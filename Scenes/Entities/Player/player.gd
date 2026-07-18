class_name PlatformPlayer

extends CharacterBody2D


#### NODE REFERENCES ####

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var respawn_timer: Timer = $RespawnTimer
@onready var control_timer: Timer = $ControlTimer
@onready var multiplayer_synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var player_camera: Camera2D = $PlayerCamera


#### PLAYER INFO ####

var peer_id: int = 1
var controls: bool = true
var sprite_type: String = "player"

var respawn_position: Vector2 = Vector2.ZERO


#### MOVEMENT ####

@export var speed: float = 70.0
@export var acceleration: float = 500.0
@export var friction: float = 500.0

@export var air_acceleration: float = 350.0
@export var air_friction: float = 80.0

@export var run_multiplier: float = 1.5

var direction: float = 0.0


#### JUMPING ####

@export var jump_velocity: float = -200.0

var jumped: bool = false
var double_jump_used: bool = false


#### COYOTE TIME ####

@export var coyote_time: float = 0.15

var coyote_timer: float = 0.0


#### GRAVITY ####

@export var gravity: Vector2 = Vector2(0.0, 600.0)
@export var jump_release_gravity_multiplier: float = 3.0
@export var falling_gravity_multiplier: float = 1.8


#### NETWORK STATE ####

@export var network_position: Vector2 = Vector2.ZERO
@export var network_velocity: Vector2 = Vector2.ZERO
@export var network_animation: StringName = &"Idle"
@export var network_flip_h: bool = false

@export var remote_smoothing: float = 15.0
@export var remote_snap_distance: float = 128.0


#### SETUP ####

func setup_player(
	new_peer_id: int,
	new_spawn_position: Vector2
) -> void:
	peer_id = new_peer_id
	name = str(peer_id)
	
	respawn_position = new_spawn_position
	global_position = new_spawn_position
	
	network_position = new_spawn_position
	network_velocity = Vector2.ZERO
	
	set_multiplayer_authority(peer_id, true)

############################
##     PLAYER OWNERSHIP   ##
############################

#### LOCAL PLAYER ####

func is_local_player() -> bool:
	return is_multiplayer_authority()


#### SERVER PLAYER ####

func is_server_player() -> bool:
	return peer_id == 1


#### PLAYER PEER ####

func get_peer_id() -> int:
	return peer_id


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	connect_timers()
	setup_camera()
	
	network_position = global_position
	network_velocity = velocity
	
	if not is_local_player():
		return
	
	Global.player_position = global_position
	Global.player_last_position = respawn_position
	
	modulate = Color.BLACK
	
	spawn_in()


#### CAMERA ####

func setup_camera() -> void:
	player_camera.enabled = is_multiplayer_authority()


#### TIMER CONNECTIONS ####

func connect_timers() -> void:
	if not respawn_timer.timeout.is_connected(respawn_finished):
		respawn_timer.timeout.connect(respawn_finished)
	
	if not control_timer.timeout.is_connected(control_finished):
		control_timer.timeout.connect(control_finished)


#### PHYSICS PROCESS ####

func _physics_process(delta: float) -> void:
	if not is_local_player():
		update_remote_player(delta)
		return
	
	Global.player_position = global_position
	
	get_input()
	update_coyote_time(delta)
	handle_jump()
	handle_sprite_direction()
	handle_animation()
	handle_gravity(delta)
	handle_movement(delta)
	
	move_and_slide()
	
	update_network_state()


#### INPUT ####

func get_input() -> void:
	direction = 0.0
	
	if not controls:
		return
	
	direction = Input.get_axis(
		"player_left",
		"player_right"
	)


#### COYOTE TIME ####

func update_coyote_time(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		jumped = false
		double_jump_used = false
		return
	
	coyote_timer = maxf(
		coyote_timer - delta,
		0.0
	)


#### JUMPING ####

func handle_jump() -> void:
	if not controls:
		return
	
	if not Input.is_action_just_pressed("player_jump"):
		return
	
	if can_ground_jump():
		perform_ground_jump()
		return
	
	if can_double_jump():
		perform_double_jump()


func can_ground_jump() -> bool:
	return coyote_timer > 0.0 and not jumped


func can_double_jump() -> bool:
	return not double_jump_used


func perform_ground_jump() -> void:
	jumped = true
	coyote_timer = 0.0
	
	velocity.y = jump_velocity


func perform_double_jump() -> void:
	double_jump_used = true
	
	velocity.y = jump_velocity


#### SPRITE DIRECTION ####

func handle_sprite_direction() -> void:
	if direction < 0.0:
		player_sprite.flip_h = true
	elif direction > 0.0:
		player_sprite.flip_h = false


#### ANIMATION ####

func handle_animation() -> void:
	var animation_name: StringName = get_current_animation()
	
	if player_sprite.animation == animation_name:
		return
	
	player_sprite.play(animation_name)


func get_current_animation() -> StringName:
	var running: bool = Input.is_action_pressed("player_run")
	
	if is_on_floor():
		if is_zero_approx(direction):
			return &"Idle"
		
		if running:
			return &"Run"
		
		return &"Walk"
	
	if velocity.y < 0.0:
		if running:
			return &"Run_Jump_Up"
		
		return &"Jump_Up"
	
	if running:
		return &"Run_Jump_Down"
	
	return &"Jump_Down"


#### GRAVITY ####

func handle_gravity(delta: float) -> void:
	if is_on_floor():
		return
	
	var gravity_multiplier: float = get_gravity_multiplier()
	
	velocity += gravity * gravity_multiplier * delta


func get_gravity_multiplier() -> float:
	if velocity.y < 0.0:
		if Input.is_action_pressed("player_jump"):
			return 1.0
		
		return jump_release_gravity_multiplier
	
	return falling_gravity_multiplier


#### MOVEMENT ####

func handle_movement(delta: float) -> void:
	if not is_zero_approx(direction):
		accelerate_player(delta)
		return
	
	decelerate_player(delta)


func accelerate_player(delta: float) -> void:
	var current_acceleration: float = acceleration
	var current_speed_multiplier: float = 1.0
	
	if not is_on_floor():
		current_acceleration = air_acceleration
	
	if Input.is_action_pressed("player_run"):
		current_speed_multiplier = run_multiplier
	
	var target_speed: float = (
		direction
		* speed
		* current_speed_multiplier
	)
	
	velocity.x = move_toward(
		velocity.x,
		target_speed,
		current_acceleration * delta
	)


func decelerate_player(delta: float) -> void:
	var current_friction: float = friction
	
	if not is_on_floor():
		current_friction = air_friction
	
	velocity.x = move_toward(
		velocity.x,
		0.0,
		current_friction * delta
	)


#### NETWORK STATE ####

func update_network_state() -> void:
	network_position = global_position
	network_velocity = velocity
	network_animation = player_sprite.animation
	network_flip_h = player_sprite.flip_h


func update_remote_player(delta: float) -> void:
	var distance_to_network_position: float = global_position.distance_to(
		network_position
	)
	
	if distance_to_network_position > remote_snap_distance:
		global_position = network_position
	else:
		var smoothing_weight: float = clampf(
			remote_smoothing * delta,
			0.0,
			1.0
		)
		
		global_position = global_position.lerp(
			network_position,
			smoothing_weight
		)
	
	velocity = network_velocity
	player_sprite.flip_h = network_flip_h
	
	if player_sprite.animation != network_animation:
		player_sprite.play(network_animation)


#### DAMAGE ####

func take_hit(
	target_location: Vector2,
	push: bool
) -> void:
	if is_multiplayer_authority():
		apply_hit(target_location, push)
		return
	
	receive_hit.rpc_id(
		peer_id,
		target_location,
		push
	)


@rpc("any_peer", "call_local", "reliable")
func receive_hit(
	target_location: Vector2,
	push: bool
) -> void:
	if not is_multiplayer_authority():
		return
	
	apply_hit(target_location, push)


func apply_hit(
	target_location: Vector2,
	push: bool
) -> void:
	var hit_direction: Vector2 = target_location.direction_to(
		global_position
	)
	
	if push:
		controls = false
		
		play_network_effect(&"Hit")
		
		control_timer.start(0.25)
		
		velocity = Vector2(
			hit_direction.x * 180.0,
			-180.0
		)
		
		return
	
	velocity += Vector2(
		hit_direction.x * 120.0,
		-120.0
	)


#### BOUNCE ####

func bounce_hit() -> void:
	if not is_multiplayer_authority():
		request_bounce.rpc_id(peer_id)
		return
	
	apply_bounce()


@rpc("any_peer", "call_local", "reliable")
func request_bounce() -> void:
	if not is_multiplayer_authority():
		return
	
	apply_bounce()


func apply_bounce() -> void:
	velocity.y = jump_velocity * 0.75


#### RESPAWN ####

func respawn() -> void:
	if not is_multiplayer_authority():
		request_respawn.rpc_id(peer_id)
		return
	
	perform_respawn()


@rpc("any_peer", "call_local", "reliable")
func request_respawn() -> void:
	if not is_multiplayer_authority():
		return
	
	perform_respawn()


func perform_respawn() -> void:
	global_position = respawn_position
	
	network_position = respawn_position
	network_velocity = Vector2.ZERO
	
	Global.player_last_position = respawn_position
	
	spawn_in()


#### RESPAWN POSITION ####

## SET RESPAWN POSITION ##

func set_respawn_position(new_position: Vector2) -> void:
	if not is_multiplayer_authority():
		return
	
	apply_respawn_position(new_position)


## APPLY RESPAWN POSITION ##

func apply_respawn_position(new_position: Vector2) -> void:
	respawn_position = new_position
	Global.player_last_position = new_position


#### SPAWN ####

func spawn_in() -> void:
	if not is_multiplayer_authority():
		return
	
	velocity = Vector2.ZERO
	
	network_position = global_position
	network_velocity = Vector2.ZERO
	
	controls = false
	
	player_sprite.set_frame_and_progress(0, 0.0)
	
	play_network_effect(&"SpawnIn")
	
	respawn_timer.start(1.4)


#### NETWORK EFFECTS ####

func play_network_effect(animation_name: StringName) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		play_effect_animation(animation_name)
		return
	
	play_effect_animation.rpc(animation_name)


@rpc("authority", "call_local", "reliable")
func play_effect_animation(animation_name: StringName) -> void:
	animation_player.play(animation_name)


#### TIMER FINISHED ####

func respawn_finished() -> void:
	if not is_multiplayer_authority():
		return
	
	controls = true


func control_finished() -> void:
	if not is_multiplayer_authority():
		return
	
	controls = true
