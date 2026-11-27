# SYNC_CoinInsert 作業ノート

## プロジェクトの前提

- Delphi プロジェクトは `SYNC_CoinInsert.dproj`、本番プラグインは `SYNC_CoinInsert.auf2`。登録名は「コイン投入演出」、グループは `SYNC`。
- `D:\DelphiProg\MyApp\SYNC_WeatherFX` から Win64 ビルド設定、SDK の型とフィルターテーブル登録処理、共通作業手順を継承した。
- AviUtl2 SDK のメディアオブジェクトとして映像と音声を生成する。位置、拡大率、回転、透明度はホスト標準項目で制御する。
- 利用方法と設定値は [README.md](README.md) を参照する。

## ビルド

- Delphi 37.0 / Win64。IDE では `SYNC_CoinInsert.dproj` を直接開く。
- プロジェクトルートで `rsvars.bat` を呼び、MSBuild で Debug / Release の両方を実行する。警告0・エラー0と AUF2 の更新を確認し、最後に Release を配置する。

```powershell
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_CoinInsert.dproj /t:Build /p:Config=Debug /p:Platform=Win64'
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_CoinInsert.dproj /t:Build /p:Config=Release /p:Platform=Win64'
```

全体を再ビルドし、ログを残す場合:

```powershell
New-Item -ItemType Directory -Path Win64\BuildLogs -Force | Out-Null
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_CoinInsert.dproj /t:Rebuild /p:Config=Debug /p:Platform=Win64 /fl /flp:"logfile=Win64\BuildLogs\Debug.log;verbosity=normal;encoding=UTF-8"'
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_CoinInsert.dproj /t:Rebuild /p:Config=Release /p:Platform=Win64 /fl /flp:"logfile=Win64\BuildLogs\Release.log;verbosity=normal;encoding=UTF-8"'
```

## ビルド後イベントとプロジェクト登録

- 出力先は Debug / Release 共通で `C:\ProgramData\aviutl2\Plugin\SYNC_CoinInsert\`。DLL を `SYNC_CoinInsert.auf2` へコピーし、成功後に DLL を削除する。Release では RSM も削除する。
- イベントはコピー元の一行の `copy ... && del ...` を維持する。後続コマンドが `if` の条件内へ取り込まれる `&&if errorlevel ...` の連結へ戻さない。
- DCU は `Win64\Debug\DCU` / `Win64\Release\DCU`。AUF2 の更新時刻・サイズと、DLL / Release RSM が残っていないことを確認する。
- デバッガーホストは実際のコピー元 `.dproj` に合わせ、両構成とも `D:\aviutl2_v2.1.16\aviutl2.exe`。実際のコピー元のデバッガー設定を継承している。
- ユニット追加時は `.dpr` の `in` と `.dproj` の `DCCReference` を両方更新する。現在の検索パスは `Source\Common`、`Source\Lib`、`Source\Lib\FilterTable`、`Source\Plugin\Filter`。
- 開いている `.dpr` / `.dproj` を外部更新した場合は、IDE で開き直して参照を読み込む。古い内容で保存して追加ユニットの参照を失わないようにする。
- MSBuild 成功と IDE の Code Insight・メッセージ表示は区別する。IDE 内のビルドを未確認なら、確認済みと報告しない。

## ソース配置

- `SYNC_CoinInsert.dpr` は DLL のエクスポートと最低対応バージョンを担当する。
- `Source/Plugin/Filter` は SDK 項目の登録と映像・音声の入出力を担当する。硬貨リストと作業バッファは映像・音声別に保持する。
- `Source/Common/CoinInsert_Timeline.pas` は硬貨の属性、額面リストの解析、投入順・投入と接触の時刻を担当する。
- `Source/Common/CoinInsert_Metal.pas` と `CoinInsert_Renderer.pas` は金属面・縁刻・穴の内壁を生成し、投入口付近で硬貨の形状をクリッピングする。生成画像の中心は投入口の位置とする。
- `Source/Common/CoinInsert_Audio.pas` は映像と共有する接触時刻を起点に、硬貨の接触・反跳・落下音を合成する。
- `Source/Lib` は SDK の型とフィルターテーブルの共通登録処理を保持する。

## コメント・分割・文字コード

- ユニット先頭に目的と責務を書く。
- 公開処理には入力、出力、重要な副作用を記載する。必要に応じて値の単位、状態の有効範囲、所有権、保存対象も明記する。
- ホストの画像・テーブル・項目ポインター、描画バッファ、キャッシュは、誰が保持・解放するかを書く。コードをそのまま言い換えるコメントは避ける。
- 日本語を含む `.pas` / `.dpr` / Windows PowerShell 用 `.ps1` は UTF-8 BOM 付きとし、改行は CRLF にする。
- 1ユニットは約1,500行を目安に責務で分割する。UI・描画・データ処理を分け、フォームの `.pas` と `.dfm` は同じフォルダーへ置く。
- SDK 型の順序・サイズ・配置を変更する場合は公式定義と照合する。ホスト所有ポインターをコールバックの外へ保存せず、DLL 境界へ例外を漏らさない。

## 検査とアプリ操作

- 通常のビルド・検査では AviUtl2 と IDE を起動・操作しない。画面操作はユーザーから明示依頼がある場合に行う。
- 本体を検査する場合は同じ本番 AUF2 を読み込む。コピー元プロジェクト、ユーザーの AUP2、他のプラグインは変更しない。

## Setup の扱い

- `Setup` は WeatherFX から全ファイルをそのままコピーした。README、スクリプト、カタログと ZIP の内容は WeatherFX 用。
- CoinInsert の配布を用意する場合は、別途依頼を受けたうえで名前・ID・公開日・配布ファイル・ハッシュを実際の配布内容に合わせる。初回の正式配布バージョンは v1.0.0 とする。

## 初回実装の検査（2026-11-27）

- 本体の表示バージョンは開発版 `v0.1.0`。Delphi 37.0 で Win64 Debug／Release を再ビルドし、両構成とも警告 0・エラー 0。Release の AUF2 を既定の出力先に配置した。
- 両構成の AUF2 を直接ロードし、登録項目と初期値、標準描画パラメータ、両方向のクリッピング、5 円・50 円の穴、硬貨の重複と無効入力、拡大率と距離、逆シーク、効果音の開始と音量、音声ブロック分割を確認した。
- 投入間隔は硬貨が現れてから次の硬貨が現れるまでの時間とした。投入時間より短い場合は重なって進行する。Release の描画は初期サイズで約 1 ms/フレーム、121 枚が重なる 300% 設定では約 47～73 ms/フレームだった。いずれも検査 EXE からの測定値。
- 描画の確認画像は `Win64/Verification/CoinInsertPreview.png`。AviUtl2 の画面での動作は未確認。
- `Setup` の 5 ファイルは、コピー元と SHA-256 が一致した。

## 横投入の下降方式（2026-11-27）

- 「横投入の下降」を設定一覧の末尾に追加した。初期値の「スムーズ」は従来の上昇と頂点を使い、頂点から投入完了まで一続きで下降する。「一時停止」は従来の軌道を使う。
- Win64 Debug／Release とも警告 0・エラー 0。標準配置先の旧 AUF2 は AviUtl2 が使用中だったため、プロジェクト内で両構成をビルドして検証し、旧版を一時フォルダーへ退避して Release 版を配置した。
- AUF2 の直接検査で 50 円硬貨のクリッピング開始後も「スムーズ」の下降が続くことを確認した。「一時停止」の 42 フレームは旧版と一致し、「スムーズ」も正面・上昇区間などの 35 フレームが旧版と一致した。両設定で発音時刻と PCM が一致した。

## AviUtl2カタログ登録時の共通ルール

1. **概要は35文字以内。** `Setup/*.catalog.json` の `summary` は、JSONのエスケープ表記ではなく実際の表示文字列を数える。機能の詳細や補足は概要に詰め込まず、説明・READMEに記載する。
2. **既存タグを優先する。** [公開カタログの `index.json`](https://github.com/Neosku/aviutl2-catalog-data/blob/main/index.json) で、同じ製品や近い用途に使われているタグの表記を確認し、用途を表すものだけを選ぶ。同義語を重ねたり、製品ごとに新しいタグを量産したりしない。
3. **配布専用フォルダー単位で導入・削除する。** ZIP内を製品専用フォルダーにまとめ、ダウンロード・展開後の配置はフォルダーの `copy` 1件、アンインストールはその専用フォルダーだけを指定する `delete` 1件を基本とする。共有フォルダーや、ユーザー素材・設定を含むフォルダーは一括削除しない。既存パッケージで変更する際は、配布ZIPの配置とセットアップスクリプトの検証条件も確認し、整合しない場合は既存の手順を維持する。
