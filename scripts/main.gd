extends Control

## Main scene - orchestrates all game interactions

@onready var grid = $MarginContainer/MainHBox/CenterPanel/VBox/Grid
@onready var deck_pile = $MarginContainer/MainHBox/CenterPanel/VBox/DeckArea/DeckPile
@onready var discard_pile = $MarginContainer/MainHBox/CenterPanel/VBox/DeckArea/DiscardPile
@onready var booster_button: Button = $MarginContainer/MainHBox/CenterPanel/VBox/BoosterButton
@onready var milestone_container: PanelContainer = $MarginContainer/MainHBox/RightPanel/MilestonePanelContainer
@onready var upgrades_panel: PanelContainer = $MarginContainer/MainHBox/RightPanel/UpgradesPanel

# Settings UI
var settings_button: Button
var settings_popup: PopupPanel
var auto_draw_toggle: CheckButton

# Deck viewer
var deck_viewer_button: Button
var deck_viewer_popup: PopupPanel

# Reset confirmation
var reset_confirm_dialog: ConfirmationDialog

const DECK_VIEWER_SCENE = preload("res://scenes/deck_viewer.tscn")
const PACK_OPENING_SCENE = preload("res://scenes/pack_opening.tscn")
const CREDITS_OVERLAY_SCENE = preload("res://scenes/credits_overlay.tscn")

# Debug panel
var debug_panel: PanelContainer
var debug_visible: bool = false
var debug_tick_button: Button


func _ready() -> void:
	grid.merge_attempted.connect(_on_merge_attempted)
	grid.move_attempted.connect(_on_move_attempted)
	grid.discard_requested.connect(_on_discard_requested)
	
	booster_button.pressed.connect(_on_booster_pressed)
	
	_setup_settings_ui()
	_setup_deck_viewer()
	_setup_debug_panel()
	_update_booster_button()
	_update_panel_visibility()
	
	GameState.points_changed.connect(_on_points_changed)
	GameState.hand_changed.connect(_on_hand_changed)
	GameState.milestone_changed.connect(_update_panel_visibility)
	GameState.upgrades_changed.connect(_update_settings_visibility)
	
	GameState.log_event("Welcome to Card Combiner! (v%s)" % GameState.VERSION)
	GameState.log_event("Click the DECK to draw your first card")

func _setup_settings_ui() -> void:
	settings_button = Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(_on_settings_pressed)
	settings_button.custom_minimum_size = Vector2(100, 32)
	
	var right_panel = $MarginContainer/MainHBox/RightPanel
	right_panel.add_child(settings_button)
	right_panel.move_child(settings_button, 0)
	
	settings_popup = PopupPanel.new()
	
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.15, 0.16, 0.19, 1.0)
	popup_style.border_width_left = 2
	popup_style.border_width_top = 2
	popup_style.border_width_right = 2
	popup_style.border_width_bottom = 2
	popup_style.border_color = Color(0.3, 0.3, 0.35, 1.0)
	popup_style.corner_radius_top_left = 4
	popup_style.corner_radius_top_right = 4
	popup_style.corner_radius_bottom_right = 4
	popup_style.corner_radius_bottom_left = 4
	settings_popup.add_theme_stylebox_override("panel", popup_style)
	
	var popup_vbox = VBoxContainer.new()
	popup_vbox.custom_minimum_size = Vector2(200, 0)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(popup_vbox)
	settings_popup.add_child(margin)
	
	var title = Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_vbox.add_child(title)
	
	var sep1 = HSeparator.new()
	popup_vbox.add_child(sep1)
	
	# Auto-draw toggle
	auto_draw_toggle = CheckButton.new()
	auto_draw_toggle.text = "Auto-Draw"
	auto_draw_toggle.button_pressed = GameState.auto_draw_enabled
	auto_draw_toggle.toggled.connect(_on_auto_draw_toggled)
	auto_draw_toggle.visible = GameState.auto_draw_unlocked
	popup_vbox.add_child(auto_draw_toggle)
	
	var save_button = Button.new()
	save_button.text = "Save Game"
	save_button.pressed.connect(_on_save_pressed)
	popup_vbox.add_child(save_button)
	
	var reset_button = Button.new()
	reset_button.text = "Reset Save (New Game)"
	reset_button.pressed.connect(_on_reset_pressed)
	popup_vbox.add_child(reset_button)
	
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	popup_vbox.add_child(spacer)
	
	var sep2 = HSeparator.new()
	popup_vbox.add_child(sep2)
	
	var version_label = Label.new()
	version_label.text = "Version %s" % GameState.VERSION
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	popup_vbox.add_child(version_label)
	
	var credits_button = Button.new()
	credits_button.text = "Credits"
	credits_button.pressed.connect(_on_credits_pressed)
	popup_vbox.add_child(credits_button)
	
	add_child(settings_popup)
	
	reset_confirm_dialog = ConfirmationDialog.new()
	reset_confirm_dialog.title = "Confirm Reset"
	reset_confirm_dialog.dialog_text = "Are you sure you want to reset?\nAll progress will be lost!"
	reset_confirm_dialog.ok_button_text = "Reset"
	reset_confirm_dialog.cancel_button_text = "Cancel"
	reset_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	add_child(reset_confirm_dialog)

func _setup_deck_viewer() -> void:
	deck_viewer_button = Button.new()
	deck_viewer_button.text = "Collection"
	deck_viewer_button.custom_minimum_size = Vector2(120, 32)
	deck_viewer_button.pressed.connect(_on_deck_viewer_pressed)
	deck_viewer_button.visible = false
	
	var center_vbox = $MarginContainer/MainHBox/CenterPanel/VBox
	center_vbox.add_child(deck_viewer_button)
	
	deck_viewer_popup = DECK_VIEWER_SCENE.instantiate()
	add_child(deck_viewer_popup)

func _on_deck_viewer_pressed() -> void:
	deck_viewer_popup.open()

func _on_settings_pressed() -> void:
	# Update auto-draw toggle state before showing
	auto_draw_toggle.visible = GameState.auto_draw_unlocked
	auto_draw_toggle.button_pressed = GameState.auto_draw_enabled
	
	var button_rect = settings_button.get_global_rect()
	settings_popup.position = Vector2(button_rect.position.x, button_rect.position.y + button_rect.size.y + 4)
	settings_popup.popup()

func _on_auto_draw_toggled(toggled_on: bool) -> void:
	if toggled_on != GameState.auto_draw_enabled:
		GameState.toggle_auto_draw()

func _on_save_pressed() -> void:
	GameState.save_game()
	settings_popup.hide()

func _on_reset_pressed() -> void:
	settings_popup.hide()
	reset_confirm_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("card_combiner_save.cfg")
	GameState.reset_to_defaults()
	get_tree().reload_current_scene()

func _on_merge_attempted(source_index: int, target_index: int) -> void:
	if GameState.try_merge_hand_slots(source_index, target_index):
		var slot = grid.get_slot(target_index)
		if slot:
			slot.play_merge_animation()

func _on_move_attempted(source_index: int, target_index: int) -> void:
	GameState.swap_hand_slots(source_index, target_index)

func _on_discard_requested(slot_index: int) -> void:
	GameState.discard_from_hand(slot_index)

func _on_booster_pressed() -> void:
	if not GameState.can_afford_pack():
		return
	
	var cards = GameState.buy_pack()
	if cards.is_empty():
		return
	
	_update_booster_button()
	_update_panel_visibility()
	
	var popup = PACK_OPENING_SCENE.instantiate()
	add_child(popup)
	popup.open(cards, GameState.current_tier)

func _on_points_changed(_value: int) -> void:
	_update_booster_button()

func _on_hand_changed() -> void:
	pass

func _update_booster_button() -> void:
	booster_button.visible = GameState.has_merged
	
	if booster_button.visible:
		var cost = GameState.get_pack_cost()
		var tier_num = CardFactory.get_tier_numeral(GameState.current_tier)
		booster_button.text = "BUY T%s BOOSTER PACK - %d pts" % [tier_num, cost]
		booster_button.disabled = not GameState.can_afford_pack()

func _update_panel_visibility() -> void:
	milestone_container.visible = GameState.has_bought_pack
	deck_viewer_button.visible = GameState.deck_viewer_unlocked

func _update_settings_visibility() -> void:
	_update_panel_visibility()
	if auto_draw_toggle:
		auto_draw_toggle.visible = GameState.auto_draw_unlocked

func _on_credits_pressed() -> void:
	settings_popup.hide()
	var credits = CREDITS_OVERLAY_SCENE.instantiate()
	add_child(credits)

# ===== DEBUG PANEL =====

func _setup_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.15, 0.15, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.3, 0.3, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	debug_panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	debug_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var title = Label.new()
	title.text = "DEBUG"
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(_toggle_debug_panel)
	header_hbox.add_child(close_btn)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var points_btn = Button.new()
	points_btn.text = "Grant 1M Points"
	points_btn.pressed.connect(_debug_grant_points)
	vbox.add_child(points_btn)
	
	debug_tick_button = Button.new()
	debug_tick_button.text = "10x Tick Rate: OFF"
	debug_tick_button.pressed.connect(_debug_toggle_tick_rate)
	vbox.add_child(debug_tick_button)
	
	var milestone_btn = Button.new()
	milestone_btn.text = "Complete Milestone"
	milestone_btn.pressed.connect(_debug_complete_milestone)
	vbox.add_child(milestone_btn)
	
	var hud = $MarginContainer/MainHBox/LeftPanel/HUD
	hud.add_child(debug_panel)

func _toggle_debug_panel() -> void:
	debug_visible = not debug_visible
	debug_panel.visible = debug_visible

func _debug_grant_points() -> void:
	GameState.points += 1000000
	GameState.log_event("[DEBUG] Granted 1,000,000 points")

func _debug_toggle_tick_rate() -> void:
	GameState.debug_tick_multiplier = 1.0 if GameState.debug_tick_multiplier > 1.0 else 10.0
	var state = "ON" if GameState.debug_tick_multiplier > 1.0 else "OFF"
	debug_tick_button.text = "10x Tick Rate: %s" % state
	GameState.log_event("[DEBUG] 10x tick rate: %s" % state)

func _debug_complete_milestone() -> void:
	var milestone = GameState.get_current_milestone()
	if milestone.is_empty():
		GameState.log_event("[DEBUG] No milestone to complete")
		return
	
	# Fill milestone slots with the actual required cards
	for i in range(milestone.required_cards.size()):
		GameState.milestone_slots[i] = milestone.required_cards[i].duplicate()
	
	# Complete it
	if GameState.complete_milestone():
		GameState.log_event("[DEBUG] Milestone completed")
	else:
		GameState.log_event("[DEBUG] Failed to complete milestone")

func _unhandled_input(event: InputEvent) -> void:
	# Ctrl+` to toggle debug panel
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_QUOTELEFT and event.ctrl_pressed:
			_toggle_debug_panel()
			get_viewport().set_input_as_handled()
