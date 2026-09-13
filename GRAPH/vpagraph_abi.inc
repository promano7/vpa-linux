{ ===========================================================================
  vpagraph_abi.inc - Definicion de la ABI v1 entre el ejecutable VPA y los
  plugins de backend grafico (.so). Fase 2 de WAYLAND.md.

  Este fichero es el UNICO contrato entre el ejecutable y los plugins. Lo
  incluyen las dos partes:

    - el nucleo, GRAPH/vpagraph.pas y GRAPH/vpagraph_loader.pas, que se
      compilan con el resto de VPA en modo Turbo Pascal (-Mtp);
    - cada plugin, BACKENDS/<X11|WAYLAND>/*.lpr, que se compila en
      modo objfpc (la directiva $MODE OBJFPC).

  Por eso NO puede usar nada que no exista en los dos modos: ni AnsiString,
  ni arrays dinamicos, ni clases, ni genericos, ni sobrecarga de operadores.
  Solo tipos de tamano fijo, registros planos y punteros a funcion cdecl.

  REGLAS DE LA ABI (seccion 3.4 de WAYLAND.md), y el motivo de cada una:

    1. Todo es cdecl. Estable entre versiones de FPC y frente a un backend
       escrito en C algun dia.
    2. Solo tipos de tamano fijo. Integer cambia de tamano segun el modo y la
       arquitectura, y compilamos para x86_64 y aarch64.
    3. Ningun String, AnsiString, UnicodeString ni array dinamico cruza la
       frontera: los gestiona el RTL, y aqui hay DOS RTL (el del ejecutable y
       el del .so).
    4. Ninguna clase ni objeto Pascal: el diseno de la VMT no es un contrato.
    5. Ninguna excepcion cruza la frontera. Desenrollar la pila entre dos RTL
       es comportamiento indefinido. El plugin captura las suyas y devuelve
       VPAG_ERR_INTERNAL.
    6. Toda estructura empieza por StructSize. Permite ampliar sin romper.
    7. La interfaz lleva ABIVersion: rechazo limpio en vez de fallo aleatorio.
    8. Los errores son enteros; el texto se copia en un buffer del LLAMANTE.
    9. Quien reserva, libera. Ningun puntero a memoria del RTL cruza la
       frontera salvo buffers crudos que reserva y libera el llamante.

  REGLA DE EVOLUCION: los campos de TVPAGraphInterface tienen ORDEN FIJO y
  solo se anaden AL FINAL, nunca en medio, nunca se reordenan y nunca se
  borran. Anadir al final no rompe a un plugin antiguo (ver
  docs/abi-compatibility.md). Por eso la v1 se queda deliberadamente corta:
  todo lo que VPA no usa hoy se deja fuera y se anadira, si algun dia hace
  falta, sin coste ninguno.

  El inventario que justifica cada entrada de este fichero (y la ausencia de
  las demas) esta en docs/vpagraph-api-inventory.md.
  =========================================================================== }

const
  { Version de la ABI. Se sube SOLO si cambia el significado o el diseno de
    algo que ya existia; anadir campos al final no la sube. }
  VPAGRAPH_ABI_VERSION = 1;

  { Nombre del unico simbolo exportado por un plugin. Ver T2.13, al final. }
  VPAGRAPH_ENTRY_POINT = 'VPAGraph_GetInterface';

{ ---------------------------------------------------------------------------
  T2.1 - Tipos de tamano fijo
  Definidos a partir de los tipos base de Pascal y no de Int32/UInt32, que no
  existen en todos los modos. Los tamanos se comprueban en tiempo de
  compilacion mas abajo.
  --------------------------------------------------------------------------- }

type
  TVPAGraphInt8    = shortint;
  TVPAGraphInt16   = smallint;
  TVPAGraphInt32   = longint;
  TVPAGraphUInt8   = byte;
  TVPAGraphUInt16  = word;
  TVPAGraphUInt32  = longword;
  TVPAGraphUInt64  = qword;

  PVPAGraphInt8    = ^TVPAGraphInt8;
  PVPAGraphInt16   = ^TVPAGraphInt16;
  PVPAGraphInt32   = ^TVPAGraphInt32;
  PVPAGraphUInt8   = ^TVPAGraphUInt8;
  PVPAGraphUInt16  = ^TVPAGraphUInt16;
  PVPAGraphUInt32  = ^TVPAGraphUInt32;
  PVPAGraphUInt64  = ^TVPAGraphUInt64;

  { Booleano de la ABI: un byte, 0 = falso, 1 = verdadero. El Boolean de
    Pascal ya es de un byte, pero no esta garantizado por ninguna norma que
    cruce una frontera binaria, y ByteBool/LongBool cambian de tamano. }
  TVPAGraphBool    = TVPAGraphUInt8;

const
  VPAG_FALSE = 0;
  VPAG_TRUE  = 1;

{ ---------------------------------------------------------------------------
  T2.2 - Codigos de error
  Toda funcion de la interfaz que pueda fallar devuelve un TVPAGraphInt32:
  0 correcto, negativo error. El texto asociado se recoge con GetLastError.
  --------------------------------------------------------------------------- }

const
  VPAG_OK                 =    0;  { correcto }
  VPAG_ERR_INVALID_PARAM  =   -1;  { parametro fuera de rango o puntero nulo }
  VPAG_ERR_ABI_MISMATCH   =   -2;  { el plugin no habla esta version de ABI }
  VPAG_ERR_STRUCT_SIZE    =   -3;  { StructSize incoherente con lo esperado }
  VPAG_ERR_INIT           =  -10;  { fallo al inicializar el backend }
  VPAG_ERR_VIDEO          =  -20;  { fallo del servidor grafico o del modo }
  VPAG_ERR_MEMORY         =  -30;  { sin memoria }
  VPAG_ERR_UNSUPPORTED    =  -40;  { funcion no soportada por este backend }
  VPAG_ERR_INTERNAL       = -100;  { excepcion interna capturada en el plugin }

  { Tamano minimo del buffer que hay que pasar a GetLastError para que quepa
    cualquier mensaje que produzca un plugin bien educado. }
  VPAG_ERROR_BUFFER_SIZE  = 256;

{ ---------------------------------------------------------------------------
  Constantes de dibujo que cruzan la frontera
  Mismos valores que la API Graph de BGI/ptcgraph, porque VPA los pasa tal
  cual desde sus 1000+ llamadas y GRAPH/vpagraph.pas los reexporta sin
  traducir (decision D-03 de WAYLAND.md).
  --------------------------------------------------------------------------- }

const
  { Modos de escritura. OJO: los respetan SOLO las primitivas que pasan por
    DirectPutPixel -Line, LineTo, LineRel, Rectangle, Circle, Ellipse-.
    OutTextXY, Bar y PutPixel dibujan siempre en modo normal. Lo hace asi
    ptcgraph (gtext.inc:476, graph.inc:836) y el backend nuevo tiene que
    hacer lo mismo o el texto sale distinto. }
  VPAG_PUT_NORMAL = 0;
  VPAG_PUT_XOR    = 1;
  VPAG_PUT_OR     = 2;
  VPAG_PUT_AND    = 3;
  VPAG_PUT_NOT    = 4;
  { SetWriteMode normaliza: AND -> XOR, y NOT/OR/COPY -> NORMAL
    (graph.inc:1988). La normalizacion la hace el nucleo, no el plugin:
    al plugin solo le llegan VPAG_PUT_NORMAL o VPAG_PUT_XOR. }

  { Estilos de linea }
  VPAG_LINE_SOLID  = 0;
  VPAG_LINE_DOTTED = 1;
  VPAG_LINE_CENTER = 2;
  VPAG_LINE_DASHED = 3;
  VPAG_LINE_USERBIT = 4;   { el patron son los 16 bits de Pattern }

  { Grosores }
  VPAG_WIDTH_NORM  = 1;
  VPAG_WIDTH_THICK = 3;

  { Relleno: VPA solo usa el solido. Los demas patrones de BGI no entran. }
  VPAG_FILL_EMPTY  = 0;
  VPAG_FILL_SOLID  = 1;

  { Justificacion horizontal y vertical }
  VPAG_JUST_LEFT   = 0;
  VPAG_JUST_CENTER = 1;
  VPAG_JUST_RIGHT  = 2;
  VPAG_JUST_BOTTOM = 0;
  VPAG_JUST_TOP    = 2;

  { Direccion del texto: VPA solo escribe en horizontal. }
  VPAG_DIR_HORIZ   = 0;
  VPAG_DIR_VERT    = 1;

  { Identificadores de fuente. 0 es la bitmap 8x8 incorporada; los valores
    positivos los devuelve InstallUserFont. }
  VPAG_FONT_DEFAULT = 0;

{ ---------------------------------------------------------------------------
  T2.12 - Eventos
  --------------------------------------------------------------------------- }

const
  { Tipos de evento }
  VPAG_EVENT_NONE         = 0;
  VPAG_EVENT_KEY_DOWN     = 1;
  VPAG_EVENT_KEY_UP       = 2;
  VPAG_EVENT_MOUSE_MOVE   = 3;
  VPAG_EVENT_MOUSE_DOWN   = 4;
  VPAG_EVENT_MOUSE_UP     = 5;
  VPAG_EVENT_POINTER_ENTER = 6;
  VPAG_EVENT_POINTER_LEAVE = 7;
  VPAG_EVENT_CLOSE        = 8;   { el usuario cierra la ventana }
  VPAG_EVENT_RESIZE       = 9;   { la ventana cambia de tamano (escala) }

  { Modificadores, en la convencion de la BIOS de DOS 0040:0017 que VPA
    espera en Keyboard.KbdFlags. Son combinables. }
  VPAG_MOD_SHIFT = 3;
  VPAG_MOD_CTRL  = 4;
  VPAG_MOD_ALT   = 8;

  { Botones del raton, en la convencion que espera UNIT/MOUSE.PAS }
  VPAG_MB_LEFT   = 1;
  VPAG_MB_RIGHT  = 2;
  VPAG_MB_MIDDLE = 4;

  { Codigos de tecla FISICOS.

    Son los mismos valores que los PTCKEY_* de PTCPas
    (VENDOR/ptc/core/keyeventd.inc), que a su vez son los codigos virtuales
    de AWT. Se reutilizan a proposito y no se inventan otros nuevos: asi el
    plugin X11, que envuelve ptc, los pasa tal cual, y el de Wayland tiene
    una tabla de destino ya definida en vez de una convencion inventada.

    Quien traduce estos codigos a los scancodes del Turbo Pascal que VPA
    espera ($4D00 derecha, $2D00 Alt-X...) es el NUCLEO, en
    GRAPH/vpagraph.pas, no cada plugin (decision D-10): si cada backend
    tradujera por su cuenta, X11 y Wayland acabarian divergiendo en teclas
    raras y el usuario lo notaria antes que nosotros. }
  VPAGK_UNDEFINED   = $00;
  VPAGK_BACKSPACE   = $08;
  VPAGK_TAB         = $09;
  VPAGK_ENTER       = $0A;
  VPAGK_CLEAR       = $0C;
  VPAGK_SHIFT       = $10;
  VPAGK_CONTROL     = $11;
  VPAGK_ALT         = $12;
  VPAGK_CAPSLOCK    = $14;
  VPAGK_ESCAPE      = $1B;
  VPAGK_SPACE       = $20;
  VPAGK_PAGEUP      = $21;
  VPAGK_PAGEDOWN    = $22;
  VPAGK_END         = $23;
  VPAGK_HOME        = $24;
  VPAGK_LEFT        = $25;
  VPAGK_UP          = $26;
  VPAGK_RIGHT       = $27;
  VPAGK_DOWN        = $28;
  VPAGK_COMMA       = $2C;
  VPAGK_PERIOD      = $2E;
  VPAGK_SLASH       = $2F;
  VPAGK_ZERO        = $30;
  VPAGK_ONE         = $31;
  VPAGK_TWO         = $32;
  VPAGK_THREE       = $33;
  VPAGK_FOUR        = $34;
  VPAGK_FIVE        = $35;
  VPAGK_SIX         = $36;
  VPAGK_SEVEN       = $37;
  VPAGK_EIGHT       = $38;
  VPAGK_NINE        = $39;
  VPAGK_SEMICOLON   = $3B;
  VPAGK_EQUALS      = $3D;
  VPAGK_A           = $41;
  VPAGK_Z           = $5A;   { A..Z ocupan $41..$5A, como en ASCII }
  VPAGK_OPENBRACKET = $5B;
  VPAGK_BACKSLASH   = $5C;
  VPAGK_CLOSEBRACKET = $5D;
  VPAGK_NUMPAD0     = $60;
  VPAGK_NUMPAD5     = $65;
  VPAGK_NUMPAD9     = $69;   { NUMPAD0..9 ocupan $60..$69 }
  VPAGK_MULTIPLY    = $6A;   { '*' del teclado numerico }
  VPAGK_ADD         = $6B;   { '+' del teclado numerico }
  VPAGK_SUBTRACT    = $6D;   { '-' del teclado numerico }
  VPAGK_DECIMAL     = $6E;
  VPAGK_DIVIDE      = $6F;
  VPAGK_F1          = $70;
  VPAGK_F12         = $7B;   { F1..F12 ocupan $70..$7B }
  VPAGK_DELETE      = $7F;
  VPAGK_NUMLOCK     = $90;
  VPAGK_INSERT      = $9B;
  VPAGK_MINUS       = $BD;   { '-' de la fila principal }
  VPAGK_BACKQUOTE   = $C0;
  VPAGK_QUOTE       = $DE;

type
  { Un evento de entrada. Estructura plana y de tamano fijo: el plugin la
    rellena en memoria del llamante, nunca reserva nada.

    UnicodeChar NO es decorativo y no se puede quitar: el arreglo de 3.67.5
    para Ctrl-+ y Ctrl-- en teclados no estadounidenses funciona comparando
    el CARACTER, porque en es/de/fr el '+' de la fila principal llega con
    codigo de tecla indefinido y en us/ru como Shift+EQUALS (tabla 3 del
    inventario). Sin este campo, ese arreglo no se puede replicar. }
  PVPAGraphEvent = ^TVPAGraphEvent;
  TVPAGraphEvent = record
    StructSize  : TVPAGraphUInt32;  { = SizeOf(TVPAGraphEvent), lo fija el llamante }
    EventType   : TVPAGraphUInt32;  { VPAG_EVENT_* }
    Timestamp   : TVPAGraphUInt64;  { milisegundos monotonos; 0 si el backend no lo sabe }
    KeyCode     : TVPAGraphUInt32;  { VPAGK_*, tecla fisica }
    ScanCode    : TVPAGraphUInt32;  { codigo crudo del sistema, solo para depurar }
    UnicodeChar : TVPAGraphUInt32;  { punto de codigo, 0 si la tecla no produce caracter }
    Modifiers   : TVPAGraphUInt32;  { VPAG_MOD_*, estado en el momento del evento }
    MouseX      : TVPAGraphInt32;   { coordenadas de SUPERFICIE (0..ancho-1) }
    MouseY      : TVPAGraphInt32;
    MouseButton : TVPAGraphUInt32;  { VPAG_MB_* del boton que cambio }
    Width       : TVPAGraphInt32;   { solo en VPAG_EVENT_RESIZE }
    Height      : TVPAGraphInt32;
    Reserved    : array[0..3] of TVPAGraphUInt32;  { a cero; espacio para no crecer enseguida }
  end;

{ ---------------------------------------------------------------------------
  T2.3 - Parametros de inicializacion
  --------------------------------------------------------------------------- }

type
  PVPAGraphInitParams = ^TVPAGraphInitParams;
  TVPAGraphInitParams = record
    StructSize   : TVPAGraphUInt32;  { = SizeOf(TVPAGraphInitParams) }
    Width        : TVPAGraphInt32;   { superficie logica; VPA usa siempre 640 }
    Height       : TVPAGraphInt32;   { superficie logica; VPA usa siempre 480 }
    ScalePercent : TVPAGraphInt32;   { 100 = 1x, 220 = 2.2x. Sustituye a la
                                       variable global ptcgraph.VPAForceScale }
    Fullscreen   : TVPAGraphBool;    { pedir pantalla completa al arrancar }
    Reserved8    : TVPAGraphUInt8;   { relleno explicito, a cero }
    Reserved16   : TVPAGraphUInt16;  { relleno explicito, a cero }
    WindowTitle  : PAnsiChar;        { terminado en cero, propiedad del LLAMANTE;
                                       el plugin lo copia si lo necesita despues }
  end;

{ ---------------------------------------------------------------------------
  Punteros a funcion
  Todos cdecl. Las coordenadas son TVPAGraphInt32 aunque la API Graph use
  smallint: un entero de 16 bits no ahorra nada en el paso de parametros y
  si nos ha costado ya una corrupcion de heap por desbordamiento (el
  MenuSize de 3.67.5). Los tamanos de imagen son de 32 bits SIEMPRE.
  --------------------------------------------------------------------------- }

type
  { --- T2.5: ciclo de vida --- }

  { Abre la ventana y deja el backend listo para dibujar. }
  TVPAGraphInitProc = function(Params: PVPAGraphInitParams): TVPAGraphInt32; cdecl;

  { Cierra la ventana y libera todo lo del plugin. Idempotente. }
  TVPAGraphShutdownProc = function: TVPAGraphInt32; cdecl;

  { Copia en Buffer, terminado en cero, el texto del ultimo error, y devuelve
    cuantos bytes habria hecho falta (sin el cero). Buffer es del llamante:
    ninguna cadena del RTL del plugin cruza la frontera (regla 8). }
  TVPAGraphGetLastErrorProc = function(Buffer: PAnsiChar;
    BufferSize: TVPAGraphUInt32): TVPAGraphInt32; cdecl;

  { Vuelca a la ventana lo dibujado desde la llamada anterior.

    VPA NO llama a esto: son 1195 OutTextXY y no vamos a tocarlos (D-03).
    Lo llama el NUCLEO desde el camino de entrada -antes de quedarse
    esperando una tecla o de sondear el raton-, que es exactamente cuando la
    pantalla tiene que estar completa. Un backend que pinte directamente
    puede dejarlo en no-op; Wayland lo necesita porque alli la entrega de un
    fotograma es explicita. }
  TVPAGraphPresentProc = function: TVPAGraphInt32; cdecl;

  { Ultimo codigo de error, sin consumirlo. Equivale al GraphResult de BGI
    que VPA consulta tras InitGraph. }
  TVPAGraphGraphResultProc = function: TVPAGraphInt32; cdecl;

  { Suspende la ventana para ejecutar un programa externo (editor, comando)
    y la reabre despues. Sustituye a la pareja RestoreCrtMode +
    SetGraphMode(GetGraphMode) que VPA usa en ocho sitios, y a la terna
    GrabInputFocus / ApplyWindowScale / RequestFullscreen que SIEMPRE la
    sigue (seccion 1.1 del inventario, decision D-08). Resume deja la
    ventana con el foco, la escala y el estado de pantalla completa que
    tenia; el contenido de la superficie NO se conserva, VPA redibuja. }
  TVPAGraphSuspendProc = function: TVPAGraphInt32; cdecl;
  TVPAGraphResumeProc = function: TVPAGraphInt32; cdecl;

  { --- T2.6: dibujo --- }

  TVPAGraphClearDeviceProc = procedure; cdecl;
  TVPAGraphSetViewPortProc = procedure(X1, Y1, X2, Y2: TVPAGraphInt32;
    Clip: TVPAGraphBool); cdecl;
  TVPAGraphGetViewSettingsProc = procedure(X1, Y1, X2, Y2: PVPAGraphInt32;
    Clip: PVPAGraphUInt8); cdecl;
  TVPAGraphSetColorProc = procedure(Color: TVPAGraphUInt32); cdecl;
  TVPAGraphGetColorProc = function: TVPAGraphUInt32; cdecl;
  TVPAGraphSetLineStyleProc = procedure(LineStyle, Pattern,
    Thickness: TVPAGraphUInt32); cdecl;
  TVPAGraphSetFillStyleProc = procedure(Pattern: TVPAGraphUInt32;
    Color: TVPAGraphUInt32); cdecl;
  TVPAGraphSetWriteModeProc = procedure(WriteMode: TVPAGraphUInt32); cdecl;
  TVPAGraphPutPixelProc = procedure(X, Y: TVPAGraphInt32;
    Color: TVPAGraphUInt32); cdecl;
  TVPAGraphGetPixelProc = function(X, Y: TVPAGraphInt32): TVPAGraphUInt32; cdecl;
  TVPAGraphLineProc = procedure(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
  TVPAGraphLineToProc = procedure(X, Y: TVPAGraphInt32); cdecl;
  TVPAGraphLineRelProc = procedure(DX, DY: TVPAGraphInt32); cdecl;
  TVPAGraphMoveToProc = procedure(X, Y: TVPAGraphInt32); cdecl;
  TVPAGraphRectangleProc = procedure(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
  TVPAGraphBarProc = procedure(X1, Y1, X2, Y2: TVPAGraphInt32); cdecl;
  TVPAGraphCircleProc = procedure(X, Y: TVPAGraphInt32;
    Radius: TVPAGraphUInt32); cdecl;

  { Arco de elipse, con angulos en grados y dos radios distintos. No se puede
    reducir a Circle: la unica llamada de VPA (TCOMBAT.PAS:617, el escudo del
    combate) pide media elipse de 9 x ry. }
  TVPAGraphEllipseProc = procedure(X, Y: TVPAGraphInt32;
    StartAngle, EndAngle: TVPAGraphInt32;
    XRadius, YRadius: TVPAGraphUInt32); cdecl;

  { --- T2.7: imagenes ---

    CONTRATO DE MEMORIA (T1.6). El buffer lo reserva y lo libera SIEMPRE VPA,
    nunca el plugin (regla 9). Su diseno es parte de la ABI porque VPA lo
    construye a mano en TCOMBAT.PAS (1350-1361 y 1801-1835) y lo lee en
    EXTFEAT.PAS:4468 y SCRSAVER.PAS:204:

      offset  tamano   contenido
      0       4        ancho en pixeles  (entero de 32 bits, little-endian)
      4       4        alto en pixeles   (entero de 32 bits)
      8       4        reservado, siempre 0
      12      w*h*2    un entero de 16 bits por pixel, fila a fila,
                       con el indice de paleta (0..255) en el byte bajo

      tamano total = 12 + w*h*2, que es lo que devuelve ImageSize.

    ImageSize devuelve 32 bits SIN EXCEPCION: guardarlo en un word fue la
    corrupcion de heap de 3.67.5 (MenuSize/ChooseMenu). PutImage recorta al
    viewport igual que ptcgraph y acepta VPAG_PUT_NORMAL, VPAG_PUT_XOR y
    VPAG_PUT_OR, que son los tres modos que VPA usa. }
  TVPAGraphImageSizeProc = function(X1, Y1, X2, Y2: TVPAGraphInt32): TVPAGraphInt32; cdecl;
  TVPAGraphGetImageProc = procedure(X1, Y1, X2, Y2: TVPAGraphInt32;
    Bitmap: Pointer; BitmapSize: TVPAGraphInt32); cdecl;
  TVPAGraphPutImageProc = procedure(X, Y: TVPAGraphInt32; Bitmap: Pointer;
    BitmapSize: TVPAGraphInt32; BitBlt: TVPAGraphUInt32); cdecl;
  { BitmapSize no existe en la API Graph: se anade aqui para que el plugin
    pueda comprobar que el buffer da de si antes de escribir en el. Es la
    unica defensa posible contra un tamano mal calculado al otro lado. }

  { --- T2.8: paleta ---

    Los valores son de 0 a 255 por canal. La paleta inicial es la del modo
    13h del VGA convertida con (valor de 6 bits) shl 2, asi que el blanco es
    252,252,252 y no 255 (seccion 8 del inventario): un backend que arranque
    con otra tabla cambia todos los colores del juego.

    SetRGBPaletteBlock existe para el caso del combate, que reescribe 15
    entradas seguidas: se pasa un puntero a Count tripletes de bytes (R,G,B)
    y el numero de entradas, nunca un array de Pascal (regla 3). }
  TVPAGraphSetRGBPaletteProc = procedure(ColorNum, R, G, B: TVPAGraphInt32); cdecl;
  TVPAGraphGetRGBPaletteProc = procedure(ColorNum: TVPAGraphInt32;
    R, G, B: PVPAGraphInt32); cdecl;
  TVPAGraphSetRGBPaletteBlockProc = procedure(FirstColor, Count: TVPAGraphInt32;
    RGBTriplets: PVPAGraphUInt8); cdecl;

  { --- T2.9: texto ---

    La conversion de shortstring a PAnsiChar ocurre SOLO en
    GRAPH/vpagraph.pas: son 1195 llamadas a OutTextXY y ninguna de ellas se
    toca (D-03). El nucleo copia la cadena a un buffer estatico terminado en
    cero y pasa el puntero; el plugin no guarda ese puntero mas alla de la
    llamada.

    InstallUserFont recibe el NOMBRE de un fichero .CHR y devuelve un
    identificador positivo, o un codigo de error negativo. El plugin carga y
    rasteriza el .CHR el mismo y libera sus fuentes el mismo (regla 9). Las
    metricas tienen que coincidir con las de ptcgraph o las etiquetas del
    mapa se descuadran (seccion 6 del inventario). }
  TVPAGraphOutTextXYProc = procedure(X, Y: TVPAGraphInt32; Text: PAnsiChar); cdecl;
  TVPAGraphSetTextStyleProc = procedure(Font, Direction,
    CharSize: TVPAGraphUInt32); cdecl;
  TVPAGraphSetTextJustifyProc = procedure(Horiz, Vert: TVPAGraphUInt32); cdecl;
  TVPAGraphInstallUserFontProc = function(FontFileName: PAnsiChar): TVPAGraphInt32; cdecl;

  { --- T2.10: ventana, foco y escala ---

    De las once funciones de UNIT/xfocus.pas solo sobreviven cuatro
    peticiones reales al servidor grafico (decision D-08). Las demas existian
    para alcanzar desde fuera una ventana que ptc creaba sin dar acceso a
    ella, y con la ventana dentro del plugin no hacen falta. }

  { Tamano de la pantalla (o del monitor activo) en pixeles. Se puede llamar
    ANTES de Init: es lo que necesita ResolveScale para decidir la escala.
    La interpretacion de VPA_SCALE se queda en el nucleo, no en el plugin. }
  TVPAGraphGetScreenSizeProc = function(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;

  { Entra o sale de pantalla completa. }
  TVPAGraphSetFullscreenProc = function(Enable: TVPAGraphBool): TVPAGraphInt32; cdecl;

  { Tamano actual de la ventana, en pixeles de pantalla. Informativo: las
    coordenadas de raton ya llegan en unidades de superficie. }
  TVPAGraphGetWindowSizeProc = function(Width, Height: PVPAGraphInt32): TVPAGraphInt32; cdecl;

  { --- T2.11: teclado y raton ---

    No hay ReadKey ni KeyPressed en la ABI: la traduccion a los scancodes del
    Turbo Pascal y el buffer de teclas viven en el nucleo (D-10). El plugin
    solo entrega eventos crudos.

    PollEvent devuelve 1 si ha rellenado un evento, 0 si no habia ninguno, o
    un codigo negativo si algo fallo. No bloquea nunca: quien espera es el
    nucleo, que ademas llama a Present antes de ponerse a esperar. }
  TVPAGraphPollEventProc = function(EventOut: PVPAGraphEvent): TVPAGraphInt32; cdecl;

  { Estado ACTUAL de los modificadores, no el del ultimo evento. VPA lo
    necesita para raton+modificador (el zoom del mapa con Shift/Ctrl), donde
    no hay pulsacion que consultar. Devuelve una combinacion de VPAG_MOD_*. }
  TVPAGraphGetModifiersProc = function: TVPAGraphUInt32; cdecl;

  { Estado del raton en coordenadas de SUPERFICIE (0..ancho-1), ya
    desescaladas por el plugin: el mapeo ventana<->superficie es asunto suyo,
    no de VPA. Inside recibe 1 si el puntero esta dentro de la ventana, que
    es lo que VPA2.PAS:4078 necesita para no hacer auto-scroll infinito. }
  TVPAGraphGetMouseStateProc = procedure(X, Y: PVPAGraphInt32;
    Buttons: PVPAGraphUInt32; Inside: PVPAGraphUInt8); cdecl;

  { Mueve el puntero fisico, tambien en coordenadas de superficie. }
  TVPAGraphSetMousePosProc = procedure(X, Y: TVPAGraphInt32); cdecl;

  { Muestra u oculta el cursor del SISTEMA. VPA dibuja su propia diana. }
  TVPAGraphShowMouseProc = procedure(Show: TVPAGraphBool); cdecl;

  { --- Diagnostico ---

    Vuelca la superficie a disco: Prefix produce Prefix + '0001.ppm' y
    '.pal'. Es lo que hoy hace ptcgraph.VPADumpFrame (tarea T0.4) y lo que
    la Fase 11 necesita para comparar un backend nuevo contra las imagenes
    doradas. Devuelve el numero de fotograma escrito, o negativo si falla. }
  TVPAGraphDumpFrameProc = function(Prefix: PAnsiChar): TVPAGraphInt32; cdecl;

{ ---------------------------------------------------------------------------
  T2.4 - La interfaz

  ORDEN FIJO. Solo se anade al final. Nunca se reordena, nunca se borra, y
  el significado de un campo no cambia sin subir VPAGRAPH_ABI_VERSION.
  --------------------------------------------------------------------------- }

type
  PVPAGraphInterface = ^TVPAGraphInterface;
  TVPAGraphInterface = record
    { --- identificacion --- }
    StructSize        : TVPAGraphUInt32;   { = SizeOf(TVPAGraphInterface) }
    ABIVersion        : TVPAGraphUInt32;   { = VPAGRAPH_ABI_VERSION }
    BackendName       : PAnsiChar;         { 'x11', 'wayland'... propiedad del PLUGIN,
                                             vive mientras el .so este cargado }
    BackendVersion    : PAnsiChar;         { version legible del plugin }

    { --- ciclo de vida (T2.5) --- }
    Init              : TVPAGraphInitProc;
    Shutdown          : TVPAGraphShutdownProc;
    GetLastError      : TVPAGraphGetLastErrorProc;
    Present           : TVPAGraphPresentProc;
    GraphResult       : TVPAGraphGraphResultProc;
    Suspend           : TVPAGraphSuspendProc;
    Resume            : TVPAGraphResumeProc;

    { --- dibujo (T2.6) --- }
    ClearDevice       : TVPAGraphClearDeviceProc;
    SetViewPort       : TVPAGraphSetViewPortProc;
    GetViewSettings   : TVPAGraphGetViewSettingsProc;
    SetColor          : TVPAGraphSetColorProc;
    GetColor          : TVPAGraphGetColorProc;
    SetLineStyle      : TVPAGraphSetLineStyleProc;
    SetFillStyle      : TVPAGraphSetFillStyleProc;
    SetWriteMode      : TVPAGraphSetWriteModeProc;
    PutPixel          : TVPAGraphPutPixelProc;
    GetPixel          : TVPAGraphGetPixelProc;
    Line              : TVPAGraphLineProc;
    LineTo            : TVPAGraphLineToProc;
    LineRel           : TVPAGraphLineRelProc;
    MoveTo            : TVPAGraphMoveToProc;
    Rectangle         : TVPAGraphRectangleProc;
    Bar               : TVPAGraphBarProc;
    Circle            : TVPAGraphCircleProc;
    Ellipse           : TVPAGraphEllipseProc;

    { --- imagenes (T2.7) --- }
    ImageSize         : TVPAGraphImageSizeProc;
    GetImage          : TVPAGraphGetImageProc;
    PutImage          : TVPAGraphPutImageProc;

    { --- paleta (T2.8) --- }
    SetRGBPalette     : TVPAGraphSetRGBPaletteProc;
    GetRGBPalette     : TVPAGraphGetRGBPaletteProc;
    SetRGBPaletteBlock: TVPAGraphSetRGBPaletteBlockProc;

    { --- texto (T2.9) --- }
    OutTextXY         : TVPAGraphOutTextXYProc;
    SetTextStyle      : TVPAGraphSetTextStyleProc;
    SetTextJustify    : TVPAGraphSetTextJustifyProc;
    InstallUserFont   : TVPAGraphInstallUserFontProc;

    { --- ventana (T2.10) --- }
    GetScreenSize     : TVPAGraphGetScreenSizeProc;
    SetFullscreen     : TVPAGraphSetFullscreenProc;
    GetWindowSize     : TVPAGraphGetWindowSizeProc;

    { --- entrada (T2.11) --- }
    PollEvent         : TVPAGraphPollEventProc;
    GetModifiers      : TVPAGraphGetModifiersProc;
    GetMouseState     : TVPAGraphGetMouseStateProc;
    SetMousePos       : TVPAGraphSetMousePosProc;
    ShowMouse         : TVPAGraphShowMouseProc;

    { --- diagnostico --- }
    DumpFrame         : TVPAGraphDumpFrameProc;

    { Espacio para crecer sin mover nada de lo de arriba. Al anadir una
      funcion nueva se consume una de estas casillas y se documenta en
      docs/abi-compatibility.md. }
    Reserved          : array[0..7] of Pointer;
  end;

{ ---------------------------------------------------------------------------
  T2.13 - Punto de entrada

  Un plugin exporta UN solo simbolo, con este nombre y esta firma:

    function VPAGraph_GetInterface(RequestedABIVersion: TVPAGraphUInt32;
                                   InterfaceSize: TVPAGraphUInt32;
                                   InterfaceOut: PVPAGraphInterface
                                  ): TVPAGraphInt32; cdecl;

  El plugin tiene que:
    - devolver VPAG_ERR_ABI_MISMATCH si no sabe hablar esa version;
    - devolver VPAG_ERR_STRUCT_SIZE si InterfaceSize es menor que la parte
      que el plugin necesita rellenar;
    - devolver VPAG_ERR_INVALID_PARAM si InterfaceOut es nil;
    - rellenar como mucho InterfaceSize bytes de InterfaceOut, dejar a nil
      lo que no implemente y devolver VPAG_OK.

  La estructura la reserva el NUCLEO y se la pasa al plugin: asi no hay duda
  de quien la libera (regla 9), y un plugin compilado contra una version
  posterior de este fichero no puede escribir mas alla de lo que el nucleo
  reservo.
  --------------------------------------------------------------------------- }

type
  TVPAGraphGetInterfaceProc = function(RequestedABIVersion: TVPAGraphUInt32;
    InterfaceSize: TVPAGraphUInt32;
    InterfaceOut: PVPAGraphInterface): TVPAGraphInt32; cdecl;
