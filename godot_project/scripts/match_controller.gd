extends Node3D

@onready var arena: Node3D = $SandstoneArena
@onready var player: CharacterBody3D = $Player
@onready var bots_root: Node3D = $Bots
@onready var hud: CanvasLayer = $TouchHUD
@onready var spectator_cam: Camera3D = $SpectatorCam

const CT_NAMES := ["Viper", "Pulse", "Ghost", "Nova", "Atlas"]
const T_NAMES := ["Raze", "Kobra", "Dusk", "Blaze", "Vandal"]
const LANES := ["A_SITE", "A_SHORT", "MID", "B_CONN", "B_SITE"]

var bots: Array = []
var all_agents: Array = []

func _ready() -> void:
	var bot_scene := ResourceLoader.load("res://scenes/bot_agent.tscn") as PackedScene
	if bot_scene != null:
		for i in 9:
			var b := bot_scene.instantiate() as CharacterBody3D
			bots_root.add_child(b)
			bots.append(b)
	all_agents.append(player)
	for b in bots:
		all_agents.append(b)

	arena.set_agents_ref(all_agents)
	hud.bind_player(player, arena, all_agents)
	GameManager.register_match_controller(self)

func setup_round_entities() -> void:
	arena.set_bomb_visual(false, Vector3.ZERO)
	spectator_cam.current = false

	var p_team: int = GameManager.player_team
	var p_spawns: Array = arena.ct_spawns if p_team == GameManager.Team.CT else arena.t_spawns
	var p_yaw: float = PI if p_team == GameManager.Team.CT else 0.0
	player.reset_for_round(p_spawns[2], p_yaw, p_team, arena)
	GameManager.register_agent_scoreboard("You", p_team)

	var bot_i := 0

	# Spawn remaining 4 teammates
	for s in 5:
		if s == 2 or bot_i >= bots.size():
			continue
		var bot = bots[bot_i]
		bot_i += 1
		var spawn_pos: Vector3 = p_spawns[s]
		var b_name: String = CT_NAMES[s] if p_team == GameManager.Team.CT else T_NAMES[s]
		var is_carrier := (p_team == GameManager.Team.T and s == 1)
		bot.reset_for_round(spawn_pos, p_team, b_name, LANES[s], is_carrier, arena, all_agents)
		GameManager.register_agent_scoreboard(b_name, p_team)

	# Spawn 5 enemy bots
	var e_team: int = GameManager.Team.T if p_team == GameManager.Team.CT else GameManager.Team.CT
	var e_spawns: Array = arena.ct_spawns if e_team == GameManager.Team.CT else arena.t_spawns
	for s in 5:
		if bot_i >= bots.size():
			break
		var bot = bots[bot_i]
		bot_i += 1
		var b_name: String = CT_NAMES[s] if e_team == GameManager.Team.CT else T_NAMES[s]
		var is_carrier := (e_team == GameManager.Team.T and s == 2)
		bot.reset_for_round(e_spawns[s], e_team, b_name, LANES[s], is_carrier, arena, all_agents)
		GameManager.register_agent_scoreboard(b_name, e_team)

	hud.refresh_alive_counts(get_alive_counts())

func _process(_delta: float) -> void:
	if not player.is_alive and not spectator_cam.current:
		spectator_cam.current = true
	hud.refresh_alive_counts(get_alive_counts())

func give_player_weapon(weapon_id: int) -> void:
	player.give_weapon(weapon_id)

func apply_player_armor() -> void:
	player.apply_armor()

func spawn_planted_bomb(pos: Vector3) -> void:
	arena.set_bomb_visual(true, pos)

func get_alive_counts() -> Dictionary:
	var counts := {GameManager.Team.CT: 0, GameManager.Team.T: 0}
	for ag in all_agents:
		if is_instance_valid(ag) and ag.is_alive:
			counts[ag.team] = counts.get(ag.team, 0) + 1
	return counts
