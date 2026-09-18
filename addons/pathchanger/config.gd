extends RefCounted

const CONFIG_PATH := "user://pathchanger_config.cfg"
const SECTION := "prompts"

var _config := ConfigFile.new()

func _init() -> void:
	_config.load(CONFIG_PATH)

## returns the remembered choice for a prompt key, or empty string if nothing saved
func get_remembered(key: String) -> String:
	return _config.get_value(SECTION, key, "")

## saves a choice so the same prompt auto answers next time instead of showing
func remember(key: String, choice: String) -> void:
	_config.set_value(SECTION, key, choice)
	_config.save(CONFIG_PATH)
