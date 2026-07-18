extends Area2D

#### NODE REFERENCES ####
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

#### VARIABLES ####
var coin_value: int = 1

#### READY ####
func _ready() -> void:
	animated_sprite.play("Idle")

#### COIN COLLECT ####
func coin_collect(body: Node2D) -> void:
	# If coin has been collected, end function here
	if animated_sprite.animation == "Collect":
		return
	
	var body_sprite_type = body.get("sprite_type")
	
	# If sprite type is null, end function here
	if body_sprite_type == null:
		return
	
	if body_sprite_type == "player":
		coin_added(body)
		
		animated_sprite.play("Collect")
		await animated_sprite.animation_finished
		
		remove_coin()

#### COIN ADDED ####
func coin_added(body: Node2D) -> void:
	get_node("/root/Game").add_coin(coin_value)
	
	var float_text = load("res://Nodes/Sprites/float_text.tscn").instantiate()
	float_text.text = "+" + str(coin_value)
	float_text.text_color = Color(1, 1, 0, 1)
	float_text.global_position = global_position + Vector2(0, -5)
	
	body.get_parent().add_child(float_text)

#### REMOVE COIN ####
func remove_coin() -> void:
	queue_free()
