unit CoinInsert_Parameters;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// SDK 設定項目を宣言し、コールバック中の値を用いて処理設定を構成する。

interface

uses
  CoinInsert_Timeline, CoinInsert_Renderer;

// DLL が所有する設定項目に初期値を設定し、SDK のテーブルへアドレスを登録する。
procedure RegisterCoinInsertParameters;
// コールバック中の文字列をコピーして返し、ホスト所有のポインターを残さない。
function ReadCoinSpec: string;
// 映像と音声で共有する方向・時間設定（秒）をコピーする。
function ReadCoinTiming: TCoinTiming;
// 硬貨の拡大率（倍率）、距離（画素）、表示と下降の設定をコピーする。
function ReadCoinView: TCoinView;
// 効果音量を倍率 0～1 に変換する。
function ReadCoinVolume: Double;

implementation

uses
  System.Math, AviUtl2FilterTypes, PluginFilterTable;

const
  DEFAULT_COINS = '100,50,10';
  DIRECTION_CHOICES: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '正面'; Value: Ord(idFront)),
    (Name: '横'; Value: Ord(idSide)),
    (Name: nil; Value: 0));
  SIDE_DESCENT_CHOICES: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'スムーズ'; Value: Ord(sdSmooth)),
    (Name: '一時停止'; Value: Ord(sdPause)),
    (Name: nil; Value: 0));

var
  Direction, SideDescent: TFILTER_ITEM_SELECT;
  CoinSpec: TFILTER_ITEM_STRING;
  CoinScale, InsertDistance, StartDelay, InsertDuration, InsertInterval,
    Volume: TFILTER_ITEM_TRACK;
  ShowFrame: TFILTER_ITEM_CHECK;

procedure RegisterCoinInsertParameters;
begin
  AddSelect(Direction, '投入方向', Ord(idFront), @DIRECTION_CHOICES[0]);
  AddString(CoinSpec, 'コイン指定', DEFAULT_COINS);
  AddTrack(CoinScale, 'コイン拡大率', 100, 10, 300, 1);
  AddTrack(InsertDistance, '投入距離', 100, 0, 300, 1);
  AddCheck(ShowFrame, '金属枠表示', 1);
  AddTrack(StartDelay, '投入開始までの時間', 0.50, 0, 60, 0.01);
  AddTrack(InsertDuration, '1枚あたりの投入時間', 0.50, 0.01, 10, 0.01);
  AddTrack(InsertInterval, '投入間隔', 0.70, 0.01, 60, 0.01);
  AddTrack(Volume, '効果音量', 40.00, 0, 100, 0.01);
  AddSelect(SideDescent, '横投入の下降', Ord(sdSmooth), @SIDE_DESCENT_CHOICES[0]);
end;

function TrackValue(const Track: TFILTER_ITEM_TRACK; Default: Double): Double;
var
  Value: Double;
begin
  Value := Track.Value;
  if IsNan(Value) or IsInfinite(Value) then Exit(Default);
  Result := EnsureRange(Value, Track.S, Track.E);
end;

function ReadCoinSpec: string;
begin
  Result := CoinSpec.Value;
end;

function ReadCoinTiming: TCoinTiming;
begin
  case Direction.Value of
    Ord(idSide): Result.Direction := idSide;
  else
    Result.Direction := idFront;
  end;
  Result.StartDelay := TrackValue(StartDelay, 0.50);
  Result.Duration := TrackValue(InsertDuration, 0.50);
  Result.Interval := TrackValue(InsertInterval, 0.70);
end;

function ReadCoinView: TCoinView;
begin
  Result.Scale := TrackValue(CoinScale, 100) / 100;
  Result.Distance := TrackValue(InsertDistance, 100);
  Result.ShowFrame := ShowFrame.Value <> 0;
  case SideDescent.Value of
    Ord(sdPause): Result.SideDescent := sdPause;
  else
    Result.SideDescent := sdSmooth;
  end;
end;

function ReadCoinVolume: Double;
begin
  Result := TrackValue(Volume, 40) / 100;
end;

end.
