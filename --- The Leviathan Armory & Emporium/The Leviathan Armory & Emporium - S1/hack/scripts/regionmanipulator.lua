--Manipulates the parameters of the region in focus pre embark. Use ? for help. 
--NOTE: Manipulations made are NOT permanent. They will be applied to the embark if the user embarks while
--the region is still in focus, but they will be discarded as soon as the focus is shifted. They are also
--lost for any subsequent embarks in the same region (but the previous embark will still retain the effects
--of the changes in place when it was embarked upon). It is unknown what effects manipulations have on
--Adventure Mode, but weird discontinuities are likely at the border between an abandoned/retired embark
--generated while under manipulation influence and the region itself (which is back to its original state).
--[====[

regionmanipulator
=================
]====]

local gui = require 'gui'
local dialog = require 'gui.dialogs'
local widgets =require 'gui.widgets'
local guiScript = require 'gui.script'

local Hidden_Page = {}
local Elevation_Page = {}
local Biome_Page = {}
local River_Page = {}
local Top_Cavern_Page = {}
local Mid_Cavern_Page = {}
local Low_Cavern_Page = {}
local Feature_Page = {}
local Help_Page = {}

local Feature_Color = {[df.feature_type.outdoor_river] = COLOR_LIGHTBLUE,
                       [df.feature_type.cave] = COLOR_WHITE,
                       [df.feature_type.pit] = COLOR_YELLOW,
                       [df.feature_type.magma_pool] = COLOR_LIGHTRED,
                       [df.feature_type.volcano] = COLOR_RED,
                       [df.feature_type.deep_special_tube] = COLOR_LIGHTCYAN,
                       [df.feature_type.deep_surface_portal] = COLOR_DARKGREY,     --  Not expected to exist
                       [df.feature_type.subterranean_from_layer] = COLOR_DARKGREY, --  Not expected to exist
                       [df.feature_type.magma_core_from_layer] = COLOR_DARKGREY,   --  Not expected to exist
                       [df.feature_type.underworld_from_layer] = COLOR_DARKGREY}   --  Not expected to exist
    
local Views = {["Hidden"] = 1,
               ["Elevation"] = 2,
               ["Biome"] = 3,
               ["River"] = 4,
               ["Top Cavern"] = 5,
               ["Mid Cavern"] = 6,
               ["Low Cavern"] = 7,
               ["Feature"] = 8,
               ["Help"] = 9}

--================================================================
--  The Grid widget defines an pen supporting X/Y character display grid supporting display of
--  a grid larger than the frame allows through a panning viewport. The init function requires
--  the specification of the width and height attributes that defines the grid dimensions.
--  The grid coordinates are 0 based.
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
--================================================================

function regionmanipulator ()
  if not dfhack.isWorldLoaded () then
    dfhack.color (COLOR_RED)
    dfhack.print("Error: This script requires a world to be loaded.")
    dfhack.color(COLOR_RESET)
    dfhack.println()
    return
  end

  if dfhack.isMapLoaded() then
    dfhack.color (COLOR_RED)
    dfhack.print("Error: This script requires a world to be loaded, but not a map.")
    dfhack.color(COLOR_RESET)
    dfhack.println()
    return
  end

  local map_width = df.global.world.world_data.world_width
  local map_height = df.global.world.world_data.world_height
  local x = math.floor ((df.global.gview.view.child.location.embark_pos_max.x + 
              df.global.gview.view.child.location.embark_pos_min.x) / 2)
  local y = math.floor ((df.global.gview.view.child.location.embark_pos_max.y + 
              df.global.gview.view.child.location.embark_pos_min.y) / 2)
  local max_x = 16
  local max_y = 16
  local region = df.global.world.world_data.region_details [0]
  local Edit_Focus
  local Focus = "Elevation"
  local Help_Focus = Focus
  local Help_Pages = {}
  local Current_Help_Page = 1
  
  local Vertical_River_Image = {[-1] = "North",
                                [0] = "None",
                                [1] = "South"}
                                 
  local Horizontal_River_Image = {[-1] = "East",
                                  [0] = "None",
                                  [1] = "West"}

  local keybindings = {
    elevation = {key = "CUSTOM_ALT_E",
                 desc = "Change display to region elevation"},
    biome = {key = "CUSTOM_ALT_B",
             desc = "Change display to region biome"},
    river = {key = "CUSTOM_ALT_R",
              desc = "Change display to river data"},
    top_cavern = {key = "CUSTOM_ALT_T",
                  desc = "Change display to top cavern"},
    mid_cavern = {key = "CUSTOM_ALT_M",
                  desc = "Change display to mid cavern"},
    low_cavern = {key = "CUSTOM_ALT_L",
                  desc = "Change display to lowest cavern"},
    hide = {key = "CUSTOM_ALT_H",
            desc = "Change display to show the DF region map"},
    feature = {key = "CUSTOM_ALT_F",
               desc = "Change display to show 'features'"},
    flatten = {key = "CUSTOM_SHIFT_F",
               desc = "Flatten the region to the elevation of the current region tile"},
    command_region_elevation = {key = "CUSTOM_E",
                                desc = "Change elevation of the region tile"},
    command_biome = {key = "CUSTOM_B",
                     desc = "Change biome reference of the region tile"},
    command_river_elevation = {key = "CUSTOM_SHIFT_E",
                               desc = "Change river elevation of the region tile"},
    command_vertical = {key = "CUSTOM_V",
                        desc = "Set/change/remove river vertical course component"},
    command_river_x = {key = "CUSTOM_X",
                       desc = "Change river vertical flow min x boundary"},
    command_river_X = {key = "CUSTOM_SHIFT_X",
                       desc = "Change river vertical flow Max X boundary"},
    command_horizontal = {key = "CUSTOM_H",
                          desc = "Set/change/remove river horizontal course component "},
    command_river_y = {key = "CUSTOM_Y",
                       desc = "Change river horizontal flow min y boundary"},
    command_river_Y = {key = "CUSTOM_SHIFT_Y",
                       desc = "Change river horizontal flow Max Y boundary"},
    command_top = {key = "CUSTOM_T",
                   desc = "Set 1:st cavern water indicator"},
    command_mid = {key = "CUSTOM_M",
                   desc = "Set 2:nd cavern water indicator"},
    command_low = {key = "CUSTOM_L",
                   desc = "Set 3:rd cavern water indicator"},
    command_water = {key = "CUSTOM_W",
                   desc = "Set cavern water indicator"},
    command_is_brook = {key = "CUSTOM_W",
                        desc = "Toggle Is Brook flag of the world tile"},
    command_feature_add = {key = "CUSTOM_A",
                           desc = "Add new feature"},
    command_feature_remove = {key = "CUSTOM_R",
                              desc = "Remove existing feature"},
    command_feature_move = {key = "CUSTOM_M",
                            desc = "Move adamantine spire"},
    command_feature_change = {key = "CUSTOM_C",
                              desc = "Change feature properties"},
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
    next_page = {key = "CHANGETAB",
                 desc = "Change focus to the next help screen"},
    prev_page = {key = "SEC_CHANGETAB",
                 desc = "Change focus to the previous help screen"},
    help = {key = "HELP",
            desc= " Show this help/info"},
    print_help = {key = "CUSTOM_P",
                  desc = "Print help screen to console"}}
            
   --============================================================

  --  Backwards compatibility detection
  --  
  local subtype_info_updated = false
  
  if true then  --  To get the temporary variable's context expire
    local subtype_info = df.world_site.T_subtype_info:new ()
    for i, k in pairs (subtype_info) do
      if i == "fortress_type" then
        subtype_info_updated = true
        break
      end
    end
    
    subtype_info:delete ()
  end
  
   --============================================================

  function Range_Color (arg)
    if arg < 100 then
      return COLOR_WHITE
    elseif arg < 110 then
      return COLOR_LIGHTCYAN
    elseif arg < 120 then
      return COLOR_CYAN
    elseif arg < 130 then
      return COLOR_LIGHTBLUE
    elseif arg < 140 then
      return COLOR_BLUE
    elseif arg < 150 then
      return COLOR_LIGHTGREEN
    elseif arg < 160 then
      return COLOR_GREEN
    elseif arg < 170 then
      return COLOR_YELLOW
    elseif arg < 180 then
      return COLOR_LIGHTMAGENTA
    elseif arg < 190 then
      return COLOR_LIGHTRED
    elseif arg < 200 then
      return COLOR_RED
    elseif arg < 210 then
      return COLOR_GREY
    else
      return COLOR_DARKGREY
    end
  end

  --============================================================

  function River_Elevation_Image (x, y)
    if region.rivers_vertical.active [x] [y] ~= 0 then
      return tostring (region.rivers_vertical.elevation [x] [y])
      
    elseif region.rivers_horizontal.active [x] [y] ~= 0 then
      return tostring (region.rivers_horizontal.elevation [x] [y])
      
    else
      return ""
    end
  end

  --============================================================

  function Make_Elevation (x, y)
    local end_x = #region.elevation - 1
    local end_y = #region.elevation [0] - 1
    local fg
    local bg
    local tile_color
         
    for k = 0, end_y do
      for i = 0, end_x do
        if i == x and k == y then
          fg = COLOR_BLACK
          bg = Range_Color (region.elevation [i] [k])
          tile_color = true

        else
          fg = Range_Color (region.elevation [i] [k])
          bg = COLOR_BLACK
          tile_color = false
        end        
          
        Elevation_Page.Grid:set (i, k, {ch = tostring (math.abs (region.elevation [i] [k] % 10)),
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
  
  function Make_Biome (x, y)
    local end_x = #region.biome - 1
    local end_y = #region.biome [0] - 1
    local fg
    local bg
    local tile_color
    
    for k = 0, end_y do
      for i = 0, end_x do
        if i == x and k == y then
          fg = COLOR_BLACK
          bg = Range_Color (region.biome [i] [k] * 10 + 100)
          tile_color = true
          
        else
          fg = Range_Color (region.biome [i] [k] * 10 + 100)
          bg = COLOR_BLACK
          tile_color = false
        end
        
        Biome_Page.Grid:set (i, k, {ch = tostring (region.biome [i] [k]),
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

  function Fit (Item, Size)
    if string.len (Item) > Size then
      return string.rep ('#', Size)
    else
      return Item .. string.rep (' ', Size - string.len (Item))
    end
  end

  --===========================================================================

  function Fit_Right (Item, Size)
    if string.len (Item) > Size then
      return string.rep ('#', Size)
    else
      return string.rep (' ', Size - string.len (Item)) .. Item
    end
  end

  --===========================================================================

  function Make_River (x, y)
    local last = #region.rivers_vertical.elevation - 1
    local ch
    local fg
    local bg
    local tile_color
         
    for k = 0, last do
      for i = 0, last do
        tile_color = (i == x and k == y)
        
        if region.rivers_vertical.active [i] [k] ~= 0 then
          ch = tostring (region.rivers_vertical.elevation [i] [k] % 10)
          
          if i == x and k == y then
            fg = COLOR_BLACK
            bg = Range_Color (region.rivers_vertical.elevation [i] [k])
                            
          else
            fg = Range_Color (region.rivers_vertical.elevation [i] [k])
            bg = COLOR_BLACK
          end    
          
        elseif region.rivers_horizontal.active [i] [k] ~= 0 then
          ch = tostring (region.rivers_horizontal.elevation [i] [k] % 10)
          
          if i == x and k == y then
            fg = COLOR_BLACK
            bg = Range_Color (region.rivers_horizontal.elevation [i] [k])
            
          else
            fg = Range_Color (region.rivers_horizontal.elevation [i] [k])
            bg = COLOR_BLACK
          end    
          
        else
          if i == x and k == y then
            ch = 'X'
            fg = COLOR_DARKGREY
            bg = COLOR_BLACK
            
          else
            ch = '.'
            fg = COLOR_BLACK
            bg = COLOR_DARKGREY
          end
        end
        
       River_Page.Grid:set (i, k, {ch = ch,
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

  local hex_map = {[0] = '0',
                   [1] = '1',
                   [2] = '2',
                   [3] = '3',
                   [4] = '4',
                   [5] = '5',
                   [6] = '6',
                   [7] = '7',
                   [8] = '8',
                   [9] = '9',
                   [10] = 'A',
                   [11] = 'B',
                   [12] = 'C',
                   [13] = 'D',
                   [14] = 'E',
                   [15] = 'F'}
  
  --============================================================

  function Make_Caverns (x, y)
    local value
    local fg
    local bg
    local tile_color
    
    for i = 0, 15 do
      for k = 0, 15 do
        tile_color = (i == x and k == y)
        
        if i == x and k == y then
          fg = COLOR_BLACK
          bg = COLOR_LIGHTBLUE
            
        else
          fg = COLOR_LIGHTBLUE
          bg = COLOR_BLACK
        end    
        
        value = 0
        
        Top_Cavern_Page.Grid:set (i, k, {ch = hex_map [value],
                                         fg = fg,
                                         bg = fg,
                                         bold = false,
                                         tile = nil,
                                         tile_color = tile_color,
                                         tile_fg = nil,
                                         tile_bg = nil})
                                         
        Mid_Cavern_Page.Grid:set (i, k, {ch = hex_map [value],
                                         fg = fg,
                                         bg = bg,
                                         bold = false,
                                         tile = nil,
                                         tile_color = tile_color,
                                         tile_fg = nil,
                                         tile_bg = nil})
                                            
        Low_Cavern_Page.Grid:set (i, k, {ch = hex_map [value],
                                         fg = fg,
                                         bg = bg,
                                         bold = false,
                                         tile = nil,
                                         tile_color = tile_color,
                                         tile_fg = nil,
                                         tile_bg = nil})
                                            
        for l, feature in ipairs (df.global.world.world_data.region_details [0].features [i] [k]) do
          if feature.layer >= 0 then
            value = 0
            
            if feature.unk_30 [0] then
              value = value + 1
            end

            if feature.unk_30 [1] then
              value = value + 2
            end

            if feature.unk_30 [2] then
              value = value + 4
            end

            if feature.unk_30 [3] then
              value = value + 8
            end

            if df.global.world.world_data.underground_regions [feature.layer].layer_depth == 0 then          
              Top_Cavern_Page.Grid:set (i, k, {ch = hex_map [value],
                                               fg = fg,
                                               bg = bg,
                                               bold = false,
                                               tile = nil,
                                               tile_color = tile_color,
                                               tile_fg = nil,
                                               tile_bg = nil})                                            
              
            elseif df.global.world.world_data.underground_regions [feature.layer].layer_depth == 1 then
              Mid_Cavern_Page.Grid:set (i, k, {ch = hex_map [value],
                                               fg = fg,
                                               bg = bg,
                                               bold = false,
                                               tile = nil,
                                               tile_color = tile_color,
                                               tile_fg = nil,
                                               tile_bg = nil})                                            
              
            elseif df.global.world.world_data.underground_regions [feature.layer].layer_depth == 2 then
              Low_Cavern_Page.Grid:set (i, k, {ch = hex_map [value],
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
    end
    
    Top_Cavern_Page.Water_Edit:setText (string.char (Top_Cavern_Page.Grid:get (x, y).ch))
    Mid_Cavern_Page.Water_Edit:setText (string.char (Mid_Cavern_Page.Grid:get (x, y).ch))
    Low_Cavern_Page.Water_Edit:setText (string.char (Low_Cavern_Page.Grid:get (x, y).ch))
  end
  
  --============================================================

  function Site_Character_Color_Type_Of (site)
    if site.type == df.world_site_type.PlayerFortress then
      return 'P', COLOR_LIGHTGREEN, "PlayerFortress"
      
    elseif site.type == df.world_site_type.DarkFortress then
      return 'D', COLOR_LIGHTGREEN, "DarkFortress"
      
    elseif site.type == df.world_site_type.MountainHalls then
      return 'm', COLOR_LIGHTGREEN, "MountainHalls"
      
    elseif site.type == df.world_site_type.ForestRetreat then
      return 'F', COLOR_LIGHTGREEN, "ForestRetreat"
      
    elseif site.type == df.world_site_type.Town then
      return 'T', COLOR_LIGHTGREEN, "Town"
      
    elseif site.type == df.world_site_type.Cave then
      return 'c', COLOR_LIGHTGREEN, "Cave"
      
    elseif site.type == df.world_site_type.ImportantLocation then
      return 'i', COLOR_GREEN, "ImportantLocation"      
    
    elseif site.type == df.world_site_type.Camp then
      return 'C', COLOR_LIGHTGREEN, "Camp"
    end

    if subtype_info_updated then
      if site.type == df.world_site_type.Fortress then
        if site.subtype_info.fortress_type == df.fortress_type.CASTLE then
          return 'e', COLOR_LIGHTGREEN, "Castle"
          
        elseif site.subtype_info.fortress_type == df.fortress_type.TOWER then
          return 't', COLOR_LIGHTGREEN, "Tower"
          
        elseif site.subtype_info.fortress_type == df.fortress_type.MONASTERY then
          return 'y', COLOR_LIGHTGREEN, "Monastery"
          
        elseif site.subtype_info.fortress_Type == df.fortress_type.FORT then
          return 'f', COLOR_LIGHTGREEN, "Fort"
        end
       
      elseif site.type == df.world_site_type.Monument then
        if site.subtype_info.monument_type == df.monument_type.TOMB then
          return 't', COLOR_LIGHTGREEN, "Tomb"
    
        elseif site.subtype_info.is_monument == df.monument_type.VAULT then
          return 'V', COLOR_GREEN, "Vault"
        
        else
          return 'M', COLOR_GREEN, "Monument"
        end
        
      elseif site.type == df.world_site_type.LairShrine then
        if site.subtype_info.lair_type == df.lair_type.SIMPLE_MOUND or
           site.subtype_info.lair_type == df.lair_type.SIMPLE_BURROW or
           site.subtype_info.lair_type == df.lair_type.WILDERNESS_LOCATION then  --  Mountain lair
          return 'l', COLOR_GREEN, "Lair"
        
        elseif site.subtype_info.lair_type == df.lair_type.LABYRINTH then
          return 'L', COLOR_GREEN, "Labyrinth"
        
        elseif site.subtype_info.lair_type == df.lair_type.SHRINE then
          return 'S', COLOR_GREEN, "Shrine"
        
        else
          return '?', COLOR_GREEN, "?LairShrine?"
        end
      end
       
    else
      if site.type == df.world_site_type.Fortress then
        if site.subtype_info.is_tower == 0 then
          return 'f', COLOR_LIGHTGREEN, "Fortress"
          
        else
          return 't', COLOR_LIGHTGREEN, "Tower"
        end
       
      elseif site.type == df.world_site_type.Monument then
        if site.subtype_info.is_monument == 0 then
          return 't', COLOR_LIGHTGREEN, "Tomb"
    
        elseif site.subtype_info.is_monument == 1 then
          return 'V', COLOR_GREEN, "Vault"
        
        else
          return 'M', COLOR_GREEN, "Monument"
        end
        
      elseif site.type == df.world_site_type.LairShrine then
        if site.subtype_info.lair_type == 0 or
           site.subtype_info.lair_type == 1 or
           site.subtype_info.lair_type == 4 then  --  Mountain lair?
          return 'l', COLOR_GREEN, "Lair"
        
        elseif site.subtype_info.lair_type == 2 then
          return 'L', COLOR_GREEN, "Labyrinth"
        
        elseif site.subtype_info.lair_type == 3 then
          return 'S', COLOR_GREEN, "Shrine"
        
        else
          return '?', COLOR_GREEN, "?LairShrine?"
        end
      end
    end
        
    return '!', COLOR_GREEN, "UnknownSite"
  end
  
  --============================================================

  function Make_Features (x, y)
    local last = 15
    local region = df.global.world.world_data.region_details [0]
    local feature_init
    local features = {}
    local text
    local ch
    local fg
    local bg
    local tile_color
    local list = {}
    local dummy_1
    local dummy_2
    
    Feature_Page.Feature_List = {}
         
    for k = 0, last do
      for i = 0, last do
        tile_color = (i == x and k == y)
        
        for l = 0, df.feature_type.underworld_from_layer do--###
          features [l] = 0
        end
        
        ch = ' '
        fg = COLOR_BLACK
        bg = COLOR_BLACK
        
        for l, feature in ipairs (region.features [i] [k]) do
          if feature.feature_idx ~= -1 then  --  We don't care about the standard caverns and the magma sea.
            feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                             features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
                             
            if tile_color then
              if feature_init:getType () == df.feature_type.outdoor_river then
                table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "River"})
                
              elseif feature_init:getType () == df.feature_type.cave then
                if feature_init.start_depth == -1 then
                  table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Passage " .. "Surface\x1aCavern " .. tostring (feature_init.end_depth + 1)})
                else
                  table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Passage Cavern " .. tostring (feature_init.start_depth + 1) .. "\x1a" .. tostring (feature_init.end_depth + 1)})
                end
                
              elseif feature_init:getType () == df.feature_type.pit then
                table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Pit Cavern " .. tostring (feature_init.start_depth + 1) .. "\x1a" .. tostring (feature_init.end_depth + 1)})
                
              elseif feature_init:getType () == df.feature_type.magma_pool then
                table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Magma Pool Top Cavern " .. tostring (feature_init.start_depth + 1)})
                
              elseif feature_init:getType () == df.feature_type.volcano then
                table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Volcano"})
                
              elseif feature_init:getType () == df.feature_type.deep_special_tube then
                if feature_init.start_depth < 3 then
                  table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Adamantine Spire Top Cavern " .. tostring (feature_init.start_depth + 1)})
                  
                else
                  table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Adamantine Spire Top Magma Sea"})
                end
                
              elseif feature_init:getType () == df.feature_type.deep_surface_portal then
                table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Deep Surface Portal"})
                
              elseif feature_init:getType () == df.feature_type.subterranean_from_layer then
                table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Subterranean From Layer"})
                
              elseif feature_init:getType () == df.feature_type.magma_core_from_layer then
                table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Magma Core From Layer"})
                
              elseif feature_init:getType () == df.feature_type.underworld_from_layer then
                table.insert (Feature_Page.Feature_List, {feature_index = feature.feature_idx, text = "Underworld From Layer"})
              end
            end
            
            if ch == ' ' then
              fg = Feature_Color [feature_init:getType ()]
              
              if feature_init:getType () == df.feature_type.outdoor_river then
                ch = 'R'
                
              elseif feature_init:getType () == df.feature_type.cave then
                if feature_init.start_depth == -1 then
                  ch = 'S'
                  
                else
                  ch = tostring (feature_init.start_depth + 1)
                end
                
              elseif feature_init:getType () == df.feature_type.pit or
                     feature_init:getType () == df.feature_type.magma_pool then
                ch = tostring (feature_init.start_depth + 1)
               
              elseif feature_init:getType () == df.feature_type.volcano then
                ch = 'V'
                
              elseif feature_init:getType () == df.feature_type.deep_special_tube then
                if feature_init.start_depth == 3 then
                  ch = 'M'
                  
                else
                  ch = tostring (feature_init.start_depth + 1)
                end
                
              elseif feature_init:getType () == df.feature_type.deep_surface_portal then
                ch = 'P'
                
              elseif feature_init:getType () == df.feature_type.subterranean_from_layer then
                ch = 'S'
                
              elseif feature_init:getType () == df.feature_type.magma_core_from_layer then
                ch = 'C'
                
              elseif feature_init:getType () == df.feature_type.underworld_from_layer then
                ch = 'U'
              end
              
            else
              ch = '*'
              fg = COLOR_MAGENTA
            end
          end
        end

        for l = math.max (region.pos.x - 1, 0), math.min (region.pos.x + 1, df.global.world.world_data.world_width - 1) do
          for m = math.max (region.pos.y - 1, 0), math.min (region.pos.y + 1, df.global.world.world_data.world_height - 1) do
            for n, site in ipairs (df.global.world.world_data.region_map [l]:_displace (m).sites) do
              if site.global_min_x <= i + region.pos.x * 16 and
                 site.global_max_x >= i + region.pos.x * 16 and
                 site.global_min_y <= k + region.pos.y * 16 and
                 site.global_max_y >= k + region.pos.y * 16 then
                if tile_color then
                  dummy_1, dummy_2, text = Site_Character_Color_Type_Of (site)
                  table.insert (Feature_Page.Feature_List, {feature_index = -1, text = text})
                end
                
                if ch ~= ' ' then
                  ch = '*'
                  fg = COLOR_MAGENTA
              
                else
                  ch, fg, text = Site_Character_Color_Type_Of (site)
                end
              end
            end
          end
        end
        
        if tile_color then
          bg = fg
          fg = COLOR_BLACK
          
          if ch == ' ' then
            ch = 'X'
            bg = COLOR_WHITE
          end
        end
        
       Feature_Page.Grid:set (i, k, {ch = ch,
                                     fg = fg,
                                     bg = bg,
                                     bold = false,
                                     tile = nil,
                                     tile_color = tile_color,
                                     tile_fg = nil,
                                     tile_bg = nil})
      end
    end
    
    for i, element in ipairs (Feature_Page.Feature_List) do
      table.insert (list, element.text)
    end
    
    Feature_Page.List:setChoices (list)
  end
  
  --============================================================

  function Set_Visibility (item, visible)
    for i, object in ipairs (River_Page.Visibility_List [item]) do
      object.visible = visible
    end
  end
  
  --============================================================

  function Bool_Image (b)
    if b then
      return 'Y'
    else
      return 'N'
    end
  end
  
  --==============================================================
  
  function Update (x, y, pages)   
    Make_Elevation (x, y)
    Make_Biome (x, y)
    Make_River (x, y)
    Make_Caverns (x, y)
    Make_Features (x, y)
    
    Elevation_Page.Heading_Label_X:setText (Fit_Right (tostring (x), 2))
    Elevation_Page.Heading_Label_Y:setText (Fit_Right (tostring (y), 2))

    Biome_Page.Heading_Label_X:setText (Fit_Right (tostring (x), 2))
    Biome_Page.Heading_Label_Y:setText (Fit_Right (tostring (y), 2))
    
    River_Page.Heading_Label_X:setText (Fit_Right (tostring (x), 2))
    River_Page.Heading_Label_Y:setText (Fit_Right (tostring (y), 2))
    
    Top_Cavern_Page.Heading_Label_X:setText (Fit_Right (tostring (x), 2))
    Top_Cavern_Page.Heading_Label_Y:setText (Fit_Right (tostring (y), 2))
    
    Mid_Cavern_Page.Heading_Label_X:setText (Fit_Right (tostring (x), 2))
    Mid_Cavern_Page.Heading_Label_Y:setText (Fit_Right (tostring (y), 2))
    
    Low_Cavern_Page.Heading_Label_X:setText (Fit_Right (tostring (x), 2))
    Low_Cavern_Page.Heading_Label_Y:setText (Fit_Right (tostring (y), 2))
    
    Feature_Page.Heading_Label_X:setText (Fit_Right (tostring (x), 2))
    Feature_Page.Heading_Label_Y:setText (Fit_Right (tostring (y), 2))

    Elevation_Page.Region_Elevation_Edit:setText (Fit_Right (region.elevation [x] [y], 4))
                                                      
    Biome_Page.Region_Biome_Edit:setText (Fit_Right (region.biome [x] [y], 1))

    River_Page.Elevation_Edit:setText (Fit_Right (River_Elevation_Image (x, y), 4))
    River_Page.Ground_Elevation:setText (Fit_Right (region.elevation [x] [y], 4))
    Set_Visibility ("River_Elevation", River_Elevation_Image (x, y) ~= "")
    
    River_Page.Vertical_Edit:setText (Vertical_River_Image [region.rivers_vertical.active [x] [y]])    

    River_Page.X_Min_Edit:setText (Fit_Right (region.rivers_vertical.x_min [x] [y], 2))
    River_Page.X_Max_Edit:setText (Fit_Right (region.rivers_vertical.x_max [x] [y], 2))
    
    Set_Visibility ("Vertical", region.rivers_vertical.active [x] [y] ~= 0)

    River_Page.Horizontal_Edit:setText (Horizontal_River_Image [region.rivers_horizontal.active [x] [y]])
                         
    River_Page.Y_Min_Edit:setText (Fit_Right (region.rivers_horizontal.y_min [x] [y], 2))
    River_Page.Y_Max_Edit:setText (Fit_Right (region.rivers_horizontal.y_max [x] [y], 2))
    
    Set_Visibility ("Horizontal", region.rivers_horizontal.active [x] [y] ~= 0)
    
    River_Page.Is_Brook_Edit:setText (Bool_Image (df.global.world.world_data.region_map[region.pos.x]:_displace(region.pos.y).flags.is_brook))
  end
  
  --============================================================

  function Free_Layers ()
    local region = df.global.world.world_data.region_details [0]
    local free_layer = {[-1] = true,
                        [0] = df.global.world.worldgen.worldgen_parms.cavern_layer_count > 0,
                        [1] = df.global.world.worldgen.worldgen_parms.cavern_layer_count > 1,
                        [2] = df.global.world.worldgen.worldgen_parms.cavern_layer_count > 2,
                        [3] = true}
                        
    for i, element in ipairs (Feature_Page.Feature_List) do
      if Feature_Page.Feature_List [i].feature_index == -1 then
        free_layer [-1] = false
        
      else
        feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                         features.feature_init [region.pos.x % 16] [region.pos.y % 16] [Feature_Page.Feature_List [i].feature_index]
          
        if feature_init:getType () == df.feature_type.outdoor_river then
          free_layer [-1] = false
        end
        
        for k = feature_init.start_depth, feature_init.end_depth - 1 do
          free_layer [k] = false
        end
        
        if feature_init:getType () == df.feature_type.magma_pool or
           feature_init:getType () == df.feature_type.volcano or
           feature_init:getType () == df.feature_type.deep_special_tube then
          free_layer [3] = false
        end
      end
    end
    
    return free_layer
  end
  
  --============================================================

  function Show_Feature_Context_Keys (index, choice)
    local region = df.global.world.world_data.region_details [0]
    local feature_init
    local free_layer = Free_Layers ()    
    local any_free_layer = false
    
    if not index or
       index < 1 or 
       #Feature_Page.Feature_List < index then
      Feature_Page.Add_Label.visible = true
      Feature_Page.Remove_Label.visible = false
      Feature_Page.Change_Label.visible = false
      Feature_Page.Move_Label.visible = false
      return
    end
    
    for i = -1, 3 do
      any_free_layer = any_free_layer or free_layer [i]
    end
    
    Feature_Page.Add_Label.visible = any_free_layer
   
    if Feature_Page.Feature_List [index].feature_index == -1 then  -- Site, not a feature
      Feature_Page.Remove_Label.visible = false
      Feature_Page.Change_Label.visible = false
      Feature_Page.Move_Label.visible = false
      
    else
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                       features.feature_init [region.pos.x % 16] [region.pos.y % 16] [Feature_Page.Feature_List [index].feature_index]
                       
      Feature_Page.Remove_Label.visible = feature_init:getType () == df.feature_type.cave or
                                          feature_init:getType () == df.feature_type.pit or
                                          feature_init:getType () == df.feature_type.magma_pool or
                                          feature_init:getType () == df.feature_type.volcano
                                          
      Feature_Page.Change_Label.visible = feature_init:getType () == df.feature_type.magma_pool or
                                          feature_init:getType () == df.feature_type.deep_special_tube
                                          
      Feature_Page.Move_Label.visible = feature_init:getType () == df.feature_type.deep_special_tube
    end    
  end
  
  --============================================================

  Ui = defclass (nil, gui.FramedScreen)
  Ui.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Region Manipulator",
    transparent = false
  }

  --============================================================

  function Ui:onRenderFrame (dc, rect)
    local x1, y1, x2, y2 = rect.x1, rect.y1, rect.x2, rect.y2

    if self.transparent then
      self:renderParent ()
      
    else
      if rect.wgap <= 0 and rect.hgap <= 0 then
        dc:clear ()
        
      else
        self:renderParent ()
        dc:fill (rect, self.frame_background)
      end
    end
    
    gui.paint_frame (x1, y1, x2, y2, self.frame_style, self.frame_title)
  end
  

  --============================================================

  function Ui:onHelp ()
    Help_Focus = Focus
    Focus = "Help"
    self.subviews.pages:setSelected (Views [Focus])
    self.transparent = false
  end

  --============================================================

  function Help_Text_Main ()
    local helptext = {"Main Help/Info", 
                      {text = "",
                       key = keybindings.print_help.key,
                       key_sep = '()'},
                       " Print all help texts to the DFHack console",
                       NEWLINE,
                       "", 
                      {text = "",
                       key = keybindings.next_page.key,
                       key_sep = '()'},
                       " Next Help Screen",
                      "", 
                      {text = "",
                       key = keybindings.prev_page.key,
                       key_sep = '()'},
                       " Previous Help Screen", NEWLINE}
     
    table.insert (helptext, NEWLINE)
    
    local dsc = 
      {"The Region Manipulator is used pre embark to manipulate the region where the", NEWLINE,
       "embark is intended to be performed. Due to the way DF works, any manipulation", NEWLINE,
       "performed on the region is lost/discarded once DF's focus is changed to", NEWLINE,
       "another region and absent when returned. Similarly, Embarking anew in the", NEWLINE,
       "same region as a previous fortress will have the region manipulations", NEWLINE,
       "performed prior to the previous embark reversed on the region level, but", NEWLINE,
       "their effects are 'frozen' in the fortress itself. Manipulations are effected", NEWLINE,
       "immediately in DF.", NEWLINE,
       "The tool allows you to change region level elevations, biomes, river, a", NEWLINE,
       "poorly understood cavern water parameter, and 'features' (volcano,", NEWLINE,
       "magma pool, adamantine spire, passage, and pit) on separate tool pages.", NEWLINE,
       "All available ecommands are indicated on the UI although some are context", NEWLINE,
       "sensitive and visible only when a corresponding item is in focus.", NEWLINE,
       "Apart from the fields, the UI also contains a 'graphic' grid over the region", NEWLINE,
       "which displays the corresponding data geographically.", NEWLINE, NEWLINE,
       "Version 0.15, 2020-02-15"}

    for i, v in pairs (dsc) do
      table.insert (helptext, v)
    end
    
    return helptext
  end
  
  table.insert (Help_Pages, {"Main", (function () return Help_Text_Main () end)})
  
  --============================================================

  function Help_Text_Elevation ()
    local helptext = {"Elevation Help/Info", 
                      {text = "",
                       key = keybindings.print_help.key,
                       key_sep = '()'},
                       " Print all help texts to the DFHack console",
                       NEWLINE,
                       "", 
                      {text = "",
                       key = keybindings.next_page.key,
                       key_sep = '()'},
                       " Next Help Screen",
                      "", 
                      {text = "",
                       key = keybindings.prev_page.key,
                       key_sep = '()'},
                       " Previous Help Screen", NEWLINE}
     
      local dsc = 
      {"The Elevation page shows a grid of the elevations in the area and provides", NEWLINE,
       "two commands: one to change the elevation of a tile, and the other to change", NEWLINE,
       "the elevation of all tiles to that of the world tile, thus flattening the", NEWLINE,
       "area. Those changes are lost if the DF focus changes to a different world", NEWLINE,
       "tile. Elevations are color coded. The color ranges are:", NEWLINE,
       {text = "WHITE        < 100, with the actual decile lost.", pen = dfhack.pen.parse {fg = COLOR_WHITE, bg = 0}}, NEWLINE,
       {text = "LIGHT CYAN     100 - 109", pen = dfhack.pen.parse {fg = COLOR_LIGHTCYAN, bg = 0}}, NEWLINE,
       {text = "CYAN           110 - 119", pen = dfhack.pen.parse {fg = COLOR_CYAN, bg = 0}}, NEWLINE,
       {text = "LIGHT BLUE     120 - 129", pen = dfhack.pen.parse {fg = COLOR_LIGHTBLUE, bg = 0}}, NEWLINE,
       {text = "BLUE           130 - 139", pen = dfhack.pen.parse {fg = COLOR_BLUE, bg = 0}}, NEWLINE,
       {text = "LIGHT GREEN    140 - 149", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, NEWLINE,
       {text = "GREEN          150 - 159", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, NEWLINE,
       {text = "YELLOW         160 - 169", pen = dfhack.pen.parse {fg = COLOR_YELLOW, bg = 0}}, NEWLINE,
       {text = "LIGHT MAGENTA  170 - 179", pen = dfhack.pen.parse {fg = COLOR_LIGHTMAGENTA, bg = 0}}, NEWLINE,
       {text = "LIGHT RED      180 - 189", pen = dfhack.pen.parse {fg = COLOR_LIGHTRED, bg = 0}}, NEWLINE,
       {text = "RED            190 - 199", pen = dfhack.pen.parse {fg = COLOR_RED, bg = 0}}, NEWLINE,
       {text = "GREY           200 - 219", pen = dfhack.pen.parse {fg = COLOR_GREY, bg = 0}}, NEWLINE,
       {text = "DARK GREY    > 219, with the actual decile lost.", pen = dfhack.pen.parse {fg = COLOR_DARKGREY, bg = 0}}}

    for i, v in pairs (dsc) do
      table.insert (helptext, v)
    end
    
    return helptext
  end
  
  table.insert (Help_Pages, {"Elevation", (function () return Help_Text_Elevation () end)})
  
  --============================================================

  function Help_Text_Biome ()
    local helptext = {"Biome Help/Info", 
                      {text = "",
                       key = keybindings.print_help.key,
                       key_sep = '()'},
                       " Print all help texts to the DFHack console",
                       NEWLINE,
                       "", 
                      {text = "",
                       key = keybindings.next_page.key,
                       key_sep = '()'},
                       " Next Help Screen",
                      "", 
                      {text = "",
                       key = keybindings.prev_page.key,
                       key_sep = '()'},
                       " Previous Help Screen", NEWLINE}
     
    table.insert (helptext, NEWLINE)
    
    local dsc = 
      {"The Biome page displays which world tile provides the biome for each tile.", NEWLINE,
       "The color used is redundant, as the value range is 1 to 9.", NEWLINE,
       "This page provides a single command: to change the world tile controlling the", NEWLINE,
       "biome of the corresponding tile. The world tiles are the current one plus the", NEWLINE,
       "8 surrounding ones. To find out what the actual biomes are you have to go", NEWLINE,
       "back to DF or use a different tool (the logic is rather convoluted, and thus", NEWLINE,
       "rather large).", NEWLINE,
       "The key for the Biome is:", NEWLINE,
       {text = "  7", pen = dfhack.pen.parse {fg = Range_Color (170), bg = 0}}, ": NW ",
       {text = "8", pen = dfhack.pen.parse {fg = Range_Color (180), bg = 0}}, ": N    ",
       {text = "9", pen = dfhack.pen.parse {fg = Range_Color (190), bg = 0}}, ": NE", NEWLINE,
       {text = "  4", pen = dfhack.pen.parse {fg = Range_Color (140), bg = 0}}, ":  W ",
       {text = "5", pen = dfhack.pen.parse {fg = Range_Color (150), bg = 0}}, ": Here ",
       {text = "6", pen = dfhack.pen.parse {fg = Range_Color (160), bg = 0}}, ":  E", NEWLINE,
       {text = "  1", pen = dfhack.pen.parse {fg = Range_Color (110), bg = 0}}, ": SW ",
       {text = "2", pen = dfhack.pen.parse {fg = Range_Color (120), bg = 0}}, ": S    ",
       {text = "3", pen = dfhack.pen.parse {fg = Range_Color (130), bg = 0}}, ": SE"}

    for i, v in pairs (dsc) do
      table.insert (helptext, v)
    end
    
    return helptext
  end
  
  table.insert (Help_Pages, {"Biome", (function () return Help_Text_Biome () end)})
  
  --============================================================

  function Help_Text_River ()
    local helptext = {"River Help/Info", 
                      {text = "",
                       key = keybindings.print_help.key,
                       key_sep = '()'},
                       " Print all help texts to the DFHack console",
                       NEWLINE,
                       "", 
                      {text = "",
                       key = keybindings.next_page.key,
                       key_sep = '()'},
                       " Next Help Screen",
                      "", 
                      {text = "",
                       key = keybindings.prev_page.key,
                       key_sep = '()'},
                       " Previous Help Screen", NEWLINE}
     
    table.insert (helptext, NEWLINE)
    
    local dsc = 
      {"River manipulation is ... messy, using poorly understood rules, so some", NEWLINE,
       "experimentation is needed. The Hide page is very useful, as it allows you to", NEWLINE,
       "see what your changes have resulted in.", NEWLINE,
       "Note that the River elevation is the level of the water, and DF generates a", NEWLINE,
       "gorge or an 'aqueduct' to adapt the level. River level differences where", NEWLINE,
       "downstream is lower than upstream result in waterfalls.", NEWLINE,
       "A river's course is controlled by where it enters enters and exits the world", NEWLINE,
       "tile, as well as vertical and horizontal 'connections'. A 'connection' joins", NEWLINE,
       "up with the previous tile, but does not dictate the flow direction. If there", NEWLINE,
       "is no river specification for the 'previous' tile DF generates a source or", NEWLINE,
       "a sink there. x/y Min/Max controls the width of the river, and is expressed", NEWLINE,
       "in game tiles (0 to 47) within the mid level tile manipulated.", NEWLINE,
       "Is Brook controls whether the river is a brook or a stream. As opposed to", NEWLINE,
       "other changes, this change is retained by DF as the property lies with the", NEWLINE,
       "world tile rather than the region.", NEWLINE,
       "The Elevation color key is the same as for the ground elevation."}

    for i, v in pairs (dsc) do
      table.insert (helptext, v)
    end
    
    return helptext
  end
  
  table.insert (Help_Pages, {"River", (function () return Help_Text_River () end)})
  
  --============================================================

  function Help_Text_Cavern ()
    local helptext = {"Cavern (1/2/3) Help/Info", 
                      {text = "",
                       key = keybindings.print_help.key,
                       key_sep = '()'},
                       " Print all help texts to the DFHack console",
                       NEWLINE,
                       "", 
                      {text = "",
                       key = keybindings.next_page.key,
                       key_sep = '()'},
                       " Next Help Screen",
                      "", 
                      {text = "",
                       key = keybindings.prev_page.key,
                       key_sep = '()'},
                       " Previous Help Screen", NEWLINE}
     
    table.insert (helptext, NEWLINE)
    
    local dsc = 
      {"The cavern water pages (one for each cavern) are rather anemic, and do not", NEWLINE,
       "serve much of a purpose for players, but should rather be considered as tools", NEWLINE,
       "for investigation of what the parameter does."}

    for i, v in pairs (dsc) do
      table.insert (helptext, v)
    end
    
    return helptext
  end
  
  table.insert (Help_Pages, {"Cavern", (function () return Help_Text_Cavern () end)})
  
  --============================================================

  function Help_Text_Feature ()
    local helptext = {"Feature Help/Info", 
                      {text = "",
                       key = keybindings.print_help.key,
                       key_sep = '()'},
                       " Print all help texts to the DFHack console",
                       NEWLINE,
                       "", 
                      {text = "",
                       key = keybindings.next_page.key,
                       key_sep = '()'},
                       " Next Help Screen",
                      "", 
                      {text = "",
                       key = keybindings.prev_page.key,
                       key_sep = '()'},
                       " Previous Help Screen", NEWLINE}
     
    table.insert (helptext, NEWLINE)
    
    local dsc = 
      {"The Feature page allows you to manipulate 'features' to some extent.", NEWLINE,
       "The Features in this case are Adamantine Spires, Volcanoes, Magma Pools,", NEWLINE,
       "Passages, and Pits. A (not very logical) set of restrictions are used to", NEWLINE,
       "restrict what can be done to 'reasonable' cases. You can Add all of the", NEWLINE,
       "Features except Spires, and you can Remove the same set of features.", NEWLINE,
       "A Feature can only be added if it doesn't clash physically with Site or", NEWLINE,
       "River for surface reaching Features), or another Feature. You can also Change", NEWLINE,
       "the extent of multi layer features (Spire/Magma Pool) to reach higher/lower", NEWLINE,
       "and Move Spires to any of the other 3 tiles (if free). A moved Spire gets its", NEWLINE,
       "top level set to the Magma sea (to save on clash checking), but can be", NEWLINE,
       "Changed back to a higher level. The 'graphic' grid shows a coded view of the", NEWLINE,
       "Features available at each tile, and a list of the Features present at the", NEWLINE,
       "current tile is provided. This list is traversed with the secondary movement", NEWLINE,
       "control scheme (as the standard one is used for the 'graphics'):", NEWLINE,
       {text = "",
        key = df.interface_key.SECONDSCROLL_UP,
        key_sep = '()'},
       {text =" Up", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}},
       {text = "",
        key = df.interface_key.SECONDSCROLL_DOWN,
        key_sep = '()'},
       {text = " Down", dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, NEWLINE,
       "Note that Sites are shown in the 'graphics' as their presence can block the", NEWLINE,
       "placement of some Features. The key is shown on the next help page."}

    for i, v in pairs (dsc) do
      table.insert (helptext, v)
    end
    
    return helptext
  end
  
  table.insert (Help_Pages, {"Feature", (function () return Help_Text_Feature () end)})
  
  --============================================================

  function Help_Text_Feature_Key ()
    local helptext = {"Feature Key Help/Info", 
                      {text = "",
                       key = keybindings.print_help.key,
                       key_sep = '()'},
                       " Print all help texts to the DFHack console",
                       NEWLINE,
                       "", 
                      {text = "",
                       key = keybindings.next_page.key,
                       key_sep = '()'},
                       " Next Help Screen",
                      "", 
                      {text = "",
                       key = keybindings.prev_page.key,
                       key_sep = '()'},
                       " Previous Help Screen", NEWLINE}
     
    table.insert (helptext, NEWLINE)
    
    local dsc = 
      {"Feature display key:", NEWLINE,
       {text = "*:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTMAGENTA, bg = 0}}, " Multiple features", NEWLINE, 
       {text = "S/1/2:  ", pen = dfhack.pen.parse {fg = COLOR_WHITE, bg = 0}}, " Passage from Surface/Cavern 1/Cavern 2", NEWLINE,
       {text = "1/2:    ", pen = dfhack.pen.parse {fg = COLOR_YELLOW, bg = 0}}, " Pit from Cavern 1/Cavern 2", NEWLINE,       
       {text = "1/2/3:  ", pen = dfhack.pen.parse {fg = COLOR_LIGHTRED, bg = 0}}, " Magma Pool from Cavern 1/Cavern 2/Cavern 3", NEWLINE,
       {text = "V:      ", pen = dfhack.pen.parse {fg = COLOR_RED, bg = 0}}, " Volcano", NEWLINE,
       {text = "1/2/3/M:", pen = dfhack.pen.parse {fg = COLOR_LIGHTCYAN, bg = 0}}, " Adamantine Spire from Cavern 1/Cavern 2/Cavern 3/Magma Sea", NEWLINE,
       {text = "R:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTBLUE, bg = 0}}, " River", NEWLINE,
       {text = "P:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, " PlayerFortress", {text = " D: ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, "DarkFortress", NEWLINE,
       {text = "m:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, " MountainHalls ", {text = " F: ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, "ForestRetreat", NEWLINE,
       {text = "T:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, " Town          ", {text = " c: ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, "Cave", NEWLINE,
       {text = "t:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, " Tomb          ", {text = " i: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "ImportantLocation", NEWLINE,
       {text = "l:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " Lair          ", {text = " L: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "Labyrinth", NEWLINE,
       {text = "S:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " Shrine        ", {text = " f: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "Fortress", NEWLINE,
       {text = "C:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " Camp          ", {text = " V: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "Vault", NEWLINE,
       {text = "M:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " Monument      ", NEWLINE,
       {text = "?:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " ?LairShrine?  ", {text = " !: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "UnknownSite", NEWLINE}

    for i, v in pairs (dsc) do
      table.insert (helptext, v)
    end
    
    return helptext
  end
  
  table.insert (Help_Pages, {"Feature_Key", (function () return Help_Text_Feature_Key () end)})
  
  --============================================================

  function Ui:init ()
    local Top_Cavern_Key_Color = COLOR_LIGHTBLUE
    local Top_Cavern_Key_Pen = COLOR_LIGHTGREEN
    local Mid_Cavern_Key_Color = COLOR_LIGHTBLUE
    local Mid_Cavern_Key_Pen = COLOR_LIGHTGREEN
    local Low_Cavern_Key_Color = COLOR_LIGHTBLUE
    local Low_Cavern_Key_Pen = COLOR_LIGHTGREEN
    
    self.stack = {}
    self.item_count = 0
    self.keys = {}
    
    if df.global.world.worldgen.worldgen_parms.cavern_layer_count < 3 then
      Low_Cavern_Key_Color = COLOR_DARKGREY
      Low_Cavern_Key_Pen = COLOR_DARKGREY
    end
    
    if df.global.world.worldgen.worldgen_parms.cavern_layer_count < 2 then
      Mid_Cavern_Key_Color = COLOR_DARKGREY
      Mid_Cavern_Key_Pen = COLOR_DARKGREY
    end
    
    if df.global.world.worldgen.worldgen_parms.cavern_layer_count < 1 then
      Top_Cavern_Key_Color = COLOR_DARKGREY
      Top_Cavern_Key_Pen = COLOR_DARKGREY
    end
    
    local top_cavern_key = {text = "",
                                   key = keybindings.top_cavern.key,
                                   key_sep = '()',
                                   key_pen = Top_Cavern_Key_Pen}
    local top_cavern_text = {text = " Top Cavern",
                             pen = Top_Cavern_Key_Color}
        
    local mid_cavern_key = {text = "",
                                   key = keybindings.mid_cavern.key,
                                   key_sep = '()',
                                   key_pen = Mid_Cavern_Key_Pen}
    local mid_cavern_text = {text = " Mid Cavern",
                             pen = Mid_Cavern_Key_Color}
        
    local low_cavern_key = {text = "",
                                   key = keybindings.low_cavern.key,
                                   key_sep = '()',
                                   key_pen = Low_Cavern_Key_Pen}
    local low_cavern_text = {text = " Low Cavern",
                             pen = Low_Cavern_Key_Color}
        
    Hidden_Page.Top_Mask = 
      widgets.Widget {frame_background = COLOR_BLACK,
                      frame = {l = 0, t = 0, r = 0, h = 1, yalign = 0}}

    Hidden_Page.Bottom_Mask = 
      widgets.Widget {frame_background = COLOR_BLACK,
                      frame = {l = 0, t = 17, r = 0, b = 0, yalign = 0}}

    Hidden_Page.Right_Mask = 
      widgets.Widget {frame_background = COLOR_BLACK,
                      frame = {l = 17, t = 1, r = 0, h = 17, yalign = 0}}
                     
    Hidden_Page.Heading_Label = 
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},
                             " Hidden Region Manipulator/Show Vanilla Region"},
                     frame = {l = 0, t = 0, y_align = 0}}
    
    Hidden_Page.Body_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.elevation.key,
                                      key_sep = '()'},
                             {text = " Elevation ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.biome.key,
                                      key_sep = '()'},
                             {text = " Biome     ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.river.key,
                                      key_sep = '()'},
                             {text = " River",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             top_cavern_key,
                             top_cavern_text,
                             mid_cavern_key,
                             mid_cavern_text,
                             low_cavern_key,
                             low_cavern_text, NEWLINE,
                             {text = "",
                                      key = keybindings.feature.key,
                                      key_sep = '()'},
                             {text = " Feature",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 17, t = 2, y_align = 0}}
                     
    local hiddenPage = widgets.Panel {
      subviews = {Hidden_Page.Top_Mask,
                  Hidden_Page.Bottom_Mask,
                  Hidden_Page.Right_Mask,
                  Hidden_Page.Heading_Label,
                  Hidden_Page.Body_Label}}
                  
    Elevation_Page.Heading_Label = 
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},
                             " X =   , Y =    Elevation Manipulation"},
                     frame = {l = 0, t = 0, y_align = 0}}
    
    Elevation_Page.Body_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.biome.key,
                                      key_sep = '()'},
                             {text = " Biome     ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.river.key,
                                      key_sep = '()'},
                             {text = " River     ",
                              pen = COLOR_LIGHTBLUE},
                             top_cavern_key,
                             top_cavern_text, NEWLINE,
                             mid_cavern_key,
                             mid_cavern_text,
                             low_cavern_key,
                             low_cavern_text,
                             {text = "",
                                      key = keybindings.feature.key,
                                      key_sep = '()'},
                             {text = " Feature",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                      key = keybindings.hide.key,
                                      key_sep = '()'},
                             {text = " Hide",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "",
                                      key = keybindings.command_region_elevation.key,
                                      key_sep = '()'},
                             {text = " Region Elevation:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                              {text = "",
                                      key = keybindings.flatten.key,
                                      key_sep = '()'},
                             {text = " Flatten Region",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             " Elevations are color coded. The color ranges are:", NEWLINE,
                             {text = "  WHITE        < 100 (Ocean), with the actual decile lost.", pen = dfhack.pen.parse {fg = COLOR_WHITE, bg = 0}}, NEWLINE,
                             {text = "  LIGHT CYAN     100 - 109", pen = dfhack.pen.parse {fg = COLOR_LIGHTCYAN, bg = 0}}, NEWLINE,
                             {text = "  CYAN           110 - 119", pen = dfhack.pen.parse {fg = COLOR_CYAN, bg = 0}}, NEWLINE,
                             {text = "  LIGHT BLUE     120 - 129", pen = dfhack.pen.parse {fg = COLOR_LIGHTBLUE, bg = 0}}, NEWLINE,
                             {text = "  BLUE           130 - 139", pen = dfhack.pen.parse {fg = COLOR_BLUE, bg = 0}}, NEWLINE,
                             {text = "  LIGHT GREEN    140 - 149", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, NEWLINE,
                             {text = "  GREEN          150 - 159 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, NEWLINE,
                             {text = "  YELLOW         160 - 169 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_YELLOW, bg = 0}}, NEWLINE,
                             {text = "  LIGHT MAGENTA  170 - 179 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_LIGHTMAGENTA, bg = 0}}, NEWLINE,
                             {text = "  LIGHT RED      180 - 189 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_LIGHTRED, bg = 0}}, NEWLINE,
                             {text = "  RED            190 - 199 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_RED, bg = 0}}, NEWLINE,
                             {text = "  GREY           200 - 219 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_GREY, bg = 0}}, NEWLINE,
                             {text = "  DARK GREY    > 219 (Mountain), with the actual decile lost.", pen = dfhack.pen.parse {fg = COLOR_DARKGREY, bg = 0}}},
                     frame = {l = 17, t = 2, y_align = 0}}
                     
    Elevation_Page.Heading_Label_X =
      widgets.Label {text = Fit_Right (tostring (x), 2),
                     frame = {l = 18, w = 3, t = 0, yalign = 0}}
                                          
    Elevation_Page.Heading_Label_Y = 
      widgets.Label {text = Fit_Right (tostring (y), 2),
                     frame = {l = 26,
                              w = 2,
                              t = 0,
                              yalign = 0}}
                                          
    Elevation_Page.Region_Elevation_Edit =
      widgets.Label {text = Fit_Right (region.elevation [x] [y], 4),
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 40,
                              w = 5,
                              t = 6,
                              yalign = 0}}
                     
    Elevation_Page.Grid = Grid {frame = {l = 1, t = 2, w = 17, h = 17},
                                width = 17,
                                height = 17,
                                visible = true}
    
    local elevationPage = widgets.Panel {
      subviews = {Elevation_Page.Heading_Label,
                  Elevation_Page.Body_Label,
                  Elevation_Page.Heading_Label_X,
                  Elevation_Page.Heading_Label_Y,
                  Elevation_Page.Region_Elevation_Edit,
                  Elevation_Page.Grid}}
    
    Biome_Page.Heading_Label = 
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},
                             " X =   , Y =    Biome Manipulation"},
                     frame = {l = 0, t = 0, y_align = 0}}
    
    Biome_Page.Body_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.elevation.key,
                                      key_sep = '()'},
                             {text = " Elevation ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.river.key,
                                      key_sep = '()'},
                             {text = " River     ",
                              pen = COLOR_LIGHTBLUE},
                             top_cavern_key,
                             top_cavern_text, NEWLINE,
                             mid_cavern_key,
                             mid_cavern_text,
                             low_cavern_key,
                             low_cavern_text,
                             {text = "",
                                      key = keybindings.feature.key,
                                      key_sep = '()'},
                             {text = " Feature",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                      key = keybindings.hide.key,
                                      key_sep = '()'},
                             {text = " Hide",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "",
                                      key = keybindings.command_biome.key,
                                      key_sep = '()'},
                             {text = " Region Biome:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             " The Biome information refers to the world tile defining the", NEWLINE,
                             " biome of the region tile. The Biome key is:", NEWLINE,
                             {text = "  7", pen = dfhack.pen.parse {fg = Range_Color (170), bg = 0}}, ": NW ",
                             {text = "8", pen = dfhack.pen.parse {fg = Range_Color (180), bg = 0}}, ": N    ",
                             {text = "9", pen = dfhack.pen.parse {fg = Range_Color (190), bg = 0}}, ": NE", NEWLINE,
                             {text = "  4", pen = dfhack.pen.parse {fg = Range_Color (140), bg = 0}}, ":  W ",
                             {text = "5", pen = dfhack.pen.parse {fg = Range_Color (150), bg = 0}}, ": Here ",
                             {text = "6", pen = dfhack.pen.parse {fg = Range_Color (160), bg = 0}}, ":  E", NEWLINE,
                             {text = "  1", pen = dfhack.pen.parse {fg = Range_Color (110), bg = 0}}, ": SW ",
                             {text = "2", pen = dfhack.pen.parse {fg = Range_Color (120), bg = 0}}, ": S    ",
                             {text = "3", pen = dfhack.pen.parse {fg = Range_Color (130), bg = 0}}, ": SE"},
                     frame = {l = 17, t = 2, y_align = 0}}
                              
    Biome_Page.Heading_Label_X =
      widgets.Label {text = Fit_Right (tostring (x), 2),
                     frame = {l = 18, w = 3, t = 0, yalign = 0}}
                                          
    Biome_Page.Heading_Label_Y = 
      widgets.Label {text = Fit_Right (tostring (y), 2),
                     frame = {l = 26,
                              w = 2,
                              t = 0,
                              yalign = 0}}
                                          
    Biome_Page.Region_Biome_Edit = 
      widgets.Label {text = Fit_Right (region.biome [x] [y], 1),
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 37,
                              w = 2,
                              t = 6,
                              yalign = 0}}
                     
    Biome_Page.Grid = Grid {frame = {l = 1, t = 2, w = 17, h = 17},
                                width = 17,
                                height = 17,
                                visible = true}
    
    local biomePage = widgets.Panel {
      subviews = {Biome_Page.Heading_Label,
                  Biome_Page.Body_Label,
                  Biome_Page.Heading_Label_X,
                  Biome_Page.Heading_Label_Y,
                  Biome_Page.Region_Biome_Edit,
                  Biome_Page.Grid}}
                     
    River_Page.Heading_Label = 
      widgets.Label {text = {{text = "Help/Info",
                                      key = keybindings.help.key,
                                      key_sep = '()'},
                             " X =   , Y =    River Manipulation"},
                     frame = {l = 0, t = 0, y_align = 0}}
    
    River_Page.Body_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.elevation.key,
                                      key_sep = '()'},
                             {text = " Elevation ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.biome.key,
                                      key_sep = '()'},
                             {text = " Biome     ",
                              pen = COLOR_LIGHTBLUE},
                             top_cavern_key,
                             top_cavern_text, NEWLINE,
                             mid_cavern_key,
                             mid_cavern_text,
                             low_cavern_key,
                             low_cavern_text,                             
                             {text = "",
                                     key = keybindings.feature.key,
                                     key_sep = '()'},
                             {text = " Feature",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                     key = keybindings.hide.key,
                                     key_sep = '()'},
                             {text = " Hide",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "",
                                      key = keybindings.command_vertical.key,
                                      key_sep = '()'},
                             {text = " Vertical:      ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.command_horizontal.key,
                                      key_sep = '()'},
                             {text = " Horizontal:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE, NEWLINE,
                             {text = "",
                                      key = keybindings.command_is_brook.key,
                                      key_sep = '()'},
                             {text = " Is Brook:",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 17, t = 2, y_align = 0}}
                     
    River_Page.Heading_Label_X =
      widgets.Label {text = Fit_Right (tostring (x), 2),
                     frame = {l = 18, w = 3, t = 0, yalign = 0}}
                                          
    River_Page.Heading_Label_Y = 
      widgets.Label {text = Fit_Right (tostring (y), 2),
                     frame = {l = 26,
                              w = 2,
                              t = 0,
                              yalign = 0}}
                                          
    River_Page.Elevation_Label =
      widgets.Label {text = {{text = "",
                              key = keybindings.command_river_elevation.key,
                              key_sep = '()'},
                             {text = " River Elevation:",
                              pen = COLOR_LIGHTBLUE},
                              "     Ground Elevation: "},
                     frame = {l = 17, t = 5, yalign = 0},
                     visible = River_Elevation_Image (x, y) ~= ""}
                                             
    River_Page.Elevation_Edit = 
      widgets.Label {text = Fit_Right (River_Elevation_Image (x, y), 4),
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 38, 
                              w = 5, 
                              t = 5, 
                              yalign = 0},
                     visible = River_Elevation_Image (x, y) ~= ""}
                        
    River_Page.Ground_Elevation = 
      widgets.Label {text = Fit_Right (region.elevation [x] [y], 4),
                     text_pen = COLOR_WHITE,
                     frame = {l = 60, 
                              w = 5, 
                              t = 5, 
                              yalign = 0},
                     visible = River_Elevation_Image (x, y) ~= ""}
                        
    River_Page.Visibility_List =  {}
    
    River_Page.Visibility_List ["River_Elevation"] = {River_Page.Elevation_Label,
                                                      River_Page.Elevation_Edit,
                                                      River_Page.Ground_Elevation}
                                                   
    River_Page.Vertical_Edit =
      widgets.Label {text = Vertical_River_Image [region.rivers_vertical.active [x] [y]],
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 32, w = 6, t = 6, yalign = 0}}
                     
    River_Page.X_Label =
      widgets.Label {text = {{text = "",
                              key = keybindings.command_river_x.key,
                              key_sep = '()'},
                             {text = " x min:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                              key = keybindings.command_river_X.key,
                              key_sep = '()'},
                             {text = " X Max:",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 21, t = 7, yalign = 0},
                     visible = region.rivers_vertical.active [x] [y] ~= 0}
                     
    River_Page.X_Min_Edit =
      widgets.Label {text = Fit_Right (region.rivers_vertical.x_min [x] [y], 2),
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 33, w = 3, t = 7, yalign = 0},
                     visible = region.rivers_vertical.active [x] [y] ~= 0}
    
    River_Page.X_Max_Edit =
      widgets.Label {text = Fit_Right (region.rivers_vertical.x_max [x] [y], 2),
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 33, w = 3, t = 8, yalign = 0},
                     visible = region.rivers_vertical.active [x] [y] ~= 0}
      
    River_Page.Visibility_List ["Vertical"] = {River_Page.X_Label,
                                               River_Page.X_Min_Edit,
                                               River_Page.X_Max_Edit} 
    River_Page.Horizontal_Edit =
      widgets.Label {text = Horizontal_River_Image [region.rivers_horizontal.active [x] [y]],
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 54, w = 5, t = 6, yalign = 0}}
                         
    River_Page.Y_Label =
      widgets.Label {text = {{text = "",
                              key = keybindings.command_river_y.key,
                              key_sep = '()'},
                             {text = " y min:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                              key = keybindings.command_river_Y.key,
                              key_sep = '()'},
                             {text = " Y Max:",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 41, t = 7, yalign = 0},
                     visible = region.rivers_vertical.active [x] [y] ~= 0}
                     
    River_Page.Y_Min_Edit =
      widgets.Label {text = Fit_Right (region.rivers_horizontal.y_min [x] [y], 2),
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 53, w = 3, t = 7, yalign = 0},
                     visible = region.rivers_horizontal.active [x] [y] ~= 0}

    River_Page.Y_Max_Edit =
      widgets.Label {text = Fit_Right (region.rivers_horizontal.y_max [x] [y], 2),
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 53, w = 3, t = 8, yalign = 0},
                     active = false,
                     visible = region.rivers_horizontal.active [x] [y] ~= 0}
                         
    River_Page.Visibility_List ["Horizontal"] = {River_Page.Y_Label,
                                                 River_Page.Y_Min_Edit,
                                                 River_Page.Y_Max_Edit}
    
    River_Page.Is_Brook_Edit =
      widgets.Label {text = Bool_Image (df.global.world.world_data.region_map[region.pos.x]:_displace(region.pos.y).flags.is_brook),
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 34, w = 2, t = 9, yalign = 0}}
                     
    if df.global.world.world_data.region_map[region.pos.x]:_displace(region.pos.y).flags.has_river then
      local r_entry = "None"
      local r_exit = "None"
      
      for i, river in ipairs (df.global.world.world_data.rivers) do
        for k, x_pos in ipairs (river.path.x) do
          if x_pos == region.pos.x and
             river.path.y [k] == region.pos.y then
            if k ~= 0 then
              if river.path.x [k - 1] < x_pos then
                r_entry = "West"
              
              elseif river.path.x [k - 1] > x_pos then
                r_entry = "East"
                
              elseif river.path.y [k - 1] < river.path.y [k] then
                r_entry = "North"
                
              else
                r_entry = "South"
              end
            end

            if k < #river.path.x - 1 then
              if river.path.x [k + 1] < x_pos then
                r_exit = "West"
                
              elseif river.path.x [k + 1] > x_pos then
                r_exit = "East"
                
              elseif river.path.y [k + 1] < river.path.y [k] then
                r_exit = "North"
                
              else
                r_exit = "South"
              end
              
            else
              if river.end_pos.x < x_pos then
                r_exit = "West"
                
              elseif river.end_pos.x > x_pos then
                r_exit = "East"
                
              elseif river.end_pos.y < river.path.y [k] then
                r_exit = "North"
                
              else
                r_exit = "South"
              end
            end
            
            break
          end
        end
      end
      
      River_Page.River_Entry =
        widgets.Label {text = "River entry: " .. r_entry,
                       frame = {l = 18, t = 11, yalign = 0},
                       visible = r_entry ~= "None"}
    
      River_Page.River_Exit =
        widgets.Label {text = "River exit: " .. r_exit,
                       frame = {l = 38, t = 11, yalign = 0}}
                       
    else
      River_Page.River_Entry =
        widgets.Label {text = "River entry:",
                       frame = {l = 18, t = 11, yalign = 0},
                       visible = false}
    
      River_Page.River_Exit =
        widgets.Label {text = "River exit:",
                       frame = {l = 38, t = 11, yalign = 0},
                       visible = false}    
    end
    
    River_Page.River_Help =
        widgets.Label {text = {{text = "The elevation color coding is the same as for the Elevation."}, NEWLINE, 
                               {text = "See that page or the Help if you can't see the key below."}, NEWLINE,
                               {text = "The color ranges are:"}, NEWLINE,
                               {text = "  WHITE        < 100 (Ocean), with the actual decile lost.", pen = dfhack.pen.parse {fg = COLOR_WHITE, bg = 0}}, NEWLINE,
                               {text = "  LIGHT CYAN     100 - 109", pen = dfhack.pen.parse {fg = COLOR_LIGHTCYAN, bg = 0}}, NEWLINE,
                               {text = "  CYAN           110 - 119", pen = dfhack.pen.parse {fg = COLOR_CYAN, bg = 0}}, NEWLINE,
                               {text = "  LIGHT BLUE     120 - 129", pen = dfhack.pen.parse {fg = COLOR_LIGHTBLUE, bg = 0}}, NEWLINE,
                               {text = "  BLUE           130 - 139", pen = dfhack.pen.parse {fg = COLOR_BLUE, bg = 0}}, NEWLINE,
                               {text = "  LIGHT GREEN    140 - 149", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, NEWLINE,
                               {text = "  GREEN          150 - 159 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, NEWLINE,
                               {text = "  YELLOW         160 - 169 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_YELLOW, bg = 0}}, NEWLINE,
                               {text = "  LIGHT MAGENTA  170 - 179 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_LIGHTMAGENTA, bg = 0}}, NEWLINE,
                               {text = "  LIGHT RED      180 - 189 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_LIGHTRED, bg = 0}}, NEWLINE,
                               {text = "  RED            190 - 199 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_RED, bg = 0}}, NEWLINE,
                               {text = "  GREY           200 - 219 (Mountain)", pen = dfhack.pen.parse {fg = COLOR_GREY, bg = 0}}, NEWLINE,
                               {text = "  DARK GREY    > 219 (Mountain), with the actual decile lost.", pen = dfhack.pen.parse {fg = COLOR_DARKGREY, bg = 0}}},
                       frame = {l = 18, t = 13, yalign = 0}}

    River_Page.Grid = Grid {frame = {l = 1, t = 2, w = 16, h = 16},
                            width = 16,
                            height = 16,
                            visible = true}
    
    local riverPage = widgets.Panel {
      subviews = {River_Page.Heading_Label,
                  River_Page.Body_Label,
                  River_Page.Heading_Label_X,
                  River_Page.Heading_Label_Y,
                  River_Page.Elevation_Label,
                  River_Page.Elevation_Edit,
                  River_Page.Ground_Elevation,
                  River_Page.Vertical_Edit,
                  River_Page.X_Label,
                  River_Page.X_Min_Edit,
                  River_Page.X_Max_Edit,
                  River_Page.Horizontal_Edit,
                  River_Page.Y_Label,
                  River_Page.Y_Min_Edit,
                  River_Page.Y_Max_Edit,
                  River_Page.Is_Brook_Edit,
                  River_Page.River_Entry,
                  River_Page.River_Exit,
                  River_Page.River_Help,
                  River_Page.Grid}}

    local cavern_info_text = {"The cavern lake abundance is poorly understood. The value is",
                              "specified as 4 bits represented as a Hexadecimal value",
                              "(0 - 9, plus A - F for 10 - 15). It is unclear if the bits",
                              "indicate geographic location of the water or not, (if so,",
                              "NW, NE, SW, SE for 1/2/4/8), and it's subject to other",
                              "restrictions."}
   
    Top_Cavern_Page.Heading_Label = 
      widgets.Label {text = {{text = "Help/Info",
                              key = keybindings.help.key,
                              key_sep = '()'},
                             " X =   , Y =    First (Top) Cavern Manipulation"},
                     frame = {l = 0, t = 0, y_align = 0}}
    
    Top_Cavern_Page.Body_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.elevation.key,
                                      key_sep = '()'},
                             {text = " Elevation ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.biome.key,
                                      key_sep = '()'},
                             {text = " Biome     ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.river.key,
                                      key_sep = '()'},
                             {text = " River",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             mid_cavern_key,
                             mid_cavern_text,
                             low_cavern_key,
                             low_cavern_text,
                             {text = "",
                                      key = keybindings.feature.key,
                                      key_sep = '()'},
                             {text = " Feature",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                      key = keybindings.hide.key,
                                      key_sep = '()'},
                             {text = " Hide",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "",
                                      key = keybindings.command_water.key,
                                      key_sep = '()'},
                             {text = " Cavern Water:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             cavern_info_text [1], NEWLINE,
                             cavern_info_text [2], NEWLINE,
                             cavern_info_text [3], NEWLINE,
                             cavern_info_text [4], NEWLINE,
                             cavern_info_text [5], NEWLINE,
                             cavern_info_text [6]},
                     frame = {l = 17, t = 2, y_align = 0}}
                     
    Top_Cavern_Page.Heading_Label_X =
      widgets.Label {text = Fit_Right (tostring (x), 2),
                     frame = {l = 18, w = 3, t = 0, yalign = 0}}
                                          
    Top_Cavern_Page.Heading_Label_Y = 
      widgets.Label {text = Fit_Right (tostring (y), 2),
                     frame = {l = 26,
                              w = 2,
                              t = 0,
                              yalign = 0}}
                                          
    Top_Cavern_Page.Water_Edit =
      widgets.Label {text = '0',
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 36, w = 2, t = 6, yalign = 0},
                     visible = df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 1}
                     
    Top_Cavern_Page.Grid = Grid {frame = {l = 1, t = 2, w = 16, h = 16},
                                 width = 16,
                                 height = 16,
                                 visible = true}
    
    local topCavernPage = widgets.Panel {
      subviews = {Top_Cavern_Page.Heading_Label,
                  Top_Cavern_Page.Body_Label,
                  Top_Cavern_Page.Heading_Label_X,
                  Top_Cavern_Page.Heading_Label_Y,
                  Top_Cavern_Page.Water_Edit,
                  Top_Cavern_Page.Grid}}
                  
    Mid_Cavern_Page.Heading_Label = 
      widgets.Label {text = {{text = "Help/Info",
                              key = keybindings.help.key,
                              key_sep = '()'},
                             " X =   , Y =    Second (Mid) Cavern Manipulation"},
                     frame = {l = 0, t = 0, y_align = 0}}
    
    Mid_Cavern_Page.Body_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.elevation.key,
                                      key_sep = '()'},
                             {text = " Elevation ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.biome.key,
                                      key_sep = '()'},
                             {text = " Biome     ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.river.key,
                                      key_sep = '()'},
                             {text = " River",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             top_cavern_key,
                             top_cavern_text,
                             low_cavern_key,
                             low_cavern_text,
                             {text = "",
                                      key = keybindings.feature.key,
                                      key_sep = '()'},
                             {text = " Feature",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                      key = keybindings.hide.key,
                                      key_sep = '()'},
                             {text = " Hide",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "",
                                      key = keybindings.command_water.key,
                                      key_sep = '()'},
                             {text = " Cavern Water:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             cavern_info_text [1], NEWLINE,
                             cavern_info_text [2], NEWLINE,
                             cavern_info_text [3], NEWLINE,
                             cavern_info_text [4], NEWLINE,
                             cavern_info_text [5], NEWLINE,
                             cavern_info_text [6]},
                     frame = {l = 17, t = 2, y_align = 0}}
                     
    Mid_Cavern_Page.Heading_Label_X =
      widgets.Label {text = Fit_Right (tostring (x), 2),
                     frame = {l = 18, w = 3, t = 0, yalign = 0}}
                                          
    Mid_Cavern_Page.Heading_Label_Y = 
      widgets.Label {text = Fit_Right (tostring (y), 2),
                     frame = {l = 26,
                              w = 2,
                              t = 0,
                              yalign = 0}}
                                          
    Mid_Cavern_Page.Water_Edit =
      widgets.Label {text = '0',
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 36, w = 2, t = 6, yalign = 0},
                     visible = df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 2}
                     
    Mid_Cavern_Page.Grid = Grid {frame = {l = 1, t = 2, w = 16, h = 16},
                                 width = 16,
                                 height = 16,
                                 visible = true}
    
    local midCavernPage = widgets.Panel {
      subviews = {Mid_Cavern_Page.Heading_Label,
                  Mid_Cavern_Page.Body_Label,
                  Mid_Cavern_Page.Heading_Label_X,
                  Mid_Cavern_Page.Heading_Label_Y,
                  Mid_Cavern_Page.Water_Edit,
                  Mid_Cavern_Page.Grid}}
                  
    Low_Cavern_Page.Heading_Label = 
      widgets.Label {text = {{text = "Help/Info",
                              key = keybindings.help.key,
                              key_sep = '()'},
                             " X =   , Y =    Third (Low) Cavern Manipulation"},
                     frame = {l = 0, t = 0, y_align = 0}}
    
    Low_Cavern_Page.Body_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.elevation.key,
                                      key_sep = '()'},
                             {text = " Elevation ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.biome.key,
                                      key_sep = '()'},
                             {text = " Biome     ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.river.key,
                                      key_sep = '()'},
                             {text = " River",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             top_cavern_key,
                             top_cavern_text,
                             mid_cavern_key,
                             mid_cavern_text,
                             {text = "",
                                      key = keybindings.feature.key,
                                      key_sep = '()'},
                             {text = " Feature",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             {text = "",
                                      key = keybindings.hide.key,
                                      key_sep = '()'},
                             {text = " Hide",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             {text = "",
                                      key = keybindings.command_water.key,
                                      key_sep = '()'},
                             {text = " Cavern Water:",
                              pen = COLOR_LIGHTBLUE}, NEWLINE, NEWLINE,
                             cavern_info_text [1], NEWLINE,
                             cavern_info_text [2], NEWLINE,
                             cavern_info_text [3], NEWLINE,
                             cavern_info_text [4], NEWLINE,
                             cavern_info_text [5], NEWLINE,
                             cavern_info_text [6]},
                     frame = {l = 17, t = 2, y_align = 0}}
                     
    Low_Cavern_Page.Heading_Label_X =
      widgets.Label {text = Fit_Right (tostring (x), 2),
                     frame = {l = 18, w = 3, t = 0, yalign = 0}}
                                          
    Low_Cavern_Page.Heading_Label_Y = 
      widgets.Label {text = Fit_Right (tostring (y), 2),
                     frame = {l = 26,
                              w = 2,
                              t = 0,
                              yalign = 0}}
                                          
    Low_Cavern_Page.Water_Edit =
      widgets.Label {text = '0',
                     text_pen = COLOR_LIGHTCYAN,
                     frame = {l = 36, w = 2, t = 6, yalign = 0},
                     visible = df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 3}
                     
    Low_Cavern_Page.Grid = Grid {frame = {l = 1, t = 2, w = 16, h = 16},
                                 width = 16,
                                 height = 16,
                                 visible = true}
    
    local lowCavernPage = widgets.Panel {
      subviews = {Low_Cavern_Page.Heading_Label,
                  Low_Cavern_Page.Body_Label,
                  Low_Cavern_Page.Heading_Label_X,
                  Low_Cavern_Page.Heading_Label_Y,
                  Low_Cavern_Page.Water_Edit,
                  Low_Cavern_Page.Grid}}
                                    
    Feature_Page.Heading_Label = 
      widgets.Label {text = {{text = "Help/Info",
                              key = keybindings.help.key,
                              key_sep = '()'},
                             " X =   , Y =    Feature Manipulation"},
                     frame = {l = 0, t = 0, y_align = 0}}
    
    Feature_Page.Body_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.elevation.key,
                                      key_sep = '()'},
                             {text = " Elevation ",                             
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.biome.key,
                                      key_sep = '()'},
                             {text = " Biome     ",
                              pen = COLOR_LIGHTBLUE},
                             {text = "",
                                      key = keybindings.river.key,
                                      key_sep = '()'},
                             {text = " River",
                              pen = COLOR_LIGHTBLUE}, NEWLINE,
                             top_cavern_key,
                             top_cavern_text,
                             mid_cavern_key,
                             mid_cavern_text,
                             low_cavern_key,
                             low_cavern_text, NEWLINE,
                             {text = "",
                                      key = keybindings.hide.key,
                                      key_sep = '()'},
                             {text = " Hide",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 17, t = 2, y_align = 0}}
                     
    Feature_Page.Heading_Label_X =
      widgets.Label {text = Fit_Right (tostring (x), 2),
                     frame = {l = 18, w = 3, t = 0, yalign = 0}}
                                          
    Feature_Page.Heading_Label_Y = 
      widgets.Label {text = Fit_Right (tostring (y), 2),
                     frame = {l = 26,
                              w = 2,
                              t = 0,
                              yalign = 0}}
                       
    Feature_Page.Add_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.command_feature_add.key,
                                      key_sep = '()'},
                             {text = " Add Feature",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 55, t = 6, yalign = 0},
                     visible = true}
                       
    Feature_Page.Remove_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.command_feature_remove.key,
                                      key_sep = '()'},
                             {text = " Remove Feature",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 55, t = 7, yalign = 0},
                     visible = true}
                       
    Feature_Page.Change_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.command_feature_change.key,
                                      key_sep = '()'},
                             {text = " Change Feature Top",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 55, t = 8, yalign = 0},
                     visible = true}
                       
    Feature_Page.Move_Label = 
      widgets.Label {text = {{text = "",
                                      key = keybindings.command_feature_move.key,
                                      key_sep = '()'},
                             {text = " Move Spire",
                              pen = COLOR_LIGHTBLUE}},
                     frame = {l = 55, t = 9, yalign = 0},
                     visible = true}
                       
    Feature_Page.Feature_List = {}
    
    Feature_Page.List =
      widgets.List {view_id = "Features",
                    choices = {},
                    frame = {l = 18, t = 6, yalign = 0},
                    text_pen = COLOR_DARKGREY,
                    cursor_pen = COLOR_YELLOW,
                    inactive_pen = COLOR_GREY,
                    scroll_keys = {SECONDSCROLL_UP = -1,
                                   SECONDSCROLL_DOWN = 1,
                                   STANDARDSCROLL_PAGEUP = "-page",
                                   STANDARDSCROLL_PAGEDOWN = "+page"},
                    active = true,
                    on_select = (function (index, choice) Show_Feature_Context_Keys (index, choice) end)}
                    
    Feature_Page.Key_Label =
      widgets.Label {text = {"Feature display key:", NEWLINE,
                             {text = "*:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTMAGENTA, bg = 0}}, " Multiple features", NEWLINE, 
                             {text = "S/1/2:  ", pen = dfhack.pen.parse {fg = COLOR_WHITE, bg = 0}}, " Passage from Surface/Cavern 1/Cavern 2", NEWLINE,
                             {text = "1/2:    ", pen = dfhack.pen.parse {fg = COLOR_YELLOW, bg = 0}}, " Pit from Cavern 1/Cavern 2", NEWLINE,       
                             {text = "1/2/3:  ", pen = dfhack.pen.parse {fg = COLOR_LIGHTRED, bg = 0}}, " Magma Pool from Cavern 1/Cavern 2/Cavern 3", NEWLINE,
                             {text = "V:      ", pen = dfhack.pen.parse {fg = COLOR_RED, bg = 0}}, " Volcano", NEWLINE,
                             {text = "1/2/3/M:", pen = dfhack.pen.parse {fg = COLOR_LIGHTCYAN, bg = 0}}, " Adamantine Spire from Cavern 1/Cavern 2/Cavern 3/Magma Sea", NEWLINE,
                             {text = "R:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTBLUE, bg = 0}}, " River", NEWLINE,
                             {text = "P:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, " PlayerFortress", {text = " D: ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, "DarkFortress", NEWLINE,
                             {text = "m:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, " MountainHalls ", {text = " F: ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, "ForestRetreat", NEWLINE,
                             {text = "T:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, " Town          ", {text = " c: ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, "Cave", NEWLINE,
                             {text = "t:      ", pen = dfhack.pen.parse {fg = COLOR_LIGHTGREEN, bg = 0}}, " Tomb          ", {text = " i: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "ImportantLocation", NEWLINE,
                             {text = "l:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " Lair          ", {text = " L: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "Labyrinth", NEWLINE,
                             {text = "S:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " Shrine        ", {text = " f: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "Fortress", NEWLINE,
                             {text = "C:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " Camp          ", {text = " V: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "Vault", NEWLINE,
                             {text = "M:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " Monument      ", NEWLINE,
                             {text = "?:      ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}},      " ?LairShrine?  ", {text = " !: ", pen = dfhack.pen.parse {fg = COLOR_GREEN, bg = 0}}, "UnknownSite", NEWLINE},
                     frame = {l = 1, t = 19, yalign = 0}}

    Feature_Page.Grid = Grid {frame = {l = 1, t = 2, w = 16, h = 16},
                              width = 16,
                              height = 16,
                              visible = true}
    
    local featurePage = widgets.Panel {
      subviews = {Feature_Page.Heading_Label,
                  Feature_Page.Body_Label,
                  Feature_Page.Heading_Label_X,
                  Feature_Page.Heading_Label_Y,
                  Feature_Page.List,
                  Feature_Page.Add_Label,
                  Feature_Page.Remove_Label,
                  Feature_Page.Change_Label,
                  Feature_Page.Move_Label,
                  Feature_Page.Key_Label,
                  Feature_Page.Grid}}
                  
    Make_Elevation (x, y)
    Make_Biome (x, y)
    Make_River (x, y)
    Make_Caverns (x, y)
    Make_Features (x, y)
    
    Help_Page.Help = widgets.Label {text = Help_Pages [Current_Help_Page] [2] (),
                                    frame = {l = 1, t = 0, yalign = 0}}
                                    
    helpPage = widgets.Panel {
        subviews = {Help_Page.Help}}
                    
    local pages = widgets.Pages 
      {subviews = {hiddenPage,
                   elevationPage,
                   biomePage,
                   riverPage,
                   topCavernPage,
                   midCavernPage,
                   lowCavernPage,
                   featurePage,
                   helpPage},view_id = "pages",
                   }

    Focus = "Elevation"
    pages:setSelected (Views [Focus])
      
    self:addviews {pages}
  end

  --============================================================

  function Ui:updateElevation (value)
    if not tonumber (value) or 
       tonumber (value) < -999 or 
       tonumber (value) > 250 then
      dialog.showMessage ("Error!", "The Elevation legal range is -999 - 250", COLOR_RED)
    else
      region.elevation [x] [y] = tonumber (value)
    end
    
    Update (x, y, self.subviews.pages)      
  end
  
  --==============================================================
  
  function Ui:updateBiome (value)
    if not tonumber (value) or 
       tonumber (value) < 1 or 
       tonumber (value) > 9 then
      dialog.showMessage ("Error!", "The Biome legal range is 1 - 9", COLOR_RED)
    else
      region.biome [x] [y] = tonumber (value)
    end
    
    Update (x, y, self.subviews.pages)      
  end
  
  --==============================================================

  function Ui:flattenRegion ()
    for i = 0, #region.elevation - 1 do
      for k = 0, #region.elevation [0] -1 do
        region.elevation [i] [k] = region.elevation [x] [y]
      end
    end
    
    Make_Elevation (x, y)
    Update (x, y, self.subviews.pages)
  end
  
  --==============================================================
  
  function Ui:updateRiverElevation (value)
    if not tonumber (value) or 
       tonumber (value) < -999 or 
       tonumber (value) > 250 then
      dialog.showMessage ("Error!", "The Elevation legal range is -999 - 250", COLOR_RED)

    else
      if region.rivers_horizontal.active [x] [y] ~= 0 then
        region.rivers_horizontal.elevation [x] [y] = tonumber (value)
      end

      if region.rivers_vertical.active [x] [y] ~= 0 then
        region.rivers_vertical.elevation [x] [y] = tonumber (value)
      end
    end
    
    Update (x, y, self.subviews.pages)
  end
  
  --==============================================================
  
  function Ui:updateRiverVerticalActive (value)
    if string.upper (value) == "SOUTH" or
       string.upper (value) == "NORTH" then
      if region.rivers_vertical.active [x] [y] == 0 then
        region.rivers_vertical.x_min [x] [y] = 23
        region.rivers_vertical.x_max [x] [y] = 25

        if region.rivers_horizontal.active [x] [y] ~= 0 then
          region.rivers_vertical.elevation [x] [y] = region.rivers_horizontal.elevation [x] [y]
          
        else
          region.rivers_vertical.elevation [x] [y] = region.elevation [x] [y]
        end
      end      

      if string.upper (value) == "SOUTH" then
        region.rivers_vertical.active [x] [y] = 1
      else
        region.rivers_vertical.active [x] [y] = -1
      end
            
    elseif string.upper (value) == "NONE" then
      region.rivers_vertical.active [x] [y] = 0
      region.rivers_vertical.elevation [x] [y] = 100
      region.rivers_vertical.x_min [x] [y] = -30000
      region.rivers_vertical.x_max [x] [y] = -30000

    else
      dialog.showMessage ("Error!", "The legal values are 'None', 'North', and 'South'", COLOR_RED)          
    end
    
    Update (x, y, self.subviews.pages)
  end

  --==============================================================
  
  function Ui:updateRiverVerticalXMin (value)
    if not tonumber (value) or
       tonumber (value) < 0 or
       tonumber (value) > 47 then
      dialog.showMessage ("Error!", "The X Min legal range is 0 - 47", COLOR_RED)
    
    elseif tonumber (value) > region.rivers_vertical.x_max [x] [y] then
      dialog.showMessage ("Error!", "The X Min value cannot be larger than X Max", COLOR_RED)
      
    else
      region.rivers_vertical.x_min [x] [y] = tonumber (value)
    end
    
    Update (x, y, self.subviews.pages)
  end
  
  --==============================================================
  
  function Ui:updateRiverVerticalXMax (value)
    if not tonumber (value) or
       tonumber (value) < 0 or
       tonumber (value) > 47 then
      dialog.showMessage ("Error!", "The X Max legal range is 0 - 47", COLOR_RED)
    
    elseif tonumber (value) < region.rivers_vertical.x_min [x] [y] then
      dialog.showMessage ("Error!", "The X Max value cannot be smaller than X Min", COLOR_RED)
      
    else
      region.rivers_vertical.x_max [x] [y] = tonumber (value)
    end
    
    Update (x, y, self.subviews.pages)
  end
  
  --==============================================================
  
  function Ui:updateRiverHorizontalActive (value)
    if string.upper (value) == "EAST" or
       string.upper (value) == "WEST" then
      if region.rivers_horizontal.active [x] [y] == 0 then
        region.rivers_horizontal.y_min [x] [y] = 23
        region.rivers_horizontal.y_max [x] [y] = 25

        if region.rivers_vertical.active [x] [y] ~= 0 then
          region.rivers_horizontal.elevation [x] [y] = region.rivers_vertical.elevation [x] [y]
          
        else
          region.rivers_horizontal.elevation [x] [y] = region.elevation [x] [y]
        end
      end      

      if string.upper (value) == "WEST" then
        region.rivers_horizontal.active [x] [y] = 1
      else
        region.rivers_horizontal.active [x] [y] = -1
      end
            
    elseif string.upper (value) == "NONE" then
      region.rivers_horizontal.active [x] [y] = 0
      region.rivers_horizontal.elevation [x] [y] = 100
      region.rivers_horizontal.y_min [x] [y] = -30000
      region.rivers_horizontal.y_max [x] [y] = -30000
    else
      dialog.showMessage ("Error!", "The legal values are 'None', 'East', and 'West'", COLOR_RED)      
    end
    
    Update (x, y, self.subviews.pages)
  end

  --==============================================================
  
  function Ui:updateRiverHorizontalYMin (value)
    if not tonumber (value) or
       tonumber (value) < 0 or
       tonumber (value) > 47 then
      dialog.showMessage ("Error!", "The Y Min legal range is 0 - 47", COLOR_RED)
    
    elseif tonumber (value) > region.rivers_horizontal.y_max [x] [y] then
      dialog.showMessage ("Error!", "The Y Min value cannot be larger than Y Max", COLOR_RED)
      
    else
      region.rivers_horizontal.y_min [x] [y] = tonumber (value)
    end
    
    Update (x, y, self.subviews.pages)
  end
  
  --==============================================================
  
  function Ui:updateRiverHorizontalYMax (value)
    if not tonumber (value) or
       tonumber (value) < 0 or
       tonumber (value) > 47 then
      dialog.showMessage ("Error!", "The Y Max legal range is 0 - 47", COLOR_RED)
    
    elseif tonumber (value) < region.rivers_horizontal.y_min [x] [y] then
      dialog.showMessage ("Error!", "The Y Max value cannot be smaller than Y Min", COLOR_RED)
      
    else
      region.rivers_horizontal.y_max [x] [y] = tonumber (value)
    end
    
    Update (x, y, self.subviews.pages)
  end

  --==============================================================

  function Ui:updateCavernWater (value)
    local val
    local cavern
    
    if (tonumber (value) and (tonumber (value) < 0 or tonumber (value) > 9)) or
       (not tonumber (value) and
        (string.upper (value) ~= 'A' and
         string.upper (value) ~= 'B' and
         string.upper (value) ~= 'C' and
         string.upper (value) ~= 'D' and
         string.upper (value) ~= 'E' and
         string.upper (value) ~= 'F')) then
      dialog.showMessage ("Error!", "The legal values are hex values, i.e. 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, and F", COLOR_RED)
      return
    end
    
    if tonumber (value) then
      val = tonumber (value)
    elseif string.upper (value) == 'A' then
      val = 10
    elseif string.upper (value) == 'B' then
      val = 11
    elseif string.upper (value) == 'C' then
      val = 12
    elseif string.upper (value) == 'D' then
      val = 13
    elseif string.upper (value) == 'E' then
      val = 14
    else
      val = 15     
    end
 
    if Focus == "Top Cavern" then
      cavern = 0
      
    elseif Focus == "Mid Cavern" then
      cavern = 1
      
    else
      cavern = 2
    end
    
    for l, feature in ipairs (df.global.world.world_data.region_details [0].features [x] [y]) do
      if feature.layer >= 0 then
        if df.global.world.world_data.underground_regions [feature.layer].layer_depth == cavern then
          for m = 0, 3 do
            feature.unk_30 [m] = (val % 2 == 1)          
            val = math.floor (val / 2)
          end
          
          break
        end
      end
    end
   
    Update (x, y, self.subviews.pages)
  end

  --==============================================================

  function Initialize_Feature (feature)
    feature.layer = -1
    feature.region_tile_idx = -1
    feature.min_z = -30000
    feature.max_z = -30000
    feature.unk_30:resize (1)
    feature.unk_38 [0] = 0
    feature.unk_38 [1] = 100
    feature.unk_38 [2] = 0
    feature.unk_38 [3] = 100
    feature.unk_38 [4] = 0
    feature.unk_38 [5] = 100
    feature.unk_38 [6] = 0
    feature.unk_38 [7] = 100
    feature.unk_38 [8] = 0
    feature.unk_38 [9] = 0
    feature.unk_38 [10] = -30000
    feature.unk_38 [11] = 100
    feature.unk_38 [12] = 100
    feature.unk_38 [13] = -1
    feature.unk_38 [14] = -1
  end
  
  --==============================================================
  
  function Ui:addFeature (index, choices)
    local region = df.global.world.world_data.region_details [0]
    local feature
    local feature_init
                
    if choices.text ==  "Volcano" then
      df.global.world.world_data.mountain_peaks:insert ("#", {new = true})
      local volcano = df.global.world.world_data.mountain_peaks [#df.global.world.world_data.mountain_peaks - 1]
      volcano.pos.x = region.pos.x
      volcano.pos.y = region.pos.y
      volcano.flags:resize (1)
      volcano.flags [0] = true
      volcano.height = df.global.world.world_data.region_map [region.pos.x]:_displace (region.pos.y).elevation
  
      df.global.world.world_data.region_map [region.pos.x]:_displace (region.pos.y).flags.is_peak = true

      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_volcanost})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = -1
      feature_init.start_y = -1
      feature_init.end_x = -1
      feature_init.end_y = -1
      feature_init.start_depth = -1
      feature_init.end_depth = 3
      feature_init.feature = df.feature_volcanost:new ()

      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = -1
      
    elseif choices.text == "Magma Pool Top Cavern 3" then
      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_magma_poolst})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = -1
      feature_init.start_y = -1
      feature_init.end_x = -1
      feature_init.end_y = -1
      feature_init.start_depth = 2
      feature_init.end_depth = 3
      feature_init.feature = df.feature_magma_poolst:new ()
    
      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = 2
    
    elseif choices.text == "Magma Pool Top Cavern 2" then
      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_magma_poolst})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = -1
      feature_init.start_y = -1
      feature_init.end_x = -1
      feature_init.end_y = -1
      feature_init.start_depth = 1
      feature_init.end_depth = 3
      feature_init.feature = df.feature_magma_poolst:new ()
    
      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = 1
    
    elseif choices.text == "Magma Pool Top Cavern 1" then
      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_magma_poolst})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = -1
      feature_init.start_y = -1
      feature_init.end_x = -1
      feature_init.end_y = -1
      feature_init.start_depth = 0
      feature_init.end_depth = 3
      feature_init.feature = df.feature_magma_poolst:new ()
    
      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = 0
    
    elseif choices.text == "Passage Cavern 2\x1a3" then
      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_cavest})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = -1
      feature_init.start_y = -1
      feature_init.end_x = -1
      feature_init.end_y = -1
      feature_init.start_depth = 1
      feature_init.end_depth = 2
      feature_init.feature = df.feature_cavest:new ()
    
      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = 1
    
    elseif choices.text == "Passage Cavern 1\x1a2" then
      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_cavest})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = -1
      feature_init.start_y = -1
      feature_init.end_x = -1
      feature_init.end_y = -1
      feature_init.start_depth = 0
      feature_init.end_depth = 1
      feature_init.feature = df.feature_cavest:new ()
    
      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = 0
    
    elseif choices.text == "Passage Surface\x1aCavern 1" then
      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_cavest})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = x
      feature_init.start_y = y
      feature_init.end_x = x
      feature_init.end_y = y
      feature_init.start_depth = -1
      feature_init.end_depth = 0
      feature_init.feature = df.feature_cavest:new ()
    
      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = -1
    
    elseif choices.text == "Pit Cavern 2\x1a3" then
      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_pitst})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = -1
      feature_init.start_y = -1
      feature_init.end_x = -1
      feature_init.end_y = -1
      feature_init.start_depth = 1
      feature_init.end_depth = 2
      feature_init.feature = df.feature_pitst:new ()
    
      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = 1
    
    elseif choices.text == "Pit Cavern 1\x1a2" then
      df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]:insert ('#', {new = df.feature_init_pitst})
        
      feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
        features.feature_init [region.pos.x % 16] [region.pos.y % 16]
          [#df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
            features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1]
            
      feature_init.start_x = -1
      feature_init.start_y = -1
      feature_init.end_x = -1
      feature_init.end_y = -1
      feature_init.start_depth = 0
      feature_init.end_depth = 1
      feature_init.feature = df.feature_pitst:new ()
    
      region.features [x] [y]:insert ("#", {new = true})      
      feature = region.features [x] [y] [#region.features [x] [y] - 1]
      feature.feature_idx = #df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).features.feature_init [region.pos.x % 16] [region.pos.y % 16] - 1
      Initialize_Feature (feature)
      feature.top_layer_idx = 0    
    end
        
    Update (x, y, self.subviews.pages)
  end

  
  --==============================================================
  
  function Ui:removeFeature (index, choices)
    local region = df.global.world.world_data.region_details [0]
    local feature
    local feature_init
                
    if choices.text ==  "Volcano" then
      for i, peak in ipairs (df.global.world.world_data.mountain_peaks) do
        if peak.flags [0] and
           peak.pos.x == region.pos.x and
           peak.pos.y == region.pos.y then
          df.global.world.world_data.mountain_peaks:erase (i) 
          break
        end
      end
      
      df.global.world.world_data.region_map [region.pos.x]:_displace (region.pos.y).flags.is_peak = false  --  Tough luck if it actually should be a peak...

      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.volcano then
            region.features [x] [y]:erase (i)
            --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
            break
          end        
        end
      end
      
    elseif choices.text == "Magma Pool Top Cavern 3" then
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.magma_pool then
            if feature_init.start_depth == 2 then
              region.features [x] [y]:erase (i)
              --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
              break
            end
          end        
        end
      end
    
    elseif choices.text == "Magma Pool Top Cavern 2" then
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.magma_pool then
            if feature_init.start_depth == 1 then
              region.features [x] [y]:erase (i)
              --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
              break
            end
          end        
        end
      end
    
    elseif choices.text == "Magma Pool Top Cavern 1" then
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.magma_pool then
            if feature_init.start_depth == 0 then
              region.features [x] [y]:erase (i)
              --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
              break
            end
          end        
        end
      end
    
    elseif choices.text == "Passage Cavern 2\x1a3" then
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.cave then
            if feature_init.start_depth == 1 then
              region.features [x] [y]:erase (i)
              --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
              break
            end
          end        
        end
      end
    
    elseif choices.text == "Passage Cavern 1\x1a2" then
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.cave then
            if feature_init.start_depth == 0 then
              region.features [x] [y]:erase (i)
              --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
              break
            end
          end        
        end
      end
    
    elseif choices.text == "Passage Surface\x1aCavern 1" then
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.cave then
            if feature_init.start_depth == -1 then
              region.features [x] [y]:erase (i)
              --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
              break
            end
          end        
        end
      end
    
    elseif choices.text == "Pit Cavern 2\x1a3" then
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.pit then
            if feature_init.start_depth == 1 then
              region.features [x] [y]:erase (i)
              --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
              break
            end
          end        
        end
      end
    
    elseif choices.text == "Pit Cavern 1\x1a2" then
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.pit then
            if feature_init.start_depth == 0 then
              region.features [x] [y]:erase (i)
              --  We won't remove the feature init entry, as that would screw up indices. This leads to resource leakage, but there shouldn't be excessive amounts of local hacking...
              break
            end
          end        
        end
      end
    end
        
    Update (x, y, self.subviews.pages)
  end

  --==============================================================
  
  function Ui:changeFeature (index, choices)
    local region = df.global.world.world_data.region_details [0]
    local feature
    local feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [Feature_Page.Feature_List [Feature_Page.List.selected].feature_index]
                
    for i, f in ipairs (region.features [x] [y]) do
      if f.feature_idx == Feature_Page.Feature_List [Feature_Page.List.selected].feature_index then
        feature = region.features [x] [y] [i]
      end
    end
    
    if choices.text == "Magma Sea" then
      feature.top_layer_idx = 3
      feature_init.start_depth = 3
      
    elseif choices.text == "Third Cavern" then
      feature.top_layer_idx = 2
      feature_init.start_depth = 2
      
    elseif choices.text == "Second Cavern" then
      feature.top_layer_idx = 1
      feature_init.start_depth = 1
      
    elseif choices.text == "First Cavern" then
      feature.top_layer_idx = 0
      feature_init.start_depth = 0
    end
    
    Update (x, y, self.subviews.pages)
  end

  --==============================================================
  
  function Ui:moveFeature (index, choices)
    local i
    local k
    local region = df.global.world.world_data.region_details [0]
    local feature_index = Feature_Page.Feature_List [Feature_Page.List.selected].feature_index
    local feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature_index]
    local new_feature
    local old_feature
                           
    if choices.text == "Northwest" then
      i = -1
      k = -1
      
    elseif choices.text == "North" then
      i = 0
      k = -1
      
    elseif choices.text == "Northeast" then
      i = 1
      k = -1
      
    elseif choices.text == "West" then
      i = -1
      k = 0
      
    elseif choices.text == "East" then
      i = 1
      k = 0
     
    elseif choices.text == "Southwest" then
      i = -1
      k = 1
     
    elseif choices.text == "South" then
      i = 0
      k = 1
      
    elseif choices.text == "Southeast" then
      i = 1
      k = 1
    end
    
    for l, feature in ipairs (region.features [x] [y]) do
      if feature.feature_idx == feature_index then
        region.features [x + i] [y + k]:insert ('#', df.world_region_feature:new ())
        new_feature = region.features [x + i] [y + k] [#region.features [x + i] [y + k] - 1]
        old_feature = region.features [x] [y] [l]
        new_feature.feature_idx = old_feature.feature_idx
        new_feature.layer = old_feature.layer
        new_feature.region_tile_idx = old_feature.region_tile_idx
        new_feature.min_z = old_feature.min_z
        new_feature.max_z = old_feature.max_z
        for m = 0, #new_feature.unk_c - 1 do
          new_feature.unk_c [m].x = old_feature.unk_c [m].x
          new_feature.unk_c [m].y = old_feature.unk_c [m].y
        end
        new_feature.unk_28 = old_feature.unk_28
        new_feature.seed = old_feature.seed
        new_feature.unk_30:resize (1)
        for m = 0, #new_feature.unk_30 - 1 do
          new_feature.unk_30 [m] = old_feature.unk_30 [m]
        end
        for m = 0, #new_feature.unk_38 - 1 do
          new_feature.unk_38 [m] = old_feature.unk_38 [m]
        end
        new_feature.top_layer_idx = 3  --  Always Magma Sea to avoid clashes
        feature_init.start_depth = 3
        region.features [x] [y]:erase (l)
        break
      end
    end
    
    Update (x, y, self.subviews.pages)
  end

  --==============================================================
  
  function Ui:onInput (keys)
    if keys.LEAVESCREEN_ALL  then
        self:dismiss ()
    end
    
    if keys.LEAVESCREEN then
      if Focus == "Help" then
        Focus = Help_Focus
        self.subviews.pages:setSelected (Views [Focus])
        self.transparent = (Focus == "Hidden")
        
      else
        self:dismiss ()
      end
    end
    
    if keys [keybindings.elevation.key] then
      self.transparent = false
      Focus = "Elevation"
      self.subviews.pages:setSelected (Views [Focus])
      
    elseif keys [keybindings.biome.key] then
      self.transparent = false
      Focus = "Biome"
      self.subviews.pages:setSelected (Views [Focus])

    elseif keys [keybindings.river.key] then
      self.transparent = false
      Focus = "River"
      self.subviews.pages:setSelected (Views [Focus])

    elseif keys [keybindings.top_cavern.key] and
           df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 1 then
      self.transparent = false
      Focus = "Top Cavern"
      self.subviews.pages:setSelected (Views [Focus])
      
    elseif keys [keybindings.mid_cavern.key] and 
           df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 2 then
      self.transparent = false
      Focus = "Mid Cavern"
      self.subviews.pages:setSelected (Views [Focus])
        
    elseif keys [keybindings.low_cavern.key] and
           df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 3 then
      self.transparent = false
      Focus = "Low Cavern"
      self.subviews.pages:setSelected (Views [Focus])
      
    elseif keys [keybindings.feature.key] then
      self.transparent = false
      Focus = "Feature"
      self.subviews.pages:setSelected (Views [Focus])

    elseif keys [keybindings.hide.key] then
      self.transparent = true
      Focus = "Hidden"
      self.subviews.pages:setSelected (Views [Focus])

    elseif keys [keybindings.flatten.key] and
           Focus == "Elevation" then
      dialog.showYesNoPrompt ("Flatten Terrain?",
                              "The whole region will be set to an elevation of " .. tostring (region.elevation [x] [y]) .. " on Enter.",
                               COLOR_WHITE,
                              NIL,
                              self:callback ("flattenRegion"))
      
    elseif keys [keybindings.print_help.key] and 
           Focus == "Help" then
      local helptext
      
      for i, element in ipairs (Help_Pages) do
        helptext = element [2] ()
        
        for i, item in ipairs (helptext) do
          if type (item) == "string" then
            dfhack.print (item)
      
          else  --  table
            if item.pen then
              dfhack.color (item.pen.fg)
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
      end
                  
      dfhack.println ()
     
    elseif keys [keybindings.command_region_elevation.key] and
           Focus == "Elevation" then
      dialog.showInputPrompt ("Change elevation of region tile",
                              {{text = "Elevation value key:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "-999 -    0 is deep underground capped to the SMR", NEWLINE,
                               "   1 -   99 is ocean level", NEWLINE,
                               " 100 - 149 is normal terrain", NEWLINE,
                               " 150 - 250 is mountain"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateElevation"))
      
    elseif keys [keybindings.command_biome.key] and 
           Focus == "Biome" then
      dialog.showInputPrompt ("Change biome reference of region tile",
                              {{text = "World tile reference key:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "7: NW 8: N   9: NE", NEWLINE,
                               "4: W  5: Own 6: E", NEWLINE,
                               "1: SW 2: S   3: SE"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateBiome"))
      
    elseif keys [keybindings.command_river_elevation.key] and 
           River_Elevation_Image (x, y) ~= "" and
           Focus == "River" then
      dialog.showInputPrompt ("Change river elevation of region tile",
                              {{text = "Elevation value key:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "-999 -    0 is deep underground capped to the SMR", NEWLINE,
                               "   1 -   99 is ocean level", NEWLINE,
                               " 100 - 149 is normal terrain", NEWLINE,
                               " 150 - 250 is mountain"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateRiverElevation"))
      
    elseif keys [keybindings.command_vertical.key] and
           Focus == "River" then
      dialog.showInputPrompt ("Set river course vertical component",
                              {{text = "Vertical river course key:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "None", NEWLINE,
                               "South", NEWLINE,
                               "North"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateRiverVerticalActive"))

    elseif keys [keybindings.command_river_x.key] and 
           region.rivers_vertical.active [x] [y] ~= 0 and
           Focus == "River" then
      dialog.showInputPrompt ("Set river vertical course min x value",
                              {{text = "Vertical river x min:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "0 - 47, but not greater than X Max"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateRiverVerticalXMin"))
                              
    elseif keys [keybindings.command_river_X.key] and
           region.rivers_vertical.active [x] [y] ~= 0 and
           Focus == "River" then
      dialog.showInputPrompt ("Set river vertical course Max X value",
                              {{text = "Vertical river X Max:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "0 - 47, but not less than x min"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateRiverVerticalXMax"))
                              
    elseif keys [keybindings.command_horizontal.key] and
           Focus == "River" then
      dialog.showInputPrompt ("Set river course horizontal component",
                              {{text = "Horizontal river course key:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "None", NEWLINE,
                               "East", NEWLINE,
                               "West"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateRiverHorizontalActive"))
       
    elseif keys [keybindings.command_river_y.key] and 
           region.rivers_horizontal.active [x] [y] ~= 0 and
           Focus == "River" then
      dialog.showInputPrompt ("Set river horizontal course min y value",
                              {{text = "Horizontal river y min:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "0 - 47, but not greater than Y Max"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateRiverHorizontalYMin"))
                              
    elseif keys [keybindings.command_river_Y.key] and
           region.rivers_horizontal.active [x] [y] ~= 0 and
           Focus == "River" then
      dialog.showInputPrompt ("Set river horizontal course Max Y value",
                              {{text = "Horizontal river Y Max:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "0 - 47, but not less than y min"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateRiverHorizontalYMax"))
                              
    elseif keys [keybindings.command_is_brook.key] and
           Focus == "River" then
      df.global.world.world_data.region_map[region.pos.x]:_displace(region.pos.y).flags.is_brook =
        not df.global.world.world_data.region_map[region.pos.x]:_displace(region.pos.y).flags.is_brook
        
      Update (x, y, self.subviews.pages)
                              
    elseif keys [keybindings.command_water.key] and
           (Focus == "Top Cavern" or
            Focus == "Mid Cavern" or
            Focus == "Low Cavern") then
      dialog.showInputPrompt ("Set cavern water indicator",
                              {{text = "Hex value:",
                                pen = COLOR_YELLOW}, NEWLINE,
                               "0 - F"},
                              COLOR_WHITE,
                              "",
                              self:callback ("updateCavernWater"))
                      
    elseif keys [keybindings.command_feature_add.key] and
           Focus == "Feature" and
           Feature_Page.Add_Label.visible then
      local free_layer = Free_Layers ()
      local list = {}
      
      if free_layer [3] and
         (free_layer [2] or df.global.world.worldgen.worldgen_parms.cavern_layer_count < 3) and
         (free_layer [1] or df.global.world.worldgen.worldgen_parms.cavern_layer_count < 2) and
         (free_layer [0] or df.global.world.worldgen.worldgen_parms.cavern_layer_count < 1) and
         free_layer [-1] then
        table.insert (list, {text = "Volcano"})
      end
                      
      if free_layer [3] and
         free_layer [2] then
        table.insert (list, {text = "Magma Pool Top Cavern 3"})
      end
                     
      if free_layer [3] and
         free_layer [2] and
         free_layer [1] then
        table.insert (list, {text = "Magma Pool Top Cavern 2"})
      end
                     
      if free_layer [3] and
         free_layer [2] and
         free_layer [1] and
         free_layer [0] then
        table.insert (list, {text = "Magma Pool Top Cavern 1"})
      end
                     
      if df.global.world.worldgen.worldgen_parms.cavern_layer_count == 3 and
         free_layer [1] then
        table.insert (list, {text = "Passage Cavern 2\x1a3"})
      end
                        
      if df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 2 and
         free_layer [0] then
        table.insert (list, {text = "Passage Cavern 1\x1a2"})
      end
                         
      if df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 1 and
         free_layer [-1] then
        table.insert (list, {text = "Passage Surface\x1aCavern 1"})
      end
      
      if df.global.world.worldgen.worldgen_parms.cavern_layer_count == 3 and
         free_layer [1] then
        table.insert (list, {text = "Pit Cavern 2\x1a3"})
      end
                     
      if df.global.world.worldgen.worldgen_parms.cavern_layer_count >= 2 and
         free_layer [0] then
        table.insert (list, {text = "Pit Cavern 1\x1a2"})
      end
                     
      dialog.showListPrompt ("Add feature",
                              "Select a new feature:",
                              COLOR_WHITE,
                              list,
                              self:callback ("addFeature"))
                                            
    elseif keys [keybindings.command_feature_remove.key] and
           Focus == "Feature" and
           Feature_Page.Remove_Label.visible then
      local region = df.global.world.world_data.region_details [0]
      local feature_init
      local list = {}
      
      for i, feature in ipairs (region.features [x] [y]) do
        if feature.feature_idx ~= -1 then
          feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                           features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
          if feature_init:getType () == df.feature_type.volcano then
            table.insert (list, {text = "Volcano"})
            
          elseif feature_init:getType () == df.feature_type.magma_pool then
            if feature_init.start_depth == 2 then
              table.insert (list, {text = "Magma Pool Top Cavern 3"})
              
            elseif feature_init.start_depth == 1 then
              table.insert (list, {text = "Magma Pool Top Cavern 2"})
              
            elseif feature_init.start_depth == 0 then
              table.insert (list, {text = "Magma Pool Top Cavern 1"})
            end
            
          elseif feature_init:getType () == df.feature_type.cave then
            if feature_init.start_depth == 1 then
              table.insert (list, {text = "Passage Cavern 2\x1a3"})
              
            elseif feature_init.start_depth == 0 then
              table.insert (list, {text = "Passage Cavern 1\x1a2"})
              
            elseif feature_init.start_depth == -1 then
              table.insert (list, {text = "Passage Surface\x1aCavern 1"})
            end
            
          elseif feature_init:getType () == df.feature_type.pit then
            if feature_init.start_depth == 1 then
              table.insert (list, {text = "Pit Cavern 2\x1a3"})
              
            elseif feature_init.start_depth == 0 then
              table.insert (list, {text = "Pit Cavern 1\x1a2"})
            end
            
          else  --  We don't care about the rest
          end        
        end
      end
           
      dialog.showListPrompt ("Remove feature",
                              "Select a feature to remove:",
                              COLOR_WHITE,
                              list,
                              self:callback ("removeFeature"))
                                            
    elseif keys [keybindings.command_feature_change.key] and
           Focus == "Feature" and
           Feature_Page.Change_Label.visible then
      local free_layer = Free_Layers ()
      local region = df.global.world.world_data.region_details [0]
      local feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                             features.feature_init [region.pos.x % 16] [region.pos.y % 16] [Feature_Page.Feature_List [Feature_Page.List.selected].feature_index]
      local list = {}
      local text_list = {}
      local bottom = 3
      
      if feature_init:getType () == df.feature_type.magma_pool then
        bottom = 2  --  A magma pool that doesn't reach above the magma sea would be rather pointless...
      end
      
      for i = bottom, 0, -1 do
        if i == 3 or
           df.global.world.worldgen.worldgen_parms.cavern_layer_count - i > 0 then
          if feature_init.start_depth < i then
            table.insert (list, {i, false})
          
          elseif feature_init.start_depth > i then
            if not free_layer [i] then
              break
            end
          
            table.insert (list, {i, true})
          end
        end
      end
      
      for i, element in ipairs (list) do        
        if element [1] == 0 then
          table.insert (text_list, {text = "First Cavern"})
          
        elseif element [1] == 1 then
          table.insert (text_list, {text = "Second Cavern"})
          
        elseif element [1] == 2 then
          table.insert (text_list, {text = "Third Cavern"})
          
        else
          table.insert (text_list, {text = "Magma Sea"})
        end
      end
      
      dialog.showListPrompt ("Change feature top layer",
                              "Select a new top layer:",
                              COLOR_WHITE,
                              text_list,
                              self:callback ("changeFeature"))
                                 
    elseif keys [keybindings.command_feature_move.key] and
           Focus == "Feature" and
           Feature_Page.Move_Label.visible then
      local region = df.global.world.world_data.region_details [0]
      local feature_init
      local vacant
      local list = {}
      
      for i = math.floor (x / 2) * 2 , math.floor (x / 2) * 2  + 1 do
        for k = math.floor (y / 2) * 2, math.floor (y / 2) * 2 + 1 do
          if i ~= x or
             k ~= y then
            vacant = true
            
            for l, feature in ipairs (df.global.world.world_data.region_details [0].features [i] [k]) do
              if feature.feature_idx ~= -1 then
                feature_init = df.global.world.world_data.feature_map [math.floor (region.pos.x / 16)]:_displace (math.floor (region.pos.y / 16)).
                                 features.feature_init [region.pos.x % 16] [region.pos.y % 16] [feature.feature_idx]
                if feature_init:getType () == df.feature_type.magma_pool or
                   feature_init:getType () == df.feature_type.volcano then
                  vacant = false
                  break
                end
              end
            end
            
            if vacant then
              if x == i then
                if y < k then
                  table.insert (list, {text = "South"})
                  
                else
                  table.insert (list, {text = "North"})
                end
                
              elseif x < i then
                if y == k then
                  table.insert (list, {text = "East"})
                  
                elseif y < k then
                  table.insert (list, {text = "Southeast"})
                  
                else
                  table.insert (list, {text = "Northeast"})
                end
                
              else
                if y == k then
                  table.insert (list, {text = "West"})
                  
                elseif y < k then
                  table.insert (list, {text = "Southwest"})
                  
                else
                  table.insert (list, {text = "Northwest"})
                end
              end
            end
          end
        end
      end
       
      dialog.showListPrompt ("Change move adamantine spire",
                              "Select a direction in which to move the spire",
                              COLOR_WHITE,
                              list,
                              self:callback ("moveFeature"))
                                 
    elseif keys [keybindings.next_page.key] and
           Focus == "Help" then
      Current_Help_Page = Current_Help_Page + 1
      if Current_Help_Page > #Help_Pages then
        Current_Help_Page = 1
      end
    
    Help_Page.Help:setText (Help_Pages [Current_Help_Page] [2] ())
    
    elseif keys [keybindings.prev_page.key] and
           Focus == "Help" then
      Current_Help_Page = Current_Help_Page - 1
      if Current_Help_Page == 0 then
        Current_Help_Page = #Help_Pages
      end
    
    Help_Page.Help:setText (Help_Pages [Current_Help_Page] [2] ())
 
    elseif keys [keybindings.up.key] and not keys._STRING then
      if Focus ~= "Help" then
        if y > 0 then
          y = y - 1
        end

        Update (x, y, self.subviews.pages)
      end
            
    elseif keys [keybindings.down.key] and not keys._STRING then
      if Focus ~= "Help" then
        if y < max_y - 1 then
          y = y + 1
        end

        Update (x, y, self.subviews.pages)
      end
            
    elseif keys [keybindings.left.key] and not keys._STRING then
      if Focus ~= "Help" then
        if x > 0 then
          x = x - 1
        end
      
        Update (x, y, self.subviews.pages)
      end
      
    elseif keys [keybindings.right.key] and not keys._STRING then
      if Focus ~= "Help" then
        if x < max_x - 1 then
          x = x + 1
        end
        
        Update (x, y, self.subviews.pages)
      end
      
    elseif keys [keybindings.upleft.key] and not keys._STRING then
      if Focus ~= "Help" then
        if x > 0 then
          x = x - 1
        end
      
        if y > 0 then
          y = y - 1
        end
      
        Update (x, y, self.subviews.pages)
      end
      
    elseif keys [keybindings.upright.key] and not keys._STRING then
      if Focus ~= "Help" then
        if x < max_x - 1 then
          x = x + 1
        end
      
        if y > 0 then
          y = y - 1
        end
      
        Update (x, y, self.subviews.pages)
      end
      
    elseif keys [keybindings.downleft.key] and not keys._STRING then
      if Focus ~= "Help" then
        if x > 0 then
          x = x - 1
        end
      
        if y < max_y - 1 then
          y = y + 1
        end
      
        Update (x, y, self.subviews.pages)
      end
      
    elseif keys [keybindings.downright.key] and not keys._STRING then
      if Focus ~= "Help" then
        if x < max_x - 1 then
          x = x + 1
        end
      
        if y < max_y - 1 then
          y = y + 1
        end
      
        Update (x, y, self.subviews.pages)
      end      
    end

    self.super.onInput (self, keys)
  end

  --============================================================

  function Show_Viewer ()
    local screen = Ui {}
    persist_screen = screen
    screen:show ()
  end

  --============================================================

  Show_Viewer ()
end

regionmanipulator ()