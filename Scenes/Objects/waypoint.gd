class_name Waypoint

extends Area2D


############################
##     NODE REFERENCES    ##
############################

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


############################
##     WAYPOINT STATE     ##
############################

var is_activated: bool = false


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	animated_sprite.play("Off")


############################
##     BODY DETECTION     ##
############################

#### BODY ENTERED ####

func waypoint_set(body: Node2D) -> void:
	if not body is PlatformPlayer:
		return
	
	var player: PlatformPlayer = body
	
	if not player.is_multiplayer_authority():
		return
	
	if multiplayer.is_server():
		activate_waypoint()
		return
	
	request_waypoint_activation.rpc_id(1)


############################
##   NETWORK ACTIVATION   ##
############################

#### REQUEST ACTIVATION ####

@rpc("any_peer", "call_remote", "reliable")
func request_waypoint_activation() -> void:
	if not multiplayer.is_server():
		return
	
	activate_waypoint()


#### ACTIVATE WAYPOINT ####

func activate_waypoint() -> void:
	if not multiplayer.is_server():
		return
	
	if is_activated:
		return
	
	is_activated = true
	
	var scene_handler: SceneHandler = get_tree().current_scene as SceneHandler
	
	if scene_handler == null:
		push_error("Waypoint could not find SceneHandler.")
		return
	
	scene_handler.set_shared_waypoint(global_position)
	activate_waypoint_remote.rpc()


#### ACTIVATE REMOTELY ####

@rpc("authority", "call_local", "reliable")
func activate_waypoint_remote() -> void:
	is_activated = true
	play_activation_animation()


############################
##       ANIMATION        ##
############################

#### PLAY ACTIVATION ####

func play_activation_animation() -> void:
	animated_sprite.play("Hoist")
	await animated_sprite.animation_finished
	
	animated_sprite.play("On")
