# scripts/pack_opening.gd
class_name PackOpening
extends CanvasLayer

## Pack opening popup - reveals cards one by one with animations

signal closed

@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $Overlay/CenterContainer/PopupBackground/VBox/TitleLabel
@onready var cards_container: Control = $Overlay/CenterContainer/PopupBackground/VBox/CardsContainer
@onready var add_button: Button = $Overlay/CenterContainer/PopupBackground/VBox/AddButton

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

const CARD_SPACING := 16.0

var cards: Array[Dictionary] = []
var card_displays: Array[Control] = []
var tier: int = 1

func _ready() -> void:
	add_button.pressed.connect(_on_add_button_pressed)

func open(pack_cards: Array[Dictionary], pack_tier: int) -> void:
	cards = pack_cards
	tier = pack_tier
	title_label.text = "Opening Pack..."
	
	_create_card_displays()
	_animate_opening()

func _create_card_displays() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	card_displays.clear()
	
	var card_size = CardFactory.visuals.card_preview_size
	var pack_size = cards.size()
	
	var total_width = (card_size.x * pack_size) + (CARD_SPACING * (pack_size - 1))
	var container_center_x = cards_container.custom_minimum_size.x / 2.0
	var start_x = container_center_x - (total_width / 2.0)
	
	for i in range(cards.size()):
		var card_display = _create_card_display(cards[i], true)
		var target_x = start_x + (i * (card_size.x + CARD_SPACING))
		card_display.position = Vector2(target_x, 0)
		card_display.modulate.a = 0.0
		card_display.pivot_offset = card_size / 2.0
		cards_container.add_child(card_display)
		card_displays.append(card_display)

func _create_card_display(card: Dictionary, face_down: bool) -> Control:
	var card_size = CardFactory.visuals.card_preview_size
	var card_display_scene = preload("res://scenes/card_display.tscn")
	var card_display = card_display_scene.instantiate()
	
	if face_down:
		card_display.setup_card_back(card_size)
	else:
		card_display.setup(card, card_size)
	
	card_display.set_meta("card_data", card)
	return card_display

func _flip_card_to_face_up(card_display: Control, card: Dictionary) -> void:
	var card_size = CardFactory.visuals.card_preview_size
	card_display.setup(card, card_size)

func _animate_opening() -> void:
	var tween = create_tween()
	var card_size = CardFactory.visuals.card_preview_size
	var pack_size = cards.size()
	
	var total_width = (card_size.x * pack_size) + (CARD_SPACING * (pack_size - 1))
	var container_center_x = cards_container.custom_minimum_size.x / 2.0
	var start_x = container_center_x - (total_width / 2.0)
	
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), OVERLAY_FADE_TIME)
	
	for i in range(card_displays.size()):
		var card_display = card_displays[i]
		var delay = OVERLAY_FADE_TIME + (i * CARD_SLIDE_STAGGER)
		var target_x = start_x + (i * (card_size.x + CARD_SPACING))
		
		card_display.position.x = cards_container.custom_minimum_size.x + 50
		
		tween.parallel().tween_property(card_display, "modulate:a", 1.0, CARD_SLIDE_TIME).set_delay(delay)
		tween.parallel().tween_property(card_display, "position:x", target_x, CARD_SLIDE_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var flip_start = OVERLAY_FADE_TIME + (card_displays.size() * CARD_SLIDE_STAGGER) + PRE_FLIP_PAUSE
	
	for i in range(card_displays.size()):
		var card_display = card_displays[i]
		var card = cards[i]
		var flip_time = flip_start + (i * FLIP_DELAY)
		
		tween.tween_property(card_display, "scale:x", 0.0, FLIP_DURATION / 2).set_delay(flip_time - tween.get_total_elapsed_time() if i == 0 else FLIP_DELAY - FLIP_DURATION)
		tween.tween_callback(_flip_card_to_face_up.bind(card_display, card))
		tween.tween_property(card_display, "scale:x", 1.0, FLIP_DURATION / 2)
	
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
	title_label.text = "Pack Opened!"
	
	var tween = create_tween()
	tween.tween_property(add_button, "modulate:a", 1.0, BUTTON_FADE_TIME)

func _on_add_button_pressed() -> void:
	closed.emit()
	queue_free()
