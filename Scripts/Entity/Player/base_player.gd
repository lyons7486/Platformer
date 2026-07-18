class_name BasePlayer
extends CharacterBody2D

#### NODE REFERENCES ####
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var respawn_timer: Timer = $RespawnTimer
@onready var control_timer: Timer = $ControlTimer

#### PLAYER INFO ####
var controls: bool = true
var sprite_type: String = "player"

#### MOVEMENT ####
var speed: float = 120.0
var accel: float = 500.0
var friction: float = 500.0
var air_accel: float = 350.0
var air_friction: float = 80.0
var dash_multi: float = 1.0
var direction: float = 0.0

#### JUMPING ####
var jump_velocity: float = -260.0
var jumped: bool = false
var double_jump_used: bool = false

#### COYOTE TIME ####
var coyote_time: float = 0.15
var coyote_timer: float = 0.0

#### GRAVITY ####
var gravity: Vector2 = Vector2(0, 650)
var gravity_multi: float = 1.0

#### READY ####
func _ready() -> void:
	modulate = Color(0, 0, 0)
	spawn_in()

#### PHYSICS PROCESS ####
func _physics_process(delta: float) -> void:
	Global.player_position = global_position
	
	get_input()
	update_coyote_time(delta)
	handle_jump()
	handle_sprite_direction()
	handle_animation()
	handle_gravity(delta)
	handle_movement(delta)
	
	move_and_slide()

#### INPUT ####
func get_input() -> void:
	direction = 0.0
	
	if controls:
		direction = Input.get_axis("player_left", "player_right")

#### COYOTE TIME ####
func update_coyote_time(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
		jumped = false
		double_jump_used = false
	else:
		coyote_timer -= delta

#### JUMPING ####
func handle_jump() -> void:
	if Input.is_action_just_pressed("player_jump") and controls:
		if coyote_timer > 0.0 and !jumped:
			jumped = true
			coyote_timer = 0.0
			velocity.y = jump_velocity
		elif !double_jump_used:
			double_jump_used = true
			velocity.y = jump_velocity

#### SPRITE DIRECTION ####
func handle_sprite_direction() -> void:
	if direction < 0:
		animated_sprite.flip_h = true
	elif direction > 0:
		animated_sprite.flip_h = false

#### ANIMATION ####
func handle_animation() -> void:
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("Idle")
		else:
			animated_sprite.play("Run")
	else:
		if velocity.y < 0:
			animated_sprite.play("Jump_up")
		else:
			animated_sprite.play("Jump_down")

#### GRAVITY ####
func handle_gravity(delta: float) -> void:
	if is_on_floor():
		return
	
	if velocity.y < 0:
		if Input.is_action_pressed("player_jump"):
			gravity_multi = 1.0
		else:
			gravity_multi = 3.0
	else:
		gravity_multi = 1.8
	
	velocity += gravity * gravity_multi * delta

#### MOVEMENT ####
func handle_movement(delta: float) -> void:
	if direction:
		if Input.is_action_pressed("player_run"):
			dash_multi = 1.5
		else:
			dash_multi = 1.0
		
		var current_accel: float = accel
		
		if !is_on_floor():
			current_accel = air_accel
		
		velocity.x = move_toward(velocity.x, direction * speed * dash_multi, current_accel * delta)
	else:
		var current_friction: float = friction
		
		if !is_on_floor():
			current_friction = air_friction
		
		velocity.x = move_toward(velocity.x, 0, current_friction * delta)

#### DAMAGE ####
func take_hit(tar_loc: Vector2, push: bool) -> void:
	var hit_dir: Vector2 = tar_loc.direction_to(global_position)
	
	if push:
		controls = false
		animation_player.play("Hit")
		control_timer.start(0.25)
		
		velocity = Vector2(hit_dir.x * 180, -180)
	else:
		velocity += Vector2(hit_dir.x * 120, -120)

#### BOUNCE ####
func bounce_hit() -> void:
	velocity.y = jump_velocity * 0.75

#### RESPAWN ####
func respawn() -> void:
	global_position = Global.player_last_position
	spawn_in()

#### SPAWN ####
func spawn_in() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	
	controls = false
	
	animated_sprite.set_frame_and_progress(0, 0)
	animation_player.play("SpawnIn")
	
	respawn_timer.start(0.5)

#### RESPAWN FINISHED ####
func respawn_finished() -> void:
	controls = true

#### CONTROL FINISHED ####
func control_finished() -> void:
	controls = true
