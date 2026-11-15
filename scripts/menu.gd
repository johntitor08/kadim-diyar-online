extends CanvasLayer
## Ana menü: sunucu kur (host) veya bir sunucuya katıl (join).

@onready var name_edit: LineEdit = %NameEdit
@onready var address_edit: LineEdit = %AddressEdit
@onready var port_edit: LineEdit = %PortEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	name_edit.text = Network.local_name
	address_edit.text = Network.OFFICIAL_ADDRESS
	address_edit.tooltip_text = "Katılmak için sunucu adresi. \"adres:port\" yazılırsa o port kullanılır."
	port_edit.text = str(Network.DEFAULT_PORT)
	port_edit.tooltip_text = "Sunucu kurarken kullanılacak port (adreste port yoksa katılırken de)."
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	Network.game_started.connect(func() -> void: visible = false)
	Network.game_ended.connect(_on_game_ended)
	Network.join_failed.connect(_on_join_failed)


func _port() -> int:
	var p := port_edit.text.to_int()
	return p if p > 0 and p < 65536 else Network.DEFAULT_PORT


func _set_busy(busy: bool) -> void:
	host_button.disabled = busy
	join_button.disabled = busy


func _on_host() -> void:
	var err := Network.host(_port(), name_edit.text)
	if err != OK:
		status_label.text = "Sunucu kurulamadı (port kullanımda olabilir). Hata: %s" % error_string(err)


func _on_join() -> void:
	var err := Network.join(address_edit.text.strip_edges(), _port(), name_edit.text)
	if err != OK:
		status_label.text = "Bağlanılamadı: %s" % error_string(err)
		return
	status_label.text = "Bağlanılıyor..."
	_set_busy(true)


func _on_join_failed(reason: String) -> void:
	status_label.text = reason
	_set_busy(false)


func _on_game_ended(reason: String) -> void:
	visible = true
	status_label.text = reason
	_set_busy(false)
