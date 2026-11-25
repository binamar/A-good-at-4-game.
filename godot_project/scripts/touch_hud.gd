extends CanvasLayer

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
var _action_btn: Button
var _action_bar: ProgressBar

# Overlays
var _buy_panel: PanelContainer
var _pause_panel: PanelContainer
var _match_over_panel: PanelContainer
var _match_over_lbl: Label

var _hitmarker_timer: float = 0.0
var _hitmarker_head: bool = false

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
	_player.health_changed.connect(_on_health_changed)
	_player.weapon_changed.connect(_on_weapon_changed)
	_player.hitmarker_triggered.connect(_on_hitmarker)
	_player.action_prompt_changed.connect(_on_action_prompt)

func _build_hud() -> void:
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	_draw_layer = _HudCanvas.new()
	_draw_layer.hud = self
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
	_timer_lbl = _make_chip_label("1:45", Color(0.12, 0.15, 0.20), 86)
	_t_alive_lbl = _make_chip_label("5 T", Color(0.90, 0.56, 0.18), 68)
	top_bar.add_child(_ct_alive_lbl)
	top_bar.add_child(_top_score_lbl)
	top_bar.add_child(_timer_lbl)
	top_bar.add_child(_t_alive_lbl)

	# Kill Feed (Top Right)
	_kill_feed_box = VBoxContainer.new()
	_kill_feed_box.anchor_left = 1.0
	_kill_feed_box.anchor_right = 1.0
	_kill_feed_box.offset_left = -320
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

	_hp_lbl = _make_chip_label("HP 100", Color(0.11, 0.14, 0.19, 0.85), 116)
	_money_lbl = _make_chip_label("$800", Color(0.12, 0.42, 0.22, 0.88), 96)
	status_box.add_child(_hp_lbl)
	status_box.add_child(_money_lbl)

	# Bottom Center Weapon & Ammo
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

	# Top Left Utility Buttons (Menu + Buy)
	_pause_btn = _make_touch_btn("MENU", Vector2(18, 162), Vector2(84, 42))
	_pause_btn.anchor_left = 0.0
	_pause_btn.anchor_top = 0.0
	_pause_btn.pressed.connect(_toggle_pause)
	_hud_root.add_child(_pause_btn)

	_buy_btn = _make_touch_btn("BUY", Vector2(110, 162), Vector2(84, 42))
	_buy_btn.anchor_left = 0.0
	_buy_btn.anchor_top = 0.0
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
	_ads_btn.pressed.connect(func(): if _player: _player.toggle_ads())
	_hud_root.add_child(_ads_btn)

	_jump_btn = _make_anchored_br_btn("JUMP", Vector2(-248, -120), Vector2(82, 54))
	_jump_btn.pressed.connect(func(): if _player: _player.trigger_jump())
	_hud_root.add_child(_jump_btn)

	_crouch_btn = _make_anchored_br_btn("CROUCH", Vector2(-340, -120), Vector2(82, 54))
	_crouch_btn.pressed.connect(func(): if _player: _player.toggle_crouch())
	_hud_root.add_child(_crouch_btn)

	_reload_btn = _make_anchored_br_btn("RELOAD", Vector2(-248, -260), Vector2(82, 52))
	_reload_btn.pressed.connect(func(): if _player: _player.trigger_reload())
	_hud_root.add_child(_reload_btn)

	_swap_btn = _make_anchored_br_btn("SWAP", Vector2(-146, -84), Vector2(114, 48))
	_swap_btn.pressed.connect(func(): if _player: _player.cycle_weapon())
	_hud_root.add_child(_swap_btn)

	# Contextual Plant / Defuse Hold Button
	_action_btn = Button.new()
	_action_btn.anchor_left = 0.5
	_action_btn.anchor_right = 0.5
	_action_btn.anchor_top = 0.65
	_action_btn.anchor_bottom = 0.65
	_action_btn.offset_left = -135
	_action_btn.offset_right = 135
	_action_btn.offset_top = 0
	_action_btn.offset_bottom = 52
	_action_btn.text = "HOLD TO PLANT C4"
	_action_btn.visible = false
	_action_btn.button_down.connect(func(): if _player: _player.is_action_held = true)
	_action_btn.button_up.connect(func(): if _player: _player.is_action_held = false)
	_hud_root.add_child(_action_btn)

	_action_bar = ProgressBar.new()
	_action_bar.anchor_left = 0.5
	_action_bar.anchor_right = 0.5
	_action_bar.anchor_top = 0.65
	_action_bar.anchor_bottom = 0.65
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
	_announce_box.offset_left = -210
	_announce_box.offset_right = 210
	_announce_box.offset_top = 80
	_announce_box.offset_bottom = 148
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
	_build_match_over_panel()

func _build_buy_panel() -> void:
	_buy_panel = PanelContainer.new()
	_buy_panel.anchor_left = 0.5
	_buy_panel.anchor_right = 0.5
	_buy_panel.anchor_top = 0.5
	_buy_panel.anchor_bottom = 0.5
	_buy_panel.offset_left = -260
	_buy_panel.offset_right = 260
	_buy_panel.offset_top = -180
	_buy_panel.offset_bottom = 180
	_buy_panel.visible = false
	_hud_root.add_child(_buy_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_buy_panel.add_child(vbox)

	var title := Label.new()
	title.text = "TACTICAL BUY MENU (FREEZE PHASE)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var items := [
		["AK-47 Rifle ($2700)", func(): GameManager.try_buy_weapon(WeaponData.WeaponId.AK47_RIFLE)],
		["M4A1-Carbine ($2900)", func(): GameManager.try_buy_weapon(WeaponData.WeaponId.M4_RIFLE)],
		["MP5-SD SMG ($1500)", func(): GameManager.try_buy_weapon(WeaponData.WeaponId.MP5_SMG)],
		["USP-Tactical Pistol ($200)", func(): GameManager.try_buy_weapon(WeaponData.WeaponId.USP_PISTOL)],
		["Kevlar Vest Armor ($650)", func(): GameManager.try_buy_armor()],
		["Defuse Kit - CT Only ($400)", func(): GameManager.try_buy_defuse_kit()],
	]
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(0, 42)
		b.pressed.connect(item[1])
		vbox.add_child(b)

	var close_b := Button.new()
	close_b.text = "CLOSE"
	close_b.custom_minimum_size = Vector2(0, 42)
	close_b.pressed.connect(func(): _buy_panel.visible = false)
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

	var sens_lbl := Label.new()
	sens_lbl.text = "Touch Look Sensitivity: %.2f" % GameManager.touch_sensitivity
	vbox.add_child(sens_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.10
	slider.max_value = 0.70
	slider.step = 0.02
	slider.value = GameManager.touch_sensitivity
	slider.value_changed.connect(func(v: float):
		GameManager.touch_sensitivity = v
		sens_lbl.text = "Touch Look Sensitivity: %.2f" % v
	)
	vbox.add_child(slider)

	var resume_b := Button.new()
	resume_b.text = "RESUME MATCH"
	resume_b.custom_minimum_size = Vector2(0, 44)
	resume_b.pressed.connect(func(): _pause_panel.visible = false)
	vbox.add_child(resume_b)

	var quit_b := Button.new()
	quit_b.text = "EXIT TO MAIN MENU"
	quit_b.custom_minimum_size = Vector2(0, 44)
	quit_b.pressed.connect(func(): GameManager.return_to_menu())
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
	replay_b.pressed.connect(func(): GameManager.start_new_match(GameManager.player_team))
	vbox.add_child(replay_b)

	var menu_b := Button.new()
	menu_b.text = "MAIN MENU"
	menu_b.custom_minimum_size = Vector2(0, 46)
	menu_b.pressed.connect(func(): GameManager.return_to_menu())
	vbox.add_child(menu_b)

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

func _input(event: InputEvent) -> void:
	if _buy_panel.visible or _pause_panel.visible or _match_over_panel.visible or _player == null:
		return

	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			if _fire_btn.get_global_rect().has_point(pos):
				_fire_finger = event.index
				_player.set_fire_pressed(true)
				return
			# Ignore touches starting on other GUI buttons
			for btn in [_ads_btn, _jump_btn, _crouch_btn, _reload_btn, _swap_btn, _buy_btn, _pause_btn, _action_btn]:
				if btn.visible and btn.get_global_rect().has_point(pos):
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
		if event.index == _joy_finger:
			var delta_v: Vector2 = event.position - _joy_origin
			if delta_v.length() > JOY_RADIUS:
				delta_v = delta_v.normalized() * JOY_RADIUS
			_joy_current = _joy_origin + delta_v
			_player.move_input = delta_v / JOY_RADIUS
		elif event.index == _look_finger or event.index == _fire_finger:
			_player.add_look_delta(event.relative)

func _process(delta: float) -> void:
	if _hitmarker_timer > 0.0:
		_hitmarker_timer -= delta
	if _announce_timer > 0.0:
		_announce_timer -= delta
		if _announce_timer <= 0.0:
			_announce_box.visible = false
	_buy_btn.visible = GameManager.can_buy()
	if not GameManager.can_buy() and _buy_panel.visible:
		_buy_panel.visible = false
	_draw_layer.queue_redraw()

func _toggle_buy_menu() -> void:
	if GameManager.can_buy():
		_buy_panel.visible = not _buy_panel.visible

func _toggle_pause() -> void:
	_pause_panel.visible = not _pause_panel.visible

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
	elif reloading:
		_ammo_lbl.text = "RELOAD"
	else:
		_ammo_lbl.text = "%d / %d" % [mag, reserve]

func _on_hitmarker(is_head: bool, _killed: bool) -> void:
	_hitmarker_timer = 0.14
	_hitmarker_head = is_head

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

class _HudCanvas extends Control:
	var hud: CanvasLayer

	func _draw() -> void:
		if hud == null:
			return
		var sz := get_viewport_rect().size
		var center := sz * 0.5

		# Dynamic Crosshair
		var gap := 10.0
		if hud._player and hud._player.is_alive:
			gap = hud._player.get_current_spread_px()
		var line_len := 8.0
		var ch_col := Color(0.25, 0.98, 0.55, 0.92)
		draw_line(center + Vector2(-gap - line_len, 0), center + Vector2(-gap, 0), ch_col, 2.0)
		draw_line(center + Vector2(gap, 0), center + Vector2(gap + line_len, 0), ch_col, 2.0)
		draw_line(center + Vector2(0, -gap - line_len), center + Vector2(0, -gap), ch_col, 2.0)
		draw_line(center + Vector2(0, gap), center + Vector2(0, gap + line_len), ch_col, 2.0)

		# Hitmarker X
		if hud._hitmarker_timer > 0.0:
			var hm_col := Color(1.0, 0.25, 0.22) if hud._hitmarker_head else Color(1.0, 1.0, 1.0)
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(center + d * 5.0, center + d * 13.0, hm_col, 2.2)

		# Virtual Joystick Visual
		var joy_c := hud._joy_origin if hud._joy_finger != -1 else Vector2(115.0, sz.y - 145.0)
		var joy_k := hud._joy_current if hud._joy_finger != -1 else joy_c
		draw_circle(joy_c, hud.JOY_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(joy_c, hud.JOY_RADIUS, 0.0, TAU, 28, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(joy_k, 28.0, Color(1, 1, 1, 0.48))

		# Tactical Radar Minimap (Top-Left)
		var map_rect := Rect2(18, 16, 134, 134)
		draw_rect(map_rect, Color(0.06, 0.09, 0.13, 0.78))
		draw_rect(map_rect, Color(0.45, 0.55, 0.68, 0.5), false, 1.5)
		var map_center := map_rect.get_center()
		var scale_f := 2.1

		# A & B site squares on radar
		var a_pos := map_center + Vector2(18.0, -6.0) * scale_f
		var b_pos := map_center + Vector2(-18.0, -6.0) * scale_f
		draw_rect(Rect2(a_pos - Vector2(7, 7), Vector2(14, 14)), Color(0.95, 0.45, 0.25, 0.65))
		draw_rect(Rect2(b_pos - Vector2(7, 7), Vector2(14, 14)), Color(0.28, 0.66, 0.96, 0.65))

		# Bomb dot
		if GameManager.bomb_planted:
			var bp := map_center + Vector2(GameManager.bomb_position.x, GameManager.bomb_position.z) * scale_f
			draw_circle(bp, 4.5, Color(1.0, 0.2, 0.2))

		# Agents on radar (Player + Teammates)
		if hud._player:
			for ag in hud._agents:
				if not is_instance_valid(ag) or not ag.is_alive:
					continue
				if ag.team != hud._player.team:
					continue
				var rp := map_center + Vector2(ag.global_position.x, ag.global_position.z) * scale_f
				rp = rp.clamp(map_rect.position + Vector2(4, 4), map_rect.end - Vector2(4, 4))
				var dot_col := Color(0.2, 1.0, 0.55) if ag == hud._player else Color(0.35, 0.72, 1.0)
				draw_circle(rp, 4.0 if ag == hud._player else 3.0, dot_col)
