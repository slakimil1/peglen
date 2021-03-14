extends Control

export(int) var max_chat_lines = 50

func _ready():
	Network.connect("chat_message_received", self, "add_chat_line")

func add_chat_line(msg):
	if ($pnlChat/ChatLines.get_child_count() >= max_chat_lines):
		$pnlChat/ChatLines.get_child(0).queue_free()
		
	var chatline = Label.new()
	chatline.autowrap = true
	chatline.text = msg
	$pnlChat/ChatLines.add_child(chatline)

func _on_txtChatInput_text_entered(new_text):
	# Cleanup the text
	var m = new_text.strip_edges()
	# Local chat box without any formatting
	add_chat_line(m)
	
	# Check if whisper or broadcast
	if (m.begins_with("@")):
		var t = m.split(" ", true, 1)
		# It must be checked that we actually have a message after the name. For simplicity sake
		# ignoring this check for the tutorial
		var player_name = t[0].trim_prefix("@")
		var dest_id = Network.get_player_id(player_name)
		
		if (dest_id == 0):
			# Unable to locate the destination player for whispering
			add_chat_line("ERROR: Cannot locate player " + player_name)
		else:
			# Player found. Remote call directly to that player
			Network.rpc_id(dest_id, "send_message", get_tree().get_network_unique_id(), t[1], false)
			
	else:
		# Send cleaned message for brodcast
		if (get_tree().is_network_server()):
			Network.send_message(1, m, true)
		else:
			Network.rpc_id(1, "send_message", get_tree().get_network_unique_id(), m, true)
			
	# Cleanup the input box so new messages can be entered without having to delete the previous one
	$txtChatInput.text = ""

func _on_btShowChat_pressed():
	if ($pnlChat.is_visible_in_tree()):
		$btShowChat.hide()
		$btShowChat.release_focus()
	else:
		$pnlChat.show()
		$txtChatInput.grab_focus()
	
func _on_whisper(msg_prefix):
	$txtChatInput.text = msg_prefix
	$txtChatInput.grab_focus()
	$txtChatInput.caret_position = msg_prefix.length()
	
func _on_txtChatInput_focus_entered():
	# Disable player input
	Gamestate.accept_player_input = false
	# And show the chat box
	$pnlChat.show()
	
func _on_txtChatInput_focus_exited():
	# Re-enable player input
	Gamestate.accept_player_input = true
