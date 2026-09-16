{ scene_test - criterio de aceptacion de la Fase 5 (WAYLAND.md, T5.11): las
  mismas escenas dibujadas a traves del plugin X11 y directamente contra
  ptcgraph tienen que dar CERO pixeles de diferencia.

  El mismo fuente se compila dos veces:

    - scene_test_plugin (por defecto): carga build/plugins/libvpagraph-x11.so
      con el cargador REAL del nucleo (GRAPH/vpagraph_loader.pas, no un
      dlopen a mano) y dibuja con la tabla de la ABI. No enlaza ptcgraph ni
      libX11: readelf -d no debe mostrar libX11 (T5.10);
    - scene_test_direct (-dDIRECT): enlaza el ptcgraph del EJECUTABLE
      (build/ptcunits, no PIC, las opciones de hoy) y dibuja llamandolo
      directamente, a traves de adaptadores cdecl de una linea con la misma
      firma que la ABI. Los adaptadores del plugin NO se comparten: si uno
      trunca mal un parametro o cambia el orden de los radios de Ellipse,
      esta es la prueba que lo ve.

  Cada escena termina con DumpFrame (VPADumpFrameTo, T0.4): un .ppm y un
  .pal por escena, con el prefijo que se pasa como segundo argumento. El
  Makefile (objetivo scene-test) corre las dos variantes bajo Xvfb y compara
  los ficheros con cmp.

  Escenas (640x480, D8bit, escala 100%):
    1. lineas: los cuatro estilos y el patron de usuario, los dos grosores,
       LineTo/LineRel/MoveTo, modo XOR sobre lo ya dibujado;
    2. formas: rectangulos, barras solidas, circulos, arcos de elipse
       (incluida la media elipse 9 x ry del escudo de TCOMBAT.PAS), PutPixel;
    3. texto: fuente bitmap en tamanos 1..3, las nueve justificaciones,
       LITT_VPA.CHR con InstallUserFont, viewport con recorte;
    4. imagenes: GetImage de una region y PutImage con NORMAL, XOR y OR,
       parcialmente fuera del viewport;
    5. paleta: SetRGBPalette y SetRGBPaletteBlock (las 15 entradas del
       combate) sobre la escena anterior.
  Ademas imprime GetPixel de unos puntos fijos y GetViewSettings, que el
  Makefile tambien compara entre variantes.

  Uso:  scene_test_plugin <ruta del .so> <prefijo de volcado>
        scene_test_direct <lo que sea>    <prefijo de volcado>   (bajo Xvfb)
  Salida 0 si todo fue bien; 1 si algo fallo. }
program scene_test;

{$MODE OBJFPC}{$H+}

uses
  {$IFDEF DIRECT}cthreads,{$ENDIF}   { como VPA/VPA.PAS: ptcgraph levanta un hilo }
  SysUtils
  {$IFDEF DIRECT}, ptc, ptcgraph{$ELSE}, vpagraph_loader{$ENDIF};

{$IFDEF DIRECT}
{$I vpagraph_abi.inc}
{$ENDIF}

var
  Failures: Integer = 0;
  G: TVPAGraphInterface;   { la tabla por la que dibujan las escenas }

procedure Check(Cond: Boolean; const What: AnsiString);
begin
  if Cond then
    Writeln('  ok   ', What)
  else
  begin
    Writeln('  FAIL ', What);
    Inc(Failures);
  end;
end;

{$IFDEF DIRECT}
{ ---------------------------------------------------------------------------
  Variante directa: adaptadores de una linea sobre ptcgraph, con las firmas
  de la ABI. Deliberadamente NO son los del plugin.
  --------------------------------------------------------------------------- }
function D_Init(P: PVPAGraphInitParams): TVPAGraphInt32; cdecl;
var GD, GM: smallint;
begin
  VPAForceScale := P^.ScalePercent;
  if P^.WindowTitle <> nil then WindowTitle := AnsiString(P^.WindowTitle);
  GD := D8bit; GM := m640x480;
  InitGraph(GD, GM, '');
  if ptcgraph.GraphResult <> grOk then Exit(VPAG_ERR_VIDEO);
  Result := VPAG_OK;
end;
function D_Shutdown: TVPAGraphInt32; cdecl; begin CloseGraph; Result := VPAG_OK; end;
function D_GetLastError(B: PAnsiChar; N: TVPAGraphUInt32): TVPAGraphInt32; cdecl;
begin if (B <> nil) and (N > 0) then B[0] := #0; Result := 0; end;
procedure D_ClearDevice; cdecl; begin ClearDevice; end;
procedure D_SetViewPort(X1, Y1, X2, Y2: TVPAGraphInt32; Clip: TVPAGraphBool); cdecl;
begin SetViewPort(X1, Y1, X2, Y2, Clip <> 0); end;
procedure D_GetViewSettings(X1, Y1, X2, Y2: PVPAGraphInt32; Clip: PVPAGraphUInt8); cdecl;
var V: ViewPortType;
begin GetViewSettings(V); X1^ := V.x1; Y1^ := V.y1; X2^ := V.x2; Y2^ := V.y2; Clip^ := Ord(V.Clip); end;
procedure D_SetColor(C: TVPAGraphUInt32); cdecl; begin SetColor(C); end;
function D_GetColor: TVPAGraphUInt32; cdecl; begin Result := GetColor; end;
procedure D_SetLineStyle(S, P, T: TVPAGraphUInt32); cdecl; begin SetLineStyle(S, P, T); end;
procedure D_SetFillStyle(P, C: TVPAGraphUInt32); cdecl; begin SetFillStyle(P, C); end;
procedure D_SetWriteMode(M: TVPAGraphUInt32); cdecl; begin SetWriteMode(M); end;
procedure D_PutPixel(X, Y: TVPAGraphInt32; C: TVPAGraphUInt32); cdecl; begin PutPixel(X, Y, C); end;
function D_GetPixel(X, Y: TVPAGraphInt32): TVPAGraphUInt32; cdecl; begin Result := GetPixel(X, Y); end;
procedure D_Line(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl; begin Line(X1, Y1, X2, Y2); end;
procedure D_LineTo(X, Y: TVPAGraphInt32); cdecl; begin LineTo(X, Y); end;
procedure D_LineRel(DX, DY: TVPAGraphInt32); cdecl; begin LineRel(DX, DY); end;
procedure D_MoveTo(X, Y: TVPAGraphInt32); cdecl; begin MoveTo(X, Y); end;
procedure D_Rectangle(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl; begin Rectangle(X1, Y1, X2, Y2); end;
procedure D_Bar(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl; begin Bar(X1, Y1, X2, Y2); end;
procedure D_Circle(X, Y: TVPAGraphInt32; R: TVPAGraphUInt32); cdecl; begin Circle(X, Y, R); end;
procedure D_Ellipse(X, Y, SA, EA: TVPAGraphInt32; XR, YR: TVPAGraphUInt32); cdecl;
begin Ellipse(X, Y, SA, EA, XR, YR); end;
function D_ImageSize(X1, Y1, X2, Y2: TVPAGraphInt32): TVPAGraphInt32; cdecl;
begin Result := ImageSize(X1, Y1, X2, Y2); end;
procedure D_GetImage(X1, Y1, X2, Y2: TVPAGraphInt32; B: Pointer; N: TVPAGraphInt32); cdecl;
begin GetImage(X1, Y1, X2, Y2, B^); end;
procedure D_PutImage(X, Y: TVPAGraphInt32; B: Pointer; N: TVPAGraphInt32; M: TVPAGraphUInt32); cdecl;
begin PutImage(X, Y, B^, M); end;
procedure D_SetRGBPalette(C, R, Gc, B: TVPAGraphInt32); cdecl; begin SetRGBPalette(C, R, Gc, B); end;
procedure D_GetRGBPalette(C: TVPAGraphInt32; R, Gc, B: PVPAGraphInt32); cdecl;
var PR, PG, PB: smallint;
begin GetRGBPalette(C, PR, PG, PB); R^ := PR; Gc^ := PG; B^ := PB; end;
procedure D_SetRGBPaletteBlock(F, N: TVPAGraphInt32; T: PVPAGraphUInt8); cdecl;
var I: Integer;
begin for I := 0 to N - 1 do SetRGBPalette(F + I, T[I * 3], T[I * 3 + 1], T[I * 3 + 2]); end;
procedure D_OutTextXY(X, Y: TVPAGraphInt32; T: PAnsiChar); cdecl; begin OutTextXY(X, Y, ShortString(AnsiString(T))); end;
procedure D_SetTextStyle(F, D, S: TVPAGraphUInt32); cdecl; begin SetTextStyle(F, D, S); end;
procedure D_SetTextJustify(H, V: TVPAGraphUInt32); cdecl; begin SetTextJustify(H, V); end;
function D_InstallUserFont(N: PAnsiChar): TVPAGraphInt32; cdecl;
begin Result := InstallUserFont(ShortString(AnsiString(N))); end;
function D_DumpFrame(P: PAnsiChar): TVPAGraphInt32; cdecl; begin Result := VPADumpFrameTo(AnsiString(P)); end;

procedure FillDirectTable;
begin
  FillChar(G, SizeOf(G), 0);
  G.Init := @D_Init;                 G.Shutdown := @D_Shutdown;
  G.GetLastError := @D_GetLastError; G.ClearDevice := @D_ClearDevice;
  G.SetViewPort := @D_SetViewPort;   G.GetViewSettings := @D_GetViewSettings;
  G.SetColor := @D_SetColor;         G.GetColor := @D_GetColor;
  G.SetLineStyle := @D_SetLineStyle; G.SetFillStyle := @D_SetFillStyle;
  G.SetWriteMode := @D_SetWriteMode; G.PutPixel := @D_PutPixel;
  G.GetPixel := @D_GetPixel;         G.Line := @D_Line;
  G.LineTo := @D_LineTo;             G.LineRel := @D_LineRel;
  G.MoveTo := @D_MoveTo;             G.Rectangle := @D_Rectangle;
  G.Bar := @D_Bar;                   G.Circle := @D_Circle;
  G.Ellipse := @D_Ellipse;           G.ImageSize := @D_ImageSize;
  G.GetImage := @D_GetImage;         G.PutImage := @D_PutImage;
  G.SetRGBPalette := @D_SetRGBPalette; G.GetRGBPalette := @D_GetRGBPalette;
  G.SetRGBPaletteBlock := @D_SetRGBPaletteBlock;
  G.OutTextXY := @D_OutTextXY;       G.SetTextStyle := @D_SetTextStyle;
  G.SetTextJustify := @D_SetTextJustify; G.InstallUserFont := @D_InstallUserFont;
  G.DumpFrame := @D_DumpFrame;
end;
{$ENDIF}

{ ---------------------------------------------------------------------------
  Las escenas. Solo usan G.
  --------------------------------------------------------------------------- }

var
  Prefix: AnsiString;
  UserFont: TVPAGraphInt32 = -1;

procedure Dump(const Name: AnsiString);
var
  R: TVPAGraphInt32;
begin
  Flush(Output);   { el 'VPA: volcado' lo escribe otro RTL: que no se entremezcle }
  R := G.DumpFrame(PAnsiChar(Prefix));
  Check(R > 0, 'scene ' + Name + ' dumped as frame ' + IntToStr(R));
end;

procedure SceneLines;
var
  I: Integer;
begin
  G.ClearDevice;
  for I := 0 to 3 do
  begin
    G.SetColor(9 + I);
    G.SetLineStyle(I, 0, VPAG_WIDTH_NORM);
    G.Line(10, 20 + I * 12, 300, 20 + I * 12);
    G.SetLineStyle(I, 0, VPAG_WIDTH_THICK);
    G.Line(10, 80 + I * 14, 300, 100 + I * 14);
  end;
  G.SetLineStyle(VPAG_LINE_USERBIT, $F0F0, VPAG_WIDTH_NORM);
  G.SetColor(14);
  G.Line(10, 150, 300, 170);
  G.SetLineStyle(VPAG_LINE_SOLID, 0, VPAG_WIDTH_NORM);
  G.SetColor(15);
  G.MoveTo(320, 20);
  for I := 1 to 12 do
  begin
    G.LineTo(320 + I * 25, 20 + (I mod 3) * 40);
    G.LineRel(-7, 9);
  end;
  { XOR encima de lo ya dibujado: un rombo que cruza las lineas }
  G.SetWriteMode(VPAG_PUT_XOR);
  G.SetColor(7);
  G.Line(150, 10, 300, 180);
  G.Line(300, 10, 150, 180);
  G.Rectangle(100, 60, 200, 140);
  G.SetWriteMode(VPAG_PUT_NORMAL);
  Dump('lines');
end;

procedure SceneShapes;
var
  I: Integer;
begin
  G.ClearDevice;
  for I := 0 to 7 do
  begin
    G.SetColor(I + 1);
    G.Rectangle(10 + I * 30, 10 + I * 10, 150 + I * 30, 100 + I * 10);
    G.SetFillStyle(VPAG_FILL_SOLID, 8 + I);
    G.Bar(400 + I * 20, 20 + I * 30, 440 + I * 20, 60 + I * 30);
  end;
  G.SetColor(15);
  for I := 1 to 6 do
    G.Circle(120, 300, I * 15);
  G.SetLineStyle(VPAG_LINE_SOLID, 0, VPAG_WIDTH_THICK);
  G.Circle(300, 300, 50);
  G.SetLineStyle(VPAG_LINE_SOLID, 0, VPAG_WIDTH_NORM);
  { arcos de elipse; el ultimo es el escudo del combate (media elipse 9 x ry) }
  G.SetColor(11);
  G.Ellipse(450, 300, 0, 360, 80, 40);
  G.Ellipse(450, 300, 45, 225, 60, 70);
  G.Ellipse(560, 380, 90, 270, 9, 30);
  G.Ellipse(20, 20, 30, 300, 100, 100);   { parcialmente fuera }
  for I := 0 to 63 do
    G.PutPixel(20 + I * 9, 440 + (I mod 5) * 6, I mod 16);
  Dump('shapes');
end;

procedure SceneText;
const
  H: array[0..2] of TVPAGraphUInt32 = (VPAG_JUST_LEFT, VPAG_JUST_CENTER, VPAG_JUST_RIGHT);
  V: array[0..2] of TVPAGraphUInt32 = (VPAG_JUST_BOTTOM, 1, VPAG_JUST_TOP);
var
  I, J: Integer;
  X1, Y1, X2, Y2: TVPAGraphInt32;
  Clip: TVPAGraphUInt8;
begin
  G.ClearDevice;
  G.SetTextJustify(VPAG_JUST_LEFT, VPAG_JUST_TOP);
  for I := 1 to 3 do
  begin
    G.SetTextStyle(VPAG_FONT_DEFAULT, VPAG_DIR_HORIZ, I);
    G.SetColor(9 + I);
    G.OutTextXY(10, 10 + (I - 1) * 40, PAnsiChar('VPA-Linux scene test ' + IntToStr(I)));
  end;
  G.SetTextStyle(VPAG_FONT_DEFAULT, VPAG_DIR_HORIZ, 1);
  G.SetColor(15);
  G.Line(320, 150, 320, 330);
  G.Line(200, 240, 440, 240);
  for I := 0 to 2 do
    for J := 0 to 2 do
    begin
      G.SetTextJustify(H[I], V[J]);
      G.OutTextXY(320, 240, PAnsiChar('J' + IntToStr(I) + IntToStr(J)));
    end;
  G.SetTextJustify(VPAG_JUST_LEFT, VPAG_JUST_TOP);
  if UserFont > 0 then
  begin
    G.SetColor(14);
    for I := 1 to 4 do
    begin
      G.SetTextStyle(UserFont, VPAG_DIR_HORIZ, I);
      G.OutTextXY(10, 340 + (I - 1) * 30, 'LITT_VPA.CHR Planets 1234567890');
    end;
  end;
  G.SetTextStyle(VPAG_FONT_DEFAULT, VPAG_DIR_HORIZ, 2);
  { viewport con recorte: el texto y la linea se cortan en el borde }
  G.SetViewPort(480, 20, 620, 120, VPAG_TRUE);
  G.SetColor(12);
  G.OutTextXY(60, 40, 'clipped text here');
  G.Line(-50, 0, 300, 100);
  G.GetViewSettings(@X1, @Y1, @X2, @Y2, @Clip);
  Writeln('  viewport: ', X1, ',', Y1, '-', X2, ',', Y2, ' clip=', Clip);
  G.SetViewPort(0, 0, 639, 479, VPAG_TRUE);
  Dump('text');
end;

procedure SceneImages;
var
  Size: TVPAGraphInt32;
  Buf: Pointer;
begin
  { sobre la escena de texto: recortar un trozo y pegarlo con los tres modos }
  Size := G.ImageSize(0, 0, 199, 99);
  Check(Size = 12 + 200 * 100 * 2, 'ImageSize(200x100) = ' + IntToStr(Size));
  GetMem(Buf, Size);
  G.GetImage(0, 0, 199, 99, Buf, Size);
  G.PutImage(220, 340, Buf, Size, VPAG_PUT_NORMAL);
  G.PutImage(100, 200, Buf, Size, VPAG_PUT_XOR);
  G.PutImage(400, 200, Buf, Size, VPAG_PUT_OR);
  G.SetViewPort(300, 300, 639, 479, VPAG_TRUE);
  G.PutImage(250, 100, Buf, Size, VPAG_PUT_NORMAL);   { parcialmente fuera }
  G.SetViewPort(0, 0, 639, 479, VPAG_TRUE);
  G.PutImage(500, 420, Buf, Size, VPAG_PUT_NORMAL);   { fuera de la pantalla }
  FreeMem(Buf);
  Dump('images');
end;

procedure ScenePalette;
var
  T: array[0..44] of TVPAGraphUInt8;
  I: Integer;
  R, Gc, B: TVPAGraphInt32;
begin
  G.SetRGBPalette(9, 252, 0, 0);
  G.SetRGBPalette(10, 0, 252, 0);
  G.SetRGBPalette(11, 0, 0, 252);
  for I := 0 to 14 do
  begin
    T[I * 3] := I * 16; T[I * 3 + 1] := 252 - I * 16; T[I * 3 + 2] := (I * 40) and $FF;
  end;
  G.SetRGBPaletteBlock(16, 15, @T[0]);
  G.GetRGBPalette(20, @R, @Gc, @B);
  Writeln('  palette[20] = ', R, ',', Gc, ',', B);
  G.SetFillStyle(VPAG_FILL_SOLID, 20);
  G.Bar(0, 440, 639, 479);
  Dump('palette');
end;

procedure PrintPixels;
const
  PX: array[0..7] of Integer = (0, 15, 100, 319, 320, 450, 600, 639);
  PY: array[0..7] of Integer = (0, 25, 90, 239, 240, 300, 445, 479);
var
  I: Integer;
  S: AnsiString;
begin
  S := '';
  for I := 0 to 7 do
    S := S + ' ' + IntToStr(G.GetPixel(PX[I], PY[I]));
  Writeln('  pixels:', S, ' color=', G.GetColor);
end;

var
  Params: TVPAGraphInitParams;
  R: TVPAGraphInt32;
  {$IFNDEF DIRECT}
  Plugin: TVPAGraphPlugin;
  Detail: AnsiString;
  {$ENDIF}

function Run: Integer;
begin
  if ParamCount < 2 then
  begin
    Writeln('usage: scene_test <libvpagraph-x11.so | -> <dump prefix>');
    Exit(2);
  end;
  Prefix := ParamStr(2);
  {$IFDEF DIRECT}
  Writeln('scene_test (direct, ptcgraph linked in)');
  FillDirectTable;
  {$ELSE}
  Writeln('scene_test (plugin via vpagraph_loader): ', ParamStr(1));
  R := VPAGraph_LoadPlugin(ParamStr(1), Plugin, Detail);
  Check(R = VPAGL_OK, 'VPAGraph_LoadPlugin -> ' + IntToStr(R) + ' ' + Detail);
  if R <> VPAGL_OK then Exit(1);
  G := Plugin.Iface;
  {$ENDIF}

  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize := SizeOf(Params);
  Params.Width := 640;
  Params.Height := 480;
  Params.ScalePercent := 100;
  Params.WindowTitle := 'scene_test';
  R := G.Init(@Params);
  Check(R = VPAG_OK, 'Init -> ' + IntToStr(R));
  if R <> VPAG_OK then Exit(1);

  UserFont := G.InstallUserFont('LITT_VPA.CHR');
  Check(UserFont > 0, 'InstallUserFont(LITT_VPA.CHR) -> ' + IntToStr(UserFont));

  SceneLines;
  PrintPixels;
  SceneShapes;
  PrintPixels;
  SceneText;
  PrintPixels;
  SceneImages;
  PrintPixels;
  ScenePalette;
  PrintPixels;

  Check(G.Shutdown() = VPAG_OK, 'Shutdown');
  {$IFNDEF DIRECT}
  VPAGraph_UnloadPlugin(Plugin);
  {$ENDIF}

  if Failures = 0 then
  begin
    Writeln('scene_test: PASS');
    Exit(0);
  end;
  Writeln('scene_test: FAIL (', Failures, ')');
  Exit(1);
end;

begin
  Halt(Run);
end.
