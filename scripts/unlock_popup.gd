# scripts/unlock_popup.gd
class_name UnlockPopup
extends CanvasLayer

## Unlock Popup - shows when a new form is unlocked via submission
## Displays face-down card that flips to reveal the new form

signal closed(card: Dictionary)

@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $Overlay/CenterContainer/PopupBackground/VBox/TitleLabel
@onready var card_container: Control = $Overlay/CenterContainer/PopupBackground/VBox/CardContainer
@onready var add_button: Button = $Overlay/CenterContainer/PopupBackground/VBox/AddButton

const CARD_DISPLAY_SCENE = preload("res://scenes/card_display.tscn")

# Animation timing
const OVERLAY_FADE_TIME := 0.2
const PRE_FLIP_PAUSE := 0.3
const FLIP_DURATION := 0.3
const BUTTON_FADE_TIME := 0.3

var unlocked_card: Dictionary = {}
var card_display: Control = null

func _ready() -> void:
	add_button.pressed.connect(_on_add_button_pressed)

func open(card: Dictionary) -> void:
	unlocked_card = card
	
	var card_name = CardFactory.get_card_name(card)
	title_label.text = "Unlocked %s!" % card_name
	
	_create_card_display()
	_animate_opening()

func _create_card_display() -> void:
	# Clear existing
	for child in card_container.get_children():
		child.queue_free()
	
	var card_size = CardFactory.visuals.card_preview_size
	
	# Create face-down card
	card_display = CARD_DISPLAY_SCENE.instantiate()
	card_display.setup_card_back(card_size)
	
	# Center in container
	var container_center_x = card_container.custom_minimum_size.x / 2.0
	card_display.position = Vector2(container_center_x - card_size.x / 2.0, 0)
	card_display.pivot_offset = card_size / 2.0
	card_display.modulate.a = 0.0
	
	card_container.add_child(card_display)

func _animate_opening() -> void:
	var tween = create_tween()
	
	# Fade in overlay
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), OVERLAY_FADE_TIME)
	
	# Fade in card
	tween.tween_property(card_display, "modulate:a", 1.0, OVERLAY_FADE_TIME)
	
	# Pause before flip
	tween.tween_interval(PRE_FLIP_PAUSE)
	
	# Flip animation
	tween.tween_property(card_display, "scale:x", 0.0, FLIP_DURATION / 2)
	tween.tween_callback(_flip_to_face_up)
	tween.tween_property(card_display, "scale:x", 1.0, FLIP_DURATION / 2)
	
	# Show button
	tween.tween_callback(_show_button)

func _flip_to_face_up() -> void:
	var card_size = CardFactory.visuals.card_preview_size
	card_display.setup(unlocked_card, card_size)

func _show_button() -> void:
	var tween = create_tween()
	tween.tween_property(add_button, "modulate:a", 1.0, BUTTON_FADE_TIME)

func _on_add_button_pressed() -> void:
	closed.emit(unlocked_card)
	queue_free()
