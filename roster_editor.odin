package hrt

import clay "./clay-odin"
import nfd "./nativefiledialog"
import "core:encoding/cbor"
import "core:fmt"
import "core:os/os2"
import "core:strings"
import rl "vendor:raylib"
import stbi "vendor:stb/image"

Saveable_Roster :: struct {
	slots: []Saveable_Slot,
}

Saveable_Slot :: struct {
	name:         string,
	color:        [4]f32,
	image:        []u8,
	image_width:  i32,
	image_height: i32,
}

Horse_Slot :: struct {
	name:          strings.Builder,
	color:         [3]f32,
	image:         rl.Texture,
	picker_active: bool,
	input_active:  bool,
	index:         u32,
	has_image:     bool,
}

Roster_Editor :: struct {
	slots:         [dynamic]Horse_Slot,
	active_input:  ^strings.Builder,
	//
	error_message: string,
	error_active:  bool,
}

roster_editor: Roster_Editor

init_roster_editor :: proc() {
}

draw_roster_editor :: proc(editor: ^Roster_Editor) {
	draw_roster_menu(editor)
}

tick_roster_editor :: proc(editor: ^Roster_Editor) {
	tick_text_inputs(editor)
	if rl.IsKeyPressed(.F11) {
		clay.SetDebugModeEnabled(!clay.IsDebugModeEnabled())
	}
}

tick_text_inputs :: proc(editor: ^Roster_Editor) {
	if editor.active_input == nil do return

	key := rl.GetCharPressed()

	for u8(key) > 0 {
		strings.write_rune(editor.active_input, key)
		key = rl.GetCharPressed()
	}

	if rl.IsKeyPressed(.BACKSPACE) {
		strings.pop_rune(editor.active_input)
	}
}

convert_to_saveable :: proc(editor: ^Roster_Editor) -> Saveable_Roster {
	slots := make([]Saveable_Slot, len(editor.slots), context.temp_allocator)
	for slot, i in editor.slots {
		slots[i] = convert_slot_to_saveable(slot)
	}
	return {slots}
}

convert_slot_to_saveable :: proc(src: Horse_Slot) -> Saveable_Slot {
	image := rl.LoadImageFromTexture(src.image)

	// This assert makes sense, if it fails then it's an internal error
	assert(image.format == .UNCOMPRESSED_R8G8B8A8)

	return {
		color = hsv_to_rgb(src.color),
		name = strings.to_string(src.name),
		image = ([^]u8)(image.data)[:image.width * image.height * 4],
		image_height = image.height,
		image_width = image.width,
	}
}

convert_from_saveable :: proc(src: Saveable_Roster, target: ^Roster_Editor) {
	target^ = {}

	for slot in src.slots {
		append(&target.slots, convert_slot_from_saveable(slot))
	}
}

convert_slot_from_saveable :: proc(src: Saveable_Slot) -> Horse_Slot {
	slot := Horse_Slot{}
	strings.write_string(&slot.name, src.name)
	slot.color = rgb_to_hsv(src.color)
	slot.has_image = true

	img := rl.Image {
		width   = src.image_width,
		height  = src.image_height,
		data    = raw_data(src.image),
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}

	slot.image = rl.LoadTextureFromImage(img)

	return slot
}

save_roster :: proc(editor: ^Roster_Editor) {
	if len(editor.slots) == 0 {
		set_roster_error(editor, "Cannot save an empty roster!")
		return
	}
	for slot in editor.slots {
		if strings.builder_len(slot.name) == 0 {
			set_roster_error(editor, fmt.aprintf("Horse %d has no name!", slot.index))
			return
		}
		if !slot.has_image {
			set_roster_error(editor, fmt.aprintf("Horse %s has no image!", strings.to_string(slot.name)))
			return
		}
	}

	path: cstring
	filter := nfd.Filter_Item{"hrtrost Files", "hrtrost"}
	args := nfd.Save_Dialog_Args {
		filter_list  = &filter,
		filter_count = 1,
	}

	result := nfd.SaveDialogU8_With(&path, &args)

	switch result {
	case .Okay:

	case .Cancel:
		set_roster_error(editor, "Load Cancelled")
		return
	case .Error:
		set_roster_error(editor, "Unknown save error")
		return
	}

	saveable_roster := convert_to_saveable(editor)

	bytes, encode_err := cbor.marshal(saveable_roster)

	if encode_err != nil {
		err_name := fmt.aprintf("Encoding error: %v", encode_err)
		set_roster_error(editor, err_name)
	}

	file, open_err := os2.open(string(path), {.Read, .Write, .Create})

	if open_err != nil {
		err_name := fmt.aprintf("File open error: %v", open_err)
		set_roster_error(editor, err_name)
	}

	_, write_err := os2.write(file, bytes)

	if write_err != nil {
		err_name := fmt.aprintf("File write error: %v", write_err)
		set_roster_error(editor, err_name)
	}
}

load_roster_to_edit :: proc(editor: ^Roster_Editor) {
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
		set_roster_error(editor, "Load cancelled")
		return
	case .Error:
		set_roster_error(editor, "Unknown load error")
		return
	}

	file, open_err := os2.open(string(path), {.Read})

	if open_err != nil {
		err_name := fmt.aprintf("File open error: %v", open_err)
		set_roster_error(editor,err_name)
		return
	}

	bytes, read_err := os2.read_entire_file(file, context.temp_allocator)

	if read_err != nil {
		err_name := fmt.aprintf("File read error: %v", read_err)
		set_roster_error(editor,err_name)
		return
	}

	saveable_roster: Saveable_Roster
	decode_err := cbor.unmarshal_from_string(string(bytes), &saveable_roster)

	if decode_err != nil {
		err_name := fmt.aprintf("Decoding error: %v", decode_err)
		set_roster_error(editor,err_name)
		return
	}

	convert_from_saveable(saveable_roster, editor)
}

set_roster_error :: proc(editor: ^Roster_Editor, message: string, location := #caller_location) {
	fmt.printfln("Error message triggered at %v: %s", location, message)
	editor.error_message = message
	editor.error_active = true
}


draw_roster_menu :: proc(editor: ^Roster_Editor) {
	clay.SetPointerState(
		transmute(clay.Vector2)rl.GetMousePosition(),
		rl.IsMouseButtonDown(rl.MouseButton.LEFT),
	)

	clay.UpdateScrollContainers(false, rl.GetMouseWheelMove() * 4, rl.GetFrameTime())

	clay.BeginLayout()

	error_box(&editor.error_active, editor.error_message)

	if clay.UI()({layout = {layoutDirection = .TopToBottom, childGap = 8}}) {

		if clay.UI()(roster_window_styles()) {
			window_titlebar("Roster Editor")
			if clay.UI()({border = {width = {0, 0, 0, 0, 1}, color = BLACK}}) {
				if editor_button("Main menu") {
					mode = .Main_Menu
				}
				if editor_button("Load Roster") {
					load_roster_to_edit(editor)
				}
				if editor_button("Add Slot") {
					add_slot(editor)
				}
				if editor_button("Save Roster") {
					save_roster(editor)
				}

			}
		}

		if len(editor.slots) > 0 {
			if clay.UI()(
			{
				layout = {
					layoutDirection = .TopToBottom,
					padding = clay.PaddingAll(8),
					childGap = 8,
				},
				border = {width = {2, 2, 2, 2, 1}, color = BLACK},
				backgroundColor = WHITE,
			},
			) {
				for &slot in editor.slots {
					draw_slot(&slot, editor)
				}
			}
		}
	}

	cmds := clay.EndLayout()
	clayRaylibRender(&cmds)
}

draw_slot :: proc(slot: ^Horse_Slot, editor: ^Roster_Editor) {
	if clay.UI()(
	{
		layout = {
			childAlignment = {y = .Center},
			childGap = 8,
			sizing = {width = clay.SizingGrow({})},
		},
	},
	) {
		roster_slot_image(slot)
		roster_text_editor(slot, editor, "Horse name")
		h_fill()
		roster_color_picker(slot, editor)
		roster_slot_x(slot, editor)
	}
}

roster_slot_image :: proc(slot: ^Horse_Slot) {
	@(static) image_plus_config := clay.TextElementConfig {
		fontId    = NOTO_SANS_BOLD,
		fontSize  = 30,
		textColor = GRAY,
	}
	if clay.UI()({}) {
		if slot.has_image {
			if clay.UI()(
			clay.ElementDeclaration {
				layout = clay.LayoutConfig {
					sizing = clay.Sizing {
						width = clay.SizingFixed(f32(slot.image.width)),
						height = clay.SizingFixed(f32(slot.image.height)),
					},
				},
				image = clay.ImageElementConfig {
					imageData = &slot.image,
					sourceDimensions = {f32(slot.image.width), f32(slot.image.height)},
				},
			},
			) {}
		} else {
			if clay.UI()(
			clay.ElementDeclaration {
				layout = clay.LayoutConfig {
					sizing = clay.Sizing {
						width = clay.SizingFixed(32),
						height = clay.SizingFixed(32),
					},
					childAlignment = clay.ChildAlignment{x = .Center, y = .Center},
				},
				backgroundColor = LIGHTGRAY,
			},
			) {
				clay.Text("+", &image_plus_config)
			}
		}

		if clay.Hovered() && rl.IsMouseButtonReleased(.LEFT) {
			pick_horse_image(slot)
		}
	}
}

pick_horse_image :: proc(slot: ^Horse_Slot) {
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
			if slot.has_image {
				rl.UnloadTexture(slot.image)
			}
			slot.has_image = true
			slot.image = rl.LoadTexture(path)
		}
	case .Cancel:
	case .Error:
	}
}

roster_slot_x :: proc(slot: ^Horse_Slot, editor: ^Roster_Editor) {
	@(static) x_config := clay.TextElementConfig {
		fontId    = NOTO_SANS_REGULAR_18,
		fontSize  = 18,
		textColor = BLACK,
	}

	id := clay.ID_LOCAL("slot_close", slot.index)

	bbox := clay.GetElementData(id).boundingBox

	if clay.UI()(
	{
		id = id,
		layout = {
			padding = clay.PaddingAll(4),
			sizing = {width = clay.SizingFixed(bbox.height)},
			childAlignment = {x = .Center, y = .Center},
		},
		border = {width = {1, 1, 1, 1, 0}, color = BLACK},
		backgroundColor = clay.Hovered() ? {255, 192, 192, 255} : WHITE,
	},
	) {
		clay.Text("X", &x_config)
		if clay.Hovered() && rl.IsMouseButtonReleased(.LEFT) {
			remove_slot(slot, editor)
		}
	}
}

roster_text_editor :: proc(
	slot: ^Horse_Slot,
	editor: ^Roster_Editor,
	$placeholder: string,
) -> bool {
	@(static) horse_slot_config := clay.TextElementConfig {
		fontId    = NOTO_SANS_REGULAR_18,
		fontSize  = 18,
		textColor = BLACK,
	}
	@(static) horse_slot_placeholder_config := clay.TextElementConfig {
		fontId    = NOTO_SANS_REGULAR_18,
		fontSize  = 18,
		textColor = LIGHTGRAY,
	}

	if clay.UI()(
	{
		layout = {padding = clay.PaddingAll(4)},
		backgroundColor = get_toggle_color(slot.input_active),
	},
	) {
		if strings.builder_len(slot.name) == 0 {
			clay.Text(placeholder, &horse_slot_placeholder_config)
		} else {
			clay.TextDynamic(strings.to_string(slot.name), &horse_slot_config)
		}

		if clay.Hovered() && rl.IsMouseButtonReleased(.LEFT) {
			if !slot.input_active {
				for &other_slot in editor.slots {
					other_slot.input_active = false
					other_slot.picker_active = false
				}
				slot.input_active = true
				editor.active_input = &slot.name
			} else {
				slot.input_active = false
				editor.active_input = nil
			}
		}
	}

	return slot.input_active
}

roster_color_picker :: proc(slot: ^Horse_Slot, editor: ^Roster_Editor) -> bool {
	if clay.UI()(
	{
		layout = {childAlignment = {x = .Right, y = .Center}, padding = clay.PaddingAll(4)},
		backgroundColor = get_toggle_color(slot.picker_active),
	},
	) {
		if clay.UI()(
		{
			layout = {sizing = {width = clay.SizingFixed(16), height = clay.SizingFixed(16)}},
			backgroundColor = hsv_to_rgb(slot.color),
		},
		) {}
		if clay.Hovered() && rl.IsMouseButtonReleased(.LEFT) {
			if !slot.picker_active {
				for &other_slot in editor.slots {
					other_slot.input_active = false
					other_slot.picker_active = false
				}
				slot.picker_active = true
			} else {
				slot.picker_active = false
			}
		}

		if slot.picker_active {
			roster_pick_color(&slot.color)
		}
	}

	return slot.picker_active
}

roster_pick_color :: proc(color: ^[3]f32) {
	if clay.UI()(
	{
		layout = {
			sizing = {width = clay.SizingFixed(128)},
			layoutDirection = .TopToBottom,
			childGap = 8,
			padding = clay.PaddingAll(8),
		},
		floating = {
			attachTo = .Parent,
			attachment = {parent = .RightTop, element = .LeftTop},
			offset = {8, 0},
		},
		backgroundColor = WHITE,
		border = {color = BLACK, width = {2, 2, 2, 2, 1}},
	},
	) {
		sv_picker(color.r, &color.g, &color.b)
		h_slider(&color.r)
	}
}

add_slot :: proc(editor: ^Roster_Editor) {
	append(&editor.slots, Horse_Slot{index = u32(len(editor.slots))})
}

remove_slot :: proc(slot: ^Horse_Slot, editor: ^Roster_Editor) {
	ordered_remove(&editor.slots, slot.index)
	for &slot, i in editor.slots {
		slot.index = u32(i)
	}
}

///
/// Styling
///

roster_window_styles :: proc() -> clay.ElementDeclaration {
	return {
		layout = {layoutDirection = .TopToBottom},
		backgroundColor = {255, 255, 255, 255},
		border = {color = {0, 0, 0, 255}, width = {2, 2, 2, 2, 2}},
	}
}
