package hrt

import clay "./clay-odin"
import nfd "./nativefiledialog"
import rl "vendor:raylib"
import "core:fmt"

Roster_Editor :: struct {
	menu_pos: [2]f32,
}

roster_editor: Roster_Editor

init_roster_editor :: proc(){
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

	if clay.UI()(window_styles(editor.menu_pos)) {
		window_titlebar("Roster Editor")
		if clay.UI()({border = {width = {0, 0, 0, 0, 1}, color = BLACK}}) {
			if editor_button("Main menu") {
				mode = .Main_Menu
			}
            if editor_button("Load Roster"){}
            if editor_button("Add Slot"){
                
            }
            if editor_button("Save Roster"){}
            
		}
	}

	cmds := clay.EndLayout()
	clayRaylibRender(&cmds)
}
