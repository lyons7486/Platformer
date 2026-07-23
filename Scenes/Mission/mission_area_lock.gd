class_name MissionAreaLock

extends StaticBody2D


############################
##     NODE REFERENCES    ##
############################

@export var lock_visual: CanvasItem
@export var lock_collision: CollisionShape2D


############################
##       LOCK SETTINGS    ##
############################

@export_range(1, 1000, 1)
var activate_on_waypoint_id: int = 1

@export var begin_locked: bool = false


############################
##        LOCK STATE      ##
############################

var is_locked: bool = false


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	connect_mission_signals()
	
	set_lock_active(
		begin_locked
	)
	
	call_deferred(
		"refresh_lock_state"
	)


#### EXIT TREE ####

func _exit_tree() -> void:
	disconnect_mission_signals()


############################
##    SIGNAL CONNECTIONS  ##
############################

#### CONNECT MISSION SIGNALS ####

func connect_mission_signals() -> void:
	if not MissionManager.team_waypoint_secured.is_connected(
		on_team_waypoint_secured
	):
		MissionManager.team_waypoint_secured.connect(
			on_team_waypoint_secured
		)
	
	if not MissionManager.roster_changed.is_connected(
		refresh_lock_state
	):
		MissionManager.roster_changed.connect(
			refresh_lock_state
		)


#### DISCONNECT MISSION SIGNALS ####

func disconnect_mission_signals() -> void:
	if MissionManager.team_waypoint_secured.is_connected(
		on_team_waypoint_secured
	):
		MissionManager.team_waypoint_secured.disconnect(
			on_team_waypoint_secured
		)
	
	if MissionManager.roster_changed.is_connected(
		refresh_lock_state
	):
		MissionManager.roster_changed.disconnect(
			refresh_lock_state
		)


############################
##      LOCK UPDATES      ##
############################

#### TEAM WAYPOINT SECURED ####

func on_team_waypoint_secured(
	secured_waypoint_id: int
) -> void:
	if secured_waypoint_id < activate_on_waypoint_id:
		return
	
	set_lock_active(true)


#### REFRESH LOCK STATE ####

func refresh_lock_state() -> void:
	if begin_locked:
		set_lock_active(true)
		return
	
	var should_be_locked: bool = (
		MissionManager.highest_team_secured_waypoint_id
		>= activate_on_waypoint_id
	)
	
	set_lock_active(
		should_be_locked
	)


#### SET LOCK ACTIVE ####

func set_lock_active(
	lock_active: bool
) -> void:
	is_locked = lock_active
	
	update_lock_visual()
	update_lock_collision()


#### UPDATE LOCK VISUAL ####

func update_lock_visual() -> void:
	if lock_visual == null:
		return
	
	lock_visual.visible = is_locked


#### UPDATE LOCK COLLISION ####

func update_lock_collision() -> void:
	if lock_collision == null:
		return
	
	lock_collision.set_deferred(
		"disabled",
		not is_locked
	)
