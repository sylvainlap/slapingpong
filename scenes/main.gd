extends Node3D

enum State { SERVE, PLAY, POINT, GAMEOVER }
enum Shot { NORMAL, SMASH, DROP }

const TABLE_HALF_WIDTH: float = 1.5 / 2.0
const TABLE_HALF_LENGTH: float = 2.8 / 2.0
const NET_HEIGHT: float = 0.2
const BALL_RADIUS: float = 0.03
const PLAYER_SIDE := 1
const AI_SIDE := -1

@export_category("Ball Physic")
@export var gravity: float = -7.0
@export var bounce_restitution: float = 0.85
@export var bounce_damping: float = 0.98
@export var out_of_play_x: float = 3.0
@export var out_of_play_y: float = -0.7
@export var out_of_play_z: float = 2.6
@export_category("Paddle")
@export var paddle_x_min: float = -1.0
@export var paddle_x_max: float = 1.0
@export var paddle_y: float = 0.2
@export var paddle_z_min: float = 0.3
@export var paddle_z_max: float = 1.7
@export_category("Serve and Play")
@export var points_to_win: int = 11
@export var serve_ball_height: float = 0.45
@export var serve_speed: float = 2.9
@export var shot_speed: float = 3.4
@export var smash_speed: float = 6.2
@export var drop_speed: float = 2.3
@export_category("AI")
@export var ai_serve_timer: float = 1.2
@export var ai_speed: float = 1.7
@export var ai_miss_probability: float = 0.12
@export_category("Mouse and Camera")
@export var mouse_sensitivity: float = 0.002
@export var mouse_responsiveness: float = 30.0
@export var camera_shake_intensity: float = 0.03

var _state: State = State.SERVE
var _score: Dictionary = { PLAYER_SIDE: 0, AI_SIDE: 0 }
var _server: int = PLAYER_SIDE
var _message: String = ""
var _timer: float = 0.0

var _ball_position: Vector3 = Vector3.ZERO
var _ball_velocity: Vector3 = Vector3.ZERO
var _last_hitter: int = 0
var _has_served_bounced: bool = false
var _has_bounced: bool = false
var _hit_count: int = 0

var _player_paddle_target_x := 0.0
var _player_paddle_x := 0.0
var _player_paddle_velocity_x := 0.0
var _player_paddle_target_z := 0.0
var _player_paddle_z := 0.0
var _player_paddle_velocity_z := 0.0

var _ai_paddle_target_x := 0.0
var _ai_paddle_x := 0.0
var _ai_paddle_velocity_x := 0.0
var _ai_paddle_target_z := 0.0
var _ai_paddle_z := 0.0
var _ai_paddle_velocity_z := 0.0
var _ai_positioning_error := 0.0

var _camera_shake: float = 0.0
var _mouse_motion: Vector2 = Vector2.ZERO
var _announcement_tween: Tween

@onready var camera_3d: Camera3D = $Camera3D
@onready var paddle_player: Node3D = $PaddlePlayer
@onready var paddle_ai: Node3D = $PaddleAI
@onready var ball: Node3D = $Ball
@onready var label_3d: Label3D = $Label3D
@onready var hit_player: AudioStreamPlayer3D = $Sfx/HitPlayer
@onready var bounce_player: AudioStreamPlayer3D = $Sfx/BouncePlayer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	start_new_game()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_motion += event.screen_relative

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_update_player_paddle(delta)
	_update_ai_paddle(delta)
	
	match _state:
		State.SERVE:
			_serve_state(delta)
		State.PLAY:
			_play_state(delta)
		State.POINT:
			_point_state(delta)
			
	_update_visuals(delta)
	_update_hud()


func set_mouse_sensitivity(mouse_sensitivity_in: float) -> void:
	mouse_sensitivity = mouse_sensitivity_in


func set_difficulty(difficulty_in: int) -> void:
	match difficulty_in:
		0:
			ai_serve_timer = 1.8
			ai_speed = 1.3
			ai_miss_probability = 0.22
		1:
			ai_serve_timer = 1.2
			ai_speed = 1.7
			ai_miss_probability = 0.12
		2:
			ai_serve_timer = 0.8
			ai_speed = 2.2
			ai_miss_probability = 0.05


func start_new_game() -> void:
	_score = { PLAYER_SIDE: 0, AI_SIDE: 0 }
	_server = PLAYER_SIDE
	_player_paddle_x = 0.0
	_player_paddle_z = paddle_z_max
	_ai_paddle_x = 0.0
	_ai_paddle_z = -paddle_z_max
	reset_paddle_input()
	_reset_serve()


func reset_paddle_input() -> void:
	_mouse_motion = Vector2.ZERO
	_player_paddle_target_x = _player_paddle_x
	_player_paddle_target_z = _player_paddle_z


func _reset_serve() -> void:
	_state = State.SERVE
	_last_hitter = 0
	_has_served_bounced = false
	_has_bounced = false
	_hit_count = 0
	_ball_velocity = Vector3.ZERO
	
	if _server == PLAYER_SIDE:
		_message = "Clic pour servir\nSouris pour bouger\nSmash : clic gauche\nAmorti : clic droit"
	else:
		_message = "L'autre sert..."
		_timer = ai_serve_timer


func _serve_state(delta: float) -> void:
	if _server == PLAYER_SIDE:
		_ball_position = Vector3(_player_paddle_x, serve_ball_height, _player_paddle_z)
		if _is_click_just_pressed():
			_launch_serve(_player_paddle_x)
	elif _server == AI_SIDE:
		_ball_position = Vector3(_ai_paddle_x, serve_ball_height, _ai_paddle_z)
		_timer -= delta
		if _timer <= 0.0:
			_launch_serve(_ai_paddle_x)


func _launch_serve(x: float) -> void:
	_ball_velocity = Vector3((randf_range(-0.5, 0.5) - x) / 0.95, 0.0, serve_speed * -_server)
	_last_hitter = _server
	_message = ""
	_state = State.PLAY
	#_animate_paddle_swing(player_paddle if server_side == PLAYER_SIDE else ai_paddle, 40.0)
	_play_hit_sound(Shot.NORMAL)


func _apply_ball_physics(delta: float) -> void:
	_ball_velocity.y += gravity * delta
	_ball_position += _ball_velocity * delta


func _is_ball_landing_on_table() -> bool:
	return _ball_velocity.y < 0.0 and _ball_position.y <= BALL_RADIUS and absf(_ball_position.x) <= TABLE_HALF_WIDTH and absf(_ball_position.z) <= TABLE_HALF_LENGTH


func _table_bounce() -> int:
	if _is_ball_landing_on_table():
		_ball_position.y = BALL_RADIUS
		_ball_velocity.y = -_ball_velocity.y * bounce_restitution
		_ball_velocity.x *= bounce_damping
		_ball_velocity.z *= bounce_damping
		
		if _ball_position.z > 0.0:
			return PLAYER_SIDE
		else:
			return AI_SIDE
	else:
		return 0


func _is_click_just_pressed() -> bool:
	return Input.is_action_just_pressed("smash")


func _is_smash_requested() -> bool:
	return Input.is_action_pressed("smash")


func _is_drop_requested() -> bool:
	return Input.is_action_pressed("drop")


func _play_state(delta: float) -> void:
	_apply_ball_physics(delta)
	
	var bounced: int = _table_bounce()
	
	if bounced != 0:
		_play_bounce_sound()
		if bounced == _last_hitter:
			if !_has_served_bounced:
				_has_served_bounced = true
			else:
				_end_point(-_last_hitter)
		elif _has_bounced:
			_end_point(_last_hitter)
		else:
			_has_bounced = true
	
	# out
	if _ball_position.y <= out_of_play_y:
		if _has_bounced:
			_end_point(_last_hitter)
		else:
			_end_point(-_last_hitter)


func _end_point(winner: int) -> void:
	_score[winner] += 1
	_state = State.POINT
	_timer = 2.0
	if winner == 1:
		_message = "Point pour toi !"
	elif winner == -1:
		_message = "Point pour l'IA"


func _point_state(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_update_server()
		_reset_serve()


func _update_server() -> void:
	var total: int = _score[1] + _score[-1]
	if total % 2 == 0:
		_server = -_server
	else:
		_server = _server


func _update_player_paddle(delta: float) -> void:
	_player_paddle_target_x += _mouse_motion.x * mouse_sensitivity
	_player_paddle_target_z += _mouse_motion.y * mouse_sensitivity
	_mouse_motion = Vector2.ZERO
	
	if _state == State.SERVE and _server == PLAYER_SIDE:
		_player_paddle_target_z = paddle_z_max
	
	_player_paddle_target_x = clampf(_player_paddle_target_x, paddle_x_min, paddle_x_max)
	_player_paddle_target_z = clampf(_player_paddle_target_z, paddle_z_min, paddle_z_max)
	
	var weight: float = 1.0 - exp(-mouse_responsiveness * delta)
	var nx: float = lerpf(_player_paddle_x, _player_paddle_target_x, weight)
	var nz: float = lerpf(_player_paddle_z, _player_paddle_target_z, weight)
	
	_player_paddle_velocity_x = (nx - _player_paddle_x) / delta
	_player_paddle_velocity_z = (nz - _player_paddle_z) / delta
	
	_player_paddle_x = nx
	_player_paddle_z = nz


func _update_ai_paddle(delta: float) -> void:
	if _state == State.SERVE and _server == AI_SIDE:
		_ai_paddle_target_z = -paddle_z_max
		
	# for now
	_ai_paddle_target_z = -paddle_z_max
	
	_ai_paddle_target_x = clampf(_ai_paddle_target_x + _ai_positioning_error, paddle_x_min, paddle_x_max)
	_ai_paddle_target_z = clampf(_ai_paddle_target_z, -paddle_z_max, -paddle_z_min)
	
	var nx := move_toward(_ai_paddle_x, _ai_paddle_target_x, delta * ai_speed)
	var nz := move_toward(_ai_paddle_z, _ai_paddle_target_z, delta * ai_speed)
	
	_ai_paddle_velocity_x = (nx - _ai_paddle_x) / delta
	_ai_paddle_velocity_z = (nz - _ai_paddle_z) / delta
	
	_ai_paddle_x = nx
	_ai_paddle_z = nz


func _update_visuals(delta: float) -> void:
	paddle_player.position = Vector3(_player_paddle_x, paddle_y, _player_paddle_z)
	paddle_ai.position = Vector3(_ai_paddle_x, paddle_y, _ai_paddle_z)
	
	paddle_player.rotation.z = lerpf(paddle_player.rotation.z, clampf(-_player_paddle_velocity_x * 0.12, -0.45, 0.45), delta * 12.0)
	paddle_ai.rotation.z = lerpf(paddle_ai.rotation.z, clampf(-_ai_paddle_velocity_x * 0.12, -0.45, 0.45), delta * 12.0)
	
	ball.position = _ball_position
	
	camera_3d.position.x = lerpf(camera_3d.position.x, _ball_position.x * 0.15, delta * 2.0)
	camera_3d.look_at(Vector3(0, 0.05, 0))

	camera_3d.h_offset = randf_range(-_camera_shake, _camera_shake)
	camera_3d.v_offset = randf_range(-_camera_shake, _camera_shake)
	_camera_shake = move_toward(_camera_shake, 0.0, delta * 0.2)


func _update_hud() -> void:
	#var player_score_text := str(scores[PLAYER_SIDE])
	#var ai_score_text := str(scores[AI_SIDE])
	#if player_score_label.text != player_score_text:
	#	player_score_label.text = player_score_text
	#if ai_score_label.text != ai_score_text:
	#	ai_score_label.text = ai_score_text
	# la pastille dorée indique qui sert
	#player_serve_indicator.modulate.a = 1.0 if server_side == PLAYER_SIDE else 0.0
	#ai_serve_indicator.modulate.a = 1.0 if server_side == AI_SIDE else 0.0

	if label_3d.text != _message:
		label_3d.text = _message


func _play_hit_sound(shot_in: Shot) -> void:
	hit_player.pitch_scale = [1.0, 1.3, 0.8][shot_in]
	hit_player.volume_db = [0.0, -4.0, 4.0][shot_in]
	hit_player.play()


func _play_bounce_sound() -> void:
	bounce_player.pitch_scale = 1.0
	bounce_player.volume_db = 0.0
	bounce_player.play()
