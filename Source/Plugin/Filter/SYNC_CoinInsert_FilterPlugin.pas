unit SYNC_CoinInsert_FilterPlugin;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// AviUtl2 メディアオブジェクトの登録、インスタンスの作業領域と入出力。

interface

uses
  AviUtl2FilterTypes;

// DLL 所有の登録テーブル。ホストが参照し、DLL だけが初期化・解放する。
function GetCoinInsertTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  System.SyncObjs, System.SysUtils, Winapi.Windows,
  PluginFilterTable, CoinInsert_Timeline, CoinInsert_Metal, CoinInsert_Renderer,
  CoinInsert_Parameters;

type
  TCoinSequence = record
    Spec: string;
    Coins: TCoinList;
    // 指定文字列が変わったときだけ、保持している解析済みリストを置き換える。
    procedure Update;
  end;

  TCoinSession = class
  private
    // 同じインスタンスの描画で使う解析済みリストと作業バッファを保護する。
    FVideoLock: TCriticalSection;
    FVideoSequence: TCoinSequence;
    FPixels: TCoinPixels;
  public
    constructor Create;
    destructor Destroy; override;
    // 借用した SDK 構造体から設定時刻を取得し、画像をホストへ渡す。
    // バッファはセッション所有。処理成功時は 1、失敗時は 0。
    function VideoFrame(Video: PFILTER_PROC_VIDEO): Byte;
  end;

var
  TableReady: Boolean;

procedure TCoinSequence.Update;
var
  Current: string;
begin
  Current := ReadCoinSpec;
  if Current = Spec then Exit;
  Coins := ParseCoinList(Current);
  Spec := Current;
end;

constructor TCoinSession.Create;
begin
  inherited;
  FVideoLock := TCriticalSection.Create;
end;

destructor TCoinSession.Destroy;
begin
  FVideoLock.Free;
  inherited;
end;

function TCoinSession.VideoFrame(Video: PFILTER_PROC_VIDEO): Byte;
var
  Width, Height: Integer;
begin
  Result := 0;
  if not Assigned(Video^.SetImageData) then Exit;
  FVideoLock.Acquire;
  try
    FVideoSequence.Update;
    RenderCoinFrame(ReadCoinView, ReadCoinTiming, FVideoSequence.Coins,
      Video^.Object_^.Time, FPixels, Width, Height);
    Video^.SetImageData(@FPixels[0], Width, Height);
    Result := 1;
  finally
    FVideoLock.Release;
  end;
end;

function ProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  Result := 0;
  try
    if (Video = nil) or (Video^.Object_ = nil) or (Video^.UserData = nil) then Exit;
    Result := TCoinSession(Video^.UserData).VideoFrame(Video);
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_CoinInsert video: ' + E.Message));
  end;
end;

function CreateSession(EffectID: Int64): Pointer; cdecl;
begin
  Result := nil;
  try
    Result := TCoinSession.Create;
  except
    // 失敗時はホストへ nil を返す。
  end;
end;

procedure DestroySession(EffectID: Int64; UserData: Pointer); cdecl;
begin
  try
    TCoinSession(UserData).Free;
  except
    // ホストの終了処理まで Delphi 例外を伝播させない。
  end;
end;

function GetCoinInsertTable: PFILTER_PLUGIN_TABLE;
begin
  if not TableReady then
  begin
    PrepareCoinFaces;
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT
      or FILTER_FLAG_USERDATA, 'コイン投入演出', 'SYNC',
      'コイン投入演出 / SYNC_CoinInsert v1.0.0', ProcVideo, nil);
    RegisterCoinInsertParameters;
    GetPluginTable^.Func_Create := CreateSession;
    GetPluginTable^.Func_Destroy := DestroySession;
    TableReady := True;
  end;
  Result := GetPluginTable;
end;

end.
