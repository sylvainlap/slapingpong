# TODO: use LimboAI
# TODO: ce serait pas plus intelligible de mettre du code dans des scripts de scenes ?
# TODO: la rotation de la raquette au shot n'est pas bonne
# TODO: supprimer les _in

class_name Main
extends Node3D

signal player_score_updated(score: int)
signal ai_score_updated(score: int)
signal server_updated(server: int)
signal status_message_updated(message: String)
signal flash_message_updated(message: String)

enum State { SERVE, PLAY, POINT, GAMEOVER }
enum Shot { NORMAL, SMASH, DROP }

const TABLE_HALF_WIDTH: float = 1.5 / 2.0
const TABLE_HALF_LENGTH: float = 2.8 / 2.0
const NET_HEIGHT: float = 0.2
const BALL_RADIUS: float = 0.03
const PLAYER_SIDE: int = 1
const AI_SIDE: int = -1
const PADDLE_HIT_HALF_WIDTH: float = 0.24
const PADDLE_HIT_MIN_HEIGHT: float = -0.1
const PADDLE_HIT_MAX_HEIGHT: float = 0.55

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
@export var smash_low_ball_miss_probability: float = 0.4
@export var smash_miss_probability: float = 0.06
@export var drop_back_penalty: float = 0.2
@export var drop_streak_penalty: float = 0.12
@export_category("AI")
@export var ai_serve_timer: float = 1.2
@export var ai_speed: float = 1.7
@export var ai_forward_speed: float = 1.7
@export var ai_paddle_z_min: float = 0.5
@export var ai_miss_probability: float = 0.12
@export_category("Mouse and Camera")
@export var mouse_sensitivity: float = 0.002
@export var mouse_responsiveness: float = 30.0
@export var camera_shake_intensity: float = 0.03

var _state: State = State.SERVE
var _server: int = PLAYER_SIDE:
	set(value):
		_server = value
		server_updated.emit(value)
var _timer: float = 0.0
var _status_message: String = "":
	set(value):
		_status_message = value
		status_message_updated.emit(value)
var _flash_message: String = "":
	set(value):
		_flash_message = value
		flash_message_updated.emit(value)

var _ball_position: Vector3 = Vector3.ZERO
var _previous_ball_position: Vector3 = Vector3.ZERO
var _ball_velocity: Vector3 = Vector3.ZERO
var _last_hitter: int = 0
var _has_served_bounced: bool = false
var _has_bounced: bool = false
var _hit_count: int = 0
var _is_drop_in_flight: bool = false
var _consecutive_player_drops: int = 0

var _player_paddle_target_x: float = 0.0
var _player_paddle_x: float = 0.0
var _player_paddle_velocity_x: float = 0.0
var _player_paddle_target_z: float = paddle_z_max
var _player_paddle_z: float = paddle_z_max
var _previous_player_paddle_z: float = 0.0
var _player_paddle_velocity_z: float = 0.0
var _player_score: int = 0:
	set(value):
		_player_score = value
		player_score_updated.emit(value)

var _ai_paddle_target_x: float = 0.0
var _ai_paddle_x: float = 0.0
var _ai_paddle_velocity_x: float = 0.0
var _ai_paddle_target_z: float = -paddle_z_max
var _ai_paddle_z: float = 0.0
var _previous_ai_paddle_z: float = 0.0
var _ai_paddle_velocity_z: float = 0.0
var _ai_positioning_error: float = 0.0
var _ai_score: int = 0:
	set(value):
		_ai_score = value
		ai_score_updated.emit(value)

var _camera_shake: float = 0.0
var _mouse_motion: Vector2 = Vector2.ZERO
var _base_mouse_sensitivity: float = 0.002

@onready var camera_3d: Camera3D = $Camera3D
@onready var paddle_player: Node3D = $PaddlePlayer
@onready var paddle_ai: Node3D = $PaddleAI
@onready var ball: Node3D = $Ball
@onready var hit_player: AudioStreamPlayer3D = $Sfx/HitPlayer
@onready var bounce_player: AudioStreamPlayer3D = $Sfx/BouncePlayer
@onready var score_player: AudioStreamPlayer3D = $Sfx/ScorePlayer
@onready var net_player: AudioStreamPlayer3D = $Sfx/NetPlayer
@onready var menu: Menu = $Menu


func _ready() -> void:
	menu.play_local.connect(_on_play_local)
	#game_menu.ai_difficulty_changed.connect(set_difficulty)
	#game_menu.mouse_sensitivity_changed.connect(_on_mouse_sensitivity_multiplier_changed)
	# fullscreen
	#var is_currently_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	#if bool(settings["fullscreen"]) != is_currently_fullscreen:
	#	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	#	DisplayServer.window_set_mode(target_mode)
	_base_mouse_sensitivity = mouse_sensitivity
	print("main _ready done.")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_motion += event.screen_relative


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
		State.GAMEOVER:
			_game_over_state(delta)
			
	_update_visuals(delta)


func set_mouse_sensitivity(mouse_sensitivity_in: float) -> void:
	mouse_sensitivity = mouse_sensitivity_in


func set_difficulty(difficulty_in: int) -> void:
	match difficulty_in:
		0:
			ai_serve_timer = 1.8
			ai_speed = 1.3
			ai_forward_speed = 1.2
			ai_miss_probability = 0.22
		1:
			ai_serve_timer = 1.2
			ai_speed = 1.7
			ai_forward_speed = 1.7
			ai_miss_probability = 0.12
		2:
			ai_serve_timer = 0.8
			ai_speed = 2.2
			ai_forward_speed = 2.2
			ai_miss_probability = 0.05


func _start_new_game() -> void:
	_player_score = 0
	_ai_score = 0
	_server = PLAYER_SIDE
	_player_paddle_x = 0.0
	_player_paddle_z = paddle_z_max
	_ai_paddle_x = 0.0
	_ai_paddle_z = -paddle_z_max
	_camera_shake = 0.0
	_reset_serve()


func _reset_serve() -> void:
	_state = State.SERVE
	_last_hitter = 0
	_has_served_bounced = false
	_has_bounced = false
	_hit_count = 0
	_is_drop_in_flight = false
	_consecutive_player_drops = 0
	_ball_velocity = Vector3.ZERO
	
	if _server == PLAYER_SIDE:
		_status_message = "Clic pour servir\nSouris pour bouger\nSmash : clic gauche\nAmorti : clic droit"
	else:
		_status_message = "L'autre sert..."
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


func _launch_serve(x_in: float) -> void:
	_status_message = ""
	_ball_velocity = Vector3((randf_range(-0.5, 0.5) - x_in) / 0.95, 0.0, serve_speed * -_server)
	_last_hitter = _server
	_state = State.PLAY
	_animate_paddle_swing(paddle_player if _server == PLAYER_SIDE else paddle_ai, 40.0)
	_play_hit_sound(Shot.NORMAL)


func _apply_ball_physics(delta: float) -> void:
	_previous_ball_position = _ball_position
	_ball_velocity.y += gravity * delta
	_ball_position += _ball_velocity * delta


func _is_ball_landing_on_table(previous_position: Vector3, current_position: Vector3, velocity: Vector3) -> bool:
	return velocity.y < 0.0 \
		and current_position.y <= BALL_RADIUS \
		and previous_position.y >= BALL_RADIUS - 0.002 \
		and absf(current_position.x) <= TABLE_HALF_WIDTH \
		and absf(current_position.z) <= TABLE_HALF_LENGTH


func _is_ball_out() -> bool:
	return absf(_ball_position.x) > out_of_play_x or _ball_position.y < out_of_play_y or absf(_ball_position.z) > out_of_play_z


func _table_bounce() -> int:
	if _is_ball_landing_on_table(_previous_ball_position, _ball_position, _ball_velocity):
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
	
	# net
	if _previous_ball_position.z * _ball_position.z < 0.0:
		# TODO: a simplifier ? z near approx 0.0 ?
		var crossing_fraction: float = _previous_ball_position.z / (_previous_ball_position.z - _ball_position.z)
		var height_at_net: float = lerpf(_previous_ball_position.y, _ball_position.y, crossing_fraction)
		var x_at_net: float = lerpf(_previous_ball_position.x, _ball_position.x, crossing_fraction)
		if height_at_net < NET_HEIGHT + BALL_RADIUS * 0.5 and absf(x_at_net) < TABLE_HALF_WIDTH + 0.15:
			_play_net_sound()
			_end_point(-_last_hitter, "Filet !")
			return
		
	# bounced
	var bounced: int = _table_bounce()
	if bounced != 0:
		_play_bounce_sound()
		if bounced == _last_hitter:
			if not _has_served_bounced:
				_has_served_bounced = true
			else:
				_end_point(-_last_hitter, "Faute !")
		elif _has_bounced:
			_end_point(_last_hitter, "Faute !")
		else:
			_has_bounced = true
			# TODO: pas ouf de mettre ce code ici
			if _is_drop_in_flight:
				_ball_velocity.z *= 0.45
				_ball_velocity.y *= 0.85
				_is_drop_in_flight = false
	
	# shot
	if _ball_velocity.z > 0.0 and _previous_ball_position.z < _previous_player_paddle_z and _ball_position.z >= _player_paddle_z:
		_try_hit_ball(PLAYER_SIDE, _player_paddle_x)
	elif _ball_velocity.z < 0.0 and _previous_ball_position.z > _previous_ai_paddle_z and _ball_position.z <= _ai_paddle_z:
		_try_hit_ball(AI_SIDE, _ai_paddle_x)
		
	# out
	if _is_ball_out():
		if _has_bounced:
			_end_point(_last_hitter, "Dehors !")
		else:
			_end_point(-_last_hitter, "Dehors !")


func _choose_shot(side_in: int) -> Shot:
	if side_in == PLAYER_SIDE:
		if _is_smash_requested():
			return Shot.SMASH
		if _is_drop_requested():
			return Shot.DROP
	elif side_in == AI_SIDE:
		var dice: float = randf()
		if _ball_position.y > 0.28 and dice < 0.2:
			return Shot.SMASH
		if _hit_count >= 1 and dice > 0.88:
			return Shot.DROP
	
	return Shot.NORMAL


func _end_point(winner: int, reason: String = "") -> void:
	if _state != State.PLAY:
		return
	
	if winner == PLAYER_SIDE:
		_player_score += 1
	elif winner == AI_SIDE:
		_ai_score += 1

	_state = State.POINT
	_timer = 2.0
	_play_score_sound()
	
	var result_text: String = "Point pour toi !" if winner == PLAYER_SIDE else "Point pour l'IA"
	_status_message = (reason + "\n" if reason != "" else "") + result_text
	
	var has_reached_target: bool = _player_score >= points_to_win or _ai_score >= points_to_win
	if has_reached_target and absi(_player_score - _ai_score) >= 2:
		_state = State.GAMEOVER
		_status_message = ("Victoire !" if _player_score > _ai_score else "Défaite...") + "\nClic pour rejouer"


func _let_ball_fall(delta: float) -> void:
	_apply_ball_physics(delta)
	_table_bounce()


func _point_state(delta: float) -> void:
	_let_ball_fall(delta)
	_timer -= delta
	if _timer <= 0.0:
		_update_server()
		_reset_serve()


func _game_over_state(delta: float) -> void:
	_let_ball_fall(delta)
	if _is_click_just_pressed():
		_start_new_game()


func _update_server() -> void:
	var total: int = _player_score + _ai_score
	var is_deuce_phase: bool = _player_score >= 10 and _ai_score >= 10
	if is_deuce_phase or total % 2 == 0:
		_server = -_server


func _update_player_paddle(delta: float) -> void:
	_previous_player_paddle_z = _player_paddle_z

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
	_previous_ai_paddle_z = _ai_paddle_z
	
	var target_x: float = 0.0
	var target_z: float = -paddle_z_max
	
	if _state == State.PLAY and _ball_velocity.z < 0.0 and _last_hitter == PLAYER_SIDE:
		# elle avance seulement pour intercepter la balle
		var interception: Vector2 = _predict_ai_interception()
		target_x = interception.x + _ai_positioning_error
		target_z = interception.y
	elif _state == State.SERVE and _server == AI_SIDE:
		target_x = _ball_position.x     # l'IA sert depuis le fond, derrière la balle
	
	_ai_paddle_target_x = clampf(target_x, paddle_x_min, paddle_x_max)
	_ai_paddle_target_z = clampf(target_z, -paddle_z_max, -ai_paddle_z_min)
	
	var nx := move_toward(_ai_paddle_x, _ai_paddle_target_x, delta * ai_speed)
	var nz := move_toward(_ai_paddle_z, _ai_paddle_target_z, delta * ai_forward_speed)
	
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


func _animate_paddle_swing(paddle: Node3D, swing_degrees: float) -> void:
	paddle.scale = Vector3.ONE * 1.2
	paddle.rotation.x = deg_to_rad(-swing_degrees)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(paddle, "scale", Vector3.ONE, 0.15)
	tween.tween_property(paddle, "rotation:x", 0.0, 0.2)


func _play_hit_sound(shot_in: Shot) -> void:
	match shot_in:
		Shot.NORMAL:
			hit_player.pitch_scale = 1.0
			hit_player.volume_db = 0.0
		Shot.SMASH:
			hit_player.pitch_scale = 0.8
			hit_player.volume_db = 4.0
		Shot.DROP:
			hit_player.pitch_scale = 1.3
			hit_player.volume_db = -4.0
	hit_player.play()


func _play_bounce_sound() -> void:
	bounce_player.play()


func _play_net_sound() -> void:
	net_player.play()


func _play_score_sound() -> void:
	score_player.play()


func _on_play_local() -> void:
	_start_new_game()


func _on_mouse_sensitivity_multiplier_changed(multiplier: float) -> void:
	set_mouse_sensitivity(_base_mouse_sensitivity * multiplier)
	

func _try_hit_ball(side_in: int, x_in: float) -> void:
	if not _has_bounced or _last_hitter == side_in:
		return
	
	var is_in_reach: bool = absf(_ball_position.x - x_in) <= PADDLE_HIT_HALF_WIDTH and _ball_position.y >= PADDLE_HIT_MIN_HEIGHT and _ball_position.y <= PADDLE_HIT_MAX_HEIGHT
	
	if not is_in_reach:
		return
	
	var shot: Shot = _choose_shot(side_in)
	_hit_count += 1
	_last_hitter = side_in
	_has_bounced = false
	_is_drop_in_flight = shot == Shot.DROP
	if side_in == PLAYER_SIDE and shot != Shot.DROP:
		_consecutive_player_drops = 0
	
	var paddle_velocity_x: float = _player_paddle_velocity_x if side_in == PLAYER_SIDE else _ai_paddle_velocity_x
	var hit_offset_ratio: float = (_ball_position.x - x_in) / PADDLE_HIT_HALF_WIDTH
	var hit_height: float = maxf(_ball_position.y, 0.08)
	var ball_speed: float = 0.0
	var target_x: float = 0.0
	var target_depth: float = 0.0               # profondeur visée de l'autre côté du filet (valeur positive)
	var net_clearance_margin: float = 0.1
	
	match shot:
		Shot.DROP:
			ball_speed = drop_speed
			target_depth = randf_range(0.22, 0.42)
			if side_in == PLAYER_SIDE:
				# depuis le fond ou en série, l'amorti est plus long (donc plus facile à rattraper)
				target_depth += (_player_paddle_z - paddle_z_min) * drop_back_penalty + _consecutive_player_drops * drop_streak_penalty
				_consecutive_player_drops += 1
			target_x = clampf(_ball_position.x + hit_offset_ratio * 0.3, -0.55, 0.55)
		Shot.SMASH:
			ball_speed = smash_speed + minf(_hit_count * 0.08, 0.8)
			target_depth = randf_range(0.9, 1.22)
			target_x = clampf(_ball_position.x + hit_offset_ratio * 0.7 + paddle_velocity_x * 0.25, -0.7, 0.7)
			net_clearance_margin = 0.04
			# risque : un smash sur une balle basse finit souvent dans le filet ou trop long
			var is_smash_missed: bool = (hit_height < 0.18 and randf() < smash_low_ball_miss_probability) or randf() < smash_miss_probability
			if is_smash_missed:
				target_depth = TABLE_HALF_LENGTH + 0.4
		_:
			ball_speed = shot_speed + minf(_hit_count * 0.12, 2.2)
			target_depth = randf_range(0.45, 1.15)
			if side_in == PLAYER_SIDE:
				target_x = clampf(x_in + hit_offset_ratio * 0.5 + paddle_velocity_x * 0.15, -0.65, 0.65)
			else:
				target_x = randf_range(-0.6, 0.6)
				if randf() < ai_miss_probability:
					target_x = signf(target_x) * randf_range(0.85, 1.1)   # coup raté : dehors
	
	if side_in == PLAYER_SIDE:
		_ai_positioning_error = randf_range(-0.12, 0.12)
	
	# la balle est frappée à la hauteur et à la profondeur de la raquette
	var paddle_z: float = _player_paddle_z if side_in == PLAYER_SIDE else _ai_paddle_z
	_ball_position = Vector3(_ball_position.x, hit_height, paddle_z)
	_aim_ball_at_target(side_in, target_x, target_depth, ball_speed, net_clearance_margin)
	
	var swing_degrees: float = 40.0
	if shot == Shot.DROP:
		swing_degrees = 15.0
	elif shot == Shot.SMASH:
		swing_degrees = 85.0
		_camera_shake = camera_shake_intensity
	_animate_paddle_swing(paddle_player if side_in == PLAYER_SIDE else paddle_ai, swing_degrees)
	_play_hit_sound(shot)
	
	if shot == Shot.SMASH:
		_flash_message = "Smash !"
	elif shot == Shot.DROP:
		_flash_message = "Amorti..."


## Calcule la vitesse de la balle pour qu'elle rebondisse en (target_x, profondeur voulue de l'autre côté)
## en passant au-dessus du filet. Si le filet n'est pas franchi, la cible est reculée par pas de 10 cm.
func _aim_ball_at_target(hitter_side: int, target_x: float, target_depth_from_net: float, ball_speed: float, net_clearance_margin: float) -> void:
	var start_z := _ball_position.z
	var start_height := _ball_position.y
	var current_depth := target_depth_from_net
	var vertical_speed := 0.0
	var flight_time := 1.0
	for attempt in 8:
		flight_time = absf(-hitter_side * current_depth - start_z) / ball_speed
		vertical_speed = (BALL_RADIUS - start_height - 0.5 * gravity * flight_time * flight_time) / flight_time
		var flight_time_to_net := absf(start_z) / ball_speed
		var height_at_net := start_height + vertical_speed * flight_time_to_net + 0.5 * gravity * flight_time_to_net * flight_time_to_net
		if height_at_net > NET_HEIGHT + net_clearance_margin:
			break
		current_depth = minf(current_depth + 0.1, maxf(current_depth, TABLE_HALF_LENGTH - 0.1))
	_ball_velocity = Vector3((target_x - _ball_position.x) / flight_time, vertical_speed, -hitter_side * ball_speed)


func _predict_ai_interception() -> Vector2:
	var predicted_position: Vector3 = _ball_position
	var predicted_velocity: Vector3 = _ball_velocity
	var has_bounced: bool = _has_bounced
	var step: float = 1.0 / 60.0
	var best_interception: Vector2 = Vector2(predicted_position.x, -paddle_z_max)
	
	for i in 180:
		var previous_predicted_position: Vector3 = predicted_position
		predicted_velocity.y += gravity * step
		predicted_position += predicted_velocity * step
		
		if _is_ball_landing_on_table(previous_predicted_position, predicted_position, predicted_velocity):
			predicted_position.y = BALL_RADIUS
			predicted_velocity.y = -predicted_velocity.y * bounce_restitution
			predicted_velocity.x *= bounce_damping
			predicted_velocity.z *= bounce_damping
			if predicted_position.z < 0.0:
				if has_bounced:
					break               # second rebond : trop tard
				has_bounced = true
				if _is_drop_in_flight:
					predicted_velocity.z *= 0.45
					predicted_velocity.y *= 0.85
		
		var is_reachable: bool = has_bounced and predicted_position.y >= 0.0 and predicted_position.y <= 0.5 and predicted_position.z < -0.25
		if is_reachable:
			best_interception = Vector2(predicted_position.x, clampf(predicted_position.z, -paddle_z_max, -ai_paddle_z_min))
			if predicted_position.z <= -1.3:
				return best_interception
		
		if predicted_position.z < -2.4 or predicted_position.y < -0.5:
			break
	return best_interception
