class_name Hud
extends CanvasLayer

@export var main: Main
@export var menu: Menu

var _tween: Tween

@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_server_panel: Panel = %PlayerServerPanel
@onready var player_score_label: Label = %PlayerScoreLabel
@onready var ai_server_panel: Panel = %AIServerPanel
@onready var ai_score_label: Label = %AIScoreLabel
@onready var flash_label: Label = %FlashLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	menu.player_name_updated.connect(_on_player_name_updated)
	main.player_score_updated.connect(_on_player_score_updated)
	main.ai_score_updated.connect(_on_ai_score_updated)
	main.server_updated.connect(_on_server_updated)
	main.flash_message_updated.connect(_on_flash_message_updated)
	main.status_message_updated.connect(_on_status_message_updated)
	print("hud _ready done.")


func _on_player_name_updated(player_name: String) -> void:
	player_name_label.text = player_name


func _on_player_score_updated(score: int) -> void:
	player_score_label.text = str(score)


func _on_ai_score_updated(score: int) -> void:
	ai_score_label.text = str(score)


func _on_server_updated(server: int) -> void:
	# TODO make PLAYER & AI global consts ?
	if server == 1:
		player_server_panel.modulate.a = 1.0
		ai_server_panel.modulate.a = 0.0
	elif server == -1:
		player_server_panel.modulate.a = 0.0
		ai_server_panel.modulate.a = 1.0


func _on_flash_message_updated(message: String):
	flash_label.text = message
	flash_label.modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(flash_label, "modulate:a", 0.0, 0.5)


func _on_status_message_updated(message: String):
	status_label.text = message
