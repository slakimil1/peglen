extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready():
	Network.connect("server_created", self, "_on_ready_to_play")
	Network.connect("join_success", self, "_on_ready_to_play")
	Network.connect("join_fail", self, "_on_join_fail")
	get_tree().paused = false

func _on_btCreate_pressed():
	set_player_info(true)
	#Gather values from the GUI and fill the network.server_info dictionary
	if (!$PanelHost/txtServerName.text.empty()):
		Network.server_info.name = $PanelHost/txtServerName.text
	Network.server_info.max_players = int($PanelHost/txtMaxPlayers.value)
	Network.server_info.used_port = int($PanelHost/txtServerPort.text)
	
	#And create the server, using the function previously added into the code
	Network.create_server()
	
func _on_btJoin_pressed():
	set_player_info(false)
	
	var port = int($PanelJoin/txtJoinPort.text)
	var ip = $PanelJoin/txtJoinIP.text
	
	Network.join_server(ip, port)

func _on_ready_to_play():
	get_tree().change_scene("res://scenes/gameworld.tscn")
	
func _on_join_fail():
	print("Failed to join server")	
	
func set_player_info(is_serever):
	if (! is_serever && $PanelPlayer/txtPlayerName.text.empty()):
		Gamestate.player_info.name = "Player02" 
	elif(! $PanelPlayer/txtPlayerName.text.empty()):
		Gamestate.player_info.name = $PanelPlayer/txtPlayerName.text
		
	Gamestate.player_info.char_color = $PanelPlayer/btColor.color

func _on_btDefaultColor_pressed():
	$PanelPlayer/PlayerIcon.modulate = Color(1,1,1)
	$PanelPlayer/btColor.color = Color(1,1,1)

func _on_btColor_color_changed(color):
	$PanelPlayer/PlayerIcon.modulate = color




