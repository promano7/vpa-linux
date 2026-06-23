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
    {$IFDEF UNIX}xfocus.DbgKey(r);{$ENDIF}
    ReadKey := r;
  end;

function PreviewKey : word;   { use only if KeyPressed }
  begin
    if not bufFull then begin bufKey := RawReadKey; bufFull := True; end;
    PreviewKey := bufKey;
  end;

function KbdFlags : byte;
  begin
    { TODO: ptccrt no expone el estado Shift/Ctrl/Alt del teclado.
      Se devuelve 0 (sin modificadores) hasta engancharlo al backend ptc. }
    KbdFlags := 0;
  end;

begin
  bufFull := False;
end.
