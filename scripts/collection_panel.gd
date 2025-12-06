# scripts/collection_panel.gd
extends PanelContainer

## Collection panel - shows collection viewer button, rate display, and submit slot

signal open_requested
signal submission_requested(card: Dictionary)  # main.gd handles the flow

const CARD_DISPLAY_SCENE = preload("res://scenes/card_display.tscn")

@onready var open_button: Button = %OpenButton
@onready var rate_label: Label = %RateLabel
@onready var slot: Panel = %Slot
@onready var empty_label: Label = %EmptyLabel
@onready var card_container: Control = %CardContainer
@onready var add_button: Button = %AddButton

var current_card: Dictionary = {}

func _ready() -> void:
	open_button.pressed.connect(_on_open_pressed)
	add_button.pressed.connect(_on_add_pressed)
	slot.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	GameState.collection_changed.connect(_update_display)
	GameState.tick.connect(_update_rate_display)
	_update_display()
	_update_rate_display()

func _on_open_pressed() -> void:
	open_requested.emit()

func _update_display() -> void:
	current_card = GameState.get_submit_slot()
	
	# Clear existing card display
	for child in card_container.get_children():
		child.queue_free()
	
	if CardFactory.is_valid_card(current_card):
		# Show card
		empty_label.visible = false
		card_container.visible = true
		
		var card_display = CARD_DISPLAY_SCENE.instantiate()
		card_display.setup(current_card, Vector2(116, 156))
		card_container.add_child(card_display)
		
		add_button.disabled = false
	else:
		# Show empty state
		empty_label.visible = true
		card_container.visible = false
		add_button.disabled = true
	
	_update_rate_display()

func _update_rate_display() -> void:
	var rate = GameState.get_collection_points_rate()
	rate_label.text = "+%s/s" % _format_number(rate)

func _format_number(value: int) -> String:
	if value >= 1000000000:
		return "%.1fB" % (value / 1000000000.0)
	elif value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	elif value >= 1000:
		return "%.1fK" % (value / 1000.0)
	else:
		return "%d" % value

func _get_drag_data(_pos: Vector2) -> Variant:
	if not CardFactory.is_valid_card(current_card):
		return null
	
	var preview = CARD_DISPLAY_SCENE.instantiate()
	preview.setup(current_card, Vector2(100, 130))
	slot.set_drag_preview(preview)
	
	return {source = "submit", card = current_card}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	
	var card = data.get("card", {})
	if not CardFactory.is_valid_card(card):
		return false
	
	# Only accept MAX cards
	if not card.is_max:
		return false
	
	# Check if already submitted
	if GameState.is_form_submitted(card.mid, card.form):
		return false
	
	return true

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var card = data.get("card", {})
	var source = data.get("source", "")
	
	# Remove from source
	if source == "hand":
		var source_slot = data.get("slot")
		if source_slot:
			source_slot.clear_card()
	elif source == "discard":
		GameState.take_from_discard()
	
	# Return current card to discard if any
	if CardFactory.is_valid_card(current_card):
		GameState.add_to_discard(current_card)
	
	# Set new card
	current_card = card
	GameState.set_submit_slot(card)
	_update_display()

func _on_add_pressed() -> void:
	if not GameState.can_submit():
		return
	
	# Emit signal with card data - main.gd will handle the flow
	submission_requested.emit(current_card.duplicate())
