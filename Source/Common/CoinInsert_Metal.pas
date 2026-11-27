unit CoinInsert_Metal;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// 硬貨の地金・縁刻・浮き彫りの表面色。金額面の模様を登録時に一度生成する。

interface

uses
  AviUtl2FilterTypes, CoinInsert_Timeline;

// DLL が保持する読み取り専用テクスチャを生成する。登録完了前に呼ぶ。
procedure PrepareCoinFaces;
// U/V は半径を 1 とした面座標。Light は現在の傾きによる明暗。
function CoinFaceColor(Kind: TCoinKind; U, V, Light: Double): TPIXEL_RGBA;
// Angle は硬貨の外周角。Depth は厚みの中心が 0 で、両端が ±1。
function CoinEdgeColor(Kind: TCoinKind; Angle, Depth, Light: Double;
  InsideHole: Boolean): TPIXEL_RGBA;
function PixelColor(R, G, B: Double): TPIXEL_RGBA;

implementation

uses
  System.Math;

const
  FACE_SIZE = 256;
  AMOUNTS: array[TCoinKind] of string = ('1', '5', '10', '50', '100', '500');

type
  TCoinTexture = array[0..FACE_SIZE - 1, 0..FACE_SIZE - 1] of TPIXEL_RGBA;

var
  Faces: array[TCoinKind] of TCoinTexture;

function PixelColor(R, G, B: Double): TPIXEL_RGBA;
begin
  Result.R := Round(EnsureRange(R, 0.0, 255.0));
  Result.G := Round(EnsureRange(G, 0.0, 255.0));
  Result.B := Round(EnsureRange(B, 0.0, 255.0));
  Result.A := 255;
end;

function SegmentDistance(X, Y, AX, AY, BX, BY: Double): Double;
var
  T, DX, DY: Double;
begin
  DX := BX - AX;
  DY := BY - AY;
  T := EnsureRange(((X - AX) * DX + (Y - AY) * DY) / (Sqr(DX) + Sqr(DY)), 0.0, 1.0);
  Result := Sqrt(Sqr(X - (AX + T * DX)) + Sqr(Y - (AY + T * DY)));
end;

function DigitDistance(Digit: Char; X, Y: Double): Double;
var
  Bowl: Double;
begin
  case Digit of
    '0':
      Result := Abs(Sqrt(Sqr(X / 0.29) + Sqr(Y / 0.41)) - 1) * 0.30;
    '1':
      begin
        Result := SegmentDistance(X, Y, -0.19, -0.25, 0.04, -0.41);
        Result := Min(Result, SegmentDistance(X, Y, 0.04, -0.41, 0.04, 0.40));
        Result := Min(Result, SegmentDistance(X, Y, -0.17, 0.40, 0.24, 0.40));
      end;
  else
    Bowl := Abs(Sqrt(Sqr(X / 0.29) + Sqr((Y - 0.158) / 0.251)) - 1) * 0.26;
    if (X < -0.13) and (Y < 0.30) then
      Bowl := Sqrt(Sqr(X + 0.235) + Sqr(Y - 0.306));
    Result := Min(Bowl, SegmentDistance(X, Y, -0.25, -0.411, 0.244, -0.411));
    Result := Min(Result, SegmentDistance(X, Y, -0.25, -0.411, -0.278, -0.075));
    Result := Min(Result, SegmentDistance(X, Y, -0.278, -0.075, -0.016, -0.093));
  end;
end;

function AmountMask(const Amount: string; U, V, CenterY, Size: Double): Double;
const
  ADVANCE = 0.82;
var
  X, Y: Double;
  Index: Integer;
begin
  X := U / Size + (Length(Amount) - 1) * ADVANCE / 2;
  Y := (V - CenterY) / Size;
  Index := Round(X / ADVANCE) + 1;
  Result := 0;
  if (Index >= 1) and (Index <= Length(Amount)) then
    Result := 1 - SmoothRange(0.071, 0.092,
      DigitDistance(Amount[Index], X - (Index - 1) * ADVANCE, Y));
end;

function Ring(Radius, AtRadius, Width: Double): Double; inline;
begin
  Result := 1 - SmoothRange(Width * 0.4, Width, Abs(Radius - AtRadius));
end;

function BakedColor(Kind: TCoinKind; U, V: Double; X, Y: Integer): TPIXEL_RGBA;
var
  Spec: TCoinSpec;
  R, A, Light, Sweep, AmountSize, AmountY, Raised, Lit, Shade, Dots,
    Leaves, HoleRadius, Join, BaseR, BaseG, BaseB, Grain: Double;
  Amount: string;
begin
  Spec := COIN_SPECS[Kind];
  R := Sqrt(Sqr(U) + Sqr(V));
  if R > 1.04 then Exit(PixelColor(0, 0, 0));
  A := ArcTan2(V, U);
  Grain := (((X * 127 + Y * 41) xor (X * Y * 17)) and 31) / 31 - 0.5;
  Sweep := 1 - SmoothRange(0.01, 0.48, Abs(U * 0.62 + V + 0.32));
  Light := 0.86 - 0.19 * V - 0.12 * U + 0.27 * Sweep
    + 0.023 * Sin(R * 173 + 2 * Sin(A * 9)) + 0.040 * Grain;
  Light := Light + 0.18 * Ring(R, 0.946, 0.024)
    - 0.22 * Ring(R, 0.907, 0.019) + 0.09 * Ring(R, 0.878, 0.019);
  Dots := Sqr(Sqr(0.5 + 0.5 * Cos(A * 68)));
  Light := Light + 0.14 * Dots * Ring(R, 0.846, 0.022)
    - 0.07 * Dots * Ring(R, 0.826, 0.014);
  BaseR := Spec.Red;
  BaseG := Spec.Green;
  BaseB := Spec.Blue;
  if Kind = ck500 then
  begin
    Join := 1 - SmoothRange(0.712, 0.725, R);
    BaseR := Lerp(BaseR, 176, Join);
    BaseG := Lerp(BaseG, 182, Join);
    BaseB := Lerp(BaseB, 178, Join);
    Light := Light - 0.14 * Ring(R, 0.721, 0.013) + 0.13 * Ring(R, 0.700, 0.015);
  end;

  Amount := AMOUNTS[Kind];
  AmountSize := 0.69;
  AmountY := -0.035;
  if Length(Amount) = 3 then AmountSize := 0.55;
  if Spec.Hole > 0 then
  begin
    HoleRadius := Spec.Hole / Spec.Diameter;
    AmountY := -0.48;
    AmountSize := 0.39;
    Light := Light + (0.19 + 0.12 * Sin(A)) * Ring(R, HoleRadius + 0.028, 0.028);
  end;
  Raised := AmountMask(Amount, U, V, AmountY, AmountSize);
  Lit := AmountMask(Amount, U + 0.013, V + 0.016, AmountY, AmountSize);
  Shade := AmountMask(Amount, U - 0.016, V - 0.019, AmountY, AmountSize);
  Light := Light + 0.15 * Raised + 0.39 * Max(0.0, Lit - Raised)
    - 0.35 * Max(0.0, Shade - Raised);
  // 下側の枝と細い刻線を浅いレリーフとして添える。
  Leaves := Sqr(Sqr(0.5 + 0.5 * Cos(A * 23 + R * 41)));
  Leaves := Leaves * SmoothRange(0.28, 0.82, V) * SmoothRange(0.10, 0.32, Abs(U));
  Light := Light + 0.17 * Leaves * Ring(R, 0.65, 0.105)
    + 0.07 * Ring(R, 0.61, 0.02) * SmoothRange(0.43, 0.63, V);
  Result := PixelColor(BaseR * Light, BaseG * Light, BaseB * Light);
end;

procedure PrepareCoinFaces;
var
  Kind: TCoinKind;
  X, Y: Integer;
begin
  for Kind := Low(TCoinKind) to High(TCoinKind) do
    for Y := 0 to FACE_SIZE - 1 do
      for X := 0 to FACE_SIZE - 1 do
        Faces[Kind][Y, X] := BakedColor(Kind,
          X * (2 / (FACE_SIZE - 1)) - 1, Y * (2 / (FACE_SIZE - 1)) - 1, X, Y);
end;

function CoinFaceColor(Kind: TCoinKind; U, V, Light: Double): TPIXEL_RGBA;
var
  X, Y: Integer;
  Texel: TPIXEL_RGBA;
begin
  X := Round((U + 1) * ((FACE_SIZE - 1) * 0.5));
  Y := Round((V + 1) * ((FACE_SIZE - 1) * 0.5));
  Texel := Faces[Kind][Y, X];
  Result := PixelColor(Texel.R * Light, Texel.G * Light, Texel.B * Light);
end;

function CoinEdgeColor(Kind: TCoinKind; Angle, Depth, Light: Double;
  InsideHole: Boolean): TPIXEL_RGBA;
var
  Spec: TCoinSpec;
  Rib, Tone: Double;
begin
  Spec := COIN_SPECS[Kind];
  Tone := 0.63 + 0.37 * Light + 0.38 * Sqr(Sqr(Abs(Depth)));
  if InsideHole then
    Tone := Tone * 0.65
  else if Spec.Ridges > 0 then
  begin
    if Kind = ck500 then Angle := Angle + Depth * 0.012 + 0.021 * Sin(Angle * 8);
    Rib := Cos(Angle * Spec.Ridges);
    Tone := Tone + 0.18 * Rib - 0.10 * Sqr(Rib);
  end
  else
    Tone := Tone + 0.06 * Cos(Depth * 24 + Angle * 5);
  Result := PixelColor(Spec.Red * Tone, Spec.Green * Tone, Spec.Blue * Tone);
end;

end.
