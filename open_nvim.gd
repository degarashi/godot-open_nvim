@tool
class_name OpenNvim
extends EditorPlugin

# --------------------------------------------------
# <Constants>
# プラグイン名
const PLUGIN_NAME = "OpenNvim"
# プラグインのアイコンテクスチャ
const ICON_TEX := preload("res://addons/open_nvim/images/nvim_logo.png")
# ショートカットアクション名
const OPEN_NVIM_ACTION = "open_nvim"
# デフォルトのNeovim実行ファイルパス (Windowsを想定)
const NEOVIM_PATH_DEFAULT = "nvim-qt.exe"

# --------------------------------------------------
# <Helper Classes>


# エディタ設定キーの結合ヘルパー
class PSKey:
	const SEP := "/"

	static func join(parts: Array) -> String:
		# すべてを文字列化して結合（StringName なども安全に扱う）
		var str_parts: Array[String] = []
		for p in parts:
			str_parts.append(str(p))
		return SEP.join(str_parts)


# エディタ設定のキー名を定義する定数クラス
class SettingName:
	const NEOVIM_EXECUTABLE := &"neovim_executable"  # Neovim実行ファイルのパス
	const WINDOW_SIZE := &"window_size"  # Neovimウィンドウのサイズ
	const IP_ADDRESS := &"ip"  # 接続先IPアドレス
	const PORT := &"port"  # 接続先ポート番号


# 設定項目を構造化するためのヘルパークラス
class SettingsEntry:
	var sys_name: String  # エディタ設定での実際のキー名 (例: "OpenNvim/neovim_executable")
	var face_name: String  # 表示用の説明（内部的には sys_name を使う）
	var type: int  # データ型 (TYPE_STRING, TYPE_INT, TYPE_VECTOR2I など)
	var default_val: Variant  # デフォルト値
	var prop_hint: int  # プロパティヒント (PROPERTY_HINT_FILE, PROPERTY_HINT_DIR など)
	var prop_hint_str: String  # ヒント文字列 (例: "*.exe")
	var usage: int  # プロパティの使用方法 (PROPERTY_USAGE_DEFAULT など)

	func _init(
		sysname: String,
		facename: String,
		type_id: int,
		defaultval: Variant,
		prophint: int = PROPERTY_HINT_NONE,
		prophintstring: String = "",
		usage_id: int = PROPERTY_USAGE_DEFAULT,
	) -> void:
		# sys_name をキー結合ヘルパーで構築し、キー構造の変更に強くする
		sys_name = PSKey.join([PLUGIN_NAME, sysname])
		face_name = facename
		type = type_id
		default_val = defaultval
		prop_hint = prophint
		prop_hint_str = prophintstring
		usage = usage_id

	func add_property_info(es: EditorSettings) -> void:
		if not es.has_setting(sys_name):
			es.set_setting(sys_name, default_val)
		(
			es
			. add_property_info(
				{
					"name": sys_name,
					"type": type,
					"hint": prop_hint,
					"hint_string": prop_hint_str,
				}
			)
		)


# --------------------------------------------------
# <Private Variables>
# ツールバーに表示するボタン
var _btn: Button
# 起動したNeovimプロセスのID
var _process_id: Array[int] = []
# エディタ設定のエントリを定義
var _settings_ent: Dictionary[StringName, SettingsEntry] = {
	# neovim実行ファイルのパス設定
	SettingName.NEOVIM_EXECUTABLE:
	(
		SettingsEntry
		. new(
			SettingName.NEOVIM_EXECUTABLE,  # sys_name
			"Neovim Executable",  # face_name
			TYPE_STRING,  # type
			NEOVIM_PATH_DEFAULT,  # default_val
			PROPERTY_HINT_FILE,  # prop_hint (ファイル選択ダイアログを表示)
			"*.exe",  # prop_hint_str (exeファイルのみを選択可能にする)
		)
	),
	# ウィンドウサイズ（nvim-qt はピクセル、neovide は本来 cols/rows。ここでは引数分岐で扱いを変える）
	SettingName.WINDOW_SIZE:
	SettingsEntry.new(
		SettingName.WINDOW_SIZE, "Window Size (nvim-qt)", TYPE_VECTOR2I, Vector2i(2048, 1200)
	),
	# IPアドレス
	SettingName.IP_ADDRESS:
	SettingsEntry.new(SettingName.IP_ADDRESS, "IP Address", TYPE_STRING, "127.0.0.1"),
	# ポート番号
	SettingName.PORT: SettingsEntry.new(SettingName.PORT, "Port", TYPE_INT, 6004),
}


# --------------------------------------------------
# <Private Methods (Callbacks)>
func _enter_tree() -> void:
	_prepare_button()
	_prepare_preferences()
	_register_shortcut()


func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(OPEN_NVIM_ACTION):
		_open_nvim()
		get_tree().root.set_input_as_handled()


func _exit_tree() -> void:
	# 起動したNeovimプロセスを終了させる
	for pid in _process_id:
		# プロセスIDが有効な場合のみ終了処理を行う
		if _is_pid_valid(pid):
			# (Windows環境限定)プロセスを強制終了するコマンドを実行
			OS.execute("taskkill", ["/pid", str(pid), "/t", "/f"])
	# ボタンを削除
	_btn.queue_free()
	_unregister_shortcut()


# --------------------------------------------------
# [Private Method]
# エディタ設定の準備
func _prepare_preferences() -> void:
	var es: EditorSettings = get_editor_interface().get_editor_settings()
	for ent: SettingsEntry in _settings_ent.values():
		ent.add_property_info(es)


# ツールバーに表示するボタンを準備
func _prepare_button() -> void:
	_btn = Button.new()
	_btn.text = "       Open Nvim"
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var tex_rect := TextureRect.new()
	# アイコンテクスチャを設定
	tex_rect.texture = ICON_TEX
	# アスペクト比を保ちつつ中央に表示
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# サイズを無視して展開
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# テクスチャの最小サイズ
	tex_rect.custom_minimum_size = Vector2(32, 32)

	# TextureRectをButtonの子として追加
	_btn.add_child(tex_rect)
	_btn.pressed.connect(_open_nvim)

	# 作成したボタンをエディタのツールバーコンテナに追加
	add_control_to_container(CONTAINER_TOOLBAR, _btn)


# Objectからアタッチされているスクリプトのパスを取得
func _get_script_path_from_obj(obj: Object) -> String:
	# ObjectにアタッチされているScriptを取得
	var script: Script = obj.get_script()
	# Scriptが存在しない場合は空文字列を返す
	if script == null:
		return ""
	# Scriptのresource_pathを返す
	return script.resource_path


# 現在エディタで編集中のシーンのルートノードからスクリプトパスを取得
func _get_script_path_from_sceneroot() -> String:
	# 現在編集中のシーンのルートノードを取得
	var scene_root := get_editor_interface().get_edited_scene_root()
	# シーンルートが存在しない場合は空文字列を返す
	if scene_root == null:
		return ""
	# シーンルートからスクリプトパスを取得して返す
	return _get_script_path_from_obj(scene_root)


# 指定された設定名のエディタ設定値を取得
func _get_setting_value(name: String) -> Variant:
	var es: EditorSettings = get_editor_interface().get_editor_settings()
	return es.get_setting(_settings_ent[name].sys_name)


# Neovim起動時の追加引数を生成（nvim-qt / neovide を分岐）
func _make_neovim_args() -> Array[String]:
	var size: Vector2i = _get_setting_value(SettingName.WINDOW_SIZE)
	var ip: String = _get_setting_value(SettingName.IP_ADDRESS)
	var port: int = _get_setting_value(SettingName.PORT)

	# nvim-qtでは -qwindowgeometryを使用
	var ret: Array[String] = []
	if _is_nvim_qt():
		ret = [
			"-qwindowgeometry",
			"%dx%d" % [size.x, size.y],
		]
	ret += [
		"--",
		"--listen",
		"%s:%d" % [ip, port],
	]
	return ret


# Neovimを実行ファイルパスから判断する
func _is_nvim_qt() -> bool:
	var path := _get_setting_value(SettingName.NEOVIM_EXECUTABLE)
	# pathに"nvim-qt"という文字列が含まれていればtrueを返す
	return path.to_lower().find("nvim-qt") != -1


# Neovimプロセスを起動する
func _open_nvim() -> void:
	# 現在編集中のシーンのスクリプトパスを取得
	var path := _get_script_path_from_sceneroot()
	var target := "."  # デフォルトはカレントディレクトリ
	# スクリプトパスが空でない場合、絶対パスに変換してtargetに設定
	if not path.is_empty():
		target = ProjectSettings.globalize_path(path)
	# Neovim起動時のオプションを作成 (スクリプトパス + 追加引数)
	var options := [target] + _make_neovim_args()
	# エディタ設定からNeovimの実行パスを取得
	var exec_path: String = _nvim_executable_path()
	# Neovimプロセスを起動し、そのPIDを記録
	var pid := OS.create_process(exec_path, options)
	if pid != -1:
		_process_id.append(pid)
	else:
		push_error("Failed to launch Neovim process: %s" % exec_path)


# Neovim実行ファイルのパスを取得
func _nvim_executable_path() -> String:
	# エディタ設定から取得
	return _get_setting_value(SettingName.NEOVIM_EXECUTABLE)


# --------------------------------------------------
# <Shortcut Handling>
func _register_shortcut() -> void:
	# 入力マップにアクションを追加（プロジェクト設定ではなく一時的に利用）
	if not InputMap.has_action(OPEN_NVIM_ACTION):
		InputMap.add_action(OPEN_NVIM_ACTION)

	var ev := InputEventKey.new()
	ev.keycode = KEY_L
	ev.alt_pressed = true
	ev.ctrl_pressed = true

	InputMap.action_erase_events(OPEN_NVIM_ACTION)
	InputMap.action_add_event(OPEN_NVIM_ACTION, ev)
	# プロジェクト設定への保存は行わない


# ショートカットキーを解除
func _unregister_shortcut() -> void:
	if InputMap.has_action(OPEN_NVIM_ACTION):
		InputMap.erase_action(OPEN_NVIM_ACTION)


# --------------------------------------------------
# <Static Methods>
static func _is_pid_valid(pid: int) -> bool:
	# プロセスIDが-1でない場合、有効とみなす
	return pid != -1
