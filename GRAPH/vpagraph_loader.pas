{ ===========================================================================
  vpagraph_loader.pas - Cargador dinamico de plugins de backend grafico.
  Fase 3 de WAYLAND.md (T3.1 a T3.7).

  UNICA UNIDAD DE TODO EL PROYECTO QUE PUEDE CARGAR BIBLIOTECAS (T3.1).
  Cualquier otra unidad que necesite un simbolo de un .so pasa por aqui. El
  motivo es el mismo que el de la regla 9 de la ABI: un dlopen suelto en
  otra unidad es un segundo camino de carga que nadie valida ni descarga en
  orden.

  La hoja de ruta decia Dynlibs; se usa la unidad dl, que es lo que Dynlibs
  envuelve en Unix, y por un motivo concreto: Dynlibs.LoadLibrary abre con
  RTLD_LAZY, y con enlace perezoso un plugin al que le falte UN simbolo de
  su biblioteca grafica (un libSDL3 mas viejo que el que se uso al compilar,
  el caso de Astra o de un Kubuntu LTS) cargaria bien y caeria en mitad de
  una partida al llamar por primera vez a ese simbolo. Con RTLD_NOW el
  enlazador resuelve TODO al cargar y el fallo se ve aqui, con su mensaje,
  y el modo auto cae a X11 como debe (seccion 3.2 de WAYLAND.md).

  Lo que hace, y en que orden:

    1. Resuelve la ruta del plugin (T3.2): $VPA_GRAPH_PLUGIN_DIR, luego
       <directorio del ejecutable>/plugins/, luego el directorio de
       instalacion. Siempre rutas absolutas; NUNCA el directorio de trabajo.
    2. Comprueba el fichero antes de tocarlo (T3.3): existe, es un fichero
       regular y es legible.
    3. Lo carga, resuelve VPAGraph_GetInterface y negocia (T3.4).
    4. Valida la tabla devuelta campo a campo (T3.5): StructSize, ABIVersion,
       nombres y TODOS los punteros obligatorios. Un plugin a medio rellenar
       se rechaza entero.
    5. Al descargar, anula la tabla ANTES de dlclose (T3.6): un uso
       posterior da un puntero nulo detectable, no un salto a memoria
       liberada.
    6. Deja rastro de todo lo que intenta (T3.7): silencioso por defecto,
       detallado en stderr con VPA_GRAPH_DEBUG=1.

  Esta unidad NO llama a ninguna funcion del plugin salvo al punto de
  entrada. Ni Init ni Shutdown: eso es del nucleo (GRAPH/vpagraph.pas), que
  sabe cuando abrir la ventana. Aqui solo se carga, se valida y se descarga.

  Al descargar se usa dlclose sin mas: el .so de un plugin de Free Pascal
  ejecuta su finalizacion en el destructor ELF, y el arnes de la Fase 3
  comprueba con heaptrc que cien ciclos no dejan nada detras.

  Los codigos de error propios del cargador (fichero ausente, simbolo
  ausente...) son distintos de los de la ABI y viven aqui, no en
  vpagraph_abi.inc: no cruzan la frontera, son del ejecutable. La traduccion
  a texto esta en vpagraph_errors.pas.

  Modo objfpc de forma local, como VENDOR/ptcgraph.pp: el resto de VPA se
  compila en -Mtp y consume esta unidad sin problema (restriccion 2.3.1).
  =========================================================================== }
unit vpagraph_loader;

{$MODE OBJFPC}{$H+}

interface

{$I vpagraph_abi.inc}

const
  { --- Codigos de error del cargador ---
    Negativos y fuera del rango de la ABI (-1..-100) para que nunca se
    confundan con lo que devuelve un plugin. }
  VPAGL_OK               =     0;
  VPAGL_ERR_NOT_FOUND    = -1001;  { ningun candidato existe }
  VPAGL_ERR_NOT_REGULAR  = -1002;  { existe pero no es un fichero regular }
  VPAGL_ERR_NOT_READABLE = -1003;  { existe pero no se puede leer }
  VPAGL_ERR_LOAD_FAILED  = -1004;  { dlopen fallo (dependencias, formato...) }
  VPAGL_ERR_NO_SYMBOL    = -1005;  { no exporta VPAGraph_GetInterface }
  VPAGL_ERR_ENTRY_FAILED = -1006;  { el punto de entrada devolvio error }
  VPAGL_ERR_STRUCT_SIZE  = -1007;  { StructSize incoherente en la tabla }
  VPAGL_ERR_ABI_MISMATCH = -1008;  { ABIVersion distinta de la esperada }
  VPAGL_ERR_NO_NAME      = -1009;  { BackendName o BackendVersion nulos o vacios }
  VPAGL_ERR_NULL_PROC    = -1010;  { alguna funcion obligatoria a nil }
  VPAGL_ERR_ALREADY      = -1011;  { ya hay un plugin cargado en ese registro }

  { Variables de entorno que entiende esta unidad. }
  VPAGL_ENV_PLUGIN_DIR = 'VPA_GRAPH_PLUGIN_DIR';
  VPAGL_ENV_DEBUG      = 'VPA_GRAPH_DEBUG';

  { Subdirectorio junto al ejecutable donde se buscan los plugins sin
    instalar (candidato 2 de T3.2). }
  VPAGL_EXE_SUBDIR = 'plugins';

  { Numero maximo de rutas candidatas que devuelve ResolvePluginPath. }
  VPAGL_MAX_CANDIDATES = 3;

{ Directorio de instalacion (candidato 3 de T3.2). Es una constante en un
  include aparte para que el empaquetador o el Makefile la ajusten sin tocar
  esta unidad. }
{$I vpagraph_installdir.inc}

type
  { Un plugin cargado. La tabla de funciones es la de la ABI; Handle es el
    del sistema, guardado como entero para que ningun tipo de dl salga
    de esta unidad. Loaded = False significa que Iface esta a cero y no se
    puede llamar a nada de ella. }
  TVPAGraphPlugin = record
    Loaded : Boolean;
    Handle : PtrUInt;
    Path   : AnsiString;               { ruta absoluta del .so cargado }
    Iface  : TVPAGraphInterface;
  end;

  { Lista de rutas que ResolvePluginPath propone, en orden de prioridad. }
  TVPAGraphCandidates = record
    Count   : Integer;
    Path    : array[0..VPAGL_MAX_CANDIDATES - 1] of AnsiString;
    Ignored : AnsiString;   { por que se descarto $VPA_GRAPH_PLUGIN_DIR, o '' }
  end;

{ --- T3.2: resolucion de la ruta ---

  Nombre de fichero de un backend: 'x11' -> 'libvpagraph-x11.so'. }
function VPAGraph_PluginFileName(const Backend: AnsiString): AnsiString;

{ Rellena Candidates con las rutas absolutas donde buscar el plugin de
  Backend, en orden: $VPA_GRAPH_PLUGIN_DIR (si esta definida y es absoluta),
  <dir del ejecutable>/plugins/, directorio de instalacion. No comprueba que
  existan: eso lo hace LoadPlugin, que ademas explica por que no valen. }
procedure VPAGraph_ResolvePluginPath(const Backend: AnsiString;
  var Candidates: TVPAGraphCandidates);

{ Directorio absoluto del ejecutable, sin barra final, leido de
  /proc/self/exe. Cadena vacia si no se puede saber. }
function VPAGraph_ExeDir: AnsiString;

{ --- T3.3 a T3.5: carga ---

  Carga y valida el plugin de la ruta Path (absoluta). Devuelve VPAGL_OK y
  deja Plugin.Loaded = True, o un codigo VPAGL_ERR_* con Plugin a cero.
  Detail recibe la explicacion concreta (ruta, nombre de la funcion que
  falta, texto de dlopen...) para que el mensaje al usuario sea util y no
  un generico. Nunca lanza excepciones. }
function VPAGraph_LoadPlugin(const Path: AnsiString;
  var Plugin: TVPAGraphPlugin; var Detail: AnsiString): longint;

{ Prueba los candidatos de Backend en orden y se queda con el primero que
  carga y valida. Si ninguno vale, Detail acumula un motivo POR CANDIDATO,
  uno por linea: la regla de T4.2 (lista acumulada de motivos, nunca un
  generico) empieza aqui. Devuelve el codigo del ultimo fallo. }
function VPAGraph_LoadBackend(const Backend: AnsiString;
  var Plugin: TVPAGraphPlugin; var Detail: AnsiString): longint;

{ --- T3.6: descarga ---

  Anula la tabla de funciones, luego descarga la biblioteca. Idempotente:
  con Plugin.Loaded = False no hace nada. NO llama a Shutdown: eso es del
  nucleo, y tiene que haber ocurrido antes. }
procedure VPAGraph_UnloadPlugin(var Plugin: TVPAGraphPlugin);

{ --- T3.7: diagnostico ---

  True si VPA_GRAPH_DEBUG=1 estaba en el entorno al arrancar. Se puede
  cambiar en ejecucion (por ejemplo desde --graph-info en la Fase 4). }
var
  VPAGraph_LoaderDebug: Boolean = False;

{ Escribe una linea en stderr con el prefijo '[vpagraph] ' si el modo de
  depuracion esta activo. La usa tambien vpagraph_detect (Fase 4). }
procedure VPAGraph_Log(const S: AnsiString);

implementation

uses
  BaseUnix, dl;

{ getenv de libc, no Dos.GetEnv ni BaseUnix.fpGetEnv: los dos leen la copia
  del entorno que el RTL tomo al arrancar, y un setenv posterior (el arnes
  de pruebas lo hace; --graph-info de la Fase 4 podria hacerlo) no se ve.
  libc ya esta enlazada: dl la necesita. }
function c_getenv(Name: PAnsiChar): PAnsiChar; cdecl; external 'c' name 'getenv';

function GetEnv(const Name: AnsiString): AnsiString;
var
  P: PAnsiChar;
begin
  P := c_getenv(PAnsiChar(Name));
  if P = nil then Result := '' else Result := AnsiString(P);
end;

{ ---------------------------------------------------------------------------
  Diagnostico (T3.7)
  --------------------------------------------------------------------------- }

procedure VPAGraph_Log(const S: AnsiString);
begin
  if not VPAGraph_LoaderDebug then Exit;
  { Sin excepciones y sin fiarse del estado de E/S del programa: si stderr
    esta cerrado, mejor perder el mensaje que morir por escribirlo. }
  {$I-}
  WriteLn(StdErr, '[vpagraph] ', S);
  {$I+}
  if IOResult <> 0 then ;
end;

{ Str() en vez de SysUtils.IntToStr: esta unidad no necesita SysUtils y no
  hay motivo para arrastrarlo (con su gestor de excepciones) al ejecutable. }
function IntToStr(V: int64): AnsiString;
var
  S: string[24];
begin
  Str(V, S);
  Result := S;
end;

procedure AppendLine(var Detail: AnsiString; const S: AnsiString);
begin
  if Detail <> '' then Detail := Detail + LineEnding;
  Detail := Detail + S;
end;

{ ---------------------------------------------------------------------------
  Resolucion de la ruta (T3.2)
  --------------------------------------------------------------------------- }

function VPAGraph_PluginFileName(const Backend: AnsiString): AnsiString;
begin
  Result := 'libvpagraph-' + Backend + '.so';
end;

function VPAGraph_ExeDir: AnsiString;
var
  Buf  : array[0..4095] of AnsiChar;
  N, I : longint;
begin
  Result := '';
  { /proc/self/exe es la unica fuente fiable: ParamStr(0) puede ser un
    nombre relativo o lo que el shell quiso poner ahi. }
  N := fpReadLink('/proc/self/exe', @Buf[0], SizeOf(Buf) - 1);
  if N <= 0 then Exit;
  Buf[N] := #0;
  SetString(Result, PAnsiChar(@Buf[0]), N);
  { Quitar el nombre del fichero: hasta la ultima barra, sin incluirla. }
  I := Length(Result);
  while (I > 1) and (Result[I] <> '/') do Dec(I);
  if I <= 1 then
    Result := ''
  else
    SetLength(Result, I - 1);
end;

function IsAbsolute(const P: AnsiString): Boolean;
begin
  Result := (Length(P) > 0) and (P[1] = '/');
end;

function JoinPath(const Dir, Name: AnsiString): AnsiString;
begin
  if (Dir <> '') and (Dir[Length(Dir)] = '/') then
    Result := Dir + Name
  else
    Result := Dir + '/' + Name;
end;

procedure VPAGraph_ResolvePluginPath(const Backend: AnsiString;
  var Candidates: TVPAGraphCandidates);
var
  FileName, EnvDir, ExeDir: AnsiString;

  procedure Add(const Dir: AnsiString);
  begin
    if Candidates.Count >= VPAGL_MAX_CANDIDATES then Exit;
    Candidates.Path[Candidates.Count] := JoinPath(Dir, FileName);
    Inc(Candidates.Count);
  end;

begin
  Candidates.Count   := 0;
  Candidates.Ignored := '';
  FileName := VPAGraph_PluginFileName(Backend);

  { 1. $VPA_GRAPH_PLUGIN_DIR, solo si es absoluta. Una relativa se
       resolveria contra el directorio de trabajo, que es justo lo que la
       regla prohibe: se descarta y se deja constancia. }
  EnvDir := GetEnv(VPAGL_ENV_PLUGIN_DIR);
  if EnvDir <> '' then
  begin
    if IsAbsolute(EnvDir) then
      Add(EnvDir)
    else
    begin
      Candidates.Ignored := VPAGL_ENV_PLUGIN_DIR + '=' + EnvDir +
        ' no es una ruta absoluta: se ignora';
      VPAGraph_Log(Candidates.Ignored);
    end;
  end;

  { 2. <directorio del ejecutable>/plugins/ }
  ExeDir := VPAGraph_ExeDir;
  if ExeDir <> '' then
    Add(JoinPath(ExeDir, VPAGL_EXE_SUBDIR))
  else
    VPAGraph_Log('no se pudo leer /proc/self/exe: se omite el candidato junto al ejecutable');

  { 3. Directorio de instalacion }
  Add(VPAGRAPH_INSTALL_DIR);
end;

{ ---------------------------------------------------------------------------
  Validaciones previas (T3.3)
  --------------------------------------------------------------------------- }

function CheckFile(const Path: AnsiString; var Detail: AnsiString): longint;
var
  St: Stat;
begin
  { fpStat sigue los enlaces simbolicos: un enlace a un dispositivo o a un
    directorio se ve como lo que apunta, que es lo que hay que rechazar. }
  if fpStat(PAnsiChar(Path), St) <> 0 then
  begin
    Detail := Path + ': no existe';
    Exit(VPAGL_ERR_NOT_FOUND);
  end;
  if not fpS_ISREG(St.st_mode) then
  begin
    Detail := Path + ': no es un fichero regular';
    Exit(VPAGL_ERR_NOT_REGULAR);
  end;
  if fpAccess(PAnsiChar(Path), R_OK) <> 0 then
  begin
    Detail := Path + ': sin permiso de lectura';
    Exit(VPAGL_ERR_NOT_READABLE);
  end;
  Result := VPAGL_OK;
end;

{ ---------------------------------------------------------------------------
  Validacion de la tabla (T3.5)
  --------------------------------------------------------------------------- }

function PCharToStr(P: PAnsiChar): AnsiString;
begin
  if P = nil then Result := '' else Result := AnsiString(P);
end;

{ Comprueba que no falte ninguna funcion obligatoria (lista de la seccion 5
  de docs/abi-compatibility.md). Devuelve cuantas faltan y deja sus nombres
  en Missing, separados por comas: el mensaje tiene que decir CUALES, no
  solo que falta alguna. }
function CountMissingProcs(const I: TVPAGraphInterface;
  var Missing: AnsiString): Integer;
var
  N: Integer;

  procedure Need(P: Pointer; const Name: AnsiString);
  begin
    if P <> nil then Exit;
    Inc(N);
    if Missing <> '' then Missing := Missing + ', ';
    Missing := Missing + Name;
  end;

begin
  N := 0;
  Missing := '';
  { ciclo de vida }
  Need(Pointer(I.Init),            'Init');
  Need(Pointer(I.Shutdown),        'Shutdown');
  Need(Pointer(I.Present),         'Present');
  { dibujo }
  Need(Pointer(I.ClearDevice),     'ClearDevice');
  Need(Pointer(I.SetViewPort),     'SetViewPort');
  Need(Pointer(I.GetViewSettings), 'GetViewSettings');
  Need(Pointer(I.SetColor),        'SetColor');
  Need(Pointer(I.GetColor),        'GetColor');
  Need(Pointer(I.SetLineStyle),    'SetLineStyle');
  Need(Pointer(I.SetFillStyle),    'SetFillStyle');
  Need(Pointer(I.SetWriteMode),    'SetWriteMode');
  Need(Pointer(I.PutPixel),        'PutPixel');
  Need(Pointer(I.GetPixel),        'GetPixel');
  Need(Pointer(I.Line),            'Line');
  Need(Pointer(I.LineTo),          'LineTo');
  Need(Pointer(I.LineRel),         'LineRel');
  Need(Pointer(I.MoveTo),          'MoveTo');
  Need(Pointer(I.Rectangle),       'Rectangle');
  Need(Pointer(I.Bar),             'Bar');
  Need(Pointer(I.Circle),          'Circle');
  Need(Pointer(I.Ellipse),         'Ellipse');
  { imagenes }
  Need(Pointer(I.ImageSize),       'ImageSize');
  Need(Pointer(I.GetImage),        'GetImage');
  Need(Pointer(I.PutImage),        'PutImage');
  { paleta }
  Need(Pointer(I.SetRGBPalette),   'SetRGBPalette');
  Need(Pointer(I.GetRGBPalette),   'GetRGBPalette');
  { texto }
  Need(Pointer(I.OutTextXY),       'OutTextXY');
  Need(Pointer(I.SetTextStyle),    'SetTextStyle');
  Need(Pointer(I.SetTextJustify),  'SetTextJustify');
  Need(Pointer(I.InstallUserFont), 'InstallUserFont');
  { entrada }
  Need(Pointer(I.PollEvent),       'PollEvent');
  Need(Pointer(I.GetModifiers),    'GetModifiers');
  Need(Pointer(I.GetMouseState),   'GetMouseState');
  Need(Pointer(I.SetMousePos),     'SetMousePos');
  Need(Pointer(I.ShowMouse),       'ShowMouse');
  Result := N;
end;

function ValidateInterface(const I: TVPAGraphInterface;
  var Detail: AnsiString): longint;
var
  Missing: AnsiString;
  N: Integer;
begin
  { El orden importa: no se lee nada de la tabla hasta saber que la tabla
    tiene el tamano y la version que creemos. }
  if I.StructSize <> SizeOf(TVPAGraphInterface) then
  begin
    Detail := 'StructSize incoherente: el plugin anuncia ' +
      IntToStr(I.StructSize) + ' bytes y el ejecutable espera ' +
      IntToStr(SizeOf(TVPAGraphInterface));
    Exit(VPAGL_ERR_STRUCT_SIZE);
  end;
  if I.ABIVersion <> VPAGRAPH_ABI_VERSION then
  begin
    Detail := 'version de ABI incompatible: el plugin habla la ' +
      IntToStr(I.ABIVersion) + ' y el ejecutable la ' +
      IntToStr(VPAGRAPH_ABI_VERSION);
    Exit(VPAGL_ERR_ABI_MISMATCH);
  end;
  if (I.BackendName = nil) or (I.BackendName^ = #0) then
  begin
    Detail := 'BackendName nulo o vacio';
    Exit(VPAGL_ERR_NO_NAME);
  end;
  if (I.BackendVersion = nil) or (I.BackendVersion^ = #0) then
  begin
    Detail := 'BackendVersion nulo o vacio (backend ' +
      PCharToStr(I.BackendName) + ')';
    Exit(VPAGL_ERR_NO_NAME);
  end;
  N := CountMissingProcs(I, Missing);
  if N > 0 then
  begin
    Detail := 'backend ' + PCharToStr(I.BackendName) + ': ' + IntToStr(N) +
      ' funcion(es) obligatoria(s) sin implementar: ' + Missing;
    Exit(VPAGL_ERR_NULL_PROC);
  end;
  Result := VPAGL_OK;
end;

{ ---------------------------------------------------------------------------
  Carga (T3.4) y descarga (T3.6)
  --------------------------------------------------------------------------- }

function VPAGraph_LoadPlugin(const Path: AnsiString;
  var Plugin: TVPAGraphPlugin; var Detail: AnsiString): longint;
var
  H     : Pointer;
  Entry : TVPAGraphGetInterfaceProc;
  Rc    : TVPAGraphInt32;
  Msg   : PAnsiChar;
begin
  Detail := '';
  if Plugin.Loaded then
  begin
    Detail := 'ya hay un plugin cargado (' + Plugin.Path + ')';
    Exit(VPAGL_ERR_ALREADY);
  end;
  { No se hace FillChar del registro entero: Path es un AnsiString y
    machacarlo a cero sin liberarlo seria una fuga. }
  Plugin.Handle := 0;
  Plugin.Path   := '';
  FillChar(Plugin.Iface, SizeOf(Plugin.Iface), 0);

  if not IsAbsolute(Path) then
  begin
    { Nunca el directorio de trabajo actual. }
    Detail := Path + ': el cargador solo acepta rutas absolutas';
    Exit(VPAGL_ERR_NOT_FOUND);
  end;

  VPAGraph_Log('probando ' + Path);

  Result := CheckFile(Path, Detail);
  if Result <> VPAGL_OK then
  begin
    VPAGraph_Log('  rechazado: ' + Detail);
    Exit;
  end;

  { RTLD_NOW: todos los simbolos resueltos ahora o ninguno (ver cabecera).
    RTLD_LOCAL (el valor por defecto, no se pide): los simbolos del plugin
    no se mezclan con los del ejecutable ni con los de otro plugin. }
  dlerror;   { limpia el ultimo error, dlerror es de un solo uso }
  H := dlopen(PAnsiChar(Path), RTLD_NOW);
  if H = nil then
  begin
    Msg := dlerror;
    Detail := Path + ': no se pudo cargar';
    if Msg <> nil then Detail := Detail + ' (' + AnsiString(Msg) + ')';
    VPAGraph_Log('  rechazado: ' + Detail);
    Exit(VPAGL_ERR_LOAD_FAILED);
  end;

  Entry := TVPAGraphGetInterfaceProc(dlsym(H, VPAGRAPH_ENTRY_POINT));
  if Entry = nil then
  begin
    Detail := Path + ': no exporta ' + VPAGRAPH_ENTRY_POINT +
      ' (no es un plugin de VPAGraph)';
    dlclose(H);
    VPAGraph_Log('  rechazado: ' + Detail);
    Exit(VPAGL_ERR_NO_SYMBOL);
  end;

  { La tabla la reserva el nucleo (esta a cero dentro de Plugin) y se le
    pasa al plugin con su tamano: no puede escribir mas alla. }
  Rc := Entry(VPAGRAPH_ABI_VERSION, SizeOf(TVPAGraphInterface), @Plugin.Iface);
  if Rc <> VPAG_OK then
  begin
    Detail := Path + ': ' + VPAGRAPH_ENTRY_POINT + ' devolvio ' + IntToStr(Rc);
    case Rc of
      VPAG_ERR_ABI_MISMATCH: Detail := Detail + ' (no habla la ABI ' +
        IntToStr(VPAGRAPH_ABI_VERSION) + ')';
      VPAG_ERR_STRUCT_SIZE:  Detail := Detail + ' (necesita una tabla mayor que ' +
        IntToStr(SizeOf(TVPAGraphInterface)) + ' bytes)';
    end;
    FillChar(Plugin.Iface, SizeOf(Plugin.Iface), 0);
    dlclose(H);
    VPAGraph_Log('  rechazado: ' + Detail);
    Exit(VPAGL_ERR_ENTRY_FAILED);
  end;

  Result := ValidateInterface(Plugin.Iface, Detail);
  if Result <> VPAGL_OK then
  begin
    Detail := Path + ': ' + Detail;
    FillChar(Plugin.Iface, SizeOf(Plugin.Iface), 0);
    dlclose(H);
    VPAGraph_Log('  rechazado: ' + Detail);
    Exit;
  end;

  Plugin.Handle := PtrUInt(H);
  Plugin.Path   := Path;
  Plugin.Loaded := True;
  VPAGraph_Log('  cargado: backend ' + PCharToStr(Plugin.Iface.BackendName) +
    ' ' + PCharToStr(Plugin.Iface.BackendVersion) + ', ABI ' +
    IntToStr(Plugin.Iface.ABIVersion));
  Result := VPAGL_OK;
end;

function VPAGraph_LoadBackend(const Backend: AnsiString;
  var Plugin: TVPAGraphPlugin; var Detail: AnsiString): longint;
var
  C   : TVPAGraphCandidates;
  I   : Integer;
  One : AnsiString;
begin
  Detail := '';
  Result := VPAGL_ERR_NOT_FOUND;
  VPAGraph_ResolvePluginPath(Backend, C);
  if C.Ignored <> '' then AppendLine(Detail, C.Ignored);
  for I := 0 to C.Count - 1 do
  begin
    Result := VPAGraph_LoadPlugin(C.Path[I], Plugin, One);
    if Result = VPAGL_OK then
    begin
      Detail := '';
      Exit;
    end;
    AppendLine(Detail, One);
  end;
  if C.Count = 0 then
    Detail := 'no hay ningun directorio donde buscar ' +
      VPAGraph_PluginFileName(Backend);
end;

procedure VPAGraph_UnloadPlugin(var Plugin: TVPAGraphPlugin);
var
  H: Pointer;
begin
  if not Plugin.Loaded then Exit;
  VPAGraph_Log('descargando ' + Plugin.Path);
  H := Pointer(Plugin.Handle);
  { Primero la tabla, luego la biblioteca (T3.6). Entre las dos lineas no
    hay ninguna llamada que pueda usar la tabla, y despues de la primera
    cualquier uso da nil, que el nucleo comprueba. }
  Plugin.Loaded := False;
  Plugin.Handle := 0;
  FillChar(Plugin.Iface, SizeOf(Plugin.Iface), 0);
  Plugin.Path := '';
  if H <> nil then
    dlclose(H);
end;

{ ---------------------------------------------------------------------------
  Inicializacion
  --------------------------------------------------------------------------- }

initialization
  VPAGraph_LoaderDebug := GetEnv(VPAGL_ENV_DEBUG) = '1';
end.
