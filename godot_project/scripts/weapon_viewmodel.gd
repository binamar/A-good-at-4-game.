extends Node3D

@onready var gun_anchor: Node3D = $GunAnchor
@onready var muzzle_flash: MeshInstance3D = $GunAnchor/MuzzleFlash

var _ak_node: Node3D
var _m4_node: Node3D
var _mp5_node: Node3D
var _usp_node: Node3D
var _glock_node: Node3D
var _knife_node: Node3D
var _grenade_node: Node3D
var _arms_node: Node3D

var _pistol_slide: MeshInstance3D
var _glock_slide: MeshInstance3D
var _muzzle_light: OmniLight3D

var _base_pos := Vector3(0.24, -0.23, -0.44)
var _ads_pos := Vector3(0.0, -0.175, -0.35)

var _bob_time := 0.0
var _recoil_z := 0.0
var _recoil_rot := 0.0
var _slide_kick := 0.0
var _flash_timer := 0.0
var _reload_angle := 0.0
var _is_reloading := false
var _is_ads := false
var _current_id := 1

func _ready() -> void:
	_build_sculpted_viewmodels()
	muzzle_flash.visible = false
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.78, 0.40)
	_muzzle_light.light_energy = 2.2
	_muzzle_light.omni_range = 4.0
	_muzzle_light.shadow_enabled = false
	_muzzle_light.visible = false
	muzzle_flash.add_child(_muzzle_light)
	equip_weapon(WeaponData.WeaponId.USP_PISTOL)

func _make_mat(col: Color, rough: float, metal: float, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _load_mesh(path: String) -> Mesh:
	var m := ResourceLoader.load(path) as Mesh
	if m != null:
		return m
	var fallback := BoxMesh.new()
	fallback.size = Vector3(0.05, 0.05, 0.2)
	return fallback

func _add_mesh(parent: Node3D, mesh_res: Mesh, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_res
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _add_sight_pip(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = sz.x * 0.5
	sm.height = sz.y
	sm.radial_segments = 6
	sm.rings = 4
	mi.mesh = sm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _build_sculpted_viewmodels() -> void:
	var steel_dark := _make_mat(Color(0.14, 0.16, 0.20), 0.40, 0.78)
	var gunmetal := _make_mat(Color(0.25, 0.28, 0.33), 0.34, 0.82)
	var polymer := _make_mat(Color(0.09, 0.10, 0.12), 0.76, 0.10)
	var walnut := _make_mat(Color(0.46, 0.24, 0.12), 0.68, 0.05)
	var chrome := _make_mat(Color(0.78, 0.82, 0.88), 0.18, 0.92)
	var tritium := _make_mat(Color(0.25, 1.0, 0.45), 0.2, 0.0, true)
	var red_dot := _make_mat(Color(1.0, 0.24, 0.18), 0.2, 0.0, true)
	var olive := _make_mat(Color(0.24, 0.34, 0.20), 0.70, 0.18)

	var camo_tex := ResourceLoader.load("res://assets/textures/tactical_camo.png") as Texture2D
	var camo_n := ResourceLoader.load("res://assets/textures/tactical_camo_normal.png") as Texture2D
	var sleeve_mat := StandardMaterial3D.new()
	if camo_tex != null:
		sleeve_mat.albedo_texture = camo_tex
	if camo_n != null:
		sleeve_mat.normal_enabled = true
		sleeve_mat.normal_texture = camo_n
	sleeve_mat.albedo_color = Color(0.32, 0.38, 0.46)
	sleeve_mat.roughness = 0.86
	var glove_mat := _make_mat(Color(0.11, 0.12, 0.14), 0.80, 0.06)

	var sleeve_mesh := _load_mesh("res://assets/models/fp_arm_sleeve.obj")
	var glove_mesh := _load_mesh("res://assets/models/fp_glove.obj")

	# Sculpted First-Person Tactical Arms & Gloves
	_arms_node = Node3D.new()
	gun_anchor.add_child(_arms_node)
	_add_mesh(_arms_node, sleeve_mesh, Vector3(0.055, -0.15, 0.22), sleeve_mat, Vector3(22, -12, 0))
	_add_mesh(_arms_node, glove_mesh, Vector3(0.005, -0.085, 0.07), glove_mat, Vector3(10, 0, 0))
	_add_mesh(_arms_node, sleeve_mesh, Vector3(-0.17, -0.13, -0.04), sleeve_mat, Vector3(16, 32, 0))
	_add_mesh(_arms_node, glove_mesh, Vector3(-0.035, -0.06, -0.17), glove_mat, Vector3(0, 18, 0))

	# 1. AK-47 (Sculpted steel receiver + curved banana mag + walnut furniture)
	_ak_node = Node3D.new()
	gun_anchor.add_child(_ak_node)
	_add_mesh(_ak_node, _load_mesh("res://assets/models/vm_ak_body.obj"), Vector3.ZERO, steel_dark)
	_add_mesh(_ak_node, _load_mesh("res://assets/models/vm_ak_furniture.obj"), Vector3.ZERO, walnut)

	# 2. M4A1-Carbine (Sculpted receiver, round quad-rail, suppressor, glowing holographic dot)
	_m4_node = Node3D.new()
	gun_anchor.add_child(_m4_node)
	_add_mesh(_m4_node, _load_mesh("res://assets/models/vm_m4_body.obj"), Vector3.ZERO, gunmetal)
	_add_sight_pip(_m4_node, Vector3(0, 0.074, -0.01), Vector3(0.009, 0.009, 0.009), red_dot)

	# 3. MP5-SD (Sculpted SMG + cylindrical suppressor + curved mag)
	_mp5_node = Node3D.new()
	gun_anchor.add_child(_mp5_node)
	_add_mesh(_mp5_node, _load_mesh("res://assets/models/vm_mp5_body.obj"), Vector3.ZERO, steel_dark)

	# 4. USP-Tactical (Beveled reciprocating slide + contoured polymer frame + suppressor + tritium sights)
	_usp_node = Node3D.new()
	gun_anchor.add_child(_usp_node)
	_pistol_slide = _add_mesh(_usp_node, _load_mesh("res://assets/models/vm_usp_slide.obj"), Vector3(0, 0.032, -0.04), gunmetal)
	_add_mesh(_usp_node, _load_mesh("res://assets/models/vm_usp_frame.obj"), Vector3.ZERO, polymer)
	_add_sight_pip(_usp_node, Vector3(0, 0.055, -0.13), Vector3(0.007, 0.007, 0.007), tritium)
	_add_sight_pip(_usp_node, Vector3(-0.010, 0.055, 0.055), Vector3(0.006, 0.006, 0.006), tritium)
	_add_sight_pip(_usp_node, Vector3(0.010, 0.055, 0.055), Vector3(0.006, 0.006, 0.006), tritium)

	# 5. Glock-18C (Chamfered slide + angled grip + tritium sight)
	_glock_node = Node3D.new()
	gun_anchor.add_child(_glock_node)
	_glock_slide = _add_mesh(_glock_node, _load_mesh("res://assets/models/vm_glock_slide.obj"), Vector3(0, 0.030, -0.04), steel_dark)
	_add_mesh(_glock_node, _load_mesh("res://assets/models/vm_glock_frame.obj"), Vector3.ZERO, polymer)
	_add_sight_pip(_glock_node, Vector3(0, 0.052, -0.12), Vector3(0.007, 0.007, 0.007), tritium)

	# 6. Tactical Combat Knife
	_knife_node = Node3D.new()
	_knife_node.rotation_degrees = Vector3(-14.0, 20.0, 0.0)
	gun_anchor.add_child(_knife_node)
	_add_mesh(_knife_node, _load_mesh("res://assets/models/vm_knife_handle.obj"), Vector3.ZERO, walnut)
	_add_mesh(_knife_node, _load_mesh("res://assets/models/vm_knife_blade.obj"), Vector3.ZERO, chrome)

	# 7. HE Frag Grenade
	_grenade_node = Node3D.new()
	gun_anchor.add_child(_grenade_node)
	_add_mesh(_grenade_node, _load_mesh("res://assets/models/vm_grenade_body.obj"), Vector3.ZERO, olive)

func equip_weapon(weapon_id: int) -> void:
	_current_id = weapon_id
	_ak_node.visible = (weapon_id == WeaponData.WeaponId.AK47_RIFLE)
	_m4_node.visible = (weapon_id == WeaponData.WeaponId.M4_RIFLE)
	_mp5_node.visible = (weapon_id == WeaponData.WeaponId.MP5_SMG)
	_usp_node.visible = (weapon_id == WeaponData.WeaponId.USP_PISTOL)
	_glock_node.visible = (weapon_id == WeaponData.WeaponId.GLOCK_PISTOL)
	_knife_node.visible = (weapon_id == WeaponData.WeaponId.KNIFE)
	_grenade_node.visible = (weapon_id == WeaponData.WeaponId.HE_GRENADE)
	_recoil_z = 0.08
	_recoil_rot = -0.16

func trigger_fire() -> void:
	if _current_id == WeaponData.WeaponId.KNIFE or _current_id == WeaponData.WeaponId.HE_GRENADE:
		_recoil_z = -0.15
		_recoil_rot = -0.48
	else:
		_recoil_z = 0.075
		_recoil_rot = 0.14
		_slide_kick = 0.055
		_flash_timer = 0.045
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf() * TAU
		if _muzzle_light != null:
			_muzzle_light.visible = true

func set_reloading(reloading: bool) -> void:
	_is_reloading = reloading

func set_ads(ads: bool) -> void:
	_is_ads = ads

func update_motion(delta: float, move_speed_ratio: float, on_floor: bool) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			muzzle_flash.visible = false
			if _muzzle_light != null:
				_muzzle_light.visible = false

	_recoil_z = lerpf(_recoil_z, 0.0, clampf(delta * 16.0, 0.0, 1.0))
	_recoil_rot = lerpf(_recoil_rot, 0.0, clampf(delta * 14.0, 0.0, 1.0))
	_slide_kick = lerpf(_slide_kick, 0.0, clampf(delta * 22.0, 0.0, 1.0))
	_reload_angle = lerpf(_reload_angle, -0.68 if _is_reloading else 0.0, clampf(delta * 10.0, 0.0, 1.0))

	if _pistol_slide != null:
		_pistol_slide.position.z = -0.04 + _slide_kick * 0.7
	if _glock_slide != null:
		_glock_slide.position.z = -0.04 + _slide_kick * 0.7

	if on_floor and move_speed_ratio > 0.08:
		_bob_time += delta * (7.5 + move_speed_ratio * 4.5)
	else:
		_bob_time += delta * 1.4

	var bob_amp := (0.014 if not _is_ads else 0.003) * move_speed_ratio
	var bob_x := cos(_bob_time * 0.5) * bob_amp
	var bob_y := absf(sin(_bob_time)) * bob_amp

	var is_gun := (_current_id != WeaponData.WeaponId.KNIFE and _current_id != WeaponData.WeaponId.HE_GRENADE)
	var target := _ads_pos if (_is_ads and is_gun) else _base_pos
	var desired_pos := target + Vector3(bob_x, -bob_y, _recoil_z)
	gun_anchor.position = gun_anchor.position.lerp(desired_pos, clampf(delta * 14.0, 0.0, 1.0))
	gun_anchor.rotation.x = _recoil_rot + _reload_angle

func get_muzzle_world_pos() -> Vector3:
	return muzzle_flash.global_position
