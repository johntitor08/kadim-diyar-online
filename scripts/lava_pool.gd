extends Node2D
## Volkandaki lav gölü: parlayarak kaynar. İçine giren oyuncu sunucuda yanar (player.gd).

var radius := 80.0
var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, radius + 10.0, Color(0.25, 0.08, 0.04))
	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.35, 0.05))
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(Vector2(radius * 0.1, -radius * 0.1), radius * 0.7, Color(1.0, 0.55 + pulse * 0.15, 0.1))
	for k in 5:
		var a := k * 1.7 + _t * 0.3
		var p := Vector2(cos(a), sin(a * 1.3)) * radius * 0.55
		var s := fposmod(_t * 0.8 + k * 0.37, 1.0)
		draw_circle(p, 4.0 + s * 7.0, Color(1.0, 0.85, 0.3, 1.0 - s))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
