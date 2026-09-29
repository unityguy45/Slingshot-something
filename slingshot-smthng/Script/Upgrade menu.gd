class_name UpgradeMenu
extends CanvasLayer

signal launch
signal buy(key: String)
signal accept(pname: String, kind: String)

const UPGRADES := [["fuel", "Fuel Tank", "+30 fuel capacity"], ["engine", "Engine", "+15% thrust"], ["efficiency", "Fuel Efficiency", "-10% fuel burn"], ["drones", "Drone Bay", "+1 probe drone"], ["hull", "Hull Plating", "+25 hull, survive harder bumps"], ["scanner", "Research Scanner", "+20% research credits"]]
const MAX_LEVEL := 5

var credits_l: Label
var rows := {}
var info_l: Label
var tabs: TabContainer
var mission_box: VBoxContainer
var mission_head: Label
static var last_tab := 0


static func cost(key: String, level: int) -> int:
	var base: int = 40
	if key == "engine":
		base = 55
	elif key == "efficiency":
		base = 45
	elif key == "drones":
		base = 35
	elif key == "hull":
		base = 50
	elif key == "scanner":
		base = 70
	return int(base * (level + 1) * (1.0 + level * 0.25))


func build(title: String, claimed_text: String) -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.08, 0.14, 0.96), Color(0.3, 0.9, 0.7), 3, 18))
	panel.custom_minimum_size = Vector2(1000, 0)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	center.add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	v.add_child(_label(title, 36, Color(0.5, 1.0, 0.8)))
	info_l = _label(claimed_text, 22, Color(1.0, 0.85, 0.4))
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(info_l)
	credits_l = _label("", 28, Color(1.0, 0.9, 0.5))
	v.add_child(credits_l)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 470)
	tabs.add_theme_font_size_override("font_size", 22)
	v.add_child(tabs)
	var up := VBoxContainer.new()
	up.name = "Upgrades"
	up.add_theme_constant_override("separation", 8)
	tabs.add_child(up)
	var ms := VBoxContainer.new()
	ms.name = "Missions"
	tabs.add_child(ms)
	mission_head = _label("", 17, Color(0.7, 0.8, 0.95))
	mission_head.autowrap_mode = TextServer.AUTOWRAP_WORD
	ms.add_child(mission_head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ms.add_child(scroll)
	mission_box = VBoxContainer.new()
	mission_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_box.add_theme_constant_override("separation", 6)
	scroll.add_child(mission_box)
	tabs.current_tab = last_tab
	tabs.tab_changed.connect(_on_tab)
	for u in UPGRADES:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		var name_box := VBoxContainer.new()
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := _label(u[1], 23, Color.WHITE)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var d := _label(u[2], 16, Color(0.6, 0.7, 0.8))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_box.add_child(n)
		name_box.add_child(d)
		h.add_child(name_box)
		var pips := _label("", 26, Color(0.4, 1.0, 0.7))
		pips.custom_minimum_size = Vector2(150, 0)
		h.add_child(pips)
		var b := _button("", Color(0.2, 0.45, 0.9))
		b.custom_minimum_size = Vector2(190, 50)
		b.pressed.connect(_on_buy_pressed.bind(u[0]))
		h.add_child(b)
		up.add_child(h)
		rows[u[0]] = [pips, b]
	var go := _button("LAUNCH", Color(0.15, 0.7, 0.45))
	go.custom_minimum_size = Vector2(0, 60)
	go.add_theme_font_size_override("font_size", 32)
	go.pressed.connect(_on_launch_pressed)
	v.add_child(go)
	v.add_child(_label("Refuelled, repaired and drones restocked. Launch aims at your cursor.", 16, Color(0.6, 0.7, 0.8)))


func _on_tab(i: int) -> void:
	last_tab = i


func set_missions(list: Array, active: int, max_active: int) -> void:
	mission_head.text = "Pick the research you want. Active missions: %d / %d  (click again to drop one)\nSurvey = fly inside the green zone around it. Drone = land a probe on it (raises its research level, max 3)." % [active, max_active]
	for c in mission_box.get_children():
		c.queue_free()
	for r: Dictionary in list:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := _label("%s     research %d/3" % [r.name, int(r.level)] if r.can_drone else "%s" % r.name, 20, Color.WHITE)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var sub := _label("%s   -   %d m away" % [r.type, int(r.dist)], 14, Color(0.6, 0.7, 0.8))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.add_child(n)
		info.add_child(sub)
		h.add_child(info)
		var sb := _button("", Color(0.15, 0.6, 0.5))
		sb.custom_minimum_size = Vector2(250, 44)
		sb.add_theme_font_size_override("font_size", 17)
		if r.surveyed:
			sb.text = "Surveyed"
			sb.disabled = true
		elif r.s_active:
			sb.text = "ACTIVE: Survey  +%d" % int(r.s_reward)
		else:
			sb.text = "Survey  +%d cr" % int(r.s_reward)
			sb.disabled = active >= max_active
		sb.pressed.connect(_on_accept.bind(r.name, "survey"))
		h.add_child(sb)
		var db := _button("", Color(0.75, 0.55, 0.15))
		db.custom_minimum_size = Vector2(250, 44)
		db.add_theme_font_size_override("font_size", 17)
		if not r.can_drone:
			db.text = "No landing possible"
			db.disabled = true
		elif int(r.level) >= 3:
			db.text = "Research maxed"
			db.disabled = true
		elif r.d_active:
			db.text = "ACTIVE: Drone Lv%d  +%d" % [int(r.level) + 1, int(r.d_reward)]
		else:
			db.text = "Drone Lv%d  +%d cr" % [int(r.level) + 1, int(r.d_reward)]
			db.disabled = active >= max_active
		db.pressed.connect(_on_accept.bind(r.name, "drone"))
		h.add_child(db)
		mission_box.add_child(h)


func _on_accept(pname: String, kind: String) -> void:
	accept.emit(pname, kind)


func _on_buy_pressed(key: String) -> void:
	buy.emit(key)


func _on_launch_pressed() -> void:
	launch.emit()


func refresh(credits: int, levels: Dictionary) -> void:
	credits_l.text = "Credits: %d" % credits
	for key in rows:
		var lvl: int = levels[key]
		var pips: Label = rows[key][0]
		var b: Button = rows[key][1]
		pips.text = "[" + "|".repeat(lvl) + "-".repeat(MAX_LEVEL - lvl) + "]"
		if lvl >= MAX_LEVEL:
			b.text = "MAXED"
			b.disabled = true
		else:
			var c := cost(key, lvl)
			b.text = "BUY  %d cr" % c
			b.disabled = credits < c


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", _box(col.darkened(0.3), col, 2, 10))
	b.add_theme_stylebox_override("hover", _box(col, col.lightened(0.4), 2, 10))
	b.add_theme_stylebox_override("pressed", _box(col.darkened(0.5), col, 2, 10))
	b.add_theme_stylebox_override("disabled", _box(Color(0.12, 0.13, 0.17), Color(0.25, 0.27, 0.32), 2, 10))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.47, 0.52))
	return b


func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s
