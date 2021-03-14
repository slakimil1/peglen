extends Node2D

var player_row = {}
onready var current_time = 0
var from_to = {}

var main_ui_control = "None"
var chest

func _ready():	
	#Connect event handlerto the player_lilst_changed signal
	Network.connect("player_list_changed", self, "_on_player_list_changed")
	# Must act if disconnected from the server
	Network.connect("disconnected", self, "_on_disconnected")
	# Once a new ping measurement is given, let's update the value within the HUD
	Network.connect("ping_updated", self, "_on_ping_update")
	# If we are in the server, connect to the event that will deal with player despawning
	if (get_tree().is_network_server()):
		Network.connect("player_removed", self, "_on_player_removed")
		
	# After receiving and fully decoding a new snapshot, apply it to the game world
	Gamestate.connect("snapshot_received", self, "apply_snapshot")	
		
	#Update the lblLocalPlayer label widget to dislay the local player name
	$HUD/PanelPlayerList/lblLocalPlayer.text = Gamestate.player_info.name
	
	# Hide the server info panel if on the server - it doesn't make any sense anyway
	if (get_tree().is_network_server()):
		$HUD/PanelServerInfo.hide()
	
	# Spawn the players
	if (get_tree().is_network_server()):
		spawn_players(Gamestate.player_info, 1)
		sync_bots(-1) # The amount doesn't matter because it will be calculated in the function body
	else:
		rpc_id(1, "spawn_players", Gamestate.player_info, -1)
		rpc_id(1, "sync_bots", -1)
		
#	for ch in get_tree().get_nodes_in_group("LootChests"):
#		ch.connect("in_loot_range", self, "_on_lootchest_in_loot_range")
#		ch.connect("out_loot_range", self, "_on_lootchest_out_loot_range")

func _process(delta):
	# Interpolate the state
	var count_time = Gamestate.update_delta
	for p in from_to:
		if (from_to[p].time >= count_time):
			continue
			
		from_to[p].time += delta
		var alpha = from_to[p].time / count_time
		from_to[p].node.position = lerp(from_to[p].from_loc, from_to[p].to_loc, alpha)
		#from_to[p].node.rotation = lerp(from_to[p].from_rot, from_to[p].to_rot, alpha)
#		from_to[p].node.turret_rotation(from_to[p].from_rot, from_to[p].to_rot, alpha) # rotate 
		from_to[p].node.turret_look(from_to[p].to_look) # look
		
	# Update the timeout counter
	current_time += delta
	if (current_time < Gamestate.update_delta):
		return
		
	# Reset the time counting
	current_time -= Gamestate.update_delta
	
	# And update the game state
	update_state()

func _on_disconnected():
	# Ideally pause the internal simulation and display a message box here
	# From the answer in the maeesage box change back into the main menu scene
	get_tree().change_scene("res://scenes/mainmenu.tscn")

func _on_player_list_changed():
	# Update the server name
	$HUD/PanelServerInfo/lblServerName.text = "Server: " + Network.server_info.name
	
	#First remove all children from the boxList widget
	for c in $HUD/PanelPlayerList/boxList.get_children():
		c.queue_free()
		
	# Reset the row dictionary
	player_row.clear()
	
	var entry_class = load("res://scenes/playerentry.tscn")
		
	# Now iterate throught the player list creating a new entry into the boxList
	for p in Network.players:
		if (p != Gamestate.player_info.net_id):
			var nentry = entry_class.instance()
			nentry.net_id = p
			nentry.set_info(Network.players[p].name, Network.players[p].char_color)
			nentry.connect("whisper_clicked", $HUD/ChatRoot, "_on_whisper")
			$HUD/PanelPlayerList/boxList.add_child(nentry)
			player_row[Network.players[p].net_id] = nentry

func _on_player_removed(pinfo):
	Gamestate.player_input.erase(pinfo.net_id)
	from_to.erase(pinfo.net_id)
	despawn_player(pinfo)
	sync_bots(-1)

func _on_ping_update(peer_id, value):
	if (peer_id == Gamestate.player_info.net_id):
		# Updating the ping for local machine
		$HUD/PanelServerInfo/lbPing.text = "Ping: " + str(int(value))
	else:
		# Updating the ping for someone else in the game
		if (player_row.has(peer_id)):
			player_row[peer_id].set_latency(value)

#func _on_lootchest_in_loot_range(chest_name):
#	chest = chest_name
#
#func _on_lootchest_out_loot_range():
#	chest = null
	
# Spawns a new player actor, usin the provided player_info structure and the given spawn index
remote func spawn_players(pinfo, spawn_index):
	
	if (Network.fake_latency > 0):
		yield(get_tree().create_timer(Network.fake_latency / 1000), "timeout")	
	
	# If the spawn_index is -1  then we define it based on the size of the player list
	if (spawn_index == -1):
		spawn_index = Network.players.size()
		
	if (get_tree().is_network_server() && pinfo.net_id != 1):
		# We are on the server and the requested spawn does not belong to the server
		# Iterate through the connected players
		var s_index = 1 # Will be used as spawn index
		for id in Network.players:
			# Spawn currently iterated player within the new player's scene, skipping the new player for now
			if (id != pinfo.net_id):
				rpc_id(pinfo.net_id, "spawn_players", Network.players[id], s_index)
	
			# Spawn the new player within the curently iterated player as long it's not the server
			# Because the server's list alredy contains the new player, that one will also get itself
			if (id != 1):
				rpc_id(id, "spawn_players", pinfo, spawn_index)
				
			s_index += 1
			
	# Load the scene and create an instence
	var pclass = load(pinfo.actor_path)
	var nactor = pclass.instance()
	# Setup player customazation (well, the color)
	nactor.set_dominant_color(pinfo.char_color)
	# And the actor position
	nactor.position = $SpawnPoints.get_node(str(spawn_index)).position
	# If this actor does not belong to the server, change the node name and network master accordingly
	if (pinfo.net_id != 1):
		nactor.set_network_master(pinfo.net_id)
	nactor.set_name(str(pinfo.net_id))
		
	# Finaly add the actor into the world
	add_child(nactor)
	#if (get_tree().is_network_server() && pinfo.net_id == 1):
	
	# Shooting
	nactor.connect("shoot", self, "_on_player_shoot")

	# Inventory	
	Gamestate.set_inventory_def(pinfo.net_id)
	
#	if Gamestate.inventory_info.has("p" + str(inter.net_id)):
#		var p_inventory = Gamestate.inventory_info["p" + str(inter.net_id)]
#		if inter.slot_0:
#			p_inventory.s00 = 0
#		elif inter.slot_1 && p_inventory.s01 == "s11":
#			p_inventory.s01 = 11
#		elif inter.slot_2 && p_inventory.s02 == "s21":
#			p_inventory.s02 = 21
#
#	#pnode.change_inventory(inter)
#
##var slots_icon = {
##	s00 = "res://assets/hand_01.png",
##	s10 = "res://assets/knife_01.png",
##	s11 = "res://assets/knife_02.png",
##	s20 = "res://assets/gun_01.png",
##	s21 = "res://assets/gun_02.png"
##}
##var inventory_info = {									# Inventory
##	p0 = {												# Player name
##		s00 = 0,										# Slot by default
##		s01 = 0,										# Slot N1 - knife
##		s02 = 0,										# Slot N2 - gun
##		s03 = 0											# Slot N3 - gold
##	}
##}	
	
remote func despawn_player(pinfo):
	
	if (Network.fake_latency > 0):
		yield(get_tree().create_timer(Network.fake_latency / 1000), "timeout")	
	
	if (get_tree().is_network_server()):
		for id in Network.players:
			# Skip disconneted player and server from replacation code
			if (id == pinfo.net_id || id == 1):
				continue
				
			# Replicate despawn into currently iterated player
			rpc_id(id, "despawn_player", pinfo)
			
	# Try to locate the player actor
	var player_node = get_node(str(pinfo.net_id))
	if (!player_node):
		print("Cannot remove invalid node from tree")
		return
		
	# Make the node for deletion
	player_node.queue_free()

remote func sync_bots(bot_count):
	
	if (Network.fake_latency > 0):
		yield(get_tree().create_timer(Network.fake_latency / 1000), "timeout")		
	
	if (get_tree().is_network_server()):
		# Calculate the target amount of spawn bots
		#bot_count = Network.server_info.max_players#Network.server_info.max_players - Network.players.size()
		bot_count = Network.max_bots
		
		# Relay this to the connected players
		rpc("sync_bots", bot_count)
		
	if (Gamestate.spawned_bots > bot_count):
		# We have more bots than the target  count - must remowe some
		while (Gamestate.spawned_bots > bot_count):
			# Locate the bot's node
			var bnode = get_node(Gamestate.bot_info[Gamestate.spawned_bots].name)
			if (!bnode):
				print("Must remove from game but cannot find it's node'")
				return
			# Mark it for removal
			bnode.queue_free()
			# And update the spawned bot count
			Gamestate.spawned_bots -= 1
			
	elif (Gamestate.spawned_bots < bot_count):
		# We have less bots than the target count - must add some
		# Since every single bot uses the exact same scene path we can cache it's loaded scene here
		# otherwise, we would have to move the following code into the while loop and change the dictonary
		# key ID to point into the correct bot info. In this case we are pointing to the 1
		var bot_class = load(Gamestate.bot_info[1].actor_path)
		
		while (Gamestate.spawned_bots < bot_count):
			var nbot = bot_class.instance()
			nbot.set_name(Gamestate.bot_info[Gamestate.spawned_bots + 1].name)
			add_child(nbot)
			Gamestate.spawned_bots += 1

func _on_txtFakeLatency_value_changed(value):
	Network.fake_latency = value

func _on_btClearFocus_pressed():
	$HUD/btClearFocus.release_focus()

func _on_player_shoot(_bullet_num, _position, _dir, type):
	match type:
		"shoot":
			Gamestate.bullet_num += 1
			var bclass = load(Global.bullet_list[_bullet_num])
			var binstance = bclass.instance()
			binstance.set_name("PlayerBullet_" + str(Gamestate.bullet_num))
			binstance.id = Gamestate.bullet_num
			$Bullets.add_child(binstance)
			binstance.start(_position, _dir)
			binstance.set_type(_bullet_num)
		#	print("shoot")
		"knock":
			add_knock_instance(_bullet_num, _position, _dir, type)
		"knife":
			add_knock_instance(_bullet_num, _position, _dir, type)
			
func add_knock_instance(_bullet_num, _position, _dir, type):
	if (! is_network_master()):
		return
		
	if _bullet_num == 1:
		Gamestate.bullet_num += 1
		var bclass = load(Global.knock_list[type])
		var binstance = bclass.instance()
		binstance.set_name("knock_" + str(Gamestate.bullet_num))
		$Knock.add_child(binstance)
		binstance.start(_position, _dir)
		
		for id in Network.players:
			if (Network.players[id].net_id != 1):
				rpc_id(Network.players[id].net_id, "remote_add_knock_instance", _bullet_num, Gamestate.bullet_num, _position, _dir, type)

remote func remote_add_knock_instance(bullet_type, bullet_num, _position, _dir, type):
	if (is_network_master()):
		return
		
	if bullet_type == 1:
		var bclass = load(Global.knock_list[type])
		var binstance = bclass.instance()
		binstance.set_name("knock_" + str(Gamestate.bullet_num))
		$Knock.add_child(binstance)
		binstance.start(_position, _dir)

func create_bullet(_bullet_type, _bullet_id):
	var bclass = load(Global.bullet_list[_bullet_type])
	var binstance = bclass.instance()
	binstance.set_name("PlayerBullet_" + str(_bullet_id))
	binstance.id = _bullet_id
	$Bullets.add_child(binstance)
	
# Update and generate a game state snapshot
func update_state():

	# If not on the server, bail
	if (!get_tree().is_network_server()):
		return
		
	# Initialize the "hight level" snapshot
	var snapshot = {
		signature = Gamestate.snapshot_signature,
		player_data = [],
		bot_data = [],
		player_inter = [],
		bullet_data = []
	}

	# Iterate through each player
	for p_id in Network.players:
		# Locate the player's node. Even if there is no input/update, it's state will be dumped
		# into the snapshot anyway
		var player_node = get_node(str(p_id))
		
		if (!player_node):
			# Ideally should give a warning that a player node wasn't found
			continue
			
		var p_pos = player_node.position 
		var p_rot = player_node.rotation
		var p_look = player_node.get_turret_rotation()
			
		# Check if there is any input for this player. In that case, update the state
		if (Gamestate.player_input.has(p_id) && Gamestate.player_input[p_id].size() > 0):
			# Calculate the delta 
			var delta = Gamestate.update_delta / float(Gamestate.player_input[p_id].size())
			
			# Now, for each input entry, calculate the resulting state
			for input in Gamestate.player_input[p_id]:
				# Build the movement direction vector based on the input
				var move_dir = Vector2()
				if (input.up):
					move_dir.y -= 1
				if (input.down):
					move_dir.y += 1
				if (input.left):
					move_dir.x -= 1
				if (input.right):
					move_dir.x += 1

				# Update the position
				move_dir = move_dir.normalized() * player_node.move_speed * delta
				move_dir = cartesian_to_isometric(move_dir)
				p_pos += move_dir
				# And the rotation
#				p_rot = p_pos.angle_to_point(input.mouse_pos)
				p_rot = p_pos.angle_to_point(input.mouse_pos) + PI
				p_look = input.mouse_pos
			# Cleanup the input vector
			Gamestate.player_input[p_id].clear()
			
		# Build player_data entry
		var pdata_entry = {
			net_id = p_id,
			location = p_pos,
			rot  = p_rot,
			look = p_look,
			col = Network.players[p_id].char_color
		}
		
		# Append into the snapshot
		snapshot.player_data.append(pdata_entry)
		
		if (Gamestate.player_inter.has(p_id) && Gamestate.player_inter[p_id].size() > 0):
			for input in Gamestate.player_inter[p_id]:
				var is_inter = false
				
				if (input.click || input.inter || input.exit ):
					is_inter = true
#					print("click srev")
				elif (input.slot_0 || input.slot_1 || input.slot_2):
					is_inter = true
					
				var pdata_inter = {
					net_id = p_id,
					click = input.click,
					inter = input.inter,
					exit = input.exit,
					slot_0 = input.slot_0,
					slot_1 = input.slot_1,
					slot_2 = input.slot_2
					}
					
				if is_inter:
					snapshot.player_inter.append(pdata_inter)
					
			Gamestate.player_inter[p_id].clear()
		
	for b_id in range(Gamestate.spawned_bots):
		# Locate the bot node
		var bot_node
		if !has_node(Gamestate.bot_info[b_id + 1].name):
			continue
		else:
			bot_node = get_node(Gamestate.bot_info[b_id + 1].name)
		
#		if (!bot_node):
#			# Must give a warning here
#			continue
#
		# Build bot_data entry
		var bdata_entry = {
			bot_id = b_id + 1,
			location = bot_node.position,
			rot = bot_node.rotation,
			health = bot_node.health,
			col = bot_node.color
		}
		# Append into the snapshot
		snapshot.bot_data.append(bdata_entry)
		
	var bullets = $Bullets.get_children()
	
	for bull_id in bullets:
		var bull_data = {
			bull_id = bull_id.id,
			bull_pos  = bull_id.position,
			bull_type = bull_id.type
		}
		snapshot.bullet_data.append(bull_data)
		
	# Encode and broadcast the snapshot - if there is at least one connected client
	var is_test = false
	if (Network.players.size() > 1 or is_test):
		Gamestate.encode_snapshot(snapshot)
	apply_snapshot(snapshot)
	# Make sure the next update will have the correct snapshot signature
	Gamestate.snapshot_signature += 1

func cartesian_to_isometric(cartesian):
	return Vector2(cartesian.x - cartesian.y, (cartesian.x + cartesian.y) / 2)

func apply_snapshot(snapshot):
	# In here we assume the obtained snapshot is newer  than the last one 
	# Iterate throught player data
	for p in snapshot.player_data:
		
		if main_ui_control != "None":
			continue
		
		# Locate the avatar node belonging to the currently iterated player
		var pnode = get_node(str(p.net_id))
		if (!pnode):
			# Depending on the synchronization mechanism, this may not be an error!
			# For now assume the entites are spawned  and kept in sync so just continue
			# the loop
			continue
			
		if (from_to.has(p.net_id)):
			# Curently iterated player already has previos data. Update the interpolation
			# control variables
			
			var crot = from_to[p.net_id].to_rot
			
			from_to[p.net_id].from_loc = from_to[p.net_id].to_loc
			from_to[p.net_id].from_rot = from_to[p.net_id].to_rot
			from_to[p.net_id].to_loc = p.location
			from_to[p.net_id].to_rot = p.rot
			from_to[p.net_id].to_look = p.look
			from_to[p.net_id].time = 0.0
			from_to[p.net_id].node = pnode
			
			#$lblTMPDebug.text = "from: " + str(from_to[p.net_id].from_rot) + " | to: " + str(from_to[p.net_id].rot)
			
		else:
			# There isn't any previous data for this player. Create the initial interpolation
			# data. The next _process() iteration will take care of applyng the state
			from_to[p.net_id] = {
				from_loc = p.location,
				from_rot = p.rot,
				to_loc = p.location,
				to_rot = p.rot,
				to_look = p.look,
				time = Gamestate.update_delta,
				node = pnode
			}
			
		# Apply the location, rotation and color to the player node
		#pnode.position = p.location
		#pnode.rotation = p.rot
		# There is no point in interpolating the color so just apply it
		pnode.set_dominant_color(p.col)
	
	if (get_tree().is_network_server()):
		for inter in snapshot.player_inter:
			var pnode = get_node(str(inter.net_id))
			if (!pnode):
				# Depending on the synchronization mechanism, this may not be an error!
				# For now assume the entites are spawned  and kept in sync so just continue
				# the loop
				continue
				
			if (inter.slot_0 || inter.slot_1 || inter.slot_2):
				change_inventory(inter)
				
#			if inter.inter:
#				main_ui_control = "loot"
#				_on_main_ui_control_pressed()
#			# Shooting player
#			elif inter.click && main_ui_control == "None":
#				pnode.shoot(inter.net_id)

			if inter.click:
				pnode.shoot(inter.net_id)

#			if (inter.exit):
#				main_ui_control = "None"
#				_on_main_ui_control_pressed()	
	
	if (get_tree().is_network_server()):
		pass
#		for inter in snapshot.player_inter:
#			var pnode = get_node(str(inter.net_id))
#			if (!pnode):
#				# Depending on the synchronization mechanism, this may not be an error!
#				# For now assume the entites are spawned  and kept in sync so just continue
#				# the loop
#				continue
#
#			if (inter.slot_0 || inter.slot_1 || inter.slot_2):
#				change_inventory(inter)
#
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
				
	else:
		for bull_id in $Bullets.get_children():
			bull_id.updated = false
			
		# Iterate through bullet data
		for b in snapshot.bullet_data:
			var bnode 
			if $Bullets.has_node("PlayerBullet_" + str(b.bullet_id)):
				bnode = $Bullets.get_node("PlayerBullet_" + str(b.bullet_id))
			else:
				create_bullet(b.bullet_type, b.bullet_id)
				bnode = $Bullets.get_node("PlayerBullet_" + str(b.bullet_id))
			# Apply location, rotation and color to the bot
			bnode.update_state(b)
			
		if snapshot.bullet_data.size() > 0:
			for bull_id in $Bullets.get_children():
				if !bull_id.updated:
					bull_id.queue_free()
		
	 # Iterate through bot data
	for b in snapshot.bot_data:
		# Locate the bot node belonging to the currently iterated bot 
		var bnode = get_node(Gamestate.bot_info[b.bot_id].name)
		if (!bnode):
			continue
			
		# Apply location, rotation and color to the bot
		bnode.update_state(b)

#func _on_main_ui_control_pressed():
#	if main_ui_control == "loot":
#		if chest == null:
#			main_ui_control = "None"
#		else:
#			if $HUD/PanelUI.get_children().size() == 0:
#				var lootpanel = load("res://scenes/UI/LootPanel.tscn").instance()
#				$HUD/PanelUI.add_child(lootpanel)
#				emit_signal("open_chest", chest)
#				lootpanel.connect("close_lootpanel", self, "_close_lootpanel")
#	elif main_ui_control == "None":
#		_close_lootpanel()
#
#func _close_lootpanel():
#	for n in $HUD/PanelUI.get_children():
#		main_ui_control = "None"
#		n.queue_free()

func change_inventory(inter):
#	var pnode = get_node(str(inter.net_id))
#	if (!pnode):
#		# Depending on the synchronization mechanism, this may not be an error!
#		# For now assume the entites are spawned  and kept in sync so just continue
#		# the loop
#		return
	
	var player_name = Network.get_player_name(inter.net_id)
	
	if Gamestate.inventory_info.has(player_name):
		var p_inventory = Gamestate.inventory_info[player_name]
		if inter.slot_0:
			p_inventory.s00 = "s00"
		elif inter.slot_1 && p_inventory.s01 == "s11":
			p_inventory.s00 = "s11"
		elif inter.slot_2 && p_inventory.s02 == "s21":
			p_inventory.s00 = "s21"
			
	if (! inter.net_id == 1):
		Gamestate.encode_inventory_info(player_name, inter.net_id)
	
	#pnode.change_inventory(inter)

#var slots_icon = {
#	s00 = "res://assets/hand_01.png",
#	s10 = "res://assets/knife_01.png",
#	s11 = "res://assets/knife_02.png",
#	s20 = "res://assets/gun_01.png",
#	s21 = "res://assets/gun_02.png"
#}
#var inventory_info = {									# Inventory
#	p0 = {												# Player name
#		s00 = 0,										# Slot by default
#		s01 = 0,										# Slot N1 - knife
#		s02 = 0,										# Slot N2 - gun
#		s03 = 0											# Slot N3 - gold
#	}
#}





























func _on_PanelUI__open_chest(chest):
	pass # Replace with function body.
