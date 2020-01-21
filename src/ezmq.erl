%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq).

-behaviour(gen_server).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("ezmq_internal.hrl").

%% API scheduler
-export([start_link/1, start/1, socket_link/1, socket/1]).
-export([bind/4, connect/5, close/1]).
-export([recv/1, recv/2]).
-export([send/2]).
-export([controlling_process/2, setopts/2, sockname/1]).

%% Internal exports
-export([deliver_recv/2, deliver_accept/2, deliver_connect/2, deliver_close/1]).
-export([simple_encap_msg/1, simple_decap_msg/1, lb/2]).
-export([remote_id_assign/1, remote_id_exists/2, transports_get/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).
-define(port(P), (((P) band bnot 16#ffff) =:= 0)).
-record(cargs, {family, address, port, tcpopts, timeout, failcnt}).

-ifdef(debug).
-define(SERVER_OPTS,{debug,[trace]}).
-else.
-define(SERVER_OPTS,).
-endif.

%%%===================================================================
%%% public API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------

start(RawOpts) when is_list(RawOpts) ->
    start_link(RawOpts).
start_link(RawOpts) when is_list(RawOpts) ->
    Opts = lists:map(fun validate_opts/1, proplists:unfold(RawOpts)),
    gen_server:start_link(?MODULE, {self(), Opts}, [?SERVER_OPTS]).

socket(Opts) when is_list(Opts) ->
    start_link(Opts).

socket_link(Opts) when is_list(Opts) ->
    start_link(Opts).

bind(Socket, tcp, Port, Opts) when ?port(Port) ->
    Valid = case proplists:get_value(ip, Opts) of
                undefined -> ok;
                Address   -> validate_address(Address)
            end,

    %%TODO: socket options
    case Valid of
        ok  -> gen_server:call(Socket, {bind, tcp, Port, Opts});
        Res -> Res
    end.

connect(Socket, tcp, Address, Port, Opts) when ?port(Port) ->
    case validate_address(Address) of
        ok  -> gen_server:call(Socket, {connect, tcp, Address, Port, Opts});
        Res -> Res
    end.

close(Socket) ->
        gen_server:call(Socket, close).

send(Socket, Msg) when is_pid(Socket), is_list(Msg) ->
    gen_server:call(Socket, {send, Msg}, infinity);

send(Socket, Msg = {_Identity, Parts})
  when is_pid(Socket), is_list(Parts) ->
    gen_server:call(Socket, {send, Msg}, infinity).

recv(Socket) ->
    gen_server:call(Socket, {recv, infinity}, infinity).

recv(Socket, Timeout) ->
    gen_server:call(Socket, {recv, Timeout}, infinity).

controlling_process(Socket, Pid) when is_pid(Socket), is_pid(Pid) ->
    gen_server:call(Socket, {controlling_process, Pid}).

setopts(Socket, RawOpts) ->
    Opts = lists:map(fun validate_opts/1, proplists:unfold(RawOpts)),
    gen_server:call(Socket, {setopts, Opts}).

sockname(Socket) ->
    gen_server:call(Socket, sockname).

%%%===================================================================
%%% internal API
%%%===================================================================

deliver_recv(Socket, IdMsg) ->
    gen_server:cast(Socket, {deliver_recv, self(), IdMsg}).

deliver_accept(Socket, RemoteId) ->
    gen_server:cast(Socket, {deliver_accept, self(), RemoteId}).

deliver_connect(Socket, Reply) ->
    gen_server:cast(Socket, {deliver_connect, self(), Reply}).

deliver_close(Socket) ->
    gen_server:cast(Socket, {deliver_close, self()}).

%%
%% load balance sending sockets
%% - simple round robin
%%
%% CHECK: is 0MQ actually doing anything else?
%%
lb(Transports, MqSState = #ezmq_socket{transports = Trans}) when is_list(Transports) ->
    Trans1 = lists:subtract(Trans, Transports) ++ Transports,
    MqSState#ezmq_socket{transports = Trans1};

lb(Transport, MqSState = #ezmq_socket{transports = Trans}) ->
    Trans1 = lists:delete(Transport, Trans) ++ [Transport],
    MqSState#ezmq_socket{transports = Trans1}.

%% transport helpers
transports_get(Pid, _) when is_pid(Pid) ->
    Pid;
transports_get(RemoteId, #ezmq_socket{remote_ids = RemIds}) ->
    case orddict:find(RemoteId, RemIds) of
        {ok, Pid} -> Pid;
        _        -> none
    end.

remote_id_assign(<<>>) ->
    make_ref();
remote_id_assign(Id) when is_binary(Id) ->
    Id.

remote_id_exists(<<>>, #ezmq_socket{}) ->
    false;
remote_id_exists(RemoteId, #ezmq_socket{remote_ids = RemIds}) ->
    orddict:is_key(RemoteId, RemIds).

remote_id_add(Transport, RemoteId, MqSState = #ezmq_socket{remote_ids = RemIds}) ->
    MqSState#ezmq_socket{remote_ids = orddict:store(RemoteId, Transport, RemIds)}.

remote_id_del(Transport, MqSState = #ezmq_socket{remote_ids = RemIds}) when is_pid(Transport) ->
    MqSState#ezmq_socket{remote_ids = orddict:filter(fun(_Key, Value) -> Value /= Transport end, RemIds)};
remote_id_del(RemoteId, MqSState = #ezmq_socket{remote_ids = RemIds}) ->
    MqSState#ezmq_socket{remote_ids = orddict:erase(RemoteId, RemIds)}.

transports_is_active(Transport, #ezmq_socket{transports = Transports}) ->
    lists:member(Transport, Transports).

transports_activate(Transport, RemoteId, MqSState = #ezmq_socket{transports = Transports}) ->
    link(Transport),
    MqSState1 = remote_id_add(Transport, RemoteId, MqSState),
    MqSState1#ezmq_socket{transports = [Transport|Transports]}.

transports_deactivate(Transport, MqSState = #ezmq_socket{transports = Transports}) ->
    unlink(Transport),
    MqSState1 = remote_id_del(Transport, MqSState),
    MqSState1#ezmq_socket{transports = lists:delete(Transport, Transports)}.

get_remote_ids_by_transport(Transport, #ezmq_socket{remote_ids = RemoteIdsOdict}) ->
    GetRemoveIdsFun =
        fun(Key, Value, RemoteIds) when Value =:= Transport ->
                [Key | RemoteIds];
            (_, _, RemoteIds) ->
                RemoteIds
        end,
    orddict:fold(GetRemoveIdsFun, [], RemoteIdsOdict).

transports_while(Fun, Data, Default, #ezmq_socket{transports = Transports}) ->
    do_transports_while(Fun, Data, Transports, Default).

transports_connected(#ezmq_socket{transports = Transports}) ->
    Transports /= [].

%% walk the list of transports
%% this is intended to hide the details of the transports impl.
do_transports_while(_Fun, _Data, [], Default) ->
    Default;
do_transports_while(Fun, Data, [Head|Rest], Default) ->
    case Fun(Head, Data) of
        continue -> do_transports_while(Fun, Data, Rest, Default);
        Resp     -> Resp
    end.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
socket_types(Type) ->
    SupMod = [{req, ezmq_socket_req}, {rep, ezmq_socket_rep},
              {dealer, ezmq_socket_dealer}, {router, ezmq_socket_router},
              {pub, ezmq_socket_pub}, {sub, ezmq_socket_sub}],
    proplists:get_value(Type, SupMod).

init({Owner, Opts}) ->
    case socket_types(proplists:get_value(type, Opts, req)) of
        undefined ->
            {stop, invalid_opts};
        Type ->
            init_socket(Owner, Type, Opts)
    end.

init_socket(Owner, Type, Opts) ->
    process_flag(trap_exit, true),
    MqSState0 = #ezmq_socket{owner = Owner, mode = passive, recv_q = orddict:new(),
			     connecting = orddict:new(), listen_trans = orddict:new(),
			     transports = [], remote_ids = orddict:new()},
    MqSState1 = lists:foldl(fun do_setopts/2, MqSState0, Opts),
    ezmq_socket_fsm:init(Type, Opts, MqSState1).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({bind, tcp, Port, Opts}, _From, MqSState = #ezmq_socket{version = Version, type = Type, identity = Identity}) ->
    TcpOpts0 = [binary, {active,false}, {send_timeout,5000}, {backlog,10},
		{nodelay,true}, {packet,raw}, {reuseaddr,true}],
    TcpOpts1 = pass_inet_opts(Opts, TcpOpts0),

    logger:debug("bind: ~p", [TcpOpts1]),
    case ezmq_tcp_socket:start_link(Version, Type, Identity, Port, TcpOpts1) of
        {ok, Pid} ->
            Listen = orddict:append(Pid, {tcp, Port, Opts}, MqSState#ezmq_socket.listen_trans),
            {reply, ok, MqSState#ezmq_socket{listen_trans = Listen}};
        Reply ->
            {reply, Reply, MqSState}
    end;

handle_call({connect, tcp, Address, Port, Opts}, _From, State) ->
    TcpOpts0 = [binary, {active,false}, {send_timeout,5000}, {nodelay,true}, {packet,raw}, {reuseaddr,true}],
    TcpOpts1 = pass_inet_opts(Opts, TcpOpts0),
    Timeout = proplists:get_value(timeout, Opts, 5000),
    ConnectArgs = #cargs{family = tcp, address = Address, port = Port, tcpopts = TcpOpts1,
                         timeout = Timeout, failcnt = 0},
    NewState = do_connect(ConnectArgs, State),
    {reply, ok, NewState};

handle_call(close, _From, #ezmq_socket{remote_ids = RemoteIds} = State) ->
    [send_owner_event(RemoteId, closed, State) || {RemoteId, _} <- RemoteIds],
    {stop, normal, ok, State};

handle_call({recv, _Timeout}, _From, #ezmq_socket{mode = Mode} = State)
  when Mode /= passive ->
    {reply, {error, active}, State};
handle_call({recv, _Timeout}, _From, #ezmq_socket{pending_recv = PendingRecv} = State)
  when PendingRecv /= none ->
    Reply = {error, already_recv},
    {reply, Reply, State};
handle_call({recv, Timeout}, From, State) ->
    handle_recv(Timeout, From, State);

handle_call({send, Msg}, From, State) ->
    case ezmq_socket_fsm:check({send, Msg}, State) of
        {queue, Action} ->
            %%TODO: HWM and swap to disk....
            State1 = State#ezmq_socket{send_q = State#ezmq_socket.send_q ++ [Msg]},
            State2 = ezmq_socket_fsm:do(queue_send, State1),
            case Action of
                return ->
                    State3 = check_send_queue(State2),
                    {reply, ok, State3};
                block  ->
                    State3 = State2#ezmq_socket{pending_send = From},
                    State4 = check_send_queue(State3),
                    {noreply, State4}
            end;
        {drop, Reply} ->
            {reply, Reply, State};
        {error, Reason} ->
            {reply, {error, Reason}, State};
        {ok, Transports} ->
            ezmq_link_send({Transports, Msg}, State),
            State1 = ezmq_socket_fsm:do({deliver_send, Transports}, State),
            State2 = queue_run(State1),
            {reply, ok, State2}
    end;

handle_call({controlling_process, Pid}, {From, _Tag}, #ezmq_socket{owner = From} = State) ->
    unlink(From),
    link(Pid),
    {reply, ok, State#ezmq_socket{owner = Pid}};
handle_call({controlling_process, _Pid}, _From, State) ->
    {reply, {error, not_owner}, State};

handle_call({setopts, Opts}, _From, State) ->
    NewState = lists:foldl(fun do_setopts/2, State, Opts),
    {reply, ok, NewState};

handle_call(sockname, _From, #ezmq_socket{listen_trans = ListenTrans, transports = Transports} = State) ->
    Reply = orddict:fold(fun do_sockname/3, [], ListenTrans) ++
	lists:foldl(fun do_sockname/2, [], Transports),
    {reply, {ok, Reply}, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------

handle_cast({deliver_accept, Transport, RemoteId}, State) ->
    State1 = transports_activate(Transport, RemoteId, State),
    send_owner_event(RemoteId, accepted, State1),
    logger:debug("DELIVER_ACCPET: ~p", [State1, ?MODULE]),
    if(State1#ezmq_socket.type == sub) ->
          logger:debug("Subscribe transport: ~p, S ~p", [Transport,State]),
          %TODO: add fitlters to State and subscribe to needed channels only
          ezmq_link_send({[Transport], [<<1,"">>]}, State1);
      true ->
          ok
    end,
    State2 = send_queue_run(State1),
    {noreply, State2};

handle_cast({deliver_connect, Transport, {ok, RemoteId}}, State) ->
    State1 = transports_activate(Transport, RemoteId, State),
    send_owner_event(RemoteId, connected, State1),
    logger:debug("DELIVER_CONNECT: ~p", [State1]),
    State2 = send_queue_run(State1),
    {noreply, State2};

handle_cast({deliver_connect, Transport, Reply}, State = #ezmq_socket{connecting = Connecting}) ->
    case Reply of
        %% transient errors
        {error, Reason} when Reason == eagain; Reason == ealready;
                             Reason == econnrefused; Reason == econnreset ->
            ConnectArgs = orddict:fetch(Transport, Connecting),
            logger:debug("CArgs: ~w", [ConnectArgs]),
            erlang:send_after(3000, self(), {reconnect, ConnectArgs#cargs{failcnt = ConnectArgs#cargs.failcnt + 1}}),
            State2 = State#ezmq_socket{connecting = orddict:erase(Transport, Connecting)},
            {noreply, State2};
        _ ->
            State1 = State#ezmq_socket{connecting = orddict:erase(Transport, Connecting)},
            State2 = check_send_queue(State1),
            {noreply, State2}
    end;

handle_cast({deliver_close, Transport}, State = #ezmq_socket{connecting = Connecting}) ->
    State0 = transports_deactivate(Transport, State),
    [send_owner_event(RemoteId, closed, State0) || RemoteId <- get_remote_ids_by_transport(Transport, State)],
    State1 = queue_close(Transport, State0),
    State2 = ezmq_socket_fsm:close(Transport, State1),
    State3 = case orddict:find(Transport, Connecting) of
                 {ok, ConnectArgs} ->
                     erlang:send_after(3000, self(), {reconnect, ConnectArgs#cargs{failcnt = 0}}),
                     State2#ezmq_socket{connecting =orddict:erase(Transport, Connecting)};
                 _ ->
                     check_send_queue(State2)
             end,
    _State4 = queue_run(State3),
    logger:debug("DELIVER_CLOSE: ~p", [_State4]),
    {noreply, State3};

handle_cast({deliver_recv, Transport, IdMsg}, State) ->
    handle_deliver_recv(Transport, IdMsg, State);

handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(recv_timeout, #ezmq_socket{pending_recv = {From, _}} = State) ->
    gen_server:reply(From, {error, timeout}),
    State1 = State#ezmq_socket{pending_recv = none},
    {noreply, State1};

handle_info({reconnect, ConnectArgs}, #ezmq_socket{} = State) ->
    NewState = do_connect(ConnectArgs, State),
    {noreply, NewState};

handle_info({'EXIT', Pid, Reason}, #ezmq_socket{owner = Pid} = State) ->
    logger:debug("owner process died: ~p~n", [Reason]),
    {stop, normal, State};

handle_info({'EXIT', Pid, _Reason}, MqSState) ->
    case transports_is_active(Pid, MqSState) of
        true ->
            handle_cast({deliver_close, Pid}, MqSState);
        _ ->
            {noreply, MqSState}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

do_connect(ConnectArgs = #cargs{family = tcp}, MqSState = #ezmq_socket{version = Version, type = Type, identity = Identity}) ->
    logger:debug("starting connect: ~w", [ConnectArgs]),
    #cargs{address = Address, port = Port, tcpopts = TcpOpts,
           timeout = Timeout, failcnt = _FailCnt} = ConnectArgs,
    {ok, Transport} = ezmq_link:start_connection(),
    ezmq_link:connect(Version, Type, Identity, Transport, tcp, Address, Port, TcpOpts, Timeout),
    Connecting = orddict:store(Transport, ConnectArgs, MqSState#ezmq_socket.connecting),
    MqSState#ezmq_socket{connecting = Connecting}.

check_send_queue(MqSState = #ezmq_socket{send_q = []}) ->
    MqSState;
check_send_queue(MqSState = #ezmq_socket{connecting = Connecting, listen_trans = Listen}) ->
    case {transports_connected(MqSState), orddict:size(Connecting), orddict:size(Listen)} of
        {false, 0, 0} -> clear_send_queue(MqSState);
        _             -> MqSState
    end.

clear_send_queue(State = #ezmq_socket{send_q = []}) ->
    State;
clear_send_queue(State = #ezmq_socket{send_q = [_Msg], pending_send = From})
  when From /= none ->
    gen_server:reply(From, {error, no_connection}),
    State1 = ezmq_socket_fsm:do({deliver_send, abort}, State),
    State1#ezmq_socket{send_q = [], pending_send = none};

clear_send_queue(State = #ezmq_socket{send_q = [_Msg|Rest]}) ->
    State1 = ezmq_socket_fsm:do({deliver_send, abort}, State),
    clear_send_queue(State1#ezmq_socket{send_q = Rest}).

send_queue_run(State = #ezmq_socket{send_q = []}) ->
    State;
send_queue_run(State = #ezmq_socket{send_q = [Msg], pending_send = From})
  when From /= none ->
    case ezmq_socket_fsm:check(dequeue_send, State) of
        {ok, Transports} ->
            ezmq_link_send({Transports, Msg}, State),
            State1 = ezmq_socket_fsm:do({deliver_send, Transports}, State),
            gen_server:reply(From, ok),
            State1#ezmq_socket{send_q = [], pending_send = none};
        _ ->
            State
    end;
send_queue_run(State = #ezmq_socket{send_q = [Msg|Rest]}) ->
    case ezmq_socket_fsm:check(dequeue_send, State) of
        {ok, Transports} ->
            ezmq_link_send({Transports, Msg}, State),
            State1 = ezmq_socket_fsm:do({deliver_send, Transports}, State),
            send_queue_run(State1#ezmq_socket{send_q = Rest});
        _ ->
            State
    end.

%% check if should deliver the 'top of queue' message
queue_run(State) ->
    case ezmq_socket_fsm:check(deliver, State) of
        ok -> queue_run_2(State);
        _ -> State
    end.
queue_run_2(#ezmq_socket{mode = Mode} = State)
  when Mode == active; Mode == active_once ->
    run_recv_q(State);
queue_run_2(#ezmq_socket{pending_recv = {_From, _Ref}} = State) ->
    run_recv_q(State);
queue_run_2(#ezmq_socket{mode = passive} = State) ->
    State.

run_recv_q(State) ->
    case dequeue(State) of
        {{Transport, IdMsg}, State0} ->
            send_owner(Transport, IdMsg, State0);
        _ ->
            State
    end.

cond_cancel_timer(none) ->
     ok;
cond_cancel_timer(Ref) ->
    _ = erlang:cancel_timer(Ref),
    ok.

%% send a specific message to the owner
send_owner(Transport, IdMsg, #ezmq_socket{pending_recv = {From, Ref}} = State) ->
    ok = cond_cancel_timer(Ref),
    State1 = State#ezmq_socket{pending_recv = none},
    gen_server:reply(From, {ok, ezmq_socket_fsm:decap_msg(Transport, IdMsg, State)}),
    ezmq_socket_fsm:do({deliver, Transport}, State1);
send_owner(Transport, IdMsg, #ezmq_socket{owner = Owner, mode = Mode} = State)
  when Mode == active; Mode == active_once ->
    Owner ! {zmq, self(), ezmq_socket_fsm:decap_msg(Transport, IdMsg, State)},
    NewState = ezmq_socket_fsm:do({deliver, Transport}, State),
    next_mode(NewState).

%% send a specific event to the owner.
send_owner_event(_RemoveId, _Event, #ezmq_socket{need_events = false}) ->
    ok;
send_owner_event(RemoveId, Event, #ezmq_socket{owner = Owner}) ->
    Owner ! {zmq_event, self(), {RemoveId, Event}}.

next_mode(#ezmq_socket{mode = active} = State) ->
    queue_run(State);
next_mode(#ezmq_socket{mode = active_once} = State) ->
    State#ezmq_socket{mode = passive}.

handle_deliver_recv(Transport, IdMsg, MqSState) ->
    logger:debug("deliver_recv: ~w, ~w", [Transport, IdMsg]),
    case ezmq_socket_fsm:check({deliver_recv, Transport, IdMsg}, MqSState) of
        ok ->
            MqSState0 = handle_deliver_recv_2(Transport, IdMsg, queue_size(MqSState), MqSState),
            {noreply, MqSState0};
        control ->
            MqSState0 = ezmq_socket_fsm:do({control, IdMsg}, MqSState),
            {noreply, MqSState0};
        {error, _Reason} ->
            {noreply, MqSState}
    end.

handle_deliver_recv_2(Transport, IdMsg, 0, #ezmq_socket{mode = Mode} = MqSState)
  when Mode == active; Mode == active_once ->
    case ezmq_socket_fsm:check(deliver, MqSState) of
        ok -> send_owner(Transport, IdMsg, MqSState);
        _ -> queue(Transport, IdMsg, MqSState)
    end;

handle_deliver_recv_2(Transport, IdMsg, 0, #ezmq_socket{pending_recv = {_From, _Ref}} = MqSState) ->
    case ezmq_socket_fsm:check(deliver, MqSState) of
        ok -> send_owner(Transport, IdMsg, MqSState);
        _ -> queue(Transport, IdMsg, MqSState)
    end;

handle_deliver_recv_2(Transport, IdMsg, _, MqSState) ->
    queue(Transport, IdMsg, MqSState).

handle_recv(Timeout, From, MqSState) ->
    case ezmq_socket_fsm:check(recv, MqSState) of
        {error, Reason} ->
            {reply, {error, Reason}, MqSState};
        ok ->
            handle_recv_2(Timeout, From, queue_size(MqSState), MqSState)
    end.

handle_recv_2(Timeout, From, 0, State) ->
    Ref = case Timeout of
              infinity -> none;
              _ -> erlang:send_after(Timeout, self(), recv_timeout)
          end,
    State1 = State#ezmq_socket{pending_recv = {From, Ref}},
    {noreply, State1};

handle_recv_2(_Timeout, _From, _, State) ->
    case dequeue(State) of
        {{Transport, IdMsg}, State0} ->
            State2 = ezmq_socket_fsm:do({deliver, Transport}, State0),
            {reply, {ok, ezmq_socket_fsm:decap_msg(Transport, IdMsg, State)}, State2};
        _ ->
            {reply, {error, internal}, State}
    end.

simple_encap_msg(Msg) when is_list(Msg) ->
    lists:map(fun(M) -> {normal, M} end, Msg).
simple_decap_msg(Msg) when is_list(Msg) ->
    lists:reverse(lists:foldl(fun({normal, M}, Acc) -> [M|Acc]; (_, Acc) -> Acc end, [], Msg)).

ezmq_link_send({Transports, Msg}, State)
  when is_list(Transports) ->
    lists:foreach(fun(T) ->
                          Msg1 = ezmq_socket_fsm:encap_msg({T, Msg}, State),
                          ezmq_link:send(T, Msg1)
                  end, Transports);
ezmq_link_send({Transport, Msg}, State) ->
    ezmq_link:send(Transport, ezmq_socket_fsm:encap_msg({Transport, Msg}, State)).

%%
%% round robin queue
%%

queue_size(#ezmq_socket{recv_q = Q}) ->
    orddict:size(Q).

queue(Transport, Value, MqSState = #ezmq_socket{recv_q = Q}) ->
    Q1 = orddict:update(Transport, fun(V) -> queue:in(Value, V) end,
                        queue:from_list([Value]), Q),
    MqSState1 = MqSState#ezmq_socket{recv_q = Q1},
    ezmq_socket_fsm:do({queue, Transport}, MqSState1).

queue_close(Transport, MqSState = #ezmq_socket{recv_q = Q}) ->
    Q1 = orddict:erase(Transport, Q),
    MqSState#ezmq_socket{recv_q = Q1}.

dequeue(MqSState = #ezmq_socket{recv_q = Q}) ->
    logger:debug("TRANS: ~p, PENDING: ~p", [MqSState#ezmq_socket.transports, Q]),
    case transports_while(fun do_dequeue/2, Q, empty, MqSState) of
        {{Transport, Value}, Q1} ->
            MqSState0 = MqSState#ezmq_socket{recv_q = Q1},
            MqSState1 = ezmq_socket_fsm:do({dequeue, Transport}, MqSState0),
            MqSState2 = lb(Transport, MqSState1),
            {{Transport, Value}, MqSState2};
        Reply ->
            Reply
    end.

do_dequeue(Transport, Q) ->
    case orddict:find(Transport, Q) of
        {ok, V} ->
            {{value, Value}, V1} = queue:out(V),
            Q1 = case queue:is_empty(V1) of
                     true -> orddict:erase(Transport, Q);
                     false -> orddict:store(Transport, V1, Q)
                 end,
                {{Transport, Value}, Q1};
        _ ->
            continue
    end.

do_setopts({type, Type}, MqSState) ->
    MqSState#ezmq_socket{type = Type};
do_setopts({identity, Id}, MqSState) ->
    MqSState#ezmq_socket{identity = Id};
do_setopts({active, once}, MqSState) ->
    run_recv_q(MqSState#ezmq_socket{mode = active_once});
do_setopts({active, true}, MqSState) ->
    run_recv_q(MqSState#ezmq_socket{mode = active});
do_setopts({active, false}, MqSState) ->
    MqSState#ezmq_socket{mode = passive};
do_setopts({need_events, NeedEvents}, MqSState) ->
    MqSState#ezmq_socket{need_events = NeedEvents};
do_setopts({version, Version}, MqSState) ->
    MqSState#ezmq_socket{version = Version};

do_setopts(_, MqSState) ->
    MqSState.

validate_opts(Opt = {type, Type})
  when Type == req;    Type == rep;
       Type == dealer; Type == router;
       Type == pub;    Type == sub ->
    Opt;

validate_opts(Opt = {identity, Id}) when is_binary(Id) ->
    Opt;
validate_opts({identity, Id}) when is_list(Id) ->
    {identity, iolist_to_binary(Id)};

validate_opts(Opt = {active, once}) -> Opt;
validate_opts(Opt = {active, true}) -> Opt;
validate_opts(Opt = {active, false}) -> Opt;

validate_opts(Opt = {need_events, NeedEvents}) when is_boolean(NeedEvents) ->
    Opt;

validate_opts(Opt = {version, Version}) ->
    case lists:member(Version, ?SUPPORTED_VERSIONS) of
        true ->
	    Opt;
        _ ->
            erlang:error(badargs, [Opt])
    end;

validate_opts(Opt) ->
    erlang:error(badarg, [Opt]).


do_sockname(Transport, _Opts, Acc) ->
    case ezmq_tcp_socket:sockname(Transport) of
	{ok, SockName} ->
	    [SockName|Acc];
	_ ->
	    Acc
    end.

do_sockname(Transport, Acc) ->
    case ezmq_link:sockname(Transport) of
	{ok, SockName} ->
	    [SockName|Acc];
	_ ->
	    Acc
    end.

pass_inet_opts(Opts, TcpOpts) ->
    lists:foldl(fun do_pass_inet_opts/2, TcpOpts, Opts).

do_pass_inet_opts(O = {ip, _}, Opts) ->
    [O|Opts];
do_pass_inet_opts(O = {ifaddr, _}, Opts) ->
    [O|Opts];
do_pass_inet_opts(inet, Opts) ->
    [inet|Opts];
do_pass_inet_opts(inet6, Opts) ->
    [inet6|Opts];
do_pass_inet_opts(_, Opts) ->
    Opts.

validate_address(Address) when is_list(Address) ->
    case inet:gethostbyname(Address) of
	{ok, _} -> ok;
	Other   -> Other
    end;
validate_address(Address) when is_tuple(Address) ->
    case inet:gethostbyaddr(Address) of
	{ok, _} -> ok;
	{error, nxdomain} -> ok;
	Other -> Other
    end;
validate_address(Address) ->
    error(badarg, [Address]).
