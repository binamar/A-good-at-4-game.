extends CanvasLayer

const HUD_CANVAS_SCRIPT := preload("res://scripts/hud_canvas.gd")

var _player: CharacterBody3D = null
var _arena: Node = null
var _agents: Array = []

# Multi-touch tracking
var _joy_finger: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_current: Vector2 = Vector2.ZERO
const JOY_RADIUS := 74.0

var _look_finger: int = -1
var _fire_finger: int = -1

# Root controls
var _hud_root: Control
var _draw_layer: Control
var _top_score_lbl: Label
var _timer_lbl: Label
var _ct_alive_lbl: Label
var _t_alive_lbl: Label
var _money_lbl: Label
var _hp_lbl: Label
var _ammo_lbl: Label
var _weapon_lbl: Label
var _hit_dmg_lbl: Label
var _announce_box: PanelContainer
var _announce_title: Label
var _announce_sub: Label
var _announce_timer: float = 0.0
var _kill_feed_box: VBoxContainer

# Touch buttons
var _fire_btn: Panel
var _ads_btn: Button
var _jump_btn: Button
var _crouch_btn: Button
var _reload_btn: Button
var _swap_btn: Button
var _buy_btn: Button
var _pause_btn: Button
var _score_btn: Button
var _slot1_btn: Button
var _slot2_btn: Button
var _slot3_btn: Button
var _slot4_btn: Button
var _pov_btn: Button
var _action_btn: Button
var _action_bar: ProgressBar

# Overlays
var _buy_panel: PanelContainer
var _pause_panel: PanelContainer
var _score_panel: PanelContainer
var _score_text: Label
var _match_over_panel: PanelContainer
var _match_over_lbl: Label
var _sens_lbl: Label
var _quality_btn: Button

var _hitmarker_timer: float = 0.0
var _hitmarker_head: bool = false
var _damage_flash_timer: float = 0.0

func _ready() -> void:
	_build_hud()
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.timer_updated.connect(_on_timer_updated)
	GameManager.money_updated.connect(_on_money_changed)
	GameManager.kill_feed_added.connect(_on_kill_feed_added)
	GameManager.announcement_triggered.connect(_on_announcement)
	GameManager.state_changed.connect(_on_state_changed)

func bind_player(p: CharacterBody3D, arena_ref: Node, all_agents: Array) -> void:
	_player = p
	_arena = arena_ref
	_agents = all_agents
	if _player == null or not is_instance_valid(_player) or not _player.has_signal("health_changed"):
		return
	_player.health_changed.connect(_on_health_changed)
	_player.weapon_changed.connect(_on_weapon_changed)
	_player.hitmarker_triggered.connect(_on_hitmarker)
	_player.damage_taken_triggered.connect(_on_damage_taken)
	_player.action_prompt_changed.connect(_on_action_prompt)
	_player.pov_changed.connect(_on_pov_changed)
	_on_pov_changed(_player.pov_mode)

func _build_hud() -> void:
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	_draw_layer = Control.new()
	_draw_layer.set_script(HUD_CANVAS_SCRIPT)
	_draw_layer.set("hud", self)
	_draw_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_draw_layer)

	# Top Bar (Score / Timer / Alive Counts)
	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.5
	top_bar.anchor_right = 0.5
	top_bar.offset_left = -210
	top_bar.offset_right = 210
	top_bar.offset_top = 12
	top_bar.offset_bottom = 58
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 12)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(top_bar)

	_ct_alive_lbl = _make_chip_label("CT 5", Color(0.22, 0.54, 0.94), 68)
	_top_score_lbl = _make_chip_label("0 : 0", Color(0.12, 0.15, 0.20), 92)
	_timer_lbl = _make_chip_label("1:50", Color(0.12, 0.15, 0.20), 86)
	_t_alive_lbl = _make_chip_label("5 T", Color(0.90, 0.56, 0.18), 68)
	top_bar.add_child(_ct_alive_lbl)
	top_bar.add_child(_top_score_lbl)
	top_bar.add_child(_timer_lbl)
	top_bar.add_child(_t_alive_lbl)

	# Floating Hit Damage Feedback near crosshair
	_hit_dmg_lbl = Label.new()
	_hit_dmg_lbl.anchor_left = 0.5
	_hit_dmg_lbl.anchor_right = 0.5
	_hit_dmg_lbl.anchor_top = 0.5
	_hit_dmg_lbl.anchor_bottom = 0.5
	_hit_dmg_lbl.offset_left = 22
	_hit_dmg_lbl.offset_right = 150
	_hit_dmg_lbl.offset_top = -36
	_hit_dmg_lbl.offset_bottom = -8
	_hit_dmg_lbl.add_theme_font_size_override("font_size", 18)
	_hit_dmg_lbl.visible = false
	_hit_dmg_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_hit_dmg_lbl)

	# Kill Feed (Top Right)
	_kill_feed_box = VBoxContainer.new()
	_kill_feed_box.anchor_left = 1.0
	_kill_feed_box.anchor_right = 1.0
	_kill_feed_box.offset_left = -330
	_kill_feed_box.offset_right = -16
	_kill_feed_box.offset_top = 16
	_kill_feed_box.offset_bottom = 180
	_kill_feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_kill_feed_box)

	# Bottom Left Status (HP + Money)
	var status_box := HBoxContainer.new()
	status_box.anchor_top = 1.0
	status_box.anchor_bottom = 1.0
	status_box.offset_left = 20
	status_box.offset_right = 300
	status_box.offset_top = -58
	status_box.offset_bottom = -16
	status_box.add_theme_constant_override("separation", 10)
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(status_box)

	_hp_lbl = _make_chip_label("HP 100", Color(0.11, 0.14, 0.19, 0.85), 118)
	_money_lbl = _make_chip_label("$1000", Color(0.12, 0.42, 0.22, 0.88), 96)
	status_box.add_child(_hp_lbl)
	status_box.add_child(_money_lbl)

	# Bottom Center Weapon Slots + Ammo
	var slot_bar := HBoxContainer.new()
	slot_bar.anchor_left = 0.5
	slot_bar.anchor_right = 0.5
	slot_bar.anchor_top = 1.0
	slot_bar.anchor_bottom = 1.0
	slot_bar.offset_left = -165
	slot_bar.offset_right = 165
	slot_bar.offset_top = -100
	slot_bar.offset_bottom = -62
	slot_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_bar.add_theme_constant_override("separation", 6)
	_hud_root.add_child(slot_bar)

	_slot1_btn = _make_slot_btn("RIFLE", _on_slot1_pressed)
	_slot2_btn = _make_slot_btn("PISTOL", _on_slot2_pressed)
	_slot3_btn = _make_slot_btn("KNIFE", _on_slot3_pressed)
	_slot4_btn = _make_slot_btn("FRAG", _on_slot4_pressed)
	slot_bar.add_child(_slot1_btn)
	slot_bar.add_child(_slot2_btn)
	slot_bar.add_child(_slot3_btn)
	slot_bar.add_child(_slot4_btn)

	var ammo_box := HBoxContainer.new()
	ammo_box.anchor_left = 0.5
	ammo_box.anchor_right = 0.5
	ammo_box.anchor_top = 1.0
	ammo_box.anchor_bottom = 1.0
	ammo_box.offset_left = -120
	ammo_box.offset_right = 120
	ammo_box.offset_top = -56
	ammo_box.offset_bottom = -16
	ammo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_box.add_theme_constant_override("separation", 8)
	ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(ammo_box)

	_weapon_lbl = _make_chip_label("USP", Color(0.12, 0.15, 0.20, 0.85), 95)
	_ammo_lbl = _make_chip_label("12 / 36", Color(0.12, 0.15, 0.20, 0.85), 108)
	ammo_box.add_child(_weapon_lbl)
	ammo_box.add_child(_ammo_lbl)

	# Top Left Utility Buttons (Menu + Score + Buy)
	_pause_btn = _make_touch_btn("MENU", Vector2(18, 162), Vector2(68, 40))
	_pause_btn.pressed.connect(_toggle_pause)
	_hud_root.add_child(_pause_btn)

	_score_btn = _make_touch_btn("SCORE", Vector2(92, 162), Vector2(72, 40))
	_score_btn.pressed.connect(_toggle_score)
	_hud_root.add_child(_score_btn)

	_buy_btn = _make_touch_btn("BUY", Vector2(170, 162), Vector2(68, 40))
	_buy_btn.pressed.connect(_toggle_buy_menu)
	_hud_root.add_child(_buy_btn)

	# Right-Side Touch Combat Cluster
	_fire_btn = Panel.new()
	_fire_btn.anchor_left = 1.0
	_fire_btn.anchor_right = 1.0
	_fire_btn.anchor_top = 1.0
	_fire_btn.anchor_bottom = 1.0
	_fire_btn.offset_left = -152
	_fire_btn.offset_right = -32
	_fire_btn.offset_top = -220
	_fire_btn.offset_bottom = -100
	var fire_style := StyleBoxFlat.new()
	fire_style.bg_color = Color(0.86, 0.26, 0.22, 0.62)
	fire_style.border_color = Color(1.0, 0.85, 0.82, 0.85)
	fire_style.set_border_width_all(3)
	fire_style.set_corner_radius_all(60)
	_fire_btn.add_theme_stylebox_override("panel", fire_style)
	_fire_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_fire_btn)

	var fire_lbl := Label.new()
	fire_lbl.text = "FIRE"
	fire_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fire_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fire_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	fire_lbl.add_theme_font_size_override("font_size", 20)
	_fire_btn.add_child(fire_lbl)

	_ads_btn = _make_anchored_br_btn("AIM", Vector2(-248, -190), Vector2(82, 56))
	_ads_btn.pressed.connect(_on_ads_pressed)
	_hud_root.add_child(_ads_btn)

	_jump_btn = _make_anchored_br_btn("JUMP", Vector2(-248, -120), Vector2(82, 54))
	_jump_btn.pressed.connect(_on_jump_pressed)
	_hud_root.add_child(_jump_btn)

	_crouch_btn = _make_anchored_br_btn("CROUCH", Vector2(-340, -120), Vector2(82, 54))
	_crouch_btn.pressed.connect(_on_crouch_pressed)
	_hud_root.add_child(_crouch_btn)

	_reload_btn = _make_anchored_br_btn("RELOAD", Vector2(-248, -260), Vector2(82, 52))
	_reload_btn.pressed.connect(_on_reload_pressed)
	_hud_root.add_child(_reload_btn)

	_swap_btn = _make_anchored_br_btn("SWAP", Vector2(-146, -84), Vector2(114, 48))
	_swap_btn.pressed.connect(_on_swap_pressed)
	_hud_root.add_child(_swap_btn)

	_pov_btn = _make_anchored_br_btn("1ST POV", Vector2(-340, -190), Vector2(82, 56))
	_pov_btn.pressed.connect(_on_pov_pressed)
	_hud_root.add_child(_pov_btn)

	# Contextual Plant / Defuse Hold Button
	_action_btn = Button.new()
	_action_btn.anchor_left = 0.5
	_action_btn.anchor_right = 0.5
	_action_btn.anchor_top = 0.62
	_action_btn.anchor_bottom = 0.62
	_action_btn.offset_left = -135
	_action_btn.offset_right = 135
	_action_btn.offset_top = 0
	_action_btn.offset_bottom = 52
	_action_btn.text = "HOLD TO PLANT C4"
	_action_btn.visible = false
	_action_btn.button_down.connect(_on_action_down)
	_action_btn.button_up.connect(_on_action_up)
	_hud_root.add_child(_action_btn)

	_action_bar = ProgressBar.new()
	_action_bar.anchor_left = 0.5
	_action_bar.anchor_right = 0.5
	_action_bar.anchor_top = 0.62
	_action_bar.anchor_bottom = 0.62
	_action_bar.offset_left = -135
	_action_bar.offset_right = 135
	_action_bar.offset_top = 56
	_action_bar.offset_bottom = 68
	_action_bar.max_value = 1.0
	_action_bar.show_percentage = false
	_action_bar.visible = false
	_hud_root.add_child(_action_bar)

	# Center Round Announcement Banner
	_announce_box = PanelContainer.new()
	_announce_box.anchor_left = 0.5
	_announce_box.anchor_right = 0.5
	_announce_box.offset_left = -220
	_announce_box.offset_right = 220
	_announce_box.offset_top = 74
	_announce_box.offset_bottom = 140
	_announce_box.visible = false
	_announce_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_announce_box)

	var av := VBoxContainer.new()
	av.alignment = BoxContainer.ALIGNMENT_CENTER
	_announce_box.add_child(av)
	_announce_title = Label.new()
	_announce_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_title.add_theme_font_size_override("font_size", 22)
	_announce_sub = Label.new()
	_announce_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_sub.add_theme_font_size_override("font_size", 14)
	av.add_child(_announce_title)
	av.add_child(_announce_sub)

	_build_buy_panel()
	_build_pause_panel()
	_build_score_panel()
	_build_match_over_panel()

func _make_slot_btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(74, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _build_buy_panel() -> void:
	_buy_panel = PanelContainer.new()
	_buy_panel.anchor_left = 0.5
	_buy_panel.anchor_right = 0.5
	_buy_panel.anchor_top = 0.5
	_buy_panel.anchor_bottom = 0.5
	_buy_panel.offset_left = -260
	_buy_panel.offset_right = 260
	_buy_panel.offset_top = -205
	_buy_panel.offset_bottom = 205
	_buy_panel.visible = false
	_hud_root.add_child(_buy_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_buy_panel.add_child(vbox)

	var title := Label.new()
	title.text = "TACTICAL ARMORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	_add_buy_row(vbox, "AK-47 Rifle ($2700)", _on_buy_ak47)
	_add_buy_row(vbox, "M4A1-Carbine ($2900)", _on_buy_m4)
	_add_buy_row(vbox, "MP5-SD SMG ($1500)", _on_buy_mp5)
	_add_buy_row(vbox, "USP-Tactical Pistol ($200)", _on_buy_usp)
	_add_buy_row(vbox, "HE Frag Grenade ($300)", _on_buy_grenade)
	_add_buy_row(vbox, "Kevlar Vest Armor ($650)", _on_buy_armor)
	_add_buy_row(vbox, "Defuse Kit - CT Only ($400)", _on_buy_kit)

	var close_b := Button.new()
	close_b.text = "CLOSE"
	close_b.custom_minimum_size = Vector2(0, 40)
	close_b.pressed.connect(_on_close_buy)
	vbox.add_child(close_b)

func _add_buy_row(parent: VBoxContainer, label_txt: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label_txt
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(cb)
	parent.add_child(b)

func _build_score_panel() -> void:
	_score_panel = PanelContainer.new()
	_score_panel.anchor_left = 0.5
	_score_panel.anchor_right = 0.5
	_score_panel.anchor_top = 0.5
	_score_panel.anchor_bottom = 0.5
	_score_panel.offset_left = -220
	_score_panel.offset_right = 220
	_score_panel.offset_top = -175
	_score_panel.offset_bottom = 175
	_score_panel.visible = false
	_hud_root.add_child(_score_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_score_panel.add_child(vbox)

	var title := Label.new()
	title.text = "5v5 MATCH SCOREBOARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 19)
	vbox.add_child(title)

	_score_text = Label.new()
	_score_text.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_score_text)

	var close_b := Button.new()
	close_b.text = "CLOSE"
	close_b.custom_minimum_size = Vector2(0, 38)
	close_b.pressed.connect(_on_close_score)
	vbox.add_child(close_b)

func _build_pause_panel() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.offset_left = -200
	_pause_panel.offset_right = 200
	_pause_panel.offset_top = -140
	_pause_panel.offset_bottom = 140
	_pause_panel.visible = false
	_hud_root.add_child(_pause_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "MATCH SETTINGS"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(lbl)

	_sens_lbl = Label.new()
	_sens_lbl.text = "Touch Look Sensitivity: %.2f" % GameManager.touch_sensitivity
	vbox.add_child(_sens_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.10
	slider.max_value = 0.70
	slider.step = 0.02
	slider.value = GameManager.touch_sensitivity
	slider.value_changed.connect(_on_sens_changed)
	vbox.add_child(slider)

	_quality_btn = Button.new()
	_quality_btn.custom_minimum_size = Vector2(0, 42)
	_quality_btn.pressed.connect(_on_quality_pressed)
	_refresh_quality_btn()
	vbox.add_child(_quality_btn)

	var resume_b := Button.new()
	resume_b.text = "RESUME MATCH"
	resume_b.custom_minimum_size = Vector2(0, 44)
	resume_b.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_b)

	var quit_b := Button.new()
	quit_b.text = "EXIT TO MAIN MENU"
	quit_b.custom_minimum_size = Vector2(0, 44)
	quit_b.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_b)

func _build_match_over_panel() -> void:
	_match_over_panel = PanelContainer.new()
	_match_over_panel.anchor_left = 0.5
	_match_over_panel.anchor_right = 0.5
	_match_over_panel.anchor_top = 0.5
	_match_over_panel.anchor_bottom = 0.5
	_match_over_panel.offset_left = -210
	_match_over_panel.offset_right = 210
	_match_over_panel.offset_top = -120
	_match_over_panel.offset_bottom = 120
	_match_over_panel.visible = false
	_hud_root.add_child(_match_over_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_match_over_panel.add_child(vbox)

	_match_over_lbl = Label.new()
	_match_over_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_over_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_match_over_lbl)

	var replay_b := Button.new()
	replay_b.text = "PLAY AGAIN"
	replay_b.custom_minimum_size = Vector2(0, 46)
	replay_b.pressed.connect(_on_replay_pressed)
	vbox.add_child(replay_b)

	var menu_b := Button.new()
	menu_b.text = "MAIN MENU"
	menu_b.custom_minimum_size = Vector2(0, 46)
	menu_b.pressed.connect(_on_menu_pressed)
	vbox.add_child(menu_b)

func _on_slot1_pressed() -> void:
	if _player != null:
		_player.equip_slot(1)

func _on_slot2_pressed() -> void:
	if _player != null:
		_player.equip_slot(2)

func _on_slot3_pressed() -> void:
	if _player != null:
		_player.equip_slot(3)

func _on_slot4_pressed() -> void:
	if _player != null:
		_player.equip_slot(4)

func _on_ads_pressed() -> void:
	if _player != null:
		_player.toggle_ads()

func _on_jump_pressed() -> void:
	if _player != null:
		_player.trigger_jump()

func _on_crouch_pressed() -> void:
	if _player != null:
		_player.toggle_crouch()

func _on_reload_pressed() -> void:
	if _player != null:
		_player.trigger_reload()

func _on_swap_pressed() -> void:
	if _player != null:
		_player.cycle_weapon()

func _on_pov_pressed() -> void:
	if _player != null:
		_player.cycle_pov()

func _on_pov_changed(mode: int) -> void:
	if _pov_btn == null:
		return
	var labels := ["1ST POV", "2ND POV", "3RD POV"]
	_pov_btn.text = labels[clampi(mode, 0, 2)]

func _on_action_down() -> void:
	if _player != null:
		_player.is_action_held = true

func _on_action_up() -> void:
	if _player != null:
		_player.is_action_held = false

func _on_buy_ak47() -> void:
	GameManager.try_buy_weapon(WeaponData.WeaponId.AK47_RIFLE)

func _on_buy_m4() -> void:
	GameManager.try_buy_weapon(WeaponData.WeaponId.M4_RIFLE)

func _on_buy_mp5() -> void:
	GameManager.try_buy_weapon(WeaponData.WeaponId.MP5_SMG)

func _on_buy_usp() -> void:
	GameManager.try_buy_weapon(WeaponData.WeaponId.USP_PISTOL)

func _on_buy_grenade() -> void:
	GameManager.try_buy_weapon(WeaponData.WeaponId.HE_GRENADE)

func _on_buy_armor() -> void:
	GameManager.try_buy_armor()

func _on_buy_kit() -> void:
	GameManager.try_buy_defuse_kit()

func _on_close_buy() -> void:
	_buy_panel.visible = false

func _on_close_score() -> void:
	_score_panel.visible = false

func _on_sens_changed(v: float) -> void:
	GameManager.touch_sensitivity = v
	if _sens_lbl != null:
		_sens_lbl.text = "Touch Look Sensitivity: %.2f" % v

func _on_quality_pressed() -> void:
	GameManager.apply_graphics_quality((GameManager.graphics_quality + 1) % 3)
	_refresh_quality_btn()

func _refresh_quality_btn() -> void:
	if _quality_btn == null:
		return
	var names := ["Graphics: COOL (540p / 45 FPS)", "Graphics: BALANCED (720p / 60 FPS)", "Graphics: SHARP (900p / 60 FPS)"]
	_quality_btn.text = names[GameManager.graphics_quality]

func _on_resume_pressed() -> void:
	_pause_panel.visible = false

func _on_quit_pressed() -> void:
	GameManager.return_to_menu()

func _on_replay_pressed() -> void:
	GameManager.start_new_match(GameManager.player_team)

func _on_menu_pressed() -> void:
	GameManager.return_to_menu()

func _make_chip_label(txt: String, bg: Color, min_w: float) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.custom_minimum_size = Vector2(min_w, 38)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(6)
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl

func _make_touch_btn(txt: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	return b

func _make_anchored_br_btn(txt: String, offset_tl: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = txt
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = offset_tl.x
	b.offset_top = offset_tl.y
	b.offset_right = offset_tl.x + sz.x
	b.offset_bottom = offset_tl.y + sz.y
	b.focus_mode = Control.FOCUS_NONE
	return b

func _to_canvas_pos(screen_pos: Vector2) -> Vector2:
	if _hud_root == null:
		return screen_pos
	return _hud_root.get_global_transform_with_canvas().affine_inverse() * screen_pos

func _input(event: InputEvent) -> void:
	if _buy_panel.visible or _pause_panel.visible or _score_panel.visible or _match_over_panel.visible or _player == null:
		return

	if event is InputEventScreenTouch:
		var pos: Vector2 = _to_canvas_pos(event.position)
		if event.pressed:
			if _fire_btn.get_global_rect().has_point(pos):
				_fire_finger = event.index
				_player.set_fire_pressed(true)
				return
			var btns: Array = [_ads_btn, _jump_btn, _crouch_btn, _reload_btn, _swap_btn, _pov_btn, _buy_btn, _pause_btn, _score_btn, _slot1_btn, _slot2_btn, _slot3_btn, _slot4_btn, _action_btn]
			for btn in btns:
				if btn != null and btn.visible and btn.get_global_rect().has_point(pos):
					return
			var vp_w := _hud_root.get_viewport_rect().size.x
			if pos.x < vp_w * 0.45 and _joy_finger == -1:
				_joy_finger = event.index
				_joy_origin = pos
				_joy_current = pos
				_player.move_input = Vector2.ZERO
			elif pos.x >= vp_w * 0.45 and _look_finger == -1:
				_look_finger = event.index
		else:
			if event.index == _fire_finger:
				_fire_finger = -1
				_player.set_fire_pressed(false)
			elif event.index == _joy_finger:
				_joy_finger = -1
				_player.move_input = Vector2.ZERO
			elif event.index == _look_finger:
				_look_finger = -1

	elif event is InputEventScreenDrag:
		var drag_pos: Vector2 = _to_canvas_pos(event.position)
		if event.index == _joy_finger:
			var delta_v: Vector2 = drag_pos - _joy_origin
			if delta_v.length() > JOY_RADIUS:
				delta_v = delta_v.normalized() * JOY_RADIUS
			_joy_current = _joy_origin + delta_v
			_player.move_input = delta_v / JOY_RADIUS
		elif event.index == _look_finger or event.index == _fire_finger:
			_player.add_look_delta(event.relative)

func _process(delta: float) -> void:
	if _hitmarker_timer > 0.0:
		_hitmarker_timer -= delta
		if _hitmarker_timer <= 0.0:
			_hit_dmg_lbl.visible = false
	if _damage_flash_timer > 0.0:
		_damage_flash_timer -= delta
	if _announce_timer > 0.0:
		_announce_timer -= delta
		if _announce_timer <= 0.0:
			_announce_box.visible = false
	_buy_btn.visible = GameManager.can_buy()
	if not GameManager.can_buy() and _buy_panel.visible:
		_buy_panel.visible = false
	if _player != null and is_instance_valid(_player) and _player.has_method("has_slot"):
		_slot1_btn.visible = _player.has_slot(1)
		_slot4_btn.visible = _player.has_slot(4)
	_draw_layer.queue_redraw()

func _toggle_buy_menu() -> void:
	if GameManager.can_buy():
		_buy_panel.visible = not _buy_panel.visible

func _toggle_pause() -> void:
	_pause_panel.visible = not _pause_panel.visible

func _toggle_score() -> void:
	_score_panel.visible = not _score_panel.visible
	if _score_panel.visible:
		_refresh_scoreboard()

func _refresh_scoreboard() -> void:
	var lines: Array = []
	lines.append("CT SIDE (%d):" % GameManager.ct_score)
	for ag_name in GameManager.scoreboard.keys():
		var row: Dictionary = GameManager.scoreboard[ag_name]
		if row["team"] == GameManager.Team.CT:
			lines.append("  %-12s  K: %d   D: %d" % [ag_name, row["kills"], row["deaths"]])
	lines.append("")
	lines.append("T SIDE (%d):" % GameManager.t_score)
	for ag_name in GameManager.scoreboard.keys():
		var row: Dictionary = GameManager.scoreboard[ag_name]
		if row["team"] == GameManager.Team.T:
			lines.append("  %-12s  K: %d   D: %d" % [ag_name, row["kills"], row["deaths"]])
	_score_text.text = "\n".join(lines)

func _on_score_changed(ct: int, t: int, _r: int) -> void:
	_top_score_lbl.text = "%d : %d" % [ct, t]

func _on_timer_updated(seconds_left: float, planted: bool) -> void:
	var sec := int(ceil(seconds_left))
	var m := sec / 60
	var s := sec % 60
	_timer_lbl.text = ("C4 %ds" % sec) if planted else ("%d:%02d" % [m, s])

func _on_money_changed(m: int) -> void:
	_money_lbl.text = "$%d" % m

func _on_health_changed(hp: int, armor: int) -> void:
	_hp_lbl.text = "HP %d | %d" % [hp, armor]

func _on_weapon_changed(w_name: String, mag: int, reserve: int, slot: int, reloading: bool) -> void:
	_weapon_lbl.text = w_name
	if slot == 3:
		_ammo_lbl.text = "MELEE"
	elif slot == 4:
		_ammo_lbl.text = "THROW"
	elif reloading:
		_ammo_lbl.text = "RELOAD"
	else:
		_ammo_lbl.text = "%d / %d" % [mag, reserve]

func _on_hitmarker(is_head: bool, killed: bool, dmg: int) -> void:
	_hitmarker_timer = 0.22
	_hitmarker_head = is_head
	_hit_dmg_lbl.visible = true
	_hit_dmg_lbl.text = ("HS -%d!" % dmg) if is_head else ("-%d" % dmg)
	if killed:
		_hit_dmg_lbl.text += " KILL"
	_hit_dmg_lbl.modulate = Color(1.0, 0.28, 0.22) if is_head else Color(1.0, 0.92, 0.45)

func _on_damage_taken() -> void:
	_damage_flash_timer = 0.25

func _on_action_prompt(vis: bool, label: String, progress: float) -> void:
	_action_btn.visible = vis
	_action_btn.text = label
	_action_bar.visible = vis and progress > 0.0
	_action_bar.value = progress

func _on_announcement(title: String, sub: String, col: Color) -> void:
	_announce_title.text = title
	_announce_title.modulate = col
	_announce_sub.text = sub
	_announce_box.visible = true
	_announce_timer = 2.8

func _on_state_changed(st: int) -> void:
	if st == GameManager.MatchState.MATCH_OVER:
		_match_over_panel.visible = true
		var won := (GameManager.ct_score > GameManager.t_score and GameManager.player_team == GameManager.Team.CT) or (GameManager.t_score > GameManager.ct_score and GameManager.player_team == GameManager.Team.T)
		_match_over_lbl.text = ("MATCH VICTORY (%d - %d)" if won else "MATCH DEFEAT (%d - %d)") % [GameManager.ct_score, GameManager.t_score]

func _on_kill_feed_added(k_name: String, k_team: int, v_name: String, v_team: int, w_short: String, head: bool) -> void:
	var row := Label.new()
	var hs := " [HS]" if head else ""
	row.text = "%s  [%s%s]  %s" % [k_name, w_short, hs, v_name]
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_theme_font_size_override("font_size", 14)
	row.modulate = Color(0.55, 0.78, 1.0) if k_team == GameManager.Team.CT else Color(1.0, 0.74, 0.42)
	if v_team == k_team:
		row.modulate = Color(0.95, 0.4, 0.4)
	_kill_feed_box.add_child(row)
	if _kill_feed_box.get_child_count() > 5:
		_kill_feed_box.get_child(0).queue_free()

func refresh_alive_counts(counts: Dictionary) -> void:
	_ct_alive_lbl.text = "CT %d" % counts.get(GameManager.Team.CT, 0)
	_t_alive_lbl.text = "%d T" % counts.get(GameManager.Team.T, 0)
