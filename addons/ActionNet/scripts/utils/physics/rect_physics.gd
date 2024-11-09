# res://addons/ActionNet/scripts/utils/physics/rect_physics.gd
extends RefCounted

class_name RectPhysics

const SCALE = Physics.SCALE

static func update_position(position: Vector2i, velocity: Vector2i, width: int, height: int) -> Vector2i:
	var new_position = position + velocity
	var half_width = width / 2
	var half_height = height / 2
	new_position.x = clamp(new_position.x, half_width, Physics.WORLD_WIDTH - half_width)
	new_position.y = clamp(new_position.y, half_height, Physics.WORLD_HEIGHT - half_height)
	return new_position

static func check_collision_rect_rect(pos1: Vector2i, width1: int, height1: int, pos2: Vector2i, width2: int, height2: int) -> bool:
	var half_width1 = width1 / 2
	var half_height1 = height1 / 2
	var half_width2 = width2 / 2
	var half_height2 = height2 / 2
	
	return !(pos1.x + half_width1 < pos2.x - half_width2 or 
			 pos1.x - half_width1 > pos2.x + half_width2 or
			 pos1.y + half_height1 < pos2.y - half_height2 or
			 pos1.y - half_height1 > pos2.y + half_height2)

static func check_collision_rect_circle(rect_pos: Vector2i, width: int, height: int, circle_pos: Vector2i, radius: int) -> bool:
	var half_width = width / 2
	var half_height = height / 2
	
	# Find the closest point on the rectangle to the circle's center
	var closest_x = clamp(circle_pos.x, rect_pos.x - half_width, rect_pos.x + half_width)
	var closest_y = clamp(circle_pos.y, rect_pos.y - half_height, rect_pos.y + half_height)
	
	# Calculate distance squared between closest point and circle center
	var delta_x = circle_pos.x - closest_x
	var delta_y = circle_pos.y - closest_y
	var distance_squared = delta_x * delta_x + delta_y * delta_y
	
	return distance_squared < radius * radius

static func resolve_collision_rect_rect(pos1: Vector2i, vel1: Vector2i, mass1: int, width1: int, height1: int, restitution1: int,
									  pos2: Vector2i, vel2: Vector2i, mass2: int, width2: int, height2: int, restitution2: int,
									  angular_vel1: int, angular_mass1: int, angular_vel2: int, angular_mass2: int) -> Dictionary:
	var half_width1 = width1 / 2
	var half_height1 = height1 / 2
	var half_width2 = width2 / 2
	var half_height2 = height2 / 2
	
	# Calculate overlap on each axis
	var overlap_x = (half_width1 + half_width2) - abs(pos2.x - pos1.x)
	var overlap_y = (half_height1 + half_height2) - abs(pos2.y - pos1.y)
	
	var normal = Vector2i(0, 0)
	if overlap_x < overlap_y:
		normal.x = -SCALE if pos1.x < pos2.x else SCALE
	else:
		normal.y = -SCALE if pos1.y < pos2.y else SCALE
	
	var relative_velocity = vel2 - vel1
	var normal_velocity = (normal.x * relative_velocity.x + normal.y * relative_velocity.y) / SCALE
	
	if normal_velocity > 0:
		return {"vel1": vel1, "vel2": vel2, "pos1": pos1, "pos2": pos2,
				"angular_vel1": angular_vel1, "angular_vel2": angular_vel2}
	
	var max_restitution = max(restitution1, restitution2)
	var new_vel1 = vel1
	var new_vel2 = vel2
	var new_angular_vel1 = angular_vel1
	var new_angular_vel2 = angular_vel2
	
	# Handle collision response similar to circle collision but with rectangular considerations
	if Physics.is_static(mass1) and Physics.is_static(mass2):
		pass
	elif Physics.is_static(mass1):
		new_vel2 = Vector2i(
			vel2.x - (2 * normal_velocity * normal.x),
			vel2.y - (2 * normal_velocity * normal.y)
		)
		if angular_mass2 > 0:
			new_angular_vel2 += Physics.calculate_angular_velocity(normal, new_vel2, min(width2, height2) / 2)
	elif Physics.is_static(mass2):
		new_vel1 = Vector2i(
			vel1.x + (2 * normal_velocity * normal.x),
			vel1.y + (2 * normal_velocity * normal.y)
		)
		if angular_mass1 > 0:
			new_angular_vel1 += Physics.calculate_angular_velocity(normal, new_vel1, min(width1, height1) / 2)
	else:
		var impulse = (-(SCALE + max_restitution) * normal_velocity * SCALE) / (SCALE * SCALE / mass1 + SCALE * SCALE / mass2)
		var impulse_vector = Vector2i(
			(normal.x * impulse) / SCALE,
			(normal.y * impulse) / SCALE
		)
		
		new_vel1 = Vector2i(
			vel1.x - (impulse_vector.x * SCALE / mass1),
			vel1.y - (impulse_vector.y * SCALE / mass1)
		)
		new_vel2 = Vector2i(
			vel2.x + (impulse_vector.x * SCALE / mass2),
			vel2.y + (impulse_vector.y * SCALE / mass2)
		)
		
		if angular_mass1 > 0:
			new_angular_vel1 += Physics.calculate_angular_velocity(normal, new_vel1, min(width1, height1) / 2)
		if angular_mass2 > 0:
			new_angular_vel2 += Physics.calculate_angular_velocity(normal, new_vel2, min(width2, height2) / 2)
	
	# Apply individual restitution
	new_vel1 = Vector2i(
		vel1.x + ((new_vel1.x - vel1.x) * restitution1) / SCALE,
		vel1.y + ((new_vel1.y - vel1.y) * restitution1) / SCALE
	)
	new_vel2 = Vector2i(
		vel2.x + ((new_vel2.x - vel2.x) * restitution2) / SCALE,
		vel2.y + ((new_vel2.y - vel2.y) * restitution2) / SCALE
	)
	
	# Resolve overlap
	var separation = Vector2i()
	if overlap_x < overlap_y:
		separation.x = (overlap_x * normal.x) / SCALE
	else:
		separation.y = (overlap_y * normal.y) / SCALE
	
	var new_pos1 = pos1
	var new_pos2 = pos2
	
	if Physics.is_static(mass1) and Physics.is_static(mass2):
		pass
	elif Physics.is_static(mass1):
		new_pos2 += separation * 2
	elif Physics.is_static(mass2):
		new_pos1 -= separation * 2
	else:
		new_pos1 -= separation
		new_pos2 += separation
	
	return {"vel1": new_vel1, "vel2": new_vel2, "pos1": new_pos1, "pos2": new_pos2,
			"angular_vel1": new_angular_vel1, "angular_vel2": new_angular_vel2}

static func resolve_collision_rect_circle(rect_pos: Vector2i, rect_vel: Vector2i, rect_mass: int, width: int, height: int, rect_restitution: int,
										circle_pos: Vector2i, circle_vel: Vector2i, circle_mass: int, radius: int, circle_restitution: int,
										rect_angular_vel: int, rect_angular_mass: int, circle_angular_vel: int, circle_angular_mass: int) -> Dictionary:
	var half_width = width / 2
	var half_height = height / 2
	
	# Find closest point on rectangle to circle center
	var closest_x = clamp(circle_pos.x, rect_pos.x - half_width, rect_pos.x + half_width)
	var closest_y = clamp(circle_pos.y, rect_pos.y - half_height, rect_pos.y + half_height)
	
	var delta_pos = Vector2i(circle_pos.x - closest_x, circle_pos.y - closest_y)
	var distance_squared = delta_pos.x * delta_pos.x + delta_pos.y * delta_pos.y
	
	if distance_squared == 0:
		# Handle the case where the circle center is exactly on the rectangle edge
		delta_pos = Vector2i(1 * SCALE, 0)
		distance_squared = SCALE * SCALE
	
	var distance = Physics.fixed_point_sqrt(distance_squared)
	var normal = Vector2i(
		(delta_pos.x * SCALE) / distance,
		(delta_pos.y * SCALE) / distance
	)
	
	var relative_velocity = circle_vel - rect_vel
	var normal_velocity = (normal.x * relative_velocity.x + normal.y * relative_velocity.y) / SCALE
	
	if normal_velocity > 0:
		return {"vel1": rect_vel, "vel2": circle_vel, "pos1": rect_pos, "pos2": circle_pos,
				"angular_vel1": rect_angular_vel, "angular_vel2": circle_angular_vel}
	
	var max_restitution = max(rect_restitution, circle_restitution)
	var new_rect_vel = rect_vel
	var new_circle_vel = circle_vel
	var new_rect_angular_vel = rect_angular_vel
	var new_circle_angular_vel = circle_angular_vel
	
	# Collision response similar to circle-circle but adapted for rect-circle
	if Physics.is_static(rect_mass) and Physics.is_static(circle_mass):
		pass
	elif Physics.is_static(rect_mass):
		new_circle_vel = Vector2i(
			circle_vel.x - (2 * normal_velocity * normal.x),
			circle_vel.y - (2 * normal_velocity * normal.y)
		)
		if circle_angular_mass > 0:
			new_circle_angular_vel += Physics.calculate_angular_velocity(normal, new_circle_vel, radius)
	elif Physics.is_static(circle_mass):
		new_rect_vel = Vector2i(
			rect_vel.x + (2 * normal_velocity * normal.x),
			rect_vel.y + (2 * normal_velocity * normal.y)
		)
		if rect_angular_mass > 0:
			new_rect_angular_vel += Physics.calculate_angular_velocity(normal, new_rect_vel, min(width, height) / 2)
	else:
		var impulse = (-(SCALE + max_restitution) * normal_velocity * SCALE) / (SCALE * SCALE / rect_mass + SCALE * SCALE / circle_mass)
		var impulse_vector = Vector2i(
			(normal.x * impulse) / SCALE,
			(normal.y * impulse) / SCALE
		)
		
		new_rect_vel = Vector2i(
			rect_vel.x - (impulse_vector.x * SCALE / rect_mass),
			rect_vel.y - (impulse_vector.y * SCALE / rect_mass)
		)
		new_circle_vel = Vector2i(
			circle_vel.x + (impulse_vector.x * SCALE / circle_mass),
			circle_vel.y + (impulse_vector.y * SCALE / circle_mass)
		)
		
		if rect_angular_mass > 0:
			new_rect_angular_vel += Physics.calculate_angular_velocity(normal, new_rect_vel, min(width, height) / 2)
		if circle_angular_mass > 0:
			new_circle_angular_vel += Physics.calculate_angular_velocity(normal, new_circle_vel, radius)
	
	# Apply individual restitution
	new_rect_vel = Vector2i(
		rect_vel.x + ((new_rect_vel.x - rect_vel.x) * rect_restitution) / SCALE,
		rect_vel.y + ((new_rect_vel.y - rect_vel.y) * rect_restitution) / SCALE
	)
	new_circle_vel = Vector2i(
		circle_vel.x + ((new_circle_vel.x - circle_vel.x) * circle_restitution) / SCALE,
		circle_vel.y + ((new_circle_vel.y - circle_vel.y) * circle_restitution) / SCALE
	)
	
	# Handle overlap
	var overlap = radius - distance
	if overlap > 0:
		var separation = Vector2i(
			(normal.x * overlap) / SCALE,
			(normal.y * overlap) / SCALE
		)
		
		var new_rect_pos = rect_pos
		var new_circle_pos = circle_pos
		
		if Physics.is_static(rect_mass) and Physics.is_static(circle_mass):
			pass
		elif Physics.is_static(rect_mass):
			new_circle_pos += separation * 2
		elif Physics.is_static(circle_mass):
			new_rect_pos -= separation * 2
		else:
			new_rect_pos -= separation
			new_circle_pos += separation
		
		return {"vel1": new_rect_vel, "vel2": new_circle_vel, "pos1": new_rect_pos, "pos2": new_circle_pos,
				"angular_vel1": new_rect_angular_vel, "angular_vel2": new_circle_angular_vel}
	
	return {"vel1": new_rect_vel, "vel2": new_circle_vel, "pos1": rect_pos, "pos2": circle_pos,
			"angular_vel1": new_rect_angular_vel, "angular_vel2": new_circle_angular_vel}
