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

画面付きで起動するのがデフォルトです。バックグラウンドの headless 実行にしたい場合だけ、次を使います。

```bash
HEADLESS=1 ./scripts/run_android.sh
```

すでに起動中のエミュレータをそのまま再利用したい場合は、次を使います。

```bash
REUSE_EXISTING_EMULATOR=1 ./scripts/run_android.sh
```

このスクリプトは以下をまとめて実行します。

- 実行用コピーを `/tmp/genba-note-run` に同期
- ASCII パス上の Flutter SDK コピーを準備
- Android エミュレータを起動
- `flutter pub get`
- `flutter analyze`
- `flutter run -d emulator-5554`

セットアップスクリプトは以下を行います。

- Flutter SDK を `.tool/flutter` に配置
- Android SDK を `.tool/android-sdk` に配置
- JDK を `.tool/jdk` に配置
- Android Emulator 用の AVD を作成

## 現在の状態

- ホーム画面に「現場ノート」を表示
- 右下に FAB を表示
- SQLite 接続処理とテーブル作成処理の雛形あり
