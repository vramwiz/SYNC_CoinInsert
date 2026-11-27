unit CoinInsert_Audio;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// 投入口との接触、内部での跳ね返りと落下を短い減衰波形で合成する。

interface

uses
  CoinInsert_Timeline;

type
  TCoinSamples = TArray<Single>;

// オブジェクト先頭からのサンプル位置を受け、呼出側のモノラル PCM バッファを更新する。
// Volume は 0～1。描画と音声の順序やブロックサイズに依存しない。
procedure RenderCoinAudio(const Timing: TCoinTiming; const Coins: TCoinList;
  SampleIndex: Int64; Count, Rate: Integer; Volume: Double; var Samples: TCoinSamples);

implementation

uses
  System.Math;

const
  SOUND_TAIL = 0.25;

function Ring(T, Frequency, Decay, Phase: Double): Double; inline;
begin
  Result := Exp(-T * Decay) * Sin(2 * Pi * Frequency * T + Phase);
end;

function CoinSound(T, Pitch, Drop, Nyquist: Double): Double;
var
  BounceTime, DropTime, Tap: Double;
begin
  Tap := 0.39 * Ring(T, Pitch * 1.01, 44, 0)
    + 0.23 * Ring(T, Min(Pitch * 1.59, Nyquist), 68, 0.7)
    + 0.16 * Ring(T, Min(Pitch * 2.37, Nyquist), 159, 0.4);
  Result := Tap * Min(1.0, T * 3200);
  BounceTime := T - Drop * 0.50;
  if BounceTime > 0 then
    Result := Result + Min(1.0, BounceTime * 2200) *
      (0.15 * Ring(BounceTime, Pitch * 0.84, 77, 0)
      + 0.085 * Ring(BounceTime, Min(Pitch * 1.92, Nyquist), 145, 0.8));
  DropTime := T - Drop;
  if DropTime > 0 then
    Result := Result + Min(1.0, DropTime * 1900) *
      (0.21 * Ring(DropTime, Pitch * 0.30, 43, 0)
      + 0.13 * Ring(DropTime, Pitch * 0.53, 70, 0.5)
      + 0.09 * Ring(DropTime, Pitch * 1.26, 147, 1.2));
  Result := Result * (1 - SmoothRange(0.20, SOUND_TAIL, T));
end;

procedure RenderCoinAudio(const Timing: TCoinTiming; const Coins: TCoinList;
  SampleIndex: Int64; Count, Rate: Integer; Volume: Double; var Samples: TCoinSamples);
var
  StartTime, FinishTime, Contact, Age, Pitch, Drop, Nyquist, SamplePeriod: Double;
  First, Last, Index, FromSample, ToSample, I: Integer;
  Kind: TCoinKind;
begin
  SetLength(Samples, Count);
  if Count = 0 then Exit;
  FillChar(Samples[0], Count * SizeOf(Single), 0);
  if (Volume <= 0) or (Length(Coins) = 0) then Exit;
  SamplePeriod := 1 / Rate;
  StartTime := SampleIndex * SamplePeriod;
  FinishTime := StartTime + (Count - 1) * SamplePeriod;
  CoinTimeRange(StartTime - SOUND_TAIL, FinishTime, CoinContact(Timing, 0),
    Timing.Interval, Length(Coins), First, Last);
  if First > Last then Exit;
  Nyquist := Rate * 0.44;
  for Index := First to Last do
  begin
    Contact := CoinContact(Timing, Index);
    FromSample := Max(0, Ceil((Contact - StartTime) * Rate));
    ToSample := Min(Count - 1, Floor((Contact + SOUND_TAIL - StartTime) * Rate));
    Kind := Coins[Index];
    Pitch := (1530 + (23.5 - COIN_SPECS[Kind].Diameter) * 125)
      * (1 + 0.07 * CoinVariation(Index, Kind, 71));
    Drop := 0.074 + 0.012 * CoinVariation(Index, Kind, 91);
    for I := FromSample to ToSample do
    begin
      Age := Max(0.0, (SampleIndex + I) * SamplePeriod - Contact);
      Samples[I] := Samples[I] + CoinSound(Age, Pitch, Drop, Nyquist);
    end;
  end;
  for I := 0 to Count - 1 do
    Samples[I] := EnsureRange(Samples[I], -1.0, 1.0) * Volume;
end;

end.
