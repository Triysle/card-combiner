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

@onready var empty_label: Label = $EmptyLabel
@onready var card_container: Control = $CardContainer
@onready var origin_indicator: ColorRect = $OriginIndicator
@onready var drop_indicator: ColorRect = $DropIndicator
@onready var rank_label: Label = $CardContainer/VBox/RankLabel
@onready var tier_label: Label = $CardContainer/VBox/TierLabel
@onready var output_label: Label = $CardContainer/VBox/OutputLabel
@onready var card_background: ColorRect = $CardContainer/CardBackground

# Rank colors (inverted chromatic: 1=violet, 10=white)
const RANK_COLORS: Array[Color] = [
	Color(0.56, 0.0, 1.0),    # 1 - Violet
	Color(0.29, 0.0, 0.51),   # 2 - Indigo
	Color(0.0, 0.0, 1.0),     # 3 - Blue
	Color(0.0, 0.5, 0.0),     # 4 - Green
	Color(1.0, 1.0, 0.0),     # 5 - Yellow
	Color(1.0, 0.65, 0.0),    # 6 - Orange
	Color(1.0, 0.0, 0.0),     # 7 - Red
	Color(0.1, 0.1, 0.1),     # 8 - Black
	Color(0.5, 0.5, 0.5),     # 9 - Grey
	Color(1.0, 1.0, 1.0),     # 10 - White
]

const TIER_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

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
	tier_label.text = "Tier %s" % TIER_NUMERALS[tier] if tier > 0 else ""
	_update_output_display()
	
	# Set card color based on rank
	var color_index = clampi(rank - 1, 0, RANK_COLORS.size() - 1)
	var base_color = RANK_COLORS[color_index]
	
	# Modify saturation based on tier
	var hsv_h = base_color.h
	var hsv_s = base_color.s * (0.6 + 0.04 * tier)
	var hsv_v = base_color.v * (0.7 + 0.03 * tier)
	
	card_background.color = Color.from_hsv(hsv_h, clampf(hsv_s, 0.0, 1.0), clampf(hsv_v, 0.3, 1.0))

func _update_output_display() -> void:
	output_label.text = "+%d/s" % get_output()

func _update_drop_indicator_style() -> void:
	match _drop_state:
		DropState.VALID_MOVE:
			drop_indicator.color = Color(0.2, 0.6, 0.2, 0.6)
		DropState.VALID_MERGE:
			drop_indicator.color = Color(0.2, 0.4, 0.8, 0.6)
		DropState.VALID_SWAP:
			drop_indicator.color = Color(0.6, 0.5, 0.2, 0.6)  # Yellow/orange for swap
		DropState.INVALID:
			drop_indicator.color = Color(0.6, 0.2, 0.2, 0.6)

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
	
	_anim_tween.tween_property(card_container, "scale", Vector2(1.08, 1.08), 0.1)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_anim_tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.08)\
		.set_ease(Tween.EASE_IN_OUT)

func play_merge_animation() -> void:
	_kill_tween()
	_anim_tween = create_tween()
	
	card_container.scale = Vector2(0.7, 0.7)
	card_container.pivot_offset = card_container.size / 2
	
	_anim_tween.tween_property(card_container, "scale", Vector2(1.25, 1.25), 0.15)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_anim_tween.tween_property(card_container, "scale", Vector2(0.92, 0.92), 0.1)\
		.set_ease(Tween.EASE_IN_OUT)
	_anim_tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.08)\
		.set_ease(Tween.EASE_OUT)

func play_return_animation() -> void:
	play_land_animation()

# === Drag and Drop ===

func _get_drag_data(_pos: Vector2) -> Variant:
	if card_data.is_empty():
		return null
	
	_is_drag_origin = true
	_update_display()
	
	var preview = _create_drag_preview()
	var offset_container = Control.new()
	offset_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_container.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2
	set_drag_preview(offset_container)
	
	return {source = "hand", slot = self, card = card_data}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		if _is_drag_origin:
			_is_drag_origin = false
			_update_display()
			if not card_data.is_empty():
				play_return_animation()
		_set_drop_state(DropState.NONE)

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		_set_drop_state(DropState.NONE)
		return false
	
	var source = data.get("source", "")
	var incoming_card = data.get("card", {})
	
	if incoming_card.is_empty():
		_set_drop_state(DropState.NONE)
		return false
	
	hover_started.emit(self)
	
	# If this is the source slot, allow (will be a no-op)
	if source == "hand" and data.get("slot") == self:
		return true
	
	if card_data.is_empty():
		_set_drop_state(DropState.VALID_MOVE)
		return true
	
	# Check merge validity
	var result = GameState.validate_merge(incoming_card, card_data)
	if result == GameState.MergeResult.VALID:
		_set_drop_state(DropState.VALID_MERGE)
		return true
	else:
		# Can swap instead of merge
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
			# Swap hand slots
			GameState.swap_hand_slots(source_slot.slot_index, slot_index)
			source_slot.set_card(card_data)
			set_card(incoming_card)
			play_land_animation()
			source_slot.play_land_animation()
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
			GameState.log_event("Swapped %s with discard" % GameState.card_to_string(incoming_card))

func _log_merge_failure(card1: Dictionary, card2: Dictionary) -> void:
	var result = GameState.validate_merge(card1, card2)
	match result:
		GameState.MergeResult.INVALID_TIER:
			GameState.log_event("Cannot merge: different tiers")
		GameState.MergeResult.INVALID_RANK:
			GameState.log_event("Cannot merge: different ranks")
		GameState.MergeResult.INVALID_MAX_RANK:
			GameState.log_event("Cannot merge: max rank reached")

func _create_drag_preview() -> Control:
	var rank = card_data.get("rank", 1)
	var tier = card_data.get("tier", 1)
	
	var preview = Panel.new()
	preview.custom_minimum_size = Vector2(90, 110)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	var color_index = clampi(rank - 1, 0, RANK_COLORS.size() - 1)
	style.bg_color = RANK_COLORS[color_index].darkened(0.2)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	preview.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(vbox)
	
	var tier_lbl = Label.new()
	tier_lbl.text = "Tier %s" % TIER_NUMERALS[tier] if tier > 0 else ""
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_color_override("font_color", Color.WHITE)
	tier_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	tier_lbl.add_theme_constant_override("outline_size", 2)
	tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tier_lbl)
	
	var rank_lbl = Label.new()
	rank_lbl.text = "Rank %d" % rank
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_color_override("font_color", Color.WHITE)
	rank_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	rank_lbl.add_theme_constant_override("outline_size", 2)
	rank_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rank_lbl)
	
	var output_lbl = Label.new()
	output_lbl.text = "+%d/s" % GameState.get_card_points_value(card_data)
	output_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	output_lbl.add_theme_color_override("font_color", Color.WHITE)
	output_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	output_lbl.add_theme_constant_override("outline_size", 2)
	output_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(output_lbl)
	
	return preview
