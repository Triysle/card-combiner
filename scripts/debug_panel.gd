# scripts/debug_panel.gd
extends PanelContainer

## Debug panel - developer tools for testing

@onready var close_button: Button = %CloseButton
@onready var points_button: Button = %PointsButton
@onready var max_card_button: Button = %MaxCardButton
@onready var foil_card_button: Button = %FoilCardButton

func _ready() -> void:
	close_button.pressed.connect(toggle)
	points_button.pressed.connect(_grant_points)
	max_card_button.pressed.connect(_create_max_card)
	if foil_card_button:
		foil_card_button.pressed.connect(_create_foil_card)

func toggle() -> void:
	visible = not visible

func _grant_points() -> void:
	GameState.add_points(1000000)

func _create_max_card() -> void:
	# Find any unlocked form that hasn't been submitted
	for mid in MonsterRegistry.get_all_mids():
		var unlocked_form = GameState.get_unlocked_form(mid)
		if not GameState.is_form_submitted(mid, unlocked_form):
			var max_card = CardFactory.create_max_card(mid, unlocked_form, false)
			GameState.deck.append(max_card)
			GameState.deck_changed.emit()
			return

func _create_foil_card() -> void:
	# Create a random foil card from unlocked species
	var unlocked = GameState.unlocked_species
	if unlocked.is_empty():
		return
	
	var mid = unlocked[randi() % unlocked.size()]
	var form = GameState.get_unlocked_form(mid)
	var rank = randi_range(1, 4)  # Random rank 1-4
	
	var foil_card = CardFactory.create_card(mid, form, rank, true)
	GameState.deck.append(foil_card)
	GameState.deck_changed.emit()
