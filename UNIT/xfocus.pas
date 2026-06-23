{$MODE OBJFPC}{$H+}
{ xfocus - integra la ventana ptcgraph con el escritorio X (Linux):
    * GrabInputFocus: localiza la ventana, oculta el puntero del sistema (cursor
      en blanco; usa conexion X PERSISTENTE para que el cursor no se libere) y
      pide el foco de teclado (ptcgraph hace XMapRaised pero no XSetInputFocus).
    * ReleaseInputFocus: suelta y cierra (llamar al salir).
    * DbgKey / DbgMouseBtn: si VPA_XDEBUG esta puesto, registran en stderr cada
      tecla/clic que VPA realmente recibe (para depurar el input). }
unit xfocus;
interface

function  FullscreenRequested: boolean;
procedure GrabInputFocus;
procedure ReleaseInputFocus;
procedure DbgKey(w: word);
procedure DbgMouseBtn(x, y: longint; btn: word);
procedure DbgDispatch(w: word);
procedure DbgPoll(installed, disabled: boolean; x, y, b: longint);
function  PointerInsideWindow: boolean;

implementation
uses x, xlib, xatom, ctypes, unixtype, baseunix, sysutils;

var
  gDpy: PDisplay = nil;          { conexion persistente (mantiene vivo el cursor) }
  gWin: TWindow  = 0;
  gCur: TCursor  = 0;
  gXDebug: boolean = False;

function FullscreenRequested: boolean;
begin
  FullscreenRequested := GetEnvironmentVariable('VPA_FULLSCREEN') <> '';
end;

procedure DbgKey(w: word);
begin
  if gXDebug then Writeln(StdErr, 'VPA recibe tecla = $', HexStr(w, 4));
end;

procedure DbgMouseBtn(x, y: longint; btn: word);
begin
  if not gXDebug then exit;
  if btn = $FFFF then Writeln(StdErr, 'VPA: raton MOVIDO a (', x, ',', y, ')')
  else Writeln(StdErr, 'VPA recibe raton botones=', btn, ' en (', x, ',', y, ')');
end;

procedure DbgDispatch(w: word);
begin
  if gXDebug then Writeln(StdErr, '>>> VPA DESPACHA ch=$', HexStr(w, 4), ' (Main salio del bucle)');
end;

procedure DbgPoll(installed, disabled: boolean; x, y, b: longint);
begin
  if gXDebug then
    Writeln(StdErr, 'PollMouse: habilitado=', installed, ' deshab=', disabled,
            '  ptc_raton=(', x, ',', y, ') botones=', b);
end;

{ ¿esta el puntero del raton dentro de la ventana de VPA? Se usa para no hacer
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

function TitleMatches(const nm, want, base: string): boolean;
begin
  TitleMatches := (nm = want)
    or ((base <> '') and (Length(nm) >= Length(base))
        and (Copy(nm, Length(nm)-Length(base)+1, Length(base)) = base));
end;

function FindWin(dpy:PDisplay; root:TWindow; const want, base:string; diag:boolean): TWindow;
var
  netcl, aType: TAtom; aFmt: cint; nItems, bAfter: culong; prop: PCUChar;
  wlist: PCULong; i: integer; w, res: TWindow; nm: PChar;
  rootR, parentR: TWindow; children: PWindow; nch: cuint;
begin
  res := 0;
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
          if (res = 0) and TitleMatches(string(nm), want, base) then res := w;
          XFree(nm);
        end;
      end;
      XFree(prop);
    end;
  end;
  if res = 0 then
    if XQueryTree(dpy, root, @rootR, @parentR, @children, @nch) <> 0 then
    begin
      for i := nch-1 downto 0 do
      begin
        nm := nil;
        if (XFetchName(dpy, children[i], @nm) <> 0) and (nm <> nil) then
        begin
          if (res = 0) and TitleMatches(string(nm), want, base) then res := children[i];
          XFree(nm);
        end;
      end;
      if children <> nil then XFree(children);
    end;
  FindWin := res;
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
  gXDebug := GetEnvironmentVariable('VPA_XDEBUG') <> '';
  if gDpy = nil then gDpy := XOpenDisplay(nil);
  if gDpy = nil then begin Writeln(StdErr,'xfocus: sin display X'); exit; end;
  root := XDefaultRootWindow(gDpy);
  want := ParamStr(0);
  base := ExtractFileName(want);
  gWin := 0; tries := 0;
  while (gWin = 0) and (tries < 20) do
  begin
    gWin := FindWin(gDpy, root, want, base, false);
    if gWin = 0 then
    begin
      ts.tv_sec := 0; ts.tv_nsec := 50*1000000; fpnanosleep(@ts, nil);
      inc(tries);
    end;
  end;
  if gWin <> 0 then
  begin
    Writeln(StdErr, 'xfocus: ventana encontrada -> pidiendo foco de teclado');
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
