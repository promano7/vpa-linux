{---------------------------------------------------------------------------}
{                                                                           }
{               P l a n e t s   C o m m a n d   C e n t e r                 }
{                                                                           }
{                            1995-2002 by Streu                             }
{                                                                           }
{---------------------------------------------------------------------------}
{                                                                           }
{                          M e s s a g e b o x e s                          }
{                                                                           }
{---------------------------------------------------------------------------}
UNIT MsgWin;
{$D-,S-}
{$I switches.inc}

INTERFACE

{$IFNDEF VPA}
USES UI;
{$ENDIF}

{--- String with up to 1024 chars ---}
TYPE PChar=^TChar;
     TChar=RECORD
        Len:WORD;
        Text:ARRAY[0..1023] OF CHAR;
     END;
     MStr63=STRING[63];

{$IFNDEF VPA}
TYPE PTextWindow = ^CTextWindow;
     CTextWindow = OBJECT(CUIWindow)
              pt   : PChar;
              wi   : INTEGER;
              font : INTEGER;
              CONSTRUCTOR Init(awidth, areserve : INTEGER;
                               CONST attl       : MSTR63;
                               atext            : PChar;
                               afc, afont       : INTEGER);
              PROCEDURE DrawInterior; VIRTUAL;
     END;
{$ENDIF}

PROCEDURE AddStr(PC:PChar; CONST S:STRING);
FUNCTION  CountLines(Width:INTEGER; Text:PChar):INTEGER;
PROCEDURE OutFormatted(X,Y,dy:INTEGER; Width:INTEGER; Text:PChar);
PROCEDURE OutFormattedStr(X,Y,dy:INTEGER; Width:INTEGER; CONST S:STRING);
PROCEDURE NMessageBox(CONST Text:STRING; Title:MStr63);
FUNCTION  NYesNo(CONST Text:STRING; Title:MStr63):BOOLEAN;
FUNCTION  NYesNoCancel(CONST Text:STRING; Title:MStr63):INTEGER;
FUNCTION  NMessageDlg(CONST Text, Title: STRING; Buttons: MStr63):INTEGER;
PROCEDURE NMemError;
PROCEDURE Warning(CONST S:STRING);

FUNCTION ReadkeyUC:CHAR;

{$IFNDEF VPA}
CONST mwc_DEFAULT = wfc_RedWindow;

CONST mwColor:BYTE=mwc_DEFAULT;
{$ENDIF}

CONST LastWarn:STRING='';

IMPLEMENTATION

{$IFNDEF VPA}
USES Drivers,Global,AAFont,User,Config,LowLevel,VGARegs;
{$ELSE}
USES VPACC, Graph, StrF, Screen;
{$ENDIF}

{ Read a character, upcase it }
FUNCTION ReadkeyUC : CHAR; ASSEMBLER;
ASM
	xor	ax,ax
	int	16h
	cmp	al,'a'
	jb	@@ok
	cmp	al,'z'
	ja	@@ok
	sub	al,32
@@ok:
END;

{
  Append string S to long string PC
}
PROCEDURE AddStr(PC:PChar; CONST S:STRING);
VAR i : INTEGER;
    L : INTEGER;
BEGIN
  IF S='' THEN Exit;
  i:=1024-PC^.Len;
  L := Length(S);
  IF L > i THEN L := i;
  Move(S[1],PC^.Text[PC^.Len], L);
  Inc(PC^.Len, L);
END;

{
  Format TEXT to WIDTH pixels width; count lines
}
FUNCTION CountLines(Width:INTEGER; Text:PChar):INTEGER;
VAR LastTW:INTEGER;
    i:INTEGER;
    Wi:INTEGER;
    Lines:INTEGER;
    C:CHAR;
BEGIN
  Lines:=1;
  i:=0;
  Wi:=0;
  LastTW:=0;
  REPEAT
    C:=Text^.Text[i];
    Inc(i);

    IF C=#13 THEN BEGIN
      Inc(Lines);
      Wi:=0;
      LastTW:=0;
    END ELSE BEGIN
      Inc(Wi,TextWidth(C));
      IF C=' ' THEN BEGIN
        LastTW:=Wi;
      END;
      IF Wi>Width THEN BEGIN
        IF LastTW=0 THEN BEGIN
          Wi:=0;
        END ELSE BEGIN
          Dec(Wi,LastTW);
          LastTW:=0;
        END;
        Inc(Lines);
      END;
    END;
  UNTIL i>=Text^.Len;
  CountLines:=Lines;
END;

{
  Output text, formatted.
    X,Y    origin
    dy     line height
    width  formatting width
}
PROCEDURE OutFormatted(X,Y,dy:INTEGER; Width:INTEGER; Text:PChar);
VAR LastSpace,LastTW:INTEGER;
    i,j:INTEGER;
    Wi:INTEGER;
    Lines:INTEGER;
    C:CHAR;
    S:STRING;
BEGIN
  IF Text^.Len=0 THEN Exit;
  Lines:=0;
  i:=0;
  Wi:=0;
  LastSpace:=0;         { Index in S }
  LastTW:=0;
  S:='';
  REPEAT
    C:=Text^.Text[i];
    Inc(i);
    IF C<>#13 THEN BEGIN
      Inc(Wi,TextWidth(C));
      CatChar(S, C);  { S:=S+C; }
      IF C=' ' THEN BEGIN
        LastSpace:=Length(S);
        LastTW:=Wi;
      END;
    END;
    IF (Wi>Width) OR (C=#13) THEN BEGIN
      IF (LastTW=0) OR (C=#13) THEN BEGIN
        OutTextXY(X,Y,S);
        Wi:=0;
        S:='';
        LastSpace:=0;
        LastTW:=0;
      END ELSE BEGIN
        Dec(Wi,LastTW);
        OutTextXY(X,Y,Copy(S,1,LastSpace));
        Delete(S,1,LastSpace);
        LastSpace:=0;
        LastTW:=0;
      END;
      Inc(Lines);
      Inc(Y,dY);
    END;
  UNTIL i>=Text^.Len;
  OutTextXY(X,Y,S);
END;

{
  Like OutFormatted; shortcut for TP strings
}
PROCEDURE OutFormattedStr(X,Y,dy:INTEGER; Width:INTEGER; CONST S:STRING);
VAR T : TChar;
BEGIN
  T.Len := 0;
  AddStr(@T, S);
  OutFormatted(X, Y, dy, Width, @T);
END;

{*** CTextWindow class *****************************************************}
{$IFNDEF VPA}
{
  This is used for certain dialogs that contain a longer text (sell
  supplies, password)
}

CONST def_he:ARRAY[0..4] OF INTEGER=(20, 16, 12, 15, 6);

{
  awidth        screen width
  areserve      reserved space below text (for buttons and other widgets)
  attl          window title
  atext         the text to display
  afc           window frame color
  afont         font to use for text
}
CONSTRUCTOR CTextWindow.Init(awidth,areserve : INTEGER;
                             CONST attl      : MSTR63;
                             atext           : PChar;
                             afc, afont      : INTEGER);
VAR L:INTEGER;
    xx1, yy1:INTEGER;
BEGIN
  TextStyle := afont;
  L := CountLines(awidth - 40, atext);

  yy1 := 210 - 10*L + cur_start - areserve DIV 2;
          { cur_start = Y coordinate of scanline 0 }
  xx1 := (640-awidth) DIV 2;

  CUIWindow.Init(xx1, yy1, xx1 + awidth, yy1 + def_he[afont]*L + 55 + areserve, attl, afc, Gray);
  TextStyle := 0;

  pt := atext;
  wi := awidth;
  font := afont;

  IF NOT Tooltips THEN MouseRange(x1, y1, x2, y2);
END;

PROCEDURE CTextWindow.DrawInterior;
BEGIN
  Color := 0;
  AAColor := Dark;
  JustX := 0;
  JustY := 0;
  TextStyle := font;
  OutFormatted(x1+20, y1+35, def_he[font], wi - 40, pt);
  TextStyle := 0;
END;
{$ENDIF}

{*** Main Entry Points *****************************************************}

FUNCTION Hack(s : STRING) : STRING;
VAR i : INTEGER;
BEGIN
  FOR i:=Length(s) DOWNTO 1 DO IF (s[i]=#13) AND ((i=Length(s)) OR (s[i+1]<>#10)) THEN
   Insert(#10, s, i);
  Hack := s;
END;

{
  Message box. Equivalent to CCScript `MessageBox' command.
  This one can be called to report memory shortage, hence the
  unconventional widget handling.
}
PROCEDURE NMessageBox(CONST Text:STRING; Title:MStr63);
VAR w  : INTEGER;
{$IFNDEF VPA}
    E  : CEvent;
    tw : CTextWindow;
    tb : CButton;
    tt : CKeyTrans;
{$ENDIF}
    p  : TChar;
BEGIN
  IF Title='' THEN Title := 'Error';

  IF NOT Gr THEN BEGIN
    Writeln(Title, ColonSP, Hack(Text));
    Exit;
  END;

{$IFNDEF VPA}
 {$IFNDEF ccs}
  w := TextWidth(Text);
  IF w < 120 THEN w := 120;
  IF w > 440 THEN w := 440;

  p.Len := 0;
  AddStr(@p, Text);

 { Allocate everything on stack, nothing dynamic here (->no SetHelp!)
   Hence NMessagebox can be used to report memory shortages. Do not
   call destructors (these assume that everything is heap-allocated) }

  tw.Init(w + 45, 30, Title, @p, mwColor, 0);
  tb.InitR(cm_Enter, 280, tw.y2 - 40, 80, 25, OKtext, 0, 32);
  tt.Init(NIL);
  tw.Add(@tb);
  tw.Add(@tt);
  OpenWindow(@tw, TRUE);
  REPEAT WinLoop(0, E); UNTIL (E.Cmd = cm_Enter) OR (E.Cmd = cm_Escape);

 { Simulates UI::CloseWindow }
  SetWindow(tw.x1, tw.y1, tw.x2, tw.y2);
  Mouseoff;
  current_window := current_window^.super;
  IF current_window<>NIL THEN current_window^.DrawWithSupers;
  Fullscreen;
  Ping;
 {$ENDIF}
{$ELSE}
  NMessageDlg(Text, Title, 'OK');
{$ENDIF}
END;

{
  Message box with multiple buttons. Equivalen to CCScript `UI.Message'.
}
FUNCTION NMessageDlg(CONST Text, Title: STRING; Buttons: MStr63):INTEGER;
CONST MAX=10;
VAR i, nbuttons : INTEGER;
    w, x        : INTEGER;
    bwi         : INTEGER;
{$IFNDEF VPA}
    pw          : PWindow;
    E           : CEvent;
{$ELSE}
    nlines      : INTEGER;
    y, y2       : INTEGER;
{$ENDIF}
    c           : CHAR;
    btext       : ARRAY[1..MAX] OF STRING[15];
    p           : TChar;
LABEL Break, Out;
BEGIN
  {--- Split button string into individual texts ---}
  nbuttons := 0;
  REPEAT
    Strip1(Buttons);
    i := Pos(' ', Buttons);
    IF i=0 THEN i:=Length(Buttons)+1;
    IF i=1 THEN GOTO Break;
    IF nbuttons < MAX THEN BEGIN
      Inc(nbuttons);
      btext[nbuttons] := Copy(Buttons, 1, i-1);
    END;
    Delete(Buttons, 1, i);
  UNTIL FALSE;
 Break:
  IF nbuttons=0 THEN BEGIN
    NMessageDlg := 0;
    Exit;
  END;

  {--- Textmode Version ---}
  IF NOT Gr THEN BEGIN
    Write(Title, ColonSP, Hack(Text), ' (');
    FOR i:=1 TO nbuttons DO BEGIN
      IF i<>1 THEN Write('/');
      Write(btext[i][1]);
    END;
    Write(') ');
    REPEAT
      c := ReadkeyUC;
      IF c=#13 THEN c:=Upcase(btext[1][1]) ELSE
      IF c=#27 THEN c:=Upcase(btext[nbuttons][1]);
      FOR i:=1 TO nbuttons DO IF c=Upcase(btext[i][1]) THEN BEGIN
        Writeln(c);
        NMessageDlg := i;
        Exit;
      END;
    UNTIL FALSE;
  END;

{$IFNDEF VPA}
 {$IFNDEF ccs}
  {--- Graphics Version ---}
  w := TextWidth(Text);
  IF w>440 THEN w:=440;

  i := Graph^.MaxX - 50;
  bwi := nbuttons*85 + 55;
  IF bwi>i THEN bwi:=i;
  IF bwi>w THEN w := bwi;

  bwi := (w-55) DIV nbuttons;
  IF bwi>85 THEN bwi := 85;

  p.Len := 0;
  AddStr(@p, Text);

  pw := New(PTextWindow, Init(w + 45, 30, Title, @p, mwColor, 0));
  FOR i:=1 TO nbuttons DO BEGIN
    x := 315 - (nbuttons * bwi) DIV 2 + bwi * Pred(i);
    pw^.Add(New(PButton, InitR(i, x, pw^.y2 - 40, bwi-10, 25, btext[i], 0, Ord(btext[i][1]))));
  END;
  OpenWindow(pw, TRUE);
  REPEAT
    WinLoop(wl_RetKeys, E);
    IF E.Typ=ev_Key THEN CASE E.Key OF
      13, 32:BEGIN
        NMessageDlg := 1;
        GOTO Out;
      END;
      27:BEGIN
        NMessageDlg := nbuttons;
        GOTO Out;
      END;
    END ELSE IF (E.Typ=ev_Command) AND (E.Cmd > 0) AND (E.Cmd <= nbuttons)
    THEN BEGIN
      NMessageDlg := E.Cmd;
      GOTO Out;
    END;
  UNTIL FALSE;
 Out:
  CloseWindow(TRUE);
 {$ELSE}
  NMessageDlg := 0;      { better safe than sorry :) }
 {$ENDIF}
{$ELSE}
  MouseOff;
  p.Len := 0;
  AddStr(@p, Text);
  nlines := CountLines(320, @p);
  y := 240 - nlines*5 - 15;
  y2 := y + nlines*10 + 30;
  SetFillStyle(SOLIDFILL, 0);
  SetLineStyle(SolidLn, 0, 1);
  Bar(0, y, 340, y2);
  SetColor(15);
  Rectangle(0, y, 340, y2);
  SetTextStyle(0, 0, 0);
  SetTextJustify(LeftText, TopText);
  OutTextXY(10, y+2, Title);
  SetColor(7);
  OutFormatted(10, y+12, 10, 320, @p);
  x := 10;
  FOR i:=1 TO nbuttons DO BEGIN
    SetColor(7);
    OutTextXY(x, y2-12, btext[i]);
    SetColor(15);
    OutTextXY(x, y2-12, btext[i][1]);
    Inc(x, 8 * Length(btext[i])+16);
  END;
  REPEAT
    c := ReadkeyUC;
    IF c=#13 THEN c:=Upcase(btext[i][1]) ELSE
    IF c=#27 THEN c:=Upcase(btext[nbuttons][1]);
    FOR i:=1 TO nbuttons DO IF c=Upcase(btext[i][1]) THEN BEGIN
      RedrawScreen;
      NMessageDlg := i;
      MouseOn;
      Exit;
    END;
  UNTIL FALSE;
{$ENDIF}
END;

{ Yes/No Dialog Shortcut }
FUNCTION NYesNo(CONST Text:STRING; Title:MStr63):BOOLEAN;
BEGIN
  NYesNo := NMessageDlg(Text, Title, 'Yes No') = 1;
END;

{ Yes/No/Cancel Dialog Shortcut }
FUNCTION NYesNoCancel(CONST Text:STRING; Title:MStr63):INTEGER;
BEGIN
  NYesNoCancel := NMessageDlg(Text, Title, 'Yes No Cancel');
END;

{ Report memory shortage }
PROCEDURE NMemError;
BEGIN
  NMessageBox(Outofmemory,Leerstring);
  Error:=TRUE;
END;

{ Report a warning. Supresses duplicate warnings. }
PROCEDURE Warning(CONST S:STRING);
BEGIN
  IF S=LastWarn THEN Exit;
  NMessageBox(S,'Warning');
  LastWarn:=S;
END;

END.
