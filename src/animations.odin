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
	frame_width:   f32,
	frame_height:  f32,
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
	soldier_idle.frame_width = 100
	soldier_idle.frame_height = 100
	append(&soldier_idle.frames, ..[]int{0, 1, 2, 3, 4, 5})
	append(&soldier_idle.frame_lengths, ..[]f32{0.15, 0.15, 0.15, 0.15, 0.15, 0.15})
	gs.animations.sprite_animation_definitions[.Soldier_Idle] = soldier_idle

	soldier_walk: Sprite_Animation_Definition
	soldier_walk.texture = gs.assets.textures[.Solider_Walk]
	soldier_walk.frame_width = 100
	soldier_walk.frame_height = 100
	append(&soldier_walk.frames, ..[]int{0, 1, 2, 3, 4, 5, 6, 7})
	append(&soldier_walk.frame_lengths, ..[]f32{1, 1, 1, 1, 1, 1, 1, 1})
	gs.animations.sprite_animation_definitions[.Soldier_Walk] = soldier_walk
}
