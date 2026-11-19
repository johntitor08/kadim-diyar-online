extends CanvasLayer
## Oyun içi arayüz: can/XP barları, görev takibi, yetenek çubuğu, çanta, sohbet, çevrimiçi sayısı.

const Quests := preload("res://scripts/quests.gd")
const InventoryUI := preload("res://scripts/inventory_ui.gd")
const SkillBar := preload("res://scripts/skillbar.gd")
const MarketUI := preload("res://scripts/market_ui.gd")
const Minimap := preload("res://scripts/minimap.gd")
const Zones := preload("res://scripts/zones.gd")

@onready var stats_panel: Control = %StatsPanel
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_text: Label = %HpText
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_text: Label = %XpText
@onready var chat_log: RichTextLabel = %ChatLog
@onready var chat_input: LineEdit = %ChatInput
@onready var online_label: Label = %OnlineLabel
@onready var leave_button: Button = %LeaveButton
@onready var dead_label: Label = %DeadLabel
@onready var gold_label: Label = %GoldLabel
@onready var hint_label: Label = %HintLabel

var inventory: PanelContainer
var market: PanelContainer
var minimap: Control
var world_map: Control
var _zone_label: Label
var skill_bar: Control
var _quest_box: PanelContainer
var _quest_label: Label
var _quest_drop: Button


func _ready() -> void:
	visible = false
	_build_quest_box()
	skill_bar = SkillBar.new()
	var w: float = skill_bar.custom_minimum_size.x
	var h: float = skill_bar.custom_minimum_size.y
	skill_bar.anchor_left = 0.5
	skill_bar.anchor_right = 0.5
	skill_bar.anchor_top = 1.0
	skill_bar.anchor_bottom = 1.0
	skill_bar.offset_left = -w * 0.5
	skill_bar.offset_right = w * 0.5
	skill_bar.offset_top = -h - 8.0
	skill_bar.offset_bottom = -8.0
	add_child(skill_bar)
	inventory = InventoryUI.new()
	inventory.anchor_left = 1.0
	inventory.anchor_right = 1.0
	inventory.offset_left = -404.0
	inventory.offset_right = -14.0
	inventory.offset_top = 290.0
	add_child(inventory)
	market = MarketUI.new()
	market.position = Vector2(12, 214)
	add_child(market)
	# Sağ üst: bölge adı + mini harita; yardım metni sağ alta
	var top_right: VBoxContainer = $TopRight
	_zone_label = Label.new()
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_zone_label.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	_zone_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_zone_label.add_theme_constant_override("outline_size", 5)
	_zone_label.add_theme_font_size_override("font_size", 15)
	top_right.add_child(_zone_label)
	top_right.move_child(_zone_label, 0)
	minimap = Minimap.new()
	minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_right.add_child(minimap)
	top_right.move_child(minimap, 1)
	var help: Label = $TopRight/HelpLabel
	help.reparent(self)
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = -760.0
	help.add_theme_font_size_override("font_size", 11)
	help.offset_right = -12.0
	help.offset_top = -92.0
	help.offset_bottom = -10.0
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	world_map = Minimap.new()
	world_map.big = true
	world_map.visible = false
	world_map.anchor_left = 0.5
	world_map.anchor_right = 0.5
	world_map.anchor_top = 0.5
	world_map.anchor_bottom = 0.5
	world_map.offset_left = -400.0
	world_map.offset_right = 400.0
	world_map.offset_top = -290.0
	world_map.offset_bottom = 270.0
	add_child(world_map)

	Network.game_started.connect(_on_game_started)
	Network.game_ended.connect(func(_r: String) -> void:
		visible = false
		inventory.visible = false
		market.visible = false
		world_map.visible = false)
	Network.chat_received.connect(_on_chat)
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input.gui_input.connect(_on_chat_gui_input)
	leave_button.pressed.connect(func() -> void: Network.leave("Oyundan ayrıldın."))


func _build_quest_box() -> void:
	_quest_box = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.72)
	style.border_color = Color(0.45, 0.55, 0.8, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	_quest_box.add_theme_stylebox_override("panel", style)
	_quest_box.position = Vector2(12, 166)
	_quest_box.custom_minimum_size = Vector2(300, 0)
	_quest_box.custom_minimum_size = Vector2(300, 0)
	add_child(_quest_box)
	var row := HBoxContainer.new()
	_quest_box.add_child(row)
	_quest_label = Label.new()
	_quest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_label.add_theme_font_size_override("font_size", 13)
	row.add_child(_quest_label)
	_quest_drop = Button.new()
	_quest_drop.text = "Bırak"
	_quest_drop.focus_mode = Control.FOCUS_NONE
	_quest_drop.tooltip_text = "Görevi bırak"
	_quest_drop.pressed.connect(func() -> void:
		var p = get_tree().get_first_node_in_group("local_player")
		if p != null:
			p.try_abandon_quest())
	row.add_child(_quest_drop)


func _on_game_started() -> void:
	visible = not Network.is_dedicated
	inventory.visible = false
	get_viewport().gui_release_focus()
	_focus_web_canvas()
	chat_log.clear()
	chat_log.append_text("[color=#9aa]Sohbet için Enter'a bas. Çanta: I, görev: kamptaki Kâhin (F).[/color]\n")


func _process(_delta: float) -> void:
	if not visible:
		return
	online_label.text = "Çevrimiçi: %d" % get_tree().get_nodes_in_group("players").size()
	var p = get_tree().get_first_node_in_group("local_player")
	stats_panel.visible = p != null
	_quest_box.visible = p != null
	skill_bar.visible = p != null
	skill_bar.player = p
	inventory.set_player(p)
	market.set_player(p)
	minimap.player = p
	world_map.player = p
	minimap.visible = p != null
	dead_label.visible = p != null and p.dead
	if p == null:
		inventory.visible = false
		hint_label.visible = false
		return
	gold_label.text = "Altın %d   •   İksir %d/%d (Q)" % [p.gold, p.potions, p.POTION_MAX]
	name_label.text = p.player_name
	level_label.text = "Seviye %d   •   Hasar %d" % [p.level, p.damage]
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	hp_text.text = "%d / %d" % [p.hp, p.max_hp]
	xp_bar.max_value = p.xp_to_next()
	xp_bar.value = p.xp
	xp_text.text = "XP %d / %d" % [p.xp, p.xp_to_next()]
	_update_quest(p)
	_update_hint(p)
	var zone: String = Zones.zone_at(p.position)
	var island := Zones.island_at(p.position)
	_zone_label.text = Zones.ZONES[zone].name + (("  •  " + island) if island != "" else "") + ("  (tekne)" if p.on_water() else "")


func _update_quest(p) -> void:
	_quest_drop.visible = p.quest_kind != ""
	if p.quest_kind == "":
		_quest_label.text = "Görev yok: kampın batısındaki Kâhin'e git (F)."
		_quest_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	elif p.quest_done():
		_quest_label.text = "Görev tamamlandı! Ödül için Kâhin'e dön (F)."
		_quest_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	else:
		_quest_label.text = "Görev: " + Quests.describe(p.quest_kind, p.quest_have, p.quest_need)
		_quest_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))


func _update_hint(p) -> void:
	var text := ""
	if not p.dead and p.near_merchant():
		text = "B: tüccar (iksir, silah, zırh)   •   I: eşya sat" if not market.visible else ""
	elif not p.dead and p.near_oracle():
		if p.quest_kind == "":
			text = "F: Kâhin'den görev al"
		elif p.quest_done():
			text = "F: görevi teslim et"
		else:
			text = "Kâhin: \"%s\"" % Quests.describe(p.quest_kind, p.quest_have, p.quest_need)
	hint_label.text = text
	hint_label.visible = text != ""


## Tarayıcıda klavye olayları yalnızca odaktaki tuvale gelir; sayfa ya da itch.io çerçevesi odağı
## alırsa tuşlar oyuna ulaşmaz. Oyuna her tıklamada odağı tuvale geri ver.
func _focus_web_canvas() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas')||document.querySelector('canvas');" +
			"if(c){if(!c.hasAttribute('tabindex')){c.setAttribute('tabindex','0');}window.focus();c.focus();}})()", true)


func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and OS.has_feature("web"):
		_focus_web_canvas()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("chat") and not chat_input.has_focus():
		chat_input.grab_focus()
		get_viewport().set_input_as_handled()
	elif chat_input.has_focus():
		return
	elif event.is_action_pressed("inventory"):
		inventory.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("world_map"):
		world_map.visible = not world_map.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("buy_potion"):
		var p = get_tree().get_first_node_in_group("local_player")
		if p != null and not p.dead:
			if p.near_merchant():
				if market.visible:
					market.visible = false
				else:
					market.open()
					inventory.visible = true
			else:
				p._say("Tüccar kampta (çayırın ortası)")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and (inventory.visible or market.visible or world_map.visible):
		inventory.visible = false
		market.visible = false
		world_map.visible = false
		get_viewport().set_input_as_handled()


func _on_chat_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		chat_input.release_focus()
		chat_input.accept_event()


func _on_chat_submitted(text: String) -> void:
	Network.send_chat(text)
	chat_input.clear()
	chat_input.release_focus()


func _on_chat(sender: String, text: String, is_system: bool) -> void:
	var safe := text.replace("[", "[lb]")
	if is_system:
		chat_log.append_text("[color=#f0c060]• %s[/color]\n" % safe)
	else:
		chat_log.append_text("[color=#7fc8ff]%s:[/color] %s\n" % [sender.replace("[", "[lb]"), safe])
