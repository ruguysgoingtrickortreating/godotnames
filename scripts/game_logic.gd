extends Control

@onready var main:MainNodeClass = get_parent() #mainnodeclass is for autofill, see main.gd
var card_scene:PackedScene = load("res://scenes/card.tscn")

var card_teams
var card_names
var card_instances

var default_theme = load("res://resources/word_card_default.tres")
var red_theme = load("res://resources/word_card_red.tres")
var blue_theme = load("res://resources/word_card_blue.tres")
var civillian_theme = load("res://resources/word_card_civillian.tres")
var assassin_theme = load("res://resources/word_card_assassin.tres")
var red_theme_unsolved = load("res://resources/word_card_red_unsolved.tres")
var blue_theme_unsolved = load("res://resources/word_card_blue_unsolved.tres")
var assassin_theme_unsolved = load("res://resources/word_card_assassin_unsolved.tres")

var red_total = 8
var red_found = 0
var blue_total = 8
var blue_found = 0

var red_turn = true
var time
var self_red 
var win_screen


#### TEAM FUNCTIONS

@rpc("authority","reliable","call_local")
func advance_to_red_turn():
	print("advancing red")
	red_turn = true
	$TurnLabel.text = "RED'S TURN"
	$TurnLabel.add_theme_color_override("font_color",Color(1,0.5,0.5,1))
	$NextTurnButton.visible = false
	if time:
		$Timer.start(time)
	if self_red:
		$InputBlockPanel.visible = false
		$Audio/TurnAudio.play()
		if MultiplayerManager.peer.get_unique_id() == main.red_spymas:
			$NextTurnButton.visible = true
	else:
		$InputBlockPanel.visible = true

@rpc("authority","reliable","call_local")
func advance_to_blue_turn():
	print("advancing blue")
	red_turn = false
	$TurnLabel.text = "BLUE'S TURN"
	$TurnLabel.add_theme_color_override("font_color",Color(0.4,0.5,1,1))
	$NextTurnButton.visible = false
	if time:
		$Timer.start(time)
	if not self_red:
		$InputBlockPanel.visible = false
		$Audio/TurnAudio.play()
		if MultiplayerManager.peer.get_unique_id() == main.blue_spymas:
			$NextTurnButton.visible = true
	else:
		$InputBlockPanel.visible = true

func _on_next_turn_button_pressed():
	if win_screen:
		main.end_game.rpc()
	if MultiplayerManager.peer.get_unique_id() == 1:	# bandaid solution to fix trying to rpc when you are host
		if main.red_spymas == 1:
			advance_to_blue_turn.rpc()
		if main.blue_spymas == 1:
			advance_to_red_turn.rpc()
	else: 
		check_next_turn_button.rpc_id(1)				# in a perfect world this function would be the only thing needed

@rpc("any_peer","reliable")
func check_next_turn_button():
	var id = multiplayer.get_remote_sender_id()
	if id == main.red_spymas:
		advance_to_blue_turn.rpc()
	if id == main.blue_spymas:
		advance_to_red_turn.rpc()

#### GAME LOGIC FUNCTIONS

func _ready():
	setup_game()

func _process(delta):
	$TimerLabel.text = str(floor($Timer.time_left))
	if floor($Timer.time_left) == 5:
		$Audio/Ticking.play()

func setup_game():
	print("setting up...")
	if MultiplayerManager.settings["timer_enabled"]:
		time = MultiplayerManager.settings["time"]
		$Timer.start(time)
		$TimerLabel.visible = true
	
	if main.red_team.find(MultiplayerManager.peer.get_unique_id()) == -1:
		self_red = false
		$InfoPanel.set("theme_override_styles/panel",blue_theme_unsolved)
		
		$InfoPanel/Label.text = "BLUE TEAM\n\nSPYMASTER:\n\n"\
		+MultiplayerManager.players[main.blue_spymas].name+ (" (YOU)" if main.blue_spymas == MultiplayerManager.peer.get_unique_id() else "")\
		+"\n\nFIELD OPS:\n"
		
		for id in main.blue_fieldops:
			$InfoPanel/Label.text = $InfoPanel/Label.text + "\n" + MultiplayerManager.players[id].name + (" (YOU)" if id == MultiplayerManager.peer.get_unique_id() else "")
	else:
		self_red = true
		$InfoPanel.set("theme_override_styles/panel",red_theme_unsolved)
		
		$InfoPanel/Label.text = "RED TEAM\n\nSPYMASTER:\n\n"\
		+MultiplayerManager.players[main.red_spymas].name+ (" (YOU)" if main.red_spymas == MultiplayerManager.peer.get_unique_id() else "")\
		+"\n\nFIELD OPS:\n"
		
		for id in main.red_fieldops:
			$InfoPanel/Label.text = $InfoPanel/Label.text + "\n" + MultiplayerManager.players[id].name + (" (YOU)" if id == MultiplayerManager.peer.get_unique_id() else "")
	print("setup successful")
	
	setup_cards()

func _on_timer_timeout():
		if red_turn:
			if self_red:
				$Audio/TimeoutAlarm.play()
			if MultiplayerManager.peer.get_unique_id() == 1:
				advance_to_blue_turn.rpc()
		else:
			if not self_red:
				$Audio/TimeoutAlarm.play()
			if MultiplayerManager.peer.get_unique_id() == 1:
				advance_to_red_turn.rpc()

@rpc("authority","reliable","call_local")
func win_game(red,msg):
	$Timer.stop()
	$TimerLabel.visible = false
	$InputBlockPanel.visible = true
	$WinReasonLabel.visible = true
	win_screen = true
	
	if red:
		$TurnLabel.text = "RED WINS"
		$TurnLabel.add_theme_color_override("font_color",Color(1,0.5,0.5,1))
		$WinReasonLabel.text = msg
	else:
		$TurnLabel.text = "BLUE WINS"
		$TurnLabel.add_theme_color_override("font_color",Color(0.4,0.5,1,1))
		$WinReasonLabel.text = msg
	
	if MultiplayerManager.peer.get_unique_id() == 1:
		$NextTurnButton.visible = true
		$NextTurnButton.text = "NEXT GAME "
	else:
		$NextTurnButton.visible = false

#### CARD FUNCTIONS

func setup_cards():
	for i in range(5):
		for v in range(5):
			var card_node:Button = card_scene.instantiate()
			card_node.name = str(i*5+v)
			card_node.position = Vector2(v*145,i*90)
			card_node.text = card_names[i][v]
			card_node.rotation_degrees = randf_range(-2,2)
			if MultiplayerManager.peer.get_unique_id() == main.red_spymas or MultiplayerManager.peer.get_unique_id() == main.blue_spymas:
				card_node.disabled = true
				match card_teams[i][v]:
					0:
						card_node.set("theme_override_styles/disabled",default_theme)
					1:
						card_node.set("theme_override_styles/disabled",red_theme_unsolved)
					2:
						card_node.set("theme_override_styles/disabled",blue_theme_unsolved)
					3:
						card_node.set("theme_override_styles/disabled",assassin_theme_unsolved)
						card_node.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
			else:
				card_node.pressed.connect(card_pressed.bind(i*5+v))
			
			card_instances[i][v] = card_node
			$Cards.add_child(card_node)

func card_pressed(index):
	check_card.rpc(index)

@rpc("any_peer","reliable","call_local")
func check_card(index:int):
	var red
	var card:Button = card_instances[index/5][index%5]
	var cardteam:int = card_teams[index/5][index%5]
	var cardtext:String = card_names[index/5][index%5]
	var id = multiplayer.get_remote_sender_id()
	var username = MultiplayerManager.players[id].name
	
	if main.red_team.find(id) == -1:
		red = false
		$PickedCardLabel.push_color(Color(0.4,0.5,1))
	else:
		red = true
		$PickedCardLabel.push_color(Color(1,0.5,0.5))
	$PickedCardLabel.append_text("\n"+username)
	$PickedCardLabel.pop()
	$PickedCardLabel.append_text(" PICKED \"")
	card.disabled = true
	match cardteam:
		0:
			card.set("theme_override_styles/disabled",civillian_theme)
			$PickedCardLabel.push_color(Color(1,0.8,0.55))
			$Audio/AnswerAudioWrong.play()
			if MultiplayerManager.peer.get_unique_id() == 1:
				if red:
					advance_to_blue_turn.rpc()
				else:
					advance_to_red_turn.rpc()
		1:
			red_found += 1
			card.set("theme_override_styles/disabled",red_theme)
			card.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
			$PickedCardLabel.push_color(Color(1,0.5,0.5))
			if not red:
				if MultiplayerManager.peer.get_unique_id() == 1:
					advance_to_red_turn.rpc()
				$Audio/AnswerAudioWrong.play()
			else:
				$Audio/AnswerAudioRight.play()
			#card_node.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
		2:
			blue_found += 1
			card.set("theme_override_styles/disabled",blue_theme)
			card.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
			$PickedCardLabel.push_color(Color(0.4,0.5,1))
			if red:
				if MultiplayerManager.peer.get_unique_id() == 1:
					advance_to_blue_turn.rpc()
				$Audio/AnswerAudioWrong.play()
			else:
				$Audio/AnswerAudioRight.play()
			#card_node.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
		3:
			card.set("theme_override_styles/disabled",assassin_theme)
			card.set("theme_override_colors/font_disabled_color",Color(1,1,1,1))
			$PickedCardLabel.push_color(Color(0,0,0))
			$PickedCardLabel.push_outline_color(Color(1,1,1))
			$PickedCardLabel.push_outline_size(5)
			$Audio/AnswerAudioAssassin.play()
			if MultiplayerManager.peer.get_unique_id() == 1:
				if red:
					win_game.rpc(false,"RED FOUND THE ASSASSIN")
				else:
					win_game.rpc(true,"BLUE FOUND THE ASSASSIN")
	$PickedCardLabel.append_text(cardtext)
	$PickedCardLabel.pop_all()
	$PickedCardLabel.append_text("\"")
	if MultiplayerManager.peer.get_unique_id() == 1:
		if red_found == red_total:
			win_game.rpc(true,"RED FOUND ALL CARDS")
		if blue_found == blue_total:
			win_game.rpc(false,"BLUE FOUND ALL CARDS")
