-module(aws_iot_client_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

start_link() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
	Procs = [{aws_iot_client, { aws_iot_client, start_link, [] }, permanent, brutal_kill, worker, dynamic }],
	{ok, {{one_for_one, 1, 5}, Procs}}.
