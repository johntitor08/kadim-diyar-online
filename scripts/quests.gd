extends RefCounted
## Kâhin'in görevleri: belli sayıda canavar avla, dön, ödülü al.

const NAMES := {"slime": "Balçık", "wolf": "Kurt", "orc": "Ork", "boss": "Kadim Dev",
	"zombie": "Zombi", "skeleton": "İskelet Okçu", "ghost": "Hayalet", "snow_wolf": "Kar Kurdu", "yeti": "Yeti",
	"ice_golem": "Buz Golemi", "lava_slime": "Lav Balçığı", "imp": "Ateş İblisi", "dragon": "Ejderha",
	"crab": "Dev Yengeç", "pirate": "Korsan", "kraken": "Kraken"}
const BOSSES := ["boss", "dragon", "kraken"]
## Görevin nerede yapıldığı (Kâhin'in sözünde söylenir)
const WHERE := {"zombie": "Mezarlık", "skeleton": "Mezarlık", "ghost": "Mezarlık", "snow_wolf": "Buzul",
	"yeti": "Buzul", "ice_golem": "Buzul", "lava_slime": "Volkan", "imp": "Volkan", "dragon": "Volkan",
	"crab": "Okyanus", "pirate": "Okyanus", "kraken": "Okyanus"}
## tür -> [kaç tane, altın, XP, ödül eşyasının en düşük nadirliği, en yüksek nadirliği]
const TABLE := {
	"slime": [8, 60, 80, 0, 0],
	"wolf": [6, 120, 160, 0, 1],
	"orc": [5, 250, 350, 1, 1],
	"boss": [1, 500, 800, 1, 2],
	"zombie": [6, 180, 300, 1, 1], "skeleton": [6, 200, 320, 1, 1], "ghost": [5, 200, 320, 1, 1],
	"crab": [6, 260, 450, 1, 1], "pirate": [5, 300, 520, 1, 2],
	"snow_wolf": [6, 320, 600, 1, 1], "yeti": [4, 380, 700, 1, 2], "ice_golem": [3, 400, 750, 1, 2],
	"lava_slime": [5, 480, 1000, 1, 2], "imp": [5, 520, 1100, 1, 2],
	"dragon": [1, 2000, 3000, 2, 2], "kraken": [1, 1800, 2600, 2, 2],
}


static func pick_kind(level: int) -> String:
	var r := randf()
	var pool: Array
	if level < 4:
		pool = ["slime", "slime", "wolf"]
	elif level < 5:
		pool = ["wolf", "orc"]
	elif level < 7:
		pool = ["orc", "zombie", "skeleton", "ghost"]
	elif level < 9:
		pool = ["zombie", "skeleton", "ghost", "crab", "pirate", "boss"]
	elif level < 13:
		pool = ["snow_wolf", "yeti", "ice_golem", "pirate", "boss", "kraken"]
	else:
		pool = ["lava_slime", "imp", "ice_golem", "dragon", "kraken"]
	return pool[int(r * pool.size()) % pool.size()]


static func need_of(kind: String, test_mode: bool) -> int:
	var n: int = TABLE[kind][0]
	return mini(n, 2) if test_mode else n


static func describe(kind: String, have: int, need: int) -> String:
	var where: String = (" — " + WHERE[kind]) if WHERE.has(kind) else ""
	if kind in BOSSES:
		var text: String = {"boss": "Kadim Dev'i yen", "dragon": "Ejderha'yı yen", "kraken": "Kraken'i yen"}[kind]
		return "%s%s (%d/%d)" % [text, where, have, need]
	return "%d %s avla%s (%d/%d)" % [need, NAMES.get(kind, kind), where, have, need]
