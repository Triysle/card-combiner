# scripts/card_factory.gd
extends Node

## Factory for creating and managing cards - autoload singleton
## Card structure: {mid: int, form: int, rank: int, is_max: bool}

const CARD_DISPLAY_SCENE = preload("res://scenes/card_display.tscn")

var visuals: CardVisuals

func _ready() -> void:
	visuals = load("res://resources/default_card_visuals.tres")

# === CARD CREATION ===

func create_card(mid: int, form: int, rank: int = 1) -> Dictionary:
	return {
		"mid": mid,
		"form": form,
		"rank": clampi(rank, 1, 9),
		"is_max": false
	}

func create_max_card(mid: int, form: int) -> Dictionary:
	return {
		"mid": mid,
		"form": form,
		"rank": 10,  # MAX cards are effectively rank 10
		"is_max": true
	}

# === CARD VALIDATION ===

func is_valid_card(card: Dictionary) -> bool:
	return card.has("mid") and card.has("form") and card.has("rank") and card.has("is_max")

func is_empty_card(card: Dictionary) -> bool:
	return card.is_empty() or not is_valid_card(card)

# === CARD INFO ===

func get_card_species(card: Dictionary) -> MonsterSpecies:
	if is_empty_card(card):
		return null
	return MonsterRegistry.get_species(card.mid)

func get_card_form_data(card: Dictionary) -> MonsterForm:
	if is_empty_card(card):
		return null
	return MonsterRegistry.get_form(card.mid, card.form)

func get_card_name(card: Dictionary) -> String:
	if is_empty_card(card):
		return "Unknown"
	return MonsterRegistry.get_form_name(card.mid, card.form)

func get_card_mid_form_string(card: Dictionary) -> String:
	## Returns "001-II" format for bottom-left display
	if is_empty_card(card):
		return ""
	return MonsterRegistry.format_mid_form(card.mid, card.form)

func get_card_form(card: Dictionary) -> int:
	if is_empty_card(card):
		return 1
	return card.form

func get_form_numeral(form: int) -> String:
	const NUMERALS = ["", "I", "II", "III", "IV", "V", "VI"]
	if form >= 0 and form < NUMERALS.size():
		return NUMERALS[form]
	return str(form)

func get_card_sprite(card: Dictionary) -> Texture2D:
	if is_empty_card(card):
		return null
	return MonsterRegistry.get_form_sprite(card.mid, card.form)

func is_final_form(card: Dictionary) -> bool:
	if is_empty_card(card):
		return true
	return MonsterRegistry.is_final_form(card.mid, card.form)

# === POINT VALUES ===

func get_card_points_value(card: Dictionary) -> int:
	if is_empty_card(card):
		return 0
	var form = card.form
	# Point value = form² × rank
	return (form * form) * card.rank

# === CARD COLORS ===

func get_card_species_color(card: Dictionary) -> Color:
	## Returns the species base color for this card
	if is_empty_card(card):
		return Color(0.3, 0.3, 0.3)
	
	var species = get_card_species(card)
	if species and "base_color" in species:
		return species.base_color
	
	# Fallback if species not found or no color set
	return Color(0.5, 0.5, 0.5)

func get_card_color(card: Dictionary) -> Color:
	## Returns the species color (for backward compatibility)
	return get_card_species_color(card)

# === STRING REPRESENTATION ===

func card_to_string(card: Dictionary) -> String:
	if is_empty_card(card):
		return "Empty"
	
	var card_name = get_card_name(card)
	if card.is_max:
		return "%s MAX" % card_name
	return "%s R%d" % [card_name, card.rank]

# === DISPLAY CREATION ===

func create_card_display(card: Dictionary, size_override: Vector2 = Vector2.ZERO) -> Control:
	var display = CARD_DISPLAY_SCENE.instantiate()
	var size = size_override if size_override != Vector2.ZERO else Vector2(120, 160)
	display.setup(card, size)
	return display

func create_card_back_display(size_override: Vector2 = Vector2.ZERO) -> Control:
	var display = CARD_DISPLAY_SCENE.instantiate()
	var size = size_override if size_override != Vector2.ZERO else Vector2(120, 160)
	display.setup_card_back(size)
	return display
