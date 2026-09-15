{ loader_test - arnes de pruebas del cargador dinamico (T3.9 y T3.10).

  Uso:
    loader_test <directorio-con-los-.so>

  Espera encontrar en ese directorio las seis bibliotecas de TESTS/abi/
  (stub_backend.so y los cinco bad_*.so) y comprueba, en este orden:

    1. que stub_backend.so carga, se identifica, se puede llamar a traves de
       la tabla (Init/Shutdown) y se descarga;
    2. que despues de descargar la tabla esta a nil (T3.6);
    3. que 100 ciclos de carga/descarga no dejan ni memoria ni descriptores
       de fichero colgando (T3.9): se compara el heap del RTL y el numero de
       entradas de /proc/self/fd antes y despues;
    4. que los cuatro plugins defectuosos de T2.16 se rechazan, cada uno con
       un codigo DISTINTO y un mensaje que dice que le pasa (T3.10), y que el
       quinto, con un simbolo sin resolver, lo rechaza dlopen gracias a
       RTLD_NOW en vez de cargar y caer despues;
    5. que un fichero inexistente, un directorio y un fichero sin permiso de
       lectura se rechazan antes de llegar a dlopen (T3.3);
    6. que una ruta relativa se rechaza sin mirar el disco (T3.2);
    7. que VPAGraph_LoadBackend acumula un motivo por candidato (T3.7).

  Se construye con -gh (heaptrc) desde el Makefile: ademas de las
  comprobaciones propias, heaptrc imprime su resumen al salir y tiene que
  decir 0 unfreed memory blocks. Codigo de salida 0 si todo pasa. }
program loader_test;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, BaseUnix, vpagraph_loader, vpagraph_errors;

{$I vpagraph_abi.inc}

{ setenv/unsetenv de libc: BaseUnix no los envuelve y el arnes los necesita
  para probar VPA_GRAPH_PLUGIN_DIR en sus tres estados. }
function setenv(Name, Value: PAnsiChar; Overwrite: cint): cint; cdecl; external 'c';
function unsetenv(Name: PAnsiChar): cint; cdecl; external 'c';

var
  Dir     : AnsiString;
  Failed  : Integer = 0;
  Passed  : Integer = 0;

procedure Check(Cond: Boolean; const What: AnsiString);
begin
  if Cond then
  begin
    Inc(Passed);
    WriteLn('  ok    ', What);
  end
  else
  begin
    Inc(Failed);
    WriteLn('  FALLO ', What);
  end;
end;

{ Lineas de un Detail multilinea: una por motivo acumulado. }
function CountLines(const S: AnsiString): Integer;
var
  I: Integer;
begin
  if S = '' then Exit(0);
  Result := 1;
  for I := 1 to Length(S) do
    if S[I] = #10 then Inc(Result);
end;

function CountFds: Integer;
var
  D: pDir;
  E: pDirent;
begin
  Result := 0;
  D := fpOpenDir('/proc/self/fd');
  if D = nil then Exit(-1);
  repeat
    E := fpReadDir(D^);
    if E <> nil then Inc(Result);
  until E = nil;
  fpCloseDir(D^);
  { El propio directorio abierto cuenta como uno mientras se lee. }
  Dec(Result);
end;

{ ---------------------------------------------------------------------------
  1 y 2: el camino bueno
  --------------------------------------------------------------------------- }
procedure TestStub;
var
  P      : TVPAGraphPlugin;
  Detail : AnsiString;
  Rc     : longint;
  Params : TVPAGraphInitParams;
  Title  : AnsiString;
begin
  WriteLn('[1] stub_backend.so');
  FillChar(P, SizeOf(P), 0);
  Rc := VPAGraph_LoadPlugin(Dir + '/stub_backend.so', P, Detail);
  Check(Rc = VPAGL_OK, 'carga: ' + VPAGraph_FormatError(Rc, Detail, vglSpanish));
  if Rc <> VPAGL_OK then Exit;
  Check(P.Loaded, 'Loaded = True');
  Check(P.Handle <> 0, 'Handle asignado');
  Check(AnsiString(P.Iface.BackendName) = 'stub',
    'BackendName = ' + AnsiString(P.Iface.BackendName));
  Check(AnsiString(P.Iface.BackendVersion) = '1.0',
    'BackendVersion = ' + AnsiString(P.Iface.BackendVersion));
  Check(P.Iface.ABIVersion = VPAGRAPH_ABI_VERSION, 'ABIVersion negociada');

  { Llamar a traves de la tabla: primero mal, para ver el mensaje del plugin
    cruzar la frontera en el buffer del llamante; luego bien. }
  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize := SizeOf(Params);
  Params.Width := 0; Params.Height := 0;
  Rc := P.Iface.Init(@Params);
  Check(Rc = VPAG_ERR_INVALID_PARAM, 'Init con 0x0 devuelve VPAG_ERR_INVALID_PARAM');
  Detail := VPAGraph_PluginMessage(P);
  Check(Detail <> '', 'GetLastError via buffer del llamante: "' + Detail + '"');
  Check(VPAGraph_FormatError(Rc, Detail, vglEnglish) =
    'invalid parameter: ' + Detail, 'FormatError en ingles');

  Title := 'loader_test';
  Params.Width := 640; Params.Height := 480; Params.ScalePercent := 100;
  Params.WindowTitle := PAnsiChar(Title);
  Rc := P.Iface.Init(@Params);
  Check(Rc = VPAG_OK, 'Init 640x480 devuelve VPAG_OK');
  Check(P.Iface.ImageSize(0, 0, 103, 103) = 12 + 104 * 104 * 2,
    'ImageSize(104x104) = 12 + 104*104*2');
  Rc := P.Iface.Shutdown();
  Check(Rc = VPAG_OK, 'Shutdown devuelve VPAG_OK');

  { Segundo LoadPlugin sobre el mismo registro: rechazado, sin tocar nada }
  Rc := VPAGraph_LoadPlugin(Dir + '/stub_backend.so', P, Detail);
  Check(Rc = VPAGL_ERR_ALREADY, 'segunda carga en el mismo registro: ' +
    VPAGraph_FormatError(Rc, Detail, vglSpanish));
  Check(P.Loaded, 'el registro original sigue cargado');

  VPAGraph_UnloadPlugin(P);
  WriteLn('[2] descarga ordenada (T3.6)');
  Check(not P.Loaded, 'Loaded = False');
  Check(P.Handle = 0, 'Handle = 0');
  Check(P.Path = '', 'Path vacio');
  Check(P.Iface.Init = nil, 'Iface.Init = nil');
  Check(P.Iface.OutTextXY = nil, 'Iface.OutTextXY = nil');
  Check(P.Iface.BackendName = nil, 'Iface.BackendName = nil');
  Check(P.Iface.StructSize = 0, 'Iface.StructSize = 0');
  VPAGraph_UnloadPlugin(P);
  Check(not P.Loaded, 'segunda descarga es inocua');
end;

{ ---------------------------------------------------------------------------
  3: cien ciclos
  --------------------------------------------------------------------------- }
procedure TestCycles;
var
  P      : TVPAGraphPlugin;
  Detail : AnsiString;
  I, Rc  : longint;
  Fds0, Fds1 : Integer;
  Heap0, Heap1 : PtrUInt;
  Params : TVPAGraphInitParams;
  AllOk  : Boolean;
begin
  WriteLn('[3] 100 ciclos de carga/descarga (T3.9)');
  FillChar(P, SizeOf(P), 0);
  FillChar(Params, SizeOf(Params), 0);
  Params.StructSize := SizeOf(Params);
  Params.Width := 640; Params.Height := 480; Params.ScalePercent := 100;

  { Un ciclo de calentamiento fuera de la medida: el primer dlopen puede
    reservar cosas del propio ld.so que luego se reutilizan. }
  Rc := VPAGraph_LoadPlugin(Dir + '/stub_backend.so', P, Detail);
  Check(Rc = VPAGL_OK, 'ciclo de calentamiento');
  VPAGraph_UnloadPlugin(P);

  Fds0  := CountFds;
  Heap0 := GetFPCHeapStatus.CurrHeapUsed;
  AllOk := True;
  for I := 1 to 100 do
  begin
    Rc := VPAGraph_LoadPlugin(Dir + '/stub_backend.so', P, Detail);
    if Rc <> VPAGL_OK then begin AllOk := False; Break; end;
    if P.Iface.Init(@Params) <> VPAG_OK then begin AllOk := False; Break; end;
    if P.Iface.Shutdown() <> VPAG_OK then begin AllOk := False; Break; end;
    VPAGraph_UnloadPlugin(P);
  end;
  Fds1  := CountFds;
  Heap1 := GetFPCHeapStatus.CurrHeapUsed;
  Check(AllOk, '100 ciclos completados (ultimo: ' +
    VPAGraph_FormatError(Rc, Detail, vglSpanish) + ')');
  Check(not P.Loaded, 'nada cargado al final');
  Check(Fds1 = Fds0, 'descriptores de fichero: ' + IntToStr(Fds0) +
    ' antes, ' + IntToStr(Fds1) + ' despues');
  Check(Heap1 = Heap0, 'heap del RTL: ' + IntToStr(Heap0) + ' antes, ' +
    IntToStr(Heap1) + ' despues');
end;

{ ---------------------------------------------------------------------------
  4: los cuatro defectuosos
  --------------------------------------------------------------------------- }
procedure TestBad;
const
  Names: array[0..4] of AnsiString =
    ('bad_nosymbol', 'bad_abiversion', 'bad_structsize', 'bad_nullprocs',
     'bad_unresolved');
var
  P      : TVPAGraphPlugin;
  Detail : AnsiString;
  Codes  : array[0..4] of longint;
  Msgs   : array[0..4] of AnsiString;
  I, J   : Integer;
  Distinct : Boolean;
begin
  WriteLn('[4] plugins defectuosos (T3.10)');
  for I := 0 to 4 do
  begin
    FillChar(P, SizeOf(P), 0);
    Codes[I] := VPAGraph_LoadPlugin(Dir + '/' + Names[I] + '.so', P, Detail);
    Msgs[I]  := VPAGraph_FormatError(Codes[I], Detail, vglSpanish);
    Check(Codes[I] <> VPAGL_OK, Names[I] + ' rechazado');
    Check(not P.Loaded, Names[I] + ': registro limpio tras el rechazo');
    Check(P.Iface.Init = nil, Names[I] + ': tabla a nil tras el rechazo');
    WriteLn('        -> ', Msgs[I]);
  end;
  Check(Codes[0] = VPAGL_ERR_NO_SYMBOL,    'bad_nosymbol   -> VPAGL_ERR_NO_SYMBOL');
  Check(Codes[1] = VPAGL_ERR_ABI_MISMATCH, 'bad_abiversion -> VPAGL_ERR_ABI_MISMATCH');
  Check(Codes[2] = VPAGL_ERR_STRUCT_SIZE,  'bad_structsize -> VPAGL_ERR_STRUCT_SIZE');
  Check(Codes[3] = VPAGL_ERR_NULL_PROC,    'bad_nullprocs  -> VPAGL_ERR_NULL_PROC');
  Check(Codes[4] = VPAGL_ERR_LOAD_FAILED,  'bad_unresolved -> VPAGL_ERR_LOAD_FAILED (RTLD_NOW)');
  Distinct := True;
  for I := 0 to 4 do
    for J := I + 1 to 4 do
      if (Codes[I] = Codes[J]) or (Msgs[I] = Msgs[J]) then Distinct := False;
  Check(Distinct, 'los cinco codigos y los cinco mensajes son distintos');
  Check(Pos('Shutdown', Msgs[3]) > 0, 'bad_nullprocs: el mensaje nombra la funcion que falta');
  Check(Pos('99', Msgs[1]) > 0, 'bad_abiversion: el mensaje dice que version anuncia');
end;

{ ---------------------------------------------------------------------------
  5 y 6: validaciones previas y ruta relativa
  --------------------------------------------------------------------------- }
procedure TestFiles;
var
  P      : TVPAGraphPlugin;
  Detail : AnsiString;
  Rc     : longint;
  Unread : AnsiString;
  F      : Text;
begin
  WriteLn('[5] validaciones previas (T3.3)');
  FillChar(P, SizeOf(P), 0);

  Rc := VPAGraph_LoadPlugin(Dir + '/no_existe.so', P, Detail);
  Check(Rc = VPAGL_ERR_NOT_FOUND, 'inexistente: ' + VPAGraph_FormatError(Rc, Detail, vglSpanish));

  Rc := VPAGraph_LoadPlugin(Dir, P, Detail);
  Check(Rc = VPAGL_ERR_NOT_REGULAR, 'directorio: ' + VPAGraph_FormatError(Rc, Detail, vglSpanish));

  Rc := VPAGraph_LoadPlugin('/dev/null', P, Detail);
  Check(Rc = VPAGL_ERR_NOT_REGULAR, 'dispositivo: ' + VPAGraph_FormatError(Rc, Detail, vglSpanish));

  { Fichero regular no legible. root lo lee todo, asi que bajo root esta
    prueba no puede fallar y se salta con aviso. }
  if fpGetEUid = 0 then
    WriteLn('  (omitida la prueba de permiso de lectura: se ejecuta como root)')
  else
  begin
    Unread := Dir + '/no_legible.so';
    Assign(F, Unread); Rewrite(F); Close(F);
    fpChmod(PAnsiChar(Unread), 0);
    Rc := VPAGraph_LoadPlugin(Unread, P, Detail);
    Check(Rc = VPAGL_ERR_NOT_READABLE, 'sin permiso: ' + VPAGraph_FormatError(Rc, Detail, vglSpanish));
    fpChmod(PAnsiChar(Unread), &644);
    Erase(F);
  end;

  { Fichero regular que no es una biblioteca: dlopen tiene que fallar, y el
    cargador tiene que decirlo con VPAGL_ERR_LOAD_FAILED, no caer. }
  Rc := VPAGraph_LoadPlugin(Dir + '/no_es_un_so.txt', P, Detail);
  Check(Rc = VPAGL_ERR_LOAD_FAILED, 'no es ELF: ' + VPAGraph_FormatError(Rc, Detail, vglSpanish));

  WriteLn('[6] ruta relativa (T3.2)');
  Rc := VPAGraph_LoadPlugin('stub_backend.so', P, Detail);
  Check(Rc = VPAGL_ERR_NOT_FOUND, 'relativa: ' + VPAGraph_FormatError(Rc, Detail, vglSpanish));
  Check(Pos('absolute', Detail) > 0, 'el motivo es la ruta relativa, no el disco');
end;

{ ---------------------------------------------------------------------------
  7: LoadBackend con candidatos y motivos acumulados
  --------------------------------------------------------------------------- }
procedure TestBackend;
var
  P      : TVPAGraphPlugin;
  C      : TVPAGraphCandidates;
  Detail : AnsiString;
  Rc     : longint;
  I      : Integer;
begin
  WriteLn('[7] resolucion de candidatos (T3.2, T3.7)');
  FillChar(P, SizeOf(P), 0);

  Check(VPAGraph_PluginFileName('x11') = 'libvpagraph-x11.so', 'nombre de fichero');
  Check(VPAGraph_ExeDir <> '', 'directorio del ejecutable: ' + VPAGraph_ExeDir);
  Check((VPAGraph_ExeDir <> '') and (VPAGraph_ExeDir[1] = '/'), 'es absoluto');

  { Sin variable: dos candidatos, junto al ejecutable y el de instalacion }
  unsetenv(VPAGL_ENV_PLUGIN_DIR);
  VPAGraph_ResolvePluginPath('x11', C);
  Check(C.Count = 2, 'sin VPA_GRAPH_PLUGIN_DIR: 2 candidatos');
  Check(C.Path[0] = VPAGraph_ExeDir + '/plugins/libvpagraph-x11.so', 'candidato 1: ' + C.Path[0]);
  Check(C.Path[1] = VPAGRAPH_INSTALL_DIR + '/libvpagraph-x11.so', 'candidato 2: ' + C.Path[1]);

  { Con variable relativa: se ignora, y queda dicho }
  setenv(VPAGL_ENV_PLUGIN_DIR, 'relativa/plugins', 1);
  VPAGraph_ResolvePluginPath('x11', C);
  Check(C.Count = 2, 'variable relativa: sigue habiendo 2 candidatos');
  Check(C.Ignored <> '', 'variable relativa: motivo registrado: ' + C.Ignored);

  { Con variable absoluta: va primero }
  setenv(VPAGL_ENV_PLUGIN_DIR, PAnsiChar(Dir), 1);
  VPAGraph_ResolvePluginPath('x11', C);
  Check(C.Count = 3, 'variable absoluta: 3 candidatos');
  Check(C.Path[0] = Dir + '/libvpagraph-x11.so', 'candidato 1 es el de la variable');

  { LoadBackend de un backend que no existe en ningun sitio: tres motivos }
  Rc := VPAGraph_LoadBackend('inexistente', P, Detail);
  Check(Rc = VPAGL_ERR_NOT_FOUND, 'backend inexistente: VPAGL_ERR_NOT_FOUND');
  I := CountLines(Detail);
  Check(I = 3, 'tres motivos acumulados, uno por candidato:');
  WriteLn('        ', StringReplace(Detail, LineEnding, LineEnding + '        ', [rfReplaceAll]));

  { LoadBackend de un backend que si existe en el directorio de la variable:
    el stub renombrado como libvpagraph-stub.so }
  Rc := VPAGraph_LoadBackend('stub', P, Detail);
  Check(Rc = VPAGL_OK, 'backend stub por VPA_GRAPH_PLUGIN_DIR: ' +
    VPAGraph_FormatError(Rc, Detail, vglSpanish));
  Check(P.Path = Dir + '/libvpagraph-stub.so', 'ruta cargada: ' + P.Path);
  VPAGraph_UnloadPlugin(P);
  unsetenv(VPAGL_ENV_PLUGIN_DIR);
end;

begin
  if ParamCount < 1 then
  begin
    WriteLn('uso: loader_test <directorio con los .so de TESTS/abi>');
    Halt(2);
  end;
  Dir := ParamStr(1);
  if (Dir = '') or (Dir[1] <> '/') then
  begin
    WriteLn('el directorio tiene que ser una ruta absoluta');
    Halt(2);
  end;
  while (Length(Dir) > 1) and (Dir[Length(Dir)] = '/') do
    SetLength(Dir, Length(Dir) - 1);

  TestStub;
  TestCycles;
  TestBad;
  TestFiles;
  TestBackend;

  WriteLn;
  WriteLn(Passed, ' comprobaciones correctas, ', Failed, ' fallidas');
  if Failed > 0 then Halt(1);
end.
