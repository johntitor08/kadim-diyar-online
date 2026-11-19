extends RefCounted
## Tarayıcı sürümü sunucuya Cloudflare wss tüneliyle bağlanır. Tünel adresi yeniden başlayınca
## değişir; sunucu bilgisayarındaki deploy/web-tunel.sh güncel adresi bir gist dosyasına yazar,
## tarayıcı sürümü bağlanmadan önce oradan okur.
## Sayfa daha yeni açılmışken ilk istek yavaş kalabildiğinden birkaç kez denenir; hiçbiri
## olmazsa en son başarıyla okunan adres (user:// içinde saklanır) kullanılır.

const GIST_ID := "381f11f78aba653c84a6ff5d2a8ae110"
const FILE_NAME := "kadim-diyar.json"
const TIMEOUTS := [10.0, 15.0, 20.0]
const CACHE_PATH := "user://son_web_adres.txt"


## Sonuç done(adres) ile döner; okunamazsa adres boştur.
## on_retry(deneme_no) yeniden denemeden önce çağrılır (durum yazısı için).
static func fetch(parent: Node, done: Callable, on_retry: Callable = Callable()) -> void:
	if GIST_ID == "":
		done.call("")
		return
	_attempt(parent, done, on_retry, 0)


static func _attempt(parent: Node, done: Callable, on_retry: Callable, index: int) -> void:
	if not is_instance_valid(parent):
		return
	var req := HTTPRequest.new()
	req.timeout = TIMEOUTS[index]
	parent.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var address := ""
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary:
				address = str(parsed.get("wss", ""))
		if address.begins_with("ws"):
			_save_cache(address)
			done.call(address)
		else:
			_next(parent, done, on_retry, index, "sonuç %d, kod %d" % [result, code])
	)
	# Önbelleğe takılmasın diye zaman damgası eklenir.
	var url := "https://gist.githubusercontent.com/johntitor08/%s/raw/%s?t=%d" % [GIST_ID, FILE_NAME, int(Time.get_unix_time_from_system())]
	var err := req.request(url)
	if err != OK:
		req.queue_free()
		_next(parent, done, on_retry, index, "istek hatası %s" % error_string(err))


static func _next(parent: Node, done: Callable, on_retry: Callable, index: int, why: String) -> void:
	print("[Web] Sunucu adresi okunamadı (%d. deneme: %s)" % [index + 1, why])
	if index + 1 < TIMEOUTS.size() and is_instance_valid(parent):
		if on_retry.is_valid():
			on_retry.call(index + 2)
		await parent.get_tree().create_timer(1.0).timeout
		_attempt(parent, done, on_retry, index + 1)
		return
	var cached := _load_cache()
	if cached != "":
		print("[Web] Son bilinen adres kullanılıyor: %s" % cached)
	done.call(cached)


static func _save_cache(address: String) -> void:
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(address)


static func _load_cache() -> String:
	if not FileAccess.file_exists(CACHE_PATH):
		return ""
	var text := FileAccess.get_file_as_string(CACHE_PATH).strip_edges()
	return text if text.begins_with("ws") else ""
