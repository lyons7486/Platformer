class_name PlayerRifle

extends AimableWeapon


############################
##         SCENES         ##
############################

const BULLET_TOKEN_SCENE: PackedScene = preload(
	"res://Scenes/Entities/Equipment/bullet_token.tscn"
)


############################
##     NODE REFERENCES    ##
############################

@onready var aim_pivot: Marker2D = $AimPivot

@onready var weapon_sprite: AnimatedSprite2D = (
	$AimPivot/WeaponSprite
)

@onready var bullet_spawn_point: Marker2D = (
	$AimPivot/BulletSpawnPoint
)

@onready var muzzle_flash: AnimatedSprite2D = (
	$AimPivot/NuzzleFlash
)

@onready var fire_sound: AudioStreamPlayer2D = $FireSound
@onready var empty_sound: AudioStreamPlayer2D = $EmptySound
@onready var reload_sound: AudioStreamPlayer2D = $ReloadSound

@onready var ammo_canvas: CanvasLayer = $CanvasLayer

@onready var ammo_belt: HBoxContainer = (
	$CanvasLayer/Margin/AmmoBelt
)

@onready var original_bullet_token: TextureRect = (
	$CanvasLayer/Margin/AmmoBelt/BulletToken
)

@onready var ammo_label: Label = (
	$CanvasLayer/Margin/AmmoBelt/AmmoLabel
)


############################
##       RIFLE DATA       ##
############################

@export var projectile_type: Projectile.ProjectileTypes = (
	Projectile.ProjectileTypes.BULLET
)

@export var fire_cooldown: float = 0.2
@export var reload_duration: float = 0.8

@export var magazine_size: int = 20
@export var starting_reserve_ammo: int = 200

@export var automatic_fire: bool = true


############################
##     BURST SETTINGS     ##
############################

@export var burst_fire_enabled: bool = true

@export_range(1, 10, 1)
var burst_size: int = 3

@export_range(0.01, 1.0, 0.01)
var burst_interval: float = 0.10


############################
##      BULLET SPRAY      ##
############################

@export_range(0.0, 45.0, 0.1)
var bullet_spread_degrees: float = 1.0


############################
##         AMMO           ##
############################

var current_ammo: int = 20
var reserve_ammo: int = 80

var reloading: bool = false
var reload_timer: float = 0.0

var ammo_tokens: Array[TextureRect] = []


############################
##      FIRE CONTROL      ##
############################

var can_fire: bool = true
var fire_cooldown_timer: float = 0.0

var burst_active: bool = false
var burst_shots_remaining: int = 0
var burst_shot_timer: float = 0.0


############################
##    AIM POSITIONING     ##
############################

@export var aiming_pivot_offset: Vector2 = Vector2(
	0.0,
	-2.0
)

@export var aim_position_speed: float = 20.0


############################
##   AIM POSITION STATE   ##
############################

var aim_pivot_rest_position: Vector2 = Vector2.ZERO


############################
##       REFERENCES       ##
############################

var scene_handler: SceneHandler


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	aim_pivot_rest_position = aim_pivot.position
	
	get_references()
	setup_rifle()
	connect_animation_signals()


#### PHYSICS PROCESS ####

func _physics_process(delta: float) -> void:
	if player == null:
		return
	
	update_aim_pivot_position(delta)
	update_weapon_animation()
	
	if not player.is_local_player():
		return
	
	update_reload(delta)
	update_burst_fire(delta)
	update_fire_cooldown(delta)
	
	handle_reload_input()
	handle_fire_input()


############################
##       REFERENCES       ##
############################

#### GET REFERENCES ####

func get_references() -> void:
	var owner_player: PlatformPlayer = (
		get_parent().get_parent()
		as PlatformPlayer
	)
	
	setup_aimable_weapon(
		owner_player
	)
	
	scene_handler = (
		get_tree().current_scene
		as SceneHandler
	)
	
	if scene_handler != null:
		return
	
	scene_handler = get_tree().get_first_node_in_group(
		"scene_handler"
	) as SceneHandler


############################
##         SETUP          ##
############################

#### SETUP RIFLE ####

func setup_rifle() -> void:
	current_ammo = magazine_size
	reserve_ammo = starting_reserve_ammo
	
	if player == null:
		ammo_canvas.visible = false
		return
	
	ammo_canvas.visible = player.is_local_player()
	muzzle_flash.visible = false
	
	build_ammo_tokens()
	update_ammo_ui()
	
	play_weapon_animation(&"Idle")


#### CONNECT ANIMATION SIGNALS ####

func connect_animation_signals() -> void:
	if not muzzle_flash.animation_finished.is_connected(
		muzzle_flash_finished
	):
		muzzle_flash.animation_finished.connect(
			muzzle_flash_finished
		)


############################
##         INPUT          ##
############################

#### HANDLE FIRE INPUT ####

func handle_fire_input() -> void:
	if not player.controls:
		return
	
	if reloading:
		return
	
	if player_is_running():
		return
	
	if burst_fire_enabled:
		if not Input.is_action_just_pressed(
			"player_primary_action"
		):
			return
		
		try_start_burst()
		return
	
	if automatic_fire:
		if not Input.is_action_pressed(
			"player_primary_action"
		):
			return
	else:
		if not Input.is_action_just_pressed(
			"player_primary_action"
		):
			return
	
	try_fire_rifle()


#### HANDLE RELOAD INPUT ####

func handle_reload_input() -> void:
	if not player.controls:
		return
	
	if not Input.is_action_just_pressed(
		"player_reload"
	):
		return
	
	start_reload()


############################
##         FIRING         ##
############################

#### TRY FIRE RIFLE ####

func try_fire_rifle() -> void:
	if not can_fire:
		return
	
	if current_ammo <= 0:
		handle_empty_magazine()
		return
	
	if scene_handler == null:
		return
	
	fire_rifle()
	start_fire_cooldown()
	
	if current_ammo <= 0 and reserve_ammo > 0:
		start_reload()


#### FIRE RIFLE ####

func fire_rifle() -> void:
	if current_ammo <= 0:
		return
	
	if scene_handler == null:
		return
	
	current_ammo -= 1
	
	var projectile_direction: Vector2 = (
		get_projectile_direction()
	)
	
	scene_handler.request_rifle_projectile(
		bullet_spawn_point.global_position,
		projectile_direction,
		player.get_peer_id(),
		projectile_type
	)
	
	play_fire_effects()
	update_ammo_ui()


############################
##      BURST FIRE        ##
############################

#### TRY START BURST ####

func try_start_burst() -> void:
	if burst_active:
		return
	
	if not can_fire:
		return
	
	if current_ammo <= 0:
		handle_empty_magazine()
		return
	
	if scene_handler == null:
		return
	
	burst_active = true
	
	burst_shots_remaining = mini(
		burst_size,
		current_ammo
	)
	
	burst_shot_timer = 0.0
	can_fire = false
	
	fire_next_burst_shot()


#### UPDATE BURST FIRE ####

func update_burst_fire(
	delta: float
) -> void:
	if not burst_active:
		return
	
	if should_cancel_burst():
		finish_burst()
		return
	
	burst_shot_timer -= delta
	
	if burst_shot_timer > 0.0:
		return
	
	fire_next_burst_shot()


#### FIRE NEXT BURST SHOT ####

func fire_next_burst_shot() -> void:
	if not burst_active:
		return
	
	if burst_shots_remaining <= 0:
		finish_burst()
		return
	
	if current_ammo <= 0:
		finish_burst()
		return
	
	fire_rifle()
	
	burst_shots_remaining -= 1
	
	if burst_shots_remaining <= 0:
		finish_burst()
		return
	
	if current_ammo <= 0:
		finish_burst()
		return
	
	burst_shot_timer = burst_interval


#### SHOULD CANCEL BURST ####

func should_cancel_burst() -> bool:
	if player == null:
		return true
	
	if not player.controls:
		return true
	
	if reloading:
		return true
	
	if player_is_running():
		return true
	
	if scene_handler == null:
		return true
	
	return false


#### FINISH BURST ####

func finish_burst() -> void:
	if not burst_active:
		return
	
	burst_active = false
	burst_shots_remaining = 0
	burst_shot_timer = 0.0
	
	start_fire_cooldown()
	
	if current_ammo <= 0 and reserve_ammo > 0:
		start_reload()


#### GET PROJECTILE DIRECTION ####

func get_projectile_direction() -> Vector2:
	var base_direction: Vector2 = (
		get_aim_direction()
	)
	
	var spread_angle: float = deg_to_rad(
		randf_range(
			-bullet_spread_degrees,
			bullet_spread_degrees
		)
	)
	
	return base_direction.rotated(
		spread_angle
	).normalized()


#### HANDLE EMPTY MAGAZINE ####

func handle_empty_magazine() -> void:
	start_fire_cooldown()
	
	fire_empty_sound()
	
	if reserve_ammo > 0:
		start_reload()


#### FIRE EMPTY SOUND ####

func fire_empty_sound() -> void:
	if empty_sound.stream == null:
		return
	
	empty_sound.play()


#### START FIRE COOLDOWN ####

func start_fire_cooldown() -> void:
	can_fire = false
	fire_cooldown_timer = fire_cooldown


#### UPDATE FIRE COOLDOWN ####

func update_fire_cooldown(
	delta: float
) -> void:
	if burst_active:
		return
	
	if can_fire:
		return
	
	fire_cooldown_timer -= delta
	
	if fire_cooldown_timer > 0.0:
		return
	
	fire_cooldown_timer = 0.0
	can_fire = true


############################
##        RELOADING       ##
############################

#### START RELOAD ####

func start_reload() -> void:
	if burst_active:
		return
	
	if reloading:
		return
	
	if current_ammo >= magazine_size:
		return
	
	if reserve_ammo <= 0:
		return
	
	reloading = true
	reload_timer = reload_duration
	
	play_reload_sound()
	play_reload_animation.rpc(reload_duration)
	update_ammo_ui()


#### PLAY RELOAD ANIMATION ####

@rpc("authority", "call_local", "reliable")
func play_reload_animation(
	target_duration: float
) -> void:
	clear_aim_state()
	
	play_timed_weapon_animation(
		&"Reload",
		target_duration
	)


#### PLAY RELOAD SOUND ####

func play_reload_sound() -> void:
	if reload_sound.stream == null:
		return
	
	reload_sound.play()


#### UPDATE RELOAD ####

func update_reload(delta: float) -> void:
	if not reloading:
		return
	
	reload_timer -= delta
	
	if reload_timer > 0.0:
		return
	
	finish_reload()


#### FINISH RELOAD ####

func finish_reload() -> void:
	var missing_ammo: int = magazine_size - current_ammo
	
	var ammo_to_load: int = mini(
		missing_ammo,
		reserve_ammo
	)
	
	current_ammo += ammo_to_load
	reserve_ammo -= ammo_to_load
	
	reloading = false
	reload_timer = 0.0
	
	update_ammo_ui()


############################
##       FIRE EFFECTS     ##
############################

#### PLAY FIRE EFFECTS ####

func play_fire_effects() -> void:
	play_fire_animation.rpc(fire_cooldown)
	play_fire_sound()
	play_muzzle_flash.rpc(fire_cooldown)


#### PLAY FIRE ANIMATION ####

@rpc("authority", "call_local", "unreliable")
func play_fire_animation(
	target_duration: float
) -> void:
	play_timed_weapon_animation(
		&"Fire",
		target_duration
	)


#### PLAY MUZZLE FLASH ####

@rpc("authority", "call_local", "unreliable")
func play_muzzle_flash(
	target_duration: float
) -> void:
	if muzzle_flash.sprite_frames == null:
		return
	
	var animation_name: StringName = (
		get_muzzle_flash_animation_name()
	)
	
	if animation_name.is_empty():
		return
	
	var animation_duration: float = (
		get_animated_sprite_duration(
			muzzle_flash,
			animation_name
		)
	)
	
	var animation_speed: float = 1.0
	
	if animation_duration > 0.0:
		var safe_target_duration: float = maxf(
			target_duration,
			0.01
		)
		
		animation_speed = (
			animation_duration
			/ safe_target_duration
		)
	
	muzzle_flash.visible = true
	muzzle_flash.speed_scale = animation_speed
	muzzle_flash.play(animation_name)


#### GET MUZZLE FLASH ANIMATION NAME ####

func get_muzzle_flash_animation_name() -> StringName:
	if muzzle_flash.sprite_frames.has_animation(&"Flash"):
		return &"Flash"
	
	var animation_names: PackedStringArray = (
		muzzle_flash.sprite_frames.get_animation_names()
	)
	
	if animation_names.is_empty():
		return &""
	
	return StringName(animation_names[0])


#### PLAY FIRE SOUND ####

func play_fire_sound() -> void:
	if fire_sound.stream == null:
		return
	
	fire_sound.play()


#### MUZZLE FLASH FINISHED ####

func muzzle_flash_finished() -> void:
	muzzle_flash.visible = false
	muzzle_flash.speed_scale = 1.0


############################
##       AIM CHECKS       ##
############################

#### CAN AIM ####

func can_aim() -> bool:
	if not super.can_aim():
		return false
	
	if reloading:
		return false
	
	return true


############################
##    AIM POSITIONING     ##
############################

#### UPDATE AIM PIVOT POSITION ####

func update_aim_pivot_position(
	delta: float
) -> void:
	if aim_pivot == null:
		return
	
	var target_position: Vector2 = (
		aim_pivot_rest_position
	)
	
	var use_aiming_position: bool = (
		is_aiming()
		and not weapon_is_reloading_visually()
	)
	
	if use_aiming_position:
		target_position += aiming_pivot_offset
	
	var movement_weight: float = clampf(
		aim_position_speed * delta,
		0.0,
		1.0
	)
	
	aim_pivot.position = aim_pivot.position.lerp(
		target_position,
		movement_weight
	)


############################
##       AIM VISUALS      ##
############################

#### APPLY AIM VISUALS ####

func apply_aim_visuals() -> void:
	if aim_pivot == null:
		return
	
	if weapon_is_reloading_visually():
		aim_pivot.rotation = 0.0
	else:
		aim_pivot.rotation = get_visual_aim_rotation()
	
	var facing_left: bool = (
		get_facing_direction() < 0.0
	)
	
	weapon_sprite.flip_h = facing_left
	muzzle_flash.flip_h = facing_left
	
	position_rifle_markers()


#### POSITION RIFLE MARKERS ####

func position_rifle_markers() -> void:
	var horizontal_direction: float = (
		get_facing_direction()
	)
	
	bullet_spawn_point.position.x = (
		absf(bullet_spawn_point.position.x)
		* horizontal_direction
	)
	
	muzzle_flash.position.x = (
		absf(muzzle_flash.position.x)
		* horizontal_direction
	)


#### GET AIM ORIGIN GLOBAL POSITION ####

func get_aim_origin_global_position() -> Vector2:
	if aim_pivot == null:
		return global_position
	
	return aim_pivot.global_position


############################
##     WEAPON ANIMATION   ##
############################

#### WEAPON IS RELOADING VISUALLY ####

func weapon_is_reloading_visually() -> bool:
	if weapon_sprite.animation != &"Reload":
		return false
	
	return weapon_sprite.is_playing()


#### UPDATE WEAPON ANIMATION ####

func update_weapon_animation() -> void:
	if weapon_animation_is_locked():
		return
	
	var animation_name: StringName = (
		get_base_weapon_animation()
	)
	
	play_weapon_animation(animation_name)


#### WEAPON ANIMATION IS LOCKED ####

func weapon_animation_is_locked() -> bool:
	if weapon_sprite.animation == &"Fire":
		return weapon_sprite.is_playing()
	
	if weapon_sprite.animation == &"Reload":
		return weapon_sprite.is_playing()
	
	return false


#### GET BASE WEAPON ANIMATION ####

func get_base_weapon_animation() -> StringName:
	if not player.is_on_floor():
		return &"Idle"
	
	if player.player_sprite.animation == &"Run":
		return &"Moving"
	
	return &"Idle"


#### PLAY WEAPON ANIMATION ####

func play_weapon_animation(
	animation_name: StringName,
	restart_animation: bool = false,
	animation_speed: float = 1.0
) -> void:
	if weapon_sprite.sprite_frames == null:
		return
	
	if not weapon_sprite.sprite_frames.has_animation(
		animation_name
	):
		return
	
	if not restart_animation:
		if weapon_sprite.animation == animation_name:
			if weapon_sprite.is_playing():
				return
	
	weapon_sprite.speed_scale = animation_speed
	weapon_sprite.play(animation_name)


#### PLAY TIMED WEAPON ANIMATION ####

func play_timed_weapon_animation(
	animation_name: StringName,
	target_duration: float
) -> void:
	var animation_duration: float = (
		get_animated_sprite_duration(
			weapon_sprite,
			animation_name
		)
	)
	
	var animation_speed: float = 1.0
	
	if animation_duration > 0.0:
		var safe_target_duration: float = maxf(
			target_duration,
			0.01
		)
		
		animation_speed = (
			animation_duration
			/ safe_target_duration
		)
	
	play_weapon_animation(
		animation_name,
		true,
		animation_speed
	)


#### GET ANIMATED SPRITE DURATION ####

func get_animated_sprite_duration(
	animated_sprite: AnimatedSprite2D,
	animation_name: StringName
) -> float:
	if animated_sprite.sprite_frames == null:
		return 0.0
	
	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		return 0.0
	
	var animation_fps: float = (
		animated_sprite.sprite_frames.get_animation_speed(
			animation_name
		)
	)
	
	if animation_fps <= 0.0:
		return 0.0
	
	var frame_count: int = (
		animated_sprite.sprite_frames.get_frame_count(
			animation_name
		)
	)
	
	var total_frame_duration: float = 0.0
	
	for frame_index: int in range(frame_count):
		total_frame_duration += (
			animated_sprite.sprite_frames.get_frame_duration(
				animation_name,
				frame_index
			)
		)
	
	return total_frame_duration / animation_fps


############################
##     PLAYER MOVEMENT    ##
############################

#### PLAYER IS RUNNING ####

func player_is_running() -> bool:
	if is_aiming():
		return false
	
	return player.run_pressed


############################
##        AMMO UI         ##
############################

#### BUILD AMMO TOKENS ####

func build_ammo_tokens() -> void:
	ammo_tokens.clear()
	original_bullet_token.visible = false
	
	for token_index: int in range(magazine_size):
		var new_token: TextureRect = (
			BULLET_TOKEN_SCENE.instantiate()
			as TextureRect
		)
		
		ammo_belt.add_child(new_token)
		ammo_tokens.append(new_token)
	
	ammo_belt.move_child(
		ammo_label,
		ammo_belt.get_child_count() - 1
	)


#### UPDATE AMMO UI ####

func update_ammo_ui() -> void:
	update_ammo_tokens()
	update_ammo_label()


#### UPDATE AMMO TOKENS ####

func update_ammo_tokens() -> void:
	for token_index: int in range(ammo_tokens.size()):
		var token: TextureRect = ammo_tokens[token_index]
		
		token.visible = token_index < current_ammo


#### UPDATE AMMO LABEL ####

func update_ammo_label() -> void:
	if reloading:
		ammo_label.text = "Reloading"
		return
	
	ammo_label.text = "Reserve: %d" % reserve_ammo
