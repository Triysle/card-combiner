# scripts/discard_pile.gd
class_name DiscardPile
extends VBoxContainer

## The discard pile - shows top card, can be dragged from

@onready var slot_panel: Panel = $SlotPanel
@onready var count_label: Label = $SlotPanel/CountLabel
@onready var card_container: Control = $SlotPanel/CardContainer
@onready var drop_indicator: ColorRect = $SlotPanel/DropIndicator

var _is_drag_origin: bool = false
var _card_display: Control = null

const CARD_DISPLAY_SCENE = preload("res://scenes/card_display.tscn")

func _ready() -> void:
	GameState.discard_changed.connect(_update_display)
	drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	_update_display()

func _update_display() -> void:
	var card = GameState.get_top_discard()
	var pile_size = GameState.discard_pile.size()
	
	count_label.text = "(%d)" % pile_size
	
	if not CardFactory.is_valid_card(card) or _is_drag_origin:
		card_container.visible = false
	else:
		card_container.visible = true
		_update_card_display(card)

func _update_card_display(card: Dictionary) -> void:
	# Remove existing card display
	if _card_display:
		_card_display.queue_free()
		_card_display = null
	
	# Create new CardDisplay - sized to fill the card container area
	_card_display = CARD_DISPLAY_SCENE.instantiate()
	_card_display.setup(card, Vector2(116, 152))
	_card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.add_child(_card_display)

# === Drag and Drop ===

func _create_drag_preview(card: Dictionary) -> Control:
	var card_display_scene = preload("res://scenes/card_display.tscn")
	var preview = card_display_scene.instantiate()
	preview.setup(card, Vector2(100, 130))
	return preview

func _get_drag_data(_pos: Vector2) -> Variant:
	var card = GameState.get_top_discard()
	if CardFactory.is_empty_card(card):
		return null
	
	_is_drag_origin = true
	_update_display()
	
	var preview = _create_drag_preview(card)
	slot_panel.set_drag_preview(preview)
	
	return {source = "discard", card = card}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if _is_drag_origin:
			_is_drag_origin = false
			_update_display()
		drop_indicator.visible = false

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		drop_indicator.visible = false
		return false
	
	var source = data.get("source", "")
	if source == "discard":
		drop_indicator.visible = false
		return false  # Can't drop discard on itself
	
	# Can drop hand cards here to discard them
	if source == "hand":
		drop_indicator.visible = true
		drop_indicator.color = CardFactory.visuals.drop_discard_color
		return true
	
	drop_indicator.visible = false
	return false

func _drop_data(_pos: Vector2, data: Variant) -> void:
	drop_indicator.visible = false
	
	if not data is Dictionary:
		return
	
	var source = data.get("source", "")
	var source_slot = data.get("slot")
	var card = data.get("card", {})
	
	if source == "hand" and source_slot is Slot:
		# Discard the card from hand
		GameState.set_hand_slot(source_slot.slot_index, {})
		GameState.add_to_discard(card)
		source_slot.clear_card()
