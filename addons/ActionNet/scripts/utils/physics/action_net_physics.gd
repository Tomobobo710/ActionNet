# res://addons/ActionNet/scripts/utils/physics/action_net_physics.gd
class_name Physics

const SCALE = 1000
const WORLD_WIDTH = 1280 * SCALE
const WORLD_HEIGHT = 720 * SCALE

enum ShapeType {
	CIRCLE,
	RECTANGLE
}

static func vec2(x: int, y: int) -> Vector2i:
	return Vector2i(x * SCALE, y * SCALE)

static func should_collide(layer1: int, mask1: int, layer2: int, mask2: int) -> bool:
	return (layer1 & mask2) != 0 or (layer2 & mask1) != 0

static func apply_force(velocity: Vector2i, force: Vector2i, mass: int, delta: int) -> Vector2i:
	return velocity + Vector2i(
		(force.x * delta) / (mass * SCALE),
		(force.y * delta) / (mass * SCALE)
	)

static func rotate_vector(vec: Vector2i, angle: int) -> Vector2i:
	var index = (angle % 360) % PhysicsTables.TABLE_SIZE
	if index < 0:
		index += PhysicsTables.TABLE_SIZE

	var sin_theta = PhysicsTables.SIN_TABLE[index]
	var cos_theta = PhysicsTables.COS_TABLE[index]

	return Vector2i(
		(vec.x * cos_theta - vec.y * sin_theta) / SCALE,
		(vec.x * sin_theta + vec.y * cos_theta) / SCALE
	)

static func is_static(mass: int) -> bool:
	return mass <= 0

static func calculate_angular_velocity(normal: Vector2i, velocity: Vector2i, radius: int) -> int:
	var tangent = Vector2i(-normal.y, normal.x)
	var tangential_velocity = (tangent.x * velocity.x + tangent.y * velocity.y) / SCALE
	return (tangential_velocity * SCALE) / radius

static func fixed_point_sqrt(n: int) -> int:
	if n == 0:
		return 0

	# Set initial guess range
	var lo = 0
	var hi = n

	# Binary search
	while lo <= hi:
		var mid = (lo + hi) / 2
		var mid_squared = mid * mid

		if mid_squared == n:
			return mid
		elif mid_squared < n:
			lo = mid + 1
		else:
			hi = mid - 1

	# When we exit the loop, 'hi' is the integer square root
	return hi

static func update_position(position: Vector2i, velocity: Vector2i, shape_type: ShapeType, shape_data: Dictionary) -> Vector2i:
	match shape_type:
		ShapeType.CIRCLE:
			return CirclePhysics.update_position(position, velocity, shape_data["radius"])
		ShapeType.RECTANGLE:
			# To be implemented
			return position
		_:
			return position

static func check_collision(pos1: Vector2i, shape_type1: ShapeType, shape_data1: Dictionary,
						   pos2: Vector2i, shape_type2: ShapeType, shape_data2: Dictionary) -> bool:
	match [shape_type1, shape_type2]:
		[ShapeType.CIRCLE, ShapeType.CIRCLE]:
			return CirclePhysics.check_collision(pos1, shape_data1["radius"], pos2, shape_data2["radius"])
		[ShapeType.RECTANGLE, ShapeType.RECTANGLE]:
			return RectPhysics.check_collision_rect_rect(pos1, shape_data1["width"], shape_data1["height"],
													   pos2, shape_data2["width"], shape_data2["height"])
		[ShapeType.RECTANGLE, ShapeType.CIRCLE]:
			return RectPhysics.check_collision_rect_circle(pos1, shape_data1["width"], shape_data1["height"],
														 pos2, shape_data2["radius"])
		[ShapeType.CIRCLE, ShapeType.RECTANGLE]:
			return RectPhysics.check_collision_rect_circle(pos2, shape_data2["width"], shape_data2["height"],
														 pos1, shape_data1["radius"])
		_:
			return false

static func resolve_collision(pos1: Vector2i, vel1: Vector2i, mass1: int, shape_type1: ShapeType, shape_data1: Dictionary, restitution1: int,
							pos2: Vector2i, vel2: Vector2i, mass2: int, shape_type2: ShapeType, shape_data2: Dictionary, restitution2: int,
							angular_vel1: int, angular_mass1: int, angular_vel2: int, angular_mass2: int) -> Dictionary:
	match [shape_type1, shape_type2]:
		[ShapeType.CIRCLE, ShapeType.CIRCLE]:
			return CirclePhysics.resolve_collision(
				pos1, vel1, mass1, shape_data1["radius"], restitution1,
				pos2, vel2, mass2, shape_data2["radius"], restitution2,
				angular_vel1, angular_mass1, angular_vel2, angular_mass2
			)
		[ShapeType.RECTANGLE, ShapeType.RECTANGLE]:
			return RectPhysics.resolve_collision_rect_rect(
				pos1, vel1, mass1, shape_data1["width"], shape_data1["height"], restitution1,
				pos2, vel2, mass2, shape_data2["width"], shape_data2["height"], restitution2,
				angular_vel1, angular_mass1, angular_vel2, angular_mass2
			)
		[ShapeType.RECTANGLE, ShapeType.CIRCLE]:
			return RectPhysics.resolve_collision_rect_circle(
				pos1, vel1, mass1, shape_data1["width"], shape_data1["height"], restitution1,
				pos2, vel2, mass2, shape_data2["radius"], restitution2,
				angular_vel1, angular_mass1, angular_vel2, angular_mass2
			)
		[ShapeType.CIRCLE, ShapeType.RECTANGLE]:
			var result = RectPhysics.resolve_collision_rect_circle(
				pos2, vel2, mass2, shape_data2["width"], shape_data2["height"], restitution2,
				pos1, vel1, mass1, shape_data1["radius"], restitution1,
				angular_vel2, angular_mass2, angular_vel1, angular_mass1
			)
			# Swap the results since we swapped the order of objects
			return {
				"vel1": result["vel2"],
				"vel2": result["vel1"],
				"pos1": result["pos2"],
				"pos2": result["pos1"],
				"angular_vel1": result["angular_vel2"],
				"angular_vel2": result["angular_vel1"]
			}
		_:
			return {"vel1": vel1, "vel2": vel2, "pos1": pos1, "pos2": pos2,
					"angular_vel1": angular_vel1, "angular_vel2": angular_vel2}
