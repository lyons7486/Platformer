class_name DebugLevel

extends Level


############################
##     NODE REFERENCES    ##
############################

@onready var spawn_point: Marker2D = $Objects/SpawnPoint


############################
##     LEVEL POSITION     ##
############################

#### PLAYER SPAWN ####

func get_spawn_position() -> Vector2:
	if spawn_point == null:
		return global_position
	
	return spawn_point.global_position


############################
##        RESPAWN         ##
############################

#### RESPAWN BODY ####

func respawn(body: Node) -> void:
	if not multiplayer.is_server():
		return
	
	if body.has_method("respawn"):
		body.respawn()
		return
	
	if body.has_method("remove_self"):
		body.remove_self()
