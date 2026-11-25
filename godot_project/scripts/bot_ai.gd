extends CharacterBody3D

const GRAVITY := 20.0
const MOVE_SPEED := 4.85
const PLANT_TIME := 3.2
const DEFUSE_TIME := 5.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_root: Node3D = $VisualRoot
@onready var hitbox_body: Area3D = $HitboxBody
@onready var hitbox_head: Area3D = $HitboxHead
@onready var body_collider: CollisionShape3D = $BodyCollider

var team: int = GameManager.Team.CT
var agent_name: String = "Bot"
var is_alive: bool = true
var hp: int = 100
var weapon_id: int = WeaponData.WeaponId.AK47_RIFLE

var _arena: Node = null
var _agents_ref: Array = []
var _flash_mats: Array[ShaderMaterial] = []
var _flash_timer: float = 0.0
var _walk_phase: float = 0.0
var _left_leg: MeshInstance3D
var _right_leg: MeshInstance3D
var _gun_muzzle: Marker3D

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
	_build_lowpoly_soldier()
	hitbox_body.set_meta("owner_agent", self)
	hitbox_body.set_meta("is_head", false)
	hitbox_head.set_meta("owner_agent", self)
	hitbox_head.set_meta("is_head", true)
	_exclude_rids = [get_rid(), hitbox_body.get_rid(), hitbox_head.get_rid()]

func _build_lowpoly_soldier() -> void:
	var shader := ResourceLoader.load("res://shaders/hit_flash.gdshader") as Shader
	var armor_mat := ShaderMaterial.new()
	armor_mat.shader = shader
	armor_mat.set_shader_parameter("albedo_color", Color(0.18, 0.34, 0.62))

	var helmet_mat := ShaderMaterial.new()
	helmet_mat.shader = shader
	helmet_mat.set_shader_parameter("albedo_color", Color(0.14, 0.18, 0.24))

	var skin_mat := ShaderMaterial.new()
	skin_mat.shader = shader
	skin_mat.set_shader_parameter("albedo_color", Color(0.82, 0.66, 0.54))

	_flash_mats = [armor_mat, helmet_mat, skin_mat]

	# Torso
	_make_part(Vector3(0.0, 1.05, 0.0), Vector3(0.46, 0.62, 0.26), armor_mat)
	# Head + Helmet
	_make_part(Vector3(0.0, 1.54, 0.0), Vector3(0.28, 0.28, 0.28), skin_mat)
	_make_part(Vector3(0.0, 1.63, 0.0), Vector3(0.32, 0.16, 0.32), helmet_mat)
	# Arms
	_make_part(Vector3(-0.31, 1.08, -0.10), Vector3(0.15, 0.48, 0.16), armor_mat)
	_make_part(Vector3(0.31, 1.08, -0.16), Vector3(0.15, 0.48, 0.16), armor_mat)
	# Legs
	_left_leg = _make_part(Vector3(-0.13, 0.38, 0.0), Vector3(0.18, 0.72, 0.20), helmet_mat)
	_right_leg = _make_part(Vector3(0.13, 0.38, 0.0), Vector3(0.18, 0.72, 0.20), helmet_mat)

	# Low-poly Rifle in hand
	var gun := MeshInstance3D.new()
	var ak_mesh := ResourceLoader.load("res://assets/models/ak_rifle.obj") as Mesh
	if ak_mesh != null:
		gun.mesh = ak_mesh
	else:
		var gb := BoxMesh.new()
		gb.size = Vector3(0.06, 0.08, 0.62)
		gun.mesh = gb
	gun.position = Vector3(0.24, 1.16, -0.34)
	gun.material_override = helmet_mat
	visual_root.add_child(gun)

	_gun_muzzle = Marker3D.new()
	_gun_muzzle.position = Vector3(0.24, 1.18, -0.78)
	visual_root.add_child(_gun_muzzle)

func _make_part(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	visual_root.add_child(mi)
	return mi

func reset_for_round(spawn_pos: Vector3, p_team: int, p_name: String, lane: String, bomb_carrier: bool, arena_ref: Node, all_agents: Array) -> void:
	team = p_team
	agent_name = p_name
	_assigned_lane = lane
	_is_bomb_carrier = bomb_carrier
	_arena = arena_ref
	_agents_ref = all_agents
	is_alive = true
	hp = 100
	weapon_id = WeaponData.WeaponId.M4_RIFLE if p_team == GameManager.Team.CT else WeaponData.WeaponId.AK47_RIFLE
	global_position = spawn_pos
	velocity = Vector3.ZERO
	_target_enemy = null
	_fire_cd = 0.0
	_burst_left = 0
	_burst_pause = 0.0
	_repath_timer = randf_range(0.0, 0.4)
	_reaction_timer = 0.25
	_objective_progress = 0.0
	visible = true
	visual_root.position = Vector3.ZERO
	visual_root.rotation = Vector3.ZERO
	body_collider.disabled = false
	hitbox_body.monitoring = true
	hitbox_body.monitorable = true
	hitbox_head.monitoring = true
	hitbox_head.monitorable = true

	var team_col := Color(0.18, 0.36, 0.68) if team == GameManager.Team.CT else Color(0.68, 0.42, 0.18)
	_flash_mats[0].set_shader_parameter("albedo_color", team_col)
	_set_flash(0.0)
	look_at(Vector3.ZERO, Vector3.UP)
	rotation.x = 0.0
	rotation.z = 0.0

func _physics_process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_set_flash(0.0)

	if not is_alive:
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
		_face_point(_target_enemy.global_position, delta * 9.0)
		_reaction_timer -= delta
		if _reaction_timer <= 0.0:
			_handle_combat_burst()
		# Strafe slightly while shooting
		var strafe := global_transform.basis.x * sin(Time.get_ticks_msec() * 0.003 + float(get_instance_id() % 7)) * 1.4
		velocity.x = strafe.x
		velocity.z = strafe.z
	else:
		_reaction_timer = randf_range(0.18, 0.34)
		_handle_navigation_and_objective(delta)

	move_and_slide()
	_animate_legs(delta)

func _update_target_and_destination() -> void:
	var best_enemy: Node3D = null
	var best_dist := 46.0
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
	# Bomb plant / defuse logic
	if team == GameManager.Team.T and _is_bomb_carrier and not GameManager.bomb_planted and GameManager.state == GameManager.MatchState.LIVE:
		var site: String = _arena.get_site_at_position(global_position)
		if site != "":
			velocity.x = 0.0
			velocity.z = 0.0
			_objective_progress += delta
			if _objective_progress >= PLANT_TIME:
				_objective_progress = 0.0
				GameManager.plant_bomb(site, global_position)
			return
	elif team == GameManager.Team.CT and GameManager.bomb_planted and GameManager.state == GameManager.MatchState.BOMB_PLANTED:
		if global_position.distance_to(GameManager.bomb_position) <= 2.6:
			velocity.x = 0.0
			velocity.z = 0.0
			_objective_progress += delta
			if _objective_progress >= DEFUSE_TIME:
				_objective_progress = 0.0
				GameManager.defuse_bomb()
			return

	_objective_progress = 0.0
	if nav_agent.is_navigation_finished():
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
		_face_point(global_position + dir * 4.0, delta * 7.0)

func _handle_combat_burst() -> void:
	if _burst_pause > 0.0 or _fire_cd > 0.0 or _target_enemy == null:
		return
	if _burst_left <= 0:
		_burst_left = randi_range(3, 5)
	_fire_at_target(_target_enemy)
	_burst_left -= 1
	_fire_cd = 0.13
	if _burst_left <= 0:
		_burst_pause = randf_range(0.32, 0.58)

func _fire_at_target(target: Node3D) -> void:
	var origin := global_position + Vector3(0.0, 1.48, 0.0)
	var aim_pt := target.global_position + Vector3(0.0, 1.25, 0.0)
	var base_dir := (aim_pt - origin).normalized()
	var spread := 0.055
	var dir := (base_dir + Vector3(randf_range(-spread, spread), randf_range(-spread * 0.7, spread * 0.7), randf_range(-spread, spread))).normalized()
	var end_pt := origin + dir * 70.0

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
			if victim and victim != self and victim.team != team and victim.has_method("take_damage"):
				var is_head: bool = col.get_meta("is_head", false)
				var dmg := 18.0 * (2.2 if is_head else 1.0)
				var w_short := "M4A1" if team == GameManager.Team.CT else "AK-47"
				victim.take_damage(dmg, agent_name, team, w_short, is_head, false)

	if _arena and _arena.has_method("spawn_tracer"):
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
		_walk_phase += delta * spd * 2.4
		_left_leg.rotation.x = sin(_walk_phase) * 0.5
		_right_leg.rotation.x = -sin(_walk_phase) * 0.5
	else:
		_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))

func take_damage(amount: float, killer_name: String, killer_team: int, weapon_short: String, is_headshot: bool, killer_is_player: bool) -> bool:
	if not is_alive:
		return false
	hp = maxi(0, hp - int(round(amount)))
	_set_flash(1.0)
	_flash_timer = 0.09
	if hp <= 0:
		is_alive = false
		hitbox_body.monitoring = false
		hitbox_body.monitorable = false
		hitbox_head.monitoring = false
		hitbox_head.monitorable = false
		body_collider.disabled = true
		visual_root.rotation.x = deg_to_rad(86.0)
		visual_root.position.y = -0.35
		GameManager.register_kill(killer_name, killer_team, agent_name, team, weapon_short, is_headshot, killer_is_player)
		return true
	return false

func _set_flash(val: float) -> void:
	for m in _flash_mats:
		m.set_shader_parameter("flash_amount", val)
