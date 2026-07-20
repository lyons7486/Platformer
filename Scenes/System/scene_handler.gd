class_name SceneHandler

extends Node


############################
##         SCENES         ##
############################

const MAIN_MENU_SCENE: PackedScene = preload(
	"res://Scenes/UI/main_menu.tscn"
)

const PLAYER_STATUS_SCENE: PackedScene = preload(
	"res://Scenes/UI/player_status.tscn"
)

const DEBUG_LEVEL_PATH: String = (
	"res://Scenes/Levels/debug_level.tscn"
)

const PLAYER_SCENE: PackedScene = preload(
	"res://Scenes/Entities/Player/player.tscn"
)

const RIFLE_PROJECTILE_SCENE: PackedScene = preload(
	"res://Scenes/Entities/Projectile/projectile.tscn"
)

############################
##      LEVEL STATE       ##
############################

var current_level_path: String = ""

############################
##   DEFEATED ENEMIES     ##
############################

var defeated_enemy_states: Dictionary = {}

############################
##     CHECKPOINT STATE   ##
############################

var shared_waypoint_position: Vector2 = Vector2.ZERO
var shared_waypoint_active: bool = false


############################
##     NODE REFERENCES    ##
############################

@onready var level_container: Node2D = $Level
@onready var players_container: Node2D = $Players
@onready var projectiles_container: Node2D = $Projectiles

@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var projectile_spawner: MultiplayerSpawner = $ProjectileSpawner

@onready var ui_container: CanvasLayer = $UI


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	setup_player_spawner()
	setup_projectile_spawner()
	connect_network_signals()
	load_main_menu()


############################
##       NETWORKING       ##
############################

#### NETWORK SIGNALS ####

func connect_network_signals() -> void:
	if not NetworkManager.connection_succeeded.is_connected(
		connection_succeeded
	):
		NetworkManager.connection_succeeded.connect(
			connection_succeeded
		)
	
	if not NetworkManager.connection_failed.is_connected(
		connection_failed
	):
		NetworkManager.connection_failed.connect(
			connection_failed
		)
	
	if not NetworkManager.server_disconnected.is_connected(
		server_disconnected
	):
		NetworkManager.server_disconnected.connect(
			server_disconnected
		)
	
	if not NetworkManager.player_connected.is_connected(
		player_connected
	):
		NetworkManager.player_connected.connect(
			player_connected
		)
	
	if not NetworkManager.player_disconnected.is_connected(
		player_disconnected
	):
		NetworkManager.player_disconnected.connect(
			player_disconnected
		)


#### HOST AND JOIN ####

## HOST GAME ##

func host_game() -> void:
	var error: Error = NetworkManager.host_game()
	
	if error == OK:
		load_level()
		return
	
	var main_menu: MainMenu = get_main_menu()
	
	if main_menu == null:
		return
	
	main_menu.set_status(
		"Could not start server. Error: %s" % error
	)
	
	main_menu.enable_buttons()


## JOIN GAME ##

func join_game(
	ip_address: String,
	port: int
) -> void:
	var error: Error = NetworkManager.join_game(
		ip_address,
		port
	)
	
	if error == OK:
		return
	
	var main_menu: MainMenu = get_main_menu()
	
	if main_menu == null:
		return
	
	main_menu.set_status(
		"Could not begin connection. Error: %s" % error
	)
	
	main_menu.enable_buttons()


#### CONNECTION CALLBACKS ####

## CONNECTION SUCCEEDED ##

func connection_succeeded() -> void:
	pass


## CONNECTION FAILED ##

func connection_failed() -> void:
	var main_menu: MainMenu = get_main_menu()
	
	if main_menu == null:
		load_main_menu()
		main_menu = get_main_menu()
	
	if main_menu == null:
		return
	
	main_menu.set_status(
		"Could not connect to the server."
	)
	
	main_menu.enable_buttons()


## SERVER DISCONNECTED ##

func server_disconnected() -> void:
	load_main_menu()
	
	var main_menu: MainMenu = get_main_menu()
	
	if main_menu == null:
		return
	
	main_menu.set_status(
		"The server disconnected."
	)


#### PLAYER CONNECTION CALLBACKS ####

## PLAYER CONNECTED ##

func player_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	if current_level_path.is_empty():
		return
	
	load_level_rpc.rpc_id(
		peer_id,
		current_level_path
	)


## PLAYER DISCONNECTED ##

func player_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	remove_player(peer_id)


#### LEAVE GAME ####

func leave_game() -> void:
	NetworkManager.close_connection()
	load_main_menu()


############################
##     SCENE LOADING      ##
############################

#### MAIN MENU ####

func load_main_menu() -> void:
	defeated_enemy_states.clear()
	
	clear_level()
	clear_players()
	clear_projectiles()
	clear_ui()
	
	var main_menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	
	main_menu.host_requested.connect(host_game)
	main_menu.join_requested.connect(join_game)
	main_menu.options_requested.connect(open_options)
	
	ui_container.add_child(main_menu)


#### LEVEL LOADING ####

## REQUEST LEVEL LOAD ##

func load_level(
	level_path: String = DEBUG_LEVEL_PATH
) -> void:
	if multiplayer.multiplayer_peer == null:
		defeated_enemy_states.clear()
		load_level_local(level_path)
		return
	
	if not multiplayer.is_server():
		return
	
	defeated_enemy_states.clear()
	
	shared_waypoint_position = Vector2.ZERO
	shared_waypoint_active = false
	
	current_level_path = level_path
	load_level_rpc.rpc(level_path)


## LOAD LEVEL RPC ##

@rpc("authority", "call_local", "reliable")
func load_level_rpc(level_path: String) -> void:
	load_level_local(level_path)
	
	if multiplayer.is_server():
		return
	
	client_level_ready.rpc_id(1)


## CLIENT LEVEL READY ##

@rpc("any_peer", "call_remote", "reliable")
func client_level_ready() -> void:
	if not multiplayer.is_server():
		return
	
	var peer_id: int = (
		multiplayer.get_remote_sender_id()
	)
	
	if peer_id <= 1:
		return
	
	sync_defeated_enemies.rpc_id(
		peer_id,
		defeated_enemy_states.duplicate(true)
	)
	
	spawn_player(peer_id)


## LOAD LEVEL LOCALLY ##

func load_level_local(level_path: String) -> void:
	var level_scene: PackedScene = load(level_path) as PackedScene
	
	if level_scene == null:
		push_error(
			"SceneHandler could not load level: %s" % level_path
		)
		return
	
	clear_level()
	clear_projectiles()
	clear_ui()
	
	var level: Node = level_scene.instantiate()
	
	level_container.add_child(level)
	current_level_path = level_path

	load_player_status()

	if multiplayer.is_server():
		spawn_connected_players()


#### OPTIONS ####

func open_options() -> void:
	print("Options requested")


############################
##       GAME HUD         ##
############################

#### LOAD PLAYER STATUS ####

func load_player_status() -> void:
	var player_status: PlayerStatus = (
		PLAYER_STATUS_SCENE.instantiate()
	)
	
	ui_container.add_child(
		player_status
	)

############################
##   DEFEATED ENEMIES     ##
############################

#### REGISTER DEFEATED ENEMY ####

func register_defeated_enemy(
	enemy_state_id: String,
	corpse_position: Vector2,
	corpse_flip_h: bool
) -> void:
	if not multiplayer.is_server():
		return
	
	if enemy_state_id.is_empty():
		return
	
	defeated_enemy_states[enemy_state_id] = {
		"position": corpse_position,
		"flip_h": corpse_flip_h
	}


#### SYNC DEFEATED ENEMIES ####

@rpc("authority", "call_remote", "reliable")
func sync_defeated_enemies(
	enemy_states: Dictionary
) -> void:
	for enemy_id_variant: Variant in enemy_states.keys():
		var enemy_state_id: String = String(
			enemy_id_variant
		)
		
		var state_variant: Variant = (
			enemy_states[enemy_id_variant]
		)
		
		if not state_variant is Dictionary:
			continue
		
		apply_defeated_enemy_state(
			enemy_state_id,
			state_variant as Dictionary
		)


#### APPLY DEFEATED ENEMY STATE ####

func apply_defeated_enemy_state(
	enemy_state_id: String,
	enemy_state: Dictionary
) -> void:
	var level: Level = get_current_level()
	
	if level == null:
		return
	
	var enemy_node: Node = level.get_node_or_null(
		NodePath(enemy_state_id)
	)
	
	if not enemy_node is WalkerEnemy:
		return
	
	if not enemy_state.has("position"):
		return
	
	var corpse_position: Vector2 = (
		enemy_state["position"]
	)
	
	var corpse_flip_h: bool = bool(
		enemy_state.get(
			"flip_h",
			false
		)
	)
	
	var enemy: WalkerEnemy = (
		enemy_node as WalkerEnemy
	)
	
	enemy.apply_corpse_state(
		corpse_position,
		corpse_flip_h
	)


#### UNREGISTER DEFEATED ENEMY ####

func unregister_defeated_enemy(
	enemy_state_id: String
) -> void:
	if not multiplayer.is_server():
		return
	
	if enemy_state_id.is_empty():
		return
	
	defeated_enemy_states.erase(
		enemy_state_id
	)


############################
##     PLAYER SPAWNING    ##
############################

#### PLAYER SPAWNER SETUP ####

func setup_player_spawner() -> void:
	player_spawner.spawn_function = create_player_from_data


#### PLAYER CREATION ####

func create_player_from_data(data: Variant) -> Node:
	var player_data: Dictionary = data
	
	var peer_id: int = player_data["peer_id"]
	var spawn_position: Vector2 = player_data["spawn_position"]
	
	var player: PlatformPlayer = PLAYER_SCENE.instantiate()
	
	player.setup_player(
		peer_id,
		spawn_position
	)
	
	return player


#### SPAWN CONNECTED PLAYERS ####

func spawn_connected_players() -> void:
	if not multiplayer.is_server():
		return
	
	spawn_player(multiplayer.get_unique_id())
	
	for peer_id: int in multiplayer.get_peers():
		spawn_player(peer_id)


#### SPAWN PLAYER ####

func spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	if has_player(peer_id):
		return
	
	var level: Level = get_current_level()
	
	if level == null:
		return
	
	var spawn_position: Vector2 = get_next_spawn_position(level)
	
	var spawn_data: Dictionary = {
		"peer_id": peer_id,
		"spawn_position": spawn_position
	}
	
	player_spawner.spawn(spawn_data)


#### SPAWN POSITION ####

func get_next_spawn_position(level: Level) -> Vector2:
	if shared_waypoint_active:
		return get_checkpoint_spawn_position()
	
	var player_index: int = players_container.get_child_count()
	
	return level.get_spawn_position() + Vector2(
		player_index * level.player_spawn_spacing,
		0.0
	)

#### CHECKPOINT SPAWN POSITION ####

func get_checkpoint_spawn_position() -> Vector2:
	var horizontal_offset: float = randf_range(
		-5.0,
		5.0
	)
	
	return shared_waypoint_position + Vector2(
		horizontal_offset,
		0.0
	)

#### PLAYER LOOKUP ####

## HAS PLAYER ##

func has_player(peer_id: int) -> bool:
	var player_name: String = str(peer_id)
	
	return players_container.has_node(player_name)


#### REMOVE PLAYER ####

func remove_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	for child: Node in players_container.get_children():
		if not child is PlatformPlayer:
			continue
		
		var player: PlatformPlayer = child
		
		if player.peer_id != peer_id:
			continue
		
		player.queue_free()
		return


############################
##   PROJECTILE SPAWNING  ##
############################

#### PROJECTILE SPAWNER SETUP ####

func setup_projectile_spawner() -> void:
	projectile_spawner.spawn_function = create_projectile_from_data


#### PROJECTILE CREATION ####

func create_projectile_from_data(data: Variant) -> Node:
	var projectile_data: Dictionary = data
	
	var spawn_position: Vector2 = (
		projectile_data["spawn_position"]
	)
	
	var projectile_direction: Vector2 = (
		projectile_data["direction"]
	)
	
	var shooter_peer_id: int = (
		projectile_data["shooter_peer_id"]
	)
	
	var projectile_type: int = (
		projectile_data["projectile_type"]
	)
	
	var projectile: Projectile = (
		RIFLE_PROJECTILE_SCENE.instantiate()
	)
	
	projectile.setup_projectile(
		spawn_position,
		projectile_direction,
		shooter_peer_id,
		projectile_type
	)
	
	return projectile


#### REQUEST RIFLE PROJECTILE ####

func request_rifle_projectile(
	spawn_position: Vector2,
	projectile_direction: Vector2,
	shooter_peer_id: int,
	projectile_type: int
) -> void:
	if multiplayer.is_server():
		spawn_rifle_projectile(
			spawn_position,
			projectile_direction,
			shooter_peer_id,
			projectile_type
		)
		return
	
	request_rifle_projectile_rpc.rpc_id(
		1,
		spawn_position,
		projectile_direction,
		shooter_peer_id,
		projectile_type
	)


#### REQUEST RIFLE PROJECTILE RPC ####

@rpc("any_peer", "call_remote", "reliable")
func request_rifle_projectile_rpc(
	spawn_position: Vector2,
	projectile_direction: Vector2,
	shooter_peer_id: int,
	projectile_type: int
) -> void:
	if not multiplayer.is_server():
		return
	
	var sender_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)
	
	if sender_peer_id != shooter_peer_id:
		return
	
	spawn_rifle_projectile(
		spawn_position,
		projectile_direction,
		shooter_peer_id,
		projectile_type
	)


#### SPAWN RIFLE PROJECTILE ####

func spawn_rifle_projectile(
	spawn_position: Vector2,
	projectile_direction: Vector2,
	shooter_peer_id: int,
	projectile_type: int
) -> void:
	if not multiplayer.is_server():
		return
	
	var spawn_data: Dictionary = {
		"spawn_position": spawn_position,
		"direction": projectile_direction,
		"shooter_peer_id": shooter_peer_id,
		"projectile_type": projectile_type
	}
	
	projectile_spawner.spawn(spawn_data)


############################
##     SHARED WAYPOINT    ##
############################

#### SET SHARED WAYPOINT ####

func set_shared_waypoint(
	waypoint_position: Vector2
) -> void:
	if not multiplayer.is_server():
		return
	
	shared_waypoint_position = waypoint_position
	shared_waypoint_active = true
	
	apply_shared_waypoint.rpc(waypoint_position)


#### APPLY SHARED WAYPOINT ####

@rpc("authority", "call_local", "reliable")
func apply_shared_waypoint(
	waypoint_position: Vector2
) -> void:
	for child: Node in players_container.get_children():
		if not child is PlatformPlayer:
			continue
		
		var player: PlatformPlayer = child
		
		player.set_respawn_position(
			waypoint_position
		)


############################
##       REFERENCES       ##
############################

#### MAIN MENU REFERENCE ####

func get_main_menu() -> MainMenu:
	for child: Node in ui_container.get_children():
		if child is MainMenu:
			return child
	
	return null


#### LEVEL REFERENCE ####

func get_current_level() -> Level:
	for child: Node in level_container.get_children():
		if child is Level:
			return child
	
	return null


############################
##        CLEANUP         ##
############################

#### CLEAR LEVEL ####

func clear_level() -> void:
	for child: Node in level_container.get_children():
		child.queue_free()


#### CLEAR PLAYERS ####

func clear_players() -> void:
	for child: Node in players_container.get_children():
		child.queue_free()


#### CLEAR PROJECTILES ####

func clear_projectiles() -> void:
	for child: Node in projectiles_container.get_children():
		child.queue_free()


#### CLEAR UI ####

func clear_ui() -> void:
	for child: Node in ui_container.get_children():
		child.queue_free()
