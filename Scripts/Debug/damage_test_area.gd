class_name DamageTestArea

extends Area2D


############################
##      DAMAGE SETTINGS   ##
############################

@export var damage_amount: float = 25.0
@export var knockback_strength: float = 220.0


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	setup_collision()
	connect_signals()


############################
##        COLLISION       ##
############################

#### SETUP COLLISION ####

func setup_collision() -> void:
	collision_layer = 0
	collision_mask = 0
	
	set_collision_mask_value(
		3,
		true
	)
	
	monitoring = multiplayer.is_server()


#### CONNECT SIGNALS ####

func connect_signals() -> void:
	if body_entered.is_connected(
		damage_body
	):
		return
	
	body_entered.connect(
		damage_body
	)


#### DAMAGE BODY ####

func damage_body(
	body: Node2D
) -> void:
	if not multiplayer.is_server():
		return
	
	if not body is PlatformPlayer:
		return
	
	var player: PlatformPlayer = body as PlatformPlayer
	
	var horizontal_direction: float = signf(
		player.global_position.x - global_position.x
	)
	
	if is_zero_approx(horizontal_direction):
		horizontal_direction = 1.0
	
	var damage_data: DamageData = DamageData.new(
		damage_amount,
		DamageTypes.Type.PHYSICAL,
		self
	)
	
	damage_data.source_peer_id = (
		multiplayer.get_unique_id()
	)
	
	damage_data.hit_position = global_position
	
	damage_data.knockback_direction = Vector2(
		horizontal_direction,
		-0.85
	).normalized()
	
	damage_data.knockback_strength = (
		knockback_strength
	)
	
	damage_data.add_tag(&"debug_hazard")
	
	player.take_damage(damage_data)
