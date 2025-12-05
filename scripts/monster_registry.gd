# scripts/monster_registry.gd
extends Node

## Singleton registry for all monsters - autoloaded before GameState
## Uses MonsterSpecies resources (MID = one chain with multiple forms)

var _species: Dictionary = {}  # MID (int) -> MonsterSpecies

func _ready() -> void:
	_load_species()
	if _species.is_empty():
		_create_placeholder_species()

func _load_species() -> void:
	var dir = DirAccess.open("res://resources/monsters")
	if dir == null:
		push_warning("MonsterRegistry: Could not open resources/monsters directory")
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var path = "res://resources/monsters/" + file_name
			var species = load(path) as MonsterSpecies
			if species:
				_species[species.id] = species
		file_name = dir.get_next()
	dir.list_dir_end()

func _create_placeholder_species() -> void:
	# Create test species with multiple forms each
	var placeholders = [
		{id = 1, name = "Alien", form_count = 2},
		{id = 2, name = "Blob", form_count = 3},
		{id = 3, name = "Crystal", form_count = 2},
		{id = 4, name = "Demon", form_count = 3},
	]
	
	for data in placeholders:
		var species = MonsterSpecies.new()
		species.id = data.id
		species.name = data.name
		
		for i in range(data.form_count):
			var form = MonsterForm.new()
			form.form_index = i + 1
			form.display_name = ""  # Will use species name + numeral
			form.can_evolve = (i < data.form_count - 1)
			species.forms.append(form)
		
		_species[species.id] = species

# === PUBLIC API ===

func get_species(mid: int) -> MonsterSpecies:
	return _species.get(mid, null)

func get_all_species() -> Array[MonsterSpecies]:
	var result: Array[MonsterSpecies] = []
	var mids = _species.keys()
	mids.sort()
	for mid in mids:
		result.append(_species[mid])
	return result

func get_species_count() -> int:
	return _species.size()

func get_all_mids() -> Array[int]:
	var mids: Array[int] = []
	mids.assign(_species.keys())
	mids.sort()
	return mids

func format_mid(mid: int) -> String:
	return "%03d" % mid

func format_mid_form(mid: int, form: int) -> String:
	var numerals = ["", "I", "II", "III", "IV", "V", "VI"]
	var numeral = numerals[form] if form < numerals.size() else str(form)
	return "%03d-%s" % [mid, numeral]

# === FORM INFO ===

func get_form_count(mid: int) -> int:
	var species = get_species(mid)
	if species:
		return species.get_form_count()
	return 0

func get_form(mid: int, form: int) -> MonsterForm:
	var species = get_species(mid)
	if species:
		return species.get_form(form)
	return null

func get_form_name(mid: int, form: int) -> String:
	var species = get_species(mid)
	if species:
		return species.get_form_display_name(form)
	return "Unknown"

func get_form_sprite(mid: int, form: int) -> Texture2D:
	var form_data = get_form(mid, form)
	if form_data:
		return form_data.sprite
	return null

func is_final_form(mid: int, form: int) -> bool:
	var species = get_species(mid)
	if species:
		return species.is_final_form(form)
	return true

func can_form_evolve(mid: int, form: int) -> bool:
	var species = get_species(mid)
	if species:
		return species.can_form_evolve(form)
	return false

func get_next_form(mid: int, current_form: int) -> int:
	var species = get_species(mid)
	if species:
		return species.get_next_form(current_form)
	return 0

# === TOTAL FORMS (for win condition) ===

func get_total_form_count() -> int:
	## Returns total number of forms across all species (for win condition)
	var total = 0
	for mid in _species.keys():
		total += get_form_count(mid)
	return total
