extends Node

var player_bullet = "res://scenes/bullets/playerBullet.tscn"
var enemy_bullet  = "res://scenes/bullets/enemyBullet.tscn"
var knock_scene	  = "res://scenes/bullets/knock.tscn"
var knife_scene	  = "res://scenes/bullets/knife.tscn"
var bullet_list = {}
var knock_list = {}

var bullet_0 = "res://assets/art/bullets_00.png"
var bullet_1 = "res://assets/art/bullets_02.png"

var slots_icon = {
	s00 = "res://assets/art/hand_01.png",
	s10 = "res://assets/art/knife_01.png",
	s11 = "res://assets/art/knife_02.png",
	s20 = "res://assets/art/gun_01.png",
	s21 = "res://assets/art/gun_02.png"
}

# Called when the node enters the scene tree for the first time.
func _ready():
	bullet_list[1] = player_bullet
	bullet_list[2] = enemy_bullet
		
	knock_list["knock"] = knock_scene
	knock_list["knife"] = knife_scene


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
