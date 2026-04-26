extends Node

func _path_for_key(key: String) -> String:
	return "user://ucup2026_%s.json" % key

func load_json(key: String, default_value):
	var path := _path_for_key(key)
	if not FileAccess.file_exists(path):
		return default_value
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return default_value
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		return default_value
	return parsed

func save_json(key: String, value) -> void:
	var path := _path_for_key(key)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(value))
	f.close()

func clear(key: String) -> void:
	var path := _path_for_key(key)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
