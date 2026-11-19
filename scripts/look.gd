extends RefCounted
## Karakter görünümü: seçenek tabloları ve çizim.
## Oyundaki karakter de menüdeki önizleme de buradaki draw() ile çizilir.
## Ayaklar (0, 0) noktasındadır; karakter yukarı (eksi y) doğru uzanır.

const SKINS := [Color(1.0, 0.87, 0.74), Color(0.96, 0.77, 0.62), Color(0.84, 0.62, 0.45),
	Color(0.66, 0.46, 0.31), Color(0.45, 0.31, 0.21)]
const SKIN_NAMES := ["Açık", "Buğday", "Esmer", "Kumral", "Koyu"]
const HAIR_STYLES := ["Kısa", "Uzun", "At kuyruğu", "Dikenli", "Kel"]
const HAIR_COLORS := [Color(0.13, 0.11, 0.11), Color(0.36, 0.21, 0.11), Color(0.62, 0.42, 0.22),
	Color(0.93, 0.79, 0.42), Color(0.76, 0.27, 0.13), Color(0.88, 0.88, 0.9), Color(0.32, 0.47, 0.86)]
const HAIR_COLOR_NAMES := ["Siyah", "Kahverengi", "Açık kahve", "Sarı", "Kızıl", "Beyaz", "Mavi"]
const OUTFITS := [Color(0.76, 0.22, 0.2), Color(0.23, 0.41, 0.78), Color(0.26, 0.6, 0.31),
	Color(0.51, 0.31, 0.71), Color(0.9, 0.55, 0.16), Color(0.15, 0.6, 0.62), Color(0.32, 0.32, 0.36)]
const OUTFIT_NAMES := ["Kırmızı", "Mavi", "Yeşil", "Mor", "Turuncu", "Turkuaz", "Kömür"]

## Alan adı -> [başlık, seçenek adları]
const FIELDS := {
	"skin": ["Ten", SKIN_NAMES],
	"hair": ["Saç", HAIR_STYLES],
	"hair_color": ["Saç rengi", HAIR_COLOR_NAMES],
	"outfit": ["Kıyafet", OUTFIT_NAMES],
}
## Eşya nadirliğine göre zırh ve kılıç renkleri: sıradan, nadir, efsanevi.
const GEAR_COLORS := [Color(0.72, 0.74, 0.79), Color(0.36, 0.6, 1.0), Color(1.0, 0.66, 0.2)]


## Ağdan ya da diskten gelen görünümü güvenli hale getirir.
static func sanitize(value) -> Dictionary:
	var src: Dictionary = value if value is Dictionary else {}
	var out := {}
	for key in FIELDS:
		var v = src.get(key, 0)
		var n: int = FIELDS[key][1].size()
		out[key] = posmod(int(v), n) if (v is int or v is float) else 0
	return out


static func random_look() -> Dictionary:
	var out := {}
	for key in FIELDS:
		out[key] = randi() % FIELDS[key][1].size()
	return out


## s: {facing, walk, moving, flash, dead, armor (-1..2), weapon (-1..2), sword_angle, show_sword,
##     origin, scale}  origin/scale: önizleme gibi büyütülmüş çizimler için (iç dönüşümler bunu korur).
static func draw(ci: CanvasItem, look: Dictionary, s: Dictionary) -> void:
	var o: Vector2 = s.get("origin", Vector2.ZERO)
	var k: float = s.get("scale", 1.0)
	ci.draw_set_transform(o, 0.0, Vector2(k, k))
	var facing: Vector2 = s.get("facing", Vector2(0.3, 1.0)).normalized()
	var walk: float = s.get("walk", 0.0)
	var moving: bool = s.get("moving", false)
	var flash: float = s.get("flash", 0.0)
	var dead: bool = s.get("dead", false)
	var armor: int = s.get("armor", -1)
	var lk := sanitize(look)
	var skin := _tint(SKINS[lk.skin], flash, dead)
	var hair := _tint(HAIR_COLORS[lk.hair_color], flash, dead)
	var cloth := _tint(OUTFITS[lk.outfit], flash, dead)
	var bob := sin(walk) * 1.6 if moving else 0.0
	var step := sin(walk) * 3.0 if moving else 0.0
	var back := facing.y < -0.55
	var side := signf(facing.x) if absf(facing.x) > 0.15 else 0.0

	# Gölge
	ci.draw_set_transform(o, 0.0, Vector2(k, k * 0.38))
	ci.draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.3))
	ci.draw_set_transform(o, 0.0, Vector2(k, k))

	# Bacaklar ve çizmeler
	var pants := cloth.darkened(0.5)
	var boot := _tint(Color(0.3, 0.2, 0.13), flash, dead)
	for lr in [-1.0, 1.0]:
		var off: float = step * lr
		ci.draw_rect(Rect2(Vector2(lr * 5.0 - 2.5, -13.0 + off * 0.3), Vector2(5.0, 9.0)), pants)
		ci.draw_rect(Rect2(Vector2(lr * 5.0 - 3.2, -5.5 + off), Vector2(6.4, 5.0)), boot)

	var torso := Vector2(0, -20.0 + bob)
	var head := Vector2(0, -36.0 + bob)
	var sword_behind := facing.y < -0.2

	# Arkada kalan saç parçaları (uzun saç, at kuyruğu)
	if lk.hair == 1:
		var top := head + Vector2(0, -2)
		var long := PackedVector2Array([top + Vector2(-12, 0), top + Vector2(12, 0),
			top + Vector2(11, 16 if not back else 19), top + Vector2(-11, 16 if not back else 19)])
		ci.draw_colored_polygon(long, hair.darkened(0.12))
	elif lk.hair == 2 and not back:
		var tail_side := -side if side != 0.0 else 1.0
		ci.draw_circle(head + Vector2(tail_side * 12.0, -2), 5.0, hair.darkened(0.1))
		ci.draw_circle(head + Vector2(tail_side * 14.5, 5), 4.2, hair.darkened(0.15))
		ci.draw_circle(head + Vector2(tail_side * 15.0, 11), 3.2, hair.darkened(0.2))

	if sword_behind and s.get("show_sword", true):
		draw_sword(ci, torso, s.get("sword_angle", facing.angle() + 1.0), s.get("weapon", -1), skin)

	# Gövde
	ci.draw_set_transform(o + torso * k, 0.0, Vector2(k, k * 1.12))
	ci.draw_circle(Vector2.ZERO, 10.5, cloth.darkened(0.3))
	ci.draw_circle(Vector2(0, -1), 9.3, cloth)
	ci.draw_set_transform(o, 0.0, Vector2(k, k))
	ci.draw_rect(Rect2(torso + Vector2(-9.5, 6.0), Vector2(19.0, 3.0)), _tint(Color(0.35, 0.22, 0.12), flash, dead))
	if armor >= 0:
		var plate := _tint(GEAR_COLORS[armor], flash, dead)
		ci.draw_set_transform(o + (torso + Vector2(0, -1)) * k, 0.0, Vector2(k, k * 1.08))
		ci.draw_circle(Vector2.ZERO, 7.6, plate.darkened(0.3))
		ci.draw_circle(Vector2(0, -0.8), 6.6, plate)
		ci.draw_circle(Vector2(-2.2, -3.0), 2.2, plate.lightened(0.35))
		ci.draw_set_transform(o, 0.0, Vector2(k, k))
		for lr in [-1.0, 1.0]:
			ci.draw_circle(torso + Vector2(lr * 9.5, -6.0), 4.6, plate.darkened(0.2))
			ci.draw_circle(torso + Vector2(lr * 9.5, -6.8), 3.4, plate)
		if armor == 2:
			ci.draw_arc(torso + Vector2(0, -1), 8.6, 0.0, TAU, 24, Color(1.0, 0.85, 0.4, 0.55), 1.2)
	# Boştaki el
	var free_hand := torso + Vector2((-side if side != 0.0 else -1.0) * 11.0, 2.0 - bob * 0.5)
	ci.draw_circle(free_hand, 3.4, skin.darkened(0.08))

	# Kafa
	ci.draw_circle(head, 11.5, skin.darkened(0.18))
	ci.draw_circle(head + Vector2(0, -0.6), 10.6, skin)
	if back:
		_draw_hair_back(ci, lk.hair, head, hair, skin)
	else:
		_draw_face(ci, head, facing)
		_draw_hair_front(ci, lk.hair, head, hair, side)

	if not sword_behind and s.get("show_sword", true):
		draw_sword(ci, torso, s.get("sword_angle", facing.angle() + 1.0), s.get("weapon", -1), skin)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_sword(ci: CanvasItem, torso: Vector2, angle: float, rarity: int, skin: Color) -> void:
	var d := Vector2.from_angle(angle)
	var hand := torso + d * 12.0
	var tip := torso + d * (46.0 if rarity >= 1 else 43.0)
	var blade := Color(0.85, 0.88, 0.95)
	if rarity >= 0:
		blade = GEAR_COLORS[rarity].lerp(Color.WHITE, 0.45)
	if rarity >= 1:
		var glow: Color = GEAR_COLORS[rarity]
		ci.draw_line(hand, tip, Color(glow.r, glow.g, glow.b, 0.28), 9.0)
	ci.draw_line(hand, tip, blade.darkened(0.15), 4.2)
	ci.draw_line(hand + d * 2.0, tip, Color(1, 1, 1, 0.75), 1.5)
	var guard := Color(0.55, 0.4, 0.15) if rarity < 2 else Color(0.95, 0.75, 0.25)
	ci.draw_line(hand - d.orthogonal() * 6.5, hand + d.orthogonal() * 6.5, guard, 3.2)
	ci.draw_circle(hand, 3.4, skin)


static func _draw_face(ci: CanvasItem, head: Vector2, facing: Vector2) -> void:
	var perp := facing.orthogonal()
	var center := head + Vector2(facing.x * 4.0, 1.5 + facing.y * 1.5)
	for k in [-1.0, 1.0]:
		var e: Vector2 = center + perp * 3.9 * k * (1.0 if facing.y >= 0.0 else -1.0)
		ci.draw_circle(e, 2.5, Color.WHITE)
		ci.draw_circle(e + facing * 0.9, 1.45, Color(0.12, 0.1, 0.16))
		ci.draw_circle(e + facing * 0.9 + Vector2(-0.5, -0.6), 0.5, Color(1, 1, 1, 0.9))
	if facing.y > 0.2:
		var m := center + Vector2(facing.x * 1.5, 4.8)
		ci.draw_arc(m, 2.2, 0.25, PI - 0.25, 8, Color(0.45, 0.2, 0.18), 1.2)
		ci.draw_circle(center + Vector2(-6.5, 3.2), 1.6, Color(1.0, 0.5, 0.5, 0.25))
		ci.draw_circle(center + Vector2(6.5, 3.2), 1.6, Color(1.0, 0.5, 0.5, 0.25))


static func _cap(center: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(center + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r)
	return pts


static func _draw_hair_front(ci: CanvasItem, style: int, head: Vector2, hair: Color, side: float) -> void:
	if style == 4:  # kel: hafif parlama
		ci.draw_circle(head + Vector2(-3.5, -6.5), 2.4, Color(1, 1, 1, 0.22))
		return
	# Tepe: üst yarım daire ve alın perçemi
	var cap := _cap(head + Vector2(0, -1.5), 12.2, PI + 0.05, TAU - 0.05, 18)
	cap.append(head + Vector2(10.5, -3.0))
	cap.append(head + Vector2(5.0 + side * 2.0, -5.0))
	cap.append(head + Vector2(1.0 + side * 2.0, -2.2))
	cap.append(head + Vector2(-3.0 + side * 2.0, -5.0))
	cap.append(head + Vector2(-10.5, -3.0))
	ci.draw_colored_polygon(cap, hair)
	ci.draw_arc(head + Vector2(-2.0, -6.5), 6.0, PI + 0.6, TAU - 0.9, 8, hair.lightened(0.25), 1.6)
	match style:
		1:  # uzun: yanlardan inen perçemler
			for k in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([head + Vector2(k * 12.2, -3.0), head + Vector2(k * 9.0, -3.0),
					head + Vector2(k * 10.0, 9.0), head + Vector2(k * 13.0, 8.0)]), hair)
		3:  # dikenli
			for i in 5:
				var x := -9.0 + i * 4.5
				var base := head + Vector2(x, -9.0 - absf(x) * 0.12)
				ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3.2, 2.0), base + Vector2(x * 0.15, -8.5),
					base + Vector2(3.2, 2.0)]), hair)


static func _draw_hair_back(ci: CanvasItem, style: int, head: Vector2, hair: Color, skin: Color) -> void:
	if style == 4:
		ci.draw_circle(head + Vector2(0, -4), 3.0, Color(1, 1, 1, 0.18))
		return
	ci.draw_circle(head + Vector2(0, -1.0), 12.0, hair)
	ci.draw_arc(head + Vector2(0, -3.0), 7.0, PI + 0.4, TAU - 0.4, 8, hair.lightened(0.2), 1.5)
	if style == 2:
		ci.draw_circle(head + Vector2(0, 8.0), 4.6, hair.darkened(0.12))
		ci.draw_circle(head + Vector2(0, 14.0), 3.6, hair.darkened(0.18))
		ci.draw_circle(head + Vector2(0, 2.5), 2.2, Color(0.75, 0.2, 0.2))  # toka
	elif style == 3:
		for i in 5:
			var x := -9.0 + i * 4.5
			var base := head + Vector2(x, -9.0)
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3.2, 2.0), base + Vector2(x * 0.15, -8.0),
				base + Vector2(3.2, 2.0)]), hair)
	# Kulaklar
	ci.draw_circle(head + Vector2(-11.0, 1.0), 2.2, skin.darkened(0.1))
	ci.draw_circle(head + Vector2(11.0, 1.0), 2.2, skin.darkened(0.1))


static func _tint(c: Color, flash: float, dead: bool) -> Color:
	if dead:
		var g := c.get_luminance() * 0.7 + 0.15
		c = Color(g, g, g)
	return c.lerp(Color.WHITE, clampf(flash, 0.0, 1.0)) if flash > 0.0 else c
