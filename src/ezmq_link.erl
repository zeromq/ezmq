%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_link).

-behaviour(gen_fsm).

%% API
-export([start_link/0]).
-export([start_connection/0, accept/6, connect/9, close/1]).
-export([sockname/1]).

%% gen_fsm callbacks
-export([init/1, handle_event/3,
         handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).
-export([setup/2, open/2, handshake/2, connecting/2, connected/2, send/2]).

-define(SERVER, ?MODULE).

-record(state, {
          role = undefined          :: 'undefined' | 'client' | 'server',
          type                      :: atom(),
          mqsocket                  :: pid(),
          identity = <<>>           :: binary(),
          remote_id = <<>>          :: binary(),
          remote_id_len = 0         :: integer(),  %% only used during backward compatible negotiation
          socket,
          version = {2,0},
          frames = [],
          hs_state = undefined,
          pending = <<>>
         }).


-define(STARTUP_TIMEOUT, 10000).     %% wait 10sec for someone to tell us what to do
-define(CONNECT_TIMEOUT, 10000).     %% wait 10sec for the first packet to arrive
-define(REQUEST_TIMEOUT, 10000).     %% wait 10sec for answer
-define(TCP_OPTS, [binary, inet6,
                   {active,       false},
                   {send_timeout, 5000},
                   {backlog,      100},
                   {nodelay,      true},
                   {packet,       raw},
                   {reuseaddr,    true}]).

-ifdef(debug).
-define(FSM_OPTS,{debug,[trace]}).
-else.
-define(FSM_OPTS,).
-endif.

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_fsm:start_link(?MODULE, [], [?FSM_OPTS]).

start_connection() ->
    ezmq_link_sup:start_connection().

accept(MqSocket, Version, Type, Identity, Server, Socket) ->
    ok = gen_tcp:controlling_process(Socket, Server),
    gen_fsm:send_event(Server, {accept, MqSocket, Version, Type, Identity, Socket}).

connect(Version, Type, Identity, Server, tcp, Address, Port, TcpOpts, Timeout) ->
    gen_fsm:send_event(Server, {connect, self(), Version, Type, Identity, tcp, Address, Port, TcpOpts, Timeout}).

send(Server, Msg) ->
    gen_fsm:send_event(Server, {send, Msg}).

sockname(Server) ->
    gen_fsm:sync_send_all_state_event(Server, sockname).

close(Server) ->
        gen_fsm:sync_send_all_state_event(Server, close).

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {ok, StateName, State, Timeout} |
%%                     ignore |
%%                     {stop, StopReason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    process_flag(trap_exit, true),
    {ok, setup, #state{}, ?STARTUP_TIMEOUT}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same
%% name as the current state name StateName is called to handle
%% the event. It is also called if a timeout occurs.
%%
%% @spec state_name(Event, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
setup({accept, MqSocket, Version, Type, Identity, Socket}, State) ->
    logger:debug("got setup"),
    NewState = State#state{version = Version, role = server,
                           type = Type, mqsocket = MqSocket,
                           identity = Identity, socket = Socket},
    logger:debug("NewState: ~p", [NewState]),
    send_greeting({next_state, open, NewState, ?CONNECT_TIMEOUT});

setup({connect, MqSocket, Version, Type, Identity, tcp, Address, Port, TcpOpts, Timeout}, State) ->
    logger:debug("got connect: ~w, ~w", [Address, Port]),
    State1 = State#state{version = Version, role = client,
                         type = Type, mqsocket = MqSocket,
                         identity = Identity},

    %%TODO: socket options
    case gen_tcp:connect(Address, Port, TcpOpts, Timeout) of
        {ok, Socket} ->
            State2 = State1#state{socket = Socket},
            ok = inet:setopts(Socket, [{active, once}]),
            send_greeting({next_state, connecting, State2, ?CONNECT_TIMEOUT});
        Reply ->
            deliver_connect(State1, Reply),
            {stop, normal, State1}
    end.

connecting(timeout, State) ->
    logger:debug("timeout in connecting"),
    deliver_connect(State, {error, timeout}),
    {stop, normal, State};

%% if we get a ZMTP 1.0 greeting or we are talking ZMTP 1.0 only, select ZMTP 1.0
connecting({_FrameType, IdLength}, State = #state{version = {Major, _}})
  when Major == 1 ->
    logger:debug("in connecting v1, got greeting: ~p", [IdLength]),
    handle_zmtp13_greeting(IdLength, State);

connecting({short, IdLength}, State = #state{version = {_Major, _}}) ->
    logger:debug("in connecting v~w, got greeting: ~p", [_Major, IdLength]),
    NextStateInfo = handle_zmtp13_greeting(IdLength, State),
    finish_zmtp13_handshake(NextStateInfo);

connecting({long, IdLength}, State = #state{version = {Major, _}}) ->
    logger:debug("in connecting v~w, got signature: ~p", [Major, IdLength]),
    send_major(next_handshake_state('$major', State#state{remote_id_len = IdLength}));

connecting(_Msg, State) ->
    logger:debug("Invalid message in connecting: ~p", [_Msg]),
    deliver_connect(State, {error, data}),
    {stop, normal, State}.

open(timeout, State) ->
    logger:debug("timeout in open"),
    {stop, normal, State};

%% if we get a ZMTP 1.0 greeting or we are talking ZMTP 1.0 only, select ZMTP 1.0
open({_FrameType, IdLength}, State = #state{version = {Major, _}})
  when Major == 1 ->
    logger:debug("in open v1, got greeting: ~p", [IdLength]),
    handle_zmtp13_greeting(IdLength, State);

open({short, IdLength}, State = #state{version = {_Major, _}}) ->
    logger:debug("in open v~w, got greeting: ~p", [_Major, IdLength]),
    NextStateInfo = handle_zmtp13_greeting(IdLength, State),
    finish_zmtp13_handshake(NextStateInfo);

open({long, IdLength}, State = #state{version = {Major, _}}) ->
    logger:debug("in open v~w, got signature: ~p", [Major, IdLength]),
    send_major(next_handshake_state('$major', State#state{remote_id_len = IdLength}));

open(_Msg, State) ->
    logger:debug("Invalid message in open: ~p", [_Msg]),
    {stop, normal, State}.

handshake(timeout, State) ->
    logger:debug("timeout in open"),
    {stop, normal, State};

handshake(_Msg, State = #state{hs_state = HsState}) ->
    logger:debug("Invalid handshake message in ~w: ~p", [HsState, _Msg]),
    {stop, normal, State}.

handshake({1, _}, '$identity', Data, #state{remote_id_len = IdLength})
  when byte_size(Data) < IdLength ->
    more;
handshake({1, _}, '$identity', Data, #state{remote_id_len = IdLength} = State) ->
    <<RemoteId:IdLength/bytes, Rest/binary>> = Data,
    logger:debug("in '$identity' v1, got remoteId: ~p", [RemoteId]),
    State1 = State#state{pending = Rest},
    State2 = remote_id_assign(RemoteId, State1),
    deliver_connected(State2),
    {next_state, connected, State2};

handshake({2, _}, '$identity', Data, #state{remote_id_len = IdLength})
  when byte_size(Data) < IdLength + 2 ->
    more;

handshake({2, _}, '$identity', <<0:8, IdLength:8/integer, RemoteId:IdLength/bytes, Rest/binary>>,
          #state{remote_id_len = IdLength} = State) ->
    logger:debug("in '$identity' v2, remoteId: ~p", [RemoteId]),
    State1 = State#state{pending = Rest},
    State2 = remote_id_assign(RemoteId, State1),
    deliver_connected(State2),
    {next_state, connected, State2};

handshake({2, _}, '$identity', _Data, State) ->
    {stop, normal, State};

%% revision 0x01 is really ZMTP 2.0
handshake(_, '$major', <<1:8, Rest/binary>>, State) ->
    State1 = State#state{pending = Rest},
    negotiate_major(2, State1);
handshake(_, '$major', <<Major:8, Rest/binary>>, State)
  when Major >= 3 ->
    State1 = State#state{pending = Rest},
    negotiate_major(Major, State1);
handshake(_, '$major', <<Major:8, _/binary>>, State) ->
    logger:error("peer tried invalid protocol version ~w", [Major]),
    {stop, normal, State};

%% TODO: handle ZMTP 3.0+
handshake(_, '$minor', _Data, State) ->
    {stop, normal, State};

handshake(_, '$socketType', <<SocketType:8, Rest/binary>>, State) ->
    State1 = State#state{pending = Rest},
    handle_socket_type(SocketType, State1);

handshake(Version, HsState, Data, State) ->
    logger:debug("in ~p:~p, invalid data ~p", [Version, HsState, Data]),
    {stop, normal, State}.

connected(timeout, State) ->
    logger:debug("timeout in connected"),
    {stop, normal, State};

connected({in, Frames}, #state{mqsocket = MqSocket, remote_id = RemoteId} = State) ->
    logger:debug("in connected Frames: ~p", [Frames]),
    ezmq:deliver_recv(MqSocket, {RemoteId, Frames}),
    {next_state, connected, State};

connected({send, Msg}, State) ->
    send_frames(Msg, {next_state, connected, State}).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/[2,3], the instance of this function with
%% the same name as the current state name StateName is called to
%% handle the event.
%%
%% @spec state_name(Event, From, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------



%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%
%% @spec handle_event(Event, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/[2,3], this function is called
%% to handle the event.
%%
%% @spec handle_sync_event(Event, From, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
handle_sync_event(close, _From, _StateName, State) ->
    {stop, normal, ok, State};

handle_sync_event(sockname, _From, StateName, #state{socket = Socket} = State)
  when is_port(Socket)  ->
    Reply =
	case inet:sockname(Socket) of
	    {ok, {Address, Port}} ->
		{ok, {tcp, Address, Port}};
	    Other ->
		Other
	end,
    {reply, Reply, StateName, State};

handle_sync_event(sockname, _From, StateName, State) ->
    Reply = {error, closed},
    {reply, Reply, StateName, State};

handle_sync_event(_Event, _From, StateName, State) ->
    Reply = ok,
    {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it receives any
%% message other than a synchronous or asynchronous event
%% (or a system message).
%%
%% @spec handle_info(Info,StateName,State)->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_info({'EXIT', MqSocket, _Reason}, _StateName, #state{mqsocket = MqSocket} = State) ->
    {stop, normal, State#state{mqsocket = undefined}};

handle_info({tcp, Socket, Data}, StateName, #state{socket = Socket} = State) ->
    logger:debug("handle_info: ~p", [Data]),
    State1 = State#state{pending = <<(State#state.pending)/binary, Data/binary>>},
    handle_data(StateName, State1, {next_state, StateName, State1});

handle_info({tcp_closed, Socket}, _StateName, #state{socket = Socket} = State) ->
    logger:debug("client disconnected: ~w", [Socket]),
    {stop, normal, State}.

handle_data(_StateName, #state{socket = Socket, pending = <<>>}, ProcessStateNext) ->
    next_state_socket_active(Socket, ProcessStateNext);

handle_data(StateName, #state{socket = Socket, pending = Pending} = State, ProcessStateNext)
  when StateName =:= connecting;
       StateName =:= open ->
    {Msg, DataRest} = ezmq_frame:decode_greeting(Pending),
    State1 = State#state{pending = DataRest},
    logger:debug("handle_data (greeting): decoded: ~p, rest: ~p", [Msg, DataRest]),

    case Msg of
        more ->
            next_state_socket_active(Socket, setelement(3, ProcessStateNext, State1));

        invalid ->
            %% assume that this is a greeting for a version that we don't understand,
            %% fall back to ZMTP 1.0
            FakeMsg = {short, 0},
            Reply = ?MODULE:StateName(FakeMsg, State1),
            handle_data_reply(Reply);

        Other ->
            Reply = ?MODULE:StateName(Other, State1),
            handle_data_reply(Reply)
    end;

handle_data(handshake, State = #state{version = Version, hs_state = HsState, socket = Socket, pending = Pending},
            ProcessStateNext) ->
    logger:debug("handshake ~w.~w ~w, got data: ~p", [element(1, Version), element(2, Version), HsState, Pending]),
    case handshake(Version, HsState, Pending, State) of
        more ->
            next_state_socket_active(Socket, setelement(3, ProcessStateNext, State));

        Reply ->
            handle_data_reply(Reply)
    end;


handle_data(StateName, #state{socket = Socket, version = Ver, pending = Pending} = State, ProcessStateNext) ->
    {Msg, DataRest} = ezmq_frame:decode(Ver, Pending),
    State1 = State#state{pending = DataRest},
    logger:debug("handle_data: (~w, ~p) decoded: ~p, rest: ~p", [Ver, StateName, Msg, DataRest]),

    case Msg of
        more ->
            next_state_socket_active(Socket, setelement(3, ProcessStateNext, State1));

        invalid ->
            {stop, normal, State1};

        {true, Frame} ->
            State2 = State1#state{frames = [Frame|State1#state.frames]},
            handle_data(StateName, State2, setelement(3, ProcessStateNext, State2));

        {false, Frame} ->
            Frames = lists:reverse([Frame|State1#state.frames]),
            State2 = State1#state{frames = []},
            logger:debug("handle_data: finale decoded: ~p", [Frames]),
            Reply = exec_sync(Frames, StateName, State2),
            logger:debug("handle_data: reply: ~p", [logger:pr(?MODULE, Reply)]),
            handle_data_reply(Reply)
    end.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%
%% @spec terminate(Reason, StateName, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, #state{mqsocket = MqSocket, socket = Socket})
  when is_port(Socket) ->
    logger:debug("terminate"),
    catch ezmq:deliver_close(MqSocket),
    gen_tcp:close(Socket),
    ok;
terminate(_Reason, _StateName, #state{mqsocket = MqSocket}) ->
    logger:debug("terminate"),
    catch ezmq:deliver_close(MqSocket),
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, StateName, State, Extra) ->
%%                   {ok, StateName, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

exec_sync(Msg, StateName, State) ->
    ?MODULE:StateName({in, Msg}, State).

next_state_socket_active(Socket, NextStateInfo) ->
    case inet:setopts(Socket, [{active, once}]) of
	ok -> NextStateInfo;
	_  -> {stop, normal, element(3, NextStateInfo)}
    end.

handle_data_reply(Reply)
  when element(1, Reply) =:= next_state ->
    handle_data(element(2, Reply), element(3, Reply), Reply);
handle_data_reply(Reply) ->
    Reply.

next_handshake_state(HsState, State) ->
    {next_state, handshake, State#state{hs_state = HsState}}.

remote_id_assign(RemoteId0, State) ->
    State#state{remote_id = ezmq:remote_id_assign(RemoteId0)}.

handle_zmtp13_greeting(IdLength, State) ->
    State1 = State#state{version = {1, 0}, remote_id_len = IdLength},
    if IdLength == 0 ->
            State2 = remote_id_assign(<<>>, State1),
            deliver_connected(State2),
            {next_state, connected, State2};
       true ->
            next_handshake_state('$identity', State1)
    end.

deliver_connected(State = #state{role = client, remote_id = RemoteId}) ->
    deliver_connect(State, {ok, RemoteId});
deliver_connected(#state{role = server, mqsocket = MqSocket, remote_id = RemoteId}) ->
    ezmq:deliver_accept(MqSocket, RemoteId).

deliver_connect(#state{mqsocket = MqSocket}, Reply) ->
    ezmq:deliver_connect(MqSocket, Reply).

negotiate_major(RemoteMajor, State = #state{version = {Major, _}})
  when Major =:= 2 orelse RemoteMajor =:= 2 ->
    finish_zmtp15_handshake(next_handshake_state('$socketType', State#state{version = {2, 0}}));

negotiate_major(RemoteMajor, State = #state{version = {Major, _}})
  when RemoteMajor < Major ->
    %% downgrade
    Version = highest_supported_version(Major),
    send_minor(next_handshake_state('$minor', State#state{version = Version}));

negotiate_major(_RemoteMajor, State) ->
    send_minor(next_handshake_state('$minor', State)).

handle_socket_type(RemoteSocketType, State = #state{type = Type}) ->
    RemoteSocketTypeAtom = ezmq_frame:socket_type_atom(RemoteSocketType),
    case is_compatible_socket(Type, RemoteSocketTypeAtom) of
        ok ->
            next_handshake_state('$identity', State);
        Other ->
            logger:warning("socket types ~w: ~w", [{Type, RemoteSocketTypeAtom}, Other]),
            {stop, normal, State}
    end.

highest_supported_version(_) ->
    {3, 1}.

send_major(NextStateInfo) ->
    #state{version = {Major, _}} = element(3, NextStateInfo),
    if Major =:= 2 ->
            send_packet(<<1:8>>, NextStateInfo);
       true ->
            send_packet(<<Major:8>>, NextStateInfo)
    end.

send_minor(NextStateInfo) ->
    #state{version = {_, Minor}} = element(3, NextStateInfo),
    send_packet(<<Minor:8>>, NextStateInfo).

finish_zmtp13_handshake(NextStateInfo) ->
    #state{identity = Identity} = element(3, NextStateInfo),
    Packet = <<Identity/binary>>,
    send_packet(Packet, NextStateInfo).

%% ZMTP 2.0, after the version 2.0 has been agreed, we can send the
%% rest of the handshake in one go
finish_zmtp15_handshake(NextStateInfo) ->
    #state{type = Type, identity = Identity} = element(3, NextStateInfo),
    SocketType = ezmq_frame:socket_type_int(Type),
    Length = byte_size(Identity),
    Packet = <<SocketType:8, 0:8, Length:8, Identity/binary>>,
    send_packet(Packet, NextStateInfo).

send_greeting(NextStateInfo) ->
    #state{version = Version, identity = Identity} = element(3, NextStateInfo),
    Packet = ezmq_frame:encode_greeting(Version, undefined, Identity),
    send_packet(Packet, NextStateInfo).

send_frames(Frames, NextStateInfo) ->
    #state{version = Version} = element(3, NextStateInfo),
    Packet = ezmq_frame:encode(Version, Frames),
    send_packet(Packet, NextStateInfo).

send_packet(Packet, NextStateInfo) ->
    State = element(3, NextStateInfo),
    Socket = State#state.socket,

    case gen_tcp:send(Socket, Packet) of
        ok ->
            next_state_socket_active(Socket, NextStateInfo);
        {error, Reason} ->
            logger:debug("error - Reason: ~p", [Reason]),
            {stop, normal, State}
    end.

is_compatible_socket(pair, pair) -> ok;
is_compatible_socket(pub, sub) -> ok;
is_compatible_socket(sub, pub) -> ok;
is_compatible_socket(req, rep) -> ok;
is_compatible_socket(req, router) -> ok;
is_compatible_socket(rep, req) -> ok;
is_compatible_socket(rep, dealer) -> ok;
is_compatible_socket(dealer, rep) -> ok;
is_compatible_socket(dealer, dealer) -> ok;
is_compatible_socket(dealer, router) -> ok;
is_compatible_socket(router, req) -> ok;
is_compatible_socket(router, dealer) -> ok;
is_compatible_socket(router, router) -> ok;
is_compatible_socket(pull, push) -> ok;
is_compatible_socket(push, pull) -> ok;
is_compatible_socket(_, _) -> incompatible.
