class_name PlayerStatus

extends MarginContainer


############################
##         SCENES         ##
############################

const HEALTH_PIP_SCENE: PackedScene = preload(
	"res://Scenes/UI/pip.tscn"
)


############################
##     NODE REFERENCES    ##
############################

@onready var health_label: Label = $HBox/Health

@onready var pip_container: HBoxContainer = (
	$HBox/Pips
)


############################
##       UI SETTINGS      ##
############################

@export var hide_until_player_found: bool = true
@export var show_health_label: bool = true
@export var show_maximum_health: bool = true

@export var health_per_pip: float = 10.0

@export var show_empty_pips: bool = true

@export_range(0.0, 1.0, 0.05)
var empty_pip_opacity: float = 0.2


############################
##     PLAYER REFERENCE   ##
############################

var local_player: PlatformPlayer = null


############################
##       HEALTH PIPS      ##
############################

var health_pips: Array[TextureRect] = []

@export var full_pip_color: Color = Color(
	0.9,
	0.1,
	0.1,
	1.0
)

@export var empty_pip_color: Color = Color(
	0.12,
	0.16,
	0.22,
	1.0
)

############################
##       LIFECYCLE        ##
############################

#### READY ####

func _ready() -> void:
	health_label.visible = show_health_label
	
	if hide_until_player_found:
		visible = false
	
	set_process(true)
	
	call_deferred(
		"find_local_player"
	)


#### PROCESS ####

func _process(_delta: float) -> void:
	if has_valid_local_player():
		set_process(false)
		return
	
	find_local_player()


#### EXIT TREE ####

func _exit_tree() -> void:
	unbind_local_player()


############################
##      PLAYER LOOKUP     ##
############################

#### FIND LOCAL PLAYER ####

func find_local_player() -> void:
	var player_node: Node = (
		get_tree().get_first_node_in_group(
			&"local_player"
		)
	)
	
	if player_node == null:
		return
	
	if not player_node is PlatformPlayer:
		return
	
	bind_local_player(
		player_node as PlatformPlayer
	)


#### HAS VALID LOCAL PLAYER ####

func has_valid_local_player() -> bool:
	if local_player == null:
		return false
	
	return is_instance_valid(local_player)


############################
##      PLAYER BINDING    ##
############################

#### BIND LOCAL PLAYER ####

func bind_local_player(
	new_local_player: PlatformPlayer
) -> void:
	if new_local_player == null:
		return
	
	if local_player == new_local_player:
		return
	
	unbind_local_player()
	
	local_player = new_local_player
	
	if not local_player.local_health_changed.is_connected(
		update_health
	):
		local_player.local_health_changed.connect(
			update_health
		)
	
	if not local_player.tree_exiting.is_connected(
		local_player_exiting
	):
		local_player.tree_exiting.connect(
			local_player_exiting
		)
	
	update_from_player()
	
	visible = true
	set_process(false)


#### UNBIND LOCAL PLAYER ####

func unbind_local_player() -> void:
	if not has_valid_local_player():
		local_player = null
		return
	
	if local_player.local_health_changed.is_connected(
		update_health
	):
		local_player.local_health_changed.disconnect(
			update_health
		)
	
	if local_player.tree_exiting.is_connected(
		local_player_exiting
	):
		local_player.tree_exiting.disconnect(
			local_player_exiting
		)
	
	local_player = null


#### LOCAL PLAYER EXITING ####

func local_player_exiting() -> void:
	local_player = null
	
	clear_health_pips()
	
	if hide_until_player_found:
		visible = false
	
	set_process(true)


############################
##       HEALTH HUD       ##
############################

#### UPDATE FROM PLAYER ####

func update_from_player() -> void:
	if not has_valid_local_player():
		return
	
	var health_component: HealthComponent = (
		local_player.health_component
	)
	
	if health_component == null:
		return
	
	update_health(
		health_component.current_health,
		health_component.maximum_health
	)


#### UPDATE HEALTH ####

func update_health(
	current_health: float,
	maximum_health: float
) -> void:
	update_health_label(
		current_health,
		maximum_health
	)
	
	update_health_pips(
		current_health,
		maximum_health
	)


#### UPDATE HEALTH LABEL ####

func update_health_label(
	current_health: float,
	maximum_health: float
) -> void:
	if not show_health_label:
		return
	
	var displayed_health: int = roundi(
		current_health
	)
	
	var displayed_maximum: int = roundi(
		maximum_health
	)
	
	if show_maximum_health:
		health_label.text = "%d / %d" % [
			displayed_health,
			displayed_maximum
		]
		return
	
	health_label.text = str(
		displayed_health
	)


############################
##       HEALTH PIPS      ##
############################

#### UPDATE HEALTH PIPS ####

func update_health_pips(
	current_health: float,
	maximum_health: float
) -> void:
	if health_per_pip <= 0.0:
		return
	
	var required_pip_count: int = ceili(
		maximum_health / health_per_pip
	)
	
	set_pip_count(
		required_pip_count
	)
	
	for pip_index: int in range(
		health_pips.size()
	):
		update_single_pip(
			pip_index,
			current_health
		)


#### UPDATE SINGLE PIP ####

func update_single_pip(
	pip_index: int,
	current_health: float
) -> void:
	var pip: TextureRect = health_pips[pip_index]
	
	var pip_start_health: float = (
		float(pip_index)
		* health_per_pip
	)
	
	var health_in_pip: float = clampf(
		current_health - pip_start_health,
		0.0,
		health_per_pip
	)
	
	var fill_amount: float = (
		health_in_pip / health_per_pip
	)
	
	if not show_empty_pips:
		pip.visible = fill_amount > 0.0
	else:
		pip.visible = true
	
	pip.modulate = empty_pip_color.lerp(
		full_pip_color,
		fill_amount
	)


#### SET PIP COUNT ####

func set_pip_count(
	required_pip_count: int
) -> void:
	required_pip_count = maxi(
		required_pip_count,
		0
	)
	
	while health_pips.size() < required_pip_count:
		create_health_pip()
	
	while health_pips.size() > required_pip_count:
		remove_last_health_pip()


#### CREATE HEALTH PIP ####

func create_health_pip() -> void:
	var pip: TextureRect = (
		HEALTH_PIP_SCENE.instantiate()
		as TextureRect
	)
	
	if pip == null:
		push_error(
			"PlayerStatus could not create a health pip."
		)
		return
	
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	pip_container.add_child(pip)
	health_pips.append(pip)


#### REMOVE LAST HEALTH PIP ####

func remove_last_health_pip() -> void:
	if health_pips.is_empty():
		return
	
	var pip: TextureRect = health_pips.pop_back()
	
	if not is_instance_valid(pip):
		return
	
	pip.queue_free()


#### CLEAR HEALTH PIPS ####

func clear_health_pips() -> void:
	for pip: TextureRect in health_pips:
		if not is_instance_valid(pip):
			continue
		
		pip.queue_free()
	
	health_pips.clear()
