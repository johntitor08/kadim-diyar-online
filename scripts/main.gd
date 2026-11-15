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
##   godot -- --foto                -> görsel kontrol: user://foto_*.png yazar ve kapanır


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
		elif a.begins_with("--boss-sure="):
			Network.boss_interval = maxf(a.get_slice("=", 1).to_float(), 5.0)
		elif a.begins_with("--sure="):
			get_tree().create_timer(a.get_slice("=", 1).to_float()).timeout.connect(get_tree().quit)

	if foto:
		Network.client_key = "fototest0001"
		Network.key_from_cli = true
		Network.save_path = "user://foto_kayit.json"
		SFX.muted = true
		Network.host(port + 9, "Gezgin")
		_foto()
	elif "--server" in args or (DisplayServer.get_name() == "headless" and join_address.is_empty()):
		Network.host(port, "", true)
	elif "--host" in args:
		Network.host(port, Network.local_name)
	elif not join_address.is_empty():
		Network.join(join_address, port, Network.local_name)


## Görsel kontrol: tüccar + arayüz, yaklaşan boss, sonra savaş anı.
func _foto() -> void:
	await get_tree().create_timer(1.0).timeout
	var me = get_tree().get_first_node_in_group("local_player")
	me.position = me.MERCHANT_POS + Vector2(-55, 65)
	await get_tree().create_timer(0.6).timeout
	await _shot("foto_1_tuccar")
	$World.enemy_spawner.spawn({"name": "FotoBoss", "type": "boss", "pos": me.position + Vector2(230, 50)})
	await get_tree().create_timer(0.5).timeout
	await _shot("foto_2_boss")
	Network.bot_mode = true
	await get_tree().create_timer(2.5).timeout
	await _shot("foto_3_savas")
	$HUD.visible = false  # kapak görseli için arayüzsüz kare
	await get_tree().create_timer(0.4).timeout
	await _shot("foto_4_kapak")
	get_tree().quit()


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % file_name)
	print("[Foto] user://%s.png" % file_name)
