extends CanvasLayer
## Oyun içi arayüz: can/XP barları, sohbet, çevrimiçi sayısı.

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


func _ready() -> void:
	visible = false
	Network.game_started.connect(_on_game_started)
	Network.game_ended.connect(func(_r: String) -> void: visible = false)
	Network.chat_received.connect(_on_chat)
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input.gui_input.connect(_on_chat_gui_input)
	leave_button.pressed.connect(func() -> void: Network.leave("Oyundan ayrıldın."))


func _on_game_started() -> void:
	visible = not Network.is_dedicated
	chat_log.clear()
	chat_log.append_text("[color=#9aa]Sohbet için Enter'a bas.[/color]\n")


func _process(_delta: float) -> void:
	if not visible:
		return
	online_label.text = "Çevrimiçi: %d" % get_tree().get_nodes_in_group("players").size()
	var p = get_tree().get_first_node_in_group("local_player")
	stats_panel.visible = p != null
	dead_label.visible = p != null and p.dead
	hint_label.visible = p != null and not p.dead and p.near_merchant()
	if p == null:
		return
	gold_label.text = "Altın %d   •   İksir %d/%d (Q)" % [p.gold, p.potions, p.POTION_MAX]
	if hint_label.visible:
		if p.potions >= p.POTION_MAX:
			hint_label.text = "Tüccar: çantan dolu (%d iksir)" % p.POTION_MAX
		elif p.gold < p.POTION_COST:
			hint_label.text = "Tüccar: iksir %d altın (sende %d var)" % [p.POTION_COST, p.gold]
		else:
			hint_label.text = "B: iksir satın al (%d altın)" % p.POTION_COST
	name_label.text = p.player_name
	level_label.text = "Seviye %d   •   Hasar %d" % [p.level, p.damage]
	hp_bar.max_value = p.max_hp
	hp_bar.value = p.hp
	hp_text.text = "%d / %d" % [p.hp, p.max_hp]
	xp_bar.max_value = p.xp_to_next()
	xp_bar.value = p.xp
	xp_text.text = "XP %d / %d" % [p.xp, p.xp_to_next()]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("chat") and not chat_input.has_focus():
		chat_input.grab_focus()
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
