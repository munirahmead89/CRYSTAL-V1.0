%% ===================================================================
%% crystal_router - Delivers events between users
%%
%% Given "send event E with data D from user A to user B":
%%   * if B has live sockets  -> push to every one of them
%%   * if B is offline        -> park it in crystal_store for later
%%
%% The mobile app uses this single pipe for everything real-time:
%% chat messages, typing dots, read receipts, and call ringing.
%% ===================================================================
-module(crystal_router).

-behaviour(gen_server).

-export([start_link/0, deliver/4, drain/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

-define(SERVER, ?MODULE).

%% ------------------------------------------------------------------
%% Public API
%% ------------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% Push {Event, Data} from FromUserId to ToUserId. Returns delivered or
%% queued so the caller can ack the sender accurately.
deliver(ToUserId, FromUserId, Event, Data) ->
    case crystal_registry:whereis_user(ToUserId) of
        [] ->
            %% Nobody home: store for later replay.
            ok = crystal_store:enqueue(ToUserId, FromUserId, Event, Data),
            {ok, queued};
        Pids ->
            Frame = event_frame(FromUserId, Event, Data),
            lists:foreach(fun(Pid) -> Pid ! {push, Frame} end, Pids),
            {ok, delivered}
    end.

%% Replay everything parked for UserId while they were away, then clear.
drain(UserId) ->
    Queued = crystal_store:take_all(UserId),
    lists:foreach(
        fun(#{ref := Ref, from := From, event := Event, data := Data}) ->
            case crystal_registry:whereis_user(UserId) of
                [] ->
                    %% They vanished again mid-drain; leave the rest stored.
                    ok;
                Pids ->
                    Frame = event_frame(From, Event, Data),
                    lists:foreach(fun(Pid) -> Pid ! {push, Frame} end, Pids),
                    crystal_store:remove(UserId, Ref)
            end
        end,
        Queued),
    {ok, length(Queued)}.

%% ------------------------------------------------------------------
%% gen_server boilerplate (owns nothing hot; calls are stateless)
%% ------------------------------------------------------------------

init([]) ->
    ok = crystal_store:open(),
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    _ = dets:sync(crystal_offline),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal helpers
%% ------------------------------------------------------------------

event_frame(From, Event, Data) ->
    jsone:encode(#{
        <<"type">> => <<"event">>,
        <<"from">> => From,
        <<"event">> => Event,
        <<"data">> => Data
    }).
