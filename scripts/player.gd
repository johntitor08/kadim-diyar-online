extends CharacterBody2D
## Oyuncu karakteri.
## - Hareket ve bakış yönü sahibinde (owner) hesaplanır ve PosSync ile yayılır.
## - Can, XP, seviye sunucuda hesaplanır ve StatsSync ile yayılır.

const SPEED := 230.0
const ATTACK_RANGE := 72.0
const ATTACK_ARC := PI * 0.66  # ~120 derece
const ATTACK_COOLDOWN := 0.45
const SWING_DURATION := 0.18
const RESPAWN_TIME := 3.0
const REGEN_DELAY := 5.0
const SPAWN_POINT := Vector2(1600, 1600)
const BASE_HP := 100
const BASE_DAMAGE := 12
const START_GOLD := 30
const POTION_COST := 30
const POTION_MAX := 5
const POTION_HEAL := 0.4  # azami canın oranı
const POTION_COOLDOWN := 6.0
const MERCHANT_POS := Vector2(1775, 1480)
const MERCHANT_RANGE := 120.0

# --- Sunucunun yönettiği değerler (StatsSync) ---
var hp := 100: set = _set_hp
var max_hp := 100
var level := 1: set = _set_level
var xp := 0: set = _set_xp
var damage := 12
var dead := false
var gold := 0: set = _set_gold
var potions := 0: set = _set_potions

# --- Sahibin yönettiği değerler (PosSync) ---
var sync_pos := Vector2.ZERO
var facing := Vector2.RIGHT

# Spawn verisinden gelir (tüm peer'larda aynı)
var peer_id := 1
var player_name := "Gezgin"
var color := Color.WHITE

var _attack_cd := 0.0
var _attack_held := false
var _swing_time := 0.0
var _swing_dir := Vector2.RIGHT
var _flash := 0.0
var _walk_anim := 0.0
var _moving := false
var _prev_pos := Vector2.ZERO
var _born_ms := 0
var _server_last_attack := 0.0
var _server_last_hit := -100.0
var _regen_acc := 0.0
var _server_last_potion := -100.0
var _bot_shopping := false

## Yalnızca sunucuda dolu: ilerlemenin saklandığı anahtar ("" = misafir, kaydedilmez).
var save_key := ""


func _ready() -> void:
	add_to_group("players")
	_born_ms = Time.get_ticks_msec()
	color = Color.from_hsv(fmod(float(peer_id % 997) * 0.618034, 1.0), 0.55, 0.95)
	$NameLabel.text = player_name
	sync_pos = position
	_prev_pos = position
	if is_multiplayer_authority():
		add_to_group("local_player")
		$Camera2D.enabled = true
		$Camera2D.make_current()


func xp_to_next() -> int:
	return 40 + (level - 1) * 30


## Seviyeden türeyen değerleri kurar (spawn anında, tüm peer'larda aynı veriyle).
func apply_progress(lv: int, xp_value: int, gold_value: int, potion_count: int) -> void:
	level = lv
	xp = xp_value
	gold = gold_value
	potions = potion_count
	max_hp = BASE_HP + (lv - 1) * 20
	damage = BASE_DAMAGE + (lv - 1) * 4
	hp = max_hp


func near_merchant() -> bool:
	return position.distance_to(MERCHANT_POS) < MERCHANT_RANGE


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_process_local(delta)
	else:
		position = position.lerp(sync_pos, clampf(delta * 14.0, 0.0, 1.0))
		if position.distance_squared_to(sync_pos) > 250000.0:
			position = sync_pos
	if multiplayer.is_server():
		_server_regen(delta)

	_moving = position.distance_squared_to(_prev_pos) > 0.25
	_prev_pos = position
	if _moving:
		_walk_anim += delta * 14.0
	_swing_time = maxf(_swing_time - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _process_local(delta: float) -> void:
	var dir := Vector2.ZERO
	if Network.bot_mode:
		dir = _bot_think()
	elif not dead and not _typing():
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var to_mouse := get_global_mouse_position() - (global_position + Vector2(0, -16))
		if to_mouse.length() > 4.0:
			facing = to_mouse.normalized()
	velocity = Vector2.ZERO if dead else dir * SPEED
	move_and_slide()
	sync_pos = position

	_attack_cd -= delta
	_attack_held = _attack_held and (Input.is_action_pressed("attack") or Network.bot_mode)
	if _attack_held and _attack_cd <= 0.0 and not dead and not _typing():
		_attack_cd = ATTACK_COOLDOWN
		attack.rpc(facing)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("attack"):
		_attack_held = true
	elif event.is_action_released("attack"):
		_attack_held = false
	elif event.is_action_pressed("use_potion"):
		try_use_potion()
	elif event.is_action_pressed("buy_potion"):
		try_buy_potion()


func try_use_potion() -> void:
	if potions > 0 and not dead and hp < max_hp:
		_use_potion.rpc_id(1)


func try_buy_potion() -> void:
	if dead:
		return
	if not near_merchant():
		FX.floating_text(global_position, "Tüccar kampta", Color(1, 0.8, 0.5), 13)
	elif potions >= POTION_MAX:
		FX.floating_text(global_position, "Çantan dolu", Color(1, 0.8, 0.5), 13)
	elif gold < POTION_COST:
		FX.floating_text(global_position, "Altın yetmiyor", Color(1, 0.5, 0.4), 13)
	else:
		_buy_potion.rpc_id(1)


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


## Basit test botu: en yakın canavara yürür ve saldırır.
func _bot_think() -> Vector2:
	_attack_held = false
	if dead:
		return Vector2.ZERO
	if hp < max_hp * 0.5:
		try_use_potion()
	# Parası yetiyorsa önce tüccara uğrar.
	if potions == 0 and gold >= POTION_COST:
		_bot_shopping = true
	elif potions > 0 or gold < POTION_COST:
		_bot_shopping = false
	if _bot_shopping:
		if near_merchant():
			try_buy_potion()
			return Vector2.ZERO
		facing = (MERCHANT_POS + Vector2(0, 40) - position).normalized()
		return facing
	var best = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = position.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	if best == null or dead:
		return Vector2.ZERO
	facing = (best.position - position).normalized()
	_attack_held = best_d < ATTACK_RANGE
	return facing if best_d > ATTACK_RANGE * 0.6 else Vector2.ZERO


# --- Saldırı ---

@rpc("authority", "call_local", "reliable")
func attack(dir: Vector2) -> void:
	_swing_dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	_swing_time = SWING_DURATION
	SFX.play("swing", global_position, -6.0)
	if multiplayer.is_server():
		_server_resolve_attack(_swing_dir)


func _server_resolve_attack(dir: Vector2) -> void:
	if dead:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _server_last_attack < ATTACK_COOLDOWN * 0.7:
		return  # hile koruması: çok hızlı saldırıları yok say
	_server_last_attack = now
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector2 = enemy.position - sync_pos
		var reach: float = ATTACK_RANGE + enemy.radius
		if to.length() > reach:
			continue
		if to.length() > 10.0 and absf(dir.angle_to(to)) > ATTACK_ARC * 0.5:
			continue
		var dmg := damage + randi_range(-2, 3)
		if randf() < 0.12:
			dmg *= 2  # kritik vuruş
		enemy.server_take_damage(dmg, self)


# --- İksir (istek sahibinden gelir, sunucu doğrular) ---

@rpc("authority", "call_local", "reliable")
func _use_potion() -> void:
	if not multiplayer.is_server() or dead or potions <= 0 or hp >= max_hp:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - _server_last_potion < POTION_COOLDOWN:
		return
	_server_last_potion = now
	potions -= 1
	hp = mini(hp + int(max_hp * POTION_HEAL), max_hp)
	print("[İksir] %s içti (kalan %d)." % [player_name, potions])


@rpc("authority", "call_local", "reliable")
func _buy_potion() -> void:
	if not multiplayer.is_server() or dead:
		return
	if gold < POTION_COST or potions >= POTION_MAX or sync_pos.distance_to(MERCHANT_POS) > MERCHANT_RANGE + 40.0:
		return
	gold -= POTION_COST
	potions += 1
	print("[Tüccar] %s iksir aldı (altın %d, iksir %d)." % [player_name, gold, potions])


func server_add_gold(amount: int) -> void:
	gold += amount


# --- Sunucu tarafı can / XP ---

func server_take_damage(amount: int) -> void:
	if dead:
		return
	_server_last_hit = Time.get_ticks_msec() * 0.001
	hp = maxi(hp - amount, 0)
	if hp == 0:
		dead = true
		Network.broadcast_system("%s yenik düştü!" % player_name)
		get_tree().create_timer(RESPAWN_TIME).timeout.connect(_server_respawn)


func server_add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		var need := xp_to_next()
		level += 1
		xp -= need
		max_hp += 20
		damage += 4
		hp = max_hp
		Network.broadcast_system("%s seviye %d oldu!" % [player_name, level])


func _server_regen(delta: float) -> void:
	if dead or hp >= max_hp:
		return
	if Time.get_ticks_msec() * 0.001 - _server_last_hit < REGEN_DELAY:
		return
	_regen_acc += delta
	if _regen_acc >= 1.0:
		_regen_acc = 0.0
		hp = mini(hp + maxi(1, int(max_hp * 0.04)), max_hp)


func _server_respawn() -> void:
	hp = max_hp
	dead = false
	var pos := SPAWN_POINT + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 110.0)
	sync_pos = pos
	position = pos
	if peer_id == multiplayer.get_unique_id():
		_teleport(pos)
	else:
		_teleport.rpc_id(peer_id, pos)


@rpc("any_peer", "reliable")
func _teleport(pos: Vector2) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return  # sadece sunucu ışınlayabilir
	position = pos
	sync_pos = pos


# --- Setter'lar: senkron gelen değişikliklerde efekt oynat ---

func _fx_ready() -> bool:
	return is_inside_tree() and Time.get_ticks_msec() - _born_ms > 500


func _set_hp(value: int) -> void:
	if _fx_ready() and value < hp:
		_flash = 0.15
		FX.floating_text(global_position, str(hp - value), Color(1.0, 0.35, 0.3))
		SFX.play("hurt", global_position)
	hp = value


func _set_level(value: int) -> void:
	if _fx_ready() and value > level:
		FX.floating_text(global_position + Vector2(0, -24), "SEVİYE %d!" % value, Color.GOLD, 22)
		FX.poof(global_position, Color.GOLD)
		SFX.play("levelup", global_position)
	level = value


func _set_xp(value: int) -> void:
	if _fx_ready() and value > xp and is_multiplayer_authority():
		FX.floating_text(global_position + Vector2(40, 10), "+%d XP" % (value - xp), Color(0.5, 0.8, 1.0), 13)
	xp = value


func _set_gold(value: int) -> void:
	if _fx_ready() and value > gold and is_multiplayer_authority():
		FX.floating_text(global_position + Vector2(-40, 10), "+%d altın" % (value - gold), Color(1.0, 0.85, 0.3), 13)
		SFX.play("coin", null, -4.0)
	gold = value


func _set_potions(value: int) -> void:
	if _fx_ready() and value < potions:
		FX.floating_text(global_position + Vector2(0, -20), "İksir!", Color(0.45, 1.0, 0.55), 15)
		FX.poof(global_position, Color(0.4, 0.95, 0.5))
		SFX.play("potion", global_position)
	elif _fx_ready() and value > potions and is_multiplayer_authority():
		FX.floating_text(global_position + Vector2(0, -20), "+1 iksir", Color(0.45, 1.0, 0.55), 14)
		SFX.play("coin", null, -4.0)
	potions = value


# --- Çizim ---

func _draw() -> void:
	var bob := sin(_walk_anim) * 2.0 if _moving else 0.0
	var col := color
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.7)
	if dead:
		col = Color(0.45, 0.45, 0.45)
	modulate.a = 0.45 if dead else 1.0

	# Gölge
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Ayaklar
	var step := sin(_walk_anim) * 3.0 if _moving else 0.0
	draw_circle(Vector2(-6, -3 + step), 4.5, col.darkened(0.55))
	draw_circle(Vector2(6, -3 - step), 4.5, col.darkened(0.55))

	var body := Vector2(0, -18 + bob)
	var sword_behind := facing.y < -0.2
	if sword_behind:
		_draw_sword(body)

	# Gövde
	draw_circle(body, 14.0, col.darkened(0.3))
	draw_circle(body + Vector2(0, -2), 12.0, col)
	draw_arc(body, 14.0, 0.0, TAU, 28, Color(0, 0, 0, 0.55), 1.5)

	# Gözler (arkası dönükse gözükmez)
	if facing.y > -0.6:
		var perp := facing.orthogonal()
		var eye := body + Vector2(facing.x * 6.0, -3.0 + facing.y * 3.0)
		for s in [-1.0, 1.0]:
			var e: Vector2 = eye + perp * 4.0 * s
			draw_circle(e, 2.8, Color.WHITE)
			draw_circle(e + facing * 1.2, 1.4, Color(0.1, 0.1, 0.15))

	if not sword_behind:
		_draw_sword(body)

	# Can barı
	var ratio := float(hp) / float(max(max_hp, 1))
	draw_rect(Rect2(-19, -50, 38, 6), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-18, -49, 36.0 * ratio, 4), Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.9, 0.35), ratio))


func _draw_sword(body: Vector2) -> void:
	var angle: float
	if _swing_time > 0.0:
		var p := 1.0 - _swing_time / SWING_DURATION
		angle = _swing_dir.angle() - ATTACK_ARC * 0.5 + ATTACK_ARC * p
		# Kesme izi
		var start := _swing_dir.angle() - ATTACK_ARC * 0.5
		draw_arc(body, ATTACK_RANGE * 0.8, start, angle, 20, Color(1, 1, 1, 0.55 * (1.0 - p) + 0.15), 6.0)
	else:
		angle = facing.angle() + 1.0
	var d := Vector2.from_angle(angle)
	var hand := body + d * 12.0
	var tip := body + d * 44.0
	draw_line(hand, tip, Color(0.85, 0.88, 0.95), 4.0)
	draw_line(hand, tip, Color(1, 1, 1, 0.8), 1.5)
	draw_line(hand - d.orthogonal() * 6.0, hand + d.orthogonal() * 6.0, Color(0.55, 0.4, 0.15), 3.0)
	draw_circle(hand, 3.0, Color(0.4, 0.28, 0.12))
