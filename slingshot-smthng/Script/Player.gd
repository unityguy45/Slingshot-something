class_name Player
extends Node2D

signal died(reason: String)
signal docked(station: Station)
signal drone_dropped(drone: Drone)
signal bumped(amount: float)

const TURN := 10.0
const MAX_SPEED := 3600.0

var fuel_max := 100.0
var thrust := 800.0
var burn := 13.0
var drones_max := 2
var hull_max := 100.0
var hull := 100.0
var braking := false
var tractor := false
var dock_cooldown := 0.0
var bump_cd := 0.0
var autopilot := false
var auto_station: Station
var ref_vel := Vector2.ZERO
var ref_name := ""

var vel := Vector2.ZERO
var fuel := 100.0
var drones := 2
var thrusting := false
var launch_lock := true
var state := "docked"
var station: Station
var bodies: Array = []
var stations: Array = []
var trail: Line2D
var flames: Array = []


func _ready() -> void:
	trail = Line2D.new()
	trail.top_level = true
	trail.width = 9.0
	trail.default_color = Color(1.4, 0.7, 0.3)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0.7))
	trail.gradient = g
	add_child(trail)
	for side in [-1.0, 0.0, 1.0]:
		var flame := CPUParticles2D.new()
		flame.amount = 40
		flame.lifetime = 0.4
		flame.local_coords = false
		flame.position = Vector2(-62, side * 50)
		flame.direction = Vector2(-1, 0)
		flame.spread = 8.0
		flame.initial_velocity_min = 250.0
		flame.initial_velocity_max = 380.0
		flame.gravity = Vector2.ZERO
		flame.scale_amount_min = 4.0
		flame.scale_amount_max = 8.0
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.2, 2.2, 3.0, 1.0))
		ramp.add_point(0.35, Color(0.4, 0.9, 2.2, 0.8))
		ramp.set_color(1, Color(0.2, 0.2, 0.8, 0.0))
		flame.color_ramp = ramp
		flame.emitting = false
		add_child(flame)
		flames.append(flame)


func refill() -> void:
	fuel = fuel_max
	drones = drones_max
	hull = hull_max


func dock(st: Station) -> void:
	state = "docked"
	station = st
	position = st.position
	_set_flames(false)
	trail.clear_points()


func undock() -> void:
	state = "fly"
	launch_lock = true
	var dir := (get_global_mouse_position() - position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	rotation = dir.angle()
	vel = station.vel + dir * 500.0
	autopilot = false
	dock_cooldown = 4.0
	position = station.position + dir * (station.dock_r + 30.0)


func gravity_at(p: Vector2) -> Vector2:
	var a := Vector2.ZERO
	for b: Planet in bodies:
		a += b.gravity_at(p)
	return a


func _unhandled_input(e: InputEvent) -> void:
	if state != "fly":
		return
	var drop: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT) \
		or (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E)
	if drop and drones > 0:
		drones -= 1
		var d := Drone.new()
		d.position = position
		d.vel = vel + Vector2.from_angle(rotation) * 400.0
		d.bodies = bodies
		drone_dropped.emit(d)


func _physics_process(delta: float) -> void:
	if state == "docked":
		position = station.position
		vel = station.vel
		return
	if state == "dead":
		return
	var ref := _reference()
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)
	braking = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SHIFT)
	if not held:
		launch_lock = false
	var rel := vel - ref_vel
	if braking and rel.length() > 4.0:
		rotation = rotate_toward(rotation, (-rel).angle(), TURN * 1.5 * delta)
	else:
		var aim := get_global_mouse_position() - global_position
		rotation = rotate_toward(rotation, aim.angle(), TURN * delta)
	thrusting = false
	if held and not launch_lock:
		autopilot = false
	if autopilot and fuel <= 0.0:
		autopilot = false
	if autopilot and auto_station != null:
		var to := auto_station.position - position
		var want := auto_station.vel + to.normalized() * minf(to.length() * 0.9, 2000.0)
		for b: Planet in bodies:
			var off := position - b.position
			var keep := b.kill_radius() * (3.0 if b.is_sun else 4.0) + 300.0
			if b.is_hole:
				keep = b.field * 0.6
			var dd := off.length()
			if dd < keep and dd > 1.0:
				var push := 1.0 - dd / keep
				var side := off.normalized()
				if side.dot(to.normalized()) < 0.3:
					side = (side + to.normalized().orthogonal() * signf(off.cross(to) + 0.001)).normalized()
				want += side * 2600.0 * push
		vel -= gravity_at(position) * delta
		vel = vel.lerp(want, 2.2 * delta)
		rotation = rotate_toward(rotation, (want - vel + to.normalized()).angle(), TURN * delta)
		fuel = maxf(0.0, fuel - burn * 0.7 * delta)
		thrusting = true
	elif fuel > 0.0:
		if braking and rel.length() > 4.0:
			var dv := minf(thrust * 2.0 * delta, rel.length())
			vel -= rel.normalized() * dv
			fuel = maxf(0.0, fuel - burn * 0.5 * delta)
			thrusting = true
		elif held and not launch_lock:
			vel += Vector2.from_angle(rotation) * thrust * delta
			fuel = maxf(0.0, fuel - burn * delta)
			thrusting = true
	_set_flames(thrusting)
	vel += gravity_at(position) * delta
	tractor = false
	dock_cooldown -= delta
	for st: Station in stations:
		if dock_cooldown > 0.0 and st == station:
			continue
		var d := position.distance_to(st.position)
		var srel := (vel - st.vel).length()
		if d < st.dock_r * 9.0:
			tractor = true
			vel = vel.lerp(st.vel + (st.position - position).normalized() * minf(d * 3.0, 1500.0), 6.0 * delta)
		if d < st.dock_r * 1.6:
			dock(st)
			docked.emit(st)
			return
	vel = vel.limit_length(MAX_SPEED)
	position += vel * delta
	bump_cd -= delta
	for b: Planet in bodies:
		var off := position - b.position
		if off.length() < b.kill_radius() + 14.0:
			var n := off.normalized()
			var rv := vel - b.vel
			var impact := rv.dot(-n)
			if b.is_hole or b.is_sun or impact > 650.0:
				_die(b)
				return
			if bump_cd <= 0.0:
				var dmg := 4.0 + maxf(impact, 0.0) * 0.06
				hull -= dmg
				bump_cd = 1.2
				bumped.emit(dmg)
				if hull <= 0.0:
					_die(b)
					return
			position = b.position + n * (b.kill_radius() + 16.0)
			var out := rv - 2.0 * minf(rv.dot(n), 0.0) * n
			vel = b.vel + out * 0.6 + n * 250.0
	trail.add_point(global_position - Vector2.from_angle(rotation) * 60.0)
	while trail.get_point_count() > 50:
		trail.remove_point(0)
	queue_redraw()


func toggle_autopilot() -> void:
	if state != "fly":
		return
	if autopilot:
		autopilot = false
		return
	if fuel <= 0.0:
		return
	var best: Station = null
	for st: Station in stations:
		if best == null or st.position.distance_to(position) < best.position.distance_to(position):
			best = st
	auto_station = best
	autopilot = best != null


func _die(b: Planet) -> void:
	state = "dead"
	_set_flames(false)
	var why := "Crashed into %s" % b.pname
	if b.is_hole:
		why = "Swallowed by a black hole"
	elif b.is_sun:
		why = "Burned up in the Sun"
	died.emit(why)


func _reference() -> Planet:
	var best: Planet = null
	var bd := INF
	for b: Planet in bodies:
		if b.is_sun:
			continue
		var d := position.distance_to(b.position)
		if d < b.field and d < bd:
			bd = d
			best = b
	if best == null:
		ref_vel = Vector2.ZERO
		ref_name = "Sol"
	else:
		ref_vel = best.vel
		ref_name = best.pname
	for st: Station in stations:
		if position.distance_to(st.position) < st.dock_r * 6.0:
			ref_vel = st.vel
			ref_name = st.sname
	return best


func predict(steps: int, dt: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var p := position
	var v := vel
	for i in steps:
		var tt := Planet.time + dt * i
		var a := Vector2.ZERO
		for b: Planet in bodies:
			var c := b.pos_at(tt)
			a += b.gravity_from(c, p)
			if p.distance_to(c) < b.kill_radius():
				return pts
		v += a * dt
		p += v * dt
		pts.append(p)
	return pts


func _set_flames(on: bool) -> void:
	for f: CPUParticles2D in flames:
		f.emitting = on


func _draw() -> void:
	if state == "dead":
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2.6, 2.6))
	var hull_c := Color(0.8, 0.83, 0.9)
	var dark := Color(0.28, 0.3, 0.38)
	var accent := Color(0.2, 0.75, 1.0)
	var wing := PackedVector2Array([Vector2(10, 0), Vector2(-6, -26), Vector2(-16, -28), Vector2(-12, -8), Vector2(-12, 8), Vector2(-16, 28), Vector2(-6, 26)])
	draw_colored_polygon(wing, dark)
	for s in [-1.0, 1.0]:
		draw_line(Vector2(4, 4 * s), Vector2(-8, 24 * s), accent, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 16 * s), Vector2(-22, 16 * s), Vector2(-22, 22 * s), Vector2(-6, 22 * s)]), Color(0.5, 0.52, 0.6))
		draw_circle(Vector2(-16, 27 * s), 1.6, Color(2.0, 0.3, 0.3) if s < 0 else Color(0.3, 2.0, 0.4))
	var body := PackedVector2Array([Vector2(26, 0), Vector2(16, -7), Vector2(-4, -10), Vector2(-18, -8), Vector2(-18, 8), Vector2(-4, 10), Vector2(16, 7)])
	draw_colored_polygon(body, hull_c)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0.1, 0.11, 0.16), 1.2, true)
	var wo := wing.duplicate()
	wo.append(wing[0])
	draw_polyline(wo, Color(0.1, 0.11, 0.16), 1.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(18, 0), Vector2(10, -4), Vector2(2, -4), Vector2(2, 4), Vector2(10, 4)]), Color(0.15, 0.55, 0.9))
	draw_line(Vector2(13, -2), Vector2(6, -2), Color(0.85, 0.95, 1.0), 1.0)
	draw_rect(Rect2(-22, -6, 4, 12), Color(0.3, 0.32, 0.4))
	var glow := Color(0.4, 1.2, 2.4) if thrusting else Color(0.15, 0.25, 0.4)
	draw_rect(Rect2(-24, -5, 2, 4), glow)
	draw_rect(Rect2(-24, 1, 2, 4), glow)
	draw_rect(Rect2(-24, 16, 2, 6), glow)
	draw_rect(Rect2(-24, -22, 2, 6), glow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tractor:
		draw_arc(Vector2.ZERO, 90.0, 0.0, TAU, 32, Color(0.3, 1.5, 0.8, 0.5), 3.0)
