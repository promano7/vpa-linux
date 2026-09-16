{ threads_test - experimento de T5.9 (WAYLAND.md): hilos y dos RTL en el
  mismo proceso.

  Carga build/plugins/libvpagraph-x11.so con dlopen(RTLD_NOW) y le hace
  Init -> dibujar -> Shutdown N veces, y luego dlclose. El plugin lleva su
  propio RTL con cthreads (ptcwrapper lo exige) y levanta el hilo de eventos
  X11 de ptc en cada Init; el proceso que lo carga es ESTE programa, con
  otro RTL, que se compila dos veces:

    - sin cthreads (por defecto), y
    - con cthreads (-dUSE_CTHREADS),

  para responder a las preguntas (b) y (c) de T5.9: si el ejecutable puede
  prescindir de cthreads y como se comporta el gestor de hilos con dos RTL.
  Lo que se observa se escribe en docs/threads-and-rtl.md.

  Ademas de que no se cuelgue, el arnes imprime:
    - IsMultiThread de SU RTL antes y despues de cargar el plugin: si el
      plugin lo cambiara, seria una pista de que los dos RTL se pisan;
    - las mascaras de senales capturadas (SigCgt de /proc/self/status)
      antes y despues de dlopen, para saber si el RTL del .so reinstala los
      manejadores de SIGSEGV/SIGINT del proceso, que es lo que VPAEXIT
      necesita saber antes de fiarse de Terminate y del guardado de
      emergencia.

  No pasa por GRAPH/vpagraph_loader.pas a proposito: el cargador rechaza,
  con razon, un plugin al que le faltan las funciones de entrada (T5.8), y
  este experimento tiene que poder correr antes de escribirlas.

  Uso:  threads_test <ruta del .so> [ciclos]     (bajo Xvfb)
  Salida 0 si todo fue bien; 1 si algo fallo. }
program threads_test;

{$MODE OBJFPC}{$H+}

uses
  {$IFDEF USE_CTHREADS}cthreads,{$ENDIF}
  SysUtils, dl;

{$I vpagraph_abi.inc}

var
  Failures: Integer = 0;

procedure Check(Cond: Boolean; const What: AnsiString);
begin
  if Cond then
    Writeln('  ok   ', What)
  else
  begin
    Writeln('  FAIL ', What);
    Inc(Failures);
  end;
end;

{ La linea SigCgt de /proc/self/status: mascara hexadecimal de las senales
  con manejador instalado en este proceso. }
function CaughtSignals: AnsiString;
var
  F: TextFile;
  L: AnsiString;
begin
  Result := '?';
  AssignFile(F, '/proc/self/status');
  {$I-} Reset(F); {$I+}
  if IOResult <> 0 then Exit;
  while not Eof(F) do
  begin
    Readln(F, L);
    if Copy(L, 1, 7) = 'SigCgt:' then
    begin
      Result := Trim(Copy(L, 8, Length(L)));
      Break;
    end;
  end;
  CloseFile(F);
end;

function ErrText(const I: TVPAGraphInterface): AnsiString;
var
  Buf: array[0..VPAG_ERROR_BUFFER_SIZE - 1] of AnsiChar;
begin
  Buf[0] := #0;
  if Assigned(I.GetLastError) then I.GetLastError(@Buf[0], SizeOf(Buf));
  Result := AnsiString(PAnsiChar(@Buf[0]));
end;

var
  Path      : AnsiString;
  Cycles, C : Integer;
  H         : Pointer;
  Entry     : TVPAGraphGetInterfaceProc;
  Iface     : TVPAGraphInterface;
  Params    : TVPAGraphInitParams;
  R         : TVPAGraphInt32;
  SigBefore, SigAfter: AnsiString;
  MTBefore  : Boolean;
  T0        : QWord;
function Run: Integer;
begin
  if ParamCount < 1 then
  begin
    Writeln('usage: threads_test <libvpagraph-x11.so> [cycles]');
    Exit(2);
  end;
  Path := ParamStr(1);
  Cycles := 20;
  if ParamCount >= 2 then Cycles := StrToIntDef(ParamStr(2), 20);

  Writeln('threads_test: harness RTL ',
    {$IFDEF USE_CTHREADS}'WITH'{$ELSE}'WITHOUT'{$ENDIF}, ' cthreads, ',
    Cycles, ' cycles');

  MTBefore := IsMultiThread;
  SigBefore := CaughtSignals;
  Writeln('  before dlopen: IsMultiThread=', MTBefore, ' SigCgt=', SigBefore);

  dlerror;
  H := dlopen(PAnsiChar(Path), RTLD_NOW);
  Check(H <> nil, 'dlopen(RTLD_NOW) ' + Path);
  if H = nil then
  begin
    Writeln('  dlerror: ', AnsiString(dlerror));
    Exit(1);
  end;

  SigAfter := CaughtSignals;
  Writeln('  after  dlopen: IsMultiThread=', IsMultiThread, ' SigCgt=', SigAfter);
  Check(IsMultiThread = MTBefore, 'IsMultiThread of the harness RTL untouched by the plugin RTL');
  if SigAfter <> SigBefore then
    Writeln('  NOTE: the plugin RTL changed the caught-signal mask (', SigBefore, ' -> ', SigAfter, ')')
  else
    Writeln('  note: caught-signal mask unchanged');

  Pointer(Entry) := dlsym(H, VPAGRAPH_ENTRY_POINT);
  Check(Entry <> nil, 'dlsym ' + VPAGRAPH_ENTRY_POINT);
  if Entry = nil then Exit(1);

  FillChar(Iface, SizeOf(Iface), 0);
  R := Entry(VPAGRAPH_ABI_VERSION, SizeOf(Iface), @Iface);
  Check(R = VPAG_OK, 'VPAGraph_GetInterface -> ' + IntToStr(R));
  if R <> VPAG_OK then Exit(1);
  Writeln('  backend: ', AnsiString(Iface.BackendName), ' ', AnsiString(Iface.BackendVersion));

  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize := SizeOf(Params);
  Params.Width := 640;
  Params.Height := 480;
  Params.ScalePercent := 100;
  Params.WindowTitle := 'threads_test';

  T0 := GetTickCount64;
  for C := 1 to Cycles do
  begin
    R := Iface.Init(@Params);
    if R <> VPAG_OK then
    begin
      Check(False, 'cycle ' + IntToStr(C) + ': Init -> ' + IntToStr(R) + ' (' + ErrText(Iface) + ')');
      Break;
    end;
    Iface.SetColor(14);
    Iface.Line(0, 0, 639, 479);
    Iface.OutTextXY(10, 10, 'threads_test');
    R := Iface.Present();
    if R <> VPAG_OK then
    begin
      Check(False, 'cycle ' + IntToStr(C) + ': Present -> ' + IntToStr(R));
      Break;
    end;
    R := Iface.Shutdown();
    if R <> VPAG_OK then
    begin
      Check(False, 'cycle ' + IntToStr(C) + ': Shutdown -> ' + IntToStr(R) + ' (' + ErrText(Iface) + ')');
      Break;
    end;
    if (C = 1) or (C = Cycles) then
      Writeln('  cycle ', C, ': Init/Present/Shutdown ok, IsMultiThread=', IsMultiThread);
  end;
  Check(Iface.Shutdown() = VPAG_OK, 'Shutdown is idempotent');
  Writeln('  ', Cycles, ' cycles in ', GetTickCount64 - T0, ' ms');

  FillChar(Iface, SizeOf(Iface), 0);
  Check(dlclose(H) = 0, 'dlclose');
  Writeln('  after  dlclose: IsMultiThread=', IsMultiThread, ' SigCgt=', CaughtSignals);

  if Failures = 0 then
  begin
    Writeln('threads_test: PASS');
    Exit(0);
  end;
  Writeln('threads_test: ', Failures, ' failure(s)');
  Exit(1);
end;

{ Las cadenas temporales del programa principal no se liberan si se sale con
  Halt desde dentro de begin..end, y heaptrc las contaria como fugas del
  arnes (que no lo son): por eso el trabajo esta en Run. }
begin
  ExitCode := Run;
end.
