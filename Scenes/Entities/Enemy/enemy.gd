class_name WalkerEnemy

extends CharacterBody2D


############################
##     NODE REFERENCES    ##
############################

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D

@onready var ground_check_left: RayCast2D = $GroundCheckLeft
@onready var ground_check_right: RayCast2D = $GroundCheckRight

@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox


############################
##        MOVEMENT        ##
############################

@export var move_speed: float = 30.0
@export var acceleration: float = 120.0
@export var friction: float = 120.0

var direction: float = 1.0


############################
##         GRAVITY        ##
############################

@export var gravity_strength: float = 700.0


############################
##      COMBAT STATE      ##
############################

var dead: bool = false


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

#### READY ####

func _ready() -> void:
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


#### ENEMY DAMAGED ####

func enemy_damaged(
	_damage_data: DamageData,
	damage_received: float,
	current_health: float
) -> void:
	if not multiplayer.is_server():
		return
	
	print(
		"%s took %.1f damage. Health: %.1f / %.1f"
		% [
			name,
			damage_received,
			current_health,
			health_component.maximum_health
		]
	)


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
	
	if dead:
		return
	
	broadcast_death()


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
	
	set_physics_process(false)
	
	hurtbox.set_hurtbox_enabled(false)
	body_collision.set_deferred("disabled", true)
	
	visible = false
	
	call_deferred("queue_free")


############################
##      SERVER ENEMY      ##
############################

#### SERVER PROCESS ####

func server_process(delta: float) -> void:
	handle_gravity(delta)
	handle_patrol_guidance()
	handle_movement(delta)
	
	move_and_slide()
	
	handle_animation()
	update_network_state()


#### HANDLE PATROL GUIDANCE ####

func handle_patrol_guidance() -> void:
	if not is_on_floor():
		return
	
	if direction < 0.0:
		if not ground_check_left.is_colliding():
			turn_around()
			return
		
		if wall_check_left.is_colliding():
			turn_around()
			return
	
	if direction > 0.0:
		if not ground_check_right.is_colliding():
			turn_around()
			return
		
		if wall_check_right.is_colliding():
			turn_around()


#### TURN AROUND ####

func turn_around() -> void:
	direction *= -1.0
	velocity.x = 0.0


#### HANDLE GRAVITY ####

func handle_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		
		return
	
	velocity.y += gravity_strength * delta


#### HANDLE MOVEMENT ####

func handle_movement(delta: float) -> void:
	if direction != 0.0:
		velocity.x = move_toward(
			velocity.x,
			direction * move_speed,
			acceleration * delta
		)
		
		return
	
	velocity.x = move_toward(
		velocity.x,
		0.0,
		friction * delta
	)


#### PICK RANDOM DIRECTION ####

func pick_random_direction() -> void:
	if randi_range(0, 1) == 0:
		direction = -1.0
		return
	
	direction = 1.0


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
		animated_sprite.play(network_animation)


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
