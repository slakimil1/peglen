extends Node

var item_data
var loot_data
var inven_data = {"Gold": 10}

func _ready():
	var itemdata_file = File.new()
	itemdata_file.open("res://data/PeglenLootTable.json", File.READ)
	var itemdata_json = JSON.parse(itemdata_file.get_as_text())
	itemdata_file.close()
	if itemdata_json.error_string != "":
		print("Error load data:" + itemdata_json.error_string + "; line: " + str(itemdata_json.error_line))
	item_data = convert_json_data(itemdata_json.result)
#	var json_data = itemdata_json.result
#	if json_data != null:
#		item_data = {}
#		for d in json_data:
#			var map = {}
#			var mapname
#			for s in d:
#				if s == "mapname":
#					mapname = d[s]
#				map[s] = d[s]
#			item_data[mapname] = map
	
	var lootdata_file = File.new()
	lootdata_file.open("res://data/PeglenLootTable.json", File.READ)
	var lootdata_json = JSON.parse(lootdata_file.get_as_text())
	lootdata_file.close()
	loot_data = convert_json_data(lootdata_json.result)
#	loot_data = lootdata_json.result
#	print(loot_data)

func convert_json_data(_json_result):
	var _data
	if _json_result != null:
		_data = {}
		for d in _json_result:
			var map = {}
			var mapname
			for s in d:
				if s == "mapname":
					mapname = d[s]
					
				if s.ends_with("id"):
					map[s] = d[s]
				else:
					var int_s = int(d[s])
					if int_s == 0 && s != "0":
						map[s] = d[s]
					else:
						map[s] = int_s
				
			_data[mapname] = map
	return _data


