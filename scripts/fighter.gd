class_name Fighter
extends CharacterBody3D
## 플레이어와 봇이 함께 쓰는 전투원. 입력(in_*)은 컨트롤러(플레이어/봇)가 채운다.

signal died(victim: Fighter, killer: Fighter, wid: String, head: bool)
signal damaged(victim: Fighter, attacker: Fighter, amount: float, head: bool)

const GRAVITY := 18.0
const JUMP_VEL := 6.4
const BASE_SPEED := 6.4
const EYE := 1.6

var team := 0
var display_name := ""
var char_id := "blaze"
var is_player := false
var max_health := 100.0
var health := 100.0
var alive := true
var slots: Array = ["m4a4", "glock", "knife", "he"]
var cur := 0
var prev_slot := 0
var ammo := {}
var util_left := 1
var yaw := 0.0
var pitch := 0.0
var kills := 0
var deaths := 0
var gun_level := 0
var aim_error := 0.0   # 봇 조준 오차(도)

# 입력
var in_move := Vector2.ZERO
var in_jump := false
var in_slide := false   # 한 번 누르면 슬라이드 시도 (사용 후 자동 해제)
var slide_t := 0.0
var slide_cd := 0.0
var _slide_k := 0.0     # 0~1 자세 보간
var _col_shape: CapsuleShape3D
var _col_node: CollisionShape3D
const SLIDE_TIME := 0.75
var in_fire := false
var in_aim := false
var _fire_prev := false

var head: Node3D
var cam: Camera3D
var model: CharacterModel
var viewmodel: Viewmodel
var third_gun: Node3D
var tag: Label3D
var match_ref: Node

var fire_cd := 0.0
var reload_t := 0.0
var switch_t := 0.0
var recoil := 0.0
var recoil_idle := 0.0
var view_kick := 0.0
var scoped := false
var flashed := 0.0
var invuln := 0.0
var step_t := 0.0
var last_attacker: Fighter
var last_damage_dir := Vector3.ZERO
var _eye_prev := Vector3.ZERO
var _eye_cur := Vector3.ZERO


func setup(p_team: int, p_name: String, p_char: String, p_slots: Array, p_player: bool, m: Node) -> void:
	team = p_team
	display_name = p_name
	char_id = p_char
	slots = p_slots.duplicate()
	is_player = p_player
	match_ref = m
	add_to_group("fighter")
	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	platform_floor_layers = 0
	platform_wall_layers = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_col_shape = cap
	_col_node = cs
	model = CharacterModel.new()
	add_child(model)
	model.build(char_id)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	if is_player:
		cam = Camera3D.new()
		cam.fov = 80
		cam.near = 0.04
		cam.far = 300
		add_child(cam)
		cam.top_level = true
		cam.current = true
		viewmodel = Viewmodel.new()
		cam.add_child(viewmodel)
		viewmodel.setup(Data.character(char_id))
		model.set_shadow_only()
	else:
		tag = Label3D.new()
		tag.text = display_name
		tag.pixel_size = 0.004
		tag.font_size = 40
		tag.outline_size = 10
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position.y = 2.15
		tag.modulate = Color(0.5, 0.8, 1.0)
		add_child(tag)
	reset_for_round()


func set_tag_color(c: Color) -> void:
	if tag:
		tag.modulate = c


func reset_for_round() -> void:
	health = max_health
	alive = true
	collision_layer = 2
	ammo.clear()
	for w in slots:
		var d := Data.weapon(w)
		ammo[w] = [int(d.mag), int(d.reserve)]
	util_left = 1
	reload_t = 0.0
	fire_cd = 0.0
	recoil = 0.0
	view_kick = 0.0
	scoped = false
	flashed = 0.0
	invuln = 1.0
	velocity = Vector3.ZERO
	slide_t = 0.0
	slide_cd = 0.0
	_slide_k = 0.0
	if _col_shape:
		_set_low(false)
	if head:
		head.position.y = EYE
	model.visible = true
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	if tag:
		tag.visible = true
	cur = 0
	_equip(0, true)


func set_slots(p_slots: Array) -> void:
	slots = p_slots.duplicate()
	for w in slots:
		if not ammo.has(w):
			var d := Data.weapon(w)
			ammo[w] = [int(d.mag), int(d.reserve)]
	_equip(cur if cur < slots.size() else 0, true)


func wid() -> String:
	return slots[cur]


func wdata() -> Dictionary:
	return Data.weapon(slots[cur])


# ------------------------------------------------------------ 무기 교체
func switch_to(i: int) -> void:
	if i < 0 or i >= slots.size() or i == cur or not alive:
		return
	if Data.weapon(slots[i]).kind == "grenade" and util_left <= 0:
		return
	prev_slot = cur
	_equip(i, false)


func cycle(dir: int) -> void:
	var n := slots.size()
	var i := cur
	for k in n:
		i = (i + dir + n) % n
		if Data.weapon(slots[i]).kind == "grenade" and util_left <= 0:
			continue
		switch_to(i)
		return


func _equip(i: int, instant: bool) -> void:
	cur = i
	reload_t = 0.0
	scoped = false
	switch_t = 0.0 if instant else 0.35
	if third_gun:
		third_gun.queue_free()
		third_gun = null
	third_gun = WeaponModel.build(wid())
	model.gun_holder.add_child(third_gun)
	if is_player:
		third_gun.visible = false
		viewmodel.set_weapon(wid(), instant)
		if not instant:
			Sfx.play("swap", -8.0)


# ------------------------------------------------------------ 물리
func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	flashed = maxf(0.0, flashed - delta)
	fire_cd -= delta
	switch_t = maxf(0.0, switch_t - delta)
	recoil_idle += delta
	if recoil_idle > 0.12:
		recoil = move_toward(recoil, 0.0, delta * 9.0)
	view_kick = lerpf(view_kick, 0.0, minf(1.0, delta * 10.0))

	if not alive:
		velocity.x = move_toward(velocity.x, 0, delta * 20)
		velocity.z = move_toward(velocity.z, 0, delta * 20)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()

	var w := wdata()
	rotation.y = yaw
	head.rotation.x = pitch + deg_to_rad(view_kick)
	var spd: float = BASE_SPEED * float(w.get("speed", 1.0))
	if scoped:
		spd *= 0.5
	var mv := in_move.limit_length(1.0)
	var dir := Basis(Vector3.UP, yaw) * Vector3(mv.x, 0, -mv.y)
	var target := dir * spd
	slide_cd = maxf(0.0, slide_cd - delta)
	var hs0 := Vector2(velocity.x, velocity.z).length()
	# 슬라이드 시작: 바닥에서 움직이는 중일 때
	if in_slide and slide_t <= 0.0 and slide_cd <= 0.0 and is_on_floor() and (hs0 > 2.5 or mv.length() > 0.3):
		var sd := Vector3(velocity.x, 0, velocity.z).normalized() if hs0 > 2.5 else dir.normalized()
		var sp := maxf(hs0 * 1.6, 12.0)
		velocity.x = sd.x * sp
		velocity.z = sd.z * sp
		slide_t = SLIDE_TIME
		_set_low(true)
		if is_player:
			Sfx.play("slide", -4.0)
		else:
			Sfx.play_at("slide", global_position, -2.0)
	in_slide = false
	if slide_t > 0.0:
		# 미끄러지는 중: 방향 고정, 서서히 감속
		slide_t -= delta
		var hv := Vector2(velocity.x, velocity.z)
		hv = hv.move_toward(Vector2.ZERO, 6.5 * delta)
		velocity.x = hv.x
		velocity.z = hv.y
		if slide_t <= 0.0 or hv.length() < 3.0:
			_end_slide()
	else:
		var accel := 16.0 if is_on_floor() else 4.0
		var hcur := Vector2(velocity.x, velocity.z)
		if (not is_on_floor() or in_jump) and hcur.length() > spd:
			# 슬라이드 점프 등으로 빠를 때 공중에서는 속도를 천천히만 잃음
			var keep := hcur.length() - 3.0 * delta
			hcur = (hcur + Vector2(target.x, target.z) * delta * 3.0).limit_length(keep)
			velocity.x = hcur.x
			velocity.z = hcur.y
		else:
			velocity.x = move_toward(velocity.x, target.x, accel * spd * delta)
			velocity.z = move_toward(velocity.z, target.z, accel * spd * delta)
	if is_on_floor():
		if in_jump:
			velocity.y = JUMP_VEL
			if slide_t > 0.0:
				# 슬라이드 점프: 속도를 살짝 더해서 유지한 채 점프
				velocity.x *= 1.1
				velocity.z *= 1.1
				_end_slide()
			if is_player:
				Sfx.play("jump", -10.0)
	else:
		velocity.y -= GRAVITY * delta
	in_jump = false
	move_and_slide()
	# 자세(카메라 높이·모델 기울기)
	_slide_k = move_toward(_slide_k, 1.0 if slide_t > 0.0 else 0.0, delta * 8.0)
	head.position.y = lerpf(EYE, 0.95, _slide_k)
	model.position.y = -0.12 * _slide_k
	model.rotation.x = 0.55 * _slide_k

	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 2.0:
		step_t -= delta * hs / BASE_SPEED
		if step_t <= 0.0:
			step_t = 0.36
			if is_player:
				Sfx.play("step", -16.0, randf_range(0.9, 1.1))
			else:
				Sfx.play_at("step", global_position, -6.0)

	model.animate(delta, clampf(hs / BASE_SPEED, 0.0, 1.0), not is_on_floor(), pitch)
	if is_player:
		_eye_prev = _eye_cur
		_eye_cur = head.global_position

	# 조준
	var can_scope: bool = int(w.scope) > 0
	if can_scope and in_aim and switch_t <= 0.0 and reload_t <= 0.0:
		scoped = true
	elif not in_aim:
		scoped = false

	# 발사
	var pressed := in_fire and not _fire_prev
	_fire_prev = in_fire
	if in_fire and flashed < 0.6:
		_try_fire(pressed)

	if is_player:
		viewmodel.update_motion(delta, clampf(hs / BASE_SPEED, 0.0, 1.0), is_on_floor(), scoped, _slide_k)
		var target_fov := 80.0
		if scoped:
			target_fov = float(w.scope)
		elif in_aim and w.kind != "grenade" and w.kind != "knife":
			target_fov = 68.0
		cam.fov = lerpf(cam.fov, target_fov, minf(1.0, delta * 18.0))


## 플레이어 카메라: 물리 틱 사이를 보간하고 회전은 매 프레임 적용 (끊김 방지)
func _process(_delta: float) -> void:
	if not is_player or cam == null:
		return
	var f := Engine.get_physics_interpolation_fraction()
	if alive:
		cam.global_position = _eye_prev.lerp(_eye_cur, f)
	else:
		cam.global_position = head.global_position
	cam.global_rotation = Vector3(pitch + deg_to_rad(view_kick), yaw, 0.0)


func snap_camera() -> void:
	if head:
		_eye_prev = head.global_position
		_eye_cur = _eye_prev


func _set_low(low: bool) -> void:
	_col_shape.height = 1.1 if low else 1.8
	_col_node.position.y = 0.55 if low else 0.9


func _end_slide() -> void:
	slide_t = 0.0
	slide_cd = 0.45
	_set_low(false)


func is_sliding() -> bool:
	return slide_t > 0.0


func move_frac() -> float:
	return clampf(Vector2(velocity.x, velocity.z).length() / BASE_SPEED, 0.0, 1.0)


# ------------------------------------------------------------ 사격
func _try_fire(pressed: bool) -> void:
	var w := wdata()
	if switch_t > 0.0 or fire_cd > 0.0:
		return
	if w.kind == "knife":
		_melee(w)
		return
	if w.kind == "grenade":
		if pressed:
			_throw(w)
		return
	if reload_t > 0.0:
		return
	if not w.auto and not pressed:
		return
	var a: Array = ammo[wid()]
	if a[0] <= 0:
		if pressed or w.auto:
			if is_player:
				Sfx.play("empty", -4.0)
			else:
				Sfx.play_at("empty", global_position, -4.0)
			fire_cd = 0.25
			start_reload()
		return
	a[0] -= 1
	fire_cd = 60.0 / float(w.rpm)
	recoil_idle = 0.0
	var origin := head.global_position
	var fwd := -head.global_basis.z
	var right := head.global_basis.x
	var up := head.global_basis.y
	var spread: float = float(w.spread) + float(w.move_spread) * move_frac() + (4.0 if not is_on_floor() else 0.0) + recoil * 0.3
	if w.kind == "sniper":
		if scoped:
			spread = 0.04 + float(w.move_spread) * move_frac() * 0.6 + (4.0 if not is_on_floor() else 0.0)
		else:
			spread = float(w.spread) + float(w.move_spread) * move_frac()
	elif in_aim and is_player:
		spread *= 0.75
	spread += aim_error
	var pellets: int = int(w.pellets)
	var hit_any := false
	var muzzle := _muzzle_pos()
	for p in pellets:
		var r := deg_to_rad(spread * sqrt(randf()))
		var ang := randf() * TAU
		var d := (fwd + right * tan(r) * cos(ang) + up * (tan(r) * sin(ang) + deg_to_rad(recoil * 0.2))).normalized()
		var res := _ray(origin, origin + d * 160.0)
		var end := origin + d * 160.0
		if res:
			end = res.position
			var col = res.collider
			if col is Fighter and col != self:
				var f: Fighter = col
				var is_head: bool = (res.position.y - f.global_position.y) > (0.78 if f.is_sliding() else 1.47)
				var dist := origin.distance_to(res.position)
				var dmg: float = float(w.dmg) * pow(float(w.falloff), dist / 25.0)
				if is_head:
					dmg *= float(w.head)
				if f.alive and match_ref.can_damage(self, f):
					f.take_damage(dmg, self, is_head, wid(), origin)
					hit_any = true
				Effects.burst(get_parent(), res.position, Data.character(f.char_id).accent, 6, 3.0, 0.05, 0.3)
			else:
				Effects.impact(get_parent(), res.position, res.normal)
		if p < 3:
			Effects.tracer(get_parent(), muzzle, end)
	recoil += float(w.recoil)
	if is_player:
		view_kick += float(w.recoil) * (0.22 if Game.is_touch else 0.4)
		viewmodel.on_fire(float(w.recoil))
		Sfx.play(Sfx.gun_sound(w.kind, wid()), -2.0)
	else:
		Sfx.play_at(Sfx.gun_sound(w.kind, wid()), muzzle, 2.0)
	if w.kind == "sniper" and is_player:
		scoped = false
	if a[0] <= 0 and is_player:
		start_reload()


func _muzzle_pos() -> Vector3:
	if is_player and viewmodel:
		return viewmodel.muzzle_global()
	if third_gun:
		var m := third_gun.get_node_or_null("muzzle")
		if m:
			return m.global_position
	return head.global_position


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 2, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


func _melee(w: Dictionary) -> void:
	fire_cd = 60.0 / float(w.rpm)
	if is_player:
		viewmodel.on_fire(0.0)
		Sfx.play("swing", -4.0)
	else:
		Sfx.play_at("swing", global_position, -2.0)
	var origin := head.global_position
	var fwd := -head.global_basis.z
	for off in [Vector3.ZERO, head.global_basis.x * 0.25, -head.global_basis.x * 0.25, Vector3(0, -0.4, 0)]:
		var res := _ray(origin, origin + (fwd * float(w.get("range", 2.4))) + off)
		if res and res.collider is Fighter and res.collider != self:
			var f: Fighter = res.collider
			if f.alive and match_ref.can_damage(self, f):
				var dmg: float = float(w.dmg)
				var back := (-f.global_basis.z).dot(fwd) > 0.5
				if back:
					dmg *= 2.0
				f.take_damage(dmg, self, back, wid(), origin)
				Effects.burst(get_parent(), res.position, Data.character(f.char_id).accent, 10, 3.0, 0.05, 0.3)
			return
		elif res and off == Vector3.ZERO:
			Effects.impact(get_parent(), res.position, res.normal, Color(0.9, 0.9, 1.0))
			return


func _throw(w: Dictionary) -> void:
	if util_left <= 0:
		return
	util_left -= 1
	fire_cd = 0.6
	var g := Grenade.new()
	get_parent().add_child(g)
	var fwd := -head.global_basis.z
	g.global_position = head.global_position + fwd * 0.6 + Vector3(0, -0.1, 0)
	g.setup(wid(), self, fwd * 15.0 + Vector3.UP * 3.0 + velocity * 0.4)
	if is_player:
		viewmodel.on_fire(0.0)
		Sfx.play("swing", -6.0)
	ammo[wid()][0] = 0
	# 이전 무기로 복귀
	var back := prev_slot if prev_slot != cur else 0
	_equip(back, false)


func start_reload() -> void:
	var w := wdata()
	if w.kind in ["knife", "grenade"] or reload_t > 0.0:
		return
	var a: Array = ammo[wid()]
	if a[0] >= int(w.mag) or a[1] <= 0:
		return
	reload_t = float(w.reload)
	scoped = false
	if is_player:
		viewmodel.on_reload(reload_t)
		Sfx.play("reload", -6.0)
	else:
		Sfx.play_at("reload", global_position, -8.0)


func _finish_reload() -> void:
	var w := wdata()
	var a: Array = ammo[wid()]
	var need: int = int(w.mag) - a[0]
	var take: int = mini(need, a[1])
	a[0] += take
	a[1] -= take


# ------------------------------------------------------------ 피해
func take_damage(amount: float, attacker: Fighter, is_head: bool, weapon_id: String, from: Vector3) -> void:
	if not alive or invuln > 0.0:
		return
	health -= amount
	last_attacker = attacker
	last_damage_dir = (from - global_position)
	model.flash()
	damaged.emit(self, attacker, amount, is_head)
	if is_player:
		Sfx.play("hurt", -4.0)
	if health <= 0.0:
		health = 0.0
		die(attacker, weapon_id, is_head)


func die(killer: Fighter, weapon_id: String, is_head: bool) -> void:
	if not alive:
		return
	alive = false
	deaths += 1
	collision_layer = 0
	scoped = false
	reload_t = 0.0
	in_fire = false
	if tag:
		tag.visible = false
	var c := Data.character(char_id)
	Effects.burst(get_parent(), global_position + Vector3.UP * 1.0, c.accent, 36, 7.0, 0.1, 0.9)
	Effects.burst(get_parent(), global_position + Vector3.UP * 1.0, c.main, 20, 5.0, 0.12, 0.7)
	if not is_player:
		var tw := model.create_tween()
		tw.tween_property(model, "rotation:x", -PI / 2, 0.35).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(model, "position:y", 0.2, 0.35)
		tw.tween_interval(1.2)
		tw.tween_property(model, "scale", Vector3(1, 0.01, 1), 0.2)
		tw.tween_callback(func(): model.visible = false; model.scale = Vector3.ONE)
	else:
		viewmodel.visible = false
	died.emit(self, killer, weapon_id, is_head)


func respawn_at(pos: Vector3, face_yaw: float) -> void:
	global_position = pos
	yaw = face_yaw
	pitch = 0.0
	rotation.y = yaw
	reset_for_round()
	snap_camera()
	if is_player:
		viewmodel.visible = true


func apply_flash(strength: float) -> void:
	flashed = maxf(flashed, strength)
