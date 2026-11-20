class_name Mats
extends RefCounted
## 재질 캐시. assets/textures/<이름>.jpg|png 가 있으면 텍스처, 없으면 색으로 대체

const FALLBACK := {
	"concrete": Color(0.62, 0.63, 0.65),
	"brick": Color(0.66, 0.33, 0.24),
	"crate": Color(0.62, 0.45, 0.26),
	"metal": Color(0.42, 0.5, 0.58),
	"sand": Color(0.86, 0.74, 0.52),
	"grass": Color(0.36, 0.62, 0.28),
	"sandstone": Color(0.85, 0.76, 0.6),
	"tiles": Color(0.78, 0.79, 0.8),
	"wood": Color(0.55, 0.38, 0.22),
	"leaf": Color(0.28, 0.55, 0.26),
	"trim": Color(0.25, 0.27, 0.3),
	"accent_a": Color(0.2, 0.55, 0.95),
	"accent_b": Color(0.95, 0.35, 0.25),
	"glass": Color(0.6, 0.85, 1.0, 0.35),
	"water": Color(0.25, 0.55, 0.8),
	"target": Color(0.95, 0.95, 0.95),
}
const SCALE := {
	"concrete": 0.25, "brick": 0.33, "crate": 0.5, "metal": 0.33, "sand": 0.2, "grass": 0.25,
	"sandstone": 0.3, "tiles": 0.33, "wood": 0.5,
}

static var _cache := {}


static func get_mat(id: String) -> StandardMaterial3D:
	if _cache.has(id):
		return _cache[id]
	var m := StandardMaterial3D.new()
	m.roughness = 0.85
	var tex: Texture2D = null
	for ext in ["jpg", "png", "webp"]:
		var p := "res://assets/textures/%s.%s" % [id, ext]
		if ResourceLoader.exists(p):
			tex = load(p)
			break
	if tex:
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		var s: float = SCALE.get(id, 0.3)
		m.uv1_scale = Vector3(s, s, s)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		m.albedo_color = FALLBACK.get(id, Color(0.7, 0.7, 0.7))
	if id == "glass":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		m.metallic = 0.3
	if id.begins_with("accent"):
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 0.6
	if id == "metal":
		m.metallic = 0.35
		m.roughness = 0.55
	_cache[id] = m
	return m


static func color_mat(c: Color, emissive: float = 0.0, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var key := "c_%s_%.2f_%.2f_%.2f" % [c.to_html(), emissive, rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	_cache[key] = m
	return m


static func unshaded(c: Color) -> StandardMaterial3D:
	var key := "u_%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m
