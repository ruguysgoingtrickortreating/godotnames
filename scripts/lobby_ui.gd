extends Control

var idcard_scene:PackedScene = load("res://scenes/player_info_card.tscn")
var red_theme = load("res://resources/red_card_id.tres")
var red_theme_hover = load("res://resources/red_card_id_hover.tres")
var blue_theme = load("res://resources/blue_card_id.tres")
var blue_theme_hover = load("res://resources/blue_card_id_hover.tres")

var idcards:Dictionary = {}

@onready var main:MainNodeClass = get_parent()
@onready var red_card_box = $PaperBG/RedBG/PlayersContainer/VBox
@onready var blue_card_box = $PaperBG/BlueBG/PlayersContainer/VBox

# Called when the node enters the scene tree for the first time.
func _ready():
	print("open error: ",FileAccess.get_open_error())
	MultiplayerManager.player_added.connect(player_added)
	MultiplayerManager.connected_to_server.connect(connected_to_server)
	MultiplayerManager.player_removed.connect(player_removed)
	MultiplayerManager.disconnected.connect(disconnected)
	MultiplayerManager.server_disconnected.connect(host_disconnected)

func player_added(id):
	add_to_playerlist(id)

func player_removed(id,username):
	idcards[id].queue_free()
	idcards.erase(id)

@rpc("any_peer","reliable")
func request_teamslist():
	set_teamslist.rpc_id(multiplayer.get_remote_sender_id(),main.red_team,main.red_spymas,main.blue_team,main.blue_spymas)

@rpc("authority","reliable")
func set_teamslist(red_team,red_spymas,blue_team,blue_spymas):
	main.red_team = red_team
	main.red_spymas = red_spymas
	main.blue_team = blue_team
	main.blue_spymas = blue_spymas
	refresh_fieldops_array()
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
		refresh_fieldops_array()
	else:
		if main.red_spymas == id:
			main.red_spymas = null
		main.red_team.remove_at(index)
		main.blue_team.append(id)
		refresh_fieldops_array()
	regenerate_cards()

@rpc("authority","reliable","call_local")
func make_spymas(id):
	if main.red_spymas == id:
		main.red_spymas = null
		refresh_fieldops_array()
		regenerate_cards()
		return
	if main.blue_spymas == id:
		main.blue_spymas = null
		refresh_fieldops_array()
		regenerate_cards()
		return
	
	var index = main.red_team.find(id)
	if index < 0: #if its not found in red team
		index = main.blue_team.find(id)
		main.blue_spymas = id
	else:
		main.red_spymas = id
	
	refresh_fieldops_array()
	regenerate_cards()

func refresh_fieldops_array():
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
	$".."/ConnectUI.visible = true
	for i in idcards:
		idcards[i].queue_free()
	idcards.clear()
	if main.ongoing_game:
		print(main.ongoing_game)
		main.end_game()
	$StartButton.visible = false
	$GameSettingsPanel/RandomizeTeamsButton.visible = false
	$LeaveButton.position = Vector2(852,472)
	$GameSettingsPanel/InputBlockPanel.visible = true

func host_disconnected():
	create_error("DISCONNECTED: HOST LEFT")

func create_error(error):
	$".."/DrawOnTop/WarningPanel/WarningText.text = error
	$".."/DrawOnTop/WarningPanel.visible = true

func _on_hosting():
	$".."/LobbyUI/InfoPanel/HostBox.text = "HOST: "+MultiplayerManager.players[1].name
	$".."/LobbyUI/InfoPanel/IPBox.text = "IP: "+MultiplayerManager.connected_ip
	$".."/LobbyUI/InfoPanel/PortBox.text = "PORT: "+str(MultiplayerManager.connected_port)
	$StartButton.visible = true
	$LeaveButton.position = Vector2(730,473)
	$GameSettingsPanel/InputBlockPanel.visible = false
	$GameSettingsPanel/RandomizeTeamsButton.visible = true

func connected_to_server():
	#for id in MultiplayerManager.players:
		#add_to_playerlist(id)
	request_teamslist.rpc_id(1)
	update_timer_state(MultiplayerManager.settings["timer_enabled"])
	set_timer_time(str(MultiplayerManager.settings["time"]))
	$InfoPanel/HostBox.text = "HOST: "+MultiplayerManager.players[1].name
	$InfoPanel/IPBox.text = "IP: "+MultiplayerManager.connected_ip
	$InfoPanel/PortBox.text = "PORT: "+str(MultiplayerManager.connected_port)

func _on_leave_button_pressed():
	MultiplayerManager.disconnect_network(0)

func _on_start_button_pressed():
	print("start pressed")
	if main.blue_fieldops.size() < 1 or main.red_fieldops.size() < 1:
		$ErrorText.text = "NOT ENOUGH PLAYERS"
		return
	if not main.blue_spymas or not main.red_spymas:
		$ErrorText.text = "MISSING SPYMASTERS"
		return
	
	$ErrorText.text = ""
	main.start_game_server()

var checked_sprite = load("res://images/checkbox_checked.svg")
var unchecked_sprite = load("res://images/checkbox_unchecked.svg")

func _on_timer_checkbox_pressed():
	if $GameSettingsPanel/TimerCheckbox.button_pressed:
		update_timer_state.rpc(true)
	else:
		update_timer_state.rpc(false)

@rpc("authority","reliable","call_local")
func update_timer_state(state:bool):
	if state:
		$GameSettingsPanel/TimerCheckbox.icon = checked_sprite
		MultiplayerManager.settings["timer_enabled"] = true
	else:
		$GameSettingsPanel/TimerCheckbox.icon = unchecked_sprite
		MultiplayerManager.settings["timer_enabled"] = false

func _on_time_box_text_changed(new_text):
	if new_text == "":
		set_timer_time.rpc("")
	else:
		var old_caret_position = $GameSettingsPanel/TimeBox.caret_column
		var validated_text = main.validate_regex(new_text,"[0-9]")
		set_timer_time.rpc(validated_text)
		$GameSettingsPanel/TimeBox.caret_column = old_caret_position

@rpc("authority","reliable","call_local")
func set_timer_time(new_time:String):
	MultiplayerManager.settings["time"] = int(new_time)
	$GameSettingsPanel/TimeBox.text = str(new_time)


func _on_ip_box_pressed():
	DisplayServer.clipboard_set(MultiplayerManager.connected_ip)

@rpc("authority","reliable")
func server_request_clients_to_request_game_info(): # i love descriptive naming
	request_teamslist.rpc_id(1)

func _on_randomize_teams_button_pressed():
	randomize() # this resets the global randomization seed
	main.red_spymas = null
	main.blue_spymas = null
	main.red_team.clear()
	main.blue_team.clear()
	
	var players = MultiplayerManager.players.duplicate()
	var player_keys_random = players.keys()
	player_keys_random.shuffle()
	var red_slots = players.size()/2
	var blue_slots = players.size()/2
	if players.size()%2:		# randomly add an extra slot when uneven players (otherwise a player will go unaccounted for)
		if randi_range(0,1):
			red_slots += 1
		else:
			blue_slots += 1
	
	for id in player_keys_random:
		if (randi_range(0,1) or blue_slots == 0) and not red_slots == 0:
			if not main.red_spymas:
				main.red_spymas = id
			main.red_team.append(id)
			red_slots -= 1
		else:
			if not main.blue_spymas:
				main.blue_spymas = id
			main.blue_team.append(id)
			blue_slots -= 1
	refresh_fieldops_array()
	regenerate_cards()
	server_request_clients_to_request_game_info.rpc()
	print(main.blue_spymas)
	print(main.red_spymas)
	print(main.blue_spymas,main.red_spymas,main.blue_team,main.red_team)
