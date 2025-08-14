@tool
class_name OpenNvim
extends EditorPlugin


# --------------------------------------------------
# <Defines>
# 設定項目を構造化するためのヘルパークラス
class SettingsEntry:
	var sys_name: String  # プロジェクト設定での実際のキー名 (例: "OpenNvim/neovim_executable")
	var face_name: String  # エディタでの表示名 (例: "Neovim Executable")
	var type: int  # プロジェクト設定のデータ型 (TYPE_STRING, TYPE_INT, TYPE_VECTOR2I など)
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
		# sys_name にプラグイン名をプレフィックスとして付与
		sys_name = PLUGIN_NAME + "/" + sysname
		face_name = facename
		type = type_id
		default_val = defaultval
		prop_hint = prophint
		prop_hint_str = prophintstring
		usage = usage_id

	# プロジェクト設定にプロパティ情報を追加
	func add_property_info() -> void:
		var p := ProjectSettings
		# 設定がまだ存在しない場合のみ追加
		if not p.has_setting(sys_name):
			# デフォルト値を設定
			p.set_setting(sys_name, default_val)
			# エディタにプロパティ情報を登録
			(
				p
				. add_property_info(
					{
						"name": face_name,  # エディタでの表示名
						"type": type,  # データ型
						"hint": prop_hint,  # プロパティヒント
						"hint_string": prop_hint_str,  # ヒント文字列
						"usage": usage,  # 使用方法
					}
				)
			)


# プロジェクト設定のキー名を定義する定数クラス
class SettingName:
	const NEOVIM_EXECUTABLE := &"neovim_executable"  # Neovim実行ファイルのパス
	const WINDOW_SIZE := &"window_size"  # Neovimウィンドウのサイズ
	const IP_ADDRESS := &"ip"  # 接続先IPアドレス
	const PORT := &"port"  # 接続先ポート番号


# --------------------------------------------------
# <Constants>
# デフォルトのNeovim実行ファイルパス (Windowsを想定)
const NEOVIM_PATH_DEFAULT = "C:/Program Files/neovim/bin/nvim-qt.exe"
# プラグインのアイコンテクスチャ
const ICON_TEX := preload("res://addons/open_nvim/images/nvim_logo.png")
# プラグイン名
const PLUGIN_NAME = "OpenNvim"

# --------------------------------------------------
# <Private Variable>
# ツールバーに表示するボタン
var _btn: Button
# 起動したNeovimプロセスのID
var _process_id: Array[int] = []
# プロジェクト設定のエントリを定義
var _settings_ent: Dictionary = {
	# nvim-qt実行ファイルのパス設定
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
	# ウィンドウサイズ
	SettingName.WINDOW_SIZE:
	SettingsEntry.new(SettingName.WINDOW_SIZE, "Window Size", TYPE_VECTOR2I, Vector2i(2048, 1200)),
	# IPアドレス
	SettingName.IP_ADDRESS:
	SettingsEntry.new(SettingName.IP_ADDRESS, "IP Address", TYPE_STRING, "127.0.0.1"),
	# ポート番号
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
	# 起動したNeovimプロセスを終了させる
	for pid in _process_id:
		# プロセスIDが有効な場合のみ終了処理を行う
		if _is_pid_valid(pid):
			# (Windows環境限定)プロセスを強制終了するコマンドを実行
			OS.execute("taskkill", ["/pid", str(pid), "/t", "/f"])
	# ボタンを削除
	_btn.queue_free()


func _on_button_pressed() -> void:
	# 現在編集中のシーンのスクリプトパスを取得
	var path := _get_script_path_from_sceneroot()
	var target := "."  # デフォルトはカレントディレクトリ
	# スクリプトパスが空でない場合、絶対パスに変換してtargetに設定
	if not path.is_empty():
		target = ProjectSettings.globalize_path(path)
	# Neovim起動時のオプションを作成 (スクリプトパス + 追加引数)
	var options := [target] + _make_neovim_args()
	# プロジェクト設定からNeovimの実行パスを取得
	var exec_path: String = _get_setting_value(SettingName.NEOVIM_EXECUTABLE)
	# Neovimプロセスを起動し、そのPIDを記録
	_process_id.append(OS.create_process(exec_path, options))


# --------------------------------------------------
# [Private Method]
# Neovim起動時の追加引数を生成
func _make_neovim_args() -> Array[String]:
	# プロジェクト設定からウィンドウサイズ、IPアドレス、ポート番号を取得
	var size: Vector2i = _get_setting_value(SettingName.WINDOW_SIZE)
	var ip: String = _get_setting_value(SettingName.IP_ADDRESS)
	var port: int = _get_setting_value(SettingName.PORT)
	# (nvim-qt限定) コマンドライン引数を生成
	return [
		"-qwindowgeometry",  # ウィンドウジオメトリを指定するオプション
		"%dx%d" % [size.x, size.y],  # ウィンドウサイズ (例: "2048x1200")
		"--",  # オプションと引数の区切り
		"--listen",  # リッスンアドレスを指定するオプション
		"%s:%d" % [ip, port],  # リッスンアドレス (例: "127.0.0.1:6004")
	]


# 指定された設定名のプロジェクト設定値を取得
func _get_setting_value(name: String) -> Variant:
	# _settings_ent 辞書から設定エントリを取得し、その sys_name を使って ProjectSettings から値を取得
	return ProjectSettings.get_setting(_settings_ent[name].sys_name)


# プロジェクト設定の準備
func _prepare_preferences() -> void:
	# _settings_ent に登録されている全ての設定エントリに対して add_property_info() を呼び出す
	for ent: SettingsEntry in _settings_ent.values():
		ent.add_property_info()
	# 全ての設定が登録された後、プロジェクト設定を保存する
	ProjectSettings.save()


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
	_btn.pressed.connect(_on_button_pressed)

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


# --------------------------------------------------
# [Static Method]
static func _is_pid_valid(pid: int) -> bool:
	# プロセスIDが-1でない場合、有効とみなす
	return pid != -1
