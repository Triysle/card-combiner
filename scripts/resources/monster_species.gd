# scripts/resources/monster_species.gd
class_name MonsterSpecies
extends Resource

## A monster species with all its evolution forms

## Unique monster ID (MID) - used for ordering in bestiary
@export var id: int = 0

## Base species name (e.g., "Alien", "Antlion")
@export var name: String = ""

## Species color - determines card background and plate tint
@export var base_color: Color = Color(0.5, 0.5, 0.5)

## Secondary color for gradient background
@export var secondary_color: Color = Color(0.4, 0.4, 0.4)

## Gradient type for card background
@export_enum("linear_horizontal", "linear_vertical", "linear_diagonal_down", "linear_diagonal_up", "radial_center", "radial_corner", "diamond") var gradient_type: String = "linear_diagonal_down"

## All forms for this species, in evolution order
@export var forms: Array[MonsterForm] = []

## Get total number of forms
func get_form_count() -> int:
	return forms.size()

## Get a specific form (1-indexed)
func get_form(form_index: int) -> MonsterForm:
	if form_index < 1 or form_index > forms.size():
		return null
	return forms[form_index - 1]

## Check if a form can evolve to the next
func can_form_evolve(form_index: int) -> bool:
	if form_index < 1 or form_index > forms.size():
		return false
	return forms[form_index - 1].can_evolve

## Get the next form index after evolution (0 if cannot evolve)
func get_next_form(current_form: int) -> int:
	if not can_form_evolve(current_form):
		return 0
	return current_form + 1

## Check if a form is the final form
func is_final_form(form_index: int) -> bool:
	return form_index == forms.size()

## Get display name for a form (uses species name + roman numeral if no custom name)
func get_form_display_name(form_index: int) -> String:
	var form = get_form(form_index)
	if form == null:
		return name
	if form.display_name != "":
		return form.display_name
	if forms.size() == 1:
		return name
	# Multi-form species: add roman numeral
	var numerals = ["", "I", "II", "III", "IV", "V", "VI"]
	if form_index < numerals.size():
		return "%s %s" % [name, numerals[form_index]]
	return "%s %d" % [name, form_index]
