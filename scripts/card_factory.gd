# scripts/card_factory.gd
extends Node

## Factory for creating card visual displays - autoload singleton

const CARD_DISPLAY_SCENE = preload("res://scenes/card_display.tscn")

var visuals: CardVisuals
var config: GameConfig

func _ready() -> void:
	# Load default resources - can be swapped at runtime
	visuals = load("res://resources/default_card_visuals.tres")
	config = load("res://resources/default_game_config.tres")

# === RESOURCE ACCESS ===

func set_visuals(new_visuals: CardVisuals) -> void:
	visuals = new_visuals

func set_config(new_config: GameConfig) -> void:
	config = new_config

# === CONVENIENCE PASSTHROUGHS ===

func get_tier_numeral(tier: int) -> String:
	return visuals.get_tier_numeral(tier)

func get_card_color(tier: int, rank: int) -> Color:
	return visuals.get_card_color(tier, rank)

func get_card_points_value(card: Dictionary) -> int:
	if card.is_empty():
		return 0
	return config.get_card_points_value(card.tier, card.rank)

func card_to_string(card: Dictionary) -> String:
	if card.is_empty():
		return "Empty"
	return "T%s R%d" % [get_tier_numeral(card.tier), card.rank]

# === CARD DISPLAY CREATION ===

func create_card_display(card: Dictionary, size_override: Vector2 = Vector2.ZERO) -> Control:
	var display = CARD_DISPLAY_SCENE.instantiate()
	display.setup(card, size_override if size_override != Vector2.ZERO else visuals.card_size)
	return display

func create_card_back_display(size_override: Vector2 = Vector2.ZERO) -> Control:
	var display = CARD_DISPLAY_SCENE.instantiate()
	display.setup_card_back(size_override if size_override != Vector2.ZERO else visuals.card_size)
	return display

# === DRAG PREVIEW ===

func create_drag_preview(card: Dictionary) -> Control:
	var size = visuals.card_preview_size
	
	var container = Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var preview = _build_card_panel(card, size)
	preview.position = -size / 2
	container.add_child(preview)
	
	return container

func _build_card_panel(card: Dictionary, size: Vector2) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tier = card.get("tier", 1)
	var rank = card.get("rank", 1)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = get_card_color(tier, rank)
	style.border_width_left = visuals.card_border_width
	style.border_width_top = visuals.card_border_width
	style.border_width_right = visuals.card_border_width
	style.border_width_bottom = visuals.card_border_width
	style.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style.corner_radius_top_left = visuals.card_corner_radius
	style.corner_radius_top_right = visuals.card_corner_radius
	style.corner_radius_bottom_right = visuals.card_corner_radius
	style.corner_radius_bottom_left = visuals.card_corner_radius
	panel.add_theme_stylebox_override("panel", style)
	
	# Content
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	
	var tier_label = Label.new()
	tier_label.text = "Tier %s" % get_tier_numeral(tier)
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_label.add_theme_color_override("font_color", Color.WHITE)
	tier_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tier_label.add_theme_constant_override("outline_size", 2)
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tier_label)
	
	var rank_label = Label.new()
	rank_label.text = "Rank %d" % rank
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_color_override("font_color", Color.WHITE)
	rank_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rank_label.add_theme_constant_override("outline_size", 2)
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rank_label)
	
	var points_label = Label.new()
	points_label.text = "+%d/s" % get_card_points_value(card)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_color_override("font_color", Color.WHITE)
	points_label.add_theme_color_override("font_outline_color", Color.BLACK)
	points_label.add_theme_constant_override("outline_size", 2)
	points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(points_label)
	
	return panel

# === CARD BACK ===

func create_card_back_panel(size: Vector2) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = visuals.card_back_color
	style.border_width_left = visuals.card_border_width
	style.border_width_top = visuals.card_border_width
	style.border_width_right = visuals.card_border_width
	style.border_width_bottom = visuals.card_border_width
	style.border_color = Color(0.5, 0.5, 0.55, 1.0)
	style.corner_radius_top_left = visuals.card_corner_radius
	style.corner_radius_top_right = visuals.card_corner_radius
	style.corner_radius_bottom_right = visuals.card_corner_radius
	style.corner_radius_bottom_left = visuals.card_corner_radius
	panel.add_theme_stylebox_override("panel", style)
	
	# Card back can use texture or symbol
	if visuals.card_back_texture:
		var tex_rect = TextureRect.new()
		tex_rect.texture = visuals.card_back_texture
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tex_rect)
	else:
		var symbol = Label.new()
		symbol.text = visuals.card_back_symbol
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		symbol.set_anchors_preset(Control.PRESET_FULL_RECT)
		symbol.add_theme_color_override("font_color", visuals.card_back_symbol_color)
		symbol.add_theme_font_size_override("font_size", int(size.y * 0.3))
		symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(symbol)
	
	return panel
