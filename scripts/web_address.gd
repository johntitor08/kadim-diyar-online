extends RefCounted
## Tarayıcı sürümü sunucuya Cloudflare wss tüneliyle bağlanır. Tünel adresi yeniden başlayınca
## değişir; sunucu bilgisayarındaki deploy/web-tunel.sh güncel adresi bir gist dosyasına yazar,
## tarayıcı sürümü bağlanmadan önce oradan okur.

const GIST_ID := "381f11f78aba653c84a6ff5d2a8ae110"
const FILE_NAME := "kadim-diyar.json"


## Sonuç done(adres) ile döner; okunamazsa adres boştur.
static func fetch(parent: Node, done: Callable) -> void:
	if GIST_ID == "":
		done.call("")
		return
	var req := HTTPRequest.new()
	req.timeout = 8.0
	parent.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		req.queue_free()
		var address := ""
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary:
				address = str(parsed.get("wss", ""))
		done.call(address if address.begins_with("ws") else "")
	)
	# Önbelleğe takılmasın diye zaman damgası eklenir.
	var url := "https://gist.githubusercontent.com/johntitor08/%s/raw/%s?t=%d" % [GIST_ID, FILE_NAME, int(Time.get_unix_time_from_system())]
	if req.request(url) != OK:
		req.queue_free()
		done.call("")
