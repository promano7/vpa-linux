{
  VPA Compile-time Defines

  When you add a define, you should also add a line to procedure
  Parameters in vpainit.pas.
}
{ This one must always be defined }
{$DEFINE VPA}

{ Define this if you want auto tasks. Note that Alex Ivlev only wrote
  the editor, the back end is still missing as of 07/Aug/2002.  --sr }
{.$DEFINE TASKS}

{ Define this if you want PCC stuff in VPA. This is mainly command
  message processing until now. }
{.$DEFINE VPACC}

{ VPA "Mixed Mode" (real *and* protected mode, i.e. PCC graphics and
  DPMI kernel). }
{.$DEFINE VPAMM}


{ Postprocessing }
{$IFDEF VPAMM}
  {$DEFINE DPMISupport}
{$ENDIF}

{ ---------------------------------------------------------------------------
  Port a Linux/FPC: empaquetado de registros byte a byte.
  Turbo/Borland Pascal SIEMPRE empaqueta los records sin relleno; FPC en
  modo TP alinea a 2 por defecto, lo que insertaria padding tras campos de
  tamano impar (p. ej. fcode de 3 bytes en SRec) y desalinearia los datos
  leidos de los .DAT con BlockRead. PACKRECORDS 1 reproduce el layout DOS.
  Todas las units de VPA incluyen este fichero, asi que aplica globalmente.
  --------------------------------------------------------------------------- }
{$IFDEF FPC}
  {$PACKRECORDS 1}
{$ENDIF}
