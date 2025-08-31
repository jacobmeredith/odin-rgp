package main

import "core:log"

Entity :: struct {
	position:         Vec2,
	sprite_animation: Sprite_Animation,
	movement_speed:   f32,
	collider_radius:  f32,
}

Entity_Handle :: struct {
	index:      int,
	generation: int,
}

// NOTE this is to set the first entity as a nil entity
entity_init :: proc() {
	append(&gs.entity.entities, Entity{})
	append(&gs.entity.generations, 0)
}

entity_create :: proc() -> Entity_Handle {
	handle: Entity_Handle

	// NOTE use unused handle if one exists
	if len(gs.entity.unused_entity_handles) > 0 {
		handle = pop(&gs.entity.unused_entity_handles)
		gs.entity.generations[handle.index] = handle.generation
	} else {
		handle.index = len(gs.entity.entities)

		_, append_entity_err := append(&gs.entity.entities, Entity{})
		_, append_generation_err := append(&gs.entity.generations, 0)

		if append_entity_err != .None || append_generation_err != .None {
			log.error("Unable to allocate space for entity. Returning the nil Entity_Handle")
			handle.index = 0
		}
	}

	append(&gs.entity.active_entities, handle.index)

	// NOTE zero the entity data
	gs.entity.entities[handle.index] = {}

	return handle
}

entity_get :: proc(handle: Entity_Handle) -> ^Entity {
	// NOTE default to nil entity
	ptr := &gs.entity.entities[0]

	if handle.index < len(gs.entity.entities) {
		stored_generation := gs.entity.generations[handle.index]

		if stored_generation == handle.generation {
			ptr = &gs.entity.entities[handle.index]
		}
	}

	return ptr
}

entity_destroy :: proc(handle: Entity_Handle) {
	if handle.index < len(gs.entity.entities) {
		stored_generation := gs.entity.generations[handle.index]

		if stored_generation == handle.generation {
			gs.entity.generations[handle.index] += 1

			index, _ := append(
				&gs.entity.unused_entity_handles,
				Entity_Handle{index = handle.index, generation = handle.generation + 1},
			)

			for entity_index, i in gs.entity.active_entities {
				if entity_index == handle.index {
					unordered_remove(&gs.entity.active_entities, i)
					break
				}
			}
		}
	}
}

entity_update :: proc() {
	for index in gs.entity.active_entities {
		entity := &gs.entity.entities[index]

		sprite_animation := &entity.sprite_animation

		if len(sprite_animation.definition.frames) > 0 {
			sprite_animation.frame_timer -= gs.time.delta

			if sprite_animation.frame_timer <= 0 {
				next_frame := sprite_animation.current_frame + 1

				if .Once not_in sprite_animation.flags {
					next_frame = next_frame % len(sprite_animation.definition.frames)
				} else {
					next_frame = min(next_frame, len(sprite_animation.definition.frames) - 1)
					if sprite_animation.current_frame == next_frame {
						sprite_animation.flags += {.Done}
					}
				}

				sprite_animation.frame_timer =
					sprite_animation.definition.frame_lengths[next_frame]
				sprite_animation.current_frame = next_frame
			}
		}
	}
}
