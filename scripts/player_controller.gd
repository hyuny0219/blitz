class_name PlayerController
extends Node
## 키보드·마우스 + 터치(HUD) 입력을 Fighter 입력으로 변환

var me: Fighter
var hud: Hud
var m: Node
var _aim_hold := false


func setup(f: Fighter, h: Hud, match_node: Node) -> void:
	me = f
	hud = h
	m = match_node
	hud.slot_tapped.connect(_on_slot)


func _on_slot(i: int) -> void:
	if not m.running and not m.warmup:
		return
	if i < 0:
		me.cycle(1)
	else:
		me.switch_to(i)


func _unhandled_input(event: InputEvent) -> void:
	if m.paused:
		return
	if event is InputEventMouseButton and event.pressed and not Game.is_touch:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				me.cycle(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				me.cycle(1)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * 0.0022 * Game.sensitivity)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: me.switch_to(0)
			KEY_2: me.switch_to(1)
			KEY_3: me.switch_to(2)
			KEY_4: me.switch_to(3)
			KEY_Q: me.switch_to(me.prev_slot)
			KEY_R: me.start_reload()
			KEY_ESCAPE, KEY_P:
				m.toggle_pause()


func _look(rel: Vector2) -> void:
	var fov_k := 1.0
	if me.cam:
		fov_k = me.cam.fov / 80.0
	me.yaw -= rel.x * fov_k
	me.pitch = clampf(me.pitch - rel.y * fov_k, -1.45, 1.45)


func _physics_process(_delta: float) -> void:
	if me == null:
		return
	var active: bool = (m.running or m.warmup) and not m.paused and me.alive
	if not active:
		me.in_move = Vector2.ZERO
		me.in_fire = false
		me.in_aim = false
		if hud:
			hud.consume_look()
		return
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.y -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1
	mv += hud.move_vec
	me.in_move = mv.limit_length(1.0)
	if m.warmup:
		me.in_move = Vector2.ZERO
	if Input.is_key_pressed(KEY_SPACE) or hud.jump_tap:
		me.in_jump = true
	hud.jump_tap = false
	if hud.reload_tap:
		me.start_reload()
		hud.reload_tap = false
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var fire := hud.fire_held or (captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if not m.running:
		fire = false
	me.in_fire = fire
	me.in_aim = hud.aim_toggle or (captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	var ld := hud.consume_look()
	if ld != Vector2.ZERO:
		_look(ld * 0.0042 * Game.sensitivity)
	# 저격 후 조준 자동 해제(터치)
	if hud.aim_toggle and me.wdata().kind != "sniper" and me.wdata().kind in ["knife", "grenade"]:
		hud.aim_toggle = false
