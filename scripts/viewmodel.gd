class_name Viewmodel
extends Node3D
## 1인칭 손 + 무기. 걷기 흔들림, 반동, 재장전/교체 애니메이션, 총구 화염

const BASE_POS := Vector3(0.19, -0.2, -0.36)

var rig: Node3D
var gun: Node3D
var arms: Node3D
var flash_node: MeshInstance3D
var wid := ""
var _bob := 0.0
var _kick := 0.0
var _swing := 0.0
var _reload_t := 0.0
var _reload_len := 1.0
var _raise := 0.0
var _flash_t := 0.0
var _sleeve: Material
var _glove: Material
var _skin: Material
var _last_cam_basis: Basis
var _sway := Vector2.ZERO


func setup(c: Dictionary) -> void:
	_sleeve = Mats.color_mat(c.sub, 0.0, 0.7)
	_glove = Mats.color_mat(Color(0.1, 0.1, 0.12), 0.0, 0.6)
	_skin = Mats.color_mat(c.main, 0.0, 0.5, 0.1)
	rig = Node3D.new()
	rig.position = BASE_POS
	rig.scale = Vector3.ONE * 0.62
	add_child(rig)
	flash_node = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	flash_node.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.45, 0.95)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_node.material_override = fm
	flash_node.visible = false
	flash_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_weapon(id: String, instant: bool) -> void:
	wid = id
	if gun:
		gun.queue_free()
	if arms:
		arms.queue_free()
	gun = WeaponModel.build(id)
	rig.add_child(gun)
	if flash_node.get_parent():
		flash_node.get_parent().remove_child(flash_node)
	var m := gun.get_node("muzzle")
	m.add_child(flash_node)
	arms = Node3D.new()
	rig.add_child(arms)
	var kind: String = Data.weapon(id).kind
	# 오른손(손잡이)
	_arm(Vector3(0.0, -0.1, 0.06), Vector3(0.12, -0.25, 0.35))
	if kind in ["rifle", "smg", "shotgun", "sniper"]:
		_arm(Vector3(-0.0, -0.05, -0.28), Vector3(-0.2, -0.28, 0.1))
	elif kind == "pistol":
		_arm(Vector3(-0.02, -0.09, 0.05), Vector3(-0.16, -0.28, 0.3))
	for n in _all(rig):
		if n is GeometryInstance3D:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raise = 0.0 if instant else 1.0
	_reload_t = 0.0


func _arm(hand: Vector3, elbow: Vector3) -> void:
	var g := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.08, 0.1)
	g.mesh = bm
	g.material_override = _glove
	g.position = hand
	arms.add_child(g)
	var f := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.042
	var len := hand.distance_to(elbow) + 0.05
	cm.height = len
	f.mesh = cm
	f.material_override = _sleeve
	arms.add_child(f)
	f.position = (hand + elbow) * 0.5
	var d := (hand - elbow).normalized()
	f.basis = Basis(Quaternion(Vector3.UP, d))
	var pad := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.09, 0.09, 0.14)
	pad.mesh = pb
	pad.material_override = _skin
	arms.add_child(pad)
	pad.position = hand.lerp(elbow, 0.55)
	pad.basis = f.basis * Basis(Vector3.RIGHT, PI / 2)


func muzzle_global() -> Vector3:
	if gun:
		var m := gun.get_node_or_null("muzzle")
		if m:
			return m.global_position
	return global_position


func on_fire(recoil: float) -> void:
	var kind: String = Data.weapon(wid).kind
	if kind == "knife" or kind == "grenade":
		_swing = 1.0
		return
	_kick = clampf(_kick + 0.6 + recoil * 0.15, 0.0, 1.6)
	_flash_t = 0.045
	flash_node.visible = true
	flash_node.rotation.z = randf() * TAU
	var s := 1.0 + recoil * 0.15
	flash_node.scale = Vector3.ONE * randf_range(0.8, 1.2) * s


func on_reload(t: float) -> void:
	_reload_len = t
	_reload_t = t


func update_motion(delta: float, speed: float, on_floor: bool, scoped: bool, slide: float = 0.0) -> void:
	visible = not scoped
	_bob += delta * (2.0 + speed * 9.0)
	var bob_amt := 0.006 + speed * 0.014 * (1.0 if on_floor else 0.3)
	_kick = move_toward(_kick, 0.0, delta * 8.0)
	_swing = move_toward(_swing, 0.0, delta * 4.0)
	_raise = move_toward(_raise, 0.0, delta * 3.2)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			flash_node.visible = false
	# 시점 흔들림(스웨이)
	var cb := get_parent_node_3d().global_basis
	if _last_cam_basis != Basis():
		var dq := (_last_cam_basis.inverse() * cb).get_euler()
		_sway = _sway.lerp(Vector2(clampf(-dq.y * 2.0, -0.06, 0.06), clampf(dq.x * 2.0, -0.05, 0.05)), minf(1.0, delta * 10.0))
	_last_cam_basis = cb
	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, delta * 6.0))
	var pos := BASE_POS
	pos.x += sin(_bob) * bob_amt + _sway.x
	pos.y += absf(cos(_bob)) * bob_amt - _raise * 0.35 + _sway.y
	pos.z += _kick * 0.05
	if not on_floor:
		pos.y += 0.02
	var rot := Vector3(_kick * 0.12 - _raise * 0.6, 0, 0)
	rot.z += slide * 0.35
	pos.x -= slide * 0.03
	if _reload_t > 0.0:
		_reload_t -= delta
		var k := 1.0 - _reload_t / _reload_len
		var dip := sin(k * PI)
		pos.y -= dip * 0.12
		rot.x -= dip * 0.5
		rot.z += dip * 0.6
	if _swing > 0.0:
		var sk := sin((1.0 - _swing) * PI)
		pos += Vector3(-0.12, 0.05, -0.12) * sk
		rot += Vector3(-0.5, 0.9, 0.3) * sk
	rig.position = rig.position.lerp(pos, minf(1.0, delta * 24.0))
	rig.rotation = rig.rotation.lerp(rot, minf(1.0, delta * 24.0))


func _all(n: Node) -> Array:
	var r := [n]
	for c in n.get_children():
		r.append_array(_all(c))
	return r
