%% ===================================================================
%% crystal_ws - One Erlang process per connected phone
%%
%% Cowboy hands every new WebSocket connection to websocket_init/1 and
%% this module then owns the conversation. The wire format is plain
%% JSON text frames:
%%
%%   client -> server:
%%     {"type":"auth","user_id":"<id>","token":"<optional>"}
%%     {"type":"ping"}
%%     {"type":"send","ref":"<any id>","to":"<user id>",
%%      "event":"message|typing|receipt|call-*","data":{...}}
%%
%%   server -> client:
%%     {"type":"welcome","user_id":"..."}          (auth accepted)
%%     {"type":"error","reason":"..."}             (auth rejected etc.)
%%     {"type":"pong"}                             (heartbeat answer)
%%     {"type":"ack","ref":"...","ok":true,"mode":"delivered|queued"}
%%     {"type":"event","from":"...","event":"...","data":{...}}
%%
%% Phones must send "auth" as their first frame; anything else before
%% auth is answered with an error and the socket is closed.
%% ===================================================================
-module(crystal_ws).

-behaviour(cowboy_websocket).

-export([init/2, websocket_init/1, websocket_handle/2, websocket_info/2,
         terminate/3]).

%% How long a socket may stay silent before Cowboy drops it. The app
%% pings well inside this window, so only truly dead connections die.
-define(IDLE_TIMEOUT, 120000). %% milliseconds

%% Abuse protection: at most RATE_LIMIT_MSGS "send" frames per sliding
%% RATE_LIMIT_WINDOW_MS per connection. Pings are free.
-define(RATE_LIMIT_MSGS, 120).
-define(RATE_LIMIT_WINDOW_MS, 10000).

%% Largest inbound WebSocket frame we accept (256 KiB) - set on the
%% upgrade request so oversized frames never reach the handler.
-define(MAX_FRAME_SIZE, 262144).

%% ------------------------------------------------------------------
%% HTTP upgrade phase
%% ------------------------------------------------------------------

init(Req0, State) ->
    Opts = #{
        idle_timeout => ?IDLE_TIMEOUT,
        max_frame_size => ?MAX_FRAME_SIZE
    },
    {cowboy_websocket, Req0, State#{rate => init_rate()}, Opts}.

%% ------------------------------------------------------------------
%% WebSocket lifecycle
%% ------------------------------------------------------------------

websocket_init(State) ->
    %% Not authenticated yet.
    {[], State#{authenticated => false, user_id => undefined}}.

websocket_handle({text, Raw}, State = #{authenticated := false}) ->
    case decode(Raw) of
        #{<<"type">> := <<"auth">>, <<"user_id">> := UserId} = Frame ->
            Token = maps:get(<<"token">>, Frame, undefined),
            case crystal_auth:verify(UserId, Token) of
                ok ->
                    ok = crystal_registry:online(UserId, self()),
                    Welcome = jsone:encode(#{
                        <<"type">> => <<"welcome">>,
                        <<"user_id">> => UserId
                    }),
                    %% Replay anything that arrived while offline, then
                    %% confirm to the client we are fully live.
                    _ = crystal_router:drain(UserId),
                    {[{text, Welcome}], State#{authenticated => true, user_id => UserId}};
                {error, Reason} ->
                    Error = jsone:encode(#{
                        <<"type">> => <<"error">>,
                        <<"reason">> => atom_to_binary(Reason)
                    }),
                    {[{text, Error}, close], State}
            end;
        _ ->
            Error = jsone:encode(#{
                <<"type">> => <<"error">>,
                <<"reason">> => <<"auth required first">>
            }),
            {[{text, Error}], State}
    end;

websocket_handle({text, Raw}, State = #{authenticated := true, user_id := Me}) ->
    case decode(Raw) of
        #{<<"type">> := <<"ping">>} ->
            {[{text, <<"{\"type\":\"pong\"}">>}], State};

        #{<<"type">> := <<"send">>,
          <<"to">> := To, <<"event">> := Event} = Frame ->
            case allow_send(State) of
                {ok, State2} ->
                    Data = maps:get(<<"data">>, Frame, #{}),
                    Ref = maps:get(<<"ref">>, Frame, null),
                    {ok, Mode} = crystal_router:deliver(To, Me, Event, Data),
                    Ack = jsone:encode(#{
                        <<"type">> => <<"ack">>,
                        <<"ref">> => Ref,
                        <<"ok">> => true,
                        <<"mode">> => Mode
                    }),
                    {[{text, Ack}], State2};
                limited ->
                    Error = jsone:encode(#{
                        <<"type">> => <<"error">>,
                        <<"reason">> => <<"rate limited">>
                    }),
                    %% Drop the connection: a well-behaved client will
                    %% reconnect with backoff and continue cleanly.
                    {[{text, Error}, close], State}
            end;

        _ ->
            %% Unknown frames are ignored so newer clients and older
            %% servers can coexist gracefully.
            {[], State}
    end;

websocket_handle(_Other, State) ->
    {[], State}.

%% Messages arriving from other processes (the router pushes here).
websocket_info({push, FrameBin}, State) ->
    {[{text, FrameBin}], State};

websocket_info(_Info, State) ->
    {[], State}.

terminate(_Reason, _Req, #{authenticated := true, user_id := UserId}) ->
    ok = crystal_registry:offline(UserId, self()),
    ok;
terminate(_Reason, _Req, _State) ->
    ok.

%% ------------------------------------------------------------------
%% Internal helpers
%% ------------------------------------------------------------------

init_rate() ->
    {0, erlang:monotonic_time(millisecond)}.

%% Fixed-window limiter: counts "send" frames per connection. Returns
%% {ok, NewState} when allowed, `limited` when the window is exhausted.
allow_send(State = #{rate := {Count, WindowStart}}) ->
    Now = erlang:monotonic_time(millisecond),
    Elapsed = Now - WindowStart,
    case Elapsed >= ?RATE_LIMIT_WINDOW_MS of
        true ->
            %% Window rolled over - start a fresh one with this frame.
            {ok, State#{rate => {1, Now}}};
        false when Count < ?RATE_LIMIT_MSGS ->
            {ok, State#{rate => {Count + 1, WindowStart}}};
        _ ->
            limited
    end.

decode(Bin) ->
    try
        jsone:decode(Bin)
    catch
        _:_ -> #{}
    end.
