{ Plugin defectuoso 3 de 4 (T2.16): anuncia un StructSize incoherente (la
  mitad del real). El cargador tiene que rechazarlo con VPAG_ERR_STRUCT_SIZE
  en vez de fiarse y leer punteros a medio escribir. }
library bad_structsize;
{$MODE OBJFPC}{$H+}
{$I vpagraph_abi.inc}
const
  BadName: PAnsiChar = 'bad-structsize';
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
  InterfaceOut^.StructSize := SizeOf(TVPAGraphInterface) div 2;   { mentira }
  InterfaceOut^.ABIVersion := VPAGRAPH_ABI_VERSION;
  InterfaceOut^.BackendName := BadName;
  VPAGraph_GetInterface := VPAG_OK;
end;
exports
  VPAGraph_GetInterface;
begin
end.
