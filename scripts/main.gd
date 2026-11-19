extends Node
## Komut satırı argümanlarıyla otomatik başlatma:
##   godot -- --server              -> dedicated (ekransız) sunucu
##   godot -- --host --name=Ali     -> sunucu kur ve oyna
##   godot -- --join=127.0.0.1      -> sunucuya katıl ("adres:port" da olur)
##   godot -- --bot                 -> karakter kendi kendine savaşır (test)
##   godot -- --sure=30             -> 30 saniye sonra kendiliğinden kapanır (test.sh)
##   godot -- --key=abc12345        -> kayıt anahtarını elle ver (diske yazılmaz; test)
##   godot -- --kayit=user://x.json -> sunucu kayıt dosyası (varsayılan user://kayit.json)
##   godot -- --boss-sure=10        -> boss'un uyanma aralığı, saniye (varsayılan 240)
##   godot -- --test-modu           -> sunucu: ganimet şansı 6 kat, görevler 2 canavarlık, portal seviyesi yok (test.sh)
##   godot -- --bolge-boss-sure=20  -> Ejderha/Kraken uyanma aralığı, saniye (varsayılan 180)
##   godot -- --bot-bolge=volcano   -> test botu önce bu bölgeye geçer, orada avlanır
##   godot -- --foto                -> görsel kontrol: user://foto_*.png yazar ve kapanır


const Items := preload("res://scripts/items.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var port := Network.DEFAULT_PORT
	var join_address := ""
	var foto := false
	for a in args:
		if a.begins_with("--name="):
			Network.local_name = a.get_slice("=", 1)
		elif a.begins_with("--port="):
			port = a.get_slice("=", 1).to_int()
		elif a.begins_with("--join="):
			join_address = a.get_slice("=", 1)
		elif a == "--bot":
			Network.bot_mode = true
		elif a == "--foto":
			foto = true
		elif a.begins_with("--key="):
			Network.client_key = a.get_slice("=", 1)
			Network.key_from_cli = true
		elif a.begins_with("--kayit="):
			Network.save_path = a.get_slice("=", 1)
		elif a == "--test-modu":
			Network.test_mode = true
		elif a.begins_with("--bolge-boss-sure="):
			Network.zone_boss_interval = maxf(a.get_slice("=", 1).to_float(), 5.0)
		elif a.begins_with("--bot-bolge="):
			Network.bot_zone = a.get_slice("=", 1)
		elif a.begins_with("--boss-sure="):
			Network.boss_interval = maxf(a.get_slice("=", 1).to_float(), 5.0)
		elif a.begins_with("--sure="):
			get_tree().create_timer(a.get_slice("=", 1).to_float()).timeout.connect(get_tree().quit)

	if foto:
		Network.client_key = "fototest0001"
		Network.key_from_cli = true
		Network.save_path = "user://foto_kayit.json"
		SFX.muted = true
		_foto()
	elif "--server" in args or (DisplayServer.get_name() == "headless" and join_address.is_empty()):
		Network.host(port, "", true)
	elif "--host" in args:
		Network.host(port, Network.local_name)
	elif not join_address.is_empty():
		Network.join(join_address, port, Network.local_name)


## Görsel kontrol: karakter oluşturma, kamp + arayüz, market, bölgeler, dünya haritası, kapak.
func _foto() -> void:
	$Menu.name_edit.text = "Gezgin"  # gerçek oyuncu adı herkese açık görüntülere girmesin
	await get_tree().create_timer(0.8).timeout
	await _shot("foto_0_karakter")
	Network.host(Network.DEFAULT_PORT + 9, "Gezgin")
	await get_tree().create_timer(1.0).timeout
	var me = get_tree().get_first_node_in_group("local_player")
	var world = $World
	me.position = Vector2(1600, 1560)
	me.facing = Vector2(0.3, 1.0).normalized()
	me.level = 14
	me.server_set_inventory([
		Items.make("weapon", 1, 12), Items.make("armor", 0, 10), Items.make("armor", 2, 14), Items.make("weapon", 0, 9),
	], Items.make("weapon", 2, 15), Items.make("armor", 1, 13))
	me.hp = me.max_hp
	me.gold = 2400
	me.potions = 3
	me.quest_kind = "imp"
	me.quest_need = 5
	me.quest_have = 2
	me._send_inventory()
	await get_tree().create_timer(0.8).timeout
	await _shot("foto_1_kamp")
	# Market + çanta
	me.position = me.MERCHANT_POS + Vector2(-30, 70)
	await get_tree().create_timer(0.3).timeout
	$HUD.market.open()
	$HUD.inventory.visible = true
	await get_tree().create_timer(0.8).timeout
	await _shot("foto_2_market")
	$HUD.market.visible = false
	$HUD.inventory.visible = false
	# Bölgeler: oyuncuyu ışınla, yanına bölgenin canavarlarını koy
	var scenes := [
		["foto_3_mezarlik", Vector2(4980, 1200), [["zombie", Vector2(170, -70)], ["skeleton", Vector2(240, 90)], ["ghost", Vector2(90, 130)]]],
		["foto_4_buzul", Vector2(8180, 1200), [["snow_wolf", Vector2(160, -60)], ["yeti", Vector2(250, 70)], ["ice_golem", Vector2(-160, 110)]]],
		["foto_5_okyanus", Vector2(1750, 5920), [["crab", Vector2(-60, -280)], ["pirate", Vector2(90, -300)], ["kraken", Vector2(330, 120)]]],
		["foto_6_volkan", Vector2(11420, 1190), [["imp", Vector2(-150, -110)], ["lava_slime", Vector2(-200, 120)], ["dragon", Vector2(230, -40)]]],
	]
	var n := 0
	for sc in scenes:
		me._server_teleport(sc[1])
		me.hp = me.max_hp
		for row in sc[2]:
			n += 1
			world.enemy_spawner.spawn({"name": "Foto%d" % n, "type": row[0], "pos": sc[1] + row[1]})
		await get_tree().create_timer(2.6).timeout
		me.hp = me.max_hp
		await _shot(sc[0])
	$HUD.world_map.visible = true
	await get_tree().create_timer(0.3).timeout
	await _shot("foto_7_dunya")
	$HUD.world_map.visible = false
	$HUD.visible = false  # kapak görseli için arayüzsüz kare (volkan, ejderha)
	me.hp = me.max_hp
	await get_tree().create_timer(1.2).timeout
	await _shot("foto_8_kapak")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % file_name)
	print("[Foto] user://%s.png" % file_name)
