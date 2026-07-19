class_name Hitbox

extends Area2D


############################
##         SIGNALS        ##
############################

signal hit_landed(
	hurtbox: Hurtbox,
	damage_data: DamageData,
	damage_received: float
)

signal activated
signal deactivated


############################
##      DAMAGE DATA       ##
############################

@export var damage_amount: float = 10.0

@export var damage_type: DamageTypes.Type = (
	DamageTypes.Type.GENERIC
)

@export var ignores_invincibility: bool = false

@export var damage_tags: Array[StringName] = []


############################
##       KNOCKBACK        ##
############################

@export var knockback_strength: float = 0.0

@export var use_target_direction_for_knockback: bool = true

@export var knockback_direction: Vector2 = Vector2.RIGHT


############################
##      HIT BEHAVIOR      ##
############################

@export var active_on_ready: bool = true
@export var one_hit_per_activation: bool = true
@export var deactivate_after_successful_hit: bool = false
@export var allow_self_damage: bool = false


############################
##      DAMAGE SOURCE     ##
############################

@export var source_entity: Node = null
@export var source_peer_id: int = 0


############################
##       HIT STATE        ##
############################

var active: bool = false
var hit_targets: Dictionary = {}


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	setup_hitbox()
	connect_area_signal()
	
	if active_on_ready:
		activate()


#### SETUP HITBOX ####

func setup_hitbox() -> void:
	monitoring = false
	monitorable = false
	
	if source_entity == null:
		source_entity = get_parent()


############################
##       ACTIVATION       ##
############################

#### ACTIVATE ####

func activate() -> void:
	hit_targets.clear()
	active = true
	
	set_deferred(
		"monitoring",
		true
	)
	
	activated.emit()


#### DEACTIVATE ####

func deactivate() -> void:
	if not active:
		return
	
	active = false
	
	set_deferred(
		"monitoring",
		false
	)
	
	deactivated.emit()


#### SET ACTIVE ####

func set_hitbox_active(
	new_active: bool
) -> void:
	if new_active:
		activate()
		return
	
	deactivate()


#### IS ACTIVE ####

func is_active() -> bool:
	return active


#### CLEAR HIT TARGETS ####

func clear_hit_targets() -> void:
	hit_targets.clear()


############################
##       HIT HANDLING     ##
############################

#### AREA ENTERED ####

func area_entered_hitbox(
	area: Area2D
) -> void:
	if not area is Hurtbox:
		return
	
	var hurtbox: Hurtbox = area as Hurtbox
	
	try_hit(hurtbox)


#### TRY HIT ####

func try_hit(
	hurtbox: Hurtbox
) -> float:
	if not active:
		return 0.0
	
	if hurtbox == null:
		return 0.0
	
	if is_self_hit(hurtbox):
		return 0.0
	
	var target_id: int = hurtbox.get_instance_id()
	
	if has_already_hit(target_id):
		return 0.0
	
	record_hit_target(target_id)
	
	var damage_data: DamageData = create_damage_data(
		hurtbox
	)
	
	var damage_received: float = hurtbox.receive_hit(
		damage_data
	)
	
	if damage_received <= 0.0:
		return 0.0
	
	hit_landed.emit(
		hurtbox,
		damage_data,
		damage_received
	)
	
	if deactivate_after_successful_hit:
		deactivate()
	
	return damage_received


#### IS SELF HIT ####

func is_self_hit(
	hurtbox: Hurtbox
) -> bool:
	if allow_self_damage:
		return false
	
	if source_entity == null:
		return false
	
	return hurtbox.get_owner_entity() == source_entity


#### HAS ALREADY HIT ####

func has_already_hit(
	target_id: int
) -> bool:
	if not one_hit_per_activation:
		return false
	
	return hit_targets.has(target_id)


#### RECORD HIT TARGET ####

func record_hit_target(
	target_id: int
) -> void:
	if not one_hit_per_activation:
		return
	
	hit_targets[target_id] = true


############################
##     DAMAGE CREATION    ##
############################

#### CREATE DAMAGE DATA ####

func create_damage_data(
	hurtbox: Hurtbox
) -> DamageData:
	var damage_data: DamageData = DamageData.new(
		damage_amount,
		damage_type,
		source_entity
	)
	
	damage_data.source_peer_id = source_peer_id
	damage_data.hit_position = hurtbox.global_position
	
	damage_data.knockback_strength = knockback_strength
	damage_data.knockback_direction = (
		get_knockback_direction(hurtbox)
	)
	
	damage_data.ignores_invincibility = (
		ignores_invincibility
	)
	
	copy_damage_tags(damage_data)
	
	return damage_data


#### COPY DAMAGE TAGS ####

func copy_damage_tags(
	damage_data: DamageData
) -> void:
	for tag: StringName in damage_tags:
		damage_data.add_tag(tag)


############################
##     KNOCKBACK DATA     ##
############################

#### GET KNOCKBACK DIRECTION ####

func get_knockback_direction(
	hurtbox: Hurtbox
) -> Vector2:
	if knockback_strength <= 0.0:
		return Vector2.ZERO
	
	if use_target_direction_for_knockback:
		var target_direction: Vector2 = (
			global_position.direction_to(
				hurtbox.global_position
			)
		)
		
		if not target_direction.is_zero_approx():
			return target_direction
	
	var configured_direction: Vector2 = (
		knockback_direction.rotated(
			global_rotation
		)
	)
	
	if configured_direction.is_zero_approx():
		return Vector2.ZERO
	
	return configured_direction.normalized()


############################
##      DAMAGE SOURCE     ##
############################

#### SET SOURCE ####

func set_source(
	new_source_entity: Node,
	new_source_peer_id: int = 0
) -> void:
	source_entity = new_source_entity
	source_peer_id = new_source_peer_id


############################
##    SIGNAL CONNECTION   ##
############################

#### CONNECT AREA SIGNAL ####

func connect_area_signal() -> void:
	if area_entered.is_connected(
		area_entered_hitbox
	):
		return
	
	area_entered.connect(
		area_entered_hitbox
	)
