%% ===================================================================
%% crystal_health - Tiny HTTP endpoint for load balancers / monitoring
%%
%% GET /health returns 200 with JSON stats when the server is up:
%%
%%   {"status":"ok","uptime_s":1234,"online_users":7,"sockets":9,
%%    "auth_mode":"enforced"}
%%
%% Anything but GET gets a 405 so probes behave predictably.
%% ===================================================================
-module(crystal_health).

-export([init/2]).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            Body = jsone:encode(#{
                <<"status">> => <<"ok">>,
                <<"uptime_s">> => uptime_seconds(),
                <<"online_users">> => crystal_registry:user_count(),
                <<"sockets">> => crystal_registry:count(),
                <<"auth_mode">> => auth_mode_bin()
            }),
            Req = cowboy_req:reply(200,
                #{<<"content-type">> => <<"application/json">>},
                Body, Req0),
            {ok, Req, State};
        _ ->
            Req = cowboy_req:reply(405,
                #{<<"allow">> => <<"GET">>}, <<>>, Req0),
            {ok, Req, State}
    end.

%% ------------------------------------------------------------------
%% Helpers
%% ------------------------------------------------------------------

auth_mode_bin() ->
    case crystal_auth:mode() of
        enforced -> <<"enforced">>;
        dev_trust -> <<"dev_trust">>
    end.

uptime_seconds() ->
    StartedAt = application:get_env(crystal_server, started_at,
                                    erlang:monotonic_time(second)),
    max(0, erlang:monotonic_time(second) - StartedAt).
