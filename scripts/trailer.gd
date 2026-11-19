extends Node
## Fragman kipi (--fragman): senaryolu sahneler + altyazılar. Godot'nun film kaydıyla birlikte çalıştırılır:
##   godot --path . --write-movie build/fragman/ham.avi --fixed-fps 30 --resolution 1920x1080 -- --fragman
## Yerel bir sunucu kurar, ekibi (sen + 3 bot arkadaş) bölgeden bölgeye taşır; botlar kendi savaşır.

const Items := preload("res://scripts/items.gd")
const Look := preload("res://scripts/look.gd")
const Zones := preload("res://scripts/zones.gd")
const FRIENDS := ["Ayşe", "Kerem", "Deniz"]

var main: Node
var world: Node
var me = null
var team: Array = []
var _layer: CanvasLayer
var _dim: ColorRect
var _title: Label
var _sub: Label
var _caption: Label
var _n := 0


func _ready() -> void:
	main = get_parent()
	world = main.get_node("World")
	_build_overlay()
	_run()


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.03, 0.05, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_dim)
	_title = _label(78, Color(1, 0.82, 0.45), 10)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.offset_left = -640
	_title.offset_right = 640
	_title.offset_top = -110
	_title.offset_bottom = -10
	_sub = _label(28, Color(0.92, 0.88, 0.8), 6)
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub.offset_left = -640
	_sub.offset_right = 640
	_sub.offset_top = 0
	_sub.offset_bottom = 90
	_caption = _label(40, Color(1, 0.92, 0.7), 9)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_left = -640
	_caption.offset_right = 640
	_caption.offset_top = -150
	_caption.offset_bottom = -90


func _label(font_size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.0))
	l.add_theme_constant_override("outline_size", outline)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(l)
	return l


func _fade(node: CanvasItem, to: float, t: float) -> void:
	node.create_tween().tween_property(node, "modulate:a", to, t)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func caption(text: String, hold: float) -> void:
	_caption.text = text
	_fade(_caption, 1.0, 0.35)
	await _wait(hold)
	_fade(_caption, 0.0, 0.35)
	await _wait(0.35)


func title_card(title: String, sub: String, hold: float) -> void:
	_title.text = title
	_sub.text = sub
	_dim.create_tween().tween_property(_dim, "color:a", 0.72, 0.4)
	_fade(_title, 1.0, 0.5)
	await _wait(0.3)
	_fade(_sub, 1.0, 0.5)
	await _wait(hold)
	_fade(_title, 0.0, 0.4)
	_fade(_sub, 0.0, 0.4)
	_dim.create_tween().tween_property(_dim, "color:a", 0.0, 0.4)
	await _wait(0.4)


func _process(_delta: float) -> void:
	# Ekip fragman boyunca ayakta kalsın (sahte arkadaşların yeniden doğması ağ isteği gerektirir)
	for p in team:
		if is_instance_valid(p) and p.hp < p.max_hp * 0.45:
			p.hp = p.max_hp


func _spawn_enemies(center: Vector2, rows: Array) -> void:
	for row in rows:
		_n += 1
		var e = world.enemy_spawner.spawn({"name": "Fragman%d" % _n, "type": row[0], "pos": center + row[1]})
		if row[0] in ["boss", "dragon", "kraken"]:
			# Boss sahne boyunca dayansın
			e.max_hp *= 8
			e.hp = e.max_hp


func _move_team(center: Vector2, zone: String) -> void:
	Network.bot_zone = zone
	for i in team.size():
		var p = team[i]
		var pos: Vector2 = center + Vector2.from_angle(TAU * i / team.size() + 0.4) * (0.0 if i == 0 else 70.0)
		p.position = pos
		p.sync_pos = pos
		p.hp = p.max_hp
	me.snap_camera()


func _clear_enemies() -> void:
	for e in world.get_node("Entities/Enemies").get_children():
		e.queue_free()


func _run() -> void:
	FX.quiet = true
	Network.client_key = "fragman00001"
	Network.key_from_cli = true
	Network.save_path = "user://fragman_kayit.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Network.save_path))
	var menu = main.get_node("Menu")
	var hud = main.get_node("HUD")
	menu.visible = false
	await _wait(0.6)
	await title_card("KADİM DİYAR ONLINE", "Çok oyunculu aksiyon RPG", 2.6)

	# Karakter oluşturma: görünümler hızla değişir
	menu.visible = true
	menu.name_edit.text = "Gezgin"
	_caption.text = "Karakterini oluştur"
	_fade(_caption, 1.0, 0.3)
	for i in 10:
		Network.local_look = Look.random_look()
		menu.get_node("Center/Panel/VBox").get_child(menu.name_edit.get_index() + 1)._refresh()
		await _wait(0.32)
	Network.local_look = {"skin": 1, "hair": 2, "hair_color": 4, "outfit": 1}
	_fade(_caption, 0.0, 0.3)
	await _wait(0.4)

	# Sunucu + ekip
	Network.bot_zone = "meadow"
	Network.host(Network.DEFAULT_PORT + 11, "Gezgin")
	await _wait(0.5)
	hud.visible = false
	me = get_tree().get_first_node_in_group("local_player")
	me.get_node("Camera2D").zoom = Vector2(1.2, 1.2)
	team = [me]
	for k in FRIENDS.size():
		var id := 9001 + k
		var p = world.player_spawner.spawn({"id": id, "name": FRIENDS[k], "pos": me.position + Vector2(60 * (k + 1), 40),
			"look": {"skin": [0, 2, 3][k], "hair": [1, 3, 0][k], "hair_color": [3, 0, 6][k], "outfit": [3, 2, 4][k]},
			"level": 13, "weapon": Items.make("weapon", [1, 2, 1][k], 13), "armor": Items.make("armor", [2, 1, 1][k], 13)})
		p.set_multiplayer_authority(1)
		team.append(p)
	me.level = 14
	me.server_set_inventory([Items.make("armor", 2, 15), Items.make("weapon", 1, 13), Items.make("armor", 1, 12)],
		Items.make("weapon", 2, 15), Items.make("armor", 1, 14))
	for p in team:
		p.potions = 5
		p._bot_market_done = true
		p.hp = p.max_hp
	Network.bot_mode = true

	# Çayır: av ve Kadim Dev
	_move_team(Vector2(1600, 1950), "meadow")
	_spawn_enemies(Vector2(1600, 1950), [["slime", Vector2(160, 80)], ["wolf", Vector2(-180, 120)], ["orc", Vector2(60, 220)]])
	await caption("Arkadaşlarınla aynı dünyada", 3.2)
	_clear_enemies()
	_spawn_enemies(me.position, [["boss", Vector2(150, 60)]])
	await caption("Kadim Dev'i birlikte devir", 4.0)

	var scenes := [
		["graveyard", Vector2(5000, 1200), "Unutulmuş Mezarlık", [["zombie", Vector2(200, -60)], ["skeleton", Vector2(260, 110)],
			["ghost", Vector2(140, 150)], ["zombie", Vector2(-160, 140)], ["skeleton", Vector2(300, -120)]]],
		["glacier", Vector2(8200, 1200), "Ebedi Buzul", [["snow_wolf", Vector2(200, -60)], ["yeti", Vector2(240, 110)],
			["ice_golem", Vector2(-180, 120)], ["snow_wolf", Vector2(120, -160)]]],
		["ocean", Vector2(1750, 5920), "Okyanusa açıl, adaları keşfet", [["crab", Vector2(-60, -290)], ["pirate", Vector2(90, -300)],
			["pirate", Vector2(-180, -260)], ["kraken", Vector2(330, 140)]]],
		["volcano", Vector2(11420, 1190), "Ejderha'yla yüzleş", [["dragon", Vector2(150, -30)], ["imp", Vector2(-330, -160)]]],
	]
	for sc in scenes:
		_clear_enemies()
		_move_team(sc[1], sc[0])
		_spawn_enemies(sc[1], sc[3])
		await _wait(0.6)
		await caption(sc[2], 4.2 if sc[0] != "volcano" else 5.4)

	# Market ve çanta (arayüzle)
	_clear_enemies()
	Network.bot_mode = false
	_move_team(me.MERCHANT_POS + Vector2(-30, 70), "meadow")
	await _wait(0.1)
	team[1].position = me.MERCHANT_POS + Vector2(-140, 130)
	team[2].position = me.MERCHANT_POS + Vector2(60, 150)
	team[3].position = me.MERCHANT_POS + Vector2(-80, 210)
	me.facing = Vector2(0.2, -1.0).normalized()
	me.gold = 2400
	hud.visible = true
	await _wait(0.3)
	hud.market.open()
	hud.inventory.visible = true
	await caption("Ganimet topla, tüccardan donan", 3.4)
	hud.market.visible = false
	hud.inventory.visible = false
	hud.world_map.visible = true
	await caption("5 bölge • 15'ten fazla düşman • görevler • yetenekler", 3.4)
	hud.world_map.visible = false
	hud.visible = false

	await title_card("KADİM DİYAR ONLINE", "Ücretsiz  •  Windows  •  Linux  •  Tarayıcı\njohntitortheprog.itch.io/kadim-diyar-online", 3.6)
	await _wait(0.3)
	get_tree().quit()
