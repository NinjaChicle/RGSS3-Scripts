#------------------------------------------------------------------------------#
# * Database Viewer (VXACE)
#------------------------------------------------------------------------------#
# by NinjaChicle
#
# View and sort database contents like Items, Skills, Animations, and States
# (able to sort by specific attribute values)
#
# v1.1 : Made some descriptions clearer.
#
# Requires:
# - Yanfly Debug Extension
#------------------------------------------------------------------------------#
if $TEST
if !$imported || !$imported.key?("YEA-DebugExtension")
  msgbox("You need Yanfly Debug Extension for this script to work properly!")
end
#------------------------------------------------------------------------------#
# * Yanfly Debug Extension modifications
#------------------------------------------------------------------------------#
YEA::DEBUG::COMMANDS << [:data_view, "Database Viewer"]
class Scene_Debug < Scene_MenuBase
  alias :cooler_create_c_window :create_command_window
  def create_command_window
    cooler_create_c_window
    @command_window.set_handler(:data_view, method(:command_data))
  end
  def command_data
    SceneManager.call(Data_Debug)
  end
end
class Window_DebugEntry # overwrite
  def initialize(width=nil,x=nil,y=nil)
    dx = x.nil? ? -standard_padding : x
    dy = y.nil? ? Graphics.height - fitting_height(1) + standard_padding : y
    dw = width.nil? ? Graphics.width + standard_padding * 2 : width
    dh = fitting_height(1)
    super(dx, dy, dw, dh)
    contents.font.name = ["VL Gothic", "Courier New"]
    contents.font.bold = false
    contents.font.italic = false
    contents.font.shadow = false
    contents.font.outline = false
    contents.font.size = 20
    contents.font.color = Color.new(192, 192, 192)
    self.opacity = 0
    @text = ""
    @rect = Rect.new(4, 0, 8192, 24)
    refresh
  end
end
#------------------------------------------------------------------------------#
class Data_Debug < Scene_MenuBase
#------------------------------------------------------------------------------#
  SYS_BG_GRAPHIC = "" # leave blank if you dont want to load any img
  SYSTEM_BG = "Graphics/Battlebacks1/Clouds.png" # only appears if in game folder
  CONFIRM = "Confirm"
  START_SORT = "Start searching data with these attributes."
  TYPE_SELECT = "Type Selection"
  LRUD = "Left/Right/Up/Down"
  INFO_SORT = "Can only open search window in data list!"
  FIRST_DESC = "Type of Data"
  SEARCH_LIST = "Search"
  TEXTS = ["CTRL + F: Search", "Esc: Back"]
#------------------------------------------------------------------------------#
  RIGHT_KEY = :RIGHT
  LEFT_KEY = :LEFT
  UP_KEY = :UP
  DOWN_KEY = :DOWN
  TYPES = { # type_sym => icon_index
  :items => 205,
  :armors => 458,
  :weapons => 144,
  :skills => 112,
  :states => 2,
  :animations => 102,
  }
  
  Depth_List = {
  :data_list => :data_types,
  :data => :data_list,
  :root_data => :data,
  }
  Desc_Sym = {
  :@element_id => "Array.new($data_system.elements.size-1){|i|\"\#{i+1}: \#{$data_system.elements[i+1]}\"}",
  :@occasion => "[\"0: Always\",\"1: Only in battle\",\"2: Only from the menu\",\"3: Never\"]",
  :@hit_type => "[\"0: Certain hit\",\"1: Physical attack\",\"2: Magical attack\"]",
  :@scope => "[\"0: None\",\"1: One Enemy\",\"2: All Enemies\",\"3: One Random Enemy\",
\"4: Two Random Enemies\",\"5: Three Random Enemies\",\"6: Four Random Enemies\", 
\"7: One Ally\",\"8: All Allies\",\"9: One Ally (Dead)\",\"10: All Allies (Dead)\",
\"11: The User\"]",
:@type => "[\"0: None\",\"1: HP damage\",\"2: MP damage\",\"3: HP recovery\",
\"4: MP recovery\",\"5: HP drain\",\"6: MP drain\"]"
  }
  EXCLUDED_DISPOSE = [:@background_sprite]
  MAX_DISPLAY_WIN_WIDTH = 3000
  MAX_DISPLAY_WIN_HEIGHT = 3000
#------------------------------------------------------------------------------#
  def map_types(sym)
    case sym
    when :items
      $data_items
    when :armors
      $data_armors
    when :weapons
      $data_weapons
    when :skills
      $data_skills
    when :states
      $data_states
    when :animations
      $data_animations
    end
  end
#------------------------------------------------------------------------------#

  def create_display_win
    w = Graphics.width/3 + 25
    h = Graphics.height - @help_window.height
    @display_win = Window_Base.new(Graphics.width - w,@help_window.height,w,h)
    @display_win.z = @help_window.z + 300
    @display_win.contents.font.size = 21
  end
  
  def set_title(text)
    @title_win.contents.clear
    rect = @title_win.contents.rect
    @title_win.draw_text(rect,text,1)
  end
  
  def create_title_win
    y = @help_window.height
    x = @display_win.x
    w = @display_win.width
    @title_win = Window_Base.new(x,y,w,45)
    @title_win.z = @help_window.z + 100
    @title_win.contents.font.size = 22
    @display_win.y = @title_win.y + @title_win.height
    @display_win.height = Graphics.height - @display_win.y
  end
  
  def create_post_card
    @sprite_post = Sprite.new
    if !SYS_BG_GRAPHIC.empty? && FileTest.exists?(SYS_BG_GRAPHIC)
      @sprite_post.bitmap = Cache.normal_bitmap(SYS_BG_GRAPHIC)
    end
    @sprite_post.y = @help_window.height
    @sprite_post.x = Graphics.width/2 - @sprite_post.width/2 + 35
    @sprite_post.z = @help_window.z - 250
    @sprite_post.angle = 15
    @sprite_bg = Sprite.new
    if !SYSTEM_BG.empty? && FileTest.exists?(SYSTEM_BG)
      @sprite_bg.bitmap = Cache.normal_bitmap(SYSTEM_BG)
    end
    @sprite_bg.z = 250
  end
  
  def create_history_display
    @select_history
    @history_display = Sprite.new
    @history_display.x = 4
    @history_display.bitmap = Bitmap.new(@charac_viewer.width-4,45)
    @history_display.bitmap.font.size = 22
    @history_display.y = @help_window.height
    @history_display.z = @help_window.z - 100
    @charac_viewer.y = @history_display.y + @history_display.height
    @charac_viewer.height = Graphics.height - @charac_viewer.y
    @charac_viewer.refresh
    draw_history
  end
  
  def draw_history
    @history_display.bitmap.fill_rect(@history_display.bitmap.rect,@black)
    if !@select_history.empty?
      text = @select_history.join("/")
      rect = @history_display.bitmap.text_size(text)
      w = @history_display.width
      rect.x = -(rect.width - w) if rect.width > w
      @history_display.bitmap.draw_text(rect,text)
    end
  end
  
  def start
    super
    @black = Color.new(0,0,0)
    create_help_window
    @help_window.z = 600
    create_display_win
    create_post_card
    create_background
    @desc_sym = {}
    Desc_Sym.each {|key,value| @desc_sym[key] = eval(value,binding) }
    @prev_history_size = 0
    @active_win = 0
    @select_history = [:data_types]
    @index_history = [0]
    icons = TYPES.values
    @types = TYPES.keys
    @data_list = @types.map {|sym| map_types(sym) }
    @arr = Array.new(@types.size) {|i| 
    ["\\I[#{icons[i]}] #{@types[i].to_s.capitalize}",@types[i]] 
    }
    @item_types = {}
    @item_help = {}
    @item_id_list = {}
    i = 0
    @types.each {|type|
      data = @data_list[i]
      @item_types[type] = []
      @item_help[type] = []
      @item_id_list[type] = []
      type_arr = @item_types[type]
      type_help_arr = @item_help[type]
      id_list = @item_id_list[type]
      j = 0
      empty_str = ""
      d_size = data.size
      while d_size > j
        d = data[j]
        if !d.nil?
          id = d.id
          if d.class != RPG::Animation
            icon = d.icon_index
            desc = d.description
          else
            icon = 0
            desc = empty_str
          end
          type_arr << ["#{id}: \\I[#{icon}]#{d.name}",:obj]
          type_help_arr << desc
          id_list << id
        end
        j += 1
      end
      i += 1
    }
    @help = Array.new(@types.size,FIRST_DESC)
    create_select_window
    @type = :data_types
    create_history_display
    create_title_win
    create_prompt_sprite
    create_prompt_sprite2
  end
  
  def create_select_window
    args = [0,@help_window.height,Graphics.width,@arr,@help]
    @charac_viewer = Window_CustomCommands.new(*args)
    @charac_viewer.help_window = @help_window
    @charac_viewer.set_handler(:ok, method(:on_npc_list_ok))
    @charac_viewer.set_handler(:cancel, method(:on_npc_list_cancel))
    @charac_viewer.z = @help_window.z - 100
    @charac_viewer.width = Graphics.width - @display_win.width
    @charac_viewer.instance_eval do
      @@icon_sym = /\\I\[(\d+)\]/
      @@gsub_icon_sym = /\\I\[\d+\]/
      @@empty = ""
      def draw_item(index)
        change_color(normal_color, command_enabled?(index))
        name = command_name(index)
        rect = item_rect_for_text(index)
        if name =~ @@icon_sym
          draw_icon($1.to_i, 0, rect.y)
          name = name.gsub(@@gsub_icon_sym,@@empty)
          rect.x += 24
        end
        draw_text(rect, name, alignment)
      end
    end
  end
  
  def create_prompt_sprite
    cw = @charac_viewer.contents.width
    @texts = TEXTS
    @prompt_sprite = Sprite.new
    @prompt_sprite.z = @charac_viewer.z + 2
    bitmap = Bitmap.new(cw/4 + 12,18)
    @prompt_sprite.bitmap = bitmap
    bitmap.font.size = @charac_viewer.contents.font.size - 8
    bitmap.font.bold = true
    @prompt_sprite.x = @charac_viewer.width - @prompt_sprite.width - 12
    @prompt_sprite.y = @charac_viewer.y - @prompt_sprite.height/2
    set_prompt_text(0)
    @prompt_sprite.opacity = 0
  end
  
  def create_search_win_header
    @search_header = Sprite.new
    @search_header.z = @search_win.z + 5
    w = @search_win.width/5 + 24
    h = 16
    @search_header.x = @search_win.width/2 - w/2
    @search_header.y = @search_win.y - h + 6
    header_bitmap = Bitmap.new(w,h)
    header_bitmap.fill_rect(header_bitmap.rect,@black)
    header_bitmap.font.size = @search_win.contents.font.size - 5
    header_bitmap.font.bold = true
    header_bitmap.draw_text(header_bitmap.rect,SEARCH_LIST,1)
    @search_header.bitmap = header_bitmap
    @search_header.opacity = 0
  end
  
  def create_prompt_sprite2
    @lr_sprite = Sprite.new
    contents = @display_win.contents
    bitmap2 = Bitmap.new(contents.width/2,18)
    @lr_sprite.bitmap = bitmap2
    bitmap2.font.size = contents.font.size - 3
    bitmap2.fill_rect(bitmap2.rect,@black)
    bitmap2.draw_text(bitmap2.rect,LRUD,1)
    @lr_sprite.opacity = 0
    @lr_sprite.x = @display_win.x + @display_win.width/2 - @lr_sprite.width/2
    @lr_sprite.y = @display_win.y + @display_win.height - @lr_sprite.height
    @lr_sprite.z = @display_win.z + 3
  end
  
  def set_prompt_text(i)
    bitmap = @prompt_sprite.bitmap
    bitmap.fill_rect(bitmap.rect,@black)
    bitmap.draw_text(bitmap.rect,@texts[i],1)
  end
  
  def update
    super
    if @active_win == 0
      if Input.trigger?(Input::LETTERS['R']) ||
        (Input.press?(Input::LETTERS['F']) && Input.press?(:CTRL))
        if @type == :data_list
          open_sort_window if !@charac_viewer.active
          @charac_viewer.deactivate
        else
          Sound.play_buzzer
          @help_window.set_text(INFO_SORT)
        end
      elsif Input.trigger?(RIGHT_KEY)
        set_prompt_text(1)
        @lr_sprite.opacity = 255
        @active_win = 1
        @charac_viewer.deactivate
      end
    else
      if Input.trigger?(Input::ESC)
        @active_win = 0
        @charac_viewer.activate
        @display_win.ox = 0
        @display_win.oy = 0
        set_prompt_text(0)
        @lr_sprite.opacity = 0
      end
      w = @display_win.contents.width
      h = @display_win.contents.height
      @display_win.ox += 2 if Input.press?(RIGHT_KEY)
      @display_win.ox -= 2 if Input.press?(LEFT_KEY)
      @display_win.ox = 0 if @display_win.ox < 0
      @display_win.ox = w if @display_win.ox > w
      @display_win.oy += 2 if Input.press?(DOWN_KEY)
      @display_win.oy -= 2 if Input.press?(UP_KEY)
      @display_win.oy = 0 if @display_win.oy < 0
      @display_win.oy = h if @display_win.oy > h
    end
    if @prev_index != @charac_viewer.index
      @prev_index = @charac_viewer.index
      @display_win.contents.clear
      return if @charac_viewer.index < 0
      case @type
      when :data_list
        list = @sorted ? @sort_id_list : @item_id_list[@item_type]
        id = list[@charac_viewer.index]
        item = @data_list[@types.index(@item_type)][id]
        draw_arr(item.note.split("\n")) if item.class != RPG::Animation
      when :data
        inst_var = @item.instance_variables[@charac_viewer.index]
        if !inst_var.nil?
          obj = @item.instance_variable_get(inst_var)
          if obj.is_a?(Array)
            first_e = obj[0]
            if first_e.method(:to_s).owner == first_e.class
              list = obj.to_s.split(",")
            else
              list = obj.map {|e| e.class.name }.to_s.split(",")
            end
          else
            list = obj.to_s.split("\n")
          end
          draw_arr(list)
        end
      else
        win = @search_win && @search_win.active ? @sort_win : @charac_viewer
        sym = win.current_symbol
        draw_arr(@desc_sym[sym]) if @desc_sym.key?(sym)
      end
    end
  end
  
  def open_sort_window
    if !@search_win
      create_sort_window
      create_search_win_header
    else
      @search_win.show
      @search_win.activate
    end
    @search_header.opacity = 255
    @sorted = false
    get_sort_options
  end
  
  def on_sort_cancel
    if @in_root_class
      root_obj = @category_input[@root_i]
      inst_vars = root_obj.instance_variables
      if inst_vars.all? {|sym| root_obj.instance_variable_get(sym).nil? }
        @category_input[@root_i] = nil
      end
      @search_win.in_root = false
      @in_root_class = false
      @vars = @prev_vars
      @categories = @prev_categories
      @input_list = @prev_input
      @help_list = @prev_help
      @search_win.replace_command_list(@input_list,@help_list)
    else
      @search_win.hide
      @search_header.opacity = 0
      @charac_viewer.activate
    end
  end
  
  def create_sort_window
    args = [0,@help_window.height,Graphics.width,[["",:ok]],[""]]
    @search_win = Window_CustomCommands.new(*args)
    @search_win.help_window = @help_window
    @search_win.set_handler(:ok, method(:on_sort_ok))
    @search_win.set_handler(:cancel, method(:on_sort_cancel))
    @search_win.z = @help_window.z + 399
    @search_win.width = Graphics.width - @display_win.width
    @search_win.height = @charac_viewer.height
    @search_win.instance_eval do
      @@icon_sym = /\\I\[(\d+)\]/
      @@gsub_icon_sym = /\\I\[\d+\]/
      @@empty = ""
      def in_root=(value); @in_root = value; end
      def root_i=(value); @root_i = value; end
      def draw_item(index)
        change_color(normal_color, command_enabled?(index))
        name = command_name(index)
        rect = item_rect_for_text(index)
        if name =~ @@icon_sym
          draw_icon($1.to_i, 0, rect.y)
          name = name.gsub(@@gsub_icon_sym,@@empty)
          rect.x += 24
        end
        if @category_input
          if @in_root
            obj = @category_input[@root_i]
            inst_var = obj.instance_variables[index]
            if inst_var.nil?
              text = @category_input[index].to_s
            else
              data = obj.instance_variable_get(inst_var)
              text = data.to_s
            end
          else
            text = @category_input[index].to_s
          end
          rect2 = text_size(text)
          rect2.x = rect.width - rect2.width
          rect2.y = rect.y + 2
          rect2.height -= 4
          contents.fill_rect(rect2,Color.new(0,0,0,150))
          draw_text(rect,text,2)
        end
        is_confirm_button = index == item_max-1 && !@in_root
        if is_confirm_button
          rect4 = Rect.new; rect4.set(rect)
          rect4.width -= 6; rect4.x += 3
          rect4.height -= 6; rect4.y += 3 
          contents.fill_rect(rect4,Color.new(0,0,0,150))
          contents.font.bold = !contents.font.bold
        end
        align = is_confirm_button ? 1 : alignment
        draw_text(rect, name, align)
        contents.font.bold = !contents.font.bold if is_confirm_button
      end
    end
  end
  
  
  def apply_search
    if @category_input.all? {|obj| obj.nil? }
      on_sort_cancel
      @sorted = false
      list = @item_types[@item_type]
      help_list = @item_help[@item_type]
      @charac_viewer.replace_command_list(list,help_list)
      @charac_viewer.select(0)
      return
    end
    search_class_type = @categories[@search_win.index]
    inputs = @category_input.select {|obj| !obj.nil? }
    input_indexes = inputs.map {|obj| @category_input.index(obj) }
    @select_items = @data_list[@types.index(@item_type)] - [nil]
    i = 0
    q = "@"
    i_str = inputs.map{|input| 
      i += 1
      j = input_indexes[i-1]
      class_type = @categories[j]
      sym = @vars[j].to_s
      sym.sub!(q,"")
      if class_type == String
        "obj.#{sym}.upcase.include?(@category_input[#{j}].upcase)"
      elsif class_type.name =~ /\bRPG::\b/
        obj = @category_input[j]
        str = []
        inst_vars = obj.instance_variables
        k = 0
        sym_list = inst_vars.select {|sym| !obj.instance_variable_get(sym).nil? }
        sym_list.map {|sym_|; k += 1
          data = obj.instance_variable_get(sym_)
          sym_ = sym_.to_s.sub(q,"")
          method = "obj.#{sym}.#{sym_}"
          check_method = "@category_input[#{j}].#{sym_}"
          if data.class == String
            method = "#{method}.upcase.include?(#{check_method}.upcase)"
          else
            method = "#{method} == #{check_method}"
          end
          str << method
        }
        str.join(" && ")
      else
        "obj.#{sym} == #{input}"
      end
    }.join(" && ")
    eval_str = "@select_items.select {|obj| #{i_str} }"
    @item_arr = eval(eval_str,binding)
    @sort_list = @item_arr.map {|obj|
      icon = obj.class != RPG::Animation ? obj.icon_index : 0
      ["#{obj.id}: \\I[#{icon}]#{obj.name}",:obj] 
    }
    @sort_help_list = @item_arr.map {|obj|
      obj.class != RPG::Animation ? obj.description : ""
    }
    @sort_id_list = @item_arr.map {|obj| obj.id }
    @charac_viewer.replace_command_list(@sort_list,@sort_help_list)
    on_sort_cancel
    @sorted = true
  end
  
  def on_sort_ok
    if @search_win.current_symbol == :confirm
      apply_search
    else
      if @in_root_class
        start_input
      else
        @root_i = @search_win.index
        @data_class_type = @categories[@root_i]
        if @data_class_type.name =~ /\bRPG::\b/
          @search_win.root_i = @root_i
          @search_win.in_root = true
          if @category_input[@root_i].nil?
            @category_input[@root_i] = @data_class_type.new
            @default_values = Array.new(@category_input.size,0)
            item = @category_input[@root_i]
            inst_vars = item.instance_variables
            @default_values[@root_i] = Array.new(inst_vars.size) {|i|
            sym = inst_vars[i]
            data = item.instance_variable_get(sym)
            item.instance_variable_set(sym,nil)
            data
            }
          else
            item = @category_input[@root_i]
          end
          @prev_vars = @vars
          @prev_categories = @categories
          @prev_input = @input_list
          @prev_help = @help_list
          @vars = item.instance_variables
          @categories = Array.new(@vars.size) {|i| 
            item.instance_variable_get(@vars[i]).class
          }
          defaults = @default_values[@root_i]
          @input_list = Array.new(@vars.size) {|i| ["#{@vars[i]}:",@vars[i]] }
          @help_list = Array.new(@vars.size) {|i| defaults[i].class.name }
          @search_win.replace_command_list(@input_list,@help_list)
          @search_win.select(0)
          @in_root_class = true
        else
          @search_win.in_root = false
          start_input
        end
      end
    end
  end
  
  def start_input
    rect = @search_win.item_rect_for_text(@search_win.index)
    x = rect.x + @search_win.x + 12
    y = @search_win.y + 12 + (rect.y - @search_win.oy)
    process_debug_window_entry(x,y,rect.width)
  end
  
  def process_debug_window_entry(x,y,width)
    @debug_entry_window = Window_DebugEntry.new(width)
    @debug_entry_window.x = x
    @debug_entry_window.y = y
    @debug_entry_window.z = 8000
    update_debug_window_entry
    @debug_entry_window.dispose
    @debug_entry_window = nil
    @search_win.activate
  end

  def update_debug_window_entry
    10.times { Graphics.update }
    loop do
      Graphics.update
      Input.update
      @debug_entry_window.update
      if Input.trigger?(Input::ESC)
        Sound.play_cancel
        if @debug_entry_window.text.size > 0
          @debug_entry_window.text = ""
        else
          break
        end
      elsif Input.trigger?(Input::ENTER)
        code = @debug_entry_window.text
        begin
          i = @search_win.index
          if code.empty?
            data = nil
          else
            if @in_root_class
              obj = @category_input[@root_i]
              inst_var = obj.instance_variables[i]
              data = obj.instance_variable_get(inst_var)
              class_obj = @default_values[@root_i][i].class
            else
              class_obj = @data_class_type
            end
            data = class_obj == String ? code.upcase : eval(code,binding)
          end
          if @in_root_class
            obj = @category_input[@root_i]
            inst_var = obj.instance_variables[@search_win.index]
            obj.instance_variable_set(inst_var,data)
          else
            @category_input[i] = data
          end
          @search_win.refresh
          Sound.play_ok
          break
        rescue Exception => ex
          puts ex.message
          Sound.play_buzzer
        end
      end
    end
  end
  
  
  def get_sort_options
    id = @item_id_list[@item_type][0]
    item = @data_list[@types.index(@item_type)][id]
    @vars = item.instance_variables
    @categories = Array.new(@vars.size) {|i| 
      item.instance_variable_get(@vars[i]).class
    }
    @category_input = Array.new(@vars.size,nil)
    @input_list = Array.new(@vars.size) {|i| ["#{@vars[i]}:",@vars[i]] }
    @help_list = Array.new(@vars.size) {|i| @categories[i].name }
    @input_list << [CONFIRM,:confirm]
    @help_list << START_SORT
    @search_win.replace_command_list(@input_list,@help_list)
    @search_win.instance_variable_set(:@category_input,@category_input)
  end
  
  def draw_arr(list)
    l_size = list.size
    i = 0
    height = is_text_fitting?(list)
    while l_size > i
      draw_t(height*i,list[i].to_s)
      i += 1
    end
  end
  
  def is_text_fitting?(str)
    height = @charac_viewer.text_size(str.is_a?(Array) ? str[0].to_s : str).height
    l_size = str.size
    max = height*l_size
    max_w = str.is_a?(Array) ? str.max_by {|data| data.to_s.size } : str.to_s.size
    max_w = @display_win.text_size(max_w.to_s).width
    contents = @display_win.contents
    new_w = contents.width > max_w ? contents.width : max_w
    new_h = contents.height > max ? contents.height : max
    if max > contents.height || max_w >contents.width
      @display_win.contents.dispose
      new_w = MAX_DISPLAY_WIN_WIDTH if new_w > MAX_DISPLAY_WIN_WIDTH
      new_h = MAX_DISPLAY_WIN_HEIGHT if new_h > MAX_DISPLAY_WIN_HEIGHT
      @display_win.contents = Bitmap.new(new_w, new_h)
      @display_win.contents.font.size = 21
    end
    height
  end
  
  def draw_t(y,text)
    rect = @display_win.text_size(text)
    rect.y = y
    @display_win.draw_text(rect,text)
  end

  def on_npc_list_ok
    case @type
    when :data_types
      @item_type = @charac_viewer.current_symbol
      @npc_name = @charac_viewer.command_name(@charac_viewer.index)
      sym = :data_list
    when :data_list
      @list_i = @charac_viewer.index
      sym = :data
    when :data
      inst_var = @item.instance_variables
      obj = @item.instance_variable_get(inst_var[@charac_viewer.index])
      if obj.is_a?(Array) || !obj.instance_variables.empty?
        sym = :root_data
        @obj_root = [@item,obj]
      else
        @charac_viewer.activate
      end
    when :root_data
      inst_var = @item.instance_variables
      if @item.is_a?(Array)
        obj = @item[@charac_viewer.index]
      else
        obj = @item.instance_variable_get(inst_var[@charac_viewer.index])
      end
      if obj.is_a?(Array) || !obj.instance_variables.empty?
        @obj_root << obj
        sym = :root_data
      else
        @charac_viewer.activate
      end
    else
      @charac_viewer.activate
    end
    if !sym.nil?
      @index_history << @charac_viewer.index
      @select_history << sym.to_s
      draw_history
      set_type_data(sym)
      @charac_viewer.select(0)
    end
  end
  
  def set_type_data(type)
    @history_size = @select_history.size
    type = :root_data if type == :data && @obj_root && @obj_root.size > 2
    show_prompt = false
    case type
    when :data_types
      @sorted = false
      set_title(TYPE_SELECT)
      list = @arr
      help_list = @help
      @charac_viewer.oy = 0
    when :data_list
      show_prompt = true
      sym = @item_type
      set_title(sym.to_s.capitalize)
      list = @sorted ? @sort_list : @item_types[sym]
      help_list = @sorted ? @sort_help_list : @item_help[sym]
    when :data
      list = @sorted ? @sort_id_list : @item_id_list[@item_type]
      id = list.size <= @list_i ? list[0] : list[@list_i]
      @item = @data_list[@types.index(@item_type)][id]
      list = []; inst_vars = @item.instance_variables
      i = 0; i_size = inst_vars.size; max_s = 40
      while i_size > i
        i_var = inst_vars[i]
        data_str = @item.instance_variable_get(i_var).to_s
        data_str = "#{data_str[0..max_s]}..." if data_str.bytesize > max_s
        list << ["#{i_var}: #{data_str}", i_var]; i += 1
      end
      help_list = Array.new(list.size) {|i| 
        @item.instance_variable_get(inst_vars[i]).class.name 
      }
      set_title(@item.name)
    when :root_data
      @obj_root.pop if @prev_history_size > @history_size
      @item = @obj_root[-1]
      i = 0; list = []; max_s = 40
      if @item.is_a?(Array)
        inst_vars = @item; i_size = inst_vars.size
        while i_size > i
          i_var = inst_vars[i]
          data_str = i_var.method(:to_s).owner==i_var.class ? i_var.to_s : i_var.class.name
          data_str = "#{data_str[0..max_s]}..." if data_str.bytesize > max_s
          list << ["#{i}: #{data_str}", i_var]; i += 1
        end
      else
        inst_vars = @item.instance_variables; i_size = inst_vars.size
        while i_size > i
          i_var = inst_vars[i]
          data_str = @item.instance_variable_get(i_var).to_s
          data_str = "#{data_str[0..max_s]}..." if data_str.bytesize > max_s
          list << ["#{i_var}: #{data_str}", i_var]; i += 1
        end
      end
      help_list = Array.new(list.size,"")
      set_title(@item.class.name)
    end
    if !list.nil?
      @type = type
      @charac_viewer.replace_command_list(list, help_list)
    end
    @prev_index = -1
    @charac_viewer.activate
    @prev_history_size = @select_history.size
    @prompt_sprite.opacity = show_prompt ? 255 : 0
  end
  
  def on_npc_list_cancel
    if Depth_List.key?(@type)
      @select_history.pop
      @charac_viewer.select(@index_history.pop)
      draw_history
      set_type_data(Depth_List[@type])
    else
      return_scene
    end
  end
  
  def dispose_em(vars, class_name)
    v_size = vars.size
    i = 0
    if class_name == Sprite
      while v_size > i
        varname = vars[i]
        ivar = instance_variable_get(varname)
        if ivar.is_a?(class_name)
          ivar.bitmap.dispose if ivar.bitmap
          ivar.viewport = nil
          ivar.dispose
          remove_instance_variable(varname)
          vars[i] = nil
        end
        i += 1
      end
    else
      while v_size > i
        varname = vars[i]
        ivar = instance_variable_get(varname)
        if ivar.is_a?(class_name)
          ivar.dispose
          remove_instance_variable(varname)
          vars[i] = nil
        end
        i += 1
      end
    end
    vars.compact!
  end
  
  def terminate
    Graphics.freeze
    inst_vars = instance_variables - EXCLUDED_DISPOSE
    dispose_em(inst_vars, Bitmap)
    dispose_em(inst_vars, Sprite)
    super
  end
end
end # $TEST

class Window_CustomCommands < Window_Command
  def initialize(x, y, width, command_list, help_list = nil)
    @help_descs = help_list
    @command_list = command_list
    @list_amount = @command_list.size
    @width = width
    super(x, y)
  end
  
  def update
    super
    if @help_window && @help_descs && active
      @help_window.set_text(@help_descs[@index])
    end
  end
  
  def window_width; return @width; end

  def replace_command_list(list, help_list = nil)
    @command_list = list
    @help_descs = help_list
    @list_amount = @command_list.size
    max_i = @list_amount - 1
    refresh
    if index > max_i
      select(max_i)
    end
    activate
  end

  def make_command_list
    i = 0
    while @list_amount > i
      command = @command_list[i]
      add_command(command[0], command[1])
      i += 1
    end
  end
end