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

#var timer_enabled
#var time = 60

var ongoing_game

func _init():
	names_file = FileAccess.open("res://wordlist.txt", FileAccess.READ)
	names_list = names_file.get_as_text().split("\n",false) # \n means newline character

func _ready():
	MultiplayerManager.disconnected.connect(disconnected)
	MultiplayerManager.player_removed.connect(player_removed)
	$HTTPRequest.request_completed.connect(_on_request_completed)
	$HTTPRequest.request("http://api.ipify.org")
	var error = FileAccess.get_open_error()
	if error == 7:
		$WarningPanel/WarningText.text = "NO WORDLIST FOUND. GAME WILL NOT WORK."
		$WarningPanel.visible = true

func _on_request_completed(result, response_code, headers, body):
	update_ip(body.get_string_from_utf8())

func _process(delta):
	if not $Music2.playing and $Music1.get_playback_position() >= 66.66:
		$Music2.play(2.66)
	if not $Music1.playing and $Music2.get_playback_position() >= 66.66:
		$Music1.play(2.66)

func assemble_matrix():
	var matrix = []
	for x in 5:
		matrix.append([])
		for y in 5:
			matrix[x].append(0)
	return matrix

func start_game_server(): #sets up team count, word list, and initiates GameplayScene.tscn
	ongoing_game = game_scene.instantiate()
	var current_names = names_list
	var red_first_turn = randi_range(0,1) == 0 #remember that comparison statements either return true or false
	var names = []
	var teams = []
	var red_count:int
	var blue_count:int
	
	for i in 5:
		names.append([])
		for v in 5:
			var name_index = randi_range(0,current_names.size()-1)
			names[i].append(current_names[name_index])
			current_names.remove_at(name_index)
	
	for x in 5:
		teams.append([])
		for y in 5:
			teams[x].append(0)
	
	for i in 8: # 0:Civillian, 1:Red, 2:Blue, 3:Assassin
		find_unteamed_card_add_team(1,teams)
		find_unteamed_card_add_team(2,teams)
	red_count = 8
	blue_count = 8
	
	if red_first_turn:
		find_unteamed_card_add_team(1,teams)
		red_count += 1
	else:
		find_unteamed_card_add_team(2,teams)
		blue_count += 1
	
	find_unteamed_card_add_team(3,teams)
	
	ongoing_game.card_names = names
	ongoing_game.card_teams = teams
	ongoing_game.red_total = red_count
	ongoing_game.blue_total = blue_count
	ongoing_game.card_instances = assemble_matrix()
	
	$LobbyUI.visible = false
	add_child(ongoing_game)
	if red_first_turn:
		ongoing_game.advance_to_red_turn()
	else:
		ongoing_game.advance_to_red_turn()
	send_card_data.rpc(teams,names,red_count,blue_count,red_first_turn)

func find_unteamed_card_add_team(team:int,matrix:Array):
	while true:
		var card_index = randi_range(1,24)
		if matrix[card_index/5][card_index%5] == 0:
			matrix[card_index/5][card_index%5] = team
			break

@rpc("authority","reliable")
func send_card_data(teams,names,totalred,totalblue,red_starts:bool):
	ongoing_game = game_scene.instantiate()
	
	ongoing_game.card_names = names
	ongoing_game.card_teams = teams
	ongoing_game.red_total = totalred
	ongoing_game.blue_total = totalblue
	ongoing_game.card_instances = assemble_matrix()
	
	$LobbyUI.visible = false
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

func early_end_throw_error(error:String):
	end_game()
	$WarningPanel/WarningText.text = error
	$WarningPanel.visible = true

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
