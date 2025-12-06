# scripts/settings_popup.gd
extends PopupPanel

## Settings popup - save, reset, credits

signal reset_requested
signal credits_requested

@onready var save_button: Button = %SaveButton
@onready var reset_button: Button = %ResetButton
@onready var version_label: Label = %VersionLabel
@onready var credits_button: Button = %CreditsButton

var reset_confirm_dialog: ConfirmationDialog

func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	
	version_label.text = "Version %s" % GameState.SAVE_VERSION
	
	# Create reset confirmation dialog
	reset_confirm_dialog = ConfirmationDialog.new()
	reset_confirm_dialog.title = "Confirm Reset"
	reset_confirm_dialog.dialog_text = "Are you sure you want to reset?\nAll progress will be lost!"
	reset_confirm_dialog.ok_button_text = "Reset"
	reset_confirm_dialog.cancel_button_text = "Cancel"
	reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	add_child(reset_confirm_dialog)

func open_at(button: Button) -> void:
	var button_rect = button.get_global_rect()
	position = Vector2(button_rect.position.x, button_rect.position.y + button_rect.size.y + 4)
	popup()

func _on_save_pressed() -> void:
	GameState.save_game()
	hide()

func _on_reset_pressed() -> void:
	hide()
	reset_confirm_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	reset_requested.emit()

func _on_credits_pressed() -> void:
	hide()
	credits_requested.emit()
