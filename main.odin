package hrt

import clay "./clay-odin"
import nfd "./nativefiledialog"
import "core:encoding/json"
import "core:fmt"
import "core:os/os2"
import rl "vendor:raylib"


GameMode :: enum {
	Winner,
	Race,
	Bet,
	Main_Menu,
	Edit,
	Roster_Edit,
	Race_Setup,
}

mode: GameMode = .Main_Menu
winner: ^Horse = nil

carrot_image: rl.Image
carrot_texture: rl.Texture

winner_background: rl.Texture
blank_horse: rl.Texture
dummy_tex: rl.Texture

papyrus: rl.Font

map_shader: rl.Shader
hsv_picker_shader: rl.Shader
hue_slider_shader: rl.Shader

world: World

NOTO_SANS_REGULAR :: 0
NOTO_SANS_REGULAR_18 :: 3
NOTO_SANS_BOLD :: 1
PAPYRUS :: 2


main :: proc() {
	nfd.Init()
	rl.InitWindow(720, 540, "DIY HRT")
	setup_clay()
	load_assets()

	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.WHITE)
		if mode == .Winner {
			draw_winner()
			tick_winner()
		} else if mode == .Race {
			draw_world(&world)
			tick_world(&world)
		} else if mode == .Bet {
			draw_world(&world)

			draw_betting(&world)
			tick_betting(&world)
		} else if mode == .Main_Menu {
			draw_main_menu()
		} else if mode == .Edit {
			draw_editor(&editor)
			tick_editor(&editor)
		}else if mode == .Roster_Edit {
			draw_roster_editor(&roster_editor)
			tick_roster_editor(&roster_editor)
		} else if mode == .Race_Setup {
			draw_race_setup(&world)
		}
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()
	nfd.Quit()
}

load_assets :: proc() {
	carrot_image = rl.LoadImage("./assets/carrots.png")
	carrot_texture = rl.LoadTextureFromImage(carrot_image)
	winner_background = rl.LoadTexture("./assets/winner_bg.png")
	blank_horse = rl.LoadTexture("./assets/colorless_horse.png")

	loadFont(NOTO_SANS_REGULAR, 48, "./assets/NotoSans-Regular.ttf")
	loadFont(NOTO_SANS_REGULAR_18, 18, "./assets/NotoSans-Regular.ttf")
	loadFont(NOTO_SANS_BOLD, 48, "./assets/NotoSans-Bold.ttf")

	loadFont(PAPYRUS, 128, "./assets/papyrus.ttf")

	map_shader = rl.LoadShader(nil, "./assets/map.frag")
	hsv_picker_shader = rl.LoadShader(nil, "./assets/hsv_picker.frag")
	hue_slider_shader = rl.LoadShader(nil, "./assets/hue_slider.frag")

	white_img := rl.GenImageColor(1,1,rl.WHITE)
	dummy_tex = rl.LoadTextureFromImage(white_img)
	rl.UnloadImage(white_img)
}

frame := 0
textSize: f32 = 1

draw_main_menu :: proc() {
	clay.SetPointerState(
		transmute(clay.Vector2)rl.GetMousePosition(),
		rl.IsMouseButtonDown(rl.MouseButton.LEFT),
	)

	textbox_config := clay.TextElementConfig {
		fontId    = NOTO_SANS_BOLD,
		fontSize  = 48,
		textColor = {0, 0, 0, 255},
	}

	clay.BeginLayout()

	if clay.UI()(
	{
		layout = {
			sizing = {width = clay.SizingGrow({})},
			childAlignment = {x = .Center},
			layoutDirection = .TopToBottom,
			childGap = 16,
		},
	},
	) {
		clay.Text("DIY HRT", &textbox_config)
		if clay.UI()({layout = {
				sizing = {width = clay.SizingFit({})},
				childAlignment = {x = .Center},
				layoutDirection = .TopToBottom,
				childGap = 16,
			}}){
			if button("Begin a race") {
				init_race_setup()
				mode = .Race_Setup
			}
			if button("Make a race") {
				initialize_editor()
				mode = .Edit
			}
			if button("Make a roster") {
				init_roster_editor()
				mode = .Roster_Edit
			}}
	}

	render_commands := clay.EndLayout()
	clayRaylibRender(renderCommands = &render_commands)
}

decode_rle :: proc(rle: []u32) -> rl.Image {
	texture_data := [dynamic]u8{}

	black := [4]u8{0, 0, 0, 255}
	alpha := [4]u8{0, 0, 0, 0}

	current := black

	for run in rle {
		for pixel in 0 ..< run {
			append(&texture_data, current.r)
			append(&texture_data, current.g)
			append(&texture_data, current.b)
			append(&texture_data, current.a)
		}
		current = black if current == alpha else alpha

	}

	assert(len(texture_data) == 720 * 540 * 4)

	img := rl.Image {
		format  = .UNCOMPRESSED_R8G8B8A8,
		data    = raw_data(texture_data),
		width   = 720,
		height  = 540,
		mipmaps = 1,
	}
	assert(rl.IsImageValid(img))

	return img
}

draw_winner :: proc() {
	rl.DrawTexture(winner_background, 0, 0, rl.WHITE)
	rl.DrawTexture(blank_horse, 0, 0, winner.color)

	config: clay.TextElementConfig = {
		textColor = BLACK,
		fontSize  = u16(textSize),
		fontId    = PAPYRUS,
	}

	clay.BeginLayout()

	if clay.UI()(
		{layout = {sizing = {height = clay.SizingGrow({})}, childAlignment = {y = .Bottom}}},
	) {

		clay.TextDynamic(winner.name, &config)
	}

	cmds := clay.EndLayout()
	clayRaylibRender(&cmds)
}

tick_winner :: proc() {
	textSize += 1
	textSize = min(textSize, 128)
}
