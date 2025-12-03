extends VBoxContainer

## HUD - displays points, rate, and event log

@onready var points_value: Label = $PointsPanel/VBox/Value
@onready var points_rate: Label = $PointsPanel/VBox/Rate
@onready var event_log: RichTextLabel = $EventLogPanel/VBox/EventLog

const MAX_LOG_LINES = 50

func _ready() -> void:
	GameState.points_changed.connect(_on_points_changed)
	GameState.tick.connect(_on_tick)
	GameState.event_logged.connect(_on_event_logged)
	_update_all()

func _update_all() -> void:
	_on_points_changed(GameState.points)
	_update_point_rate()

func _on_points_changed(value: int) -> void:
	points_value.text = _format_number(value)

func _format_number(value: int) -> String:
	if value >= 1000000000:
		return "%.2fB" % (value / 1000000000.0)
	elif value >= 1000000:
		return "%.2fM" % (value / 1000000.0)
	elif value >= 10000:
		return "%.1fK" % (value / 1000.0)
	else:
		return "%d" % value

func _on_tick() -> void:
	_update_point_rate()

func _update_point_rate() -> void:
	var rate = GameState.calculate_points_per_tick()
	points_rate.text = "+%s/s" % _format_number(rate)

func _on_event_logged(message: String) -> void:
	# Prepend new message at the top
	var current_text = event_log.get_parsed_text()
	event_log.clear()
	event_log.append_text(message + "\n" + current_text)
	
	# Trim old lines if too many
	var line_count = event_log.get_line_count()
	if line_count > MAX_LOG_LINES:
		var text = event_log.get_parsed_text()
		var lines = text.split("\n")
		var trimmed = "\n".join(lines.slice(0, MAX_LOG_LINES))
		event_log.clear()
		event_log.append_text(trimmed)
	
	# Scroll to top to show newest
	event_log.scroll_to_line(0)
