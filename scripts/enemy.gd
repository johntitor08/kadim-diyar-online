extends CharacterBody2D
## Canavar. Yapay zeka ve can tamamen sunucuda çalışır; istemciler sadece çizer.
## Bazı türler uzaktan saldırır (ok, ateş topu: mermi görüntüsü herkeste, isabet sunucuda),
## Ejderha ateş püskürür (koni), Kraken ve hayalet engellerin üstünden geçer.

const Zones := preload("res://scripts/zones.gd")

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
	# Mezarlık
	"zombie": {"name": "Zombi", "hp": 140, "damage": 15, "speed": 60.0, "xp": 45, "gold": 18,
		"radius": 17.0, "color": Color(0.45, 0.58, 0.4), "aggro": 240.0},
	"skeleton": {"name": "İskelet Okçu", "hp": 95, "damage": 14, "speed": 110.0, "xp": 50, "gold": 20,
		"radius": 15.0, "color": Color(0.9, 0.88, 0.8), "aggro": 340.0,
		"ranged": 260.0, "proj": Color(0.85, 0.8, 0.65), "shot_cd": 1.8},
	"ghost": {"name": "Hayalet", "hp": 80, "damage": 18, "speed": 125.0, "xp": 55, "gold": 22,
		"radius": 15.0, "color": Color(0.8, 0.88, 1.0), "aggro": 300.0, "phase": true},
	# Buzul
	"snow_wolf": {"name": "Kar Kurdu", "hp": 160, "damage": 20, "speed": 165.0, "xp": 80, "gold": 30,
		"radius": 16.0, "color": Color(0.88, 0.92, 0.98), "aggro": 320.0},
	"yeti": {"name": "Yeti", "hp": 380, "damage": 30, "speed": 85.0, "xp": 140, "gold": 55,
		"radius": 24.0, "color": Color(0.92, 0.94, 0.97), "aggro": 280.0},
	"ice_golem": {"name": "Buz Golemi", "hp": 520, "damage": 34, "speed": 60.0, "xp": 180, "gold": 70,
		"radius": 26.0, "color": Color(0.55, 0.78, 0.95), "aggro": 240.0},
	# Volkan
	"lava_slime": {"name": "Lav Balçığı", "hp": 260, "damage": 32, "speed": 80.0, "xp": 160, "gold": 60,
		"radius": 17.0, "color": Color(1.0, 0.42, 0.1), "aggro": 260.0},
	"imp": {"name": "Ateş İblisi", "hp": 300, "damage": 38, "speed": 150.0, "xp": 200, "gold": 75,
		"radius": 15.0, "color": Color(0.85, 0.2, 0.15), "aggro": 340.0,
		"ranged": 280.0, "proj": Color(1.0, 0.5, 0.1), "shot_cd": 2.0},
	"dragon": {"name": "Ejderha", "hp": 5000, "damage": 45, "speed": 100.0, "xp": 2000, "gold": 1200,
		"radius": 46.0, "color": Color(0.72, 0.16, 0.14), "aggro": 460.0, "phase": true, "boss": true},
	# Okyanus
	"crab": {"name": "Dev Yengeç", "hp": 200, "damage": 24, "speed": 95.0, "xp": 95, "gold": 35,
		"radius": 17.0, "color": Color(0.9, 0.36, 0.22), "aggro": 260.0, "land": true},
	"pirate": {"name": "Korsan", "hp": 240, "damage": 26, "speed": 120.0, "xp": 120, "gold": 60,
		"radius": 15.0, "color": Color(0.35, 0.25, 0.45), "aggro": 320.0, "land": true,
		"ranged": 240.0, "proj": Color(0.25, 0.25, 0.28), "shot_cd": 2.2},
	"kraken": {"name": "Kraken", "hp": 4200, "damage": 50, "speed": 90.0, "xp": 1700, "gold": 1000,
		"radius": 44.0, "color": Color(0.45, 0.2, 0.5), "aggro": 420.0, "phase": true, "sea": true, "boss": true},
}
const PROJ_SPEED := 430.0
const BREATH_RANGE := 260.0
const BREATH_HALF_ANGLE := 0.6
const BREATH_DAMAGE := 60
const BOSS_SLAM_RANGE := 95.0
const LEASH_DISTANCE := 900.0
const ATTACK_COOLDOWN := 1.0

# Senkronlanan değerler (EnemySync)
var hp := 40: set = _set_hp
var sync_pos := Vector2.ZERO
var angry := false

var enemy_type := "slime"
var zone := "meadow"
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
var _shot_cd := 0.0
var _breath_cd := 2.0
var _breath_time := 0.0
var _breath_dir := Vector2.RIGHT


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
	zone = Zones.zone_at(pos)


func _ready() -> void:
	add_to_group("enemies")
	if enemy_type == "boss":
		add_to_group("boss")
		SFX.play("boss")
	elif _data.get("boss", false):
		add_to_group("zone_boss")
		SFX.play("boss")
	var shape := CircleShape2D.new()
	shape.radius = radius * 0.8
	$CollisionShape2D.shape = shape
	if _data.get("phase", false):
		collision_mask = 0  # engellerin ve diğer canavarların üstünden geçer
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
	_breath_time = maxf(_breath_time - delta, 0.0)
	queue_redraw()


# --- Sunucu yapay zekası ---

func _server_ai(delta: float) -> void:
	_attack_cd -= delta
	_shot_cd -= delta
	_breath_cd -= delta
	var target = _find_target()
	angry = target != null
	var move := Vector2.ZERO
	if target:
		var to: Vector2 = target.sync_pos - position
		var dist := to.length()
		var ranged: float = _data.get("ranged", 0.0)
		if dist > radius + 12.0:
			move = to / dist
		if ranged > 0.0 and dist < ranged and dist > radius + 40.0:
			if dist < ranged * 0.8:
				move = Vector2.ZERO  # menzildeyken durup ateş eder
			if _shot_cd <= 0.0:
				_shot_cd = float(_data.get("shot_cd", 2.0))
				_server_shoot(target.sync_pos)
		if enemy_type == "dragon" and dist < BREATH_RANGE and _breath_cd <= 0.0:
			_breath_cd = 3.4
			_server_breath(to.normalized())
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
	# Kara canavarı suya, deniz canavarı karaya, kimse lava girmez
	if move != Vector2.ZERO:
		var next := position + move * float(_data.speed) * maxf(delta, 0.05) * 3.0
		if (_data.get("land", false) and not Zones.is_land(next)) or (_data.get("sea", false) and Zones.is_land(next)) \
				or (zone == "volcano" and not _data.get("phase", false) and Zones.in_lava(next)):
			move = Vector2.ZERO
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


## Mermi: hedefin o anki yerine uçar; vardığında oradaki oyuncular vurulur (kaçarak kurtulunabilir).
func _server_shoot(target_pos: Vector2) -> void:
	var from := position + Vector2(0, -radius)
	var to := target_pos + Vector2(0, -16)
	var t := from.distance_to(to) / PROJ_SPEED
	_shoot.rpc(from, to, t)
	get_tree().create_timer(t).timeout.connect(_server_projectile_hit.bind(target_pos))


func _server_projectile_hit(ground_pos: Vector2) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if not p.dead and p.sync_pos.distance_to(ground_pos) < 34.0:
			p.server_take_damage(int(_data.damage))


@rpc("authority", "call_local", "reliable")
func _shoot(from: Vector2, to: Vector2, t: float) -> void:
	_lunge_dir = (to - from).normalized()
	_lunge_time = 0.2
	FX.projectile(from, to, t, _data.get("proj", Color.WHITE), enemy_type)
	SFX.play("swing", from, -4.0)


## Ejderha nefesi: 0,45 sn uyarıdan sonra önündeki konide herkes yanar.
func _server_breath(dir: Vector2) -> void:
	_breath.rpc(dir)
	get_tree().create_timer(0.45).timeout.connect(_server_breath_hit.bind(dir))


func _server_breath_hit(dir: Vector2) -> void:
	print("[Ejderha] nefes")
	var mouth := position + Vector2(0, -radius * 0.9)
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead:
			continue
		var to: Vector2 = p.sync_pos + Vector2(0, -16) - mouth
		if to.length() < BREATH_RANGE and absf(dir.angle_to(to)) < BREATH_HALF_ANGLE:
			p.server_take_damage(BREATH_DAMAGE)


@rpc("authority", "call_local", "reliable")
func _breath(dir: Vector2) -> void:
	_breath_dir = dir
	_breath_time = 1.0
	_face_x = signf(dir.x) if absf(dir.x) > 0.1 else _face_x
	SFX.play("boss", position, -6.0)


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
			p.server_on_kill(enemy_type)
			p.server_roll_loot(enemy_type)
			slayers.append(p.player_name)
	if enemy_type == "boss" or _data.get("boss", false):
		Network.broadcast_system("%s yenildi! Kahramanlar: %s" % [_data.name, ", ".join(slayers) if not slayers.is_empty() else "kimse"])
	if zone != "meadow" or _data.get("boss", false):
		print("[Av] %s: %s (%s)" % [", ".join(slayers), _data.name, Zones.ZONES[zone].name])
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
		"zombie":
			_draw_zombie(off, r, col)
		"skeleton":
			_draw_skeleton(off, r, col)
		"ghost":
			_draw_ghost(off, r, col)
		"snow_wolf":
			_draw_wolf(off, r, col)
		"yeti":
			_draw_yeti(off, r, col)
		"ice_golem":
			_draw_golem(off, r, col)
		"lava_slime":
			draw_circle(off + Vector2(0, -r * 0.7), r * 1.6, Color(1.0, 0.45, 0.1, 0.15 + 0.05 * sin(_anim * 4.0)))
			_draw_slime(off, r, col)
		"imp":
			_draw_imp(off, r, col)
		"dragon":
			_draw_dragon(off, r, col)
		"crab":
			_draw_crab(off, r, col)
		"pirate":
			_draw_pirate(off, r, col)
		"kraken":
			_draw_kraken(off, r, col)

	var top := -r * 2.4 - 6.0
	var big_boss: bool = enemy_type == "boss" or _data.get("boss", false)
	var name_size := 15 if big_boss else 11
	if enemy_type == "dragon" or enemy_type == "kraken":
		top = -r * 2.9
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


# --- Bölge canavarları ---

func _draw_zombie(off: Vector2, r: float, col: Color) -> void:
	var sway := sin(_anim * 3.0) * 2.0
	var body := off + Vector2(sway * 0.5, -r * 1.0)
	var shirt := Color(0.35, 0.3, 0.4) if _flash <= 0.0 else col
	# Bacaklar
	draw_rect(Rect2(body + Vector2(-7, r * 0.55), Vector2(5, r * 0.5)), Color(0.25, 0.22, 0.3))
	draw_rect(Rect2(body + Vector2(2, r * 0.55), Vector2(5, r * 0.5)), Color(0.25, 0.22, 0.3))
	# Gövde (yırtık gömlek)
	draw_rect(Rect2(body + Vector2(-r * 0.6, -r * 0.3), Vector2(r * 1.2, r * 0.9)), shirt)
	draw_colored_polygon(PackedVector2Array([body + Vector2(-r * 0.6, r * 0.6), body + Vector2(-r * 0.3, r * 0.4),
		body + Vector2(0, r * 0.6), body + Vector2(r * 0.3, r * 0.4), body + Vector2(r * 0.6, r * 0.6)]), shirt.darkened(0.2))
	# Öne uzanan kollar
	for k in [-1.0, 1.0]:
		var sh: Vector2 = body + Vector2(k * r * 0.45, -r * 0.15)
		var hand: Vector2 = sh + Vector2(_face_x * r * 1.0, k * 3.0 + sway)
		draw_line(sh, hand, col.darkened(0.15), 5.0)
		draw_circle(hand, 3.5, col)
	# Kafa
	var head := body + Vector2(_face_x * 2.0, -r * 0.75)
	draw_circle(head, r * 0.55, col)
	draw_circle(head + Vector2(_face_x * 3.0 - 3.0, -1), 2.6, Color(0.1, 0.05, 0.05))
	draw_circle(head + Vector2(_face_x * 3.0 + 3.0, -2), 2.0, Color(0.9, 0.85, 0.3))
	draw_line(head + Vector2(-4, 5), head + Vector2(5, 4), Color(0.25, 0.1, 0.1), 2.0)


func _draw_skeleton(off: Vector2, r: float, col: Color) -> void:
	var body := off + Vector2(0, -r * 1.05)
	var bone := col
	# Bacak kemikleri
	draw_line(body + Vector2(-3, r * 0.5), body + Vector2(-5, r * 1.05), bone, 2.5)
	draw_line(body + Vector2(3, r * 0.5), body + Vector2(5, r * 1.05), bone, 2.5)
	# Kaburgalar
	draw_line(body + Vector2(0, -r * 0.4), body + Vector2(0, r * 0.5), bone, 3.0)
	for k in 3:
		var y := -r * 0.25 + k * r * 0.22
		draw_arc(body + Vector2(0, y), r * 0.42 - k * 1.5, PI * 0.15, PI * 0.85, 8, bone, 2.0)
	# Yay ve kol
	var hand := body + Vector2(_face_x * r * 0.75, -r * 0.05)
	draw_line(body + Vector2(0, -r * 0.3), hand, bone, 2.0)
	var bow_c := hand + Vector2(_face_x * 4.0, 0)
	var start := -PI * 0.5 if _face_x > 0 else PI * 0.5
	draw_arc(bow_c, r * 0.8, start, start + PI, 12, Color(0.5, 0.33, 0.18), 2.5)
	draw_line(bow_c + Vector2(0, -r * 0.8), bow_c + Vector2(0, r * 0.8), Color(0.9, 0.9, 0.9, 0.7), 1.0)
	# Kafatası
	var head := body + Vector2(0, -r * 0.85)
	draw_circle(head, r * 0.55, bone)
	draw_rect(Rect2(head + Vector2(-r * 0.3, r * 0.25), Vector2(r * 0.6, r * 0.35)), bone)
	draw_circle(head + Vector2(_face_x * 2.0 - 3.5, -1), 2.8, Color(0.1, 0.08, 0.08))
	draw_circle(head + Vector2(_face_x * 2.0 + 3.5, -1), 2.8, Color(0.1, 0.08, 0.08))
	if angry:
		draw_circle(head + Vector2(_face_x * 2.0 - 3.5, -1), 1.2, Color(1, 0.3, 0.2))
		draw_circle(head + Vector2(_face_x * 2.0 + 3.5, -1), 1.2, Color(1, 0.3, 0.2))


func _draw_ghost(off: Vector2, r: float, col: Color) -> void:
	var float_y := sin(_anim * 2.5) * 4.0
	var c := off + Vector2(0, -r * 1.4 + float_y)
	var sheet := Color(col.r, col.g, col.b, 0.72)
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	for i in 7:
		var x := r - i * (r * 2.0 / 6.0)
		var y := r * 1.1 + (5.0 if i % 2 == 0 else -1.0) + sin(_anim * 6.0 + i) * 2.0
		pts.append(c + Vector2(x, y))
	draw_colored_polygon(pts, sheet)
	draw_circle(c + Vector2(_face_x * 3.0 - 4.5, -2), 3.2, Color(0.05, 0.05, 0.12, 0.85))
	draw_circle(c + Vector2(_face_x * 3.0 + 4.5, -2), 3.2, Color(0.05, 0.05, 0.12, 0.85))
	draw_circle(c + Vector2(_face_x * 3.0, 6), 3.0, Color(0.05, 0.05, 0.12, 0.6))


func _draw_yeti(off: Vector2, r: float, col: Color) -> void:
	var body := off + Vector2(0, -r * 0.95)
	var fur := col.darkened(0.08)
	for k in [-1.0, 1.0]:
		var sh: Vector2 = body + Vector2(k * r * 0.8, -r * 0.1)
		var fist: Vector2 = sh + Vector2(k * r * 0.25, r * 0.8)
		if _lunge_time > 0.0:
			fist += _lunge_dir * 10.0
		draw_line(sh, fist, fur, 10.0)
		draw_circle(fist, 7.0, fur)
	draw_circle(body, r, fur.darkened(0.15))
	draw_circle(body + Vector2(0, -2), r * 0.92, fur)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		draw_circle(body + Vector2.from_angle(a) * r * 0.78, r * 0.22, fur.lightened(0.08))
	var face := body + Vector2(_face_x * r * 0.25, -r * 0.3)
	draw_circle(face, r * 0.42, Color(0.45, 0.6, 0.78))
	draw_circle(face + Vector2(-4, -2), 2.4, Color(0.05, 0.05, 0.1))
	draw_circle(face + Vector2(4, -2), 2.4, Color(0.05, 0.05, 0.1))
	draw_line(face + Vector2(-5, 5), face + Vector2(5, 5), Color(0.1, 0.1, 0.15), 2.0)
	draw_colored_polygon(PackedVector2Array([face + Vector2(-4, 5), face + Vector2(-2.5, 9), face + Vector2(-1, 5)]), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([face + Vector2(1, 5), face + Vector2(2.5, 9), face + Vector2(4, 5)]), Color.WHITE)


func _draw_golem(off: Vector2, r: float, col: Color) -> void:
	var body := off + Vector2(0, -r * 0.95)
	var ice := col
	var dark := col.darkened(0.3)
	for k in [-1.0, 1.0]:
		var arm := PackedVector2Array([body + Vector2(k * r * 0.7, -r * 0.4), body + Vector2(k * r * 1.25, -r * 0.2),
			body + Vector2(k * r * 1.15, r * 0.7), body + Vector2(k * r * 0.75, r * 0.6)])
		draw_colored_polygon(arm, dark)
	var torso := PackedVector2Array([body + Vector2(-r * 0.8, -r * 0.7), body + Vector2(r * 0.7, -r * 0.85),
		body + Vector2(r * 0.85, r * 0.6), body + Vector2(-r * 0.7, r * 0.75)])
	draw_colored_polygon(torso, ice)
	draw_polyline(torso + PackedVector2Array([torso[0]]), dark, 2.0)
	draw_line(body + Vector2(-r * 0.4, -r * 0.5), body + Vector2(-r * 0.1, r * 0.3), Color(1, 1, 1, 0.5), 2.0)
	var head := PackedVector2Array([body + Vector2(-r * 0.35, -r * 0.85), body + Vector2(r * 0.4, -r * 0.9),
		body + Vector2(r * 0.35, -r * 1.4), body + Vector2(-r * 0.3, -r * 1.35)])
	draw_colored_polygon(head, ice.lightened(0.1))
	var glow := Color(0.4, 0.9, 1.0) if not angry else Color(1.0, 1.0, 1.0)
	draw_circle(body + Vector2(_face_x * 3.0 - 5.0, -r * 1.12), 3.0, glow)
	draw_circle(body + Vector2(_face_x * 3.0 + 5.0, -r * 1.14), 3.0, glow)


func _draw_imp(off: Vector2, r: float, col: Color) -> void:
	var flap := sin(_anim * 14.0) * 6.0
	var c := off + Vector2(0, -r * 1.4 + sin(_anim * 3.0) * 3.0)
	var wing := col.darkened(0.45)
	for k in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(k * 4.0, -4), c + Vector2(k * r * 1.5, -r * 0.6 - flap),
			c + Vector2(k * r * 1.1, r * 0.1), c + Vector2(k * r * 1.4, r * 0.3)]), wing)
	draw_line(c + Vector2(0, r * 0.6), c + Vector2(-_face_x * r * 0.9, r * 1.1), col.darkened(0.2), 2.5)
	draw_circle(c, r * 0.8, col)
	for k in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([c + Vector2(k * 4.0, -r * 0.6), c + Vector2(k * 9.0, -r * 1.3),
			c + Vector2(k * 9.0, -r * 0.5)]), Color(0.25, 0.1, 0.08))
	draw_circle(c + Vector2(_face_x * 3.0 - 3.0, -2), 2.2, Color(1.0, 0.9, 0.3))
	draw_circle(c + Vector2(_face_x * 3.0 + 3.0, -2), 2.2, Color(1.0, 0.9, 0.3))
	var orb := c + Vector2(_face_x * r * 1.1, 4)
	draw_circle(orb, 6.0 + sin(_anim * 9.0), Color(1.0, 0.55, 0.1, 0.9))
	draw_circle(orb, 3.0, Color(1.0, 0.9, 0.5))


func _draw_dragon(off: Vector2, r: float, col: Color) -> void:
	var fly := sin(_anim * 2.0) * 6.0
	var c := off + Vector2(0, -r * 1.5 + fly)
	var flap := sin(_anim * 4.0) * r * 0.45
	var dark := col.darkened(0.4)
	var f := _face_x
	# Kanatlar
	for k in [-1.0, 1.0]:
		var root: Vector2 = c + Vector2(k * r * 0.2, -r * 0.3)
		draw_colored_polygon(PackedVector2Array([root, c + Vector2(k * r * 1.7, -r * 1.2 - flap),
			c + Vector2(k * r * 2.3, -r * 0.2 - flap * 0.5), c + Vector2(k * r * 1.6, r * 0.1),
			c + Vector2(k * r * 1.0, -r * 0.05)]), dark)
		draw_line(root, c + Vector2(k * r * 1.7, -r * 1.2 - flap), col.darkened(0.2), 3.0)
	# Kuyruk
	var tail := PackedVector2Array()
	for i in 8:
		var t := i / 7.0
		tail.append(c + Vector2(-f * (r * 0.6 + t * r * 1.6), r * 0.3 + sin(_anim * 3.0 + t * 3.0) * 8.0 * t))
	draw_polyline(tail, col, 9.0)
	draw_colored_polygon(PackedVector2Array([tail[7] + Vector2(0, -8), tail[7] + Vector2(-f * 14.0, 0), tail[7] + Vector2(0, 8)]), dark)
	# Gövde ve karın
	draw_set_transform(c, 0.0, Vector2(1.25, 0.85))
	draw_circle(Vector2.ZERO, r * 0.8, col)
	draw_circle(Vector2(f * r * 0.1, r * 0.25), r * 0.5, Color(0.95, 0.75, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Boyun ve kafa
	var head := c + Vector2(f * r * 1.15, -r * 0.75)
	draw_line(c + Vector2(f * r * 0.5, -r * 0.3), head, col, 14.0)
	draw_circle(head, r * 0.42, col)
	draw_colored_polygon(PackedVector2Array([head + Vector2(f * r * 0.2, -6), head + Vector2(f * r * 0.85, 2),
		head + Vector2(f * r * 0.2, 10)]), col.lightened(0.05))
	for k in [-1.0, 1.0]:
		var hb := head + Vector2(-f * 3.0 + k * 7.0, -r * 0.28)
		draw_colored_polygon(PackedVector2Array([hb + Vector2(-4, 2), hb + Vector2(-f * r * 0.35, -r * 0.6),
			hb + Vector2(4, 2)]), Color(0.9, 0.85, 0.7))
	draw_circle(head + Vector2(f * 6.0, -6), 4.0, Color(1.0, 0.85, 0.2))
	draw_circle(head + Vector2(f * 7.0, -6), 1.8, Color(0.1, 0.0, 0.0))
	# Ateş nefesi (ilk 0,45 sn ağızda kor, sonra koni)
	if _breath_time > 0.0:
		var mouth := head + Vector2(f * r * 0.8, 2)
		var age := 1.0 - _breath_time
		if age < 0.45:
			draw_circle(mouth, 6.0 + age * 20.0, Color(1.0, 0.6, 0.1, 0.7))
		else:
			var k := clampf((age - 0.45) / 0.25, 0.0, 1.0)
			var len := BREATH_RANGE * k
			var fade := clampf((1.0 - age) / 0.3, 0.0, 1.0)
			var a := _breath_dir.angle()
			var cone := PackedVector2Array([mouth])
			for i in 9:
				cone.append(mouth + Vector2.from_angle(a - BREATH_HALF_ANGLE + BREATH_HALF_ANGLE * 2.0 * i / 8.0) * len)
			draw_colored_polygon(cone, Color(1.0, 0.45, 0.08, 0.55 * fade))
			var inner := PackedVector2Array([mouth])
			for i in 7:
				inner.append(mouth + Vector2.from_angle(a - BREATH_HALF_ANGLE * 0.55 + BREATH_HALF_ANGLE * 1.1 * i / 6.0) * len * 0.8)
			draw_colored_polygon(inner, Color(1.0, 0.85, 0.3, 0.6 * fade))


func _draw_crab(off: Vector2, r: float, col: Color) -> void:
	var c := off + Vector2(0, -r * 0.6)
	var walk := sin(_anim * 10.0) * 3.0
	for k in [-1.0, 1.0]:
		for i in 3:
			var base: Vector2 = c + Vector2(k * r * 0.6, -2 + i * 5)
			draw_line(base, base + Vector2(k * r * 0.6, 6 + (walk if i % 2 == 0 else -walk) * 0.5), col.darkened(0.3), 2.5)
		var arm: Vector2 = c + Vector2(k * r * 0.7, -r * 0.4)
		var claw: Vector2 = arm + Vector2(k * r * 0.5, -r * 0.5) + (_lunge_dir * 8.0 if _lunge_time > 0.0 else Vector2.ZERO)
		draw_line(arm, claw, col, 4.0)
		draw_circle(claw, 6.0, col.lightened(0.1))
		draw_colored_polygon(PackedVector2Array([claw + Vector2(-2, -4), claw + Vector2(k * 9.0, -9), claw + Vector2(2, -1)]), col.darkened(0.2))
	draw_set_transform(c, 0.0, Vector2(1.3, 0.8))
	draw_circle(Vector2.ZERO, r * 0.8, col)
	draw_circle(Vector2(0, -2), r * 0.6, col.lightened(0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in [-1.0, 1.0]:
		draw_line(c + Vector2(k * 4.0, -r * 0.4), c + Vector2(k * 5.0, -r * 0.85), col.darkened(0.3), 2.0)
		draw_circle(c + Vector2(k * 5.0, -r * 0.9), 2.6, Color.WHITE)
		draw_circle(c + Vector2(k * 5.0 + _face_x, -r * 0.9), 1.3, Color.BLACK)


func _draw_pirate(off: Vector2, r: float, col: Color) -> void:
	var body := off + Vector2(0, -r * 1.05)
	draw_rect(Rect2(body + Vector2(-6, r * 0.5), Vector2(5, r * 0.55)), Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(body + Vector2(1, r * 0.5), Vector2(5, r * 0.55)), Color(0.2, 0.15, 0.1))
	draw_circle(body, r * 0.75, col)
	draw_line(body + Vector2(-r * 0.6, -r * 0.2), body + Vector2(r * 0.6, r * 0.3), Color(0.85, 0.75, 0.3), 3.0)
	var hand := body + Vector2(_face_x * r * 0.8, 0)
	draw_line(hand, hand + Vector2(_face_x * 14.0, -2), Color(0.25, 0.25, 0.28), 4.0)  # tabanca
	draw_circle(hand, 3.5, Color(0.9, 0.72, 0.55))
	var head := body + Vector2(0, -r * 0.95)
	draw_circle(head, r * 0.5, Color(0.9, 0.72, 0.55))
	draw_rect(Rect2(head + Vector2(-r * 0.6, -r * 0.55), Vector2(r * 1.2, r * 0.3)), Color(0.12, 0.1, 0.1))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-r * 0.75, -r * 0.4), head + Vector2(0, -r * 1.1),
		head + Vector2(r * 0.75, -r * 0.4)]), Color(0.12, 0.1, 0.1))
	draw_circle(head + Vector2(0, -r * 0.7), 2.5, Color.WHITE)
	draw_circle(head + Vector2(_face_x * 3.0 - 3.0, 0), 2.0, Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(head + Vector2(_face_x * 3.0 + 1.0, -3), Vector2(5, 5)), Color(0.1, 0.1, 0.1))  # göz bandı
	draw_line(head + Vector2(-4, 5), head + Vector2(4, 6), Color(0.3, 0.15, 0.1), 2.0)


func _draw_kraken(off: Vector2, r: float, col: Color) -> void:
	var c := off + Vector2(0, -r * 0.6)
	# Su halkaları
	draw_set_transform(c + Vector2(0, r * 0.5), 0.0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, r * 1.4 + sin(_anim * 2.0) * 6.0, 0.0, TAU, 32, Color(0.8, 0.9, 1.0, 0.4), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Dokunaçlar
	for k in 6:
		var a := PI * 0.1 + PI * 0.8 * k / 5.0
		var pts := PackedVector2Array()
		for i in 7:
			var t := i / 6.0
			var w := sin(_anim * 3.0 + k + t * 4.0) * 10.0 * t
			pts.append(c + Vector2(cos(a + PI) * r * (0.6 + t * 1.3) + w, -sin(a) * r * (0.2 + t * 0.9) + r * 0.3))
		draw_polyline(pts, col.darkened(0.1), 8.0 - k % 2 * 2.0)
	# Kafa
	draw_set_transform(c + Vector2(0, -r * 0.3), 0.0, Vector2(1.0, 1.25))
	draw_circle(Vector2.ZERO, r * 0.75, col)
	draw_circle(Vector2(-r * 0.2, -r * 0.3), r * 0.2, col.lightened(0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var eye_col := Color(1.0, 0.85, 0.2) if not angry else Color(1.0, 0.3, 0.2)
	for k in [-1.0, 1.0]:
		draw_circle(c + Vector2(k * r * 0.3, -r * 0.15), 6.0, eye_col)
		draw_rect(Rect2(c + Vector2(k * r * 0.3 - 1.0, -r * 0.15 - 4.0), Vector2(2, 8)), Color.BLACK)
