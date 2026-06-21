{
*******************************************************************
* SCREEN.PAS - Main Part - Screen Output
*
* $Id: screen.pas,v 1.68 2013/12/29 06:41:03 sfplanets Exp $
*
*
*******************************************************************
}

{$I switches.inc}
Unit    Screen;
{$V-}

{$A-}

Interface

uses ptcgraph,AuxF,StrF,Mouse,VPAData,Ini,VPA2;

const
        cPInfo  : byte  = LightGreen;   { the order is used in CONFIG }
        cOPInfo : byte  = Green;
        cBInfo  : byte  = LightBlue;
        cSInfo  : byte  = Cyan;
        cIInfo  : byte  = Green;
        cWInfo  : byte  = Magenta;
        cUInfo  : byte  = Magenta;
        cmPNeut : byte  = White;
        cmIWeak : byte  = Green;
        cmIMod  : byte  = Yellow;
        cmIDang : byte  = Red;
        cmWorm  : byte  = LightRed;
        cmRoute : byte  = Magenta;
        cmTow   : byte  = Yellow;
        cmTrace : byte  = Magenta;
        cmDist  : byte  = Brown;
        cMsg    : byte  = Cyan;
        cMsgHL1 : byte  = Yellow;
        cMsgHL2 : byte  = White;
        cMsgHL3 : byte  = LightMagenta;
        cMsgKilled : byte = DarkGray;
        cActive : byte  = White;
        cNonActive : byte = DarkGray;
var
        cColors : array [0..1] of byte absolute cPInfo; { starting from kcPInfo }

type
        ColorType       = (_P_,_B_,_S_,_M_);
        ColorProf       = array [ColorType] of byte;
var
        RaceColor       : array [0..12] of ColorProf;

const
        AutoScroll      : boolean = On;
        StickyMouse     : boolean = On;
        LargePlanets    : boolean = On;
        PlanetNames     : boolean = On;
        UseSmallFont    : boolean = On;
        ScreenSaverTime : longint = 5*60*18;
        BadVideoOrMouse : boolean = No;
        AutoUseGravity  : boolean = No;
        DullMissions    : boolean = No;
        ShowFinalHappy  : boolean = No;
        AltWormholes    : boolean = No;
        ShowMaxPop      : boolean = No;
        ShowCombatStrength : boolean = No;
        ShowMineTrack   : boolean = No; { for Future use: Show previous size of minefield }
        CrossPointer    : PointerShape =
                        ( ($FEFF,$FEFF,$FEFF,$FEFF,$FEFF,$FEFF,$FFFF,$0381,
                           $FFFF,$FEFF,$FEFF,$FEFF,$FEFF,$FEFF,$FEFF,$FFFF),
                          ($100,$100,$100,$100,$100,$100,0,$FC7E,
                           0,$100,$100,$100,$100,$100,$100,0) );
        GrMode  : boolean = No;
        GrMode0 : byte = 3;
        TextAttr: word = White;         { word, not byte! hi byte = 0 }
        MX0     = 496;
        MapX0   : int = 1000;           { UL corner of the map }
        MapY0   : int = 3000;
        MapSize : int = 2000;
        MapSSize: int = 479;            { full map size in screen pixels }
        MapWrap : boolean = No;
        ExplMap : boolean = No;
        NRatios = 6;
        PNRatio = 3;            { first ratio when planet names are shown }
        GWRatio = 4;            { first ratio when Gravity Wells are shown }
        Ratios  : array [1..NRatios,1..2] of int =
                ( (2000,479),(2,1),(1,1),(1,2),(1,4),(1,16));
(* The following variables have to be in the same order as in VPAScr! *)
(* I think I should rewrite this with a record - bbu *)
        ratioN  : byte = 1;
        x0      : int = 0;
        y0      : int = 0;
        showS   : boolean = Yes;
        showE   : boolean = Yes;
        showM   : boolean = Yes;
        showI   : boolean = Yes;
        showU   : boolean = Yes;
        showA   : boolean = Yes;
        showT   : boolean = No;
        showP   : boolean = Yes;
        showG   : boolean = No;
        showL   : boolean = No;         {ExtFeat: connections between planets}
        showX   : boolean = No;         {Show Minefield-Explosions}
        showC   : boolean = No;         {Show clock}
        showF   : boolean = No;         {Show Forecasts}
        showY   : byte = 0;             {Show Planet Ynfos}
        showW   : byte = 0;             {Show Warp-circles}
        showN   : boolean = No;
        showV   : boolean = No;         {Show View Teleport}
        showR3  : boolean = No;
        showR4  : boolean = No;
        showR5  : boolean = No;
(* till here *)
        NShows  = 16;                   { number of show flags on screen }
        NShowmax= 20;                   { number of show flags in VPAScr }
type
        VPAScr  = record
                        ratioN  : byte;
                        x0,y0   : int;
                        showS ,showE ,showM ,showI,
                        showU ,showA ,showT ,showP,
                        showG ,showL ,showX ,showC,  {ExtFeat: added showL}
                        showF, showY, showW ,showN,
                        showV                       : byte;
                        res3,res4,res5              : boolean; 
                        
                        { res*: reserved values, remove one for every 
                           new show* to keep size of VPAScr constant }
                        force   : int;
        end;
const
        VPASCR_Size     = SizeOf(VPAScr)*11;
        GetStrPwdChar   : char = #0;
        GetStr1stKey    : byte = 0;
        DefaultHilite   = 8;
        MenuHiliteColor : byte = DefaultHilite;
        mEvent          : word = 0;
        mdraw           : boolean = No;
        ch              : word = 0;
        ForceKey        : word = 0;
        helpscr         : int = 0;
        HelpName        : string[79] = 'VPA.HLP';
        ResName         : string[79] = 'RESOURCE.PLN';
        FontName        : string[79] = '';
        glx             : int = 0;
        gly             : int = 0;
        VPASCR_INI      : string[12] = '';

const
        gmVesa640x480x256 = 3;

type
        menutext        = string[50];

var
        MenuValue       : int;
        MenuString      : menutext;
        MenuKey         : word;
        MenuData        : long;
        MenuData2       : int;
        BrownC          : pointer;
        Cross0          : pointer;
        ratio1,ratio2   : int;
        cx0,cy0         : int;
        mmx,mmy         : int;
        lx,ly           : int;
        GetStrKey       : byte;
        helpfile        : file;
        ScreenPos       : array [1..10] of VPAScr;
        LastActivityTime: longint;
        LastClockTime   : longint;
        OldX,OldY       : integer;

procedure EGAVGADriverProc;
procedure SmallFontProc;
procedure CloseGraphics;
procedure WaitRetrace;
procedure WriteXY (x,y:byte; s:string);
procedure WriteXYAttr (x,y:byte; var s:string);
procedure MakeNumDots(x,y,c:int;num:long);
procedure MouseMotionHandler;
procedure MouseHandler;
procedure MouseOff;
procedure MouseOn;
procedure ResetMouse;
procedure MoveMouseTo (x,y:int);
procedure Clear (x1,y1,x2,y2:int);
function  GetStr (x,y:int; l:byte) : str40;
function  GetStrMore (x,y:int; l:byte; ss:str40) : str40;
procedure NewMenu;
procedure SaveMenu (var m:pointer);
procedure RestoreMenu (m:pointer);
function  MenuSize (x,y,x2:word; h:byte; SaveScr:boolean) : word;
procedure AddMenuItem (t:menutext; color:byte; sort:boolean);
procedure ChooseMenu (x,y,x1,x2:word; h,c,c1,v0:byte; AskVal,SaveScr:boolean; hlp:int);
procedure ArrowBlink (x,y:int);
procedure WriteTurn (turn:word);
procedure WriteShows;
procedure WriteFreeMem;
procedure InitRatios;
procedure WrapXY (var x,y:int);
procedure WrapWayPoint (x,y:int; var mx,my:int);
procedure Scr2Abs (sx,sy:int; var ax,ay:int);
function  Abs2Scr (ax,ay:int; var sx,sy:int) : boolean;
function  EnterHull (x,y,ha0:int; restore: boolean) : int;
function  EnterEngine (x,y,ha0:int; restore: boolean) : int;
function  EnterBeam (x,y,ha0:int; restore: boolean) : int;
function  EnterTorp (x,y,ha0:int; restore: boolean) : int;
procedure DrawHelpPrompt;
procedure DrawRightScreen;
procedure ClearInfo;
procedure PressAnyKey;
function  YesNo : boolean;
procedure Help;
procedure WriteFCode (x,y:int; c:byte; fc:fcstr);
procedure WriteCoord;
procedure WriteHChange (nat:boolean);
procedure WriteMaxPop(cpos:integer;cdiff:longint);
procedure WritePlanCombatStrength(n:integer);
procedure SayFuel;
procedure DrawGravityWell(x,y:int);
procedure DrawGravityWellEnv(x,y:int);
procedure LoadAlternateFont;
procedure ShowClock;
{$IFDEF VPACC}
procedure DisplayHullfuncs(const qr:THullFuncQueryResult; build:boolean; highpl,highlvl:int);
{$ENDIF}

Implementation

uses    Keyboard,VHLP,dos
{$IFDEF VPACC},
        Hullfunc
{$ENDIF};

{ MaxAvail/MemAvail no existen en FPC/Linux. En Linux la memoria es amplia:
  devolvemos un valor grande para que las comprobaciones de memoria pasen. }
function MaxAvail: longint; begin MaxAvail := $7FFFFFFF; end;
function MemAvail: longint; begin MemAvail := $7FFFFFFF; end;


Type
        Font16 = Array [char,0..15] of byte;

        iptr    = ^item;
        item    = record
                        next    : iptr;
                        n               : int;
                        c               : byte;
                        text    : menutext;
                  end;

const
        Menu    : iptr = nil;
        baColor = Yellow;
        baDelay = 7;
        tic     : byte = 1;
        bac     : byte = baColor;
        VGABuf  : pointer = nil;

var
        ti0     : long;

procedure EGAVGADriverProc; begin end;   { stub: ptcgraph no usa drivers .bgi }

{.Procedure rusfont; External;}
{.$L rusfont}

{$I rusfont.inc}

const
        ourFont : ^Font16 = @StandardFont;

procedure SmallFontProc; begin end;      { stub: fuente bitmap via ourFont }

procedure CloseGraphics;
  begin
    DisableMouse;
{$IFDEF DPMI}
    DeAllocateStatusBuffer;
{$ENDIF}
    if GrMode then
    begin
          CloseGraph;
      { la restauracion del modo de video la gestiona CloseGraph en Linux }
      GrMode:=No;
    end;
  end;

procedure WaitRetrace;
  begin
    { ptcgraph gestiona la sincronia; no-op en Linux }
  end;

procedure WriteChar (x,y:byte; attr:integer; c:char);
  var s:string;
  begin s := c; SetColor(attr and $0F); OutTextXY(x*8, y*8, s); end;

procedure WriteXY (x,y:byte; s:string);
  var curchar, currow, row, bit : byte;  sx, sy : word;
  begin
    sx := x * 8;  sy := y * 16;
    SetFillStyle(SolidFill, black);
    Bar(sx, sy, sx + Length(s)*8, sy+15);
    for curchar := 1 to Length(s) do
      if s[curchar] <= ' ' then inc(sx, 8)
      else begin
        for currow := 0 to 15 do begin
          row := ourFont^[s[curchar]][currow];
          if row <> 0 then begin
            for bit := 0 to 7 do begin
              if (row and $80) <> 0 then PutPixel(sx, sy, TextAttr);
              inc(sx);  row := byte(row shl 1);
            end;
            dec(sx, 8);
          end;
          inc(sy);
        end;
        dec(sy, 16);  inc(sx, 8);
      end;
  end;

procedure WriteXYAttr (x,y:byte; var s:string);
  var curchar, currow, row, bit : byte;  sx, sy, color : word;
  begin
    sx := x * 8;  sy := y * 16;
    SetFillStyle(SolidFill, black);
    Bar(sx, sy, sx + (Length(s) shr 1)*8, sy+15);
    curchar := 1;
    while curchar <= Length(s) do begin
      if s[curchar] <= ' ' then begin inc(sx, 8); inc(curchar, 2); Continue; end;
      color := ord(s[curchar+1]);
      for currow := 0 to 15 do begin
        row := ourFont^[s[curchar]][currow];
        if row <> 0 then begin
          for bit := 0 to 7 do begin
            if (row and $80) <> 0 then PutPixel(sx, sy, color);
            inc(sx);  row := byte(row shl 1);
          end;
          dec(sx, 8);
        end;
        inc(sy);
      end;
      dec(sy, 16);  inc(sx, 8);  inc(curchar, 2);
    end;
  end;

procedure MakeNumDots(x,y,c:int;num:long);
  var s:string; l:byte absolute s;
  begin  Str(num,s);
    if l>3 then PutPixel(x+(l-3)*8-1,y+7,c);
    if l>6 then PutPixel(x+(l-6)*8-1,y+7,c);
  end;

procedure MouseHandler;
  begin mEvent := MouseEvent; end;

procedure MouseMotionHandler;
begin
        mEvent := MouseEvent;
        if mdraw then
        begin
          if MouseX<7 then MouseX:=7;
          if MouseX>472 then MouseX:=472;
          if MouseY<7 then MouseY:=7;
          cx0:=MouseX-7;
          cy0:=MouseY-7;
          PutImage(oldX-7,oldY-7,Cross0^,NormalPut);
          GetImage(cx0,cy0,cx0+14,cy0+14,Cross0^);
          SetColor(White);
          SetLineStyle(SolidLn,0,NormWidth);
          Line(cx0,MouseY,MouseX-2,MouseY);
          Line(MouseX+2,MouseY,MouseX+7,MouseY);
          Line(MouseX,cy0,MouseX,MouseY-2);
          Line(MouseX,MouseY+2,MouseX,MouseY+7);
          oldX := MouseX; oldY := MouseY;
        end;
end;

procedure MouseOff;
begin
        if not mdraw then Exit;
        if MousePresent then
                if useSVGA then
                        PutImage(oldX-7,oldY-7,Cross0^,NormalPut)
                else
                        HideMouse
        else
                PutImage(cx0,cy0,Cross0^,NormalPut);
        mdraw:=No;
end;

procedure MouseOn;
begin
        if mdraw then Exit;
        if MousePresent AND not useSVGA then
                ShowMouse
        else
        begin
        cx0:=Max(0,MouseX-7);
        cy0:=Max(0,MouseY-7);
        OldX := MouseX;
        OldY := MouseY;
        GetImage(cx0,cy0,cx0+14,cy0+14,Cross0^);
        SetColor(White);
        SetLineStyle(SolidLn,0,NormWidth);
        Line(MouseX-7,MouseY,MouseX-2,MouseY);
        Line(MouseX+2,MouseY,MouseX+7,MouseY);
        Line(MouseX,MouseY-7,MouseX,MouseY-2);
        Line(MouseX,MouseY+2,MouseX,MouseY+7);
        end;
        mdraw:=Yes;
end;

procedure ResetMouse;
  begin
    if MousePresent then
    begin
      RestoreMouseStatus;
          if useSVGA then
        HideMouse
      else
        SetPointerShape(CrossPointer,7,7);
      MoveMouse(MouseX,MouseY);
    end;
  end;

procedure MoveMouseTo (x,y:int);
  begin
        MouseOff;
        MoveMouse(x,y); 
        MouseOn;
  end;

procedure NewMenu;
  var   i       : iptr;
  begin
    while Menu<>nil do
      begin i:=Menu; Menu:=Menu^.next; Dispose(i) end;
  end;

procedure SaveMenu (var m:pointer);
  begin
    m:=Menu;
    Menu:=nil;
  end;

procedure RestoreMenu (m:pointer);
  begin
    Menu:=m;
  end;

function MenuSize (x,y,x2:word; h:byte; SaveScr:boolean) : word;
                { x,y,x2,h are the same as in ChooseMenu }
  var   ms      : word;
  begin
    ms:=h*SizeOf(item);
    if SaveScr then inc(ms,ImageSize(x-8,y-8,x2+7,y+h*8+7));
    MenuSize:=ms;
  end;

procedure AddMenuItem (t:menutext; color:byte; sort:boolean);
  var   i,i1    : iptr;
        lt      : byte absolute t;
  begin
    if MaxAvail<SizeOf(item) then Exit;
    New(i);
    if (lt>1) and (Copy(t,lt-1,2)=' 0') then dec(lt);
    i^.c:=color;
    i^.text:=t;
    i1:=Menu;
    if sort then
      while (i1<>nil) and (i^.text<i1^.text) do i1:=i1^.next;
    i^.next:=i1;
    if i1=nil then i^.n:=1 else i^.n:=i1^.n+1;
    if sort then
    begin
      i1:=Menu;
      while (i1<>nil) and (i1^.n>=i^.n) do
      begin
        inc(i1^.n);
        if i1^.n=i^.n+1 then begin i1^.next:=i; Break end;
        i1:=i1^.next;
      end;
    end;
    if i^.next=Menu then Menu:=i;
  end;

function FindItem (n:byte) : iptr;
  var   i       : iptr;
  begin
    i:=Menu;
    while (i<>nil) and (i^.n<>n) do i:=i^.next;
    FindItem:=i;
  end;

Procedure CenterPlanetID(var n:int);
  var   xx2,yy2,pla2 : int;
        i        : iptr;
  begin
    i:=FindItem(n);
    if i=nil then Exit;
    pla2:=0;
    val(copy(i^.text,2,3),pla2,xx2);
    if (xx2=0) and (pla2>0) and (pla2<501) then begin
      GetObjectCoord(pla2 or LockP,xx2,yy2);      
      CenterMap(xx2,yy2,yes);
    end;
  end;
    
procedure ChooseMenu (x,y,x1,x2:word; h,c,c1,v0:byte; AskVal,SaveScr:boolean; hlp:int);
  {     (x,y)   - coordinates of the menu bar UL corner
        (x2,y)  - coordinates of the menu bar UR corner (rightmost pixel)
                  image is saved 8 pixels around the menu bar
                  rectangle is drawn 3 pixels around the menu bar
        x1      - x coordinate where items are displayed
        h       - number of items in the menu bar
        c       - rectangle color
        c1      - highlighted text color
        hlp     - call help page number on F1
  }
  var   is      : word;
        p       : pointer;
        top     : byte;
        hei     : byte;
        ilen    : byte;
        s       : string[5];
        ls      : byte absolute s;
        xx,yy   : integer;
        ch_     : integer;
        pla     : integer;
        i,i0    : iptr;
        lm      : byte absolute MenuString;
        inp     : menutext;
  procedure ReDraw;
    var k       : byte;
        i       : iptr;
    begin
      Clear(x1-2,y,x2+2,y+h*8-1);
      i:=FindItem(top+hei-1);
      for k:=Min(h,Menu^.n) downto 1 do
      begin
        SetColor(i^.c);
        OutTextXY(x1,y+(i^.n-top)*8,Copy(i^.text,1,ilen));
        i:=i^.next;
      end;
    end;
  procedure Draw (hilite:boolean);
    var i       : iptr;
        yy      : int;
    begin
      i:=FindItem(MenuValue);
      if i=nil then Exit;
      MenuString:=i^.text;
      yy:=y+(i^.n-top)*8;
      SetFillStyle(SolidFill,IIF(hilite,MenuHiliteColor,0));
      Bar(x1-2,yy,x2+2,yy+7);
      SetColor(IIF(hilite,c1,i^.c));
      OutTextXY(x1,yy,Copy(i^.text,1,ilen));
    end;
  function InputVal (x:int; s1:char) : long;
    var iv      : long;
    begin
      yy:=y+(MenuValue-top)*8;
      {Clear(x,yy,x+4*8-1,yy+7);}
      SetColor(c);
      OutTextXY(x,yy,s1);
      s:=GetStr(x+8,yy,5);
      if ls=0 then MenuKey:=27
              else begin Val(s,iv,x); if x<>0 then MenuKey:=27 end;
      if MenuKey=27 then iv:=-1;
      InputVal:=iv;
    end;
  begin
    if Menu=nil then Exit;
    if FindItem(v0)=nil then v0:=1;
    if SaveScr then
    begin
      is:=ImageSize(x-8,y-8,x2+7,y+h*8+7);
      if MaxAvail<is then SaveScr:=No
      else begin
        GetMem(p,is);
        GetImage(x-8,y-8,x2+7,y+h*8+7,p^);
      end;
    end;
    MenuValue:=v0; MenuData:=0;
    top:=Max(v0-h+1,1);
    hei:=Min(h,Menu^.n);
    ilen:=(x2-x1+1) div 8; inp:='';
   repeat
    Clear(x-8,y-8,x2+7,y-1);
    Clear(x1,y,x2+7,y+7);
    Clear(x-8,y+8,x2+7,y+h*8+7);
    SetColor(c); SetLineStyle(SolidLn,0,NormWidth);
    Rectangle(x-3,y-3,x2+3,y+h*8+2);
    ReDraw;
    repeat
      Draw(Yes);
      MenuKey:=ReadKey;
      Draw(No);
      case MenuKey of
{up}    $4800   : if MenuValue>1 then
                  begin
                    dec(MenuValue);
                    if MenuValue<top then
                      begin dec(top); ReDraw end;
                  end;
{down}  $5000   : if MenuValue<Menu^.n then
                  begin
                    inc(MenuValue);
                    if MenuValue>=top+hei then
                      begin inc(top); ReDraw end;
                  end;
{pgup}  $4900   : if (MenuValue=top) then begin
                    MenuValue:=Max(1,MenuValue-hei+1);
                    if MenuValue<top then
                      begin top:=MenuValue; ReDraw end;
                  end else MenuValue:=top;
{pgdn}  $5100   : if (MenuValue=top+hei-1) then begin
                    MenuValue:=Min(Menu^.n,MenuValue+hei-1);
                    if MenuValue>=top+hei then
                      begin top:=MenuValue-hei+1; ReDraw end;
                  end else MenuValue:=top+hei-1;
{home}  $4700   : begin MenuValue:=1; if MenuValue<top then 
                    begin top:=1; ReDraw end;
                  end;
{end}   $4F00   : begin MenuValue:=Menu^.n; if MenuValue>=top+hei then 
                    begin top:=Menu^.n-hei+1; ReDraw end;
                  end;
{tab}   9       : if (hlp=-2) then Zoom(1);
{_tab}  $0F00   : if (hlp=-2) then Zoom(255);
{^tab}  $9400   : if (hlp=-2) then Zoom(0); 
{space} ord(' '): if (hlp=-2) then CenterPlanetID(MenuValue);               
{f1}    $3B00   : begin   
                    if (hlp>=0) then begin
                      helpscr:=hlp; {MyMax - Most common mistakes}
                      ch_ := ch;
                      Help;
                      ch := ch_;
                      helpscr:=0;
                      drawmap(yes);
                    end;
                  end;
      end;      
      if (Length(inp)=0) and (MenuKey IN [ord('a')..ord('z')]) then begin
        i0:=FindItem(MenuValue);
        if i0=nil then i0:=Menu;
        i:=i0^.next;
        if i=nil then i:=Menu;
        if i<>nil then
        while ((byte(i^.text[0])=0) or (UChr[byte(i^.text[1])]<>UChr[MenuKey])) do
        begin
          i:=i^.next;
          if i=nil then i:=Menu;
          if i=i0 then Break;
        end;
        if i<>i0 then
        begin
          MenuValue:=i^.n;
          top:=Max(MenuValue-h+1,1);
          ReDraw;
        end;
      end else if (Length(inp)=0) and (MenuKey in [ord('0')..ord('9')]) then begin
        if (MenuKey=ord('0')) then MenuValue:=Min(Menu^.n,top+10)
        else MenuValue:=Min(Menu^.n,top+(MenuKey-Ord('1')));
        if (MenuValue>=top+hei) then begin top:=MenuValue-hei+1; ReDraw end;
      end else if (MenuKey IN [ord('a')..ord('z'), ord('A')..ord('Z'), 
                   ord('0')..ord('9'),ord(' '), ord('-'), ord('.')]) then begin
        if Menu<>nil then begin
          inp:=inp+Chr(MenuKey);
          i:=Menu;
          while (i<>nil) and not StrCmp(i^.text,inp,length(inp)) do i:=i^.next;
          if (i<>nil) then while (i^.next<>nil) and StrCmp(i^.next^.text,inp,length(inp))
            do i:=i^.next;
          if (i<>nil) then begin
            MenuValue:=i^.n;
            if (MenuValue<top) or (MenuValue>=top+hei) then
              begin  top:=Min(MenuValue,Menu^.n-hei+1); ReDraw;  end;
          end;
        end;
      end else inp:='';
      i:=FindItem(MenuValue);
      while (i<>nil) and (ITrim(i^.text)='') and (MenuValue>1) and (MenuValue<Menu^.n) do begin
        if (MenuKey=$4800) or (MenuKey=$4900) then dec(MenuValue)
        else inc(MenuValue);
        i:=FindItem(MenuValue);
      end;
    until (MenuKey=27) or (MenuKey=13) or (MenuKey=$3B00);
   until (MenuKey<>$3B00);
    if lm=0 then MenuKey:=27;
    if (MenuKey=13) then 
      if AskVal then begin
        while (lm>0) and (MenuString[lm] in ['0'..'9']) do dec(lm);
        if MenuString[lm]=' ' then MenuData:=InputVal(x1+lm*8-8,' ');
{       case MenuString[lm] of
          ' '     : MenuData:=InputVal(x1+lm*8-8,' ');
          '*'     : MenuData:=InputVal(x,'I');
          '#'     : MenuData2:=InputVal(x,'T');
          '/'     : begin MenuData:=InputVal(x,'I');
                          Clear(x,yy,x+4*8-1,yy+7);
                          if MenuKey<>27 then MenuData2:=InputVal(x,'T')  end;
        end;}
      end else MenuString:=FindItem(MenuValue)^.text;
    if SaveScr then
    begin
      PutImage(x-8,y-8,p^,NormalPut);
      FreeMem(p,is);
    end;
  end;

procedure Clear (x1,y1,x2,y2:int);
  begin
    SetFillStyle(SolidFill,Black);
    Bar(x1,y1,x2,y2);
  end;

function GetStr (x,y:int; l:byte) : str40;
  var   s       : str40;
        ls      : byte absolute s;
        ch      : byte;
        cur     : boolean;
        t0      : long;
        first   : boolean;
  procedure DrawCursor;
    begin
      SetWriteMode(XORPut);
      SetColor(White);
      Line(x+ls*8,y+8,x+ls*8+7,y+8);
      SetWriteMode(NormalPut);
      cur:=not cur;
    end;
  begin
    SetLineStyle(SolidLn,0,NormWidth);
    ls:=0; ch:=0; first:=Yes;
    repeat
      if GetStr1stKey=0 then
      begin
        cur:=Off; t0:=Timer;
        while not KeyPressed do
          if Timer>t0+1 then begin DrawCursor; t0:=Timer end;
        if cur then DrawCursor;
        ch:=ReadKey;
      end
      else begin ch:=GetStr1stKey; GetStr1stKey:=0 end;
      if ch in [8,32..175,224..239] then
      begin
        if first then begin Clear(x,y,x+l*8-1,y+7); first:=No end;
        if (ch=8) or (ch=127) then
        begin
          if ls>0 then
          begin
            SetColor(Black);
            OutTextXY(x+ls*8-8,y,'Û');
            dec(ls);
          end
        end
        else if ls<l then
        begin
          SetColor(White);
          OutTextXY(x+ls*8,y,char(IIF(GetStrPwdChar=#0,ch,byte(GetStrPwdChar))));
          s:=s+char(ch);
        end;
      end;
    until (ch=13) or (ch=27) or ((l=1) and (ls=1));
    if ch=27 then begin Clear(x,y,x+l*8-1,y+7); ls:=0 end;
    GetStr:=s;
    GetStrKey:=ch;
  end;

function GetStrMore (x,y:int; l:byte; ss:str40) : str40;
  var   s       : str40;
        ls      : byte absolute s;
        ch      : byte;
        cur     : boolean;
        t0      : long;
        first   : boolean;
        i       : byte;
  procedure DrawCursor; 
    begin
      SetWriteMode(XORPut);
      SetColor(White);
      Line(x+ls*8,y+8,x+ls*8+7,y+8);
      SetWriteMode(NormalPut);
      cur:=not cur;
    end;
  begin
    SetLineStyle(SolidLn,0,NormWidth);
    ls:=0; ch:=0; first:=Yes;
    
    if (length(ss)>0) then
    begin
      first := No;
    {  s    := ss;}
      i :=1;
      while (i <=  length(ss)) do begin
       s := s + ss[i];
       SetColor(White);
       OutTextXY(x+(ls-1)*8,y,char(IIF(GetStrPwdChar=#0,byte(ss[ls]),byte(GetStrPwdChar))));
       inc(i);
      end;
    end;
    
    repeat
      if GetStr1stKey=0 then
      begin
        cur:=Off; t0:=Timer;
        while not KeyPressed do
          if Timer>t0+1 then begin DrawCursor; t0:=Timer end;
        if cur then DrawCursor;
        ch:=ReadKey;
      end
      else begin ch:=GetStr1stKey; GetStr1stKey:=0 end;
      if ch in [8,32..175,224..239] then
      begin
        if first then begin Clear(x,y,x+l*8-1,y+7); first:=No end;
        if (ch=8) or (ch=127) then
        begin
          if ls>0 then
          begin
            SetColor(Black);
            OutTextXY(x+ls*8-8,y,'Û');
            dec(ls);
          end
        end
        else if ls<l then
        begin
          SetColor(White);
          OutTextXY(x+ls*8,y,char(IIF(GetStrPwdChar=#0,ch,byte(GetStrPwdChar))));
          s:=s+char(ch);
        end;


      end;
    until (ch=13) or (ch=27) or ((l=1) and (ls=1));
    if ch=27 then begin Clear(x,y,x+l*8-1,y+7); ls:=0 end;
    GetStrMore:=s;
    GetStrKey:=ch;
  end;

procedure ArrowBlink (x,y:int);
  begin
    if Timer<>ti0 then
    begin
      dec(tic);
      if tic=0 then
      begin
        tic:=baDelay;
        SetColor(bac);
        OutTextXY(x,y,#27);
        bac:=bac xor baColor;
        SetColor(bac);
        OutTextXY(x+8,y,#26);
      end;
      ti0:=Timer;
    end;
  end;
  
procedure WriteTurn (turn:word);
  var   s       : string[3];
  begin
    Clear(MX0+40,40,MX0+63,47);
    SetColor(LightGray);
    Str(turn,s);
    OutTextXY(MX0,40,'turn '+s);
  end;

procedure WriteShows;
  begin
    SetColor(IIF(showE,White,DarkGray));
    OutTextXY(568,0,'E');
    SetColor(IIF(showS,White,DarkGray));
    OutTextXY(576,0,'S');
    SetColor(IIF(showT,White,DarkGray));
    OutTextXY(584,0,'T');
    SetColor(IIF(showM,White,DarkGray));
    OutTextXY(592,0,'M');
    SetColor(IIF(showI,White,DarkGray));
    OutTextXY(600,0,'I');
    SetColor(IIF(showU,White,DarkGray));
    OutTextXY(608,0,'U');
    SetColor(IIF(showA,White,DarkGray));
    OutTextXY(616,0,'A');
    SetColor(IIF(showP,White,DarkGray));
    OutTextXY(624,0,'P');
    SetColor(IIF(showG,White,DarkGray));
    OutTextXY(632,0,'G');
    {ExtFeat: added showL}
    SetColor(IIF(showL,White,DarkGray));
    OutTextXY(632,8,'L');
    SetColor(IIF(showX,White,DarkGray));
    OutTextXY(624,8,'X');
    SetColor(IIF(showC,White,DarkGray));
    OutTextXY(616,8,'C');
    SetColor(IIF(showW>0,White,DarkGray));
    OutTextXY(608,8,'W');
    SetColor(IIF(showF,White,DarkGray));
    OutTextXY(600,8,'F');
    SetColor(IIF(showY>0,White,DarkGray));
    OutTextXY(592,8,'Y');
    SetColor(IIF(showN,White,DarkGray));
    OutTextXY(584,8,'N');		
    if Addon.teleport then begin 
      SetColor(IIF(showV,White,DarkGray));
      OutTextXY(640-((NShows-8)*8),8,'V');
    end;
 end;

procedure WriteFreeMem;
  begin
    Clear(MX0-13,0,MX0-13+10*8-1,7);
    SetColor(LightGray);
    if (MemAvail div (1024*1024)> 9) then
      OutTextXY(MX0-13,0,NStr0(MemAvail div (1024*1024))+'M free')
    else
      OutTextXY(MX0-13,0,NStr0(MemAvail div 1024)+'K free');
  end;

procedure InitRatios;
  begin
    ratio1:=Ratios[ratioN,1];
    ratio2:=Ratios[ratioN,2];
    MapSSize:=long(MapSize)*ratio2 div ratio1;
  end;

procedure WrapXY (var x,y:int);
  begin
    if (Phost)and( (PHOSTver[1]=char(51))and(PHOSTver[3]=char(51))and(PHOSTver[4]>=char(99)) 
    or (PHOSTver[1]>char(51)) or ((PHOSTver[1]=char(51))and(PHOSTver[3]>char(51)))
    ) then begin
     if x<MapX0 then inc(x,MapSize);
     if x>=MapX0+MapSize then dec(x,MapSize);
     if y>=MapY0 then dec(y,MapSize);
     if y<MapY0-MapSize then inc(y,MapSize);
    end
    else
    begin
     if x<MapX0 then inc(x,MapSize);
     if x>MapX0+MapSize then dec(x,MapSize);
     if y>MapY0 then dec(y,MapSize);
     if y<MapY0-MapSize then inc(y,MapSize);
    end

  end;
procedure WrapWayPoint (x,y:int; var mx,my:int);
  var   x1,y1,x2,y2     : int;
  begin
    Abs2Scr(x,y,x1,y1);
    Abs2Scr(mx,my,x2,y2);
    if Sign(x-mx)<>Sign(x1-x2) then inc(mx,MapSize*Sign(x2-x1));
    if Sign(y-my)<>Sign(y2-y1) then inc(my,MapSize*Sign(y1-y2));
  end;

procedure Scr2Abs (sx,sy:int; var ax,ay:int);
  var   x,y     : long;
  begin
    x:=sx; y:=sy;
    ax:=(x+x0)*ratio1 div ratio2+MapX0;
    ay:=MapY0-(y+y0)*ratio1 div ratio2;
    if MapWrap then WrapXY(ax,ay);
  end;

function Abs2Scr (ax,ay:int; var sx,sy:int) : boolean;  { on the screen? Y/N }
  var   x,y     : long;
        t       : int;
  begin
    x:=ax; y:=ay;
    sx:=(x-MapX0)*ratio2 div ratio1-x0;
    sy:=(MapY0-y)*ratio2 div ratio1-y0;
    if MapWrap then
    begin
      if (sx<0) or (sx>479) then
      begin
        t:=sx-MapSSize*Sign(sx);
        if Abs(t-240)<Abs(sx-240) then sx:=t;
      end;
      if (sy<0) or (sy>479) then
      begin
        t:=sy-MapSSize*Sign(sy);
        if Abs(t-240)<Abs(sy-240) then sy:=t;
      end;
    end;
    Abs2Scr:=(sx>=0) and (sx<=479) and (sy>=0) and (sy<=479);
  end;

function EnterHull (x,y,ha0:int; restore: boolean) : int;
  var   i       : int;
  begin
    NewMenu;
    if restore then UnLockReservedMemory(MenuSize(x,y,x+18*8,10,Yes));
    for i:=1 to 105 do AddMenuItem(Hulls[i].name,White,Yes);
    ChooseMenu(x,y,x,x+18*8,10,White,Yellow,ha0,No,restore,-1);
    if (MenuKey=13) and (MenuValue>0) and (MenuValue<=105) then begin
      for i:=1 to 105 do if Hulls[i].name=MenuString then 
        begin  EnterHull:=i; Break;  end;
    end else EnterHull:=ha0;
    NewMenu;
    if restore then LockReservedMemory;
  end;

function EnterEngine (x,y,ha0:int; restore: boolean) : int;
  const xsize=18; lines=9; cI=White; cH=Yellow; cB=White;
  var   i : int;  isres:boolean;
  begin
    NewMenu;  isres:=(ResMem<>nil);
    if restore and isres then UnLockReservedMemory(MenuSize(x,y,x+xsize*8,lines,Yes));
    for i:=1 to 9 do AddMenuItem(Engines[i].name,cI,No);
    ChooseMenu(x,y,x,x+xsize*8,lines,cB,cH,ha0,No,restore,-1);
    if (MenuKey=13) and (MenuValue>0) and (MenuValue<=9) then begin
      for i:=1 to 9 do if Engines[i].name=MenuString then 
        begin  EnterEngine:=i; Break;  end;
    end else EnterEngine:=ha0;
    NewMenu;
    if restore and isres then LockReservedMemory;
  end;

function EnterBeam (x,y,ha0:int; restore: boolean) : int;
  const xsize=15; lines=10; cI=White; cH=Yellow; cB=White;
  var   i : int;  isres:boolean;
  begin
    NewMenu;  isres:=(ResMem<>nil);
    if restore and isres then UnLockReservedMemory(MenuSize(x,y,x+xsize*8,lines,Yes));
    for i:=1 to 10 do AddMenuItem(Beams[i].name,cI,No);
    ChooseMenu(x,y,x,x+xsize*8,lines,cB,cH,ha0,No,restore,-1);
    if (MenuKey=13) and (MenuValue>0) and (MenuValue<=10) then begin
      for i:=1 to 10 do if Beams[i].name=MenuString then 
        begin  EnterBeam:=i; Break;  end;
    end else EnterBeam:=ha0;
    NewMenu;
    if restore and isres then LockReservedMemory;
  end;

function EnterTorp (x,y,ha0:int; restore: boolean) : int;
  const xsize=10; lines=10; cI=White; cH=Yellow; cB=White;
  var   i : int;  isres:boolean;
  begin
    NewMenu;  isres:=(ResMem<>nil);
    if restore and isres then UnLockReservedMemory(MenuSize(x,y,x+xsize*8,lines,Yes));
    for i:=1 to 10 do AddMenuItem(Torps[i].name,cI,No);
    ChooseMenu(x,y,x,x+xsize*8,lines,cB,cH,ha0,No,restore,-1);
    if (MenuKey=13) and (MenuValue>0) and (MenuValue<=10) then begin
      for i:=1 to 10 do if Torps[i].name=MenuString then 
        begin  EnterTorp:=i; Break;  end;
    end else EnterTorp:=ha0;
    NewMenu;
    if restore and isres then LockReservedMemory;
  end;


procedure DrawHelpPrompt;
  begin
    SetColor(LightGray);
    OutTextXY(MX0,472,'Press F1 for help');
  end;

procedure DrawRightScreen;
  begin
    Clear(480,0,639,479);
    SetLineStyle(SolidLn,0,ThickWidth);
    SetColor(DarkGray);
    Line(481,0,481,479);
    if Addon.teleport then Line(482,11,638-(NShows-8)*8,11)
    else Line(482,11,638-(NShows-9)*8,11);
    Line(482,59,639,59);
    Line(MX0-13+10*8+1,0,MX0-13+10*8+1,10);
    SetTextStyle(DefaultFont,HorizDir,1);
    SetTextJustify(LeftText,TopText);
    SetColor(Yellow);
    OutTextXY(MX0,24,pname);
    Line(MX0,33,MX0+RLen(pname)*8-2,33);
    DrawHelpPrompt;
    WriteTurn(turn);
    WriteShows;
  end;

procedure ClearInfo;
  begin
    if distlock<>0 then Clear(MX0-8,72,639,dll-2)
    else begin
      Clear(MX0-8,72,639,479);
      DrawHelpPrompt;
    end;
  end;

procedure PressAnyKey;
  begin
    while KeyPressed do ReadKey;
    Write(#13#10'Press any key to continue...');
    ReadKey;
    Writeln;
  end;

function YesNo : boolean;
  var   ch      : word;
  begin
    repeat ch:=ReadKey until (ch=ord('y')) or (ch=ord('n')) or (ch=ord('Y')) or (ch=ord('N'));
    YesNo:=( (ch=ord('y')) or (ch=ord('Y')) );
  end;

procedure Help;
  var   mx,my   : int;
        hs      : int;
        md0     : boolean;
  begin
    md0:=MouseDisabled;
    if not md0 then
    begin
      MouseOff;
      MouseDisabled:=True;
      mx:=MouseX; my:=MouseY;
    end;
    hs:=helpscr;
    if hs=0 then hs:=ltype;
    if (hs=LockP) and (lbase<>nil) then inc(hs);
    if (hs=LockM) or (hs=LockI) then hs:=0;
    ShowHelp(helpfile,hs);
    ch:=2;
    if not md0 then
    begin
      MoveMouseTo(mx,my);
      MouseDisabled:=False;
      MouseOn;
    end;
  end;

procedure WriteFCode (x,y:int; c:byte; fc:fcstr);
  var   i       : byte;
  begin
    SetColor(c);
    OutTextXY(x,y,fc);
    for i:=1 to 3 do
      if fc[i]='0' then PutPixel(x+i*8-5,y+3,c);
  end;

procedure WriteCoord;
  var   sx,sy   : string[4];
  begin
    if lock or glx or gly=0 then Scr2Abs(MouseX,MouseY,mmx,mmy)
    else if lock<>0 then begin mmx:=lx; mmy:=ly end
    else begin mmx:=glx; mmy:=gly end;
    Str(mmx:4,sx); Str(mmy:4,sy);
    SetColor(LightGray);
    Clear(MX0-13,0,MX0-13+10*8-1,7);
    OutTextXY(MX0-8,0,sx+','+sy);
  end;

procedure WriteHChange (nat:boolean);
  var   hc,hs,y : int;
        s       : string[7];
        ls      : byte absolute s;
  begin  
    y:=IIF(nat,IIF(ShowMaxPop,168,176),208);
    Str(IIF(nat,lplan^.Nstat,lplan^.Cstat),s);
    Clear(MX0+(ls+9)*8,y,639,y+7);
    if nat then hc:=NHappyChange(lock and LockLo,TRUE)
           else hc:=CHappyChange(lock and LockLo,TRUE);
    hs:=IIF(nat,lplan^.Nstat,lplan^.Cstat);
    if not ShowFinalHappy then begin                  {old way}
      SetColor(IIF(hc<0,Red,IIF((lplan^.when=turn) and (lplan^.when=lplan^.when0),LightGreen,Green)));
      hc:=Max(Min(hs+hc,100),-300)-hs;
      if (hc<>0) or ( (lplan^.owner=0) and nat) then
      begin
        Str(hc,s);
        if (hc>=0) then s:='+'+s;
        if (lplan^.owner=0) then s:='('+s+')' else s:='['+s+']';
        OutTextXY(640-ls*8,y,s);
      end;
    end else begin                         {ShowFinalHappy = On}
      hc:=Max(Min(hs+hc,100),-300);
      if (lplan^.when=turn) and (lplan^.when=lplan^.when0) then
            SetColor(IIF(hc>=70,LightGreen,IIF(hc<40,LightRed,Yellow)))
      else  SetColor(IIF(hc>=70,Green,IIF(hc<40,Red,Yellow)));
      if (nat and (lplan^.natives>0)
              and (lplan^.Ntax <>-1)
              and (lplan^.Ngovt <>-1))
         or
         ((not nat) and (lplan^.Ctax <>-1)
                    and (lplan^.mines<>-1)
                    and (lplan^.factories<>-1)
                    and (lplan^.owner<>0)) then
      begin
        Str(hc,s);
        if (lplan^.owner=0) then s:='('+s+')' else s:='{'+s+'}';
        OutTextXY(640-ls*8,y,s);
      end;
    end;
  end;

procedure WriteMaxPop(cpos:integer;cdiff:longint);
  { TODO: Move Calculation completely to CalcMaxPop }
  const nline=(17+5)*8; 
        defcline=(23+4)*8;
  var colo,ming,maxcol,maxnat,growcol,grownat,GAmin,GAmax,GA,GARem,GAOwn:long;
      dp,r,cline:integer;
      enemy:boolean;
      s:string;
  begin
    if not ShowMaxPop then Exit;
    if (lplan=NIL) then Exit;
    if (lplan^.climate<0) then Exit;    
    if (cpos>0) then cline:=cpos else cline:=defcline;
    if (lplan^.owner=0) or (lplan^.owner=player) then enemy:=false else enemy:=true;

    if not enemy then lplan^.colonists:=lplan^.colonists+cdiff;
    CalcMaxPop(lplan,colo,ming,maxcol,growcol,maxnat,grownat,GAmin,GAmax,GA,GARem);
    if not enemy then lplan^.colonists:=lplan^.colonists-cdiff;
{    with lplan^ do begin}
      if (colo=0) then r:=race[player] else r:=race[lplan^.owner];

      Clear(MX0+8,cline,639,cline+7);
 
      SetColor(Green);
      if enemy then begin
       if (lplan^.colonists>0) then begin
        {Enemy planet, show only Ground Attack Amin and Amax}
        if (lplan^.colonists>50) then dp:=50+trunc(sqrt(lplan^.colonists-50))
        else if (lplan^.colonists>0) then dp:=lplan^.colonists
        else dp:=0;
        if (cdiff<=GAMin) then SetColor(lightred)
        else if (cdiff<=GAMax) then SetColor(yellow);
        s:=''; if (GAmax>GAmin) then s:=NStr(GAmin)+'-';
        if (GAmax<10000) then
          OutTextXY(MX0+8,cline,'GC   : '+s+NStr(GAmax))
          else if (GAmin<10000) then
          OutTextXY(MX0+8,cline,'GC   : '+s+' >9999')
          else
          OutTextXY(MX0+8,cline,'GC   : >9999');
                               
        if (cpos<72) {and (ShowF)} then begin 
          SetColor(lightgreen);
          Str(iDefense:3,s);
          OutTextXY(MX0,cline+4*8,'Sim-Def. : '+s+'/'+Nstr0(dp));
          OutTextXY(MX0+14*8,cline-4*8,'Sim-');
          OutTextXY(MX0+14*8,cline-3*8,'Col.');
          OutTextXY(MX0+14*8,cline-2*8,Nstr0(iColo));

          if (GARem<0) then begin
            SetColor(lightred);
            OutTextXY(MX0+8,cline+17*8,copy(RaceName[lplan^.owner],1,3)+': '+Nstr0(minL(GARem*(-1),lplan^.colonists)));
            SetColor(green);
          end else if (GARem>0) then OutTextXY(MX0+8,cline+17*8,copy(RaceName[player],1,3)+': '+Nstr0(GARem))
          else begin
            SetColor(Yellow);
            OutTextXY(MX0+8,cline+17*8,'unowned');
            SetColor(Green);
          end;  
          OutTextXY(MX0+8+10*8,cline+17*8,'/ '+Nstr0(GA+1));
          SetColor(White);
          OutTextXY(MX0+14*8,cline-3*8,'C');
          OutTextXY(MX0+4*8,cline+4*8,'D');
        end;
       end;
      end else 
			begin
				SetColor(White);
        OutTextXY(MX0+17*8,cline-4*8,'C');
				if (iRace>0) then begin				{=0 shows nothing but Key}
					SetColor(lightred);
					OutTextXY(MX0+14*8,cline-4*8,'GA-');
					OutTextXY(MX0+14*8,cline-3*8,copy(RaceName[iRace],1,3)+':');
					Clear(MX0+14*8,cline-2*8,MX0+18*8,cline-8);
					if GAMin<10000 then OutTextXY(MX0+14*8,cline-2*8,Nstr0(GAMin))
												else OutTextXY(MX0+14*8,cline-2*8,'>10');
				end;
				SetColor(Lightgreen);
				if (colo=-3) {and (lplan^.owner=6)} then begin              {All Borgs are Disassembled Quapla}
					SetColor(Lightred); colo:=0;
					OutTextXY(MX0+16,cline,'No colos left!');
				end else if (colo<ming) and (ming<>-1) then begin
					{no or too few colonist to growcol, show min and maxcol - but not all disassembled}
					OutTextXY(MX0+16,cline,'>='+NStr(ming));
					OutTextXY(MX0+16+64,cline,'<='+NStr(maxcol));
					MakeNumDots(MX0+16+64+16,cline,Green,maxcol*100);
				end else if (colo<maxcol) then begin
					{colonist can grow, show growth and maximum in correct color}
					OutTextXY(MX0+16+64,cline,'<='+NStr(maxcol));
					MakeNumDots(MX0+16+64+16,cline,Green,maxcol*100);
					if (growcol=0) then { OutTextXY(MX0+16,cline,'no grow')}
															begin 
																
									 
															end
					else begin
						if growcol<0 then SetColor(Red);
						if (colo>0) then OutTextXY(MX0+16,cline,NSStr(growcol))
						else OutTextXY(MX0+16,cline,'('+NSStr(growcol)+')');
					end;
				end else if (colo=maxcol) and (growcol=0) then begin
					{show only "=max"}
					OutTextXY(MX0+8+56,cline,'=max');
				end else {colo>maxcol} begin
					{population exceeds maxcol, overpop die or amorphous, show death and maxcol}
					SetColor(Red);
					OutTextXY(MX0+16+64,cline,'<='+NStr(maxcol));
					MakeNumDots(MX0+16+64+16,cline,Green,maxcol*100);
					if growcol>0 then SetColor(Green);
					OutTextXY(MX0+16,cline,NSStr(growcol))
				end;
			end;

      if (cpos>0) then begin
      { Show only Colonist-Info for unloading ships }
        Exit;
      end;

      {max and growth for natives}
      Clear(MX0+8,nline,639,nline+7);
      if (maxnat>0) then begin
        SetColor(Green);
        OutTextXY(MX0+16+64,nline,'<='+NStr0(maxnat));
        MakeNumDots(MX0+16+64+16,nline,Green,maxnat*100);
        if (grownat=0) then OutTextXY(MX0+16,nline,'no grow')
        else begin
          if grownat<0 then SetColor(Red);
          if (colo>0) then OutTextXY(MX0+16,nline,NSStr(grownat))
          else OutTextXY(MX0+16,nline,'('+NSStr(grownat)+')');
        end;
      end;
{    end;}
  end;

procedure WritePlanCombatStrength(n:integer);
  const line=248;
  var p:pptr; b:bptr;
      dp:integer;
      i:integer;
  begin
    if not ShowCombatStrength then Exit;
    Clear(MX0+8,line,639,line+7);
    SetColor(Green);
    with TTurn^.data^ do
    begin
      p:=planet[n];
      b:=base[n];
    end;
    if p=nil then Exit;
    with p^ do begin
      dp:=Max(defense,0); if (b<>nil) and (b^.defense>0) then Inc(dp,b^.defense);
      if (dp>0) then begin
        i:=100+Trunc(dp);                {Battlemass:Trc(100+DP+BDP *PH)}
        OutTextXY(MX0+1*8,line,NStr(i)+'kt');
        i:=round(SQRT(dp/3));            {BeamCount:Rnd(Sqrt([DP+BDP]/3 *PH))}
        if PHost and AllowAlternativeCombat then i:=min(i,20)
        else i:=min(i,10);
        OutTextXY(MX0+IIF(i>9,7,8)*8,line,NStr(i));
        i:=1;                            {Beamtype:Rnd(Sqrt(DP/2 *PH))|BTech}
        if (b<>nil) and (b^.Wl>0) then i:=b^.Wl;
        i:=Max(i,Min(10,round(SQRT(Max(defense,0)/2))));
        OutTextXY(MX0+9*8,line,'x'+NStr(i));
      end;
      if defense>0 then begin
        i:=round(SQRT(defense));     {FghtCount: Rnd(Sqrt((DP-?0.75)*ph))}
        if (b<>nil) and (b^.fighters>0) then i:=i+b^.fighters;
        OutTextXY(MX0+IIF(i>9,13,14)*8,line,NStr(i));
        i:=defense;                      {FghtBays: Rnd/Trc(Sqrt(DP))+?5}
        if PHost then i:=round(SQRT(i)) else i:=Trunc(SQRT(i));
        if (b<>nil) then i:=i+5;
        OutTextXY(MX0+15*8,line,':'+NStr(i));
      end;
{!    PHost: Base torps??? (found in doc, but dont know... can bases fire torp?}
    end;
  end;

procedure SayFuel;
  var   i,e     : int;
        s,s1    : string[4];
  begin
    SetColor(cSInfo);
    with lship^ do
    if hull<>-1 then
    begin
      if fuel<>-1 then
      begin
        Clear(MX0,144,639,152+7);
        Str(fuel,s);
        Clear(MX0,144,639,144+7);
        OutTextXY(MX0,144,'Fuel: '+s+'/'+NStr0(Hulls[hull].fuel)+' kt');
        if (warp<>-1) and (mission<>-1) then
        begin
          CalcMovement(lship,StdTowPtr(lship^),i,e);
          s1:=NStrMax(i,4,'+'); Trim(s1);
          if i>0 then OutTextXY(MX0,152,'Burn: '+s1+' kt') else
          if i<0 then
          begin
            s1[1]:='+';
            OutTextXY(MX0,152,'Make: '+s1+' kt');
          end;
          if fuel<=i+IIF((warp>0) and (wx or wy<>0),1,0) then
          begin
            SetColor(IIF(fuel>=i,Yellow,LightRed));
            OutTextXY(MX0+6*8,144,s);
            if i>0 then OutTextXY(MX0+6*8,152,s1);
          end;
        end;
      end;
      if ((M=-1) and (mass<>-1)) then OutTextXY(MX0,152,'Ne+Crgo:'+FuelCargoMass(lship)+' kt');
      {if SRdrawn then DrawShipRange;
      DrawShipRange;}
    end;
  end;

procedure DrawGravityWellEnv (x,y:int);
  var   i,j,gr1 : int;
        gr2     : long;
  begin
    gr1 := GravityRange+1;
    gr2 := GravityRange*GravityRange;
    for i := -gr1 to gr1 do
     for j := -gr1 to gr1 do
       if not ( (RoundWells and (Distance2(x,y,x+i,y+j)<=gr2))  or
          ((not RoundWells) and (Abs(i)<gr1) and (Abs(j)<gr1))) then
        putpixel(x+i*ratio2,y+j*ratio2,DarkGray);
  end;

procedure DrawGravityWell (x,y:int);
  var   i,j,gr1 : int;
        gr2     : long;
  begin
    gr1 := GravityRange+1;
    gr2 := GravityRange*GravityRange;
    for i := -gr1 to gr1 do
     for j := -gr1 to gr1 do
       if (RoundWells and (Distance2(x,y,x+i,y+j)<=gr2)) or
          ((not RoundWells) and (Abs(i)<gr1) and (Abs(j)<gr1)) then
         putpixel(x+i*ratio2,y+j*ratio2,Blue)
  end;

procedure LoadAlternateFont;
  var f:file;
      r:word;
  begin
    if FontName='' then Exit;
    OpenFile(f,FontName,0,Yes);
    BlockRead(f, StandardFont, Sizeof(StandardFont), R);
    CloseData(f);
    if R<>Sizeof(StandardFont) then begin
      Writeln('Font file ', FontName, ' is too short.');
      Halt;
    end;
  end;

procedure ShowClock;
var h,m,s,c : word;
   s3     : string[3];
   s10      : string[10];
begin     
   GetTime(h,m,s,c);
   SetColor(LightGray);
   Str(h,s10);
   str(m,s3);
   if (m<10) then
      s10:=s10+':0'+s3
   else
      s10:=s10+':'+s3;
   Clear(640-5*8,40,640,48);
   OutTextXY(640-5*8,40,s10);
end;

{$IFDEF VPACC}
procedure DisplayHullfuncs(const qr:THullFuncQueryResult; build:boolean; highpl,highlvl:int);
const
  x0    = 20;
  y0    = 20;
  ybody = y0 + 15;
var 
  i, j                     : int;
  phf                      : PHullFunction;
  y                        : int;
  xname,wname,wplayer,wexp : int;
  xr                       : int;
  ybot                     : int;
  as                       : string[3];
const elf                  : array[0..11] of char = '0123456789AB';
begin 
  if qr.count=0 then Exit;

  xname := x0+3+3*8+4;
  wname := 40*8;
  if PHOST then wplayer:=12*8 else wplayer:=0;
  if NumExperienceLevels>0 then wexp:=NumExperienceLevels*8+16 else wexp:=0;

  ybot := ybody + qr.count*10;
  if ybot < ybody+10*10 then ybot:=ybody+10*10;

  xr := xname + wname + wplayer + wexp;
  SetFillStyle(SolidFill,Black);
  Bar(x0,y0,xr,ybot);
  SetColor(White);
  Rectangle(x0,y0,xr,ybot);
  SetTextJustify(LeftText,TopText);
  OutTextXY(xname,y0+3,'Ship functions:');
  if wplayer<>0 then OutTextXY(xname+wname,y0+3,'Players');
  if wexp<>0 then OutTextXY(xname+wname+wplayer,y0+3,'Level');

  for i:=1 to qr.count do begin
    phf := @PHullFunctionArray(qr.data)^[i];
    y := ybody + 10*Pred(i);
    if phf^.AssignedTo = asRace then begin
      if phf^.RaceMask = ALL_PLAYERS then as := '[U]' else as := '[R]'
    end else begin
      if phf^.AssignedTo = asHull then as := '[C]' else as := '[S]';
    end;
    SetColor(DarkGray);
    OutTextXY(x0+3,y,as);
    SetColor(LightGray);
    OutTextXY(xname,y,Copy(GetBasicFunctionTitle(phf^.BasicFunction), 1, 39));
    if wplayer<>0 then begin
      for j:=1 to 11 do
        if phf^.RaceMask and (1 shl j)<>0 then begin
          if j=highpl then SetColor(IIF(build,9,LightBlue)) else SetColor(LightGray);
          OutTextXY(xname+wname+8*Pred(j), y, Elf[j]);
        end;
    end;
    SetColor(LightGray);
    if wexp<>0 then begin
      for j:=0 to NumExperienceLevels do
        if phf^.LevelMask and (1 shl j)<>0 then begin
          if j=highlvl then SetColor(IIF(build,9,LightBlue)) else SetColor(LightGray);
          OutTextXY(xname+wname+wplayer+8*j, y, Elf[j]);
        end;
    end;
  end;
  Readkey;
end;
{$ENDIF}

End.
