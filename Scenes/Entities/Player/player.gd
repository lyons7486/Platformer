class_name PlatformPlayer

extends CharacterBody2D


############################
##         SIGNALS        ##
############################

signal local_health_changed(
	current_health: float,
	maximum_health: float
)

signal local_player_died


############################
##     NODE REFERENCES    ##
############################

@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var equips: Marker2D = $Equipsr

@onready var body_collision: CollisionPolygon2D = (
	$CollisionPolygon2D
)

@onready var respawn_timer: Timer = $RespawnTimer
@onready var control_timer: Timer = $ControlTimer


@onready var death_timer: Timer = $DeathTimer



@onready var multiplayer_synchronizer: MultiplayerSynchronizer = (
	$MultiplayerSynchronizer
)

@onready var player_camera: Camera2D = $PlayerCamera

@onready var health_component: HealthComponent = (
	$HealthComponent
)

@onready var hurtbox: Hurtbox = $Hurtbox


############################
##       PLAYER INFO      ##
############################

var peer_id: int = 1
var controls: bool = true
var sprite_type: String = "player"

var respawn_position: Vector2 = Vector2.ZERO


############################
##        MOVEMENT        ##
############################

@export var speed: float = 70.0
@export var acceleration: float = 500.0
@export var friction: float = 500.0

@export var air_acceleration: float = 350.0
@export var air_friction: float = 80.0

@export var run_multiplier: float = 1.5

var direction: float = 0.0


############################
##         JUMPING        ##
############################

@export var jump_velocity: float = -200.0

var jumped: bool = false
var double_jump_used: bool = false


############################
##       COYOTE TIME      ##
############################

@export var coyote_time: float = 0.15

var coyote_timer: float = 0.0


############################
##         GRAVITY        ##
############################

@export var gravity: Vector2 = Vector2(0.0, 600.0)

@export var jump_release_gravity_multiplier: float = 3.0
@export var falling_gravity_multiplier: float = 1.8


############################
##      COMBAT SETTINGS   ##
############################

@export var hit_control_lock_duration: float = 0.25

@export var damage_invincibility_duration: float = 0.75
@export var spawn_invincibility_duration: float = 1.4

@export var death_respawn_delay: float = 2.0

@export_range(0.0, 1.0, 0.05)
var received_knockback_multiplier: float = 1.0

@export var maximum_received_knockback: Vector2 = Vector2(
	90.0,
	110.0
)

@export var hit_animation_duration: float = 0.5


############################
##       COMBAT STATE     ##
############################

var dead: bool = false
var dying: bool = false
var death_pending: bool = false

var hit_reaction_active: bool = false
var hit_reaction_time_remaining: float = 0.0

var camera_smoothing_enabled_default: bool = true


############################
##      NETWORK STATE     ##
############################

@export var network_position: Vector2 = Vector2.ZERO
@export var network_velocity: Vector2 = Vector2.ZERO
@export var network_animation: StringName = &"Idle"
@export var network_flip_h: bool = false
@export var network_dead: bool = false

@export var remote_smoothing: float = 15.0
@export var remote_snap_distance: float = 128.0


############################
##          SETUP         ##
############################

#### SETUP PLAYER ####

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
	
	setup_combat_components()
	connect_combat_signals()
	connect_animation_signals()
	setup_local_player_group()
	
	network_position = global_position
	network_velocity = velocity
	
	if not is_local_player():
		return
	
	Global.player_position = global_position
	Global.player_last_position = respawn_position
	
	modulate = Color.BLACK
	
	spawn_in()


#### PHYSICS PROCESS ####

func _physics_process(delta: float) -> void:
	if not is_local_player():
		update_remote_player(delta)
		return
	
	if dead:
		return
	
	Global.player_position = global_position
	
	if dying:
		process_death_animation(delta)
		return
	
	get_input()
	update_coyote_time(delta)
	handle_jump()
	handle_sprite_direction()
	update_hit_reaction(delta)
	handle_animation()
	handle_gravity(delta)
	handle_movement(delta)
	
	move_and_slide()
	
	update_network_state()


############################
##          CAMERA        ##
############################

#### SETUP CAMERA ####

func setup_camera() -> void:
	player_camera.enabled = is_multiplayer_authority()
	
	if not is_local_player():
		return
	
	camera_smoothing_enabled_default = (
		player_camera.position_smoothing_enabled
	)

#### DISABLE CAMERA SMOOTHING ####

func disable_camera_smoothing() -> void:
	if not is_local_player():
		return
	
	player_camera.position_smoothing_enabled = false


#### RESTORE CAMERA SMOOTHING ####

func restore_camera_smoothing() -> void:
	if not is_local_player():
		return
	
	player_camera.position_smoothing_enabled = (
		camera_smoothing_enabled_default
	)
	
	if not player_camera.position_smoothing_enabled:
		return
	
	player_camera.reset_smoothing()

############################
##          INPUT         ##
############################

#### GET INPUT ####

func get_input() -> void:
	direction = 0.0
	
	if not controls:
		return
	
	direction = Input.get_axis(
		"player_left",
		"player_right"
	)


############################
##       COYOTE TIME      ##
############################

#### UPDATE COYOTE TIME ####

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


############################
##         JUMPING        ##
############################

#### HANDLE JUMP ####

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


#### CAN GROUND JUMP ####

func can_ground_jump() -> bool:
	return coyote_timer > 0.0 and not jumped


#### CAN DOUBLE JUMP ####

func can_double_jump() -> bool:
	return not double_jump_used


#### PERFORM GROUND JUMP ####

func perform_ground_jump() -> void:
	jumped = true
	coyote_timer = 0.0
	
	velocity.y = jump_velocity


#### PERFORM DOUBLE JUMP ####

func perform_double_jump() -> void:
	double_jump_used = true
	
	velocity.y = jump_velocity


############################
##     SPRITE DIRECTION   ##
############################

#### HANDLE SPRITE DIRECTION ####

func handle_sprite_direction() -> void:
	if direction < 0.0:
		player_sprite.flip_h = true
	elif direction > 0.0:
		player_sprite.flip_h = false


############################
##        ANIMATION       ##
############################

#### HANDLE ANIMATION ####

func handle_animation() -> void:
	if hit_reaction_active:
		return
	
	var animation_name: StringName = get_current_animation()
	
	if player_sprite.animation == animation_name:
		return
	
	player_sprite.play(animation_name)


#### GET CURRENT ANIMATION ####

func get_current_animation() -> StringName:
	var running: bool = Input.is_action_pressed(
		"player_run"
	)
	
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


############################
##         GRAVITY        ##
############################

#### HANDLE GRAVITY ####

func handle_gravity(delta: float) -> void:
	if is_on_floor():
		return
	
	var gravity_multiplier: float = (
		get_gravity_multiplier()
	)
	
	velocity += gravity * gravity_multiplier * delta


#### GET GRAVITY MULTIPLIER ####

func get_gravity_multiplier() -> float:
	if velocity.y < 0.0:
		if Input.is_action_pressed("player_jump"):
			return 1.0
		
		return jump_release_gravity_multiplier
	
	return falling_gravity_multiplier


############################
##        MOVEMENT        ##
############################

#### HANDLE MOVEMENT ####

func handle_movement(delta: float) -> void:
	if not is_zero_approx(direction):
		accelerate_player(delta)
		return
	
	decelerate_player(delta)


#### ACCELERATE PLAYER ####

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


#### DECELERATE PLAYER ####

func decelerate_player(delta: float) -> void:
	var current_friction: float = friction
	
	if not is_on_floor():
		current_friction = air_friction
	
	velocity.x = move_toward(
		velocity.x,
		0.0,
		current_friction * delta
	)


############################
##         COMBAT         ##
############################

#### SETUP COMBAT COMPONENTS ####

func setup_combat_components() -> void:
	hurtbox.owner_entity = self
	hurtbox.health_component = health_component
	
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	
	hurtbox.set_collision_layer_value(
		6,
		true
	)
	
	hurtbox.use_invincibility_frames = true
	
	hurtbox.invincibility_duration = (
		damage_invincibility_duration
	)
	
	hurtbox.set_hurtbox_enabled(false)


#### CONNECT COMBAT SIGNALS ####

func connect_combat_signals() -> void:
	if not health_component.health_changed.is_connected(
		player_health_changed
	):
		health_component.health_changed.connect(
			player_health_changed
		)
	
	if not health_component.damaged.is_connected(
		player_damaged
	):
		health_component.damaged.connect(
			player_damaged
		)
	
	if not health_component.died.is_connected(
		player_died
	):
		health_component.died.connect(
			player_died
		)
	
	if not hurtbox.knockback_requested.is_connected(
		player_knockback_requested
	):
		hurtbox.knockback_requested.connect(
			player_knockback_requested
		)

############################
##   ANIMATION SIGNALS    ##
############################

#### CONNECT ANIMATION SIGNALS ####

func connect_animation_signals() -> void:
	if not player_sprite.animation_finished.is_connected(
		player_sprite_animation_finished
	):
		player_sprite.animation_finished.connect(
			player_sprite_animation_finished
		)


#### PLAYER SPRITE ANIMATION FINISHED ####

func player_sprite_animation_finished() -> void:
	if not is_local_player():
		return
	
	if not dying:
		return
	
	if player_sprite.animation != &"Death":
		return
	
	finish_death_animation()


############################
##     DAMAGE ROUTING     ##
############################

#### TAKE DAMAGE ####

func take_damage(
	damage_data: DamageData
) -> void:
	if damage_data == null:
		return
	
	if dead:
		return
	
	if is_local_player():
		apply_damage_data(damage_data)
		return
	
	var network_tags: PackedStringArray = (
		get_network_damage_tags(damage_data)
	)
	
	request_damage.rpc_id(
		peer_id,
		damage_data.amount,
		int(damage_data.damage_type),
		damage_data.source_peer_id,
		damage_data.hit_position,
		damage_data.knockback_direction,
		damage_data.knockback_strength,
		damage_data.ignores_invincibility,
		network_tags
	)


#### REQUEST DAMAGE ####

@rpc("any_peer", "call_remote", "reliable", 1)
func request_damage(
	damage_amount: float,
	damage_type_value: int,
	damage_source_peer_id: int,
	hit_position: Vector2,
	knockback_direction: Vector2,
	knockback_strength: float,
	ignores_invincibility: bool,
	damage_tags: PackedStringArray
) -> void:
	if not is_local_player():
		return
	
	var sender_id: int = (
		multiplayer.get_remote_sender_id()
	)
	
	if sender_id != 0 and sender_id != 1:
		return
	
	var damage_data: DamageData = DamageData.new(
		damage_amount,
		damage_type_value as DamageTypes.Type
	)
	
	damage_data.source_peer_id = damage_source_peer_id
	damage_data.hit_position = hit_position
	
	damage_data.knockback_direction = knockback_direction
	damage_data.knockback_strength = knockback_strength
	
	damage_data.ignores_invincibility = (
		ignores_invincibility
	)
	
	for tag: String in damage_tags:
		damage_data.add_tag(
			StringName(tag)
		)
	
	apply_damage_data(damage_data)


#### APPLY DAMAGE DATA ####

func apply_damage_data(
	damage_data: DamageData
) -> void:
	if not is_local_player():
		return
	
	hurtbox.receive_hit(damage_data)


#### GET NETWORK DAMAGE TAGS ####

func get_network_damage_tags(
	damage_data: DamageData
) -> PackedStringArray:
	var network_tags: PackedStringArray = []
	
	for tag: StringName in damage_data.tags:
		network_tags.append(
			String(tag)
		)
	
	return network_tags


############################
##     DAMAGE REACTION    ##
############################

#### PLAYER HEALTH CHANGED ####

func player_health_changed(
	current_health: float,
	maximum_health: float
) -> void:
	if not is_local_player():
		return
	
	local_health_changed.emit(
		current_health,
		maximum_health
	)


#### PLAYER DAMAGED ####

func player_damaged(
	_damage_data: DamageData,
	damage_received: float,
	current_health: float
) -> void:
	if not is_local_player():
		return
	
	controls = false
	
	start_hit_reaction()
	
	control_timer.start(
		hit_control_lock_duration
	)
	
	print(
		"Player %s took %.1f damage. Health: %.1f / %.1f"
		% [
			peer_id,
			damage_received,
			current_health,
			health_component.maximum_health
		]
	)


#### PLAYER KNOCKBACK REQUESTED ####

func player_knockback_requested(
	knockback_velocity: Vector2,
	_damage_data: DamageData
) -> void:
	if not is_local_player():
		return
	
	if dead:
		return
	
	var adjusted_knockback: Vector2 = (
		knockback_velocity
		* received_knockback_multiplier
	)
	
	adjusted_knockback.x = clampf(
		adjusted_knockback.x,
		-maximum_received_knockback.x,
		maximum_received_knockback.x
	)
	
	adjusted_knockback.y = clampf(
		adjusted_knockback.y,
		-maximum_received_knockback.y,
		maximum_received_knockback.y
	)
	
	velocity = adjusted_knockback


############################
##         DEATH          ##
############################

#### PLAYER DIED ####

func player_died(
	_damage_data: DamageData
) -> void:
	if not is_local_player():
		return
	
	if dead or dying or death_pending:
		return
	
	death_pending = true
	
	controls = false
	direction = 0.0
	
	hurtbox.set_hurtbox_enabled(false)
	
	control_timer.stop()
	
	disable_camera_smoothing()
	
	local_player_died.emit()
	
	## The Hurtbox emits its knockback signal after the
	## HealthComponent finishes processing the fatal damage.
	## Deferring this function allows that knockback signal
	## to set the player's velocity first.
	
	call_deferred(
		"begin_death_knockback"
	)


#### BEGIN DEATH KNOCKBACK ####

func begin_death_knockback() -> void:
	if not is_local_player():
		return
	
	if not death_pending:
		return
	
	death_pending = false
	dying = true
	
	controls = false
	direction = 0.0
	
	hit_reaction_active = false
	hit_reaction_time_remaining = 0.0
	
	player_sprite.play(&"Death")
	
	update_network_state()


#### FINISH DEATH ANIMATION ####

func finish_death_animation() -> void:
	if not is_local_player():
		return
	
	if not dying:
		return
	
	broadcast_dead_body_state(
		global_position,
		player_sprite.flip_h
	)
	
	death_timer.start(
		death_respawn_delay
	)

#### BROADCAST DEAD BODY STATE ####

func broadcast_dead_body_state(
	corpse_position: Vector2,
	corpse_flip_h: bool
) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		apply_dead_body_state(
			corpse_position,
			corpse_flip_h
		)
		return
	
	apply_dead_body_state.rpc(
		corpse_position,
		corpse_flip_h
	)


#### APPLY DEAD BODY STATE ####

@rpc("authority", "call_local", "reliable", 2)
func apply_dead_body_state(
	corpse_position: Vector2,
	corpse_flip_h: bool
) -> void:
	dead = true
	dying = false
	death_pending = false
	
	controls = false
	
	global_position = corpse_position
	network_position = corpse_position
	
	velocity = Vector2.ZERO
	network_velocity = Vector2.ZERO
	
	network_dead = true
	network_animation = &"Death"
	network_flip_h = corpse_flip_h
	
	animation_player.stop()
	
	modulate = Color.WHITE
	player_sprite.modulate = Color.WHITE
	
	player_sprite.flip_h = corpse_flip_h
	
	hurtbox.set_hurtbox_enabled(false)
	
	body_collision.set_deferred(
		"disabled",
		true
	)
	
	equips.visible = false
	visible = true
	
	hold_player_death_frame()

#### HOLD PLAYER DEATH FRAME ####

func hold_player_death_frame() -> void:
	if player_sprite.sprite_frames == null:
		return
	
	if not player_sprite.sprite_frames.has_animation(
		&"Death"
	):
		return
	
	var frame_count: int = (
		player_sprite.sprite_frames.get_frame_count(
			&"Death"
		)
	)
	
	if frame_count <= 0:
		return
	
	player_sprite.play(&"Death")
	
	player_sprite.set_frame_and_progress(
		frame_count - 1,
		1.0
	)
	
	player_sprite.pause()


############################
##    LEGACY HIT SUPPORT  ##
############################

#### TAKE HIT ####

func take_hit(
	target_location: Vector2,
	push: bool
	) -> void:
	var hit_direction: Vector2 = (
		target_location.direction_to(
			global_position
		)
	)
	
	var horizontal_direction: float = hit_direction.x
	
	if is_zero_approx(horizontal_direction):
		if player_sprite.flip_h:
			horizontal_direction = 1.0
		else:
			horizontal_direction = -1.0
	
	var damage_data: DamageData = DamageData.new(
		25.0 if push else 10.0,
		DamageTypes.Type.PHYSICAL
	)
	
	damage_data.hit_position = target_location
	
	damage_data.knockback_direction = Vector2(
		horizontal_direction,
		-0.85
	).normalized()
	
	damage_data.knockback_strength = (
		255.0 if push else 170.0
	)
	
	damage_data.add_tag(&"legacy_hit")
	
	take_damage(damage_data)

#### START HIT REACTION ####

func start_hit_reaction() -> void:
	hit_reaction_active = true
	
	hit_reaction_time_remaining = (
		hit_animation_duration
	)
	
	player_sprite.play(&"Hit")
	
	play_network_effect(
		&"Hit",
		damage_invincibility_duration
	)


#### UPDATE HIT REACTION ####

func update_hit_reaction(delta: float) -> void:
	if not hit_reaction_active:
		return
	
	hit_reaction_time_remaining = maxf(
		hit_reaction_time_remaining - delta,
		0.0
	)
	
	if hit_reaction_time_remaining > 0.0:
		return
	
	hit_reaction_active = false

############################
##         BOUNCE         ##
############################

#### BOUNCE HIT ####

func bounce_hit() -> void:
	if not is_multiplayer_authority():
		request_bounce.rpc_id(peer_id)
		return
	
	apply_bounce()


#### REQUEST BOUNCE ####

@rpc("any_peer", "call_local", "reliable")
func request_bounce() -> void:
	if not is_multiplayer_authority():
		return
	
	apply_bounce()


#### APPLY BOUNCE ####

func apply_bounce() -> void:
	velocity.y = jump_velocity * 0.75


############################
##        RESPAWN         ##
############################

#### RESPAWN ####

func respawn() -> void:
	if not is_multiplayer_authority():
		request_respawn.rpc_id(peer_id)
		return
	
	perform_respawn()


#### REQUEST RESPAWN ####

@rpc("any_peer", "call_local", "reliable")
func request_respawn() -> void:
	if not is_multiplayer_authority():
		return
	
	perform_respawn()


#### PERFORM RESPAWN ####

func perform_respawn() -> void:
	if not is_local_player():
		return
	
	death_timer.stop()
	
	health_component.reset_health()
	
	global_position = respawn_position
	velocity = Vector2.ZERO
	
	network_position = respawn_position
	network_velocity = Vector2.ZERO
	
	Global.player_last_position = respawn_position
	
	broadcast_respawn_state(
		respawn_position
	)
	
	spawn_in()


#### BROADCAST RESPAWN STATE ####

func broadcast_respawn_state(
	new_position: Vector2
) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		apply_respawn_state(new_position)
		return
	
	apply_respawn_state.rpc(
		new_position
	)


#### APPLY RESPAWN STATE ####

@rpc("authority", "call_local", "reliable")
func apply_respawn_state(
	new_position: Vector2
) -> void:
	dead = false
	dying = false
	death_pending = false
	
	network_dead = false
	
	visible = true
	equips.visible = true
	
	global_position = new_position
	network_position = new_position
	
	velocity = Vector2.ZERO
	network_velocity = Vector2.ZERO
	
	animation_player.stop()
	
	modulate = Color.WHITE
	player_sprite.modulate = Color.WHITE
	
	player_sprite.play(&"Idle")
	
	player_sprite.set_frame_and_progress(
		0,
		0.0
	)
	
	network_animation = &"Idle"
	network_flip_h = player_sprite.flip_h
	
	body_collision.set_deferred(
		"disabled",
		false
	)
	
	if not is_local_player():
		hurtbox.set_hurtbox_enabled(false)


############################
##    RESPAWN POSITION    ##
############################

#### SET RESPAWN POSITION ####

func set_respawn_position(
	new_position: Vector2
) -> void:
	if not is_multiplayer_authority():
		return
	
	apply_respawn_position(new_position)


#### APPLY RESPAWN POSITION ####

func apply_respawn_position(
	new_position: Vector2
) -> void:
	respawn_position = new_position
	Global.player_last_position = new_position


############################
##          SPAWN         ##
############################

#### SPAWN IN ####

func spawn_in() -> void:
	if not is_multiplayer_authority():
		return
	
	dead = false
	dying = false
	death_pending = false

	network_dead = false

	visible = true
	equips.visible = true

	player_sprite.play(&"Idle")
	network_animation = &"Idle"
	
	visible = true
	
	velocity = Vector2.ZERO
	
	network_position = global_position
	network_velocity = Vector2.ZERO
	
	controls = false
	
	hit_reaction_active = false
	hit_reaction_time_remaining = 0.0
	
	death_timer.stop()
	control_timer.stop()
	
	hurtbox.end_invincibility()
	hurtbox.set_hurtbox_enabled(true)
	
	hurtbox.start_invincibility(
		spawn_invincibility_duration
	)
	
	body_collision.set_deferred(
		"disabled",
		false
	)
	
	player_sprite.set_frame_and_progress(
		0,
		0.0
	)
	
	restore_camera_smoothing()
	
	play_spawn_effect()
	
	respawn_timer.start(
		spawn_invincibility_duration
	)


############################
##      NETWORK STATE     ##
############################

#### SETUP LOCAL PLAYER GROUP ####

func setup_local_player_group() -> void:
	if not is_local_player():
		return
	
	add_to_group(&"local_player")
	

#### UPDATE NETWORK STATE ####

func update_network_state() -> void:
	network_position = global_position
	network_velocity = velocity
	network_animation = player_sprite.animation
	network_flip_h = player_sprite.flip_h
	network_dead = dead


#### UPDATE REMOTE PLAYER ####

func update_remote_player(delta: float) -> void:
	if multiplayer.is_server():
		update_server_player_proxy()
	else:
		smooth_remote_player_position(delta)
	
	apply_remote_player_state()


#### UPDATE SERVER PLAYER PROXY ####

func update_server_player_proxy() -> void:
	## The server uses this player's physical body for
	## hit detection. It must use the newest synchronized
	## position rather than a visually smoothed position.
	
	global_position = network_position


#### SMOOTH REMOTE PLAYER POSITION ####

func smooth_remote_player_position(
	delta: float
) -> void:
	var distance_to_network_position: float = (
		global_position.distance_to(
			network_position
		)
	)
	
	if distance_to_network_position > remote_snap_distance:
		global_position = network_position
		return
	
	var smoothing_weight: float = clampf(
		remote_smoothing * delta,
		0.0,
		1.0
	)
	
	global_position = global_position.lerp(
		network_position,
		smoothing_weight
	)


#### APPLY REMOTE PLAYER STATE ####

func apply_remote_player_state() -> void:
	velocity = network_velocity
	player_sprite.flip_h = network_flip_h
	
	if network_dead:
		if not dead:
			apply_dead_body_state(
				network_position,
				network_flip_h
			)
		
		return
	
	if player_sprite.animation != network_animation:
		player_sprite.play(
			network_animation
		)


############################
##      NETWORK EFFECTS   ##
############################

#### PLAY NETWORK EFFECT ####

func play_network_effect(
	animation_name: StringName,
	effect_duration: float
) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		play_effect_animation(
			animation_name,
			effect_duration
		)
		return
	
	play_effect_animation.rpc(
		animation_name,
		effect_duration
	)


#### PLAY EFFECT ANIMATION ####

@rpc("authority", "call_local", "reliable")
func play_effect_animation(
	animation_name: StringName,
	effect_duration: float
) -> void:
	if not animation_player.has_animation(
		animation_name
	):
		return
	
	var effect_animation: Animation = (
		animation_player.get_animation(
			animation_name
		)
	)
	
	if effect_animation == null:
		return
	
	var safe_duration: float = maxf(
		effect_duration,
		0.001
	)
	
	var playback_speed: float = (
		effect_animation.length
		/ safe_duration
	)
	
	animation_player.play(
		animation_name,
		-1.0,
		playback_speed
	)


#### PLAY SPAWN EFFECT ####

func play_spawn_effect() -> void:
	play_network_effect(
		&"SpawnIn",
		spawn_invincibility_duration
	)

############################
##     TIMER CONNECTIONS  ##
############################

#### CONNECT TIMERS ####

func connect_timers() -> void:
	if not respawn_timer.timeout.is_connected(
		respawn_finished
	):
		respawn_timer.timeout.connect(
			respawn_finished
		)
	
	if not control_timer.timeout.is_connected(
		control_finished
	):
		control_timer.timeout.connect(
			control_finished
		)
	
	if not death_timer.timeout.is_connected(
		death_timer_finished
	):
		death_timer.timeout.connect(
			death_timer_finished
		)


############################
##      TIMER FINISHED    ##
############################

#### RESPAWN FINISHED ####

func respawn_finished() -> void:
	if not is_multiplayer_authority():
		return
	
	if dead or dying:
		return
	
	controls = true


#### CONTROL FINISHED ####

func control_finished() -> void:
	if not is_multiplayer_authority():
		return
	
	if dead:
		return
	
	controls = true

#### PROCESS DEATH ANIMATION ####

func process_death_animation(
	delta: float
) -> void:
	handle_gravity(delta)
	
	move_and_slide()
	
	update_network_state()

#### DEATH TIMER FINISHED ####

func death_timer_finished() -> void:
	if not is_multiplayer_authority():
		return
	
	perform_respawn()
