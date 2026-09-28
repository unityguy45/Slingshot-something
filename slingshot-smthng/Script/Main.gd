extends Node2D

const BAND := 1500.0
const ZOOM := 0.7

var cam: Camera2D
var player: Player
var planets: Array = []
var stations: Array = []
var next_x := 700.0
var since_station := 0
var scroll_speed := 60.0
var cam_x := 0.0
var score := 0
var best := 0
var over := false
var started := false
var t := 0.0
var shake := 0.0
var thrust_snd_t := 0.0

var ui: CanvasLayer
var hud: Control
var score_l: Label
var msg_l: Label
var info_l: Label
var stars_node: Node2D
var stars: Array = []
var snd := {}
var players: Array = []


func _ready() -> void:
	randomize()
	_load_best()
	_make_glow()
	_make_stars()
	_make_sounds()
	cam = Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(cam)
	player = Player.new()
	player.planets = planets
	player.stations = stations
	player.position = Vector2(0, 0)
	add_child(player)
	player.died.connect(_on_died)
	player.docked.connect(_on_docked)
	var first := _spawn_planet(Vector2(750, 260), 95.0)
	first.vel = Vector2(40, 0)
	next_x = 1500.0
	_fill()
	_make_ui()
	get_tree().paused = false
	player.set_physics_process(false)


func _half_view() -> Vector2:
	return get_viewport_rect().size / ZOOM / 2.0


func _unhandled_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE)
	if e is InputEventKey and e.pressed and e.keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if not tap:
		return
	if over:
		get_tree().reload_current_scene()
	elif not started:
		started = true
		msg_l.text = ""
		player.set_physics_process(true)


func _process(delta: float) -> void:
	t += delta
	var hv := _half_view()
	if started and not over:
		scroll_speed = minf(60.0 + t * 1.2, 190.0)
		cam_x += scroll_speed * delta
		cam_x = maxf(cam_x, player.position.x - hv.x * 0.35)
		score = maxi(score, int(player.position.x / 100.0))
		score_l.text = "%d km" % score
		if player.position.x < cam_x - hv.x - 40.0:
			_on_died("Left behind")
		elif absf(player.position.y) > BAND:
			_on_died("Lost in deep space")
		if player.thrusting:
			thrust_snd_t -= delta
			if thrust_snd_t <= 0.0:
				thrust_snd_t = 0.09
				_play("thrust")
	var target_y := clampf(player.position.y, -BAND + hv.y * 0.6, BAND - hv.y * 0.6)
	cam.position = Vector2(cam_x, lerpf(cam.position.y, target_y, 1.0 - exp(-4.0 * delta)))
	_fill()
	_cleanup()
	shake = maxf(0.0, shake - delta * 2.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 30.0
	info_l.text = "speed %d" % int(player.vel.length())
	stars_node.queue_redraw()
	hud.queue_redraw()
	queue_redraw()


func _fill() -> void:
	while next_x < cam_x + _half_view().x + 2500.0:
		var r := randf_range(40.0, 140.0)
		var y := randf_range(-BAND + 350.0, BAND - 350.0)
		var p := _spawn_planet(Vector2(next_x, y), r)
		p.vel = Vector2(randf_range(20.0, 90.0), randf_range(-25.0, 25.0))
		var gap := r * 3.5 + randf_range(350.0, 650.0)
		since_station += 1
		if since_station >= randi_range(3, 4):
			since_station = 0
			var st := Station.new()
			var sy := clampf(y + (700.0 if y < 0.0 else -700.0) * randf_range(0.5, 1.0), -BAND + 250.0, BAND - 250.0)
			st.position = Vector2(next_x + gap * 0.5, sy)
			add_child(st)
			stations.append(st)
		next_x += gap


func _spawn_planet(pos: Vector2, r: float) -> Planet:
	var p := Planet.new()
	p.setup(r)
	p.position = pos
	add_child(p)
	move_child(p, 0)
	planets.append(p)
	return p


func _cleanup() -> void:
	var limit := cam_x - _half_view().x - 1500.0
	for p: Planet in planets.duplicate():
		if p.position.x < limit:
			planets.erase(p)
			p.queue_free()
	for s: Station in stations.duplicate():
		if s.position.x < limit:
			stations.erase(s)
			s.queue_free()


func _on_docked(_s: Station) -> void:
	_play("dock")
	_burst(player.position, Color(0.4, 1.6, 0.8), 24, 260.0)
	msg_l.text = "DOCKED - refuelling\nhold to launch when full"
	get_tree().create_timer(2.0).timeout.connect(func() -> void: if not over: msg_l.text = "")


func _on_died(reason: String) -> void:
	if over:
		return
	over = true
	player.state = "dead"
	player.queue_redraw()
	player.trail.clear_points()
	shake = 1.0
	_play("boom")
	_burst(player.position, Color(2.5, 1.2, 0.5), 50, 500.0)
	var new_best := score > best
	if new_best:
		best = score
		_save_best()
	msg_l.text = "%s\n\n%d km%s\n\nclick to fly again" % [reason, score, "  NEW BEST!" if new_best else ""]


func _draw() -> void:
	var hv := _half_view()
	var left := cam_x - hv.x
	for y in [-BAND, BAND]:
		draw_line(Vector2(left, y), Vector2(left + hv.x * 2.0, y), Color(1.0, 0.25, 0.25, 0.35), 4.0)
	if started and not over:
		var pts := player.predict(150, 1.0 / 30.0)
		for i in range(0, pts.size(), 3):
			var a := 0.55 * (1.0 - float(i) / pts.size())
			draw_circle(pts[i], 3.0, Color(0.7, 0.9, 1.0, a))
	var danger := clampf(1.0 - (player.position.x - left) / 500.0, 0.0, 1.0)
	if danger > 0.0 and not over:
		draw_rect(Rect2(left, cam.position.y - hv.y, 60.0, hv.y * 2.0), Color(1.0, 0.1, 0.1, 0.35 * danger))


func _draw_hud() -> void:
	var fk := player.fuel / Player.FUEL_MAX
	var col := Color(0.3, 0.9, 1.0) if fk > 0.25 else Color(1.0, 0.3, 0.25)
	hud.draw_rect(Rect2(30, 30, 304, 26), Color(0, 0, 0, 0.6))
	hud.draw_rect(Rect2(32, 32, 300 * fk, 22), col)
	hud.draw_string(ThemeDB.fallback_font, Vector2(340, 51), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
	var size := get_viewport_rect().size
	for s: Station in stations:
		if s.used:
			continue
		var sp := (s.position - cam.get_screen_center_position()) * ZOOM + size / 2.0
		if sp.x > size.x or sp.y < 0 or sp.y > size.y:
			var e := Vector2(clampf(sp.x, 40, size.x - 40), clampf(sp.y, 40, size.y - 40))
			var d := (sp - e).normalized()
			hud.draw_colored_polygon(PackedVector2Array([e + d * 14, e + d.orthogonal() * 9, e - d.orthogonal() * 9]), Color(0.35, 1.0, 0.6, 0.8))
			break


func _make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	ui.add_child(hud)
	score_l = _label("0 km", 44, Vector2(0, 20))
	info_l = _label("", 20, Vector2(0, 80))
	info_l.modulate.a = 0.6
	var b := _label("BEST %d km" % best, 20, Vector2(0, 110))
	b.modulate.a = 0.6
	msg_l = _label("ORBIT BREAKER\n\nyour ship points at the cursor  -  hold click to boost\nfuel is tiny: use planet gravity to slingshot\ndock slowly at green stations to refuel\ndon't get left behind\n\nclick to launch", 30, Vector2(0, 520))


func _label(text: String, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(get_viewport_rect().size.x, 400)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	ui.add_child(l)
	return l


func _make_stars() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	stars_node = Node2D.new()
	layer.add_child(stars_node)
	for i in 260:
		stars.append([Vector2(randf() * 2600.0, randf() * 1600.0), randf_range(0.03, 0.25), randf_range(1.0, 2.6)])
	stars_node.draw.connect(_draw_stars)


func _draw_stars() -> void:
	var size: Vector2 = get_viewport_rect().size
	for s in stars:
		var x: float = fposmod(s[0].x - cam.position.x * s[1], 2600.0)
		var y: float = fposmod(s[0].y - cam.position.y * s[1], 1600.0)
		if x < size.x and y < size.y:
			var a: float = 0.3 + 0.7 * s[1] / 0.25
			stars_node.draw_circle(Vector2(x, y), s[2], Color(0.8, 0.85, 1.0, a))


func _make_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
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
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.6
	p.damping_max = speed
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = col
	add_child(p)
	p.finished.connect(p.queue_free)


func _make_sounds() -> void:
	snd.thrust = _tone(120.0, 90.0, 0.12, "noise", 0.12)
	snd.dock = _tone(440.0, 880.0, 0.35, "sine", 0.4)
	snd.boom = _tone(160.0, 40.0, 0.7, "noise", 0.6)
	for i in 8:
		var a := AudioStreamPlayer.new()
		add_child(a)
		players.append(a)


func _tone(f0: float, f1: float, dur: float, wave: String, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(f0, f1, k) / rate
		var s := 0.0
		match wave:
			"sine": s = sin(phase)
			"noise": s = randf_range(-1.0, 1.0) * (0.5 + 0.5 * sin(phase))
		s *= vol * (1.0 - k) * minf(1.0, i / 200.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _play(name: String) -> void:
	for a: AudioStreamPlayer in players:
		if not a.playing:
			a.stream = snd[name]
			a.pitch_scale = randf_range(0.95, 1.05)
			a.play()
			return


func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://orbit.save") == OK:
		best = cf.get_value("score", "best", 0)


func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("score", "best", best)
	cf.save("user://orbit.save")
