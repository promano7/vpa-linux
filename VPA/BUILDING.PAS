{
*******************************************************************
* Building.PAS - Main Part Base Building
*
* $Id: building.pas,v 1.47 2013/12/24 08:08:10 sfplanets Exp $
*
*******************************************************************
}

{$I switches.inc}
Unit    Building;
{$V-}

Interface

uses    AuxF, VPAData;

type
  stptr = ^shipTable;
  shipTable= array [1..NUM_SHIPS] of sptr;
  
  GoodShipsPtr = ^GoodShipsTable;
  GoodShipsTable = array [1..NUM_SHIPS] of Boolean; {Ship that will be processed}
   
  TowedByPtr = ^TowedByTable;
  TowedByTable = array [1..NUM_SHIPS] of int;

  
procedure BaseBuild;
procedure PretendBuild;
procedure PretendHost;
procedure PretendBase;
procedure PretendHostAnywhere(showF_ :boolean; ShpNum:int);
PROCEDURE ShowShips(turn__ :int; ly_ :int; showF_ : boolean; TempShipsPtr: stptr);
PROCEDURE ShowForecast;
PROCEDURE ShowPlanetNextTurn;
procedure ShowShipsNextTurn;
PROCEDURE GetPillage(ShipNum : int);

Implementation

uses    ptcgraph,Screen,StrF,TCombat,Keyboard,Mouse,ExtFeat,vpa4
{$IFDEF VPACC},
        Hullfunc
{$ENDIF};

type    bldType = (bldH,bldE,bldW,bldT);
const   bldN    : array [bldType] of byte = (1,9,1,1);
        ShowAviableRes : Boolean   = Yes;
        ShowUpgradeCosts : Boolean = Yes;

PROCEDURE BaseBuild;

const   RX      = 57;
        RY      = 0;
        LX      = 43;
        LY      = 0;
        PY      = 7;
        HX      = 0;
        EX      = 24;
        WX      = 47;
        TX      = 69;
        SX      = 0;
        SY      = 0;
        ShX     = 14*8;
        ShY     = 0;
        CostX   = 24;
        CostY   = 20;
        StX     = 54;
        StY     = 29;
        CX      = 24*8;
        CY      = 22*16;
        BX      = 25;
        BY      = 22;
        IX1     = 0;
        IX2     = LX*8-9;
        IY1     = 0;
        IY2     = 100;

var     ttt,ddd,mmm,ccc : long;
        maxH,mx,my      : int;
        ii,jj,kk        : int;
        ha              : array [1..20] of boolean;
        ea              : array [1..9] of boolean;
        wa,ta           : array [1..10] of boolean;
        chh             : word;
        j               : bldType;
        blW,blT         : byte;
        bldA            : array [bldType] of boolean;
        can,build,RWM   : boolean;
        baseid          : int;
        clone           : boolean;
        clship          : sptr;
        myrace          : byte;
        needcash        : long;
        currhull,last   : int;
        b0              : BRec;
        keyOK           : boolean;
        mylock          : int;

function UpgradeCost (l1,l2:byte) : long;
  var   c       : long;
  begin
    c:=0;
    while l1<l2 do
      begin inc(c,l1*100); inc(l1) end;
    UpgradeCost:=c;
  end;

procedure WriteTechs;
  begin
    TextAttr:=White;
    with lbase^ do
    begin
      WriteXY(LX,LY,'Tech levels:');
      WriteXY(LX,LY+2,'Engine:  '+NStr(El));
      WriteXY(LX,LY+3,'Hull:    '+NStr(Hl));
      WriteXY(LX,LY+4,'Beam:    '+NStr(Wl));
      WriteXY(LX,LY+5,'Torpedo: '+NStr(Tl));
    end;
  end;

procedure WriteResources;
  begin
    with lplan^ do
    begin
      ttt:=T;
      ddd:=D;
      mmm:=M;
      ccc:=funds+supplies;
    end;
    Clear(RX*8,RY*16,639,(RY+5)*16+15);
    if (ShowAviableRes) then
    begin
      TextAttr:=White;
      if (turn=today+1) then
        WriteXY(RX,RY,'NEXT TURN RESOURCES:')
      else
        WriteXY(RX,RY,'AVAILABLE RESOURCES:');
      WriteXY(RX,RY+2,'Tritanium:      '+NStr(ttt));
      WriteXY(RX,RY+3,'Duranium:       '+NStr(ddd));
      WriteXY(RX,RY+4,'Molybdenum:     '+NStr(mmm));
      WriteXY(RX,RY+5,'Cash+supplies:  '+NStr(ccc));
    end;
  end;

procedure DrawShip;
  var   s,s1    : string[79];
        ls      : byte absolute s;
        ls1     : byte absolute s1;
        i       : int;
        j       : byte;
        hf      : int;
      {$IFDEF VPACC}
        qr      : THullFuncQueryResult;
        phf     : PHullFunction;
      {$ENDIF}
  begin
        Clear(IX1,IY1,IX2,IY2);
        if useSVGA then
        begin
          convertImage(img[Left]^,img256);
          PutImage(SX+(104-img[Left]^[1]) div 2,SY+(93-img[Left]^[2]) div 2,img256,NormalPut);
        end
        else
          PutImage(SX+(104-img[Left]^[1]) div 2,SY+(93-img[Left]^[2]) div 2,img[Left]^,NormalPut);
    SetColor(Yellow);
    with Hulls[currhull] do
    begin
      OutTextXY(ShX,ShY,name);
      SetColor(White);
      OutTextXY(ShX,ShY+1*10,'Tech level:    '+NStr(tech));
      OutTextXY(ShX,ShY+2*10,'Engines:       '+NStr(engines));
      if blW>0 then OutTextXY(ShX,ShY+3*10,'Beam weapons:  '+NStr(blW));
      if bays>0 then OutTextXY(ShX,ShY+4*10,'Fighter bays:  '+NStr(bays));
      if blT>0 then OutTextXY(ShX,ShY+4*10,'Torpedo tubes: '+NStr(blT));
      OutTextXY(ShX,ShY+5*10,'Hull mass:     '+NStr0(mass)+' kt');
      OutTextXY(ShX,ShY+6*10,'Crew:          '+NStr0(crew));
      OutTextXY(ShX,ShY+7*10,'Fuel tank:     '+NStr0(fuel)+' kt');
      OutTextXY(ShX,ShY+8*10,'Cargo space:   '+NStr0(cargo)+' kt');
      if not clone then
      begin
        SetColor(LightGreen);
        if weapons>0 then OutTextXY(ShX,ShY+3*10,'B');
        if launchers>0 then OutTextXY(ShX,ShY+4*10,'T');
      end;
    end;
    ls:=0;
    {$IFDEF VPACC}
    EnumNewShipFunctions(qr, currhull);
    for i:=1 to qr.count do begin
      phf := @PHullFunctionArray(qr.data)^[i];
      if (phf^.BasicFunction in [SPC_Alchemy,SPC_Refinery]) and not Alchemy then Continue;
      if (phf^.BasicFunction in [SPC_HeatsTo50..SPC_HeatsTo100]) and not Terraformers then Continue;
      if (phf^.BasicFunction=SPC_Hyperdrive) and not HyperDrive then Continue;
      if (phf^.BasicFunction in [SPC_Chunneling,SPC_ChunnelSelf,SPC_ChunnelTarget,SPC_ChunnelOthers])
       and not Chunnel then Continue;
      if (phf^.BasicFunction in [SPC_GloryDeviceLow,SPC_GloryDeviceHigh]) and not GloryDevice then Continue;
      if (phf^.BasicFunction=SPC_AntiCloak) and not AntiCloak then Continue;
      if (phf^.BasicFunction=SPC_ImperialAssault) and not ImperialAssault then Continue;
      if (phf^.BasicFunction=SPC_AdvancedRefinery) and not AdvancedRefinery then Continue;
      if (phf^.BasicFunction in [SPC_Bioscan,SPC_FullBioscan]) and not BioScanners then Continue;
      if (phf^.BasicFunction=SPC_ScansAllWormholes) and not Wormholes then Continue;
      if (phf^.BasicFunction=SPC_Gambling) and not Gambling then Continue;
      if (phf^.BasicFunction=SPC_Ramscoop) and (RamScoop=0) then Continue;
      s1 := GetBasicFunctionTitle(phf^.BasicFunction);
      if ls>0 then s:=s+', ';
      s:=s+s1;
    end;
    FreeShipFuncQueryResult(qr);
    {$ELSE}
    for i:=1 to HullFN do
    begin
      hf:=HullFunc^[i];
      if Lo(hf)=currhull then
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
        if Hi(hf)>byte(HullFunc2) then s1:='Function '+NStr0(Hi(hf))
        else begin
          ItemStr(HullFuncName,Hi(hf),s1);
          j:=2;
          while j<=ls1 do
          begin
            if s1[j] in ['A'..'Z','1','5'] then begin Insert(' ',s1,j); inc(j) end;
            inc(j);
          end;
        end;
        if ls>0 then s:=s+', ';
        s:=s+s1;
      end;
    end;
    {$ENDIF}
    if ls>24 then SetTextStyle(LittFont,HorizDir,4);
    SetColor(LightBlue);
    OutTextXY(ShX,ShY+9*10,s);
    SetTextStyle(DefaultFont,HorizDir,1);
  end;

procedure Draw1Eng (i:byte);
  var   s       : string[37];
        s1      : string[4];
        j,b     : byte;
  begin
    with Engines[i] do
    begin
      s:=' '+chr(i+ord('0'))+' ';
      Str(tech:3,s1); s:=s+s1;
      Str(T:3,s1); s:=s+s1;
      Str(D:3,s1); s:=s+s1;
      Str(M:3,s1); s:=s+s1;
      Str(cost:4,s1); s:=s+s1;
      for j:=1 to 9 do
      begin
        b:=Round(burn[j]/(j*j*100));
        Str(b:2,s1);
        s:=s+s1;
      end;
    end;
    OutTextXY(0,20+(i-1)*8,s);
  end;

procedure DrawEng;
  var   i       : byte;
  begin
    Clear(IX1,IY1,IX2,IY2);
    SetColor(White);
    OutTextXY(0,0,'           Cost     Fuel burn by warp');
    OutTextXY(0,8,'Eng Lv Tr Du Mo  mc 1 2 3 4 5 6 7 8 9');
    Line(0,17,37*8-2,17);
    Line(3*8+3,0,3*8+3,20+9*8-1);
    Line(6*8+4,0,6*8+4,20+9*8-1);
    Line(19*8+4,0,19*8+4,20+9*8-1);
    for i:=1 to 9 do Draw1Eng(i);
  end;

procedure Draw1Beam (i:byte);
  var   s       : string[59];
        s1      : string[6];
  begin
    with Beams[i] do
    begin
      Str(i:2,s);
      Str(tech:4,s1); s:=s+s1;
      Str(T:3,s1); s:=s+s1;
      Str(D:3,s1); s:=s+s1;
      Str(M:3,s1); s:=s+s1;
      Str(cost:3,s1); s:=s+s1;
      Str(mass:4,s1); s:=s+s1;
      Str(kill:5,s1); s:=s+s1;
      Str(expl:4,s1); s:=s+s1;
      Str(SweepRate*i*i:6,s1); s:=s+s1;
      Str(WebSweepRate*i*i:4,s1); s:=s+s1;
    end;
    OutTextXY(0,20+(i-1)*8,s);
  end;

procedure DrawBeams;
  var   i       : byte;
  begin
    Clear(IX1,IY1,IX2,IY2);
    SetColor(White);
    OutTextXY(0,0,'           Cost                    Sweep');
    OutTextXY(0,8,'No. Lv Tr Du Mo mc Mass Kill Exp Mine Web');
    Line(0,17,41*8-2,17);
    Line(3*8+3,0,3*8+3,20+10*8-1);
    Line(6*8+3,0,6*8+3,20+10*8-1);
    Line(18*8+3,0,18*8+3,20+10*8-1);
    Line(23*8+3,0,23*8+3,20+10*8-1);
    Line(32*8+3,0,32*8+3,20+10*8-1);
    for i:=1 to 10 do Draw1Beam(i);
  end;

procedure Draw1Torp (i:byte);
  var   s       : string[59];
        s1      : string[6];
  begin
    with Torps[i] do
    begin
      Str(i:2,s);
      Str(tech:4,s1); s:=s+s1;
      Str(T:3,s1); s:=s+s1;
      Str(D:3,s1); s:=s+s1;
      Str(M:3,s1); s:=s+s1;
      Str(tcost:4,s1); s:=s+s1;
      Str(mass:3,s1); s:=s+s1;
      Str(cost:4,s1); s:=s+s1;
      Str(kill:4,s1); s:=s+s1;
      Str(expl:5,s1); s:=s+s1;
      Str(IIF(myrace=9,4,1)*i*i:6,s1); s:=s+s1;
    end;
    OutTextXY(0,20+(i-1)*8,s);
  end;

procedure DrawTorps;
  var   i       : byte;
  begin
    Clear(IX1,IY1,IX2,IY2);
    SetColor(White);
    OutTextXY(0,0,'            Tube             Torpedo');
    OutTextXY(0,8,'No. Lv Tr Du Mo  mc kt  mc Kill Expl Mines');
    Line(0,17,42*8-2,17);
    Line(3*8+3,0,3*8+3,20+10*8-1);
    Line(6*8+4,0,6*8+4,20+10*8-1);
    Line(22*8+4,0,22*8+4,20+10*8-1);
    for i:=1 to 10 do Draw1Torp(i);
  end;

procedure WriteHull (n:int; highlight:boolean; hlc:byte; draw:boolean);
  var   s       : string[4];
        ls      : byte absolute s;
        k       : int;
  begin
    k:=lbase^.HH[n];
    if k<>0 then s:='('+NStrMax(lbase^.HH[n],1,'+')+')'
            else s:='   ';
    TextAttr:=IIF(highlight,hlc,IIF(ha[n],White,__Gray));
    WriteXY(HX,PY+1+n,Hulls[RaceHull[myrace,n]].name+' '+s);
    if draw then DrawShip;
  end;

procedure WriteEng (n:int; highlight:boolean; hlc:byte; draw:boolean);
  var   s       : string[4];
        ls      : byte absolute s;
        k       : int;
  begin
    k:=lbase^.EE[n];
    if k<>0 then s:='('+NStrMax(lbase^.EE[n],1,'+')+')'
            else s:='   ';
    TextAttr:=IIF(highlight,hlc,IIF(ea[n],White,__Gray));
    WriteXY(EX,PY+1+n,Copy(Engines[n].name,1,17)+' '+s);
    if draw and (n=bldN[bldE]) then
    begin
      SetColor(IIF(highlight,Yellow,White));
      Draw1Eng(n);
    end;
  end;

procedure WriteBeam (n:int; highlight:boolean; hlc:byte; draw:boolean);
  var   s       : string[4];
        ls      : byte absolute s;
        k       : int;
  begin
    k:=lbase^.WW[n];
    if k<>0 then s:='('+NStrMax(lbase^.WW[n],2,'+')+')'
            else s:='    ';
    TextAttr:=IIF(highlight,hlc,IIF(wa[n],White,__Gray));
    WriteXY(WX,PY+1+n,Copy(Beams[n].name,1,15)+' '+s);
    if draw and (n=bldN[bldW]) then
    begin
      SetColor(IIF(highlight,Yellow,White));
      Draw1Beam(n);
    end;
  end;

procedure WriteTorp (n:int; highlight:boolean; hlc:byte; draw:boolean);
  var   s       : string[4];
        ls      : byte absolute s;
        k       : int;
  begin
    k:=lbase^.LL[n];
    if k<>0 then s:='('+NStrMax(lbase^.LL[n],2,'+')+')'
            else s:='    ';
    TextAttr:=IIF(highlight,hlc,IIF(ta[n],White,__Gray));
    WriteXY(TX,PY+1+n,Torps[n].name+' '+s);
    if draw and (n=bldN[bldT]) then
    begin
      SetColor(IIF(highlight,Yellow,White));
      Draw1Torp(n);
    end;
  end;

procedure WriteCur (j:bldType; highlight:boolean; hlc:byte; draw:boolean);
  begin
    case j of
      bldH      : WriteHull(bldN[bldH],highlight,hlc,draw);
      bldE      : WriteEng(bldN[bldE],highlight,hlc,draw);
      bldW      : if bldA[bldW] then WriteBeam(bldN[bldW],highlight,hlc,draw);
      bldT      : if bldA[bldT] then WriteTorp(bldN[bldT],highlight,hlc,draw);
    end;
  end;

procedure WriteAll;
  var   i,n     : int;
        j       : bldType;
  begin
    WriteResources;
    for i:=1 to maxH do
    begin
      n:=1-lbase^.HH[i];
      with Hulls[RaceHull[myrace,i]] do
        ha[i]:=(n<=0) or ((ttt>=T*n) and (ddd>=D*n) and (mmm>=M*n) and (lbase^.Hl>=tech));
      WriteHull(i,No,0,No);
    end;
    for i:=1 to 9 do
    begin
      n:=lbase^.EE[i];
      with Engines[i] do
        ea[i]:=(n>0) or ((ttt>=T*n) and (ddd>=D*n) and (mmm>=M*n) and (lbase^.El>=tech));
      WriteEng(i,No,0,No);
    end;
    for i:=1 to 10 do
    begin
      n:=lbase^.WW[i];
      with Beams[i] do
        wa[i]:=(n>0) or ((ttt>=T*n) and (ddd>=D*n) and (mmm>=M*n) and (lbase^.Wl>=tech));
      if bldA[bldW] then WriteBeam(i,No,0,No);
    end;
    for i:=1 to 10 do
    begin
      n:=lbase^.LL[i];
      with Torps[i] do
        ta[i]:=(n>0) or ((ttt>=T*n) and (ddd>=D*n) and (mmm>=M*n) and (lbase^.Tl>=tech));
      if bldA[bldT] then WriteTorp(i,No,0,No);
    end;
    for j:=bldH to bldT do WriteCur(j,Yes,Yellow,No);
  end;

procedure WriteClone;
  var   n       : int;
  begin
    TextAttr:=Yellow;
    WriteXY(HX,PY+2,Hulls[clship^.hull].name);
    n:=clship^.El;
    WriteXY(EX,PY+1+n,Copy(Engines[n].name,1,17));
    n:=clship^.Wl;
    if n<>0 then WriteXY(WX,PY+1+n,Copy(Beams[n].name,1,15));
    n:=clship^.Tl;
    if n<>0 then WriteXY(TX,PY+1+n,Torps[n].name);
  end;

procedure WriteCost;
  var   s               : string[56];
        s1              : string[4];
        tt,dd,mm,cc     : int;
  begin
    case j of
      bldH      : with Hulls[RaceHull[myrace,bldN[bldH]]] do
                    begin s:=name; tt:=T; dd:=D; mm:=M; cc:=cost end;
      bldE      : with Engines[bldN[bldE]] do
                    begin s:=name; tt:=T; dd:=D; mm:=M; cc:=cost end;
      bldW      : with Beams[bldN[bldW]] do
                    begin s:=name; tt:=T; dd:=D; mm:=M; cc:=cost end;
      bldT      : with Torps[bldN[bldT]] do
                    begin s:=name+' tube'; tt:=T; dd:=D; mm:=M; cc:=tcost end;
    end;
    Clear(CostX*8,CostY*16,639,CostY*16+15);
    TextAttr:=Yellow;
    WriteXY(CostX,CostY,'1 '+s+' =');
    if tt>0 then begin Str(tt:4,s1); WriteXY(CostX+22,CostY,s1+' Tr +') end;
    if dd>0 then begin Str(dd:4,s1); WriteXY(CostX+31,CostY,s1+' Du +') end;
    if mm>0 then begin Str(mm:4,s1); WriteXY(CostX+40,CostY,s1+' Mo +') end;
    Str(cc:4,s1); WriteXY(CostX+49,CostY,s1+' mc');
  end;

procedure ClearBeams;
  begin
    Clear(WX*8,(PY+2)*16,(WX+20)*8-1,(PY+12)*16-1);
  end;

procedure ClearTorps;
  begin
    Clear(TX*8,(PY+2)*16,(TX+11)*8-1,(PY+12)*16-1);
  end;

procedure GetShip;
  var   h,n     : int;
  begin
    if clone then h:=clship^.hull
    else begin
      if FastKeyPressed then
      begin
        n:=PreviewKey;
        if (n=$4800) or (n=$5000) then Exit;
      end;
      h:=RaceHull[myrace,bldN[bldH]];
    end;
    currhull:=h;
    with Hulls[h] do
    begin
      {Clear(SX,ShY,ShX+22*8-1,ShY+9*10+7);}
      LoadPic(Left,pic,No,No,No,No);
      SetPal;
      if clone then blW:=clship^.weapons
               else blW:=weapons;
      if blW>0 then
      begin
        if not clone then for n:=1 to 10 do WriteBeam(n,n=bldN[bldW],Yellow,No);
      end
      else ClearBeams;
      if clone then blT:=clship^.launchers
               else blT:=launchers;
      if blT>0 then
      begin
        if not clone then for n:=1 to 10 do WriteTorp(n,n=bldN[bldT],Yellow,No);
      end
      else ClearTorps;
      bldA[bldH]:=Yes;
      bldA[bldE]:=Yes;
      bldA[bldW]:=blW>0;
      bldA[bldT]:=blT>0;
    end;
{    DrawShip;}
  end;

function GetBldVal (v0,v2:byte; x,y:int) : byte;
  var   ch      : word;
        v       : byte;
        s       : string[2];
  begin
    v:=v0;
    repeat
      Clear(x,y,x+2*8-1,y+7);
      SetColor(White);
      Str(v,s);
      OutTextXY(x,y,s);
      repeat ArrowBlink(x+3*8,y) until KeyPressed;
      ch:=ReadKey;
      case ch of
        $4B00   : if v>0 then dec(v);
        $4D00   : if v<v2 then inc(v);
      end;
    until (ch=13) or (ch=27);
    Clear(x+3*8,y,x+5*8-1,y+7);
    {if ch=27 then v:=v0;}
    GetBldVal:=v;
  end;

procedure WriteCalculation(var last :int);
  const limit           = 471;
    step            = 9;
  var   l,n,e           : int;
        ts,ds,ms,cs,cs1,cs2 : long;
        Hn,En,Wn,Tn     : byte;
        navail          : boolean;
        s                       : string[5];
  type  str26   = string[26];
        str7    = string[7];
  function NumStr (a:long) : str7;
    var s       : str7;
    begin
      if a=0 then s:='       '
             else Str(a:7,s);
      NumStr:=s;
    end;
  procedure WriteCalcStr (nm:str26; t,d,m,c:long; add:boolean);
    begin
      if add then
        begin inc(ts,t); inc(ds,d); inc(ms,m); inc(cs,c) end;
      if (l=limit-step) then Clear(CX,l,639,479);
      RPad(nm,26);
      OutTextXY(CX,l,'  '+nm+NumStr(t)+NumStr(d)+NumStr(m)+NumStr(c));
      inc(l,step);
    end;
  begin
    if clone then
    begin
      Hn:=clship^.hull;
      En:=clship^.El;
      Wn:=clship^.Wl;
      Tn:=clship^.Tl;
    end
    else begin
      Hn:=RaceHull[myrace,bldN[bldH]];
      En:=bldN[bldE];
      Wn:=bldN[bldW];
      Tn:=bldN[bldT];
    end;
    navail:=No;
    ts:=0; ds:=0; ms:=0; cs:=0;
    cs1:=0;                             { tech upgrade expenses }
    Clear(CX,CY,639,IIF(build,StY*16-1,479));
    SetColor(Yellow);
    if clone then s:='clone' else s:='build';
    OutTextXY(CX,CY,'Resources to '+s+' this ship:    Tr     Du     Mo     mc');
    l:=CY+15;
    SetColor(White);
    Line(CX+32*8,l-4,639,l-4);
    with Hulls[Hn] do
    begin
      n:=1-IIF(clone,0,lbase^.HH[bldN[bldH]]-IIF(lbase^.cHl=bldN[bldH],1,0));
      if n>0 then
      begin
        if SWPlan and (tech>6) and (tech>lbase^.Hl) and (lplan^.Nrace<>1) then
          begin navail:=Yes; SetColor(LightRed) end;
        if ShowUpgradeCosts then
        begin
        if tech-lbase^.Hl>0 then WriteCalcStr('Upgrade to hull tech '+NStr(tech),0,0,0,UpgradeCost(lbase^.Hl,tech),Yes);
        inc(cs1,UpgradeCost(lbase^.Hl,tech));
        end;
        WriteCalcStr(NStr(n)+' '+Proper(n,name),n*T,n*D,n*M,n*cost,Yes);
      end;
      e:=engines;
    end;
    with Engines[En] do
    begin
      SetColor(White);
      n:=e-IIF(clone,0,lbase^.EE[bldN[bldE]]-IIF(lbase^.cEl=bldN[bldE],Hulls[RaceHull[myrace,lbase^.cHl]].engines,0));
      if n>0 then
      begin
        if SWPlan and (tech>6) and (tech>lbase^.El) and (lplan^.Nrace<>8) then
          begin navail:=Yes; SetColor(LightRed) end;
        if ShowUpgradeCosts then
        begin
        if tech-lbase^.El>0 then WriteCalcStr('Upgrade to engine tech '+NStr(tech),0,0,0,UpgradeCost(lbase^.El,tech),Yes);
        inc(cs1,UpgradeCost(lbase^.El,tech));
        end;
        WriteCalcStr(NStr(n)+' '+Proper(n,name),n*T,n*D,n*M,n*cost,Yes);
      end;
    end;
    if bldA[bldW] and (blW>0) then
    with Beams[Wn] do
    begin
      SetColor(White);
      n:=blW-IIF(clone,0,lbase^.WW[bldN[bldW]]-IIF(lbase^.cWl=bldN[bldW],lbase^.cWn,0));
      if n>0 then
      begin
        if SWPlan and (tech>6) and (tech>lbase^.Wl) and (lplan^.Nrace<>7) then
          begin navail:=Yes; SetColor(LightRed) end;
        if ShowUpgradeCosts then
        begin
        if tech-lbase^.Wl>0 then WriteCalcStr('Upgrade to beam tech '+NStr(tech),0,0,0,UpgradeCost(lbase^.Wl,tech),Yes);
        inc(cs1,UpgradeCost(lbase^.Wl,tech));
        end;
        WriteCalcStr(NStr(n)+' '+Proper(n,name),n*T,n*D,n*M,n*cost,Yes);
      end;
    end;
    if bldA[bldT] and (blT>0) then
    with Torps[Tn] do
    begin
      SetColor(White);
      n:=blT-IIF(clone,0,lbase^.LL[bldN[bldT]]-IIF(lbase^.cTl=bldN[bldT],lbase^.cTn,0));
      if n>0 then
      begin
        if SWPlan and (tech>6) and (tech>lbase^.Tl) and (lplan^.Nrace<>9) then
          begin navail:=Yes; SetColor(LightRed) end;
        if ShowUpgradeCosts then
        begin
        if tech-lbase^.Tl>0 then WriteCalcStr('Upgrade to torpedo tech '+NStr(tech),0,0,0,UpgradeCost(lbase^.Tl,tech),Yes);
        inc(cs1,UpgradeCost(lbase^.Tl,tech));
        end;
        WriteCalcStr(NStr(n)+' '+Proper(n,name+' tube'),n*T,n*D,n*M,n*tcost,Yes);
      end;
    end;
    if clone then WriteCalcStr('Cloning expenses',0,0,0,(cs-cs1)*(CloneCost[player]-100) div 100,Yes);
    if navail then
    begin
      SetColor(LightRed);
      OutTextXY(CX,l,'  REGISTER YOUR COPY OF PLANETS TO BUILD HIGH TECH PARTS');
      can:=No;
      Exit;
    end;
    needcash:=cs;
    if ts+ds+ms+cs=0 then
    begin
      Clear(CX,CY,639,CY+15);
      SetColor(Yellow);
      OutTextXY(CX,CY,'This ship can be built for FREE!');
      can:=Yes;
    end
    else begin
      Line(CX+32*8,l,639,l);
      inc(l,5);
      SetColor(Yellow);
      WriteCalcStr('Total',ts,ds,ms,cs,No);
      can:=(ttt>=ts) and (ddd>=ds) and (mmm>=ms) and (ccc>=cs);
      SetColor(White);
      if l<=480-8-IIF(can,17,0) then
        if (ShowAviableRes) then WriteCalcStr('Available resources',ttt,ddd,mmm,ccc,No);
      if (l<=480-8-IIF(can,17,0)) and (not ShowUpgradeCosts) then
        begin
        cs2 :=      UpgradeCost(lbase^.Tl,Torps[Tn].tech);
        cs2 := cs2+ UpgradeCost(lbase^.Wl,Beams[Wn].tech);
        cs2 := cs2+ UpgradeCost(lbase^.El,Engines[En].tech);
        cs2 := cs2+ UpgradeCost(lbase^.Hl,Hulls[Hn].tech);
        if (cs2>0) then WriteCalcStr('Total upgrade costs',0,0,0,cs2,Yes);
        can:=(ttt>=ts) and (ddd>=ds) and (mmm>=ms) and (ccc>=cs+cs2);
        end;
      if can then
      begin
        if (l<=480-8-IIF(can,17,0)) and RWMode then
          if (ShowAviableRes) then
            WriteCalcStr('Remaining resources',ttt-ts,ddd-ds,mmm-ms,ccc-cs,No);
      end
      else begin
        SetColor(LightRed);
        if (l<=480-8-IIF(can,17,0)) then
        if (ShowAviableRes) then
          WriteCalcStr('MORE RESOURCES NEEDED',MaxL(ts-ttt,0),MaxL(ds-ddd,0),MaxL(ms-mmm,0),MaxL(cs-ccc,0),No);
      end;
    end;
    if (l<limit)and(last>=limit) then 
    begin
      Clear(CX,l,639,479);
      if RWM and build then
      begin
          TextAttr:=White;
          WriteXY(StX+1,StY,'STOP CONSTRUCTION');
          TextAttr:=LightGreen;
          WriteXY(StX+1,StY,'S');
      end;
    end;
    last:=l;

    ExtFeatBuildingWriteCalcHook(Hn,En,blW,Wn,blT,Tn);

    if build then Exit;
    {begin
      TextAttr:=Yellow;
      WriteXY(BX,StY,'Building:');
      TextAttr:=White;
      WriteXY(BX+10,StY,Hulls[RaceHull[myrace,lbase^.cHl]].name);
    end
    else}
    if RWM and can and ShowUpgradeCosts then
    begin
      TextAttr:=White;
      if clone then WriteXY(StX+5,StY,'START CLONING')
               else WriteXY(StX,StY,'START CONSTRUCTION');
      TextAttr:=LightGreen;
      WriteXY(StX+IIF(clone,5,0),StY,'S');
    end;
  end;

procedure WriteBuild;
  var   e       : byte;
  begin
    Clear(CX,CY,639,479);
    with lbase^ do
    begin
      build:=(cHl<>0);
      if not build then Exit;
      TextAttr:=Yellow;
      WriteXY(BX,BY,'Currently building:');
      TextAttr:=White;
      with Hulls[RaceHull[myrace,cHl]] do
      begin
        WriteXY(BX+2,BY+2,name);
        e:=engines;
      end;
      WriteXY(BX+2,BY+3,NStr(e)+' '+Proper(e,Engines[cEl].name));
      if cWn>0 then WriteXY(BX+2,BY+4,NStr(cWn)+' '+Proper(cWn,Beams[cWl].name));
      if cTn>0 then WriteXY(BX+2,BY+5,NStr(cTn)+' '+Torps[cTl].name+' '+Proper(cTn,'tube'));
    end;
    if RWM then
    begin
      WriteXY(StX+1,StY,'STOP CONSTRUCTION');
      TextAttr:=LightGreen;
      WriteXY(StX+1,StY,'S');
    end;
  end;

function SpendResources (tr,du,mo,cash:long) : boolean;
  var   c       : long;
  begin
    if (ttt>=tr) and (ddd>=du) and (mmm>=mo) and (ccc>=cash) then
    begin
      with lplan^ do
      begin
        dec(T,tr);
        dec(D,du);
        dec(M,mo);
        c:=MinL(cash,funds);
        dec(funds,c);
        dec(supplies,cash-c);
      end;
      ChangeData(Pl,baseid);
      dec(ttt,tr); dec(ddd,du); dec(mmm,mo); dec(ccc,cash);
      dec(needcash,cash);
      SpendResources:=Yes;
    end
    else SpendResources:=No;
  end;

function BuildPart (n:int) : boolean;
  var   k       : byte;
  begin
    BuildPart:=No;
    k:=bldN[j];
    with lbase^ do
    case j of
      bldH      : begin
                    n:=Max(n,b0.HH[k]-HH[k]);
                    if n=0 then Exit;
                    with Hulls[RaceHull[myrace,k]] do
                      if (tech>Hl) or (not SpendResources(n*T,n*D,n*M,n*cost)) then Exit
                      else inc(HH[k],n);
                  end;
      bldE      : begin
                    n:=Max(n,b0.EE[k]-EE[k]);
                    if n=0 then Exit;
                    with Engines[k] do
                      if (tech>El) or (not SpendResources(n*T,n*D,n*M,n*cost)) then Exit
                      else inc(EE[k],n);
                  end;
      bldW      : begin
                    n:=Max(n,b0.WW[k]-WW[k]);
                    if n=0 then Exit;
                    with Beams[k] do
                      if (tech>Wl) or (not SpendResources(n*T,n*D,n*M,n*cost)) then Exit
                      else inc(WW[k],n);
                  end;
      bldT      : begin
                    n:=Max(n,b0.LL[k]-LL[k]);
                    if n=0 then Exit;
                    with Torps[k] do
                      if (tech>Tl) or (not SpendResources(n*T,n*D,n*M,n*tcost)) then Exit
                      else inc(LL[k],n);
                  end;
    end;
    ChangeData(Ba,baseid);
    BuildPart:=Yes;
  end;

function ConfirmBuild : boolean;
  var   ch              : word;
  begin
    TextAttr:=White;
    WriteXY(StX+18,StY,'? (Y/N)');
    TextAttr:=LightGreen;
    WriteXY(StX+21,StY,'Y');
    WriteXY(StX+23,StY,'N');
    ch:=ReadKey;
    ConfirmBuild:=(ch in [ord('y'),ord('Y')]);
    Clear((StX+18)*8,StY*16,639,479);
  end;

function BuildShip : boolean;
  var   j0              : bldType;
        ht,et,wt,lt     : byte; { techs needed }
        nh,ne,nw,nt     : int;  { parts needed, int! }
        k,x,y           : int;
        h               : sptr;
  begin
    BuildShip:=No;
    if not clone then WriteCur(j,Yes,Yellow,No);
    if not ConfirmBuild then Exit;
    if clone then
    begin
      ht:=Hulls[clship^.hull].tech;
      et:=Engines[clship^.El].tech;
      wt:=IIF(blW>0,Beams[clship^.Wl].tech,1);
      lt:=IIF(blT>0,Torps[clship^.Tl].tech,1);
    end
    else begin
      nh:=1-lbase^.HH[bldN[bldH]];
      ne:=Hulls[RaceHull[myrace,bldN[bldH]]].engines-lbase^.EE[bldN[bldE]];
      nw:=blW-lbase^.WW[bldN[bldW]];
      nt:=blT-lbase^.LL[bldN[bldT]];
      ht:=IIF(nh>0,Hulls[RaceHull[myrace,bldN[bldH]]].tech,1);
      et:=IIF(ne>0,Engines[bldN[bldE]].tech,1);
      wt:=IIF(bldA[bldW] and (nw>0),Beams[bldN[bldW]].tech,1);
      lt:=IIF(bldA[bldT] and (nt>0),Torps[bldN[bldT]].tech,1);
    end;
    with lbase^ do
    begin
      if (Hl<ht) and SpendResources(0,0,0,UpgradeCost(Hl,ht)) then Hl:=ht;
      if (El<et) and SpendResources(0,0,0,UpgradeCost(El,et)) then El:=et;
      if (Wl<wt) and SpendResources(0,0,0,UpgradeCost(Wl,wt)) then Wl:=wt;
      if (Tl<lt) and SpendResources(0,0,0,UpgradeCost(Tl,lt)) then Tl:=lt;
    end;
    ChangeData(Ba,baseid);
    if clone then
    begin
      dec(needcash,lplan^.funds);
      if needcash>0 then
      begin
        inc(lplan^.funds,needcash);
        dec(lplan^.supplies,needcash);
        ChangeData(Pl,baseid);
      end;
      with TTurn^.data^ do
      begin
        x:=xyplan[baseid,1];
        y:=xyplan[baseid,2];
      end;
      for k:=1 to 999 do
        if ShipIsHere(k,x,y) then
        begin
          h:=TTurn^.data^.ship[k];
          if (h^.owner=player) and ((k=cloneID) or (h^.fcode='cln')) then
          begin
            if k=cloneID then h^.fcode:='cln' else RandomFCode(h^.fcode);
            ChangeData(Sh,k);
          end;
        end;
      lock:=cloneID or LockS;
      chh:=27;
      Exit;
    end;
    WriteTechs;
    j0:=j;
    if nh>0 then begin j:=bldH; BuildPart(nh) end;
    if ne>0 then begin j:=bldE; BuildPart(ne) end;
    if bldA[bldW] and (nw>0) then begin j:=bldW; BuildPart(nw) end;
    if bldA[bldT] and (nt>0) then begin j:=bldT; BuildPart(nt) end;
    j:=j0;
    with lbase^ do
    begin
      cHl:=bldN[bldH];
      cEl:=bldN[bldE];
      cWl:=IIF(bldA[bldW],bldN[bldW],0);
      cWn:=blW;
      cTl:=IIF(bldA[bldT],bldN[bldT],0);
      cTn:=blT;
    end;
    ChangeData(Ba,baseid);
    WriteBuild;
    BuildShip:=Yes;
  end;

procedure CancelBuild;
  var   bldN0   : array [bldType] of byte;
        j0      : bldType;
  begin
    if ConfirmBuild and build then
    begin
      Move(bldN,bldN0,SizeOf(bldN));
      j0:=j;
      with lbase^ do
      begin
        bldN[bldH]:=cHl;
        j:=bldH;
        BuildPart(-1);
        bldN[bldE]:=cEl;
        j:=bldE;
        BuildPart(-Hulls[RaceHull[myrace,cHl]].engines);
        if cWl<>0 then
        begin
          bldN[bldW]:=cWl;
          j:=bldW;
          BuildPart(-cWn);
        end;
        if cTl<>0 then
        begin
          bldN[bldT]:=cTl;
          j:=bldT;
          BuildPart(-cTn);
        end;
        cHl:=0; cEl:=0;
        cWl:=0; cWn:=0;
        cTl:=0; cTn:=0;
      end;
      ChangeData(Ba,baseid);
      Move(bldN0,bldN,SizeOf(bldN));
      j:=j0;
      build:=No;
      WriteAll;
    end;
    WriteCalculation(last);
  end;

procedure DrawFirst;
  begin
    ClearDevice;
    SetPal;
    WriteTechs;
    SetLineStyle(SolidLn,0,NormWidth);
    SetColor(LightGray);
    Line(0,PY*16-8,639,PY*16-8);
    Line(EX*8-9,(PY+12)*16+7,639,(PY+12)*16+7);
    Line(EX*8-9,PY*16-8,EX*8-9,479);
    Line(WX*8-9,PY*16-8,WX*8-9,(PY+12)*16+7);
    Line(TX*8-9,PY*16-8,TX*8-9,(PY+12)*16+7);
    Line(RX*8-9,0,RX*8-9,PY*16-8);
    Line(LX*8-8,0,LX*8-8,PY*16-8);      { -8! for DrawTorps }
    Line(EX*8-9,CostY*16+16+7,639,CostY*16+16+7);
    WriteXY(HX,PY,'Hulls:');
    WriteXY(EX,PY,'Engines:');
    WriteXY(WX,PY,'Beams:');
    WriteXY(TX,PY,'Tubes:');
    GetShip;
    if clone then
    begin
      WriteResources;
      WriteClone;
      DrawShip;
      build:=No;
      WriteCalculation(last);
    end
    else begin
      WriteAll;
      build:=lbase^.cHl<>0;
      if build then WriteBuild else WriteCalculation(last);
    end;
    case j of
      bldH      : DrawShip;
      bldE      : DrawEng;
      bldW      : DrawBeams;
      bldT      : DrawTorps;
    end;
  end;

procedure ShowAllHullfuncs(hull:int);
{$IFDEF VPACC}
  var qr : THullFuncQueryResult;
  begin
    EnumNewShipFunctions(qr, hull);
    if qr.count<>0 then begin
      DisplayHullfuncs(qr,true,lbase^.owner,-1);
      FreeShipFuncQueryResult(qr);
      DrawFirst;
    end;
  end;
{$ELSE}
  begin end;
{$ENDIF}

BEGIN
  if (turn<today) or (ltype<>LockP) or (lplan=nil) {or (lbase=nil)} then Exit;

  if (lbase=nil) then begin {N pressed -> New Base Simulation }
    mylock := lock and LockLo;
    b0.owner:=player;
    b0.El:=1;b0.Hl:=1;b0.Wl:=1;b0.Tl:=1;b0.fighters:=0;b0.defense:=0;b0.damage:=0;
    b0.fShip:=0;b0.fOp:=0;b0.order:=0;b0.cHl:=0;b0.cEl:=0;b0.cWl:=0;b0.cWn:=0;b0.cTl:=0;b0.cTn:=0;b0.cBn:=0;
    case lplan^.nrace of
      1:  b0.hl:=10;
      7:  b0.wl:=10;
      8:  b0.el:=10;
      9:  b0.Tl:=10;
    end;
    for ii := 1 to 9 do b0.EE[ii]:=0; 
    for ii := 1 to 20 do b0.HH[ii]:=0; 
    for ii := 1 to 10 do begin b0.WW[ii]:=0; b0.LL[ii]:=0; b0.TT[ii]:=0; end;
    TTurn^.data^.base[mylock]:=@b0;
    lbase:=TTurn^.data^.base[mylock];
  end
    else mylock := 0;
  
    
  if TrueHullByRace then myrace:=Race[lbase^.owner]
                    else myrace:=lbase^.owner;
  RWM:=RWMode and (lbase^.owner=player);
  baseid:=lock and LockLo;
  if (mylock=0) then if RWM then LoadBDis(baseid,b0);
  clone:=(ch=ord('c')) and (cloneID<>0);
  if clone then clship:=TTurn^.data^.ship[cloneID];
  bldA[bldW]:=Yes;
  bldA[bldT]:=Yes;
  maxH:=0;
  while (maxH<20) and (RaceHull[myrace,maxH+1]<>0) do inc(maxH);
  if bldN[bldH]>maxH then bldN[bldH]:=1;
  if (turn<=today) then
  begin
    UnlockReservedMemory(ReservedMemory);
    TCombatInit(No);
    MouseOff;
  end;
  MouseDisabled:=True;
  mx:=MouseX; my:=MouseY;
  helpscr:=3;
  j:=bldH;
  
  if (mylock>0) then begin {Pretend Base}
    PretendHost;
    TTurn^.data^.base[mylock]:=nil;
    lbase:=nil;
    force:=mylock and LockP; ForceKey:=13; lock:=0;
  end else begin {Build Base}
    DrawFirst;
    repeat
      if not clone then
      begin
        WriteCur(j,Yes,LightGreen,Yes);
        WriteCost;
      end;
      chh:=ReadKey;
      if not clone then
      begin
        WriteCur(j,No,0,j<>bldH);
        keyOK:=Yes;
        case chh of
{up,dn} $4800,$5000,$4900,$5100 :
{pgup,pgdn}       begin
                    ii:=IIF(j=bldH,maxH,IIF(j=bldE,9,10));
                    kk:=IIF(chh<$5000,-1,1);
                    jj:=IIF(Hi(chh) and 1=0,1,5)*kk;
                    inc(bldN[j],jj);
                    if (bldN[j]=0) or (bldN[j]>ii) then dec(bldN[j],ii*kk);
                    if j=bldH then GetShip;
                  end;
{lt,rt} $4B00,$4D00     :
                  begin
                    WriteCur(j,Yes,Yellow,No);
                    repeat
                      if chh=$4B00 then j:=bldType(IIF(j=bldH,byte(bldT),byte(pred(j))))
                                   else j:=bldType(IIF(j=bldT,byte(bldH),byte(succ(j))));
                    until bldA[j];
                    case j of
                      bldH      : DrawShip;
                      bldE      : DrawEng;
                      bldW      : DrawBeams;
                      bldT      : DrawTorps;
                    end;
                  end;
        ord('b'): if (j=bldH) and (bldA[bldW]) then
                    blW:=GetBldVal(blW,Hulls[RaceHull[myrace,bldN[bldH]]].weapons,ShX+15*8,ShY+3*10);
        ord('t'): if (j=bldH) and (bldA[bldT]) then
                    blT:=GetBldVal(blT,Hulls[RaceHull[myrace,bldN[bldH]]].launchers,ShX+15*8,ShY+4*10);
        ord('+'): if RWM and BuildPart(1) then WriteAll;
        ord('-'): if RWM and BuildPart(-1) then WriteAll;
{F1}    $3B00   : begin
                    if BadVideoOrMouse then RestoreCrtMode;
                    if customBGI then SetGraphMode(bgiMode)
                    else SetGraphMode(VGAHi);
                    Help;
                    DrawFirst;
                  end;
{_u}    ord('U'): begin ShowUpgradeCosts:=not ShowUpgradeCosts; WriteAll; end;
{n}     ord('n'): if (turn=today) then
          begin
            PretendHost;
            DrawFirst;
          end;
{_f}    ord('F'): ShowAllHullfuncs(RaceHull[myrace,bldN[bldH]]);
        else    keyOK:=No;
      end;
      if keyOK then WriteCalculation(last);
    end;
    if RWM and (chh=ord('s')) and ShowUpgradeCosts then
      if build then CancelBuild
               else if can and BuildShip then WriteAll;
    until chh=27;
    end;
  
  {valid for Build and Pretend Build}
  if (turn<=today) then
  begin
    TCombatFinish;
    LockReservedMemory;
    if BadVideoOrMouse then RestoreCrtMode;
    if not useSVGA then
      if customBGI then SetGraphMode(bgiMode)
      else SetGraphMode(VGAHi);
    DrawRightScreen;
    helpscr:=0;
    MoveMouseTo(mx,my);
    MouseDisabled:=False;
    MouseOn;
    ResetMouse;
    if (lock<>0) and (mylock=0) then begin force:=lock; ForceKey:=13 end;
    if (mylock=0) then ch:=2
                  else ch:=3;                { redraw map }
  end;
END;

procedure PretendBase;
begin
  BaseBuild;
end;

Procedure PretendBuild;
var
   TempPlanet: PRec;
   TempBase  : BRec;
   templplan : pptr;
   templbase : bptr;

   templtype : int;
   tempturn  : int;
   tempCloneID :int;
   tempplayer  :int;
   tempbldN  : array [bldType] of byte;
   tempShowUpgradeCosts : boolean;
   tempSWPlan: Boolean;

   maxH : int;
   HullFound: Boolean;
   HullRace : int;
   i,jj : int;

function ChooseOneRace : int;
const
        MsgX    = 1;
        MsgY    = 6;
        KeyY    = (MsgY+20)*16+10;

 var    i,i0,im : byte;
        ch      : word;

  begin
    Clear(0,0,479,479);

{    Clear(MsgX*8,MsgY*16,(MsgX+40)*8-1,(MsgY+20)*16-1);
    Clear(MsgX*8,KeyY,(MsgX+40)*8-1,KeyY+8+7);}

    TextAttr:=cMsg;
    WriteXY(MsgX+4,MsgY,'Select race to show ships:');
    WriteXY(MsgX+4,MsgY+17,'    Enter to finish selection');
    WriteXY(MsgX+4,MsgY+18,'    Esc to cancel');
    TextAttr:=White;
    WriteXY(MsgX+8,MsgY+17,'Enter');
    WriteXY(MsgX+8,MsgY+18,'Esc');

    im:=11;
    for i:=1 to 11 do
    begin
      TextAttr:=IIF(No,Yellow,DarkGray);
      WriteXY(MsgX+6,MsgY+1+i,RaceFull[i]);
    end;
    i:=1;
    ChooseOneRace:=i;
    repeat
      TextAttr:=IIF(Yes,Yellow,DarkGray);
      WriteXY(MsgX+6,MsgY+1+i,RaceFull[i]);
      ch:=ReadKey;
      TextAttr:=IIF(No,Yellow,DarkGray);
      WriteXY(MsgX+6,MsgY+1+i,RaceFull[i]);

      case ch of
        $4800   : i:=IIF(i=1,im,i-1);
        $5000   : i:=IIF(i=im,1,i+1);
        13      : ChooseOneRace := i;
        27      : ChooseOneRace := 0;
      end;
    until ch in [13,27];
  end;


begin

   tempbldN[bldH] := bldN[bldH];
   tempbldN[bldE] := bldN[bldE];
   tempbldN[bldW] := bldN[bldW];
   tempbldN[bldT] := bldN[bldT];

   {find owner}
   HullFound := False;
   if (ltype=LockS) then
          begin
            if (lship^.hull<>-1) then
             begin
              {find if this hull belongs to player}
              maxH :=0;
              HullFound := False;
              while (maxH<20) and (RaceHull[lship^.owner,maxH+1]<>0) do inc(maxH);
              for i:= 1 to maxH do
                if (RaceHull[lship^.owner,i]=lship^.hull) then
                 begin
                   HullFound := True;
                   HullRace  := lship^.owner;
                   bldN[bldH]:= i;
                   if (lship^.El>=1)and(lship^.El<=9)  then bldN[bldE]:=lship^.El
                                                       else bldN[bldE]:=1;
                   if (lship^.Wl>=1)and(lship^.Wl<=10) then bldN[bldW]:=lship^.Wl
                                                       else bldN[bldW]:=1;
                   if (lship^.Tl>=1)and(lship^.Tl<=10) then bldN[bldT]:=lship^.Tl
                                                       else bldN[bldT]:=1;
                 end;
             end;

            if (HullFound = False) then
            begin
              for jj:= 1 to 11 do
              if (jj <> lship^.owner)and not HullFound then
              begin
                maxH :=0;
                while (maxH<20) and (RaceHull[jj,maxH+1]<>0) do inc(maxH);
                for i:= 1 to maxH do
                   if (RaceHull[jj,i]=lship^.hull) then
                    begin
                      HullFound := True;
                      HullRace  := jj;
                      bldN[bldH]:= i;
                      if (lship^.El>=1)and(lship^.El<=9)  then bldN[bldE]:=lship^.El
                                                          else bldN[bldE]:=1;
                      if (lship^.Wl>=1)and(lship^.Wl<=10) then bldN[bldW]:=lship^.Wl
                                                          else bldN[bldW]:=1;
                      if (lship^.Tl>=1)and(lship^.Tl<=10) then bldN[bldT]:=lship^.Tl
                                                          else bldN[bldT]:=1;
                    end;
              end;
            end;
          end;
   {choose race}

   if (lock = 0) then
   begin
     HullRace := ChooseOneRace;
     if (HullRace <> 0) then HullFound := True;
     bldN[bldH]:=1;
     bldN[bldE]:=9;
     bldN[bldW]:=1;
     bldN[bldT]:=1;
   end;

   {store values}
   templtype := ltype;
   tempturn  := turn;
   tempplayer := player;
   tempCloneID := CloneID;
   templplan := lplan;
   templbase := lbase;
   tempShowUpgradeCosts := ShowUpgradeCosts;
   tempSWPlan := SWPlan;

   {make proxy planet}
   ShowUpgradeCosts := No;
   ltype     := LockP;
   turn      := today;
   CloneID   := 0;           {no cloning}
   player    := player+20; {make read only mode, Changed by Quapla: was := 20}
   lplan     := @TempPlanet;
   lbase     := @TempBase;
   lbase^.owner := HullRace;
   lbase^.El    := 1;
   lbase^.Hl    := 1;
   lbase^.Wl    := 1;
   lbase^.Tl    := 1;
   for i:=1 to 9 do lbase^.EE[i]:=0;
   for i:=1 to 20 do lbase^.HH[i]:=0;
   for i:=1 to 10 do lbase^.WW[i]:=0;
   for i:=1 to 10 do lbase^.LL[i]:=0;
   for i:=1 to 10 do lbase^.TT[i]:=0;
   lbase^.cHl := 0;
   lbase^.cEl := 0;
   lbase^.cWl := 0;
   lbase^.cWn := 0;
   lbase^.cTl := 0;
   lbase^.cTn := 0;
   lbase^.cBn := 0;

   lplan^.T     := 100000;
   lplan^.D     := 100000;
   lplan^.M     := 100000;
   lplan^.funds := 1000000;
   lplan^.supplies := 0;

   {proxy build}
   SWPlan := No;
   ShowAviableRes := No;
   if (HullFound) then  BaseBuild;
   ShowAviableRes := Yes;
   SWPlan := tempSWPlan;

   {restore old values}
   ltype := templtype;
   turn  := tempturn;
   player := tempplayer;
   CloneID := tempCloneID;
   lplan := templplan;
   lbase := templbase;
   ShowUpgradeCosts := tempShowUpgradeCosts;

   bldN[bldH] := tempbldN[bldH];
   bldN[bldE] := tempbldN[bldE];
   bldN[bldW] := tempbldN[bldW];
   bldN[bldT] := tempbldN[bldT];

end;

{  Below procedure is for forecasting next turn     minerals on given base/planet.
  A lot of host actions have to be done.}
  
procedure RunHost(number :word; TempShipsPtr: stptr);
var
   TempShips: shipTable;
   GoodShips: GoodShipsPtr; {Ship that will be processed}
   TowedBy  : TowedByPtr;
   c        : byte;
   maxH : int;
   HullFound_: Boolean;
   HullRace : int;
   k,i,jj,mkt : int;
   Rt,Rd,Rm,Rcash,RSup: long;
   targetfighters,x,y,hn : word;
   CloneCost_ : double;

   supprod,HissHChange,alch,alch_rest: long;
   h            : sptr;

   xx,yy,fc,fa  : int;
   fh1          : sptr;
   cost         : TFullPrice;

{
     DONE as listed by Donovan:
      0. -> DONE Auxhost1 - Addon Teleport
      1. -> DONE Lady Royale generates MCs
          - Rob (only for ships)
      1b -> DONE -Hiss
      3. -> DONE -Build fighters (incl. 'lfm')
      2. -> DONE -Repair Self (Borg)
      4. -> DONE Cargo drop (ship - planet)
      4a. -> DONE Transfers (ship to foreign ship) (only for ships)
      4b. to be DONE Beam transfer fcodes (by ID) (only for ships)
          - including give ships (gsX) (only for ships)
      Planets beam up money ("bum") (need to do)
      4d. Gather missions 
      5. -> DONE Alchemy
      6. -> DONE Lay mines
         -> DONE Lay web mines
      Mine sweep/scoop (only for ships, scoop to be done)
          - Web drain (only for ships)
      6a. -> DONE Starbases fix or recycle ships
      7. -> Clone ships
          - Super refit (only for ships)
          - Force a surrender at starbase (only for ships)
      7aa -> DONE Mass check, repair & mkt
      7a. -> DONE Towing ships move
      Cobol Ramscoop makes fuel(only for ships, maybe to be done for towing/moving)
      7a. -> DONE Most ships move (Incl. HYP)
      Cobol Ramscoop makes fuel (only for ships see above)
      DONE? Intercepting ships move
      Cobol Ramscoop makes fuel (only for ships see above)
      7.  -> DONE later Glory device ships detonate
      7a -> DONE Firecloud chunnel
      8. --> Done Starbase Primary Orders
      8a. -> Done Starbases build 'free' fighters
      9. -> DONE Starbases dump parts (dmp)
      11. -> DONE Mass check, repair & mkt
          - New natives appear (cant simulate that *g)
      12. -> DONE Colonise ships
      12a. -> DONE Glory device ships detonate
      12  -> DONE before Mass check, repair & mkt
          - Ship vs. ship combat (only for ships)
          - Borg gather debris (only for ships)
      12b -> DONE Terraforming  (all formulas only valid for THost not for PHost)
      13. -> DONE Structure decay
      13a. ->	DONE Fascists Pillage planets
      13a. ->	DONE Rebel Ground Attack
      14. -> DONE Happiness change computed
          -> Unity-Addon: DA? can add Supps  (Quapla)
      15. -> Done Supplies produced (inc Bovinoids)
      16. -> Done Taxes produce MCs (if HP > 30)
      17. -> DONE Borg assimilate natives
      17. -> DONE Population growth (if HP > 69)
      17. -> DONE Overpopulation dies/eats supplies
      17. -> DONE Amorphous worms eat clans
      17. -> DONE Riots
      17. -> DONE Civil wars
      18. -> DONE Mines produce minerals
      Trans-uranium mutation (need to do?)
      (extract from Donovan's VGA Planets Helppages)

     INFO:
           fighters and torpedos are not converted into
           materials when colonize or recycle.
            
     NOT DONE :
            Give ship (Need to be done?)
            Fed Super Refit (What does this change?)
            mine scoop 
            PHost formulas
            Implement universal usage
   }

{taken from vpa2.pas}
function _UnderTow (id:int) : int;       { tower's id or 0 }
  var   i       : int;
        h1      : sptr;
  begin
    _UnderTow:=0;
    for i:=1 to 999 do
    begin
      h1:=TempShips[i];
      if (h1<>nil) and (h1^.when=turn) and
         (h1^.mission=7) and (h1^.tow_ship=id) then
        begin _UnderTow:=i; Exit end;
    end;
  end;
{taken from vpadata.pas}
function _StdTowPtr(h: SRec): sptr;
var
        i       : int;
        h1      : sptr;
begin
    h1 := nil;
    if (h.mission=7) then
    begin
      i:=IIF(h.mission=7,h.tow_ship,0);
      if (i>0)and(GoodShips^[i]=True) then h1 :=TempShips[i];
    end;
    _StdTowPtr := h1;
end;



begin
  CheckMem(sizeof(GoodShips^)); GetMem(GoodShips, sizeof(GoodShips^));
  CheckMem(sizeof(TowedBy^)); GetMem(TowedBy, sizeof(TowedBy^));
  
  TempShips:=TempShipsPtr^;
   {Find all ships with full information }
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
           if (hull<>-1) and (mission<>-1) and (fuel<>-1) and
              (mass<>-1) and (warp<>-1)    and (El<>-1)   and (Wl<>-1) and
              (Tl<>-1)   and (T<>-1)       and (D<>-1)    and (M<>-1) and
              (when = today+1)
              then
             GoodShips^[i]:=True
           else
             GoodShips^[i]:=False;
       end
       else
         GoodShips^[i]:=False;

   { Pretend some host actions }

   {0. AuxHost1 Addons, like Teleport}
  if Addon.Teleport and (lplan<>NIL) then begin
    k:=number;
    mkt:=0;
    Rt:=0;
    jj := GetTeleportDataTX(k,c,mkt);
    if jj>0 then Rt:=-mkt                {TX-Code, Give minerals}
    else if jj=0 then begin
      jj := GetTeleportDataRX(k,c,mkt);
      if jj>0 then Rt:=mkt;              {RX-Code, Get minerals}
    end;
    if Rt<>0 then begin
      case c of
        1:  Inc(lplan^.colonists,Rt);
        2:  Inc(lplan^.N,Rt);
        3:  Inc(lplan^.T,Rt);
        4:  Inc(lplan^.D,Rt);
        5:  Inc(lplan^.M,Rt); 
        6:  Inc(lplan^.supplies,Rt);
        7:  Inc(lplan^.funds,Rt); 
      end;
    end;
  end;
  
   {1. Gambling ships}
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
         begin
            if GoodShips^[i] then
           begin
             if (IsShipFunc(TempShips[i]^,hfGambling)) then
             begin
               inc(credits,colonists); {only colonists in cargo}
             end;
           end;
         end; {with TempShips[i]^ do}
       end;

   {1b. change happy due to hisss }
  if (lplan <> nil) then begin
    HissHChange:=0;
    if HissEffect<>0 then
    begin
      hn:=0;
      with TTurn^.data^ do
      begin
        x:=xyplan[number,1];
        y:=xyplan[number,2];
        for k:=1 to NUM_SHIPS do
        begin
          h:=TempShips[k];
          if (h<>nil) and (GoodShips^[k]) and (Race[h^.owner]=2) and (h^.when=turn) and
           (h^.x=x) and (h^.y=y) and (h^.mission in [9,ExtMissionsStartAt+11]) and
           (h^.weapons>0) and (h^.fuel>0) then inc(hn);
        end;
      end;
      HissHChange:=Min(hn,MaxShipsHissing)*HissEffect;
    end;
  end;     
       
   {2. Try Borg selfrepair mission }
   for i:=1 to NUM_SHIPS do
    if (TempShips[i]<>nil) and (GoodShips^[i]) then
      with TempShips[i]^ do
       if (Race[owner]=6)and( mission in [9,ExtMissionsStartAt+11])AND(fuel>0) then
       begin
         damage:=  damage - Min(damage,10);
         {no move is allowed}
         warp  :=0;
         wx    :=0;
         wy    :=0;
       end;

    {3. Building fighters by ships
    NO 'lfm' actions and mission 32 actions}
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
         with TempShips[i]^ do 
            if (GoodShips^[i]) then begin
             {Robot/Colo need Mission or lfm}
						 if (Addon.Unity) and (Race[owner] = 4) and (bays>0) and (fuel>0) and (Hull=30) then {30=Vaillant}
							HullFound_ := true else HullFound_ := false;
             if ((Race[owner] in [9..11]) and (bays>0) and (fuel>0)) or HullFound_ then begin
								GetShipFighterCost(owner,cost);
								if (fcode = 'lfm') and (lplan <> nil) and 
								(x = TTurn^.data^.xyplan[number,1]) and (y = TTurn^.data^.xyplan[number,2]) then begin
									mkt := 0;
									if (cost.tri<>0) and (cost.Mol<>0) then mkt := Min(lplan^.T div cost.Tri,lplan^.M div cost.Mol);
									if (cost.Supplies<>0) then mkt := Min(mkt,lplan^.supplies div cost.Supplies);
									mkt := Min(mkt, (Hulls[hull].cargo-(TT+TD+TM+TS+TC+T+D+M+Sup+colonists+TFNum)) div (cost.Tri+cost.Mol+cost.Supplies));
									if (mkt>0) then	begin
										dec(lplan^.T  ,mkt*cost.Tri);
										dec(lplan^.M  ,mkt*cost.Mol);
										dec(lplan^.supplies,mkt*cost.Supplies);
										inc(T  ,mkt*cost.Tri);
										inc(M  ,mkt*cost.Mol);
										inc(Sup,mkt*cost.Supplies);
									end;  
								{FIXME lfm actions try to get 325-Minerals from planet}
								end;
							 mkt:=0;
							 if ((mission=9) and (Race[owner] in [9,11])) or (fcode = 'lfm') or HullFound_ then begin
								 {handle ShipFighterCost, uses Standard 3-2-5}
									if (cost.tri<>0) and (cost.Mol<>0) then mkt := Min(T div cost.Tri,M div cost.Mol);
									if (cost.Supplies<>0) then mkt := Min(mkt,Sup div cost.Supplies);
									if (mkt>0) then
									begin
										dec(T  ,mkt*cost.Tri);
										dec(M  ,mkt*cost.Mol);
										dec(Sup,mkt*cost.Supplies);
										inc(TFnum,mkt);
									end;  
								end;
							end;
          end;

       {4. cargo dump and bdm or mission=25}
 if (lplan <> nil) then begin
   for i:=1 to NUM_SHIPS do
   if (TempShips[i]<>nil) and (GoodShips^[i]) then begin
        with TempShips[i]^ do begin
           {Cargo dump}
           if (x = TTurn^.data^.xyplan[number,1]) and
           (y = TTurn^.data^.xyplan[number,2]) then begin
              if ((CN>0) or (CT>0) or (CD>0) or (CM>0) or (CS>0)) then
              if (CPl = number) then begin
                 inc(lplan^.N,CN);
                 inc(lplan^.T,CT);
                 inc(lplan^.D,CD);
                 inc(lplan^.M,CM);
                 inc(lplan^.supplies,CS);
                 CN:=0; {dump cargo}
                 CT:=0;
                 CD:=0;
                 CM:=0;
                 CS:=0;
              end;
              
              if (CC>0) and (CPl = number) then begin
                 if (lplan^.owner=0) then begin 
                    lplan^.owner := owner; 
                    inc(lplan^.colonists,CC);
                 end else begin
                    Rt := trunc((CC*GroundKillFactor[owner]-lplan^.colonists*GroundDefenseFactor[lplan^.owner])
                    /GroundKillFactor[owner]);
                    if (Rt>0) then begin
                      lplan^.colonists:=Rt;
                      lplan^.owner := owner;
                    end else if (Rt=0) then begin
                      lplan^.colonists:=0;
                      lplan^.owner := 0;
                    end else inc(lplan^.colonists,CC); {Since Rt<0 subtract}
                 end;
              CC:=0;
              end;
              {bdm code and mission 25}
							Rt := 0;
              if (fcode = 'bdm') or (mission = ExtMissionsStartAt+5)  then Rt := credits;
              if (mission = ExtMissionsStartAt+5) and (intr_ship>0) then Rt := MinL(credits,intr_ship);
							if (addon.unity) and (fcode='bdh') then Rt := credits div 2;
							if (addon.unity) and (fcode[1]='b') AND (fcode[2]='d') AND
								 (fcode[3] in ['1','2','3','4','5','6','7','8','9' ]) then 
									Rt := min( (ord(fcode[3])-ord('0'))*100, credits); 
              inc(lplan^.funds,Rt);
              dec(credits,Rt);              
           end; {over Planet}
         end;
     end;
  end;

  { 4a. Tranfer Cargo }
  {  k := 0; No Output anymore... }
  Hullfound_ := false; {no Transfer}
  for i:=1 to NUM_SHIPS do begin
    if (TempShips[i]<>nil) then begin
      with TempShips[i]^ do begin
        if GoodShips^[i] and (TempShips[Tsh]<>nil) {and GoodShips^[Tsh]} then 
        if (TN>0) or (TT>0) or (TD>0) or (TM>0) or (TS>0) or (TC>0) then
        if (x=TempShips[TSh]^.x) and (y=TempShips[TSh]^.y)  then begin 
{        inc(k,1);
          OutTextXY(170,24+k*8,'TN: '+NStr0(TN)+' TT: '+NStr0(TT)+' TD: '+NStr0(TD)+
          ' TM: '+NStr0(TM)+' TS: '+NStr0(TS)+' TC: '+NStr0(TC)); }
          if (fuel=0) then begin
{            OutTextXY(5,24+k*8,'No Fuel, transit fails'); }
            TN:=0;TT:=0;TD:=0;TM:=0;TS:=0;TC:=0;
          end else if ShipIsCloaking(TempShips[TSh]^.owner,TempShips[TSh]^.mission) then begin
            if not VPAExtra then begin {VPAExtra off -> no transfer to cloaked}
{              OutTextXY(5,24+k*8,'No Transfer Dest Cloaked'); }
              inc(fuel,TN); inc(T,TT); inc(D,TD); inc(M,TM); inc(sup,TS); inc(colonists,TC); 
              {Ship Cloaked, transit back to cargo}
            end else HullFound_ := true; {make transfer}
          end else if (TT+TD+TM+TS+TC+T+D+M+Sup+colonists+TFNum>Hulls[hull].cargo) then begin
            if not VPAExtra then begin {VPA Extra off -> with overload will be returned}
{              inc(k,1);
              OutTextXY(5,24+k*8,'Check VPA Feature, transit dropped'); }
              TN:=0;TT:=0;TD:=0;TM:=0;TS:=0;TC:=0;
            end else HullFound_ := true;
          end else HullFound_ := true; {Transfer}
          if HullFound_ then begin
{            inc(k,1);
            OutTextXY(5,24+k*8,'Transfer '+NStr(i)+' to '+NStr(Tsh));
            OutTextXY(170,24+k*8,'TN:     TT:     TD:     TM:     TS:     TC:    '); }
            Rt:=min(TN,Hulls[TempShips[Tsh]^.hull].fuel-TempShips[Tsh]^.fuel);
            inc(TempShips[Tsh]^.fuel,Rt);dec(TN,Rt);inc(fuel,TN);TN:=0;
{            OutTextXY(170+4*8,24+k*8,NStr0(Rt));}
            Rt:=min(TT,Hulls[TempShips[Tsh]^.hull].cargo-TempShips[Tsh]^.t-TempShips[Tsh]^.d-TempShips[Tsh]^.m-
            TempShips[Tsh]^.sup-TempShips[Tsh]^.colonists-TempShips[Tsh]^.TFNum);
            inc(TempShips[Tsh]^.t,Rt);dec(TT,Rt);inc(t,TT);TT:=0;
{            OutTextXY(170+12*8,24+k*8,NStr0(Rt)); }
            Rt:=min(TD,Hulls[TempShips[Tsh]^.hull].cargo-TempShips[Tsh]^.t-TempShips[Tsh]^.d-TempShips[Tsh]^.m-
            TempShips[Tsh]^.sup-TempShips[Tsh]^.colonists-TempShips[Tsh]^.TFNum);
            inc(TempShips[Tsh]^.d,Rt);dec(TD,Rt);inc(d,TD);TD:=0;
{            OutTextXY(170+20*8,24+k*8,NStr0(Rt)); }
            Rt:=min(TM,Hulls[TempShips[Tsh]^.hull].cargo-TempShips[Tsh]^.t-TempShips[Tsh]^.d-TempShips[Tsh]^.m-
            TempShips[Tsh]^.sup-TempShips[Tsh]^.colonists-TempShips[Tsh]^.TFNum);
            inc(TempShips[Tsh]^.m,Rt);dec(TM,Rt);inc(m,TM);TM:=0;
{            OutTextXY(170+28*8,24+k*8,NStr0(Rt)); }
            Rt:=min(TS,Hulls[TempShips[Tsh]^.hull].cargo-TempShips[Tsh]^.t-TempShips[Tsh]^.d-TempShips[Tsh]^.m-
            TempShips[Tsh]^.sup-TempShips[Tsh]^.colonists-TempShips[Tsh]^.TFNum);
            inc(TempShips[Tsh]^.sup,Rt);dec(TS,Rt);inc(sup,TS);TS:=0;
{            OutTextXY(170+36*8,24+k*8,NStr0(Rt)); }
            Rt:=min(TC,Hulls[TempShips[Tsh]^.hull].cargo-TempShips[Tsh]^.t-TempShips[Tsh]^.d-TempShips[Tsh]^.m-
            TempShips[Tsh]^.sup-TempShips[Tsh]^.colonists-TempShips[Tsh]^.TFNum);
            inc(TempShips[Tsh]^.colonists,Rt);dec(TC,Rt);inc(colonists,TC);TC:=0;
{            OutTextXY(170+44*8,24+k*8,NStr0(Rt)); }
            
          end;
        end;
      end;  
    end;
  end;

  {4b. Transfercodes + Give Ship + 'bum'}

  { 4d. Gather Mission }
  if (lplan <> nil) then begin
    for i:=1 to NUM_SHIPS do
    if (TempShips[i]<>nil) then begin
      if GoodShips^[i] then begin
        with TempShips[i]^ do begin
           if (x = TTurn^.data^.xyplan[number,1]) and    
              (y = TTurn^.data^.xyplan[number,2]) then  {on that Planet}
           if (owner=lplan^.owner) or (fcode=lplan^.fcode) or (lplan^.owner=0) then begin

                case mission of 
{fuel}          11: begin
                      Rd := min(Hulls[hull].fuel-fuel,lplan^.N); { fill cargo with}
                      inc(fuel, Rd); {up to max}
                      dec(lplan^.N,Rd);
                    end; 
{dura}          12: begin
                      Rd := min(Hulls[hull].cargo-T-D-M-Sup-colonists-TFnum,lplan^.D); { fill cargo with}
                      inc(D,Rd); {up to max}
                      dec(lplan^.D,Rd);
                    end; 
{trit}          13: begin
                      Rd := min(Hulls[hull].cargo-T-D-M-Sup-colonists-TFnum,lplan^.T); { fill cargo with}
                      inc(T,Rd); {up to max}
                      dec(lplan^.T,Rd);
                    end; 
{moly}          14: begin
                      Rd := min(Hulls[hull].cargo-T-D-M-Sup-colonists-TFnum,lplan^.M); { fill cargo with}
                      inc(M, Rd); {up to max}
                      dec(lplan^.M,Rd);
                    end;
{Sups}          15: begin
                      Rd := min(Hulls[hull].cargo-T-D-M-Sup-colonists-TFnum,lplan^.Supplies); { fill cargo with}
                      inc(Sup, Rd); {up to max}
                      dec(lplan^.Supplies,Rd);
                    end; 
              end; {Case}  
           end; 
        end;
     end;{with TempShips[i]^ do}
    end;
  end;      

   {5. Alchemy & Rafinery}
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
         begin
            if GoodShips^[i] then begin
               {Alchemy}
              if (IsShipFunc(TempShips[i]^,hfAlchemy)) and (fcode<>'NAL') then
              begin
                alch      := Sup div 3;
                alch_rest := Sup mod 3;
                Sup       := alch_rest;
                if (fcode='alt') then T:=T+alch
                else
                if (fcode='ald') then D:=D+alch
                else
                if (fcode='alm') then M:=M+alch
                else                                 
               
               if (Addon.Unity) then begin                {Advanced Alchemy for Unity Addon Quapla}
                  if (fcode='ABT')  then begin D:=D+alch div 2 + alch mod 2;M:=M+alch div 2; end
                  else
                  if (fcode='ABD')  then begin T:=T+alch div 2 + alch mod 2;M:=M+alch div 2; end
                  else
                  if (fcode='ABM')  then begin T:=T+alch div 2 + alch mod 2;D:=D+alch div 2; end
               end else
                
               if (PHOST) then begin                    {Advanced Alchemy for PHOST Quapla}
                  if (fcode='nat') then begin D:=D+alch div 2 + alch mod 2;M:=M+alch div 2; end
                  else
                  if (fcode='nad') then begin T:=T+alch div 2 + alch mod 2;M:=M+alch div 2; end
                  else
                  if (fcode='nam') then begin T:=T+alch div 2 + alch mod 2;D:=D+alch div 2; end
               end else
               
               begin
                 T:=T + alch div 3 + IIF((alch mod 3 > 0),1,0);
                 D:=D + alch div 3 + IIF((alch mod 3 > 1),1,0);
                 M:=M + alch div 3;
               end;
             end; {Alchemy}
             {Rafinery}
             if (IsShipFunc(TempShips[i]^,hfRefinery)) and (fcode<>'NAL') then
             begin
               alch := Min(Sup,Min(M+D+T,Hulls[hull].fuel-fuel));
               Sup       := Sup  - alch;
               fuel      := fuel + alch;
               if (alch>T) then begin dec(alch,T);  T:=0; end
                           else begin T:=T-alch; alch:=0; end;
               if (alch>D) then begin dec(alch,D);  D:=0; end
                           else begin D:=D-alch; alch:=0; end;
               if (alch>M) then begin dec(alch,M);  M:=0; end
                           else begin M:=M-alch; alch:=0; end;
             end; {Rafinery}
             {AdvancedRafinery - THost Phost diff accorging to Donovan's info}
             if (IsShipFunc(TempShips[i]^,hfAdvRefinery)) and ((fcode<>'NAL')or (not Phost)) then
             begin
               alch := Min(M+D+T,Hulls[hull].fuel-fuel);
               fuel := fuel + alch;
               if (alch>T) then begin dec(alch,T);  T:=0; end
                           else begin T:=T-alch; alch:=0; end;
               if (alch>D) then begin dec(alch,D);  D:=0; end
                           else begin D:=D-alch; alch:=0; end;
               if (alch>M) then begin dec(alch,M);  M:=0; end
                           else begin M:=M-alch; alch:=0; end;
             end; {AdvancedRafinery}
           end;
         end; {with TempShips[i]^ do}
       end;

   {6. minefield laying}
   for i:=1 to NUM_SHIPS do
    if GoodShips^[i] then
      with TempShips[i]^ do
        if ((mission in [3,ExtMissionsStartAt+1,ExtMissionsStartAt+16])OR
           ((Race[owner]=7)and(mission in [9,ExtMissionsStartAt+2,ExtMissionsStartAt+11,ExtMissionsStartAt+17])))AND
           (launchers>0)and(fuel>0)and(TFnum>0) then
        begin
          k :=0;
          if (mission in [3,9,ExtMissionsStartAt+11]) then
          begin
            k :=TFnum;
            if (fcode='mdq') then k := TFnum div 4;
            if (fcode='mdh') then k := TFnum div 2;
            if (fcode[1]='m')AND(fcode[2]='d')AND
               (fcode[3] in ['1','2','3','4','5','6','7','8','9' ]) then
               k:=min( (ord(fcode[3])-ord('0'))*10, TFnum);
            if (fcode='md0') then k := min(100,TFnum);   
          end;
          if (mission in [ExtMissionsStartAt+1,ExtMissionsStartAt+2,ExtMissionsStartAt+16,ExtMissionsStartAt+17]) then
          begin
            if (intr_ship=0) then k := TFnum
            else                  k := min(intr_ship,TFnum);
          end;
          dec(TFnum,k);
        end;   

  {7a. base fix or recycle}
   if (lplan <> nil)and(lbase <> nil) then begin
    if (lbase^.fOp<>0) then {base is fixing or recycling}
    begin
      if (TempShips[lbase^.fShip]<>nil)and(GoodShips^[lbase^.fShip]) then
      if (TempShips[lbase^.fShip]^.x =TTurn^.data^.xyplan[number,1]) and
         (TempShips[lbase^.fShip]^.y =TTurn^.data^.xyplan[number,2]) then
      {ship exist and is orbiting planet}
      begin
        if (lbase^.fOp=1) then TempShips[lbase^.fShip]^.damage:=0; {fix}
        if (lbase^.fOp=2) then {recycle}
          begin
            {dump cargo }
            inc(lplan^.T, TempShips[lbase^.fShip]^.T);
            inc(lplan^.D, TempShips[lbase^.fShip]^.D);
            inc(lplan^.M, TempShips[lbase^.fShip]^.M);
            inc(lplan^.supplies ,TempShips[lbase^.fShip]^.Sup);
            inc(lplan^.funds    ,TempShips[lbase^.fShip]^.credits);
            inc(lplan^.colonists,TempShips[lbase^.fShip]^.colonists);
            {move equipment}
            if (TempShips[lbase^.fShip]^.weapons>0) then
               inc(lbase^.WW[TempShips[lbase^.fShip]^.Wl],TempShips[lbase^.fShip]^.weapons);
            if (TempShips[lbase^.fShip]^.launchers>0) then
               inc(lbase^.LL[TempShips[lbase^.fShip]^.Tl],TempShips[lbase^.fShip]^.launchers);
            inc(lbase^.EE[TempShips[lbase^.fShip]^.El],Hulls[TempShips[lbase^.fShip]^.hull].engines);
            {recycle hull minerals}
            inc(lplan^.T, (long(Hulls[TempShips[lbase^.fShip]^.hull].T)*RecycleRate)div 100);
            inc(lplan^.D, (long(Hulls[TempShips[lbase^.fShip]^.hull].D)*RecycleRate)div 100);
            inc(lplan^.M, (long(Hulls[TempShips[lbase^.fShip]^.hull].M)*RecycleRate)div 100);

            {delete ship}
            GoodShips^[lbase^.fShip]:= False;
            {if (TempShips[lbase^.fShip]<>nil) then Dispose(TempShips[lbase^.fShip]);}
          end;
      end;
    end;
end;
        

   {7. ship cloning}
   if (lplan <> nil)and(lbase <> nil) then begin
    for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
           if GoodShips^[i] then
             if (x = TTurn^.data^.xyplan[number,1])  and
                (y = TTurn^.data^.xyplan[number,2])  and
                not OwnShipDesign(lplan^.owner,hull) and
                (fcode='cln')
                then
           begin
             {check if cloning is possible}
             Rt:=0;
             Rd:=0;
             Rm:=0;
             Rcash:=0;
            if (TempShips[i]^.weapons>0) then
            begin
               inc(Rt,TempShips[i]^.weapons*Beams[TempShips[i]^.Wl].T);
               inc(Rd,TempShips[i]^.weapons*Beams[TempShips[i]^.Wl].D);
               inc(Rm,TempShips[i]^.weapons*Beams[TempShips[i]^.Wl].M);
               inc(Rcash,TempShips[i]^.weapons*Beams[TempShips[i]^.Wl].cost);
            end;
            if (TempShips[i]^.launchers>0) then
            begin
               inc(Rt,TempShips[i]^.launchers*Torps[TempShips[i]^.Tl].T);
               inc(Rd,TempShips[i]^.launchers*Torps[TempShips[i]^.Tl].D);
               inc(Rm,TempShips[i]^.launchers*Torps[TempShips[i]^.Tl].M);
               inc(Rcash,TempShips[i]^.launchers*Torps[TempShips[i]^.Tl].cost);
            end;
            {engines minerals}
            inc(Rt,Hulls[TempShips[i]^.hull].engines*Engines[TempShips[i]^.El].T);
            inc(Rd,Hulls[TempShips[i]^.hull].engines*Engines[TempShips[i]^.El].D);
            inc(Rm,Hulls[TempShips[i]^.hull].engines*Engines[TempShips[i]^.El].M);
            inc(Rcash,Hulls[TempShips[i]^.hull].engines*Engines[TempShips[i]^.El].cost);
            {hull minerals}
            inc(Rt,Hulls[TempShips[i]^.hull].T);
            inc(Rd,Hulls[TempShips[i]^.hull].D);
            inc(Rm,Hulls[TempShips[i]^.hull].M);
      inc(Rcash,Hulls[TempShips[i]^.hull].cost);
      CloneCost_ := CloneCost[lplan^.owner]/100.0;
      
            Rcash := round(CloneCost_*Rcash);
           {check tech levels}
           if (Hulls[TempShips[i]^.hull].tech<=lbase^.Hl)and
              (Engines[TempShips[i]^.El].tech<=lbase^.El) then
            if   (Torps[TempShips[i]^.Tl].tech<=lbase^.Tl)or
                 (TempShips[i]^.launchers=0) then
            if   (Beams[TempShips[i]^.Wl].tech<=lbase^.Wl)or
                 (TempShips[i]^.weapons=0) then begin
           with lplan^ do begin  
             if (T>=Rt)and(D>=Rd)and(M>=Rm)and(funds>=Rcash) then begin 
               {cloning}  
               dec(T       ,Rt);
               dec(D       ,Rd);
               dec(M       ,Rm);
               dec(funds   ,Rcash);
               {only 1 ship can clone, the lowest id wins}
               break;
              end; {if minerals}
           end; {lplan^}
           end; {if tech}
          end; {'cln'}
       end;
  end;

  {7aaa. Super Refit}
   if (lplan <> nil)and(lbase <> nil) then begin
      for i:=1 to NUM_SHIPS do
      if (TempShips[i]<>nil) then begin
         with TempShips[i]^ do
         if GoodShips^[i] then
         if (x = TTurn^.data^.xyplan[number,1])  and
            (y = TTurn^.data^.xyplan[number,2])  and
            (Race[RealShipOwner(i)]=1) and (fuel>0) and
            (mission=9) then begin {Refit Conditions true}
              if (weapons>0) then begin
                 inc(lbase^.WW[Wl],weapons);
                 weapons:=0; end;
              if (launchers>0) then begin
                 inc(lbase^.LL[Tl],launchers);   
                 launchers:=0; end;
              inc(lbase^.EE[El],Hulls[Hull].engines);
              for k:=9 downto 1 do 
              if (lbase^.EE[k] >= Hulls[Hull].engines) then begin
                  dec(lbase^.EE[k],Hulls[Hull].engines);
                  if El<>k then begin el:=k; name[20]:='!'; end;
                  break;
              end;
              for k:=10 downto 1 do 
              if (lbase^.WW[k] >= Hulls[Hull].weapons) then begin
                 dec(lbase^.WW[k],Hulls[Hull].weapons);
                 if (Wl<>k) then begin Wl:=k; name[20]:='!'; end;
                 if (weapons<>Hulls[Hull].weapons) then begin weapons:=Hulls[Hull].weapons; name[20]:='!'; end;
                 break;
              end;
              for k:=10 downto 1 do 
              if (lbase^.LL[k] >= Hulls[Hull].launchers) then begin
                 dec(lbase^.LL[k],Hulls[Hull].launchers);
                 if (Tl<>k) then begin Tl:=k; name[20]:='!'; end;
                 if (launchers<>Hulls[Hull].launchers) then begin launchers:=Hulls[Hull].launchers; name[20]:='!'; end;
                 inc(TFnum,min(lbase^.TT[k],(Hulls[Hull].cargo-T-D-M-Sup-TFnum-colonists)));
                 break;
              end;
         end; {Conditions}
      end;
   end;
   
 {7aa. recalculate mass}
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
            if GoodShips^[i] then  SetShipMass(TempShips[i]^);
       end;
 
   {7aa. repair using supp}
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
            if (GoodShips^[i])and(damage<>0) then
            begin
              targetfighters := damage;
              targetfighters := Min(targetfighters,Sup div 5);
              damage := damage - targetfighters;
              Sup := Sup - targetfighters *5;
            end;
       end;

  { 7aa. torpedo building using 'mkt' code + Ext. Mis. =20
  NO mission 24 actions  }
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
         begin
            if GoodShips^[i] then
           begin
             if ((fcode='mkt')or(mission=ExtMissionsStartAt) )and(launchers>0)AND(fuel>0) then
             begin
                mkt := Min(T,D);
                mkt := Min(mkt,M);
                mkt := Min(mkt,credits div Torps[Tl].cost);
                if (mkt>0) then
                begin
                  dec(T,mkt);
                  dec(D,mkt);
                  dec(M,mkt);
                  dec(credits, mkt * Torps[Tl].cost);
                  inc(TFnum,mkt);
                end;
             end;
           end;
         end; {with TempShips[i]^ do}
       end;

 
    {7a. ship movement}
   for i:=1 to NUM_SHIPS do TowedBy^[i]:=0;
   
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
           if (GoodShips^[i])and(mission=7) then {7 = Tow mission}
             if (GoodShips^[tow_ship])and(warp>0) then
             begin
            if (x=TempShips[tow_ship]^.x)and
               (y=TempShips[tow_ship]^.y) then
               begin
                 TempShips[tow_ship]^.warp:=0; {no tow resolution}
                 TempShips[tow_ship]^.wx:=0;
                 TempShips[tow_ship]^.wy:=0;
                 if (TowedBy^[tow_ship]=0) then {The lowest Id wins}
                     TowedBy^[tow_ship]:=i;
               end;
             end
             else
             {forget about this ship, we know nothing about it
              or our speed=0}
             begin
             {clear tow mission}
             mission:=1;
             tow_ship:=0;
             end;
       end;
   
   {7a. normal, HYP}
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
            if GoodShips^[i] then
              CalcMove(TempShips[i]^,_StdTowPtr(TempShips[i]^),Yes);       {Quapla BUG}
       end;

   {7a. TOW using TowedBy}
   for i:=1 to NUM_SHIPS do {No need to check}
   if (TowedBy^[i]<>0) then
   begin
     TempShips[i]^.x :=  TempShips[TowedBy^[i]]^.x;
     TempShips[i]^.y :=  TempShips[TowedBy^[i]]^.y;
   end;

   {7a. Chunnel}
   if Chunnel and chuns then
   begin
     for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
            if (GoodShips^[i]) then
             if (IsShipFunc(TempShips[i]^,hfChunneling)) then
             {we got all information about this ship}
             begin
               if (warp=0) and (fuel>=50) and
                  (damage<DamageLevelForChunnelFail) and
               (IsShipFunc(TempShips[i]^,hfChunneling)) and (_UnderTow(i)=0) then
                {ship can chunnel (More PHOST params must be added) }
               begin
                 xx:=x;
                 yy:=y;
                 Val(fcode,fc,fa);
                 if (fa=0) and (fc>0) and (fc<=NUM_SHIPS) then
                 {we search for ship with this FC}
                 begin
                   fh1:=TempShips[fc];
                   if (GoodShips^[fc]) then
                   with fh1^ do
                   if (fh1<>nil) and (when=turn) and (warp=0) and
                      ((owner=TempShips[i]^.owner)or ((Phost)and(AllowAlliedChunneling)) )and
                      (damage<DamageLevelForChunnelFail) and
                      (IsShipFunc(fh1^,hfChunneling)) and (_UnderTow(fc)=0) and
                      (Distance2Wrap(xx,yy,x,y)>=MinimumChunnelDistance*MinimumChunnelDistance)
                      then
                     begin {Ship 'i' will be moved here x,y }
                       {move chunnel ship}
                       TempShips[i]^.x := x;
                       TempShips[i]^.y := y;
                       {Try all ships at position xx,yy }
                       for k:=1 to NUM_SHIPS do
                       if (TempShips[k]<>nil) then
                         begin
                           with TempShips[k]^ do
                              if (GoodShips^[k]) then
                               if (x=xx)and(y=yy)and(
                               (warp=0) or (mission in [10,ExtMissionsStartAt+10]) or
                               ((Race[owner]=3) and (mission in [9,ExtMissionsStartAt+9])) or
                                 (fuel=0) or (owner=TempShips[k]^.owner)or(TempShips[k]^.fcode=fcode)
                               )  then
                               {move this ship too}
                               begin
                                 TempShips[k]^.x := TempShips[i]^.x;
                                 TempShips[k]^.y := TempShips[i]^.y;
                               end;
                         end;
                     end;
                 end;
               end; {can chunnel}
             end;
       end;
   end;

   {8. base Max Defence mission}
  if (lplan <> nil)and(lbase <> nil) then begin
    if (lbase^.order=2) then {base got Max Defence mission}
    with lplan^ do
    begin
      mkt := Min(D,funds div 10);
      mkt := Min(GetMaxDefenseOnBase(lbase^.owner)-lbase^.defense,mkt);
      if (mkt>0) then
      begin
        dec(D,mkt);
        dec(funds, mkt *10);
      end;
    end;
  end;

   {8. ship unload}
   if (lplan <> nil) then begin
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
           if GoodShips^[i] then
             if (TempShips[i]^.x = TTurn^.data^.xyplan[number,1]) and
                (TempShips[i]^.y = TTurn^.data^.xyplan[number,2]) and
               ( (lplan^.owner = TempShips[i]^.owner) or
                 ((lbase<>nil)and (lbase^.order = 4)) ) {Unload freighters}
                then
           begin
             with lplan^ do
             begin
             {unload ships ?? }
             inc(N       ,TempShips[i]^.fuel);
             inc(T       ,TempShips[i]^.T);
             inc(D       ,TempShips[i]^.D);
             inc(M       ,TempShips[i]^.M);
             inc(funds   ,TempShips[i]^.credits);
             inc(supplies,TempShips[i]^.Sup);
             end;
           end;
       end;
    end;
 
  
   {8a. Free Fighters for starbases - MSGREAD Fixed Quapla}
   if (lplan <> nil)and(lbase <> nil) then begin
   with lplan^ do
   begin
   if (FreeFighters[owner]<>0) then
   begin
     if (lbase^.fighters < GetMaxFightersOnBase(owner)) then
     begin
       GetFreeFighterCost(owner,cost);
       targetfighters := Min(GetMaxFightersOnBase(owner) - lbase^.fighters,FreeFighters[owner]);
       if cost.Tri>0 then targetfighters := Min(targetfighters, T div cost.Tri);
       if cost.Dur>0 then targetfighters := Min(targetfighters, D div cost.Dur);
       if cost.Mol>0 then targetfighters := Min(targetfighters, M div cost.Mol);
       if cost.Supplies>0 then targetfighters := Min(targetfighters, supplies div cost.Supplies);
       if cost.MC>0  then targetfighters := Min(targetfighters, (supplies+funds) div (cost.MC+cost.Supplies));
       inc(lbase^.fighters, targetfighters);
       dec(T, cost.Tri*targetfighters);
       dec(D, cost.Dur*targetfighters);
       dec(M, cost.Mol*targetfighters);
       dec(supplies, cost.Supplies*targetfighters);
       dec(funds, cost.MC*targetfighters);
       if funds<0 then Inc(supplies, funds);
     end
   end;
   end;
end;
  
   {9. base 'dmp' FC}
   if (lplan <> nil)and(lbase <> nil) then begin
   if (lplan^.fcode = 'dmp') then
   begin
     Rt:=0;
     Rd:=0;
     Rm:=0;
     {recycle hulls}
     with lbase^ do
     begin
       for i:=1 to 20 do
       begin
         if (HH[i]-IIF(cHl=i,1,0)>0) then
         begin
           fc := HH[i]-IIF(cHl=i,1,0);
           inc(Rt,fc * Hulls[RaceHull[owner,i]].T);
           inc(Rd,fc * Hulls[RaceHull[owner,i]].D);
           inc(Rm,fc * Hulls[RaceHull[owner,i]].M);
           dec(HH[i],fc);
         end;
       end; {recycle hulls}
       {recycle engines}
       for i:=1 to 9 do
       begin
         fc := EE[i];
         if (cEl=i) then dec(fc,Hulls[RaceHull[owner,cHl]].engines);
         inc(Rt,fc * Engines[i].T);
         inc(Rd,fc * Engines[i].D);
         inc(Rm,fc * Engines[i].M);
         dec(EE[i],fc);
       end; {recycle engines}
       {recycle beams}
       for i:=1 to 10 do
       begin
         fc := WW[i];
         if (cWl=i) then dec(fc,cWn);
         inc(Rt,fc * Beams[i].T);
         inc(Rd,fc * Beams[i].D);
         inc(Rm,fc * Beams[i].M);
         dec(WW[i],fc);
       end; {recycle engines}
       {recycle lunchers}
       for i:=1 to 10 do
       begin
         fc := LL[i];
         if (cTl=i) then dec(fc,cTn);
         inc(Rt,fc * Torps[i].T);
         inc(Rd,fc * Torps[i].D);
         inc(Rm,fc * Torps[i].M);
         dec(LL[i],fc);
       end; {recycle lunchers}
     end; { with ^lbase do }
     inc(lplan^.T, (Rt*RecycleRate)div 100);
     inc(lplan^.D, (Rd*RecycleRate)div 100);
     inc(lplan^.M, (Rm*RecycleRate)div 100);
   end;
end;
         
  {11. recalculate mass}
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
            if GoodShips^[i] then  SetShipMass(TempShips[i]^);
       end;
 
       {11. repair using supp}
   {FIXME: Trim Masses}
   for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
            if (GoodShips^[i])and(damage<>0) then
            begin
              targetfighters := damage;
              targetfighters := Min(targetfighters,Sup div 5);
              damage := damage - targetfighters;
              Sup := Sup - targetfighters *5;
            end;
       end;

  { 11. torpedo building using 'mkt' code + Ext. Mis. =20
  NO mission 24 actions  }
  for i:=1 to NUM_SHIPS do
     if (TempShips[i]<>nil) then
       begin
         with TempShips[i]^ do
         begin
            if GoodShips^[i] then
           begin
             if ((fcode='mkt')or(mission=ExtMissionsStartAt) )and(launchers>0)AND(fuel>0) then
             begin
                mkt := Min(T,D);
                mkt := Min(mkt,M);
                mkt := Min(mkt,credits div Torps[Tl].cost);
                if (mkt>0) then
                begin
                  dec(T,mkt);
                  dec(D,mkt);
                  dec(M,mkt);
                  dec(credits, mkt * Torps[Tl].cost);
                  inc(TFnum,mkt);
                end;
             end;
           end;
         end; {with TempShips[i]^ do}
       end;

   {12. colonize mission+Terraforming}
  if (lplan <> nil) then begin
    for i:=1 to NUM_SHIPS do
      if (TempShips[i]<>nil)and(GoodShips^[i]) then
      if (TempShips[i]^.x =TTurn^.data^.xyplan[number,1]) and 
        (TempShips[i]^.y =TTurn^.data^.xyplan[number,2]) then begin {Ship Over Panet}
        if (TempShips[i]^.mission=6) then {colonize mission ship will colonize on planet}
        begin
             with lplan^ do
             begin
            {dump cargo ? }
            inc(lplan^.T, TempShips[i]^.T);
            inc(lplan^.D, TempShips[i]^.D);
            inc(lplan^.M, TempShips[i]^.M);
            inc(lplan^.supplies ,TempShips[i]^.Sup);
            inc(lplan^.funds, TempShips[i]^.credits);
            inc(lplan^.colonists,TempShips[i]^.colonists);
            {recycle ship}
             Rt:=0;
             Rd:=0;
             Rm:=0;
            if (TempShips[i]^.weapons>0) then
            begin
               inc(Rt,TempShips[i]^.weapons*Beams[TempShips[i]^.Wl].T);
               inc(Rd,TempShips[i]^.weapons*Beams[TempShips[i]^.Wl].D);
               inc(Rm,TempShips[i]^.weapons*Beams[TempShips[i]^.Wl].M);
            end;
            if (TempShips[i]^.launchers>0) then
            begin
               inc(Rt,TempShips[i]^.launchers*Torps[TempShips[i]^.Tl].T);
               inc(Rd,TempShips[i]^.launchers*Torps[TempShips[i]^.Tl].D);
               inc(Rm,TempShips[i]^.launchers*Torps[TempShips[i]^.Tl].M);
            end;
            {recycle engines minerals}
            inc(Rt,Hulls[TempShips[i]^.hull].engines*Engines[TempShips[i]^.El].T);
            inc(Rd,Hulls[TempShips[i]^.hull].engines*Engines[TempShips[i]^.El].D);
            inc(Rm,Hulls[TempShips[i]^.hull].engines*Engines[TempShips[i]^.El].M);
            {recycle hull minerals}
            inc(Rt,Hulls[TempShips[i]^.hull].T);
            inc(Rd,Hulls[TempShips[i]^.hull].D);
            inc(Rm,Hulls[TempShips[i]^.hull].M);

            inc(lplan^.T, (Rt*RecycleRate)div 100);
            inc(lplan^.D, (Rd*RecycleRate)div 100);
            inc(lplan^.M, (Rm*RecycleRate)div 100);
            end;
        if (IsShipFunc(TempShips[i]^,hfGloryDeviceH) or IsShipFunc(TempShips[i]^,hfGloryDeviceL)
        and (TempShips[i]^.fcode='pop')) and not GloryDevice then begin
          {Glory Device}
          with lplan^ do begin
            if not (owner=TempShips[i]^.owner) then begin {Glory Device over foreign Planet -> Damage}
              mines := TRound(Mines*0.75);
              factories := TRound(Factories*0.75);
              if not ((owner = 2) or (owner = 7)) then colonists := TRound(colonists*0.6);
              { Not for LIZ and CRYS}
              if not ((Nrace = 2) or (NRace = 3) or (NRace = 9)) then natives := TRound(Natives*0.6);
              { Not Sili, Reptile, Bovis}
            end;
            if NRace = 5 then begin
              supplies := supplies + natives;
              natives := 0;
              NRace := 0;
            end;
          end;
        end;  
            
          
        {12a. Teraforming}  
        if (TempShips[i]^.fuel > 0) then begin 
          if IsShipFunc(TempShips[i]^,hfHeat100) then 
          if lplan^.climate < 99 then inc(lplan^.climate,1);
          if IsShipFunc(TempShips[i]^,hfHeat50) then
          if lplan^.climate < 49 then inc(lplan^.climate,1);
          if IsShipFunc(TempShips[i]^,hfCool50) then
          if lplan^.climate > 51 then dec(lplan^.climate,1);
        end;
      end;
   end;
  end;
   
  { planetary production}   
  {13. structure decay} 
  if (lplan <> nil) then ReCalcDecay (lplan, lplan);
  with lplan^ do begin 
      
    {13a. Pillage}
    if (lplan <> nil) then begin
      k:=0;     {No Pillage}
      for i:=1 to NUM_SHIPS do
      if (TempShips[i]<>nil) and (GoodShips^[i]) then
      if (TempShips[i]^.x =TTurn^.data^.xyplan[number,1]) and 
      (TempShips[i]^.y =TTurn^.data^.xyplan[number,2]) then       { Over Planet?}
      if (TempShips[i]^.mission in [9, ExtMissionsStartAt+11]) and (TempShips[i]^.weapons>0) 
      and (TempShips[i]^.fuel>0) then begin
        if (Race[RealShipOwner(i)]=4) and (colonists>0) then begin {Klingon Pillage Ship Over populated planet}
          funds := funds+trunc ((natives+colonists)/100);             {Inc Planet funds+sup}
          supplies := supplies+trunc ((natives+colonists)/100);

          { Done later in Population Growth }
          natives := natives - trunc ((natives*0.2)+121);
          colonists := colonists - trunc ((colonists*0.2)+20);

          if natives < 0 then begin
            natives := 0;
            NRace := 0;
          end;
          if colonists < 0 then colonists := 0;

          Cstat := cstat-10;
          Nstat := Nstat-10;
          k:=1;                 {Pillage done}
          break;                {only first ship pillages}
        end;
      end;
      if (k=1) then begin
        k:=funds; jj:=supplies;  {Move $ and S on Ships}
        
        {Lowest ID Klingon-Ship gets first}
        for i:=1 to NUM_SHIPS do
        if (TempShips[i]<>nil) and (GoodShips^[i]) then
        if (TempShips[i]^.x =TTurn^.data^.xyplan[number,1]) and 
        (TempShips[i]^.y =TTurn^.data^.xyplan[number,2])  {over Planet?}
        and (Race[RealShipOwner(i)]=4) then begin
           if jj>0 then begin 
            with TempShips[i]^ do 
              RSup := min( Hulls[hull].cargo-T-D-M-Sup-colonists-TFnum,jj); { fill cargo with Sups}
            TempShips[i]^.sup := RSup; {up to max}
            jj := jj-RSup; { remaining sups}
            k := k+jj;
            funds := funds+jj; supplies := supplies-jj;
            jj := 0;  {Sell rest of supplies}                  
           end;
           if k>0 then begin
            RCash := min(10000,TempShips[i]^.credits+k);
            k := k+TempShips[i]^.credits-RCash;
            TempShips[i]^.credits := RCash; {to be optimized up to 10000MC}
            {writeln('P-ID: ',i,' $: ',TempShips[i]^.credits,' S: ',TempShips[i]^.sup);                  }
           end;
        end; 
      end;
      {13b.  RGA only Happy Change }
      for i:=1 to NUM_SHIPS do
      if (TempShips[i]<>nil) and (GoodShips^[i]) then
      if (TempShips[i]^.x =TTurn^.data^.xyplan[number,1]) and 
      (TempShips[i]^.y =TTurn^.data^.xyplan[number,2]) then       { Over Planet?}
      if (TempShips[i]^.mission in [9, ExtMissionsStartAt+11]) and (TempShips[i]^.weapons>0) 
      and (TempShips[i]^.fuel>0) then 
      if (Race[RealShipOwner(i)]=10) then begin {Rebel RGA Ship Over Planet}
        funds := trunc (0.7 * funds);
        supplies := trunc (0.6 * supplies);
        { colonists := trunc (0.8 * colonists); Done later in Population Growth }
        mines := trunc (0.4 * mines);
        factories := trunc (0.7 * factories);
        defense := trunc (0.8 * defense);
        Cstat := Cstat - 60;
        Nstat := MIN (Nstat+30 ,100);
        break;
      end;
    end;
  
{14. happiness} {15. produce supplies} {16. produce taxes} 
{17. population growth+Overpop+Amorph+Riots+Civil war}
    if (lplan <> nil) then ReCalcPlanet(lplan,lplan);
    
{18. Produce Mines}
    if (lplan <> nil) then 
    if (colonists>0) then begin
      inc(N,Min(Nc,MiningRate(lplan,Nc,Nm,nil)));
      inc(T,Min(Tc,MiningRate(lplan,Tc,Tm,nil)));
      inc(D,Min(Dc,MiningRate(lplan,Dc,Dm,nil)));
      inc(M,Min(Mc,MiningRate(lplan,Mc,Mm,nil)));
    end; 
  end; 
  FreeMem(GoodShips, sizeof(GoodShips^));
  FreeMem(TowedBy, sizeof(TowedBy^));
  
end;

Procedure PretendHost;
var
(*   TempShips: shipTable; {Need this to move ships} old *)
   Ships  : ^shipTable; {Need this to move ships}
   TempPlanet: PRec;
   TempBase  : BRec;
   templplan : pptr;
   templbase : bptr;
 
   templtype,i,templock : int;
   tempturn  : int;
   tempCloneID :int;
   tempplayer  :int;
   tempbldN  : array [bldType] of byte;
   tempShowUpgradeCosts : boolean;
   tempSWPlan: Boolean;
   number      : word;
   h1           : sptr;

begin
   if (turn<>today) or (ltype<>LockP) or (lplan=nil) or (lbase=nil) then Exit;

   number := lock and LockLo;
   if (number=0) or (number>500) then Exit;

   tempbldN[bldH] := bldN[bldH];
   tempbldN[bldE] := bldN[bldE];
   tempbldN[bldW] := bldN[bldW];
   tempbldN[bldT] := bldN[bldT];

   {store values}
   templtype   := ltype; 
   templock    := lock;
   tempturn    := turn;
   tempplayer  := player;
   tempCloneID := CloneID;
   templplan   := lplan;
   templbase   := lbase;
   tempShowUpgradeCosts := ShowUpgradeCosts;
   tempSWPlan := SWPlan;
   {make proxy planet}
   ltype     := LockP;
   turn      := today+1;
   CloneID   := 0;           {no cloning}
   player    := player+20; {make read only mode, Changed by Quapla: was := 20}

   {copy current planet}
   TempPlanet := lplan^;
   TempBase   := lbase^;
   lplan      := @TempPlanet;
   lbase      := @TempBase;

   {alocate and copy all ships}
   CheckMem(sizeof(Ships^)); GetMem(Ships, sizeof(Ships^));
   for i:=1 to NUM_SHIPS do
   begin
      h1:=TTurn^.data^.ship[i];
      if (h1<>nil) then
      begin
        New(Ships^[i]);
        Ships^[i]^:= h1^;
        if (Ships^[i]^.when = today) then
          Ships^[i]^.when := today+1;
      end
      else
        Ships^[i] := nil; {No ship data}
   end;

   RunHost(number,@Ships^);
   {proxy build}
   SWPlan := No;
   (*************************)
   BaseBuild;
   (*************************)
   SWPlan := tempSWPlan;


   {dealocate ships}
   for i:=1 to NUM_SHIPS do
      if (Ships^[i]<>nil) then Dispose(Ships^[i]);

   FreeMem(Ships, sizeof(Ships^));
   {restore old values}
   ltype := templtype;
   lock  := templock;
   turn  := tempturn;
   player := tempplayer;
   CloneID := tempCloneID;
   lplan := templplan;
   lbase := templbase;
   ShowUpgradeCosts := tempShowUpgradeCosts;

   bldN[bldH] := tempbldN[bldH];
   bldN[bldE] := tempbldN[bldE];
   bldN[bldW] := tempbldN[bldW];
   bldN[bldT] := tempbldN[bldT];
end;

procedure showPlanetorNot(xx,yy,x,y,turn_ : int);
var
   i,p:int;
   s :str20;
begin
        SetColor(White);
  p:=PSearchXY(x,y);
  s := Location(x,y);
  OutTextXY(xx,yy+8,s);
        if (p<>0) then 
           OutTextXY(xx,yy,'Planet '+NStr0(p))
        else
    if s[1]='÷' then
           OutTextXY(xx,yy,'Gravity well')
        else
           OutTextXY(xx,yy,'Deep Space');
        
        SetColor(LightGray);
        if (turn_ = today +1)  then
       OutTextXY(xx,yy+16,'(next turn)')
    else
    if (turn_ = today) then   
       OutTextXY(xx,yy+16,'(now)')
    else
       OutTextXY(xx,yy+16,'Turn : '+NStr0(turn_));
end;

PROCEDURE ShowForecast;
begin
  PretendHostAnywhere(TRUE, 0);
end;

PROCEDURE ShowPlanetNextTurn;
begin
  PretendHostAnywhere(FALSE, 0);
end;

PROCEDURE GetPillage(ShipNum : int);
begin 
  PretendHostAnywhere(TRUE, ShipNum);
end;


procedure PretendHostAnywhere(showF_ :boolean; ShpNum:int);
  {Getpillage: TRUE,  ShipNum
   ShowPlanet: FALSE, 0
   Forecast  : TRUE, 0}
var
(*   TempShips: shipTable; {Need this to move ships}
  *) 
(*  GoodShipsPtr = ^GoodShipsTable;
  GoodShipsTable = array [1..NUM_SHIPS] of Boolean; {Ship that will be processed}
*)
   
   Ships  : ^shipTable; {Need this to move ships}

   TempPlanet: PRec;
   TempBase  : BRec;
   templplan : pptr;
   templbase : bptr;
 
   templtype,i,templock : int;
   tempturn  : int;
   tempCloneID :int;
   tempplayer  :int;
   tempbldN  : array [bldType] of byte;
   tempShowUpgradeCosts : boolean;
   tempSWPlan,forceBase,forcePlanet: Boolean;
   number     : word;
   h1           : sptr;
   x_,y_ :int;
   N_,T_,D_,M_,supplies,funds,colonists_,natives: long;
   Cstat, Nstat, Nrace: int;
   tr : array [0..11] of int;
   s:string;
begin 
   CheckMem(sizeof(Ships^)); GetMem(Ships, sizeof(Ships^));

   {store values}
   tempbldN[bldH] := bldN[bldH];
   tempbldN[bldE] := bldN[bldE];
   tempbldN[bldW] := bldN[bldW];
   tempbldN[bldT] := bldN[bldT];

   templtype   := ltype;
   tempturn    := turn;
   tempplayer  := player;
   tempCloneID := CloneID;

   templplan  := lplan;
   
   tempShowUpgradeCosts := ShowUpgradeCosts;
   tempSWPlan := SWPlan;

   { FIXME check mine laying/scooping done in RunHost } 
   if (turn<>today) then Exit;
   forceBase := false; forcePlanet:=false;
   x_:=mmx;
   y_:=mmy;
   templock := lock;
   turn      := today+1;
   { CloneID   := 0;            cloning allowed}
   {player    := player+20;} {make read only mode. no need just show}

   {copy current planet}
   if (lplan <> nil) and (ltype=LockP) then begin
{    ltype      := LockP;}
    templplan  := lplan;
    TempPlanet := lplan^; 
    lplan      := @TempPlanet;
    number     := lock and LockLo;

    {if (lplan^.colonists<=0) then begin 
      lplan^.owner  :=player; 
      lplan^.colonists:=0; 
      lplan^.Ctax :=0; 
      lplan^.Cstat  :=80; 
      lplan^.supplies :=0;
      lplan^.funds  :=0;
    end;}
    
    if (lbase <> nil) then begin
      templbase  := lbase;
      TempBase   := lbase^;
      lbase      := @TempBase;
    end;
  end else begin
    {make proxy planet}
    number:=PSearchXY(x_,y_);
    if (number>0) and (number<501) then
     if (TTurn^.data^.planet[number] <> nil) then begin 
        if (lplan=nil) then forcePlanet := true;
        {ltype      := LockP;}
        TempPlanet := TTurn^.data^.planet[number]^; 
        lplan      := @TempPlanet;
        {lock := number;}
        
        {check for base}    
        if (lbase=nil) then 
          if (TTurn^.data^.base[number]<>nil) then 
          begin 
           TempBase   := TTurn^.data^.base[number]^;
           lbase      := @TempBase;
           forceBase:=True;
          end;
          if (lplan^.Nc = -1) or (lplan^.N = -1) or (lplan^.Nm =- 1) then 
          begin
            lplan := nil;
          end;     
     end else lplan:=nil { No Planet with number }
  else lplan:=nil; {XY not over Planet} 
  end;

   {alocate and copy all ships}
   for i:=1 to NUM_SHIPS do
   begin
      h1:=TTurn^.data^.ship[i];
      if (h1<>nil) then
      begin
        New(Ships^[i]);
        Ships^[i]^:= h1^;
        if (Ships^[i]^.when = today) then
          Ships^[i]^.when := today + 1;
      end
      else
        Ships^[i] := nil; {No ship data}
   end;
   RunHost(number,@Ships^);

   {Calculate results}
   N_:=0; T_:=0; D_:=0; M_:=0; supplies:=0; funds:=0; colonists_:=0;
   natives:=0;NStat:=0;NRace:=0;Cstat:=0;
   for i:=0 to 11 do tr[i]:=0;
   if (lplan <> nil) then begin
    N_:=lplan^.N; T_:=lplan^.T; D_:=lplan^.D; M_:=lplan^.M;
    supplies:=lplan^.supplies; funds:=lplan^.funds; colonists_:=lplan^.colonists;
    natives:=lplan^.natives; Nstat:=lplan^.Nstat; NRace:=lplan^.NRace; Cstat:=lplan^.Cstat; 
   end else begin
    for i:=1 to NUM_SHIPS do 
     if (Ships^[i]<>nil) then 
     with Ships^[i]^ do begin
      if (hull<>-1) and (mission<>-1) and 
       (fuel<>-1) and (mass<>-1)    and 
       (warp<>-1) and (El<>-1)      and
       (Wl<>-1)   and (Tl<>-1)      and 
       (T<>-1)    and (D<>-1)       and 
       (M<>-1) and (owner=player) then 
      if (x=x_) and (y=y_) then begin 
      {writeln('Total-ID: ',i,' $: ',credits,' S: ',sup);}

        inc(N_,fuel);
        inc(T_,T);
        inc(D_,D);
        inc(M_,M);
        inc(colonists_,colonists);
        inc(funds,credits);
        inc(supplies,Sup);
        if (launchers >0) then begin 
          inc(tr[Tl],TFnum);
          inc(tr[0],TFnum);
        end;
        if (bays>0) then inc(tr[11],TFnum); 
      end; 
     end; 
   end;

   if (lbase <> nil) then begin
      for i:=1 to 10 do begin 
        inc(tr[i],lbase^.TT[i]);
        inc(tr[0],lbase^.TT[i]);
      end;
      inc(tr[11],lbase^.fighters);
   end;
    
   {show results}
   if (ShpNum>0) and (ShowF_) then begin {GetPillage from ShipInfo}
      with (TTurn^.data^.ship[ShpNum]^) do begin {Original Ship Data}
{      writeln('ID: ',ShpNum,' $: ',credits,'/',TempShips[ShpNum]^.credits,' S: ',TempShips[ShpNum]^.sup);}
        if (credits < Ships^[ShpNum]^.credits) {Sup or $ changed?}
        then begin
          Clear(MX0, 248, 639, 255); {Show Klingon always}
          SetColor(lightgreen);
          OutTextXY(MX0+100, 248, 'Pill:');
          if (Ships^[ShpNum]^.fuel<1) then begin
              SetColor(lightred);
              OutTextXY(MX0+100, 248+2*8, 'ZERO');
          end else
            OutTextXY(MX0+100, 248+2*8, Nstr0(Ships^[ShpNum]^.fuel));
          OutTextXY(MX0+100, 248+6*8, Nstr0(Ships^[ShpNum]^.Sup));
          OutTextXY(MX0+100, 248+8*8, Nstr0(Ships^[ShpNum]^.credits));
        end else
{        if (T+D+M+Sup <> TempShips[ShpNum]^.Sup+TempShips[ShpNum]^.M+
            TempShips[ShpNum]^.D+TempShips[ShpNum]^.T)}
         if (TTurn^.data^.xyplan[number,1]=x_) and (TTurn^.data^.xyplan[number,2]=y_) then {was over planet}
         if (Ships^[ShpNum]^.mission) in [11..15] 
            then begin {Gathered?}
          Clear(MX0, 248, 639, 255); {Show Klingon always}
          SetColor(lightgreen);
          OutTextXY(MX0+100, 248, 'Beam'+#39+'d');
          if (Ships^[ShpNum]^.fuel<1) then begin
              SetColor(lightred);
              OutTextXY(MX0+100, 248+2*8, 'ZERO');
          end else
            OutTextXY(MX0+100, 248+2*8, Nstr0(Ships^[ShpNum]^.fuel));
          OutTextXY(MX0+100, 248+6*8, Nstr0(Ships^[ShpNum]^.Sup));
          OutTextXY(MX0+100, 248+3*8, Nstr0(Ships^[ShpNum]^.T));
          OutTextXY(MX0+100, 248+4*8, Nstr0(Ships^[ShpNum]^.D));
          OutTextXY(MX0+100, 248+5*8, Nstr0(Ships^[ShpNum]^.M));
        end else 
         if (TTurn^.data^.xyplan[number,1]=x_) and (TTurn^.data^.xyplan[number,2]=y_) then {was over planet, {Refit?}
         if (mission = 9) and (Race[RealShipOwner(ShpNum)]=1) and (fuel>0) and (Ships^[ShpNum]^.name[20]='!') then begin 
          Clear(MX0, 248, 639, 255); 
          SetColor(lightgreen);
          OutTextXY(MX0+100, 248, 'Refit');
          OutTextXY(MX0+100, 248+2*8, Nstr0(Ships^[ShpNum]^.fuel));
          with (Ships^[ShpNum]^) do begin
            Clear(MX0,215,639,247);
            OutTextXY(MX0,215,'New Equipment:');
            if (El<>-1) then
            begin
              s:='';
              str(Hulls[hull].engines,s);
              s:=s+' ';
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
          end;
        end;    
      end; 
   end else if (ShpNum=0) and (showF_) then begin {_F Forecast}  
        SetColor(LightGray);
        Clear(0,0,MX0-17,21);
        s := 'N: '+NStr0(N_)+' | T: '+NStr0(T_)+' | D: '+NStr0(D_)+' | M: '+NStr0(M_)+
        ' | $: '+NStr0(funds)+' | S: '+NStr0(supplies);
        OutTextXY(5,5,copy(s, 1, min(length(s),59)));
        s := 'C: '+NStr0(colonists_)+' ('+NStr0(Cstat)+'%) | ';
        if natives >0 then s := s+'N: '+NStr0(natives)+' '+copy(NatRace[NRace],1,3)+' ('+Nstr0(Nstat)+'%) | ';
        if tr[0]>0 then s:=s+'Tp: '+NStr0(tr[0])+' | ';
        if tr[11]>0 then s:=s+'F: '+NStr0(tr[11])+' | ';
        s:=s+'$+S: '+NStr0(funds+supplies);
        OutTextXY(5,13,copy(s, 1, min(length(s),59)));
        ShowShips(today+1,108+23*8,showF_, @Ships^); 
        if (templtype=LockS) then begin {Ship View next Turn}
          i := (templock and LockLO);
          if (Ships^[i] <> NIL) then begin
            Clear(MX0-8*8,248,MX0-17,248*10*8);
            SetColor(LightGray);
            OutTextXY(MX0-8*8, 248, 'F'+#39+'cast');
            if (Ships^[i]^.fuel<1) then begin
              SetColor(lightred);
              OutTextXY(MX0-7*8, 248+2*8, 'ZERO');
              SetColor(LightGray);
            end else
              OutTextXY(MX0-7*8, 248+2*8, Nstr0(Ships^[i]^.fuel));
            OutTextXY(MX0-7*8, 248+3*8, Nstr0(Ships^[i]^.T));
            OutTextXY(MX0-7*8, 248+4*8, Nstr0(Ships^[i]^.D));
            OutTextXY(MX0-7*8, 248+5*8, Nstr0(Ships^[i]^.M));
            OutTextXY(MX0-7*8, 248+6*8, Nstr0(Ships^[i]^.Sup));
            OutTextXY(MX0-7*8, 248+7*8, Nstr0(Ships^[i]^.colonists));
            OutTextXY(MX0-7*8, 248+8*8, Nstr0(Ships^[i]^.credits));
            if ((Ships^[i]^.Bays) >0) or ((Ships^[i]^.Launchers) >0) then
              OutTextXY(MX0-7*8, 248+9*8, Nstr0(Ships^[i]^.TFNum)); 
          end;
        end;
   end else if (ShpNum=0) and not (showF_) then  begin {_F1} 
       Clear(MX0,72,639,358);
       showPlanetorNot(MX0,72,x_,y_,turn);
       SetColor(LightGray);
       OutTextXY(MX0,108+0*8,'Neut : '+NStr0(N_)) ;
       OutTextXY(MX0,108+1*8,'Trit : '+NStr0(T_)) ;
       OutTextXY(MX0,108+2*8,'Dura : '+NStr0(D_)) ;
       OutTextXY(MX0,108+3*8,'Moly : '+NStr0(M_)) ;
       OutTextXY(MX0,108+4*8,'Colo : '+NStr0(colonists_)+' '+Nstr0(Cstat)+'%') ;
       if natives>0 then
          OutTextXY(MX0,108+5*8,copy(NatRace[NRace],1,4)+' : '+NStr0(natives)+' '+Nstr0(Nstat)+'%') ;
       OutTextXY(MX0,108+6*8,'Fund : '+NStr0(funds));
       OutTextXY(MX0,108+7*8,'Supp : '+NStr0(supplies));
       OutTextXY(MX0,108+8*8,'Mins : '+NStr0(T_+D_+M_)) ;
       OutTextXY(MX0,108+9*8,'S.+F.: '+NStr0(funds+supplies)) ; 
      
      { Show torpedos } 
      for i:=1 to 10 do 
        OutTextXY(MX0,108+10*8+i*8,Torps[i].name+'   : '+NStr0(tr[i])) ;
      OutTextXY(MX0,108+10*8+11*8,'Fighters : '+NStr0(tr[11])) ;
      { Ships Here }
      OutTextXY(MX0,108+24*8,'Ships at Position:');
      ShowShips(today+1,108+23*8,showF_, @Ships^); 
      
    end;
    
   
   {dealocate ships}
   for i:=1 to NUM_SHIPS do
      if (Ships^[i]<>nil) then Dispose(Ships^[i]);
   FreeMem(Ships, sizeof(Ships^));
   
   {restore old values}
   ltype := templtype;
   turn  := tempturn;
   player := tempplayer;
   CloneID := tempCloneID;
      
   if (lplan <> nil) then begin
      lplan := templplan;
      if (lbase <> nil) then lbase := templbase;
   end;
     
   if (forceBase) then lbase:=nil;
   if (forcePlanet) then lplan:=nil;
   ShowUpgradeCosts := tempShowUpgradeCosts;

   bldN[bldH] := tempbldN[bldH];
   bldN[bldE] := tempbldN[bldE];
   bldN[bldW] := tempbldN[bldW];
   bldN[bldT] := tempbldN[bldT];
   lock := templock;
   
end;



procedure ShowShips(turn__ :int; ly_ :int; showF_ : boolean; TempShipsPtr: stptr);
var
  TempShips: shipTable;
        ShipSortTablePtr      : ^ShipSortArray ;
        ShipSortTableIndex    : word;
        {ShipSortTableType     : word;}
        ShipSortTableLock     : boolean;
        x,y,i,j,k,l,n : int;
         s       : string[8];
         ss      : string;
        h       : sptr;
        p       : pptr;
        fa, fc  : int;
        swap    : ShipSortRecord;
        towed,ObjN   : int;
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
    end;
  end;
  function MarkOffsetY(t:MarkType) : int;
  begin
    MarkOffsetY:=0;
    if (t=mrkFlag) or (t=mrkGrave) or (t=mrkCactus) then
      begin
        MarkOffsetY:=3;
      end;
  end;        
function ShipIsHere (i,x,y,turn_:int) : boolean;
  var   h       : sptr;
  begin
    h:=TempShips[i];
    ShipIsHere:=(h<>nil) and (h^.when=turn_) and (h^.x=x) and (h^.y=y);
  end; 
function UnderTow (id,turn_:int) : int;       { tower's id or 0 }
  var   i       : int;
        h1      : sptr;
  begin
    UnderTow:=0;
    for i:=1 to 999 do
    begin
      h1:=TempShips[i];
      if (h1<>nil) and (h1^.when=turn_) and
         (h1^.mission=7) and (h1^.tow_ship=id) then
        begin UnderTow:=i; Exit end;
    end;
  end;

function GoToShipXYSorted (var h:sptr; x,y,k:int) : int;
  var   i       : int;
  begin   
    if (k>0) and (ShipSortTableIndex > 0) and (k<=ShipSortTableIndex ) then
    begin
      h:=TempShips[ShipSortTablePtr^[k].id];
      GoToShipXYSorted:=ShipSortTablePtr^[k].id or LockS;
      Exit;
    end; 
    h:=nil;
    GoToShipXYSorted:=0;
  end;  
  
begin
(*   Clear(MX0,72,639,358); *)
   if not showF_ then if ly_=72 then Clear(MX0,ly_,639,430) else Clear(MX0,ly_+24,639,430); {_F1 or _F2}
   
   TempShips:=TempShipsPtr^;
   ObjN:=0;
   ShipSortTableIndex :=0;
   
   x:=mmx;
   y:=mmy;
 
   New(ShipSortTablePtr);
   FillChar(ShipSortTablePtr^, Sizeof(ShipSortTablePtr^), 0);
   
    for i:=1 to NUM_SHIPS do
      if ShipIsHere(i,x,y,turn__) then
      begin
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
     with TempShips[ShipSortTablePtr^[i].id]^ do
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
     with TempShips[ShipSortTablePtr^[i].id]^ do
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
     with TempShips[ShipSortTablePtr^[i].id]^ do
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

         if (TempShips[ShipSortTablePtr^[towed].id]^.warp > 0) and
            (ShipSortTablePtr^[towed].color = COLOR_SHIP_TOWED) then
              ShipSortTablePtr^[towed].color := COLOR_SHIP_TOWED_HAS_WARP;
        
         if (ShipSortTablePtr^[towed].icon = NO_ICON) then
              ShipSortTablePtr^[towed].icon  := ICON_SHIP_TOWED;
              
         end;
       end;
    end
     else
     begin
       if ( UnderTow(ShipSortTablePtr^[i].id,turn__) > 0) then
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
    
    {show ships}
    if not showF_ then if ly_=72 then showPlanetorNot(MX0,72,x,y,turn); (* Shift F2, Else Shift F1 *)
    l:=ly_+24;
    ss := '';
    while ((k<=ObjN) and (k<=28)) do
    begin
      
        n:=GoToShipXYSorted(h,lx,ly,k);
        if h<>nil then
        begin
         
          SetColor(RaceColor[h^.owner,_S_]);
          with h^ do
          begin
          if hull<>-1 then
            if owner=player then 
              if showF_ then ss := ss+NStr(n AND LockLo)+' '+copy(name,1,8)+' | '
              else begin
                OutTextXY(MX0+8,l,NStr(n AND LockLo));
                OutTextXY(MX0+40,l,name);
            end else if showF_ then
              ss := ss+NStr(n AND LockLo)+' '+copy(Hulls[hull].name,1,8)+' | '
              else begin
              OutTextXY(MX0+8,l,NStr(n AND LockLo));
              OutTextXY(MX0+40,l,Hulls[hull].name);
            end
          else begin
            if mass=-1 then s:='' else s:=' ('+NStr0(mass)+'kt)';
            if showF_ then 
              ss := ss+'Ship '+NStr0(n and LockLo)+s+' | '
            else
              OutTextXY(MX0+8,l,'Ship '+NStr0(n and LockLo)+s);
          end;
            if (ShipSortTablePtr^[k].icon <> NO_ICON) and not showF_ then
            begin
              SetColor(ShipSortTablePtr^[k].color);
              DrawMark (MX0+0-5+8,l+4+MarkOffsetY(ShipSortTablePtr^[k].Icon),
                       ShipSortTablePtr^[k].color,
                       ShipSortTablePtr^[k].Icon);
            end;  
          end;
      end;
    inc(l,8);
    inc(k);
    end;
    if showF_  then begin
        Clear(0,459,MX0-17,480);
        if ((length(ss)-3) < 60) then begin
          OutTextXY(5,468,copy(ss,1,min((length(ss)-3),59)));
        end else begin
          OutTextXY(5,460,copy(ss,1,min((length(ss)-3),59)));        
          OutTextXY(5,468,copy(ss,60,min((length(ss)-62),59)));
        end;
    end;
    Dispose(ShipSortTablePtr);
end;


procedure ShowShipsNextTurn;
var
{   TempShips: shipTable;}
  Ships  : ^shipTable; {Need this to move ships}
      TempPlanet: PRec;
   TempBase  : BRec;
   templplan : pptr;
   templbase : bptr;
 
   templtype,i : int;
   tempturn  : int;
   tempCloneID :int;
   tempplayer  :int;
   tempbldN  : array [bldType] of byte;
   tempShowUpgradeCosts : boolean;
   tempSWPlan,forceBase: Boolean;
  number : word;
   h1           : sptr;
   x,y :int;
   N,T,D,M,supplies,funds,colonists: long;
begin
  x:=mmx;
  y:=mmy;
  if (turn<>today) then exit;
  if (lplan= nil) then begin
    number:=PSearchXY(x,y);
    if (number<>0) then
    if (TTurn^.data^.planet[number] <> nil) then begin 
      lplan:=TTurn^.data^.planet[number];
      lock := number;
    end;
  end;
  if (lplan <>nil) then begin
    if (ltype=LockP) then  number:=lock and LockLo
    else number:=PSearchXY(x,y);
    if (number=0) or (number>500) then Exit;
      {check for base}    
    if (lbase=nil) then 
    if (TTurn^.data^.base[number]<>nil) then begin 
      lbase:=TTurn^.data^.base[number];
      forceBase:=True;
    end;
  end;

   {store values}
   templtype   := ltype;
   tempturn    := turn;
   tempplayer  := player;
   tempCloneID := CloneID;
   tempShowUpgradeCosts := ShowUpgradeCosts;
   tempSWPlan := SWPlan;
   {make proxy planet}
   turn      := today+1;
   CloneID   := 0;           {no cloning}
  { player    := 20;} {make read only mode}
   
   {copy current planet}
   if (lplan <> nil) then begin
   ltype      := LockP;
   templplan  := lplan;
   TempPlanet := lplan^;
   lplan      := @TempPlanet;
   if (lplan^.colonists<=0) then begin 
    lplan^.owner  :=player; 
    lplan^.colonists:=0; 
    lplan^.Ctax :=0; 
    lplan^.Cstat  :=80;
    lplan^.supplies :=0;
    lplan^.funds  :=0;
   end;
   if (lbase <> nil) then begin
    templbase  := lbase;
    TempBase   := lbase^;
    lbase      := @TempBase;
   end;
   end;  

   
    {alocate and copy all ships}
   CheckMem(sizeof(Ships^)); GetMem(Ships, sizeof(Ships^));
   for i:=1 to NUM_SHIPS do
   begin
      h1:=TTurn^.data^.ship[i];
      if (h1<>nil) then
      begin
        New(Ships^[i]);
        Ships^[i]^:= h1^;
        if (Ships^[i]^.when = today) then
          Ships^[i]^.when := today+1;
      end
      else
        Ships^[i] := nil; {No ship data}
   end;

   RunHost(number,@Ships^);
   ShowShips(today+1,72,FALSE, @Ships^);

   {dealocate ships}
   for i:=1 to NUM_SHIPS do
      if (Ships^[i]<>nil) then Dispose(Ships^[i]);
   FreeMem(Ships, sizeof(Ships^));

   {restore old values}
   ltype := templtype;
   turn  := tempturn;
  { player := tempplayer;}
   CloneID := tempCloneID;
 
   if (lplan <> nil) then begin
      lplan := templplan;
      if (lbase <> nil) then lbase := templbase;
   end;
   
   if (forceBase) then lbase:=nil;
   ShowUpgradeCosts := tempShowUpgradeCosts;
   
end;

end.
