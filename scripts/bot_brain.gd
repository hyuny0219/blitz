class_name BotBrain
extends Node
## 봇 AI: 적을 찾아 길찾기로 이동, 보이면 반응시간 후 조준·사격, 좌우 무빙

var me: Fighter
var m: Node
var diff: Dictionary
var agent: NavigationAgent3D
var target: Fighter
var see_t := 0.0
var lost_t := 9.0
var last_seen := Vector3.ZERO
var has_seen := false
var strafe := 1.0
var strafe_t := 0.0
var think_t := 0.0
var burst_t := 0.0
var pause_t := 0.0
var stuck_t := 0.0
var aim_head := false
var nade_t := 0.0
var nade_state := 0
var wander_t := 0.0
var turn_speed := 7.0


func setup(f: Fighter, match_node: Node, d: Dictionary) -> void:
	me = f
	m = match_node
	diff = d
	turn_speed = 4.5 + float(d.accuracy) * 7.0
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.2
	agent.radius = 0.4
	agent.height = 1.8
	agent.avoidance_enabled = false
	f.add_child(agent)
	nade_t = randf_range(6.0, 14.0)


func _physics_process(delta: float) -> void:
	if me == null:
		return
	me.in_fire = false
	me.in_aim = false
	if not me.alive or not m.running:
		me.in_move = Vector2.ZERO
		return
	think_t -= delta
	if think_t <= 0.0 or target == null or not target.alive:
		think_t = 0.2
		_pick_target()
	if target == null:
		_wander(delta)
		return
	var visible := _can_see(target)
	if visible:
		see_t += delta
		lost_t = 0.0
		last_seen = target.global_position
		has_seen = true
	else:
		see_t = 0.0
		lost_t += delta

	# 섬광탄에 맞으면 허둥지둥
	if me.flashed > 0.6:
		me.in_move = Vector2(sin(Time.get_ticks_msec() * 0.003), -0.5)
		me.yaw += delta * 2.0
		return

	var w := me.wdata()
	var dist := me.global_position.distance_to(target.global_position)
	_weapon_logic(w, visible, dist)

	# 조준
	var aim_point := target.global_position + Vector3(0, 1.62 if aim_head else 1.25, 0)
	if not visible:
		aim_point = (last_seen if has_seen else target.global_position) + Vector3(0, 1.4, 0)
		if agent and not agent.is_navigation_finished() and lost_t > 1.0:
			var nx := agent.get_next_path_position()
			aim_point = Vector3(nx.x, me.head.global_position.y, nx.z) + (nx - me.global_position).normalized() * 3.0
	var d := aim_point - me.head.global_position
	var want_yaw := atan2(-d.x, -d.z)
	var want_pitch := atan2(d.y, Vector2(d.x, d.z).length())
	me.yaw = rotate_toward(me.yaw, want_yaw, turn_speed * delta * (1.4 if visible else 0.8))
	me.pitch = move_toward(me.pitch, want_pitch, turn_speed * 0.6 * delta)
	me.aim_error = float(diff.aim_err) * (1.0 + me.move_frac() * 0.8)
	var off := absf(angle_difference(me.yaw, want_yaw))

	# 수류탄
	if nade_state > 0:
		_nade_logic(delta, want_yaw)
		return

	# 사격
	if visible and see_t > float(diff.react) and off < deg_to_rad(8.0):
		if w.kind == "sniper":
			me.in_aim = true
			if see_t > float(diff.react) + 0.35:
				me.in_fire = true
		elif pause_t > 0.0:
			pause_t -= delta
		else:
			me.in_fire = true
			burst_t += delta
			var max_burst := 0.25 if dist > 18.0 else (0.6 if dist > 8.0 else 1.5)
			if burst_t > max_burst:
				burst_t = 0.0
				pause_t = randf_range(0.15, 0.4)
		if not w.auto:
			# 단발 무기는 눌렀다 뗐다
			me.in_fire = me.in_fire and (Engine.get_physics_frames() % 6 < 3)
	else:
		burst_t = 0.0

	# 이동
	if visible:
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe = [-1.0, 1.0, -1.0, 1.0, 0.0][randi() % 5]
			strafe_t = randf_range(0.35, 1.0)
			aim_head = randf() < float(diff.accuracy) * 0.6
			if randf() < 0.12 * float(diff.strafe):
				me.in_jump = true
		var fwd := 0.0
		var pref := _pref_range(w)
		if dist > pref + 4.0:
			fwd = 1.0
		elif dist < pref - 4.0:
			fwd = -0.6
		var s := strafe * float(diff.strafe)
		if w.kind == "sniper" and me.scoped:
			s *= 0.0
		me.in_move = Vector2(s, fwd)
	else:
		_hunt(delta)
		if nade_t <= 0.0 and has_seen and lost_t > 1.0 and lost_t < 6.0 and me.util_left > 0:
			var nd := me.global_position.distance_to(last_seen)
			if nd > 7.0 and nd < 22.0:
				nade_state = 1
				nade_t = randf_range(10.0, 20.0)
	nade_t -= delta


func _pref_range(w: Dictionary) -> float:
	match w.kind:
		"shotgun", "knife": return 3.0
		"smg": return 8.0
		"sniper": return 22.0
		"pistol": return 10.0
	return 13.0


func _weapon_logic(w: Dictionary, visible: bool, dist: float) -> void:
	if w.kind == "grenade" and nade_state == 0:
		me.switch_to(0)
		return
	if w.kind == "knife" and me.slots.size() > 0 and not (dist < 3.0 and visible):
		me.switch_to(0)
		return
	if w.kind in ["knife", "grenade"]:
		return
	var a: Array = me.ammo[me.wid()]
	if a[0] <= 0 and a[1] <= 0:
		me.switch_to(1 if me.cur == 0 else 2)
		return
	if a[0] <= 0:
		if visible and dist < 12.0 and me.cur == 0:
			me.switch_to(1)
		else:
			me.start_reload()
	elif not visible and lost_t > 1.5 and a[0] < int(w.mag) * 0.5:
		me.start_reload()
	elif me.cur != 0 and not visible and lost_t > 2.0:
		var pa: Array = me.ammo[me.slots[0]]
		if pa[0] > 0 or pa[1] > 0:
			me.switch_to(0)


func _nade_logic(delta: float, want_yaw: float) -> void:
	me.in_move = Vector2.ZERO
	if nade_state == 1:
		var slot := me.slots.size() - 1
		if Data.weapon(me.slots[slot]).kind != "grenade" or me.util_left <= 0:
			nade_state = 0
			return
		me.switch_to(slot)
		nade_state = 2
		strafe_t = 0.5
	elif nade_state == 2:
		me.pitch = move_toward(me.pitch, 0.35, delta * 2.0)
		strafe_t -= delta
		if strafe_t <= 0.0 and absf(angle_difference(me.yaw, want_yaw)) < 0.2:
			me.in_fire = true
			nade_state = 3
	else:
		nade_state = 0


func _hunt(delta: float) -> void:
	var goal := last_seen if (has_seen and lost_t < 4.0) else target.global_position
	if agent.target_position.distance_to(goal) > 1.5:
		agent.target_position = goal
	var next := agent.get_next_path_position()
	var dv := next - me.global_position
	dv.y = 0
	if dv.length() < 0.1 or agent.is_navigation_finished():
		if has_seen and lost_t < 4.0:
			has_seen = false
		me.in_move = Vector2.ZERO
		return
	var local := Basis(Vector3.UP, me.yaw).inverse() * dv.normalized()
	me.in_move = Vector2(local.x, -local.z)
	var hs := Vector2(me.velocity.x, me.velocity.z).length()
	if hs < 1.0:
		stuck_t += delta
		if stuck_t > 0.6:
			me.in_jump = true
			stuck_t = 0.0
	else:
		stuck_t = 0.0


func _wander(delta: float) -> void:
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = 3.0
		var rp := NavigationServer3D.map_get_random_point(me.get_world_3d().navigation_map, 1, false)
		agent.target_position = rp
	var next := agent.get_next_path_position()
	var dv := next - me.global_position
	dv.y = 0
	if dv.length() > 0.2:
		var local := Basis(Vector3.UP, me.yaw).inverse() * dv.normalized()
		me.in_move = Vector2(local.x, -local.z) * 0.6
		me.yaw = rotate_toward(me.yaw, atan2(-dv.x, -dv.z), delta * 3.0)
	else:
		me.in_move = Vector2.ZERO


func _pick_target() -> void:
	var best: Fighter = null
	var best_score := INF
	for f in m.fighters:
		if f == me or not f.alive or not m.is_enemy(me, f):
			continue
		var dd := me.global_position.distance_to(f.global_position)
		if _can_see(f):
			dd *= 0.3
		if f == me.last_attacker:
			dd *= 0.5
		if dd < best_score:
			best_score = dd
			best = f
	if best != target:
		see_t = 0.0
	target = best


func _can_see(f: Fighter) -> bool:
	var a := me.head.global_position
	var b := f.global_position + Vector3(0, 1.4, 0)
	var dir := b - a
	if dir.length() > 70.0:
		return false
	# 시야각 (맞으면 뒤도 돌아봄)
	var fwd := -me.global_basis.z
	if fwd.dot(dir.normalized()) < -0.1 and me.last_attacker != f:
		return false
	if m.smoke_blocks(a, b):
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var res := me.get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return true
	var b2 := f.global_position + Vector3(0, 0.8, 0)
	q = PhysicsRayQueryParameters3D.create(a, b2, 1)
	return me.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
