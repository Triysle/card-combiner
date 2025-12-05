# scripts/monster_registry.gd
extends Node

## Singleton registry for all monsters - autoloaded before GameState
## Uses explicit preloads for web export compatibility

var _species: Dictionary = {}  # MID (int) -> MonsterSpecies

# Explicitly preload all monster species for web export compatibility
# DirAccess.open() doesn't work reliably in web exports
const MONSTER_RESOURCES: Array[Resource] = [
	preload("res://resources/monsters/001_alien.tres"),
	preload("res://resources/monsters/002_antlion.tres"),
	preload("res://resources/monsters/003_armed_rocket.tres"),
	preload("res://resources/monsters/004_armed_rocks.tres"),
	preload("res://resources/monsters/005_beaker_slime.tres"),
	preload("res://resources/monsters/006_bees.tres"),
	preload("res://resources/monsters/007_bombardier_ant.tres"),
	preload("res://resources/monsters/008_bookworm.tres"),
	preload("res://resources/monsters/009_boxing_marsupial.tres"),
	preload("res://resources/monsters/010_buff_vegetable.tres"),
	preload("res://resources/monsters/011_chameleon.tres"),
	preload("res://resources/monsters/012_chickensaurus.tres"),
	preload("res://resources/monsters/013_chime_angel.tres"),
	preload("res://resources/monsters/014_chimera.tres"),
	preload("res://resources/monsters/015_clockwork_toy.tres"),
	preload("res://resources/monsters/016_clown_frog.tres"),
	preload("res://resources/monsters/017_cupid.tres"),
	preload("res://resources/monsters/018_dead_fish.tres"),
	preload("res://resources/monsters/019_dragonfly.tres"),
	preload("res://resources/monsters/020_dummy.tres"),
	preload("res://resources/monsters/021_electric_rat.tres"),
	preload("res://resources/monsters/022_emotional_balloon.tres"),
	preload("res://resources/monsters/023_fashion_fox.tres"),
	preload("res://resources/monsters/024_fire_aardvark.tres"),
	preload("res://resources/monsters/025_fire_bird.tres"),
	preload("res://resources/monsters/026_forest_nymph.tres"),
	preload("res://resources/monsters/027_fruity.tres"),
	preload("res://resources/monsters/028_garbage_slug.tres"),
	preload("res://resources/monsters/029_gingerbread.tres"),
	preload("res://resources/monsters/030_icy_pig.tres"),
	preload("res://resources/monsters/031_karate_dog.tres"),
	preload("res://resources/monsters/032_lost_soul.tres"),
	preload("res://resources/monsters/033_man_o_war.tres"),
	preload("res://resources/monsters/034_mantis_shrimp.tres"),
	preload("res://resources/monsters/035_mighty_oak.tres"),
	preload("res://resources/monsters/036_mimic_spider.tres"),
	preload("res://resources/monsters/037_mirror.tres"),
	preload("res://resources/monsters/038_molecule.tres"),
	preload("res://resources/monsters/039_mummy_bug.tres"),
	preload("res://resources/monsters/040_musical_bat.tres"),
	preload("res://resources/monsters/041_paper_parrot.tres"),
	preload("res://resources/monsters/042_pinball.tres"),
	preload("res://resources/monsters/043_plant_reptile.tres"),
	preload("res://resources/monsters/044_plug_cyclops.tres"),
	preload("res://resources/monsters/045_robbing_robin.tres"),
	preload("res://resources/monsters/046_seadragon.tres"),
	preload("res://resources/monsters/047_snowman_yeti.tres"),
	preload("res://resources/monsters/048_statue.tres"),
	preload("res://resources/monsters/049_storm_cloud.tres"),
	preload("res://resources/monsters/050_tapeworm.tres"),
	preload("res://resources/monsters/051_tardigrade.tres"),
	preload("res://resources/monsters/052_time_cat.tres"),
	preload("res://resources/monsters/053_toilet_mimic.tres"),
	preload("res://resources/monsters/054_trash_monster.tres"),
	preload("res://resources/monsters/055_ugly_duckling.tres"),
	preload("res://resources/monsters/056_wasps_nest.tres"),
	preload("res://resources/monsters/057_water_fish.tres"),
	preload("res://resources/monsters/058_wisp.tres"),
	preload("res://resources/monsters/059_z_placeholder.tres"),
]

func _ready() -> void:
	_load_species()

func _load_species() -> void:
	for resource in MONSTER_RESOURCES:
		var species = resource as MonsterSpecies
		if species:
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
