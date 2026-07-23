extends TextureButton

@export var character_class: String = ""

func _process(delta: float) -> void:
	if character_class == null:
		return
	if character_class == "":
		$AnimatedSprite2D.play("coming_soon")
	elif character_class == "gunner":
		$AnimatedSprite2D.play("class_gunner")
