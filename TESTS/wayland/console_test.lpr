{ VPA-Linux - WAYLAND.md, Fase 8, T8B.2: lo que el prototipo de la consola
  SDL3 dejo vacio. Habla con la consola directamente (sin wrapper ni
  ptcgraph): Clear con color y area, Save, Copy, las opciones de cursor y
  MoveMouseTo (R12).

  MoveMouseTo depende del compositor (wp_pointer_warp_v1 o
  zwp_pointer_constraints_v1) y de que la ventana tenga el puntero encima,
  cosa que en un weston sin pantalla no ocurre: aqui solo se exige que fuera
  de la consola devuelva False y que dentro no reviente; el resultado se
  imprime. La prueba de verdad es el iman sobre planetas en un compositor real.

    uso: con-weston.sh console_test }
program console_test;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF} SysUtils, ptc;

var
  Fails: Integer = 0;

procedure Check(AOk: Boolean; const AWhat: string);
begin
  if AOk then WriteLn('  ok   ', AWhat)
  else begin WriteLn('  FAIL ', AWhat); Inc(Fails); end;
end;

const
  W = 640; H = 480;
var
  con: IPTCConsole;
  fmt: IPTCFormat;
  surf: IPTCSurface;
  buf: array of LongWord;
  p: PLongWord;
  i, bad: Integer;
  r: Boolean;
begin
  try
    fmt := TPTCFormatFactory.CreateNew(32, $FF0000, $FF00, $FF);
    con := TPTCConsoleFactory.CreateNew;
    Check(con.Option('hide cursor'), 'Option(hide cursor) before Open');
    con.Open('console_test', W, H, fmt);
    WriteLn('  ', con.Information);
    Check(con.Option('show cursor'), 'Option(show cursor)');
    Check(con.Option('hide cursor'), 'Option(hide cursor)');
    Check(con.Option('show cursor'), 'Option(show cursor) again');

    { Clear(color) y Clear(color, area) }
    con.Clear(TPTCColorFactory.CreateNew(1, 0, 0));
    con.Clear(TPTCColorFactory.CreateNew(0, 0, 1),
              TPTCAreaFactory.CreateNew(10, 20, 110, 70));
    p := con.Lock;
    bad := 0;
    for i := 0 to W * H - 1 do
      if ((i mod W >= 10) and (i mod W < 110) and
          (i div W >= 20) and (i div W < 70)) then
      begin
        if (p[i] and $FFFFFF) <> $0000FF then Inc(bad);
      end
      else if (p[i] and $FFFFFF) <> $FF0000 then Inc(bad);
    con.Unlock;
    Check(bad = 0, 'Clear(color) + Clear(color, area): ' + IntToStr(bad) +
                   ' wrong pixels');
    con.Update;

    { Save }
    SetLength(buf, W * H);
    con.Save(@buf[0], W, H, W * 4, fmt, TPTCPaletteFactory.CreateNew);
    Check(((buf[0] and $FFFFFF) = $FF0000) and
          ((buf[20 * W + 10] and $FFFFFF) = $0000FF) and
          ((buf[69 * W + 109] and $FFFFFF) = $0000FF) and
          ((buf[70 * W + 110] and $FFFFFF) = $FF0000), 'Save');

    { Copy a una superficie }
    surf := TPTCSurfaceFactory.CreateNew(W, H, fmt);
    con.Copy(surf);
    p := surf.Lock;
    Check(((p[0] and $FFFFFF) = $FF0000) and
          ((p[20 * W + 10] and $FFFFFF) = $0000FF), 'Copy(surface)');
    surf.Unlock;

    { Clear sin argumentos: negro }
    con.Clear;
    p := con.Lock;
    Check((p[0] and $FFFFFF) = 0, 'Clear');
    con.Unlock;

    { MoveMouseTo }
    Check(not con.MoveMouseTo(-1, 5), 'MoveMouseTo(-1, 5) -> False');
    Check(not con.MoveMouseTo(W, 5), 'MoveMouseTo(width, 5) -> False');
    r := con.MoveMouseTo(320, 240);
    WriteLn('  info MoveMouseTo(320, 240) -> ', r);

    con.Close;
    Check(True, 'Close');
  except
    on E: TPTCError do
      begin WriteLn('  FAIL TPTCError: ', E.Message); Inc(Fails); end;
  end;
  if Fails = 0 then WriteLn('console_test: PASS')
  else begin WriteLn('console_test: FAIL (', Fails, ')'); Halt(1); end;
end.
