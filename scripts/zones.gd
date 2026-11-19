extends RefCounted
## Bölgeler: aynı dünyada birbirinden uzak dikdörtgenler; aralarında portallarla geçilir.
## Her bölgenin zemini, engelleri ve süslemeleri seed ile üretilir (tüm peer'larda aynı).

const ORDER := ["meadow", "graveyard", "glacier", "volcano", "ocean"]
const ZONES := {
	"meadow": {"name": "Kadim Çayır", "rect": Rect2(0, 0, 3200, 3200), "level": 1,
		"entry": Vector2(1600, 1600), "color": Color(0.27, 0.5, 0.24), "seed": 20261006},
	"graveyard": {"name": "Unutulmuş Mezarlık", "rect": Rect2(4400, 0, 2400, 2400), "level": 5,
		"entry": Vector2(4660, 1200), "color": Color(0.24, 0.27, 0.3), "seed": 7101,
		"max": 16, "types": [["zombie", 0.45], ["skeleton", 0.35], ["ghost", 0.2]],
		"obstacles": [["tomb", 0.55, 12, 18], ["deadtree", 0.3, 18, 28], ["rock", 0.15, 14, 22]]},
	"glacier": {"name": "Ebedi Buzul", "rect": Rect2(7600, 0, 2400, 2400), "level": 9,
		"entry": Vector2(7860, 1200), "color": Color(0.82, 0.88, 0.94), "seed": 7202,
		"max": 16, "types": [["snow_wolf", 0.45], ["yeti", 0.35], ["ice_golem", 0.2]],
		"obstacles": [["snowpine", 0.5, 20, 30], ["ice", 0.3, 14, 24], ["snowrock", 0.2, 14, 24]]},
	"volcano": {"name": "Kızıl Volkan", "rect": Rect2(10800, 0, 2400, 2400), "level": 13,
		"entry": Vector2(11060, 1200), "color": Color(0.2, 0.15, 0.14), "seed": 7303,
		"max": 16, "types": [["lava_slime", 0.55], ["imp", 0.45]],
		"obstacles": [["basalt", 0.5, 14, 26], ["obsidian", 0.35, 12, 20], ["vent", 0.15, 16, 20]]},
	# Okyanus: suda tekneyle gidilir, adalarda yürünür. Kara canavarları sudan çıkamaz, Kraken karaya çıkamaz.
	"ocean": {"name": "Engin Okyanus", "rect": Rect2(0, 4400, 6000, 4000), "level": 7,
		"entry": Vector2(560, 6400), "color": Color(0.16, 0.42, 0.62), "seed": 7404,
		"max": 18, "types": [["crab", 0.5], ["pirate", 0.5]],
		"obstacles": [["palm", 0.65, 20, 30], ["rock", 0.35, 14, 22]]},
}
## Adalar: [ad, merkez, yarıçap]. Her adanın kıyısı birkaç daireden oluşur (seed'li).
const ISLANDS := [
	["Liman Adası", Vector2(420, 6400), 260.0],
	["Palmiye Adası", Vector2(1750, 5300), 380.0],
	["Yengeç Adası", Vector2(2350, 7350), 330.0],
	["Korsan Koyu", Vector2(3700, 5900), 450.0],
	["Kayıp Ada", Vector2(5150, 7050), 380.0],
]
## Portallar: çayırdaki yol uçlarından bölgelere, her bölgenin girişinden çayıra.
const PORTALS := [
	{"pos": Vector2(3080, 1600), "to": "graveyard"},
	{"pos": Vector2(1600, 120), "to": "glacier"},
	{"pos": Vector2(1600, 3080), "to": "volcano"},
	{"pos": Vector2(120, 1600), "to": "ocean"},
	{"pos": Vector2(4520, 1200), "to": "meadow", "back": "graveyard"},
	{"pos": Vector2(7720, 1200), "to": "meadow", "back": "glacier"},
	{"pos": Vector2(10920, 1200), "to": "meadow", "back": "volcano"},
	{"pos": Vector2(300, 6400), "to": "meadow", "back": "ocean"},
]
const SAFE_RADIUS := 380.0

static var _cache := {}


static func zone_at(pos: Vector2) -> String:
	for id in ORDER:
		if ZONES[id].rect.grow(200.0).has_point(pos):
			return id
	return "meadow"


static func level_of(zone: String) -> int:
	return ZONES[zone].level


## Portaldan çıkınca varılan nokta: bölgeye girerken bölgenin girişi, çayıra dönerken
## o bölgeye açılan çayır portalının biraz içi.
static func arrival(portal: Dictionary) -> Vector2:
	if portal.to != "meadow":
		return ZONES[portal.to].entry + Vector2(randf_range(-20, 20), randf_range(-40, 40))
	for p in PORTALS:
		if p.to == portal.back:
			return p.pos + (ZONES.meadow.entry - p.pos).normalized() * 120.0
	return ZONES.meadow.entry


## Bölgenin engelleri ve süslemeleri (önbellekli, deterministik).
## {"obstacles": [[pos, kind, size, variant]], "pools": [[pos, r]] (lav), "decor": [[pos, r, kind]]}
static func layout(zone: String) -> Dictionary:
	if _cache.has(zone):
		return _cache[zone]
	var z: Dictionary = ZONES[zone]
	var out := {"obstacles": [], "pools": [], "decor": []}
	if zone == "meadow":
		_cache[zone] = out  # çayırın engelleri world.gd'de eski yöntemle üretilir
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = z.seed
	if zone == "ocean":
		out["land"] = _island_blobs(rng)
		out.obstacles = _island_obstacles(rng, out.land, z.entry)
		_cache[zone] = out
		return out
	var r: Rect2 = z.rect
	var entry: Vector2 = z.entry
	# Süslemeler: volkanda lav gölleri, buzulda donmuş göletler, mezarlıkta sis ve açık mezarlar
	var decor_count: int = {"graveyard": 26, "glacier": 10, "volcano": 16}[zone]
	for i in decor_count:
		var p := Vector2(rng.randf_range(r.position.x + 150, r.end.x - 150), rng.randf_range(r.position.y + 150, r.end.y - 150))
		var rad := rng.randf_range(50, 115) if zone != "graveyard" else rng.randf_range(40, 90)
		if p.distance_to(entry) < SAFE_RADIUS + rad or absf(p.y - entry.y) < 70.0 + rad * 0.5:
			continue
		if zone == "volcano":
			out.pools.append([p, rad])
		else:
			out.decor.append([p, rad, "pond" if zone == "glacier" else ("grave" if i % 3 == 0 else "fog")])
	# Engeller
	var spots: Array[Vector2] = []
	for i in 260:
		var p := Vector2(rng.randf_range(r.position.x + 60, r.end.x - 60), rng.randf_range(r.position.y + 70, r.end.y - 40))
		var roll := rng.randf()
		var kind := ""
		var lo := 14.0
		var hi := 24.0
		var acc := 0.0
		for row in z.obstacles:
			acc += row[1]
			if roll < acc:
				kind = row[0]
				lo = row[2]
				hi = row[3]
				break
		if kind == "":
			kind = z.obstacles[0][0]
		var s := rng.randf_range(lo, hi)
		var v := rng.randi() % 100
		if p.distance_to(entry) < 230.0 or absf(p.y - entry.y) < 60.0:
			continue  # giriş kampı ve ana yol açık kalsın
		var blocked := false
		for pool in out.pools:
			if p.distance_to(pool[0]) < pool[1] + 30.0:
				blocked = true
				break
		for d in out.decor:
			if d[2] == "pond" and p.distance_to(d[0]) < d[1] + 20.0:
				blocked = true
				break
		if blocked:
			continue
		for o in spots:
			if o.distance_to(p) < 58.0:
				blocked = true
				break
		if blocked:
			continue
		spots.append(p)
		out.obstacles.append([p, kind, s, v])
	_cache[zone] = out
	return out


static func in_lava(pos: Vector2) -> bool:
	if not ZONES.volcano.rect.has_point(pos):
		return false
	for pool in layout("volcano").pools:
		if pos.distance_to(pool[0]) < pool[1] * 0.92:
			return true
	return false


## Her ada: ana daire + 3-4 küçük daire (kıyı girintileri). [[merkez, yarıçap, ada_no]]
static func _island_blobs(rng: RandomNumberGenerator) -> Array:
	var blobs := []
	for i in ISLANDS.size():
		var c: Vector2 = ISLANDS[i][1]
		var r: float = ISLANDS[i][2]
		blobs.append([c, r, i])
		for k in (3 if i == 0 else 4):
			var a := rng.randf() * TAU
			blobs.append([c + Vector2.from_angle(a) * r * rng.randf_range(0.45, 0.75), r * rng.randf_range(0.35, 0.55), i])
	return blobs


static func _island_obstacles(rng: RandomNumberGenerator, blobs: Array, entry: Vector2) -> Array:
	var obs := []
	var spots: Array[Vector2] = []
	for i in range(1, ISLANDS.size()):
		var c: Vector2 = ISLANDS[i][1]
		var r: float = ISLANDS[i][2]
		for k in int(r / 14.0):
			var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r * 0.95
			var palm := rng.randf() < 0.65
			var s := rng.randf_range(20, 30) if palm else rng.randf_range(14, 22)
			var v := rng.randi() % 100
			if not _blob_land(blobs, p, -40.0) or p.distance_to(c) < r * 0.28:
				continue  # kıyıya çok yakın değil; ada ortası (kamp yeri) açık
			var crowded := false
			for o in spots:
				if o.distance_to(p) < 62.0:
					crowded = true
					break
			if crowded:
				continue
			spots.append(p)
			obs.append([p, "palm" if palm else "rock", s, v])
	# Liman adasına birkaç palmiye (iskeleyi kapatmadan)
	for k in 5:
		var p := ISLANDS[0][1] + Vector2.from_angle(TAU * k / 5.0 + 0.4) * 170.0
		if p.distance_to(entry) > 120.0:
			obs.append([p, "palm", 24.0, k * 17])
	return obs


static func _blob_land(blobs: Array, pos: Vector2, margin := 0.0) -> bool:
	for b in blobs:
		if pos.distance_to(b[0]) < b[1] + margin:
			return true
	return false


## Okyanusta bu nokta kara mı? (Okyanus dışında her yer kara sayılır.)
static func is_land(pos: Vector2) -> bool:
	if not ZONES.ocean.rect.grow(200.0).has_point(pos):
		return true
	return _blob_land(layout("ocean").land, pos)


## Bu nokta hangi adada? Değilse "".
static func island_at(pos: Vector2) -> String:
	if not ZONES.ocean.rect.has_point(pos):
		return ""
	for b in layout("ocean").land:
		if pos.distance_to(b[0]) < b[1]:
			return ISLANDS[b[2]][0]
	return ""
