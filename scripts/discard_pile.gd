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
	
	tier_label.text = "Tier %s" % TIER_NUMERALS[tier]
	rank_label.text = "Rank %d" % rank
	output_label.text = "+%d/s" % GameState.get_card_points_value(card)
	
	var color_index = clampi(rank - 1, 0, RANK_COLORS.size() - 1)
	var base_color = RANK_COLORS[color_index]
	var hsv_h = base_color.h
	var hsv_s = base_color.s * (0.6 + 0.04 * tier)
	var hsv_v = base_color.v * (0.7 + 0.03 * tier)
	card_background.color = Color.from_hsv(hsv_h, clampf(hsv_s, 0.0, 1.0), clampf(hsv_v, 0.3, 1.0))

# === Drag and Drop ===

func _get_drag_data(_pos: Vector2) -> Variant:
	var card = GameState.peek_discard()
	if card.is_empty():
		return null
	
	_is_drag_origin = true
	_update_display()
	
	var preview = _create_drag_preview(card)
	var offset_container = Control.new()
	offset_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offset_container.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2
	set_drag_preview(offset_container)
	
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
		drop_indicator.color = Color(0.6, 0.4, 0.2, 0.6)  # Orange for discard
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
		GameState.log_event("Discarded %s" % GameState.card_to_string(card))

func _create_drag_preview(card: Dictionary) -> Control:
	var rank = card.get("rank", 1)
	var tier = card.get("tier", 1)
	
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
	tier_lbl.text = "Tier %s" % TIER_NUMERALS[tier]
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
	output_lbl.text = "+%d/s" % GameState.get_card_points_value(card)
	output_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	output_lbl.add_theme_color_override("font_color", Color.WHITE)
	output_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	output_lbl.add_theme_constant_override("outline_size", 2)
	output_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(output_lbl)
	
	return preview
