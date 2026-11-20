class_name WeaponModel
extends RefCounted
## 무기 3D 모델(상자 조합). 총구는 -Z 방향. 반환 노드에 "muzzle" 마커 포함.


static func build(wid: String) -> Node3D:
	var w: Dictionary = Data.weapon(wid)
	var root := Node3D.new()
	root.name = "Gun_" + wid
	var body := Mats.color_mat(w.color, 0.0, 0.45, 0.35)
	var dark := Mats.color_mat(Color(0.08, 0.08, 0.09), 0.0, 0.4, 0.5)
	var metal := Mats.color_mat(Color(0.55, 0.57, 0.6), 0.0, 0.3, 0.8)
	var wood := Mats.color_mat(Color(0.5, 0.3, 0.15), 0.0, 0.6)
	var accent := Mats.color_mat(Color(1.0, 0.6, 0.15), 0.8)
	var muzzle_z := -0.4
	match wid:
		"ak47":
			_p(root, dark, Vector3(0, 0, -0.05), Vector3(0.06, 0.09, 0.42))
			_p(root, wood, Vector3(0, -0.01, -0.33), Vector3(0.065, 0.07, 0.18))
			_p(root, metal, Vector3(0, 0.02, -0.55), Vector3(0.025, 0.025, 0.32))
			_p(root, dark, Vector3(0, 0.05, -0.42), Vector3(0.02, 0.05, 0.02))
			_p(root, wood, Vector3(0, -0.03, 0.27), Vector3(0.05, 0.1, 0.24))
			_p(root, dark, Vector3(0, -0.13, -0.12), Vector3(0.05, 0.18, 0.07), -0.35)
			_p(root, wood, Vector3(0, -0.1, 0.07), Vector3(0.045, 0.12, 0.05), 0.3)
			muzzle_z = -0.72
		"m4a4":
			_p(root, body, Vector3(0, 0, -0.05), Vector3(0.06, 0.09, 0.4))
			_p(root, dark, Vector3(0, 0, -0.33), Vector3(0.07, 0.075, 0.2))
			_p(root, metal, Vector3(0, 0.0, -0.53), Vector3(0.022, 0.022, 0.24))
			_p(root, dark, Vector3(0, 0.075, -0.02), Vector3(0.025, 0.05, 0.2))
			_p(root, dark, Vector3(0, -0.02, 0.27), Vector3(0.05, 0.09, 0.22))
			_p(root, dark, Vector3(0, -0.13, -0.12), Vector3(0.05, 0.18, 0.07), -0.15)
			_p(root, dark, Vector3(0, -0.1, 0.07), Vector3(0.045, 0.12, 0.05), 0.3)
			_p(root, accent, Vector3(0.031, 0.0, -0.1), Vector3(0.004, 0.02, 0.15))
			muzzle_z = -0.66
		"mp5":
			_p(root, body, Vector3(0, 0, -0.05), Vector3(0.055, 0.085, 0.34))
			_p(root, dark, Vector3(0, 0, -0.32), Vector3(0.065, 0.07, 0.2))
			_p(root, dark, Vector3(0, -0.12, -0.12), Vector3(0.035, 0.17, 0.05), -0.2)
			_p(root, dark, Vector3(0, -0.09, 0.06), Vector3(0.04, 0.11, 0.05), 0.3)
			_p(root, metal, Vector3(0, 0.0, 0.2), Vector3(0.02, 0.05, 0.16))
			muzzle_z = -0.45
		"p90":
			_p(root, body, Vector3(0, -0.02, -0.05), Vector3(0.07, 0.13, 0.5))
			_p(root, Mats.color_mat(Color(0.8, 0.75, 0.4, 0.8)), Vector3(0, 0.06, -0.05), Vector3(0.05, 0.03, 0.3))
			_p(root, dark, Vector3(0, 0.0, -0.33), Vector3(0.025, 0.025, 0.08))
			muzzle_z = -0.38
		"nova":
			_p(root, dark, Vector3(0, 0, -0.05), Vector3(0.06, 0.09, 0.3))
			_p(root, metal, Vector3(0, 0.02, -0.42), Vector3(0.035, 0.035, 0.5))
			_p(root, body, Vector3(0, -0.04, -0.35), Vector3(0.055, 0.05, 0.2))
			_p(root, body, Vector3(0, -0.04, 0.25), Vector3(0.05, 0.1, 0.25))
			_p(root, dark, Vector3(0, -0.09, 0.06), Vector3(0.04, 0.11, 0.05), 0.3)
			muzzle_z = -0.68
		"ssg08", "awp":
			var long := wid == "awp"
			_p(root, body, Vector3(0, -0.01, 0.0), Vector3(0.07, 0.1, 0.62 if long else 0.52))
			_p(root, metal, Vector3(0, 0.02, -0.55 if long else -0.47), Vector3(0.025, 0.025, 0.42 if long else 0.36))
			_p(root, dark, Vector3(0, 0.1, -0.02), Vector3(0.045, 0.045, 0.3))
			_p(root, Mats.color_mat(Color(0.2, 0.6, 1.0), 1.0), Vector3(0, 0.1, -0.175), Vector3(0.035, 0.035, 0.005))
			_p(root, dark, Vector3(0, -0.09, 0.08), Vector3(0.04, 0.11, 0.05), 0.3)
			_p(root, dark, Vector3(0, -0.07, -0.1), Vector3(0.035, 0.08, 0.06))
			muzzle_z = -0.78 if long else -0.67
		"glock", "usp", "deagle":
			var big := wid == "deagle"
			var ln := 0.24 if big else 0.19
			_p(root, body, Vector3(0, 0.0, -ln * 0.4), Vector3(0.04 if not big else 0.05, 0.06, ln))
			_p(root, dark, Vector3(0, -0.07, 0.02), Vector3(0.035, 0.12, 0.05), 0.25)
			if wid == "usp":
				_p(root, dark, Vector3(0, 0.0, -0.22), Vector3(0.035, 0.035, 0.14))
				muzzle_z = -0.3
			else:
				muzzle_z = -ln * 0.9 - 0.02
		"knife":
			_p(root, dark, Vector3(0, 0, 0.02), Vector3(0.03, 0.035, 0.12))
			_p(root, metal, Vector3(0, 0.005, -0.12), Vector3(0.006, 0.04, 0.18))
			_p(root, accent, Vector3(0, 0, -0.04), Vector3(0.05, 0.05, 0.01))
			muzzle_z = -0.22
		"he", "flash", "smoke":
			var g := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.12 if wid == "he" else 0.1
			sm.radial_segments = 10
			sm.rings = 6
			if wid != "he":
				var cm := CylinderMesh.new()
				cm.top_radius = 0.035
				cm.bottom_radius = 0.035
				cm.height = 0.13
				g.mesh = cm
				g.rotation.x = PI / 2
			else:
				g.mesh = sm
			g.material_override = Mats.color_mat(w.color, 0.0, 0.5)
			root.add_child(g)
			_p(root, metal, Vector3(0, 0.06, 0), Vector3(0.02, 0.03, 0.02))
			muzzle_z = -0.05
	var m := Marker3D.new()
	m.name = "muzzle"
	m.position = Vector3(0, 0.02, muzzle_z)
	root.add_child(m)
	return root


static func _p(root: Node3D, mat: Material, pos: Vector3, size: Vector3, rot_x: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.x = rot_x
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
