%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_tcp_socket).
-behaviour(gen_listener_tcp).

-define(TCP_PORT, 5555).
-define(TCP_OPTS, [binary, inet,
                   {ip,           {127,0,0,1}},
                   {active,       false},
                   {send_timeout, 5000},
                   {backlog,      10},
                   {nodelay,      true},
                   {packet,       raw},
                   {reuseaddr,    true}]).

%% --------------------------------------------------------------------
%% External exports
-export([start/5, start_link/5, sockname/1]).

%% gen_listener_tcp callbacks
-export([init/1, handle_accept/2, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%%-record(state, {}).

-ifdef(debug).
-define(SERVER_OPTS,{debug,[trace]}).
-else.
-define(SERVER_OPTS,).
-endif.

%% ====================================================================
%% External functions
%% ====================================================================

%% @doc Start the server.
start(Version, Type, Identity, Port, Opts) ->
    gen_listener_tcp:start(?MODULE, [self(), Version, Type, Identity, Port, Opts], [?SERVER_OPTS]).

start_link(Version, Type, Identity, Port, Opts) ->
    gen_listener_tcp:start_link(?MODULE, [self(), Version, Type, Identity, Port, Opts], [?SERVER_OPTS]).

sockname(Listener) ->
    case gen_listener_tcp:sockname(Listener) of
	{ok, {Address, Port}} ->
	    {ok, {tcp, Address, Port}};
	Other ->
	    Other
    end.

init([MqSocket, Version, Type, Identity, Port, Opts]) ->
    {ok, {Port, Opts}, {MqSocket, Version, Type, Identity}}.

handle_accept(Sock, State = {MqSocket, Version, Type, Identity}) ->
    case ezmq_link:start_connection() of
        {ok, Pid} ->
            ezmq_link:accept(MqSocket, Version, Type, Identity, Pid, Sock);
        Other ->
            logger:warning("failed to handle accept with error ~p", [Other]),
            gen_tcp:close(Sock)
    end,
    {noreply, State}.

handle_call(Request, _From, State) ->
    {reply, {illegal_request, Request}, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    logger:debug("ezmq_tcp_socket terminate on ~p", [_Reason]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
