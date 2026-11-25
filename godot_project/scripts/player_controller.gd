extends CharacterBody3D

signal health_changed(hp: int, armor: int)
signal weapon_changed(weapon_name: String, mag: int, reserve: int, slot: int, is_reloading: bool)
signal hitmarker_triggered(is_headshot: bool, killed: bool, dmg: int)
signal damage_taken_triggered()
signal action_prompt_changed(visible: bool, label: String, progress: float)
signal pov_changed(pov_mode: int)

enum PovMode {
	FIRST_PERSON = 0,
	SECOND_PERSON = 1,
	THIRD_PERSON = 2,
}

const GRAVITY := 20.0
const JUMP_SPEED := 6.7
const CROUCH_SPEED_MULT := 0.56
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.15
const PLANT_TIME := 3.0
const DEFUSE_TIME_BASE := 6.0
const DEFUSE_TIME_KIT := 3.5

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var viewmodel: Node3D = $Head/Camera3D/ViewModel
@onready var body_collider: CollisionShape3D = $BodyCollider
@onready var hitbox_body: Area3D = $HitboxBody
@onready var hitbox_head: Area3D = $HitboxHead

var team: int = 1
var agent_name: String = "You"
var is_alive: bool = true
var hp: int = 100
var armor: int = 0
var pov_mode: int = PovMode.FIRST_PERSON

var move_input: Vector2 = Vector2.ZERO
var is_crouching: bool = false
var is_ads: bool = false
var is_firing_held: bool = false
var is_action_held: bool = false

var _yaw: float = 0.0
var _pitch: float = 0.0
var _recoil_pitch_offset: float = 0.0
var _recoil_yaw_offset: float = 0.0
var _punch_roll: float = 0.0
var _spray_shots: int = 0
var _fire_cooldown: float = 0.0
var _reload_timer: float = 0.0
var _action_progress: float = 0.0
var _walk_phase: float = 0.0

var _current_slot: int = 2
var _weapons: Dictionary = {} # slot -> {id, mag, reserve}
var _exclude_rids: Array[RID] = []
var _agents_ref: Array = []

var arena: Node = null

# 3rd-person & 2nd-person camera rigs + sculpted player body
var _tpp_spring: SpringArm3D
var _tpp_camera: Camera3D
var _second_cam: Camera3D

var _body_visual: Node3D
var _body_torso: Node3D
var _body_head: Node3D
var _body_left_leg: Node3D
var _body_right_leg: Node3D
var _body_muzzle: Marker3D
var _p_armor_mat: StandardMaterial3D
var _p_gear_mat: StandardMaterial3D
var _p_visor_mat: StandardMaterial3D

func _ready() -> void:
	team = GameManager.Team.CT
	hitbox_body.set_meta("owner_agent", self)
	hitbox_body.set_meta("is_head", false)
	hitbox_head.set_meta("owner_agent", self)
	hitbox_head.set_meta("is_head", true)
	_exclude_rids.clear()
	_exclude_rids.append(get_rid())
	_exclude_rids.append(hitbox_body.get_rid())
	_exclude_rids.append(hitbox_head.get_rid())
	_setup_pov_cameras_and_body()
	_apply_pov_mode()

func _load_mesh(path: String) -> Mesh:
	var m := ResourceLoader.load(path) as Mesh
	if m != null:
		return m
	var fb := CapsuleMesh.new()
	fb.radius = 0.12
	fb.height = 0.4
	return fb

func _add_body_mesh(parent: Node3D, path: String, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _load_mesh(path)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _setup_pov_cameras_and_body() -> void:
	# 3rd-person SpringArm + Over-the-Shoulder Camera
	_tpp_spring = SpringArm3D.new()
	_tpp_spring.position = Vector3(0.56, 0.22, 0.0)
	_tpp_spring.spring_length = 2.75
	_tpp_spring.margin = 0.25
	_tpp_spring.collision_mask = 1
	head.add_child(_tpp_spring)

	_tpp_camera = Camera3D.new()
	_tpp_camera.fov = 78.0
	_tpp_camera.near = 0.05
	_tpp_camera.far = 180.0
	_tpp_spring.add_child(_tpp_camera)

	# 2nd-person Camera (views player from nearest enemy's / teammate's eyes)
	_second_cam = Camera3D.new()
	_second_cam.top_level = true
	_second_cam.fov = 76.0
	_second_cam.near = 0.05
	_second_cam.far = 180.0
	add_child(_second_cam)

	# Sculpted 3D Player Character Body (visible in 2nd & 3rd person)
	_p_armor_mat = StandardMaterial3D.new()
	_p_armor_mat.albedo_color = Color(0.18, 0.42, 0.78)
	_p_armor_mat.roughness = 0.72
	_p_armor_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	_p_gear_mat = StandardMaterial3D.new()
	_p_gear_mat.albedo_color = Color(0.16, 0.20, 0.28)
	_p_gear_mat.roughness = 0.80
	_p_gear_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	_p_visor_mat = StandardMaterial3D.new()
	_p_visor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_p_visor_mat.albedo_color = Color(0.25, 0.90, 1.0)

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.86, 0.68, 0.54)
	skin_mat.roughness = 0.82
	skin_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.14, 0.16, 0.20)
	gun_mat.roughness = 0.40

	_body_visual = Node3D.new()
	add_child(_body_visual)

	_body_torso = Node3D.new()
	_body_torso.position = Vector3(0.0, 0.78, 0.0)
	_body_visual.add_child(_body_torso)
	_add_body_mesh(_body_torso, "res://assets/models/op_torso_assault.obj", Vector3.ZERO, _p_armor_mat)

	_body_head = Node3D.new()
	_body_head.position = Vector3(0.0, 0.62, 0.0)
	_body_torso.add_child(_body_head)
	_add_body_mesh(_body_head, "res://assets/models/op_head_sculpted.obj", Vector3.ZERO, skin_mat)
	_add_body_mesh(_body_head, "res://assets/models/op_helmet_assault.obj", Vector3.ZERO, _p_gear_mat)
	_add_body_mesh(_body_head, "res://assets/models/op_visor_curved.obj", Vector3.ZERO, _p_visor_mat)

	_add_body_mesh(_body_torso, "res://assets/models/op_limb_arm.obj", Vector3(-0.26, 0.48, 0.0), _p_gear_mat, Vector3(0.0, -24.0, 0.0))
	var right_arm := Node3D.new()
	right_arm.position = Vector3(0.26, 0.48, 0.0)
	_body_torso.add_child(right_arm)
	_add_body_mesh(right_arm, "res://assets/models/op_limb_arm.obj", Vector3.ZERO, _p_gear_mat, Vector3(0.0, 10.0, 0.0))
	_add_body_mesh(right_arm, "res://assets/models/op_rifle_world.obj", Vector3(-0.07, -0.18, -0.34), gun_mat)

	_body_muzzle = Marker3D.new()
	_body_muzzle.position = Vector3(-0.07, -0.16, -0.84)
	right_arm.add_child(_body_muzzle)

	_body_left_leg = Node3D.new()
	_body_left_leg.position = Vector3(-0.13, 0.78, 0.0)
	_body_visual.add_child(_body_left_leg)
	_add_body_mesh(_body_left_leg, "res://assets/models/op_limb_leg.obj", Vector3.ZERO, _p_gear_mat)

	_body_right_leg = Node3D.new()
	_body_right_leg.position = Vector3(0.13, 0.78, 0.0)
	_body_visual.add_child(_body_right_leg)
	_add_body_mesh(_body_right_leg, "res://assets/models/op_limb_leg.obj", Vector3.ZERO, _p_gear_mat)

func cycle_pov() -> void:
	pov_mode = (pov_mode + 1) % 3
	_apply_pov_mode()
	pov_changed.emit(pov_mode)

func _apply_pov_mode() -> void:
	if camera == null or _tpp_camera == null or _second_cam == null:
		return
	if not is_alive:
		return
	match pov_mode:
		PovMode.FIRST_PERSON:
			_body_visual.visible = false
			viewmodel.visible = true
			camera.current = true
		PovMode.SECOND_PERSON:
			_body_visual.visible = true
			viewmodel.visible = false
			_update_second_person_camera()
			_second_cam.current = true
		PovMode.THIRD_PERSON:
			_body_visual.visible = true
			viewmodel.visible = false
			_tpp_camera.current = true

func _update_second_person_camera() -> void:
	var best_observer: Node3D = null
	var best_dist := 99999.0
	# Prefer nearest living enemy watching the player; fallback to nearest living teammate
	for pass_idx in 2:
		for ag in _agents_ref:
			if not is_instance_valid(ag) or ag == self or not ag.is_alive:
				continue
			if pass_idx == 0 and ag.team == team:
				continue
			var d := global_position.distance_squared_to(ag.global_position)
			if d < best_dist:
				best_dist = d
				best_observer = ag
		if best_observer != null:
			break

	var look_target := global_position + Vector3(0.0, 1.28, 0.0)
	if best_observer != null:
		var obs_eye := best_observer.global_position + Vector3(0.0, 1.62, 0.0)
		var to_player := (look_target - obs_eye).normalized()
		if to_player.length_squared() < 0.001:
			to_player = -global_transform.basis.z
		_second_cam.global_position = obs_eye + to_player * 0.42
	else:
		_second_cam.global_position = global_position + Vector3(0.0, 2.2, 3.2)

	if _second_cam.global_position.distance_squared_to(look_target) > 0.05:
		var up_vec := Vector3.UP if absf((look_target - _second_cam.global_position).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		_second_cam.look_at(look_target, up_vec)

func reset_for_round(spawn_pos: Vector3, look_yaw: float, p_team: int, arena_ref: Node, all_agents: Array = []) -> void:
	arena = arena_ref
	_agents_ref = all_agents
	team = p_team
	is_alive = true
	hp = 100
	armor = 100 if GameManager.player_has_armor else 0
	global_position = spawn_pos
	velocity = Vector3.ZERO
	_yaw = look_yaw
	_pitch = 0.0
	_recoil_pitch_offset = 0.0
	_recoil_yaw_offset = 0.0
	_punch_roll = 0.0
	_spray_shots = 0
	_fire_cooldown = 0.0
	_reload_timer = 0.0
	_action_progress = 0.0
	_walk_phase = 0.0
	is_crouching = false
	is_ads = false
	is_firing_held = false
	is_action_held = false
	visible = true
	hitbox_body.set_deferred("monitoring", true)
	hitbox_body.set_deferred("monitorable", true)
	hitbox_head.set_deferred("monitoring", true)
	hitbox_head.set_deferred("monitorable", true)

	if team == GameManager.Team.CT:
		_p_armor_mat.albedo_color = Color(0.18, 0.42, 0.78)
		_p_gear_mat.albedo_color = Color(0.14, 0.18, 0.26)
		_p_visor_mat.albedo_color = Color(0.25, 0.90, 1.0)
	else:
		_p_armor_mat.albedo_color = Color(0.76, 0.42, 0.18)
		_p_gear_mat.albedo_color = Color(0.24, 0.18, 0.15)
		_p_visor_mat.albedo_color = Color(1.0, 0.44, 0.16)

	_apply_pov_mode()
	pov_changed.emit(pov_mode)

	_weapons.clear()
	_weapons[3] = {"id": WeaponData.WeaponId.KNIFE, "mag": 0, "reserve": 0}
	var sec_id := GameManager.player_secondary_weapon
	var sec_stats := WeaponData.get_stats(sec_id)
	_weapons[2] = {"id": sec_id, "mag": sec_stats["mag_size"], "reserve": sec_stats["reserve_max"]}
	if GameManager.player_primary_weapon != -1:
		var pri_stats := WeaponData.get_stats(GameManager.player_primary_weapon)
		_weapons[1] = {"id": GameManager.player_primary_weapon, "mag": pri_stats["mag_size"], "reserve": pri_stats["reserve_max"]}
	if GameManager.player_has_grenade:
		_weapons[4] = {"id": WeaponData.WeaponId.HE_GRENADE, "mag": 1, "reserve": 0}

	if _weapons.has(1):
		equip_slot(1)
	else:
		equip_slot(2)

	health_changed.emit(hp, armor)

func give_weapon(weapon_id: int) -> void:
	var stats := WeaponData.get_stats(weapon_id)
	var slot: int = stats["slot"]
	_weapons[slot] = {"id": weapon_id, "mag": stats["mag_size"], "reserve": stats["reserve_max"]}
	equip_slot(slot)

func apply_armor() -> void:
	armor = 100
	health_changed.emit(hp, armor)

func has_slot(slot: int) -> bool:
	return _weapons.has(slot)

func equip_slot(slot: int) -> void:
	if not _weapons.has(slot):
		return
	_current_slot = slot
	_reload_timer = 0.0
	is_ads = false
	viewmodel.set_reloading(false)
	viewmodel.set_ads(false)
	var w: Dictionary = _weapons[_current_slot]
	viewmodel.equip_weapon(w["id"])
	_emit_weapon_ui()

func cycle_weapon() -> void:
	var order := [1, 2, 3, 4]
	var idx := order.find(_current_slot)
	for step in range(1, 5):
		var next_slot: int = order[(idx + step) % 4]
		if _weapons.has(next_slot):
			equip_slot(next_slot)
			return

func add_look_delta(delta_px: Vector2) -> void:
	if not is_alive:
		return
	var sens := GameManager.touch_sensitivity * (0.62 if is_ads else 1.0)
	_yaw -= deg_to_rad(delta_px.x * sens)
	_pitch = clampf(_pitch - deg_to_rad(delta_px.y * sens), deg_to_rad(-82.0), deg_to_rad(82.0))

func trigger_jump() -> void:
	if is_alive and is_on_floor() and not GameManager.is_movement_frozen():
		velocity.y = JUMP_SPEED

func toggle_crouch() -> void:
	is_crouching = not is_crouching

func toggle_ads() -> void:
	var w: Dictionary = _weapons.get(_current_slot, {})
	if w.is_empty() or w["id"] == WeaponData.WeaponId.KNIFE or w["id"] == WeaponData.WeaponId.HE_GRENADE:
		is_ads = false
	else:
		is_ads = not is_ads
	viewmodel.set_ads(is_ads)

func trigger_reload() -> void:
	if not is_alive or _reload_timer > 0.0:
		return
	var w: Dictionary = _weapons.get(_current_slot, {})
	if w.is_empty():
		return
	var stats := WeaponData.get_stats(w["id"])
	if stats["is_melee"] or stats["is_grenade"] or w["mag"] >= stats["mag_size"] or w["reserve"] <= 0:
		return
	_reload_timer = stats["reload_time"]
	is_ads = false
	viewmodel.set_ads(false)
	viewmodel.set_reloading(true)
	AudioManager.play_sfx("reload", -6.0, 0.03)
	_emit_weapon_ui()

func set_fire_pressed(pressed: bool) -> void:
	var was_pressed := is_firing_held
	is_firing_held = pressed
	if pressed and not was_pressed and is_alive:
		_try_fire()

func _physics_process(delta: float) -> void:
	if not is_alive or _weapons.is_empty():
		return

	var kb_move := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	var active_move := move_input if move_input.length_squared() > 0.01 else kb_move
	if active_move.length() > 1.0:
		active_move = active_move.normalized()

	var w: Dictionary = _weapons.get(_current_slot, _weapons[2])
	var stats := WeaponData.get_stats(w["id"])

	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()

	if is_firing_held and stats["auto"] and _fire_cooldown <= 0.0:
		_try_fire()
	elif not is_firing_held:
		_spray_shots = maxi(0, _spray_shots - 1)
		_recoil_pitch_offset = lerpf(_recoil_pitch_offset, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_recoil_yaw_offset = lerpf(_recoil_yaw_offset, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	_punch_roll = lerpf(_punch_roll, 0.0, clampf(delta * 12.0, 0.0, 1.0))

	var target_eye_y := 0.98 if is_crouching else 1.54
	head.position.y = lerpf(head.position.y, target_eye_y, clampf(delta * 12.0, 0.0, 1.0))
	var col_shape := body_collider.shape as CapsuleShape3D
	if col_shape:
		var target_h := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
		col_shape.height = lerpf(col_shape.height, target_h, clampf(delta * 12.0, 0.0, 1.0))
		body_collider.position.y = col_shape.height * 0.5

	var target_fov: float = stats["ads_fov"] if is_ads else (78.0 if pov_mode == PovMode.THIRD_PERSON else 75.0)
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 14.0, 0.0, 1.0))
	_tpp_camera.fov = camera.fov

	rotation.y = _yaw + _recoil_yaw_offset
	head.rotation.x = clampf(_pitch + _recoil_pitch_offset, deg_to_rad(-85.0), deg_to_rad(85.0))
	head.rotation.z = _punch_roll

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if GameManager.is_movement_frozen():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var max_spd: float = stats["move_speed"] * (CROUCH_SPEED_MULT if is_crouching else 1.0) * (0.78 if is_ads else 1.0)
		var forward := -global_transform.basis.z
		var right := global_transform.basis.x
		var wish_dir := (right * active_move.x + forward * -active_move.y)
		wish_dir.y = 0.0
		if wish_dir.length_squared() > 0.001:
			wish_dir = wish_dir.normalized()
		var target_vel := wish_dir * (max_spd * active_move.length())
		var accel := 18.0 if is_on_floor() else 4.5
		velocity.x = lerpf(velocity.x, target_vel.x, clampf(delta * accel, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, target_vel.z, clampf(delta * accel, 0.0, 1.0))

	move_and_slide()

	var h_speed := Vector2(velocity.x, velocity.z).length()
	if pov_mode == PovMode.FIRST_PERSON:
		viewmodel.update_motion(delta, clampf(h_speed / 6.0, 0.0, 1.0), is_on_floor())
	else:
		_animate_body_visual(delta, h_speed)
		if pov_mode == PovMode.SECOND_PERSON:
			_update_second_person_camera()

	_handle_bomb_interaction(delta)

func _animate_body_visual(delta: float, h_speed: float) -> void:
	_body_torso.position.y = lerpf(_body_torso.position.y, 0.62 if is_crouching else 0.78, clampf(delta * 10.0, 0.0, 1.0))
	_body_head.rotation.x = clampf(_pitch * 0.65, -0.55, 0.55)
	if h_speed > 0.3:
		_walk_phase += delta * h_speed * 2.5
		_body_left_leg.rotation.x = sin(_walk_phase) * 0.52
		_body_right_leg.rotation.x = -sin(_walk_phase) * 0.52
	else:
		_body_left_leg.rotation.x = lerpf(_body_left_leg.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))
		_body_right_leg.rotation.x = lerpf(_body_right_leg.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))

func _try_fire() -> void:
	if not is_alive or GameManager.is_movement_frozen() or _fire_cooldown > 0.0 or _reload_timer > 0.0:
		return
	var w: Dictionary = _weapons[_current_slot]
	var stats := WeaponData.get_stats(w["id"])

	if stats["is_grenade"]:
		_fire_cooldown = stats["fire_rate"]
		viewmodel.trigger_fire()
		AudioManager.play_sfx("throw", -4.0, 0.05)
		var throw_dir := -head.global_transform.basis.z
		if arena != null and arena.has_method("throw_grenade"):
			arena.throw_grenade(head.global_position + throw_dir * 0.7, throw_dir, agent_name, team)
		GameManager.player_has_grenade = false
		_weapons.erase(4)
		equip_slot(1 if _weapons.has(1) else 2)
		return

	if not stats["is_melee"] and w["mag"] <= 0:
		trigger_reload()
		return

	_fire_cooldown = stats["fire_rate"]
	if not stats["is_melee"]:
		w["mag"] -= 1
		_emit_weapon_ui()

	viewmodel.trigger_fire()

	match stats["id"]:
		WeaponData.WeaponId.KNIFE:
			AudioManager.play_sfx("knife", -5.0, 0.08)
		WeaponData.WeaponId.MP5_SMG:
			AudioManager.play_sfx("smg", -4.0, 0.06)
		WeaponData.WeaponId.USP_PISTOL, WeaponData.WeaponId.GLOCK_PISTOL:
			AudioManager.play_sfx("pistol", -4.0, 0.06)
		_:
			AudioManager.play_sfx("rifle", -3.0, 0.05)

	var h_speed := Vector2(velocity.x, velocity.z).length()
	var move_factor := clampf(h_speed / 5.5, 0.0, 1.0)
	var spread: float = stats["base_spread"] + stats["move_spread"] * move_factor
	if is_crouching:
		spread *= 0.55
	if is_ads:
		spread *= 0.50
	if not is_on_floor():
		spread += 0.045
	spread += minf(0.035, float(_spray_shots) * 0.0025)

	# Aim raycast: in 3rd-person, converge crosshair hit from TPP camera toward head ray origin
	var ray_origin := head.global_position
	var aim_basis := head.global_transform.basis
	if pov_mode == PovMode.THIRD_PERSON:
		var tpp_from := _tpp_camera.global_position
		var tpp_to := tpp_from + (-_tpp_camera.global_transform.basis.z) * float(stats["range"])
		var tpp_q := PhysicsRayQueryParameters3D.create(tpp_from, tpp_to, 1 | 4 | 8)
		tpp_q.collide_with_areas = true
		tpp_q.collide_with_bodies = true
		tpp_q.exclude = _exclude_rids
		var tpp_hit := get_world_3d().direct_space_state.intersect_ray(tpp_q)
		var converge_pt := tpp_hit["position"] if not tpp_hit.is_empty() else tpp_to
		var dir_to_pt := (converge_pt - ray_origin).normalized()
		if dir_to_pt.length_squared() > 0.01:
			var base_dir := dir_to_pt
			var ray_dir_tpp := (base_dir + _tpp_camera.global_transform.basis.x * randf_range(-spread, spread) + _tpp_camera.global_transform.basis.y * randf_range(-spread, spread)).normalized()
			_execute_bullet_ray(ray_origin, ray_dir_tpp, stats)
			return

	var cam_forward := -aim_basis.z
	var cam_right := aim_basis.x
	var cam_up := aim_basis.y
	var ray_dir := (cam_forward + cam_right * randf_range(-spread, spread) + cam_up * randf_range(-spread, spread)).normalized()
	_execute_bullet_ray(ray_origin, ray_dir, stats)

func _execute_bullet_ray(ray_origin: Vector3, ray_dir: Vector3, stats: Dictionary) -> void:
	var ray_end := ray_origin + ray_dir * float(stats["range"])
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 1 | 4 | 8)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = _exclude_rids

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var visual_end := ray_end
	if not hit.is_empty():
		visual_end = hit["position"]
		var collider = hit["collider"]
		if collider is Area3D and collider.has_meta("owner_agent"):
			var target = collider.get_meta("owner_agent")
			var is_head := bool(collider.get_meta("is_head", false))
			if target and target != self and target.has_method("take_damage") and target.team != team:
				var dmg: float = stats["damage"] * (stats["head_mult"] if is_head else 1.0)
				var killed: bool = target.take_damage(dmg, agent_name, team, stats["short"], is_head, true)
				AudioManager.play_sfx("headshot" if is_head else "hit", -3.0, 0.04)
				hitmarker_triggered.emit(is_head, killed, int(round(dmg)))
				if arena != null and arena.has_method("spawn_impact"):
					arena.spawn_impact(hit["position"], hit["normal"], true)
		elif arena != null and arena.has_method("spawn_impact"):
			arena.spawn_impact(hit["position"], hit["normal"], false)

	if not stats["is_melee"] and arena and arena.has_method("spawn_tracer"):
		var muzzle_pos := viewmodel.get_muzzle_world_pos() if pov_mode == PovMode.FIRST_PERSON else _body_muzzle.global_position
		arena.spawn_tracer(muzzle_pos, visual_end)

	_spray_shots += 1
	_recoil_pitch_offset = clampf(_recoil_pitch_offset + deg_to_rad(stats["recoil_pitch"]), 0.0, deg_to_rad(14.0))
	var yaw_jitter := randf_range(-float(stats["recoil_yaw"]), float(stats["recoil_yaw"]))
	_recoil_yaw_offset = clampf(_recoil_yaw_offset + deg_to_rad(yaw_jitter), deg_to_rad(-6.0), deg_to_rad(6.0))

func _finish_reload() -> void:
	viewmodel.set_reloading(false)
	var w: Dictionary = _weapons[_current_slot]
	var stats := WeaponData.get_stats(w["id"])
	var needed: int = stats["mag_size"] - w["mag"]
	var take := mini(needed, w["reserve"])
	w["mag"] += take
	w["reserve"] -= take
	_emit_weapon_ui()

func _handle_bomb_interaction(delta: float) -> void:
	if arena == null or GameManager.state == GameManager.MatchState.FREEZE_BUY or GameManager.state == GameManager.MatchState.ROUND_END:
		action_prompt_changed.emit(false, "", 0.0)
		return

	if team == GameManager.Team.T and not GameManager.bomb_planted and GameManager.state == GameManager.MatchState.LIVE:
		var site: String = arena.get_site_at_position(global_position)
		if site != "":
			if is_action_held:
				_action_progress += delta / PLANT_TIME
				action_prompt_changed.emit(true, "PLANTING C4 AT SITE " + site, clampf(_action_progress, 0.0, 1.0))
				if _action_progress >= 1.0:
					_action_progress = 0.0
					GameManager.plant_bomb(site, global_position)
					action_prompt_changed.emit(false, "", 0.0)
			else:
				_action_progress = 0.0
				action_prompt_changed.emit(true, "HOLD TO PLANT AT SITE " + site, 0.0)
			return
	elif team == GameManager.Team.CT and GameManager.bomb_planted and GameManager.state == GameManager.MatchState.BOMB_PLANTED:
		if global_position.distance_to(GameManager.bomb_position) <= 3.2:
			var req_time := DEFUSE_TIME_KIT if GameManager.player_has_defuse_kit else DEFUSE_TIME_BASE
			if is_action_held:
				_action_progress += delta / req_time
				action_prompt_changed.emit(true, "DEFUSING C4", clampf(_action_progress, 0.0, 1.0))
				if _action_progress >= 1.0:
					_action_progress = 0.0
					GameManager.defuse_bomb()
					action_prompt_changed.emit(false, "", 0.0)
			else:
				_action_progress = 0.0
				action_prompt_changed.emit(true, "HOLD TO DEFUSE C4", 0.0)
			return

	_action_progress = 0.0
	action_prompt_changed.emit(false, "", 0.0)

func take_damage(amount: float, killer_name: String, killer_team: int, weapon_short: String, is_headshot: bool, killer_is_player: bool) -> bool:
	if not is_alive:
		return false
	var actual := amount
	if armor > 0:
		var absorbed := minf(float(armor), amount * 0.42)
		armor = maxi(0, armor - int(round(absorbed)))
		actual -= absorbed * 0.65
	hp = maxi(0, hp - int(round(actual)))
	_punch_roll = randf_range(-0.04, 0.04)
	health_changed.emit(hp, armor)
	damage_taken_triggered.emit()
	if hp <= 0:
		is_alive = false
		visible = false
		hitbox_body.set_deferred("monitoring", false)
		hitbox_body.set_deferred("monitorable", false)
		hitbox_head.set_deferred("monitoring", false)
		hitbox_head.set_deferred("monitorable", false)
		GameManager.register_kill(killer_name, killer_team, agent_name, team, weapon_short, is_headshot, killer_is_player)
		return true
	return false

func _emit_weapon_ui() -> void:
	var w: Dictionary = _weapons[_current_slot]
	var stats := WeaponData.get_stats(w["id"])
	weapon_changed.emit(stats["short"], w["mag"], w["reserve"], _current_slot, _reload_timer > 0.0)

func get_current_spread_px() -> float:
	var w: Dictionary = _weapons.get(_current_slot, _weapons[2])
	var stats := WeaponData.get_stats(w["id"])
	var h_speed := Vector2(velocity.x, velocity.z).length()
	var spread: float = stats["base_spread"] + stats["move_spread"] * clampf(h_speed / 5.5, 0.0, 1.0)
	if is_crouching:
		spread *= 0.55
	if is_ads:
		spread *= 0.50
	return 8.0 + spread * 480.0 + float(_spray_shots) * 1.4
