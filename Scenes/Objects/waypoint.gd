class_name Waypoint

extends Area2D


############################
##     NODE REFERENCES    ##
############################

@onready var animated_sprite: AnimatedSprite2D = (
	$AnimatedSprite2D
)


############################
##    WAYPOINT SETTINGS   ##
############################

@export_range(1, 100, 1)
var waypoint_id: int = 1


############################
##     WAYPOINT STATE     ##
############################

var local_player_reached: bool = false
var reach_request_sent: bool = false

var team_secured: bool = false
var activation_animation_active: bool = false


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	connect_mission_signals()
	
	animated_sprite.play(&"Off")
	
	call_deferred(
		"refresh_waypoint_state"
	)


############################
##     SIGNAL SETUP       ##
############################

#### CONNECT MISSION SIGNALS ####

func connect_mission_signals() -> void:
	if not MissionManager.roster_changed.is_connected(
		mission_roster_changed
	):
		MissionManager.roster_changed.connect(
			mission_roster_changed
		)
	
	if not MissionManager.team_waypoint_secured.is_connected(
		team_waypoint_was_secured
	):
		MissionManager.team_waypoint_secured.connect(
			team_waypoint_was_secured
		)


############################
##     BODY DETECTION     ##
############################

#### BODY ENTERED ####

func waypoint_set(
	body: Node2D
) -> void:
	if not body is PlatformPlayer:
		return
	
	var player: PlatformPlayer = (
		body as PlatformPlayer
	)
	
	if not player.is_multiplayer_authority():
		return
	
	if player.dead:
		return
	
	if player.dying:
		return
	
	if player.death_pending:
		return
	
	if local_player_has_reached_waypoint():
		return
	
	if reach_request_sent:
		return
	
	reach_waypoint_for_local_player(
		player
	)


#### LOCAL PLAYER HAS REACHED WAYPOINT ####

func local_player_has_reached_waypoint() -> bool:
	if local_player_reached:
		return true
	
	if not MissionManager.mission_active:
		return false
	
	var local_peer_id: int = (
		multiplayer.get_unique_id()
	)
	
	return MissionManager.has_player_reached_waypoint(
		local_peer_id,
		waypoint_id
	)


#### REACH WAYPOINT FOR LOCAL PLAYER ####

func reach_waypoint_for_local_player(
	player: PlatformPlayer
) -> void:
	reach_request_sent = true
	local_player_reached = true
	
	player.set_respawn_position(
		global_position
	)
	
	play_activation_animation()
	
	if multiplayer.is_server():
		MissionManager.mark_player_waypoint_by_peer(
			player.get_peer_id(),
			waypoint_id,
			global_position
		)
		
		return
	
	request_waypoint_reached.rpc_id(1)


############################
##    NETWORK REPORTING   ##
############################

#### REQUEST WAYPOINT REACHED ####

@rpc("any_peer", "call_remote", "reliable", 3)
func request_waypoint_reached() -> void:
	if not multiplayer.is_server():
		return
	
	var sender_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)
	
	if sender_peer_id <= 0:
		return
	
	MissionManager.mark_player_waypoint_by_peer(
		sender_peer_id,
		waypoint_id,
		global_position
	)


############################
##     STATE REFRESH      ##
############################

#### MISSION ROSTER CHANGED ####

func mission_roster_changed() -> void:
	refresh_waypoint_state()


#### REFRESH WAYPOINT STATE ####

func refresh_waypoint_state() -> void:
	if not MissionManager.mission_active:
		return
	
	var local_peer_id: int = (
		multiplayer.get_unique_id()
	)
	
	var player_has_reached: bool = (
		MissionManager.has_player_reached_waypoint(
			local_peer_id,
			waypoint_id
		)
	)
	
	if player_has_reached:
		local_player_reached = true
		reach_request_sent = false
		
		play_activation_animation()
	
	var waypoint_is_team_secured: bool = (
		MissionManager.is_team_waypoint_secured(
			waypoint_id
		)
	)
	
	if waypoint_is_team_secured:
		apply_team_secured()


############################
##    TEAM COMPLETION     ##
############################

#### TEAM WAYPOINT WAS SECURED ####

func team_waypoint_was_secured(
	secured_waypoint_id: int
) -> void:
	if secured_waypoint_id != waypoint_id:
		return
	
	apply_team_secured()


#### APPLY TEAM SECURED ####

func apply_team_secured() -> void:
	if team_secured:
		return
	
	team_secured = true
	
	## Do not set local_player_reached here.
	## Team completion and personal progress are separate.
	
	play_activation_animation()


############################
##       ANIMATION        ##
############################

#### PLAY ACTIVATION ####

func play_activation_animation() -> void:
	if activation_animation_active:
		return
	
	if animated_sprite.animation == &"On":
		return
	
	activation_animation_active = true
	
	animated_sprite.play(&"Hoist")
	
	await animated_sprite.animation_finished
	
	animated_sprite.play(&"On")
	
	activation_animation_active = false
