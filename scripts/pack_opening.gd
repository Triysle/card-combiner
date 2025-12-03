class_name PackOpening
extends CanvasLayer

## Pack opening popup - reveals cards one by one with animations

signal closed

@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $Overlay/CenterContainer/VBox/TitleLabel
@onready var cards_container: Control = $Overlay/CenterContainer/VBox/CardsContainer
@onready var add_button: Button = $Overlay/CenterContainer/VBox/AddButton

const TIER_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

# Card colors by rank (matching slot.gd)
const RANK_COLORS: Array[Color] = [
	Color(0.56, 0.0, 1.0),    # 1 - Violet
	Color(0.29, 0.0, 0.51),   # 2 - Indigo
	Color(0.0, 0.0, 1.0),     # 3 - Blue
	Color(0.0, 0.5, 0.0),     # 4 - Green
	Color(1.0, 1.0, 0.0),     # 5 - Yellow
	Color(1.0, 0.65, 0.0),    # 6 - Orange
	Color(1.0, 0.0, 0.0),     # 7 - Red
	Color(0.1, 0.1, 0.1),     # 8 - Black
	Color(0.5, 0.5, 0.5),     # 9 - Grey
	Color(1.0, 1.0, 1.0),     # 10 - White
]

# Card back style (matching deck_pile.tscn)
const CARD_BACK_COLOR := Color(0.2, 0.25, 0.35, 1)
const CARD_BACK_SYMBOL_COLOR := Color(0.35, 0.4, 0.5, 1)

# Animation timing
const OVERLAY_FADE_TIME := 0.2
const CARD_SLIDE_TIME := 0.4
const CARD_SLIDE_STAGGER := 0.08
const PRE_FLIP_PAUSE := 0.3
const FLIP_DURATION := 0.3
const FLIP_DELAY := 0.35
const FINAL_CARD_EXTRA_PAUSE := 0.3
const FINAL_CARD_PULSE_DURATION := 0.15
const BUTTON_FADE_TIME := 0.3

# Card display size
const CARD_SIZE := Vector2(90, 120)
const CARD_SPACING := 16.0
const PACK_SIZE := 5

var cards: Array[Dictionary] = []
var card_displays: Array[Control] = []
var tier: int = 1

func _ready() -> void:
	add_button.pressed.connect(_on_add_button_pressed)
	add_button.modulate.a = 0.0

func open(pack_cards: Array[Dictionary], pack_tier: int) -> void:
	cards = pack_cards
	tier = pack_tier
	title_label.text = "Opening Tier %s Pack..." % TIER_NUMERALS[tier]
	
	# Create card displays (initially off-screen, face-down)
	_create_card_displays()
	
	# Start animation sequence
	_animate_opening()

func _create_card_displays() -> void:
	# Clear any existing
	for child in cards_container.get_children():
		child.queue_free()
	card_displays.clear()
	
	# Calculate total width for centering
	var total_width = (CARD_SIZE.x * PACK_SIZE) + (CARD_SPACING * (PACK_SIZE - 1))
	# Container is 530 wide, so center point is 265
	var container_center_x = cards_container.custom_minimum_size.x / 2.0
	var start_x = container_center_x - (total_width / 2.0)
	
	for i in range(cards.size()):
		var card_display = _create_card_display(cards[i], true)  # Start face-down
		var target_x = start_x + (i * (CARD_SIZE.x + CARD_SPACING))
		card_display.position = Vector2(target_x, 0)
		card_display.modulate.a = 0.0  # Start invisible for slide-in
		cards_container.add_child(card_display)
		card_displays.append(card_display)

func _create_card_display(card: Dictionary, face_down: bool) -> Control:
	var container = Control.new()
	container.custom_minimum_size = CARD_SIZE
	
	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.55, 1)
	
	if face_down:
		style.bg_color = CARD_BACK_COLOR
	else:
		var rank = card.get("rank", 1)
		var color_index = clampi(rank - 1, 0, RANK_COLORS.size() - 1)
		var base_color = RANK_COLORS[color_index]
		# Apply tier modifier (matching slot.gd style)
		var hsv_h = base_color.h
		var hsv_s = base_color.s * (0.6 + 0.04 * tier)
		var hsv_v = base_color.v * (0.7 + 0.03 * tier)
		style.bg_color = Color.from_hsv(hsv_h, clampf(hsv_s, 0.0, 1.0), clampf(hsv_v, 0.3, 1.0))
	
	panel.add_theme_stylebox_override("panel", style)
	container.add_child(panel)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	if face_down:
		# Card back - diamond symbol
		var symbol = Label.new()
		symbol.text = "♦"
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.add_theme_color_override("font_color", CARD_BACK_SYMBOL_COLOR)
		symbol.add_theme_font_size_override("font_size", 32)
		vbox.add_child(symbol)
	else:
		# Face up - show tier, rank, points
		var rank = card.get("rank", 1)
		
		var tier_lbl = Label.new()
		tier_lbl.text = "Tier %s" % TIER_NUMERALS[tier]
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl.add_theme_color_override("font_color", Color.WHITE)
		tier_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		tier_lbl.add_theme_constant_override("outline_size", 2)
		vbox.add_child(tier_lbl)
		
		var rank_lbl = Label.new()
		rank_lbl.text = "Rank %d" % rank
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_color_override("font_color", Color.WHITE)
		rank_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		rank_lbl.add_theme_constant_override("outline_size", 2)
		vbox.add_child(rank_lbl)
		
		var points_lbl = Label.new()
		points_lbl.text = "+%d/s" % GameState.get_card_points_value(card)
		points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		points_lbl.add_theme_color_override("font_color", Color.WHITE)
		points_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		points_lbl.add_theme_constant_override("outline_size", 2)
		vbox.add_child(points_lbl)
	
	return container

func _animate_opening() -> void:
	var tween = create_tween()
	
	# Calculate total width for centering (same as _create_card_displays)
	var total_width = (CARD_SIZE.x * PACK_SIZE) + (CARD_SPACING * (PACK_SIZE - 1))
	var container_center_x = cards_container.custom_minimum_size.x / 2.0
	var start_x = container_center_x - (total_width / 2.0)
	
	# Fade in overlay
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), OVERLAY_FADE_TIME)
	
	# Slide in cards from off-screen right to their target positions (staggered)
	for i in range(card_displays.size()):
		var card_display = card_displays[i]
		var delay = OVERLAY_FADE_TIME + (i * CARD_SLIDE_STAGGER)
		var target_x = start_x + (i * (CARD_SIZE.x + CARD_SPACING))
		
		# Start position off-screen right
		card_display.position.x = 800
		
		tween.parallel().tween_property(card_display, "modulate:a", 1.0, CARD_SLIDE_TIME).set_delay(delay)
		tween.parallel().tween_property(card_display, "position:x", target_x, CARD_SLIDE_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Wait for slides to complete, then flip cards
	var flip_start = OVERLAY_FADE_TIME + (card_displays.size() * CARD_SLIDE_STAGGER) + CARD_SLIDE_TIME + PRE_FLIP_PAUSE
	
	for i in range(card_displays.size()):
		var is_final = (i == card_displays.size() - 1)
		var extra_pause = FINAL_CARD_EXTRA_PAUSE if is_final else 0.0
		var delay = flip_start + (i * FLIP_DELAY) + extra_pause
		
		# Call flip function
		tween.tween_callback(_flip_card.bind(i)).set_delay(delay if i == 0 else FLIP_DELAY + extra_pause)
		
		# Pulse final card after flip
		if is_final:
			tween.tween_callback(_pulse_card.bind(i)).set_delay(FLIP_DURATION + 0.1)
	
	# Show button after all flips
	tween.tween_callback(_show_button).set_delay(0.3)

func _flip_card(index: int) -> void:
	var card_display = card_displays[index]
	
	# Set pivot to center for proper flip
	card_display.pivot_offset = CARD_SIZE / 2.0
	
	var tween = create_tween()
	
	# Scale X to 0 (card edge)
	tween.tween_property(card_display, "scale:x", 0.0, FLIP_DURATION / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Swap content at midpoint
	tween.tween_callback(_swap_card_content.bind(index))
	
	# Scale X back to 1
	tween.tween_property(card_display, "scale:x", 1.0, FLIP_DURATION / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _swap_card_content(index: int) -> void:
	var card_display = card_displays[index]
	var card = cards[index]
	
	# Get the panel and update its style
	var panel = card_display.get_node("Panel")
	var vbox = panel.get_node("VBox")
	
	# Clear old content
	for child in vbox.get_children():
		child.queue_free()
	
	# Update panel color to face-up color
	var rank = card.get("rank", 1)
	var color_index = clampi(rank - 1, 0, RANK_COLORS.size() - 1)
	var base_color = RANK_COLORS[color_index]
	var hsv_h = base_color.h
	var hsv_s = base_color.s * (0.6 + 0.04 * tier)
	var hsv_v = base_color.v * (0.7 + 0.03 * tier)
	
	var style = panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = Color.from_hsv(hsv_h, clampf(hsv_s, 0.0, 1.0), clampf(hsv_v, 0.3, 1.0))
	panel.add_theme_stylebox_override("panel", style)
	
	# Add face-up content
	var tier_lbl = Label.new()
	tier_lbl.text = "Tier %s" % TIER_NUMERALS[tier]
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_color_override("font_color", Color.WHITE)
	tier_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	tier_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(tier_lbl)
	
	var rank_lbl = Label.new()
	rank_lbl.text = "Rank %d" % rank
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_color_override("font_color", Color.WHITE)
	rank_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	rank_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(rank_lbl)
	
	var points_lbl = Label.new()
	points_lbl.text = "+%d/s" % GameState.get_card_points_value(card)
	points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_lbl.add_theme_color_override("font_color", Color.WHITE)
	points_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	points_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(points_lbl)

func _pulse_card(index: int) -> void:
	var card_display = card_displays[index]
	card_display.pivot_offset = CARD_SIZE / 2.0
	
	var tween = create_tween()
	tween.tween_property(card_display, "scale", Vector2(1.15, 1.15), FINAL_CARD_PULSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_display, "scale", Vector2(1.0, 1.0), FINAL_CARD_PULSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _show_button() -> void:
	add_button.visible = true
	title_label.text = "Tier %s Pack" % TIER_NUMERALS[tier]
	
	var tween = create_tween()
	tween.tween_property(add_button, "modulate:a", 1.0, BUTTON_FADE_TIME)

func _on_add_button_pressed() -> void:
	closed.emit()
	queue_free()
