extends RefCounted
## Sunucu tarafı kalıcı kayıt: oyuncu anahtarı -> ilerleme. Tek bir JSON dosyası.
## Konum gibi Vector2 değerleri buraya konmaz (JSON'da metne döner); yalnızca sayı ve metin.

var path := "user://kayit.json"
var _players: Dictionary = {}
var _dirty := false


func load_file(p: String) -> void:
	path = p
	_players = {}
	_dirty = false
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("players") is Dictionary:
		_players = parsed["players"]
		print("[Kayıt] %d oyuncu kaydı okundu (%s)." % [_players.size(), path])
	else:
		# Bozuk dosyanın üzerine yazmadan önce kenara al.
		var abs_path := ProjectSettings.globalize_path(path)
		DirAccess.copy_absolute(abs_path, abs_path + ".bozuk")
		print("[Kayıt] UYARI: %s okunamadı, .bozuk olarak yedeklendi; boş kayıtla başlanıyor." % path)


func get_player(key: String) -> Dictionary:
	var rec = _players.get(key)
	return rec if rec is Dictionary else {}


func put_player(key: String, record: Dictionary) -> void:
	if key.is_empty():
		return
	if _players.get(key) != record:
		_players[key] = record
		_dirty = true


func count() -> int:
	return _players.size()


## Değişiklik varsa diske yazar: önce geçici dosyaya, sonra yerine taşır.
func flush() -> void:
	if not _dirty:
		return
	var abs_path := ProjectSettings.globalize_path(path)
	var tmp := abs_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		print("[Kayıt] HATA: %s yazılamadı (%s)." % [tmp, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify({"v": 1, "players": _players}, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, abs_path)
	if err != OK:
		print("[Kayıt] HATA: kayıt dosyası taşınamadı (%s)." % error_string(err))
		return
	_dirty = false
