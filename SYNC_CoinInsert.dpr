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
  CoinInsert_Audio in 'Source\Common\CoinInsert_Audio.pas',
  CoinInsert_Parameters in 'Source\Plugin\Filter\CoinInsert_Parameters.pas',
  SYNC_CoinInsert_FilterPlugin in 'Source\Plugin\Filter\SYNC_CoinInsert_FilterPlugin.pas';

{$R *.res}

function RequiredVersion: Cardinal; cdecl;
begin
  Result := 2011600;
end;

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
