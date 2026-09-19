{ T7.4 (WAYLAND.md) - prototipo DESECHABLE. El mismo guion de lineas:
    sin define   -> via A (viaa_bgi.pas), escribe <prefijo>0001.ppm con la
                    paleta que se le pasa (la .pal de la referencia);
    -dREFERENCIA -> ptcgraph de verdad, volcado con VPADumpFrameTo.
  uso:  t74_via_a <prefijo> <paleta.pal>      t74_ref <prefijo>  (bajo Xvfb) }
program t74_line;
{$mode objfpc}{$H+}
uses
  {$IFDEF REFERENCIA}cthreads, ptcgraph
  {$ELSE}{$IFDEF INTENTO1}viaa_bgi_intento1{$ELSE}viaa_bgi{$ENDIF}{$ENDIF};
{$I t74_script.inc}
{$IFDEF REFERENCIA}
var gd, gm: SmallInt;
begin
  gd := D8bit; gm := m640x480;   { como VPA }
  InitGraph(gd, gm, '');
  if GraphResult <> grOk then Halt(1);
  DrawScript;
  if VPADumpFrameTo(ParamStr(1)) <= 0 then Halt(1);
  CloseGraph;
end.
{$ELSE}
var
  pal: array[0..767] of Byte; f: file; x, y: Integer; o: Text; row: array[0..1919] of Byte;
begin
  Assign(f, ParamStr(2)); Reset(f, 1); BlockRead(f, pal, 768); Close(f);
  DrawScript;
  Assign(o, ParamStr(1) + '0001.ppm'); Rewrite(o);
  Write(o, 'P6'#10'640 480'#10'255'#10); System.Close(o);
  Assign(f, ParamStr(1) + '0001.ppm'); Reset(f, 1); Seek(f, FileSize(f));
  for y := 0 to 479 do
  begin
    for x := 0 to 639 do Move(pal[FB[y, x] * 3], row[x * 3], 3);
    BlockWrite(f, row, 1920);
  end;
  Close(f);
end.
{$ENDIF}
