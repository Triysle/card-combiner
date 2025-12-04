# scripts/resources/game_config.gd
class_name GameConfig
extends Resource

## Balance and tuning configuration for Card Combiner (GDD v2)

# === PROGRESSION LIMITS ===
@export_group("Progression")
@export_range(1, 10) var max_tier: int = 10
@export_range(1, 10) var max_rank: int = 10

# === STARTING STATE ===
@export_group("Starting State")
@export_range(1, 10) var starting_hand_size: int = 2
@export_range(1, 20) var starting_deck_size: int = 10
@export_range(1, 10) var starting_card_tier: int = 1
@export_range(1, 10) var starting_card_rank: int = 1

# === TIMING ===
@export_group("Timing")
@export_range(0.5, 30.0, 0.5) var base_draw_cooldown: float = 10.0
@export_range(0.1, 5.0, 0.1) var base_tick_interval: float = 1.0
@export_range(0.1, 2.0, 0.05) var min_draw_cooldown: float = 0.5
@export_range(0.05, 0.5, 0.01) var min_tick_interval: float = 0.125

# === BOOSTER PACKS ===
@export_group("Booster Packs")
@export_range(1, 10) var pack_size: int = 5
@export_range(10, 500, 10) var pack_base_cost: int = 100
## Probability decay per rank (0.5 = each rank half as likely as previous)
@export_range(0.3, 0.8, 0.05) var pack_rank_probability_decay: float = 0.5
## Pity slot 3 (index 2) minimum rank
@export_range(1, 5) var pack_pity_slot_3_min_rank: int = 2
## Pity slot 5 (index 4) minimum rank
@export_range(1, 5) var pack_pity_slot_5_min_rank: int = 3

# === POINT FORMULAS ===
@export_group("Point Formulas")
## Card value = tier^tier_exponent * rank^rank_exponent
@export_range(1.0, 3.0, 0.1) var card_value_tier_exponent: float = 2.0
@export_range(0.5, 2.0, 0.1) var card_value_rank_exponent: float = 1.0
## Sell returns this fraction of card value
@export_range(0.05, 0.5, 0.05) var sell_value_fraction: float = 0.1

# === UPGRADES (All 4 always available) ===
@export_group("Upgrades")
@export_range(5, 20) var base_upgrade_cap: int = 10
@export_range(5, 20) var upgrade_cap_increment: int = 10

@export_subgroup("Points Mod")
## Base cost for Points Mod upgrade
@export_range(10, 200, 10) var upgrade_points_mod_base_cost: int = 50
## Points multiplier bonus per level (0.1 = +10% per level)
@export_range(0.05, 0.5, 0.05) var upgrade_points_mod_per_level: float = 0.1

@export_subgroup("Pack Discount")
## Base cost for Pack Discount upgrade
@export_range(10, 200, 10) var upgrade_pack_discount_base_cost: int = 75
## Pack cost reduction per level (0.01 = 1% per level)
@export_range(0.005, 0.05, 0.005) var upgrade_pack_discount_per_level: float = 0.01

@export_subgroup("Critical Merge")
## Base cost for Critical Merge upgrade
@export_range(10, 200, 10) var upgrade_critical_merge_base_cost: int = 100
## Critical merge chance per level (0.01 = 1% per level)
@export_range(0.005, 0.05, 0.005) var upgrade_critical_merge_per_level: float = 0.01

@export_subgroup("Lucky Pack")
## Base cost for Lucky Pack upgrade
@export_range(10, 200, 10) var upgrade_lucky_pack_base_cost: int = 150
## Lucky pack chance per level (0.01 = 1% per level)
@export_range(0.005, 0.05, 0.005) var upgrade_lucky_pack_per_level: float = 0.01

@export_subgroup("Cost Scaling")
## Upgrade cost multiplier per level
@export_range(1.2, 2.0, 0.1) var upgrade_cost_exponent: float = 1.5

# === MILESTONES ===
@export_group("Milestones")
@export_range(2, 6) var milestones_per_tier: int = 4
@export_range(1, 5) var milestone_cards_required: int = 3

# === HELPER METHODS ===

func get_card_points_value(tier: int, rank: int) -> int:
	return int(pow(tier, card_value_tier_exponent) * pow(rank, card_value_rank_exponent))

func get_sell_value(tier: int, rank: int) -> int:
	return maxi(1, int(get_card_points_value(tier, rank) * sell_value_fraction))

# === UPGRADE HELPERS ===

func get_upgrade_base_cost(upgrade_id: String) -> int:
	match upgrade_id:
		"points_mod": return upgrade_points_mod_base_cost
		"pack_discount": return upgrade_pack_discount_base_cost
		"critical_merge": return upgrade_critical_merge_base_cost
		"lucky_pack": return upgrade_lucky_pack_base_cost
	return 50

func get_upgrade_cost(upgrade_id: String, current_level: int) -> int:
	var base = get_upgrade_base_cost(upgrade_id)
	return int(base * pow(upgrade_cost_exponent, current_level))

## Points Mod: 1.0x + 0.1x per level
func get_points_mod_multiplier(level: int) -> float:
	return 1.0 + upgrade_points_mod_per_level * level

## Pack Discount: 0% + 1% per level
func get_pack_discount_percent(level: int) -> float:
	return upgrade_pack_discount_per_level * level

## Critical Merge: 0% + 1% per level
func get_critical_merge_chance(level: int) -> float:
	return upgrade_critical_merge_per_level * level

## Lucky Pack: 0% + 1% per level
func get_lucky_pack_chance(level: int) -> float:
	return upgrade_lucky_pack_per_level * level
