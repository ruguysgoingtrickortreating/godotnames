extends Control

signal hosting()

const DEFAULT_IP:String = "127.0.0.1"
const DEFAULT_PORT:int = 1962

var ip_addr:String = DEFAULT_IP
var port:int = DEFAULT_PORT

@onready var username_box = $InfoPanel/UsernameBox
@onready var ip_box = $InfoPanel/IPBox
@onready var port_box = $InfoPanel/PortBox
@onready var card_text = $InfoPanel/CardText
var username_characters = "[a-zA-Z0-9\\s\\-\\_]"
var ip_characters = "[0-9\\.:+]"
var port_characters = "[0-9]"


# Called when the node enters the scene tree for the first time.
func _ready():
	if OS.has_feature("editor"):
		username_box.text = str(randi())


func on_host_pressed():
	card_text.text = "ENTER YOUR CREDENTIALS"
	
	if not username_box.text:
		card_text.text = "INPUT A USERNAME"
		return
	
	var error = MultiplayerManager.create_server(port, username_box.text)
	var error_name:String
	match error:
		20: error_name = "CAN'T CREATE HOST (ERR 20)"
		22: error_name = "ALREADY USING THAT PORT (ERR 22)"
	if error_name: card_text.text = "ERROR: " + error_name
	
	hosting.emit()
	self.visible = false
	$".."/LobbyUI.visible = true

func on_join_pressed():
	card_text.text = "ENTER YOUR CREDENTIALS"
	
	if not username_box.text:
		card_text.text = "INPUT A USERNAME"
		return
	
	var error = MultiplayerManager.create_client(ip_addr,port,username_box.text)
	var error_name:String
	match error:
		20:
			error_name = "COULDN'T REACH THAT IP (ERR 20)"
		22:
			error_name = "ALREADY USING THAT PORT (ERR 22)"
	card_text.text = "ERROR: " + error_name
	if error != OK: return
	
	self.visible = false
	$".."/LobbyUI.visible = true


func _on_username_box_text_changed(new_text:String):
	var old_caret_position = username_box.caret_column
	var validated_text = $"..".validate_regex(new_text,username_characters)
	username_box.set_text(validated_text)
	username_box.caret_column = old_caret_position

func _on_ip_box_text_changed(new_text):
	var old_caret_position = ip_box.caret_column
	var validated_text = $"..".validate_regex(new_text,ip_characters)
	ip_box.set_text(validated_text)
	ip_box.caret_column = old_caret_position
	if ip_box.text:
		ip_addr = ip_box.text
	else:
		ip_addr = DEFAULT_IP

func _on_port_box_text_changed(new_text):
	var old_caret_position = port_box.caret_column
	var validated_text = $"..".validate_regex(new_text,port_characters)
	port_box.set_text(validated_text)
	port_box.caret_column = old_caret_position
	if port_box.text:
		port = int(port_box.text)
	else:
		port = DEFAULT_PORT
