class_name Projectile

extends Area2D


############################
##     PROJECTILE TYPES   ##
############################

enum ProjectileTypes {
	BULLET,
	PLASMA,
	ROCKET,
	LASER
}


############################
##     NODE REFERENCES    ##
############################

@onready var bullet_sprite: AnimatedSprite2D = (
	$Visuals/BulletSprite
)

@onready var plasma_sprite: AnimatedSprite2D = (
	$Visuals/PlasmaSprite
)

@onready var rocket_sprite: AnimatedSprite2D = (
	$Visuals/RocketSprite
)

@onready var laser_sprite: AnimatedSprite2D = (
	$Visuals/LaserSprite
)

@onready var bullet_shape: CollisionShape2D = (
	$CollisionShapes/BulletShape
)

@onready var plasma_shape: CollisionShape2D = (
	$CollisionShapes/PlasmaShape
)

@onready var rocket_shape: CollisionShape2D = (
	$CollisionShapes/RocketShape
)

@onready var laser_shape: CollisionShape2D = (
	$CollisionShapes/LaserShape
)

@onready var lifetime_timer: Timer = $LifetimeTimer


############################
##     PROJECTILE DATA    ##
############################

var projectile_type: ProjectileTypes = ProjectileTypes.BULLET

var move_speed: float = 350.0
var damage: float = 10.0
var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var shooter_peer_id: int = 1


############################
##     NETWORK STATE      ##
############################

@export var network_position: Vector2 = Vector2.ZERO
@export var network_direction: Vector2 = Vector2.RIGHT

@export var network_projectile_type: int = (
	ProjectileTypes.BULLET
)

@export var remote_smoothing_speed: float = 20.0
@export var remote_snap_distance: float = 64.0


############################
##         SETUP          ##
############################

#### SETUP PROJECTILE ####

func setup_projectile(
	spawn_position: Vector2,
	new_direction: Vector2,
	new_shooter_peer_id: int,
	new_projectile_type: int
) -> void:
	global_position = spawn_position
	
	direction = new_direction.normalized()
	shooter_peer_id = new_shooter_peer_id
	
	projectile_type = (
		new_projectile_type as ProjectileTypes
	)
	
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	
	network_position = global_position
	network_direction = direction
	network_projectile_type = projectile_type


#### APPLY PROJECTILE TYPE ####

func apply_projectile_type() -> void:
	disable_all_projectile_types()
	
	match projectile_type:
		ProjectileTypes.BULLET:
			setup_bullet()
		
		ProjectileTypes.PLASMA:
			setup_plasma()
		
		ProjectileTypes.ROCKET:
			setup_rocket()
		
		ProjectileTypes.LASER:
			setup_laser()
	
	update_visual_direction()


#### DISABLE ALL PROJECTILE TYPES ####

func disable_all_projectile_types() -> void:
	bullet_sprite.visible = false
	plasma_sprite.visible = false
	rocket_sprite.visible = false
	laser_sprite.visible = false
	
	bullet_shape.set_deferred("disabled", true)
	plasma_shape.set_deferred("disabled", true)
	rocket_shape.set_deferred("disabled", true)
	laser_shape.set_deferred("disabled", true)


############################
##     TYPE SETTINGS      ##
############################

#### SETUP BULLET ####

func setup_bullet() -> void:
	move_speed = 350.0
	damage = 10.0
	lifetime = 3.0
	
	bullet_sprite.visible = true
	bullet_shape.set_deferred("disabled", false)
	
	play_sprite_animation(
		bullet_sprite,
		&"Travel"
	)


#### SETUP PLASMA ####

func setup_plasma() -> void:
	move_speed = 250.0
	damage = 20.0
	lifetime = 4.0
	
	plasma_sprite.visible = true
	plasma_shape.set_deferred("disabled", false)
	
	play_sprite_animation(
		plasma_sprite,
		&"Travel"
	)


#### SETUP ROCKET ####

func setup_rocket() -> void:
	move_speed = 180.0
	damage = 40.0
	lifetime = 5.0
	
	rocket_sprite.visible = true
	rocket_shape.set_deferred("disabled", false)
	
	play_sprite_animation(
		rocket_sprite,
		&"Travel"
	)


#### SETUP LASER ####

func setup_laser() -> void:
	move_speed = 600.0
	damage = 8.0
	lifetime = 1.5
	
	laser_sprite.visible = true
	laser_shape.set_deferred("disabled", false)
	
	play_sprite_animation(
		laser_sprite,
		&"Travel"
	)


#### PLAY SPRITE ANIMATION ####

func play_sprite_animation(
	sprite: AnimatedSprite2D,
	animation_name: StringName
) -> void:
	if sprite.sprite_frames == null:
		return
	
	if sprite.sprite_frames.has_animation(
		animation_name
	):
		sprite.play(animation_name)
		return
	
	if sprite.sprite_frames.has_animation(&"Default"):
		sprite.play(&"Default")


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	connect_signals()
	
	network_position = global_position
	network_direction = direction
	network_projectile_type = projectile_type
	
	apply_projectile_type()
	
	if multiplayer.is_server():
		lifetime_timer.start(lifetime)


#### CONNECT SIGNALS ####

func connect_signals() -> void:
	if not lifetime_timer.timeout.is_connected(
		lifetime_finished
	):
		lifetime_timer.timeout.connect(
			lifetime_finished
		)


#### PHYSICS PROCESS ####

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		server_process(delta)
	else:
		client_process(delta)


############################
##        SERVER          ##
############################

#### SERVER PROCESS ####

func server_process(delta: float) -> void:
	global_position += direction * move_speed * delta
	
	update_network_state()


#### LIFETIME FINISHED ####

func lifetime_finished() -> void:
	if not multiplayer.is_server():
		return
	
	queue_free()


############################
##        CLIENT          ##
############################

#### CLIENT PROCESS ####

func client_process(delta: float) -> void:
	apply_remote_projectile_type()
	update_remote_position(delta)
	
	direction = network_direction
	
	update_visual_direction()


#### APPLY REMOTE PROJECTILE TYPE ####

func apply_remote_projectile_type() -> void:
	if projectile_type == network_projectile_type:
		return
	
	projectile_type = (
		network_projectile_type as ProjectileTypes
	)
	
	apply_projectile_type()


#### UPDATE REMOTE POSITION ####

func update_remote_position(delta: float) -> void:
	var distance_to_target: float = (
		global_position.distance_to(
			network_position
		)
	)
	
	if distance_to_target > remote_snap_distance:
		global_position = network_position
		return
	
	var smoothing_weight: float = clampf(
		remote_smoothing_speed * delta,
		0.0,
		1.0
	)
	
	global_position = global_position.lerp(
		network_position,
		smoothing_weight
	)


############################
##     VISUAL DIRECTION   ##
############################

#### UPDATE VISUAL DIRECTION ####

func update_visual_direction() -> void:
	var flip_projectile: bool = direction.x < 0.0
	
	bullet_sprite.flip_h = flip_projectile
	plasma_sprite.flip_h = flip_projectile
	rocket_sprite.flip_h = flip_projectile
	laser_sprite.flip_h = flip_projectile
	
	rotation = direction.angle()


############################
##        NETWORK         ##
############################

#### UPDATE NETWORK STATE ####

func update_network_state() -> void:
	network_position = global_position
	network_direction = direction
	network_projectile_type = projectile_type
