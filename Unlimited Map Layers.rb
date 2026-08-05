#------------------------------------------------------------------------------#
# Unlimited Map Layers (VXACE)
#------------------------------------------------------------------------------#
# by NinjaChicle
#
# This allows to display & use multiple maps at the same time,
# each with their own tilemap, parallax, collision, spawned events and
# pixel offset. Switching between these layer maps is possible for all characters.
#
# Compatible with:
# * Yanfly - Parallax Lock
# * Victor Engine - Visual Equip
#------------------------------------------------------------------------------#
# Instructions:
#------------------------------------------------------------------------------#
# To load map layers into the main map
# put "MLayers:[MapID1,MapID2,MapID3...]" into the map's notetag.
#
# If Layer Maps don't get a z value set, they will all receive z values
# greater than the main map. To set the z values of specific layers
# upon layer creation, put "ML_SetZ[[MAP_ID1,Z],[MAP_ID2,Z]...]"
# in the map notetag. (example: ML_SetZ[[39,-200],[55,52]])
#
# set the z value of a layer:
#   $layer_maps.set_layer_viewport_z(layer_i,z)
#
# set the xy pixel offset of a layer: 
#   $layer_maps.set_xy_offset(layer_i, offset_x, offset_y)
#   $layer_maps.active_layer_data[layer_i].visual_data.x_offset
#   $layer_maps.active_layer_data[layer_i].visual_data.y_offset
#
# layer_i is based on which order the layer maps were loaded into the main map
# with "MLayers:[...]". (MapID1 -> 0, MapID2 -> 1, MapID3 -> 2)
#
# Layer order is sorted by their individual viewport's z values.
#
# move character one layer up   : character.move_up_layer
# move character one layer down : character.move_down_layer
# set layer : character.set_layer(layer_i)
#
# you can check whether an interpreter class is run from a layer event
# by checking for the existence of the @layer_map_id variable in a script call.
# 
# get event of interpreter: get_self_ev
#
# Layer events get their ID set incrementally starting from the
# main map's maximum event ID.
# get an event's original Event ID : event.original_id
# get an event's original Map ID   : event.origin_map
#
# get current layer index of character : character.layer_i
# get the layer_i of a layer map       : $layer_maps.data_translator[map_id]
#
# When a layer_i of an event gets set to -1, it will be moved to
# $game_map.events. Otherwise it will be moved to
# $layer_maps.active_layer_data[layer_i].event_data.events
#
# A layer index of -1 means the character is on the main map, and will work
# with all default $game_map functionality.
#
# Get event from any layer:
# (real id)                     : $layer_maps.find_ev(id)
# (origin map id & original id) : $layer_maps.find_ev_original(map_id,id)
#
#-------------------------------------------------------------------------------
# MOVE_PNG_MAP: Move between layers via PNG map (true/false)
#  Specify on which tiles you will be sent a layer up/down through PNG
#  pixel colour channel values, also with the option to only allow layer
#  switching when facing a specific direction (2, 4, 6, 8) on the tile.
#  (Supports both main and layer maps)
#  Example:
#  Create a PNG image with the same amount of pixels matching the
#  number of tiles you want to manage
#  Name the file "MAPX.png", replacing 'X' with the Map ID you want to manage
#  Place the file in the "Pictures" folder
#  Each pixel is one tile, the blue colour channel value
#  controls where the player will be transported to.
#  Color channel value specifications (any facing direction):
#  value 100: sends you a layer down 
#  value 200: sends you a layer up
#  For character facing direction: base value + facing direction
#  2 for facing down
#  4 for facing left
#  6 for facing right
#  8 for facing up
#  For example, '204' sends you a layer up when facing left
#------------------------------------------------------------------------------#
$imported = {} if !$imported
$imported[:Ninja_UnlimMapLayers] = true

module MULT_LAYERS
#------------------------------------------------------------------------------#
  MOVE_PNG_MAP = false    # see upper description
  FADE_UPPER_MAPS = true  # if upper maps cover player, make them transparent
  FADE_UPPER_CHARS = true # if characters of covering maps should be transparent
  FADE_OPACITY = 100 # the transparency opacity for upper maps
  FADE_SPEED = 8 # speed of fadein effect for layers. set -1 to switch it off.
  MAX_UPPER_ = 5 # max upper visible maps (to make max unlimited, set -1)
  MAX_LOWER_ = 5 # max lower visible maps (to make max unlimited, set -1)
#------------------------------------------------------------------------------#
  MAP_DIR = "Data/Map%03d.rvdata2"
  LMapsFolder = "Graphics/Pictures/"
  REGEX = /MLayers:\[([\d\,\s]+)\]/m
  REGEX_Z = /ML_SetZ:\[((?:[\s\,]*\[[\,\-\d\s]+\][\s\,]*)+)\]/m
  HAS_PARALLAX_LOCK = $imported.key?("YEA-ParallaxLock")
  HAS_VISUAL_EQUIP = $imported.key?(:ve_visual_equip)
  if HAS_VISUAL_EQUIP
    EV_VISUAL = "EVENT VISUAL"
    ACT_VISUAL = "ACTOR VISUAL"
    ACTOR = "ACTOR"
    PARTY = "PARTY"
  end
  SIZEOFLONG1 = DL::SIZEOF_LONG*4 # - bitmap pointer stuff
  SIZEOFLONG2 = DL::SIZEOF_LONG*2
  FIELDS = [2, 1, 0]
  EXCLUSION = { 
  # EXCLUSION: tiles considered invisible (to check if upper tiles cover the player)
    # tileset_id => [0, 1, 2],
    # [0, 1, 2] -> | 0: roof,wall,floor | 1: carpets,grass | 2: Tilesets B,C,D 
    1 => [[],[],[]],       # field tileset
    2 => [[0x0608],[],[]], # exterior tileset
    3 => [[0x0608],[],[]], # interior tileset
    4 => [[0x0608],[],[]], # dungeon tileset
  }
  
  # turns exclusion arrays to hashes to increase performance of tile checks
  EXCLUSION.each {|key,value|
    h = []; i = 0; v_s = value.size
    while v_s > i
      hh = {}; arr = value[i]; i += 1
      a_s = arr.size; j = 0
      while a_s > j; num = arr[j]; j += 1; hh[num] = true; end; h << hh
    end
    EXCLUSION[key] = h
  }
  
  # $game_map methods for layer maps
  
  def self.layered_tiles(x, y, data)
    FIELDS.collect {|z| data[x, y, z] }
  end
  
  def self.passable?(x, y, d, layer_i)
    check_passage(x, y, (1 << (d / 2 - 1)) & 0x0f, layer_i)
  end

  def self.boat_passable?(x, y, layer_i)
    check_passage(x, y, 0x0200, layer_i)
  end

  def self.ship_passable?(x, y, layer_i)
    check_passage(x, y, 0x0400, layer_i)
  end

  def self.airship_land_ok?(x, y, layer_i)
    check_passage(x, y, 0x0800, layer_i) && check_passage(x, y, 0x0f, layer_i)
  end

  def self.layered_tiles_flag?(x, y, bit, layer)
    data = layer.data
    tileset = $data_tilesets[layer.tileset_id]
    layered_tiles(x, y, data).any? {|tile_id| tileset.flags[tile_id] & bit != 0 }
  end

  def self.region_id(x,y,layer)
    data = layer.data
    valid?(x, y, data) ? data[x, y, 3] >> 8 : 0
  end
  
  def self.ladder?(x, y, layer)
    valid?(x, y, layer.data) && layered_tiles_flag?(x, y, 0x20, layer)
  end

  def self.bush?(x, y, layer)
    valid?(x, y, layer.data) && layered_tiles_flag?(x, y, 0x40, layer)
  end

  def self.counter?(x, y, layer)
    valid?(x, y, layer.data) && layered_tiles_flag?(x, y, 0x80, layer)
  end

  def self.damage_floor?(x, y, layer)
    valid?(x, y, layer.data) && layered_tiles_flag?(x, y, 0x100, layer)
  end

  def self.terrain_tag(x, y, layer)
    return 0 unless valid?(x, y, layer.data)
    tileset = $data_tilesets[layer.tileset_id]
    l_tiles = layered_tiles(x, y, layer.data)
    l_t_s = l_tiles.size
    i = 0
    while l_t_s > i
      tile_id = l_tiles[i]
      tag = tileset.flags[tile_id] >> 12
      return tag if tag > 0
      i += 1
    end
    0
  end

  def self.events_xy(x,y,layer_i)
    data = $layer_maps.active_layer_data[layer_i].event_data.events.values
    data.select {|event| event.pos?(x, y) }
  end
  
  def self.valid?(x,y,data)
    x >= 0 && x < data.xsize && y >= 0 && y < data.ysize
  end
  
  def self.refresh
    layer_i = $game_player.layer_i
    data_size = $layer_maps.layer_data.size
    start_i = layer_i - MAX_LOWER_
    start_i = 0 if start_i < 0
    max_i = start_i+MAX_UPPER_+MAX_LOWER_
    max_i = data_size if data_size < max_i
    i = start_i
    while max_i > i
      data = $layer_maps.active_layer_data[i]
      event_data = data.event_data
      evs = event_data.events.values
      event_data.tile_events = evs.select {|event| event.tile? }
      e_size = evs.size
      j = 0
      while e_size > j
        evs[j].refresh
        j += 1
      end
      i += 1
    end
  end

  def self.events_xy_nt(x, y, layer_i)
    data = $layer_maps.active_layer_data[layer_i].event_data.events.values
    data.select {|event| event.pos_nt?(x, y) }
  end

  def tile_events_xy(x, y, layer_i)
    data = $layer_maps.active_layer_data[layer_i].event_data.tile_events
    data.select {|event| event.pos_nt?(x, y) }
  end

  def self.event_id_xy(x, y, layer_i)
    list = events_xy(x, y, layer_i)
    list.empty? ? 0 : list[0].id
  end
  
  def self.check_passage(x, y, bit, layer_i)
    main_layer_data = $layer_maps.layer_data[layer_i]
    sub_layer_data = $layer_maps.active_layer_data[layer_i]
    tile_events = sub_layer_data.event_data.tile_events
    map_data = main_layer_data.data
    return false if !MULT_LAYERS.valid?(x,y,map_data)
    all_tile_list=tile_events.select {|event| event.pos_nt?(x, y) }.collect {|ev| ev.tile_id }.concat(FIELDS.collect {|z| map_data[x, y, z]})
    a_t_size = all_tile_list.size
    var_tileset = $data_tilesets[main_layer_data.tileset_id]
    flags = var_tileset.flags
    i = 0
    while a_t_size > i
      tile_id = all_tile_list[i]; i += 1
      flag = flags[tile_id]
      if flag & 0x10 != 0
        next         if flag & bit == 0
        return false if flag & bit == bit
      else
        return true  if flag & bit == 0
        return false if flag & bit == bit
      end
    end
    false
  end
  
  def self.parallax_ox(bitmap,layer_map)
    parallax = layer_map.parallax
    if parallax.loop_x
      parallax.x * 16
    else
      w1_ = bitmap.width - Graphics.width
      w2_ = layer_map.data.xsize * 32 - Graphics.width
      w1 = w1_ > 0 ? w1_ : 0
      w2 = w2_ > 1 ? w2_ : 1
      parallax.x * 16 * w1 / w2
    end
  end
  
  def self.parallax_oy(bitmap,layer_map)
    parallax = layer_map.parallax
    if parallax.loop_y
      parallax.y * 16
    else
      h1_ = bitmap.height - Graphics.height
      h2_ = layer_map.data.ysize * 32 - Graphics.height
      h1 = h1_ > 0 ? h1_ : 0
      h2 = h2_ > 1 ? h2_ : 1
      parallax.y * 16 * h1 / h2
    end
  end

  if HAS_PARALLAX_LOCK
    class <<self; alias :layer_p_ox :parallax_ox; alias :layer_p_oy :parallax_oy
    end
    def self.parallax_lock_x?(parallax); parallax.lock_x; end
    def self.parallax_lock_y?(parallax); parallax.lock_y; end
    def self.parallax_tile_lock?(parallax); parallax.tile_lock; end
    def self.parallax_ox(bitmap,layer_map)
      parallax = layer_map.parallax
      return 0 if parallax_lock_x?(parallax)
      return $game_map.display_x * 32 if parallax_tile_lock?(parallax)
      layer_p_ox(bitmap,layer_map)
    end
    def self.parallax_oy(bitmap,layer_map)
      parallax = layer_map.parallax
      return 0 if parallax_lock_y?(parallax)
      return $game_map.display_y * 32 if parallax_tile_lock?(parallax)
      layer_p_oy(bitmap,layer_map)
    end
  end
end

class Multi_Layer_Map
  attr_reader :data_translator
  attr_reader :mem_attrib
  attr_reader :layer_data
  attr_accessor :sorted_layer_i
  attr_accessor :map_id
  attr_accessor :active_layer_data
  attr_accessor :layer_order_changed
  
  P_Args = [:name,:loop_x,:loop_y,:sx,:sy,:x,:y]
  P_Args.concat([:lock_x,:lock_y,:tile_lock]) if MULT_LAYERS::HAS_PARALLAX_LOCK
  Parallax = Struct.new(*P_Args); P_Args.clear; P_Args = nil
  Layer_Map = Struct.new(:id, :data, :tileset_id, :parallax, :event_values)
  Layer_Visual = Struct.new(:x_offset, :y_offset)
  Active_Map_Data = Struct.new(:visual_data, :event_data)
  Layer_Events = Struct.new(:events,:tile_events)
  Layer_Attributes = Struct.new(:opacity,:viewport_z,:modified_tilemap)
  
  def set_xy_offset(layer_i, offset_x, offset_y)
    visual_data = @active_layer_data[layer_i].visual_data
    visual_data.x_offset = offset_x
    visual_data.y_offset = offset_y
  end
  
  def initialize
    @data_translator = {}
    @layer_data = []
    @active_layer_data = []
    @sorted_layer_i = [] # sorts by viewport.z
    @mem_attrib = Layer_Attributes.new([],[],[])
  end

  if MULT_LAYERS::HAS_PARALLAX_LOCK
    YEA_LOCK_NOTE_SPLIT = /[\r\n]+/
    def read_yea_p_lock(map)
      yea_modules = YEA::REGEXP::MAP
      lock_x = false;  lock_y = false;  tile_lock = false
      lines = map.note.split(YEA_LOCK_NOTE_SPLIT)
      l_s = lines.size;  i = 0
      while l_s > i
        line = lines[i]; i += 1
        case line
        when yea_modules::LOCK_PARALLAX_X
          lock_x = true;  tile_lock = false
        when yea_modules::LOCK_PARALLAX_Y
          lock_y = true;  tile_lock = false
        when yea_modules::FULL_LOCK_PARALLAX
          lock_x = true;  lock_y = true;  tile_lock = false
        when yea_modules::TILE_LOCK_PARALLAX
          lock_x = false;  lock_y = false;  tile_lock = true
        end
      end
      [lock_x,lock_y,tile_lock]
    end
  end
  
  def load_layer(map_id)
    if @data_translator.key?(map_id)
      @layer_data[@data_translator[map_id]]
    else
      map = load_data(sprintf(MULT_LAYERS::MAP_DIR, map_id))
      p_args = [map.parallax_name,map.parallax_loop_x,
        map.parallax_loop_y,map.parallax_sx,map.parallax_sy,0,0]
      p_args.concat(read_yea_p_lock(map)) if MULT_LAYERS::HAS_PARALLAX_LOCK
      parallax = Parallax.new(*p_args)
      Layer_Map.new(map_id,map.data,map.tileset_id,parallax,map.events)
    end
  end
  
  def add_layer(layer_data, id)
    @data_layer[id] = layer_data
  end

  def set_layer_opacity(layer_i,value)
    SceneManager.scene.set_layer_opacity(layer_i,value)
  end
  
  def get_layer_viewport(layer_i)
    spriteset = SceneManager.scene.spriteset
    spriteset ? spriteset.layer_viewports[layer_i] : nil
  end
  
  def set_layer_viewport_z(layer_i,z)
    spriteset = SceneManager.scene.spriteset
    if !spriteset.nil?
      viewports = spriteset.layer_viewports
      viewports[layer_i].z = z
      rearrange_layer_i(viewports)
    end
  end
  
  def rearrange_layer_i(layer_viewports)
    a = layer_viewports.map {|v| v.z }
    c = a.sort
    @sorted_layer_i = Array.new(a.size) {|i| a.index(c[i]) }
    @layer_order_changed = true
  end
  
  def all_layer_events
    layer_evs = []; i = 0; a_l = @active_layer_data.size
    while a_l > i
      layer_evs.concat(@active_layer_data[i].event_data.events.values);  i += 1
    end
    layer_evs
  end
  
  def get_all_events
    $game_map.events.values.concat(all_layer_events)
  end
  
  def find_ev_original(map_id,id)
    ev = $game_map.events.values.find {|ev| 
    ev.original_id == id && ev.origin_map == map_id }
    if ev.nil?
      i = 0; a_l = @active_layer_data.size
      while a_l > i
        evs = @active_layer_data[i].event_data.events.values
        j = 0; e_s = evs.size
        while e_s > j
          ev = evs[j]
          return ev if ev.original_id == id && ev.origin_map == map_id
          j += 1
        end
        i += 1
      end
    end
    ev
  end
  
  def find_ev(id)
    if $game_map.events.key?(id)
      $game_map.events[id]
    else
      i = 0; a_l = @active_layer_data.size
      while a_l > i
        evs = @active_layer_data[i].event_data.events.values
        j = 0; e_s = evs.size
        while e_s > j
          ev = evs[j]
          return ev if ev.id == id
          j += 1
        end
        i += 1
      end
      nil
    end
  end
  
  def layer_events(layer_i)
    @active_layer_data[layer_i].event_data.events
  end
  
  def layer_event(layer_i,id)
    layer_events(layer_i)[id]
  end
end

module DataManager
  class << self
    alias :unlayered_create_game_objects :create_game_objects
    alias :unlayered_make_save_contents :make_save_contents 
    alias :unlayered_extract_save_contents :extract_save_contents
  end
  
  def self.create_game_objects
    unlayered_create_game_objects
    $layer_maps = Multi_Layer_Map.new
  end
  
  def self.make_save_contents
    contents = unlayered_make_save_contents
    contents[:unlayered_data] = $layer_maps
    contents
  end
  
  def self.extract_save_contents(contents)
    unlayered_extract_save_contents(contents)
    $layer_maps = contents[:unlayered_data] || Multi_Layer_Map.new
  end
end

class Game_Follower
  alias :unlayered_follower_update :update
  def update
    unlayered_follower_update
    @layer_i = $game_player.layer_i
    @layer_mode_on = $game_player.layer_mode_on
  end
end

class Game_Followers
  def size
    @data.size
  end
end

class Game_CharacterBase
  attr_accessor :original_id
  attr_accessor :layer_i
  attr_accessor :origin_map
  attr_accessor :layer_move_check
  attr_reader :increase_layer
  attr_reader :layer_mode_on
  
  alias :unlayered_initialize :initialize
  def initialize
    @l_y_offset = 0
    @l_x_offset = 0
    unlayered_initialize
  end
  
  alias :unlayered_char_update :update
  def update
    unlayered_char_update
    check_offset_v
  end
  
  alias :unlayer_screen_x :screen_x
  def screen_x
    unlayer_screen_x - @l_x_offset
  end

  alias :unlayer_screen_y :screen_y
  def screen_y
    unlayer_screen_y - @l_y_offset
  end
  
  def check_offset_v
    if @do_visual_check
      if @layer_mode_on
        @visual_xy_data = $layer_maps.active_layer_data[@layer_i].visual_data
        @l_x_offset = @visual_xy_data.x_offset
        @l_y_offset = @visual_xy_data.y_offset
      else
        @visual_xy_data = nil
        @l_x_offset = 0
        @l_y_offset = 0
      end
      @do_visual_check = false
    end
    if @visual_xy_data
      @l_x_offset = @visual_xy_data.x_offset if @l_x_offset != @visual_xy_data.x_offset
      @l_y_offset = @visual_xy_data.y_offset if @l_y_offset != @visual_xy_data.y_offset
    end
    if @prev_l_i != @layer_i
      @prev_l_i = @layer_i
      @l_x_offset = 0
      @l_y_offset = 0
      @visual_xy_data = nil
      @do_visual_check = true
    end
  end
  
  alias :unlayered_region_id :region_id
  def region_id
    @layer_mode_on ? MULT_LAYERS.region_id(@x,@y,cur_layer) : unlayered_region_id
  end
  
  def cur_region_id(x,y)
    @layer_mode_on ? MULT_LAYERS.region_id(x,y,cur_layer) : $game_map.region_id(x,y)
  end
  
  alias :unlayer_u_move :update_move
  def update_move
    unlayer_u_move
    img_layer_check if @layer_move_check
  end
  
  def img_layer_check
    x_ = @x.to_i
    y_ = @y.to_i
    unless x_ == @prev_img_l_x && y_ == @prev_img_l_y
      @prev_img_l_x = x_
      @prev_img_l_y = y_
      check_layer_img_map(x_,y_)
    end
  end
  
  def check_layer_img_map(x_,y_)
    img_l_move = @layer_mode_on ? $img_layers[@layer_i] : $main_img_layer
    num = img_l_move[x_,y_]
    if num > 0
      base = num > 199 ? 200 : 100
      check_num = base + @direction
      if num == base || num & check_num == check_num
        base > 100 ? move_up_layer : move_down_layer
      end
    end
  end
  
  alias :m_layer_initialize :initialize
  def initialize
    @layer_i = -1
    @origin_map = -1
    @layer_mode_on = false
    m_layer_initialize
  end
  
  alias :unlayered_map_pass :map_passable?
  def map_passable?(x, y, d)
    @layer_mode_on ? layered_map_pass(x,y,d) : unlayered_map_pass(x,y,d)
  end
  
  alias :unlayered_coll_ev :collide_with_events?
  def collide_with_events?(x, y)
    @layer_mode_on ? layered_coll_ev(x,y) : unlayered_coll_ev(x,y)
  end
  
  def layered_coll_ev(x,y)
    evs = $layer_maps.active_layer_data[@layer_i].event_data.events.values
    !(evs.select {|event| event.pos_nt?(x, y) && event.normal_priority? }.empty?)
  end
  
  def layered_map_pass(x,y,d)
    bit = (1 << (d / 2 - 1)) & 0x0f
    MULT_LAYERS.check_passage(x, y, bit, @layer_i)
  end
  
  alias :unlayer_ladder :ladder?
  def ladder?
    @layer_mode_on ? MULT_LAYERS.ladder?(@x,@y,cur_layer) : unlayer_ladder
  end

  alias :unlayer_bush :bush?
  def bush?
    @layer_mode_on ? MULT_LAYERS.bush?(@x,@y,cur_layer) : unlayer_bush
  end

  alias :unlayer_trn_tag :terrain_tag
  def terrain_tag
    @layer_mode_on ? MULT_LAYERS.terrain_tag(@x,@y,cur_layer) : unlayer_trn_tag
  end
  
  alias :layered_update_animation :update_animation
  def update_animation
    layered_update_animation
  end
  
  def move_up_layer
    @layer_i = SceneManager.scene.spriteset.get_upper_layer(@layer_i)
    @layer_mode_on = @layer_i > -1
  end
  
  def move_down_layer
    @layer_i = SceneManager.scene.spriteset.get_lower_layer(@layer_i)
    @layer_mode_on = @layer_i > -1
  end
  
  def activate_layer_mode; @layer_mode_on = true; end
  
  def set_layer(layer_i)
    @layer_i = layer_i
    @layer_mode_on = @layer_i > -1
    @do_visual_check = true
  end
  
  def cur_layer
    $layer_maps.layer_data[@layer_i]
  end
end

class Sprite_Character
  attr_reader :layer_i
  attr_accessor :reduced_l_o
  alias :s_layer_initialize :initialize
  def initialize(viewport,character=nil)
    @reduced_l_o = 0
    @layer_i = character.layer_i
    @prev_layer = @layer_i
    s_layer_initialize(viewport,character)
  end
  
  alias :layered_update_other :update_other
  def update_other
    layered_update_other
    @layer_i = @character.layer_i
    if @character.layer_mode_on
      new_opacity = @character.opacity - @reduced_l_o
      if @prev_layer != @layer_i
        self.viewport = $layer_maps.get_layer_viewport(@layer_i)
      end
      self.opacity = new_opacity
    else
      if @prev_layer && @prev_layer != @layer_i
        self.viewport = SceneManager.scene.spriteset.viewport1
      end
    end
    @prev_layer = @layer_i
  end
end

class Game_Player
  alias :unlayered_start_m_evs :start_map_event
  def start_map_event(x, y, triggers, normal)
    return if $game_map.interpreter.running?
    if @layer_mode_on
      evs = MULT_LAYERS.events_xy(x,y,@layer_i)
      e_s = evs.size
      i = 0
      while e_s > i
        event = evs[i]
        if event.trigger_in?(triggers) && event.normal_priority? == normal
          event.start
        end
        i += 1
      end
    else
      unlayered_start_m_evs(x, y, triggers, normal)
    end
  end
end

class Plane
  attr_accessor :layer_i
end

class Tilemap
  attr_accessor :layer_i
end

class Game_Map
  attr_reader :tileset_id
  alias :any_ev_start_unlayer :any_event_starting?
  def any_event_starting?
    player_l_i = $game_player.layer_i
    if $game_player.layer_mode_on
      evs = $layer_maps.active_layer_data[player_l_i].event_data.events.values
      evs.any? {|event| event.starting } || any_ev_start_unlayer
    else
      any_ev_start_unlayer
    end
  end
  
  alias :unlayer_ssmapev :setup_starting_map_event
  def setup_starting_map_event
    layer_i = $game_player.layer_i
    if $game_player.layer_mode_on
      layer_data = $layer_maps.layer_data[layer_i]
      evs = $layer_maps.active_layer_data[layer_i].event_data.events.values
      event = evs.find {|event| event.starting }
      event.clear_starting_flag if event
      @interpreter.setup(event.list, event.id) if event
      @interpreter.instance_variable_set(:@layer_map_id,layer_data.id)
      event
    else
      @interpreter.instance_variable_set(:@layer_map_id,nil)
      unlayer_ssmapev
    end
  end
  
  alias :unlayer_setup :setup
  def setup(map_id)
    $layer_maps.map_id = map_id if $layer_maps
    unlayer_setup(map_id)
    if SceneManager.scene.is_a?(Scene_Map)
      SceneManager.scene.spriteset._refresh_map_layers_
    end
  end
  
  alias :unlayer_refresh :refresh
  def refresh
    MULT_LAYERS.refresh if !$layer_maps.data_translator.empty?
    unlayer_refresh
  end
  
  def note
    @map ? @map.note : ""
  end
end

class Game_Event
  def refresh_interpret_map_id
    @interpreter.instance_variable_set(:@layer_map_id,@map_id)
  end
  
  alias :unlayered_player_collide? :collide_with_player_characters?
  def collide_with_player_characters?(x, y)
    unlayered_player_collide?(x,y) && $game_player.layer_i == @layer_i
  end
  
  def set_layer(layer_i)
    prev_layer_i = @layer_i
    @layer_i = layer_i
    @layer_mode_on = @layer_i > -1
    return if layer_i == prev_layer_i
    SceneManager.scene.spriteset.switch_char_layer(prev_layer_i,layer_i,@id)
  end
  
  def conditions_met?(page) # overwrite
    c = page.condition
    if c.switch1_valid
      return false unless $game_switches[c.switch1_id]
    end
    if c.switch2_valid
      return false unless $game_switches[c.switch2_id]
    end
    if c.variable_valid
      return false if $game_variables[c.variable_id] < c.variable_value
    end
    if c.self_switch_valid
      e_id = @original_id ? @original_id : @event.id
      key = [@map_id, e_id, c.self_switch_ch]
      return false if $game_self_switches[key] != true
    end
    if c.item_valid
      item = $data_items[c.item_id]
      return false unless $game_party.has_item?(item)
    end
    if c.actor_valid
      actor = $game_actors[c.actor_id]
      return false unless $game_party.members.include?(actor)
    end
    return true
  end
end

class Scene_Map
  attr_reader :spriteset
  
  if MULT_LAYERS::HAS_VISUAL_EQUIP
    alias :unlayered_ve_visual_e_start :start
    def start
      unlayered_ve_visual_e_start
      evs = $layer_maps.all_layer_events; e_s = evs.size; i = 0
      while e_s > i; evs[i].default_clone_visual; i += 1; end
    end
  end
end

class Spriteset_Map
  attr_reader :viewport1
  attr_reader :parallax_layers
  attr_reader :layer_tilemaps
  attr_reader :layer_viewports
  alias :spriteful_map_init :initialize
  def initialize
    init_vars
    spriteful_map_init
  end
  
  def init_vars
    @do_upper_fade = MULT_LAYERS::FADE_UPPER_MAPS
    @do_u_f_chars = MULT_LAYERS::FADE_UPPER_CHARS
    @u_t_opacity = MULT_LAYERS::FADE_OPACITY
    @set_upper_opacity = MULT_LAYERS::MAX_UPPER_ > -1
    @set_lower_opacity = MULT_LAYERS::MAX_LOWER_ > -1
    @gradual_m_speed = -1
    @layer_char_sprites = []
    @parallax_layers = []
    @layer_tilemaps = []
    @layer_viewports = []
    @updating_layer_keys = {}
    @mem_opacity = 255
  end
  
  
  alias :spriteful_map_dispose :dispose
  def dispose
    dispose_data
    spriteful_map_dispose
  end
  
  def _refresh_map_layers_
    dispose_data if !@disposed_layers && @layers_active
    load_layers
  end
  
  def dispose_data
    erase_remain_sprites
    is_new_map = $layer_maps.map_id && @map_id != $layer_maps.map_id
    chars = @character_sprites.select {|char| char.viewport != @viewport1 }
    char_s = chars.size; i = 0
    while char_s > i; chars[i].viewport = @viewport1; i += 1; end
    a_s = $layer_maps.active_layer_data.size
    i = 0
    while a_s > i
      char_sprites = @layer_char_sprites[i]
      active_data = $layer_maps.active_layer_data[i]
      tilemap = @layer_tilemaps[i]
      tilemap.viewport = nil
      tilemap.dispose
      parallax = @parallax_layers[i]
      parallax.viewport = nil
      parallax.bitmap.dispose if parallax.bitmap
      parallax.dispose
      c_s = char_sprites.size
      j = 0
      while c_s > j
        sprite = char_sprites[j]
        sprite.viewport = nil
        sprite.dispose
        j += 1
      end
      i += 1
    end
    $layer_maps.mem_attrib.viewport_z.clear
    viewports = @layer_viewports
    v_s = viewports.size
    i = 0
    while v_s > i
      viewport = viewports[i]
      $layer_maps.mem_attrib.viewport_z << viewport.z
      viewport.dispose
      i += 1
    end
    viewports.clear
    @parallax_layers.clear
    @layer_tilemaps.clear
    @disposed_layers = true
    clear_layer_data if is_new_map
  end
  
  def clear_layer_data
    $layer_maps.active_layer_data.clear
    $layer_maps.layer_data.clear
    $layer_maps.data_translator.clear
    $layer_maps.mem_attrib.viewport_z.clear
  end
  
  def set_follower_sprites_viewport(viewport)
    return if !$game_player.followers.visible
    class_name = Game_Follower
    followers = @character_sprites.select {|sprite| 
    sprite.character.instance_of?(class_name) }
    followers.each {|sprite| sprite.viewport = viewport }
  end
  
  def load_layers
    @prev_l_map_id = $game_map.map_id
    @max_ev_id = $game_map.events.keys.max
    @next_ev_id = @max_ev_id + 1
    @layers_active = false
    @img_map_active = false
    @disposed_layers = false
    if $game_map.note =~ MULT_LAYERS::REGEX
      map_ids = $1.split(",").map! {|i| i.to_i }
      @l_map_ids = map_ids.size
      @layers_active = true
      @mod_tilemap = false
      @on_upper_map = true
      @mem_opacity = 255
      if !$layer_maps.data_translator.empty?
        $layer_maps.mem_attrib.opacity.clear
        $layer_maps.mem_attrib.modified_tilemap.clear
      end
      $layer_maps.mem_attrib.opacity = Array.new(@l_map_ids,255)
      $layer_maps.mem_attrib.modified_tilemap = Array.new(@l_map_ids,false)
      @img_map_active = @layers_active && MULT_LAYERS::MOVE_PNG_MAP
      i = 0
      while @l_map_ids > i
        _create_layer_(i, map_ids[i], 0, 0)
        i += 1
      end
      viewport_z = $layer_maps.mem_attrib.viewport_z
      if !viewport_z.empty?
        viewports = @layer_viewports
        v_s = viewports.size;  i = 0
        while v_s > i
          viewport = viewports[i]
          viewport.z = viewport_z[i]
          i += 1
        end
        $layer_maps.rearrange_layer_i(@layer_viewports)
      else
        $layer_maps.sorted_layer_i = (0..(@l_map_ids-1)).to_a
        if $game_map.note =~ MULT_LAYERS::REGEX_Z
          str = $1
          str.gsub!(/\s+/, '')
          arr = str.scan(/\[(\d+),(\-?\d+)\]/)
          i = 0; a_s = arr.size
          while a_s > i
            nums = arr[i]
            index = @l_map_ids.index(nums[0].to_i)
            @layer_viewports[index].z = nums[1].to_i
            i += 1
          end
          arr.clear
        end
      end
      $layer_maps.layer_order_changed = true
      @erasing_sprites = Array.new(@layer_char_sprites.size) { Array.new }
      if $game_player.layer_mode_on && @layer_viewports.size <= $game_player.layer_i
        $game_player.set_layer(@layer_viewports.size-1)
      end
      load_img_maps if @img_map_active
      evs = $layer_maps.all_layer_events.select {|ev| ev.trigger == 4 }
      i = 0; e_s = evs.size
      while e_s > i
        evs[i].refresh_interpret_map_id
        i += 1
      end
      update_layers_u
      Graphics.frame_reset
    else
      $game_player.set_layer(-1)
      clear_layer_data
    end
    if $game_player.layer_mode_on
      sprite = @character_sprites.find {|char| char.character==$game_player }
      v = @layer_viewports[$game_player.layer_i]
      sprite.viewport = v
      set_follower_sprites_viewport(v)
    end
    $game_player.layer_move_check = @img_map_active
  end

  def load_img_maps
    @img_map = $game_map.map_id
    return if @img_map == @prev_img_map
    @prev_img_map = @img_map
    $img_layers = $img_layers ? $img_layers.clear : []
    imgs = Dir.glob("#{MULT_LAYERS::LMapsFolder}MAP*.png")
    @img_lmaps_active = !imgs.empty?
    if @img_lmaps_active
      img_check = Hash[imgs.each_with_index.to_a]
      lm_s = @l_map_ids.size
      i = 0
      while lm_s > i
        layer_data = $layer_maps.layer_data[i].data
        $img_layers << load_img_move_maps(@l_map_ids[i],layer_data,img_check)
        i += 1
      end
      $main_img_layer = load_img_move_maps($game_map.map_id,$game_map.data,img_check)
    end
  end
  
  def get_upper_layer(cur_layer)
    if cur_layer == -1
      return (!@upper_l_arr.empty? ? @upper_l_arr[0] : -1)
    else
      u_i = @upper_l_arr.index(cur_layer)
      if !u_i.nil?
        return @upper_l_arr[u_i+1 >= @upper_l_arr.size ? u_i : u_i+1]
      else
        l_i = @lower_l_arr.index(cur_layer)
        return (l_i + 1 >= @lower_l_arr.size ? -1 : @lower_l_arr[l_i+1])
      end
    end
  end
  
  def get_lower_layer(cur_layer)
    if cur_layer == -1
      return (!@lower_l_arr.empty? ? @lower_l_arr[-1] : -1)
    else
      u_i = @upper_l_arr.index(cur_layer)
      if !u_i.nil?
        return (u_i-1 < 0 ? -1 : @upper_l_arr[u_i-1])
      else
        l_i = @lower_l_arr.index(cur_layer)
        return @lower_l_arr[l_i-1 < 0 ? l_i : l_i-1]
      end
    end
  end
  
  def update_layer_order_data
    @g_m_s2 = MULT_LAYERS::FADE_SPEED
    @upper_start_i = mu = MULT_LAYERS::MAX_UPPER_
    @lower_start_i = ml = MULT_LAYERS::MAX_LOWER_
    sort_l_i = $layer_maps.sorted_layer_i
    @tgr_start_i = nil
    data_size = @layer_viewports.size
    p_layer = $game_player.layer_i
    sorted_viewports = Array.new(data_size) {|i| @layer_viewports[sort_l_i[i]] }
    highest_viewports = sorted_viewports.select {|viewport| viewport.z > @viewport1.z }
    lowest_viewports = sorted_viewports.select {|viewport| viewport.z < @viewport1.z }
    @upper_l_arr = Array.new(highest_viewports.size) {|i| @layer_viewports.index(highest_viewports[i]) }
    @lower_l_arr = Array.new(lowest_viewports.size) {|i| @layer_viewports.index(lowest_viewports[i]) }
    @upper_arr_size = @upper_l_arr.size
    @lower_arr_size = @lower_l_arr.size
    $layer_maps.layer_order_changed = false
    @prev_p_x = nil
    @activate_u_l_update = nil
    if $game_player.layer_mode_on
      p_viewport = @layer_viewports[p_layer]
      if highest_viewports.include?(p_viewport)
        @upper_start_i = highest_viewports.index(p_viewport) + MULT_LAYERS::MAX_UPPER_
      elsif lowest_viewports.include?(p_viewport)
        @lower_start_i = lowest_viewports.index(p_viewport) + MULT_LAYERS::MAX_LOWER_
      end
    end
    excluded_i = []
    if MULT_LAYERS::MAX_LOWER_ > -1
      i = @lower_start_i
      @lower_l_arr.reverse!
      while @lower_arr_size > i
        excluded_i << @lower_l_arr[i]; i += 1
      end
      @lower_l_arr.reverse!
    end
    if MULT_LAYERS::MAX_UPPER_ > -1
      i = @upper_start_i
      while @upper_arr_size > i
        excluded_i << @upper_l_arr[i]; i += 1
      end
    end
    @updating_i = sort_l_i - excluded_i
    @updating_layer_keys.clear
    @updating_i.each {|layer_i| @updating_layer_keys[layer_i] = true }
    @on_upper_map = true
    if @do_upper_fade
      if p_layer > -1
        p_viewport = @layer_viewports[p_layer]
        p_layer_i = highest_viewports.index(p_viewport)
        @on_upper_map = !p_layer_i.nil?
        p_layer_i = lowest_viewports.index(p_viewport) if !@on_upper_map
      else
        p_layer_i = -1
      end
      if @on_upper_map
        if p_layer < 0
          i = sorted_viewports.index(highest_viewports[0])
          if !i.nil?
            u_l_i = @updating_i.index(sort_l_i[i])
            @active_upper_layers = @updating_i[u_l_i..@updating_i.size-1]
          else
            @active_upper_layers = []
          end
        else
          arr = @updating_i[@updating_i.index(p_layer)+1..@updating_i.size-1]
          @active_upper_layers = arr
        end
      else
        arr = @updating_i[@updating_i.index(p_layer)+1..@updating_i.size-1]
        @active_upper_layers = arr
      end
      @active_upper_layers -= excluded_i
      @updating_i -= @active_upper_layers
      @a_u_l_s = @active_upper_layers.size
    end
    @updating_i_size = @updating_i.size
  end
  
  def move_opacity(o, target_o, speed)
    return target_o if speed < 0
    current_o = o
    if current_o < target_o
      cur_o = current_o + speed
      o = target_o < cur_o ? target_o : cur_o
    end
    if current_o > target_o
      cur_o = current_o - speed
      o = target_o > cur_o ? target_o : cur_o
    end
    o
  end

  def upper_fade_iterate
    i = 0
    while @a_u_l_s > i
      opacity = 255
      id = @active_upper_layers[i]
      layer_data = $layer_maps.layer_data[id]
      active_layer_data = $layer_maps.active_layer_data[id]
      data = layer_data.data
      if @prev_tileset != layer_data.tileset_id
        @prev_tileset = layer_data.tileset_id
        @exclusion_list = MULT_LAYERS::EXCLUSION[@prev_tileset]
      end
      if MULT_LAYERS::FIELDS.any? {|i|
        num = data[@i_p_x,@i_p_y,i]
        num > 0 && !@exclusion_list[i].key?(num) }
        opacity = @u_t_opacity
      end
      o = @do_u_f_chars || !@updating_layer_keys.key?(id) ||
      opacity == 255 && @updating_layer_keys.key?(id)
      @comp_l += 1 if set_layer_opacity(id,opacity,false,@g_m_s2,o)
      i += 1
    end
  end
  
  def do_upper_fade_check
    @p_x = $game_player.x
    @p_y = $game_player.y
    if !@activate_u_l_update && (@p_x != @prev_p_x || @p_y != @prev_p_y)
      @comp_l = 0
      @expected_num = @a_u_l_s
      @activate_u_l_update = true
      @prev_p_x = $game_player.x
      @prev_p_y = $game_player.y
      @i_p_x = @p_x.to_i
      @i_p_y = @p_y.to_i
      @opacity_main_map = !@on_upper_map
      @expected_num += 1 if @opacity_main_map
    end
    return if !@activate_u_l_update
    unless @p_x == @prev_p_x && @p_y == @prev_p_y
      @i_p_x = @p_x.to_i
      @i_p_y = @p_y.to_i
    end
    upper_fade_iterate unless @opacity_main_map && @comp_l == @a_u_l_s
    if @opacity_main_map
      tileset_id = $game_map.tileset_id
      if @prev_tileset != tileset_id
        @prev_tileset = tileset_id
        @exclusion_list = MULT_LAYERS::EXCLUSION[@prev_tileset]
      end
      opacity = 255
      if MULT_LAYERS::FIELDS.any? {|i|
        num = $game_map.data[@i_p_x, @i_p_y, i]
        num > 0 && !@exclusion_list[i].key?(num) }
        opacity = @u_t_opacity
      end
      if set_cur_map_opacity(opacity,@g_m_s2)
        @comp_l += 1
        @opacity_main_map = false
      end
    end
    if @comp_l == @expected_num
      @activate_u_l_update = false
      @comp_l = 0
    end
  end
  
  def set_layer_opacities
    if @prev_layer_i && $game_player.layer_i != @prev_layer_i
      @gradual_m_speed = MULT_LAYERS::FADE_SPEED
      update_layer_order_data
    end
    @prev_layer_i = $game_player.layer_i
    opacity = 255
    i = 0
    while @updating_i_size > i
      id = @updating_i[i]
      set_layer_opacity(id,opacity,false,@gradual_m_speed)
      i += 1
    end
    do_upper_fade_check if @do_upper_fade
    opacity = 0
    if @set_upper_opacity
      i = @upper_start_i
      while @upper_arr_size > i
        set_layer_opacity(@upper_l_arr[i],opacity,true,@gradual_m_speed)
        i += 1
      end
    end
    return unless @set_lower_opacity
    i = @lower_start_i
    while @lower_arr_size > i
      set_layer_opacity(@lower_l_arr[i],opacity,true,@gradual_m_speed)
      i += 1
    end
  end
  
  def set_cur_map_opacity(opacity,speed = -1)
    return true if opacity == @mem_opacity
    opacity = move_opacity(@mem_opacity, opacity, speed)
    @mem_opacity = opacity
    tileset = $game_map.tileset
    names = tileset.tileset_names
    bitmaps = @tilemap.bitmaps
    b_s = names.size
    i = 0
    if @mod_tilemap
      if opacity > 254
        while b_s > i
          bitmaps[i].dispose
          bitmaps[i] = Cache.tileset(names[i])
          i += 1
        end
        @mod_tilemap = false
      else
        while b_s > i
          bitmap = bitmaps[i]
          bitmap.clear
          bitmap.blt(0,0,Cache.tileset(names[i]),bitmap.rect,opacity)
          i += 1
        end
      end
    else
      while b_s > i
        bitmap = bitmaps[i]
        new_bitmap = Bitmap.new(bitmap.width,bitmap.height)
        new_bitmap.blt(0,0,Cache.tileset(names[i]),new_bitmap.rect,opacity)
        bitmaps[i] = new_bitmap
        i += 1
      end
      @mod_tilemap = true
    end
    @parallax.opacity = opacity
    false
  end
  
  def set_layer_opacity(layer_i,opacity,update=false,speed = -1,o_char=true)
    opacity_mem = $layer_maps.mem_attrib.opacity
    cur_o_mem = opacity_mem[layer_i]
    return true if opacity == cur_o_mem
    opacity = move_opacity(cur_o_mem, opacity, speed)
    opacity_mem[layer_i] = opacity
    mod_tilemap = $layer_maps.mem_attrib.modified_tilemap
    layer_map = $layer_maps.layer_data[layer_i]
    tilemap = @layer_tilemaps[layer_i]
    names = $data_tilesets[layer_map.tileset_id].tileset_names
    bitmaps = tilemap.bitmaps
    b_s = names.size
    i = 0
    if mod_tilemap[layer_i]
      if opacity > 254
        while b_s > i
          bitmaps[i].dispose
          bitmaps[i] = Cache.tileset(names[i])
          i += 1
        end
        mod_tilemap[layer_i] = false
      else
        while b_s > i
          bitmap = bitmaps[i]
          bitmap.clear
          bitmap.blt(0,0,Cache.tileset(names[i]),bitmap.rect,opacity)
          i += 1
        end
      end
    else
      while b_s > i
        bitmap = bitmaps[i]
        new_bitmap = Bitmap.new(bitmap.width,bitmap.height)
        new_bitmap.blt(0,0,Cache.tileset(names[i]),new_bitmap.rect,opacity)
        bitmaps[i] = new_bitmap
        i += 1
      end
      mod_tilemap[layer_i] = true
    end
    parallax = @parallax_layers[layer_i]
    parallax.opacity = opacity
    set_layer_char_o(opacity,layer_i,update) if o_char
    update_layer(layer_i) if !@updating_layer_keys.key?(layer_i)
    false
  end
  
  def _create_layer_(map_index, map_id,x_offset,y_offset)
    layer_map = $layer_maps.load_layer(map_id)
    viewport = Viewport.new
    viewport.z = @viewport1.z + map_index + 1
    @layer_viewports << viewport
    tilemap = Tilemap.new(viewport)
    tilemap.layer_i = map_index
    tilemap.map_data = layer_map.data
    tileset = $data_tilesets[layer_map.tileset_id]
    tileset_names = tileset.tileset_names
    t_size = tileset_names.size
    i = 0
    while t_size > i
      name = tileset_names[i]
      tilemap.bitmaps[i] = Cache.tileset(name)
      i += 1
    end
    tilemap.flags = tileset.flags
    @layer_tilemaps << tilemap
    parallax = Plane.new(viewport)
    parallax.z = @parallax.z + (map_index+1)#*100
    if !layer_map.parallax.name.empty?
      parallax.bitmap = Cache.parallax(layer_map.parallax.name)
    end
    parallax.layer_i = map_index
    @parallax_layers << parallax
    $layer_maps.layer_data[map_index] = layer_map
    if !$layer_maps.data_translator.key?(map_id)
      $layer_maps.data_translator[map_id] = map_index
      event_values = load_layer_events(layer_map,map_index)
      visual_data = Multi_Layer_Map::Layer_Visual.new(x_offset, y_offset)
      active_map_data = Multi_Layer_Map::Active_Map_Data.new(visual_data, event_values)
      $layer_maps.active_layer_data[map_index] = active_map_data
    end
    create_layer_characters(map_index,viewport)
  end
  
  def load_layer_events(map,layer_i=0)
    events = {}
    map_id = map.id
    map_events = map.event_values
    ids = map_events.keys
    evs = map_events.values
    map_event_size = ids.size
    i = 0
    while map_event_size > i
      ev_id = ids[i]
      data_ev = evs[i]
      original_id = data_ev.id
      data_ev.id = @next_ev_id
      ev = Game_Event.new(map_id, data_ev)
      ev.origin_map = map_id
      ev.original_id = original_id
      ev.layer_i = layer_i
      ev.activate_layer_mode
      events[ev.id] = ev
      @next_ev_id += 1
      i += 1
    end
    tile_events = events.values.select {|event| event.tile? }
    Multi_Layer_Map::Layer_Events.new(events,tile_events)
  end
  
  def update_layers_u
    erase_remain_sprites
    update_layer_order_data if $layer_maps.layer_order_changed
    update_layer_data
    set_layer_opacities
  end
  
  alias :layered_update :update
  def update
    _refresh_map_layers_ if @prev_l_map_id != $game_map.map_id
    layered_update
    update_layers_u if @layers_active
  end
  
  def switch_char_layer(layer_i,new_layer_i,id)
    prev_layer = $layer_maps.active_layer_data[layer_i]
    if layer_i < 0
      prev_evs = $game_map.events
      old_sprites = @character_sprites
    else 
      prev_evs = prev_layer.event_data.events
      old_sprites = @layer_char_sprites[layer_i]
    end
    if new_layer_i < 0
      evs = $game_map.events
      sprites = @character_sprites
    else
      evs = $layer_maps.active_layer_data[new_layer_i].event_data.events
      sprites = @layer_char_sprites[new_layer_i]
    end
    evs[id] = prev_evs.delete(id)
    sprite = old_sprites.find {|sprite| sprite.character.id == id }
    if new_layer_i < 0
      sprite.reduced_l_o = 0
      s_i = sprites.size - 1-$game_player.followers.size-$game_map.vehicles.size
      sprites.insert(s_i,sprite)
    else
      if @do_u_f_chars || !@updating_layer_keys.key?(new_layer_i)
        sprite.reduced_l_o = 255 - $layer_maps.mem_attrib.opacity[new_layer_i]
      end
      sprites << sprite
    end
    @erasing_sprites[layer_i] << sprite
    @start_sprite_erasure = true
  end
  
  def erase_remain_sprites
    return if !@start_sprite_erasure
    e_s = @erasing_sprites.size
    i = 0
    while e_s > i
      layer_erase_s = @erasing_sprites[i]
      if !layer_erase_s.empty?
        layer_sprites = @layer_char_sprites[i]
        l_s = layer_erase_s.size
        j = 0
        while l_s > j
          sprite = layer_erase_s[j]
          layer_sprites.delete(sprite)
          j += 1
        end
        layer_erase_s.clear
      end
      i += 1
    end
    @start_sprite_erasure = false
  end
  
  def set_layer_char_o(opacity,layer_i,update)
    events = @layer_char_sprites[layer_i]
    ev_s = events.size
    i = 0
    while ev_s > i
      event = events[i]
      event.reduced_l_o = 255 - opacity
      event.update if update
      i += 1
    end
  end
  
  def update_layer_data
    i = 0
    while @updating_i_size > i
      update_layer(@updating_i[i])
      i += 1
    end
    if @do_upper_fade
      i = 0
      while @a_u_l_s > i
        update_layer(@active_upper_layers[i])
        i += 1
      end
    end
  end

  def update_layer(id)
    tilemap = @layer_tilemaps[id]
    layer_data = $layer_maps.layer_data[id]
    active_layer_data = $layer_maps.active_layer_data[id]
    tilemap.map_data = layer_data.data
    visual_data = active_layer_data.visual_data
    x_offset = visual_data.x_offset
    y_offset = visual_data.y_offset
    tilemap.ox = @tilemap.ox + x_offset
    tilemap.oy = @tilemap.oy + y_offset
    tilemap.update
    parallax = @parallax_layers[id]
    p_b = parallax.bitmap
    if p_b
      layer_parallax = layer_data.parallax
      parallax.ox = MULT_LAYERS.parallax_ox(p_b,layer_data) + x_offset
      parallax.oy = MULT_LAYERS.parallax_oy(p_b,layer_data) + y_offset
      layer_parallax.x += layer_parallax.sx / 64.0 if layer_parallax.loop_x
      layer_parallax.y += layer_parallax.sy / 64.0 if layer_parallax.loop_y
    else
      parallax.ox = @parallax.ox + x_offset
      parallax.oy = @parallax.oy + y_offset
    end
    update_layer_characters(id)
  end
  
  def create_layer_characters(layer_i, viewport=@viewport1)
    character_sprites = []
    evs = $layer_maps.active_layer_data[layer_i].event_data.events.values
    @layer_char_sprites[layer_i] = character_sprites
    i = 0
    e_size = evs.size
    while e_size > i
      event = evs[i]
      character_sprites << Sprite_Character.new(viewport, event)
      i += 1
    end
  end
  
  def update_layer_characters(layer_i)
    character_sprites = @layer_char_sprites[layer_i]
    c_size = character_sprites.size
    evs = $layer_maps.active_layer_data[layer_i].event_data.events.values
    i = 0
    while c_size > i
      ev = evs[i]
      ev.update
      character_sprites[i].update if ev.near_the_screen?
      i += 1
    end
  end
  
  def load_img_move_maps(map_id,layer_data,img_check)
    width_ = layer_data.xsize
    height_ = layer_data.ysize
    table = Table.new(width_,height_)
    filename_1 = "#{MULT_LAYERS::LMapsFolder}MAP#{map_id}.png"
    if img_check.key?(filename_1)
      bitmap_1 = Cache.normal_bitmap(filename_1)
      max = width_ * height_ * 4
      row_size = width_ * 4
      offset = max - row_size
      bytesize1 = MULT_LAYERS::SIZEOFLONG1
      bytesize2 = MULT_LAYERS::SIZEOFLONG2
      b_ptr1 = DL::CPtr.new(bitmap_1.__id__<<1)
      cptr1 = (((b_ptr1 + bytesize1).ptr + bytesize2).ptr + bytesize1).ptr
      y_ = 0
      while height_ > y_
        row_x = (width_ * y_) << 2
        x_ = 0
        while width_ > x_
          o = offset - row_x + (x_*4)
          table[x_,y_] = cptr1[o] & 0xFF
          x_ += 1
        end
        y_ += 1
      end
      cptr1 = nil
      b_ptr1 = nil
      bitmap_1.dispose
    end
    table
  end
end

class Game_Interpreter
  alias :unlayered_c_111 :command_111
  def command_111
    if @params[0] == 2  # Self switch
      result = false
      if @event_id > 0
        ev = get_self_ev
        if ev.original_id
          id = ev.original_id
          map_id = ev.origin_map
        else
          id = @event_id
          map_id = @map_id
        end
        key = [map_id, id, @params[1]]
        result = ($game_self_switches[key] == (@params[2] == 0))
      end
      @branch[@indent] = result
      command_skip if !@branch[@indent]
    else
      unlayered_c_111
    end
  end
  
  alias :unlayered_c_123 :command_123
  def command_123
    if !@layer_map_id
      unlayered_c_123
    else
      if @event_id > 0
        ev = get_self_ev
        id = ev.original_id ? ev.original_id : ev.id
        key = [@layer_map_id, id, @params[0]]
        $game_self_switches[key] = (@params[1] == 0)
      end
    end
  end
  
  alias :unlayered_c_214 :command_214
  def command_214
    if @layer_map_id
      if @event_id > 0
        layer_i = $layer_maps.data_translator[@layer_map_id]
        layer_data = $layer_maps.active_layer_data[layer_i]
        event = layer_data.event_data.events[@event_id]
        event.erase
      end
    else
      unlayered_c_214
    end
  end
  
  alias :unlayered_get_char :get_character
  def get_character(param)
    if param < 0 || $game_party.in_battle
      unlayered_get_char(param)
    else
      if @layer_map_id
        layer_i = $layer_maps.data_translator[@layer_map_id]
        layer_data = $layer_maps.active_layer_data[layer_i]
        ev_id = param > 0 ? param : @event_id
        same_map? ? layer_data.event_data.events[ev_id] : nil
      else
        unlayered_get_char(param)
      end
    end
  end
  
  def get_layer_ev(id)
    layer_i = $layer_maps.data_translator[@layer_map_id]
    layer_data = $layer_maps.active_layer_data[layer_i]
    layer_data.event_data.events[id]
  end
  
  def get_self_ev
    @event_id > 0 ? $layer_maps.find_ev(@event_id) : nil
  end
  
  def find_ev_layers_(id)
    $layer_maps.find_ev(id)
  end
  
  def find_ev_map_(id)
    $layer_maps.find_ev_original(@layer_map_id, id)
  end
  
  if MULT_LAYERS::HAS_VISUAL_EQUIP
    def get_obj_v_type(id)
      t_up = type.upcase
      return find_ev_map_(id) if t_up == MULT_LAYERS::EV_VISUAL
      return $game_actors[id] if t_up == MULT_LAYERS::ACT_VISUAL
      nil
    end
    def call_change_visual(type) # overwrite
      regexp = get_all_values("CHANGE #{type}")
      note.scan(regexp) do
        value = $1.dup
        id = value =~ /ID: (\d+)/i ? $1.to_i : nil
        object = get_obj_v_type(id)  if id
        object.set_visual_parts(value) if object
        object.character_items         if object
      end
    end
    def call_clear_visual(type) # overwrite
      note.scan(/<CLEAR #{type}: (\d+)>/i) do
        id = $1.to_i
        object = get_obj_v_type(id)  if id
        object.clear_visual_parts if object
        object.character_items    if object
      end
    end
    def call_restore_visual(type) # overwrite
      note.scan(/<DEFAULT #{type}: (\d+)>/i) do
        value = $1.dup
        id = value =~ /ID: (\d+)/i ? $1.to_i : nil
        object = get_obj_v_type(id)  if id
        object.default_visual_parts if object
        object.character_items      if object
      end
    end
    def call_clone_visual # overwrite
      note.scan(/<EVENT CLONE (ACTOR|PARTY): (\d+) *, *(\d+)>/i) do |pt, ev, ac|
        event = find_ev_map_(ev.to_i)
        pt_u = pt.upcase
        actor = $game_actors[ac.to_i]            if pt_u == MULT_LAYERS::ACTOR
        actor = $game_party.members[ac.to_i - 1] if pt_u == MULT_LAYERS::PARTY
        next if !actor || !event
        event.set_cloned_visual(actor.clone.visual_items.dup)
      end
    end
  end# MULT_LAYERS::HAS_VISUAL_EQUIP
end