extends Node2D
## Bölgeler arası geçit. Okyanusa giden ve okyanustan dönen geçitler iskele/tekne olarak çizilir.
## Çarpışması yoktur; oyuncu üstüne yürüyünce kendi istemcisi sunucudan geçiş ister.

const Zones := preload("res://scripts/zones.gd")

var index := 0
var to_zone := "graveyard"
var _t := 0.0


func _ready() -> void:
	add_to_group("portals")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func is_dock() -> bool:
	return to_zone == "ocean" or Zones.zone_at(position) == "ocean"


func _draw() -> void:
	var z: Dictionary = Zones.ZONES[to_zone]
	var col: Color = z.color.lightened(0.35) if to_zone != "volcano" else Color(1.0, 0.45, 0.15)
	if to_zone == "meadow":
		col = Color(0.45, 0.85, 0.4)
	if is_dock():
		_draw_boat()
	else:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 46.0, Color(col.r, col.g, col.b, 0.18))
		for k in 3:
			var a := _t * (1.6 + k * 0.5) + k * 2.1
			draw_arc(Vector2.ZERO, 40.0 - k * 9.0, a, a + 4.2, 24, Color(col.r, col.g, col.b, 0.85 - k * 0.2), 4.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for k in 6:
			var a := _t * 1.3 + TAU * k / 6.0
			var h := fposmod(_t * 30.0 + k * 13.0, 50.0)
			draw_circle(Vector2(cos(a) * 30.0, sin(a) * 15.0 - h), 2.5, Color(col.r, col.g, col.b, 1.0 - h / 50.0))
	var font := ThemeDB.fallback_font
	var text: String = ("→ " + z.name) + ("" if to_zone == "meadow" else "  (Sv %d+)" % z.level)
	if is_dock():
		text = "Okyanusa açıl  (Sv %d+)" % z.level if to_zone == "ocean" else "İskele → Kadim Çayır"
	draw_string_outline(font, Vector2(-120, -58), text, HORIZONTAL_ALIGNMENT_CENTER, 240, 14, 5, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(-120, -58), text, HORIZONTAL_ALIGNMENT_CENTER, 240, 14, col.lightened(0.3))


func _draw_boat() -> void:
	var bob := sin(_t * 2.0) * 2.0
	var hull := Color(0.48, 0.3, 0.16)
	var base := Vector2(0, 6 + bob)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-34, -10), base + Vector2(34, -10),
		base + Vector2(24, 8), base + Vector2(-24, 8)]), hull)
	draw_line(base + Vector2(-34, -10), base + Vector2(34, -10), hull.lightened(0.25), 3.0)
	draw_line(base + Vector2(0, -10), base + Vector2(0, -52), Color(0.4, 0.28, 0.16), 3.0)
	draw_colored_polygon(PackedVector2Array([base + Vector2(2, -50), base + Vector2(28, -22), base + Vector2(2, -18)]),
		Color(0.95, 0.93, 0.85))
	draw_arc(base + Vector2(0, 10), 30.0, 0.2, PI - 0.2, 12, Color(1, 1, 1, 0.35), 2.0)
