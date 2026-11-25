extends NavigationRegion3D

const SITE_A_CENTER := Vector3(18.0, 0.0, -6.0)
const SITE_B_CENTER := Vector3(-18.0, 0.0, -6.0)
const SITE_RADIUS := 4.0

var ct_spawns: Array[Vector3] = [
	Vector3(-4.0, 0.1, -19.5),
	Vector3(-2.0, 0.1, -19.5),
	Vector3(0.0, 0.1, -19.5),
	Vector3(2.0, 0.1, -19.5),
	Vector3(4.0, 0.1, -19.5),
]

var t_spawns: Array[Vector3] = [
	Vector3(-4.0, 0.1, 19.5),
	Vector3(-2.0, 0.1, 19.5),
	Vector3(0.0, 0.1, 19.5),
	Vector3(2.0, 0.1, 19.5),
	Vector3(4.0, 0.1, 19.5),
]

var tactical_waypoints: Dictionary = {
	"A_SITE": Vector3(18.0, 0.1, -6.0),
	"A_LONG": Vector3(18.0, 0.1, 12.0),
	"A_SHORT": Vector3(9.0, 0.1, -2.0),
	"MID": Vector3(0.0, 0.1, 0.0),
	"B_SITE": Vector3(-18.0, 0.1, -6.0),
	"B_TUNNEL": Vector3(-18.0, 0.1, 12.0),
	"B_CONN": Vector3(-9.0, 0.1, -2.0),
	"CT_MID": Vector3(0.0, 0.1, -14.0),
	"T_MID": Vector3(0.0, 0.1, 14.0),
}

var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_crate: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_hazard: StandardMaterial3D

var _crate_mesh: Mesh
var _barrel_mesh: Mesh
var _geometry_root: Node3D
var _bomb_visual: Node3D

var _tracer_pool: Array[MeshInstance3D] = []
var _tracer_timers: Array[float] = []
var _tracer_idx := 0

func _ready() -> void:
	_prepare_materials_and_meshes()
	_build_sandstone_arena()
	_setup_navmesh()
	_setup_tracer_pool()

func _process(delta: float) -> void:
	for i in _tracer_pool.size():
		if _tracer_timers[i] > 0.0:
			_tracer_timers[i] -= delta
			if _tracer_timers[i] <= 0.0:
				_tracer_pool[i].visible = false

func _prepare_materials_and_meshes() -> void:
	_mat_floor = _make_mat("res://assets/textures/concrete_floor.png", Color(0.92, 0.90, 0.86), 0.25, 0.88)
	_mat_wall = _make_mat("res://assets/textures/sandstone_wall.png", Color(0.96, 0.91, 0.82), 0.25, 0.92)
	_mat_crate = _make_mat("res://assets/textures/crate_wood.png", Color(0.92, 0.85, 0.72), 0.85, 0.85)
	_mat_metal = _make_mat("res://assets/textures/metal_panel.png", Color(0.68, 0.74, 0.82), 0.5, 0.48)
	_mat_hazard = _make_mat("res://assets/textures/caution_stripe.png", Color(1.0, 0.92, 0.75), 0.5, 0.75)

	_crate_mesh = ResourceLoader.load("res://assets/models/crate_tactical.obj") as Mesh
	if _crate_mesh == null:
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_crate_mesh = b

	_barrel_mesh = ResourceLoader.load("res://assets/models/barrel_lowpoly.obj") as Mesh
	if _barrel_mesh == null:
		var c := CylinderMesh.new()
		c.top_radius = 0.36
		c.bottom_radius = 0.36
		c.height = 1.1
		_barrel_mesh = c

func _make_mat(tex_path: String, tint: Color, tri_scale: float, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex := ResourceLoader.load(tex_path) as Texture2D
	if tex != null:
		mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.roughness = rough
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * tri_scale
	return mat

func _build_sandstone_arena() -> void:
	_geometry_root = Node3D.new()
	_geometry_root.name = "ArenaGeometry"
	add_child(_geometry_root)

	# Main Floor
	_add_box(Vector3(0.0, -0.25, 0.0), Vector3(58.0, 0.5, 50.0), _mat_floor)

	# Outer Perimeter Walls
	_add_box(Vector3(0.0, 2.5, -24.5), Vector3(58.0, 5.0, 1.0), _mat_wall)
	_add_box(Vector3(0.0, 2.5, 24.5), Vector3(58.0, 5.0, 1.0), _mat_wall)
	_add_box(Vector3(-28.5, 2.5, 0.0), Vector3(1.0, 5.0, 50.0), _mat_wall)
	_add_box(Vector3(28.5, 2.5, 0.0), Vector3(1.0, 5.0, 50.0), _mat_wall)

	# Lane Dividers separating Mid from A-Side (X = +9.5) with wide A-Short & Spawn exits
	_add_box(Vector3(9.5, 2.25, -10.5), Vector3(1.2, 4.5, 7.0), _mat_wall)
	_add_box(Vector3(9.5, 2.25, 8.5), Vector3(1.2, 4.5, 11.0), _mat_wall)

	# Lane Dividers separating Mid from B-Side (X = -9.5) with wide B-Connector & Spawn exits
	_add_box(Vector3(-9.5, 2.25, -10.5), Vector3(1.2, 4.5, 7.0), _mat_wall)
	_add_box(Vector3(-9.5, 2.25, 8.5), Vector3(1.2, 4.5, 11.0), _mat_wall)

	# Mid Courtyard Tactical Barriers & Cover
	_add_box(Vector3(-5.0, 1.75, -12.5), Vector3(4.5, 3.5, 1.0), _mat_wall)
	_add_box(Vector3(5.0, 1.75, -12.5), Vector3(4.5, 3.5, 1.0), _mat_wall)
	_add_box(Vector3(-5.0, 1.75, 12.5), Vector3(4.5, 3.5, 1.0), _mat_wall)
	_add_box(Vector3(5.0, 1.75, 12.5), Vector3(4.5, 3.5, 1.0), _mat_wall)

	# Mid Center Double Crates + Peek Boxes
	_add_crate(Vector3(0.0, 0.75, 0.0), Vector3(2.2, 1.5, 2.2))
	_add_crate(Vector3(0.0, 2.0, 0.0), Vector3(1.4, 1.0, 1.4))
	_add_crate(Vector3(-4.2, 0.65, 5.2), Vector3(1.5, 1.3, 1.5))
	_add_crate(Vector3(4.2, 0.65, -5.2), Vector3(1.5, 1.3, 1.5))

	# A-Long Chokepoint Arch & Cover
	_add_box(Vector3(14.0, 2.0, 4.5), Vector3(4.5, 4.0, 1.2), _mat_wall)
	_add_box(Vector3(24.5, 2.0, 4.5), Vector3(4.5, 4.0, 1.2), _mat_wall)
	_add_crate(Vector3(19.0, 0.65, 10.5), Vector3(1.8, 1.3, 1.4))
	_add_barrel(Vector3(14.5, 0.0, 14.0))

	# Site A Plant Pad & Tactical Cover
	_add_box(Vector3(18.0, 0.02, -6.0), Vector3(5.8, 0.06, 5.8), _mat_hazard, false)
	_add_site_marker(Vector3(18.0, 3.4, -6.0), "A", Color(0.95, 0.42, 0.25))
	_add_crate(Vector3(21.5, 0.8, -6.5), Vector3(1.8, 1.6, 1.8))
	_add_crate(Vector3(21.5, 2.1, -6.5), Vector3(1.2, 1.0, 1.2))
	_add_crate(Vector3(15.2, 0.65, -9.8), Vector3(1.6, 1.3, 1.6))
	_add_barrel(Vector3(23.2, 0.0, -2.5))

	# B-Tunnel Chokepoint & Cover
	_add_box(Vector3(-14.0, 2.0, 4.5), Vector3(4.5, 4.0, 1.2), _mat_metal)
	_add_box(Vector3(-24.5, 2.0, 4.5), Vector3(4.5, 4.0, 1.2), _mat_metal)
	_add_crate(Vector3(-19.2, 0.65, 11.0), Vector3(1.8, 1.3, 1.5))
	_add_barrel(Vector3(-14.2, 0.0, 14.5))

	# Site B Plant Pad & Pillars
	_add_box(Vector3(-18.0, 0.02, -6.0), Vector3(5.8, 0.06, 5.8), _mat_hazard, false)
	_add_site_marker(Vector3(-18.0, 3.4, -6.0), "B", Color(0.28, 0.66, 0.96))
	_add_box(Vector3(-22.0, 1.9, -6.0), Vector3(1.6, 3.8, 1.6), _mat_wall)
	_add_crate(Vector3(-14.8, 0.65, -9.8), Vector3(1.6, 1.3, 1.6))
	_add_crate(Vector3(-21.2, 0.65, -1.2), Vector3(1.4, 1.3, 1.4))
	_add_barrel(Vector3(-23.0, 0.0, -10.5))

	# CT & T Spawn Protection Crates
	_add_crate(Vector3(-5.2, 0.7, -16.8), Vector3(1.8, 1.4, 1.4))
	_add_crate(Vector3(5.2, 0.7, -16.8), Vector3(1.8, 1.4, 1.4))
	_add_crate(Vector3(-5.2, 0.7, 16.8), Vector3(1.8, 1.4, 1.4))
	_add_crate(Vector3(5.2, 0.7, 16.8), Vector3(1.8, 1.4, 1.4))

func _add_box(pos: Vector3, size: Vector3, mat: Material, with_collision: bool = true) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)

	if with_collision:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)

	_geometry_root.add_child(body)

func _add_crate(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	mi.mesh = _crate_mesh
	mi.scale = size
	mi.material_override = _mat_crate
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	_geometry_root.add_child(body)

func _add_barrel(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	mi.mesh = _barrel_mesh
	mi.material_override = _mat_metal
	body.add_child(mi)

	var col := CollisionShape3D.new()
	col.position = Vector3(0.0, 0.55, 0.0)
	var shape := CylinderShape3D.new()
	shape.radius = 0.38
	shape.height = 1.1
	col.shape = shape
	body.add_child(col)

	_geometry_root.add_child(body)

func _add_site_marker(pos: Vector3, text: String, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.position = pos
	lbl.text = "SITE " + text
	lbl.font_size = 72
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = col
	lbl.outline_size = 10
	_geometry_root.add_child(lbl)

func _setup_navmesh() -> void:
	var nav := NavigationMesh.new()
	nav.agent_radius = 0.5
	nav.agent_height = 1.8
	nav.agent_max_climb = 0.35
	nav.agent_max_slope = 40.0
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	navigation_mesh = nav
	bake_navigation_mesh(false)

func _setup_tracer_pool() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.86, 0.42)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 1.0)
	for i in 14:
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_tracer_pool.append(mi)
		_tracer_timers.append(0.0)

func spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var dist := from_pos.distance_to(to_pos)
	if dist < 0.2:
		return
	var mi := _tracer_pool[_tracer_idx]
	_tracer_timers[_tracer_idx] = 0.045
	_tracer_idx = (_tracer_idx + 1) % _tracer_pool.size()
	mi.visible = true
	mi.global_position = from_pos.lerp(to_pos, 0.5)
	mi.look_at(to_pos, Vector3.UP)
	mi.scale = Vector3(1.0, 1.0, dist)

func set_bomb_visual(planted: bool, pos: Vector3) -> void:
	if _bomb_visual == null:
		_bomb_visual = Node3D.new()
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.14, 0.22)
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.14, 0.16, 0.18)
		mesh_inst.material_override = mat
		_bomb_visual.add_child(mesh_inst)

		var led := MeshInstance3D.new()
		var led_box := BoxMesh.new()
		led_box.size = Vector3(0.08, 0.04, 0.08)
		led.mesh = led_box
		led.position = Vector3(0.0, 0.09, 0.0)
		var led_mat := StandardMaterial3D.new()
		led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		led_mat.albedo_color = Color(1.0, 0.2, 0.15)
		led.material_override = led_mat
		_bomb_visual.add_child(led)
		add_child(_bomb_visual)

	_bomb_visual.visible = planted
	if planted:
		_bomb_visual.global_position = pos + Vector3(0.0, 0.08, 0.0)

func get_site_at_position(pos: Vector3) -> String:
	if Vector2(pos.x - SITE_A_CENTER.x, pos.z - SITE_A_CENTER.z).length() <= SITE_RADIUS:
		return "A"
	if Vector2(pos.x - SITE_B_CENTER.x, pos.z - SITE_B_CENTER.z).length() <= SITE_RADIUS:
		return "B"
	return ""
