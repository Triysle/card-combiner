# scripts/card_display.gd
class_name CardDisplay
extends Panel

## Visual representation of a card with texture layers:
## ┌─────────────────────┐
## │ [NamePlate+Label]   │  ← Top layer: ribbon texture + name
## │                     │
## │   [Monster Sprite]  │  ← Middle layer: transparent PNG
## │                     │
## │ [InfoPlate+Labels]  │  ← Bottom layer: plate texture + MID/rank stars
## └─────────────────────┘
## [Gradient Background]   ← Bottom layer: species gradient

# Preload shaders
const FOIL_SHADER = preload("res://resources/shaders/foil_shimmer.gdshader")
const PLATE_PLATINUM_SHADER = preload("res://resources/shaders/plate_platinum.gdshader")
const PLATE_DIAMOND_SHADER = preload("res://resources/shaders/plate_diamond.gdshader")

# Preload star texture
const STAR_TEXTURE = preload("res://assets/UI/star_filled.png")

# Plate colors by rank
const PLATE_COLORS = {
	1: Color(0.80, 0.50, 0.20),  # Bronze
	2: Color(0.65, 0.65, 0.70),  # Silver (muted)
	3: Color(1.00, 0.84, 0.00),  # Gold
	4: Color(0.90, 0.90, 0.95),  # Platinum (bright) - also uses shader
	5: Color(0.40, 0.80, 1.00),  # Diamond (MAX) - uses shader
}

# Node references - created dynamically
var background_rect: Control  # For gradient (can be ColorRect or TextureRect)
var gradient_texture: GradientTexture2D
var monster_sprite: TextureRect
var name_plate: TextureRect
var name_label: Label
var info_plate: TextureRect
var mid_label: Label
var rank_container: HBoxContainer  # For stars or MAX label
var card_back_container: CenterContainer
var card_back_symbol: Label
var border_frame: Panel
var foil_overlay: ColorRect  # Overlay for foil shimmer effect

# Foil container for shader application
var foil_content_container: Control

var card_data: Dictionary = {}
var is_card_back: bool = false

# Per-instance randomization for foil effect
var _foil_time_offset: float = 0.0
var _foil_speed_multiplier: float = 1.0

func _ready() -> void:
	_setup_nodes()
	set_process(false)  # Only enable when shader needs time updates
	
	# Randomize foil timing per instance
	_foil_time_offset = randf() * 10.0  # Random start point in the animation
	_foil_speed_multiplier = randf_range(0.8, 1.0)  # Vary speed

func _process(delta: float) -> void:
	# Update shader time uniforms for animations
	_update_shader_time(name_plate, delta)
	_update_shader_time(info_plate, delta)
	
	# Update foil shader time if active (with per-instance variation)
	if foil_overlay and foil_overlay.material is ShaderMaterial:
		var mat = foil_overlay.material as ShaderMaterial
		var current_time = mat.get_shader_parameter("time")
		if current_time != null:
			mat.set_shader_parameter("time", current_time + delta * _foil_speed_multiplier)

func _update_shader_time(node: Control, delta: float) -> void:
	if node and node.material is ShaderMaterial:
		var mat = node.material as ShaderMaterial
		var current_time = mat.get_shader_parameter("time")
		if current_time != null:
			mat.set_shader_parameter("time", current_time + delta)

func _setup_nodes() -> void:
	# Clear any existing children
	for child in get_children():
		child.queue_free()
	
	# Foil content container - wraps background and sprite for single shader
	foil_content_container = Control.new()
	foil_content_container.name = "FoilContentContainer"
	foil_content_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	foil_content_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(foil_content_container)
	
	# Background gradient (inside foil container) - placeholder, replaced in _show_card_front
	background_rect = null
	
	# Monster sprite layer (inside foil container)
	monster_sprite = TextureRect.new()
	monster_sprite.name = "MonsterSprite"
	monster_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	monster_sprite.anchor_top = 0.18
	monster_sprite.anchor_bottom = 0.82
	monster_sprite.anchor_left = 0.1
	monster_sprite.anchor_right = 0.9
	monster_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	monster_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foil_content_container.add_child(monster_sprite)
	
	# Name plate (ribbon at top) - outside foil container
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
	
	# Rank container at bottom-right (HBox for stars or Label for MAX)
	rank_container = HBoxContainer.new()
	rank_container.name = "RankContainer"
	rank_container.anchor_left = 0.5
	rank_container.anchor_right = 1.0
	rank_container.anchor_top = 1.0
	rank_container.anchor_bottom = 1.0
	rank_container.offset_left = 0
	rank_container.offset_right = -6
	rank_container.offset_top = -20
	rank_container.offset_bottom = -4
	rank_container.alignment = BoxContainer.ALIGNMENT_END
	rank_container.add_theme_constant_override("separation", 1)
	add_child(rank_container)
	
# Foil overlay (shimmer effect layer - inside foil_content_container, after sprite)
	foil_overlay = ColorRect.new()
	foil_overlay.name = "FoilOverlay"
	foil_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	foil_overlay.color = Color.TRANSPARENT
	foil_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foil_overlay.visible = false
	foil_content_container.add_child(foil_overlay)  # Add to foil container, not main panel
	
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
	rank_container.visible = true
	monster_sprite.visible = true
	border_frame.visible = true
	foil_content_container.visible = true
	
	var visuals = CardFactory.visuals
	var rank = card_data.rank
	var is_max = card_data.is_max
	var is_foil = card_data.get("is_foil", false)
	
	# Species colors for gradient background
	var base_color = CardFactory.get_card_species_color(card_data)
	var secondary_color = CardFactory.get_card_secondary_color(card_data)
	var gradient_type = CardFactory.get_card_gradient_type(card_data)
	
	# Setup gradient background
	_setup_gradient_background(base_color, secondary_color, gradient_type)
	
	# Setup foil effect if applicable
	_setup_foil_effect(is_foil)
	
	# Monster sprite
	var sprite_tex = CardFactory.get_card_sprite(card_data)
	if sprite_tex:
		monster_sprite.texture = sprite_tex
		monster_sprite.visible = true
	else:
		monster_sprite.visible = false
	
	# Name plate texture with rank-based styling
	var name_tex = visuals.get("name_plate_texture") if visuals else null
	if name_tex:
		name_plate.texture = name_tex
		name_plate.visible = true
		_apply_plate_style(name_plate, rank)
	else:
		name_plate.visible = false
	
	# Info plate texture with rank-based styling
	var info_tex = visuals.get("info_plate_texture") if visuals else null
	if info_tex:
		info_plate.texture = info_tex
		info_plate.visible = true
		_apply_plate_style(info_plate, rank)
	else:
		info_plate.visible = false
	
	# Labels
	name_label.text = CardFactory.get_card_name(card_data)
	mid_label.text = CardFactory.get_card_mid_form_string(card_data)
	
	# Rank display (stars or MAX)
	_setup_rank_display(rank, is_max)
	
	# Dark background style for the panel itself
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", bg_style)
	
	# MAX cards get golden border
	_apply_border(is_max)
	
	# Enable processing if we have animated shaders
	set_process(_needs_shader_updates(rank, is_foil))

func _needs_shader_updates(rank: int, is_foil: bool) -> bool:
	# Platinum (4) and MAX (5) have animated plate shaders
	# Foil cards have animated foil shader
	return rank >= 4 or is_foil

func _setup_gradient_background(base_color: Color, secondary_color: Color, gradient_type: String) -> void:
	# Create gradient
	var gradient = Gradient.new()
	gradient.set_color(0, base_color)
	gradient.set_color(1, secondary_color)
	
	# Create gradient texture
	gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 64
	gradient_texture.height = 64
	
	# Set fill type based on gradient_type
	match gradient_type:
		"linear_horizontal":
			gradient_texture.fill = GradientTexture2D.FILL_LINEAR
			gradient_texture.fill_from = Vector2(0, 0.5)
			gradient_texture.fill_to = Vector2(1, 0.5)
		"linear_vertical":
			gradient_texture.fill = GradientTexture2D.FILL_LINEAR
			gradient_texture.fill_from = Vector2(0.5, 0)
			gradient_texture.fill_to = Vector2(0.5, 1)
		"linear_diagonal_down":
			gradient_texture.fill = GradientTexture2D.FILL_LINEAR
			gradient_texture.fill_from = Vector2(0, 0)
			gradient_texture.fill_to = Vector2(1, 1)
		"linear_diagonal_up":
			gradient_texture.fill = GradientTexture2D.FILL_LINEAR
			gradient_texture.fill_from = Vector2(0, 1)
			gradient_texture.fill_to = Vector2(1, 0)
		"radial_center":
			gradient_texture.fill = GradientTexture2D.FILL_RADIAL
			gradient_texture.fill_from = Vector2(0.5, 0.5)
			gradient_texture.fill_to = Vector2(1, 0.5)
		"radial_corner":
			gradient_texture.fill = GradientTexture2D.FILL_RADIAL
			gradient_texture.fill_from = Vector2(0, 0)
			gradient_texture.fill_to = Vector2(1, 1)
		"diamond":
			gradient_texture.fill = GradientTexture2D.FILL_SQUARE
			gradient_texture.fill_from = Vector2(0.5, 0.5)
			gradient_texture.fill_to = Vector2(1, 0.5)
		_:
			gradient_texture.fill = GradientTexture2D.FILL_LINEAR
			gradient_texture.fill_from = Vector2(0, 0)
			gradient_texture.fill_to = Vector2(1, 1)
	
	# Apply to background using a TextureRect instead of ColorRect
	# Replace ColorRect with TextureRect for gradient
	if background_rect:
		background_rect.queue_free()
	
	var bg_tex_rect = TextureRect.new()
	bg_tex_rect.name = "BackgroundRect"
	bg_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex_rect.offset_left = 3
	bg_tex_rect.offset_top = 3
	bg_tex_rect.offset_right = -3
	bg_tex_rect.offset_bottom = -3
	bg_tex_rect.texture = gradient_texture
	bg_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# Insert at beginning of foil container
	foil_content_container.add_child(bg_tex_rect)
	foil_content_container.move_child(bg_tex_rect, 0)
	background_rect = bg_tex_rect

func _setup_foil_effect(is_foil: bool) -> void:
	if is_foil:
		# Check if we already have a foil shader running - don't restart it
		if foil_overlay.visible and foil_overlay.material is ShaderMaterial:
			var existing_shader = (foil_overlay.material as ShaderMaterial).shader
			if existing_shader == FOIL_SHADER:
				return  # Already running, don't restart
		
		# Create new shader material
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = FOIL_SHADER
		shader_mat.set_shader_parameter("time", _foil_time_offset)
		shader_mat.set_shader_parameter("shimmer_speed", 0.6 * _foil_speed_multiplier)
		shader_mat.set_shader_parameter("shimmer_intensity", 0.35)
		shader_mat.set_shader_parameter("sparkle_density", 0.96)
		foil_overlay.material = shader_mat
		foil_overlay.visible = true
	else:
		foil_overlay.material = null
		foil_overlay.visible = false

func _apply_plate_style(plate: TextureRect, rank: int) -> void:
	var plate_color = PLATE_COLORS.get(rank, Color.WHITE)
	
	# Clear existing material
	plate.material = null
	
	match rank:
		4:  # Platinum - use shimmer shader
			var shader_mat = ShaderMaterial.new()
			shader_mat.shader = PLATE_PLATINUM_SHADER
			shader_mat.set_shader_parameter("time", 0.0)
			shader_mat.set_shader_parameter("base_tint", plate_color)
			plate.material = shader_mat
			plate.modulate = Color.WHITE  # Shader handles color
		5:  # MAX/Diamond - use glow shader
			var shader_mat = ShaderMaterial.new()
			shader_mat.shader = PLATE_DIAMOND_SHADER
			shader_mat.set_shader_parameter("time", 0.0)
			shader_mat.set_shader_parameter("diamond_color", plate_color)
			plate.material = shader_mat
			plate.modulate = Color.WHITE  # Shader handles color
		_:  # Bronze, Silver, Gold - simple color modulate
			plate.modulate = plate_color

func _setup_rank_display(rank: int, is_max: bool) -> void:
	# Clear existing rank display
	for child in rank_container.get_children():
		child.queue_free()
	
	if is_max:
		# MAX label (bold italic)
		var max_label = Label.new()
		max_label.text = "MAX"
		max_label.add_theme_font_size_override("font_size", 12)
		max_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		max_label.add_theme_color_override("font_outline_color", Color.BLACK)
		max_label.add_theme_constant_override("outline_size", 3)
		# Note: Bold/italic would require a font variation, keeping as-is for now
		rank_container.add_child(max_label)
	else:
		# Star icons (rank 1-4)
		var star_size = 11
		for i in range(rank):
			var star = TextureRect.new()
			star.texture = STAR_TEXTURE
			star.custom_minimum_size = Vector2(star_size, star_size)
			star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			# Stars are always gold
			star.modulate = _get_star_color(rank)
			rank_container.add_child(star)

func _get_star_color(_rank: int) -> Color:
	# Stars are always gold/yellow regardless of rank
	return Color(1.0, 0.85, 0.0)

func _apply_border(_is_max: bool) -> void:
	var border_style = border_frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	border_style.border_color = Color(0.15, 0.15, 0.15)
	border_style.border_width_top = 3
	border_style.border_width_bottom = 3
	border_style.border_width_left = 3
	border_style.border_width_right = 3
	border_frame.add_theme_stylebox_override("panel", border_style)

func _show_card_back() -> void:
	card_back_container.visible = true
	name_plate.visible = false
	name_label.visible = false
	info_plate.visible = false
	mid_label.visible = false
	rank_container.visible = false
	monster_sprite.visible = false
	foil_content_container.visible = false
	foil_overlay.visible = false
	set_process(false)
	
	var visuals = CardFactory.visuals
	
	# Check for card back texture
	var back_tex = visuals.get("card_back_texture") if visuals else null
	
	if back_tex:
		# Use TextureRect for card back
		if background_rect:
			background_rect.queue_free()
		
		var back_rect = TextureRect.new()
		back_rect.name = "BackgroundRect"
		back_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		back_rect.texture = back_tex
		back_rect.stretch_mode = TextureRect.STRETCH_SCALE
		back_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(back_rect)
		move_child(back_rect, 0)
		background_rect = back_rect
		
		# Hide border frame since card back has its own border
		border_frame.visible = false
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
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
	rank_container.visible = false
	monster_sprite.visible = false
	foil_content_container.visible = false
	foil_overlay.visible = false
	set_process(false)
	
	if background_rect:
		background_rect.queue_free()
		background_rect = null
	
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
	# Show as a MAX card with green border (MAX is always foil)
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
