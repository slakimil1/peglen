extends HBoxContainer

signal LootButton_pressed

var num

func _on_LootButton_pressed():
	emit_signal("LootButton_pressed", num)
