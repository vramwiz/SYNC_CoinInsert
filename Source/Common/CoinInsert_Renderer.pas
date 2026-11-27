unit CoinInsert_Renderer;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// 投入口を原点とする透過 RGBA を生成する。オブジェクト変形は AviUtl2 が担当する。

interface

uses
  AviUtl2FilterTypes, CoinInsert_Timeline;

type
  TSideDescent = (sdSmooth, sdPause);
  TCoinView = record
    Scale, Distance: Double;
    ShowFrame: Boolean;
    SideDescent: TSideDescent;
  end;
  TCoinPixels = TArray<TPIXEL_RGBA>;

// オブジェクト内時刻（秒）の形状を呼出側所有の RGBA バッファへ書き込む。
// Width/Height は出力画素数。投入口の中心を画像中心に固定し、透明領域は A=0 にする。
procedure RenderCoinFrame(const View: TCoinView; const Timing: TCoinTiming;
  const Coins: TCoinList; Time: Double; var Pixels: TCoinPixels;
  out Width, Height: Integer);

implementation

uses
  System.Math, CoinInsert_Metal;

const
  MAX_COIN_RADIUS = 60.0;
  SLOT_HALF_WIDTH = 68.0;
  SIDE_CUT = 0.0;

type
  TVec3 = record
    X, Y, Z: Double;
  end;
  TCoinPose = record
    X, Y, Radius, DepthClip: Double;
    UAxis, VAxis, NAxis: TVec3;
  end;
  TSurface = (sfFace, sfEdge, sfHole);
  THit = record
    Material: TSurface;
    U, V, W, RayDepth: Double;
  end;

procedure PutUnder(var Target: TPIXEL_RGBA; const Color: TPIXEL_RGBA; Coverage: Double);
var
  Fore, Back, Total: Double;
begin
  if Target.A = 255 then Exit;
  if Target.A = 0 then
  begin
    Target := Color;
    Target.A := Round(Coverage * 255);
    Exit;
  end;
  Fore := Target.A;
  Back := (255 - Target.A) * Coverage;
  Total := Fore + Back;
  Target.R := Round((Target.R * Fore + Color.R * Back) / Total);
  Target.G := Round((Target.G * Fore + Color.G * Back) / Total);
  Target.B := Round((Target.B * Fore + Color.B * Back) / Total);
  Target.A := Round(Total);
end;

function RoundedBox(X, Y, HalfW, HalfH, Radius: Double): Double;
var
  DX, DY: Double;
begin
  DX := Abs(X) - HalfW + Radius;
  DY := Abs(Y) - HalfH + Radius;
  Result := Sqrt(Sqr(Max(DX, 0.0)) + Sqr(Max(DY, 0.0)))
    + Min(Max(DX, DY), 0.0) - Radius;
end;

procedure DrawSlot(var Pixels: TCoinPixels; Width, Height: Integer;
  Direction: TInsertDirection);
var
  HalfW, HalfH, OpeningW, OpeningH, Corner, CenterX, X, Y, Outer,
    Opening, Cover, Dark, Tone, Reflection: Double;
  Col, Row, CX, CY: Integer;
  Color: TPIXEL_RGBA;
begin
  CX := Width div 2;
  CY := Height div 2;
  case Direction of
    idSide:
      begin
        HalfW := 3.3;
        HalfH := 44;
        OpeningW := 1.3;
        OpeningH := 40;
        Corner := 1.1;
        CenterX := 2;
      end;
  else
    HalfW := 80;
    HalfH := 18;
    OpeningW := SLOT_HALF_WIDTH;
    OpeningH := 7.5;
    Corner := 3;
    CenterX := 0;
  end;
  for Row := CY - Ceil(HalfH) - 1 to CY + Ceil(HalfH) do
  begin
    Y := Row + 0.5 - CY;
    for Col := CX + Floor(CenterX - HalfW) - 1 to CX + Ceil(CenterX + HalfW) do
    begin
      X := Col + 0.5 - CX - CenterX;
      Outer := RoundedBox(X, Y, HalfW, HalfH, Corner);
      Cover := EnsureRange(0.5 - Outer, 0.0, 1.0);
      if Cover = 0 then Continue;
      Opening := RoundedBox(X, Y, OpeningW, OpeningH, Corner * 0.5);
      Reflection := 19 * Sin(X * 0.053 + Y * 0.18)
        + 35 * (1 - SmoothRange(0, 48, Abs(X + Y * 1.6 + 25)));
      Tone := 112 - 65 * Cos((Y / HalfH + 0.8) * 3.6)
        + Reflection + 3 * Sin(Y * 7.1 + X * 0.1);
      Tone := Lerp(Tone, 58 - 70 * Y / HalfH, 1 - SmoothRange(0, 1.8, -Outer));
      Tone := Tone + (57 + 43 * Y / HalfH) * (1 - SmoothRange(0.6, 2.8, Abs(Opening - 1.25)));
      Dark := 9 + 14 * SmoothRange(-OpeningH, OpeningH, Y)
        + 13 * (1 - SmoothRange(0.15, 1.5, Abs(Opening)));
      Tone := Lerp(Dark, Tone, SmoothRange(-0.6, 0.6, Opening));
      Color := PixelColor(Tone * 0.93, Tone, Tone * 1.10);
      PutUnder(Pixels[Row * Width + Col], Color, Cover);
    end;
  end;
end;

function SideStart(Radius: Double): Double; inline;
begin
  Result := -Max(155.0, Radius + 90.0);
end;

function SideHeight(StartY, Lift, Approach, Progress, Contact: Double;
  Descent: TSideDescent): Double;
var
  ApexApproach, ApexProgress, ApexY, Fall: Double;
begin
  Result := Lerp(StartY, 0.0, Approach) - Lift * Sin(Pi * Approach);
  if Descent = sdPause then Exit;

  // 従来の軌道の傾きがゼロになる位置まで、同じ上昇を使う。
  ApexApproach := ArcCos(-StartY / (Pi * Lift)) / Pi;
  if Approach <= ApexApproach then Exit;
  ApexY := Lerp(StartY, 0.0, ApexApproach) - Lift * Sin(Pi * ApexApproach);
  // SmoothRange の逆関数で頂点の時刻を求め、投入完了まで一続きで下降する。
  ApexProgress := Contact * (0.5 - Sin(ArcSin(1 - 2 * ApexApproach) / 3));
  Fall := (Progress - ApexProgress) / (1 - ApexProgress);
  Result := Lerp(ApexY, 0.0, Sqr(Fall) * (2 - Fall));
end;

procedure Orient(var Pose: TCoinPose; TiltX, TiltY, Spin: Double);
var
  SX, CX, SY, CY, SZ, CZ: Double;
begin
  SinCos(TiltX, SX, CX);
  SinCos(TiltY, SY, CY);
  SinCos(Spin, SZ, CZ);
  Pose.UAxis.X := CZ * CY;
  Pose.UAxis.Y := SZ * CY;
  Pose.UAxis.Z := -SY;
  Pose.VAxis.X := CZ * SY * SX - SZ * CX;
  Pose.VAxis.Y := SZ * SY * SX + CZ * CX;
  Pose.VAxis.Z := CY * SX;
  Pose.NAxis.X := CZ * SY * CX + SZ * SX;
  Pose.NAxis.Y := SZ * SY * CX - CZ * SX;
  Pose.NAxis.Z := CY * CX;
end;

function CoinPose(Kind: TCoinKind; Index: Integer; const View: TCoinView;
  Direction: TInsertDirection; Progress: Double): TCoinPose;
var
  A, B, C, Approach, Align, Through, Contact, SideTravel: Double;
begin
  Contact := ContactProgress(Direction);
  A := CoinVariation(Index, Kind, 11);
  B := CoinVariation(Index, Kind, 23);
  C := CoinVariation(Index, Kind, 37);
  Result.Radius := View.Scale * MAX_COIN_RADIUS * COIN_SPECS[Kind].Diameter
    / COIN_SPECS[ck500].Diameter;
  Result.DepthClip := -2;
  Approach := SmoothRange(0, Contact, Progress);
  Through := EnsureRange((Progress - Contact) / (1 - Contact), 0.0, 1.0);
  case Direction of
    idSide:
      begin
        SideTravel := Min(1.0, Progress / Contact);
        Result.X := Lerp(SideStart(Result.Radius), SIDE_CUT - Result.Radius,
          SideTravel * (0.70 + 0.30 * SideTravel)) + (Result.Radius * 2 + 2)
          * Through * (0.5 + Through * (1.5 - Through));
        Result.Y := SideHeight(9 + 5 * B, 13 + 6 * C, Approach, Progress,
          Contact, View.SideDescent);
        Align := SmoothRange(0.36, 0.97, Progress);
        Orient(Result, Lerp(0.20 + 0.22 * A, 0.04, Align),
          Lerp(0.08 + 0.27 * B + 0.13 * Sin(Pi * Progress), 0.025, Align),
          Lerp(0.29 * C + 0.60 * Approach, 0.13, Align));
      end;
  else
    Result.Radius := Lerp(Result.Radius, Min(SLOT_HALF_WIDTH - 3, Result.Radius * 0.90),
      SmoothRange(0.04, Contact, Progress));
    Result.X := (1 - Approach) * (7 + C * 11);
    Result.Y := Lerp(View.Distance, 11, Approach) - 20 * Through;
    Result.DepthClip := Lerp(-1.035, 1.035, Through);
    Align := SmoothRange(0.29, Contact + 0.06, Progress);
    Orient(Result, Lerp(0.24 + A * 0.18 + 0.22 * Approach, 1.47, Align),
      Lerp(0.16 * B + 0.15 * Sin(Progress * Pi), 0.0, Align),
      Lerp(0.27 * C + 0.22 * Approach, 0.0, Align));
  end;
end;

function TraceCoin(const Pose: TCoinPose; X, Y, HalfDepth, Hole: Double;
  out Hit: THit): Boolean;
var
  U, V, W, DZU, DZV, DZW, T, R2, AtU, AtV, Radial, Linear,
    D2, D, NearT, FarT, AtW: Double;
begin
  // 画面の光線を円柱の座標に移し、表面・外壁・穴の内壁を調べる。
  U := X * Pose.UAxis.X + Y * Pose.UAxis.Y;
  V := X * Pose.VAxis.X + Y * Pose.VAxis.Y;
  W := X * Pose.NAxis.X + Y * Pose.NAxis.Y;
  DZU := Pose.UAxis.Z;
  DZV := Pose.VAxis.Z;
  DZW := Pose.NAxis.Z;
  T := (HalfDepth - W) / DZW;
  AtU := U + T * DZU;
  AtV := V + T * DZV;
  R2 := Sqr(AtU) + Sqr(AtV);
  if (R2 <= 1) and (R2 >= Sqr(Hole)) then
  begin
    if T < Pose.DepthClip then Exit(False);
    Hit.Material := sfFace;
    Hit.U := AtU;
    Hit.V := AtV;
    Hit.W := HalfDepth;
    Hit.RayDepth := T;
    Exit(True);
  end;

  Result := False;
  Radial := Sqr(DZU) + Sqr(DZV);
  if Radial < 1E-12 then Exit;
  Linear := U * DZU + V * DZV;
  R2 := Sqr(U) + Sqr(V);
  D2 := Sqr(Linear) - Radial * (R2 - 1);
  if D2 < 0 then Exit;
  D := Sqrt(D2);
  NearT := (-Linear + D) / Radial;
  if NearT < Pose.DepthClip then Exit;
  AtW := W + NearT * DZW;
  if Abs(AtW) <= HalfDepth then
  begin
    Hit.Material := sfEdge;
    Hit.U := U + NearT * DZU;
    Hit.V := V + NearT * DZV;
    Hit.W := AtW;
    Hit.RayDepth := NearT;
    Exit(True);
  end;

  if Hole <= 0 then Exit;
  D2 := Sqr(Linear) - Radial * (R2 - Sqr(Hole));
  if D2 < 0 then Exit;
  FarT := (-Linear - Sqrt(D2)) / Radial;
  AtW := W + FarT * DZW;
  if (FarT < Pose.DepthClip) or (Abs(AtW) > HalfDepth) then Exit;
  Hit.Material := sfHole;
  Hit.U := U + FarT * DZU;
  Hit.V := V + FarT * DZV;
  Hit.W := AtW;
  Hit.RayDepth := FarT;
  Result := True;
end;

function Shade(Kind: TCoinKind; const Hit: THit; const Pose: TCoinPose;
  HalfDepth, FaceLight: Double): TPIXEL_RGBA;
var
  NX, NY, Light, Angle: Double;
begin
  if Hit.Material = sfFace then
    Exit(CoinFaceColor(Kind, Hit.U, Hit.V, FaceLight));
  Angle := ArcTan2(Hit.V, Hit.U);
  NX := Cos(Angle);
  NY := Sin(Angle);
  Light := -NX * (Pose.UAxis.X * 0.34 + Pose.UAxis.Y * 0.64)
    - NY * (Pose.VAxis.X * 0.34 + Pose.VAxis.Y * 0.64);
  Result := CoinEdgeColor(Kind, Angle, Hit.W / HalfDepth,
    Light, Hit.Material = sfHole);
end;

procedure DrawCoin(var Pixels: TCoinPixels; Width, Height: Integer; Kind: TCoinKind;
  const Pose: TCoinPose; Direction: TInsertDirection);
const
  OFFSETS: array[0..1] of Double = (0.25, 0.75);
var
  HalfDepth, Hole, ExtentX, ExtentY, FaceLight, X, Y, SampleX,
    SampleStep, Cut: Double;
  Col, Row, CX, CY, FirstCol, LastCol, SX, SY, Coverage, PixelIndex: Integer;
  Hit, Best: THit;
  Color: TPIXEL_RGBA;
begin
  CX := Width div 2;
  CY := Height div 2;
  HalfDepth := COIN_SPECS[Kind].Thickness / COIN_SPECS[Kind].Diameter;
  Hole := COIN_SPECS[Kind].Hole / COIN_SPECS[Kind].Diameter;
  ExtentX := Pose.Radius * (Sqrt(Sqr(Pose.UAxis.X) + Sqr(Pose.VAxis.X))
    + HalfDepth * Abs(Pose.NAxis.X));
  ExtentY := Pose.Radius * (Sqrt(Sqr(Pose.UAxis.Y) + Sqr(Pose.VAxis.Y))
    + HalfDepth * Abs(Pose.NAxis.Y));
  FirstCol := Max(0, CX + Floor(Pose.X - ExtentX));
  LastCol := Min(Width - 1, CX + Ceil(Pose.X + ExtentX));
  Cut := Width;
  if Direction = idSide then
  begin
    Cut := CX + SIDE_CUT;
    LastCol := Min(LastCol, Ceil(Cut) - 1);
  end;
  FaceLight := 0.82 + 0.23 * Pose.NAxis.Z - 0.12 * Pose.NAxis.Y
    - 0.12 * Pose.NAxis.X;
  SampleStep := 1 / Pose.Radius;
  for Row := Max(0, CY + Floor(Pose.Y - ExtentY)) to
    Min(Height - 1, CY + Ceil(Pose.Y + ExtentY)) do
  begin
    Y := (Row - CY - Pose.Y) * SampleStep;
    for Col := FirstCol to LastCol do
    begin
      PixelIndex := Row * Width + Col;
      if Pixels[PixelIndex].A = 255 then Continue;
      X := (Col - CX - Pose.X) * SampleStep;
      Coverage := 0;
      Best.RayDepth := -MaxDouble;
      for SY := 0 to 1 do
        for SX := 0 to 1 do
        begin
          SampleX := Col + OFFSETS[SX];
          if (SampleX < Cut) and TraceCoin(Pose, X + OFFSETS[SX] * SampleStep,
            Y + OFFSETS[SY] * SampleStep, HalfDepth, Hole, Hit) then
          begin
            Inc(Coverage);
            if Hit.RayDepth > Best.RayDepth then Best := Hit;
          end;
        end;
      if Coverage = 0 then Continue;
      if Coverage = 4 then
        if TraceCoin(Pose, X + 0.5 * SampleStep, Y + 0.5 * SampleStep,
          HalfDepth, Hole, Hit) then Best := Hit;
      Color := Shade(Kind, Best, Pose, HalfDepth, FaceLight);
      PutUnder(Pixels[PixelIndex], Color, Coverage * 0.25);
    end;
  end;
end;

procedure RenderCoinFrame(const View: TCoinView; const Timing: TCoinTiming;
  const Coins: TCoinList; Time: Double; var Pixels: TCoinPixels;
  out Width, Height: Integer);
var
  MaxRadius, XBound, YBound, Progress: Double;
  First, Last, Index: Integer;
  Kind: TCoinKind;
begin
  MaxRadius := View.Scale * MAX_COIN_RADIUS;
  XBound := Max(82.0, MaxRadius * 1.05 + 20.0);
  YBound := Max(48.0, MaxRadius * 1.05 + 22.0);
  case Timing.Direction of
    idSide: XBound := -SideStart(MaxRadius) + MaxRadius * 1.05 + 4;
  else
    YBound := Max(YBound, View.Distance + MaxRadius * 1.05 + 4);
  end;
  Width := Ceil(XBound) * 2;
  Height := Ceil(YBound) * 2;
  SetLength(Pixels, Width * Height);
  FillChar(Pixels[0], Length(Pixels) * SizeOf(TPIXEL_RGBA), 0);
  if not (IsNan(Time) or IsInfinite(Time)) then
  begin
    CoinTimeRange(Time - Timing.Duration, Time, Timing.StartDelay,
      Timing.Interval, Length(Coins), First, Last);
    // 手前から描くことで、重なった硬貨の不透明な画素の計算は省ける。
    for Index := Last downto First do
    begin
      Progress := (Time - CoinStart(Timing, Index)) / Timing.Duration;
      if (Progress < -1E-10) or (Progress >= 1 - 1E-10) then Continue;
      Kind := Coins[Index];
      DrawCoin(Pixels, Width, Height, Kind,
        CoinPose(Kind, Index, View, Timing.Direction, Max(0.0, Progress)), Timing.Direction);
    end;
  end;
  if View.ShowFrame then DrawSlot(Pixels, Width, Height, Timing.Direction);
end;

end.
