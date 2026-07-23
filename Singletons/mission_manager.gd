extends Node


############################
##         SIGNALS        ##
############################

signal mission_started(
	mission_id: StringName
)

signal mission_ended(
	mission_id: StringName
)

signal roster_changed

signal player_registered(
	player_key: String
)

signal player_state_changed(
	player_key: String,
	previous_state: int,
	new_state: int
)

signal player_reconnected(
	player_key: String,
	peer_id: int
)

signal disconnect_grace_started(
	player_key: String
)

signal disconnect_grace_expired(
	player_key: String
)

signal player_waypoint_reached(
	player_key: String,
	waypoint_id: int
)

signal team_waypoint_secured(
	waypoint_id: int
)


############################
##     MISSION SETTINGS   ##
############################

var reconnect_grace_duration: float = 30.0
var disconnect_update_interval: float = 0.25

var print_roster_changes: bool = false


############################
##      MISSION STATE     ##
############################

var mission_active: bool = false
var current_mission_id: StringName = &""

var roster_revision: int = 0
var highest_team_secured_waypoint_id: int = 0

var waypoint_positions: Dictionary = {}

var snapshot_publish_queued: bool = false


############################
##       PLAYER DATA      ##
############################

var player_records: Dictionary = {}
var peer_to_player_key: Dictionary = {}

var disconnect_grace_player_keys: Dictionary = {}


############################
##      TIMER STATE       ##
############################

var disconnect_grace_timer: Timer = null


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	setup_disconnect_grace_timer()
	connect_network_signals()


############################
##      TIMER SETUP       ##
############################

#### SETUP DISCONNECT GRACE TIMER ####

func setup_disconnect_grace_timer() -> void:
	disconnect_grace_timer = Timer.new()
	
	disconnect_grace_timer.name = (
		"DisconnectGraceTimer"
	)
	
	disconnect_grace_timer.wait_time = (
		disconnect_update_interval
	)
	
	disconnect_grace_timer.one_shot = false
	disconnect_grace_timer.autostart = false
	disconnect_grace_timer.ignore_time_scale = true
	
	disconnect_grace_timer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)
	
	add_child(
		disconnect_grace_timer
	)
	
	disconnect_grace_timer.timeout.connect(
		disconnect_grace_timer_timeout
	)


#### DISCONNECT GRACE TIMER TIMEOUT ####

func disconnect_grace_timer_timeout() -> void:
	if not multiplayer.is_server():
		stop_disconnect_grace_timer()
		return
	
	if not mission_active:
		stop_disconnect_grace_timer()
		return
	
	update_disconnect_grace_periods(
		disconnect_update_interval
	)


#### START DISCONNECT GRACE TIMER ####

func start_disconnect_grace_timer() -> void:
	if disconnect_grace_timer == null:
		return
	
	if disconnect_grace_player_keys.is_empty():
		return
	
	if not disconnect_grace_timer.is_stopped():
		return
	
	disconnect_grace_timer.start()


#### STOP DISCONNECT GRACE TIMER ####

func stop_disconnect_grace_timer() -> void:
	if disconnect_grace_timer == null:
		return
	
	disconnect_grace_timer.stop()


############################
##    NETWORK SIGNALS     ##
############################

#### CONNECT NETWORK SIGNALS ####

func connect_network_signals() -> void:
	if not NetworkManager.player_connected.is_connected(
		network_player_connected
	):
		NetworkManager.player_connected.connect(
			network_player_connected
		)
	
	if not NetworkManager.player_disconnected.is_connected(
		network_player_disconnected
	):
		NetworkManager.player_disconnected.connect(
			network_player_disconnected
		)
	
	if not NetworkManager.server_disconnected.is_connected(
		network_server_disconnected
	):
		NetworkManager.server_disconnected.connect(
			network_server_disconnected
		)


#### NETWORK PLAYER CONNECTED ####

func network_player_connected(
	peer_id: int
) -> void:
	if not multiplayer.is_server():
		return
	
	if not mission_active:
		return
	
	register_or_reconnect_player(
		peer_id,
		get_temporary_player_key(peer_id),
		"",
		false
	)


#### NETWORK PLAYER DISCONNECTED ####

func network_player_disconnected(
	peer_id: int
) -> void:
	if not multiplayer.is_server():
		return
	
	if not mission_active:
		return
	
	mark_player_disconnected(peer_id)


#### NETWORK SERVER DISCONNECTED ####

func network_server_disconnected() -> void:
	clear_local_mission_state()


############################
##      MISSION FLOW      ##
############################

#### BEGIN MISSION ####

func begin_mission(
	new_mission_id: StringName
) -> void:
	if not multiplayer.is_server():
		return
	
	clear_local_mission_state()
	
	mission_active = true
	current_mission_id = new_mission_id
	
	register_or_reconnect_player(
		1,
		get_temporary_player_key(1),
		"Host",
		true,
		false
	)
	
	for connected_peer_id: int in multiplayer.get_peers():
		register_or_reconnect_player(
			connected_peer_id,
			get_temporary_player_key(
				connected_peer_id
			),
			"",
			true,
			false
		)
	
	mission_started.emit(
		current_mission_id
	)
	
	publish_roster_change()


#### END MISSION ####

func end_mission() -> void:
	if not multiplayer.is_server():
		return
	
	if not mission_active:
		return
	
	var completed_mission_id: StringName = (
		current_mission_id
	)
	
	mission_active = false
	
	mission_ended.emit(
		completed_mission_id
	)
	
	publish_roster_change()


#### CLEAR LOCAL MISSION STATE ####

func clear_local_mission_state() -> void:
	mission_active = false
	current_mission_id = &""
	
	roster_revision = 0
	highest_team_secured_waypoint_id = 0
	
	waypoint_positions.clear()
	
	snapshot_publish_queued = false
	
	player_records.clear()
	peer_to_player_key.clear()
	
	disconnect_grace_player_keys.clear()
	stop_disconnect_grace_timer()
	
	roster_changed.emit()


############################
##   PLAYER REGISTRATION  ##
############################

#### REGISTER OR RECONNECT PLAYER ####

func register_or_reconnect_player(
	peer_id: int,
	player_key: String,
	display_name: String = "",
	started_with_mission: bool = false,
	publish_change: bool = true
) -> MissionPlayerRecord:
	if not multiplayer.is_server():
		return null
	
	if player_key.is_empty():
		player_key = get_temporary_player_key(
			peer_id
		)
	
	var existing_record: MissionPlayerRecord = (
		get_player_record(player_key)
	)
	
	if existing_record != null:
		var old_peer_id: int = (
			existing_record.peer_id
		)
		
		if peer_to_player_key.has(old_peer_id):
			peer_to_player_key.erase(old_peer_id)
		
		existing_record.reconnect(peer_id)
		
		disconnect_grace_player_keys.erase(
			player_key
		)
		
		if disconnect_grace_player_keys.is_empty():
			stop_disconnect_grace_timer()
		
		if not display_name.is_empty():
			existing_record.display_name = (
				display_name
			)
		
		if started_with_mission:
			existing_record.began_mission = true
			existing_record.late_joiner = false
		
		peer_to_player_key[peer_id] = player_key
		
		player_reconnected.emit(
			player_key,
			peer_id
		)
		
		reevaluate_team_waypoint_progress()
		
		if publish_change:
			publish_roster_change()
		
		return existing_record
	
	var new_record: MissionPlayerRecord = (
		MissionPlayerRecord.new(
			player_key,
			peer_id,
			started_with_mission
		)
	)
	
	new_record.display_name = display_name
	
	if (
		new_record.late_joiner
		and highest_team_secured_waypoint_id > 0
	):
		var entry_position: Vector2 = (
			get_waypoint_position(
				highest_team_secured_waypoint_id,
				Vector2.ZERO
			)
		)
		
		new_record.set_late_join_entry(
			highest_team_secured_waypoint_id,
			entry_position
		)
	
	player_records[player_key] = new_record
	peer_to_player_key[peer_id] = player_key
	
	player_registered.emit(player_key)
	
	if publish_change:
		publish_roster_change()
	
	return new_record


#### GET TEMPORARY PLAYER KEY ####

func get_temporary_player_key(
	peer_id: int
) -> String:
	return "peer_%s" % peer_id


############################
##       PLAYER LOOKUP    ##
############################

#### GET PLAYER RECORD ####

func get_player_record(
	player_key: String
) -> MissionPlayerRecord:
	if not player_records.has(player_key):
		return null
	
	return (
		player_records[player_key]
		as MissionPlayerRecord
	)


#### GET PLAYER RECORD BY PEER ####

func get_player_record_by_peer(
	peer_id: int
) -> MissionPlayerRecord:
	if not peer_to_player_key.has(peer_id):
		return null
	
	var player_key: String = str(
		peer_to_player_key[peer_id]
	)
	
	return get_player_record(player_key)


#### GET PLAYER KEY BY PEER ####

func get_player_key_by_peer(
	peer_id: int
) -> String:
	if not peer_to_player_key.has(peer_id):
		return ""
	
	return str(
		peer_to_player_key[peer_id]
	)


############################
##    PLAYER STATE API    ##
############################

#### SET PLAYER STATE ####

func set_player_state(
	player_key: String,
	new_state: int
) -> void:
	if not multiplayer.is_server():
		return
	
	var record: MissionPlayerRecord = (
		get_player_record(player_key)
	)
	
	if record == null:
		return
	
	var previous_state: int = record.state
	
	if previous_state == new_state:
		return
	
	record.set_state(new_state)
	
	player_state_changed.emit(
		player_key,
		previous_state,
		new_state
	)
	
	reevaluate_team_waypoint_progress()
	publish_roster_change()


#### MARK PLAYER DEAD BY PEER ####

func mark_player_dead_by_peer(
	peer_id: int
) -> void:
	if not multiplayer.is_server():
		return
	
	var record: MissionPlayerRecord = (
		get_player_record_by_peer(peer_id)
	)
	
	if record == null:
		return
	
	if not record.alive:
		return
	
	var previous_state: int = record.state
	
	record.mark_dead()
	
	player_state_changed.emit(
		record.player_key,
		previous_state,
		record.state
	)
	
	reevaluate_team_waypoint_progress()
	publish_roster_change()


#### MARK PLAYER RESPAWNED BY PEER ####

func mark_player_respawned_by_peer(
	peer_id: int
) -> void:
	if not multiplayer.is_server():
		return
	
	var record: MissionPlayerRecord = (
		get_player_record_by_peer(peer_id)
	)
	
	if record == null:
		return
	
	var previous_state: int = record.state
	
	record.mark_respawned()
	
	player_state_changed.emit(
		record.player_key,
		previous_state,
		record.state
	)
	
	reevaluate_team_waypoint_progress()
	publish_roster_change()


############################
##   PLAYER REPORTING     ##
############################

#### REPORT LOCAL PLAYER DIED ####

func report_local_player_died() -> void:
	if not mission_active:
		return
	
	if multiplayer.is_server():
		mark_player_dead_by_peer(
			multiplayer.get_unique_id()
		)
		return
	
	request_local_player_died.rpc_id(1)


#### REQUEST LOCAL PLAYER DIED ####

@rpc("any_peer", "call_remote", "reliable")
func request_local_player_died() -> void:
	if not multiplayer.is_server():
		return
	
	var sender_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)
	
	if sender_peer_id <= 0:
		return
	
	mark_player_dead_by_peer(
		sender_peer_id
	)


#### REPORT LOCAL PLAYER RESPAWNED ####

func report_local_player_respawned() -> void:
	if not mission_active:
		return
	
	if multiplayer.is_server():
		mark_player_respawned_by_peer(
			multiplayer.get_unique_id()
		)
		return
	
	request_local_player_respawned.rpc_id(1)


#### REQUEST LOCAL PLAYER RESPAWNED ####

@rpc("any_peer", "call_remote", "reliable")
func request_local_player_respawned() -> void:
	if not multiplayer.is_server():
		return
	
	var sender_peer_id: int = (
		multiplayer.get_remote_sender_id()
	)
	
	if sender_peer_id <= 0:
		return
	
	mark_player_respawned_by_peer(
		sender_peer_id
	)


############################
##      DISCONNECTS       ##
############################

#### MARK PLAYER DISCONNECTED ####

func mark_player_disconnected(
	peer_id: int
) -> void:
	if not multiplayer.is_server():
		return
	
	var record: MissionPlayerRecord = (
		get_player_record_by_peer(peer_id)
	)
	
	if record == null:
		return
	
	peer_to_player_key.erase(peer_id)
	
	record.mark_disconnected(
		reconnect_grace_duration
	)
	
	disconnect_grace_player_keys[
		record.player_key
	] = true
	
	disconnect_grace_started.emit(
		record.player_key
	)
	
	start_disconnect_grace_timer()
	publish_roster_change()


#### UPDATE DISCONNECT GRACE PERIODS ####

func update_disconnect_grace_periods(
	delta: float
) -> void:
	if disconnect_grace_player_keys.is_empty():
		stop_disconnect_grace_timer()
		return
	
	var roster_was_changed: bool = false
	
	var finished_player_keys: Array[String] = []
	
	for player_key_value: Variant in (
		disconnect_grace_player_keys.keys()
	):
		var player_key: String = str(
			player_key_value
		)
		
		var record: MissionPlayerRecord = (
			get_player_record(player_key)
		)
		
		if record == null:
			finished_player_keys.append(
				player_key
			)
			
			continue
		
		if not record.update_disconnect_grace(delta):
			continue
		
		disconnect_grace_expired.emit(
			record.player_key
		)
		
		finished_player_keys.append(
			player_key
		)
		
		roster_was_changed = true
	
	for player_key: String in finished_player_keys:
		disconnect_grace_player_keys.erase(
			player_key
		)
	
	if disconnect_grace_player_keys.is_empty():
		stop_disconnect_grace_timer()
	
	if not roster_was_changed:
		return
	
	reevaluate_team_waypoint_progress()
	publish_roster_change()


############################
##       WAYPOINTS        ##
############################

#### MARK PLAYER WAYPOINT BY PEER ####

func mark_player_waypoint_by_peer(
	peer_id: int,
	waypoint_id: int,
	waypoint_position: Vector2
) -> void:
	if not multiplayer.is_server():
		return
	
	if not mission_active:
		return
	
	if waypoint_id <= 0:
		return
	
	var record: MissionPlayerRecord = (
		get_player_record_by_peer(peer_id)
	)
	
	if record == null:
		return
	
	if not record.alive:
		return
	
	if record.extracted:
		return
	
	if (
		record.late_joiner
		and waypoint_id
		<= record.progression_entry_waypoint_id
	):
		return
	
	if waypoint_id <= record.highest_waypoint_id:
		return
	
	waypoint_positions[waypoint_id] = (
		waypoint_position
	)
	
	record.current_waypoint_id = waypoint_id
	record.highest_waypoint_id = waypoint_id
	
	record.current_waypoint_position = (
		waypoint_position
	)
	
	increment_player_statistic(
		record,
		&"waypoints_reached_alive",
		1.0
	)
	
	player_waypoint_reached.emit(
		record.player_key,
		waypoint_id
	)
	
	reevaluate_team_waypoint_progress()
	publish_roster_change()


#### REEVALUATE TEAM WAYPOINT PROGRESS ####

func reevaluate_team_waypoint_progress() -> void:
	if not multiplayer.is_server():
		return
	
	if not mission_active:
		return
	
	var highest_reached_waypoint_id: int = (
		highest_team_secured_waypoint_id
	)
	
	for record_value: Variant in player_records.values():
		var record: MissionPlayerRecord = (
			record_value as MissionPlayerRecord
		)
		
		if record == null:
			continue
		
		highest_reached_waypoint_id = maxi(
			highest_reached_waypoint_id,
			record.get_progression_waypoint_id()
		)
	
	if (
		highest_reached_waypoint_id
		<= highest_team_secured_waypoint_id
	):
		return
	
	var next_waypoint_id: int = (
		highest_team_secured_waypoint_id + 1
	)
	
	while next_waypoint_id <= highest_reached_waypoint_id:
		var previous_secured_waypoint_id: int = (
			highest_team_secured_waypoint_id
		)
		
		try_secure_team_waypoint(
			next_waypoint_id
		)
		
		if (
			highest_team_secured_waypoint_id
			== previous_secured_waypoint_id
		):
			return
		
		next_waypoint_id += 1


#### TRY SECURE TEAM WAYPOINT ####

func try_secure_team_waypoint(
	waypoint_id: int
) -> void:
	if not multiplayer.is_server():
		return
	
	if waypoint_id <= highest_team_secured_waypoint_id:
		return
	
	var required_records: Array[MissionPlayerRecord] = (
		get_required_player_records()
	)
	
	if required_records.is_empty():
		return
	
	for record: MissionPlayerRecord in required_records:
		if (
			record.get_progression_waypoint_id()
			>= waypoint_id
		):
			continue
		
		return
	
	highest_team_secured_waypoint_id = waypoint_id
	
	team_waypoint_secured.emit(
		waypoint_id
	)
	
	print(
		"Team secured waypoint: ",
		waypoint_id
	)


#### HAS PLAYER REACHED WAYPOINT ####

func has_player_reached_waypoint(
	peer_id: int,
	waypoint_id: int
) -> bool:
	var record: MissionPlayerRecord = (
		get_player_record_by_peer(peer_id)
	)
	
	if record == null:
		return false
	
	return (
		record.highest_waypoint_id
		>= waypoint_id
	)


#### IS TEAM WAYPOINT SECURED ####

func is_team_waypoint_secured(
	waypoint_id: int
) -> bool:
	return (
		highest_team_secured_waypoint_id
		>= waypoint_id
	)


#### GET WAYPOINT POSITION ####

func get_waypoint_position(
	waypoint_id: int,
	fallback_position: Vector2 = Vector2.ZERO
) -> Vector2:
	var stored_position: Variant = (
		waypoint_positions.get(
			waypoint_id,
			fallback_position
		)
	)
	
	if stored_position is Vector2:
		return stored_position
	
	return fallback_position


#### GET CURRENT TEAM SPAWN POSITION ####

func get_current_team_spawn_position(
	fallback_position: Vector2
) -> Vector2:
	if highest_team_secured_waypoint_id <= 0:
		return fallback_position
	
	return get_waypoint_position(
		highest_team_secured_waypoint_id,
		fallback_position
	)


#### GET LATE JOIN SPAWN POSITION ####

func get_late_join_spawn_position(
	peer_id: int,
	fallback_position: Vector2
) -> Vector2:
	if not mission_active:
		return fallback_position
	
	var record: MissionPlayerRecord = (
		get_player_record_by_peer(peer_id)
	)
	
	if record == null:
		return get_current_team_spawn_position(
			fallback_position
		)
	
	if not record.can_receive_late_join_spawn():
		return fallback_position
	
	return record.progression_entry_position


############################
##      STATISTICS        ##
############################

#### INCREMENT PLAYER STATISTIC ####

func increment_player_statistic(
	record: MissionPlayerRecord,
	statistic_name: StringName,
	amount: float
) -> void:
	if record == null:
		return
	
	var statistic_key: String = String(
		statistic_name
	)
	
	var current_amount: float = float(
		record.statistics.get(
			statistic_key,
			0.0
		)
	)
	
	record.statistics[statistic_key] = (
		current_amount + amount
	)


############################
##    PROGRESSION CHECKS  ##
############################

#### GET REQUIRED PLAYER RECORDS ####

func get_required_player_records() -> Array[MissionPlayerRecord]:
	var required_records: Array[MissionPlayerRecord] = []
	
	for record_value: Variant in player_records.values():
		var record: MissionPlayerRecord = (
			record_value as MissionPlayerRecord
		)
		
		if record == null:
			continue
		
		if not record.is_required_for_progression():
			continue
		
		required_records.append(record)
	
	return required_records


#### GET LIVING UNEXTRACTED RECORDS ####

func get_living_unextracted_records() -> Array[MissionPlayerRecord]:
	var living_records: Array[MissionPlayerRecord] = []
	
	for record_value: Variant in player_records.values():
		var record: MissionPlayerRecord = (
			record_value as MissionPlayerRecord
		)
		
		if record == null:
			continue
		
		if not record.is_living_and_unextracted():
			continue
		
		living_records.append(record)
	
	return living_records


#### HAS EXTRACTED PLAYER ####

func has_extracted_player() -> bool:
	for record_value: Variant in player_records.values():
		var record: MissionPlayerRecord = (
			record_value as MissionPlayerRecord
		)
		
		if record == null:
			continue
		
		if record.extracted:
			return true
	
	return false


############################
##    NETWORK SNAPSHOT    ##
############################

#### CREATE MISSION SNAPSHOT ####

func create_mission_snapshot() -> Dictionary:
	var serialized_records: Array[Dictionary] = []
	
	for record_value: Variant in player_records.values():
		var record: MissionPlayerRecord = (
			record_value as MissionPlayerRecord
		)
		
		if record == null:
			continue
		
		serialized_records.append(
			record.to_dictionary()
		)
	
	return {
		"mission_active": mission_active,
		"mission_id": String(current_mission_id),
		"roster_revision": roster_revision,
		"highest_team_secured_waypoint_id": (
			highest_team_secured_waypoint_id
		),
		"waypoint_positions": (
			waypoint_positions.duplicate(true)
		),
		"player_records": serialized_records
	}


#### RECEIVE MISSION SNAPSHOT ####

@rpc("authority", "call_remote", "reliable", 3)
func receive_mission_snapshot(
	snapshot: Dictionary
) -> void:
	var was_mission_active: bool = mission_active
	
	var previous_team_waypoint_id: int = (
		highest_team_secured_waypoint_id
	)
	
	mission_active = bool(
		snapshot.get("mission_active", false)
	)
	
	current_mission_id = StringName(
		str(snapshot.get("mission_id", ""))
	)
	
	roster_revision = int(
		snapshot.get("roster_revision", 0)
	)
	
	highest_team_secured_waypoint_id = int(
		snapshot.get(
			"highest_team_secured_waypoint_id",
			0
		)
	)
	
	waypoint_positions.clear()
	
	var loaded_waypoint_positions: Variant = (
		snapshot.get("waypoint_positions", {})
	)
	
	if loaded_waypoint_positions is Dictionary:
		for waypoint_key: Variant in (
			loaded_waypoint_positions.keys()
		):
			var loaded_position: Variant = (
				loaded_waypoint_positions[
					waypoint_key
				]
			)
			
			if not loaded_position is Vector2:
				continue
			
			waypoint_positions[int(waypoint_key)] = (
				loaded_position
			)
	
	player_records.clear()
	peer_to_player_key.clear()
	
	var serialized_records: Variant = (
		snapshot.get("player_records", [])
	)
	
	if serialized_records is Array:
		for record_data: Variant in serialized_records:
			if not record_data is Dictionary:
				continue
			
			var record: MissionPlayerRecord = (
				MissionPlayerRecord.from_dictionary(
					record_data
				)
			)
			
			player_records[record.player_key] = record
			
			if record.connected:
				peer_to_player_key[record.peer_id] = (
					record.player_key
				)
	
	if mission_active and not was_mission_active:
		mission_started.emit(
			current_mission_id
		)
	
	if not mission_active and was_mission_active:
		mission_ended.emit(
			current_mission_id
		)
	
	if (
		highest_team_secured_waypoint_id
		> previous_team_waypoint_id
	):
		for secured_waypoint_id: int in range(
			previous_team_waypoint_id + 1,
			highest_team_secured_waypoint_id + 1
		):
			team_waypoint_secured.emit(
				secured_waypoint_id
			)
	
	roster_changed.emit()
	
	if print_roster_changes:
		print_roster_summary()


#### PUBLISH ROSTER CHANGE ####

func publish_roster_change() -> void:
	if not multiplayer.is_server():
		return
	
	roster_revision += 1
	
	roster_changed.emit()
	
	if print_roster_changes:
		print_roster_summary()
	
	if not NetworkManager.is_online():
		return
	
	if snapshot_publish_queued:
		return
	
	snapshot_publish_queued = true
	
	call_deferred(
		"send_queued_mission_snapshot"
	)


#### SEND QUEUED MISSION SNAPSHOT ####

func send_queued_mission_snapshot() -> void:
	snapshot_publish_queued = false
	
	if not multiplayer.is_server():
		return
	
	if not NetworkManager.is_online():
		return
	
	receive_mission_snapshot.rpc(
		create_mission_snapshot()
	)


############################
##         DEBUG          ##
############################

#### PRINT ROSTER SUMMARY ####

func print_roster_summary() -> void:
	print("")
	
	print(
		"Mission roster: ",
		current_mission_id,
		" | Revision: ",
		roster_revision,
		" | Team waypoint: ",
		highest_team_secured_waypoint_id
	)
	
	for record_value: Variant in player_records.values():
		var record: MissionPlayerRecord = (
			record_value as MissionPlayerRecord
		)
		
		if record == null:
			continue
		
		print(
			"- ",
			record.player_key,
			" | Peer: ",
			record.peer_id,
			" | State: ",
			MissionPlayerRecord.get_state_name(
				record.state
			),
			" | Connected: ",
			record.connected,
			" | Started mission: ",
			record.began_mission,
			" | Late joiner: ",
			record.late_joiner,
			" | Deaths: ",
			record.death_count,
			" | Personal waypoint: ",
			record.highest_waypoint_id,
			" | Progression entry: ",
			record.progression_entry_waypoint_id,
			" | Missed waypoints: ",
			record.missed_waypoint_count
		)
