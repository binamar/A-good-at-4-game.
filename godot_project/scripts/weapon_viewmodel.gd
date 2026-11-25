extends Node3D

@onready var gun_anchor: Node3D = $GunAnchor
@onready var muzzle_flash: MeshInstance3D = $GunAnchor/MuzzleFlash

var _rifle_mesh: MeshInstance3D
var _pistol_mesh: MeshInstance3D
var _knife_mesh: Node3D

var _base_pos := Vector3(0.24, -0.22, -0.42)
var _ads_pos := Vector3(0.0, -0.17, -0.34)

var _bob_time := 0.0
var _recoil_z := 0.0
var _recoil_rot := 0.0
var _flash_timer := 0.0
var _reload_angle := 0.0
var _is_reloading := false
var _is_ads := false
var _current_id := -1

func _ready() -> void:
	_build_lowpoly_viewmodels()
	muzzle_flash.visible = false
	equip_weapon(WeaponData.WeaponId.USP_PISTOL)

func _build_lowpoly_viewmodels() -> void:
	var metal_dark := StandardMaterial3D.new()
	metal_dark.albedo_color = Color(0.18, 0.20, 0.24)
	metal_dark.roughness = 0.45
	metal_dark.metallic = 0.55

	var wood_grip := StandardMaterial3D.new()
	wood_grip.albedo_color = Color(0.48, 0.28, 0.14)
	wood_grip.roughness = 0.78

	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.78, 0.82, 0.88)
	blade_mat.metallic = 0.85
	blade_mat.roughness = 0.22

	_rifle_mesh = MeshInstance3D.new()
	var ak_res := ResourceLoader.load("res://assets/models/ak_rifle.obj") as Mesh
	if ak_res != null:
		_rifle_mesh.mesh = ak_res
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.1, 0.65)
		_rifle_mesh.mesh = box
	_rifle_mesh.material_override = metal_dark
	gun_anchor.add_child(_rifle_mesh)

	_pistol_mesh = MeshInstance3D.new()
	var usp_res := ResourceLoader.load("res://assets/models/usp_pistol.obj") as Mesh
	if usp_res != null:
		_pistol_mesh.mesh = usp_res
	else:
		var pbox := BoxMesh.new()
		pbox.size = Vector3(0.04, 0.08, 0.28)
		_pistol_mesh.mesh = pbox
	_pistol_mesh.material_override = metal_dark
	gun_anchor.add_child(_pistol_mesh)

	_knife_mesh = Node3D.new()
	var handle := MeshInstance3D.new()
	var hbox := BoxMesh.new()
	hbox.size = Vector3(0.028, 0.032, 0.13)
	handle.mesh = hbox
	handle.material_override = wood_grip
	_knife_mesh.add_child(handle)

	var blade := MeshInstance3D.new()
	var bbox := BoxMesh.new()
	bbox.size = Vector3(0.012, 0.036, 0.20)
	blade.mesh = bbox
	blade.position = Vector3(0.0, 0.008, -0.16)
	blade.material_override = blade_mat
	_knife_mesh.add_child(blade)
	_knife_mesh.rotation_degrees = Vector3(-12.0, 18.0, 0.0)
	gun_anchor.add_child(_knife_mesh)

func equip_weapon(weapon_id: int) -> void:
	_current_id = weapon_id
	var stats := WeaponData.get_stats(weapon_id)
	var slot: int = stats["slot"]
	_rifle_mesh.visible = (slot == 1)
	_pistol_mesh.visible = (slot == 2)
	_knife_mesh.visible = (slot == 3)
	_recoil_z = 0.08
	_recoil_rot = -0.15

func trigger_fire() -> void:
	if _current_id == WeaponData.WeaponId.KNIFE:
		_recoil_z = -0.14
		_recoil_rot = -0.45
	else:
		_recoil_z = 0.075
		_recoil_rot = 0.14
		_flash_timer = 0.045
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf() * TAU

func set_reloading(reloading: bool) -> void:
	_is_reloading = reloading

func set_ads(ads: bool) -> void:
	_is_ads = ads

func update_motion(delta: float, move_speed_ratio: float, on_floor: bool) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			muzzle_flash.visible = false

	_recoil_z = lerpf(_recoil_z, 0.0, clampf(delta * 16.0, 0.0, 1.0))
	_recoil_rot = lerpf(_recoil_rot, 0.0, clampf(delta * 14.0, 0.0, 1.0))
	_reload_angle = lerpf(_reload_angle, -0.65 if _is_reloading else 0.0, clampf(delta * 10.0, 0.0, 1.0))

	if on_floor and move_speed_ratio > 0.08:
		_bob_time += delta * (7.5 + move_speed_ratio * 4.5)
	else:
		_bob_time += delta * 1.4

	var bob_amp := (0.014 if not _is_ads else 0.004) * move_speed_ratio
	var bob_x := cos(_bob_time * 0.5) * bob_amp
	var bob_y := absf(sin(_bob_time)) * bob_amp

	var target := _ads_pos if (_is_ads and _current_id != WeaponData.WeaponId.KNIFE) else _base_pos
	var desired_pos := target + Vector3(bob_x, -bob_y, _recoil_z)
	gun_anchor.position = gun_anchor.position.lerp(desired_pos, clampf(delta * 14.0, 0.0, 1.0))
	gun_anchor.rotation.x = _recoil_rot + _reload_angle

func get_muzzle_world_pos() -> Vector3:
	return muzzle_flash.global_position
