{$MODE OBJFPC}{$H+}
{ xfocus - integra la ventana ptcgraph con el escritorio X (Linux):
    * GrabInputFocus: localiza la ventana, oculta el puntero del sistema (cursor
      en blanco; usa conexion X PERSISTENTE para que el cursor no se libere) y
      pide el foco de teclado (ptcgraph hace XMapRaised pero no XSetInputFocus).
    * ReleaseInputFocus: suelta y cierra (llamar al salir). }
unit xfocus;
interface

function  FullscreenRequested: boolean;
function  ResolveScale: longint;
function  WantFullscreen: boolean;
procedure ApplyWindowScale;
procedure RequestFullscreen;
procedure ReleaseFullscreen;
procedure MapMouseToSurface(var x, y: longint);
procedure MapSurfaceToWindow(var x, y: longint);
procedure GrabInputFocus;
procedure ReleaseInputFocus;
function  PointerInsideWindow: boolean;
function  XReady: boolean;              { True si hay conexion X abierta }
function  KbdModifiers: byte;           { estado actual Shift=3/Ctrl=4/Alt=8 (estilo BIOS 0040:0017) }

implementation
uses x, xlib, xutil, xatom, ctypes, unixtype, baseunix, sysutils;

var
  gDpy: PDisplay = nil;          { conexion persistente (mantiene vivo el cursor) }
  gWin: TWindow  = 0;
  gCur: TCursor  = 0;
  gFullscreen: boolean = False;  { pantalla completa activa (escalar raton) }
  gWinW: cint = 0;               { tamano de la ventana (cache para escalar el raton) }
  gWinH: cint = 0;
  gWantFullscreen: boolean = False;  { VPA_SCALE=fullscreen: pedir pantalla completa al gestor }

function FullscreenRequested: boolean;
begin
  FullscreenRequested := (GetEnvironmentVariable('VPA_FULLSCREEN') <> '') or
                         (LowerCase(GetEnvironmentVariable('VPA_VIDEO')) = 'fullscreen');
end;

{ Resuelve la escala de ventana deseada (1..8):
    - VPA_SCALE sin definir  -> 2 (por defecto, ventana mas grande)
    - VPA_SCALE=1            -> 1 (640x480 nativo, sin escalar)
    - VPA_SCALE=fullscreen   -> la mayor escala entera que cabe en la pantalla
    - VPA_SCALE=N (2..8)     -> N
  Siempre se recorta a lo que cabe en pantalla (4:3, escala entera, nitido).
  VPA pasa el resultado a ptcgraph.VPAForceScale antes de InitGraph. }
function ResolveScale: longint;
var
  v: string;
  n, code, scr, sw, sh, maxfit: longint;
  dpy: PDisplay;
begin
  v := LowerCase(Trim(GetEnvironmentVariable('VPA_SCALE')));
  maxfit := 1;
  dpy := XOpenDisplay(nil);
  if dpy <> nil then
  begin
    scr := XDefaultScreen(dpy);
    sw := XDisplayWidth(dpy, scr);
    sh := XDisplayHeight(dpy, scr);
    maxfit := sw div 640;
    if (sh div 480) < maxfit then maxfit := sh div 480;
    XCloseDisplay(dpy);
  end;
  if maxfit < 1 then maxfit := 1;
  if maxfit > 8 then maxfit := 8;

  gWantFullscreen := False;
  if v = '' then
    n := 2                                  { por defecto: ventana mas grande }
  else if (v = 'fullscreen') or (v = 'full') or (v = 'max') then
  begin
    n := maxfit;                            { ajuste 4:3 mas grande que cabe }
    gWantFullscreen := True;                { + estado pantalla completa (tapa el panel) }
  end
  else
  begin
    Val(v, n, code);
    if (code <> 0) or (n < 1) then n := 1;
  end;
  if n > maxfit then n := maxfit;           { recortar a lo que cabe }
  if n < 1 then n := 1;
  ResolveScale := n;
end;

function WantFullscreen: boolean;
begin
  WantFullscreen := gWantFullscreen;
end;

{ La ventana mas grande la crea ya ptcgraph parcheado (VENDOR/ptcgraph + VPA_SCALE),
  con el surface a 640x480 escalado por ptc. Aqui solo detectamos que la ventana
  es mayor de 640x480 y activamos el escalado de coordenadas del raton
  (ventana -> surface), que hace MapMouseToSurface. Sin VPA_SCALE no hace nada. }
procedure ApplyWindowScale;
var attr: TXWindowAttributes;
begin
  if (gDpy = nil) or (gWin = 0) then exit;
  if XGetWindowAttributes(gDpy, gWin, @attr) = 0 then exit;
  if (attr.width > 640) or (attr.height > 480) then
  begin
    gFullscreen := True;          { activa el escalado del raton en MapMouseToSurface }
    gWinW := attr.width; gWinH := attr.height;
  end;
end;

{ Pide al gestor de ventanas que ponga la ventana a pantalla completa
  (_NET_WM_STATE_FULLSCREEN). NO cambia el modo de video: el monitor sigue a su
  resolucion nativa y el gestor agranda la ventana; ptc escala su superficie. }
procedure RequestFullscreen;
var
  ev: TXEvent;
  netState, netFS: TAtom;
  hints: PXSizeHints;
  attr: TXWindowAttributes;
  scr, sw, sh: longint;
  i: integer;
  ts: TimeSpec;
begin
  if (gDpy = nil) or (gWin = 0) then exit;

  { esperar a que la ventana este mapeada/gestionada por el gestor (hasta ~2s) }
  for i := 1 to 40 do
  begin
    if (XGetWindowAttributes(gDpy, gWin, @attr) <> 0) and (attr.map_state = IsViewable) then break;
    ts.tv_sec := 0; ts.tv_nsec := 50 * 1000 * 1000; fpnanosleep(@ts, nil);
  end;

  scr := XDefaultScreen(gDpy);
  sw := XDisplayWidth(gDpy, scr);
  sh := XDisplayHeight(gDpy, scr);

  { fondo negro: ptc solo pinta su consola (640x480 escalada) en la esquina; el
    resto de la ventana, al llenar la pantalla, debe quedar negro, no en blanco. }
  XSetWindowBackground(gDpy, gWin, XBlackPixel(gDpy, scr));
  XClearWindow(gDpy, gWin);

  { Relajar los size hints (min=1, max=pantalla) para que el gestor pueda agrandar
    la ventana hasta llenar la pantalla al activar _NET_WM_STATE_FULLSCREEN. El
    contenido 4:3 queda pegado arriba-izquierda con franja negra a la derecha;
    centrarlo requeriria que ptc desplazara su consola (no soportado aqui). }
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
    { fijar la propiedad (fiable en algunos gestores) ... }
    XChangeProperty(gDpy, gWin, netState, XA_ATOM, 32, PropModeReplace,
                    PByte(@netFS), 1);
    { ... y enviar el ClientMessage (para la ventana ya mapeada) }
    FillChar(ev, sizeof(ev), 0);
    ev.xclient._type := ClientMessage;
    ev.xclient.window := gWin;
    ev.xclient.message_type := netState;
    ev.xclient.format := 32;
    ev.xclient.data.l[0] := 1;       { _NET_WM_STATE_ADD }
    ev.xclient.data.l[1] := clong(netFS);
    ev.xclient.data.l[2] := 0;
    ev.xclient.data.l[3] := 1;       { fuente: aplicacion }
    XSendEvent(gDpy, XDefaultRootWindow(gDpy), 0,
               SubstructureRedirectMask or SubstructureNotifyMask, @ev);
  end;
  XFlush(gDpy);
  gFullscreen := True;
end;

{ Quita el estado de pantalla completa. Se llama al cerrar la grafica, como
  doble seguro para que el panel del escritorio reaparezca (ademas, al destruir
  la ventana el estado desaparece de todas formas). }
procedure ReleaseFullscreen;
var
  ev: TXEvent;
  netState, netFS: TAtom;
begin
  if (gDpy = nil) or (gWin = 0) then exit;
  if not gFullscreen then exit;
  netState := XInternAtom(gDpy, '_NET_WM_STATE', 0);
  netFS    := XInternAtom(gDpy, '_NET_WM_STATE_FULLSCREEN', 0);
  if (netState = 0) or (netFS = 0) then exit;
  XDeleteProperty(gDpy, gWin, netState);
  FillChar(ev, sizeof(ev), 0);
  ev.xclient._type := ClientMessage;
  ev.xclient.window := gWin;
  ev.xclient.message_type := netState;
  ev.xclient.format := 32;
  ev.xclient.data.l[0] := 0;       { _NET_WM_STATE_REMOVE }
  ev.xclient.data.l[1] := clong(netFS);
  ev.xclient.data.l[2] := 0;
  ev.xclient.data.l[3] := 1;
  XSendEvent(gDpy, XDefaultRootWindow(gDpy), 0,
             SubstructureRedirectMask or SubstructureNotifyMask, @ev);
  XFlush(gDpy);
end;

procedure UpdateWindowSize;
var attr: TXWindowAttributes;
begin
  if (gDpy = nil) or (gWin = 0) then exit;
  if XGetWindowAttributes(gDpy, gWin, @attr) <> 0 then
  begin
    gWinW := attr.width;
    gWinH := attr.height;
  end;
end;

{ Escala coordenadas de raton de pixeles de ventana a la superficie 640x480.
  Solo actua en pantalla completa; en modo ventana (640x480) no hace nada. }
procedure MapMouseToSurface(var x, y: longint);
begin
  if not gFullscreen then exit;
  if (gDpy = nil) or (gWin = 0) then exit;
  { gWinW/gWinH = tamano de la CONSOLA de ptc (donde vive el contenido 640x480
    escalado), fijado en ApplyWindowScale. No se reconsulta: si el gestor
    redimensiona la ventana al activar pantalla completa, ptc sigue pintando a
    tamano de consola, asi que el raton debe seguir referido a la consola. }
  if (gWinW <= 0) or (gWinH <= 0) then UpdateWindowSize;
  if (gWinW > 0) and (gWinH > 0) then
  begin
    x := (x * 640) div gWinW;
    y := (y * 480) div gWinH;
    if x < 0 then x := 0 else if x > 639 then x := 639;
    if y < 0 then y := 0 else if y > 479 then y := 479;
  end;
end;

{ Inverso de MapMouseToSurface: superficie 640x480 -> pixeles de ventana, para
  reposicionar el cursor fisico (XWarpPointer espera coords de ventana). Lo usa
  MoveMouse (flechas, enganche del cursor). Sin escalado (640x480) no hace nada. }
procedure MapSurfaceToWindow(var x, y: longint);
begin
  if not gFullscreen then exit;
  if (gDpy = nil) or (gWin = 0) then exit;
  if (gWinW <= 0) or (gWinH <= 0) then UpdateWindowSize;
  if (gWinW > 0) and (gWinH > 0) then
  begin
    x := (x * gWinW) div 640;
    y := (y * gWinH) div 480;
    if x < 0 then x := 0 else if x > gWinW - 1 then x := gWinW - 1;
    if y < 0 then y := 0 else if y > gWinH - 1 then y := gWinH - 1;
  end;
end;

{ Esta el puntero del raton dentro de la ventana de VPA? Se usa para no hacer
  auto-scroll cuando el puntero ha salido de la ventana (si no, MouseX se queda
  congelado en el borde y el mapa se desplaza sin parar). }
function PointerInsideWindow: boolean;
var
  root, child: TWindow;
  rx, ry, wx, wy: cint;
  mask: cuint;
  attr: TXWindowAttributes;
begin
  PointerInsideWindow := True;        { si no podemos consultar, no bloquear }
  if (gDpy = nil) or (gWin = 0) then Exit;
  if not XQueryPointer(gDpy, gWin, @root, @child, @rx, @ry, @wx, @wy, @mask) then
  begin
    PointerInsideWindow := False;     { puntero en otra pantalla => fuera }
    Exit;
  end;
  if XGetWindowAttributes(gDpy, gWin, @attr) = 0 then Exit;
  PointerInsideWindow := (wx >= 0) and (wx < attr.width) and
                         (wy >= 0) and (wy < attr.height);
end;

function XReady: boolean;
begin
  XReady := gDpy <> nil;
end;

{ Estado ACTUAL de los modificadores (no el del ultimo evento de tecla), leido de
  X11 igual que la BIOS de DOS exponia 0040:0017. Devuelve Shift=3, Ctrl=4, Alt=8
  (combinables). Cubre tanto los atajos de teclado como raton+modificador (p.ej.
  el zoom del mapa con Shift/Ctrl y el boton central). 0 si no hay conexion X. }
function KbdModifiers: byte;
var
  root, child: TWindow;
  rx, ry, wx, wy: cint;
  mask: cuint;
  r: byte;
begin
  KbdModifiers := 0;
  if gDpy = nil then Exit;
  if not XQueryPointer(gDpy, XDefaultRootWindow(gDpy), @root, @child,
                       @rx, @ry, @wx, @wy, @mask) then Exit;
  r := 0;
  if (mask and ShiftMask)   <> 0 then r := r or 3;
  if (mask and ControlMask) <> 0 then r := r or 4;
  if (mask and Mod1Mask)    <> 0 then r := r or 8;
  KbdModifiers := r;
end;

function TitleMatches(const nm, want, base: string): boolean;
begin
  TitleMatches := (nm = want)
    or ((base <> '') and (Length(nm) >= Length(base))
        and (Copy(nm, Length(nm)-Length(base)+1, Length(base)) = base));
end;

function FindWin(dpy:PDisplay; root:TWindow; const want, base:string; strict:boolean): TWindow;
var
  netcl, aType: TAtom; aFmt: cint; nItems, bAfter: culong; prop: PCUChar;
  wlist: PCULong; i: integer; w, exactW, lenientW: TWindow; nm: PChar;
  rootR, parentR: TWindow; children: PWindow; nch: cuint;
  s: string;
begin
  exactW := 0; lenientW := 0;
  { 1) lista de ventanas del gestor (EWMH): buscamos la coincidencia EXACTA con
       la ruta completa (lo que ptcgraph pone como titulo de la ventana de VPA);
       guardamos aparte una coincidencia laxa (titulo = nombre base) por si la
       exacta no existiera. Asi no cogemos el terminal titulado "VPA". }
  netcl := XInternAtom(dpy, '_NET_CLIENT_LIST', 1);
  if netcl <> 0 then
  begin
    prop := nil;
    if (XGetWindowProperty(dpy, root, netcl, 0, 4096, 0, AnyPropertyType,
          @aType, @aFmt, @nItems, @bAfter, @prop) = 0) and (prop <> nil) then
    begin
      wlist := PCULong(prop);
      for i := 0 to nItems-1 do
      begin
        w := wlist[i]; nm := nil;
        if (XFetchName(dpy, w, @nm) <> 0) and (nm <> nil) then
        begin
          s := string(nm);
          if (exactW = 0) and (s = want) then exactW := w
          else if (lenientW = 0) and TitleMatches(s, want, base) then lenientW := w;
          XFree(nm);
        end;
      end;
      XFree(prop);
    end;
  end;
  { 2) respaldo por XQueryTree si aun no hay exacta (gestores sin EWMH) }
  if (exactW = 0) and (XQueryTree(dpy, root, @rootR, @parentR, @children, @nch) <> 0) then
  begin
    for i := nch-1 downto 0 do
    begin
      nm := nil;
      if (XFetchName(dpy, children[i], @nm) <> 0) and (nm <> nil) then
      begin
        s := string(nm);
        if (exactW = 0) and (s = want) then exactW := children[i]
        else if (lenientW = 0) and TitleMatches(s, want, base) then lenientW := children[i];
        XFree(nm);
      end;
    end;
    if children <> nil then XFree(children);
  end;
  if exactW <> 0 then FindWin := exactW
  else if strict then FindWin := 0      { en modo estricto, solo vale la exacta }
  else FindWin := lenientW;             { ultimo recurso: coincidencia laxa }
end;

procedure MakeBlankCursor;
const blank: array[0..7] of char = (#0,#0,#0,#0,#0,#0,#0,#0);
var pm: TPixmap; black: TXColor;
begin
  FillChar(black, sizeof(black), 0);
  pm := XCreateBitmapFromData(gDpy, gWin, @blank, 8, 8);
  if pm <> None then
  begin
    gCur := XCreatePixmapCursor(gDpy, pm, pm, @black, @black, 0, 0);
    XFreePixmap(gDpy, pm);
  end;
end;

procedure GrabInputFocus;
var
  root: TWindow; want, base: string; tries: integer;
  ev: TXEvent; netActive: TAtom; ts: TTimeSpec;
begin
  if gDpy = nil then gDpy := XOpenDisplay(nil);
  if gDpy = nil then begin Writeln(StdErr,'xfocus: sin display X'); exit; end;
  root := XDefaultRootWindow(gDpy);
  want := ParamStr(0);
  base := ExtractFileName(want);
  gWin := 0; tries := 0;
  while (gWin = 0) and (tries < 20) do
  begin
    gWin := FindWin(gDpy, root, want, base, true);   { estricto: solo la ventana de VPA (ruta completa) }
    if gWin = 0 then
    begin
      ts.tv_sec := 0; ts.tv_nsec := 50*1000000; fpnanosleep(@ts, nil);
      inc(tries);
    end;
  end;
  if gWin = 0 then
    gWin := FindWin(gDpy, root, want, base, false);  { ultimo recurso: coincidencia laxa por nombre base }
  if gWin <> 0 then
  begin
    Writeln(StdErr, 'xfocus: window found -> requesting keyboard focus');
    { No ocultamos el cursor del sistema: XDefinecursor hacia que el puntero
      desapareciera tambien fuera de la ventana. Mientras VPA no dibuje su propia
      diana, dejamos visible el puntero de Linux como puntero. }
    XRaiseWindow(gDpy, gWin);
    XSetInputFocus(gDpy, gWin, RevertToParent, CurrentTime);
    netActive := XInternAtom(gDpy, '_NET_ACTIVE_WINDOW', 1);
    if netActive <> 0 then
    begin
      FillChar(ev, sizeof(ev), 0);
      ev.xclient._type := ClientMessage;
      ev.xclient.window := gWin;
      ev.xclient.message_type := netActive;
      ev.xclient.format := 32;
      ev.xclient.data.l[0] := 1;
      ev.xclient.data.l[1] := CurrentTime;
      XSendEvent(gDpy, root, 0, SubstructureRedirectMask or SubstructureNotifyMask, @ev);
    end;
    XFlush(gDpy);
  end
  else
    Writeln(StdErr, 'xfocus: VENTANA NO ENCONTRADA (titulo="', want, '")');
  { NO cerramos gDpy: mantiene vivo el cursor en blanco durante la sesion }
end;

procedure ReleaseInputFocus;
begin
  if gDpy <> nil then
  begin
    if gCur <> 0 then begin XFreeCursor(gDpy, gCur); gCur := 0; end;
    XCloseDisplay(gDpy);
    gDpy := nil;
  end;
end;

end.
