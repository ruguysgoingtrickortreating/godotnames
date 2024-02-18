extends Node

signal player_added(id)
signal player_removed
signal connected_to_server()
signal connection_failed
signal disconnected(code)

var peer:ENetMultiplayerPeer
var local_name:String
var local_ip:String
var connected_ip:String
var connected_port:int
var gamedata = {}
var players = {}

func create_server(port:int, plr_name:String):
	local_name = plr_name
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port)
	if error: return error
	multiplayer.set_multiplayer_peer(peer)
	connected_ip = local_ip
	connected_port = port
	_register_new_player(local_name)
	return error

func create_client(ip_addr:String,port:int,plr_name:String):
	local_name = plr_name
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_addr,port)
	if error: return error
	connected_ip = ip_addr
	connected_port = port
	multiplayer.set_multiplayer_peer(peer)
	return error

@rpc("any_peer","reliable")
func _register_new_player(plr_name):
	var id = multiplayer.get_remote_sender_id()
	if not id: id = peer.get_unique_id()
	
	if peer.get_unique_id() != 1:
		print("_register_new_player() called on client instead of host")
		get_tree().quit()
	if players.has(id):
		push_error("multiplayer manager: _register_new_player called from id that already is registered! ("+str(id)+") haxxor!!?")
		return
	
	players[id] = {
		name = plr_name,
		team = 1
	}
	
	print(players)
	_send_new_player.rpc(id,players[id])
	_send_player_list.rpc_id(id,players)
	player_added.emit(id)

func _remove_player(id):
	if id == 1:
		disconnect_network()
		return
	player_removed.emit(id, players[id].name)
	players.erase(id)

func disconnect_network(code:int = 0):
	multiplayer.multiplayer_peer.close()
	peer = null
	local_name = ""
	connected_ip = ""
	connected_port = 0
	players.clear()
	disconnected.emit(code)

@rpc("authority","reliable")
func _send_new_player(id:int,new_entry:Dictionary):
	if id == peer.get_unique_id(): return
	if players.has(id): print("player "+str(id)+" already exists! "); return
	players[id] = new_entry
	print(str(players))
	player_added.emit(id)

@rpc("authority","reliable") func _send_player_list(player_list:Dictionary):
	players = player_list
	print(str(players))
	connected_to_server.emit()

func _connected_to_server(): #CONNECTING CLIENT ONLY
	_register_new_player.rpc_id(1,local_name)

func _player_disconnected(id):
	_remove_player(id)

func _server_disconnected():
	disconnect_network(1)

func _ready():
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server) #CONNECTING CLIENT ONLY
	#multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
