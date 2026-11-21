class_name UiKit
extends RefCounted
## 공통 UI 스타일/위젯

static var title_font: Font
static var body_font: Font
static var theme: Theme


static func init_theme(root: Window) -> void:
	if ResourceLoader.exists("res://assets/fonts/title.ttf"):
		title_font = load("res://assets/fonts/title.ttf")
	if ResourceLoader.exists("res://assets/fonts/body.ttf"):
		body_font = load("res://assets/fonts/body.ttf")
	var th := Theme.new()
	if body_font:
		th.default_font = body_font
	th.default_font_size = 20
	th.set_color("font_color", "Label", Color(0.95, 0.96, 1.0))
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	th.set_constant("outline_size", "Label", 3)
	var sb := style(Color(0.12, 0.15, 0.22, 0.92), 12)
	th.set_stylebox("normal", "Button", sb)
	th.set_stylebox("hover", "Button", style(Color(0.18, 0.22, 0.32, 0.95), 12))
	th.set_stylebox("pressed", "Button", style(Color(1.0, 0.6, 0.15, 0.95), 12))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("disabled", "Button", style(Color(0.1, 0.1, 0.12, 0.6), 12))
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color(0.05, 0.05, 0.08))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_stylebox("panel", "PanelContainer", style(Color(0.07, 0.09, 0.14, 0.85), 16))
	var grab := style(Color(1.0, 0.6, 0.15), 10)
	grab.content_margin_left = 10
	th.set_stylebox("slider", "HSlider", style(Color(0.2, 0.24, 0.32), 6))
	th.set_stylebox("grabber_area", "HSlider", style(Color(1.0, 0.6, 0.15, 0.8), 6))
	th.set_stylebox("grabber_area_highlight", "HSlider", style(Color(1.0, 0.7, 0.3, 0.9), 6))
	root.theme = th
	theme = th


static func style(c: Color, r: int, border: Color = Color(1, 1, 1, 0.08), bw: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.anti_aliasing = true
	return s


static func big_button(text: String, col: Color, min_size: Vector2 = Vector2(220, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	if title_font:
		b.add_theme_font_override("font", title_font)
	var n := style(col, 14, col.lightened(0.35), 3)
	n.shadow_color = Color(0, 0, 0, 0.35)
	n.shadow_size = 6
	n.shadow_offset = Vector2(0, 4)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", style(col.lightened(0.12), 14, col.lightened(0.5), 3))
	b.add_theme_stylebox_override("pressed", style(col.darkened(0.2), 14, col.lightened(0.3), 3))
	var dark := col.get_luminance() > 0.55
	b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.1) if dark else Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color(0.06, 0.06, 0.1) if dark else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.pressed.connect(func(): Sfx.play("ui", -8.0))
	return b


static func label(text: String, size: int = 20, col: Color = Color(0.95, 0.96, 1.0), title: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if title and title_font:
		l.add_theme_font_override("font", title_font)
	return l


static func slider_row(text: String, mn: float, mx: float, val: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := label(text, 22)
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(260, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(cb)
	row.add_child(s)
	return row


static func toggle_row(text: String, val: bool, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := label(text, 22)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var b := CheckButton.new()
	b.button_pressed = val
	b.focus_mode = Control.FOCUS_NONE
	b.toggled.connect(cb)
	row.add_child(b)
	return row


static func stat_bar(name: String, v: float, col: Color = Color(1.0, 0.6, 0.15)) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := label(name, 16, Color(0.75, 0.8, 0.9))
	l.custom_minimum_size = Vector2(64, 0)
	row.add_child(l)
	var bg := Panel.new()
	bg.custom_minimum_size = Vector2(200, 12)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.add_theme_stylebox_override("panel", style(Color(0.2, 0.22, 0.3), 6, Color(0, 0, 0, 0), 0))
	row.add_child(bg)
	var fg := Panel.new()
	fg.add_theme_stylebox_override("panel", style(col, 6, Color(0, 0, 0, 0), 0))
	fg.size = Vector2(200 * clampf(v, 0.04, 1.0), 12)
	bg.add_child(fg)
	return row
