--  Allows manipulation of region biomes, mainly changing of evilness and addition/removal of plants and creatures from biome regions.
--
--[====[

biomemanipulator
================
--  The biome determination logic is mainly copied and adapted from https://github.com/ragundo/exportmaps/blob/master/cpp/df_utils/biome_type.cpp#L105
--
]====]
local gui = require 'gui'
local dialog = require 'gui.dialogs'
local widgets = require 'gui.widgets'
local guiScript = require 'gui.script'
local utils = require 'utils'

local Grids = {}
local Main_Page = {}
local Animal_Page = {}
local Plant_Page = {}
local Cavern_Page = {}
local Weather_Page = {}
local Geo_Page = {}
local Map_Page = {}
local River_Page = {}
local Help_Page = {}
local rng = dfhack.random.new ()
local river_matrix = {}
local current_river = -1
local river_truncate_accepted = false
local river_clear_accepted = false
local river_delete_accepted = false
local lost_rivers_present = false

--================================================================
--  The Grid widget defines an pen supporting X/Y character display grid supporting display of
--  a grid larger than the frame allows through a panning viewport. The init function requires
--  the specification of the width and height attributes that defines the grid dimensions.
--  The grid coordinates are 0 based.
--  Version 0.2 2017-11-11 (Screen resizing added, fixed viewport initial width allocation).
--
Grid = defclass (Grid, widgets.Widget)
Grid.ATTRS =
  {width = DEFAULT_NIL,
   height = DEFAULT_NIL}

--================================================================

function Grid:init ()
  if type (self.width) ~= 'number' or
     type (self.height) ~= 'number' or
     type (self.frame.w) ~= 'number' or
     type (self.frame.h) ~= 'number' or
     self.width < 0 or
     self.height < 0 then
    error ("Grid widgets have to have their widths and heights set permanently on initiation")
    return
  end
  
  self.grid = dfhack.penarray.new (self.width, self.height)
  
  self.viewport = {x1 = 0,
                   x2 = self.frame.w - 1,
                   y1 = 0,
                   y2 = self.frame.h - 1}
end

--================================================================

function Grid:panTo (x, y)
  local x_size = self.viewport.x2 - self.viewport.x1 + 1
  local y_size = self.viewport.y2 - self.viewport.y1 + 1
  
  self.viewport.x1 = x

  if self.viewport.x1 + x_size > self.width then
    self.viewport.x1 = self.width - x_size
  end
  
  if self.viewport.x1 < 0 then
    self.viewport.x1 = 0
  end
  
  self.viewport.x2 = self.viewport.x1 + x_size - 1
  
  self.viewport.y1 = y
  
  if self.viewport.y1 + y_size > self.height then
    self.viewport.y1 = self.height - y_size
  end
  
  if self.viewport.y1 < 0 then
    self.viewport.y1 = 0
  end
  
  self.viewport.y2 = self.viewport.y1 + y_size - 1
end

--================================================================
--  Pans the viewport in the X and Y dimensions the number of steps specified by the parameters.
--  It will stop the panning at 0, however, and will not pan outside of the grid (a grid smaller)
--  than the frame will still have non grid parts in the frame, of course).
--
function Grid:pan (x, y)
  self:panTo (self.viewport.x1 + x, self.viewport.y1 + y)
end

--================================================================

function Grid:panCenter (x, y)
  self:panTo (x - math.floor ((self.viewport.x2 - self.viewport.x1 + 1) / 2),
              y - math.floor ((self.viewport.y2 - self.viewport.y1 + 1) / 2))
end

--================================================================

function Grid:screenResized (screen_width, screen_height, lock_width, lock_height, center_x, center_y)
  local available_width = screen_width - self.frame.l - 1
  local available_height = screen_height - self.frame.t - 1
  local current_width = self.viewport.x2 - self.viewport.x1 + 1
  local current_height = self.viewport.y2 - self.viewport.y1 + 1
  
  if not locked_width then
    if current_width == self.width then
      if current_width > available_width then
        self.frame.w = available_width
      end
      
    else
      if available_width >= self.width then
        self.frame.w = self.width
        
      else
        self.frame.w = available_width
      end
    end
    
    self.viewport.x1 = 0
    self.viewport.x2 = self.frame.w - 1
  end
  
  if not locked_height then
    if current_height == self.height then
      if current_height > available_height then
        self.frame.h = available_height
      end
      
    else
      if available_height >= self.height then
        self.frame.h = self.height
        
      else
        self.frame.h = available_height
      end
    end
    self.viewport.y1 = 0
    self.viewport.y2 = self.frame.h - 1
  end

  self:panCenter (center_x, center_y)
end

--================================================================
--  Assigns a value to the specified grid (not frame) coordinates. The 'pen'
--  parameter has to be a DFHack 'pen' table or object.
--
function Grid:set (x, y, pen)
  if x < 0 or x >= self.width then
    error ("Grid:set error: x out of bounds " .. tostring (x) .. " vs 0 - " .. tostring (self.width - 1))
    return
    
  elseif y < 0 or y >= self.height then
    error ("Grid:set error: y out of bounds " .. tostring (y) .. " vs 0 - " .. tostring (self.height - 1))
    return
  end

  self.grid:set_tile (x, y, pen)
end

--================================================================
--  Returns the data at position x, y in the grid.
--
function Grid:get (x, y)
  if x < 0 or x >= self.width then
    error ("Grid:set error: x out of bounds " .. tostring (x) .. " vs 0 - " .. tostring (self.width - 1))
    return
    
  elseif y < 0 or y >= self.height then
    error ("Grid:set error: y out of bounds " .. tostring (y) .. " vs 0 - " .. tostring (self.height - 1))
    return
  else
    return self.grid:get_tile (x, y)
  end
end

--================================================================
--  Renders the contents within the viewport into the frame.
--
function Grid:onRenderBody (dc)
  self.grid:draw (self.frame.l,
                  self.frame.t,
                  self.viewport.x2 - self.viewport.x1 + 1,
                  self.viewport.y2 - self.viewport.y1 + 1,
                  self.viewport.x1,
                  self.viewport.y1)
end

--================================================================
--  Support function to decompose a DFHack release number for the operation below
--
function decomposeDFHackReleaseNumber (release)
  local punctuation_1
  local punctuation_2
  local dash
  local major
  local medium
  local minor
  local rel
  
  punctuation_1 = release:find ('.', 1, #release, true)
  if punctuation_1 == nil then
    error ("decompose fails to find first puncuation in " .. release)
  end
  
  major = tonumber (release:sub (1, punctuation_1 - 1))
  if type (major) ~= 'number' then
    error ("decompose fails to extract major release number from " .. release)
  end
  
  punctuation_2 = release:find ('.', punctuation_1 + 1, #release, true)
  if punctuation_2 == nil then
    error ("decompose fails to find second puncuation in " .. release)   
  end
  
  medium = tonumber (release:sub (punctuation_1 + 1, punctuation_2 - 1))
  if type (medium) ~= 'number' then
    error ("decompose fails to extract medium release number from " .. release)
  end
  
  dash = release:find ('-', punctuation_2 + 1, #release, plain)
  if dash == nil then
    error ("decompose fails to find dash in " .. release)
  end
  
  minor = tonumber (release:sub (punctuation_2 + 1, dash - 1))
  if type (minor) ~= 'number' then
    error ("decompose fails to extract minor release number from " .. release)
  end
    
  if release:sub (dash + 1, dash + 1) ~= 'r' then
    if release:len () > dash + 5 and
       release:sub (dash + 1, dash + 5) == "alpha" then
      rel = tonumber (release:sub (dash + 6, #release)) / 1000
    
    elseif release:len () > dash + 4 and
       release:sub (dash + 1, dash + 4) == "beta" then
      rel = tonumber (release:sub (dash + 5, #release)) / 100
      
    elseif release:len () > dash + 5 and
       release:sub (dash + 1, dash + 5) == "gamma" then
      rel = tonumber (release:sub (dash + 6, #release)) / 10
      
    else
      error ("decompose fails to DFHack version (including any alpha, beta, or gamma) from " .. release)
    end
  
  else
    rel = tonumber (release:sub (dash + 2, #release))
  end
  
  if type (rel) ~= 'number' then
    error ("decompose fails to extract DFHack release number from " .. release)
  end
  
  return major, medium, minor, rel
end

--================================================================
--  Reports whether a DFHack version is older than a given version to allow for scripts to detect which path to execute
--  to support older DFHack versions (for instance when the DFHack structures morph or fields change names).
--
function isDFHackOlderThan (reference)
  if type (reference) ~= 'string' then
    error ("isDFHackOlderThan takes a string parameter " .. tostring (reference))
  end
  
  local major_release, medium_release, minor_release, release_release = decomposeDFHackReleaseNumber (dfhack.getDFHackVersion ())
  local major_reference, medium_reference, minor_reference, release_reference = decomposeDFHackReleaseNumber (reference)

  if major_release ~= major_reference then
    return major_release < major_reference
  end
  
  if medium_release ~= medium_reference then
    return medium_release < medium_reference
  end
  
  if minor_release ~= minor_reference then
    return minor_release < minor_reference
  end
  
  return release_release < release_reference
end

--================================================================

function move_cursor (original_x, original_y, target_x, target_y)
  local screen = dfhack.gui.getCurViewscreen ()
  local large_x = math.floor (math.abs (original_x - target_x) / 10)
  local small_x = math.abs (original_x - target_x) % 10
  local large_y = math.floor (math.abs (original_y - target_y) / 10)
  local small_y = math.abs (original_y - target_y) % 10
  
  while (large_x > 0 or large_y > 0) do
    if large_x > 0 and large_y > 0 then
      if original_x - target_x > 0 and original_y - target_y > 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_UPLEFT_FAST)
        
      elseif original_x - target_x > 0 and original_y - target_y < 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_DOWNLEFT_FAST)
        
      elseif original_y - target_y > 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_UPRIGHT_FAST)
        
      else
        screen.parent:feed_key (df.interface_key.CURSOR_DOWNRIGHT_FAST)
      end
      
      large_x = large_x - 1
      large_y = large_y - 1
      
    elseif large_x > 0 then
      if original_x - target_x > 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_LEFT_FAST)
        
      else
        screen.parent:feed_key (df.interface_key.CURSOR_RIGHT_FAST)
      end
      
      large_x = large_x - 1
    
    else
      if original_y - target_y > 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_UP_FAST)
        
      else
        screen.parent:feed_key (df.interface_key.CURSOR_DOWN_FAST)
      end
      
      large_y = large_y - 1
    end
  end
  
  while small_x > 0 or small_y > 0 do
    if small_x > 0 and small_y > 0 then
      if original_x - target_x > 0 and original_y - target_y > 0 then     
        screen.parent:feed_key (df.interface_key.CURSOR_UPLEFT)
        
      elseif original_x - target_x > 0 and original_y - target_y < 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_DOWNLEFT)
        
      elseif original_y - target_y > 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_UPRIGHT)
        
      else
        screen.parent:feed_key (df.interface_key.CURSOR_DOWNRIGHT)        
      end
      
      small_x = small_x - 1
      small_y = small_y - 1
      
    elseif small_x > 0 then
      if original_x - target_x > 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_LEFT)
        
      else
        screen.parent:feed_key (df.interface_key.CURSOR_RIGHT)        
      end
      
      small_x = small_x - 1
      
    else
      if original_y - target_y > 0 then
        screen.parent:feed_key (df.interface_key.CURSOR_UP)
        
      else
        screen.parent:feed_key (df.interface_key.CURSOR_DOWN)        
      end
      
      small_y = small_y - 1
    end
  end
end

--================================================================
--================================================================

function biomemanipulator ()
  local map_width = df.global.world.world_data.world_width
  local map_height = df.global.world.world_data.world_height
  local pole = df.global.world.world_data.flip_latitude
  local evilness
  local region = {[-1] = 0,
                  [0] = NIL,
                  [1] = NIL,
                  [2] = NIL,
                  [3] = NIL}
  local animals = {[-1] = 0,
                   [0] = 0,
                   [1] = 0,
                   [2] = 0,
                   [3] = 0}
  local plants = {[-1] = 0,
                   [0] = 0,
                   [1] = 0,
                   [2] = 0,
                   [3] = 0}
  local size = {[-1] = 0,
                [0] = 0,
                [1] = 0,
                [2] = 0,
                [3] = 0}
  local layer_image = {[-1] = "Surface",
                       [0] = "Cavern 1",
                       [1] = "Cavern 2",
                       [2] = "Cavern 3",
                       [3] = "Magma Sea"}
  
  local Surface = -1
  local x
  local y
  local savagery
  local Focus = "Main"
  local Layer = Surface
  local Unrestricted = false
    
  local Max_Geo_Layer_Name_Length = 0
  local Max_Geo_Type_Name_Length = string.len ("SEDIMENTARY_OCEAN_SHALLOW")
  
  for i, material in ipairs (df.global.world.raws.inorganics) do
    if material.flags.SEDIMENTARY or
       material.flags.IGNEOUS_INTRUSIVE or
       material.flags.IGNEOUS_EXTRUSIVE or
       material.flags.METAMORPHIC or
       material.flags.SOIL then
      if string.len (material.id) > Max_Geo_Layer_Name_Length then
        Max_Geo_Layer_Name_Length = string.len (material.id)
      end
    end
  end
  
  local Max_Geo_Vein_Name_Length = 0
  
  for i, material in ipairs (df.global.world.raws.inorganics) do
    if #material.environment_spec.mat_index ~= 0 or
       #material.environment.location ~= 0 then
      if string.len (material.id) > Max_Geo_Vein_Name_Length then
        Max_Geo_Vein_Name_Length = string.len (material.id)
      end
    end
  end

  local Max_Geo_Cluster_Name_Length = string.len ("CLUSTER_LARGE")
  local Max_Soil_Depth
  
  --  Backwards compatibility detection
  --  
  local river_type_updated = false
  if true then  --  To get the temporary variable's context expire
    local river = df.world_river:new()
    for i, k in pairs (river) do
      if i == "flow" then
        river_type_updated = true
        break
      end
    end
    river:delete ()
  end
  
  local underground_region_type_updated = false
  if true then
    local world_underground_region = df.world_underground_region:new()
    for i, k in pairs (world_underground_region) do
      if i == "water" then
        underground_region_type_updated = true
        break
      end
    end
    world_underground_region:delete ()
  end
  
  local interaction_target_material_type_updated = false
  if true then
    local interaction_target = df.interaction_target_materialst:new()
    for i, k in pairs (interaction_target) do
      if i == "mat_type" then
        interaction_target_material_type_updated = true
        break
      end
    end
    interaction_target:delete ()
  end
  
  local movement_supported = not isDFHackOlderThan ("0.43.05-r2")

  local region_evil_named = false
  local region_trees_named = false
  local reanimating_named = false
  
  if true then
    local region = df.world_region:new ()
    for i, k in pairs (region) do
      if i == "evil" then
        region_evil_named = true
        
      elseif i == "tree_biomes" then
        region_trees_named = true
      
      elseif i == "reanimating" then
        reanimating_named = true
      end
    end
    
    region:delete ()
  end
  
  local creature_raw_flags_renamed = false
  if true then
    local creature = df.creature_raw:new ()
    for i, k in pairs (creature.flags) do
      if i == "HAS_ANY_MEGABEAST" then
        creature_raw_flags_renamed = true
        break
      end
    end
    creature:delete ()
  end
  
  --============================================================

  function Is_Animal (value)
    return value == df.world_population_type.Animal or
           value == df.world_population_type.Vermin or
           value == df.world_population_type.VerminInnumerable or
           value == df.world_population_type.ColonyInsect     
  end
  
  --============================================================

  function Is_Plant (value)
    return value == df.world_population_type.Tree or
           value == df.world_population_type.Grass or
           value == df.world_population_type.Bush
  end
  
  --============================================================

  if #df.global.world.world_data.region_details ~= 0 then
    x = df.global.world.world_data.region_details [0].pos.x
    y = df.global.world.world_data.region_details [0].pos.y
    region [Surface] = df.global.world.world_data.region_map [x]:_displace (y).region_id
  
  else
    if true then  --  Backwards compatibility. Detect whether new or the old incorrect name is used.
      local world = df.world:new ()
      
      for i, k in pairs (world.worldgen_status) do
        if i == "width" then
          x = df.global.world.worldgen_status.width   --  Incorrectly named field
          y = df.global.world.worldgen_status.height  --  Incorrectly named field
          break
          
        elseif i == "cursor_x" then
          x = df.global.world.worldgen_status.cursor_x
          y = df.global.world.worldgen_status.cursor_y
          break
        end
      end
      
      world:delete()
    end
  end
  
  for i, underground_region in ipairs (df.global.world.world_data.underground_regions) do
    if underground_region.layer_depth <= 3 then
      for k, x_coord in ipairs (underground_region.region_coords.x) do
        if x == x_coord and y == underground_region.region_coords.y [k] then
          region [underground_region.layer_depth] = i
          size [underground_region.layer_depth] = #underground_region.region_coords.x
          break
        end
      end
    end
  end
  
  evilness = df.global.world.world_data.region_map [x]:_displace (y).evilness
  savagery = df.global.world.world_data.region_map [x]:_displace (y).savagery
  size [Surface] = #df.global.world.world_data.regions [region [Surface]].region_coords.x

  for i, population in ipairs (df.global.world.world_data.regions [region [Surface]].population) do
    if Is_Animal (population.type) then
      animals [Surface] = animals [Surface] + 1
     
    elseif Is_Plant (population.type) then
      plants [Surface] = plants [Surface] + 1
    end
  end
  
  for i = 0, 3 do
    if region [i] then
      for k, population in ipairs (df.global.world.world_data.underground_regions [region [i]].feature_init.feature.population) do
        if Is_Animal (population.type) then
          animals [i] = animals [i] + 1
        elseif Is_Plant (population.type) then
          plants [i] = plants [i] + 1
        end
      end
    end
  end
  
  local keybindings = {
    evilness = {key = "CUSTOM_E",
                desc = "Change biome's Evilness"},
    unrestricted = {key = "CUSTOM_U",
                    desc = "Toggles whether plant and animal selection is limited to region applicable types"},
    animals = {key = "CUSTOM_A",
               desc = "Change Animals within the biome"},
    plants = {key = "CUSTOM_P",
              desc = "Change Plants within the biome"},
    cavern = {key = "CUSTOM_C",
              desc = "Tweak some parameters for the current cavern biome"},
    weather = {key = "CUSTOM_W",
               desc = "Limited Evil Weather manipulation"},
    geo = {key = "CUSTOM_G",
           desc = "Geo Biome manipulation"},
    evilness_single = {key = "CUSTOM_SHIFT_E",
                       desc = "Changes the Evilness level of the current world tile ONLY"},
    savagery = {key = "CUSTOM_SHIFT_S",
                desc = "Changing the Savagery level of the current world tile"},
    floradiversity = {key = "CUSTOM_F",
                      desc = "Gives all regions all plants legal to their biomes"},
    faunadiversity = {key = "CUSTOM_SHIFT_F",
                      desc = "Gives all regions all creatures legal to their biomes"},
    layer = {key = "CUSTOM_L",
             desc = "Set world layer on which action will be applied"},
    map_edit = {key = "CUSTOM_M",
                desc = "Edit the world map"},
    river = {key = "CUSTOM_R",
             desc = "Edit rivers on the world map"},
    min_count = {key = "CUSTOM_X",
                 desc = "Change the minimum number of a creature"},
    max_count = {key = "CUSTOM_SHIFT_X",
                 desc = "Change the maximum number of a creature"},
    cavern_water = {key = "CUSTOM_W",
                    desc = "Change cavern water parameter"},
    cavern_openness_min = {key = "CUSTOM_O",
                           desc = "Change cavern openness min"},
    cavern_openness_max = {key = "CUSTOM_SHIFT_O",
                           desc = "Change cavern openness max"},
    cavern_density_min = {key = "CUSTOM_D",
                          desc = "Change cavern passage density min"},
    cavern_density_max = {key = "CUSTOM_SHIFT_D",
                          desc = "Change cavern passage density max"},
    weather_dead_percent = {key = "CUSTOM_D",
                            desc = "Change dead vegetation percentage for the region"},
    geo_diversity_single = {key = "CUSTOM_G",
                            desc = "Assign all legal minerals to all layers of the current geo biome"},
    geo_diversity_all = {key = "CUSTOM_SHIFT_G",
                         desc = "Assign all legal minerals to all layers of all geo biomes"},
    geo_clone = {key = "CUSTOM_SHIFT_C",
                 desc = "Clone current Geo Biome"},
    geo_update = {key = "CUSTOM_U",
                  desc = "Update current world tile to new geo biome"},
    geo_delete = {key = "CUSTOM_D",
                  desc = "Delete the currently highlighted layer/vein/cluster/inclusion. The layer below extends upwards to cover the gap."},
    geo_split = {key = "CUSTOM_S",
                 desc = "Splits the current layer into two."},
    geo_expand = {key = "CUSTOM_E",
                  desc = "Expands the current layer one level downwards. The layer below has to be able to donate levels. The lowest layer cannot be expanded."},
    geo_contract = {key = "CUSTOM_C",
                    desc = "Contracts the current layer, giving to the layer below. Cannot contract when size one or at the bottom."},
    geo_morph = {key = "CUSTOM_M",
                 desc = "Morph the current layer into something else. All clusters and veins inside are removed."},
    geo_add = {key = "CUSTOM_A",
               desc = "Add a vein or cluster to the expanded layer."},
    geo_remove = {key = "CUSTOM_R",
                  desc = "Remove the currently selected vein/cluster. It will also remove everything nested inside of it."},
    geo_nest = {key = "CUSTOM_N",
                desc = "Nest a cluster inside the currently selected vein/cluster."},
    geo_proportion = {key = "CUSTOM_P",
                      desc = "Proportion of maximum abundance of this substance"},
    geo_full = {key = "CUSTOM_F",
                desc = "Add all legal minerals to this layer"},
    geo_clear = {key = "CUSTOM_C",
                 desc = "Clear the list of mineral veins/clusters/inclusions in this layer"},
    map_adopt_biome = {key = "CUSTOM_A",
                       desc = "Adopt biome & region of neighboring tile"},
    map_new_region = {key = "CUSTOM_N",
                      desc = "Create new region and biome"},
    map_elevation = {key = "CUSTOM_E",
                     desc = "Edit elevation of world map tile"},
    map_rainfall = {key = "CUSTOM_R",
                    desc = "Edit rainfall of world map tile"},
    map_vegetation = {key = "CUSTOM_SHIFT_V",
                      desc = "Edit vegetation of world map tile"},
    map_temperature = {key = "CUSTOM_T",
                       desc = "Edit temperature of world map tile"},
    map_evilness = {key = "CUSTOM_SHIFT_E",
                    desc = "Edit evilness of world map tile"},
    map_drainage = {key = "CUSTOM_D",
                    desc = "Edit drainage of world map tile"},
    map_volcanism = {key = "CUSTOM_V",
                     desc = "Edit volcanism of world map tile"},
    map_savagery = {key = "CUSTOM_S",
                    desc = "Edit savagery of world map tile"},
    map_salinity = {key = "CUSTOM_SHIFT_S",
                    desc = "Edit salinity of world map tile"},
    map_biome = {key = "CUSTOM_B",
                 desc = "Select a new biome for the world tile, keeping the region"},
    next_edit = {key = "CHANGETAB",
                 desc = "Change focus to the next map/list"},
    prev_edit = {key = "SEC_CHANGETAB",
                 desc = "Change focus to the previous map/list"},
    river_select = {key = "SELECT",
                    desc = "Select river in current tile for editing"},
    river_brook = {key = "CUSTOM_B",
                   desc = "Toggle the brook/stream flag"},
    river_flow = {key = "CUSTOM_F",
                  desc = "Set flow in current river tile"},
    river_exit = {key = "CUSTOM_E",
                  desc = "Set exit mid level tile from current world tile"},
    river_elevation = {key = "CUSTOM_SHIFT_E",
                       desc = "Set river elevation for the current world tile"},
    river_clear = {key = "CUSTOM_C",
                   desc = "Clear the complete course of the current river"},
    river_truncate = {key = "CUSTOM_T",
                      desc = "Remove this and all following tiles from the current river course"},
    river_add = {key = "CUSTOM_A",
                 desc = "Add the current tile to the selected river's course (will wipe end tile)"},
    river_set_sink = {key = "CUSTOM_S",
                     desc = "Set the current tile as the river's sink"},
    river_set_sink_direction = {key = "CUSTOM_SHIFT_S",
                               desc = "Set the river's sink to the indicated direction (needed if off map)"},
    river_delete = {key = "CUSTOM_D",
                    desc = "Delete the current river completely"},
    river_new = {key = "CUSTOM_N",
                 desc = "Create a new river with it's source at the current tile"},
    river_wipe_lost = {key = "CUSTOM_W",
                       desc = "Wipes away lost rivers"},
    up = {key = "CURSOR_UP",
          desc = "Shifts focus 1 step upwards"},
    down = {key = "CURSOR_DOWN",
            desc = "Shifts focus 1 step downwards"},
    left = {key = "CURSOR_LEFT",
            desc = "Shifts focus 1 step to the left"},
    right = {key = "CURSOR_RIGHT",
             desc = "Shift focus 1 step to the right"},
    upleft = {key = "CURSOR_UPLEFT",
              desc = "Shifts focus 1 step up to the left"},
    upright = {key = "CURSOR_UPRIGHT",
               desc = "Shifts focus 1 step up to the right"},
    downleft = {key = "CURSOR_DOWNLEFT",
                desc = "Shifts focus 1 step down to the left"},
    downright = {key = "CURSOR_DOWNRIGHT",
                 desc = "Shifts focus 1 step down to the right"},
    up_fast = {key = "CURSOR_UP_FAST",
          desc = "Shifts focus 10 step upwards"},
    down_fast = {key = "CURSOR_DOWN_FAST",
            desc = "Shifts focus 10 step downwards"},
    left_fast = {key = "CURSOR_LEFT_FAST",
            desc = "Shifts focus 10 step to the left"},
    right_fast = {key = "CURSOR_RIGHT_FAST",
             desc = "Shift focus 10 step to the right"},
    upleft_fast = {key = "CURSOR_UPLEFT_FAST",
              desc = "Shifts focus 10 step up to the left"},
    upright_fast = {key = "CURSOR_UPRIGHT_FAST",
               desc = "Shifts focus 10 step up to the right"},
    downleft_fast = {key = "CURSOR_DOWNLEFT_FAST",
                desc = "Shifts focus 10 step down to the left"},
    downright_fast = {key = "CURSOR_DOWNRIGHT_FAST",
                 desc = "Shifts focus 10 step down to the right"},
    help = {key = "HELP",
            desc= "Show this help/info"},
    print_help = {key = "CUSTOM_P",
                  desc = "Print this help to the DFHack console window"}}

 --============================================================

  function check_tropicality_no_poles_world (temperature)
    local is_possible_tropical_area_by_latitude = false
    local is_tropical_area_by_latitude = false

    --  No poles => Temperature determines tropicality
    --
    if temperature >= 75 then
      is_possible_tropical_area_by_latitude = true
    end
    is_tropical_area_by_latitude = temperature >= 85
    
    return is_possible_tropical_area_by_latitude, is_tropical_area_by_latitude
  end
  
  --============================================================
  
  function check_tropicality_north_pole_only_world (pos_y,
                                                    map_height)
    local v6
    local is_possible_tropical_area_by_latitude = false
    local is_tropical_area_by_latitude = false
    
    if map_height == 17 then
      v6 = pos_y * 16
      
    elseif map_height == 33 then
      v6 = pos_y * 8
      
    elseif map_height == 65 then
      v6 = pos_y * 4
      
    elseif map_height == 129 then
      v6 = pos_y * 2
    
    else
      v6 = pos_y
    end
    
    is_possible_tropical_area_by_latitude = v6 > 170
    is_tropical_area_by_latitude = v6 >= 200
    
    return is_possible_tropical_area_by_latitude, is_tropical_area_by_latitude
  end
  
  --============================================================
  
  function check_tropicality_south_pole_only_world (pos_y,
                                                    map_height)
    local v6 = map_height - pos_y - 1
    local is_possible_tropical_area_by_latitude = false
    local is_tropical_area_by_latitude = false
    
    if map_height == 17 then
      v6 = v6 * 16
      
    elseif map_height == 33 then
      v6 = v6 * 8
      
    elseif map_height == 65 then
      v6 = v6 * 4
      
    elseif map_height == 129 then
      v6 = v6 * 2
    
    else
      v6 = v6
    end
    
      is_possible_tropical_area_by_latitude = v6 > 170
    is_tropical_area_by_latitude = v6 >= 200
    
    return is_possible_tropical_area_by_latitude, is_tropical_area_by_latitude
  end
  
  --============================================================
  
  function check_tropicality_both_poles_world (pos_y,
                                               map_height)
    local v6
    local is_possible_tropical_area_by_latitude = false
    local is_tropical_area_by_latitude = false

    if pos_y < math.floor (map_height / 2) then
      v6 = 2 * pos_y
    
    else
      v6 = map_height + 2 * (math.floor (map_height / 2) - pos_y) - 1
      
      if v6 < 0 then
         v6 = 0
      end

      if v6 >= map_height then
        v6 = map_height - 1
      end
    end

    if map_height == 17 then
      v6 = v6 * 16
      
    elseif map_height == 33 then
      v6 = v6 * 8
      
    elseif map_height == 65 then
      v6 = v6 * 4
      
    elseif map_height == 129 then
      v6 = v6 * 2
    
    else
      v6 = v6
    end
    
    is_possible_tropical_area_by_latitude = v6 > 170
    is_tropical_area_by_latitude = v6 >= 200
    
    return is_possible_tropical_area_by_latitude, is_tropical_area_by_latitude
  end
  
  --============================================================
  
  function check_tropicality (pos_y,
                              map_height,
                              temperature)
    local flip_latitude = df.global.world.world_data.flip_latitude
    
    if flip_latitude == -1 then  --  No poles
      return check_tropicality_no_poles_world (temperature)
                                            
    elseif flip_latitude == 0 then  --  North pole
      return check_tropicality_north_pole_only_world (pos_y,
                                                      map_height)
                                                      
    elseif flip_latitude == 1 then  --  South pole
      return check_tropicality_south_pole_only_world (pos_y,
                                                      map_height)
                                                      
    elseif flip_latitude == 2 then  -- Both poles
      return check_tropicality_both_poles_world (pos_y,
                                                 map_height)

    else
      return false, false
    end
  end
  
  --============================================================
  
  function get_parameter_percentage (flip_latitude,
                                     pos_y,
                                     rainfall,
                                     map_height)
    local result
    local ypos = pos_y
    
    if flip_latitude == -1 then  -- No poles
      return 100
      
    elseif flip_latitude == 1 then --  South pole
      ypos = map_height - ypos - 1
      
    elseif flip_latitude == 2 then  --  North and South pole
      if ypos < math.floor (map_height / 2) then
        ypos = ypos * 2
      
      else
        ypos = map_height + 2 * (math.floor (map_height / 2) - ypos) - 1
        if ypos < 0 then
          ypos = 0
        end
        
        if ypos >= map_height then
          ypos = map_height - 1
        end
      end
    end
    
    local latitude
    if map_height == 17 then
      latitude = 16 * ypos
    elseif map_height == 33 then
      latitude = 8 * ypos
    elseif map_height == 65 then
      latitude = 4 * ypos
    elseif map_height == 129 then
      latitude = 2 * ypos
    else
      latitude = ypos
    end
    
    if latitude > 220 then
      return 100

    elseif latitude > 190 and
           latitude < 201 then
      return 0

    elseif latitude >= 201 then
      result = rainfall + 16 * (latitude - 207)

    else
      result = 16 * (184 - latitude) - rainfall
    end
    
    if result < 0 then
      return 0
    elseif result > 100 then
      return 100
    else
      return result
    end
  end

  --============================================================

  function get_region_parameter (pos_y,
                                 rainfall,
                                 map_height)

    local result = 100
    
    if map_height > 65 then  --  Medium & Large worlds
      return get_parameter_percentage (df.global.world.world_data.flip_latitude,
                                       pos_y,
                                       rainfall,
                                       map_height)
    end
    
    return result
  end
  
  --============================================================
  
  function get_lake_biome (is_possible_tropical_area_by_latitude,
                           salinity)
    if salinity < 33 then
      if is_possible_tropical_area_by_latitude then
        return df.biome_type.LAKE_TROPICAL_FRESHWATER
      else
        return df.biome_type.LAKE_TEMPERATE_FRESHWATER
      end
    
    elseif salinity < 66 then
      if is_possible_tropical_area_by_latitude then
        return df.biome_type.LAKE_TROPICAL_BRACKISHWATER
      else
        return df.biome_type.LAKE_TEMPERATE_BRACKISHWATER
      end
           
    else
      if is_possible_tropical_area_by_latitude then
        return df.biome_type.LAKE_TROPICAL_SALTWATER
      else
        return df.biome_type.LAKE_TEMPERATE_SALTWATER
      end
    end
  end
  
  --============================================================

  function get_ocean_biome (is_tropical_area_by_latitude,
                            temperature)
    if is_tropical_area_by_latitude then
      return df.biome_type.OCEAN_TROPICAL
    elseif temperature <= -5 then
      return df.biome_type.OCEAN_ARCTIC
    else
      return df.biome_type.OCEAN_TEMPERATE
    end
  end
  
  --============================================================
  
  function get_desert_biome (drainage)
    if drainage < 33 then
      return df.biome_type.DESERT_SAND
    elseif drainage < 66 then
      return df.biome_type.DESERT_ROCK
    else
      return df.biome_type.DESERT_BADLAND
    end
  end
  
  --============================================================
  
  function get_biome_grassland (is_possible_tropical_area_by_latitude,
                                is_tropical_area_by_latitude,
                                rainfall,
                                pos_y,
                                map_height)
       
    if (is_possible_tropical_area_by_latitude and
        get_region_parameter(pos_y, rainfall, map_height) < 66) or
       is_tropical_area_by_latitude then
      return df.biome_type.GRASSLAND_TROPICAL
    else
      return df.biome_type.GRASSLAND_TEMPERATE
    end
  end
  
  --============================================================

  function get_biome_savanna (is_possible_tropical_area_by_latitude,
                              is_tropical_area_by_latitude,
                              rainfall,
                              pos_y,
                              map_height)
    if is_tropical_area_by_latitude or
       (is_possible_tropical_area_by_latitude and
        get_region_parameter (pos_y, rainfall, map_height) <= 6) then
      return df.biome_type.SAVANNA_TROPICAL
    else
      return df.biome_type.SAVANNA_TEMPERATE
    end       
  end
  
  --============================================================

  function get_biome_desert_or_grassland_or_savanna (is_possible_tropical_area_by_latitude,
                                                     is_tropical_area_by_latitude,
                                                     vegetation,
                                                     drainage,
                                                     rainfall,
                                                     pos_y,
                                                     map_height)
    if vegetation < 10 then
      return get_desert_biome (drainage)
      
    elseif vegetation < 20 then
       return get_biome_grassland (is_possible_tropical_area_by_latitude,
                                   is_tropical_area_by_latitude,
                                   rainfall,
                                   pos_y,
                                   map_height)
    
    else
      return get_biome_savanna (is_possible_tropical_area_by_latitude,
                                is_tropical_area_by_latitude,
                                  rainfall,
                                  pos_y,
                                map_height)
    end
  end
  
  --============================================================

  function get_biome_shrubland (is_possible_tropical_area_by_latitude,
                                is_tropical_area_by_latitude,
                                rainfall,
                                pos_y,
                                map_height)
    if is_tropical_area_by_latitude or
      (is_possible_tropical_area_by_latitude and
       get_region_parameter (pos_y, rainfall, map_height) < 66) then
      return df.biome_type.SHRUBLAND_TROPICAL
    else
      return df.biome_type.SHRUBLAND_TEMPERATE
    end
  end
  
  --============================================================

  function get_biome_marsh (is_possible_tropical_area_by_latitude,
                            is_tropical_area_by_latitude,
                            salinity,
                            rainfall,
                            pos_y,
                            map_height)
    if salinity < 66 then
      if is_tropical_area_by_latitude or
         (is_possible_tropical_area_by_latitude and
          get_region_parameter (pos_y, rainfall, map_height) < 66) then
        return df.biome_type.MARSH_TROPICAL_FRESHWATER
      else
        return df.biome_type.MARSH_TEMPERATE_FRESHWATER
      end
      
    else
      if is_tropical_area_by_latitude or
         (is_possible_tropical_area_by_latitude and
          get_region_parameter (pos_y, rainfall, map_height) < 66) then
        return df.biome_type.MARSH_TROPICAL_SALTWATER
      else
        return df.biome_type.MARSH_TEMPERATE_SALTWATER
      end
    end
  end
  
  --============================================================

  function get_biome_shrubland_or_marsh (is_possible_tropical_area_by_latitude,
                                         is_tropical_area_by_latitude,
                                         drainage,
                                         salinity,
                                         rainfall,
                                         pos_y,
                                         map_height)
    if drainage < 33 then
      return get_biome_marsh (is_possible_tropical_area_by_latitude,
                              is_tropical_area_by_latitude,
                              salinity,
                              rainfall,
                              pos_y,
                              map_height)
    else
      return get_biome_shrubland (is_possible_tropical_area_by_latitude,
                                  is_tropical_area_by_latitude,
                                  rainfall,
                                  pos_y,
                                  map_height)
    end
  end
  
  --============================================================

  function get_biome_forest (is_possible_tropical_area_by_latitude,
                             is_tropical_area_by_latitude,
                             rainfall,
                             temperature,
                             pos_y,
                             map_height)
    local parameter = get_region_parameter (pos_y, rainfall, map_height)
    
    if is_possible_tropical_area_by_latitude then
      if (parameter < 66 or
          is_tropical_area_by_latitude) and
         rainfall < 75 then
         return df.biome_type.FOREST_TROPICAL_CONIFER
    
      elseif parameter < 66 then
         return df.biome_type.FOREST_TROPICAL_DRY_BROADLEAF
      
      elseif is_tropical_area_by_latitude then
         return df.biome_type.FOREST_TROPICAL_MOIST_BROADLEAF
        
      elseif rainfall < 75 or
             temperature < 65 then
        if temperature < 10 then
          return df.biome_type.FOREST_TAIGA
          
        else
          return df.biome_type.FOREST_TEMPERATE_CONIFER
        end
        
      else
         return df.biome_type.FOREST_TEMPERATE_BROADLEAF
      end
      
    else
      if rainfall < 75 or
         temperature < 65 then
           if temperature < 10 then
             return df.biome_type.FOREST_TAIGA
           else
             return df.biome_type.FOREST_TEMPERATE_CONIFER
           end
           
         else
          return df.biome_type.FOREST_TEMPERATE_BROADLEAF
         end
    end
  end
  
  --============================================================

  function get_biome_swamp (is_possible_tropical_area_by_latitude,
                            is_tropical_area_by_latitude,
                            salinity,
                            drainage,
                            rainfall,
                            pos_y,
                            map_height)
    local parameter = get_region_parameter (pos_y, rainfall, map_height)
    
    if is_possible_tropical_area_by_latitude then
      if salinity < 66 then
        if parameter < 66 or
           is_tropical_area_by_latitude then
          return df.biome_type.SWAMP_TROPICAL_FRESHWATER
        else
          return df.biome_type.SWAMP_TEMPERATE_FRESHWATER
        end
     
      elseif parameter < 66 or
             is_tropical_area_by_latitude then
        if drainage < 10 then
           return df.biome_type.SWAMP_MANGROVE
        else
          return df.biome_type.SWAMP_TROPICAL_SALTWATER
        end
        
      else
           return df.biome_type.SWAMP_TEMPERATE_SALTWATER
      end
    
    else
      if salinity < 66 then
           return df.biome_type.SWAMP_TEMPERATE_FRESHWATER
      else
           return df.biome_type.SWAMP_TEMPERATE_SALTWATER
      end
    end
  end
  
  --============================================================
  
  function get_biome_type (biome_pos_y,
                           map_height,
                           temperature,
                           elevation,
                           drainage,
                           rainfall,
                           salinity,
                           vegetation,
                           is_lake)
                      
    local is_possible_tropical_area_by_latitude, is_tropical_area_by_latitude = 
      check_tropicality (biome_pos_y,
                         map_height,
                         temperature)
          
    if is_lake then
      return get_lake_biome (is_possible_tropical_area_by_latitude,
                             salinity)
      
    elseif elevation >= 150 then
         return df.biome_type.MOUNTAIN
      
    elseif elevation < 100 then
      return get_ocean_biome (is_tropical_area_by_latitude,
                                temperature)
                                
    elseif temperature <= -5 then
      if drainage < 75 then
           return df.biome_type.TUNDRA
      else
           return df.biome_type.GLACIER
      end
        
    elseif vegetation < 33 then
      return get_biome_desert_or_grassland_or_savanna (is_possible_tropical_area_by_latitude,
                                                       is_tropical_area_by_latitude,
                                                       vegetation,
                                                       drainage,
                                                       rainfall,
                                                       biome_pos_y,
                                                       map_height)
        
    elseif vegetation < 66 then
      return get_biome_shrubland_or_marsh (is_possible_tropical_area_by_latitude,
                                           is_tropical_area_by_latitude,
                                           drainage,
                                           salinity,
                                           rainfall,
                                           biome_pos_y,
                                           map_height)
        
    elseif drainage < 33 then
      return get_biome_swamp (is_possible_tropical_area_by_latitude,
                              is_tropical_area_by_latitude,
                              salinity,
                              drainage,
                              rainfall,
                              biome_pos_y,
                              map_height)
    else
      return get_biome_forest (is_possible_tropical_area_by_latitude,
                               is_tropical_area_by_latitude,
                               rainfall,
                               temperature,
                               biome_pos_y,
                               map_height)
    end
  end
  
  --============================================================

  function biome_character_of (biome_type)
    if biome_type == df.biome_type.MOUNTAIN then
      return '+'      
    elseif biome_type == df.biome_type.GLACIER then
      return '*'
    elseif biome_type == df.biome_type.TUNDRA then
      return 't'
    elseif biome_type == df.biome_type.SWAMP_TEMPERATE_FRESHWATER then
      return 'p'
    elseif biome_type == df.biome_type.SWAMP_TEMPERATE_SALTWATER then
      return 'r'
    elseif biome_type == df.biome_type.MARSH_TEMPERATE_FRESHWATER then
      return 'n'
    elseif biome_type == df.biome_type.MARSH_TEMPERATE_SALTWATER then
      return 'y'
    elseif biome_type == df.biome_type.SWAMP_TROPICAL_FRESHWATER then
      return 'P'
    elseif biome_type == df.biome_type.SWAMP_TROPICAL_SALTWATER then
      return 'R'
    elseif biome_type == df.biome_type.SWAMP_MANGROVE then
      return 'M'
    elseif biome_type == df.biome_type.MARSH_TROPICAL_FRESHWATER then
      return 'N'
    elseif biome_type == df.biome_type.MARSH_TROPICAL_SALTWATER then
      return 'Y'
    elseif biome_type == df.biome_type.FOREST_TAIGA then
      return 'T'
    elseif biome_type == df.biome_type.FOREST_TEMPERATE_CONIFER then
      return 'c'
    elseif biome_type == df.biome_type.FOREST_TEMPERATE_BROADLEAF then
      return 'l'
    elseif biome_type == df.biome_type.FOREST_TROPICAL_CONIFER then
      return 'C'
    elseif biome_type == df.biome_type.FOREST_TROPICAL_DRY_BROADLEAF then
      return 'd'
    elseif biome_type == df.biome_type.FOREST_TROPICAL_MOIST_BROADLEAF then
      return 'L'
    elseif biome_type == df.biome_type.GRASSLAND_TEMPERATE then
      return 'g'
    elseif biome_type == df.biome_type.SAVANNA_TEMPERATE then
      return 's'
    elseif biome_type == df.biome_type.SHRUBLAND_TEMPERATE then
      return 'u'
    elseif biome_type == df.biome_type.GRASSLAND_TROPICAL then
      return 'G'
    elseif biome_type == df.biome_type.SAVANNA_TROPICAL then
      return 'S'
    elseif biome_type == df.biome_type.SHRUBLAND_TROPICAL then
      return 'U'
    elseif biome_type == df.biome_type.DESERT_BADLAND then
      return 'B'
    elseif biome_type == df.biome_type.DESERT_ROCK then
      return 'e'
    elseif biome_type == df.biome_type.DESERT_SAND then
      return 'D'
    elseif biome_type == df.biome_type.OCEAN_TROPICAL then
      return 'O'
    elseif biome_type == df.biome_type.OCEAN_TEMPERATE then
      return 'o'
    elseif biome_type == df.biome_type.OCEAN_ARCTIC then
      return 'a'
    elseif biome_type == df.biome_type.POOL_TEMPERATE_FRESHWATER then
      return '.'
    elseif biome_type == df.biome_type.POOL_TEMPERATE_BRACKISHWATER then
      return ':'
    elseif biome_type == df.biome_type.POOL_TEMPERATE_SALTWATER then
      return '!'
    elseif biome_type == df.biome_type.POOL_TROPICAL_FRESHWATER then
      return ','
    elseif biome_type == df.biome_type.POOL_TROPICAL_BRACKISHWATER then
      return ';'
    elseif biome_type == df.biome_type.POOL_TROPICAL_SALTWATER then
      return '|'
    elseif biome_type == df.biome_type.LAKE_TEMPERATE_FRESHWATER then
      return '<'
    elseif biome_type == df.biome_type.LAKE_TEMPERATE_BRACKISHWATER then
      return '-'
    elseif biome_type == df.biome_type.LAKE_TEMPERATE_SALTWATER then
      return '['
    elseif biome_type == df.biome_type.LAKE_TROPICAL_FRESHWATER then
      return '>'
    elseif biome_type == df.biome_type.LAKE_TROPICAL_BRACKISHWATER then
      return '='
    elseif biome_type == df.biome_type.LAKE_TROPICAL_SALTWATER then
      return ']'
    elseif biome_type == df.biome_type.RIVER_TEMPERATE_FRESHWATER then
      return '\\'
    elseif biome_type == df.biome_type.RIVER_TEMPERATE_BRACKISHWATER then
      return '%'
    elseif biome_type == df.biome_type.RIVER_TEMPERATE_SALTWATER then
      return '('
    elseif biome_type == df.biome_type.RIVER_TROPICAL_FRESHWATER then
      return '/'
    elseif biome_type == df.biome_type.RIVER_TROPICAL_BRACKISHWATER then
      return '&'
    elseif biome_type == df.biome_type.RIVER_TROPICAL_SALTWATER then
      return ')'
    elseif biome_type == df.biome_type.SUBTERRANEAN_WATER then
      return '_'
    elseif biome_type == df.biome_type.SUBTERRANEAN_CHASM then
      return '^'
    elseif biome_type == df.biome_type.SUBTERRANEAN_LAVA then
      return '~'
    end  
  end
  
  --============================================================
  
  function get_biome_character (local_pos_y,
                                biome_reference_y,
                                biome_home_y,
                                map_height,
                                temperature,
                                elevation,
                                drainage,
                                rainfall,
                                salinity,
                                vegetation,
                                is_lake)
    
    local biome_type    

    biome_type = get_biome_type (biome_reference_y,
                                 map_height,
                                 temperature,
                                 elevation,
                                 drainage,
                                 rainfall,
                                 salinity,
                                 vegetation,
                                 is_lake)
    
    return biome_character_of (biome_type)
  end
  
  --============================================================
    
  function is_possible_biome (biome_type,
                              is_possible_tropical_area_by_latitude,
                              is_tropical_area_by_latitude,
                              pole,
                              pos_y)
                              
    if biome_type == df.biome_type.MOUNTAIN then
      return true  
      
    elseif biome_type == df.biome_type.GLACIER then
      return true
      
    elseif biome_type == df.biome_type.TUNDRA then
      return true
      
    elseif biome_type == df.biome_type.SWAMP_TEMPERATE_FRESHWATER or
           biome_type == df.biome_type.SWAMP_TEMPERATE_SALTWATER then
      return pole == -1 or
             not is_possible_tropical_area_by_latitude or
             (not is_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     66,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66 or
               get_region_parameter (pos_y,
                                     100,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66))
      
    elseif biome_type == df.biome_type.MARSH_TEMPERATE_FRESHWATER or
           biome_type == df.biome_type.MARSH_TEMPERATE_SALTWATER then
      return pole == -1 or 
             not is_possible_tropical_area_by_latitude or
             (not is_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     33,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66 or
               get_region_parameter (pos_y,
                                     65,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66))
      
    elseif biome_type == df.biome_type.SWAMP_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.SWAMP_TROPICAL_SALTWATER then
      return pole == -1 or
             is_tropical_area_by_latitude or
             (is_possible_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     66,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66 or
               get_region_parameter (pos_y,
                                     100,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66))
      
    elseif biome_type == df.biome_type.SWAMP_MANGROVE then
      return pole == -1 or 
             is_tropical_area_by_latitude or
             (is_possible_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     66,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66 or
               get_region_parameter (pos_y,
                                     100,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66))
      
    elseif biome_type == df.biome_type.MARSH_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.MARSH_TROPICAL_SALTWATER then
      return pole == -1 or 
             is_tropical_area_by_latitude or
             (is_possible_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     33,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66 or
               get_region_parameter (pos_y,
                                     65,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66))
      
    elseif biome_type == df.biome_type.FOREST_TAIGA then
      return pole == -1 or
             not is_possible_tropical_area_by_latitude or
             (not is_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     66,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66 or
               get_region_parameter (pos_y,
                                     100,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66))
      
    elseif biome_type == df.biome_type.FOREST_TEMPERATE_CONIFER then
      return pole == -1 or
             not is_possible_tropical_area_by_latitude or
             (not is_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     66,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66 or
               get_region_parameter (pos_y,
                                     74,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66))
      
    elseif biome_type == df.biome_type.FOREST_TEMPERATE_BROADLEAF then
      return pole == -1 or
             not is_possible_tropical_area_by_latitude or
             (not is_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     75,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66 or
               get_region_parameter (pos_y,
                                     100,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66))
      
    elseif biome_type == df.biome_type.FOREST_TROPICAL_CONIFER then
      return pole == -1 or 
             is_tropical_area_by_latitude or
             (is_possible_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     66,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66 or
               get_region_parameter (pos_y,
                                     74,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66))
      
    elseif biome_type == df.biome_type.FOREST_TROPICAL_DRY_BROADLEAF then
      return is_possible_tropical_area_by_latitude and
             (get_region_parameter (pos_y,
                                    75,
                                    df.global.world.worldgen.worldgen_parms.dim_y) < 66 or
              get_region_parameter (pos_y,
                                    100,
                                    df.global.world.worldgen.worldgen_parms.dim_y) < 66)
      
    elseif biome_type == df.biome_type.FOREST_TROPICAL_MOIST_BROADLEAF then
      return pole == -1 or
             (is_tropical_area_by_latitude and
              get_region_parameter (pos_y,
                                    100,
                                    df.global.world.worldgen.worldgen_parms.dim_y) >= 66)
      
    elseif biome_type == df.biome_type.GRASSLAND_TEMPERATE then
      return pole == -1 or 
             not is_possible_tropical_area_by_latitude or
             (not is_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     10,
                                    df.global.world.worldgen.worldgen_parms.dim_y) >= 66 or
               get_region_parameter (pos_y,
                                     19,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66))
      
    elseif biome_type == df.biome_type.SAVANNA_TEMPERATE then
      return pole == -1 or 
             not is_possible_tropical_area_by_latitude or
             (not is_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     20,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 6 or
               get_region_parameter (pos_y,
                                     32,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 6))
      
    elseif biome_type == df.biome_type.SHRUBLAND_TEMPERATE then
      return pole == -1 or 
             not is_possible_tropical_area_by_latitude or
             (not is_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     33,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66 or
               get_region_parameter (pos_y,
                                     65,
                                     df.global.world.worldgen.worldgen_parms.dim_y) >= 66))
      
    elseif biome_type == df.biome_type.GRASSLAND_TROPICAL then
      return pole == -1 or
             is_tropical_area_by_latitude or
             (is_possible_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     10,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66 or
               get_region_parameter (pos_y,
                                     19,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66))
      
    elseif biome_type == df.biome_type.SAVANNA_TROPICAL then
      return pole == -1 or 
             is_tropical_area_by_latitude or
             (is_possible_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     20,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 6 or
               get_region_parameter (pos_y,
                                     32,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 6))
      
    elseif biome_type == df.biome_type.SHRUBLAND_TROPICAL then
      return pole == -1 or
             is_tropical_area_by_latitude or
             (is_possible_tropical_area_by_latitude and
              (get_region_parameter (pos_y,
                                     33,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66 or
               get_region_parameter (pos_y,
                                     65,
                                     df.global.world.worldgen.worldgen_parms.dim_y) < 66))
      
    elseif biome_type == df.biome_type.DESERT_BADLAND then
      return true
      
    elseif biome_type == df.biome_type.DESERT_ROCK then
      return true
      
    elseif biome_type == df.biome_type.DESERT_SAND then
      return true
      
    elseif biome_type == df.biome_type.OCEAN_TROPICAL then
      return pole == -1 or is_tropical_area_by_latitude
      
    elseif biome_type == df.biome_type.OCEAN_TEMPERATE then
      return pole == -1 or not is_tropical_area_by_latitude
      
    elseif biome_type == df.biome_type.OCEAN_ARCTIC then
      return pole == -1 or not is_tropical_area_by_latitude
      
    elseif biome_type == df.biome_type.POOL_TEMPERATE_FRESHWATER or  --  Not visible on world tile level
           biome_type == df.biome_type.POOL_TEMPERATE_BRACKISHWATER or
           biome_type == df.biome_type.POOL_TEMPERATE_SALTWATER or
           biome_type == df.biome_type.POOL_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.POOL_TROPICAL_BRACKISHWATER or
           biome_type == df.biome_type.POOL_TROPICAL_SALTWATER then
      return false
      
    elseif biome_type == df.biome_type.LAKE_TEMPERATE_FRESHWATER or
           biome_type == df.biome_type.LAKE_TEMPERATE_BRACKISHWATER or
           biome_type == df.biome_type.LAKE_TEMPERATE_SALTWATER then
      return pole == -1 or not is_possible_tropical_area_by_latitude
      
    elseif biome_type == df.biome_type.LAKE_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.LAKE_TROPICAL_BRACKISHWATER or
           biome_type == df.biome_type.LAKE_TROPICAL_SALTWATER then
      return pole == -1 or is_possible_tropical_area_by_latitude
      
    elseif biome_type == df.biome_type.RIVER_TEMPERATE_FRESHWATER or  --  Not separate world tile entities
           biome_type == df.biome_type.RIVER_TEMPERATE_BRACKISHWATER or
           biome_type == df.biome_type.RIVER_TEMPERATE_SALTWATER or
           biome_type == df.biome_type.RIVER_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.RIVER_TROPICAL_BRACKISHWATER or
           biome_type == df.biome_type.RIVER_TROPICAL_SALTWATER then
      return false
      
    elseif biome_type == df.biome_type.SUBTERRANEAN_WATER or
           biome_type == df.biome_type.SUBTERRANEAN_CHASM or
           biome_type == df.biome_type.SUBTERRANEAN_LAVA then --  Not surface biomes
      return false     
    end
  end  
  
  --============================================================

  function match_biome (s)
    if s == '+' then
      return df.biome_type.MOUNTAIN

    elseif s == '*' then
      return df.biome_type.GLACIER
      
    elseif s == 't' then
      return df.biome_type.TUNDRA
      
    elseif s == 'p' then
      return df.biome_type.SWAMP_TEMPERATE_FRESHWATER

    elseif s == 'r' then
      return df.biome_type.SWAMP_TEMPERATE_SALTWATER
      
    elseif s == 'n' then
      return df.biome_type.MARSH_TEMPERATE_FRESHWATER

    elseif s == 'y' then
      return df.biome_type.MARSH_TEMPERATE_SALTWATER
     
    elseif s == 'P' then
      return df.biome_type.SWAMP_TROPICAL_FRESHWATER

    elseif s == 'R' then
      return df.biome_type.SWAMP_TROPICAL_SALTWATER
       
    elseif s == 'M' then
      return df.biome_type.SWAMP_MANGROVE
      
    elseif s == 'N' then
      return df.biome_type.MARSH_TROPICAL_FRESHWATER

    elseif s == 'Y' then
      return df.biome_type.MARSH_TROPICAL_SALTWATER
      
    elseif s == 'T' then
      return df.biome_type.FOREST_TAIGA
      
    elseif s == 'c' then
      return df.biome_type.FOREST_TEMPERATE_CONIFER
      
    elseif s == 'l' then
      return df.biome_type.FOREST_TEMPERATE_BROADLEAF
      
    elseif s == 'C' then
      return df.biome_type.FOREST_TROPICAL_CONIFER
      
    elseif s == 'd' then
      return df.biome_type.FOREST_TROPICAL_DRY_BROADLEAF
      
    elseif s == 'L' then 
      return df.biome_type.FOREST_TROPICAL_MOIST_BROADLEAF
      
    elseif s == 'g' then
      return df.biome_type.GRASSLAND_TEMPERATE
      
    elseif s == 's' then
      return df.biome_type.SAVANNA_TEMPERATE
      
    elseif s == 'u' then
      return df.biome_type.SHRUBLAND_TEMPERATE
      
    elseif s == 'G' then 
      return df.biome_type.GRASSLAND_TROPICAL
      
    elseif s == 'S' then 
      return df.biome_type.SAVANNA_TROPICAL
      
    elseif s == 'U' then 
      return df.biome_type.SHRUBLAND_TROPICAL
      
    elseif s == 'B' then
      return df.biome_type.DESERT_BADLAND
      
    elseif s == 'e' then
      return df.biome_type.DESERT_ROCK
      
    elseif s == 'D' then
      return df.biome_type.DESERT_SAND
      
    elseif s == 'O' then
      return df.biome_type.OCEAN_TROPICAL
      
    elseif s == 'o' then
      return df.biome_type.OCEAN_TEMPERATE
      
    elseif s == 'a' then
      return df.biome_type.OCEAN_ARCTIC
      
    elseif s == '<' then
      return df.biome_type.LAKE_TEMPERATE_FRESHWATER
    
    elseif s == '-' then
      return df.biome_type.LAKE_TEMPERATE_BRACKISHWATER
      
    elseif s == '[' then
      return df.biome_type.LAKE_TEMPERATE_SALTWATER
      
    elseif s == '>' then
      return df.biome_type.LAKE_TROPICAL_FRESHWATER
      
    elseif s == '=' then
      return df.biome_type.LAKE_TROPICAL_BRACKISHWATER
      
    elseif s == ']' then
      return df.biome_type.LAKE_TROPICAL_SALTWATER
      
    else
      return nil
    end
  end
  
  --============================================================

  function supported_biome_list (is_possible_tropical_area_by_latitude,
                                 is_tropical_area_by_latitude,
                                 pole,
                                 pos_y)
    local result = "supported biomes\n"
    
      for i = df.biome_type.MOUNTAIN, df.biome_type.LAKE_TROPICAL_SALTWATER do      
        if is_possible_biome (i,
                              is_possible_tropical_area_by_latitude,
                              is_tropical_area_by_latitude,
                              pole,
                              pos_y) then
          result = result .. biome_character_of (i) .. " = " .. df.biome_type [i] .. "\n"
        end
      end
    
      return result
  end
  
  --============================================================  
  
  function make_biome (biome_type,
                       is_possible_tropical_area_by_latitude,
                       is_tropical_area_by_latitude,
                       parameters,
                       pole,
                       pos_y)
    local par = parameters
    local world_height = df.global.world.worldgen.worldgen_parms.dim_y
    
    if not is_possible_biome (biome_type,
                              is_possible_tropical_area_by_latitude,
                              is_tropical_area_by_latitude,
                              pole,
                              pos_y) then
      dialog.showMessage("Failure", "Requested biome cannot be created (here)", COLOR_RED)
      return par
    end
    
    if biome_type == df.biome_type.MOUNTAIN then
      if par.elevation < 150 then
        par.elevation = 200
      end
      
    elseif biome_type == df.biome_type.GLACIER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature > -5 then
        par.temperature = -30
      end
      
      if par.drainage < 75 then
        par.drainage = 85
      end
      
    elseif biome_type == df.biome_type.TUNDRA then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature > -5 then
        par.temperature = -30
      end
      
      if par.drainage >= 75 then
        par.drainage = 30
      end
      
    elseif biome_type == df.biome_type.SWAMP_TEMPERATE_FRESHWATER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature >= 75) then
        par.temperature = 20
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.vegetation < 66  then
          par.vegetation = 85
          par.rainfall = 85
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       66,
                                       world_height) >= 66 then
        par.vegetation = 66
        par.rainfall = 66
        
      else
        par.vegetation = 100
        par.rainfall = 100
      end
      
      if par.drainage >= 33 then
        par.drainage = 20
      end
      
      if par.salinity >= 66 then
        par.salinity = 0
      end
   
    elseif biome_type == df.biome_type.SWAMP_TEMPERATE_SALTWATER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature >= 75) then
        par.temperature = 20
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.rainfall < 66 then
          par.vegetation = 85
          par.rainfall = 85
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       66,
                                       world_height) >= 66 then
        par.vegetation = 66
        par.rainfall = 66  
        
      else
        par.vegetation = 100
        par.rainfall = 100
      end
      
      if par.drainage >= 33 then
        par.drainage = 20
      end
      
      if par.salinity < 66 then
        par.salinity = 75
      end
      
    elseif biome_type == df.biome_type.MARSH_TEMPERATE_FRESHWATER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85)  then
        par.temperature = 20
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.vegetation < 33 or par.vegetation >= 66 then
          par.vegetation = 50
          par.rainfall = 50
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       33,
                                       world_height) >= 66 then
        par.vegetation = 33
        par.rainfall = 33
        
      else
        par.vegetation = 65
        par.rainfall = 65
      end
      
      if par.drainage >= 33 or par.drainage < 10 then
        par.drainage = 20
      end                
      
      if par.salinity >= 66 then
        par.salinity = 0
      end
    
    elseif biome_type == df.biome_type.MARSH_TEMPERATE_SALTWATER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature >= 75) then
        par.temperature = 20
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.vegetation < 33 or par.vegetation >= 66 then
          par.vegetation = 50
          par.rainfall = 50
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       33,
                                       world_height) >= 66 then
        par.vegetation = 33
        par.rainfall = 33  
        
      else
        par.vegetation = 65
        par.rainfall = 65
      end
      
      if par.drainage >= 33 then
        par.drainage = 20
      end
      
      if par.salinity < 66 then
        par.salinity = 75
      end
            
    elseif biome_type == df.biome_type.SWAMP_TROPICAL_FRESHWATER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85)  then
        par.temperature = 90
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.vegetation < 66 then
          par.vegetation = 85
          par.rainfall = 85
        end
      
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       66,
                                       world_height) < 66 then
        par.vegetation = 66
        par.rainfall = 66
        
      else
        par.vegetation = 100
        par.rainfall = 100
      end
      
      if par.drainage >= 33 then
        par.drainage = 20
      end
      
      if par.salinity >= 66 then
        par.salinity = 0
      end
            
    elseif biome_type == df.biome_type.SWAMP_TROPICAL_SALTWATER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85)  then
        par.temperature = 90
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.vegetation < 66 then
          par.vegetation = 85
          par.rainfall = 85
        end
      
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       66,
                                       world_height) < 66 then
        par.vegetation = 66
        par.rainfall = 66
        
      else
        par.vegetation = 100
        par.rainfall = 100
      end
      
      if par.drainage >= 33 or par.drainage < 10 then
        par.drainage = 20
      end                
      
      if par.salinity < 66 then
        par.salinity = 75
      end
      
    elseif biome_type == df.biome_type.SWAMP_MANGROVE then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85)  then
        par.temperature = 90
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.vegetation < 66 then
          par.vegetation = 85
          par.rainfall = 85
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       66,
                                       world_height) < 66 then
        par.vegetation = 66
        par.rainfall = 66
        
      else
        par.vegetation = 100
        par.rainfall = 100
      end
      
      if par.drainage >= 10 then
        par.drainage = 5
      end                 
      
      if par.salinity < 66 then
        par.salinity = 75
      end
      
    elseif biome_type == df.biome_type.MARSH_TROPICAL_FRESHWATER then
       if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85) then
        par.temperature = 90
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.vegetation < 33 or par.vegetation >= 66 then
          par.vegetation = 50
          par.rainfall = 50
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       33,
                                       world_height) < 66 then
        par.vegetation = 33
        par.rainfall = 33
        
      else
        par.vegetation = 65
        par.rainfall = 65
      end

      if par.drainage >= 33 then
        par.drainage = 20
      end
                  
      if par.salinity >= 66 then
        par.salinity = 0
      end
   
    elseif biome_type == df.biome_type.MARSH_TROPICAL_SALTWATER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85) then
        par.temperature = 90
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.vegetation < 33 or par.vegetation >= 66 then
          par.vegetation = 50
          par.rainfall = 50
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       33,
                                       world_height) < 66 then
        par.vegetation = 33
        par.rainfall = 33
        
      else
        par.vegetation = 65
        par.rainfall = 65
      end

      if par.drainage >= 33 then
        par.drainage = 20
      end
                  
      if par.salinity < 66 then
        par.salinity = 75
      end
      
    elseif biome_type == df.biome_type.FOREST_TAIGA then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or par.temperature > 10 then
        par.temperature = 0
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.rainfall < 66 then
          par.vegetation = 85
          par.rainfall = 85
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       66,
                                       world_height) >= 66 then
        par.vegetation = 66
        par.rainfall = 66
        
      else
        par.vegetation = 100
        par.rainfall = 100
      end
      
      if par.drainage < 33 then
        par.drainage = 65
      end
      
    elseif biome_type == df.biome_type.FOREST_TEMPERATE_CONIFER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < 10 or par.temperature >= 65 then
        par.temperature = 20
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.rainfall < 66 or par.rainfall > 74 then
          par.vegetation = 70
          par.rainfall = 70
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       66,
                                       world_height) >= 66 then
        par.vegetation = 66
        par.rainfall = 66
        
      else
        par.vegetation = 74
        par.rainfall = 74
      end
      
      if par.drainage < 33 then
        par.drainage = 65
      end
      
    elseif biome_type == df.biome_type.FOREST_TEMPERATE_BROADLEAF then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < 65 or
         (pole == -1 and par.temperature >= 85) then
        par.temperature = 70
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.rainfall < 75 then
          par.vegetation = 85
          par.rainfall = 85
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       75,
                                       world_height) >= 66 then
        par.vegetation = 75
        par.rainfall = 75
        
      else
        par.vegetation = 100
        par.rainfall = 100
      end        
      
      if par.drainage < 33 then
        par.drainage = 65
      end
      
    elseif biome_type == df.biome_type.FOREST_TROPICAL_CONIFER then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85) then
        par.temperature = 90
      end
      
      if is_tropical_area_by_latitude then
        if par.rainfall < 66 or par.rainfall > 74 then
          par.vegetation = 70
          par.rainfall = 70
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       66,
                                       world_height) < 66 then
        par.vegetation = 66
        par.rainfall = 66
        
      else
        par.vegetation = 74
        par.rainfall = 74
      end
      
      if par.drainage < 33 then
        par.drainage = 65
      end
      
    elseif biome_type == df.biome_type.FOREST_TROPICAL_DRY_BROADLEAF then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85) then
        par.temperature = 90
      end
            
      if get_parameter_percentage (pole,
                                   pos_y,
                                    75,
                                    world_height) < 66 then
        par.vegetation = 75
        par.rainfall = 75
        
      else
        par.vegetation = 100
        par.rainfall = 100
      end
      
      if par.drainage < 33 then
        par.drainage = 65
      end
      
    elseif biome_type == df.biome_type.FOREST_TROPICAL_MOIST_BROADLEAF then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85) then
        par.temperature = 90
      end
      
      par.vegetation = 100
      par.rainfall = 100
      
      if par.drainage < 33 then
        par.drainage = 65
      end     
      
    elseif biome_type == df.biome_type.GRASSLAND_TEMPERATE then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature >= 85) then
        par.temperature = 20
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.rainfall < 10 or par.rainfall > 19 then
          par.vegetation = 15
          par.rainfall = 15
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       10,
                                       world_height) >= 66 then
        par.vegetation = 10
        par.rainfall = 10
        
      else
        par.vegetation = 19
        par.rainfall = 19
      end
      
    elseif biome_type == df.biome_type.SAVANNA_TEMPERATE then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature >= 85) then
        par.temperature = 20
      end
      
      if not is_possible_tropical_area_by_latitude then
        if par.rainfall < 20 or par.rainfall > 32 then
          par.vegetation = 25
          par.rainfall = 25
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       20,
                                       world_height) >= 6 then
        par.vegetation = 20
        par.rainfall = 20
        
      else
        par.vegetation = 32
        par.rainfall = 32
      end
      
    elseif biome_type == df.biome_type.SHRUBLAND_TEMPERATE then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature >= 85) then
        par.temperature = 20
      end

      if not is_possible_tropical_area_by_latitude then
        if par.rainfall < 33 or par.rainfall > 65 then
          par.vegetation = 50
          par.rainfall = 50
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       33,
                                       world_height) >= 66 then
        par.vegetation = 33
        par.rainfall = 33
        
      else
        par.vegetation = 65
        par.rainfall = 65
      end
      
      if par.drainage < 33 then
        par.drainage = 65
      end     
      
    elseif biome_type == df.biome_type.GRASSLAND_TROPICAL then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85) then
        par.temperature = 90
      end
      
      if is_tropical_area_by_latitude then
        if par.rainfall < 10 or par.rainfall > 19 then
          par.vegetation = 15
          par.rainfall = 15
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       10,
                                       world_height) < 66 then
        par.vegetation = 10
        par.rainfall = 10
        
      else
        par.vegetation = 19
        par.rainfall = 19
      end
      
    elseif biome_type == df.biome_type.SAVANNA_TROPICAL then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85) then
        par.temperature = 90
      end
      
      if is_tropical_area_by_latitude then
        if par.rainfall < 20 or par.rainfall > 32 then
          par.vegetation = 25
          par.rainfall = 25
        end
    
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       20,
                                       world_height) < 6 then
        par.vegetation = 20
        par.rainfall = 20
        
      else
        par.vegetation = 32
        par.rainfall = 32
      end
      
    elseif biome_type == df.biome_type.SHRUBLAND_TROPICAL then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 or
         (pole == -1 and par.temperature < 85) then
        par.temperature = 90
      end

      if is_tropical_area_by_latitude then
        if par.rainfall < 33 or par.rainfall > 65 then
          par.vegetation = 50
          par.rainfall = 50
        end
        
      elseif get_parameter_percentage (pole,
                                       pos_y,
                                       33,
                                       world_height) < 66 then
        par.vegetation = 33
        par.rainfall = 33
        
      else
        par.vegetation = 65
        par.rainfall = 65
      end
      
      if par.drainage < 33 then
        par.drainage = 65
      end     
      
    elseif biome_type == df.biome_type.DESERT_BADLAND then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 then
        par.temperature = 70
      end
      
      if par.rainfall >= 10 then
        par.vegetation = 6
        par.rainfall = 6
      end
      
      if par.drainage < 66 then
        par.drainage = 85
      end
      
    elseif biome_type == df.biome_type.DESERT_ROCK then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 then
        par.temperature = 70
      end
      
      if par.rainfall >= 10 then
        par.vegetation = 6
        par.rainfall = 6
      end
      
      if par.drainage < 33 or par.drainage >= 66 then
        par.drainage = 50
      end      
      
    elseif biome_type == df.biome_type.DESERT_SAND then
      if par.elevation < 100 or par.elevation >= 150 then
        par.elevation = 125
      end
      
      if par.temperature < -5 then
        par.temperature = 70
      end
      
      if par.rainfall >= 10 then
        par.vegetation = 6
        par.rainfall = 6
      end
      
      if par.drainage >= 33 then
        par.drainage = 15
      end      
      
    elseif biome_type == df.biome_type.OCEAN_TROPICAL then
      if par.elevation >= 100 then
        par.elevation = 50
      end
      
      if pole == -1 and par.temperature < 85 then
        par.temperature = 90
      end
      
    elseif biome_type == df.biome_type.OCEAN_TEMPERATE then
      if par.elevation >= 100 then
        par.elevation = 50
      end
      
      if par.temperature <= -5 or
         (pole == -1 and par.temperature >= 85) then
        par.temperature = 20
      end
      
    elseif biome_type == df.biome_type.OCEAN_ARCTIC then
      if par.elevation >= 100 then
        par.elevation = 50
      end
      
      if par.temperature > -5 then
        par.temperature = -20
      end
      
    elseif biome_type == df.biome_type.LAKE_TEMPERATE_FRESHWATER then
      if par.elevation > 99 then
        par.elevation = 95
      end

      if pole == -1 and par.temperature >= 75 then
        par.temperature = 50
      end

      if par.salinity >= 33 then
        par.salinity = 0
      end        

    elseif biome_type == df.biome_type.LAKE_TEMPERATE_BRACKISHWATER then
      if par.elevation > 99 then
        par.elevation = 95
      end

      if pole == -1 and par.temperature >= 75 then
        par.temperature = 50
      end

      if par.salinity < 33 or
         par.salinity >= 66 then
        par.salinity = 50
      end        
     
    elseif biome_type == df.biome_type.LAKE_TEMPERATE_SALTWATER then
      if par.elevation > 99 then
        par.elevation = 95
      end

      if pole == -1 and par.temperature >= 75 then
        par.temperature = 50
      end

      if par.salinity < 66 then
        par.salinity = 75
      end        

    elseif biome_type == df.biome_type.LAKE_TROPICAL_FRESHWATER then
      if par.elevation > 99 then
        par.elevation = 95
      end

      if pole == -1 and par.temperature < 75 then
        par.temperature = 85
      end

      if par.salinity >= 33 then
        par.salinity = 0
      end        

    elseif biome_type == df.biome_type.LAKE_TROPICAL_BRACKISHWATER then
      if par.elevation > 99 then
        par.elevation = 95
      end

      if pole == -1 and par.temperature < 75 then
        par.temperature = 85
      end

      if par.salinity < 33 or
         par.salinity >= 66 then
        par.salinity = 50
      end        
     
    elseif biome_type == df.biome_type.LAKE_TROPICAL_SALTWATER then
      if par.elevation > 99 then
        par.elevation = 95
      end

      if pole == -1 and par.temperature < 75 then
        par.temperature = 85
      end

      if par.salinity < 66 then
        par.salinity = 75
      end        
    
    else
      dialog.showMessage("Failure", "Requested biome cannot be created", COLOR_RED)    
    end
    
    return par
  end
  
  --============================================================

  function world_region_type_of (biome_type, drainage)
    if biome_type == df.biome_type.MOUNTAIN then
      return df.world_region_type.Mountains
      
    elseif biome_type == df.biome_type.GLACIER then
      return df.world_region_type.Glacier
       
    elseif biome_type == df.biome_type.TUNDRA then
      return df.world_region_type.Tundra
       
    elseif biome_type == df.biome_type.SWAMP_TEMPERATE_FRESHWATER or
           biome_type == df.biome_type.SWAMP_TEMPERATE_SALTWATER or
           biome_type == df.biome_type.MARSH_TEMPERATE_FRESHWATER or
           biome_type == df.biome_type.MARSH_TEMPERATE_SALTWATER or
           biome_type == df.biome_type.SWAMP_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.SWAMP_TROPICAL_SALTWATER or
           biome_type == df.biome_type.SWAMP_MANGROVE or
           biome_type == df.biome_type.MARSH_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.MARSH_TROPICAL_SALTWATER then
      return df.world_region_type.Swamp
       
    elseif biome_type == df.biome_type.FOREST_TAIGA or
           biome_type == df.biome_type.FOREST_TEMPERATE_CONIFER or
           biome_type == df.biome_type.FOREST_TEMPERATE_BROADLEAF or
           biome_type == df.biome_type.FOREST_TROPICAL_CONIFER or
           biome_type == df.biome_type.FOREST_TROPICAL_DRY_BROADLEAF or
           biome_type == df.biome_type.FOREST_TROPICAL_MOIST_BROADLEAF then
      return df.world_region_type.Jungle
       
    elseif biome_type == df.biome_type.GRASSLAND_TEMPERATE or
           biome_type == df.biome_type.SAVANNA_TEMPERATE or
           biome_type == df.biome_type.SHRUBLAND_TEMPERATE or
           biome_type == df.biome_type.GRASSLAND_TROPICAL or
           biome_type == df.biome_type.SAVANNA_TROPICAL or
           biome_type == df.biome_type.SHRUBLAND_TROPICAL then
      if drainage < 50 then
        return df.world_region_type.Steppe
        
      else
        return df.world_region_type.Hills
      end
       
    elseif biome_type == df.biome_type.DESERT_BADLAND or
           biome_type == df.biome_type.DESERT_ROCK or
           biome_type == df.biome_type.DESERT_SAND then
      return df.world_region_type.Desert
       
    elseif biome_type == df.biome_type.OCEAN_TROPICAL or
           biome_type == df.biome_type.OCEAN_TEMPERATE or
           biome_type == df.biome_type.OCEAN_ARCTIC then
      return df.world_region_type.Ocean
       
    elseif biome_type == df.biome_type.POOL_TEMPERATE_FRESHWATER or
           biome_type == df.biome_type.POOL_TEMPERATE_BRACKISHWATER or
           biome_type == df.biome_type.POOL_TEMPERATE_SALTWATER or
           biome_type == df.biome_type.POOL_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.POOL_TROPICAL_BRACKISHWATER or
           biome_type == df.biome_type.POOL_TROPICAL_SALTWATER then
      return nil  --  Not represented on the region level
      
    elseif biome_type == df.biome_type.LAKE_TEMPERATE_FRESHWATER or
           biome_type == df.biome_type.LAKE_TEMPERATE_BRACKISHWATER or
           biome_type == df.biome_type.LAKE_TEMPERATE_SALTWATER or
           biome_type == df.biome_type.LAKE_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.LAKE_TROPICAL_BRACKISHWATER or
           biome_type == df.biome_type.LAKE_TROPICAL_SALTWATER then
      return df.world_region_type.Lake
       
    elseif biome_type == df.biome_type.RIVER_TEMPERATE_FRESHWATER or
           biome_type == df.biome_type.RIVER_TEMPERATE_BRACKISHWATER or
           biome_type == df.biome_type.RIVER_TEMPERATE_SALTWATER or
           biome_type == df.biome_type.RIVER_TROPICAL_FRESHWATER or
           biome_type == df.biome_type.RIVER_TROPICAL_BRACKISHWATER or
           biome_type == df.biome_type.RIVER_TROPICAL_SALTWATER or
           biome_type == df.biome_type.SUBTERRANEAN_WATER or
           biome_type == df.biome_type.SUBTERRANEAN_CHASM or
           biome_type == df.biome_type.SUBTERRANEAN_LAVA then
      return nil  --  Not represented on the region level
    end  
  end
  
  --============================================================

  function Sort (list)
    local temp
    
    for i, dummy in ipairs (list) do
      for k = i + 1, #list do
        if list [k].name < list [i].name then
          temp = list [i]
          list [i] = list [k]
          list [k] = temp
        end
      end
    end
  end
  
  --============================================================

  function Sort_Keep_First (list)  --  Ensures the first (default) item remains the first one in the list.
    local temp
    
    for i, dummy in ipairs (list) do
      if i > 1 then
        for k = i + 1, #list do
          if list [k].name < list [i].name then
            temp = list [i]
            list [i] = list [k]
            list [k] = temp
          end
        end
      end
    end
  end
  
  --============================================================

  function Locate_Animal (index, layer)
    if layer == Surface then
      for i, population in ipairs (df.global.world.world_data.regions [region [layer]].population) do
        if Is_Animal (population.type) and
          population.race == index then
          return i
        end
      end
      
    else
      for i, population in ipairs (df.global.world.world_data.underground_regions [region [layer]].feature_init.feature.population) do
        if Is_Animal (population.type) and
           population.race == index then
          return i
        end
      end
    end
    
    return nil
  end
  
  --============================================================

  function Locate_Plant (index, layer)
    if layer == Surface then
      for i, population in ipairs (df.global.world.world_data.regions [region [layer]].population) do
        if Is_Plant (population.type) and
           population.plant == index then
          return i
        end
      end
    else
      for i, population in ipairs (df.global.world.world_data.underground_regions [region [layer]].feature_init.feature.population) do
        if Is_Plant (population.type) and
           population.plant == index then
          return i
        end
      end
    end
    
    return nil
  end
  
  --============================================================

  function Fit (Item, Size)
    return Item .. string.rep (' ', Size - string.len (Item))
  end
   
  --============================================================

  function Fit_Right (Item, Size)
    if string.len (Item) > Size then
      return string.rep ('#', Size)
    else
      return string.rep (' ', Size - string.len (Item)) .. Item
    end
  end

  --============================================================

  function Bool_To_YN (value)
    if value then
      return 'Y'
    else
      return 'N'
    end
  end
  
  --============================================================

  function Savagery_Pen (evilness)
    if evilness < 33 then
      return COLOR_LIGHTCYAN
    elseif evilness < 66 then
      return COLOR_YELLOW
    else
      return COLOR_LIGHTMAGENTA
    end
  end
  
  --============================================================
  
  local Region_Pen =
   {[0] = COLOR_WHITE,
    [1] = COLOR_LIGHTCYAN,
    [2] = COLOR_CYAN,
    [3] = COLOR_LIGHTBLUE,
    [4] = COLOR_BLUE,
    [5] = COLOR_LIGHTGREEN,
    [6] = COLOR_GREEN,
    [7] = COLOR_YELLOW,
    [8] = COLOR_LIGHTMAGENTA,
    [9] = COLOR_MAGENTA,
    [10] = COLOR_LIGHTRED,
    [11] = COLOR_RED,
    [12] = COLOR_GREY,
    [13] = COLOR_DARKGREY,
    [14] = COLOR_BROWN}

  --============================================================

  function Is_River_Consistent (river)
    if #river.path.x == 0 then
      return false
    end
    
    local last_x = river.path.x [#river.path.x - 1]
    local last_y = river.path.y [#river.path.y - 1]
    
    return (river.end_pos.x - 1 == last_x and river.end_pos.y == last_y) or
           (river.end_pos.x + 1 == last_x and river.end_pos.y == last_y) or
           (river.end_pos.x == last_x and river.end_pos.y - 1 == last_y) or
           (river.end_pos.x == last_x and river.end_pos.y + 1 == last_y)
  end
  
  --============================================================

  function Setup_Rivers ()
    local broken = false
    
    for i = 0, df.global.world.worldgen.worldgen_parms.dim_x - 1 do
      river_matrix [i] = {}
          
      for k = 0, df.global.world.worldgen.worldgen_parms.dim_y - 1 do
        river_matrix [i] [k] = {path = -1,
                                sink = 0,
                                color = COLOR_WHITE} 
      end
    end
      
    for i, river in ipairs (df.global.world.world_data.rivers) do
      broken = not Is_River_Consistent (river)
      
      if broken and #river.path.x == 0 then
        lost_rivers_present = true
      end
      
      for k, path_x in ipairs (river.path.x) do
        river_matrix [path_x] [river.path.y [k]].path = i
        
        if broken then
          river_matrix [path_x] [river.path.y [k]].color = COLOR_LIGHTRED
        end
      end
        
      if river.end_pos.x >= 0 and  --  The sink can be off the map, so we need to check that first.
         river.end_pos.x < df.global.world.worldgen.worldgen_parms.dim_x and
         river.end_pos.y >= 0 and
         river.end_pos.y < df.global.world.worldgen.worldgen_parms.dim_y then
        river_matrix [river.end_pos.x] [river.end_pos.y].sink = 
          river_matrix [river.end_pos.x] [river.end_pos.y].sink + 1
          
        if broken then
          river_matrix [river.end_pos.x] [river.end_pos.y].color = COLOR_LIGHTRED
        end
      end
    end
    
    for i = 0, df.global.world.worldgen.worldgen_parms.dim_x - 1 do
      for k = 0, df.global.world.worldgen.worldgen_parms.dim_y - 1 do
        if river_matrix [i] [k].color ~= COLOR_LIGHTRED then  --  Broken rivers take precedence
          if river_matrix [i] [k].path == -1 then
            if river_matrix [i] [k].sink == 0 then
              river_matrix [i] [k].color = COLOR_WHITE
            
            else
              river_matrix [i] [k].color = COLOR_GREY
            end
          
          else
            if river_matrix [i] [k].sink == 0 then
              river_matrix [i] [k].color = COLOR_LIGHTGREEN
            
            else
              river_matrix [i] [k].color = COLOR_GREEN
            end
          end
        end
      end
    end
  end
  
  --============================================================
  --  Does NOT check if there is a river at the extension as a
  --  sink does not need a river free target. Thus, the caller
  --  has to do this check if the intention is to check for an
  --  extension of the course rather than with a sink.
  --
  function legal_river_extension (x, y, current_river)
    if #df.global.world.world_data.rivers [current_river].path.x == 0 then  --  Cleared river
      return true
    end
    
    local last_x = df.global.world.world_data.rivers [current_river].path.x 
                     [#df.global.world.world_data.rivers [current_river].path.x - 1]
    local last_y = df.global.world.world_data.rivers [current_river].path.y 
                     [#df.global.world.world_data.rivers [current_river].path.y - 1]
    
    return river_matrix [x] [y].path ~= current_river and
           ((last_x - 1 == x and last_y == y) or
            (last_x + 1 == x and last_y == y) or
            (last_x == x and last_y - 1 == y) or
            (last_x == x and last_y + 1 == y))    
  end
  
  --============================================================
  --  Exactly one of the deltas should be -1 or 1 and the other 0. Also
  --  assumes (x, y) has been verified to be the end of the current river's
  --  path.
  --
  function Is_Legal_Sink_Direction (x, y, delta_x, delta_y, current_river)
    if delta_x == -1 then
      if x == 0 then
        return true
      end
      
    elseif delta_x == 1 then
      if x == df.global.world.worldgen.worldgen_parms.dim_x - 1 then
        return true
      end
      
    elseif delta_y == -1 then
      if y == 0 then
        return true
      end
      
    else
      if y == df.global.world.worldgen.worldgen_parms.dim_y - 1 then
        return true
      end
    end
    
    return river_matrix [x + delta_x] [y + delta_y].path ~= current_river
  end
  
  --============================================================

  function Has_Legal_River_Sink_Direction (x, y, current_river)
    if #df.global.world.world_data.rivers [current_river].path.x == 0 then
      return false  --  An empty river cannot be given a sink.
    end
    
    local last_x = df.global.world.world_data.rivers [current_river].path.x 
                     [#df.global.world.world_data.rivers [current_river].path.x - 1]
    local last_y = df.global.world.world_data.rivers [current_river].path.y 
                     [#df.global.world.world_data.rivers [current_river].path.y - 1]
                    
    if x ~= last_x or y ~= last_y then
      return false
    end
    
    return Is_Legal_Sink_Direction (x, y, -1, 0, current_river) or
           Is_Legal_Sink_Direction (x, y, 1, 0, current_river) or
           Is_Legal_Sink_Direction (x, y, 0, -1, current_river) or
           Is_Legal_Sink_Direction (x, y, 0, 1, current_river)
  end
  
  --============================================================

  local Region_Character =
  {[0] = 'A',
    [1] = 'B',
    [2] = 'C',
    [3] = 'D',
    [4] = 'E',
    [5] = 'F',
    [6] = 'G',
    [7] = 'H',
    [8] = 'K',
    [9] = 'L',
    [10] = 'M',
    [11] = 'O',
    [12] = 'P',
    [13] = 'R',
    [14] = 'S'}
  
  --============================================================

  function Update_Region_Tile (x_coord, y_coord)
    local fg
    local bg
    local tile_color
    local region_id = df.global.world.world_data.region_map [x_coord]:_displace (y_coord).region_id
    local ch = Region_Character [math.floor (region_id / 15) % 15]
    
    if x_coord == x and y_coord == y then
      fg = COLOR_BLACK
      bg = Region_Pen [region_id % 15]
      tile_color = false
          
    else
      fg = Region_Pen [region_id % 15]
      bg = COLOR_BLACK
      tile_color = true
    end
        
    Main_Page.Region_Grid:set (x_coord,
                               y_coord,
                               {ch = ch,
                                fg = fg,
                                bg = bg,
                                bold = false,
                                tile = nil,
                                tile_color = tile_color,
                                tile_fg = nil,
                                tile_bg = nil})
  end
  
  --============================================================

  function Make_Region ()
    local ch
    local fg
    local bg
    local tile_color
    local region_id
    
    for i = 0, map_height - 1 do
      for k = 0, map_width - 1 do
        Update_Region_Tile (k, i)
      end
    end
  end
  
  --============================================================

  function Biome_Color (savagery, evilness)
    if evilness < 33 then
      if savagery < 33 then
        return COLOR_BLUE
      elseif savagery < 66 then
        return COLOR_GREEN
      else
        return COLOR_LIGHTCYAN
      end

    elseif evilness < 66 then
      if savagery < 33 then
        return COLOR_GREY
      elseif savagery < 66 then
        return COLOR_LIGHTGREEN
      else
        return COLOR_YELLOW
      end

    else
      if savagery < 33 then
        return COLOR_MAGENTA
      elseif savagery < 66 then
        return COLOR_LIGHTRED
      else
        return COLOR_RED
      end
    end
  end

  --============================================================

  function Update_Biome_Tile (x_coord, y_coord)
    local fg
    local bg
    local river_fg
    local river_bg
    local tile_color
    local region = df.global.world.world_data.region_map [x_coord]:_displace (y_coord)
    local ch = get_biome_character (y_coord,
                                    y_coord,
                                    y_coord,
                                    map_height,
                                    region.temperature,
                                    region.elevation,
                                    region.drainage,
                                    region.rainfall,
                                    region.salinity,
                                    region.rainfall,  -- Proxy for vegetation as that isn't set until finalization
                                    region.flags.is_lake)
    if x_coord == x and y_coord == y then
      fg = COLOR_BLACK
      bg = Biome_Color (region.savagery, region.evilness)
      tile_color = false
      river_fg = COLOR_BLACK
      river_bg = river_matrix [x_coord] [y_coord].color
          
    else
      fg = Biome_Color (region.savagery, region.evilness)
      bg = COLOR_BLACK
      tile_color = true
      river_fg = river_matrix [x_coord] [y_coord].color
      river_bg = COLOR_BLACK
    end
        
    Main_Page.Biome_Grid:set (x_coord,
                              y_coord,
                              {ch = ch,
                               fg = fg,
                               bg = bg,
                               bold = false,
                               tile = nil,
                               tile_color = tile_color,
                               tile_fg = nil,
                               tile_bg = nil})

    Map_Page.Biome_Grid:set (x_coord,
                             y_coord,
                             {ch = ch,
                              fg = fg,
                              bg = bg,
                              bold = false,
                              tile = nil,
                              tile_color = tile_color,
                              tile_fg = nil,
                              tile_bg = nil})
                              
    River_Page.River_Grid:set (x_coord,
                               y_coord,
                               {ch = ch,
                                fg = river_fg,
                                bg = river_bg,
                                bold = false,
                                tile = nil,
                                tile_color = tile_color,
                                tile_fg = nil,
                                tile_bg = nil})
  end
  
  --============================================================

  function Make_Biome ()
    local ch
    local fg
    local bg
    local tile_color
    local region
    
    for i = 0, map_height - 1 do
      for k = 0, map_width - 1 do
        Update_Biome_Tile (k, i)
      end
    end
  end

  --============================================================

  function Flip_Underground_Tile (x_coord, y_coord)
    local fg
    local pen
    
    for i = 0, 3 do
      if region [i] then
        pen = Main_Page.Underground_Grid [i]:get (x_coord, y_coord)
        fg = pen.bg
        pen.bg = pen.fg
        pen.fg = fg
        pen.tile_color = not pen.tile_color
        Main_Page.Underground_Grid [i]:set (x_coord, y_coord, pen)
      end
    end
  end
  
  --============================================================

  function Make_Underground (x, y)
    local ch
    local fg
    local bg
    local tile_color
    local region_id
    
    for i, region in ipairs (df.global.world.world_data.underground_regions) do
      ch = Region_Character [math.floor (i / 15) % 15]
      
      if region.layer_depth >= 0 and
         region.layer_depth <= 3 then
        for k, x_coord in ipairs (region.region_coords.x) do          
          if x == x_coord and y == region.region_coords.y [k] then
            fg = COLOR_BLACK
            bg = Region_Pen [i % 15]
            tile_color = false
          
          else
            fg = Region_Pen [i % 15]
            bg = COLOR_BLACK
            tile_color = true
          end
        
          Main_Page.Underground_Grid [region.layer_depth]:set (x_coord, 
                                                               region.region_coords.y [k],
                                                               {ch = ch,
                                                                fg = fg,
                                                                bg = bg,
                                                                bold = false,
                                                                tile = nil,
                                                                tile_color = tile_color,
                                                                tile_fg = nil,
                                                                tile_bg = nil})
        end
      end
    end
  end
  
  --============================================================

  function Flip_Geo_Tile (x_coord, y_coord)
    local fg
    local pen = Main_Page.Geo_Grid:get (x_coord, y_coord)
    
    fg = pen.bg
    pen.bg = pen.fg
    pen.fg = fg
    pen.tile_color = not pen.tile_color
    Main_Page.Geo_Grid:set (x_coord, y_coord, pen)
  end
  
  --============================================================

  function Make_Geo (x, y)
    local ch
    local fg
    local bg
    local tile_color
    local geo_index
    
    for i = 0, map_width - 1 do
      for k = 0, map_height - 1 do
        geo_index = df.global.world.world_data.region_map [i]:_displace (k).geo_index
       
        ch = Region_Character [math.floor (geo_index / 15) % 15]
      
        if i == x and k == y then
          fg = COLOR_BLACK
          bg = Region_Pen [geo_index % 15]
          tile_color = false
          
        else
          fg = Region_Pen [geo_index % 15]
          bg = COLOR_BLACK
          tile_color = true
        end
        
        Main_Page.Geo_Grid:set (i, 
                                k,
                                {ch = ch,
                                 fg = fg,
                                 bg = bg,
                                 bold = false,
                                 tile = nil,
                                 tile_color = tile_color,
                                 tile_fg = nil,
                                 tile_bg = nil})
        
       end
    end
  end
  
  --============================================================

  function Add_One (List, Index)
    List [Index] = List [Index] + 1
  end
  
  --============================================================
  
  function Make_Profile (region_index)
    local Profile = 
      {BIOME_MOUNTAIN = 0,
       BIOME_GLACIER = 0,
       BIOME_TUNDRA = 0,
       BIOME_SWAMP_TEMPERATE_SALTWATER = 0,
       BIOME_SWAMP_TEMPERATE_FRESHWATER = 0,
       BIOME_MARSH_TEMPERATE_FRESHWATER = 0,
       BIOME_MARSH_TEMPERATE_SALTWATER = 0,
       BIOME_SWAMP_TROPICAL_FRESHWATER = 0,
       BIOME_SWAMP_TROPICAL_SALTWATER = 0,
       BIOME_SWAMP_MANGROVE = 0,
       BIOME_MARSH_TROPICAL_FRESHWATER = 0,
       BIOME_MARSH_TROPICAL_SALTWATER = 0,
       BIOME_FOREST_TAIGA = 0,
       BIOME_FOREST_TEMPERATE_CONIFER = 0,
       BIOME_FOREST_TEMPERATE_BROADLEAF = 0,
       BIOME_FOREST_TROPICAL_CONIFER = 0,
       BIOME_FOREST_TROPICAL_DRY_BROADLEAF = 0,
       BIOME_FOREST_TROPICAL_MOIST_BROADLEAF = 0,
       BIOME_GRASSLAND_TEMPERATE = 0,
       BIOME_SAVANNA_TEMPERATE = 0,
       BIOME_SHRUBLAND_TEMPERATE = 0,
       BIOME_GRASSLAND_TROPICAL = 0,
       BIOME_SAVANNA_TROPICAL = 0,
       BIOME_SHRUBLAND_TROPICAL = 0,
       BIOME_DESERT_BADLAND = 0,
       BIOME_DESERT_ROCK = 0,
       BIOME_DESERT_SAND = 0,
       BIOME_OCEAN_TROPICAL = 0,
       BIOME_OCEAN_TEMPERATE = 0,
       BIOME_OCEAN_ARCTIC = 0,
       BIOME_LAKE_TEMPERATE_FRESHWATER = 0,
       BIOME_LAKE_TEMPERATE_BRACKISHWATER = 0,
       BIOME_LAKE_TEMPERATE_SALTWATER = 0,
       BIOME_LAKE_TROPICAL_FRESHWATER = 0,
       BIOME_LAKE_TROPICAL_BRACKISHWATER = 0,
       BIOME_LAKE_TROPICAL_SALTWATER = 0,
       --BIOME_SUBTERRANEAN_WATER = 0,
       --BIOME_SUBTERRANEAN_CHASM = 0,
       --BIOME_SUBTERRANEAN_LAVA = 0,
       GOOD = false,
       EVIL = false,
       SAVAGE = 0}
    
    if not isDFHackOlderThan ("0.43.05-r2") then
      for i, value in pairs (df.global.world.world_data.regions [region_index].biome_tile_counts) do
        Profile ["BIOME_" .. i] = value
      end
    end
    
    for i, x_coord in ipairs (df.global.world.world_data.regions [region_index].region_coords.x) do
      local y_coord = df.global.world.world_data.regions [region_index].region_coords.y [i]      
      local biome = df.global.world.world_data.region_map [x_coord]:_displace (y_coord)

      if isDFHackOlderThan ("0.43.05-r2") then      
        local biome_type = get_biome_type
           (y_coord,
            map_height,
            biome.temperature,
            biome.elevation,
            biome.drainage,
            biome.rainfall,
            biome.salinity,
            biome.rainfall,  --  biome.vegetation, --  Should be vegetation, but doesn't seem to be set before finalization.
            biome.flags.is_lake)
    
        Add_One (Profile, "BIOME_" .. df.biome_type [biome_type])
      end
      
      if biome.evilness < 33 then
        Profile.GOOD = true
      elseif biome.evilness >= 66 then
        Profile.EVIL = true
      end
      
      if biome.savagery >= 66 then
        Add_One (Profile, "SAVAGE")
      end
    end  
     
    Animal_Page.Present_List [Surface] = {}
    Animal_Page.Absent_List [Surface] = {}
    Plant_Page.Present_List [Surface] = {}
    Plant_Page.Absent_List [Surface] = {}
    
    for i, creature in ipairs (df.global.world.raws.creatures.all) do
      local found = false
      local matching = false
      
      for k, v in ipairs (df.global.world.world_data.regions [region_index].population) do
        if Is_Animal (v.type) and
           v.race == i then
          table.insert (Animal_Page.Present_List [Surface], {name = creature.creature_id, index = i})
          found = true
          break
        end   
      end
            
      if not found then
        local creature_raw_flags_passed = true
        
        if creature_raw_flags_renamed then
          if creature.flags.EQUIPMENT_WAGON or
             creature.flags.HAS_ANY_MEGABEAST or
             creature.flags.HAS_ANY_SEMIMEGABEAST or
             creature.flags.GENERATED or  --  When is this flag set?
             creature.flags.HAS_ANY_TITAN or
             creature.flags.HAS_ANY_UNIQUE_DEMON or
             creature.flags.HAS_ANY_DEMON or
             creature.flags.HAS_ANY_NIGHT_CREATURE or
             (creature.flags.GOOD and not Profile.GOOD) or
             (creature.flags.EVIL and not Profile.EVIL) or
             (creature.flags.SAVAGE and Profile.SAVAGE == 0) then
            creature_raw_flags_passed = false
          end
          
        elseif creature.flags.EQUIPMENT_WAGON or
               creature.flags.CASTE_MEGABEAST or
               creature.flags.CASTE_SEMIMEGABEAST or
               creature.flags.GENERATED or  --  When is this flag set?
               creature.flags.CASTE_TITAN or
               creature.flags.CASTE_UNIQUE_DEMON or
               creature.flags.CASTE_DEMON or
               creature.flags.CASTE_NIGHT_CREATURE_ANY or
               (creature.flags.GOOD and not Profile.GOOD) or
               (creature.flags.EVIL and not Profile.EVIL) or
               (creature.flags.SAVAGE and Profile.SAVAGE == 0) then
              creature_raw_flags_passed = false
        end
        
        if creature_raw_flags_passed then
          for l, value in pairs (Profile) do
            if l == "GOOD" or
               l == "EVIL"  then
              if creature.flags [l] and value == false then
                matching = false
                break
              end
          
            elseif l == "SAVAGE" then
              if creature.flags [l] and value == 0 then
                matching = false
                break
              end
              
            elseif creature.flags [l] and value > 0 then
              matching = true
            end
          end
        end
                
        if matching then
          table.insert (Animal_Page.Absent_List [Surface], {name = creature.creature_id, index = i})
        elseif Unrestricted then
          table.insert (Animal_Page.Absent_List [Surface], {name = creature.creature_id, index = i})
        end
      end
    end

    for i, plant in ipairs (df.global.world.raws.plants.all) do
      local found = false
      local matching = false
      
      for k, v in ipairs (df.global.world.world_data.regions [region_index].population) do
        if Is_Plant (v.type) and
           v.plant == i then
          table.insert (Plant_Page.Present_List [Surface], {name = plant.id, index = i})
          found = true
          break
        end   
      end
            
      if not found then
        for l, value in pairs (Profile) do
          if l == "GOOD" or
             l == "EVIL"  then
            if plant.flags [l] and value == false then
              matching = false
              break
            end
          
          elseif l == "SAVAGE" then
            if plant.flags [l] and value == 0 then
              matching = false
              break
            end
            
          elseif plant.flags [l] and value > 0 then
            matching = true
          end
        end
        
        if matching then
          table.insert (Plant_Page.Absent_List [Surface], {name = plant.id, index = i})
          
        elseif Unrestricted then
          table.insert (Plant_Page.Absent_List [Surface], {name = plant.id, index = i})
        end
      end
    end
    
    Sort (Animal_Page.Present_List [Surface])
    Sort (Animal_Page.Absent_List [Surface])
    Sort (Plant_Page.Present_List [Surface])
    Sort (Plant_Page.Absent_List [Surface])
    
    return Profile
  end
  
  --============================================================

  function Make_Subterranean_Profile (region_index, layer_index)
    local Profile = 
      {BIOME_SUBTERRANEAN_WATER = 0,
       BIOME_SUBTERRANEAN_CHASM = 0,
       BIOME_SUBTERRANEAN_LAVA = 0}
    
    for i, x_coord in ipairs (df.global.world.world_data.underground_regions [region_index].region_coords.x) do
      local y_coord = df.global.world.world_data.underground_regions [region_index].region_coords.y [i]      
      local underground_water
      
      if underground_region_type_updated then
        underground_water = df.global.world.world_data.underground_regions [region_index].water
      else
        underground_water = df.global.world.world_data.underground_regions [region_index].unk_7a
      end
      
      if layer_index == 3 then
        Profile.BIOME_SUBTERRANEAN_LAVA = Profile.BIOME_SUBTERRANEAN_LAVA + 1        
      elseif underground_water < 10 then
        Profile.BIOME_SUBTERRANEAN_CHASM = Profile.BIOME_SUBTERRANEAN_CHASM + 1
      else
        Profile.BIOME_SUBTERRANEAN_WATER = Profile.BIOME_SUBTERRANEAN_WATER + 1
      end
    end
    
    Animal_Page.Present_List [layer_index] = {}
    Animal_Page.Absent_List [layer_index] = {}
    Plant_Page.Present_List [layer_index] = {}
    Plant_Page.Absent_List [layer_index] = {}
        
    for i, creature in ipairs (df.global.world.raws.creatures.all) do
      local found = false
      local matching
      
      for k, v in ipairs (df.global.world.world_data.underground_regions [region_index].feature_init.feature.population) do
        if Is_Animal (v.type) and
           v.race == i then
          table.insert (Animal_Page.Present_List [layer_index], {name = creature.creature_id, index = i})
          found = true
          break
        end   
      end
            
      if not found then
        local creature_raw_flags_passed = true
        
        if creature_raw_flags_renamed then
          if creature.flags.EQUIPMENT_WAGON or
             creature.flags.HAS_ANY_MEGABEAST or
             creature.flags.HAS_ANY_SEMIMEGABEAST or
             creature.flags.GENERATED or  --  When is this flag set?
             creature.flags.HAS_ANY_TITAN or
             creature.flags.HAS_ANY_UNIQUE_DEMON or
             creature.flags.HAS_ANY_DEMON or
             creature.flags.HAS_ANY_NIGHT_CREATURE or
             (creature.flags.GOOD and not Profile.GOOD) or
             (creature.flags.EVIL and not Profile.EVIL) or
             (creature.flags.SAVAGE and Profile.SAVAGE == 0) then
            creature_raw_flags_passed = false
          end
          
        elseif creature.flags.EQUIPMENT_WAGON or
               creature.flags.CASTE_MEGABEAST or
               creature.flags.CASTE_SEMIMEGABEAST or
               creature.flags.GENERATED or  --  When is this flag set?
               creature.flags.CASTE_TITAN or
               creature.flags.CASTE_UNIQUE_DEMON or
               creature.flags.CASTE_DEMON or
               creature.flags.CASTE_NIGHT_CREATURE_ANY or
               (creature.flags.GOOD and not Profile.GOOD) or
               (creature.flags.EVIL and not Profile.EVIL) or
               (creature.flags.SAVAGE and Profile.SAVAGE == 0) then
              creature_raw_flags_passed = false
        end
        
        if creature_raw_flags_passed and
           creature.underground_layer_min <= layer_index and
           creature.underground_layer_max >= layer_index and
           ((creature.flags.BIOME_SUBTERRANEAN_WATER and Profile.BIOME_SUBTERRANEAN_WATER > 0) or
            (creature.flags.BIOME_SUBTERRANEAN_CHASM and Profile.BIOME_SUBTERRANEAN_CHASM > 0) or
            (creature.flags.BIOME_SUBTERRANEAN_LAVA and Profile.BIOME_SUBTERRANEAN_LAVA > 0)) then
          matching = true          
        end
        
        if matching then
          table.insert (Animal_Page.Absent_List [layer_index], {name = creature.creature_id, index = i})
        elseif Unrestricted then
          table.insert (Animal_Page.Absent_List [layer_index], {name = creature.creature_id, index = i})
        end
      end
    end

    for i, plant in ipairs (df.global.world.raws.plants.all) do
      local found = false
      local matching
      
      for k, v in ipairs (df.global.world.world_data.underground_regions [region_index].feature_init.feature.population) do
        if Is_Plant (v.type) and
           v.plant == i then
          table.insert (Plant_Page.Present_List [layer_index], {name = plant.id, index = i})
          found = true
          break
        end   
      end
          
      if not found then        
        if plant.underground_depth_min <= layer_index + 1 and
           plant.underground_depth_max >= layer_index + 1 and
           ((plant.flags.BIOME_SUBTERRANEAN_WATER and Profile.BIOME_SUBTERRANEAN_WATER > 0) or
            (plant.flags.BIOME_SUBTERRANEAN_CHASM and Profile.BIOME_SUBTERRANEAN_CHASM > 0) or
            (plant.flags.BIOME_SUBTERRANEAN_LAVA and Profile.BIOME_SUBTERRANEAN_LAVA > 0)) then
          matching = true          
        end
        
        if matching then
          table.insert (Plant_Page.Absent_List [layer_index], {name = plant.id, index = i})
          
        elseif Unrestricted then
          table.insert (Plant_Page.Absent_List [layer_index], {name = plant.id, index = i})
        end
      end
    end
    
    Sort (Animal_Page.Present_List [layer_index])
    Sort (Animal_Page.Absent_List [layer_index])
    Sort (Plant_Page.Present_List [layer_index])
    Sort (Plant_Page.Absent_List [layer_index])
    
    return Profile
  end
  
  --============================================================

  function Apply_Animal_Selection (index, choice)
    if not Animal_Page.Present then
      return  --  Startup, so it doesn't exist properly yet
    end
    
    local animal_visible = true

     if not Animal_Page.Present.active or
       choice == NIL or
       #Animal_Page.Present_List [Layer] == 0 then
      animal_visible = false
      
    else
      local region_index = Locate_Animal (Animal_Page.Present_List [Layer] [index].index, Layer)
      local element
      
      if Layer == Surface then
        element = df.global.world.world_data.regions [region [Layer]].population [region_index]
      else
        element = df.global.world.world_data.underground_regions [region [Layer]].feature_init.feature.population [region_index]
      end
        
      Animal_Page.Type:setText (df.world_population_type [element.type])
      Animal_Page.Race:setText (choice.text)
      Animal_Page.Min_Count:setText (Fit_Right (tostring (element.count_min), 8))
      Animal_Page.Max_Count:setText (Fit_Right (tostring (element.count_max), 8))
    end
    
    for i, element in ipairs (Animal_Page.Animal_Visible_List) do
      element.visible = animal_visible
    end
  end
        
  --============================================================

  function Apply_Plant_Selection (index, choice)
    if not Plant_Page.Present then
      return  --  Startup, so it doesn't exist properly yet
    end
    
    local plant_visible = true

     if not Plant_Page.Present.active or
       choice == NIL or
       #Plant_Page.Present_List [Layer] == 0 then
      plant_visible = false
      
    else
      local region_index = Locate_Plant (Plant_Page.Present_List [Layer] [index].index, Layer)
      local element

      if Layer == Surface then
           element = df.global.world.world_data.regions [region [Layer]].population [region_index]
      else
        element = df.global.world.world_data.underground_regions [region [Layer]].feature_init.feature.population [region_index]
      end
        
      Plant_Page.Type:setText (df.world_population_type [element.type])
      Plant_Page.Plant:setText (choice.text)
    end
    
    for i, element in ipairs (Plant_Page.Plant_Visible_List) do
      element.visible = plant_visible
    end
    
    
    if not Plant_Page.Present then
      return  --  Startup, so it doesn't exist properly yet
    end
  end
        
  --============================================================

  function Layer_Image (Layer, Type, Start, Stop)
    return Fit (Layer, Max_Geo_Layer_Name_Length + 1) .. 
           Fit (Type, Max_Geo_Type_Name_Length + 1) .. 
           Fit_Right (tostring (Start), 5) .. 
           Fit_Right (tostring (Stop), 5)
  end
  
  --===========================================================================

  function Nested_In_Image (Layer, Nested_In)
    if Nested_In == -1 then
      return string.rep (' ', Max_Geo_Vein_Name_Length + 1)
      
    else
      return Fit (df.global.world.raws.inorganics [Layer.vein_mat [Nested_In]].id, Max_Geo_Vein_Name_Length + 1)
    end
  end
  
  --===========================================================================

  function Vein_Image (Layer, index)
    return Fit (df.global.world.raws.inorganics [Layer.vein_mat [index]].id, Max_Geo_Vein_Name_Length + 1) ..
           Fit_Right (tostring (Layer.vein_unk_38 [index]), 5) .. " " .. 
           Fit (df.inclusion_type [Layer.vein_type [index]], Max_Geo_Cluster_Name_Length + 1) ..
           Nested_In_Image (Layer, Layer.vein_nested_in [index])
  end
  
  --===========================================================================

  function Make_Geo_Layer (index)
    local geo_biome = df.global.world.world_data.geo_biomes [index]
      
    Geo_Page.Layer_List = {}
    
    for i, layer in ipairs (geo_biome.layers) do
      table.insert (Geo_Page.Layer_List, {name = Layer_Image (df.global.world.raws.inorganics [layer.mat_index].id,
                                                              df.geo_layer_type [layer.type],
                                                              layer.top_height,
                                                              layer.bottom_height),
                                          index = layer.mat_index})
    end
    
    Geo_Page.Vein_List = {}
    
    for i, vein in ipairs (geo_biome.layers [0].vein_mat) do
      table.insert (Geo_Page.Vein_List, {name = Vein_Image (geo_biome.layers [0], i),
                                         index = vein_mat [i]})
    end
  end
  
  --============================================================

  function Make_Layer (x, y)
    Make_Geo_Layer (df.global.world.world_data.region_map [x]:_displace (y).geo_index)    
  end
  
  --============================================================

  function Make_List (List)
    local Result = {}
    
    for i, element in ipairs (List) do
      table.insert (Result, element.name)
    end
    
    return Result
  end
  
  --============================================================

  function Update (delta_x, delta_y, full)
    local old_x = x
    local old_y = y
    local old_region = {}
    local movement
    
    for i = -1, 3 do
      old_region [i] = region [i]
    end
    
    x = x + delta_x
    if x < 0 then
      x = 0
    elseif x >= map_width then
      x = map_width - 1
    end

    y = y + delta_y
    if y < 0 then
      y = 0
    elseif y >= map_height then
      y = map_height - 1
    end
    
    movement = x ~= old_x or y ~= old_y
    
    evilness = df.global.world.world_data.region_map [x]:_displace (y).evilness
    savagery = df.global.world.world_data.region_map [x]:_displace (y).savagery

    if movement or full then
      region [Surface] = df.global.world.world_data.region_map [x]:_displace (y).region_id
      size [Surface] = #df.global.world.world_data.regions [region [Surface]].region_coords.x

      for i, underground_region in ipairs (df.global.world.world_data.underground_regions) do
        if underground_region.layer_depth <= 3 then
          for k, x_coord in ipairs (underground_region.region_coords.x) do
            if x == x_coord and y == underground_region.region_coords.y [k] then
              region [underground_region.layer_depth] = i
              size [underground_region.layer_depth] = #underground_region.region_coords.x
              break
            end
          end
        end
      end
    end
    
    if not movement or old_region [Surface] ~= region [Surface] or full then
      animals [Surface] = 0
      plants [Surface] = 0
      for i, population in ipairs (df.global.world.world_data.regions [region [Surface]].population) do
        if Is_Animal (population.type) then
          animals [Surface] = animals [Surface] + 1
     
        elseif Is_Plant (population.type) then
          plants [Surface] = plants [Surface] + 1
        end
      end  
    end
    
    for i = 0, 3 do
      if region [i] and (not movement or old_region [i] ~= region [i] or full) then
        animals [i] = 0
        plants [i] = 0
        
        for k, population in ipairs (df.global.world.world_data.underground_regions [region [i]].feature_init.feature.population) do
          if Is_Animal (population.type) then
            animals [i] = animals [i] + 1
          elseif Is_Plant (population.type) then
            plants [i] = plants [i] + 1
          end
        end
      end
    end
  
    if full or not movement or old_region [Surface] ~= region [Surface] then
        Main_Page.Profile = Make_Profile (region [Surface])
    end
        
    for i = 0, 3 do
      if region [i] and (full or not movement or old_region [i] ~= region [i]) then
        Make_Subterranean_Profile (region [i], i)
      end
    end
    
    if full then
      Make_Region ()
      Make_Biome ()
      Make_Underground (x, y)
      Make_Geo (x, y)
      
    else
      if movement then
        Update_Region_Tile (old_x, old_y)
        Update_Biome_Tile (old_x, old_y)
        Flip_Underground_Tile (old_x, old_y)
        Flip_Geo_Tile (old_x, old_y)
        Flip_Underground_Tile (x, y)
        Flip_Geo_Tile (x, y)                
      end
      
      Update_Region_Tile (x, y)
      Update_Biome_Tile (x, y)
    end
        
    Main_Page.Cavern.visible = (Layer >= 0 and Layer <= 2)

    Main_Page.X:setText (Fit_Right (tostring (x), 3))        
    Map_Page.X:setText (Fit_Right (tostring (x), 3))        
    Main_Page.Y:setText (Fit_Right (tostring (y), 3))                                      
    Map_Page.Y:setText (Fit_Right (tostring (y), 3))                                      
    Main_Page.Biome:setText (Fit_Right (tostring (region [Layer]), 4))
    Map_Page.Biome:setText (Fit_Right (tostring (region [Surface]), 4))
    Main_Page.Size:setText (Fit_Right (tostring (size [Layer]), 6))
    Map_Page.Size:setText (Fit_Right (tostring (size [Surface]), 6))
    Main_Page.Weather.visible = Layer == Surface
    
    if Layer == Surface then
      Main_Page.Type:setText (df.world_region_type [df.global.world.world_data.regions [region [Layer]].type])
      
    elseif Layer >= 0 and
           Layer <= 2 then
      local underground_water
      
      if underground_region_type_updated then
        underground_water = df.global.world.world_data.underground_regions [region [Layer]].water
        
      else
        underground_water = df.global.world.world_data.underground_regions [region [Layer]].unk_7a
      end
      
      if underground_water < 10 then
         Main_Page.Type:setText ("Subterranean Chasm")
      else
         Main_Page.Type:setText ("Subterranean Water")
      end
    else
         Main_Page.Type:setText ("Subterranean Lava")
    end
    
    Map_Page.Type:setText (df.world_region_type [df.global.world.world_data.regions [region [Surface]].type])
    Map_Page.Biome_Name:setText (df.biome_type [get_biome_type
      (y,
       df.global.world.worldgen.worldgen_parms.dim_y,
       df.global.world.world_data.region_map [x]:_displace (y).temperature,
       df.global.world.world_data.region_map [x]:_displace (y).elevation,
       df.global.world.world_data.region_map [x]:_displace (y).drainage,
       df.global.world.world_data.region_map [x]:_displace (y).rainfall,
       df.global.world.world_data.region_map [x]:_displace (y).salinity,
       df.global.world.world_data.region_map [x]:_displace (y).rainfall,  --  Proxy for vegetation as that doesn't seem to be set before finalization
       df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake)])

    Main_Page.Evilness:setText (Fit_Right (tostring (evilness), 3))
    Main_Page.Evilness.text_pen = Savagery_Pen (evilness)
    Map_Page.Evilness:setText (Fit_Right (tostring (evilness), 3))
    Map_Page.Evilness.text_pen = Savagery_Pen (evilness)
      
    Main_Page.Animals:setText (Fit_Right (tostring (animals [Layer]), 3))
    Main_Page.Plants:setText (Fit_Right (tostring (plants [Layer]), 3))

    Main_Page.Evilness_Single:setText (Fit_Right (tostring (evilness), 3))
    Main_Page.Evilness_Single.text_pen = Biome_Color (savagery, evilness)
      
    Main_Page.Savagery:setText (Fit_Right (tostring (savagery), 3))
    Main_Page.Savagery.text_pen = Biome_Color (savagery, evilness)
    Map_Page.Savagery:setText (Fit_Right (tostring (savagery), 3))
    Map_Page.Savagery.text_pen = Biome_Color (savagery, evilness)
      
    Map_Page.Elevation:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).elevation), 4))
    Map_Page.Rainfall:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).rainfall), 3))
    Map_Page.Vegetation:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).vegetation), 3))
    Map_Page.Temperature:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).temperature), 5))
    Map_Page.Drainage:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).drainage), 3))
    Map_Page.Volcanism:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).volcanism), 3))
    Map_Page.Salinity:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).salinity), 3))
    
    Main_Page.Layer:setText (layer_image [Layer])
    
    if movement then
      Main_Page.Region_Grid:panCenter (x, y)
      Main_Page.Biome_Grid:panCenter (x, y)
      for i = 0, 3 do
        Main_Page.Underground_Grid [i]:panCenter (x, y)
      end
      Main_Page.Geo_Grid:panCenter (x, y)
      Map_Page.Biome_Grid:panCenter (x, y)
      River_Page.River_Grid:panCenter (x, y)
    end
    
    if Layer == Surface and
       (full or
        not movement or 
        old_region [Surface] ~= region [Surface]) then
      Animal_Page.Present:setChoices (Make_List (Animal_Page.Present_List [Layer]), 1)
      Animal_Page.Absent:setChoices (Make_List (Animal_Page.Absent_List [Layer]), 1)
      Plant_Page.Present:setChoices (Make_List (Plant_Page.Present_List [Layer]), 1)
      Plant_Page.Absent:setChoices (Make_List (Plant_Page.Absent_List [Layer]), 1)
    end
    
    if Layer ~= Surface and
       (full or not movement or old_region [Layer] ~= region [Layer]) then
      Animal_Page.Present:setChoices (Make_List (Animal_Page.Present_List [Layer]), 1)
      Animal_Page.Absent:setChoices (Make_List (Animal_Page.Absent_List [Layer]), 1)
      Plant_Page.Present:setChoices (Make_List (Plant_Page.Present_List [Layer]), 1)
      Plant_Page.Absent:setChoices (Make_List (Plant_Page.Absent_List [Layer]), 1)
    end
    
    Apply_Animal_Selection ()        
    Apply_Plant_Selection ()
    
    Weather_Page.Interaction_Index = -1  --  None
        
    for i, interaction in ipairs (df.global.world.interaction_instances.all) do
      if interaction.region_index == region [Surface] then
        Weather_Page.Interaction_Index = interaction.interaction_id
        break
      end
    end
    
    if full or movement then
      if river_matrix [x] [y].path == -1 or
         river_matrix [x] [y].path == current_river or
         (current_river ~= -1 and 
          #df.global.world.world_data.rivers [current_river].path.x == 0) then
        River_Page.Select_River.text_pen = COLOR_DARKGREY
          
      else
        River_Page.Select_River.text_pen = COLOR_LIGHTBLUE
      end
          
      if current_river ~= -1 then
        River_Page.Clear_Course.text_pen = COLOR_LIGHTBLUE
            
      else
        River_Page.Clear_Course.text_pen = COLOR_DARKGREY
      end
          
      if river_matrix [x] [y].path ~= -1 and
         river_matrix [x] [y].path == current_river then
        River_Page.Truncate_Course.text_pen = COLOR_LIGHTBLUE
        
      else
        River_Page.Truncate_Course.text_pen = COLOR_DARKGREY
      end
        
      if river_matrix [x] [y].path == -1 and
         current_river ~= -1 and
         legal_river_extension (x, y, current_river) then
        River_Page.Add_Course.text_pen = COLOR_LIGHTBLUE
          
      else
        River_Page.Add_Course.text_pen = COLOR_DARKGREY
      end
        
      if current_river ~= -1 and
         legal_river_extension (x, y, current_river) then
        River_Page.Set_Sink.text_pen = COLOR_LIGHTBLUE
          
      else
        River_Page.Set_Sink.text_pen = COLOR_DARKGREY
      end
        
      if current_river ~= -1 and
         Has_Legal_River_Sink_Direction (x, y, current_river) then
        River_Page.Set_Sink_Direction.text_pen = COLOR_LIGHTBLUE
          
      else
        River_Page.Set_Sink_Direction.text_pen = COLOR_DARKGREY     
      end
        
      if current_river ~= -1 then
        River_Page.Delete_River.text_pen = COLOR_LIGHTBLUE
          
      else
        River_Page.Delete_River.text_pen = COLOR_DARKGREY
      end
        
      if river_matrix [x] [y].path == -1 then
        River_Page.New_River.text_pen = COLOR_LIGHTBLUE

      else
        River_Page.New_River.text_pen = COLOR_DARKGREY
      end          
          
      if lost_rivers_present and current_river == -1 then
        River_Page.Wipe_Lost.text_pen = COLOR_LIGHTBLUE
        
      else
        River_Page.Wipe_Lost.text_pen = COLOR_DARKGREY
      end
      
      if river_matrix [x] [y].path == -1 then
        River_Page.Brook.text_pen = COLOR_DARKGREY
        River_Page.Brook_Edit:setText ("")
        River_Page.Flow.text_pen = COLOR_DARKGREY
        River_Page.Flow_Edit:setText ("")
        River_Page.Exit_Tile.text_pen = COLOR_DARKGREY
        River_Page.Exit_Tile_Edit:setText ("")
        River_Page.Elevation.text_pen = COLOR_DARKGREY
        River_Page.Elevation_Edit:setText ("")
          
      else
        local index
        for i, x_pos in ipairs (df.global.world.world_data.rivers [river_matrix [x] [y].path].path.x) do
          if x_pos == x and 
             df.global.world.world_data.rivers [river_matrix [x] [y].path].path.y [i] == y then
            index = i
            break
           end
        end
        
        River_Page.Brook.text_pen = COLOR_LIGHTBLUE
        if df.global.world.world_data.region_map [x]:_displace (y).flags.is_brook then
          River_Page.Brook_Edit:setText ('Y')
        else
          River_Page.Brook_Edit:setText ('N')
        end
        
        River_Page.Flow.text_pen = COLOR_LIGHTBLUE        
        if not river_type_updated then
          River_Page.Flow_Edit:setText (Fit_Right (tostring (df.global.world.world_data.rivers [river_matrix [x] [y].path].unk_8c [index]), 5))
          River_Page.Exit_Tile_Edit:setText (Fit_Right (tostring (df.global.world.world_data.rivers [river_matrix [x] [y].path].unk_9c [index]), 2))
        else
          River_Page.Flow_Edit:setText (Fit_Right (tostring (df.global.world.world_data.rivers [river_matrix [x] [y].path].flow [index]), 5))
          River_Page.Exit_Tile_Edit:setText (Fit_Right (tostring (df.global.world.world_data.rivers [river_matrix [x] [y].path].exit_tile [index]), 2))
        end
        
        River_Page.Exit_Tile.text_pen = COLOR_LIGHTBLUE
        River_Page.Elevation.text_pen = COLOR_LIGHTBLUE
        River_Page.Elevation_Edit:setText (Fit_Right (tostring (df.global.world.world_data.rivers [river_matrix [x] [y].path].elevation [index]), 4))
      end
    end
  end
  
  --============================================================

  function Screen_Resized (w, h)
    if Main_Page.Biome_Grid ~= NIL then
      for i, grid in ipairs (Grids) do
        grid:screenResized (w, h, false, false, x, y)
      end
    end
  end
  
  --============================================================

  BiomeManipulatorUi = defclass (BiomeManipulatorUi, gui.FramedScreen)
  BiomeManipulatorUi.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Biome Manipulator",
    Resize_Callback = (function (w, h) Screen_Resized (w, h) end),
    transparent = false
  }

  --============================================================
 
  function BiomeManipulatorUi:onRenderFrame (dc, rect)
    local x1, y1, x2, y2 = rect.x1, rect.y1, rect.x2, rect.y2

    if self.transparent then
  
    else
      if rect.wgap <= 0 and rect.hgap <= 0 then
        dc:clear ()
      else
        self:renderParent ()
        dc:fill (rect, self.frame_background)
      end

      gui.paint_frame (x1, y1, x2, y2, self.frame_style, self.frame_title)
    end
  end
  
  --============================================================

  function BiomeManipulatorUi:onResize (w, h)
    self:updateLayout (gui.ViewRect {rect = gui.mkdims_wh (0, 0 , w, h)})
    if self.Resize_Callback then
      self.Resize_Callback (w, h)
    end
  end
  
  --============================================================

  function BiomeManipulatorUi:onHelp ()
    self.subviews.pages:setSelected (9)
    Focus = "Help"
  end

  --============================================================

  function Helptext_Main ()
    local helptext =
      {"Help/Info Main Page",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       {text = " to switch between help screens.",
        pen = COLOR_LIGHTBLUE},
       {text = "",
        key = keybindings.print_help.key,
        key_sep = '()'},
       {text = " to print this to the DFHack console.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       "The Biome Mainpulator is used during world gen or pre embark to manipulate various biome related aspects of", NEWLINE,
       "the world. This screen provides general tool information, while more detailed information is provided on the", NEWLINE,
       "corresponding help screen (see the top of this page).", NEWLINE,
       "The things the Biome Manipulator can modify are:", NEWLINE,
       "- Surface and Underground Biome Plant Populations", NEWLINE,
       "- Surface and Underground Biome Animal Populations", NEWLINE,
       "- Evilness of Surface Biomes", NEWLINE,
       "- Evilness of individual World Tiles", NEWLINE,
       "- Limited Cavern properties", NEWLINE,
       "- Limited Evil Weather display and region assignment", NEWLINE,
       "- Geo Biome manipulation and World Tile assignment", NEWLINE,
       "- World Map world tile region reassignment and new regions", NEWLINE, NEWLINE,
       "The Biome Manipulator main page provides a map display that can be cycled with ",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
       " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       " (same as", NEWLINE,
       "above: the principle is used to shift focus throughout the tool) to display information about the World", NEWLINE, 
       "Tiles. The available views are: Surface Biome/Region Number/Cavern 1/2/3/Magma Sea Underground Region", NEWLINE,
       "Number/Geo Biome Number. The current view is displayed in the Map Display field.", NEWLINE,
       "The Surface Biome encoding is described below, while the others just uses Number modulo 15 for color and", NEWLINE,
       "math.floor (Number / 15) for the letter. This is useful only as a means to see boundaries. The map can be", NEWLINE, 
       "traversed with the normal DF movement keys.", NEWLINE,
       "The section above the map contains information and command keys.", NEWLINE,
       "The X and Y fields show the currently selected World Tile coordinates, Biome shows the Biome Region number", NEWLINE,
       "of this tile, while Size and Type shows the number of World Tiles belonging to the region and the region's", NEWLINE,
       "broad type, respectively. Evilness shows that value for the current Region, while the command key", NEWLINE,
       "beside it allows you to change it (removing any evil weather associated with it).", NEWLINE,
       "The Animals and Plants fields show the number of each available to the region, and the command keys bring", NEWLINE,
       "you to pages allowing you to modify the corresponding contents. The Current World Tile Evilness and", NEWLINE, 
       "Savagery fiels show the corresponding values while the command keys allow you to modify the values for the", NEWLINE, 
       "current tile (in the case of Evilness this can break DF's connection between Biome Region and Evilness).", NEWLINE,
       "The Unrestricted field shows whether animal and plant selections (when manipulated) will adhere to DF's", NEWLINE,
       "restrictions regarding Evilness, Savagery, and Biome, while the command key allows you to toggle this.", NEWLINE, 
       "The Flora and Fauna diversity keys allow you to add all legal plants/animals to ALL Biome Regions of", NEWLINE,
       "the current Layer (explained below), but these keys are NOT affected by the Unrestricted setting.", NEWLINE,
       "The Weather Manipulation command key brings you to an Evil Weather manipulation page, while the Geo", NEWLINE, 
       "Manipulation one brings you to the Geo Manipulation page. The Command Layer display shows which layer", NEWLINE, 
       "(Surface, Cavern 1/2/3, Magma Sea) the flora/fauna diversity and animal/plant manipulations affect.", NEWLINE,
       "Changing the Layer to an Underground one will cause the Cavern Param Edit field to be displayed to show", NEWLINE,
       "the command key to edit some cavern parameters for the cavern belonging to the current Layer and World", NEWLINE,
       "Tile. This will also suppress the display (and availability) of the Weather and Geo Manipulation keys", NEWLINE,
       "The World Map key brings you to the World Map page. World tiles parameters can be manipulated to yield", NEWLINE,
       "new biomes and world tiles can be shifted to join neighboring regions or generate their own regions.", NEWLINE,
       "The River key brings you to a page that allows you to manipulate rivers.", NEWLINE,
       NEWLINE,
       "The biome map uses a color coding to indicate savagery + evilness and a large number of characters to", NEWLINE,
       "indicate various biome versions. The biomes listed are the ones present in the corresponding DF enumeration,", NEWLINE,
       "(except for Subterranean Chasm and Subterranean Water which aren't visible on the surface, and pools and", NEWLINE,
       "rivers, which are embedded in biomes, rather than forming biomes themselves).", NEWLINE,
       NEWLINE,
       "Color coding key:", NEWLINE,
       {text = "Serene       ", pen = COLOR_BLUE}, {text = "Mirthful     ", pen = COLOR_GREEN}, {text = "Joyous Wilds ", pen = COLOR_LIGHTCYAN}, NEWLINE,
       {text = "Calm         ", pen = COLOR_GREY}, {text = "Wilderness   ", pen = COLOR_LIGHTGREEN}, {text = "Untamed Wilds", pen = COLOR_YELLOW}, NEWLINE,
       {text = "Sinister     ", pen = COLOR_MAGENTA}, {text = "Haunted      ", pen = COLOR_LIGHTRED}, {text = "Terrifying   ", pen = COLOR_RED}, NEWLINE,
       NEWLINE,
       "The environment character symbols use lower case for the temperate version and upper case", NEWLINE,
       "for the tropical one. The one exception is d/D.", NEWLINE,
       "Biome", NEWLINE,
       "a = Arctic Ocean", NEWLINE,
       "                               B = Badlands", NEWLINE,
       "c = Temperate Conifer          C = Tropical Conifer", NEWLINE,
       "d = Dry Tropical Broadleaf     D = Sand Desert", NEWLINE,
       "e = Rocky Desert", NEWLINE,
       "g = Temperate Grassland        G = Tropical Grassland", NEWLINE,
       "l = Temperate Broadleaf        L = Tropical Moist Broadleaf", NEWLINE,
       "                               M = Mangrove Swamp", NEWLINE,
       "n = Temperate Freshwater Marsh N = Tropical Freshwater Marsh", NEWLINE,
       "o = Temperate Ocean            O = Tropical Ocean", NEWLINE,
       "p = Temperate Freshwater Swamp P = Tropical Freshwater Swamp", NEWLINE,
       "r = Temperate Saltwater Swamp  R = Tropical Saltwater Swamp", NEWLINE,
       "s = Temperate Savanna          S = Tropical Savanna", NEWLINE,
       "t = Tundra                     T = Taiga", NEWLINE,
       "u = Temperate Shrubland        U = Tropical Shrubland", NEWLINE,
       "Y = Temperate Saltwater Marsh  Y = Tropical Saltwater Marsh", NEWLINE,
       "+ = Mountain                   * = Glacier", NEWLINE,
--       "                               ~ = Subterranean Lava", NEWLINE,         --  Commented out won't appear.
--       ". = Temperate Freshwater Pool  , = Tropical Freshwater Pool", NEWLINE,
--       ": = Temperate Brackish Pool    ; = Tropical Brackish Pool", NEWLINE,
--       "! = Temperate Saltwater Pool   | = Tropical Saltwater Pool", NEWLINE,
       "< = Temperate Freshwater Lake  > = Tropical Freshwater Lake", NEWLINE,
       "- = Temperate Brackish Lake    = = Tropical Brackish Lake", NEWLINE,
       "[ = Temperate Saltwater Lake   ] = Tropical Saltwater Lake", NEWLINE,
--       "\\ = Temperate Freshwater River / = Tropical Freshwater River", NEWLINE,
--       "% = Temperate Brackish River   & = Tropical Brackish River", NEWLINE,
--       "( = Temperate Saltwater River  ) = Tropical Saltwater River", NEWLINE,
       NEWLINE,       
       "Version 0.40, 2020-03-04", NEWLINE,
       "Caveats: Only tested to a limited degree.", NEWLINE,
       "Making silly changes are likely to lead to either silly results or nothing at all.", NEWLINE,
       "This script makes use of some unnamed DFHack data structure fields and will cease to work when/if those", NEWLINE,
       "fields are named until the script is updated to use the new names.", NEWLINE,
       "Changes to evil weathers themselves do not seem to be saved, and so providing editing of them is rather", NEWLINE,
       "pointless."}
               
   return helptext
 end
  
  --============================================================

  function Helptext_Plant ()
    local helptext =
      {"Help/Info Plant Page",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       {text = " to switch between help screens.",
        pen = COLOR_LIGHTBLUE},
       {text = "",
        key = keybindings.print_help.key,
        key_sep = '()'},
       {text = " to print this to the DFHack console.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       "The Region Biome Plant page allows you to add/remove plants to the current Biome Region (which will be", NEWLINE,
       "the surface or an Underground Region, as per the Layer set on the main page). The left list shows the", NEWLINE,
       "plants currently present in the biome, while the right one shows the absent ones that are legal (or,", NEWLINE,
       "in the case of Unrestricted being set to True, all of them). Note that Savage ones will not show up", NEWLINE,
       "in the Absent list of there are no Savage World Tiles belonging to the region. It can also be noted", NEWLINE,
       "that this page is rather boring for the Magma Sea as no plants are supported there in vanilla DF.", NEWLINE,
       "You navigate the lists using the normal movement keys and between the lists using the same keys as", NEWLINE,
       "on the top of this page, i.e. ",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       ". Plants are removed from from one list and added to", NEWLINE,
       "the other one when you press <ENTER> on the corresponding entry (and this happens even if the", NEWLINE,
       "plant removed is not legal for the biome, allowing you to reverse your selection).", NEWLINE,
       "While a plant in the Present list is selected the top of the screen shows the plant type (Grass/Bush/", NEWLINE,
       "Tree) and a redundant display of the name.", NEWLINE,
       "Comments:", NEWLINE,
       "- DF does not seem to check whether a World Tile is Evil/Good to make corresponding plants available.", NEWLINE,
       "  Presumably the check performed when DF allocates plants to tiles is deemed sufficient.", NEWLINE,
       "  Note that since Savagery is a per World Tile property, that IS checked, so adding Savage plants to", NEWLINE,
       "  a Region Biome and then embarking on a non Savage tile will not make them available.", NEWLINE,
       "- DF doesn't seem to check whether Surface plants are legal in caverns, so if addded to a Cavern", NEWLINE,
       "  they can show up on embark. The author does not know if they can propagate there, but suspect", NEWLINE,
       "  the light/darkness check will block that.", NEWLINE,
       "- Adding underground plants to Underground Chasm biomes ('muddy caverns') will make them available", NEWLINE,
       "  on embark, but it's unknown if Cavern layer restrictions are upheld, i.e. if they'll propagate", NEWLINE,
       "  the author supects they do, however, as per the Evil/Good plant logic that it's checked when the", NEWLINE,
       "  Biome Region is generated.", NEWLINE,
       "- Manipulate plant selection on an established embark requires methods beyond what this tool does.", NEWLINE,
       "  The author has not figured out how to do that beyond adding grasses. Trying to use this tool on", NEWLINE,
       "  an existing embark is probably pointless."
      }  

    return helptext       
  end
  
  --============================================================

  function Helptext_Animal ()
    local helptext =
      {"Help/Info Animal Page",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       {text = " to switch between help screens.",
        pen = COLOR_LIGHTBLUE},
       {text = "",
        key = keybindings.print_help.key,
        key_sep = '()'},
       {text = " to print this to the DFHack console.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       "The Region Biome Animal page allows you to add/remove animals to the current Biome Region (which will be", NEWLINE,
       "the surface or an Underground Region, as per the Layer set on the main page). The left list shows the", NEWLINE,
       "animalss currently present in the biome, while the right one shows the absent ones that are legal (or,", NEWLINE,
       "in the case of Unrestricted being set to True, all of them). Note that Savage ones will not show up", NEWLINE,
       "in the Absent list of there are no Savage World Tiles belonging to the region.", NEWLINE,
       "You navigate the lists using the normal movement keys and between the lists using the same keys as", NEWLINE,
       "on the top of this page, i.e. ",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       ". Animals are removed from from one list and added to", NEWLINE,
       "the other one when you press <ENTER> on the corresponding entry (and this happens even if the", NEWLINE,
       "animal removed is not legal for the biome, allowing you to reverse your selection).", NEWLINE,
       "While an animal in the Present list is selected the top of the screen shows the animal type (Animal/", NEWLINE,
       "ColonyInsect/VerminInnumerable/Vermin) a redundant display of the name, and Max/min counts of this", NEWLINE,
       "animal, together with the command keys to change the numbers.", NEWLINE,
       "Comments:", NEWLINE,
       "- DF uses the Max/Min count of 10000001 to indicate an innumerable animal.", NEWLINE,
       "- It's been reported that toggling Unrestricted and adding megabeasts to Region Biomes allow you to", NEWLINE,
       "  have these creatures visit your fortress as normal animals without either warnings or the extreme", NEWLINE,
       "  hostility levels 'real' megabeasts display."
      }  

    return helptext       
  end
  
  --============================================================

  function Helptext_Weather ()
    local helptext =
      {"Help/Info Evil Weather Page",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       {text = " to switch between help screens.",
        pen = COLOR_LIGHTBLUE},
       {text = "",
        key = keybindings.print_help.key,
        key_sep = '()'},
       {text = " to print this to the DFHack console.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       "The Evil Weather page allows you to display some of the effects of the Evil Weathers DF has generated", NEWLINE,
       "as well as to add/remove/replace an Evil Weather for the current Biome Region.", NEWLINE,
       "The left side if the screen shows a table of all existing Evil Weathers plus NONE. To the right of", NEWLINE,
       "this there is a display of which Evil Weather the current Biome Region has (or NONE if absent), while", NEWLINE,
       "below that a redundant display of the currently selected Evil Weather name is given, followed by a", NEWLINE,
       "section with extracted from DF about the Evil Weather type and effects.", NEWLINE,
       "Pressing <ENTER> on an entry in the Evil Weather list causes that weather to be added to the current", NEWLINE,
       "Biome Region (if no Weather was associated to it previously), replace the current Evil Weather with", NEWLINE,
       "the selected one (if one was associated already), or remove the current Evil Weather (if NONE was", NEWLINE,
       "selected).", NEWLINE,
       "It is also possible to set a Dead Vegetation percentage for the region. While this effect is set only", NEWLINE,
       "for evil regions that have reanimation by DF itself, it can be applied to any region. The effect", NEWLINE,
       "causes some or all vegetation to be dead in the region, controlled by the percentage value. Note that", NEWLINE,
       "this effect is applied to the region directly, and technically isn't part of the evil weather itself.", NEWLINE,
       "Comments:", NEWLINE,
       "- Thralling and reanimating Evil Weather seems to generate the same set of modifications, starting", NEWLINE,
       "  with a flashing symbol. However, Reanimation is just displayed as such without these modifications", NEWLINE,
       "  because these effects are stored elsewhere in the messy structures.", NEWLINE,
       "- There's an element for the frequency of Evil Weather effects. It seems to always have the same value", NEWLINE,
       "  though, so it was removed from display.", NEWLINE,
       "- There are parameters for the type of biomes Evil Weather affect. However, changing those did not", NEWLINE,
       "  cause DF to retain the changes.", NEWLINE
      }  

    return helptext       
  end
  
  --============================================================

  function Helptext_Geo ()
    local helptext =
      {"Help/Info Geo Biome Page",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       {text = " to switch between help screens.",
        pen = COLOR_LIGHTBLUE},
       {text = "",
        key = keybindings.print_help.key,
        key_sep = '()'},
       {text = " to print this to the DFHack console.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       "The Geo Biome page allows you to manipulate the Geo Biome associated with the current World Tile.", NEWLINE,
       "You can change the layer materials, their thickness, and what materials they include.", NEWLINE,
       "All Geo Biome manipulations adhere to relations/restrictions set up in the raws, so you're only", NEWLINE,
       "allowed to add veins of materials that are actually legal as veins in the layer material it is", NEWLINE,
       "to be included in.", NEWLINE,
       "The Geo Biome page shows the number of the Geo Biome, followed by keys to Clone the biome (i.e.", NEWLINE,
       "create a new one with with a new number for further modification. Obviously, this new Geo Biome", NEWLINE,
       "is not associated to any World Tile). The next key allows you to Update the Geo Biome number of", NEWLINE,
       "the current World Tile, i.e. have it refer to a new Geo Biome (e.g. the one just created).", NEWLINE,
       "The Geo Diversity this/all Biome(s) commands allow you to assign every legal mineral to every", NEWLINE,
       "layer of the current/all geo biomes in the world respectively.", NEWLINE,
       "Below this the Layer list is displayed. This list shows all the layers included in the Geo", NEWLINE,
       "Biome associated with the current World Tile (or the clone, if you've just cloned a Geo Biome)", NEWLINE,
       "listing the Layer material, its type, and the top and bottom levels (starting with 0 for the", NEWLINE,
       "surface level). To the right of this list there is a number of command keys for manipulation", NEWLINE,
       "of the Layer list. However, before covering those, we'll just briefly mention that there is", NEWLINE,
       "another list below the Layer one containing the Veins/Clusters/Inclusions in the currently", NEWLINE,
       "selected layer. This list is likely to be empty as you enter the screen, as the top layer", NEWLINE,
       "is probably soil, and is unlikely to contain any other materials.", NEWLINE,
       "Back to the Layer List: DF has generated a depth using some internal logic, and the Biome", NEWLINE,
       "maintains that depth in all manipulations. DF also supports a maximum of 16 layers, so you", NEWLINE,
       "will not be allowed to exceed that number.", NEWLINE,
       "The Delete command removes the current layer, including anything Veins etc. inside it,", NEWLINE,
       "extending the layer below to cover the combined range. You're not allowed to remove the bottom", NEWLINE,
       "layer, as there's nothing below to extend upwards.", NEWLINE,
       "The Split command Splits the current layer into two of 'equal' size, with the bottom one being", NEWLINE,
       "the original and the top one being the copy that's devoid of any Veins etc. You're not allowed", NEWLINE,
       "to Split any Layer of a thickness of less than 2, as there isn't a sufficient number of levels", NEWLINE,
       "to support two Layers.", NEWLINE,
       "The Expand command expands the current Layer downwards, taking one level from the Layer below.", NEWLINE,
       "Again, you can't Expand a Layer if the Layer below doesn't have at least one level to spare.", NEWLINE,
       "Contract is the opposite of Expand and returns a level to the Layer below. It can't be performed", NEWLINE,
       "If the current Layer is shallower than 2 or if it's the bottommost Layer.", NEWLINE,
       "The Morph command brings up a list of all Layer materials, allowing you to change the Layer to a", NEWLINE,
       "new material. All Veins etc. inside the former Layer material are removed.", NEWLINE,
       "As per the general principle in the Biome Manipulator you change to the other List by using the", NEWLINE,
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       " keys. Doing so causes the Layer manipulation keys to be removed from display", NEWLINE, 
       "and the Vein (and Cluster/Inclusion) keys are made available instead.", NEWLINE,
       "The Add key allows you to add a Vein/Cluster into the Layer by bringing up a list of all legal", NEWLINE,
       "Veins/Clusters for that Layer (that are not already included in the list).", NEWLINE,
       "The Remove key removes the currently selected Vein/Cluster/Inclusion and will remove any", NEWLINE,
       "Inclusions nested into it in the case of Veins and Clusters.", NEWLINE,
       "The Nest command brings up a list of all materials legal for being nested inside the currently", NEWLINE,
       "selected material. Again, the list is depleted as Inclusions are added.", NEWLINE,
       "The Proportion command allows you to change the Proportion value associated with each Vein etc.", NEWLINE,
       "This unidentified field seems to control the abundance of the Vein etc. material.", NEWLINE,
       "The Full mineral set allows you to assign all minerals in the available list to the current layer", NEWLINE,
       "and will also add every possible inclusion, while the Clear command will remove all minerals in", NEWLINE,
       "the current layer (which also will remove any inclusions).", NEWLINE,
       "Comments:", NEWLINE,
       "- Adding more materials than there are available space for will cause DF to somehow decide which", NEWLINE,
       "  ones are present. You you only have space for two veins and specify three vein materials, one", NEWLINE,
       "  material will have to do without. With cluster materials, the relative amounts of materials", NEWLINE,
       "  seems to roughly correspond to the Proportion value. It can be noted that over specification", NEWLINE,
       "  materials might be the reason for reports of DF claiming metal(s) to be present while the", NEWLINE,
       "  indicated number wasn't found: the metal bearing material might have been crowded out by", NEWLINE,
       "  other materials. This is just a speculation and not confirmed, however.", NEWLINE,
       "- Geo Biomes do not have the two way references Biome Regions do: A Geo Biome just contains the", NEWLINE,
       "  Geological data, with the World Tiles referencing the approproate Geo Biome, while each Biome", NEWLINE,
       "  Region contain a list of every World Tile it contains, with each World Tile referring to its", NEWLINE,
       "  Biome Region. This makes it a lot easier to shuffle World Tile Geo Regions than Biome Regions.", NEWLINE,
       "- There's a geological type called 'Alluvial' that is the only one in which some gems are found", NEWLINE,
       "  However, since the author has found not information on how to determine if a layer is", NEWLINE,
       "  Alluvial or not, these gems can not be added by this tool (but they can be removed...).", NEWLINE,
       "- Similar to Alluvial environents, Pelargic ones are not detected either.", NEWLINE,
       "- DF has a logic for determining maximum soil depth at an embark math.floor (154 - Elevation) / 5", NEWLINE,
       "  with a minimum of 1 (except on mountains) where Elevation is the DF ingame one, not the world", NEWLINE,
       "  gen one. Soil levels are shorn away from the top if the depth exceeds the elevation maximum", NEWLINE,
       "  (with some wrinkes), so what you specify might not be exactly what you get if you embark", NEWLINE,
       "  elevation is too high. There's also a DF bug resulting in bogus aquifer pre embark reports", NEWLINE,
       "  due to DF not taking its own shearing into account when producing the report.", NEWLINE,
       "- The author has not tested  the effects of the various geo diversity commands on any embark."
      }  

    return helptext       
  end
  
  --============================================================

  function Helptext_Cavern ()
    local helptext =
      {"Help/Info Cavern Page",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       {text = " to switch between help screens.",
        pen = COLOR_LIGHTBLUE},
       {text = "",
        key = keybindings.print_help.key,
        key_sep = '()'},
       {text = " to print this to the DFHack console.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       "The Cavern page allows you to display and modify a small number of Cavern parameters.", NEWLINE,
       "The Cavern page shows the Underground Region number as well as the Underground Layer at the top of", NEWLINE,
       "page, followed by the supported parameters and their commands.", NEWLINE,
       "All of these parameters have a range of 0 - 100 and are included as Advanced World Gen parameters.", NEWLINE,
       "The Water parameter controls the amount of water in the cavern. A value of less than 10 results in", NEWLINE,
       "a 'muddy' cavern and an Underground Biome of Underground_Chasm (the other is called", NEWLINE,
       "Underground_Water) completely devoid of plants.", NEWLINE,
       "Note that the tool does NOT update the Underground Biome to contain appropriate plants: the user", NEWLINE,
       "will have to do that manually, if desired.", NEWLINE,
       "This parameter influences the amount of water in the caverns, although the RNG controls the exact ", NEWLINE,
       "amount, and even at a value of 100 some mid level tiles will remain completely free of water. It", NEWLINE,
       "can also be noted that a value of 9 (resulting in a muddy cavern) can still cause a lake to be", NEWLINE,
       "present. It can also be noted that values over 90 also causes caverns to become mud covered, but", NEWLINE,
       "then accompanined with a lot of water.", NEWLINE,
       "The Openness Min/Max control how open the cavern layout will be, as well as whether the cavern can", NEWLINE,
       "be split into more than a single cavern segment without connection", NEWLINE,
       "The Passage Density Min/Max controls how broad/narrow passages will be, with narrow passages", NEWLINE,
       "running the risk of getting blocked by the maturation of a single cavern tree.", NEWLINE,
       "Comments:", NEWLINE,
       "- It can be noted that the parameters have not yet been named by DF and will cause the tool to", NEWLINE,
       "  fail when they are, resulting in a need to update it when that happens.", NEWLINE,
       "- Note that these parameters influence region details data which are generated as the region is", NEWLINE,
       "  brought into focus, so if you want them to influence an embark properly you have to ensure the", NEWLINE,
       "  focus is changed from the embark world tile and then back after having changed the parameters if.", NEWLINE,
       "  the focus was on that world tile when the parameters were changed."
      }  

    return helptext       
  end
  
  --============================================================

  function Helptext_World_Map ()
    local helptext =
      {"Help/Info World Map Page",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       {text = " to switch between help screens.",
        pen = COLOR_LIGHTBLUE},
       {text = "",
        key = keybindings.print_help.key,
        key_sep = '()'},
       {text = " to print this to the DFHack console.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       "The World Map page displays the same Biome map that's available at the main page, and provides", NEWLINE,
       "means to manipulate World Tile parameters individually and collectively in the form of biomes.", NEWLINE,
       "Some of these parameters can also be modified from the main page (as this page is a later", NEWLINE,
       "addition to the script). The main feature is the abilities shift region boundaries and to", NEWLINE,
       "create new Regions.", NEWLINE,
       "The Adopt Region command allows you to change a world tile to belong to a neighboring region", NEWLINE,
       "instead of the current one, while at the same time adopting the world tile parameters of the", NEWLINE,
       "adopted tile, thus taking on its biome (possibly with a different tropicality).", NEWLINE,
       "We'll defer a description of the new Region command, as it's easier to describe when other", NEWLINE,
       "functionality has been explained.", NEWLINE,
       "The next set of 9 commands allows you to change the corresponding world tile parameter to a", NEWLINE,
       "specified value. The Evilness level is the same throughout a Region in vanilla DF, so changing", NEWLINE,
       "it to a different range departs from normal behavior. It's also worth noting that changes to", NEWLINE,
       "Evilness or Savagery levels, as well as Biome changes resulting from parameter changes will not", NEWLINE,
       "add compatible plants/animals to the Region. That will have to be done manually from the", NEWLINE,
       "appropriate pages. It's doubtful changing Volcanism has any effect on DF, as it affects", NEWLINE,
       "the placement of volcanoes, magma pools, and the generation of geo biomes, but probably isn't", NEWLINE,
       "used after that. It should also be noted that Vegetation doesn't seem to be set during world", NEWLINE,
       "generation, but seems to always match Rainfall later on, so it's recommended to try to keep", NEWLINE,
       "Those parameters at the same value.", NEWLINE,
       "The Biome command allows you to set the biome of the world tile to one that's legal for the", NEWLINE,
       "tile's latitude. Parameters that are in the biome's range are left unchanged, while parameters", NEWLINE,
       "that are outside are set to default values close to the middle of the range. Changing the biome", NEWLINE,
       "to one not among those DF allows within that type of region is not recommended unless it's a", NEWLINE,
       "precursor to creating a new region, as it's unknown how DF deals with inconsistent regions.", NEWLINE,
       "Back to the New Region command: It creates a new region from the current world tile, and the", NEWLINE,
       "region's type is based on the biome of the tile. The evilness and savagery is also used to set", NEWLINE,
       "some obscure 'tree' fields on the new region. If you create a Lake the region's lake surface", NEWLINE,
       "elevation is taken from the source world tile's elevation (which is defaulted to 95 if you", NEWLINE,
       "used the Biome command to create the lake).", NEWLINE,
       "Comments:", NEWLINE,
       "- The functionality provided here is tested even less than the rest.", NEWLINE,
       "- A new region is given a randomly generated name of the 'The X of Y' syntax with an X part", NEWLINE,
       "  taken from a list of region type appropriate names within DF and the Y part being a random", NEWLINE,
       "  selection of any VerbGerund within DF. The Mountain X list is somewhat odd, though.", NEWLINE,
       "- Changing elevations/biomes can cause rivers to become inconsistent, such as flowing uphill", NEWLINE,
       "  or crossing oceans and lakes. It's unknown to what extend that messes up gameplay.", NEWLINE,
       "- The main intended usage of the functionality on this page is to adjust the world map", NEWLINE,
       "  during world gen, prior to the placement of civs. Later Biome/Region change may or may", NEWLINE,
       "  not have suitable effects of the world (Manual replacement of a blocking ocean tile during", NEWLINE,
       "  history gen did not seem to cause civs on either side to cross the new land bridge, for", NEWLINE,
       "  instance)."
      }  

    return helptext       
  end
  
  --============================================================

  function Helptext_River ()
    local helptext =
      {"Help/Info River Page",
       {text = "",
        key = keybindings.next_edit.key,
        key_sep = '()'},
        " /",
       {text = "",
        key = keybindings.prev_edit.key,
        key_sep = '()'},
       {text = " to switch between help screens.",
        pen = COLOR_LIGHTBLUE},
       {text = "",
        key = keybindings.print_help.key,
        key_sep = '()'},
       {text = " to print this to the DFHack console.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       "The River page displays a Biome map with the normal letters, but with the color scheme replaced", NEWLINE,
       "with one indicating river related information. The Biome letters have no real bearing on the", NEWLINE,
       "functionality, but are there for orientation purposes.", NEWLINE,
       "DF rivers consists of a river course through a number of world tiles, plus a sink connected to", NEWLINE,
       "the last tile of the course. The tiles in the river's course are connected either horizontally", NEWLINE,
       "or vertically: there are no diagonal connections. Each tile of a river's course has the same", NEWLINE,
       "set of attributes: Flow, Exit Tile, and Elevation. Flow is presumably the amount of water the", NEWLINE,
       "river carries which affects the width of the river according to the formula width =", NEWLINE,
       "(flow / 40000 * 46) + 1, with a minimum of 4 and a maximum of 47. The Exit Tile is the mid", NEWLINE,
       "level tile along the edge through which the river exits the world tile (0 - 15), with the", NEWLINE,
       "edge determined by the next tile of the river's course (or the sink). Elevation is the", NEWLINE,
       "elevation of the river, which tends to create a valley on the region level of lower than that", NEWLINE,
       "of the world tile. In addition to the river parameters, there are a number of world tile flags,", NEWLINE,
       "with most managed by the script, but the 'is_brook' flag is exported for user control.", NEWLINE,
       "The 'sink' of a river is the tile where the river ends, either by emptying into an ocean, lake,", NEWLINE,
       "or another river, or through dissipation in a branching pattern (the same as for the river", NEWLINE,
       "head). DF allows for at most one river to exist in a world tile. Rivers can join because sinks", NEWLINE,
       "are not considered parts of their rivers. Thus, a world tile can contain 0-1 rivers and 0-4", NEWLINE,
       "(0-3 if there's also a river present).", NEWLINE,
       "The river page allows you to modify river attributes (Flow, Exit Tile, and Elevation), plus", NEWLINE,
       "'is_brook'. In addition to this, rivers can be deleted, modified, and created. An existing", NEWLINE,
       "can be selected and then manipulated by clearing it, truncating it's course (i.e", NEWLINE,
       "delete the course from the current tile to the end), add a tile to the end (in one of three", NEWLINE,
       "available directions from the previous end, or anywhere if the course is empty). The sink", NEWLINE,
       "remains where it was until overwritten by a course tile or explicitly assigned by one of the", NEWLINE,
       "sink assignment keys. The Sink Direction key is needed when the sink is off the map (i.e. the", NEWLINE,
       "river should run off the edge of the map), but can be used elsewhere as well. When the sink is", NEWLINE,
       "adjacent to the river's end the script connects it automatically, but when it is not the river", NEWLINE,
       "is inconsistent and should be fixed before the world is finalized/the player embarks (depending", NEWLINE,
       "on when this script is used). A sink overwritten by the course is moved to the 'impossible'", NEWLINE,
       "location (-1, -1) pending the user's allocation of a new sink location.", NEWLINE,
       "The following color scheme is used on the River 'map':", NEWLINE, NEWLINE,
       {text = "White: Neither river nor any sink present.",
        pen = COLOR_WHITE}, NEWLINE,
       {text = "Grey: No rivers present, but at least one sink.",
        pen = COLOR_GREY}, NEWLINE,
       {text = "Light Green: Unselected river, but no sink present.",
        pen = COLOR_LIGHTGREEN}, NEWLINE,
       {text = "Green: Unselected river and at least one sink present.",
        pen = COLOR_GREEN}, NEWLINE,
       {text = "Light Blue: Selected river but no sink present.",
        pen = COLOR_LIGHTBLUE}, NEWLINE,
       {text = "Blue: Selected river and at least one sink present.",
        pen = COLOR_BLUE}, NEWLINE,
       {text = "Light Cyan: Selected river's sink but no other river present (other sinks may be present).",
        pen = COLOR_LIGHTCYAN}, NEWLINE,
       {text = "Cyan: Selected river's sink and another river present (other sinks may be present).",
        pen = COLOR_CYAN}, NEWLINE,
       {text = "Light Red: Inconsistent river present. Both course and sink tiles have the same color.",
        pen = COLOR_LIGHTRED}, NEWLINE, NEWLINE,
       "The Wipe Lost command is used to hide the sinks of rivers that have no course. Such rivers", NEWLINE,
       "should not be created by the script, but can be generated by escaping out of it after having", NEWLINE,
       "cleared the course of a river.", NEWLINE, NEWLINE,
       "Comments:", NEWLINE,
       "- The functionality provided here is tested even less than the rest.", NEWLINE,
       "- A new river is given a randomly generated name of the 'The River of Y' syntax with the Y part", NEWLINE,
       "  being a random selection of any VerbGerund within DF. There is no 'appropriate name' list to", NEWLINE,
       "  select an X part from, so 'River' is essentially hard coded.", NEWLINE,
       "- Rivers are not deleted technically, as that would throw any river indices used to refer to", NEWLINE,
       "  rivers elsewhere (if any exists) of target, so they're emptied of their course and have their", NEWLINE,
       "  sinks placed at (-1, -1).", NEWLINE,
       "- The Clear Course command achieves the same thing as the Truncate Course command operated on", NEWLINE,
       "  the first tile of a river. However, it can sometimes be tricky to locate the first tile.", NEWLINE,
       "- DF doesn't seem to like new rivers. Creating one in pre embark mode did not cause it to show", NEWLINE,
       "  up on the region map (unlike rerouted previously existing rivers)."
      }  

    return helptext       
  end
  
  --============================================================

  function BiomeManipulatorUi:init ()
    self.stack = {}
    self.item_count = 0
    self.keys = {}
    
    local screen_width, screen_height = dfhack.screen.getWindowSize ()
    
    Main_Page.Background = 
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},
                             " X:    Y:    Biome:      Size:       Type:", NEWLINE,
                             {text = "",
                                     key = keybindings.evilness.key,
                                     key_sep = '()'},
                             {text = " Evilness:     ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.animals.key,
                                     key_sep = '()'},
                             {text = " Animals:     ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.plants.key,
                                     key_sep = '()'},
                             {text = " Plants:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             " Current world tile",
                             {text = "",
                                     key = keybindings.evilness_single.key,
                                     key_sep = '()'},
                             {text = " Evilness:    ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.savagery.key,
                                     key_sep = '()'},
                             {text = " Savagery: ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.unrestricted.key,
                                     key_sep = '()'},
                             {text = " Unrestricted:      ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.floradiversity.key,
                                     key_sep = '()'},
                             {text = " floradiversity",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.faunadiversity.key,
                                     key_sep = '()'},
                             {text = " Faunadiversity",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             "Map Display:            ",
                             {text = "",
                                     key = keybindings.layer.key,
                                     key_sep = '()'},
                             {text = " Command Layer:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "                        "},
                             {text = "",
                                     key = keybindings.map_edit.key,
                                     key_sep = '()'},
                             {text = " World Map Edit",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.river.key,
                                     key_sep = '()'},
                             {text = " River Edit",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 0, t = 1, y_align = 0}}
                    
    Main_Page.Cavern =
      widgets.Label {text = {{text = "",
                              key = keybindings.cavern.key,
                              key_sep = '()'},
                             {text = " Cavern Param Edit",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 0, t = 5, yalign = 0},
                     visible = (Layer >= 0 and Layer <= 2)}
      
    Main_Page.Weather =
      widgets.Label {text = {{text = "",
                              key = keybindings.weather.key,
                              key_sep = '()'},
                             {text = " Weather Manipulation",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                              key = keybindings.geo.key,
                              key_sep = '()'},
                             {text = " Geo Manipulation",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 24, t = 5, yalign = 0},
                     visible = {Layer == Surface}}
      
    Main_Page.X =
      widgets.Label {text = Fit_Right (tostring (x), 3),
                     frame = {l = 16, t = 1, yalign = 0}}
                                          
    Main_Page.Y = 
      widgets.Label {text = Fit_Right (tostring (y), 3),
                     frame = {l = 22, t = 1, yalign = 0}}
                                          
    Main_Page.Biome =
      widgets.Label {text = Fit_Right (tostring (region [Layer]), 4),
                     frame = {l = 33, t = 1, yalign = 0}}

    Main_Page.Size =
      widgets.Label {text = Fit_Right (tostring (size [Layer]), 6),
                     frame = {l = 43, t = 1, yalign = 0}}

    Main_Page.Type =
      widgets.Label {text = df.world_region_type [df.global.world.world_data.regions [region [Surface]].type],
                     frame = {l = 56, t = 1, yalign = 0}}

    Main_Page.Evilness =
      widgets.Label {text = Fit_Right (tostring (evilness), 3),
                     frame = {l = 14, t = 2, yalign = 0},
                     text_pen = Savagery_Pen (evilness)}
      
    Main_Page.Animals =
      widgets.Label {text = Fit_Right (tostring (animals [Layer]), 3),
                     frame = {l = 34, t = 2, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
      
    Main_Page.Plants =
      widgets.Label {text = Fit_Right (tostring (plants [Layer]), 3),
                     frame = {l = 52, t = 2, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
      
    Main_Page.Evilness_Single =
      widgets.Label {text = Fit_Right (tostring (evilness), 3),
                     frame = {l = 34, t = 3, yalign = 0},
                     text_pen = Biome_Color (savagery, evilness)}
      
    Main_Page.Savagery =
      widgets.Label {text = Fit_Right (tostring (savagery), 3),
                     frame = {l = 52, t = 3, yalign = 0},
                     text_pen = Biome_Color (savagery, evilness)}
      
    Main_Page.Unrestricted =
      widgets.Label {text = tostring (Unrestricted),
                     frame = {l = 19, t = 4, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
      
    Main_Page.Map_Label =
      widgets.Label {text = "Biome",
                     frame = {l = 13, t = 6, yalign = 0}}      
    
    Main_Page.Layer =
      widgets.Label {text = layer_image [Layer],
                     frame = {l = 44, t = 6, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                 
    --  Another premature Map elemen section.                 
    Map_Page.Elevation =
      widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).elevation), 4),
                     frame = {l = 17, t = 3, yalign = 0}}
      
    Map_Page.Rainfall =
      widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).rainfall), 3),
                     frame = {l = 39, t = 3, yalign = 0}}
      
    Map_Page.Vegetation =
      widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).vegetation), 3),
                     frame = {l = 59, t = 3, yalign = 0}}
      
    Map_Page.Temperature =
      widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).temperature), 5),
                     frame = {l = 16, t = 4, yalign = 0}}
      
    Map_Page.Evilness =
      widgets.Label {text = Fit_Right (tostring (evilness), 3),
                     frame = {l = 39, t = 4, yalign = 0},
                     text_pen = Savagery_Pen (evilness)}
      
    Map_Page.Drainage =
      widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).drainage), 3),
                     frame = {l = 59, t = 4, yalign = 0}}
      
    Map_Page.Volcanism =
      widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).volcanism), 3),
                     frame = {l = 18, t = 5, yalign = 0}}
      
    Map_Page.Savagery =
      widgets.Label {text = Fit_Right (tostring (savagery), 3),
                     frame = {l = 39, t = 5, yalign = 0},
                     text_pen = Savagery_Pen (savagery)}
      
    Map_Page.Salinity =
      widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).salinity), 3),
                     frame = {l = 59, t = 5, yalign = 0}}
      
    Main_Page.Grid_Visibility = {}
    Main_Page.Grid_Label = {}
    
    Main_Page.Biome_Grid = Grid {frame = {l = 1,
                                          t = 9,
                                          w = math.min (map_width, screen_width - 2),
                                          h = math.min (map_height, screen_height - 10)},
                                 width = map_width,
                                 height = map_height,
                                 visible = true}
    Main_Page.Biome_Grid:panCenter (x, y)
    table.insert (Main_Page.Grid_Visibility, Main_Page.Biome_Grid)
    table.insert (Main_Page.Grid_Label, "Biome")
    Main_Page.Grid_Visibility_Index = 1
    table.insert (Grids, Main_Page.Biome_Grid)
    
    --  Map_Page.Biome_Grid introduced prematurely to have it defined when Make_Biome is called.
    Map_Page.Biome_Grid = Grid {frame = {l = 1,
                                         t = 9,
                                         w = math.min (map_width, screen_width - 2),
                                         h = math.min (map_height, screen_height - 10)},
                                width = map_width,
                                height = map_height,
                                visible = true}
    Map_Page.Biome_Grid:panCenter (x, y)
    table.insert (Grids, Map_Page.Biome_Grid)
    
    --  River_Page.River_Grid introduced prematurely to have it defined when Make_Biome is called.
    River_Page.River_Grid = Grid {frame = {l = 1,
                                           t = 9,
                                           w = math.min (map_width, screen_width - 2),
                                           h = math.min (map_height, screen_height - 10)},
                                  width = map_width,
                                  height = map_height,
                                  visible = true}
                                  
    River_Page.River_Grid:panCenter (x, y)
    table.insert (Grids, River_Page.River_Grid)
    
    Main_Page.Region_Grid = Grid {frame = {l = 1, 
                                           t = 9, 
                                           w = math.min (map_width, screen_width - 2),
                                           h = math.min (map_height, screen_height - 10)},
                                  width = map_width,
                                    height = map_height,
                                  visible = false}
    Main_Page.Region_Grid:panCenter (x, y)
    table.insert (Main_Page.Grid_Visibility, Main_Page.Region_Grid)
    table.insert (Main_Page.Grid_Label, "Region")
    table.insert (Grids, Main_Page.Region_Grid)
    
    Main_Page.Underground_Grid = {}
    for i = 0, 3 do
      Main_Page.Underground_Grid [i] = Grid {frame = {l = 1,
                                                      t = 9,
                                                      w = math.min (map_width, screen_width - 2),
                                                      h = math.min (map_height, screen_height - 10)},
                                             width = map_width,
                                             height = map_height,
                                             visible = false}
       Main_Page.Underground_Grid [i]:panCenter (x, y)
      table.insert (Main_Page.Grid_Visibility, Main_Page.Underground_Grid [i])
      table.insert (Grids, Main_Page.Underground_Grid [i])
    end
    
    table.insert (Main_Page.Grid_Label, "Cavern 1")
    table.insert (Main_Page.Grid_Label, "Cavern 2")
    table.insert (Main_Page.Grid_Label, "Cavern 3")
    table.insert (Main_Page.Grid_Label, "Magma Sea")
          
    Main_Page.Geo_Grid =
      Grid {frame = {l = 1,
                     t = 9,
                     w = math.min (map_width, screen_width - 2),
                     h = math.min (map_height, screen_height - 10)},
                     width = map_width,
                     height = map_height,
                     visible = false}
    Main_Page.Geo_Grid:panCenter (x, y)
    table.insert (Main_Page.Grid_Visibility, Main_Page.Geo_Grid)
    table.insert (Main_Page.Grid_Label, "Geo Biome")
    table.insert (Grids, Main_Page.Geo_Grid)
      
    Animal_Page.Present_List = {}
    Animal_Page.Absent_List = {}
    Plant_Page.Present_List = {}
    Plant_Page.Absent_List = {}
    
    Setup_Rivers ()
    Make_Region (x, y)
    Make_Biome ()
    Make_Underground (x, y)
    Make_Geo (x, y)
    Main_Page.Profile = Make_Profile (region [Surface])
        
    for i = 0, 3 do
      if region [i] then
        Make_Subterranean_Profile (region [i], i)
      end
    end

    local mainPage = widgets.Panel {
      subviews = {Main_Page.Background,
                  Main_Page.Cavern,
                  Main_Page.Weather,
                  Main_Page.X,
                  Main_Page.Y,
                  Main_Page.Biome,
                  Main_Page.Size,
                  Main_Page.Type,
                  Main_Page.Evilness,
                  Main_Page.Animals,
                  Main_Page.Plants,
                  Main_Page.Evilness_Single,
                  Main_Page.Savagery,
                  Main_Page.Unrestricted,
                  Main_Page.Layer,
                  Main_Page.Map_Label,
                  Main_Page.Biome_Grid,
                  Main_Page.Region_Grid,
                  Main_Page.Underground_Grid [0],
                  Main_Page.Underground_Grid [1],
                  Main_Page.Underground_Grid [2],
                  Main_Page.Underground_Grid [3],
                  Main_Page.Geo_Grid}}
          
    Animal_Page.Background =
      widgets.Label {text = "Creatures Present         Creatures Absent",
                     frame = {l = 1, t = 4, yalign = 0}}
     
    Animal_Page.Animal_Background =
      widgets.Label {text = {"     Type:                    Race:\n",
                             {text = "",
                                     key = keybindings.min_count.key,
                                     key_sep = '()'},
                             {text = " Count min:          ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.max_count.key,
                                     key_sep = '()'},
                             {text = " Count Max:",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 1, t = 1, yalign = 0}}
    
    Animal_Page.Animal_Visible_List = {}    
    table.insert (Animal_Page.Animal_Visible_List, Animal_Page.Animal_Background)
    
    Animal_Page.Type =
      widgets.Label {text = "",
                     frame = {l = 12, t = 1, yalign = 0}}
    table.insert (Animal_Page.Animal_Visible_List, Animal_Page.Type)
      
    Animal_Page.Race = 
      widgets.Label {text = "",
                     frame = {l = 37, t = 1, yalign = 0}}
    table.insert (Animal_Page.Animal_Visible_List, Animal_Page.Race)
                     
    Animal_Page.Min_Count =
      widgets.Label {text = "",
                     frame = {l = 17, t = 2, yalign = 0}}
    table.insert (Animal_Page.Animal_Visible_List, Animal_Page.Min_Count)
                     
    Animal_Page.Max_Count =
      widgets.Label {text = "",
                     frame = {l = 42, t = 2, yalign = 0}}
    table.insert (Animal_Page.Animal_Visible_List, Animal_Page.Max_Count)
                     
    Animal_Page.Present =
      widgets.List {view_id = "Present Animals",
                    choices = Make_List (Animal_Page.Present_List [Layer]),
                    frame = {l = 1, w = 25, t = 6, yalign = 0},
                    on_submit = self:callback ("removeAnimal"),
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    on_select = (function (index, choice) Apply_Animal_Selection (index, choice) end)}
                    
    Apply_Animal_Selection (Animal_Page.Present:getSelected ())
    
    Animal_Page.Absent =
      widgets.List {view_id = "Absent Animals",
                    choices = Make_List (Animal_Page.Absent_List [Layer]),
                    frame = {l = 27, w= 25, t = 6, yalign = 0},
                    on_submit = self:callback ("addAnimal"),
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY}
                    
    local animalPage = widgets.Panel {
      subviews = {Animal_Page.Background,
                  Animal_Page.Animal_Background,
                  Animal_Page.Type,
                  Animal_Page.Race,
                  Animal_Page.Min_Count,
                  Animal_Page.Max_Count,
                  Animal_Page.Present,
                  Animal_Page.Absent}}
    
    Plant_Page.Background =
      widgets.Label {text = "Plants Present            Plants Absent",
                     frame = {l = 1, t = 4, yalign = 0}}
     
    Plant_Page.Plant_Background =
      widgets.Label {text = {"     Type:                    Plant:"},
                     frame = {l = 1, t = 1, yalign = 0}}
    
    Plant_Page.Plant_Visible_List = {}
    table.insert (Plant_Page.Plant_Visible_List, Plant_Page.Plant_Background)
    
    Plant_Page.Type =
      widgets.Label {text = "",
                     frame = {l = 12, t = 1, yalign = 0}}
    table.insert (Plant_Page.Plant_Visible_List, Plant_Page.Type)
      
    Plant_Page.Plant = 
      widgets.Label {text = "",
                     frame = {l = 37, t = 1, yalign = 0}}
    table.insert (Plant_Page.Plant_Visible_List, Plant_Page.Plant)
                     
    Plant_Page.Present =
      widgets.List {view_id = "Present Plants",
                    choices = Make_List (Plant_Page.Present_List [Layer]),
                    frame = {l = 1, w = 25, t = 6, yalign = 0},
                    on_submit = self:callback ("removePlant"),
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    on_select = (function (index, choice) Apply_Plant_Selection (index, choice) end)}
                    
    Apply_Plant_Selection (Plant_Page.Present:getSelected ())

    Plant_Page.Absent =
      widgets.List {view_id = "Absent Plants",
                    choices = Make_List (Plant_Page.Absent_List [Layer]),
                    frame = {l = 27,  w = 25, t = 6, yalign = 0},
                    on_submit = self:callback ("addPlant"),
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY}
                    
    local plantPage = widgets.Panel 
      {subviews = {Plant_Page.Background,
                   Plant_Page.Plant_Background,
                   Plant_Page.Type,
                   Plant_Page.Plant,
                   Plant_Page.Present,
                   Plant_Page.Absent}}
    
    Cavern_Page.Background =
      widgets.Label {text = {"     Region:\n",
                             "     Layer:\n",
                             {text = "",
                                     key = keybindings.cavern_water.key,
                                     key_sep = '()'},                             
                             {text = " Water:                  ",
                              pen = COLOR_LIGHTBLUE},
                             "0 - 100. <10 => Subterranean Chasm. Doesn't update populations on biome change\n",
                             {text = "",
                                     key = keybindings.cavern_openness_min.key,
                                     key_sep = '()'},                            
                             {text = " Openness Min:           ",
                              pen = COLOR_LIGHTBLUE},
                             "0 - 100. <= Openness Max\n",
                             {text = "",
                                     key = keybindings.cavern_openness_max.key,
                                     key_sep = '()'},                            
                             {text = " Openness Max:           ",
                              pen = COLOR_LIGHTBLUE},
                             "0 - 100. >= Openness Min\n",
                             {text = "",
                                     key = keybindings.cavern_density_min.key,
                                     key_sep = '()'},
                             {text = " Passage Density Min:    ",
                              pen = COLOR_LIGHTBLUE},
                             "0 - 100. >= Density Max\n",
                             {text = "",
                                     key = keybindings.cavern_density_max.key,
                                     key_sep = '()'},
                             {text = " Passage Density Max:    ",
                              pen = COLOR_LIGHTBLUE},
                             "0 - 100. <= Density Min\n"},
                     frame = {l = 0, t = 1, yalign = 0}}
      
    Cavern_Page.Region =
      widgets.Label {text = " ",
                     frame = {l = 24, t = 1, yalign = 0}}
      
    Cavern_Page.Layer =
      widgets.Label {text = " ",
                     frame = {l = 20, t = 2, yalign = 0}}
      
    Cavern_Page.Water =
      widgets.Label {text = " ",
                     frame = {l = 25, t = 3, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
    
    Cavern_Page.Openness_Min =
      widgets.Label {text = " ",
                     frame = {l = 25, t = 4, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
    
    Cavern_Page.Openness_Max =
      widgets.Label {text = " ",
                     frame = {l = 25, t = 5, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
    
    Cavern_Page.Density_Min =
      widgets.Label {text = " ",
                     frame = {l = 25, t = 6, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
    
    Cavern_Page.Density_Max =
      widgets.Label {text = " ",
                     frame = {l = 25, t = 7, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
    
    local cavernPage = widgets.Panel
      {subviews = {Cavern_Page.Background,
                   Cavern_Page.Region,
                   Cavern_Page.Layer,
                   Cavern_Page.Water,
                   Cavern_Page.Openness_Min,
                   Cavern_Page.Openness_Max,
                   Cavern_Page.Density_Min,
                   Cavern_Page.Density_Max}}
      
    Weather_Page.Interaction_Index = -1
    Weather_Page.Focus_List = {}
    Weather_Page.Focus = 1
        
    for i, interaction in ipairs (df.global.world.interaction_instances.all) do
      if interaction.region_index == region [Surface] then
        Weather_Page.Interaction_Index = interaction.interaction_id
        break
      end
    end
        
    Weather_Page.Label =
      widgets.Label {text = "Evil Weather",
                     frame = {l = 0, t = 1, yalign = 0}}
                     
    Weather_Page.Key =
      widgets.Label {text = "Syndrome effect key: Start/Peak/End/Severity displayed unless permanent",
                     frame = {l = 14, t = 1, yalign = 0}}
      
    Weather_Page.Weather_List = {}
    table.insert (Weather_Page.Weather_List, {name = "NONE", index = -1})
    
    for i, interaction in ipairs (df.global.world.raws.interactions) do
      if #interaction.sources >= 1 and
         interaction.sources [0]:getType () == df.interaction_source_type.REGION then
        table.insert (Weather_Page.Weather_List, {name = interaction.name, index = i})
      end
    end
    
    Sort_Keep_First (Weather_Page.Weather_List)
    
    Weather_Page.Weather =
      widgets.List {view_id = "Region Weather",
                    choices = Make_List (Weather_Page.Weather_List),
                    frame = {l = 0,  w = 13, t = 3, yalign = 0},
                    on_select = self:callback ("onWeatherSelect"),
                    on_submit = self:callback ("shiftWeather"),
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY}
    
    table.insert (Weather_Page.Focus_List, Weather_Page.Weather)
    
    Weather_Page.Visibility_List = {}  --  Declared here rather than above, as onWeatherSelect is called prematurely above,
                                       --  and the absence of this field is used as a detector.
    table.insert (Weather_Page.Visibility_List, Weather_Page.Key)
    
    Weather_Page.Info =
      widgets.Label {text = "Linked to current region:\n\n" ..
                            "Name:\n",
                     frame = {l = 14, t = 3, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
    
    Weather_Page.Dynamic_Info =
      widgets.Label {text = " ",
                     frame = {l = 14, t = 7, yalign = 0}}
    
    table.insert (Weather_Page.Visibility_List, Weather_Page.Dynamic_Info)
    
    Weather_Page.Dead_Percent_Label =
      widgets.Label {text = {{text = "",
                              key = keybindings.weather_dead_percent.key,
                              key_sep = '()'},                             
                             {text = " Dead Vegetation:    %",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 53, t = 3, yalign = 0}}
    
    Weather_Page.Current_Weather =
      widgets.Label {text = " ",
                     frame = {l = 40, t = 3, yalign = 0}}
      
    if reanimating_named then
      Weather_Page.Dead_Percent =
        widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.regions [region [Surface]].dead_percentage), 3),
                       frame = {l = 75, t = 3, yalign = 0}}
                       
    else
      Weather_Page.Dead_Percent =
        widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.regions [region [Surface]].unk_1e4 % 256), 3),
                       frame = {l = 75, t = 3, yalign = 0}}
    end
      
    Weather_Page.Name =
      widgets.Label {text = " ",
                     frame = {l = 30, t = 5, yalign = 0}}
          
    weatherPage = widgets.Panel
      {subviews = {Weather_Page.Label,
                   Weather_Page.Key,
                   Weather_Page.Weather,
                   Weather_Page.Info,
                   Weather_Page.Dynamic_Info,
                   Weather_Page.Dead_Percent_Label,
                   Weather_Page.Current_Weather,
                   Weather_Page.Dead_Percent,
                   Weather_Page.Name}}
                  
    Geo_Page.Layer_Label =
      widgets.Label {text = {"Geo Biome:     ",
                             {text = "",
                                     key = keybindings.next_edit.key,
                                     key_sep = '()'},                             
                             {text = " /",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.prev_edit.key,
                                     key_sep = '()'},                            
                             {text = " Swap current table     ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.geo_diversity_single.key,
                                     key_sep = '()'},       
                             {text = " Geo Diversity this Biome only",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_clone.key,
                                     key_sep = '()'},                             
                             {text = " Clone Geo Biome",
                              pen = COLOR_LIGHTBLUE},                             
                             {text = "",
                                     key = keybindings.geo_update.key,
                                     key_sep = '()'},                             
                             {text = " Update Geo Biome Number           ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.geo_diversity_all.key,
                                     key_sep = '()'},       
                             {text = " Geo Diversity all Biomes",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             Fit ("Layer", Max_Geo_Layer_Name_Length + 1) ..
                             Fit ("Type", Max_Geo_Type_Name_Length + 1) ..
                             Fit ("Top", 5) ..
                             "Bottom  Layer Manipulation Keys:"},
                     frame = {l = 0, t = 0, yalign = 0}}
      
    Geo_Page.Geo_Index =
      widgets.Label {text = Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).geo_index), 4),
                     frame = {l = 10, t = 0, yalign = 0}}
    
    Geo_Page.Layer_Edit_Label =
      widgets.Label {text = {{text = "",
                                     key = keybindings.geo_delete.key,
                                     key_sep = '()'},                             
                             {text = " Delete",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_split.key,
                                     key_sep = '()'},                            
                             {text = " Split",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_expand.key,
                                     key_sep = '()'},                            
                             {text = " Expand",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_contract.key,
                                     key_sep = '()'},
                             {text = " Contract",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_morph.key,
                                     key_sep = '()'},
                             {text = " Morph",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = Max_Geo_Vein_Name_Length + 1 + 5 + Max_Geo_Cluster_Name_Length + Max_Geo_Vein_Name_Length + 2, t = 4, yalign = 0}}
      
    Geo_Page.Vein_Label =
      widgets.Label {text = Fit ("Vein/Cluster/Inclusion", Max_Geo_Vein_Name_Length + 1) ..
                            Fit (" %", 5) ..
                            Fit ("Cluster Type", Max_Geo_Cluster_Name_Length + 1) ..
                            "Nested In      Vein Manipulation Keys:",
                     frame = {l = 0, t = 22, yalign = 0}}
      
    Geo_Page.Vein_Edit_Label =
      widgets.Label {text = {{text = "",
                                     key = keybindings.geo_add.key,
                                     key_sep = '()'},                            
                             {text = " Add",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_remove.key,
                                     key_sep = '()'},                            
                             {text = " Remove",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_nest.key,
                                     key_sep = '()'},
                             {text = " Nest",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_proportion.key,
                                     key_sep = '()'},
                             {text = " Proportion",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_full.key,
                                     key_sep = '()'},
                             {text = " Full mineral set",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.geo_clear.key,
                                     key_sep = '()'},
                             {text = " Clear mineral list",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = Max_Geo_Vein_Name_Length + 1 + 5 + Max_Geo_Cluster_Name_Length + Max_Geo_Vein_Name_Length + 2, t = 24, yalign = 0}}
      
    Geo_Page.Layer_List = {}
    Geo_Page.Vein_List = {}
    
    Make_Layer (x, y)
    
    Geo_Page.Layer =
      widgets.List {view_id = "Geo Layers",
                    choices = Make_List (Geo_Page.Layer_List),
                    frame = {l = 0, t = 4, yalign = 0},
                    on_select = self:callback ("onGeoLayerSelect"),
                    on_submit = nil,
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY}
                    
    Geo_Page.Vein =
      widgets.List {view_id = "Veins",
                    choices = Make_List (Geo_Page.Vein_List),
                    frame = {l = 0, t = 24, yalign = 0},
                    on_select = self:callback ("onGeoVeinSelect"),
                    on_submit = nil,
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY}
      
    local geoPage = widgets.Panel
      {subviews = {Geo_Page.Layer_Label,
                   Geo_Page.Geo_Index,
                   Geo_Page.Layer_Edit_Label,
                   Geo_Page.Vein_Label,
                   Geo_Page.Vein_Edit_Label,
                   Geo_Page.Layer,
                   Geo_Page.Vein}}
        
    Map_Page.Background = 
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},
                             " X:    Y:    Biome:      Size:       Type:", NEWLINE,
                             {text = "",
                                     key = keybindings.map_adopt_biome.key,
                                     key_sep = '()'},
                             {text = " Adopt Biome     ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.map_new_region.key,
                                     key_sep = '()'},
                             {text = " New Region      ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.map_elevation.key,
                                     key_sep = '()'},
                             {text = " Elevation:      ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.map_rainfall.key,
                                     key_sep = '()'},
                             {text = " Rainfall:       ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.map_vegetation.key,
                                     key_sep = '()'},
                             {text = " Vegetation:     ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.map_temperature.key,
                                     key_sep = '()'},
                             {text = " Temperature:    ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.map_evilness.key,
                                     key_sep = '()'},
                             {text = " Evilness:       ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.map_drainage.key,
                                     key_sep = '()'},
                             {text = " Drainage:       ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.map_volcanism.key,
                                     key_sep = '()'},
                             {text = " Volcanism:      ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.map_savagery.key,
                                     key_sep = '()'},
                             {text = " Savagery:       ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.map_salinity.key,
                                     key_sep = '()'},
                             {text = " Salinity:       ",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.map_biome.key,
                                     key_sep = '()'},
                             {text = " Biome:       ",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 0, t = 1, y_align = 0}}
                    
    Map_Page.X =
      widgets.Label {text = Fit_Right (tostring (x), 3),
                     frame = {l = 16, t = 1, yalign = 0}}
                                          
    Map_Page.Y = 
      widgets.Label {text = Fit_Right (tostring (y), 3),
                     frame = {l = 22, t = 1, yalign = 0}}
                                          
    Map_Page.Biome =
      widgets.Label {text = Fit_Right (tostring (region [Surface]), 4),
                     frame = {l = 33, t = 1, yalign = 0}}

    Map_Page.Size =
      widgets.Label {text = Fit_Right (tostring (size [Surface]), 6),
                     frame = {l = 43, t = 1, yalign = 0}}

    Map_Page.Type =
      widgets.Label {text = df.world_region_type [df.global.world.world_data.regions [region [Surface]].type],
                     frame = {l = 56, t = 1, yalign = 0}}

    Map_Page.Biome_Name =
      widgets.Label {text = df.biome_type [get_biome_type
                      (y,
                       df.global.world.worldgen.worldgen_parms.dim_y,
                       df.global.world.world_data.region_map [x]:_displace (y).temperature,
                       df.global.world.world_data.region_map [x]:_displace (y).elevation,
                       df.global.world.world_data.region_map [x]:_displace (y).drainage,
                       df.global.world.world_data.region_map [x]:_displace (y).rainfall,
                       df.global.world.world_data.region_map [x]:_displace (y).salinity,
                       df.global.world.world_data.region_map [x]:_displace (y).elevation,  --  Proxy fo vegetation as that doesn't seem to be set before finalization
                       df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake)],
                     frame = {l = 12, t = 6, yalign = 0}}
      
    local mapPage = widgets.Panel
      {subviews = {Map_Page.Background,
                   Map_Page.X,
                   Map_Page.Y,
                   Map_Page.Biome,
                   Map_Page.Size,
                   Map_Page.Type,
                   Map_Page.Elevation,
                   Map_Page.Rainfall,
                   Map_Page.Vegetation,
                   Map_Page.Temperature,
                   Map_Page.Evilness,
                   Map_Page.Drainage,
                   Map_Page.Volcanism,
                   Map_Page.Savagery,
                   Map_Page.Salinity,
                   Map_Page.Biome_Name,
                   Map_Page.Biome_Grid}}

    River_Page.Visibility = {}
    table.insert (River_Page.Visibility, River_Page.River_Grid)  --  Grid defined earlier
    
    River_Page.Background =
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},
                             " River:       Name:", NEWLINE,
                             {text = "",
                                     key = keybindings.river_select.key,
                                     key_sep = '()'},
                             {text = "             ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.river_brook.key,
                                     key_sep = '()'}, NEWLINE,
                             {text = "",
                                     key = keybindings.river_flow.key,
                                     key_sep = '()'},
                             {text = "                 ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.river_exit.key,
                                     key_sep = '()'},
                             {text = "                 ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                     key = keybindings.river_elevation.key,
                                     key_sep = '()'}, NEWLINE,
                              
                             {text = "",
                                     key = keybindings.river_clear.key,
                                     key_sep = '()'},
                             {text = "                 ",
                              pen = COLOR_DARKGREY},
                             {text = "",
                                     key = keybindings.river_truncate.key,
                                     key_sep = '()'},
                             {text = "                 ",
                              pen = COLOR_DARKGREY},
                             {text = "",
                                     key = keybindings.river_add.key,
                                     key_sep = '()'}, NEWLINE,

                             {text = "",
                                     key = keybindings.river_set_sink.key,
                                     key_sep = '()'},
                             {text = "                 ",
                              pen = COLOR_DARKGREY},
                             {text = "",
                                     key = keybindings.river_set_sink_direction.key,
                                     key_sep = '()'}, NEWLINE,
                              
                             {text = "",
                                     key = keybindings.river_delete.key,
                                     key_sep = '()'},
                             {text = "                 ",
                              pen = COLOR_DARKGREY},
                             {text = "",
                                     key = keybindings.river_new.key,
                                     key_sep = '()'},
                             {text = "                 ",
                              pen = COLOR_DARKGREY},
                             {text = "",
                                     key = keybindings.river_wipe_lost.key,
                                     key_sep = '()'},
                                     
                                     },
                     frame = {l = 0, t = 1, y_align = 0}}
      
    table.insert (River_Page.Visibility, River_Page.Background)
    
    River_Page.Number =
      widgets.Label {text = " ",
                     frame = {l = 20, t = 1, yalign = 0},
                     text_pen = COLOR_WHITE}
                     
    table.insert (River_Page.Visibility, River_Page.Number)
    
    River_Page.Name =
      widgets.Label {text = " ",
                     frame = {l = 33, t = 1, yalign = 0},
                     text_pen = COLOR_WHITE}
                     
    table.insert (River_Page.Visibility, River_Page.Name)
    
    River_Page.Select_River =
      widgets.Label {text = "Select River",
                     frame = {l = 9, t = 2, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.Select_River)
    
    River_Page.Brook =
      widgets.Label {text = "Is Brook:",
                     frame = {l = 26, t = 2, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                     
    table.insert (River_Page.Visibility, River_Page.Brook)
    
    River_Page.Brook_Edit =
      widgets.Label {text = " ",
                     frame = {l = 38, t = 2, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                     
    table.insert (River_Page.Visibility, River_Page.Brook_Edit)
    
    River_Page.Flow =
      widgets.Label {text = "Flow:",
                     frame = {l = 5, t = 3, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                     
    table.insert (River_Page.Visibility, River_Page.Flow)
    
    River_Page.Flow_Edit =
      widgets.Label {text = "     ",
                     frame = {l = 11, t = 3, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                     
    table.insert (River_Page.Visibility, River_Page.Flow_Edit)
    
    River_Page.Exit_Tile =
      widgets.Label {text = "Exit Tile:",
                     frame = {l = 26, t = 3, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                     
    table.insert (River_Page.Visibility, River_Page.Exit_Tile)
    
    River_Page.Exit_Tile_Edit =
      widgets.Label {text = "  ",
                     frame = {l = 37, t = 3, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                     
    table.insert (River_Page.Visibility, River_Page.Exit_Tile_Edit)
    
    River_Page.Elevation =
      widgets.Label {text = "Elevation:",
                     frame = {l = 47, t = 3, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                     
    table.insert (River_Page.Visibility, River_Page.Elevation)
    
    River_Page.Elevation_Edit =
      widgets.Label {text = "   ",
                     frame = {l = 58, t = 3, yalign = 0},
                     text_pen = COLOR_LIGHTBLUE}
                     
    table.insert (River_Page.Visibility, River_Page.Elevation_Edit)
    
    River_Page.Clear_Course =
      widgets.Label {text = "Clear Course",
                     frame = {l = 5, t = 4, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.Clear_Course)
    
    River_Page.Truncate_Course =
      widgets.Label {text = "Truncate Course",
                     frame = {l = 26, t = 4, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.Truncate_Course)
    
    River_Page.Add_Course =
      widgets.Label {text = "Add Course",
                     frame = {l = 47, t = 4, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.Add_Course)
    
    River_Page.Set_Sink =
      widgets.Label {text = "Set Sink",
                     frame = {l = 5, t = 5, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.Set_Sink)
    
    River_Page.Set_Sink_Direction =
      widgets.Label {text = "Set Sink Direction",
                     frame = {l = 26, t = 5, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.Set_Sink_Direction)
    
    River_Page.Delete_River =
      widgets.Label {text = "Delete River",
                     frame = {l = 5, t = 6, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.Delete_River)
    
    River_Page.New_River =
      widgets.Label {text = "New River",
                     frame = {l = 26, t = 6, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.New_River)
    
    River_Page.Wipe_Lost =
      widgets.Label {text = "Wipe Lost",
                     frame = {l = 47, t = 6, yalign = 0},
                     text_pen = COLOR_DARKGREY}
                     
    table.insert (River_Page.Visibility, River_Page.New_River)
    
    local riverPage = widgets.Panel
      {subviews = {River_Page.Background,
                   River_Page.Number,
                   River_Page.Name,
                   River_Page.Select_River,
                   River_Page.Brook,
                   River_Page.Brook_Edit,
                   River_Page.Flow,
                   River_Page.Flow_Edit,
                   River_Page.Exit_Tile,
                   River_Page.Exit_Tile_Edit,
                   River_Page.Elevation,
                   River_Page.Elevation_Edit,
                   River_Page.Clear_Course,
                   River_Page.Truncate_Course,
                   River_Page.Add_Course,
                   River_Page.Set_Sink,
                   River_Page.Set_Sink_Direction,
                   River_Page.Delete_River,
                   River_Page.New_River,
                   River_Page.Wipe_Lost,
                   River_Page.River_Grid}}
      
    Help_Page.Visibility_List = {}
    
    Help_Page.Focus = 1
    
    Help_Page.Main = 
      widgets.Label
        {text = Helptext_Main (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = true}
         
    table.insert (Help_Page.Visibility_List, Help_Page.Main)
         
    Help_Page.Plant =
      widgets.Label
        {text = Helptext_Plant (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = false}
    
    table.insert (Help_Page.Visibility_List, Help_Page.Plant)
         
    Help_Page.Animal =
      widgets.Label
        {text = Helptext_Animal (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = false}
        
    table.insert (Help_Page.Visibility_List, Help_Page.Animal)
         
    Help_Page.Weather =
      widgets.Label
        {text = Helptext_Weather (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = false}
        
    table.insert (Help_Page.Visibility_List, Help_Page.Weather)
         
    Help_Page.Geo =
      widgets.Label
        {text = Helptext_Geo (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = false}
        
    table.insert (Help_Page.Visibility_List, Help_Page.Geo)
         
    Help_Page.Cavern =
      widgets.Label
        {text = Helptext_Cavern (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = false}
        
    table.insert (Help_Page.Visibility_List, Help_Page.Cavern)
    
    Help_Page.World_Map =
      widgets.Label
        {text = Helptext_World_Map (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = false}
        
    table.insert (Help_Page.Visibility_List, Help_Page.World_Map)
    
    Help_Page.River =
      widgets.Label
        {text = Helptext_River (),
         frame = {l = 1, t = 1, yalign = 0},
         visible = false}
        
    table.insert (Help_Page.Visibility_List, Help_Page.River)
    
    helpPage = widgets.Panel
      {subviews = {Help_Page.Main,
                   Help_Page.Plant,
                   Help_Page.Animal,
                   Help_Page.Weather,
                   Help_Page.Geo,
                   Help_Page.Cavern,
                   Help_Page.World_Map,
                   Help_Page.River}}
                   
    local pages = widgets.Pages 
      {subviews = {mainPage,
                   animalPage,
                   plantPage,
                   cavernPage,
                   weatherPage,
                   geoPage,
                   mapPage,
                   riverPage,
                   helpPage},view_id = "pages",
                   }

    pages:setSelected (1)
    Focus = "Main"
      
    Update (0, 0, true)
    self:addviews {pages}
  end

  --==============================================================

   function BiomeManipulatorUi:updateEvilness (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The Evilness legal range is 0 - 100", COLOR_LIGHTRED)
    else
      local val = tonumber (value)
      local purge_good = false
      local purge_evil = false
      local typ
      local x_coord
      
      if evilness < 33 and
         val >= 33 then
        purge_good = true
        
      elseif evilness >= 66 and val < 66 then
        purge_evil = true
      end
      
      if val < 33 then
        if region_evil_named then
          df.global.world.world_data.regions [region [Surface]].good = true
          df.global.world.world_data.regions [region [Surface]].evil = false
        else
          df.global.world.world_data.regions [region [Surface]].unk_1e8 = 256
        end
        
      elseif val < 66 then
        if region_evil_named then
          df.global.world.world_data.regions [region [Surface]].good = false
          df.global.world.world_data.regions [region [Surface]].evil = false
        else
          df.global.world.world_data.regions [region [Surface]].unk_1e8 = 0
        end
        
      else
        if region_evil_named then
          df.global.world.world_data.regions [region [Surface]].good = false
          df.global.world.world_data.regions [region [Surface]].evil = true
        else
          df.global.world.world_data.regions [region [Surface]].unk_1e8 = 1
        end
      end
      
      if purge_good or purge_evil then
        for i = #df.global.world.world_data.regions [region [Surface]].population - 1, 0, Surface do
          typ = df.global.world.world_data.regions [region [Surface]].population [i].type
          if Is_Animal (typ) then
            if (purge_good and
                df.global.world.raws.creatures.all [df.global.world.world_data.regions [region [Surface]].population [i].race].flags.GOOD) or
               (purge_evil and
                df.global.world.raws.creatures.all [df.global.world.world_data.regions [region [Surface]].population [i].race].flags.EVIL) then
              df.global.world.world_data.regions [region [Surface]].population:erase (i)
            end                
     
          elseif Is_Plant (typ) then
            if (purge_good and
                df.global.world.raws.plants.all [df.global.world.world_data.regions [region [Surface]].population [i].plant].flags.GOOD) or
               (purge_evil and
                df.global.world.raws.plants.all [df.global.world.world_data.regions [region [Surface]].population [i].plant].flags.EVIL) then
              df.global.world.world_data.regions [region [Surface]].population:erase (i)
            end                        
          end
        end
      end
      
      if purge_evil then
        for i = #df.global.world.interaction_instances.all - 1, 0, -1 do
          if df.global.world.interaction_instances.all [i].region_index == region [Surface] then
            df.global.world.interaction_instances.all:erase (i)
          end
        end
      end
      
      for i, x_coord in ipairs (df.global.world.world_data.regions [region [Surface]].region_coords.x) do
        df.global.world.world_data.region_map [x_coord]:_displace (df.global.world.world_data.regions [region [Surface]].region_coords.y [i]).evilness = val
      end
    end
    
    Update (0, 0, true)
   end
   
  --==============================================================

  function BiomeManipulatorUi:updateElevation (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 250 then
      dialog.showMessage ("Error!", "The Elevation legal range is 0 - 250", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).elevation = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateRainfall (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The Rainfall legal range is 0 - 100", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).rainfall = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateVegetation (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The Vegetation legal range is 0 - 100", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).vegetation = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateTemperature (value)
    if not tonumber (value) or 
       tonumber (value) < -1000 or 
       tonumber (value) > 1000 then
      dialog.showMessage ("Error!", "The Temperature legal range is -1000 - 1000", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).temperature = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateEvilnessSingle (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The Evilness legal range is 0 - 100", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).evilness = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateDrainage (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The Drainage legal range is 0 - 100", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).drainage = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateVolcanism (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The Volcanism legal range is 0 - 100", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).volcanism = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateSavagery (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The Savagery legal range is 0 - 100", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).savagery = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateSalinity (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or 
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The Salinity legal range is 0 - 100", COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).salinity = tonumber (value)    
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:Floradiversity ()
    local Profile
    local unrestricted_cache = Unrestricted
    local plant
    Unrestricted = false
    
    if Layer == Surface then
      for i, biome_region in ipairs (df.global.world.world_data.regions) do
        dfhack.println ("Updating flora for " .. layer_image [Layer] .. " region " .. tostring (i))
        Profile = Make_Profile (i)
      
        for k, plant_entry in ipairs (Plant_Page.Absent_List [Surface]) do
          plant = df.global.world.raws.plants.all [plant_entry.index]
          local new_plant = df.world_population:new ()
          new_plant.plant = plant_entry.index
    
          if plant.flags.TREE then
            new_plant.type = df.world_population_type.Tree
          
          elseif plant.flags.GRASS then
            new_plant.type = df.world_population_type.Grass
            
          else
            new_plant.type = df.world_population_type.Bush
          end          
          
          df.global.world.world_data.regions [i].population:insert ("#", new_plant)        
        end
      end
      
    else
      for i, biome_region in ipairs (df.global.world.world_data.underground_regions) do
        if biome_region.layer_depth == Layer then
          dfhack.println ("Updating flora for " .. layer_image [Layer] .. " region " .. tostring (i))
          Profile = Make_Subterranean_Profile (i, Layer)
      
          for k, plant_entry in ipairs (Plant_Page.Absent_List [Layer]) do
            plant = df.global.world.raws.plants.all [plant_entry.index]
            local new_plant = df.world_population:new ()
            new_plant.plant = plant_entry.index
    
            if plant.flags.TREE then
              new_plant.type = df.world_population_type.Tree
          
            elseif plant.flags.GRASS then
              new_plant.type = df.world_population_type.Grass
            
            else
              new_plant.type = df.world_population_type.Bush
            end          
          
            df.global.world.world_data.underground_regions [i].feature_init.feature.population:insert ("#", new_plant)        
         end         
       end
     end
    end
    
    Unrestricted = unrestricted_cache
    Update (0, 0, false)
  end
  
  --==============================================================

  function BiomeManipulatorUi:Faunadiversity ()
    local Profile
    local unrestricted_cache = Unrestricted
    local creature
    Unrestricted = false
    
    if Layer == Surface then
      for i, biome_region in ipairs (df.global.world.world_data.regions) do
        dfhack.println ("Updating fauna for " .. layer_image [Layer] .. " region " .. tostring (i))
        Profile = Make_Profile (i)
      
        for k, animal_entry in ipairs (Animal_Page.Absent_List [Surface]) do
          creature = df.global.world.raws.creatures.all [animal_entry.index]
          local new_creature = df.world_population:new ()
          new_creature.race = animal_entry.index
    
          if creature.flags.VERMIN_SOIL_COLONY then
            new_creature.type = df.world_population_type.ColonyInsect
          
          elseif (creature_raw_flags_renamed and creature.flags.HAS_ANY_VERMIN_MICRO) or
                 (not creature_raw_flags_renamed and creature.flags.any_vermin) then
            if creature.flags.UBIQUITOUS then
              new_creature.type = df.world_population_type.VerminInnumerable
              
            else
              new_creature.type = df.world_population_type.Vermin
            end
            
          else
            new_creature.type = df.world_population_type.Animal
          end          
     
          if not creature.flags.UBIQUITOUS then
            local creature_biome_count = 0
            for t, q in pairs (Profile) do
              if type (q) == 'number' and
                 q ~= "SAVAGE" and                 
                 creature.flags [t] then
                creature_biome_count = creature_biome_count + q
              end
            end
            
            if creature.flags.SAVAGE then
              creature_biome_count = math.min (creature_biome_count, Profile.SAVAGE)
            end

            new_creature.count_min = creature_biome_count * (7 + math.random (9))
            new_creature.count_max = new_creature.count_min
          end
          
          df.global.world.world_data.regions [i].population:insert ("#", new_creature)
        end
      end
    
    else
      for i, biome_region in ipairs (df.global.world.world_data.underground_regions) do
        if biome_region.layer_depth == Layer then
          dfhack.println ("Updating fauna for " .. layer_image [Layer] .. " region " .. tostring (i))
          Profile = Make_Subterranean_Profile (i, Layer)
      
          for k, animal_entry in ipairs (Animal_Page.Absent_List [Layer]) do
            creature = df.global.world.raws.creatures.all [animal_entry.index]
            local new_creature = df.world_population:new ()
            new_creature.race = animal_entry.index
    
          if creature.flags.VERMIN_SOIL_COLONY then
            new_creature.type = df.world_population_type.ColonyInsect
          
          elseif (creature_raw_flags_renamed and creature.flags.HAS_ANY_VERMIN_MICRO) or
                 (not creature_raw_flags_renamed and creature.flags.any_vermin) then
            if creature.flags.UBIQUITOUS then
              new_creature.type = df.world_population_type.VerminInnumerable
              
            else
              new_creature.type = df.world_population_type.Vermin
            end
            
          else
            new_creature.type = df.world_population_type.Animal
          end          
     
          if not creature.flags.UBIQUITOUS then
            local creature_biome_count = size [Layer]
            
            new_creature.count_min = creature_biome_count * (7 + math.random (9))
            new_creature.count_max = new_creature.count_min
          end
           
            df.global.world.world_data.underground_regions [i].feature_init.feature.population:insert ("#", new_creature)        
         end         
       end
     end
    end
    
    Unrestricted = unrestricted_cache
    Update (0, 0, false)
  end

  --==============================================================

  function BiomeManipulatorUi:removeAnimal (index, choice)
    if choice ~= NIL then
      table.insert (Animal_Page.Absent_List [Layer], {name = choice.text, index = Animal_Page.Present_List [Layer] [index].index})
      Sort (Animal_Page.Absent_List [Layer])
      Animal_Page.Absent:setChoices (Make_List (Animal_Page.Absent_List [Layer]))
      
      if Layer == Surface then
        df.global.world.world_data.regions [region [Layer]].population:erase (Locate_Animal (Animal_Page.Present_List [Layer] [index].index, Layer))
      else
        df.global.world.world_data.underground_regions [region [Layer]].feature_init.feature.population:erase (Locate_Animal (Animal_Page.Present_List [Layer] [index].index, Layer))
      end
      
      table.remove (Animal_Page.Present_List [Layer], index)
      Animal_Page.Present:setChoices (Make_List (Animal_Page.Present_List [Layer]))
    end
  end
  
  --==============================================================
  
  function BiomeManipulatorUi:addAnimal (index, choice)
    if choice ~= NIL then
      table.insert (Animal_Page.Present_List [Layer], {name = choice.text, index = Animal_Page.Absent_List [Layer] [index].index})
      Sort (Animal_Page.Present_List [Layer])
      Animal_Page.Present:setChoices (Make_List (Animal_Page.Present_List [Layer]))     

      local creature = df.global.world.raws.creatures.all [Animal_Page.Absent_List [Layer] [index].index]
      local new_creature = df.world_population:new ()
      new_creature.race = Animal_Page.Absent_List [Layer] [index].index
    
      if creature.flags.VERMIN_SOIL_COLONY then
        new_creature.type = df.world_population_type.ColonyInsect
          
      elseif (creature_raw_flags_renamed and creature.flags.HAS_ANY_VERMIN_MICRO) or
             (not creature_raw_flags_renamed and creature.flags.any_vermin) then
        if creature.flags.UBIQUITOUS then
          new_creature.type = df.world_population_type.VerminInnumerable
              
        else
          new_creature.type = df.world_population_type.Vermin
        end
            
      else
        new_creature.type = df.world_population_type.Animal
      end          
     
      if not creature.flags.UBIQUITOUS then
        local creature_biome_count = 0
        if Layer == Surface then
          for t, q in pairs (Main_Page.Profile) do
            if type (q) == 'number' and
               q ~= "SAVAGE" and                 
               creature.flags [t] then
              creature_biome_count = creature_biome_count + q
            end
          end
            
          if creature.flags.SAVAGE then
            creature_biome_count = math.min (creature_biome_count, Main_Page.Profile.SAVAGE)
          end
        else
          creature_biome_count = size [Layer]
        end

        new_creature.count_min = creature_biome_count * (7 + math.random (9))
        new_creature.count_max = new_creature.count_min
      end
          
      if Layer == Surface then
        df.global.world.world_data.regions [region [Layer]].population:insert ("#", new_creature)
      else
        df.global.world.world_data.underground_regions [region [Layer]].feature_init.feature.population:insert ("#", new_creature)
      end
      
      table.remove (Animal_Page.Absent_List [Layer], index)
      Animal_Page.Absent:setChoices (Make_List (Animal_Page.Absent_List [Layer]))
    end
  end
  
  --==============================================================
    
  function BiomeManipulatorUi:updateAnimalMinCount (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or
       tonumber (value) > tonumber (Animal_Page.Max_Count.text) then
      dialog.showMessage ("Error!", "The min count cannot be negative or exceed Max count", COLOR_LIGHTRED)
    else
      local index, choice = Animal_Page.Present:getSelected ()
      local pop_index = Locate_Animal (Animal_Page.Present_List [Layer] [index].index, Layer)
      
      if Layer == Surface then
        df.global.world.world_data.regions [region [Layer]].population [pop_index].count_min = tonumber (value)
      else
        df.global.world.world_data.underground_regions [region [Layer]].feature_init.feature.population [pop_index].count_min = tonumber (value)
      end
      
      Animal_Page.Min_Count:setText (Fit_Right (value, 8))
    end
  end
  
  --==============================================================
  
  function BiomeManipulatorUi:updateAnimalMaxCount (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or
       tonumber (value) < tonumber (Animal_Page.Min_Count.text) then
      dialog.showMessage ("Error!", "The Max count cannot be negative or less than the min count", COLOR_LIGHTRED)
    else
      local index, choice = Animal_Page.Present:getSelected ()
      local pop_index = Locate_Animal (Animal_Page.Present_List [Layer] [index].index, Layer)
      
      if Layer == Surface then
        df.global.world.world_data.regions [region [Layer]].population [pop_index].count_max = tonumber (value)
      else
        df.global.world.world_data.underground_regions [region [Layer]].feature_init.feature.population [pop_index].count_max = tonumber (value)
      end
      
      Animal_Page.Max_Count:setText (Fit_Right (value, 8))
    end
  end
  
  --==============================================================
  
  function BiomeManipulatorUi:removePlant (index, choice)
    if choice ~= NIL then
      table.insert (Plant_Page.Absent_List [Layer], {name = choice.text, index = Plant_Page.Present_List [Layer] [index].index})
      Sort (Plant_Page.Absent_List [Layer])
      Plant_Page.Absent:setChoices (Make_List (Plant_Page.Absent_List [Layer]))
      
      if Layer == Surface then
        df.global.world.world_data.regions [region [Layer]].population:erase (Locate_Plant (Plant_Page.Present_List [Layer] [index].index, Layer))
      else
        df.global.world.world_data.underground_regions [region [Layer]].feature_init.feature.population:erase 
         (Locate_Plant (Plant_Page.Present_List [Layer] [index].index, Layer))
      end
      
      table.remove (Plant_Page.Present_List [Layer], index)
      Plant_Page.Present:setChoices (Make_List (Plant_Page.Present_List [Layer]))
    end
  end
  
  --==============================================================
  
  function BiomeManipulatorUi:addPlant (index, choice)
    if choice ~= NIL then
      table.insert (Plant_Page.Present_List [Layer], {name = choice.text, index = Plant_Page.Absent_List [Layer] [index].index})
      Sort (Plant_Page.Present_List [Layer])
      Plant_Page.Present:setChoices (Make_List (Plant_Page.Present_List [Layer]))     
      local plant = df.global.world.raws.plants.all [Plant_Page.Absent_List [Layer] [index].index]
      local new_plant = df.world_population:new ()
      new_plant.plant = Plant_Page.Absent_List [Layer] [index].index
    
      if plant.flags.TREE then
        new_plant.type = df.world_population_type.Tree
          
      elseif plant.flags.GRASS then
        new_plant.type = df.world_population_type.Grass
            
      else
        new_plant.type = df.world_population_type.Bush
      end          
     
     if Layer == Surface then
        df.global.world.world_data.regions [region [Layer]].population:insert ("#", new_plant)
      else
        df.global.world.world_data.underground_regions [region [Layer]].feature_init.feature.population:insert ("#", new_plant)
      end
      
      table.remove (Plant_Page.Absent_List [Layer], index)
      Plant_Page.Absent:setChoices (Make_List (Plant_Page.Absent_List [Layer]))
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateCavernWater (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or
       tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The legal Water range is 0 - 100", COLOR_LIGHTRED)

    else      
      if underground_region_type_updated then
        df.global.world.world_data.underground_regions [region [Layer]].water = tonumber (value)
        
      else
        df.global.world.world_data.underground_regions [region [Layer]].unk_7a = tonumber (value)
      end
      
      Update (0, 0, true)
      Cavern_Page.Water:setText (Fit_Right (value, 3))
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateCavernOpennessMin (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or
       tonumber (value) > tonumber (Cavern_Page.Openness_Max.text) then
      dialog.showMessage ("Error!", "The legal Openness Min range is 0 - 100 and it cannot be greater than Openness Max", COLOR_LIGHTRED)

    else    
      if underground_region_type_updated then
        df.global.world.world_data.underground_regions [region [Layer]].openness_min = tonumber (value)
        
      else
        df.global.world.world_data.underground_regions [region [Layer]].unk_7e = tonumber (value)
      end
      
      Update (0, 0, false)
      Cavern_Page.Openness_Min:setText (Fit_Right (value, 3))
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateCavernOpennessMax (value)
    if not tonumber (value) or 
       tonumber (value) > 100 or
       tonumber (value) < tonumber (Cavern_Page.Openness_Min.text) then
      dialog.showMessage ("Error!", "The legal Openness Max range is 0 - 100 and it cannot be less than Openness Min", COLOR_LIGHTRED)
      
    else
      if underground_region_type_updated then
        df.global.world.world_data.underground_regions [region [Layer]].openness_max = tonumber (value)
        
      else    
        df.global.world.world_data.underground_regions [region [Layer]].unk_80 = tonumber (value)
      end
      
      Update (0, 0, false)
      Cavern_Page.Openness_Max:setText (Fit_Right (value, 3))
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateCavernDensityMin (value)
    if not tonumber (value) or 
       tonumber (value) < 0 or
       tonumber (value) > tonumber (Cavern_Page.Density_Max.text) then
      dialog.showMessage ("Error!", "The legal Passage Density Min range is 0 - 100 and it cannot be greater than Passage Density Max", COLOR_LIGHTRED)
      
    else
      if underground_region_type_updated then
        df.global.world.world_data.underground_regions [region [Layer]].passage_density_min = tonumber (value)
        
      else
        df.global.world.world_data.underground_regions [region [Layer]].unk_82 = tonumber (value)
      end
      
      Update (0, 0, false)
      Cavern_Page.Density_Min:setText (Fit_Right (value, 3))
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateCavernDensityMax (value)
    if not tonumber (value) or 
       tonumber (value) > 100 or
       tonumber (value) < tonumber (Cavern_Page.Density_Min.text) then
      dialog.showMessage ("Error!", "The legal Passage Density Max range is 0 - 100 and it cannot be less than Passage Density Min", COLOR_LIGHTRED)
      
    else
      if underground_region_type_updated then
        df.global.world.world_data.underground_regions [region [Layer]].passage_density_max = tonumber (value)
        
      else
        df.global.world.world_data.underground_regions [region [Layer]].passage_density = tonumber (value)
      end
      
      Update (0, 0, false)
      Cavern_Page.Density_Max:setText (Fit_Right (value, 3))
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateWeatherDeadPercent (value)
    if not tonumber (value) or 
       tonumber (value) > 100 or
       tonumber (value) < 0 then
      dialog.showMessage ("Error!", "The legal Dead Percent range is 0 - 100", COLOR_LIGHTRED)
      
    else
      if reanimating_named then
        df.global.world.world_data.regions [region [Surface]].dead_percentage = tonumber (value)
        
      else
        local bool
        
        if df.global.world.world_data.regions [region [Surface]].unk_1e4 >= 256 then
          bool = 1
        else
          bool = 0
        end
        
        df.global.world.world_data.regions [region [Surface]].unk_1e4 = tonumber (value) + bool
      end
      
      Update (0, 0, false)
      Weather_Page.Dead_Percent:setText (Fit_Right (value, 3))
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:shiftWeather (index, choice)
    if Weather_Page.Interaction_Index == -1 then  --  None
      if index == 1 then
        return  --  No change
      end
      dialog.showYesNoPrompt("Add evil weather to the current region",
                             "Are you sure you want to add the selected\n" ..
                             "evil weather interaction to the current region?",
                              COLOR_WHITE,
                              (function ()
                                 local id = -1
                                 local found
                                 local new_interaction = df.interaction_instance:new ()
                                 new_interaction.interaction_id = Weather_Page.Weather_List [index].index
                                 new_interaction.region_index = region [Surface]
                                 for i = 0, #df.global.world.interaction_instances.all - 1 do
                                   found = false
                                   for k, instance in ipairs (df.global.world.interaction_instances.all) do
                                     if instance.id == i then
                                       found = true
                                       break
                                     end
                                   end
                                   
                                   if not found then
                                     id = i
                                     break
                                   end
                                 end
                                 
                                 if id == -1 then
                                   id = #df.global.world.interaction_instances.all
                                 end
                                 new_interaction.id = id
                                 df.global.world.interaction_instances.all:insert (id, new_interaction)
                                 Weather_Page.Interaction_Index = Weather_Page.Weather_List [index].index
                                 Weather_Page.Current_Weather:setText (Weather_Page.Weather_List [index].name)
                               end),
                              (function () end))
     
    elseif Weather_Page.Weather_List [index].index == Weather_Page.Interaction_Index then
      return  --  No change
       
    elseif index == 1 then
      dialog.showYesNoPrompt("Remove evil weather from the current region",
                             "Are you sure you want to remove the existing\n" ..
                             "evil weather interaction from the current region?",
                              COLOR_WHITE,
                              (function ()
                                 for i, interaction in ipairs (df.global.world.interaction_instances.all) do
                                   if interaction.region_index == region [Surface] then
                                     df.global.world.interaction_instances.all:erase (i)
                                     break
                                   end
                                 end
                                 
                                 Weather_Page.Interaction_Index = Weather_Page.Weather_List [index].index
                                 Weather_Page.Current_Weather:setText (Weather_Page.Weather_List [index].name)
                               end),
                              (function () end))
     
    else
      dialog.showYesNoPrompt("Replace evil weather for the current region",
                             "Are you sure you want to replace the existing\n" ..
                             "evil weather of the current region with the selected one?",
                              COLOR_WHITE,
                              (function ()
                                 for i, interaction in ipairs (df.global.world.interaction_instances.all) do
                                   if interaction.region_index == region [Surface] then
                                     interaction.interaction_id = Weather_Page.Weather_List [index].index
                                     break
                                   end
                                 end
                                 
                                 Weather_Page.Interaction_Index = Weather_Page.Weather_List [index].index
                                 Weather_Page.Current_Weather:setText (Weather_Page.Weather_List [index].name)
                               end),
                              (function () end))
    end    
  end
  
  --==============================================================

  function BiomeManipulatorUi:onWeatherSelect (index, choice)
    if not Weather_Page.Visibility_List then
      return  --  Called during startup
    end
    
    local Interaction_Index = Weather_Page.Weather_List [index].index
    local Info = {}
    
    if index == 1 or  --  NONE
      not df.global.world.raws.interactions [Interaction_Index].sources or
      df.global.world.raws.interactions [Interaction_Index].sources [0]._type ~= df.interaction_source_regionst then  --  Only type supported
      for i, element in ipairs (Weather_Page.Visibility_List) do
        element.visible = false
      end
          
    else
      for i, element in ipairs (Weather_Page.Visibility_List) do
        element.visible = true
      end
    
      for i, target in ipairs (df.global.world.raws.interactions [Interaction_Index].targets) do
        if target._type == df.interaction_target_corpsest then
          for k, effect in ipairs (df.global.world.raws.interactions [Interaction_Index].effects) do
            if effect._type == df.interaction_effect_animatest then
              table.insert (Info, "Reanimation\n")
              break
            end
          end
          
        elseif target._type == df.interaction_target_materialst then
          table.insert (Info, "Material\n")
          
          local mat_type
          local mat_index
          
          if interaction_target_material_type_updated then
            mat_type = target.mat_type
            mat_index = target.mat_index
          else
            mat_type = target ["interaction_target_materialst.anon_1"]
            mat_index = target.anon_2
          end
          
          mat_info = dfhack.matinfo.decode (mat_type, mat_index)
          
          if mat_info.mode == 'inorganic' then
            for l, syndrome in ipairs (df.global.world.raws.inorganics [mat_index].material.syndrome) do
              table.insert (Info, "  Syndrome name: " ..syndrome.syn_name .. "\n")
                  
              for m, effect in ipairs (syndrome.ce) do
                table.insert (Info, "  " .. df.creature_interaction_effect_type [effect:getType ()] .. 
                                       string.rep (' ', string.len ("MATERIAL_FORCE_MULTIPLIER") - -- Longest name
                                                        string.len (df.creature_interaction_effect_type [effect:getType ()])))
                if effect.prob ~= 100 then
                  table.insert (Info, " Probability: " .. tostring (effect.prob))
                end
                
                if effect ["end"] == -1 then
                  table.insert (Info, " Permanent")
                else
                table.insert (Info, "  " .. Fit_Right (tostring (effect.start), 5) .. "/" ..
                                             Fit_Right (tostring (effect.peak), 5) .. "/" .. 
                                            Fit_Right (tostring (effect ["end"]), 5))
                end
                
                if effect._type == df.creature_interaction_effect_painst or
                   effect._type == df.creature_interaction_effect_swellingst or
                   effect._type == df.creature_interaction_effect_oozingst or
                   effect._type == df.creature_interaction_effect_bruisingst or
                   effect._type == df.creature_interaction_effect_blistersst or
                   effect._type == df.creature_interaction_effect_numbnessst or
                   effect._type == df.creature_interaction_effect_paralysisst or
                   effect._type == df.creature_interaction_effect_bleedingst or
                   effect._type == df.creature_interaction_effect_necrosisst or
                   effect._type == df.creature_interaction_effect_impair_functionst then                 
                  table.insert (Info, "/" .. Fit_Right (tostring (effect.sev), 4))
                  
                  for n, tgt in ipairs (effect.target.mode) do
                    table.insert (Info, "\n")
                    table.insert (Info, "   Mode: " .. df.creature_interaction_effect_target_mode [tgt] ..
                                        " Key: " .. effect.target.key [n].value ..
                                        " Tissue: " .. effect.target.tissue [n].value .. "\n")
                  end
                  
                  if #effect.target.mode == 0 then
                    table.insert (Info, "\n")
                  end
                   
                elseif effect._type == df.creature_interaction_effect_feverst or
                       effect._type == df.creature_interaction_effect_cough_bloodst or
                       effect._type == df.creature_interaction_effect_vomit_bloodst or
                       effect._type == df.creature_interaction_effect_nauseast or
                       effect._type == df.creature_interaction_effect_unconsciousnessst or
                       effect._type == df.creature_interaction_effect_painst or
                       effect._type == df.creature_interaction_effect_drowsinessst or
                       effect._type == df.creature_interaction_effect_dizzinessst  or
                       effect._type == df.creature_interaction_effect_erratic_behaviorst then
                  table.insert (Info, "/" .. Fit_Right (tostring (effect.sev), 4) .. "\n")
                
                elseif effect._type == df.creature_interaction_effect_display_namest then
                  table.insert (Info, " " .. effect.name .. "\n")
                  
                elseif effect._type == df.creature_interaction_effect_bp_appearance_modifierst then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_transformationst then
                  table.insert (Info, " Chance: " .. tostring (effect.chance) .. 
                                      " Race: " .. effect.race_str .. 
                                      " Caste: " .. effect.caste_str .. "\n")
                                 
                elseif effect._type == df.creature_interaction_effect_skill_roll_adjustst then
                  table.insert (Info, " Multiplier: " .. tostring (effect.multiplier) .. 
                                      " Chance: " .. tostring (effect.chance) .. "\n")
                                  
                elseif effect._type == df.creature_interaction_effect_display_symbolst then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_flash_symbolst then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_phys_att_changest then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_ment_att_changest then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_add_simple_flagst then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_remove_simple_flagst then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_speed_changest then
                  table.insert (Info, " Bonus Add: " .. tostring (effect.bonus_add) .. 
                                      " Bonus Percentage: " .. tostring (effect.bonus_perc) .. "\n")
                                  
                elseif effect._type == df.creature_interaction_effect_body_mat_interactionst then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_material_force_adjustst then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_can_do_interactionst then
                  table.insert (Info, "\n")
                  
                elseif effect._type == df.creature_interaction_effect_sense_creature_classst then
                  table.insert (Info, " Class name: " .. effect.class_name .. "\n")
                
                elseif effect._type == df.creature_interaction_effect_feel_emotionst then
                  table.insert (Info, " Emotion: " .. df.emotion_type [effect.emotion] ..
                                      " Severity: " .. tostring (effect.sev) .. "\n")
                
                elseif effect._type == df.creature_interaction_effect_change_personalityst then
                  table.insert (Info, "\n")
                  
                else
                  table.insert (Info, " Unknown derived interaction effect type\n")
                end
              end
            end
          end
          
          table.insert (Info, "  " .. tostring (mat_info) .. "\n")
          table.insert (Info, "  " .. df.breath_attack_type [target.breath_attack_type] .. "\n")
          
        else          
          table.insert (Info, "Unsupported target type " .. tostring (target._type) .. "\n")
        end
      end
          
      Weather_Page.Dynamic_Info:setText (Info)
      Weather_Page.Dynamic_Info:updateLayout ()
    end

    Weather_Page.Name:setText (Weather_Page.Weather_List [index].name)             
  end
  
  --==============================================================

  function BiomeManipulatorUi:onGeoLayerSelect (index, choice)
    if not Geo_Page.Vein then  --  Called during creation, before Vein has been created.
      return
    end
    
    local geo_biome = df.global.world.world_data.geo_biomes 
      [df.global.world.world_data.region_map [x]:_displace (y).geo_index]
      
    for i, layer in ipairs (geo_biome.layers) do
      table.insert (Geo_Page.Layer_List, {name = Layer_Image (df.global.world.raws.inorganics [layer.mat_index].id,
                                                              df.geo_layer_type [layer.type],
                                                              layer.top_height,
                                                              layer.bottom_height),
                                          index = layer.mat_index})
    end
    
    Geo_Page.Vein_List = {}
    
    if index ~= 0 then
      for i, vein in ipairs (geo_biome.layers [index - 1].vein_mat) do
        table.insert (Geo_Page.Vein_List, {name = Vein_Image (geo_biome.layers [index - 1], i),
                                           index = vein})
      end
    end
    
    Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))
  end
  
  --==============================================================

  function BiomeManipulatorUi:onGeoVeinSelect (index, choice)
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateGeoBiomeNumber (value)
    if not tonumber (value) or
    tonumber (value) < 0 or
    tonumber (value) >= #df.global.world.world_data.geo_biomes then
      dialog.showMessage ("Error!", "The legal Geo Biome Number range is 0 - " .. tostring (#df.global.world.world_data.geo_biomes - 1), COLOR_LIGHTRED)
    else
      df.global.world.world_data.region_map [x]:_displace (y).geo_index = tonumber (value)
      Make_Geo (x, y)
      Make_Layer (x, y)
      Geo_Page.Geo_Index:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).geo_index), 4))
      
      Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List), 1)
      Geo_Page.Layer.active = true
      Geo_Page.Layer_Edit_Label.visible = true
      
      Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List), 1)
      Geo_Page.Vein.active = false
      Geo_Page.Vein_Edit_Label.visible = false
    end    
  end
  
  --==============================================================

  function BiomeManipulatorUi:cloneGeoBiome ()
    local geo_biome = df.world_geo_biome:new ()
    geo_biome.index = #df.global.world.world_data.geo_biomes
        
    for i, layer in ipairs (df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)].layers) do
      geo_biome.layers:insert (i, df.world_geo_layer:new ())
      geo_biome.layers [i].type = layer.type
      geo_biome.layers [i].mat_index = layer.mat_index
      geo_biome.layers [i].top_height = layer.top_height
      geo_biome.layers [i].bottom_height = layer.bottom_height
    
      for k, vein in ipairs (layer.vein_mat) do
        geo_biome.layers [i].vein_mat:insert (k, vein)
        geo_biome.layers [i].vein_nested_in:insert (k, layer.vein_nested_in [k])
        geo_biome.layers [i].vein_type:insert (k, layer.vein_type [k])
        geo_biome.layers [i].vein_unk_38:insert (k, layer.vein_unk_38 [k])      
      end
    end

    Geo_Page.Geo_Index:setText (Fit_Right (tostring (#df.global.world.world_data.geo_biomes), 4))
    df.global.world.world_data.geo_biomes:insert ('#', geo_biome)    
  end
  
  --==============================================================
  
  function Geo_Diversity_Layer (geo_biome, layer)
    local Layer_Material = df.global.world.raws.inorganics [geo_biome.layers [layer].mat_index]
    local Found
        
    for i, material in ipairs (df.global.world.raws.inorganics) do
      Found = false
          
      for k, mat in ipairs (geo_biome.layers [layer].vein_mat) do
        if geo_biome.layers [layer].vein_mat [k] == i then
          Found = true
          break
        end
      end
          
      if not Found then
        for k, location in ipairs (material.environment.location) do
          if (location == df.environment_type.SOIL and Layer_Material.flags.SOIL) or
             (location == df.environment_type.SOIL_OCEAN and Layer_Material.flags.SOIL_OCEAN) or  --  Redundant, covered by SOIL
             (location == df.environment_type.SOIL_SAND and Layer_Material.flags.SOIL_SAND) or    --  Redundant, covered by SOIL
             (location == df.environment_type.METAMORPHIC and Layer_Material.flags.METAMORPHIC) or
             (location == df.environment_type.SEDIMENTARY and Layer_Material.flags.SEDIMENTARY) or
             (location == df.environment_type.IGNEOUS_INTRUSIVE and Layer_Material.flags.IGNEOUS_INTRUSIVE) or
             (location == df.environment_type.IGNEOUS_EXTRUSIVE and Layer_Material.flags.IGNEOUS_EXTRUSIVE) then  -- or
            -- (location == df.environment_type.ALLUVIAL and Layer_Material.flags.ALLUVIAL) then  -- No Alluvial flag!
            Found = true
            geo_biome.layers [layer].vein_mat:insert ('#', i)
            geo_biome.layers [layer].vein_nested_in:insert ('#', -1)
            geo_biome.layers [layer].vein_type:insert ('#', material.environment.type [k])
            geo_biome.layers [layer].vein_unk_38:insert ('#', 50)
            break
          end
        end                     
      end
          
      if not Found then
        for k, mat_index in ipairs (material.environment_spec.mat_index) do
          if mat_index == geo_biome.layers [layer].mat_index then
            geo_biome.layers [layer].vein_mat:insert ('#', i)
            geo_biome.layers [layer].vein_nested_in:insert ('#', -1)
            geo_biome.layers [layer].vein_type:insert ('#', material.environment_spec.inclusion_type [k])
            geo_biome.layers [layer].vein_unk_38:insert ('#', 50)
            break
          end
        end
      end
    end

    for i, vein in ipairs (geo_biome.layers [layer].vein_mat) do
      for k, material in ipairs (df.global.world.raws.inorganics) do
        for l, mat_index in ipairs (material.environment_spec.mat_index) do
          Found = false
            
          if mat_index == vein then
            for m, nested_in in ipairs (geo_biome.layers [layer].vein_nested_in) do
              if nested_in == i and
                 vein == k then
                Found = true
                break
              end
            end
              
            if not Found then
              geo_biome.layers [layer].vein_mat:insert ('#', k)
              geo_biome.layers [layer].vein_nested_in:insert ('#', i)
              geo_biome.layers [layer].vein_type:insert ('#', material.environment_spec.inclusion_type [l])
              geo_biome.layers [layer].vein_unk_38:insert ('#', 50)
            end
          end            
        end
      end      
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:geoDiversitySingle ()
    local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
    
    for index, layer in ipairs (geo_biome.layers) do
      Geo_Diversity_Layer (geo_biome, index)
    end
    
    Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))

    Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
    Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))            
  end
  
  --==============================================================

  function BiomeManipulatorUi:geoDiversityAll ()
    for i, geo_biome in ipairs (df.global.world.world_data.geo_biomes) do
      dfhack.println ("Diversifying Geo Biome " .. tostring (i) .. " (" .. tostring (#df.global.world.world_data.geo_biomes - 1) .. ")")    
      for index, layer in ipairs (geo_biome.layers) do
        Geo_Diversity_Layer (geo_biome, index)
      end
    end
    
    Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))

    Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
    Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))            
  end
  
  --==============================================================

  function BiomeManipulatorUi:updateGeoProportion (value)
    if not tonumber (value) or
    tonumber (value) < 0 or
    tonumber (value) > 100 then
      dialog.showMessage ("Error!", "The legal Proportion range is 0 - 100", COLOR_LIGHTRED)
      
    else
      local layer_index, layer_choice = Geo_Page.Layer:getSelected ()
      local index, choice = Geo_Page.Vein:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      index = index - 1

      geo_biome.layers [layer_index - 1].vein_unk_38 [index] = tonumber (value)
      
      Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))

      Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
      Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))            
    end    
  end
  
  --==============================================================

  function BiomeManipulatorUi:adoptBiome (value)
    if not tonumber (value) or
       tonumber (value) < 1 or
       tonumber (value) > 9 or
       tonumber (value) == 5 then
      dialog.showMessage ("Error!", "The legal adoption direction range is 1 - 9, excluding 5", COLOR_LIGHTRED)
    
    else
      local val = tonumber (value)
      local x_offset = val % 3 - 2
      
      if x_offset == - 2 then
        x_offset = x_offset + 3
      end
      
      local y_offset
      if val >= 7 then
        y_offset = -1
      elseif val <= 3 then
        y_offset = 1
      else
        y_offset = 0
      end
      
      if (x == 0 and
          x_offset == -1) or
         (x == df.global.world.worldgen.worldgen_parms.dim_x - 1 and
          x_offset == 1) or
         (y == 0 and
          y_offset == -1) or
         (y == df.global.world.worldgen.worldgen_parms.dim_y - 1 and
          y_offset == 1) then
        dialog.showMessage ("Error!", "The referenced world tile has to exist within the world map.", COLOR_LIGHTRED)
        
      else                                 
        local original_biome_type = 
          get_biome_type (y,
                          df.global.world.worldgen.worldgen_parms.dim_y,
                          df.global.world.world_data.region_map [x]:_displace (y).temperature,
                          df.global.world.world_data.region_map [x]:_displace (y).elevation,
                          df.global.world.world_data.region_map [x]:_displace (y).drainage,
                          df.global.world.world_data.region_map [x]:_displace (y).rainfall,
                          df.global.world.world_data.region_map [x]:_displace (y).salinity,
                          df.global.world.world_data.region_map [x]:_displace (y).rainfall,  --  Proxy for vegetation as that doesn't seem to be set before finalization
                          df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake)

        df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].biome_tile_counts [original_biome_type] = 
          df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].biome_tile_counts [original_biome_type] - 1
      
        local adopted_tile = df.global.world.world_data.region_map [x + x_offset]:_displace (y + y_offset)
        local added = false
        
        for i, x_coord in ipairs (df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].region_coords.x) do
          if x_coord == x and 
             df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].region_coords.x [i] == y then
             df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].region_coords.x:erase (i)
             df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].region_coords.y:erase (i)
             break
          end             
        end
        
        for i, x_coord in ipairs (df.global.world.world_data.regions [adopted_tile.region_id].region_coords.x) do
          if x_coord == x then
            for k = i, #df.global.world.world_data.regions [adopted_tile.region_id].region_coords.y - 1 do
              if  df.global.world.world_data.regions [adopted_tile.region_id].region_coords.y [k] < y then
                df.global.world.world_data.regions [adopted_tile.region_id].region_coords.x:insert (k, x)
                df.global.world.world_data.regions [adopted_tile.region_id].region_coords.y:insert (k, y)
                added = true
                break
              end
            end
            
          elseif x_coord > x then
            df.global.world.world_data.regions [adopted_tile.region_id].region_coords.x:insert (i, x)
            df.global.world.world_data.regions [adopted_tile.region_id].region_coords.y:insert (i, y)
            added = true
            break
          end
          
          if added then
            break
          end
        end
        
        if not added then
            df.global.world.world_data.regions [adopted_tile.region_id].region_coords.x:insert ('#', x)
            df.global.world.world_data.regions [adopted_tile.region_id].region_coords.y:insert ('#', y)
        end
        
        df.global.world.world_data.region_map [x]:_displace (y).region_id = adopted_tile.region_id
        df.global.world.world_data.region_map [x]:_displace (y).elevation = adopted_tile.elevation
        df.global.world.world_data.region_map [x]:_displace (y).rainfall = adopted_tile.rainfall
        df.global.world.world_data.region_map [x]:_displace (y).vegetation = adopted_tile.vegetation
        df.global.world.world_data.region_map [x]:_displace (y).temperature = adopted_tile.temperature
        df.global.world.world_data.region_map [x]:_displace (y).evilness = adopted_tile.evilness
        df.global.world.world_data.region_map [x]:_displace (y).drainage = adopted_tile.drainage
        df.global.world.world_data.region_map [x]:_displace (y).volcanism = adopted_tile.volcanism
        df.global.world.world_data.region_map [x]:_displace (y).savagery = adopted_tile.savagery
        df.global.world.world_data.region_map [x]:_displace (y).salinity = adopted_tile.salinity        
        df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake = adopted_tile.flags.is_lake
        
        local new_biome_type = 
          get_biome_type (y,
                          df.global.world.worldgen.worldgen_parms.dim_y,
                          adopted_tile.temperature,
                          adopted_tile.elevation,
                          adopted_tile.drainage,
                          adopted_tile.rainfall,
                          adopted_tile.salinity,
                          adopted_tile.rainfall,  --  Proxy for vegetation as that doesn't seem to be set before finalization
                          adopted_tile.flags.is_lake)

        df.global.world.world_data.regions [adopted_tile.region_id].biome_tile_counts [new_biome_type] =
          df.global.world.world_data.regions [adopted_tile.region_id].biome_tile_counts [new_biome_type] + 1
      
        if x < df.global.world.world_data.regions [adopted_tile.region_id].min_x then
          df.global.world.world_data.regions [adopted_tile.region_id].min_x = x
          
        elseif x > df.global.world.world_data.regions [adopted_tile.region_id].max_x then
          df.global.world.world_data.regions [adopted_tile.region_id].max_x = x
          
        end
        
        if y < df.global.world.world_data.regions [adopted_tile.region_id].min_y then
          df.global.world.world_data.regions [adopted_tile.region_id].min_y = y
          
        elseif y > df.global.world.world_data.regions [adopted_tile.region_id].max_y then
          df.global.world.world_data.regions [adopted_tile.region_id].max_y = y
          
        end
        
        Update (0, 0, false)
      end
    end
  end
  
  --==============================================================
  
  function BiomeManipulatorUi:updateBiome (value)
     local is_possible_tropical_area_by_latitude, is_tropical_area_by_latitude = 
       check_tropicality (y,
                          df.global.world.worldgen.worldgen_parms.dim_y,
                          0,  --  Disable when no pole.
                          df.global.world.worldgen.worldgen_parms.pole)

    local biome_type = match_biome (value)

    if not biome_type then
      dialog.showMessage ("Error!", "The Biome specification has to be one of the characters depicting a biome (see Help)", COLOR_RED)
    
    elseif not is_possible_biome (biome_type,
                                  is_possible_tropical_area_by_latitude,
                                  is_tropical_area_by_latitude,
                                  df.global.world.worldgen.worldgen_parms.pole,
                                  y) then
                         
      dialog.showMessage ("Error!", "The Biome specification has to be one of those listed", COLOR_RED)
      
    else
      local parameters = {elevation = df.global.world.world_data.region_map [x]:_displace (y).elevation,
                          rainfall = df.global.world.world_data.region_map [x]:_displace (y).rainfall,
                          vegetation = df.global.world.world_data.region_map [x]:_displace (y).vegetation,
                          temperature = df.global.world.world_data.region_map [x]:_displace (y).temperature,
                          drainage = df.global.world.world_data.region_map [x]:_displace (y).drainage,
                          salinity = df.global.world.world_data.region_map [x]:_displace (y).salinity}
                          
      local original_biome_type = 
        get_biome_type (y,
                        df.global.world.worldgen.worldgen_parms.dim_y,
                        parameters.temperature,
                        parameters.elevation,
                        parameters.drainage,
                        parameters.rainfall,
                        parameters.salinity,
                        parameters.rainfall,  -- Proxy for vegetation, as that doesn't seem to be set before finalizaiton
                        df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake)

      df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].biome_tile_counts [original_biome_type] =
        df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].biome_tile_counts [original_biome_type] - 1
      
      parameters = make_biome (biome_type,
                              is_possible_tropical_area_by_latitude,
                              is_tropical_area_by_latitude,
                              parameters,
                              df.global.world.worldgen.worldgen_parms.pole,
                              y)
                              
      df.global.world.world_data.region_map [x]:_displace (y).elevation = parameters.elevation
      df.global.world.world_data.region_map [x]:_displace (y).rainfall = parameters.rainfall
      df.global.world.world_data.region_map [x]:_displace (y).vegetation = parameters.vegetation
      df.global.world.world_data.region_map [x]:_displace (y).temperature = parameters.temperature
      df.global.world.world_data.region_map [x]:_displace (y).drainage = parameters.drainage
      df.global.world.world_data.region_map [x]:_displace (y).salinity = parameters.salinity
      df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake = 
        (biome_type == df.biome_type.LAKE_TEMPERATE_FRESHWATER or
         biome_type == df.biome_type.LAKE_TEMPERATE_BRACKISHWATER or
         biome_type == df.biome_type.LAKE_TEMPERATE_SALTWATER or
         biome_type == df.biome_type.LAKE_TROPICAL_FRESHWATER or
         biome_type == df.biome_type.LAKE_TROPICAL_BRACKISHWATER or
         biome_type == df.biome_type.LAKE_TROPICAL_SALTWATER)
         
      if df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake then
        if df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].lake_surface == -30000 then
          df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].lake_surface =
            df.global.world.world_data.region_map [x]:_displace (y).elevation
                       
        else
          df.global.world.world_data.region_map [x]:_displace (y).elevation = 
            df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].lake_surface
        end
      end
         
     df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].biome_tile_counts [biome_type] =
       df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id].biome_tile_counts [biome_type] + 1
   end

    Update (0, 0, false)      
  end
  
  --==============================================================

  --  This is a primitive implementation of an "The X Of Y" name generator. That pattern is the only one generated
  --  as opposed to native region names. The "X" is taken from the list of values associated with the corresponding
  --  region type, while the "Y" is a randomly selected VerbGerund from the complete dictionary. Names are checked
  --  for uniqueness.
  --
  function assign_region_name (name, world_region_type)
    name.parts_of_speech [5] = df.part_of_speech.Noun
    
    if world_region_type == df.world_region_type.Swamp then --  The table indices come from Quietust's df.language.xml instance.
      name.words [5] = df.global.world.raws.language.word_table [0] [3].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [3].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Desert then
      name.words [5] = df.global.world.raws.language.word_table [0] [4].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [4].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Jungle then
      name.words [5] = df.global.world.raws.language.word_table [0] [5].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [5].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Mountains then
      name.words [5] = df.global.world.raws.language.word_table [0] [6].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [6].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Lake then
      name.words [5] = df.global.world.raws.language.word_table [0] [7].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [7].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Ocean then
      name.words [5] = df.global.world.raws.language.word_table [0] [8].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [8].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Glacier then
      name.words [5] = df.global.world.raws.language.word_table [0] [9].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [9].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Tundra then
      name.words [5] = df.global.world.raws.language.word_table [0] [10].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [10].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Steppe then
      name.words [5] = df.global.world.raws.language.word_table [0] [11].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [11].words [2] - 1)]
                                
    elseif world_region_type == df.world_region_type.Hills then
      name.words [5] = df.global.world.raws.language.word_table [0] [12].words [2] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [12].words [2] - 1)]
    end
    
    name.parts_of_speech [6] = df.part_of_speech.VerbGerund
    
    while true do
      name.words [6] = df.global.world.raws.language.word_table [0] [35].words [5] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [35].words [5] - 1)]
      if df.global.world.raws.language.words [name.words [6]].forms.VerbGerund ~= "" then
        local found = false
        
        for i, region in ipairs (df.global.world.world_data.regions) do
          if region.name.words [0] == -1 and
             region.name.words [1] == -1 and
             region.name.words [2] == -1 and
             region.name.words [3] == -1 and
             region.name.words [4] == -1 and
             region.name.words [5] == name.words [5] and
             region.name.parts_of_speech [5] == name.parts_of_speech [5] and
             region.name.words [6] == name.words [6] and
             region.name.parts_of_speech [6] == name.parts_of_speech [6] then
            found = true
            break
          end
        end
        
        if not found then
          break
        end
      end
    end
    
    name.language = 0  -- Dwarf
    name.has_name = true
  end
  
  --==============================================================
  --  Even more primitive than region naming, as there's no known table to draw
  --  the first part from.
  --
  function Assign_River_Name (name)
    local river_index
    
    for i, word in ipairs (df.global.world.raws.language.words) do
      if word.word == "RIVER" then
        river_index = i
        break        
      end
    end
    
    name.words [5] = river_index
    name.parts_of_speech [5] = df.part_of_speech.Noun
      
    name.parts_of_speech [6] = df.part_of_speech.VerbGerund
    
    while true do
      name.words [6] = df.global.world.raws.language.word_table [0] [35].words [5] 
                         [rng:random (#df.global.world.raws.language.word_table [0] [35].words [5] - 1)]
      if df.global.world.raws.language.words [name.words [6]].forms.VerbGerund ~= "" then
        local found = false
        
        for i, river in ipairs (df.global.world.world_data.rivers) do
          if river.name.words [0] == -1 and
             river.name.words [1] == -1 and
             river.name.words [2] == -1 and
             river.name.words [3] == -1 and
             river.name.words [4] == -1 and
             river.name.words [5] == name.words [5] and
             river.name.parts_of_speech [5] == name.parts_of_speech [5] and
             river.name.words [6] == name.words [6] and
             river.name.parts_of_speech [6] == name.parts_of_speech [6] then
            found = true
            break
          end
        end
        
        if not found then
          break
        end
      end
    end
    
    name.language = 0  -- Dwarf
    name.has_name = true
  end
  
  --==============================================================
  
  function BiomeManipulatorUi:newRegion ()
    local parameters = {elevation = df.global.world.world_data.region_map [x]:_displace (y).elevation,
                        rainfall = df.global.world.world_data.region_map [x]:_displace (y).rainfall,
                        vegetation = df.global.world.world_data.region_map [x]:_displace (y).vegetation,
                        temperature = df.global.world.world_data.region_map [x]:_displace (y).temperature,
                        drainage = df.global.world.world_data.region_map [x]:_displace (y).drainage,
                        salinity = df.global.world.world_data.region_map [x]:_displace (y).salinity}

    local region = df.world_region:new ()
    local biome = get_biome_type (y,
                                  df.global.world.worldgen.worldgen_parms.dim_y,
                                  df.global.world.world_data.region_map [x]:_displace (y).temperature,
                                  df.global.world.world_data.region_map [x]:_displace (y).elevation,
                                  df.global.world.world_data.region_map [x]:_displace (y).drainage,
                                  df.global.world.world_data.region_map [x]:_displace (y).rainfall,
                                  df.global.world.world_data.region_map [x]:_displace (y).salinity,
                                  df.global.world.world_data.region_map [x]:_displace (y).rainfall,  --  Proxy for vegetation, as that doesn't seem to be set before finalization
                                  df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake)
      
    region.type = world_region_type_of 
      (biome,
      df.global.world.world_data.region_map [x]:_displace (y).drainage)
      
    --  Detach the tile from it's old region
    --
    local old_region = df.global.world.world_data.regions [df.global.world.world_data.region_map [x]:_displace (y).region_id]
    if region_trees_named then
      old_region.biome_tile_counts [biome] = old_region.biome_tile_counts [biome] - 1
      
    else
      old_region.unk_118 [biome] = old_region.unk_118 [biome] -1
    end
    
    for i, x_coord in ipairs (old_region.region_coords.x) do
      if x_coord == x then
        for k = i, #old_region.region_coords.y - 1 do
          if old_region.region_coords.y [k] == y then
            old_region.region_coords.x:erase (k)
            old_region.region_coords.y:erase (k)
            break
          end
        end
      end
    end
      
    region.region_coords.x:insert ('#', x)
    region.region_coords.y:insert ('#', y)
      
    if df.global.world.world_data.region_map [x]:_displace (y).flags.is_lake then
      region.lake_surface = parameters.elevation
    end
      
    region.mid_x = x
    region.mid_y = y
    region.min_x = x
    region.max_x = x
    region.min_y = y
    region.max_y = y
  
    assign_region_name (region.name, region.type)
           
    if df.global.world.world_data.region_map [x]:_displace (y).evilness < 33 then
      if region_evil_named then
        region.good = true
        region.evil = false
        
      else
        region.unk_1e8 = 256
      end
      
    elseif df.global.world.world_data.region_map [x]:_displace (y).evilness < 66 then
      if region_evil_named then
        region.good = false
        region.evil = false
        
      else      
        region.unk_1e8 = 0
      end
        
    else
      if region_evil_named then
        region.good = false
        region.evil = true
      else
        region.unk_1e8 = 1
      end
    end
     
    if region_trees_named then     
      region.biome_tile_counts [biome] = 1
      
    else
      region.unk_118 [biome] = 1
    end

    --  The tree list stuff is poorly understood. As far as I can see, all biomes of the same kind have
    --  the same trees in the tree_tile_x lists, but I don't know how they've been selected.
    --  The good/evil/savage slots contain either -1 or the single vanilla tree associated with that property.
    --  The script assumes these might be associated to biomes if modded, so the script attempts to copy
    --  values from existing biomes. If that fails, however, a simple fallback is used. Since it's not
    --  known how, or even if, these fields are used, the effects of poor implementation of the setting of
    --  them is unknown.
    --  Also note that there's a bunch of unidentified fields which this script ignores as there's no
    --  knowledge of how they should be set.
    --
    local biome_has_trees = false
    
    for i, tree in ipairs (df.global.world.raws.plants.trees) do
      if tree.flags ["BIOME_" .. df.biome_type [biome]] then
        biome_has_trees = true
        break
      end
    end
    
    if biome_has_trees then
      if region_trees_named then
        region.tree_biomes:insert ('#', biome)
        
      else
        region.unk_184:insert ("#", biome)
      end
      
      local tree_tiles_set = false
      local good_set = false
      local evil_set = false
      local savage_set = false
      
      if df.global.world.world_data.region_map [x]:_displace (y).evilness >= 33 and
         df.global.world.world_data.region_map [x]:_displace (y).evilness < 66 then
        if region_trees_named then
          region.tree_tiles_good:insert ('#', -1)
          region.tree_tiles_evil:insert ('#', -1)
          
        else
          region.unk_1b4:insert ("#", -1)
          region.unk_1c4:insert ("#", -1)
        end
        
        good_set = true
        evil_set = true         
      end
      
      if df.global.world.world_data.region_map [x]:_displace (y).savagery < 66 then
        if region_trees_named then
          region.tree_tiles_savage:insert ('#', -1)
         
        else
          region.unk_1d4:insert ("#", -1)
        end
        
        savage_set = true
      end
      
      for i, reg in ipairs (df.global.world.world_data.regions) do
        if reg.type == region.type then
          local tree_biomes
          
          if region_trees_named then
            tree_biomes = reg.tree_biomes
            
          else
            tree_biomes = reg.unk_118
          end
          
          for k, bio in ipairs (tree_biomes) do
            if bio == biome then
              if not tree_tiles_set then
                if region_trees_named then
                  region.tree_tiles_1:insert ('#', reg.tree_tiles_1 [k])
                  region.tree_tiles_2:insert ('#', reg.tree_tiles_2 [k])
                  
                else
                  region.unk_194:insert ("#", reg.unk_194 [k])
                  region.unk_1a4:insert ("#", reg.unk_1a4 [k])
                end
                
                tree_tiles_set = true
              end
              
              if not good_set and
                 reg.tree_tiles_good [k] ~= -1 then
                if region_trees_named then
                  region.tree_tiles_good:insert ('#', reg.tree_tiles_good [k])
                
                else
                  region.unk_1b4:insert ("#", reg.unk_1b4 [k])
                end
                
                good_set = true
              end
            
              if not evil_set and
                 reg.tree_tiles_evil [k] ~= -1 then
                if region_trees_named then
                  region.tree_tiles_evil:insert ('#', reg.tree_tiles_evil [k])
                
                else
                  region.unk_1c4:insert ("#", reg.unk_1c4 [k])
                end
                
                evil_set = true
              end
            
              if not savage_set and
                 reg.tree_tiles_savage [k] ~= -1 then
                if region_trees_named then
                  region.tree_tiles_savage:insert ('#', reg.tree_tiles_savage [k])
                
                else
                  region.unk_1d4:insert ("#", reg.unk_1d4 [k])
                end
                
                savage_set = true
              end
            
              break
            end
          end
          
          if tree_tiles_set and
             good_set and
             evil_set and
             savage_set then
            break
          end
        end
      end
      
      if not tree_tiles_set then
        local count = 0
        
        for i, tree in ipairs (df.global.world.raws.plants.trees) do
          if tree.flags ["BIOME_" .. df.biome_type [biome]] then
            if count == 0 then
              if region_trees_named then
                region.tree_tiles_1:insert ('#', tree.anon_1)  --  assuming this is the index
                
              else
                region.unk_194:insert ("#", tree.anon_1)
              end
              
              count = 1
              
            elseif count == 1 then
              if region_trees_named then
                region.tree_tiles_2:insert ('#', tree.anon_1)  --  assuming this is the index
                
              else
                region.unk_1a4:insert ("#", tree.anon_1)
              end
              
              count = 2
              break
            end
          end
        end
            
        if count == 1 then
          if region_trees_named then
            region.tree_tiles_2:insert ('#', region.tree_tiles_1 [0])
          
          else
            region.unk_1a4:insert ("#", region.unk_194 [0])
          end
        end
      end
      
      if not good_set then
        for i, tree in ipairs (df.global.world.raws.plants.trees) do
          if tree.flags ["BIOME_" .. df.biome_type [biome]] and
             tree.flags.GOOD then
            if region_trees_named then
              region.tree_tiles_good:insert ('#', tree.anon_1)  --  assuming this is the index
            
            else
              region.unk_1b4:insert ("#", tree.anon_1)
            end
            
            good_set = true
            break
          end
        end
        
        if not_good_set then
          if region_trees_named then
            region.tree_tiles_good:insert ('#', -1)
          
          else
            region.unk_1b4:insert ("#", -1)
          end
        end
      end
        
      if not evil_set then
        for i, tree in ipairs (df.global.world.raws.plants.trees) do
          if tree.flags ["BIOME_" .. df.biome_type [biome]] and
             tree.flags.EVIL then
            if region_trees_named then
              region.tree_tiles_evil:insert ('#', tree.anon_1)  --  assuming this is the index
            
            else
              region.unk_1c4:insert ("#", tree.anon_1)
            end
            
            evil_set = true
            break
          end
        end
        
        if not_evil_set then
          if region_trees_named then
            region.tree_tiles_evil:insert ('#', -1)
            
          else
            region.unk_1c4:insert ("#", -1)
          end
        end
      end
        
      if not savage_set then
        for i, tree in ipairs (df.global.world.raws.plants.trees) do
          if tree.flags ["BIOME_" .. df.biome_type [biome]] and
             tree.flags.SAVAGE then
            if region_trees_named then
              region.tree_tiles_savage:insert ('#', tree.anon_1)  --  assuming this is the index
            
            else
              region.unk_1d4:insert ("#", tree.anon_1)
            end
            
            savage_set = true
            break
          end
        end
        
        if not_savage_set then
          if region_trees_named then
            region.tree_tiles_savage:insert ('#', -1)
          
          else
            region.unk_1d4:insert ("#", -1)
          end
        end
      end
    end
    
    region.index = #df.global.world.world_data.regions
    df.global.world.world_data.regions:insert ('#', region)
    df.global.world.world_data.region_map [x]:_displace (y).region_id = region.index
    Update (0, 0, true)
  end
  
  --==============================================================

  function BiomeManipulatorUi:riverSelect ()
    if current_river ~= -1 then
      local consistent = Is_River_Consistent (df.global.world.world_data.rivers [current_river])
      
      for i, x_pos in ipairs (df.global.world.world_data.rivers [current_river].path.x) do
        if consistent then
          if river_matrix [x_pos] [df.global.world.world_data.rivers [current_river].path.y [i]].sink == 0 then
            river_matrix [x_pos] [df.global.world.world_data.rivers [current_river].path.y [i]].color = COLOR_LIGHTGREEN
          
          else
            river_matrix [x_pos] [df.global.world.world_data.rivers [current_river].path.y [i]].color = COLOR_GREEN
          end
          
        else
          river_matrix [x_pos] [df.global.world.world_data.rivers [current_river].path.y [i]].color = COLOR_LIGHTRED
        end
      end
      
      if df.global.world.world_data.rivers [current_river].end_pos.x ~= -1 and
         df.global.world.world_data.rivers [current_river].end_pos.x ~= df.global.world.worldgen.worldgen_parms.dim_x and
         df.global.world.world_data.rivers [current_river].end_pos.y ~= -1 and
         df.global.world.world_data.rivers [current_river].end_pos.y ~= df.global.world.worldgen.worldgen_parms.dim_y then
        if consistent then
          if river_matrix [df.global.world.world_data.rivers [current_river].end_pos.x] 
                          [df.global.world.world_data.rivers [current_river].end_pos.y].path == -1 then
            river_matrix [df.global.world.world_data.rivers [current_river].end_pos.x] 
                         [df.global.world.world_data.rivers [current_river].end_pos.y].color = COLOR_GREEN
          else
            river_matrix [df.global.world.world_data.rivers [current_river].end_pos.x] 
                         [df.global.world.world_data.rivers [current_river].end_pos.y].color = COLOR_GREY
          end
          
        else
            river_matrix [df.global.world.world_data.rivers [current_river].end_pos.x] 
                         [df.global.world.world_data.rivers [current_river].end_pos.y].color = COLOR_LIGHTRED        
        end
      end
    end
    
    current_river = river_matrix [x] [y].path
    
    for i, x_pos in ipairs (df.global.world.world_data.rivers [current_river].path.x) do
      if river_matrix [x_pos] [df.global.world.world_data.rivers [current_river].path.y [i]].sink == 0 then
        river_matrix [x_pos] [df.global.world.world_data.rivers [current_river].path.y [i]].color = COLOR_LIGHTBLUE
          
      else
        river_matrix [x_pos] [df.global.world.world_data.rivers [current_river].path.y [i]].color = COLOR_BLUE
      end
    end
      
    if df.global.world.world_data.rivers [current_river].end_pos.x ~= -1 and
       df.global.world.world_data.rivers [current_river].end_pos.x ~= df.global.world.worldgen.worldgen_parms.dim_x and
       df.global.world.world_data.rivers [current_river].end_pos.y ~= -1 and
       df.global.world.world_data.rivers [current_river].end_pos.y ~= df.global.world.worldgen.worldgen_parms.dim_y then
      if river_matrix [df.global.world.world_data.rivers [current_river].end_pos.x] 
                      [df.global.world.world_data.rivers [current_river].end_pos.y].path == -1 then
        river_matrix [df.global.world.world_data.rivers [current_river].end_pos.x] 
                     [df.global.world.world_data.rivers [current_river].end_pos.y].color = COLOR_LIGHTCYAN
      else
        river_matrix [df.global.world.world_data.rivers [current_river].end_pos.x] 
                     [df.global.world.world_data.rivers [current_river].end_pos.y].color = COLOR_CYAN
      end
    end
   
    River_Page.Number:setText (Fit_Right (tostring (current_river), 6))
    River_Page.Name:setText (dfhack.TranslateName (df.global.world.world_data.rivers [current_river].name, true))
    
    Make_Biome ()
    Update (0, 0, true)
  end  
  
  --==============================================================

  function BiomeManipulatorUi:riverBrook ()
    df.global.world.world_data.region_map [x]:_displace (y).flags.is_brook =
      not df.global.world.world_data.region_map [x]:_displace (y).flags.is_brook
      
    Update (0, 0, true)
  end
  
  --==============================================================

  function BiomeManipulatorUi:riverFlow (value)
    if not tonumber (value) or
       tonumber (value) < 0 or
       tonumber (value) > 99999 then
      dialog.showMessage ("Error!", "The legal flow range is 0 - 99999.", COLOR_LIGHTRED)
    
    else
      local val = tonumber (value)
      local index
      
      for i, x_pos in ipairs (df.global.world.world_data.rivers [river_matrix [x] [y].path].path.x) do
        if x_pos == x and
           df.global.world.world_data.rivers [river_matrix [x] [y].path].path.y [i] == y then
          index = i
          break
        end
      end
      
      if not river_type_updated then
        df.global.world.world_data.rivers [river_matrix [x] [y].path].unk_8c [index] = val
        
      else
        df.global.world.world_data.rivers [river_matrix [x] [y].path].flow [index] = val
      end
      
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:riverExit (value)
    if not tonumber (value) or
       tonumber (value) < 0 or
       tonumber (value) > 15 then
      dialog.showMessage ("Error!", "The legal flow range is 0 - 15.", COLOR_LIGHTRED)
    
    else
      local val = tonumber (value)
      local index
      
      for i, x_pos in ipairs (df.global.world.world_data.rivers [river_matrix [x] [y].path].path.x) do
        if x_pos == x and
           df.global.world.world_data.rivers [river_matrix [x] [y].path].path.y [i] == y then
          index = i
          break
        end
      end
      
      if not river_type_updated then
        df.global.world.world_data.rivers [river_matrix [x] [y].path].unk_9c [index] = val
        
      else
        df.global.world.world_data.rivers [river_matrix [x] [y].path].exit_tile [index] = val
      end
      
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:riverElevation (value)
    if not tonumber (value) or
       tonumber (value) < 0 or
       tonumber (value) > 250 then
      dialog.showMessage ("Error!", "The legal flow range is 0 - 250.", COLOR_LIGHTRED)
    
    else
      local val = tonumber (value)
      local index
      
      for i, x_pos in ipairs (df.global.world.world_data.rivers [river_matrix [x] [y].path].path.x) do
        if x_pos == x and
           df.global.world.world_data.rivers [river_matrix [x] [y].path].path.y [i] == y then
          index = i
          break
        end
      end
      
      df.global.world.world_data.rivers [river_matrix [x] [y].path].elevation [index] = val
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function River_Truncate (current_river, index)
    local cache_x = x
    local cache_y = y
    local x_pos
    local y_pos
    local last_x = x
    local last_y = y
    local feature
    Focus = "River_Truncate"  --  Block input processing. Otherwise cursor movement will be processed twice.
    
    while #df.global.world.world_data.rivers [current_river].path.x > index do
      x_pos = df.global.world.world_data.rivers [current_river].path.x [index]
      y_pos = df.global.world.world_data.rivers [current_river].path.y [index]
      move_cursor (last_x, last_y, x_pos, y_pos)  --  load feature data
      
      feature = df.global.world.world_data.feature_map [math.floor (x_pos / 16)]:_displace (math.floor (y_pos / 16))
      
      if feature.features then  --  Otherwise assume we're operating during world gen.
        for k, feature_init in ipairs (feature.features.feature_init [x_pos % 16] [y_pos % 16]) do
          if feature_init._type == df.feature_init_outdoor_riverst then
            feature.features.feature_init [x_pos % 16] [y_pos % 16]:erase (k)
            break
          end
        end
      end
      
      df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.has_river = false
      df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.is_brook = false
      
      if index ~= 0 then
        if x_pos == last_x and x_pos == last_y then  --  First to be removed
          last_x = df.global.world.rivers [current_index].path.x [index - 1]
          last_y = df.global.world.rivers [current_index].path.y [index - 1]
        end
        
        if last_x < cache_x then
          df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_left = false
          df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.river_right = false
          
        elseif last_x > cache_x then
          df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_right = false
          df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.river_left = false
            
        elseif last_y < cache_y then
          df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_down = false
          df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.river_up = false
            
        else
          df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_up = false
          df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.river_down = false
        end
      end
      
      if #df.global.world.world_data.rivers [current_river].path.x == index + 1 then  --  Last one. Remove sink reference if present.
        last_x = df.global.world.world_data.rivers [current_river].end_pos.x
        last_y = df.global.world.world_data.rivers [current_river].end_pos.y
        
        if last_x == x_pos - 1 then
           df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.river_left = false
       
        elseif last_x == x_pos + 1 then
           df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.river_right = false
       
        elseif last_y == y_pos - 1 then
           df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.river_up = false
       
        elseif last_y == y_pos + 1 then
           df.global.world.world_data.region_map [x_pos]:_displace (y_pos).flags.river_down = false
        end
      end
      
      df.global.world.world_data.rivers [current_river].path.x:erase (index)
      df.global.world.world_data.rivers [current_river].path.y:erase (index)
      
      if not river_type_updated then
        df.global.world.world_data.rivers [current_river].unk_8c:erase (index)
        df.global.world.world_data.rivers [current_river].unk_9c:erase (index)
        
      else
        df.global.world.world_data.rivers [current_river].flow:erase (index)
        df.global.world.world_data.rivers [current_river].exit_tile:erase (index)
      end
      
      df.global.world.world_data.rivers [current_river].elevation:erase (index)
      
      river_matrix [x_pos] [y_pos].path = -1
      
      if river_matrix [x_pos] [y_pos].sink == 0 then
        river_matrix [x_pos] [y_pos].color = COLOR_WHITE
        
      else
        river_matrix [x_pos] [y_pos].color = COLOR_GREY
      end
      
      last_x = x_pos
      last_y = y_pos
    end
        
    move_cursor (last_x, last_y, cache_x, cache_y)

    Focus = "River"  --  Reenable input processing
    
    Make_Biome ()
    Update (0, 0, true)
  end
  
  --==============================================================

  function BiomeManipulatorUi:riverClear ()
    local screen = dfhack.gui.getCurViewscreen ()
    river_clear_accepted = true
    screen.parent:feed_key (df.interface_key [keybindings.river_clear.key])
  end
  
  --==============================================================

  function BiomeManipulatorUi:riverTruncate ()
    local screen = dfhack.gui.getCurViewscreen ()
    river_truncate_accepted = true
    screen.parent:feed_key (df.interface_key [keybindings.river_truncate.key])
  end
  
  --==============================================================

  function BiomeManipulatorUi:riverSetEndDirection (value)
    if (string.upper (value) ~= 'E' and
        string.upper (value) ~= 'W' and
        string.upper (value) ~= 'N' and
        string.upper (value) ~= 'S') or
       (string.upper (value) == 'W' and not Is_Legal_Sink_Direction (x, y, -1, 0, current_river)) or
       (string.upper (value) == 'E' and not Is_Legal_Sink_Direction (x, y, 1, 0, current_river)) or
       (string.upper (value) == 'N' and not Is_Legal_Sink_Direction (x, y, 0, -1, current_river)) or
       (string.upper (value) == 'S' and not Is_Legal_Sink_Direction (x, y, 0, 1, current_river)) then
      dialog.showMessage ("Error!", "The character has to be one of those listed", COLOR_LIGHTRED)
    
    else      
      local last_index = #df.global.world.world_data.rivers [current_river].path.x - 1
      local last_x = x
      local last_y = y
      local end_x = df.global.world.world_data.rivers [current_river].end_pos.x
      local end_y = df.global.world.world_data.rivers [current_river].end_pos.y
      local on_map = true
      
      --  Disconnect the previous sink automatically if connected.
      --
      if end_x == last_x - 1 and end_y == last_y then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_left = false
         
      elseif end_x == last_x + 1 and end_y == last_y then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_right = false
          
      elseif end_x == last_x and end_y == last_y - 1 then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_up = false
          
      elseif end_x == last_x and end_y == last_y + 1 then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_down = false
      end
      
      if end_x >= 0 and end_x < df.global.world.worldgen.worldgen_parms.dim_x and
         end_y >= 0 and end_y < df.global.world.worldgen.worldgen_parms.dim_y then     
        river_matrix [end_x] [end_y].sink = river_matrix [end_x] [end_y].sink - 1
      
        if river_matrix [end_x] [end_y].path == -1 then
          if river_matrix [end_x] [end_y].sink == 0 then
            river_matrix [end_x] [end_y].color = COLOR_WHITE
          
          else
            river_matrix [end_x] [end_y].color = COLOR_GREY
          end
        
        else
          if river_matrix [end_x] [end_y].sink == 0 then
            river_matrix [end_x] [end_y].color = COLOR_LIGHTGREEN
          
          else
            river_matrix [end_x] [end_y].color = COLOR_GREEN
          end
        end
      end
      
      if string.upper (value) == 'W' then
        end_x = x - 1
        end_y = y
        
        on_map = end_x >= 0
        
      elseif string.upper (value) == 'E' then
        end_x = x + 1
        end_y = y
        
        on_map = end_x < df.global.world.worldgen.worldgen_parms.dim_x
        
      elseif string.upper (value) == 'N' then
        end_x = x
        end_y = y - 1
        
        on_map = end_y >= 0
        
      elseif string.upper (value) == 'S' then
        end_x = x
        end_y = y + 1
        
        on_map = end_y < df.global.world.worldgen.worldgen_parms.dim_y
      end
      
      df.global.world.world_data.rivers [current_river].end_pos.x = end_x
      df.global.world.world_data.rivers [current_river].end_pos.y = end_y
      
      if end_x == last_x - 1 and end_y == last_y then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_left = true
         
      elseif end_x == last_x + 1 and end_y == last_y then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_right = true
          
      elseif end_x == last_x and end_y == last_y - 1 then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_up = true
          
      else
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_down = true
      end
      
      if on_map then
        river_matrix [end_x] [end_y].sink = river_matrix [end_x] [end_y].sink + 1
      
        if river_matrix [end_x] [end_y].path == -1 then
          river_matrix [end_x] [end_y].color = COLOR_LIGHTCYAN
          
        else
          river_matrix [end_x] [end_y].color = COLOR_CYAN
        end
      end      
      
      Make_Biome ()
      Update (0, 0, true)
    end
  end
  
  --==============================================================

  function BiomeManipulatorUi:riverDelete ()
    local screen = dfhack.gui.getCurViewscreen ()
    river_delete_accepted = true
    screen.parent:feed_key (df.interface_key [keybindings.river_delete.key])
  end
  
  --==============================================================

  function BiomeManipulatorUi:onInput (keys)
    if keys.LEAVESCREEN_ALL then
        self:dismiss ()
    end
    
    if keys.LEAVESCREEN then
      if Focus == "Help" or
         Focus == "Animal" or
         Focus == "Plant" or
         Focus == "Cavern" or
         Focus == "Weather" or
         Focus == "Geo" or 
         Focus == "World_Map" or
         Focus == "River" then
        self.transparent = false
        Focus = "Main"
        self.subviews.pages:setSelected (1)
                
      else
        self:dismiss ()
      end
    end

    if keys [keybindings.evilness.key] and Focus == "Main" then
      dialog.showInputPrompt ("Evilness",
                              "Changing evilness to a different range will result\n" ..
                              "in all plants and animals dependent on the former\n" ..
                              "Evilness to be removed from the biome.\n" ..
                              "Any change to the Evilness value will cause that\n" ..
                              "value to be applied to all world tiles belonging\n" ..
                              "to the edited region, destroying any variation\n\n" ..
                              "Also removes any interactions associated with the\n" ..
                              "region. The ranges are:\n" ..
                              "Good: 0 - 32\n" ..
                              "Neutral: 33 - 65\n" ..
                              "Evil: 66 - 100\n" ..                               
                              "Evilness (" .. tostring (evilness) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateEvilness"))
    
    elseif keys [keybindings.evilness_single.key] and Focus == "Main" then  --  Overloaded key
      dialog.showInputPrompt ("Change Evilness of the current world tile only",
                              "Changing the evilness of the world tile to a\n" ..
                              "different range (Good/Neutral/Evil) than that\n" ..
                              "of the rest of the biome departs from how DF\n"    ..
                              "implements it naturally. It also will fail to\n" ..
                              "provide any of the plants or animals that\n" ..
                              "require the new evilness level unless manually\n" ..
                              "added to the biome region. The ranges are:\n\n" ..                               
                              "Good: 0 - 32\n" ..
                              "Neutral: 33 - 65\n" ..
                              "Evil: 66 - 100\n\n" ..                               
                              "Evilness (" .. tostring (evilness) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateEvilnessSingle"))
      
    elseif keys [keybindings.savagery.key] and Focus == "Main" then
      dialog.showInputPrompt ("Change Savagery of the current world tile",
                              "If you change the Savagery of the world tile\n" ..
                              "to Savage and the biome region did not\n" ..
                              "previously contain any Savage world tiles\n" ..
                              "you will not get any Savage only plants or\n" ..
                              "animals, but will have to add them manually.\n" ..
                              "The ranges are:\n\n" ..                               
                              "Calm: 0 - 32\n" ..
                              "Neutral: 33 - 65\n" ..
                              "Savage: 66 - 100\n\n" ..                               
                              "Savagery (" .. tostring (savagery) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateSavagery"))
    
    elseif keys [keybindings.animals.key] and  --  Overloaded key
           (Focus == "Main" or 
            Focus == "Plant" or
            Focus == "Cavern") then
      Animal_Page.Present.active = true
      Animal_Page.Absent.active = false    
      Apply_Animal_Selection (Animal_Page.Present:getSelected ())
      Focus = "Animal"
      self.subviews.pages:setSelected (2)
      
    elseif keys [keybindings.plants.key] and  --  Overloaded key
           (Focus == "Main" or 
            Focus == "Animal" or
            Focus == "Cavern") then
      Plant_Page.Present.active = true
      Plant_Page.Absent.active = false
      Apply_Plant_Selection (Plant_Page.Present:getSelected ())
      Focus = "Plant"
      self.subviews.pages:setSelected (3)
      
    elseif keys [keybindings.cavern.key] and   --  Overloaded key
           (Focus == "Main" or
            Focus == "Plant" or
            Focus == "Animal") then
      if Layer >= 0 and
         Layer <= 2 then
        Focus = "Cavern"
        local reg = df.global.world.world_data.underground_regions [region [Layer]]
        Cavern_Page.Region:setText (Fit_Right (region [Layer], 4))      
        Cavern_Page.Layer:setText (layer_image [Layer])
        
        if underground_region_type_updated then
          Cavern_Page.Water:setText (Fit_Right (tostring (reg.water), 3))
          Cavern_Page.Openness_Min:setText (Fit_Right (tostring (reg.openness_min), 3))
          Cavern_Page.Openness_Max:setText (Fit_Right (tostring (reg.openness_max), 3))
          Cavern_Page.Density_Min:setText (Fit_Right (tostring (reg.passage_density_min), 3))
          Cavern_Page.Density_Max:setText (Fit_Right (tostring (reg.passage_density_max), 3))
          
        else
          Cavern_Page.Water:setText (Fit_Right (tostring (reg.unk_7a), 3))
          Cavern_Page.Openness_Min:setText (Fit_Right (tostring (reg.unk_7e), 3))
          Cavern_Page.Openness_Max:setText (Fit_Right (tostring (reg.unk_80), 3))
          Cavern_Page.Density_Min:setText (Fit_Right (tostring (reg.unk_82), 3))
          Cavern_Page.Density_Max:setText (Fit_Right (tostring (reg.passage_density), 3))
        end
        
        self.subviews.pages:setSelected (4)        
      end
      
    elseif keys [keybindings.weather.key] and Focus == "Main" then  --  Overloaded key
      if Layer == Surface then
        Focus = "Weather"

        if reanimating_named then
          Weather_Page.Dead_Percent:setText
            (Fit_Right (tostring (df.global.world.world_data.regions [region [Surface]].dead_percentage), 3))
            
        else
          Weather_Page.Dead_Percent:setText
            (Fit_Right (tostring (df.global.world.world_data.regions [region [Surface]].unk_1e4 % 256), 3))
        end

        local List_Index = 1  --  NONE
        local Interaction_Index = -1
        
        for i, interaction in ipairs (df.global.world.interaction_instances.all) do
          if interaction.region_index == region [Surface] then
            Interaction_Index = interaction.interaction_id
            break
          end
        end
        
        for i, element in ipairs (Weather_Page.Weather_List) do
          if element.index == Interaction_Index then
            List_Index = i
            break
          end
        end
        
        Weather_Page.Current_Weather:setText (Weather_Page.Weather_List [List_Index].name)
        Weather_Page.Weather:setSelected (List_Index)
                
        self.subviews.pages:setSelected (5)
      end
      
    elseif keys [keybindings.geo.key] and Focus == "Main" then
      Focus = "Geo"
      Make_Layer (x, y)
      Geo_Page.Geo_Index:setText (Fit_Right (tostring (df.global.world.world_data.region_map [x]:_displace (y).geo_index), 4))
      
      Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List), 1)
      Geo_Page.Layer.active = true
      Geo_Page.Layer_Edit_Label.visible = true
      
      Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List), 1)
      Geo_Page.Vein.active = false
      Geo_Page.Vein_Edit_Label.visible = false
      
      self.subviews.pages:setSelected (6)
      
    elseif keys [keybindings.unrestricted.key] and Focus == "Main" then
      if not Unrestricted then
        dialog.showYesNoPrompt ("Enabling unrestricted plant and creature selection",
                                "Defaults to disabled for a reason...\n" ..
                                "When Unrestricted is True the plant and creature\n" ..
                                "selection choices list all those existing in DF\n" ..
                                "regardless of whether they make sense or not.\n" ..
                                "Using this mode is completely on the user's own\n" ..
                                "responsibility, as potential results are crashes\n" ..
                                "(probably not), plain failure to have any effect\n" ..
                                "(not unreasonable), or just stupid.\n" ..
                                "Are you sure you want to enable Unrestricted mode?",
                                COLOR_MAGENTA,
                                (function () Unrestricted = true 
                                             Main_Page.Unrestricted:setText (tostring (Unrestricted))
                                             Update (0, 0, false)
                                 end),
                                (function () end))
        
      else
        dialog.showMessage ("Leaving Terra Incognita", "You have returned to plant/creature selections within the normal DF habitat bounds.")
        Unrestricted = false
        Main_Page.Unrestricted:setText (tostring (Unrestricted))
        Update (0, 0, false)
      end    
    
    elseif keys [keybindings.floradiversity.key] and Focus == "Main" then
      dialog.showYesNoPrompt ("Floradiversity",
                              "This command assigns all plants legal to each region\n" ..
                              "in the world to be present in those regions\n" ..
                              "This will affect each " .. layer_image [Layer] .. " region.\n" ..
                              "Are you sure you want to do that?",
                              COLOR_WHITE,
                              self:callback ("Floradiversity"),
                              (function () end))
      
    elseif keys [keybindings.faunadiversity.key] and Focus == "Main" then
      dialog.showYesNoPrompt ("Faunadiversity",
                              "This command assigns all creatures legal to each region\n" ..
                              "in the world to be present in those regions\n" ..
                              "This will affect each " .. layer_image [Layer] .. " region.\n" ..
                              "Are you sure you want to do that?",
                              COLOR_WHITE,
                              self:callback ("Faunadiversity"),
                              (function () end))
      
    elseif keys [keybindings.layer.key] and Focus == "Main" then
      local Done = false
       
      while not Done do
        Layer = Layer + 1
        if Layer > 3 then
          Layer = -1
        end
         
        Done = region [Layer] ~= nil
      end
      
      Update (0, 0, false)
      
    elseif keys [keybindings.map_edit.key] and Focus == "Main" then
      Focus = "World_Map"
      self.subviews.pages:setSelected (7)
     
    elseif keys [keybindings.river.key] and Focus == "Main" then
      if movement_supported then
        Focus = "River"      
        self.subviews.pages:setSelected (8)
      
      else
        dfhack.color (COLOR_LIGHTRED)
        dfhack.println ("Sorry, but your DFHack version is too old to support a function essential to this functionality")
        dfhack.color (COLOR_RESET)
      end
      
    elseif keys [keybindings.cavern_water.key] and Focus == "Cavern" then  --  Overloaded key
      dialog.showInputPrompt ("Change Water value for cavern",
                              "Water (" .. Cavern_Page.Water.text .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateCavernWater"))
      
    elseif keys [keybindings.cavern_openness_min.key] and Focus == "Cavern" then
      dialog.showInputPrompt ("Change Openness Min value for cavern",
                              "Openness Min (" .. Cavern_Page.Openness_Min.text .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateCavernOpennessMin"))
      
    elseif keys [keybindings.cavern_openness_max.key] and Focus == "Cavern" then
      dialog.showInputPrompt ("Change Openness Max value for cavern",
                              "Openness Max (" .. Cavern_Page.Openness_Max.text .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateCavernOpennessMax"))
      
    elseif keys [keybindings.cavern_density_min.key] and Focus == "Cavern" then  --  Overloaded key
      dialog.showInputPrompt ("Change Passage Density Min value for cavern",
                              "Passage Density Min (" .. Cavern_Page.Density_Min.text .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateCavernDensityMin"))
      
    elseif keys [keybindings.cavern_density_max.key] and Focus == "Cavern" then
      dialog.showInputPrompt ("Change Passage Density Max value for cavern",
                              "Passage Density Max (" .. Cavern_Page.Density_Max.text .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateCavernDensityMax"))
     
    elseif keys [keybindings.weather_dead_percent.key] and Focus == "Weather" then
      dialog.showInputPrompt ("Change Percentage of dead vegetation for this region",
                              "Dead Vegetation (" .. Weather_Page.Dead_Percent.text .."%:",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateWeatherDeadPercent"))
         
    elseif keys [keybindings.geo_clone.key] and Focus == "Geo" then
      dialog.showYesNoPrompt ("Clone Current Geo Biome",
                              "Copy current Geo Biome for further tweaking\n" ..
                              "Note that it will not be associated with ANY World Tile\n" ..
                              "Are you sure you want to do that?",
                              COLOR_WHITE,
                              self:callback ("cloneGeoBiome"),
                              (function () end))
      
    elseif keys [keybindings.geo_update.key] and Focus == "Geo" then
      dialog.showInputPrompt ("Change Geo Biome Number",
                              "World Coordinate affected (" .. tostring (x) .. ", " .. tostring (y) ..")\n" ..
                              "New Geo Biome Number: (0 - " .. tostring (#df.global.world.world_data.geo_biomes - 1) .. "):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateGeoBiomeNumber"))
      
    elseif keys [keybindings.geo_diversity_single.key] and Focus == "Geo" then
      dialog.showYesNoPrompt ("Geo Diversity Single Geo Biome",
                              "This command assigns all minerals legal to each\n" ..
                              "layer to that layer of the current Geo Biome.\n" ..
                              "Are you sure you want to do that?",
                              COLOR_WHITE,
                              self:callback ("geoDiversitySingle"),
                              (function () end))      
      
    elseif keys [keybindings.geo_diversity_all.key] and Focus == "Geo" then
      dialog.showYesNoPrompt ("Geo Diversity All Geo Biomes",
                              "This command assigns all minerals legal to each\n" ..
                              "layer of each Geo Biome in the world to that layer.\n" ..
                              "Are you sure you want to do that?",
                              COLOR_WHITE,
                              self:callback ("geoDiversityAll"),
                              (function () end))      
          
    elseif keys [keybindings.geo_delete.key] and Focus == "Geo" and Geo_Page.Layer.active then
      local index, choice = Geo_Page.Layer:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      index = index - 1  --  DF starts lists at 0, Lua at 1...
        
      if #geo_biome.layers == 1 then
        dialog.showMessage ("Error!", "You have to retain at least one layer.\n",COLOR_LIGHTRED)
        
      else
        if index == #geo_biome.layers - 1 then
          geo_biome.layers [index - 1].bottom_height = geo_biome.layers [index].bottom_height
          
        else
          geo_biome.layers [index + 1].top_height = geo_biome.layers [index].top_height
        end

        geo_biome.layers [index]:delete ()
        geo_biome.layers:erase (index)
        
        Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
     
        Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
        Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List), 1)
      end
      
    elseif keys [keybindings.geo_split.key] and Focus == "Geo" and Geo_Page.Layer.active then
      local index, choice = Geo_Page.Layer:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      index = index - 1  --  DF starts lists at 0, Lua at 1...
        
      if #geo_biome.layers == 16 then
        dialog.showMessage ("Error!", "DF doesn't recognize more than at most 16 layers.\n",COLOR_LIGHTRED)
        
      elseif geo_biome.layers [index].top_height - geo_biome.layers [index].bottom_height == 0 then
        dialog.showMessage ("Error!", "A layer has to have a depth of at least two do donate space to a new layer.\n",COLOR_LIGHTRED)
        
      else
        geo_biome.layers:insert (index, df.world_geo_layer:new ())
        geo_biome.layers [index].type = geo_biome.layers [index + 1].type
        geo_biome.layers [index].mat_index = geo_biome.layers [index + 1].mat_index
        geo_biome.layers [index].top_height = geo_biome.layers [index + 1].top_height
        geo_biome.layers [index].bottom_height = math.ceil ((geo_biome.layers [index].top_height + geo_biome.layers [index + 1].bottom_height) / 2)
        geo_biome.layers [index + 1].top_height = geo_biome.layers [index].bottom_height - 1
        geo_biome.layers [index].vein_mat = {}
        geo_biome.layers [index].vein_nested_in = {}
        geo_biome.layers [index].vein_type = {}
        geo_biome.layers [index].vein_unk_38 = {}
          
        Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
      
        Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
        Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List), 1)
      end
      
    elseif keys [keybindings.geo_expand.key] and Focus == "Geo" and Geo_Page.Layer.active then
      local index, choice = Geo_Page.Layer:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      index = index - 1  --  DF starts lists at 0, Lua at 1...
        
      if index == #geo_biome.layers - 1 then
        dialog.showMessage ("Error!", "The lowest layer cannot be expanded.\n",COLOR_LIGHTRED)
        
      elseif geo_biome.layers [index + 1].top_height - geo_biome.layers [index + 1].bottom_height == 0 then
        dialog.showMessage ("Error!", "A layer can be expanded only if the layer below has levels to spare.\n",COLOR_LIGHTRED)
          
      else
        geo_biome.layers [index].bottom_height = geo_biome.layers [index].bottom_height - 1
        geo_biome.layers [index + 1].top_height = geo_biome.layers [index + 1].top_height - 1
          
        Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
      
        Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
        Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List), 1)
      end
      
    elseif keys [keybindings.geo_contract.key] and Focus == "Geo" and Geo_Page.Layer.active then
      local index, choice = Geo_Page.Layer:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      index = index - 1  --  DF starts lists at 0, Lua at 1...
        
      if index == #geo_biome.layers - 1 then
        dialog.showMessage ("Error!", "The lowest layer cannot be contracted.\n",COLOR_LIGHTRED)
        
      elseif geo_biome.layers [index].top_height - geo_biome.layers [index].bottom_height == 0 then
        dialog.showMessage ("Error!", "A layer can be contracted only if it has levels to spare.\n",COLOR_LIGHTRED)
          
      else
        geo_biome.layers [index].bottom_height = geo_biome.layers [index].bottom_height + 1
        geo_biome.layers [index + 1].top_height = geo_biome.layers [index + 1].top_height + 1
          
        Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
      
        Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
        Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List), 1)
      end
      
    elseif keys [keybindings.geo_morph.key] and Focus == "Geo" and Geo_Page.Layer.active then
      local index, choice = Geo_Page.Layer:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      local List = {}
      index = index - 1  --  DF starts lists at 0, Lua at 1...
                
      for i, material in ipairs (df.global.world.raws.inorganics) do
        if material.flags.SEDIMENTARY or
           material.flags.IGNEOUS_INTRUSIVE or
           material.flags.IGNEOUS_EXTRUSIVE or
           material.flags.METAMORPHIC or
           material.flags.SOIL then
             table.insert (List, {text = material.id})
        end       
      end

      guiScript.start (function ()
        local ret, idx, choice = guiScript.showListPrompt ("Choose layer material:", nil, 3, List, nil, true)
        
        if ret then
          for i, material in ipairs (df.global.world.raws.inorganics) do
            if material.id == List [idx].text then
              geo_biome.layers [index].mat_index = i
              if material.flags.SEDIMENTARY then
                geo_biome.layers [index].type = df.geo_layer_type.SEDIMENTARY
                  
              elseif material.flags.IGNEOUS_INTRUSIVE then
                geo_biome.layers [index].type = df.geo_layer_type.IGNEOUS_INTRUSIVE
                  
              elseif material.flags.IGNEOUS_EXTRUSIVE then
                geo_biome.layers [index].type = df.geo_layer_type.IGNEOUS_EXTRUSIVE
                  
              elseif material.flags.METAMORPHIC then
                geo_biome.layers [index].type = df.geo_layer_type.METAMORPHIC
                  
--                elseif material.flags.SOIL_SAND then
--                  geo_biome.layers [index].type = df.geo_layer_type.SOIL_SAND

              elseif material.flags.SOIL then
                geo_biome.layers [index].type = df.geo_layer_type.SOIL
              end
                
              if #geo_biome.layers [index].vein_mat > 0 then
                for k = 0, #geo_biome.layers [index].vein_mat - 1, -1 do                
                  geo_biome.layers [index].vein_mat:erase (k)
                  geo_biome.layers [index].vein_nested_in:erase (k)
                  geo_biome.layers [index].vein_type:erase (k)
                  geo_biome.layers [index].vein_unk_38:erase (k)
                end
              end
                
              Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
     
              Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
              Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List), 1)
                
              break
            end
          end
        end       
      end)
      
    elseif keys [keybindings.geo_add.key] and Focus == "Geo" and Geo_Page.Vein.active then
      local layer_index, choice = Geo_Page.Layer:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      local List = {}
      local Layer_Material = df.global.world.raws.inorganics [geo_biome.layers [layer_index - 1].mat_index]
      local Found
        
      for i, material in ipairs (df.global.world.raws.inorganics) do
        Found = false
          
        for k, mat in ipairs (geo_biome.layers [layer_index - 1].vein_mat) do
          if geo_biome.layers [layer_index - 1].vein_mat [k] == i then
            Found = true
            break
          end
        end
          
        if not Found then
          for k, location in ipairs (material.environment.location) do
            if (location == df.environment_type.SOIL and Layer_Material.flags.SOIL) or
               (location == df.environment_type.SOIL_OCEAN and Layer_Material.flags.SOIL_OCEAN) or  --  Redundant, covered by SOIL
               (location == df.environment_type.SOIL_SAND and Layer_Material.flags.SOIL_SAND) or    --  Redundant, covered by SOIL
               (location == df.environment_type.METAMORPHIC and Layer_Material.flags.METAMORPHIC) or
               (location == df.environment_type.SEDIMENTARY and Layer_Material.flags.SEDIMENTARY) or
               (location == df.environment_type.IGNEOUS_INTRUSIVE and Layer_Material.flags.IGNEOUS_INTRUSIVE) or
               (location == df.environment_type.IGNEOUS_EXTRUSIVE and Layer_Material.flags.IGNEOUS_EXTRUSIVE) then  -- or
              -- (location == df.environment_type.ALLUVIAL and Layer_Material.flags.ALLUVIAL) then  -- No Alluvial flag!
              Found = true
              table.insert (List, {text = material.id})
            end
          end                     
        end
          
        if not Found then
          for k, mat_index in ipairs (material.environment_spec.mat_index) do
            if mat_index == geo_biome.layers [layer_index - 1].mat_index then
              table.insert (List, {text = material.id})
              break
            end
          end
        end
      end
        
      guiScript.start (function ()
        local ret, idx, choice = guiScript.showListPrompt ("Choose vein/cluster material:", nil, 3, List, nil, true)
        if ret then
          for i, material in ipairs (df.global.world.raws.inorganics) do
            if material.id == List [idx].text then
              geo_biome.layers [layer_index - 1].vein_mat:insert ('#', i)
              geo_biome.layers [layer_index - 1].vein_nested_in:insert ('#', -1)
                
              Found = false
              for k, location in ipairs (material.environment.location) do
                if (location == df.environment_type.SOIL and Layer_Material.flags.SOIL) or
                   (location == df.environment_type.SOIL_OCEAN and Layer_Material.flags.SOIL_OCEAN) or
                   (location == df.environment_type.SOIL_SAND and Layer_Material.flags.SOIL_SAND) or
                   (location == df.environment_type.METAMORPHIC and Layer_Material.flags.METAMORPHIC) or
                   (location == df.environment_type.SEDIMENTARY and Layer_Material.flags.SEDIMENTARY) or
                   (location == df.environment_type.IGNEOUS_INTRUSIVE and Layer_Material.flags.IGNEOUS_INTRUSIVE) or
                   (location == df.environment_type.IGNEOUS_EXTRUSIVE and Layer_Material.flags.IGNEOUS_EXTRUSIVE) then  -- or
                  -- (location == df.environment_type.ALLUVIAL and Layer_Material.flags.ALLUVIAL) then  -- No Alluvial flag!
                  geo_biome.layers [layer_index - 1].vein_type:insert ('#', material.environment.type [k])
                  Found = true
                  break
                end
              end
                
              if not Found then
                for k, mat_index in ipairs (material.environment_spec.mat_index) do
                  if mat_index == geo_biome.layers [layer_index - 1].mat_index then
                    geo_biome.layers [layer_index - 1].vein_type:insert ('#', material.environment_spec.inclusion_type [k])
                    break
                  end
                end
              end
                
              geo_biome.layers [layer_index - 1].vein_unk_38:insert ('#', 50)
               
              Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
      
              Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
              Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))
                
              break
            end
          end
        end
      end)
      
    elseif keys [keybindings.geo_remove.key] and Focus == "Geo" and Geo_Page.Vein.active then
      local layer_index, layer_choice = Geo_Page.Layer:getSelected ()
      local index, choice = Geo_Page.Vein:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
        
      if #geo_biome.layers [layer_index - 1].vein_mat == 0 then
        dialog.showMessage ("Error!", "Cannot remove non existent entries.\n",COLOR_LIGHTRED)
        
      else
        index = index - 1  --  C vs Lua ...
        local vein_nested_in_length = #geo_biome.layers [layer_index - 1].vein_nested_in - 1
          
        for i = 0, vein_nested_in_length do
          if geo_biome.layers [layer_index - 1].vein_nested_in [vein_nested_in_length - i] == index then
            geo_biome.layers [layer_index - 1].vein_mat:erase (vein_nested_in_length - i)
            geo_biome.layers [layer_index - 1].vein_nested_in:erase (vein_nested_in_length - i)
            geo_biome.layers [layer_index - 1].vein_type:erase (vein_nested_in_length - i)
            geo_biome.layers [layer_index - 1].vein_unk_38:erase (vein_nested_in_length - i)
          end
        end
          
        geo_biome.layers [layer_index - 1].vein_mat:erase (index)
        geo_biome.layers [layer_index - 1].vein_nested_in:erase (index)
        geo_biome.layers [layer_index - 1].vein_type:erase (index)
        geo_biome.layers [layer_index - 1].vein_unk_38:erase (index)
                          
        Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
      
        Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
        Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))
      end
      
    elseif keys [keybindings.geo_nest.key] and Focus == "Geo" and Geo_Page.Vein.active then      
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      local layer_index, layer_choice = Geo_Page.Layer:getSelected ()
      
      if #geo_biome.layers [layer_index - 1].vein_mat ~= 0 then
        local index, choice = Geo_Page.Vein:getSelected ()
        index = index - 1  --  C vs Lua ...
        
        local List = {}
        local Found
        
        for i, material in ipairs (df.global.world.raws.inorganics) do
          for k, mat_index in ipairs (material.environment_spec.mat_index) do
            Found = false
            if mat_index == geo_biome.layers [layer_index - 1].vein_mat [index] then
              for l, nested_in in ipairs (geo_biome.layers [layer_index - 1].vein_nested_in) do
                if nested_in == index and
                   geo_biome.layers [layer_index - 1].vein_mat [l] == i then
                   Found = true
                   break
                end
              end              

              if not Found then
                table.insert (List, {text = material.id})
              end
            end
          end
        end

        guiScript.start (function ()
          local ret, idx, choice = guiScript.showListPrompt ("Choose vein/cluster inclusion material:", nil, 3, List, nil, true)
          if ret then
            for i, material in ipairs (df.global.world.raws.inorganics) do
              if material.id == List [idx].text then
                geo_biome.layers [layer_index - 1].vein_mat:insert ('#', i)
                geo_biome.layers [layer_index - 1].vein_nested_in:insert ('#', index)
                
                for k, mat_index in ipairs (material.environment_spec.mat_index) do
                  if mat_index == geo_biome.layers [layer_index - 1].vein_mat [index] then                  
                    geo_biome.layers [layer_index - 1].vein_type:insert ('#', material.environment_spec.inclusion_type [k])
                    break
                  end
                end
                
                geo_biome.layers [layer_index - 1].vein_unk_38:insert ('#', 50)
         
                  Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
      
                Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
                Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))
                
                break
              end
            end
          end
        end)
      end
      
    elseif keys [keybindings.geo_proportion.key] and Focus == "Geo" and Geo_Page.Vein.active then
      local layer_index, layer_choice = Geo_Page.Layer:getSelected ()
      local index, choice = Geo_Page.Vein:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
        
      if #geo_biome.layers [layer_index - 1].vein_mat == 0 then
        dialog.showMessage ("Error!", "Cannot modify non existent entries.\n",COLOR_LIGHTRED)
        
      else
        index = index - 1  --  C vs Lua ...
        
        dialog.showInputPrompt ("Change Proportion for the Vein/Cluster/Inclusion",
                                "Proportion (percentage of max) (" .. tostring (geo_biome.layers [layer_index - 1].vein_unk_38 [index]) .."):",
                                COLOR_WHITE,
                                "",
                                self:callback ("updateGeoProportion"))
      end

    elseif keys [keybindings.geo_full.key] and Focus == "Geo" and Geo_Page.Vein.active then
      local layer_index, choice = Geo_Page.Layer:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]
      Geo_Diversity_Layer (geo_biome, layer_index - 1)
                  
      Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
      
      Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
      Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))
    
    elseif keys [keybindings.geo_clear.key] and Focus == "Geo" and Geo_Page.Vein.active then
      local layer_index, layer_choice = Geo_Page.Layer:getSelected ()
      local geo_biome = df.global.world.world_data.geo_biomes [tonumber (Geo_Page.Geo_Index.text)]

      while #geo_biome.layers [layer_index - 1].vein_mat > 0 do
        geo_biome.layers [layer_index - 1].vein_mat:erase (#geo_biome.layers [layer_index - 1].vein_mat - 1)
        geo_biome.layers [layer_index - 1].vein_nested_in:erase (#geo_biome.layers [layer_index - 1].vein_mat) --  Shrunk 1 above
        geo_biome.layers [layer_index - 1].vein_type:erase (#geo_biome.layers [layer_index - 1].vein_mat)
        geo_biome.layers [layer_index - 1].vein_unk_38:erase (#geo_biome.layers [layer_index - 1].vein_mat)
      end   
        
      Make_Geo_Layer (tonumber (Geo_Page.Geo_Index.text))
      
      Geo_Page.Layer:setChoices (Make_List (Geo_Page.Layer_List))      
      Geo_Page.Vein:setChoices (Make_List (Geo_Page.Vein_List))
      
    elseif keys [keybindings.map_adopt_biome.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Adopt neighboring tile's Biome/Region to current world tile",
                              "Changes the biome and region of the current world tile to\n" ..
                              "match those of a neighbor. Note that DF does not generate\n" ..
                              "regions with diagonal only access, and potential effects\n" ..
                              "of such connections are unknown. The input indicates the\n" ..
                              "Relative location of the tile to adopt from. Legal values:\n\n" ..                               
                              "Northwest: 7 North: 8 Northeast: 9\n" ..
                              "West:      4          East       6\n" ..
                              "Southwest: 1 South: 2 Southeast: 3\n\n",                              
                              COLOR_WHITE,
                              "",
                              self:callback ("adoptBiome"))
                              
    elseif keys [keybindings.map_new_region.key] and Focus == "World_Map" then
      dialog.showYesNoPrompt("Make a new Region out of the current world tile",
                             "Note that the resulting region will be devoid of plants\n" ..
                             "and animals, so you have to add those manually afterwards.\n" ..
                             "The Region's type and implicit evilness association will\n" ..
                             "be taken from the current values of the current world tile.\n" ..
                             "Have you prepared the world tile so it's ready for this?",
                             COLOR_WHITE,
                             self:callback ("newRegion"),
                             (function () end))
    
    elseif keys [keybindings.map_elevation.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Elevation of the current world tile",
                              "Changing the elevation of the world tile to a\n" ..
                              "value that changes the biome (mountain/normal/ocean)\n" ..
                              "will cause the tile to fail to belong to the same\n" ..
                              "broad biome as the rest of the region. This\n" ..
                              "departs from how DF implements it naturally.\n" ..
                              "It will also fail to provide any of the plants/animals\n" ..
                              "that would populate that biome exclusively, unless manually\n" ..
                              "added to the biome region. The ranges are:\n\n" ..                               
                              "Ocean: 0 - 99\n" ..
                              "Normal: 100 - 149\n" ..
                              "Mountain: 150 - 250\n\n" ..                               
                              "Elevation (" .. tostring (df.global.world.world_data.region_map [x]:_displace (y).elevation) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateElevation"))
                              
    elseif keys [keybindings.map_rainfall.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Rainfall of the current world tile",
                              "Changing the rainfall of the world tile to a value\n" ..
                              "that changes the biome to a type not belonging\n" ..
                              "to the same broad biome as the region departs from\n" ..
                              "how DF implements it naturally. It will also fail to\n" ..
                              "provide the additional plants/animals that would\n" ..
                              "normally populate that biome, unless manually added\n" ..
                              "to the biome region. Note that this issue also\n" ..
                              "occurs if adding a biome to a matching region that\n" ..
                              "did not previously contain that biome. Also note\n" ..
                              "that Vegetation should normally have the same value\n" ..
                              "as Rainfall.\n" ..
                              "The range is: 0 - 100\n\n" ..                             
                              "Rainfall (" .. tostring (df.global.world.world_data.region_map [x]:_displace (y).rainfall) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateRainfall"))
                              
    elseif keys [keybindings.map_vegetation.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Vegetation of the current world tile",
                              "Changing the vegetation of the world tile to a value\n" ..
                              "that changes the biome to a type not belonging\n" ..
                              "to the same broad biome as the region departs from\n" ..
                              "how DF implements it naturally. It will also fail to\n" ..
                              "provide the additional plants/animals that would\n" ..
                              "normally populate that biome, unless manually added\n" ..
                              "to the biome region. Note that this issue also\n" ..
                              "occurs if adding a biome to a matching region that\n" ..
                              "did not previously contain that biome. Also note\n" ..
                              "that Rainfall should normally have the same value\n" ..
                              "as Vegetation.\n" ..
                              "The range is: 0 - 100\n\n" ..                             
                              "Vegetation (" .. tostring (df.global.world.world_data.region_map [x]:_displace (y).vegetation) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateVegetation"))
                              
    elseif keys [keybindings.map_temperature.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Temperature of the current world tile",
                              "Changing the temperature of the world tile to a value\n" ..
                              "that changes the biome to a type not belonging\n" ..
                              "to the same broad biome as the region departs from\n" ..
                              "how DF implements it naturally. It will also fail to\n" ..
                              "provide the additional plants/animals that would\n" ..
                              "normally populate that biome, unless manually added\n" ..
                              "to the biome region. Note that this issue also\n" ..
                              "occurs if adding a biome to a matching region that\n" ..
                              "did not previously contain that biome.\n\n" ..                               
                              "The range is -1000 - 1000\n\n" ..                               
                              "Temperature (" .. tostring (df.global.world.world_data.region_map [x]:_displace (y).temperature) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateTemperature"))
                              
    elseif keys [keybindings.map_evilness.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Evilness of the current world tile",
                              "Changing the evilness of the world tile to a\n" ..
                              "different range (Good/Neutral/Evil) than that\n" ..
                              "of the rest of the biome departs from how DF\n"    ..
                              "implements it naturally. It also will fail to\n" ..
                              "provide any of the plants or animals that\n" ..
                              "require the new evilness level unless manually\n" ..
                              "added to the biome region. The ranges are:\n\n" ..                               
                              "Good: 0 - 32\n" ..
                              "Neutral: 33 - 65\n" ..
                              "Evil: 66 - 100\n\n" ..                               
                              "Evilness (" .. tostring (evilness) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateEvilnessSingle"))
                              
    elseif keys [keybindings.map_drainage.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Drainage of the current world tile",
                              "Changing the drainage of the world tile to a value\n" ..
                              "that changes the biome to a type not belonging\n" ..
                              "to the same broad biome as the region departs from\n" ..
                              "how DF implements it naturally. It will also fail to\n" ..
                              "provide the additional plants/animals that would\n" ..
                              "normally populate that biome, unless manually added\n" ..
                              "to the biome region. Note that this issue also\n" ..
                              "occurs if adding a biome to a matching region that\n" ..
                              "did not previously contain that biome.\n" ..
                              "The range is: 0 - 100\n\n" ..                             
                              "Drainage (" .. tostring (df.global.world.world_data.region_map [x]:_displace (y).drainage) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateDrainage"))
                              
    elseif keys [keybindings.map_volcanism.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Volcanism of the current world tile",
                              "Changing the volcanism of the world tile is of a\n" ..
                              "doubtful value, as the parameter does not affect\n" ..
                              "biomes, and the volcanoes and geo biomes have\n" ..
                              "been generated.\n" ..
                              "The range is: 0 - 100\n\n" ..                             
                              "Volcanism (" .. tostring (df.global.world.world_data.region_map [x]:_displace (y).volcanism) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateVolcanism"))
                              
    elseif keys [keybindings.map_savagery.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Savagery of the current world tile",
                              "If you change the Savagery of the world tile\n" ..
                              "to Savage and the biome region did not\n" ..
                              "previously contain any Savage world tiles\n" ..
                              "you will not get any Savage only plants or\n" ..
                              "animals, but will have to add them manually.\n" ..
                              "The ranges are:\n\n" ..                               
                              "Calm: 0 - 32\n" ..
                              "Neutral: 33 - 65\n" ..
                              "Savage: 66 - 100\n\n" ..                               
                              "Savagery (" .. tostring (savagery) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateSavagery"))
    
    elseif keys [keybindings.map_salinity.key] and Focus == "World_Map" then
      dialog.showInputPrompt ("Change Salinity of the current world tile",
                              "Changing the Salinity of the world tile to a value\n" ..
                              "that changes the biome to a type not belonging\n" ..
                              "to the same broad biome as the region departs from\n" ..
                              "how DF implements it naturally. It will also fail to\n" ..
                              "provide the additional plants/animals that would\n" ..
                              "normally populate that biome, unless manually added\n" ..
                              "to the biome region.\n" ..
                              "The range is: 0 - 100\n\n" ..                             
                              "Salinity (" .. tostring (df.global.world.world_data.region_map [x]:_displace (y).salinity) .."):",
                              COLOR_WHITE,
                              "",
                              self:callback ("updateSalinity"))
                                    
    elseif keys [keybindings.map_biome.key] and Focus == "World_Map" then
      local is_possible_tropical_area_by_latitude, is_tropical_area_by_latitude = 
        check_tropicality (y,
                           df.global.world.worldgen.worldgen_parms.dim_y,
                           0,  --  Disable when no pole.
                           df.global.world.worldgen.worldgen_parms.pole)

      dialog.showInputPrompt ("Change Biome without changing region",
                             "Warning. It's probably better to create new regions or expand\n" ..
                             "existing ones than to force existing regions to contain\n" ..
                             "biomes incompatible with the region's broad biome type, so\n" ..
                             "if you change the biome to an inconsistent type you ought to\n" ..
                             "make a new region out of it.\n" ..
                             "Select a new biome from the list of legal alternatives.\n" ..
                             "Note that plants/animals for the biome have to be added\n" ..
                             "manually, and that selecting a biome that is not within\n" ..
                             "those belonging to the region's broad biome departs from\n" ..
                             "DF's normal restrictions.\n\n" ..
                             supported_biome_list (is_possible_tropical_area_by_latitude,
                                                   is_tropical_area_by_latitude,
                                                   df.global.world.worldgen.worldgen_parms.pole,
                                                   y) .. 
                                            "Biome:",
                                            COLOR_WHITE,
                                            "",
                                            self:callback ("updateBiome"))
               
    elseif keys [keybindings.river_select.key] and Focus == "River" and
           river_matrix [x] [y].path ~= -1 then
      if current_river == -1 then
        dialog.showYesNoPrompt("Selects the river in the current world tile for editing",
                               "Do you want to select this river?",
                               COLOR_WHITE,
                               self:callback ("riverSelect"),
                               (function () end))
      else
        dialog.showYesNoPrompt("Selects the river in the current world tile for editing",
                               "The currently selected river will be replaced.\n" ..
                               "Do you want to select this river?",
                               COLOR_WHITE,
                               self:callback ("riverSelect"),
                               (function () end))
      end
    
    elseif keys [keybindings.river_brook.key] and Focus == "River" and
           river_matrix [x] [y].path ~= -1 then
      dialog.showYesNoPrompt("Toggles the Brook/Stream indicator of the current world tile",
                             "Do you want to toggle the flag?",
                             COLOR_WHITE,
                             self:callback ("riverBrook"),
                             (function () end))
           
    elseif keys [keybindings.river_flow.key] and Focus == "River" and
           river_matrix [x] [y].path ~= -1 then
      dialog.showInputPrompt ("Change the flow of the current tile",
                              "The width of the river is (flow / 40000 * 46) + 1 with a\n" ..
                              "minimum width of 4 and a maximum of 47. DF uses specific\n" ..
                              "names for rivers within different flow ranges:\n" ..
                              "Stream:       < 5000\n" ..
                              "Minor River:    5000 -  9999\n" ..
                              "River:         10000 - 19999\n" ..
                              "Major River: > 19999\n" ..
                              "Brooks tend to have a flow of 0, but it is a separate flag\n" ..
                              "(is_brook) in the world tile that controls this,\n" ..
                              "allowing for very wide brooks.\n" ..
                              "Supported range: 0 - 99999\n\n",
                                            COLOR_WHITE,
                                            "",
                                            self:callback ("riverFlow"))
     
    elseif keys [keybindings.river_exit.key] and Focus == "River" and
           river_matrix [x] [y].path ~= -1 then
      dialog.showInputPrompt ("Change the river exit mid level tile",
                              "This parameter specifies which mid level tile along the\n" ..
                              "world tile edge the river exits the world tile. The\n" ..
                              "exiting side is determined by the river's course.\n" ..
                              "There are 16 tiles along the edge, so a value of 8\n" ..
                              "means the river exits the world tile just past the\n" ..
                              "middle of the edge.\n" ..
                              "Legal range: 0 - 15\n\n",
                                            COLOR_WHITE,
                                            "",
                                            self:callback ("riverExit"))
           
    elseif keys [keybindings.river_elevation.key] and Focus == "River" and
           river_matrix [x] [y].path ~= -1 then
      dialog.showInputPrompt ("Change the elevation of the river",
                              "This parameter specifies the elevation of the river.\n" ..
                              "An elevation lower than that of the world tile tends\n" ..
                              "to result in a river valley forming around the river.\n" ..
                              "Legal range: 0 - 250\n\n",
                                            COLOR_WHITE,
                                            "",
                                            self:callback ("riverElevation"))
                                            
    elseif keys [keybindings.river_clear.key] and Focus == "River" and
           River_Page.Clear_Course.text_pen == COLOR_LIGHTBLUE then
      if not river_clear_accepted then
        dialog.showYesNoPrompt("Removes the whole river course except the sink",
                               "Note that you have to add at least one tile to\n" ..
                               "the river to be allowed to select a new one as\n" ..
                               "a river with only a sink cannot be selected again.\n" ..
                               "Do you want to remove the course?",
                               COLOR_WHITE,
                               self:callback ("riverClear"),
                               (function () end))
      else
        river_clear_accepted = false
        River_Truncate (current_river, 0)
      end
                             
    elseif keys [keybindings.river_truncate.key] and Focus == "River" and
           River_Page.Truncate_Course.text_pen == COLOR_LIGHTBLUE then
      if not river_truncate_accepted then
        dialog.showYesNoPrompt("Removes the whole river course from here except the sink",
                               "This will remove the river's course from the currently\n"  ..
                               "selected tile onwards, except for the sink.\n" ..
                               "Note that you have to add or keep at least one tile of\n" ..
                               "the river to be allowed to select a new one as\n" ..
                               "a river with only a sink cannot be selected again.\n" ..
                               "Do you want to truncate the course?",
                               COLOR_WHITE,
                               self:callback ("riverTruncate"),
                               (function () end))
      else
        river_truncate_accepted = false
    
        for i, x_pos in ipairs (df.global.world.world_data.rivers [current_river].path.x) do
          if x_pos == x and
             df.global.world.world_data.rivers [current_river].path.y [i] == y then         
            River_Truncate (current_river, i)
            break
          end
        end
      end
           
    elseif keys [keybindings.river_add.key] and Focus == "River" then
      local previous_x
      local previous_y
      local previous_index = #df.global.world.world_data.rivers [current_river].path.x - 1
      
      if previous_index ~= -1 then
        previous_x = df.global.world.world_data.rivers [current_river].path.x [previous_index]
        previous_y = df.global.world.world_data.rivers [current_river].path.y [previous_index]
      end
      
      df.global.world.world_data.rivers [current_river].path.x:insert ('#', x)
      df.global.world.world_data.rivers [current_river].path.y:insert ('#', y)
      
      if not river_type_updated then
        if #df.global.world.world_data.rivers [current_river].path.x == 1 then
          df.global.world.world_data.rivers [current_river].unk_8c:insert ('#', 0)
        else
          df.global.world.world_data.rivers [current_river].unk_8c:insert 
            ('#', df.global.world.world_data.rivers [current_river].unk_8c [previous_index])
        end
      
        df.global.world.world_data.rivers [current_river].unk_9c:insert ('#', 8)
        df.global.world.world_data.rivers [current_river].elevation:insert 
          ('#', df.global.world.world_data.region_map [x]:_displace (y).elevation)
        
        df.global.world.world_data.region_map [x]:_displace (y).flags.is_brook =
          df.global.world.world_data.rivers [current_river].unk_8c [previous_index + 1] == 0
      
      else
        if #df.global.world.world_data.rivers [current_river].path.x == 1 then
          df.global.world.world_data.rivers [current_river].flow:insert ('#', 0)
        else
          df.global.world.world_data.rivers [current_river].flow:insert 
            ('#', df.global.world.world_data.rivers [current_river].flow [previous_index])
        end
      
        df.global.world.world_data.rivers [current_river].exit_tile:insert ('#', 8)
        df.global.world.world_data.rivers [current_river].elevation:insert 
          ('#', df.global.world.world_data.region_map [x]:_displace (y).elevation)
        
        df.global.world.world_data.region_map [x]:_displace (y).flags.is_brook =
          df.global.world.world_data.rivers [current_river].flow [previous_index + 1] == 0
      end
      
      df.global.world.world_data.region_map [x]:_displace (y).flags.has_river = true
      
      if #df.global.world.world_data.rivers [current_river].path.x > 1 then
        if previous_x < x then
          df.global.world.world_data.region_map [x]:_displace (y).flags.river_left = true
          df.global.world.world_data.region_map [previous_x]:_displace (previous_y).flags.river_right = true
          
        elseif previous_x > x then
          df.global.world.world_data.region_map [x]:_displace (y).flags.river_right = true
          df.global.world.world_data.region_map [previous_x]:_displace (previous_y).flags.river_left = true
          
        elseif previous_y < y then
          df.global.world.world_data.region_map [x]:_displace (y).flags.river_up = true
          df.global.world.world_data.region_map [previous_x]:_displace (previous_y).flags.river_down = true
          
        else
          df.global.world.world_data.region_map [x]:_displace (y).flags.river_down = true
          df.global.world.world_data.region_map [previous_x]:_displace (previous_y).flags.river_up = true
        end
      end
      
      if df.global.world.world_data.feature_map [math.floor (x / 16)]:_displace (math.floor (y / 16)).features then
        df.global.world.world_data.feature_map [math.floor (x / 16)]:_displace (math.floor (y / 16)).features.
          feature_init [x % 16] [y % 16]:insert ('#', df.feature_init_outdoor_riverst:new())
      end
      
      --  Hook up the sink automatically if adjacent.
      --
      if df.global.world.world_data.rivers [current_river].end_pos.x == x - 1 and
         df.global.world.world_data.rivers [current_river].end_pos.y == y then
        df.global.world.world_data.region_map [x]:_displace (y).flags.river_left = true
         
      elseif df.global.world.world_data.rivers [current_river].end_pos.x == x + 1 and
             df.global.world.world_data.rivers [current_river].end_pos.y == y then
        df.global.world.world_data.region_map [x]:_displace (y).flags.river_right = true
          
      elseif df.global.world.world_data.rivers [current_river].end_pos.x == x and
             df.global.world.world_data.rivers [current_river].end_pos.y == y - 1 then
        df.global.world.world_data.region_map [x]:_displace (y).flags.river_up = true
          
      elseif df.global.world.world_data.rivers [current_river].end_pos.x == x and
             df.global.world.world_data.rivers [current_river].end_pos.y == y + 1 then
        df.global.world.world_data.region_map [x]:_displace (y).flags.river_down = true
      
      elseif df.global.world.world_data.rivers [current_river].end_pos.x == x and  --  The sink is overwritten. Move it out of the way.
             df.global.world.world_data.rivers [current_river].end_pos.y == y then
        river_matrix [x] [y].sink = river_matrix [x] [y].sink - 1
        df.global.world.world_data.rivers [current_river].end_pos.x = -1
        df.global.world.world_data.rivers [current_river].end_pos.y = -1
      end
      
      river_matrix [x] [y].path = current_river      
      river_matrix [x] [y].color = COLOR_LIGHTBLUE
      
      Make_Biome ()
      Update (0, 0, true)
      
    elseif keys [keybindings.river_set_sink.key] and Focus == "River" then
      local last_index = #df.global.world.world_data.rivers [current_river].path.x - 1
      local last_x = df.global.world.world_data.rivers [current_river].path.x [last_index]
      local last_y = df.global.world.world_data.rivers [current_river].path.y [last_index]
      local end_x = df.global.world.world_data.rivers [current_river].end_pos.x
      local end_y = df.global.world.world_data.rivers [current_river].end_pos.y
      
      --  Disconnect the previous sink automatically if connected.
      --
      if end_x == last_x - 1 and end_y == last_y then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_left = false
         
      elseif end_x == last_x + 1 and end_y == last_y then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_right = false
          
      elseif end_x == last_x and end_y == last_y - 1 then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_up = false
          
      elseif end_x == last_x and end_y == last_y + 1 then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_down = false
      end
      
      if end_x >= 0 and end_x < df.global.world.worldgen.worldgen_parms.dim_x and
         end_y >= 0 and end_y < df.global.world.worldgen.worldgen_parms.dim_y then
        river_matrix [end_x] [end_y].sink = river_matrix [end_x] [end_y].sink - 1
      
        if river_matrix [end_x] [end_y].path == -1 then
          if river_matrix [end_x] [end_y].sink == 0 then
            river_matrix [end_x] [end_y].color = COLOR_WHITE
          
          else
            river_matrix [end_x] [end_y].color = COLOR_GREY
          end
        
        else
          if river_matrix [end_x] [end_y].sink == 0 then
            river_matrix [end_x] [end_y].color = COLOR_LIGHTGREEN
          
          else
            river_matrix [end_x] [end_y].color = COLOR_GREEN
          end
        end
      end
      
      df.global.world.world_data.rivers [current_river].end_pos.x = x
      df.global.world.world_data.rivers [current_river].end_pos.y = y
      
      if x == last_x - 1 and y == last_y then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_left = true
         
      elseif x == last_x + 1 and y == last_y then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_right = true
          
      elseif x == last_x and y == last_y - 1 then
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_up = true
          
      else
        df.global.world.world_data.region_map [last_x]:_displace (last_y).flags.river_down = true
      end
      
      river_matrix [x] [y].sink = river_matrix [x] [y].sink + 1
      
      if river_matrix [x] [y].path == -1 then
        river_matrix [x] [y].color = COLOR_LIGHTCYAN
      else
        river_matrix [x] [y].color = COLOR_CYAN
      end
      
      Make_Biome ()
      Update (0, 0, true)
      
    elseif keys [keybindings.river_set_sink_direction.key] and Focus == "River" then
      local directions = ""
      
      if Is_Legal_Sink_Direction (x, y, -1, 0, current_river) then
        directions = directions .. "W: West\n"
      end
      
      if Is_Legal_Sink_Direction (x, y, 1, 0, current_river) then
        directions = directions .. "E: East\n"
      end

      if Is_Legal_Sink_Direction (x, y, 0, -1, current_river) then
        directions = directions .. "N: North\n"
      end
      
      if Is_Legal_Sink_Direction (x, y, 0, 1, current_river) then
        directions = directions .. "S: South\n"
      end
 
      dialog.showInputPrompt ("Set the river sink in the indicated direction",
                              "This command is needed if the sink is to be\n" ..
                              "located off the border, but can be used from\n" ..
                              "the last river tile otherwise as well.\n" ..                              
                              "Legal directions for this tile are:\n" ..
                              directions ..
                              "\nEnter the character indicating the direction",
                                            COLOR_WHITE,
                                            "",
                                            self:callback ("riverSetEndDirection"))
 
    elseif keys [keybindings.river_delete.key] and Focus == "River" then
      if not river_delete_accepted then
        dialog.showYesNoPrompt("Deletes the river from play",
                               "Once deleted the river cannot be restored, although\n" ..
                               "a new one can be created.\n" ..
                               "Do you want to delete the river?",
                               COLOR_WHITE,
                               self:callback ("riverDelete"),
                               (function () end))
      else
        river_delete_accepted = false
        River_Truncate (current_river, 0)
        local end_x = df.global.world.world_data.rivers [current_river].end_pos.x
        local end_y = df.global.world.world_data.rivers [current_river].end_pos.y
        
        if end_x >= 0 and end_x < df.global.world.worldgen.worldgen_parms.dim_x and
           end_y >= 0 and end_y < df.global.world.worldgen.worldgen_parms.dim_y then
          river_matrix [end_x] [end_y].sink = river_matrix [end_x] [end_y].sink - 1

          if river_matrix [end_x] [end_y].path == -1 then
            if river_matrix [end_x] [end_y].sink == 0 then
              river_matrix [end_x] [end_y].color = COLOR_WHITE
              
            else
              river_matrix [end_x] [end_y].color = COLOR_GREY
            end
            
          else
            if river_matrix [end_x] [end_y].sink == 0 then
              river_matrix [end_x] [end_y].color = COLOR_LIGHTGREEN
              
            else
              river_matrix [end_x] [end_y].color = COLOR_GREEN
            end
          end          
        end
        
        df.global.world.world_data.rivers [current_river].end_pos.x = -1
        df.global.world.world_data.rivers [current_river].end_pos.y = -1
        
        River_Page.Number:setText ("")
        River_Page.Name:setText ("")
        current_river = -1

        Make_Biome ()
        Update (0, 0, true)        
      end
      
    elseif keys [keybindings.river_new.key] and Focus == "River" then
      local river = df.world_river:new ()
      Assign_River_Name (river.name)
      river.path.x:insert ('#', x)
      river.path.y:insert ('#', y)
      
      if not river_type_updated then
        river.unk_8c:insert ('#', 0)
        river.unk_9c:insert ('#', 8)
      else
        river.flow:insert ('#', 0)
        river.exit_tile:insert ('#', 8)
      end
      
      river.elevation:insert ('#', df.global.world.world_data.region_map [x]:_displace (y).elevation)
      
      river.end_pos.x = -1
      river.end_pos.y = -1
      
      df.global.world.world_data.region_map [x]:_displace (y).flags.is_brook = true
      df.global.world.world_data.region_map [x]:_displace (y).flags.has_river = true
            
      if df.global.world.world_data.feature_map [math.floor (x / 16)]:_displace (math.floor (y / 16)).features then
        df.global.world.world_data.feature_map [math.floor (x / 16)]:_displace (math.floor (y / 16)).features.
          feature_init [x % 16] [y % 16]:insert ('#', df.feature_init_outdoor_riverst:new())
      end
      
      current_river = #df.global.world.world_data.rivers
      df.global.world.world_data.rivers:insert ('#', river)
      
      River_Page.Number:setText (Fit_Right (tostring (current_river), 6))
      River_Page.Name:setText (dfhack.TranslateName (river.name, true))
      
      river_matrix [x] [y].path = current_river      
      river_matrix [x] [y].color = COLOR_LIGHTBLUE
      
      Make_Biome ()
      Update (0, 0, true)      
      
    elseif keys [keybindings.river_wipe_lost.key] and Focus == "River" and
           lost_rivers_present and current_river == -1 then
           dfhack.println ("wipe lost called")
      for i, river in ipairs (df.global.world.world_data.rivers) do
        if #river.path.x == 0 and
           river.end_pos.x ~= -1 and
           river.end_pos.y ~= -1 then
           dfhack.println ("lost found")
          if river.end_pos.x >= 0 and river.end_pos.x < df.global.world.worldgen.worldgen_parms.dim_x and
             river.end_pos.y >= 0 and river.end_pos.y < df.global.world.worldgen.worldgen_parms.dim_y then             
            river_matrix [river.end_pos.x] [river.end_pos.y].sink = river_matrix [river.end_pos.x] [river.end_pos.y].sink - 1
            
            if river_matrix [river.end_pos.x] [river.end_pos.y].path == -1 then
              if river_matrix [river.end_pos.x] [river.end_pos.y].sink == 0 then
                river_matrix [river.end_pos.x] [river.end_pos.y].color = COLOR_WHITE
                
              else
                river_matrix [river.end_pos.x] [river.end_pos.y].color = COLOR_GREY
              end
              
            else
              if Is_River_Consistent (df.global.world.world_data.rivers [river_matrix [river.end_pos.x] [river.end_pos.y].path]) then
                if river_matrix [river.end_pos.x] [river.end_pos.y].sink == 0 then
                  river_matrix [river.end_pos.x] [river.end_pos.y].color = COLOR_LIGHTGREEN                
                  
                else
                  river_matrix [river.end_pos.x] [river.end_pos.y].color = COLOR_GREEN
                end
                
              else
                river_matrix [river.end_pos.x] [river.end_pos.y].color = COLOR_LIGHTRED
              end
            end
          end
          
          river.end_pos.x = -1
          river.end_pos.y = -1          
        end
      end
      
      lost_rivers_present = false
      Make_Biome ()
      Update (0, 0, true)      
     
    elseif keys [keybindings.next_edit.key] then
      if Focus == "Main" then
        Main_Page.Grid_Visibility [Main_Page.Grid_Visibility_Index].visible = false
        
        Main_Page.Grid_Visibility_Index = Main_Page.Grid_Visibility_Index + 1
        if Main_Page.Grid_Visibility_Index > #Main_Page.Grid_Visibility then
          Main_Page.Grid_Visibility_Index = 1
        end
        
        Main_Page.Grid_Visibility [Main_Page.Grid_Visibility_Index].visible = true
        Main_Page.Map_Label:setText (Main_Page.Grid_Label [Main_Page.Grid_Visibility_Index])
        
      elseif Focus == "Animal" then
        if Animal_Page.Present.active then
          Animal_Page.Present.active = false
          Animal_Page.Absent.active = true
          
          for i, element in ipairs (Animal_Page.Animal_Visible_List) do
            element.visible = false
          end
          
        else
          Animal_Page.Present.active = true
          Animal_Page.Absent.active = false
          
          Apply_Animal_Selection (Animal_Page.Present:getSelected ())
        end
        
      elseif Focus == "Plant" then
        if Plant_Page.Present.active then
          Plant_Page.Present.active = false
          Plant_Page.Absent.active = true
          
          for i, element in ipairs (Plant_Page.Plant_Visible_List) do
            element.visible = false
          end
          
        else
          Plant_Page.Present.active = true
          Plant_Page.Absent.active = false
          
          Apply_Plant_Selection (Plant_Page.Present:getSelected ())
        end
    
      elseif Focus == "Geo" then
        if Geo_Page.Layer.active then
          Geo_Page.Layer.active = false
          Geo_Page.Vein.active = true
          Geo_Page.Layer_Edit_Label.visible = false
          Geo_Page.Vein_Edit_Label.visible = true
          
        else
          Geo_Page.Layer.active = true
          Geo_Page.Vein.active = false
          Geo_Page.Layer_Edit_Label.visible = true
          Geo_Page.Vein_Edit_Label.visible = false
        end
        
      elseif Focus == "Help" then
        Help_Page.Visibility_List [Help_Page.Focus].visible = false
        
        if Help_Page.Focus == #Help_Page.Visibility_List then
          Help_Page.Focus = 1
          
        else
        Help_Page.Focus = Help_Page.Focus + 1
        end
        
        Help_Page.Visibility_List [Help_Page.Focus].visible = true
      end
      
    elseif keys [keybindings.prev_edit.key] then
      if Focus == "Main" then
        Main_Page.Grid_Visibility [Main_Page.Grid_Visibility_Index].visible = false
        
        Main_Page.Grid_Visibility_Index = Main_Page.Grid_Visibility_Index - 1
        if Main_Page.Grid_Visibility_Index == 0 then
          Main_Page.Grid_Visibility_Index = #Main_Page.Grid_Visibility
        end
        
        Main_Page.Grid_Visibility [Main_Page.Grid_Visibility_Index].visible = true
        Main_Page.Map_Label:setText (Main_Page.Grid_Label [Main_Page.Grid_Visibility_Index])
        
      elseif Focus == "Animal" then
        if Animal_Page.Present.active then
          Animal_Page.Present.active = false
          Animal_Page.Absent.active = true
          
          for i, element in ipairs (Animal_Page.Animal_Visible_List) do
            element.visible = false
          end
          
        else
          Animal_Page.Present.active = true
          Animal_Page.Absent.active = false
          
          Apply_Animal_Selection (Animal_Page.Present:getSelected ())
        end
        
      elseif Focus == "Plant" then
        if Plant_Page.Present.active then
          Plant_Page.Present.active = false
          Plant_Page.Absent.active = true
          
          for i, element in ipairs (Plant_Page.Plant_Visible_List) do
            element.visible = false
          end
          
        else
          Plant_Page.Present.active = true
          Plant_Page.Absent.active = false
          
          Apply_Plant_Selection (Plant_Page.Present:getSelected ())
        end
        
      elseif Focus == "Geo" then
        if Geo_Page.Layer.active then
          Geo_Page.Layer.active = false
          Geo_Page.Vein.active = true
          Geo_Page.Layer_Edit_Label.visible = false
          Geo_Page.Vein_Edit_Label.visible = true
          
        else
          Geo_Page.Layer.active = true
          Geo_Page.Vein.active = false
          Geo_Page.Layer_Edit_Label.visible = true
          Geo_Page.Vein_Edit_Label.visible = false
        end
        
      elseif Focus == "Help" then
        Help_Page.Visibility_List [Help_Page.Focus].visible = false
        
        if Help_Page.Focus == 1 then
          Help_Page.Focus = #Help_Page.Visibility_List
          
        else
        Help_Page.Focus = Help_Page.Focus - 1
        end
        
        Help_Page.Visibility_List [Help_Page.Focus].visible = true
      end
      
    elseif keys [keybindings.print_help.key] and Focus == "Help" then
      local helptext
      
      if Help_Page.Focus == 1 then
        helptext = Helptext_Main ()
        
      elseif Help_Page.Focus == 2 then
        helptext = Helptext_Plant ()
        
      elseif Help_Page.Focus == 3 then
        helptext = Helptext_Animal ()
        
      elseif Help_Page.Focus == 4 then
        helptext = Helptext_Weather ()
        
      elseif Help_Page.Focus == 5 then
        helptext = Helptext_Geo ()
        
      elseif Help_Page.Focus == 6 then
        helptext = Helptext_Cavern ()
       
      elseif Help_Page.Focus == 7 then
        helptext = Helptext_World_Map ()
      
      elseif Help_Page.Focus == 8 then
        helptext = Helptext_River ()
      end
      
      for i, item in ipairs (helptext) do
        if type (item) == "string" then
          dfhack.print (item)
      
        else  --  table
          if item.pen then
            dfhack.color (item.pen)
            dfhack.print (item.text)
            dfhack.color (COLOR_RESET)
      
          else  --  Has to be a key, and we know the format used.
            dfhack.print (" (")
            dfhack.color (COLOR_LIGHTGREEN)
            dfhack.print (item.key)
            dfhack.color (COLOR_RESET)
            dfhack.print (')')
          end
        end
      end
  
      dfhack.println ()
      dfhack.println ()
      
    elseif keys [keybindings.min_count.key] then
      if Focus == "Animal" and
         Animal_Page.Min_Count.visible then
        dialog.showInputPrompt("min count",
                               "Has to be non negative and less than or equal to\n" ..
                               "Max Count\n" ..
                               "min count (" .. tostring (Animal_Page.Min_Count.text) .."):",
                               COLOR_WHITE,
                               "",
                               self:callback ("updateAnimalMinCount"))
      end
      
    elseif keys [keybindings.max_count.key] then
      if Focus == "Animal" and
         Animal_Page.Max_Count.visible then
        dialog.showInputPrompt("Max count",
                               "Has to be non negative and equal to or greater than\n" ..
                               "min Count\n" ..
                               "Max count (" .. tostring (Animal_Page.Max_Count.text) .."):",
                               COLOR_WHITE,
                               "",
                               self:callback ("updateAnimalMaxCount"))
      end
      
    elseif keys [keybindings.up.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_UP)
        end
        
        Update (0, -1, false)
      end
      
    elseif keys [keybindings.down.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()

        if movement_supported then        
          screen.parent:feed_key (df.interface_key.CURSOR_DOWN)
        end

        Update (0, 1, false)
      end
      
    elseif keys [keybindings.left.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_LEFT)
        end
        
        Update (-1, 0, false)
      end
      
    elseif keys [keybindings.right.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_RIGHT)
        end
        
        Update (1, 0, false)
      end
      
    elseif keys [keybindings.upleft.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_UPLEFT)
        end
        
        Update (-1, -1, false)
      end
      
    elseif keys [keybindings.upright.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_UPRIGHT)
        end
        
        Update (1, -1, false)
      end
      
    elseif keys [keybindings.downleft.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_DOWNLEFT)
        end
        
        Update (-1, 1, false)
      end
      
    elseif keys [keybindings.downright.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then        
          screen.parent:feed_key (df.interface_key.CURSOR_DOWNRIGHT)
        end
        
        Update (1, 1, false)
      end
      
    elseif keys [keybindings.up_fast.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_UP_FAST)
        end
        
        Update (0, -10, false)
      end
      
    elseif keys [keybindings.down_fast.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_DOWN_FAST)
        end
        
        Update (0, 10, false)
      end
      
    elseif keys [keybindings.left_fast.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_LEFT_FAST)
        end
        
        Update (-10, 0, false)
      end
      
    elseif keys [keybindings.right_fast.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_RIGHT_FAST)
        end
        
        Update (10, 0, false)
      end
      
    elseif keys [keybindings.upleft_fast.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_UPLEFT_FAST)
        end
        
        Update (-10, -10, false)
      end
      
    elseif keys [keybindings.upright_fast.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_UPRIGHT_FAST)
        end
        
        Update (10, -10, false)
      end
      
    elseif keys [keybindings.downleft_fast.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_DOWNLEFT_FAST)
        end
        
        Update (-10, 10, false)
      end
      
    elseif keys [keybindings.downright_fast.key] then
      if Focus == "Main" or
         Focus == "World_Map" or
         Focus == "River" then
        local screen = dfhack.gui.getCurViewscreen ()
        
        if movement_supported then
          screen.parent:feed_key (df.interface_key.CURSOR_DOWNRIGHT_FAST)
        end
        
        Update (10, 10, false)
      end
    end

    self.super.onInput (self, keys)
  end

  --============================================================

  function Show_Viewer ()
    local screen = BiomeManipulatorUi {}
    persist_screen = screen
    screen:show ()
  end

  --============================================================

  Show_Viewer ()  
end

biomemanipulator ()