%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_zmq2_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

reqrep_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, req, rep, active, 3),
    basic_tests_ezmq(fun ping_pong_ezmq/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, req, rep, active, 3).
reqrep_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5556", {127,0,0,1}, 5556, req, rep, passive, 3),
    basic_tests_ezmq(fun ping_pong_ezmq/3, "tcp://127.0.0.1:5556", {127,0,0,1}, 5556, req, rep, passive, 3).

reqrep_tcp_id_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, req, "reqrep_tcp_id_test_active_req", rep, "reqrep_tcp_id_test_active_rep", active, 3),
    basic_tests_ezmq(fun ping_pong_ezmq/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, req, "reqrep_tcp_id_test_active_req", rep, "reqrep_tcp_id_test_active_rep", active, 3).
reqrep_tcp_id_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5556", {127,0,0,1}, 5556, req, "reqrep_tcp_id_test_passive_req", rep, "reqrep_tcp_id_test_passive_rep", passive, 3),
    basic_tests_ezmq(fun ping_pong_ezmq/3, "tcp://127.0.0.1:5556", {127,0,0,1}, 5556, req, "reqrep_tcp_id_test_passive_req", rep, "reqrep_tcp_id_test_passive_rep", passive, 3).

reqrep_tcp_large_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5557", {127,0,0,1}, 5557, req, rep, active, 256),
    basic_tests_ezmq(fun ping_pong_ezmq/3, "tcp://127.0.0.1:5557", {127,0,0,1}, 5557, req, rep, active, 256).
reqrep_tcp_large_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5558", {127,0,0,1}, 5558, req, rep, passive, 256),
    basic_tests_ezmq(fun ping_pong_ezmq/3, "tcp://127.0.0.1:5558", {127,0,0,1}, 5558, req, rep, passive, 256).

dealerrep_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun dealer_rep_ping_pong_erlzmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, rep, active, 4),
    basic_tests_ezmq(fun dealer_rep_ping_pong_ezmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, rep, active, 4).
dealerrep_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun dealer_rep_ping_pong_erlzmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, rep, passive, 3),
    basic_tests_ezmq(fun dealer_rep_ping_pong_ezmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, rep, passive, 3).

dealerrep_tcp_id_test_active(_Config) ->
    basic_tests_erlzmq(fun dealer_rep_ping_pong_erlzmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, "dealerrep_tcp_id_test_active_dealer", rep, "dealerrep_tcp_id_test_active_rep", active, 4),
    basic_tests_ezmq(fun dealer_rep_ping_pong_ezmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, "dealerrep_tcp_id_test_active_dealer", rep, "dealerrep_tcp_id_test_active_rep", active, 4).
dealerrep_tcp_id_test_passive(_Config) ->
    basic_tests_erlzmq(fun dealer_rep_ping_pong_erlzmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, "dealerrep_tcp_id_test_passive_dealer", rep, "dealerrep_tcp_id_test_passive_rep", passive, 3),
    basic_tests_ezmq(fun dealer_rep_ping_pong_ezmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, "dealerrep_tcp_id_test_passive_dealer", rep, "dealerrep_tcp_id_test_passive_rep", passive, 3).

dealerrouter_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun dealer_router_ping_pong_erlzmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, router, active, 4),
    basic_tests_ezmq(fun dealer_router_ping_pong_ezmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, router, active, 4).
dealerrouter_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun dealer_router_ping_pong_erlzmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, router, passive, 3),
    basic_tests_ezmq(fun dealer_router_ping_pong_ezmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, router, passive, 3).

dealerrouter_tcp_id_test_active(_Config) ->
    basic_tests_erlzmq(fun dealer_router_ping_pong_erlzmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, "dealerrouter_tcp_id_test_active_dealer", router, "dealerrouter_tcp_id_test_active_router", active, 4),
    basic_tests_ezmq(fun dealer_router_ping_pong_ezmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, "dealerrouter_tcp_id_test_active_dealer", router, "dealerrouter_tcp_id_test_active_router", active, 4).
dealerrouter_tcp_id_test_passive(_Config) ->
    basic_tests_erlzmq(fun dealer_router_ping_pong_erlzmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, "dealerrouter_tcp_id_test_passive_dealer", router, "dealerrouter_tcp_id_test_passive_router", passive, 3),
    basic_tests_ezmq(fun dealer_router_ping_pong_ezmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, "dealerrouter_tcp_id_test_passive_dealer", router, "dealerrouter_tcp_id_test_passive_router", passive, 3).

reqdealer_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_req_dealer/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, dealer, active, 3),
    basic_tests_ezmq(fun ping_pong_ezmq_req_dealer/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, dealer, active, 3).
reqdealer_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_req_dealer/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, dealer, passive, 3),
    basic_tests_ezmq(fun ping_pong_ezmq_req_dealer/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, dealer, passive, 3).

reqdealer_tcp_id_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_req_dealer/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, "reqdealer_tcp_test_active_req",  dealer, "reqdealer_tcp_test_active_dealer",  active, 3),
    basic_tests_ezmq(fun ping_pong_ezmq_req_dealer/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, "reqdealer_tcp_test_active_req",  dealer, "reqdealer_tcp_test_active_dealer",  active, 3).
reqdealer_tcp_id_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_req_dealer/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, "reqdealer_tcp_test_passive_req",  dealer, "reqdealer_tcp_test_passive_dealer",  passive, 3),
    basic_tests_ezmq(fun ping_pong_ezmq_req_dealer/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, "reqdealer_tcp_test_passive_req",  dealer, "reqdealer_tcp_test_passive_dealer",  passive, 3).

reqrouter_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_req_router/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, router, active, 3),
    basic_tests_ezmq(fun ping_pong_ezmq_req_router/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, router, active, 3).
reqrouter_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_req_router/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, router, passive, 3),
    basic_tests_ezmq(fun ping_pong_ezmq_req_router/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, router, passive, 3).

reqrouter_tcp_id_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_req_router/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, "reqrouter_tcp_test_active_req",  router, "reqrouter_tcp_test_active_router",  active, 3),
    basic_tests_ezmq(fun ping_pong_ezmq_req_router/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, "reqrouter_tcp_test_active_req",  router, "reqrouter_tcp_test_active_router",  active, 3).
reqrouter_tcp_id_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_req_router/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, "reqrouter_tcp_test_passive_req",  router, "reqrouter_tcp_test_passive_router",  passive, 3),
    basic_tests_ezmq(fun ping_pong_ezmq_req_router/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, "reqrouter_tcp_test_passive_req",  router, "reqrouter_tcp_test_passive_router",  passive, 3).

create_bound_pair_erlzmq(Ctx, Type1, Type2, Mode, Transport, IP, Port) ->
    create_bound_pair_erlzmq(Ctx, Type1, [], Type2, [], Mode, Transport, IP, Port).

erlzmq_identity(Socket, []) ->
    ok;
erlzmq_identity(Socket, Id) ->
    erlzmq:setsockopt(Socket, identity, Id).

ezmq_socket(Opts) ->
    SOpts = case erlang:get(ezmq_version) of
	       Version = {_,_} ->
		    [{version, Version}|Opts];
	       _ -> Opts
	   end,
    ezmq:socket(SOpts).

create_bound_pair_erlzmq(Ctx, Type1, Id1, Type2, Id2, Mode, Transport, IP, Port) ->
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
    {ok, S1} = erlzmq:socket(Ctx, [Type1, {active, Active}]),
    {ok, S2} = ezmq_socket([{type, Type2}, {active, Active}, {identity, Id2}]),
    ok = erlzmq_identity(S1, Id1),
    ok = erlzmq:bind(S1, Transport),
    ok = ezmq:connect(S2, tcp, IP, Port, []),
    {S1, S2}.

create_bound_pair_ezmq(Ctx, Type1, Type2, Mode, Transport, IP, Port) ->
    create_bound_pair_ezmq(Ctx, Type1, [], Type2, [], Mode, Transport, IP, Port).

create_bound_pair_ezmq(Ctx, Type1, Id1, Type2, Id2, Mode, Transport, IP, Port) ->
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
    {ok, S1} = ezmq_socket([{type, Type1}, {active, Active}, {identity,Id1}]),
    {ok, S2} = erlzmq:socket(Ctx, [Type2, {active, Active}]),
    ok = erlzmq_identity(S2, Id2),
    ok = ezmq:bind(S1, tcp, Port, [{reuseaddr, true}]),
    ok = erlzmq:connect(S2, Transport),
    {S1, S2}.

%% assert that message queue is empty....
assert_mbox_empty() ->
    receive
        M -> ct:fail({unexpected, M})
    after
        0 -> ok
    end.

%% assert that top message in the queue is what we think it should be
assert_mbox(Msg) ->
    assert_mbox_match({Msg,[],[ok]}).

assert_mbox_match(MatchSpec) ->
    CompiledMatchSpec = ets:match_spec_compile([MatchSpec]),
    receive
        M -> case ets:match_spec_run([M], CompiledMatchSpec) of
                 [] -> ct:fail({unexpected, M});
                 [Ret] -> Ret
             end
    after
        1000 ->
            ct:fail(timeout)
    end.

ping_pong_erlzmq({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    assert_mbox({zmq, S2, [Msg,Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, [Msg]),
    assert_mbox({zmq, S1, Msg, []}),

    ok = erlzmq:send(S1, Msg),
    assert_mbox({zmq, S2, [Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, [Msg]),
    assert_mbox({zmq, S1, Msg, []}),
    assert_mbox_empty(),

    ok;

ping_pong_erlzmq({S1, S2}, Msg, passive) ->
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg]} = ezmq:recv(S2),
    ok = ezmq:send(S2, [Msg]),
    {ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg,Msg]} = ezmq:recv(S2),
    ok.

ping_pong_ezmq({S1, S2}, Msg, active) ->
    ok = ezmq:send(S1, [Msg,Msg]),
    assert_mbox({zmq, S2, Msg, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S1, [Msg]),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, Msg, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [Msg,Msg]}),
    assert_mbox_empty(),

    ok;

ping_pong_ezmq({S1, S2}, Msg, passive) ->
    ok = ezmq:send(S1, [Msg]),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, Msg),
    {ok, [Msg]} = ezmq:recv(S1),
    ok = ezmq:send(S1, [Msg,Msg]),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

ping_pong_erlzmq_req_dealer({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    assert_mbox({zmq, S2, [<<>>, Msg, Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, [<<>>, Msg]),
    assert_mbox({zmq, S1, Msg, []}),

    ok = erlzmq:send(S1, Msg),
    assert_mbox({zmq, S2, [<<>>, Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, [<<>>, Msg]),
    assert_mbox({zmq, S1, Msg, []}),
    assert_mbox_empty(),

    ok;

ping_pong_erlzmq_req_dealer({S1, S2}, Msg, passive) ->
    ok = erlzmq:send(S1, Msg),
    {ok, [<<>>, Msg]} = ezmq:recv(S2),
    ok = ezmq:send(S2, [<<>>, Msg]),
    {ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [<<>>, Msg, Msg]} = ezmq:recv(S2),
    ok.

ping_pong_ezmq_req_dealer({S1, S2}, Msg, active) ->
    ok = ezmq:send(S1, [Msg, Msg]),
    assert_mbox({zmq, S2, <<>>, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S1, [Msg]),
    assert_mbox({zmq, S2, <<>>, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [Msg,Msg]}),
    assert_mbox_empty(),

    ok;

ping_pong_ezmq_req_dealer({S1, S2}, Msg, passive) ->
    ok = ezmq:send(S1, [Msg]),
    {ok, <<>>} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    {ok, [Msg]} = ezmq:recv(S1),
    ok = ezmq:send(S1, [Msg,Msg]),
    {ok, <<>>} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

dealer_rep_ping_pong_erlzmq({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),

    assert_mbox({zmq, S2, [Msg,Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, [Msg]),
    assert_mbox({zmq, S1, <<>>, [rcvmore]}),
    assert_mbox({zmq, S1, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    assert_mbox({zmq, S2, [Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, [Msg]),
    assert_mbox({zmq, S1, <<>>, [rcvmore]}),
    assert_mbox({zmq, S1, Msg, []}),
    assert_mbox_empty(),

    ok;

dealer_rep_ping_pong_erlzmq({S1, S2}, Msg, passive) ->
    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg]} = ezmq:recv(S2),
    ok = ezmq:send(S2, [Msg]),
    {ok, <<>>} = erlzmq:recv(S1),
    {ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg,Msg]} = ezmq:recv(S2),
    ok.

dealer_router_ping_pong_erlzmq({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),

    Id = assert_mbox_match({{zmq, S2, {'$1',[Msg, Msg]}},[], ['$1']}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, {Id, [Msg, Msg]}),
    assert_mbox({zmq, S1, Msg, [rcvmore]}),
    assert_mbox({zmq, S1, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    assert_mbox({zmq, S2, {Id, [Msg, Msg]}}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, {Id, [Msg, Msg]}),
    assert_mbox({zmq, S1, Msg, [rcvmore]}),
    assert_mbox({zmq, S1, Msg, []}),
    assert_mbox_empty(),

    ok;

dealer_router_ping_pong_erlzmq({S1, S2}, Msg, passive) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, {Id, [Msg, Msg]}} = ezmq:recv(S2),

    ok = ezmq:send(S2, {Id, [Msg, Msg]}),
    {ok, Msg} = erlzmq:recv(S1),
    {ok, Msg} = erlzmq:recv(S1),

    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, {Id, [Msg, Msg, Msg]}} = ezmq:recv(S2),
    ok.

dealer_recv_loop() ->
    receive
        M ->
            ct:pal("got: ~w~n", [M]),
            dealer_recv_loop()
    after
        1000 ->
            ct:fail(timeout)
    end.

dealer_rep_ping_pong_ezmq({S1, S2}, Msg, active) ->
    ok = ezmq:send(S1, [<<>>, Msg,Msg]),
    assert_mbox({zmq, S2, Msg, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [<<>>, Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S1, [<<>>, Msg]),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [<<>>, Msg]}),
    ok;

dealer_rep_ping_pong_ezmq({S1, S2}, Msg, passive) ->
    ok = ezmq:send(S1, [<<>>, Msg]),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, Msg),
    {ok, [<<>>, Msg]} = ezmq:recv(S1),
    ok = ezmq:send(S1, [<<>>, Msg,Msg]),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

dealer_router_ping_pong_ezmq({S1, S2}, Msg, active) ->
    ok = ezmq:send(S1, [Msg,Msg]),
    Id = assert_mbox_match({{zmq, S2, '$1', [rcvmore]},[], ['$1']}),
    assert_mbox({zmq, S2, Msg, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, Msg, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [Msg, Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S1, [Msg, Msg]),
    assert_mbox({zmq, S2, Id, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [Msg]}),
    ok;

dealer_router_ping_pong_ezmq({S1, S2}, Msg, passive) ->
    ok = ezmq:send(S1, [Msg]),
    {ok, Id} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    {ok, [Msg]} = ezmq:recv(S1),
    ok = ezmq:send(S1, [Msg,Msg]),
    {ok, Id} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

ping_pong_erlzmq_req_router({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    %% {zmq, S2, {Id,[Msg,Msg]}} =
    Id = assert_mbox_match({{zmq, S2, {'$1',[<<>>, Msg,Msg]}},[], ['$1']}),
    ct:pal("ezmq router ID: ~p~n", [Id]),
    io:format("Id: ~w~n", [Id]),
    assert_mbox_empty(),

    ok = ezmq:send(S2, {Id, [<<>>, Msg]}),
    assert_mbox({zmq, S1, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S1, Msg),
    assert_mbox({zmq, S2, {Id, [<<>>, Msg]}}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, {Id, [<<>>, Msg]}),
    assert_mbox({zmq, S1, Msg, []}),
    assert_mbox_empty(),

    ok;

ping_pong_erlzmq_req_router({S1, S2}, Msg, passive) ->
    ok = erlzmq:send(S1, Msg),
    {ok, {Id, [<<>>, Msg]}} = ezmq:recv(S2),
    ct:pal("ezmq router ID: ~p~n", [Id]),
    ok = ezmq:send(S2, {Id, [<<>>, Msg]}),
    {ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, {Id, [<<>>, Msg,Msg]}} = ezmq:recv(S2),
    ok.

ping_pong_ezmq_req_router({S1, S2}, Msg, active) ->
    ok = ezmq:send(S1, [Msg,Msg]),
    Id = assert_mbox_match({{zmq, S2, '$1', [rcvmore]},[], ['$1']}),
    ct:pal("erlzmq router ID: ~p~n", [Id]),
    assert_mbox({zmq, S2, <<>>, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S1, [Msg]),
    assert_mbox({zmq, S2, Id, [rcvmore]}),
    assert_mbox({zmq, S2, <<>>, [rcvmore]}),
    assert_mbox({zmq, S2, Msg, []}),
    assert_mbox_empty(),

    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    assert_mbox({zmq, S1, [Msg,Msg]}),
    assert_mbox_empty(),

    ok;

ping_pong_ezmq_req_router({S1, S2}, Msg, passive) ->
    ok = ezmq:send(S1, [Msg]),
    {ok, Id} = erlzmq:recv(S2),
    ct:pal("erlzmq router ID: ~p~n", [Id]),
    {ok, <<>>} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg),
    {ok, [Msg]} = ezmq:recv(S1),
    ok = ezmq:send(S1, [Msg,Msg]),
    {ok, Id} = erlzmq:recv(S2),
    {ok, <<>>} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

basic_tests_erlzmq(Fun, Transport, IP, Port, Type1, Type2, Mode, Size) ->
    basic_tests_erlzmq(Fun, Transport, IP, Port, Type1, [], Type2, [], Mode, Size).

basic_tests_erlzmq(Fun, Transport, IP, Port, Type1, Id1, Type2, Id2, Mode, Size) ->
    {ok, C} = erlzmq:context(1),
    {S1, S2} = create_bound_pair_erlzmq(C, Type1, Id1, Type2, Id2, Mode, Transport, IP, Port),
    Msg = list_to_binary(string:chars($X, Size)),
    Fun({S1, S2}, Msg, Mode),
    ok = erlzmq:close(S1),
    ok = ezmq:close(S2),
    ok = erlzmq:term(C).

basic_tests_ezmq(Fun, Transport, IP, Port, Type1, Type2, Mode, Size) ->
    basic_tests_ezmq(Fun, Transport, IP, Port, Type1, [], Type2, [], Mode, Size).

basic_tests_ezmq(Fun, Transport, IP, Port, Type1, Id1, Type2, Id2, Mode, Size) ->
    {ok, C} = erlzmq:context(1),
    {S1, S2} = create_bound_pair_ezmq(C, Type1, Id1, Type2, Id2, Mode, Transport, IP, Port),
    Msg = list_to_binary(string:chars($X, Size)),
    Fun({S1, S2}, Msg, Mode),
    ok = ezmq:close(S1),
    ok = erlzmq:close(S2),
    ok = erlzmq:term(C).

init_per_suite(Config) ->
    application:start(sasl),
    %%lager:start(),
    %% lager:set_loglevel(lager_console_backend, debug),
    application:start(gen_listener_tcp),
    application:start(ezmq),
    Config.

end_per_suite(Config) ->
    Config.

init_per_group(zmtp13, Config) ->
    [{ezmq_version, {1,0}}|Config];
init_per_group(zmtp15, Config) ->
    [{ezmq_version, {2,0}}|Config];
init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, Config) ->
    Config.

init_per_testcase(_TestCase, Config)  ->
    erlang:put(ezmq_version, proplists:get_value(ezmq_version, Config)),
    Config.

end_per_testcase(_TestCase, Config) ->
    Config.

suite() -> [{timetrap, 60000}].

all() ->
    case code:ensure_loaded(erlzmq) of
        {error, _} ->
            ct:pal("Skipping erlzmq tests"),
            [];
        _ ->
	    [{group, zmtp13},
	     {group, zmtp15}]
    end.

groups() ->
    [{zmtp13, [], all_tests()},
     {zmtp15, [], all_tests()}].

f_all_tests() ->
    [reqrep_tcp_id_test_active].


all_tests() ->
    [reqrep_tcp_test_active, reqrep_tcp_test_passive, reqrep_tcp_large_active, reqrep_tcp_large_passive,
     dealerrep_tcp_test_active, dealerrep_tcp_test_passive,
     dealerrouter_tcp_test_active, dealerrouter_tcp_test_passive,
     reqdealer_tcp_test_active, reqdealer_tcp_test_passive,
     reqrouter_tcp_test_active, reqrouter_tcp_test_passive,
     reqrep_tcp_id_test_active, reqrep_tcp_id_test_passive,
     dealerrep_tcp_id_test_active, dealerrep_tcp_id_test_passive,
     dealerrouter_tcp_id_test_active, dealerrouter_tcp_id_test_passive,
     reqdealer_tcp_id_test_active, reqdealer_tcp_id_test_passive,
     reqrouter_tcp_id_test_active, reqrouter_tcp_id_test_passive].
