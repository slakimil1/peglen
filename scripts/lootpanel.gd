extends Control

var loot_dic = {}
var current_chest
var loot_slot_scene = "res://scenes/UI/Slot.tscn"

signal close_lootpanel

func _ready():
	pass
#	get_parent().connect("_open_chest", self, "open_chest")
	
func open_chest(chest):
	current_chest = get_node("/root/GameWorld/LootChests/" + str(chest))
	current_chest.determine_loot_count()
	current_chest.loot_selector()
	loot_dic = current_chest.contents
	populate_panel()

func populate_panel():
	for i in loot_dic.size():
		var sclass = load(loot_slot_scene)
		var sinstance = sclass.instance()
		sinstance.set_name("Loot" + str(i + 1))
		sinstance.num = i + 1
		$Border/Mainnodes/Lootslots/SlotsContainer.add_child(sinstance)
		sinstance.connect("LootButton_pressed", self, "_on_LootButton_pressed")
		get_node(str(sinstance.get_path()) + "/Label").set_text(str(loot_dic[i + 1][1]))
		var icon = "res://assets/art/" + str(loot_dic[i + 1][0]) + ".png"
		get_node(str(sinstance.get_path()) + "/LootIcon/LootButton").set_normal_texture(load(icon))
		if loot_dic[i + 1][2] > 1:
			get_node(str(sinstance.get_path()) + "/LootIcon/LootButton/Label").set_text(str(loot_dic[i + 1][2]))
				
func _on_CloseButton_pressed():
	current_chest.contents = loot_dic
	emit_signal("close_lootpanel")

func _on_LootButton_pressed(lootpanelslot):
	if !loot_dic.has(lootpanelslot):
		return
		
	var loot_id = loot_dic[lootpanelslot][0]
	var loot_count = loot_dic[lootpanelslot][2]
	Gamestate.loot_change(loot_id, loot_count)
	
#	$Border/Mainnodes/Lootslots/SlotsContainer.get_node("Loot" + str(lootpanelslot))
#
#	var slot_node = $Border/Mainnodes/Lootslots/SlotsContainer.get_node("Loot" + str(lootpanelslot))
	
	loot_dic.erase(lootpanelslot)
	var loot_slot_root = "Mainnodes/Lootslots/SlotsContainer/Loot" + str(lootpanelslot)
	$Border.get_node(loot_slot_root + "/LootIcon/LootButton").set_normal_texture(null)
	$Border.get_node(loot_slot_root + "/LootIcon/LootButton/Label").set_text("")
	$Border.get_node(loot_slot_root + "/Label").set_text("")

#	var counter = loot_dic.size()
#	for i in get_tree().get_nodes_in_group("LootPanelSlots"):
#		if counter != 0:
#			get_node(str(i.get_path()) + "/Label").set_text(str(loot_dic[counter][1]))
#			var icon = "res://assets/art/" + str(loot_dic[counter][0]) + ".png"
#			get_node(str(i.get_path()) + "/LootIcon/LootButton").set_normal_texture(load(icon))
#			if loot_dic[counter][2] > 1:
#				get_node(str(i.get_path()) + "/LootIcon/LootButton/Label").set_text(str(loot_dic[counter][2]))
#			counter -= 1

#	var slot_checker_start
#	var slot_checker_max
#	var looted_item_name = loot_dic[lootpanelslot][0]
#	if loot_dic.has(lootpanelslot):
#		if loot_dic[lootpanelslot][0] == "Gold":
#			ImportData.inven_data.Gold += loot_dic[lootpanelslot][1]
#			loot_dic.erase(lootpanelslot)
#			var loot_slot_root = "Border/Mainnodes/Lootslots/VBoxContainer/Loot" + str(lootpanelslot)
#			get_node(loot_slot_root + "/LootIcon/LootButton").set_normal_texture(null)
#			get_node(loot_slot_root + "/LootIcon/LootButton/Label").set_text("")
#			get_node(loot_slot_root + "/Label").set_text("")
#		else:
#			match ImportData.item_data[looted_item_name].itemtype:
#				"Weapons":
#					slot_checker_start = 101
#					slot_checker_max = 110
#				"Armor":
#					slot_checker_start = 201
#					slot_checker_max = 210
#				"Crafting":
#					slot_checker_start = 301
#					slot_checker_max = 310
#				"Consumables":
#					slot_checker_start = 401
#					slot_checker_max = 410
#				"Other":
#					slot_checker_start = 501
#					slot_checker_max = 510
#			while slot_checker_start <= slot_checker_max + 1:
#				if slot_checker_start > slot_checker_max:
#					print("Your inventory is full")
#					break
#				elif ImportData.inven_data.has(slot_checker_start):
#					slot_checker_start += 1
#				else:
#					ImportData.inven_data[slot_checker_start] = loot_dic[lootpanelslot]
#					loot_dic.erase(lootpanelslot)
#					var loot_slot_root = "Border/Mainnodes/Lootslots/VBoxContainer/Loot" + str(lootpanelslot)
#					get_node(loot_slot_root + "/LootIcon/LootButton").set_normal_texture(null)
#					get_node(loot_slot_root + "/LootIcon/LootButton/Label").set_text("")
#					get_node(loot_slot_root + "/Label").set_text("")
#					return
					
					
				
		
	
