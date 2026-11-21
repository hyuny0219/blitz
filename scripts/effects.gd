class_name Effects
extends RefCounted
## 탄 궤적, 피격 불꽃, 폭발, 쓰러짐 효과 (CPUParticles3D 사용: 웹/모바일 호환)


static func tracer(world: Node3D, from: Vector3, to: Vector3, col: Color = Color(1.0, 0.85, 0.5)) -> void:
	var len := from.distance_to(to)
	if len < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, len)
	mi.mesh = bm
	mi.material_override = Mats.color_mat(Color(col.r, col.g, col.b, 0.85), 3.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.1, 0.1, 1.0), 0.07)
	tw.tween_callback(mi.queue_free)


static func impact(world: Node3D, pos: Vector3, normal: Vector3, col: Color = Color(1.0, 0.8, 0.4)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 8
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 40.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := BoxMesh.new()
	m.size = Vector3(0.04, 0.04, 0.04)
	p.mesh = m
	p.material_override = Mats.color_mat(col, 2.0)
	world.add_child(p)
	p.global_position = pos + normal * 0.02
	p.emitting = true
	# 총알 자국
	var d := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	d.mesh = q
	d.material_override = Mats.unshaded(Color(0.1, 0.1, 0.1, 0.7))
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(d)
	d.global_position = pos + normal * 0.01
	if absf(normal.dot(Vector3.UP)) > 0.99:
		d.look_at(d.global_position - normal, Vector3.FORWARD)
	else:
		d.look_at(d.global_position - normal, Vector3.UP)
	var tw := d.create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(d.queue_free)
	var tw2 := p.create_tween()
	tw2.tween_interval(1.0)
	tw2.tween_callback(p.queue_free)


static func burst(world: Node3D, pos: Vector3, col: Color, amount: int = 30, speed: float = 6.0, size: float = 0.09, life: float = 0.8) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var m := BoxMesh.new()
	m.size = Vector3(size, size, size)
	p.mesh = m
	p.material_override = Mats.color_mat(col, 2.5)
	world.add_child(p)
	p.global_position = pos
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(life + 0.5)
	tw.tween_callback(p.queue_free)


static func explosion(world: Node3D, pos: Vector3) -> void:
	burst(world, pos, Color(1.0, 0.6, 0.15), 40, 10.0, 0.18, 0.7)
	burst(world, pos, Color(1.0, 0.9, 0.5), 20, 6.0, 0.25, 0.4)
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	s.mesh = sm
	s.material_override = Mats.color_mat(Color(1.0, 0.7, 0.3, 0.6), 4.0)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(s)
	s.global_position = pos
	s.scale = Vector3.ONE * 0.3
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 3.5, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_callback(s.queue_free)


static func smoke_cloud(world: Node3D, pos: Vector3, radius: float, duration: float) -> Node3D:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = pos
	var mat := Mats.color_mat(Color(0.82, 0.85, 0.88, 0.92), 0.0, 1.0)
	for i in 14:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := randf_range(radius * 0.45, radius * 0.7)
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		s.mesh = sm
		s.material_override = mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := randf() * TAU
		var d := randf() * radius * 0.6
		s.position = Vector3(cos(a) * d, randf_range(0.6, radius * 0.9), sin(a) * d)
		s.scale = Vector3.ONE * 0.1
		root.add_child(s)
		var tw := s.create_tween()
		tw.tween_property(s, "scale", Vector3.ONE, 0.8).set_ease(Tween.EASE_OUT)
		tw.tween_interval(duration)
		tw.tween_property(s, "scale", Vector3.ONE * 0.01, 1.2)
	var tw2 := root.create_tween()
	tw2.tween_interval(duration + 2.2)
	tw2.tween_callback(root.queue_free)
	return root
