# scripts/deck_viewer.gd
extends PopupPanel

## Collection Viewer - nearly fullscreen grid showing all species and forms
## Uses actual CardDisplay instances for consistent visuals
## Rows = species (MID), Columns = forms (I, II, III, etc.)

signal closed()
signal flip_animation_complete()

@onready var title_label: Label = $MarginContainer/VBox/Header/TitleLabel
@onready var close_button: Button = $MarginContainer/VBox/Header/CloseButton
@onready var column_headers: HBoxContainer = $MarginContainer/VBox/ColumnHeaders
@onready var scroll_container: ScrollContainer = $MarginContainer/VBox/ScrollContainer
@onready var chains_container: VBoxContainer = $MarginContainer/VBox/ScrollContainer/ChainsContainer

const CARD_DISPLAY_SCENE = preload("res://scenes/card_display.tscn")

const SCREEN_PADDING: int = 10  # Padding from screen edges
const MID_COLUMN_WIDTH: int = 60
const CELL_SPACING: int = 4
const HEADER_HEIGHT: int = 28

# Animation constants
const FLIP_DURATION: float = 0.3
const PRE_FLIP_PAUSE: float = 0.2

var max_forms: int = 1
var card_size: Vector2 = Vector2(120, 160)  # Will be calculated dynamically

# Store references to card displays by mid_form key for animation
var card_displays: Dictionary = {}  # "mid_form" -> CardDisplay

# Track which card should show as face-down pending flip animation
var pending_flip_mid: int = -1
var pending_flip_form: int = -1

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	GameState.collection_changed.connect(_refresh_display)
	GameState.deck_changed.connect(_refresh_display)
	# Ensure scroll container clips its contents
	scroll_container.clip_contents = true

func _on_close_pressed() -> void:
	hide()
	closed.emit()

func _get_window_size() -> Vector2:
	# Use parent's size since main scene resizes correctly in web exports
	var parent = get_parent()
	if parent and parent is Control:
		return parent.size
	# Fallback to root size
	return get_tree().root.size

func open() -> void:
	_calculate_max_forms()
	
	# Get actual window size
	var window_size = _get_window_size()
	
	_calculate_sizes()
	_refresh_display()
	
	# Calculate target size
	var target_width = int(window_size.x) - (SCREEN_PADDING * 2)
	var target_height = int(window_size.y) - (SCREEN_PADDING * 2)
	var target_size = Vector2i(target_width, target_height)
	
	# Reset min_size to allow smaller sizes
	min_size = Vector2i.ZERO
	
	# Set max_size to constrain the popup (key fix for web exports)
	max_size = target_size
	
	# Show and position
	position = Vector2i(SCREEN_PADDING, SCREEN_PADDING)
	size = target_size
	show()
	
	# Force size again after show
	call_deferred("_force_size", target_size)

## Open collection and scroll to specific MID, optionally animate a card flip
func open_and_scroll_to(mid: int, form: int, animate_flip: bool = false) -> void:
	# Set pending flip BEFORE refresh so the card shows face-down
	if animate_flip:
		pending_flip_mid = mid
		pending_flip_form = form
	else:
		pending_flip_mid = -1
		pending_flip_form = -1
	
	open()
	
	# Wait a frame for layout to settle
	await get_tree().process_frame
	
	_scroll_to_mid(mid)
	
	if animate_flip:
		# Wait for scroll to complete
		await get_tree().process_frame
		await get_tree().create_timer(PRE_FLIP_PAUSE).timeout
		_animate_card_flip(mid, form)

func _scroll_to_mid(mid: int) -> void:
	# Find the row for this MID
	var row_index = 0
	var all_species = MonsterRegistry.get_all_species()
	for i in range(all_species.size()):
		if all_species[i].id == mid:
			row_index = i
			break
	
	# Calculate scroll position (header is now outside scroll area)
	var row_height = card_size.y + CELL_SPACING
	var target_scroll = row_index * row_height
	
	# Center the row if possible
	var viewport_height = scroll_container.size.y
	target_scroll = max(0, target_scroll - viewport_height / 3)
	
	# Animate scroll
	var tween = create_tween()
	tween.tween_property(scroll_container, "scroll_vertical", int(target_scroll), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _force_size(target: Vector2i) -> void:
	size = target
	# Also ensure max_size is set
	max_size = target

func _calculate_max_forms() -> void:
	max_forms = 1
	var all_species = MonsterRegistry.get_all_species()
	for species in all_species:
		max_forms = maxi(max_forms, species.get_form_count())

func _calculate_sizes() -> void:
	# Get actual window size (use same method as open())
	var window_size = _get_window_size()
	
	# Calculate popup size (nearly fullscreen)
	var popup_width = window_size.x - (SCREEN_PADDING * 2)
	
	# Calculate available space for cards
	# Subtract: margins (24+16 on each side = 80), MID column, spacing between 5 cards
	var margin_space = 80  # MarginContainer + StyleBox margins
	var available_width = popup_width - margin_space - MID_COLUMN_WIDTH - (CELL_SPACING * (max_forms + 1))
	
	# Ensure at least 5 cards fit horizontally (no horizontal scroll)
	var min_columns = maxi(max_forms, 5)
	var card_width = available_width / min_columns
	
	# Maintain 3:4 aspect ratio (width:height)
	var card_height = card_width / 0.75
	
	# Clamp to reasonable bounds
	card_width = clampf(card_width, 60, 200)
	card_height = clampf(card_height, 80, 267)
	
	card_size = Vector2(card_width, card_height)

func _refresh_display() -> void:
	# Clear existing content
	for child in chains_container.get_children():
		child.queue_free()
	card_displays.clear()
	
	# Get collection stats
	var submitted_count = GameState.get_submitted_form_count()
	var total_forms = MonsterRegistry.get_total_form_count()
	
	title_label.text = "COLLECTION - %d/%d Complete" % [submitted_count, total_forms]
	
	# Update fixed column headers (outside scroll area)
	_update_column_headers()
	
	# Create rows for each species
	var all_species = MonsterRegistry.get_all_species()
	for species in all_species:
		var row = _create_species_row(species)
		chains_container.add_child(row)

func _update_column_headers() -> void:
	# Clear existing headers
	for child in column_headers.get_children():
		child.queue_free()
	
	column_headers.add_theme_constant_override("separation", CELL_SPACING)
	
	# Empty cell for MID column alignment
	var empty_label = Label.new()
	empty_label.custom_minimum_size.x = MID_COLUMN_WIDTH
	column_headers.add_child(empty_label)
	
	# Form numeral headers
	for form_idx in range(1, max_forms + 1):
		var header = Label.new()
		header.text = CardFactory.get_form_numeral(form_idx)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.custom_minimum_size = Vector2(card_size.x, HEADER_HEIGHT)
		header.add_theme_font_size_override("font_size", 24)
		header.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		column_headers.add_child(header)

func _create_species_row(species: MonsterSpecies) -> Control:
	var mid = species.id
	var species_form_count = species.get_form_count()
	
	# Check overall row status for MID label coloring
	var all_forms_submitted = true
	var any_form_submitted = false
	for form_idx in range(1, species_form_count + 1):
		if GameState.is_form_submitted(mid, form_idx):
			any_form_submitted = true
		else:
			all_forms_submitted = false
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", CELL_SPACING)
	
	# MID label
	var mid_label = Label.new()
	mid_label.text = MonsterRegistry.format_mid(mid)
	mid_label.custom_minimum_size = Vector2(MID_COLUMN_WIDTH, card_size.y)
	mid_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid_label.add_theme_font_size_override("font_size", 20)
	
	if all_forms_submitted:
		mid_label.add_theme_color_override("font_color", Color(0.15, 0.5, 0.1))  # Dark green
	elif any_form_submitted:
		mid_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.1))  # Dark yellow/gold
	else:
		mid_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))  # Dark grey
	
	hbox.add_child(mid_label)
	
	# Form cells
	for form_idx in range(1, max_forms + 1):
		if form_idx <= species_form_count:
			# This form exists - create a CardDisplay
			var card_display = _create_form_card(species, form_idx)
			hbox.add_child(card_display)
			# Store reference for animation
			var key = "%d_%d" % [mid, form_idx]
			card_displays[key] = card_display
		else:
			# Empty space - no form here for this species
			var spacer = Control.new()
			spacer.custom_minimum_size = card_size
			hbox.add_child(spacer)
	
	return hbox

func _create_form_card(species: MonsterSpecies, form_idx: int) -> Control:
	var mid = species.id
	var is_submitted = GameState.is_form_submitted(mid, form_idx)
	
	var card_display = CARD_DISPLAY_SCENE.instantiate()
	
	# Check if this card is pending a flip animation
	var is_pending_flip = (mid == pending_flip_mid and form_idx == pending_flip_form)
	
	# If pending flip, show as face-down even though it's submitted
	var state: String
	if is_pending_flip:
		state = "not_collected"
	elif is_submitted:
		state = "submitted"
	else:
		state = "not_collected"
	
	card_display.setup_collection(mid, form_idx, state, card_size)
	
	return card_display

func _animate_card_flip(mid: int, form: int) -> void:
	var key = "%d_%d" % [mid, form]
	var card_display = card_displays.get(key)
	if not card_display:
		pending_flip_mid = -1
		pending_flip_form = -1
		flip_animation_complete.emit()
		return
	
	# Card should currently be showing card back (not_collected state)
	# Animate flip to submitted state
	card_display.pivot_offset = card_size / 2.0
	
	var tween = create_tween()
	# Scale X to 0 (flip halfway)
	tween.tween_property(card_display, "scale:x", 0.0, FLIP_DURATION / 2)
	# Change to submitted state at midpoint
	tween.tween_callback(func():
		card_display.setup_collection(mid, form, "submitted", card_size)
	)
	# Scale X back to 1 (complete flip)
	tween.tween_property(card_display, "scale:x", 1.0, FLIP_DURATION / 2)
	# Clear pending and emit signal when done
	tween.tween_callback(func():
		pending_flip_mid = -1
		pending_flip_form = -1
		flip_animation_complete.emit()
	)
