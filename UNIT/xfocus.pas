{$MODE OBJFPC}{$H+}
{ xfocus - pide al servidor X / gestor de ventanas el foco de teclado para
  nuestra ventana ptcgraph. ptcgraph hace XMapRaised pero NO XSetInputFocus,
  asi que bajo gestores como Cinnamon la ventana no recibe el teclado al abrir. }
unit xfocus;
interface
procedure GrabInputFocus;
implementation
uses x, xlib, xatom, ctypes, unixtype, baseunix;

function FindByTitle(dpy:PDisplay; root:TWindow; const want:string): TWindow;
var
  netcl, aType: TAtom; aFmt: cint; nItems, bAfter: culong; prop: PCUChar;
  wlist: PCULong; i: integer; w, res: TWindow; nm: PChar;
  rootR, parentR: TWindow; children: PWindow; nch: cuint;
begin
  res := 0;
  netcl := XInternAtom(dpy, '_NET_CLIENT_LIST', 1);   { solo si existe (EWMH) }
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
          if string(nm) = want then res := w;
          XFree(nm);
        end;
        if res <> 0 then break;
      end;
      XFree(prop);
    end;
  end;
  if res = 0 then    { respaldo: hijos directos del root (sin gestor/reparenting) }
  begin
    if XQueryTree(dpy, root, @rootR, @parentR, @children, @nch) <> 0 then
    begin
      for i := nch-1 downto 0 do
      begin
        nm := nil;
        if (XFetchName(dpy, children[i], @nm) <> 0) and (nm <> nil) then
        begin
          if string(nm) = want then res := children[i];
          XFree(nm);
        end;
        if res <> 0 then break;
      end;
      if children <> nil then XFree(children);
    end;
  end;
  FindByTitle := res;
end;

procedure GrabInputFocus;
var
  dpy: PDisplay; root, win: TWindow; want: string; tries: integer;
  ev: TXEvent; netActive: TAtom; ts: TTimeSpec;
begin
  dpy := XOpenDisplay(nil);
  if dpy = nil then exit;
  root := XDefaultRootWindow(dpy);
  want := ParamStr(0);
  win := 0; tries := 0;
  while (win = 0) and (tries < 20) do   { reintenta ~1s: el gestor tarda en gestionarla }
  begin
    win := FindByTitle(dpy, root, want);
    if win = 0 then
    begin
      ts.tv_sec := 0; ts.tv_nsec := 50*1000000; fpnanosleep(@ts, nil);
      inc(tries);
    end;
  end;
  if win <> 0 then
  begin
    XRaiseWindow(dpy, win);
    XSetInputFocus(dpy, win, RevertToParent, CurrentTime);
    netActive := XInternAtom(dpy, '_NET_ACTIVE_WINDOW', 1);   { via EWMH si hay gestor }
    if netActive <> 0 then
    begin
      FillChar(ev, sizeof(ev), 0);
      ev.xclient._type := ClientMessage;
      ev.xclient.window := win;
      ev.xclient.message_type := netActive;
      ev.xclient.format := 32;
      ev.xclient.data.l[0] := 1;            { fuente = aplicacion }
      ev.xclient.data.l[1] := CurrentTime;
      XSendEvent(dpy, root, 0, SubstructureRedirectMask or SubstructureNotifyMask, @ev);
    end;
    XFlush(dpy);
  end;
  XCloseDisplay(dpy);
end;
end.
