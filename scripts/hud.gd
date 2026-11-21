class_name Hud
extends CanvasLayer
## 경기 HUD + 터치 조작. 터치 상태(move/look/fire...)를 플레이어 컨트롤러가 읽어간다.

signal pause_requested
signal slot_tapped(i: int)

var m: Node
var player: Fighter
var touch := false

# 터치 상태
var move_vec := Vector2.ZERO
var look_delta := Vector2.ZERO
var fire_held := false
var aim_toggle := false
var jump_tap := false
var slide_tap := false
var reload_tap := false
var _touches := {}   # index -> {role, start, pos}
var _stick_center := Vector2.ZERO
var _stick_active := false
var _hint_t := 4.0

var root: Control
var draw: Control
var score_lbl: Label
var round_lbl: Label
var center_lbl: Label
var sub_lbl: Label
var health_lbl: Label
var ammo_lbl: Label
var wname_lbl: Label
var feed: VBoxContainer
var slots_box: HBoxContainer
var slot_btns: Array[Button] = []
var flash_rect: ColorRect
var hurt_rect: ColorRect
var scope_rect: Control
var pause_btn: Button
var keys_lbl: Label
var fps_lbl: Label
var _fps_t := 0.0

var _hit_t := 0.0
var _hit_kill := false
var _hit_head := false
var _dmg_dir_t := 0.0
var _dmg_dir := 0.0
var _center_t := 0.0
var _btn := {}   # name -> {pos, r}


func setup(match_node: Node, p: Fighter) -> void:
	m = match_node
	player = p
	touch = Game.is_touch
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	hurt_rect = ColorRect.new()
	hurt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hurt_rect.color = Color(0.9, 0.1, 0.1, 0.0)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_rect)

	scope_rect = Control.new()
	scope_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_rect.draw.connect(_draw_scope)
	scope_rect.visible = false
	root.add_child(scope_rect)

	draw = Control.new()
	draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.draw.connect(_draw_overlay)
	root.add_child(draw)

	# 상단 점수
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-200, 8)
	top.size = Vector2(400, 80)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	score_lbl = _label(top, "", 34, Color.WHITE)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_lbl = _label(top, "", 18, Color(0.85, 0.9, 1.0))
	round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	center_lbl = _label(root, "", 64, Color.WHITE)
	center_lbl.set_anchors_preset(Control.PRESET_CENTER)
	center_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_lbl.size = Vector2(900, 90)
	center_lbl.position = Vector2(-450, -170)
	sub_lbl = _label(root, "", 26, Color(1, 0.9, 0.5))
	sub_lbl.set_anchors_preset(Control.PRESET_CENTER)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.size = Vector2(900, 40)
	sub_lbl.position = Vector2(-450, -90)

	# 킬피드
	feed = VBoxContainer.new()
	feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	feed.position = Vector2(-430, 60 if touch else 12)
	feed.size = Vector2(420, 200)
	feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed)

	# 체력 / 탄약
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hb.position = Vector2(-260, -84)
	hb.size = Vector2(520, 56)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 40)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hb)
	health_lbl = _label(hb, "100", 40, Color(0.6, 1.0, 0.6))
	var wv := VBoxContainer.new()
	wv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(wv)
	ammo_lbl = _label(wv, "30 / 90", 30, Color.WHITE)
	wname_lbl = _label(wv, "", 16, Color(0.8, 0.85, 0.9))

	# 무기 슬롯 버튼
	slots_box = HBoxContainer.new()
	slots_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	slots_box.position = Vector2(-230, -146)
	slots_box.size = Vector2(460, 54)
	slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_box.add_theme_constant_override("separation", 8)
	root.add_child(slots_box)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func(): slot_tapped.emit(i))
		slots_box.add_child(b)
		slot_btns.append(b)

	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.add_theme_font_size_override("font_size", 22)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause_btn.position = Vector2(14, 12)
	pause_btn.size = Vector2(56, 48)
	pause_btn.pressed.connect(func(): pause_requested.emit())
	root.add_child(pause_btn)

	fps_lbl = _label(root, "", 14, Color(1, 1, 1, 0.55))
	fps_lbl.position = Vector2(80, 26)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)
	if touch:
		pause_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for b in slot_btns:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_slots()


func _label(parent: Control, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


var _slot_key := ""


func _style_slots() -> void:
	var key := "%s|%d|%d" % [str(player.slots), player.cur, player.util_left]
	if key == _slot_key:
		return
	_slot_key = key
	for i in slot_btns.size():
		var b := slot_btns[i]
		if i >= player.slots.size():
			b.visible = false
			continue
		b.visible = true
		var w := Data.weapon(player.slots[i])
		b.text = "%d %s" % [i + 1, w.name]
		var sb := StyleBoxFlat.new()
		var active := i == player.cur
		sb.bg_color = Color(1.0, 0.62, 0.15, 0.9) if active else Color(0.08, 0.1, 0.14, 0.6)
		sb.set_corner_radius_all(10)
		sb.border_color = Color(1, 1, 1, 0.25)
		sb.set_border_width_all(2)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08) if active else Color.WHITE)
		if w.kind == "grenade" and player.util_left <= 0:
			b.modulate = Color(1, 1, 1, 0.35)
		else:
			b.modulate = Color.WHITE


# ------------------------------------------------------------------ 표시
func show_center(text: String, sub: String = "", t: float = 1.6, col: Color = Color.WHITE) -> void:
	center_lbl.text = text
	center_lbl.add_theme_color_override("font_color", col)
	sub_lbl.text = sub
	_center_t = t
	center_lbl.modulate.a = 1.0
	sub_lbl.modulate.a = 1.0
	center_lbl.pivot_offset = center_lbl.size / 2
	center_lbl.scale = Vector2(1.3, 1.3)
	var tw := center_lbl.create_tween()
	tw.tween_property(center_lbl, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)


func hit_marker(kill: bool, head: bool) -> void:
	_hit_t = 0.25 if not kill else 0.45
	_hit_kill = kill
	_hit_head = head


func hurt_from(dir_world: Vector3) -> void:
	_dmg_dir_t = 1.0
	var local := Basis(Vector3.UP, player.yaw).inverse() * dir_world
	_dmg_dir = atan2(local.x, -local.z)


func add_feed(killer: String, victim: String, wname: String, head: bool, kcol: Color, vcol: Color) -> void:
	var row := RichTextLabel.new()
	row.bbcode_enabled = true
	row.fit_content = true
	row.scroll_active = false
	row.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.custom_minimum_size = Vector2(420, 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_font_size_override("normal_font_size", 18)
	row.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	row.add_theme_constant_override("outline_size", 5)
	var hs := " [color=#ffd24a]◎[/color]" if head else ""
	row.text = "[right][color=#%s]%s[/color]  [color=#dddddd][%s][/color]%s  [color=#%s]%s[/color][/right]" % [
		kcol.to_html(false), killer, wname, hs, vcol.to_html(false), victim]
	feed.add_child(row)
	if feed.get_child_count() > 5:
		feed.get_child(0).queue_free()
	var tw := row.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.5)
	tw.tween_callback(row.queue_free)


func _process(delta: float) -> void:
	if player == null:
		return
	_hit_t = maxf(0.0, _hit_t - delta)
	if _stick_active:
		_hint_t = 0.0
	else:
		_hint_t = maxf(0.0, _hint_t - delta * 0.25)
	_dmg_dir_t = maxf(0.0, _dmg_dir_t - delta)
	if _center_t > 0.0:
		_center_t -= delta
		if _center_t < 0.3:
			center_lbl.modulate.a = maxf(0.0, _center_t / 0.3)
			sub_lbl.modulate.a = center_lbl.modulate.a
	var hp := int(ceil(player.health))
	_set_text(health_lbl, "✚ %d" % hp)
	health_lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if hp > 50 else (Color(1, 0.85, 0.3) if hp > 25 else Color(1, 0.35, 0.3)))
	var w := player.wdata()
	_set_text(wname_lbl, w.name)
	if w.kind == "knife":
		_set_text(ammo_lbl, "—")
	elif w.kind == "grenade":
		_set_text(ammo_lbl, "× %d" % player.util_left)
	elif player.reload_t > 0.0:
		_set_text(ammo_lbl, "재장전…")
	else:
		var a: Array = player.ammo[player.wid()]
		_set_text(ammo_lbl, "%d / %d" % [a[0], a[1]])
	_fps_t -= delta
	if _fps_t <= 0.0:
		_fps_t = 0.5
		_set_text(fps_lbl, "%d FPS" % Engine.get_frames_per_second())
	hurt_rect.color.a = clampf((1.0 - player.health / player.max_health) * 0.35 - 0.05, 0.0, 0.3) if player.alive else 0.25
	flash_rect.color.a = clampf(player.flashed / 1.2, 0.0, 1.0)
	scope_rect.visible = player.scoped
	var vis := player.alive
	slots_box.visible = vis
	_style_slots()
	draw.queue_redraw()
	if scope_rect.visible:
		scope_rect.queue_redraw()


func _set_text(l: Label, t: String) -> void:
	if l.text != t:
		l.text = t


func _draw_scope() -> void:
	var s := scope_rect.size
	var c := s / 2.0
	var r := s.y * 0.46
	var col := Color(0, 0, 0, 1)
	scope_rect.draw_rect(Rect2(0, 0, c.x - r, s.y), col)
	scope_rect.draw_rect(Rect2(c.x + r, 0, s.x - c.x - r, s.y), col)
	# 원 바깥 채우기 (폴리곤)
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var a := PI + PI * float(i) / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(Vector2(c.x + r, 0))
	pts.append(Vector2(c.x - r, 0))
	scope_rect.draw_colored_polygon(pts, col)
	pts = PackedVector2Array()
	for i in n + 1:
		var a := PI * float(i) / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(Vector2(c.x - r, s.y))
	pts.append(Vector2(c.x + r, s.y))
	scope_rect.draw_colored_polygon(pts, col)
	scope_rect.draw_arc(c, r, 0, TAU, 64, Color(0.05, 0.05, 0.05), 6)
	scope_rect.draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), Color(0, 0, 0, 0.9), 2)
	scope_rect.draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), Color(0, 0, 0, 0.9), 2)
	scope_rect.draw_circle(c, 3, Color(1, 0.2, 0.2))


func _draw_overlay() -> void:
	var s := draw.size
	var c := s / 2.0
	if player.alive and not player.scoped:
		var w := player.wdata()
		var spread: float = float(w.spread) + float(w.move_spread) * player.move_frac() + player.recoil * 0.3
		if w.kind == "sniper":
			spread = float(w.spread)
		if not player.is_on_floor():
			spread += 4.0
		var gap := 6.0 + spread * 6.0
		var len := 9.0
		var col := Color(0.4, 1.0, 0.6, 0.95)
		var oc := Color(0, 0, 0, 0.7)
		if w.kind == "knife" or w.kind == "grenade":
			draw.draw_circle(c, 4, oc)
			draw.draw_circle(c, 2.5, col)
		else:
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw.draw_line(c + d * gap, c + d * (gap + len), oc, 4)
				draw.draw_line(c + d * gap, c + d * (gap + len), col, 2)
			draw.draw_circle(c, 1.5, col)
	if _hit_t > 0.0:
		var hc := Color(1, 0.25, 0.25) if _hit_kill else (Color(1, 0.85, 0.2) if _hit_head else Color.WHITE)
		var g := 8.0
		var l := 9.0 + (6.0 if _hit_kill else 0.0)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dn: Vector2 = d.normalized()
			draw.draw_line(c + dn * g, c + dn * (g + l), Color(0, 0, 0, 0.7), 5)
			draw.draw_line(c + dn * g, c + dn * (g + l), hc, 3)
	if _dmg_dir_t > 0.0:
		var a := _dmg_dir - PI / 2
		draw.draw_arc(c, 120, a - 0.35, a + 0.35, 16, Color(1, 0.2, 0.2, _dmg_dir_t * 0.9), 10)
	if touch and player.alive:
		_draw_touch()


# ------------------------------------------------------------------ 터치 UI
func _layout_buttons() -> void:
	var s := root.size
	var u := s.y / 720.0 * Game.btn_scale
	var W := s.x
	var H := s.y
	var k := s.y / 720.0
	# 오른손 엄지가 발사 버튼을 중심으로 닿는 반원 배치
	_btn = {
		"fire": {"pos": Vector2(W - 200 * k, H - 205 * k), "r": 80 * u, "label": "발사", "icon": "fire"},
		"aim": {"pos": Vector2(W - 350 * k, H - 140 * k), "r": 46 * u, "label": "조준", "icon": "aim"},
		"reload": {"pos": Vector2(W - 345 * k, H - 300 * k), "r": 40 * u, "label": "장전", "icon": "reload"},
		"jump": {"pos": Vector2(W - 82 * k, H - 318 * k), "r": 54 * u, "label": "점프", "icon": "jump"},
		"slide": {"pos": Vector2(W - 72 * k, H - 76 * k), "r": 46 * u, "label": "슬라이드", "icon": "slide"},
		"swap": {"pos": Vector2(W - 74 * k, H - 462 * k), "r": 38 * u, "label": "교체", "icon": "swap"},
	}
	if Game.left_fire:
		_btn["fire2"] = {"pos": Vector2(140 * k, H - 400 * k), "r": 50 * u, "label": "발사", "icon": "fire"}


func _btn_held(k: String) -> bool:
	for t in _touches.values():
		if t.role == k:
			return true
	return false


func _draw_touch() -> void:
	_layout_buttons()
	var font := draw.get_theme_default_font()
	var a: float = Game.btn_alpha
	var now := Time.get_ticks_msec() / 1000.0
	for k in _btn:
		var b: Dictionary = _btn[k]
		var held := _btn_held(k)
		var on: bool = held or (k == "aim" and (aim_toggle or player.scoped))
		var r: float = b.r * (0.92 if held else 1.0)
		var c: Vector2 = b.pos
		var is_fire: bool = str(k).begins_with("fire")
		# 그림자 + 유리판 원
		draw.draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.25 * a))
		var fill := Color(0.06, 0.08, 0.13, 0.5 * a)
		if is_fire:
			fill = Color(0.92, 0.27, 0.18, (0.85 if held else 0.62) * a)
		elif on:
			fill = Color(1.0, 0.6, 0.15, 0.85 * a)
		draw.draw_circle(c, r, fill)
		draw.draw_circle(c + Vector2(0, -r * 0.35), r * 0.62, Color(1, 1, 1, 0.06 * a))
		draw.draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, (0.75 if on or held else 0.4) * a), 2.5)
		# 상태 링: 발사=탄약, 장전=진행도, 슬라이드=재사용 대기
		var ring := -1.0
		var w := player.wdata()
		if is_fire and int(w.mag) > 0 and w.kind != "grenade":
			ring = float(player.ammo[player.wid()][0]) / float(w.mag)
		elif k == "reload" and player.reload_t > 0.0:
			ring = 1.0 - player.reload_t / maxf(0.01, float(w.reload))
		elif k == "slide" and (player.slide_cd > 0.0 or player.is_sliding()):
			ring = 1.0 - player.slide_cd / 0.45 if not player.is_sliding() else 0.0
		if ring >= 0.0:
			draw.draw_arc(c, r + 5, -PI / 2, -PI / 2 + TAU * clampf(ring, 0.0, 1.0), 48,
				Color(1, 0.85, 0.3, 0.95 * a) if not (is_fire and ring < 0.25) else Color(1, 0.3, 0.25, a), 4)
		# 아이콘
		var ic := Color(1, 1, 1, 0.95 * maxf(a, 0.6))
		if on and not is_fire:
			ic = Color(0.08, 0.06, 0.04, 0.95)
		_icon(b.icon, c + Vector2(0, -r * 0.1), r * 0.42, ic)
		# 작은 글자
		var fs := int(clampf(r * 0.24, 11, 18))
		var ts := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw.draw_string(font, c + Vector2(-ts.x / 2, r * 0.62), b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(ic.r, ic.g, ic.b, 0.85 * ic.a))
	# 수류탄 개수 배지(교체 버튼 옆 대신 무기 칸에서 이미 표시)
	# 조이스틱
	var k2 := root.size.y / 720.0 * Game.btn_scale
	var base := _stick_center if _stick_active else Vector2(200 * root.size.y / 720.0, root.size.y - 185 * root.size.y / 720.0)
	var br := 92 * k2
	var ba := (1.0 if _stick_active else 0.55) * a
	draw.draw_circle(base, br, Color(0.06, 0.08, 0.13, 0.35 * ba))
	draw.draw_arc(base, br, 0, TAU, 56, Color(1, 1, 1, 0.35 * ba), 2.5)
	for i in 4:
		var ang := i * PI / 2 - PI / 2
		var dv := Vector2(cos(ang), sin(ang))
		var tip := base + dv * (br - 14 * k2)
		var side := Vector2(-dv.y, dv.x) * 7 * k2
		draw.draw_colored_polygon(PackedVector2Array([tip, tip - dv * 10 * k2 + side, tip - dv * 10 * k2 - side]), Color(1, 1, 1, 0.45 * ba))
	var knob := base + move_vec * Vector2(1, -1) * 60 * k2
	draw.draw_circle(knob + Vector2(0, 3), 40 * k2, Color(0, 0, 0, 0.25 * ba))
	draw.draw_circle(knob, 40 * k2, Color(1, 1, 1, 0.55 * ba))
	draw.draw_circle(knob + Vector2(0, -10 * k2), 26 * k2, Color(1, 1, 1, 0.25 * ba))
	if not _stick_active and _hint_t > 0.0:
		var hf := root.get_theme_default_font()
		var hs := "여기를 눌러 이동"
		var hsz := hf.get_string_size(hs, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		draw.draw_string(hf, base + Vector2(-hsz.x / 2, -br - 12), hs, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 0.7 * minf(1.0, _hint_t)))


## 단순한 선 아이콘 (s = 크기 기준)
func _icon(kind: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.14)
	match kind:
		"fire":
			draw.draw_arc(c, s * 0.62, 0, TAU, 32, col, w)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw.draw_line(c + d * s * 0.3, c + d * s * 0.95, col, w)
			draw.draw_circle(c, w * 0.8, col)
		"aim":
			var q := s * 0.75
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner := c + Vector2(sx * q, sy * q * 0.8)
					draw.draw_line(corner, corner + Vector2(-sx * q * 0.45, 0), col, w)
					draw.draw_line(corner, corner + Vector2(0, -sy * q * 0.45), col, w)
			draw.draw_circle(c, w, col)
		"reload":
			draw.draw_arc(c, s * 0.6, -PI * 0.25, PI * 1.45, 28, col, w)
			var tip := c + Vector2(cos(-PI * 0.25), sin(-PI * 0.25)) * s * 0.6
			draw.draw_colored_polygon(PackedVector2Array([tip + Vector2(s * 0.3, 0), tip + Vector2(-s * 0.12, -s * 0.28), tip + Vector2(-s * 0.1, s * 0.25)]), col)
		"jump":
			for i in 2:
				var y := c.y + s * 0.15 - i * s * 0.5
				draw.draw_polyline(PackedVector2Array([Vector2(c.x - s * 0.6, y + s * 0.3), Vector2(c.x, y - s * 0.25), Vector2(c.x + s * 0.6, y + s * 0.3)]), col, w)
		"slide":
			draw.draw_line(c + Vector2(-s * 0.8, s * 0.45), c + Vector2(s * 0.8, s * 0.45), col, w)
			draw.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.5), c + Vector2(-s * 0.1, s * 0.2), c + Vector2(s * 0.7, s * 0.2)]), col, w)
			draw.draw_circle(c + Vector2(-s * 0.55, -s * 0.72), s * 0.18, col)
			for i in 3:
				var yy := c.y - s * 0.25 + i * s * 0.2
				draw.draw_line(Vector2(c.x + s * 0.35, yy - s * 0.3), Vector2(c.x + s * 0.85, yy - s * 0.3), Color(col.r, col.g, col.b, col.a * 0.6), w * 0.6)
		"swap":
			draw.draw_line(c + Vector2(-s * 0.6, -s * 0.25), c + Vector2(s * 0.6, -s * 0.25), col, w)
			draw.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.8, -s * 0.25), c + Vector2(s * 0.45, -s * 0.5), c + Vector2(s * 0.45, 0)]), col)
			draw.draw_line(c + Vector2(s * 0.6, s * 0.3), c + Vector2(-s * 0.6, s * 0.3), col, w)
			draw.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.8, s * 0.3), c + Vector2(-s * 0.45, s * 0.05), c + Vector2(-s * 0.45, s * 0.55)]), col)


func _input(event: InputEvent) -> void:
	if not touch or player == null:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_touch_down(e.index, e.position)
		else:
			_touch_up(e.index)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if not _touches.has(e.index):
			return
		var t: Dictionary = _touches[e.index]
		# relative 대신 직접 계산한 위치 차이를 쓴다 (손가락 번호가 꼬여도 튀지 않게)
		var d: Vector2 = e.position - t.pos
		t.pos = e.position
		if d.length() > 90.0:
			return  # 한 번에 너무 크게 움직였다면 잘못된 이벤트로 보고 무시
		var role: String = t.role
		if role == "move":
			var u := root.size.y / 720.0
			var v := (e.position - _stick_center) / (60.0 * u)
			v = v.limit_length(1.0)
			if v.length() < 0.12:
				v = Vector2.ZERO
			move_vec = Vector2(v.x, -v.y)
		elif role == "look":
			look_delta += d
		elif role in ["fire", "fire2", "aim"]:
			# 버튼 위에서는 손가락이 조금 떨려도 시점이 돌지 않게 여유를 둔다
			if not t.moved:
				if (e.position - t.start).length() < 14.0:
					return
				t.moved = true
			look_delta += d


func _touch_down(idx: int, pos: Vector2) -> void:
	if OS.get_cmdline_user_args().has("--touchtest"):
		print("  down ", idx, " ", pos)
	_layout_buttons()
	if _touches.has(idx):
		_touch_up(idx)
	# 일시정지 / 무기 칸
	if pause_btn.get_global_rect().grow(10).has_point(pos):
		_touches[idx] = {"role": "ui", "pos": pos, "start": pos, "moved": false}
		pause_requested.emit()
		return
	if slots_box.visible:
		for i in slot_btns.size():
			var b := slot_btns[i]
			if b.visible and b.get_global_rect().grow(6).has_point(pos):
				_touches[idx] = {"role": "ui", "pos": pos, "start": pos, "moved": false}
				slot_tapped.emit(i)
				return
	var best := ""
	var best_d := INF
	for kk in _btn:
		var bb: Dictionary = _btn[kk]
		var dd: float = pos.distance_to(bb.pos) / bb.r
		if dd <= 1.3 and dd < best_d:
			best_d = dd
			best = kk
	if best != "":
		var k := best
		_touches[idx] = {"role": k, "pos": pos, "start": pos, "moved": false}
		_buzz(12)
		match k:
			"fire", "fire2":
				fire_held = true
			"aim":
				aim_toggle = not aim_toggle
			"jump":
				jump_tap = true
			"slide":
				slide_tap = true
			"reload":
				reload_tap = true
			"swap":
				slot_tapped.emit(-1)
		return
	if pos.x < root.size.x * 0.45:
		_touches[idx] = {"role": "move", "pos": pos, "start": pos, "moved": false}
		_stick_center = pos
		_stick_active = true
		move_vec = Vector2.ZERO
	else:
		_touches[idx] = {"role": "look", "pos": pos, "start": pos, "moved": false}


func _touch_up(idx: int) -> void:
	if OS.get_cmdline_user_args().has("--touchtest"):
		print("  up ", idx, " ", _touches.get(idx, {}).get("role", "-"))
	if not _touches.has(idx):
		return
	var role: String = _touches[idx].role
	_touches.erase(idx)
	if role == "move":
		move_vec = Vector2.ZERO
		_stick_active = false
	if role.begins_with("fire"):
		fire_held = false
		for t in _touches.values():
			if t.role.begins_with("fire"):
				fire_held = true


func _buzz(ms: int) -> void:
	if Game.haptics:
		Input.vibrate_handheld(ms)


func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d


func reset_touch() -> void:
	_touches.clear()
	move_vec = Vector2.ZERO
	fire_held = false
	aim_toggle = false
	_stick_active = false
