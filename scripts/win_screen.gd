# scripts/win_screen.gd
class_name WinScreen
extends CanvasLayer

## Win Screen - displays when player completes their entire collection

signal credits_requested()
signal reset_requested()

@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $Overlay/CenterContainer/PopupBackground/VBox/TitleLabel
@onready var message_label: Label = $Overlay/CenterContainer/PopupBackground/VBox/MessageLabel
@onready var credits_button: Button = $Overlay/CenterContainer/PopupBackground/VBox/ButtonsHBox/CreditsButton
@onready var reset_button: Button = $Overlay/CenterContainer/PopupBackground/VBox/ButtonsHBox/ResetButton

# Animation timing
const OVERLAY_FADE_TIME := 0.3
const CONTENT_STAGGER := 0.2

func _ready() -> void:
	credits_button.pressed.connect(_on_credits_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

func open() -> void:
	_animate_opening()

func _animate_opening() -> void:
	var tween = create_tween()
	
	# Fade in overlay
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), OVERLAY_FADE_TIME)
	
	# Fade in title
	tween.tween_property(title_label, "modulate:a", 1.0, CONTENT_STAGGER)
	
	# Fade in message
	tween.tween_property(message_label, "modulate:a", 1.0, CONTENT_STAGGER)
	
	# Fade in buttons
	tween.tween_property(credits_button, "modulate:a", 1.0, CONTENT_STAGGER)
	tween.parallel().tween_property(reset_button, "modulate:a", 1.0, CONTENT_STAGGER)

func _on_credits_pressed() -> void:
	credits_requested.emit()
	queue_free()

func _on_reset_pressed() -> void:
	reset_requested.emit()
	queue_free()
