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
		static_geometry: [dynamic]Rect,
	},
	camera:        rl.Camera2D,
}

gs: ^Game_State

event_red_circle_offscreen_proc :: proc(event: Event) {
	payload := event.payload.(Red_Circle_Offscreen_Event_Payload)
	fmt.println("The red circle is off the screen! At position:", payload.x, payload.y)
}

system_a_start_proc :: proc(event: Event) {
	fmt.println("Hello from system a")
}

system_b_start_proc :: proc(event: Event) {
	fmt.println("Hello from system b")
}

main :: proc() {
	gs = new(Game_State)

	event_type_subscribe(.Red_Circle_Offscreen, event_red_circle_offscreen_proc)
	event_type_subscribe(.Game_Start, system_a_start_proc)
	event_type_subscribe(.Game_Start, system_b_start_proc)

	{
		event := Event {
			type          = .Game_Start,
			debug_message = "Game started!",
			debug_level   = .Info,
		}

		event_enqueue(event)
	}

	gs.window_width = 1280
	gs.window_height = 720

	rl.InitWindow(gs.window_width, gs.window_height, "RPG")
	rl.SetTargetFPS(60)

	entity_init()
	assets_init()
	animations_init()

	soldier_idle_instance: Sprite_Animation
	soldier_idle_instance.definition = gs.animations.sprite_animation_definitions[.Soldier_Idle]
	append(&gs.animations.sprite_animations, soldier_idle_instance)

	soldier_walk_instance: Sprite_Animation
	soldier_walk_instance.definition = gs.animations.sprite_animation_definitions[.Soldier_Walk]
	soldier_walk_instance.flags += {.Once}
	append(&gs.animations.sprite_animations, soldier_walk_instance)

	gs.player_handle = entity_create()
	player := entity_get(gs.player_handle)
	player.movement_speed = 300
	player.collider_radius = 16
	player.sprite_animation.definition = gs.animations.sprite_animation_definitions[.Soldier_Walk]

	center := Vec2{f32(gs.window_width), f32(gs.window_height)} / 2
	player.position = center

	append(&gs.physics.static_geometry, Rect{center.x + 16, center.y + 16, 100, 30})
	append(&gs.physics.static_geometry, Rect{center.x - 32, center.y / 2, 20, 130})
	append(&gs.physics.static_geometry, Rect{center.x - 128, center.y * 0.75, 50, 50})

	gs.camera.zoom = 4

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
			next_player_position = player.position
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
		rl.DrawText(
			fmt.ctprintf("Animations: %v", len(gs.animations.sprite_animations)),
			8,
			44,
			20,
			rl.WHITE,
		)

		duration: f64 = 5
		t := f32(gs.time.session / duration)
		a := f32(0)
		b := f32(gs.window_width)
		x := a + (b - a) * t
		rl.DrawCircleV({x, f32(gs.window_height / 2)}, 10, rl.RED)

		if x > b {
			event := Event {
				type = .Red_Circle_Offscreen,
				payload = Red_Circle_Offscreen_Event_Payload{x = x, y = f32(gs.window_height) / 2},
			}

			event_enqueue(event)
		}

		if texture, texture_ok := gs.assets.textures[.Test_Image]; texture_ok {
			rotation := f32(gs.time.session) * 200
			scale := math.sin(f32(gs.time.session))
			rl.DrawTextureEx(texture, {256, 256}, rotation, scale, rl.WHITE)
		}

		rl.DrawCircleLinesV(player.position, player.collider_radius, rl.GREEN)

		for rect in gs.physics.static_geometry {
			rl.DrawRectangleLinesEx(rect, 1, rl.GRAY)
		}

		rl.BeginMode2D(gs.camera)
		{
			for index in gs.entity.active_entities {
				entity := &gs.entity.entities[index]
				sprite_animation := &entity.sprite_animation

				if len(sprite_animation.definition.frames) > 0 {
					frame_width := sprite_animation.definition.frame_width
					frame_height := sprite_animation.definition.frame_height
					x_offset :=
						f32(sprite_animation.current_frame) *
						sprite_animation.definition.frame_width
					rl.DrawTextureRec(
						sprite_animation.definition.texture,
						{x_offset, 0, frame_width, frame_height},
						entity.position - {50, 50},
						rl.WHITE,
					)
				}
			}
		}
		rl.EndMode2D()
	}

	rl.EndDrawing()
}
