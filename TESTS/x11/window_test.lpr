{ window_test - comprobacion del bloque de ventana de la ABI (T2.10) en el
  plugin X11, tareas T5.6 y T5.7 de WAYLAND.md. Corre bajo Xvfb (sin gestor
  de ventanas: la pantalla completa solo puede comprobarse como propiedad
  puesta en la ventana, no como cambio de tamano).

  Comprueba que:
    - GetScreenSize funciona ANTES de Init y da el tamano de la pantalla de
      Xvfb, sin dejar abierta ninguna conexion (lo vigila heaptrc del arnes
      y, para el descriptor, se cuenta /proc/self/fd antes y despues);
    - Init a 100% deja una ventana de 640x480 con el foco de teclado (el
      arnes lo mira con XGetInputFocus desde SU propia conexion), y a 200%
      una de 1280x960: la escala llega al plugin como ScalePercent;
    - SetFullscreen(1) pone _NET_WM_STATE_FULLSCREEN en la ventana y
      SetFullscreen(0) lo quita;
    - Suspend cierra la ventana (GetWindowSize -> VPAG_ERR_INIT) y Resume
      abre otra, con el foco y con la pantalla completa que habia;
    - Init con Fullscreen = 1 arranca ya con la propiedad puesta.

  Uso:  window_test <ruta del .so>     (bajo xvfb-run)
  Salida 0 si todo fue bien; 1 si algo fallo. }
program window_test;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, dl, x, xlib, xatom, ctypes;

{$I vpagraph_abi.inc}

var
  Failures: Integer = 0;
  Dpy: PDisplay;   { conexion propia del arnes, para mirar la ventana }

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

function ErrText(const I: TVPAGraphInterface): AnsiString;
var
  Buf: array[0..VPAG_ERROR_BUFFER_SIZE - 1] of AnsiChar;
begin
  Buf[0] := #0;
  I.GetLastError(@Buf[0], SizeOf(Buf));
  ErrText := AnsiString(PAnsiChar(@Buf[0]));
end;

{ Numero de descriptores abiertos en este proceso. }
function OpenFds: Integer;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst('/proc/self/fd/*', faAnyFile, SR) = 0 then
  begin
    repeat
      Inc(Result);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

{ La ventana que tiene el foco de teclado, segun el servidor. }
function FocusWindow: TWindow;
var
  W: TWindow;
  RevertTo: cint;
begin
  XGetInputFocus(Dpy, @W, @RevertTo);
  Result := W;
end;

{ La ventana de nivel superior con el tamano dado (la unica que hay bajo
  Xvfb mientras corre el arnes). 0 si no la encuentra. }
function FindWindowBySize(W, H: Integer): TWindow;
var
  Root, Parent: TWindow;
  Children: PWindow;
  N: cuint;
  I: Integer;
  Attr: TXWindowAttributes;
begin
  Result := 0;
  if XQueryTree(Dpy, XDefaultRootWindow(Dpy), @Root, @Parent, @Children, @N) = 0 then Exit;
  for I := 0 to Integer(N) - 1 do
    if (XGetWindowAttributes(Dpy, Children[I], @Attr) <> 0) and
       (Attr.map_state = IsViewable) and (Attr.width = W) and (Attr.height = H) then
      Result := Children[I];
  if Children <> nil then XFree(Children);
end;

{ True si la ventana lleva _NET_WM_STATE_FULLSCREEN en _NET_WM_STATE. }
function HasFullscreenProperty(Win: TWindow): Boolean;
var
  netState, netFS, AType: TAtom;
  AFmt: cint;
  NItems, BAfter: culong;
  Prop: PCUChar;
  Atoms: PCULong;
  I: Integer;
begin
  Result := False;
  netState := XInternAtom(Dpy, '_NET_WM_STATE', 0);
  netFS := XInternAtom(Dpy, '_NET_WM_STATE_FULLSCREEN', 0);
  Prop := nil;
  if (XGetWindowProperty(Dpy, Win, netState, 0, 64, 0, XA_ATOM, @AType, @AFmt,
        @NItems, @BAfter, @Prop) = 0) and (Prop <> nil) then
  begin
    Atoms := PCULong(Prop);
    for I := 0 to Integer(NItems) - 1 do
      if Atoms[I] = netFS then Result := True;
    XFree(Prop);
  end;
end;

var
  Path   : AnsiString;
  H      : Pointer;
  Entry  : TVPAGraphGetInterfaceProc;
  Iface  : TVPAGraphInterface;
  Params : TVPAGraphInitParams;
  R      : TVPAGraphInt32;
  SW, SH, WW, WH: TVPAGraphInt32;
  Fds0   : Integer;
  Win    : TWindow;

function Run: Integer;
begin
  if ParamCount < 1 then
  begin
    Writeln('usage: window_test <libvpagraph-x11.so>');
    Exit(2);
  end;
  Path := ParamStr(1);
  Writeln('window_test: ', Path);

  Dpy := XOpenDisplay(nil);
  Check(Dpy <> nil, 'harness has its own X connection');
  if Dpy = nil then Exit(1);

  H := dlopen(PAnsiChar(Path), RTLD_NOW);
  Check(H <> nil, 'dlopen(RTLD_NOW) ' + Path);
  if H = nil then Exit(1);
  Pointer(Entry) := dlsym(H, VPAGRAPH_ENTRY_POINT);
  Check(Entry <> nil, 'dlsym ' + VPAGRAPH_ENTRY_POINT);
  if Entry = nil then Exit(1);
  FillChar(Iface, SizeOf(Iface), 0);
  R := Entry(VPAGRAPH_ABI_VERSION, SizeOf(Iface), @Iface);
  Check(R = VPAG_OK, 'VPAGraph_GetInterface -> ' + IntToStr(R));
  if R <> VPAG_OK then Exit(1);
  Check(Assigned(Iface.GetScreenSize) and Assigned(Iface.SetFullscreen) and
        Assigned(Iface.GetWindowSize), 'T2.10 entries are filled in');

  { --- GetScreenSize antes de Init, sin dejar conexion abierta --- }
  Fds0 := OpenFds;
  SW := 0; SH := 0;
  R := Iface.GetScreenSize(@SW, @SH);
  Check(R = VPAG_OK, 'GetScreenSize before Init -> ' + IntToStr(R) + ' (' + ErrText(Iface) + ')');
  Check((SW = XDisplayWidth(Dpy, XDefaultScreen(Dpy))) and
        (SH = XDisplayHeight(Dpy, XDefaultScreen(Dpy))),
        'screen is ' + IntToStr(SW) + 'x' + IntToStr(SH));
  Check(OpenFds = Fds0, 'GetScreenSize before Init leaves no descriptor open');
  Check(Iface.GetWindowSize(@WW, @WH) = VPAG_ERR_INIT, 'GetWindowSize before Init -> VPAG_ERR_INIT');
  Check(Iface.SetFullscreen(VPAG_TRUE) = VPAG_ERR_INIT, 'SetFullscreen before Init -> VPAG_ERR_INIT');

  { --- Init a 100%: 640x480 con el foco --- }
  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize := SizeOf(Params);
  Params.Width := 640;
  Params.Height := 480;
  Params.ScalePercent := 100;
  Params.WindowTitle := 'window_test';
  R := Iface.Init(@Params);
  Check(R = VPAG_OK, 'Init at 100% -> ' + IntToStr(R) + ' (' + ErrText(Iface) + ')');
  if R <> VPAG_OK then Exit(1);
  R := Iface.GetWindowSize(@WW, @WH);
  Check((R = VPAG_OK) and (WW = 640) and (WH = 480), 'GetWindowSize -> ' + IntToStr(WW) + 'x' + IntToStr(WH));
  Win := FindWindowBySize(640, 480);
  Check(Win <> 0, 'the 640x480 window is mapped');
  Check((Win <> 0) and (FocusWindow = Win), 'it has the keyboard focus');

  { --- pantalla completa: propiedad puesta y quitada --- }
  Check(not HasFullscreenProperty(Win), 'no _NET_WM_STATE_FULLSCREEN at start');
  R := Iface.SetFullscreen(VPAG_TRUE);
  XSync(Dpy, 0);
  Check(R = VPAG_OK, 'SetFullscreen(1) -> ' + IntToStr(R));
  Check(HasFullscreenProperty(Win), '_NET_WM_STATE_FULLSCREEN is set');

  { --- Suspend / Resume: otra ventana, con foco y pantalla completa --- }
  Check(Iface.Suspend() = VPAG_OK, 'Suspend');
  XSync(Dpy, 0);
  Check(Iface.GetWindowSize(@WW, @WH) = VPAG_ERR_INIT, 'GetWindowSize while suspended -> VPAG_ERR_INIT');
  Check(FindWindowBySize(640, 480) = 0, 'the window is gone while suspended');
  R := Iface.Resume();
  XSync(Dpy, 0);
  Check(R = VPAG_OK, 'Resume -> ' + IntToStr(R) + ' (' + ErrText(Iface) + ')');
  Win := FindWindowBySize(640, 480);
  Check(Win <> 0, 'a new 640x480 window is mapped');
  Check((Win <> 0) and (FocusWindow = Win), 'it has the keyboard focus again');
  Check((Win <> 0) and HasFullscreenProperty(Win), 'fullscreen was re-applied by Resume');

  R := Iface.SetFullscreen(VPAG_FALSE);
  XSync(Dpy, 0);
  Check(R = VPAG_OK, 'SetFullscreen(0) -> ' + IntToStr(R));
  Check((Win <> 0) and not HasFullscreenProperty(Win), '_NET_WM_STATE_FULLSCREEN is cleared');
  Check(Iface.Shutdown() = VPAG_OK, 'Shutdown');
  XSync(Dpy, 0);

  { --- Init a 200% y con Fullscreen = 1 --- }
  Params.ScalePercent := 200;
  Params.Fullscreen := VPAG_TRUE;
  R := Iface.Init(@Params);
  Check(R = VPAG_OK, 'Init at 200% with Fullscreen -> ' + IntToStr(R) + ' (' + ErrText(Iface) + ')');
  if R = VPAG_OK then
  begin
    XSync(Dpy, 0);
    R := Iface.GetWindowSize(@WW, @WH);
    Check((R = VPAG_OK) and (WW = 1280) and (WH = 960), 'GetWindowSize -> ' + IntToStr(WW) + 'x' + IntToStr(WH));
    Win := FindWindowBySize(1280, 960);
    Check(Win <> 0, 'the 1280x960 window is mapped');
    Check((Win <> 0) and (FocusWindow = Win), 'it has the keyboard focus');
    Check((Win <> 0) and HasFullscreenProperty(Win), 'Init.Fullscreen set _NET_WM_STATE_FULLSCREEN');
    Check(Iface.Shutdown() = VPAG_OK, 'Shutdown');
  end;

  Check(dlclose(H) = 0, 'dlclose');
  XCloseDisplay(Dpy);

  if Failures = 0 then
  begin
    Writeln('window_test: PASS');
    Exit(0);
  end;
  Writeln('window_test: FAIL (', Failures, ')');
  Exit(1);
end;

begin
  Halt(Run);
end.
