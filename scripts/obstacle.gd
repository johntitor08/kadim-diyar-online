extends StaticBody2D
## Haritadaki engeller: ağaç, kaya, kamp ateşi, tüccar tezgâhı, Kâhin. Seed ile üretildiği için senkron gerekmez.

var kind := "tree"
var size := 24.0
var variant := 0
var _t := 0.0
var _redraw_acc := 0.0


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
		"oracle":
			shape.radius = size * 0.6
		"tomb", "ice", "obsidian":
			shape.radius = size * 0.6
		"deadtree", "snowpine", "palm":
			shape.radius = size * 0.4
		"snowrock", "basalt":
			shape.radius = size * 0.8
		"vent":
			shape.radius = size * 0.75
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -size * 0.25 if kind in ["rock", "snowrock", "basalt"] else -4.0)
	add_child(cs)
	set_process(kind in ["campfire", "oracle", "vent"])


func _process(delta: float) -> void:
	_t += delta
	_redraw_acc += delta
	if _redraw_acc >= 0.033 and FX.on_screen(global_position):
		_redraw_acc = 0.0
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
		"oracle":
			_draw_oracle()
		"tomb":
			_draw_tomb()
		"deadtree":
			_draw_deadtree()
		"snowpine":
			_draw_snowpine()
		"ice":
			_draw_ice()
		"snowrock":
			_draw_rock_colored(Color(0.62, 0.66, 0.72), Color(0.95, 0.97, 1.0))
		"basalt":
			_draw_rock_colored(Color(0.2, 0.17, 0.17), Color(0.35, 0.2, 0.15))
		"obsidian":
			_draw_obsidian()
		"vent":
			_draw_vent()
		"palm":
			_draw_palm()


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


func _draw_oracle() -> void:
	var s := size
	var float_y := sin(_t * 2.2) * 2.0
	_shadow(s * 0.9)
	# Asa ve parlayan küre
	var staff_top := Vector2(s * 0.75, -s * 2.6)
	draw_line(Vector2(s * 0.7, -2), staff_top, Color(0.42, 0.28, 0.14), 4.0)
	var orb := staff_top + Vector2(0, -6 + float_y)
	draw_circle(orb, 14.0 + sin(_t * 3.0) * 2.0, Color(0.55, 0.75, 1.0, 0.15))
	draw_circle(orb, 6.5, Color(0.55, 0.8, 1.0))
	draw_circle(orb + Vector2(-2, -2), 2.2, Color(1, 1, 1, 0.85))
	# Cüppe
	var robe := Color(0.28, 0.24, 0.5)
	draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.75, 0), Vector2(-s * 0.45, -s * 1.5),
		Vector2(s * 0.45, -s * 1.5), Vector2(s * 0.75, 0)]), robe)
	draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.12, 0), Vector2(-s * 0.08, -s * 1.45),
		Vector2(s * 0.08, -s * 1.45), Vector2(s * 0.12, 0)]), Color(0.85, 0.7, 0.3))
	# Kollar
	draw_circle(Vector2(s * 0.65, -s * 1.0), 3.6, Color(0.93, 0.78, 0.64))
	# Kafa, sakal, kukuleta
	var head := Vector2(0, -s * 1.85)
	draw_circle(head, s * 0.45, Color(0.93, 0.78, 0.64))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-s * 0.35, s * 0.05), head + Vector2(0, s * 0.95),
		head + Vector2(s * 0.35, s * 0.05)]), Color(0.92, 0.92, 0.95))
	draw_circle(head + Vector2(-3.5, -1), 1.5, Color(0.1, 0.1, 0.15))
	draw_circle(head + Vector2(3.5, -1), 1.5, Color(0.1, 0.1, 0.15))
	draw_arc(head + Vector2(0, -2), s * 0.55, PI * 0.95, TAU + PI * 0.05, 16, robe.darkened(0.2), 5.0)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-s * 0.55, -s * 0.1), head + Vector2(0, -s * 1.1),
		head + Vector2(s * 0.55, -s * 0.1)]), robe.darkened(0.1))
	var font := ThemeDB.fallback_font
	var label_y := -s * 3.3
	draw_string_outline(font, Vector2(-60, label_y), "Kâhin", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-60, label_y), "Kâhin", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.7, 0.85, 1.0))
	# Görev işareti
	var mark_y := label_y - 20.0 + float_y
	draw_string_outline(font, Vector2(-20, mark_y), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, 5, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-20, mark_y), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 22, Color(1.0, 0.85, 0.25))


# --- Bölge engelleri ---

func _draw_tomb() -> void:
	var s := size
	_shadow(s * 0.9)
	var stone := Color(0.5, 0.52, 0.55).darkened(float(variant % 4) * 0.06)
	var top := Vector2(0, -s * 1.6)
	if variant % 3 == 0:
		# Haç
		draw_rect(Rect2(-s * 0.15, -s * 1.9, s * 0.3, s * 1.9), stone)
		draw_rect(Rect2(-s * 0.55, -s * 1.45, s * 1.1, s * 0.28), stone)
	else:
		draw_rect(Rect2(-s * 0.6, -s * 1.3, s * 1.2, s * 1.3), stone)
		draw_circle(top + Vector2(0, s * 0.3), s * 0.6, stone)
		draw_line(Vector2(-s * 0.3, -s * 0.9), Vector2(s * 0.3, -s * 0.9), stone.darkened(0.35), 2.0)
		draw_line(Vector2(-s * 0.3, -s * 0.65), Vector2(s * 0.2, -s * 0.65), stone.darkened(0.35), 2.0)
	draw_rect(Rect2(-s * 0.75, -s * 0.12, s * 1.5, s * 0.24), Color(0.3, 0.26, 0.22))


func _draw_deadtree() -> void:
	var s := size
	_shadow(s * 0.8)
	var wood := Color(0.27, 0.22, 0.2)
	draw_line(Vector2(0, 0), Vector2(0, -s * 2.0), wood, 7.0)
	var k := 1.0 if variant % 2 == 0 else -1.0
	draw_line(Vector2(0, -s * 1.2), Vector2(s * 0.8 * k, -s * 1.9), wood, 4.0)
	draw_line(Vector2(0, -s * 1.6), Vector2(-s * 0.7 * k, -s * 2.3), wood, 3.5)
	draw_line(Vector2(s * 0.8 * k, -s * 1.9), Vector2(s * 1.1 * k, -s * 1.8), wood, 2.5)
	draw_line(Vector2(0, -s * 2.0), Vector2(s * 0.2 * k, -s * 2.5), wood, 3.0)


func _draw_snowpine() -> void:
	var s := size
	_shadow(s * 1.0)
	draw_rect(Rect2(-5, -s * 0.9, 10, s * 0.9), Color(0.38, 0.26, 0.16))
	var dark := Color(0.13, 0.32, 0.26)
	for i in 3:
		var y := -s * (0.8 + i * 0.55)
		var w := s * (1.1 - i * 0.25)
		draw_colored_polygon(PackedVector2Array([Vector2(-w, y), Vector2(0, y - s * 0.95), Vector2(w, y)]), dark)
		draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.55, y - s * 0.35), Vector2(0, y - s * 0.95),
			Vector2(w * 0.55, y - s * 0.35)]), Color(0.95, 0.97, 1.0))


func _draw_ice() -> void:
	var s := size
	_shadow(s * 0.8)
	var ice := Color(0.65, 0.85, 1.0, 0.92)
	draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.5, 0), Vector2(-s * 0.3, -s * 1.8),
		Vector2(0, -s * 2.4), Vector2(s * 0.25, -s * 1.6), Vector2(s * 0.5, 0)]), ice)
	draw_colored_polygon(PackedVector2Array([Vector2(s * 0.3, 0), Vector2(s * 0.55, -s * 1.1),
		Vector2(s * 0.85, -s * 0.2)]), ice.darkened(0.1))
	draw_line(Vector2(-s * 0.15, -s * 0.3), Vector2(-s * 0.05, -s * 1.9), Color(1, 1, 1, 0.75), 2.0)


func _draw_rock_colored(col: Color, top_col: Color) -> void:
	var s := size
	_shadow(s * 1.0)
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0
		var rr := s * (0.85 + 0.15 * sin(a * 3.0 + variant))
		pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.75 - s * 0.45))
	draw_colored_polygon(pts, col)
	draw_circle(Vector2(-s * 0.2, -s * 0.85), s * 0.4, top_col)
	pts.append(pts[0])
	draw_polyline(pts, col.darkened(0.5), 2.0)


func _draw_obsidian() -> void:
	var s := size
	_shadow(s * 0.7)
	var col := Color(0.12, 0.08, 0.16)
	for k in 3:
		var x := (k - 1) * s * 0.45
		var h := s * (1.8 - absf(k - 1) * 0.6)
		draw_colored_polygon(PackedVector2Array([Vector2(x - s * 0.25, 0), Vector2(x, -h), Vector2(x + s * 0.25, 0)]), col)
		draw_line(Vector2(x - s * 0.08, -h * 0.2), Vector2(x - s * 0.02, -h * 0.85), Color(0.6, 0.4, 0.8, 0.6), 1.5)


func _draw_vent() -> void:
	var s := size
	_shadow(s * 1.0)
	var rim := Color(0.25, 0.2, 0.18)
	draw_colored_polygon(PackedVector2Array([Vector2(-s, 0), Vector2(-s * 0.45, -s * 0.9),
		Vector2(s * 0.45, -s * 0.9), Vector2(s, 0)]), rim)
	draw_circle(Vector2(0, -s * 0.9), s * 0.42, Color(1.0, 0.45, 0.1))
	for k in 4:
		var p := fposmod(_t * 0.5 + k * 0.25, 1.0)
		draw_circle(Vector2(sin(_t + k) * 6.0, -s * 1.1 - p * s * 2.2), 6.0 + p * 10.0, Color(0.45, 0.42, 0.42, 0.5 * (1.0 - p)))


func _draw_palm() -> void:
	var s := size
	_shadow(s * 0.9)
	var sway := sin(variant * 1.7) * 2.5
	var trunk := Color(0.55, 0.4, 0.24)
	var top := Vector2(s * 0.3 + sway, -s * 2.4)
	for k in 6:
		var a := Vector2(0, 0).lerp(top, k / 6.0)
		var b := Vector2(0, 0).lerp(top, (k + 1) / 6.0)
		draw_line(a, b, trunk if k % 2 == 0 else trunk.darkened(0.15), 7.0 - k * 0.5)
	var leaf := Color(0.2, 0.55, 0.22)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var tip := top + Vector2(cos(a) * s * 1.3, sin(a) * s * 0.55 + s * 0.3)
		draw_colored_polygon(PackedVector2Array([top, tip + Vector2(0, -5), tip + Vector2(0, 5)]), leaf.lightened(0.1 * (k % 2)))
	draw_circle(top + Vector2(-3, 4), 4.0, Color(0.45, 0.3, 0.15))
	draw_circle(top + Vector2(4, 5), 4.0, Color(0.45, 0.3, 0.15))
