extends CharacterBody2D
## Canavar. Yapay zeka ve can tamamen sunucuda çalışır; istemciler sadece çizer.

const TYPES := {
	"slime": {"name": "Balçık", "hp": 40, "damage": 6, "speed": 75.0, "xp": 12, "gold": 5,
		"radius": 14.0, "color": Color(0.35, 0.85, 0.4), "aggro": 220.0},
	"wolf": {"name": "Kurt", "hp": 75, "damage": 11, "speed": 145.0, "xp": 25, "gold": 10,
		"radius": 16.0, "color": Color(0.58, 0.58, 0.64), "aggro": 300.0},
	"orc": {"name": "Ork", "hp": 170, "damage": 19, "speed": 95.0, "xp": 60, "gold": 25,
		"radius": 20.0, "color": Color(0.42, 0.6, 0.25), "aggro": 260.0},
	# Boss: uzak köşelerde belirir, vuruşu çevresindeki herkese işler.
	"boss": {"name": "Kadim Dev", "hp": 1200, "damage": 32, "speed": 85.0, "xp": 400, "gold": 300,
		"radius": 34.0, "color": Color(0.5, 0.3, 0.62), "aggro": 380.0},
}
const BOSS_SLAM_RANGE := 95.0
const LEASH_DISTANCE := 900.0
const ATTACK_COOLDOWN := 1.0

# Senkronlanan değerler (EnemySync)
var hp := 40: set = _set_hp
var sync_pos := Vector2.ZERO
var angry := false

var enemy_type := "slime"
var max_hp := 40
var radius := 14.0
var home := Vector2.ZERO

var _data: Dictionary = TYPES["slime"]
var _target = null
var _attack_cd := 0.0
var _wander_target := Vector2.ZERO
var _wander_wait := 0.0
var _avoid_time := 0.0
var _avoid_dir := Vector2.ZERO
var _flash := 0.0
var _anim := 0.0
var _lunge_time := 0.0
var _lunge_dir := Vector2.ZERO
var _face_x := 1.0
var _prev_pos := Vector2.ZERO


## Spawn fonksiyonu tarafından tüm peer'larda aynı verilerle çağrılır.
func setup(type: String, pos: Vector2) -> void:
	enemy_type = type if TYPES.has(type) else "slime"
	_data = TYPES[enemy_type]
	max_hp = _data.hp
	hp = max_hp
	radius = _data.radius
	position = pos
	home = pos
	sync_pos = pos
	_prev_pos = pos
	_wander_target = pos


func _ready() -> void:
	add_to_group("enemies")
	if enemy_type == "boss":
		add_to_group("boss")
		SFX.play("boss")
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.8
	$CollisionShape2D.shape = shape
	_anim = randf() * 10.0


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_ai(delta)
		sync_pos = position
	else:
		position = position.lerp(sync_pos, clampf(delta * 12.0, 0.0, 1.0))
	var dx := position.x - _prev_pos.x
	if absf(dx) > 0.2:
		_face_x = signf(dx)
	_prev_pos = position
	_anim += delta
	_flash = maxf(_flash - delta, 0.0)
	_lunge_time = maxf(_lunge_time - delta, 0.0)
	queue_redraw()


# --- Sunucu yapay zekası ---

func _server_ai(delta: float) -> void:
	_attack_cd -= delta
	var target = _find_target()
	angry = target != null
	var move := Vector2.ZERO
	if target:
		var to: Vector2 = target.sync_pos - position
		var dist := to.length()
		if dist > radius + 12.0:
			move = to / dist
		if dist < radius + 24.0 and _attack_cd <= 0.0:
			_attack_cd = ATTACK_COOLDOWN
			if enemy_type == "boss":
				# Yer sarsıntısı: yakındaki herkes hasar alır.
				_attack_cd = ATTACK_COOLDOWN * 1.6
				for p in get_tree().get_nodes_in_group("players"):
					if not p.dead and p.sync_pos.distance_to(position) < BOSS_SLAM_RANGE:
						p.server_take_damage(_data.damage)
			else:
				target.server_take_damage(_data.damage)
			_lunge.rpc(to.normalized())
	else:
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			_wander_target = home + Vector2(randf_range(-140, 140), randf_range(-140, 140))
			_wander_wait = randf_range(2.0, 5.0)
		var to := _wander_target - position
		if to.length() > 8.0:
			move = to.normalized() * 0.4

	# Engelin etrafından dolanmak için basit kaçınma
	if _avoid_time > 0.0:
		_avoid_time -= delta
		move = (move + _avoid_dir).normalized() * move.length()
	velocity = move * float(_data.speed)
	move_and_slide()
	if get_slide_collision_count() > 0 and move.length() > 0.5 and _avoid_time <= 0.0:
		_avoid_time = 0.4
		_avoid_dir = move.orthogonal() * (1.0 if randf() < 0.5 else -1.0)


func _find_target():
	var aggro: float = _data.aggro
	if position.distance_to(home) > LEASH_DISTANCE:
		_target = null
		_wander_target = home
		return null
	if is_instance_valid(_target) and not _target.dead \
			and _target.sync_pos.distance_to(position) < aggro * 1.8:
		return _target
	_target = null
	var best_d := aggro
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead:
			continue
		var d: float = p.sync_pos.distance_to(position)
		if d < best_d:
			best_d = d
			_target = p
	return _target


func server_take_damage(amount: int, attacker) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	_target = attacker
	if hp == 0:
		_server_die()


func _server_die() -> void:
	# Yakındaki tüm canlı oyuncular XP kazanır (grup oyunu teşviki)
	var slayers: PackedStringArray = []
	for p in get_tree().get_nodes_in_group("players"):
		if not p.dead and p.sync_pos.distance_to(position) < 600.0:
			p.server_add_xp(_data.xp)
			p.server_add_gold(int(_data.gold * randf_range(0.8, 1.2)))
			slayers.append(p.player_name)
	if enemy_type == "boss":
		Network.broadcast_system("Kadim Dev yenildi! Kahramanlar: %s" % (", ".join(slayers) if not slayers.is_empty() else "kimse"))
	FX.broadcast_poof(position, _data.color)
	queue_free()  # MultiplayerSpawner istemcilerde de siler


@rpc("authority", "call_local", "unreliable")
func _lunge(dir: Vector2) -> void:
	_lunge_dir = dir
	_lunge_time = 0.2


func _set_hp(value: int) -> void:
	if is_inside_tree() and value < hp:
		_flash = 0.15
		var big := hp - value > 20
		FX.floating_text(global_position, str(hp - value), Color(1.0, 0.95, 0.4), 22 if big else 16)
		SFX.play("hit", global_position)
	hp = value


# --- Çizim ---

func _draw() -> void:
	var r := radius
	var col: Color = _data.color
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.75)
	var off := _lunge_dir * sin(_lunge_time / 0.2 * PI) * 10.0

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, r * 1.1, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	match enemy_type:
		"slime":
			_draw_slime(off, r, col)
		"wolf":
			_draw_wolf(off, r, col)
		"orc":
			_draw_orc(off, r, col)
		"boss":
			_draw_boss(off, r, col)

	var top := -r * 2.4 - 6.0
	var name_size := 15 if enemy_type == "boss" else 11
	if hp < max_hp:
		var ratio := float(hp) / float(max_hp)
		draw_rect(Rect2(-r - 1, top - 1, r * 2 + 2, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-r, top, r * 2 * ratio, 4), Color(0.9, 0.25, 0.2))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-50, top - 5), _data.name, HORIZONTAL_ALIGNMENT_CENTER, 100, name_size, 3, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-50, top - 5), _data.name, HORIZONTAL_ALIGNMENT_CENTER, 100, name_size,
		Color(1.0, 0.55, 0.5) if angry else Color(1, 1, 1, 0.85))


func _eyes(center: Vector2, spread: float, size: float, iris: Color) -> void:
	for s in [-1.0, 1.0]:
		var e: Vector2 = center + Vector2(spread * s + _face_x * 2.0, 0)
		draw_circle(e, size, Color.WHITE)
		draw_circle(e + Vector2(_face_x * size * 0.35, 0), size * 0.55, iris)


func _draw_slime(off: Vector2, r: float, col: Color) -> void:
	var squash := sin(_anim * 6.0) * 0.1
	var c := off + Vector2(0, -r * 0.7)
	draw_set_transform(c, 0.0, Vector2(1.15 - squash, 0.85 + squash))
	draw_circle(Vector2.ZERO, r, col.darkened(0.25))
	draw_circle(Vector2(0, -2), r * 0.9, col)
	draw_circle(Vector2(-r * 0.4, -r * 0.45), r * 0.22, Color(1, 1, 1, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_eyes(c + Vector2(0, -1), 4.5, 3.0, Color(0.1, 0.1, 0.1))


func _draw_wolf(off: Vector2, r: float, col: Color) -> void:
	var trot := sin(_anim * 12.0) * 1.5
	var body := off + Vector2(0, -r * 0.8 + trot)
	# Kuyruk
	draw_line(body + Vector2(-_face_x * r * 1.1, -2), body + Vector2(-_face_x * r * 1.8, -r * 0.7), col.darkened(0.2), 5.0)
	# Gövde
	draw_set_transform(body, 0.0, Vector2(1.35, 0.8))
	draw_circle(Vector2.ZERO, r, col.darkened(0.25))
	draw_circle(Vector2(0, -2), r * 0.85, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Kafa
	var head := body + Vector2(_face_x * r * 1.0, -r * 0.5)
	draw_circle(head, r * 0.65, col)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-8, -6), head + Vector2(-4, -r), head + Vector2(-1, -6)]), col.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([head + Vector2(1, -6), head + Vector2(5, -r), head + Vector2(8, -6)]), col.darkened(0.3))
	draw_circle(head + Vector2(_face_x * r * 0.55, 3), 3.0, Color(0.1, 0.1, 0.1))
	_eyes(head + Vector2(_face_x * 2.0, -2), 3.5, 2.4, Color(0.9, 0.2, 0.1) if angry else Color(0.9, 0.7, 0.1))


func _draw_orc(off: Vector2, r: float, col: Color) -> void:
	var body := off + Vector2(0, -r * 0.9)
	# Sopa
	var club_dir := Vector2(_face_x, -0.6).normalized()
	if _lunge_time > 0.0:
		club_dir = _lunge_dir
	var hand := body + Vector2(_face_x * r * 0.9, 4)
	draw_line(hand, hand + club_dir * r * 1.6, Color(0.45, 0.3, 0.15), 6.0)
	draw_circle(hand + club_dir * r * 1.6, 7.0, Color(0.4, 0.26, 0.12))
	# Gövde
	draw_circle(body, r, col.darkened(0.3))
	draw_circle(body + Vector2(0, -2), r * 0.9, col)
	draw_rect(Rect2(body.x - r * 0.85, body.y + r * 0.25, r * 1.7, 5), Color(0.35, 0.22, 0.1))
	draw_arc(body, r, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 1.5)
	# Dişler
	var mouth := body + Vector2(_face_x * 3.0, r * 0.1)
	draw_colored_polygon(PackedVector2Array([mouth + Vector2(-6, 0), mouth + Vector2(-4, -6), mouth + Vector2(-2, 0)]), Color.IVORY)
	draw_colored_polygon(PackedVector2Array([mouth + Vector2(2, 0), mouth + Vector2(4, -6), mouth + Vector2(6, 0)]), Color.IVORY)
	_eyes(body + Vector2(0, -r * 0.35), 5.5, 3.0, Color(0.85, 0.1, 0.1))


func _draw_boss(off: Vector2, r: float, col: Color) -> void:
	var breathe := sin(_anim * 2.5) * 1.5
	var body := off + Vector2(0, -r * 0.95 + breathe)
	# Yer sarsıntısı halkası (vuruş anında)
	if _lunge_time > 0.0:
		var k := 1.0 - _lunge_time / 0.2
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, BOSS_SLAM_RANGE * k, 0.0, TAU, 40, Color(1.0, 0.8, 0.4, 0.8 * (1.0 - k)), 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Kollar ve yumruklar
	for s in [-1.0, 1.0]:
		var shoulder: Vector2 = body + Vector2(s * r * 0.85, -r * 0.1)
		var fist: Vector2 = shoulder + Vector2(s * r * 0.45, r * 0.75 - breathe)
		if _lunge_time > 0.0:
			fist += Vector2(0, r * 0.35)
		draw_line(shoulder, fist, col.darkened(0.35), 11.0)
		draw_circle(fist, 10.0, col.darkened(0.15))
	# Gövde
	draw_circle(body, r, col.darkened(0.4))
	draw_circle(body + Vector2(0, -3), r * 0.9, col)
	draw_arc(body, r, 0.0, TAU, 40, Color(0, 0, 0, 0.6), 2.0)
	# Taş zırh plakaları
	draw_circle(body + Vector2(-r * 0.4, r * 0.3), r * 0.22, col.lightened(0.18))
	draw_circle(body + Vector2(r * 0.35, r * 0.4), r * 0.18, col.lightened(0.18))
	# Boynuzlar
	for s in [-1.0, 1.0]:
		var base: Vector2 = body + Vector2(s * r * 0.55, -r * 0.7)
		draw_colored_polygon(PackedVector2Array([
			base + Vector2(-s * 7.0, 4), base + Vector2(s * r * 0.55, -r * 0.75), base + Vector2(s * 7.0, 6)]),
			Color(0.92, 0.88, 0.75))
	# Gözler: öfkeliyken parlar
	var glow := Color(1.0, 0.25, 0.1) if angry else Color(1.0, 0.75, 0.2)
	for s in [-1.0, 1.0]:
		var e: Vector2 = body + Vector2(s * r * 0.3 + _face_x * 3.0, -r * 0.3)
		draw_circle(e, 7.0, Color(glow.r, glow.g, glow.b, 0.25))
		draw_circle(e, 4.0, glow)
	# Ağız
	var mouth := body + Vector2(_face_x * 3.0, r * 0.15)
	draw_line(mouth + Vector2(-10, 0), mouth + Vector2(10, 0), Color(0.12, 0.05, 0.1), 4.0)
	for i in 4:
		var tx := -8.0 + i * 5.3
		draw_colored_polygon(PackedVector2Array([
			mouth + Vector2(tx, -1), mouth + Vector2(tx + 2.5, 5), mouth + Vector2(tx + 5.0, -1)]), Color.IVORY)
