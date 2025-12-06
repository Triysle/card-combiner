@tool
extends EditorScript

## Run this from the Godot editor: Script > Run (Ctrl+Shift+X)
## Generates secondary_color and gradient_type for all monster species

const GRADIENT_TYPES = [
	"linear_horizontal",
	"linear_vertical", 
	"linear_diagonal_down",
	"linear_diagonal_up",
	"radial_center",
	"radial_corner",
	"diamond"
]

func _run() -> void:
	print("=== Generating Monster Colors ===")
	
	var monsters_dir = "res://resources/monsters/"
	var dir = DirAccess.open(monsters_dir)
	if not dir:
		push_error("Could not open monsters directory: " + monsters_dir)
		return
	
	# Use consistent seed for reproducibility
	seed(42)
	
	var updated_count = 0
	dir.list_dir_begin()
	var filename = dir.get_next()
	
	while filename != "":
		if filename.ends_with(".tres"):
			var filepath = monsters_dir + filename
			if _process_species(filepath):
				updated_count += 1
		filename = dir.get_next()
	
	dir.list_dir_end()
	print("=== Updated %d monster files ===" % updated_count)

func _process_species(filepath: String) -> bool:
	var species = load(filepath) as MonsterSpecies
	if not species:
		push_warning("Could not load: " + filepath)
		return false
	
	# Check if already has valid secondary_color (not default gray)
	var needs_update = false
	if species.secondary_color == Color(0.4, 0.4, 0.4) or species.secondary_color == Color(0.5, 0.5, 0.5):
		needs_update = true
	
	if not needs_update:
		print("  Skipping (already configured): " + filepath.get_file())
		return false
	
	# Generate secondary color
	species.secondary_color = _generate_secondary_color(species.base_color)
	
	# Assign gradient type
	species.gradient_type = GRADIENT_TYPES[randi() % GRADIENT_TYPES.size()]
	
	# Save the resource
	var err = ResourceSaver.save(species, filepath)
	if err != OK:
		push_error("Failed to save: " + filepath)
		return false
	
	print("  Updated: %s - gradient: %s" % [filepath.get_file(), species.gradient_type])
	return true

func _generate_secondary_color(base: Color) -> Color:
	var h = base.h
	var s = base.s
	var v = base.v
	
	# Randomly choose complementary (120-180°) or analogous (30-60°)
	var hue_shift: float
	if randf() < 0.6:
		# Complementary - more dramatic
		hue_shift = randf_range(0.33, 0.5)  # 120-180 degrees
	else:
		# Analogous - more subtle
		hue_shift = randf_range(0.08, 0.17)  # 30-60 degrees
		if randf() < 0.5:
			hue_shift = -hue_shift
	
	var new_h = fmod(h + hue_shift + 1.0, 1.0)
	
	# Desaturate slightly (20-35%)
	var new_s = maxf(0.15, s * randf_range(0.65, 0.8))
	
	# Keep value similar but allow slight variation
	var new_v = clampf(v * randf_range(0.85, 1.1), 0.3, 0.9)
	
	return Color.from_hsv(new_h, new_s, new_v, base.a)
