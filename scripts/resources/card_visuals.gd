# scripts/resources/card_visuals.gd
class_name CardVisuals
extends Resource

## Visual configuration for cards - textures and UI colors

# === CARD DIMENSIONS ===
@export_group("Dimensions")
@export var card_size: Vector2 = Vector2(100, 120)
@export var card_preview_size: Vector2 = Vector2(120, 160)
@export var card_corner_radius: int = 6
@export var card_border_width: int = 2

# === TEXTURES ===
@export_group("Textures")
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
