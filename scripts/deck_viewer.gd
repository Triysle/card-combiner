extends PopupPanel

## Collection Viewer - shows all cards in deck/discard/hand with sell functionality

signal closed()

@onready var title_label: Label = $MarginContainer/VBox/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/VBox/Header/CloseButton
@onready var card_grid: GridContainer = $MarginContainer/VBox/ScrollContainer/CardGrid
@onready var sell_zone: PanelContainer = $MarginContainer/VBox/SellZone
@onready var sell_label: Label = $MarginContainer/VBox/SellZone/SellLabel
@onready var stats_label: Label = $MarginContainer/VBox/StatsLabel

const TIER_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

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

# Track card buttons for updating
var card_buttons: Array[Button] = []

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	GameState.deck_changed.connect(_refresh_display)
	GameState.discard_changed.connect(_refresh_display)
	GameState.hand_changed.connect(_refresh_display)
	
	# Setup sell zone as drop target
	sell_zone.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_close_pressed() -> void:
	hide()
	closed.emit()

func open() -> void:
	_refresh_display()
	popup_centered()

func _refresh_display() -> void:
	# Clear existing cards
	for btn in card_buttons:
		btn.queue_free()
	card_buttons.clear()
	
	# Collect all cards from all sources
	var all_cards: Array[Dictionary] = []
	
	# Add deck cards
	for i in range(GameState.deck.size()):
		all_cards.append({
			card = GameState.deck[i],
			source = "deck",
			index = i
		})
	
	# Add discard cards
	for i in range(GameState.discard_pile.size()):
		all_cards.append({
			card = GameState.discard_pile[i],
			source = "discard",
			index = i
		})
	
	# Add hand cards
	for i in range(GameState.hand.size()):
		var card = GameState.hand[i]
		if not card.is_empty():
			all_cards.append({
				card = card,
				source = "hand",
				index = i
			})
	
	# Update title with total count
	title_label.text = "COLLECTION (%d cards)" % all_cards.size()
	
	# Sort by tier desc, then rank desc
	all_cards.sort_custom(func(a, b):
		if a.card.tier != b.card.tier:
			return a.card.tier > b.card.tier
		return a.card.rank > b.card.rank
	)
	
	# Create card buttons
	for entry in all_cards:
		var btn = _create_card_button(entry.card, entry.source, entry.index)
		card_grid.add_child(btn)
		card_buttons.append(btn)
	
	# Update stats
	var total_value = 0
	for entry in all_cards:
		total_value += GameState.get_card_points_value(entry.card)
	stats_label.text = "Total collection value: %d points/tick (if all in hand)" % total_value
	
	# Show/hide sell zone based on unlock
	sell_zone.visible = GameState.sell_unlocked

func _create_card_button(card: Dictionary, source: String, index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(70, 50)
	btn.text = "T%s R%d" % [TIER_NUMERALS[card.tier], card.rank]
	
	# Color based on rank (matching card colors used elsewhere)
	var color_index = clampi(card.rank - 1, 0, RANK_COLORS.size() - 1)
	var base_color = RANK_COLORS[color_index]
	# Adjust brightness/saturation based on tier
	var hsv_h = base_color.h
	var hsv_s = base_color.s * (0.5 + 0.05 * card.tier)
	var hsv_v = base_color.v * (0.6 + 0.04 * card.tier)
	btn.self_modulate = Color.from_hsv(hsv_h, clampf(hsv_s, 0.0, 1.0), clampf(hsv_v, 0.3, 1.0))
	
	# Determine if sellable (can only sell cards below current tier)
	var can_sell = GameState.sell_unlocked and card.tier < GameState.current_tier
	
	# Build tooltip
	var value = GameState.get_card_points_value(card)
	var sell_value = GameState.get_sell_value(card)
	var source_text = ""
	match source:
		"deck": source_text = "In deck"
		"discard": source_text = "In discard" if index > 0 else "Top of discard"
		"hand": source_text = "In hand (slot %d)" % (index + 1)
	
	var sell_text = ""
	if can_sell:
		sell_text = "\nClick to sell for %d pts" % sell_value
	elif GameState.sell_unlocked:
		sell_text = "\nCannot sell current tier cards"
	
	btn.tooltip_text = "%s\n+%d/tick\n%s%s" % [
		GameState.card_to_string(card), value, source_text, sell_text
	]
	
	# Dim current tier cards to indicate they can't be sold
	if GameState.sell_unlocked and not can_sell:
		btn.modulate.a = 0.6
	
	# Click to sell
	btn.pressed.connect(_on_card_clicked.bind(source, index, card))
	
	return btn

func _on_card_clicked(source: String, index: int, card: Dictionary) -> void:
	if not GameState.sell_unlocked:
		return
	
	# Only allow selling cards below current tier
	if card.tier >= GameState.current_tier:
		GameState.log_event("Cannot sell Tier %s cards (current tier)" % TIER_NUMERALS[card.tier])
		return
	
	var sell_value = GameState.get_sell_value(card)
	var sold = false
	
	match source:
		"deck":
			sold = GameState.sell_card_from_deck(index) > 0
		"discard":
			sold = GameState.sell_card_from_discard(index) > 0
		"hand":
			sold = GameState.sell_card_from_hand(index) > 0
	
	if sold:
		_refresh_display()
