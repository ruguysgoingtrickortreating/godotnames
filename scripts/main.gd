extends Control

var card_teams = [[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0]] #5x5 2d matrix
var card_names = [["","","","",""],["","","","",""],["","","","",""],["","","","",""],["","","","",""]]
var card_instances = [[null,null,null,null,null],[null,null,null,null,null],[null,null,null,null,null],[null,null,null,null,null],[null,null,null,null,null]]
var names_file
var names_list
var card_scene:PackedScene = load("res://card.tscn")

var default_theme = load("res://resources/word_card_default.tres")
var red_theme = load("res://resources/word_card_red.tres")
var blue_theme = load("res://resources/word_card_blue.tres")
var civillian_theme = load("res://resources/word_card_civillian.tres")
var assassin_theme = load("res://resources/word_card_assassin.tres")
var red_theme_unsolved = load("res://resources/word_card_red_unsolved.tres")
var blue_theme_unsolved = load("res://resources/word_card_blue_unsolved.tres")
var assassin_theme_unsolved = load("res://resources/word_card_assassin_unsolved.tres")

var red_team = []
var blue_team = []
var red_fieldops = []
var blue_fieldops = []
var red_spymas
var blue_spymas

var red_total = 8
var red_found = 0
var blue_total = 8
var blue_found = 0

var red_turn = true
var self_red
var ongoing_game
var win_screen

func _init():
	if OS.has_feature("standalone"):
		var path = OS.get_executable_path().get_base_dir().path_join("wordlist.txt")
		names_file = FileAccess.open("res://wordlist.txt", FileAccess.READ)
	else:
		names_file = FileAccess.open("res://wordlist.txt", FileAccess.READ)
	names_list = names_file.get_as_text().split("\n",false) # \n means newline character

func card_pressed(index):
	check_card.rpc(index)

@rpc("any_peer","reliable","call_local")
func check_card(index:int):
	var red
	var card:Button = card_instances[index/5][index%5]
	var cardteam:int = card_teams[index/5][index%5]
	var cardtext:String = card_names[index/5][index%5]
	if red_team.find(multiplayer.get_remote_sender_id()) == -1:
		red = false
		flash_picked_card_msg(Color(0.4,0.5,1,0),MultiplayerManager.players[multiplayer.get_remote_sender_id()].name + " PICKED \""+cardtext+"\"")
	else:
		red = true
		flash_picked_card_msg(Color(1,0.5,0.5,0),MultiplayerManager.players[multiplayer.get_remote_sender_id()].name + " PICKED \""+cardtext+"\"")
	card.disabled = true
	match cardteam:
		0:
			card.set("theme_override_styles/disabled",civillian_theme)
			if MultiplayerManager.peer.get_unique_id() == 1:
				if red:
					advance_to_blue_turn.rpc()
					if self_red:
						$AnswerAudioWrong.play()
				else:
					advance_to_red_turn.rpc()
					if not self_red:
						$AnswerAudioWrong.play()
		1:
			red_found += 1
			card.set("theme_override_styles/disabled",red_theme)
			card.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
			if not red:
				if MultiplayerManager.peer.get_unique_id() == 1:
					advance_to_red_turn.rpc()
				if not self_red:
					$AnswerAudioWrong.play()
			elif self_red:
				$AnswerAudioRight.play()
			#card_node.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
		2:
			blue_found += 1
			card.set("theme_override_styles/disabled",blue_theme)
			card.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
			if red:
				if MultiplayerManager.peer.get_unique_id() == 1:
					advance_to_blue_turn.rpc()
				if self_red:
					$AnswerAudioWrong.play()
			elif not self_red:
				$AnswerAudioRight.play()
			#card_node.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
		3:
			card.set("theme_override_styles/disabled",assassin_theme)
			card.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
			$AnswerAudioAssassin.play()
			if red:
				win_game.rpc(false,"RED FOUND THE ASSASSIN")
			else:
				win_game.rpc(true,"BLUE FOUND THE ASSASSIN")
	if MultiplayerManager.peer.get_unique_id() == 1:
		if red_found == red_total:
			win_game.rpc(true,"RED FOUND ALL CARDS")
		if blue_found == blue_total:
			win_game.rpc(false,"BLUE FOUND ALL CARDS")

@rpc("authority","reliable","call_local")
func advance_to_red_turn():
	print("advancing red")
	red_turn = true
	$GameUI/TurnLabel.text = "RED'S TURN"
	$GameUI/TurnLabel.add_theme_color_override("font_color",Color(1,0.5,0.5,1))
	$GameUI/NextTurnButton.visible = false
	if self_red:
		$GameUI/InputBlockPanel.visible = false
		$TurnAudio.play()
	else:
		$GameUI/InputBlockPanel.visible = true
	if MultiplayerManager.peer.get_unique_id() == red_spymas:
		$GameUI/NextTurnButton.visible = true

@rpc("authority","reliable","call_local")
func advance_to_blue_turn():
	print("advancing blue")
	red_turn = false
	$GameUI/TurnLabel.text = "BLUE'S TURN"
	$GameUI/TurnLabel.add_theme_color_override("font_color",Color(0.4,0.5,1,1))
	$GameUI/NextTurnButton.visible = false
	if self_red:
		$GameUI/InputBlockPanel.visible = true
	else:
		$TurnAudio.play()
		$GameUI/InputBlockPanel.visible = false
	if MultiplayerManager.peer.get_unique_id() == blue_spymas:
		$GameUI/NextTurnButton.visible = true

func _ready():
	MultiplayerManager.disconnected.connect(disconnected)
	MultiplayerManager.player_removed.connect(player_removed)
	$HTTPRequest.request_completed.connect(_on_request_completed)
	$HTTPRequest.request("http://api.ipify.org")
	var error = FileAccess.get_open_error()
	if error == 7:
		$WarningPanel/WarningText.text = "NO WORDLIST FOUND. GAME WILL NOT WORK."
		$WarningPanel.visible = true

func flash_picked_card_msg(color,text):
	var tween = get_tree().create_tween()
	$GameUI/PickedCardLabel.text = text
	$GameUI/PickedCardLabel.modulate = Color(color.r,color.g,color.b,1)
	tween.tween_property($GameUI/PickedCardLabel,"modulate",color,3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

func _on_request_completed(result, response_code, headers, body):
	update_ip(body.get_string_from_utf8())

func update_ip(ip):
	if not ip:
		MultiplayerManager.local_ip = ""
		$ConnectUI/IpCopyButton.text = "IP: COULD NOT DETERMINE"
	MultiplayerManager.local_ip = str(ip)
	$ConnectUI/IpCopyButton.text = "IP: "+str(ip)

func disconnected(code):
	red_team.clear()
	blue_team.clear()
	red_spymas = null
	blue_spymas = null

func player_removed(id,username):
	print("removed: "+str(id))
	red_team.remove_at(red_team.find(id))
	blue_team.remove_at(blue_team.find(id))
	red_fieldops.remove_at(red_fieldops.find(id))
	blue_fieldops.remove_at(blue_fieldops.find(id))
	if red_spymas == id:
		red_spymas = null
		if ongoing_game:
			early_end_throw_error("GAME ENDED: SPYMASTER LEFT")
	if blue_spymas == id:
		blue_spymas = null
		if ongoing_game:
			early_end_throw_error("GAME ENDED: SPYMASTER LEFT")
	if red_fieldops.size() == 0:
		if ongoing_game:
			early_end_throw_error("GAME ENDED: TOO FEW PLAYERS")
	if blue_fieldops.size() == 0:
		if ongoing_game:
			early_end_throw_error("GAME ENDED: TOO FEW PLAYERS")

@rpc("authority","reliable")
func send_card_data(teams,names,totalred,totalblue):
	print("sending card data...")
	print(teams," ",names," ",totalred," ",totalblue)
	print(card_teams," ",card_names," ",red_total," ",blue_total)
	card_teams = teams
	card_names = names
	red_total = totalred
	blue_total = totalblue
	start_game_client()

func start_game_client():
	setup_game()
	setup_cards()

func start_game_server():
	print("setting up game as server")
	setup_game()
	generate_card_data()

func setup_game():
	print("setting up...")
	ongoing_game = true
	$LobbyUI.visible = false
	$GameUI.visible = true
	if red_team.find(MultiplayerManager.peer.get_unique_id()) == -1:
		self_red = false
		$GameUI/InfoPanel.set("theme_override_styles/panel",blue_theme_unsolved)
		
		$GameUI/InfoPanel/Label.text = "BLUE TEAM\n\nSPYMASTER:\n\n"\
		+MultiplayerManager.players[blue_spymas].name+ (" (YOU)" if blue_spymas == MultiplayerManager.peer.get_unique_id() else "")\
		+"\n\nFIELD OPS:\n"
		
		for id in blue_fieldops:
			$GameUI/InfoPanel/Label.text = $GameUI/InfoPanel/Label.text + "\n" + MultiplayerManager.players[id].name + (" (YOU)" if id == MultiplayerManager.peer.get_unique_id() else "")
	else:
		self_red = true
		$GameUI/InfoPanel.set("theme_override_styles/panel",red_theme_unsolved)
		
		$GameUI/InfoPanel/Label.text = "RED TEAM\n\nSPYMASTER:\n\n"\
		+MultiplayerManager.players[red_spymas].name+ (" (YOU)" if red_spymas == MultiplayerManager.peer.get_unique_id() else "")\
		+"\n\nFIELD OPS:\n"
		
		for id in red_fieldops:
			$GameUI/InfoPanel/Label.text = $GameUI/InfoPanel/Label.text + "\n" + MultiplayerManager.players[id].name + (" (YOU)" if id == MultiplayerManager.peer.get_unique_id() else "")
	print("setup successful")

func generate_card_data():
	
	var current_names = names_list
	var red_first_turn = randi_range(0,1) == 0 #remember that comparison statements either return true or false
	
	for i in 5:
		for v in 5:
			var name_index = randi_range(0,current_names.size()-1)
			card_names[i][v] = current_names[name_index]
			current_names.remove_at(name_index)
	
	for i in 8: # 0:Civillian, 1:Red, 2:Blue, 3:Assassin
		set_team(1)
		set_team(2)
	set_team(1 if red_first_turn else 2)
	
	set_team(3)
	
	
	red_total = 8
	blue_total = 8
	
	
	if red_first_turn:
		red_total += 1
		print("trying to send carddata red")
		send_card_data.rpc(card_teams,card_names,red_total,blue_total)
		advance_to_red_turn.rpc()
	else:
		blue_total += 1
		print("trying to send carddata blue")
		send_card_data.rpc(card_teams,card_names,red_total,blue_total)
		advance_to_blue_turn.rpc()
	
	setup_cards()

func setup_cards():
	for i in range(5):
		for v in range(5):
			var card_node:Button = card_scene.instantiate()
			card_node.name = str(i*5+v)
			card_node.position = Vector2(v*145,i*90)
			card_node.text = card_names[i][v]
			card_node.rotation_degrees = randf_range(-2,2)
			if MultiplayerManager.peer.get_unique_id() == red_spymas or MultiplayerManager.peer.get_unique_id() == blue_spymas:
				card_node.disabled = true
				match card_teams[i][v]:
					0:
						card_node.set("theme_override_styles/disabled",default_theme)
					1:
						card_node.set("theme_override_styles/disabled",red_theme_unsolved)
						#card_node.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
					2:
						card_node.set("theme_override_styles/disabled",blue_theme_unsolved)
						#card_node.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
					3:
						card_node.set("theme_override_styles/disabled",assassin_theme_unsolved)
						card_node.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
			else:
				card_node.pressed.connect(card_pressed.bind(i*5+v))
			
			card_instances[i][v] = card_node
			$GameUI/Cards.add_child(card_node)

@rpc("authority","reliable","call_local")
func end_game():
	for i in 5:
		for v in 5:
			card_instances[i][v].queue_free()
			card_instances[i][v] = null
			card_teams[i][v] = 0
			card_names[i][v] = ""
	red_found = 0
	blue_found = 0
	
	ongoing_game = false
	win_screen = false
	$GameUI.visible = false
	$LobbyUI.visible = true
	$GameUI/WinReasonLabel.visible = false
	$GameUI/NextTurnButton.text = "NEXT TURN "

@rpc("authority","reliable","call_local")
func win_game(red,msg):
	$GameUI/InputBlockPanel.visible = true
	$GameUI/WinReasonLabel.visible = true
	win_screen = true
	if red:
		$GameUI/TurnLabel.text = "RED WINS"
		$GameUI/TurnLabel.add_theme_color_override("font_color",Color(1,0.5,0.5,1))
		$GameUI/WinReasonLabel.text = msg
	else:
		$GameUI/TurnLabel.text = "BLUE WINS"
		$GameUI/TurnLabel.add_theme_color_override("font_color",Color(0.4,0.5,1,1))
		$GameUI/WinReasonLabel.text = msg
	if MultiplayerManager.peer.get_unique_id() == 1:
		$GameUI/NextTurnButton.visible = true
		$GameUI/NextTurnButton.text = "NEXT GAME "
	else:
		$GameUI/NextTurnButton.visible = false

func early_end_throw_error(error:String):
	end_game()
	$WarningPanel/WarningText.text = error
	$WarningPanel.visible = true

func set_team(team:int):
	while true:
		var card_index = randi_range(1,24)
		if card_teams[card_index/5][card_index%5] == 0:
			card_teams[card_index/5][card_index%5] = team
			break

func _on_ip_copy_button_pressed():
	if not MultiplayerManager.local_ip:
		return
	DisplayServer.clipboard_set(MultiplayerManager.local_ip)

func _on_next_turn_button_pressed():
	if win_screen:
		end_game.rpc()
	if MultiplayerManager.peer.get_unique_id() == 1:
		if red_spymas == 1:
			advance_to_blue_turn.rpc()
		if blue_spymas == 1:
			advance_to_red_turn.rpc()
	else:
		check_next_turn_button.rpc_id(1)
@rpc("any_peer","reliable")
func check_next_turn_button():
	var id = multiplayer.get_remote_sender_id()
	if id == red_spymas:
		advance_to_blue_turn.rpc()
	if id == blue_spymas:
		advance_to_red_turn.rpc()
