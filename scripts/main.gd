# scripts/main.gd
extends Control

## Main scene - orchestrates game interactions
## UI panels are now instanced scenes, main.gd just wires them together

# Center area
@onready var grid = %Grid
@onready var deck_pile: DeckPile = %DeckPile
@onready var discard_pile = %DiscardPile
@onready var booster_button: Button = %BoosterButton
@onready var debug_panel: PanelContainer = %DebugPanel

# Right panel (all instanced scenes)
@onready var points_panel = %PointsPanel
@onready var upgrades_panel = %UpgradesPanel
@onready var collection_panel = %CollectionPanel

# Top left buttons
@onready var settings_button: Button = %SettingsButton
@onready var how_to_play_button: Button = %HowToPlayButton

# Popups (instanced scenes)
@onready var settings_popup = %SettingsPopup
@onready var how_to_play_popup = %HowToPlayPopup

# Loaded scenes
const DECK_VIEWER_SCENE = preload("res://scenes/deck_viewer.tscn")
const PACK_OPENING_SCENE = preload("res://scenes/pack_opening.tscn")
const CREDITS_OVERLAY_SCENE = preload("res://scenes/credits_overlay.tscn")
const UNLOCK_POPUP_SCENE = preload("res://scenes/unlock_popup.tscn")
const FINAL_FORM_POPUP_SCENE = preload("res://scenes/final_form_popup.tscn")
const WIN_SCREEN_SCENE = preload("res://scenes/win_screen.tscn")

var collection_popup: PopupPanel

func _ready() -> void:
	# Grid signals
	grid.merge_attempted.connect(_on_merge_attempted)
	grid.move_attempted.connect(_on_move_attempted)
	
	# Button signals
	booster_button.pressed.connect(_on_booster_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	
	# Panel signals
	collection_panel.open_requested.connect(_on_collection_pressed)
	collection_panel.submission_requested.connect(_on_submission_requested)
	settings_popup.reset_requested.connect(_on_reset_confirmed)
	settings_popup.credits_requested.connect(_on_credits_pressed)
	
	# Create collection popup
	collection_popup = DECK_VIEWER_SCENE.instantiate()
	add_child(collection_popup)
	
	# GameState signals
	GameState.points_changed.connect(_on_points_changed)
	GameState.hand_changed.connect(_on_hand_changed)
	
	_update_booster_button()

# ===== BUTTON HANDLERS =====

func _on_booster_pressed() -> void:
	if not GameState.can_buy_pack():
		return
	
	var cards = GameState.buy_pack()
	if cards.is_empty():
		return
	
	_update_booster_button()
	
	var popup = PACK_OPENING_SCENE.instantiate()
	add_child(popup)
	popup.open(cards, 1)

func _on_settings_pressed() -> void:
	settings_popup.open_at(settings_button)

func _on_how_to_play_pressed() -> void:
	how_to_play_popup.open()

func _on_collection_pressed() -> void:
	collection_popup.open()

func _on_credits_pressed() -> void:
	var credits = CREDITS_OVERLAY_SCENE.instantiate()
	add_child(credits)

func _on_reset_confirmed() -> void:
	GameState.reset_game()
	get_tree().reload_current_scene()

# ===== SUBMISSION FLOW =====

func _on_submission_requested(card: Dictionary) -> void:
	# Store card info before submission modifies state
	var mid = card.mid
	var form = card.form
	var is_final = CardFactory.is_final_form(card)
	
	# Perform the submission
	var success = GameState.confirm_submission()
	if not success:
		return
	
	# Check if game is won (all forms submitted)
	var game_won = GameState.get_submitted_form_count() >= MonsterRegistry.get_total_form_count()
	
	# Open collection with scroll and flip animation
	collection_popup.open_and_scroll_to(mid, form, true)
	
	# Wait for flip animation to complete
	await collection_popup.flip_animation_complete
	
	# Small pause to let player see the result
	await get_tree().create_timer(0.5).timeout
	
	# Close collection
	collection_popup.hide()
	
	# Show appropriate popup based on what happened
	if game_won:
		_show_win_screen()
	elif is_final:
		# Final form - check if a new species was unlocked
		var unlocked_species_card = GameState.get_last_unlocked_species_card()
		if CardFactory.is_valid_card(unlocked_species_card):
			# New species unlocked - show unlock popup with new species' base form
			_show_unlock_popup(unlocked_species_card)
		else:
			# No new species (all 59 unlocked) - just show progress
			_show_final_form_popup()
	else:
		# Non-final form - show next form unlock
		var next_form = form + 1
		var unlocked_card = CardFactory.create_card(mid, next_form, 1)
		_show_unlock_popup(unlocked_card)

func _show_unlock_popup(card: Dictionary) -> void:
	var popup = UNLOCK_POPUP_SCENE.instantiate()
	add_child(popup)
	popup.closed.connect(_on_unlock_popup_closed)
	popup.open(card)

func _on_unlock_popup_closed(_card: Dictionary) -> void:
	# Card was already added to deck by GameState.confirm_submission()
	pass

func _show_final_form_popup() -> void:
	var popup = FINAL_FORM_POPUP_SCENE.instantiate()
	add_child(popup)
	popup.open()

func _show_win_screen() -> void:
	var screen = WIN_SCREEN_SCENE.instantiate()
	add_child(screen)
	screen.credits_requested.connect(_on_credits_pressed)
	screen.reset_requested.connect(_on_reset_confirmed)
	screen.open()

# ===== GRID HANDLERS =====

func _on_merge_attempted(source_index: int, target_index: int) -> void:
	var source_card = GameState.get_hand_slot(source_index)
	var target_card = GameState.get_hand_slot(target_index)
	
	if GameState.validate_merge(source_card, target_card) == GameState.MergeResult.SUCCESS:
		var result = GameState.merge_cards(source_card, target_card)
		GameState.set_hand_slot(target_index, result)
		GameState.set_hand_slot(source_index, {})
		
		var slot = grid.get_slot(target_index)
		if slot:
			slot.set_card(result)
			slot.play_merge_animation()
		
		var source_slot = grid.get_slot(source_index)
		if source_slot:
			source_slot.clear_card()

func _on_move_attempted(source_index: int, target_index: int) -> void:
	var card = GameState.get_hand_slot(source_index)
	GameState.set_hand_slot(target_index, card)
	GameState.set_hand_slot(source_index, {})
	
	var target_slot = grid.get_slot(target_index)
	var source_slot = grid.get_slot(source_index)
	if target_slot:
		target_slot.set_card(card)
		target_slot.play_land_animation()
	if source_slot:
		source_slot.clear_card()

# ===== STATE HANDLERS =====

func _on_points_changed(_value: int) -> void:
	_update_booster_button()

func _on_hand_changed() -> void:
	_update_booster_button()

func _update_booster_button() -> void:
	var cost = GameState.get_pack_cost()
	if cost == 0:
		booster_button.text = "OPEN BOOSTER PACK - FREE!"
	else:
		booster_button.text = "BUY BOOSTER PACK - %s pts" % _format_number(cost)
	booster_button.disabled = not GameState.can_buy_pack()

func _format_number(value: int) -> String:
	if value >= 1000000000:
		return "%.2fB" % (value / 1000000000.0)
	elif value >= 1000000:
		return "%.2fM" % (value / 1000000.0)
	elif value >= 10000:
		return "%.1fK" % (value / 1000.0)
	else:
		return "%d" % value

# ===== DEBUG =====

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_QUOTELEFT and event.ctrl_pressed:
			debug_panel.toggle()
			get_viewport().set_input_as_handled()
