class_name WalkerEnemy

extends CharacterBody2D


############################
##     NODE REFERENCES    ##
############################

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var ground_check_left: RayCast2D = $GroundCheckLeft
@onready var ground_check_right: RayCast2D = $GroundCheckRight

@onready var wall_check_left: RayCast2D = $WallCheckLeft
@onready var wall_check_right: RayCast2D = $WallCheckRight


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
	network_position = position
	network_velocity = velocity
	network_direction = direction
	network_animation = animated_sprite.animation
	network_flip_h = animated_sprite.flip_h
	
	if not multiplayer.is_server():
		return
	
	pick_random_direction()


#### PHYSICS PROCESS ####

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		server_process(delta)
	else:
		client_process(delta)


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
		animated_sprite.play("Walk")
	else:
		animated_sprite.play("Idle")
	
	if direction < 0.0:
		animated_sprite.flip_h = true
	elif direction > 0.0:
		animated_sprite.flip_h = false
