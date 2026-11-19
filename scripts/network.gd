extends Node
## Ağ yönetimi: sunucu/istemci kurulumu, oyuncu kaydı ve sohbet.
## Sunucu (peer id 1) otoritedir: canavarlar, can, XP, seviye, altın, eşya ve görevler sunucuda hesaplanır.
## Masaüstü oyuncular ENet (UDP) ile, tarayıcı oyuncuları WebSocket (TCP, port + 1) ile bağlanır.

signal game_started
signal game_ended(reason: String)
signal join_failed(reason: String)
signal player_registered(id: int, player_name: String)
signal player_left(id: int)
signal chat_received(sender: String, text: String, is_system: bool)

## Protokol sürümü: RPC imzaları ya da senkronlanan alanlar değişince artır.
const VERSION := 4
const DEFAULT_PORT := 7820  # 7777 bu makinede MyCity sunucusunda
const WS_PORT_OFFSET := 1   # tarayıcılar için WebSocket portu: DEFAULT_PORT + 1
const MAX_PLAYERS := 16
## Resmi sunucu: playit UDP tüneli -> sunucu makinesinde 127.0.0.1:7820
const OFFICIAL_ADDRESS := "scooter-regs.tun.ply.gg:37826"
const WEB_AUTO_ADDRESS := "Otomatik"
const IDENTITY_PATH := "user://kimlik.cfg"
const DualPeer := preload("res://scripts/dual_peer.gd")
const Look := preload("res://scripts/look.gd")

var player_names: Dictionary = {}  # peer_id -> isim (yalnızca sunucuda dolu)
var player_keys: Dictionary = {}   # peer_id -> kayıt anahtarı (yalnızca sunucuda dolu)
var player_looks: Dictionary = {}  # peer_id -> görünüm (yalnızca sunucuda dolu)
var local_name := "Gezgin%d" % randi_range(100, 999)
var local_look: Dictionary = {}
var is_dedicated := false
var bot_mode := false  # test için: oyuncu kendi kendine savaşır
var bot_zone := ""      # test botu bu bölgeye geçip orada avlanır

## Bu cihazın kimliği: sunucu ilerlemeyi (seviye, altın, eşya) bu anahtarla saklar.
var client_key := ""
var key_from_cli := false  # --key= ile verildiyse diske yazılmaz
## Sunucu ayarları (komut satırından değiştirilebilir)
var save_path := "user://kayit.json"
var boss_interval := 240.0
var zone_boss_interval := 180.0  # Ejderha / Kraken: bölgede oyuncu varken bu kadar saniyede bir
var test_mode := false  # --test-modu: ganimet şansı yüksek, görevler kısa, portal seviyesi yok, başlangıç altını 500


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	local_look = Look.random_look()
	_load_identity()


func _exit_tree() -> void:
	# Oyun kapanırken bağlantıları kapat (ENet/WebSocket nesneleri sızmasın).
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_online() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_web() -> bool:
	return OS.has_feature("web")


# --- Kimlik (isim + görünüm + kayıt anahtarı) ---

func _load_identity() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(IDENTITY_PATH) != OK:
		return
	client_key = str(cfg.get_value("kimlik", "anahtar", ""))
	var saved_name := str(cfg.get_value("kimlik", "isim", ""))
	if not saved_name.is_empty():
		local_name = _sanitize_name(saved_name)
	var saved_look = cfg.get_value("kimlik", "gorunum", {})
	if saved_look is Dictionary and not saved_look.is_empty():
		local_look = Look.sanitize(saved_look)


func _ensure_identity() -> void:
	if not _valid_key(client_key):
		client_key = _random_key()
		key_from_cli = false
	save_identity()


## İsmi, görünümü ve anahtarı diske yazar (test botları ve --key= ile verilen anahtar yazılmaz).
func save_identity() -> void:
	if key_from_cli or bot_mode:
		return
	var cfg := ConfigFile.new()
	cfg.load(IDENTITY_PATH)
	if _valid_key(client_key):
		cfg.set_value("kimlik", "anahtar", client_key)
	cfg.set_value("kimlik", "isim", local_name)
	cfg.set_value("kimlik", "gorunum", Look.sanitize(local_look))
	cfg.save(IDENTITY_PATH)


func _random_key() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() == 16:
		return bytes.hex_encode()
	var key := ""
	for i in 4:
		key += "%08x" % randi()
	return key


func _valid_key(key: String) -> bool:
	if key.length() < 8 or key.length() > 64:
		return false
	for c in key:
		if not (c in "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"):
			return false
	return true


# --- Sunucu kur / katıl ---

func host(port: int, player_name: String, dedicated := false) -> Error:
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, MAX_PLAYERS)
	if err != OK:
		return err
	# Tarayıcılar UDP kullanamaz: aynı oyuna WebSocket ile (port + 1, TCP) bağlanırlar.
	var ws := WebSocketMultiplayerPeer.new()
	var ws_err := ws.create_server(port + WS_PORT_OFFSET)
	if ws_err == OK:
		var dual := DualPeer.new()
		dual.setup(enet, ws)
		multiplayer.multiplayer_peer = dual
	else:
		print("[Ağ] UYARI: WebSocket portu %d açılamadı (%s), yalnızca UDP." % [port + WS_PORT_OFFSET, error_string(ws_err)])
		multiplayer.multiplayer_peer = enet
	is_dedicated = dedicated
	player_names.clear()
	player_keys.clear()
	player_looks.clear()
	print("[Ağ] Sunucu %d portunda başlatıldı%s." % [port, " (dedicated)" if dedicated else ""])
	if ws_err == OK:
		print("[Ağ] Tarayıcılar için WebSocket %d portunda." % (port + WS_PORT_OFFSET))
	game_started.emit()
	if not dedicated:
		local_name = _sanitize_name(player_name)
		_ensure_identity()
		player_names[1] = local_name
		player_keys[1] = client_key
		player_looks[1] = Look.sanitize(local_look)
		player_registered.emit(1, local_name)
	return OK


## "adres:port" biçimini ayırır; port yazılmamışsa default_port kullanılır.
func split_address(address: String, default_port: int) -> Array:
	address = address.strip_edges()
	var i := address.rfind(":")
	if i > 0 and address.count(":") == 1 and address.substr(i + 1).is_valid_int():
		var p := address.substr(i + 1).to_int()
		if p > 0 and p < 65536:
			return [address.left(i), p]
	return [address, default_port]


func join(address: String, port: int, player_name: String) -> Error:
	address = address.strip_edges()
	local_name = _sanitize_name(player_name)
	if is_web() or address.begins_with("ws://") or address.begins_with("wss://"):
		var ws := WebSocketMultiplayerPeer.new()
		var ws_err := ws.create_client(address)
		if ws_err != OK:
			return ws_err
		multiplayer.multiplayer_peer = ws
	else:
		var target := split_address(address, port)
		address = target[0]
		port = target[1]
		var enet := ENetMultiplayerPeer.new()
		var err := enet.create_client(address, port)
		if err != OK:
			return err
		multiplayer.multiplayer_peer = enet
		address = "%s:%d" % [address, port]
	_ensure_identity()
	print("[Ağ] %s adresine bağlanılıyor..." % address)
	return OK


func leave(reason := "") -> void:
	if is_online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	game_ended.emit(reason)
	player_names.clear()
	player_keys.clear()
	player_looks.clear()
	is_dedicated = false


# --- Bağlantı olayları ---

func _on_connected_to_server() -> void:
	print("[Ağ] Sunucuya bağlanıldı. ID: %d" % multiplayer.get_unique_id())
	game_started.emit()
	_register.rpc_id(1, local_name, client_key, VERSION, Look.sanitize(local_look))


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	join_failed.emit("Bağlantı kurulamadı.")


func _on_server_disconnected() -> void:
	leave("Sunucu bağlantısı koptu.")


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		print("[Ağ] Peer bağlandı: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not player_names.has(id):
		return
	var left_name: String = player_names[id]
	player_names.erase(id)
	player_left.emit(id)
	player_keys.erase(id)
	player_looks.erase(id)
	broadcast_system("%s oyundan ayrıldı." % left_name)


## Eski sürümler görünüm göndermez; varsayılan değer sayesinde sürüm uyarısını yine de alırlar.
@rpc("any_peer", "reliable")
func _register(player_name: String, key: String, version: int, look: Dictionary = {}) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if player_names.has(id):
		return
	if version != VERSION:
		print("[Ağ] Peer %d reddedildi: sürüm %d (sunucu %d)" % [id, version, VERSION])
		_rejected.rpc_id(id, "Sürüm uyumsuz: oyunun güncel sürümünü indir (sunucu v%d, sen v%d)." % [VERSION, version])
		return
	player_names[id] = _sanitize_name(player_name)
	player_keys[id] = key if _valid_key(key) else ""
	player_looks[id] = Look.sanitize(look)
	var dual := multiplayer.multiplayer_peer as DualPeer
	var via := " (tarayıcı)" if dual != null and dual.is_web_peer(id) else ""
	print("[Ağ] %s kaydoldu%s." % [player_names[id], via])
	player_registered.emit(id, player_names[id])
	broadcast_system("%s oyuna katıldı." % player_names[id])


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	leave(reason)


# --- Sohbet ---

func send_chat(text: String) -> void:
	text = text.strip_edges().left(200)
	if text.is_empty() or not is_online():
		return
	_server_chat.rpc_id(1, text)


@rpc("any_peer", "call_local", "reliable")
func _server_chat(text: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not player_names.has(id):
		return
	_receive_chat.rpc(player_names[id], text.strip_edges().left(200), false)


func broadcast_system(text: String) -> void:
	if multiplayer.is_server() and is_online():
		_receive_chat.rpc("", text, true)


## Yalnızca bir oyuncuya giden sistem mesajı (görev, ganimet bildirimi).
func send_private(peer_id: int, text: String) -> void:
	if not multiplayer.is_server() or not is_online():
		return
	if peer_id == multiplayer.get_unique_id():
		_receive_chat("", text, true)
	elif player_names.has(peer_id):
		_receive_chat.rpc_id(peer_id, "", text, true)


@rpc("authority", "call_local", "reliable")
func _receive_chat(sender: String, text: String, is_system: bool) -> void:
	print("[Sohbet] %s%s" % ["" if is_system else sender + ": ", text])
	chat_received.emit(sender, text, is_system)


func _sanitize_name(n: String) -> String:
	n = n.strip_edges().replace("[", "").replace("]", "").left(16)
	return n if not n.is_empty() else "Gezgin"
