class_name Data
extends RefCounted
## 게임 전체에서 쓰는 정적 데이터: 무기 / 캐릭터 / 맵 / 모드

enum Slot { PRIMARY, SECONDARY, MELEE, UTILITY }

# ---------------------------------------------------------------- 무기
# dmg: 1발 피해, rpm: 분당 발사수, mag: 탄창, reserve: 예비탄, reload: 재장전(초)
# spread: 기본 탄퍼짐(도), move_spread: 이동 중 추가 탄퍼짐, recoil: 1발당 반동(도)
# head: 헤드샷 배율, falloff: 25m 당 피해 유지율, auto: 연사 여부
# scope: 조준 시 FOV(0이면 일반 줌), pellets: 산탄 개수, keys: 해금 열쇠
const WEAPONS := {
	"ak47": {"name": "AK-47", "slot": Slot.PRIMARY, "kind": "rifle", "dmg": 36, "rpm": 600, "mag": 30, "reserve": 90,
		"reload": 2.4, "spread": 0.55, "move_spread": 3.5, "recoil": 1.15, "head": 4.0, "falloff": 0.98,
		"auto": true, "scope": 0, "pellets": 1, "keys": 0, "speed": 0.92,
		"color": Color(0.45, 0.28, 0.16), "desc": "강력한 한 방. 헤드샷 한 발이면 끝!"},
	"m4a4": {"name": "M4A4", "slot": Slot.PRIMARY, "kind": "rifle", "dmg": 33, "rpm": 666, "mag": 30, "reserve": 90,
		"reload": 2.2, "spread": 0.45, "move_spread": 3.0, "recoil": 0.85, "head": 4.0, "falloff": 0.97,
		"auto": true, "scope": 0, "pellets": 1, "keys": 0, "speed": 0.93,
		"color": Color(0.22, 0.24, 0.26), "desc": "반동이 적어 다루기 쉬운 소총"},
	"mp5": {"name": "MP5-SD", "slot": Slot.PRIMARY, "kind": "smg", "dmg": 27, "rpm": 750, "mag": 30, "reserve": 120,
		"reload": 2.1, "spread": 0.8, "move_spread": 1.4, "recoil": 0.5, "head": 3.0, "falloff": 0.85,
		"auto": true, "scope": 0, "pellets": 1, "keys": 4, "speed": 1.0,
		"color": Color(0.18, 0.2, 0.22), "desc": "뛰면서 쏘기 좋은 기관단총"},
	"p90": {"name": "P90", "slot": Slot.PRIMARY, "kind": "smg", "dmg": 26, "rpm": 857, "mag": 50, "reserve": 100,
		"reload": 2.6, "spread": 0.9, "move_spread": 1.6, "recoil": 0.45, "head": 3.0, "falloff": 0.84,
		"auto": true, "scope": 0, "pellets": 1, "keys": 8, "speed": 0.97,
		"color": Color(0.3, 0.34, 0.22), "desc": "50발 탄창으로 쉬지 않고 쏜다"},
	"nova": {"name": "Nova", "slot": Slot.PRIMARY, "kind": "shotgun", "dmg": 24, "rpm": 68, "mag": 8, "reserve": 32,
		"reload": 2.8, "spread": 4.5, "move_spread": 1.0, "recoil": 4.0, "head": 2.0, "falloff": 0.45,
		"auto": false, "scope": 0, "pellets": 9, "keys": 6, "speed": 0.95,
		"color": Color(0.35, 0.22, 0.14), "desc": "가까이에선 최강의 산탄총"},
	"ssg08": {"name": "SSG 08", "slot": Slot.PRIMARY, "kind": "sniper", "dmg": 88, "rpm": 48, "mag": 10, "reserve": 30,
		"reload": 2.6, "spread": 3.0, "move_spread": 4.0, "recoil": 3.5, "head": 2.5, "falloff": 1.0,
		"auto": false, "scope": 35, "pellets": 1, "keys": 10, "speed": 1.0,
		"color": Color(0.24, 0.3, 0.36), "desc": "가볍고 빠른 저격총"},
	"awp": {"name": "AWP", "slot": Slot.PRIMARY, "kind": "sniper", "dmg": 115, "rpm": 41, "mag": 5, "reserve": 20,
		"reload": 3.2, "spread": 4.0, "move_spread": 6.0, "recoil": 6.0, "head": 2.0, "falloff": 1.0,
		"auto": false, "scope": 25, "pellets": 1, "keys": 15, "speed": 0.82,
		"color": Color(0.2, 0.32, 0.18), "desc": "몸통 한 방! 전설의 저격총"},
	"glock": {"name": "Glock-18", "slot": Slot.SECONDARY, "kind": "pistol", "dmg": 30, "rpm": 400, "mag": 20, "reserve": 120,
		"reload": 2.2, "spread": 0.9, "move_spread": 1.5, "recoil": 0.9, "head": 3.0, "falloff": 0.85,
		"auto": false, "scope": 0, "pellets": 1, "keys": 0, "speed": 1.05,
		"color": Color(0.15, 0.15, 0.16), "desc": "기본 권총. 탄창이 넉넉해"},
	"usp": {"name": "USP-S", "slot": Slot.SECONDARY, "kind": "pistol", "dmg": 35, "rpm": 352, "mag": 12, "reserve": 24,
		"reload": 2.2, "spread": 0.5, "move_spread": 1.4, "recoil": 1.0, "head": 4.0, "falloff": 0.9,
		"auto": false, "scope": 0, "pellets": 1, "keys": 3, "speed": 1.05,
		"color": Color(0.2, 0.2, 0.22), "desc": "정확하고 조용한 권총"},
	"deagle": {"name": "Desert Eagle", "slot": Slot.SECONDARY, "kind": "pistol", "dmg": 63, "rpm": 267, "mag": 7, "reserve": 35,
		"reload": 2.2, "spread": 0.8, "move_spread": 3.0, "recoil": 3.2, "head": 3.0, "falloff": 0.92,
		"auto": false, "scope": 0, "pellets": 1, "keys": 7, "speed": 1.0,
		"color": Color(0.7, 0.68, 0.62), "desc": "권총계의 대포"},
	"knife": {"name": "나이프", "slot": Slot.MELEE, "kind": "knife", "dmg": 55, "rpm": 100, "mag": 0, "reserve": 0,
		"reload": 0, "spread": 0, "move_spread": 0, "recoil": 0, "head": 1.0, "falloff": 1.0,
		"auto": true, "scope": 0, "pellets": 1, "keys": 0, "speed": 1.15, "range": 2.4,
		"color": Color(0.75, 0.78, 0.82), "desc": "가장 빠르게 달릴 수 있어"},
	"he": {"name": "HE 수류탄", "slot": Slot.UTILITY, "kind": "grenade", "dmg": 98, "rpm": 60, "mag": 1, "reserve": 0,
		"reload": 0, "spread": 0, "move_spread": 0, "recoil": 0, "head": 1.0, "falloff": 1.0,
		"auto": false, "scope": 0, "pellets": 1, "keys": 0, "speed": 1.05, "radius": 6.0, "effect": "explode",
		"color": Color(0.25, 0.35, 0.2), "desc": "폭발로 주변에 큰 피해"},
	"flash": {"name": "섬광탄", "slot": Slot.UTILITY, "kind": "grenade", "dmg": 0, "rpm": 60, "mag": 1, "reserve": 0,
		"reload": 0, "spread": 0, "move_spread": 0, "recoil": 0, "head": 1.0, "falloff": 1.0,
		"auto": false, "scope": 0, "pellets": 1, "keys": 4, "speed": 1.05, "radius": 14.0, "effect": "flash",
		"color": Color(0.6, 0.62, 0.66), "desc": "바라본 적의 눈을 멀게 해"},
	"smoke": {"name": "연막탄", "slot": Slot.UTILITY, "kind": "grenade", "dmg": 0, "rpm": 60, "mag": 1, "reserve": 0,
		"reload": 0, "spread": 0, "move_spread": 0, "recoil": 0, "head": 1.0, "falloff": 1.0,
		"auto": false, "scope": 0, "pellets": 1, "keys": 4, "speed": 1.05, "radius": 4.5, "effect": "smoke",
		"color": Color(0.5, 0.55, 0.6), "desc": "연기로 시야를 가려"},
}

const PRIMARIES := ["m4a4", "ak47", "mp5", "p90", "nova", "ssg08", "awp"]
const SECONDARIES := ["glock", "usp", "deagle"]
const MELEES := ["knife"]
const UTILITIES := ["he", "flash", "smoke"]

# 건게임 순서
const GUN_GAME := ["p90", "mp5", "nova", "m4a4", "ak47", "ssg08", "awp", "deagle", "usp", "glock", "knife"]

# ---------------------------------------------------------------- 캐릭터
# body: 0=기본 1=날렵 2=육중   helmet: visor / cap / hood / heavy / crest / goggles
const CHARACTERS := {
	"blaze": {"name": "블레이즈", "role": "돌격대장", "main": Color(0.86, 0.32, 0.18), "sub": Color(0.16, 0.17, 0.2),
		"accent": Color(1.0, 0.75, 0.2), "skin": Color(0.93, 0.76, 0.62), "helmet": "visor", "body": 0, "keys": 0,
		"desc": "불꽃처럼 뜨거운 승부사"},
	"frost": {"name": "프로스트", "role": "저격수", "main": Color(0.82, 0.9, 0.96), "sub": Color(0.2, 0.38, 0.6),
		"accent": Color(0.4, 0.9, 1.0), "skin": Color(0.98, 0.84, 0.74), "helmet": "goggles", "body": 1, "keys": 0,
		"desc": "차갑고 정확한 눈"},
	"volt": {"name": "볼트", "role": "스피드러너", "main": Color(0.98, 0.8, 0.12), "sub": Color(0.12, 0.12, 0.14),
		"accent": Color(0.3, 0.95, 1.0), "skin": Color(0.62, 0.42, 0.3), "helmet": "crest", "body": 1, "keys": 0,
		"desc": "번개보다 빠른 발"},
	"ranger": {"name": "레인저", "role": "정찰병", "main": Color(0.46, 0.5, 0.32), "sub": Color(0.55, 0.45, 0.32),
		"accent": Color(0.95, 0.55, 0.15), "skin": Color(0.85, 0.66, 0.5), "helmet": "cap", "body": 0, "keys": 3,
		"desc": "숲과 사막의 베테랑"},
	"viper": {"name": "바이퍼", "role": "전략가", "main": Color(0.18, 0.62, 0.38), "sub": Color(0.1, 0.14, 0.12),
		"accent": Color(0.7, 1.0, 0.3), "skin": Color(0.95, 0.8, 0.68), "helmet": "hood", "body": 1, "keys": 5,
		"desc": "조용히 다가가는 그림자"},
	"nova": {"name": "노바", "role": "지원가", "main": Color(0.58, 0.36, 0.86), "sub": Color(0.95, 0.95, 0.98),
		"accent": Color(1.0, 0.45, 0.75), "skin": Color(0.78, 0.58, 0.44), "helmet": "visor", "body": 1, "keys": 5,
		"desc": "별빛 에너지의 수호자"},
	"titan": {"name": "타이탄", "role": "탱커", "main": Color(0.45, 0.48, 0.52), "sub": Color(0.9, 0.5, 0.12),
		"accent": Color(1.0, 0.85, 0.3), "skin": Color(0.7, 0.5, 0.38), "helmet": "heavy", "body": 2, "keys": 8,
		"desc": "무너지지 않는 강철 벽"},
	"shadow": {"name": "섀도우", "role": "암살자", "main": Color(0.12, 0.12, 0.16), "sub": Color(0.3, 0.3, 0.36),
		"accent": Color(1.0, 0.2, 0.28), "skin": Color(0.9, 0.74, 0.62), "helmet": "hood", "body": 1, "keys": 10,
		"desc": "어둠 속의 붉은 눈"},
}
const CHARACTER_ORDER := ["blaze", "frost", "volt", "ranger", "viper", "nova", "titan", "shadow"]

# ---------------------------------------------------------------- 맵
const MAPS := {
	"warehouse": {"name": "물류 창고", "desc": "상자 사이 근거리 전투", "sky_top": Color(0.35, 0.55, 0.85), "sky_horizon": Color(0.75, 0.82, 0.9),
		"sun": Color(1.0, 0.96, 0.88), "ambient": 0.6, "floor": "concrete", "wall": "metal", "fog": Color(0.7, 0.75, 0.82)},
	"dust": {"name": "사막 마을", "desc": "모래 골목과 긴 직선", "sky_top": Color(0.3, 0.55, 0.9), "sky_horizon": Color(0.95, 0.85, 0.7),
		"sun": Color(1.0, 0.92, 0.78), "ambient": 0.65, "floor": "sand", "wall": "sandstone", "fog": Color(0.95, 0.85, 0.7)},
	"rooftop": {"name": "도시 옥상", "desc": "높낮이가 있는 옥상 결투", "sky_top": Color(0.2, 0.35, 0.75), "sky_horizon": Color(0.95, 0.65, 0.5),
		"sun": Color(1.0, 0.82, 0.65), "ambient": 0.6, "floor": "tiles", "wall": "brick", "fog": Color(0.95, 0.7, 0.6)},
	"park": {"name": "중앙 공원", "desc": "나무와 다리가 있는 공원", "sky_top": Color(0.3, 0.6, 0.95), "sky_horizon": Color(0.8, 0.92, 1.0),
		"sun": Color(1.0, 0.98, 0.9), "ambient": 0.7, "floor": "grass", "wall": "brick", "fog": Color(0.8, 0.9, 0.95)},
	"crossroads": {"name": "크로스로드", "desc": "건물 사이 네 갈래 길", "sky_top": Color(0.25, 0.45, 0.8), "sky_horizon": Color(0.85, 0.88, 0.92),
		"sun": Color(1.0, 0.95, 0.85), "ambient": 0.6, "floor": "concrete", "wall": "brick", "fog": Color(0.8, 0.84, 0.9)},
	"range": {"name": "사격 훈련장", "desc": "저격수를 위한 긴 레인", "sky_top": Color(0.3, 0.5, 0.85), "sky_horizon": Color(0.85, 0.9, 0.95),
		"sun": Color(1.0, 0.97, 0.9), "ambient": 0.65, "floor": "sand", "wall": "crate", "fog": Color(0.85, 0.88, 0.9)},
}
const MAP_ORDER := ["warehouse", "dust", "rooftop", "park", "crossroads", "range"]

# ---------------------------------------------------------------- 모드
const MODES := {
	"duel1": {"name": "1 vs 1 듀얼", "type": "duel", "team_size": 1, "win": 5},
	"duel2": {"name": "2 vs 2 듀얼", "type": "duel", "team_size": 2, "win": 5},
	"duel3": {"name": "3 vs 3 듀얼", "type": "duel", "team_size": 3, "win": 5},
	"duel5": {"name": "5 vs 5 듀얼", "type": "duel", "team_size": 5, "win": 5},
	"ffa": {"name": "개인전", "type": "ffa", "players": 6, "win": 15},
	"gungame": {"name": "건게임", "type": "gungame", "players": 6, "win": 11},
}
const MODE_ORDER := ["duel1", "duel2", "duel3", "duel5", "ffa", "gungame"]

const DIFFICULTY := [
	{"name": "쉬움", "react": 0.75, "aim_err": 3.2, "accuracy": 0.35, "strafe": 0.4},
	{"name": "보통", "react": 0.45, "aim_err": 1.8, "accuracy": 0.55, "strafe": 0.7},
	{"name": "어려움", "react": 0.25, "aim_err": 0.9, "accuracy": 0.75, "strafe": 1.0},
]

const BOT_NAMES := ["번개토끼", "아이언팽", "슈팅스타", "블루호크", "레드폭스", "킹코브라", "실버울프", "썬더볼", "제트팬더", "나이트오울", "스톰베어", "파이어링크스"]


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["glock"])


static func character(id: String) -> Dictionary:
	return CHARACTERS.get(id, CHARACTERS["blaze"])
