%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_socket_rep).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("ezmq_internal.hrl").

-export([init/1, close/4, encap_msg/4, decap_msg/5]).
-export([idle/4, pending/4, processing/4]).

-record(state, {
          last_recv = none  :: pid()|'none'
}).

%%%===================================================================
%%% API
%%%===================================================================

%%%===================================================================
%%% ezmq_socket callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the Fsm
%%
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------

init(_Opts) ->
    {ok, idle, #state{}}.

close(_StateName, _Transport, MqSState, State) ->
    State1 = State#state{last_recv = none},
    {next_state, idle, MqSState, State1}.

encap_msg({_Transport, Msg}, _StateName, _MqSState, _State) ->
    %% socket always includes an empty message part
    ezmq:simple_encap_msg([<<>>|Msg]).
decap_msg(_Transport, {_RemoteId, Msg}, _StateName, _MqSState, _State) ->
    %% socket always drops the first message message part
    [_|Tail] = ezmq:simple_decap_msg(Msg),
    Tail.

idle(check, recv, _MqSState, _State) ->
    ok;
idle(check, {deliver_recv, _Transport, IdMsg}, _MqSState, _State) ->
    check_message_structure(IdMsg);
idle(check, deliver, _MqSState, _State) ->
    ok;
idle(check, _, _MqSState, _State) ->
    {error, fsm};

idle(do, {queue, _Transport}, MqSState, State) ->
    {next_state, pending, MqSState, State};
idle(do, {dequeue, _Transport}, MqSState, State) ->
    {next_state, pending, MqSState, State};
idle(do, {deliver, Transport}, MqSState, State) ->
    State1 = State#state{last_recv = Transport},
    {next_state, processing, MqSState, State1};
idle(do, _, _MqSState, _State) ->
    {error, fsm}.

pending(check, {deliver_recv, _Transport, IdMsg}, _MqSState, _State) ->
    check_message_structure(IdMsg);
pending(check, recv, _MqSState, _State) ->
    ok;
pending(check, deliver, _MqSState, _State) ->
    ok;
pending(check, _, _MqSState, _State) ->
    {error, fsm};

pending(do, {queue, _Transport}, MqSState, State) ->
    {next_state, pending, MqSState, State};
pending(do, {dequeue, _Transport}, MqSState, State) ->
    {next_state, pending, MqSState, State};
pending(do, {deliver, Transport}, MqSState, State) ->
    State1 = State#state{last_recv = Transport},
    {next_state, processing, MqSState, State1};
pending(do, _, _MqSState, _State) ->
    {error, fsm}.

processing(check, {deliver_recv, _Transport, IdMsg}, _MqSState, _State) ->
    check_message_structure(IdMsg);
processing(check, {deliver, _Transport}, _MqSState, _State) ->
    queue;
processing(check, {send, _Msg}, _MqSState, #state{last_recv = Transport}) ->
    {ok, Transport};
processing(check, _, _MqSState, _State) ->
    {error, fsm};

processing(do, {deliver_send, abort}, MqSState, State) ->
    State1 = State#state{last_recv = none},
    {next_state, idle, MqSState, State1};
processing(do, {deliver_send, _Transport}, MqSState, State) ->
    State1 = State#state{last_recv = none},
    {next_state, idle, MqSState, State1};
processing(do, {queue, _Transport}, MqSState, State) ->
    {next_state, processing, MqSState, State};

processing(do, _, _MqSState, _State) ->
    {error, fsm}.

%%--------------------------------------------------------------------
%% Helper
%%--------------------------------------------------------------------

check_message_structure({_Id, [{normal, <<>>}|_]}) ->
    ok;
check_message_structure(_) ->
    {error, invalid_message}.
