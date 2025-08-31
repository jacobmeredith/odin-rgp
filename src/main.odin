package main

import "core:container/queue"
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Vec2 :: [2]f32
Vec3 :: [3]f32
Rect :: rl.Rectangle

Game_State :: struct {
	window_width:  i32,
	window_height: i32,
	time:          struct {
		delta:   f32,
		frame:   int,
		session: f64,
		fps:     int,
	},
	input:         struct {
		up, down, left, right: bool,
	},
	entity:        struct {
		entities:              [dynamic]Entity,
		generations:           [dynamic]int,
		unused_entity_handles: [dynamic]Entity_Handle,
		active_entities:       [dynamic]int,
	},
	player_handle: Entity_Handle,
	event:         struct {
		queue:       queue.Queue(Event),
		subscribers: map[Event_Type][dynamic]Event_Callback_Proc,
	},
	assets:        struct {
		textures: map[Texture_Key]rl.Texture,
	},
	animations:    struct {
		sprite_animation_definitions: [Animation_Type]Sprite_Animation_Definition,
		sprite_animations:            [dynamic]Sprite_Animation,
	},
	physics:       struct {
		static_geometry:   [dynamic]Rect,
		last_collided_box: Rect,
	},
	camera:        rl.Camera2D,
}

gs: ^Game_State

main :: proc() {
	gs = new(Game_State)

	gs.window_width = 1280
	gs.window_height = 720

	rl.InitWindow(gs.window_width, gs.window_height, "RPG")
	rl.SetTargetFPS(60)

	entity_init()
	assets_init()
	animations_init()

	gs.player_handle = entity_create()
	player := entity_get(gs.player_handle)
	player.movement_speed = 300
	player.collider_radius = 16

	center := Vec2{f32(gs.window_width), f32(gs.window_height)} / 2
	player.position = center

	append(&gs.physics.static_geometry, Rect{center.x + 16, center.y + 16, 100, 30})
	append(&gs.physics.static_geometry, Rect{center.x - 32, center.y / 2, 20, 130})
	append(&gs.physics.static_geometry, Rect{center.x - 128, center.y * 0.75, 50, 50})

	for !rl.WindowShouldClose() {
		input()
		update()
		render()
	}

	rl.CloseWindow()
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

	for rect in gs.physics.static_geometry {
		if rl.CheckCollisionCircleRec(next_player_position, player.collider_radius, rect) {
			gs.physics.last_collided_box = rect
			next_player_position = circle_vs_rect_response(
				next_player_position,
				player.collider_radius,
				rect,
			)
			break
		}
	}

	player.position = next_player_position
}

render :: proc() {
	player := entity_get(gs.player_handle)

	rl.BeginDrawing()
	{
		rl.ClearBackground(rl.BLACK)

		rl.DrawText(fmt.ctprintf("Frame: %d", gs.time.frame), 8, 8, 20, rl.WHITE)
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

		rl.DrawCircleLinesV(player.position, player.collider_radius, rl.GREEN)

		for rect in gs.physics.static_geometry {
			rl.DrawRectangleLinesEx(rect, 1, rl.GRAY)
		}

		pnext := circle_vs_rect_response(
			player.position,
			player.collider_radius,
			gs.physics.last_collided_box,
		)
		rl.DrawCircleLinesV(pnext, player.collider_radius, rl.YELLOW)
	}

	rl.EndDrawing()
}
