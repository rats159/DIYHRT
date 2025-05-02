package hrt

import clay "./clay-odin"
import nfd "./nativefiledialog"
import "core:container/bit_array"
import "core:encoding/json"
import "core:fmt"
import "core:math/linalg"
import "core:os/os2"
import rl "vendor:raylib"

editor: Editor_Data

Save_Data :: struct {
	horse_spawns:                                           [][2]f32,
	carrot_pos:                                             [2]f32,
	gate:                                                   [4]f32,
	foreground_1, foreground_2, background_1, background_2: [3]f32,
	map_data:                                               []u32,
}

Drag_Manager :: struct {
	current_dragging: ^rl.Vector2,
	drag_offset:      rl.Vector2,
}

Editor_Data :: struct {
	using _:            Drag_Manager,
	horseSpawns:        [dynamic]rl.Vector2,
	carrot_exists:      bool,
	carrotPos:          rl.Vector2,
	gate_exists:        bool,
	gate_tl:            rl.Vector2,
	gate_br:            rl.Vector2,

	//
	fg1, fg2, bg1, bg2: [3]f32,
	//
	walls:              rl.Image,
	walls_tex:          rl.Texture,
	//
	error_message:      string,
	error_active:       bool,
}

initialize_editor :: proc() {
	editor.fg1 = {0, 0, 0}
	editor.fg2 = {0, 0, 0}
	editor.bg1 = {0, 0, 1}
	editor.bg2 = {0, 0, 1}
	set_color("u_foreground1", &editor.fg1)
	set_color("u_foreground2", &editor.fg2)
	set_color("u_background1", &editor.bg1)
	set_color("u_background2", &editor.bg2)
	check := rl.GenImageChecked(720, 540, 16, 16, {255, 255, 255, 255}, {192, 192, 192, 255})
	editor_bg = rl.LoadTextureFromImage(check)
	rl.UnloadImage(check)
}

draw_editor :: proc(editor_world: ^Editor_Data) {
	rl.DrawTexture(editor_bg, 0, 0, rl.WHITE)
	draw_editor_world(editor_world)
	draw_editor_ui(editor_world)
}

draw_editor_world :: proc(world: ^Editor_Data) {
	rl.BeginShaderMode(map_shader)
	rl.DrawTexture(world.walls_tex, 0, 0, rl.WHITE)
	rl.EndShaderMode()
	if world.carrot_exists do rl.DrawTextureV(carrot_texture, world.carrotPos, rl.WHITE)
}

create_horse_spawn :: proc(world: ^Editor_Data) {
	append(
		&world.horseSpawns,
		rl.Vector2{f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)},
	)
}

create_gate :: proc(world: ^Editor_Data) {
	world.gate_exists = true
	world.gate_tl = {f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)} - 10
	world.gate_br = {f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)} + 10
}

create_carrot :: proc(world: ^Editor_Data) {
	world.carrot_exists = true
	world.carrotPos = {f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)}
}

map_config_open: bool
horse_config_open: bool
fg_1_open: bool
fg_2_open: bool
bg_1_open: bool
bg_2_open: bool

map_menu_pos: rl.Vector2
race_editor_pos: rl.Vector2

set_color :: proc(name: cstring, col: ^[3]f32) {
	rl.SetShaderValue(map_shader, rl.GetShaderLocation(map_shader, name), col, .VEC3)
}

draw_editor_ui :: proc(world: ^Editor_Data) {
	clay.SetPointerState(
		transmute(clay.Vector2)rl.GetMousePosition(),
		rl.IsMouseButtonDown(rl.MouseButton.LEFT),
	)


	clay.BeginLayout()

	if world.error_active {
		if clay.UI()(
		{
			layout = {
				sizing = {width = clay.SizingGrow({}), height = clay.SizingGrow({})},
				childAlignment = {x = .Center, y = .Center},
			},
			floating = {attachTo = .Root, zIndex = 99},
			backgroundColor = {0, 0, 0, 192},
		},
		) {
			if clay.UI()(
			{
				layout = {layoutDirection = .TopToBottom, childGap = 4},
				backgroundColor = {255, 255, 255, 255},
				border = {color = {0, 0, 0, 255}, width = {2, 2, 2, 2, 2}},
			},
			) {
				window_titlebar("Uh Oh!")
				if clay.UI()(
				{
					layout = {
						layoutDirection = .TopToBottom,
						padding = clay.PaddingAll(8),
						childAlignment = {x = .Center},
					},
				},
				) {
					clay.TextDynamic(editor.error_message, &standard_button_config)
					if error_button("Close") {
						editor.error_active = false
					}
				}
			}
		}
	}

	for spawn in world.horseSpawns {
		rl.DrawRectangleV(spawn, {32, 32}, {255, 0, 0, 128})
	}

	if world.gate_exists {
		gate_w := cast(i32)abs(world.gate_br.x - world.gate_tl.x)
		gate_h := cast(i32)abs(world.gate_br.y - world.gate_tl.y)
		gate_x := cast(i32)min(world.gate_tl.x, world.gate_br.x)
		gate_y := cast(i32)min(world.gate_tl.y, world.gate_br.y)
		rl.DrawRectangle(gate_x, gate_y, gate_w, gate_h, {0, 0, 255, 128})
		rl.DrawCircleV(world.gate_tl, 4, {255, 255, 0, 128})
		rl.DrawCircleV(world.gate_br, 4, {255, 255, 0, 128})
	}

	if clay.UI()(window_styles(race_editor_pos)) {
		window_titlebar("Race Editor")
		if clay.UI()({border = {width = {0, 0, 0, 0, 1}, color = BLACK}}) {
			if editor_button("Main menu") {
				mode = .Main_Menu
			}
			if editor_button("Add Spawn") {
				create_horse_spawn(world)
			}
			if editor_button("Set Gate") {
				create_gate(world)
			}
			if editor_button("Set Carrot") {
				create_carrot(world)
			}
			if editor_toggle("Map Config", &map_config_open) {
				draw_map_menu(world)
			}
			if editor_button("Save Map") {
				save_map(world)
			}}
	}

	render_commands := clay.EndLayout()
	clayRaylibRender(&render_commands)
}

draw_map_menu :: proc(world: ^Editor_Data) {
	if clay.UI()(window_styles(map_menu_pos)) {
		window_titlebar("Map Config")
		if clay.UI()(
		{
			layout = {layoutDirection = .TopToBottom, sizing = {width = clay.SizingGrow({})}},
			border = {color = BLACK, width = {0, 0, 0, 0, 1}},
		},
		) {
			if editor_button("Upload Map") {
				pick_map(world)
			}

			if editor_color_picker("Foreground 1", world.fg1, &fg_1_open) {
				if pick_color(&world.fg1, "Foreground 1") {
					set_color("u_foreground1", &world.fg1)
				}
			}
			if editor_color_picker("Foreground 2", world.fg2, &fg_2_open) {
				if pick_color(&world.fg2, "Foreground 2") {
					set_color("u_foreground2", &world.fg2)
				}
			}
			if editor_color_picker("Background 1", world.bg1, &bg_1_open) {
				if pick_color(&world.bg1, "Background 1") {
					set_color("u_background1", &world.bg1)
				}
			}
			if editor_color_picker("Background 2", world.bg2, &bg_2_open) {
				if pick_color(&world.bg2, "Background 2") {
					set_color("u_background2", &world.bg2)
				}
			}}
	}
}

titlebar_config := clay.TextElementConfig {
	fontId    = NOTO_SANS_BOLD,
	fontSize  = 24,
	textColor = {0, 0, 0, 255},
}

pick_color :: proc(color: ^[3]f32, name: string) -> bool {
	if clay.UI()(
	{
		layout = {
			sizing = {width = clay.SizingFixed(128)},
			layoutDirection = .TopToBottom,
			childGap = 8,
			padding = clay.PaddingAll(8),
		},
		floating = {
			attachTo = .ElementWithId,
			parentId = clay.ID(name, 0).id,
			attachment = {parent = .RightTop, element = .LeftTop},
			offset = {8, 0},
		},
		backgroundColor = WHITE,
		border = {color = BLACK, width = {2, 2, 2, 2, 1}},
	},
	) {
		gb_changed := sv_picker(color.r, &color.g, &color.b)
		r_changed := h_slider(&color.r)
		return r_changed || gb_changed
	}

	return false
}

window_styles :: proc(attach: rl.Vector2) -> clay.ElementDeclaration {
	return {
		layout = {layoutDirection = .TopToBottom},
		backgroundColor = {255, 255, 255, 255},
		floating = {
			attachTo = .Root,
			offset = attach,
			attachment = {element = .LeftTop, parent = .LeftTop},
		},
		border = {color = {0, 0, 0, 255}, width = {2, 2, 2, 2, 2}},
	}
}

editor_button_config := clay.TextElementConfig {
	fontId        = NOTO_SANS_REGULAR,
	fontSize      = 16,
	textColor     = {0, 0, 0, 255},
	textAlignment = .Right,
}
editor_color_picker :: proc($text: string, color: [3]f32, active: ^bool) -> bool {
	if clay.UI()(
	{
		id = clay.ID(text, 0),
		layout = {
			childAlignment = {x = .Right, y = .Center},
			padding = clay.PaddingAll(8),
			sizing = {width = clay.SizingGrow({})},
		},
		backgroundColor = get_toggle_color(active^),
	},
	) {
		clay.Text(text, &editor_button_config)
		if clay.UI()({layout = {sizing = {width = clay.SizingGrow({})}}}) {}
		if clay.UI()(
		{
			layout = {sizing = {width = clay.SizingFixed(16), height = clay.SizingFixed(16)}},
			backgroundColor = hsv_to_rgb(color),
		},
		) {}
		if clay.Hovered() && rl.IsMouseButtonReleased(.LEFT) {
			active^ = !active^
		}
	}

	return active^
}

pick_map :: proc(editor: ^Editor_Data) {
	path: cstring
	filter := nfd.Filter_Item{"PNG Files", "png"}
	args := nfd.Open_Dialog_Args {
		filter_list  = &filter,
		filter_count = 1,
	}

	result := nfd.OpenDialogU8_With(&path, &args)
	switch result {
	case .Okay:
		{
			image := rl.LoadImage(path)

			if image.width != 720 || image.height != 540 {
				set_error_message(editor, "Image must be 720x540!")
				return
			}

			editor.walls = image
			editor.walls_tex = rl.LoadTextureFromImage(editor.walls)
			nfd.FreePathU8(path)
			return
		}
	case .Cancel:
	case .Error:
	}

	set_error_message(editor, "Failed to load image, for some unknown reason")
	return
}

set_error_message :: proc(editor: ^Editor_Data, $text: string) {
	editor.error_message = text
	editor.error_active = true
}

save_map :: proc(editor: ^Editor_Data) {
	path: cstring
	filter := nfd.Filter_Item{"hrtmap Files", "hrtmap"}
	args := nfd.Save_Dialog_Args {
		filter_list  = &filter,
		filter_count = 1,
	}

	result := nfd.SaveDialogU8_With(&path, &args)

	switch result {
	case .Okay:

	case .Cancel, .Error:
		assert(false)
	}

	runs := [dynamic]u32{}
	defer delete(runs)

	a: u8 = 255
	run_length: u32 = 0

	for y in 0 ..< editor.walls.height {
		for x in 0 ..< editor.walls.width {
			pixel_alpha := rl.GetImageColor(editor.walls, x, y).a
			if pixel_alpha != a {
				append(&runs, run_length)
				run_length = 1
				a = pixel_alpha
			} else {
				run_length += 1
			}
		}
	}
	append(&runs, run_length)


	data := Save_Data {
		horse_spawns = editor.horseSpawns[:],
		carrot_pos   = editor.carrotPos,
		gate         = [4]f32 {
			editor.gate_tl.x,
			editor.gate_tl.y,
			editor.gate_br.x,
			editor.gate_br.y,
		},
		foreground_1 = editor.fg1,
		foreground_2 = editor.fg2,
		background_1 = editor.bg1,
		background_2 = editor.bg2,
		map_data     = runs[:],
	}

	bytes, err := json.marshal(data)

	if err != nil {
		fmt.println(err)
		assert(false)
	}

	file, open_err := os2.open(string(path), {.Read, .Write, .Create})

	if open_err != nil {
		fmt.println(open_err)
		assert(false)
	}

	_, write_err := os2.write(file, bytes)

	if write_err != nil {
		fmt.println(write_err)
		assert(false)
	}
}

tick_editor :: proc(world: ^Editor_Data) {
	if try_drag_windows(world) do return
	if try_drag_spawns(world) do return
}

try_drag_windows :: proc(world: ^Drag_Manager) -> bool {
	if world.current_dragging == nil {
		if try_drag_window(world, &map_menu_pos, "Map Config") ||
		   try_drag_window(world, &race_editor_pos, "Race Editor") {
			return true
		}
	} else if rl.IsMouseButtonReleased(.LEFT) {
		world.current_dragging = nil
		return false
	} else {
		world.current_dragging^ = rl.GetMousePosition() - world.drag_offset
		return true
	}

	return false
}

try_drag_spawns :: proc(world: ^Editor_Data) -> bool {
	if world.current_dragging == nil {
		for &spawn in world.horseSpawns {
			if try_drag_rect(world, &spawn, 32, 32) {
				return true
			}
		}

		if world.gate_exists &&
		   (try_drag_circle(world, &world.gate_tl, 4) ||
				   try_drag_circle(world, &world.gate_br, 4)) {
			return true
		}

		if world.carrot_exists && try_drag_rect(world, &world.carrotPos, 48, 48) {
			return true
		}
	} else if rl.IsMouseButtonReleased(.LEFT) {
		world.current_dragging = nil
		return false
	} else {
		world.current_dragging^ = rl.GetMousePosition() - world.drag_offset
		return true
	}

	return false
}

try_drag_window :: proc(world: ^Drag_Manager, vec: ^rl.Vector2, name: string) -> bool {
	bbox := clay.GetElementData(clay.ID(name)).boundingBox

	return try_drag_rect(world, vec, bbox.width, bbox.height)
}

try_drag_circle :: proc(world: ^Drag_Manager, vec: ^rl.Vector2, radius: f32) -> bool {
	if !rl.IsMouseButtonPressed(.LEFT) do return false
	if rl.CheckCollisionPointCircle(rl.GetMousePosition(), {vec.x, vec.y}, radius) {
		world.current_dragging = vec
		world.drag_offset = rl.GetMousePosition() - vec^
		return true
	}

	return false
}

try_drag_rect :: proc(world: ^Drag_Manager, vec: ^rl.Vector2, w: f32, h: f32) -> bool {
	if !rl.IsMouseButtonPressed(.LEFT) do return false
	if rl.CheckCollisionPointRec(rl.GetMousePosition(), {vec.x, vec.y, w, h}) {
		world.current_dragging = vec

		world.drag_offset = rl.GetMousePosition() - vec^
		return true
	}

	return false
}
