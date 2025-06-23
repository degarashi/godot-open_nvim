@tool
extends EditorPlugin

const NEOVIM_PATH = "C:/Program Files/neovim/bin/nvim-qt.exe"
const NEOVIM_OPTIONS = [".", "-qwindowgeometry", "2048x1200", "--", "--listen", "127.0.0.1:6004"]

const ICON_TEX := preload("res://addons/open_nvim/nvim_logo.png")
var btn: Button
var process_id: Array[int] = []


static func _is_pid_valid(pid: int) -> bool:
	return pid != -1


func _enter_tree() -> void:
	btn = Button.new()
	btn.text = "       Open Nvim"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var tex_rect := TextureRect.new()
	tex_rect.texture = ICON_TEX
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.custom_minimum_size = Vector2(32, 32)

	btn.add_child(tex_rect)
	btn.pressed.connect(_on_button_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, btn)


func _on_button_pressed() -> void:
	process_id.append(OS.create_process(NEOVIM_PATH, NEOVIM_OPTIONS))


func _exit_tree() -> void:
	for pid in process_id:
		if _is_pid_valid(pid):
			OS.kill(pid)
	btn.queue_free()
