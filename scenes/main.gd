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
# 0 = local player, 1 = other player
var _server: int = 0
var _last_hitter: int = 0
var _player_x: float = 0.0
var _player_z: float = 0.0
var _ball_position: Vector3 = Vector3.ZERO
var _ball_velocity: Vector3 = Vector3.ZERO
var _camera_shake: float = 0.0
var _mouse_button_left_pressed: bool = false
var _mouse_button_right_pressed: bool = false
var _serve_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _ball_radius: float = 0.03
var _table_size_x: float = 1.5
var _table_size_z: float = 2.8

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
			
	_update_visuals(delta)


func _reset_serve() -> void:
	_state = State.SERVE
	_last_hitter = 0
	if _server == 0:
		label_3d.text = "Clic pour servir\nSouris pour bouger\nSmash : clic gauche\nAmorti : clic droit"
	else:
		label_3d.text = "L'autre sert..."
	_serve_timer = 1.0


func _update_player(delta: float) -> void:
	var screen_size_x := get_viewport().get_visible_rect().size.x
	var screen_size_y := get_viewport().get_visible_rect().size.y
	
	var x: float = clampf((get_viewport().get_mouse_position().x / screen_size_x), 0.0, 1.0)
	_player_x = move_toward(_player_x, lerpf(paddle_x_min, paddle_x_max, x), delta * 6.0)
	
	# fix z when serve
	if _state == State.SERVE and _server == 0:
		_player_z = move_toward(_player_z, paddle_z_max, delta * 6.0)
	else:
		var z: float = clampf((get_viewport().get_mouse_position().y / screen_size_y), 0.0, 1.0)
		_player_z = move_toward(_player_z, lerpf(paddle_z_min, paddle_z_max, z), delta * 6.0)
		print("(x,z) : (" + str(x) + "," + str(z) + ")")

	print("(player) : (" + str(_player_x) + "," + str(_player_z) + ")")


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
	if _server == 0:
		_ball_position = Vector3(_player_x, 0.45, 1.5)
		if _mouse_button_left_pressed:
			_launch_serve(_player_x)
	else:
		_ball_position = Vector3(0.0, 0.45, -1.5)
		_serve_timer -= delta
		if _serve_timer <= 0.0:
			_launch_serve(0.0)


func _launch_serve(x: float) -> void:
	_ball_velocity = Vector3((randf_range(-0.5, 0.5) - x) / 0.95, 0.0, -2.9)
	_last_hitter = _server
	_state = State.PLAY
	#bounced_opp = false
	#serve_own_bounce_ok = true
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
		return 1 if _ball_position.z > 0.0 else -1
	return 0


func _play(delta: float) -> void:
	_apply_velocity_to_ball(delta)
	
	# bounce
	_table_bounce()
