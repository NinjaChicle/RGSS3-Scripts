#--------------------------------------------------------------------------
#* Party Member Select Script
#
# A script for RPG Maker VX Ace projects
#
# script by: NinjaChicle
#
# This script lets you select an actor from your party and save their ID
# in a variable. Also saves the name of the actor in a different
# variable too if you want to.
#
# To use it, just put SceneManager.call(Scene_ActorSelect) in a script call and then 
# add the wait command for one frame, and you will be able to select an actor and then use the ID for
# whatever you want.
#
#--------------------------------------------------------------------------

module YAHOO
  ACTOR_ID_VAR = 1 #the variable in which the actor id will be saved in.
  ACTOR_NAME = 2   #this variable will save the name of the selected actor.
                   #set ACTOR_NAME to 0 if you don't need it.
  SELECT_TEXT = "Choose who \nshould be \nselected." #the \n moves the text after it one line down.
end

class Scene_ActorSelect < Scene_MenuBase
  def start
    super
    @okay = false
    create_actor_window
    show_sub_window(@actor_window)
  end
 

  def update
    super
    return if @okay != true
    do_stuff
    return if @actor_window.opacity != 0
    @actor_window.hide.deactivate
    @text_window.hide
    return_scene
  end

  def do_stuff
    move_window(@actor_window, 550, 13)
    ghost_actor_window(0)
    @text_window.opacity = @actor_window.opacity
    @actor_window.contents_opacity = @actor_window.opacity
    move_window(@text_window, -450, 13)
  end

  def move_window(window, x, speed)
    current_x = window.x
    window.x = [x, current_x + speed].min if current_x < x
    window.x = [x, current_x - speed].max if current_x > x
  end
  def ghost_actor_window(opacity)
    current_o = @actor_window.opacity
    @actor_window.opacity = [opacity, current_o + 13].min if current_o < opacity
    @actor_window.opacity = [opacity, current_o - 13].max if current_o > opacity
  end
  #--------------------------------------------------------------------------
  # show_sub_window
  #--------------------------------------------------------------------------
  def show_sub_window(window)
    width_remain = Graphics.width - window.width
    window.x = width_remain
    @viewport.rect.x = @viewport.ox = 0
    @viewport.rect.width = width_remain
    window.show.activate
  end

  #--------------------------------------------------------------------------
  # on_actor_ok
  #--------------------------------------------------------------------------

  def on_actor_ok
      Sound.play_ok
      $game_party.menu_actor = $game_party.members[@actor_window.index]
      $game_variables[YAHOO::ACTOR_ID_VAR] = $game_party.menu_actor.id
      window = @actor_window
      @okay = true
      $game_variables[YAHOO::ACTOR_NAME] = $game_actors[$game_party.menu_actor.id].name unless YAHOO::ACTOR_NAME == 0
  end

  #--------------------------------------------------------------------------
  # on_actor_cancel
  #--------------------------------------------------------------------------

  def on_actor_cancel
    Sound.play_buzzer
    @actor_window.activate
  end

  def create_actor_window
    @actor_window = Window_MenuActor.new
    @actor_window.set_handler(:ok,     method(:on_actor_ok))
    @actor_window.set_handler(:cancel, method(:on_actor_cancel))
    @actor_window.select_last
    @text_window = Window_Base.new(0,0,200,120)
    @text_window.width = Graphics.width - @actor_window.width
    @text = YAHOO::SELECT_TEXT
    @text_window.draw_text_ex(0,0,@text)
  end
end