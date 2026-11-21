class_name Menu
extends Control
## 메인 메뉴: 플레이(모드/맵/난이도), 캐릭터, 무기(로드아웃), 설정

signal play_requested

var tab := "play"
var content: Control
var keys_lbl: Label
var tab_btns := {}
var preview_vp: SubViewport
var preview_model: CharacterModel
var preview_pivot: Node3D
var preview_char := ""
var _sel_weapon := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme
	# 배경
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/ui/keyart.jpg"):
		bg.texture = load("res://assets/ui/keyart.jpg")
	add_child(bg)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.05, 0.1, 0.55 if bg.texture else 1.0)
	add_child(shade)
	if bg.texture == null:
		var grad := ColorRect.new()
		grad.set_anchors_preset(Control.PRESET_FULL_RECT)
		var gm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type canvas_item; void fragment(){ vec2 u=UV; COLOR=vec4(mix(vec3(0.06,0.09,0.18),vec3(0.18,0.08,0.12),u.x)+0.05*sin(u.y*40.0+u.x*10.0),1.0);}"
		gm.shader = sh
		grad.material = gm
		add_child(grad)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	# 상단바
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	var logo := UiKit.label("BLITZ", 44, Color(1.0, 0.75, 0.25), true)
	logo.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	logo.add_theme_constant_override("outline_size", 10)
	top.add_child(logo)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	for t in [["play", "플레이"], ["chars", "캐릭터"], ["arms", "무기"], ["settings", "설정"]]:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(118, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
		var id: String = t[0]
		b.pressed.connect(func(): _set_tab(id))
		top.add_child(b)
		tab_btns[id] = b
	var kp := PanelContainer.new()
	top.add_child(kp)
	keys_lbl = UiKit.label("", 24, Color(1.0, 0.85, 0.35))
	kp.add_child(keys_lbl)

	var ver := UiKit.label("v" + BuildInfo.VERSION, 14, Color(1, 1, 1, 0.45))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -140
	ver.offset_top = -26
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	content = Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(content)
	_build_preview()
	_set_tab("play")


func _process(_d: float) -> void:
	keys_lbl.text = "🔑 %d" % Game.keys
	if preview_pivot:
		preview_pivot.rotation.y += _d * 0.6
		if preview_model:
			preview_model.animate(_d, 0.0, false, 0.0)


func _set_tab(t: String) -> void:
	tab = t
	Sfx.play("click", -10.0)
	for k in tab_btns:
		var b: Button = tab_btns[k]
		var on: bool = k == t
		b.add_theme_stylebox_override("normal", UiKit.style(Color(1.0, 0.6, 0.15, 0.95) if on else Color(0.1, 0.13, 0.2, 0.85), 12))
		b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.1) if on else Color.WHITE)
	for c in content.get_children():
		if c.has_meta("preview"):
			c.visible = false
			continue
		c.queue_free()
	match t:
		"play": _tab_play()
		"chars": _tab_chars()
		"arms": _tab_arms()
		"settings": _tab_settings()


func _fill(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.add_child(c)


# ------------------------------------------------------------- 3D 미리보기
func _build_preview() -> void:
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_meta("preview", true)
	svc.visible = false
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(svc)
	preview_vp = SubViewport.new()
	preview_vp.transparent_bg = true
	preview_vp.own_world_3d = true
	preview_vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(preview_vp)
	var w := Node3D.new()
	preview_vp.add_child(w)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, 3.1)
	cam.fov = 36
	w.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-35, 30, 0)
	l.light_energy = 1.3
	w.add_child(l)
	var l2 := DirectionalLight3D.new()
	l2.rotation_degrees = Vector3(-20, 200, 0)
	l2.light_energy = 0.6
	l2.light_color = Color(0.6, 0.8, 1.0)
	w.add_child(l2)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	w.add_child(env)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.8
	cm.bottom_radius = 0.85
	cm.height = 0.08
	disc.mesh = cm
	disc.position.y = -0.04
	disc.material_override = Mats.color_mat(Color(0.95, 0.5, 0.12), 0.25, 0.3, 0.3)
	w.add_child(disc)
	preview_pivot = Node3D.new()
	w.add_child(preview_pivot)


func _show_preview(rect: Rect2, char_id: String, wid: String = "") -> void:
	var svc: SubViewportContainer = preview_vp.get_parent()
	svc.visible = true
	svc.position = rect.position
	svc.size = rect.size
	content.move_child(svc, -1)
	if char_id != preview_char or wid != _sel_weapon:
		preview_char = char_id
		_sel_weapon = wid
		if preview_model:
			preview_model.queue_free()
		preview_model = CharacterModel.new()
		preview_pivot.add_child(preview_model)
		preview_model.build(char_id)
		var g := WeaponModel.build(wid if wid != "" else Game.loadout.primary)
		preview_model.gun_holder.add_child(g)


# ------------------------------------------------------------- 플레이
func _tab_play() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_fill(h)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	h.add_child(left)
	left.add_child(UiKit.label("모드", 22, Color(1.0, 0.8, 0.4), true))
	var mg := GridContainer.new()
	mg.columns = 3
	mg.add_theme_constant_override("h_separation", 10)
	mg.add_theme_constant_override("v_separation", 10)
	left.add_child(mg)
	for mid in Data.MODE_ORDER:
		var b := _choice_btn(Data.MODES[mid].name, Game.mode == mid, Vector2(200, 56))
		b.pressed.connect(func(): Game.mode = mid; Game.save(); _set_tab("play"))
		mg.add_child(b)
	left.add_child(UiKit.label("맵", 22, Color(1.0, 0.8, 0.4), true))
	var gg := GridContainer.new()
	gg.columns = 3
	gg.add_theme_constant_override("h_separation", 10)
	gg.add_theme_constant_override("v_separation", 10)
	left.add_child(gg)
	for map_id in Data.MAP_ORDER:
		gg.add_child(_map_card(map_id))
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 10)
	left.add_child(dr)
	dr.add_child(UiKit.label("봇 난이도", 22, Color(1.0, 0.8, 0.4), true))
	for i in Data.DIFFICULTY.size():
		var b := _choice_btn(Data.DIFFICULTY[i].name, Game.difficulty == i, Vector2(110, 50))
		var ii := i
		b.pressed.connect(func(): Game.difficulty = ii; Game.save(); _set_tab("play"))
		dr.add_child(b)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(330, 330)
	right.add_child(spacer)
	var c := Data.character(Game.character)
	var nm := UiKit.label("%s · %s" % [c.name, c.role], 24, c.accent, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(nm)
	var lo := UiKit.label("%s / %s / %s" % [Data.weapon(Game.loadout.primary).name, Data.weapon(Game.loadout.secondary).name, Data.weapon(Game.loadout.utility).name], 16, Color(0.8, 0.85, 0.95))
	lo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(lo)
	var start := UiKit.big_button("게임 시작", Color(1.0, 0.6, 0.15), Vector2(330, 76))
	start.add_theme_font_size_override("font_size", 34)
	start.pressed.connect(func(): play_requested.emit())
	right.add_child(start)
	await get_tree().process_frame
	if is_instance_valid(spacer):
		_show_preview(Rect2(spacer.global_position - content.global_position, spacer.size), Game.character)


func _choice_btn(text: String, on: bool, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	if on:
		b.add_theme_stylebox_override("normal", UiKit.style(Color(1.0, 0.6, 0.15, 0.95), 12, Color(1, 0.9, 0.6), 3))
		b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.1))
	b.pressed.connect(func(): Sfx.play("click", -10.0))
	return b


func _map_card(map_id: String) -> Button:
	var info: Dictionary = Data.MAPS[map_id]
	var on := Game.map_id == map_id
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 92)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var sb := UiKit.style(info.sky_top.darkened(0.25), 12, Color(1.0, 0.75, 0.3) if on else Color(1, 1, 1, 0.15), 4 if on else 2)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var thumb_path := "res://assets/ui/map_%s.jpg" % map_id
	if ResourceLoader.exists(thumb_path):
		var tr := TextureRect.new()
		tr.texture = load(thumb_path)
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.modulate = Color(1, 1, 1, 1.0 if on else 0.75)
		b.add_child(tr)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.offset_left = 10
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var n := UiKit.label(info.name, 22, Color.WHITE, true)
	n.add_theme_color_override("font_outline_color", Color.BLACK)
	n.add_theme_constant_override("outline_size", 6)
	v.add_child(n)
	var d := UiKit.label(info.desc, 14, Color(0.9, 0.92, 1.0))
	d.add_theme_color_override("font_outline_color", Color.BLACK)
	d.add_theme_constant_override("outline_size", 4)
	v.add_child(d)
	b.pressed.connect(func(): Sfx.play("click", -10.0); Game.map_id = map_id; Game.save(); _set_tab("play"))
	return b


# ------------------------------------------------------------- 캐릭터
func _tab_chars() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_fill(h)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(grid)
	var sel := preview_char if preview_char != "" else Game.character
	if not Data.CHARACTERS.has(sel):
		sel = Game.character
	for cid in Data.CHARACTER_ORDER:
		var c: Dictionary = Data.CHARACTERS[cid]
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 130)
		b.focus_mode = Control.FOCUS_NONE
		var on: bool = cid == sel
		var sb := UiKit.style(c.main.darkened(0.45), 14, c.accent if on else Color(1, 1, 1, 0.12), 4 if on else 2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		var portrait := "res://assets/ui/char_%s.jpg" % cid
		if ResourceLoader.exists(portrait):
			var tr := TextureRect.new()
			tr.texture = load(portrait)
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_END
		v.offset_left = 10
		v.offset_bottom = -6
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var n := UiKit.label(c.name, 24, Color.WHITE, true)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_constant_override("outline_size", 6)
		v.add_child(n)
		var st: String = c.role
		if not Game.is_unlocked(cid):
			st = "🔒 %d" % int(c.keys)
		elif cid == Game.character:
			st = "✔ 사용 중"
		var r := UiKit.label(st, 15, c.accent)
		r.add_theme_color_override("font_outline_color", Color.BLACK)
		r.add_theme_constant_override("outline_size", 4)
		v.add_child(r)
		b.pressed.connect(func(): Sfx.play("click", -10.0); preview_char = cid; _set_tab("chars"))
		grid.add_child(b)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(340, 0)
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(340, 330)
	right.add_child(spacer)
	var c2 := Data.character(sel)
	var t := UiKit.label("%s  ·  %s" % [c2.name, c2.role], 26, c2.accent, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(t)
	var d := UiKit.label(c2.desc, 18, Color(0.85, 0.88, 0.95))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(d)
	if Game.is_unlocked(sel):
		var use := UiKit.big_button("사용 중" if sel == Game.character else "선택하기", Color(0.25, 0.75, 0.45), Vector2(340, 64))
		use.disabled = sel == Game.character
		use.pressed.connect(func(): Game.character = sel; Game.save(); _set_tab("chars"))
		right.add_child(use)
	else:
		var buy := UiKit.big_button("🔑 %d 로 해금" % int(c2.keys), Color(1.0, 0.6, 0.15), Vector2(340, 64))
		buy.pressed.connect(func():
			if Game.try_unlock(sel):
				Sfx.play("unlock", -4.0)
				Game.character = sel
				Game.save()
			else:
				Sfx.play("empty", -4.0)
			_set_tab("chars"))
		right.add_child(buy)
	await get_tree().process_frame
	if is_instance_valid(spacer):
		var force := preview_char
		preview_char = ""
		_show_preview(Rect2(spacer.global_position - content.global_position, spacer.size), sel)
		preview_char = sel if force != "" else sel


# ------------------------------------------------------------- 무기
func _tab_arms() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_fill(h)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	if _sel_weapon == "" or not Data.WEAPONS.has(_sel_weapon):
		_sel_weapon = Game.loadout.primary
	for row in [["주무기", "primary", Data.PRIMARIES], ["보조무기", "secondary", Data.SECONDARIES], ["근접", "melee", Data.MELEES], ["투척", "utility", Data.UTILITIES]]:
		v.add_child(UiKit.label(row[0], 20, Color(1.0, 0.8, 0.4), true))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for wid in row[2]:
			var w := Data.weapon(wid)
			var equipped: bool = Game.loadout[row[1]] == wid
			var txt: String = w.name
			if not Game.is_unlocked(wid):
				txt = "🔒 %s  %d" % [w.name, int(w.keys)]
			elif equipped:
				txt = "✔ " + w.name
			var b := _choice_btn(txt, wid == _sel_weapon, Vector2(150, 50))
			if equipped and wid != _sel_weapon:
				b.add_theme_stylebox_override("normal", UiKit.style(Color(0.15, 0.4, 0.25, 0.95), 12, Color(0.4, 1.0, 0.6), 2))
			b.pressed.connect(func(): _sel_weapon = wid; _set_tab("arms"))
			flow.add_child(b)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(360, 240)
	right.add_child(spacer)
	var w2 := Data.weapon(_sel_weapon)
	right.add_child(UiKit.label(w2.name, 30, Color(1.0, 0.8, 0.4), true))
	right.add_child(UiKit.label(w2.desc, 17, Color(0.85, 0.88, 0.95)))
	if w2.kind != "grenade":
		var dps: float = float(w2.dmg) * float(w2.pellets)
		right.add_child(UiKit.stat_bar("피해", dps / 120.0))
		right.add_child(UiKit.stat_bar("연사", float(w2.rpm) / 900.0))
		right.add_child(UiKit.stat_bar("정확도", 1.0 - float(w2.spread) / 5.0 if w2.kind != "sniper" else 0.98))
		right.add_child(UiKit.stat_bar("기동성", (float(w2.speed) - 0.75) / 0.4))
		if int(w2.mag) > 0:
			right.add_child(UiKit.label("탄창 %d발 · 재장전 %.1f초" % [int(w2.mag), float(w2.reload)], 16, Color(0.75, 0.8, 0.9)))
	var slot_key: String = ["primary", "secondary", "melee", "utility"][int(w2.slot)]
	if Game.is_unlocked(_sel_weapon):
		var eq := UiKit.big_button("장착 중" if Game.loadout[slot_key] == _sel_weapon else "장착하기", Color(0.25, 0.75, 0.45), Vector2(360, 60))
		eq.disabled = Game.loadout[slot_key] == _sel_weapon
		eq.pressed.connect(func(): Game.loadout[slot_key] = _sel_weapon; Game.save(); _set_tab("arms"))
		right.add_child(eq)
	else:
		var buy := UiKit.big_button("🔑 %d 로 해금" % int(w2.keys), Color(1.0, 0.6, 0.15), Vector2(360, 60))
		buy.pressed.connect(func():
			if Game.try_unlock(_sel_weapon):
				Sfx.play("unlock", -4.0)
				Game.loadout[slot_key] = _sel_weapon
				Game.save()
			else:
				Sfx.play("empty", -4.0)
			_set_tab("arms"))
		right.add_child(buy)
	await get_tree().process_frame
	if is_instance_valid(spacer):
		_show_weapon_preview(Rect2(spacer.global_position - content.global_position, spacer.size), _sel_weapon)


func _show_weapon_preview(rect: Rect2, wid: String) -> void:
	var svc: SubViewportContainer = preview_vp.get_parent()
	svc.visible = true
	svc.position = rect.position
	svc.size = rect.size
	content.move_child(svc, -1)
	if preview_model:
		preview_model.queue_free()
		preview_model = null
	preview_char = ""
	for c in preview_pivot.get_children():
		c.queue_free()
	var g := WeaponModel.build(wid)
	var holder := Node3D.new()
	holder.position = Vector3(0, 1.0, 0)
	holder.rotation.y = PI / 2
	var s := 2.6 if Data.weapon(wid).kind in ["pistol", "knife", "grenade"] else 1.9
	holder.scale = Vector3.ONE * s
	holder.add_child(g)
	preview_pivot.add_child(holder)


# ------------------------------------------------------------- 설정
func _tab_settings() -> void:
	var p := PanelContainer.new()
	_fill(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	v.add_child(UiKit.label("설정", 30, Color(1.0, 0.8, 0.4), true))
	v.add_child(UiKit.slider_row("감도", 0.3, 3.0, Game.sensitivity, func(x): Game.sensitivity = x; Game.save()))
	v.add_child(UiKit.slider_row("소리", 0.0, 1.0, Game.volume, func(x): Game.set_volume(x)))
	v.add_child(UiKit.label("조작법", 24, Color(1.0, 0.8, 0.4), true))
	v.add_child(UiKit.label("📱 폰: 왼쪽 드래그 이동 · 오른쪽 드래그 시점 · 발사/조준/점프/슬라이드/장전 버튼 · 아래 무기 칸 터치로 교체", 18))
	v.add_child(UiKit.label("⌨ PC: WASD 이동 · 마우스 조준 · 좌클릭 발사 · 우클릭 조준 · Space 점프 · C/Shift 슬라이드 · R 장전 · 1~4/휠 무기 · Esc 일시정지", 18))
	var st := Game.stats
	v.add_child(UiKit.label("전적: %d승 %d패 · 처치 %d · 쓰러짐 %d" % [st.wins, st.losses, st.kills, st.deaths], 18, Color(0.8, 0.85, 0.95)))
