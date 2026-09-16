{ nodisplay_test - criterio de aceptacion de T5.5b (WAYLAND.md): Init sin
  servidor X tiene que fallar limpio.

  Carga build/plugins/libvpagraph-x11.so con dlopen(RTLD_NOW) SIN DISPLAY en
  el entorno y comprueba que:

    - Init devuelve VPAG_ERR_VIDEO (no aborta el proceso con un error 217:
      antes de T5.5b el TPTCError de TX11Console.Open moria dentro del hilo
      de ptc, donde nadie lo capturaba);
    - GetLastError explica el motivo ('Cannot open X display');
    - GraphResult sigue devolviendo ese mismo error;
    - un segundo Init falla igual (el plugin queda reutilizable, no roto);
    - Shutdown despues de un Init fallido devuelve VPAG_OK (idempotente);
    - dlclose termina: el hilo de ptc que Init creo se destruyo al fallar,
      asi que no queda vivo hasta la finalization del .so (T5.9).

  Sin esto, la seleccion 'auto' de la Fase 6 no puede probar el plugin X11
  y caer al de Wayland cuando no hay servidor X.

  No pasa por GRAPH/vpagraph_loader.pas por el mismo motivo que threads_test:
  el cargador rechaza un plugin sin las funciones de entrada (T5.8).

  Uso:  env -u DISPLAY nodisplay_test <ruta del .so>
  Salida 0 si todo fue bien; 1 si algo fallo. }
program nodisplay_test;

{$MODE OBJFPC}{$H+}

uses
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

function ErrText(const I: TVPAGraphInterface): AnsiString;
var
  Buf: array[0..VPAG_ERROR_BUFFER_SIZE - 1] of AnsiChar;
begin
  Buf[0] := #0;
  I.GetLastError(@Buf[0], SizeOf(Buf));
  ErrText := AnsiString(PAnsiChar(@Buf[0]));
end;

var
  Path   : AnsiString;
  H      : Pointer;
  Entry  : TVPAGraphGetInterfaceProc;
  Iface  : TVPAGraphInterface;
  Params : TVPAGraphInitParams;
  R      : TVPAGraphInt32;
  Msg    : AnsiString;
  T0     : QWord;

function Run: Integer;
begin
  if ParamCount < 1 then
  begin
    Writeln('usage: nodisplay_test <libvpagraph-x11.so>');
    Exit(2);
  end;
  Path := ParamStr(1);

  Writeln('nodisplay_test: ', Path);
  Check(GetEnvironmentVariable('DISPLAY') = '', 'DISPLAY is not set');

  H := dlopen(PAnsiChar(Path), RTLD_NOW);
  Check(H <> nil, 'dlopen(RTLD_NOW) ' + Path);
  if H = nil then
  begin
    Writeln('  dlerror: ', AnsiString(dlerror));
    Exit(1);
  end;

  Pointer(Entry) := dlsym(H, VPAGRAPH_ENTRY_POINT);
  Check(Entry <> nil, 'dlsym ' + VPAGRAPH_ENTRY_POINT);
  if Entry = nil then Exit(1);

  FillChar(Iface, SizeOf(Iface), 0);
  R := Entry(VPAGRAPH_ABI_VERSION, SizeOf(Iface), @Iface);
  Check(R = VPAG_OK, 'VPAGraph_GetInterface -> ' + IntToStr(R));
  if R <> VPAG_OK then Exit(1);

  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize := SizeOf(Params);
  Params.Width := 640;
  Params.Height := 480;
  Params.ScalePercent := 100;
  Params.WindowTitle := 'nodisplay_test';

  R := Iface.Init(@Params);
  Msg := ErrText(Iface);
  Check(R = VPAG_ERR_VIDEO, 'Init without DISPLAY -> ' + IntToStr(R) +
    ' (expected VPAG_ERR_VIDEO = ' + IntToStr(VPAG_ERR_VIDEO) + ')');
  Check(Pos('Cannot open X display', Msg) > 0, 'GetLastError: "' + Msg + '"');
  Check(Iface.GraphResult() = VPAG_ERR_VIDEO, 'GraphResult keeps VPAG_ERR_VIDEO');

  R := Iface.Init(@Params);
  Check(R = VPAG_ERR_VIDEO, 'second Init fails the same way -> ' + IntToStr(R));

  R := Iface.Shutdown();
  Check(R = VPAG_OK, 'Shutdown after a failed Init -> ' + IntToStr(R));

  T0 := GetTickCount64;
  Check(dlclose(H) = 0, 'dlclose');
  Writeln('  dlclose took ', GetTickCount64 - T0, ' ms');

  if Failures = 0 then
  begin
    Writeln('nodisplay_test: PASS');
    Exit(0);
  end;
  Writeln('nodisplay_test: FAIL (', Failures, ')');
  Exit(1);
end;

begin
  Halt(Run);
end.
