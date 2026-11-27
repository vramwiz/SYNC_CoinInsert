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
  CoinInsert_Audio, CoinInsert_Parameters;

type
  TCoinSequence = record
    Spec: string;
    Coins: TCoinList;
    // 指定文字列が変わったときだけ、保持している解析済みリストを置き換える。
    procedure Update;
  end;

  TCoinSession = class
  private
    // SDK の映像・音声スレッドが、互いのバッファや解析済みリストを共有しない。
    FVideoLock, FAudioLock: TCriticalSection;
    FVideoSequence, FAudioSequence: TCoinSequence;
    FPixels: TCoinPixels;
    FSamples: TCoinSamples;
  public
    constructor Create;
    destructor Destroy; override;
    // 借用した SDK 構造体から設定時刻を取得し、画像・PCM をホストへ渡す。
    // バッファはセッション所有。処理成功時は 1、失敗時は 0。
    function VideoFrame(Video: PFILTER_PROC_VIDEO): Byte;
    function AudioBlock(Audio: PFILTER_PROC_AUDIO): Byte;
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
  FAudioLock := TCriticalSection.Create;
end;

destructor TCoinSession.Destroy;
begin
  FAudioLock.Free;
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

function TCoinSession.AudioBlock(Audio: PFILTER_PROC_AUDIO): Byte;
var
  Count, Channels, Rate, Channel: Integer;
begin
  Result := 0;
  if (Audio^.Scene = nil) or not Assigned(Audio^.SetSampleData) then Exit;
  Count := Audio^.Object_^.SampleNum;
  Channels := Audio^.Object_^.ChannelNum;
  Rate := Audio^.Scene^.SampleRate;
  if (Count < 0) or (Count > 1048576) or (Channels < 1) or (Channels > 32)
    or (Rate < 8000) or (Rate > 768000) then Exit;
  if Count = 0 then Exit(1);
  FAudioLock.Acquire;
  try
    FAudioSequence.Update;
    RenderCoinAudio(ReadCoinTiming, FAudioSequence.Coins, Audio^.Object_^.SampleIndex,
      Count, Rate, ReadCoinVolume, FSamples);
    for Channel := 0 to Channels - 1 do
      Audio^.SetSampleData(@FSamples[0], Channel);
    Result := 1;
  finally
    FAudioLock.Release;
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

function ProcAudio(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;
begin
  Result := 0;
  try
    if (Audio = nil) or (Audio^.Object_ = nil) or (Audio^.UserData = nil) then Exit;
    Result := TCoinSession(Audio^.UserData).AudioBlock(Audio);
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_CoinInsert audio: ' + E.Message));
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
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_AUDIO or FILTER_FLAG_INPUT
      or FILTER_FLAG_USERDATA, 'コイン投入演出', 'SYNC',
      'コイン投入演出 / SYNC_CoinInsert v1.0.0', ProcVideo, ProcAudio);
    RegisterCoinInsertParameters;
    GetPluginTable^.Func_Create := CreateSession;
    GetPluginTable^.Func_Destroy := DestroySession;
    TableReady := True;
  end;
  Result := GetPluginTable;
end;

end.
