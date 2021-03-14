extends Node

var player_info = {
	name = "Player",									#How this player will be shown within the GUI
	net_id = 1,											#By default everyone receives "server ID"
	actor_path = "res://scenes/character/player.tscn",	#The class used to represent the player in the game world
	char_color = Color(1,1,1)							#By default don't modulate the icon color
}

var inventory_info = {									# Inventory
	p0 = {}
}

	
var spawned_bots = 0
var bot_info = {}

var update_rate = 30 setget set_update_rate								# How many game updates per second
var update_delta = 1.0 / update_rate setget no_set, get_update_delta	# And the delta time for the specfied update rate

# The "signature" (timestamp) added into each generated state snashot
var snapshot_signature = 1
# The signature of the last snapshot received
var last_snapshot_info = {}

# Hold player input data (inclding the local one) which will be used to update the game state
# This will be filled only on the server
var player_input = {}

# player interaction
var player_inter = {}

# Cash the variant headers so we can manually decode data sent across the network
var int_header = PoolByteArray(var2bytes(int(0)).subarray(0, 3))
var float_header = PoolByteArray(var2bytes(float(0)).subarray(0, 3))
var vec2_header = PoolByteArray(var2bytes(Vector2()).subarray(0, 3))
var col_header = PoolByteArray(var2bytes(Color()).subarray(0, 3))
var bool_header = PoolByteArray(var2bytes(bool(false)).subarray(0, 6))

# If this is true, then player input will be gathered and procesed. Otherwise "ignore"
var accept_player_input = true

# Navigation system
var navigation
var destinations

# Shooting
var bullet_num = 0

signal snapshot_received(snapshot) # Emit as soon as an snapshot is fully decoded

# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	
	# Initialize the bot list
	#for id in range(1, 16):
	for id in range(1, Network.max_bots + 1):
		bot_info[id] = {name = "Bot_" + str(id), actor_path = "res://scenes/character/bot.tscn"}

remote func client_get_snapshot(encoded):
	if (Network.fake_latency > 0):
		yield(get_tree().create_timer(Network.fake_latency / 1000), "timeout")
		
	var decoded = {
		# Extract the signature
		signature = bytes2var(int_header + encoded.subarray(0, 3)),
		# Initialize  the player data and bot data arrays
		player_data = [],
		bot_data = [],
		bullet_data = []
	}
	
#	# If the received snapshot is older (or even equal) to the last received one, ignore
#	if (decoded.signature <= last_snapshot):
#		return
	
	# Type packet
	var type_packet = bytes2var(int_header + encoded.subarray(4, 7))
	var name_type = "last_snapshot_" + str(type_packet)
	if !last_snapshot_info.has(name_type):
		last_snapshot_info[name_type] = 0
		
	# If the received snapshot is older to the last received one, ignore
	if (decoded.signature <= last_snapshot_info[name_type]):
		return
		
## First add the snapshot signature (timestamp)
#	encoded_playerdata.append_array(encode_4bytes(snapshot_data.signature))
#	# type packet
#	encoded_playerdata.append_array(encode_4bytes(1))
#	# Player data count
#	encoded_playerdata.append_array(encode_4bytes(snapshot_data.player_data.size()))	

	var data_count = bytes2var(int_header + encoded.subarray(8, 11))
	# Control variable to point into the player array (skiping player count)
	var idx = 12
	
	# Extract player data count
	if type_packet == 1:
		# Then the player data itself
		for i in range (data_count):
			# Extract the network ID, integer, 4 bytes
			var eid = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the location, Vector2, 8 bytes
			var eloc = bytes2var(vec2_header + encoded.subarray(idx, idx + 7))
			idx += 8
			# Extract rotation, float, 4 bytes
			var erot = bytes2var(float_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the look turret
			var elook = bytes2var(vec2_header + encoded.subarray(idx, idx + 7))
			idx += 8
			# Extract color, Color, 16 bytes
			var ecol = bytes2var(col_header + encoded.subarray(idx, idx + 15))
			idx += 16
			
			var pd = {
				net_id = eid,
				location = eloc,
				rot = erot,
				look = elook,
				col = ecol
			}
			
			decoded.player_data.append(pd)
		
#	# Extract bot data count
#	var bdata_count = bytes2var(int_header + encoded.subarray(idx, idx + 3))
#	idx += 4
	if type_packet == 2:
		# Then the bot data
		for i in range(data_count):
			# Extract the bot id
			var bid = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the location
			var eloc = bytes2var(vec2_header + encoded.subarray(idx, idx + 7))
			idx += 8
			# Extract rotation
			var erot = bytes2var(float_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the health
			var ehel = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract color
			var ecol = bytes2var(col_header + encoded.subarray(idx, idx + 15))
			idx += 16
	
			var bd = {
				bot_id = bid,
				location = eloc,
				rot = erot,
				health = ehel,
				col = ecol
			}
	
			decoded.bot_data.append(bd)
			
	if type_packet == 3:
		# Extract bullet data count
#		var bull_data_count = bytes2var(int_header + encoded.subarray(idx, idx + 3))
#		idx += 4
		# Then the bot data
		for i in range(data_count):
			# Extract the bullet id
			var bid = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the position
			var eloc = bytes2var(vec2_header + encoded.subarray(idx, idx + 7))
			idx += 8
			# Extract type
			var btype = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
	
			var bd = {
				bullet_id = bid,
				location = eloc,
				bullet_type = btype
			}
	
			decoded.bullet_data.append(bd)
		
	# Update the "last_snapshot"
	#last_snapshot = decoded.signature
	last_snapshot_info[name_type] = decoded.signature
	
	# Emit the signal indicating that there is a new snapshot do be applied
	emit_signal("snapshot_received", decoded)

func set_inventory_def(net_id):
	for p in Network.players:
		if Network.players[p].net_id == net_id:
			var slots_info = {												# Player name
					s00 = "s00",										# Slot by default
					s01 = "s10",										# Slot N1 - knife
					s02 = "s20",										# Slot N2 - gun
					s03 = 10,											# Slot N3 - bullet
					s99 = 0												# Slot N3 - gold
				}
			inventory_info[Network.players[p].name] = slots_info
	
func loot_added(net_id, loot_id, loot_count):
	for p in Network.players:
		if Network.players[p].net_id == net_id:
			var p_inv = inventory_info[Network.players[p].name]
			
			match loot_id:
				"knife_02":
					p_inv.s01 = "s11"
				"coins_00":
					p_inv.s99 += loot_count
				"gun_02":
					p_inv.s02 = "s21"
				"bullets_02":
					p_inv.s03 += loot_count

			#var slots_info = {												# Player name
			#		s00 = "s00",										# Slot by default
			#		s01 = "s10",										# Slot N1 - knife
			#		s02 = "s20",										# Slot N2 - gun
			#		s03 = 0,											# Slot N3 - bullet
			#		s99 = 0												# Slot N3 - gold
			#	}			
	
	if (! net_id == 1):
		encode_inventory_info(Network.get_player_name(net_id), net_id)
	
remote func remote_loot_added(loot_id, loot_count):
	loot_added(get_tree().get_rpc_sender_id(), loot_id, loot_count)
	
func loot_change(loot_id, loot_count):
	if is_network_master():
		loot_added(1, loot_id, loot_count)
	else:
		rpc_id(1, "remote_loot_added", loot_id, loot_count)
	
func set_update_rate(r):
	update_rate = r
	update_delta = 1.0 / update_rate
	
func get_update_delta():
	return update_delta
	
func no_set(r):
	pass

# Encode a variable that uses 4 bytes (integer, float)
func encode_4bytes(val):
	return var2bytes(val).subarray(4, 7)
	
# Encode a variable that uses 8 bytes (vector2)
func encode_8bytes(val):
	return var2bytes(val).subarray(4, 11)
	
# Encode a variable that uses 12 bytes (vector3....)
func encode_12bytes(val):
	return var2bytes(val).subarray(4, 15)
	
# Encode a variable  that uses 16 bytes (quaternion, color....)
func encode_16bytes(val):
	return var2bytes(val).subarray(4, 19)

# Based on the "Height level" snapshot data, encodes into a byte array
# ready to be sent across the network. This function does not return
# the data, just broadcast it to  the connect players. To that end, 
# it is meant to be run only on the server
func encode_snapshot(snapshot_data):
	if (!get_tree().is_network_server()):
		return
		
	var encoded = PoolByteArray()
	
	# PLAYER
	# First add the snapshot signature (timestamp)
	encoded.append_array(encode_4bytes(snapshot_data.signature))
	# type packet 
	encoded.append_array(encode_4bytes(1))
	# Player data count
	encoded.append_array(encode_4bytes(snapshot_data.player_data.size()))
	# snapshot_data should contain a "players" field which must be an array
	# of player data. Each entry in this array should be a dictionary, containig
	# the following fields: network_id, location, rot, col
	for pdata in snapshot_data.player_data:
		# Encode the network_id which should be an integer, 4 bytes
		encoded.append_array(encode_4bytes(pdata.net_id))
		# Encode the location which should be a Vector2, 8 bytes
		encoded.append_array(encode_8bytes(pdata.location))
		# Encode the rotation which should be a float, 4 bytes
		encoded.append_array(encode_4bytes(pdata.rot))
		# Encode the look turret
		encoded.append_array(encode_8bytes(pdata.look))
		# Encode the color which should be a Color, 16 bytes
		encoded.append_array(encode_16bytes(pdata.col))
		
	rpc_unreliable("client_get_snapshot", encoded)
	
	# BOT
	encoded = PoolByteArray()
	# First add the snapshot signature (timestamp)
	encoded.append_array(encode_4bytes(snapshot_data.signature))
	# type packet 
	encoded.append_array(encode_4bytes(2))
	# Bot data count
	encoded.append_array(encode_4bytes(snapshot_data.bot_data.size()))
	# The bot_data field should be an array, each entry containgthe following
	# fields: bot_id, location, rot, col
	for bdata in snapshot_data.bot_data:
		# Encode the bot_id which should be an integer, 4 bytes
		encoded.append_array(encode_4bytes(bdata.bot_id))
		# Encode the location, which should be a Vector2,  8 bytes
		encoded.append_array(encode_8bytes(bdata.location))
		# Encoded the rotation, which should a floa, 4 bytes
		encoded.append_array(encode_4bytes(bdata.rot))
		# Encoded the health. integer. 4 bytes
		encoded.append_array(encode_4bytes(bdata.health))
		# Encoded the color which should be a Color, 16 bytes
		encoded.append_array(encode_16bytes(bdata.col))
		
		#print(bdata.bot_id)
		
	rpc_unreliable("client_get_snapshot", encoded)
	
	# test
#	var decoded = decoded_main_snapshot(encoded)
#	pass
	
	# BULLETS
	if snapshot_data.bullet_data.size() > 0:
		encoded = PoolByteArray()
		# First add the snapshot signature (timestamp)
		encoded.append_array(encode_4bytes(snapshot_data.signature))
		# type packet 
		encoded.append_array(encode_4bytes(3))
		# Bullet data count
		encoded.append_array(encode_4bytes(snapshot_data.bullet_data.size()))
		for bdata in snapshot_data.bullet_data:
			encoded.append_array(encode_4bytes(bdata.bull_id))
			encoded.append_array(encode_8bytes(bdata.bull_pos))
			encoded.append_array(encode_4bytes(bdata.bull_type))
		rpc_unreliable("client_get_snapshot", encoded)
#
#	# test
#	var decoded = decoded_main_snapshot(encoded, snapshot_data)
#	pass

func encode_inventory_info(player_name, net_id):
	rpc_id(net_id, "update_local_inventory_info", Gamestate.inventory_info[player_name])

remote func update_local_inventory_info(local_inventory_info):
	Gamestate.inventory_info[Gamestate.player_info.name] = local_inventory_info

func decoded_main_snapshot(encoded):
	var decoded = {
		# Extract the signature
		signature = bytes2var(int_header + encoded.subarray(0, 3)),
		# Initialize  the player data and bot data arrays
		player_data = [],
		bot_data = [],
		bullet_data = []
	}
	
#	# If the received snapshot is older (or even equal) to the last received one, ignore
#	if (decoded.signature <= last_snapshot):
#		return
	
	# Type packet
	var type_packet = bytes2var(int_header + encoded.subarray(4, 7))
	var name_type = "last_snapshot_" + str(type_packet)
	if !last_snapshot_info.has(name_type):
		last_snapshot_info[name_type] = 0
		
	# If the received snapshot is older to the last received one, ignore
	if (decoded.signature <= last_snapshot_info[name_type]):
		return
		
## First add the snapshot signature (timestamp)
#	encoded_playerdata.append_array(encode_4bytes(snapshot_data.signature))
#	# type packet
#	encoded_playerdata.append_array(encode_4bytes(1))
#	# Player data count
#	encoded_playerdata.append_array(encode_4bytes(snapshot_data.player_data.size()))	

	var data_count = bytes2var(int_header + encoded.subarray(8, 11))
	# Control variable to point into the player array (skiping player count)
	var idx = 12
	
	# Extract player data count
	if type_packet == 1:
		# Then the player data itself
		for i in range (data_count):
			# Extract the network ID, integer, 4 bytes
			var eid = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the location, Vector2, 8 bytes
			var eloc = bytes2var(vec2_header + encoded.subarray(idx, idx + 7))
			idx += 8
			# Extract rotation, float, 4 bytes
			var erot = bytes2var(float_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the look turret
			var elook = bytes2var(vec2_header + encoded.subarray(idx, idx + 7))
			idx += 8
			# Extract color, Color, 16 bytes
			var ecol = bytes2var(col_header + encoded.subarray(idx, idx + 15))
			idx += 16
			
			var pd = {
				net_id = eid,
				location = eloc,
				rot = erot,
				look = elook,
				col = ecol
			}
			
			decoded.player_data.append(pd)
		
#	# Extract bot data count
#	var bdata_count = bytes2var(int_header + encoded.subarray(idx, idx + 3))
#	idx += 4
	if type_packet == 2:
		# Then the bot data
		for i in range(data_count):
			# Extract the bot id
			var bid = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the location
			var eloc = bytes2var(vec2_header + encoded.subarray(idx, idx + 7))
			idx += 8
			# Extract rotation
			var erot = bytes2var(float_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the health
			var ehel = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract color
			var ecol = bytes2var(col_header + encoded.subarray(idx, idx + 15))
			idx += 16
	
			var bd = {
				bot_id = bid,
				location = eloc,
				rot = erot,
				health = ehel,
				col = ecol
			}
	
			decoded.bot_data.append(bd)
			
	if type_packet == 3:
		# Extract bullet data count
#		var bull_data_count = bytes2var(int_header + encoded.subarray(idx, idx + 3))
#		idx += 4
		# Then the bot data
		for i in range(data_count):
			# Extract the bullet id
			var bid = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
			# Extract the position
			var eloc = bytes2var(vec2_header + encoded.subarray(idx, idx + 7))
			idx += 8
			# Extract type
			var btype = bytes2var(int_header + encoded.subarray(idx, idx + 3))
			idx += 4
	
			var bd = {
				bullet_id = bid,
				location = eloc,
				bullet_type = btype
			}
	
			decoded.bullet_data.append(bd)
				
	return decoded

func cache_input(p_id, data):
	if (!get_tree().is_network_server()):
		return
		
	if (!player_input.has(p_id)):
		player_input[p_id] = []
		
	player_input[p_id].append(data)

func cache_inter(p_id, data):
	if (!get_tree().is_network_server()):
		return
		
	if (!player_inter.has(p_id)):
		player_inter[p_id] = []
		
	player_inter[p_id].append(data)




































