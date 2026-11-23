extends Node3D

enum State { SERVE, PLAY, POINT, GAMEOVER }

# Paddle x min.
@export var paddle_x_min: float = -1.0
# Paddle x max.
@export var paddle_x_max: float = 1.0
# Paddle z min.
@export var paddle_z_min: float = 0.3
# Paddle z max.
@export var paddle_z_max: float = 1.7
# Paddle y max.
@export var paddle_y: float = 0.2
# Rebound strengh.
@export var rebound_strengh: float = 0.85
# Camera shake.
@export var camera_shake_intensity: float = 0.03

var _state: State = State.SERVE
# 1 is local player, -1 is the other player
var _server: int = 1
var _last_hitter: int = 1
var _player_x: float = 0.0
var _player_z: float = 0.0
var _ball_position: Vector3 = Vector3.ZERO
var _ball_velocity: Vector3 = Vector3.ZERO
var _camera_shake: float = 0.0
var _mouse_button_left_pressed: bool = false
var _mouse_button_right_pressed: bool = false
var _timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _ball_radius: float = 0.03
var _table_size_x: float = 1.5
var _table_size_z: float = 2.8
var _serve_bounced: bool = false
var _already_bounced: bool = false
var _score: Dictionary = { 1: 0, -1: 0 }

@onready var camera_3d: Camera3D = $Camera3D
@onready var label_3d: Label3D = $Label3D
@onready var paddle: Node3D = $Paddle
@onready var ball: Node3D = $Ball


func _ready() -> void:
	_reset_serve()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_button_left_pressed = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_button_right_pressed = true


func _physics_process(delta: float) -> void:
	_update_player(delta)
	
	# TODO: use LimboAI ?
	match _state:
		State.SERVE:
			_serve(delta)
		State.PLAY:
			_play(delta)
		State.POINT:
			_point(delta)
			
	_update_visuals(delta)
	_mouse_button_left_pressed = false


func _reset_serve() -> void:
	_state = State.SERVE
	if _server == 1:
		label_3d.text = "Clic pour servir\nSouris pour bouger\nSmash : clic gauche\nAmorti : clic droit"
	else:
		label_3d.text = "L'autre sert..."
	_timer = 1.0


func _update_player(delta: float) -> void:
	var screen_size_x := get_viewport().get_visible_rect().size.x
	var screen_size_y := get_viewport().get_visible_rect().size.y
	
	var x: float = clampf((get_viewport().get_mouse_position().x / screen_size_x), 0.0, 1.0)
	_player_x = move_toward(_player_x, lerpf(paddle_x_min, paddle_x_max, x), delta * 6.0)
	
	# fix z when serve
	if _state == State.SERVE and _server == 1:
		_player_z = move_toward(_player_z, paddle_z_max * _server, delta * 6.0)
	else:
		var z: float = clampf((get_viewport().get_mouse_position().y / screen_size_y), 0.0, 1.0)
		_player_z = move_toward(_player_z, lerpf(paddle_z_min, paddle_z_max, z), delta * 6.0)


func _update_visuals(delta: float) -> void:
	# paddle position
	paddle.position = Vector3(_player_x, paddle_y, _player_z)
	
	# ball position
	ball.position = _ball_position
	
	# camera position
	camera_3d.position.x = lerpf(camera_3d.position.x, _ball_position.x * 0.15, delta * 2.0)
	camera_3d.look_at(Vector3(0, 0.3, 0))

	# camera shake
	camera_3d.h_offset = randf_range(-_camera_shake, _camera_shake)
	camera_3d.v_offset = randf_range(-_camera_shake, _camera_shake)
	_camera_shake = move_toward(_camera_shake, 0.0, delta * 0.2)


func _serve(delta: float) -> void:
	if _server == 1:
		_ball_position = Vector3(_player_x, paddle_y + 0.3, paddle_z_max)
		if _mouse_button_left_pressed:
			_launch_serve(_player_x)
	else:
		_ball_position = Vector3(0.0, paddle_y + 0.3, -paddle_z_max)
		_timer -= delta
		if _timer <= 0.0:
			_launch_serve(0.0)


func _launch_serve(x: float) -> void:
	_ball_velocity = Vector3((randf_range(-0.5, 0.5) - x) / 0.95, 0.0, -2.9)
	_last_hitter = _server
	_state = State.PLAY
	_already_bounced = false
	_serve_bounced = false
	#rally = 0
	label_3d.text = ""
	#_pop(paddle_p if server == 1 else paddle_a, 40.0)
	#_sfx_hit(Shot.NORMAL)


func _apply_velocity_to_ball(delta: float) -> void:
	_ball_velocity.y -= _gravity * delta
	_ball_position += _ball_velocity * delta


func _table_bounce() -> int:
	if _ball_velocity.y < 0.0 and _ball_position.y <= _ball_radius and absf(_ball_position.x) <= _table_size_x / 2 and absf(_ball_position.z) <= _table_size_z / 2:
		_ball_position.y = _ball_radius
		_ball_velocity.y = -_ball_velocity.y * rebound_strengh
		_ball_velocity.x *= 0.98
		_ball_velocity.z *= 0.98
		if _ball_position.z > 0.0:
			return 1
		else:
			return -1
	return 0


func _play(delta: float) -> void:
	_apply_velocity_to_ball(delta)
	
	var bounced: int = _table_bounce()
	
	if bounced != 0:
		if bounced == _last_hitter:
			if !_serve_bounced:
				_serve_bounced = true
			else:
				_end_point(-_last_hitter)
		elif _already_bounced:
			_end_point(_last_hitter)
		else:
			_already_bounced = true
	
	# out
	if _ball_position.y <= 0.0:
		if _already_bounced:
			_end_point(_last_hitter)
		else:
			_end_point(-_last_hitter)


func _end_point(winner: int) -> void:
	_score[winner] += 1
	_state = State.POINT
	_timer = 2.0
	if winner == 1:
		label_3d.text = "Point pour toi !"
	elif winner == -1:
		label_3d.text = "Point pour l'IA"


func _point(delta: float) -> void:
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
