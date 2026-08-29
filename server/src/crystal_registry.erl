%% ===================================================================
%% crystal_registry - "Who is online right now?"
%%
%% A tiny gen_server that owns one ETS table:
%%
%%     crystal_online : UserId (binary) => [WebSocketPid, ...]
%%
%% One person can be connected from several devices at once (phone +
%% tablet), so the value is a list. WebSocket handler processes call
%% online/2 when they authenticate and offline/2 when they disconnect.
%% ===================================================================
-module(crystal_registry).

-behaviour(gen_server).

-export([start_link/0, online/2, offline/2, whereis_user/1, count/0,
         user_count/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

-define(TABLE, crystal_online).

%% ------------------------------------------------------------------
%% Public API
%% ------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Record that Pid now speaks for UserId.
online(UserId, Pid) ->
    gen_server:call(?MODULE, {online, UserId, Pid}).

%% Remove one connection of UserId (used on graceful socket close).
offline(UserId, Pid) ->
    gen_server:call(?MODULE, {offline, UserId, Pid}).

%% Which pids are currently serving this user? [] means offline.
whereis_user(UserId) ->
    try ets:lookup(?TABLE, UserId) of
        [{UserId, Pids}] -> Pids;
        [] -> []
    catch
        _:_ -> []
    end.

%% How many individual sockets are connected (for a status line).
count() ->
    try
        lists:sum([length(Pids) || {_, Pids} <- ets:tab2list(?TABLE)])
    catch
        _:_ -> 0
    end.

%% How many distinct users have at least one live socket.
user_count() ->
    try
        ets:info(?TABLE, size)
    catch
        _:_ -> 0
    end.

%% ------------------------------------------------------------------
%% gen_server callbacks
%% ------------------------------------------------------------------

init([]) ->
    ets:new(?TABLE, [set, named_table, protected, {read_concurrency, true}]),
    {ok, #{}}.

handle_call({online, UserId, Pid}, _From, State) ->
    Existing = safe_lookup(UserId),
    Pruned = [P || P <- Existing, is_process_alive(P)],
    NewPids = lists:usort([Pid | Pruned]),
    true = ets:insert(?TABLE, {UserId, NewPids}),
    {reply, ok, State};

handle_call({offline, UserId, Pid}, _From, State) ->
    case safe_lookup(UserId) of
        [] ->
            ok;
        Pids ->
            Remaining = [P || P <- Pids, P =/= Pid andalso is_process_alive(P)],
            case Remaining of
                [] -> true = ets:delete(?TABLE, UserId);
                _ -> true = ets:insert(?TABLE, {UserId, Remaining})
            end
    end,
    {reply, ok, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal helpers
%% ------------------------------------------------------------------

safe_lookup(UserId) ->
    try ets:lookup(?TABLE, UserId) of
        [{UserId, Pids}] -> Pids;
        [] -> []
    catch
        _:_ -> []
    end.
