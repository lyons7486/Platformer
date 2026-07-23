class_name PerformanceMonitorUI

extends Control


############################
##     NODE REFERENCES    ##
############################

@onready var fps_label: Label = $Margin/VBox/Fps
@onready var ping_label: Label = $Margin/VBox/Ping


############################
##       UI SETTINGS      ##
############################

@export_range(0.1, 2.0, 0.1)
var update_interval: float = 0.5

@export var fps_prefix: String = "FPS: "
@export var ping_prefix: String = "Ping: "


############################
##       TIMER STATE      ##
############################

var update_timer: Timer = null


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	setup_update_timer()
	set_process(true)
	
	visible = false


#### PROCESS ####

func _process(
	_delta: float
) -> void:
	if not Input.is_action_just_pressed(
		&"debug_performance"
	):
		return
	
	toggle_performance_monitor()


############################
##       UI TOGGLE        ##
############################

#### TOGGLE PERFORMANCE MONITOR ####

func toggle_performance_monitor() -> void:
	visible = not visible
	
	if update_timer == null:
		return
	
	if visible:
		update_performance_display()
		update_timer.start()
		return
	
	update_timer.stop()


############################
##       TIMER SETUP      ##
############################

#### SETUP UPDATE TIMER ####

func setup_update_timer() -> void:
	update_timer = Timer.new()
	
	update_timer.name = (
		"PerformanceUpdateTimer"
	)
	
	update_timer.wait_time = (
		update_interval
	)
	
	update_timer.one_shot = false
	update_timer.autostart = false
	update_timer.ignore_time_scale = true
	
	update_timer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)
	
	add_child(
		update_timer
	)
	
	update_timer.timeout.connect(
		update_performance_display
	)


############################
##    DISPLAY UPDATES     ##
############################

#### UPDATE PERFORMANCE DISPLAY ####

func update_performance_display() -> void:
	update_fps_display()
	update_ping_display()


#### UPDATE FPS DISPLAY ####

func update_fps_display() -> void:
	if fps_label == null:
		return
	
	var current_fps: int = roundi(
		Engine.get_frames_per_second()
	)
	
	fps_label.text = (
		fps_prefix
		+ str(current_fps)
	)


#### UPDATE PING DISPLAY ####

func update_ping_display() -> void:
	if ping_label == null:
		return
	
	ping_label.text = (
		ping_prefix
		+ get_ping_text()
	)


############################
##         PING           ##
############################

#### GET PING TEXT ####

func get_ping_text() -> String:
	if not NetworkManager.is_online():
		return "Offline"
	
	var current_multiplayer_peer: MultiplayerPeer = (
		multiplayer.multiplayer_peer
	)
	
	if not current_multiplayer_peer is ENetMultiplayerPeer:
		return "N/A"
	
	var enet_multiplayer_peer: ENetMultiplayerPeer = (
		current_multiplayer_peer
		as ENetMultiplayerPeer
	)
	
	if multiplayer.is_server():
		return get_host_ping_text(
			enet_multiplayer_peer
		)
	
	return get_client_ping_text(
		enet_multiplayer_peer
	)


#### GET CLIENT PING TEXT ####

func get_client_ping_text(
	enet_multiplayer_peer: ENetMultiplayerPeer
) -> String:
	var server_peer: ENetPacketPeer = (
		enet_multiplayer_peer.get_peer(1)
	)
	
	if server_peer == null:
		return "Connecting"
	
	var ping_milliseconds: int = roundi(
		server_peer.get_statistic(
			ENetPacketPeer.PEER_ROUND_TRIP_TIME
		)
	)
	
	return "%s ms" % ping_milliseconds


#### GET HOST PING TEXT ####

func get_host_ping_text(
	enet_multiplayer_peer: ENetMultiplayerPeer
) -> String:
	var connected_peer_ids: PackedInt32Array = (
		multiplayer.get_peers()
	)
	
	if connected_peer_ids.is_empty():
		return "Host"
	
	var total_ping: float = 0.0
	var valid_peer_count: int = 0
	
	for connected_peer_id: int in connected_peer_ids:
		var connected_peer: ENetPacketPeer = (
			enet_multiplayer_peer.get_peer(
				connected_peer_id
			)
		)
		
		if connected_peer == null:
			continue
		
		total_ping += connected_peer.get_statistic(
			ENetPacketPeer.PEER_ROUND_TRIP_TIME
		)
		
		valid_peer_count += 1
	
	if valid_peer_count <= 0:
		return "Host"
	
	var average_ping: int = roundi(
		total_ping / valid_peer_count
	)
	
	return "%s ms avg" % average_ping
