package hrt

import clay "./clay-odin"
import nfd "./nativefiledialog"
import rl "vendor:raylib"

Horse_Slot :: struct {
	name:  string,
	color: [3]f32,
	picker_active: bool,
}

Roster_Editor :: struct {
	slots: [dynamic]Horse_Slot,
}

roster_editor: Roster_Editor

init_roster_editor :: proc() {
}

draw_roster_editor :: proc(editor: ^Roster_Editor) {
	rl.ClearBackground(rl.RED)
	draw_roster_menu(editor)
}

tick_roster_editor :: proc(editor: ^Roster_Editor) {}

draw_roster_menu :: proc(editor: ^Roster_Editor) {
	clay.SetPointerState(
		transmute(clay.Vector2)rl.GetMousePosition(),
		rl.IsMouseButtonDown(rl.MouseButton.LEFT),
	)

	clay.BeginLayout()

	if clay.UI()({layout = {layoutDirection = .TopToBottom}}) {

		if clay.UI()(roster_window_styles()) {
			window_titlebar("Roster Editor")
			if clay.UI()({border = {width = {0, 0, 0, 0, 1}, color = BLACK}}) {
				if editor_button("Main menu") {
					mode = .Main_Menu
				}
				if editor_button("Load Roster") {}
				if editor_button("Add Slot") {
					add_slot(editor)
				}
				if editor_button("Save Roster") {}

			}
		}

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
				draw_slot(&slot)
			}
		}
	}

	cmds := clay.EndLayout()
	clayRaylibRender(&cmds)
}

draw_slot :: proc(slot: ^Horse_Slot) {
	@(static) horse_slot_config := clay.TextElementConfig {
		fontId    = NOTO_SANS_REGULAR,
		fontSize  = 18,
		textColor = BLACK,
	}

	if clay.UI()({
		layout = {
			childAlignment = {
				y = .Center
			}
		}
	}) {
		clay.TextDynamic(slot.name, &horse_slot_config)
		roster_color_picker(&slot.color, &slot.picker_active)
	}
}

roster_color_picker :: proc(color: ^[3]f32, active: ^bool) -> bool {
	if clay.UI()(
	{
		layout = {
			childAlignment = {x = .Right, y = .Center},
			padding = clay.PaddingAll(4),
			sizing = {width = clay.SizingGrow({})},
		},
		backgroundColor = get_toggle_color(active^),
	},
	) {
		if clay.UI()({layout = {sizing = {width = clay.SizingGrow({})}}}) {}
		if clay.UI()(
		{
			layout = {sizing = {width = clay.SizingFixed(16), height = clay.SizingFixed(16)}},
			backgroundColor = hsv_to_rgb(color^),
		},
		) {}
		if clay.Hovered() && rl.IsMouseButtonReleased(.LEFT) {
			active^ = !active^
		}

		if active^ {
			if roster_pick_color(color) {
				// set_color("u_foreground1", color)
			}
		}
	}

	return active^
}

roster_pick_color :: proc(color: ^[3]f32) -> bool {
	if clay.UI()(
	{
		layout = {
			sizing = {width = clay.SizingFit({})},
			layoutDirection = .TopToBottom,
			childGap = 8,
			padding = clay.PaddingAll(8)
		},
		floating = {
			attachTo = .Parent,
			attachment = {
				parent = .RightTop,
				element = .LeftTop
			},
			offset = {
				8,0
			}
		},
		backgroundColor = WHITE,
		border = {
			color = BLACK,
			width = {2,2,2,2,1}
		}
	},
	) {
		gb_changed := sv_picker(color.r, &color.g, &color.b)
		r_changed := h_slider(&color.r)
		return r_changed || gb_changed
	}

	return false
}

add_slot :: proc(editor: ^Roster_Editor) {
	append(&editor.slots, Horse_Slot{name = "Test Name"})
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
