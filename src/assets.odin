package main

import "core:fmt"
import rl "vendor:raylib"

Texture_Key :: enum {
	Test_Image,
	Solider_Idle,
	Solider_Walk,
}

assets_init :: proc() {
	assets_load_texture("./assets/textures/test_image.png", .Test_Image)
	assets_load_texture("./assets/textures/soldier_idle.png", .Solider_Idle)
	assets_load_texture("./assets/textures/soldier_walk.png", .Solider_Walk)
}

assets_load_texture :: proc(path: cstring, key: Texture_Key) {
	if key not_in gs.assets.textures {
		texture := rl.LoadTexture(path)

		if rl.IsTextureValid(texture) {
			gs.assets.textures[key] = texture

			event_enqueue(Event{debug_message = fmt.tprintf("Loaded texture `%v`", key)})
		} else {
			panic(fmt.tprintf("Failed to load texture `%v`", key))
		}
	}
}
