%% ===================================================================
%% crystal_sup - Supervision tree
%%
%% OTP supervisors restart crashed parts automatically. If the registry
%% ever crashes it is restarted fresh - phones simply reconnect.
%% ===================================================================
-module(crystal_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,       %% allow up to 10 restarts...
        period => 10           %% ...per 10 seconds before giving up
    },

    %% The registry keeps track of which users are online right now.
    Registry = #{
        id => crystal_registry,
        start => {crystal_registry, start_link, []},
        type => worker
    },

    %% The router owns the offline-message queue (persistent on disk).
    Router = #{
        id => crystal_router,
        start => {crystal_router, start_link, []},
        type => worker
    },

    {ok, {SupFlags, [Registry, Router]}}.
