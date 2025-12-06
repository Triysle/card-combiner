# scripts/upgrades_panel.gd
extends PanelContainer

## Upgrades Panel - always expanded, description in button

@onready var content: VBoxContainer = %Content

# Upgrade button references
var upgrade_buttons: Dictionary = {}
var progress_bars: Dictionary = {}  # Track progress bars per upgrade

# Upgrade type to node name mapping
const UPGRADE_NODES: Dictionary = {
	GameState.UpgradeType.POINTS_MOD: "PointsMod",
	GameState.UpgradeType.DRAW_SPEED: "DrawSpeed",
	GameState.UpgradeType.PACK_DISCOUNT: "PackDiscount",
	GameState.UpgradeType.COLLECTION_MOD: "CollectionMod",
	GameState.UpgradeType.FOIL_CHANCE: "FoilChance",
	GameState.UpgradeType.FOIL_BONUS: "FoilBonus"
}

const UPGRADE_NAMES: Dictionary = {
	GameState.UpgradeType.POINTS_MOD: "Points Boost",
	GameState.UpgradeType.DRAW_SPEED: "Draw Speed",
	GameState.UpgradeType.PACK_DISCOUNT: "Pack Discount",
	GameState.UpgradeType.COLLECTION_MOD: "Collection Boost",
	GameState.UpgradeType.FOIL_CHANCE: "Foil Chance",
	GameState.UpgradeType.FOIL_BONUS: "Foil Bonus"
}

const PROGRESS_BAR_HEIGHT: int = 3
const PROGRESS_BAR_CORNER_RADIUS: int = 4

func _ready() -> void:
	GameState.points_changed.connect(_update_all)
	GameState.hand_changed.connect(_update_all)
	
	# Get references to buttons and create progress bars
	for upgrade_type in UPGRADE_NODES:
		var node_name = UPGRADE_NODES[upgrade_type]
		var button = content.get_node_or_null(node_name)
		if button:
			upgrade_buttons[upgrade_type] = button
			button.pressed.connect(_on_upgrade_pressed.bind(upgrade_type))
			
			# Create progress bar for this button
			var progress_bar = _create_progress_bar(button)
			progress_bars[upgrade_type] = progress_bar
	
	_update_all()

func _create_progress_bar(button: Button) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.name = "CostProgress"
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	
	# Position at bottom of button
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -PROGRESS_BAR_HEIGHT - 3  # Account for button's bottom padding
	bar.offset_bottom = -3
	bar.offset_left = 3
	bar.offset_right = -3
	
	# Style: transparent background, white fill with rounded bottom corners
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color.TRANSPARENT
	bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1, 1, 1, 0.5)  # Semi-transparent white
	fill_style.corner_radius_bottom_left = PROGRESS_BAR_CORNER_RADIUS
	fill_style.corner_radius_bottom_right = PROGRESS_BAR_CORNER_RADIUS
	fill_style.corner_radius_top_left = 0
	fill_style.corner_radius_top_right = 0
	bar.add_theme_stylebox_override("fill", fill_style)
	
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	button.add_child(bar)
	return bar

func _update_all(_value: int = 0) -> void:
	for upgrade_type in upgrade_buttons:
		_update_button(upgrade_type)

func _update_button(upgrade_type: GameState.UpgradeType) -> void:
	var button: Button = upgrade_buttons.get(upgrade_type)
	var bar: ProgressBar = progress_bars.get(upgrade_type)
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
		
		# Hide progress bar when maxed
		if bar:
			bar.visible = false
	else:
		button.text = "%s - %s\n%s" % [upgrade_name, _format_number(cost), desc]
		var can_afford = GameState.can_buy_upgrade(upgrade_type)
		button.disabled = not can_afford
		button.focus_mode = Control.FOCUS_NONE if not can_afford else Control.FOCUS_ALL
		
		# Update progress bar
		if bar:
			bar.visible = not can_afford
			if not can_afford:
				var progress = clampf(float(GameState.points) / float(cost), 0.0, 1.0)
				bar.value = progress

func _get_description(upgrade_type: GameState.UpgradeType, level: int, maxed: bool) -> String:
	match upgrade_type:
		GameState.UpgradeType.POINTS_MOD:
			var current_bonus = level * 10
			var next_bonus = (level + 1) * 10
			if maxed:
				return "+%d%% total points" % current_bonus
			return "+%d%% -> +%d%% total points" % [current_bonus, next_bonus]
		
		GameState.UpgradeType.DRAW_SPEED:
			var current = maxf(10.0 / pow(2, level), 0.5)
			if maxed:
				return "Draw every %.2fs" % current
			var next = maxf(10.0 / pow(2, level + 1), 0.5)
			return "Draw every %.2fs -> %.2fs" % [current, next]
		
		GameState.UpgradeType.PACK_DISCOUNT:
			var current = mini(level, 90)
			if maxed:
				return "%d%% off pack cost" % current
			var next = mini(level + 1, 90)
			return "%d%% -> %d%% off pack cost" % [current, next]
		
		GameState.UpgradeType.COLLECTION_MOD:
			var current_bonus = level * 10
			var next_bonus = (level + 1) * 10
			if maxed:
				return "+%d%% collection points" % current_bonus
			return "+%d%% -> +%d%% collection points" % [current_bonus, next_bonus]
		
		GameState.UpgradeType.FOIL_CHANCE:
			var current = mini(level, 90)
			if maxed:
				return "%d%% foil chance per pack" % current
			var next = mini(level + 1, 90)
			return "%d%% -> %d%% foil chance per pack" % [current, next]
		
		GameState.UpgradeType.FOIL_BONUS:
			var current = mini(int(pow(2, level + 1)), 100)
			if maxed:
				return "Foil cards give %d× points" % current
			var next = mini(int(pow(2, level + 2)), 100)
			return "Foil cards give %d× -> %d× points" % [current, next]
	
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
