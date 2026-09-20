{ Plugin defectuoso 2 de 4 (T2.16): exporta el simbolo correcto pero dice
  hablar la ABI 99. El cargador tiene que rechazarlo con
  VPAG_ERR_ABI_MISMATCH ANTES de llamar a ninguna de sus funciones. }
library bad_abiversion;
{$MODE OBJFPC}{$H+}
{$I vpagraph_abi.inc}
const
  BadName: PAnsiChar = 'bad-abiversion';
function VPAGraph_GetInterface(RequestedABIVersion: TVPAGraphUInt32;
  InterfaceSize: TVPAGraphUInt32;
  InterfaceOut: PVPAGraphInterface): TVPAGraphInt32; cdecl;
begin
  if InterfaceOut = nil then
  begin
    VPAGraph_GetInterface := VPAG_ERR_INVALID_PARAM;
    Exit;
  end;
  { A proposito NO comprueba RequestedABIVersion y se anuncia como 99: es el
    caso del plugin viejo (o de otro proyecto) que no negocia bien. }
  FillChar(InterfaceOut^, SizeOf(TVPAGraphInterface), 0);
  InterfaceOut^.StructSize := SizeOf(TVPAGraphInterface);
  InterfaceOut^.ABIVersion := 99;
  InterfaceOut^.BackendName := BadName;
  VPAGraph_GetInterface := VPAG_OK;
end;
exports
  VPAGraph_GetInterface;
begin
end.
