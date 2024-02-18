extends Control

var idcard_scene:PackedScene = load("res://scenes/player_info_card.tscn")
var red_theme = load("res://resources/red_card_id.tres")
var red_theme_hover = load("res://resources/red_card_id_hover.tres")
var blue_theme = load("res://resources/blue_card_id.tres")
var blue_theme_hover = load("res://resources/blue_card_id_hover.tres")

var idcards:Dictionary = {}

@onready var main = get_parent()
@onready var red_card_box = $PaperBG/RedBG/PlayersContainer/VBox
@onready var blue_card_box = $PaperBG/BlueBG/PlayersContainer/VBox

# Called when the node enters the scene tree for the first time.
func _ready():
	MultiplayerManager.player_added.connect(player_added)
	MultiplayerManager.connected_to_server.connect(connected_to_server)
	MultiplayerManager.player_removed.connect(player_removed)
	MultiplayerManager.disconnected.connect(disconnected)

func player_added(id):
	add_to_playerlist(id)

func player_removed(id,username):
	idcards[id].queue_free()
	idcards.erase(id)

func connected_to_server():
	#for id in MultiplayerManager.players:
		#add_to_playerlist(id)
	request_teamslist.rpc_id(1)
	$".."/LobbyUI/InfoPanel/HostBox.text = "HOST: "+MultiplayerManager.players[1].name
	print(MultiplayerManager.peer.get_unique_id())
	$".."/LobbyUI/InfoPanel/IPBox.text = "IP: "+MultiplayerManager.connected_ip
	$".."/LobbyUI/InfoPanel/PortBox.text = "PORT: "+str(MultiplayerManager.connected_port)

@rpc("any_peer","reliable")
func request_teamslist():
	set_teamslist.rpc_id(multiplayer.get_remote_sender_id(),main.red_team,main.red_spymas,main.blue_team,main.blue_spymas)

@rpc("authority","reliable")
func set_teamslist(red_team,red_spymas,blue_team,blue_spymas):
	main.red_team = red_team
	main.red_spymas = red_spymas
	main.blue_team = blue_team
	main.blue_spymas = blue_spymas
	check_spymasters()
	regenerate_cards()

@rpc("authority","reliable","call_local")
func switch_team(id):
	var index = main.red_team.find(id)
	if index < 0: #if its not found in red team
		index = main.blue_team.find(id)
		if main.blue_spymas == id:
			main.blue_spymas = null
		main.blue_team.remove_at(index)
		main.red_team.append(id)
		check_spymasters()
	else:
		if main.red_spymas == id:
			main.red_spymas = null
		main.red_team.remove_at(index)
		main.blue_team.append(id)
		check_spymasters()
	regenerate_cards()

@rpc("authority","reliable","call_local")
func make_spymas(id):
	if main.red_spymas == id:
		main.red_spymas = null
		check_spymasters()
		regenerate_cards()
		return
	if main.blue_spymas == id:
		main.blue_spymas = null
		check_spymasters()
		regenerate_cards()
		return
	
	var index = main.red_team.find(id)
	if index < 0: #if its not found in red team
		index = main.blue_team.find(id)
		main.blue_spymas = id
	else:
		main.red_spymas = id
	
	check_spymasters()
	regenerate_cards()

func check_spymasters():
	main.blue_fieldops.clear()
	main.red_fieldops.clear()
	for i in main.blue_team:
		if i != main.blue_spymas:
			main.blue_fieldops.append(i)
	for i in main.red_team:
		if i != main.red_spymas:
			main.red_fieldops.append(i)

func regenerate_cards():
	for card in idcards:
		idcards[card].queue_free()
	idcards.clear()
	for id in main.red_fieldops:
		var card = create_idcard(MultiplayerManager.players[id].name,id,1)
		red_card_box.add_child(card)
	for id in main.blue_fieldops:
		var card = create_idcard(MultiplayerManager.players[id].name,id,2)
		blue_card_box.add_child(card)
	if main.red_spymas:
		var card = create_idcard(MultiplayerManager.players[main.red_spymas].name,main.red_spymas,1)
		card.position = Vector2(15,44)
		$PaperBG/RedBG.add_child(card)
	if main.blue_spymas:
		var card = create_idcard(MultiplayerManager.players[main.blue_spymas].name,main.blue_spymas,2)
		card.position = Vector2(15,44)
		$PaperBG/BlueBG.add_child(card)
	#print("red: " +str(main.red_team))
	#print("blu: " +str(main.blue_team))
	#print("cards: "+str(idcards))

func rpc_switch_team(id):
	switch_team.rpc(id)

func rpc_make_spymas(id):
	make_spymas.rpc(id)

func add_to_playerlist(id:int):
	var username = MultiplayerManager.players[id].name
	#var red = true
	var idcard
	
	if main.red_team.size() > main.blue_team.size():
		main.blue_team.append(id)
		main.blue_fieldops.append(id)
		#red = false
		idcard = create_idcard(username,id,2)
		$PaperBG/BlueBG/PlayersContainer/VBox.add_child(idcard)
	else:
		main.red_team.append(id)
		main.red_fieldops.append(id)
		idcard = create_idcard(username,id,1)
		$PaperBG/RedBG/PlayersContainer/VBox.add_child(idcard)

func create_idcard(username,id,team):
	var idcard:Panel = idcard_scene.instantiate()
	
	idcard.name = str(id)
	idcard.get_node("UsernameText").text = username
	if id == 1:
		idcard.get_node("IDText").text = "#1 (HOST)"
	else:
		idcard.get_node("IDText").text = "#" + str(id)
	
	if MultiplayerManager.peer.get_unique_id() == 1:
		idcard.get_node("SwapTeamButton").visible = true
		idcard.get_node("SwapTeamButton").pressed.connect(rpc_switch_team.bind(id))
		idcard.get_node("MakeMasterButton").visible = true
		idcard.get_node("MakeMasterButton").pressed.connect(rpc_make_spymas.bind(id))
	
	if team == 2:
		set_idcard_blue(idcard)
	idcards[id] = idcard
	return idcard

func set_idcard_blue(idcard):
	idcard.set("theme_override_styles/panel", blue_theme)
	idcard.get_node("SwapTeamButton").set("theme_override_styles/normal",blue_theme)
	idcard.get_node("SwapTeamButton").set("theme_override_styles/hover",blue_theme_hover)
	idcard.get_node("SwapTeamButton").set("theme_override_styles/pressed",blue_theme)
	idcard.get_node("MakeMasterButton").set("theme_override_styles/normal",blue_theme)
	idcard.get_node("MakeMasterButton").set("theme_override_styles/hover",blue_theme_hover)
	idcard.get_node("MakeMasterButton").set("theme_override_styles/pressed",blue_theme)

func disconnected(code):
	self.visible = false
	$".."/GameUI.visible = false
	$".."/ConnectUI.visible = true
	disconnect_with_error("DISCONNECTED: HOST LEFT")
	for i in idcards:
		idcards[i].queue_free()
	idcards.clear()
	$StartButton.visible = false
	$LeaveButton.position = Vector2(852,472)

func disconnect_with_error(error):
	$".."/WarningPanel/WarningText.text = error
	$".."/WarningPanel.visible = true
	if main.ongoing_game:
		main.end_game()

func _on_hosting():
	$".."/LobbyUI/InfoPanel/HostBox.text = "HOST: "+MultiplayerManager.players[1].name
	print(MultiplayerManager.peer.get_unique_id())
	$".."/LobbyUI/InfoPanel/IPBox.text = "IP: "+MultiplayerManager.connected_ip
	$".."/LobbyUI/InfoPanel/PortBox.text = "PORT: "+str(MultiplayerManager.connected_port)
	$StartButton.visible = true
	$LeaveButton.position = Vector2(730,473)


func _on_leave_button_pressed():
	MultiplayerManager.disconnect_network(0)

func _on_start_button_pressed():
	if main.blue_fieldops.size() < 1 or main.red_fieldops.size() < 1:
		$ErrorText.text = "NOT ENOUGH PLAYERS"
		return
	if not main.blue_spymas or not main.red_spymas:
		$ErrorText.text = "MISSING SPYMASTERS"
		return
	
	main.start_game_server()
