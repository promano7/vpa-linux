{ T7.4 - via A, PRIMER INTENTO: Line/SetLineStyle/SetWriteMode escritos a
  partir de la semantica documentada de BGI, sin mirar VENDOR/graph.inc.
  Framebuffer propio de 8 bits; la presentacion por SDL3 ya la cubre T7.2. }
unit viaa_bgi_intento1;
{$mode objfpc}
interface
const
  SolidLn = 0; DottedLn = 1; CenterLn = 2; DashedLn = 3; UserBitLn = 4;
  NormWidth = 1; ThickWidth = 3;
  NormalPut = 0; XORPut = 1;
var
  FB: array[0..479, 0..639] of Byte;
procedure SetColor(c: Word);
procedure SetLineStyle(style, pattern, thick: Word);
procedure SetWriteMode(m: Integer);
procedure SetViewPort(x1, y1, x2, y2: Integer; clip: Boolean);
procedure Line(x1, y1, x2, y2: Integer);
implementation
var
  Col: Byte = 15; Pat: Word = $FFFF; Thick: Word = 1; Mode: Integer = 0;
  VX1: Integer = 0; VY1: Integer = 0; VX2: Integer = 639; VY2: Integer = 479;
procedure SetColor(c: Word); begin Col := c; end;
procedure SetWriteMode(m: Integer); begin Mode := m; end;
procedure SetLineStyle(style, pattern, thick: Word);
begin
  case style of
    SolidLn: Pat := $FFFF; DottedLn: Pat := $CCCC; CenterLn: Pat := $FC78;
    DashedLn: Pat := $F8F8; UserBitLn: Pat := pattern;
  end;
  viaa_bgi_intento1.Thick := thick;
end;
procedure SetViewPort(x1, y1, x2, y2: Integer; clip: Boolean);
begin VX1 := x1; VY1 := y1; VX2 := x2; VY2 := y2; end;
procedure Plot(x, y: Integer);
begin
  x := x + VX1; y := y + VY1;
  if (x < VX1) or (x > VX2) or (y < VY1) or (y > VY2) then exit;
  if Mode = XORPut then FB[y, x] := FB[y, x] xor Col else FB[y, x] := Col;
end;
procedure Line(x1, y1, x2, y2: Integer);
var
  dx, dy, sx, sy, err, e2, i, k: Integer;
begin
  dx := Abs(x2 - x1); dy := Abs(y2 - y1);
  if x1 < x2 then sx := 1 else sx := -1;
  if y1 < y2 then sy := 1 else sy := -1;
  err := dx - dy; i := 0;
  repeat
    if ((Pat shl (i and 15)) and $8000) <> 0 then
      if Thick = 1 then Plot(x1, y1)
      else for k := -1 to 1 do
        if dx >= dy then Plot(x1, y1 + k) else Plot(x1 + k, y1);
    if (x1 = x2) and (y1 = y2) then break;
    e2 := 2 * err;
    if e2 > -dy then begin err := err - dy; x1 := x1 + sx; end;
    if e2 < dx then begin err := err + dx; y1 := y1 + sy; end;
    Inc(i);
  until False;
end;
end.
