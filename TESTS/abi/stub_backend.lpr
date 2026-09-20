{ stub_backend - plugin de juguete que cumple la ABI v1 y no dibuja nada.

  No abre ninguna ventana ni enlaza ninguna biblioteca grafica: solo devuelve
  una interfaz valida, con todas las funciones rellenas y con un estado
  minimo (color, viewport, posicion) para que devuelvan algo coherente. Es el
  banco de pruebas del cargador de la Fase 3: permite comprobar que se carga,
  que se negocia la version, que se llama a traves de la tabla y que se
  descarga, sin un servidor grafico de por medio y sin que un fallo de dibujo
  se confunda con un fallo de carga.

  Tarea T2.15 de WAYLAND.md.

  Se construye con:
    fpc -MOBJFPC -Cg -FiGRAPH -o<destino>/stub_backend.so TESTS/abi/stub_backend.lpr
}
library stub_backend;

{$MODE OBJFPC}{$H+}

{$I vpagraph_abi.inc}

const
  StubName    : PAnsiChar = 'stub';
  StubVersion : PAnsiChar = '1.0';

var
  Initialized : Boolean = False;
  LastError   : TVPAGraphInt32 = VPAG_OK;
  LastMessage : array[0..127] of AnsiChar;
  CurColor    : TVPAGraphUInt32 = 15;
  CurX, CurY  : TVPAGraphInt32;
  VpX1, VpY1  : TVPAGraphInt32;
  VpX2, VpY2  : TVPAGraphInt32;
  VpClip      : TVPAGraphUInt8 = VPAG_TRUE;
  SurfW, SurfH: TVPAGraphInt32;
  Frames      : TVPAGraphInt32 = 0;

{ Deja un mensaje de error, copiandolo a un buffer PROPIO del plugin: la
  cadena no cruza la frontera hasta que el llamante pide GetLastError con su
  propio buffer. }
procedure SetError(Code: TVPAGraphInt32; const Msg: AnsiString);
var
  N: Integer;
begin
  LastError := Code;
  N := Length(Msg);
  if N > High(LastMessage) then N := High(LastMessage);
  if N > 0 then Move(Msg[1], LastMessage[0], N);
  LastMessage[N] := #0;
end;

function StubInit(Params: PVPAGraphInitParams): TVPAGraphInt32; cdecl;
begin
  if Params = nil then
  begin
    SetError(VPAG_ERR_INVALID_PARAM, 'Params es nil');
    StubInit := VPAG_ERR_INVALID_PARAM;
    Exit;
  end;
  if Params^.StructSize < SizeOf(TVPAGraphInitParams) then
  begin
    SetError(VPAG_ERR_STRUCT_SIZE, 'TVPAGraphInitParams demasiado pequeno');
    StubInit := VPAG_ERR_STRUCT_SIZE;
    Exit;
  end;
  if (Params^.Width <= 0) or (Params^.Height <= 0) then
  begin
    SetError(VPAG_ERR_INVALID_PARAM, 'ancho o alto no positivos');
    StubInit := VPAG_ERR_INVALID_PARAM;
    Exit;
  end;
  SurfW := Params^.Width;
  SurfH := Params^.Height;
  VpX1 := 0; VpY1 := 0; VpX2 := SurfW - 1; VpY2 := SurfH - 1;
  CurX := 0; CurY := 0;
  Initialized := True;
  SetError(VPAG_OK, '');
  StubInit := VPAG_OK;
end;

function StubShutdown: TVPAGraphInt32; cdecl;
begin
  Initialized := False;   { idempotente a proposito }
  StubShutdown := VPAG_OK;
end;

function StubGetLastError(Buffer: PAnsiChar; BufferSize: TVPAGraphUInt32): TVPAGraphInt32; cdecl;
var
  N, Len: TVPAGraphUInt32;
begin
  Len := 0;
  while LastMessage[Len] <> #0 do Inc(Len);
  if (Buffer <> nil) and (BufferSize > 0) then
  begin
    N := Len;
    if N > BufferSize - 1 then N := BufferSize - 1;
    if N > 0 then Move(LastMessage[0], Buffer^, N);
    PAnsiChar(Buffer)[N] := #0;
  end;
  StubGetLastError := TVPAGraphInt32(Len);
end;

{ Presentar antes de Init es un error del llamante, y el stub lo dice: el
  cargador de la Fase 3 puede comprobar asi que respeta el ciclo de vida. }
function StubPresent: TVPAGraphInt32; cdecl;
begin
  if not Initialized then
  begin
    SetError(VPAG_ERR_INIT, 'Present antes de Init');
    StubPresent := VPAG_ERR_INIT;
    Exit;
  end;
  Inc(Frames);
  StubPresent := VPAG_OK;
end;

function StubGraphResult: TVPAGraphInt32; cdecl;
begin
  StubGraphResult := LastError;
end;

function StubSuspend: TVPAGraphInt32; cdecl;
begin
  StubSuspend := VPAG_OK;
end;

function StubResume: TVPAGraphInt32; cdecl;
begin
  StubResume := VPAG_OK;
end;

procedure StubClearDevice; cdecl;
begin
  CurX := 0; CurY := 0;
end;

procedure StubSetViewPort(X1, Y1, X2, Y2: TVPAGraphInt32; Clip: TVPAGraphBool); cdecl;
begin
  VpX1 := X1; VpY1 := Y1; VpX2 := X2; VpY2 := Y2; VpClip := Clip;
  CurX := 0; CurY := 0;
end;

procedure StubGetViewSettings(X1, Y1, X2, Y2: PVPAGraphInt32; Clip: PVPAGraphUInt8); cdecl;
begin
  if X1 <> nil then X1^ := VpX1;
  if Y1 <> nil then Y1^ := VpY1;
  if X2 <> nil then X2^ := VpX2;
  if Y2 <> nil then Y2^ := VpY2;
  if Clip <> nil then Clip^ := VpClip;
end;

procedure StubSetColor(Color: TVPAGraphUInt32); cdecl;
begin
  CurColor := Color;
end;

function StubGetColor: TVPAGraphUInt32; cdecl;
begin
  StubGetColor := CurColor;
end;

procedure StubSetLineStyle(LineStyle, Pattern, Thickness: TVPAGraphUInt32); cdecl;
begin
end;

procedure StubSetFillStyle(Pattern: TVPAGraphUInt32; Color: TVPAGraphUInt32); cdecl;
begin
end;

procedure StubSetWriteMode(WriteMode: TVPAGraphUInt32); cdecl;
begin
end;

procedure StubPutPixel(X, Y: TVPAGraphInt32; Color: TVPAGraphUInt32); cdecl;
begin
end;

function StubGetPixel(X, Y: TVPAGraphInt32): TVPAGraphUInt32; cdecl;
begin
  StubGetPixel := 0;
end;

procedure StubLine(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
begin
  CurX := X2; CurY := Y2;
end;

procedure StubLineTo(X, Y: TVPAGraphInt32); cdecl;
begin
  CurX := X; CurY := Y;
end;

procedure StubLineRel(DX, DY: TVPAGraphInt32); cdecl;
begin
  Inc(CurX, DX); Inc(CurY, DY);
end;

procedure StubMoveTo(X, Y: TVPAGraphInt32); cdecl;
begin
  CurX := X; CurY := Y;
end;

procedure StubRectangle(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
begin
end;

procedure StubBar(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
begin
end;

procedure StubCircle(X, Y: TVPAGraphInt32; Radius: TVPAGraphUInt32); cdecl;
begin
end;

procedure StubEllipse(X, Y: TVPAGraphInt32; StartAngle, EndAngle: TVPAGraphInt32;
  XRadius, YRadius: TVPAGraphUInt32); cdecl;
begin
end;

{ Mismo calculo que ptcgraph: cabecera de 12 bytes y un entero de 16 bits por
  pixel. Aunque el stub no dibuje, esto tiene que ser exacto: el cargador y
  VPA reservan memoria con lo que devuelva. }
function StubImageSize(X1, Y1, X2, Y2: TVPAGraphInt32): TVPAGraphInt32; cdecl;
begin
  StubImageSize := 12 + ((X2 - X1 + 1) * (Y2 - Y1 + 1)) * 2;
end;

procedure StubGetImage(X1, Y1, X2, Y2: TVPAGraphInt32; Bitmap: Pointer;
  BitmapSize: TVPAGraphInt32); cdecl;
var
  Header: PVPAGraphInt32;
begin
  if (Bitmap = nil) or (BitmapSize < StubImageSize(X1, Y1, X2, Y2)) then Exit;
  { la cabecera si se rellena: es lo que VPA lee despues }
  Header := PVPAGraphInt32(Bitmap);
  Header[0] := X2 - X1 + 1;
  Header[1] := Y2 - Y1 + 1;
  Header[2] := 0;
  FillChar((PByte(Bitmap) + 12)^, BitmapSize - 12, 0);
end;

procedure StubPutImage(X, Y: TVPAGraphInt32; Bitmap: Pointer;
  BitmapSize: TVPAGraphInt32; BitBlt: TVPAGraphUInt32); cdecl;
begin
end;

procedure StubSetRGBPalette(ColorNum, R, G, B: TVPAGraphInt32); cdecl;
begin
end;

procedure StubGetRGBPalette(ColorNum: TVPAGraphInt32; R, G, B: PVPAGraphInt32); cdecl;
begin
  if R <> nil then R^ := 0;
  if G <> nil then G^ := 0;
  if B <> nil then B^ := 0;
end;

procedure StubSetRGBPaletteBlock(FirstColor, Count: TVPAGraphInt32;
  RGBTriplets: PVPAGraphUInt8); cdecl;
begin
end;

procedure StubOutTextXY(X, Y: TVPAGraphInt32; Text: PAnsiChar); cdecl;
begin
end;

procedure StubSetTextStyle(Font, Direction, CharSize: TVPAGraphUInt32); cdecl;
begin
end;

procedure StubSetTextJustify(Horiz, Vert: TVPAGraphUInt32); cdecl;
begin
end;

{ Devuelve siempre un identificador valido: el stub no carga nada, pero el
  nucleo tiene que poder distinguir "cargada" de "fallo". }
function StubInstallUserFont(FontFileName: PAnsiChar): TVPAGraphInt32; cdecl;
begin
  if FontFileName = nil then
    StubInstallUserFont := VPAG_ERR_INVALID_PARAM
  else
    StubInstallUserFont := 1;
end;

function StubGetScreenSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;
begin
  if (Width = nil) or (Height = nil) then
  begin
    StubGetScreenSize := VPAG_ERR_INVALID_PARAM;
    Exit;
  end;
  Width^ := 1920;
  Height^ := 1080;
  StubGetScreenSize := VPAG_OK;
end;

function StubSetFullscreen(Enable: TVPAGraphBool): TVPAGraphInt32; cdecl;
begin
  StubSetFullscreen := VPAG_OK;
end;

function StubGetWindowSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;
begin
  if (Width = nil) or (Height = nil) then
  begin
    StubGetWindowSize := VPAG_ERR_INVALID_PARAM;
    Exit;
  end;
  Width^ := SurfW;
  Height^ := SurfH;
  StubGetWindowSize := VPAG_OK;
end;

{ Nunca hay eventos: el stub no tiene ventana. 0 = sin evento. }
function StubPollEvent(EventOut: PVPAGraphEvent): TVPAGraphInt32; cdecl;
begin
  if EventOut = nil then
  begin
    StubPollEvent := VPAG_ERR_INVALID_PARAM;
    Exit;
  end;
  StubPollEvent := 0;
end;

function StubGetModifiers: TVPAGraphUInt32; cdecl;
begin
  StubGetModifiers := 0;
end;

procedure StubGetMouseState(X, Y: PVPAGraphInt32; Buttons: PVPAGraphUInt32;
  Inside: PVPAGraphUInt8); cdecl;
begin
  if X <> nil then X^ := 0;
  if Y <> nil then Y^ := 0;
  if Buttons <> nil then Buttons^ := 0;
  if Inside <> nil then Inside^ := VPAG_FALSE;
end;

procedure StubSetMousePos(X, Y: TVPAGraphInt32); cdecl;
begin
end;

procedure StubShowMouse(Show: TVPAGraphBool); cdecl;
begin
end;

function StubDumpFrame(Prefix: PAnsiChar): TVPAGraphInt32; cdecl;
begin
  StubDumpFrame := VPAG_ERR_UNSUPPORTED;
end;

function VPAGraph_GetInterface(RequestedABIVersion: TVPAGraphUInt32;
  InterfaceSize: TVPAGraphUInt32;
  InterfaceOut: PVPAGraphInterface): TVPAGraphInt32; cdecl;
begin
  if InterfaceOut = nil then
  begin
    VPAGraph_GetInterface := VPAG_ERR_INVALID_PARAM;
    Exit;
  end;
  if RequestedABIVersion <> VPAGRAPH_ABI_VERSION then
  begin
    VPAGraph_GetInterface := VPAG_ERR_ABI_MISMATCH;
    Exit;
  end;
  if InterfaceSize < SizeOf(TVPAGraphInterface) then
  begin
    VPAGraph_GetInterface := VPAG_ERR_STRUCT_SIZE;
    Exit;
  end;

  FillChar(InterfaceOut^, SizeOf(TVPAGraphInterface), 0);
  with InterfaceOut^ do
  begin
    StructSize         := SizeOf(TVPAGraphInterface);
    ABIVersion         := VPAGRAPH_ABI_VERSION;
    BackendName        := StubName;
    BackendVersion     := StubVersion;

    Init               := @StubInit;
    Shutdown           := @StubShutdown;
    GetLastError       := @StubGetLastError;
    Present            := @StubPresent;
    GraphResult        := @StubGraphResult;
    Suspend            := @StubSuspend;
    Resume             := @StubResume;

    ClearDevice        := @StubClearDevice;
    SetViewPort        := @StubSetViewPort;
    GetViewSettings    := @StubGetViewSettings;
    SetColor           := @StubSetColor;
    GetColor           := @StubGetColor;
    SetLineStyle       := @StubSetLineStyle;
    SetFillStyle       := @StubSetFillStyle;
    SetWriteMode       := @StubSetWriteMode;
    PutPixel           := @StubPutPixel;
    GetPixel           := @StubGetPixel;
    Line               := @StubLine;
    LineTo             := @StubLineTo;
    LineRel            := @StubLineRel;
    MoveTo             := @StubMoveTo;
    Rectangle          := @StubRectangle;
    Bar                := @StubBar;
    Circle             := @StubCircle;
    Ellipse            := @StubEllipse;

    ImageSize          := @StubImageSize;
    GetImage           := @StubGetImage;
    PutImage           := @StubPutImage;

    SetRGBPalette      := @StubSetRGBPalette;
    GetRGBPalette      := @StubGetRGBPalette;
    SetRGBPaletteBlock := @StubSetRGBPaletteBlock;

    OutTextXY          := @StubOutTextXY;
    SetTextStyle       := @StubSetTextStyle;
    SetTextJustify     := @StubSetTextJustify;
    InstallUserFont    := @StubInstallUserFont;

    GetScreenSize      := @StubGetScreenSize;
    SetFullscreen      := @StubSetFullscreen;
    GetWindowSize      := @StubGetWindowSize;

    PollEvent          := @StubPollEvent;
    GetModifiers       := @StubGetModifiers;
    GetMouseState      := @StubGetMouseState;
    SetMousePos        := @StubSetMousePos;
    ShowMouse          := @StubShowMouse;

    DumpFrame          := @StubDumpFrame;
  end;
  VPAGraph_GetInterface := VPAG_OK;
end;

exports
  VPAGraph_GetInterface;

begin
  LastMessage[0] := #0;
end.
