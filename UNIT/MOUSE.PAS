Unit	Mouse;
{$V-}

{$A-}
Interface

const	EvMouseMove	= 1;
	EvLtPress	= 2;
	EvLtRelease	= 4;
	EvRtPress	= 8;
	EvRtRelease	= $10;
	EvCtPress	= $20;
	EvCtRelease	= $40;
	AllEvents	= $7F;
	DisableHandler	= 0;
	LeftButton	= 1;
	RightButton	= 2;
	CenterButton	= 4;

type	PointerShape	= array [1..2,1..16] of word;

const	MousePresent		: boolean = True;   { Linux/ptc: siempre hay puntero; /K lo desactiva }
	MouseHandlerInstalled	: boolean = False;
	MouseDisabled		: boolean = True;

var	MouseX,MouseY		: integer;
	MouseButtons		: word;
	MouseEvent		: word;
	StatusBufferSize	: word;

{$IFDEF DPMI}
	StatusBufferSel,
	StatusBufferSeg		: word;
{$ELSE}
const	StatusBuffer		: pointer = nil;
{$ENDIF}

procedure EnableMouse;
procedure DisableMouse;
procedure ShowMouse;
procedure HideMouse;
procedure SuspendMouse;
procedure ResumeMouse;
procedure HookMouseEvent (event:byte; handler:pointer);
procedure UnHookMouseEvent (event:byte);
procedure SetPointerShape (var shape:PointerShape; hx,hy:word);
procedure SetMouseSensitivity (mx,my,mt:byte);
procedure SetMouseRange (x1,y1,x2,y2:word);
procedure MoveMouse (x,y:word);
procedure AllocateStatusBuffer;

{$IFDEF DPMI}
procedure DeAllocateStatusBuffer;
{$ENDIF}

procedure SaveMouseStatus;
procedure RestoreMouseStatus;
procedure PollMouse;   { Linux: el bucle principal debe llamar a esto }
function PointerInsideWindow : boolean;   { False si el puntero salio de la ventana (auto-scroll) }
function PointerInsideRange : boolean;    { False si el puntero real esta fuera del rango de SetMouseRange }


Implementation

{ Fase 6 de WAYLAND.md (T6.7): el raton sale del nucleo VPAGraph
  (vpagraph_input) y llega ya en coordenadas de superficie (0..639, 0..479):
  el escalado de la ventana es asunto del backend. }
uses vpagraph_input;

type TMouseProc = procedure;

procedure NullHandler; begin end;

var
  HandlerTable : array[0..6] of TMouseProc;
  prevX, prevY : integer;
  prevButtons  : word;
  rangeSet     : boolean;
  rX1, rY1, rX2, rY2 : integer;   { rango permitido del cursor (clamp por software) }
  outOfRange   : boolean;   { el ultimo PollMouse tuvo que recortar la posicion real }

{ indice 0..6 del primer bit activo del evento (1,2,4,...,$40) }
function EventIndex(evbit: word): integer;
  var idx: integer;
  begin
    idx := 0;
    if evbit = 0 then begin EventIndex := -1; Exit; end;
    while (evbit and 1) = 0 do begin evbit := evbit shr 1; inc(idx); end;
    EventIndex := idx;
  end;

procedure Dispatch(evbit: word);
  var idx: integer; p: TMouseProc;
  begin
    MouseEvent := evbit;
    idx := EventIndex(evbit);
    if (idx >= 0) and (idx <= 6) then
    begin
      p := HandlerTable[idx];
      if Assigned(p) then p;
    end;
  end;

procedure EnableMouse;
  begin
    if MouseHandlerInstalled then Exit;
    MousePresent := True;   { como ptcmouse.InitMouse, que nunca fallaba: siempre hay puntero }
    VPAShowMouse(True);   { mostrar el puntero del sistema (la diana propia aun no va) }
    MouseHandlerInstalled := True;
    MouseDisabled := False;
    MouseX := 160; MouseY := 100; MouseButtons := 0;
    prevX := 160; prevY := 100; prevButtons := 0;
  end;

procedure DisableMouse;
  begin
    if not MouseHandlerInstalled then Exit;
    VPAShowMouse(False);
    MouseHandlerInstalled := False;
  end;

procedure ShowMouse;  begin VPAShowMouse(True); end;
procedure HideMouse;  begin VPAShowMouse(False); end;
procedure SuspendMouse; begin VPAShowMouse(False); end;
procedure ResumeMouse;  begin VPAShowMouse(True); end;

procedure HookMouseEvent (event:byte; handler:pointer);
  var idx: integer;
  begin
    idx := EventIndex(event);
    if (idx >= 0) and (idx <= 6) then HandlerTable[idx] := TMouseProc(handler);
  end;

procedure UnHookMouseEvent (event:byte);
  begin
    HookMouseEvent(event, @NullHandler);
  end;

procedure SetPointerShape (var shape:PointerShape; hx,hy:word);
  begin
    { el backend gestiona su propio cursor; la forma personalizada no se porta }
  end;

procedure SetMouseSensitivity (mx,my,mt:byte);
  begin
    { sin equivalente directo necesario; no-op }
  end;

procedure SetMouseRange (x1,y1,x2,y2:word);
  begin
    { la ABI no expone limitacion de rango: se emula por software en PollMouse }
    rX1 := x1; rY1 := y1; rX2 := x2; rY2 := y2;
    rangeSet := True;
  end;

procedure MoveMouse (x,y:word);
  begin
    VPASetMousePos(x, y);   { coords de superficie: el backend las lleva a la ventana }
    MouseX := x; MouseY := y;   { la posicion logica sigue en coords de superficie }
  end;

procedure AllocateStatusBuffer;
  begin
    { estado del driver DOS: no aplica en Linux }
  end;

procedure SaveMouseStatus;
  begin
  end;

procedure RestoreMouseStatus;
  begin
  end;

procedure PollMouse;
  var lx, ly, lb: longint; mx, my: integer; btns: word;
  begin
    if MouseDisabled or (not MouseHandlerInstalled) then Exit;
    VPAGetMouseState(lx, ly, lb);
    mx := lx; my := ly; btns := word(lb) and $07;
    outOfRange := False;
    if rangeSet then
    begin
      outOfRange := (mx < rX1) or (mx > rX2) or (my < rY1) or (my > rY2);
      if mx < rX1 then mx := rX1 else if mx > rX2 then mx := rX2;
      if my < rY1 then my := rY1 else if my > rY2 then my := rY2;
      { sin warp del puntero fisico: VPA dibuja su propia diana, y el warp
        provocaba un bucle de realimentacion que fijaba el raton en el borde }
    end;
    MouseX := mx; MouseY := my; MouseButtons := btns;
    if (mx <> prevX) or (my <> prevY) then
    begin
      Dispatch(EvMouseMove);
    end;
    if ((btns and LeftButton)<>0)   and ((prevButtons and LeftButton)=0)   then Dispatch(EvLtPress);
    if ((btns and LeftButton)=0)    and ((prevButtons and LeftButton)<>0)  then Dispatch(EvLtRelease);
    if ((btns and RightButton)<>0)  and ((prevButtons and RightButton)=0)  then Dispatch(EvRtPress);
    if ((btns and RightButton)=0)   and ((prevButtons and RightButton)<>0) then Dispatch(EvRtRelease);
    if ((btns and CenterButton)<>0) and ((prevButtons and CenterButton)=0) then Dispatch(EvCtPress);
    if ((btns and CenterButton)=0)  and ((prevButtons and CenterButton)<>0)then Dispatch(EvCtRelease);
    prevX := mx; prevY := my; prevButtons := btns;
  end;

function PointerInsideWindow : boolean;
  begin
    PointerInsideWindow := VPAMouseInside;
  end;

{ En DOS el driver paraba el puntero en el borde del rango (el mapa, 0..479):
  para hacer auto-scroll a la derecha habia que empujar contra x=479. Aqui el
  puntero real sigue hasta el panel derecho y PollMouse solo recorta MouseX a
  479, asi que todo el panel cumplia MouseX>471 y el mapa no paraba de moverse.
  El bucle principal pregunta esto para tratar el panel como el exterior de la
  ventana: alli no hay auto-scroll. }
function PointerInsideRange : boolean;
  begin
    PointerInsideRange := not outOfRange;
  end;

var i: integer;
begin
  for i := 0 to 6 do HandlerTable[i] := NullHandler;
  rangeSet := False;
  outOfRange := False;
end.
