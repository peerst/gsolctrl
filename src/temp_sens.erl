-module(temp_sens).

-export([get_temp/1]).

map_id(hot_water_buffer1) ->
    [40,255,18,91,96,23,3,62];
map_id(solar_flow) ->
    [40,255,203,173,80,23,4,182];
map_id(Id) when is_list(Id) ->
    Id.

get_temp(Name) -> 
    Id = map_id(Name),
    ok = onewire_ds18b20:convert(Id, 500),
    onewire_ds18b20:temp(Id).


    
