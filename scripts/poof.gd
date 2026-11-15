extends Node2D
## Kısa ömürlü patlama efekti.

const DURATION := 0.5

var color := Color.WHITE
var _t := 0.0
var _parts: Array[Vector2] = []


func _ready() -> void:
	for i in 12:
		_parts.append(Vector2.from_angle(randf() * TAU) * randf_range(20.0, 50.0))


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := _t / DURATION
	var a := 1.0 - p
	var c := Vector2(0, -14)
	draw_arc(c, 8.0 + 34.0 * p, 0.0, TAU, 28, Color(color, a), 3.0)
	for v in _parts:
		draw_circle(c + v * p, 4.5 * (1.0 - p), Color(color.lightened(0.3), a))
