# scripts/card_display.gd
class_name CardDisplay
extends Panel

## Visual representation of a card - used by CardFactory

@onready var background: ColorRect = $Background
@onready var rank_texture: TextureRect = $RankTexture
@onready var tier_frame: TextureRect = $TierFrame
@onready var vbox: VBoxContainer = $VBox
@onready var tier_label: Label = $VBox/TierLabel
@onready var rank_label: Label = $VBox/RankLabel
@onready var output_label: Label = $VBox/OutputLabel
@onready var card_back_content: CenterContainer = $CardBackContent
@onready var card_back_symbol: Label = $CardBackContent/Symbol

var card_data: Dictionary = {}
var is_card_back: bool = false

func setup(card: Dictionary, size: Vector2) -> void:
	card_data = card
	is_card_back = false
	custom_minimum_size = size
	
	if is_node_ready():
		_update_display()
	else:
		ready.connect(_update_display, CONNECT_ONE_SHOT)

func setup_card_back(size: Vector2) -> void:
	card_data = {}
	is_card_back = true
	custom_minimum_size = size
	
	if is_node_ready():
		_update_display()
	else:
		ready.connect(_update_display, CONNECT_ONE_SHOT)

func _update_display() -> void:
	if is_card_back:
		_show_card_back()
	elif card_data.is_empty():
		_show_empty()
	else:
		_show_card_front()

func _show_card_front() -> void:
	var tier = card_data.get("tier", 1)
	var rank = card_data.get("rank", 1)
	
	card_back_content.visible = false
	vbox.visible = true
	
	# Update labels
	tier_label.text = "Tier %s" % CardFactory.get_tier_numeral(tier)
	rank_label.text = "Rank %d" % rank
	output_label.text = "+%d/s" % CardFactory.get_card_points_value(card_data)
	
	# Apply visuals based on mode
	var visuals = CardFactory.visuals
	
	# Check for rank texture
	var rank_tex = visuals.get_rank_background(rank)
	if rank_tex and visuals.should_use_textures():
		rank_texture.texture = rank_tex
		rank_texture.visible = true
		background.visible = false
	else:
		rank_texture.visible = false
		background.visible = true
		background.color = visuals.get_card_color(tier, rank)
	
	# Check for tier frame
	var frame_tex = visuals.get_tier_frame(tier)
	if frame_tex and visuals.should_use_textures():
		tier_frame.texture = frame_tex
		tier_frame.visible = true
	else:
		tier_frame.visible = false
	
	# Apply shader if present
	var shader = visuals.get_tier_effect_shader(tier)
	if shader and visuals.should_use_shader():
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tier", tier)
		mat.set_shader_parameter("rank", rank)
		self.material = mat
	else:
		self.material = null

func _show_card_back() -> void:
	vbox.visible = false
	rank_texture.visible = false
	tier_frame.visible = false
	
	var visuals = CardFactory.visuals
	
	if visuals.card_back_texture:
		# Use texture
		rank_texture.texture = visuals.card_back_texture
		rank_texture.visible = true
		background.visible = false
		card_back_content.visible = false
	else:
		# Use procedural
		background.visible = true
		background.color = visuals.card_back_color
		card_back_content.visible = true
		card_back_symbol.text = visuals.card_back_symbol
		card_back_symbol.add_theme_color_override("font_color", visuals.card_back_symbol_color)

func _show_empty() -> void:
	vbox.visible = false
	rank_texture.visible = false
	tier_frame.visible = false
	card_back_content.visible = false
	background.visible = true
	background.color = Color(0.2, 0.2, 0.25, 0.5)
