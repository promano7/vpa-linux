{ ===========================================================================
  vpagraph_errors.pas - Traduccion de codigos de error a texto, en espanol
  y en ingles, y recogida del mensaje del plugin. Fase 3 de WAYLAND.md
  (T3.8).

  Hay tres familias de codigos y las tres se traducen aqui:

    - los de la ABI (VPAG_ERR_*, de -1 a -100), que devuelven las funciones
      del plugin y el punto de entrada;
    - los del cargador (VPAGL_ERR_*, de -1001 en adelante), que produce
      vpagraph_loader.pas antes de que exista ningun plugin;
    - los de la seleccion (VPAGD_ERR_*, de -1101 en adelante), que produce
      vpagraph_detect.pas al decidir que backend intentar (Fase 4).

  El texto de esta unidad es la parte GENERICA del mensaje ("no se pudo
  cargar el plugin"). La parte concreta (que ruta, que funcion falta) viene
  en el Detail del cargador o en el GetLastError del plugin, y el nucleo
  junta las dos. Asi el usuario ve "no se pudo cargar el plugin:
  /usr/lib/vpa-linux/libvpagraph-wayland.so: no existe" y no una de las dos
  mitades sola.

  El mensaje del plugin se recoge con un buffer DEL LLAMANTE (regla 8 de la
  ABI): ninguna cadena del RTL del .so cruza la frontera.

  Modo objfpc de forma local, como vpagraph_loader.pas.
  =========================================================================== }
unit vpagraph_errors;

{$MODE OBJFPC}{$H+}

interface

uses
  vpagraph_loader, vpagraph_detect;

{$I vpagraph_abi.inc}

type
  TVPAGraphLang = (vglSpanish, vglEnglish);

{ Texto generico de un codigo de error, de la ABI o del cargador. Para un
  codigo desconocido devuelve 'error N' en el idioma pedido, nunca una
  cadena vacia: un mensaje vacio en pantalla es peor que un numero. }
function VPAGraph_ErrorText(Code: longint; Lang: TVPAGraphLang): AnsiString;

{ Recoge el mensaje de GetLastError del plugin en una cadena del EJECUTABLE.
  Devuelve '' si el plugin no implementa GetLastError (es opcional) o si no
  tiene nada que decir. Nunca lanza excepciones: si el plugin miente sobre
  la longitud, el buffer local esta terminado en cero igualmente. }
function VPAGraph_PluginMessage(const Plugin: TVPAGraphPlugin): AnsiString;

{ Mensaje completo para el usuario: texto generico del codigo mas el detalle
  concreto, si lo hay, separados por ': '. Detail suele ser el del cargador
  (VPAGraph_LoadPlugin) o el de VPAGraph_PluginMessage. }
function VPAGraph_FormatError(Code: longint; const Detail: AnsiString;
  Lang: TVPAGraphLang): AnsiString;

implementation

function IntToStr(V: int64): AnsiString;
var
  S: string[24];
begin
  Str(V, S);
  Result := S;
end;

function VPAGraph_ErrorText(Code: longint; Lang: TVPAGraphLang): AnsiString;
begin
  if Lang = vglSpanish then
    case Code of
      VPAG_OK                : Result := 'correcto';
      VPAG_ERR_INVALID_PARAM : Result := 'parametro invalido';
      VPAG_ERR_ABI_MISMATCH  : Result := 'version de ABI incompatible';
      VPAG_ERR_STRUCT_SIZE   : Result := 'tamano de estructura invalido';
      VPAG_ERR_INIT          : Result := 'error al inicializar el backend grafico';
      VPAG_ERR_VIDEO         : Result := 'error de video';
      VPAG_ERR_MEMORY        : Result := 'sin memoria';
      VPAG_ERR_UNSUPPORTED   : Result := 'funcion no soportada por este backend';
      VPAG_ERR_INTERNAL      : Result := 'error interno del plugin';
      VPAGL_ERR_NOT_FOUND    : Result := 'plugin no encontrado';
      VPAGL_ERR_NOT_REGULAR  : Result := 'el plugin no es un fichero regular';
      VPAGL_ERR_NOT_READABLE : Result := 'el plugin no se puede leer';
      VPAGL_ERR_LOAD_FAILED  : Result := 'no se pudo cargar el plugin';
      VPAGL_ERR_NO_SYMBOL    : Result := 'el fichero no es un plugin de VPAGraph';
      VPAGL_ERR_ENTRY_FAILED : Result := 'el plugin rechazo la negociacion';
      VPAGL_ERR_STRUCT_SIZE  : Result := 'el plugin devolvio una tabla de tamano incoherente';
      VPAGL_ERR_ABI_MISMATCH : Result := 'el plugin habla otra version de la ABI';
      VPAGL_ERR_NO_NAME      : Result := 'el plugin no se identifica';
      VPAGL_ERR_NULL_PROC    : Result := 'el plugin esta incompleto';
      VPAGL_ERR_ALREADY      : Result := 'ya hay un plugin cargado';
      VPAGD_ERR_BAD_REQUEST  : Result := 'valor de VPA_GRAPH_BACKEND desconocido';
      VPAGD_ERR_NO_SESSION   : Result := 'no se ha detectado ninguna sesion grafica';
      VPAGD_ERR_ALL_FAILED   : Result := 'no se pudo cargar ningun backend grafico';
    else
      Result := 'error ' + IntToStr(Code);
    end
  else
    case Code of
      VPAG_OK                : Result := 'ok';
      VPAG_ERR_INVALID_PARAM : Result := 'invalid parameter';
      VPAG_ERR_ABI_MISMATCH  : Result := 'incompatible ABI version';
      VPAG_ERR_STRUCT_SIZE   : Result := 'invalid structure size';
      VPAG_ERR_INIT          : Result := 'graphics backend initialization failed';
      VPAG_ERR_VIDEO         : Result := 'video error';
      VPAG_ERR_MEMORY        : Result := 'out of memory';
      VPAG_ERR_UNSUPPORTED   : Result := 'function not supported by this backend';
      VPAG_ERR_INTERNAL      : Result := 'internal plugin error';
      VPAGL_ERR_NOT_FOUND    : Result := 'plugin not found';
      VPAGL_ERR_NOT_REGULAR  : Result := 'plugin is not a regular file';
      VPAGL_ERR_NOT_READABLE : Result := 'plugin is not readable';
      VPAGL_ERR_LOAD_FAILED  : Result := 'could not load plugin';
      VPAGL_ERR_NO_SYMBOL    : Result := 'file is not a VPAGraph plugin';
      VPAGL_ERR_ENTRY_FAILED : Result := 'plugin refused negotiation';
      VPAGL_ERR_STRUCT_SIZE  : Result := 'plugin returned a table of inconsistent size';
      VPAGL_ERR_ABI_MISMATCH : Result := 'plugin speaks a different ABI version';
      VPAGL_ERR_NO_NAME      : Result := 'plugin does not identify itself';
      VPAGL_ERR_NULL_PROC    : Result := 'plugin is incomplete';
      VPAGL_ERR_ALREADY      : Result := 'a plugin is already loaded';
      VPAGD_ERR_BAD_REQUEST  : Result := 'unknown VPA_GRAPH_BACKEND value';
      VPAGD_ERR_NO_SESSION   : Result := 'no graphical session detected';
      VPAGD_ERR_ALL_FAILED   : Result := 'no graphics backend could be loaded';
    else
      Result := 'error ' + IntToStr(Code);
    end;
end;

function VPAGraph_PluginMessage(const Plugin: TVPAGraphPlugin): AnsiString;
var
  Buf : array[0..VPAG_ERROR_BUFFER_SIZE - 1] of AnsiChar;
  N   : TVPAGraphInt32;
begin
  Result := '';
  if not Plugin.Loaded then Exit;
  if Plugin.Iface.GetLastError = nil then Exit;   { opcional }
  FillChar(Buf, SizeOf(Buf), 0);
  N := Plugin.Iface.GetLastError(@Buf[0], SizeOf(Buf) - 1);
  { Terminador garantizado por nosotros, no por el plugin: SizeOf(Buf)-1 le
    deja el ultimo byte fuera del alcance y ese byte ya esta a cero. }
  Buf[High(Buf)] := #0;
  if N <= 0 then Exit;
  Result := AnsiString(PAnsiChar(@Buf[0]));
end;

function VPAGraph_FormatError(Code: longint; const Detail: AnsiString;
  Lang: TVPAGraphLang): AnsiString;
begin
  Result := VPAGraph_ErrorText(Code, Lang);
  if Detail <> '' then
    Result := Result + ': ' + Detail;
end;

end.
