extends Node2D

var move_speed = 200
onready var current_time = 0
# puppet var repl_position = Vector2()

# shooting
signal shoot
var can_shoot = true

var local_inventory = {
	s00 = "s00",
	s01 = "s10",
	s02 = "s20"
}

signal open_chest(chest)
var main_ui_control = "None"
var chest

func _ready():
	if (is_network_master()):
		$Camera2D.make_current()

func _process(delta):
	# interaction
	if (is_network_master() && Gamestate.accept_player_input):
		gather_inter()
	# Update the timeout  and if "outside of the update window", ball
		current_time += delta
		
		if (current_time < Gamestate.update_delta):
			return
			
	# Inside an "input" window. First "reset" the time counting variable.
	# Rather than just resetting to 0, subtract update_delta from it to try to compensate
	# for some variances in the time counting. Ideally it would be a good idea to check if the 
	# current_time is still bigger than update_delta after this subtraction which would indicate
	# some major lag in the game
		current_time -= Gamestate.update_delta
		
#	if (is_network_master() && Gamestate.accept_player_input):
		gather_input()
		
	upadate_inventory_gui()
	
remote func server_get_player_input(input):
	if (Network.fake_latency > 0):
		yield(get_tree().create_timer(Network.fake_latency / 1000), "timeout")
	
	if (get_tree().is_network_server()):
		# Decode the input data
		var input_data = {
			up = bytes2var(Gamestate.bool_header + input.subarray(0, 0)),
			down = bytes2var(Gamestate.bool_header + input.subarray(1,1)),
			left = bytes2var(Gamestate.bool_header + input.subarray(2,2)),
			right = bytes2var(Gamestate.bool_header + input.subarray(3,3)),
			mouse_pos = bytes2var(Gamestate.vec2_header + input.subarray(4, 11))
#			click = bytes2var(Gamestate.bool_header + input.subarray(12,12))
		}
		# Then cache the dacode data
		Gamestate.cache_input(get_tree().get_rpc_sender_id(), input_data)

remote func server_get_player_inter(input):
	if (Network.fake_latency > 0):
		yield(get_tree().create_timer(Network.fake_latency / 1000), "timeout")
	
	if (get_tree().is_network_server()):
		# Decode the input data
		var inter_data = {
			click = bytes2var(Gamestate.bool_header + input.subarray(0, 0)),
			slot_0 = bytes2var(Gamestate.bool_header + input.subarray(1, 1)),
			slot_1 = bytes2var(Gamestate.bool_header + input.subarray(2, 2)),
			slot_2 = bytes2var(Gamestate.bool_header + input.subarray(3, 3)),
			inter  = bytes2var(Gamestate.bool_header + input.subarray(4, 4)),
			exit   = bytes2var(Gamestate.bool_header + input.subarray(5, 5))
		}
		# Then cache the dacode data
		Gamestate.cache_inter(get_tree().get_rpc_sender_id(), inter_data)
	
remote func client_get_player_update(pos):
	
	if (Network.fake_latency > 0):
		yield(get_tree().create_timer(Network.fake_latency / 1000), "timeout")
	
	position = pos

func upadate_inventory_gui():
	var inv_id = 0
	if get_tree().is_network_server():
		inv_id = 1
		
	if Gamestate.inventory_info.has(Gamestate.player_info.name):
		var p_inventory = Gamestate.inventory_info[Gamestate.player_info.name]
		
		if local_inventory.s00 != p_inventory.s00:
			$PlayerGUI/Inventory/HBoxContainer/Slot0.texture = load(Global.slots_icon[p_inventory.s00])
			local_inventory.s00 = p_inventory.s00
		if local_inventory.s01 != p_inventory.s01:
			$PlayerGUI/Inventory/HBoxContainer/HBoxContainer/Slot1.texture = load(Global.slots_icon[p_inventory.s01])
			local_inventory.s01 = p_inventory.s01
		if local_inventory.s02 != p_inventory.s02:
			$PlayerGUI/Inventory/HBoxContainer/HBoxContainer/Slot2.texture = load(Global.slots_icon[p_inventory.s02])
			local_inventory.s02 != p_inventory.s02
			
		$PlayerGUI/Inventory/HBoxContainer/HBoxContainer/GoldCount.text = str(p_inventory.s99)
		$PlayerGUI/Inventory/HBoxContainer/HBoxContainer/BulletCount.text = str(p_inventory.s03)
		if p_inventory.s03 == 0:
			$PlayerGUI/Inventory/HBoxContainer/HBoxContainer/SlotBellet.texture = load(Global.bullet_0)
		else:
			$PlayerGUI/Inventory/HBoxContainer/HBoxContainer/SlotBellet.texture = load(Global.bullet_1)
		
func set_dominant_color(color):
	$SpriteBody.modulate = color

func _on_main_ui_control_pressed():
	if main_ui_control == "loot":
		if chest == null:
			main_ui_control = "None"
		else:
#			if $PlayerGUI/LootPanel.get_children().size() == 0:
#				var lootpanel = load("res://scenes/UI/LootPanel.tscn").instance()
#				$PlayerGUI/LootPanel.add_child(lootpanel)
#				connect("open_chest", lootpanel, "open_chest")
#				lootpanel.connect("close_lootpanel", self, "_close_lootpanel")
#				emit_signal("open_chest", chest)
			
			if (! $PlayerGUI.has_node("LootPanel")):
				var lootpanel = load("res://scenes/UI/LootPanel.tscn").instance()
				$PlayerGUI.add_child(lootpanel)
				connect("open_chest", lootpanel, "open_chest")
				lootpanel.connect("close_lootpanel", self, "_close_lootpanel")
				emit_signal("open_chest", chest)

	elif main_ui_control == "None":
		_close_lootpanel()

func _close_lootpanel():
#	for n in $PlayerGUI/LootPanel.get_children():
#		main_ui_control = "None"
#		n.queue_free()
	$PlayerGUI/LootPanel.queue_free()
		
func gather_input():
	var input_data = {
		up = Input.is_action_pressed("move_up"),
		down = Input.is_action_pressed("move_down"),
		left = Input.is_action_pressed("move_left"),
		right = Input.is_action_pressed("move_right"),
		mouse_pos = get_global_mouse_position()
	}
	
	if input_data.up || input_data.down || input_data.left || input_data.right:
		$AnimationPlayer.play("walk")
	else:
		$AnimationPlayer.stop()
	
	if (get_tree().is_network_server()):
		# On the srever, direcly cache  the input data
		Gamestate.cache_input(1, input_data)
		
	else:
		# On a client. Encode the data and send to the server
		var encoded = PoolByteArray()
		encoded.append(input_data.up)
		encoded.append(input_data.down)
		encoded.append(input_data.left)
		encoded.append(input_data.right)
		encoded.append_array(Gamestate.encode_8bytes(input_data.mouse_pos))
#		encoded.append(input_data.click)
		rpc_unreliable_id(1, "server_get_player_input", encoded)
		
func gather_inter():
	
	var inter_data = {
		click = Input.is_action_just_pressed("click"),
		slot_0 = Input.is_action_just_pressed("slot_0"),
		slot_1 = Input.is_action_just_pressed("slot_1"),
		slot_2 = Input.is_action_just_pressed("slot_2"),
		inter  = Input.is_action_just_pressed("interaction"),
		exit   = Input.is_action_just_pressed("exit")
		}
		
#			if inter.inter:
#				main_ui_control = "loot"
#				_on_main_ui_control_pressed()
#			# Shooting player
#			elif inter.click && main_ui_control == "None":
#				pnode.shoot(inter.net_id)
#
#			if (inter.exit):
#				main_ui_control = "None"
#				_on_main_ui_control_pressed()

	if inter_data.inter:
		main_ui_control = "loot"
		_on_main_ui_control_pressed()
	# Shooting player
#		elif inter.click && main_ui_control == "None":
#			pnode.shoot(inter.net_id)
	if (inter_data.exit):
		main_ui_control = "None"
		_on_main_ui_control_pressed()

	var is_inter = false
#	if (inter_data.click || inter_data.inter || inter_data.exit):
	if (inter_data.click):
		is_inter = true
		
	if (inter_data.slot_0 || inter_data.slot_1 || inter_data.slot_2):
		is_inter = true
		
	if (get_tree().is_network_server()):
		# On the srever, direcly cache  the input data
		if is_inter:
			Gamestate.cache_inter(1, inter_data)
	else:
		# On a client. Encode the data and send to the server		
		if is_inter:
			var encoded_inter = PoolByteArray()
#			encoded_inter.append(inter_data.click)	
			for i in inter_data:
				encoded_inter.append(inter_data[i])
			rpc_id(1, "server_get_player_inter", encoded_inter)

func turret_rotation(from_rot, to_rot, alpha):
	$Turret.rotation = lerp(from_rot, to_rot, alpha)

func turret_look(to_look):
	if to_look != null:
		$Turret.look_at(to_look)

func get_turret_rotation():
	var _look = $Turret.rotation
	if _look == 0 or _look == null:
		return Vector2(0,0)
	else:
		return Vector2(cos(_look), sin(_look))

func shoot(net_id):
	var p_inventory = Gamestate.inventory_info[Network.get_player_name(net_id)]
	var dir = Vector2(1,0).rotated($Turret.global_rotation)
	if p_inventory.s00 == "s21":
		if can_shoot:
			if p_inventory.s03 <= 0:
				return
#			Gamestate.loot_change("bullets_02", -1)
			Gamestate.loot_added(net_id, "bullets_02", -1)
			can_shoot = false
			$GunTimer.start()
			emit_signal('shoot', 1, $Turret/Muzzle.global_position, dir, "shoot")
	elif p_inventory.s00 == "s00":
		if can_shoot:
			can_shoot = false
			$GunTimer.start()
			emit_signal('shoot', 1, $Turret/Muzzle.global_position, dir, "knock")
	elif p_inventory.s00 == "s11":
		if can_shoot:
			can_shoot = false
			$GunTimer.start()
			emit_signal('shoot', 1, $Turret/Muzzle.global_position, dir, "knife")

func _on_GunTimer_timeout():
	can_shoot = true

func in_loot_range(chest_name):
	chest = chest_name
	
func out_loot_range():
	chest = null







