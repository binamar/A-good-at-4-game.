extends NavigationRegion3D

const SITE_A_CENTER := Vector3(24.0, 0.0, -8.0)
const SITE_B_CENTER := Vector3(-24.0, 0.0, -8.0)
const SITE_RADIUS := 4.4

var ct_spawns: Array[Vector3] = [
	Vector3(-5.0, 0.1, -26.5),
	Vector3(-2.5, 0.1, -26.5),
	Vector3(0.0, 0.1, -26.5),
	Vector3(2.5, 0.1, -26.5),
	Vector3(5.0, 0.1, -26.5),
]

var t_spawns: Array[Vector3] = [
	Vector3(-5.0, 0.1, 26.5),
	Vector3(-2.5, 0.1, 26.5),
	Vector3(0.0, 0.1, 26.5),
	Vector3(2.5, 0.1, 26.5),
	Vector3(5.0, 0.1, 26.5),
]

var tactical_waypoints: Dictionary = {
	"A_SITE": Vector3(24.0, 0.1, -8.0),
	"A_LONG": Vector3(25.7, 0.1, 6.0),
	"A_SHORT": Vector3(12.5, 0.1, -2.5),
	"MID": Vector3(4.6, 0.1, 0.0),
	"B_SITE": Vector3(-24.0, 0.1, -8.0),
	"B_TUNNEL": Vector3(-25.7, 0.1, 6.0),
	"B_CONN": Vector3(-12.5, 0.1, -2.5),
	"CT_MID": Vector3(0.0, 0.1, -17.0),
	"T_MID": Vector3(0.0, 0.1, 17.0),
}

var _mat_floor: StandardMaterial3D
var _mat_wall: StandardMaterial3D
var _mat_trim: StandardMaterial3D
var _mat_crate: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_hazard: StandardMaterial3D
var _mat_sandbag: StandardMaterial3D

var _crate_mesh: Mesh
var _barrel_mesh: Mesh
var _geometry_root: Node3D
var _bomb_visual: Node3D

var _tracer_pool: Array = []
var _tracer_timers: Array = []
var _tracer_idx := 0

var _impact_pool: Array = []
var _impact_timers: Array = []
var _impact_idx := 0

var _active_grenades: Array = []
var _explosions: Array = []
var _agents_ref: Array = []

func _ready() -> void:
	_prepare_materials_and_meshes()
	_build_sandstone_arena()
	_add_zone_lighting()
	_setup_fx_pools()
	call_deferred("_setup_navmesh")

func set_agents_ref(agents: Array) -> void:
	_agents_ref = agents

func _process(delta: float) -> void:
	for i in _tracer_pool.size():
		if _tracer_timers[i] > 0.0:
			_tracer_timers[i] -= delta
			if _tracer_timers[i] <= 0.0:
				_tracer_pool[i].visible = false

	for i in _impact_pool.size():
		if _impact_timers[i] > 0.0:
			_impact_timers[i] -= delta
			if _impact_timers[i] <= 0.0:
				_impact_pool[i].visible = false

	_update_explosions(delta)

func _physics_process(delta: float) -> void:
	_update_grenades(delta)

func _prepare_materials_and_meshes() -> void:
	_mat_floor = _make_pbr_mat("res://assets/textures/concrete_floor.png", "", Color(0.92, 0.90, 0.86), 0.22, 0.92, 1.0, false)
	_mat_wall = _make_pbr_mat("res://assets/textures/sandstone_wall.png", "", Color(0.96, 0.90, 0.80), 0.22, 0.94, 1.0, false)
	_mat_crate = _make_pbr_mat("res://assets/textures/crate_wood.png", "res://assets/textures/crate_wood_normal.png", Color(0.92, 0.84, 0.70), 0.82, 0.82, 1.0, true)
	_mat_metal = _make_pbr_mat("res://assets/textures/metal_panel.png", "res://assets/textures/metal_panel_normal.png", Color(0.64, 0.70, 0.78), 0.45, 0.48, 1.0, true)
	_mat_hazard = _make_pbr_mat("res://assets/textures/caution_stripe.png", "", Color(1.0, 0.92, 0.75), 0.45, 0.80, 1.0, false)

	_mat_trim = StandardMaterial3D.new()
	_mat_trim.albedo_color = Color(0.36, 0.34, 0.31)
	_mat_trim.roughness = 0.90
	_mat_trim.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	_mat_sandbag = StandardMaterial3D.new()
	var camo := ResourceLoader.load("res://assets/textures/tactical_camo.png") as Texture2D
	if camo != null:
		_mat_sandbag.albedo_texture = camo
	_mat_sandbag.albedo_color = Color(0.76, 0.68, 0.52)
	_mat_sandbag.roughness = 0.95
	_mat_sandbag.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

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

func _make_pbr_mat(tex_path: String, norm_path: String, tint: Color, _uv_scale: float, rough: float, norm_scale: float, allow_spec: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex := ResourceLoader.load(tex_path) as Texture2D
	if tex != null:
		mat.albedo_texture = tex
	if norm_path != "":
		var ntex := ResourceLoader.load(norm_path) as Texture2D
		if ntex != null:
			mat.normal_enabled = true
			mat.normal_texture = ntex
			mat.normal_scale = norm_scale
	mat.albedo_color = tint
	mat.roughness = rough
	if not allow_spec:
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat

func _build_sandstone_arena() -> void:
	_geometry_root = Node3D.new()
	_geometry_root.name = "ArenaGeometry"
	add_child(_geometry_root)

	# Main Floor (78m x 66m) - no shadow casting needed on flat floor
	_add_box(Vector3(0.0, -0.25, 0.0), Vector3(78.0, 0.5, 66.0), _mat_floor, true, false)

	# Outer Perimeter Walls + Top Sandstone Trim (no shadow casting on outer bounds)
	_add_walled_block(Vector3(0.0, 3.0, -32.5), Vector3(78.0, 6.0, 1.2), false)
	_add_walled_block(Vector3(0.0, 3.0, 32.5), Vector3(78.0, 6.0, 1.2), false)
	_add_walled_block(Vector3(-38.5, 3.0, 0.0), Vector3(1.2, 6.0, 66.0), false)
	_add_walled_block(Vector3(38.5, 3.0, 0.0), Vector3(1.2, 6.0, 66.0), false)

	# Lane Dividers separating Mid from A-Side (X = +12.5) with wide A-Short & Spawn exits
	_add_walled_block(Vector3(12.5, 2.5, -14.0), Vector3(1.4, 5.0, 10.0))
	_add_walled_block(Vector3(12.5, 2.5, 11.5), Vector3(1.4, 5.0, 14.0))
	# Arch lintel over A Short
	_add_box(Vector3(12.5, 4.4, -2.5), Vector3(1.4, 1.2, 13.0), _mat_trim, false)

	# Lane Dividers separating Mid from B-Side (X = -12.5) with wide B-Connector & Spawn exits
	_add_walled_block(Vector3(-12.5, 2.5, -14.0), Vector3(1.4, 5.0, 10.0))
	_add_walled_block(Vector3(-12.5, 2.5, 11.5), Vector3(1.4, 5.0, 14.0))
	_add_box(Vector3(-12.5, 4.4, -2.5), Vector3(1.4, 1.2, 13.0), _mat_trim, false)

	# Mid Courtyard Gateways & Central Monument Plinth
	_add_walled_block(Vector3(-6.8, 2.1, -17.0), Vector3(6.2, 4.2, 1.2))
	_add_walled_block(Vector3(6.8, 2.1, -17.0), Vector3(6.2, 4.2, 1.2))
	_add_box(Vector3(0.0, 4.1, -17.0), Vector3(7.4, 0.9, 1.2), _mat_metal, false)

	_add_walled_block(Vector3(-6.8, 2.1, 17.0), Vector3(6.2, 4.2, 1.2))
	_add_walled_block(Vector3(6.8, 2.1, 17.0), Vector3(6.2, 4.2, 1.2))
	_add_box(Vector3(0.0, 4.1, 17.0), Vector3(7.4, 0.9, 1.2), _mat_metal, false)

	# Mid Monument Base + Crates + Sandbags
	_add_box(Vector3(0.0, 0.25, 0.0), Vector3(5.4, 0.5, 5.4), _mat_trim)
	_add_crate(Vector3(0.0, 1.25, 0.0), Vector3(2.4, 1.5, 2.4))
	_add_crate(Vector3(0.0, 2.5, 0.0), Vector3(1.4, 1.0, 1.4))
	_add_crate(Vector3(-5.6, 0.7, 7.2), Vector3(1.7, 1.4, 1.7))
	_add_crate(Vector3(5.6, 0.7, -7.2), Vector3(1.7, 1.4, 1.7))
	_add_sandbags(Vector3(-5.5, 0.5, -7.5), Vector3(2.6, 1.0, 0.8))
	_add_sandbags(Vector3(5.5, 0.5, 7.5), Vector3(2.6, 1.0, 0.8))

	# A-Long Chokepoint + Overhead Pergola Beams
	_add_walled_block(Vector3(18.5, 2.4, 6.0), Vector3(6.0, 4.8, 1.4))
	_add_walled_block(Vector3(33.0, 2.4, 6.0), Vector3(6.0, 4.8, 1.4))
	_add_box(Vector3(25.7, 4.5, 6.0), Vector3(8.5, 0.8, 1.4), _mat_metal, false)
	_add_crate(Vector3(24.5, 0.75, 13.5), Vector3(2.0, 1.5, 1.6))
	_add_barrel(Vector3(18.5, 0.0, 17.5))
	_add_barrel(Vector3(19.5, 0.0, 18.2))

	# Site A Plant Pad + Elevated Heaven Balcony & Walkable Ramp
	_add_box(Vector3(24.0, 0.03, -8.0), Vector3(6.8, 0.06, 6.8), _mat_hazard, false)
	_add_site_marker(Vector3(24.0, 4.0, -8.0), "A", Color(0.98, 0.48, 0.22))
	_add_crate(Vector3(28.0, 0.85, -8.5), Vector3(2.0, 1.7, 2.0))
	_add_crate(Vector3(28.0, 2.25, -8.5), Vector3(1.3, 1.1, 1.3))
	_add_crate(Vector3(20.0, 0.7, -12.8), Vector3(1.8, 1.4, 1.8))
	_add_barrel(Vector3(29.8, 0.0, -3.5))
	# Elevated A-Heaven Balcony (Y = 2.0) + Ramp
	_add_box(Vector3(34.5, 1.0, -18.5), Vector3(6.5, 2.0, 7.0), _mat_trim)
	_add_box(Vector3(31.5, 2.45, -16.5), Vector3(0.4, 0.9, 3.0), _mat_metal) # low parapet
	_add_ramp(Vector3(34.5, 1.0, -11.5), Vector3(4.0, 0.4, 7.6), -16.5, _mat_floor)

	# B-Tunnel Chokepoint + Corrugated Metal Cover
	_add_box(Vector3(-18.5, 2.4, 6.0), Vector3(6.0, 4.8, 1.4), _mat_metal)
	_add_box(Vector3(-33.0, 2.4, 6.0), Vector3(6.0, 4.8, 1.4), _mat_metal)
	_add_box(Vector3(-25.7, 4.5, 6.0), Vector3(8.5, 0.8, 1.4), _mat_trim, false)
	_add_crate(Vector3(-24.5, 0.75, 14.0), Vector3(2.0, 1.5, 1.6))
	_add_barrel(Vector3(-18.5, 0.0, 18.0))

	# Site B Plant Pad + Elevated B Catwalk & Ramp
	_add_box(Vector3(-24.0, 0.03, -8.0), Vector3(6.8, 0.06, 6.8), _mat_hazard, false)
	_add_site_marker(Vector3(-24.0, 4.0, -8.0), "B", Color(0.28, 0.68, 0.98))
	_add_walled_block(Vector3(-28.5, 2.1, -8.0), Vector3(1.8, 4.2, 1.8))
	_add_crate(Vector3(-20.0, 0.7, -12.8), Vector3(1.8, 1.4, 1.8))
	_add_crate(Vector3(-27.2, 0.7, -1.8), Vector3(1.5, 1.4, 1.5))
	_add_barrel(Vector3(-29.5, 0.0, -13.0))
	# Elevated B-Balcony (Y = 2.0) + Ramp
	_add_box(Vector3(-34.5, 1.0, -18.5), Vector3(6.5, 2.0, 7.0), _mat_trim)
	_add_box(Vector3(-31.5, 2.45, -16.5), Vector3(0.4, 0.9, 3.0), _mat_metal)
	_add_ramp(Vector3(-34.5, 1.0, -11.5), Vector3(4.0, 0.4, 7.6), -16.5, _mat_floor)

	# CT & T Spawn Pergola Roofs + Sandbags
	for bx in [-6.0, 0.0, 6.0]:
		_add_box(Vector3(bx, 4.2, -26.0), Vector3(1.0, 0.35, 8.0), _mat_metal, false)
		_add_box(Vector3(bx, 4.2, 26.0), Vector3(1.0, 0.35, 8.0), _mat_metal, false)
	_add_sandbags(Vector3(-7.0, 0.5, -22.0), Vector3(3.2, 1.0, 0.9))
	_add_sandbags(Vector3(7.0, 0.5, -22.0), Vector3(3.2, 1.0, 0.9))
	_add_sandbags(Vector3(-7.0, 0.5, 22.0), Vector3(3.2, 1.0, 0.9))
	_add_sandbags(Vector3(7.0, 0.5, 22.0), Vector3(3.2, 1.0, 0.9))

func _add_walled_block(pos: Vector3, size: Vector3, cast_sh: bool = true) -> void:
	_add_box(pos, size, _mat_wall, true, cast_sh)
	_add_box(Vector3(pos.x, pos.y + size.y * 0.5 + 0.12, pos.z), Vector3(size.x + 0.12, 0.24, size.z + 0.12), _mat_trim, false, false)

func _add_sandbags(pos: Vector3, size: Vector3) -> void:
	_add_box(pos, size, _mat_sandbag, true, false)

func _make_tiled_box_mesh(size: Vector3, tile_scale: float = 0.25) -> ArrayMesh:
	var bm := BoxMesh.new()
	bm.size = size
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.get_mesh_arrays())
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(am, 0)
	for i in mdt.get_vertex_count():
		var v := mdt.get_vertex(i)
		var n := mdt.get_vertex_normal(i)
		var uv := Vector2.ZERO
		if absf(n.y) > 0.6:
			uv = Vector2(v.x, v.z) * tile_scale
		elif absf(n.x) > 0.6:
			uv = Vector2(v.z, -v.y) * tile_scale
		else:
			uv = Vector2(v.x, -v.y) * tile_scale
		mdt.set_vertex_uv(i, uv)
	am.clear_surfaces()
	mdt.commit_to_surface(am)
	return am

func _add_ramp(pos: Vector3, size: Vector3, tilt_deg_x: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = Vector3(tilt_deg_x, 0.0, 0.0)
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	mi.mesh = _make_tiled_box_mesh(size, 0.24)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	_geometry_root.add_child(body)

func _add_box(pos: Vector3, size: Vector3, mat: Material, with_collision: bool = true, cast_sh: bool = true) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var t_scale := 0.24
	if mat == _mat_hazard:
		t_scale = 0.65
	elif mat == _mat_sandbag:
		t_scale = 0.75
	mi.mesh = _make_tiled_box_mesh(size, t_scale)
	mi.material_override = mat
	if not cast_sh:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)

	if with_collision:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)

	_geometry_root.add_child(body)

func _add_zone_lighting() -> void:
	# 6 non-overlapping Purple, Blue, and Golden-Yellow light pools (1 light per fragment max = cool mobile FPS)
	_add_accent_light(Vector3(0.0, 3.6, -24.0), Color(0.20, 0.62, 1.0), 2.8, 13.5, Vector3(3.2, 0.16, 0.16))    # CT Spawn Electric Blue
	_add_accent_light(Vector3(-24.0, 3.8, -6.0), Color(0.24, 0.68, 1.0), 2.8, 13.5, Vector3(3.0, 0.16, 0.16))    # Site B Cool Blue
	_add_accent_light(Vector3(-12.2, 3.6, -2.5), Color(0.70, 0.28, 1.0), 3.0, 12.0, Vector3(0.16, 0.16, 3.0))    # B Connector Deep Purple
	_add_accent_light(Vector3(12.2, 3.6, -2.5), Color(0.72, 0.28, 1.0), 3.0, 12.0, Vector3(0.16, 0.16, 3.0))     # A Short Deep Purple
	_add_accent_light(Vector3(24.0, 4.4, -8.0), Color(1.0, 0.76, 0.22), 3.0, 13.5, Vector3(2.8, 0.16, 0.16))     # Site A Golden Yellow
	_add_accent_light(Vector3(0.0, 4.4, 20.0), Color(1.0, 0.68, 0.20), 2.8, 13.5, Vector3(3.0, 0.16, 0.16))      # T Side Golden Yellow

func _add_accent_light(pos: Vector3, col: Color, energy: float, rng: float, bar_size: Vector3) -> void:
	var omni := OmniLight3D.new()
	omni.position = pos
	omni.light_color = col
	omni.light_energy = energy
	omni.omni_range = rng
	omni.omni_attenuation = 1.4
	omni.shadow_enabled = false
	_geometry_root.add_child(omni)

	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bar_size
	bar.mesh = bm
	bar.position = pos + Vector3(0.0, 0.25, 0.0)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col.lightened(0.25)
	bar.material_override = mat
	_geometry_root.add_child(bar)

func get_route_for_lane(team: int, lane: String) -> Array:
	if team == 1:
		match lane:
			"A_SITE":
				return [Vector3(10.0, 0.1, -22.5), Vector3(24.0, 0.1, -18.0), Vector3(24.0, 0.1, -8.0), Vector3(24.0, 0.1, 4.0)]
			"A_SHORT":
				return [Vector3(0.0, 0.1, -17.0), Vector3(4.6, 0.1, -6.0), Vector3(12.5, 0.1, -2.5), Vector3(22.0, 0.1, -6.0)]
			"MID":
				return [Vector3(0.0, 0.1, -17.0), Vector3(4.6, 0.1, -6.0), Vector3(4.6, 0.1, 6.0), Vector3(0.0, 0.1, 17.0)]
			"B_CONN":
				return [Vector3(0.0, 0.1, -17.0), Vector3(-4.6, 0.1, -6.0), Vector3(-12.5, 0.1, -2.5), Vector3(-22.0, 0.1, -6.0)]
			_:
				return [Vector3(-10.0, 0.1, -22.5), Vector3(-24.0, 0.1, -18.0), Vector3(-24.0, 0.1, -8.0), Vector3(-25.7, 0.1, 6.0)]
	else:
		match lane:
			"A_SITE":
				return [Vector3(10.0, 0.1, 22.5), Vector3(25.7, 0.1, 14.0), Vector3(25.7, 0.1, 6.0), Vector3(24.0, 0.1, -8.0)]
			"A_SHORT":
				return [Vector3(0.0, 0.1, 17.0), Vector3(4.6, 0.1, 6.0), Vector3(12.5, 0.1, -2.5), Vector3(24.0, 0.1, -8.0)]
			"MID":
				return [Vector3(0.0, 0.1, 17.0), Vector3(-4.6, 0.1, 6.0), Vector3(-4.6, 0.1, -6.0), Vector3(0.0, 0.1, -17.0)]
			"B_CONN":
				return [Vector3(0.0, 0.1, 17.0), Vector3(-4.6, 0.1, 6.0), Vector3(-12.5, 0.1, -2.5), Vector3(-24.0, 0.1, -8.0)]
			_:
				return [Vector3(-10.0, 0.1, 22.5), Vector3(-25.7, 0.1, 14.0), Vector3(-25.7, 0.1, 6.0), Vector3(-24.0, 0.1, -8.0)]

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
	lbl.font_size = 84
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = col
	lbl.outline_size = 12
	_geometry_root.add_child(lbl)

func _setup_navmesh() -> void:
	var nav := NavigationMesh.new()
	nav.agent_radius = 0.44
	nav.agent_height = 1.8
	nav.agent_max_climb = 0.45
	nav.agent_max_slope = 45.0
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = 1
	navigation_mesh = nav
	bake_navigation_mesh(false)

func _setup_fx_pools() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.86, 0.42)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.024, 0.024, 1.0)
	for i in 16:
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = mat
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_tracer_pool.append(mi)
		_tracer_timers.append(0.0)

	var imp_mat := StandardMaterial3D.new()
	imp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imp_mat.albedo_color = Color(1.0, 0.65, 0.25)
	var imp_mesh := SphereMesh.new()
	imp_mesh.radius = 0.08
	imp_mesh.height = 0.16
	imp_mesh.radial_segments = 6
	imp_mesh.rings = 4
	for i in 20:
		var im := MeshInstance3D.new()
		im.mesh = imp_mesh
		im.material_override = imp_mat
		im.visible = false
		im.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(im)
		_impact_pool.append(im)
		_impact_timers.append(0.0)

func spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var dist := from_pos.distance_to(to_pos)
	if dist < 0.2:
		return
	var mi: MeshInstance3D = _tracer_pool[_tracer_idx]
	_tracer_timers[_tracer_idx] = 0.045
	_tracer_idx = (_tracer_idx + 1) % _tracer_pool.size()
	mi.visible = true
	mi.global_position = from_pos.lerp(to_pos, 0.5)
	var look_dir := (to_pos - mi.global_position).normalized()
	var up_vec := Vector3.UP if absf(look_dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	mi.look_at(to_pos, up_vec)
	mi.scale = Vector3(1.0, 1.0, dist)

func spawn_impact(pos: Vector3, normal: Vector3, is_blood: bool) -> void:
	var mi: MeshInstance3D = _impact_pool[_impact_idx]
	_impact_timers[_impact_idx] = 0.14 if is_blood else 0.10
	_impact_idx = (_impact_idx + 1) % _impact_pool.size()
	mi.visible = true
	mi.global_position = pos + normal * 0.03
	mi.scale = Vector3.ONE * (1.4 if is_blood else 1.0)
	var mat: StandardMaterial3D = mi.material_override
	mat.albedo_color = Color(0.95, 0.18, 0.18) if is_blood else Color(1.0, 0.78, 0.35)

func throw_grenade(origin: Vector3, dir: Vector3, thrower_name: String, thrower_team: int) -> void:
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.38, 0.22)
	mesh.material_override = mat
	add_child(mesh)
	mesh.global_position = origin
	_active_grenades.append({
		"node": mesh,
		"pos": origin,
		"vel": dir.normalized() * 16.5 + Vector3(0.0, 4.2, 0.0),
		"fuse": 1.65,
		"owner_name": thrower_name,
		"owner_team": thrower_team,
	})

func _update_grenades(delta: float) -> void:
	for i in range(_active_grenades.size() - 1, -1, -1):
		var g: Dictionary = _active_grenades[i]
		g["fuse"] -= delta
		var vel: Vector3 = g["vel"]
		vel.y -= 18.5 * delta
		var pos: Vector3 = g["pos"]
		var next_pos: Vector3 = pos + vel * delta
		var query := PhysicsRayQueryParameters3D.create(pos, next_pos, 1)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			pos = hit["position"] + n * 0.08
			vel = vel.bounce(n) * 0.45
		else:
			pos = next_pos
		g["pos"] = pos
		g["vel"] = vel
		var node: MeshInstance3D = g["node"]
		node.global_position = pos
		if g["fuse"] <= 0.0:
			node.queue_free()
			_detonate_grenade(pos, g["owner_name"], g["owner_team"])
			_active_grenades.remove_at(i)

func _detonate_grenade(pos: Vector3, owner_name: String, owner_team: int) -> void:
	AudioManager.play_sfx("explode", -2.0, 0.08)
	var exp_node := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 8
	exp_node.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.52, 0.14, 0.85)
	exp_node.material_override = mat
	add_child(exp_node)
	exp_node.global_position = pos
	exp_node.scale = Vector3.ONE * 0.6
	_explosions.append({"node": exp_node, "t": 0.35})

	var max_r := 7.5
	for ag in _agents_ref:
		if not is_instance_valid(ag) or not ag.is_alive:
			continue
		var d := pos.distance_to(ag.global_position + Vector3(0.0, 1.0, 0.0))
		if d <= max_r and ag.has_method("take_damage"):
			var falloff := 1.0 - (d / max_r)
			var dmg := 95.0 * falloff
			if ag.team != owner_team or ag.agent_name == owner_name:
				ag.take_damage(dmg, owner_name, owner_team, "FRAG", false, owner_name == "You")

func _update_explosions(delta: float) -> void:
	for i in range(_explosions.size() - 1, -1, -1):
		var ex: Dictionary = _explosions[i]
		ex["t"] -= delta
		var node: MeshInstance3D = ex["node"]
		var k := 1.0 - clampf(ex["t"] / 0.35, 0.0, 1.0)
		node.scale = Vector3.ONE * lerpf(0.8, 5.2, k)
		var mat: StandardMaterial3D = node.material_override
		mat.albedo_color.a = (1.0 - k) * 0.85
		if ex["t"] <= 0.0:
			node.queue_free()
			_explosions.remove_at(i)

func set_bomb_visual(planted: bool, pos: Vector3) -> void:
	if _bomb_visual == null:
		_bomb_visual = Node3D.new()
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.36, 0.16, 0.24)
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.14, 0.16, 0.18)
		mesh_inst.material_override = mat
		_bomb_visual.add_child(mesh_inst)

		var led := MeshInstance3D.new()
		var led_box := BoxMesh.new()
		led_box.size = Vector3(0.10, 0.05, 0.10)
		led.mesh = led_box
		led.position = Vector3(0.0, 0.10, 0.0)
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
