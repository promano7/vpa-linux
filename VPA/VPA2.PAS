{
*******************************************************************
* VPA 2 - Main Part Display
*
* $Id: vpa2.pas,v 1.98 2013/12/29 06:41:03 sfplanets Exp $
*
*
*******************************************************************
}

{$I switches.inc}
Unit    VPA2;           (* VPA Main Part - Display *)
{$V-}
{DEFINE DEBUG}  (* include TurnsInMemory *)

Interface

uses    AuxF,VPAData,Building;

const   ListY   = 362;
        BL1     = 208;
        BL2     = 312;
        CY0     = 256;
        DistanceDigits = 1;

const   dline   : boolean = Off;
        radius0 : int = 0;
        ShowMassDiff : boolean = On;

var     ObjN,PlanN,ShipN: int;
        ObjL0,Obj0      : int;
        dlx,dly         : int;

procedure DrawMap (clr:boolean);
function  GoToShipXY (var h:sptr; x,y,k:int) : int;   { find k-th ship at (x,y), return ID or LockS }
function  GoToShipXYSorted (var h:sptr; x,y,k:int) : int;
procedure MouseMove;
procedure DrawWLine (x1,y1,x2,y2:int; FindMin:boolean);
procedure DrawWCircle (x,y,r:int);
procedure DrawWXCircle (x,y,r:int);
procedure DrawMark (x,y:int; c:byte; t:MarkType);       { XREF to VPA 3 }
procedure DrawPath;
procedure SayMoving;

{ procedure PlanetInfo; -> Moved to VPA4.PAS due to too lang segment-code}
{ procedure BaseInfo; -> Moved to VPA4.PAS }

procedure ShipInfo;
procedure MineInfo;
procedure InitObjList;
procedure ObjList;
function  CheckClone (baseId:int) : int;
function  ShipNumXY (h:sptr; x,y:int) : word;
{moved to interface section for ExtFeat}
procedure GetObjectCoord (obj:int; var lx,ly:int);
procedure CenterMap (x,y:int; forced:boolean);
procedure Zoom (k:byte);
procedure LockDistTarget (xx,yy:int);
{ function  NewShipControler(sid:int):int; }
procedure ResetMouseAndVideo;

procedure Main;

Implementation

uses    ptcgraph,Screen,Mouse,StrF,Keyboard,VPA3,{$IFDEF UNIX}xfocus,{$ENDIF}
{$IFDEF TASKS}
        Tasks,
{$ENDIF}
        UtilFmt,Plansim,ExtFeat,Ini,config,VPA4
{$IFDEF VPACC},
        PHostM,VPACC,Hullfunc
{$ENDIF};

(*moved Var-defs VPADATA.PAS
var     mt0,mt1         : longint;
        MineN,IonN,WormN,UfoN,MarkN   : int;
        BL0             : int;
        bOver           : boolean;
        AllH,eAllH,hOver: boolean;
        ScanH           : int;
        lsxy            : array [1..2,1..2] of int;
        dlship          : SRec;
{       dlf0            : long;
        dlw,dlc         : byte;}
        dlf             : long;
        dlt             : int;
        dlc             : byte;
        mEv0            : word;

const   iBeam : int = 10;


var     DScolorR: byte;
        DScolorO: byte;
        DScolorT: byte;
        DSwm    : byte;
const   DSdrawn : boolean = No;
        SRdrawn : boolean = No;
        forceDL : boolean = No;
var     SRradius: word;

const
        ShipSortTablePtr      : ^ShipSortArray = nil;
var
        ShipSortTableIndex    : word;
        ShipSortTableLock     : boolean;
moved to PADATA.PAS*)

procedure DrawDistLine;
  var   vp      : ViewPortType;
        p0      : int;
  begin
    MouseOff;
    GetViewSettings(vp);
    SetViewPort(0,0,479,479,ClipOn);
    SetLineStyle(DashedLn,0,NormWidth);
    SetColor(cmDist);
    p0:=GetPixel(lsxy[1,1],lsxy[1,2]);
    SetWriteMode(XORPut);
    Line(lsxy[1,1],lsxy[1,2],lsxy[2,1],lsxy[2,2]);
    SetWriteMode(NormalPut);
    PutPixel(lsxy[1,1],lsxy[1,2],p0);
    SetViewPort(vp.x1,vp.y1,vp.x2,vp.y2,vp.clip);
    MouseOn;
    dline:=not dline;
  end;

procedure DrawDistLock;
  var   xx,yy   : int;
  begin
    if distlock<0 then Exit;
    MouseOff;
    Abs2Scr(dlx,dly,xx,yy);
    if xx<476 then PutImage(xx-4,yy-4,BrownC^,XORPut);
    MouseOn;
  end;

procedure DrawWLine (x1,y1,x2,y2:int; FindMin:boolean);
  procedure DrawLine (x1,y1,x2,y2:int);
    var p1,p2   : byte;
        outta   : boolean;
    begin
      { outta = caja de la linea completamente fuera de [0,479]x[0,479]
        (se calcula como en el asm original; el Exit que lo usaba esta comentado) }
      outta := (Max(Min(x1,x2),0) > Min(Max(x1,x2),479))
            or (Max(Min(y1,y2),0) > Min(Max(y1,y2),479));
      {if outta then Exit;}
      p1:=GetPixel(x1,y1); p2:=GetPixel(x2,y2);
      Line(x1,y1,x2,y2);
      PutPixel(x1,y1,p1); PutPixel(x2,y2,p2);
    end;
  begin
    if MapWrap and FindMin then
    begin
      if long(Abs(x2-x1))>MapSSize div 2 then dec(x2,MapSSize*Sign(x2-x1));
      if long(Abs(y2-y1))>MapSSize div 2 then dec(y2,MapSSize*Sign(y2-y1));
    end;
    DrawLine(x1,y1,x2,y2);
    if MapWrap  then
    begin
      if (x1<0) or (x2<0) then DrawLine(x1+MapSSize,y1,x2+MapSSize,y2)
      else if (x1>479) or (x2>479) then DrawLine(x1-MapSSize,y1,x2-MapSSize,y2);
      if (y1<0) or (y2<0) then DrawLine(x1,y1+MapSSize,x2,y2+MapSSize)
      else if (y1>479) or (y2>479) then DrawLine(x1,y1-MapSSize,x2,y2-MapSSize);

      if ((y1<0) or (y2<0))and((x1<0) or (x2<0)) then DrawLine(x1+MapSSize,y1+MapSSize,x2+MapSSize,y2+MapSSize);
      if ((y1>479) or (y2>479))and((x1>479) or (x2>MapSSize)) then DrawLine(x1-MapSSize,y1-MapSSize,x2-MapSSize,y2-MapSSize);
      if ((y1<0) or (y2<0))and((x1>479) or (x2>479)) then DrawLine(x1-MapSSize,y1+MapSSize,x2-MapSSize,y2+MapSSize);
      if ((y1>479) or (y2>479))and((x1<0) or (x2<0)) then DrawLine(x1+MapSSize,y1-MapSSize,x2+MapSSize,y2-MapSSize);
    end;
  end;

procedure DrawCircle (x,y,r:int);
  var   x1,y1   : int;
  begin
    if (x<-r) or (x>479+r) or (y<-r) or (y>479+r) then Exit; {completely outside}
    x1:=x-IIF(x<240,479,0);
    y1:=y-IIF(y<240,479,0);
    if long(r)*r>long(x1)*x1+long(y1)*y1 then Exit;     {completely inside}
    Circle(x,y,r);
  end;

procedure DrawWCircle (x,y,r:int);
  var   xw,yw   : boolean;
  begin
    DrawCircle(x,y,r);
    if MapWrap and (ratioN=1) then
    begin
      xw:=(x-r<0) or (x+r>479);
      yw:=(y-r<0) or (y+r>479);
      if xw then DrawCircle(x-Sign(x-r)*480,y,r);
      if yw then DrawCircle(x,y-Sign(y-r)*480,r);
      if xw and yw then DrawCircle(x-Sign(x-r)*480,y-Sign(y-r)*480,r);
    end;
  end;

procedure DrawXCircle (x,y,r:int);
  { Draw circle by several line segments to allow XOR-Mode }
  var   x0,y0,x1,y1,i,w : int;
        f : int;
  begin
    if (x<-r) or (x>479+r) or (y<-r) or (y>479+r) then Exit; {completely outside}
    x1:=x-IIF(x<240,479,0);
    y1:=y-IIF(y<240,479,0);
    if long(r)*r>long(x1)*x1+long(y1)*y1 then Exit;     {completely inside}
    if (r<1) then Exit;
    if (r>50) then f:=9 else f:=18;
    x0:=x+r;
    y0:=y;
    w:=0;
    while (w<360) do begin
      w:=w+f;
      if w>360 then w:=360;
      x1:=x+round(r*cos(w*pi/180));
      y1:=y+round(r*sin(w*pi/180));
      line(x0,y0,x1,y1);
      x0:=x1;
      y0:=y1;
    end;
  end;

procedure DrawWXCircle (x,y,r:int);
  var   xw,yw   : boolean;
  begin
    DrawXCircle(x,y,r);
    if MapWrap and (ratioN=1) then
    begin
      xw:=(x-r<0) or (x+r>479);
      yw:=(y-r<0) or (y+r>479);
      if xw then DrawXCircle(x-Sign(x-r)*480,y,r);
      if yw then DrawXCircle(x,y-Sign(y-r)*480,r);
      if xw and yw then DrawXCircle(x-Sign(x-r)*480,y-Sign(y-r)*480,r);
    end;
  end;


procedure DrawFlyPath (h:sptr; sx1,sy1,heading,warp,wx,wy:int; c:byte; var DrawChunnel: boolean);
  var   sx2,sy2         : int;
        i,xx,yy,fc,fa   : int;
        fh,fh1          : sptr;
        if1             : boolean;
        hk              : single;
        _fuel,_eta      : int;
  begin
      DrawChunnel := False;
      sx2:=sx1; sy2:=sy1;
      if heading=-2 then
      begin
        if {(warp>0) and} (wx or wy<>0) then
        begin
          inc(sx2,long(wx)*ratio2 div ratio1);
          dec(sy2,long(wy)*ratio2 div ratio1);
        end;
        CalcMovement(h,StdTowPtr(h^),_fuel,_eta);
        if Chunnel and chuns and (ltype=LockS) and (_eta<=1) then { check for chunnel }
        begin
          xx:=h^.x; yy:=h^.y;
          if warp>0 then begin inc(xx,wx); inc(yy,wy) end;
          if warp>1 then
          begin
            Location(xx,yy);
            xx:=LocationX;
            yy:=LocationY;
          end;
          if1:=(h^.warp=0) or
               ShipIsCloaking(h^.owner, h^.mission) or
               (h^.fuel=0) or
               (h^.fuel=_fuel)or
               ((Phost)and(AllowAlliedChunneling));
          for i:=1 to 999 do
          begin
            fh:=TTurn^.data^.ship[i];
            with fh^ do
            if (fh<>nil) and (when=turn) and (x=xx) and (y=yy) and
               (warp=0) and (fuel>=50) and (damage<DamageLevelForChunnelFail) and
               (IsShipFunc3(fh^,SPC_Chunneling,SPC_ChunnelOthers,IIF(i=h^.ship_id,SPC_ChunnelSelf,-1))) and
               (UnderTow(i)=0) and
               ((owner=h^.owner) or (h^.fcode=fcode) or if1) then
            begin
              Val(fcode,fc,fa);
              if (fa=0) and (fc>0) and (fc<=999) then                  {FC set on target?}
              begin
                fh1:=TTurn^.data^.ship[fc];
                { When fuel>0 we are sure that RST with this ship was loaded,
                  so it is an ally to player.
                }
                with fh1^ do                                            {can chunnel to target fh1?}
                if (fh1<>nil) and (when=turn) and (warp=0) and (fuel>0) and
                  ( (owner=fh^.owner)or ((Phost)and(AllowAlliedChunneling)) )and
                   (damage<DamageLevelForChunnelFail) and
                   (IsShipFunc3(fh1^,SPC_Chunneling,SPC_ChunnelTarget,-1)) and (UnderTow(fc)=0) and
                   (Distance2(xx,yy,x,y)>=MinimumChunnelDistance*MinimumChunnelDistance)
                   then
                begin
                  SetColor(IIF(showT,DScolorO xor DScolorR,DScolorO));
                  SetLineStyle(SolidLn,0,NormWidth);
                  Abs2Scr(xx,yy,xx,yy);
                  Abs2Scr(x,y,fc,fa);
                  DrawWLine(xx,yy,fc,fa,Yes);
                  DrawChunnel := True;
                  Break;
                end;
              end;
            end;
          end;
      { Chunnel to Ship impemented 26.2.11 by Quapla sfplanets@gmx.de}
        if (IsShipFunc(h^,hfChunneling)) then                       {Ship can chunnel?}
          begin
            with h^ do 
                if (when=turn) and (warp=0) and (fuel>0)  and
                   (UnderTow(ship_id)=0) 
                then begin 
                xx:=h^.x; yy:=h^.y;
                Abs2Scr(xx,yy,xx,yy);                      { Set screen position of destination } 
                for i:=1 to 999 do 
                  begin
                  fh:=TTurn^.data^.ship[i];
                  if (fh<>NIL) then begin
                    with fh^ do Val(fcode,fc,fa);
                    with fh^ do 
                    if (h^.ship_id=fc) and (when=turn) and
                    (warp=0) and (fuel>=50)  and (damage<DamageLevelForChunnelFail) and 
                    { (IsShipFunc3(fh^,SPC_Chunneling,SPC_ChunnelOthers,IIF(i=h^.ship_id,SPC_ChunnelSelf,-1))) and  
                     // do not understand this, replaced by // }
                    (IsShipFunc(fh^,hfChunneling)) and (UnderTow(i)=0) and
                    (Distance2(h^.x,h^.y,x,y)>=MinimumChunnelDistance*MinimumChunnelDistance) and 
                    ( (owner=h^.owner) or ((Phost) and (AllowAlliedChunneling))) then 
                      begin                                        {fh chunnels to h}
                        SetColor(IIF(showT,DScolorO xor DScolorR,DScolorO));
                        SetLineStyle(DottedLn,0,NormWidth);
                        Abs2Scr(fh^.x,fh^.y,fc,fa);                { Set screen position of origin }
                        DrawWLine(xx,yy,fc,fa,Yes);
                        DrawChunnel := True;
                      end;
                    end;
                  end;
                end; 
          end;
        end;
        { Hyperjump implemented by Quapla}
        if (IsShipFunc(h^,hfHyperDrive)) then begin                      {Ship can HYP?}
          with h^ do begin
            if (warp>0) and (fcode='HYP') and (fuel>=50) then begin            {Ships does Jump}
              SetColor(IIF(showT,DScolorO xor DScolorR,DScolorO));
              if (Distance(0,0,wx,wy)>=340) and (Distance(0,0,wx,wy)<=360) then 
                SetLineStyle(SolidLn,0,NormWidth)
              else
                  SetLineStyle(DottedLn,0,NormWidth);
              DrawWLine(sx1,sy1,sx2,sy2,Yes);
              DrawChunnel := True;
            end else if (Addon.Unity) and (warp>0) and (fcode='AHP') and (fuel>=60) then begin            {Ships does Jump}
              SetColor(IIF(showT,DScolorO xor DScolorR,DScolorO));
              if (Distance(0,0,wx,wy)>=690) and (Distance(0,0,wx,wy)<=710) then 
                SetLineStyle(SolidLn,0,NormWidth)
              else
                  SetLineStyle(DottedLn,0,NormWidth);
              DrawWLine(sx1,sy1,sx2,sy2,Yes);
              DrawChunnel := True;
            end;
          end;
        end;

      end
      else if warp>0 then
      begin
        hk:=long(warp*warp)*ratio2/ratio1;
        if (h<>nil) and (IsShipFunc(h^,hfGravitonic)) then hk:=hk*2;
        inc(sx2,Round(hk*Sin(heading*Pi/180.0)));
        dec(sy2,Round(hk*Cos(heading*Pi/180.0)));
      end;
      if (sx2<>sx1) or (sy2<>sy1) then
      begin
        SetColor(c);
        if warp>0 then 
          SetLineStyle(SolidLn,0,NormWidth)
        else
          SetLineStyle(DottedLn,0,NormWidth);
      DrawWLine(sx1,sy1,sx2,sy2,No);
      end;
  end;

procedure DrawPath;
  var   x,y,px1,py1,px2,py2,wx,wy,heading,warp  : int;
        sx1,sy1,sx2,sy2 : int;
        p1,p2           : byte;
        mdr             : boolean;
        DrawChunnel     : boolean;
        vp              : ViewPortType;
        h               : sptr;
        is              : iptr;
        u               : uptr;
  function NearBy (x1,y1,x2,y2:int) : boolean;
    begin
      NearBy:=(Abs(x1-x2)<=3) and (Abs(y1-y2)<=3);
    end;
  begin
    if {showT or} ((ltype<>LockS) and (ltype<>LockI)) then Exit;
    mdr:=mdraw;
    MouseOff;
    SetWriteMode(DSwm);
    GetViewSettings(vp);
    SetViewPort(0,0,479,479,ClipOn);
    repeat      { try }
      if ltype=LockS then
      begin
        h:=TTurn^.data^.ship[lock and LockLo];
        if h=nil then Break;
        x:=h^.x; y:=h^.y;
        px1:=h^.px1; py1:=h^.py1;
        px2:=h^.px2; py2:=h^.py2;
        wx:=h^.wx; wy:=h^.wy;
        heading:=IIF(h^.mission=-1,h^.enemy,-2);
        warp:=h^.warp;
      end else
      if ltype=LockI then
      begin
        is:=TTurn^.data^.ion[lock and LockLo];
        if is=nil then Break;
        x:=is^.x; y:=is^.y;
        px1:=is^.px1; py1:=is^.py1;
        px2:=is^.px2; py2:=is^.py2;
        wx:=-1; wy:=-1;
        heading:=is^.heading;
        warp:=is^.warp;
        h:=nil; { needed for DrawFlyPath }
      end else
      if ltype=LockU then
      begin
        u:=TTurn^.data^.ufo[lock and LockLo];
        if u=nil then Break;
        x:=u^.x; y:=u^.y;
        px1:=u^.px1; py1:=u^.py1;
        px2:=u^.px2; py2:=u^.py2;
        wx:=-1; wy:=-1;
        heading:=u^.heading;
        warp:=u^.warp;
        h:=nil; { needed for DrawFlyPath }
      end;
      Abs2Scr(x,y,sx1,sy1);
      DrawChunnel := False;
      if heading<>-1 then DrawFlyPath(h,sx1,sy1,heading,warp,wx,wy,IIF(showT,8,DScolorR),DrawChunnel);
      if ltype=LockS then
      begin
        sx2:=UnderTow(lock and LockLo);
        if (sx2<>0) and ((h^.mission<>7) or (lock and LockLo>sx2)) then
        begin
          h:=TTurn^.data^.ship[sx2];    { h is changed !!! }
          if (not DrawChunnel) then
            DrawFlyPath(h,sx1,sy1,-2,h^.warp,h^.wx,h^.wy,IIF(showT,DScolorO xor DScolorR,DScolorO), DrawChunnel);
        end;
      end;
      SetColor(IIF(showT,8,DScolorT));
      if (px1<>-1) and (not NearBy(x+wx,y+wy,px1,py1)) then
      begin
        SetLineStyle(UserBitLn,$6666,NormWidth);
        Abs2Scr(px1,py1,sx2,sy2);
        if (px1<>x+wx) or (py1<>y+wy) then DrawWLine(sx1,sy1,sx2,sy2,Yes);
        sx1:=sx2; sy1:=sy2;
      end;
      if (px2<>-1) and ((px2<>x) or (py2<>y)) and (not NearBy(x+wx,y+wy,px2,py2)) then
      begin
        SetLineStyle(UserBitLn,$8888,NormWidth);
        Abs2Scr(px2,py2,sx2,sy2);
        DrawWLine(sx1,sy1,sx2,sy2,Yes);
      end;
    until True; { finally }
    SetViewPort(vp.x1,vp.y1,vp.x2,vp.y2,vp.clip);
    SetWriteMode(NormalPut);
    if mdr then MouseOn;
    DSdrawn:=not DSdrawn;
  end;

procedure DrawShipRange;
  var  vp      : ViewPortType;
        xx,yy   : int;
        i2,ee,ww,ff,mm,n1       : int;
        h1      : sptr;
  begin
    Exit;
    { DrawShipRange formulas totally wrong! }
    with lship^ do begin
      if (ltype<>LockS) or (hull<=0) or (mass<=0) then Exit;
      MouseOff;
      GetViewSettings(vp);
      SetViewPort(0,0,479,479,ClipOn);
      SetLineStyle(SolidLn,0,NormWidth);
      SetColor(LightGray);
      SetWriteMode(XORPut);
      if not SRdrawn then
      begin
        ee:=IIF(El>0,El,9);
        ww:=IIF(El>0,IIF(warp=0,GetOptimalWarp(lship),warp),9);
        ff:=IIF(fuel=-1,mass-Hulls[hull].mass,fuel);
        mm:=mass;
        n1:=IIF(mission=7,tow_ship,0);
        if (n1<>-1) and (n1<>0) then               { tow }
        begin
          h1:=TTurn^.data^.ship[n1];
          if (h1<>nil) and (h1^.mass<>-1) then mm:=mm+h1^.mass;
        end;
        i2:=ww*ww;
        if (IsShipFunc(lship^,hfGravitonic)) then i2:=i2*2;
        SRradius:=Round(Ln(ff/mm)/Ln(1-Engines[ee].burn[ww]/100000)*i2);
      end;
      Abs2Scr(x,y,xx,yy);
      DrawWXCircle(xx,yy,long(SRradius)*ratio2 div ratio1);
      SetWriteMode(NormalPut);
      SetViewPort(vp.x1,vp.y1,vp.x2,vp.y2,vp.clip);
      MouseOn;
    end;
    SRdrawn:=not SRdrawn;
  end;

function MarkOffsetX(t:MarkType) : int;
  begin
    MarkOffsetX:=0;
    if (t=mrkFlag) or (t=mrkFlag1) or (t=mrkFlag2) or (t=mrkFlag3)  then  begin
        MarkOffsetX:=-1;
      end;
  end;

function MarkOffsetY(t:MarkType) : int;
  begin
    MarkOffsetY:=0;
    if (t=mrkFlag) or (t=mrkGrave) or (t=mrkCactus) or
       (t=mrkFlag1) or (t=mrkFlag2) or (t=mrkFlag3) or
       (t=mrkNe) or (t=mrkTr) or (t=mrkDu) or (t=mrkMo) or (t=mrkSkull) then
      begin
        MarkOffsetY:=3;
      end;
  end;

procedure DrawMark (x,y:int; c:byte; t:MarkType);       { XREF to VPA 3 }
  begin
    if t=mrkDLine then SetLineStyle(UserBitLn,$5B5B,NormWidth)
                  else SetLineStyle(SolidLn,0,NormWidth);
    SetWriteMode(NormalPut);
    SetColor(c);
    case t of
      mrkFlag   : begin Line(x,y,x,y-7);
                        Line(x,y-6,x+3,y-5);
                        Line(x+3,y-5,x,y-4)     end;
      mrkCircle : Circle(x,y,2); { not DrawCircle! they can be on the right screen }
      mrkCross  : begin Line(x-2,y-2,x+2,y+2);
                        Line(x-2,y+2,x+2,y-2)   end;
      mrkSquare : Rectangle(x-2,y-2,x+2,y+2);
      mrkRhombe : begin Line(x-2,y,x,y-2);
                        Line(x,y-2,x+2,y);
                        Line(x+2,y,x,y+2);
                        Line(x,y+2,x-2,y)       end;
      mrkPoint  : PutPixel(x,y,c);
      mrkRCircle: Circle(x,y,3); { not DrawCircle! they can be on the right screen }
      mrkLine,
      mrkDLine  : Line(x-3,y-3,x+3,y+3);
      mrkGrave  : begin Line(x,y,x,y-6);
                        Line(x-2,y-5,x+2,y-5);
                        Line(x-1,y-1,x+1,y-2);  end;
      mrkCactus : begin Line(x,y,x,y-6);
                        Line(x-2,y-4,x-2,y-5);
                        Line(x-1,y-3,x+1,y-2);
                        Line(x+2,y-3,x+2,y-5);  end;
      mrkFlag1  : begin Line(x,y,x,y-7);
                        Line(x,y-7,x+4,y-7);
                        Line(x+4,y-7,x+4,y-4);
                        Line(x+4,y-4,x,y-4)     end;
      mrkFlag2  : begin Line(x,y,x,y-7);
                        Line(x,y-7,x+3,y-7);
                        Line(x,y-6,x+3,y-6);
                        Line(x,y-5,x+3,y-5);
                        Line(x,y-4,x+3,y-4);    end;
      mrkFlag3  : begin Line(x,y,x,y-8);
                        Line(x,y-8,x+4,y-8);
                        Line(x,y-4,x+4,y-4);
                        Line(x,y-7,x+3,y-7);
                        Line(x,y-5,x+3,y-5);
                        Line(x,y-6,x+2,y-6);    end;
      mrkArrow1 : begin Line(x,y-2,x,y+3);
                        Line(x,y-4,x+2,y-2);
                        Line(x,y-4,x-2,y-2);    end;
      mrkArrow2 : begin Line(x-3,y+3,x+1,y-1);
                        Line(x+3,y-3,x,y-3);
                        Line(x+3,y-3,x+3,y);    end;
      mrkArrow3 : begin Line(x-3,y,x+1,y);
                        Line(x+3,y,x+1,y-2);
                        Line(x+3,y,x+1,y+2);    end;
      mrkArrow4 : begin Line(x+1,y+1,x-3,y-3);
                        Line(x+3,y+3,x,y+3);
                        Line(x+3,y+3,x+3,y);    end;
      mrkArrow5 : begin Line(x,y-3,x,y+2);
                        Line(x,y+4,x+2,y+2);
                        Line(x,y+4,x-2,y+2);    end;
      mrkArrow6 : begin Line(x+3,y-3,x-1,y+1);
                        Line(x-3,y+3,x,y+3);
                        Line(x-3,y+3,x-3,y);    end;
      mrkArrow7 : begin Line(x-1,y,x+3,y);
                        Line(x-3,y,x-1,y-2);
                        Line(x-3,y,x-1,y+2);    end;
      mrkArrow8 : begin Line(x+3,y+3,x-1,y-1);
                        Line(x-3,y-3,x,y-3);
                        Line(x-3,y-3,x-3,y);    end;
      mrkNe     : begin Line(x-3,y,x-3,y-6);
                        Line(x-2,y-2,x-2,y-4);
                        Line(x-1,y,x-1,y-6);
                        Line(x+3,y-2,x+3,y-3);
                        PutPixel(x+2,y,c);
                        PutPixel(x+2,y-4,c);
                        Line(x+1,y-1,x+1,y-3)   end;
      mrkTr     : begin Line(x-3,y-6,x-1,y-6);
                        Line(x-2,y,x-2,y-6);
                        Line(x,y,x,y-3);
                        Line(x+1,y-4,x+2,y-4);  end;
      mrkDu     : begin Line(x-3,y,x-3,y-5);
                        Line(x-1,y-1,x-1,y-5);
                        Line(x-3,y-6,x-2,y-6);
                        Line(x-3,y,x-2,y);
                        Line(x+1,y-1,x+1,y-4);
                        Line(x+3,y-1,x+3,y-4);
                        Line(x+1,y,x+2,y);      end;
      mrkMo     : begin Line(x-3,y,x-3,y-6);
                        Line(x-1,y,x-1,y-6);
                        Line(x-2,y-4,x-2,y-5);
                        Line(x+3,y-1,x+3,y-3);
                        PutPixel(x+2,y,c);
                        PutPixel(x+2,y-4,c);
                        Line(x+1,y-1,x+1,y-3)   end;
      mrkSkull  : begin Line(x-2,y-7,x+2,y-7);
                        Line(x-3,y-3,x-3,y-6);
                        Line(x+3,y-3,x+3,y-6);
                        PutPixel(x-2,y-3,c);
                        PutPixel(x+2,y-3,c);
{Line(x-1,y-3,x+1,y-3);}
                        PutPixel(x-1,y-5,c);
                        PutPixel(x+1,y-5,c);
{PutPixel(x,y-4,c);}
                        PutPixel(x-1,y-2,c);
                        PutPixel(x+1,y-2,c);
                        Line(x-3,y+1,x+3,y-1);
                        Line(x+3,y+1,x-3,y-1);

                                                end;

    end;
  end;

procedure DrawMap (clr:boolean);
  var   xx,yy     : int;
        oxx,oyy   : int;
        x2,y2   : int;
        i       : int;
        l0,l1   : int;
        c       : byte;
        sh0     : boolean;
        s       : str20;
        ls      : byte absolute s;
        mc      : String[1];
        mexptr  : MineExplosionRecordPtr;
  begin
    MouseOff;
    MouseDisabled:=Yes;
    SetViewPort(0,0,479,479,ClipOn);
    if clr then
    begin
      SetFillStyle(SolidFill,Black);
      Bar(0,0,479,479);
      {ClearViewPort;}
      DSdrawn:=No;
      DWdrawn:=No;
      SRdrawn:=No;
    end
    else begin
      if DSdrawn then DrawPath;
      if SRdrawn then DrawShipRange;
      if DWdrawn then DrawWarpCircles;
      {DrawPlanetYnfos;}
      if distlock<>0 then DrawDistLock;
      if dline then begin dline:=No; DrawDistLine end;
      MouseOff;         { DrawDistLock and DrawDistLine turn mouse on! }
    end;

    if MapWrap and ShowMapBorder then
    begin
      SetColor(DarkGray);
      SetLineStyle(DashedLn,0,NormWidth);
      Abs2Scr(MapX0,MapY0,xx,yy);
      Line(xx,0,xx,479);
      Line(0,yy,479,yy);
    end;

    ExtFeatDrawMapBeginHook;
    SetLineStyle(SolidLn,0,NormWidth);

    with TTurn^.data^ do
    begin
      if showG and (ratioN>=GWRatio) then
      begin
        for i:=1 to 500 do
          if (xyplan[i,1]<>-1) and Abs2Scr(xyplan[i,1],xyplan[i,2],xx,yy) then
            DrawGravityWellEnv(xx,yy);
        for i:=1 to 500 do
          if (xyplan[i,1]<>-1) and Abs2Scr(xyplan[i,1],xyplan[i,2],xx,yy) then          
            DrawGravityWell(xx,yy);          
      end;

      if showT or not clr then
      begin
        DSwm:=NormalPut;
        sh0:=showT; showT:=No;
        l0:=lock;
        ltype:=LockS;
        for i:=1 to 999 do
          if ship[i]<>nil then
          with ship[i]^ do
            if when=turn then
            begin
              lock:=i or LockS;
              DScolorR:=IIF(sh0 and (((showS) and (owner=player)) or ((showE) and (owner<>player))),cmRoute,Black);
              DSColorO:=IIF(DSColorR=Black,Black,cmRoute);
              DSColorT:=IIF(DSColorR=Black,Black,cmTrace);
              DrawPath;
            end;
        ltype:=LockI;
        for i:=1 to 50 do
          if ion[i]<>nil then
          with ion[i]^ do
          begin
            lock:=i or LockI;
            DScolorR:=IIF(sh0 and showI,cmRoute,Black);
            DSColorO:=IIF(DSColorR=Black,Black,cmTow);
            DSColorT:=IIF(DSColorR=Black,Black,cmTrace);
            DrawPath;
          end;
        ltype:=LockU;
        for i:=1 to 100 do
          if ufo[i]<>nil then
          with ufo[i]^ do
          begin
            lock:=i or LockU;
            DScolorR:=IIF(sh0 and showU,cmRoute,Black);
            DSColorO:=IIF(DSColorR=Black,Black,cmTow);
            DSColorT:=IIF(DSColorR=Black,Black,cmTrace);
            DrawPath;
          end;
        lock:=l0; ltype:=lock and LockHi;
        showT:=sh0;
      end;
      DSwm:=XORPut; DScolorR:=cmRoute; DScolorT:=cmTrace; DScolorO:=cmTow; DSdrawn:=No;

      if showI or not clr then
      for i:=1 to 50 do
        if ion[i]<>nil then
        with ion[i]^ do
        begin
          Abs2Scr(x,y,xx,yy);
          SetColor(IIF(showI,IIF(voltage<50,cmIWeak,IIF(voltage<150,cmIMod,cmIDang)),Black));
          DrawWCircle(xx,yy,long(radius)*ratio2 div ratio1);
        end;

      if IsMines and (showM or not clr) then
      for i:=1 to 500 do
        if mines[i]<>nil then
        with mines[i]^ do
        begin
          Abs2Scr(x,y,xx,yy);
          SetColor(IIF(showM,RaceColor[owner,_M_],Black));
          if (web and 4=4) then
            DrawWCircle(xx,yy,Round(Sqrt(MaxL(DecayMineUnits(units,(web and 1=1)),0))*ratio2/ratio1))
          else
            DrawWCircle(xx,yy,Round(Sqrt(MaxL(units,0))*ratio2/ratio1));
        end;

      if ((showP) or (showN))  and (ratioN>=PNRatio) then
      begin
        if UseSmallFont then SetTextStyle(LittFont,HorizDir,4);
        SetTextJustify(CenterText,BottomText);
        SetColor(LightGray);
        for i:=1 to 500 do if (planet[i]<>NIL) then 
          if (xyplan[i,1]<>-1) and Abs2Scr(xyplan[i,1],xyplan[i,2],xx,yy) then
          begin
            if showP then begin
              c:=eplan[i].owner;
              if c=255 then c:=0;
              SetColor(RaceColor[c,_P_]);
              if ShowN and (planet[i]^.natives>0) then OutTextXY(xx,yy-13,PlName(i,No))
              else OutTextXY(xx,yy-4,PlName(i,No));
            end;
            if ShowN then with planet[i]^ do if natives>0 then begin
              if (100-climate)>84 then SetColor(lightred) 
              else if (100-climate)<15 then SetColor(lightblue)
              else SetColor(green);
              s:=Nstr0(natives div 1000)+#39+' '+copy(NatRace[NRace],1,5);
              if (Ngovt<>-1) then s:=s+' ('+NatGRate[Ngovt]+')';
              OutTextXY(xx,yy-5,s);
            end;
          end;
        if showU or not clr then
        for i:=1 to 100 do
          if ufo[i]<>nil then
          with ufo[i]^ do
          if (color<>0) and Abs2Scr(x,y,xx,yy) then
          begin
            SetColor(IIF(showU,color,Black));
            s:=name; Trim(s);
            OutTextXY(xx,yy-4,s);
          end;
        if UseSmallFont then SetTextStyle(DefaultFont,HorizDir,1);
        SetTextJustify(LeftText,TopText);
      end;

      if showA then
      begin
        mc := '*';
        if UseSmallFont then SetTextStyle(LittFont,HorizDir,4);
        for i:=1 to nmark do
          with mark^[i] do
          if (mtype<>mrkNone) and (Abs2Scr(x,y,xx,yy) or
                                   (mtype in [mrkRCircle..mrkDLine])) then begin
            mc[1] := MarkGroup[mtype][color];
          if (LastMarkMask < 1) or (MarkMask[CurMarkMask]='*') or
                 (PosInStr(mc,MarkMask[CurMarkMask]) <> 0) then
            { Abs2Scr MUST be executed, therefore, it is first in OR }
            begin
              if mtype=mrkRCircle then
              begin
                SetColor(color);
                DrawWCircle(xx,yy,long(radius)*ratio2 div ratio1);
              end else
              if mtype in [mrkLine,mrkDLine] then
              begin
                SetLineStyle(IIF(mtype=mrkDLine,DashedLn,SolidLn),0,NormWidth);
                x2:=xx; y2:=yy;
                inc(x2,long(dx)*ratio2 div ratio1);
                dec(y2,long(dy)*ratio2 div ratio1);
                SetColor(color);
                DrawWLine(xx,yy,x2,y2,No);
              end
              else begin
                DrawMark(xx,yy,color,mtype);
                s:=GetMarkText(i);
                if (ls>0) and (s[1]<>'`') then
                begin
                  SetTextJustify(xalg,yalg);
                  OutTextXY(xx+(1-xalg)*3+1,yy+(yalg-1)*3-1,s);
                end;
              end;
            end;
          end;
        if UseSmallFont then SetTextStyle(DefaultFont,HorizDir,1);
        SetTextJustify(LeftText,TopText);
      end;

      if showU or not clr then
      begin
        for i:=0 to 199 do
          if worm[i]<>nil then
          with worm[i]^ do
          begin
            Abs2Scr(x,y,xx,yy);
            SetColor(IIF(showU,cmWorm,Black));
            DrawWCircle(xx,yy,Round(( Exp(Ln(mass)*WormPower/100)/2 )*ratio2/ratio1));
            if (i and 1=1) and (worm[i-1]<>nil) then
            begin
              MoveTo(xx,yy);
              oxx:=xx;
              oyy:=yy;
              with worm[i-1]^ do Abs2Scr(x,y,xx,yy);
              if showU and (cmWorm and 8=8) then SetColor(cmWorm xor 8);
              SetLineStyle(DashedLn,0,NormWidth);
              if (AltWormholes) then
                 DrawWLine(oxx,oyy,xx,yy,Yes)
              else {not AltWormhole}
              begin
                MoveTo(oxx,oyy);
                LineTo(xx,yy);
              end;
            end;
          end;
        for i:=1 to 100 do
          if ufo[i]<>nil then
          with ufo[i]^ do
          begin
            Abs2Scr(x,y,xx,yy);
            SetColor(IIF(showU,color,Black));
            DrawWCircle(xx,yy,long(radius)*ratio2 div ratio1);
          end;
      end;

      if showX and (turn=today) then begin
         mexptr:=MineExplosions;
         while (mexptr^.next<>NIL) do begin
            SetLineStyle(SolidLn,0,NormWidth);
            SetColor(7);
            Abs2Scr(mexptr^.x1,mexptr^.y1,xx,yy);
            Abs2Scr(mexptr^.x2,mexptr^.y2,x2,y2);
            if ((ratioN>1) and (abs(y2-yy)<480) and (abs(x2-xx)<480)) or
               ((ratioN=1) and (abs(y2-yy)<240) and (abs(x2-xx)<240)) then
               DrawWLine(xx,yy,x2,y2,No);
            mexptr:=mexptr^.next;
         end;
      end;
      
      if showV and Addon.Teleport then begin         {View Teleport}
        if UseSmallFont then SetTextStyle(LittFont,HorizDir,4);
        for i := 1 to 500 do begin
          l0 := GetTeleportDataTX(i,c,l1);
          if (l0=0) then begin                            {No TX, check RX}
            l0 := GetTeleportDataRX(i,c,l1);
            if (l0<>0) and (ratioN>=PNRatio) then begin     {RX and View}
              if (l0>0) then s:=Nstr0(l0)+'^: '+Nstr0(l1)+TPFCode[c]  {RX Resolved}
                        else s:=' '+TPFCode[c];             {RX but no TX}
              Abs2Scr(xyplan[i,1],xyplan[i,2],xx,yy);
              SetTextJustify(Righttext,CenterText);
              SetColor(c);
              DrawMark(xx-8,yy,c,mrkArrow3);
              OutTextXY(xx-12,yy-1,s);
            end;
          end else begin                                 {TX}
            Abs2Scr(xyplan[i,1],xyplan[i,2],xx,yy);
            SetColor(c);
            if (l0>0) then begin                          {TX Resolved}
              Abs2Scr(xyplan[l0,1],xyplan[l0,2],x2,y2); 
              SetLineStyle(UserBitLn,$8888,NormWidth);
              DrawWLine(xx,yy,x2,y2,No);
              s:=Nstr0(l1)+TPFCode[c];
              SetTextJustify(Centertext,CenterText);
              OutTextXY(min(xx,x2)+((max(xx,x2)-min(xx,x2)) div 2),min(yy,y2)+((max(yy,y2)-min(yy,y2)) div 2),
                '#'+Nstr(i)+' -> #'+Nstr(l0)+': '+s);
            end else s:=' '+TPFCode[c];                  {TX But no RX}
            if (ratioN>=PNRatio) then begin
              SetTextJustify(Lefttext,CenterText);
              DrawMark(xx+9,yy,c,mrkArrow3);
              OutTextXY(xx+12,yy-1,s);
            end;
          end;          
        end;
        SetTextJustify(Lefttext,TopText);
        if UseSmallFont then SetTextStyle(DefaultFont,HorizDir,1);      
      end;
            
      for i:=1 to 999 do
        if (ship[i]<>nil) and (splan[i]<>0) then
        with ship[i]^ do
          if when=turn then
          if Abs2Scr(x,y,xx,yy) then
          begin
            c:=RaceColor[owner,_S_];
            c:=IIF(((owner=player) and showS) or ((owner<>player) and showE),c,Black);
            SetColor(c); Circle(xx,yy,IIF(owner=player,3,2));
          end;

      for i:=1 to 500 do
      if (xyplan[i,1]<>-1) and Abs2Scr(xyplan[i,1],xyplan[i,2],xx,yy) then
      begin
        c:=eplan[i].owner;
        if c=255 then c:=0;
        c:=IIF(eplan[i].activity and EP_Base=0,RaceColor[c,_P_],RaceColor[c,_B_]);
        PutPixel(xx,yy,c);
        if (LargePlanets and (ratioN>1)) or (eplan[i].activity and EP_Base<>0) then
        begin
          PutPixel(xx-1,yy,c);
          PutPixel(xx+1,yy,c);
          PutPixel(xx,yy-1,c);
          PutPixel(xx,yy+1,c);
        end;
      end;

      for i:=1 to 999 do
        if (ship[i]<>nil) and (splan[i]=0) then
        with ship[i]^ do
          if (when=turn) and (owner<>player) then
          if Abs2Scr(x,y,xx,yy) then
            PutPixel(xx,yy,IIF(showE,RaceColor[owner,_S_],Black));

      for i:=1 to 999 do
        if (ship[i]<>nil) and (splan[i]=0) then
        with ship[i]^ do
          if (when=turn) and (owner=player) then
          if Abs2Scr(x,y,xx,yy) then
          begin
            c:=RaceColor[owner,_S_];
            if showS or (GetPixel(xx,yy)=c) then PutPixel(xx,yy,IIF(showS,c,Black));
          end;
    end;
    ExtFeatDrawMapEndHook;
    if distlock<>0 then DrawDistLock;
    if dline then begin dline:=No; DrawDistLine end;
    {if not showT then} DrawPath;
    DrawShipRange;
    DrawWarpCircles;
    DrawPlanetYnfos;
    if showC then ShowClock;
    if showF and (turn=today) and (clr) then ShowForecast; 
    SetViewPort(0,0,639,479,ClipOn);
    MouseDisabled:=No;
    MouseOn;
  end;

procedure LockDistTarget (xx,yy:int);
  var   i,n,mm  : int;
{       ef,r    : long;
        i2      : int;}
        {nd,}dd : single;
        mx,my   : int;
        s,s1,s2 : string[6];
{       h1      : sptr;}
{       kf      : single;}
{       clFB    : int;}
        dlsh1   : SRec;
        lsxy0   : array [1..2,1..2] of int;
  begin
    if dline then DrawDistLine;
    Abs2Scr(xx,yy,mx,my);
    Move(lsxy,lsxy0,SizeOf(lsxy));
    Abs2Scr(dlx,dly,lsxy[1,1],lsxy[1,2]);
    lsxy[2,1]:=mx; lsxy[2,2]:=my;
    DrawDistLine;
    if forceDL then forceDL:=No
    else if not Diff(lsxy,lsxy0,SizeOf(lsxy)) then Exit;
    if MapWrap then
    begin
      if Sign(dlx-xx)<>Sign(lsxy[1,1]-lsxy[2,1]) then inc(xx,MapSize*Sign(lsxy[2,1]-lsxy[1,1]));
      if Sign(yy-dly)<>Sign(lsxy[1,2]-lsxy[2,2]) then inc(yy,MapSize*Sign(lsxy[1,2]-lsxy[2,2]));
    end;
    dd:=round((Sqrt(Distance2(dlx,dly,xx,yy))*10-0.1))/10;
    (*dd:=Trunc(Sqrt(Distance2(dlx,dly,xx,yy))*10)/10;*)
    Str(dd:3+DistanceDigits:DistanceDigits,s);
    SetColor(LightGray);
    Clear(MX0,dll+2,639,479);
    if dll>400 then OutTextXY(MX0,472,'Distance = '+s)
    else begin
      OutTextXY(MX0,370,'Distance = '+s);
      OutTextXY(MX0,380,'Warp  Time  Fuel');
      SetLineStyle(SolidLn,0,NormWidth);
      Line(MX0,388,623,388);
      with dlship do
      begin
        if (mass=-1) or (hull=-1) or (El=-1) or (fuel=-1) then Exit;
        wx:=xx-dlx;
        wy:=yy-dly;
        dlship.mission:=IIF(dlc=1,10,IIF(dlship.mission=7,7,0));
        if dd=0 then
        begin
          if dlc=1 then
          begin
            dlsh1:=dlship;
            CalcMove(dlsh1,StdTowPtr(dlsh1),No);
            n:=dlship.fuel-dlsh1.fuel;
            SetColor(IIF(dlship.fuel>n,LightGray,Brown));
            OutTextXY(MX0,392,'Cloaking : '+NStr0(n)+' kt');
          end;
          if (dlc<>2) and (turn=today) and (dlship.owner=player) then
          begin
            SetColor(White);
            OutTextXY(MX0,392,'C');
          end;
          Exit;
        end;
        for i:=1 to 9 do
        begin
          dlsh1:=dlship;
          dlsh1.warp:=i;
          CalcMovement(@dlsh1,StdTowPtr(dlsh1),mm,n);
          SetColor(IIF(mm>fuel,IIF(i=dlship.warp,Brown,DarkGray),
                               IIF(i=dlship.warp,Yellow,LightGray)));
          if distlock<0 then inc(n,dlt);
          if distlock<0 then inc(mm,dlf);
          Str(i:2,s);
          if n>=20000 then
          begin
            s1:=' too';
            s2:='long';
          end
          else begin
            Str(n:4,s1);
            s2:=NStrMax(mm,4,'+');
            for n:=1 to 3 do
              if s2[n]='-' then s2[n]:='+';
          end;
          OutTextXY(MX0+8,380+i*10,s+'   '+s1+'  '+s2);
          Line(MX0,388+i*10,623,388+i*10);
          if (i<>dlship.warp) and (turn=today) {and (dlship.owner=player)} then
          begin
            SetColor(White);
            OutTextXY(MX0+8,380+i*10,s);
          end;
          if dlc=1 then
          begin
            SetColor(LightGray);
            OutTextXY(640-8,380+i*10,Copy('Cloaked',i,1));
          end;
        end;
        if (dlc<>2) and (turn=today) {and (dlship.owner=player)} then
        begin
          SetColor(White);
          OutTextXY(640-8,380+1*10,'C');
        end;
      end;
    end;
  end;

(*procedure LockDistTarget (lx,ly:int);
  var   i,n,mm  : int;
        ef,r    : long;
        i2      : int;
        nd,dd   : single;
        mx,my   : int;
        s,s1,s2 : string[6];
        h,h1    : sptr;
        kf      : single;
        clFB    : int;
        n1      : int;
  begin
    if dline then DrawDistLine;
    Abs2Scr(lx,ly,mx,my);
    Abs2Scr(dlx,dly,lsxy[1,1],lsxy[1,2]);
    lsxy[2,1]:=mx; lsxy[2,2]:=my;
    DrawDistLine;
    if MapWrap then
    begin
      if Sign(dlx-lx)<>Sign(lsxy[1,1]-lsxy[2,1]) then inc(lx,MapSize*Sign(lsxy[2,1]-lsxy[1,1]));
      if Sign(ly-dly)<>Sign(lsxy[1,2]-lsxy[2,2]) then inc(ly,MapSize*Sign(lsxy[1,2]-lsxy[2,2]));
    end;
    dd:=Sqrt(Distance2(dlx,dly,lx,ly));
    Str(dd:4:1,s);
    SetColor(LightGray);
    Clear(MX0,dll+2,639,479);
    if dll>400 then OutTextXY(MX0,472,'Distance = '+s)
    else begin
      OutTextXY(MX0,370,'Distance = '+s);
      OutTextXY(MX0,380,'Warp  Time  Fuel');
      SetLineStyle(SolidLn,0,NormWidth);
      Line(MX0,388,623,388);
      h:=TTurn^.data^.ship[Abs(distlock) and LockLo];
      if (h=nil) or (h^.mass=-1) or (h^.hull=-1) or (h^.El=-1) or (h^.fuel=-1) then Exit;
      with h^ do
      begin
        mm:=mass;
        n1:=IIF(mission=7,tow_ship,0);
        if n1>0 then               { tow }
        begin
          h1:=TTurn^.data^.ship[n1];
          if (h1<>nil) and (h1^.mass<>-1) then inc(mm,h1^.mass);
          if TSh=n1 then inc(mm,TN+TT+TD+TM+TC+TS);
        end;
      end;
      if dlc=1 then
      begin
        i:=h^.mission;
        h^.mission:=10;
        clFB:=CloakFuel(h);
        h^.mission:=i;
      end
      else clFB:=0;
      if distlock<0 then dec(mm,MinL(h^.fuel,dlf));
      if dd=0 then
      begin
        if dlc=1 then
        begin
          SetColor(IIF(h^.fuel>clFB,LightGray,Brown));
          OutTextXY(MX0,392,'Cloaking : '+NStr0(clFB)+' kt');
        end;
        if (dlc<>2) and (turn=today) and (h^.owner=player) then
        begin
          SetColor(White);
          OutTextXY(MX0,392,'C');
        end;
        Exit;
      end;
      for i:=1 to 9 do
      begin
        i2:=i*i;                        { XREF to CalcFuel }
        if IsShipFunc(h^,hfGravitonic) then i2:=i2*2;
        ef:=Engines[h^.El].burn[i];
        kf:=ef/100000;
        SetColor(IIF(i=dlw{h^.warp},Yellow,LightGray));
        Str(i:2,s);
        if dd<i2+1 then n:=1 else n:=Ceil(dd/i2); { XREF to ETA }
        if distlock<0 then inc(n,dlt);
        Str(n:4,s1);
        dec(n);
        if n>0 then r:=Trunc(long(mm)*(1.0-Exp(Ln(1-kf)*n)))
               else r:=0;
        nd:=dd-long(i2)*n;
        inc( r , long(clFB)*(n+1)+Trunc(nd*((long(mm)-MinL(r,h^.fuel)) div 10)*(ef/i2)/10000) ); {local XREF}
        if distlock<0 then inc(r,dlf);
        if i=dlw{h^.warp} then
        begin
          if dd>i2 then nd:=i2 else nd:=dd;
          dlf0:=Trunc(nd*(mm div 10)*(ef/i2)/10000)+clFB;       { local XREF }
        end;
        if r>h^.fuel then SetColor(IIF(i=dlw{h^.warp},Brown,DarkGray));
        s2:=NStrMax(r,4,'+');
        OutTextXY(MX0+8,380+i*10,s+'   '+s1+'  '+s2);
        Line(MX0,388+i*10,623,388+i*10);
        if (i<>dlw) and (turn=today) and (h^.owner=player) then
        begin
          SetColor(White);
          OutTextXY(MX0+8,380+i*10,s);
        end;
        if dlc=1 then
        begin
          SetColor(LightGray);
          OutTextXY(640-8,380+i*10,Copy('Cloaked',i,1));
        end;
      end;
      if (dlc<>2) and (turn=today) and (h^.owner=player) then
      begin
        SetColor(White);
        OutTextXY(640-8,380+1*10,'C');
      end;
    end;
  end;*)

procedure CenterMap (x,y:int; forced:boolean);
  var   sx,sy   : int;
  begin
    Abs2Scr(x,y,sx,sy);
    if forced or (sx<0) or (sy<0) or (sx>479) or (sy>479) then
    begin
      inc(x0,sx-240); inc(y0,sy-240);
      MoveMouseTo(240,240);
      DrawMap(Yes);
      if distlock<>0 then LockDistTarget(mmx,mmy);
    end;
  end;

procedure Zoom (k:byte); {0 - ZoomOut, 1 or 255 - enlarge/sqeeze }
  var   mx,my   : int;
        w0      : boolean;
  begin
    Scr2Abs(MouseX,MouseY,mx,my);
    if k=0 then ratioN:=1
    else begin
      inc(ratioN,k);
      if ratioN=0 then ratioN:=NRatios;
      if ratioN>NRatios then ratioN:=1;
    end;
    InitRatios;
    x0:=0; y0:=0;
    w0:=MapWrap; MapWrap:=No;
    if ratioN=1 then
    begin
      Abs2Scr(mx,my,MouseX,MouseY);
      MouseX:=Min(Max(MouseX,0),479);
      MouseY:=Min(Max(MouseY,0),479);
    end
    else begin
      Abs2Scr(mx,my,x0,y0);
      dec(x0,239); dec(y0,239);
      MouseX:=240; MouseY:=240;
    end;
    MapWrap:=w0;
    MoveMouseTo(MouseX,MouseY);
    DrawMap(Yes);
    if lock<>0 then begin force:=lock; ForceKey:=13 end
               else MouseMove;
  end;

procedure SetScreenPos (n:byte);
  begin
    if KbdFlags and KbdShft<>0 then             { store screen pos }
    begin
      Move(ratioN,ScreenPos[n],SizeOf(VPAScr)-2);
      ScreenPos[n].force:=lock;
       write(y0,':',ScreenPos[n].y0,'   ');
    end
    else if ScreenPos[n].ratioN<>0 then
    begin                                       { retrieve screen pos }
      MouseMove;
(*      Move(ScreenPos[n],ratioN,SizeOf(VPAScr)-2-NShowmax); { without showflags } *)
      ratioN:=ScreenPos[n].ration;
      x0:=ScreenPos[n].x0;
      y0:=ScreenPos[n].y0;
      InitRatios;
      force:=ScreenPos[n].force;
      DrawMap(Yes);
      if force<>0 then ForceKey:=13;
    end;
  end;

procedure InitObjList;
  var   i,j     : int;
        h       : sptr;
        p       : pptr;
        fa, fc  : int;
        swap    : ShipSortRecord;
        towed   : int;

  begin
    ObjL0:=0;
    ObjN:=0;
    ShipSortTableIndex :=0;

    for i:=1 to NUM_SHIPS do
      if ShipIsHere(i,lx,ly) then
      begin
        if lock=i or LockS then ObjL0:=ObjN div 10;     { before increment! }
        inc(ShipSortTableIndex);
        ShipSortTablePtr^[ShipSortTableIndex].id   := i;
        ShipSortTablePtr^[ShipSortTableIndex].key  := 0;
        ShipSortTablePtr^[ShipSortTableIndex].key2 := 0;
        ShipSortTablePtr^[ShipSortTableIndex].icon := NO_ICON;
        ShipSortTablePtr^[ShipSortTableIndex].color:= NO_COLOR;
        inc(ObjN);
      end;

    { Sort by battle order }
    if (ShipSortTableType > 0) then
    begin
    {Prepare key for battle order}
    if (ShipSortTableType = 1) then
    for i := 1 to ShipSortTableIndex do
     with TTurn^.data^.ship[ShipSortTablePtr^[i].id]^ do
       if (fuel <>-1) and (mission <> -1) and (enemy <> -1) and (fcode <>#$FF#$FF#$FF) then
       begin
       if (fuel > 0) then
        if (weapons>1) or (bays>0) or (launchers>0) then
         if  ((mission = 4) or (enemy <> 0)) then    {KILL mission }
          begin
            Val(fcode,fc,fa);
            if (fa=0) and (fc >= -99) and (fc <= 999) then
             begin
                ShipSortTablePtr^[i].key  := fc + 1000;        { agressive ships }
                if (fc<0) then
                 begin
                   ShipSortTablePtr^[i].icon  := ICON_SHIP_BEFORE_PLANET;
                   ShipSortTablePtr^[i].color := COLOR_SHIP_BEFORE_PLANET;
                 end
                else
                 begin
                   ShipSortTablePtr^[i].icon  := ICON_SHIP_AFTER_PLANET;
                   ShipSortTablePtr^[i].color := COLOR_SHIP_AFTER_PLANET;
                 end;
             end
            else  (* (fa=0) and (fc >= -99) and (fc <= 999) *)
              begin
                ShipSortTablePtr^[i].key := ShipSortTablePtr^[i].Id + 2000; { agressive but FC not set }
                ShipSortTablePtr^[i].icon  := ICON_SHIP_NO_FC;
                ShipSortTablePtr^[i].color := COLOR_SHIP_NO_FC;
              end;
          end
         else (* (mission = 4) or (enemy <> 0) *)
           begin
            ShipSortTablePtr^[i].key := ShipSortTablePtr^[i].id + 3000; { can fight but not willing  }
            ShipSortTablePtr^[i].icon  := ICON_SHIP_NO_FIGHT;
            ShipSortTablePtr^[i].color := COLOR_SHIP_NO_FIGHT;
           end
        else (* (weapons>1) or (bays>0) or (launchers>0) *)
          begin
            ShipSortTablePtr^[i].key := ShipSortTablePtr^[i].id + 4000; { cannot fight  }
            ShipSortTablePtr^[i].icon  := ICON_SHIP_PASSIVE;
            ShipSortTablePtr^[i].color := COLOR_SHIP_PASSIVE;
          end
       else (*(fuel > 0) *)
        begin
         ShipSortTablePtr^[i].key := ShipSortTablePtr^[i].id + 5000; { ships without fuel }
         ShipSortTablePtr^[i].icon  := ICON_SHIP_NO_FUEL;
         ShipSortTablePtr^[i].color := COLOR_SHIP_NO_FUEL;
        end
       end
       else (* (fuel <>-1) and (mission <> -1) and (enemy <> -1) and (fcode <>#$FF#$FF#$FF) *)
         ShipSortTablePtr^[i].key := ShipSortTablePtr^[i].id + 6000; { enemy ships }

    { Prepare key for hull id}
    if (ShipSortTableType = 2) then
    for i := 1 to ShipSortTableIndex do
     with TTurn^.data^.ship[ShipSortTablePtr^[i].id]^ do
     if (hull <> -1)and(owner <> -1) then
     begin
       ShipSortTablePtr^[i].key  := hull;
       ShipSortTablePtr^[i].key2 := ShipSortTablePtr^[i].id;

       if (OwnShipDesign(player,hull)) then
       begin
         ShipSortTablePtr^[i].icon  := ICON_SHIP_OWN_DESIGN;
         ShipSortTablePtr^[i].color := COLOR_SHIP_OWN_DESIGN;
       end;
     end
     else
     {unknown hull}
     begin
       ShipSortTablePtr^[i].key  := 200;
       ShipSortTablePtr^[i].key2 := ShipSortTablePtr^[i].id;
     end;

    { Prepare key for tow }
    if (ShipSortTableType = 3) then
    for i := 1 to ShipSortTableIndex do
     with TTurn^.data^.ship[ShipSortTablePtr^[i].id]^ do
     if (mission <> -1)and(tow_ship <> -1) then
     begin
       if (ShipSortTablePtr^[i].key = 0) then
          ShipSortTablePtr^[i].key   := ShipSortTablePtr^[i].id  + 2000; {default key}

       if (mission = 7)and (tow_ship > 0) then { mission tow }
       begin
         ShipSortTablePtr^[i].key   := ShipSortTablePtr^[i].id * 2;

         ShipSortTablePtr^[i].icon  := ICON_SHIP_TOWING;
         ShipSortTablePtr^[i].color := COLOR_SHIP_TOWING;

         towed := 0;
         for j:=1 to ShipSortTableIndex do
          if (ShipSortTablePtr^[j].id = tow_ship) then towed := j;

         if (towed > 0) then
         begin
          if (ShipSortTablePtr^[towed].key > 2000)or(ShipSortTablePtr^[towed].key = 0) then
              ShipSortTablePtr^[towed].key := ShipSortTablePtr^[i].id * 2 + 1;

         if (ShipSortTablePtr^[towed].icon = NO_ICON) then
              ShipSortTablePtr^[towed].color := COLOR_SHIP_TOWED
         else
              ShipSortTablePtr^[towed].color := COLOR_SHIP_TOWED_BY_TWO_SHIPS;

         if (TTurn^.data^.ship[ShipSortTablePtr^[towed].id]^.warp > 0) and
            (ShipSortTablePtr^[towed].color = COLOR_SHIP_TOWED) then
              ShipSortTablePtr^[towed].color := COLOR_SHIP_TOWED_HAS_WARP;

         if (ShipSortTablePtr^[towed].icon = NO_ICON) then
              ShipSortTablePtr^[towed].icon  := ICON_SHIP_TOWED;

         end;
       end;
    end
     else
     begin
       if ( UnderTow(ShipSortTablePtr^[i].id) > 0) then
         ShipSortTablePtr^[i].key := ShipSortTablePtr^[i].id + 5000;
     end;

    {Sort}
    if ShipSortTableIndex > 1 then
      for i := 1 to ShipSortTableIndex-1 do
        for j := i+1 to ShipSortTableIndex do
         if ShipSortTablePtr^[j].key < ShipSortTablePtr^[i].key then
          begin
            swap := ShipSortTablePtr^[j];
            ShipSortTablePtr^[j] := ShipSortTablePtr^[i];
            ShipSortTablePtr^[i] := swap;
          end
          else
           if (ShipSortTablePtr^[j].key = ShipSortTablePtr^[i].key) then
           if ShipSortTablePtr^[j].key2 < ShipSortTablePtr^[i].key2 then
          begin
            swap := ShipSortTablePtr^[j];
            ShipSortTablePtr^[j] := ShipSortTablePtr^[i];
            ShipSortTablePtr^[i] := swap;
          end
    end;

    {Find ObjL0}
    for i := 1 to ShipSortTableIndex do
      if lock=ShipSortTablePtr^[i].id or LockS then ObjL0:=(i-1) div 10;

    ShipN:=ObjN;
    with TTurn^.data^ do
    begin
      if showM then
        for i:=1 to 500 do
          if (mines[i]<>nil) and (mines[i]^.x=lx) and (mines[i]^.y=ly) then
          begin
            if lock=i or LockM then ObjL0:=ObjN div 10;
            inc(ObjN);
          end;
      MineN:=ObjN;
      if showI then
        for i:=1 to 50 do
          if (ion[i]<>nil) and (ion[i]^.x=lx) and (ion[i]^.y=ly) then
          begin
            if lock=i or LockI then ObjL0:=ObjN div 10;
            inc(ObjN);
          end;
      IonN:=ObjN;
      if showU then
        for i:=0 to 199 do
          if (worm[i]<>nil) and (worm[i]^.x=lx) and (worm[i]^.y=ly) then
          begin
            if lock=i or LockW then ObjL0:=ObjN div 10;
            inc(ObjN);
          end;
      WormN:=ObjN;
      if showU then
        for i:=1 to 100 do
          if (ufo[i]<>nil) and (ufo[i]^.x=lx) and (ufo[i]^.y=ly) then
          begin
            if lock=i or LockU then ObjL0:=ObjN div 10;
            inc(ObjN);
          end;
      UfoN:=ObjN;
      if showA then
        for i:=1 to nmark do
          with mark^[i] do
          if ((mtype<>mrkNone) and (x=lx) and (y=ly)) or
             ((mtype in [mrkLine,mrkDLine]) and (x+dx=lx) and (y+dy=ly)) then
          begin
            if lock=i or LockA then ObjL0:=ObjN div 10;
            inc(ObjN);
          end;
      MarkN:=ObjN;
    end;
    if lock=0 then PlanN:=0
              else PlanN:=PSearchXY(lx,ly);
  end;

function GoToShipXY (var h:sptr; x,y,k:int) : int;
  { find k-th ship at (x,y) }
  var   i       : int;
  begin
    for i:=1 to NUM_SHIPS do
      if ShipIsHere(i,x,y) then
      begin
        h:=TTurn^.data^.ship[i];
        dec(k);
        if k<=0 then begin GoToShipXY:=i or LockS; Exit end;
      end;
    h:=nil;
    GoToShipXY:=0;
  end;

function GoToShipXYSorted (var h:sptr; x,y,k:int) : int;
  var   i       : int;
  begin
    if (k>0) and (ShipSortTableIndex > 0) and (k<=ShipSortTableIndex ) then
    begin
      h:=TTurn^.data^.ship[ShipSortTablePtr^[k].id];
      GoToShipXYSorted:=ShipSortTablePtr^[k].id or LockS;
      Exit;
    end;
    h:=nil;
    GoToShipXYSorted:=0;
  end;

function ShipNumXY (h:sptr; x,y:int) : word;
  var   i,k     : int;
  begin
    k:=0;
    for i:=1 to NUM_SHIPS do
      if ShipIsHere(i,x,y) then begin
        inc(k);
        if ((h<>nil) and (TTurn^.data^.ship[i]=h)) then Break;
      end;
    ShipNumXY:=k;
  end;

{ Who controls this ship next turn - not in vpadata to avoid cross-link to vpacc }
(* function NewShipControler(sid:int):int;
var s:sptr;
begin
  {$IFDEF VPACC}
  NewShipControler:=GetNewRCOwner(sid);
  {$ELSE}
  s:=TTurn^.data^.ship[sid];
  if (s=NIL) then NewShipControler:=0 else NewShipControler:=s^.owner;
  {$ENDIF}
end; *)

function GoToMinesXY (var m:mptr; x,y,k:int) : int;
  var   i       : int;
  begin
    with TTurn^.data^ do
    for i:=1 to 500 do
      if (mines[i]<>nil) and (mines[i]^.x=x) and (mines[i]^.y=y) then
      begin
        m:=mines[i];
        dec(k);
        if k<=0 then begin GoToMinesXY:=i or LockM; Exit end;
      end;
    m:=nil;
    GoToMinesXY:=0;
  end;

function GoToIonXY (var ii:iptr; x,y,k:int) : int;
  var   i       : int;
  begin
    with TTurn^.data^ do
    for i:=1 to 50 do
      if (ion[i]<>nil) and (ion[i]^.x=x) and (ion[i]^.y=y) then
      begin
        ii:=ion[i];
        dec(k);
        if k<=0 then begin GoToIonXY:=i or LockI; Exit end;
      end;
    ii:=nil;
    GoToIonXY:=0;
  end;

function GoToWormXY (var w:wptr; x,y,k:int) : int;
  var   i       : int;
  begin
    with TTurn^.data^ do
    for i:=0 to 199 do
      if (worm[i]<>nil) and (worm[i]^.x=x) and (worm[i]^.y=y) then
      begin
        w:=worm[i];
        dec(k);
        if k<=0 then begin GoToWormXY:=i or LockW; Exit end;
      end;
    w:=nil;
    GoToWormXY:=0;
  end;

function GoToUfoXY (var u:uptr; x,y,k:int) : int;
  var   i       : int;
  begin
    with TTurn^.data^ do
    for i:=1 to 100 do
      if (ufo[i]<>nil) and (ufo[i]^.x=x) and (ufo[i]^.y=y) then
      begin
        u:=ufo[i];
        dec(k);
        if k<=0 then begin GoToUfoXY:=i or LockU; Exit end;
      end;
    u:=nil;
    GoToUfoXY:=0;
  end;

function GoToMarkXY (var a:MapMark; x,y,k:int) : int;
  var   i       : int;
  begin
    with TTurn^.data^ do
    for i:=1 to nmark do
      with mark^[i] do
      if ((mtype<>mrkNone) and (x=lx) and (y=ly)) or
         ((mtype in [mrkLine,mrkDLine]) and (x+dx=lx) and (y+dy=ly)) then
      begin
        a:=mark^[i];
        dec(k);
        if k<=0 then begin GoToMarkXY:=i or LockA; Exit end;
      end;
    GoToMarkXY:=0;
  end;

procedure ObjList;
  var   h       : sptr;
        m       : mptr;
        ii      : iptr;
        w       : wptr;
        u       : uptr;
        a       : MapMark;
        k       : byte;
        l       : int;
        s       : string[8];
        n       : int;
        ms      : str20;
        mls     : byte absolute s;
        s_      : char;
      {$IFDEF VPACC}
        phc     : PPHostCommand;
      {$ENDIF}
  procedure Highlight;
    begin
      SetFillStyle(SolidFill,8);
      Bar(MX0,l,639,l+7);
      Obj0:=k;
    end;
  begin
    if (distlock<>0) and (dll<400) then Exit;
    if distlock<>0 then Clear(MX0-8,ListY-3,639,dll-2)
    else begin
      Clear(MX0-8,ListY-3,639,479);
      DrawHelpPrompt;
    end;
    with TTurn^.data^ do
    begin
    {$IFDEF VPACC}
    { this re-uses the place where VPA usually says '<Planet>'. When
      we are at a planet, there's no point in going to one :-) }
    if (PlanN<>0) and (ltype=LockP) and (turn=today) and PHOST and EnableGive
        and (planet[PlanN]<>nil) and (planet[PlanN]^.owner=player) then
    begin
      phc := GetPHostCmd(phc_GivePlanet, PlanN);
      if phc<>nil then begin
        SetColor(Green);
        OutTextXY(MX0,ListY,'Giv:' + phc^.arg);
      end else begin
        SetColor(cPInfo);
        OutTextXY(MX0,ListY,'Give');
      end;
      if RWMode then begin
        SetColor(White);
        OutTextXY(MX0+2*8,ListY,'v');
      end;
    end;
   {$ENDIF}
   end;
    if lock=0 then Exit;
    Obj0:=0;
    k:=ObjL0*10+1; l:=378;
    while (k<=ObjN) and (k<=ObjL0*10+10) do
    begin
      if k<=ShipN then
      begin
        n:=GoToShipXYSorted(h,lx,ly,k);
        if h<>nil then
        begin
          if n=lock then Highlight;
          SetColor(RaceColor[h^.owner,_S_]);
          with h^ do
          begin
          if hull<>-1 then
            if owner=player then OutTextXY(MX0+24,l,name)
                            else OutTextXY(MX0+24,l,Hulls[hull].name)
          else begin
            if mass=-1 then s:='' else s:=' ('+NStr0(mass)+'kt)';
            OutTextXY(MX0+24,l,'Ship '+NStr0(n and LockLo)+s);
          end;
            if (ShipSortTablePtr^[k].icon <> NO_ICON) then
            begin
              SetColor(ShipSortTablePtr^[k].color);
              DrawMark (MX0+0-5,l+4+MarkOffsetY(ShipSortTablePtr^[k].Icon),
                       ShipSortTablePtr^[k].color,
                       ShipSortTablePtr^[k].Icon);
            end;
          end;
          {Display status of object on the act-list.}
          if ((actlist[n and LockLo] and LockS) = LockS) and ShowCheckMark then
            DrawCheckMark( MX0+16+1, l+1, CheckMarkColor);
        end;
      end else
      if k<=MineN then
      begin
        n:=GoToMinesXY(m,lx,ly,k-ShipN);
        if n=lock then Highlight;
        SetColor(RaceColor[m^.owner,_M_]);
        if m^.web and 1=0 then s:='field' else s:='WEB';
        OutTextXY(MX0+24,l,'Mine '+s+' '+NStr(n and LockLo));
      end else
      if k<=IonN then
      begin
        n:=GoToIonXY(ii,lx,ly,k-MineN);
        if n=lock then Highlight;
        SetColor(cIInfo);
        OutTextXY(MX0+24,l,'Ion storm '+NStr(n and LockLo));
      end else
      if k<=WormN then
      begin
        n:=GoToWormXY(w,lx,ly,k-IonN);
        if n=lock then Highlight;
        SetColor(cWInfo);
        OutTextXY(MX0+24,l,'Wormhole '+NStr0(n and LockLo));
      end else
      if k<=UfoN then
      begin
        n:=GoToUfoXY(u,lx,ly,k-WormN);
        if n=lock then Highlight;
        SetColor(u^.color);
        OutTextXY(MX0+24,l,u^.name);
      end
      else
      if k<=MarkN then
      begin
        n:=GoToMarkXY(a,lx,ly,k-UfoN);
        if n=lock then Highlight;
        SetColor(LightGray);
        OutTextXY(MX0+24+16,l,'marker');
        DrawMark(MX0+24+4,l+4+MarkOffsetY(a.mtype),a.color,a.mtype);
      end;
      Str(k:2,s);
      SetColor(cSInfo);
      OutTextXY(MX0,l,s);
      SetColor(White);
      OutTextXY(MX0+8,l,s[2]);
      inc(l,8);
      inc(k);
    end;
    SetColor(White);
    case ShipSortTableType of
      0 : s_:=' ';
      1 : s_:='B';
      2 : s_:='H';
      3 : s_:='T';
    end;
    OutTextXY(MX0-8,ListY+12*8,s_);
    if ObjL0>0 then OutTextXY(MX0+24,ListY+12*8,'PgUp');
    if (ObjN>0) and (ObjL0<(ObjN-1) div 10) then OutTextXY(640-4*8,ListY+12*8,'PgDn');
    if PlanN<>0 then
    begin
      if (lbase<>nil) or (ltype<>LockP) then
      begin
        SetColor(cPInfo);
        OutTextXY(640-8*8,ListY,'<Planet>');
        SetColor(White);
        OutTextXY(640-7*8,ListY,'P');
      end;
      with TTurn^.data^ do
      if (lbase=nil) and (eplan[PlanN].activity and EP_Base<>0) and
         (planet[PlanN]<>nil) and (planet[PlanN]^.build<>1) then
      begin
        k:=IIF(ltype=LockP,6,18);
        SetColor(IIF((base[PlanN]<>nil) or (newplan[PlanN] and NP_Base<>0),cPInfo,cOPInfo));
        OutTextXY(640-k*8,ListY,'<Base>');
        if base[PlanN]<>nil then
        begin
          SetColor(White);
          OutTextXY(640-(k-1)*8,ListY,'B');
        end;
      end;
    end;
  end;

function CheckClone (baseId:int) : int;
  { -1 - impossible, 0 - possible but not active, 1..999 - id being cloned }
  var   i,x,y,k : int;
        h       : sptr;
  begin
    CheckClone:=-1;
    if (not Cloning) or (CloneCost[player]=32767) then Exit;
    with TTurn^.data^ do
    begin
      x:=xyplan[baseId,1];
      y:=xyplan[baseId,2];
    end;
    for i:=1 to ShipNumXY(NIL,x,y) do
    begin
      k:=GoToShipXY(h,x,y,i);
      if (h<>nil) and (h^.when=turn) and (h^.owner=player) and not OwnShipDesign(player,h^.hull) then
        if h^.fcode<>'cln' then CheckClone:=0
                           else begin CheckClone:=k and LockLo; Exit end;
    end;
  end;

procedure HullTypes;
  const HY0     = 176;
        HY1     = 344;
  var   i,j,l   : word;
        myrace  : int;
  procedure ScanAllHulls;
    var i,k,j0  : int;
    begin
      k:=1; j0:=j;
      for i:=1 to 105 do
      begin
        if HullFit(i,lship^.mass1,lship^.mass2) then
        begin
          if j=HY1 then
            if k<ScanH then begin j:=j0; inc(k) end
                       else begin hOver:=Yes; Break end;
          if j<HY1 then
          begin
            if k=ScanH then OutTextXY(MX0,j,Hulls[i].name);
            inc(j,8);
          end;
        end;
      end;
      SetColor(White);
      if ScanH>1 then OutTextXY(MX0,j,'Home');
      if hOver   then OutTextXY(640-3*8,j,'End');
    end;
  begin
    Clear(MX0,HY0+16,639,344+7);
    eAllH:=No; hOver:=No;
    with lship^ do
    begin
      SetColor(cSInfo);
      j:=HY0+16;
      if AllH then ScanAllHulls
      else begin
        if TrueHullByRace then myrace:=Race[owner]
                          else myrace:=owner;
        for i:=1 to 20 do
        begin
          l:=RaceHull[myrace,i];
          if HullFit(l,mass1,mass2) then
          begin
            OutTextXY(MX0,j,Hulls[l].name);
            inc(j,8);
          end;
        end;
      end;
      if j>=HY0+24 then
      begin
        SetColor(White);
        OutTextXY(MX0+14*8,HY0,'A');
        SetColor(IIF(AllH,cSInfo+8,DarkGray));
        OutTextXY(MX0+13*8,HY0,'( ll)');
        SetColor(cSInfo);
        eAllH:=Yes;
      end;
      if j>HY0+24 then OutTextXY(MX0,HY0,'It might be:')
      else if j=HY0+24 then
        begin
          if (not AllH) or (ScanH=1) then
            OutTextXY(MX0,HY0+8,'I think it is a')
        end
      else begin
        SetColor(Red);
        OutTextXY(MX0,HY0,'This ship COUDN''T');
        OutTextXY(MX0,HY0+8,'be constructed');
        OutTextXY(MX0,HY0+16,'by '+RaceName[owner]);
        SetColor(cSInfo);
        j:=HY0+48;
        ScanAllHulls;
        if j>HY0+56 then OutTextXY(MX0,HY0+32,'It might be:')
        else if j=HY0+56 then OutTextXY(MX0,HY0+40,'It is SURELY a');
      end;
    end;
  end;

procedure SayMoving;            { currently called for lship only }
  var   e,f     : int;
        towed   : int;
        s       : string[2];
  begin
    Clear(MX0,128,639,136+7);
    with lship^ do
    begin
      towed:=UnderTow(lock and LockLo);
      if towed<>0 then
      begin
        SetColor(Yellow);
        OutTextXY(MX0,128,'Being towed by '+NStr0(towed));
      end;
      SetColor(cSInfo);
      if ((warp<>-1) and (warp=0)) or (wx or wy=0) then
        begin if towed=0 then OutTextXY(MX0,128,'Not moving') end
      else begin
        if mission=-1 then
        begin
          if (towed=0) and (enemy<>-1) then OutTextXY(MX0,128,'Heading: '+NStr0(enemy));
        end
        else if warp<>-1 then
        begin
          if towed=0 then OutTextXY(MX0,128,'Dest: '+Location(x+wx,y+wy));
          CalcMovement(lship,StdTowPtr(lship^),f,e);
          if e>0 then OutTextXY(640-7*8,136,'ETA:'+NStrMax(e,3,'+'));
        end;
      end;
      if warp<>-1 then
      begin
        OutTextXY(MX0,136,'Warp:');
        if towed<>0 then
          begin if warp>0 then SetColor(Yellow) end
        else if (damage>19) and (warp>IIF(race[owner]=2,15,10)-Trunc((damage-Sup div 5)/10)) then
          SetColor(LightRed)
        else if (El<>-1) and (warp<>GetSafeWarp(El)) then SetColor(IIF(warp>GetSafeWarp(El),LightRed,Yellow));
        OutTextXY(MX0+6*8,136,NStr0(warp));
        if RWMode and (turn=today) and (distlock=0) and (owner=player) then
        begin
          SetColor(White);
          OutTextXY(MX0,136,'W');
        end;
        SetColor(cSInfo);
      end;
    end;
  end;

procedure SayMission (h:sptr; number:int);
  var   s       : str20;
        mp      : MITptr;
        xx      : int;
  begin
    SetColor(cSInfo);
    with h^ do begin
      if mission>=0 then begin
        if mission<=15 then begin
          if mission<>9 then s:=Missions[mission]
                        else begin
                          s:=SpecMisn[Race[RealShipOwner(number)]];
                          if (Race[RealShipOwner(number)]=3) and (upcase(fcode[1])<>'X') then
                            s:=s+' D.'
                          else SetColor(Yellow);
                        end;
        end else begin
          mp:=MIT;
          while (mp<>nil) and (mp^.mission<>mission) do mp:=mp^.next;
          if mp<>nil then s:=mp^.name
                     else s:='Mission '+NStr0(mission);
          xx:=MX0+6*8;
          if (mp=nil) or (mp^.param and MIT_I<>0) then begin
            OutTextXY(xx,200,'I='+NStr0(intr_ship));
            inc(xx,6*8);
          end;
          if (mp=nil) or (mp^.param and MIT_T<>0) then
            OutTextXY(xx,200,'T='+NStr0(tow_ship));
        end;
        if mission in [7,8] then
        begin
          s:=s+' '+NStr0(IIF(mission=7,tow_ship,intr_ship));
          SetColor(Yellow);
          if (mission=7) and (not OneEngineTow) and
             (Hulls[hull].engines<2) then SetColor(LightRed);
        end else
        { FIXME: handle Super Spy here? }
        if (mission in [10,ExtMissionsStartAt+10]) and (damage>=CloakPreventDamage) and
           (Sup<(damage-CloakPreventDamage+1)*5) then SetColor(LightRed);
        OutTextXY(MX0+6*8,192,s);
        SetColor(cSInfo);
        OutTextXY(MX0,192,'Misn:');
      end;
    end;
  end;

procedure ShipInfo;
  var   s       : string[18];
        s1      : string[4];
        s2      : string[79];
        h       : sptr;
        i,j,l   : int;
        number  : word;
        b       : bptr;
        p       : pptr;
{$IFDEF TASKS}
        tsk     : taskptr;
{$ENDIF}
        hf      : int;
        equip_known  : boolean;
        new_function : boolean;
       {$IFDEF vpacc}
        phc     : PPHostCommand;
        pha     : PHullFunctionArray;
        nhf     : int;
        thf     : THullFunction;
       {$ENDIF}

  begin
    if ltype<>LockS then Exit;
    number:=lock and LockLo;
    if (number=0) or (number>999) then Exit;
    Clear(MX0,72,639,359);
    h:=TTurn^.data^.ship[number];
    if (h=nil) or (h^.when<>turn) then Exit;
    if PlanN<>0 then b:=TTurn^.data^.base[PlanN] else b:=nil;
    with h^ do
    begin
      lship:=h;
      if ((actlist[number] and LockS)<>LockS) or (turn<>today)  then SetColor(cActive)
      else SetColor(cNonActive);
      i := ShipExperience(number);
      if i >= 0 then s := ' (L' + NStr0(i) + ')' else s := '';
      OutTextXY(MX0,72,'Ship '+NStr(number) + s);
      OutTextXY(MX0,80,'Race: '+RaceName[owner]);
      if hull<>-1 then OutTextXY(MX0,88,Hulls[hull].name);
      SetColor(cSInfo);
      OutTextXY(MX0,112,'at '+Location(x,y));
      if name[1]<>#$FF then
      begin
        SetColor(LightGray);
        OutTextXY(MX0,96,name);
      end;
      if mass<>-1 then begin
        if hull<>-1 then
        begin
          if (owner<>player) and (not IsData[owner]) and (turn=today) then OutTextXY(632,72,'F');
        end
        else begin
          if turn=today then SetColor(white);
          OutTextXY(MX0+9*8,88,'H');
          SetColor(cSInfo);
          OutTextXY(MX0,88,'(unknown  ull)');
          AllH:=No; ScanH:=1; HullTypes;
        end;
      end {mass known};
      SayFuel;
      SayMoving;
      if mass<>-1 then
      begin
        s:=NStr0(mass); l:=Length(s); s2:='';
        if ShowMassDiff and (owner<>player) and (TTurn^.prev<>nil) then begin
          if (TTurn^.prev^.data=nil) then LoadTurnData(TTurn^.prev);
          if (TTurn^.prev^.data<>nil) and (TTurn^.prev^.data^.ship[number]<>nil)
              and (TTurn^.prev^.data^.ship[number]^.hull=hull) and (TTurn^.prev^.data^.ship[number]^.mass<>-1) then begin
            s2:=' ('+NSStr(mass-TTurn^.prev^.data^.ship[number]^.mass)+')';
            inc(l,Length(s2));
          end;
        end;
        if l<=9 then s:=s+' kt';
        if l<=12 then s:=s+s2;
        OutTextXY(MX0,160,'Mass: '+s);
      end;
      equip_known := (hull<>-1) and (El and Wl and Tl<>-1);
      if (mass<>-1) and (hull<>-1) and (fcode = #$FF#$FF#$FF) and not equip_known then
      begin
        { more information on enemy ships }
        SetColor(cSInfo);
        OutTextXY(MX0,216,'Hull mass: '+NStr0(Hulls[hull].mass)+' kt');
        OutTextXY(MX0,224,'Engines  : '+NStr0(Hulls[hull].engines) );
        if (Hulls[hull].weapons > 0) then
         OutTextXY(MX0,232,'Max beams: '+NStr0(Hulls[hull].weapons) );
        if (Hulls[hull].bays > 0) then
         OutTextXY(MX0,240,'Max bays : '+NStr0(Hulls[hull].bays) );
        if (Hulls[hull].launchers > 0) then
         OutTextXY(MX0,240,'Max lunch: '+NStr0(Hulls[hull].launchers) );

        OutTextXY(MX0,176,'Max crew : '+NStr0(Hulls[hull].crew) );
        OutTextXY(MX0,260,'Max cargo: '+NStr0(Hulls[hull].cargo)+' kt' );
        OutTextXY(MX0,268,'Max fuel : '+NStr0(Hulls[hull].fuel)+' kt' );

        OutTextXY(MX0,192,'Mine hit : '+NStr0(Min(100,Trunc( 100.0 * MineHitDamageFor100KT / Hulls[hull].mass )))+' %' );
        OutTextXY(MX0,200,'Web hit  : '+NStr0(Min(100,Trunc( 100.0 * WebHitDamageFor100KT / Hulls[hull].mass )))+' %' );

        {special hull functions }
        j:=0;
        new_function := true;
        {$IFDEF VPACC}
        nhf := EnumHullfuncsForShip(number, NIL, 0, hf_NoRacialAbilities);
        if nhf<>0 then begin
          pha := Malloc(nhf * Sizeof(THullFunction));
          if pha<>nil then begin
            EnumHullfuncsForShip(number, pha, 0, hf_NoRacialAbilities);
            for i:=1 to nhf do begin
              thf := pha^[i];
              if ((thf.BasicFunction) in [SPC_Alchemy,SPC_Refinery]) and not Alchemy then Continue;
              if ((thf.BasicFunction) in [SPC_HeatsTo50..SPC_HeatsTo50]) and not Terraformers then Continue;
              if ((thf.BasicFunction)=SPC_HyperDrive) and not HyperDrive then Continue;
              if ((thf.BasicFunction) in [SPC_Chunneling,SPC_ChunnelSelf,SPC_ChunnelOthers,SPC_ChunnelTarget])
               and not Chunnel then Continue;
              if ((thf.BasicFunction) in [SPC_GloryDeviceLow,SPC_GloryDeviceHigh]) and not GloryDevice then Continue;
              if ((thf.BasicFunction)=SPC_AntiCloak) and not AntiCloak then Continue;
              if ((thf.BasicFunction)=SPC_ImperialAssault) and not ImperialAssault then Continue;
              if ((thf.BasicFunction)=SPC_AdvancedRefinery) and not AdvancedRefinery then Continue;
              if ((thf.BasicFunction) in [SPC_Bioscan,SPC_FullBioscan]) and not BioScanners then Continue;
              if ((thf.BasicFunction)=SPC_ScansAllWormholes) and not Wormholes then Continue;
              if ((thf.BasicFunction)=SPC_Gambling) and not Gambling then Continue;
              if ((thf.BasicFunction)=SPC_RamScoop) and (RamScoop=0) then Continue;

              if new_function then
              begin
                new_function := false;
                inc(j);
              end;
              OutTextXY(MX0,284+j*8,GetBasicFunctionName(thf.BasicFunction));
              inc(j);
            end;
            FreeMem(pha, nhf * Sizeof(THullFunction));
          end;
        end;
        {$ELSE}
        for i:=1 to HullFN do
        begin
          hf:=HullFunc^[i];
          if Lo(hf)=hull then
          begin
            if (HullFuncs(Hi(hf)) in [hfAlchemy,hfRefinery]) and not Alchemy then Continue;
            if (HullFuncs(Hi(hf)) in [hfHeat50..hfHeat100]) and not Terraformers then Continue;
            if (HullFuncs(Hi(hf))=hfHyperDrive) and not HyperDrive then Continue;
            if (HullFuncs(Hi(hf))=hfChunneling) and not Chunnel then Continue;
            if (HullFuncs(Hi(hf)) in [hfGloryDeviceL,hfGloryDeviceH]) and not GloryDevice then Continue;
            if (HullFuncs(Hi(hf))=hfAntiCloak) and not AntiCloak then Continue;
            if (HullFuncs(Hi(hf))=hfImperialAssault) and not ImperialAssault then Continue;
            if (HullFuncs(Hi(hf))=hfAdvRefinery) and not AdvancedRefinery then Continue;
            if (HullFuncs(Hi(hf)) in [hfBioscan,hfFullBioscan]) and not BioScanners then Continue;
            if (HullFuncs(Hi(hf))=hfAllWormScan) and not Wormholes then Continue;
            if (HullFuncs(Hi(hf))=hfGambling) and not Gambling then Continue;
            if (HullFuncs(Hi(hf))=hfRamScoop) and (RamScoop=0) then Continue;

            if new_function then
            begin
              new_function := false;
              inc(j);
            end;

            ItemStr(HullFuncName,Hi(hf),s2);
            OutTextXY(MX0,284+j*8,s2);
            inc(j);
          end;
        end {for each hull function};
        {$ENDIF}
        if (j>2) then OutTextXY(MX0,284,'Hull functions:' )
        else if (j>1) then OutTextXY(MX0,284,'Hull function:' );
      end {mass and hull known [target]};
      if fcode<>#$FF#$FF#$FF then
      begin
        OutTextXY(MX0,168,'FCode:');
        WriteFCode(MX0+7*8,168,cSInfo,fcode);
      end;
      if (crew<>-1) and (hull<>-1) then
      begin
        OutTextXY(MX0,176,'Crew :');
        SetColor(IIF(crew<>Hulls[hull].crew,Yellow,cSInfo));
        OutTextXY(MX0+7*8,176,NStr0(crew));
        if (b<>nil) and (b^.fOp=1) and (b^.fShip=number) and (crew<>Hulls[hull].crew) then
        begin
          SetColor(LightGreen);
          OutTextXY(640-7*8,176,'(fixed)');
        end;
        SetColor(cSInfo);
      end {crew known};
      if (damage<>-1) and (hull<>-1) then
      begin
        OutTextXY(MX0,184,'Damage:');
        if damage>0 then
        begin
          i:=damage;
          SetColor(LightRed);
          OutTextXY(MX0+8*8,184,NStr(i)+'%');
          if (b<>nil) and (b^.fOp=1) and (b^.fShip=number) then i:=0
          else i:=Max(i-Sup div 5-IIF((Race[owner]=6) and (mission=9) and (fuel>0),10,0),0); {fixed quapla}
          if i<damage then begin
            if i<=0 then
            begin
              if (damage>0) then begin
                SetColor(LightGreen);
                OutTextXY(640-7*8,184,'(fixed)');
              end;
            end else begin
              SetColor(Yellow);
              OutTextXY(640-6*8,184,'('+NStr(i)+'%)');
            end;
          end;
          SetColor(cSInfo);
        end;
      end {damage known};
      SayMission(h,number);
      if (mission<>-1) and (enemy<>-1) then
        OutTextXY(MX0,200+IIF(mission>15,8,0),'Enemy: '+RaceName[enemy]);
      if equip_known then
      begin
        OutTextXY(MX0,215,'Equipment:');
        if El<>-1 then
        begin
          s:='';
(* Show always numer of engines
          if (not OneEngineTow) and (Hulls[hull].engines=1) then s:='1 ';
          if (Phost) then begin  *)
            str(Hulls[hull].engines,s);
            s:=s+' ';
(*          end; *)
          OutTextXY(MX0,224,' '+s+Proper(Hulls[hull].engines,Engines[El].name));
        end;
        if (Wl<>-1) and (weapons<>-1) then
        begin
          if weapons=0 then OutTextXY(MX0,232,' No main weapons')
          else OutTextXY(MX0,232,' '+NStr(weapons)+' '+Proper(weapons,Beams[Wl].name));
        end;
        if bays or launchers=0 then OutTextXY(MX0,240,' No bays/launchers')
        else begin
          if bays>0 then OutTextXY(MX0,240,' '+NStr(bays)+Proper(bays,' Fighter bay')) else
          if launchers>0 then OutTextXY(MX0,240,' '+NStr(launchers)+Proper(launchers,' '+Torps[Tl].name+' tube'));
        end;
      end {equipment known};
      if (hull<>-1) and (colonists<>-1) and (Sup<>-1) and (credits<>-1) and
         (fuel<>-1) and (T<>-1) and (D<>-1) and (M<>-1) and (TFnum<>-1) and
         (CN<>-1) and (CT<>-1) and (CD<>-1) and (CM<>-1) and (CC<>-1) and (CS<>-1) and (CPl<>-1) and
         (TN<>-1) and (TT<>-1) and (TD<>-1) and (TM<>-1) and (TC<>-1) and (TS<>-1) and (TSh<>-1) then
      begin
        OutTextXY(MX0,CY0,'Cargo: '+NStr0(colonists+Sup+T+D+M+TFnum)+'/'+NStr0(Hulls[hull].cargo)+' kt');
        OutTextXY(MX0,CY0+8,'Ne: '+NStr(fuel));
        OutTextXY(MX0,CY0+16,'Tr: '+NStr(T));
        OutTextXY(MX0,CY0+24,'Du: '+NStr(D));
        OutTextXY(MX0,CY0+32,'Mo: '+NStr(M));
        OutTextXY(MX0,CY0+40,'Sp: '+NStr(Sup));
        OutTextXY(MX0,CY0+48,'Cl: '+NStr(colonists));
        OutTextXY(MX0,CY0+56,'$$: '+NStr(credits));
        if bays or launchers<>0 then
        begin
          if bays=0 then s:='Tp: ' else s:='Fg: ';
          OutTextXY(MX0,CY0+64,s+NStr(TFnum));
        end;
        if CN or CT or CD or CM or CC or CS<>0 then
        begin
          SetColor(cPInfo);
          OutTextXY(MX0+9*8,CY0+8,NStr(CN));
          OutTextXY(MX0+9*8,CY0+16,NStr(CT));
          OutTextXY(MX0+9*8,CY0+24,NStr(CD));
          OutTextXY(MX0+9*8,CY0+32,NStr(CM));
          OutTextXY(MX0+9*8,CY0+40,NStr(CS));
          OutTextXY(MX0+9*8,CY0+48,NStr(CC));
          if CPl=0 then OutTextXY(MX0,CY0+88,'Jettison cargo!')
                   else OutTextXY(MX0,CY0+88,'Unload to '+NStr0(CPl));
        end;
        if TN or TT or TD or TM or TC or TS<>0 then
        begin
          SetColor(LightBlue);
          OutTextXY(MX0+14*8,CY0+8,NStr(TN));
          OutTextXY(MX0+14*8,CY0+16,NStr(TT));
          OutTextXY(MX0+14*8,CY0+24,NStr(TD));
          OutTextXY(MX0+14*8,CY0+32,NStr(TM));
          OutTextXY(MX0+14*8,CY0+40,NStr(TS));
          OutTextXY(MX0+14*8,CY0+48,NStr(TC));
          OutTextXY(MX0,CY0+80,'Transfer to '+NStr0(TSh));
          SetColor(red);
          if fuel=0 then OuttextXY(MX0,CY0+72,'no Fuel, no Transf.') 
          else if (TT+TD+TM+TS+TC+T+D+M+Sup+colonists+TFNum>Hulls[hull].cargo) then {Overload}
            if VPAExtra then OuttextXY(MX0,CY0+72,'Transfer trimmed')
            else OuttextXY(MX0,CY0+72,'Transfer spoiled')
          else if ShipIsCloaking(TTurn^.data^.ship[TSh]^.owner,TTurn^.data^.ship[TSh]^.mission) then {Destination Cloaked} 
            if VPAExtra then OuttextXY(MX0,CY0+72,'Transfer to cloaked')
            else OuttextXY(MX0,CY0+72,'No Transfer to cloaked') ; 
        end;
      end{cargo known};
      {Display status of object on the act-list.}
      if ((actlist[number] and LockS) = LockS) and ShowCheckMark then begin
        DrawCheckMark( 623, 72, CheckMarkColor);
        {SetColor(CheckMarkColor); OutTextXY(623,72,CheckMarkChar);}
      end;
   {$IFDEF VPACC}
      if (turn=today) and PHOST and EnableRemote then begin
        SetColor(cSInfo);
        case GetNewRCFlag(number) of
          rc_Forbidden: SetColor(Red);
          rc_RemoteControlled, rc_Applying, rc_OurRemoteControlled: SetColor(Green);
          rc_Dropping: SetColor(Yellow);
        end;
        OutTextXY(MX0,CY0+96,'RCtl');
        i:=RealShipOwner(number);
        if i<>owner then begin
          OutTextXY(MX0+5*8,CY0+96,'('+nstr(i)+')');
        end else case GetNewRCFlag(number) of
          rc_Forbidden:        OutTextXY(MX0+5*8,CY0+96,'no');
          rc_Normal:           OutTextXY(MX0+5*8,CY0+96,'allow');
          rc_Applying:         OutTextXY(MX0+5*8,CY0+96,'req''d');
          rc_Dropping:         OutTextXY(MX0+5*8,CY0+96,'drop');
          rc_OurRemoteControlled: OutTextXY(MX0+5*8,CY0+96,'ours');
        end;
        if RWMode then begin
          SetColor(White);
          OutTextXY(MX0+8,CY0+96,'C');
        end;
      end;
      if (turn=today) and PHOST and EnableGive and (owner=player) then begin
        phc := GetPHostCmd(phc_GiveShip, number);
        if phc<>nil then begin
          SetColor(Green);
          OutTextXY(MX0+12*8,CY0+96,'Giv:' + phc^.arg);
        end else begin
          SetColor(cSInfo);
          OutTextXY(MX0+12*8,CY0+96,'Give');
        end;
        if RWMode then begin
          SetColor(White);
          OutTextXY(MX0+14*8,CY0+96,'v');
        end;
      end;
   {$ENDIF}
      if RWMode and (turn=today) and (distlock=0) and (owner=player) then
      begin
        SetColor(White);
        OutTextXY(632,72,'N');
        OutTextXY(MX0,136,'W');
        OutTextXY(MX0,168,'F');
        OutTextXY(MX0,192,'M');
        OutTextXY(MX0,200+IIF(mission>15,8,0),'E');
        OutTextXY(MX0,CY0,'C');
        if ShipN>1 then
        begin
          if TSh=0 then
          begin
            SetColor(cSInfo);
            OutTextXY(MX0+8,CY0+80,'ransfer');
          end;
          SetColor(White);
          OutTextXY(MX0,CY0+80,'T');
        end;
        if PlanN<>0 then
        begin
          p:=TTurn^.data^.planet[PlanN];
          if (p<>nil) and (p^.when=turn) and (p^.owner=player) then
          begin
            if T+D+M+Sup+IIF(Gambling and (IsShipFunc(h^,hfGambling)),0,colonists)+credits>0 then
            begin
              SetColor(cSInfo);
              OutTextXY(MX0,CY0+88,'Unload');
              SetColor(White);
              OutTextXY(MX0,CY0+88,'U');
            end;
            if bays or launchers<>0 then
            begin
              if (b<>nil) and (b^.owner=player) then begin
                if ((bays>0) and PlanetCanBuildFighter(p))
                 or ((launchers>0) and (p^.T>0) and (p^.D>0) and (p^.M>0) and (p^.supplies+p^.funds>=Torps[Tl].cost))
                then begin
                  SetColor(cSInfo);
                  OutTextXY(MX0+9*8,CY0+64,'Buy more');
                  SetColor(White);
                  OutTextXY(MX0+11*8,CY0+64,'y');
                end;
              end;
              i:=Hulls[hull].cargo-T-D-M-Sup-colonists-TFnum;
              if ((launchers>0) and (i>=3) and (p^.T>0) and (p^.D>0) and (p^.M>0) and
                  (MinL(p^.funds+p^.supplies,10000-credits)>=Torps[Tl].cost)) or
                 ((Race[RealShipOwner(number)] in [9..11]) and (bays>0) and
                  (i>=10) and (p^.T>=3) and (p^.M>=2) and (p^.supplies>=5)) then
              begin
                SetColor(cSInfo);
                OutTextXY(640-10*8,CY0+88,'Load&Build');
                SetColor(White);
                OutTextXY(640-10*8,CY0+88,'L');
              end;
            end;
          end;
          if (b<>nil) and (b^.owner=player) then
          begin
            if (b^.fOp=2) and (b^.fShip=number) then
            begin
              SetColor(Yellow);
              OutTextXY(MX0,351,'BEING RECYCLED');
            end;
            if (damage>0) or (crew<>Hulls[hull].crew) then
            begin
              SetColor(White);
              OutTextXY(MX0+1*8,CY0+72,'i');
              SetColor(Yellow);
              OutTextXY(MX0,CY0+72,'F x');
              if (b^.fOp=1) and (b^.fShip=number) then OutTextXY(MX0+3*8,CY0+72,'ing ship');
            end;
          end;
        end{orbiting a planet};
{$IFDEF TASKS}
        tsk:=FindTask(lock);
        if tsk<>nil then
        begin
          SetColor(LightGray);
          OutTextXY(640-6*8,72,'<  >');
          if tsk^.flag and tfDeac=0 then SetColor(White);
          OutTextXY(640-5*8,72,'F8');
        end;
{$ENDIF}
      end{today, our ship};
      if (owner<>player) and (not IsData[owner]) and
         (mass<>-1) and (mass<>0) and ((mass<MinSM) or (mass>MaxSM) or
           ((hull<>-1) and (not HullFit(hull,mass,mass)))) then
      begin
        Clear(MX0,215,639,344+7);
        SetColor(LightRed);
        OutTextXY(MX0,216,'!!! ATTENTION !!!');
        if (hull<>-1) and (owner<>player) then
        begin
          OutTextXY(MX0,224,' WRONG HULL TYPE');
          OutTextXY(MX0,232,'   ASSUMPTION!');
          if turn=today then
          begin
            OutTextXY(MX0,272,'Press F to cancel');
            OutTextXY(MX0,280,' this assumption');
            SetColor(White);
            OutTextXY(MX0+6*8,272,'F');
          end;
        end
        else begin
          OutTextXY(MX0,224,'    DATA ERROR');
          OutTextXY(MX0,232,'   OR CHEATING!');
        end;
        if (mass<MinSM) or (mass>MaxSM) then OutTextXY(MX0,248,'NEITHER ship can')
                                        else OutTextXY(MX0,248,'This ship CAN NOT');
        OutTextXY(MX0,256,'have such mass');
      end;
    end;
    if not DSdrawn then DrawPath;
    if not SRdrawn then DrawShipRange;
    if not DWdrawn then DrawWarpCircles;
    DrawPlanetYnfos;
    ObjList;
    ExtFeatInfoDisplayHook;
  end;

procedure MineInfo;
  var   s       : string[12];
        s1      : string[12];
        m       : mptr;
        i,k,Y0  : int;
        number  : word;
        nd,dd   : long;
        c       : byte;
        p       : double;
        safe1   : double;
        safe2   : double;
        r       : long;
        decunits: word;           {need unsigned max. 65535}
        sweptunits: word;           {need unsigned max. 65535}
 {      robot   : boolean;}
  begin
    if ltype<>LockM then Exit;
    number:=lock and LockLo;
    if (number=0) or (number>500) then Exit;
    m:=TTurn^.data^.mines[number];
    if m<>nil then
    with m^ do
    begin
      {Make sure our units already contain this turn's mine decay.}
      if (web and 4=4) then
        decunits:=DecayMineUnits( units, (web and 1=1) )
      else
        decunits:=units;

      ClearInfo;
      SetColor(White);
      if (web and 2=2) and (owner=12) then s:='Someone''s'
                                      else s:=RaceName[owner];
      OutTextXY(MX0,72,s);
      if web and 1=0 then s:='field ' else s:='WEB ';
      OutTextXY(MX0,80,'mine '+s+NStr(number));
      SetColor(LightGray);
      if when=turn then OutTextXY(MX0,88,'(now)')
                   else OutTextXY(MX0,88,'('+NStr(turn-when)+Proper(turn-when,' turn')+' ago)');
      c:=RaceColor[owner,_M_];
      SetColor(c);
      OutTextXY(MX0,104,'Center:('+NStr0(x)+','+NStr0(y)+')');
      OutTextXY(MX0,112,'Radius: '+NStr0(MineRadius(decunits)));
      s:=NStr00(decunits,'SWEPT OUT');
      if (web and 2=2) and (decunits>0) then s:='÷'+s;
      OutTextXY(MX0,120,'Units : '+s);
      {Highlight 'R' in Radius + 'U' in Units}
      SetColor(White);
      OutTextXY(MX0,112,'R');
{      OutTextXY(MX0,120,'U');   Still to do.... Quapla}
      SetColor(c);
      with TTurn^.data^ do
      begin
        k:=0; nd:=1000000000;
        for i:=1 to 500 do
        begin
          if ( ((owner=player) or IsData[owner]) and ((planet[i]=nil) or (planet[i]^.when<>turn)) ) or
             ((eplan[i].when=turn) and (eplan[i].owner<>owner)) or
             ((planet[i]<>nil) and (planet[i]^.when=turn) and (planet[i]^.owner<>owner))
            then Continue;
          dd:=Distance2(x,y,xyplan[i,1],xyplan[i,2]);
          if dd<nd then begin nd:=dd; k:=i end;
        end;
        if k<>0 then
        begin
          {New Layout - I need the Space.... Quapla}
          if (owner=player) then OutTextXY(MX0,136,' FC-P:'+NStr(k))
                            else OutTextXY(MX0,136,'Nxt-P:'+NStr(k));
          with planet[k]^ do
          if (planet[k]<>nil) and (when=turn) and (fcode<>#$FF#$FF#$FF) then
          begin
            OutTextXY(MX0+10*8,136,' FC:');
            WriteFCode(MX0+14*8,136,c,fcode);
          end;
        end;
        k:=0;
        for i:=1 to 500 do
          if (eplan[i].owner=owner) and (planet[i]<>nil) and (planet[i]^.when=turn) and
             (Copy(planet[i]^.fcode,1,2)='mf') then k:=i;
        if k<>0 then
        begin
          OutTextXY(MX0,144,'Uni-P:'+NStr(k));
          OutTextXY(MX0+10*8,144,'UFC:');
          WriteFCode(MX0+14*8,144,c,planet[k]^.fcode);
        end;
      end;
      if decunits>0 then
      begin
 {       robot:=(Race[owner]=9);}
        if (web and 4=4) then begin
          s:=NStr0(units);
          if (web and 2=2) and (units>0) then s:='÷'+s;
          OutTextXY(MX0,160,'Pre-decay: '+s);
        end;
{        OutTextXY(MX0,160,'This is equal to:');}
{        if robot then OutTextXY(MX0,186,'(using 4X bonus)');}
        OutTextXY(MX0,168,'equal to: ('+NStr(UnitsPerTorpRate[owner])+'%)');
        for i:=1 to 10 do
        begin
          Str(units/(i*i*(UnitsPerTorpRate[owner]/100)):9:2,s);
          OutTextXY(MX0,168+i*8,s+' '+Torps[i].name);
        end;
       { More info }
        Y0 := 256;

       { Sweep with beam number 10 (best ones) }
        OutTextXY(MX0,Y0 ,'To sweep use:');
        SetColor(White);
        OutTextXY(MX0,Y0, 'T');
        SetColor(c);
        if (web and 1=1) then p := decunits/( Sqr(iBeam)*WebSweepRate)
                         else p := decunits/( Sqr(iBeam)*SweepRate);

        if ( p <> Trunc(p) ) then p := Trunc(p)+1.0
                             else p := Trunc(p);
        Str(p:2:0,s);
        OutTextXY(MX0,Y0 +8*1,s+' x '+Beams[iBeam].name);

        {Sweep with own Beams Quapla}
        OutTextXY(MX0,Y0 +8*2,'Add/Sub Beams');
        SetColor(White);
        OutTextXY(MX0+0*8,Y0+8*2, 'A');
        OutTextXY(MX0+4*8,Y0+8*2, 'S');
        OutTextXY(MX0+9*8,Y0+8*2, 'e');
        SetColor(c);
        Str(jAmmo:2,s);
        OutTextXY(MX0,Y0 +8*3,s+' x '+Beams[jBeam].name);
        
       {Safe travel with warp =9 to center probability}
        r := MineRadius(decunits);
        OutTextXY(MX0,Y0 +8*6,NStr(r)+' LY travel prob');

        if (web and 1=1) then p := (100.0 - WebMineHitOdds)/100.0
                         else p := (100.0 - MineHitOdds)/100.0;
        safe1 := Exp(r * Ln(p));
        if (web and 1=1) then p := (100.0 - WebMineHitOdds)/100.0
                         else p := (100.0 - MineHitOddsWhenCloakedX10/10.0)/100.0;
        safe2 := Exp(r * Ln(p));
        Str(safe1*100.0:5:2,s);
        Str(safe2*100.0:5:2,s1);
        OutTextXY(MX0,Y0 +8*7,s+'% ('+s1+'%)');
        
        {Next turn decay - only when mines from current turn }
        if when=turn then
        begin
          if (jAmmo>0) then begin               {Sweep-Simulation Quapla}
            if (web and 1=1) then number := ( jBeam*jBeam*WebSweepRate*jAmmo)
                             else number := ( jBeam*jBeam*SweepRate*jAmmo);
            if (decunits<number)   then sweptunits:= 0
                            else sweptunits:=decunits-number;                {Swept out?}
            setcolor(Red);
            p:=DecayMineUnits(sweptunits, (web and 1=1))			{One more Decay}
          end
          else p:=DecayMineUnits(decunits, (web and 1=1));			{One more Decay}

          OutTextXY(MX0     ,Y0 +8*9,'Next turn     diff');

          OutTextXY(MX0     ,Y0 +8*10,'Radius: '+NStr0(MineRadius(Trunc(p))));
          Str(Round(r)-MineRadius(Trunc(p)):2,s);
          OutTextXY(MX0+8*16,Y0 +8*10,s);

          OutTextXY(MX0     ,Y0 +8*11,'Units : '+NStr0(Trunc(p)));
          Str(decunits-Trunc(p):4,s);
          OutTextXY(MX0+8*14,Y0 +8*11,s);
        end;
      end;
    end;
    ObjList;
  end;

procedure IonInfo;
  var   ii      : iptr;
        number  : word;
  begin
    ClearInfo;
    if ltype<>LockI then Exit;
    number:=lock and LockLo;
    if (number=0) or (number>50) then Exit;
    ii:=TTurn^.data^.ion[number];
    if ii<>nil then
    with ii^ do
    begin
      SetColor(White);
      OutTextXY(MX0,72,'Ion storm '+NStr(number));
      OutTextXY(MX0,80,StormName[number]);
      SetColor(cIInfo);
      OutTextXY(MX0,104,'Center:('+NStr0(x)+','+NStr0(y)+')');
      OutTextXY(MX0,112,'Radius: '+NStr0(radius));
      OutTextXY(MX0,128,'Heading: '+NStr0(heading));
      OutTextXY(MX0,136,'Warp   : '+NStr0(warp));
      OutTextXY(MX0,152,'Voltage: '+NStr0(voltage)+' meV');
      OutTextXY(MX0+3*8,168,'and '+IonGrow[grow]);
      SetColor(IIF(voltage<50,cmIWeak,IIF(voltage<150,cmIMod,cmIDang)));
      OutTextXY(MX0+3*8,160,IonLevel[Min(voltage div 50+1,5)]);
    end;
    if not DSdrawn then DrawPath;
    ObjList;
  end;

procedure WormInfo;
  var   w,ww    : wptr;
        number  : word;
        wlength : long;
        x_,y_   : int;
        dx_,dy_ : long;
  begin
    ClearInfo;
    if ltype<>LockW then Exit;
    number:=lock and LockLo;
    if (number<0) or (number>199) then Exit;
    w:=TTurn^.data^.worm[number];
    if w<>nil then
    with w^ do
    begin
      SetColor(White);
      OutTextXY(MX0,72,'Wormhole '+NStr0(number));
      SetColor(LightGray);
      if when=turn then OutTextXY(MX0,80,'(now)')
                   else OutTextXY(MX0,80,'('+NStr(turn-when)+Proper(turn-when,' turn')+' ago)');
      SetColor(cWInfo);
      OutTextXY(MX0,96, 'Center:('+NStr0(x)+','+NStr0(y)+')');
      OutTextXY(MX0,104,'Mass  : '+NStr0(mass));
      OutTextXY(MX0,112,'Radius: '+NStr0(Round( Exp(Ln(mass)*WormPower/100)/2 )));
      OutTextXY(640-byte(Stability[stable,0])*8,128,Stability[stable]);
      if AltWormholes then
      begin
        OutTextXY(640-byte(Stability2[stable,0])*8,136,Stability2[stable]);
        OutTextXY(MX0,152,'Detect rad.: '+NStr0(Round(Exp(Ln(mass)/3)*10)) );
        ww := nil;
        if (number mod 2=1) and (TTurn^.data^.worm[number-1] <>nil )
            then ww:=TTurn^.data^.worm[number-1];
        if (number mod 2=0) and (TTurn^.data^.worm[number+1] <>nil )
            then ww:=TTurn^.data^.worm[number+1];
        if (ww<>nil) then
        begin
          x_:=ww^.x;
          y_:=ww^.y;
          dx_ := Abs(x-x_);
          dy_ := Abs(y-y_);
          if (dx_>MapSize div 2) then dec(dx_,MapSize);
          if (dy_>MapSize div 2) then dec(dy_,MapSize);
          wlength := Round(Sqrt( dx_*dx_+dy_*dy_ ));
          OutTextXY(MX0,168,'Length: '+NStr0(wlength) );
          if Phost then
          begin
            OutTextXY(MX0,176,'Equivalent of');
            OutTextXY(MX0,184,NStr0(Round(wlength/WrmTravelDistDivisor))+
                              ' LY with warp '+NStr0(WrmTravelWarpSpeed));
          end;
        end;
        if Phost then
          if (WrmTravelCloaked) then OutTextXY(MX0,198,'Ship will cloak')
                                else OutTextXY(MX0,198,'Ship will decloak')
      end; {AltWormholes}
    end;
    ObjList;
  end;

procedure UFOInfo;
  var   u       : uptr;
        number  : word;
  begin
    ClearInfo;
    if ltype<>LockU then Exit;
    number:=lock and LockLo;
    if (number<1) or (number>100) then Exit;
    u:=TTurn^.data^.ufo[number];
    if u<>nil then
    with u^ do
    begin
      SetColor(White);
      OutTextXY(MX0,72,u^.name);
      SetColor(LightGray);
      if when=turn then OutTextXY(MX0,80,'(now)')
                   else OutTextXY(MX0,80,'('+NStr(turn-when)+Proper(turn-when,' turn')+' ago)');
      SetColor(cUInfo);
      OutTextXY(MX0,96, 'Center:('+NStr0(x)+','+NStr0(y)+')');
      OutTextXY(MX0,104,'Radius: '+NStr0(radius));
      OutTextXY(MX0,112,'Visible for:');
      OutTextXY(MX0,120,'ships at '+NStr0(rangeS)+' LY');
      OutTextXY(MX0,128,'planets at '+NStr0(rangeP)+' LY');
      if warp=0 then OutTextXY(MX0,144,'Not moving')
      else begin
        OutTextXY(MX0,144,'Heading: '+NStr0(heading));
        OutTextXY(MX0,152,'Warp   : '+NStr(warp));
      end;
      if RLen(info[1])+RLen(info[2])>0 then
      begin
        OutTextXY(MX0,168,'Information:');
        SetLineStyle(SolidLn,0,NormWidth);
        Line(MX0,168+8+1,MX0+12*8-3,168+8+1);
        OutTextXY(MX0,180,info[1]);
        OutTextXY(MX0,188,info[2]);
      end;
    end;
    ObjList;
  end;

procedure MarkInfo;
  var   number  : word;
        a       : MapMark;
  begin
    ClearInfo;
    if ltype<>LockA then Exit;
    number:=lock and LockLo;
    if number=0 then Exit;
    a:=TTurn^.data^.mark^[number];
    DrawMark(MX0+4,80+4+MarkOffsetY(a.mtype),a.color,a.mtype);
    SetColor(White);
    OutTextXY(MX0+18,80,'marker');
    if a.bind>0 then
    begin
      OutTextXY(640-3*8,80,'F3');
      SetColor(LightGray);
      OutTextXY(640-4*8,80,'<  >');
    end;
    SetColor(LightGray);
    if a.mtype=mrkRCircle then OutTextXY(MX0,104,'Radius: '+NStr0(a.radius)) else
    if a.mtype in [mrkLine,mrkDLine] then begin end
    else begin
      OutTextXY(MX0,104,'Text:');
      SetColor(a.color);
      OutTextXY(MX0,116,GetMarkText(number));
      SetColor(LightGray);
      if a.text<>0 then
      begin
        OutTextXY(MX0,136,'Alignment:');
        DrawMark(MX0+5*8-1,156+4+MarkOffsetY(a.mtype),a.color,a.mtype);
        SetColor(a.color);
        SetTextJustify(a.xalg,a.yalg);
        OutTextXY(MX0+5*8-1+(1-a.xalg)*4,156+4+(a.yalg-1)*4,'text');
        SetTextJustify(LeftText,TopText);
        SetColor(LightGray);
      end;
    end;
    if a.bind<0 then OutTextXY(MX0,184,'Bound to ship '+NStr(-a.bind));
    if RWMode and (turn=today) and (distlock=0) then
    begin
      SetColor(White);
      if a.mtype=mrkRCircle then OutTextXY(MX0,104,'R') else
      if a.mtype in [mrkLine,mrkDLine] then begin end
      else begin
        OutTextXY(MX0,104,'T');
        if a.text<>0 then OutTextXY(MX0,136,'A');
      end;
    end;
    ObjList;
  end;

procedure ObjInfo (k:int);
  var   h       : sptr;
        m       : mptr;
        ii      : iptr;
        w       : wptr;
        u       : uptr;
        a       : MapMark;
  begin
    if DSdrawn then DrawPath;
    if SRdrawn then DrawShipRange;
    if DWdrawn then DrawWarpCircles;
    lship:=nil;
    lbase:=nil;
    if k<=0 then k:=ObjN
    else if k>ObjN then k:=1;
    ObjL0:=(k-1) div 10;
    if k<=ShipN then
    begin
      lock:=GoToShipXYSorted(h,lx,ly,k) or LockS;
      ltype:=LockS;
      ShipInfo;
    end else
    if k<=MineN then
    begin
      lock:=GoToMinesXY(m,lx,ly,k-ShipN) or LockM;
      ltype:=LockM;
      MineInfo;
    end else
    if k<=IonN then
    begin
      lock:=GoToIonXY(ii,lx,ly,k-MineN) or LockI;
      ltype:=LockI;
      IonInfo;
    end else
    if k<=WormN then
    begin
      lock:=GoToWormXY(w,lx,ly,k-IonN) or LockW;
      ltype:=LockW;
      WormInfo;
    end else
    if k<=UfoN then
    begin
      lock:=GoToUfoXY(u,lx,ly,k-WormN) or LockW;
      ltype:=LockU;
      UFOInfo;
    end
    else
    if k<=MarkN then
    begin
      lock:=GoToMarkXY(a,lx,ly,k-UfoN) or LockA;
      ltype:=LockA;
      MarkInfo;
    end;
  end;

procedure MouseMove;
  var   sx,sy   : int;
  begin
    if lock<>0 then
    begin
      Abs2Scr(lx,ly,sx,sy);
      if (mEv0=EvMouseMove) and StickyMouse and (Abs(MouseX-sx)<=StickyMouseRange)
                                           and (Abs(MouseY-sy)<=StickyMouseRange) then
        begin MoveMouseTo(sx,sy); Exit end;
      if DSdrawn then DrawPath;
      if SRdrawn then DrawShipRange;
      if DWdrawn then DrawWarpCircles;
            DrawPlanetYnfos;
      ClearInfo;
      lock:=0;
      ltype:=0;
      lship:=nil;
      lplan:=nil;
      lbase:=nil;
      ObjN:=0; ShipN:=0; ObjL0:=0;
      MineN:=0;IonN:=0;WormN:=0;UfoN:=0;MarkN:=0;
    end;
    glx:=0; gly:=0;
    WriteCoord;
    if dline then DrawDistLine;
    if distlock<>0 then LockDistTarget(mmx,mmy);
  end;

procedure GetObjectCoord (obj:int; var lx,ly:int);
  var   nn,otype        : int;
        h               : sptr;
  begin
    otype:=obj and LockHi;
    nn:=obj and LockLo;
    if obj<0 then begin lx:=dlx; ly:=dly end else
    with TTurn^.data^ do
    if (otype=LockA) and (nn>0) and (nn<=nmark) and (mark^[nn].mtype<>mrkNone) then
    with mark^[nn] do
    begin
      lx:=x; ly:=y;
    end else
    if (otype=LockM) and (mines[nn]<>nil) then
    with mines[nn]^ do
    begin
      lx:=x; ly:=y;
    end else
    if (otype=LockI) and (ion[nn]<>nil) then
    with ion[nn]^ do
    begin
      lx:=x; ly:=y;
    end else
    if (otype=LockW) and (worm[nn]<>nil) then
    with worm[nn]^ do
    begin
      lx:=x; ly:=y;
    end else
    if (otype=LockU) and (ufo[nn]<>nil) then
    with ufo[nn]^ do
    begin
      lx:=x; ly:=y;
    end else
       { additional check for invalid planet-numbers has fixed two broken vpa.db }
    if (otype=LockP) and (nn<=NUM_PLANETS) then
    begin
      lx:=xyplan[nn,1];
      ly:=xyplan[nn,2];
    end else
    if (otype=LockS) and (ship[nn]<>nil) then
    begin
      h:=ship[nn];
      if h<>nil then begin lx:=h^.x; ly:=h^.y end;    end
    else lx:=-1;
  end;

procedure MouseLtPress;
  var   mx,my   : int;
  begin
    if DSdrawn then DrawPath;
    if SRdrawn then DrawShipRange;
    if DWdrawn then DrawWarpCircles;
          DrawPlanetYnfos;
    Scr2Abs(MouseX,MouseY,lx,ly);
    if force=0 then lock:=NearestObject(lx,ly)
    else begin
      lock:=force;
      force:=0;
      GetObjectCoord(lock,mx,my);
      if mx=-1 then lock:=0
               else begin lx:=mx; ly:=my end;
    end;
    ltype:=lock and LockHi;
    if lock>0 then
    begin
      ShipSortTableLock := true;
      InitObjList;
      case ltype of
        LockA   :       MarkInfo;
        LockM   :       MineInfo;
        LockI   :       IonInfo;
        LockW   :       WormInfo;
        LockU   :       UFOInfo;
        LockP   :       if lbase<>nil then BaseInfo else PlanetInfo;
        LockS   :       ShipInfo;
        else    begin lock:=0; ltype:=0 end;
      end;
    ShipSortTableLock := false;
    end;
    if ltype<>LockS then lship:=nil;
    if ltype<>LockP then lplan:=nil;
    CenterMap(lx,ly,No);
    if dline then DrawDistLine;
    if distlock<>0 then LockDistTarget(lx,ly);
    if not DWdrawn then DrawWarpCircles;
          DrawPlanetYnfos;
    Abs2Scr(lx,ly,mx,my);
    MoveMouseTo(mx,my); WriteCoord;
    if mEvent<>EvLtPress then mEvent:=0;
    if showF and (turn=today) then ShowForecast; 
  end;

procedure MouseRtPress;
{  var  h       : sptr;}
  var   shift   : boolean;
        sx1,sy1,sx2,sy2,sr,ss   : int;
        x00,y00 : int;
        enterDM : boolean;
  begin
    shift:=(KbdFlags and KbdShft)<>0;
    if ((lock or distlock=0) and (not shift)) or (mEvent<>0) then
    begin
      if (MouseX>119) and (MouseX<360) and
         (MouseY>119) and (MouseY<360) then Exit;
      if not MapWrap then
      begin
        Scr2Abs(0,0,sx1,sy2);
        Scr2Abs(479,479,sx2,sy1);
        sr:=(sx2-sx1) div 2;
      end;
      ss:=IIF(mEvent<>0,20,50);
      x00:=x0; y00:=y0;
      if (MouseX<120) and (MapWrap or (sx1>MapX0-sr)) then dec(x0,ss);
      if (MouseX>359) and (MapWrap or (sx2<MapY0+sr)) then inc(x0,ss);
      if (MouseY<120) and (MapWrap or (sy2<MapY0+sr)) then dec(y0,ss);
      if (MouseY>359) and (MapWrap or (sy1>MapX0-sr)) then inc(y0,ss);
      if MapWrap then
      begin
        if x0>MapSSize then dec(x0,MapSSize);
        if x0<-MapSSize then inc(x0,MapSSize*2);
        if y0>MapSSize then dec(y0,MapSSize);
        if y0<-MapSSize then inc(y0,MapSSize*2);
      end;
      if (x0=x00) and (y0=y00) then mEvent:=0
      else begin
        MouseX:=Min(Max(MouseX,1),478);
        MouseY:=Min(Max(MouseY,1),478);
        DrawMap(Yes);
        MouseMove;
      end;
    end
    else begin
      enterDM:=No;
      if shift then
      begin
        if dline then DrawDistLine;
        if distlock<>0 then DrawDistLock;
        distlock:=-1;
        Scr2Abs(MouseX,MouseY,dlx,dly);
      end
      else begin
        if dline then DrawDistLine;
        if (lock=0) or (distlock=lock) then
        begin
          DrawDistLock;
          force:=distlock;
          ForceKey:=13;
          distlock:=0;
        end
        else begin
          if distlock<>0 then DrawDistLock;
          distlock:=lock;
          dlx:=lx; dly:=ly;
          DrawDistLock;
          enterDM:=Yes;
        end;
      end;
      if distlock=0 then Clear(483,dll-1,639,479)
      else begin
        SetLineStyle(SolidLn,0,ThickWidth);
        SetColor(DarkGray);
        dll:=468;
        if (distlock>0) and (distlock and LockHi=LockS) then
        begin
          dlship:=TTurn^.data^.ship[distlock and LockLo]^;
          if (CloakFuelBurn=0) or (dlship.mission in [7,8]) or
             ((not IsShipFunc(dlship,hfCloak)) and
              (not IsShipFunc(dlship,hfAdvCloak))) then dlc:=2
          else if ShipIsCloaking(dlship.owner, dlship.mission) then dlc:=1
          else dlc:=0;
          dlf:=0;
          dlt:=0;
          with dlship do
          begin
            if hull=-1 then hull:=17;   {assume LSDF}
{            if (El=-1) and (warp>0) then El:=warp;}
            if (El=-1) then begin if (warp>0) then El:=warp else El:=9; end;
            { autoadjust speed if OptimizeFuel option is set }
            if ((warp=0) or (OptimizeFuel)) then warp:=GetOptimalWarp(addr(dlship));
            if (fuel=-1) and (hull<>-1) and (mass<>-1) then fuel:=mass-Hulls[hull].mass;
            if (mission=-1) and (warp>0) and (enemy>=0) then
            begin
              ss:=warp*warp;
              if (hull<>-1) and (IsShipFunc(dlship,hfGravitonic)) then ss:=ss*2;
              wx:=Round(Sin(enemy*Pi/180.0)*ss);
              wy:=Round(Cos(enemy*Pi/180.0)*ss);
              mission:=0;
            end;
            if (mass<>-1) and (hull<>-1) and (El<>-1) and (fuel<>-1) then dll:=360;
          end;
          {if dlship.owner=player then dll:=360;}
{         h:=TTurn^.data^.ship[distlock and LockLo];
          dlw:=h^.warp;
          if (CloakFuelBurn=0) or (h^.mission in [7,8]) or
             ((not IsShipFunc(h^,hfCloak)) and
              (not IsShipFunc(h^,hfAdvCloak))) then dlc:=2
          else if ((h^.mission in [10,ExtMissionsStartAt+10]) or
                   ((Race[h^.owner]=3) and (h^.mission in [9,ExtMissionsStartAt+9]))) then dlc:=1
          else dlc:=0;
          if h^.owner=player then dll:=360;}
        end;
        Clear(483,354,639,479);
        Line(482,dll,639,dll);
      end;
      if enterDM and (ltype=LockS) then
        {with TTurn^.data^.ship[lock and LockLo]^ do}
        with dlship do
        if mission<>-1 then
        begin
          sx2:=x+wx; sy2:=y+wy;
          MouseMove;    {changes dlship.wx and wy, sets glx=gly=0}
          glx:=sx2; gly:=sy2;
          if MapWrap then WrapXY(glx,gly);
          CenterMap(glx,gly,No);
          Abs2Scr(glx,gly,sx1,sy1);
          MoveMouseTo(sx1,sy1);
          WriteCoord;
          forceDL:=Yes; LockDistTarget(glx,gly);
        end;
    end;
  end;

const   mtype0  : MarkType = mrkFlag;
        mcolor0 : byte = LightRed;

procedure SetMark;
  var   t       : MarkType;
        c       : byte;
        dx,dy   : int;
        ch      : word;
        a       : MapMark;
        s       : string[4];
        bind    : word;
  const MDX     = (640-MX0) div 15;
  procedure DrawS (c:byte);
    var x,y     : int;
    begin
      x:=MX0+MDX*(mcolor0-Blue);
      y:=88-12+ord(mtype0)*12;
      SetColor(c);
      SetLineStyle(SolidLn,0,NormWidth);
      Rectangle(x,y,x+MDX-1,y+11);
    end;
  begin
    if turn<>today then Exit;
    {MouseOff;} {suspendmouse;}
    MouseDisabled:=True;
    bind:=IIF(ltype=LockS,lock and LockLo,0);
    if DSdrawn then DrawPath;
    if SRdrawn then DrawShipRange;
    if DSdrawn then DrawWarpCircles;
          DrawPlanetYnfos;
    lock:=0;
    ltype:=0;
    lship:=nil;
    lplan:=nil;
    lbase:=nil;
{    ClearInfo;}
    Clear(MX0-13,72,639,479);
    SetColor(White);
    OutTextXY(MX0,72,'Choose marker type:');
    if bind<>0 then
    begin
      OutTextXY(MX0,120+ord(LastMark)*12+32,'The marker will be');
      OutTextXY(MX0,120+ord(LastMark)*12+32+8,'bound to ship '+NStr(bind));
    end;
    for t:=MarkType(ord(mrkNone)+1) to LastMark do
    begin
      dx:=MarkOffsetX(t);
      dy:=MarkOffsetY(t);
      {if t=mrkFlag) then begin dx:=-1; dy:=3 end
                   else begin dx:=0; dy:=0 end;}
      for c:=Blue to White do
        DrawMark(MX0+MDX div 2+MDX*(c-Blue)+dx,88-12+6+ord(t)*12+dy,c,t);
    end;
    repeat
      DrawS(White);
      ch:=ReadKey;
      DrawS(Black);
      case ch of
        $4B00   : begin dec(mcolor0); if mcolor0<Blue then mcolor0:=White end;
        $4D00   : begin inc(mcolor0); if mcolor0>White then mcolor0:=Blue end;
        $4800   : begin dec(mtype0); if mtype0=mrkNone then mtype0:=LastMark end;
        $5000   : begin inc(mtype0); if mtype0>LastMark then mtype0:=MarkType(ord(mrkNone)+1) end;
      end;
    until (ch=13) or (ch=27);
    {resumemouse;} {MouseOff;}
    if ch=13 then
    begin
      if MapWrap then WrapXY(mmx,mmy);
      a.x:=mmx;
      a.y:=mmy;
      a.mtype:=mtype0;
      a.color:=mcolor0;
      a.bind:=-bind;
      a.text:=0;
      if mtype0=mrkRCircle then
      begin
        SetColor(White);
        OutTextXY(MX0,88+ord(LastMark)*12+16,'Radius (LY):');
        SetColor(LightGray);
        OutTextXY(MX0+13*8,88+ord(LastMark)*12+16,NStr0(radius0));
        s:=GetStr(MX0+13*8,88+ord(LastMark)*12+16,4);
        if GetStrKey<>13 then a.mtype:=mrkNone
        else begin
          a.radius:=Value(s);
          if (a.radius<0) and (radius0=0) then a.mtype:=mrkNone else
          if a.radius=0 then a.radius:=radius0 else radius0:=a.radius;
        end;
      end else
      if mtype0 in [mrkLine,mrkDLine] then
      begin
        SetColor(White);
        OutTextXY(MX0,88+ord(LastMark)*12+16,'Move cursor to the');
        OutTextXY(MX0,88+ord(LastMark)*12+24,'end point and use');
        OutTextXY(MX0,88+ord(LastMark)*12+32,'Ctrl-click or');
        OutTextXY(MX0,88+ord(LastMark)*12+40,'Ctrl-Enter');
        if not MouseGetTarget(mcolor0,IIF(mtype0=mrkLine,SolidLn,DashedLn),Yes) then a.mtype:=mrkNone
        else begin
          dx:=mmx; dy:=mmy;
          if MapWrap then WrapWayPoint(a.x,a.y,dx,dy);
          a.dx:=dx-a.x;
          a.dy:=dy-a.y;
        end;
      end;
      if a.mtype<>mrkNone then
      begin
        lock:=CreateMark(a) or LockA;
        ltype:=LockA;
        if lock and LockLo=0 then
        begin
          ClearInfo;
          SetColor(LightRed);
          OutTextXY(MX0,72,'No more markers');
          OutTextXY(MX0,80,'  available!');
        end
        else begin
          DataChg:=Yes;
          DrawMap(No);
        end;
      end;
    end;
    Clear(MX0-13,72,639,479);
    if lock and LockLo=0 then begin lock:=0; ltype:=0 end;
{    if lock=0 then begin ClearInfo; ObjList end }
    if lock=0 then begin ObjList end
    else begin
      lx:=mmx; ly:=mmy;
      InitObjList;
      MarkInfo;
    end;
    if distlock<>0 then
    begin
      SetColor(DarkGray);
      SetLineStyle(SolidLn,0,ThickWidth);
      Line(482,dll,639,dll);
      ForceDL:=Yes;
      LockDistTarget(mmx,mmy)
    end;
    MouseDisabled:=False;
    {MouseOn;}
  end;

procedure ClearMark;
  var   i,xx,yy : int;
        s       : string[1];
  begin
    if (turn<>today) or (ltype<>LockA) then Exit;
    i:=lock and LockLo;
    with TTurn^.data^.mark^[i] do
    begin
      if bind>0 then Exit;
      {MouseOff;}
      EraseMark(i);
      DataChg:=Yes;
      MouseMove;
    end;
    DrawMap(Yes);
    InitObjList; ObjList;
    {MouseOn;}
  end;

procedure AssignMarkText;
  var   s0      : string;
        s       : str20;
        number  : word;
  begin
    if (turn<>today) or (ltype<>LockA) then Exit;
    number:=lock and LockLo;
    with TTurn^.data^ do
    begin
      if mark^[number].mtype in [mrkRCircle..mrkDLine] then Exit;
      {MouseOff;}
      MouseDisabled:=True;
      s0:=GetMarkText(number);
      {Clear(MX0,116,639,116+7);}
      s:=GetStr(MX0,116,20);
      {MouseOff;}
      if (GetStrKey<>27) and (s<>s0) then
      begin
        if mark^[number].text=0 then
        begin
          mark^[number].xalg:=MarkXAlg;
          mark^[number].yalg:=MarkYAlg;
        end;
        SetMarkText(number,s);
        DrawMap(Yes);
        MarkInfo;
        DataChg:=Yes;
      end
      else begin
        Clear(MX0,116,639,116+7);
        SetColor(mark^[number].color);
        OutTextXY(MX0,116,s0);
      end;
      MouseDisabled:=False;
      {MouseOn;}
    end;
  end;

procedure MarkAlignment;
  var   number  : word;
        a       : MapMark;
        xa,ya   : byte;
        ch      : word;
  procedure DrawA (c:byte);
    begin
      SetColor(c);
      SetTextJustify(xa,ya);
      OutTextXY(MX0+5*8-1+(1-xa)*4,156+4+(ya-1)*4,'text');
      SetTextJustify(LeftText,TopText);
    end;
  begin
    if (turn<>today) or (ltype<>LockA) then Exit;
    number:=lock and LockLo;
    a:=TTurn^.data^.mark^[number];
    if a.mtype in [mrkRCircle..mrkDLine] then Exit;
    if a.text=0 then Exit;
    {MouseOff;}
    MouseDisabled:=True;
    SetColor(Yellow);
    OutTextXY(640-2*8,156-8,#24);
    OutTextXY(640-3*8,156,#27' '#26);
    OutTextXY(640-2*8,156+8,#25);
    xa:=a.xalg; ya:=a.yalg;
    repeat
      DrawA(a.color);
      ch:=ReadKey;
      DrawA(Black);
      case ch of
        $4B00   : begin inc(xa); if (xa=1) and (ya=1) then inc(xa); if xa>2 then xa:=0 end;
        $4D00   : begin dec(xa); if (xa=1) and (ya=1) then dec(xa); if xa>2 then xa:=2 end;
        $4800   : begin dec(ya); if (xa=1) and (ya=1) then dec(ya); if ya>2 then ya:=2 end;
        $5000   : begin inc(ya); if (xa=1) and (ya=1) then inc(ya); if ya>2 then ya:=0 end;
      end;
    until (ch=13) or (ch=27);
    {MouseOff;}
    if ch=27 then begin xa:=a.xalg; ya:=a.yalg end;
    Clear(640-3*8,156-8,639,156+8+7);
    DrawA(a.color);
    if (xa<>a.xalg) or (ya<>a.yalg) then
    with TTurn^.data^.mark^[number] do
    begin
      xalg:=xa;
      yalg:=ya;
      MarkXAlg:=xalg;
      MarkYAlg:=yalg;
      DataChg:=Yes;
      DrawMap(Yes);
    end;
    MouseDisabled:=False;
    {MouseOn;}
  end;

procedure SetMarkRadius;
  var   number  : word;
        a       : MapMark;
        s       : string[4];
  begin
    if (turn<>today) or (ltype<>LockA) then Exit;
    number:=lock and LockLo;
    a:=TTurn^.data^.mark^[number];
    if a.mtype<>mrkRCircle then Exit;
    {MouseOff;}
    MouseDisabled:=True;
    {Clear(MX0+8*8,104,639,104+7);}
    s:=GetStr(MX0+8*8,104,4);
    {MouseOff;}
    if GetStrKey=13 then
    begin
      a.radius:=Value(s);
      if (a.radius>0) or (radius0>0) then
      begin
        if a.radius>0 then radius0:=a.radius else a.radius:=radius0;
        TTurn^.data^.mark^[number].radius:=a.radius;
        DataChg:=Yes;
        DrawMap(Yes);
      end;
    end;
    MarkInfo;
    MouseDisabled:=False;
    {MouseOn;}
  end;

{procedure NextPoint;
  var   h       : sptr;
        d,dd    : int;
        mx,my   : int;
  begin
    if ((dlx=mmx) and (dly=mmy)) or (dlw=0) then Exit;
    mx:=mmx; my:=mmy;
    if MapWrap then WrapWayPoint(dlx,dly,mx,my);
    if (dlx=mx) and (dly=my) then Exit;
    h:=TTurn^.data^.ship[Abs(distlock) and LockLo];
    if (h=nil) or (h^.warp=-1) then Exit;
    dd:=Trunc(Sqrt(Distance2(dlx,dly,mx,my)));
    d:=dlw*dlw;
    if IsShipFunc(h^,hfGravitonic) then d:=d*2;
    DrawDistLine;
    DrawDistLock;
    if dd<=d then
      begin dlx:=mx; dly:=my end
    else begin
      dlx:=dlx+Round((mx-dlx)/dd*d);
      dly:=dly+Round((my-dly)/dd*d);
    end;
    if MapWrap then WrapXY(dlx,dly);
    if distlock>0 then begin dlf:=0; dlt:=0 end;
    inc(dlf,dlf0); inc(dlt);
    distlock:=-Abs(distlock);
    if Gravity and (dlw>1) then
    begin
      Location(dlx,dly);
      if LocationPlanet<>0 then
        begin
          dlx:=LocationX;
          dly:=LocationY;
          force:=LocationPlanet or LockP;
          ForceKey:=13;
          Exit;
        end;
    end;
    LockDistTarget(mmx,mmy);
  end;}

procedure NextPoint;
  var   mx,my   : int;
        f0      : int;
  begin
    if ((dlx=mmx) and (dly=mmy)) or (dlship.warp<1) then Exit;
    mx:=mmx; my:=mmy;
    if MapWrap then WrapWayPoint(dlx,dly,mx,my);
    if (dlx=mx) and (dly=my) then Exit;
    DrawDistLine;
    DrawDistLock;
    dlship.wx:=mx-dlx;
    dlship.wy:=my-dly;
    f0:=dlship.fuel;
    CalcMove(dlship,StdTowPtr(dlship),Yes);
    if MapWrap then WrapXY(dlship.x,dlship.y);
    dlx:=dlship.x;
    dly:=dlship.y;
    inc(dlf,f0-dlship.fuel);
    inc(dlt);
    distlock:=-Abs(distlock);
    LocationPlanet:=PSearchXY(dlx,dly);
    if LocationPlanet<>0 then   { CalcMove calls Location() }
    begin
      force:=LocationPlanet or LockP;
      ForceKey:=13;
      Exit;
    end;
    LockDistTarget(mmx,mmy);
  end;

procedure AlignWayPoint;
  var   h       : sptr;
        number  : word;
        px,py   : int;
        dx,dy   : int;
        dl      : long;
        nomore  : boolean;
  function Check : boolean;
    var x,y     : int;
        d       : long;
    begin
      Check:=No;
      x:=glx+dx;
      y:=gly+dy;
      d:=Distance2(dlx,dly,x,y);
      if d>=dl then Exit;
      if RoundWells and (Distance2(px,py,x,y)<=GravityRange*GravityRange) or
         (not RoundWells) and (Abs(px-x)<=GravityRange) and (Abs(py-y)<=GravityRange) then
      begin
        Check:=Yes;
        inc(glx,dx);
        inc(gly,dy);
      end;
    end;
  begin
    if (turn<>today) or (distlock=0) or (not Gravity) or (ltype<>LockP) then Exit;
    with TTurn^.data^ do
    begin
      px:=xyplan[lock and LockLo,1];
      py:=xyplan[lock and LockLo,2];
    end;
    MouseMove;
    glx:=lx; gly:=ly;
    if MapWrap then
    begin
      WrapWayPoint(dlx,dly,px,py);
      WrapWayPoint(dlx,dly,glx,gly);
    end;
    repeat
      nomore:=Yes;
      dl:=Distance2(dlx,dly,glx,gly);
      for dx:=-2 to 2 do
      begin
        for dy:=-2 to 2 do
          if Check then begin nomore:=No; Break end;
        if not nomore then Break;
      end;
    until nomore;
    if MapWrap then WrapXY(glx,gly);
    Abs2Scr(glx,gly,px,py);
    MoveMouseTo(px,py);
    WriteCoord;
    LockDistTarget(glx,gly);
  end;

procedure SetWayPoint;
  var   h       : sptr;
        dl      : single;
        mx,my   : int;
        l       : long;
        number  : word;
        cloaked : boolean;
  begin
    if (turn<>today) or (distlock<0) or (distlock and LockHi<>LockS) then Exit;
    number:=distlock and LockLo;
    h:=TTurn^.data^.ship[number];
    if (h=nil) or (h^.owner<>player) or (h^.when<>turn) then Exit;
    if Gravity and AutoUseGravity and (h^.warp<>1) and
      ((not HyperDrive) or (not IsShipFunc(h^,hfHyperDrive)) or (h^.fcode<>'HYP')
                                                             or ((h^.fcode<>'AHP') and Addon.Unity)) then
    begin
      Location(h^.x,h^.y);
      if LocationPlanet<>lock and LockLo then AlignWayPoint;
    end;
    if lock or glx or gly=0 then begin MouseMove; mx:=mmx; my:=mmy end
    else if lock<>0 then begin mx:=lx; my:=ly; MouseMove end
    else begin mx:=glx; my:=gly; MouseMove end;
    with h^ do
    begin
      if MapWrap then WrapWayPoint(x,y,mx,my);
      dl:=Sqrt(Distance2(x,y,mx,my));
      if dl>3000 then
      begin
        l:=mx-x; mx:=x+Trunc(l*3000/dl);
        l:=my-y; my:=y+Trunc(l*3000/dl);
      end;
      cloaked:=ShipIsCloaking(player, mission);
      if (x+wx<>mx) or (y+wy<>my) or (warp<>dlship.warp) or ( (dlc=1) xor cloaked ) then
      begin
        wx:=mx-x;
        wy:=my-y;
        warp:=dlship.warp;
        { autoadjust speed if OptimizeFuel option is set }
        if ((warp=0) or (OptimizeFuel)) then warp:=GetOptimalWarp(addr(dlship));
        if (dlc=1) and (not cloaked) then mission:=IIF(player=3,9,10) else
        if (dlc=0) and cloaked then mission:=5;
        ChangeData(Sh,number);
      end;
      MouseRtPress;
      if showT then DrawMap(Yes);
      force:=number or LockS;
      ForceKey:=13;
    end;
  end;

{procedure FindFirst;
  var   i,k,sx,sy       : int;
        p               : pptr;
        l               : long;
  begin
    k:=0; l:=0;
    for i:=1 to 500 do
    begin
      p:=TTurn^.data^.planet[i];
      if (p<>nil) and (p^.when=turn) and
         (p^.owner=player) and (p^.colonists>l) then
        begin k:=i; l:=p^.colonists end;
    end;
    l:=0;
    for i:=1 to 500 do
    begin
      p:=TTurn^.data^.planet[i];
      if (p<>nil) and (p^.when=turn) and (p^.owner=player) and
         (TTurn^.data^.eplan[i].activity and EP_Base<>0) and (p^.colonists>l) then
        begin k:=i; l:=p^.colonists end;
    end;
    if k=0 then Exit;
    Abs2Scr(Planets[k].x,Planets[k].y,sx,sy);
    MoveMouseTo(sx,sy);
  end;}

{$IFDEF DEBUG}
procedure TurnsInMemory;
  var   y,i     : int;
        t       : tptr;
        m       : long;
  begin
    MouseMove;
    WriteFreeMem;
    ClearInfo;
    SetColor(White);
    OutTextXY(MX0,72,'Turns in memory:');
    y:=88;
    t:=TRoot;
    while t<>nil do
    begin
      if t^.data<>nil then
      begin
        m:=SizeOf(TurnData);
        with t^.data^ do
        begin
          for i:=1 to 999 do
          begin
            if (i<=500) and (planet[i]<>nil) then inc(m,SizeOf(PRec));
            if (i<=500) and (base[i]<>nil) then inc(m,SizeOf(BRec));
            if ship[i]<>nil then inc(m,SizeOf(SRec));
            if (i<=500) and (mines[i]<>nil) then inc(m,SizeOf(MRec));
            if (i<=50) and (ion[i]<>nil) then inc(m,SizeOf(IRec));
          end;
          inc(m,nmark*SizeOf(MapMark));
          inc(m,mtsize);
        end;
        OutTextXY(MX0,y,'turn '+NStr(t^.turn)+' = '+NStr(m));
        inc(y,8);
      end;
      t:=t^.next;
    end;
    OutTextXY(MX0,y+8,'MaxAvail = '+NStr0(MaxAvail));
  end;
{$ENDIF}

procedure ChangeMineBeams;
begin
  iBeam:=iBeam+1;
  if iBeam > 10 then iBeam:=1;
  MineInfo;
end;

procedure ChangeSweepBeams;
begin
  jBeam:=jBeam+1;
  if jBeam > 10 then jBeam:=1;
  MineInfo;
end;

procedure ChangeAmmoBeams(diff:int);
begin
  jAmmo:=jAmmo+diff;
  if jAmmo > 99 then jAmmo:=0
  else if jAmmo<0 then jAmmo:=99;
  MineInfo;
end;



procedure ResetMouseAndVideo;
  begin
    MouseMove;
    { (en DOS aqui se reseteaba el modo de video por BIOS; ptcgraph lo mantiene) }
    ResetMouse;
    DrawRightScreen;
    DrawMap(Yes);
  end;

procedure DisplayShipFunctions(s:sptr);
{$IFDEF VPACC}
  var qr : THullFuncQueryResult;
  begin
    EnumExistingShipFunctions(qr, s, true);
    if qr.count<>0 then begin
      MouseOff;
      DisplayHullfuncs(qr,false,RealShipOwner(s^.ship_id),ShipExperience(s^.ship_id));
      FreeShipFuncQueryResult(qr);
      MouseOn;
      DrawRightScreen;
      ShipInfo;
      DrawMap(Yes);
    end;
  end;
{$ELSE}
  begin end;
{$ENDIF}

procedure Main;
begin
  mt0:=Timer;
  LastActivityTime:=mt0;
  LastClockTime:=mt0;
  if ShipSortTablePtr=nil then begin
    New(ShipSortTablePtr);
    FillChar(ShipSortTablePtr^, Sizeof(ShipSortTablePtr^), 0);
  end;
  repeat
    if (ForceKey<>0) or KeyPressed then
    begin
      if ForceKey<>0 then begin ch:=ForceKey; ForceKey:=0 end
                     else ch:=ReadKey;
      if MousePresent and (lock<>0) and (distlock=0) then
        case ch of
          $4800 : ch:=$8D00;    { Up -> ^Up }
          $5000 : ch:=$9100;    { Dn -> ^Dn }
          $4B00 : ch:=$7300;    { Lt -> ^Lt }
          $4D00 : ch:=$7400;    { Rt -> ^Rt }
        end;
        
      case ch of
{esc}   27      : MouseMove;
{left}  $4B00   : if MouseX>0   then begin MoveMouseTo(MouseX-Max(1,ratio2 div ratio1),MouseY); MouseMove end;
{right} $4D00   : if MouseX<479 then begin MoveMouseTo(MouseX+Max(1,ratio2 div ratio1),MouseY); MouseMove end;
{up}    $4800   : if MouseY>0   then begin MoveMouseTo(MouseX,MouseY-Max(1,ratio2 div ratio1)); MouseMove end;
{down}  $5000   : if MouseY<479 then begin MoveMouseTo(MouseX,MouseY+Max(1,ratio2 div ratio1)); MouseMove end;
{~lt}   $9B00   : if MouseX>9   then begin MoveMouseTo(MouseX-10,MouseY); MouseMove end;
{~rt}   $9D00   : if MouseX<470 then begin MoveMouseTo(MouseX+10,MouseY); MouseMove end;
{~up}   $9800   : if MouseY>9   then begin MoveMouseTo(MouseX,MouseY-10); MouseMove end;
{~dn}   $A000   : if MouseY<470 then begin MoveMouseTo(MouseX,MouseY+10); MouseMove end;
{^up}   $8D00   : if ObjN>0 then ObjInfo(Obj0-1);
{^dn}   $9100   : if ObjN>0 then ObjInfo(Obj0+1);
{^lt}   $7300   : if (ltype=LockS) and showS then NextShip(-1)
                  else if ltype=LockP then
                    if lbase=nil then NextPlanet(-1) else NextBase(-1)
                  else if (ltype=LockM) and showM then NextMines(-1)
                  else if (ltype=LockI) and showI then NextIon(-1)
                  else if (ltype=LockW) and showU then NextWorm(-1)
                  else if (ltype=LockU) and showU then NextUFO(-1);
{_r}    ord('R'): DrawRange;
{^rt}   $7400   : if (ltype=LockS) and showS then NextShip(1)
                  else if ltype=LockP then
                    if lbase=nil then NextPlanet(1) else NextBase(1)
                  else if (ltype=LockM) and showM then NextMines(1)
                  else if (ltype=LockI) and showI then NextIon(1)
                  else if (ltype=LockW) and showU then NextWorm(1)
                  else if (ltype=LockU) and showU then NextUFO(1);
{<}     60      : ;
{,}     44      : if (turn=today) then
                    begin
                      if (ltype=LockS) and showS and (lship^.owner=player) then NextActiveShip(-1)
                      else if (ltype=LockP)  then
                        if (lbase=nil) then NextActivePlanet(-1)
                                       else NextActiveBase(-1);
                    end;
{>}     62      : ;
{.}     46      : if (turn=today) then
                    begin
                      if (ltype=LockS) and showS and (lship^.owner=player) then NextActiveShip(1)
                      else if (ltype=LockP)  then
                        if (lbase=nil) then NextActivePlanet(1)
                                       else NextActiveBase(1);
                    end;
{?}     63      : ;
{/}     47      : if (turn=today) then
                    begin
                      if (ltype=LockS) and showS and (lship^.owner=player) then SwitchActive(LockS)
                      else if (lplan<>nil) then
                        if (ltype=LockP) and (lplan^.owner=player) and (lplan^.when=turn) then
                          if (lbase=nil) then SwitchActive(LockP)
                                         else SwitchActive(LockB);
                    end;
{enter} 13      : MouseLtPress;
{^ent}  10,
{auml}    132   : if RWMode then SetWayPoint;
{space} ord(' '),
{ouml}    148   : MouseRtPress;
{tab}   9       : Zoom(1);
{_tab}  $0F00   : Zoom(255);
{^tab}  $9400   : Zoom(0);
{~1..0} $7800,$7900,$7A00,$7B00,$7C00,$7D00,$7E00,$7F00,$8000,$8100     :
                  SetScreenPos(Hi(ch)-$77);
{-}     ord('-'): TimeShift(-1);
{+}     ord('+'): TimeShift(1);
{^-}    $8E00   : if turn<>TRoot^.turn then begin SetTurn(TRoot^.turn); TimeShift(0) end;
{^+}    $9000   : if turn<>today then begin SetTurn(today); TimeShift(0) end;

{0..9}  ord('0')..ord('9'):
                  if (turn=today) and (Abs(distlock) and LockHi=LockS) then
                    begin {dlw}dlship.warp:=ch-ord('0'); forceDL:=Yes; LockDistTarget(mmx,mmy) end
                  else ObjInfo(ObjL0*10+IIF(ch=ord('0'),ord('9')+1,ch)-ord('0'));
{pgup}  $4900   : if ObjL0>0 then
                  begin
                    dec(ObjL0);
                    ObjInfo(Max(Obj0-10,1));
                  end;
{pgdn}  $5100   : if (ObjN>0) and (ObjL0<(ObjN-1) div 10) then
                  begin
                    inc(ObjL0);
                    ObjInfo(Min(Obj0+10,ObjN));
                  end;
{ins}   $5200   : if showA then SetMark;
{del}   $5300   : if ltype=LockA then ClearMark;
{home}  $4700   : if (lbase<>nil) and (BL0>BL1) then begin dec(BL0,BL2-BL1+8); BaseStorage end
                  else
                  if (ltype=LockS) and (lship^.hull=-1) and
                     eAllH and AllH and (ScanH>1) then
                    begin dec(ScanH); HullTypes end;
{end}   $4F00   : if (lbase<>nil) and bOver then begin inc(BL0,BL2-BL1+8); BaseStorage end
                  else
                  if (ltype=LockS) and (lship^.hull=-1) and
                     eAllH and AllH and hOver then
                    begin inc(ScanH); HullTypes end;
{_a}    ord('A'): begin showA:=not showA; WriteShows; MouseMove; DrawMap(not showA) end;
{_b}    ord('B'): begin PretendBuild; DrawMap(Yes); end;
{~a}    $1E00   : if showA then begin
                    CurMarkMask := (CurMarkMask+1) mod (LastMarkMask+1);
                    DrawMap(Yes);
                  end;
{_e}    ord('E'): begin showE:=not showE; WriteShows; MouseMove; DrawMap(No) end;
{_i}    ord('I'): begin showI:=not showI; WriteShows; MouseMove; DrawMap(No) end;
{_m}    ord('M'): begin showM:=not showM; WriteShows; MouseMove; DrawMap(No) end;
{_p}    ord('P'): begin showP:=not showP; WriteShows; MouseMove;
                        if ratioN>=PNRatio then DrawMap(not showP) end;
{_n}    ord('N'): begin showN:=not showN; WriteShows; DrawMap(yes); MouseMove; end;
{_s}    ord('S'): begin showS:=not showS; WriteShows; MouseMove; DrawMap(No) end;
{_t}    ord('T'): begin showT:=not showT; WriteShows; MouseMove; DrawMap(No) end;
{_u}    ord('U'): begin showU:=not showU; WriteShows; MouseMove; DrawMap(No) end;
{_v}    ord('V'): if Addon.Teleport then begin showV:=not showV; WriteShows; MouseMove; DrawMap(Yes) end;
{_g}    ord('G'): begin showG:=not showG; WriteShows; MouseMove;
                        if ratioN>=GWRatio then  DrawMap(not showG) end;
{_w}    ord('W'): begin
                     if DWdrawn then DrawWarpCircles;
                     DrawWarpCirclesSelect;
                     WriteShows; DrawWarpCircles;
                  end;
{_y}    ord('Y'): begin PlanetYnfoSelect; WriteShows; DrawMap(Yes);  end;
{_h}    ord('H'): begin ShowFinalHappy:= not ShowFinalHappy;
                        if (ltype=LockP) and (lplan<>nil) then PlanetInfo;
                  end;
{_z}    ord('Z'): begin
                    inc(ShipSortTableType);
                    if (ShipSortTableType > ShipSortTableMaxType) then ShipSortTableType:=0;

                    if (ltype=LockP) or (ltype=LockS) then
                    begin
                       InitObjList;
                       ObjList;
                    end;
                  end;
{a}     ord('a'): if RWMode and (ltype=LockP) and (lplan<>nil) and (lbase=nil) then BuildStructures(_Factory)
                  else if (ltype=LockS) and (lship^.hull=-1) and
                          (lship^.mass<>-1) and eAllH then
                         begin AllH:=not AllH; HullTypes end
                  else if (ltype=LockM) then ChangeAmmoBeams(1)
                  else if (ltype=LockA) and RWMode and (turn=today) and
                          (distlock=0) then MarkAlignment;
{b}     ord('b'): if (ltype=LockS) and (splan[lock and LockLo]<>0) then
                  begin
                    force:=splan[lock and LockLo];
                    lbase:=TTurn^.data^.base[force];
                    force:=force or LockP;
                    MouseLtPress;
                  end
                  else if ltype=LockP then begin
                    if RWMode and (TTurn^.data^.eplan[lock and LockLo].activity and EP_Base=0) then BuildBase
                    else if RWMode and (lplan^.build=1) then CancelBase
                    else if lbase=nil then BaseInfo else Exit; end
                  else if ((PlanN>0) and (lock<>0)) then begin
                    ltype:=LockP;
                    lock:=PlanN or LockP;
                    BaseInfo;
                  end;
{c}     ord('c'): begin
                    if RWMode and (turn=today) then begin
                      if (ltype=LockS) and (distlock=0) then
                      begin
                         TransferCargo(Pl);
                         InitObjList;
                         ObjList;
                      end
                      else if (Abs(distlock) and LockHi=LockS) and (dlc<>2) then
                        begin dlc:=dlc xor 1; forceDL:=Yes; LockDistTarget(mmx,mmy) end
                      else if (ltype=LockP) and (lbase<>nil) and
                              (CheckClone(lock and LockLo)>=0) and BuildClone then Exit;
                    end;
                    if RWMode and (ltype=LockP) and (lplan^.owner<>0) then
                        if (lplan^.owner=player) then SimOwnGroundAttack
                                                 else SimGroundAttack(1); 
                  end;

{_c}    ord('C'): begin
{$IFDEF vpacc}
                    if RWMode and PHOST and EnableRemote and (ltype=LockS) and (turn=today) then begin
                      NRemoteControl(0, lock and LockLo);
                      ChangeData(Sh, lock and LockLo);
                      MouseDisabled := true;
                      ShipInfo;
                      MouseDisabled := false;
                    end else
{$ENDIF}
                    begin showC:=not showC; WriteShows; MouseMove; DrawMap(Yes) end;
                  end;
{$IFDEF vpacc}
{v}     ord('v'): if RWMode and PHOST and EnableGive and (turn=today) then begin
                    if (ltype=LockS) and (lship<>nil) and (lship^.owner=player) and (lship^.when=today)
                     then begin
                       NGive(0, lock and LockLo, phc_GiveShip, RealShipOwner(lock and LockLo));
                       ChangeData(Sh, lock and LockLo);
                       MouseDisabled := true;
                       ShipInfo;
                       MouseDisabled := false;
                     end
                    else if (ltype=LockP) and (lplan<>nil) and (lplan^.owner=player) and (lplan^.when=today)
                     then begin
                       NGive(0, lock and LockLo, phc_GivePlanet, lplan^.owner);
                       ChangeData(Pl, lock and LockLo);
                       MouseDisabled := true;
                       PlanetInfo;
                       MouseDisabled := false;
                     end;
                  end;
{$ENDIF}
{d}     ord('d'): if RWMode and (ltype=LockP) and (lplan<>nil) then begin
                    if lbase=nil then BuildStructures(_Defense) else IncreaseBaseDefense;
                    if (lplan^.owner<>player) and (lplan^.owner<>0) then
                      SimGroundAttack(2);
                    end;
                  
{_d}    ord('D'): if (ltype=LockP) and (lplan<>nil) and (lbase=nil) then
                    begin ShowCombatStrength:=not ShowCombatStrength; force:=lock; ForceKey:=13 end;
{e}     ord('e'): if RWMode and (distlock=0) and (ltype=LockS) then
                  begin
                     SetEnemy;
                     InitObjList;
                     ObjList;
                  end
                  else if (ltype=LockM) then ChangeSweepBeams;
{f}     ord('f'): if RWMode and (ltype=LockP) and (lplan<>nil) then
                    if lbase=nil then SetFCode(Pl,No) else FixOrRecycle(1)
                  else if (ltype=LockS) then
                    if (lship^.hull<>-1) and (lship^.owner<>player) and
                       (not IsData[lship^.owner]) then ForgetShip
                    else if RWMode and (distlock=0) and
                            (lship^.owner=player) then
                         begin
                           SetFCode(Sh,No);
                           InitObjList;
                           ObjList;
                           ChangeData(Sh,lock and LockLo);
                         end;
        Ord('F'): if (ltype=LockS) and (lship<>nil) then DisplayShipFunctions(lship)
                  else begin showF:=not showF; WriteShows; MouseMove; DrawMap(Yes) end;
{^f}    6       : if RWMode and ((ltype=LockP) or (ltype=LockS)) then
                    if (ltype=LockP) and (lplan<>nil) and (lbase=nil) then SetFCode(Pl,No)
                    else if (distlock=0) and (lship<>nil) and (lship^.owner=player) then SetFCode(Sh,No);
{g}     ord('g'): {if RWMode and (ltype=LockP) and (lplan^.owner<>player) and (lplan^.owner<>0)
                       and (lplan^.colonists>0) and (distlock=0) then SimGA
                  else no use anymore...}
                  AlignWayPoint;
{h}     ord('h'): if (ltype=LockS) and (lship^.hull=-1) and (lship^.mass<>-1) then InputHull;
{^h}    8       : if KbdFlags and KbdCtrl<>0 then DrawHYPCircles;
{i}     ord('i'): if RWMode and (turn=today) and (distlock=0) and (ltype=LockS) and (PlanN<>0) and
                     ((lship^.damage>0) or (lship^.crew<>Hulls[lship^.hull].crew)) then
                    FixOrRecycleShip(PlanN,1,lock and LockLo);
{l}     ord('l'): if RWMode and (distlock=0) and (ltype=LockS) then LoadForBuild;
{m}     ord('m'): if RWMode and (ltype=LockP) and (lplan<>nil) and (lbase=nil) then BuildStructures(_Mine)
                  else if RWMode and (distlock=0) and (ltype=LockS) then
                  begin
                    SetMission;
                    InitObjList;
                    ObjList;
                  end;
{n}     ord('n'): if Abs(distlock) and LockHi=LockS then NextPoint
                  else if RWMode and (distlock=0) and (ltype=LockS) then SetName
                  else if RWMode and (ltype=LockP) and (lplan^.build=1) then      PretendBase;                   
{o}     ord('o'): if RWMode and (ltype=LockP) and (lbase<>nil) then SetBaseOrder
                  else if RWMode and ((ltype=LockS) or (ltype=LockP)) then OKShip(1);
{O}     ord('O'),
{uuml}  129     : if RWMode and ((ltype=LockS) or (ltype=LockP)) then OKShip(2);
{^o}    15      : if RWMode then begin
                     ini_showmenu(ini_file_vpa,true);
                     CenterMap(mmx,mmy,Yes);
                  end;
{^u}    21       : if RWMode then begin
                     ini_showmenu(ini_file_addon,true);
                     {CenterMap(mmx,mmy,Yes);}
                     DrawRightScreen; DrawMap(yes);
                  end;
{^v}    22       : ShowTeleport; 
{^w}    23       : if RWMode then begin
                     ini_showmenu(ini_file_cmistakes,true);
                     CenterMap(mmx,mmy,Yes);
                  end;

{p}     ord('p'): if (lock>0) and (PlanN<>0) then
                  if (ltype<>LockP) or (lbase<>NIL) then begin
                    lbase:=nil; force:=PlanN or LockP; MouseLtPress
                  end else if Addon.Teleport and (turn=today) and 
                  (lock and LockLo>0) and (lock and LockLo<500) { and 
                  (TTurn^.data^.base[lock and LockLo]<>NIL)} then 
                  if (TTurn^.data^.base[PlanN]<>NIL) or
                     ((TTurn^.data^.planet[PlanN]^.build=1) and (TTurn^.data^.base[PlanN]=NIL)) then begin
                  GetTeleport(PlanN); DrawMap(yes); end;                  
{~p}    $1900   : if RWMode then ChangePassword;
{~c}    $2E00   : MyCalc;         {Quapla Rechner}
{^p}    16      : PBPInfo;
{r}     ord('r'): if RWMode and (ltype=LockP) and (lplan<>nil) then
                    if lbase=nil then SetFCode(Pl,Yes) else FixOrRecycle(2)
                  else if RWMode and (ltype=LockS) and
                          (lship<>nil) and (distlock=0) then begin SetFCode(Sh,Yes); InitObjList; ObjList; end
                  else if (ltype=LockA) and RWMode and (turn=today) and
                          (distlock=0) then SetMarkRadius
                  else if (ltype=LockM) then AdjustMinefieldRadius;
{^r}    18      : if RWMode and ((ltype=LockP) or (ltype<=LockS)) then
                    if (ltype=LockP) and (lplan<>nil) and (lbase=nil) then SetFCode(Pl,Yes)
                    else if (distlock=0) and (lship<>nil) and (lship^.owner=player) then
                       begin SetFCode(Sh,Yes); InitObjList; ObjList; end;
{~r}    $1300   : if RWMode and (ltype=LockP) and (lplan<>nil) and (lbase=nil) then RandAllPCodes;
{s}     ord('s'): if RWMode and (ltype=LockP) and (lplan<>nil) and (lbase=nil) then SellSupp
                  else if (ltype=LockM) then ChangeAmmoBeams(-1);
{^s}    19      : ResetMouseAndVideo;
{t}     ord('t'): if (ltype=LockP) and (lplan<>nil) then
                  begin
                    if lbase<>nil then begin if RWMode then UpgradeBaseTech end
                    else
                      if RWMode and (turn=today) and (lplan^.owner=player)
                        then SetTaxes(Yes,lplan^.Ntax)
                        else CalcTaxes;
                  end
                  else if (ltype=LockA) and RWMode and (turn=today) and
                          (distlock=0) then AssignMarkText
                  else if RWMode and (turn=today) and (distlock=0) and
                          (ltype=LockS) and
                          (ShipN>1) then TransferCargo(Sh)
                  else if (ltype=LockM) then ChangeMineBeams;
{^t}    20      : if (ltype=LockP) and (lplan<>nil) and (lbase=nil) then CalcTaxes;
{$IFDEF DEBUG}
{~t}    $1400   : TurnsInMemory;
{$ENDIF}
{u}     ord('u'): if RWMode and (distlock=0) and (ltype=LockS) then UnloadShip(lock and LockLo)
				  else if (ltype=LockM) then AdjustMinefieldUnits;
{~u}    $1600   : if RWMode and (ltype=LockP) and (lplan<>nil) and (lbase=nil) then UnloadAllShips;
{w}     ord('w'): if RWMode and (distlock=0) and (ltype=LockS) then
                  begin
                    SetWarp;
                    InitObjList;
                    ObjList;
                  end;
{x}     ord('x'): if (ltype=LockP) and (lplan<>nil) and (lbase=nil) then
                    if RWMode and (turn=today) and (lplan^.owner=player)
                      then SetTaxes(No,lplan^.Ctax);
{_x}    ord('X'): begin showX:=not showX; WriteShows; MouseMove; DrawMap(Yes) end;
{~x}    $2D00   : Exit;
{y}     ord('y'): if RWMode then
                    if (distlock=0) and (ltype=LockS) then BuyShipTF
                    else if (ltype=LockP) and (lbase<>nil) then BuyBaseTF;
{z}     ord('z'): CenterMap(mmx,mmy,Yes);
{^z}    26      : ResetShipsInWarp;
{f1}    $3B00   : Exit;
{_f1}   $5400   : ShowPlanetNextTurn;
{^f1    $5E00   : ShipList;}
{~f1}   $6800   : ShowRules;
{_f2}   $5500   : ShowShipsNextTurn;
{f2}    $3C00   : Exit;
{f3}    $3D00   : Exit;
{_f3}   $5600   : if RWMode and (lock<>0) then Exit;
{f4}    $3E00   : Exit;
{~f4}   $6B00   : Exit;
{f5}    $3F00   : Exit;
{f6 is reserved for planet sim}
{f6}    $4000   : begin PlanSimDo; DrawMap(Yes); end;
{f7}    $4100   : FindPlanet;
{_f7}   $5A00   : FindShip;
{$IFDEF TASKS}
{f8}    $4200   : if (ltype=LockP) or (ltype=LockS) then exit; {Tasks}
{$ELSE}
{f8}    $4200   : FindShip; {Since nobody finishes Task, i will reput it after 10 Years ;)}
{$ENDIF}
{f9}    $4300   : DrawUserCircle;
{_f9}   $5C00   : DrawMineCircle;
{~f9}   $7000   : DrawMineCircleRadius;
{f10}   $4400   : Exit;
{_f10}  $5D00   : MineSim;
{F11}   $8500   : GoTurn;
{_f11}  $8700   : MyMax;

      end;
      {Write(ord(ch),' ',ch,' ',hi(ch),' ',lo(ch),' / ');         { for adding new functions - print keycode of unknown key } 
      ExtFeatKeyHook(ch);
      LastActivityTime:=Timer;
    end;
    while mEvent<>0 do
    begin
      Mouse.PollMouse;   { port: sin interrupcion de raton; refrescar MouseX/Y aqui
                           para poder salir del borde y no hacer scroll infinito }
      ch:=0;
      mEv0:=mEvent; mEvent:=0;
      if AutoScroll and
        ((MouseX<8) or (MouseX>471) or (MouseY<8) or (MouseY>477))
        {$IFDEF UNIX} and xfocus.PointerInsideWindow {$ENDIF} then
        begin
                mEv0:=EvRtPress;
                mEvent:=EvRtPress
        end;
      if (mEv0<>EvMouseMove) and (mEvent=0) then MouseOff;
      case mEv0 of
        EvMouseMove     : if (Timer<mt0) or (Timer>=mt0+5) then MouseMove;
        EvLtPress       : begin
                            if RWMode and
                               ( (KbdFlags and KbdCtrl<>0) or
                                 ((Timer>=mt1) and (Timer<=mt1+5)) )
                            then begin SetWayPoint; mEvent:=0 end
                            else MouseLtPress;
                            mt0:=Timer;
                            mt1:=mt0;
                          end;
        EvRtPress       : if (Timer<mt0) or (Timer>=mt0+2) then
                            begin MouseRtPress; mt0:=Timer end;
        EvCtPress       : begin
                            if KbdFlags and KbdShft<>0 then Zoom(255) else
                            if KbdFlags and KbdCtrl<>0 then Zoom(0) else Zoom(1);
                            mt0:=Timer
                          end;
      end;
      if (mEv0<>EvMouseMove) and (mEvent=0) then MouseOn;
      mEv0:=0;
      LastActivityTime:=Timer;
      {$IFDEF UNIX}if mEvent<>0 then CpuNap;{$ENDIF}   { scroll continuo: no clavar CPU }
    end;
    if (ScreenSaverTime>0) and (Timer>LastActivityTime+ScreenSaverTime) then
      begin ch:=13; Exit end;
    if showC and (Timer>LastClockTime+30*25) then begin
      ShowClock;
      LastClockTime:=Timer;
    end;
    { port Linux: ceder CPU cuando no hay nada pendiente, para no girar el bucle
      al 100% (en DOS no habia SO; aqui disparaba el ventilador) }
    if (ForceKey=0) and (mEvent=0) then CpuNap;
  until False;
end;

End.
