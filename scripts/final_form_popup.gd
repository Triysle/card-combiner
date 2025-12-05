# scripts/final_form_popup.gd
class_name FinalFormPopup
extends CanvasLayer

## Final Form Popup - shows when submitting the final form of a species
## Displays collection progress

signal closed()

@onready var overlay: ColorRect = $Overlay
@onready var title_label: Label = $Overlay/CenterContainer/PopupBackground/VBox/TitleLabel
@onready var progress_label: Label = $Overlay/CenterContainer/PopupBackground/VBox/ProgressLabel
@onready var ok_button: Button = $Overlay/CenterContainer/PopupBackground/VBox/OkButton

# Animation timing
const OVERLAY_FADE_TIME := 0.2
const CONTENT_FADE_TIME := 0.3

func _ready() -> void:
	ok_button.pressed.connect(_on_ok_button_pressed)

func open() -> void:
	var submitted = GameState.get_submitted_form_count()
	var total = MonsterRegistry.get_total_form_count()
	progress_label.text = "Collection Progress: %d/%d" % [submitted, total]
	
	_animate_opening()

func _animate_opening() -> void:
	var tween = create_tween()
	
	# Fade in overlay
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.8), OVERLAY_FADE_TIME)
	
	# Fade in button
	tween.tween_property(ok_button, "modulate:a", 1.0, CONTENT_FADE_TIME)

func _on_ok_button_pressed() -> void:
	closed.emit()
	queue_free()
