extends Node2D

signal in_loot_range(chest_name)
signal out_loot_range

var map_name
var loot_count

#var looted = false
var contents = {}
#var loot_dic = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	map_name = "Enemy"
	$lbPressF.hide()
	determine_loot_count()
	loot_selector()

func determine_loot_count():
	var item_count_min = ImportData.loot_data[map_name].itemcountmin
	var item_count_max = ImportData.loot_data[map_name].itemcountmax
	randomize()
	loot_count = randi() % ((int(item_count_max) - int(item_count_min)) + 1) + int(item_count_min)
	
func loot_selector():
	contents = {}
	for i in range(1, loot_count + 1):
		randomize()
		var loot_selector = randi() % 100 + 1
		var counter = 1
		while loot_selector >= 0:
			if loot_selector <= ImportData.loot_data[map_name]["item" + str(counter) + "chance"]:
				var loot = []
				loot.append(ImportData.loot_data[map_name]["item" + str(counter) + "id"])
				loot.append(ImportData.loot_data[map_name]["item" + str(counter) + "name"])
				randomize()
				loot.append((int(rand_range(float(ImportData.loot_data[map_name]["item" + str(counter) + "minq"]), float(ImportData.loot_data[map_name]["item" + str(counter) + "maxq"])))))
				contents[contents.size() + 1] = loot
				break
			else:
				loot_selector = loot_selector - ImportData.loot_data[map_name]["item" + str(counter) + "chance"]
				counter += 1
				

func _on_Area2D_body_entered(body):
	$lbPressF.show()
	$AnimationPlayer.play("press_f")
	var chest_name = get_name()
#	emit_signal("in_loot_range", chest_name)
	body.in_loot_range(chest_name)

func _on_Area2D_body_exited(body):
	$lbPressF.hide()
	$AnimationPlayer.stop()
#	emit_signal("out_loot_range")
	body.out_loot_range()
