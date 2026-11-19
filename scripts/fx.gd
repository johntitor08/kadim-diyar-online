extends Node
## Görsel efektler: uçan hasar yazıları ve "puf" patlamaları.
## Efektler ağdan senkronlanmaz; her istemci kendisi çizer.

const Poof := preload("res://scripts/poof.gd")
const Projectile := preload("res://scripts/projectile.gd")


func _layer() -> Node:
	return get_tree().get_first_node_in_group("fx_layer")


func floating_text(pos: Vector2, text: String, color: Color, font_size := 16) -> void:
	var layer := _layer()
	if layer == null or Network.is_dedicated:
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(160, 30)
	label.position = pos + Vector2(-80 + randf_range(-10, 10), -76)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", font_size)
	layer.add_child(label)
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 45.0, 0.9) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.45)
	tw.chain().tween_callback(label.queue_free)


func poof(pos: Vector2, color: Color) -> void:
	var layer := _layer()
	if layer == null or Network.is_dedicated:
		return
	var p := Poof.new()
	p.color = color
	p.position = pos
	layer.add_child(p)


func projectile(from: Vector2, to: Vector2, duration: float, color: Color, kind: String) -> void:
	var layer := _layer()
	if layer == null or Network.is_dedicated:
		return
	var p := Projectile.new()
	p.from = from
	p.to = to
	p.duration = maxf(duration, 0.05)
	p.color = color
	p.kind = kind
	p.position = from
	layer.add_child(p)


## Sunucu çağırır, tüm oyuncularda patlama efekti oynar.
func broadcast_poof(pos: Vector2, color: Color) -> void:
	if multiplayer.is_server() and Network.is_online():
		_poof_rpc.rpc(pos, color)


@rpc("authority", "call_local", "unreliable")
func _poof_rpc(pos: Vector2, color: Color) -> void:
	poof(pos, color)
	SFX.play("kill", pos)
