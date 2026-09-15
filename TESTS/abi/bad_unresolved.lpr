{ Plugin defectuoso 5 de 5 (anadido en la Fase 3): la cabecera y la tabla
  serian correctas, pero la biblioteca depende de un simbolo que no existe en
  ningun sitio. Es el caso real de un libvpagraph-wayland.so compilado contra
  un SDL3 mas nuevo que el instalado: con RTLD_LAZY cargaria y caeria en
  mitad de la partida al llamar por primera vez a ese simbolo; con RTLD_NOW,
  que es lo que usa el cargador, dlopen falla aqui y lo dice.

  Al enlazar se le pide al enlazador que permita el simbolo sin resolver
  (ld lo admite en bibliotecas compartidas si no se pasa --no-undefined). }
library bad_unresolved;
{$MODE OBJFPC}{$H+}
{$I vpagraph_abi.inc}
const
  BadName    : PAnsiChar = 'bad-unresolved';
  BadVersion : PAnsiChar = '0.0';
function SimboloQueNoExiste: TVPAGraphInt32; cdecl;
  external name 'vpagraph_simbolo_que_no_existe_en_ninguna_biblioteca';
function BadInit(Params: PVPAGraphInitParams): TVPAGraphInt32; cdecl;
begin
  BadInit := SimboloQueNoExiste;
end;
function VPAGraph_GetInterface(RequestedABIVersion: TVPAGraphUInt32;
  InterfaceSize: TVPAGraphUInt32;
  InterfaceOut: PVPAGraphInterface): TVPAGraphInt32; cdecl;
begin
  if InterfaceOut = nil then
  begin
    VPAGraph_GetInterface := VPAG_ERR_INVALID_PARAM;
    Exit;
  end;
  FillChar(InterfaceOut^, SizeOf(TVPAGraphInterface), 0);
  InterfaceOut^.StructSize := SizeOf(TVPAGraphInterface);
  InterfaceOut^.ABIVersion := VPAGRAPH_ABI_VERSION;
  InterfaceOut^.BackendName := BadName;
  InterfaceOut^.BackendVersion := BadVersion;
  InterfaceOut^.Init := @BadInit;
  VPAGraph_GetInterface := VPAG_OK;
end;
exports
  VPAGraph_GetInterface;
begin
end.
