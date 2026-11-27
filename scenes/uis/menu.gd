class_name Menu
extends CanvasLayer

signal play_local
signal player_name_updated(name: String)
signal mouse_sensitivity_updated(multiplier: float)
signal ai_difficulty_updated(difficulty: int)
signal fullscreen_updated(fullscreen: bool)

const SETTINGS_FILE_PATH := "user://slapingpong_settings.cfg"

var _is_menu_opened: bool = false

@onready var main_menu_container: VBoxContainer = %MainMenuContainer
@onready var settings_container: VBoxContainer = %SettingsContainer
@onready var player_name_line_edit: LineEdit = %PlayerNameLineEdit
@onready var mouse_sensitivity_slider: HSlider = %MouseSensitivitySlider
@onready var difficulty_option_button: OptionButton = %DifficultyOptionButton
@onready var fullscreen_check_button: CheckButton = %FullscreenCheckButton

func _ready() -> void:
	_load_settings()
	_apply_settings()
	_open_menu()
	print("menu _ready done.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _is_menu_opened:
			_close_menu()
		else:
			_open_menu()
		return


func _open_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	get_tree().paused = true
	main_menu_container.visible = true
	settings_container.visible = false
	_is_menu_opened = true


func _close_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	visible = false
	get_tree().paused = false
	_is_menu_opened = false


func _open_settings() -> void:
	main_menu_container.visible = false
	settings_container.visible = true


func _close_settings() -> void:
	_save_settings()
	main_menu_container.visible = true
	settings_container.visible = false


func _apply_settings() -> void:
	player_name_updated.emit(player_name_line_edit.text)
	mouse_sensitivity_updated.emit(mouse_sensitivity_slider.value)
	ai_difficulty_updated.emit(difficulty_option_button.selected)
	fullscreen_updated.emit(fullscreen_check_button.button_pressed)


func _load_settings() -> void:
	var config_file := ConfigFile.new()
	if config_file.load(SETTINGS_FILE_PATH) != OK:
		return
	
	player_name_line_edit.text = config_file.get_value("settings", "player_name")
	mouse_sensitivity_slider.value = config_file.get_value("settings", "mouse_sensitivity")
	difficulty_option_button.selected = config_file.get_value("settings", "ai_difficulty")
	fullscreen_check_button.button_pressed = config_file.get_value("settings", "fullscreen")


func _save_settings() -> void:
	var config_file := ConfigFile.new()
	config_file.set_value("settings", "player_name", player_name_line_edit.text)
	config_file.set_value("settings", "mouse_sensitivity", mouse_sensitivity_slider.value)
	config_file.set_value("settings", "ai_difficulty", difficulty_option_button.selected)
	config_file.set_value("settings", "fullscreen", fullscreen_check_button.button_pressed)
	config_file.save(SETTINGS_FILE_PATH)


func _on_play_local_button_pressed() -> void:
	play_local.emit()
	_close_menu()


func _on_settings_button_pressed() -> void:
	_open_settings()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_apply_button_pressed() -> void:
	_apply_settings()
	_save_settings()


func _on_back_button_pressed() -> void:
	_close_settings()
