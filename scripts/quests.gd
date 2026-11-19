extends RefCounted
## Kâhin'in görevleri: belli sayıda canavar avla, dön, ödülü al.

const NAMES := {"slime": "Balçık", "wolf": "Kurt", "orc": "Ork", "boss": "Kadim Dev"}
## tür -> [kaç tane, altın, XP, ödül eşyasının en düşük nadirliği, en yüksek nadirliği]
const TABLE := {
	"slime": [8, 60, 80, 0, 0],
	"wolf": [6, 120, 160, 0, 1],
	"orc": [5, 250, 350, 1, 1],
	"boss": [1, 500, 800, 1, 2],
}


static func pick_kind(level: int) -> String:
	var r := randf()
	if level < 4:
		return "slime" if r < 0.65 else "wolf"
	if level < 8:
		return "wolf" if r < 0.55 else "orc"
	return "orc" if r < 0.6 else "boss"


static func need_of(kind: String, test_mode: bool) -> int:
	var n: int = TABLE[kind][0]
	return mini(n, 2) if test_mode else n


static func describe(kind: String, have: int, need: int) -> String:
	if kind == "boss":
		return "Kadim Dev'i yen (%d/%d)" % [have, need]
	return "%d %s avla (%d/%d)" % [need, NAMES.get(kind, kind), have, need]
