# scripts/how_to_play_popup.gd
extends PopupPanel

## How to Play popup - simple tutorial text

@onready var got_it_button: Button = %GotItButton

func _ready() -> void:
	got_it_button.pressed.connect(_on_got_it_pressed)

func open() -> void:
	popup_centered()

func _on_got_it_pressed() -> void:
	hide()
