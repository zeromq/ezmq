%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

reqrep_tcp_test_active(Config) ->
    basic_tests(Config, req, rep, active, 3).
reqrep_tcp_test_passive(Config) ->
    basic_tests(Config, req, rep, passive, 3).

reqrep_tcp_large_active(Config) ->
    basic_tests(Config, req, rep, active, 256).
reqrep_tcp_large_passive(Config) ->
    basic_tests(Config, req, rep, passive, 256).

req_tcp_bind_close(_Config) ->
    {ok, S} = ezmq_server_socket([{type, req}, {active, false}]),
    ok = ezmq:bind(S, tcp, 0, [{reuseaddr, true}]),
    {ok, [{_, _, _}]} = ezmq:sockname(S),
    ezmq:close(S).

req_tcp_connect_close(Config) ->
    TcpOpts = tcp_opts(Config),
    IP = proplists:get_value(localhost, Config, {127,0,0,1}),
    {ok, S} = ezmq_client_socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, tcp, IP, 5555, TcpOpts),
    ezmq:close(S).

req_tcp_connect_fail(Config) ->
    TcpOpts = tcp_opts(Config),
    {ok, S} = ezmq_client_socket([{type, req}, {active, false}]),
    {error,nxdomain} = ezmq:connect(S, tcp, "undefined.undefined", 5555, TcpOpts),
    ezmq:close(S).

req_tcp_connect_timeout(Config) ->
    TcpOpts = tcp_opts(Config),
    IP = proplists:get_value(localhost, Config, {127,0,0,1}),
    {ok, S} = ezmq_client_socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, tcp, IP, 5555, [{timeout, 1000}|TcpOpts]),
    ct:sleep(2000),
    ezmq:close(S).

req_tcp_connecting_timeout(Config) ->
    TcpOpts = tcp_opts(Config),
    {ok, L} = gen_tcp:listen(0,[{active, false}, {packet, raw}, {reuseaddr, true}|TcpOpts]),
    {ok, {IP, Port}} = inet:sockname(L),
    spawn(fun() ->
                  {ok, S1} = gen_tcp:accept(L),
                  ct:sleep(15000),   %% keep socket alive for at least 10sec...
                  gen_tcp:close(S1)
          end),
    {ok, S} = ezmq_client_socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, tcp, IP, Port, [{timeout, 1000}]),
    ct:sleep(15000),    %% wait for the connection setup timeout
    ezmq:close(S).

dealer_tcp_bind_close(_Config) ->
    {ok, S} = ezmq_server_socket([{type, dealer}, {active, false}]),
    ok = ezmq:bind(S, tcp, 0, [{reuseaddr, true}]),
    {ok, [{_, _, _}]} = ezmq:sockname(S),
    ezmq:close(S).

dealer_tcp_connect_close(Config) ->
    TcpOpts = tcp_opts(Config),
    IP = proplists:get_value(localhost, Config, {127,0,0,1}),
    {ok, S} = ezmq_client_socket([{type, dealer}, {active, false}]),
    ok = ezmq:connect(S, tcp, IP, 5555, TcpOpts),
    ezmq:close(S).

dealer_tcp_connect_timeout(Config) ->
    TcpOpts = tcp_opts(Config),
    IP = proplists:get_value(localhost, Config, {127,0,0,1}),
    {ok, S} = ezmq_client_socket([{type, dealer}, {active, false}]),
    ok = ezmq:connect(S, tcp, IP, 5555, [{timeout, 1000}|TcpOpts]),
    ok = ezmq:connect(S, tcp, IP, 5555, [{timeout, 1000}|TcpOpts]),
    ok = ezmq:connect(S, tcp, IP, 5555, [{timeout, 1000}|TcpOpts]),
    ok = ezmq:connect(S, tcp, IP, 5555, [{timeout, 1000}|TcpOpts]),
    ct:sleep(2000),
    ezmq:close(S).

dealer_tcp_connecting_timeout(Config) ->
    TcpOpts = tcp_opts(Config),
    {ok, L} = gen_tcp:listen(0,[{active, false}, {packet, raw}, {reuseaddr, true}|TcpOpts]),
    {ok, {IP, Port}} = inet:sockname(L),
    spawn(fun() ->
                  {ok, S1} = gen_tcp:accept(L),
                  ct:sleep(15000),   %% keep socket alive for at least 10sec...
                  gen_tcp:close(S1)
          end),
    {ok, S} = ezmq_client_socket([{type, dealer}, {active, false}]),
    ok = ezmq:connect(S, tcp, IP, Port, [{timeout, 1000}]),
    ok = ezmq:connect(S, tcp, IP, Port, [{timeout, 1000}]),
    ok = ezmq:connect(S, tcp, IP, Port, [{timeout, 1000}]),
    ok = ezmq:connect(S, tcp, IP, Port, [{timeout, 1000}]),
    ct:sleep(15000),    %% wait for the connection setup timeout
    ezmq:close(S).

req_tcp_connecting_trash(Config) ->
    Self = self(),
    TcpOpts = tcp_opts(Config),
    {ok, L} = gen_tcp:listen(0, [{active, false}, {packet, raw}, {reuseaddr, true}|TcpOpts]),
    {ok, {IP, Port}} = inet:sockname(L),
    spawn(fun() ->
                  {ok, S1} = gen_tcp:accept(L),
                  T = <<1,16#FF,"TRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASH">>,
                  gen_tcp:send(S1, list_to_binary([T,T,T,T,T])),
                  ct:sleep(500),
                  gen_tcp:close(S1),
                  Self ! done
          end),
    {ok, S} = ezmq_client_socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, tcp, IP, Port, [{timeout, 1000}]),
    receive
        done -> ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ezmq:close(S).

rep_tcp_connecting_timeout(Config) ->
    TcpOpts = tcp_opts(Config),
    {ok, S} = ezmq_server_socket([{type, rep}, {active, false}]),
    ok = ezmq:bind(S, tcp, 0, [{reuseaddr, true}|TcpOpts]),
    {ok, [{_, IP, Port}|_]} = ezmq:sockname(S),
    spawn(fun() ->
                  {ok, L} = gen_tcp:connect(IP, Port,[{active, false}, {packet, raw}|TcpOpts]),
                  ct:sleep(15000),   %% keep socket alive for at least 10sec...
                  gen_tcp:close(L)
          end),
    ct:sleep(15000),    %% wait for the connection setup timeout
    ezmq:close(S).

rep_tcp_connecting_trash(Config) ->
    Self = self(),
    TcpOpts = tcp_opts(Config),
    {ok, S} = ezmq_server_socket([{type, rep}, {active, false}]),
    ok = ezmq:bind(S, tcp, 0, [{reuseaddr, true}|TcpOpts]),
    {ok, [{_, IP, Port}|_]} = ezmq:sockname(S),
    spawn(fun() ->
                  {ok, L} = gen_tcp:connect(IP, Port,[{active, false}, {packet, raw}|TcpOpts]),
                  T = <<1,16#FF,"TRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASH">>,
                  gen_tcp:send(L, list_to_binary([T,T,T,T,T])),
                  ct:sleep(500),
                  gen_tcp:close(L),
                  Self ! done
          end),
    receive
        done -> ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ezmq:close(S).

req_tcp_fragment_send(Socket, Data) ->
    lists:foreach(fun(X) -> gen_tcp:send(Socket, X), ct:sleep(10) end, [<<X>> || <<X>> <= Data]).

req_tcp_fragment(Config) ->
    Self = self(),
    TcpOpts = tcp_opts(Config),
    {ok, L} = gen_tcp:listen(0, [binary, {active, false}, {packet, raw}, {reuseaddr, true}, {nodelay, true}|TcpOpts]),
    {ok, {IP, Port}} = inet:sockname(L),
    spawn(fun() ->
                  {ok, S1} = gen_tcp:accept(L),
                  req_tcp_fragment_send(S1, <<16#01, 16#00>>),
                  {ok, _} = gen_tcp:recv(S1, 0),
                  Self ! connected,
                  {ok,<<_:4/bytes,"ZZZ">>} = gen_tcp:recv(S1, 0),
                  req_tcp_fragment_send(S1, <<16#01, 16#7F, 16#06, 16#7E, "Hello">>),
                  gen_tcp:close(S1),
                  Self ! done
          end),
    {ok, S} = ezmq_client_socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, tcp, IP, Port, [{timeout, 1000}]),
    receive
        connected -> ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S, [<<"ZZZ">>]),
    {ok, [<<"Hello">>]} = ezmq:recv(S),
    ezmq:close(S).

ezmq_client_socket(Opts) ->
    COpts = case erlang:get(client_version) of
	       Version = {_,_} ->
		    [{version, Version}|Opts];
	       _ -> Opts
	   end,
    ezmq:socket(COpts).

ezmq_server_socket(Opts) ->
    SOpts = case erlang:get(server_version) of
	       Version = {_,_} ->
		    [{version, Version}|Opts];
	       _ -> Opts
	   end,
    ezmq:socket(SOpts).

create_multi_connect(_Type, _Active, _IP, _Port, 0, Acc) ->
    Acc;
create_multi_connect(Type, Active, IP, Port, Cnt, Acc) ->
    {ok, S2} = ezmq_client_socket([{type, Type}, {active, Active}]),
    ok = ezmq:connect(S2, tcp, IP, Port, []),
    create_multi_connect(Type, Active, IP, Port, Cnt - 1, [S2|Acc]).

create_bound_pair_multi(Config, Type1, Type2, Cnt2, Mode) ->
    TcpOpts = tcp_opts(Config),
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
    {ok, S1} = ezmq_server_socket([{type, Type1}, {active, Active}]),
    ok = ezmq:bind(S1, tcp, 0, [{reuseaddr, true}|TcpOpts]),
    {ok, [{_, IP, Port}|_]} = ezmq:sockname(S1),

    S2 = create_multi_connect(Type2, Active, IP, Port, Cnt2, []),
    ct:sleep(10),  %% give it a moment to establish all sockets....
    {S1, S2}.

basic_test_dealer_rep(Config, Cnt2, Mode, Size) ->
    {S1, S2} = create_bound_pair_multi(Config, dealer, rep, Cnt2, Mode),
    Msg = list_to_binary(string:chars($X, Size)),

    %% send a message for each client Socket and expect a result on each socket
    lists:foreach(fun(_S) -> ok = ezmq:send(S1, [<<>>, Msg]) end, S2),
    lists:foreach(fun(S) -> {ok, [Msg]} = ezmq:recv(S) end, S2),

    ok = ezmq:close(S1),
    lists:foreach(fun(S) -> ok = ezmq:close(S) end, S2).

basic_test_dealer_req(Config, Cnt2, Mode, Size) ->
    {S1, S2} = create_bound_pair_multi(Config, dealer, req, Cnt2, Mode),
    Msg = list_to_binary(string:chars($X, Size)),

    %% send a message for each client Socket and expect a result on each socket
    lists:foreach(fun(S) -> ok = ezmq:send(S, [Msg]) end, S2),
    lists:foreach(fun(_S) -> {ok, [<<>>, Msg]} = ezmq:recv(S1) end, S2),

    ok = ezmq:close(S1),
    lists:foreach(fun(S) -> ok = ezmq:close(S) end, S2).

basic_tests_dealer(Config) ->
    %% basic_test_dealer_req(Config, 10, passive, 3), %% dealer/req is not compatible
    basic_test_dealer_rep(Config, 10, passive, 3).

basic_test_router_req(Config, Cnt2, Mode, Size) ->
    {S1, S2} = create_bound_pair_multi(Config, router, req, Cnt2, Mode),
    Msg = list_to_binary(string:chars($X, Size)),

    %% send a message for each client Socket and expect a result on each socket
    lists:foreach(fun(S) -> ok = ezmq:send(S, [Msg]) end, S2),
    lists:foreach(fun(_S) ->
                          {ok, {Id, [<<>>, Msg]}} = ezmq:recv(S1),
                          ok = ezmq:send(S1, {Id, [<<>>, Msg]})
                  end, S2),
    lists:foreach(fun(S) -> {ok, [Msg]} = ezmq:recv(S) end, S2),

    ok = ezmq:close(S1),
    lists:foreach(fun(S) -> ok = ezmq:close(S) end, S2).

basic_tests_router(Config) ->
    basic_test_router_req(Config, 10, passive, 3).

basic_test_rep_req(Config, Cnt2, Mode, Size) ->
    {S1, S2} = create_bound_pair_multi(Config, rep, req, Cnt2, Mode),
    Msg = list_to_binary(string:chars($X, Size)),

    %% send a message for each client Socket and expect a result on each socket
    lists:foreach(fun(S) -> ok = ezmq:send(S, [Msg]) end, S2),
    lists:foreach(fun(_S) ->
                          {ok, [Msg]} = ezmq:recv(S1),
                          ok = ezmq:send(S1, [Msg])
                  end, S2),
    lists:foreach(fun(S) -> {ok, [Msg]} = ezmq:recv(S) end, S2),

    ok = ezmq:close(S1),
    lists:foreach(fun(S) -> ok = ezmq:close(S) end, S2).

basic_tests_rep_req(Config) ->
    basic_test_rep_req(Config, 10, passive, 3).

basic_test_pub_sub(Config, Cnt2, Mode, Size) ->
    {S1, S2} = create_bound_pair_multi(Config, pub, sub, Cnt2, Mode),
    Msg = list_to_binary(string:chars($X, Size)),

    %% send a message for each client and expect a result on each socket
    {error, fsm} = ezmq:recv(S1),
    ok = ezmq:send(S1, [Msg]),
    lists:foreach(fun(S) -> {ok, [Msg]} = ezmq:recv(S) end, S2),
    ok = ezmq:close(S1),
    lists:foreach(fun(S) -> ok = ezmq:close(S) end, S2).

basic_tests_pub_sub(Config) ->
    basic_test_pub_sub(Config, 10, passive, 3).

shutdown_stress_test(Config) ->
    shutdown_stress_loop(Config, 10).

%% version_test() ->
%%     {Major, Minor, Patch} = ezmq:version(),
%%     ?assert(is_integer(Major) andalso is_integer(Minor) andalso is_integer(Patch)).

shutdown_stress_loop(_Config, 0) ->
    ok;
shutdown_stress_loop(Config, N) ->
    TcpOpts = tcp_opts(Config),
    {ok, S1} = ezmq_server_socket([{type, rep}, {active, false}]),
    ok = ezmq:bind(S1, tcp, 0, [{reuseaddr, true}|TcpOpts]),
    {ok, [{_, IP, Port}|_]} = ezmq:sockname(S1),
    shutdown_stress_worker_loop(IP, Port, 100),
    ok = join_procs(100),
    ezmq:close(S1),
    shutdown_stress_loop(Config, N-1).

shutdown_no_blocking_test(_Config) ->
    {ok, S} = ezmq_server_socket([{type, req}, {active, false}]),
    ezmq:close(S).

join_procs(0) ->
    ok;
join_procs(N) ->
    receive
        proc_end ->
            join_procs(N-1)
    after
        2000 ->
            throw(stuck)
    end.

shutdown_stress_worker_loop(_IP, _Port, 0) ->
    ok;
shutdown_stress_worker_loop(IP, Port, N) ->
    {ok, S2} = ezmq_client_socket([{type, req}, {active, false}]),
    spawn(?MODULE, worker, [self(), S2, IP, Port]),
    shutdown_stress_worker_loop(IP, Port, N-1).

worker(Pid, S, IP, Port) ->
    ok = ezmq:connect(S, tcp, IP, Port, []),
    ok = ezmq:close(S),
    Pid ! proc_end.

create_bound_pair(Config, Type1, Type2, Mode) ->
    TcpOpts = tcp_opts(Config),
    ct:pal("TcpOpts: ~p~n", [TcpOpts]),
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
    {ok, S1} = ezmq_server_socket([{type, Type1}, {active, Active}]),
    {ok, S2} = ezmq_client_socket([{type, Type2}, {active, Active}]),
    ok = ezmq:bind(S1, tcp, 0, [{reuseaddr, true}|TcpOpts]),
    {ok, [{_, IP, Port}|_]} = ezmq:sockname(S1),
    ct:pal("IP: ~p, Port: ~p~n", [IP, Port]),
    ok = ezmq:connect(S2, tcp, IP, Port, TcpOpts),
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

ping_pong({S1, S2}, Msg, active) ->
    ok = ezmq:send(S1, [Msg,Msg]),
    assert_mbox({zmq, S2, [Msg,Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, [Msg]),
    assert_mbox({zmq, S1, [Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S1, [Msg]),
    assert_mbox({zmq, S2, [Msg]}),
    assert_mbox_empty(),

    ok = ezmq:send(S2, [Msg]),
    assert_mbox({zmq, S1, [Msg]}),
    assert_mbox_empty(),
    ok;

ping_pong({S1, S2}, Msg, passive) ->
    ok = ezmq:send(S1, [Msg]),
    {ok, [Msg]} = ezmq:recv(S2),
    ok = ezmq:send(S2, [Msg]),
    {ok, [Msg]} = ezmq:recv(S1),
    ok = ezmq:send(S1, [Msg,Msg]),
    {ok, [Msg,Msg]} = ezmq:recv(S2),
    ok.

basic_tests(Config, Type1, Type2, Mode, Size) ->
    {S1, S2} = create_bound_pair(Config, Type1, Type2, Mode),
    Msg = list_to_binary(string:chars($X, Size)),
    ping_pong({S1, S2}, Msg, Mode),
    ok = ezmq:close(S1),
    ok = ezmq:close(S2).

tcp_opts(Config) ->
    INetType = proplists:get_value(inet_type, Config, inet),
    IP = proplists:get_value(localhost, Config, {127,0,0,1}),
    [INetType, {ifaddr, IP}].

init_per_suite(Config) ->
    ok = application:start(sasl),
    %%lager:start(),
    %% lager:set_loglevel(lager_console_backend, debug),
    ok = application:start(gen_listener_tcp),
    ok = application:start(ezmq),
    Config.

end_per_suite(Config) ->
    Config.

%% find first IPv6 IP on loopback
get_localhost_ipv6() ->
    case inet:getifaddrs() of
	{ok, AddrList} ->
	    case lists:filter(fun({_IfName, Opts}) -> Flags = proplists:get_value(flags, Opts, []), proplists:get_bool(loopback, Flags) end, AddrList) of
		[{_IfName, Opts}|_] ->
		    [Addr|_] = [A || {Key, A} <- Opts, Key == addr, tuple_size(A) == 8],
		    Addr;
		_ ->
		    undefined
	    end;
	_ ->
	    undefined
    end.

init_per_group(ipv6, Config) ->
    case get_localhost_ipv6() of
	undefined ->
            {skip, "Host does not support IPv6"};
	IP ->
	    [{inet_type, inet6}, {localhost, IP}|Config]
    end;
init_per_group(ipv4, Config) ->
    [{inet_type, inet}, {localhost, {127,0,0,1}}|Config];

init_per_group(zmtp13, Config) ->
    [{server_version, {1,0}}, {client_version, {1,0}}|Config];
init_per_group(zmtp13_server, Config) ->
    [{server_version, {1,0}}|Config];
init_per_group(zmtp13_client, Config) ->
    [{client_version, {1,0}}|Config];
init_per_group(zmtp15, Config) ->
    [{server_version, {2,0}}, {client_version, {2,0}}|Config];
init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, Config) ->
    Config.

init_per_testcase(_TestCase, Config)  ->
    erlang:put(server_version, proplists:get_value(server_version, Config)),
    erlang:put(client_version, proplists:get_value(client_version, Config)),
    Config.

end_per_testcase(_TestCase, Config) ->
    Config.

suite() -> [{timetrap, 60000}].

all() ->
    [{group, ipv6},
     {group, ipv4}].

groups() ->
    [{ipv4, [], all_versions()},
     {ipv6, [], all_versions()},
     {zmtp13, [], all_tests()},
     {zmtp13_server, [], all_tests()},
     {zmtp13_client, [], all_tests()},
     {zmtp15, [], all_tests()}].

all_versions() ->
    [{group, zmtp13},
     {group, zmtp13_server},
     {group, zmtp13_client},
     {group, zmtp15}].

all_tests() ->
    [reqrep_tcp_test_active, reqrep_tcp_test_passive,
     reqrep_tcp_large_active, reqrep_tcp_large_passive,
     shutdown_no_blocking_test,
     req_tcp_connect_fail,
     req_tcp_bind_close, req_tcp_connect_close, req_tcp_connect_timeout,
     req_tcp_connecting_timeout, req_tcp_connecting_trash,
     rep_tcp_connecting_timeout, rep_tcp_connecting_trash,
     req_tcp_fragment,
     dealer_tcp_bind_close, dealer_tcp_connect_close, dealer_tcp_connect_timeout,
     basic_tests_rep_req, basic_tests_dealer, basic_tests_router,
     basic_tests_pub_sub,
     shutdown_stress_test].
