extends Control
class_name MainNodeClass #so that autofill works in children

var game_scene:PackedScene = load("res://scenes/gameplay_scene.tscn")

var names_file
var names_list

var red_team = []
var blue_team = []
var red_fieldops = []
var blue_fieldops = []
var red_spymas
var blue_spymas

var ongoing_game
var settings = {
	music_during_games = true,
	hide_found_cards = false
}

func _init():
	names_file = FileAccess.open("res://wordlist.txt", FileAccess.READ)
	names_list = names_file.get_as_text().split("\n",false) # \n means newline character


var EPIC_boolean = {
	joe = "president of the united states",
	obama = "black",
	trrump = "not black",
}
func _ready():
	print(EPIC_boolean["obama"])
	MultiplayerManager.disconnected.connect(disconnected)
	MultiplayerManager.player_removed.connect(player_removed)
	$HTTPRequest.request_completed.connect(_on_request_completed)
	$HTTPRequest.request("http://api.ipify.org")
	var error = FileAccess.get_open_error()
	if error == 7:
		$DrawOnTop/WarningPanel/WarningText.text = "NO WORDLIST FOUND. HOSTING WILL RESULT IN CARDS THAT SAY <NULL>."
		$DrawOnTop/WarningPanel.visible = true

func _on_request_completed(result, response_code, headers, body):
	update_ip(body.get_string_from_utf8())

func _process(delta):
	if $Audio/Music.get_playback_position() >= 66.66:
		$Audio/Music.play(2.66)

func start_game_server(): #sets up team count, word list, and initiates GameplayScene.tscn
	ongoing_game = game_scene.instantiate()
	var current_names = names_list
	var red_first_turn = randi_range(0,1) == 0 #remember that comparison statements either return true or false
	var cards = []
	var red_count:int
	var blue_count:int
	
	for i in 5:
		cards.append([])
		for v in 5:
			var name_index = randi_range(0,current_names.size()-1)
			cards[i].append\
			({
				text = current_names[name_index],
				team = 0,
				node = null,
				found = false
			})
			current_names.remove_at(name_index)
	
	for i in 8: # 0:Civillian, 1:Red, 2:Blue, 3:Assassin
		find_unteamed_card_add_team(1,cards)
		find_unteamed_card_add_team(2,cards)
	red_count = 8
	blue_count = 8
	
	if red_first_turn:
		find_unteamed_card_add_team(1,cards)
		red_count += 1
	else:
		find_unteamed_card_add_team(2,cards)
		blue_count += 1
	
	find_unteamed_card_add_team(3,cards)
	
	ongoing_game.cards = cards
	ongoing_game.red_total = red_count
	ongoing_game.blue_total = blue_count
	
	$LobbyUI.visible = false
	if settings["music_during_games"] == false:
		var tween = get_tree().create_tween()
		tween.tween_property($Audio/Music,"volume_db",-60,2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		var awaiter = func():
			await tween.finished
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),true)
		awaiter.call()
	
	add_child(ongoing_game)
	if red_first_turn:
		ongoing_game.advance_to_red_turn()
	else:
		ongoing_game.advance_to_red_turn()
	send_card_data.rpc(cards,red_count,blue_count,red_first_turn)

func find_unteamed_card_add_team(team:int,matrix:Array):
	while true:
		var card_index = randi_range(1,24)
		if matrix[card_index/5][card_index%5]["team"] == 0:
			matrix[card_index/5][card_index%5]["team"] = team
			break

@rpc("authority","reliable")
func send_card_data(cards,totalred,totalblue,red_starts:bool):
	ongoing_game = game_scene.instantiate()
	
	ongoing_game.cards = cards
	ongoing_game.red_total = totalred
	ongoing_game.blue_total = totalblue
	
	$LobbyUI.visible = false
	if settings["music_during_games"] == false:
		var tween = get_tree().create_tween()
		tween.tween_property($Audio/Music,"volume_db",-60,2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
		var awaiter = func():
			await tween.finished
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),true)
		awaiter.call()
	add_child(ongoing_game)
	if red_starts:
		ongoing_game.advance_to_red_turn()
	else:
		ongoing_game.advance_to_red_turn()

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

@rpc("authority","reliable","call_local")
func end_game():
	ongoing_game.queue_free()
	ongoing_game = null
	$LobbyUI.visible = true
	var tween = get_tree().create_tween()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),false)
	tween.tween_property($Audio/Music,"volume_db",0,2).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

func early_end_throw_error(error:String):
	end_game()
	$DrawOnTop/WarningPanel/WarningText.text = error
	$DrawOnTop/WarningPanel.visible = true

func _on_ip_copy_button_pressed():
	if not MultiplayerManager.local_ip:
		return
	DisplayServer.clipboard_set(MultiplayerManager.local_ip)

func validate_regex(text:String,regex_filter:String):
	var word = ''
	var regex = RegEx.new()
	regex.compile(regex_filter)
	for valid_character in regex.search_all(text):
		word += valid_character.get_string()
	return word


func _on_settings_button_pressed():
	$DrawOnTop/SettingsPanel.visible = not $DrawOnTop/SettingsPanel.visible

func _on_game_vol_slider_drag_ended(value_changed):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),($DrawOnTop/SettingsPanel/GameVolSlider.value-100)*0.6)
	if $DrawOnTop/SettingsPanel/GameVolSlider.value < 1:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"),true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"),false)
	$Audio/AnswerAudioAssassin.play()

func _on_music_vol_slider_drag_ended(value_changed):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),($DrawOnTop/SettingsPanel/MusicVolSlider.value-100)*0.6)
	if $DrawOnTop/SettingsPanel/MusicVolSlider.value < 1:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),false)

var checked_sprite = load("res://images/checkbox_checked.svg")
var unchecked_sprite = load("res://images/checkbox_unchecked.svg")

func _on_music_during_games_checkbox_pressed():
	if $DrawOnTop/SettingsPanel/MusicDuringGamesCheckbox.button_pressed:
		$DrawOnTop/SettingsPanel/MusicDuringGamesCheckbox.icon = checked_sprite
		settings["music_during_games"] = true
		if ongoing_game:
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),false)
	else:
		$DrawOnTop/SettingsPanel/MusicDuringGamesCheckbox.icon = unchecked_sprite
		settings["music_during_games"] = false
		if ongoing_game:
			AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"),true)

func _on_hide_found_cards_checkbox_pressed():
	if $DrawOnTop/SettingsPanel/HideFoundCardsCheckbox.button_pressed:
		$DrawOnTop/SettingsPanel/HideFoundCardsCheckbox.icon = checked_sprite
		settings["hide_found_cards"] = true
		if ongoing_game:
			for i in 5:
				for v in 5:
					var card = ongoing_game.cards[i][v]
					if card["found"]:
						card["node"].text = ""
	else:
		$DrawOnTop/SettingsPanel/HideFoundCardsCheckbox.icon = unchecked_sprite
		settings["hide_found_cards"] = false
		if ongoing_game:
			for i in 5:
				for v in 5:
					var card = ongoing_game.cards[i][v]
					if card["found"]:
						card["node"].text = card["text"]
