library SYNC_CoinInsert;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// AviUtl2 の DLL エクスポート。Delphi 例外はホスト側へ伝播させない。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
  CoinInsert_Timeline in 'Source\Common\CoinInsert_Timeline.pas',
  CoinInsert_Metal in 'Source\Common\CoinInsert_Metal.pas',
  CoinInsert_Renderer in 'Source\Common\CoinInsert_Renderer.pas',
  CoinInsert_Parameters in 'Source\Plugin\Filter\CoinInsert_Parameters.pas',
  SYNC_CoinInsert_FilterPlugin in 'Source\Plugin\Filter\SYNC_CoinInsert_FilterPlugin.pas';

{$R *.res}

// SDK 形式で最低対応ホストバージョンを返す。2011600 は 2.1.16。
function RequiredVersion: Cardinal; cdecl;
begin
  Result := 2011600;
end;

// ホストのバージョンを確認し、登録完了時は 1、非対応または失敗時は 0 を返す。
function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  Result := 0;
  if Version < RequiredVersion then Exit;
  try
    if GetCoinInsertTable <> nil then Result := 1;
  except
    // 初期化できない場合は 0 を返す。
  end;
end;

procedure UninitializePlugin; cdecl;
begin
  // インスタンスのバッファは func_destroy、共有テクスチャは DLL が解放する。
end;

// DLL が所有する登録テーブルを返す。取得に失敗した場合は nil。
function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := nil;
  try
    Result := GetCoinInsertTable;
  except
    // 未完成の登録テーブルは渡さない。
  end;
end;

exports
  RequiredVersion name 'RequiredVersion',
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
