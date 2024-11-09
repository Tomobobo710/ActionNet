# res://addons/ActionNet/scripts/utils/physics/action_net_physics.gd
extends RefCounted

class_name CirclePhysics

const SCALE = Physics.SCALE

static func update_position(position: Vector2i, velocity: Vector2i, radius: int) -> Vector2i:
	var new_position = position + velocity
	new_position.x = clamp(new_position.x, radius, Physics.WORLD_WIDTH - radius)
	new_position.y = clamp(new_position.y, radius, Physics.WORLD_HEIGHT - radius)
	return new_position

static func check_collision(pos1: Vector2i, radius1: int, pos2: Vector2i, radius2: int) -> bool:
	var delta_pos = pos2 - pos1
	var distance_squared = delta_pos.x * delta_pos.x + delta_pos.y * delta_pos.y
	var sum_radii = radius1 + radius2
	return distance_squared < sum_radii * sum_radii

static func resolve_collision(pos1: Vector2i, vel1: Vector2i, mass1: int, radius1: int, restitution1: int,
							  pos2: Vector2i, vel2: Vector2i, mass2: int, radius2: int, restitution2: int,
							  angular_vel1: int, angular_mass1: int, angular_vel2: int, angular_mass2: int) -> Dictionary:
	var delta_pos = pos2 - pos1
	var distance_squared = delta_pos.x * delta_pos.x + delta_pos.y * delta_pos.y
	var distance = Physics.fixed_point_sqrt(distance_squared)
	
	if distance == 0:
		return {"vel1": vel1, "vel2": vel2, "pos1": pos1, "pos2": pos2 + Vector2i(radius1 + radius2, 0),
				"angular_vel1": angular_vel1, "angular_vel2": angular_vel2}
	
	var normal = Vector2i(
		(delta_pos.x * SCALE) / distance,
		(delta_pos.y * SCALE) / distance
	)
	
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
	
	if Physics.is_static(mass1) and Physics.is_static(mass2):
		# Both objects are static, no velocity change
		pass
	elif Physics.is_static(mass1):
		# Object 1 is static, only object 2 changes velocity
		new_vel2 = Vector2i(
			vel2.x - (2 * normal_velocity * normal.x),
			vel2.y - (2 * normal_velocity * normal.y)
		)
		if angular_mass2 > 0:
			new_angular_vel2 += Physics.calculate_angular_velocity(normal, new_vel2, radius2)
	elif Physics.is_static(mass2):
		# Object 2 is static, only object 1 changes velocity
		new_vel1 = Vector2i(
			vel1.x + (2 * normal_velocity * normal.x),
			vel1.y + (2 * normal_velocity * normal.y)
		)
		if angular_mass1 > 0:
			new_angular_vel1 += Physics.calculate_angular_velocity(normal, new_vel1, radius1)
	else:
		# Neither object is static, use original collision resolution
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
			new_angular_vel1 += Physics.calculate_angular_velocity(normal, new_vel1, radius1)
		if angular_mass2 > 0:
			new_angular_vel2 += Physics.calculate_angular_velocity(normal, new_vel2, radius2)
	
	# Apply individual restitution
	new_vel1 = Vector2i(
		vel1.x + ((new_vel1.x - vel1.x) * restitution1) / SCALE,
		vel1.y + ((new_vel1.y - vel1.y) * restitution1) / SCALE
	)
	new_vel2 = Vector2i(
		vel2.x + ((new_vel2.x - vel2.x) * restitution2) / SCALE,
		vel2.y + ((new_vel2.y - vel2.y) * restitution2) / SCALE
	)
	
	# Handle overlap
	var overlap = radius1 + radius2 - distance
	if overlap > 0:
		var separation = Vector2i(
			(normal.x * overlap) / SCALE,
			(normal.y * overlap) / SCALE
		)
		var new_pos1 = pos1
		var new_pos2 = pos2
		
		if Physics.is_static(mass1) and Physics.is_static(mass2):
			# Both objects are static, don't move either
			pass
		elif Physics.is_static(mass1):
			# Only move object 2
			new_pos2 += separation * 2
		elif Physics.is_static(mass2):
			# Only move object 1
			new_pos1 -= separation * 2
		else:
			# Move both objects
			new_pos1 -= separation
			new_pos2 += separation
		
		return {"vel1": new_vel1, "vel2": new_vel2, "pos1": new_pos1, "pos2": new_pos2,
				"angular_vel1": new_angular_vel1, "angular_vel2": new_angular_vel2}
	
	return {"vel1": new_vel1, "vel2": new_vel2, "pos1": pos1, "pos2": pos2,
			"angular_vel1": new_angular_vel1, "angular_vel2": new_angular_vel2}
