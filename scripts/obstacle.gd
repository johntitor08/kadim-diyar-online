extends StaticBody2D
## Haritadaki engeller: ağaç, kaya, kamp ateşi, tüccar tezgâhı. Seed ile üretildiği için senkron gerekmez.

var kind := "tree"
var size := 24.0
var variant := 0
var _t := 0.0


func setup(k: String, s: float, v: int) -> void:
	kind = k
	size = s
	variant = v


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CircleShape2D.new()
	match kind:
		"tree":
			shape.radius = size * 0.45
		"rock":
			shape.radius = size * 0.8
		"campfire":
			shape.radius = size * 0.9
		"merchant":
			shape.radius = size * 0.8
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -size * 0.25 if kind == "rock" else -4.0)
	add_child(cs)
	set_process(kind == "campfire")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		"tree":
			_draw_tree()
		"rock":
			_draw_rock()
		"campfire":
			_draw_campfire()
		"merchant":
			_draw_merchant()


func _shadow(r: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tree() -> void:
	var s := size
	_shadow(s * 1.0)
	draw_rect(Rect2(-5, -s * 0.9, 10, s * 0.9), Color(0.4, 0.26, 0.14))
	if variant % 3 == 0:
		# Çam
		var dark := Color(0.12, 0.38, 0.22)
		var light := Color(0.18, 0.5, 0.28)
		for i in 3:
			var y := -s * (0.8 + i * 0.55)
			var w := s * (1.1 - i * 0.25)
			draw_colored_polygon(PackedVector2Array([Vector2(-w, y), Vector2(0, y - s * 0.95), Vector2(w, y)]), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.75, y - 3), Vector2(0, y - s * 0.9), Vector2(w * 0.2, y - 3)]), light)
	else:
		# Yuvarlak yapraklı
		var base := Color(0.2, 0.52, 0.22) if variant % 3 == 1 else Color(0.32, 0.55, 0.18)
		var c := Vector2(0, -s * 1.5)
		draw_circle(c + Vector2(0, 4), s, base.darkened(0.35))
		draw_circle(c + Vector2(-s * 0.45, 2), s * 0.7, base.darkened(0.1))
		draw_circle(c + Vector2(s * 0.45, 2), s * 0.7, base.darkened(0.1))
		draw_circle(c, s * 0.8, base)
		draw_circle(c + Vector2(-s * 0.25, -s * 0.3), s * 0.35, base.lightened(0.18))


func _draw_rock() -> void:
	var s := size
	_shadow(s * 1.0)
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		var rr := s * (0.85 + 0.15 * sin(a * 3.0 + variant))
		pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.75 - s * 0.45))
	draw_colored_polygon(pts, Color(0.45, 0.45, 0.48))
	draw_circle(Vector2(-s * 0.25, -s * 0.7), s * 0.35, Color(0.58, 0.58, 0.62))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.2, 0.2, 0.22), 2.0)


func _draw_campfire() -> void:
	_shadow(size * 1.3)
	for i in 8:
		var a := TAU * i / 8.0
		draw_circle(Vector2(cos(a) * size, sin(a) * size * 0.5 - 4), 6.0, Color(0.5, 0.5, 0.52))
	draw_line(Vector2(-12, -2), Vector2(12, -8), Color(0.4, 0.25, 0.1), 5.0)
	draw_line(Vector2(-12, -8), Vector2(12, -2), Color(0.35, 0.22, 0.1), 5.0)
	var f := sin(_t * 9.0) * 0.12 + sin(_t * 23.0) * 0.06
	draw_circle(Vector2(0, -10), 34.0 + f * 20.0, Color(1.0, 0.6, 0.2, 0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -6), Vector2(0, -38 - f * 30.0), Vector2(11, -6)]), Color(1.0, 0.45, 0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -6), Vector2(1, -25 + f * 20.0), Vector2(6, -6)]), Color(1.0, 0.85, 0.3))


func _draw_merchant() -> void:
	var s := size
	_shadow(s * 1.6)
	var wood := Color(0.45, 0.3, 0.16)
	# Direkler
	draw_rect(Rect2(-s * 1.3, -s * 2.3, 5, s * 2.3), wood.darkened(0.2))
	draw_rect(Rect2(s * 1.3 - 5, -s * 2.3, 5, s * 2.3), wood.darkened(0.2))
	# Tüccar (tezgâhın arkasında)
	var head := Vector2(0, -s * 1.75)
	draw_circle(head + Vector2(0, s * 0.6), s * 0.55, Color(0.35, 0.25, 0.55))
	draw_circle(head, s * 0.38, Color(0.93, 0.76, 0.6))
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-s * 0.45, -s * 0.2), head + Vector2(0, -s * 0.85), head + Vector2(s * 0.45, -s * 0.2)]),
		Color(0.55, 0.2, 0.2))
	draw_circle(head + Vector2(-4, -1), 1.6, Color(0.1, 0.1, 0.1))
	draw_circle(head + Vector2(4, -1), 1.6, Color(0.1, 0.1, 0.1))
	# Tezgâh
	draw_rect(Rect2(-s * 1.35, -s * 1.05, s * 2.7, s * 0.95), wood)
	draw_rect(Rect2(-s * 1.45, -s * 1.15, s * 2.9, 6), wood.lightened(0.15))
	# İksir şişeleri
	var bottle_colors := [Color(0.9, 0.2, 0.25), Color(0.3, 0.85, 0.45), Color(0.9, 0.2, 0.25)]
	for i in 3:
		var b := Vector2(-s * 0.8 + i * s * 0.8, -s * 1.15)
		draw_rect(Rect2(b.x - 2, b.y - 15, 4, 6), Color(0.8, 0.8, 0.85))
		draw_circle(b + Vector2(0, -6), 6.0, bottle_colors[i])
		draw_circle(b + Vector2(-2, -8), 1.6, Color(1, 1, 1, 0.7))
	# Tente
	for i in 6:
		var x := -s * 1.5 + i * s * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -s * 2.3), Vector2(x + s * 0.5, -s * 2.3), Vector2(x + s * 0.5, -s * 1.95),
			Vector2(x + s * 0.25, -s * 1.8), Vector2(x, -s * 1.95)]),
			Color(0.78, 0.22, 0.2) if i % 2 == 0 else Color(0.95, 0.9, 0.8))
	draw_rect(Rect2(-s * 1.5, -s * 2.45, s * 3.0, 6), Color(0.6, 0.16, 0.15))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-60, -s * 2.6), "Tüccar", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-60, -s * 2.6), "Tüccar", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1.0, 0.88, 0.55))
