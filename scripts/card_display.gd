# scripts/card_display.gd
class_name CardDisplay
extends Panel

## Visual representation of a card with texture layers:
## ┌─────────────────────┐
## │ [NamePlate+Label]   │  ← Top layer: ribbon texture + name
## │                     │
## │   [Monster Sprite]  │  ← Middle layer: transparent PNG
## │                     │
## │ [InfoPlate+Labels]  │  ← Bottom layer: plate texture + MID/rank
## └─────────────────────┘
## [Background Texture]   ← Bottom layer: rank texture, tinted

# Node references - created dynamically
var background_texture: TextureRect
var monster_sprite: TextureRect
var name_plate: TextureRect
var name_label: Label
var info_plate: TextureRect
var mid_label: Label
var rank_label: Label
var card_back_container: CenterContainer
var card_back_symbol: Label
var border_frame: Panel

var card_data: Dictionary = {}
var is_card_back: bool = false

func _ready() -> void:
	_setup_nodes()
	set_process(false)  # Only enable when shader needs time updates

func _process(delta: float) -> void:
	# Update shader time uniform for animations
	if background_texture and background_texture.material is ShaderMaterial:
		var mat = background_texture.material as ShaderMaterial
		var current_time = mat.get_shader_parameter("time")
		if current_time != null:
			mat.set_shader_parameter("time", current_time + delta)

func _setup_nodes() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	
	# Background texture layer (inset to avoid corner bleed)
	background_texture = TextureRect.new()
	background_texture.name = "BackgroundTexture"
	background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_texture.offset_left = 3
	background_texture.offset_top = 3
	background_texture.offset_right = -3
	background_texture.offset_bottom = -3
	background_texture.stretch_mode = TextureRect.STRETCH_SCALE
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(background_texture)
	
	# Monster sprite layer (centered, preserves aspect)
	monster_sprite = TextureRect.new()
	monster_sprite.name = "MonsterSprite"
	monster_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	monster_sprite.anchor_top = 0.18
	monster_sprite.anchor_bottom = 0.82
	monster_sprite.anchor_left = 0.1
	monster_sprite.anchor_right = 0.9
	monster_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	monster_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(monster_sprite)
	
	# Name plate (ribbon at top)
	name_plate = TextureRect.new()
	name_plate.name = "NamePlate"
	name_plate.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_plate.offset_bottom = 28
	name_plate.stretch_mode = TextureRect.STRETCH_SCALE
	name_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(name_plate)
	
	# Name label (on top of plate)
	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_top = 0
	name_label.offset_bottom = 26
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	_apply_outline_to_label(name_label)
	add_child(name_label)
	
	# Info plate (at bottom)
	info_plate = TextureRect.new()
	info_plate.name = "InfoPlate"
	info_plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	info_plate.offset_top = -24
	info_plate.stretch_mode = TextureRect.STRETCH_SCALE
	info_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(info_plate)
	
	# MID label at bottom-left
	mid_label = Label.new()
	mid_label.name = "MIDLabel"
	mid_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mid_label.offset_left = 6
	mid_label.offset_top = -20
	mid_label.offset_bottom = -4
	mid_label.add_theme_font_size_override("font_size", 12)
	_apply_outline_to_label(mid_label)
	add_child(mid_label)
	
	# Rank label at bottom-right
	rank_label = Label.new()
	rank_label.name = "RankLabel"
	rank_label.anchor_left = 0.5
	rank_label.anchor_right = 1.0
	rank_label.anchor_top = 1.0
	rank_label.anchor_bottom = 1.0
	rank_label.offset_left = 0
	rank_label.offset_right = -6
	rank_label.offset_top = -20
	rank_label.offset_bottom = -4
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.add_theme_font_size_override("font_size", 12)
	_apply_outline_to_label(rank_label)
	add_child(rank_label)
	
	# Card back container
	card_back_container = CenterContainer.new()
	card_back_container.name = "CardBackContainer"
	card_back_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_back_container.visible = false
	add_child(card_back_container)
	
	card_back_symbol = Label.new()
	card_back_symbol.name = "CardBackSymbol"
	card_back_symbol.add_theme_font_size_override("font_size", 24)
	card_back_container.add_child(card_back_symbol)
	
	# Border frame (topmost layer - just draws border, no fill)
	border_frame = Panel.new()
	border_frame.name = "BorderFrame"
	border_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	border_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_width_top = 3
	border_style.border_width_bottom = 3
	border_style.border_width_left = 3
	border_style.border_width_right = 3
	border_style.border_color = Color(0.15, 0.15, 0.15)
	border_style.corner_radius_top_left = 6
	border_style.corner_radius_top_right = 6
	border_style.corner_radius_bottom_left = 6
	border_style.corner_radius_bottom_right = 6
	border_frame.add_theme_stylebox_override("panel", border_style)
	add_child(border_frame)

func _apply_outline_to_label(label: Label) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)

## Setup the card display with card data
## Second parameter can be bool (show_back) or Vector2 (card_size)
func setup(data: Dictionary, arg2 = null) -> void:
	card_data = data
	
	# Handle overloaded parameter
	if arg2 is bool:
		is_card_back = arg2
	elif arg2 is Vector2:
		custom_minimum_size = arg2
		is_card_back = false
	else:
		is_card_back = false
	
	_update_display()

## Setup the card to show its back (face-down)
func setup_card_back(card_size: Vector2 = Vector2.ZERO) -> void:
	card_data = {}
	is_card_back = true
	if card_size != Vector2.ZERO:
		custom_minimum_size = card_size
	_update_display()

## Refresh the display with current data
func refresh() -> void:
	_update_display()

func _update_display() -> void:
	if not is_node_ready():
		await ready
	
	if is_card_back:
		_show_card_back()
	elif CardFactory.is_empty_card(card_data):
		_show_empty()
	else:
		_show_card_front()

func _show_card_front() -> void:
	card_back_container.visible = false
	name_plate.visible = true
	name_label.visible = true
	info_plate.visible = true
	mid_label.visible = true
	rank_label.visible = true
	monster_sprite.visible = true
	background_texture.visible = true
	border_frame.visible = true
	
	# Restore inset for card front (in case we switched from back)
	background_texture.offset_left = 3
	background_texture.offset_top = 3
	background_texture.offset_right = -3
	background_texture.offset_bottom = -3
	
	var visuals = CardFactory.visuals
	var rank = card_data.rank
	var is_max = card_data.is_max
	
	# Species color for background/plates, rank for shader effect
	var species_color = CardFactory.get_card_species_color(card_data)
	
	# Background - try texture first, fall back to colored panel
	var bg_tex = null
	if visuals and visuals.has_method("get_rank_background"):
		bg_tex = visuals.get_rank_background(rank)
	
	# Check for rank shader
	var rank_shader: Shader = null
	if visuals and visuals.has_method("get_rank_shader"):
		rank_shader = visuals.get_rank_shader(rank)
	
	if bg_tex:
		background_texture.texture = bg_tex
		background_texture.visible = true
		
		# Apply shader if available
		if rank_shader:
			var shader_mat = ShaderMaterial.new()
			shader_mat.shader = rank_shader
			shader_mat.set_shader_parameter("rank", rank)
			shader_mat.set_shader_parameter("base_color", species_color)
			shader_mat.set_shader_parameter("time", 0.0)
			background_texture.material = shader_mat
			background_texture.modulate = Color.WHITE  # Shader handles color
			set_process(true)  # Enable _process for time updates
		else:
			background_texture.material = null
			background_texture.modulate = species_color  # No shader, use modulate
			set_process(false)
		
		# Use dark background style - border_frame handles the border
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1)
		bg_style.corner_radius_top_left = 6
		bg_style.corner_radius_top_right = 6
		bg_style.corner_radius_bottom_left = 6
		bg_style.corner_radius_bottom_right = 6
		add_theme_stylebox_override("panel", bg_style)
	else:
		background_texture.visible = false
		background_texture.material = null
		set_process(false)
		
		# Use colored panel as fallback
		var style = StyleBoxFlat.new()
		style.bg_color = species_color
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		add_theme_stylebox_override("panel", style)
	
	# Monster sprite
	var sprite_tex = CardFactory.get_card_sprite(card_data)
	if sprite_tex:
		monster_sprite.texture = sprite_tex
		monster_sprite.visible = true
	else:
		monster_sprite.visible = false
	
	# Name plate texture
	var name_tex = visuals.get("name_plate_texture") if visuals else null
	if name_tex:
		name_plate.texture = name_tex
		name_plate.visible = true
		name_plate.modulate = _get_plate_modulate(visuals, species_color)
	else:
		name_plate.visible = false
	
	# Info plate texture
	var info_tex = visuals.get("info_plate_texture") if visuals else null
	if info_tex:
		info_plate.texture = info_tex
		info_plate.visible = true
		info_plate.modulate = _get_plate_modulate(visuals, species_color)
	else:
		info_plate.visible = false
	
	# Labels
	name_label.text = CardFactory.get_card_name(card_data)
	mid_label.text = CardFactory.get_card_mid_form_string(card_data)
	
	if is_max:
		rank_label.text = "MAX"
		rank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	else:
		rank_label.text = "R%d" % rank
		rank_label.add_theme_color_override("font_color", Color.WHITE)
	
	# MAX cards get golden border
	_apply_border(is_max)

func _get_rank_color(visuals, rank: int) -> Color:
	if visuals and visuals.has_method("get_rank_color"):
		return visuals.get_rank_color(rank)
	# Hardcoded fallback
	var fallback_colors = [
		Color(0.56, 0.0, 1.0),    # 1 - Violet
		Color(0.29, 0.0, 0.51),   # 2 - Indigo
		Color(0.0, 0.0, 1.0),     # 3 - Blue
		Color(0.0, 0.5, 0.0),     # 4 - Green
		Color(1.0, 1.0, 0.0),     # 5 - Yellow
		Color(1.0, 0.65, 0.0),    # 6 - Orange
		Color(1.0, 0.0, 0.0),     # 7 - Red
		Color(0.1, 0.1, 0.1),     # 8 - Black
		Color(0.7, 0.7, 0.7),     # 9 - Grey
		Color(1.0, 0.85, 0.0),    # 10 - Gold (MAX)
	]
	var index = clampi(rank - 1, 0, fallback_colors.size() - 1)
	return fallback_colors[index]

func _get_plate_modulate(visuals, species_color: Color) -> Color:
	if not visuals:
		return Color.WHITE
	
	var tint_plates = visuals.get("tint_plates") if visuals else false
	if not tint_plates:
		return Color.WHITE
	
	var intensity = visuals.get("plate_tint_intensity") if visuals else 0.3
	
	# Blend white with species color based on intensity
	return Color.WHITE.lerp(species_color, intensity)

func _apply_border(is_max: bool) -> void:
	if is_max:
		# Golden border for MAX cards
		var style = get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style = style.duplicate()
			style.border_width_top = 3
			style.border_width_bottom = 3
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_color = Color(1.0, 0.85, 0.0)
			add_theme_stylebox_override("panel", style)

func _show_card_back() -> void:
	card_back_container.visible = true
	name_plate.visible = false
	name_label.visible = false
	info_plate.visible = false
	mid_label.visible = false
	rank_label.visible = false
	monster_sprite.visible = false
	
	var visuals = CardFactory.visuals
	
	# Check for card back texture
	var back_tex = visuals.get("card_back_texture") if visuals else null
	
	if back_tex:
		background_texture.texture = back_tex
		background_texture.modulate = Color.WHITE
		background_texture.visible = true
		# Remove inset for card back so it aligns with border
		background_texture.offset_left = 0
		background_texture.offset_top = 0
		background_texture.offset_right = 0
		background_texture.offset_bottom = 0
		# Hide border frame since card back has its own border
		border_frame.visible = false
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		background_texture.visible = false
		# Restore inset in case we switch back to front
		background_texture.offset_left = 3
		background_texture.offset_top = 3
		background_texture.offset_right = -3
		background_texture.offset_bottom = -3
		border_frame.visible = true
		var back_color = Color(0.2, 0.25, 0.35)
		if visuals and "card_back_color" in visuals:
			back_color = visuals.card_back_color
		var style = StyleBoxFlat.new()
		style.bg_color = back_color
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		add_theme_stylebox_override("panel", style)
	
	# Card back symbol
	var symbol = "[CC]"
	var symbol_color = Color(0.35, 0.4, 0.5)
	if visuals:
		if "card_back_symbol" in visuals:
			symbol = visuals.card_back_symbol
		if "card_back_symbol_color" in visuals:
			symbol_color = visuals.card_back_symbol_color
	card_back_symbol.text = symbol
	card_back_symbol.add_theme_color_override("font_color", symbol_color)

func _show_empty() -> void:
	card_back_container.visible = false
	name_plate.visible = false
	name_label.visible = false
	info_plate.visible = false
	mid_label.visible = false
	rank_label.visible = false
	monster_sprite.visible = false
	background_texture.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.5)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)

## Setup for collection viewer - shows card in different states
## state: "submitted" (face-up MAX with green border) or "not_collected" (card back)
func setup_collection(mid: int, form: int, state: String, card_size: Vector2) -> void:
	custom_minimum_size = card_size
	
	match state:
		"submitted":
			_show_collection_submitted(mid, form)
		_:  # "not_collected" or any other state
			_show_collection_not_collected()

func _show_collection_submitted(mid: int, form: int) -> void:
	# Show as a MAX card with green border
	var max_card = CardFactory.create_max_card(mid, form)
	setup(max_card, false)
	
	# Override border with green to indicate submitted
	if border_frame:
		var border_style = StyleBoxFlat.new()
		border_style.bg_color = Color.TRANSPARENT
		border_style.border_width_top = 3
		border_style.border_width_bottom = 3
		border_style.border_width_left = 3
		border_style.border_width_right = 3
		border_style.border_color = Color(0.4, 0.8, 0.3)  # Green
		border_style.corner_radius_top_left = 6
		border_style.corner_radius_top_right = 6
		border_style.corner_radius_bottom_left = 6
		border_style.corner_radius_bottom_right = 6
		border_frame.add_theme_stylebox_override("panel", border_style)

func _show_collection_not_collected() -> void:
	# Show card back (face-down) - same appearance for locked and unlocked
	setup_card_back(custom_minimum_size)
	modulate = Color.WHITE  # Full brightness
