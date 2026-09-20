{ T7.4 - via A, SEGUNDO INTENTO: corregido tras leer VENDOR/graph.inc y
  clip.inc. El primero (viaa_bgi_intento1.pas, escrito solo con la semantica
  documentada de BGI) daba 10054 pixeles distintos. Lo que hubo que copiar:
    a) ptcgraph recorta los EXTREMOS con Cohen-Sutherland (division entera
       truncada) y luego traza desde el extremo recortado: cambian la
       pendiente efectiva y la fase del patron respecto a recortar por pixel;
    b) en lineas horizontales y verticales con patron, la fase sale de la
       coordenada ABSOLUTA de pantalla (x and 15), no de la distancia al
       origen, y los extremos se ordenan antes;
    c) el grosor se recorta por pixel aunque el eje ya este recortado. }
unit viaa_bgi;
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
  viaa_bgi.Thick := thick;
end;
procedure SetViewPort(x1, y1, x2, y2: Integer; clip: Boolean);
begin VX1 := x1; VY1 := y1; VX2 := x2; VY2 := y2; end;
function Clipped(var x1, y1, x2, y2: Integer): Boolean;
const L = 1; R = 2; B = 4; T = 8;
var c1, c2, c, nx, ny: Integer;
  function Oc(x, y: Integer): Integer;
  begin
    Oc := 0;
    if x < VX1 then Oc := L else if x > VX2 then Oc := R;
    if y > VY2 then Oc := Oc or B else if y < VY1 then Oc := Oc or T;
  end;
begin
  c1 := Oc(x1, y1); c2 := Oc(x2, y2);
  repeat
    if (c1 = 0) and (c2 = 0) then exit(False);
    if (c1 and c2) <> 0 then exit(True);
    if c1 = 0 then c := c2 else c := c1;
    if (c and L) <> 0 then begin ny := y1 + ((y2-y1)*(VX1-x1)) div (x2-x1); nx := VX1; end
    else if (c and R) <> 0 then begin ny := y1 + ((y2-y1)*(VX2-x1)) div (x2-x1); nx := VX2; end
    else if (c and B) <> 0 then begin nx := x1 + ((x2-x1)*(VY2-y1)) div (y2-y1); ny := VY2; end
    else begin nx := x1 + ((x2-x1)*(VY1-y1)) div (y2-y1); ny := VY1; end;
    if c = c1 then begin x1 := nx; y1 := ny; c1 := Oc(x1, y1); end
    else begin x2 := nx; y2 := ny; c2 := Oc(x2, y2); end;
  until False;
end;
procedure PlotAbs(x, y: Integer);
begin
  if (x < VX1) or (x > VX2) or (y < VY1) or (y > VY2) then exit;
  if Mode = XORPut then FB[y, x] := FB[y, x] xor Col else FB[y, x] := Col;
end;
function Bit(i: Integer): Boolean;
begin Bit := ((Pat shl (i and 15)) and $8000) <> 0; end;
procedure Line(x1, y1, x2, y2: Integer);
var
  dx, dy, d, d1, d2, xi1, xi2, yi1, yi2, i, k, n, t: Integer;
begin
  x1 := x1 + VX1; x2 := x2 + VX1; y1 := y1 + VY1; y2 := y2 + VY1;
  if Clipped(x1, y1, x2, y2) then exit;
  if y1 = y2 then
  begin
    if x1 >= x2 then begin t := x1; x1 := x2; x2 := t; end;
    for k := -1 to 1 do
      if (k = 0) or (Thick <> 1) then
        for i := x1 to x2 do if Bit(i) then PlotAbs(i, y1 + k);
    exit;
  end;
  if x1 = x2 then
  begin
    if y1 >= y2 then begin t := y1; y1 := y2; y2 := t; end;
    for k := -1 to 1 do
      if (k = 0) or (Thick <> 1) then
        for i := y1 to y2 do if Bit(i) then PlotAbs(x1 + k, i);
    exit;
  end;
  dx := Abs(x2 - x1); dy := Abs(y2 - y1);
  if dx >= dy then
  begin n := dx; d := 2*dy - dx; d1 := 2*dy; d2 := 2*(dy-dx); xi1 := 1; xi2 := 1; yi1 := 0; yi2 := 1; end
  else
  begin n := dy; d := 2*dx - dy; d1 := 2*dx; d2 := 2*(dx-dy); xi1 := 0; xi2 := 1; yi1 := 1; yi2 := 1; end;
  if x1 > x2 then begin xi1 := -xi1; xi2 := -xi2; end;
  if y1 > y2 then begin yi1 := -yi1; yi2 := -yi2; end;
  for i := 0 to n do
  begin
    if Bit(i) then
      if Thick = 1 then PlotAbs(x1, y1)
      else for k := -1 to 1 do
        if dx >= dy then PlotAbs(x1, y1 + k) else PlotAbs(x1 + k, y1);
    if d < 0 then begin d := d + d1; x1 := x1 + xi1; y1 := y1 + yi1; end
    else begin d := d + d2; x1 := x1 + xi2; y1 := y1 + yi2; end;
  end;
end;
end.
