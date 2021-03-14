extends MenuButton

# Popup menu entry IDs
enum PopID {whisper = 1, kick, ban}

# Network ID of the player associated with this object
var net_id = 0

signal whisper_clicked(msg_prefix)		# Given when the whisper option in the pop menu is clicked

# Called when the node enters the scene tree for the first time.
func _ready():
	var pop = get_popup() # Just a shortcut
	pop.add_item("Whisoer", PopID.whisper)
	if (get_tree().is_network_server()):
		pop.add_separator()
		pop.add_item("Kick", PopID.kick)
		pop.add_item("Ban", PopID.ban)
		
	pop.connect("id_pressed", self, "_on_popup_id_pressed")

func set_info(pname, pcolor):
	$PlayerRow/lbName.text = pname
	$PlayerRow/Icon.modulate = pcolor

func set_latency(v):
	$PlayerRow/lbLatency.text = "(" + str(int(v)) + ")"

func _on_popup_id_pressed(id):
	match id:
		PopID.whisper:
			emit_signal("whisper_clicked", "@" + Network.players[net_id].name + " ")
			
		PopID.kick:
			$pnKickBan/btKickBan.text = "Kick"
			$pnKickBan.show()
			$pnKickBan/txtReason.grab_focus()
			
		PopID.ban:
			$pnKickBan/btKickBan.text = "Ban"
			$pnKickBan.show()
			$pnKickBan/txtReason.grab_focus()

func _on_btCancel_pressed():
	$pnKickBan.hide()

func _on_btKickBan_pressed():
	var reason = $pnKickBan/txtReason.text
	if (reason.empty()):
		reason = "No reason"
	if ($pnKickBan/btKickBan.text == "Kick"):
		print("Kicking player with nique ID", net_id)
		Network.kick_player(net_id, reason)
	else:
		print("Banning not implemented yet")
		
	$pnKickBan.hide()
	







