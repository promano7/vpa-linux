{ vpagraph_x11_input - teclado y raton del plugin X11. Fase 5 de WAYLAND.md,
  tarea T5.8 (bloque T2.11 de la ABI).

  El plugin NO usa ptccrt ni ptcmouse (aclaracion de T5.8 a la luz de D-10):
  bombea el mismo PTCWrapperObject.NextEvent y convierte cada evento de ptc
  a un TVPAGraphEvent, sin interpretarlo:

    IPTCKeyEvent      -> KEY_DOWN / KEY_UP, con KeyCode = codigo ptc TAL CUAL
                         (los VPAGK_* de la ABI son los PTCKEY_*), el punto
                         de codigo en UnicodeChar y Shift/Ctrl/Alt del evento
                         en Modifiers, en la convencion de la BIOS;
    IPTCMouseEvent    -> MOUSE_MOVE, o MOUSE_DOWN / MOUSE_UP si ademas es
                         IPTCMouseButtonEvent, con la posicion en coordenadas
                         de SUPERFICIE (0..639, 0..479);
    IPTCCloseEvent    -> CLOSE;
    IPTCResizeEvent   -> RESIZE (ptc no lo emite: la ventana no es
                         redimensionable; se traduce por completitud).

  La traduccion a scancodes de Turbo Pascal, el buffer de teclas,
  PTCLastKbdFlags, PTCQuitNoSave y la emulacion por software del rango del
  raton son semantica del NUCLEO y se reescriben en T6.6 y T6.7.

  Coordenadas. ptc entrega el raton en pixeles de su consola (640x480
  escalado por ScalePercent; en pantalla completa ya descuenta la franja
  negra, arreglo de 3.67.5 en HandleMouseEvent). La division a superficie es
  la misma que hacia xfocus.MapMouseToSurface, con el tamano de consola que
  da el wrapper (ConsoleWidth/ConsoleHeight, T5.7) en vez de adivinarlo
  mirando la ventana. SetMousePos hace el camino inverso de
  MapSurfaceToWindow, incluido el medio bloque que centra la diana en el
  pixel escalado.

  GetMouseState devuelve la ultima posicion y estado de botones que pasaron
  por PollEvent (o que fijo SetMousePos), exactamente como ptcmouse, que
  tambien era de eventos: el nucleo bombea PollEvent antes de consultarlo.
  El bit Inside si es una consulta viva al servidor (XQueryPointer sobre la
  conexion del plugin), porque su motivo es precisamente detectar que el
  puntero ha salido y ya no llegan eventos (VPA2.PAS:4078). }
unit vpagraph_x11_input;

{$MODE OBJFPC}{$H+}

interface

{ Los tipos de la ABI se toman de vpagraph_x11_impl y no de un segundo
  $I vpagraph_abi.inc: dos inclusiones son dos tipos distintos para FPC y
  @X11PollEvent no encajaria en la casilla de la interfaz. }
uses
  vpagraph_x11_impl;

function X11PollEvent(EventOut: PVPAGraphEvent): TVPAGraphInt32; cdecl;
function X11GetModifiers: TVPAGraphUInt32; cdecl;
procedure X11GetMouseState(X, Y: PVPAGraphInt32; Buttons: PVPAGraphUInt32;
  Inside: PVPAGraphUInt8); cdecl;
procedure X11SetMousePos(X, Y: TVPAGraphInt32); cdecl;
procedure X11ShowMouse(Show: TVPAGraphBool); cdecl;

implementation

uses
  SysUtils, ptc, ptcwrapper, ptcgraph,
  {$IFDEF VPAG_WAYLAND}vpagraph_wayland_window{$ELSE}vpagraph_x11_window{$ENDIF};

const
  SurfaceWidth  = 640;
  SurfaceHeight = 480;

var
  { Ultimo estado del raton visto por PollEvent, en coordenadas de superficie }
  MouseX: TVPAGraphInt32 = 0;
  MouseY: TVPAGraphInt32 = 0;
  MouseButtons: TVPAGraphUInt32 = 0;

function ConsoleReady: Boolean;
begin
  Result := Initialized and (PTCWrapperObject <> nil) and PTCWrapperObject.IsOpen;
end;

{ Pixeles de consola -> superficie, recortando al borde. }
procedure ConsoleToSurface(CX, CY: Integer; out SX, SY: TVPAGraphInt32);
var
  CW, CH: Integer;
begin
  CW := PTCWrapperObject.ConsoleWidth;
  CH := PTCWrapperObject.ConsoleHeight;
  if (CW > 0) and (CH > 0) then
  begin
    SX := (CX * SurfaceWidth) div CW;
    SY := (CY * SurfaceHeight) div CH;
  end
  else
  begin
    SX := CX;
    SY := CY;
  end;
  if SX < 0 then SX := 0 else if SX > SurfaceWidth - 1 then SX := SurfaceWidth - 1;
  if SY < 0 then SY := 0 else if SY > SurfaceHeight - 1 then SY := SurfaceHeight - 1;
end;

{ Superficie -> pixeles de consola, al centro del bloque escalado (como
  MapSurfaceToWindow: si la diana fuera a la esquina quedaria escala/2 px
  arriba-izquierda del planeta). }
procedure SurfaceToConsole(SX, SY: TVPAGraphInt32; out CX, CY: Integer);
var
  CW, CH: Integer;
begin
  CW := PTCWrapperObject.ConsoleWidth;
  CH := PTCWrapperObject.ConsoleHeight;
  if (CW > 0) and (CH > 0) then
  begin
    CX := (SX * CW) div SurfaceWidth + (CW div SurfaceWidth) div 2;
    CY := (SY * CH) div SurfaceHeight + (CH div SurfaceHeight) div 2;
    if CX < 0 then CX := 0 else if CX > CW - 1 then CX := CW - 1;
    if CY < 0 then CY := 0 else if CY > CH - 1 then CY := CH - 1;
  end
  else
  begin
    CX := SX;
    CY := SY;
  end;
end;

function ButtonsOf(const S: TPTCMouseButtonState): TVPAGraphUInt32;
begin
  Result := 0;
  if PTCMouseButton1 in S then Result := Result or VPAG_MB_LEFT;
  if PTCMouseButton2 in S then Result := Result or VPAG_MB_RIGHT;
  if PTCMouseButton3 in S then Result := Result or VPAG_MB_MIDDLE;
end;

function ButtonOf(B: TPTCMouseButton): TVPAGraphUInt32;
begin
  case B of
    PTCMouseButton1: Result := VPAG_MB_LEFT;
    PTCMouseButton2: Result := VPAG_MB_RIGHT;
    PTCMouseButton3: Result := VPAG_MB_MIDDLE;
  else
    Result := 0;   { botones 4.. (rueda): no tienen nombre en la ABI }
  end;
end;

{ ---------------------------------------------------------------------------
  T2.11 - ABI
  --------------------------------------------------------------------------- }

function X11PollEvent(EventOut: PVPAGraphEvent): TVPAGraphInt32; cdecl;
var
  Ev: IPTCEvent;
  KeyEv: IPTCKeyEvent;
  MouseEv: IPTCMouseEvent;
  ButtonEv: IPTCMouseButtonEvent;
  ResizeEv: IPTCResizeEvent;
  SX, SY: TVPAGraphInt32;
begin
  try
    if EventOut = nil then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'PollEvent: EventOut is nil');
      Exit(VPAG_ERR_INVALID_PARAM);
    end;
    if EventOut^.StructSize < SizeOf(TVPAGraphEvent) then
    begin
      SetError(VPAG_ERR_STRUCT_SIZE, 'PollEvent: TVPAGraphEvent too small');
      Exit(VPAG_ERR_STRUCT_SIZE);
    end;
    if not ConsoleReady then
    begin
      SetError(VPAG_ERR_INIT, 'PollEvent before Init');
      Exit(VPAG_ERR_INIT);
    end;

    Ev := nil;
    PTCWrapperObject.NextEvent(Ev, False, PTCAnyEvent);
    if Ev = nil then
      Exit(0);

    { Se conserva StructSize; el resto se limpia. }
    FillChar(EventOut^.EventType, SizeOf(TVPAGraphEvent) - SizeOf(EventOut^.StructSize), 0);
    EventOut^.EventType := VPAG_EVENT_NONE;

    case Ev.EventType of
      PTCKeyEvent:
        begin
          KeyEv := Ev as IPTCKeyEvent;
          if KeyEv.Press then
            EventOut^.EventType := VPAG_EVENT_KEY_DOWN
          else
            EventOut^.EventType := VPAG_EVENT_KEY_UP;
          EventOut^.KeyCode := TVPAGraphUInt32(KeyEv.Code);
          EventOut^.ScanCode := TVPAGraphUInt32(KeyEv.Code);  { ptc no expone el keycode X }
          if KeyEv.Unicode > 0 then
            EventOut^.UnicodeChar := TVPAGraphUInt32(KeyEv.Unicode);
          if KeyEv.Shift   then EventOut^.Modifiers := EventOut^.Modifiers or VPAG_MOD_SHIFT;
          if KeyEv.Control then EventOut^.Modifiers := EventOut^.Modifiers or VPAG_MOD_CTRL;
          if KeyEv.Alt     then EventOut^.Modifiers := EventOut^.Modifiers or VPAG_MOD_ALT;
          EventOut^.MouseX := MouseX;
          EventOut^.MouseY := MouseY;
        end;
      PTCMouseEvent:
        begin
          MouseEv := Ev as IPTCMouseEvent;
          ConsoleToSurface(MouseEv.X, MouseEv.Y, SX, SY);
          MouseX := SX;
          MouseY := SY;
          MouseButtons := ButtonsOf(MouseEv.ButtonState);
          if Supports(Ev, IPTCMouseButtonEvent, ButtonEv) then
          begin
            if ButtonEv.Press then
              EventOut^.EventType := VPAG_EVENT_MOUSE_DOWN
            else
              EventOut^.EventType := VPAG_EVENT_MOUSE_UP;
            EventOut^.MouseButton := ButtonOf(ButtonEv.Button);
          end
          else
            EventOut^.EventType := VPAG_EVENT_MOUSE_MOVE;
          EventOut^.MouseX := MouseX;
          EventOut^.MouseY := MouseY;
          EventOut^.Modifiers := CurrentModifiers;
        end;
      PTCCloseEvent:
        begin
          EventOut^.EventType := VPAG_EVENT_CLOSE;
          EventOut^.MouseX := MouseX;
          EventOut^.MouseY := MouseY;
        end;
      PTCResizeEvent:
        begin
          ResizeEv := Ev as IPTCResizeEvent;
          EventOut^.EventType := VPAG_EVENT_RESIZE;
          EventOut^.Width := ResizeEv.Width;
          EventOut^.Height := ResizeEv.Height;
        end;
    end;
    Ev := nil;
    Result := 1;
  except
    on E: Exception do
    begin
      InternalError('PollEvent', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

function X11GetModifiers: TVPAGraphUInt32; cdecl;
begin
  try
    Result := CurrentModifiers;
  except
    on E: Exception do
    begin
      InternalError('GetModifiers', E);
      Result := 0;
    end;
  end;
end;

procedure X11GetMouseState(X, Y: PVPAGraphInt32; Buttons: PVPAGraphUInt32;
  Inside: PVPAGraphUInt8); cdecl;
begin
  try
    if X <> nil then X^ := MouseX;
    if Y <> nil then Y^ := MouseY;
    if Buttons <> nil then Buttons^ := MouseButtons;
    if Inside <> nil then
      if PointerInsideWindow then Inside^ := VPAG_TRUE else Inside^ := VPAG_FALSE;
  except
    on E: Exception do InternalError('GetMouseState', E);
  end;
end;

procedure X11SetMousePos(X, Y: TVPAGraphInt32); cdecl;
var
  CX, CY: Integer;
begin
  try
    if not ConsoleReady then Exit;
    SurfaceToConsole(X, Y, CX, CY);
    PTCWrapperObject.MoveMouseTo(CX, CY);
    { Como ptcmouse.SetMousePos: la posicion interna se actualiza ya, sin
      esperar al evento de movimiento, o el cursor logico se quedaria en la
      esquina y dispararia el auto-scroll al arrancar (arreglo VPA). }
    if X < 0 then MouseX := 0 else if X > SurfaceWidth - 1 then MouseX := SurfaceWidth - 1 else MouseX := X;
    if Y < 0 then MouseY := 0 else if Y > SurfaceHeight - 1 then MouseY := SurfaceHeight - 1 else MouseY := Y;
  except
    on E: Exception do InternalError('SetMousePos', E);
  end;
end;

procedure X11ShowMouse(Show: TVPAGraphBool); cdecl;
begin
  try
    if not ConsoleReady then Exit;
    if Show <> VPAG_FALSE then
      PTCWrapperObject.Option('show cursor')
    else
      PTCWrapperObject.Option('hide cursor');
  except
    on E: Exception do InternalError('ShowMouse', E);
  end;
end;

end.
