class_name PlayerDetectionArea

extends Area2D


############################
##         SIGNALS        ##
############################

signal target_changed(
	previous_target: PlatformPlayer,
	new_target: PlatformPlayer
)


############################
##    DETECTION SETTINGS  ##
############################

@export var detection_enabled: bool = true

@export_range(1, 32, 1)
var player_collision_layer: int = 3


############################
##     DETECTION STATE    ##
############################

var detected_players: Array[PlatformPlayer] = []
var closest_player: PlatformPlayer = null


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	setup_detection_area()
	connect_detection_signals()
	
	set_physics_process(
		multiplayer.is_server()
	)


#### PHYSICS PROCESS ####

func _physics_process(
	_delta: float
) -> void:
	if not multiplayer.is_server():
		return
	
	if not detection_enabled:
		return
	
	refresh_closest_player()


############################
##         SETUP          ##
############################

#### SETUP DETECTION AREA ####

func setup_detection_area() -> void:
	collision_layer = 0
	collision_mask = 0
	
	set_collision_mask_value(
		player_collision_layer,
		true
	)
	
	monitorable = false
	
	set_detection_enabled(
		detection_enabled
	)


############################
##    SIGNAL CONNECTIONS  ##
############################

#### CONNECT DETECTION SIGNALS ####

func connect_detection_signals() -> void:
	if not body_entered.is_connected(
		detection_body_entered
	):
		body_entered.connect(
			detection_body_entered
		)
	
	if not body_exited.is_connected(
		detection_body_exited
	):
		body_exited.connect(
			detection_body_exited
		)


############################
##     BODY DETECTION     ##
############################

#### DETECTION BODY ENTERED ####

func detection_body_entered(
	body: Node2D
) -> void:
	if not multiplayer.is_server():
		return
	
	if not body is PlatformPlayer:
		return
	
	var player: PlatformPlayer = body as PlatformPlayer
	
	if detected_players.has(player):
		return
	
	detected_players.append(player)
	
	refresh_closest_player()


#### DETECTION BODY EXITED ####

func detection_body_exited(
	body: Node2D
) -> void:
	if not multiplayer.is_server():
		return
	
	if not body is PlatformPlayer:
		return
	
	var player: PlatformPlayer = body as PlatformPlayer
	
	detected_players.erase(player)
	
	refresh_closest_player()


############################
##     TARGET SELECTION   ##
############################

#### REFRESH CLOSEST PLAYER ####

func refresh_closest_player() -> void:
	remove_freed_players()
	
	var new_closest_player: PlatformPlayer = null
	var closest_distance_squared: float = INF
	
	for player: PlatformPlayer in detected_players:
		if not is_valid_target(player):
			continue
		
		var distance_squared: float = (
			global_position.distance_squared_to(
				player.global_position
			)
		)
		
		if distance_squared >= closest_distance_squared:
			continue
		
		closest_distance_squared = distance_squared
		new_closest_player = player
	
	set_closest_player(
		new_closest_player
	)


#### SET CLOSEST PLAYER ####

func set_closest_player(
	new_closest_player: PlatformPlayer
) -> void:
	if closest_player == new_closest_player:
		return
	
	var previous_target: PlatformPlayer = closest_player
	
	closest_player = new_closest_player
	
	target_changed.emit(
		previous_target,
		closest_player
	)


#### GET CLOSEST PLAYER ####

func get_closest_player() -> PlatformPlayer:
	if multiplayer.is_server() and detection_enabled:
		refresh_closest_player()
	
	return closest_player


#### HAS TARGET ####

func has_target() -> bool:
	return is_valid_target(
		closest_player
	)


#### IS VALID TARGET ####

func is_valid_target(
	player: PlatformPlayer
) -> bool:
	if player == null:
		return false
	
	if not is_instance_valid(player):
		return false
	
	if player.dead:
		return false
	
	if player.dying:
		return false
	
	if player.death_pending:
		return false
	
	return true


############################
##      LIST CLEANUP      ##
############################

#### REMOVE FREED PLAYERS ####

func remove_freed_players() -> void:
	for player_index: int in range(
		detected_players.size() - 1,
		-1,
		-1
	):
		var player: PlatformPlayer = (
			detected_players[player_index]
		)
		
		if is_instance_valid(player):
			continue
		
		detected_players.remove_at(
			player_index
		)


#### CLEAR DETECTED PLAYERS ####

func clear_detected_players() -> void:
	detected_players.clear()
	set_closest_player(null)


############################
##    DETECTION CONTROL   ##
############################

#### SET DETECTION ENABLED ####

func set_detection_enabled(
	new_enabled: bool
) -> void:
	detection_enabled = new_enabled
	
	var should_monitor: bool = (
		detection_enabled
		and multiplayer.is_server()
	)
	
	set_deferred(
		"monitoring",
		should_monitor
	)
	
	if detection_enabled:
		return
	
	clear_detected_players()
