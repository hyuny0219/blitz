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
	var u := s.y / 720.0
	_btn = {
		"fire": {"pos": Vector2(s.x - 170 * u, s.y - 190 * u), "r": 74 * u, "label": "발사"},
		"fire2": {"pos": Vector2(150 * u, s.y - 360 * u), "r": 48 * u, "label": "발사"},
		"aim": {"pos": Vector2(s.x - 330 * u, s.y - 270 * u), "r": 46 * u, "label": "조준"},
		"jump": {"pos": Vector2(s.x - 84 * u, s.y - 330 * u), "r": 50 * u, "label": "점프"},
		"reload": {"pos": Vector2(s.x - 300 * u, s.y - 110 * u), "r": 42 * u, "label": "장전"},
		"swap": {"pos": Vector2(s.x - 84 * u, s.y - 480 * u), "r": 40 * u, "label": "교체"},
		"slide": {"pos": Vector2(s.x - 225 * u, s.y - 400 * u), "r": 44 * u, "label": "슬라이드"},
	}


func _draw_touch() -> void:
	_layout_buttons()
	var font := draw.get_theme_default_font()
	for k in _btn:
		var b: Dictionary = _btn[k]
		var held := false
		for t in _touches.values():
			if t.role == k:
				held = true
		var on: bool = held or (k == "aim" and aim_toggle)
		var bg := Color(1, 0.55, 0.15, 0.55) if on else Color(0.05, 0.07, 0.1, 0.38)
		if k.begins_with("fire"):
			bg = Color(0.95, 0.25, 0.2, 0.65) if held else Color(0.85, 0.2, 0.15, 0.4)
		draw.draw_circle(b.pos, b.r, bg)
		draw.draw_arc(b.pos, b.r, 0, TAU, 40, Color(1, 1, 1, 0.5), 3)
		var fs := int(b.r * (0.32 if b.label.length() > 2 else 0.42))
		var ts := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw.draw_string(font, b.pos + Vector2(-ts.x / 2, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 1, 1, 0.95))
	# 조이스틱
	var u := root.size.y / 720.0
	var base := _stick_center if _stick_active else Vector2(190 * u, root.size.y - 170 * u)
	draw.draw_circle(base, 90 * u, Color(0.05, 0.07, 0.1, 0.3))
	draw.draw_arc(base, 90 * u, 0, TAU, 40, Color(1, 1, 1, 0.35), 3)
	draw.draw_circle(base + move_vec * Vector2(1, -1) * 60 * u, 40 * u, Color(1, 1, 1, 0.5))


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
	for k in _btn:
		var b: Dictionary = _btn[k]
		if pos.distance_to(b.pos) <= b.r * 1.15:
			_touches[idx] = {"role": k, "pos": pos, "start": pos, "moved": false}
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
