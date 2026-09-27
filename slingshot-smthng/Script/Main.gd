extends Node2D

const W := 720.0

var cam: Camera2D
var player: Player
var planets: Array = []
var shards: Array = []
var top_y := 0.0
var last_x := 360.0
var score := 0
var best := 0
var over := false
var started := false
var t := 0.0
var shake := 0.0

var ui: CanvasLayer
var score_l: Label
var best_l: Label
var msg_l: Label
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
	cam.position = Vector2(W / 2.0, 640.0)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	add_child(cam)
	var first := _spawn_planet(Vector2(W / 2.0, 900.0), 95.0, false)
	top_y = first.position.y
	player = Player.new()
	player.planets = planets
	add_child(player)
	player.captured.connect(_on_captured)
	player.died.connect(_on_died)
	_make_ui()
	first.visited = true
	player.attach(first, -PI / 2.0, 1.0)
	player.fuse_len = 999.0
	_fill_planets()


func _unhandled_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventScreenTouch and e.pressed) \
		or (e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_SPACE, KEY_ENTER, KEY_UP, KEY_W])
	if not tap:
		return
	if over:
		get_tree().reload_current_scene()
		return
	if not started:
		started = true
		msg_l.text = ""
	if player.state == "orbit":
		player.release()
		_play("whoosh")
		_burst(player.position, Color(0.6, 1.6, 2.0), 10, 160.0)


func _process(delta: float) -> void:
	t += delta
	if not over:
		var target_y := minf(cam.position.y, player.position.y - 180.0)
		cam.position.y = target_y
		_fill_planets()
		_cleanup()
		_check_shards()
		var half_w := get_viewport_rect().size.x / 2.0
		var bottom := cam.get_screen_center_position().y + get_viewport_rect().size.y / 2.0
		if player.state == "fly" and (player.position.y > bottom + 40.0 or absf(player.position.x - W / 2.0) > half_w + 60.0):
			player._die()
	shake = maxf(0.0, shake - delta * 2.5)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 18.0
	stars_node.queue_redraw()
	queue_redraw()


func _difficulty() -> float:
	return minf(score / 12.0, 3.0)


func _fill_planets() -> void:
	var view_top := cam.position.y - 1400.0
	while top_y > view_top:
		var d := _difficulty()
		var gap := randf_range(250.0, 330.0) + d * 25.0
		var y := top_y - gap
		var x := clampf(last_x + randf_range(-300.0, 300.0), 130.0, W - 130.0)
		var orbit := clampf(randf_range(75.0, 110.0) - d * 8.0, 58.0, 110.0)
		var p := _spawn_planet(Vector2(x, y), orbit, false)
		if randf() < minf(0.12 * d, 0.45):
			p.move_amp = randf_range(60.0, 140.0)
			p.move_speed = randf_range(0.8, 1.6)
		if randf() < 0.6:
			var mid := Vector2((x + last_x) / 2.0, y + gap / 2.0) + Vector2(randf_range(-80, 80), 0)
			shards.append({"pos": mid, "alive": true})
		if randf() < minf(0.1 + 0.12 * d, 0.5):
			var sx := 110.0 if x > W / 2.0 else W - 110.0
			_spawn_planet(Vector2(sx, y + gap * 0.5), 0.0, true)
		top_y = y
		last_x = x


func _spawn_planet(pos: Vector2, orbit: float, sun: bool) -> Planet:
	var p := Planet.new()
	p.position = pos
	p.is_sun = sun
	if sun:
		p.radius = randf_range(26.0, 40.0)
	else:
		p.orbit_r = orbit
		p.radius = orbit * randf_range(0.35, 0.5)
		p.color = Color.from_hsv(randf(), 0.55, 1.0)
	add_child(p)
	move_child(p, 0)
	planets.append(p)
	return p


func _cleanup() -> void:
	var limit := cam.position.y + 1100.0
	for p: Planet in planets.duplicate():
		if p.position.y > limit and p != player.planet:
			planets.erase(p)
			p.queue_free()
	shards = shards.filter(func(s): return s.alive and s.pos.y < limit)


func _check_shards() -> void:
	for s in shards:
		if s.alive and s.pos.distance_to(player.position) < 30.0:
			s.alive = false
			score += 1
			_update_score()
			_play("shard")
			_burst(s.pos, Color(2.5, 2.2, 0.6), 14, 200.0)


func _on_captured(p: Planet) -> void:
	player.fuse_len = maxf(4.0 - _difficulty() * 0.7, 1.8)
	if p.visited:
		return
	p.visited = true
	score += 1
	_update_score()
	_play("catch")
	shake = 0.35
	_burst(player.position, p.color * 1.8, 16, 220.0)


func _on_died() -> void:
	over = true
	shake = 1.0
	_play("boom")
	_burst(player.position, Color(2.5, 1.2, 0.5), 40, 420.0)
	player.trail.clear_points()
	var new_best := score > best
	if new_best:
		best = score
		_save_best()
	msg_l.text = ("NEW BEST!\n" if new_best else "") + "Score %d\n\ntap to retry" % score
	best_l.text = "BEST %d" % best


func _update_score() -> void:
	score_l.text = str(score)
	var tw := create_tween()
	score_l.scale = Vector2(1.3, 1.3)
	tw.tween_property(score_l, "scale", Vector2.ONE, 0.2)


func _draw() -> void:
	for s in shards:
		if not s.alive:
			continue
		var r := 9.0 + sin(t * 6.0 + s.pos.x) * 2.0
		var pts := PackedVector2Array()
		for i in 8:
			var a := TAU * i / 8.0 + t * 1.5
			pts.append(s.pos + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.4))
		draw_colored_polygon(pts, Color(2.6, 2.2, 0.7))


func _make_stars() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	stars_node = Node2D.new()
	layer.add_child(stars_node)
	for i in 160:
		stars.append([Vector2(randf() * 1400.0, randf() * 1400.0), randf_range(0.05, 0.35), randf_range(1.0, 2.6)])
	stars_node.draw.connect(_draw_stars)


func _draw_stars() -> void:
	var size: Vector2 = get_viewport_rect().size
	for s in stars:
		var y: float = fposmod(s[0].y - cam.position.y * s[1], 1400.0)
		var x: float = fposmod(s[0].x, 1400.0)
		if x < size.x and y < size.y:
			var a: float = 0.4 + 0.6 * s[1] / 0.35
			stars_node.draw_circle(Vector2(x, y), s[2], Color(0.8, 0.85, 1.0, a))


func _make_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.1
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	score_l = _label("0", 96, Vector2(0, 60))
	score_l.pivot_offset = Vector2(get_viewport_rect().size.x / 2.0, 60)
	best_l = _label("BEST %d" % best, 28, Vector2(0, 180))
	best_l.modulate.a = 0.6
	msg_l = _label("ORBIT BREAKER\n\ntap to let go\ncatch the next orbit", 40, Vector2(0, 420))


func _label(text: String, size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(get_viewport_rect().size.x, 400)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	ui.add_child(l)
	return l


func _burst(at: Vector2, col: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.2
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = col
	add_child(p)
	p.finished.connect(p.queue_free)


func _make_sounds() -> void:
	snd.whoosh = _tone(300.0, 900.0, 0.18, "noise", 0.35)
	snd.catch = _tone(520.0, 1040.0, 0.15, "sine", 0.4)
	snd.shard = _tone(1200.0, 1800.0, 0.12, "square", 0.18)
	snd.boom = _tone(160.0, 40.0, 0.6, "noise", 0.6)
	for i in 6:
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
			"square": s = 1.0 if sin(phase) > 0.0 else -1.0
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
