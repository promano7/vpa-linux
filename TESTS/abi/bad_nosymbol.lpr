{ Plugin defectuoso 1 de 4 (T2.16): biblioteca valida que NO exporta
  VPAGraph_GetInterface. El cargador tiene que detectarlo al resolver el
  simbolo y rechazarla con un mensaje claro, no caer. }
library bad_nosymbol;
{$MODE OBJFPC}{$H+}
{$I vpagraph_abi.inc}
function OtraCosa: TVPAGraphInt32; cdecl;
begin
  OtraCosa := VPAG_OK;
end;
exports
  OtraCosa;
begin
end.
