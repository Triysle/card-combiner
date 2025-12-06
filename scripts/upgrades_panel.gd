# scripts/upgrades_panel.gd
extends PanelContainer

## Upgrades Panel - always expanded, description in button

@onready var content: VBoxContainer = %Content

# Upgrade button references
var upgrade_buttons: Dictionary = {}

# Upgrade type to node name mapping
const UPGRADE_NODES: Dictionary = {
	GameState.UpgradeType.POINTS_MULT: "PointsMult",
	GameState.UpgradeType.DRAW_SPEED: "DrawSpeed",
	GameState.UpgradeType.PACK_DISCOUNT: "PackDiscount",
	GameState.UpgradeType.CRITICAL_MERGE: "CriticalMerge",
	GameState.UpgradeType.FOIL_CHANCE: "FoilChance",
	GameState.UpgradeType.FOIL_BONUS: "FoilBonus"
}

const UPGRADE_NAMES: Dictionary = {
	GameState.UpgradeType.POINTS_MULT: "Points Doubler",
	GameState.UpgradeType.DRAW_SPEED: "Draw Speed",
	GameState.UpgradeType.PACK_DISCOUNT: "Pack Discount",
	GameState.UpgradeType.CRITICAL_MERGE: "Critical Merge",
	GameState.UpgradeType.FOIL_CHANCE: "Foil Chance",
	GameState.UpgradeType.FOIL_BONUS: "Foil Bonus"
}

func _ready() -> void:
	GameState.points_changed.connect(_update_all)
	GameState.hand_changed.connect(_update_all)
	
	# Get references to buttons
	for upgrade_type in UPGRADE_NODES:
		var node_name = UPGRADE_NODES[upgrade_type]
		var button = content.get_node_or_null(node_name)
		if button:
			upgrade_buttons[upgrade_type] = button
			button.pressed.connect(_on_upgrade_pressed.bind(upgrade_type))
	
	_update_all()

func _update_all(_value: int = 0) -> void:
	for upgrade_type in upgrade_buttons:
		_update_button(upgrade_type)

func _update_button(upgrade_type: GameState.UpgradeType) -> void:
	var button: Button = upgrade_buttons.get(upgrade_type)
	if not button:
		return
	
	var level = GameState.get_upgrade_level(upgrade_type)
	var cost = GameState.get_upgrade_cost(upgrade_type)
	var upgrade_name = UPGRADE_NAMES.get(upgrade_type, "Unknown")
	var maxed = cost < 0
	
	var desc = _get_description(upgrade_type, level, maxed)
	
	# Reset any custom styles first
	button.remove_theme_stylebox_override("normal")
	button.remove_theme_stylebox_override("hover")
	button.remove_theme_stylebox_override("disabled")
	
	# Button text: "Name - Cost\nDescription"
	if maxed:
		button.text = "%s - MAX\n%s" % [upgrade_name, desc]
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE
		# Use pressed style for maxed buttons (pushed-in look)
		var pressed_style = button.get_theme_stylebox("pressed")
		button.add_theme_stylebox_override("disabled", pressed_style)
	else:
		button.text = "%s - %s\n%s" % [upgrade_name, _format_number(cost), desc]
		var can_afford = GameState.can_buy_upgrade(upgrade_type)
		button.disabled = not can_afford
		button.focus_mode = Control.FOCUS_NONE if not can_afford else Control.FOCUS_ALL

func _get_description(upgrade_type: GameState.UpgradeType, level: int, maxed: bool) -> String:
	match upgrade_type:
		GameState.UpgradeType.POINTS_MULT:
			var current = int(pow(2, level))
			var next = int(pow(2, level + 1))
			if maxed:
				return "Multiplies points by %dx" % current
			return "Multiplies points by %dx -> %dx" % [current, next]
		
		GameState.UpgradeType.DRAW_SPEED:
			var speeds = [10.0, 5.0, 2.5, 1.25, 0.5]
			var current = speeds[mini(level, 4)]
			if maxed:
				return "Draw every %.1fs" % current
			var next = speeds[mini(level + 1, 4)]
			return "Draw every %.1fs -> %.1fs" % [current, next]
		
		GameState.UpgradeType.PACK_DISCOUNT:
			var current = int(pow(2, level))
			var next = int(pow(2, level + 1))
			if maxed:
				return "Pack cost divided by %d" % current
			return "Pack cost divided by %d -> %d" % [current, next]
		
		GameState.UpgradeType.CRITICAL_MERGE:
			var current = level * 2
			var next = (level + 1) * 2
			if maxed:
				return "%d%% chance for +2 ranks" % current
			return "%d%% -> %d%% chance for +2 ranks" % [current, next]
		
		GameState.UpgradeType.FOIL_CHANCE:
			var current = level * 5
			var next = (level + 1) * 5
			if maxed:
				return "%d%% chance for foil cards" % current
			return "%d%% -> %d%% foil chance" % [current, next]
		
		GameState.UpgradeType.FOIL_BONUS:
			var current = 2 + level
			var next = current + 1
			if maxed:
				return "Foil cards give %dx points" % current
			return "Foil cards give %dx -> %dx points" % [current, next]
	
	return ""

func _on_upgrade_pressed(upgrade_type: GameState.UpgradeType) -> void:
	if GameState.buy_upgrade(upgrade_type):
		_update_all()

func _format_number(value: int) -> String:
	if value >= 1000000000:
		@warning_ignore("integer_division")
		return "%dB" % (value / 1000000000)
	elif value >= 1000000:
		@warning_ignore("integer_division")
		return "%dM" % (value / 1000000)
	elif value >= 1000:
		@warning_ignore("integer_division")
		return "%dK" % (value / 1000)
	else:
		return "%d" % value
