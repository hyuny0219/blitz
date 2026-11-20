class_name Grenade
extends RigidBody3D
## 던지는 수류탄. 시간이 지나면 터지고 match 에 알린다.

var kind := "he"
var thrower: Node = null
var fuse := 1.6
var _bounced := 0.0


func setup(wid: String, who: Node, vel: Vector3) -> void:
	kind = wid
	thrower = who
	fuse = 1.5 if wid != "smoke" else 1.3
	collision_layer = 4
	collision_mask = 1
	mass = 0.4
	linear_velocity = vel
	angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.8
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.08
	cs.shape = sh
	add_child(cs)
	var model := WeaponModel.build(wid)
	model.scale = Vector3.ONE * 1.4
	add_child(model)
	body_entered.connect(_on_hit)


func _on_hit(_b: Node) -> void:
	if _bounced <= 0.0 and linear_velocity.length() > 2.0:
		Sfx.play_at("bounce", global_position, -6.0)
		_bounced = 0.15


func _physics_process(delta: float) -> void:
	_bounced -= delta
	fuse -= delta
	if fuse <= 0.0:
		var m := get_tree().get_first_node_in_group("match")
		if m:
			m.on_grenade(kind, global_position, thrower)
		queue_free()
