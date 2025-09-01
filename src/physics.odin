package main

import "core:math"
import rl "vendor:raylib"

OBB :: struct {
	position:    Vec2,
	size:        Vec2,
	rotation:    f32,
	debug_color: rl.Color,
}

rect_from_obb :: #force_inline proc(obb: OBB) -> Rect {
	return Rect{obb.position.x, obb.position.y, obb.size.x, obb.size.y}
}

rect_min_max :: #force_inline proc(rect: Rect) -> (Vec2, Vec2) {
	return Vec2{rect.x, rect.y}, Vec2{rect.x + rect.width, rect.y + rect.height}
}

// Assumes the centre of the collider is outside the AABB.
// The constraint being:
//     movement_speed * dt <= radius * 0.95
// We will adhere to this constraint and so do not need to create
// a solution for the case where movement_speed is too large.
circle_vs_rect_response :: #force_inline proc(center: Vec2, radius: f32, rect: Rect) -> Vec2 {
	rect_min, rect_max := rect_min_max(rect)

	closest_point_on_rect := rl.Vector2Clamp(center, rect_min, rect_max)

	direction_to_closest_point := rl.Vector2Normalize(closest_point_on_rect - center)

	contact_point := center + direction_to_closest_point * radius

	penetration_vector := closest_point_on_rect - contact_point

	return center + penetration_vector
}
