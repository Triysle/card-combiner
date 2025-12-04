extends PanelContainer

## Upgrades Panel - compact format: Lv | Name | Cost
## Description shows current -> next value

@onready var header_button: Button = $VBox/HeaderButton
@onready var content: VBoxContainer = $VBox/Content
@onready var upgrades_container: VBoxContainer = $VBox/Content/UpgradesContainer
@onready var cap_label: Label = $VBox/Content/CapLabel

var is_expanded: bool = true
var upgrade_rows: Dictionary = {}  # upgrade_id -> {button, desc_label}

func _ready() -> void:
	header_button.pressed.connect(_on_header_pressed)
	GameState.upgrades_changed.connect(_rebuild_upgrades)
	GameState.points_changed.connect(_update_buttons)
	GameState.tick.connect(_update_buttons)
	
	_rebuild_upgrades()

func _format_number(value: int) -> String:
	if value >= 1000000000:
		return "%.2fB" % (value / 1000000000.0)
	elif value >= 1000000:
		return "%.2fM" % (value / 1000000.0)
	elif value >= 10000:
		return "%.1fK" % (value / 1000.0)
	else:
		return "%d" % value

func _on_header_pressed() -> void:
	is_expanded = not is_expanded
	content.visible = is_expanded
	header_button.text = "[-] UPGRADES" if is_expanded else "[+] UPGRADES"

func _rebuild_upgrades() -> void:
	# Clear existing
	for child in upgrades_container.get_children():
		child.queue_free()
	upgrade_rows.clear()
	
	# Create rows for all upgrades
	for upgrade_id in GameState.UPGRADE_ORDER:
		var row = _create_upgrade_row(upgrade_id)
		upgrades_container.add_child(row)
	
	cap_label.text = "Level cap: %d" % GameState.upgrade_cap
	_update_buttons()

func _create_upgrade_row(upgrade_id: String) -> Control:
	var container = VBoxContainer.new()
	container.name = upgrade_id + "_container"
	
	# Main button - compact format
	var button = Button.new()
	button.name = upgrade_id
	button.custom_minimum_size.y = 28
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))
	container.add_child(button)
	
	# Description label showing current -> next
	var desc = Label.new()
	desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	desc.add_theme_font_size_override("font_size", 10)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc)
	
	upgrade_rows[upgrade_id] = {button = button, desc = desc}
	return container

func _update_buttons(_value: int = 0) -> void:
	for upgrade_id in upgrade_rows:
		var row = upgrade_rows[upgrade_id]
		var button: Button = row.button
		var desc: Label = row.desc
		
		var level = GameState._get_upgrade_level(upgrade_id)
		var cost = GameState.get_upgrade_cost(upgrade_id)
		var at_cap = GameState.is_upgrade_at_cap(upgrade_id)
		var display_name = GameState._get_upgrade_name(upgrade_id)
		
		# Button: Lv | Name | Cost
		if at_cap:
			button.text = "Lv%d | %s | MAX" % [level, display_name]
			button.disabled = true
		else:
			button.text = "Lv%d | %s | %s pts" % [level, display_name, _format_number(cost)]
			button.disabled = not GameState.can_purchase_upgrade(upgrade_id)
		
		# Description: current -> next (or just current if maxed)
		var current = GameState.get_upgrade_value_display(upgrade_id)
		if at_cap:
			desc.text = _get_upgrade_desc(upgrade_id, current, "")
		else:
			var next = GameState.get_upgrade_next_value_display(upgrade_id)
			desc.text = _get_upgrade_desc(upgrade_id, current, next)
	
	cap_label.text = "Level cap: %d" % GameState.upgrade_cap

func _get_upgrade_desc(upgrade_id: String, current: String, next: String) -> String:
	match upgrade_id:
		"points_mod":
			if next.is_empty():
				return "Point multiplier: %s" % current
			return "Point multiplier: %s -> %s" % [current, next]
		"pack_discount":
			if next.is_empty():
				return "Pack discount: %s" % current
			return "Pack discount: %s -> %s" % [current, next]
		"critical_merge":
			if next.is_empty():
				return "Crit chance (+2 rank): %s" % current
			return "Crit chance (+2 rank): %s -> %s" % [current, next]
		"lucky_pack":
			if next.is_empty():
				return "Lucky R9 chance: %s" % current
			return "Lucky R9 chance: %s -> %s" % [current, next]
	return ""

func _on_upgrade_pressed(upgrade_id: String) -> void:
	if GameState.try_purchase_upgrade(upgrade_id):
		_update_buttons()
