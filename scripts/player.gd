extends CharacterBody2D
## Oyuncu karakteri.
## - Hareket ve bakış yönü sahibinde (owner) hesaplanır ve PosSync ile yayılır.
## - Can, XP, seviye, altın, kuşanılan eşyanın nadirliği ve görev sunucuda hesaplanır, StatsSync ile yayılır.
## - Çantanın tamamı yalnızca sunucuda ve sahibinde bulunur (_inv_sync ile gönderilir).
## - İstekler (iksir, kuşan, sat, görev, yetenek) sahibinden gelir, sunucu doğrular.

signal inventory_changed

const Look := preload("res://scripts/look.gd")
const Items := preload("res://scripts/items.gd")
const Quests := preload("res://scripts/quests.gd")
const Zones := preload("res://scripts/zones.gd")

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
const ORACLE_POS := Vector2(1425, 1480)
const MERCHANT_RANGE := 120.0

const SKILL_ORDER := ["spin", "dash", "heal"]
const SKILLS := {
	"spin": {"name": "Kasırga", "key": "E", "level": 3, "cooldown": 6.0},
	"dash": {"name": "Atılma", "key": "Shift", "level": 5, "cooldown": 4.0},
	"heal": {"name": "Şifa", "key": "R", "level": 8, "cooldown": 20.0},
}
const SPIN_RANGE := 95.0
const SPIN_DAMAGE := 1.6
const SPIN_TIME := 0.35
const DASH_SPEED := 950.0
const DASH_TIME := 0.17
const HEAL_RANGE := 230.0
const HEAL_RATIO := 0.3
const BOAT_SPEED := 1.35   # suda tekne, yürümekten hızlı
const LAVA_DAMAGE := 0.06  # saniyede azami canın oranı
## Market: vitrin bu kadar saniyede bir yenilenir; eşya fiyatı = satış fiyatı x MARKET_MARKUP
const MARKET_PERIOD := 600
const MARKET_MARKUP := 4
const MARKET_SIZE := 5

# --- Sunucunun yönettiği değerler (StatsSync) ---
var hp := 100: set = _set_hp
var max_hp := 100
var level := 1: set = _set_level
var xp := 0: set = _set_xp
var damage := 12
var dead := false
var gold := 0: set = _set_gold
var potions := 0: set = _set_potions
var weapon_rarity := -1
var armor_rarity := -1
var quest_kind := ""
var quest_have := 0: set = _set_quest_have
var quest_need := 0

# --- Sahibin yönettiği değerler (PosSync) ---
var sync_pos := Vector2.ZERO
var facing := Vector2.RIGHT

# Spawn verisinden gelir (tüm peer'larda aynı)
var peer_id := 1
var player_name := "Gezgin"
var look: Dictionary = {}

# --- Yalnızca sunucuda ---
## İlerlemenin saklandığı anahtar ("" = misafir, kaydedilmez).
var save_key := ""
var inv: Array = []
var weapon: Dictionary = {}
var armor: Dictionary = {}
var _next_item_id := 1
var _server_last_attack := 0.0
var _server_last_hit := -100.0
var _server_last_potion := -100.0
var _server_skill_ready := {}
var _server_invuln_until := -1.0
var _regen_acc := 0.0

# --- Yalnızca sahibinde: arayüz için çanta kopyası ve yetenek bekleme süreleri ---
var client_inv: Array = []
var client_weapon: Dictionary = {}
var client_armor: Dictionary = {}
var skill_ready_at := {}
## Market vitrini (sahibinde): {"period", "offers": [eşya + "price"], "bought": [indeks], "left": sn}
signal market_changed
var client_market := {}
var _market_bought := {}  # sunucu: dönem -> [indeks]
var _portal_cd := 0.0
var _lava_acc := 0.0
var _was_on_water := false

# --- Görsel durum ---
var _attack_cd := 0.0
var _attack_held := false
var _swing_time := 0.0
var _swing_dir := Vector2.RIGHT
var _spin_time := 0.0
var _dash_left := 0.0
var _dash_dir := Vector2.ZERO
var _dash_fx := 0.0
var _heal_fx := 0.0
var _flash := 0.0
var _walk_anim := 0.0
var _moving := false
var _prev_pos := Vector2.ZERO
var _born_ms := 0
var _bot_shopping := false
var _bot_market_done := false
var _bot_wait := 0.0


func _ready() -> void:
	add_to_group("players")
	_born_ms = Time.get_ticks_msec()
	$NameLabel.text = player_name
	sync_pos = position
	_prev_pos = position
	if is_multiplayer_authority():
		add_to_group("local_player")
		$Camera2D.enabled = true
		$Camera2D.make_current()
		inventory_changed.connect(_on_inventory_changed)
		if not multiplayer.is_server():
			_req_inventory.rpc_id(1)


func xp_to_next() -> int:
	return 40 + (level - 1) * 30


## Spawn anında tüm peer'larda aynı veriyle çağrılır.
func apply_progress(data: Dictionary) -> void:
	look = Look.sanitize(data.get("look", {}))
	level = data.get("level", 1)
	xp = data.get("xp", 0)
	gold = data.get("gold", 0)
	potions = data.get("potions", 0)
	weapon = data.get("weapon", {})
	armor = data.get("armor", {})
	quest_kind = data.get("quest_kind", "")
	quest_need = data.get("quest_need", 0)
	quest_have = data.get("quest_have", 0)
	_recalc_stats()
	hp = max_hp


## Seviyeden ve kuşanılan eşyadan türeyen değerler.
func _recalc_stats() -> void:
	max_hp = BASE_HP + (level - 1) * 20 + int(armor.get("power", 0))
	damage = BASE_DAMAGE + (level - 1) * 4 + int(weapon.get("power", 0))
	weapon_rarity = int(weapon.get("rarity", -1)) if not weapon.is_empty() else -1
	armor_rarity = int(armor.get("rarity", -1)) if not armor.is_empty() else -1
	if hp > max_hp:
		hp = max_hp


func on_water() -> bool:
	return not Zones.is_land(position)


func zone() -> String:
	return Zones.zone_at(position)


## Kıyıdan suya geçince tekneye biner, karaya basınca iner (yalnızca bildirim; hareket otomatik).
func _check_boat() -> void:
	var water := on_water()
	if water == _was_on_water:
		return
	_was_on_water = water
	if Time.get_ticks_msec() - _born_ms < 1500:
		return  # ışınlanma/doğma anında bildirim gösterme
	_say("Tekneye bindin" if water else "Karaya çıktın", Color(0.6, 0.85, 1.0))
	FX.poof(global_position, Color(0.55, 0.8, 1.0))
	SFX.play("dash", global_position, -4.0)


## Sahibinde: portalın üstüne basınca sunucudan geçiş ister.
func _check_portals(delta: float) -> void:
	_portal_cd -= delta
	if _portal_cd > 0.0 or dead:
		return
	for i in Zones.PORTALS.size():
		var portal: Dictionary = Zones.PORTALS[i]
		if position.distance_to(portal.pos) < 40.0:
			_portal_cd = 1.5
			var need := Zones.level_of(portal.to)
			if level < need and not Network.test_mode and not Network.bot_mode:
				_say("%s için seviye %d gerekir" % [Zones.ZONES[portal.to].name, need], Color(1, 0.6, 0.4))
			else:
				_req_portal.rpc_id(1, i)
			return


@rpc("authority", "call_local", "reliable")
func _req_portal(index: int) -> void:
	if not multiplayer.is_server() or dead or index < 0 or index >= Zones.PORTALS.size():
		return
	var portal: Dictionary = Zones.PORTALS[index]
	if sync_pos.distance_to(portal.pos) > 90.0:
		return
	if level < Zones.level_of(portal.to) and not Network.test_mode:
		Network.send_private(peer_id, "%s için seviye %d gerekir." % [Zones.ZONES[portal.to].name, Zones.level_of(portal.to)])
		return
	var dest := Zones.arrival(portal)
	print("[Bölge] %s → %s" % [player_name, Zones.ZONES[portal.to].name])
	_server_teleport(dest)
	Network.send_private(peer_id, "%s bölgesine geçtin." % Zones.ZONES[portal.to].name)


func _server_teleport(pos: Vector2) -> void:
	sync_pos = pos
	position = pos
	if peer_id == multiplayer.get_unique_id():
		_teleport(pos)
	else:
		_teleport.rpc_id(peer_id, pos)


func near_merchant() -> bool:
	return position.distance_to(MERCHANT_POS) < MERCHANT_RANGE


func near_oracle() -> bool:
	return position.distance_to(ORACLE_POS) < MERCHANT_RANGE


func quest_done() -> bool:
	return quest_kind != "" and quest_have >= quest_need


func skill_unlocked(id: String) -> bool:
	return level >= int(SKILLS[id].level)


## 0 = hazır, 1 = yeni kullanıldı (yalnızca sahibinde anlamlı).
func skill_cooldown_ratio(id: String) -> float:
	var left: float = skill_ready_at.get(id, 0.0) - Time.get_ticks_msec() * 0.001
	return clampf(left / float(SKILLS[id].cooldown), 0.0, 1.0)


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
	_spin_time = maxf(_spin_time - delta, 0.0)
	_dash_fx = maxf(_dash_fx - delta, 0.0)
	_heal_fx = maxf(_heal_fx - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	if not Network.is_dedicated and FX.on_screen(position):
		queue_redraw()


func _process_local(delta: float) -> void:
	var dir := Vector2.ZERO
	if Network.bot_mode:
		dir = _bot_think(delta)
	elif not dead and not _typing():
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var to_mouse := get_global_mouse_position() - (global_position + Vector2(0, -20))
		if to_mouse.length() > 4.0:
			facing = to_mouse.normalized()
		# Sağ fare tuşu basılıyken imlece doğru yürü (klavyesiz oynamak için de).
		if dir == Vector2.ZERO and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and to_mouse.length() > 12.0:
			dir = to_mouse.normalized()
	if _dash_left > 0.0 and not dead:
		_dash_left -= delta
		velocity = _dash_dir * DASH_SPEED
	else:
		velocity = Vector2.ZERO if dead else dir * SPEED * (BOAT_SPEED if on_water() else 1.0)
	move_and_slide()
	sync_pos = position
	_check_portals(delta)
	_check_boat()

	_attack_cd -= delta
	_attack_held = _attack_held and (Input.is_action_pressed("attack") or Network.bot_mode)
	if _attack_held and _attack_cd <= 0.0 and not dead and not _typing():
		_attack_cd = ATTACK_COOLDOWN
		attack.rpc(facing)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or Network.bot_mode or _typing():
		return
	if event.is_action_pressed("attack"):
		_attack_held = true
	elif event.is_action_released("attack"):
		_attack_held = false
	elif event.is_action_pressed("use_potion"):
		try_use_potion()
	elif event.is_action_pressed("interact"):
		try_quest()
	elif event.is_action_pressed("skill_spin"):
		try_skill("spin")
	elif event.is_action_pressed("skill_dash"):
		try_skill("dash")
	elif event.is_action_pressed("skill_heal"):
		try_skill("heal")


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _say(text: String, col := Color(1, 0.8, 0.5)) -> void:
	FX.floating_text(global_position + Vector2(0, -12), text, col, 13)


# --- Sahibin istekleri ---

func try_use_potion() -> void:
	if potions > 0 and not dead and hp < max_hp:
		_use_potion.rpc_id(1)


func try_buy_potion() -> void:
	if dead:
		return
	if not near_merchant():
		_say("Tüccar kampta")
	elif potions >= POTION_MAX:
		_say("İksir çantan dolu")
	elif gold < POTION_COST:
		_say("Altın yetmiyor", Color(1, 0.5, 0.4))
	else:
		_buy_potion.rpc_id(1)


func try_quest() -> void:
	if dead:
		return
	if not near_oracle():
		_say("Kâhin kampın batısında")
	elif quest_kind != "" and not quest_done():
		_say("Görev sürüyor: " + Quests.describe(quest_kind, quest_have, quest_need))
	else:
		_req_quest.rpc_id(1)


func try_equip(item_id: int) -> void:
	_req_equip.rpc_id(1, item_id)


func try_sell(item_id: int) -> void:
	if not near_merchant():
		_say("Satmak için tüccara git")
		return
	_req_sell.rpc_id(1, item_id)


func try_abandon_quest() -> void:
	if quest_kind != "":
		_req_abandon_quest.rpc_id(1)


func try_skill(id: String) -> void:
	if dead or not SKILLS.has(id):
		return
	if not skill_unlocked(id):
		_say("%s seviye %d'te açılır" % [SKILLS[id].name, SKILLS[id].level])
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < skill_ready_at.get(id, 0.0):
		return
	skill_ready_at[id] = now + float(SKILLS[id].cooldown)
	var dir := facing
	if id == "dash":
		var mv := velocity.normalized() if Network.bot_mode else Input.get_vector("move_left", "move_right", "move_up", "move_down")
		dir = mv.normalized() if mv.length() > 0.1 else facing
		_dash_dir = dir
		_dash_left = DASH_TIME
	_skill.rpc(id, dir)


# --- Test botu: görev alır, tüccara uğrar, avlanır, eşya kuşanır, yetenek kullanır ---

func _bot_think(delta: float) -> Vector2:
	_attack_held = false
	_bot_wait -= delta
	if dead:
		return Vector2.ZERO
	if hp < max_hp * 0.5:
		try_use_potion()
	if hp < max_hp * 0.45 and skill_unlocked("heal"):
		try_skill("heal")
	var here := zone()
	if Network.bot_zone != "" and here != Network.bot_zone and Zones.ZONES.has(Network.bot_zone):
		# Önce hedef bölgenin portalına yürü (portal kontrolü geçişi kendisi ister)
		for portal in Zones.PORTALS:
			if portal.to == Network.bot_zone:
				facing = (portal.pos - position).normalized()
				return facing
	if here == "meadow":
		if (potions == 0 and gold >= POTION_COST) or (not _bot_market_done and gold >= 150):
			_bot_shopping = true
		elif (potions > 0 or gold < POTION_COST) and _bot_market_done:
			_bot_shopping = false
		if _bot_shopping:
			return _bot_walk_to(MERCHANT_POS, _bot_shop)
		if Network.bot_zone == "" and (quest_kind == "" or quest_done()):
			return _bot_walk_to(ORACLE_POS, try_quest)
	var best = null
	var best_d := INF
	var close := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = position.distance_to(e.position)
		if d < SPIN_RANGE + e.radius:
			close += 1
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return Vector2.ZERO
	facing = (best.position - position).normalized()
	if close >= 1 and skill_unlocked("spin"):
		try_skill("spin")
	if best_d > 260.0 and skill_unlocked("dash"):
		try_skill("dash")
	_attack_held = best_d < ATTACK_RANGE
	return facing if best_d > ATTACK_RANGE * 0.6 else Vector2.ZERO


## Bot alışverişi: iksir alır, marketten parasının yettiği ilk eşyayı alır.
func _bot_shop() -> void:
	if potions == 0:
		try_buy_potion()
	if client_market.is_empty():
		_req_market.rpc_id(1)
		return
	_bot_market_done = true
	for i in client_market.offers.size():
		var offer: Dictionary = client_market.offers[i]
		if not i in client_market.bought and int(offer.price) <= gold - POTION_COST and client_inv.size() < Items.INV_MAX:
			try_market_buy(i)
			return


func _bot_walk_to(target: Vector2, action: Callable) -> Vector2:
	if position.distance_to(target) < MERCHANT_RANGE - 30.0:
		if _bot_wait <= 0.0:
			_bot_wait = 1.0
			action.call()
		return Vector2.ZERO
	facing = (target + Vector2(0, 45) - position).normalized()
	return facing


func _on_inventory_changed() -> void:
	if not Network.bot_mode:
		return
	# Bot daha güçlü eşyayı hemen kuşanır (her seferinde bir tane; sonuç yeni bir eşitlemeyle gelir).
	for item in client_inv:
		var current: Dictionary = client_weapon if item.slot == "weapon" else client_armor
		if int(item.power) > int(current.get("power", 0)):
			try_equip(int(item.id))
			return


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


# --- Yetenekler: görüntü herkeste, etki sunucuda ---

@rpc("authority", "call_local", "reliable")
func _skill(id: String, dir: Vector2) -> void:
	match id:
		"spin":
			_spin_time = SPIN_TIME
			SFX.play("spin", global_position)
		"dash":
			_dash_fx = 0.3
			_dash_dir = dir
			SFX.play("dash", global_position)
		"heal":
			_heal_fx = 0.7
			SFX.play("heal", global_position)
	if multiplayer.is_server():
		_server_skill(id, dir)


func _server_skill(id: String, _dir: Vector2) -> void:
	if dead or not SKILLS.has(id) or not skill_unlocked(id):
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < _server_skill_ready.get(id, 0.0) - 0.3:
		return  # bekleme süresi dolmadan gelen istek (gecikme payı 0,3 sn)
	_server_skill_ready[id] = now + float(SKILLS[id].cooldown)
	match id:
		"spin":
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.position.distance_to(sync_pos) < SPIN_RANGE + enemy.radius:
					enemy.server_take_damage(int(damage * SPIN_DAMAGE) + randi_range(0, 4), self)
		"dash":
			_server_invuln_until = now + 0.35
		"heal":
			for p in get_tree().get_nodes_in_group("players"):
				if not p.dead and p.sync_pos.distance_to(sync_pos) < HEAL_RANGE:
					p.server_heal(int(p.max_hp * HEAL_RATIO))
	print("[Yetenek] %s: %s" % [player_name, SKILLS[id].name])


# --- İksir ---

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
	if gold < POTION_COST or potions >= POTION_MAX or not _server_near(MERCHANT_POS):
		return
	gold -= POTION_COST
	potions += 1
	print("[Tüccar] %s iksir aldı (altın %d, iksir %d)." % [player_name, gold, potions])


func _server_near(pos: Vector2) -> bool:
	return sync_pos.distance_to(pos) < MERCHANT_RANGE + 40.0


# --- Çanta ve eşyalar (sunucu) ---

## Kayıttan gelen çantayı kurar; kimlikler yeniden verilir.
func server_set_inventory(items: Array, w: Dictionary, a: Dictionary) -> void:
	inv.clear()
	_next_item_id = 1
	for it in items:
		var clean := Items.sanitize(it)
		if not clean.is_empty() and inv.size() < Items.INV_MAX:
			clean.id = _take_id()
			inv.append(clean)
	weapon = Items.sanitize(w)
	armor = Items.sanitize(a)
	if not weapon.is_empty() and weapon.slot != "weapon":
		weapon = {}
	if not armor.is_empty() and armor.slot != "armor":
		armor = {}
	if not weapon.is_empty():
		weapon.id = _take_id()
	if not armor.is_empty():
		armor.id = _take_id()
	var full := hp >= max_hp
	_recalc_stats()
	if full:
		hp = max_hp


func _take_id() -> int:
	_next_item_id += 1
	return _next_item_id - 1


func _inv_index(item_id: int) -> int:
	for i in inv.size():
		if int(inv[i].id) == item_id:
			return i
	return -1


func server_give_item(item: Dictionary, reason := "") -> void:
	item = item.duplicate()
	item.id = _take_id()
	if inv.size() >= Items.INV_MAX:
		var price := Items.sell_price(item)
		gold += price
		Network.send_private(peer_id, "Çanta dolu: %s %d altına satıldı." % [Items.display_name(item), price])
	else:
		inv.append(item)
	print("[Ganimet] %s: %s %s%s" % [player_name, Items.RARITY_NAMES[item.rarity], Items.display_name(item),
		(" (" + reason + ")") if reason != "" else ""])
	if item.rarity == 2:
		Network.broadcast_system("%s efsanevi %s buldu!" % [player_name, item.name])
	_send_loot_fx(item.name, item.rarity)
	_send_inventory()


func server_roll_loot(enemy_type: String) -> void:
	if not Items.LOOT.has(enemy_type):
		return
	var row: Array = Items.LOOT[enemy_type]
	var chance: float = row[0] * (6.0 if Network.test_mode else 1.0)
	if randf() >= chance:
		return
	var rarity := Items.roll_rarity(enemy_type in Items.BOSSES)
	server_give_item(Items.random_item(rarity, randi_range(row[1], row[2])))


@rpc("authority", "call_local", "reliable")
func _req_inventory() -> void:
	if multiplayer.is_server():
		_send_inventory()


@rpc("authority", "call_local", "reliable")
func _req_equip(item_id: int) -> void:
	if not multiplayer.is_server():
		return
	var idx := _inv_index(item_id)
	if idx < 0:
		return
	var item: Dictionary = inv[idx]
	inv.remove_at(idx)
	if item.slot == "weapon":
		if not weapon.is_empty():
			inv.append(weapon)
		weapon = item
	else:
		if not armor.is_empty():
			inv.append(armor)
		armor = item
	var full := hp >= max_hp
	_recalc_stats()
	if full:
		hp = max_hp
	print("[Kuşan] %s: %s" % [player_name, Items.display_name(item)])
	_send_inventory()


@rpc("authority", "call_local", "reliable")
func _req_sell(item_id: int) -> void:
	if not multiplayer.is_server() or not _server_near(MERCHANT_POS):
		return
	var idx := _inv_index(item_id)
	if idx < 0:
		return
	var item: Dictionary = inv[idx]
	inv.remove_at(idx)
	var price := Items.sell_price(item)
	gold += price
	print("[Tüccar] %s sattı: %s (%d altın)" % [player_name, Items.display_name(item), price])
	_send_inventory()


func _send_inventory() -> void:
	if not multiplayer.is_server():
		return
	if peer_id == multiplayer.get_unique_id():
		_inv_sync(inv, weapon, armor)
	elif Network.player_names.has(peer_id):
		_inv_sync.rpc_id(peer_id, inv, weapon, armor)


@rpc("any_peer", "reliable")
func _inv_sync(items: Array, w: Dictionary, a: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return  # yalnızca sunucu gönderebilir
	client_inv = items.duplicate(true)
	client_weapon = w.duplicate()
	client_armor = a.duplicate()
	inventory_changed.emit()


func _send_loot_fx(item_name: String, rarity: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_loot_fx(item_name, rarity)
	elif Network.player_names.has(peer_id):
		_loot_fx.rpc_id(peer_id, item_name, rarity)


@rpc("any_peer", "reliable")
func _loot_fx(item_name: String, rarity: int) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	rarity = clampi(rarity, 0, 2)
	FX.floating_text(global_position + Vector2(0, -30), item_name + "!", Items.RARITY_COLORS[rarity], 16 + rarity * 2)
	if rarity >= 1:
		FX.poof(global_position + Vector2(0, -20), Items.RARITY_COLORS[rarity])
	SFX.play("loot", null, -2.0 + rarity * 2.0)


# --- Market ---

func market_period() -> int:
	return int(Time.get_unix_time_from_system()) / MARKET_PERIOD


## Vitrin her oyuncuya ve döneme göre seed'lidir: aynı dönemde hep aynı eşyalar.
func server_market_offers(period: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(save_key if save_key != "" else str(peer_id)) + ":" + str(period))
	var offers := []
	for i in MARKET_SIZE:
		var rarity := 0 if i < 2 else 1
		if i == MARKET_SIZE - 1 and rng.randf() < 0.35:
			rarity = 2
		var ilvl := clampi(level + rng.randi_range(-1, 1), 1, 30) if rarity < 2 else clampi(level, 1, 30)
		var item := Items.make("weapon" if rng.randf() < 0.5 else "armor", rarity, ilvl)
		item.name = Items.NAMES[item.slot][rarity][rng.randi() % 3]
		item["price"] = Items.sell_price(item) * MARKET_MARKUP
		offers.append(item)
	return offers


func open_market() -> void:
	_req_market.rpc_id(1)


func try_market_buy(index: int) -> void:
	if client_market.is_empty():
		return
	if not near_merchant():
		_say("Tüccardan uzaklaştın")
		return
	_req_market_buy.rpc_id(1, int(client_market.period), index)


@rpc("authority", "call_local", "reliable")
func _req_market() -> void:
	if multiplayer.is_server():
		_send_market()


@rpc("authority", "call_local", "reliable")
func _req_market_buy(period: int, index: int) -> void:
	if not multiplayer.is_server() or dead or not _server_near(MERCHANT_POS):
		return
	if period != market_period() or index < 0 or index >= MARKET_SIZE:
		_send_market()  # vitrin yenilenmiş; güncelini gönder
		return
	var bought: Array = _market_bought.get(period, [])
	if index in bought:
		return
	var offer: Dictionary = server_market_offers(period)[index]
	if gold < int(offer.price) or inv.size() >= Items.INV_MAX:
		return
	gold -= int(offer.price)
	bought.append(index)
	_market_bought = {period: bought}
	var item := offer.duplicate()
	item.erase("price")
	item.id = _take_id()
	inv.append(item)
	print("[Market] %s aldı: %s (%d altın)" % [player_name, Items.display_name(item), int(offer.price)])
	_send_inventory()
	_send_market()


func _send_market() -> void:
	var period := market_period()
	var data := {
		"period": period, "offers": server_market_offers(period), "bought": _market_bought.get(period, []),
		"left": MARKET_PERIOD - int(Time.get_unix_time_from_system()) % MARKET_PERIOD,
	}
	if peer_id == multiplayer.get_unique_id():
		_market_sync(data)
	elif Network.player_names.has(peer_id):
		_market_sync.rpc_id(peer_id, data)


@rpc("any_peer", "reliable")
func _market_sync(data: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	client_market = data.duplicate(true)
	client_market["received"] = Time.get_ticks_msec()
	market_changed.emit()


# --- Görevler (sunucu) ---

func server_on_kill(enemy_type: String) -> void:
	if quest_kind != enemy_type or quest_have >= quest_need:
		return
	quest_have += 1
	print("[Görev] %s: %s" % [player_name, Quests.describe(quest_kind, quest_have, quest_need)])
	if quest_have >= quest_need:
		Network.send_private(peer_id, "Görev tamamlandı! Ödül için Kâhin'e dön (F).")


@rpc("authority", "call_local", "reliable")
func _req_quest() -> void:
	if not multiplayer.is_server() or dead or not _server_near(ORACLE_POS):
		return
	if quest_kind == "":
		var kind := Quests.pick_kind(level)
		quest_need = Quests.need_of(kind, Network.test_mode)
		quest_have = 0
		quest_kind = kind
		print("[Görev] %s aldı: %s" % [player_name, Quests.describe(kind, 0, quest_need)])
		Network.send_private(peer_id, "Kâhin: \"%s.\" Ödül: %d altın, %d XP ve bir eşya." %
			[Quests.describe(kind, 0, quest_need).split(" (")[0], Quests.TABLE[kind][1], Quests.TABLE[kind][2]])
		_send_quest_fx(false)
	elif quest_have >= quest_need:
		var row: Array = Quests.TABLE[quest_kind]
		var kind := quest_kind
		quest_kind = ""
		quest_have = 0
		quest_need = 0
		gold += row[1]
		server_add_xp(row[2])
		var rarity := randi_range(row[3], row[4])
		server_give_item(Items.random_item(rarity, clampi(level, 1, 15)), "görev ödülü")
		print("[Görev] %s tamamladı: %s" % [player_name, Quests.NAMES[kind]])
		Network.broadcast_system("%s, Kâhin'in görevini tamamladı." % player_name)
		_send_quest_fx(true)


@rpc("authority", "call_local", "reliable")
func _req_abandon_quest() -> void:
	if not multiplayer.is_server() or quest_kind == "":
		return
	print("[Görev] %s bıraktı: %s" % [player_name, quest_kind])
	quest_kind = ""
	quest_have = 0
	quest_need = 0


func _send_quest_fx(done: bool) -> void:
	if peer_id == multiplayer.get_unique_id():
		_quest_fx(done)
	elif Network.player_names.has(peer_id):
		_quest_fx.rpc_id(peer_id, done)


@rpc("any_peer", "reliable")
func _quest_fx(done: bool) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	_say("Görev tamamlandı!" if done else "Yeni görev!", Color(1.0, 0.9, 0.45))
	SFX.play("quest")


# --- Sunucu tarafı can / XP ---

func server_add_gold(amount: int) -> void:
	gold += amount


func server_heal(amount: int) -> void:
	if not dead:
		hp = mini(hp + amount, max_hp)


func server_take_damage(amount: int) -> void:
	if dead or Time.get_ticks_msec() * 0.001 < _server_invuln_until:
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
		_recalc_stats()
		hp = max_hp
		Network.broadcast_system("%s seviye %d oldu!" % [player_name, level])
		for id in SKILL_ORDER:
			if int(SKILLS[id].level) == level:
				Network.send_private(peer_id, "Yeni yetenek: %s (%s)" % [SKILLS[id].name, SKILLS[id].key])


func _server_regen(delta: float) -> void:
	if not dead and Zones.in_lava(sync_pos) and Time.get_ticks_msec() * 0.001 >= _server_invuln_until:
		_lava_acc += delta
		if _lava_acc >= 0.5:
			_lava_acc = 0.0
			server_take_damage(maxi(1, int(max_hp * LAVA_DAMAGE * 0.5)))
		return
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
	var zone_id := Zones.zone_at(sync_pos)
	var entry: Vector2 = Zones.ZONES[zone_id].entry
	var pos := entry + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 110.0)
	if zone_id == "ocean":
		pos = entry + Vector2(randf_range(-30, 30), randf_range(-60, 60))
	_server_teleport(pos)


@rpc("any_peer", "reliable")
func _teleport(pos: Vector2) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return  # sadece sunucu ışınlayabilir
	position = pos
	sync_pos = pos
	snap_camera()


## Işınlanınca kamera yumuşak takiple aradaki bölgelerin üstünden kaymasın.
func snap_camera() -> void:
	if is_multiplayer_authority():
		var cam: Camera2D = $Camera2D
		cam.force_update_scroll.call_deferred()
		cam.reset_smoothing.call_deferred()


# --- Setter'lar: senkron gelen değişikliklerde efekt oynat ---

func _fx_ready() -> bool:
	return is_inside_tree() and Time.get_ticks_msec() - _born_ms > 500


func _set_hp(value: int) -> void:
	if _fx_ready() and value < hp:
		_flash = 0.15
		FX.floating_text(global_position, str(hp - value), Color(1.0, 0.35, 0.3))
		SFX.play("hurt", global_position)
	elif _fx_ready() and hp > 0 and value - hp >= maxi(8, int(max_hp * 0.1)):
		FX.floating_text(global_position, "+%d" % (value - hp), Color(0.45, 1.0, 0.55), 15)
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


func _set_quest_have(value: int) -> void:
	if _fx_ready() and value > quest_have and is_multiplayer_authority() and quest_kind != "":
		FX.floating_text(global_position + Vector2(0, -44), "Görev %d/%d" % [value, quest_need], Color(1.0, 0.9, 0.45), 13)
	quest_have = value


# --- Çizim ---

func _draw() -> void:
	modulate.a = 0.45 if dead else 1.0
	var bob := sin(_walk_anim) * 1.6 if _moving else 0.0
	var torso := Vector2(0, -20.0 + bob)

	# Atılma izi
	if _dash_fx > 0.0:
		var outfit: Color = Look.OUTFITS[Look.sanitize(look).outfit]
		for k in 3:
			var off := -_dash_dir * (14.0 + k * 16.0) * (_dash_fx / 0.3)
			draw_circle(torso + off, 10.0 - k * 2.0, Color(outfit.r, outfit.g, outfit.b, 0.3 - k * 0.08))
	# Şifa halkası
	if _heal_fx > 0.0:
		var k := 1.0 - _heal_fx / 0.7
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, HEAL_RANGE * k, 0.0, TAU, 48, Color(0.45, 1.0, 0.55, 0.7 * (1.0 - k)), 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 6:
			var a := TAU * i / 6.0 + k * 2.0
			draw_circle(torso + Vector2.from_angle(a) * (16.0 + k * 10.0) + Vector2(0, -k * 20.0), 2.5, Color(0.6, 1.0, 0.65, 1.0 - k))

	# Suda: tekne
	if on_water():
		var hull := Color(0.5, 0.32, 0.17)
		var rock := sin(Time.get_ticks_msec() * 0.004 + peer_id) * 2.0
		draw_set_transform(Vector2(0, 2 + rock), 0.0, Vector2(1.0, 1.0))
		draw_arc(Vector2(0, 10), 34.0, 0.15, PI - 0.15, 14, Color(1, 1, 1, 0.35), 2.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-30, -6), Vector2(30, -6), Vector2(21, 10), Vector2(-21, 10)]), hull)
		draw_line(Vector2(-30, -6), Vector2(30, -6), hull.lightened(0.25), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var sword_angle := facing.angle() + 1.0
	if _spin_time > 0.0:
		var p := 1.0 - _spin_time / SPIN_TIME
		sword_angle = facing.angle() + p * TAU * 1.5
		draw_arc(torso, SPIN_RANGE * 0.75, sword_angle - 2.4, sword_angle, 24, Color(1, 1, 1, 0.5 * (1.0 - p) + 0.15), 7.0)
	elif _swing_time > 0.0:
		var p := 1.0 - _swing_time / SWING_DURATION
		sword_angle = _swing_dir.angle() - ATTACK_ARC * 0.5 + ATTACK_ARC * p
		var start := _swing_dir.angle() - ATTACK_ARC * 0.5
		draw_arc(torso, ATTACK_RANGE * 0.8, start, sword_angle, 20, Color(1, 1, 1, 0.55 * (1.0 - p) + 0.15), 6.0)

	Look.draw(self, look, {
		"facing": facing, "walk": _walk_anim, "moving": _moving,
		"flash": 0.7 if _flash > 0.0 else 0.0, "dead": dead,
		"armor": armor_rarity, "weapon": weapon_rarity, "sword_angle": sword_angle,
	})

	# Can barı
	var ratio := float(hp) / float(max(max_hp, 1))
	draw_rect(Rect2(-19, -62, 38, 6), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-18, -61, 36.0 * ratio, 4), Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.9, 0.35), ratio))
