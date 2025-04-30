package hrt

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

HORSE_SPEED :: 2

make_horse :: proc(pos: rl.Vector2, image: rl.Image, name: string, color: rl.Color) -> Horse {
	tex := rl.LoadTextureFromImage(image)
	dir := random_dir() * HORSE_SPEED

	return Horse{pos = pos, image = image, tex = tex, name = name, color = color, dir = dir}
}

draw_horse :: proc(horse: ^Horse) {
	rl.DrawTextureV(horse.tex, horse.pos, rl.WHITE)
}

tick_horse :: proc(horse: ^Horse, world: ^World) {
	horse.pos += horse.dir
	if (horse_hits_carrot(horse, world)) {
		mode = .Winner
		winner = horse
	}

	collision_attempts := 0

	for (horse_hits_wall(horse,world) || horse_hits_horse(horse, world) && collision_attempts < 100) {
		horse.pos -= horse.dir
		horse.dir = random_dir() * HORSE_SPEED
		horse.pos += horse.dir
		collision_attempts += 1
	}
}

horse_hits_carrot :: proc(horse: ^Horse, world: ^World) -> bool {
	return check_image_overlap(carrot_image, world.carrotPos, horse.image, horse.pos)
}

horse_hits_wall :: proc(horse: ^Horse, world: ^World) -> bool {
	return check_image_overlap(world.walls, {0, 0}, horse.image, horse.pos)
}

horse_hits_horse :: proc(horse: ^Horse, world: ^World) -> bool {
	for &other in world.horses {
		if &other == horse do continue
		if check_image_overlap(other.image, other.pos, horse.image, horse.pos) {
			other.dir = random_dir() * HORSE_SPEED //TODO: Move this out
			return true
		}
	}

	return false
}

random_dir :: proc() -> rl.Vector2 {
	angle := rand.float32_range(0, math.TAU)
	x := math.cos(angle)
	y := math.sin(angle)
	return {x, y}
}
Horse :: struct {
	pos:   rl.Vector2,
	dir:   rl.Vector2,
	image: rl.Image,
	tex:   rl.Texture2D,
	name:  string,
	color: rl.Color,
}
