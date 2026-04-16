# 現場ノート（Genba Note）

個人事業主向けの作業記録アプリです。

## コンセプト

「記憶を使わない仕事」

## Step1 で作成した内容

- Android 向け Flutter アプリの初期構成
- `flutter_riverpod` による `ProviderScope` 設定
- `go_router` によるホーム画面ルーティング
- `sqflite` と `path_provider` を使った SQLite 初期化雛形
- ホーム画面と FAB の最小実装

## ディレクトリ構成

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router.dart
├── core/
│   ├── constants/
│   ├── db/
│   └── utils/
├── features/
│   ├── master/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── work_log/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── shared/
    ├── providers/
    └── widgets/
```

## 依存パッケージ

- `flutter_riverpod`
- `sqflite`
- `path_provider`
- `go_router`

## 実行手順

最初にセットアップスクリプトでローカル開発環境を作成します。

```bash
./scripts/setup_android_tools.sh
```

その後、実行スクリプトでアプリを起動します。

```bash
./scripts/run_android.sh
```

ソース更新後に、起動中のエミュレータへ最新ビルドだけを入れ直したい場合は次を使います。

```bash
./scripts/reinstall_android.sh
```

必要なら解析込みでも実行できます。

```bash
RUN_ANALYZE=1 ./scripts/reinstall_android.sh
```

`run_android.sh` はデフォルトで位置シミュレータも自動起動します。無効化したい場合は次を使います。

```bash
AUTO_SIMULATE_LOCATION=0 ./scripts/run_android.sh
```

エミュレータの現在地をテスト用に動かしたい場合は、次のスクリプトを使えます。

```bash
./scripts/simulate_location.sh
```

デフォルトでは東京駅付近を中心に、半径 10km 以内を 10 秒ごとにランダム移動します。

画面付きで起動するのがデフォルトです。バックグラウンドの headless 実行にしたい場合だけ、次を使います。

```bash
HEADLESS=1 ./scripts/run_android.sh
```

すでに起動中のエミュレータをそのまま再利用したい場合は、次を使います。

```bash
REUSE_EXISTING_EMULATOR=1 ./scripts/run_android.sh
```

既定でも、起動中のエミュレータが画面付きならそのまま再利用します。強制的に再起動したい場合だけ次を使います。

```bash
FORCE_EMULATOR_RESTART=1 ./scripts/run_android.sh
```

エミュレータ起動で詰まる場合は、AVD を `.tool/android-avd` から読み込む前提です。起動失敗時は `/tmp/genba_note_api_36.log` に直近ログが出ます。

このスクリプトは以下をまとめて実行します。

- 実行用コピーを `/tmp/genba-note-run` に同期
- ASCII パス上の Flutter SDK コピーを準備
- Android エミュレータを起動
- `flutter pub get`
- `flutter analyze`
- `flutter run -d emulator-5554`

`reinstall_android.sh` は以下をまとめて実行します。

- 実行用コピーを `/tmp/genba-note-run` に同期
- `flutter pub get`
- debug APK を再ビルド
- 起動中エミュレータへ `adb install -r`
- アプリを前面起動

セットアップスクリプトは以下を行います。

- Flutter SDK を `.tool/flutter` に配置
- Android SDK を `.tool/android-sdk` に配置
- JDK を `.tool/jdk` に配置
- Android Emulator 用の AVD を作成

## 現在の状態

- FAB タップで即記録
- 履歴一覧を「すべて / 未整理」で切り替え
- 詳細編集で物件・請求先・メモ・ステータスを更新
- 未整理タブで複数選択し、一括で請求先・物件・完了設定
- 地図画面で GPS 付き履歴をピン表示
- 地図と Bottom Sheet 一覧が連動し、詳細編集へ遷移可能
