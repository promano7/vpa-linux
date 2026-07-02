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

uses ptccrt, Mouse{$IFDEF UNIX}, xfocus, baseunix, unixtype{$ENDIF};

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

{ lee una tecla cruda y la convierte al 'word' de VPA:
  ascii normal -> byte bajo; tecla extendida (#0 + scancode) -> scancode en byte alto }
function RawReadKey : word;
  var c : char;
  begin
    c := ptccrt.ReadKey;
    if c = #0 then
      RawReadKey := word(ord(ptccrt.ReadKey)) shl 8
    else
      RawReadKey := ord(c);
  end;

function FastKeyPressed : boolean;
  begin FastKeyPressed := bufFull or ptccrt.KeyPressed; end;

function KeyPressed : boolean;
  { Linux: sondea el raton aqui para generar eventos (mEvent) en cada espera de
    entrada. FastKeyPressed NO lo hace (bucles de animacion que solo abortan con tecla). }
  begin
    Mouse.PollMouse;
    KeyPressed := bufFull or ptccrt.KeyPressed;
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
    {$IFDEF UNIX}
    { Estado ACTUAL de modificadores (Shift=3, Ctrl=4, Alt=8), consultado a X11 al
      estilo de la BIOS DOS 0040:0017. Asi funciona tanto en atajos de teclado como
      en raton+modificador (zoom del mapa con Shift/Ctrl). Sin conexion X se recurre
      al ultimo evento de tecla que expone el ptccrt vendorizado. }
    if xfocus.XReady then
      KbdFlags := xfocus.KbdModifiers
    else
      KbdFlags := ptccrt.PTCLastKbdFlags;
    {$ELSE}
    KbdFlags := ptccrt.PTCLastKbdFlags;
    {$ENDIF}
  end;

function KbdQuitNoSave : boolean;
  begin
    { Indicador fijado al pulsar Alt+X: True si era Ctrl-Alt-X (salir sin guardar). }
    KbdQuitNoSave := ptccrt.PTCQuitNoSave;
  end;

begin
  bufFull := False;
end.
