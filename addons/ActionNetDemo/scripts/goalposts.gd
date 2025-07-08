# All goalpost collision boundaries consolidated into one file
# These are invisible physics-only objects that match the visual ColorRect goal posts

# Red team goal posts
class RedGoalBack extends ActionNetPhysObject2D:
	func _init():
		super._init(Physics.vec2(5, 360))  # Left goal back wall center point
		MASS = 0                           # Static object (immovable)
		RESTITUTION = 0                   # Bounce factor
		auto_spawn = true                  # ActionNet creates automatically
		shape_type = Physics.ShapeType.RECTANGLE
	func _ready():
		update_scale(Vector2(10.0/512, 150.0/512))  # Thin vertical wall
		update_visual()

class RedGoalTop extends ActionNetPhysObject2D:
	func _init():
		super._init(Physics.vec2(30, 285))
		MASS = 0
		RESTITUTION = 0
		auto_spawn = true
		shape_type = Physics.ShapeType.RECTANGLE
	func _ready():
		update_scale(Vector2(60.0/512, 10.0/512))  # Thin horizontal beam
		update_visual()

class RedGoalBottom extends ActionNetPhysObject2D:
	func _init():
		super._init(Physics.vec2(30, 435))
		MASS = 0
		RESTITUTION = 0
		auto_spawn = true
		shape_type = Physics.ShapeType.RECTANGLE
	func _ready():
		update_scale(Vector2(60.0/512, 10.0/512))  # Thin horizontal beam
		update_visual()

# Blue team goal posts
class BlueGoalBack extends ActionNetPhysObject2D:
	func _init():
		super._init(Physics.vec2(1275, 360))  # Right goal back wall center point
		MASS = 0
		RESTITUTION = 0
		auto_spawn = true
		shape_type = Physics.ShapeType.RECTANGLE
	func _ready():
		update_scale(Vector2(10.0/512, 150.0/512))  # Thin vertical wall
		update_visual()

class BlueGoalTop extends ActionNetPhysObject2D:
	func _init():
		super._init(Physics.vec2(1250, 285))
		MASS = 0
		RESTITUTION = 0
		auto_spawn = true
		shape_type = Physics.ShapeType.RECTANGLE
	func _ready():
		update_scale(Vector2(60.0/512, 10.0/512))  # Thin horizontal beam
		update_visual()

class BlueGoalBottom extends ActionNetPhysObject2D:
	func _init():
		super._init(Physics.vec2(1250, 435))
		MASS = 0
		RESTITUTION = 0
		auto_spawn = true
		shape_type = Physics.ShapeType.RECTANGLE
	func _ready():
		update_scale(Vector2(60.0/512, 10.0/512))  # Thin horizontal beam
		update_visual()
