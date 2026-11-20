class_name Match
extends Node3D
## 한 경기: 맵 생성, 전투원 배치, 라운드/점수, 수류탄, 일시정지, 결과

signal finished(result: Dictionary)

const TEAM_COL := [Color(0.35, 0.7, 1.0), Color(1.0, 0.35, 0.3)]

var mode_id := "duel1"
var mode: Dictionary
var map_id := "warehouse"
var fighters: Array[Fighter] = []
var player: Fighter
var hud: Hud
var running := false
var warmup := false
var paused := false
var over := false
var scores := [0, 0]
var round_no := 0
var round_time := 0.0
var smokes: Array = []
var respawn_q: Array = []
var _countdown := 0.0
var _last_count := -1
var pause_layer: CanvasLayer
var nav_map: RID
var killer_cam_target: Fighter
var keys_earned := 0


func _ready() -> void:
	add_to_group("match")


func start(p_mode: String, p_map: String) -> void:
	mode_id = p_mode
	mode = Data.MODES[mode_id]
	map_id = p_map
	MapBuilder.build(map_id, self)
	nav_map = get_world_3d().navigation_map
	_spawn_fighters()
	hud = Hud.new()
	add_child(hud)
	hud.setup(self, player)
	hud.pause_requested.connect(toggle_pause)
	var pc := PlayerController.new()
	pc.name = "PlayerController"
	player.add_child(pc)
	pc.setup(player, hud, self)
	_build_pause()
	if OS.get_cmdline_user_args().has("--nohud"):
		hud.visible = false
		player.viewmodel.visible = false
		player.viewmodel.process_mode = Node.PROCESS_MODE_DISABLED
	# 내비게이션 맵 동기화를 한 프레임 기다린 뒤 시작
	await get_tree().physics_frame
	await get_tree().physics_frame
	if mode.type == "duel":
		_start_round()
	else:
		_start_ffa()


func _spawn_fighters() -> void:
	var diff: Dictionary = Data.DIFFICULTY[Game.difficulty]
	var names := Data.BOT_NAMES.duplicate()
	names.shuffle()
	var chars := Data.CHARACTER_ORDER.duplicate()
	chars.erase(Game.character)
	chars.shuffle()
	var plist := []
	if mode.type == "duel":
		var n: int = mode.team_size
		for t in 2:
			for i in n:
				plist.append({"team": t, "player": t == 0 and i == 0})
	else:
		for i in int(mode.players):
			plist.append({"team": i, "player": i == 0})
	var ci := 0
	for e in plist:
		var f := Fighter.new()
		f.name = "Fighter%d" % fighters.size()
		f.position = Vector3(fighters.size() * 3.0 - 15.0, 40.0, 0)
		add_child(f)
		var is_p: bool = e.player
		var ch: String = Game.character if is_p else chars[ci % chars.size()]
		if not is_p:
			ci += 1
		var slots: Array
		if mode.type == "gungame":
			slots = [Data.GUN_GAME[0], "knife"]
		elif is_p:
			slots = [Game.loadout.primary, Game.loadout.secondary, Game.loadout.melee, Game.loadout.utility]
		else:
			slots = [Data.PRIMARIES.pick_random(), Data.SECONDARIES.pick_random(), "knife", ["he", "he", "flash", "smoke"].pick_random()]
		var nm: String = "나" if is_p else str(names[fighters.size() % names.size()])
		f.setup(int(e.team), nm, ch, slots, is_p, self)
		if is_p:
			player = f
		if not is_p or OS.get_cmdline_user_args().has("--botplayer"):
			var bb := BotBrain.new()
			f.add_child(bb)
			bb.setup(f, self, diff)
		f.died.connect(_on_died)
		f.damaged.connect(_on_damaged)
		fighters.append(f)
	for f in fighters:
		if f != player:
			f.set_tag_color(TEAM_COL[0] if not is_enemy(player, f) else TEAM_COL[1])


func is_enemy(a: Fighter, b: Fighter) -> bool:
	if a == b:
		return false
	if mode.type != "duel":
		return true
	return a.team != b.team


func can_damage(a: Fighter, b: Fighter) -> bool:
	return is_enemy(a, b) and (running or mode.type != "duel")


# ------------------------------------------------------------ 듀얼 라운드
func _start_round() -> void:
	round_no += 1
	smokes.clear()
	for n in get_children():
		if n is Grenade:
			n.queue_free()
	var counts := [0, 0]
	for f in fighters:
		var pts := MapBuilder.spawn_points(map_id, f.team, int(mode.team_size))
		var pos: Vector3 = pts[counts[f.team]]
		counts[f.team] += 1
		f.respawn_at(pos, PI if f.team == 0 else 0.0)
	running = false
	warmup = true
	_countdown = 3.0
	_last_count = -1
	round_time = 0.0
	hud.reset_touch()
	var is_match_point: bool = scores[0] == int(mode.win) - 1 or scores[1] == int(mode.win) - 1
	hud.show_center("라운드 %d" % round_no, "매치 포인트!" if is_match_point else "%d점 먼저 따면 승리" % int(mode.win), 1.4)
	_update_score()


func _start_ffa() -> void:
	for f in fighters:
		var pos := _far_spawn(f)
		f.respawn_at(pos, randf() * TAU)
	running = false
	warmup = true
	_countdown = 3.0
	_last_count = -1
	var goal := "%d킬 먼저 달성!" % int(mode.win) if mode.type == "ffa" else "모든 무기로 처치하라!"
	hud.show_center(mode.name, goal, 1.4)
	_update_score()


func _far_spawn(who: Fighter) -> Vector3:
	var best := Vector3(0, 0.2, 0)
	var best_d := -1.0
	for i in 16:
		var p := NavigationServer3D.map_get_random_point(nav_map, 1, true)
		var md := 999.0
		for f in fighters:
			if f != who and f.alive:
				md = minf(md, f.global_position.distance_to(p))
		if md > best_d:
			best_d = md
			best = p
	return best + Vector3(0, 0.3, 0)


func _process(delta: float) -> void:
	if paused or over:
		return
	if warmup:
		_countdown -= delta
		var c := int(ceil(_countdown))
		if c != _last_count and c <= 3 and c > 0 and _countdown < 3.0 - 1.2:
			pass
		if c != _last_count:
			_last_count = c
			if c > 0 and _countdown < 2.0:
				hud.show_center(str(c), "", 0.9, Color(1, 0.85, 0.3))
				Sfx.play("beep", -6.0)
		if _countdown <= 0.0:
			warmup = false
			running = true
			hud.show_center("시작!", "", 0.8, Color(0.5, 1.0, 0.6))
			Sfx.play("go", -4.0)
	if running:
		round_time += delta
	if OS.get_cmdline_user_args().has("--debugpos") and Engine.get_process_frames() % 30 == 0:
		print("pos ", player.global_position, " floor ", player.is_on_floor(), " vel ", player.velocity)
		for ci in player.get_slide_collision_count():
			var col := player.get_slide_collision(ci)
			print("  hit ", col.get_collider(), " n=", col.get_normal(), " at ", col.get_position())
	# 리스폰 대기
	for i in range(respawn_q.size() - 1, -1, -1):
		respawn_q[i].t -= delta
		if respawn_q[i].t <= 0.0:
			var f: Fighter = respawn_q[i].f
			respawn_q.remove_at(i)
			if not over:
				f.respawn_at(_far_spawn(f), randf() * TAU)
	# 연막 만료
	for i in range(smokes.size() - 1, -1, -1):
		smokes[i].t -= delta
		if smokes[i].t <= 0.0:
			smokes.remove_at(i)
	# 사망 후 시점: 나를 쓰러뜨린 적을 바라봄
	if not player.alive and killer_cam_target and is_instance_valid(killer_cam_target) and killer_cam_target.alive:
		var d := killer_cam_target.global_position + Vector3.UP * 1.2 - player.head.global_position
		player.yaw = rotate_toward(player.yaw, atan2(-d.x, -d.z), delta * 3.0)
		player.pitch = move_toward(player.pitch, atan2(d.y, Vector2(d.x, d.z).length()), delta * 2.0)
		player.rotation.y = player.yaw
		player.head.rotation.x = player.pitch
	if not player.alive and player.cam:
		player.head.position.y = move_toward(player.head.position.y, 0.5, delta * 3.0)
	elif player.alive:
		player.head.position.y = Fighter.EYE
	_update_score()


func _update_score() -> void:
	if mode.type == "duel":
		hud.score_lbl.text = "%d  :  %d" % [scores[0], scores[1]]
		var alive := [0, 0]
		for f in fighters:
			if f.alive:
				alive[f.team] += 1
		hud.round_lbl.text = "라운드 %d   ·   아군 %d명 / 적 %d명" % [round_no, alive[0], alive[1]]
	elif mode.type == "ffa":
		var lead := 0
		for f in fighters:
			lead = maxi(lead, f.kills)
		hud.score_lbl.text = "내 킬 %d  /  %d" % [player.kills, int(mode.win)]
		hud.round_lbl.text = "1등 %d킬" % lead
	else:
		hud.score_lbl.text = "무기 %d / %d" % [player.gun_level + 1, Data.GUN_GAME.size()]
		var next: String = Data.weapon(Data.GUN_GAME[mini(player.gun_level, Data.GUN_GAME.size() - 1)]).name
		hud.round_lbl.text = "현재: " + next


# ------------------------------------------------------------ 이벤트
func _on_damaged(victim: Fighter, attacker: Fighter, _amount: float, head: bool) -> void:
	if attacker == player and victim != player:
		if victim.alive:
			hud.hit_marker(false, head)
			Sfx.play("headshot" if head else "hit", -6.0 if head else -10.0)
	if victim == player and attacker:
		hud.hurt_from(attacker.global_position - player.global_position)


func _on_died(victim: Fighter, killer: Fighter, wid: String, head: bool) -> void:
	var kname := killer.display_name if killer else "?"
	var kcol: Color = TEAM_COL[0] if (killer and not is_enemy(player, killer)) else TEAM_COL[1]
	var vcol: Color = TEAM_COL[0] if not is_enemy(player, victim) else TEAM_COL[1]
	if killer == player:
		kcol = Color(1, 0.85, 0.3)
	if victim == player:
		vcol = Color(1, 0.85, 0.3)
	if OS.get_cmdline_user_args().has("--autoplay"):
		print("[KILL] t=%.1f %s -> %s (%s%s)" % [round_time, kname, victim.display_name, wid, " HS" if head else ""])
	hud.add_feed(kname, victim.display_name, Data.weapon(wid).name, head, kcol, vcol)
	if killer and killer != victim:
		killer.kills += 1
	if killer == player and victim != player:
		hud.hit_marker(true, head)
		Sfx.play("kill", -4.0)
		if head:
			Sfx.play("headshot", -4.0)
	if victim == player:
		killer_cam_target = killer
		if killer:
			hud.show_center("처치당함", "%s · %s" % [killer.display_name, Data.weapon(wid).name], 2.0, Color(1, 0.45, 0.4))
	if mode.type == "duel":
		_check_round_end()
	else:
		if mode.type == "gungame" and killer and killer != victim:
			_gungame_advance(killer)
		elif mode.type == "ffa" and killer and killer.kills >= int(mode.win):
			_end_match(killer == player, killer)
			return
		if not over:
			respawn_q.append({"f": victim, "t": 2.5})


func _gungame_advance(k: Fighter) -> void:
	k.gun_level += 1
	if k.gun_level >= Data.GUN_GAME.size():
		_end_match(k == player, k)
		return
	var nw: String = Data.GUN_GAME[k.gun_level]
	if nw == "knife":
		k.set_slots(["knife"])
	else:
		k.set_slots([nw, "knife"])
	k.cur = 0
	k.switch_to(0)
	k._equip(0, false)
	if k == player:
		hud.show_center("레벨 업!", Data.weapon(nw).name, 1.2, Color(0.5, 1.0, 0.6))
		Sfx.play("unlock", -6.0)


func _check_round_end() -> void:
	if not running:
		return
	var alive := [0, 0]
	for f in fighters:
		if f.alive:
			alive[f.team] += 1
	var winner := -1
	if alive[0] == 0:
		winner = 1
	elif alive[1] == 0:
		winner = 0
	if winner < 0:
		return
	running = false
	scores[winner] += 1
	if OS.get_cmdline_user_args().has("--autoplay"):
		print("[ROUND] %d winner=%d score=%s t=%.1f" % [round_no, winner, str(scores), round_time])
	_update_score()
	var won := winner == 0
	if scores[winner] >= int(mode.win):
		await get_tree().create_timer(1.2).timeout
		_end_match(won, null)
		return
	hud.show_center("라운드 승리!" if won else "라운드 패배", "%d : %d" % [scores[0], scores[1]], 2.2,
		Color(0.5, 1.0, 0.6) if won else Color(1, 0.45, 0.4))
	Sfx.play("unlock" if won else "lose", -8.0)
	await get_tree().create_timer(3.0).timeout
	if not over and is_inside_tree():
		_start_round()


func _end_match(won: bool, winner: Fighter) -> void:
	if over:
		return
	over = true
	running = false
	keys_earned = (3 if won else 1) + player.kills / 4
	Game.add_keys(keys_earned)
	Game.stats.wins += 1 if won else 0
	Game.stats.losses += 0 if won else 1
	Game.stats.kills += player.kills
	Game.stats.deaths += player.deaths
	Game.save()
	Sfx.play("win" if won else "lose", -2.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var res := {"won": won, "kills": player.kills, "deaths": player.deaths, "keys": keys_earned,
		"scores": scores.duplicate(), "mode": mode_id, "map": map_id,
		"winner": winner.display_name if winner else ""}
	_show_results(res)


func _show_results(res: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.06, 0.0)
	layer.add_child(bg)
	var tw := bg.create_tween()
	tw.tween_property(bg, "color:a", 0.82, 0.5)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.size = Vector2(640, 420)
	box.position = Vector2(-320, -210)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.theme = UiKit.theme
	layer.add_child(box)
	var t := Label.new()
	t.text = "승리!" if res.won else "패배"
	t.add_theme_font_size_override("font_size", 96)
	t.add_theme_color_override("font_color", Color(1, 0.82, 0.25) if res.won else Color(0.9, 0.4, 0.4))
	t.add_theme_color_override("font_outline_color", Color.BLACK)
	t.add_theme_constant_override("outline_size", 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UiKit.title_font:
		t.add_theme_font_override("font", UiKit.title_font)
	box.add_child(t)
	var info := Label.new()
	var sc := ""
	if mode.type == "duel":
		sc = "%d : %d\n" % [res.scores[0], res.scores[1]]
	elif res.winner != "":
		sc = "1등: %s\n" % res.winner
	info.text = "%s처치 %d   ·   쓰러짐 %d\n열쇠 +%d 🔑" % [sc, res.kills, res.deaths, res.keys]
	info.add_theme_font_size_override("font_size", 28)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var again := UiKit.big_button("다시 하기", Color(1.0, 0.6, 0.15))
	again.pressed.connect(func(): finished.emit({"again": true}))
	row.add_child(again)
	var menu := UiKit.big_button("메뉴로", Color(0.25, 0.5, 0.9))
	menu.pressed.connect(func(): finished.emit({"again": false}))
	row.add_child(menu)


# ------------------------------------------------------------ 수류탄
func on_grenade(kind: String, pos: Vector3, thrower: Node) -> void:
	var w := Data.weapon(kind)
	var r: float = float(w.radius)
	match kind:
		"he":
			Effects.explosion(self, pos)
			Sfx.play_at("explosion", pos, 4.0)
			for f in fighters:
				if not f.alive:
					continue
				var t := thrower as Fighter
				if t and f != t and not is_enemy(t, f):
					continue
				var d := f.global_position.distance_to(pos)
				if d > r or not _los(pos + Vector3.UP * 0.3, f.global_position + Vector3.UP * 1.0):
					continue
				var dmg: float = float(w.dmg) * pow(1.0 - d / r, 0.8)
				if f == t:
					dmg *= 0.4
				f.take_damage(dmg, t, false, kind, pos)
			if player.alive and player.global_position.distance_to(pos) < 14.0:
				player.view_kick += 6.0
		"flash":
			Effects.burst(self, pos, Color(1, 1, 0.9), 24, 8.0, 0.08, 0.3)
			Sfx.play_at("flash", pos, 2.0)
			for f in fighters:
				if not f.alive:
					continue
				var eye := f.head.global_position
				var d := eye.distance_to(pos)
				if d > r or not _los(pos, eye):
					continue
				var face := (-f.head.global_basis.z).dot((pos - eye).normalized())
				var s := 2.6 * (1.0 - d / r * 0.5)
				if face < 0.3:
					s *= 0.25
				f.apply_flash(s)
		"smoke":
			Effects.smoke_cloud(self, pos, r, 13.0)
			Sfx.play_at("smoke", pos, 0.0)
			smokes.append({"pos": pos + Vector3.UP * 1.2, "r": r, "t": 14.0})


func _los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func smoke_blocks(a: Vector3, b: Vector3) -> bool:
	for s in smokes:
		var c: Vector3 = s.pos
		var ab := b - a
		var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * t).distance_to(c) < float(s.r) * 0.85:
			return true
	return false


# ------------------------------------------------------------ 일시정지
func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 9
	pause_layer.visible = false
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.65)
	pause_layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.size = Vector2(420, 380)
	box.position = Vector2(-210, -190)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.theme = UiKit.theme
	pause_layer.add_child(box)
	var t := Label.new()
	t.text = "일시정지"
	t.add_theme_font_size_override("font_size", 48)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var sl := UiKit.slider_row("감도", 0.3, 3.0, Game.sensitivity, func(v): Game.sensitivity = v; Game.save())
	box.add_child(sl)
	var vl := UiKit.slider_row("소리", 0.0, 1.0, Game.volume, func(v): Game.set_volume(v))
	box.add_child(vl)
	var r := UiKit.big_button("계속하기", Color(1.0, 0.6, 0.15))
	r.pressed.connect(toggle_pause)
	box.add_child(r)
	var q := UiKit.big_button("나가기", Color(0.5, 0.52, 0.58))
	q.pressed.connect(func():
		get_tree().paused = false
		finished.emit({"again": false}))
	box.add_child(q)


func toggle_pause() -> void:
	if over:
		return
	paused = not paused
	pause_layer.visible = paused
	get_tree().paused = paused
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.reset_touch()
