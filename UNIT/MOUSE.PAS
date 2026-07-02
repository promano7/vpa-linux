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


Implementation

uses ptcmouse{$IFDEF UNIX}, xfocus{$ENDIF};

type TMouseProc = procedure;

procedure NullHandler; begin end;

var
  HandlerTable : array[0..6] of TMouseProc;
  prevX, prevY : integer;
  prevButtons  : word;
  rangeSet     : boolean;
  rX1, rY1, rX2, rY2 : integer;   { rango permitido del cursor (clamp por software) }

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
    MousePresent := InitMouse;
    if not MousePresent then Exit;
    ptcmouse.ShowMouse;   { mostrar el puntero del sistema (la diana propia aun no va) }
    MouseHandlerInstalled := True;
    MouseDisabled := False;
    MouseX := 160; MouseY := 100; MouseButtons := 0;
    prevX := 160; prevY := 100; prevButtons := 0;
  end;

procedure DisableMouse;
  begin
    if not MouseHandlerInstalled then Exit;
    ptcmouse.HideMouse;
    MouseHandlerInstalled := False;
  end;

procedure ShowMouse;  begin ptcmouse.ShowMouse; end;
procedure HideMouse;  begin ptcmouse.HideMouse; end;
procedure SuspendMouse; begin ptcmouse.HideMouse; end;
procedure ResumeMouse;  begin ptcmouse.ShowMouse; end;

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
    { ptcmouse gestiona su propio cursor; la forma personalizada no se porta }
  end;

procedure SetMouseSensitivity (mx,my,mt:byte);
  begin
    { sin equivalente directo necesario; no-op }
  end;

procedure SetMouseRange (x1,y1,x2,y2:word);
  begin
    { ptcmouse no expone limitacion de rango: se emula por software en PollMouse }
    rX1 := x1; rY1 := y1; rX2 := x2; rY2 := y2;
    rangeSet := True;
  end;

procedure MoveMouse (x,y:word);
  var wx, wy: longint;
  begin
    wx := x; wy := y;
    {$IFDEF UNIX}xfocus.MapSurfaceToWindow(wx, wy);{$ENDIF}  { superficie->ventana para el warp }
    SetMousePos(wx, wy);
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
    GetMouseState(lx, ly, lb);
    {$IFDEF UNIX}xfocus.MapMouseToSurface(lx, ly);{$ENDIF}   { pantalla completa: escalar a 640x480 }
    mx := lx; my := ly; btns := word(lb) and $07;
    if rangeSet then
    begin
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

var i: integer;
begin
  for i := 0 to 6 do HandlerTable[i] := NullHandler;
  rangeSet := False;
end.
