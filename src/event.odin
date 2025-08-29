package main

import "core:container/queue"
import "core:fmt"
import "core:log"

Event_Type :: enum {
	Game_Start,
	Red_Circle_Offscreen,
}

Empty_Event_Payload :: struct {}

Red_Circle_Offscreen_Event_Payload :: struct {
	x: f32,
	y: f32,
}

Event_Payload :: union {
	Empty_Event_Payload,
	Red_Circle_Offscreen_Event_Payload,
}

Event :: struct {
	type:          Event_Type,
	payload:       Event_Payload,
	debug_message: string,
	debug_level:   log.Level,
}

Event_Callback_Proc :: proc(event: Event)

event_type_subscribe :: proc(event_type: Event_Type, cb: Event_Callback_Proc) {
	if event_type not_in gs.event.subscribers {
		gs.event.subscribers[event_type] = {}
	}

	append(&gs.event.subscribers[event_type], cb)
}

event_enqueue :: proc(event: Event) {
	queue.push_back(&gs.event.queue, event)
}

event_update :: proc() {
	if queue.len(gs.event.queue) > 0 {
		event := queue.pop_front(&gs.event.queue)

		if event.debug_message != "" {
			fmt.printfln("[%s] %s", event.debug_level, event.debug_message)
		}

		if gs.event.subscribers[event.type] != nil {
			for callback_proc in gs.event.subscribers[event.type] {
				callback_proc(event)
			}
		}
	}
}
