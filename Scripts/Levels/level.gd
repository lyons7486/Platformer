class_name Level

extends Node2D


############################
##     SPAWN SETTINGS     ##
############################

@export var player_spawn_spacing: float = 32.0


############################
##     LEVEL POSITION     ##
############################

#### PLAYER SPAWN ####

## BASE POSITION ##

func get_spawn_position() -> Vector2:
	return global_position


## INDEXED POSITION ##

func get_player_spawn_position(player_index: int) -> Vector2:
	var base_position: Vector2 = get_spawn_position()
	
	return base_position + Vector2(
		player_index * player_spawn_spacing,
		0.0
	)
