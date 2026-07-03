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

{ ---------------------------------------------------------------------------
  Port a Linux/FPC: endianness.
  Los ficheros de VGA Planets (.DAT, .RST, .TRN, VPAx.DB...) son little-endian
  (formato x86 de DOS) y VPA los lee/escribe crudos con BlockRead/BlockWrite
  sobre records empaquetados, SIN conversion de bytes. Esto es correcto en todos
  los targets Linux realistas (x86-64, ARM64, ARM32, RISC-V... todos little-endian
  por defecto), asi que en ARM funciona igual que en x86. Pero en un target
  BIG-ENDIAN los enteros multi-byte quedarian invertidos y los datos se
  corromperian en silencio. Como no hay byte-swapping implementado, fallamos aqui
  de forma EXPLICITA en vez de corromper datos: si algun dia se quisiera soportar
  big-endian, habria que intercambiar los bytes de los campos multi-byte de cada
  record al leer/escribir de disco.
  --------------------------------------------------------------------------- }
{$IFDEF FPC}
  {$IFDEF ENDIAN_BIG}
    {$FATAL VPA lee/escribe datos VGA Planets little-endian sin conversion; los targets big-endian necesitan byte-swapping (no implementado). Compila en un target little-endian (x86, ARM y RISC-V lo son por defecto).}
  {$ENDIF}
{$ENDIF}
