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
##     PROJECTILE SPEEDS  ##
############################

@export var bullet_speed: float = 1000.0
@export var plasma_speed: float = 250.0
@export var rocket_speed: float = 180.0
@export var laser_speed: float = 600.0


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

@onready var hitbox: Hitbox = $CollisionShapes

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

@onready var bullet_trail: Line2D = (
	$Visuals/BulletTrail
)

############################
##     PROJECTILE DATA    ##
############################

var projectile_type: ProjectileTypes = ProjectileTypes.BULLET

var move_speed: float = 350.0
var damage: float = 10.0
var lifetime: float = 3.0

var damage_type: DamageTypes.Type = (
	DamageTypes.Type.PHYSICAL
)

var knockback_strength: float = 100.0

var direction: Vector2 = Vector2.RIGHT
var shooter_peer_id: int = 1


############################
##      BULLET TRAIL      ##
############################

@export var bullet_trail_max_length: float = 40.0
@export var bullet_trail_shrink_speed: float = 180.0

var bullet_trail_length: float = 0.0
var bullet_trail_finished: bool = false
var impact_animation_finished: bool = false


############################
##      IMPACT STATE      ##
############################

var impact_active: bool = false


############################
##     NETWORK STATE      ##
############################

@export var network_position: Vector2 = Vector2.ZERO
@export var network_direction: Vector2 = Vector2.RIGHT

@export var network_projectile_type: int = (
	ProjectileTypes.BULLET
)


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
	
	configure_hitbox()
	update_visual_direction()
	setup_bullet_trail()


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
	move_speed = bullet_speed
	damage = 10.0
	lifetime = 3.0
	
	damage_type = DamageTypes.Type.PHYSICAL
	knockback_strength = 40.0
	
	bullet_sprite.visible = true
	bullet_shape.set_deferred("disabled", false)
	
	play_sprite_animation(
		bullet_sprite,
		&"Travel"
	)


#### SETUP PLASMA ####

func setup_plasma() -> void:
	move_speed = plasma_speed
	damage = 20.0
	lifetime = 4.0
	
	damage_type = DamageTypes.Type.ENERGY
	knockback_strength = 140.0
	
	plasma_sprite.visible = true
	plasma_shape.set_deferred("disabled", false)
	
	play_sprite_animation(
		plasma_sprite,
		&"Travel"
	)


#### SETUP ROCKET ####

func setup_rocket() -> void:
	move_speed = rocket_speed
	damage = 40.0
	lifetime = 5.0
	
	damage_type = DamageTypes.Type.EXPLOSIVE
	knockback_strength = 240.0
	
	rocket_sprite.visible = true
	rocket_shape.set_deferred("disabled", false)
	
	play_sprite_animation(
		rocket_sprite,
		&"Travel"
	)


#### SETUP LASER ####

func setup_laser() -> void:
	move_speed = laser_speed
	damage = 8.0
	lifetime = 1.5
	
	damage_type = DamageTypes.Type.ENERGY
	knockback_strength = 60.0
	
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
		return
	
	if sprite.sprite_frames.has_animation(&"default"):
		sprite.play(&"default")


############################
##         HITBOX         ##
############################

#### CONFIGURE HITBOX ####

func configure_hitbox() -> void:
	hitbox.damage_amount = damage
	hitbox.damage_type = damage_type
	
	hitbox.knockback_strength = knockback_strength
	
	# Use the projectile's facing direction rather than
	# calculating direction from the impact positions.
	hitbox.use_target_direction_for_knockback = false
	hitbox.knockback_direction = Vector2.RIGHT
	
	hitbox.one_hit_per_activation = true
	hitbox.deactivate_after_successful_hit = true
	hitbox.allow_self_damage = false
	
	hitbox.set_source(
		self,
		shooter_peer_id
	)
	
	setup_hitbox_collision()


#### SETUP HITBOX COLLISION ####

func setup_hitbox_collision() -> void:
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	
	# Player Hitbox
	hitbox.set_collision_layer_value(
		8,
		true
	)
	
	# Enemy Hurtbox
	hitbox.set_collision_mask_value(
		7,
		true
	)


#### PROJECTILE HIT LANDED ####

func projectile_hit_landed(
	_hurtbox: Hurtbox,
	_damage_data: DamageData,
	_damage_received: float
) -> void:
	if not multiplayer.is_server():
		return
	
	begin_projectile_impact(
		global_position
	)


############################
##     PROJECTILE IMPACT  ##
############################

#### BEGIN PROJECTILE IMPACT ####

func begin_projectile_impact(
	impact_position: Vector2
) -> void:
	if impact_active:
		return
	
	impact_active = true
	
	direction = Vector2.ZERO
	network_direction = Vector2.ZERO
	
	hitbox.deactivate()
	lifetime_timer.stop()
	
	set_deferred(
		"monitoring",
		false
	)
	
	broadcast_projectile_impact(
		impact_position
	)


#### BROADCAST PROJECTILE IMPACT ####

func broadcast_projectile_impact(
	impact_position: Vector2
) -> void:
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		apply_projectile_impact(
			impact_position
		)
		return
	
	apply_projectile_impact.rpc(
		impact_position
	)


#### APPLY PROJECTILE IMPACT ####

@rpc("authority", "call_local", "reliable")
func apply_projectile_impact(
	impact_position: Vector2
) -> void:
	impact_active = true
	impact_animation_finished = false
	
	bullet_trail_finished = (
		projectile_type
		!= ProjectileTypes.BULLET
		or is_zero_approx(
			bullet_trail_length
		)
	)
	
	global_position = impact_position
	network_position = impact_position
	
	direction = Vector2.ZERO
	network_direction = Vector2.ZERO
	
	set_physics_process(false)
	
	set_deferred(
		"monitoring",
		false
	)
	
	hitbox.deactivate()
	disable_all_projectile_types()
	
	if not bullet_trail_finished:
		bullet_trail.visible = true
	
	play_bullet_hit_animation()


#### PLAY BULLET HIT ANIMATION ####

func play_bullet_hit_animation() -> void:
	bullet_sprite.visible = true
	bullet_sprite.speed_scale = 1.0
	
	if bullet_sprite.sprite_frames == null:
		impact_animation_finished = true
		finish_projectile_impact()
		return
	
	if not bullet_sprite.sprite_frames.has_animation(
		&"hit"
	):
		impact_animation_finished = true
		finish_projectile_impact()
		return
	
	bullet_sprite.play(&"hit")


#### BULLET ANIMATION FINISHED ####

func bullet_animation_finished() -> void:
	if not impact_active:
		return
	
	if bullet_sprite.animation != &"hit":
		return
	
	impact_animation_finished = true
	
	finish_projectile_impact()


#### FINISH PROJECTILE IMPACT ####

func finish_projectile_impact() -> void:
	if not impact_animation_finished:
		return
	
	if not bullet_trail_finished:
		return
	
	if not multiplayer.is_server():
		return
	
	if is_queued_for_deletion():
		return
	
	queue_free()


############################
##      BULLET TRAIL      ##
############################

#### SETUP BULLET TRAIL ####

func setup_bullet_trail() -> void:
	bullet_trail.clear_points()
	
	bullet_trail.add_point(
		Vector2.ZERO
	)
	
	bullet_trail.add_point(
		Vector2.ZERO
	)
	
	bullet_trail_length = 0.0
	bullet_trail_finished = false
	
	bullet_trail.visible = (
		projectile_type
		== ProjectileTypes.BULLET
	)
	
	update_bullet_trail_points()


#### UPDATE BULLET TRAIL ####

func update_bullet_trail(delta: float) -> void:
	if projectile_type != ProjectileTypes.BULLET:
		return
	
	if impact_active:
		shrink_bullet_trail(delta)
	else:
		grow_bullet_trail(delta)
	
	update_bullet_trail_points()


#### GROW BULLET TRAIL ####

func grow_bullet_trail(delta: float) -> void:
	bullet_trail_length = minf(
		bullet_trail_length
		+ move_speed
		* delta,
		bullet_trail_max_length
	)


#### SHRINK BULLET TRAIL ####

func shrink_bullet_trail(delta: float) -> void:
	bullet_trail_length = move_toward(
		bullet_trail_length,
		0.0,
		bullet_trail_shrink_speed * delta
	)
	
	if not is_zero_approx(
		bullet_trail_length
	):
		return
	
	bullet_trail_length = 0.0
	bullet_trail_finished = true
	bullet_trail.visible = false
	
	finish_projectile_impact()


#### UPDATE BULLET TRAIL POINTS ####

func update_bullet_trail_points() -> void:
	if bullet_trail.get_point_count() < 2:
		return
	
	bullet_trail.set_point_position(
		0,
		Vector2(
			-bullet_trail_length,
			0.0
		)
	)
	
	bullet_trail.set_point_position(
		1,
		Vector2.ZERO
	)


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
	
	if not multiplayer.is_server():
		hitbox.deactivate()
		return
	
	hitbox.activate()
	lifetime_timer.start(lifetime)


#### CONNECT SIGNALS ####

func connect_signals() -> void:
	if not lifetime_timer.timeout.is_connected(
		lifetime_finished
	):
		lifetime_timer.timeout.connect(
			lifetime_finished
		)
	
	if not hitbox.hit_landed.is_connected(
		projectile_hit_landed
	):
		hitbox.hit_landed.connect(
			projectile_hit_landed
		)
	
	if not bullet_sprite.animation_finished.is_connected(
		bullet_animation_finished
	):
		bullet_sprite.animation_finished.connect(
			bullet_animation_finished
		)


#### PROCESS ####

func _process(delta: float) -> void:
	update_bullet_trail(delta)


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
	if impact_active:
		return
	
	var start_position: Vector2 = global_position
	
	var next_position: Vector2 = (
		start_position
		+ direction
		* move_speed
		* delta
	)
	
	var world_hit: Dictionary = get_world_collision(
		start_position,
		next_position
	)
	
	if not world_hit.is_empty():
		var impact_position: Vector2 = (
			world_hit["position"]
			as Vector2
		)
		
		begin_projectile_impact(
			impact_position
		)
		return
	
	global_position = next_position
	
	update_network_state()


#### GET WORLD COLLISION ####

func get_world_collision(
	start_position: Vector2,
	end_position: Vector2
) -> Dictionary:
	var ray_query: PhysicsRayQueryParameters2D = (
		PhysicsRayQueryParameters2D.create(
			start_position,
			end_position
		)
	)
	
	ray_query.collision_mask = 1
	ray_query.collide_with_bodies = true
	ray_query.collide_with_areas = false
	
	var space_state: PhysicsDirectSpaceState2D = (
		get_world_2d().direct_space_state
	)
	
	return space_state.intersect_ray(
		ray_query
	)


#### LIFETIME FINISHED ####

func lifetime_finished() -> void:
	if not multiplayer.is_server():
		return
	
	if impact_active:
		return
	
	hitbox.deactivate()
	
	queue_free()


############################
##        CLIENT          ##
############################

#### CLIENT PROCESS ####

func client_process(
	_delta: float
) -> void:
	apply_remote_projectile_type()
	
	direction = network_direction
	
	snap_to_network_position()
	update_visual_direction()


#### APPLY REMOTE PROJECTILE TYPE ####

func apply_remote_projectile_type() -> void:
	if projectile_type == network_projectile_type:
		return
	
	projectile_type = (
		network_projectile_type as ProjectileTypes
	)
	
	apply_projectile_type()
	hitbox.deactivate()


#### SNAP TO NETWORK POSITION ####

func snap_to_network_position() -> void:
	global_position = network_position


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
