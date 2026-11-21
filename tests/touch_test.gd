extends Node
## 터치 조작 자동 테스트: --touchtest --touch --autoplay 로 실행

var m: Match


func _ready() -> void:
	await get_tree().create_timer(4.0).timeout
	m = get_tree().get_first_node_in_group("match")
	var p: Fighter = m.player
	var vs := get_viewport().get_visible_rect().size
	print("[T] viewport ", vs, " is_touch ", Game.is_touch, " emulate ", Input.emulate_mouse_from_touch)
	var y0 := p.yaw
	# 1) 조이스틱만 움직이기 → 시점은 그대로여야 함
	_touch(0, Vector2(200, 560), true)
	for i in 10:
		_drag(0, Vector2(200 + i * 3, 560 - i * 8))
		await get_tree().physics_frame
	await get_tree().create_timer(0.5).timeout
	print("[T] joystick only: yaw change=%.4f move=%s pos=%s" % [p.yaw - y0, m.hud.move_vec, p.global_position])
	# 1-1) 달리면서 슬라이드 버튼
	var sb: Dictionary = m.hud._btn["slide"]
	_touch(3, sb.pos, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_touch(3, sb.pos, false)
	await get_tree().create_timer(0.15).timeout
	print("[T] slide: speed=%.1f head_y=%.2f sliding=%s" % [Vector2(p.velocity.x, p.velocity.z).length(), p.head.position.y, p.is_sliding()])
	await get_tree().create_timer(0.3).timeout
	_touch(4, m.hud._btn["jump"].pos, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_touch(4, m.hud._btn["jump"].pos, false)
	await get_tree().create_timer(0.2).timeout
	print("[T] slide-jump: speed=%.1f y=%.2f sliding=%s" % [Vector2(p.velocity.x, p.velocity.z).length(), p.global_position.y, p.is_sliding()])
	await get_tree().create_timer(1.2).timeout
	print("[T] after: speed=%.1f head_y=%.2f" % [Vector2(p.velocity.x, p.velocity.z).length(), p.head.position.y])
	# 2) 오른쪽 드래그로 시점 돌리기 (조이스틱 누른 채)
	y0 = p.yaw
	_touch(1, Vector2(900, 300), true)
	for i in 10:
		_drag(1, Vector2(900 + (i + 1) * 10, 300))
		await get_tree().physics_frame
	await get_tree().process_frame
	print("[T] look drag 100px: yaw change=%.4f (expect about -0.36 or less with assist)" % (p.yaw - y0))
	# 3) 시점 손가락 떼고 조이스틱만 계속 → 시점 고정
	_touch(1, Vector2(1000, 300), false)
	y0 = p.yaw
	for i in 10:
		_drag(0, Vector2(230 - i * 6, 480 + i * 4))
		await get_tree().physics_frame
	print("[T] joystick after look release: yaw change=%.4f" % (p.yaw - y0))
	# 4) 발사 버튼 살짝 떨림 → 시점 고정, 사격 중
	var fb: Dictionary = m.hud._btn["fire"]
	y0 = p.yaw
	_touch(2, fb.pos, true)
	for i in 6:
		_drag(2, fb.pos + Vector2(i % 2 * 4, 3))
		await get_tree().physics_frame
	print("[T] fire jitter: yaw change=%.4f fire_held=%s in_fire=%s" % [p.yaw - y0, m.hud.fire_held, p.in_fire])
	# 5) 잘못된 큰 점프 이벤트 → 무시
	y0 = p.yaw
	_drag(2, fb.pos + Vector2(-400, 0))
	await get_tree().physics_frame
	print("[T] bogus jump: yaw change=%.4f" % (p.yaw - y0))
	_touch(2, fb.pos, false)
	_touch(0, Vector2(200, 500), false)
	await get_tree().physics_frame
	print("[T] released: move=%s fire=%s touches=%d" % [m.hud.move_vec, m.hud.fire_held, m.hud._touches.size()])
	get_tree().quit()


func _touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	e.relative = Vector2(500, 0)  # 일부러 엉터리 값: 직접 계산하는지 확인
	Input.parse_input_event(e)
	Input.flush_buffered_events()
