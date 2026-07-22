class_name AimableWeapon

extends Node2D


############################
##      AIM SETTINGS      ##
############################

@export var aim_input_action: StringName = &"player_aim"

@export_range(0.0, 89.0, 1.0)
var maximum_aim_angle_degrees: float = 45.0

@export_range(0.0, 1.0, 0.05)
var aim_forward_speed_multiplier: float = 0.8

@export_range(0.0, 1.0, 0.05)
var aim_backward_speed_multiplier: float = 0.5

@export_range(0.0, 16.0, 0.5)
var aim_horizontal_deadzone: float = 2.0


############################
##       AIM STATE        ##
############################

var aiming: bool = false

var aim_direction: Vector2 = Vector2.RIGHT
var facing_direction: float = 1.0


############################
##      NETWORK STATE     ##
############################

@export var network_aiming: bool = false

@export var network_aim_direction: Vector2 = (
	Vector2.RIGHT
)


############################
##       REFERENCES       ##
############################

var player: PlatformPlayer = null


############################
##         SETUP          ##
############################

#### SETUP AIMABLE WEAPON ####

func setup_aimable_weapon(
	new_player: PlatformPlayer
) -> void:
	player = new_player
	
	reset_aim_direction()
	
	network_aiming = aiming
	network_aim_direction = aim_direction
	
	if player != null:
		player.register_aimable_weapon(self)
	
	apply_aim_visuals()


############################
##      AIM PROCESSING    ##
############################

#### UPDATE AIM STATE ####

func update_aim_state() -> void:
	if player == null:
		return
	
	if player.is_local_player():
		update_local_aim_state()
	else:
		apply_network_aim_state()
	
	apply_aim_visuals()


#### UPDATE LOCAL AIM STATE ####

func update_local_aim_state() -> void:
	aiming = (
		can_aim()
		and Input.is_action_pressed(
			aim_input_action
		)
	)
	
	if not aiming:
		reset_aim_direction()
		update_network_aim_state()
		return
	
	var mouse_offset: Vector2 = (
		get_global_mouse_position()
		- global_position
	)
	
	if mouse_offset.is_zero_approx():
		update_network_aim_state()
		return
	
	update_aim_facing_direction(
		mouse_offset
	)
	
	aim_direction = get_clamped_aim_direction(
		mouse_offset.normalized()
	)
	
	update_network_aim_state()


#### APPLY NETWORK AIM STATE ####

func apply_network_aim_state() -> void:
	aiming = network_aiming
	aim_direction = network_aim_direction
	
	if aim_direction.is_zero_approx():
		reset_aim_direction()
		return
	
	if absf(aim_direction.x) > 0.001:
		facing_direction = signf(
			aim_direction.x
		)


#### UPDATE NETWORK AIM STATE ####

func update_network_aim_state() -> void:
	if player == null:
		return
	
	if not player.is_local_player():
		return
	
	network_aiming = aiming
	network_aim_direction = aim_direction


############################
##      AIM DIRECTION     ##
############################

#### UPDATE AIM FACING DIRECTION ####

func update_aim_facing_direction(
	mouse_offset: Vector2
) -> void:
	if absf(mouse_offset.x) <= aim_horizontal_deadzone:
		return
	
	facing_direction = signf(
		mouse_offset.x
	)


#### GET CLAMPED AIM DIRECTION ####

func get_clamped_aim_direction(
	raw_direction: Vector2
) -> Vector2:
	var local_direction: Vector2 = Vector2(
		absf(raw_direction.x),
		raw_direction.y
	)
	
	var maximum_angle: float = deg_to_rad(
		maximum_aim_angle_degrees
	)
	
	var clamped_angle: float = clampf(
		local_direction.angle(),
		-maximum_angle,
		maximum_angle
	)
	
	return Vector2(
		cos(clamped_angle) * facing_direction,
		sin(clamped_angle)
	).normalized()


#### RESET AIM DIRECTION ####

func reset_aim_direction() -> void:
	if player != null:
		if player.player_sprite.flip_h:
			facing_direction = -1.0
		else:
			facing_direction = 1.0
	
	aim_direction = Vector2(
		facing_direction,
		0.0
	)


#### CLEAR AIM STATE ####

func clear_aim_state() -> void:
	aiming = false
	
	reset_aim_direction()
	update_network_aim_state()
	apply_aim_visuals()


############################
##       AIM CHECKS       ##
############################

#### CAN AIM ####

func can_aim() -> bool:
	if player == null:
		return false
	
	if not player.controls:
		return false
	
	if player.dead:
		return false
	
	if player.dying:
		return false
	
	if player.death_pending:
		return false
	
	return true


#### IS AIMING ####

func is_aiming() -> bool:
	return aiming


#### GET AIM DIRECTION ####

func get_aim_direction() -> Vector2:
	if aim_direction.is_zero_approx():
		return Vector2(
			get_facing_direction(),
			0.0
		)
	
	return aim_direction.normalized()


#### GET FACING DIRECTION ####

func get_facing_direction() -> float:
	if absf(facing_direction) < 0.001:
		return 1.0
	
	return signf(facing_direction)


############################
##     AIM MOVEMENT       ##
############################

#### GET AIM MOVEMENT MULTIPLIER ####

func get_aim_movement_multiplier(
	movement_direction: float
) -> float:
	if not aiming:
		return 1.0
	
	if is_zero_approx(movement_direction):
		return 1.0
	
	if movement_direction * facing_direction > 0.0:
		return aim_forward_speed_multiplier
	
	return aim_backward_speed_multiplier


############################
##      AIM VISUALS       ##
############################

#### GET VISUAL AIM ROTATION ####

func get_visual_aim_rotation() -> float:
	var current_direction: Vector2 = (
		get_aim_direction()
	)
	
	var local_direction: Vector2 = Vector2(
		absf(current_direction.x),
		current_direction.y
	)
	
	return (
		local_direction.angle()
		* facing_direction
	)


#### APPLY AIM VISUALS ####

func apply_aim_visuals() -> void:
	
	# Override this function in each weapon.
	# Different weapons may rotate differently,
	# use different pivots, or use custom animations.
	
	pass
