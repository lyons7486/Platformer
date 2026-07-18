extends Node2D

var fade_timer = 3

# Text Variables #
var text = "Blank"
var text_color : Color
var text_scale = 1.0

func _ready():
	scale = Vector2(text_scale,text_scale)
	$Label.text = text
	modulate = text_color
	$Timer.start(fade_timer)

func _physics_process(delta):
	global_position.y -= 1
	modulate.a = $Timer.time_left / fade_timer
	if modulate.a <= 0.01:
		queue_free()
