extends Control

signal _open_chest(chest)

# Called when the node enters the scene tree for the first time.
func _ready():
	$"/root/GameWorld".connect("open_chest", self, "open_chest")
	
func open_chest(chest):
	emit_signal("_open_chest", chest)
	
