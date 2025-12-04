# scripts/discard_pile.gd
class_name DiscardPile
extends Panel

## The discard pile - shows top card, can be dragged from

@onready var empty_label: Label = $EmptyLabel
@onready var count_label: Label = $CountLabel
@onready var card_container: Control = $CardContainer
@onready var card_background: ColorRect = $CardContainer/CardBackground
@onready var tier_label: Label = $CardContainer/VBox/TierLabel
@onready var rank_label: Label = $CardContainer/VBox/RankLabel
@onready var output_label: Label = $CardContainer/VBox/OutputLabel
@onready var drop_indicator: ColorRect = $DropIndicator

var _is_drag_origin: bool = false

func _ready() -> void:
	GameState.discard_changed.connect(_update_display)
	drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_display()

func _update_display() -> void:
	var card = GameState.peek_discard()
	var pile_size = GameState.discard_pile.size()
	
	count_label.text = "(%d)" % pile_size
	
	if card.is_empty() or _is_drag_origin:
		empty_label.visible = true
		card_container.visible = false
	else:
		empty_label.visible = false
		card_container.visible = true
		_update_card_display(card)

func _update_card_display(card: Dictionary) -> void:
	var rank = card.get("rank", 1)
	var tier = card.get("tier", 1)
	
	tier_label.text = "Tier %s" % CardFactory.get_tier_numeral(tier)
	rank_label.text = "Rank %d" % rank
	output_label.text = "+%d/s" % GameState.get_card_points_value(card)
	
	card_background.color = CardFactory.get_card_color(tier, rank)

# === Drag and Drop ===

func _get_drag_data(_pos: Vector2) -> Variant:
	var card = GameState.peek_discard()
	if card.is_empty():
		return null
	
	_is_drag_origin = true
	_update_display()
	
	var preview = CardFactory.create_drag_preview(card)
	set_drag_preview(preview)
	
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
	
	# Can drop hand cards or milestone cards here to discard them
	if source == "hand" or source == "milestone":
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
		GameState.clear_hand_slot(source_slot.slot_index)
		GameState.add_to_discard(card)
		source_slot.clear_card()
		GameState.log_event("Discarded %s" % CardFactory.card_to_string(card))
	elif source == "milestone" and source_slot is MilestoneSlot:
		# Discard the card from milestone
		GameState.clear_milestone_slot(source_slot.slot_index)
		GameState.add_to_discard(card)
		source_slot.clear_card()
		GameState.log_event("Discarded %s from milestone" % CardFactory.card_to_string(card))
