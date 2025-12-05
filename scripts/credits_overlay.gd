# scripts/credits_overlay.gd
extends CanvasLayer

## Credits overlay - popup with clickable links

signal closed

@onready var overlay: ColorRect = $Overlay

const FADE_TIME := 0.2
const POPUP_TEXTURE = preload("res://assets/UI/panel_bg.svg")

const CREDITS_TEXT := """[center]CARD COMBINER

Created by Tee
with [url=https://godotengine.org/]Godot 4.5[/url] and [url=https://claude.ai/]Claude Opus 4.5[/url]

Art by [url=https://ci.itch.io/all-game-assets]Chequered Ink[/url]

Font: [url=https://fonts.google.com/specimen/Roboto+Slab]Roboto Slab[/url]

Playtesters
Alanox  Harbinger  Kittara  Malikav[/center]"""

func _ready() -> void:
	overlay.color = Color(0, 0, 0, 0)
	_build_ui()
	_animate_in()

func _build_ui() -> void:
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	# Popup background
	var popup_bg = NinePatchRect.new()
	popup_bg.texture = POPUP_TEXTURE
	popup_bg.patch_margin_left = 48
	popup_bg.patch_margin_top = 48
	popup_bg.patch_margin_right = 48
	popup_bg.patch_margin_bottom = 48
	popup_bg.custom_minimum_size = Vector2(500, 400)
	center.add_child(popup_bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	popup_bg.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var credits_label = RichTextLabel.new()
	credits_label.bbcode_enabled = true
	credits_label.text = CREDITS_TEXT
	credits_label.fit_content = true
	credits_label.scroll_active = false
	credits_label.custom_minimum_size.x = 400
	credits_label.add_theme_font_size_override("normal_font_size", 18)
	credits_label.add_theme_color_override("default_color", Color(0.2, 0.15, 0.1))
	credits_label.meta_clicked.connect(_on_link_clicked)
	vbox.add_child(credits_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 24
	vbox.add_child(spacer)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

func _on_link_clicked(meta: Variant) -> void:
	OS.shell_open(str(meta))

func _animate_in() -> void:
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.85), FADE_TIME)

func _on_close_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0), FADE_TIME)
	tween.tween_callback(queue_free)
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
