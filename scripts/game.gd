extends Node
## 전역 상태: 저장 데이터(열쇠, 해금, 로드아웃, 설정)와 다음 매치 설정

const SAVE_PATH := "user://strike_save.json"

var keys: int = 5
var unlocked: Array = []
var character: String = "blaze"
var loadout := {"primary": "m4a4", "secondary": "glock", "melee": "knife", "utility": "he"}
var sensitivity: float = 1.0
var volume: float = 0.8
var difficulty: int = 1
var stats := {"wins": 0, "losses": 0, "kills": 0, "deaths": 0}

# 다음 매치
var mode: String = "duel1"
var map_id: String = "warehouse"
var last_result: Dictionary = {}

var is_touch: bool = false


func _ready() -> void:
	is_touch = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if OS.get_cmdline_user_args().has("--touch"):
		is_touch = true
	load_save()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))


func is_unlocked(id: String) -> bool:
	if Data.WEAPONS.has(id) and int(Data.WEAPONS[id].get("keys", 0)) == 0:
		return true
	if Data.CHARACTERS.has(id) and int(Data.CHARACTERS[id].get("keys", 0)) == 0:
		return true
	return unlocked.has(id)


func price_of(id: String) -> int:
	if Data.WEAPONS.has(id):
		return int(Data.WEAPONS[id].get("keys", 0))
	if Data.CHARACTERS.has(id):
		return int(Data.CHARACTERS[id].get("keys", 0))
	return 0


func try_unlock(id: String) -> bool:
	if is_unlocked(id):
		return true
	var p := price_of(id)
	if keys < p:
		return false
	keys -= p
	unlocked.append(id)
	save()
	return true


func add_keys(n: int) -> void:
	keys += n
	save()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	save()


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"keys": keys, "unlocked": unlocked, "character": character, "loadout": loadout,
		"sensitivity": sensitivity, "volume": volume, "difficulty": difficulty, "stats": stats,
		"mode": mode, "map": map_id,
	}))


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	keys = int(d.get("keys", keys))
	unlocked = d.get("unlocked", [])
	character = str(d.get("character", character))
	var lo = d.get("loadout", {})
	if typeof(lo) == TYPE_DICTIONARY:
		for k in loadout.keys():
			if lo.has(k) and Data.WEAPONS.has(str(lo[k])):
				loadout[k] = str(lo[k])
	sensitivity = float(d.get("sensitivity", sensitivity))
	volume = float(d.get("volume", volume))
	difficulty = clampi(int(d.get("difficulty", difficulty)), 0, 2)
	var st = d.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in stats.keys():
			stats[k] = int(st.get(k, 0))
	mode = str(d.get("mode", mode))
	if not Data.MODES.has(mode):
		mode = "duel1"
	map_id = str(d.get("map", map_id))
	if not Data.MAPS.has(map_id):
		map_id = "warehouse"
	if not Data.CHARACTERS.has(character):
		character = "blaze"
