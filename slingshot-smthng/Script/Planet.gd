class_name Planet
extends Node2D

const KINDS := ["rocky", "gas", "ice", "lava", "ocean", "sun"]
const SUN_MU := 700000000.0

static var time := 0.0

var kind := "rocky"
var is_hole := false
var radius := 80.0
var mu := 0.0
var field := 0.0
var vel := Vector2.ZERO
var home := Vector2.ZERO
var parent: Planet
var orbit_r := 0.0
var orbit_a0 := 0.0
var omega := 0.0
var is_sun := false
var is_moon := false
var pname := ""
var colors: Array = []
var ring_col := Color.WHITE
var has_ring := false
var ring_tilt := 0.0
var t := randf() * 10.0

var survey_reward := 0
var drone_base := 0
var survey_time := 6.0
var survey_progress := 0.0
var survey_active := false
var drone_active := false
var level := 0
var surveyed := false


func setup(r: float, k: String) -> void:
	kind = k
	is_hole = k == "hole"
	is_sun = k == "sun"
	radius = r
	pname = _make_name()
	if is_sun:
		mu = SUN_MU
		field = INF
		colors = palette(k)
		pname = "Sol"
	elif is_hole:
		mu = 5.0 * pow(r * 2.4, 3.0)
		field = r * 16.0
		survey_reward = 180
		survey_time = 5.0
	else:
		mu = 5.0 * r * r * r
		field = r * 5.5
		colors = palette(k)
		ring_col = (colors[2] as Color).lightened(0.2)
		has_ring = (k == "gas" and randf() < 0.7) or randf() < 0.15
		ring_tilt = randf_range(-0.5, 0.5)
		var bonus := {"rocky": 0, "ice": 15, "ocean": 20, "lava": 25, "gas": 30}
		survey_reward = 30 + int(radius * 0.2) + int(bonus.get(k, 0)) + randi_range(0, 15)
		drone_base = 35 + int(radius * 0.25) + int(bonus.get(k, 0)) + randi_range(0, 15)
		survey_time = 4.0 + radius / 60.0
	_make_visual()


func set_orbit(p: Planet, r: float, a0: float) -> void:
	parent = p
	orbit_r = r
	orbit_a0 = a0
	omega = sqrt(p.mu / pow(r, 3.0))


func pos_at(tt: float) -> Vector2:
	if parent == null:
		return home
	return parent.pos_at(tt) + Vector2.from_angle(orbit_a0 + omega * tt) * orbit_r


func update_motion() -> void:
	position = pos_at(time)
	vel = (pos_at(time + 0.05) - position) / 0.05


func can_drone() -> bool:
	return not is_hole and not is_sun


func drone_reward(lvl: int) -> int:
	return drone_base * (lvl + 1)


func type_name() -> String:
	if is_hole:
		return "Black hole"
	if is_moon:
		return "Moon (%s)" % kind
	match kind:
		"gas": return "Gas giant"
		"ocean": return "Ocean world"
		"lava": return "Lava world"
		"ice": return "Ice world"
	return "Rocky world"


func orbit_band() -> Vector2:
	if is_hole:
		return Vector2(radius * 2.5, field * 0.5)
	return Vector2(radius * 1.2, radius * 4.5)


func _make_name() -> String:
	var a := ["Ka", "Ve", "Tor", "Xy", "Lu", "Or", "Zen", "Mi", "Ar", "Qu", "Sol", "Ny", "Ixi", "Dra", "Hel"]
	var b := ["ros", "nia", "tar", "lon", "via", "rix", "mus", "dor", "phe", "ta", "gon", "lia"]
	if is_hole:
		return "Void %s-%d" % [["A", "B", "K", "X", "Z"].pick_random(), randi_range(10, 99)]
	return "%s%s %s" % [a.pick_random(), b.pick_random(), ["I", "II", "III", "IV", "V", "b", "c"].pick_random()]


func _make_visual() -> void:
	var rect := ColorRect.new()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	if is_hole:
		sh.code = hole_shader()
		rect.size = Vector2.ONE * radius * 8.0
	else:
		sh.code = planet_shader()
		mat.set_shader_parameter("col_a", colors[0])
		mat.set_shader_parameter("col_b", colors[1])
		mat.set_shader_parameter("col_c", colors[2])
		mat.set_shader_parameter("kind", KINDS.find(kind))
		mat.set_shader_parameter("seed", randf() * 100.0)
		mat.set_shader_parameter("spin", randf_range(0.01, 0.04) * (1.0 if randf() < 0.5 else -1.0))
		rect.size = Vector2.ONE * radius * 2.6
		if is_sun:
			mat.set_shader_parameter("spin", 0.01)
	mat.shader = sh
	rect.material = mat
	rect.position = -rect.size / 2.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func gravity_at(p: Vector2) -> Vector2:
	return gravity_from(position, p)


func gravity_from(center: Vector2, p: Vector2) -> Vector2:
	var d := center - p
	var dist := d.length()
	if is_sun:
		return d / dist * mu / maxf(dist * dist, radius * radius)
	if dist > field or dist < 1.0:
		return Vector2.ZERO
	var fade := clampf((field - dist) / (field * 0.25), 0.0, 1.0)
	return d / dist * mu / maxf(dist * dist, radius * radius) * fade


func kill_radius() -> float:
	return radius * 1.05 if is_hole else radius


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if is_sun:
		for i in 4:
			draw_circle(Vector2.ZERO, radius * (1.3 + i * 0.35), Color(1.0, 0.6, 0.2, 0.08 - i * 0.015))
		return
	var c: Color = Color(1.0, 0.6, 0.3) if is_hole else (colors[2] as Color)
	for i in 3:
		var rr := field * (0.4 + 0.3 * i)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 128, Color(c.r, c.g, c.b, 0.18 - i * 0.05), 4.0, true)
	if survey_active:
		var band := orbit_band()
		draw_arc(Vector2.ZERO, (band.x + band.y) / 2.0, 0.0, TAU, 128, Color(0.4, 1.0, 0.7, 0.08), band.y - band.x)
		draw_arc(Vector2.ZERO, band.x, 0.0, TAU, 128, Color(0.4, 1.0, 0.7, 0.4), 3.0, true)
		draw_arc(Vector2.ZERO, band.y, 0.0, TAU, 128, Color(0.4, 1.0, 0.7, 0.4), 3.0, true)
		if survey_progress > 0.0:
			draw_arc(Vector2.ZERO, band.y + 12.0, -PI / 2.0, -PI / 2.0 + TAU * survey_progress / survey_time, 96, Color(0.5, 1.6, 0.9), 10.0, true)
	if drone_active:
		var p := 0.5 + 0.5 * sin(t * 4.0)
		draw_arc(Vector2.ZERO, radius * (1.25 + 0.1 * p), 0.0, TAU, 64, Color(1.6, 1.2, 0.3, 0.8), 5.0, true)
	if has_ring:
		draw_set_transform(Vector2.ZERO, ring_tilt, Vector2(1.0, 0.26))
		for k in 3:
			draw_arc(Vector2.ZERO, radius * (1.55 + k * 0.22), PI, TAU, 64, Color(ring_col.r, ring_col.g, ring_col.b, 0.5 - k * 0.12), radius * 0.12)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_front_ring(canvas: CanvasItem) -> void:
	if not has_ring:
		return
	canvas.draw_set_transform(position, ring_tilt, Vector2(1.0, 0.26))
	for k in 3:
		canvas.draw_arc(Vector2.ZERO, radius * (1.55 + k * 0.22), 0.0, PI, 64, Color(ring_col.r, ring_col.g, ring_col.b, 0.55 - k * 0.12), radius * 0.12)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func palette(k: String) -> Array:
	if k == "rocky":
		return [Color(0.55, 0.45, 0.38), Color(0.32, 0.26, 0.22), Color(0.8, 0.6, 0.45)]
	if k == "gas":
		return [Color(0.85, 0.65, 0.4), Color(0.6, 0.35, 0.25), Color(0.95, 0.85, 0.7)]
	if k == "ice":
		return [Color(0.8, 0.9, 1.0), Color(0.45, 0.65, 0.85), Color(0.6, 0.85, 1.0)]
	if k == "lava":
		return [Color(0.18, 0.1, 0.1), Color(2.2, 0.7, 0.15), Color(1.0, 0.35, 0.1)]
	if k == "ocean":
		return [Color(0.12, 0.3, 0.65), Color(0.25, 0.55, 0.25), Color(0.5, 0.75, 1.0)]
	if k == "sun":
		return [Color(1.6, 0.9, 0.3), Color(2.2, 1.6, 0.7), Color(2.0, 0.9, 0.3)]
	return [Color.WHITE, Color.GRAY, Color.WHITE]


static func planet_shader() -> String:
	var L := PackedStringArray()
	L.append("shader_type canvas_item;")
	L.append("uniform vec3 col_a;")
	L.append("uniform vec3 col_b;")
	L.append("uniform vec3 col_c;")
	L.append("uniform int kind = 0;")
	L.append("uniform float seed = 0.0;")
	L.append("uniform float spin = 0.02;")
	L.append("")
	L.append("float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }")
	L.append("float noise(vec2 p) {")
	L.append("\tvec2 i = floor(p); vec2 f = fract(p);")
	L.append("\tvec2 u = f * f * (3.0 - 2.0 * f);")
	L.append("\treturn mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);")
	L.append("}")
	L.append("float fbm(vec2 p) {")
	L.append("\tfloat v = 0.0; float a = 0.5;")
	L.append("\tfor (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }")
	L.append("\treturn v;")
	L.append("}")
	L.append("")
	L.append("void fragment() {")
	L.append("\tvec2 p = (UV * 2.0 - 1.0) * 1.3;")
	L.append("\tfloat d = length(p);")
	L.append("\tif (d > 1.0) {")
	L.append("\t\tfloat glow = smoothstep(1.3, 1.0, d);")
	L.append("\t\tCOLOR = vec4(col_c, glow * glow * 0.45);")
	L.append("\t} else {")
	L.append("\t\tfloat z = sqrt(1.0 - d * d);")
	L.append("\t\tvec3 n = vec3(p, z);")
	L.append("\t\tfloat light = clamp(dot(n, normalize(vec3(-0.55, -0.55, 0.65))), 0.0, 1.0);")
	L.append("\t\tvec2 sp = vec2(atan(p.x, z) / 3.14159 + TIME * spin, asin(p.y) / 1.5708) * 2.0 + seed;")
	L.append("\t\tvec3 col;")
	L.append("\t\tfloat emit = 0.0;")
	L.append("\t\tif (kind == 0) {")
	L.append("\t\t\tfloat h = fbm(sp * 2.5);")
	L.append("\t\t\tcol = mix(col_b, col_a, smoothstep(0.3, 0.7, h));")
	L.append("\t\t\tfloat cr = fbm(sp * 7.0 + 3.0);")
	L.append("\t\t\tcol *= 0.75 + 0.35 * smoothstep(0.45, 0.6, cr);")
	L.append("\t\t} else if (kind == 1) {")
	L.append("\t\t\tfloat b = sin(sp.y * 9.0 + fbm(sp * vec2(1.0, 3.0)) * 4.0);")
	L.append("\t\t\tcol = mix(col_a, col_b, b * 0.5 + 0.5);")
	L.append("\t\t\tcol = mix(col, col_c, smoothstep(0.6, 0.9, fbm(sp * 3.0 + 7.0)) * 0.6);")
	L.append("\t\t} else if (kind == 2) {")
	L.append("\t\t\tfloat h = fbm(sp * 3.0);")
	L.append("\t\t\tcol = mix(col_a, col_b, smoothstep(0.35, 0.75, h) * 0.6);")
	L.append("\t\t\tfloat crack = smoothstep(0.03, 0.0, abs(fbm(sp * 5.0) - 0.5));")
	L.append("\t\t\tcol = mix(col, col_b * 0.7, crack);")
	L.append("\t\t} else if (kind == 3) {")
	L.append("\t\t\tfloat h = fbm(sp * 3.0);")
	L.append("\t\t\tfloat crack = smoothstep(0.06, 0.0, abs(h - 0.5));")
	L.append("\t\t\tcol = col_a * (0.7 + 0.5 * fbm(sp * 8.0));")
	L.append("\t\t\temit = crack;")
	L.append("\t\t\tcol = mix(col, col_b, crack);")
	L.append("\t\t} else if (kind == 5) {")
	L.append("\t\t\tfloat g = fbm(sp * 5.0 + vec2(TIME * 0.03, 0.0));")
	L.append("\t\t\tcol = mix(col_a, col_b, g);")
	L.append("\t\t\temit = 1.0;")
	L.append("\t\t} else {")
	L.append("\t\t\tfloat h = fbm(sp * 2.2);")
	L.append("\t\t\tcol = mix(col_a, col_b, smoothstep(0.52, 0.56, h));")
	L.append("\t\t\tfloat cloud = smoothstep(0.55, 0.75, fbm(sp * 3.5 + vec2(TIME * 0.01, 0.0)));")
	L.append("\t\t\tcol = mix(col, vec3(1.0), cloud * 0.8);")
	L.append("\t\t}")
	L.append("\t\tvec3 lit = col * (0.12 + 1.0 * light) + col * emit * 0.8;")
	L.append("\t\tif (kind == 5) { lit = col * (1.3 + 0.5 * z); }")
	L.append("\t\tfloat rim = pow(1.0 - z, 3.0);")
	L.append("\t\tlit += col_c * rim * 0.9;")
	L.append("\t\tCOLOR = vec4(lit, smoothstep(1.0, 0.985, d));")
	L.append("\t}")
	L.append("}")
	return "\n".join(L)


static func hole_shader() -> String:
	var L := PackedStringArray()
	L.append("shader_type canvas_item;")
	L.append("float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }")
	L.append("float noise(vec2 p) {")
	L.append("\tvec2 i = floor(p); vec2 f = fract(p);")
	L.append("\tvec2 u = f * f * (3.0 - 2.0 * f);")
	L.append("\treturn mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);")
	L.append("}")
	L.append("void fragment() {")
	L.append("\tvec2 p = (UV * 2.0 - 1.0) * 4.0;")
	L.append("\tfloat d = length(p);")
	L.append("\tvec2 q = vec2(p.x, p.y * 3.2);")
	L.append("\tfloat dd = length(q);")
	L.append("\tfloat ang = atan(q.y, q.x);")
	L.append("\tfloat swirl = noise(vec2(ang * 3.0 - TIME * 1.5 + dd * 2.0, dd * 3.0));")
	L.append("\tfloat disk = smoothstep(1.3, 1.6, dd) * smoothstep(3.8, 2.4, dd);")
	L.append("\tvec3 hot = mix(vec3(2.4, 0.9, 0.25), vec3(2.8, 2.4, 1.8), smoothstep(2.6, 1.4, dd));")
	L.append("\tvec3 col = hot * disk * (0.55 + 0.7 * swirl);")
	L.append("\tfloat a = disk * (0.6 + 0.4 * swirl);")
	L.append("\tfloat ring = smoothstep(0.25, 0.0, abs(d - 1.12));")
	L.append("\tcol += vec3(2.5, 1.8, 1.2) * ring;")
	L.append("\ta = max(a, ring);")
	L.append("\tfloat halo = smoothstep(2.2, 1.0, d) * 0.35;")
	L.append("\ta = max(a, halo);")
	L.append("\tbool front = p.y > 0.0;")
	L.append("\tif (d < 1.0 && !(front && disk > 0.05)) {")
	L.append("\t\tcol = vec3(0.0);")
	L.append("\t\ta = 1.0;")
	L.append("\t}")
	L.append("\tCOLOR = vec4(col, a);")
	L.append("}")
	return "\n".join(L)
