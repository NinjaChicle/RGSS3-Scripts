#------------------------------------------------------------------------------#
# - Item Age Sorting Script - by NinjaChicle
#
# This script pushes the most recent obtained item to
# the first index in the item list.
#
# v1.1 - Fixed issue where item disappeared after being used in the menu while
#        the item number was still above 0.
# v1.2 - Fixed Hime's Instance Items compatibility
#------------------------------------------------------------------------------#
module Sort_em_all
 SORT_ITEMS   = true
 SORT_WEAPONS = true
 SORT_ARMORS  = true
end
# Turn to false if you don't want a type of item to be sorted.
# For the sorting to take effect, obtain an item in your game.
#
# Doesn't work well on save files that existed before using this script.

module DataManager
  class << self
    alias :itemtastic_create_game_objects :create_game_objects
    alias :itemtastic_make_save_contents :make_save_contents 
    alias :itemtastic_extract_save_contents :extract_save_contents
  end
  
  def self.create_game_objects
    itemtastic_create_game_objects
    $awesome_items = []
    $awesome_weapons = []
    $awesome_armors = []
  end
  def self.make_save_contents
    contents = itemtastic_make_save_contents
    contents[:sorted_items]   = $awesome_items
    contents[:sorted_weapons] = $awesome_weapons
    contents[:sorted_armors]  = $awesome_armors
    contents
  end
  
  def self.extract_save_contents(contents)
    itemtastic_extract_save_contents(contents)
    $awesome_items = contents[:sorted_items]     || []
    $awesome_weapons = contents[:sorted_weapons] || []
    $awesome_armors = contents[:sorted_armors]   || []
  end
end

class Game_Party < Game_Unit
  alias sortastic_gain_item gain_item
  def gain_item(item, amount, include_equip = false)
    sortastic_gain_item(item, amount, include_equip)
      if item.is_a?(RPG::Item) && Sort_em_all::SORT_ITEMS == true
       $awesome_items ||= []
       $awesome_items = $game_party.all_items.select {|item| item.is_a?(RPG::Item) } if $awesome_items == []
       if $imported["TH_InstanceItems"] && !instance_enabled?(item) || !$imported["TH_InstanceItems"]
        $awesome_items.delete(item) if $awesome_items.include?(item)
        $awesome_items.unshift(item) unless $game_party.item_number(item) < 1
       end
      elsif item.is_a?(RPG::Weapon) && Sort_em_all::SORT_WEAPONS == true
       $awesome_weapons ||= []
       $awesome_weapons = $game_party.all_items.select {|item| item.is_a?(RPG::Weapon) } if $awesome_weapons == []
       if $imported["TH_InstanceItems"] && !instance_enabled?(item) || !$imported["TH_InstanceItems"]
        $awesome_weapons.delete(item) if $awesome_weapons.include?(item)
        $awesome_weapons.unshift(item) unless $game_party.item_number(item) < 1
       end
      elsif item.is_a?(RPG::Armor) && Sort_em_all::SORT_ARMORS == true
       $awesome_armors ||= []
       $awesome_armors = $game_party.all_items.select {|item| item.is_a?(RPG::Armor) } if $awesome_armors == []
       if $imported["TH_InstanceItems"] && !instance_enabled?(item) || !$imported["TH_InstanceItems"]
        $awesome_armors.delete(item) if $awesome_armors.include?(item)
        $awesome_armors.unshift(item) unless $game_party.item_number(item) < 1
       end
      end
  end
#-------------------------------------------------------------------------------#
# Instance Items compatibility
#-------------------------------------------------------------------------------#
  if $imported["TH_InstanceItems"]
   alias you_gotta_add_instance add_instance_item
   def add_instance_item(item)
    you_gotta_add_instance(item)
    awesome_stuff = get_awesome_item(item)
    awesome_stuff ||= []
    awesome_stuff = select_awesome_item(item) if awesome_stuff == []
    awesome_stuff.delete(item) if awesome_stuff.include?(item)
    awesome_stuff.unshift(item)
    set_awesome_item(awesome_stuff)
   end
  
   alias you_gotta_lose_instance lose_instance_item
   def lose_instance_item(item)
    you_gotta_lose_instance(item)
    awesome_stuff = get_awesome_item(item)
    awesome_stuff ||= []
    awesome_stuff = select_awesome_item(item) if awesome_stuff == []
    awesome_stuff.delete(item) if awesome_stuff.include?(item)
    set_awesome_item(awesome_stuff)
   end
 
   def lose_template_item(item, include_equip)
    container_list = item_container_list(item)
    item_lost = container_list.find {|obj| obj.template_id == item.template_id }
    if item_lost
      container = item_container(item.class)
      container[item.template_id] ||= 0
      container[item.template_id] -= 1
      container_list.delete(item_lost)
    elsif include_equip
      discard_members_template_equip(item, 1)
    end
    awesome_stuff = get_awesome_item(item_lost)
    awesome_stuff ||= []
    awesome_stuff = select_awesome_item(item_lost) if awesome_stuff == []
    awesome_stuff.delete(item_lost) if awesome_stuff.include?(item_lost)
    set_awesome_item(awesome_stuff)
    return item_lost
  end
 end
#-------------------------------------------------------------------------------#
# Instance Items compatibility
#-------------------------------------------------------------------------------#
  def select_awesome_item(item)
   return $awesome_weapons = $game_party.all_items.select {|item| item.is_a?(RPG::Weapon) } if item.is_a?(RPG::Weapon)
   return $awesome_armors = $game_party.all_items.select {|item| item.is_a?(RPG::Armor) } if item.is_a?(RPG::Armor)
   return $awesome_items = $game_party.all_items.select {|item| item.is_a?(RPG::Item) } if item.is_a?(RPG::Item)
  end
  
  def set_awesome_item(item)
   return $awesome_weapons = item if item.is_a?(RPG::Weapon)
   return $awesome_armors = item if item.is_a?(RPG::Armor)
   return $awesome_items = item if item.is_a?(RPG::Item)
 end
 
  def get_awesome_item(item)
   return $awesome_weapons if item.is_a?(RPG::Weapon)
   return $awesome_armors if item.is_a?(RPG::Armor)
   return $awesome_items if item.is_a?(RPG::Item)
  end
end

class Window_ItemList < Window_Selectable
  alias sortastic_make_item_list make_item_list
  def make_item_list
    sortastic_make_item_list
    if SceneManager.scene_is?(Scene_Item)
       if @data[0].is_a?(RPG::Weapon)
        if Sort_em_all::SORT_WEAPONS == true
         @data = $awesome_weapons.select {|item| include?(item) }
         @data.push(nil) if include?(nil)
        end
      elsif @data[0].is_a?(RPG::Armor)
        if Sort_em_all::SORT_ARMORS == true 
         @data = $awesome_armors.select {|item| include?(item) }
         @data.push(nil) if include?(nil)
        end
      else
        if Sort_em_all::SORT_ITEMS == true
         @data = $awesome_items.select {|item| include?(item) }
         @data.push(nil) if include?(nil)
        end
      end
    end
  end
end