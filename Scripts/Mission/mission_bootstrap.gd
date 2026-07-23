class_name MissionBootstrap

extends Node


############################
##     MISSION SETTINGS   ##
############################

@export var mission_id: StringName = &"debug_mission"
@export var begin_mission_on_ready: bool = true


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	if not begin_mission_on_ready:
		return
	
	if not multiplayer.is_server():
		return
	
	call_deferred(
		"begin_level_mission"
	)


#### BEGIN LEVEL MISSION ####

func begin_level_mission() -> void:
	if not multiplayer.is_server():
		return
	
	MissionManager.begin_mission(
		mission_id
	)
