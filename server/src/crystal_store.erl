%% ===================================================================
%% crystal_store - Offline message storage (survives restarts)
%%
%% Messages that arrive while the recipient is offline are parked in a
%% DETS file (disk-based Erlang Term Storage). When the person comes
%% back online, crystal_router replays everything and clears it.
%%
%% This is what makes delivery "guaranteed-ish" like WhatsApp: send a
%% message to a sleeping phone, they wake up, they receive it.
%% ===================================================================
-module(crystal_store).

-export([open/0, enqueue/4, take_all/1, remove/2]).

-define(TABLE, crystal_offline).

%% The offline queue lives in CRYSTAL_DATA_DIR (default ".") so Docker
%% and systemd units can point it at a persistent volume.
dets_path() ->
    Dir = case os:getenv("CRYSTAL_DATA_DIR") of
        false -> ".";
        "" -> ".";
        D -> D
    end,
    filename:join(unicode:characters_to_list(Dir), "crystal_offline.dets").

open() ->
    %% auto_save keeps the on-disk copy fresh without manual flushes.
    case dets:open_file(?TABLE, [{file, dets_path()}, {auto_save, 5000}]) of
        {ok, _} -> ok;
        {error, Reason} ->
            io:format("WARNING: could not open offline store (~p); "
                      "offline queueing disabled this run~n", [Reason]),
            ok
    end.

%% Park one event for a user who is currently offline.
%% Key = {UserId, UniqueId} so replay order is stable per user.
enqueue(UserId, From, Event, Data) ->
    Ref = erlang:unique_integer([positive, monotonic]),
    true = dets:insert(?TABLE, {{UserId, Ref}, From, Event, Data}),
    dets:sync(?TABLE),
    {ok, Ref}.

%% Fetch every queued event for UserId (oldest first).
take_all(UserId) ->
    Matches = dets:match(?TABLE, {{UserId, '$1'}, '$2', '$3', '$4'}),
    Sorted = lists:sort([{Ref, From, Event, Data} ||
                            [Ref, From, Event, Data] <- Matches]),
    [#{ref => Ref, from => From, event => Event, data => Data}
     || {Ref, From, Event, Data} <- Sorted].

%% Delete a single queued event once it has been delivered.
remove(UserId, Ref) ->
    dets:delete(?TABLE, {UserId, Ref}),
    dets:sync(?TABLE).
