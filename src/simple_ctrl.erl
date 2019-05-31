-module(simple_ctrl).

-behaviour(gen_server).

%% API
-export([start/0, start_link/0, trigger_pump/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3, format_status/2]).

-define(cycle_time, 5*1000).
-define(trigger_cycle, 15*1000).
-define(give_up, 3*1000).
-define(hyst, 5.0).

-record(state, {pump1, buffer1_valve, hot_water_buffer1, solar_flow,
                trying}).

start() ->
    gen_server:start({local, ?MODULE}, ?MODULE, [], []).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

trigger_pump(1) ->
    gen_server:cast(?MODULE, trigger_pump1).


init([]) ->
    timer:send_interval(?trigger_cycle, trigger),
    timer:send_interval(?cycle_time, measure),
    self() ! trigger,
    {ok, #state{pump1 = off,
                buffer1_valve = bypass,
                hot_water_buffer1 = 0.0,
                solar_flow = 0.0,
                trying = false}}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(measure, State) ->
    Hw = get_recorded_temp(hot_water_buffer1),
    Sf = get_recorded_temp(solar_flow),
    S1 = State#state{hot_water_buffer1=Hw,
                     solar_flow=Sf},
    {noreply, update_actuators(control_logic(S1))};
handle_info(trigger, State) ->
    erlang:send_after(?give_up, self(), give_up),
    {noreply, update_actuators(control_logic(State#state{trying=true}))};
handle_info(give_up, State) ->
    {noreply, update_actuators(control_logic(State#state{trying=false}))};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

format_status(_Opt, Status) ->
    Status.

control_logic(State) ->
    control_logic0(control_logic1(State)).

control_logic0(#state{trying=T, buffer1_valve=B}=State)
  when T =:= true; B =:= loading ->
    State#state{pump1 = on};
control_logic0(State) ->
    State#state{pump1 = off}.

control_logic1(#state{solar_flow = Sf, hot_water_buffer1=Hw, 
                      pump1=P1}=State)
  when P1 =:= on, Sf > Hw + ?hyst ->
    State#state{buffer1_valve = loading};
control_logic1(#state{solar_flow = Sf, hot_water_buffer1=Hw, 
                      pump1=P1}=State)
  when P1 =:= off; Sf < Hw ->
    State#state{buffer1_valve = bypass};
control_logic1(State) ->
    State.

update_actuators(#state{pump1 = P1, buffer1_valve = B1}=State) ->
    case B1 of
        loading -> grisp_led:color(2, red);
        bypass -> grisp_led:off(2)
    end,
    case P1 of
        on -> grisp_led:color(1, blue);
        off -> grisp_led:off(1)
    end,
    State.

get_recorded_temp(Sens) ->            
    Val = temp_sens:get_temp(Sens),
    record_temp(Sens, Val),
    Val.

record_temp(Sens, Value) ->
    Data = iolist_to_binary(
             io_lib:format("sol,type=temp,unit=celsius,sensor=~p value=~f\n", 
                           [Sens, Value])),
    httpc:request(post, {"http://yrael:8086/write?db=gsolctrl", [], 
                         "application/binary", 
                         Data}, [], []).