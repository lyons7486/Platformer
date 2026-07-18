extends Area2D

#### NODE REFERENCES ####
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

#### READY ####
func _ready() -> void:
	animated_sprite.play("Off")

#### ENDPOINT ####
func endpoint_set(body: Node2D) -> void:
	# If endpoint has been triggered, end function here
	if animated_sprite.animation == "On" or animated_sprite.animation == "Tear":
		return
	
	var body_sprite_type = body.get("sprite_type")
	
	# If sprite type is null, end function here
	if body_sprite_type == null:
		return
	
	if body_sprite_type == "player" and animated_sprite.animation == "Off":
		get_parent().get_parent().get_parent().timer = false
		
		Global.player_last_position = global_position
		
		animated_sprite.play("Tear")
		await animated_sprite.animation_finished
		
		animated_sprite.play("On")
