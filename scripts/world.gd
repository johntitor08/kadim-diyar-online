extends Node2D
## Dünya: zemin çizimi, engeller, oyuncu/canavar spawn yönetimi.

const MAP_SIZE := Vector2(3200, 3200)
const TILE := 64
const SPAWN_POINT := Vector2(1600, 1600)
const MAP_SEED := 20261006
const MAX_ENEMIES := 24
const SAFE_RADIUS := 420.0
const AUTOSAVE_INTERVAL := 20.0
## Boss'un belirebileceği köşeler (sohbet duyurusundaki adıyla).
const BOSS_SPOTS := {
	"kuzeybatı": Vector2(520, 520), "kuzeydoğu": Vector2(2680, 520),
	"güneybatı": Vector2(520, 2680), "güneydoğu": Vector2(2680, 2680),
}

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const Obstacle := preload("res://scripts/obstacle.gd")
const SaveStore := preload("res://scripts/save.gd")
const Player := preload("res://scripts/player.gd")
const Items := preload("res://scripts/items.gd")
const Look := preload("res://scripts/look.gd")
const Quests := preload("res://scripts/quests.gd")
const Zones := preload("res://scripts/zones.gd")
const ZoneGround := preload("res://scripts/zone_ground.gd")
const Portal := preload("res://scripts/portal.gd")
const LavaPool := preload("res://scripts/lava_pool.gd")
## Bölge boss'ları: [tür, doğduğu yer, duyuru]
const ZONE_BOSSES := {
	"volcano": ["dragon", Vector2(12600, 700), "Ejderha Kızıl Volkan'ın tepesinde uyandı!"],
	"ocean": ["kraken", Vector2(4500, 7900), "Kraken Kayıp Ada açıklarında yükseldi!"],
}
const ZONE_EMPTY_DESPAWN := 40.0

const GRASS := Color(0.27, 0.5, 0.24)
const GRASS_DARK := Color(0.245, 0.47, 0.22)
const DIRT := Color(0.55, 0.45, 0.3)

@onready var players: Node2D = $Entities/Players
@onready var enemies: Node2D = $Entities/Enemies
@onready var props: Node2D = $Entities/Props
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var enemy_spawner: MultiplayerSpawner = $EnemySpawner
@onready var enemy_timer: Timer = $EnemyTimer
@onready var menu_camera: Camera2D = $MenuCamera

var _enemy_counter := 0
var _obstacle_spots: Array[Vector2] = []
var _save := SaveStore.new()
var _hosting := false
var _autosave_wait := 0.0
var _boss_wait := 0.0
var _zone_empty := {}
var _zone_boss_wait := {}
## Mini harita için: bölge -> [[konum, tür]]
var obstacles_by_zone := {}


func _ready() -> void:
	add_to_group("world")
	player_spawner.spawn_function = _spawn_player
	enemy_spawner.spawn_function = _spawn_enemy
	_build_map()
	Network.game_started.connect(_on_game_started)
	Network.game_ended.connect(_on_game_ended)
	Network.player_registered.connect(_on_player_registered)
	Network.player_left.connect(_on_player_left)
	enemy_timer.timeout.connect(_on_enemy_timer)


# --- Harita ---

func _hash(x: int, y: int) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


func _build_map() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = MAP_SEED
	var t := 64.0
	_add_wall(Rect2(-t, -t, MAP_SIZE.x + t * 2, t))
	_add_wall(Rect2(-t, MAP_SIZE.y, MAP_SIZE.x + t * 2, t))
	_add_wall(Rect2(-t, 0, t, MAP_SIZE.y))
	_add_wall(Rect2(MAP_SIZE.x, 0, t, MAP_SIZE.y))

	_add_obstacle(SPAWN_POINT, "campfire", 26.0, 0)
	_add_obstacle(Player.MERCHANT_POS, "merchant", 26.0, 0)
	_add_obstacle(Player.ORACLE_POS, "oracle", 24.0, 0)
	_build_zones.call_deferred()  # zemin düğümleri çayırın üstüne değil altına eklensin diye sonra
	for i in 320:
		var pos := Vector2(rng.randf_range(60, MAP_SIZE.x - 60), rng.randf_range(80, MAP_SIZE.y - 40))
		var kind := "tree" if rng.randf() < 0.72 else "rock"
		var s := rng.randf_range(20, 32) if kind == "tree" else rng.randf_range(14, 26)
		var v := rng.randi() % 100
		if pos.distance_to(SPAWN_POINT) < 260.0:
			continue
		if pos.distance_to(Player.MERCHANT_POS) < 110.0 or pos.distance_to(Player.ORACLE_POS) < 110.0:
			continue  # tüccarın ve Kâhin'in çevresi açık kalsın
		if absf(pos.x - SPAWN_POINT.x) < 70.0 or absf(pos.y - SPAWN_POINT.y) < 70.0:
			continue  # yollar açık kalsın
		var crowded := false
		for o in _obstacle_spots:
			if o.distance_to(pos) < 55.0:
				crowded = true
				break
		if not crowded:
			_add_obstacle(pos, kind, s, v)


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	body.add_child(cs)
	add_child(body)


func _add_obstacle(pos: Vector2, kind: String, s: float, v: int) -> void:
	var o := Obstacle.new()
	o.setup(kind, s, v)
	o.position = pos
	props.add_child(o)
	_obstacle_spots.append(pos)
	var zone := Zones.zone_at(pos)
	if not obstacles_by_zone.has(zone):
		obstacles_by_zone[zone] = []
	obstacles_by_zone[zone].append([pos, kind])


## Çayır dışındaki bölgeler: zemin, duvarlar, engeller, lav gölleri ve portallar.
func _build_zones() -> void:
	for id in Zones.ORDER:
		if id == "meadow":
			continue
		var r: Rect2 = Zones.ZONES[id].rect
		var ground := ZoneGround.new()
		ground.zone = id
		ground.z_index = -2
		add_child(ground)
		var t := 64.0
		_add_wall(Rect2(r.position.x - t, r.position.y - t, r.size.x + t * 2, t))
		_add_wall(Rect2(r.position.x - t, r.end.y, r.size.x + t * 2, t))
		_add_wall(Rect2(r.position.x - t, r.position.y, t, r.size.y))
		_add_wall(Rect2(r.end.x, r.position.y, t, r.size.y))
		var lay := Zones.layout(id)
		for o in lay.obstacles:
			_add_obstacle(o[0], o[1], o[2], o[3])
		for pool in lay.pools:
			var lava := LavaPool.new()
			lava.radius = pool[1]
			lava.position = pool[0]
			add_child(lava)
	for i in Zones.PORTALS.size():
		var p := Portal.new()
		p.index = i
		p.to_zone = Zones.PORTALS[i].to
		p.position = Zones.PORTALS[i].pos
		props.add_child(p)


func _draw() -> void:
	# Harita dışı karanlık orman
	draw_rect(Rect2(-600, -600, MAP_SIZE.x + 1200, MAP_SIZE.y + 1200), Color(0.08, 0.16, 0.09))
	var cols := int(MAP_SIZE.x / TILE)
	var rows := int(MAP_SIZE.y / TILE)
	for x in cols:
		for y in rows:
			var h := _hash(x, y)
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			draw_rect(r, GRASS.lerp(GRASS_DARK, h))
			if h > 0.82:
				var p := r.position + Vector2(_hash(y, x) * 48 + 8, h * 40 + 12)
				for k in 3:
					draw_line(p + Vector2(k * 4 - 4, 0), p + Vector2(k * 5 - 6, -7), GRASS.lightened(0.25), 1.5)
			elif h < 0.04:
				var p := r.get_center()
				draw_circle(p, 3.0, Color(0.95, 0.85, 0.3))
				draw_circle(p + Vector2(10, 6), 3.0, Color(0.9, 0.5, 0.7))
	# Yollar
	draw_line(Vector2(0, SPAWN_POINT.y), Vector2(MAP_SIZE.x, SPAWN_POINT.y), DIRT, 70.0)
	draw_line(Vector2(SPAWN_POINT.x, 0), Vector2(SPAWN_POINT.x, MAP_SIZE.y), DIRT, 70.0)
	# Kamp alanı (güvenli bölge)
	draw_circle(SPAWN_POINT, 240.0, DIRT.lightened(0.08))
	draw_arc(SPAWN_POINT, 240.0, 0.0, TAU, 64, DIRT.darkened(0.25), 4.0)
	# Harita sınırı
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.05, 0.1, 0.05), false, 8.0)


# --- Oyun akışı ---

func _on_game_started() -> void:
	if multiplayer.is_server():
		_hosting = true
		_autosave_wait = 0.0
		_boss_wait = 0.0
		_save.load_file(Network.save_path)
		for i in 14:
			_spawn_random_enemy()
		enemy_timer.start()


func _on_game_ended(_reason: String) -> void:
	_save_all()
	_hosting = false
	enemy_timer.stop()
	for c in players.get_children():
		c.queue_free()
	for c in enemies.get_children():
		c.queue_free()
	menu_camera.make_current()


func _on_player_registered(id: int, player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var pos := SPAWN_POINT + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 120.0)
	# Aynı kimlik zaten oyundaysa ikinci bağlantı misafir sayılır (kaydı ezmesin).
	var key: String = Network.player_keys.get(id, "")
	for other in players.get_children():
		if not key.is_empty() and other.save_key == key:
			key = ""
	var rec: Dictionary = _save.get_player(key) if not key.is_empty() else {}
	var quest: Dictionary = rec.get("quest") if rec.get("quest") is Dictionary else {}
	var quest_kind := str(quest.get("kind", ""))
	if not Quests.TABLE.has(quest_kind):
		quest_kind = ""
	var quest_need := clampi(_num(quest.get("need"), 0), 1, 99) if quest_kind != "" else 0
	var p = player_spawner.spawn({
		"id": id, "name": player_name, "pos": pos,
		"look": Network.player_looks.get(id, Look.random_look()),
		"level": clampi(_num(rec.get("level"), 1), 1, 999),
		"xp": maxi(_num(rec.get("xp"), 0), 0),
		"gold": clampi(_num(rec.get("gold"), 500 if Network.test_mode else Player.START_GOLD), 0, 9999999),
		"potions": clampi(_num(rec.get("potions"), 0), 0, Player.POTION_MAX),
		"weapon": Items.sanitize(rec.get("weapon")),
		"armor": Items.sanitize(rec.get("armor")),
		"quest_kind": quest_kind,
		"quest_need": quest_need,
		"quest_have": clampi(_num(quest.get("have"), 0), 0, quest_need),
	})
	p.save_key = key
	var items: Array = rec.get("inv") if rec.get("inv") is Array else []
	p.server_set_inventory(items, rec.get("weapon", {}), rec.get("armor", {}))
	if id == multiplayer.get_unique_id():
		p._send_inventory()  # uzak oyuncular kendi karakterleri oluşunca çantayı ister
	if not rec.is_empty():
		print("[Kayıt] %s yüklendi: seviye %d, altın %d, iksir %d, eşya %d, silah %s, zırh %s" % [player_name,
			p.level, p.gold, p.potions, p.inv.size(), Items.display_name(p.weapon), Items.display_name(p.armor)])


## JSON'dan gelen sayılar float olur; sayı değilse varsayılan döner.
func _num(v, default: int) -> int:
	return int(v) if (v is int or v is float) else default


func _on_player_left(id: int) -> void:
	var p := players.get_node_or_null(str(id))
	if p:
		_store_player(p)
		_save.flush()
		p.queue_free()


func _on_enemy_timer() -> void:
	if not multiplayer.is_server():
		return
	var counts := {}
	for e in enemies.get_children():
		counts[e.zone] = counts.get(e.zone, 0) + 1
	if counts.get("meadow", 0) < MAX_ENEMIES:
		_spawn_random_enemy()
	for id in Zones.ORDER:
		if id == "meadow":
			continue
		if _players_in(id) > 0:
			if _zone_empty.get(id, 0.0) > 0.0 or not counts.has(id):
				if not counts.has(id):
					print("[Bölge] %s canlandı (oyuncu geldi)." % Zones.ZONES[id].name)
			_zone_empty[id] = 0.0
			var have: int = counts.get(id, 0)
			# Bölge yeni canlandıysa birkaç canavarı birden doğur
			for k in (6 if have == 0 else 1):
				if have + k < int(Zones.ZONES[id].max):
					_spawn_zone_enemy(id)
			if ZONE_BOSSES.has(id):
				_zone_boss_tick(id)
		else:
			_zone_empty[id] = _zone_empty.get(id, 0.0) + enemy_timer.wait_time
			_zone_boss_wait[id] = 0.0
			if _zone_empty[id] >= ZONE_EMPTY_DESPAWN and counts.has(id):
				for e in enemies.get_children():
					if e.zone == id:
						e.queue_free()
				print("[Bölge] %s boşaldı, canavarlar kaldırıldı." % Zones.ZONES[id].name)
	_autosave_wait += enemy_timer.wait_time
	if _autosave_wait >= AUTOSAVE_INTERVAL:
		_autosave_wait = 0.0
		_save_all()
	# Boss: ölümünden (ya da açılıştan) boss_interval saniye sonra bir köşede uyanır.
	if not get_tree().get_nodes_in_group("boss").is_empty():
		_boss_wait = 0.0
	else:
		_boss_wait += enemy_timer.wait_time
		if _boss_wait >= Network.boss_interval:
			_boss_wait = 0.0
			_spawn_boss()


func _players_in(zone: String) -> int:
	var n := 0
	for p in players.get_children():
		if Zones.zone_at(p.sync_pos) == zone:
			n += 1
	return n


func _zone_boss_tick(zone: String) -> void:
	var row: Array = ZONE_BOSSES[zone]
	for e in enemies.get_children():
		if e.enemy_type == row[0]:
			_zone_boss_wait[zone] = 0.0
			return
	_zone_boss_wait[zone] = _zone_boss_wait.get(zone, 0.0) + enemy_timer.wait_time
	if _zone_boss_wait[zone] >= Network.zone_boss_interval:
		_zone_boss_wait[zone] = 0.0
		_enemy_counter += 1
		enemy_spawner.spawn({"name": "E%d" % _enemy_counter, "type": row[0], "pos": row[1]})
		print("[Boss] %s" % row[2])
		Network.broadcast_system(row[2])


func _spawn_zone_enemy(zone: String) -> void:
	var z: Dictionary = Zones.ZONES[zone]
	var r: Rect2 = z.rect
	var pos := Vector2.ZERO
	var ok := false
	for attempt in 40:
		pos = Vector2(randf_range(r.position.x + 100, r.end.x - 100), randf_range(r.position.y + 100, r.end.y - 100))
		if pos.distance_to(z.entry) < Zones.SAFE_RADIUS:
			continue
		if zone == "ocean":
			# Kara canavarları adalarda (liman adası hariç) doğar
			if not Zones.is_land(pos) or Zones.island_at(pos) == Zones.ISLANDS[0][0]:
				continue
		elif Zones.in_lava(pos):
			continue
		var blocked := false
		for o in obstacles_by_zone.get(zone, []):
			if o[0].distance_to(pos) < 50.0:
				blocked = true
				break
		if not blocked:
			ok = true
			break
	if not ok:
		return
	var roll := randf()
	var type: String = z.types[0][0]
	var acc := 0.0
	for row in z.types:
		acc += row[1]
		if roll < acc:
			type = row[0]
			break
	_enemy_counter += 1
	enemy_spawner.spawn({"name": "E%d" % _enemy_counter, "type": type, "pos": pos})


# --- Kayıt (yalnızca sunucu) ---

func _store_player(p) -> void:
	if p.save_key.is_empty():
		return
	_save.put_player(p.save_key, {
		"name": p.player_name, "level": p.level, "xp": p.xp, "gold": p.gold, "potions": p.potions,
		"inv": p.inv, "weapon": p.weapon, "armor": p.armor,
		"quest": {"kind": p.quest_kind, "have": p.quest_have, "need": p.quest_need} if p.quest_kind != "" else {},
	})


func _save_all() -> void:
	if not _hosting:
		return
	for p in players.get_children():
		_store_player(p)
	_save.flush()


func _exit_tree() -> void:
	_save_all()


func _spawn_boss() -> void:
	var where: String = BOSS_SPOTS.keys().pick_random()
	var pos: Vector2 = BOSS_SPOTS[where]
	for attempt in 20:
		var blocked := false
		for o in _obstacle_spots:
			if o.distance_to(pos) < 80.0:
				blocked = true
				break
		if not blocked:
			break
		pos = BOSS_SPOTS[where] + Vector2(randf_range(-160, 160), randf_range(-160, 160))
	_enemy_counter += 1
	enemy_spawner.spawn({"name": "E%d" % _enemy_counter, "type": "boss", "pos": pos})
	print("[Boss] Kadim Dev %s köşesinde belirdi." % where)
	Network.broadcast_system("Kadim Dev %s köşesinde uyandı! Tek başına gitme." % where)


func _spawn_random_enemy() -> void:
	var pos := Vector2.ZERO
	for attempt in 30:
		pos = Vector2(randf_range(100, MAP_SIZE.x - 100), randf_range(100, MAP_SIZE.y - 100))
		if pos.distance_to(SPAWN_POINT) < SAFE_RADIUS:
			continue
		var blocked := false
		for o in _obstacle_spots:
			if o.distance_to(pos) < 50.0:
				blocked = true
				break
		if not blocked:
			break
	_enemy_counter += 1
	var type := _pick_type(pos.distance_to(SPAWN_POINT))
	enemy_spawner.spawn({"name": "E%d" % _enemy_counter, "type": type, "pos": pos})


## Kamptan uzaklaştıkça canavarlar güçlenir.
func _pick_type(dist: float) -> String:
	var r := randf()
	if dist < 800.0:
		return "slime" if r < 0.85 else "wolf"
	if dist < 1250.0:
		if r < 0.55:
			return "wolf"
		return "slime" if r < 0.85 else "orc"
	return "orc" if r < 0.5 else "wolf"


# --- Spawn fonksiyonları (tüm peer'larda aynı veriyle çalışır) ---

func _spawn_player(data: Dictionary) -> Node:
	var p = PLAYER_SCENE.instantiate()
	var id: int = data["id"]
	p.name = str(id)
	p.peer_id = id
	p.player_name = data["name"]
	p.position = data["pos"]
	p.apply_progress(data)
	p.set_multiplayer_authority(id)  # hareket: sahibi
	p.get_node("StatsSync").set_multiplayer_authority(1)  # statlar: sunucu
	return p


func _spawn_enemy(data: Dictionary) -> Node:
	var e = ENEMY_SCENE.instantiate()
	e.name = data["name"]
	e.setup(data["type"], data["pos"])
	return e
