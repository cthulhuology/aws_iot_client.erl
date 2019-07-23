%% aws_iot_client
%%
%%
%%
-module(aws_iot_client).

-behavior(gen_server).

-record(exchange, {
          name, type, durable, auto_delete, internal, arguments, %% immutable
          scratches,       %% durable, explicitly updated via update_scratch/3
          policy,          %% durable, implicitly updated when policy changes
          operator_policy, %% durable, implicitly updated when policy changes
          decorators,
          options = #{}}).    %% transient, recalculated in store/1 (i.e. recovery)

-export([ subscribe/1, publish/2 ]).
-export([ init/1, start_link/0, handle_cast/2, handle_call/3, handle_info/2, terminate/2, code_change/3 ]).

%%-----------------------------------------------------------------------------

subscribe(Topic) ->
	gen_server:cast(?MODULE, { subscribe, Topic }).

publish(Topic,Message) ->
	gen_server:cast(?MODULE, { publish, Topic, Message }).


%%-----------------------------------------------------------------------------

start_link() ->
	gen_server:start_link( { local, ?MODULE }, ?MODULE, [], [] ).

init([]) ->
	Config = application:get_all_env(?MODULE),
	io:format("Config is ~p~n", [ Config ]),
	Certs = proplists:get_value(certsdir, Config),
	Host = proplists:get_value(host, Config),
	Port = proplists:get_value(port, Config),
	ClientId = proplists:get_value(client_id, Config),
	Cert = proplists:get_value(certfile, Config),
	Keyfile = proplists:get_value(keyfile, Config),
	CACert = proplists:get_value(cacertfile, Config),
	Exchange = proplists:get_value(exchange, Config),
	{ ok, Client } = emqttc:start_link([
		{ host, Host },
		{ port, Port },
		{ client_id, ClientId },
		{ ssl, [
			{ certfile, Certs ++ "/" ++ Cert },
			{ keyfile, Certs ++ "/"  ++ Keyfile },
			{ cacertfile,  Certs ++ "/" ++ CACert }
		]},
		{ auto_resub, true },
		{ reconnect, 0 }
	]),
	{ ok, [{ client, Client }, { config, Config }, { exchange, Exchange }] }.

handle_cast({ subscribe, Topic }, State) ->
	Client = proplists:get_value(client, State),
	ok = emqttc:subscribe(Client,Topic,qos0),
	{ noreply, State };

handle_cast({ publish, Topic, Message }, State) ->
	Client = proplists:get_value(client, State),
	emqttc:publish(Client,Topic,Message),
	{ noreply, State };

handle_cast(Message,State) ->
	io:format("Unknown message ~p~n", [ Message ]),
	{ noreply, State }.

handle_call(Message, _From, State) ->
	io:format("Unknown message ~p~n", [ Message ]),
	{ reply, ok, State }.

handle_info({ mqttc, _C, connected }, State) ->
	io:format("Connected~n"),
	{ noreply,  State };

handle_info({ publish, Topic, Message }, State) ->
	Exchange = proplists:get_value(exchange,State),
	io:format("Publishing ~p -> ~p / ~p~n",[ Message, Topic, Exchange ]),
	Res = rabbit_basic:publish(#exchange{ name = Exchange },Topic,[],Message),
	io:format("Publish result ~p~n", [ Res ]),
	{ noreply, State };

handle_info(Message,State) ->
	io:format("Info Msg: ~p~n", [ Message ]),
	{ noreply,  State }.

terminate(Reason,_State) ->
	io:format("terminating ~p~n", [ Reason ]),
	Reason.

code_change(_OldVsn, _State, _Extra) ->
	io:format("code change ~n"),
	ok.

