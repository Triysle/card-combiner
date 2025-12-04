# scripts/milestone_slot.gd
class_name MilestoneSlot
extends Panel

## A milestone slot that accepts specific cards as keys

signal card_dropped(slot: MilestoneSlot, card: Dictionary)
signal card_removed(slot: MilestoneSlot)

var slot_index: int = -1
var required_card: Dictionary = {}  # {tier, rank} that this slot needs
var current_card: Dictionary = {}   # Currently slotted card (if any)

enum DropState { NONE, VALID, INVALID }
var _drop_state: DropState = DropState.NONE

@onready var requirement_label: Label = $VBox/RequirementLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var card_display: Panel = $VBox/CardDisplay
@onready var card_tier_label: Label = $VBox/CardDisplay/VBox/TierLabel
@onready var card_rank_label: Label = $VBox/CardDisplay/VBox/RankLabel
@onready var drop_indicator: ColorRect = $DropIndicator

func _ready() -> void:
	drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_exited.connect(_on_mouse_exited)
	_update_display()

func _on_mouse_exited() -> void:
	_set_drop_state(DropState.NONE)

func set_requirement(card_req: Dictionary) -> void:
	required_card = card_req
	_update_display()

func set_card(card: Dictionary) -> void:
	current_card = card
	_update_display()

func clear_card() -> void:
	current_card = {}
	_update_display()

func has_card() -> bool:
	return not current_card.is_empty()

func _update_display() -> void:
	if not is_node_ready():
		return
	
	# Show requirement
	if not required_card.is_empty():
		requirement_label.text = "T%s R%d" % [CardFactory.get_tier_numeral(required_card.tier), required_card.rank]
	else:
		requirement_label.text = "???"
	
	# Show card or empty state
	if current_card.is_empty():
		card_display.visible = false
		status_label.visible = true
		status_label.text = "Empty"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		card_display.visible = true
		status_label.visible = false
		card_tier_label.text = "T%s" % CardFactory.get_tier_numeral(current_card.tier)
		card_rank_label.text = "R%d" % current_card.rank
		_update_card_color()
	
	# Drop indicator
	drop_indicator.visible = _drop_state != DropState.NONE
	if _drop_state == DropState.VALID:
		drop_indicator.color = CardFactory.visuals.drop_valid_move_color
	elif _drop_state == DropState.INVALID:
		drop_indicator.color = CardFactory.visuals.drop_invalid_color

func _update_card_color() -> void:
	var tier = current_card.get("tier", 1)
	var rank = current_card.get("rank", 1)
	card_display.self_modulate = CardFactory.get_card_color(tier, rank)

func _set_drop_state(state: DropState) -> void:
	if _drop_state != state:
		_drop_state = state
		_update_display()

# === Drag and Drop ===

func _get_drag_data(_pos: Vector2) -> Variant:
	if current_card.is_empty():
		return null
	
	# Allow dragging card back out of milestone slot
	var preview = CardFactory.create_drag_preview(current_card)
	set_drag_preview(preview)
	
	return {source = "milestone", slot = self, card = current_card}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		_set_drop_state(DropState.NONE)
		return false
	
	var incoming_card = data.get("card", {})
	if incoming_card.is_empty():
		_set_drop_state(DropState.NONE)
		return false
	
	# Don't accept if already has a card
	if not current_card.is_empty():
		_set_drop_state(DropState.INVALID)
		return true  # Accept for visual feedback
	
	# Check if card matches requirement
	if _card_matches_requirement(incoming_card):
		_set_drop_state(DropState.VALID)
		return true
	else:
		_set_drop_state(DropState.INVALID)
		return true  # Accept for visual feedback

func _drop_data(_pos: Vector2, data: Variant) -> void:
	_set_drop_state(DropState.NONE)
	
	if not data is Dictionary:
		return
	
	var incoming_card = data.get("card", {})
	var source = data.get("source", "")
	
	# Don't accept if slot is full
	if not current_card.is_empty():
		GameState.log_event("Milestone slot already filled")
		return
	
	# Check requirement
	if not _card_matches_requirement(incoming_card):
		GameState.log_event("Card doesn't match requirement (need T%s R%d)" % [
			CardFactory.get_tier_numeral(required_card.tier), required_card.rank])
		return
	
	# Remove card from source
	if source == "hand":
		var source_slot = data.get("slot")
		if source_slot:
			source_slot.clear_card()
			GameState.clear_hand_slot(source_slot.slot_index)
	elif source == "discard":
		GameState.take_from_discard()
	
	# Place card in milestone
	card_dropped.emit(self, incoming_card)

func _card_matches_requirement(card: Dictionary) -> bool:
	if required_card.is_empty() or card.is_empty():
		return false
	return card.tier == required_card.tier and card.rank == required_card.rank

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drop_state(DropState.NONE)
		# If we were the drag source and card was dropped elsewhere
		if current_card.is_empty():
			card_removed.emit(self)
