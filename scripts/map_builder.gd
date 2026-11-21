class_name MapBuilder
extends RefCounted
## 맵을 코드로 조립한다. 상자 정의 = [재질, x, 바닥y, z, 가로, 높이, 세로]
## mirror 목록은 (x,z) → (-x,-z) 로 대칭 복제되어 양 팀이 공평해진다.

const WORLD_LAYER := 1


static func build(map_id: String, root: Node3D) -> Dictionary:
	var info: Dictionary = Data.MAPS[map_id]
	var layout := _layout(map_id)
	var size: Vector2 = layout.size
	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	root.add_child(nav)
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 46.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nav.navigation_mesh = nm

	_env(info, root)

	# 바닥
	_box(nav, info.floor, Vector3(0, -0.5, 0), Vector3(size.x + 2, 1.0, size.y + 2))
	# 외벽 (보이는 벽 + 높은 투명벽)
	var wh: float = layout.get("wall_h", 6.0)
	var wm: String = layout.get("wall_mat", info.wall)
	var hx := size.x / 2.0 + 0.5
	var hz := size.y / 2.0 + 0.5
	_box(nav, wm, Vector3(0, wh / 2.0, hz), Vector3(size.x + 2, wh, 1))
	_box(nav, wm, Vector3(0, wh / 2.0, -hz), Vector3(size.x + 2, wh, 1))
	_box(nav, wm, Vector3(hx, wh / 2.0, 0), Vector3(1, wh, size.y + 2))
	_box(nav, wm, Vector3(-hx, wh / 2.0, 0), Vector3(1, wh, size.y + 2))
	for s in [[Vector3(0, 10, hz), Vector3(size.x + 2, 20, 1)], [Vector3(0, 10, -hz), Vector3(size.x + 2, 20, 1)],
			[Vector3(hx, 10, 0), Vector3(1, 20, size.y + 2)], [Vector3(-hx, 10, 0), Vector3(1, 20, size.y + 2)]]:
		_invisible(root, s[0], s[1])
	# 팀 색 띠
	_deco(root, Mats.get_mat("accent_a"), Vector3(0, 0.02, -hz + 2.5), Vector3(size.x * 0.6, 0.04, 0.3))
	_deco(root, Mats.get_mat("accent_b"), Vector3(0, 0.02, hz - 2.5), Vector3(size.x * 0.6, 0.04, 0.3))

	for b in layout.boxes:
		_add_def(nav, b, false)
	for b in layout.mirror:
		_add_def(nav, b, false)
		_add_def(nav, b, true)
	for t in layout.get("trees", []):
		_tree(nav, Vector3(t[0], 0, t[1]), t[2])
		_tree(nav, Vector3(-t[0], 0, -t[1]), t[2])
	for c in layout.get("cars", []):
		_car(nav, Vector3(c[0], 0, c[1]), c[2], c[3])
		_car(nav, Vector3(-c[0], 0, -c[1]), c[2] + PI, c[4] if c.size() > 4 else c[3])
	for st in layout.get("stairs", []):
		_stairs(nav, st, false)
		_stairs(nav, st, true)
	for tg in layout.get("targets", []):
		_target(root, Vector3(tg[0], 0, tg[1]))

	nav.bake_navigation_mesh(false)
	return {"size": size, "nav": nav}


static func _add_def(parent: Node3D, b: Array, mirrored: bool) -> void:
	var x: float = b[1]
	var z: float = b[3]
	if mirrored:
		x = -x
		z = -z
	var sz := Vector3(b[4], b[5], b[6])
	_box(parent, b[0], Vector3(x, b[2] + sz.y / 2.0, z), sz)


static func _box(parent: Node3D, mat: String, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = center
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Mats.get_mat(mat)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	parent.add_child(body)
	# 상자 모서리 테두리(가독성 향상)
	if mat == "crate" and size.y >= 1.0:
		for yy in [-size.y / 2.0 + 0.06, size.y / 2.0 - 0.06]:
			_deco(body, Mats.get_mat("trim"), Vector3(0, yy, 0), Vector3(size.x + 0.04, 0.12, size.z + 0.04))
	return body


static func _invisible(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.position = center
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	parent.add_child(body)


static func _deco(parent: Node3D, mat: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _tree(parent: Node3D, pos: Vector3, scale: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.position = pos
	parent.add_child(body)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25 * scale
	cm.bottom_radius = 0.35 * scale
	cm.height = 3.0 * scale
	trunk.mesh = cm
	trunk.material_override = Mats.get_mat("wood")
	trunk.position.y = 1.5 * scale
	body.add_child(trunk)
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.4 * scale
	sh.height = 3.0 * scale
	cs.shape = sh
	cs.position.y = 1.5 * scale
	body.add_child(cs)
	var leaf := Mats.get_mat("leaf")
	for o in [Vector3(0, 3.6, 0), Vector3(0.8, 3.0, 0.3), Vector3(-0.7, 3.1, -0.4), Vector3(0.1, 4.3, 0.2)]:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.3 * scale
		sm.height = 2.4 * scale
		sm.radial_segments = 12
		sm.rings = 6
		s.mesh = sm
		s.material_override = leaf
		s.position = o * scale
		body.add_child(s)


static func _car(parent: Node3D, pos: Vector3, rot: float, col: Color) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = WORLD_LAYER
	body.position = pos
	body.rotation.y = rot
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.0, 1.5, 4.2)
	cs.shape = sh
	cs.position.y = 0.75
	body.add_child(cs)
	var paint := Mats.color_mat(col, 0.0, 0.3, 0.4)
	_deco(body, paint, Vector3(0, 0.65, 0), Vector3(2.0, 0.8, 4.2))
	_deco(body, paint, Vector3(0, 1.3, -0.2), Vector3(1.8, 0.6, 2.2))
	_deco(body, Mats.get_mat("glass"), Vector3(0, 1.32, -0.2), Vector3(1.84, 0.45, 2.24))
	var wheel := Mats.color_mat(Color(0.1, 0.1, 0.1))
	for w in [Vector3(1, 0.35, 1.3), Vector3(-1, 0.35, 1.3), Vector3(1, 0.35, -1.3), Vector3(-1, 0.35, -1.3)]:
		_deco(body, wheel, w, Vector3(0.3, 0.7, 0.7))
	_deco(body, Mats.color_mat(Color(1, 0.95, 0.7), 1.5), Vector3(0.6, 0.7, 2.11), Vector3(0.4, 0.15, 0.02))
	_deco(body, Mats.color_mat(Color(1, 0.95, 0.7), 1.5), Vector3(-0.6, 0.7, 2.11), Vector3(0.4, 0.15, 0.02))


## 계단: [x, z, 방향(0:+z,1:-z,2:+x,3:-x), 단수, 재질]
static func _stairs(parent: Node3D, st: Array, mirrored: bool) -> void:
	var x: float = st[0]
	var z: float = st[1]
	var dir: int = st[2]
	if mirrored:
		x = -x
		z = -z
		dir = [1, 0, 3, 2][dir]
	var steps: int = st[3]
	var mat: String = st[4]
	var d := Vector3([0, 0, 1, -1][dir], 0, [1, -1, 0, 0][dir])
	for i in steps:
		var h := 0.4 * (i + 1)
		var p := Vector3(x, h / 2.0, z) + d * (i * 0.6)
		var size := Vector3(2.4, h, 0.6) if dir < 2 else Vector3(0.6, h, 2.4)
		_box(parent, mat, p, size)


static func _target(parent: Node3D, pos: Vector3) -> void:
	_deco(parent, Mats.get_mat("wood"), pos + Vector3(0, 0.8, 0), Vector3(0.12, 1.6, 0.12))
	var board := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.55
	cm.height = 0.06
	board.mesh = cm
	board.rotation.x = PI / 2
	board.position = pos + Vector3(0, 1.7, 0)
	board.material_override = Mats.color_mat(Color(0.95, 0.95, 0.95))
	parent.add_child(board)
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.3
	rm.bottom_radius = 0.3
	rm.height = 0.08
	ring.mesh = rm
	ring.rotation.x = PI / 2
	ring.position = pos + Vector3(0, 1.7, 0)
	ring.material_override = Mats.color_mat(Color(0.9, 0.2, 0.2))
	parent.add_child(ring)


static func _env(info: Dictionary, root: Node3D) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = info.sky_top
	sm.sky_horizon_color = info.sky_horizon
	sm.ground_horizon_color = info.sky_horizon
	sm.ground_bottom_color = info.sky_horizon.darkened(0.4)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = info.ambient * 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.fog_enabled = true
	env.fog_light_color = info.fog
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = info.sun
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	sun.shadow_bias = 0.05
	root.add_child(sun)
	if Game.is_touch:
		# 폰: 그림자 거리와 글로우를 줄여 프레임 확보
		sun.shadow_enabled = false
		env.glow_enabled = false
		env.fog_enabled = false


# ------------------------------------------------------------------ 레이아웃
static func _layout(id: String) -> Dictionary:
	match id:
		"warehouse":
			return {"size": Vector2(36, 48), "wall_h": 7.0,
				"boxes": [
					["crate", 0, 0, 0, 3, 3, 3], ["crate", -9, 0, 0, 2, 1.3, 2], ["crate", 9, 0, 0, 2, 1.3, 2],
					["metal", -15, 0, 0, 3, 4, 1], ["metal", 15, 0, 0, 3, 4, 1],
				],
				"mirror": [
					["crate", -12, 0, 15, 2.4, 2.4, 2.4], ["crate", -12, 2.4, 15, 2.4, 2.4, 2.4], ["crate", -9.6, 0, 15, 2.4, 1.2, 2.4],
					["crate", 9, 0, 17, 3, 1.6, 1.6], ["metal", 0, 0, 12, 8, 1.2, 1],
					["crate", -4, 0, 7, 2, 2, 2], ["crate", -2, 0, 7.6, 2, 1.2, 2], ["crate", 12, 0, 8, 2.4, 2.4, 4],
					["metal", 6, 0, 4, 1, 3, 6], ["crate", -14, 0, 5, 3, 2, 3],
					["metal", 16.5, 0, 14, 2, 4.5, 8], ["metal", -16.5, 0, 21, 2, 4.5, 4],
				]}
		"dust":
			return {"size": Vector2(40, 56), "wall_h": 6.0,
				"boxes": [
					["sandstone", -7, 0, 0, 2, 4, 7], ["sandstone", 7, 0, 0, 2, 4, 7], ["crate", 0, 0, 0, 2.2, 2.2, 2.2],
					["sandstone", -16, 0, 0, 7, 5, 4], ["sandstone", 16, 0, 0, 7, 5, 4],
				],
				"mirror": [
					["sandstone", -9, 0, 15, 3, 5, 12], ["sandstone", 10, 0, 17, 7, 5, 8], ["crate", 3, 0, 10, 2, 2, 2],
					["crate", 3.5, 2, 10, 1.4, 1.4, 1.4], ["sandstone", -15, 0, 6, 9, 4, 2], ["sandstone", 13, 0, 6, 2, 3, 5],
					["wood", -2, 0, 21, 4, 1.2, 1], ["crate", -3, 0, 4, 1.6, 1.6, 1.6], ["crate", 16, 0, 22, 2, 2, 2],
				]}
		"rooftop":
			return {"size": Vector2(36, 44), "wall_h": 1.3, "wall_mat": "brick",
				"boxes": [
					["metal", 0, 0, 0, 4, 1.4, 2.4], ["brick", -12, 0, 0, 1.5, 4, 1.5], ["brick", 12, 0, 0, 1.5, 4, 1.5],
				],
				"mirror": [
					["brick", -11, 0, 13, 8, 2, 6], ["metal", -12, 2, 15, 2, 1.2, 1.4],
					["metal", 8, 0, 10, 3, 1.6, 2], ["metal", 8, 0, 13, 3, 1.6, 2],
					["brick", 3, 0, 15, 1.2, 3.5, 1.2], ["glass", 14, 0, 4, 4, 0.8, 4], ["crate", -4, 0, 6, 2, 1.5, 2],
					["metal", 14, 0, 19, 2.5, 2.4, 2.5],
				],
				"stairs": [[-5, 12.5, 3, 5, "concrete"]]}
		"park":
			return {"size": Vector2(44, 52), "wall_h": 2.5, "wall_mat": "brick",
				"boxes": [
					["tiles", 0, 0, 0, 6, 0.8, 6], ["sandstone", 0, 0.8, 0, 1.4, 2.2, 1.4],
					["leaf", -12, 0, 0, 6, 1.4, 1.2], ["leaf", 12, 0, 0, 6, 1.4, 1.2],
				],
				"mirror": [
					["leaf", -8, 0, 12, 1.2, 1.4, 7], ["leaf", 10, 0, 9, 8, 1.4, 1.2], ["wood", 4, 0, 6, 3, 0.9, 0.8],
					["wood", -16, 0, 18, 3, 0.9, 0.8], ["leaf", 3, 0, 18, 6, 1.4, 1.2], ["sandstone", 17, 0, 14, 4, 2.5, 4],
				],
				"trees": [[-14, 9, 1.0], [6, 13, 1.1], [16, 3, 0.9], [-4, 21, 1.0], [-18, 2, 1.2], [14, 22, 1.0]]}
		"crossroads":
			return {"size": Vector2(44, 44), "wall_h": 9.0, "wall_mat": "brick",
				"boxes": [
					["brick", -14, 0, -14, 12, 8, 12], ["brick", 14, 0, 14, 12, 8, 12],
					["brick", 14, 0, -14, 12, 8, 12], ["brick", -14, 0, 14, 12, 8, 12],
					["concrete", 0, 0, 0, 2.5, 0.6, 2.5],
				],
				"mirror": [
					["crate", -3, 0, 12, 1.8, 1.8, 1.8], ["crate", 4, 0, 14, 2.2, 1.4, 2.2], ["concrete", 3.5, 0, 6, 0.6, 1.0, 3],
					["metal", -5, 0, 15.5, 1.2, 2.2, 1.2],
				],
				"cars": [[3.2, -3.5, 0.15, Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.85)], [-16, 3.5, PI / 2, Color(0.95, 0.75, 0.15), Color(0.2, 0.7, 0.4)]]}
		"range":
			return {"size": Vector2(24, 70), "wall_h": 4.0, "wall_mat": "crate",
				"boxes": [
					["wood", 0, 0, 0, 0.6, 2.4, 6], ["crate", -7, 0, 0, 2, 1.4, 2], ["crate", 7, 0, 0, 2, 1.4, 2],
				],
				"mirror": [
					["wood", -6, 0, 10, 0.5, 2.2, 8], ["wood", 6, 0, 18, 0.5, 2.2, 8], ["crate", 2, 0, 8, 1.6, 1.4, 1.6],
					["crate", -3, 0, 22, 2, 1.2, 1], ["sandstone", 8, 0, 28, 4, 1.4, 1], ["crate", -9, 0, 30, 2, 2, 2],
					["wood", 0, 0, 25, 6, 1.0, 0.5],
				],
				"targets": [[-10, 5], [10, -5], [-10, -15], [10, 15]]}
	return _layout("warehouse")


static func spawn_points(map_id: String, team: int, count: int) -> Array:
	var layout := _layout(map_id)
	var size: Vector2 = layout.size
	var z := size.y / 2.0 - 3.0
	if team == 0:
		z = -z
	var out := []
	var offs := [0.0, -3.0, 3.0, -6.0, 6.0, -9.0]
	for i in count:
		out.append(Vector3(offs[i % offs.size()], 0.2, z))
	return out


static func map_size(map_id: String) -> Vector2:
	return _layout(map_id).size
