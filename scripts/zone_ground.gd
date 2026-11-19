extends Node2D
## Bir bölgenin zemini: karolar, yol, giriş kampı, süslemeler (göletler, sis, mezarlar, adalar).
## Her bölge ayrı düğüm olduğu için ekran dışındaki bölgeler çizilmez.

const Zones := preload("res://scripts/zones.gd")

var zone := "graveyard"


func _hash(x: int, y: int) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var z: Dictionary = Zones.ZONES[zone]
	var r: Rect2 = z.rect
	var lay := Zones.layout(zone)
	var tile := 128.0 if zone == "ocean" else 64.0
	var base: Color = z.color
	# Bölge dışı kenar boşluğu
	draw_rect(r.grow(500.0), base.darkened(0.55))
	var cols := int(r.size.x / tile)
	var rows := int(r.size.y / tile)
	for x in cols:
		for y in rows:
			var h := _hash(x + int(r.position.x / 64.0), y + 31)
			var t := Rect2(r.position + Vector2(x, y) * tile, Vector2(tile, tile))
			draw_rect(t, base.lerp(base.darkened(0.12), h))
			_tile_detail(t, h)
	match zone:
		"graveyard":
			_draw_path(r, z.entry, Color(0.36, 0.33, 0.3))
			for d in lay.decor:
				if d[2] == "grave":
					_draw_grave(d[0])
				else:
					draw_circle(d[0], d[1], Color(0.75, 0.8, 0.85, 0.08))
					draw_circle(d[0] + Vector2(d[1] * 0.4, -10), d[1] * 0.7, Color(0.75, 0.8, 0.85, 0.07))
		"glacier":
			_draw_path(r, z.entry, Color(0.72, 0.78, 0.86))
			for d in lay.decor:
				draw_set_transform(d[0], 0.0, Vector2(1.0, 0.65))
				draw_circle(Vector2.ZERO, d[1] + 6.0, Color(0.6, 0.72, 0.85))
				draw_circle(Vector2.ZERO, d[1], Color(0.62, 0.82, 0.95))
				draw_line(Vector2(-d[1] * 0.5, -d[1] * 0.2), Vector2(d[1] * 0.1, -d[1] * 0.45), Color(1, 1, 1, 0.6), 3.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"volcano":
			_draw_path(r, z.entry, Color(0.3, 0.24, 0.22))
		"ocean":
			_draw_islands(lay.land)
			_draw_dock(z.entry)
	if zone != "ocean":
		_draw_camp(z.entry)
	draw_rect(r, base.darkened(0.6), false, 8.0)


func _tile_detail(t: Rect2, h: float) -> void:
	match zone:
		"graveyard":
			if h > 0.86:
				var p := t.position + Vector2(h * 40 + 10, 30)
				for k in 3:
					draw_line(p + Vector2(k * 4 - 4, 0), p + Vector2(k * 5 - 6, -6), Color(0.3, 0.36, 0.3), 1.5)
			elif h < 0.05:
				draw_circle(t.get_center(), 3.0, Color(0.85, 0.85, 0.8, 0.6))  # kemik parçası
		"glacier":
			if h > 0.8:
				draw_circle(t.position + Vector2(h * 50, 20), 2.0, Color(1, 1, 1, 0.8))
				draw_circle(t.position + Vector2(20, h * 50), 1.6, Color(1, 1, 1, 0.7))
		"volcano":
			if h > 0.78:
				var a := t.position + Vector2(8, h * 50)
				var b := a + Vector2(30, -12 + h * 10)
				draw_line(a, b, Color(1.0, 0.4, 0.1, 0.55), 2.5)
				draw_line(b, b + Vector2(16, 10), Color(1.0, 0.55, 0.15, 0.45), 2.0)
			elif h < 0.06:
				draw_circle(t.get_center(), 2.5, Color(1.0, 0.6, 0.2, 0.7))  # kor
		"ocean":
			if h > 0.55:
				var p := t.position + Vector2(h * 80, 30 + h * 50)
				draw_arc(p, 9.0, PI * 1.1, PI * 1.9, 6, Color(0.7, 0.85, 0.95, 0.35), 2.0)
				draw_arc(p + Vector2(16, 0), 9.0, PI * 1.1, PI * 1.9, 6, Color(0.7, 0.85, 0.95, 0.35), 2.0)


func _draw_path(r: Rect2, entry: Vector2, col: Color) -> void:
	draw_line(Vector2(r.position.x, entry.y), Vector2(r.end.x, entry.y), col, 64.0)


func _draw_camp(entry: Vector2) -> void:
	var z: Dictionary = Zones.ZONES[zone]
	var col: Color = z.color.lightened(0.12)
	draw_circle(entry, 200.0, col)
	draw_arc(entry, 200.0, 0.0, TAU, 56, col.darkened(0.3), 4.0)


func _draw_grave(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-16, -8), Vector2(32, 18)), Color(0.12, 0.1, 0.09))
	draw_rect(Rect2(p + Vector2(-20, 10), Vector2(40, 8)), Color(0.33, 0.27, 0.2))


func _draw_islands(blobs: Array) -> void:
	# Sığ su, kum, çimen: tüm daireler katman katman çizilir.
	for b in blobs:
		draw_circle(b[0], b[1] + 40.0, Color(0.3, 0.62, 0.75))
	for b in blobs:
		draw_circle(b[0], b[1] + 14.0, Color(0.9, 0.82, 0.58))
	for b in blobs:
		draw_circle(b[0], b[1] - 16.0, Color(0.36, 0.62, 0.3))
	for b in blobs:
		if b[1] > 150.0:
			draw_circle(b[0] + Vector2(-b[1] * 0.2, -b[1] * 0.15), b[1] * 0.3, Color(0.4, 0.66, 0.33))


func _draw_dock(entry: Vector2) -> void:
	var wood := Color(0.5, 0.35, 0.2)
	var start := entry + Vector2(-260, 0)
	draw_rect(Rect2(start + Vector2(0, -26), Vector2(230, 52)), wood.darkened(0.25))
	for k in 12:
		draw_rect(Rect2(start + Vector2(k * 19 + 2, -24), Vector2(15, 48)), wood)
	for k in 4:
		draw_circle(start + Vector2(k * 70 + 10, -28), 5.0, wood.darkened(0.4))
		draw_circle(start + Vector2(k * 70 + 10, 28), 5.0, wood.darkened(0.4))
