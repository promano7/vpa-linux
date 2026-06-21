{
  This emulates Unit Graph on top of the PCC graphics kernel.
}
UNIT Graph;

INTERFACE

CONST Black        = 0;
      Blue         = 1;
      Green        = 2;
      Cyan         = 3;
      Red          = 4;
      Magenta      = 5;
      Brown        = 6;
      LightGray    = 7;

      DarkGray     = 8;
      LightBlue    = 9;
      LightGreen   = 10;
      LightCyan    = 11;
      LightRed     = 12;
      LightMagenta = 13;
      Yellow       = 14;
      White        = 15;

      SolidLn   = 0;
      DottedLn  = 1;
      CenterLn  = 2;
      DashedLn  = 3;
      UserBitLn = 4;

      NormWidth  = 1;
      ThickWidth = 3;

      EmptyFill      = 0;
      SolidFill      = 1;
      LineFill       = 2;
      LtSlashFill    = 3;
      SlashFill      = 4;
      BkSlashFill    = 5;
      LtBkSlashFill  = 6;
      HatchFill      = 7;
      XHatchFill     = 8;
      InterleaveFill = 9;
      WideDotFill    = 10;
      CloseDotFill   = 11;
      UserFill       = 12;

      NormalPut      = 0;
      CopyPut        = 0;
      XORPut         = 1;
      OrPut          = 2;
      AndPut         = 3;
      NotPut         = 4;

      DefaultFont   = 0;
      TriplexFont   = 1;
      SmallFont     = 2;
      SansSerifFont = 3;
      GothicFont    = 4;
      HorizDir      = 0;
      VertDir       = 1;
      UserCharSize  = 0;

      LeftText       = 0;
      CenterText     = 1;
      RightText      = 2;
      BottomText     = 0;
      TopText        = 2;

      ClipOn  = True;
      ClipOff = False;

      VGAHi  = 2;    { This one's only passed to SetGraphMode }
      Detect = 0;

TYPE ViewPortType = record
        x1, y1, x2, y2 : integer;
        Clip           : Boolean;
     end;

{ Setters }
PROCEDURE SetColor(y:BYTE);
FUNCTION GetColor:BYTE;
PROCEDURE SetLineStyle(LineStyle, Pattern, Thickness:WORD);
PROCEDURE SetFillStyle(Pattern: WORD; Color: WORD);
PROCEDURE SetWriteMode(WriteMode:INTEGER);
PROCEDURE SetTextStyle(Font, Direction:INTEGER; CharSize:INTEGER);
PROCEDURE SetTextJustify(H,V:WORD);
PROCEDURE SetViewport(x1,y1,x2,y2:INTEGER; clip:BOOLEAN);
FUNCTION  TextWidth(CONST S:STRING):INTEGER;

PROCEDURE GetViewSettings(VAR v:ViewportType);
PROCEDURE SetRGBPalette(c, r, g, b:INTEGER);

{ Graphics Primitives }
PROCEDURE Circle(x,y:INTEGER; r:WORD);
PROCEDURE Line(x1,y1,x2,y2:INTEGER);
PROCEDURE MoveTo(x,y:INTEGER);
PROCEDURE LineTo(x,y:INTEGER);
PROCEDURE LineRel(x,y:INTEGER);
PROCEDURE Bar(x1,y1,x2,y2:INTEGER);
PROCEDURE Rectangle(x1,y1,x2,y2:INTEGER);
PROCEDURE OutTextXY(x,y:INTEGER; CONST st:STRING);
PROCEDURE PutPixel(x,y:INTEGER; c:WORD);
FUNCTION  GetPixel(x,y:INTEGER):WORD;
PROCEDURE Ellipse(X, Y: Integer; StAngle, EndAngle: Word; XRadius, YRadius: Word);
PROCEDURE ClearDevice;

{ Bitblt }
PROCEDURE PutImage(x,y:INTEGER; VAR bm; blit:WORD);
PROCEDURE GetImage(x,y,x2,y2:INTEGER; VAR bm);
FUNCTION ImageSize(x,y,x2,y2:INTEGER):WORD;

{ Init / Shutdown }
PROCEDURE InitGraph(i, j:INTEGER; CONST path:STRING);
PROCEDURE CloseGraph;
PROCEDURE SetGraphMode(i:INTEGER);
PROCEDURE RestoreCRTMode;
FUNCTION  InstallUserDriver(CONST name:STRING; adptr:POINTER):INTEGER;
FUNCTION  RegisterBGIDriver(ptr:POINTER):INTEGER;
FUNCTION  RegisterBGIFont(ptr:POINTER):INTEGER;

VAR GraphResult : INTEGER;

CONST grOK        = 0;

IMPLEMENTATION

USES Drivers, VGA640, Vesa256, AAFont, AAVesa;

PROCEDURE SansFont; EXTERNAL;
{$L sansfont}

PROCEDURE ProportionalFont; EXTERNAL;
{$L propfont}

CONST UserFillPattern : TPattern = ($FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF);
      FillColor : BYTE = White;

CONST WriteModeMap : ARRAY[0..4] OF BYTE = (wmPut, wmXor, wmOr, wmAnd, wmPut);
      { Note: We don't support NotPut }

VAR Viewport : ViewportType;

PROCEDURE SetColor(y:BYTE);
BEGIN
  Color := y;
END;

FUNCTION GetColor:BYTE;
BEGIN
  GetColor := Color;
END;

PROCEDURE SetLineStyle(LineStyle, Pattern, Thickness:WORD);
CONST Patterns : ARRAY[0..3] OF BYTE = ($FF, $CC, $EE, $EE);
BEGIN
  { Note that the PCC graphics kernel only accepts 8-bit patterns,
    so the rendering is inexact. }
  IF LineStyle=UserBitLn THEN Drivers.LineStyle := Pattern
                         ELSE Drivers.LineStyle := Patterns[LineStyle];
  Drivers.Thickness := Thickness;
END;

PROCEDURE SetFillStyle(Pattern: WORD; Color: WORD);
CONST EmptyFill : TPattern = (0,0,0,0,0,0,0,0);
CONST patterns:ARRAY[0..12] OF ^TPattern = (
                  @EmptyFill,
                  @Drivers.SolidFill,
                  @Drivers.HLineFill,
                  @Drivers.LtSlashFill,
                  @Drivers.LtSlashFill,         { thicker lines, actually }
                  @Drivers.RtSlashFill,         { thicker lines, actually }
                  @Drivers.RtSlashFill,
                  @Drivers.CrossFill,
                  @Drivers.CrossFill,
                  @Drivers.CrossFill,
                  @Drivers.Gray25Fill,
                  @Drivers.Gray50Fill,
                  @UserFillPattern);
BEGIN
  Drivers.SetFillStyle(patterns[Pattern]^);
  FillColor := Color;
END;

PROCEDURE SetWriteMode(WriteMode:INTEGER);
BEGIN
  Drivers.WriteMode := WriteModeMap[WriteMode];
END;

PROCEDURE SetTextStyle(Font, Direction:INTEGER; CharSize:INTEGER);
BEGIN
  { VPA uses SmallFont size 4, and DefaultFont size 1 }
  IF Font=SmallFont THEN Drivers.TextStyle:=1 ELSE Drivers.TextStyle:=0;
END;

PROCEDURE SetTextJustify(H,V:WORD);
BEGIN
  Drivers.SetTextJustify(h, 2-v);
END;

PROCEDURE SetViewport(x1,y1,x2,y2:INTEGER; clip:BOOLEAN);
BEGIN
  Drivers.SetOrigin(x1,y1);
  IF clip THEN Drivers.SetWindow(x1,y1,x2,y2);
  Viewport.x1 := x1;
  Viewport.y1 := y1;
  Viewport.x2 := x2;
  Viewport.y2 := x2;
  Viewport.Clip := Clip;
END;

FUNCTION TextWidth(CONST S:STRING):INTEGER;
BEGIN
  TextWidth := Drivers.TextWidth(S);
END;

PROCEDURE GetViewSettings(VAR v:ViewportType);
BEGIN
  v := Viewport;
END;

PROCEDURE Circle(x,y:INTEGER; r:WORD);
BEGIN
  { Note that our circles look a bit different than Borland's. }
  Drivers.Circle(x,y,r);
END;

PROCEDURE Line(x1,y1,x2,y2:INTEGER);
BEGIN
  Drivers.Line(x1,y1,x2,y2);
END;

PROCEDURE LineTo(x,y:INTEGER);
BEGIN
  Drivers.LineTo(x,y);
END;

PROCEDURE MoveTo(x,y:INTEGER);
BEGIN
  Drivers.MoveTo(x,y);
END;

PROCEDURE LineRel(x,y:INTEGER);
BEGIN
  Drivers.LineRel(x,y);
END;

PROCEDURE Bar(x1,y1,x2,y2:INTEGER);
VAR c : BYTE;
BEGIN
  c := Drivers.Color;
  Drivers.Color := FillColor;
  Drivers.Bar(x1,y1,x2,y2,0);
  Drivers.Color := c;
END;

PROCEDURE Rectangle(x1,y1,x2,y2:INTEGER);
BEGIN
  Drivers.Rectangle(x1,y1,x2,y2);
END;

PROCEDURE OutTextXY(x,y:INTEGER; CONST st:STRING);
BEGIN
  IF Drivers.TextStyle<>0 THEN Inc(y, 3);
  Drivers.OutTextXY(x,y,st);
END;

PROCEDURE PutPixel(x,y:INTEGER; c:WORD);
BEGIN
  Drivers.PutPixel(x,y,c);
END;

FUNCTION GetPixel(x,y:INTEGER):WORD;
BEGIN
  GetPixel := Drivers.Graph^.GetPixel(x+XOrg,y+YOrg);
END;

PROCEDURE Ellipse(X, Y: Integer; StAngle, EndAngle: Word; XRadius, YRadius: Word);
BEGIN
  Drivers.Ellipse(x,y,StAngle,EndAngle,XRadius,YRadius);
END;

PROCEDURE ClearDevice;
BEGIN
  ExtdBar(0, 0, GetMaxX, GetMaxY, 0);
END;

PROCEDURE PutImage(x,y:INTEGER; VAR bm; blit:WORD);
VAR wms : BYTE;
    pix : ARRAY[0..2] OF INTEGER ABSOLUTE bm;
BEGIN
  Inc(pix[0]);
  Inc(pix[1]);
  wms := WriteMode;
  WriteMode := WriteModeMap[blit];
  PutBitmap(x, y, bm, 0, 255);
  WriteMode := wms;
  Dec(pix[0]);
  Dec(pix[1]);
END;

PROCEDURE GetImage(x,y,x2,y2:INTEGER; VAR bm);
VAR b : RECORD
         wi, he:INTEGER;
         data : ARRAY[0..32767] OF BYTE;
    END ABSOLUTE bm;
    i, j, n, ow,oh:INTEGER;
BEGIN
  b.wi := x2-x;
  b.he := y2-y;
  n := 0;
  FOR i:=y TO y2 DO BEGIN
    FOR j:=x TO x2 DO BEGIN
      b.data[n] := GetPixel(j,i);
      Inc(n);
    END;
  END;
END;

FUNCTION ImageSize(x,y,x2,y2:INTEGER):WORD;
VAR L : LONGINT;
    wi:INTEGER;
BEGIN
  wi := x2-x+1;
  IF Odd(wi) THEN Inc(wi);
  L := LONGINT(wi) * (y2-y+1) + 4;
  IF L>65535 THEN ImageSize := 65535 ELSE ImageSize:=L;
END;

PROCEDURE SetStandardPalette;
CONST vga_palette : ARRAY[0..15,0..2] OF BYTE = (
         (0,0,0),
         (0,0,42),
         (0,42,0),
         (0,42,42),
         (42,0,0),
         (42,0,42),
         (42,21,0),
         (42,42,42),
         (21,21,21),
         (21,21,63),
         (21,63,21),
         (21,63,63),
         (63,21,21),
         (63,21,63),
         (63,63,21),
         (63,63,63));
VAR i:INTEGER;
BEGIN
  FOR i:=0 TO 15 DO VesaSetRGB(i, vga_palette[i,0], vga_palette[i,1], vga_palette[i,2]);
END;

PROCEDURE SetRGBPalette(c, r, g, b:INTEGER);
BEGIN
  VesaSetRGB(c, r SHR 2, g SHR 2, b SHR 2);
END;

{ Modify EGA palette entry. Doing this manually is too cumbersome. }
PROCEDURE SetEgaPalette(r,i:BYTE); ASSEMBLER;
ASM
        mov     ax,1000h
        mov     bl,r
        mov     bh,i
        int     10h
END;

PROCEDURE InitGraph(i, j:INTEGER; CONST path:STRING);
VAR pg : PGraph;
    pa : PAAFont;
BEGIN
  IF i=99 THEN BEGIN
    pg := New(PVesa, Init(Vesa640x480));
    IF pg=NIL THEN BEGIN
      GraphResult := -1;
      Exit;
    END;
    Drivers.InitGraph(pg);
  END ELSE BEGIN
    Drivers.InitGraph(New(PVGA, Init($12)));
    FOR i:=0 TO 15 DO SetEgaPalette(i, i);
  END;
  SetTextJustify(LeftText, BottomText);
  SetViewport(0, 0, GetMaxX, GetMaxY, True);

  { Font 0 is normal 8x8 font }
  InstallFont(0, New(PFont, Init));
  Fonts[0]^.Font := @SansFont;

  { Font 1 is proportional font }
  IF i=99 THEN BEGIN
    pa := New(PAAVesa, InitPtr(@ProportionalFont));
  END ELSE BEGIN
    pa := New(PAAFont, InitPtr(@ProportionalFont));
  END;
  AAClip:=TRUE;
  InstallFont(1, pa);

  SetStandardPalette;
END;

PROCEDURE CloseGraph;
BEGIN
  Drivers.CloseGraph;
END;

PROCEDURE SetGraphMode(i:INTEGER);
BEGIN
  SetStandardPalette;
END;

PROCEDURE RestoreCRTMode;
BEGIN
END;

FUNCTION InstallUserDriver(CONST name:STRING; adptr:POINTER):INTEGER;
BEGIN
  InstallUserDriver := 99;
END;

FUNCTION RegisterBGIDriver(ptr:POINTER):INTEGER;
BEGIN
  RegisterBGIDriver := grOK;
END;

FUNCTION RegisterBGIFont(ptr:POINTER):INTEGER;
BEGIN
  RegisterBGIFont := grOK;
END;

END.
