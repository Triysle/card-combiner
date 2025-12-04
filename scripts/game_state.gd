extends Node

## Core game state for Card Combiner - deck-based merge game

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

# ===== CONSTANTS =====
const MAX_TIER: int = 10
const MAX_RANK: int = 10
const STARTING_HAND_SIZE: int = 2
const STARTING_DECK_SIZE: int = 10
const BASE_DRAW_COOLDOWN: float = 10.0
const BASE_TICK_INTERVAL: float = 1.0
const PACK_SIZE: int = 5
const PACK_BASE_COST: int = 100

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
var hand_size: int = STARTING_HAND_SIZE
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

# ===== MILESTONE UNLOCKS (permanent flags from tier-specific milestones) =====
var draw_cooldown_divisor: float = 1.0  # 1.0, 2.0, 4.0, 8.0 (halved at T1, T5, T8)
var tick_multiplier: int = 1  # 1, 2, 4, 8 (doubled at T2, T6, T9)
var auto_draw_unlocked: bool = false  # T3
var auto_draw_enabled: bool = false  # Player toggle
var deck_scoring_percent: float = 0.0  # 0.0, 0.1, 0.5, 1.0 (T4, T7, T10)

# ===== PURCHASABLE UPGRADES =====
# All 4 upgrades available from start, caps increase via milestones
var upgrade_points_mod_level: int = 0      # +0.1x per level, starts at 1.0x
var upgrade_pack_discount_level: int = 0   # +1% per level
var upgrade_critical_merge_level: int = 0  # +1% chance per level
var upgrade_lucky_pack_level: int = 0      # +1% chance for R9 in final slot

# Upgrade cap (increased by "Upgrade Limit" milestones - R7,R8,R9)
var upgrade_cap: int = 10  # Base cap, +10 per Upgrade Limit milestone

# ===== INTERNAL =====
var _tick_timer: float = 0.0

func _ready() -> void:
	_initialize_game()
	load_game()

func _initialize_game() -> void:
	# Initialize deck with starting cards
	deck.clear()
	for i in range(STARTING_DECK_SIZE):
		deck.append({tier = 1, rank = 1})
	
	# Initialize hand slots
	hand.clear()
	for i in range(hand_size):
		hand.append({})
	
	# Initialize milestone slots
	milestone_slots = [{}, {}, {}]

func _process(delta: float) -> void:
	# Draw cooldown
	if not can_draw:
		draw_cooldown_current -= delta
		draw_cooldown_changed.emit(draw_cooldown_current, get_draw_cooldown_max())
		if draw_cooldown_current <= 0:
			can_draw = true
			draw_cooldown_current = 0.0
			draw_cooldown_changed.emit(0.0, get_draw_cooldown_max())
	
	# Auto-draw logic
	if auto_draw_unlocked and auto_draw_enabled and can_draw:
		if deck.size() > 0 or discard_pile.size() > 0:
			try_draw()
	
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
	
	# Softlock prevention: give free pack if player has no cards and can't afford one
	_check_softlock()
	
	tick.emit()

func _check_softlock() -> void:
	var total_cards = deck.size() + discard_pile.size()
	for card in hand:
		if not card.is_empty():
			total_cards += 1
	
	if total_cards == 0 and not can_buy_pack():
		log_event("No cards remaining! Here's a free pack.")
		var cards = _generate_pack()
		for card in cards:
			deck.append(card)
		deck.shuffle()
		deck_changed.emit()

# ===== UPGRADE FORMULAS =====

## Points Mod: 1.0 + 0.1 * level (T1 cap=10 gives 2.0x, final=10.0x at level 90)
func get_points_mod_multiplier() -> float:
	return 1.0 + 0.1 * upgrade_points_mod_level

## Pack Discount: 1% per level (T1 cap=10 gives 10%, final=100% free at level 90+)
func get_pack_discount_percent() -> int:
	return mini(upgrade_pack_discount_level, 100)

func get_pack_cost_multiplier() -> float:
	return maxf(0.0, 1.0 - 0.01 * upgrade_pack_discount_level)

## Critical Merge: 1% per level chance for +1 rank on merge
func get_critical_merge_chance() -> float:
	return minf(upgrade_critical_merge_level * 0.01, 1.0)

## Lucky Pack: 1% per level chance for guaranteed R9 in final slot
func get_lucky_pack_chance() -> float:
	return minf(upgrade_lucky_pack_level * 0.01, 1.0)

## Draw cooldown: BASE / divisor (10s -> 5s -> 2.5s -> 1.25s)
func get_draw_cooldown_max() -> float:
	return BASE_DRAW_COOLDOWN / draw_cooldown_divisor

## Tick interval: BASE / multiplier (1s -> 0.5s -> 0.25s -> 0.125s)
func get_tick_interval() -> float:
	return BASE_TICK_INTERVAL / tick_multiplier

## Deck scoring bonus: percent of total deck value added per tick
func get_deck_scoring_bonus() -> int:
	if deck_scoring_percent <= 0:
		return 0
	var total_value: int = 0
	for card in deck:
		total_value += get_card_points_value(card)
	for card in discard_pile:
		total_value += get_card_points_value(card)
	return int(total_value * deck_scoring_percent)

# ===== UPGRADE COSTS =====

func get_upgrade_cost(upgrade_id: String) -> int:
	var level = _get_upgrade_level(upgrade_id)
	# Base cost scales with level: base * (1.5 ^ level)
	var base_cost = 50
	match upgrade_id:
		"pack_discount":
			base_cost = 75
		"critical_merge":
			base_cost = 100
		"lucky_pack":
			base_cost = 150
	return int(base_cost * pow(1.5, level))

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
	save_game()
	return true

func _get_upgrade_name(upgrade_id: String) -> String:
	match upgrade_id:
		"points_mod": return "Points Mod"
		"pack_discount": return "Pack Discount"
		"critical_merge": return "Critical Merge"
		"lucky_pack": return "Lucky Pack"
	return upgrade_id

func get_upgrade_value_display(upgrade_id: String) -> String:
	match upgrade_id:
		"points_mod":
			return "%.1f×" % get_points_mod_multiplier()
		"pack_discount":
			return "%d%%" % get_pack_discount_percent()
		"critical_merge":
			return "%d%%" % int(get_critical_merge_chance() * 100)
		"lucky_pack":
			return "%d%%" % int(get_lucky_pack_chance() * 100)
	return ""

func get_upgrade_next_value_display(upgrade_id: String) -> String:
	var current_level = _get_upgrade_level(upgrade_id)
	match upgrade_id:
		"points_mod":
			return "%.1f×" % (1.0 + 0.1 * (current_level + 1))
		"pack_discount":
			return "%d%%" % mini(current_level + 1, 100)
		"critical_merge":
			return "%d%%" % mini(current_level + 1, 100)
		"lucky_pack":
			return "%d%%" % mini(current_level + 1, 100)
	return ""

# ===== POINT FORMULAS =====

func calculate_points_per_tick() -> int:
	var base_total: int = 0
	for card in hand:
		if not card.is_empty():
			base_total += get_card_points_value(card)
	
	# Apply points mod multiplier
	var modified = int(base_total * get_points_mod_multiplier())
	
	# Add deck scoring bonus
	modified += get_deck_scoring_bonus()
	
	# Apply tick multiplier (from milestone unlocks)
	modified *= tick_multiplier
	
	return modified

func get_card_points_value(card: Dictionary) -> int:
	if card.is_empty():
		return 0
	# Base formula: tier^2 * rank
	return card.tier * card.tier * card.rank

func get_sell_value(card: Dictionary) -> int:
	# 10% of tick value
	@warning_ignore("integer_division")
	return get_card_points_value(card) / 10

# ===== DECK MANAGEMENT =====

func try_draw() -> bool:
	if not can_draw:
		log_event("Draw on cooldown")
		return false
	
	# If deck is empty, shuffle discard into deck first
	if deck.size() == 0:
		if discard_pile.size() == 0:
			log_event("No cards to draw")
			return false
		_shuffle_discard_into_deck()
	
	# Draw top card to discard pile
	var card = deck.pop_front()
	discard_pile.push_front(card)
	
	# Start cooldown
	can_draw = false
	draw_cooldown_current = get_draw_cooldown_max()
	
	deck_changed.emit()
	discard_changed.emit()
	return true

## Alias for try_draw (for compatibility)
func draw_card() -> bool:
	return try_draw()

func _shuffle_discard_into_deck() -> void:
	for card in discard_pile:
		deck.append(card)
	discard_pile.clear()
	deck.shuffle()
	log_event("Deck shuffled")
	deck_changed.emit()
	discard_changed.emit()

func place_card_in_hand(slot_index: int) -> bool:
	if discard_pile.is_empty():
		return false
	if slot_index < 0 or slot_index >= hand.size():
		return false
	if not hand[slot_index].is_empty():
		return false
	
	var card = discard_pile.pop_front()
	hand[slot_index] = card
	
	discard_changed.emit()
	hand_changed.emit()
	return true

func discard_from_hand(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= hand.size():
		return false
	if hand[slot_index].is_empty():
		return false
	
	var card = hand[slot_index]
	hand[slot_index] = {}
	
	# Add to top of discard pile
	discard_pile.push_front(card)
	
	hand_changed.emit()
	discard_changed.emit()
	return true

func swap_hand_slots(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= hand.size():
		return false
	if to_index < 0 or to_index >= hand.size():
		return false
	
	var temp = hand[from_index]
	hand[from_index] = hand[to_index]
	hand[to_index] = temp
	
	hand_changed.emit()
	return true

# ===== MERGING =====

enum MergeResult { SUCCESS, INVALID_EMPTY, INVALID_TIER, INVALID_RANK, INVALID_MAX_RANK }

func can_merge(card1: Dictionary, card2: Dictionary) -> bool:
	if card1.is_empty() or card2.is_empty():
		return false
	if card1.tier != card2.tier:
		return false
	if card1.rank != card2.rank:
		return false
	if card1.rank >= MAX_RANK:
		return false
	return true

func validate_merge(card1: Dictionary, card2: Dictionary) -> MergeResult:
	if card1.is_empty() or card2.is_empty():
		return MergeResult.INVALID_EMPTY
	if card1.tier != card2.tier:
		return MergeResult.INVALID_TIER
	if card1.rank != card2.rank:
		return MergeResult.INVALID_RANK
	if card1.rank >= MAX_RANK:
		return MergeResult.INVALID_MAX_RANK
	return MergeResult.SUCCESS

func merge_cards(card1: Dictionary, card2: Dictionary) -> Dictionary:
	if not can_merge(card1, card2):
		return {}
	
	# Calculate new rank (with critical merge chance)
	var new_rank = card1.rank + 1
	if new_rank < MAX_RANK and randf() < get_critical_merge_chance():
		new_rank += 1
		log_event("Critical merge! +2 ranks")
	
	if not has_merged:
		has_merged = true
	
	var result = {tier = card1.tier, rank = new_rank}
	log_event("Merged: %s + %s = %s" % [card_to_string(card1), card_to_string(card2), card_to_string(result)])
	save_game()
	return result

func try_merge_hand_slots(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= hand.size():
		log_event("Merge failed: invalid from slot")
		return false
	if to_index < 0 or to_index >= hand.size():
		log_event("Merge failed: invalid to slot")
		return false
	
	var card1 = hand[from_index]
	var card2 = hand[to_index]
	
	if not can_merge(card1, card2):
		if card1.is_empty() or card2.is_empty():
			log_event("Merge failed: empty slot")
		elif card1.tier != card2.tier:
			log_event("Merge failed: tier mismatch (%s vs %s)" % [TIER_NUMERALS[card1.tier], TIER_NUMERALS[card2.tier]])
		elif card1.rank != card2.rank:
			log_event("Merge failed: rank mismatch (R%d vs R%d)" % [card1.rank, card2.rank])
		elif card1.rank >= MAX_RANK:
			log_event("Merge failed: already max rank")
		return false
	
	# Calculate new rank (with critical merge chance)
	var new_rank = card1.rank + 1
	if new_rank < MAX_RANK and randf() < get_critical_merge_chance():
		new_rank += 1
		log_event("Critical merge! +2 ranks")
	
	# Merge: card2 becomes upgraded, card1 is consumed
	hand[to_index] = {tier = card1.tier, rank = new_rank}
	hand[from_index] = {}
	
	if not has_merged:
		has_merged = true
	
	log_event("Merged: %s + %s = %s" % [
		card_to_string(card1),
		card_to_string(card2),
		card_to_string(hand[to_index])
	])
	
	hand_changed.emit()
	save_game()
	return true

func try_merge_to_discard(from_hand_index: int) -> bool:
	if from_hand_index < 0 or from_hand_index >= hand.size():
		return false
	if discard_pile.is_empty():
		return false
	
	var card1 = hand[from_hand_index]
	var card2 = discard_pile[0]
	
	if not can_merge(card1, card2):
		return false
	
	# Calculate new rank (with critical merge chance)
	var new_rank = card1.rank + 1
	if new_rank < MAX_RANK and randf() < get_critical_merge_chance():
		new_rank += 1
		log_event("Critical merge! +2 ranks")
	
	# Merge: discard top becomes upgraded, hand card consumed
	discard_pile[0] = {tier = card1.tier, rank = new_rank}
	hand[from_hand_index] = {}
	
	if not has_merged:
		has_merged = true
	
	log_event("Merged to discard: %s" % card_to_string(discard_pile[0]))
	
	hand_changed.emit()
	discard_changed.emit()
	save_game()
	return true

# ===== BOOSTER PACKS =====

func get_pack_cost() -> int:
	var base = PACK_BASE_COST * current_tier
	return int(base * get_pack_cost_multiplier())

func can_buy_pack() -> bool:
	return points >= get_pack_cost()

func buy_pack() -> Array[Dictionary]:
	if not can_buy_pack():
		return []
	
	points -= get_pack_cost()
	var cards = _generate_pack()
	
	# Add cards to deck
	for card in cards:
		deck.append(card)
	deck.shuffle()
	
	if not has_bought_pack:
		has_bought_pack = true
	
	log_event("Opened Tier %s pack (+%d cards)" % [TIER_NUMERALS[current_tier], cards.size()])
	deck_changed.emit()
	save_game()
	return cards

func _generate_pack() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	
	for i in range(PACK_SIZE):
		var rank: int
		
		# Pity system: card 3 (index 2) = R2+, card 5 (index 4) = R3+
		var min_rank = 1
		if i == 2:
			min_rank = 2
		elif i == 4:
			# Final slot: check for lucky pack
			if randf() < get_lucky_pack_chance():
				min_rank = 9
			else:
				min_rank = 3
		
		rank = _roll_card_rank(min_rank)
		
		# R10 cannot drop from packs - cap at R9
		rank = mini(rank, 9)
		
		cards.append({tier = current_tier, rank = rank})
	
	return cards

func _roll_card_rank(min_rank: int = 1) -> int:
	# Exponential distribution: R1 ~50%, R2 ~25%, etc.
	var roll = randf()
	var cumulative = 0.0
	var probability = 0.5
	
	for rank in range(1, MAX_RANK + 1):
		cumulative += probability
		if roll < cumulative:
			return maxi(rank, min_rank)
		probability *= 0.5
	
	return maxi(MAX_RANK, min_rank)

# ===== HAND SIZE =====

func expand_hand(new_size: int) -> void:
	while hand.size() < new_size:
		hand.append({})
	hand_size = new_size
	hand_changed.emit()

# ===== MILESTONES =====
# 4 milestones per tier × 10 tiers = 40 total
# Milestone 1: Hand Size (R1 + R2 + R3) - +1 slot (or +5 for T9/T10)
# Milestone 2: Tier Power (R4 + R5 + R6) - tier-specific unlock
# Milestone 3: Upgrade Limit (R7 + R8 + R9) - +10 upgrade cap
# Milestone 4: Booster Tier (R10 + R10 + R10) - next tier or win

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
		0:  # Hand size: R1, R2, R3
			type = "hand_size"
			required = [
				{tier = tier, rank = 1},
				{tier = tier, rank = 2},
				{tier = tier, rank = 3}
			]
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
		3:  # Booster tier: R10, R10, R10
			type = "booster_tier"
			required = [
				{tier = tier, rank = 10},
				{tier = tier, rank = 10},
				{tier = tier, rank = 10}
			]
			if tier == MAX_TIER:
				reward_text = "WIN THE GAME!"
			else:
				reward_text = "Unlock Tier %s packs" % TIER_NUMERALS[tier + 1]
	
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
		1: return "Draw speed ×2 (10s → 5s)"
		2: return "Tick rate ×2"
		3: return "Auto-draw unlocked"
		4: return "Deck scoring: 10%"
		5: return "Draw speed ×2 (5s → 2.5s)"
		6: return "Tick rate ×2"
		7: return "Deck scoring: 50%"
		8: return "Draw speed ×2 (2.5s → 1.25s)"
		9: return "Tick rate ×2"
		10: return "Deck scoring: 100%"
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
			_apply_hand_size_upgrade(milestone.tier)
		"tier_power":
			_apply_tier_power(milestone.tier)
		"upgrade_limit":
			_apply_upgrade_limit()
		"booster_tier":
			_apply_booster_tier_upgrade(milestone.tier)
	
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
	save_game()
	return true

func _apply_hand_size_upgrade(tier: int) -> void:
	var old_size = hand_size
	var increase = 5 if tier >= 9 else 1
	expand_hand(hand_size + increase)
	log_event("Hand size: %d → %d" % [old_size, hand_size])

func _apply_tier_power(tier: int) -> void:
	match tier:
		1:  # Draw cooldown halved: 10s -> 5s
			draw_cooldown_divisor = 2.0
			log_event("Draw speed doubled! (10s → 5s)")
		2:  # Tick rate doubled
			tick_multiplier = 2
			log_event("Tick rate doubled!")
		3:  # Auto-draw unlocked
			auto_draw_unlocked = true
			log_event("Auto-draw unlocked! Toggle in settings.")
		4:  # Deck scoring 10%
			deck_scoring_percent = 0.1
			log_event("Deck scoring: 10% of deck value per tick!")
		5:  # Draw cooldown halved: 5s -> 2.5s
			draw_cooldown_divisor = 4.0
			log_event("Draw speed doubled! (5s → 2.5s)")
		6:  # Tick rate doubled again
			tick_multiplier = 4
			log_event("Tick rate doubled!")
		7:  # Deck scoring 50%
			deck_scoring_percent = 0.5
			log_event("Deck scoring increased to 50%!")
		8:  # Draw cooldown halved: 2.5s -> 1.25s
			draw_cooldown_divisor = 8.0
			log_event("Draw speed doubled! (2.5s → 1.25s)")
		9:  # Tick rate doubled again
			tick_multiplier = 8
			log_event("Tick rate doubled!")
		10:  # Deck scoring 100%
			deck_scoring_percent = 1.0
			log_event("Deck scoring maxed at 100%!")
	
	upgrades_changed.emit()

func _apply_upgrade_limit() -> void:
	upgrade_cap += 10
	log_event("Upgrade cap increased to %d levels!" % upgrade_cap)
	upgrades_changed.emit()

func _apply_booster_tier_upgrade(_tier: int) -> void:
	current_tier += 1
	
	# Unlock deck viewer and sell after T2
	if current_tier == 2:
		deck_viewer_unlocked = true
		sell_unlocked = true
		log_event("Deck viewer and selling unlocked!")
	
	log_event("Tier %s packs unlocked!" % TIER_NUMERALS[current_tier])

# ===== SELL =====

func sell_card_from_deck(deck_index: int) -> int:
	if not sell_unlocked:
		return 0
	if deck_index < 0 or deck_index >= deck.size():
		return 0
	
	var card = deck[deck_index]
	
	# Can only sell cards below current tier
	if card.tier >= current_tier:
		log_event("Cannot sell current tier cards")
		return 0
	
	var value = get_sell_value(card)
	
	deck.remove_at(deck_index)
	points += value
	
	log_event("Sold %s for %d points" % [card_to_string(card), value])
	deck_changed.emit()
	return value

func sell_card_from_discard(discard_index: int) -> int:
	if not sell_unlocked:
		return 0
	if discard_index < 0 or discard_index >= discard_pile.size():
		return 0
	
	var card = discard_pile[discard_index]
	
	# Can only sell cards below current tier
	if card.tier >= current_tier:
		log_event("Cannot sell current tier cards")
		return 0
	
	var value = get_sell_value(card)
	
	discard_pile.remove_at(discard_index)
	points += value
	
	log_event("Sold %s for %d points" % [card_to_string(card), value])
	discard_changed.emit()
	return value

func sell_card_from_hand(hand_index: int) -> int:
	if not sell_unlocked:
		return 0
	if hand_index < 0 or hand_index >= hand.size():
		return 0
	if hand[hand_index].is_empty():
		return 0
	
	var card = hand[hand_index]
	
	# Can only sell cards below current tier
	if card.tier >= current_tier:
		log_event("Cannot sell current tier cards")
		return 0
	
	var value = get_sell_value(card)
	
	hand[hand_index] = {}
	points += value
	
	log_event("Sold %s for %d points" % [card_to_string(card), value])
	hand_changed.emit()
	return value

# ===== AUTO-DRAW TOGGLE =====

func toggle_auto_draw() -> void:
	if auto_draw_unlocked:
		auto_draw_enabled = not auto_draw_enabled
		log_event("Auto-draw: %s" % ("ON" if auto_draw_enabled else "OFF"))
		save_game()

# ===== UTILITIES =====

const TIER_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

func card_to_string(card: Dictionary) -> String:
	if card.is_empty():
		return "Empty"
	return "T%s R%d" % [TIER_NUMERALS[card.tier], card.rank]

func get_total_deck_card_count() -> int:
	return deck.size() + discard_pile.size()

## Returns the top card of the discard pile without removing it
func peek_discard() -> Dictionary:
	if discard_pile.is_empty():
		return {}
	return discard_pile[0]

## Removes and returns the top card from the discard pile
func take_from_discard() -> Dictionary:
	if discard_pile.is_empty():
		return {}
	var card = discard_pile.pop_front()
	discard_changed.emit()
	return card

## Adds a card to the top of the discard pile
func add_to_discard(card: Dictionary) -> void:
	if not card.is_empty():
		discard_pile.push_front(card)
		discard_changed.emit()

## Clears a hand slot and returns the card that was there
func clear_hand_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= hand.size():
		return {}
	var card = hand[slot_index]
	hand[slot_index] = {}
	hand_changed.emit()
	return card

## Returns the card at the given hand slot (or empty dict if invalid/empty)
func get_hand_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= hand.size():
		return {}
	return hand[slot_index]

## Sets the card at the given hand slot
func set_hand_slot(slot_index: int, card: Dictionary) -> bool:
	if slot_index < 0 or slot_index >= hand.size():
		return false
	hand[slot_index] = card
	hand_changed.emit()
	return true

func log_event(message: String) -> void:
	event_logged.emit(message)

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
	
	# Milestone unlock states
	config.set_value("milestone_unlocks", "draw_cooldown_divisor", draw_cooldown_divisor)
	config.set_value("milestone_unlocks", "tick_multiplier", tick_multiplier)
	config.set_value("milestone_unlocks", "auto_draw_unlocked", auto_draw_unlocked)
	config.set_value("milestone_unlocks", "auto_draw_enabled", auto_draw_enabled)
	config.set_value("milestone_unlocks", "deck_scoring_percent", deck_scoring_percent)
	
	# Purchasable upgrades
	config.set_value("upgrades", "points_mod_level", upgrade_points_mod_level)
	config.set_value("upgrades", "pack_discount_level", upgrade_pack_discount_level)
	config.set_value("upgrades", "critical_merge_level", upgrade_critical_merge_level)
	config.set_value("upgrades", "lucky_pack_level", upgrade_lucky_pack_level)
	config.set_value("upgrades", "upgrade_cap", upgrade_cap)
	
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
	
	# Milestone unlock states
	draw_cooldown_divisor = config.get_value("milestone_unlocks", "draw_cooldown_divisor", 1.0)
	tick_multiplier = config.get_value("milestone_unlocks", "tick_multiplier", 1)
	auto_draw_unlocked = config.get_value("milestone_unlocks", "auto_draw_unlocked", false)
	auto_draw_enabled = config.get_value("milestone_unlocks", "auto_draw_enabled", false)
	deck_scoring_percent = config.get_value("milestone_unlocks", "deck_scoring_percent", 0.0)
	
	# Purchasable upgrades
	upgrade_points_mod_level = config.get_value("upgrades", "points_mod_level", 0)
	upgrade_pack_discount_level = config.get_value("upgrades", "pack_discount_level", 0)
	upgrade_critical_merge_level = config.get_value("upgrades", "critical_merge_level", 0)
	upgrade_lucky_pack_level = config.get_value("upgrades", "lucky_pack_level", 0)
	upgrade_cap = config.get_value("upgrades", "upgrade_cap", 10)
	
	# Ensure hand is correct size
	while hand.size() < hand_size:
		hand.append({})
	
	log_event("Game loaded (v%s)" % VERSION)

func reset_to_defaults() -> void:
	points = 0
	deck.clear()
	for i in range(10):
		deck.append({tier = 1, rank = 1})
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
	
	# Reset milestone unlocks
	draw_cooldown_divisor = 1.0
	tick_multiplier = 1
	auto_draw_unlocked = false
	auto_draw_enabled = false
	deck_scoring_percent = 0.0
	
	# Reset purchasable upgrades
	upgrade_points_mod_level = 0
	upgrade_pack_discount_level = 0
	upgrade_critical_merge_level = 0
	upgrade_lucky_pack_level = 0
	upgrade_cap = 10
