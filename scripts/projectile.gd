extends Node2D
## Uzaktan saldırı mermisinin görüntüsü (ok, ateş topu, gülle). İsabeti sunucu hesaplar.

var from := Vector2.ZERO
var to := Vector2.ZERO
var duration := 0.5
var color := Color.WHITE
var kind := "skeleton"
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	position = from.lerp(to, _t / duration)
	queue_redraw()


func _draw() -> void:
	var dir := (to - from).normalized()
	match kind:
		"skeleton":
			draw_line(-dir * 14.0, dir * 4.0, Color(0.55, 0.38, 0.2), 2.0)
			draw_colored_polygon(PackedVector2Array([dir * 8.0, dir * 2.0 + dir.orthogonal() * 3.0,
				dir * 2.0 - dir.orthogonal() * 3.0]), Color(0.8, 0.8, 0.85))
		"imp":
			for k in 4:
				draw_circle(-dir * k * 6.0, 7.0 - k * 1.4, Color(1.0, 0.5 + k * 0.1, 0.1, 0.8 - k * 0.18))
			draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.95, 0.6))
		_:
			draw_circle(Vector2.ZERO, 5.0, color)
			draw_line(-dir * 16.0, Vector2.ZERO, Color(0.8, 0.8, 0.8, 0.4), 3.0)
