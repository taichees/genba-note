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

このリポジトリでは、ローカルに配置した Flutter / Android SDK を使う実行スクリプトを利用できます。

```bash
./scripts/run_android.sh
```

このスクリプトは以下をまとめて実行します。

- 実行用コピーを `/tmp/genba-note-run` に同期
- ASCII パス上の Flutter SDK コピーを準備
- Android エミュレータを起動
- `flutter pub get`
- `flutter analyze`
- `flutter run -d emulator-5554`

前提として、`.tool/` 配下に以下が準備済みである必要があります。

- `.tool/flutter`
- `.tool/android-sdk`
- `.tool/jdk`

## 現在の状態

- ホーム画面に「現場ノート」を表示
- 右下に FAB を表示
- SQLite 接続処理とテーブル作成処理の雛形あり
