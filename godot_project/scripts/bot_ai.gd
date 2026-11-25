extends CharacterBody3D

const GRAVITY := 20.0
const MOVE_SPEED := 5.15
const PLANT_TIME := 3.2
const DEFUSE_TIME := 5.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_root: Node3D = $VisualRoot
@onready var hitbox_body: Area3D = $HitboxBody
@onready var hitbox_head: Area3D = $HitboxHead
@onready var body_collider: CollisionShape3D = $BodyCollider

var team: int = 1
var agent_name: String = "Bot"
var is_alive: bool = true
var hp: int = 100
var weapon_id: int = 5
var _role_idx: int = 0

var _arena = null
var _agents_ref: Array = []
var _flash_mats: Array = []
var _flash_timer: float = 0.0
var _walk_phase: float = 0.0
var _death_anim_t: float = 0.0
var _stuck_timer: float = 0.0

var _torso_pivot: Node3D
var _head_pivot: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _right_arm: Node3D
var _left_arm: Node3D
var _gun_muzzle: Marker3D
var _ally_marker: MeshInstance3D

var _torso_mesh_inst: MeshInstance3D
var _helmet_mesh_inst: MeshInstance3D
var _visor_mesh_inst: MeshInstance3D

var _visor_mat: ShaderMaterial
var _skin_mat: ShaderMaterial
var _helmet_mat: ShaderMaterial
var _armor_mat: ShaderMaterial
var _gear_mat: ShaderMaterial
var _gun_mat: ShaderMaterial

var _torso_meshes: Array = []
var _helmet_meshes: Array = []

var _fire_cd: float = 0.0
var _burst_left: int = 0
var _burst_pause: float = 0.0
var _repath_timer: float = 0.0
var _reaction_timer: float = 0.0
var _target_enemy: Node3D = null
var _assigned_lane: String = "A_SITE"
var _objective_progress: float = 0.0
var _is_bomb_carrier: bool = false
var _exclude_rids: Array[RID] = []

func _ready() -> void:
	_build_articulated_operator()
	hitbox_body.set_meta("owner_agent", self)
	hitbox_body.set_meta("is_head", false)
	hitbox_head.set_meta("owner_agent", self)
	hitbox_head.set_meta("is_head", true)
	_exclude_rids.clear()
	_exclude_rids.append(get_rid())
	_exclude_rids.append(hitbox_body.get_rid())
	_exclude_rids.append(hitbox_head.get_rid())

func _make_flash_mat(col: Color, rough: float = 0.68) -> ShaderMaterial:
	var shader := ResourceLoader.load("res://shaders/hit_flash.gdshader") as Shader
	var sm := ShaderMaterial.new()
	sm.shader = shader
	sm.set_shader_parameter("albedo_color", col)
	sm.set_shader_parameter("roughness_val", rough)
	_flash_mats.append(sm)
	return sm

func _load_mesh(path: String) -> Mesh:
	var m := ResourceLoader.load(path) as Mesh
	if m != null:
		return m
	var fallback := CapsuleMesh.new()
	fallback.radius = 0.12
	fallback.height = 0.4
	return fallback

func _add_mesh(parent: Node3D, mesh_res: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_res
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_articulated_operator() -> void:
	_flash_mats.clear()
	_armor_mat = _make_flash_mat(Color(0.18, 0.36, 0.64), 0.65)
	_helmet_mat = _make_flash_mat(Color(0.13, 0.16, 0.22), 0.50)
	_gear_mat = _make_flash_mat(Color(0.18, 0.20, 0.24), 0.72)
	_visor_mat = _make_flash_mat(Color(0.20, 0.85, 1.0), 0.16)
	_skin_mat = _make_flash_mat(Color(0.84, 0.66, 0.52), 0.78)
	_gun_mat = _make_flash_mat(Color(0.14, 0.16, 0.20), 0.38)

	_torso_meshes.clear()
	_torso_meshes.append(_load_mesh("res://assets/models/op_torso_assault.obj"))
	_torso_meshes.append(_load_mesh("res://assets/models/op_torso_heavy.obj"))
	_torso_meshes.append(_load_mesh("res://assets/models/op_torso_recon.obj"))
	_torso_meshes.append(_load_mesh("res://assets/models/op_torso_assault.obj"))

	_helmet_meshes.clear()
	_helmet_meshes.append(_load_mesh("res://assets/models/op_helmet_assault.obj"))
	_helmet_meshes.append(_load_mesh("res://assets/models/op_helmet_heavy.obj"))
	_helmet_meshes.append(_load_mesh("res://assets/models/op_helmet_recon.obj"))
	_helmet_meshes.append(_load_mesh("res://assets/models/op_helmet_tech.obj"))

	var head_mesh := _load_mesh("res://assets/models/op_head_sculpted.obj")
	var visor_mesh := _load_mesh("res://assets/models/op_visor_curved.obj")
	var arm_mesh := _load_mesh("res://assets/models/op_limb_arm.obj")
	var leg_mesh := _load_mesh("res://assets/models/op_limb_leg.obj")
	var rifle_mesh := _load_mesh("res://assets/models/op_rifle_world.obj")

	# Torso Pivot
	_torso_pivot = Node3D.new()
	_torso_pivot.position = Vector3(0.0, 0.78, 0.0)
	visual_root.add_child(_torso_pivot)
	_torso_mesh_inst = _add_mesh(_torso_pivot, _torso_meshes[0], Vector3.ZERO, _armor_mat)

	# Expressive Sculpted Head Pivot
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0.0, 0.62, 0.0)
	_torso_pivot.add_child(_head_pivot)
	_add_mesh(_head_pivot, head_mesh, Vector3.ZERO, _skin_mat)
	_helmet_mesh_inst = _add_mesh(_head_pivot, _helmet_meshes[0], Vector3.ZERO, _helmet_mat)
	_visor_mesh_inst = _add_mesh(_head_pivot, visor_mesh, Vector3.ZERO, _visor_mat, Vector3.ZERO, false)

	# Floating Friendly Diamond Marker (only visible on teammates)
	_ally_marker = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.20, 0.20, 0.20)
	_ally_marker.mesh = pm
	_ally_marker.position = Vector3(0.0, 0.62, 0.0)
	_ally_marker.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	var m_mat := StandardMaterial3D.new()
	m_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_mat.albedo_color = Color(0.22, 0.88, 1.0)
	_ally_marker.material_override = m_mat
	_ally_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head_pivot.add_child(_ally_marker)

	# Sculpted Arms + Rifle
	_left_arm = Node3D.new()
	_left_arm.position = Vector3(-0.26, 0.48, 0.0)
	_torso_pivot.add_child(_left_arm)
	_add_mesh(_left_arm, arm_mesh, Vector3.ZERO, _gear_mat, Vector3(0.0, -24.0, 0.0))

	_right_arm = Node3D.new()
	_right_arm.position = Vector3(0.26, 0.48, 0.0)
	_torso_pivot.add_child(_right_arm)
	_add_mesh(_right_arm, arm_mesh, Vector3.ZERO, _gear_mat, Vector3(0.0, 10.0, 0.0))

	_add_mesh(_right_arm, rifle_mesh, Vector3(-0.07, -0.18, -0.34), _gun_mat)

	_gun_muzzle = Marker3D.new()
	_gun_muzzle.position = Vector3(-0.07, -0.16, -0.84)
	_right_arm.add_child(_gun_muzzle)

	# Sculpted Legs
	_left_leg = Node3D.new()
	_left_leg.position = Vector3(-0.13, 0.78, 0.0)
	visual_root.add_child(_left_leg)
	_add_mesh(_left_leg, leg_mesh, Vector3.ZERO, _gear_mat)

	_right_leg = Node3D.new()
	_right_leg.position = Vector3(0.13, 0.78, 0.0)
	visual_root.add_child(_right_leg)
	_add_mesh(_right_leg, leg_mesh, Vector3.ZERO, _gear_mat)

func reset_for_round(spawn_pos: Vector3, p_team: int, p_name: String, lane: String, bomb_carrier: bool, arena_ref, all_agents: Array, p_role: int = 0) -> void:
	team = p_team
	agent_name = p_name
	_assigned_lane = lane
	_is_bomb_carrier = bomb_carrier
	_arena = arena_ref
	_agents_ref = all_agents
	_role_idx = posmod(p_role, 4)
	is_alive = true
	hp = 100
	weapon_id = WeaponData.WeaponId.M4_RIFLE if p_team == GameManager.Team.CT else WeaponData.WeaponId.AK47_RIFLE
	global_position = spawn_pos
	velocity = Vector3.ZERO
	_target_enemy = null
	_fire_cd = 0.0
	_burst_left = 0
	_burst_pause = 0.0
	_repath_timer = randf_range(0.0, 0.35)
	_reaction_timer = 0.22
	_objective_progress = 0.0
	_death_anim_t = 0.0
	_stuck_timer = 0.0
	visible = true
	visual_root.position = Vector3.ZERO
	visual_root.rotation = Vector3.ZERO
	_torso_pivot.position.y = 0.78
	_head_pivot.rotation = Vector3.ZERO
	_left_leg.rotation = Vector3.ZERO
	_right_leg.rotation = Vector3.ZERO

	body_collider.set_deferred("disabled", false)
	hitbox_body.set_deferred("monitoring", true)
	hitbox_body.set_deferred("monitorable", true)
	hitbox_head.set_deferred("monitoring", true)
	hitbox_head.set_deferred("monitorable", true)

	# Assign distinct 3D archetype silhouette per operator role
	_torso_mesh_inst.mesh = _torso_meshes[_role_idx]
	_helmet_mesh_inst.mesh = _helmet_meshes[_role_idx]
	_visor_mesh_inst.visible = (_role_idx != 2) # Recon uses quad-NVGs instead of curved visor

	var skin_tones := [
		Color(0.86, 0.68, 0.54),
		Color(0.72, 0.52, 0.38),
		Color(0.56, 0.39, 0.29),
		Color(0.90, 0.74, 0.62),
	]
	_skin_mat.set_shader_parameter("albedo_color", skin_tones[_role_idx])

	if team == GameManager.Team.CT:
		var ct_armors := [Color(0.16, 0.35, 0.68), Color(0.13, 0.26, 0.48), Color(0.20, 0.42, 0.58), Color(0.18, 0.28, 0.56)]
		var ct_visors := [Color(0.22, 0.85, 1.0), Color(0.35, 0.95, 0.85), Color(0.42, 0.72, 1.0), Color(0.68, 0.42, 1.0)]
		_armor_mat.set_shader_parameter("albedo_color", ct_armors[_role_idx])
		_helmet_mat.set_shader_parameter("albedo_color", Color(0.12, 0.16, 0.24))
		_gear_mat.set_shader_parameter("albedo_color", Color(0.16, 0.20, 0.28))
		_visor_mat.set_shader_parameter("albedo_color", ct_visors[_role_idx])
	else:
		var t_armors := [Color(0.74, 0.40, 0.16), Color(0.56, 0.20, 0.18), Color(0.34, 0.36, 0.24), Color(0.66, 0.30, 0.22)]
		var t_visors := [Color(1.0, 0.46, 0.14), Color(1.0, 0.22, 0.20), Color(1.0, 0.74, 0.20), Color(0.92, 0.30, 0.62)]
		_armor_mat.set_shader_parameter("albedo_color", t_armors[_role_idx])
		_helmet_mat.set_shader_parameter("albedo_color", Color(0.24, 0.18, 0.14))
		_gear_mat.set_shader_parameter("albedo_color", Color(0.22, 0.18, 0.16))
		_visor_mat.set_shader_parameter("albedo_color", t_visors[_role_idx])

	_ally_marker.visible = (team == GameManager.player_team)
	_set_flash(0.0)
	if global_position.distance_squared_to(Vector3.ZERO) > 0.05:
		look_at(Vector3(0.0, global_position.y, 0.0), Vector3.UP)
	rotation.x = 0.0
	rotation.z = 0.0

func _physics_process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_set_flash(0.0)

	if not is_alive:
		if _death_anim_t < 1.0:
			_death_anim_t = minf(1.0, _death_anim_t + delta * 5.2)
			visual_root.rotation.x = lerpf(0.0, deg_to_rad(86.0), _death_anim_t)
			visual_root.position.y = lerpf(0.0, 0.18, _death_anim_t)
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if GameManager.is_movement_frozen():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if _fire_cd > 0.0:
		_fire_cd -= delta
	if _burst_pause > 0.0:
		_burst_pause -= delta

	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = 0.35
		_update_target_and_destination()

	var has_los := _target_enemy != null and is_instance_valid(_target_enemy) and _target_enemy.is_alive and _has_line_of_sight(_target_enemy)

	if has_los:
		_stuck_timer = 0.0
		_face_point(_target_enemy.global_position, delta * 9.5)
		var dy := _target_enemy.global_position.y - global_position.y
		_head_pivot.rotation.x = clampf(dy * 0.08, -0.45, 0.45)
		_torso_pivot.position.y = lerpf(_torso_pivot.position.y, 0.68, clampf(delta * 8.0, 0.0, 1.0))
		_reaction_timer -= delta
		if _reaction_timer <= 0.0:
			_handle_combat_burst()
		var strafe := global_transform.basis.x * sin(Time.get_ticks_msec() * 0.0032 + float(get_instance_id() % 7)) * 1.6
		velocity.x = strafe.x
		velocity.z = strafe.z
	else:
		_head_pivot.rotation.x = lerpf(_head_pivot.rotation.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		_torso_pivot.position.y = lerpf(_torso_pivot.position.y, 0.78, clampf(delta * 8.0, 0.0, 1.0))
		_reaction_timer = randf_range(0.16, 0.30)
		_handle_navigation_and_objective(delta)

	move_and_slide()
	_animate_legs(delta)

func _update_target_and_destination() -> void:
	var best_enemy: Node3D = null
	var best_dist := 64.0
	for ag in _agents_ref:
		if not is_instance_valid(ag) or ag == self or not ag.is_alive or ag.team == team:
			continue
		var d := global_position.distance_to(ag.global_position)
		if d < best_dist and _has_line_of_sight(ag):
			best_dist = d
			best_enemy = ag
	_target_enemy = best_enemy

	if _arena == null:
		return
	var dest: Vector3 = _arena.tactical_waypoints.get(_assigned_lane, Vector3.ZERO)
	if GameManager.bomb_planted:
		dest = GameManager.bomb_position
	elif team == GameManager.Team.T and _is_bomb_carrier:
		dest = _arena.SITE_A_CENTER if _assigned_lane.begins_with("A") else _arena.SITE_B_CENTER
	nav_agent.target_position = dest

func _handle_navigation_and_objective(delta: float) -> void:
	if _arena == null:
		return

	if team == GameManager.Team.T and _is_bomb_carrier and not GameManager.bomb_planted and GameManager.state == GameManager.MatchState.LIVE:
		var site: String = _arena.get_site_at_position(global_position)
		if site != "":
			velocity.x = 0.0
			velocity.z = 0.0
			_torso_pivot.position.y = 0.62
			_objective_progress += delta
			if _objective_progress >= PLANT_TIME:
				_objective_progress = 0.0
				GameManager.plant_bomb(site, global_position)
			return
	elif team == GameManager.Team.CT and GameManager.bomb_planted and GameManager.state == GameManager.MatchState.BOMB_PLANTED:
		if global_position.distance_to(GameManager.bomb_position) <= 2.8:
			velocity.x = 0.0
			velocity.z = 0.0
			_torso_pivot.position.y = 0.62
			_objective_progress += delta
			if _objective_progress >= DEFUSE_TIME:
				_objective_progress = 0.0
				GameManager.defuse_bomb()
			return

	_objective_progress = 0.0
	if nav_agent.is_navigation_finished():
		# Patrol aggressively toward Mid or opposite site so enemies keep engaging
		var alt_lanes := ["MID", "A_SITE", "B_SITE", "A_SHORT", "B_CONN"]
		_assigned_lane = alt_lanes[randi() % alt_lanes.size()]
		_update_target_and_destination()
		velocity.x = lerpf(velocity.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		return

	var next_pt := nav_agent.get_next_path_position()
	var dir := next_pt - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.02:
		dir = dir.normalized()
		velocity.x = dir.x * MOVE_SPEED
		velocity.z = dir.z * MOVE_SPEED
		_face_point(global_position + dir * 4.0, delta * 7.5)

	if Vector2(velocity.x, velocity.z).length() < 0.55:
		_stuck_timer += delta
		if _stuck_timer > 1.1:
			_stuck_timer = 0.0
			var fallbacks := ["MID", "A_SHORT", "B_CONN", "A_LONG", "B_TUNNEL"]
			_assigned_lane = fallbacks[randi() % fallbacks.size()]
			_update_target_and_destination()
	else:
		_stuck_timer = 0.0

func _handle_combat_burst() -> void:
	if _burst_pause > 0.0 or _fire_cd > 0.0 or _target_enemy == null:
		return
	if _burst_left <= 0:
		_burst_left = randi_range(3, 5)
	_fire_at_target(_target_enemy)
	_burst_left -= 1
	_fire_cd = 0.13
	if _burst_left <= 0:
		_burst_pause = randf_range(0.30, 0.55)

func _fire_at_target(target: Node3D) -> void:
	var origin := global_position + Vector3(0.0, 1.48, 0.0)
	var aim_pt := target.global_position + Vector3(0.0, 1.25, 0.0)
	var base_dir := (aim_pt - origin).normalized()
	var spread := 0.052
	var dir := (base_dir + Vector3(randf_range(-spread, spread), randf_range(-spread * 0.7, spread * 0.7), randf_range(-spread, spread))).normalized()
	var end_pt := origin + dir * 75.0

	var query := PhysicsRayQueryParameters3D.create(origin, end_pt, 1 | 4 | 8)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = _exclude_rids

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var visual_end := end_pt
	if not hit.is_empty():
		visual_end = hit["position"]
		var col = hit["collider"]
		if col is Area3D and col.has_meta("owner_agent"):
			var victim = col.get_meta("owner_agent")
			if victim != null and victim != self and victim.team != team and victim.has_method("take_damage"):
				var is_head := bool(col.get_meta("is_head", false))
				var dmg := 17.0 * (2.1 if is_head else 1.0)
				var w_short := "M4A1" if team == GameManager.Team.CT else "AK-47"
				victim.take_damage(dmg, agent_name, team, w_short, is_head, false)
				if _arena != null and _arena.has_method("spawn_impact"):
					_arena.spawn_impact(hit["position"], hit["normal"], true)
		elif _arena != null and _arena.has_method("spawn_impact"):
			_arena.spawn_impact(hit["position"], hit["normal"], false)

	if _arena != null and _arena.has_method("spawn_tracer"):
		_arena.spawn_tracer(_gun_muzzle.global_position, visual_end)

func _has_line_of_sight(target: Node3D) -> bool:
	var from_pt := global_position + Vector3(0.0, 1.5, 0.0)
	var to_pt := target.global_position + Vector3(0.0, 1.35, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from_pt, to_pt, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty()

func _face_point(pt: Vector3, weight: float) -> void:
	var flat := Vector3(pt.x, global_position.y, pt.z)
	if flat.distance_squared_to(global_position) < 0.01:
		return
	var target_tf := global_transform.looking_at(flat, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(target_tf.basis, clampf(weight, 0.0, 1.0))

func _animate_legs(delta: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.3:
		_walk_phase += delta * spd * 2.5
		_left_leg.rotation.x = sin(_walk_phase) * 0.52
		_right_leg.rotation.x = -sin(_walk_phase) * 0.52
	else:
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))

func take_damage(amount: float, killer_name: String, killer_team: int, weapon_short: String, is_headshot: bool, killer_is_player: bool) -> bool:
	if not is_alive:
		return false
	hp = maxi(0, hp - int(round(amount)))
	_set_flash(1.0)
	_flash_timer = 0.09
	if _target_enemy == null and killer_team != team:
		_assigned_lane = "MID"
		_repath_timer = 0.05
	if hp <= 0:
		is_alive = false
		_ally_marker.visible = false
		hitbox_body.set_deferred("monitoring", false)
		hitbox_body.set_deferred("monitorable", false)
		hitbox_head.set_deferred("monitoring", false)
		hitbox_head.set_deferred("monitorable", false)
		body_collider.set_deferred("disabled", true)
		GameManager.register_kill(killer_name, killer_team, agent_name, team, weapon_short, is_headshot, killer_is_player)
		return true
	return false

func _set_flash(val: float) -> void:
	for m in _flash_mats:
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("flash_amount", val)
