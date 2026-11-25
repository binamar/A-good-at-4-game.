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

var _ak_bolt: MeshInstance3D
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
	_build_detailed_viewmodels()
	muzzle_flash.visible = false
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.78, 0.40)
	_muzzle_light.light_energy = 2.4
	_muzzle_light.omni_range = 4.2
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

func _add_part(parent: Node3D, pos: Vector3, sz: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _add_cyl(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot_deg: Vector3 = Vector3(90.0, 0.0, 0.0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_detailed_viewmodels() -> void:
	var steel_dark := _make_mat(Color(0.14, 0.16, 0.20), 0.42, 0.75)
	var gunmetal := _make_mat(Color(0.24, 0.27, 0.32), 0.35, 0.80)
	var polymer := _make_mat(Color(0.09, 0.10, 0.12), 0.78, 0.08)
	var walnut := _make_mat(Color(0.46, 0.24, 0.12), 0.70, 0.05)
	var chrome := _make_mat(Color(0.76, 0.80, 0.86), 0.20, 0.92)
	var tritium := _make_mat(Color(0.25, 1.0, 0.45), 0.2, 0.0, true)
	var red_dot := _make_mat(Color(1.0, 0.22, 0.18), 0.2, 0.0, true)
	var olive := _make_mat(Color(0.24, 0.32, 0.20), 0.72, 0.15)
	var camo_tex := ResourceLoader.load("res://assets/textures/tactical_camo.png") as Texture2D
	var sleeve_mat := StandardMaterial3D.new()
	if camo_tex != null:
		sleeve_mat.albedo_texture = camo_tex
	sleeve_mat.albedo_color = Color(0.32, 0.38, 0.46)
	sleeve_mat.roughness = 0.88
	var glove_mat := _make_mat(Color(0.11, 0.12, 0.14), 0.82, 0.05)

	# First-person tactical arms & gloves
	_arms_node = Node3D.new()
	gun_anchor.add_child(_arms_node)
	# Right forearm + glove
	_add_part(_arms_node, Vector3(0.06, -0.16, 0.22), Vector3(0.085, 0.085, 0.30), sleeve_mat, Vector3(24, -12, 0))
	_add_part(_arms_node, Vector3(0.005, -0.09, 0.07), Vector3(0.068, 0.072, 0.095), glove_mat, Vector3(12, 0, 0))
	# Left forearm + support glove
	_add_part(_arms_node, Vector3(-0.18, -0.14, -0.04), Vector3(0.082, 0.082, 0.30), sleeve_mat, Vector3(18, 34, 0))
	_add_part(_arms_node, Vector3(-0.04, -0.06, -0.18), Vector3(0.068, 0.065, 0.09), glove_mat, Vector3(0, 18, 0))

	# 1. AK-47 (Stamped steel, walnut furniture, curved mag, reciprocating bolt)
	_ak_node = Node3D.new()
	gun_anchor.add_child(_ak_node)
	_add_part(_ak_node, Vector3(0, 0.0, 0.0), Vector3(0.054, 0.078, 0.33), steel_dark)
	_add_part(_ak_node, Vector3(0, 0.025, 0.0), Vector3(0.048, 0.036, 0.30), gunmetal)
	_ak_bolt = _add_part(_ak_node, Vector3(0.028, 0.018, -0.02), Vector3(0.014, 0.018, 0.075), chrome)
	_add_part(_ak_node, Vector3(0, -0.005, -0.25), Vector3(0.048, 0.060, 0.20), walnut) # handguard
	_add_cyl(_ak_node, Vector3(0, 0.022, -0.37), 0.011, 0.44, steel_dark) # barrel
	_add_cyl(_ak_node, Vector3(0, 0.042, -0.29), 0.012, 0.22, steel_dark) # gas tube
	_add_part(_ak_node, Vector3(0, 0.052, -0.49), Vector3(0.012, 0.032, 0.022), steel_dark) # front sight
	_add_part(_ak_node, Vector3(0, 0.052, -0.08), Vector3(0.022, 0.016, 0.03), steel_dark) # rear sight
	_add_part(_ak_node, Vector3(0, -0.022, 0.26), Vector3(0.042, 0.088, 0.22), walnut, Vector3(-6, 0, 0)) # stock
	_add_part(_ak_node, Vector3(0, -0.095, 0.075), Vector3(0.036, 0.11, 0.052), walnut, Vector3(16, 0, 0)) # grip
	_add_part(_ak_node, Vector3(0, -0.10, -0.09), Vector3(0.032, 0.13, 0.062), steel_dark, Vector3(-12, 0, 0))
	_add_part(_ak_node, Vector3(0, -0.18, -0.115), Vector3(0.031, 0.09, 0.058), steel_dark, Vector3(-26, 0, 0))

	# 2. M4A1-Carbine (Polymer/steel, quad-rail, holographic red-dot, suppressor)
	_m4_node = Node3D.new()
	gun_anchor.add_child(_m4_node)
	_add_part(_m4_node, Vector3(0, 0.0, 0.0), Vector3(0.054, 0.076, 0.30), polymer)
	_add_part(_m4_node, Vector3(0, 0.042, -0.02), Vector3(0.034, 0.014, 0.34), gunmetal) # top rail
	# Holographic sight + glowing red dot
	_add_part(_m4_node, Vector3(0, 0.072, -0.01), Vector3(0.040, 0.042, 0.075), steel_dark)
	_add_part(_m4_node, Vector3(0, 0.075, -0.01), Vector3(0.008, 0.008, 0.008), red_dot)
	_add_part(_m4_node, Vector3(0, 0.012, -0.24), Vector3(0.050, 0.054, 0.20), gunmetal) # quad-rail
	_add_cyl(_m4_node, Vector3(0, 0.018, -0.45), 0.020, 0.24, steel_dark) # suppressor
	_add_cyl(_m4_node, Vector3(0, 0.010, 0.24), 0.022, 0.20, polymer) # buffer tube
	_add_part(_m4_node, Vector3(0, -0.018, 0.28), Vector3(0.042, 0.10, 0.14), polymer) # buttstock
	_add_part(_m4_node, Vector3(0, -0.095, 0.07), Vector3(0.036, 0.11, 0.050), polymer, Vector3(18, 0, 0))
	_add_part(_m4_node, Vector3(0, -0.11, -0.08), Vector3(0.032, 0.16, 0.064), gunmetal, Vector3(-5, 0, 0))

	# 3. MP5-SD (Compact SMG, ribbed integral suppressor, curved mag)
	_mp5_node = Node3D.new()
	gun_anchor.add_child(_mp5_node)
	_add_part(_mp5_node, Vector3(0, 0.01, -0.02), Vector3(0.048, 0.068, 0.28), polymer)
	_add_cyl(_mp5_node, Vector3(0, 0.018, -0.27), 0.024, 0.25, steel_dark) # SD suppressor
	_add_part(_mp5_node, Vector3(0, 0.056, -0.12), Vector3(0.018, 0.022, 0.022), steel_dark)
	_add_part(_mp5_node, Vector3(0, 0.056, 0.06), Vector3(0.022, 0.022, 0.024), steel_dark)
	_add_part(_mp5_node, Vector3(0, 0.01, 0.21), Vector3(0.036, 0.068, 0.18), polymer)
	_add_part(_mp5_node, Vector3(0, -0.085, 0.06), Vector3(0.034, 0.10, 0.046), polymer, Vector3(16, 0, 0))
	_add_part(_mp5_node, Vector3(0, -0.11, -0.07), Vector3(0.026, 0.15, 0.042), steel_dark, Vector3(-16, 0, 0))

	# 4. USP-Tactical (Two-tone slide, suppressor, green tritium sights)
	_usp_node = Node3D.new()
	gun_anchor.add_child(_usp_node)
	_pistol_slide = _add_part(_usp_node, Vector3(0, 0.032, -0.04), Vector3(0.036, 0.038, 0.22), gunmetal)
	_add_part(_usp_node, Vector3(0, 0.054, -0.13), Vector3(0.007, 0.010, 0.010), tritium)
	_add_part(_usp_node, Vector3(-0.010, 0.054, 0.055), Vector3(0.006, 0.010, 0.008), tritium)
	_add_part(_usp_node, Vector3(0.010, 0.054, 0.055), Vector3(0.006, 0.010, 0.008), tritium)
	_add_part(_usp_node, Vector3(0, 0.0, -0.02), Vector3(0.033, 0.028, 0.19), polymer)
	_add_part(_usp_node, Vector3(0, -0.068, 0.048), Vector3(0.032, 0.11, 0.048), polymer, Vector3(14, 0, 0))
	_add_cyl(_usp_node, Vector3(0, 0.026, -0.22), 0.017, 0.16, steel_dark)

	# 5. Glock-18C (Compact vented slide, extended mag)
	_glock_node = Node3D.new()
	gun_anchor.add_child(_glock_node)
	_glock_slide = _add_part(_glock_node, Vector3(0, 0.030, -0.04), Vector3(0.034, 0.034, 0.20), steel_dark)
	_add_part(_glock_node, Vector3(0, 0.050, -0.12), Vector3(0.007, 0.008, 0.008), tritium)
	_add_part(_glock_node, Vector3(0, 0.0, -0.02), Vector3(0.032, 0.026, 0.18), polymer)
	_add_part(_glock_node, Vector3(0, -0.075, 0.046), Vector3(0.031, 0.125, 0.046), polymer, Vector3(15, 0, 0))

	# 6. Tactical Combat Knife
	_knife_node = Node3D.new()
	_knife_node.rotation_degrees = Vector3(-14.0, 20.0, 0.0)
	gun_anchor.add_child(_knife_node)
	_add_part(_knife_node, Vector3(0, 0, 0.02), Vector3(0.030, 0.034, 0.13), walnut)
	_add_part(_knife_node, Vector3(0, 0.004, -0.05), Vector3(0.048, 0.014, 0.016), steel_dark)
	_add_part(_knife_node, Vector3(0, 0.008, -0.155), Vector3(0.010, 0.034, 0.20), chrome)
	_add_part(_knife_node, Vector3(0, 0.022, -0.24), Vector3(0.008, 0.016, 0.045), chrome, Vector3(24, 0, 0))

	# 7. HE Frag Grenade
	_grenade_node = Node3D.new()
	gun_anchor.add_child(_grenade_node)
	_add_cyl(_grenade_node, Vector3(0, -0.02, -0.06), 0.042, 0.095, olive, Vector3.ZERO)
	_add_part(_grenade_node, Vector3(0, 0.042, -0.06), Vector3(0.024, 0.026, 0.024), gunmetal)
	_add_part(_grenade_node, Vector3(0.022, 0.012, -0.06), Vector3(0.010, 0.068, 0.014), steel_dark, Vector3(0, 0, -10))

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

	if _ak_bolt != null:
		_ak_bolt.position.z = -0.02 + _slide_kick
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
