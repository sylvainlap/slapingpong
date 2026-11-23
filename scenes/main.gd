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
# Paddle y.
@export var paddle_y: float = 0.2
# Paddle responsiveness
@export var paddle_responsiveness: float = 18.0
# Serve strength.
@export var serve_strength: float = 3.0
# Rebound strength.
@export var rebound_strength: float = 0.9
# Camera shake.
@export var camera_shake_intensity: float = 0.03
# Mouse sensitivity
@export var mouse_sensitivity: float = 0.001

var _state: State = State.SERVE
# 1 is local player, -1 is remote player
var _server: int = 1
var _last_hitter: int = 0
var _local_target_position: Vector3 = Vector3.ZERO
var _remote_target_position: Vector3 = Vector3.ZERO
var _ball_position: Vector3 = Vector3.ZERO
var _ball_velocity: Vector3 = Vector3.ZERO
var _camera_shake: float = 0.0
var _timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _ball_radius: float = 0.03
var _table_size_x: float = 1.5
var _table_size_z: float = 2.8
var _serve_bounced: bool = false
var _already_bounced: bool = false
var _score: Dictionary = { 1: 0, -1: 0 }
var _mouse_motion: Vector2 = Vector2.ZERO

@onready var camera_3d: Camera3D = $Camera3D
@onready var label_3d: Label3D = $Label3D
@onready var paddle_local: Node3D = $PaddleLocal
@onready var paddle_remote: Node3D = $PaddleRemote
@onready var ball: Node3D = $Ball


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_reset_serve()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_motion += event.relative

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	match _state:
		State.SERVE:
			_serve_state(delta)
		State.PLAY:
			_play_state(delta)
		State.POINT:
			_point_state(delta)
			
	_update_visuals(delta)


func _reset_serve() -> void:
	_state = State.SERVE
	
	_local_target_position = Vector3(0.0, paddle_y, paddle_z_max)
	_remote_target_position = Vector3(0.0, paddle_y, -paddle_z_max)

	if _server == 1:
		label_3d.text = "Clic pour servir\nSouris pour bouger\nSmash : clic gauche\nAmorti : clic droit"
	else:
		label_3d.text = "L'autre sert..."
		_timer = 1.0


func _serve_state(delta: float) -> void:
	if _server == 1:
		_ball_position = paddle_local.position
		_ball_position.y += 0.3
		if Input.is_action_just_pressed("left_click"):
			_launch_serve(paddle_local.position.x)
	elif _server == -1:
		_ball_position = paddle_remote.position
		_ball_position.y += 0.3
		_timer -= delta
		if _timer <= 0.0:
			_launch_serve(paddle_remote.position.x)


func _launch_serve(x: float) -> void:
	_ball_velocity = Vector3((randf_range(-0.5, 0.5) - x) / 0.95, 0.0, serve_strength * -_server)
	_last_hitter = _server
	_state = State.PLAY
	_already_bounced = false
	_serve_bounced = false
	label_3d.text = ""


func _apply_velocity_to_ball(delta: float) -> void:
	_ball_velocity.y -= _gravity * delta
	_ball_position += _ball_velocity * delta


func _table_bounce() -> int:
	if _ball_velocity.y < 0.0 and _ball_position.y <= _ball_radius and absf(_ball_position.x) <= _table_size_x / 2 and absf(_ball_position.z) <= _table_size_z / 2:
		_ball_position.y = _ball_radius
		_ball_velocity.y = -_ball_velocity.y * rebound_strength
		_ball_velocity.x *= 0.95
		_ball_velocity.z *= 0.95
		
		# return table side
		if _ball_position.z > 0.0:
			return 1
		else:
			return -1
	else:
		return 0


func _play_state(delta: float) -> void:
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


func _update_visuals(delta: float) -> void:
	# paddle positions
	_local_target_position.x = clampf(_local_target_position.x + _mouse_motion.x * mouse_sensitivity, paddle_x_min, paddle_x_max)
	# fix z when serve
	if _state == State.SERVE and _server == 1:
		_local_target_position.z = paddle_z_max
	else:
		_local_target_position.z = clampf(_local_target_position.z + _mouse_motion.y * mouse_sensitivity, paddle_z_min, paddle_z_max)
	# reset mouse motion
	_mouse_motion = Vector2.ZERO
	# responsiveness
	var weight: float = 1.0 - exp(-paddle_responsiveness * delta)
	paddle_local.position = paddle_local.position.lerp(_local_target_position, weight)
	
	# ball position
	ball.position = _ball_position
	
	# camera position
	camera_3d.position.x = lerpf(camera_3d.position.x, _ball_position.x * 0.15, delta * 2.0)
	camera_3d.look_at(Vector3(0, 0.3, 0))

	# camera shake
	camera_3d.h_offset = randf_range(-_camera_shake, _camera_shake)
	camera_3d.v_offset = randf_range(-_camera_shake, _camera_shake)
	_camera_shake = move_toward(_camera_shake, 0.0, delta * 0.2)
