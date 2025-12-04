# scripts/milestone_panel.gd
extends VBoxContainer

## Milestone Panel - displays current milestone and accepts card keys

@onready var title_label: Label = $TitleLabel
@onready var tier_label: Label = $TierLabel
@onready var slots_container: HBoxContainer = $SlotsContainer
@onready var reward_label: Label = $RewardLabel
@onready var unlock_button: Button = $UnlockButton

const MILESTONE_SLOT_SCENE = preload("res://scenes/milestone_slot.tscn")

var milestone_slots: Array[MilestoneSlot] = []

func _ready() -> void:
	unlock_button.pressed.connect(_on_unlock_pressed)
	GameState.milestone_changed.connect(_update_display)
	# Note: Panel visibility is controlled by main.gd based on GameState.has_bought_pack
	
	_create_slots()
	_update_display()

func _create_slots() -> void:
	# Clear existing
	for slot in milestone_slots:
		slot.queue_free()
	milestone_slots.clear()
	
	# Create 3 slots
	for i in range(3):
		var slot = MILESTONE_SLOT_SCENE.instantiate() as MilestoneSlot
		slot.slot_index = i
		slot.card_dropped.connect(_on_card_dropped)
		slot.card_removed.connect(_on_card_removed)
		slots_container.add_child(slot)
		milestone_slots.append(slot)

func _update_display() -> void:
	var milestone = GameState.get_current_milestone()
	
	if milestone.is_empty():
		# Game complete
		title_label.text = "COMPLETE!"
		tier_label.text = "You won!"
		reward_label.text = "Congratulations!"
		unlock_button.visible = false
		for slot in milestone_slots:
			slot.visible = false
		return
	
	# Show milestone info
	var type_name = _get_milestone_type_name(milestone.type)
	title_label.text = type_name
	tier_label.text = "Tier %s" % CardFactory.get_tier_numeral(milestone.tier)
	reward_label.text = milestone.reward_text
	
	# Update slots with requirements
	for i in range(milestone_slots.size()):
		var slot = milestone_slots[i]
		slot.visible = true
		
		if i < milestone.required_cards.size():
			slot.set_requirement(milestone.required_cards[i])
			
			# Sync current card from GameState
			var current = GameState.get_milestone_slot(i)
			if not current.is_empty():
				slot.set_card(current)
			else:
				slot.clear_card()
	
	# Update unlock button
	unlock_button.visible = true
	unlock_button.disabled = not GameState.can_complete_milestone()
	unlock_button.text = "UNLOCK" if not unlock_button.disabled else "Need Cards"

func _get_milestone_type_name(type: String) -> String:
	match type:
		"hand_size": return "HAND SIZE"
		"tier_power": return "TIER POWER"
		"upgrade_limit": return "UPGRADE LIMIT"
		"booster_tier": return "BOOSTER TIER"
	return type.to_upper()

func _on_card_dropped(slot: MilestoneSlot, card: Dictionary) -> void:
	# Add to GameState
	GameState.slot_card_in_milestone(card, slot.slot_index)
	slot.set_card(card)
	_update_display()

func _on_card_removed(slot: MilestoneSlot) -> void:
	# This is called when card is dragged out
	GameState.remove_card_from_milestone(slot.slot_index)
	_update_display()

func _on_unlock_pressed() -> void:
	if GameState.complete_milestone():
		_update_display()
