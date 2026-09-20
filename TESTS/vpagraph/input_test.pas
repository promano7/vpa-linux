{ input_test - Fase 6 de WAYLAND.md: la parte del nucleo de T6.6 y T6.7.

  Un programa -Mtp (mismas opciones que vpa.cfg) que lee teclado y raton
  COMO LO HACEN UNIT/KEYBOARD.PAS y UNIT/MOUSE.PAS, compilado dos veces:

    - input_test_core   : vpagraph + vpagraph_input (nucleo + plugin);
    - input_test_direct : ptcgraph + ptccrt + ptcmouse (-dDIRECT; las
                          unidades del ejecutable de hoy, build/ptcunits).

  Los dos reciben de xdotool exactamente las mismas pulsaciones y los mismos
  movimientos de raton bajo Xvfb, e imprimen lo que ven en lineas 'key ...'
  y 'mouse ...'. El Makefile compara esas lineas con diff: la traduccion del
  nucleo tiene que dar lo mismo que ptccrt, tecla a tecla, incluidos los
  modificadores de la ultima pulsacion y el indicador de Ctrl-Alt-X.

  La variante del nucleo hace ademas, ANTES de abrir la ventana, las pruebas
  que no necesitan servidor grafico (eventos sinteticos con
  VPAInputFeedEvent): lo que xdotool no puede producir con el teclado 'us'
  de Xvfb -el '+' de una distribucion es/de/fr, que llega con tecla
  indefinida (D-09)-, el boton [X], el bufer lleno y el nucleo sin backend.

  Sin gestor de ventanas el foco es PointerRoot: las teclas van a la ventana
  que esta bajo el puntero, y por eso lo primero es meter el raton dentro.
  ptc no emite evento por el PRIMER movimiento que ve (solo guarda la
  posicion previa), asi que ese primer movimiento no se comprueba.

  Salida 0 si todo fue bien; 1 si algo fallo. }
program input_test;

uses
  {$IFDEF DIRECT}cthreads, ptcgraph, ptccrt, ptcmouse,
  {$ELSE}vpagraph, vpagraph_loader, vpagraph_input,{$ENDIF}
  baseunix, unix;

var
  Failures : integer;
  gd, gm   : integer;

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

procedure SleepMs(Ms: longint);
var
  ts : TTimeSpec;
begin
  ts.tv_sec := Ms div 1000;
  ts.tv_nsec := (Ms mod 1000) * 1000000;
  fpnanosleep(@ts, nil);
end;

procedure XDo(const Args: string);
begin
  Flush(Output);
  if fpSystem('xdotool ' + Args) <> 0 then
    Check(False, 'xdotool ' + Args);
  SleepMs(120);
end;

function Hex4(w: word): string;
const
  H : string[16] = '0123456789ABCDEF';
begin
  Hex4 := '$' + H[(w shr 12) + 1] + H[((w shr 8) and 15) + 1] +
          H[((w shr 4) and 15) + 1] + H[(w and 15) + 1];
end;

{ --- las cuatro lecturas, por las que difieren las dos variantes --- }

function TKeyPressed: boolean;
begin
  {$IFDEF DIRECT}TKeyPressed := ptccrt.KeyPressed;{$ELSE}TKeyPressed := VPAKeyPressed;{$ENDIF}
end;

function TReadKey: char;
begin
  {$IFDEF DIRECT}TReadKey := ptccrt.ReadKey;{$ELSE}TReadKey := VPAReadKey;{$ENDIF}
end;

function TFlags: byte;
begin
  {$IFDEF DIRECT}TFlags := PTCLastKbdFlags;{$ELSE}TFlags := VPALastKbdFlags;{$ENDIF}
end;

function TQuit: boolean;
begin
  {$IFDEF DIRECT}TQuit := PTCQuitNoSave;{$ELSE}TQuit := VPAQuitNoSave;{$ENDIF}
end;

procedure TMouse(var x, y, b: longint);
begin
  {$IFDEF DIRECT}ptcmouse.GetMouseState(x, y, b);{$ELSE}VPAGetMouseState(x, y, b);{$ENDIF}
end;

{ Igual que RawReadKey de KEYBOARD.PAS: ascii en el byte bajo, extendida en
  el alto. }
function ReadWord: word;
var
  c : char;
begin
  c := TReadKey;
  if c = #0 then ReadWord := word(ord(TReadKey)) shl 8
  else ReadWord := ord(c);
end;

{ Pulsa Spec con xdotool e imprime TODO lo que llega al bufer. }
procedure Key(const Spec: string);
var
  s : string;
  n : integer;
begin
  XDo('key ' + Spec);
  s := '';
  n := 0;
  while TKeyPressed and (n < 8) do
  begin
    s := s + ' ' + Hex4(ReadWord);
    Inc(n);
  end;
  if n = 0 then s := ' -';
  Writeln('key ', Spec, ' ->', s, ' flags=', TFlags, ' quit=', TQuit);
end;

procedure Mouse(const What: string);
var
  x, y, b : longint;
begin
  x := -1; y := -1; b := -1;
  TMouse(x, y, b);
  Writeln('mouse ', What, ' -> ', x, ',', y, ' buttons=', b);
end;

{ La ventana de 640x480 esta en (0,0) de una pantalla de 1024x768. }
procedure LiveTests;
var
  i : integer;
  c : char;
begin
  XDo('mousemove 5 5');
  XDo('mousemove 320 240');
  Mouse('move 320 240');

  { imprimibles y sus Shift }
  Key('a'); Key('z'); Key('shift+a'); Key('1'); Key('shift+1'); Key('space');
  Key('minus'); Key('equal'); Key('plus'); Key('slash'); Key('period');
  Key('bracketleft'); Key('semicolon'); Key('grave'); Key('asciitilde');
  Key('KP_Add'); Key('KP_Subtract'); Key('KP_Multiply'); Key('KP_Divide');
  Key('KP_5'); Key('KP_Enter');
  { edicion y cursor, solas y con Shift }
  Key('Escape'); Key('BackSpace'); Key('Tab'); Key('Return'); Key('Insert');
  Key('Delete'); Key('Home'); Key('End'); Key('Prior'); Key('Next');
  Key('Left'); Key('Up'); Key('Right'); Key('Down');
  Key('shift+Tab'); Key('shift+Return'); Key('shift+Left'); Key('shift+Insert');
  Key('shift+Escape'); Key('shift+BackSpace');
  { funcion: sola, Shift, Ctrl, Alt }
  for i := 1 to 12 do
  begin
    c := chr(ord('0') + i mod 10);
    if i < 10 then
    begin
      Key('F' + c); Key('shift+F' + c); Key('ctrl+F' + c); Key('alt+F' + c);
    end
    else
    begin
      Key('F1' + c); Key('shift+F1' + c); Key('ctrl+F1' + c); Key('alt+F1' + c);
    end;
  end;
  { Ctrl y Alt con letras }
  for c := 'a' to 'z' do
  begin
    Key('ctrl+' + c);
    Key('alt+' + c);
  end;
  { Ctrl y Alt con la fila de numeros }
  for c := '0' to '9' do
  begin
    Key('ctrl+' + c);
    Key('alt+' + c);
  end;
  Key('alt+minus'); Key('alt+equal');
  { los arreglos de VPA }
  Key('ctrl+KP_Add'); Key('ctrl+KP_Subtract'); Key('ctrl+minus');
  Key('ctrl+shift+equal'); Key('ctrl+plus'); Key('ctrl+equal');
  Key('ctrl+Tab'); Key('ctrl+Up'); Key('ctrl+Down'); Key('ctrl+Left');
  Key('ctrl+Right'); Key('ctrl+Home'); Key('ctrl+End'); Key('ctrl+Prior');
  Key('ctrl+Next'); Key('ctrl+Return'); Key('ctrl+BackSpace'); Key('ctrl+Escape');
  Key('ctrl+bracketleft'); Key('ctrl+backslash'); Key('ctrl+bracketright');
  Key('alt+Up'); Key('alt+Down'); Key('alt+Left'); Key('alt+Right');
  Key('alt+Home'); Key('alt+Tab'); Key('alt+Return');
  Key('alt+x'); Key('ctrl+alt+x'); Key('alt+x');
  Key('ctrl+shift+a'); Key('alt+shift+a'); Key('ctrl+alt+a');
  { un modificador solo no produce tecla, pero si cambia los indicadores }
  Key('shift'); Key('ctrl'); Key('alt'); Key('a');
  { varias teclas de golpe: orden del bufer }
  Key('h o l a Left F5 alt+m');

  { raton }
  XDo('mousemove 100 50');  Mouse('move 100 50');
  XDo('mousemove 639 479'); Mouse('move 639 479');
  XDo('mousedown 1');       Mouse('down 1');
  XDo('mousemove 200 300'); Mouse('drag 200 300');
  XDo('mousedown 3');       Mouse('down 3');
  XDo('mouseup 1');         Mouse('up 1');
  XDo('mouseup 3');         Mouse('up 3');
  XDo('mousedown 2');       Mouse('down 2');
  XDo('mouseup 2');         Mouse('up 2');
  XDo('click 1');           Mouse('click 1');
  { sondear el raton no se come las teclas }
  XDo('key q w');
  Mouse('after q w');
  Key('e');
end;

{$IFNDEF DIRECT}
{ --- pruebas del nucleo que no tienen equivalente en ptc --- }

procedure Feed(EventType, KeyCode, Uni, Mods: longword);
var
  Ev : TVPAGraphEvent;
begin
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.StructSize := SizeOf(Ev);
  Ev.EventType := EventType;
  Ev.KeyCode := KeyCode;
  Ev.UnicodeChar := Uni;
  Ev.Modifiers := Mods;
  VPAInputFeedEvent(Ev);
end;

procedure SyntheticTests;
var
  i, n : integer;
begin
  Writeln('-- synthetic, no backend');
  Check(not VPAInputReady, 'no backend: VPAInputReady is False');
  Check(not VPAKeyPressed, 'no backend: VPAKeyPressed is False');
  Check(VPAReadKey = #0, 'no backend: VPAReadKey returns #0 without blocking');
  Check(VPAMouseInside, 'no backend: VPAMouseInside is True (do not block auto-scroll logic)');

  { D-09: el '+' de es/de/fr llega con tecla indefinida }
  Check(VPATranslateKey(VPAGK_UNDEFINED, Ord('+'), VPAG_MOD_CTRL) = $9000,
        'Ctrl-+ with undefined key code (es/de/fr layouts) -> $9000');
  Check(VPATranslateKey(VPAGK_EQUALS, Ord('+'), VPAG_MOD_CTRL or VPAG_MOD_SHIFT) = $9000,
        'Ctrl-Shift-= producing + (us/ru layouts) -> $9000');
  Check(VPATranslateKey(VPAGK_ADD, Ord('+'), VPAG_MOD_CTRL) = $9000, 'Ctrl-grey+ -> $9000');
  Check(VPATranslateKey(VPAGK_MINUS, Ord('-'), VPAG_MOD_CTRL) = $8E00, 'Ctrl-- main row -> $8E00');
  Check(VPATranslateKey(VPAGK_SUBTRACT, Ord('-'), VPAG_MOD_CTRL) = $8E00, 'Ctrl-grey- -> $8E00');
  Check(VPATranslateKey(VPAGK_MINUS, 0, VPAG_MOD_CTRL) = 31, 'Ctrl-- with no character -> #31, as TP7');
  Check(VPATranslateKey(VPAGK_UNDEFINED, Ord('+'), 0) = Ord('+'), '+ with undefined key code -> +');
  Check(VPATranslateKey(VPAGK_UNDEFINED, 241, 0) = 0, 'a character above 127 produces nothing');
  Check(VPATranslateKey(VPAGK_SHIFT, 0, VPAG_MOD_SHIFT) = 0, 'Shift alone produces nothing');

  { boton [X] = Alt-X guardando, aunque antes hubiera un Ctrl-Alt-X }
  VPAInputReset;
  Feed(VPAG_EVENT_KEY_DOWN, VPAGK_CONTROL, 0, VPAG_MOD_CTRL);
  Feed(VPAG_EVENT_KEY_DOWN, VPAGK_A + 23, 0, VPAG_MOD_ALT);   { el evento NO trae Ctrl }
  Check(VPAQuitNoSave, 'Alt-X with Ctrl tracked as held, not flagged in the event -> quit without saving');
  Feed(VPAG_EVENT_KEY_UP, VPAGK_CONTROL, 0, 0);
  Feed(VPAG_EVENT_CLOSE, 0, 0, 0);
  Check((not VPAQuitNoSave) and (VPALastKbdFlags = 0), 'window close -> quit saving, flags 0');
  VPAInputReset;
  Feed(VPAG_EVENT_KEY_DOWN, VPAGK_A + 23, 0, VPAG_MOD_ALT);
  Check(not VPAQuitNoSave, 'Alt-X after Ctrl was released -> quit saving');

  { bufer lleno: 255 caracteres utiles; una extendida entra entera o no entra }
  VPAInputReset;
  for i := 1 to 254 do Feed(VPAG_EVENT_KEY_DOWN, VPAGK_A, Ord('a'), 0);
  Feed(VPAG_EVENT_KEY_DOWN, VPAGK_F1, 0, 0);          { necesita 2, queda 1 }
  Feed(VPAG_EVENT_KEY_DOWN, VPAGK_A + 1, Ord('b'), 0); { cabe }
  Feed(VPAG_EVENT_KEY_DOWN, VPAGK_A + 2, Ord('c'), 0); { ya no }
  { sin backend VPAReadKey no espera: se puede vaciar el bufer con el }
  n := 0;
  for i := 1 to 254 do
    if VPAReadKey = 'a' then Inc(n);
  Check(n = 254, 'full buffer: 254 characters kept in order');
  Check(VPAReadKey = 'b', 'full buffer: F1 did not fit and left no half key; b did');
  Check(VPAReadKey = #0, 'full buffer: c was dropped');
  VPAInputReset;
end;
{$ENDIF}

begin
  Failures := 0;
  {$IFDEF DIRECT}
  { ptccrt arrastra a crt, que se queda con Output y parte las lineas a 80
    columnas: se devuelve a la salida estandar para poder comparar. }
  Assign(Output, '');
  Rewrite(Output);
  {$ELSE}
  SyntheticTests;
  {$ENDIF}

  Writeln('-- live, under Xvfb with xdotool');
  gd := D8bit;
  gm := m640x480;
  InitGraph(gd, gm, '');
  gm := GraphResult;
  Check(gm = grOk, 'InitGraph');
  if gm <> grOk then Halt(1);
  {$IFNDEF DIRECT}
  Check(VPAInputReady, 'VPAInputReady after InitGraph');
  {$ENDIF}
  SetColor(White);
  OutTextXY(10, 10, 'input_test');
  SleepMs(300);

  LiveTests;

  {$IFNDEF DIRECT}
  { con la ventana suspendida no hay a quien pedir eventos }
  RestoreCrtMode;
  Check(not VPAInputReady, 'suspended: VPAInputReady is False');
  SetGraphMode(GetGraphMode);
  Check(VPAInputReady, 'resumed: VPAInputReady is True again');
  XDo('mousemove 5 5');
  XDo('mousemove 320 240');
  Key('r');
  {$ENDIF}

  CloseGraph;
  {$IFNDEF DIRECT}
  Check(not VPAInputReady, 'after CloseGraph: VPAInputReady is False');
  {$ENDIF}

  if Failures = 0 then Writeln('input_test: PASS')
  else Writeln('input_test: FAIL (', Failures, ')');
  if Failures <> 0 then Halt(1);
end.
