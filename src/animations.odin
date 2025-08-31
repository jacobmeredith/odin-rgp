package main

import rl "vendor:raylib"

Animation_Type :: enum {
	None,
	Soldier_Idle,
	Soldier_Walk,
}

Sprite_Animation_Definition :: struct {
	frames:        [dynamic]int,
	frame_lengths: [dynamic]f32,
	texture:       rl.Texture,
}

Sprite_Animation_Flags :: bit_set[Sprite_Animation_Flag]
Sprite_Animation_Flag :: enum {
	Once,
	Done,
}

Sprite_Animation :: struct {
	definition:    Sprite_Animation_Definition,
	current_frame: int,
	flags:         Sprite_Animation_Flags,
	frame_timer:   f32,
}

animations_init :: proc() {
	soldier_idle: Sprite_Animation_Definition
	soldier_idle.texture = gs.assets.textures[.Solider_Idle]
	append(&soldier_idle.frames, ..[]int{0, 1, 2, 3, 4, 5})
	append(&soldier_idle.frame_lengths, ..[]f32{0.15, 0.15, 0.15, 0.15, 0.15, 0.15})
	gs.animations.sprite_animation_definitions[.Soldier_Idle] = soldier_idle

	soldier_walk: Sprite_Animation_Definition
	soldier_walk.texture = gs.assets.textures[.Solider_Walk]
	append(&soldier_walk.frames, ..[]int{0, 1, 2, 3, 4, 5, 6, 7})
	append(&soldier_walk.frame_lengths, ..[]f32{1, 1, 1, 1, 1, 1, 1, 1})
	gs.animations.sprite_animation_definitions[.Soldier_Walk] = soldier_walk
}

sprite_animations_update :: proc() {
	for &sprite_animation, i in gs.animations.sprite_animations {
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

			sprite_animation.frame_timer = sprite_animation.definition.frame_lengths[next_frame]
			sprite_animation.current_frame = next_frame
		}

		if .Done in sprite_animation.flags {
			unordered_remove(&gs.animations.sprite_animations, i)
		}
	}
}
