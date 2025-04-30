package hrt

import clay "./clay-odin"
import "core:math"
import rl "vendor:raylib"

BLACK :: [4]f32{0, 0, 0, 255}
DARKGRAY :: [4]f32{96, 96, 96, 255}
GRAY :: [4]f32{128, 128, 128, 255}
LIGHTGRAY :: [4]f32{192, 192, 192, 255}
WHITE :: [4]f32{255, 255, 255, 255}

editor_bg: rl.Texture

setup_clay :: proc() {
	min_mem_size := clay.MinMemorySize()
	memory := make([^]u8, min_mem_size)
	arena := clay.CreateArenaWithCapacityAndMemory(uint(min_mem_size), memory)

	clay.Initialize(arena, {f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, {})
	clay.SetMeasureTextFunction(measureText, nil)
}

// taken from https://github.com/nicbarker/clay/blob/main/bindings/odin/examples/clay-official-website/clay-official-website.odin
loadFont :: proc(fontId: u16, fontSize: u16, path: cstring) {
	assign_at(&raylibFonts,fontId, RaylibFont {
		font   = rl.LoadFontEx(path, cast(i32)fontSize * 2, nil, 0),
		fontId = cast(u16)fontId,
	})
	rl.SetTextureFilter(raylibFonts[fontId].font.texture, rl.TextureFilter.TRILINEAR)
}

standard_button_config := clay.TextElementConfig {
	fontId        = NOTO_SANS_REGULAR_24,
	fontSize      = 24,
	textColor     = BLACK,
	textAlignment = .Right,
}

button :: proc($text: string) -> bool {
	if clay.UI()(
	{
		layout = {childAlignment = {x = .Right, y = .Center}, padding = {32, 32, 8, 8}, sizing = {width = clay.SizingGrow({})}},
		backgroundColor = clay.Hovered() ? rl.IsMouseButtonDown(.LEFT) ? GRAY : LIGHTGRAY : WHITE,
		border = {color = BLACK, width = {2,2,2,2, 0}},
	},
	) {
		clay.Text(text, &standard_button_config)
		return clay.Hovered() && rl.IsMouseButtonReleased(.LEFT)
	}

	return false
}

///
/// editor stuff
///

// True if button was pressed this frame
editor_button :: proc($text: string) -> bool {
	if clay.UI()(
	{
		layout = {padding = clay.PaddingAll(8), sizing = {width = clay.SizingGrow({})}},
		backgroundColor = clay.Hovered() ? rl.IsMouseButtonDown(.LEFT) ? {128, 128, 128, 255} : {192, 192, 192, 255} : {255, 255, 255, 255},
	},
	) {
		clay.Text(text, &editor_button_config)
		return clay.Hovered() && rl.IsMouseButtonReleased(.LEFT)
	}

	return false
}

// True if toggle is actively pressed
editor_toggle :: proc($text: string, active: ^bool) -> bool {
	if clay.UI()(
	{layout = {padding = clay.PaddingAll(8)}, backgroundColor = get_toggle_color(active^)},
	) {
		clay.Text(text, &editor_button_config)
		if clay.Hovered() && rl.IsMouseButtonReleased(.LEFT) {
			active^ = !active^
		}
	}

	return active^
}

get_toggle_color :: proc(active: bool) -> clay.Color {
	if active {
		if clay.Hovered() {
			return DARKGRAY
		}

		return GRAY
	} else {
		if clay.Hovered() {
			return LIGHTGRAY
		}

		return WHITE
	}
}

window_titlebar :: proc($name: string) {

	if clay.UI()(
	{
		id = clay.ID(name),
		layout = {sizing = {width = clay.SizingGrow({})}, padding = {8, 8, 0, 0}},
		backgroundColor = {192, 192, 192, 255},
	},
	) {
		clay.Text(name, &titlebar_config)
	}
}

h_slider :: proc(value: ^f32, id: clay.ElementId) -> bool {
	hue_slider := new(Custom_Element, context.temp_allocator)
	hue_slider^ = Hue_Slider{}
	if clay.UI()(
	{
		id = id,
		layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(16)}},
		backgroundColor = BLACK,
		custom = {customData = hue_slider},
	},
	) {
		bbox := clay.GetElementData(id).boundingBox
		over_slider := clay.Hovered()

		changed := false

		if over_slider && rl.IsMouseButtonDown(.LEFT) {
			value^ = (rl.GetMousePosition().x - bbox.x) / bbox.width
			changed = true
		}
		if clay.UI()(
		{
			layout = {sizing = {height = clay.SizingFixed(18), width = clay.SizingFixed(8)}},
			backgroundColor = {255, 255, 255, 255},
			border = {color = {0, 0, 0, 255}, width = {1, 1, 1, 1, 0}},
			floating = {
				attachTo = .Parent,
				offset = {value^ * bbox.width, 0},
				attachment = {element = .CenterCenter, parent = .LeftCenter},
				pointerCaptureMode = .Passthrough,
			},
		},
		) {}
		return changed
	}
	return false
}

sv_picker :: proc(hue: f32, sat: ^f32, val: ^f32, id: clay.ElementId) -> bool {
	bbox := clay.GetElementData(id).boundingBox
	hsv_picker := new(Custom_Element, context.temp_allocator)
	hsv_picker^ = Hsv_Picker(hue)

	if clay.UI()(
	{
		id = id,
		layout = {sizing = {width = clay.SizingGrow({}), height = clay.SizingFixed(bbox.width)}},
		backgroundColor = BLACK,
		border = {width = {1, 1, 1, 1, 0}, color = BLACK},
		custom = {customData = hsv_picker},
	},
	) {
		over_slider := clay.Hovered()

		changed := false

		if over_slider && rl.IsMouseButtonDown(.LEFT) {
			sat^ = (rl.GetMousePosition().x - bbox.x) / bbox.width
			val^ = 1 - ((rl.GetMousePosition().y - bbox.y) / bbox.height)
			changed = true
		}
		if clay.UI()(
		{
			layout = {sizing = {height = clay.SizingFixed(8), width = clay.SizingFixed(8)}},
			backgroundColor = {255, 255, 255, 255},
			cornerRadius = clay.CornerRadiusAll(4),
			border = {color = {0, 0, 0, 255}, width = {1, 1, 1, 1, 0}},
			floating = {
				attachTo = .Parent,
				offset = {sat^ * bbox.width, (1 - val^) * bbox.height},
				attachment = {element = .CenterCenter, parent = .LeftTop},
				pointerCaptureMode = .Passthrough,
			},
		},
		) {}
		return changed
	}
	return false
}

hue_to_rgb :: proc(p: f32, q: f32, t: f32) -> f32 {
	t := t
	if t < 0.0 do t += 1.0
	if t > 1.0 do t -= 1.0
	if t < 1.0 / 6.0 do return p + (q - p) * 6.0 * t
	if t < 1.0 / 2.0 do return q
	if t < 2.0 / 3.0 do return p + (q - p) * (2.0 / 3.0 - t) * 6.0
	return p
}

hsv_to_rgb :: proc(hsv: [3]f32) -> [4]f32 {
	rgb: [3]f32
	h := math.mod(hsv.r, 1)
	s := hsv.g
	v := hsv.b
	if s == 0.0 {
		rgb = hsv.zzz
	} else {
		f := math.mod(h * 6.0, 1)
		p := v * (1.0 - s)
		q := v * (1.0 - f * s)
		t := v * (1.0 - (1.0 - f) * s)

		if h < 1.0 / 6.0 do rgb = {v, t, p}
		else if h < 1.0 / 3.0 do rgb = {q, v, p}
		else if h < 0.5 do rgb = {p, v, t}
		else if h < 2.0 / 3.0 do rgb = {p, q, v}
		else if h < 5.0 / 6.0 do rgb = {t, p, v}
		else do rgb = {v, p, q}
	}
	final_rgb := rgb * 255
	return {final_rgb.r, final_rgb.g, final_rgb.b, 255}
}
