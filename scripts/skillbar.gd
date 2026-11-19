extends Control
## Yetenek çubuğu: iksir (Q) ve üç yetenek. Bekleme süresi, kilit ve tuşlar gösterilir.

const SLOT := 58.0
const GAP := 8.0

var player = null


func _init() -> void:
	custom_minimum_size = Vector2(SLOT * 4 + GAP * 3, SLOT + 18)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var font := ThemeDB.fallback_font
	var slots := [["potion", "Q", "İksir"]]
	for id in player.SKILL_ORDER:
		slots.append([id, player.SKILLS[id].key, player.SKILLS[id].name])
	for i in slots.size():
		var id: String = slots[i][0]
		var r := Rect2(Vector2(i * (SLOT + GAP), 0), Vector2(SLOT, SLOT))
		var locked: bool = id != "potion" and not player.skill_unlocked(id)
		var ratio: float = 0.0 if id == "potion" else player.skill_cooldown_ratio(id)
		var empty: bool = id == "potion" and player.potions == 0
		draw_rect(r, Color(0.08, 0.07, 0.06, 0.85))
		var c := r.get_center()
		_icon(id, c, Color(1, 1, 1, 0.35) if locked or empty else Color.WHITE)
		if ratio > 0.0:
			draw_rect(Rect2(r.position, Vector2(SLOT, SLOT * ratio)), Color(0, 0, 0, 0.6))
			var secs := ceili(ratio * float(player.SKILLS[id].cooldown))
			_text(font, str(secs), c + Vector2(0, 7), 20, Color.WHITE)
		if locked:
			draw_rect(r, Color(0, 0, 0, 0.45))
			_text(font, "Sv %d" % player.SKILLS[id].level, c + Vector2(0, 6), 15, Color(1, 0.85, 0.5))
		var ready: bool = not locked and ratio <= 0.0 and not empty
		draw_rect(r, Color(0.95, 0.78, 0.4) if ready else Color(0.45, 0.4, 0.32), false, 2.0)
		# Tuş ve ad
		draw_string_outline(font, r.position + Vector2(4, 13), slots[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		draw_string(font, r.position + Vector2(4, 13), slots[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.9, 0.6))
		_text(font, slots[i][2], Vector2(c.x, r.end.y + 14), 11, Color(0.92, 0.9, 0.85))
		if id == "potion":
			draw_string_outline(font, Vector2(r.end.x - 24, r.end.y - 4), "x%d" % player.potions,
				HORIZONTAL_ALIGNMENT_RIGHT, 20, 12, 3, Color.BLACK)
			draw_string(font, Vector2(r.end.x - 24, r.end.y - 4), "x%d" % player.potions,
				HORIZONTAL_ALIGNMENT_RIGHT, 20, 12, Color.WHITE)


func _text(font: Font, text: String, center: Vector2, font_size: int, col: Color) -> void:
	var pos := Vector2(center.x - 40, center.y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 80, font_size, col)


func _icon(id: String, c: Vector2, tint: Color) -> void:
	match id:
		"potion":
			draw_rect(Rect2(c + Vector2(-3, -15), Vector2(6, 7)), Color(0.85, 0.85, 0.9) * tint)
			draw_circle(c + Vector2(0, 2), 11.0, Color(0.9, 0.2, 0.28) * tint)
			draw_circle(c + Vector2(-4, -2), 3.0, Color(1, 1, 1, 0.6) * tint)
		"spin":
			for k in 3:
				var a := TAU * k / 3.0
				draw_arc(c, 15.0 - k * 3.0, a, a + 2.2, 12, Color(0.75, 0.9, 1.0) * tint, 3.0)
			draw_circle(c, 3.0, Color.WHITE * tint)
		"dash":
			for k in 3:
				var x := -12.0 + k * 9.0
				draw_polyline(PackedVector2Array([c + Vector2(x, -10), c + Vector2(x + 8, 0), c + Vector2(x, 10)]),
					Color(1.0, 0.8, 0.4, 0.5 + k * 0.25) * tint, 3.5)
		"heal":
			draw_circle(c, 15.0, Color(0.3, 0.8, 0.4, 0.35) * tint)
			draw_rect(Rect2(c + Vector2(-4, -12), Vector2(8, 24)), Color(0.55, 1.0, 0.6) * tint)
			draw_rect(Rect2(c + Vector2(-12, -4), Vector2(24, 8)), Color(0.55, 1.0, 0.6) * tint)
