class_name HealthComponent

extends Node


############################
##         SIGNALS        ##
############################

signal health_changed(
	current_health: float,
	maximum_health: float
)

signal damaged(
	damage_data: DamageData,
	damage_received: float,
	current_health: float
)

signal healed(
	healing_received: float,
	current_health: float
)

signal died(
	damage_data: DamageData
)


############################
##      HEALTH SETTINGS   ##
############################

@export var maximum_health: float = 100.0
@export var start_at_full_health: bool = true
@export var starting_health: float = 100.0


############################
##       HEALTH STATE     ##
############################

var current_health: float = 0.0
var dead: bool = false


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	initialize_health()


#### INITIALIZE HEALTH ####

func initialize_health() -> void:
	maximum_health = maxf(maximum_health, 1.0)
	
	if start_at_full_health:
		current_health = maximum_health
	else:
		current_health = clampf(
			starting_health,
			0.0,
			maximum_health
		)
	
	dead = current_health <= 0.0


############################
##         DAMAGE         ##
############################

#### TAKE DAMAGE ####

func take_damage(
	damage_data: DamageData
) -> float:
	if damage_data == null:
		return 0.0
	
	if dead:
		return 0.0
	
	var requested_damage: float = calculate_damage_amount(
		damage_data
	)
	
	if requested_damage <= 0.0:
		return 0.0
	
	var previous_health: float = current_health
	
	current_health = maxf(
		current_health - requested_damage,
		0.0
	)
	
	var damage_received: float = (
		previous_health - current_health
	)
	
	if damage_received <= 0.0:
		return 0.0
	
	damaged.emit(
		damage_data,
		damage_received,
		current_health
	)
	
	emit_health_changed()
	
	if current_health <= 0.0:
		handle_death(damage_data)
	
	return damage_received


#### CALCULATE DAMAGE AMOUNT ####

func calculate_damage_amount(
	damage_data: DamageData
) -> float:
	return maxf(damage_data.amount, 0.0)


############################
##         HEALING        ##
############################

#### HEAL ####

func heal(healing_amount: float) -> float:
	if dead:
		return 0.0
	
	if healing_amount <= 0.0:
		return 0.0
	
	if is_full_health():
		return 0.0
	
	var previous_health: float = current_health
	
	current_health = minf(
		current_health + healing_amount,
		maximum_health
	)
	
	var healing_received: float = (
		current_health - previous_health
	)
	
	if healing_received <= 0.0:
		return 0.0
	
	healed.emit(
		healing_received,
		current_health
	)
	
	emit_health_changed()
	
	return healing_received


############################
##          DEATH         ##
############################

#### HANDLE DEATH ####

func handle_death(
	damage_data: DamageData
) -> void:
	if dead:
		return
	
	dead = true
	
	died.emit(damage_data)


#### IS DEAD ####

func is_dead() -> bool:
	return dead


############################
##      HEALTH CONTROL    ##
############################

#### RESET HEALTH ####

func reset_health(
	new_health: float = -1.0
) -> void:
	if new_health < 0.0:
		current_health = maximum_health
	else:
		current_health = clampf(
			new_health,
			0.0,
			maximum_health
		)
	
	dead = current_health <= 0.0
	
	emit_health_changed()


#### SET MAXIMUM HEALTH ####

func set_maximum_health(
	new_maximum_health: float,
	refill_health: bool = false
) -> void:
	maximum_health = maxf(
		new_maximum_health,
		1.0
	)
	
	if refill_health:
		current_health = maximum_health
	else:
		current_health = minf(
			current_health,
			maximum_health
		)
	
	dead = current_health <= 0.0
	
	emit_health_changed()


############################
##      HEALTH CHECKS     ##
############################

#### IS FULL HEALTH ####

func is_full_health() -> bool:
	return is_equal_approx(
		current_health,
		maximum_health
	)


#### GET HEALTH PERCENT ####

func get_health_percent() -> float:
	if maximum_health <= 0.0:
		return 0.0
	
	return clampf(
		current_health / maximum_health,
		0.0,
		1.0
	)


############################
##       HEALTH SIGNAL    ##
############################

#### EMIT HEALTH CHANGED ####

func emit_health_changed() -> void:
	health_changed.emit(
		current_health,
		maximum_health
	)
