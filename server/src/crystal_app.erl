%% ===================================================================
%% crystal_app - Application entry point
%%
%% Starts the supervision tree and the WebSocket listener.
%%
%% Configuration (environment variables):
%%   CRYSTAL_WS_PORT          - listen port            (default 8081)
%%   CRYSTAL_WS_MAX_CONN      - max simultaneous conns (default 50000)
%%   SUPABASE_JWT_SECRET      - when set, auth is ENFORCED (HS256 JWT);
%%                              when absent the server runs in
%%                              trust-the-id DEV mode and warns loudly.
%%   CRYSTAL_WS_CERTFILE      - TLS certificate chain (PEM). When set
%%   CRYSTAL_WS_KEYFILE         together with the key the listener uses
%%                              TLS (wss://); otherwise plain TCP.
%%   CRYSTAL_DATA_DIR         - where the offline queue lives
%%                              (default ".", set to /data in Docker)
%% ===================================================================
-module(crystal_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    Port = int_env("CRYSTAL_WS_PORT", 8081),
    MaxConn = int_env("CRYSTAL_WS_MAX_CONN", 50000),

    ok = application:set_env(crystal_server, started_at,
                             erlang:monotonic_time(second)),

    %% Two routes: /ws upgrades to WebSocket; /health answers plain GETs.
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/ws", crystal_ws, []},
            {"/health", crystal_health, []}
        ]}
    ]),

    Env = #{env => #{dispatch => Dispatch},
            max_connections => MaxConn},

    ListenerResult =
        case {os:getenv("CRYSTAL_WS_CERTFILE"), os:getenv("CRYSTAL_WS_KEYFILE")} of
            {CertFile, KeyFile} when CertFile =/= false, CertFile =/= "",
                                     KeyFile =/= false, KeyFile =/= "" ->
                cowboy:start_tls(crystal_listener,
                    [{port, Port},
                     {certfile, unicode:characters_to_list(CertFile)},
                     {keyfile, unicode:characters_to_list(KeyFile)}],
                    Env);
            _ ->
                cowboy:start_clear(crystal_listener, [{port, Port}], Env)
        end,

    case ListenerResult of
        {ok, _Listener} ->
            {ok, Pid} = crystal_sup:start_link(),
            report_startup(Port),
            {ok, Pid};
        {error, Reason} ->
            io:format("~n!!! Crystal server failed to listen on port ~p: ~p~n",
                      [Port, Reason]),
            {error, Reason}
    end.

stop(_State) ->
    ok = cowboy:stop_listener(crystal_listener).

%% ------------------------------------------------------------------
%% Internal helpers
%% ------------------------------------------------------------------

report_startup(Port) ->
    Scheme = case os:getenv("CRYSTAL_WS_CERTFILE") of
        false -> "ws";
        "" -> "ws";
        _ -> "wss"
    end,
    io:format("~n=== Crystal Messenger real-time server listening on "
              "port ~p (~s) ===~n", [Port, Scheme]),
    case crystal_auth:mode() of
        enforced ->
            io:format("=== Auth mode: ENFORCED (Supabase JWT verification) ===~n");
        dev_trust ->
            io:format("!!! Auth mode: DEV TRUST - any user id is accepted.~n"
                      "!!! Set SUPABASE_JWT_SECRET before going to production.~n")
    end.

int_env(Name, Default) ->
    case os:getenv(Name) of
        false -> Default;
        "" -> Default;
        Raw ->
            try
                list_to_integer(Raw)
            catch
                _:_ -> Default
            end
    end.
