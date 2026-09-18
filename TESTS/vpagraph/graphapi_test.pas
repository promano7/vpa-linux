{ graphapi_test - Fase 6 de WAYLAND.md, T6.2 y ensayo general de T6.5.

  Un programa en modo Turbo Pascal (-Mtp, con las mismas opciones que
  vpa.cfg) que dibuja con la API Graph TAL Y COMO LO HACE VPA: shortstrings,
  smallint, buferes de GetImage reservados con GetMem y pasados como
  'var Bitmap', ViewPortType, SetGraphMode no... Se compila dos veces y la
  UNICA diferencia entre las dos es la palabra de la clausula uses:

    - graphapi_test_core   : uses vpagraph  (nucleo + plugin por dlopen);
    - graphapi_test_direct : uses ptcgraph  (-dDIRECT; el ptcgraph del
                             ejecutable, build/ptcunits).

  Eso es exactamente lo que T6.5 hara con las 24 unidades de VPA. Si esta
  prueba compila en los dos sentidos sin tocar una sola llamada, y los
  volcados salen identicos byte a byte, la decision D-03 se sostiene.

  Los volcados se hacen con VPADumpFrame, como KEYBOARD.PAS con Ctrl-F12:
  el prefijo viene de VPA_GRAPH_DUMP y la numeracion es NNNN.

  Salida 0 si todo fue bien; 1 si algo fallo. }
program graphapi_test;

uses
  {$IFDEF DIRECT}cthreads, ptcgraph{$ELSE}vpagraph{$ENDIF};

var
  Failures : integer;
  gd, gm   : integer;        { como en VPAINIT: 'integer' de -Mtp = smallint }
  LittFont : integer;

procedure Check(Cond: boolean; const What: string);
begin
  if Cond then
    Writeln('  ok   ', What)
  else
  begin
    Writeln('  FAIL ', What);
    Inc(Failures);
  end;
end;

{ El backend anuncia cada volcado por su propia salida estandar, que es la de
  OTRO RTL con su propio bufer: se vacia el nuestro antes para que las lineas
  no se entremezclen en el registro que compara el Makefile. }
procedure Dump(const What: string);
begin
  Flush(Output);
  Check(VPADumpFrame > 0, 'dump ' + What);
end;

{ --- 1: lineas, estilos, cursor grafico, XOR --- }
procedure SceneLines;
var
  i : integer;
begin
  ClearDevice;
  for i := 0 to 3 do
  begin
    SetColor(White - i);
    SetLineStyle(i, 0, NormWidth);
    Line(10, 10 + i * 12, 300, 40 + i * 12);
    SetLineStyle(i, 0, ThickWidth);
    Line(320, 10 + i * 12, 620, 40 + i * 12);
  end;
  SetColor(Yellow);
  SetLineStyle(UserBitLn, $F0F0, NormWidth);
  Line(10, 100, 620, 100);
  SetLineStyle(UserBitLn, $3333, NormWidth);
  Line(10, 110, 620, 470);
  SetLineStyle(SolidLn, 0, NormWidth);
  SetColor(LightGreen);
  MoveTo(50, 200);
  LineTo(150, 250);
  LineRel(60, -30);
  LineRel(-20, 80);
  LineTo(50, 200);
  SetWriteMode(XORPut);
  SetColor(LightRed);
  for i := 0 to 9 do
    Line(0, 120 + i * 30, 639, 400 - i * 25);
  Rectangle(40, 190, 230, 310);
  SetWriteMode(NormalPut);
  Dump('lines');
end;

{ --- 2: formas --- }
procedure SceneShapes;
var
  i : integer;
begin
  ClearDevice;
  for i := 1 to 15 do
  begin
    SetFillStyle(SolidFill, i);
    Bar(i * 40 - 30, 10, i * 40, 60);
    SetColor(16 - i);
    Rectangle(i * 40 - 32, 8, i * 40 + 2, 62);
    Circle(i * 40 - 15, 120, i * 2);
  end;
  SetColor(LightCyan);
  Ellipse(100, 250, 270, 90, 9, 30);      { el escudo de TCOMBAT }
  Ellipse(140, 250, 90, 270, 9, 30);
  Ellipse(320, 300, 0, 360, 120, 60);
  Ellipse(320, 300, 45, 200, 80, 100);
  SetWriteMode(XORPut);
  SetColor(White);
  Circle(320, 300, 90);
  SetWriteMode(NormalPut);
  for i := 0 to 255 do
    PutPixel(10 + i * 2, 460, i);
  Writeln('  pixels ', GetPixel(20, 30), ' ', GetPixel(60, 30), ' ',
    GetPixel(320, 300), ' ', GetPixel(110, 460), ' ', GetPixel(639, 479),
    ' color ', GetColor);
  Dump('shapes');
end;

{ --- 3: texto, fuentes, justificacion, viewport --- }
procedure SceneText;
var
  vp : ViewPortType;
  h, v : integer;
  s : string;
begin
  ClearDevice;
  SetColor(White);
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);
  OutTextXY(10, 10, 'VGA Planets Assistant - graphapi_test');
  s := '';
  for h := 32 to 126 do s := s + Chr(h);
  OutTextXY(10, 24, s);
  OutTextXY(10, 36, '');                       { cadena vacia }
  for h := 0 to 2 do
    for v := 0 to 2 do
      if v <> 1 then
      begin
        SetTextJustify(h, v);
        SetColor(Yellow - h);
        OutTextXY(320, 80 + v * 20, 'Justify');
        PutPixel(320, 80 + v * 20, LightRed);
      end;
  SetTextJustify(LeftText, TopText);
  SetTextStyle(LittFont, HorizDir, 4);
  SetColor(LightGreen);
  OutTextXY(10, 150, 'Planet 123  Ship 456  ~!@#$%^&*()');
  SetTextJustify(CenterText, BottomText);
  OutTextXY(320, 200, 'centered on the bottom');
  SetTextStyle(DefaultFont, HorizDir, 1);
  SetTextJustify(LeftText, TopText);

  SetViewPort(200, 250, 440, 330, ClipOn);
  GetViewSettings(vp);
  Writeln('  viewport ', vp.x1, ' ', vp.y1, ' ', vp.x2, ' ', vp.y2, ' ', vp.Clip);
  SetColor(LightMagenta);
  Rectangle(0, 0, 240, 80);
  OutTextXY(-20, 30, 'clipped on both sides of the viewport, certainly');
  Line(-50, -50, 400, 200);
  SetViewPort(0, 0, 639, 479, ClipOn);
  GetViewSettings(vp);
  Writeln('  viewport ', vp.x1, ' ', vp.y1, ' ', vp.x2, ' ', vp.y2, ' ', vp.Clip);
  Dump('text');
end;

{ --- 4: imagenes, como SCREEN.PAS: ImageSize -> GetMem -> GetImage --- }
procedure SceneImages;
var
  p    : pointer;
  size : longint;
begin
  size := ImageSize(0, 0, 159, 99);
  Writeln('  imagesize ', size, ' ', ImageSize(0, 0, 639, 479));
  Check(size = 12 + 160 * 100 * 2, 'ImageSize = 12 + w*h*2');
  GetMem(p, size);
  GetImage(0, 0, 159, 99, p^);
  PutImage(400, 250, p^, NormalPut);
  PutImage(420, 270, p^, XORPut);
  PutImage(300, 380, p^, OrPut);
  PutImage(560, 420, p^, NormalPut);            { se sale de la pantalla }
  SetViewPort(100, 340, 200, 400, ClipOn);
  PutImage(-30, -20, p^, NormalPut);            { se sale del viewport }
  SetViewPort(0, 0, 639, 479, ClipOn);
  FreeMem(p, size);
  Dump('images');
end;

{ --- 5: paleta, como TCOMBAT --- }
procedure ScenePalette;
var
  i : integer;
  r, g, b : integer;
begin
  GetRGBPalette(White, r, g, b);
  Writeln('  palette[15] ', r, ' ', g, ' ', b);
  for i := 1 to 15 do
    SetRGBPalette(i, i * 16, 255 - i * 16, (i * 40) and 255);
  GetRGBPalette(7, r, g, b);
  Writeln('  palette[7] ', r, ' ', g, ' ', b);
  Dump('palette');
end;

begin
  Failures := 0;
  Check(VPADumpEnabled, 'VPA_GRAPH_DUMP is set');
  gd := D8bit;
  gm := m640x480;
  {$IFDEF DIRECT}
  VPAForceScale := 100;
  {$ENDIF}
  InitGraph(gd, gm, '');
  if GraphResult <> grOk then
  begin
    Writeln('  FAIL InitGraph');
    {$IFNDEF DIRECT}Writeln(VPAGraphInitDetail);{$ENDIF}
    Halt(1);
  end;
  {$IFNDEF DIRECT}
  Writeln('  backend ', VPAGraphBackendName, ', scale ', VPAGraphScalePercent, '%');
  Check(VPAGraphScalePercent = 100, 'VPA_SCALE=1 gives 100%');
  {$ENDIF}
  LittFont := InstallUserFont('LITT_VPA.CHR');
  Check(LittFont > 0, 'InstallUserFont');

  SceneLines;
  SceneShapes;
  SceneText;
  SceneImages;
  ScenePalette;

  CloseGraph;
  { tras CloseGraph las primitivas de vpagraph son inocuas; ptcgraph no lo
    garantiza, asi que solo se prueba en la variante del nucleo }
  {$IFNDEF DIRECT}
  SetColor(White);
  OutTextXY(0, 0, 'nobody home');
  Check(GetPixel(0, 0) = 0, 'primitives are harmless after CloseGraph');
  Check(VPAGraphBackendName = '', 'no backend after CloseGraph');
  {$ENDIF}

  if Failures = 0 then
    Writeln('graphapi_test: PASS')
  else
    Writeln('graphapi_test: FAIL (', Failures, ')');
  if Failures <> 0 then Halt(1);
end.
