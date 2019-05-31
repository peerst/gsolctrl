% @doc gsolctrl top level supervisor.
% @end
-module(gsolctrl_sup).

-behavior(supervisor).

% API
-export([start_link/0]).

% Callbacks
-export([init/1]).

%--- API -----------------------------------------------------------------------

start_link() -> supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%--- Callbacks -----------------------------------------------------------------

init([]) -> {ok, { {one_for_all, 0, 1}, 
                   [
                    #{id => simple_ctrl,
                      start => {simple_ctrl, start_link, []}
                     }]}}.