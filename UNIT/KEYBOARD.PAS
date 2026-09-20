Unit	Keyboard;		(* Keyboard functions *)
{$V-}


Interface

const	KbdShft	= 3;
	KbdCtrl	= 4;
	KbdAlt	= 8;

function FastKeyPressed : boolean;
function KeyPressed : boolean;
function ReadKey : word;
function PreviewKey : word; 	{ use only if KeyPressed }
function KbdFlags : byte;
function KbdQuitNoSave : boolean;  { True si la ultima salida pedida fue Ctrl-Alt-X (sin guardar) }
procedure CpuNap;   { cede CPU brevemente (port Linux: evita el busy-loop) }

Implementation

{ Fase 6 de WAYLAND.md (T6.6): el teclado sale del nucleo VPAGraph
  (vpagraph_input: eventos del backend traducidos a los scancodes de Turbo
  Pascal), no de ptccrt. crt es de la RTL y no enlaza X11. }
uses crt, Mouse, vpagraph, vpagraph_input{$IFDEF UNIX}, baseunix, unixtype{$ENDIF};

var
  bufKey  : word;      { buffer de retroceso de 1 tecla (para PreviewKey/peek) }
  bufFull : boolean;

procedure CpuNap;
{$IFDEF UNIX}
  var ts : TTimeSpec;
{$ENDIF}
  begin
    {$IFDEF UNIX}
    ts.tv_sec  := 0;
    ts.tv_nsec := 5 * 1000000;   { 5 ms: ~200 Hz, suficiente para raton/teclado }
    fpnanosleep(@ts, nil);
    {$ENDIF}
  end;

{ Las dos lecturas crudas. Con backend activo las teclas vienen de la ventana
  grafica. Sin el (antes de InitGraph, tras CloseGraph o entre RestoreCrtMode
  y SetGraphMode) no hay ventana que las reciba y VPAReadKey devolveria #0 sin
  esperar: se lee de la terminal con crt, que es lo que hacia ptccrt. }
function BackendKeyPressed : boolean;
  begin
    if VPAInputReady then BackendKeyPressed := VPAKeyPressed
    else BackendKeyPressed := crt.KeyPressed;
  end;

function BackendReadKey : char;
  begin
    if VPAInputReady then BackendReadKey := VPAReadKey
    else BackendReadKey := crt.ReadKey;
  end;

{ lee una tecla cruda y la convierte al 'word' de VPA:
  ascii normal -> byte bajo; tecla extendida (#0 + scancode) -> scancode en byte alto }
function RawReadKey : word;
  var c : char;
      k : word;
  begin
    c := BackendReadKey;
    if c = #0 then
      k := word(ord(BackendReadKey)) shl 8
    else
      k := ord(c);
    {$IFDEF UNIX}
    { T0.4 de WAYLAND.md: Ctrl-F12 ($8A00) vuelca el framebuffer a disco cuando
      VPA_GRAPH_DUMP esta definida. Es el unico punto por el que pasan todas las
      teclas de VPA, asi que basta con interceptar aqui.
      La tecla NO se consume: $8A00 no lo usa ninguna pantalla de VPA, de modo
      que sigue su camino y cae en el 'else' de los case, que es exactamente lo
      que ya ocurre hoy con cualquier tecla desconocida. Consumirla obligaria a
      devolver otra cosa o a esperar a la siguiente, y eso si cambiaria el
      comportamiento (PreviewKey se llama tras KeyPressed y no puede bloquear). }
    if (k = $8A00) and vpagraph.VPADumpEnabled then
      vpagraph.VPADumpFrame;
    {$ENDIF}
    RawReadKey := k;
  end;

function FastKeyPressed : boolean;
  begin FastKeyPressed := bufFull or BackendKeyPressed; end;

function KeyPressed : boolean;
  { Linux: sondea el raton aqui para generar eventos (mEvent) en cada espera de
    entrada. FastKeyPressed NO lo hace (bucles de animacion que solo abortan con tecla). }
  begin
    Mouse.PollMouse;
    KeyPressed := bufFull or BackendKeyPressed;
  end;

function ReadKey : word;
  var r : word;
  begin
    if bufFull then begin r := bufKey; bufFull := False; end
    else r := RawReadKey;
    ReadKey := r;
  end;

function PreviewKey : word;   { use only if KeyPressed }
  begin
    if not bufFull then begin bufKey := RawReadKey; bufFull := True; end;
    PreviewKey := bufKey;
  end;

function KbdFlags : byte;
  begin
    { Estado ACTUAL de modificadores (Shift=3, Ctrl=4, Alt=8), consultado al
      backend al estilo de la BIOS DOS 0040:0017. Asi funciona tanto en atajos de
      teclado como en raton+modificador (zoom del mapa con Shift/Ctrl). Sin
      backend activo VPAKbdModifiers devuelve los de la ultima pulsacion. }
    KbdFlags := VPAKbdModifiers;
  end;

function KbdQuitNoSave : boolean;
  begin
    { Indicador fijado al pulsar Alt+X: True si era Ctrl-Alt-X (salir sin guardar). }
    KbdQuitNoSave := VPAQuitNoSave;
  end;

begin
  bufFull := False;
end.
