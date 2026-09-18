{ initgraph_test - Fase 6 de WAYLAND.md, T6.3: InitGraph de VPAGraph detecta,
  carga, valida y arranca el backend, con respaldo solo en 'auto'.

  Programa -Mtp minimo: InitGraph, dice que paso, pinta algo, CloseGraph, y
  lo repite una segunda vez (InitGraph -> CloseGraph tiene que ser un ciclo
  repetible: es lo que hara Suspend/Resume si algun backend lo necesita).
  El entorno lo prepara el Makefile (objetivo initgraph-test), que es quien
  comprueba la salida; aqui solo se imprime:

    result <GraphResult>
    backend <nombre o ->
    detail: <una linea por motivo acumulado>

  Se compila con -gh: heaptrc dice si el nucleo deja algo sin liberar.
  Salida 0 si InitGraph fue bien las dos veces, 2 si fallo. }
program initgraph_test;

uses
  vpagraph;

var
  gd, gm, r, pass : integer;
  ok : boolean;

procedure PrintDetail;
var
  s : ansistring;
  p : longint;
begin
  s := VPAGraphInitDetail;
  while s <> '' do
  begin
    p := Pos(#10, s);
    if p = 0 then p := Length(s) + 1;
    Writeln('detail: ', Copy(s, 1, p - 1));
    Delete(s, 1, p);
  end;
end;

begin
  ok := true;
  for pass := 1 to 2 do
  begin
    gd := D8bit;
    gm := m640x480;
    InitGraph(gd, gm, '');
    r := GraphResult;
    Writeln('result ', r);
    if VPAGraphBackendName <> '' then
      Writeln('backend ', VPAGraphBackendName)
    else
      Writeln('backend -');
    PrintDetail;
    if r <> grOk then ok := false;
    SetColor(White);
    Line(0, 0, 639, 479);
    OutTextXY(10, 10, 'initgraph_test');
    { el patron de INI/BUILDING/MESSAGES/VCS para lanzar un programa externo:
      Suspend y Resume de la ABI. Tras reanudar se tiene que poder dibujar, y
      un SetGraphMode suelto no debe hacer nada. }
    RestoreCrtMode;
    SetGraphMode(GetGraphMode);
    SetGraphMode(GetGraphMode);
    PutPixel(5, 5, Yellow);
    if r = grOk then
      Writeln('after resume: pixel ', GetPixel(5, 5), ' result ', GraphResult);
    Flush(Output);
    CloseGraph;
  end;
  if not ok then Halt(2);
end.
