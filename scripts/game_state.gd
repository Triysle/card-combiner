extends Node

## Core game state for Card Combiner - deck-based merge game

const VERSION: String = "0.1.3"
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
const MAX_TIER: int = 5  # Reduced to 5 tiers for now
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
var current_milestone_index: int = 0  # 0-19 (4 per tier × 5 tiers)
var milestone_slots: Array[Dictionary] = [{}, {}, {}]  # 3 slots for milestone cards

# ===== DRAW COOLDOWN =====
var draw_cooldown_current: float = 0.0
var can_draw: bool = true

# ===== UNLOCK FLAGS =====
var has_merged: bool = false
var has_bought_pack: bool = false
var deck_viewer_unlocked: bool = false
var sell_unlocked: bool = false

# ===== UPGRADES =====
# Upgrade levels (0 = not purchased yet)
var upgrade_point_gen_level: int = 0      # Unlocked T1
var upgrade_pack_cost_level: int = 0      # Unlocked T2
var upgrade_draw_speed_level: int = 0     # Unlocked T3
var upgrade_tick_speed_level: int = 0     # Unlocked T4
var upgrade_deck_value_level: int = 0     # Unlocked T5

# Upgrade caps (increased by "Upgrade Cap" milestones)
var upgrade_cap: int = 10  # Base cap, +10 per upgrade cap milestone

# Track which upgrades are unlocked
var upgrades_unlocked: Array[String] = []

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

# ===== UPGRADE FORMULAS =====

## Point Gen multiplier: 1.0 + 0.1 * level (so level 10 = 2.0x)
func get_point_gen_multiplier() -> float:
	return 1.0 + 0.1 * upgrade_point_gen_level

## Pack cost multiplier: 1.0 - 0.05 * level (so level 10 = 0.5x = 50% cost)
func get_pack_cost_multiplier() -> float:
	return maxf(0.1, 1.0 - 0.05 * upgrade_pack_cost_level)

## Draw cooldown: BASE - 0.5 * level (so level 10 = 5s instead of 10s)
func get_draw_cooldown_max() -> float:
	return maxf(0.5, BASE_DRAW_COOLDOWN - 0.5 * upgrade_draw_speed_level)

## Tick interval: BASE - 0.05 * level (so level 10 = 0.5s instead of 1s)
func get_tick_interval() -> float:
	return maxf(0.1, BASE_TICK_INTERVAL - 0.05 * upgrade_tick_speed_level)

## Deck value bonus: level * total_deck_value * 0.01 (1% of deck value per level)
func get_deck_value_bonus() -> int:
	if upgrade_deck_value_level == 0:
		return 0
	var total_value: int = 0
	for card in deck:
		total_value += get_card_points_value(card)
	for card in discard_pile:
		total_value += get_card_points_value(card)
	return int(total_value * 0.01 * upgrade_deck_value_level)

# ===== UPGRADE COSTS =====

func get_upgrade_cost(upgrade_id: String) -> int:
	var level = _get_upgrade_level(upgrade_id)
	# Base cost scales with level: 50 * (1.5 ^ level)
	var base_cost = 50
	match upgrade_id:
		"pack_cost":
			base_cost = 75
		"draw_speed":
			base_cost = 100
		"tick_speed":
			base_cost = 150
		"deck_value":
			base_cost = 200
	return int(base_cost * pow(1.5, level))

func _get_upgrade_level(upgrade_id: String) -> int:
	match upgrade_id:
		"point_gen": return upgrade_point_gen_level
		"pack_cost": return upgrade_pack_cost_level
		"draw_speed": return upgrade_draw_speed_level
		"tick_speed": return upgrade_tick_speed_level
		"deck_value": return upgrade_deck_value_level
	return 0

func _set_upgrade_level(upgrade_id: String, value: int) -> void:
	match upgrade_id:
		"point_gen": upgrade_point_gen_level = value
		"pack_cost": upgrade_pack_cost_level = value
		"draw_speed": upgrade_draw_speed_level = value
		"tick_speed": upgrade_tick_speed_level = value
		"deck_value": upgrade_deck_value_level = value

func is_upgrade_unlocked(upgrade_id: String) -> bool:
	return upgrade_id in upgrades_unlocked

func is_upgrade_at_cap(upgrade_id: String) -> bool:
	return _get_upgrade_level(upgrade_id) >= upgrade_cap

func can_purchase_upgrade(upgrade_id: String) -> bool:
	if not is_upgrade_unlocked(upgrade_id):
		return false
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
	var value_str = ""
	match upgrade_id:
		"point_gen":
			value_str = "%.1f×" % get_point_gen_multiplier()
		"pack_cost":
			value_str = "%d%%" % int(get_pack_cost_multiplier() * 100)
		"draw_speed":
			value_str = "%.1fs" % get_draw_cooldown_max()
		"tick_speed":
			value_str = "%.2fs" % get_tick_interval()
		"deck_value":
			value_str = "+%d/tick" % get_deck_value_bonus()
	
	log_event("Upgraded %s to level %d (%s)" % [_get_upgrade_name(upgrade_id), level, value_str])
	upgrades_changed.emit()
	return true

func _get_upgrade_name(upgrade_id: String) -> String:
	match upgrade_id:
		"point_gen": return "Point Gen"
		"pack_cost": return "Pack Cost"
		"draw_speed": return "Draw Speed"
		"tick_speed": return "Tick Speed"
		"deck_value": return "Deck Value"
	return upgrade_id

func get_upgrade_value_display(upgrade_id: String) -> String:
	match upgrade_id:
		"point_gen":
			return "%.1f×" % get_point_gen_multiplier()
		"pack_cost":
			return "%d%%" % int(get_pack_cost_multiplier() * 100)
		"draw_speed":
			return "%.1fs" % get_draw_cooldown_max()
		"tick_speed":
			return "%.2fs" % get_tick_interval()
		"deck_value":
			return "+%d/tick" % get_deck_value_bonus()
	return ""

func get_upgrade_next_value_display(upgrade_id: String) -> String:
	# Simulate what the next level would give
	var current_level = _get_upgrade_level(upgrade_id)
	match upgrade_id:
		"point_gen":
			return "%.1f×" % (1.0 + 0.1 * (current_level + 1))
		"pack_cost":
			return "%d%%" % int(maxf(0.1, 1.0 - 0.05 * (current_level + 1)) * 100)
		"draw_speed":
			return "%.1fs" % maxf(0.5, BASE_DRAW_COOLDOWN - 0.5 * (current_level + 1))
		"tick_speed":
			return "%.2fs" % maxf(0.1, BASE_TICK_INTERVAL - 0.05 * (current_level + 1))
		"deck_value":
			# This one is trickier since it depends on deck - just show level
			return "Level %d" % (current_level + 1)
	return ""

# ===== POINT FORMULAS =====

func calculate_points_per_tick() -> int:
	var base_total: int = 0
	for card in hand:
		if not card.is_empty():
			base_total += get_card_points_value(card)
	
	# Apply point gen multiplier
	var multiplied = int(base_total * get_point_gen_multiplier())
	
	# Add deck value bonus
	multiplied += get_deck_value_bonus()
	
	return multiplied

## Card point value = tier² × rank (T1R1=1, T1R10=10, T5R1=25, T5R10=250)
func get_card_points_value(card: Dictionary) -> int:
	if card.is_empty():
		return 0
	return card.tier * card.tier * card.rank

func get_pack_cost() -> int:
	var base_cost = PACK_BASE_COST * current_tier
	return int(base_cost * get_pack_cost_multiplier())

func get_sell_value(card: Dictionary) -> int:
	if card.is_empty():
		return 0
	return maxi(1, get_card_points_value(card) / 10)

# ===== LOGGING =====

func log_event(message: String) -> void:
	event_logged.emit(message)

# ===== DECK OPERATIONS =====

func draw_card() -> Dictionary:
	if not can_draw:
		return {}
	
	# If deck is empty, shuffle discard into deck
	if deck.is_empty():
		if discard_pile.is_empty():
			return {}  # No cards anywhere
		_shuffle_discard_into_deck()
	
	var card = deck.pop_front()
	discard_pile.push_front(card)
	
	# Start cooldown
	can_draw = false
	draw_cooldown_current = get_draw_cooldown_max()
	
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
	# Simply add card to top of discard pile
	discard_pile.push_front(card)
	discard_changed.emit()

func replace_discard_top(new_card: Dictionary) -> Dictionary:
	## Swap the top of discard with a new card, return the old top
	if new_card.is_empty():
		return {}
	if discard_pile.is_empty():
		discard_pile.push_front(new_card)
		discard_changed.emit()
		return {}
	var old_card = discard_pile[0]
	discard_pile[0] = new_card
	discard_changed.emit()
	return old_card

# ===== HAND OPERATIONS =====

func get_hand_slot(index: int) -> Dictionary:
	if index < 0 or index >= hand.size():
		return {}
	return hand[index]

func set_hand_slot(index: int, card: Dictionary) -> bool:
	if index < 0 or index >= hand.size():
		return false
	hand[index] = card
	hand_changed.emit()
	return true

func clear_hand_slot(index: int) -> Dictionary:
	if index < 0 or index >= hand.size():
		return {}
	var card = hand[index]
	hand[index] = {}
	hand_changed.emit()
	return card

func is_hand_slot_empty(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	return hand[index].is_empty()

func find_empty_hand_slot() -> int:
	for i in range(hand.size()):
		if hand[i].is_empty():
			return i
	return -1

func get_hand_card_count() -> int:
	var count = 0
	for card in hand:
		if not card.is_empty():
			count += 1
	return count

func expand_hand(new_size: int) -> void:
	while hand.size() < new_size:
		hand.append({})
	hand_size = new_size
	hand_changed.emit()

func swap_hand_slots(index1: int, index2: int) -> bool:
	if index1 < 0 or index1 >= hand.size():
		return false
	if index2 < 0 or index2 >= hand.size():
		return false
	var temp = hand[index1]
	hand[index1] = hand[index2]
	hand[index2] = temp
	hand_changed.emit()
	return true

# ===== MERGE OPERATIONS =====

enum MergeResult { VALID, INVALID_EMPTY, INVALID_TIER, INVALID_RANK, INVALID_MAX_RANK }

func can_merge(card1: Dictionary, card2: Dictionary) -> bool:
	return validate_merge(card1, card2) == MergeResult.VALID

func validate_merge(card1: Dictionary, card2: Dictionary) -> MergeResult:
	if card1.is_empty() or card2.is_empty():
		return MergeResult.INVALID_EMPTY
	if card1.tier != card2.tier:
		return MergeResult.INVALID_TIER
	if card1.rank != card2.rank:
		return MergeResult.INVALID_RANK
	if card1.rank >= MAX_RANK:
		return MergeResult.INVALID_MAX_RANK
	return MergeResult.VALID

func merge_cards(card1: Dictionary, card2: Dictionary) -> Dictionary:
	if not can_merge(card1, card2):
		return {}
	
	var result = {tier = card1.tier, rank = card1.rank + 1}
	
	if not has_merged:
		has_merged = true
	
	log_event("Merged %s + %s → %s" % [card_to_string(card1), card_to_string(card2), card_to_string(result)])
	return result

func try_merge_hand_slots(source_index: int, target_index: int) -> bool:
	var source_card = get_hand_slot(source_index)
	var target_card = get_hand_slot(target_index)
	
	var result = merge_cards(source_card, target_card)
	if result.is_empty():
		return false
	
	# Clear source, set target to result
	clear_hand_slot(source_index)
	set_hand_slot(target_index, result)
	return true

func try_move_hand_slots(source_index: int, target_index: int) -> bool:
	if not is_hand_slot_empty(target_index):
		return false
	
	var card = clear_hand_slot(source_index)
	if card.is_empty():
		return false
	
	set_hand_slot(target_index, card)
	log_event("Moved card to slot %d" % (target_index + 1))
	return true

# ===== BOOSTER PACKS =====

func can_afford_pack() -> bool:
	return points >= get_pack_cost()

func buy_booster_pack() -> Array[Dictionary]:
	var cost = get_pack_cost()
	if points < cost:
		return []
	
	points -= cost
	var cards = _generate_pack(current_tier)
	
	# Add cards to bottom of deck
	for card in cards:
		deck.push_back(card)
	
	# Shuffle deck
	deck.shuffle()
	
	if not has_bought_pack:
		has_bought_pack = true
	
	var card_strings: Array[String] = []
	for card in cards:
		card_strings.append(card_to_string(card))
	log_event("Opened T%s pack: %s" % [TIER_NUMERALS[current_tier], ", ".join(card_strings)])
	
	deck_changed.emit()
	return cards

func _generate_pack(tier: int) -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	
	for i in range(PACK_SIZE):
		var min_rank = 1
		# Pity system: card 3 (index 2) is R2+, card 5 (index 4) is R3+
		if i == 2:
			min_rank = 2
		elif i == 4:
			min_rank = 3
		
		var rank = _roll_card_rank(min_rank)
		cards.append({tier = tier, rank = rank})
	
	return cards

func _roll_card_rank(min_rank: int = 1) -> int:
	# Exponential distribution: R1 ~50%, R2 ~25%, R3 ~12.5%, etc.
	var roll = randf()
	var cumulative = 0.0
	var probability = 0.5
	
	for rank in range(1, MAX_RANK + 1):
		cumulative += probability
		if roll < cumulative:
			return maxi(rank, min_rank)
		probability *= 0.5
	
	return maxi(MAX_RANK, min_rank)

# ===== MILESTONES =====
# 4 milestones per tier × 5 tiers = 20 total
# Milestone 1: Hand Size (R1 + R2 + R3)
# Milestone 2: New Upgrade (R4 + R5 + R6)
# Milestone 3: Upgrade Cap (R7 + R8 + R9)
# Milestone 4: Booster Tier (R10 + R10 + R10)

func get_current_milestone() -> Dictionary:
	if current_milestone_index >= 20:
		return {}  # Game complete
	
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
			reward_text = "+1 hand slot"
		1:  # New Upgrade: R4, R5, R6
			type = "new_upgrade"
			required = [
				{tier = tier, rank = 4},
				{tier = tier, rank = 5},
				{tier = tier, rank = 6}
			]
			var upgrade_name = _get_tier_upgrade_name(tier)
			reward_text = "Unlock: %s" % upgrade_name
		2:  # Upgrade Cap: R7, R8, R9
			type = "upgrade_cap"
			required = [
				{tier = tier, rank = 7},
				{tier = tier, rank = 8},
				{tier = tier, rank = 9}
			]
			reward_text = "+10 upgrade levels"
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
		is_final = (current_milestone_index == 19)
	}

func _get_tier_upgrade_name(tier: int) -> String:
	match tier:
		1: return "Point Gen ×"
		2: return "Pack Cost -"
		3: return "Draw Speed"
		4: return "Tick Speed"
		5: return "Deck Value Bonus"
	return ""

func _get_tier_upgrade_id(tier: int) -> String:
	match tier:
		1: return "point_gen"
		2: return "pack_cost"
		3: return "draw_speed"
		4: return "tick_speed"
		5: return "deck_value"
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
			_apply_hand_size_upgrade()
		"new_upgrade":
			_apply_new_upgrade(milestone.tier)
		"upgrade_cap":
			_apply_upgrade_cap()
		"booster_tier":
			_apply_booster_tier_upgrade(milestone.tier)
	
	# Clear milestone slots (cards are consumed)
	milestone_slots = [{}, {}, {}]
	
	# Check for win
	if milestone.is_final:
		log_event("🎉 CONGRATULATIONS! You've completed Card Combiner!")
		game_won.emit()
	else:
		current_milestone_index += 1
		log_event("Milestone complete! %s" % milestone.reward_text)
	
	milestone_changed.emit()
	return true

func _apply_hand_size_upgrade() -> void:
	var old_size = hand_size
	expand_hand(hand_size + 1)
	log_event("Hand size: %d → %d" % [old_size, hand_size])

func _apply_new_upgrade(tier: int) -> void:
	var upgrade_id = _get_tier_upgrade_id(tier)
	if upgrade_id != "" and upgrade_id not in upgrades_unlocked:
		upgrades_unlocked.append(upgrade_id)
		log_event("New upgrade unlocked: %s" % _get_upgrade_name(upgrade_id))
		upgrades_changed.emit()

func _apply_upgrade_cap() -> void:
	upgrade_cap += 10
	log_event("Upgrade cap increased to %d levels!" % upgrade_cap)
	upgrades_changed.emit()

func _apply_booster_tier_upgrade(tier: int) -> void:
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
	var value = get_sell_value(card)
	
	deck.remove_at(deck_index)
	points += value
	
	log_event("Sold %s for %d points" % [card_to_string(card), value])
	deck_changed.emit()
	return value

# ===== UTILITIES =====

const TIER_NUMERALS: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]

func card_to_string(card: Dictionary) -> String:
	if card.is_empty():
		return "Empty"
	return "T%s R%d" % [TIER_NUMERALS[card.tier], card.rank]

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
	
	config.set_value("upgrades", "point_gen_level", upgrade_point_gen_level)
	config.set_value("upgrades", "pack_cost_level", upgrade_pack_cost_level)
	config.set_value("upgrades", "draw_speed_level", upgrade_draw_speed_level)
	config.set_value("upgrades", "tick_speed_level", upgrade_tick_speed_level)
	config.set_value("upgrades", "deck_value_level", upgrade_deck_value_level)
	config.set_value("upgrades", "upgrade_cap", upgrade_cap)
	config.set_value("upgrades", "unlocked", upgrades_unlocked)
	
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
	
	upgrade_point_gen_level = config.get_value("upgrades", "point_gen_level", 0)
	upgrade_pack_cost_level = config.get_value("upgrades", "pack_cost_level", 0)
	upgrade_draw_speed_level = config.get_value("upgrades", "draw_speed_level", 0)
	upgrade_tick_speed_level = config.get_value("upgrades", "tick_speed_level", 0)
	upgrade_deck_value_level = config.get_value("upgrades", "deck_value_level", 0)
	upgrade_cap = config.get_value("upgrades", "upgrade_cap", 10)
	
	var loaded_unlocked = config.get_value("upgrades", "unlocked", [])
	upgrades_unlocked.clear()
	for u in loaded_unlocked:
		upgrades_unlocked.append(u)
	
	# Ensure hand is correct size
	while hand.size() < hand_size:
		hand.append({})
	
	log_event("Game loaded (v%s)" % VERSION)
