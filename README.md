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
- `in_app_purchase`

## 実行手順

最初にセットアップスクリプトでローカル開発環境を作成します。

**macOS**

```bash
./scripts/setup_android_tools.sh
```

**Windows (PowerShell)**

```powershell
.\scripts\setup_android_tools.ps1
```

（`ExecutionPolicy` で弾かれる場合は、例: `powershell -ExecutionPolicy Bypass -File .\scripts\setup_android_tools.ps1`）

**macOS（続き）** — 実行スクリプトでアプリを起動します。

```bash
./scripts/run_android.sh
```

**Windows** — `run_android.sh` は mac 前提のため、セットアップ完了メッセージのとおり `JAVA_HOME` / `ANDROID_SDK_ROOT` / `ANDROID_AVD_HOME` / `Path` を設定し、エミュレータ起動後にプロジェクト直下で `flutter run` するか、WSL 上で上記 `run_android.sh` を使います。

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

デフォルトでは東京駅付近を中心に、半径 10km 以内を 1 分ごとにランダム移動します。

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

Android ホーム画面ウィジェットは、ホーム画面のウィジェット一覧から「現場ノート」を追加すると使えます。最小サイズの「記録」ウィジェットをタップすると、アプリを開かずに未整理レコードを 1 件保存します。

エミュレータでタップ相当を確認したい場合は、次の broadcast でもテストできます。

```bash
./.tool/android-sdk/platform-tools/adb -s emulator-5554 shell am broadcast \
  -a jp.genbanote.app.action.QUICK_RECORD \
  -n jp.genbanote.app/.GenbaNoteWidgetProvider
```

DB を空にして検証したい場合は、アプリ停止や DB ファイル削除ではなく次のスクリプトを使ってください。ホーム画面ウィジェットの表示が崩れにくくなります。

```bash
./scripts/clear_db.sh
```

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
- 記録後に逆ジオコーディングで大体の住所を非同期補完し、詳細画面に表示
- Android ホーム画面ウィジェットから未整理レコードを 1 タップで保存可能
- 無料 / 100円 / 500円 のプラン状態管理
- 51件目到達、検索実行時、機種変更導線、地図、一括編集で課金導線を表示
- 設定画面、プラン比較画面、購入復元、hidden debug panel を追加
- 課金状態は SQLite に永続化し、起動時に復元
- 500円プラン向けのクラウド同期インターフェースをプレースホルダ実装

## 課金商品 ID

- `jp.genbanote.plan.local_100`
- `jp.genbanote.plan.cloud_500`

初月無料トライアルは `jp.genbanote.plan.cloud_500` を Play Console 側で設定します。

## Google Play Console 準備

1. 新しいアプリを作成し、パッケージ名を `jp.genbanote.app` に合わせる
2. アプリ内課金商品を 2 つ作成する
3. 商品 ID は README の課金商品 ID と一致させる
4. `500円プラン` 側に無料トライアルを設定する
5. 内部テスト用トラックを作成し、テスターを追加する

## 内部テストの流れ

1. Play Console で課金商品を `有効` にする
2. 内部テストへ `.aab` か `release apk` をアップロードする
3. テスターへ招待リンクを配布する
4. テスター端末で Play ストア版をインストールして購入導線を確認する

## 署名設定

1. `android/key.properties.example` を `android/key.properties` としてコピーする
2. `storeFile`、`storePassword`、`keyAlias`、`keyPassword` を実値へ置き換える
3. keystore ファイルを `android/keystore/` など任意の安全な場所へ置く

`android/key.properties` は `.gitignore` で除外しています。ファイルが無い場合、release ビルドは debug 署名で動作確認用にビルドされます。

## リリースビルド

```bash
JAVA_HOME=.tool/jdk/jdk-17.0.18+8/Contents/Home \
ANDROID_SDK_ROOT=.tool/android-sdk \
.tool/flutter/bin/flutter build apk --release
```

Play 提出用に App Bundle を作る場合:

```bash
JAVA_HOME=.tool/jdk/jdk-17.0.18+8/Contents/Home \
ANDROID_SDK_ROOT=.tool/android-sdk \
.tool/flutter/bin/flutter build appbundle --release
```
