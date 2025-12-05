# scripts/resources/monster_form.gd
class_name MonsterForm
extends Resource

## A single form/evolution stage of a monster species

## Form index within species (1-indexed: 1 = base form, 2 = first evolution, etc.)
@export var form_index: int = 1

## Display name for this specific form (optional, falls back to species name)
@export var display_name: String = ""

## Sprite texture for this form
@export var sprite: Texture2D

## Whether this form can evolve further (false = final form)
@export var can_evolve: bool = false

## Get the point multiplier for this form (form²)
func get_point_multiplier() -> int:
	return form_index * form_index
