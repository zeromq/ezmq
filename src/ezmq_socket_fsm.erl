%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_socket_fsm).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("ezmq_internal.hrl").

-export([init/3, check/2, do/2, close/2, encap_msg/2, decap_msg/3]).

-record(fsm_state, {
          module      :: atom(),
          state_name  :: atom(),
          state       :: term()
}).

-type transport()  :: pid().
-type check_type() :: 'send' | 'dequeue_send' | 'deliver' | 'deliver_recv' | 'recv'.
-type do_type()    :: 'queue_send' | {'deliver_send', list(transport())} | {'deliver', transport()} | {'queue', transport()} | {'dequeue', transport()}.

%% FSM CHECKS
%% ==========
%%
%% {'send', Msg}:
%%     is it permited the execute a send call in the current state,
%%     return: {ok, Transport} | {error, Reason} | {queue, block | return}
%%
%% 'dequeue_send':
%%     return the transport to send on or 'keep' when none is available
%%     return: {ok, Transport} | 'keep'
%%
%% 'deliver':
%%     should the recived message delivered to the socket owner or queue for later
%%     return: ok | queue
%%
%% {'deliver_recv', Transport, IdMsg}
%%     is IdMsg recived on Transport permited in the current state and/or
%%     do we need to treat is as a socket fsm control message
%%     return: ok | control | {error, Reason}
%%
%% 'recv':
%%     is it permited the execute a recv call in the current state,
%%     return: ok | {error, Reason}
%%
%% FSM do operations
%% =================
%%
%% do operations change the current state of FSM,
%%  their return is:
%%       {next_state, NextStateName, MqSState1, State} | {error, Reason}
%%
%% 'queue_send':
%%     called the a new message has been queued for sending
%%
%% {'deliver_send', Transports}:
%%     called the a new message has been send on Transports,
%%     Transports == 'abort' signals that the last message was not sent
%%
%% {'deliver', Transport}:
%%     called the a received message has been delivered to the socket owner
%%
%% {'queue', Transport}:
%%     called the a received message has been queued for delivery to the socket owner
%%
%% {'dequeue', Transport}:
%%    called the a queued received message has been delivered to the socket owner


init(Module, Opts, MqSState) ->
    case Module:init(Opts) of
        {ok, StateName, State} ->
            {ok, MqSState#ezmq_socket{fsm = #fsm_state{module = Module, state_name = StateName, state = State}}};
        Reply ->
            {Reply, MqSState}
    end.

%% check actions do not alter the state of the FSM
check(Action, MqSState = #ezmq_socket{fsm = Fsm}) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
    R = Module:StateName(check, Action, MqSState, State),
    logger:debug("ezmq_socket_fsm state: ~w, check: ~w, Result: ~w", [StateName, Action, R]),
    R.

do(Action, MqSState = #ezmq_socket{fsm = Fsm}) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
    case Module:StateName(do, Action, MqSState, State) of
        {error, Reason} ->
            logger:error("socket fsm for ~w exited with ~p, (~p,~p)~n", [Action, Reason, MqSState, State]),
            error(Reason);
        {next_state, NextStateName, NextMqSState, NextState} ->
            logger:debug("ezmq_socket_fsm: state: ~w, Action: ~w, next_state: ~w", [StateName, Action, NextStateName]),
            NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
            NextMqSState#ezmq_socket{fsm = NewFsm}
    end.

close(Transport, MqSState = #ezmq_socket{fsm = Fsm}) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
    case Module:close(StateName, Transport, MqSState, State) of
        {error, Reason} ->
            logger:error("socket fsm for ~w exited with ~p, (~p,~p)~n", [Transport, Reason, MqSState, State]),
            error(Reason);
        {next_state, NextStateName, NextMqSState, NextState} ->
            logger:debug("ezmq_socket_fsm: state: ~w, Transport: ~w, next_state: ~w", [StateName, Transport, NextStateName]),
            NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
            NextMqSState#ezmq_socket{fsm = NewFsm}
    end.

encap_msg({Transport, Msg}, MqSState = #ezmq_socket{fsm = Fsm})
  when is_pid(Transport), is_list(Msg) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
     Module:encap_msg({Transport, Msg}, StateName, MqSState, State);
encap_msg({Transport, Msg = {_Identity, Parts}}, MqSState = #ezmq_socket{fsm = Fsm})
  when is_pid(Transport), is_list(Parts) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
     Module:encap_msg({Transport, Msg}, StateName, MqSState, State).

decap_msg(Transport, IdMsg = {_, Msg}, MqSState = #ezmq_socket{fsm = Fsm})
  when is_pid(Transport), is_list(Msg) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
     Module:decap_msg(Transport, IdMsg, StateName, MqSState, State).
