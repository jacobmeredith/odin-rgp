package main

import rl "vendor:raylib"

rect_min_max :: #force_inline proc(rect: Rect) -> (Vec2, Vec2) {
	return Vec2{rect.x, rect.y}, Vec2{rect.x + rect.width, rect.y + rect.height}
}

circle_vs_rect_response :: #force_inline proc(center: Vec2, radius: f32, rect: Rect) -> Vec2 {
	rect_min, rect_max := rect_min_max(rect)
	closest_point_on_rect := rl.Vector2Clamp(center, rect_min, rect_max)
	direction_to_closest_point := rl.Vector2Normalize(closest_point_on_rect - center)
	contact_point := center + direction_to_closest_point * radius
	penetration_vector := closest_point_on_rect - contact_point

	return center + penetration_vector
}
