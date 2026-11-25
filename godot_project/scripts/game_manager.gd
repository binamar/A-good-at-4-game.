extends Node

signal state_changed(new_state: int)
signal score_changed(ct_score: int, t_score: int, round_num: int)
signal timer_updated(seconds_left: float, bomb_planted: bool)
signal money_updated(money: int)
signal kill_feed_added(killer_name: String, killer_team: int, victim_name: String, victim_team: int, weapon_short: String, is_headshot: bool)
signal announcement_triggered(title: String, subtitle: String, color: Color)
signal bomb_state_changed(planted: bool, site_name: String, progress: float)

enum Team {
	CT = 1,
	T = 2,
}

enum MatchState {
	MENU,
	FREEZE_BUY,
	LIVE,
	BOMB_PLANTED,
	ROUND_END,
	MATCH_OVER,
}

const ROUNDS_TO_WIN := 7
const FREEZE_DURATION := 3.5
const ROUND_DURATION := 110.0
const BOMB_DURATION := 40.0
const ROUND_END_DURATION := 3.5

var state: int = MatchState.MENU
var player_team: int = 1
var ct_score: int = 0
var t_score: int = 0
var current_round: int = 1
var phase_timer: float = 0.0

var player_money: int = 1000
var player_has_armor: bool = false
var player_has_defuse_kit: bool = false
var player_has_grenade: bool = false
var player_primary_weapon: int = -1
var player_secondary_weapon: int = 1
var player_round_kills: int = 0

var scoreboard: Dictionary = {} # agent_name -> {team, kills, deaths}

var bomb_planted: bool = false
var bomb_site_name: String = ""
var bomb_position: Vector3 = Vector3.ZERO
var bomb_beep_accum: float = 0.0

var match_controller: Node = null
var touch_sensitivity: float = 0.28

func start_new_match(chosen_team: int) -> void:
	player_team = chosen_team
	ct_score = 0
	t_score = 0
	current_round = 1
	player_money = 1000
	player_has_armor = false
	player_has_defuse_kit = false
	player_has_grenade = false
	player_primary_weapon = -1
	player_secondary_weapon = WeaponData.WeaponId.USP_PISTOL if chosen_team == Team.CT else WeaponData.WeaponId.GLOCK_PISTOL
	player_round_kills = 0
	scoreboard.clear()
	bomb_planted = false
	bomb_site_name = ""
	state = MatchState.FREEZE_BUY
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func register_match_controller(ctrl: Node) -> void:
	match_controller = ctrl
	_begin_round()

func return_to_menu() -> void:
	state = MatchState.MENU
	match_controller = null
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _process(delta: float) -> void:
	if state == MatchState.MENU or state == MatchState.MATCH_OVER or match_controller == null:
		return

	phase_timer -= delta
	if state == MatchState.BOMB_PLANTED:
		var ratio := clampf(phase_timer / BOMB_DURATION, 0.0, 1.0)
		var beep_interval := lerpf(0.16, 1.0, ratio)
		bomb_beep_accum += delta
		if bomb_beep_accum >= beep_interval:
			bomb_beep_accum = 0.0
			AudioManager.play_sfx("beep", -7.0, 0.0)
		timer_updated.emit(maxf(0.0, phase_timer), true)
		if phase_timer <= 0.0:
			_on_bomb_exploded()
	else:
		timer_updated.emit(maxf(0.0, phase_timer), false)
		if phase_timer <= 0.0:
			match state:
				MatchState.FREEZE_BUY:
					state = MatchState.LIVE
					phase_timer = ROUND_DURATION
					state_changed.emit(state)
					announcement_triggered.emit("ROUND LIVE", "Eliminate enemies or play the objective", Color(0.95, 0.96, 0.98))
				MatchState.LIVE:
					_end_round(Team.CT, "Time Expired — Bomb Not Planted")
				MatchState.ROUND_END:
					if ct_score >= ROUNDS_TO_WIN or t_score >= ROUNDS_TO_WIN:
						state = MatchState.MATCH_OVER
						state_changed.emit(state)
						var win_team := Team.CT if ct_score >= ROUNDS_TO_WIN else Team.T
						var msg := "VICTORY" if win_team == player_team else "DEFEAT"
						var col := Color(0.22, 0.78, 0.45) if win_team == player_team else Color(0.92, 0.28, 0.28)
						announcement_triggered.emit("MATCH " + msg, "Final Score: CT %d - %d T" % [ct_score, t_score], col)
					else:
						current_round += 1
						_begin_round()

func _begin_round() -> void:
	bomb_planted = false
	bomb_site_name = ""
	bomb_beep_accum = 0.0
	player_round_kills = 0
	state = MatchState.FREEZE_BUY
	phase_timer = FREEZE_DURATION
	if match_controller and match_controller.has_method("setup_round_entities"):
		match_controller.setup_round_entities()
	state_changed.emit(state)
	score_changed.emit(ct_score, t_score, current_round)
	money_updated.emit(player_money)
	bomb_state_changed.emit(false, "", 0.0)
	announcement_triggered.emit("ROUND %d" % current_round, "Tap BUY to gear up — Move unlocks in 3s", Color(0.96, 0.68, 0.18))

func is_movement_frozen() -> bool:
	return state == MatchState.FREEZE_BUY or state == MatchState.MATCH_OVER

func can_buy() -> bool:
	return state == MatchState.FREEZE_BUY or (state == MatchState.LIVE and phase_timer >= ROUND_DURATION - 10.0)

func add_money(amount: int) -> void:
	player_money = clampi(player_money + amount, 0, 16000)
	money_updated.emit(player_money)

func try_buy_weapon(weapon_id: int) -> bool:
	if not can_buy():
		return false
	var stats := WeaponData.get_stats(weapon_id)
	var price: int = stats["price"]
	if player_money < price:
		return false
	if stats["is_grenade"] and player_has_grenade:
		return false
	player_money -= price
	if stats["slot"] == 1:
		player_primary_weapon = weapon_id
	elif stats["slot"] == 2:
		player_secondary_weapon = weapon_id
	elif stats["slot"] == 4:
		player_has_grenade = true
	money_updated.emit(player_money)
	if match_controller and match_controller.has_method("give_player_weapon"):
		match_controller.give_player_weapon(weapon_id)
	AudioManager.play_sfx("reload", -6.0, 0.02)
	return true

func try_buy_armor() -> bool:
	if not can_buy() or player_has_armor or player_money < 650:
		return false
	player_money -= 650
	player_has_armor = true
	money_updated.emit(player_money)
	if match_controller and match_controller.has_method("apply_player_armor"):
		match_controller.apply_player_armor()
	AudioManager.play_sfx("reload", -6.0, 0.02)
	return true

func try_buy_defuse_kit() -> bool:
	if not can_buy() or player_team != Team.CT or player_has_defuse_kit or player_money < 400:
		return false
	player_money -= 400
	player_has_defuse_kit = true
	money_updated.emit(player_money)
	AudioManager.play_sfx("reload", -6.0, 0.02)
	return true

func plant_bomb(site_name: String, world_pos: Vector3) -> void:
	if state != MatchState.LIVE or bomb_planted:
		return
	bomb_planted = true
	bomb_site_name = site_name
	bomb_position = world_pos
	bomb_beep_accum = 0.0
	state = MatchState.BOMB_PLANTED
	phase_timer = BOMB_DURATION
	state_changed.emit(state)
	bomb_state_changed.emit(true, site_name, 1.0)
	AudioManager.play_sfx("plant", -3.0, 0.0)
	announcement_triggered.emit("BOMB PLANTED", "Site %s — 40s to detonation" % site_name, Color(0.95, 0.30, 0.25))
	if match_controller and match_controller.has_method("spawn_planted_bomb"):
		match_controller.spawn_planted_bomb(world_pos)

func defuse_bomb() -> void:
	if state != MatchState.BOMB_PLANTED:
		return
	bomb_planted = false
	bomb_state_changed.emit(false, "", 0.0)
	AudioManager.play_sfx("win", -3.0, 0.0)
	_end_round(Team.CT, "Bomb Defused")

func _on_bomb_exploded() -> void:
	bomb_planted = false
	bomb_state_changed.emit(false, "", 0.0)
	AudioManager.play_sfx("explode", -1.0, 0.0)
	_end_round(Team.T, "Target Detonated")

func register_agent_scoreboard(ag_name: String, ag_team: int) -> void:
	if not scoreboard.has(ag_name):
		scoreboard[ag_name] = {"team": ag_team, "kills": 0, "deaths": 0}
	else:
		scoreboard[ag_name]["team"] = ag_team

func register_kill(killer_name: String, killer_team: int, victim_name: String, victim_team: int, weapon_short: String, is_headshot: bool, killer_is_player: bool) -> void:
	register_agent_scoreboard(killer_name, killer_team)
	register_agent_scoreboard(victim_name, victim_team)
	if killer_team != victim_team:
		scoreboard[killer_name]["kills"] += 1
	scoreboard[victim_name]["deaths"] += 1

	kill_feed_added.emit(killer_name, killer_team, victim_name, victim_team, weapon_short, is_headshot)
	if killer_is_player and killer_team != victim_team:
		add_money(300)
		player_round_kills += 1
		if player_round_kills == 2:
			AudioManager.play_sfx("multikill", -4.0, 0.0)
			announcement_triggered.emit("DOUBLE KILL", "+$300 Elimination Bonus", Color(0.98, 0.78, 0.22))
		elif player_round_kills == 3:
			AudioManager.play_sfx("multikill", -3.0, 0.05)
			announcement_triggered.emit("TRIPLE KILL!", "Dominating the round", Color(0.98, 0.48, 0.22))
		elif player_round_kills == 4:
			AudioManager.play_sfx("multikill", -2.0, 0.08)
			announcement_triggered.emit("QUAD KILL!", "One enemy left!", Color(0.95, 0.28, 0.28))
		elif player_round_kills >= 5:
			AudioManager.play_sfx("multikill", -1.0, 0.1)
			announcement_triggered.emit("ACE!", "5-Kill Sweep!", Color(0.25, 0.92, 0.55))

	if victim_name == "You":
		player_primary_weapon = -1
		player_has_armor = false
		player_has_defuse_kit = false
		player_has_grenade = false
	_check_team_elimination()

func _check_team_elimination() -> void:
	if state != MatchState.LIVE and state != MatchState.BOMB_PLANTED:
		return
	if match_controller == null:
		return
	var alive_counts: Dictionary = match_controller.get_alive_counts()
	var ct_alive: int = alive_counts.get(Team.CT, 0)
	var t_alive: int = alive_counts.get(Team.T, 0)
	if ct_alive <= 0:
		_end_round(Team.T, "Counter-Terrorists Eliminated")
	elif t_alive <= 0 and not bomb_planted:
		_end_round(Team.CT, "Terrorists Eliminated")

func _end_round(winner_team: int, reason: String) -> void:
	if state == MatchState.ROUND_END or state == MatchState.MATCH_OVER:
		return
	state = MatchState.ROUND_END
	phase_timer = ROUND_END_DURATION
	if winner_team == Team.CT:
		ct_score += 1
	else:
		t_score += 1
	if winner_team == player_team:
		add_money(3250)
		AudioManager.play_sfx("win", -4.0, 0.0)
	else:
		add_money(1900)
	score_changed.emit(ct_score, t_score, current_round)
	state_changed.emit(state)
	var title := "CT WIN" if winner_team == Team.CT else "T WIN"
	var col := Color(0.28, 0.62, 0.96) if winner_team == Team.CT else Color(0.94, 0.64, 0.22)
	announcement_triggered.emit(title, reason, col)
