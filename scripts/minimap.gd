extends Control
## Mini harita: bulunulan bölgenin kuşbakışı. Engeller, lav, adalar, portallar, tüccar/Kâhin,
## oyuncular (sen: beyaz ok, diğerleri: camgöbeği), canavarlar (kırmızı), boss'lar (büyük) gösterilir.
## Dünya haritası kipi (big = true) tüm bölgeleri yan yana gösterir.

const Zones := preload("res://scripts/zones.gd")
const Player := preload("res://scripts/player.gd")
const SIZE := 180.0
## Dünya haritasında bölgelerin yerleşimi (gerçek koordinatlar değil; yönlere göre)
const WORLD_LAYOUT := {
	"meadow": Vector2(0.5, 0.47), "graveyard": Vector2(0.84, 0.47), "glacier": Vector2(0.5, 0.17),
	"volcano": Vector2(0.5, 0.77), "ocean": Vector2(0.16, 0.47),
}

var player = null
var big := false
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)


var _redraw_acc := 0.0


func _process(delta: float) -> void:
	_t += delta
	_redraw_acc += delta
	if visible and is_visible_in_tree() and _redraw_acc >= 0.1:
		_redraw_acc = 0.0
		queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	if big:
		_draw_world()
		return
	var zone: String = Zones.zone_at(player.position)
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0, 0, 0, 0.55))
	_draw_zone(zone, Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), true)
	draw_rect(rect, Color(0.62, 0.48, 0.25, 0.95), false, 2.0)


## Bir bölgeyi verilen ekran dikdörtgenine çizer.
func _draw_zone(zone: String, area: Rect2, detailed: bool) -> void:
	var z: Dictionary = Zones.ZONES[zone]
	var zr: Rect2 = z.rect
	var k := minf(area.size.x / zr.size.x, area.size.y / zr.size.y)
	var off := area.position + (area.size - zr.size * k) * 0.5
	var to_map := func(p: Vector2) -> Vector2: return off + (p - zr.position) * k
	draw_rect(Rect2(off, zr.size * k), z.color.darkened(0.1))
	var lay := Zones.layout(zone)
	match zone:
		"meadow":
			var dirt := Color(0.55, 0.45, 0.3)
			draw_line(to_map.call(Vector2(zr.position.x, 1600)), to_map.call(Vector2(zr.end.x, 1600)), dirt, maxf(70.0 * k, 2.0))
			draw_line(to_map.call(Vector2(1600, zr.position.y)), to_map.call(Vector2(1600, zr.end.y)), dirt, maxf(70.0 * k, 2.0))
			draw_circle(to_map.call(z.entry), 240.0 * k, dirt.lightened(0.1))
		"ocean":
			for b in lay.land:
				draw_circle(to_map.call(b[0]), (b[1] + 14.0) * k, Color(0.9, 0.82, 0.58))
			for b in lay.land:
				draw_circle(to_map.call(b[0]), maxf((b[1] - 16.0) * k, 1.0), Color(0.36, 0.62, 0.3))
		"volcano":
			for pool in lay.pools:
				draw_circle(to_map.call(pool[0]), pool[1] * k, Color(1.0, 0.45, 0.1))
		"glacier":
			for d in lay.decor:
				draw_circle(to_map.call(d[0]), d[1] * k, Color(0.62, 0.82, 0.95))
	if zone != "meadow" and zone != "ocean":
		draw_line(to_map.call(Vector2(zr.position.x, z.entry.y)), to_map.call(Vector2(zr.end.x, z.entry.y)),
			z.color.lightened(0.15), maxf(64.0 * k, 2.0))
	if not detailed:
		return
	# Engeller
	var world = get_tree().get_first_node_in_group("world")
	if world != null:
		var dot: Color = z.color.darkened(0.45) if zone != "glacier" else Color(0.25, 0.4, 0.35)
		for o in world.obstacles_by_zone.get(zone, []):
			draw_rect(Rect2(to_map.call(o[0]) - Vector2(1, 1), Vector2(2, 2)), dot)
	# Tüccar ve Kâhin
	if zone == "meadow":
		_icon(to_map.call(Player.MERCHANT_POS), Color(1.0, 0.85, 0.3), 3.5)
		_icon(to_map.call(Player.ORACLE_POS), Color(0.6, 0.75, 1.0), 3.5)
	# Portallar
	for portal in Zones.PORTALS:
		if Zones.zone_at(portal.pos) == zone:
			var pc: Vector2 = to_map.call(portal.pos)
			var col: Color = Zones.ZONES[portal.to].color.lightened(0.4) if portal.to != "meadow" else Color(0.5, 0.9, 0.45)
			draw_arc(pc, 4.5, 0.0, TAU, 12, col, 2.0)
	# Canavarlar
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.zone != zone:
			continue
		var ep: Vector2 = to_map.call(e.position)
		if e.is_in_group("boss") or e.is_in_group("zone_boss"):
			var pulse := 5.0 + sin(_t * 5.0) * 1.5
			draw_circle(ep, pulse + 1.5, Color.BLACK)
			draw_circle(ep, pulse, Color(0.85, 0.2, 0.9))
		else:
			draw_circle(ep, 1.8, Color(1.0, 0.3, 0.25))
	# Oyuncular
	for p in get_tree().get_nodes_in_group("players"):
		if p == player or Zones.zone_at(p.position) != zone:
			continue
		draw_circle(to_map.call(p.position), 3.0, Color(0.3, 0.9, 1.0))
	var me: Vector2 = to_map.call(player.position)
	var f: Vector2 = player.facing.normalized()
	draw_colored_polygon(PackedVector2Array([me + f * 7.0, me + f.orthogonal() * 4.0 - f * 3.0,
		me - f.orthogonal() * 4.0 - f * 3.0]), Color.WHITE)
	draw_polyline(PackedVector2Array([me + f * 7.0, me + f.orthogonal() * 4.0 - f * 3.0,
		me - f.orthogonal() * 4.0 - f * 3.0, me + f * 7.0]), Color.BLACK, 1.0)


func _icon(p: Vector2, col: Color, r: float) -> void:
	draw_circle(p, r + 1.0, Color.BLACK)
	draw_circle(p, r, col)


## Dünya haritası: beş bölge yönlerine göre yerleşir, portallar çizgilerle bağlanır.
func _draw_world() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.05, 0.07, 0.1, 0.92))
	draw_rect(rect, Color(0.62, 0.48, 0.25, 0.95), false, 3.0)
	var font := ThemeDB.fallback_font
	var cell := Vector2(size.x * 0.26, size.y * 0.24)
	var here: String = Zones.zone_at(player.position)
	var centers := {}
	for id in Zones.ORDER:
		centers[id] = Vector2(size.x * WORLD_LAYOUT[id].x, size.y * WORLD_LAYOUT[id].y)
	for id in Zones.ORDER:
		if id != "meadow":
			draw_line(centers.meadow, centers[id], Color(0.9, 0.8, 0.5, 0.5), 3.0)
	for id in Zones.ORDER:
		var area := Rect2(centers[id] - cell * 0.5, cell)
		_draw_zone(id, area, id == here)
		draw_rect(area, Color(1, 1, 1, 0.9) if id == here else Color(0.6, 0.55, 0.45, 0.8), false, 2.0 if id == here else 1.0)
		var z: Dictionary = Zones.ZONES[id]
		var title: String = z.name + ("" if id == "meadow" else "  (Sv %d+)" % z.level)
		var col := Color(1, 0.9, 0.6) if id == here else Color(0.85, 0.85, 0.8)
		if player.level < z.level:
			col = Color(0.75, 0.5, 0.45)
		draw_string_outline(font, Vector2(area.position.x - 40, area.position.y - 8), title,
			HORIZONTAL_ALIGNMENT_CENTER, area.size.x + 80, 14, 4, Color.BLACK)
		draw_string(font, Vector2(area.position.x - 40, area.position.y - 8), title,
			HORIZONTAL_ALIGNMENT_CENTER, area.size.x + 80, 14, col)
	var hint := "Dünya haritası (N ile kapat)  •  Portallar çayırdaki yol uçlarında, iskele batıda"
	draw_string_outline(font, Vector2(0, size.y - 14), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, 4, Color.BLACK)
	draw_string(font, Vector2(0, size.y - 14), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.9, 0.9, 0.85))
