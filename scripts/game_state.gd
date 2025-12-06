# scripts/game_state.gd
extends Node

## Game state singleton - manages all game data
## Progression: Start with 10 species unlocked, unlock more by completing species (MAX all forms)

# ===== SIGNALS =====
signal points_changed(value: int)
signal deck_changed()
signal discard_changed()
signal hand_changed()
signal draw_cooldown_changed(remaining: float, total: float)
signal tick()
signal collection_changed()
signal game_won()
signal form_unlocked(mid: int, form: int, card: Dictionary)
signal species_unlocked(mid: int, card: Dictionary)

# ===== CONSTANTS =====
const MAX_NORMAL_RANK: int = 4    # Highest rank before MAX (★★★★)
const MAX_CARD_RANK: int = 5      # MAX cards are rank 5
const BASE_HAND_SIZE: int = 10
const BASE_DRAW_COOLDOWN: float = 10.0
const PACK_SIZE: int = 5
const SAVE_PATH: String = "user://savegame.cfg"
const SAVE_VERSION: int = 9  # Added collection points, removed critical merge
const STARTING_SPECIES_COUNT: int = 10  # How many species unlocked at game start

# Tick timer
var _tick_timer: Timer

# ===== ENUMS =====
enum UpgradeType {
	POINTS_MULT,
	DRAW_SPEED,
	PACK_DISCOUNT,
	COLLECTION_MULT,
	FOIL_CHANCE,
	FOIL_BONUS
}

enum MergeResult {
	SUCCESS,
	INVALID_EMPTY,
	INVALID_DIFFERENT,
	INVALID_MAX,
	INVALID_RANK,
	INVALID_FORM
}

# ===== GAME STATE =====
var points: int = 0
var deck: Array[Dictionary] = []
var discard_pile: Array[Dictionary] = []
var hand: Array[Dictionary] = []
var upgrade_levels: Dictionary = {}

# Species/Collection tracking
var unlocked_species: Array[int] = []     # MIDs of species player can access
var unlocked_forms: Dictionary = {}       # {mid: highest_unlocked_form} - what can drop from packs
var submitted_forms: Dictionary = {}      # {mid: [form_indices]} - completed forms
var submit_slot: Dictionary = {}          # Card in submit slot
var packs_purchased: int = 0              # Track for first free pack

# Track last unlock for UI (cleared after read)
var _last_unlocked_species_card: Dictionary = {}

# Draw cooldown
var can_draw: bool = true
var _draw_cooldown_remaining: float = 0.0
var _current_draw_cooldown: float = BASE_DRAW_COOLDOWN

# Computed property for grid compatibility
var hand_size: int:
	get: return hand.size()

# ===== INITIALIZATION =====
func _ready() -> void:
	_init_upgrades()
	_setup_tick_timer()
	if not load_game():
		_init_new_game()

func _setup_tick_timer() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_on_tick_timer_timeout)
	add_child(_tick_timer)

func _init_upgrades() -> void:
	for type in UpgradeType.values():
		upgrade_levels[type] = 0

func _init_new_game() -> void:
	points = 0
	deck.clear()
	discard_pile.clear()
	hand.clear()
	unlocked_species.clear()
	unlocked_forms.clear()
	submitted_forms.clear()
	submit_slot = {}
	packs_purchased = 0
	_last_unlocked_species_card = {}
	
	# Initialize unlocked species: first N species by MID
	var all_mids = MonsterRegistry.get_all_mids()
	for i in range(mini(STARTING_SPECIES_COUNT, all_mids.size())):
		var mid = all_mids[i]
		unlocked_species.append(mid)
		unlocked_forms[mid] = 1  # Each unlocked species starts with form 1 available
	
	# Initialize hand with empty slots
	var starting_hand_size = get_current_hand_size()
	for i in range(starting_hand_size):
		hand.append({})
	
	deck_changed.emit()
	hand_changed.emit()
	collection_changed.emit()

func _process(delta: float) -> void:
	# Handle draw cooldown
	if not can_draw:
		_draw_cooldown_remaining -= delta
		draw_cooldown_changed.emit(_draw_cooldown_remaining, _current_draw_cooldown)
		if _draw_cooldown_remaining <= 0:
			can_draw = true
			_draw_cooldown_remaining = 0

func _on_tick_timer_timeout() -> void:
	var pts = calculate_points_per_tick()
	if pts > 0:
		add_points(pts)
	tick.emit()

# ===== HAND SIZE =====
func get_current_hand_size() -> int:
	return BASE_HAND_SIZE

func _resize_hand(new_size: int) -> void:
	while hand.size() < new_size:
		hand.append({})
	hand_changed.emit()

# ===== POINTS =====
func add_points(amount: int) -> void:
	points += amount
	points_changed.emit(points)

func spend_points(amount: int) -> bool:
	if points >= amount:
		points -= amount
		points_changed.emit(points)
		return true
	return false

func calculate_points_per_tick() -> int:
	var hand_total = get_hand_points_rate()
	var collection_total = get_collection_points_rate()
	
	# Apply points multiplier to combined total
	var mult_level = upgrade_levels.get(UpgradeType.POINTS_MULT, 0)
	var total = hand_total + collection_total
	if mult_level > 0:
		total *= int(pow(2, mult_level))
	
	return total

## Get points per tick from hand cards only (before global multiplier)
func get_hand_points_rate() -> int:
	var total = 0
	for card in hand:
		if CardFactory.is_valid_card(card):
			total += get_card_points_with_foil(card)
	return total

## Get points per tick from collection (before global multiplier)
func get_collection_points_rate() -> int:
	var submitted_count = get_submitted_form_count()
	var base_rate = 100 * submitted_count
	
	# Apply collection multiplier
	var coll_level = upgrade_levels.get(UpgradeType.COLLECTION_MULT, 0)
	if coll_level > 0:
		base_rate *= int(pow(2, coll_level))
	
	return base_rate

## Calculate points for a single card including foil bonus (but not global multiplier)
func get_card_points_with_foil(card: Dictionary) -> int:
	if not CardFactory.is_valid_card(card):
		return 0
	
	var base_pts = CardFactory.get_card_points_value(card)
	
	# Apply foil bonus if applicable
	if card.get("is_foil", false):
		var foil_level = upgrade_levels.get(UpgradeType.FOIL_BONUS, 0)
		var foil_mult = 2 + foil_level  # 2x, 3x, 4x, 5x
		base_pts *= foil_mult
	
	return base_pts

# ===== DECK & DRAW =====
func draw_card() -> void:
	if not can_draw:
		return
	
	# Shuffle discard into deck if needed
	if deck.is_empty() and not discard_pile.is_empty():
		deck = discard_pile.duplicate()
		discard_pile.clear()
		deck.shuffle()
		deck_changed.emit()
		discard_changed.emit()
	
	if deck.is_empty():
		return
	
	var card = deck.pop_back()
	discard_pile.push_front(card)
	
	# Start cooldown
	can_draw = false
	_current_draw_cooldown = get_draw_cooldown()
	_draw_cooldown_remaining = _current_draw_cooldown
	
	deck_changed.emit()
	discard_changed.emit()

func get_draw_cooldown() -> float:
	var level = upgrade_levels.get(UpgradeType.DRAW_SPEED, 0)
	var cooldowns = [10.0, 5.0, 2.5, 1.25, 0.5]
	return cooldowns[mini(level, cooldowns.size() - 1)]

# ===== HAND MANAGEMENT =====
func get_hand_slot(index: int) -> Dictionary:
	if index < 0 or index >= hand.size():
		return {}
	return hand[index]

func set_hand_slot(index: int, card: Dictionary) -> void:
	if index >= 0 and index < hand.size():
		hand[index] = card
		hand_changed.emit()

func is_hand_slot_empty(index: int) -> bool:
	return CardFactory.is_empty_card(get_hand_slot(index))

func place_card_in_hand(card: Dictionary, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= hand.size():
		return false
	if not is_hand_slot_empty(slot_index):
		return false
	
	hand[slot_index] = card
	hand_changed.emit()
	return true

func remove_card_from_hand(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= hand.size():
		return {}
	var card = hand[slot_index]
	hand[slot_index] = {}
	hand_changed.emit()
	return card

# ===== DISCARD PILE =====
func get_top_discard() -> Dictionary:
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
	if CardFactory.is_valid_card(card):
		discard_pile.push_front(card)
		discard_changed.emit()

# ===== MERGING =====
func validate_merge(card_a: Dictionary, card_b: Dictionary) -> MergeResult:
	if CardFactory.is_empty_card(card_a) or CardFactory.is_empty_card(card_b):
		return MergeResult.INVALID_EMPTY
	if card_a.is_max or card_b.is_max:
		return MergeResult.INVALID_MAX
	if card_a.mid != card_b.mid:
		return MergeResult.INVALID_DIFFERENT
	if card_a.form != card_b.form:
		return MergeResult.INVALID_FORM
	if card_a.rank != card_b.rank:
		return MergeResult.INVALID_RANK
	return MergeResult.SUCCESS

func merge_cards(card_a: Dictionary, card_b: Dictionary) -> Dictionary:
	var result = validate_merge(card_a, card_b)
	if result != MergeResult.SUCCESS:
		return {}
	
	var mid = card_a.mid
	var form = card_a.form
	var rank = card_a.rank
	
	# Rank 4 + Rank 4 = MAX
	if rank == MAX_NORMAL_RANK:
		return CardFactory.create_max_card(mid, form, _roll_foil())
	
	# Normal merge: +1 rank
	var new_rank = rank + 1
	
	return CardFactory.create_card(mid, form, new_rank, _roll_foil())

func _roll_foil() -> bool:
	var foil_level = upgrade_levels.get(UpgradeType.FOIL_CHANCE, 0)
	var foil_chance = foil_level * 0.05  # 5% per level, max 25%
	return randf() < foil_chance

func get_merge_failure_reason(result: MergeResult) -> String:
	match result:
		MergeResult.INVALID_EMPTY:
			return "Cannot merge with empty slot"
		MergeResult.INVALID_DIFFERENT:
			return "Cards must be same species"
		MergeResult.INVALID_FORM:
			return "Cards must be same form"
		MergeResult.INVALID_MAX:
			return "Cannot merge MAX cards"
		MergeResult.INVALID_RANK:
			return "Cards must be same rank"
		_:
			return "Unknown error"

# ===== BOOSTER PACKS =====
func get_pack_cost() -> int:
	# Cost = total card value * 10 (0 cards = free)
	var card_value = _get_total_card_value()
	
	# Apply discount from upgrades
	var discount_level = upgrade_levels.get(UpgradeType.PACK_DISCOUNT, 0)
	var cost = card_value * 10
	for i in range(discount_level):
		cost = cost / 2.0
	cost = int(cost)
	
	return cost

func _get_total_card_value() -> int:
	var total = 0
	for card in deck:
		total += CardFactory.get_card_points_value(card)
	for card in discard_pile:
		total += CardFactory.get_card_points_value(card)
	for card in hand:
		if CardFactory.is_valid_card(card):
			total += CardFactory.get_card_points_value(card)
	return total

func can_buy_pack() -> bool:
	return points >= get_pack_cost()

func buy_pack() -> Array[Dictionary]:
	var cost = get_pack_cost()
	if cost > 0 and not spend_points(cost):
		return []
	
	packs_purchased += 1
	var pack = _generate_pack()
	
	# Add cards to deck
	for card in pack:
		deck.append(card)
	
	deck.shuffle()
	deck_changed.emit()
	
	return pack

func _generate_pack() -> Array[Dictionary]:
	var pack: Array[Dictionary] = []
	
	# Get available forms (unlocked species + unlocked form + not submitted)
	var available: Array[Dictionary] = []  # [{mid, form}, ...]
	for mid in unlocked_species:
		if mid not in unlocked_forms:
			continue
		var unlocked_form = unlocked_forms[mid]
		var submitted = submitted_forms.get(mid, [])
		if unlocked_form not in submitted:
			available.append({mid = mid, form = unlocked_form})
	
	if available.is_empty():
		return pack
	
	for i in range(PACK_SIZE):
		var choice = available[randi() % available.size()]
		var rank: int
		
		# Pity system for last slot only
		if i == 4:  # Slot 5: 90% ★★, 10% ★★★
			rank = 2 if randf() < 0.90 else 3
		else:
			rank = _roll_pack_rank()
		
		rank = clampi(rank, 1, MAX_NORMAL_RANK)
		var is_foil = _roll_foil()
		pack.append(CardFactory.create_card(choice.mid, choice.form, rank, is_foil))
	
	return pack

func _roll_pack_rank() -> int:
	## Roll a rank weighted toward lower values (1-4 only, no MAX from packs)
	var roll = randf()
	if roll < 0.90:
		return 1  # ★ - 90%
	elif roll < 0.99:
		return 2  # ★★ - 9%
	else:
		return 3  # ★★★ - 1%

# ===== SPECIES & COLLECTION =====

func is_species_unlocked(mid: int) -> bool:
	return mid in unlocked_species

func get_unlocked_species_count() -> int:
	return unlocked_species.size()

func is_species_complete(mid: int) -> bool:
	## Returns true if all forms of this species have been submitted
	var species = MonsterRegistry.get_species(mid)
	if not species:
		return false
	var form_count = species.get_form_count()
	var submitted = submitted_forms.get(mid, [])
	for form in range(1, form_count + 1):
		if form not in submitted:
			return false
	return true

func _get_next_species_to_unlock() -> int:
	## Find the lowest MID not yet in unlocked_species
	var all_mids = MonsterRegistry.get_all_mids()
	for mid in all_mids:
		if mid not in unlocked_species:
			return mid
	return -1  # All species unlocked

func get_last_unlocked_species_card() -> Dictionary:
	## Get and clear the last unlocked species card (for UI to display)
	var card = _last_unlocked_species_card
	_last_unlocked_species_card = {}
	return card

# ===== FORM TRACKING =====

func is_form_unlocked(mid: int, form: int) -> bool:
	return unlocked_forms.get(mid, 0) >= form

func is_form_submitted(mid: int, form: int) -> bool:
	return form in submitted_forms.get(mid, [])

func get_unlocked_form(mid: int) -> int:
	return unlocked_forms.get(mid, 1)

func get_submitted_form_count() -> int:
	var total = 0
	for mid in submitted_forms.keys():
		total += submitted_forms[mid].size()
	return total

# ===== SUBMISSION =====

func set_submit_slot(card: Dictionary) -> void:
	submit_slot = card
	collection_changed.emit()

func get_submit_slot() -> Dictionary:
	return submit_slot

func clear_submit_slot() -> Dictionary:
	var card = submit_slot
	submit_slot = {}
	collection_changed.emit()
	return card

func can_submit() -> bool:
	if not CardFactory.is_valid_card(submit_slot):
		return false
	if not submit_slot.is_max:
		return false
	# Form not already submitted
	var mid = submit_slot.mid
	var form = submit_slot.form
	return not is_form_submitted(mid, form)

func get_submit_warning() -> String:
	if not CardFactory.is_valid_card(submit_slot):
		return ""
	var card_name = CardFactory.get_card_name(submit_slot)
	return "Submitting will remove all %s cards from your game. This cannot be undone!" % card_name

func confirm_submission() -> bool:
	if not can_submit():
		return false
	
	var mid = submit_slot.mid
	var form = submit_slot.form
	var is_final = CardFactory.is_final_form(submit_slot)
	
	# Mark form as submitted
	if mid not in submitted_forms:
		submitted_forms[mid] = []
	submitted_forms[mid].append(form)
	
	# Remove all cards of this form from game
	_remove_form_from_game(mid, form)
	
	# Clear submit slot
	submit_slot = {}
	
	# Clear any previous unlock tracking
	_last_unlocked_species_card = {}
	
	# Handle unlocks based on whether this was a final form
	if not is_final:
		# Unlock next form of same species
		var next_form = form + 1
		unlocked_forms[mid] = next_form
		var unlocked_card = CardFactory.create_card(mid, next_form, 1, false)
		deck.append(unlocked_card)
		deck.shuffle()
		deck_changed.emit()
		
		form_unlocked.emit(mid, next_form, unlocked_card)
	else:
		# Final form submitted - check if we should unlock a new species
		var next_species = _get_next_species_to_unlock()
		if next_species > 0:
			# Unlock the new species
			unlocked_species.append(next_species)
			unlocked_forms[next_species] = 1
			
			# Create starter card for new species
			var starter_card = CardFactory.create_card(next_species, 1, 1, false)
			deck.append(starter_card)
			deck.shuffle()
			deck_changed.emit()
			
			# Store for UI to retrieve
			_last_unlocked_species_card = starter_card
			
			species_unlocked.emit(next_species, starter_card)
	
	collection_changed.emit()
	
	# Check win condition - all forms across all species submitted
	if get_submitted_form_count() >= MonsterRegistry.get_total_form_count():
		game_won.emit()
	
	return true

func _remove_form_from_game(mid: int, form: int) -> void:
	## Remove all cards of specific mid+form from deck, discard, hand
	deck = deck.filter(func(c): return c.get("mid", -1) != mid or c.get("form", -1) != form)
	discard_pile = discard_pile.filter(func(c): return c.get("mid", -1) != mid or c.get("form", -1) != form)
	for i in range(hand.size()):
		var card = hand[i]
		if card.get("mid", -1) == mid and card.get("form", -1) == form:
			hand[i] = {}
	deck_changed.emit()
	discard_changed.emit()
	hand_changed.emit()

# ===== UPGRADES =====
func get_upgrade_level(type: UpgradeType) -> int:
	return upgrade_levels.get(type, 0)

func get_upgrade_cost(type: UpgradeType) -> int:
	var level = get_upgrade_level(type)
	
	# Draw Speed caps at level 4
	if type == UpgradeType.DRAW_SPEED and level >= 4:
		return -1
	# Foil Chance caps at level 5
	if type == UpgradeType.FOIL_CHANCE and level >= 5:
		return -1
	# Foil Bonus caps at level 4
	if type == UpgradeType.FOIL_BONUS and level >= 4:
		return -1
	
	# All upgrades: 100 base × 10 per level
	return int(100 * pow(10, level))

func can_buy_upgrade(type: UpgradeType) -> bool:
	var cost = get_upgrade_cost(type)
	if cost < 0:
		return false
	return points >= cost

func buy_upgrade(type: UpgradeType) -> bool:
	var cost = get_upgrade_cost(type)
	if cost < 0 or not spend_points(cost):
		return false
	
	upgrade_levels[type] = get_upgrade_level(type) + 1
	return true

func get_upgrade_name(type: UpgradeType) -> String:
	match type:
		UpgradeType.POINTS_MULT: return "Points x2"
		UpgradeType.DRAW_SPEED: return "Draw Speed"
		UpgradeType.PACK_DISCOUNT: return "Pack Discount"
		UpgradeType.COLLECTION_MULT: return "Collection x2"
		UpgradeType.FOIL_CHANCE: return "Foil Chance"
		UpgradeType.FOIL_BONUS: return "Foil Bonus"
	return "Unknown"

func get_upgrade_description(type: UpgradeType) -> String:
	var level = get_upgrade_level(type)
	match type:
		UpgradeType.POINTS_MULT:
			var mult = int(pow(2, level))
			var next_mult = int(pow(2, level + 1))
			return "%dx -> %dx" % [mult, next_mult]
		UpgradeType.DRAW_SPEED:
			var speeds = [10.0, 5.0, 2.5, 1.25, 0.5]
			var current = speeds[mini(level, 4)]
			if level >= 4:
				return "%.1fs (MAX)" % current
			var next = speeds[mini(level + 1, 4)]
			return "%.1fs -> %.1fs" % [current, next]
		UpgradeType.PACK_DISCOUNT:
			var discount = int(pow(2, level))
			var next = int(pow(2, level + 1))
			return "1/%d -> 1/%d cost" % [discount, next]
		UpgradeType.COLLECTION_MULT:
			var mult = int(pow(2, level))
			var next_mult = int(pow(2, level + 1))
			return "%dx -> %dx" % [mult, next_mult]
		UpgradeType.FOIL_CHANCE:
			var chance = level * 5
			if level >= 5:
				return "%d%% (MAX)" % chance
			return "%d%% -> %d%%" % [chance, chance + 5]
		UpgradeType.FOIL_BONUS:
			var mult = 2 + level
			if level >= 4:
				return "%dx (MAX)" % mult
			return "%dx -> %dx" % [mult, mult + 1]
	return ""

# ===== SAVE/LOAD =====
func save_game() -> void:
	var config = ConfigFile.new()
	config.set_value("save", "version", SAVE_VERSION)
	config.set_value("save", "points", points)
	config.set_value("save", "deck", deck)
	config.set_value("save", "discard_pile", discard_pile)
	config.set_value("save", "hand", hand)
	config.set_value("save", "upgrade_levels", upgrade_levels)
	config.set_value("save", "unlocked_species", unlocked_species)
	config.set_value("save", "unlocked_forms", unlocked_forms)
	config.set_value("save", "submitted_forms", submitted_forms)
	config.set_value("save", "packs_purchased", packs_purchased)
	config.save(SAVE_PATH)

func load_game() -> bool:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	
	var version = config.get_value("save", "version", 0)
	if version != SAVE_VERSION:
		return false
	
	points = config.get_value("save", "points", 0)
	deck = config.get_value("save", "deck", [])
	discard_pile = config.get_value("save", "discard_pile", [])
	hand = config.get_value("save", "hand", [])
	upgrade_levels = config.get_value("save", "upgrade_levels", {})
	unlocked_species = config.get_value("save", "unlocked_species", [])
	unlocked_forms = config.get_value("save", "unlocked_forms", {})
	submitted_forms = config.get_value("save", "submitted_forms", {})
	packs_purchased = config.get_value("save", "packs_purchased", 0)
	
	# Ensure hand has correct size
	var target_size = get_current_hand_size()
	while hand.size() < target_size:
		hand.append({})
	
	points_changed.emit(points)
	deck_changed.emit()
	discard_changed.emit()
	hand_changed.emit()
	collection_changed.emit()
	
	return true

func reset_game() -> void:
	var dir = DirAccess.open("user://")
	if dir:
		dir.remove(SAVE_PATH.get_file())
	_init_upgrades()
	_init_new_game()

# ===== SOFTLOCK PREVENTION =====
func check_softlock() -> void:
	var total_cards = deck.size() + discard_pile.size()
	for card in hand:
		if CardFactory.is_valid_card(card):
			total_cards += 1
	
	if total_cards == 0 and not can_buy_pack():
		var pack = _generate_pack()
		for card in pack:
			deck.append(card)
		deck.shuffle()
		deck_changed.emit()
