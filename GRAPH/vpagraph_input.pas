{ ===========================================================================
  vpagraph_input.pas - Teclado y raton del NUCLEO sobre los eventos crudos
  del backend. Fase 6 de WAYLAND.md: la parte del nucleo de T6.6 y T6.7
  (decisiones D-09 y D-10).

  El plugin solo entrega eventos (PollEvent): codigo de tecla fisico VPAGK_*,
  caracter Unicode y modificadores. Todo lo que VPA entiende por "teclado"
  vive aqui, una sola vez para todos los backends:

    - la traduccion a los scancodes de Turbo Pascal 7. Es la tabla de
      VENDOR/ptccrt.pp (GetKeyEvents) en su modo kmTP7, que es el unico que
      VPA ha usado nunca (nadie asigna KeyMode), CON los arreglos de VPA:
      F11/F12, Ctrl-Tab, Ctrl-Arriba/Abajo y Alt-flechas tambien en kmTP7;
      Ctrl-'+' y Ctrl-'-' por CARACTER y no por tecla (3.67.5, D-09); el
      boton [X] de la ventana como Alt-X; el indicador de Ctrl-Alt-X;
    - el bufer de teclas (#0 + scancode para las extendidas, como ReadKey
      de Turbo Pascal);
    - los modificadores de la ultima pulsacion (PTCLastKbdFlags).

  Una sola bomba. En ptc, ptccrt y ptcmouse sacaban cada uno SUS eventos de
  la cola (NextEvent con filtro de tipo). PollEvent de la ABI no filtra, asi
  que aqui hay una unica bomba, Pump, que lo vacia todo: las teclas van al
  bufer y el raton lo recuerda el propio plugin (GetMouseState devuelve lo
  ultimo que paso por PollEvent). Da igual quien bombee, teclado o raton:
  ninguno pierde nada del otro. Pump llama a Present antes de vaciar la
  cola, que es el contrato de la ABI: la pantalla tiene que estar completa
  justo cuando VPA se para a mirar la entrada.

  El bufer es de 256 caracteres y, como el de la BIOS, descarta cuando se
  llena. El de ptccrt era de 64, pero alli las teclas no leidas se quedaban
  en la cola de ptc mientras solo se sondeaba el raton; aqui ese sondeo las
  trae al bufer, y de ahi el margen.

  Sin backend activo (antes de InitGraph, tras CloseGraph o con la ventana
  suspendida) VPAInputReady es False, VPAKeyPressed devuelve False,
  VPAReadKey devuelve #0 SIN esperar y el raton no se mueve. ptccrt, en esa
  situacion, leia de la terminal con crt; esa decision es de
  UNIT/KEYBOARD.PAS, no de esta unidad.

  Los tipos de la ABI se toman de vpagraph_loader y NO de un segundo
  $I vpagraph_abi.inc: dos inclusiones son dos tipos distintos.
  =========================================================================== }
unit vpagraph_input;

{$MODE OBJFPC}{$H+}

interface

uses
  vpagraph_loader;

var
  { Modificadores (Shift=3, Ctrl=4, Alt=8, estilo BIOS 0040:0017) de la
    ultima PULSACION procesada. Es el PTCLastKbdFlags de ptccrt. }
  VPALastKbdFlags : Byte = 0;
  { Se fija EXACTAMENTE al traducir Alt-X: True si Ctrl estaba pulsado
    (Ctrl-Alt-X = salir SIN guardar). El boton [X] de la ventana lo pone a
    False (= Alt-X, salir guardando). Es el PTCQuitNoSave de ptccrt. }
  VPAQuitNoSave   : Boolean = False;

{ True si hay un backend activo al que pedirle eventos. }
function VPAInputReady: Boolean;

{ Teclado, con la forma de ptccrt: ReadKey devuelve #0 y despues el
  scancode para las teclas extendidas. VPAReadKey espera (1 ms por vuelta,
  como ptccrt) mientras haya backend. }
function VPAKeyPressed: Boolean;
function VPAReadKey: Char;

{ Estado ACTUAL de los modificadores (GetModifiers de la ABI), no el de la
  ultima pulsacion: raton+modificador. Sustituye a xfocus.KbdModifiers. }
function VPAKbdModifiers: Byte;

{ Raton, con la forma de ptcmouse y en coordenadas de SUPERFICIE (0..639,
  0..479): el desescalado es asunto del plugin. Sustituye ademas a
  xfocus.MapMouseToSurface / MapSurfaceToWindow, que desaparecen. }
procedure VPAGetMouseState(var X, Y, Buttons: LongInt);
procedure VPASetMousePos(X, Y: LongInt);
procedure VPAShowMouse(Show: Boolean);

{ True si el puntero esta dentro de la ventana. Consulta viva al servidor:
  solo para VPA2.PAS (auto-scroll). Sin backend devuelve True, que es lo
  que hacia xfocus.PointerInsideWindow sin conexion X. }
function VPAMouseInside: Boolean;

{ Las dos piezas de la bomba, publicas para poder probarlas sin servidor
  grafico (TESTS/vpagraph/input_test.pas):

  VPATranslateKey   la tabla, pura: 0 si la tecla no produce nada; $00cc si
                    produce el caracter cc; $ss00 si produce la extendida de
                    scancode ss (el mismo word que maneja UNIT/KEYBOARD.PAS).
                    CtrlDown es el estado rastreado de la tecla Ctrl.
  VPAInputFeedEvent procesa UN evento como si lo hubiera entregado el
                    backend: actualiza el bufer y los indicadores. }
function VPATranslateKey(KeyCode, UnicodeChar, Modifiers: LongWord): Word;
procedure VPAInputFeedEvent(const Ev: TVPAGraphEvent);

{ Vacia el bufer de teclas y olvida el estado rastreado. }
procedure VPAInputReset;

implementation

uses
  BaseUnix, vpagraph;

{ ---------------------------------------------------------------------------
  Bufer de teclas
  --------------------------------------------------------------------------- }
var
  KeyBuffer : array[0..255] of Char;
  KeyBufHead : Integer = 0;
  KeyBufTail : Integer = 0;
  { Estado real de la tecla Ctrl, rastreado por sus propios KEY_DOWN/KEY_UP,
    para no depender de que el evento de la X lo refleje (PTCCtrlDown). }
  CtrlDown : Boolean = False;

function KeyBufEmpty: Boolean;
begin
  Result := KeyBufHead = KeyBufTail;
end;

function KeyBufFree: Integer;
begin
  Result := High(KeyBuffer) - ((KeyBufTail - KeyBufHead + Length(KeyBuffer)) mod Length(KeyBuffer));
end;

procedure KeyBufPut(Ch: Char);
begin
  KeyBuffer[KeyBufTail] := Ch;
  KeyBufTail := (KeyBufTail + 1) mod Length(KeyBuffer);
end;

{ Una tecla extendida son DOS caracteres y entran los dos o ninguno: medio
  scancode en el bufer descuadraria todas las lecturas siguientes. }
procedure KeyBufAddKey(K: Word);
begin
  if K = 0 then Exit;
  if (K and $FF) <> 0 then
  begin
    if KeyBufFree >= 1 then KeyBufPut(Chr(K and $FF));
  end
  else if KeyBufFree >= 2 then
  begin
    KeyBufPut(#0);
    KeyBufPut(Chr(K shr 8));
  end;
end;

function KeyBufGet: Char;
begin
  Result := #0;
  if KeyBufHead <> KeyBufTail then
  begin
    Result := KeyBuffer[KeyBufHead];
    KeyBufHead := (KeyBufHead + 1) mod Length(KeyBuffer);
  end;
end;

procedure VPAInputReset;
begin
  KeyBufHead := 0;
  KeyBufTail := 0;
  CtrlDown := False;
  VPALastKbdFlags := 0;
  VPAQuitNoSave := False;
end;

{ ---------------------------------------------------------------------------
  La tabla. Mismo orden que ptccrt: Alt gana a Ctrl y Ctrl a Shift.
  --------------------------------------------------------------------------- }
const
  { Scancode de Alt-letra, de la A a la Z (la fila del teclado de PC). }
  AltLetter : array[0..25] of Byte =
    (30, 48, 46, 32, 18, 33, 34, 35, 23, 36, 37, 38, 50,   { A..M }
     49, 24, 25, 16, 19, 31, 20, 22, 47, 17, 45, 21, 44);  { N..Z }
  { Alt-1..9, 0: 120..129 en el orden de la fila, con el cero al final. }
  AltDigit  : array[0..9] of Byte = (129, 120, 121, 122, 123, 124, 125, 126, 127, 128);

function Ext(ScanCode: Byte): Word; inline;
begin
  Result := Word(ScanCode) shl 8;
end;

{ Teclas de edicion y cursor: identicas con y sin Shift. }
function NavKey(KeyCode: LongWord): Word;
begin
  case KeyCode of
    VPAGK_INSERT:   Result := Ext(82);
    VPAGK_DELETE:   Result := Ext(83);
    VPAGK_LEFT:     Result := Ext(75);
    VPAGK_UP:       Result := Ext(72);
    VPAGK_RIGHT:    Result := Ext(77);
    VPAGK_DOWN:     Result := Ext(80);
    VPAGK_HOME:     Result := Ext(71);
    VPAGK_END:      Result := Ext(79);
    VPAGK_PAGEUP:   Result := Ext(73);
    VPAGK_PAGEDOWN: Result := Ext(81);
  else
    Result := 0;
  end;
end;

function Printable(UnicodeChar: LongWord): Word;
begin
  if (UnicodeChar >= 32) and (UnicodeChar <= 127) then
    Result := UnicodeChar
  else
    Result := 0;
end;

function VPATranslateKey(KeyCode, UnicodeChar, Modifiers: LongWord): Word;
begin
  Result := 0;

  if (Modifiers and VPAG_MOD_ALT) <> 0 then
  begin
    case KeyCode of
      VPAGK_F1..VPAGK_F1 + 9: Result := Ext(104 + (KeyCode - VPAGK_F1));
      VPAGK_ZERO..VPAGK_NINE: Result := Ext(AltDigit[KeyCode - VPAGK_ZERO]);
      VPAGK_MINUS:            Result := Ext(130);
      VPAGK_EQUALS:           Result := Ext(131);
      VPAGK_A..VPAGK_Z:       Result := Ext(AltLetter[KeyCode - VPAGK_A]);
      { Alt-flechas: paneo del mapa y ajustes +-100. Es el comportamiento
        real del TP7 de DOS; ptccrt solo las daba en kmGO32 (arreglo VPA). }
      VPAGK_UP:               Result := Ext(152);
      VPAGK_LEFT:             Result := Ext(155);
      VPAGK_RIGHT:            Result := Ext(157);
      VPAGK_DOWN:             Result := Ext(160);
    end;
    Exit;
  end;

  if (Modifiers and VPAG_MOD_CTRL) <> 0 then
  begin
    { Ctrl-'+' y Ctrl-'-' (ultimo / primer turno). En DOS solo los daban
      el + y el - GRISES, como $90 y $8E, y eso espera VPA. Se decide por
      el CARACTER (D-09): el '+' de la fila principal llega con tecla
      indefinida en es/de/fr y como Shift+EQUALS en us/ru, y el '-' de la
      fila principal daria #31. Un unico camino para todos (3.67.5). }
    if UnicodeChar = Ord('+') then Exit(Ext(144));
    if UnicodeChar = Ord('-') then Exit(Ext(142));
    case KeyCode of
      VPAGK_ESCAPE:           Result := 27;
      VPAGK_F1..VPAGK_F1 + 9: Result := Ext(94 + (KeyCode - VPAGK_F1));
      VPAGK_F1 + 10:          Result := Ext(137);   { Ctrl-F11 }
      VPAGK_F12:              Result := Ext(138);   { Ctrl-F12: volcado (T0.4) }
      VPAGK_TWO:              Result := Ext(3);
      VPAGK_SIX:              Result := 30;
      VPAGK_MINUS:            Result := 31;
      VPAGK_BACKSPACE:        Result := 127;
      VPAGK_A..VPAGK_Z:       Result := 1 + (KeyCode - VPAGK_A);
      VPAGK_OPENBRACKET:      Result := 27;
      VPAGK_BACKSLASH:        Result := 28;
      VPAGK_CLOSEBRACKET:     Result := 29;
      VPAGK_ENTER:            Result := 10;
      VPAGK_LEFT:             Result := Ext(115);
      VPAGK_RIGHT:            Result := Ext(116);
      VPAGK_HOME:             Result := Ext(119);
      VPAGK_END:              Result := Ext(117);
      VPAGK_PAGEUP:           Result := Ext(132);
      VPAGK_PAGEDOWN:         Result := Ext(118);
      { Ctrl-Tab (galaxia completa) y Ctrl-Arriba/Abajo (objeto anterior /
        siguiente): ptccrt solo las daba fuera de kmTP7 (arreglo VPA). }
      VPAGK_TAB:              Result := Ext(148);
      VPAGK_UP:               Result := Ext(141);
      VPAGK_DOWN:             Result := Ext(145);
    end;
    Exit;
  end;

  { F11/F12 tambien en kmTP7 (arreglo VPA): $8500 F11 (GoTurn), $8700
    Shift-F11, $8900 Ctrl-F11. }
  if (Modifiers and VPAG_MOD_SHIFT) <> 0 then
  begin
    case KeyCode of
      VPAGK_ESCAPE:           Result := 27;
      VPAGK_F1..VPAGK_F1 + 9: Result := Ext(84 + (KeyCode - VPAGK_F1));
      VPAGK_F1 + 10:          Result := Ext(135);
      VPAGK_F12:              Result := Ext(136);
      VPAGK_BACKSPACE:        Result := 8;
      VPAGK_TAB:              Result := Ext(15);
      VPAGK_ENTER:            Result := 13;
    else
      Result := NavKey(KeyCode);
      if Result = 0 then Result := Printable(UnicodeChar);
    end;
    Exit;
  end;

  case KeyCode of
    VPAGK_ESCAPE:           Result := 27;
    VPAGK_F1..VPAGK_F1 + 9: Result := Ext(59 + (KeyCode - VPAGK_F1));
    VPAGK_F1 + 10:          Result := Ext(133);
    VPAGK_F12:              Result := Ext(134);
    VPAGK_BACKSPACE:        Result := 8;
    VPAGK_TAB:              Result := 9;
    VPAGK_ENTER:            Result := 13;
  else
    Result := NavKey(KeyCode);
    if Result = 0 then Result := Printable(UnicodeChar);
  end;
end;

{ ---------------------------------------------------------------------------
  La bomba
  --------------------------------------------------------------------------- }
procedure VPAInputFeedEvent(const Ev: TVPAGraphEvent);
begin
  case Ev.EventType of
    VPAG_EVENT_CLOSE:
      begin
        { El boton [X] equivale a Alt-X: salir guardando (arreglo VPA). }
        VPALastKbdFlags := 0;
        VPAQuitNoSave := False;
        KeyBufAddKey(Ext(45));
      end;
    VPAG_EVENT_KEY_UP:
      if Ev.KeyCode = VPAGK_CONTROL then CtrlDown := False;
    VPAG_EVENT_KEY_DOWN:
      begin
        if Ev.KeyCode = VPAGK_CONTROL then CtrlDown := True;
        VPALastKbdFlags := Byte(Ev.Modifiers and
          (VPAG_MOD_SHIFT or VPAG_MOD_CTRL or VPAG_MOD_ALT));
        if ((Ev.Modifiers and VPAG_MOD_ALT) <> 0) and (Ev.KeyCode = VPAGK_A + 23) then
          VPAQuitNoSave := ((Ev.Modifiers and VPAG_MOD_CTRL) <> 0) or CtrlDown;
        KeyBufAddKey(VPATranslateKey(Ev.KeyCode, Ev.UnicodeChar, Ev.Modifiers));
      end;
    { El raton lo recuerda el plugin; RESIZE y ENTER/LEAVE no le dicen nada
      a VPA. }
  end;
end;

function VPAInputReady: Boolean;
begin
  Result := VPAGraphActiveInterface <> nil;
end;

procedure Pump;
var
  Iface: PVPAGraphInterface;
  Ev: TVPAGraphEvent;
begin
  Iface := VPAGraphActiveInterface;
  if Iface = nil then Exit;
  Iface^.Present();
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.StructSize := SizeOf(Ev);
  { Un codigo negativo es un fallo del backend: no hay a quien contarselo
    desde aqui (GetLastError lo conserva) y seguir sondeando seria un bucle. }
  while Iface^.PollEvent(@Ev) = 1 do
    VPAInputFeedEvent(Ev);
end;

function VPAKeyPressed: Boolean;
begin
  Pump;
  Result := not KeyBufEmpty;
end;

function VPAReadKey: Char;
var
  Req: TTimeSpec;
begin
  while not VPAKeyPressed do
  begin
    if not VPAInputReady then Exit(#0);
    Req.tv_sec := 0;
    Req.tv_nsec := 1000000;
    fpNanoSleep(@Req, nil);
  end;
  Result := KeyBufGet;
end;

function VPAKbdModifiers: Byte;
var
  Iface: PVPAGraphInterface;
begin
  Iface := VPAGraphActiveInterface;
  if Iface <> nil then
    Result := Byte(Iface^.GetModifiers())
  else
    Result := VPALastKbdFlags;
end;

procedure VPAGetMouseState(var X, Y, Buttons: LongInt);
var
  Iface: PVPAGraphInterface;
  MX, MY: TVPAGraphInt32;
  MB: TVPAGraphUInt32;
begin
  Iface := VPAGraphActiveInterface;
  if Iface = nil then Exit;   { X, Y y Buttons se quedan como estaban }
  Pump;
  MX := 0; MY := 0; MB := 0;
  Iface^.GetMouseState(@MX, @MY, @MB, nil);
  X := MX;
  Y := MY;
  Buttons := LongInt(MB);
end;

procedure VPASetMousePos(X, Y: LongInt);
var
  Iface: PVPAGraphInterface;
begin
  Iface := VPAGraphActiveInterface;
  if Iface <> nil then Iface^.SetMousePos(X, Y);
end;

procedure VPAShowMouse(Show: Boolean);
var
  Iface: PVPAGraphInterface;
begin
  Iface := VPAGraphActiveInterface;
  if Iface <> nil then
    if Show then Iface^.ShowMouse(VPAG_TRUE) else Iface^.ShowMouse(VPAG_FALSE);
end;

function VPAMouseInside: Boolean;
var
  Iface: PVPAGraphInterface;
  Inside: TVPAGraphUInt8;
begin
  Result := True;
  Iface := VPAGraphActiveInterface;
  if Iface = nil then Exit;
  Inside := VPAG_TRUE;
  Iface^.GetMouseState(nil, nil, nil, @Inside);
  Result := Inside <> VPAG_FALSE;
end;

end.
