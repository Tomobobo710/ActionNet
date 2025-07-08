# res://addons/ActionNetDemo/scripts/box_deterministic.gd
extends ActionNetPhysObject2D

class_name Box

const BOX_MASS = 0
const BOX_RESTITUTION = 10

func _init():
	super._init()
	# Position will be set when instantiating
	sprite_texture = load("res://addons/ActionNetDemo/sprites/rectangle_texture.png")
	MASS = BOX_MASS
	RESTITUTION = BOX_RESTITUTION
	auto_spawn = false  # Disabled auto-spawn - no floating box
	shape_type = Physics.ShapeType.RECTANGLE
	# Initialize shape_data with width and height for rectangle
	shape_data = {
		"width": BASE_SIZE * 2,
		"height": BASE_SIZE
	}

func _ready():
	if sprite_texture:
		sprite = Sprite2D.new()
		sprite.texture = sprite_texture
		add_child(sprite)
		update_scale(Vector2(0.1, 0.2))
	update_shape_data()
	update_visual()
