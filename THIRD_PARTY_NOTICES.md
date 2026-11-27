# ライセンスと共通基盤の由来

コイン投入演出（SYNC_CoinInsert） Copyright (c) 2026 VRAMの魔術師

本体のソースコードは、継承元の SYNC_WeatherFX と同じ GNU General Public License v3.0（GPL-3.0-only）です。全文は [LICENSE](LICENSE) を参照してください。

## AviUtl ExEdit2 Plugin SDK

- 著作権 Copyright (c) 2025 Kenkun
- ライセンス MIT
- 対象は `Source/Lib/AviUtl2FilterTypes.pas` の SDK 型定義、コールバックと編集 API の ABI 定義です。音声入力の ABI は公式 SDK の `filter2.h` と `MediaObject.cpp` に沿っています。[AviUtl ExEdit2 Plugin SDK 配布元](https://spring-fragrance.mints.ne.jp/aviutl/)
- ライセンス全文は [ThirdParty/LICENSE.AviUtl2-SDK.txt](ThirdParty/LICENSE.AviUtl2-SDK.txt) を参照してください。

## 継承元

- **SYNC_WeatherFX** から Win64 ビルド設定・ビルドイベント、SDK 型定義、フィルターテーブル登録処理、作業手順を継承しています。
- **SYNC_AquaFX / SYNC_ParticleFX / SYNC_Mine / SYNC_PhotoShot / SYNC_Nicomea** は、継承元のプロジェクト構成・ビルド設定・SDK 型定義・配布処理の由来です。
- **Syncroh2 / SYNC_Lyrics** は、`PluginFilterTable.pas` の登録処理の由来です。

本体は Delphi RTL を使用します。硬貨・投入口の画像は本体が生成します。
