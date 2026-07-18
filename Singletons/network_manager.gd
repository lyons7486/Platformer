extends Node


#### SIGNALS ####

signal host_started
signal connection_succeeded
signal connection_failed
signal server_disconnected

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)


#### NETWORK SETTINGS ####

const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 4
const LOCAL_ADDRESS: String = "127.0.0.1"


#### CONNECTION STATE ####

var peer: ENetMultiplayerPeer = null


#### READY ####

func _ready() -> void:
	connect_multiplayer_signals()


#### MULTIPLAYER SIGNALS ####

func connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(
		_on_peer_connected
	):
		multiplayer.peer_connected.connect(
			_on_peer_connected
		)
	
	if not multiplayer.peer_disconnected.is_connected(
		_on_peer_disconnected
	):
		multiplayer.peer_disconnected.connect(
			_on_peer_disconnected
		)
	
	if not multiplayer.connected_to_server.is_connected(
		_on_connected_to_server
	):
		multiplayer.connected_to_server.connect(
			_on_connected_to_server
		)
	
	if not multiplayer.connection_failed.is_connected(
		_on_connection_failed
	):
		multiplayer.connection_failed.connect(
			_on_connection_failed
		)
	
	if not multiplayer.server_disconnected.is_connected(
		_on_server_disconnected
	):
		multiplayer.server_disconnected.connect(
			_on_server_disconnected
		)


#### HOST GAME ####

func host_game(port: int = DEFAULT_PORT) -> Error:
	close_connection()
	
	peer = ENetMultiplayerPeer.new()
	
	var error: Error = peer.create_server(
		port,
		MAX_PLAYERS
	)
	
	if error != OK:
		push_error(
			"Could not start server. Error: %s" % error
		)
		
		peer = null
		
		return error
	
	multiplayer.multiplayer_peer = peer
	
	print("Server started.")
	print("Port: ", port)
	print("Host peer ID: ", multiplayer.get_unique_id())
	print("Is server: ", multiplayer.is_server())
	
	host_started.emit()
	
	return OK


#### JOIN GAME ####

func join_game(
	address: String = LOCAL_ADDRESS,
	port: int = DEFAULT_PORT
) -> Error:
	close_connection()
	
	address = address.strip_edges()
	
	if address.is_empty():
		address = LOCAL_ADDRESS
	
	peer = ENetMultiplayerPeer.new()
	
	var error: Error = peer.create_client(
		address,
		port
	)
	
	if error != OK:
		push_error(
			"Could not create client. Error: %s" % error
		)
		
		peer = null
		
		return error
	
	multiplayer.multiplayer_peer = peer
	
	print(
		"Connecting to %s:%s..." % [
			address,
			port
		]
	)
	
	return OK


#### CLOSE CONNECTION ####

func close_connection() -> void:
	if multiplayer.multiplayer_peer == null:
		peer = null
		return
	
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		peer = null
		return
	
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	
	peer = null
	
	print("Multiplayer connection closed.")


#### CONNECTION INFORMATION ####

func is_online() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	
	return not (
		multiplayer.multiplayer_peer
		is OfflineMultiplayerPeer
	)


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()


#### NETWORK CALLBACKS ####

func _on_peer_connected(peer_id: int) -> void:
	print("Player connected: ", peer_id)
	
	player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Player disconnected: ", peer_id)
	
	player_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	print("Connected successfully.")
	print("Local peer ID: ", multiplayer.get_unique_id())
	
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	push_warning("Connection failed.")
	
	close_connection()
	
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_warning("Disconnected from server.")
	
	close_connection()
	
	server_disconnected.emit()
