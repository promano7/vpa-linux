{ Plugin defectuoso 4 de 4 (T2.16): la cabecera es correcta -version y
  StructSize buenos- pero deja a nil funciones OBLIGATORIAS. Es el caso mas
  peligroso, porque pasa la negociacion: el cargador tiene que comprobar
  puntero a puntero las funciones que considera obligatorias y rechazar el
  plugin, en vez de descubrirlo con un salto a la direccion cero en mitad de
  una partida. }
library bad_nullprocs;
{$MODE OBJFPC}{$H+}
{$I vpagraph_abi.inc}
const
  BadName: PAnsiChar = 'bad-nullprocs';
function BadInit(Params: PVPAGraphInitParams): TVPAGraphInt32; cdecl;
begin
  BadInit := VPAG_OK;
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
  if RequestedABIVersion <> VPAGRAPH_ABI_VERSION then
  begin
    VPAGraph_GetInterface := VPAG_ERR_ABI_MISMATCH;
    Exit;
  end;
  FillChar(InterfaceOut^, SizeOf(TVPAGraphInterface), 0);
  InterfaceOut^.StructSize := SizeOf(TVPAGraphInterface);
  InterfaceOut^.ABIVersion := VPAGRAPH_ABI_VERSION;
  InterfaceOut^.BackendName := BadName;
  InterfaceOut^.Init := @BadInit;
  { Shutdown, OutTextXY, Line, PutImage... se quedan a nil a proposito }
  VPAGraph_GetInterface := VPAG_OK;
end;
exports
  VPAGraph_GetInterface;
begin
end.
