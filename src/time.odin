package main

import rl "vendor:raylib"

time_update :: #force_inline proc() {
	gs.time.delta = rl.GetFrameTime()
	gs.time.frame += 1
	gs.time.session += f64(gs.time.delta)
	gs.time.fps = int(rl.GetFPS())
}
