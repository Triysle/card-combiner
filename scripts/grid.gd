class_name Grid
extends CenterContainer

## The hand area - displays slots for cards in hand

signal merge_attempted(source_index: int, target_index: int)
signal move_attempted(source_index: int, target_index: int)
signal discard_requested(slot_index: int)

@onready var grid_container: GridContainer = $GridContainer

var slots: Array[Slot] = []
var _current_hover_slot: Slot = null

const SLOT_SCENE = preload("res://scenes/slot.tscn")

func _ready() -> void:
	_rebuild_grid(GameState.hand_size)
	GameState.hand_changed.connect(_on_hand_changed)
	# Sync initial state
	call_deferred("_sync_from_game_state")

func _on_hand_changed() -> void:
	# Check if we need to rebuild (size changed)
	if GameState.hand_size != slots.size():
		_rebuild_grid(GameState.hand_size)
	else:
		_sync_from_game_state()

func _rebuild_grid(new_size: int) -> void:
	# Clear existing slots
	for slot in slots:
		slot.queue_free()
	slots.clear()
	
	# Set grid columns (max 5 per row)
	grid_container.columns = mini(new_size, 5)
	
	# Create new slots
	for i in new_size:
		var slot = SLOT_SCENE.instantiate() as Slot
		slot.slot_index = i
		slot.merge_attempted.connect(_on_merge_attempted)
		slot.move_attempted.connect(_on_move_attempted)
		slot.hover_started.connect(_on_slot_hover_started)
		slot.discard_requested.connect(_on_discard_requested)
		grid_container.add_child(slot)
		slots.append(slot)
	
	_sync_from_game_state()

func _sync_from_game_state() -> void:
	for i in range(mini(slots.size(), GameState.hand.size())):
		var card_data = GameState.get_hand_slot(i)
		slots[i].set_card(card_data)

func _on_merge_attempted(source_slot: Slot, target_slot: Slot) -> void:
	merge_attempted.emit(source_slot.slot_index, target_slot.slot_index)

func _on_move_attempted(source_slot: Slot, target_slot: Slot) -> void:
	move_attempted.emit(source_slot.slot_index, target_slot.slot_index)

func _on_slot_hover_started(slot: Slot) -> void:
	if _current_hover_slot and _current_hover_slot != slot:
		_current_hover_slot.clear_drop_state()
	_current_hover_slot = slot

func _on_discard_requested(slot: Slot) -> void:
	discard_requested.emit(slot.slot_index)

func clear_all_drop_states() -> void:
	_current_hover_slot = null
	for slot in slots:
		slot.clear_drop_state()

# === Data Access ===

func get_slot(index: int) -> Slot:
	if index < 0 or index >= slots.size():
		return null
	return slots[index]

func get_slot_count() -> int:
	return slots.size()
