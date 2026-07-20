class_name ContactHitbox

extends Hitbox


############################
##     NODE REFERENCES    ##
############################

@onready var contact_timer: Timer = $ContactTimer


############################
##    CONTACT SETTINGS    ##
############################

@export_range(0.05, 5.0, 0.05)
var contact_interval: float = 0.8

@export var damage_immediately_on_enter: bool = true


############################
##      CONTACT STATE     ##
############################

var overlapping_players: Array[PlatformPlayer] = []


############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	
	# The base Hitbox should not automatically activate
	# on every peer. Contact damage is processed only by
	# the server.
	
	active_on_ready = false
	
	super._ready()
	
	setup_contact_collision()
	resolve_contact_source()
	connect_contact_signals()
	
	if multiplayer.is_server():
		activate()
	else:
		deactivate()


############################
##         SETUP          ##
############################

#### SETUP CONTACT COLLISION ####

func setup_contact_collision() -> void:
	contact_timer.one_shot = true
	
	collision_layer = 0
	collision_mask = 0
	
	set_collision_layer_value(
		9,
		true
	)
	
	# The contact Hitbox detects the player's physical
	# body on Layer 3. Damage is then routed to the
	# player's owning peer and applied through its Hurtbox.
	
	set_collision_mask_value(
		3,
		true
	)


#### RESOLVE CONTACT SOURCE ####

func resolve_contact_source() -> void:
	var current_node: Node = get_parent()
	
	while current_node != null:
		if current_node is CharacterBody2D:
			set_source(
				current_node,
				multiplayer.get_unique_id()
			)
			return
		
		current_node = current_node.get_parent()
	
	push_warning(
		"ContactHitbox could not find its owning entity."
	)


############################
##    SIGNAL CONNECTIONS  ##
############################

#### CONNECT CONTACT SIGNALS ####

func connect_contact_signals() -> void:
	if not body_entered.is_connected(
		contact_body_entered
	):
		body_entered.connect(
			contact_body_entered
		)
	
	if not body_exited.is_connected(
		contact_body_exited
	):
		body_exited.connect(
			contact_body_exited
		)
	
	if not contact_timer.timeout.is_connected(
		contact_timer_finished
	):
		contact_timer.timeout.connect(
			contact_timer_finished
		)


############################
##     BODY DETECTION     ##
############################

#### CONTACT BODY ENTERED ####

func contact_body_entered(
	body: Node2D
) -> void:
	if not multiplayer.is_server():
		return
	
	if not body is PlatformPlayer:
		return
	
	var player: PlatformPlayer = body as PlatformPlayer
	
	if overlapping_players.has(player):
		return
	
	overlapping_players.append(player)
	
	if damage_immediately_on_enter:
		damage_player(player)
	
	start_contact_timer()


#### CONTACT BODY EXITED ####

func contact_body_exited(
	body: Node2D
) -> void:
	if not body is PlatformPlayer:
		return
	
	var player: PlatformPlayer = body as PlatformPlayer
	
	overlapping_players.erase(player)


############################
##      CONTACT DAMAGE    ##
############################

#### DAMAGE PLAYER ####

func damage_player(
	player: PlatformPlayer
) -> void:
	if not multiplayer.is_server():
		return
	
	if not active:
		return
	
	if not is_instance_valid(player):
		return
	
	if player.dead:
		return
	
	if player.dying or player.death_pending:
		return
	
	var player_hurtbox: Hurtbox = player.hurtbox
	
	if player_hurtbox == null:
		return
	
	# Use the base Hitbox to construct DamageData so
	# damage types, tags, source information, and
	# knockback settings remain consistent.
	
	var damage_data: DamageData = create_damage_data(
		player_hurtbox
	)
	
	damage_data.hit_position = global_position
	damage_data.add_tag(&"enemy_contact")
	
	player.take_damage(damage_data)


############################
##      CONTACT TIMER     ##
############################

#### START CONTACT TIMER ####

func start_contact_timer() -> void:
	if overlapping_players.is_empty():
		return
	
	if not contact_timer.is_stopped():
		return
	
	contact_timer.start(
		contact_interval
	)


#### CONTACT TIMER FINISHED ####

func contact_timer_finished() -> void:
	if not multiplayer.is_server():
		return
	
	remove_invalid_players()
	
	var players_to_damage: Array[PlatformPlayer] = (
		overlapping_players.duplicate()
	)
	
	for player: PlatformPlayer in players_to_damage:
		damage_player(player)
	
	start_contact_timer()


#### REMOVE INVALID PLAYERS ####

func remove_invalid_players() -> void:
	for player_index: int in range(
		overlapping_players.size() - 1,
		-1,
		-1
	):
		var player: PlatformPlayer = (
			overlapping_players[player_index]
		)
		
		if is_instance_valid(player):
			continue
		
		overlapping_players.remove_at(
			player_index
		)

############################
##    CONTACT SHUTDOWN    ##
############################

#### STOP CONTACT DAMAGE ####

func stop_contact_damage() -> void:
	deactivate()
	
	contact_timer.stop()
	overlapping_players.clear()
