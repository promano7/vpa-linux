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
  ScrW, ScrH : TVPAGraphInt32;
  Btn    : TVPAGraphUInt32;
  Inside : TVPAGraphUInt8;
  Ok     : Boolean;
  I, Bad : Integer;
  FirstBad: AnsiString;
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

  { --- Fase 10, T10.1: tamano de pantalla ANTES de Init, sin ventana --- }
  ScrW := 0; ScrH := 0;
  R := Iface.GetScreenSize(@ScrW, @ScrH);
  Check((R = VPAG_OK) and (ScrW = 1600) and (ScrH = 1200),
    'GetScreenSize before Init -> ' + IntToStr(R) + ', ' + IntToStr(ScrW) + 'x' + IntToStr(ScrH));
  { con el compositor a x2 la pantalla mide la mitad, en unidades logicas }
  Sh('swaymsg -q output HEADLESS-1 scale 2');
  ScrW := 0; ScrH := 0;
  R := Iface.GetScreenSize(@ScrW, @ScrH);
  Check((R = VPAG_OK) and (ScrW = 800) and (ScrH = 600),
    'GetScreenSize before Init, output scale 2 -> ' + IntToStr(R) + ', ' + IntToStr(ScrW) + 'x' + IntToStr(ScrH));
  Sh('swaymsg -q output HEADLESS-1 scale 1');

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
  { con la consola abierta contesta ella (valor publicado al abrir) }
  ScrW := 0; ScrH := 0;
  R := Iface.GetScreenSize(@ScrW, @ScrH);
  Check((R = VPAG_OK) and (ScrW = 1600) and (ScrH = 1200),
    'GetScreenSize with the window open -> ' + IntToStr(R) + ', ' + IntToStr(ScrW) + 'x' + IntToStr(ScrH));

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

  { --- SetMousePos con escala NO entera: ida y vuelta exacta ---
    Las flechas del mapa hacen MoveMouseTo(MouseX+-1, ...) y leen MouseX del
    evento de movimiento que vuelve: tiene que volver el mismo pixel.
    OJO: aqui solo se prueba la cuenta en coma flotante de SDL (el sway 1.9
    del contenedor no aplica el warp; ver la cabecera). La otra mitad -el
    wl_fixed de 1/256 con que un compositor con wp_pointer_warp_v1 devuelve
    la posicion, truncando hacia abajo- no se puede ejercitar aqui: por eso
    TSDLConsole.MoveMouseTo apunta al CENTRO del pixel y no a su borde. }
  Sh('swaymsg -q resize set 1087 816');
  SleepMs(500);
  Drain;
  MoveTo(1000, 700);
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX <> 500);
  Check(Ok, 'window resized, scale no longer 2: (1000,700) -> ' + EvText(Ev));
  Drain;
  Bad := 0;
  FirstBad := '';
  I := 1;
  while I < 640 do
  begin
    Iface.SetMousePos(I, (I * 3) div 4);
    if not (WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX = I) and
            (Ev.MouseY = (I * 3) div 4)) then
    begin
      if Bad = 0 then
        FirstBad := ' first: asked (' + IntToStr(I) + ',' + IntToStr((I * 3) div 4) +
                    ') got ' + EvText(Ev);
      Inc(Bad);
    end;
    Inc(I, 1);
  end;
  Check(Bad = 0, 'SetMousePos round trip at a non-integer scale: ' +
        IntToStr(Bad) + ' of 639 off' + FirstBad);
  Drain;

  { --- Fase 10: la ventana FLOTANTE es siempre 4:3 (SDL_SetWindowAspectRatio).
        El compositor concede 1600x600 y la ventana se queda en 800x600, sin
        bandas: es lo que hace KWin cuando encoge una ventana que no cabe
        entre la barra de titulo y el panel (visto por Pablo). --- }
  Sh('swaymsg -q resize set 1600 600');
  Sh('swaymsg -q move absolute position 0 0');   { resize conserva el centro }
  SleepMs(500);
  MoveTo(400, 300);
  Drain;
  MoveTo(700, 450);
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX = 560) and (Ev.MouseY = 360);
  Check(Ok, 'floating 1600x600 becomes 800x600, no bands: (700,450) -> (560,360): ' + EvText(Ev));
  Drain;

  { --- Fase 10, T10.4: pantalla completa en una salida 16:9. La imagen 4:3
        mide 1440x1080 y queda centrada, con bandas de 240 px. --- }
  Sh('swaymsg -q output HEADLESS-1 mode 1920x1080');
  Check(Iface.SetFullscreen(VPAG_TRUE) = VPAG_OK, 'SetFullscreen(1)');
  SleepMs(800);
  MoveTo(500, 500);
  Drain;
  MoveTo(960, 540);
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX = 320) and (Ev.MouseY = 240);
  Check(Ok, 'fullscreen 1920x1080: (960,540) -> (320,240): ' + EvText(Ev));
  MoveTo(1679, 1079);
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX = 639) and (Ev.MouseY = 479);
  Check(Ok, 'fullscreen 1920x1080: (1679,1079) -> (639,479): ' + EvText(Ev));
  Drain;
  MoveTo(100, 540);
  Ok := not WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev);
  Check(Ok, 'fullscreen 1920x1080: nothing from the side band: ' + EvText(Ev));
  { T10.2: las bandas no son de VPA. Como en la consola X11 en pantalla
    completa, de ahi no sale ningun evento: un clic en la banda no llega a
    nadie (antes llegaba como clic en la columna 0 del mapa) y uno dentro de
    la imagen llega en su sitio (ver TSDLConsole.MouseAt). Las bandas solo
    existen donde el tamano lo manda el protocolo; la ventana flotante es
    siempre 4:3. No se prueba el boton pulsado en la banda que entra en la
    imagen: el sway 1.9 del contenedor no entrega los 'cursor set' mientras
    hay un boton pulsado (visto con WAYLAND_DEBUG). }
  Sh('swaymsg -q seat seat0 cursor press button1');
  Sh('swaymsg -q seat seat0 cursor release button1');
  Ok := not WaitEvent(VPAG_EVENT_MOUSE_DOWN, Ev);
  Check(Ok, 'fullscreen 1920x1080: a click in the side band reaches nobody: ' + EvText(Ev));
  Drain;
  MoveTo(640, 540);
  Drain;
  Sh('swaymsg -q seat seat0 cursor press button1');
  Ok := WaitEvent(VPAG_EVENT_MOUSE_DOWN, Ev) and (Ev.MouseButton = VPAG_MB_LEFT) and
        (Ev.MouseX = 177) and (Ev.MouseY = 240);
  Check(Ok, 'fullscreen 1920x1080: click inside the image at (640,540) -> (177,240): ' + EvText(Ev));
  Sh('swaymsg -q seat seat0 cursor release button1');
  Ok := WaitEvent(VPAG_EVENT_MOUSE_UP, Ev);
  Check(Ok, 'fullscreen 1920x1080: and its release: ' + EvText(Ev));
  Drain;
  { En la banda el puntero esta FUERA para VPA. Entrando por la derecha la
    ultima posicion entregada es del panel (MouseX>471) y con Inside = 1 el
    auto-scroll del mapa no paraba nunca (visto por Pablo en KWin). }
  MoveTo(1600, 540);             { dentro del panel derecho de VPA }
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX > 471);
  Check(Ok, 'fullscreen 1920x1080: (1600,540) is in the side panel: ' + EvText(Ev));
  MoveTo(1800, 540);             { banda derecha }
  SleepMs(100);
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check((Inside = VPAG_FALSE) and (MX > 471),
    'fullscreen 1920x1080: Inside = 0 in the right band, last X = ' + IntToStr(MX));
  MoveTo(960, 540);
  SleepMs(100);
  Iface.GetMouseState(@MX, @MY, @Btn, @Inside);
  Check(Inside = VPAG_TRUE, 'fullscreen 1920x1080: Inside = 1 back in the image');
  Drain;
  Check(Iface.SetFullscreen(VPAG_FALSE) = VPAG_OK, 'SetFullscreen(0)');
  SleepMs(800);
  Sh('swaymsg -q output HEADLESS-1 mode 1600x1200');

  { --- Fase 10, T10.5: HiDPI. Salida a x2 y ventana de 640x480 logicos, o
        sea 1280x960 fisicos, que es justo la consola al 200 %: cada pixel de
        VPA son 2x2 fisicos exactos. Rayas verticales de dos colores y una
        captura del compositor: no puede haber colores intermedios. --- }
  Sh('swaymsg -q resize set 640 480');
  Sh('swaymsg -q move absolute position 0 0');
  Sh('swaymsg -q output HEADLESS-1 scale 2');
  Iface.SetColor(15);
  I := 0;
  while I < 100 do
  begin
    Iface.Line(I, 0, I, 99);
    Inc(I, 2);
  end;
  SleepMs(800);
  MoveTo(10, 10);
  Drain;
  MoveTo(320, 240);
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX = 320) and (Ev.MouseY = 240);
  Check(Ok, 'HiDPI x2: (320,240) logical -> (320,240) surface: ' + EvText(Ev));
  MoveTo(639, 479);
  Ok := WaitEvent(VPAG_EVENT_MOUSE_MOVE, Ev) and (Ev.MouseX = 639) and (Ev.MouseY = 479);
  Check(Ok, 'HiDPI x2: (639,479) logical -> (639,479) surface: ' + EvText(Ev));
  Drain;
  Sh('grim -t ppm /tmp/input_test_hidpi.ppm');
  Check(fpSystem(ExtractFilePath(VKbd) + 'blur-check.py /tmp/input_test_hidpi.ppm 0 0 400 200') = 0,
    'HiDPI x2: the image reaches the screen without interpolation (blur-check.py)');
  { Y con la ventana a 320x240 logicos (640x480 fisicos) cada pixel de VPA
    es UN pixel fisico: las rayas de 1 px solo sobreviven si SDL dibuja a la
    resolucion fisica (SDL_WINDOW_HIGH_PIXEL_DENSITY). Si dibujara a la
    logica y el compositor ampliara, se perderia la mitad de las columnas. }
  Sh('swaymsg -q resize set 320 240');
  Sh('swaymsg -q move absolute position 0 0');
  SleepMs(800);
  Sh('grim -t ppm /tmp/input_test_hidpi.ppm');
  Check(fpSystem(ExtractFilePath(VKbd) + 'blur-check.py /tmp/input_test_hidpi.ppm 0 0 100 100 1') = 0,
    'HiDPI x2: drawn at the physical resolution, 1 px stripes survive (blur-check.py)');
  DeleteFile('/tmp/input_test_hidpi.ppm');
  Sh('swaymsg -q output HEADLESS-1 scale 1');

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
