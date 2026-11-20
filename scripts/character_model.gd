class_name CharacterModel
extends Node3D
## 캐릭터 3D 모델. assets/models/<id>.glb(리깅 모델)가 있으면 그걸 쓰고,
## 없으면 코드로 만든 기본 모델을 쓴다. 둘 다 같은 animate() 로 걷기 모션.

var char_id := "blaze"
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var sh_l: Node3D
var sh_r: Node3D
var torso: Node3D
var head: Node3D
var gun_holder: Node3D
var _phase := 0.0
var _meshes: Array[MeshInstance3D] = []
var _flash_t := 0.0
var _flash_mat: StandardMaterial3D
# GLB 모드
var _skel: Skeleton3D
var _bones := {}
var _rest := {}
var _anim: AnimationPlayer


func build(id: String) -> void:
	char_id = id
	_flash_mat = Mats.unshaded(Color(1, 1, 1, 0.55))
	var glb := "res://assets/models/%s.glb" % id
	if ResourceLoader.exists(glb):
		_build_glb(glb)
	else:
		_build_proc(Data.character(id))
	_collect(self)


func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			_meshes.append(c)
		_collect(c)


func set_shadow_only() -> void:
	for m in _meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func flash() -> void:
	_flash_t = 0.09
	for m in _meshes:
		m.material_overlay = _flash_mat


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			for m in _meshes:
				m.material_overlay = null


## speed: 0~1 이동 비율, air: 공중 여부, pitch: 상하 시선(라디안)
func animate(delta: float, speed: float, air: bool, pitch: float) -> void:
	_phase += delta * (4.0 + speed * 7.0) * (1.0 if speed > 0.05 else 0.0)
	var swing := sin(_phase) * 0.75 * speed
	if _skel:
		_animate_glb(swing, air, pitch, speed)
		return
	if hip_l == null:
		return
	if air:
		hip_l.rotation.x = lerpf(hip_l.rotation.x, 0.6, delta * 10)
		hip_r.rotation.x = lerpf(hip_r.rotation.x, -0.2, delta * 10)
		knee_l.rotation.x = lerpf(knee_l.rotation.x, -1.0, delta * 10)
		knee_r.rotation.x = lerpf(knee_r.rotation.x, -0.5, delta * 10)
	else:
		hip_l.rotation.x = swing
		hip_r.rotation.x = -swing
		knee_l.rotation.x = -maxf(0.0, -sin(_phase)) * 1.0 * speed
		knee_r.rotation.x = -maxf(0.0, sin(_phase)) * 1.0 * speed
	torso.position.y = 0.0 + absf(cos(_phase)) * 0.04 * speed
	torso.rotation.y = sin(_phase) * 0.06 * speed
	# 상체는 조준 방향을 따라 위아래로
	var p := clampf(pitch, -0.9, 0.9)
	sh_l.rotation.x = 1.3 + p * 0.9
	sh_r.rotation.x = 1.4 + p * 0.9
	gun_holder.rotation.x = p
	head.rotation.x = p * 0.6


func _build_proc(c: Dictionary) -> void:
	var main := Mats.color_mat(c.main, 0.0, 0.45, 0.15)
	var sub := Mats.color_mat(c.sub, 0.0, 0.7)
	var acc := Mats.color_mat(c.accent, 1.6, 0.4)
	var skin := Mats.color_mat(c.skin, 0.0, 0.8)
	var dark := Mats.color_mat(Color(0.08, 0.08, 0.1), 0.0, 0.5)
	var bulk: float = [1.0, 0.92, 1.18][int(c.body)]
	var sw: float = 0.22 * bulk

	torso = Node3D.new()
	add_child(torso)
	# 골반·몸통
	_box(torso, sub, Vector3(0, 1.02, 0), Vector3(0.34 * bulk, 0.18, 0.2))
	_box(torso, sub, Vector3(0, 1.28, 0), Vector3(0.38 * bulk, 0.36, 0.22))
	_box(torso, main, Vector3(0, 1.3, -0.03), Vector3(0.42 * bulk, 0.3, 0.2))   # 가슴 장갑
	_box(torso, acc, Vector3(0, 1.3, -0.135), Vector3(0.18, 0.025, 0.01))
	_box(torso, main, Vector3(0, 1.32, 0.12), Vector3(0.3 * bulk, 0.26, 0.1))    # 등판
	_box(torso, dark, Vector3(0, 1.1, 0), Vector3(0.36 * bulk, 0.05, 0.22))      # 벨트
	_box(torso, acc, Vector3(0, 1.1, -0.112), Vector3(0.06, 0.04, 0.01))
	# 머리
	head = Node3D.new()
	head.position = Vector3(0, 1.55, 0)
	torso.add_child(head)
	_box(head, skin, Vector3(0, 0.03, 0), Vector3(0.07, 0.08, 0.07))
	var hs := _sphere(head, skin, Vector3(0, 0.15, 0), 0.115, 0.26)
	hs.scale = Vector3(1.0, 1.05, 1.05)
	_box(head, dark, Vector3(-0.04, 0.16, -0.105), Vector3(0.025, 0.018, 0.01))
	_box(head, dark, Vector3(0.04, 0.16, -0.105), Vector3(0.025, 0.018, 0.01))
	_helmet(head, c.helmet, main, sub, acc, dark)
	# 다리
	hip_l = _limb(torso, Vector3(-0.1 * bulk, 0.95, 0))
	hip_r = _limb(torso, Vector3(0.1 * bulk, 0.95, 0))
	for hp in [hip_l, hip_r]:
		_capsule(hp, sub, Vector3(0, -0.22, 0), 0.075 * bulk, 0.46)
		_box(hp, main, Vector3(0, -0.36, -0.06), Vector3(0.12, 0.12, 0.04))  # 무릎 보호대
		var kn := _limb(hp, Vector3(0, -0.45, 0))
		_capsule(kn, sub, Vector3(0, -0.2, 0), 0.065 * bulk, 0.42)
		_box(kn, dark, Vector3(0, -0.44, -0.04), Vector3(0.13, 0.1, 0.24))      # 신발
		_box(kn, acc, Vector3(0, -0.4, -0.155), Vector3(0.1, 0.015, 0.01))
		if hp == hip_l:
			knee_l = kn
		else:
			knee_r = kn
	# 팔 (총을 든 자세)
	sh_l = _limb(torso, Vector3(-sw - 0.04, 1.42, 0))
	sh_r = _limb(torso, Vector3(sw + 0.04, 1.42, 0))
	for s in [sh_l, sh_r]:
		_sphere(s, main, Vector3(0, 0, 0), 0.085 * bulk, 0.16 * bulk)  # 어깨 보호대
		_capsule(s, sub, Vector3(0, -0.15, 0), 0.055 * bulk, 0.32)
		_capsule(s, skin, Vector3(0, -0.36, 0), 0.05, 0.22)
		_box(s, dark, Vector3(0, -0.48, 0), Vector3(0.08, 0.09, 0.08))  # 장갑
	sh_l.rotation = Vector3(1.3, 0, 0.5)
	sh_r.rotation = Vector3(1.4, 0, -0.15)
	gun_holder = Node3D.new()
	gun_holder.position = Vector3(0.1, 1.3, -0.32)
	torso.add_child(gun_holder)


func _helmet(h: Node3D, kind: String, main: Material, sub: Material, acc: Material, dark: Material) -> void:
	match kind:
		"visor":
			var s := _sphere(h, main, Vector3(0, 0.19, 0.01), 0.135, 0.22)
			s.scale = Vector3(1.0, 0.85, 1.05)
			_box(h, Mats.color_mat(Color(0.1, 0.12, 0.16, 0.85), 0.0, 0.1, 0.6), Vector3(0, 0.155, -0.11), Vector3(0.21, 0.06, 0.03))
			_box(h, acc, Vector3(0, 0.155, -0.127), Vector3(0.2, 0.012, 0.005))
			_box(h, acc, Vector3(0.13, 0.17, 0), Vector3(0.02, 0.06, 0.06))
		"goggles":
			var s := _sphere(h, sub, Vector3(0, 0.2, 0.01), 0.125, 0.18)
			s.scale = Vector3(1.0, 0.9, 1.0)
			_box(h, dark, Vector3(0, 0.2, 0), Vector3(0.25, 0.04, 0.25))
			_box(h, acc, Vector3(-0.045, 0.205, -0.12), Vector3(0.07, 0.05, 0.02))
			_box(h, acc, Vector3(0.045, 0.205, -0.12), Vector3(0.07, 0.05, 0.02))
			_box(h, main, Vector3(0, 0.08, -0.06), Vector3(0.2, 0.06, 0.12))  # 목도리
		"crest":
			var s := _sphere(h, main, Vector3(0, 0.19, 0.01), 0.135, 0.22)
			s.scale = Vector3(1.0, 0.85, 1.05)
			_box(h, acc, Vector3(0, 0.3, 0.02), Vector3(0.025, 0.07, 0.24))
			_box(h, dark, Vector3(0, 0.15, -0.115), Vector3(0.19, 0.04, 0.02))
		"cap":
			var s := _sphere(h, main, Vector3(0, 0.2, 0.0), 0.122, 0.16)
			s.scale = Vector3(1.0, 0.8, 1.0)
			_box(h, main, Vector3(0, 0.215, -0.14), Vector3(0.18, 0.015, 0.1))
			_box(h, acc, Vector3(0, 0.25, -0.1), Vector3(0.05, 0.04, 0.01))
			_box(h, sub, Vector3(0, 0.08, -0.04), Vector3(0.2, 0.05, 0.14))
		"hood":
			var s := _sphere(h, main, Vector3(0, 0.17, 0.03), 0.15, 0.3)
			s.scale = Vector3(1.0, 1.0, 1.05)
			_box(h, sub, Vector3(0, 0.1, -0.1), Vector3(0.2, 0.08, 0.04))  # 마스크
			_box(h, acc, Vector3(-0.04, 0.16, -0.113), Vector3(0.03, 0.012, 0.005))
			_box(h, acc, Vector3(0.04, 0.16, -0.113), Vector3(0.03, 0.012, 0.005))
		"heavy":
			_box(h, main, Vector3(0, 0.16, 0.0), Vector3(0.28, 0.27, 0.28))
			_box(h, dark, Vector3(0, 0.16, -0.14), Vector3(0.22, 0.05, 0.01))
			_box(h, acc, Vector3(0, 0.16, -0.146), Vector3(0.2, 0.015, 0.005))
			_box(h, sub, Vector3(0, 0.31, 0), Vector3(0.06, 0.03, 0.22))


func _limb(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _box(p: Node3D, m: Material, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	p.add_child(mi)
	return mi


func _sphere(p: Node3D, m: Material, pos: Vector3, r: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = maxf(h, r * 2.0)
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	p.add_child(mi)
	return mi


func _capsule(p: Node3D, m: Material, pos: Vector3, r: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0)
	cm.radial_segments = 10
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	p.add_child(mi)
	return mi


# ------------------------------------------------------------- GLB (Higgsfield 리깅 모델)
func _build_glb(path: String) -> void:
	var scene: PackedScene = load(path)
	var inst := scene.instantiate()
	add_child(inst)
	inst.rotation.y = PI  # 모델 정면(+Z)을 게임 정면(-Z)으로
	_skel = _find_skel(inst)
	_anim = _find_anim(inst)
	# 키 1.8m 로 맞추기
	var aabb := _merged_aabb(inst)
	if aabb.size.y > 0.01:
		var s := 1.8 / aabb.size.y
		inst.scale = Vector3.ONE * s
		inst.position.y = -aabb.position.y * s
	if _skel:
		for i in _skel.get_bone_count():
			var bn := _skel.get_bone_name(i).to_lower()
			for key in ["leftupleg", "rightupleg", "leftleg", "rightleg", "leftarm", "rightarm", "leftforearm", "rightforearm", "spine", "head", "hips"]:
				if bn.ends_with(key) and not _bones.has(key):
					_bones[key] = i
					_rest[key] = _skel.get_bone_pose_rotation(i)
	if _anim:
		_anim.stop()
	# 총 붙이기: 오른손 본이 있으면 거기에
	gun_holder = Node3D.new()
	var hand := -1
	if _skel:
		for i in _skel.get_bone_count():
			if _skel.get_bone_name(i).to_lower().ends_with("righthand"):
				hand = i
	if hand >= 0:
		var ba := BoneAttachment3D.new()
		ba.bone_idx = hand
		_skel.add_child(ba)
		ba.add_child(gun_holder)
		gun_holder.rotation_degrees = Vector3(0, 180, 0)
	else:
		gun_holder.position = Vector3(0.12, 1.36, -0.05)
		add_child(gun_holder)


func _animate_glb(swing: float, air: bool, pitch: float, speed: float) -> void:
	var leg := swing
	if air:
		leg = 0.5
	_rot("leftupleg", Vector3.RIGHT, -leg)
	_rot("rightupleg", Vector3.RIGHT, leg if not air else -0.2)
	_rot("leftleg", Vector3.RIGHT, maxf(0.0, -sin(_phase)) * speed * 1.0 + (0.8 if air else 0.0))
	_rot("rightleg", Vector3.RIGHT, maxf(0.0, sin(_phase)) * speed * 1.0 + (0.4 if air else 0.0))
	# 총 드는 자세 (A포즈 기준)
	_rot2("rightarm", Vector3(-1.2 - pitch * 0.8, 0, -0.9))
	_rot2("leftarm", Vector3(-1.2 - pitch * 0.8, 0, 0.9))
	_rot("rightforearm", Vector3.UP, -0.6)
	_rot("leftforearm", Vector3.UP, 0.9)
	_rot("head", Vector3.RIGHT, -pitch * 0.5)


func _rot(key: String, axis: Vector3, ang: float) -> void:
	if not _bones.has(key):
		return
	_skel.set_bone_pose_rotation(_bones[key], _rest[key] * Quaternion(axis, ang))


func _rot2(key: String, e: Vector3) -> void:
	if not _bones.has(key):
		return
	_skel.set_bone_pose_rotation(_bones[key], _rest[key] * Quaternion.from_euler(e))


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r:
			return r
	return null


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _merged_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in _all(n):
		if c is MeshInstance3D and c.mesh:
			var a: AABB = (c as MeshInstance3D).get_aabb()
			if first:
				out = a
				first = false
			else:
				out = out.merge(a)
	return out


func _all(n: Node) -> Array:
	var r := [n]
	for c in n.get_children():
		r.append_array(_all(c))
	return r
