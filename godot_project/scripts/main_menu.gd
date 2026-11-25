extends Control

@onready var ct_btn: Button = $CenterBox/Panel/VBox/TeamRow/CTButton
@onready var t_btn: Button = $CenterBox/Panel/VBox/TeamRow/TButton
@onready var sens_label: Label = $CenterBox/Panel/VBox/SensLabel
@onready var sens_slider: HSlider = $CenterBox/Panel/VBox/SensSlider
@onready var play_btn: Button = $CenterBox/Panel/VBox/PlayButton

var _selected_team: int = 1

func _ready() -> void:
	_selected_team = GameManager.Team.CT
	sens_slider.value = GameManager.touch_sensitivity
	_update_sens_label(GameManager.touch_sensitivity)
	_select_team(GameManager.Team.CT)

	ct_btn.pressed.connect(_on_ct_pressed)
	t_btn.pressed.connect(_on_t_pressed)
	sens_slider.value_changed.connect(_on_sens_changed)
	play_btn.pressed.connect(_on_play_pressed)

func _on_ct_pressed() -> void:
	_select_team(GameManager.Team.CT)

func _on_t_pressed() -> void:
	_select_team(GameManager.Team.T)

func _on_sens_changed(v: float) -> void:
	GameManager.touch_sensitivity = v
	_update_sens_label(v)

func _on_play_pressed() -> void:
	GameManager.start_new_match(_selected_team)

func _select_team(team_id: int) -> void:
	_selected_team = team_id
	ct_btn.modulate = Color(0.35, 0.72, 1.0) if team_id == GameManager.Team.CT else Color(0.65, 0.65, 0.70)
	t_btn.modulate = Color(1.0, 0.68, 0.30) if team_id == GameManager.Team.T else Color(0.65, 0.65, 0.70)

func _update_sens_label(v: float) -> void:
	sens_label.text = "Touch Look Sensitivity: %.2f" % v
