# scripts/resources/card_visuals.gd
class_name CardVisuals
extends Resource

## Visual configuration for cards - colors, textures, shaders, and dimensions

# === TIER DISPLAY ===
@export var tier_numerals: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

# === CARD DIMENSIONS ===
@export_group("Dimensions")
@export var card_size: Vector2 = Vector2(100, 120)
@export var card_preview_size: Vector2 = Vector2(90, 110)
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

@export_subgroup("Tier Modifiers")
@export_range(0.0, 0.2) var tier_saturation_base: float = 0.6
@export_range(0.0, 0.1) var tier_saturation_scale: float = 0.04
@export_range(0.0, 0.2) var tier_value_base: float = 0.7
@export_range(0.0, 0.1) var tier_value_scale: float = 0.03

# === VISUAL MODE ===
@export_group("Visual Mode")
enum VisualMode { PROCEDURAL, TEXTURE, SHADER, HYBRID }
@export var visual_mode: VisualMode = VisualMode.PROCEDURAL

# === TEXTURES ===
@export_group("Textures")
## Background textures per rank (index 0 = rank 1). If empty, uses procedural.
@export var rank_backgrounds: Array[Texture2D] = []

## Frame textures per tier (index 0 = tier 1). Overlays on top of rank background.
@export var tier_frames: Array[Texture2D] = []

## Optional overlay for the tier-rank numeral area
@export var numeral_background: Texture2D

# === CARD BACK ===
@export_group("Card Back")
@export var card_back_texture: Texture2D
@export var card_back_color: Color = Color(0.2, 0.25, 0.35, 1.0)
@export var card_back_symbol: String = "[CC]"
@export var card_back_symbol_color: Color = Color(0.35, 0.4, 0.5, 1.0)

# === SHADERS ===
@export_group("Shaders")
## Shader applied to card background (receives tier, rank as uniforms)
@export var card_shader: Shader

## Per-tier effect shaders (index 0 = tier 1). For glow, holo, etc.
@export var tier_effect_shaders: Array[Shader] = []

# === GAME BACKGROUND ===
@export_group("Game Background")
@export var game_background_texture: Texture2D
@export var game_background_color: Color = Color(0.1, 0.11, 0.14, 1.0)

# === DROP INDICATOR COLORS ===
@export_group("UI Colors")
@export var drop_valid_move_color: Color = Color(0.2, 0.6, 0.2, 0.6)
@export var drop_valid_merge_color: Color = Color(0.2, 0.4, 0.8, 0.6)
@export var drop_valid_swap_color: Color = Color(0.6, 0.5, 0.2, 0.6)
@export var drop_invalid_color: Color = Color(0.6, 0.2, 0.2, 0.6)
@export var drop_discard_color: Color = Color(0.6, 0.4, 0.2, 0.6)

# === HELPER METHODS ===

func get_tier_numeral(tier: int) -> String:
	if tier < 0 or tier >= tier_numerals.size():
		return "?"
	return tier_numerals[tier]

func get_rank_color(rank: int) -> Color:
	var index = clampi(rank - 1, 0, rank_colors.size() - 1)
	return rank_colors[index]

func get_card_color(tier: int, rank: int) -> Color:
	var base_color = get_rank_color(rank)
	
	var hsv_h = base_color.h
	var hsv_s = base_color.s * (tier_saturation_base + tier_saturation_scale * tier)
	var hsv_v = base_color.v * (tier_value_base + tier_value_scale * tier)
	
	return Color.from_hsv(hsv_h, clampf(hsv_s, 0.0, 1.0), clampf(hsv_v, 0.3, 1.0))

func get_rank_background(rank: int) -> Texture2D:
	var index = rank - 1
	if index < 0 or index >= rank_backgrounds.size():
		return null
	return rank_backgrounds[index]

func get_tier_frame(tier: int) -> Texture2D:
	var index = tier - 1
	if index < 0 or index >= tier_frames.size():
		return null
	return tier_frames[index]

func get_tier_effect_shader(tier: int) -> Shader:
	var index = tier - 1
	if index < 0 or index >= tier_effect_shaders.size():
		return null
	return tier_effect_shaders[index]

func has_texture_for_card(tier: int, rank: int) -> bool:
	return get_rank_background(rank) != null

func has_frame_for_tier(tier: int) -> bool:
	return get_tier_frame(tier) != null

func should_use_textures() -> bool:
	return visual_mode == VisualMode.TEXTURE or visual_mode == VisualMode.HYBRID

func should_use_shader() -> bool:
	return visual_mode == VisualMode.SHADER or visual_mode == VisualMode.HYBRID
