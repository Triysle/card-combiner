# scripts/game_state.gd
extends Node

## Core game state for Card Combiner - GDD v2
## 4 always-available upgrades, tier power bonuses from milestones, 10 tiers

const VERSION: String = "0.2"
const SAVE_PATH: String = "user://card_combiner_save.cfg"

signal points_changed(new_value: int)
signal tick()
signal event_logged(message: String)
signal deck_changed()
signal discard_changed()
signal hand_changed()
signal milestone_changed()
signal upgrades_changed()
signal draw_cooldown_changed(remaining: float, total: float)
signal game_won()

# ===== CONFIG (from CardFactory.config) =====
var MAX_TIER: int:
	get: return CardFactory.config.max_tier
var MAX_RANK: int:
	get: return CardFactory.config.max_rank
var STARTING_HAND_SIZE: int:
	get: return CardFactory.config.starting_hand_size
var STARTING_DECK_SIZE: int:
	get: return CardFactory.config.starting_deck_size
var BASE_DRAW_COOLDOWN: float:
	get: return CardFactory.config.base_draw_cooldown
var BASE_TICK_INTERVAL: float:
	get: return CardFactory.config.base_tick_interval
var PACK_SIZE: int:
	get: return CardFactory.config.pack_size
var PACK_BASE_COST: int:
	get: return CardFactory.config.pack_base_cost

# ===== CURRENCY =====
var points: int = 0:
	set(value):
		points = value
		points_changed.emit(points)

# ===== DECK & HAND =====
var deck: Array[Dictionary] = []  # Array of {tier: int, rank: int}
var discard_pile: Array[Dictionary] = []
var hand: Array[Dictionary] = []  # Fixed size array, empty dict = empty slot

# ===== PROGRESSION =====
var current_tier: int = 1  # Highest unlocked booster tier
var hand_size: int = 2
var current_milestone_index: int = 0  # 0-39 (4 per tier × 10 tiers)
var milestone_slots: Array[Dictionary] = [{}, {}, {}]  # 3 slots for milestone cards

# ===== DRAW COOLDOWN =====
var draw_cooldown_current: float = 0.0
var can_draw: bool = true

# ===== UNLOCK FLAGS =====
var has_merged: bool = false
var has_bought_pack: bool = false
var deck_viewer_unlocked: bool = false
var sell_unlocked: bool = false

# ===== UPGRADES (All 4 always available from start) =====
var upgrade_points_mod_level: int = 0
var upgrade_pack_discount_level: int = 0
var upgrade_critical_merge_level: int = 0
var upgrade_lucky_pack_level: int = 0

# Upgrade cap (increased by "Upgrade Limit" milestones)
var upgrade_cap: int = 10  # Base cap, +10 per milestone

# ===== TIER POWER BONUSES (from Tier Power milestones) =====
# Draw cooldown divisor: T1=2, T5=4, T8=8
var draw_cooldown_divisor: float = 1.0
# Tick rate multiplier: T2=2, T6=4, T9=8
var tick_rate_multiplier: float = 1.0
# Deck scoring percent: T4=10%, T7=50%, T10=100%
var deck_scoring_percent: float = 0.0
# Auto-draw: unlocked at T3
var auto_draw_unlocked: bool = false
var auto_draw_enabled: bool = false

# ===== INTERNAL =====
var _tick_timer: float = 0.0

func _ready() -> void:
	_initialize_game()
	load_game()

func _initialize_game() -> void:
	deck.clear()
	var start_tier = CardFactory.config.starting_card_tier
	var start_rank = CardFactory.config.starting_card_rank
	for i in range(STARTING_DECK_SIZE):
		deck.append({tier = start_tier, rank = start_rank})
	
	hand.clear()
	for i in range(hand_size):
		hand.append({})
	
	milestone_slots = [{}, {}, {}]

func _process(delta: float) -> void:
	# Draw cooldown
	if not can_draw:
		draw_cooldown_current -= delta
		draw_cooldown_changed.emit(draw_cooldown_current, get_draw_cooldown())
		if draw_cooldown_current <= 0:
			can_draw = true
			draw_cooldown_current = 0.0
			draw_cooldown_changed.emit(0.0, get_draw_cooldown())
	
	# Point generation tick
	_tick_timer += delta
	var tick_interval = get_tick_interval()
	if _tick_timer >= tick_interval:
		_tick_timer -= tick_interval
		_on_tick()

func _on_tick() -> void:
	var point_rate = calculate_points_per_tick()
	if point_rate > 0:
		points += point_rate
	tick.emit()

# ===== COMPUTED VALUES (combining upgrades + tier power bonuses) =====

## Draw cooldown: base / divisor (tier power)
func get_draw_cooldown() -> float:
	return maxf(CardFactory.config.min_draw_cooldown, BASE_DRAW_COOLDOWN / draw_cooldown_divisor)

## Tick interval: base / multiplier (tier power)
func get_tick_interval() -> float:
	return maxf(CardFactory.config.min_tick_interval, BASE_TICK_INTERVAL / tick_rate_multiplier)

## Points multiplier from Points Mod upgrade
func get_points_mod_multiplier() -> float:
	return CardFactory.config.get_points_mod_multiplier(upgrade_points_mod_level)

## Pack discount from Pack Discount upgrade
func get_pack_discount_percent() -> float:
	return CardFactory.config.get_pack_discount_percent(upgrade_pack_discount_level)

## Critical merge chance from Critical Merge upgrade
func get_critical_merge_chance() -> float:
	return CardFactory.config.get_critical_merge_chance(upgrade_critical_merge_level)

## Lucky pack chance from Lucky Pack upgrade
func get_lucky_pack_chance() -> float:
	return CardFactory.config.get_lucky_pack_chance(upgrade_lucky_pack_level)

## Deck scoring bonus (tier power)
func get_deck_scoring_bonus() -> int:
	if deck_scoring_percent <= 0:
		return 0
	var total_value: int = 0
	for card in deck:
		total_value += get_card_points_value(card)
	for card in discard_pile:
		total_value += get_card_points_value(card)
	return int(total_value * deck_scoring_percent)

# ===== UPGRADE SYSTEM =====

const UPGRADE_ORDER: Array[String] = ["points_mod", "pack_discount", "critical_merge", "lucky_pack"]

const UPGRADE_NAMES: Dictionary = {
	"points_mod": "Points Mod",
	"pack_discount": "Pack Discount",
	"critical_merge": "Critical Merge",
	"lucky_pack": "Lucky Pack"
}

func _get_upgrade_level(upgrade_id: String) -> int:
	match upgrade_id:
		"points_mod": return upgrade_points_mod_level
		"pack_discount": return upgrade_pack_discount_level
		"critical_merge": return upgrade_critical_merge_level
		"lucky_pack": return upgrade_lucky_pack_level
	return 0

func _set_upgrade_level(upgrade_id: String, value: int) -> void:
	match upgrade_id:
		"points_mod": upgrade_points_mod_level = value
		"pack_discount": upgrade_pack_discount_level = value
		"critical_merge": upgrade_critical_merge_level = value
		"lucky_pack": upgrade_lucky_pack_level = value

func _get_upgrade_name(upgrade_id: String) -> String:
	return UPGRADE_NAMES.get(upgrade_id, upgrade_id)

func get_upgrade_cost(upgrade_id: String) -> int:
	var level = _get_upgrade_level(upgrade_id)
	return CardFactory.config.get_upgrade_cost(upgrade_id, level)

func is_upgrade_at_cap(upgrade_id: String) -> bool:
	return _get_upgrade_level(upgrade_id) >= upgrade_cap

func can_purchase_upgrade(upgrade_id: String) -> bool:
	if is_upgrade_at_cap(upgrade_id):
		return false
	return points >= get_upgrade_cost(upgrade_id)

func try_purchase_upgrade(upgrade_id: String) -> bool:
	if not can_purchase_upgrade(upgrade_id):
		return false
	
	var cost = get_upgrade_cost(upgrade_id)
	points -= cost
	_set_upgrade_level(upgrade_id, _get_upgrade_level(upgrade_id) + 1)
	
	var level = _get_upgrade_level(upgrade_id)
	var value_str = get_upgrade_value_display(upgrade_id)
	
	log_event("Upgraded %s to level %d (%s)" % [_get_upgrade_name(upgrade_id), level, value_str])
	upgrades_changed.emit()
	return true

func get_upgrade_value_display(upgrade_id: String) -> String:
	match upgrade_id:
		"points_mod":
			return "%.1fx" % get_points_mod_multiplier()
		"pack_discount":
			return "%d%%" % int(get_pack_discount_percent() * 100)
		"critical_merge":
			return "%d%%" % int(get_critical_merge_chance() * 100)
		"lucky_pack":
			return "%d%%" % int(get_lucky_pack_chance() * 100)
	return ""

func get_upgrade_next_value_display(upgrade_id: String) -> String:
	var next_level = _get_upgrade_level(upgrade_id) + 1
	match upgrade_id:
		"points_mod":
			return "%.1fx" % CardFactory.config.get_points_mod_multiplier(next_level)
		"pack_discount":
			return "%d%%" % int(CardFactory.config.get_pack_discount_percent(next_level) * 100)
		"critical_merge":
			return "%d%%" % int(CardFactory.config.get_critical_merge_chance(next_level) * 100)
		"lucky_pack":
			return "%d%%" % int(CardFactory.config.get_lucky_pack_chance(next_level) * 100)
	return ""

# ===== POINT FORMULAS =====

func calculate_points_per_tick() -> int:
	var base_total: int = 0
	for card in hand:
		if not card.is_empty():
			base_total += get_card_points_value(card)
	
	# Apply points mod multiplier (upgrade)
	var multiplied = int(base_total * get_points_mod_multiplier())
	
	# Apply tick rate multiplier (tier power) - more ticks = more points
	multiplied = int(multiplied * tick_rate_multiplier)
	
	# Add deck scoring bonus (tier power)
	multiplied += get_deck_scoring_bonus()
	
	return multiplied

func get_card_points_value(card: Dictionary) -> int:
	if card.is_empty():
		return 0
	return CardFactory.config.get_card_points_value(card.tier, card.rank)

func get_pack_cost() -> int:
	var base_cost = PACK_BASE_COST * current_tier
	var discount = get_pack_discount_percent()
	return maxi(0, int(base_cost * (1.0 - discount)))

func get_sell_value(card: Dictionary) -> int:
	if card.is_empty():
		return 0
	return CardFactory.config.get_sell_value(card.tier, card.rank)

# ===== AUTO-DRAW =====

func toggle_auto_draw() -> void:
	if not auto_draw_unlocked:
		return
	auto_draw_enabled = not auto_draw_enabled
	if auto_draw_enabled:
		log_event("Auto-draw enabled")
	else:
		log_event("Auto-draw disabled")

# ===== LOGGING =====

func log_event(message: String) -> void:
	event_logged.emit(message)

# ===== DECK OPERATIONS =====

func draw_card() -> Dictionary:
	if not can_draw:
		return {}
	
	if deck.is_empty():
		if discard_pile.is_empty():
			return {}
		_shuffle_discard_into_deck()
	
	var card = deck.pop_front()
	discard_pile.push_front(card)
	
	can_draw = false
	draw_cooldown_current = get_draw_cooldown()
	
	deck_changed.emit()
	discard_changed.emit()
	log_event("Drew %s" % card_to_string(card))
	return card

func _shuffle_discard_into_deck() -> void:
	deck.append_array(discard_pile)
	discard_pile.clear()
	deck.shuffle()
	log_event("Shuffled discard pile into deck")
	deck_changed.emit()
	discard_changed.emit()

func peek_discard() -> Dictionary:
	if discard_pile.is_empty():
		return {}
	return discard_pile[0]

func take_from_discard() -> Dictionary:
	if discard_pile.is_empty():
		return {}
	var card = discard_pile.pop_front()
	discard_changed.emit()
	return card

func add_to_discard(card: Dictionary) -> void:
	if card.is_empty():
		return
	discard_pile.push_front(card)
	discard_changed.emit()

# ===== HAND OPERATIONS =====

func get_hand_slot(index: int) -> Dictionary:
	if index < 0 or index >= hand.size():
		return {}
	return hand[index]

func set_hand_slot(index: int, card: Dictionary) -> void:
	if index < 0 or index >= hand.size():
		return
	hand[index] = card
	hand_changed.emit()

func clear_hand_slot(index: int) -> Dictionary:
	if index < 0 or index >= hand.size():
		return {}
	var card = hand[index]
	hand[index] = {}
	hand_changed.emit()
	return card

func swap_hand_slots(index_a: int, index_b: int) -> void:
	if index_a < 0 or index_a >= hand.size():
		return
	if index_b < 0 or index_b >= hand.size():
		return
	var temp = hand[index_a]
	hand[index_a] = hand[index_b]
	hand[index_b] = temp
	hand_changed.emit()

func expand_hand(new_size: int) -> void:
	while hand.size() < new_size:
		hand.append({})
	hand_size = new_size
	hand_changed.emit()

func discard_from_hand(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= hand.size():
		return
	var card = hand[slot_index]
	if card.is_empty():
		return
	hand[slot_index] = {}
	discard_pile.push_front(card)
	hand_changed.emit()
	discard_changed.emit()
	log_event("Discarded %s" % card_to_string(card))

# ===== MERGING =====

enum MergeResult { SUCCESS, INVALID_EMPTY, INVALID_TIER, INVALID_RANK, INVALID_MAX_RANK }

func can_merge(card_a: Dictionary, card_b: Dictionary) -> bool:
	return validate_merge(card_a, card_b) == MergeResult.SUCCESS

func validate_merge(card_a: Dictionary, card_b: Dictionary) -> MergeResult:
	if card_a.is_empty() or card_b.is_empty():
		return MergeResult.INVALID_EMPTY
	if card_a.tier != card_b.tier:
		return MergeResult.INVALID_TIER
	if card_a.rank != card_b.rank:
		return MergeResult.INVALID_RANK
	if card_a.rank >= MAX_RANK:
		return MergeResult.INVALID_MAX_RANK
	return MergeResult.SUCCESS

func merge_cards(card_a: Dictionary, card_b: Dictionary) -> Dictionary:
	if not can_merge(card_a, card_b):
		return {}
	
	if not has_merged:
		has_merged = true
	
	# Check for critical merge (+2 ranks instead of +1)
	var rank_bonus = 1
	var critical_chance = get_critical_merge_chance()
	if critical_chance > 0 and randf() < critical_chance:
		# Critical merge! But can't exceed max rank
		if card_a.rank + 2 <= MAX_RANK:
			rank_bonus = 2
			log_event("CRITICAL MERGE!")
	
	var result = {tier = card_a.tier, rank = mini(card_a.rank + rank_bonus, MAX_RANK)}
	log_event("Merged %s + %s -> %s" % [card_to_string(card_a), card_to_string(card_b), card_to_string(result)])
	return result

func try_merge_hand_slots(source_index: int, target_index: int) -> bool:
	var source_card = get_hand_slot(source_index)
	var target_card = get_hand_slot(target_index)
	
	if not can_merge(source_card, target_card):
		return false
	
	var result = merge_cards(source_card, target_card)
	hand[source_index] = {}
	hand[target_index] = result
	hand_changed.emit()
	return true

func try_move_hand_slots(source_index: int, target_index: int) -> bool:
	var source_card = get_hand_slot(source_index)
	var target_card = get_hand_slot(target_index)
	
	if source_card.is_empty():
		return false
	if not target_card.is_empty():
		return false
	
	hand[target_index] = source_card
	hand[source_index] = {}
	hand_changed.emit()
	return true

# ===== BOOSTER PACKS =====

func can_afford_pack() -> bool:
	return points >= get_pack_cost()

func buy_pack() -> Array[Dictionary]:
	if not can_afford_pack():
		return []
	
	var cost = get_pack_cost()
	points -= cost
	
	var cards = _generate_pack(current_tier)
	
	for card in cards:
		deck.append(card)
	deck.shuffle()
	
	if not has_bought_pack:
		has_bought_pack = true
	
	log_event("Bought T%s pack for %d pts" % [CardFactory.get_tier_numeral(current_tier), cost])
	deck_changed.emit()
	
	return cards

func _generate_pack(tier: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	var lucky_triggered = false
	
	# Check for lucky pack on final slot
	var lucky_chance = get_lucky_pack_chance()
	if lucky_chance > 0 and randf() < lucky_chance:
		lucky_triggered = true
	
	for i in range(PACK_SIZE):
		var min_rank = 1
		var max_rank_roll = MAX_RANK - 1  # R10 cannot drop normally
		
		# Pity system
		if i == 2:  # Card 3 (index 2): R2+
			min_rank = CardFactory.config.pack_pity_slot_3_min_rank
		elif i == 4:  # Card 5 (index 4): R3+ or R9 if lucky
			if lucky_triggered:
				cards.append({tier = tier, rank = 9})
				log_event("Lucky Pack triggered! R9 guaranteed!")
				continue
			min_rank = CardFactory.config.pack_pity_slot_5_min_rank
		
		var rank = _roll_rank(min_rank, max_rank_roll)
		cards.append({tier = tier, rank = rank})
	
	return cards

func _roll_rank(min_rank: int, max_rank: int = 9) -> int:
	var roll = randf()
	var cumulative = 0.0
	var probability = CardFactory.config.pack_rank_probability_decay
	
	for rank in range(1, max_rank + 1):
		cumulative += probability
		if roll < cumulative:
			return maxi(rank, min_rank)
		probability *= CardFactory.config.pack_rank_probability_decay
	
	return maxi(max_rank, min_rank)

# ===== MILESTONES =====
# 4 milestones per tier × 10 tiers = 40 total
# Milestone 1: Hand Size (R1 + R2 + R3)
# Milestone 2: Tier Power (R4 + R5 + R6) - unique per tier
# Milestone 3: Upgrade Limit (R7 + R8 + R9)
# Milestone 4: Booster Tier (R10 + R10 + R10)

func get_current_milestone() -> Dictionary:
	if current_milestone_index >= 40:
		return {}  # Game complete
	
	@warning_ignore("integer_division")
	var tier = (current_milestone_index / 4) + 1
	var type_index = current_milestone_index % 4
	
	var type: String
	var required: Array[Dictionary] = []
	var reward_text: String
	
	match type_index:
		0:  # Hand Size: R1, R2, R3
			type = "hand_size"
			required = [
				{tier = tier, rank = 1},
				{tier = tier, rank = 2},
				{tier = tier, rank = 3}
			]
			# T9 and T10 give +5 instead of +1
			if tier >= 9:
				reward_text = "+5 hand slots"
			else:
				reward_text = "+1 hand slot"
		
		1:  # Tier Power: R4, R5, R6
			type = "tier_power"
			required = [
				{tier = tier, rank = 4},
				{tier = tier, rank = 5},
				{tier = tier, rank = 6}
			]
			reward_text = _get_tier_power_reward_text(tier)
		
		2:  # Upgrade Limit: R7, R8, R9
			type = "upgrade_limit"
			required = [
				{tier = tier, rank = 7},
				{tier = tier, rank = 8},
				{tier = tier, rank = 9}
			]
			reward_text = "+10 upgrade cap"
		
		3:  # Booster Tier: R10, R10, R10
			type = "booster_tier"
			required = [
				{tier = tier, rank = 10},
				{tier = tier, rank = 10},
				{tier = tier, rank = 10}
			]
			if tier == MAX_TIER:
				reward_text = "WIN THE GAME!"
			else:
				reward_text = "Unlock T%s packs" % CardFactory.get_tier_numeral(tier + 1)
	
	return {
		index = current_milestone_index,
		tier = tier,
		type = type,
		type_index = type_index,
		required_cards = required,
		reward_text = reward_text,
		is_final = (current_milestone_index == 39)
	}

func _get_tier_power_reward_text(tier: int) -> String:
	match tier:
		1: return "Draw Speed x2"
		2: return "Tick Rate x2"
		3: return "Auto-Draw Unlocked"
		4: return "Deck Scoring: 10%"
		5: return "Draw Speed x2"
		6: return "Tick Rate x2"
		7: return "Deck Scoring: 50%"
		8: return "Draw Speed x2"
		9: return "Tick Rate x2"
		10: return "Deck Scoring: 100%"
	return ""

func get_milestone_slot(index: int) -> Dictionary:
	if index < 0 or index >= milestone_slots.size():
		return {}
	return milestone_slots[index]

func card_matches_milestone_slot(card: Dictionary, slot_index: int) -> bool:
	var milestone = get_current_milestone()
	if milestone.is_empty():
		return false
	if slot_index < 0 or slot_index >= milestone.required_cards.size():
		return false
	
	var required = milestone.required_cards[slot_index]
	return card.tier == required.tier and card.rank == required.rank

func slot_card_in_milestone(card: Dictionary, slot_index: int) -> bool:
	if not card_matches_milestone_slot(card, slot_index):
		return false
	if not milestone_slots[slot_index].is_empty():
		return false
	
	milestone_slots[slot_index] = card
	milestone_changed.emit()
	return true

func remove_card_from_milestone(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= milestone_slots.size():
		return {}
	
	var card = milestone_slots[slot_index]
	milestone_slots[slot_index] = {}
	milestone_changed.emit()
	return card

func can_complete_milestone() -> bool:
	var milestone = get_current_milestone()
	if milestone.is_empty():
		return false
	
	for i in range(milestone.required_cards.size()):
		if milestone_slots[i].is_empty():
			return false
	
	return true

func complete_milestone() -> bool:
	if not can_complete_milestone():
		return false
	
	var milestone = get_current_milestone()
	
	# Apply reward
	match milestone.type:
		"hand_size":
			_apply_hand_size_reward(milestone.tier)
		"tier_power":
			_apply_tier_power_reward(milestone.tier)
		"upgrade_limit":
			_apply_upgrade_limit_reward()
		"booster_tier":
			_apply_booster_tier_reward(milestone.tier)
	
	# Clear milestone slots (cards are consumed)
	milestone_slots = [{}, {}, {}]
	
	# Check for win
	if milestone.is_final:
		log_event("CONGRATULATIONS! You've completed Card Combiner!")
		game_won.emit()
	else:
		current_milestone_index += 1
		log_event("Milestone complete! %s" % milestone.reward_text)
	
	milestone_changed.emit()
	return true

func _apply_hand_size_reward(tier: int) -> void:
	var old_size = hand_size
	var bonus = 5 if tier >= 9 else 1
	expand_hand(hand_size + bonus)
	log_event("Hand size: %d -> %d" % [old_size, hand_size])

func _apply_tier_power_reward(tier: int) -> void:
	match tier:
		1:  # Draw Speed x2 (10s -> 5s)
			draw_cooldown_divisor = 2.0
			log_event("Draw speed doubled! (%.1fs)" % get_draw_cooldown())
		2:  # Tick Rate x2
			tick_rate_multiplier = 2.0
			log_event("Tick rate doubled!")
		3:  # Auto-Draw Unlocked
			auto_draw_unlocked = true
			log_event("Auto-draw unlocked! Toggle in Settings.")
		4:  # Deck Scoring 10%
			deck_scoring_percent = 0.10
			log_event("Deck scoring: 10%% bonus!")
		5:  # Draw Speed x2 (5s -> 2.5s)
			draw_cooldown_divisor = 4.0
			log_event("Draw speed doubled! (%.1fs)" % get_draw_cooldown())
		6:  # Tick Rate x2
			tick_rate_multiplier = 4.0
			log_event("Tick rate doubled!")
		7:  # Deck Scoring 50%
			deck_scoring_percent = 0.50
			log_event("Deck scoring: 50%% bonus!")
		8:  # Draw Speed x2 (2.5s -> 1.25s)
			draw_cooldown_divisor = 8.0
			log_event("Draw speed doubled! (%.1fs)" % get_draw_cooldown())
		9:  # Tick Rate x2
			tick_rate_multiplier = 8.0
			log_event("Tick rate doubled!")
		10:  # Deck Scoring 100%
			deck_scoring_percent = 1.0
			log_event("Deck scoring: 100%% bonus!")
	
	upgrades_changed.emit()

func _apply_upgrade_limit_reward() -> void:
	upgrade_cap += CardFactory.config.upgrade_cap_increment
	log_event("Upgrade cap increased to %d!" % upgrade_cap)
	upgrades_changed.emit()

func _apply_booster_tier_reward(tier: int) -> void:
	current_tier += 1
	
	# Unlock deck viewer and sell after T2
	if current_tier == 2:
		deck_viewer_unlocked = true
		sell_unlocked = true
		log_event("Collection viewer and selling unlocked!")
	
	if current_tier <= MAX_TIER:
		log_event("T%s packs unlocked!" % CardFactory.get_tier_numeral(current_tier))

# ===== SELL =====

func sell_card_from_deck(deck_index: int) -> int:
	if not sell_unlocked:
		return 0
	if deck_index < 0 or deck_index >= deck.size():
		return 0
	
	var card = deck[deck_index]
	var value = get_sell_value(card)
	
	deck.remove_at(deck_index)
	points += value
	
	log_event("Sold %s for %d pts" % [card_to_string(card), value])
	deck_changed.emit()
	return value

# ===== UTILITIES =====

func card_to_string(card: Dictionary) -> String:
	return CardFactory.card_to_string(card)

func get_total_deck_card_count() -> int:
	return deck.size() + discard_pile.size()

# ===== SAVE / LOAD =====

func save_game() -> void:
	var config = ConfigFile.new()
	
	config.set_value("meta", "version", VERSION)
	config.set_value("currency", "points", points)
	
	config.set_value("deck", "cards", deck)
	config.set_value("deck", "discard", discard_pile)
	config.set_value("deck", "hand", hand)
	
	config.set_value("progression", "current_tier", current_tier)
	config.set_value("progression", "hand_size", hand_size)
	config.set_value("progression", "current_milestone_index", current_milestone_index)
	config.set_value("progression", "milestone_slots", milestone_slots)
	
	config.set_value("flags", "has_merged", has_merged)
	config.set_value("flags", "has_bought_pack", has_bought_pack)
	config.set_value("flags", "deck_viewer_unlocked", deck_viewer_unlocked)
	config.set_value("flags", "sell_unlocked", sell_unlocked)
	
	config.set_value("upgrades", "points_mod_level", upgrade_points_mod_level)
	config.set_value("upgrades", "pack_discount_level", upgrade_pack_discount_level)
	config.set_value("upgrades", "critical_merge_level", upgrade_critical_merge_level)
	config.set_value("upgrades", "lucky_pack_level", upgrade_lucky_pack_level)
	config.set_value("upgrades", "upgrade_cap", upgrade_cap)
	
	config.set_value("tier_power", "draw_cooldown_divisor", draw_cooldown_divisor)
	config.set_value("tier_power", "tick_rate_multiplier", tick_rate_multiplier)
	config.set_value("tier_power", "deck_scoring_percent", deck_scoring_percent)
	config.set_value("tier_power", "auto_draw_unlocked", auto_draw_unlocked)
	config.set_value("tier_power", "auto_draw_enabled", auto_draw_enabled)
	
	var err = config.save(SAVE_PATH)
	if err == OK:
		log_event("Game saved")
	else:
		log_event("Save failed: error %d" % err)

func load_game() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	if err != OK:
		log_event("Starting new game")
		return
	
	points = config.get_value("currency", "points", 0)
	
	var loaded_deck = config.get_value("deck", "cards", [])
	deck.clear()
	for card in loaded_deck:
		deck.append(card)
	
	var loaded_discard = config.get_value("deck", "discard", [])
	discard_pile.clear()
	for card in loaded_discard:
		discard_pile.append(card)
	
	var loaded_hand = config.get_value("deck", "hand", [])
	hand.clear()
	for card in loaded_hand:
		hand.append(card)
	
	current_tier = config.get_value("progression", "current_tier", 1)
	hand_size = config.get_value("progression", "hand_size", STARTING_HAND_SIZE)
	current_milestone_index = config.get_value("progression", "current_milestone_index", 0)
	
	var loaded_milestone = config.get_value("progression", "milestone_slots", [{}, {}, {}])
	milestone_slots.clear()
	for slot in loaded_milestone:
		milestone_slots.append(slot)
	
	has_merged = config.get_value("flags", "has_merged", false)
	has_bought_pack = config.get_value("flags", "has_bought_pack", false)
	deck_viewer_unlocked = config.get_value("flags", "deck_viewer_unlocked", false)
	sell_unlocked = config.get_value("flags", "sell_unlocked", false)
	
	upgrade_points_mod_level = config.get_value("upgrades", "points_mod_level", 0)
	upgrade_pack_discount_level = config.get_value("upgrades", "pack_discount_level", 0)
	upgrade_critical_merge_level = config.get_value("upgrades", "critical_merge_level", 0)
	upgrade_lucky_pack_level = config.get_value("upgrades", "lucky_pack_level", 0)
	upgrade_cap = config.get_value("upgrades", "upgrade_cap", CardFactory.config.base_upgrade_cap)
	
	draw_cooldown_divisor = config.get_value("tier_power", "draw_cooldown_divisor", 1.0)
	tick_rate_multiplier = config.get_value("tier_power", "tick_rate_multiplier", 1.0)
	deck_scoring_percent = config.get_value("tier_power", "deck_scoring_percent", 0.0)
	auto_draw_unlocked = config.get_value("tier_power", "auto_draw_unlocked", false)
	auto_draw_enabled = config.get_value("tier_power", "auto_draw_enabled", false)
	
	# Ensure hand is correct size
	while hand.size() < hand_size:
		hand.append({})
	
	log_event("Game loaded (v%s)" % VERSION)

func reset_to_defaults() -> void:
	points = 0
	
	deck.clear()
	var start_tier = CardFactory.config.starting_card_tier
	var start_rank = CardFactory.config.starting_card_rank
	for i in range(STARTING_DECK_SIZE):
		deck.append({tier = start_tier, rank = start_rank})
	deck.shuffle()
	
	discard_pile.clear()
	
	hand.clear()
	for i in range(STARTING_HAND_SIZE):
		hand.append({})
	
	current_tier = 1
	hand_size = STARTING_HAND_SIZE
	current_milestone_index = 0
	milestone_slots = [{}, {}, {}]
	
	has_merged = false
	has_bought_pack = false
	deck_viewer_unlocked = false
	sell_unlocked = false
	
	upgrade_points_mod_level = 0
	upgrade_pack_discount_level = 0
	upgrade_critical_merge_level = 0
	upgrade_lucky_pack_level = 0
	upgrade_cap = CardFactory.config.base_upgrade_cap
	
	draw_cooldown_divisor = 1.0
	tick_rate_multiplier = 1.0
	deck_scoring_percent = 0.0
	auto_draw_unlocked = false
	auto_draw_enabled = false
