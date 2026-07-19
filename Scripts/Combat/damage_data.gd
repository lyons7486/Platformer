class_name DamageData

extends RefCounted


############################
##      DAMAGE DATA       ##
############################

var amount: float = 0.0
var damage_type: DamageTypes.Type = DamageTypes.Type.GENERIC

var source: Node = null
var source_peer_id: int = 0

var hit_position: Vector2 = Vector2.ZERO

var knockback_direction: Vector2 = Vector2.ZERO
var knockback_strength: float = 0.0

var ignores_invincibility: bool = false

var tags: Array[StringName] = []


############################
##       LIFECYCLE        ##
############################

#### INITIALIZE ####

func _init(
	new_amount: float = 0.0,
	new_damage_type: DamageTypes.Type = DamageTypes.Type.GENERIC,
	new_source: Node = null
) -> void:
	amount = maxf(new_amount, 0.0)
	damage_type = new_damage_type
	source = new_source


############################
##         TAGS           ##
############################

#### ADD TAG ####

func add_tag(tag: StringName) -> void:
	if tags.has(tag):
		return
	
	tags.append(tag)


#### REMOVE TAG ####

func remove_tag(tag: StringName) -> void:
	if not tags.has(tag):
		return
	
	tags.erase(tag)


#### HAS TAG ####

func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


############################
##       KNOCKBACK        ##
############################

#### HAS KNOCKBACK ####

func has_knockback() -> bool:
	if knockback_strength <= 0.0:
		return false
	
	return not knockback_direction.is_zero_approx()


#### GET KNOCKBACK VECTOR ####

func get_knockback_vector() -> Vector2:
	if not has_knockback():
		return Vector2.ZERO
	
	return (
		knockback_direction.normalized()
		* knockback_strength
	)
