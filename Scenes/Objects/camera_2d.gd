extends Camera2D

var camera_speed = 200.0


func _physics_process(delta):
	follow_player()

func follow_player():
	global_position.x = lerp(global_position.x, Global.player_position.x, 0.5)
	global_position.y = lerp(global_position.y, Global.player_position.y, 0.02)

func goto_pos(pos):
	global_position = pos
