@tool
class_name OpenNvim
extends EditorPlugin


# --------------------------------------------------
# <Defines>
class SettingsEntry:
	var sys_name: String
	var face_name: String
	var type: int
	var default_val: Variant
	var prop_hint: int
	var prop_hint_str: String
	var usage: int

	func _init(
		sysname: String,
		facename: String,
		type_id: int,
		defaultval: Variant,
		prophint: int = PROPERTY_HINT_NONE,
		prophintstring: String = "",
		usage_id: int = PROPERTY_USAGE_DEFAULT,
	) -> void:
		sys_name = PLUGIN_NAME + "/" + sysname
		face_name = facename
		type = type_id
		default_val = defaultval
		prop_hint = prophint
		prop_hint_str = prophintstring
		usage = usage_id

	func add_property_info() -> void:
		var p := ProjectSettings
		if not p.has_setting(sys_name):
			p.set_setting(sys_name, default_val)
			(
				p
				. add_property_info(
					{
						"name": face_name,
						"type": type,
						"hint": prop_hint,
						"hint_string": prop_hint_str,
						"usage": usage,
					}
				)
			)


class SettingName:
	const NEOVIM_EXECUTABLE := &"neovim_executable"
	const WINDOW_SIZE := &"window_size"
	const IP_ADDRESS := &"ip"
	const PORT := &"port"


# --------------------------------------------------
# <Constants>
const NEOVIM_PATH_DEFAULT = "C:/Program Files/neovim/bin/nvim-qt.exe"
const ICON_TEX := preload("res://addons/open_nvim/nvim_logo.png")
const PLUGIN_NAME = "OpenNvim"

# --------------------------------------------------
# <Private Variable>
var _btn: Button
var _process_id: Array[int] = []
var _settings_ent: Dictionary = {
	SettingName.NEOVIM_EXECUTABLE:
	(
		SettingsEntry
		. new(
			SettingName.NEOVIM_EXECUTABLE,
			"Neovim Executable",
			TYPE_STRING,
			NEOVIM_PATH_DEFAULT,
			PROPERTY_HINT_FILE,
			"*.exe",
		)
	),
	SettingName.WINDOW_SIZE:
	SettingsEntry.new(SettingName.WINDOW_SIZE, "Window Size", TYPE_VECTOR2I, Vector2i(2048, 1200)),
	SettingName.IP_ADDRESS:
	SettingsEntry.new(SettingName.IP_ADDRESS, "IP Address", TYPE_STRING, "127.0.0.1"),
	SettingName.PORT: SettingsEntry.new(SettingName.PORT, "Port", TYPE_INT, 6004),
}


# --------------------------------------------------
# <Public Variable>
# --------------------------------------------------
# [Private Method (Callback)]
func _enter_tree() -> void:
	_prepare_button()
	_prepare_preferences()


func _exit_tree() -> void:
	for pid in _process_id:
		if _is_pid_valid(pid):
			OS.execute("taskkill", ["/pid", pid, "/t", "/f"])
	_btn.queue_free()


func _on_button_pressed() -> void:
	var path := _get_script_path_from_sceneroot()
	var target := "."
	if not path.is_empty():
		target = ProjectSettings.globalize_path(path)
	var options := [target] + _make_neovim_args()
	var exec_path: String = _get_setting_value(SettingName.NEOVIM_EXECUTABLE)
	_process_id.append(OS.create_process(exec_path, options))


# --------------------------------------------------
# [Private Method]
func _make_neovim_args() -> Array[String]:
	var size: Vector2i = _get_setting_value(SettingName.WINDOW_SIZE)
	var ip: String = _get_setting_value(SettingName.IP_ADDRESS)
	var port: int = _get_setting_value(SettingName.PORT)
	return [
		"-qwindowgeometry",
		"{}x{}".format([size.x, size.y], "{}"),
		"--",
		"--listen",
		"{}:{}".format([ip, port], "{}"),
	]


func _get_setting_value(name: String) -> Variant:
	return ProjectSettings.get_setting(_settings_ent[name].sys_name)


func _prepare_preferences() -> void:
	for ent: SettingsEntry in _settings_ent.values():
		ent.add_property_info()
	ProjectSettings.save()


func _prepare_button() -> void:
	_btn = Button.new()
	_btn.text = "       Open Nvim"
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var tex_rect := TextureRect.new()
	tex_rect.texture = ICON_TEX
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.custom_minimum_size = Vector2(32, 32)

	_btn.add_child(tex_rect)
	_btn.pressed.connect(_on_button_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, _btn)


func _get_script_path_from_obj(obj: Object) -> String:
	var script: Script = obj.get_script()
	if script == null:
		return ""
	return script.resource_path


func _get_script_path_from_sceneroot() -> String:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return ""
	return _get_script_path_from_obj(scene_root)


# --------------------------------------------------
# [Public Method]
# --------------------------------------------------
# [Static Method]
static func _is_pid_valid(pid: int) -> bool:
	return pid != -1
