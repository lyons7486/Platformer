class_name MissionPlayerRecord

extends RefCounted


############################
##     PLAYER STATES      ##
############################

enum PlayerState {
	ACTIVE,
	DEAD,
	WAITING_FOR_RESPAWN,
	EXTRACTION_READY,
	EXTRACTED,
	DISCONNECTED_GRACE,
	DISCONNECTED_INACTIVE
}


############################
##      PLAYER DATA       ##
############################

var player_key: String = ""
var peer_id: int = 0
var display_name: String = ""

var state: int = PlayerState.ACTIVE
var state_before_disconnect: int = PlayerState.ACTIVE

var connected: bool = true
var began_mission: bool = false
var late_joiner: bool = false

var counts_for_progression: bool = true
var counts_for_rewards: bool = true

var reconnect_time_remaining: float = 0.0


############################
##    SURVIVAL STATE      ##
############################

var alive: bool = true
var reached_extraction_zone: bool = false
var extracted: bool = false

var death_count: int = 0


############################
##    WAYPOINT STATE      ##
############################

var current_waypoint_id: int = 0
var highest_waypoint_id: int = 0

var current_waypoint_position: Vector2 = Vector2.ZERO


############################
##      STATISTICS        ##
############################

var statistics: Dictionary = {}


############################
##        CREATION        ##
############################

#### INITIALIZE ####

func _init(
	new_player_key: String = "",
	new_peer_id: int = 0,
	started_with_mission: bool = false
) -> void:
	player_key = new_player_key
	peer_id = new_peer_id
	
	began_mission = started_with_mission
	late_joiner = not started_with_mission
	
	connected = true
	counts_for_progression = true
	counts_for_rewards = true
	
	set_state(PlayerState.ACTIVE)


############################
##      STATE CHANGES     ##
############################

#### SET STATE ####

func set_state(
	new_state: int
) -> void:
	state = new_state
	
	match state:
		PlayerState.ACTIVE:
			alive = true
			extracted = false
		
		PlayerState.DEAD:
			alive = false
			extracted = false
		
		PlayerState.WAITING_FOR_RESPAWN:
			alive = false
			extracted = false
		
		PlayerState.EXTRACTION_READY:
			alive = true
			reached_extraction_zone = true
			extracted = false
		
		PlayerState.EXTRACTED:
			alive = true
			reached_extraction_zone = true
			extracted = true
			counts_for_progression = false
		
		PlayerState.DISCONNECTED_GRACE:
			pass
		
		PlayerState.DISCONNECTED_INACTIVE:
			counts_for_progression = false


#### MARK DEAD ####

func mark_dead() -> void:
	if alive:
		death_count += 1
	
	set_state(PlayerState.DEAD)


#### MARK WAITING FOR RESPAWN ####

func mark_waiting_for_respawn() -> void:
	set_state(
		PlayerState.WAITING_FOR_RESPAWN
	)


#### MARK RESPAWNED ####

func mark_respawned() -> void:
	connected = true
	counts_for_progression = true
	
	reached_extraction_zone = false
	extracted = false
	
	set_state(PlayerState.ACTIVE)


#### MARK EXTRACTION READY ####

func mark_extraction_ready() -> void:
	set_state(
		PlayerState.EXTRACTION_READY
	)


#### LEAVE EXTRACTION ZONE ####

func leave_extraction_zone() -> void:
	if extracted:
		return
	
	reached_extraction_zone = false
	
	set_state(PlayerState.ACTIVE)


#### MARK EXTRACTED ####

func mark_extracted() -> void:
	set_state(PlayerState.EXTRACTED)


############################
##      DISCONNECT        ##
############################

#### MARK DISCONNECTED ####

func mark_disconnected(
	grace_duration: float
) -> void:
	if state != PlayerState.DISCONNECTED_GRACE:
		if state != PlayerState.DISCONNECTED_INACTIVE:
			state_before_disconnect = state
	
	connected = false
	
	reconnect_time_remaining = maxf(
		grace_duration,
		0.0
	)
	
	state = PlayerState.DISCONNECTED_GRACE


#### UPDATE DISCONNECT GRACE ####

func update_disconnect_grace(
	delta: float
) -> bool:
	if state != PlayerState.DISCONNECTED_GRACE:
		return false
	
	reconnect_time_remaining = maxf(
		reconnect_time_remaining - delta,
		0.0
	)
	
	if reconnect_time_remaining > 0.0:
		return false
	
	reconnect_time_remaining = 0.0
	counts_for_progression = false
	
	state = PlayerState.DISCONNECTED_INACTIVE
	
	return true


#### RECONNECT ####

func reconnect(
	new_peer_id: int
) -> void:
	peer_id = new_peer_id
	connected = true
	
	reconnect_time_remaining = 0.0
	
	if state == PlayerState.DISCONNECTED_GRACE:
		state = state_before_disconnect
	elif state == PlayerState.DISCONNECTED_INACTIVE:
		state = state_before_disconnect
	
	counts_for_progression = (
		state != PlayerState.EXTRACTED
	)


############################
##         CHECKS         ##
############################

#### REQUIRED FOR PROGRESSION ####

func is_required_for_progression() -> bool:
	if not counts_for_progression:
		return false
	
	if state == PlayerState.DISCONNECTED_GRACE:
		return (
			state_before_disconnect
			== PlayerState.ACTIVE
			or state_before_disconnect
			== PlayerState.EXTRACTION_READY
			or state_before_disconnect
			== PlayerState.DEAD
		)
	
	if not connected:
		return false
	
	return (
		state == PlayerState.ACTIVE
		or state == PlayerState.EXTRACTION_READY
		or state == PlayerState.DEAD
	)


#### LIVING AND UNEXTRACTED ####

func is_living_and_unextracted() -> bool:
	if not connected:
		return false
	
	if not alive:
		return false
	
	if extracted:
		return false
	
	return true


############################
##      SERIALIZATION     ##
############################

#### TO DICTIONARY ####

func to_dictionary() -> Dictionary:
	return {
		"player_key": player_key,
		"peer_id": peer_id,
		"display_name": display_name,
		"state": state,
		"state_before_disconnect": state_before_disconnect,
		"connected": connected,
		"began_mission": began_mission,
		"late_joiner": late_joiner,
		"counts_for_progression": counts_for_progression,
		"counts_for_rewards": counts_for_rewards,
		"reconnect_time_remaining": reconnect_time_remaining,
		"alive": alive,
		"reached_extraction_zone": reached_extraction_zone,
		"extracted": extracted,
		"death_count": death_count,
		"current_waypoint_id": current_waypoint_id,
		"highest_waypoint_id": highest_waypoint_id,
		"current_waypoint_position": current_waypoint_position,
		"statistics": statistics.duplicate(true)
	}


#### APPLY DICTIONARY ####

func apply_dictionary(
	data: Dictionary
) -> void:
	player_key = str(
		data.get("player_key", "")
	)
	
	peer_id = int(
		data.get("peer_id", 0)
	)
	
	display_name = str(
		data.get("display_name", "")
	)
	
	state = int(
		data.get(
			"state",
			PlayerState.ACTIVE
		)
	)
	
	state_before_disconnect = int(
		data.get(
			"state_before_disconnect",
			PlayerState.ACTIVE
		)
	)
	
	connected = bool(
		data.get("connected", true)
	)
	
	began_mission = bool(
		data.get("began_mission", false)
	)
	
	late_joiner = bool(
		data.get("late_joiner", false)
	)
	
	counts_for_progression = bool(
		data.get(
			"counts_for_progression",
			true
		)
	)
	
	counts_for_rewards = bool(
		data.get(
			"counts_for_rewards",
			true
		)
	)
	
	reconnect_time_remaining = float(
		data.get(
			"reconnect_time_remaining",
			0.0
		)
	)
	
	alive = bool(
		data.get("alive", true)
	)
	
	reached_extraction_zone = bool(
		data.get(
			"reached_extraction_zone",
			false
		)
	)
	
	extracted = bool(
		data.get("extracted", false)
	)
	
	death_count = int(
		data.get("death_count", 0)
	)
	
	current_waypoint_id = int(
		data.get("current_waypoint_id", 0)
	)
	
	highest_waypoint_id = int(
		data.get("highest_waypoint_id", 0)
	)
	
	current_waypoint_position = data.get(
		"current_waypoint_position",
		Vector2.ZERO
	)
	
	var loaded_statistics: Variant = (
		data.get("statistics", {})
	)
	
	if loaded_statistics is Dictionary:
		statistics = loaded_statistics.duplicate(true)
	else:
		statistics = {}


#### FROM DICTIONARY ####

static func from_dictionary(
	data: Dictionary
) -> MissionPlayerRecord:
	var record: MissionPlayerRecord = (
		MissionPlayerRecord.new()
	)
	
	record.apply_dictionary(data)
	
	return record


############################
##       STATE NAME       ##
############################

#### GET STATE NAME ####

static func get_state_name(
	state_value: int
) -> String:
	match state_value:
		PlayerState.ACTIVE:
			return "Active"
		
		PlayerState.DEAD:
			return "Dead"
		
		PlayerState.WAITING_FOR_RESPAWN:
			return "Waiting For Respawn"
		
		PlayerState.EXTRACTION_READY:
			return "Extraction Ready"
		
		PlayerState.EXTRACTED:
			return "Extracted"
		
		PlayerState.DISCONNECTED_GRACE:
			return "Disconnected Grace"
		
		PlayerState.DISCONNECTED_INACTIVE:
			return "Disconnected Inactive"
		
		_:
			return "Unknown"
