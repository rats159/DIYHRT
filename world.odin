package hrt

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

make_world :: proc() -> World {
	return World {
		countdownTime = 11,
		counterDx = 1,
		counterDy = 1,
		countdownPos = {0, f32(rl.GetScreenHeight() - 32)},
	}
}

draw_world :: proc(world: ^World) {
	rl.ClearBackground(rl.WHITE)
	rl.BeginShaderMode(map_shader)
	rl.DrawTexture(world.walls_tex, 0, 0, rl.WHITE)
	rl.EndShaderMode()
	rl.DrawTextureV(carrot_texture, world.carrotPos, rl.WHITE)
	for &horse in world.horses {
		draw_horse(&horse)
	}
}

shuffle_horse_spawns :: proc(this: ^World) {
	rand.shuffle(this.horseSpawns[:])
}

draw_betting :: proc(this: ^World) {
	rl.DrawRectangleRec(this.gate, rl.WHITE)
	gate_letter_height := i32(this.gate.height / 4)
	gate_letter_x := i32(this.gate.x)
	y := i32(this.gate.y)

	rl.DrawText("G", gate_letter_x, y, gate_letter_height, rl.BLACK)
	y += gate_letter_height
	rl.DrawText("A", gate_letter_x, y, gate_letter_height, rl.BLACK)
	y += gate_letter_height
	rl.DrawText("T", gate_letter_x, y, gate_letter_height, rl.BLACK)
	y += gate_letter_height
	rl.DrawText("E", gate_letter_x, y, gate_letter_height, rl.BLACK)
	y += gate_letter_height

	str := fmt.ctprintf("Place your bets in %d", int(this.countdownTime))
	w := rl.MeasureText(str, 32)
	rl.DrawRectangle(i32(this.countdownPos.x), i32(this.countdownPos.y), w, 32, rl.RED)
	rl.DrawText(str, i32(this.countdownPos.x), i32(this.countdownPos.y), 32, rl.WHITE)
}

tick_betting :: proc(this: ^World) {
	str := fmt.ctprintf("Place your bets in %d", int(this.countdownTime))
	w := rl.MeasureText(str, 32)

	if this.countdownPos.x < 0 || i32(this.countdownPos.x) + w > rl.GetScreenWidth() do this.counterDx *= -1
	if this.countdownPos.y < 0 || i32(this.countdownPos.y) + 32 > rl.GetScreenHeight() do this.counterDy *= -1
	this.countdownPos += {f32(this.counterDx) * 2, f32(this.counterDy) * 2}
	this.countdownTime -= f32(1) / 60
	if i32(this.countdownTime) == 0 do mode = .Race
}

tick_world :: proc(this: ^World) {
	for &horse in this.horses do tick_horse(&horse, this)
}

add_horse_spawn :: proc(world: ^World, pos: [2]f32) {
	append(&world.horseSpawns, pos)
}

spawn_horse :: proc(world: ^World, horse:Horse) {
	if len(world.horseSpawns) == 0 {
		fmt.println("WARN: Tried to add a horse with no available spawn spots")
		return
	}

	horse := horse

	pos := pop(&world.horseSpawns)
	horse.pos = pos
	append(&world.horses, horse) 
}

World :: struct {
	horse_queue: []Horse,
	horseSpawns:   [dynamic]rl.Vector2,
	horses:        [dynamic]Horse,
	carrotPos:     rl.Vector2,
	gate:          rl.Rectangle,
	countdownPos:  rl.Vector2,
	countdownTime: f32,
	counterDx:     int,
	counterDy:     int,
	//
	walls: rl.Image,
	walls_tex: rl.Texture,
	//
	roster_loaded: bool,
	walls_loaded: bool
}

check_image_overlap :: proc(
	image_a: rl.Image,
	pos_a: rl.Vector2,
	image_b: rl.Image,
	pos_b: rl.Vector2,
) -> bool {
	startX := max(pos_a.x, pos_b.x)
	startY := max(pos_a.y, pos_b.y)
	endX := min(pos_a.x + f32(image_a.width), pos_b.x + f32(image_b.width))
	endY := min(pos_a.y + f32(image_a.height), pos_b.y + f32(image_b.height))

	if (startX >= endX || startY >= endY) {
		return false
	}

	for i in startX ..< endX {
		for j in startY ..< endY {
			img1X := i - pos_a.x
			img1Y := j - pos_a.y
			img2X := i - pos_b.x
			img2Y := j - pos_b.y

			if (is_transparent(image_a, img1X, img1Y) && is_transparent(image_b, img2X, img2Y)) {
				return true
			}
		}
	}

	return false
}

is_transparent :: proc(img: rl.Image, x, y: f32) -> bool {
	if (x >= 0 && i32(x) < img.width && y >= 0 && i32(y) < img.height) {
		pixel_color := rl.GetImageColor(img, i32(x), i32(y))
		return pixel_color.a == 255
	}
	return false
}

cleanup_world :: proc(world: ^World) {
	for horse in world.horses {
		rl.UnloadTexture(horse.tex)
		delete(horse.name)
	}
	free(world.walls.data)
	delete(world.horses)
	delete(world.horseSpawns)

	for horse in world.horse_queue {
		free(horse.image.data)
		delete(horse.name)
	}

	delete(world.horse_queue)
	rl.UnloadTexture(world.walls_tex)
}

reset_world :: proc(world: ^World) {
	for horse in world.horses {
		rl.UnloadTexture(horse.tex)
		delete(horse.name)
	}
	free(world.walls.data)
	clear(&world.horses)
	clear(&world.horseSpawns)
	delete(world.horse_queue)
	rl.UnloadTexture(world.walls_tex)
}