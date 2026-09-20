{ input_test - comprobacion del bloque de teclado y raton de la ABI (T2.11)
  en el plugin X11, tarea T5.8 de WAYLAND.md. Corre bajo Xvfb con xdotool
  (XTest) para inyectar teclas y raton, con la ventana a 200% (1280x960),
  para que se vea el paso de pixeles de consola a coordenadas de superficie.

  Comprueba que:
    - un movimiento del raton llega como MOUSE_MOVE en coordenadas de
      superficie (640,480 de ventana -> 320,240), y un clic como MOUSE_DOWN
      + MOUSE_UP con VPAG_MB_LEFT;
    - una tecla llega como KEY_DOWN + KEY_UP con KeyCode = codigo ptc
      (VPAGK_A) y su punto de codigo; con Shift, UnicodeChar es 'B' y
      Modifiers lleva VPAG_MOD_SHIFT; con Ctrl, VPAG_MOD_CTRL;
    - GetModifiers refleja el estado vivo (Shift pulsado con xdotool keydown);
    - GetMouseState devuelve la ultima posicion de los eventos e Inside = 1,
      y Inside = 0 con el puntero fuera de la ventana;
    - SetMousePos(100,100) mueve el puntero fisico al centro del bloque
      escalado (201,201 en pantalla) y GetMouseState ya devuelve (100,100);
    - ShowMouse(0) y ShowMouse(1) no fallan;
    - WM_DELETE_WINDOW llega como CLOSE (ptc intercepta el cierre).

  Sin gestor de ventanas la ventana esta en (0,0), asi que las coordenadas
  de raiz que usa xdotool son las de ventana.

  Uso:  input_test <ruta del .so>     (bajo xvfb-run, con xdotool instalado)
  Salida 0 si todo fue bien; 1 si algo fallo. }
program input_test;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, dl, x, xlib, xatom, ctypes, unix, baseunix;

{$I vpagraph_abi.inc}

var
  Failures: Integer = 0;
  Dpy: PDisplay;
  Iface: TVPAGraphInterface;

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

function ErrText: AnsiString;
var
  Buf: array[0..VPAG_ERROR_BUFFER_SIZE - 1] of AnsiChar;
begin
  Buf[0] := #0;
  Iface.GetLastError(@Buf[0], SizeOf(Buf));
  ErrText := AnsiString(PAnsiChar(@Buf[0]));
end;

procedure SleepMs(Ms: Integer);
var
  ts: TTimeSpec;
begin
  ts.tv_sec := Ms div 1000;
  ts.tv_nsec := (Ms mod 1000) * 1000 * 1000;
  fpnanosleep(@ts, nil);
end;

procedure XDo(const Args: AnsiString);
begin
  if fpSystem('xdotool ' + Args) <> 0 then
    Check(False, 'xdotool ' + Args);
  SleepMs(100);
end;

{ Vacia la cola de eventos del plugin. }
procedure Drain;
var
  Ev: TVPAGraphEvent;
begin
  repeat
    FillChar(Ev, SizeOf(Ev), 0);
    Ev.StructSize := SizeOf(Ev);
  until Iface.PollEvent(@Ev) <> 1;
end;

{ Espera (hasta ~1 s) al siguiente evento del tipo pedido -y, si KeyCode no
  es 0, de esa tecla: 'xdotool key shift+b' pulsa antes el propio Shift-,
  descartando los demas. True si llego. }
function WaitEvent(EventType: TVPAGraphUInt32; out Ev: TVPAGraphEvent;
  KeyCode: TVPAGraphUInt32 = 0): Boolean;
var
  Waited: Integer;
  R: TVPAGraphInt32;
begin
  Waited := 0;
  repeat
    FillChar(Ev, SizeOf(Ev), 0);
    Ev.StructSize := SizeOf(Ev);
    R := Iface.PollEvent(@Ev);
    if R < 0 then
    begin
      Check(False, 'PollEvent -> ' + IntToStr(R) + ' (' + ErrText + ')');
      Exit(False);
    end;
    if (R = 1) and (Ev.EventType = EventType) and
       ((KeyCode = 0) or (Ev.KeyCode = KeyCode)) then
      Exit(True);
    if R = 0 then
    begin
      SleepMs(20);
      Inc(Waited, 20);
    end;
  until Waited >= 1000;
  Result := False;
end;

function EvText(const Ev: TVPAGraphEvent): AnsiString;
begin
  EvText := 'type=' + IntToStr(Ev.EventType) + ' key=$' + IntToHex(Ev.KeyCode, 2) +
    ' uni=' + IntToStr(Ev.UnicodeChar) + ' mod=' + IntToStr(Ev.Modifiers) +
    ' mouse=(' + IntToStr(Ev.MouseX) + ',' + IntToStr(Ev.MouseY) + ') btn=' +
    IntToStr(Ev.MouseButton);
end;

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

{ Posicion del puntero en la raiz, segun el servidor. }
procedure QueryPointer(out RX, RY: Integer);
var
  Root, Child: TWindow;
  rx0, ry0, wx, wy: cint;
  Mask: cuint;
begin
  XQueryPointer(Dpy, XDefaultRootWindow(Dpy), @Root, @Child, @rx0, @ry0, @wx, @wy, @Mask);
  RX := rx0;
  RY := ry0;
end;

var
  Path   : AnsiString;
  H      : Pointer;
  Entry  : TVPAGraphGetInterfaceProc;
  Params : TVPAGraphInitParams;
  R      : TVPAGraphInt32;
  Ev     : TVPAGraphEvent;
  Win    : TWindow;
  MX, MY : TVPAGraphInt32;
  Btn    : TVPAGraphUInt32;
  Inside : TVPAGraphUInt8;
  RX, RY : Integer;
  XEv    : TXEvent;
  wmProtocols, wmDelete: TAtom;
  Ok     : Boolean;

function Run: Integer;
begin
  if ParamCount < 1 then
  begin
    Writeln('usage: input_test <libvpagraph-x11.so>');
    Exit(2);
  end;
  Path := ParamStr(1);
  Writeln('input_test: ', Path);

  Dpy := XOpenDisplay(nil);
  Check(Dpy <> nil, 'harness has its own X connection');
  if Dpy = nil then Exit(1);

  H := dlopen(PAnsiChar(Path), RTLD_NOW);
  Check(H <> nil, 'dlopen(RTLD_NOW) ' + Path);
  if H = nil then Exit(1);
  Pointer(Entry) := dlsym(H, VPAGRAPH_ENTRY_POINT);
  if Entry = nil then Exit(1);
  FillChar(Iface, SizeOf(Iface), 0);
  R := Entry(VPAGRAPH_ABI_VERSION, SizeOf(Iface), @Iface);
  Check(R = VPAG_OK, 'VPAGraph_GetInterface -> ' + IntToStr(R));
  if R <> VPAG_OK then Exit(1);
  Check(Assigned(Iface.PollEvent) and Assigned(Iface.GetModifiers) and
        Assigned(Iface.GetMouseState) and Assigned(Iface.SetMousePos) and
        Assigned(Iface.ShowMouse), 'T2.11 entries are filled in');

  FillChar(Ev, SizeOf(Ev), 0);
  Ev.StructSize := SizeOf(Ev);
  Check(Iface.PollEvent(@Ev) = VPAG_ERR_INIT, 'PollEvent before Init -> VPAG_ERR_INIT');

  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize := SizeOf(Params);
  Params.Width := 640;
  Params.Height := 480;
  Params.ScalePercent := 200;
  Params.WindowTitle := 'input_test';
  R := Iface.Init(@Params);
  Check(R = VPAG_OK, 'Init at 200% -> ' + IntToStr(R) + ' (' + ErrText + ')');
  if R <> VPAG_OK then Exit(1);
  Win := FindWindowBySize(1280, 960);
  Check(Win <> 0, 'the 1280x960 window is mapped');
  SleepMs(200);
  Drain;

  { --- raton: movimiento y clic, escalados a superficie ---
    El primer movimiento que ve ptc solo fija la posicion previa y no emite
    evento (FPreviousMousePositionSaved), asi que se mueve dos veces. }
  XDo('mousemove 10 10');
  Drain;
  XDo('mousemove 640 480');
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX = 320) and (Ev.MouseY = 240);
  Check(Ok, 'MOUSE_MOVE at (640,480) window -> (320,240) surface: ' + EvText(Ev));
  Drain;
  XDo('click 1');
  Ok := WaitEvent(VPAG_EVENT_MOUSE_DOWN, Ev) and (Ev.MouseButton = VPAG_MB_LEFT) and
        (Ev.MouseX = 320) and (Ev.MouseY = 240);
  Check(Ok, 'MOUSE_DOWN left: ' + EvText(Ev));
  Ok := WaitEvent(VPAG_EVENT_MOUSE_UP, Ev) and (Ev.MouseButton = VPAG_MB_LEFT);
  Check(Ok, 'MOUSE_UP left: ' + EvText(Ev));
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check((MX = 320) and (MY = 240) and (Btn = 0) and (Inside = VPAG_TRUE),
        'GetMouseState -> (' + IntToStr(MX) + ',' + IntToStr(MY) + ') buttons=' +
        IntToStr(Btn) + ' inside=' + IntToStr(Inside));

  { --- teclado --- }
  XDo('key a');
  Ok := WaitEvent(VPAG_EVENT_KEY_DOWN, Ev, VPAGK_A) and (Ev.UnicodeChar = Ord('a')) and
        (Ev.Modifiers = 0);
  Check(Ok, 'KEY_DOWN a: ' + EvText(Ev));
  Ok := WaitEvent(VPAG_EVENT_KEY_UP, Ev, VPAGK_A);
  Check(Ok, 'KEY_UP a: ' + EvText(Ev));
  XDo('key shift+b');
  Ok := WaitEvent(VPAG_EVENT_KEY_DOWN, Ev, VPAGK_A + 1) and (Ev.UnicodeChar = Ord('B')) and
        ((Ev.Modifiers and VPAG_MOD_SHIFT) <> 0);
  Check(Ok, 'KEY_DOWN Shift+b: ' + EvText(Ev));
  Drain;
  XDo('key ctrl+x');
  Ok := WaitEvent(VPAG_EVENT_KEY_DOWN, Ev, Ord('X')) and ((Ev.Modifiers and VPAG_MOD_CTRL) <> 0);
  Check(Ok, 'KEY_DOWN Ctrl+x: ' + EvText(Ev));
  Drain;
  XDo('key Right');
  Ok := WaitEvent(VPAG_EVENT_KEY_DOWN, Ev, VPAGK_RIGHT) and (Ev.UnicodeChar = 0);
  Check(Ok, 'KEY_DOWN Right: ' + EvText(Ev));
  Drain;

  { --- modificadores vivos --- }
  XDo('keydown shift');
  Check((Iface.GetModifiers() and VPAG_MOD_SHIFT) <> 0, 'GetModifiers with Shift held');
  XDo('keyup shift');
  Check(Iface.GetModifiers() = 0, 'GetModifiers with nothing held');
  Drain;

  { --- puntero fuera --- }
  XDo('mousemove 1500 1100');
  Drain;
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check(Inside = VPAG_FALSE, 'Inside = 0 with the pointer outside the window');

  { --- SetMousePos --- }
  Iface.SetMousePos(100, 100);
  XSync(Dpy, 0);
  SleepMs(100);
  QueryPointer(RX, RY);
  Check((RX = 201) and (RY = 201), 'SetMousePos(100,100) warped the pointer to (' +
        IntToStr(RX) + ',' + IntToStr(RY) + ')');
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check((MX = 100) and (MY = 100), 'GetMouseState right after SetMousePos -> (' +
        IntToStr(MX) + ',' + IntToStr(MY) + ')');
  Drain;
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check((MX = 100) and (MY = 100) and (Inside = VPAG_TRUE),
        'and after the warp event -> (' + IntToStr(MX) + ',' + IntToStr(MY) + ') inside=' + IntToStr(Inside));

  { --- cursor del sistema --- }
  Iface.ShowMouse(VPAG_FALSE);
  Iface.ShowMouse(VPAG_TRUE);
  Check(Iface.GraphResult() = VPAG_OK, 'ShowMouse(0) / ShowMouse(1)');

  { --- cierre de ventana --- }
  wmProtocols := XInternAtom(Dpy, 'WM_PROTOCOLS', 0);
  wmDelete := XInternAtom(Dpy, 'WM_DELETE_WINDOW', 0);
  FillChar(XEv, SizeOf(XEv), 0);
  XEv.xclient._type := ClientMessage;
  XEv.xclient.window := Win;
  XEv.xclient.message_type := wmProtocols;
  XEv.xclient.format := 32;
  XEv.xclient.data.l[0] := clong(wmDelete);
  XEv.xclient.data.l[1] := CurrentTime;
  XSendEvent(Dpy, Win, 0, NoEventMask, @XEv);
  XSync(Dpy, 0);
  Ok := WaitEvent(VPAG_EVENT_CLOSE, Ev);
  Check(Ok, 'WM_DELETE_WINDOW -> CLOSE');

  Check(Iface.Shutdown() = VPAG_OK, 'Shutdown');
  Check(dlclose(H) = 0, 'dlclose');
  XCloseDisplay(Dpy);

  if Failures = 0 then
  begin
    Writeln('input_test: PASS');
    Exit(0);
  end;
  Writeln('input_test: FAIL (', Failures, ')');
  Exit(1);
end;

begin
  Halt(Run);
end.
