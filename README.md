![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-0.01-brightgreen.svg)

# OpenNvim for Godot 4.x

GodotエディタからNeovimを一発で起動するためのシンプルなプラグインです。
現在のシーンのルートノードにアタッチされているスクリプトを、素早くNeovimで開くことができます。

<img src="./images/open_nvim_button.png" alt="usage image" width="600"/>

## 主な機能

- **ツールバーボタン**: エディタ上部のツールバーにNeovimを起動するボタンを追加します。
- **ショートカットキー**: `Ctrl + Alt + M` で即座にNeovimを起動可能です。
- **スクリプトの自動オープン**: 現在編集中のシーンのルートノードにスクリプトが設定されていれば、そのファイルを開いた状態でNeovimを起動します。
- **複数起動管理**: 複数のNeovimインスタンスを管理し、エディタ終了時にそれらをクリーンアップします。
- **エディタ設定との連携**: Neovimの実行パスやウィンドウサイズをGodotのエディタ設定からカスタマイズ可能です。

## インストール

1. このリポジトリをダウンロードまたはクローンします。
2. `addons/open_nvim` フォルダを、あなたのGodotプロジェクトの `addons/` ディレクトリに配置します。
3. Godotエディタで `プロジェクト` -> `プロジェクト設定` -> `プラグイン` タブを開き、`OpenNvim` を **有効** にします。

## 使い方

1. エディタ上部の「Open Nvim」ボタンをクリックするか、ショートカット `Ctrl + Alt + M` を押します。
2. 現在のシーンのルートノードにスクリプトがアタッチされていれば、そのスクリプトが開かれます。アタッチされていない場合は、プロジェクトのルートディレクトリでNeovimが起動します。

## 設定

`エディタ` -> `エディタ設定` -> `OpenNvim` セクションから以下の設定を変更できます。

- **Neovim Executable**: Neovim (または nvim-qt, neovide 等) の実行ファイルパスを指定します。
  - デフォルト: `nvim-qt.exe`
- **Window Size (nvim-qt)**: `nvim-qt` を使用する場合の初期ウィンドウサイズを指定します。
- **IP Address / Port**: Neovimの `--listen` オプションで使用する接続先情報を設定します。

## 動作環境

- **OS**: Windows / Linux
- **対応Neovim**: `nvim-qt`, `neovide`, `nvim` (PATHが通っているか実行ファイルを指定している場合)
  - ※ `nvim-qt` 以外のGUIクライアントでは、ウィンドウサイズ指定などの一部オプションが無視される場合があります。

## ライセンス

MIT License
