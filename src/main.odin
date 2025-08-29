package main

import "core:container/queue"
import "core:fmt"
import rl "vendor:raylib"

Vec2 :: [2]f32
Vec3 :: [3]f32

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

	entity_init()

	gs.window_width = 1280
	gs.window_height = 720

	rl.InitWindow(gs.window_width, gs.window_height, "RPG")
	rl.SetTargetFPS(60)

	gs.player_handle = entity_create()

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

	player := entity_get(gs.player_handle)

	move_dir := Vec2{}

	if gs.input.up do move_dir.y -= 1
	if gs.input.down do move_dir.y += 1
	if gs.input.left do move_dir.x -= 1
	if gs.input.right do move_dir.x += 1

	player.position += rl.Vector2Normalize(move_dir) * 300 * gs.time.delta
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

		rl.DrawCircleV(player.position, 10, rl.GREEN)

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
	}

	rl.EndDrawing()
}
