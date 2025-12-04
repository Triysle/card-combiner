# scripts/pack_opening.gd
class_name PackOpening
extends CanvasLayer

## Pack opening popup - reveals cards one by one with animations

signal closed

@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $Overlay/CenterContainer/VBox/TitleLabel
@onready var cards_container: Control = $Overlay/CenterContainer/VBox/CardsContainer
@onready var add_button: Button = $Overlay/CenterContainer/VBox/AddButton

# Animation timing
const OVERLAY_FADE_TIME := 0.2
const CARD_SLIDE_TIME := 0.25
const CARD_SLIDE_STAGGER := 0.08
const PRE_FLIP_PAUSE := 0.0
const FLIP_DURATION := 0.3
const FLIP_DELAY := 0.35
const FINAL_CARD_EXTRA_PAUSE := 0.3
const FINAL_CARD_PULSE_DURATION := 0.15
const BUTTON_FADE_TIME := 0.3

# Card display
const CARD_SPACING := 16.0

var cards: Array[Dictionary] = []
var card_displays: Array[Control] = []
var tier: int = 1

func _ready() -> void:
	add_button.pressed.connect(_on_add_button_pressed)
	add_button.modulate.a = 0.0

func open(pack_cards: Array[Dictionary], pack_tier: int) -> void:
	cards = pack_cards
	tier = pack_tier
	title_label.text = "Opening Tier %s Pack..." % CardFactory.get_tier_numeral(tier)
	
	# Create card displays (initially off-screen, face-down)
	_create_card_displays()
	
	# Start animation sequence
	_animate_opening()

func _create_card_displays() -> void:
	# Clear any existing
	for child in cards_container.get_children():
		child.queue_free()
	card_displays.clear()
	
	var card_size = CardFactory.visuals.card_preview_size
	var pack_size = cards.size()
	
	# Calculate total width for centering
	var total_width = (card_size.x * pack_size) + (CARD_SPACING * (pack_size - 1))
	var container_center_x = cards_container.custom_minimum_size.x / 2.0
	var start_x = container_center_x - (total_width / 2.0)
	
	for i in range(cards.size()):
		var card_display = _create_card_display(cards[i], true)  # Start face-down
		var target_x = start_x + (i * (card_size.x + CARD_SPACING))
		card_display.position = Vector2(target_x, 0)
		card_display.modulate.a = 0.0  # Start invisible for slide-in
		# Set pivot to center for flip animation
		card_display.pivot_offset = card_size / 2.0
		cards_container.add_child(card_display)
		card_displays.append(card_display)

func _create_card_display(card: Dictionary, face_down: bool) -> Control:
	var card_size = CardFactory.visuals.card_preview_size
	var visuals = CardFactory.visuals
	
	var container = Control.new()
	container.custom_minimum_size = card_size
	
	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = visuals.card_corner_radius
	style.corner_radius_top_right = visuals.card_corner_radius
	style.corner_radius_bottom_right = visuals.card_corner_radius
	style.corner_radius_bottom_left = visuals.card_corner_radius
	style.border_width_left = visuals.card_border_width
	style.border_width_top = visuals.card_border_width
	style.border_width_right = visuals.card_border_width
	style.border_width_bottom = visuals.card_border_width
	style.border_color = Color(0.5, 0.5, 0.55, 1)
	
	if face_down:
		style.bg_color = visuals.card_back_color
	else:
		var rank = card.get("rank", 1)
		style.bg_color = CardFactory.get_card_color(tier, rank)
	
	panel.add_theme_stylebox_override("panel", style)
	container.add_child(panel)
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	if face_down:
		# Card back symbol
		var symbol = Label.new()
		symbol.text = visuals.card_back_symbol
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.add_theme_color_override("font_color", visuals.card_back_symbol_color)
		symbol.add_theme_font_size_override("font_size", 32)
		vbox.add_child(symbol)
	else:
		_add_card_face_content(vbox, card)
	
	return container

func _add_card_face_content(vbox: VBoxContainer, card: Dictionary) -> void:
	var rank = card.get("rank", 1)
	
	var tier_lbl = Label.new()
	tier_lbl.text = "Tier %s" % CardFactory.get_tier_numeral(tier)
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
	points_lbl.text = "+%d/s" % CardFactory.get_card_points_value(card)
	points_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_lbl.add_theme_color_override("font_color", Color.WHITE)
	points_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	points_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(points_lbl)

func _flip_card_to_face_up(card_display: Control, card: Dictionary) -> void:
	var panel = card_display.get_node("Panel")
	var vbox = panel.get_node("VBox")
	
	# Clear existing content
	for child in vbox.get_children():
		child.queue_free()
	
	# Update style
	var style = panel.get_theme_stylebox("panel").duplicate()
	style.bg_color = CardFactory.get_card_color(tier, card.get("rank", 1))
	panel.add_theme_stylebox_override("panel", style)
	
	# Add face-up content
	_add_card_face_content(vbox, card)

func _animate_opening() -> void:
	var tween = create_tween()
	var card_size = CardFactory.visuals.card_preview_size
	var pack_size = cards.size()
	
	# Calculate positions
	var total_width = (card_size.x * pack_size) + (CARD_SPACING * (pack_size - 1))
	var container_center_x = cards_container.custom_minimum_size.x / 2.0
	var start_x = container_center_x - (total_width / 2.0)
	
	# Fade in overlay
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), OVERLAY_FADE_TIME)
	
	# Slide in cards from off-screen right to their target positions (staggered)
	for i in range(card_displays.size()):
		var card_display = card_displays[i]
		var delay = OVERLAY_FADE_TIME + (i * CARD_SLIDE_STAGGER)
		var target_x = start_x + (i * (card_size.x + CARD_SPACING))
		
		# Start position (off-screen right)
		card_display.position.x = cards_container.custom_minimum_size.x + 50
		
		# Fade in and slide
		tween.parallel().tween_property(card_display, "modulate:a", 1.0, CARD_SLIDE_TIME).set_delay(delay)
		tween.parallel().tween_property(card_display, "position:x", target_x, CARD_SLIDE_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Flip cards one by one
	var flip_start = OVERLAY_FADE_TIME + (card_displays.size() * CARD_SLIDE_STAGGER) + PRE_FLIP_PAUSE
	
	for i in range(card_displays.size()):
		var card_display = card_displays[i]
		var card = cards[i]
		var flip_time = flip_start + (i * FLIP_DELAY)
		
		# Scale down (flip)
		tween.tween_property(card_display, "scale:x", 0.0, FLIP_DURATION / 2).set_delay(flip_time - tween.get_total_elapsed_time() if i == 0 else FLIP_DELAY - FLIP_DURATION)
		
		# Change to face-up at midpoint
		tween.tween_callback(_flip_card_to_face_up.bind(card_display, card))
		
		# Scale back up
		tween.tween_property(card_display, "scale:x", 1.0, FLIP_DURATION / 2)
	
	# Pulse final card and show button
	tween.tween_callback(_pulse_card.bind(card_displays.size() - 1)).set_delay(FINAL_CARD_EXTRA_PAUSE)
	tween.tween_callback(_show_button)

func _pulse_card(index: int) -> void:
	var card_display = card_displays[index]
	var card_size = CardFactory.visuals.card_preview_size
	card_display.pivot_offset = card_size / 2.0
	
	var tween = create_tween()
	tween.tween_property(card_display, "scale", Vector2(1.15, 1.15), FINAL_CARD_PULSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_display, "scale", Vector2(1.0, 1.0), FINAL_CARD_PULSE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _show_button() -> void:
	add_button.visible = true
	title_label.text = "Tier %s Pack" % CardFactory.get_tier_numeral(tier)
	
	var tween = create_tween()
	tween.tween_property(add_button, "modulate:a", 1.0, BUTTON_FADE_TIME)

func _on_add_button_pressed() -> void:
	closed.emit()
	queue_free()
