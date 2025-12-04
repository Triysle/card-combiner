# scripts/slot.gd
class_name Slot
extends Panel

## A hand slot that can hold a card

signal merge_attempted(source_slot: Slot, target_slot: Slot)
signal move_attempted(source_slot: Slot, target_slot: Slot)
signal hover_started(slot: Slot)
signal discard_requested(slot: Slot)

var slot_index: int = -1

# Card data (empty dict = empty slot)
var card_data: Dictionary = {}

var _is_drag_origin: bool = false

enum DropState { NONE, VALID_MOVE, VALID_MERGE, VALID_SWAP, INVALID }
var _drop_state: DropState = DropState.NONE

var _anim_tween: Tween = null

@onready var empty_label: Label = $EmptyLabel
@onready var card_container: Control = $CardContainer
@onready var origin_indicator: ColorRect = $OriginIndicator
@onready var drop_indicator: ColorRect = $DropIndicator
@onready var rank_label: Label = $CardContainer/VBox/RankLabel
@onready var tier_label: Label = $CardContainer/VBox/TierLabel
@onready var output_label: Label = $CardContainer/VBox/OutputLabel
@onready var card_background: ColorRect = $CardContainer/CardBackground

func _ready() -> void:
	origin_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_exited.connect(_on_mouse_exited)
	GameState.tick.connect(_on_tick)
	_update_display()

func _on_mouse_exited() -> void:
	if _drop_state != DropState.NONE:
		_set_drop_state(DropState.NONE)

func _on_tick() -> void:
	if not card_data.is_empty():
		_update_output_display()

func set_card(data: Dictionary) -> void:
	card_data = data
	_update_display()

func clear_card() -> void:
	card_data = {}
	_update_display()

func is_empty() -> bool:
	return card_data.is_empty()

func get_card_data() -> Dictionary:
	return card_data

func get_output() -> int:
	return GameState.get_card_points_value(card_data)

func _update_display() -> void:
	if not is_node_ready():
		return
	
	var is_empty_slot = card_data.is_empty()
	
	origin_indicator.visible = _is_drag_origin
	drop_indicator.visible = _drop_state != DropState.NONE
	if _drop_state != DropState.NONE:
		_update_drop_indicator_style()
	
	empty_label.visible = is_empty_slot and not _is_drag_origin and _drop_state == DropState.NONE
	card_container.visible = not is_empty_slot and not _is_drag_origin
	
	if not is_empty_slot:
		_update_card_display()

func _update_card_display() -> void:
	var rank = card_data.get("rank", 0)
	var tier = card_data.get("tier", 0)
	
	rank_label.text = "Rank %d" % rank
	tier_label.text = "Tier %s" % CardFactory.get_tier_numeral(tier) if tier > 0 else ""
	_update_output_display()
	
	# Set card color using CardFactory
	card_background.color = CardFactory.get_card_color(tier, rank)

func _update_output_display() -> void:
	output_label.text = "+%d/s" % get_output()

func _update_drop_indicator_style() -> void:
	var visuals = CardFactory.visuals
	match _drop_state:
		DropState.VALID_MOVE:
			drop_indicator.color = visuals.drop_valid_move_color
		DropState.VALID_MERGE:
			drop_indicator.color = visuals.drop_valid_merge_color
		DropState.VALID_SWAP:
			drop_indicator.color = visuals.drop_valid_swap_color
		DropState.INVALID:
			drop_indicator.color = visuals.drop_invalid_color

func _set_drop_state(state: DropState) -> void:
	if _drop_state != state:
		_drop_state = state
		_update_display()

func clear_drop_state() -> void:
	_set_drop_state(DropState.NONE)

# === Animations ===

func _kill_tween() -> void:
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null

func play_land_animation() -> void:
	_kill_tween()
	_anim_tween = create_tween()
	
	card_container.scale = Vector2(0.8, 0.8)
	card_container.pivot_offset = card_container.size / 2
	
	_anim_tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func play_merge_animation() -> void:
	_kill_tween()
	_anim_tween = create_tween()
	
	card_container.scale = Vector2(1.2, 1.2)
	card_container.pivot_offset = card_container.size / 2
	
	_anim_tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

# === Drag and Drop ===

func _get_drag_data(_pos: Vector2) -> Variant:
	if card_data.is_empty():
		return null
	
	_is_drag_origin = true
	_update_display()
	
	var preview = CardFactory.create_drag_preview(card_data)
	set_drag_preview(preview)
	
	return {source = "hand", slot = self, card = card_data}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_is_drag_origin = false
		_update_display()

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		_set_drop_state(DropState.NONE)
		return false
	
	var source = data.get("source", "")
	var incoming_card = data.get("card", {})
	
	if incoming_card.is_empty():
		_set_drop_state(DropState.NONE)
		return false
	
	# Accept from hand, discard, or milestone
	if source != "hand" and source != "discard" and source != "milestone":
		_set_drop_state(DropState.NONE)
		return false
	
	# Emit hover signal for grid to track
	hover_started.emit(self)
	
	# Can always drop on empty slot
	if card_data.is_empty():
		_set_drop_state(DropState.VALID_MOVE)
		return true
	
	# Check for merge
	if GameState.can_merge(incoming_card, card_data):
		_set_drop_state(DropState.VALID_MERGE)
		return true
	else:
		# Can swap (except milestone which requires specific cards)
		if source == "milestone":
			_set_drop_state(DropState.INVALID)
			return true
		_set_drop_state(DropState.VALID_SWAP)
		return true

func _drop_data(_pos: Vector2, data: Variant) -> void:
	if not data is Dictionary:
		return
	
	var source = data.get("source", "")
	var source_slot = data.get("slot")
	var incoming_card = data.get("card", {})
	
	_set_drop_state(DropState.NONE)
	
	# Handle drop from hand slot
	if source == "hand" and source_slot is Slot:
		if source_slot == self:
			return
		
		if card_data.is_empty():
			# Simple move
			move_attempted.emit(source_slot, self)
		elif GameState.can_merge(incoming_card, card_data):
			# Merge
			merge_attempted.emit(source_slot, self)
		else:
			# Swap hand slots - GameState.swap_hand_slots emits hand_changed
			# which triggers Grid._sync_from_game_state to update all slot visuals
			GameState.swap_hand_slots(source_slot.slot_index, slot_index)
			# Play animations after sync happens
			call_deferred("play_land_animation")
			source_slot.call_deferred("play_land_animation")
			GameState.log_event("Swapped cards")
	
	# Handle drop from discard pile
	elif source == "discard":
		if card_data.is_empty():
			# Place card from discard
			GameState.take_from_discard()
			set_card(incoming_card)
			GameState.set_hand_slot(slot_index, incoming_card)
			play_land_animation()
		elif GameState.can_merge(incoming_card, card_data):
			# Merge with discard card
			GameState.take_from_discard()
			var result = GameState.merge_cards(incoming_card, card_data)
			set_card(result)
			GameState.set_hand_slot(slot_index, result)
			play_merge_animation()
		else:
			# Swap: hand card goes to discard, discard card comes to hand
			var old_hand_card = card_data
			GameState.take_from_discard()
			set_card(incoming_card)
			GameState.set_hand_slot(slot_index, incoming_card)
			GameState.add_to_discard(old_hand_card)
			play_land_animation()
			GameState.log_event("Swapped %s with discard" % CardFactory.card_to_string(incoming_card))
	
	# Handle drop from milestone slot
	elif source == "milestone":
		var milestone_slot = data.get("slot")
		if card_data.is_empty():
			# Place card from milestone into hand
			if milestone_slot:
				milestone_slot.clear_card()
				GameState.clear_milestone_slot(milestone_slot.slot_index)
			set_card(incoming_card)
			GameState.set_hand_slot(slot_index, incoming_card)
			play_land_animation()
			GameState.log_event("Moved %s from milestone to hand" % CardFactory.card_to_string(incoming_card))
		elif GameState.can_merge(incoming_card, card_data):
			# Merge milestone card with hand card
			if milestone_slot:
				milestone_slot.clear_card()
				GameState.clear_milestone_slot(milestone_slot.slot_index)
			var result = GameState.merge_cards(incoming_card, card_data)
			set_card(result)
			GameState.set_hand_slot(slot_index, result)
			play_merge_animation()
		else:
			# Swap: hand card goes to milestone (if valid), milestone card to hand
			# For simplicity, just reject swap since milestone requires specific cards
			GameState.log_event("Cannot swap - milestone requires specific card")

func _log_merge_failure(card1: Dictionary, card2: Dictionary) -> void:
	var result = GameState.validate_merge(card1, card2)
	match result:
		GameState.MergeResult.INVALID_TIER:
			GameState.log_event("Cannot merge: different tiers")
		GameState.MergeResult.INVALID_RANK:
			GameState.log_event("Cannot merge: different ranks")
		GameState.MergeResult.INVALID_MAX_RANK:
			GameState.log_event("Cannot merge: max rank reached")
