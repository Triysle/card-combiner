class_name DeckPile
extends Panel

## The deck - click to draw a card to discard pile

@onready var count_label: Label = $CountLabel
@onready var cooldown_bar: ProgressBar = $CooldownBar
@onready var ready_indicator: ColorRect = $ReadyIndicator
@onready var card_back: ColorRect = $CardBack

func _ready() -> void:
	GameState.deck_changed.connect(_update_display)
	GameState.discard_changed.connect(_update_display)
	GameState.draw_cooldown_changed.connect(_on_cooldown_changed)
	_update_display()

func _update_display() -> void:
	var deck_size = GameState.deck.size()
	var discard_size = GameState.discard_pile.size()
	count_label.text = "(%d)" % deck_size
	
	# Show card back if deck has cards, or if we can shuffle from discard
	var can_shuffle = deck_size == 0 and discard_size > 0
	card_back.visible = deck_size > 0 or can_shuffle
	
	# Dim the card back if it represents "click to shuffle"
	if can_shuffle:
		card_back.modulate = Color(0.6, 0.6, 0.7, 0.8)
	else:
		card_back.modulate = Color(1, 1, 1, 1)
	
	ready_indicator.visible = GameState.can_draw and (deck_size > 0 or can_shuffle)

func _on_cooldown_changed(remaining: float, total: float) -> void:
	var deck_size = GameState.deck.size()
	var can_shuffle = deck_size == 0 and GameState.discard_pile.size() > 0
	
	if remaining <= 0:
		cooldown_bar.visible = false
		ready_indicator.visible = deck_size > 0 or can_shuffle
	else:
		cooldown_bar.visible = true
		ready_indicator.visible = false
		cooldown_bar.max_value = total
		cooldown_bar.value = total - remaining

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if GameState.can_draw:
				GameState.draw_card()  # This already shuffles if deck empty
				accept_event()
