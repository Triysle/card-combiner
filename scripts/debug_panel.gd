# scripts/debug_panel.gd
extends PanelContainer

## Debug panel - developer tools for testing

@onready var close_button: Button = %CloseButton
@onready var points_button: Button = %PointsButton
@onready var max_card_button: Button = %MaxCardButton

func _ready() -> void:
	close_button.pressed.connect(toggle)
	points_button.pressed.connect(_grant_points)
	max_card_button.pressed.connect(_create_max_card)

func toggle() -> void:
	visible = not visible

func _grant_points() -> void:
	GameState.add_points(1000000)

func _create_max_card() -> void:
	# Find any unlocked form that hasn't been submitted
	for mid in MonsterRegistry.get_all_mids():
		var unlocked_form = GameState.get_unlocked_form(mid)
		if not GameState.is_form_submitted(mid, unlocked_form):
			var max_card = CardFactory.create_max_card(mid, unlocked_form)
			GameState.deck.append(max_card)
			GameState.deck_changed.emit()
			return
