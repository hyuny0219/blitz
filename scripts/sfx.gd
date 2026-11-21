extends Node
## 효과음: 2D(내 소리)와 3D(위치 소리) 풀

const NAMES := ["rifle", "smg", "pistol", "deagle", "sniper", "shotgun", "explosion", "hit", "headshot", "kill",
	"beep", "go", "win", "lose", "click", "ui", "unlock", "reload", "empty", "swap", "bounce", "swing", "step",
	"jump", "flash", "smoke", "hurt", "slide"]

var _streams := {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _i2 := 0
var _i3 := 0


func _ready() -> void:
	for n in NAMES:
		var p := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in 12:
		var a := AudioStreamPlayer.new()
		add_child(a)
		_pool2d.append(a)
	for i in 16:
		var b := AudioStreamPlayer3D.new()
		b.unit_size = 8.0
		b.max_distance = 80.0
		b.attenuation_filter_cutoff_hz = 6000
		add_child(b)
		_pool3d.append(b)


func play(n: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(n):
		return
	var a := _pool2d[_i2]
	_i2 = (_i2 + 1) % _pool2d.size()
	a.stream = _streams[n]
	a.volume_db = vol_db
	a.pitch_scale = pitch * randf_range(0.96, 1.04)
	a.play()


func play_at(n: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(n):
		return
	var b := _pool3d[_i3]
	_i3 = (_i3 + 1) % _pool3d.size()
	b.stream = _streams[n]
	b.global_position = pos
	b.volume_db = vol_db
	b.pitch_scale = pitch * randf_range(0.95, 1.05)
	b.play()


func gun_sound(kind: String, wid: String) -> String:
	if wid == "deagle":
		return "deagle"
	match kind:
		"rifle": return "rifle"
		"smg": return "smg"
		"pistol": return "pistol"
		"sniper": return "sniper"
		"shotgun": return "shotgun"
	return "pistol"
