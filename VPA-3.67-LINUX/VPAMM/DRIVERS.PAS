{$A+,B-,E+,F-,G+,I-,L+,N-,O+,R-,S-,V-,X+}
{**************************************************************************

			    U N I T   D R I V E R S

**************************************************************************}
{  Diese Unit implementiert ein Grafik-Interface. Dazu werden benîtigt:
     o Ein Grafikobjekt, wobei ØTGraphÆ als Not-Variante gelten kann,
       Nachkommen sollten mindestens ØPutPixelÆ Åberschreiben
     o Die Grafikprozeduren, Ñhnlich denen von ØGraphÆ
   Koordinatenangaben:
     o Mit ØSetOriginÆ lÑ·t sich der logische Koordinatenursprung
       verschieben, es werden physikalische Koordinaten angegeben, die dann
       zu den Grafikkoordinaten addiert werden
     o Mit ØSetWindowÆ lÑ·t sich ein (physikalischer) Bereich angeben, der
       verÑndert werden darf. Andere Ausgaben werden abgeschnitten. Die
       PrÅfung auf ØInnerhalbÆ erfolgt nach der Addition (s.o.)

   Au·erdem werden noch Routinen zur Event-Bearbeitung angeboten.

   Die Routinen der Basisobjekte (TGraph, TFont) werden nur angeboten, wenn
   der Compilerswitch "GRAPH" definiert ist. Ist dieser nicht definiert,
   enthÑlt TGraph nur GETPIXEL und PUTPATTERN, da diese bis jetzt von keinem
   Grafikobjekt implementiert werden, TFont enthÑlt nur rudimentÑre Objekte.

}

{$DEFINE Graph}

UNIT Drivers;

INTERFACE

USES Objects;

{=== Hilfstypen ===}

TYPE TPattern=ARRAY[0..7] OF BYTE;
     TByteField=ARRAY[0..65534] OF BYTE;
     TCoordinates=RECORD
	    XOrg,YOrg,WinX1,WinY1,WinX2,WinY2:INTEGER;
     END;

{=== Grafikobjekt ===}

CONST
{$IFDEF VER60}
      VMTOffset = 4;
{$ENDIF}
{$IFDEF VER70}
      VMTOffset = 8;
{$ENDIF}
      TGraph_Done       = VMTOffset + 0;
      TGraph_Putpixel   = VMTOffset + 4;
      TGraph_HLine      = VMTOffset + 8;
      TGraph_VLine      = VMTOffset + 12;
      TGraph_Bar        = VMTOffset + 16;
      TGraph_PutBitmap  = VMTOffset + 20;
      TGraph_PutPattern = VMTOffset + 24;
      TGraph_ClearScreen = VMTOffset + 28;
      TGraph_ResetVideo = VMTOffset + 32;
      TGraph_GetPixel   = VMTOffset + 36;

TYPE PGraph=^TGraph;
     TGraph=OBJECT(TObject)
	    OldMode,Mode:BYTE;
	    MaxX,MaxY:INTEGER;
	    CONSTRUCTOR Init(AMode:BYTE);
	    DESTRUCTOR Done; VIRTUAL;
	    PROCEDURE PutPixel(X,Y:INTEGER; C,Op:BYTE); VIRTUAL;
	    PROCEDURE HLine(X1,Y1,X2:INTEGER; Mask,C,Op:BYTE); VIRTUAL;
	    PROCEDURE VLine(X1,Y1,Y2:INTEGER; Mask,C,Op:BYTE); VIRTUAL;
	    PROCEDURE Bar(X1,Y1,X2,Y2:INTEGER; Patt:TPattern; C,Op:BYTE); VIRTUAL;
	    PROCEDURE PutBitMap(X1,Y1,X2,Y2:INTEGER; VWidth:INTEGER; VAR Map; C,Back,Op:BYTE); VIRTUAL;
	    PROCEDURE PutPattern(X1div8,Y1,X2div8,Y2:INTEGER; VWidth:INTEGER; VAR Map; C,Op:BYTE); VIRTUAL;
	    PROCEDURE ClearScreen; VIRTUAL;
	    PROCEDURE ResetVideo; VIRTUAL;
	    FUNCTION GetPixel(X,Y:INTEGER):BYTE; VIRTUAL;
     END;

TYPE PMouse=^TMouse;
     TMouse=OBJECT(TObject)
	    CONSTRUCTOR Init;
	    DESTRUCTOR Done; VIRTUAL;
	    PROCEDURE GetMouse(VAR X,Y:INTEGER; VAR B:BYTE); VIRTUAL;
	    PROCEDURE ShowMouse; VIRTUAL;
	    PROCEDURE HideMouse; VIRTUAL;
	    PROCEDURE MoveMouse(X,Y:INTEGER); VIRTUAL;
	    PROCEDURE MouseWin(X1,Y1,X2,Y2:INTEGER); VIRTUAL;
	    PROCEDURE MouseCur(VAR Cur; XD,YD:INTEGER); VIRTUAL;
	    PROCEDURE MouseRange(X1,Y1,X2,Y2:INTEGER); VIRTUAL;
     END;

{=== Text-Objekt ===}
TYPE PFont=^TFont;
     TFont=OBJECT(TObject)
	    Font:POINTER;
	    State:BYTE;
	    CONSTRUCTOR Init;
	    DESTRUCTOR Done; VIRTUAL;
	    PROCEDURE OutText(X,Y:INTEGER; S:STRING); VIRTUAL;
	    FUNCTION TextWidth(S:STRING):INTEGER; VIRTUAL;
	    FUNCTION TextHeight(S:STRING):INTEGER; VIRTUAL;
	    PROCEDURE LoadFont(VAR S:TStream); VIRTUAL;
	    PROCEDURE SetZoom(Xm,Ym,Xd,Yd:INTEGER); VIRTUAL;
     END;
     TFontItem=RECORD
	    Shape:ARRAY[0..15] OF BYTE;
	    Width:BYTE;
     END;
     PFontData=^TFontdata;
     TFontData=ARRAY[0..255] OF TFontItem;
     PRelFont=^TRelFont;
     TRelFont=OBJECT(TFont)
	    CONSTRUCTOR Init(VAR FontFile:TStream);
	    DESTRUCTOR Done; VIRTUAL;
	    PROCEDURE OutText(X,Y:INTEGER; S:STRING); VIRTUAL;
	    FUNCTION TextWidth(S:STRING):INTEGER; VIRTUAL;
	    FUNCTION TextHeight(S:STRING):INTEGER; VIRTUAL;
	    PROCEDURE LoadFont(VAR S:TStream); VIRTUAL;
     END;

{=== Format einer BitmÑp ===}
TYPE TBitmapImage=RECORD
	   Width,Height:INTEGER;
	   Data:BYTE;
     END;

{=== Optimierte Speicherung fÅr FÅllmuster ===}
TYPE T2Patterns = RECORD
	   CASE BYTE OF
	     0:(Fill:TPattern);
	     1:(X:BYTE;
		Fill2:TPattern);
     END;

TYPE T4Patterns = RECORD
	   CASE BYTE OF
	     0:(Fill:TPattern);
	     1:(X2:BYTE;
		Fill2:TPattern);
	     2:(X3:WORD;
		Fill3:TPattern);
	     3:(X4:ARRAY[0..2] OF BYTE;
		Fill4:TPattern);
     END;

{=== Konstanten fÅr Op-Parameter (Writemode) ===}

CONST wmPut = 0;
      wmAnd = 1;
      wmOr  = 2;
      wmXor = 3;

{=== Konstanten fÅr Grafiktreiber-Eigenschaften ===}
{                                       Farben         Flags         }
{    3                   2                   1                       }
{  1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0   }
{ ⁄ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ“ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ“ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒ¬ƒø  }
{ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ≥ ∫ ≥ ≥D≥  Bits   ∫ ≥ ≥C≥H≥V≥M≥P≥V≥  }
{ ¿ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ–ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ–ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒ¡ƒŸ  }
{                                                                    }

CONST GraphicsDevice:LONGINT=0;
      gdDirectColor=$2000;         { Direct Color mîglich?  - D }
      gdColorBits=$1F00;           { Anzahl Farbbits (1-32)     }
      gdVGAPalette=$0001;          { VGA-Palette?           - V }
      gdRGBPalette=$0002;          { SetRGBPalette mîglich? - P }
      gdMonochrome=$0004;          { Monochrome-Modus?      - M }
      gdVertScroll=$0008;          { Vertikales Scrolling?  - V }
      gdHorScroll=$0010;           { Horizontales Scrolling - H }
      gdMouseCursor=$0020;         { Mauszeiger-Anzeige     - C }

{=== Maus-Interrupt-Routine Maske ===}
CONST miMouseMoves=$0001;          { Maus bewegt sich }
      miLeftPressed=$0002;         { Linke Taste gedr. }
      miLeftReleased=$0004;        { Linke Taste losgelassen }
      miRightPressed=$0008;        { dito rechts }
      miRightReleased=$0010;
      miMiddlePressed=$0020;       { ebenfalls mittel }
      miMiddleReleased=$0040;
      miButtonPressed=$002A;       { Irgendeine Taste gedrÅckt }

{=== FÅllmuster ===}

CONST SolidFill:TPattern=  ($FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF);  {€€€€}

CONST Gray50:T2Patterns=   (X:$AA; Fill2:($55,$AA,$55,$AA,$55,$AA,$55,$AA));
CONST Gray50Fill:TPattern= ($AA,$55,$AA,$55,$AA,$55,$AA,$55);  {±±±±}
CONST Gray50Fill2:TPattern=($55,$AA,$55,$AA,$55,$AA,$55,$AA);  {±±±± invers}

CONST Gray25:T4Patterns=   (X4:($AA,$00,$55); Fill4:($00,$AA,$00,$55,$00,$AA,$00,$55));
CONST Gray25Fill:TPattern= ($AA,$00,$55,$00,$AA,$00,$55,$00);  {∞∞∞∞}

CONST Gray75Fill:TPattern= ($55,$FF,$AA,$FF,$55,$FF,$AA,$FF);  {≤≤≤≤}
CONST RtSlashFill:TPattern=($11,$22,$44,$88,$11,$22,$44,$88);  {////}
CONST LtSlashFill:TPattern=($88,$44,$22,$11,$88,$44,$22,$11);  {\\\\}
CONST VLineFill:TPattern=  ($66,$66,$66,$66,$66,$66,$66,$66);  {≥≥≥≥}
CONST HLineFill:TPattern=  ($00,$FF,$FF,$00,$00,$FF,$FF,$00);  {}
CONST CrossFill:TPattern=  ($81,$42,$24,$18,$18,$24,$42,$81);  {XXXX}

{=== Linienarten ===}

CONST SolidLn=  $FF;      {ƒƒƒƒ}
      DottedLn= $AA;      {˘˘˘˘}
      DashedLn= $BB;      {----}
      CenterLn= $EB;      {-˘-˘}

{=== EGA/VGA-Farben ===}
CONST Black       =0;     {Schwarz}
      Blue        =1;     {Blau}
      Green       =2;     {GrÅn}
      Cyan        =3;     {BlaugrÅn}
      Red         =4;     {Rot}
      Magenta     =5;     {Lila}
      Brown       =6;     {Braun}
      Lightgray   =7;     {Hellgrau}
      Darkgray    =8;     {Dunkelgrau}
      LightBlue   =9;     {Hellblau}
      LightGreen  =10;    {HellgrÅn}
      LightCyan   =11;    {HelltÅrkis}
      LightRed    =12;    {Hellrot}
      LightMagenta=13;    {Helles Lila}
      Yellow      =14;    {Gelb}
      White       =15;    {Wei·}

{=== Text-Anordnung ===}
CONST CenterText  =1;     { Te˘xt }
      TopText     =0;     { Te¯xt }
      BottomText  =2;     { Te.xt }
      LeftText    =0;     { ˘Text }
      RightText   =2;     { Text˘ }

{=== Fehlercodes ===}
CONST grOK        =0;     { kein Fehler }
      grBitmapTooLarge=1; { Bitmap grî·er 64k }
      grNoMemory  =2;     { Operation abgebrochen wegen zu wenig Speicher }

{=== Maus-Variablen ===}
CONST VirtX:INTEGER=0;
      VirtY:INTEGER=0;
      Mouse:PMouse=NIL;

{=== Grafikvariablen ===}

VAR WinY1,WinX1,WinY2,WinX2:INTEGER; { Zeichenfenster                      }
    YOrg,XOrg:INTEGER;               { Koordinatenverschiebung             }
    WriteMode:BYTE;                  { ØOpÆ fÅr div. Operationen           }
    FillPattern:TPattern;            { FÅllmuster (8x8 Pixel)              }
    YCor,XCor:INTEGER;               { Grafikcursor                        }
    Graph:PGraph;                    { Grafiktreiber-Objekt                }
    Thickness,LineStyle:BYTE;        { Liniendicke/Muster                  }
    Fonts:ARRAY[0..15] OF PFont;     { ZeichensÑtze                        }
    Color:BYTE;                      { Farbe fÅr Linien/FÅllung            }
    TextStyle:BYTE;                  { Text-Nummer                         }
    JustY,JustX:BYTE;                { Anordnung von Text                  }
    SavedCS:TCoordinates;            { fÅr LOCK/UNLOCK - gesicherte Koord. }
    GraphError:BYTE;                 { Fehlercode, nur zur Auswt.          }
    TextY,TextX:INTEGER;             { Koordinaten d. letzten Textausgabe  }
    HasRedrawArea:BOOLEAN;           { TRUE = SetRedrawArea aufgerufen     }

{=== Grafikprozeduren ===}

PROCEDURE InitGraph(AGraph:PGraph);
PROCEDURE InitGraph1(AGraph:PGraph);    { wie InitGraph, lÑ·t die Fonts im Speicher }
PROCEDURE CloseGraph;
PROCEDURE MoveTo(X,Y:INTEGER);
PROCEDURE MoveRel(X,Y:INTEGER);
PROCEDURE SetOrigin(X,Y:INTEGER);
PROCEDURE SetWindow(X1,Y1,X2,Y2:INTEGER);
PROCEDURE SetLocalWin(X1,Y1,X2,Y2:INTEGER);
PROCEDURE ClearRedrawArea;
PROCEDURE SetRedrawArea(X1,Y1,X2,Y2:INTEGER);
PROCEDURE PutPixel(X,Y:INTEGER; C:BYTE);
PROCEDURE ChangePixel(X,Y:INTEGER; C:BYTE);
PROCEDURE Bar(X1,Y1,X2,Y2:INTEGER; BackCol:BYTE);
PROCEDURE ExtdBar(X1,Y1,X2,Y2:INTEGER; Color:BYTE);
PROCEDURE HLine(X1,Y1,X2:INTEGER);
PROCEDURE VLine(X1,Y1,Y2:INTEGER);
PROCEDURE Line(X1,Y1,X2,Y2:INTEGER);
PROCEDURE InstallFont(Nr:BYTE; P:PFont);
PROCEDURE OutTextXY(X,Y:INTEGER; S:STRING);
PROCEDURE OutCTextXY(X,Y:INTEGER; S:STRING);
PROCEDURE LineTo(X,Y:INTEGER);
PROCEDURE LineRel(X,Y:INTEGER);
PROCEDURE RectAngle(X1,Y1,X2,Y2:INTEGER);
PROCEDURE Circle(X0,Y0,R:INTEGER);
PROCEDURE FillCircle(X0,Y0,R:INTEGER);
PROCEDURE Ellipse(X,Y,StAngle,EndAngle,XR,YR:INTEGER);
PROCEDURE xEllipse(X,Y,XR,YR:INTEGER);
PROCEDURE SaveCS(VAR CS:TCoordinates);
PROCEDURE RestoreCS(CS:TCoordinates);
PROCEDURE ResetVideo;
PROCEDURE LockVideo;
PROCEDURE UnlockVideo;
PROCEDURE PutBitmap(X,Y:INTEGER; VAR V; Back,Trans:BYTE);
FUNCTION OnScreenRect(X1,Y1,X2,Y2:INTEGER):BOOLEAN;

{=== Prozeduren zum Einstellen von Parametern ===}
PROCEDURE SetColor(C:BYTE);
PROCEDURE SetLineStyle(S:BYTE);
PROCEDURE SetFillStyle(P:TPattern);
PROCEDURE SetLineThickness(T:BYTE);
PROCEDURE SetWriteMode(W:BYTE);
PROCEDURE SetTextStyle(S:BYTE);
PROCEDURE SetTextJustify(XJ,YJ:BYTE);
PROCEDURE SetTextSize(Xm,Ym,Xd,Yd:INTEGER);
FUNCTION TextHeight(S:STRING):INTEGER;
FUNCTION TextWidth(S:STRING):INTEGER;
FUNCTION CTextWidth(S:STRING):INTEGER;
FUNCTION GetMaxX:INTEGER;
FUNCTION GetMaxY:INTEGER;

{=== BitmÑp-Versorgung ===}
PROCEDURE LoadBitmap(VAR S:TStream; VAR P:POINTER);
PROCEDURE FreeBitmap(VAR P:POINTER);
PROCEDURE StoreBitmap(VAR S:TStream; VAR P:POINTER);

{**************************************************************************

    E v e n t b e a r b e i t u n g

**************************************************************************}

{=== Verschiedene Mauszeiger ===}
CONST FourArrows:ARRAY[0..31] OF WORD=
			 ($FE7F,$FC3F,$F81F,$F00F,$E007,$C423,$8001,$0000,
			  $0000,$8001,$C423,$E007,$F00F,$F81F,$FC3F,$FE7F,
			  $0000,$0180,$03C0,$07E0,$0180,$1188,$318C,$7FFE,
			  $7FFE,$318C,$1188,$0180,$07E0,$03C0,$0180,$0000);
CONST Normal:ARRAY[0..31] OF WORD=
			 ($3FFF,$1FFF,$0FFF,$07FF,$03FF,$01FF,$00FF,$007F,
			  $003F,$001F,$001F,$00FF,$10FF,$387F,$F87F,$FC7F,
			  $0000,$4000,$6000,$7000,$7800,$7C00,$7E00,$7F00,
			  $7F80,$7FC0,$7C00,$6600,$4600,$0300,$0300,$0000);

CONST HourGlass:ARRAY[0..31] OF WORD=  { kennt man ja von Windows }
			 ($E00F,$F01F,$F01F,$F01F,$F01F,$F83F,$F83F,$FC7F,
			  $FC7F,$F83F,$F83F,$F01F,$F01F,$F01F,$F01F,$E00F,
			  $0000,$07C0,$07C0,$07C0,$0540,$0280,$0100,$0000,
			  $0100,$0280,$0380,$06C0,$0540,$0280,$0540,$0000);
{=== Ereignis-Record ===}

TYPE TEvent=RECORD
	   What:BYTE;
	   CASE INTEGER OF
	     0:(Key:WORD);
	     1:(X,Y:INTEGER);
	     2:(Command:WORD;
		CASE INTEGER OF
		  0:(Info:POINTER);
		  1:(InfoWord:WORD);
		  2:(InfoLong:LONGINT));
	   END;

{=== Event-Variable ===}
CONST MouseButtons:BYTE=0;          { Anzahl der Maustasten, 0=keine Maus }
CONST EventStart:BYTE=0;            { Erstes Ereignis im Puffer           }
      EventStop:BYTE=0;             { Letztes Ereignis im Puffer          }
      EventCount:BYTE=0;            { Anzahl der gespeicherten Ereignisse }

{=== Event-Typen ===}
      evNothing=0;
      evKeyboard=1;
      evMouse=2;
      evCommand=3;

VAR EventBuf:ARRAY[0..15] OF TEvent;

{=== Maus-Prozeduren ===}
PROCEDURE GetMouse(VAR X,Y:INTEGER; VAR B:BYTE);
PROCEDURE InitMouse;
PROCEDURE DoneMouse;
PROCEDURE ShowMouse;
PROCEDURE HideMouse;
PROCEDURE GetMouseEvent(VAR E:TEvent);
PROCEDURE MoveMouse(X,Y:INTEGER);
PROCEDURE MouseWin(X1,Y1,X2,Y2:INTEGER);
PROCEDURE MouseRange(X1,Y1,X2,Y2:INTEGER);
PROCEDURE WaitMouseOff;
PROCEDURE SetMouseDrv(P:PMouse);

PROCEDURE MouseCur(VAR Cur; XD,YD:INTEGER);
PROCEDURE SetMouseIntPoint(Mask:WORD; Proc:POINTER);

{=== Tastatur-Prozeduren ===}
PROCEDURE GetKeyEvent(VAR E:TEvent);
FUNCTION GetKey:WORD;

{=== Allgemeine Eventbearbeitung ===}

PROCEDURE GetEvent(VAR E:TEvent);
PROCEDURE PutEvent(VAR E:TEvent);

{=== Hilfsprozeduren ===}

FUNCTION Less(A,B:INTEGER):INTEGER;
FUNCTION Greater(A,B:INTEGER):INTEGER;
PROCEDURE SwapInt(VAR A,B:INTEGER);
PROCEDURE SwapIfGreater(VAR A,B:INTEGER);
PROCEDURE IncPointer(VAR P:POINTER);

{*************************************************************************}

IMPLEMENTATION

{*************************************************************************}

USES SysExt;

CONST MaxXYTable:ARRAY[$00..$27] OF INTEGER=
		  (40,25,      40,25,                  { Textmodi       }
		   80,25,      80,25,                  {   -"-          }
		   320,200,    320,200,                { CGA            }
		   640,200,    80,25,                  { CGA, Herc-Text }
		   0,0,0,0,0,0,0,0,0,0,                { (08..0C leer)  }
		   320,200,    640,200,                { EGA            }
		   640,350,    640,350,                { EGA            }
		   640,480,    640,480,                { VGA            }
		   320,200);                           { VGA 256-Farben }

{**************************************************************************

    M e t h o d e n   v o n   T G r a p h   ( Low level - Ansteuerung )

**************************************************************************}

CONSTRUCTOR TGraph.Init;         { Initialisiert Grafik mit Modus ØAModeÆ }
		      ASSEMBLER; { Wenn mîglich, werden ØMaxXÆ und ØMaxYÆ }
ASM                              { auch initialisiert, ØMaxY=25Æ -> Text, }
	LES     DI,Self          { ØMaxX=MaxY=0Æ -> kein gÅltiger Modus,  }
	MOV     AX,0F00H         { ØMaxX=MaxY=-1Æ -> kein bekannter Modus }
	INT     10H
	MOV     TGraph(ES:[DI]).OldMode,AL
	MOV     AL,AMode
	MOV     AH,0
	MOV     BX,AX
	MOV     TGraph(ES:[DI]).Mode,AL
	INT     10H
	CMP     BL,13H
	JA      @NotImplemented
	ADD     BX,BX
	ADD     BX,BX
	MOV     AX,WORD PTR MaxXYTable[BX]
	MOV     TGraph(ES:[DI]).MaxX,AX
	MOV     AX,WORD PTR MaxXYTable[BX+2]
	MOV     TGraph(ES:[DI]).MaxY,AX
	JMP     @Ende
@NotImplemented:
	MOV     TGraph(ES:[DI]).MaxX,-1
	MOV     TGraph(ES:[DI]).MaxY,-1
@Ende:
END;

DESTRUCTOR TGraph.Done; ASSEMBLER;
ASM
	LES     DI,Self
	MOV     AL,TGraph(ES:[DI]).OldMode
	MOV     AH,0
	INT     10H
END;

PROCEDURE TGraph.PutPixel;       { Setze Pixel an Position ØX,YÆ in Farbe }
		      ASSEMBLER; { ØCÆ Åber VerknÅpfung ØOpÆ              }
ASM
{$IFDEF Graph}
	MOV     AL,C
	MOV     BH,0
	MOV     DX,Y
	MOV     CX,X
	CMP     Op,wmPut
	JE      @Set
	MOV     AH,0DH
	INT     10H
	CMP     Op,wmOr
	JNE     @NichtOr
	OR      AL,C
	JMP     @Set
@NichtOr:
	CMP     Op,wmAnd
	JNE     @NichtAnd
	AND     AL,C
	JMP     @Set
@NichtAnd:
	XOR     AL,C
@Set:   MOV     AH,0CH
	INT     10H
{$ENDIF}
END;

PROCEDURE TGraph.HLine;          { Zeichne Linie von ØX1,Y1Æ nach ØX2,Y1Æ  }
VAR i:INTEGER;                   { in Farbe ØCÆ mit Operation ØOpÆ, ØMaskÆ }
BEGIN                            { ist ein Muster, MSB ist links           }
{$IFDEF Graph}
  FOR i:=X1 TO X2 DO IF Odd(Mask SHR (7-(i AND 7))) THEN PutPixel(i,Y1,C,Op);
{$ENDIF}
END;

PROCEDURE TGraph.VLine;          { Zeichne Linie von ØX1,Y1Æ nach ØX1,Y2Æ  }
VAR i:INTEGER;                   { in Farbe ØCÆ mit Operation ØOpÆ, ØMaskÆ }
BEGIN                            { ist ein Muster, MSB liegt unten         }
{$IFDEF Graph}
  FOR i:=Y1 TO Y2 DO IF Odd(Mask SHR (i AND 7)) THEN PutPixel(X1,i,C,Op);
{$ENDIF}
END;

PROCEDURE TGraph.Bar;            { Zeichne Balken von ØX1,Y1Æ bis ØX2,Y2Æ  }
VAR i,j:INTEGER;                 { mit Muster ØPattÆ, Farbe ØCÆ, Operation }
BEGIN                            { ØOpÆ                                    }
{$IFDEF Graph}
  FOR i:=X1 TO X2 DO
    FOR j:=Y1 TO Y2 DO
      IF Odd(Patt[j AND 7] SHR (7-(i AND 7))) THEN PutPixel(i,j,C,Op);
{$ENDIF}
END;

PROCEDURE TGraph.PutBitmap;      { Zeichnet eine Bitmap von ØX1,Y1Æ bis    }
VAR i,j:INTEGER;                 { ØX2,Y2Æ, ZeilenlÑnge im Speicher        }
    f:BYTE;                      { ØVWidthÆ, dargestellt nur ØX2-X1Æ.      }
    dx,dy:INTEGER;               { Farbe ØCÆ ist transparent, ØBackÆ wird  }
BEGIN                            { statt Farbe 0 eingesetzt                }
{$IFDEF Graph}
  dx:=0;
  dy:=0;
  FOR i:=X1 TO X2 DO BEGIN
    FOR j:=Y1 TO Y2 DO BEGIN
      f:=TByteField(Map)[dx+dy*VWidth];
      IF f=0 THEN PutPixel(i,j,Back,Op)
	ELSE IF f<>c THEN PutPixel(i,j,f,Op);
      Inc(dy);
    END;
    dy:=0;
    Inc(dx);
  END;
{$ENDIF}
END;

PROCEDURE TGraph.PutPattern;     { ØXdiv8Æ ist Spalte im 8er-Raster, Zeile }
VAR i,j,k:INTEGER;               { unverÑndert. Es wird eine Bitmap im 2-  }
    v:BYTE;                      { Farben-Modus erzeugt, MSB liegt links.  }
BEGIN                            { ØCÆ ist die Farbe fÅr Eins-Bits, Null-  }
  FOR i:=X1div8 TO X2div8 DO     { Bits sind transparent.                  }
    FOR j:=Y1 TO Y2 DO BEGIN
      v:=TByteField(Map)[i+j*vWidth];
      FOR k:=0 TO 7 DO BEGIN
	IF (v AND $80)<>0 THEN PutPixel(i*8+k,j,C,Op);
	v:=v SHL 1;
      END;
    END;
END;

PROCEDURE TGraph.ClearScreen;    { Lîscht den Bildschirm                   }
ASSEMBLER;
ASM
	LES     DI,Self
	MOV     AL,TGraph(ES:[DI]).Mode
	MOV     AH,0
	INT     10H
END;

PROCEDURE TGraph.ResetVideo;    { Grafik-Register zurÅcksetzen, falls      }
BEGIN END;                      { nîtig (Masken-Register etc.)             }

FUNCTION TGraph.GetPixel;       { Liefert die Farbe des Pixels an ØX,YÆ    }
		    ASSEMBLER;
ASM
	MOV     AH,0DH
	MOV     BH,0
	MOV     CX,X
	MOV     DX,Y
	INT     10H
END;

{***************************************************************************

   M e t h o d e n   v o n   T F o n t

***************************************************************************}

CONSTRUCTOR TFont.Init;         { fast keine Initialisierungen nîtig       }
BEGIN
{$IFDEF Graph}
  Font:=Ptr($FFA6,$000E);
  State:=0;
{$ENDIF}
END;

DESTRUCTOR TFont.Done;          { also auch fast keine AufrÑumarbeiten     }
BEGIN
{$IFDEF Graph}
  IF State<>0 THEN Freemem(Font,2048);
{$ENDIF}
END;

PROCEDURE TFont.OutText;        { gibt den Text im entsprechenden Font aus }
VAR i,j,k:BYTE;
TYPE FontArray=ARRAY[#0..#255,0..7] OF BYTE;
BEGIN
{$IFDEF Graph}
  FOR i:=1 TO Length(S) DO BEGIN
    FOR j:=0 TO 7 DO BEGIN
      FOR k:=0 TO 7 DO IF (FontArray(Font^)[S[i],j] AND ($80 SHR k))<>0 THEN
	PutPixel(X+k,Y+j,Color);
    END;
    Inc(X,8);
  END;
{$ENDIF}
END;

PROCEDURE TFont.LoadFont;       { Service fÅr abgeleitete Objekte          }
BEGIN
{$IFDEF Graph}
  IF State=0 THEN GetMem(Font,2048);
  State:=1;
  S.Read(Font^,2048);
{$ENDIF}
END;

PROCEDURE TFont.SetZoom;        { dasselbe                                 }
BEGIN
END;

FUNCTION TFont.TextHeight;      { Hîhe eines Textes                        }
BEGIN
  TextHeight:=8;
END;

FUNCTION TFont.TextWidth;       { Breite eines Textes                      }
BEGIN
  TextWidth:=8*Length(S);
END;

{***************************************************************************

   M e t h o d e n   v o n   T R e l F o n t

***************************************************************************}

CONSTRUCTOR TRelFont.Init;
BEGIN
  TFont.Init;
  Font:=NIL;
  LoadFont(FontFile);
  IF Font=NIL THEN Fail;
END;

DESTRUCTOR TRelFont.Done;
BEGIN
  IF Font<>NIL THEN Dispose(PFontData(Font));
  TFont.Done;
END;

PROCEDURE TRelFont.OutText;
VAR YY,XX:INTEGER;
    i,j,k:BYTE;
    Item:TFontItem;
BEGIN
  IF (Y+YOrg>WinY2) OR (Y+YOrg+8<WinY1) OR (X+XOrg>WinX2) THEN Exit;
  YY:=Y;
  XX:=X+XOrg;
  FOR i:=1 TO Length(S) DO BEGIN
    Item:=TFontData(Font^)[BYTE(S[i])];
    FOR j:=0 TO Item.Width-1 DO BEGIN
      Y:=YY;
      FOR k:=0 TO 7 DO BEGIN
	IF Odd(Item.Shape[j] SHR k) THEN PutPixel(X,Y,Color);
	Inc(Y);
      END;
      Inc(X);
      Inc(XX);
      IF XX>WinX2 THEN Exit;
    END;
  END;
END;

PROCEDURE TRelFont.LoadFont;
BEGIN
  IF Font=NIL THEN New(PFontData(Font));
  S.Read(Font^,SizeOf(TFontData));
END;

FUNCTION TRelFont.TextHeight;
BEGIN
  TextHeight:=8;
END;

FUNCTION TRelFont.TextWidth;
VAR i:BYTE;
    r:INTEGER;
BEGIN
  r:=0;
  FOR i:=1 TO Length(S) DO Inc(r,TFontData(Font^)[BYTE(S[i])].Width);
  TextWidth:=r;
END;

{***************************************************************************

   H i l f s p r o z e d u r e n   f Å r   G r a f i k i n t e r f a c e

***************************************************************************}

FUNCTION Less; ASSEMBLER;       { Less := kleineres der Argumente          }
ASM
	MOV     AX,A
	MOV     BX,B
	CMP     AX,BX
	JLE     @AXOk
	MOV     AX,BX
@AXOk:
END;

FUNCTION Greater; ASSEMBLER;    { Greater := grî·eres der Argumente        }
ASM
	MOV     AX,A
	MOV     BX,B
	CMP     AX,BX
	JGE     @AXOk
	MOV     AX,BX
@AXOk:
END;

PROCEDURE SwapInt; ASSEMBLER;   { Tauscht 2 Werte aus                      }
ASM
	PUSH    DS
	LES     DI,A
	LDS     SI,B
	MOV     AX,[SI]
	XCHG    ES:[DI],AX
	MOV     [SI],AX
	POP     DS
END;

PROCEDURE SwapIfGreater;        { Tauscht zwei Werte aus, wenn A>B         }
		    ASSEMBLER;
ASM
	PUSH    DS
	LDS     SI,A
	LES     DI,B
	MOV     AX,[SI]
	MOV     BX,ES:[DI]
	CMP     AX,BX
	JNGE    @Ok
	MOV     [SI],BX
	MOV     ES:[DI],AX
@Ok:    POP     DS
END;

PROCEDURE IncPointer; ASSEMBLER;{ Inkrementiert Zeiger                     }
ASM
	LES     DI,P
	MOV     AX,ES:[DI]
	INC     AX
	CMP     AX,10H
	JB      @Alright
	MOV     BX,AX
	AND     AX,0FH
	SHR     BX,4
	ADD     ES:[DI+2],BX
@Alright:
	MOV     ES:[DI],AX
END;

{***************************************************************************

   E n d b e n u t z e r - G r a f i k p r o z e d u r e n

***************************************************************************}

PROCEDURE InitGraph1;   { Initialisiert Standardparameter          }
BEGIN
  Graph:=AGraph;
  XCor:=0;
  YCor:=0;
  Color:=15;
  FillPattern:=SolidFill;
  WriteMode:=wmPut;
  XOrg:=0;
  YOrg:=0;
  WinX1:=0;
  WinY1:=0;
  WinX2:=Graph^.MaxX-1;
  WinY2:=Graph^.MaxY-1;
  HasRedrawArea:=FALSE;
  Thickness:=1;
  LineStyle:=SolidLn;
  JustX:=0;
  JustY:=0;
  TextStyle:=0;
END;

PROCEDURE InitGraph;
VAR i:INTEGER;
BEGIN
  InitGraph1(AGraph);
  FOR i:=0 TO 15 DO Fonts[i]:=NIL;
END;

PROCEDURE CloseGraph;           { Beendet die Grafik                       }
VAR i:BYTE;
BEGIN
  Dispose(Graph,Done);
  FOR i:=0 TO 15 DO IF Fonts[i]<>NIL THEN Dispose(Fonts[i],Done);
END;

PROCEDURE MoveTo;               { Grafikcursor bewegen (absolut)           }
BEGIN
  XCor:=X;
  YCor:=Y;
END;

PROCEDURE MoveRel;              { Grafikcursor bewegen (relativ)           }
BEGIN
  Inc(XCor,X);
  Inc(YCor,Y);
END;

PROCEDURE SetOrigin;            { Nullpunkt festlegen                      }
BEGIN
  XOrg:=X;
  YOrg:=Y;
END;

PROCEDURE SetWindow;            { Ausschnitt festlegen (global)            }
BEGIN                           { Vorige Ausschnitte werden nicht berÅck-  }
  WinX1:=X1;                    { sichtigt, Koordinaten sind global        }
  WinY1:=Y1;                    { FÅr TApplication.Draw                    }
  WinX2:=X2;
  WInY2:=Y2;
  HasRedrawArea:=FALSE;
END;

PROCEDURE SetLocalWin;          { Auschnitt festlegen (lokal)              }
BEGIN                           { Der neue Ausschnitt liegt innerhalb des  }
  WinX1:=Greater(X1+XOrg,WinX1);{ vorher gesetzten (FÅr TView.Draw):       }
  WinY1:=Greater(Y1+YOrg,WinY1);{      ∞∞∞∞∞∞∞∞∞         € Resultat bei... }
  WinX2:=Less(X2+XOrg,WinX2);   {      ∞∞∞∞∞€€€€±±±±±    ∞ SetWindow       }
  WinY2:=Less(Y2+YOrg,WinY2);   {           ±±±±±±±±±    ± SetLocalWin     }
END;

PROCEDURE ClearRedrawArea;      { Lîscht die Redraw Area                   }
BEGIN
  HasRedrawArea:=FALSE;
END;

PROCEDURE SetRedrawArea;          { Auschnitt festlegen (lokal)            }
BEGIN                             { Der neue Ausschnitt enthÑlt sowohl den }
  IF HasRedrawArea THEN BEGIN     { neuen, als auch den alten:             }
    WinX1:=Less(X1+XOrg,WinX1);   {      ∞∞∞∞∞∞∞∞∞€€€€€    € Resultat bei..}
    WinY1:=Less(Y1+YOrg,WinY1);   {      ∞∞∞∞∞±±±±±±±±±    ∞ SetWindow     }
    WinX2:=Greater(X2+XOrg,WinX2);{      €€€€€±±±±±±±±±    ± SetRedrawArea }
    WinY2:=Greater(Y2+YOrg,WinY2);
  END ELSE SetLocalWin(X1,Y1,X2,Y2);
  HasRedrawArea:=TRUE;
END;

{---------------------------------------------------------------------------}
{                                                                           }
{   P u t P i x e l                                                         }
{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - }
{                                                                           }
{   Setzt ein Pixel an (X,Y), ohne BerÅcksichtigung von WriteMode           }
{                                                                           }
{---------------------------------------------------------------------------}
PROCEDURE PutPixel(X,Y:INTEGER; c:BYTE); ASSEMBLER;
ASM
	mov     ax,X
	add     ax,XOrg
	cmp     ax,WinX1
	jl      @@Ende
	cmp     ax,WinX2
	jg      @@Ende
	push    ax

	mov     ax,Y
	add     ax,YOrg
	cmp     ax,WinY1
	jl      @@Ende
	cmp     ax,WinY2
	jg      @@Ende
	push    ax
	mov     al,C
	push    ax
	push    wmPut
	les     di,Graph
	push    es
	push    di
	mov     di,es:[di]
	call    dword ptr [di+TGraph_PutPixel]
@@Ende:
END;

{---------------------------------------------------------------------------}
{                                                                           }
{   C h a n g e P i x e l                                                   }
{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - }
{                                                                           }
{   Setzt ein Pixel an (X,Y) mir BerÅcksichtigung von WriteMode             }
{                                                                           }
{---------------------------------------------------------------------------}
PROCEDURE ChangePixel(X,Y:INTEGER; c:BYTE); ASSEMBLER;
ASM
	mov     ax,X
	add     ax,XOrg
	cmp     ax,WinX1
	jl      @@Ende
	cmp     ax,WinX2
	jg      @@Ende
	push    ax

	mov     ax,Y
	add     ax,YOrg
	cmp     ax,WinY1
	jl      @@Ende
	cmp     ax,WinY2
	jg      @@Ende
	push    ax

	mov     al,C
	push    ax
	mov     al,WriteMode
	push    ax
	les     di,Graph
	push    es
	push    di
	mov     di,es:[di]
	call    dword ptr [di+TGraph_PutPixel]
@@Ende:
END;

{---------------------------------------------------------------------------}
{                                                                           }
{   B a r                                                                   }
{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - }
{                                                                           }
{   Zeichnet einen Balken (X1,Y1)-(X2,Y2) in der gesetzten Zeichenfarbe.    }
{   BackCol ist die Hintergrundfarbe bei non-Solid Mustern, BackCol==Color  }
{   fÅr ein transparenter Muster                                            }
{                                                                           }
{---------------------------------------------------------------------------}
PROCEDURE Bar(X1,Y1,X2,Y2:INTEGER; BackCol:BYTE); ASSEMBLER;
VAR Temp:TPattern;
ASM
		mov     ax,X1           { ax = X1 }
		mov     bx,X2           { bx = X2 }
		mov     cx,XOrg
		cmp     ax,bx           
		jl      @@X_OK          { Tauschen, falls nîtig }
		xchg    ax,bx
@@X_OK:         add     ax,cx           { Offset }
		add     bx,cx
		cmp     ax,WinX1        { Linker Rand }
		jge     @@X1_BOUND
		mov     ax,WinX1
@@X1_BOUND:     cmp     bx,WinX2        { Rechter Rand }
		jle     @@X2_BOUND
		mov     bx,WinX2
@@X2_BOUND:     cmp     ax,bx
		jg      @@Degenerate
		mov     X1,ax
		mov     X2,bx

		mov     ax,Y1           { ax = Y1 }
		mov     bx,Y2           { bx = Y2 }
		mov     cx,YOrg
		cmp     ax,bx
		jl      @@Y_OK          { Tauschen, falls nîtig }
		xchg    ax,bx
@@Y_OK:         add     ax,cx           { Offset }
		add     bx,cx
		cmp     ax,WinY1        { Oberer Rand }
		jge     @@Y1_BOUND
		mov     ax,WinY1
@@Y1_BOUND:     cmp     bx,WinY2        { Unterer Rand }
		jle     @@Y2_BOUND
		mov     bx,WinY2
@@Y2_BOUND:     cmp     ax,bx
		jg      @@Degenerate
		mov     Y1,ax
		mov     Y2,bx
 
		push    X1              { Ersten Balken zeichnen }
		push    ax
		push    X2
		push    bx

		push    ds
		push    offset FillPattern

		mov     al,Color
		push    ax
		mov     al,Writemode
		push    ax

		les     di,Graph
		push    es
		push    di
		mov     di,es:[di]
		call    dword ptr [di+TGraph_Bar]

		mov     al,Color
		cmp     BackCol,al
		je      @@Transparent

		cld                     { Muster invertieren fÅr Hintergrundmuster }
		push    ss
		pop     es
		mov     cx,8
		mov     ah,0
		lea     di,Temp
		mov     bx,di
		mov     si,offset FillPattern
@@NegLoop:      lodsb
		not     al
		or      ah,al
		stosb
		loop    @@NegLoop
		je      @@Transparent

		push    X1              { Hintergrundbalken }
		push    Y1
		push    X2
		push    Y2
		push    ss
		push    bx
		mov     al,BackCol
		push    ax
		mov     al,WriteMode
		push    ax

		les     di,Graph
		push    es
		push    di
		mov     di,es:[di]
		call    dword ptr [di+TGraph_Bar]
@@Transparent:
@@Degenerate:
END;

{---------------------------------------------------------------------------}
{                                                                           }
{   E x t d B a r                                                           }
{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - }
{                                                                           }
{   Zeichnet Balken von (X1,Y1)-(X2,Y2) in der Farbe Color:                 }
{   - 00 .. 0F - Solid in dieser Farbe                                      }
{   - 10 .. FF - Als 50% Mischung aus Color & 0F und Color >> 4             }
{                                                                           }
{---------------------------------------------------------------------------}
PROCEDURE ExtdBar(X1,Y1,X2,Y2:INTEGER; Color:BYTE); ASSEMBLER;
ASM
		mov     ax,X1           { ax = X1 }
		mov     bx,X2           { bx = X2 }
		mov     cx,XOrg
		cmp     ax,bx           
		jl      @@X_OK          { Tauschen, falls nîtig }
		xchg    ax,bx
@@X_OK:         add     ax,cx           { Offset }
		add     bx,cx
		cmp     ax,WinX1        { Linker Rand }
		jge     @@X1_BOUND
		mov     ax,WinX1
@@X1_BOUND:     cmp     bx,WinX2        { Rechter Rand }
		jle     @@X2_BOUND
		mov     bx,WinX2
@@X2_BOUND:     cmp     ax,bx
		jg      @@Degenerate
		mov     X1,ax
		mov     X2,bx

		mov     ax,Y1           { ax = Y1 }
		mov     bx,Y2           { bx = Y2 }
		mov     cx,YOrg
		cmp     ax,bx
		jl      @@Y_OK          { Tauschen, falls nîtig }
		xchg    ax,bx
@@Y_OK:         add     ax,cx           { Offset }
		add     bx,cx
		cmp     ax,WinY1        { Oberer Rand }
		jge     @@Y1_BOUND
		mov     ax,WinY1
@@Y1_BOUND:     cmp     bx,WinY2        { Unterer Rand }
		jle     @@Y2_BOUND
		mov     bx,WinY2
@@Y2_BOUND:     cmp     ax,bx
		jg      @@Degenerate
		mov     Y1,ax
		mov     Y2,bx
 
		push    X1              { Koordinaten }
		push    ax
		push    X2
		push    bx

		push    ds              { Adresse FÅllmuster, Teil 1 }
		mov     dl,Color
		cmp     dl,10h
		jae     @@Mixture

		push    offset SolidFill  { 1 Balken -> FÅllmuster Teil 2 }
		push    dx              { Farbe }

		jmp     @@CallGraph

@@Mixture:      push    offset Gray50.Fill2
		mov     cx,15*16        { 2 Farben -> Hintergrund-Balken }
		and     cx,dx
		shr     cx,4
		push    cx

		push    X1              { Koordinaten VG-Balken }
		push    ax
		push    X2
		push    bx
		push    ds              { Muster VG-Balken }
		push    offset Gray50.Fill
		and     dl,15           { Farbe VG }
		push    dx
		mov     al,WriteMode
		push    ax

		les     di,Graph        { VG-Balken zeichnen }
		push    es
		push    di
		mov     di,es:[di]
		call    dword ptr [di+TGraph_Bar]

@@CallGraph:    mov     al,WriteMode
		push    ax

		les     di,Graph
		push    es
		push    di
		mov     di,es:[di]
		call    dword ptr [di+TGraph_Bar]
@@Degenerate:
END;

{---------------------------------------------------------------------------}
{ Hilfsroutine: Linie von (X1,Y1)-(X2,Y1), LineStyle und Thickness wie im   }
{ Parameter                                                                 }
{---------------------------------------------------------------------------}
PROCEDURE DoHLine(X1,Y1,X2,LineStyle,Thickness:INTEGER); ASSEMBLER;
ASM
		mov     ax,X1           { X-Koordinaten ... }
		mov     bx,X2
		mov     cx,XOrg
		cmp     ax,bx           { ... anordnen ... }
		jl      @@OK
		xchg    ax,bx
@@OK:
		add     ax,cx           { ... verschieben ... }
		add     bx,cx

		cmp     ax,WinX1        { ... und begrenzen }
		jge     @@X1_OK
		mov     ax,WinX1
@@X1_OK:        cmp     bx,WinX2
		jle     @@X2_OK
		mov     bx,WinX2
@@X2_OK:
		cmp     ax,bx                   { AX = X1, BX = X2 }
		jg      @@Degenerate

		mov     X1,ax
		mov     X2,bx

		mov     ax,Thickness
		mov     cx,ax
		jcxz    @@Degenerate

		shr     ax,1
		sub     ax,YOrg
		sub     Y1,ax

@@Loop:         push    cx
		mov     ax,Y1
		cmp     ax,WinY1
		jl      @@Outside
		cmp     ax,WinY2
		jg      @@Outside

		push    X1
		push    ax
		push    X2
		push    Linestyle
		mov     al,Color
		push    ax
		mov     al,WriteMode
		push    ax

		les     di,Graph
		push    es
		push    di
		mov     di,es:[di]
		call    dword ptr [di+TGraph_HLine]

@@Outside:      pop     cx
		inc     Y1
		loop    @@Loop
@@Degenerate:
END;
  
PROCEDURE HLine;
BEGIN
  DoHLine(X1,Y1,X2,LineStyle,Thickness);
END;

PROCEDURE VLine;                { Zeichnet eine Linie von ØX1,Y1Æ nach     }
VAR i:BYTE;                     { ØX1,Y2Æ in der aktuellen Farbe, unter    }
BEGIN                           { BerÅcksichtigung von ØWriteModeÆ, ØLine- }
  SwapIfGreater(Y1,Y2);         { StyleÆ und ØThicknessÆ                   }
  Y1:=Greater(Y1+YOrg,WinY1);
  Y2:=Less(Y2+YOrg,WinY2);
  IF Y1>Y2 THEN Exit;
  X1:=X1-(Thickness SHR 1)+XOrg;
  FOR i:=1 TO Thickness DO BEGIN
    IF (X1>=WinX1) AND (X1<=WinX2) THEN Graph^.VLine(X1,Y1,Y2,LineStyle,
							   Color,WriteMode);
    Inc(X1);
  END;
END;

VAR LineFlag,TH:BYTE;           { <-- interne Flags fÅr Line               }
PROCEDURE Line;                 { beliebige Linie, alle Parameter beachtet }
VAR AX,AY,DX,DY,IX,IY,O,CT:INTEGER;

 PROCEDURE WritePixel(X,Y:INTEGER); { lokale Hilfsprozedur }
 VAR i:BYTE;
 BEGIN
   IF Thickness=1 THEN BEGIN
     IF LineFlag=1 THEN BEGIN
       IF Odd(LineStyle SHR (X AND 7)) THEN ChangePixel(X,Y,Color);
     END ELSE BEGIN
       IF Odd(LineStyle SHR (Y AND 7)) THEN ChangePixel(X,Y,Color);
     END;
   END ELSE
     IF LineFlag=1 THEN BEGIN   { Linie flacher als breit                  }
       Y:=Y-TH+YOrg;
       Inc(X,XOrg);
       IF (X>=WinX1) AND (X<=WinX2) THEN
	 FOR i:=1 TO Thickness DO BEGIN
	   IF (Y>=WinY1) AND (Y<=WinY2) AND
		  Odd(LineStyle SHR (X AND 7)) THEN
	     Graph^.PutPixel(X,Y,Color,WriteMode);
	   Inc(Y);
	 END;
     END ELSE BEGIN             { Linie schmaler als hoch                  }
       X:=X-TH+XOrg;
       Inc(Y,YOrg);
       IF (Y>=WinY1) AND (Y<=WinY2) THEN
	 FOR i:=1 TO Thickness DO BEGIN
	   IF (X>=WinX1) AND (X<=WinX2) AND
		  Odd(LineStyle SHR (Y AND 7)) THEN
	     Graph^.PutPixel(X,Y,Color,WriteMode);
	   Inc(X);
	 END;
     END;
 END;

BEGIN
  IF X1=X2 THEN BEGIN
    Vline(X1,Y1,Y2);
    Exit;
  END;
  IF Y1=Y2 THEN BEGIN
    HLine(X1,Y1,X2);
    Exit;
  END;
  IF NOT OnscreenRect(X1,Y1,X2,Y2) THEN Exit;
  TH:=Thickness SHR 1;
  AX:=0;
  AY:=0;
  IF X2>=X1 THEN BEGIN
    DX:=X2-X1;
    IX:=1;
  END ELSE BEGIN
    DX:=X1-X2;
    IX:=-1;
  END;
  IF Y2>=Y1 THEN BEGIN
    DY:=Y2-Y1;
    IY:=1;
  END ELSE BEGIN
    DY:=Y1-Y2;
    IY:=-1;
  END;
  IF DX<DY THEN BEGIN
    LineFlag:=0;            { Linie hîher als breit }
    SwapInt(DX,DY);
    AY:=IX;
    AX:=IY;
    IX:=0;
    IY:=0;
  END ELSE LineFlag:=1;     { Linie breiter als hoch }
  O:=DX SHR 1;
  CT:=1;
  WritePixel(X1,Y1);
  WHILE DX>=CT DO BEGIN
    Inc(X1,IX);
    Inc(Y1,AX);
    Inc(CT);
    Inc(O,DY);
    IF WORD(O)>WORD(DX) THEN BEGIN
      Dec(O,DX);
      Inc(X1,AY);
      Inc(Y1,IY);
    END;
    WritePixel(X1,Y1);
  END;
END;

PROCEDURE InstallFont;          { Installiert Font-Objekt                  }
BEGIN
  IF Fonts[Nr]<>NIL THEN Dispose(Fonts[Nr],Done);
  Fonts[Nr]:=P;
  IF P<>NIL THEN TextStyle:=Nr;
END;

PROCEDURE OutTextXY;            { Text ausgeben. Wie - liegt in der Ver-   }
VAR DX,DY:INTEGER;              { antwortung vom TFont-Objekt              }
BEGIN
  IF Fonts[TextStyle]<>NIL THEN BEGIN
    WITH Fonts[TextStyle]^ DO BEGIN
      IF JustX<>0 THEN DX:=TextWidth(S) ELSE DX:=0;
      IF JustY<>0 THEN DY:=TextHeight(S) ELSE DY:=0;
    END;
    IF JustX=1 THEN DX:=DX DIV 2;
    IF JustY=1 THEN DY:=DY DIV 2;
    TextX:=X-DX;
    TextY:=Y-DY;
    Fonts[TextStyle]^.OutText(TextX,TextY,S);
  END;
END;

PROCEDURE OutCTextXY;           { Text ausgeben, analog zu OutTextXY.      }
VAR DX,DY,h,XX:INTEGER;
    S1:STRING;
    U:BOOLEAN;
    i:BYTE;
BEGIN
  IF Fonts[TextStyle]<>NIL THEN BEGIN
    h:=TextHeight(S);
    IF JustX<>0 THEN DX:=CTextWidth(S) ELSE DX:=0;
    IF JustY<>0 THEN DY:=h ELSE DY:=0;
    IF JustX=1 THEN DX:=DX DIV 2;
    IF JustY=1 THEN DY:=DY DIV 2;
    TextX:=X-DX;
    TextY:=Y-DY;
    U:=FALSE;
    WHILE S<>'' DO BEGIN
      i:=Pos('~',S);
      IF i=0 THEN BEGIN
	S1:=S;
	S:='';
      END ELSE BEGIN
	S1:=Copy(S,1,i-1);
	Delete(S,1,i);
      END;
      Fonts[TextStyle]^.OutText(TextX,TextY,S1);
      XX:=TextX;
      Inc(TextX,TextWidth(S1));
      IF U THEN HLine(XX,TextY+h+1,TextX);
      U:=NOT U;
    END;
  END;
END;

PROCEDURE LineTo;               { Linie vom Grafikcursor zu ØX,YÆ zeichnen }
BEGIN
  Line(XCor,YCor,X,Y);
  XCor:=X;
  YCor:=Y;
END;

PROCEDURE LineRel;              { Linie vom Grafikcursor ØXÆ Pixel nach    }
BEGIN                           { rechts und ØYÆ Pixel nach unten          }
  LineTo(XCor+X,YCor+Y);
END;

PROCEDURE Rectangle;            { Rechteck von ØX1,Y1Æ nach ØX2,Y2Æ        }
BEGIN
  HLine(X1,Y1,X2);
  HLine(X1,Y2,X2);
  VLine(X1,Y1,Y2);
  VLine(X2,Y1,Y2);
END;

PROCEDURE Circle;               { Kreis zeichnen                           }
VAR Z,Y2:LONGINT;               { Nutzt die Eigenschaft ‰(2k-1)=k˝ fÅr     }
    xk:WORD;
    x,w:INTEGER;
    k:LONGINT;
    w0:INTEGER;
BEGIN                           { Kreisgleichungsberechnung (x˝+y˝=r˝)     }
  W:=0;                 { EnthÑlt eine Koordinate }
  k:=1;                 { Ungerade Zahl fÅr Quadratzahlberechnung }
  z:=0;                 { EnthÑlt Quadratzahl w˝ }
  y2:=0;                { EnthÑlt y˝ }
  xk:=Pred(2*R);        { Ungerade Zahl fÅr y˝-Berechnung }
  x:=R;                 { EnthÑlt die andere Koordinate }
  WHILE x>=0 DO BEGIN
    ASM
        mov     si,w
	MOV     AX,WORD PTR Z[0]    { DX:AX = Z }
	MOV     DX,WORD PTR Z[2]
	MOV     BX,WORD PTR Y2[0]   { CX:BX = Y2 }
	MOV     CX,WORD PTR Y2[2]
     @Schleifenstart:
	CMP     DX,CX
	JA      @Schleifenende   { Dieser tolle Assembler-Block entspricht }
	JB      @Schleifenrumpf  { so Pi*Daumen:                           }
	CMP     AX,BX            {    WHILE Z<Y2 DO BEGIN                  }
	JAE     @Schleifenende   {      Inc(z,k);    Quadratzahl (w+1)˝    }
     @Schleifenrumpf:            {      Inc(w);      w <ƒ w+1              }
	ADD     AX,WORD PTR k[0] {      Inc(k,2);    ungerade Zahl         }
	ADC     DX,WORD PTR k[2] {    END;                                 }
        inc     si
	ADD     WORD PTR k[0],2
	ADC     WORD PTR k[2],0
	JMP     @Schleifenstart
     @Schleifenende:
	MOV     WORD PTR Z[0],AX
	MOV     WORD PTR Z[2],DX
        mov     w, si
    END;
    IF W>=X THEN BEGIN
      ChangePixel(X0-X,Y0-W,Color);
      ChangePixel(X0+X,Y0-W,Color);
      ChangePixel(X0-W,Y0-X,Color);
      ChangePixel(X0+W,Y0-X,Color);
      ChangePixel(X0-W,Y0+X,Color);
      ChangePixel(X0+W,Y0+X,Color);
      ChangePixel(X0-X,Y0+W,Color);
      ChangePixel(X0+X,Y0+W,Color);
    END;
    Inc(y2,xk);
    Dec(xk,2);
    Dec(x);
  END;
(* Version aus bgi++: nicht nennenswert schneller
  w:=0;
  k:=1;
  z:=0;
  y2:=0;
  xk:=2*r-1;
  x:=r;
  w0:=w;
  WHILE x >= w DO BEGIN
    WHILE z < y2 DO BEGIN
      Inc(z, k);
        HLine(x0-w0, y0-x, x0-w);
        HLine(x0+w0, y0-x, x0+w);
        VLine(x0-x, y0-w0, y0-w);
        VLine(x0+x, y0-w0, y0-w);
        VLine(x0+x, y0+w0, y0+w);
        VLine(x0-x, y0+w0, y0+w);
        HLine(x0-w0, y0+x, x0-w);
        HLine(x0+w0, y0+x, x0+w);
      Inc(w);
      w0 := w;
      Inc(k, 2);
    END;
    Inc(y2, xk);
    Dec(xk, 2);
    Dec(x);
  END; *)
END;

PROCEDURE FillCircle;           { GefÅllten Kreis zeichnen                 }
VAR W,K,Z,Y2,XK,X:LONGINT;      { Nutzt die Eigenschaft ‰(2k-1)=k˝ fÅr     }
BEGIN                           { Kreisgleichungsberechnung (x˝+y˝=r˝)     }
  IF NOT OnScreenRect(X0-R,Y0-R,X0+R,Y0+R) THEN Exit;
  W:=0;                 { EnthÑlt eine Koordinate }
  k:=1;                 { Ungerade Zahl fÅr Quadratzahlberechnung }
  z:=0;                 { EnthÑlt Quadratzahl w˝ }
  y2:=0;                { EnthÑlt y˝ }
  xk:=Pred(2*R);        { Ungerade Zahl fÅr y˝-Berechnung }
  x:=R;                 { EnthÑlt die andere Koordinate }
  WHILE X>=0 DO BEGIN
    ASM
	MOV     AX,WORD PTR Z[0]    { DX:AX = Z }
	MOV     DX,WORD PTR Z[2]
	MOV     BX,WORD PTR Y2[0]   { CX:BX = Y2 }
	MOV     CX,WORD PTR Y2[2]
     @Schleifenstart:
	CMP     DX,CX
	JA      @Schleifenende   { Dieser tolle Assembler-Block entspricht }
	JB      @Schleifenrumpf  { so Pi*Daumen:                           }
	CMP     AX,BX            {    WHILE Z<Y2 DO BEGIN                  }
	JAE     @Schleifenende   {      Inc(z,k);    Quadratzahl (w+1)˝    }
     @Schleifenrumpf:            {      Inc(w);      w <ƒ w+1              }
	ADD     AX,WORD PTR k[0] {      Inc(k,2);    ungerade Zahl         }
	ADC     DX,WORD PTR k[2] {    END;                                 }
	ADD     WORD PTR w[0],1  {                                         }
	ADC     WORD PTR w[2],0
	ADD     WORD PTR k[0],2
	ADC     WORD PTR k[2],0
	JMP     @Schleifenstart
     @Schleifenende:
	MOV     WORD PTR Z[0],AX
	MOV     WORD PTR Z[2],DX
    END;
    DoHLine(X0-W,Y0-X,X0+W,FillPattern[(Y0-X) AND 7],1);
    DoHLine(X0-W,Y0+X,X0+W,FillPattern[(Y0+X) AND 7],1);
    Inc(y2,xk);
    Dec(xk,2);
    Dec(x);
  END;
END;

{$I SINTAB.INC}			{ don't hardwire path  --sr, 10/03/2002 }

FUNCTION iSin(i:INTEGER):INTEGER;
BEGIN
  WHILE i>360 DO Dec(i,360);
  iSin:=SinTab[i];
END;

FUNCTION iCos(i:INTEGER):INTEGER;
BEGIN
  iCos:=iSin(i+90);
END;

PROCEDURE Ellipse;              { Ellipse zeichnen                         }
VAR i,j:INTEGER;               {(X,Y,StAngle,EndAngle,XR,YR:INTEGER);}
    XX,YY:INTEGER;
BEGIN
  IF EndAngle=0 THEN EndAngle:=360;
  i:=StAngle;
  XX:=X+Round(XR*iCos(i) DIV 127);
  YY:=Y+Round(YR*iSin(i) DIV 127);
  MoveTo(XX,YY);
  REPEAT
    Inc(i);
    WHILE i>360 DO Dec(i,360);
    XX:=X+Round(XR*iCos(i) DIV 127);
    YY:=Y+Round(YR*iSin(i) DIV 127);
    LineTo(XX,YY);
  UNTIL i=EndAngle;
END;

PROCEDURE xEllipse;             { Ellipse zeichnen                         }
VAR i,j:INTEGER;               {(X,Y,XR,YR:INTEGER);}
    XX,YY:INTEGER;
BEGIN
  i:=0;
  XX:=X+(LONGINT(XR)*iCos(i)) DIV 127;
  YY:=Y+(LONGINT(YR)*iSin(i)) DIV 127;
  MoveTo(XX,YY);
  REPEAT
    Inc(i,10);
    XX:=X+(LONGINT(XR)*iCos(i)) DIV 127;
    YY:=Y+(LONGINT(YR)*iSin(i)) DIV 127;
    LineTo(XX,YY);
  UNTIL i>=360;
END;

PROCEDURE SaveCS;               { Aktuelles Koordinatensystem in ØCSÆ      }
BEGIN                           { sichern                                  }
  CS.XOrg:=XOrg;
  CS.YOrg:=YOrg;
  CS.WinX1:=WinX1;
  CS.WinY1:=WinY1;
  CS.WinX2:=WinX2;
  CS.WinY2:=WinY2;
END;

PROCEDURE RestoreCS;            { Koordinatensystem aus ØCSÆ wiederher-    }
BEGIN                           { stellen                                  }
  XOrg:=CS.XOrg;
  YOrg:=CS.YOrg;
  WinX1:=CS.WinX1;
  WinY1:=CS.WinY1;
  WinX2:=CS.WinX2;
  WinY2:=CS.WinY2;
END;

PROCEDURE ResetVideo;           { ØResetVideoÆ-Methode vom Graph aufrufen  }
BEGIN                           { = RÅcksetzen von Parametern je nach      }
  Graph^.ResetVideo;            { Treiber                                  }
END;

PROCEDURE LockVideo;            { Bildschirmausgaben unterbinden           }
BEGIN
  SaveCS(SavedCS);
  WinX1:=1;
  WinX2:=0;
  WinY1:=1;
  WinY2:=0;
  {SetWindow(0,0,0,0);}
END;

PROCEDURE UnlockVideo;          { Koordinaten von vor ØLockVideoÆ restau-  }
BEGIN                           { rieren                                   }
  RestoreCS(SavedCS);
END;

PROCEDURE PutBitmap;            { Stellt eine Bitmap dar, die in der Varia-}
VAR X1,Y1,X2,Y2:INTEGER;        { blen ØVÆ gespeichert ist. Das Format im  }
    P:POINTER;                  { Speicher ist Breite/Hîhe/Daten. Die      }
TYPE Image=RECORD               { Farbe ØTransÆ ist durchsichtig, ØBackÆ   }
	Width,Height:WORD;      { wird statt Farbe 0 eingesetzt            }
	Data:ARRAY[0..0] OF BYTE;
     END;
BEGIN
  X1:=Greater(X+XOrg,WinX1);
  Y1:=Greater(Y+YOrg,WinY1);
  X2:=Less(Pred(X+XOrg+Image(V).Width),WinX2);
  Y2:=Less(Pred(Y+YOrg+Image(V).Height),WinY2);
  IF (X1>X2) OR (Y1>Y2) THEN Exit;
  P:=Addr(Image(V).Data);
  IF Y1<>Y THEN ASM
	MOV     AX,Y1
	SUB     AX,Y            { AX := Anzahl zu Åberspringender Zeilen   }
	LES     DI,V
	IMUL    WORD PTR ES:[DI] { DX:AX := Anzahl Åberspr. Bytes          }
	ADD     WORD PTR P[0],AX { DX=0, da Bitmap nicht grî·er 64k        }
  END;
  IF X1<>X THEN ASM
	MOV     AX,X1
	SUB     AX,X            { AX := Anzahl zu Åberspringender Bytes    }
	ADD     WORD PTR P[0],AX
  END;
{$IFDEF ___________} Kommentar 14/09/2000: warum *das*?
  ASM                           { Zeiger normieren                         }
	MOV     AX,WORD PTR P[0]
	CMP     AX,16
	JB      @SchonNormal
	MOV     DX,AX           { Offset-Anteil laden                      }
	MOV     CL,4
	SHR     DX,CL           { durch 16 teilen -> Segmentverschiebung   }
	ADD     WORD PTR P[2],DX  { addieren                               }
	AND     AX,15           { entferne Segmentverschiebung aus Offset  }
	MOV     WORD PTR P[0],AX
   @SchonNormal:
  END;
{$ENDIF}
  Graph^.PutBitmap(X1,Y1,X2,Y2,Image(V).Width,P^,Trans,Back,WriteMode);
END;

FUNCTION OnScreenRect;          { PrÅfe, ob ein Bereich (auch teilweise)   }
BEGIN                           { sichtbar ist                             }
  SwapIfGreater(X1,X2);
  SwapIfGreater(Y1,Y2);
  X1:=Greater(X1+XOrg,WinX1);
  Y1:=Greater(Y1+YOrg,WinY1);
  X2:=Less(X2+XOrg,WinX2);
  Y2:=Less(Y2+YOrg,WinY2);
  OnScreenRect:=(X1<=X2) AND (Y1<=Y2);
END;

{***************************************************************************

    E i n s t e l l e n   v o n   P a r a m e t e r n

***************************************************************************}

FUNCTION TextHeight;            { Liefert Hîhe eines Textes zurÅck         }
BEGIN
  IF Fonts[TextStyle]<>NIL THEN TextHeight:=Fonts[TextStyle]^.TextHeight(S)
    ELSE TextHeight:=0;
END;

FUNCTION TextWidth;             { Liefert Breite eines Textes zurÅck       }
BEGIN
  IF Fonts[TextStyle]<>NIL THEN TextWidth:=Fonts[TextStyle]^.TextWidth(S)
    ELSE TextWidth:=0;
END;

FUNCTION CTextWidth;            { Liefert Breite eines Textes zurÅck       }
VAR i,j:BYTE;
    k:INTEGER;
BEGIN
  IF Fonts[TextStyle]<>NIL THEN BEGIN
    j:=Fonts[TextStyle]^.TextWidth('~');
    k:=0;
    FOR i:=1 TO Length(S) DO IF S[i]='~' THEN Inc(k,j);
    CTextWidth:=Fonts[TextStyle]^.TextWidth(S)-k;
  END ELSE CTextWidth:=0;
END;

PROCEDURE SetColor;             { Setzt die Farbe auf einen Wert           }
BEGIN
  Color:=C;
END;

PROCEDURE SetLineStyle;         { Setzt das Linienmuster: Ein Bytewert,    }
BEGIN                           { Bit gesetzt = Pixel gesetzt. Das LSB ist }
  LineStyle:=S;                 { rechts bzw. oben                         }
END;

PROCEDURE SetFillStyle;         { Setzt das FÅllmuster, Mono-Bitmap 8x8    }
BEGIN                           { Das LSB ist rechts                       }
  FillPattern:=P;
END;

PROCEDURE SetLineThickness;     { Setzt die Liniendicke (empfohlen 1..9,   }
BEGIN                           { dann sehr starker QualitÑtsverlust       }
  Thickness:=T;
END;

PROCEDURE SetWriteMode;         { Setzt den Zeichenmodus auf öberschreiben }
BEGIN                           { AND, OR oder XOR                         }
  WriteMode:=W;
END;

PROCEDURE SetTextStyle;         { Setzt den Zeichensatz auf einen der 16   }
BEGIN                           { ØFont-SlotsÆ                             }
  IF Fonts[S]<>NIL THEN TextStyle:=S;
END;

PROCEDURE SetTextJustify;       { Setzt die Art der Koordinateninterpreta- }
BEGIN                           { tion bei Textausgaben: 0=links/oben, 1=  }
  IF (XJ>=0) AND (XJ<=2) AND    { zentriert, 2=rechts/unten                }
   (YJ>=0) AND (YJ<=2) THEN BEGIN
    JustX:=XJ;
    JustY:=YJ;
  END;
END;

PROCEDURE SetTextSize;          { Setzt Textgrî·e, abhÑngig vom TFont-Obj. }
BEGIN
  IF Fonts[TextStyle]<>NIL THEN Fonts[TextStyle]^.SetZoom(Xm,Ym,Xd,Yd);
END;

FUNCTION GetMaxX;               { Maximale Bildbreite                      }
BEGIN
  GetMaxX:=Graph^.MaxX;
END;

FUNCTION GetMaxY;               { Maximale Bildhîhe                        }
BEGIN
  GetMaxY:=Graph^.MaxY;
END;

{***************************************************************************

   B i t m Ñ p - V e r s o r g u n g

***************************************************************************}

PROCEDURE LoadBitmap;           { LÑdt eine BitmÑp aus dem angegebenen     }
VAR Method,Width,Height:INTEGER;{ Stream, liefert NIL zurÅck, wenn:        }
    Size:LONGINT;               { * Grî·e = 0                              }
BEGIN                           { * Grî·e > 64k                            }
  S.Read(Method,2);             { * nicht genug Speicher                   }
  S.Read(Width,2);              { Die BitmÑp-Daten werden auf jeden Fall   }
  S.Read(height,2);             { Åberlesen                                }
  Size:=Width*Height;
  IF Size<=0 THEN
   BEGIN
    P:=NIL;
    GraphError:=0;
    Exit;
  END;
  Inc(Size,4);
  IF Size>65520 THEN BEGIN
    P:=NIL;
    S.Seek(S.GetPos+Size);
    GraphError:=grBitmapTooLarge;
    Exit;
  END;
  IF Size>MaxAvail THEN BEGIN
    P:=NIL;
    S.Seek(S.GetPos+Size);
    GraphError:=grNoMemory;
    Exit;
  END;
  GetMem(p,Size);
  S.Seek(S.GetPos-4);
  S.Read(P^,Size);
END;

PROCEDURE FreeBitmap;           { Gibt den von einer BitmÑp belegten Spei- }
TYPE Image=RECORD               { cher frei.                               }
	   Width,Height:INTEGER;
	   Data:BYTE;
     END;
BEGIN
  IF P=NIL THEN Exit;
  FreeMem(P,Image(P^).Width*Image(P^).Height+4);
  P:=NIL;
END;

PROCEDURE StoreBitmap;          { Speichert die Bitmap in einem Stream     }
TYPE Image=RECORD
	   Width,Height:INTEGER;
	   Data:BYTE;
     END;
CONST NILBmp:ARRAY[0..2] OF WORD=(0,0,0);
BEGIN
  IF P=NIL THEN S.Write(NILBmp,6) ELSE BEGIN
    S.Write(NILBmp,2);
    S.Write(P^,Image(P^).Width*Image(P^).Height+4);
  END;
END;

{***************************************************************************

   E v e n t - M a n a g e r

***************************************************************************}

{===========================================================================
   M a u s s t e u e r u n g
===========================================================================}
PROCEDURE InitMouse;
BEGIN
  SetMouseDrv(New(PMouse,Init));
END;

PROCEDURE SetMouseDrv(P:PMouse);
BEGIN
  IF Mouse<>NIL THEN Dispose(Mouse,Done);
  Mouse:=P;
END;

PROCEDURE MouseCur(VAR Cur; XD,YD:INTEGER);
BEGIN
  IF Mouse<>NIL THEN Mouse^.MouseCur(Cur,XD,YD);
END;

PROCEDURE DoneMouse;              { Beendet den Maustreiber                }
BEGIN
  SetMouseDrv(NIL);
END;

PROCEDURE ShowMouse;
BEGIN
  IF Mouse<>NIL THEN Mouse^.ShowMouse;
END;

PROCEDURE HideMouse;
BEGIN
  IF Mouse<>NIL THEN Mouse^.HideMouse;
END;

PROCEDURE GetMouse(VAR X,Y:INTEGER; VAR B:BYTE);
BEGIN
  IF Mouse<>NIL THEN Mouse^.GetMouse(X,Y,B) ELSE BEGIN
    X:=VirtX;
    Y:=VirtY;
    B:=0;
  END;
END;

PROCEDURE MoveMouse;
BEGIN
  IF Mouse<>NIL THEN Mouse^.MoveMouse(X,Y) ELSE BEGIN
    VirtX:=X;
    VirtY:=Y;
  END;
END;

PROCEDURE GetMouseEvent;          { Holt ein Mausereignis. Wenn keine     }
BEGIN                             { Maustaste gedrÅckt ist, wird ØevNo-   }
  GetMouse(E.X,E.Y,E.What);       { thingÆ zurÅckgegeben                  }
  IF E.What<>0 THEN E.What:=evMouse;
END;

PROCEDURE MouseWin(X1,Y1,X2,Y2:INTEGER);
BEGIN
  IF Mouse<>NIL THEN Mouse^.MouseWin(X1,Y1,X2,Y2);
END;

PROCEDURE MouseRange(X1,Y1,X2,Y2:INTEGER);
BEGIN
  IF Mouse<>NIL THEN Mouse^.MouseRange(X1,Y1,X2,Y2);
END;

PROCEDURE SetMouseIntPoint; ASSEMBLER; { Setzt die Maus-Interrupt-Routine  }
ASM
	CMP     Mousebuttons,0
	JE      @Ende
	MOV     AX,12
	MOV     CX,Mask
	LES     DX,Proc
	INT     33h
@Ende:
END;

PROCEDURE WaitMouseOff;
VAR X,Y:INTEGER;
    B:BYTE;
BEGIN
  ShowMouse;
  REPEAT
    GetMouse(X,Y,B);
  UNTIL B=0;
  HideMouse;
END;

{===========================================================================
   M a u s - O b j e k t
===========================================================================}
CONSTRUCTOR TMouse.Init;          { Initialisiert den Maustreiber          }
BEGIN                             { Setzt ØMouseButtonsÆ auf die Anzahl    }
  TObject.Init;                   { der Maustasten, 0 = keine Maus         }
  ASM
	XOR     AX,AX
	INT     33H
	CMP     AX,0FFFFH
	JNE     @NoMouse
	MOV     MouseButtons,BL
	JMP     @Ende
@NoMouse:
	MOV     MouseButtons,0
@Ende:
  END;
  IF MouseButtons=0 THEN Fail;
END;

DESTRUCTOR TMouse.Done;
BEGIN
  SetMouseIntPoint(0,NIL);
END;

PROCEDURE TMouse.MouseCur; ASSEMBLER;{ éndert die Form des Mauscursors     }
ASM
	CMP     MouseButtons,0
	JE      @Ende
	MOV     AX,9
	MOV     BX,XD
	MOV     CX,YD
	LES     DX,Cur
	INT     33H
@Ende:
END;

PROCEDURE TMouse.ShowMouse; ASSEMBLER;    { Zeigt den Mauszeiger an                }
ASM
	CMP     MouseButtons,0
	JE      @NoMouse
	MOV     AX,1
	INT     33H
@NoMouse:
END;

PROCEDURE TMouse.HideMouse; ASSEMBLER;    { Lîscht den Mauszeiger vom Bildschirm   }
ASM
	CMP     MouseButtons,0
	JE      @NoMouse
	MOV     AX,2
	INT     33H
@NoMouse:
END;

PROCEDURE TMouse.GetMouse; ASSEMBLER; { Holt den Status der Maustasten und die }
ASM                                   { Position der Maus                          }
	CMP     MouseButtons,0
	JE      @NoMouse
	MOV     AX,3
	INT     33H
	JMP     @PutIt
@NoMouse:
	XOR     BX,BX
	MOV     CX,BX
	MOV     DX,BX
@PutIt:
	LES     DI,X
	SUB     CX,XOrg
	MOV     ES:[DI],CX
	LES     DI,Y
	SUB     DX,YOrg
	MOV     ES:[DI],DX
	LES     DI,B
	MOV     ES:[DI],BL
END;

PROCEDURE TMouse.MoveMouse; ASSEMBLER;    { Bewegt die Maus zur Position ØX,YÆ    }
ASM
	CMP     MouseButtons,0
	JE      @NoMouse
	MOV     AX,4
	MOV     CX,X
	MOV     DX,Y
	INT     33H
@NoMouse:
END;

PROCEDURE TMouse.MouseWin; ASSEMBLER;     { Versteckt den Mauszeiger, wenn er in  }
ASM                               { dem angegebenen Fenster ist           }
	CMP     MouseButtons,0
	JE      @NoMouse
	MOV     AX,10h
	MOV     CX,X1
	MOV     DX,Y1
	MOV     SI,X2
	MOV     DI,Y2
	INT     33h
@NoMouse:
END;

PROCEDURE TMouse.MouseRange; ASSEMBLER;   { Mausbewegung auf Bereich limitieren  }
ASM
	CMP     MouseButtons,0
	JE      @NoMouse
	MOV     AX,7
	MOV     CX,X1
	MOV     DX,X2
	INT     33h
	MOV     AX,8
	MOV     CX,Y1
	MOV     DX,Y2
	INT     33h
@NoMouse:
END;

{==========================================================================
    T a s t a t u r t r e i b e r
==========================================================================}

PROCEDURE GetKeyEvent;            { Holt ein Tastaturereignis. Wenn kein  }
BEGIN                             { Tastaturereignis verfÅgbar ist, wird  }
  E.Key:=GetKey;                  { evNothing zurÅckgegeben.              }
  IF E.Key=0 THEN E.What:=0 ELSE E.What:=evKeyboard;
END;

FUNCTION GetKey; ASSEMBLER;       { Holt eine Taste via Fn ØExtd.ReadkeyÆ }
ASM                               { Konvertiert Ø‡-TastenÆ in normale     }
	MOV     AH,11H            { Codes, lÑuft nur bei neuerem BIOS     }
	INT     16H               { Extended Keypressed }
	JZ      @NoKey            { ... keine Taste }
	MOV     AH,10H
	INT     16H
	CMP     AL,20h
	JNE     @NoSpace
	MOV     ES,Seg0040
	TEST    BYTE PTR ES:[17h],8    { Alt gedrÅckt?                   }
	JZ      @NoSpace
	MOV     AX,$0200 {kbAltSpace}
	JMP     @Ende
@NoSpace:
	CMP     AL,0E0H           { '‡'-Taste ? (Extended Hackbrett) }
	JNE     @NoSpecial
	CMP     AH,0              { Zeichen #244='‡' ? }
	JE      @NoSpecial
	MOV     AL,0              { Erzeuge 'normale' Cursortaste }
	JMP     @Ende
@NoSpecial:
	CMP     AL,0              { Spezialtaste ? }
	JE      @Ende
	MOV     AH,0              { sonst Scancode auf 0 }
	JMP     @Ende
@NoKey:
	XOR   AX,AX
@Ende:
END;

{===========================================================================
    E v e n t m a n a g e r
===========================================================================}

PROCEDURE GetEvent;               { Holt ein Ereignis. Die Maus hat Vor-   }
BEGIN                             { rang. Wenn kein Ereignis verfÅgbar     }
  IF EventCount<>0 THEN BEGIN     { ist, wird cmIdle zurÅckgegeben         }
    E:=EventBuf[EventStart];      { Ereignisse aus dem Puffer werden       }
    EventStart:=Succ(EventStart)  { selbstverfreilich berÅcksichtigt       }
			   AND 15;
    Dec(EventCount);
  END ELSE BEGIN
    GetMouseEvent(E);
    IF E.What=0 THEN GetKeyEvent(E);
    IF E.What=0 THEN BEGIN
      E.What:=evCommand;
      E.Command:=$FFFF {cmIdle from BGITV};
    END;
  END;
END;

PROCEDURE PutEvent;               { Schreibt ein Ereignis in den Puffer,   }
BEGIN                             { welcher nach dem FIFO-Prinzip aufge-   }
  IF EventCount=16 THEN Exit;     { baut ist. Wenn schon 16 Ereignisse in  }
  EventBuf[EventStop]:=E;         { der Warteschlange stehen, wird der Be- }
  EventStop:=Succ(EventStop)      { fehl ignoriert.                        }
			  AND 15;
  Inc(EventCount);
END;

END.
