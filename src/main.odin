package main

import "core:fmt"
import "core:math"

import "core:container/queue"
import rl "vendor:raylib"

Vec2 :: [2]f32
Vec3 :: [3]f32
Rect :: rl.Rectangle
Mat3 :: matrix[3, 3]f32

Game_State :: struct {
	window_width:           f32,
	window_height:          f32,
	time:                   struct {
		delta:   f32,
		frame:   int,
		session: f64,
		fps:     int,
	},
	input:                  struct {
		up, down, left, right: bool,
	},
	entity:                 struct {
		entities:              [dynamic]Entity,
		generations:           [dynamic]int,
		unused_entity_handles: [dynamic]Entity_Handle,
		active_entities:       [dynamic]int,
	},
	player_handle:          Entity_Handle,
	event:                  struct {
		queue:       queue.Queue(Event),
		subscribers: map[Event_Type][dynamic]Event_Callback_Proc,
	},
	assets:                 struct {
		textures: map[Texture_Key]rl.Texture,
	},
	animations:             struct {
		sprite_animation_definitions: [Animation_Type]Sprite_Animation_Definition,
	},
	physics:                struct {
		static_geometry:   [dynamic]OBB,
		last_collided_box: OBB,
	},
	camera:                 rl.Camera2D,
	current_rotation_index: int,
}

gs: ^Game_State

main :: proc() {
	gs = new(Game_State)

	gs.window_width = 1280
	gs.window_height = 720

	rl.InitWindow(i32(gs.window_width), i32(gs.window_height), "PVG RPG")
	rl.SetTargetFPS(60)

	// Let's just move the init below raylib anyway.
	entity_init()
	assets_init()
	animations_init()

	gs.player_handle = entity_create()
	player := entity_get(gs.player_handle)
	player.movement_speed = 500
	player.collider_radius = 16

	center := Vec2{gs.window_width, gs.window_height} / 2
	player.position = center

	append(
		&gs.physics.static_geometry,
		OBB{Vec2{center.x + 16, center.y + 16}, Vec2{100, 30}, math.to_radians_f32(0.0), rl.BLUE},
	)
	append(
		&gs.physics.static_geometry,
		OBB{Vec2{center.x - 32, center.y / 4}, Vec2{3, 130}, math.to_radians_f32(30.0), 0},
	)
	append(
		&gs.physics.static_geometry,
		OBB{Vec2{center.x - 128, center.y * 0.75}, Vec2{50, 50}, math.to_radians_f32(62.0), 0},
	)
	append(
		&gs.physics.static_geometry,
		OBB {
			Vec2{center.x - 32, center.y * 0.95},
			Vec2{12, 180},
			math.to_radians_f32(30.0),
			rl.RED,
		},
	)

	// Create corners to test
	{
		thickness := f32(35)
		border := f32(35)
		offset := border + thickness / 2
		width := gs.window_width - border * 2
		height := gs.window_height - border * 2

		append(
			&gs.physics.static_geometry,
			OBB{Vec2{center.x, offset}, Vec2{width, thickness}, 0, 0},
		)
		append(
			&gs.physics.static_geometry,
			OBB{Vec2{center.x, gs.window_height - offset}, Vec2{width, thickness}, 0, 0},
		)
		append(
			&gs.physics.static_geometry,
			OBB{Vec2{offset, center.y}, Vec2{thickness, height}, 0, 0},
		)
		append(
			&gs.physics.static_geometry,
			OBB{Vec2{gs.window_width - offset, center.y}, Vec2{thickness, height}, 0, 0},
		)
	}

	for !rl.WindowShouldClose() {
		input()
		update()
		render()
	}
}

input :: proc() {
	gs.input.up = false
	gs.input.down = false
	gs.input.left = false
	gs.input.right = false

	if rl.IsKeyDown(.W) do gs.input.up = true
	if rl.IsKeyDown(.S) do gs.input.down = true
	if rl.IsKeyDown(.A) do gs.input.left = true
	if rl.IsKeyDown(.D) do gs.input.right = true
}

update :: proc() {
	time_update()
	event_update()
	entity_update()

	player := entity_get(gs.player_handle)

	move_dir := Vec2{}

	if gs.input.up do move_dir.y -= 1
	if gs.input.down do move_dir.y += 1
	if gs.input.left do move_dir.x -= 1
	if gs.input.right do move_dir.x += 1

	player_movement := rl.Vector2Normalize(move_dir) * player.movement_speed * gs.time.delta
	next_player_position := player.position + player_movement

	// for rect in gs.physics.static_geometry {
	// 	if rl.CheckCollisionCircleRec(next_player_position, player.collider_radius, rect) {
	// 		gs.physics.last_collided_box = rect
	// 		next_player_position = circle_vs_rect_response(next_player_position, player.collider_radius, rect)
	// 		break
	// 	}
	// }

	player.position = next_player_position
}

render :: proc() {
	player := entity_get(gs.player_handle)

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.DrawText(
		fmt.ctprintf(
			"Frame: %d, Frame Time: %f, FPS: %d, Session: %f",
			gs.time.frame,
			gs.time.delta,
			gs.time.fps,
			gs.time.session,
		),
		8,
		8,
		20,
		rl.WHITE,
	)
	rl.DrawText(
		fmt.ctprintf(
			"Up: %v, Down: %v, Left: %v, Right: %v",
			gs.input.up,
			gs.input.down,
			gs.input.left,
			gs.input.right,
		),
		8,
		26,
		20,
		rl.WHITE,
	)

	for obb, i in gs.physics.static_geometry {
		color := obb.debug_color.a == 0 ? rl.GRAY : obb.debug_color

		world_rect := rect_from_obb(obb)
		rl.DrawRectanglePro(world_rect, obb.size / 2, math.to_degrees(obb.rotation), color)

		// Coordinate system transformation
		// Goal: Transform the player from world space into OBB's local space
		// where the OBB becomes an axis-aligned box centered at the origin

		// Matrix to move OBB to origin
		translate_to_origin := Mat3{1, 0, -obb.position.x, 0, 1, -obb.position.y, 0, 0, 1}

		// Matrix to undo OBB's rotation
		undo_rotation := Mat3 {
			math.cos(-obb.rotation),
			-math.sin(-obb.rotation),
			0,
			math.sin(-obb.rotation),
			math.cos(-obb.rotation),
			0,
			0,
			0,
			1,
		}

		// Combined transformation matrix to translate then rotate (note inverse order)
		world_to_local := undo_rotation * translate_to_origin

		// Transform player position into OBB's local coordinate system
		// A Vec3 is required to multiply by a Mat3
		player_world := Vec3{player.position.x, player.position.y, 1}
		player_local := world_to_local * player_world
		player_final := player_local.xy

		// Now we can do collision detection the same as before!
		// First, construct the OBB around the origin as an axis-aligned bounding box
		local_aabb := Rect{-obb.size.x / 2, -obb.size.y / 2, obb.size.x, obb.size.y}
		if rl.CheckCollisionCircleRec(player_final, player.collider_radius, local_aabb) {
			collision_response_local := circle_vs_rect_response(
				player_final,
				player.collider_radius,
				local_aabb,
			)

			// Transform back to world space to apply the result
			restore_rotation := Mat3 {
				math.cos(obb.rotation),
				-math.sin(obb.rotation),
				obb.position.x,
				math.sin(obb.rotation),
				math.cos(obb.rotation),
				obb.position.y,
				0,
				0,
				1,
			}

			response_local := Vec3{collision_response_local.x, collision_response_local.y, 1}
			response_world := restore_rotation * response_local
			response_final := response_world.xy

			// Debug drawing
			world_aabb := Rect {
				world_rect.x - world_rect.width / 2,
				world_rect.y - world_rect.height / 2,
				world_rect.width,
				world_rect.height,
			}
			rl.DrawRectangleLinesEx(world_aabb, 1, rl.GRAY)
			rl.DrawCircleLinesV(obb.position + player_final, player.collider_radius, rl.GRAY)

			rl.DrawCircleLinesV(response_final, player.collider_radius, rl.YELLOW)

			player.position = response_final
		}
	}

	rl.DrawCircleLinesV(player.position, player.collider_radius, rl.GREEN)

	rl.EndDrawing()
}
