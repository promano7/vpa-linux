{ VPA-Linux - consola PTC sobre SDL3 (WAYLAND.md, Fase 8, via B; nacio como
  prototipo en T7.3).
  Consola PTC sobre SDL3. No existe en PTCPas rio arriba: es codigo nuevo de
  VPA-Linux que ocupa el hueco que PTCPas deja para cada plataforma
  (TPTCBaseConsole). Solo se compila con -dPTC_SDL3; sin ese define ptc.pp
  sigue siendo exactamente la consola X11 de siempre. }

type
  TSDLConsole = class(TPTCBaseConsole)
  private
    FWindow: PSDL_Window;
    FRenderer: PSDL_Renderer;
    FTexture: PSDL_Texture;
    FOpen: Boolean;
    FWidth, FHeight: Integer;
    FPixels: array of Uint32;      { lo que se presenta: XRGB de 32 bits }
    FTitle: string;
    FFormat: IPTCFormat;
    FArea, FClip: IPTCArea;
    FPalette: IPTCPalette;
    FCopy: TPTCCopy;
    FClear: TPTCClear;
    FEventQueue: TEventQueue;
    FFullscreen, FInterceptClose: Boolean;
    FButtons: TPTCMouseButtonState;       { lo ya contado a VPA }
    FRealButtons: TPTCMouseButtonState;   { lo que dice SDL (ver MouseAt) }
    FLastX, FLastY: Integer;
    FPresentedPrefix: string;      { VPA_GRAPH_PRESENTED, leido en Open }
    FPresentedFrame: Integer;
    FKeyTrace: Boolean;            { VPA_KEY_TRACE, leido en Open }
    FCrossCursor: PSDL_Cursor;     { la diana blanca de VPA }
    FCrossScale: Integer;          { escala con la que se creo; 0 = ninguna }
    FCursorVisible: Boolean;

    procedure CheckOpen;
    procedure UpdateCursor;
    procedure MouseAt(AX, AY: Single; AMoved: Boolean);
    procedure PumpEvents(AWait: Boolean);
    procedure PublishInputState;
    procedure TranslateKey(const AEvent: TSDL_KeyboardEvent);

    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    function GetPitch: Integer; override;
    function GetArea: IPTCArea; override;
    function GetFormat: IPTCFormat; override;
    function GetPages: Integer; override;
    function GetName: string; override;
    function GetTitle: string; override;
    function GetInformation: string; override;
    function GetOpenGL_Enabled: Boolean; override;
    procedure SetOpenGL_Enabled(AValue: Boolean); override;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Open(const ATitle: string; APages: Integer = 0); overload; override;
    procedure Open(const ATitle: string; AFormat: IPTCFormat;
                   APages: Integer = 0); overload; override;
    procedure Open(const ATitle: string; AWidth, AHeight: Integer;
                   AFormat: IPTCFormat; APages: Integer = 0); overload; override;
    procedure Open(const ATitle: string; AMode: IPTCMode;
                   APages: Integer = 0); overload; override;
    procedure Close; override;
    procedure InternalResize(AWidth, AHeight: Integer); override;

    procedure Copy(ASurface: IPTCSurface); override;
    procedure Copy(ASurface: IPTCSurface;
                   ASource, ADestination: IPTCArea); override;
    procedure Load(const APixels: Pointer; AWidth, AHeight, APitch: Integer;
                   AFormat: IPTCFormat; APalette: IPTCPalette); override;
    procedure Load(const APixels: Pointer; AWidth, AHeight, APitch: Integer;
                   AFormat: IPTCFormat; APalette: IPTCPalette;
                   ASource, ADestination: IPTCArea); override;
    procedure Save(APixels: Pointer; AWidth, AHeight, APitch: Integer;
                   AFormat: IPTCFormat; APalette: IPTCPalette); override;
    procedure Save(APixels: Pointer; AWidth, AHeight, APitch: Integer;
                   AFormat: IPTCFormat; APalette: IPTCPalette;
                   ASource, ADestination: IPTCArea); override;

    function Lock: Pointer; override;
    procedure Unlock; override;

    procedure Clear; override;
    procedure Clear(AColor: IPTCColor); override;
    procedure Clear(AColor: IPTCColor; AArea: IPTCArea); override;

    procedure Configure(const AFileName: String); override;
    function Option(const AOption: String): Boolean; override;

    procedure Palette(APalette: IPTCPalette); override;
    procedure Clip(AArea: IPTCArea); override;
    function Clip: IPTCArea; override;
    function Palette: IPTCPalette; override;
    function Modes: TPTCModeList; override;

    procedure Flush; override;
    procedure Finish; override;
    procedure Update; override;
    procedure Update(AArea: IPTCArea); override;

    function NextEvent(out AEvent: IPTCEvent; AWait: Boolean; const AEventMask: TPTCEventMask): Boolean; override;
    function PeekEvent(AWait: Boolean; const AEventMask: TPTCEventMask): IPTCEvent; override;

    function MoveMouseTo(X, Y: Integer): Boolean; override;

    procedure OpenGL_SwapBuffers; override;
    procedure OpenGL_SetSwapInterval(AInterval: Integer); override;
    function OpenGL_GetSwapInterval: Integer; override;
  end;
