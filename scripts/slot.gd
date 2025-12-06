# scripts/slot.gd
class_name Slot
extends Panel

## A hand slot that can hold a card

signal merge_attempted(source_slot: Slot, target_slot: Slot)
signal move_attempted(source_slot: Slot, target_slot: Slot)
signal hover_started(slot: Slot)

var slot_index: int = -1

# Card data (empty dict = empty slot)
var card_data: Dictionary = {}

var _is_drag_origin: bool = false

enum DropState { NONE, VALID_MOVE, VALID_MERGE, VALID_SWAP, INVALID }
var _drop_state: DropState = DropState.NONE

var _anim_tween: Tween = null

var _card_display: Control = null  # CardDisplay instance

@onready var card_container: Control = $CardContainer
@onready var origin_indicator: ColorRect = $OriginIndicator
@onready var drop_indicator: ColorRect = $DropIndicator
@onready var output_label: Label = $OutputLabel

const CARD_DISPLAY_SCENE = preload("res://scenes/card_display.tscn")

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
	return not CardFactory.is_valid_card(card_data)

func get_card_data() -> Dictionary:
	return card_data

func get_output() -> int:
	# Use GameState helper to include foil bonus
	return GameState.get_card_points_with_foil(card_data)

func _update_display() -> void:
	if not is_node_ready():
		return
	
	var is_empty_slot = CardFactory.is_empty_card(card_data)
	
	origin_indicator.visible = _is_drag_origin
	drop_indicator.visible = _drop_state != DropState.NONE
	if _drop_state != DropState.NONE:
		_update_drop_indicator_style()
	
	card_container.visible = not is_empty_slot and not _is_drag_origin
	output_label.visible = not is_empty_slot and not _is_drag_origin
	
	if not is_empty_slot:
		_update_card_display()

func _update_card_display() -> void:
	# Remove existing card display
	if _card_display:
		_card_display.queue_free()
		_card_display = null
	
	# Create new CardDisplay
	_card_display = CARD_DISPLAY_SCENE.instantiate()
	_card_display.setup(card_data, Vector2(112, 146))
	_card_display.position = Vector2(4, 4)
	_card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.add_child(_card_display)
	
	_update_output_display()

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

func _create_drag_preview(card: Dictionary) -> Control:
	var card_display_scene = preload("res://scenes/card_display.tscn")
	var preview = card_display_scene.instantiate()
	preview.setup(card, Vector2(100, 130))
	return preview

func _get_drag_data(_pos: Vector2) -> Variant:
	if CardFactory.is_empty_card(card_data):
		return null
	
	_is_drag_origin = true
	_update_display()
	
	var preview = _create_drag_preview(card_data)
	set_drag_preview(preview)
	
	return {source = "hand", slot = self, card = card_data}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_is_drag_origin = false
		_update_display()

func _can_merge(card_a: Dictionary, card_b: Dictionary) -> bool:
	return GameState.validate_merge(card_a, card_b) == GameState.MergeResult.SUCCESS

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		_set_drop_state(DropState.NONE)
		return false
	
	var source = data.get("source", "")
	var incoming_card = data.get("card", {})
	
	if CardFactory.is_empty_card(incoming_card):
		_set_drop_state(DropState.NONE)
		return false
	
	# Accept from hand or discard
	if source != "hand" and source != "discard":
		_set_drop_state(DropState.NONE)
		return false
	
	# Emit hover signal for grid to track
	hover_started.emit(self)
	
	# Can always drop on empty slot
	if CardFactory.is_empty_card(card_data):
		_set_drop_state(DropState.VALID_MOVE)
		return true
	
	# Check for merge
	if _can_merge(incoming_card, card_data):
		_set_drop_state(DropState.VALID_MERGE)
		return true
	else:
		# Can swap
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
		
		if CardFactory.is_empty_card(card_data):
			# Simple move
			move_attempted.emit(source_slot, self)
		elif _can_merge(incoming_card, card_data):
			# Merge
			merge_attempted.emit(source_slot, self)
		else:
			# Swap hand slots
			var temp = card_data
			set_card(incoming_card)
			source_slot.set_card(temp)
			GameState.set_hand_slot(slot_index, incoming_card)
			GameState.set_hand_slot(source_slot.slot_index, temp)
			play_land_animation()
			source_slot.play_land_animation()
	
	# Handle drop from discard pile
	elif source == "discard":
		if CardFactory.is_empty_card(card_data):
			# Place card from discard
			GameState.take_from_discard()
			set_card(incoming_card)
			GameState.set_hand_slot(slot_index, incoming_card)
			play_land_animation()
		elif _can_merge(incoming_card, card_data):
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
