class_name Menu
extends CanvasLayer

signal play_local
#signal ai_difficulty_changed(difficulty_level: int)
#signal mouse_sensitivity_changed(multiplier: float)

const SETTINGS_FILE_PATH := "user://settings.cfg"

var _settings := {
	"mouse_sensitivity": 1.0,
	"fullscreen": false,
	"ai_difficulty": 1,
}
var _is_menu_opened: bool = false

@onready var main_menu_container: VBoxContainer = %MainMenuContainer
@onready var settings_container: VBoxContainer = %SettingsContainer

func _ready() -> void:
	_load_settings()

	#mouse_sensitivity_slider.set_value(float(settings["mouse_sensitivity"]))
	#difficulty_option_button.select(int(settings["ai_difficulty"]))
	#fullscreen_check_box.set_pressed(bool(settings["fullscreen"]))

	#await game_scene.ready
	_apply_all_settings()
	
	_open_menu()


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
	visible = false
	get_tree().paused = false
	_is_menu_opened = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
	main_menu_container.visible = false
	settings_container.visible = true


func _close_settings() -> void:
	_save_settings()
	main_menu_container.visible = true
	settings_container.visible = false




#func _on_volume_changed(new_volume: float) -> void:
#	settings["master_volume"] = new_volume
#	_apply_all_settings()


#func _on_sensitivity_changed(new_multiplier: float) -> void:
#	settings["mouse_sensitivity"] = new_multiplier
#	mouse_sensitivity_changed.emit(new_multiplier)


#func _on_difficulty_selected(difficulty_index: int) -> void:
#	settings["ai_difficulty"] = difficulty_index
#	ai_difficulty_changed.emit(difficulty_index)





func _apply_all_settings() -> void:
	#var is_currently_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	#if bool(settings["fullscreen"]) != is_currently_fullscreen:
	#	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	#	DisplayServer.window_set_mode(target_mode)

	pass



func _load_settings() -> void:
	#var config_file := ConfigFile.new()
	#if config_file.load(SETTINGS_FILE_PATH) != OK:
	#	return
	#for setting_name in settings.keys():
	#	settings[setting_name] = config_file.get_value("settings", setting_name, settings[setting_name])
	pass

func _save_settings() -> void:
	#var config_file := ConfigFile.new()
	#for setting_name in settings.keys():
	#	config_file.set_value("settings", setting_name, settings[setting_name])
	#config_file.save(SETTINGS_FILE_PATH)
	pass


func _on_play_local_button_pressed() -> void:
	play_local.emit()
	_close_menu()


func _on_settings_button_pressed() -> void:
	_open_settings()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_mouse_sensitivity_slider_value_changed(value: float) -> void:
	pass # Replace with function body.


func _on_back_button_pressed() -> void:
	_close_settings()
