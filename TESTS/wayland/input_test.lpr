{ input_test (Wayland) - el bloque de teclado y raton de la ABI (T2.11) en el
  plugin Wayland: Fase 9 de WAYLAND.md (T9.1 a T9.4 y T9.6). Es la pareja de
  TESTS/x11/input_test.lpr y comprueba lo mismo, mas el teclado que en X11 ya
  estaba hecho y aqui es nuevo (teclado numerico, puntuacion, '+' y '-' con
  Ctrl por CARACTER, D-09/D-23).

  Corre dentro de TESTS/wayland/con-sway.sh (sway sin pantalla + puntero
  virtual), con la ventana a 200% (1280x960) flotante en (0,0) de una salida
  de 1600x1200. Raton con swaymsg; teclas con TESTS/wayland/vkbd.py, un
  teclado virtual con la distribucion xkb de verdad ('us', 'es' y 'ru', la de
  Alexander: T9.2), y un par con wtype (el camino de TESTS/capture.sh).

  NO comprueba que SetMousePos mueva el puntero fisico: el sway 1.9 del
  contenedor no aplica el warp y SDL emite igual el movimiento sintetico
  (R12), asi que solo se comprueba lo que ve VPA.

  Uso:  con-sway.sh input_test <ruta del .so> <ruta de vkbd.py>
  Salida 0 si todo fue bien; 1 si algo fallo. }
program input_test;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, dl, ctypes, unix, baseunix;

{$I vpagraph_abi.inc}

var
  Failures: Integer = 0;
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

procedure Sh(const Cmd: AnsiString);
begin
  if fpSystem(Cmd) <> 0 then
    Check(False, Cmd);
  SleepMs(150);
end;

{ wtype crea un teclado virtual por invocacion, con su keymap, y lo destruye
  al salir: sin la pausa previa la tecla llega pegada al alta del teclado,
  SDL aun no tiene el foco de teclado (enter) y se pierde, no siempre
  (medido; es la misma pausa de TESTS/capture.sh). }
procedure WType(const Args: AnsiString);
begin
  Sh('wtype -s 300 ' + Args + ' -s 100');
end;

procedure MoveTo(X, Y: Integer);
begin
  Sh('swaymsg -q seat seat0 cursor set ' + IntToStr(X) + ' ' + IntToStr(Y));
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

var
  Path   : AnsiString;
  H      : Pointer;
  Entry  : TVPAGraphGetInterfaceProc;
  Params : TVPAGraphInitParams;
  R      : TVPAGraphInt32;
  Ev     : TVPAGraphEvent;
  MX, MY : TVPAGraphInt32;
  Btn    : TVPAGraphUInt32;
  Inside : TVPAGraphUInt8;
  Ok     : Boolean;
  VKbd   : AnsiString;

type
  TKeyCase = record
    Combo: AnsiString;
    Code, Uni, Mods: TVPAGraphUInt32;
  end;

function K(const Combo: AnsiString; Code, Uni, Mods: TVPAGraphUInt32): TKeyCase;
begin
  Result.Combo := Combo; Result.Code := Code; Result.Uni := Uni; Result.Mods := Mods;
end;

{ Manda todas las combinaciones con UN teclado virtual de esa distribucion
  (vkbd.py solo manda la tecla y la mascara de modificadores, no las teclas
  Shift/Ctrl: cada combinacion es exactamente un KEY_DOWN y un KEY_UP) y
  comprueba los KEY_DOWN en orden: codigo, caracter y modificadores. }
procedure Layout(const Name: AnsiString; const Cases: array of TKeyCase);
var
  Cmd: AnsiString;
  J: Integer;
begin
  Drain;
  Cmd := 'python3 ' + VKbd + ' ' + Name;
  for J := 0 to High(Cases) do
    Cmd := Cmd + ' ' + Cases[J].Combo;
  Sh(Cmd);
  for J := 0 to High(Cases) do
  begin
    Ok := WaitEvent(VPAG_EVENT_KEY_DOWN, Ev) and (Ev.KeyCode = Cases[J].Code) and
          (Ev.UnicodeChar = Cases[J].Uni) and (Ev.Modifiers = Cases[J].Mods);
    Check(Ok, Name + ' ' + Cases[J].Combo + ': ' + EvText(Ev));
  end;
  Drain;
end;

function Run: Integer;
begin
  if ParamCount < 2 then
  begin
    Writeln('usage: input_test <libvpagraph-wayland.so> <vkbd.py>');
    Exit(2);
  end;
  Path := ParamStr(1);
  VKbd := ParamStr(2);
  Writeln('input_test: ', Path);

  H := dlopen(PAnsiChar(Path), RTLD_NOW);
  Check(H <> nil, 'dlopen(RTLD_NOW) ' + Path);
  if H = nil then Exit(1);
  Pointer(Entry) := dlsym(H, VPAGRAPH_ENTRY_POINT);
  if Entry = nil then Exit(1);
  FillChar(Iface, SizeOf(Iface), 0);
  R := Entry(VPAGRAPH_ABI_VERSION, SizeOf(Iface), @Iface);
  Check(R = VPAG_OK, 'VPAGraph_GetInterface -> ' + IntToStr(R));
  if R <> VPAG_OK then Exit(1);

  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize := SizeOf(Params);
  Params.Width := 640;
  Params.Height := 480;
  Params.ScalePercent := 200;
  Params.WindowTitle := 'input_test';
  R := Iface.Init(@Params);
  Check(R = VPAG_OK, 'Init at 200% -> ' + IntToStr(R) + ' (' + ErrText + ')');
  if R <> VPAG_OK then Exit(1);
  SleepMs(800);
  Drain;

  { --- raton: movimiento y clic, escalados a superficie --- }
  MoveTo(10, 10);
  Drain;
  MoveTo(640, 480);
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX = 320) and (Ev.MouseY = 240);
  Check(Ok, 'MOUSE_MOVE at (640,480) window -> (320,240) surface: ' + EvText(Ev));
  Drain;
  Sh('swaymsg -q seat seat0 cursor press button1');
  Ok := WaitEvent(VPAG_EVENT_MOUSE_DOWN, Ev) and (Ev.MouseButton = VPAG_MB_LEFT) and
        (Ev.MouseX = 320) and (Ev.MouseY = 240);
  Check(Ok, 'MOUSE_DOWN left: ' + EvText(Ev));
  Sh('swaymsg -q seat seat0 cursor release button1');
  Ok := WaitEvent(VPAG_EVENT_MOUSE_UP, Ev) and (Ev.MouseButton = VPAG_MB_LEFT);
  Check(Ok, 'MOUSE_UP left: ' + EvText(Ev));
  Sh('swaymsg -q seat seat0 cursor press button3');
  Ok := WaitEvent(VPAG_EVENT_MOUSE_DOWN, Ev) and (Ev.MouseButton = VPAG_MB_RIGHT);
  Check(Ok, 'MOUSE_DOWN right: ' + EvText(Ev));
  Sh('swaymsg -q seat seat0 cursor release button3');
  Drain;
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check((MX = 320) and (MY = 240) and (Btn = 0) and (Inside = VPAG_TRUE),
        'GetMouseState -> (' + IntToStr(MX) + ',' + IntToStr(MY) + ') buttons=' +
        IntToStr(Btn) + ' inside=' + IntToStr(Inside));

  { --- teclado, con distribuciones de verdad (vkbd.py) --- }
  Layout('us', [
    K('A',                 VPAGK_A,       Ord('a'), 0),
    K('shift+B',           VPAGK_A + 1,   Ord('B'), VPAG_MOD_SHIFT),
    K('caps+C',            VPAGK_A + 2,   Ord('C'), 0),
    K('ctrl+X',            VPAGK_A + 23,  Ord('x'), VPAG_MOD_CTRL),
    K('alt+X',             VPAGK_A + 23,  Ord('x'), VPAG_MOD_ALT),
    { Ctrl-+ / Ctrl-- por CARACTER (3.67.5, D-09): en 'us' el '+' es Shift-= }
    K('ctrl+shift+EQUAL',  $3D,           Ord('+'), VPAG_MOD_CTRL or VPAG_MOD_SHIFT),
    K('ctrl+MINUS',        VPAGK_MINUS,   Ord('-'), VPAG_MOD_CTRL),
    K('ctrl+KPPLUS',       $6B,           Ord('+'), VPAG_MOD_CTRL),
    K('ctrl+KPMINUS',      $6D,           Ord('-'), VPAG_MOD_CTRL),
    { teclas que el prototipo de la Fase 8 no traducia }
    K('ESC',               VPAGK_ESCAPE,  27, 0),
    K('ENTER',             VPAGK_ENTER,   13, 0),
    K('TAB',               VPAGK_TAB,     9, 0),
    K('shift+TAB',         VPAGK_TAB,     9, VPAG_MOD_SHIFT),
    K('BACKSPACE',         VPAGK_BACKSPACE, 8, 0),
    K('SPACE',             VPAGK_SPACE,   32, 0),
    K('COMMA',             $2C,           Ord(','), 0),
    K('DOT',               $2E,           Ord('.'), 0),
    K('SLASH',             $2F,           Ord('/'), 0),
    K('shift+SLASH',       $2F,           Ord('?'), VPAG_MOD_SHIFT),
    K('SEMICOLON',         $3B,           Ord(';'), 0),
    K('APOSTROPHE',        $DE,           39, 0),
    K('GRAVE',             $C0,           Ord('`'), 0),
    K('LEFTBRACE',         $5B,           Ord('['), 0),
    K('BACKSLASH',         $5C,           Ord('\'), 0),
    K('RIGHTBRACE',        $5D,           Ord(']'), 0),
    K('5',                 Ord('5'),      Ord('5'), 0),
    K('shift+5',           Ord('5'),      Ord('%'), VPAG_MOD_SHIFT),
    { teclado numerico: con y sin BloqNum, como XK_KP_1 / XK_KP_End en X11 }
    K('num+KP1',           $61,           Ord('1'), 0),
    K('KP1',               VPAGK_END,     0, 0),
    K('num+KP5',           $65,           Ord('5'), 0),
    K('KP5',               VPAGK_CLEAR,   0, 0),
    K('num+KPDOT',         $6E,           Ord('.'), 0),
    K('KPDOT',             $7F,           0, 0),
    K('KPASTERISK',        $6A,           Ord('*'), 0),
    K('KPSLASH',           $6F,           Ord('/'), 0),
    K('KPENTER',           VPAGK_ENTER,   13, 0)]);
  { espanola: '+' es tecla propia y no tiene codigo ptc; '-' esta donde el
    '/' de 'us'; Shift-7 es '/'; AltGr-2 es '@' }
  Layout('es', [
    K('RIGHTBRACE',        VPAGK_UNDEFINED, Ord('+'), 0),
    K('ctrl+RIGHTBRACE',   VPAGK_UNDEFINED, Ord('+'), VPAG_MOD_CTRL),
    K('ctrl+SLASH',        VPAGK_MINUS,   Ord('-'), VPAG_MOD_CTRL),
    K('shift+7',           $2F,           Ord('/'), VPAG_MOD_SHIFT),
    K('altgr+2',           Ord('2'),      Ord('@'), 0),
    K('alt+X',             VPAGK_A + 23,  Ord('x'), VPAG_MOD_ALT)]);
  { rusa (la de Alexander), sin grupo latino: las letras conservan el codigo
    de la tecla (Alt-X sigue siendo Alt-X) y el caracter es el cirilico }
  Layout('ru', [
    K('alt+X',             VPAGK_A + 23,  $447, VPAG_MOD_ALT),
    K('ctrl+S',            VPAGK_A + 18,  $44B, VPAG_MOD_CTRL),
    K('ctrl+shift+EQUAL',  $3D,           Ord('+'), VPAG_MOD_CTRL or VPAG_MOD_SHIFT),
    K('ctrl+MINUS',        VPAGK_MINUS,   Ord('-'), VPAG_MOD_CTRL),
    K('F',                 VPAGK_A + 5,   $430, 0)]);
  WType('-k F11');
  Ok := WaitEvent(VPAG_EVENT_KEY_DOWN, Ev, VPAGK_F1 + 10) and (Ev.UnicodeChar = 0);
  Check(Ok, 'KEY_DOWN F11: ' + EvText(Ev));
  Ok := WaitEvent(VPAG_EVENT_KEY_UP, Ev, VPAGK_F1 + 10) and (Ev.UnicodeChar = 0);
  Check(Ok, 'KEY_UP F11: ' + EvText(Ev));
  WType('-k Right');
  Ok := WaitEvent(VPAG_EVENT_KEY_DOWN, Ev, VPAGK_RIGHT) and (Ev.UnicodeChar = 0);
  Check(Ok, 'KEY_DOWN Right: ' + EvText(Ev));
  Drain;

  { --- modificadores vivos --- }
  Sh('wtype -s 300 -M shift -s 800 -m shift &');
  SleepMs(500);
  Check((Iface.GetModifiers() and VPAG_MOD_SHIFT) <> 0, 'GetModifiers with Shift held');
  SleepMs(1000);
  Check(Iface.GetModifiers() = 0, 'GetModifiers with nothing held');
  Drain;

  { --- puntero fuera --- }
  MoveTo(1500, 1100);
  Drain;
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check(Inside = VPAG_FALSE, 'Inside = 0 with the pointer outside the window');
  MoveTo(400, 400);
  Drain;
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check((Inside = VPAG_TRUE) and (MX = 200) and (MY = 200),
        'Inside = 1 again at (' + IntToStr(MX) + ',' + IntToStr(MY) + ')');

  { --- SetMousePos: lo que ve VPA (ver la cabecera) --- }
  Iface.SetMousePos(100, 100);
  SleepMs(100);
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check((MX = 100) and (MY = 100), 'GetMouseState right after SetMousePos -> (' +
        IntToStr(MX) + ',' + IntToStr(MY) + ')');
  Drain;

  { --- cursor del sistema --- }
  Iface.ShowMouse(VPAG_FALSE);
  Iface.ShowMouse(VPAG_TRUE);
  Check(Iface.GraphResult() = VPAG_OK, 'ShowMouse(0) / ShowMouse(1)');

  { --- cierre de ventana: xdg_toplevel.close -> CLOSE (T9.6) --- }
  Sh('swaymsg -q kill');
  Ok := WaitEvent(VPAG_EVENT_CLOSE, Ev);
  Check(Ok, 'xdg_toplevel.close -> CLOSE');

  Check(Iface.Shutdown() = VPAG_OK, 'Shutdown');
  Check(dlclose(H) = 0, 'dlclose');

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
