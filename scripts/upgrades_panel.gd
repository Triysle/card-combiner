extends PanelContainer

## Upgrades Panel - collapsible panel showing available upgrades

@onready var header_button: Button = $VBox/HeaderButton
@onready var content: VBoxContainer = $VBox/Content
@onready var upgrades_container: VBoxContainer = $VBox/Content/UpgradesContainer
@onready var cap_label: Label = $VBox/Content/CapLabel

var is_expanded: bool = true
var upgrade_buttons: Dictionary = {}  # upgrade_id -> Button

const UPGRADE_ORDER: Array[String] = ["point_gen", "pack_cost", "draw_speed", "tick_speed", "deck_value"]

const UPGRADE_DESCRIPTIONS: Dictionary = {
	"point_gen": "Multiplies point generation",
	"pack_cost": "Reduces booster pack cost",
	"draw_speed": "Faster card drawing",
	"tick_speed": "Faster point ticks",
	"deck_value": "Bonus from deck value"
}

func _ready() -> void:
	header_button.pressed.connect(_on_header_pressed)
	GameState.upgrades_changed.connect(_rebuild_upgrades)
	GameState.points_changed.connect(_update_buttons)
	GameState.tick.connect(_update_buttons)
	
	_rebuild_upgrades()
	_update_visibility()

func _update_visibility() -> void:
	# Only show if at least one upgrade is unlocked
	visible = GameState.upgrades_unlocked.size() > 0

func _on_header_pressed() -> void:
	is_expanded = not is_expanded
	content.visible = is_expanded
	header_button.text = "▼ UPGRADES" if is_expanded else "▶ UPGRADES"

func _rebuild_upgrades() -> void:
	# Clear existing buttons
	for child in upgrades_container.get_children():
		child.queue_free()
	upgrade_buttons.clear()
	
	# Create buttons for unlocked upgrades
	for upgrade_id in UPGRADE_ORDER:
		if GameState.is_upgrade_unlocked(upgrade_id):
			var btn_container = _create_upgrade_button(upgrade_id)
			upgrades_container.add_child(btn_container)
	
	# Update cap label
	cap_label.text = "Level cap: %d" % GameState.upgrade_cap
	
	_update_visibility()
	_update_buttons()

func _create_upgrade_button(upgrade_id: String) -> Control:
	var container = VBoxContainer.new()
	container.name = upgrade_id + "_container"
	
	# Main button
	var button = Button.new()
	button.name = upgrade_id
	button.custom_minimum_size.y = 40
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))
	container.add_child(button)
	upgrade_buttons[upgrade_id] = button
	
	# Description label
	var desc = Label.new()
	desc.text = UPGRADE_DESCRIPTIONS.get(upgrade_id, "")
	desc.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	desc.add_theme_font_size_override("font_size", 10)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(desc)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 4
	container.add_child(spacer)
	
	return container

func _update_buttons(_value: int = 0) -> void:
	for upgrade_id in upgrade_buttons:
		var button: Button = upgrade_buttons[upgrade_id]
		var cost = GameState.get_upgrade_cost(upgrade_id)
		var current_value = GameState.get_upgrade_value_display(upgrade_id)
		var at_cap = GameState.is_upgrade_at_cap(upgrade_id)
		
		var display_name = GameState._get_upgrade_name(upgrade_id)
		
		if at_cap:
			button.text = "%s: %s (MAX)" % [display_name, current_value]
			button.disabled = true
		else:
			var next_value = GameState.get_upgrade_next_value_display(upgrade_id)
			button.text = "%s: %s → %s (%d pts)" % [display_name, current_value, next_value, cost]
			button.disabled = not GameState.can_purchase_upgrade(upgrade_id)

func _on_upgrade_pressed(upgrade_id: String) -> void:
	if GameState.try_purchase_upgrade(upgrade_id):
		_update_buttons()
