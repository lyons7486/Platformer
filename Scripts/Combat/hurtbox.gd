class_name Hurtbox

extends Area2D


############################
##         SIGNALS        ##
############################

signal hit_received(
	damage_data: DamageData,
	damage_received: float
)

signal hit_blocked(
	damage_data: DamageData
)

signal knockback_requested(
	knockback_velocity: Vector2,
	damage_data: DamageData
)

signal invincibility_started(
	duration: float
)

signal invincibility_ended


############################
##     NODE REFERENCES    ##
############################

@onready var invincibility_timer: Timer = $InvincibilityTimer


############################
##       REFERENCES       ##
############################

@export var health_component: HealthComponent = null
@export var owner_entity: Node = null


############################
##     HURTBOX SETTINGS   ##
############################

@export var hurtbox_enabled: bool = true


############################
##      INVINCIBILITY     ##
############################

@export var use_invincibility_frames: bool = true

@export_range(0.0, 10.0, 0.05)
var invincibility_duration: float = 0.5

var invincible: bool = false


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	resolve_references()
	setup_hurtbox()
	connect_timer()


#### SETUP HURTBOX ####

func setup_hurtbox() -> void:
	monitoring = false
	
	invincibility_timer.one_shot = true
	
	set_hurtbox_enabled(hurtbox_enabled)


############################
##       REFERENCES       ##
############################

#### RESOLVE REFERENCES ####

func resolve_references() -> void:
	resolve_owner_entity()
	resolve_health_component()


#### RESOLVE OWNER ENTITY ####

func resolve_owner_entity() -> void:
	if owner_entity != null:
		return
	
	owner_entity = get_parent()


#### RESOLVE HEALTH COMPONENT ####

func resolve_health_component() -> void:
	if health_component != null:
		return
	
	if owner_entity == null:
		push_warning(
			"Hurtbox could not find its owner entity."
		)
		return
	
	for child: Node in owner_entity.get_children():
		if not child is HealthComponent:
			continue
		
		health_component = child as HealthComponent
		return
	
	push_warning(
		"Hurtbox could not find a HealthComponent on %s."
		% owner_entity.name
	)


############################
##         DAMAGE         ##
############################

#### RECEIVE HIT ####

func receive_hit(
	damage_data: DamageData
) -> float:
	if not can_receive_hit(damage_data):
		hit_blocked.emit(damage_data)
		return 0.0
	
	var damage_received: float = (
		health_component.take_damage(damage_data)
	)
	
	if damage_received <= 0.0:
		return 0.0
	
	hit_received.emit(
		damage_data,
		damage_received
	)
	
	request_knockback(damage_data)
	
	if should_start_invincibility(damage_data):
		start_invincibility()
	
	return damage_received


#### CAN RECEIVE HIT ####

func can_receive_hit(
	damage_data: DamageData
) -> bool:
	if not hurtbox_enabled:
		return false
	
	if damage_data == null:
		return false
	
	if health_component == null:
		return false
	
	if health_component.is_dead():
		return false
	
	if invincible:
		return damage_data.ignores_invincibility
	
	return true


############################
##       KNOCKBACK        ##
############################

#### REQUEST KNOCKBACK ####

func request_knockback(
	damage_data: DamageData
) -> void:
	if not damage_data.has_knockback():
		return
	
	knockback_requested.emit(
		damage_data.get_knockback_vector(),
		damage_data
	)


############################
##      INVINCIBILITY     ##
############################

#### SHOULD START INVINCIBILITY ####

func should_start_invincibility(
	damage_data: DamageData
) -> bool:
	if not use_invincibility_frames:
		return false
	
	if damage_data.ignores_invincibility:
		return false
	
	if invincibility_duration <= 0.0:
		return false
	
	if health_component.is_dead():
		return false
	
	return true


#### START INVINCIBILITY ####

func start_invincibility(
	duration: float = -1.0
) -> void:
	var target_duration: float = duration
	
	if target_duration < 0.0:
		target_duration = invincibility_duration
	
	if target_duration <= 0.0:
		return
	
	invincible = true
	
	invincibility_timer.start(target_duration)
	
	invincibility_started.emit(target_duration)


#### END INVINCIBILITY ####

func end_invincibility() -> void:
	if not invincible:
		return
	
	invincible = false
	
	invincibility_timer.stop()
	
	invincibility_ended.emit()


#### SET INVINCIBLE ####

func set_invincible(
	new_invincible: bool,
	duration: float = -1.0
) -> void:
	if new_invincible:
		start_invincibility(duration)
		return
	
	end_invincibility()


#### IS INVINCIBLE ####

func is_invincible() -> bool:
	return invincible


############################
##     HURTBOX CONTROL    ##
############################

#### SET HURTBOX ENABLED ####

func set_hurtbox_enabled(
	new_enabled: bool
) -> void:
	hurtbox_enabled = new_enabled
	
	set_deferred(
		"monitorable",
		hurtbox_enabled
	)


#### IS HURTBOX ENABLED ####

func is_hurtbox_enabled() -> bool:
	return hurtbox_enabled


#### GET OWNER ENTITY ####

func get_owner_entity() -> Node:
	return owner_entity


############################
##     TIMER CONNECTION   ##
############################

#### CONNECT TIMER ####

func connect_timer() -> void:
	if invincibility_timer.timeout.is_connected(
		end_invincibility
	):
		return
	
	invincibility_timer.timeout.connect(
		end_invincibility
	)
