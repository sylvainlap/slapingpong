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
# Camera shake.
@export var camera_shake_intensity: float = 0.03

var _state: State = State.SERVE
# 0 = local player, 1 = other player
var _server: int = 0
var _last_hitter: int = 0
var _player_x: float = 0.0
var _player_z: float = 0.0
var _ball_position: Vector3 = Vector3.ZERO
var _camera_shake: float = 0.0


@onready var camera_3d: Camera3D = $Camera3D
@onready var label_3d: Label3D = $Label3D
@onready var ball: Node3D = $Ball

func _ready() -> void:
	_reset_serve()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print(event)
		# just for tests:
		_camera_shake = camera_shake_intensity
	elif event is InputEventMouseMotion:
		print(event)


func _physics_process(delta: float) -> void:
	_update_player(delta)
	_update_visuals(delta)


func _reset_serve() -> void:
	_state = State.SERVE
	_last_hitter = 0
	if _server == 0:
		label_3d.text = "Clic pour servir\nSouris pour bouger\nSmash : clic gauche\nAmorti : clic droit"
	else:
		label_3d.text = "L'autre sert..."


func _update_player(delta: float) -> void:
	var screen_size_x := get_viewport().get_visible_rect().size.x
	var screen_size_y := get_viewport().get_visible_rect().size.y
	
	var x: float = clampf((get_viewport().get_mouse_position().x / screen_size_x), 0.0, 1.0)
	_player_x = move_toward(_player_x, lerpf(paddle_x_min, paddle_x_max, x), delta * 6.0)
	
	# fix z when serve
	#if state == State.SERVE and server == 1:
		#nz = move_toward(player_z, PZ, 6.0 * dt)
	
	var z: float = clampf((get_viewport().get_mouse_position().y / screen_size_y), 0.0, 1.0)
	_player_z = move_toward(_player_z, lerpf(paddle_z_min, paddle_z_max, z), delta * 6.0)
	
	print("(x,z) : (" + str(x) + "," + str(z) + ")")
	print("(player) : (" + str(_player_x) + "," + str(_player_z) + ")")


func _update_visuals(delta: float) -> void:
	# just for tests:
	_ball_position = Vector3(_player_x, paddle_y, _player_z)
	
	# TODO: la ball doit être spawn via le multiplayer process
	ball.position = _ball_position
	# camera position
	camera_3d.position.x = lerpf(camera_3d.position.x, _ball_position.x * 0.15, delta * 2.0)
	camera_3d.look_at(Vector3(0, 0.3, 0))
	# camera shake
	camera_3d.h_offset = randf_range(-_camera_shake, _camera_shake)
	camera_3d.v_offset = randf_range(-_camera_shake, _camera_shake)
	_camera_shake = move_toward(_camera_shake, 0.0, delta * 0.2)
	
	
