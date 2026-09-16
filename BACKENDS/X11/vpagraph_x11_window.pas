{ vpagraph_x11_window - ventana, foco, escala y pantalla completa del plugin
  X11. Fase 5 de WAYLAND.md, tareas T5.6 (reescritura de lo que sobrevive de
  UNIT/xfocus.pas) y T5.7 (bloque T2.10 de la ABI).

  Lo que hay aqui es la forma ABI de UNIT/xfocus.pas, no un traslado: de sus
  once funciones solo sobreviven cuatro peticiones reales al servidor
  (decision D-08) -tamano de pantalla, pantalla completa, "puntero dentro" y
  modificadores actuales- mas lo que Resume necesita rehacer (foco y pantalla
  completa). Lo demas existia para alcanzar desde fuera una ventana que ptc
  creaba sin dar acceso a ella:
    - FindWin por titulo (sondeo de 20 x 50 ms con respaldo laxo) desaparece:
      la ventana la da PTCWrapperObject.X11WindowID (T5.3b, D-18);
    - ApplyWindowScale y los dos Map* desaparecen: el mapeo consola <->
      superficie lo hace vpagraph_x11_input con el tamano de consola que da
      el wrapper (ConsoleWidth/ConsoleHeight);
    - ResolveScale y la interpretacion de VPA_SCALE se quedan en el nucleo:
      al plugin le llega ScalePercent ya resuelto;
    - MakeBlankCursor era codigo muerto (el cursor lo oculta la opcion
      'hide cursor' de ptc, que es lo que hace ShowMouse).

  Conexion X propia y persistente (gDpy): ptc no llama a XInitThreads y su
  hilo es dueno de su Display, asi que este plugin no puede usarlo desde el
  hilo del llamante. Dos conexiones distintas al mismo servidor no necesitan
  XInitThreads; el XID de la ventana es global al servidor y basta con el.
  gDpy se abre en Init y se cierra en Shutdown: ningun recurso se adquiere en
  initialization ni se libera en finalization (regla de T5.9, dlclose).

  XSetInputFocus sobre una ventana que aun no es visible produce BadMatch, y
  el manejador de errores por defecto de Xlib mata el proceso. Por eso
  WindowAttach espera (hasta ~2 s) a que la ventana este mapeada antes de
  pedir el foco, y ni esta unidad ni ninguna otra instalan XSetErrorHandler,
  que es global al proceso y pisaria al de ptc (XShm). }
unit vpagraph_x11_window;

{$MODE OBJFPC}{$H+}

interface

uses
  x, xlib;

{$I vpagraph_abi.inc}

{ --- ciclo de vida de la conexion y la ventana (los llama vpagraph_x11_impl) --- }

{ Abre la conexion X propia del plugin. False si no hay servidor. Idempotente. }
function WindowConnect: Boolean;

{ Cierra la conexion propia y olvida la ventana. Idempotente. }
procedure WindowDisconnect;

{ Toma la ventana que ptc acaba de abrir (X11WindowID), espera a que sea
  visible y le pide el foco de teclado, como hacia GrabInputFocus. Se llama
  despues de InitGraph y despues de SetGraphMode(GetGraphMode) en Resume. }
procedure WindowAttach;

{ Olvida la ventana (ptc la va a destruir en RestoreCrtMode/CloseGraph).
  Conserva el estado de pantalla completa pedido, para que Resume lo rehaga. }
procedure WindowDetach;

{ Estado de pantalla completa que pidio el llamante (SetFullscreen o
  Init.Fullscreen), aunque la ventana este cerrada en este momento. }
function FullscreenWanted: Boolean;

{ Conexion y ventana actuales, para vpagraph_x11_input (XQueryPointer). }
function WindowDisplay: PDisplay;
function WindowHandle: TWindow;

{ Bit "puntero dentro" (VPA2.PAS:4078) y modificadores actuales en la
  convencion de la BIOS (Shift=3, Ctrl=4, Alt=8), sobre la conexion propia.
  Los usa vpagraph_x11_input para GetMouseState y GetModifiers. }
function PointerInsideWindow: Boolean;
function CurrentModifiers: TVPAGraphUInt32;

{ --- T2.10: funciones de la ABI --- }

function X11GetScreenSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;
function X11SetFullscreen(Enable: TVPAGraphBool): TVPAGraphInt32; cdecl;
function X11GetWindowSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;

implementation

uses
  SysUtils, xutil, xatom, ctypes, baseunix, ptcwrapper, ptcgraph,
  vpagraph_x11_impl;

var
  gDpy: PDisplay = nil;          { conexion persistente del plugin }
  gWin: TWindow  = 0;            { ventana de ptc, 0 si esta cerrada }
  gFullscreenWanted: Boolean = False;  { pedido por el llamante }
  gFullscreenApplied: Boolean = False; { _NET_WM_STATE_FULLSCREEN puesto en gWin }

procedure SleepMs(Ms: Integer);
var
  ts: TTimeSpec;
begin
  ts.tv_sec := Ms div 1000;
  ts.tv_nsec := (Ms mod 1000) * 1000 * 1000;
  fpnanosleep(@ts, nil);
end;

{ Espera a que la ventana este mapeada y sea visible (hasta MaxMs). True si
  lo esta. Sin esto XSetInputFocus daria BadMatch. }
function WaitViewable(MaxMs: Integer): Boolean;
var
  attr: TXWindowAttributes;
  Waited: Integer;
begin
  Result := False;
  Waited := 0;
  repeat
    if (XGetWindowAttributes(gDpy, gWin, @attr) <> 0) and
       (attr.map_state = IsViewable) then
      Exit(True);
    SleepMs(50);
    Inc(Waited, 50);
  until Waited >= MaxMs;
end;

{ Envia el ClientMessage _NET_WM_STATE (EWMH) al root: Add = True anade el
  estado, False lo quita. }
procedure SendNetWMState(StateAtom: TAtom; Add: Boolean);
var
  ev: TXEvent;
  netState: TAtom;
begin
  netState := XInternAtom(gDpy, '_NET_WM_STATE', 0);
  if netState = 0 then Exit;
  FillChar(ev, SizeOf(ev), 0);
  ev.xclient._type := ClientMessage;
  ev.xclient.window := gWin;
  ev.xclient.message_type := netState;
  ev.xclient.format := 32;
  if Add then
    ev.xclient.data.l[0] := 1        { _NET_WM_STATE_ADD }
  else
    ev.xclient.data.l[0] := 0;       { _NET_WM_STATE_REMOVE }
  ev.xclient.data.l[1] := clong(StateAtom);
  ev.xclient.data.l[2] := 0;
  ev.xclient.data.l[3] := 1;         { fuente: aplicacion }
  XSendEvent(gDpy, XDefaultRootWindow(gDpy), 0,
             SubstructureRedirectMask or SubstructureNotifyMask, @ev);
end;

{ Pide al gestor de ventanas pantalla completa (_NET_WM_STATE_FULLSCREEN).
  NO cambia el modo de video: el gestor agranda la ventana y ptc centra su
  consola en ella (HandleConfigureNotifyEvent, arreglo de 3.67.5). Es el
  RequestFullscreen de xfocus. }
procedure ApplyFullscreen;
var
  netState, netFS: TAtom;
  hints: PXSizeHints;
  scr, sw, sh: longint;
begin
  if (gDpy = nil) or (gWin = 0) then Exit;
  WaitViewable(2000);

  scr := XDefaultScreen(gDpy);
  sw := XDisplayWidth(gDpy, scr);
  sh := XDisplayHeight(gDpy, scr);

  { fondo negro: ptc solo pinta su consola; el resto de la ventana, al
    llenar la pantalla, tiene que quedar negro y no en blanco. }
  XSetWindowBackground(gDpy, gWin, XBlackPixel(gDpy, scr));
  XClearWindow(gDpy, gWin);

  { relajar los size hints (min=1, max=pantalla) para que el gestor pueda
    agrandar la ventana hasta llenar la pantalla. }
  hints := XAllocSizeHints;
  if hints <> nil then
  begin
    hints^.flags := PMinSize or PMaxSize;
    hints^.min_width := 1;  hints^.min_height := 1;
    hints^.max_width := sw; hints^.max_height := sh;
    XSetWMNormalHints(gDpy, gWin, hints);
    XFree(hints);
  end;

  netState := XInternAtom(gDpy, '_NET_WM_STATE', 0);
  netFS    := XInternAtom(gDpy, '_NET_WM_STATE_FULLSCREEN', 0);
  if (netState <> 0) and (netFS <> 0) then
  begin
    { fijar la propiedad (fiable en algunos gestores) y enviar el
      ClientMessage (para la ventana ya mapeada) }
    XChangeProperty(gDpy, gWin, netState, XA_ATOM, 32, PropModeReplace,
                    PByte(@netFS), 1);
    SendNetWMState(netFS, True);
  end;
  XSync(gDpy, 0);   { ida y vuelta: al volver, el servidor ya lo ha aplicado }
  gFullscreenApplied := True;
end;

{ Quita el estado de pantalla completa. Es el ReleaseFullscreen de xfocus:
  doble seguro para que el panel del escritorio reaparezca. }
procedure ReleaseFullscreen;
var
  netState, netFS: TAtom;
begin
  if (gDpy = nil) or (gWin = 0) or not gFullscreenApplied then Exit;
  gFullscreenApplied := False;
  netState := XInternAtom(gDpy, '_NET_WM_STATE', 0);
  netFS    := XInternAtom(gDpy, '_NET_WM_STATE_FULLSCREEN', 0);
  if (netState = 0) or (netFS = 0) then Exit;
  XDeleteProperty(gDpy, gWin, netState);
  SendNetWMState(netFS, False);
  XSync(gDpy, 0);   { ida y vuelta: al volver, el servidor ya lo ha aplicado }
end;

{ Foco de teclado: ptcgraph hace XMapRaised pero no XSetInputFocus. Es el
  nucleo de GrabInputFocus. }
procedure GrabFocus;
var
  ev: TXEvent;
  netActive: TAtom;
begin
  if (gDpy = nil) or (gWin = 0) then Exit;
  if not WaitViewable(2000) then Exit;   { BadMatch si no es visible }
  XRaiseWindow(gDpy, gWin);
  XSetInputFocus(gDpy, gWin, RevertToParent, CurrentTime);
  netActive := XInternAtom(gDpy, '_NET_ACTIVE_WINDOW', 1);
  if netActive <> 0 then
  begin
    FillChar(ev, SizeOf(ev), 0);
    ev.xclient._type := ClientMessage;
    ev.xclient.window := gWin;
    ev.xclient.message_type := netActive;
    ev.xclient.format := 32;
    ev.xclient.data.l[0] := 1;
    ev.xclient.data.l[1] := CurrentTime;
    XSendEvent(gDpy, XDefaultRootWindow(gDpy), 0,
               SubstructureRedirectMask or SubstructureNotifyMask, @ev);
  end;
  XSync(gDpy, 0);   { ida y vuelta: al volver, el servidor ya lo ha aplicado }
end;

{ ---------------------------------------------------------------------------
  Ciclo de vida
  --------------------------------------------------------------------------- }

function WindowConnect: Boolean;
begin
  if gDpy = nil then
    gDpy := XOpenDisplay(nil);
  Result := gDpy <> nil;
end;

procedure WindowDisconnect;
begin
  gWin := 0;
  gFullscreenApplied := False;
  gFullscreenWanted := False;
  if gDpy <> nil then
  begin
    XCloseDisplay(gDpy);
    gDpy := nil;
  end;
end;

procedure WindowAttach;
begin
  if gDpy = nil then Exit;
  if PTCWrapperObject = nil then Exit;
  gWin := TWindow(PTCWrapperObject.X11WindowID);
  gFullscreenApplied := False;
  if gWin = 0 then Exit;
  GrabFocus;
  if gFullscreenWanted then
    ApplyFullscreen;
end;

procedure WindowDetach;
begin
  gWin := 0;
  gFullscreenApplied := False;
end;

function FullscreenWanted: Boolean;
begin
  Result := gFullscreenWanted;
end;

function WindowDisplay: PDisplay;
begin
  Result := gDpy;
end;

function WindowHandle: TWindow;
begin
  Result := gWin;
end;

{ ---------------------------------------------------------------------------
  Consultas para el bloque de entrada
  --------------------------------------------------------------------------- }

function PointerInsideWindow: Boolean;
var
  root, child: TWindow;
  rx, ry, wx, wy: cint;
  mask: cuint;
  attr: TXWindowAttributes;
begin
  Result := True;                     { si no se puede consultar, no bloquear }
  if (gDpy = nil) or (gWin = 0) then Exit;
  if not XQueryPointer(gDpy, gWin, @root, @child, @rx, @ry, @wx, @wy, @mask) then
    Exit(False);                      { puntero en otra pantalla: fuera }
  if XGetWindowAttributes(gDpy, gWin, @attr) = 0 then Exit;
  Result := (wx >= 0) and (wx < attr.width) and (wy >= 0) and (wy < attr.height);
end;

function CurrentModifiers: TVPAGraphUInt32;
var
  root, child: TWindow;
  rx, ry, wx, wy: cint;
  mask: cuint;
begin
  Result := 0;
  if gDpy = nil then Exit;
  if not XQueryPointer(gDpy, XDefaultRootWindow(gDpy), @root, @child,
                       @rx, @ry, @wx, @wy, @mask) then Exit;
  if (mask and ShiftMask)   <> 0 then Result := Result or VPAG_MOD_SHIFT;
  if (mask and ControlMask) <> 0 then Result := Result or VPAG_MOD_CTRL;
  if (mask and Mod1Mask)    <> 0 then Result := Result or VPAG_MOD_ALT;
end;

{ ---------------------------------------------------------------------------
  T2.10 - ABI
  --------------------------------------------------------------------------- }

{ Se puede llamar ANTES de Init: si el plugin no tiene conexion abre una
  temporal y la cierra, para no dejar un descriptor vivo en un plugin que
  quiza nunca se inicialice (quien reserva, libera). }
function X11GetScreenSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;
var
  dpy: PDisplay;
  scr: longint;
  Temporary: Boolean;
begin
  try
    if (Width = nil) or (Height = nil) then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'GetScreenSize: nil pointer');
      Exit(VPAG_ERR_INVALID_PARAM);
    end;
    Temporary := gDpy = nil;
    if Temporary then
      dpy := XOpenDisplay(nil)
    else
      dpy := gDpy;
    if dpy = nil then
    begin
      SetError(VPAG_ERR_VIDEO, 'GetScreenSize: cannot open X display');
      Exit(VPAG_ERR_VIDEO);
    end;
    scr := XDefaultScreen(dpy);
    Width^ := XDisplayWidth(dpy, scr);
    Height^ := XDisplayHeight(dpy, scr);
    if Temporary then
      XCloseDisplay(dpy);
    Result := VPAG_OK;
  except
    on E: Exception do
    begin
      InternalError('GetScreenSize', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
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
    if gWin <> 0 then
      if gFullscreenWanted then
        ApplyFullscreen
      else
        ReleaseFullscreen;
    Result := VPAG_OK;
  except
    on E: Exception do
    begin
      InternalError('SetFullscreen', E);
      Result := VPAG_ERR_INTERNAL;
    end;
  end;
end;

function X11GetWindowSize(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;
var
  attr: TXWindowAttributes;
begin
  try
    if (Width = nil) or (Height = nil) then
    begin
      SetError(VPAG_ERR_INVALID_PARAM, 'GetWindowSize: nil pointer');
      Exit(VPAG_ERR_INVALID_PARAM);
    end;
    if (gDpy = nil) or (gWin = 0) then
    begin
      SetError(VPAG_ERR_INIT, 'GetWindowSize: no window');
      Exit(VPAG_ERR_INIT);
    end;
    if XGetWindowAttributes(gDpy, gWin, @attr) = 0 then
    begin
      SetError(VPAG_ERR_VIDEO, 'GetWindowSize: XGetWindowAttributes failed');
      Exit(VPAG_ERR_VIDEO);
    end;
    Width^ := attr.width;
    Height^ := attr.height;
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
