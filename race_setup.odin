package hrt

import clay "./clay-odin"
import nfd "./nativefiledialog"
import "core:encoding/cbor"
import "core:fmt"
import "core:os/os2"
import rl "vendor:raylib"

setup_error_message: string
setup_error_active: bool

init_race_setup :: proc() {
	if world.horse_queue != nil {
		delete(world.horse_queue)
	}
	world = make_world()
}

draw_race_setup :: proc(world: ^World) {
	clay.SetPointerState(rl.GetMousePosition(), rl.IsMouseButtonDown(.LEFT))
	clay.BeginLayout()

	error_box(&setup_error_active, setup_error_message)


	if clay.UI()({}) {
		if button("Main Menu") {
			mode = .Main_Menu
		}
		if button("Load Track") {
			load_map_to_race(world)
		}
		if button("Load Roster") {
			load_roster_to_race(world)
		}
	}
	h_fill()

	if clay.UI()(
	{floating = {attachTo = .Root, attachment = {parent = .LeftBottom, element = .LeftBottom}}},
	) {
		if button("Begin!") {
			if !world.walls_loaded || !world.roster_loaded {
				set_setup_error_message(fmt.aprintf("A race needs a roster and a track!"))
				return
			} else {
				for horse in world.horse_queue {
					spawn_horse(world, horse)
				}
				mode = .Bet
			}
		}
	}

	if world.roster_loaded {
		draw_setup_roster(world)
	}

	render_commands := clay.EndLayout()

	if world.walls_loaded {
		draw_world(world)
	}
	clayRaylibRender(&render_commands)
}

@(private = "file")
set_setup_error_message :: proc(text: string, loc := #caller_location) {
	fmt.printfln("Error message triggered at %v", loc)
	setup_error_message = text
	setup_error_active = true
}

draw_setup_roster :: proc(world: ^World) {
	if clay.UI()(
	{
		backgroundColor = WHITE,
		layout = {layoutDirection = .TopToBottom},
		border = {width = {2, 2, 2, 2, 1}, color = BLACK},
	},
	) {
		for &horse in world.horse_queue {
			draw_horse_ui(&horse)
		}
	}
}

draw_horse_ui :: proc(horse: ^Horse) {
	@(static) horse_name_config := clay.TextElementConfig {
		fontId    = NOTO_SANS_REGULAR,
		fontSize  = 24,
		textColor = BLACK,
	}
	if clay.UI()({}) {
		if clay.UI()(
		clay.ElementDeclaration {
			layout = {
				sizing = {
					width = clay.SizingFixed(f32(horse.tex.width)),
					height = clay.SizingFixed(f32(horse.tex.height)),
				},
			},
			image = clay.ImageElementConfig {
				imageData = &horse.tex,
				sourceDimensions = {width = f32(horse.tex.width), height = f32(horse.tex.height)},
			},
		},
		) {}

		clay.TextDynamic(horse.name, &horse_name_config)
	}
}

load_roster_to_race :: proc(world: ^World) {
	path: cstring
	filter := nfd.Filter_Item{"hrtrost Files", "hrtrost"}
	args := nfd.Open_Dialog_Args {
		filter_list  = &filter,
		filter_count = 1,
	}

	result := nfd.OpenDialogU8_With(&path, &args)

	switch result {
	case .Okay:

	case .Cancel:
		set_setup_error_message(fmt.aprintf("Load cancelled!"))
		return
	case .Error:
		set_setup_error_message(fmt.aprintf("Unknown load error."))
		return
	}

	file, open_err := os2.open(string(path), {.Read})

	if open_err != nil {
		set_setup_error_message(fmt.aprintf("File open error: %v",open_err))
		return
	}

	bytes, read_err := os2.read_entire_file(file, context.temp_allocator)

	if read_err != nil {
		set_setup_error_message(fmt.aprintf("File read error: %v",read_err))
		return
	}

	saveable_roster: Saveable_Roster
	unmarshal_err := cbor.unmarshal_from_string(string(bytes), &saveable_roster)

	if unmarshal_err != nil {
		set_setup_error_message(fmt.aprintf("Decoding error: %v",unmarshal_err))
		return
	}

	load_roster_into_world(saveable_roster, world)
	world.roster_loaded = true

	delete(saveable_roster.slots)
}

load_roster_into_world :: proc(roster: Saveable_Roster, world: ^World) {
	if world.horse_queue != nil {
		for horse in world.horse_queue {
			free(horse.image.data)
			rl.UnloadTexture(horse.tex)
			delete(horse.name)
		}
		delete(world.horse_queue)
	}
	world.horse_queue = make([]Horse, len(roster.slots))
	for &slot, i in roster.slots {
		img := rl.Image {
			width   = slot.image_width,
			height  = slot.image_height,
			data    = raw_data(slot.image),
			mipmaps = 1,
			format  = .UNCOMPRESSED_R8G8B8A8,
		}

		color := rl.Color{u8(slot.color.r), u8(slot.color.g), u8(slot.color.b), u8(slot.color.a)}
		world.horse_queue[i] = make_horse({0, 0}, img, slot.name, color)
	}
}

load_map_to_race :: proc(world: ^World) {
	path: cstring
	filter := nfd.Filter_Item{"Horse Race Test Maps", "hrtmap"}
	args := nfd.Open_Dialog_Args {
		filter_list  = &filter,
		filter_count = 1,
	}

	result := nfd.OpenDialogU8_With(&path, &args)
	switch result {
	case .Okay:
	case .Cancel:
		set_setup_error_message(fmt.aprintf("Load Cancelled"))
		return
	case .Error:
		set_setup_error_message(fmt.aprintf("Load failed"))
		return
	}

	race_data, err := os2.read_entire_file_from_path(string(path), context.allocator)
	defer delete(race_data)

	if err != nil {
		set_setup_error_message(fmt.aprintf("File read error: %v",err))
		return
	}

	if world.walls_loaded {
		reset_world(world)
	}

	save_data: Save_Data
	decode_err := cbor.unmarshal_from_string(string(race_data), &save_data)
	defer delete(save_data.map_data)
	defer delete(save_data.horse_spawns)

	if decode_err != nil {
		set_setup_error_message(fmt.aprintf("Decode error: %v",decode_err))
		return
	}

	for spawn in save_data.horse_spawns {
		add_horse_spawn(world, spawn)
	}

	world.carrotPos = save_data.carrot_pos
	world.gate = {
		x      = save_data.gate.x,
		y      = save_data.gate.y,
		width  = abs(save_data.gate.z - save_data.gate.x),
		height = abs(save_data.gate.y - save_data.gate.w),
	}

	world.walls = decode_rle(save_data.map_data)
	world.walls_tex = rl.LoadTextureFromImage(world.walls)
	assert(rl.IsImageValid(world.walls))
	assert(rl.IsTextureValid(world.walls_tex))

	set_color("u_foreground1", &save_data.foreground_1)
	set_color("u_foreground2", &save_data.foreground_2)
	set_color("u_background1", &save_data.background_1)
	set_color("u_background2", &save_data.background_2)
	world.walls_loaded = true
}
