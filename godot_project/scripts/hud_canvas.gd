extends Control

var hud = null

func _draw() -> void:
	if hud == null:
		return
	var sz: Vector2 = get_viewport_rect().size
	var center: Vector2 = sz * 0.5

	# Dynamic Crosshair
	var gap := 10.0
	if hud._player != null and hud._player.is_alive:
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
		var dirs := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
		for d in dirs:
			draw_line(center + d * 5.0, center + d * 13.0, hm_col, 2.2)

	# Virtual Joystick Visual
	var joy_c: Vector2 = hud._joy_origin if hud._joy_finger != -1 else Vector2(115.0, sz.y - 145.0)
	var joy_k: Vector2 = hud._joy_current if hud._joy_finger != -1 else joy_c
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
	if hud._player != null:
		for ag in hud._agents:
			if not is_instance_valid(ag) or not ag.is_alive:
				continue
			if ag.team != hud._player.team:
				continue
			var rp := map_center + Vector2(ag.global_position.x, ag.global_position.z) * scale_f
			rp = rp.clamp(map_rect.position + Vector2(4, 4), map_rect.end - Vector2(4, 4))
			var dot_col := Color(0.2, 1.0, 0.55) if ag == hud._player else Color(0.35, 0.72, 1.0)
			draw_circle(rp, 4.0 if ag == hud._player else 3.0, dot_col)
