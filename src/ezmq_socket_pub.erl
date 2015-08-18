%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_socket_pub).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("ezmq_internal.hrl").

-export([init/1, close/4, encap_msg/4, decap_msg/5]).
-export([idle/4]).

-record(state, {
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
    {next_state, idle, MqSState, State}.

encap_msg({_Transport, Msg}, _StateName, _MqSState, _State) ->
    ezmq:simple_encap_msg(Msg).
decap_msg(_Transport, {_RemoteId, Msg}, _StateName, _MqSState, _State) ->
    ezmq:simple_decap_msg(Msg).

idle(check, {send, _Msg}, #ezmq_socket{transports = []}, _State) ->
    {queue, block};
idle(check, {send, _Msg}, #ezmq_socket{transports = Transports}, _State) ->
    {ok, Transports};
idle(check, dequeue_send, #ezmq_socket{transports = Transports}, _State) ->
    {ok, Transports};
idle(check, dequeue_send, _MqSState, _State) ->
    keep;
idle(check, {deliver_recv, _Transport, {_, [{normal, <<0:8>>}]}}, _MqSState, _State) ->
    control;
idle(check, {deliver_recv, _Transport, {_, [{normal, <<1:8, _/binary>>}]}}, _MqSState, _State) ->
    control;
idle(check, _, _MqSState, _State) ->
    {error, fsm};

idle(do, queue_send, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, {deliver_send, abort}, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, {deliver_send, _Transport}, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, {control, {PeerId, [{normal, <<0:8>>}]}}, MqSState, State) ->
    %% TODO: unsubscribe all topic for this peer
    {next_state, idle, MqSState, State};
idle(do, {control, {PeerId, [{normal, <<1:8, Topic/binary>>}]}}, MqSState, State) ->
    %% TODO: subscribe the topic for this peer
    {next_state, idle, MqSState, State};
idle(do, _, _MqSState, _State) ->
    {error, fsm}.
