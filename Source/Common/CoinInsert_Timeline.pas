unit CoinInsert_Timeline;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// 硬貨の寸法と映像・音声が共有するオブジェクト内の投入時刻。

interface

type
  TCoinKind = (ck1, ck5, ck10, ck50, ck100, ck500);
  TCoinList = TArray<TCoinKind>;
  TInsertDirection = (idFront, idSide);

  TCoinSpec = record
    Diameter, Thickness, Hole: Double; // mm。厚みと穴径は描画用の近似値。
    Red, Green, Blue: Byte;
    Ridges: Integer; // 0 は平滑な側面
  end;

  TCoinTiming = record
    Direction: TInsertDirection;
    StartDelay, Duration, Interval: Double;
  end;

const
  COIN_SPECS: array[TCoinKind] of TCoinSpec = (
    (Diameter:20.0; Thickness:1.5; Hole:0; Red:188; Green:200; Blue:207; Ridges:0),
    (Diameter:22.0; Thickness:1.5; Hole:5.0; Red:198; Green:158; Blue:74; Ridges:0),
    (Diameter:23.5; Thickness:1.5; Hole:0; Red:198; Green:119; Blue:77; Ridges:0),
    (Diameter:21.0; Thickness:1.7; Hole:4.0; Red:162; Green:176; Blue:185; Ridges:104),
    (Diameter:22.6; Thickness:1.7; Hole:0; Red:175; Green:188; Blue:197; Ridges:110),
    (Diameter:26.5; Thickness:1.8; Hole:0; Red:187; Green:158; Blue:98; Ridges:134)
  );

// DLL 所有の動的配列を返す。空欄・未対応額面を除外して順序と重複を保つ。
function ParseCoinList(const Spec: string): TCoinList;
// 0 始まりの投入順から、オブジェクト開始を基準とした時刻（秒）を求める。
function CoinStart(const Timing: TCoinTiming; Index: Integer): Double;
// 投入口との接触を示す、投入開始から完了までの進捗（0～1）。
function ContactProgress(Direction: TInsertDirection): Double;
// 投入順と方向に基づく接触時刻（秒）。効果音の発音時刻と一致する。
function CoinContact(const Timing: TCoinTiming; Index: Integer): Double;
// 秒単位の閉区間に含まれるイベントの最初と最後を返す。Interval は正。空なら Last < First。
procedure CoinTimeRange(WindowStart, WindowEnd, FirstTime, Interval: Double;
  Count: Integer; out First, Last: Integer);
// 投入順・額面・用途別の Salt から、再読込でも同じ -1～1 のばらつきを返す。
function CoinVariation(Index: Integer; Kind: TCoinKind; Salt: Cardinal): Double;
// Lo から Hi の範囲を両端で速度ゼロの 0～1 に変換する。Lo < Hi。
function SmoothRange(Lo, Hi, Value: Double): Double;
// T=0 で A、T=1 で B となる線形補間。
function Lerp(A, B, T: Double): Double; inline;

implementation

uses
  System.SysUtils, System.Math;

function ParseCoinList(const Spec: string): TCoinList;
var
  Token: string;
  Start, I, J, Value, Count: Integer;
  Kind: TCoinKind;
begin
  Result := nil;
  if Spec = '' then Exit;
  SetLength(Result, 1);
  Start := 1;
  Count := 0;
  for I := 1 to Length(Spec) + 1 do
  begin
    if (I <= Length(Spec)) and (Spec[I] <> ',') and (Spec[I] <> '，') then Continue;
    Token := Trim(Copy(Spec, Start, I - Start));
    Start := I + 1;
    if (Length(Token) = 0) or (Length(Token) > 3) then Continue;
    Value := 0;
    for J := 1 to Length(Token) do
      case Token[J] of
        '0'..'9': Value := Value * 10 + Ord(Token[J]) - Ord('0');
        '０'..'９': Value := Value * 10 + Ord(Token[J]) - Ord('０');
      else
        Value := -1;
        Break;
      end;
    case Value of
      1: Kind := ck1;
      5: Kind := ck5;
      10: Kind := ck10;
      50: Kind := ck50;
      100: Kind := ck100;
      500: Kind := ck500;
    else
      Continue;
    end;
    if Count = Length(Result) then SetLength(Result, Count * 2);
    Result[Count] := Kind;
    Inc(Count);
  end;
  SetLength(Result, Count);
end;

function CoinStart(const Timing: TCoinTiming; Index: Integer): Double;
begin
  Result := Timing.StartDelay + Index * Timing.Interval;
end;

function ContactProgress(Direction: TInsertDirection): Double;
begin
  case Direction of
    idSide: Result := 0.68;
  else
    Result := 0.74;
  end;
end;

function CoinContact(const Timing: TCoinTiming; Index: Integer): Double;
begin
  Result := CoinStart(Timing, Index) + Timing.Duration * ContactProgress(Timing.Direction);
end;

procedure CoinTimeRange(WindowStart, WindowEnd, FirstTime, Interval: Double;
  Count: Integer; out First, Last: Integer);
var
  FinalTime: Double;
begin
  First := 0;
  Last := -1;
  if Count <= 0 then Exit;
  FinalTime := FirstTime + (Count - 1) * Interval;
  if (WindowEnd < FirstTime) or (WindowStart > FinalTime) then Exit;
  First := Ceil(Max(0.0, (WindowStart - FirstTime) / Interval - 1E-8));
  Last := Min(Count - 1, Floor((Min(WindowEnd, FinalTime) - FirstTime) / Interval + 1E-8));
end;

function CoinVariation(Index: Integer; Kind: TCoinKind; Salt: Cardinal): Double;
var
  Hash: Cardinal;
begin
  Hash := Cardinal((UInt64(Index) * 1664525 + UInt64(Ord(Kind)) * 1013904223
    + UInt64(Salt) * 2246822519) and $FFFFFFFF);
  Hash := Hash xor (Hash shr 16);
  Hash := Cardinal((UInt64(Hash) * $85EBCA6B) and $FFFFFFFF);
  Hash := Hash xor (Hash shr 13);
  Result := (Hash and $FFFF) / 32767.5 - 1;
end;

function Lerp(A, B, T: Double): Double;
begin
  Result := A + (B - A) * T;
end;

function SmoothRange(Lo, Hi, Value: Double): Double;
var
  T: Double;
begin
  T := EnsureRange((Value - Lo) / (Hi - Lo), 0.0, 1.0);
  Result := T * T * (3 - 2 * T);
end;

end.
