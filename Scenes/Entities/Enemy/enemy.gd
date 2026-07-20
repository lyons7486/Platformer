class_name WalkerEnemy

extends CharacterBody2D


############################
##     NODE REFERENCES    ##
############################

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D

@onready var ground_check_left: RayCast2D = $CheckArea/GroundCheckLeft
@onready var ground_check_right: RayCast2D = $CheckArea/GroundCheckRight

@onready var wall_check_left: RayCast2D = $CheckArea/WallCheckLeft
@onready var wall_check_right: RayCast2D = $CheckArea/WallCheckRight

@onready var detection_area: PlayerDetectionArea = $DetectionArea

@onready var contact_hitbox: ContactHitbox = (
	$Attacks/Bite/ContactHitbox
)

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox

@onready var death_knockback_timer: Timer = (
	$DeathKnockbackTimer
)



############################
##        MOVEMENT        ##
############################

@export var move_speed: float = 30.0
@export var chase_speed: float = 42.0

@export var acceleration: float = 120.0
@export var friction: float = 120.0

@export var chase_stop_distance: float = 4.0

var direction: float = 1.0


############################
##         TARGET         ##
############################

var target_player: PlatformPlayer = null


############################
##         GRAVITY        ##
############################

@export var gravity_strength: float = 700.0


############################
##      DEATH SETTINGS    ##
############################

@export var death_horizontal_friction: float = 180.0


############################
##     HIT FEEDBACK       ##
############################

@export_range(0.01, 1.0, 0.01)
var hit_flash_duration: float = 0.15

@export var hit_flash_color: Color = Color(
	1.0,
	0.15,
	0.15,
	1.0
)

@export_range(0.05, 2.0, 0.05)
var death_knockback_duration: float = 0.35


############################
##    HIT FEEDBACK STATE  ##
############################

var default_sprite_modulate: Color = Color.WHITE
var hit_flash_tween: Tween = null

############################
##      COMBAT STATE      ##
############################

var dead: bool = false
var dying: bool = false
var death_pending: bool = false

var enemy_state_id: String = ""


############################
##     NETWORK STATE      ##
############################

@export var network_position: Vector2 = Vector2.ZERO
@export var network_velocity: Vector2 = Vector2.ZERO
@export var network_direction: float = 1.0
@export var network_animation: StringName = &"Idle"
@export var network_flip_h: bool = false

@export var remote_smoothing_speed: float = 12.0


############################
##       LIFECYCLE        ##
############################

func _ready() -> void:
	initialize_enemy_state_id()
	connect_animation_signals()
	
	setup_combat_components()
	connect_combat_signals()
	initialize_network_state()
	
	if not multiplayer.is_server():
		return
	
	pick_random_direction()


#### INITIALIZE NETWORK STATE ####

func initialize_network_state() -> void:
	network_position = position
	network_velocity = velocity
	network_direction = direction
	network_animation = animated_sprite.animation
	network_flip_h = animated_sprite.flip_h


#### PHYSICS PROCESS ####

func _physics_process(delta: float) -> void:
	if dead:
		return
	
	if multiplayer.is_server():
		server_process(delta)
	else:
		client_process(delta)

############################
##    TIMER CONNECTIONS   ##
############################

#### CONNECT TIMERS ####

func connect_timers() -> void:
	if not death_knockback_timer.timeout.is_connected(
		finish_death_knockback
	):
		death_knockback_timer.timeout.connect(
			finish_death_knockback
		)


############################
##         COMBAT         ##
############################

#### SETUP COMBAT COMPONENTS ####

func setup_combat_components() -> void:
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	
	hurtbox.set_collision_layer_value(
		7,
		true
	)
	
	hurtbox.use_invincibility_frames = false
	
	hurtbox.set_hurtbox_enabled(
		multiplayer.is_server()
	)


#### CONNECT COMBAT SIGNALS ####

func connect_combat_signals() -> void:
	if not health_component.damaged.is_connected(
		enemy_damaged
	):
		health_component.damaged.connect(
			enemy_damaged
		)
	
	if not health_component.died.is_connected(
		enemy_died
	):
		health_component.died.connect(
			enemy_died
		)
	
	if not hurtbox.knockback_requested.is_connected(
		enemy_knockback_requested
	):
		hurtbox.knockback_requested.connect(
			enemy_knockback_requested
		)


############################
##   ANIMATION SIGNALS    ##
############################

#### CONNECT ANIMATION SIGNALS ####

func connect_animation_signals() -> void:
	if not animated_sprite.animation_finished.is_connected(
		enemy_animation_finished
	):
		animated_sprite.animation_finished.connect(
			enemy_animation_finished
		)


#### ENEMY ANIMATION FINISHED ####

func enemy_animation_finished() -> void:
	if not multiplayer.is_server():
		return
	
	if not dying:
		return
	
	if animated_sprite.animation != &"Death":
		return
	
	finish_death_animation()


#### ENEMY DAMAGED ####

func enemy_damaged(
	_damage_data: DamageData,
	damage_received: float,
	current_health: float
) -> void:
	if not multiplayer.is_server():
		return
	
	broadcast_hit_flash()
	
	print(
		"%s took %.1f damage. Health: %.1f / %.1f"
		% [
			name,
			damage_received,
			current_health,
			health_component.maximum_health
		]
	)

############################
##       HIT FLASH        ##
############################

#### BROADCAST HIT FLASH ####

func broadcast_hit_flash() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		play_hit_flash()
		return
	
	play_hit_flash.rpc()


#### PLAY HIT FLASH ####

@rpc("authority", "call_local", "unreliable", 2)
func play_hit_flash() -> void:
	if dead:
		return
	
	stop_hit_flash()
	
	animated_sprite.self_modulate = hit_flash_color
	
	hit_flash_tween = create_tween()
	
	hit_flash_tween.tween_property(
		animated_sprite,
		"self_modulate",
		default_sprite_modulate,
		hit_flash_duration
	)


#### STOP HIT FLASH ####

func stop_hit_flash() -> void:
	if hit_flash_tween != null:
		if hit_flash_tween.is_valid():
			hit_flash_tween.kill()
	
	hit_flash_tween = null


#### ENEMY KNOCKBACK REQUESTED ####

func enemy_knockback_requested(
	knockback_velocity: Vector2,
	_damage_data: DamageData
) -> void:
	if not multiplayer.is_server():
		return
	
	if dead:
		return
	
	velocity += knockback_velocity


#### ENEMY DIED ####

func enemy_died(
	_damage_data: DamageData
) -> void:
	if not multiplayer.is_server():
		return
	
	if dead or dying or death_pending:
		return
	
	death_pending = true
	
	register_defeated_enemy()
	disable_enemy_combat()
	
	# The HealthComponent emits its death signal before
	# the Hurtbox finishes applying fatal knockback.
	
	call_deferred(
		"begin_death_animation"
	)


#### DISABLE ENEMY COMBAT ####

func disable_enemy_combat() -> void:
	direction = 0.0
	target_player = null
	
	detection_area.set_detection_enabled(false)
	hurtbox.set_hurtbox_enabled(false)
	
	contact_hitbox.stop_contact_damage()

#### BEGIN DEATH KNOCKBACK ####

func begin_death_knockback() -> void:
	if not multiplayer.is_server():
		return
	
	if not death_pending:
		return
	
	death_pending = false
	dying = true
	
	direction = 0.0
	
	animated_sprite.play(&"Idle")
	
	update_network_state()
	
	death_knockback_timer.start(
		death_knockback_duration
	)


#### FINISH DEATH KNOCKBACK ####

func finish_death_knockback() -> void:
	if not multiplayer.is_server():
		return
	
	if not dying:
		return
	
	dying = false
	
	broadcast_death()

#### BEGIN DEATH ANIMATION ####

func begin_death_animation() -> void:
	if not multiplayer.is_server():
		return
	
	if not death_pending:
		return
	
	death_pending = false
	dying = true
	
	direction = 0.0
	
	animated_sprite.play(&"Death")
	
	update_network_state()


#### FINISH DEATH ANIMATION ####

func finish_death_animation() -> void:
	if not multiplayer.is_server():
		return
	
	if not dying:
		return
	
	dying = false
	
	broadcast_death()


#### REGISTER DEFEATED ENEMY ####

func register_defeated_enemy() -> void:
	if enemy_state_id.is_empty():
		return
	
	var scene_handler: SceneHandler = (
		get_tree().current_scene as SceneHandler
	)
	
	if scene_handler == null:
		push_warning(
			"%s could not find SceneHandler."
			% name
		)
		return
	
	scene_handler.register_defeated_enemy(
		enemy_state_id
	)

#### BROADCAST DEATH ####

func broadcast_death() -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		apply_death()
		return
	
	apply_death.rpc()


#### APPLY DEATH ####

@rpc("authority", "call_local", "reliable")
func apply_death() -> void:
	if dead:
		return
	
	dead = true
	dying = false
	death_pending = false
	
	set_physics_process(false)
	
	detection_area.set_detection_enabled(false)
	hurtbox.set_hurtbox_enabled(false)
	contact_hitbox.stop_contact_damage()
	
	body_collision.set_deferred(
		"disabled",
		true
	)
	
	visible = false
	
	call_deferred(
		"queue_free"
	)


############################
##      SERVER ENEMY      ##
############################

#### SERVER PROCESS ####

func server_process(delta: float) -> void:
	if dying:
		process_death_animation(delta)
		return
	
	update_target_player()
	
	handle_gravity(delta)
	handle_movement_guidance()
	handle_movement(delta)
	
	move_and_slide()
	
	handle_animation()
	update_network_state()


#### PROCESS DEATH ANIMATION ####

func process_death_animation(
	delta: float
) -> void:
	handle_gravity(delta)
	
	velocity.x = move_toward(
		velocity.x,
		0.0,
		death_horizontal_friction * delta
	)
	
	move_and_slide()
	
	update_network_state()


#### PROCESS DEATH KNOCKBACK ####

func process_death_knockback(
	delta: float
) -> void:
	handle_gravity(delta)
	
	move_and_slide()
	
	update_network_state()


############################
##      TARGET LOGIC      ##
############################

#### UPDATE TARGET PLAYER ####

func update_target_player() -> void:
	target_player = detection_area.get_closest_player()


#### HAS VALID TARGET ####

func has_valid_target() -> bool:
	if target_player == null:
		return false
	
	if not is_instance_valid(target_player):
		return false
	
	if target_player.dead:
		return false
	
	if target_player.dying:
		return false
	
	if target_player.death_pending:
		return false
	
	return true


#### HANDLE MOVEMENT GUIDANCE ####

func handle_movement_guidance() -> void:
	if has_valid_target():
		handle_chase_guidance()
		return
	
	handle_patrol_guidance()


#### HANDLE CHASE GUIDANCE ####

func handle_chase_guidance() -> void:
	if not is_on_floor():
		return
	
	var horizontal_difference: float = (
		target_player.global_position.x
		- global_position.x
	)
	
	if absf(horizontal_difference) <= chase_stop_distance:
		direction = 0.0
		return
	
	var desired_direction: float = signf(
		horizontal_difference
	)
	
	if is_direction_blocked(desired_direction):
		direction = 0.0
		return
	
	direction = desired_direction


############################
##        PATROLLING      ##
############################

#### HANDLE PATROL GUIDANCE ####

func handle_patrol_guidance() -> void:
	if not is_on_floor():
		return
	
	if is_zero_approx(direction):
		pick_random_direction()
	
	if is_direction_blocked(direction):
		turn_around()


#### IS DIRECTION BLOCKED ####

func is_direction_blocked(
	move_direction: float
) -> bool:
	if move_direction < 0.0:
		if not ground_check_left.is_colliding():
			return true
		
		if wall_check_left.is_colliding():
			return true
	
	if move_direction > 0.0:
		if not ground_check_right.is_colliding():
			return true
		
		if wall_check_right.is_colliding():
			return true
	
	return false


#### TURN AROUND ####

func turn_around() -> void:
	direction *= -1.0
	velocity.x = 0.0


#### PICK RANDOM DIRECTION ####

func pick_random_direction() -> void:
	if randi_range(0, 1) == 0:
		direction = -1.0
		return
	
	direction = 1.0


############################
##         GRAVITY        ##
############################

#### HANDLE GRAVITY ####

func handle_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		
		return
	
	velocity.y += gravity_strength * delta


############################
##        MOVEMENT        ##
############################

#### HANDLE MOVEMENT ####

func handle_movement(delta: float) -> void:
	if not is_zero_approx(direction):
		accelerate_enemy(delta)
		return
	
	decelerate_enemy(delta)


#### ACCELERATE ENEMY ####

func accelerate_enemy(delta: float) -> void:
	var current_move_speed: float = move_speed
	
	if has_valid_target():
		current_move_speed = chase_speed
	
	velocity.x = move_toward(
		velocity.x,
		direction * current_move_speed,
		acceleration * delta
	)


#### DECELERATE ENEMY ####

func decelerate_enemy(delta: float) -> void:
	velocity.x = move_toward(
		velocity.x,
		0.0,
		friction * delta
	)


############################
##      CLIENT ENEMY      ##
############################

#### CLIENT PROCESS ####

func client_process(delta: float) -> void:
	update_remote_enemy(delta)


#### UPDATE REMOTE ENEMY ####

func update_remote_enemy(delta: float) -> void:
	var smoothing_weight: float = clampf(
		remote_smoothing_speed * delta,
		0.0,
		1.0
	)
	
	position = position.lerp(
		network_position,
		smoothing_weight
	)
	
	velocity = network_velocity
	direction = network_direction
	
	animated_sprite.flip_h = network_flip_h
	
	if animated_sprite.animation != network_animation:
		animated_sprite.play(
			network_animation
		)


############################
##        NETWORK         ##
############################

#### UPDATE NETWORK STATE ####

func update_network_state() -> void:
	network_position = position
	network_velocity = velocity
	network_direction = direction
	network_animation = animated_sprite.animation
	network_flip_h = animated_sprite.flip_h


############################
##       ANIMATION        ##
############################

#### HANDLE ANIMATION ####

func handle_animation() -> void:
	if absf(velocity.x) > 1.0:
		animated_sprite.play(&"Walk")
	else:
		animated_sprite.play(&"Idle")
	
	if direction < 0.0:
		animated_sprite.flip_h = true
	elif direction > 0.0:
		animated_sprite.flip_h = false

############################
##     ENEMY STATE ID     ##
############################

#### INITIALIZE ENEMY STATE ID ####

func initialize_enemy_state_id() -> void:
	var level: Level = find_parent_level()
	
	if level == null:
		push_warning(
			"%s could not find its parent Level."
			% name
		)
		return
	
	enemy_state_id = String(
		level.get_path_to(self)
	)


#### FIND PARENT LEVEL ####

func find_parent_level() -> Level:
	var current_node: Node = get_parent()
	
	while current_node != null:
		if current_node is Level:
			return current_node as Level
		
		current_node = current_node.get_parent()
	
	return null
