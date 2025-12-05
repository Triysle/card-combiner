# scripts/resources/card_visuals.gd
class_name CardVisuals
extends Resource

## Visual configuration for cards - colors, textures, shaders, and dimensions

# === CARD DIMENSIONS ===
@export_group("Dimensions")
@export var card_size: Vector2 = Vector2(100, 120)
@export var card_preview_size: Vector2 = Vector2(120, 160)
@export var card_corner_radius: int = 6
@export var card_border_width: int = 2

# === PROCEDURAL COLORS ===
@export_group("Procedural Colors")
@export var rank_colors: Array[Color] = [
	Color(0.56, 0.0, 1.0),    # 1 - Violet
	Color(0.29, 0.0, 0.51),   # 2 - Indigo
	Color(0.0, 0.0, 1.0),     # 3 - Blue
	Color(0.0, 0.5, 0.0),     # 4 - Green
	Color(1.0, 1.0, 0.0),     # 5 - Yellow
	Color(1.0, 0.65, 0.0),    # 6 - Orange
	Color(1.0, 0.0, 0.0),     # 7 - Red
	Color(0.1, 0.1, 0.1),     # 8 - Black
	Color(0.5, 0.5, 0.5),     # 9 - Grey
	Color(1.0, 1.0, 1.0),     # 10 - White
]

# === TEXTURES ===
@export_group("Textures")
## Background textures per rank (index 0 = rank 1). If empty, uses procedural.
@export var rank_backgrounds: Array[Texture2D] = []

## Shaders per rank (index 0 = rank 1). Applied to card background.
## Shaders receive uniforms: rank (int), base_color (vec4), time (float)
@export var rank_shaders: Array[Shader] = []

## Texture for name ribbon at top of card
@export var name_plate_texture: Texture2D

## Texture for info plate at bottom of card
@export var info_plate_texture: Texture2D

## Whether to tint plates with rank color
@export var tint_plates: bool = false

## Intensity of plate tinting (0.0 = no tint, 1.0 = full tint)
@export_range(0.0, 1.0) var plate_tint_intensity: float = 0.3

# === CARD BACK ===
@export_group("Card Back")
@export var card_back_texture: Texture2D
@export var card_back_color: Color = Color(0.2, 0.25, 0.35, 1.0)
@export var card_back_symbol: String = "[CC]"
@export var card_back_symbol_color: Color = Color(0.35, 0.4, 0.5, 1.0)

# === DROP INDICATOR COLORS ===
@export_group("UI Colors")
@export var drop_valid_move_color: Color = Color(0.2, 0.6, 0.2, 0.6)
@export var drop_valid_merge_color: Color = Color(0.2, 0.4, 0.8, 0.6)
@export var drop_valid_swap_color: Color = Color(0.6, 0.5, 0.2, 0.6)
@export var drop_invalid_color: Color = Color(0.6, 0.2, 0.2, 0.6)
@export var drop_discard_color: Color = Color(0.6, 0.4, 0.2, 0.6)

# === HELPER METHODS ===

func get_rank_color(rank: int) -> Color:
	var index = clampi(rank - 1, 0, rank_colors.size() - 1)
	return rank_colors[index]

func get_rank_background(rank: int) -> Texture2D:
	var index = rank - 1
	if index < 0 or index >= rank_backgrounds.size():
		return null
	return rank_backgrounds[index]

func get_rank_shader(rank: int) -> Shader:
	var index = rank - 1
	if index < 0 or index >= rank_shaders.size():
		return null
	return rank_shaders[index]
