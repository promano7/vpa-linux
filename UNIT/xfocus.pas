{$MODE OBJFPC}{$H+}
{ xfocus - integra la ventana ptcgraph con el escritorio X:
    * pide el foco de teclado (ptcgraph hace XMapRaised pero NO XSetInputFocus).
    * oculta el puntero del sistema sobre la ventana (solo se ve la diana de VPA).
    * FullscreenRequested: ¿pidió el usuario pantalla completa? (env VPA_FULLSCREEN)
  Imprime diagnóstico en stderr para depurar si encuentra o no la ventana. }
unit xfocus;
interface
function  FullscreenRequested: boolean;
procedure GrabInputFocus;
implementation
uses x, xlib, xatom, ctypes, unixtype, baseunix, sysutils;

function FullscreenRequested: boolean;
begin
  FullscreenRequested := GetEnvironmentVariable('VPA_FULLSCREEN') <> '';
end;

{ ¿el título de la ventana 'nm' casa con lo que buscamos 'want'?
  Exacto, o el título termina en el nombre del binario (por si el gestor lo altera). }
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
          if diag then Writeln(StdErr, '  xfocus: ventana EWMH titulo="', string(nm), '"');
          if (res = 0) and TitleMatches(string(nm), want, base) then res := w;
          XFree(nm);
        end;
      end;
      XFree(prop);
    end;
  end;
  if res = 0 then    { respaldo: hijos directos del root (sin gestor/reparenting) }
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

procedure HideSystemCursor(dpy:PDisplay; win:TWindow);
const blank: array[0..7] of char = (#0,#0,#0,#0,#0,#0,#0,#0);
var pm: TPixmap; cur: TCursor; black: TXColor;
begin
  FillChar(black, sizeof(black), 0);
  pm := XCreateBitmapFromData(dpy, win, @blank, 8, 8);
  if pm <> None then
  begin
    cur := XCreatePixmapCursor(dpy, pm, pm, @black, @black, 0, 0);
    XDefineCursor(dpy, win, cur);
    XFreePixmap(dpy, pm);
  end;
end;

procedure GrabInputFocus;
var
  dpy: PDisplay; root, win: TWindow; want, base: string; tries: integer;
  ev: TXEvent; netActive: TAtom; ts: TTimeSpec; diag: boolean;
begin
  dpy := XOpenDisplay(nil);
  if dpy = nil then begin Writeln(StdErr,'xfocus: sin display X'); exit; end;
  root := XDefaultRootWindow(dpy);
  want := ParamStr(0);
  base := ExtractFileName(want);
  diag := GetEnvironmentVariable('VPA_XDEBUG') <> '';
  if diag then Writeln(StdErr, 'xfocus: buscando ventana titulo="', want, '" (base="', base, '")');
  win := 0; tries := 0;
  while (win = 0) and (tries < 20) do
  begin
    win := FindWin(dpy, root, want, base, diag and (tries = 0));
    if win = 0 then
    begin
      ts.tv_sec := 0; ts.tv_nsec := 50*1000000; fpnanosleep(@ts, nil);
      inc(tries);
    end;
  end;
  if win <> 0 then
  begin
    Writeln(StdErr, 'xfocus: ventana encontrada -> aplicando foco + ocultar cursor');
    HideSystemCursor(dpy, win);
    XRaiseWindow(dpy, win);
    XSetInputFocus(dpy, win, RevertToParent, CurrentTime);
    netActive := XInternAtom(dpy, '_NET_ACTIVE_WINDOW', 1);
    if netActive <> 0 then
    begin
      FillChar(ev, sizeof(ev), 0);
      ev.xclient._type := ClientMessage;
      ev.xclient.window := win;
      ev.xclient.message_type := netActive;
      ev.xclient.format := 32;
      ev.xclient.data.l[0] := 1;
      ev.xclient.data.l[1] := CurrentTime;
      XSendEvent(dpy, root, 0, SubstructureRedirectMask or SubstructureNotifyMask, @ev);
    end;
    XFlush(dpy);
  end
  else
    Writeln(StdErr, 'xfocus: VENTANA NO ENCONTRADA (titulo buscado="', want, '")');
  XCloseDisplay(dpy);
end;
end.
