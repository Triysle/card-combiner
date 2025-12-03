extends PopupPanel

## Deck Viewer - shows all cards in deck/discard with sell functionality

signal closed()

@onready var title_label: Label = $MarginContainer/VBox/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/VBox/Header/CloseButton
@onready var card_grid: GridContainer = $MarginContainer/VBox/ScrollContainer/CardGrid
@onready var sell_zone: PanelContainer = $MarginContainer/VBox/SellZone
@onready var sell_label: Label = $MarginContainer/VBox/SellZone/SellLabel
@onready var stats_label: Label = $MarginContainer/VBox/StatsLabel

const TIER_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

# Track card buttons for updating
var card_buttons: Array[Button] = []
var pending_sell_index: int = -1
var pending_sell_is_discard: bool = false

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	GameState.deck_changed.connect(_refresh_display)
	GameState.discard_changed.connect(_refresh_display)
	
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
	
	# Update title with counts
	var deck_count = GameState.deck.size()
	var discard_count = GameState.discard_pile.size()
	title_label.text = "DECK VIEWER (%d in deck, %d in discard)" % [deck_count, discard_count]
	
	# Sort all cards for display
	var all_cards: Array[Dictionary] = []
	
	# Add deck cards with source info
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
	stats_label.text = "Total deck value: %d points/tick (if all in hand)" % total_value
	
	# Show/hide sell zone based on unlock
	sell_zone.visible = GameState.sell_unlocked

func _create_card_button(card: Dictionary, source: String, index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(70, 50)
	btn.text = "T%s R%d" % [TIER_NUMERALS[card.tier], card.rank]
	
	# Color based on tier
	var hue = (card.tier - 1) / 10.0 * 0.7
	var sat = 0.4 + (card.rank / 10.0) * 0.3
	btn.self_modulate = Color.from_hsv(hue, sat, 0.9)
	
	# Tooltip with details
	var value = GameState.get_card_points_value(card)
	var sell_value = GameState.get_sell_value(card)
	var source_text = "In deck" if source == "deck" else "In discard (top)" if index == 0 else "In discard"
	btn.tooltip_text = "%s\n+%d/tick\nSell: %d pts\n%s" % [
		GameState.card_to_string(card), value, sell_value, source_text
	]
	
	# Click to sell (with confirmation)
	btn.pressed.connect(_on_card_clicked.bind(source, index, card))
	
	return btn

func _on_card_clicked(source: String, index: int, card: Dictionary) -> void:
	if not GameState.sell_unlocked:
		return
	
	# Don't allow selling from discard (cards cycle through naturally)
	if source == "discard":
		GameState.log_event("Can't sell from discard - draw it first")
		return
	
	var _sell_value = GameState.get_sell_value(card)
	var sold = GameState.sell_card_from_deck(index)
	if sold > 0:
		_refresh_display()
