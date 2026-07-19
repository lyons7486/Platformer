class_name DamageTypes

extends RefCounted


############################
##      DAMAGE TYPES      ##
############################

enum Type {
	GENERIC,
	PHYSICAL,
	ENERGY,
	FIRE,
	ICE,
	ELECTRIC,
	EXPLOSIVE,
	POISON,
	TRUE_DAMAGE
}


############################
##       TYPE NAMES       ##
############################

#### GET DISPLAY NAME ####

static func get_display_name(
	damage_type: Type
) -> String:
	match damage_type:
		Type.PHYSICAL:
			return "Physical"
		
		Type.ENERGY:
			return "Energy"
		
		Type.FIRE:
			return "Fire"
		
		Type.ICE:
			return "Ice"
		
		Type.ELECTRIC:
			return "Electric"
		
		Type.EXPLOSIVE:
			return "Explosive"
		
		Type.POISON:
			return "Poison"
		
		Type.TRUE_DAMAGE:
			return "True Damage"
		
		_:
			return "Generic"
