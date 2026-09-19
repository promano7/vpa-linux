{ vpagraph_wayland_window - ventana y pantalla completa del plugin Wayland.
  Fase 8 de WAYLAND.md, tarea T8B.9; decision D-22.

  Es la pareja de BACKENDS/X11/vpagraph_x11_window.pas y exporta EXACTAMENTE
  la misma interfaz, con los mismos nombres (tambien los X11*, que aqui solo
  significan "la casilla T2.10 de la ABI"): asi vpagraph_x11_impl.pas y
  vpagraph_x11_input.pas se compilan dos veces sin mas diferencia que un
  'uses' bajo -dVPAG_WAYLAND, que es lo que pide T8B.9.

  Lo que cambia respecto de X11 no es de estilo, es del protocolo (D-22):
    - En X11 el plugin abre una segunda conexion al servidor y manipula desde
      fuera la ventana de ptc por su XID. En Wayland una superficie solo
      existe dentro de la conexion que la creo: no hay nada que "abrir
      aparte". Por eso aqui no hay conexion propia, y todo lo que toca la
      ventana se le pide a la consola SDL3 con PTCWrapperObject.Option, que
      ptcwrapper ya ejecuta en el hilo de la consola. Ademas es lo que exige
      el riesgo R11: a SDL solo se la llama desde ese hilo.
    - No hay foco que pedir: Wayland no deja a un cliente quitarselo a otro;
      el compositor se lo da a la ventana nueva. WindowAttach solo rehace la
      pantalla completa, que ptcgraph pierde en cada Open ('windowed output').
    - Un cliente Wayland no sabe el tamano de la pantalla hasta tener
      ventana, y GetScreenSize se llama antes de Init. Devuelve
      VPAG_ERR_UNSUPPORTED, caso que el nucleo ya contempla (no recorta la
      escala). El tamano real y VPA_SCALE=fullscreen son de la Fase 10.

  PointerInsideWindow y CurrentModifiers (Fase 9, D-24) leen el estado que la
  consola SDL3 publica desde su hilo (ptc.PTCSDLInputState): no llaman a SDL
  (R11) ni pasan por Option, que costaria 10 ms por consulta y se pregunta en
  cada evento de raton. Wayland solo informa de los modificadores a la
  ventana con foco de teclado: sin foco, "ninguno". }
unit vpagraph_wayland_window;

{$MODE OBJFPC}{$H+}

interface

uses
  vpagraph_x11_impl;

function WindowConnect: Boolean;
procedure WindowDisconnect;
procedure WindowAttach;
procedure WindowDetach;
function FullscreenWanted: Boolean;
function PointerInsideWindow: Boolean;
function CurrentModifiers: TVPAGraphUInt32;

function X11GetScreenSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;
function X11SetFullscreen(Enable: TVPAGraphBool): TVPAGraphInt32; cdecl;
function X11GetWindowSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;

implementation

uses
  SysUtils, ptc, ptcwrapper, ptcgraph;

var
  gAttached: Boolean = False;          { hay consola abierta }
  gFullscreenWanted: Boolean = False;  { pedido por el llamante }

{ Pide a la consola, en su hilo, el estado de pantalla completa deseado. }
procedure ApplyFullscreen;
begin
  if PTCWrapperObject = nil then Exit;
  if gFullscreenWanted then
    PTCWrapperObject.Option('fullscreen output')
  else
    PTCWrapperObject.Option('windowed output');
end;

function WindowConnect: Boolean;
begin
  Result := True;   { no hay segunda conexion en Wayland (D-22) }
end;

procedure WindowDisconnect;
begin
  gAttached := False;
  gFullscreenWanted := False;
end;

procedure WindowAttach;
begin
  gAttached := True;
  if gFullscreenWanted then
    ApplyFullscreen;
end;

procedure WindowDetach;
begin
  gAttached := False;   { gFullscreenWanted se conserva para Resume }
end;

function FullscreenWanted: Boolean;
begin
  Result := gFullscreenWanted;
end;

function PointerInsideWindow: Boolean;
begin
  if not gAttached then Exit(True);   { sin ventana, no bloquear (como X11) }
  Result := (PTCSDLInputState and PTC_SDL_INPUT_POINTER_INSIDE) <> 0;
end;

function CurrentModifiers: TVPAGraphUInt32;
var
  St: LongWord;
begin
  Result := 0;
  if not gAttached then Exit;
  St := PTCSDLInputState;
  if (St and PTC_SDL_INPUT_SHIFT)   <> 0 then Result := Result or VPAG_MOD_SHIFT;
  if (St and PTC_SDL_INPUT_CONTROL) <> 0 then Result := Result or VPAG_MOD_CTRL;
  if (St and PTC_SDL_INPUT_ALT)     <> 0 then Result := Result or VPAG_MOD_ALT;
end;

function X11GetScreenSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;
begin
  SetError(VPAG_ERR_UNSUPPORTED,
    'GetScreenSize: a Wayland client cannot know the screen size before it has a window');
  Result := VPAG_ERR_UNSUPPORTED;
end;

function X11SetFullscreen(Enable: TVPAGraphBool): TVPAGraphInt32; cdecl;
begin
  try
    if not Initialized then
    begin
      SetError(VPAG_ERR_INIT, 'SetFullscreen before Init');
      Exit(VPAG_ERR_INIT);
    end;
    gFullscreenWanted := Enable <> VPAG_FALSE;
    if gAttached then
      ApplyFullscreen;
    Result := VPAG_OK;
  except
    on E: Exception do
    begin
      InternalError('SetFullscreen', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

{ Tamano de la consola de ptc (superficie x escala). Si el usuario
  redimensiona la ventana, SDL reescala dentro y este valor no cambia: el
  tamano real de la ventana es de la Fase 10. }
function X11GetWindowSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;
begin
  try
    if (Width = nil) or (Height = nil) then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'GetWindowSize: nil pointer');
      Exit(VPAG_ERR_INVALID_PARAM);
    end;
    if (not gAttached) or (PTCWrapperObject = nil) or
       (PTCWrapperObject.ConsoleWidth = 0) then
    begin
      SetError(VPAG_ERR_INIT, 'GetWindowSize: no window');
      Exit(VPAG_ERR_INIT);
    end;
    Width^ := PTCWrapperObject.ConsoleWidth;
    Height^ := PTCWrapperObject.ConsoleHeight;
    Result := VPAG_OK;
  except
    on E: Exception do
    begin
      InternalError('GetWindowSize', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

end.
