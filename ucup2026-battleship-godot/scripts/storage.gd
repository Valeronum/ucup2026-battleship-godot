extends Node

func _path_for_key(key: String) -> String:
	return "user://ucup2026_%s.json" % key

func load_json(key: String, default_value):
	var path := _path_for_key(key)
	if not FileAccess.file_exists(path):
		print("Storage.load_json: %s not found, returning default" % key)
		return default_value
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Storage.load_json: failed to open %s" % path)
		return default_value
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		push_error("Storage.load_json: failed to parse %s" % key)
		return default_value
	print("Storage.load_json: loaded %s (%d bytes)" % [key, txt.length()])
	return parsed

func save_json(key: String, value) -> void:
	var path := _path_for_key(key)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Storage.save_json: failed to open %s" % path)
		return
	var txt := JSON.stringify(value)
	f.store_string(txt)
	f.close()
	print("Storage.save_json: saved %s (%d bytes)" % [key, txt.length()])

func clear(key: String) -> void:
	var path := _path_for_key(key)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
