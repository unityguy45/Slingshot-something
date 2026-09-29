extends Node2D

const WORLD_R := 26000.0
const WARN_R := 23000.0
const BELT_IN := 8000.0
const BELT_OUT := 8900.0

var cam: Camera2D
var zoom_level := 0.28
var player: Player
var bodies: Array = []
var stations: Array = []
var front: Node2D
var sun: Planet
var belt_rocks: Array = []
var outside_t := 0.0
var over := false
var t := 0.0
var shake := 0.0
var thrust_snd_t := 0.0
var menu: UpgradeMenu
var pending: Array = []

var data := {"credits": 0, "best": 0, "research": {}, "surveyed": [], "active": [], "tutorial": false, "levels": {"fuel": 0, "engine": 0, "efficiency": 0, "drones": 0, "hull": 0, "scanner": 0}}
var target: Planet
const MAX_ACTIVE := 4
var paused := false
var pause_l: Label
var tut: Array = []
var tut_t := 0.0
var engine_snd: AudioStreamPlayer
var research_max := 0

var hud: Control
var toast_l: Label
var toast_t := 0.0
var msg_l: Label
var nebula: ColorRect
var stars_node: Node2D
var stars: Array = []
var snd := {}
var players: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_load()
	_make_glow()
	_make_background()
	_make_sounds()
	cam = Camera2D.new()
	cam.zoom = Vector2(zoom_level, zoom_level)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 4.0
	add_child(cam)
	_build_system()
	var home: Station = stations[0]
	home.update_motion()
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.bodies = bodies
	player.stations = stations
	add_child(player)
	player.died.connect(_on_died)
	player.docked.connect(_on_docked)
	player.drone_dropped.connect(_on_drone)
	player.bumped.connect(_on_bumped)
	for b: Planet in bodies:
		b.process_mode = Node.PROCESS_MODE_PAUSABLE
		if b.is_sun:
			continue
		research_max += 1
		if b.can_drone():
			research_max += 3
		b.level = int((data.research as Dictionary).get(b.pname, 0))
		b.surveyed = (data.surveyed as Array).has(b.pname)
	_sync_active()
	_apply_upgrades()
	player.refill()
	player.dock(home)
	front = Node2D.new()
	front.z_index = 10
	front.draw.connect(_draw_front)
	add_child(front)
	_make_ui()
	cam.position = player.position
	cam.reset_smoothing()
	_open_menu(home, true)


func _apply_upgrades() -> void:
	var lv: Dictionary = data.levels
	player.fuel_max = 100.0 + 30.0 * lv.fuel
	player.thrust = 800.0 * (1.0 + 0.15 * lv.engine)
	player.burn = 13.0 * (1.0 - 0.1 * lv.efficiency)
	player.drones_max = 2 + lv.drones
	player.hull_max = 100.0 + 25.0 * lv.hull


func _reward_mult() -> float:
	return 1.0 + 0.2 * float(data.levels.scanner)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_level = minf(zoom_level * 1.12, 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_level = maxf(zoom_level / 1.12, 0.05)
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_F11:
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif e.keycode == KEY_R and menu == null and not paused:
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif e.keycode == KEY_ESCAPE and menu == null and not over:
			paused = not paused
			get_tree().paused = paused
			pause_l.visible = paused
		elif e.keycode == KEY_F and not paused and menu == null:
			player.toggle_autopilot()
			_play("buy")
		elif e.keycode == KEY_T and not paused:
			_cycle_target()
		elif e.keycode == KEY_M:
			zoom_level = 0.05 if zoom_level > 0.08 else 0.35
	if over and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	Planet.time += delta
	for b: Planet in bodies:
		b.update_motion()
	for st: Station in stations:
		st.update_motion()


func _process(delta: float) -> void:
	if paused:
		hud.queue_redraw()
		return
	t += delta
	engine_snd.volume_db = lerpf(engine_snd.volume_db, -8.0 if player.thrusting and not get_tree().paused else -60.0, 10.0 * delta)
	if menu == null and not over:
		_tick_tutorial(delta)
		if target == null or not (target.survey_active or target.drone_active):
			_auto_target()
	var zz := zoom_level / (1.0 + (player.vel - player.ref_vel).length() / 2500.0)
	cam.zoom = cam.zoom.lerp(Vector2(zz, zz), 1.0 - exp(-4.0 * delta))
	if not over:
		cam.position = player.position
		if player.state == "fly":
			_update_quests(delta)
			if player.position.length() > WARN_R:
				outside_t += delta
				if outside_t > 10.0 or player.position.length() > WORLD_R:
					player.state = "dead"
					_on_died("Lost in deep space")
			else:
				outside_t = 0.0
	shake = maxf(0.0, shake - delta * 2.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 60.0
	toast_t -= delta
	toast_l.modulate.a = clampf(toast_t, 0.0, 1.0)
	nebula.material.set_shader_parameter("offset", cam.position * 0.00004)
	stars_node.queue_redraw()
	front.queue_redraw()
	hud.queue_redraw()


func _update_quests(delta: float) -> void:
	for b: Planet in bodies:
		if not b.survey_active:
			continue
		var d := player.position.distance_to(b.position)
		var band := b.orbit_band()
		if d > band.x and d < band.y:
			b.survey_progress += delta
			if b.survey_progress >= b.survey_time:
				_complete(b, "survey")

func _complete(b: Planet, kind: String) -> void:
	var rw := 0
	if kind == "survey":
		rw = int(b.survey_reward * _reward_mult())
		b.survey_active = false
		b.survey_progress = 0.0
	else:
		rw = int(b.drone_reward(b.level) * _reward_mult())
		b.drone_active = false
	_remove_active(b.pname, kind)
	pending.append([b, kind, rw])
	_play("research")
	shake = 0.3
	var what := "Survey" if kind == "survey" else "Drone landing (Lv%d)" % (b.level + 1)
	_toast("MISSION COMPLETE: %s - %s  (+%d cr, claim at a station)" % [b.pname, what, rw])
	_burst(player.position, Color(0.5, 1.8, 1.0), 30, 400.0)

func _on_drone(d: Drone) -> void:
	add_child(d)
	d.process_mode = Node.PROCESS_MODE_PAUSABLE
	d.landed.connect(_on_drone_landed)
	_play("drone")


func _on_drone_landed(b: Planet) -> void:
	_burst(b.position + (player.position - b.position).normalized() * b.radius, Color(0.5, 1.8, 1.0), 16, 200.0)
	if b.drone_active:
		_complete(b, "drone")
	elif b.can_drone():
		_toast("Probe landed on %s - accept a drone mission for it at a station first" % b.pname)

func _on_docked(st: Station) -> void:
	_play("dock")
	_open_menu(st, false)


func _open_menu(st: Station, first: bool) -> void:
	var claimed := 0
	var lines := []
	for p in pending:
		claimed += int(p[2])
		var b: Planet = p[0]
		if not is_instance_valid(b):
			continue
		if p[1] == "survey":
			b.surveyed = true
			if not (data.surveyed as Array).has(b.pname):
				(data.surveyed as Array).append(b.pname)
			lines.append("%s survey +%d" % [b.pname, p[2]])
		else:
			b.level = mini(b.level + 1, 3)
			data.research[b.pname] = b.level
			lines.append("%s Lv%d +%d" % [b.pname, b.level, p[2]])
	pending.clear()
	data.credits += claimed
	_save()
	var text := ""
	if first:
		text = "Welcome to the Sol system. Open the MISSIONS tab and pick research to do,\nthen come back to any station to claim your credits."
	elif claimed > 0:
		text = "Research claimed: +%d credits   (%s)\nSystem research: %d / %d" % [claimed, ", ".join(lines), _research_done(), research_max]
		if _research_done() >= research_max:
			text += "\nSOL SYSTEM FULLY RESEARCHED!"
	else:
		text = "No research to claim. Pick missions in the MISSIONS tab."
	player.refill()
	menu = UpgradeMenu.new()
	add_child(menu)
	menu.build(st.sname, text)
	menu.refresh(data.credits, data.levels)
	_refresh_missions()
	menu.buy.connect(_on_buy)
	menu.launch.connect(_on_launch)
	menu.accept.connect(_on_accept)
	get_tree().paused = true
	engine_snd.volume_db = -60.0

func _research_done() -> int:
	var n := 0
	for b: Planet in bodies:
		if b.is_sun:
			continue
		n += b.level + (1 if b.surveyed else 0)
	return n


func _find_body(pname: String) -> Planet:
	for b: Planet in bodies:
		if b.pname == pname:
			return b
	return null


func _sync_active() -> void:
	for b: Planet in bodies:
		b.survey_active = false
		b.drone_active = false
	var keep := []
	for a in data.active:
		var b := _find_body(a[0])
		if b == null:
			continue
		if a[1] == "survey" and not b.surveyed:
			b.survey_active = true
			keep.append(a)
		elif a[1] == "drone" and b.level < 3:
			b.drone_active = true
			keep.append(a)
	data.active = keep


func _remove_active(pname: String, kind: String) -> void:
	var keep := []
	for a in data.active:
		if not (a[0] == pname and a[1] == kind):
			keep.append(a)
	data.active = keep
	_save()


func _on_accept(pname: String, kind: String) -> void:
	var exists := false
	for a in data.active:
		if a[0] == pname and a[1] == kind:
			exists = true
	if exists:
		_remove_active(pname, kind)
	elif (data.active as Array).size() < MAX_ACTIVE:
		(data.active as Array).append([pname, kind])
	_sync_active()
	_save()
	_play("buy")
	_refresh_missions()


func _refresh_missions() -> void:
	var rows := []
	var list := bodies.duplicate()
	list.sort_custom(_closer)
	for b: Planet in list:
		if b.is_sun:
			continue
		var pend_survey := false
		var pend_drone := 0
		for p in pending:
			if p[0] == b:
				if p[1] == "survey":
					pend_survey = true
				else:
					pend_drone += 1
		rows.append({"name": b.pname, "type": b.type_name(), "level": b.level, "surveyed": b.surveyed or pend_survey, "s_reward": int(b.survey_reward * _reward_mult()), "d_reward": int(b.drone_reward(b.level) * _reward_mult()), "dist": b.position.distance_to(player.position) / 10.0, "s_active": b.survey_active, "d_active": b.drone_active, "can_drone": b.can_drone()})
	menu.set_missions(rows, (data.active as Array).size(), MAX_ACTIVE)


func _on_buy(key: String) -> void:
	var lvl: int = data.levels[key]
	var c := UpgradeMenu.cost(key, lvl)
	if data.credits < c or lvl >= UpgradeMenu.MAX_LEVEL:
		return
	data.credits -= c
	data.levels[key] = lvl + 1
	_save()
	_apply_upgrades()
	player.refill()
	_play("buy")
	menu.refresh(data.credits, data.levels)


func _on_launch() -> void:
	menu.queue_free()
	menu = null
	get_tree().paused = false
	player.undock()
	_play("launch")
	if not data.tutorial:
		data.tutorial = true
		_save()
		tut = ["Aim with the MOUSE. Hold LEFT CLICK to boost.", "Hold S or SHIFT to BRAKE. Press F anytime for AUTOPILOT to the nearest station - it docks for you.", "The YELLOW ARROW points at your active missions. T switches target, hold TAB to see them all.", "SURVEY missions: fly inside the green zone around the planet until the bar fills.", "DRONE missions: right click fires a probe that homes in on the planet. Each landing raises its research level (max 3).", "Dock at any station to claim credits, upgrade, and pick new missions in the MISSIONS tab."]
		tut_t = 1.0


func _on_died(reason: String) -> void:
	if over:
		return
	over = true
	shake = 1.2
	_play("boom")
	_burst(player.position, Color(2.5, 1.2, 0.5), 60, 700.0)
	player.trail.clear_points()
	player.queue_redraw()
	var lost := 0
	for p in pending:
		lost += int(p[2])
	_save()
	engine_snd.volume_db = -60.0
	msg_l.text = "%s%s\n\nSystem research: %d / %d\n\nclick to respawn at the Mothership" % [reason, ("\nUnclaimed research lost: %d cr" % lost) if lost > 0 else "", _research_done(), research_max]


func _build_system() -> void:
	seed(20260929)
	sun = _spawn_body(Vector2.ZERO, 420.0, "sun")
	var layout := [[3000.0, "lava", 90.0, 0], [4700.0, "rocky", 120.0, 1], [6400.0, "ocean", 150.0, 1], [10800.0, "gas", 260.0, 2], [13800.0, "ice", 140.0, 1], [17000.0, "gas", 200.0, 1], [20500.0, "rocky", 110.0, 0]]
	var home_planet: Planet
	var station_on := [2, 3, 4, 5]
	for i in layout.size():
		var L: Array = layout[i]
		var p := _spawn_body(Vector2.ZERO, L[2], L[1])
		p.set_orbit(sun, L[0], randf() * TAU)
		p.update_motion()
		if i == 2:
			home_planet = p
		for m in int(L[3]):
			var moon := _spawn_body(Vector2.ZERO, randf_range(30.0, 50.0), ["rocky", "ice", "lava"].pick_random())
			moon.is_moon = true
			moon.set_orbit(p, p.radius * (3.2 + m * 1.3), randf() * TAU)
			moon.field = moon.radius * 4.0
		if i in station_on:
			var st := Station.new()
			st.mothership = i == 2
			add_child(st)
			st.set_orbit(p, p.radius * (2.4 if i != 2 else 3.0) + (130.0 if i == 2 else 90.0), randf() * TAU)
			if st.mothership:
				stations.push_front(st)
			else:
				stations.append(st)
	var hole := _spawn_body(Vector2(-15500, 12500), 70.0, "hole")
	hole.home = Vector2(-15500, 12500)
	for i in 500:
		var r := randf_range(BELT_IN, BELT_OUT)
		belt_rocks.append([randf() * TAU, r, sqrt(Planet.SUN_MU / pow(r, 3.0)), randf_range(6.0, 22.0), randf() * TAU])
	randomize()


func _spawn_body(pos: Vector2, r: float, kind: String) -> Planet:
	var p := Planet.new()
	p.position = pos
	p.home = pos
	add_child(p)
	move_child(p, 0)
	p.setup(r, kind)
	bodies.append(p)
	return p


func _draw() -> void:
	var w := 3.0 / cam.zoom.x
	for b: Planet in bodies:
		if b.parent != null:
			draw_arc(b.parent.position, b.orbit_r, 0.0, TAU, 256, Color(1, 1, 1, 0.07 if not b.is_moon else 0.05), w)
	var view := Rect2(cam.position - get_viewport_rect().size / cam.zoom / 2.0, get_viewport_rect().size / cam.zoom).grow(100.0)
	for r in belt_rocks:
		var a: float = r[0] + r[2] * Planet.time
		var p := Vector2.from_angle(a) * float(r[1])
		if view.has_point(p):
			draw_circle(p, r[3], Color(0.42, 0.38, 0.36))
			draw_circle(p + Vector2(-0.25, -0.25) * float(r[3]), float(r[3]) * 0.6, Color(0.55, 0.5, 0.46))
	draw_arc(Vector2.ZERO, WARN_R, 0.0, TAU, 512, Color(1.0, 0.3, 0.3, 0.35), 12.0 / cam.zoom.x * 0.3)


func _draw_front() -> void:
	for b: Planet in bodies:
		b.draw_front_ring(front)
	if player.state == "fly" and not over:
		var pts := player.predict(360, 1.0 / 20.0)
		for i in range(0, pts.size(), 4):
			var a := 0.7 * (1.0 - float(i) / pts.size())
			front.draw_circle(pts[i], 4.0 / cam.zoom.x, Color(0.7, 0.9, 1.0, a))
	if player.state != "dead":
		front.draw_arc(player.position, 30.0 / cam.zoom.x, 0.0, TAU, 32, Color(1, 1, 1, clampf(0.3 - cam.zoom.x, 0.0, 0.5) * 2.0), 2.0 / cam.zoom.x)


func _to_screen(p: Vector2) -> Vector2:
	return (p - cam.get_screen_center_position()) * cam.zoom + get_viewport_rect().size / 2.0


func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size
	var fk := player.fuel / player.fuel_max
	var col := Color(0.3, 0.9, 1.0) if fk > 0.25 else Color(1.0, 0.3, 0.25)
	_panel(Rect2(20, 20, 380, 200))
	hud.draw_string(font, Vector2(40, 56), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
	hud.draw_rect(Rect2(110, 38, 270, 22), Color(0, 0, 0, 0.5))
	hud.draw_rect(Rect2(110, 38, 270 * fk, 22), col)
	var hk := player.hull / player.hull_max
	hud.draw_string(font, Vector2(40, 92), "HULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
	hud.draw_rect(Rect2(110, 76, 270, 16), Color(0, 0, 0, 0.5))
	hud.draw_rect(Rect2(110, 76, 270 * clampf(hk, 0.0, 1.0), 16), Color(0.5, 1.0, 0.4) if hk > 0.35 else Color(1.0, 0.45, 0.2))
	hud.draw_string(font, Vector2(40, 128), "DRONES", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.7))
	for i in player.drones_max:
		var filled := i < player.drones
		hud.draw_rect(Rect2(130 + i * 26, 112, 18, 18), Color(0.3, 1.0, 0.8) if filled else Color(0.2, 0.25, 0.3), filled)
	hud.draw_string(font, Vector2(40, 168), "CREDITS  %d" % data.credits, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.4))
	hud.draw_string(font, Vector2(220, 168), "research %d/%d" % [_research_done(), research_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.8, 1.0, 0.8))
	var pend := 0
	for p in pending:
		pend += int(p[2])
	if pend > 0:
		hud.draw_string(font, Vector2(40, 200), "unclaimed research  +%d" % pend, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.5, 1.0, 0.8))
	hud.draw_rect(Rect2(size.x / 2.0 - 420, 10, 840, 104), Color(0.02, 0.04, 0.08, 0.72))
	hud.draw_rect(Rect2(size.x / 2.0 - 420, 10, 840, 104), Color(0.3, 0.9, 0.7, 0.35), false, 1.5)
	hud.draw_string(font, Vector2(0, 44), "SOL SYSTEM", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(1, 1, 1, 0.8))
	var rel := player.vel - player.ref_vel
	hud.draw_string(font, Vector2(0, 74), "speed relative to %s: %d" % [player.ref_name, int(rel.length())], HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, 1, 1, 0.6))
	if player.braking and player.state == "fly":
		hud.draw_string(font, Vector2(0, 124), "BRAKING - matching speed with %s" % player.ref_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1.0, 0.8, 0.4))
	if player.autopilot and player.auto_station != null:
		hud.draw_string(font, Vector2(0, 172), "AUTOPILOT: flying to %s  (F to cancel)" % player.auto_station.sname, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(0.4, 0.9, 1.0))
	if player.tractor:
		hud.draw_string(font, Vector2(0, 148), "DOCKING BEAM LOCKED", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(0.4, 1.0, 0.6))
	_draw_target(font, size)
	if outside_t > 0.0:
		hud.draw_string(font, Vector2(0, size.y / 2.0 - 120), "LEAVING THE SYSTEM - TURN BACK  %.1f" % (10.0 - outside_t), HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(1.0, 0.3, 0.25))
	_draw_minimap(Vector2(size.x - 150, size.y - 190), 130.0)
	hud.draw_string(font, Vector2(24, size.y - 24), "mouse: aim   LMB: boost   S/Shift: brake   F: autopilot to station   RMB/E: drone   T: next target   TAB: missions   M: map   wheel: zoom   Esc: pause   R: respawn", HORIZONTAL_ALIGNMENT_LEFT, 1200, 16, Color(1, 1, 1, 0.4))
	for b: Planet in bodies:
		if b.is_moon and cam.zoom.x < 0.12:
			continue
		var sp := _to_screen(b.position)
		if sp.x < -300 or sp.x > size.x + 300 or sp.y < -300 or sp.y > size.y + 300:
			continue
		var top := sp.y - b.radius * cam.zoom.x * (4.0 if b.is_hole else 1.4) - 14.0
		hud.draw_string(font, Vector2(sp.x - 200, top - 22), b.pname + (" (moon)" if b.is_moon else ""), HORIZONTAL_ALIGNMENT_CENTER, 400, 20, Color(1, 1, 1, 0.85))
		var qt := b.type_name()
		if not b.is_sun:
			qt += ("   -   research %d/3" % b.level) if b.can_drone() else ""
		var qc := Color(0.7, 0.8, 0.95, 0.8)
		if b.survey_active:
			qt = "SURVEY %d/%ds - fly in the green zone" % [int(b.survey_progress), int(b.survey_time)]
			qc = Color(0.5, 1.0, 0.8)
		elif b.drone_active:
			qt = "DRONE MISSION - land a probe (right click)"
			qc = Color(1.0, 0.8, 0.3)
		if b.is_sun:
			qt = ""
		hud.draw_string(font, Vector2(sp.x - 250, top), qt, HORIZONTAL_ALIGNMENT_CENTER, 500, 17, qc)
	for s: Station in stations:
		var sp := _to_screen(s.position)
		if sp.x > 0 and sp.x < size.x and sp.y > 0 and sp.y < size.y:
			hud.draw_string(font, Vector2(sp.x - 200, sp.y - s.dock_r * cam.zoom.x - 30), s.sname + "  (dock slowly)", HORIZONTAL_ALIGNMENT_CENTER, 400, 18, Color(0.4, 1.0, 0.6))
		elif s == _nearest_station():
			var e := Vector2(clampf(sp.x, 40, size.x - 40), clampf(sp.y, 40, size.y - 40))
			var d := (sp - e).normalized()
			hud.draw_colored_polygon(PackedVector2Array([e + d * 18, e + d.orthogonal() * 11, e - d.orthogonal() * 11]), Color(0.35, 1.0, 0.6, 0.9))
			hud.draw_string(font, e - d * 30 + Vector2(-60, 6), "%d m" % int(s.position.distance_to(player.position) / 10.0), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.35, 1.0, 0.6))
	if Input.is_key_pressed(KEY_TAB):
		_draw_quest_log(font, size)
	if paused:
		hud.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
	if player.fuel <= 0.0 and player.state == "fly" and not over:
		hud.draw_string(font, Vector2(0, size.y - 90), "OUT OF FUEL - engines and autopilot are dead, you are drifting. Press R to call a rescue", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1.0, 0.4, 0.3, 0.6 + 0.4 * sin(t * 6.0)))


func _open_quests() -> Array:
	var out := []
	for b: Planet in bodies:
		if b.survey_active or b.drone_active:
			out.append(b)
	return out

func _auto_target() -> void:
	target = null
	var best := INF
	for b: Planet in _open_quests():
		var d := b.position.distance_to(player.position)
		if d < best:
			best = d
			target = b

func _cycle_target() -> void:
	var list := _open_quests()
	list.sort_custom(_closer)
	if list.is_empty():
		return
	var i := list.find(target)
	target = list[(i + 1) % list.size()]
	_play("buy")


func _closer(a: Planet, b: Planet) -> bool:
	return a.position.distance_to(player.position) < b.position.distance_to(player.position)


func _draw_target(font: Font, size: Vector2) -> void:
	if over or player.state == "dead":
		return
	var pos := Vector2.ZERO
	var label := ""
	if target != null:
		pos = target.position
		label = "%s: %s" % [target.pname, "Survey %d/%ds" % [int(target.survey_progress), int(target.survey_time)] if target.survey_active else "Land a drone"]
	else:
		hud.draw_string(font, Vector2(0, 100), "No active missions - dock at a station (F) and pick some in the MISSIONS tab", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1.0, 0.85, 0.3, 0.8))
		return
	hud.draw_string(font, Vector2(0, 100), "TARGET  " + label + "   (%d m)" % int(pos.distance_to(player.position) / 10.0), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1.0, 0.85, 0.3))
	var sp := _to_screen(pos)
	var c := size / 2.0
	var margin := 70.0
	if sp.x < margin or sp.x > size.x - margin or sp.y < margin or sp.y > size.y - margin:
		var d := (sp - c).normalized()
		var e := c + d * minf((size.x / 2.0 - margin) / maxf(absf(d.x), 0.001), (size.y / 2.0 - margin) / maxf(absf(d.y), 0.001))
		var pulse := 1.0 + 0.15 * sin(t * 6.0)
		hud.draw_colored_polygon(PackedVector2Array([e + d * 26 * pulse, e + d.orthogonal() * 15, e - d * 6, e - d.orthogonal() * 15]), Color(1.0, 0.85, 0.2, 0.95))
	else:
		var r := 34.0 + 4.0 * sin(t * 5.0)
		for k in 4:
			var a := k * PI / 2.0 + t
			hud.draw_arc(sp, r, a, a + 0.8, 8, Color(1.0, 0.85, 0.2, 0.9), 3.0)


func _draw_quest_log(font: Font, size: Vector2) -> void:
	var list := _open_quests()
	list.sort_custom(_closer)
	var h := 130.0 + 30.0 * maxi(list.size(), 1)
	var r := Rect2(size.x / 2.0 - 380, size.y / 2.0 - h / 2.0, 760, h)
	hud.draw_rect(r, Color(0.03, 0.06, 0.1, 0.92))
	hud.draw_rect(r, Color(0.3, 0.9, 0.7, 0.7), false, 2.0)
	hud.draw_string(font, r.position + Vector2(0, 44), "ACTIVE MISSIONS  %d / %d" % [list.size(), MAX_ACTIVE], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color(0.5, 1.0, 0.8))
	var y := r.position.y + 90.0
	var mult := _reward_mult()
	if list.is_empty():
		hud.draw_string(font, Vector2(r.position.x, y), "None yet - pick missions at any station (MISSIONS tab)", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(1, 1, 1, 0.7))
	for b: Planet in list:
		var col := Color(1.0, 0.85, 0.3) if b == target else Color(1, 1, 1, 0.85)
		var kinds := []
		var rw := 0
		if b.survey_active:
			kinds.append("Survey %d/%ds" % [int(b.survey_progress), int(b.survey_time)])
			rw += int(b.survey_reward * mult)
		if b.drone_active:
			kinds.append("Drone Lv%d" % (b.level + 1))
			rw += int(b.drone_reward(b.level) * mult)
		hud.draw_string(font, Vector2(r.position.x + 30, y), b.pname, HORIZONTAL_ALIGNMENT_LEFT, 200, 18, col)
		hud.draw_string(font, Vector2(r.position.x + 230, y), " + ".join(kinds), HORIZONTAL_ALIGNMENT_LEFT, 300, 18, col)
		hud.draw_string(font, Vector2(r.position.x + 560, y), "+%d cr   %d m" % [rw, int(b.position.distance_to(player.position) / 10.0)], HORIZONTAL_ALIGNMENT_LEFT, 180, 18, col)
		y += 30.0
	hud.draw_string(font, Vector2(r.position.x, r.end.y - 18), "T switches target", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(1, 1, 1, 0.5))

func _tick_tutorial(delta: float) -> void:
	if tut.is_empty() or player.state != "fly":
		return
	tut_t -= delta
	if tut_t <= 0.0:
		_toast(tut.pop_front())
		tut_t = 6.0


func _on_bumped(amount: float) -> void:
	shake = 0.7
	_play("boom")
	_burst(player.position, Color(1.5, 0.8, 0.4), 16, 250.0)
	_toast("HULL DAMAGED  -%d   (approach planets slower!)" % int(amount))


func _nearest_body() -> Planet:
	var best: Planet = sun
	var bd := INF
	for b: Planet in bodies:
		var d := (b.position.distance_to(player.position) - b.radius) / maxf(b.radius, 1.0)
		if b.is_sun:
			d = player.position.length() / 3000.0 + 3.0
		if d < bd:
			bd = d
			best = b
	return best


func _nearest_station() -> Station:
	var best: Station = stations[0]
	for s: Station in stations:
		if s.position.distance_to(player.position) < best.position.distance_to(player.position):
			best = s
	return best


func _draw_minimap(c: Vector2, r: float) -> void:
	var font := ThemeDB.fallback_font
	hud.draw_circle(c, r + 10.0, Color(0.02, 0.04, 0.08, 0.85))
	hud.draw_arc(c, r + 10.0, 0.0, TAU, 64, Color(0.3, 0.9, 0.7, 0.5), 2.0)
	var k := r / WORLD_R
	hud.draw_arc(c, WARN_R * k, 0.0, TAU, 64, Color(1.0, 0.3, 0.3, 0.4), 1.0)
	hud.draw_arc(c, (BELT_IN + BELT_OUT) / 2.0 * k, 0.0, TAU, 64, Color(0.6, 0.55, 0.5, 0.5), (BELT_OUT - BELT_IN) * k)
	for b: Planet in bodies:
		if b.is_moon:
			continue
		if b.parent == sun:
			hud.draw_arc(c, b.orbit_r * k, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 1.0)
		var col: Color = Color(2.0, 1.2, 0.4) if b.is_sun else (Color(0.8, 0.4, 1.0) if b.is_hole else (b.colors[2] as Color))
		hud.draw_circle(c + b.position * k, 5.0 if b.is_sun else 3.0, col)
		if b.survey_active or b.drone_active:
			hud.draw_arc(c + b.position * k, 6.5, 0.0, TAU, 12, Color(1.0, 0.85, 0.3, 0.9), 1.5)
	for s: Station in stations:
		hud.draw_rect(Rect2(c + s.position * k - Vector2(2, 2), Vector2(4, 4)), Color(0.35, 1.0, 0.6))
	var pp := c + player.position * k
	hud.draw_colored_polygon(PackedVector2Array([pp + Vector2.from_angle(player.rotation) * 7, pp + Vector2.from_angle(player.rotation + 2.5) * 5, pp + Vector2.from_angle(player.rotation - 2.5) * 5]), Color.WHITE)
	hud.draw_string(font, c + Vector2(-r, r + 30), "yellow ring = active mission", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 12, Color(1, 1, 1, 0.5))


func _panel(r: Rect2) -> void:
	hud.draw_rect(r, Color(0.03, 0.06, 0.1, 0.7))
	hud.draw_rect(r, Color(0.3, 0.9, 0.7, 0.5), false, 2.0)


func _make_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	ui.add_child(hud)
	toast_l = _label(ui, "", 24, Vector2(0, 740), Color(0.5, 1.0, 0.8))
	msg_l = _label(ui, "", 40, Vector2(0, 260), Color.WHITE)
	pause_l = _label(ui, "PAUSED\n\nEsc to resume\n\nmouse: aim  -  LMB: boost  -  S / Shift: brake  -  F: autopilot to station\nRMB / E: drop probe  -  T: next target  -  TAB: active missions\nM: system map  -  wheel: zoom  -  R: respawn  -  F11: fullscreen", 30, Vector2(0, 250), Color.WHITE)
	pause_l.visible = false


func _label(parent: Node, text: String, size: int, pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(get_viewport_rect().size.x, 400)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


func _toast(text: String) -> void:
	toast_l.text = text
	toast_t = 4.0


func _make_background() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -2
	add_child(bg)
	nebula = ColorRect.new()
	nebula.set_anchors_preset(Control.PRESET_FULL_RECT)
	nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = nebula_shader()
	mat.shader = sh
	nebula.material = mat
	bg.add_child(nebula)
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	stars_node = Node2D.new()
	layer.add_child(stars_node)
	for i in 350:
		stars.append([Vector2(randf() * 2600.0, randf() * 1600.0), randf_range(0.01, 0.08), randf_range(0.8, 2.4)])
	stars_node.draw.connect(_draw_stars)


func _draw_stars() -> void:
	var size: Vector2 = get_viewport_rect().size
	for s in stars:
		var x: float = fposmod(s[0].x - cam.position.x * s[1], 2600.0)
		var y: float = fposmod(s[0].y - cam.position.y * s[1], 1600.0)
		if x < size.x and y < size.y:
			var a: float = 0.3 + 0.7 * s[1] / 0.08
			stars_node.draw_circle(Vector2(x, y), s[2], Color(0.85, 0.9, 1.0, a))


func _make_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _burst(at: Vector2, col: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.6
	p.damping_max = speed
	p.scale_amount_min = 8.0
	p.scale_amount_max = 16.0
	p.color = col
	add_child(p)
	p.finished.connect(p.queue_free)


func _make_sounds() -> void:
	snd.thrust = _tone(120.0, 90.0, 0.12, "noise", 0.1)
	snd.dock = _tone(440.0, 880.0, 0.35, "sine", 0.4)
	snd.launch = _tone(200.0, 600.0, 0.4, "noise", 0.3)
	snd.research = _tone(660.0, 1320.0, 0.3, "sine", 0.35)
	snd.drone = _tone(900.0, 500.0, 0.15, "sine", 0.25)
	snd.buy = _tone(520.0, 1040.0, 0.12, "sine", 0.35)
	snd.boom = _tone(160.0, 40.0, 0.8, "noise", 0.6)
	var loop := _tone(70.0, 70.0, 1.0, "noise", 0.22, true)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = 22050
	engine_snd = AudioStreamPlayer.new()
	engine_snd.stream = loop
	engine_snd.volume_db = -60.0
	add_child(engine_snd)
	engine_snd.play()
	for i in 8:
		var a := AudioStreamPlayer.new()
		a.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(a)
		players.append(a)


func _tone(f0: float, f1: float, dur: float, wave: String, vol: float, flat: bool = false) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(f0, f1, k) / rate
		var s := 0.0
		match wave:
			"sine": s = sin(phase)
			"noise": s = randf_range(-1.0, 1.0) * (0.5 + 0.5 * sin(phase))
		s *= vol if flat else vol * (1.0 - k) * minf(1.0, i / 200.0)
		bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = bytes
	return w


func _play(name: String) -> void:
	for a: AudioStreamPlayer in players:
		if not a.playing:
			a.stream = snd[name]
			a.pitch_scale = randf_range(0.95, 1.05)
			a.play()
			return


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://orbit_v3.save") == OK:
		data.credits = cf.get_value("save", "credits", 0)
		data.best = cf.get_value("save", "best", 0)
		data.research = cf.get_value("save", "research", {})
		data.surveyed = cf.get_value("save", "surveyed", [])
		data.active = cf.get_value("save", "active", [])
		data.tutorial = cf.get_value("save", "tutorial", false)
		var lv: Dictionary = cf.get_value("save", "levels", {})
		for k in data.levels:
			data.levels[k] = int(lv.get(k, 0))


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("save", "credits", data.credits)
	cf.set_value("save", "best", data.best)
	cf.set_value("save", "levels", data.levels)
	cf.set_value("save", "research", data.research)
	cf.set_value("save", "surveyed", data.surveyed)
	cf.set_value("save", "active", data.active)
	cf.set_value("save", "tutorial", data.tutorial)
	cf.save("user://orbit_v3.save")


static func nebula_shader() -> String:
	var L := PackedStringArray()
	L.append("shader_type canvas_item;")
	L.append("uniform vec2 offset;")
	L.append("float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }")
	L.append("float noise(vec2 p) {")
	L.append("\tvec2 i = floor(p); vec2 f = fract(p);")
	L.append("\tvec2 u = f * f * (3.0 - 2.0 * f);")
	L.append("\treturn mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);")
	L.append("}")
	L.append("float fbm(vec2 p) {")
	L.append("\tfloat v = 0.0; float a = 0.5;")
	L.append("\tfor (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.0; a *= 0.5; }")
	L.append("\treturn v;")
	L.append("}")
	L.append("void fragment() {")
	L.append("\tvec2 p = UV * vec2(2.2, 1.25) + offset;")
	L.append("\tfloat n1 = fbm(p * 1.3);")
	L.append("\tfloat n2 = fbm(p * 2.1 + 17.0);")
	L.append("\tvec3 col = vec3(0.012, 0.012, 0.035);")
	L.append("\tcol += vec3(0.25, 0.08, 0.35) * smoothstep(0.45, 0.85, n1) * 0.55;")
	L.append("\tcol += vec3(0.05, 0.2, 0.35) * smoothstep(0.5, 0.9, n2) * 0.6;")
	L.append("\tCOLOR = vec4(col, 1.0);")
	L.append("}")
	return "\n".join(L)
