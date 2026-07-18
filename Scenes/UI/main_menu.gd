class_name MainMenu

extends Control


#### SIGNALS ####

signal host_requested
signal join_requested(ip_address: String, port: int)
signal options_requested


#### NODE REFERENCES ####

@onready var ip_address_input: LineEdit = %IPAddress
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var options_button: Button = %OptionsButton
@onready var exit_button: Button = %ExitButton
@onready var connection_status: Label = %ConnectionStatus


#### NETWORK SETTINGS ####

const DEFAULT_IP_ADDRESS: String = "127.0.0.1"
const DEFAULT_PORT: int = 7000


#### READY ####

func _ready() -> void:
	connect_buttons()
	clear_status()
	
	host_button.grab_focus()


#### BUTTON CONNECTIONS ####

func connect_buttons() -> void:
	if not host_button.pressed.is_connected(host_game):
		host_button.pressed.connect(host_game)
	
	if not join_button.pressed.is_connected(join_game):
		join_button.pressed.connect(join_game)
	
	if not options_button.pressed.is_connected(open_options):
		options_button.pressed.connect(open_options)
	
	if not exit_button.pressed.is_connected(exit_game):
		exit_button.pressed.connect(exit_game)


#### HOST GAME ####

func host_game() -> void:
	set_buttons_disabled(true)
	set_status("Starting server...")
	
	host_requested.emit()


#### JOIN GAME ####

func join_game() -> void:
	var connection_info: Dictionary = get_connection_info()
	
	if connection_info.is_empty():
		return
	
	var ip_address: String = connection_info["ip_address"]
	var port: int = connection_info["port"]
	
	set_buttons_disabled(true)
	
	set_status(
		"Connecting to %s:%s..." % [
			ip_address,
			port
		]
	)
	
	join_requested.emit(
		ip_address,
		port
	)


#### OPTIONS ####

func open_options() -> void:
	set_status("Options are not available yet.")
	
	options_requested.emit()


#### EXIT GAME ####

func exit_game() -> void:
	get_tree().quit()


#### CONNECTION INFORMATION ####

func get_connection_info() -> Dictionary:
	var address_text: String = ip_address_input.text.strip_edges()
	
	if address_text.is_empty():
		address_text = "%s:%s" % [
			DEFAULT_IP_ADDRESS,
			DEFAULT_PORT
		]
	
	var address_parts: PackedStringArray = address_text.split(
		":",
		false,
		1
	)
	
	var ip_address: String = address_parts[0].strip_edges()
	var port: int = DEFAULT_PORT
	
	if address_parts.size() > 1:
		var port_text: String = address_parts[1].strip_edges()
		
		if not port_text.is_valid_int():
			set_status("Invalid port number.")
			return {}
		
		port = port_text.to_int()
	
	if ip_address.is_empty():
		set_status("Enter a valid IP address.")
		return {}
	
	if port < 1 or port > 65535:
		set_status("Port must be between 1 and 65535.")
		return {}
	
	return {
		"ip_address": ip_address,
		"port": port
	}


#### BUTTON STATE ####

func set_buttons_disabled(disabled: bool) -> void:
	host_button.disabled = disabled
	join_button.disabled = disabled
	options_button.disabled = disabled


func enable_buttons() -> void:
	set_buttons_disabled(false)


#### CONNECTION STATUS ####

func set_status(message: String) -> void:
	connection_status.text = message


func clear_status() -> void:
	connection_status.text = ""
