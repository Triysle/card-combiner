# scripts/points_panel.gd
extends PanelContainer

## Points display panel - shows current points and generation rate

@onready var value_label: Label = %Value
@onready var rate_label: Label = %Rate

func _ready() -> void:
	GameState.points_changed.connect(_update_display)
	GameState.tick.connect(_update_display)
	_update_display()

func _update_display(_value: int = 0) -> void:
	value_label.text = _format_number(GameState.points)
	var rate = GameState.calculate_points_per_tick()
	rate_label.text = "+%s/s" % _format_number(rate)

func _format_number(value: int) -> String:
	if value >= 1000000000:
		return "%.2fB" % (value / 1000000000.0)
	elif value >= 1000000:
		return "%.2fM" % (value / 1000000.0)
	elif value >= 10000:
		return "%.1fK" % (value / 1000.0)
	else:
		return "%d" % value
