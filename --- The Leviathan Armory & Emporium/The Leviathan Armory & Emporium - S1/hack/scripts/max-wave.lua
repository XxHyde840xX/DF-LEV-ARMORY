--Dynamically limit the next immigration wave
--[[=begin

max-wave.lua
============
Set the population cap to the lesser of current_pop + wave_size or max_pop.
Use with the `repeat` command to set a rolling immigration limit.

Usage examples::

    max-wave wave_size (max_pop)
   
    repeat -time 1 -timeUnits months -command [ max-wave 10 200 ]

The first example is abstract and only sets the population cap once;
the second will update the population cap monthly, allowing a
maximum of 10 immigrants per wave, up to a total population of 200.

=end]]

local args = {...}

local wave_size = tonumber(args[1])
local max_pop = tonumber(args[2])
local current_pop = 0

if not wave_size then
  print('max-wave: wave_size required')
  return
end

--One would think the game would track this value somewhere...
for k,v in ipairs(df.global.world.units.active) do
  if dfhack.units.isCitizen(v) or 
  (dfhack.units.isOwnCiv(v) and 
   dfhack.units.isAlive(v) and 
   df.global.world.raws.creatures.all[v.race].caste[v.caste].flags.CAN_LEARN and
   not (dfhack.units.isMerchant(v) or dfhack.units.isForest(v) or v.flags1.diplomat or v.flags2.visitor)
   )
    then
   current_pop = current_pop + 1
  end
 end

local new_limit = current_pop + wave_size
 
if max_pop and new_limit > max_pop then new_limit = max_pop end

df.global.d_init.population_cap = new_limit
print('max-wave: Population cap set to '.. new_limit)