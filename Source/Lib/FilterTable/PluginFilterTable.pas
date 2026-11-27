unit PluginFilterTable;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// AviUtl2 Filterテーブルと設定項目の順次登録を一か所で管理する。
// Syncroh2 / SYNC_Lyrics 由来の共通基盤を SYNC_Mine から引き継ぐ。
// テーブルと登録先の配列は DLL が所有し、各項目の実体は呼出側が保持する。

interface

uses
  AviUtl2FilterTypes;

// 登録情報とコールバックを受け、既存の登録項目を空にして初期化する。
// 文字列・項目はコピーせず参照するため、DLL の使用中は有効に保つ。
procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
// Add 系は項目と初期値を受け、呼出側所有の項目を登録順に参照する。
// 項目、文字列および nil 終端の選択肢リストは DLL の使用中有効に保つ。
// 上限を超える登録では ERangeError を送出する。
procedure AddString(var Item: TFILTER_ITEM_STRING; Name, Value: PWideChar);
procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double);
procedure AddCheck(var Item: TFILTER_ITEM_CHECK; Name: PWideChar;
  Value: Byte);
procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar;
  Value: Integer; List: Pointer);

// DLL が所有する現在のテーブルを返す。呼出側で解放しない。
function GetPluginTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  System.SysUtils;

const
  MAX_GUI_ITEMS = 100;

var
  GTable: TFILTER_PLUGIN_TABLE;
  GItems: array[0..MAX_GUI_ITEMS - 1] of Pointer;
  GItemIndex: Integer;

procedure RegisterItem(Item: Pointer);
begin
  // 最後の1要素はAviUtl2が要求するnil終端用に予約する。
  if GItemIndex >= High(GItems) then
    raise ERangeError.CreateFmt(
      'Filter setting item count exceeds the limit (%d)',
      [High(GItems)]);
  GItems[GItemIndex] := Item;
  Inc(GItemIndex);
  GItems[GItemIndex] := nil;
end;

procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
begin
  GItemIndex := 0;
  FillChar(GItems, SizeOf(GItems), 0);
  GTable.Flag := Flag;
  GTable.Name := Name;
  GTable.Label_ := Label_;
  GTable.Information := Information;
  GTable.Items := @GItems[0];
  GTable.Func_Proc_Video := VideoProc;
  GTable.Func_Proc_Audio := AudioProc;
  GTable.Func_Create := nil;
  GTable.Func_Destroy := nil;
end;

procedure AddString(var Item: TFILTER_ITEM_STRING; Name, Value: PWideChar);
begin
  Item.ItemType := 'string';
  Item.Name := Name;
  Item.Value := Value;
  RegisterItem(@Item);
end;

procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double);
begin
  Item.ItemType := 'track';
  Item.Name := Name;
  Item.Value := Value;
  Item.S := S;
  Item.E := E;
  Item.Step := Step;
  RegisterItem(@Item);
end;

procedure AddCheck(var Item: TFILTER_ITEM_CHECK; Name: PWideChar;
  Value: Byte);
begin
  Item.ItemType := 'check';
  Item.Name := Name;
  Item.Value := Value;
  RegisterItem(@Item);
end;

procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar;
  Value: Integer; List: Pointer);
begin
  Item.ItemType := 'select';
  Item.Name := Name;
  Item.Value := Value;
  Item.List := List;
  RegisterItem(@Item);
end;

function GetPluginTable: PFILTER_PLUGIN_TABLE;
begin
  Result := @GTable;
end;

end.
