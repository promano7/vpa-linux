{
*******************************************************************
* VPA4.PAS - Main Part - Misc
*
* $Id: vpa4.pas,v 1.25 2013/12/29 06:41:03 sfplanets Exp $
*
*
*******************************************************************
}

{$I switches.inc}
unit VPA4;

interface

uses Graph, VPAData, AuxF, Building;

procedure SetTaxes (nat:boolean; var tax:int);                  { M.O.T. }
procedure WriteMiningRate;
procedure WriteMineral (M,y:int; N,Nc:long; Nm:int);
procedure WriteActivity (var ep:epln);
procedure WriteTaxes (tax,y:int);
procedure WriteIncome(id:int);
function MouseGetTarget (lcolor,lstyle:byte; ctrl:boolean) : boolean;   { sets mmx,mmy }
function NearestObject (var mx,my:int) : word;  { sets new mx,my }
procedure Ini_Init_CMistakes;
procedure MyMax;              { Handles Common Mistakes SHFT-F11 }
procedure Ini_Init_Addon;     { Handles Addons Quapla}
procedure Ini_Init_Help;
procedure PlanetInfo;
procedure BaseInfo;
procedure LastBuilt(var id:word);
procedure BaseStorage;
procedure MyCalc;
{procedure SimGA;}
procedure SimGroundAttack(Input:byte);
procedure SimOwnGroundAttack;
function DoChooseNumber(x,y,len,arrow: long; yes_no : Boolean; min_,max_,initnumber : long):long;
procedure GetTeleport(PlanN:int);
function GetTeleportDataTX(pl:int; var mineral:byte; var data:int) : int; {returns corresponding RX-Data}
function GetTeleportDataRX(pl:int; var mineral:byte; var data:int) : int; {returns corresponding TX-Data}
procedure ShowTeleport;
procedure ShowRules;

implementation

uses Screen, Mouse, StrF, Keyboard, VPA2, INI,dos
{$IFDEF TASKS}
     ,Tasks 
{$ENDIF}
     ,Extfeat, UtilFmt
{$IFDEF VPACC}
     ,PHostM,VPACC,Hullfunc
{$ENDIF};

procedure WriteMiningRate;
  var   s               : string[3];
        c               : byte;
        b               : boolean;
  begin
    if lplan=nil then Exit;
    c := IIF((lplan^.when=turn) and (lplan^.when=lplan^.when0),cPInfo,cOPInfo);
    with lplan^ do
    begin
      if (Nc<>-1) and (Nm<>-1) and (Nc<>0) then
      begin
        Clear(MX0+12*8+1,308,MX0+15*8-1,315);
        Str(MiningRate(lplan,Nc,Nm,@b):3,s);
        SetColor(IIF(b, Yellow, c));
        OutTextXY(MX0+12*8,308,s);
      end;
      if (Tc<>-1) and (Tm<>-1) and (Tc<>0) then
      begin
        Clear(MX0+12*8+1,318,MX0+15*8-1,325);
        Str(MiningRate(lplan,Tc,Tm,@b):3,s);
        SetColor(IIF(b, Yellow, c));
        OutTextXY(MX0+12*8,318,s);
      end;
      if (Dc<>-1) and (Dm<>-1) and (Dc<>0) then
      begin
        Clear(MX0+12*8+1,328,MX0+15*8-1,335);
        Str(MiningRate(lplan,Dc,Dm,@b):3,s);
        SetColor(IIF(b, Yellow, c));
        OutTextXY(MX0+12*8,328,s);
      end;
      if (Mc<>-1) and (Mm<>-1) and (Mc<>0) then
      begin
        Clear(MX0+12*8+1,338,MX0+15*8-1,345);
        Str(MiningRate(lplan,Mc,Mm,@b):3,s);
        SetColor(IIF(b, Yellow, c));
        OutTextXY(MX0+12*8,338,s);
      end;
    end;
    SetColor(c);
  end;

procedure WriteMineral (M,y:int; N,Nc:long; Nm:int);
  var   s,s1,s2,s3      : string[6];
        sm              : array [1..2] of char absolute M;
        b               : boolean;
        oc              : byte;
  begin
    s:=''; s1:='     '; s2:='';
    oc := GetColor;
    if N>-1 then Str(N:5,s);
    if (Nc<>-1) and (Nc<>-2) then Str(Nc:5,s1);
    OutTextXY(MX0,y,sm+s+s1);
    if (Nm<>-1) and (Nc<>0) then
    begin
      Str(MiningRate(lplan,Nc,Nm,@b):3,s3);
      if b then SetColor(yellow);
      s2:=s3+'/'+NStrMax(Nm,2,'+');
    end;
    OutTextXY(MX0+8*12,y,s2);
    SetColor(oc);
  end;

procedure WriteActivity (var ep:epln);
  var   k       : byte;
  begin
    k:=ep.activity and 7;
    if k=0 then Exit;
    if k>5 then k:=0;
    SetColor(IIF(ep.when=turn,cPInfo,cOPInfo));
    OutTextXY(MX0,224,Industry[k]);
    OutTextXY(MX0,232,'    industrial');
    OutTextXY(MX0,240,'          activity');
  end;

procedure WriteIncome(id:int);
  var   l       : long;
  begin
    Clear(MX0+10*8,272,638,279);
    l:=PlanetIncome(lplan,id,TRUE);
    if l>0 then
    begin
      SetColor(IIF((lplan^.when=turn) and (lplan^.when=lplan^.when0),cPInfo,cOPInfo));
      OutTextXY(MX0,272,'Income  : '+NStr0(l));
    end;
  end;

procedure WriteTaxes (tax,y:int);
  var   s       : string[7];
  begin
    if tax=0 then s:='No' else s:=NStr(tax)+'%';
    OutTextXY(MX0,y,' Taxes: '+s);
  end;

procedure SetTaxes (nat:boolean; var tax:int);                  { M.O.T. }
  var   x,y,tax0  : int;
        number  : int;
        ch      : word;
        l       : int;
        s       : string[3];
  begin
    if (lplan=nil) or (lplan^.when<>today) or (nat and (lplan^.Nrace=0)) then Exit;
    {MouseOff;}
    MouseDisabled:=True;
    l:=0; if nat and not ShowMaxPop then l:=8;
    SetLineStyle(SolidLn,0,NormWidth);
    x:=MX0+8*8;
    y:=IIF(nat,160,200);
    Clear(MX0+11*8,y+l,639,y+7+l);
    tax0:=tax;
    number:=lock and LockLo;
    repeat
      WriteHChange(nat);
      WriteMaxPop(-1,0);
      Clear(MX0+8*8,y+l,MX0+12*8-1,y+7+l);
      WriteTaxes(tax,y+l);
      repeat ArrowBlink(592,y+l) until KeyPressed;
      ch:=ReadKey;
      case ch of
        $4B00   : if tax>0 then
                  begin
                    if KbdFlags and KbdShft=0 then dec(tax) else tax:=0;
                    WriteIncome(number);
                  end;
        $4D00   : if tax<100 then
                  begin
                    if KbdFlags and KbdShft=0 then inc(tax) else tax:=100;
                    WriteIncome(number);
                  end;
        $7300   : if tax>=10 then
                  begin
                    dec(tax,10);
                    WriteIncome(number);
                  end;
        $7400   : if tax<=90 then
                  begin
                    inc(tax,10);
                    WriteIncome(number);
                  end;
        ord('0')..ord('9') :
                  begin
                    GetStr1stKey:=ch;
                    s:=GetStr(x,y+l,3);
                    if GetStrKey=13 then
                    begin
                      tax := Value(s);
                      if tax<0 then tax:=0;
                      if tax>100 then tax:=100;
                      WriteIncome(number);
                    end;
                  end;
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
      end;
    until (ch=13) or (ch=27);
    {if ch=27 then tax:=tax0;}
    if tax<>tax0 then ChangeData(Pl,lock and LockLo);
    Clear(MX0+8*8,y+l,639,y+7+l);
    WriteHChange(nat);
    WriteTaxes(tax,y+l);
    SetColor(White);
    if nat then OutTextXY(MX0+8,160+l,'T')
           else OutTextXY(MX0+24,200+l,'x');
    WriteIncome(number);
    MouseDisabled:=False;
    {MouseOn;}
  end;

function MouseGetTarget (lcolor,lstyle:byte; ctrl:boolean) : boolean;   { sets mmx,mmy }
  var   ch,mEv0 : word;
        mdis0   : boolean;
        lock0,glx0,gly0,lx0,ly0 : int;
        x0,y0,x1,y1             : int;
        ack     : word;
  procedure DrawLine;
    begin
      if lcolor=0 then Exit;
      MouseOff;
      SetWriteMode(XORPut);
      SetColor(lcolor);
      Line(x0,y0,x1,y1);
      SetWriteMode(NormalPut);
      MouseOn;
    end;
  procedure NewPoint;
    begin
      DrawLine;
      WriteCoord;
      x1:=MouseX; y1:=MouseY;
      DrawLine;
    end;
  procedure LockObj;
    var mx,my   : int;
    begin
      lx:=mmx; ly:=mmy;
      lock:=NearestObject(lx,ly);
      Abs2Scr(lx,ly,mx,my);
      MoveMouseTo(mx,my);
    end;
  begin
    ack:=IIF(ctrl,10,13);
    lock0:=lock; lock:=0;
    lx0:=lx; lx:=0;
    ly0:=ly; ly:=0;
    glx0:=glx; glx:=0;
    gly0:=gly; gly:=0;
    mdis0:=MouseDisabled;
    MouseDisabled:=No;
    Abs2Scr(mmx,mmy,x0,y0);
    SetLineStyle(lstyle,0,NormWidth);
    x1:=x0; y1:=y0;
    ch:=0;
    DrawLine;
    repeat
      if KeyPressed then
      begin
        ch:=ReadKey;
        case ch of
{left}    $4B00 : if MouseX>0   then MoveMouseTo(MouseX-Max(1,ratio2 div ratio1),MouseY);
{right}   $4D00 : if MouseX<479 then MoveMouseTo(MouseX+Max(1,ratio2 div ratio1),MouseY);
{up}      $4800 : if MouseY>0   then MoveMouseTo(MouseX,MouseY-Max(1,ratio2 div ratio1));
{down}    $5000 : if MouseY<479 then MoveMouseTo(MouseX,MouseY+Max(1,ratio2 div ratio1));
{~lt}     $9B00 : if MouseX>9   then MoveMouseTo(MouseX-10,MouseY);
{~rt}     $9D00 : if MouseX<470 then MoveMouseTo(MouseX+10,MouseY);
{~up}     $9800 : if MouseY>9   then MoveMouseTo(MouseX,MouseY-10);
{~dn}     $A000 : if MouseY<470 then MoveMouseTo(MouseX,MouseY+10);
          13    : begin LockObj; if ctrl then NewPoint end;
        end;
        NewPoint;
        if (ch<>13) and (ch<>ack) then lock:=0;
      end;
      if mEvent<>0 then
      begin
        mEv0:=mEvent; mEvent:=0;
        if mEv0=EvMouseMove then begin NewPoint; lock:=0 end;
        if mEv0=EvLtPress then
          if (not ctrl) or (KbdFlags and KbdCtrl<>0) then ch:=ack
          else begin LockObj; NewPoint end;
        if mEv0=EvRtPress then ch:=27;
        mEv0:=0;
      end;
    until (ch=ack) or (ch=27);
    DrawLine;
    MouseDisabled:=mdis0;
    lock:=lock0;
    lx:=lx0; ly:=ly0;
    glx:=glx0; gly:=gly0;
    MouseGetTarget:=(ch=ack);
  end;

function NearestObject (var mx,my:int) : word;  { sets new mx,my }
  var   shift   : boolean;
        i,n     : int;
        nd,dd   : long;
        nx,ny   : int;
        lck     : int;
  procedure Check (x,y:int);
    begin
      if x=-1 then Exit;
      dd:=Distance2(mx,my,x,y);
      if dd<nd then
      begin
        nd:=dd;
        nx:=x; ny:=y;
        n:=i or lck;
      end;
    end;
  begin
    shift:=(showM or showI or showU or showA) and ((KbdFlags and KbdShft)<>0);
    n:=0;
    nd:=1000000000;
    with TTurn^.data^ do
    begin
      if not shift then
      begin
        lck:=LockP;
        for i:=1 to 500 do Check(xyplan[i,1],xyplan[i,2]);
        lck:=LockS;
        if showS or showE then
          for i:=1 to 999 do
            with ship[i]^ do
            if (ship[i]<>nil) and (when=turn) and (splan[i]=0) and
               ((showS and (owner=player)) or (showE and (owner<>player))) then
              Check(x,y);
        if distlock<0 then
        begin
          lck:=0; i:=distlock;
          Check(dlx,dly);
        end;
      end;
      lck:=LockM;
      if showM then
        for i:=1 to 500 do
          with mines[i]^ do
          if mines[i]<>nil then Check(x,y);
      lck:=LockI;
      if showI then
        for i:=1 to 50 do
          with ion[i]^ do
          if ion[i]<>nil then Check(x,y);
      lck:=LockW;
      if showU then
        for i:=0 to 199 do
          with worm[i]^ do
          if worm[i]<>nil then Check(x,y);
      lck:=LockU;
      if showU then
        for i:=1 to 100 do
          with ufo[i]^ do
          if ufo[i]<>nil then Check(x,y);
      lck:=LockA;
      if showA then
        for i:=1 to nmark do
          with mark^[i] do
          if (mtype<>mrkNone) and ((not shift) or (mtype=mrkRCircle)) then
          begin
            Check(x,y);
            if (mtype in [mrkLine,mrkDLine]) then Check(x+dx,y+dy);
          end;
    end;
    NearestObject:=n;
    if n<>0 then begin mx:=nx; my:=ny end;
  end;

var CMistakes : record
   bovis,detect,unhappy70,lowntax,nontax         : boolean;
   btm0mc,towwarn,inwarp,tooslow,hypwarn,lowfuel : boolean;
   chkchun,ahpwarn,da_max,rmt_tmx                : boolean;  
   chkmines,clone,base,pop,trg,build,teleport    : boolean; 
	 oneclan,accurate 														 : boolean;
end;                                        { true = disable component }

var VPAHELP : record
   List,Help1,Help2,Help3,Help4							         : boolean;
	 Help5,Help6,Help7,Help8,Help9										 : boolean;
end;  																	   { true = enable component }
 
procedure Ini_Init_CMistakes;
begin
   ini_add(ini_file_cmistakes,'Planets','P-Bovis','',ini_size_boolinv,@CMistakes.bovis);
   ini_add(ini_file_cmistakes,'Planets','P-Detect','',ini_size_boolinv,@CMistakes.detect);
   ini_add(ini_file_cmistakes,'Planets','P-Unhappy70','',ini_size_boolinv,@CMistakes.unhappy70);
   ini_add(ini_file_cmistakes,'Planets','P-LowNTax','',ini_size_boolinv,@CMistakes.lowntax);
   ini_add(ini_file_cmistakes,'Planets','P-NoNTax','',ini_size_boolinv,@CMistakes.nontax);
   ini_add(ini_file_cmistakes,'Planets','P-DA_Max','',ini_size_boolinv,@CMistakes.da_max);
   ini_add(ini_file_cmistakes,'Planets','P-BldBase','',ini_size_boolinv,@CMistakes.base);   
	 ini_add(ini_file_cmistakes,'Planets','P-OneClan','',ini_size_boolinv,@CMistakes.oneclan);   
   ini_add(ini_file_cmistakes,'Base','B-RMT_TMx','',ini_size_boolinv,@CMistakes.rmt_tmx);
   ini_add(ini_file_cmistakes,'Base','B-No_Bld','',ini_size_boolinv,@CMistakes.build);
   ini_add(ini_file_cmistakes,'Base','B-Teleport','',ini_size_boolinv,@CMistakes.teleport);
   ini_add(ini_file_cmistakes,'Ships','S-btm0mc','',ini_size_boolinv,@CMistakes.btm0mc);
   ini_add(ini_file_cmistakes,'Ships','S-TowWarn','',ini_size_boolinv,@CMistakes.towwarn);
   ini_add(ini_file_cmistakes,'Ships','S-InWarp','',ini_size_boolinv,@CMistakes.inwarp);
   ini_add(ini_file_cmistakes,'Ships','S-TooSlow','',ini_size_boolinv,@CMistakes.tooslow);
   ini_add(ini_file_cmistakes,'Ships','S-HypWarn','',ini_size_boolinv,@CMistakes.hypwarn);
   ini_add(ini_file_cmistakes,'Ships','S-AHPWarn','',ini_size_boolinv,@CMistakes.ahpwarn);
   ini_add(ini_file_cmistakes,'Ships','S-LowFuel','',ini_size_boolinv,@CMistakes.lowfuel);
   ini_add(ini_file_cmistakes,'Ships','S-ChkChun','',ini_size_boolinv,@CMistakes.chkchun);
   ini_add(ini_file_cmistakes,'Ships','S-ChkMines','',ini_size_boolinv,@CMistakes.chkmines);
   ini_add(ini_file_cmistakes,'Ships','S-Clone','',ini_size_boolinv,@CMistakes.clone);   
   ini_add(ini_file_cmistakes,'Ships','S-Glorypop','',ini_size_boolinv,@CMistakes.pop);   
   ini_add(ini_file_cmistakes,'Ships','S-Glorytrg','',ini_size_boolinv,@CMistakes.trg);   
   ini_add(ini_file_cmistakes,'Setup','Accurate Pill/RGA','',ini_size_bool,@CMistakes.accurate);   
end; { Ini_Init_CMistakes }
 
procedure Ini_Init_Addon;
begin
   ini_add(ini_file_addon,'Addon','Unity','',ini_size_bool,@Addon.Unity);
   ini_add(ini_file_addon,'Addon','Starbase+','',ini_size_bool,@Addon.SB_Plus);
   ini_add(ini_file_addon,'Starbase+','MaxMoney','',ini_size_int,@Addon.SB_PlusMM); 
   ini_add(ini_file_addon,'Addon','Teleport','',ini_size_bool,@Addon.Teleport); 
end; { Ini_Init_Addon }


procedure MyMax;
{ BBU: MyMax gives hints to common player-mistakes like too low speed,
 ships flying in the warpwell with too high speed ...
 to be improved... }
const maxline=20;
      maxids=200;
var i,j,l,lo,los,lop,dplan,pn,nh,mline,tow,grav,
    use,eta,xx,yy,nx,ny,fc,fa, 
    Rt, Rd, Rm, Rcash, cln:integer;
    gr2,lWayX, lWayY,tm,rmt: long;
    p,p2:pptr;
    b:bptr;
    s,tows,chs:sptr;
    income:longint;
    dist:real;
    ids:array[1..maxids+2] of integer;
    clnerror: char;
    str : str20;
    c : byte;
begin
   NewMenu;
   UnLockReservedMemory(MenuSize(10,10,120,maxline,Yes));
   mline:=1;
	 gr2:=GravityRange*GravityRange;
   SetColor(White);
   if lship<>NIL then begin { show ships first }
      los:=1;
      lop:=2;
   end else begin { show planets first }
      lop:=1;
      los:=2;
   end;
   Addmenuitem('used Addons:', Green, No);
   ids[mline]:=-1; inc(mline);
   if (Addon.Unity) then AddMenuItem('Unity',Green,No) else AddMenuItem('No Unity',Red,No) ;
   ids[mline]:=-2; inc(mline);
   if (Addon.SB_Plus) then AddMenuItem('Starbase+',Green,No) else AddMenuItem('No Starbase+',Red,No) ;
   ids[mline]:=-2; inc(mline);
   if (Addon.Teleport) then AddMenuItem('Teleport',Green,No) else AddMenuItem('No Teleport',Red,No) ;
   ids[mline]:=-2; inc(mline);
   AddMenuItem('--------------',Green,No);
   ids[mline]:=-1; inc(mline);
   for lo:=1 to 2 do begin
      if (lo=lop) then begin
         rmt:=0;
         for l:=PlanetID(lplan)+1 to PlanetID(lplan)+NUM_PLANETS do begin
            if (l>NUM_PLANETS) then i:=l-NUM_PLANETS else i:=l;
            if (mline>=maxids) then break;
            p:=TTurn^.Data^.planet[i];
            if ((p<>NIL) and (p^.owner=player) and (p^.when=today)) then begin
               with p^ do begin
                  if ((not CMistakes.RMT_TMx) and (Addon.SB_Plus)) then begin
                      if (fcode='RMT') then begin
                                    {Starbase+ moneytransfer by Quapla
                                    Parameters: RMT Receive all money Lowest ID
                                    TM[1-5] Sendmoney *1000 (lower than setting)
                                    Base must have 20+ Techlevels}
                      b:=TTurn^.data^.base[i];
                      if (b=NIL) then begin
                        AddMenuItem('RMT-NoBase'+Nstr(i),Red,No);
                        ids[mline]:=i;
                        inc(mline);
                      end else if (b^.El+b^.Hl+b^.Wl+b^.Tl < 20) then begin 
                        AddMenuItem('RMT-LowTec'+Nstr(i),Red,No);
                        ids[mline]:=i;
                        inc(mline);
                      end else if (rmt>0) then begin
                        AddMenuItem('RMT-Skipd '+Nstr(i),Red,No);
                        ids[mline]:=i;
                        inc(mline);
                      end else begin                                        {Correct RMT Parameters}
                        AddMenuItem('RMT-GET$  '+Nstr(i),Green,No);
                        ids[mline]:=i;
                        inc(mline);
                        for j:=1 to NUM_Planets do begin
                          b:=TTurn^.data^.base[j];
                          if ((b<>NIL) and (b^.owner=player) and (b^.El+b^.Hl+b^.Wl+b^.Tl >= 20)) then begin
                            p2:=TTurn^.Data^.planet[j];
                            if (p2^.fcode='TM1') or (p2^.fcode='TM2') or (p2^.fcode='TM3') or
                               (p2^.fcode='TM4') or (p2^.fcode='TM5') then begin 
                              use:=minL(((ord(p2^.fcode[3])-ord('0'))*1000),p2^.funds);     {x*1000 or funds on planet}
                              if (use>addon.sb_plusmm) then use:= 0;                        {more than allowed -> 0 }
                              rmt:=rmt+use;                            
                            end;
                          end;
                        end;
                        if (rmt=0) then begin
                          AddMenuItem('->NoTransfer',Red,No);
                          ids[mline]:=i;
                          inc(mline);
                        end else begin
                          AddMenuItem('->Got '+Nstr(rmt)+'$',Green,No);
                          ids[mline]:=i;
                          inc(mline);
                        end;
                      end; 
                    end;

                    if (fcode='TM1') or (fcode='TM2') or (fcode='TM3') or
                       (fcode='TM4') or (fcode='TM5') then begin 
                      b:=TTurn^.data^.base[i];
                      if (b=NIL) then begin
                        AddMenuItem('TM-NoBase: '+Nstr(i),Red,No);
                        ids[mline]:=i;
                        inc(mline);
                      end else if (b^.El+b^.Hl+b^.Wl+b^.Tl < 20) then begin 
                        AddMenuItem('TM-LowTec: '+Nstr(i),Red,No);
                        ids[mline]:=i;
                        inc(mline);
                      end else begin                                        {Correct RMT Parameters}
                        use:=0;
                        for j:=1 to NUM_Planets do begin
                          b:=TTurn^.data^.base[j];
                          if ((b<>NIL) and (b^.owner=player) and (b^.El+b^.Hl+b^.Wl+b^.Tl >= 20) and
                             (TTurn^.Data^.planet[j]^.fcode='RMT') ) then begin
                            use:=minL(((ord(fcode[3])-ord('0'))*1000),funds);   {x*1000 or funds on planet}
                            if (use>addon.sb_plusmm) then use:= -1;             {more than allowed}
                            break;
                          end;
                        end;
                        if (use>0) then
                          AddMenuItem('TM- '+NStr(use)+'$:'+Nstr(i),Green,No)
                        else if (use=-1) then
                          AddMenuItem('TM- Max MM:'+Nstr(i),Red,No)
                        else
                          AddMenuItem('TM- No_RMT:'+Nstr(i),Red,No);
                        ids[mline]:=i;
                        inc(mline);                       
                      end;
                    end;                                                    { Ende Starbase+ RMT/TM checks }
                  end;
                  if ((not CMistakes.da_max) and (owner=6) and (Addon.Unity) and (fcode[1]='D') AND (fcode[2]='A') AND
                                                 (fcode[3] in ['1','2','3','4','5','6','7','8','9' ])) then begin
                      {Add-On Unity -> Planet-Code DA? -> 100*? Borg Clans will be disassempled into 50% Supplys Quapla}
                    if ((ord(fcode[3])-ord('0'))*100)>colonists then begin {all Clans disassembled}
                      AddMenuItem('P-DA_MAX:  '+Nstr(i),LightRed,No);
                      ids[mline]:=i;
                      inc(mline);
                    end;
                  end;
                  if ((not CMistakes.teleport) and (Addon.Teleport)) then begin
                    str:='';
                    j:=GetTeleportDataTX(i,c,use);
                    if j<0 then str:='B-No RX'
                    else begin
                      j:=GetTeleportDataRX(i,c,use);
                      if j<0 then str:='B-No TX';
                    end;
                    if str<>'' then begin                  
                      c:=Red;
                      AddMenuItem(str+fcode[3]+' :'+Nstr(i),c,No);
                      ids[mline]:=i;
                      inc(mline);
                    end;
                  end;
                  if ((not CMistakes.bovis) and (Nrace=2) and
                      (colonists<natives div 100)) then begin
                     AddMenuItem('P-Bovis:  '+Nstr(i),Green,No);
                     ids[mline]:=i;
                     inc(mline);
                  end;
                  if ((not CMistakes.detect) and (defense<15) and (colonists>=15) and
                      ((mines>=20) or (factories>=15))) then begin
                         AddMenuItem('P-Detect: '+Nstr(i),Yellow,No);
                         ids[mline]:=i;
                         inc(mline);
                      end;
                  nh:=Nstat+NHappyChange(i,CMistakes.accurate);		{Quapla Speed break!}
                  if ((not CMistakes.unhappy70) and (nh<70) and (NTax>0)) then begin
                     AddMenuItem('P-Unhappy:'+Nstr(i),Yellow,No);
                     ids[mline]:=i;
                     inc(mline);
                  end; 
                  income:=PlanetIncome(p,i,CMistakes.accurate); 	{Quapla Speed break!}
									if (not CMistakes.oneclan) or (colonists>1) then {CMistakes.oneclan TRUE calculation only done for mor than one clan}
                  if ((owner=player) and (when=turn) and (Nrace<>5) and (income<colonists) and
                     (income<MaxIncome) and(natives>0) ) then begin
                     if (nh>=100-HissHChange(i)) then begin
                               if (not CMistakes.nontax) then begin
                                  AddMenuItem('P-NoNTax :'+Nstr(i),Red,No);
                                  ids[mline]:=i;
                                  inc(mline);
                               end;
                      end else begin					
                               if (not CMistakes.lowntax) then begin 
                                AddMenuItem('P-LowNTax:'+Nstr(i),Yellow,No);
                                ids[mline]:=i;
                                inc(mline);
                               end;
                      end;                       
                  end;  
                  if ((not CMistakes.base) and (TTurn^.data^.base[i]=NIL)) and (build=0) then begin
                    if PlanetCanBuildBase(TTurn^.data^.planet[i]) then begin
                      AddMenuItem('P-BldBase:'+Nstr(i),Green,No);
                      ids[mline]:=i;
                      inc(mline);
                    end else 
                    if PlanetMayBuildBase(i) then begin
                        AddMenuItem('P-BldBase:'+Nstr(i),Yellow,No);
                        ids[mline]:=i;
                        inc(mline);
                    end;                  
                  end;
                  
                  if ((not CMistakes.build) and (TTurn^.data^.base[i]<>NIL)) then begin
                    with TTurn^.data^.base[i]^ do begin
                      if (cHl=0) and (cEl=0) and (cWl=0) and (cWn=0) and (cTl=0) and (cTn=0) and (cBn=0) then begin
                        AddMenuItem('B-No_Bld: '+Nstr(i),red,No);
                        ids[mline]:=i+2000;
                        inc(mline);
                      end;
                    end;
                  end;
               end; 
            end; 
         end;
      end; 
      if (lo=los) then begin
         cln := 0; {No Clone yet}
         for l:=ShipID(lship)+1 to ShipID(lship)+NUM_SHIPS do begin
            if (l>NUM_SHIPS) then i:=l-NUM_SHIPS else i:=l;
            if (mline>100) then break;
            s:=TTurn^.data^.ship[i];
            if ((s<>NIL)) then begin
               with s^ do begin 
               { Check Chunneling 24.2.2011 by Quapla 
               1. Checks if own ships can chunnel
               2. If yes, do they have a numeric FC? -> Write "Try Chunnel"
               3. "Chunnel from" Conditions not true -> Write "No Chunnel From"
               4. "Chunnel to" conditions not true   -> Write "No Chunnel to" }
          if ((not CMistakes.chkchun) and (owner=player) and (IsShipFunc3(s^,SPC_Chunneling,-1,-1)) )
          then begin
            Val(fcode,fc,fa);
            if (fa=0) and (fc>0) and (fc<=999) then begin
              AddMenuItem('S-Chunnel:'+NStr(i),Green,No);
              ids[mline]:=1000+i;
              inc(mline);
              if not ((warp=0) and (fuel>=50) and (damage<DamageLevelForChunnelFail) 
                and (UnderTow(i)=0)) then begin
                AddMenuItem('->NoStart:'+NStr(i),Red,No);
                ids[mline]:=1000+i;
                inc(mline);
              end;
              chs:=TTurn^.data^.ship[fc];
              if not ( (chs<>nil) and (chs^.warp=0) and (chs^.fuel>0) and
              ((owner=chs^.owner)or ((Phost)and(AllowAlliedChunneling)) )and
              (damage<DamageLevelForChunnelFail) and (IsShipFunc3(chs^,SPC_Chunneling,-1,-1))
              and (UnderTow(fc)=0) ) then begin
                AddMenuItem('->No End: '+NStr(fc),Red,No);
                ids[mline]:=1000+fc;
                inc(mline);
              end else if (Distance2(s^.x,s^.y,chs^.x,chs^.y)<MinimumChunnelDistance*MinimumChunnelDistance)
              then begin
                AddMenuItem('->LowDist:'+NStr(i),Red,No);
                ids[mline]:=1000+i;
                inc(mline);              
              end;
            end;
          end;
          { End check chunneluing }
                  if ((not CMistakes.btm0mc) and (owner=player) and
                      (fcode='btm') and (credits=0)) then begin
                     AddMenuItem('S-btm0MC: '+NStr(i),Yellow,No);
                     ids[mline]:=1000+i;
                     inc(mline);
                  end;
                  tow:=UnderTow(i);
                  if (tow>0) then tows:=TTurn^.data^.ship[tow] else tows:=NIL;
                  if ((not CMistakes.towwarn) and (s^.owner=player) and
                      (tow>0) and (warp>0)) then begin
                     AddMenuItem('S-TowWarn:'+Nstr(i),Yellow,No);
                     ids[mline]:=1000+i;
                     inc(mline);
                  end;
{ Do not know for what this is/was good....
                  p:=NIL;
                  if (tows=NIL) then tows:=s;
                  nx:=tows^.x+tows^.wx;
                  ny:=tows^.y+tows^.wy;
                  for j:=NUM_PLANETS downto 1 do begin
                     xx:=TTurn^.data^.xyplan[j,1];
                     yy:=TTurn^.data^.xyplan[j,2];
                     gr2:=GravityRange*GravityRange;
                     if (RoundWells and (Distance2(nx,nx,xx,yy)<=gr2)) or
                        ((not RoundWells) and (Abs(nx-xx)<=GravityRange) and
                        (Abs(ny-yy)<=GravityRange)) then begin
                           p:=TTurn^.data^.planet[j];
                           break;
                     end;
                  end;
}
                  pn:=PSearchXY(x,y);
                  lWayX := abs(wx);
                  lWayY := abs(wy);
                  if ((not CMistakes.inwarp) and (s^.owner=player) and
                      (pn<>0) and (warp>1) and ((wx<>0) or (wy<>0)) and (tow=0)) then begin
                    if ((RoundWells and (Sqr(lWayX)+ Sqr(lWayY)<= gr2))
                        or ((not RoundWells) and (lWayX <= GravityRange) and (lWayY <= GravityRange)))
                    then begin
                         AddMenuItem('S-InWarp :'+Nstr(i),Yellow,No);
                         ids[mline]:=1000+i;
                         inc(mline);
                      end;
                    end;
                  dist:=Distance(0,0,wx,wy);
                  if (IsShipFunc(s^,hfGravitonic)) then grav:=2 else grav:=1;
                  if ((not CMistakes.tooslow) and (s^.owner=player) and
                      (warp>0) and (dist<81*grav+1) and
                      (dist>warp*warp*grav) and (tow=0)) then begin
                         AddMenuItem('S-TooSlow:'+Nstr(i),Yellow,No);
                         ids[mline]:=1000+i;
                         inc(mline);
                         {       OutTextXY(300,line*8,NStr(wx*wx+wy*wy)); }
                      end;
                  if ((not CMistakes.hypwarn) and (IsShipFunc(s^,hfHyperDrive))) then begin
                    if (dist>=340) and (dist<=360) and ((fuel<50) or (fcode<>'HYP')) then begin
                      AddMenuItem('S-HYPFuel:'+Nstr(i),Yellow,No);
                      ids[mline]:=1000+i;
                      inc(mline);
                    end else if ((dist<340) or (dist>360)) and (fuel>50) and (fcode='HYP') then begin
                      AddMenuItem('S-HYPDist:'+Nstr(i),Yellow,No);
                      ids[mline]:=1000+i;
                      inc(mline);
                    end;
                  end;
                     
                  if ((not CMistakes.ahpwarn) and (IsShipFunc(s^,hfHyperDrive)) and Addon.Unity) then begin
                    if (dist>=690) and (dist<=710) and ((fuel<60) or (fcode<>'AHP')) then begin
                      AddMenuItem('S-AHPFuel:'+Nstr(i),Yellow,No);
                      ids[mline]:=1000+i;
                      inc(mline);
                    end else if ((dist<690) or (dist>710)) and (fuel>60) and (fcode='AHP') then begin
                      AddMenuItem('S-AHPDist:'+Nstr(i),Yellow,No);
                      ids[mline]:=1000+i;
                      inc(mline);
                    end;
                  end;

                  if ((not CMistakes.lowfuel) and (owner=player) and (warp>0)) then begin
                     CalcMovement(s,StdTowPtr(s^),use,eta);
                     if (use>fuel) then begin
                        AddMenuItem('S-LowFuel:'+Nstr(i),Yellow,No);
                        ids[mline]:=1000+i;
                        inc(mline);
                     end;
                  end;
                  
                  if ((not CMistakes.chkmines) and (owner=player) and (fcode='msc')) then begin
                    if ((mission <> 2) or (fuel=0)) then begin
                        AddMenuItem('S-NoSweep:'+Nstr(i),Red,No);
                        ids[mline]:=1000+i;
                        inc(mline);
                    end;
                  end; 
                  if ((not CMistakes.chkmines) and (owner=player) and ( (fcode[1]='m') and (fcode[2]='d') and 
                            (fcode[3] in ['0', '1','2','3','4','5','6','7','8','9','h','q']) or 
                            ( (fcode[1]='m') and (fcode[2]='i') and 
                            (fcode[3] in ['1','2','3','4','5','6','7','8','9','a','b']))) ) then begin
                    if ( (mission<>3) or ( (Race[realshipowner(i)]=7) and not (mission in [9,ExtMissionsStartAt+11]))
                            or (fuel=0) ) then begin
                        AddMenuItem('S-NoLayM.:'+Nstr(i),Red,No);
                        ids[mline]:=1000+i;
                        inc(mline);
                    end;
                  end; 
              { Check Clone }
               if ((not CMistakes.clone) and (owner=player) and (fcode='cln')) then begin
                pn:=PSearchXY(x,y);
                clnerror := ' ';
                if (pn<>0) then begin
                 p:=TTurn^.Data^.planet[pn];
                 b:=TTurn^.Data^.base[pn]; 
                 if ((b<>NIL) and (p<>NIL)) then {Planet und Base da?}
                 if (b^.owner=player) and (not OwnShipDesign(p^.owner,hull)) then begin
                  {check if cloning is possible} 
                  Rt:=0;
                  Rd:=0;
                  Rm:=0;
                  Rcash:=0; 
                  if (weapons>0) then begin
                    inc(Rt,weapons*Beams[Wl].T);
                    inc(Rd,weapons*Beams[Wl].D);
                    inc(Rm,weapons*Beams[Wl].M);
                    inc(Rcash,weapons*Beams[Wl].cost);
                  end;
                  if (launchers>0) then begin
                    inc(Rt,launchers*Torps[Tl].T);
                    inc(Rd,launchers*Torps[Tl].D);
                    inc(Rm,launchers*Torps[Tl].M);
                    inc(Rcash,launchers*Torps[Tl].cost);
                  end; 
                  {engines minerals}
                  inc(Rt,Hulls[hull].engines*Engines[El].T);
                  inc(Rd,Hulls[hull].engines*Engines[El].D);
                  inc(Rm,Hulls[hull].engines*Engines[El].M);
                  inc(Rcash,Hulls[hull].engines*Engines[El].cost);
                  {hull minerals} 
                  inc(Rt,Hulls[hull].T);
                  inc(Rd,Hulls[hull].D);
                  inc(Rm,Hulls[hull].M);
                  inc(Rcash,Hulls[hull].cost);
                  Rcash := round((CloneCost[b^.owner]/100.0)*Rcash);
                  {check tech levels} 
                  if (Hulls[hull].tech<=b^.Hl) and (Engines[El].tech<=b^.El) and
                     ((Torps[Tl].tech<=b^.Tl) or (launchers=0)) and
                     ((Beams[Wl].tech<=b^.Wl)or (weapons=0)) then begin
                      if (p^.T<Rt) or (p^.D<Rd) or (p^.M<Rm) then clnerror:='M' {No Clone: Not enough Minerals}
                      else if (p^.funds<Rcash) then clnerror:='$' {No Clone: Not enough Cash}
                      else if (warp > 0) then clnerror:='W' {No Clone: Not Warp 0}
                      else if (b^.cHl+b^.cEl+b^.cWl+b^.cWn+b^.cTl+b^.cTn)>0 then clnerror:='S' {No Clone: Building Ship}
                      else if (cln > 0) then begin {already clone}
                        inc(cln);
                        clnerror:='-'; {No Clone: Not first Ship to clone}
                      end else clnerror:='!'; {Clone done}
                     end else clnerror:='L'; {No Clone: Low Tec-Level}
                    end else clnerror:='B'; {No Clone: No/Wrong Base}
                  end else clnerror:='P'; {No Clone: Not over Planet}
                  if (clnerror <> ' ') then begin
                    if (clnerror = '!') then begin
                      AddMenuItem('S-CloneOK:'+Nstr(i),Green,No);
                      ids[mline]:=1000+i;
                      inc(mline);
                    end else begin
                      AddMenuItem('S-NoCln_'+clnerror+':'+Nstr(i),Red,No);
                      ids[mline]:=1000+i;
                      inc(mline); 
                    end; 
                  end;
               end; 
               
               if (IsShipFunc(s^,hfGloryDeviceH) or IsShipFunc(s^,hfGloryDeviceL)
               and not GloryDevice) then begin
                if (not CMistakes.pop) and (fcode='pop') then begin
                  AddMenuItem('S-GlryPOP:'+Nstr(i),yellow,No);
                  ids[mline]:=1000+i;
                  inc(mline);
                end;
                if (not CMistakes.trg) and (fcode='trg') then begin
                  if ((enemy<>player) and (enemy<>0)) 
                  or ((mission=4) and (fuel>0)) then  begin
                    AddMenuItem('S-GlryTRG:'+Nstr(i),Green,No);
                    ids[mline]:=1000+i;
                    inc(mline);
                  end else begin
                    AddMenuItem('S-GlryTRG:'+Nstr(i),red,No);
                    ids[mline]:=1000+i;
                    inc(mline);
                  end;
                end;
              end;
{ The following needs GetRCOwner and is only usefull in team-games: 
                  if ((p<>NIL) and (p^.CTax>=0) and (s^.T>=0)) then begin
                   if ((s^.owner=player) and (realshipowner(i)=p^.owner) and
                   (newshipcontroler(i)<>p^.owner)) then begin
                   AddMenuItem('S-ReDrop :'+Nstr(i),Yellow,No);
                   ids[mline]:=1000+i;
                   inc(mline);
                   end;
                   if ((p^.owner=player) and (realshipowner(i)<>player) and
                   (newshipcontroler(i)<>player)) then begin
                   AddMenuItem('S-ReContr:'+Nstr(i),Yellow,No);
                   ids[mline]:=1000+i;
                   inc(mline);
                   end;
                   end;
}
               end; 
            end; 
         end; 
      end;
   end;
   AddMenuItem('--------------',Green,No);
   AddMenuItem('Configure',Green,No);
   ids[mline]:=0;
   ids[mline+1]:=0;
   ChooseMenu(10,10,10,120,maxline,White,Yellow,1,No,Yes,14);
   NewMenu;
   LockReservedMemory;
   If (MenuKey<>27) then begin
      i:=ids[MenuValue];
      if (i=0) then ini_showmenu(ini_file_cmistakes,true);
      if (i=-2) then ini_showmenu(ini_file_addon,true);
      if ((i>0) and (i<1000)) then begin
         force:=i or LockP;
         ForceKey:=13;
         lbase:=NIL;
      end;
      if ((i>1000) and (i<2000)) then begin
         force:=(i-1000) or LockS;
         ForceKey:=13;
         lbase:=NIL;
      end;
      if ((i>2000) and (i<3000)) then begin
         force:=(i-2000) or LockP;
         ForceKey:=13;
         lbase:=TTurn^.data^.base[i-2000];
      end;
   end;
end;

procedure PlanetInfo;
  var   s       : string[18];
        s1      : string[8];
        p       : pptr;
        ep      : EPln;
        l       : long;
        i,t0,t1 : int;
        number  : word;
        c       : byte;
        newpln  : byte;
{$IFDEF TASKS}
        tsk     : taskptr;
{$ENDIF}
{$IFDEF VPACC}
        phc     : PPhostCommand;
{$ENDIF}
  begin
    if ltype<>LockP then Exit;
    number:=lock and LockLo;
    if (number=0) or (number>500) then Exit;
    with TTurn^.data^ do
    begin
      p:=planet[number];
      ep:=eplan[number];
      newpln:=newplan[number];
    end;
    Clear(MX0,72,639,358);
    if ((actlist[number] and LockP)<>LockP) or (turn<>today)  then SetColor(cActive)
                                                              else SetColor(cNonActive);
    i := PlanetExperience(number);
    if i >= 0 then s := ' (L' + NStr0(i) + ')' else s := '';
    OutTextXY(MX0,72,'Planet '+NStr(number) + s);    
    OutTextXY(MX0,80,PlanName[number]);
    SetColor(LightGray);
    if (p=nil) and (ep.activity=0) then OutTextXY(MX0,104,'(No data)') else
    if p=nil then
    begin
      if ep.when=turn then s:='now'
                      else s:=NStr(turn-ep.when)+Proper(turn-ep.when,' turn')+' ago';
      OutTextXY(MX0,88,'('+s+')');
      SetColor(IIF(ep.when=turn,cPInfo,cOPInfo));
      if ep.owner<>0 then OutTextXY(MX0,104,'Race: '+RaceName[ep.owner]);
      WriteActivity(ep);
    end
    else with p^ do
    begin
      lplan:=p;
      i:=Max(when,ep.when);
      t0:=when0;
      if (ep.when<>0) and (ep.when<when0) then t0:=ep.when;
      if i=turn then s:='now' else s:=NStr(turn-i);
      s:='('+s;
      if t0<>i then s:=s+' - '+NStr(turn-t0)+' trn ago'
      else if t0<>turn then s:=s+Proper(turn-t0,' turn')+' ago';
      s:=s+')';
      OutTextXY(MX0,88,s);
      LastBuilt(number);
      if (when=turn) and (when=when0) then
      begin
        c:=cPInfo;
        newpln:=newpln or ($FF-NP_Base);
      end
      else c:=cOPInfo;
      if owner<>-1 then
      begin
        SetColor(IIF(newpln and NP_Owner=0,cOPInfo,cPInfo));
        OutTextXY(MX0,104,'Race: '+RaceName[IIF(ep.owner<>0,ep.owner,owner)]);
      end;
      if fcode<>#$FF#$FF#$FF then
      begin
        i:=IIF(newpln and NP_MFD_FCode=0,cOPInfo,cPInfo);
        SetColor(i);
        OutTextXY(MX0,112,'FCode:');
        WriteFCode(MX0+7*8,112,i,fcode);
      end;
      if climate<>-1 then
      begin
        SetColor(IIF(newpln and NP_Climate=0,cOPInfo,cPInfo));
        OutTextXY(MX0,128,'Climate: '+ClimStr[ClimateType(climate)]+' '+NStrMax(100-climate,2,'+'));
      end;
      if Nrace<>-1 then
      begin
        SetColor(IIF(newpln and NP_NRace_NPop=0,cOPInfo,cPInfo));
        if Nrace<>0 then
        begin
          OutTextXY(MX0,136,'Natives:');
          OutTextXY(MX0,144,' '+NatRace[Nrace]);
          l:=8; if ShowMaxPop then l:=0;
          if natives<>-1 then begin
            OutTextXY(MX0+8,152+l,'Pop. : '+NStr(natives)+'00');
            MakeNumDots(MX0+8*8,152+l,Green,natives*100);
          end;
          SetColor(c);
          if Ngovt<>-1 then begin
            if ShowMaxPop then OutTextXY(MX0+12*8,144,'G:'+NatGRate[Ngovt])
            else OutTextXY(MX0,152,' '+NatGovt[Ngovt])
          end;
          WriteHChange(Yes);
          if Ntax<>-1 then WriteTaxes(Ntax,160+l);
          if (Nstat<>-1) or (Ntax<>-1) then
          begin
            SetColor(IIF(Nstat>=70,c,IIF(Nstat<30,LightRed,Yellow)));
            OutTextXY(MX0,168+l,' Happy: '+NStr0(Nstat)+'%');
          end;
        end
        else OutTextXY(MX0,144,'(no native life)');
      end;
      if (ep.owner<>0) and (ep.owner<>owner) and (ep.when>=when) then WriteActivity(ep)
      else begin
        if colonists<>-1 then
        begin
          SetColor(IIF(newpln and NP_CPop=0,cOPInfo,cPInfo));
          if owner<>0 then begin
            OutTextXY(MX0,184,'Colonists:');
            if colonists<>-1 then begin
              s:=NStr(colonists);
              OutTextXY(MX0+8,192,'Pop. : '+s);
              SetColor(Green);
              OutTextXY(MX0+(8+length(s))*8,192,'00');
              MakeNumDots(MX0+8*8,192,Green,colonists*100);
            end;
            SetColor(c);
            WriteHChange(No);
            if Ctax<>-1 then WriteTaxes(Ctax,200);
          end
          else OutTextXY(MX0,200,'Colonists: None');
        end;
        { BBU: TODO improve formulas }
        if ShowMaxPop then WriteMaxPop(-1,0);
        if Cstat<>-1 then
        begin
          SetColor(IIF(Cstat>=70,c,IIF(Cstat<30,LightRed,Yellow)));
          s:='Happy: '+NStr0(Cstat)+'%'; if owner=0 then s:='('+s+')';
          OutTextXY(MX0+8,208,s);
        end;
        if (colonists<>-1) and (mines and factories and defense<>-1) then
        begin
          i:=IIF(newpln and NP_MFD_FCode=0,cOPInfo,cPInfo);
          SetColor(i);
          if mines<>-1 then
          begin
            l:=MaxPlanetStruct(p,200);
            Str(mines:3,s); Str(l,s1);
            OutTextXY(MX0,224,'Mines    :    /'+s1);
            if mines>l then SetColor(Red);
            OutTextXY(MX0+11*8,224,s);
            SetColor(i);
          end;
          if factories<>-1 then
          begin
            l:=MaxPlanetStruct(p,100);
            Str(factories:3,s); Str(l,s1);
            OutTextXY(MX0,232,'Factories:    /'+s1);
            if factories>l then SetColor(Red);
            OutTextXY(MX0+11*8,232,s);
            SetColor(i);
          end;
          if defense<>-1 then
          begin
            l:=MaxPlanetStruct(p,50);
            Str(defense:3,s); Str(l,s1);
            OutTextXY(MX0,240,'Defense  :    /'+s1);
            if defense>l then SetColor(Red);
            OutTextXY(MX0+11*8,240,s);
            SetColor(i);
          end;
        end
        else WriteActivity(ep);
        WritePlanCombatStrength(number);
        SetColor(i);
        if supplies<>-1 then
        begin
          SetColor(IIF(newpln and NP_Supplies=0,cOPInfo,cPInfo));
          {SetColor(c);}
          OutTextXY(MX0,256,'Supplies: '+NStr0(supplies));
        end;
        if funds<>-1 then
        begin
          SetColor(IIF(newpln and NP_NTDM_Funds=0,cOPInfo,cPInfo));
          OutTextXY(MX0,264,'Funds   : '+NStr0(funds));
        end;
        WriteIncome(number);
      end;
      if addon.teleport then begin
        SetColor(LightMagenta);
        t0 := number;
        i := GetTeleportDataTX(t0,c,t1);
        if i>0 then begin 
          OutTextXY(MX0,280,'TP: '+Nstr0(t1)+TPFcode[c]+' -> #'+Nstr(i));
          SetColor(white); OutTextXY(MX0+8,280,'P');
        end else begin
          i := GetTeleportDataRX(t0,c,t1);
          if i>0 then begin 
            OutTextXY(MX0,280,'TP: '+Nstr0(t1)+TPFcode[c]+' <- '+Nstr(i)+'^');
            SetColor(white); OutTextXY(MX0+8,280,'P');
          end else 
          if(TTurn^.data^.base[number]<>NIL) or (TTurn^.data^.planet[number]^.build=1) then begin
            OutTextXY(MX0,280,'No TX/RX Teleport');         
            SetColor(white); OutTextXY(MX0+13*8,280,'p');
          end;
        end;
      end;
      
      if N and T and D and M<>-1 then
      begin
        SetColor(IIF(newpln and NP_NTDM_Funds=0,cOPInfo,cPInfo));
        OutTextXY(MX0,288,'Minerals: ');
        SetLineStyle(SolidLn,0,NormWidth);
        i:=IIF(Nm and Tm and Dm and Mm<>-1,639,MX0+12*8);
        Line(MX0+2*8,306,i,306);
        Line(MX0+2*8,316,i,316);
        Line(MX0+2*8,326,i,326);
        Line(MX0+2*8,336,i,336);
        Line(MX0+2*8,346,i,346);
        Line(MX0+2*8,307,MX0+2*8,345);
        Line(MX0+12*8,307,MX0+12*8,345);
        if (Nc and Tc and Dc and Mc<>-1) then
        begin
          Line(MX0+7*8,307,MX0+7*8,345);
          OutTextXY(MX0,298,'   Surf Core  Extr');
        end
        else begin
          if i=639 then s:='  Ext' else s:='';
          OutTextXY(MX0,298,'   Surf+Core'+s);
        end;
        WriteMineral($654E,308,N,Nc,Nm);
        WriteMineral($7254,318,T,Tc,Tm);
        WriteMineral($7544,328,D,Dc,Dm);
        WriteMineral($6F4D,338,M,Mc,Mm);
      end;
      if build=1 then
      begin
        SetColor(Yellow);
        OutTextXY(MX0,351,'BUILDING S-BASE');
      end;
      SetColor(White);
      if (Nrace>0) and (Ngovt<>-1) and (natives<>-1) and (climate<>-1) then
        OutTextXY(MX0+8,160+IIF(ShowMaxPop,0,8),'T');
      if RWMode and (turn=today) and (when=today) and (distlock=0) and (owner=player) then
      begin
        OutTextXY(MX0,112,'F');
        OutTextXY(MX0+24,200,'x');
        OutTextXY(MX0,224,'M');
        OutTextXY(MX0+8,232,'a');
        OutTextXY(MX0,240,'D');
        OutTextXY(MX0,256,'S');
        if build=1 then begin 
          OutTextXY(MX0,351,'B'); 
          OutTextXY(MX0+17*8,351,'N');
        end;
        if (ep.activity and EP_Base=0) and (build=0) then
        if PlanetCanBuildBase(p) then begin
          OutTextXY(MX0,351,'B');
          SetColor(cPInfo);
          OutTextXY(MX0+8,351,'uild Starbase');
        end else if PlanetMayBuildBase(number) then begin
          SetColor(cPInfo);
          OutTextXY(MX0,351,'May build Starbase');
        end;
{$IFDEF TASKS}        
        tsk:=FindTask(lock);
        if tsk<>nil then
        begin
          SetColor(LightGray);
          OutTextXY(640-4*8,72,'<  >');
          if tsk^.flag and tfDeac=0 then SetColor(White);
          OutTextXY(640-3*8,72,'F8');
        end;
{$ENDIF}
      end;
      {Display status of object on the act-list.}
      if ((actlist[number] and LockP) = LockP) and ShowCheckMark then begin
        DrawCheckMark( 623, 72, CheckMarkColor);
        {SetColor(CheckMarkColor); OutTextXY(623,72,CheckMarkChar);}
      end
    end;
    lbase:=nil;
    ObjList;
    if (ep.owner<>0) and (ep.owner<>player) and (not IsData[ep.owner]) and
       (ep.activity and EP_NoBase<>0) then
    begin
      SetColor(IIF(newpln and NP_Base=0,cOPInfo,cPInfo));
      OutTextXY(640-9*8,ListY,'<No Base>');
    end;
    {$IFDEF VPACC}
    { this re-uses the place where VPA usually says '<Planet>'. When
      we are at a planet, there's no point in going to one :-) }
    if (turn=today) and PHOST and EnableGive and (p<>nil) and (p^.owner=player) then
    begin
      phc := GetPHostCmd(phc_GivePlanet, number);
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
    ExtFeatInfoDisplayHook;
  end;

procedure BaseStorage;
  type  str18   = string[18];
  var   s       : string[7];
        l,l0    : word;
        i,j     : byte;
        sl0     : int;
        myrace  : int;
  procedure Say (s:str18);
    begin
      if (l>=BL0) and (l<=BL0+BL2-BL1) then
      begin
        OutTextXY(MX0,BL1+l-BL0,s);
        sl0:=0;
      end
      else if l>BL0+BL2-BL1 then bOver:=Yes;
      inc(l,8);
    end;
  procedure SLine;
    begin
      if (l<>l0) and (l>=BL0+8) and (l<=BL0-BL1+BL2+8) then
      begin
        sl0:=BL1+l-BL0+3;
        Line(MX0,sl0,639,sl0);
      end;
      inc(l,8); l0:=l;
    end;
  begin
    Clear(MX0,BL1,639,BL2+15);
    bOver:=No;
    sl0:=0;
    with lbase^ do
    begin
      if TrueHullByRace then myrace:=Race[owner]
                        else myrace:=owner;
      l:=BL1; l0:=BL1;
      s:='';
      for i:=1 to 20 do
        for j:=1 to HH[i] do
        begin
          if (cHl=i) and (s='') then
            begin SetColor(Yellow); s:='1' end
          else SetColor(cBInfo);
          Say(Hulls[RaceHull[myrace,i]].name);
        end;
      SetColor(cBInfo);
      SLine;
      for i:=1 to 9 do
        if EE[i]<>0 then
        begin
          SetColor(IIF(cEl=i,Yellow,cBInfo));
          Say(NStr(EE[i])+' '+Proper(EE[i],Engines[i].name));
        end;
      SetColor(cBInfo);
      SLine;
      for i:=1 to 10 do
        if WW[i]<>0 then
        begin
          SetColor(IIF(cWl=i,Yellow,cBInfo));
          Say(NStr(WW[i])+' '+Proper(WW[i],Beams[i].name));
        end;
      SetColor(cBInfo);
      SLine;
      for i:=1 to 10 do
        if LL[i]<>0 then
        begin
          SetColor(IIF(cTl=i,Yellow,cBInfo));
          Say(NStr(LL[i])+' '+Proper(LL[i],Torps[i].name+' launcher'));
        end;
      SetColor(cBInfo);
      SLine;
      for i:=1 to 10 do
        if TT[i]<>0 then Say(NStr(TT[i])+' '+Proper(LL[i],Torps[i].name+' torpedo'));
      SLine;
    end;
    if sl0<>0 then
    begin
      SetColor(Black);
      Line(MX0,sl0,639,sl0);
    end;
    SetColor(cBInfo);
    l:=BL0-BL1+BL2+8; l0:=0; SLine;
    SetColor(White);
    if BL0>BL1 then OutTextXY(MX0,BL2+8,'Home');
    if bOver   then OutTextXY(640-3*8,BL2+8,'End');
  end;

procedure LastBuilt(var id:word);
var i, lap : int;
    built : string[2];
begin
      i:=BuildQ(0);
      if (i<>0) then begin               {Data found...}
        if (i=id) then begin
          SetColor(Green); built[2]:='L'; 
         end else built[2]:=' ';
        if (BuildQ(id)>0) then built[1]:='B'
        else built[1]:=' ';
        lap := 1;
        repeat
          inc(i);
          if i>500 then begin i:=1; inc(lap); end;
          if (lap=3) then i:=0;        { No base at all }
        until (TTurn^.data^.base[i]<>NIL) or (i=0);
        if (i=id) then begin SetColor(LightRed); built[2]:='N'; end;      
        OutTextXY(MX0+16*8,88,built); {Quapla Last Base built}
      end;
end;
procedure BaseInfo;
  var   l       : int;
        number  : word;
        hull_nr : int;
        myrace  : int;
        ue      : PUtil39QueueEntry;
        no_c    : boolean;
  begin
    if ltype<>LockP then Exit;
    number:=lock and LockLo;
    if (number=0) or (number>500) then Exit;
    lplan:=TTurn^.data^.planet[number];
    lbase:=TTurn^.data^.base[number];
    if lbase=nil then Exit;
    Clear(MX0,72,639,358);
    if ((actlist[number] and LockB)<>LockB) or (turn<>today)  then SetColor(cActive)
                                                              else SetColor(cNonActive);
    OutTextXY(MX0,72,'Starbase '+NStr(number));
    OutTextXY(MX0,80,PlanName[number]);
    BL0:=BL1;
    with lbase^ do
    begin
      SetColor(cBInfo);
      OutTextXY(MX0,96,'Defense:  '+NStr0(defense));
      OutTextXY(MX0,104,'Damage:');
      if damage>0 then
      begin
        SetColor(LightRed);
        OutTextXY(MX0+10*8,104,NStr(damage)+'%');
        SetColor(cBInfo);
      end;
      OutTextXY(MX0,112,'Fighters: '+NStr(fighters));
      OutTextXY(MX0,120,'Primary order:');
      OutTextXY(MX0,128,' '+BaseOrd[order]);
      OutTextXY(MX0,144,'Tech. levels:');
      OutTextXY(MX0,152,' Engines     '+NStr(El));
      OutTextXY(MX0,160,' Hulls       '+NStr(Hl));
      OutTextXY(MX0,168,' Weapons     '+NStr(Wl));
      OutTextXY(MX0,176,' Torpedoes   '+NStr(Tl));
      OutTextXY(MX0,192,'Base storage:');
      SetLineStyle(SolidLn,0,NormWidth);
      Line(MX0,203,639,203);
      BaseStorage;
      LastBuilt(number);
      l:=CheckClone(number);
      SetColor(Yellow);
      if cHl<>0 then OutTextXY(MX0,BL2+16,'BUILDING SHIP')
      else if l>0 then OutTextXY(MX0+6*8,BL2+16,'CLONING');
      if fOp<>0 then
      begin
        if fOp=1 then OutTextXY(MX0,BL2+32,'FIXING Ship '+NStr0(fShip));
        if fOp=2 then OutTextXY(MX0,BL2+32,'RECYCLING '+NStr0(fShip));
      end;
      no_c := false;
{$IFDEF VPACC}
      if (turn=today) and (distlock=0) then begin
        if TrueHullByRace then myrace:=Race[owner] else myrace:=owner;
        if l>0    then hull_nr := TTurn^.data^.ship[l]^.hull else
        if cHl<>0 then hull_nr := RaceHull[myrace, cHl] else
         hull_nr := 0;
        ue := GetQueueEntry(number);
        if (ue<>nil) and (hull_nr<>0) then begin
          if hull_nr<>ue^.hull then SetColor(Red) else SetColor(Green);
          SetTextJustify(RightText, TopText);
          OutTextXY(MX0 + 144, BL2 + 16, '@' + NStr(ue^.qpos));
          SetTextJustify(LeftText, TopText);
          no_c := true;
        end;
      end;
{$ENDIF}
      if RWMode and (turn=today) and (distlock=0) then
      begin
        SetColor(White);
        OutTextXY(MX0,96,'D');
        OutTextXY(MX0+8*8,120,'o');
        OutTextXY(MX0,144,'T');
        OutTextXY(MX0,BL2+16,'B');
        if (cHl=0) and (l<=0) then
        begin
          SetColor(cBInfo);
          OutTextXY(MX0+8,BL2+16,'uild ship');
        end;
        if l>=0 then
          if cHl<>0 then
          begin
            SetColor(White);
            if not no_c then OutTextXY(632,BL2+16,'C');
          end else
          if l=0 then
          begin
            SetColor(cBInfo);
            OutTextXY(MX0+13*8,BL2+16,'Clone');
            SetColor(White);
            OutTextXY(MX0+13*8,BL2+16,'C');
          end
          else begin
            SetColor(White);
            OutTextXY(MX0+6*8,BL2+16,'C');
          end;
        SetColor(cBInfo);
        OutTextXY(MX0,BL2+24,'Buy torps/fighters');
        SetColor(White);
        OutTextXY(MX0+2*8,BL2+24,'y');
        if fOp=0 then
        begin
          SetColor(cBInfo);
          OutTextXY(MX0,BL2+32,'Fix ship   Recycle');
          SetColor(White);
          OutTextXY(MX0,BL2+32,'F          R');
        end
        else if fOp<>2 then OutTextXY(MX0,BL2+32,'F                R')
                       else OutTextXY(MX0,BL2+32,'R                F');
        {Display status of object on the act-list.}
        if ((actlist[number] and LockB) = LockB) and ShowCheckMark then begin
          DrawCheckMark( 623, 72, CheckMarkColor);
          {SetColor(CheckMarkColor); OutTextXY(623,72,CheckMarkChar);}
        end;
      end;
    end;
    ObjList;
    ExtFeatInfoDisplayHook;
  end;

function DoChooseNumber(x,y,len,arrow: long; yes_no : Boolean; min_,max_,initnumber : long):long;
{
   line - number of digits to underline
}
var
        c       : byte;
        what,k  : long;
        s       : string[16];
procedure PutNum;
var
        s       : string[16];
begin
        Clear(x,y,x+len*8-1,y+7);
        SetColor(c);
        Str(what,s);
        OutTextXY(x,y,s);
end;

procedure BuildStruct(i: long);
begin
        inc(what,i);
        what:=maxL(minL(what,max_),min_);
end;

begin
        c       := LightGreen;
        what    := initnumber;

        repeat
                PutNum;
                SetColor(Yellow);
                Line(x,y+7,x+len*8-1,y+7);
                if (yes_no) then Clear(x+arrow*8,y,x+arrow*8+16-1,y+8);
                repeat ArrowBlink(x+arrow*8,y) until KeyPressed;
                SetColor(Black);
                Line(x,y+7,x+len*8-1,y+7);
                ch:=ReadKey;
                case ch of
                $4B00   : BuildStruct(-1);
                $4D00   : BuildStruct(1);
                $7300   : BuildStruct(-10);
                $7400   : BuildStruct(10);
                $9B00   : BuildStruct(-100);
                $9D00   : BuildStruct(100);
                ord('0')..ord('9')      : begin
                        GetStr1stKey:=ch;
                        s:=GetStr(x,y,len);
                        if GetStrKey=13 then
                          begin
                                k:=Value(s);
                                BuildStruct(k-what);
                          end;
                        end;
                $3B00   : begin
                          what := -999; {Exit Identifier for Help in Function}
                        end; 
(*                $4800   : begin
                          what := -991; {Exit Identifier for UP in Function}
                        end; 
                $5000   : begin
                          what := -992; {Exit Identifier for DOWN in Function}
                        end; Undone yet... *)
                        
                end;
        until (ch=13) or (ch=27) or (what=-999);
        DoChooseNumber := what;
  end;
  
  
  
Procedure MyCalc;
var i,ls  :int;
    s,s2  :str40;
    cur   :boolean;
    t0    :long;

procedure DrawCursor(x,y:int);
    begin
      SetWriteMode(XORPut);
      SetColor(White);
      Line(x,y+8,x+7,y+8);
      SetWriteMode(NormalPut);
      cur:=not cur;
    end;
  
  
function MyGetNum(xa,ya:int):string;
 var mych:string[14];
     mynum, var1, var2:word;
     op,forced:char;
     dy,dx:integer;
     
 BEGIN
 dy:=40;
 dx:=150;
 mych:=''; mynum:=0; op:=chr(0); forced:=char(0); var1:=0; var2:=0; ls:=0;
 {s:=Getstr(xa,ya,dx);
 writeln(s);}
 repeat
  cur:=Off; t0:=Timer;
  while not KeyPressed do
   if Timer>t0+1 then begin DrawCursor(xa+ls*8,ya); t0:=Timer end;
   if cur then DrawCursor(xa+ls*8,ya);
  
    ch:=readkey;
    case chr(ch) of
        '0'..'9'    :begin
                      mych:=mych+chr(ch);
                      mynum:=mynum*10+(ch-ord('0'));
                      bar(xa,ya,xa+dx,ya+dy);
                      outtextxy(xa,ya,mych);
                      inc(ls);
                    end;
{backspace} #8      :begin
                      mych:=copy(mych,1,length(mych)-1);
                      if mynum>0 then mynum:=mynum div 10 else begin
						op:=chr(0);
						mynum:=var1;
						end;
                      bar(xa,ya,xa+dx,ya+dy);
                      outtextxy(xa,ya,mych);
                      dec(ls);
                    end;
        '+','-','*','/'         :begin
                    if (op=chr(0)) then begin
                      mych:=mych+chr(ch);
                      var1:=mynum; mynum:=0; op:=chr(ch); 
                      bar(xa,ya,xa+dx,ya+dy);
                      outtextxy(xa,ya,mych);
                      inc(ls);
                      end;
                    end;
        chr(13),'=','s'                :begin
                    if chr(ch)='s' then op:='s';
                    if (op<>chr(0)) then begin
                      case op of
                      '+'   :var2:=var1+mynum;
                      '-'   :var2:=var1-mynum;
                      '*'   :var2:=var1*mynum;
                      '/'   :var2:=var1 div mynum;
                      's'   :var2:=round(sqrt(mynum));
                      end; 
                      bar(xa,ya,xa+dx,ya+dy);
                      if op='s' then OutTextXY(xa,ya+16,'sqrt('+NStr0(mynum)+') = '+NStr0(var2))
                      else begin
						OutTextXY(xa+16,ya+16,NStr0(var1));
						OutTextXY(xa,ya+24,op+' '+NStr0(mynum));
						outtextXY(xa,ya+32,'= '+NStr0(var2));
						end;
                      op:=chr(0);
                      mynum:=var2;
                      mych:=Nstr0(var2);
                      outtextxy(xa,ya,mych);
                      ls:=length(mych);
                      end;
                    end;
{DEL}  chr($5300)                           :begin
                    mych:=''; mynum:=0; op:=chr(0); forced:=char(0); var1:=0; var2:=0;
                    bar(xa,ya,xa+dx,ya+dy); 
                    ls:=0;
                    end;
(*      else
        Write(ord(ch),' ',ch,' ',hi(ch)); { for adding new functions - print keycode of unknown key } *)

    end;
  
 until ch=27;  {enter}
 
 MyGetNum:=mych;
end;

begin
  WriteFreeMem;
  MouseOff;
  MouseDisabled:=True;
  Clear(MX0,72,639,479);
  OutTextXY(MX0,72,'My Calculator');
  OutTextXY(MX0,72+1*8,'=============');
  OutTextXY(MX0,72+2*8,'ESC = to end');
  OutTextXY(MX0,72+4*8,'Operators:');
  OutTextXY(MX0,72+5*8,'-----------');
  OutTextXY(MX0,72+6*8,'+ - * /');
  OutTextXY(MX0,72+7*8,'s - Square Root');
  OutTextXY(MX0,72+9*8,'Multiply lay with');
  OutTextXY(MX0,72+21*8,'Multiply sweep w.');
  for i := 1 to 10 do begin
    Str((i*i*(UnitsPerTorpRate[player]/100)):4:0,s);
    OutTextXY(MX0,72+9*8+i*8,s+' ^ '+Torps[i].name);
    Str((i*i*SweepRate*1.0):4:0,s);
    Str((i*i*WebSweepRate*1.0):4:0,s2);
    OutTextXY(MX0,72+21*8+i*8,s+'/'+s2+' ^ '+Beams[i].name);
  end;
   
  MyGetNum(MX0,72+33*8);
    
  NewMenu;
  MouseDisabled:=False;
  MouseOn;
  ch:=1;		{ don't redraw map }
  
end;

(* No use anymore.... 
procedure SimGA;
type  NArray = array[0..3,0..9] of int;

var dp, i : int;
    num, df, af, GAMin, GAmax, ar, dr, GARem, GA, calc : long;
    a : NArray;

{
   procedure AdvChooseNumber(var a :long);
   a - Array [Counter,Data]
   [0,0]  : Length of array [1..x]
   [0,1]  : Index
   [x,1]  : Data of variable x
   [x,2]  : Min
   [x,3]  : Max
   [x,4]  : Init Number
   [x,5]  : X-Pos on Screen
   [x,6]  : Y-Pos on Screen
   [x,7]  : length
   [x,8]  : arrow
   [x,9]  : yes=1, no=0
   
   x=1: Colonists
   x=2: Defense
   x=3: New Colonists}
         
procedure AdvChooseNumber(var a : NArray);

{
   a - Array [Counter,Data]
   [0,0]  : Length of array [1..x]
   [0,1]  : Index
   [x,1]  : Data of variable x
   [x,2]  : Min
   [x,3]  : Max
   [x,4]  : Init Number
   [x,5]  : X-Pos on Screen
   [x,6]  : Y-Pos on Screen
   [x,7]  : length
   [x,8]  : arrow
   [x,9]  : yes=1, no=0
   
   Old Data
   x,y,len,arrow: long; yes_no : Boolean; min_,max_,initnumber : long):long;
   line - number of digits to underline
}
var
        x,y,len,arrow,yes_no,min_,max_,what : long;
        k       : long;
        s       : string[16];
procedure PutNum;
var
        s       : string[16];
begin
        Clear(x,y,x+len*8-1,y+7);
        SetColor(LightGreen);
        Str(what,s);
        OutTextXY(x,y,s);
end;

procedure BuildStruct(i: int);
begin
        inc(what,i);
        a[a[0,1],1]:=max(min(what,max_),min_);
end;

begin
        if a[0,1] > a[0,0] then exit; {Out of limits}
        Min_ := a[a[0,1],2];
        Max_ := a[a[0,1],3];
        what := a[a[0,1],1];
        x := a[a[0,1],5];
        y := a[a[0,1],6];
        len := a[a[0,1],7];
        arrow := a[a[0,1],8];
        yes_no := a[a[0,1],9];
        
                PutNum;
                SetColor(Yellow);
                Line(x,y+7,x+len*8-1,y+7);
                if (yes_no>0) then Clear(x+arrow*8,y,x+arrow*8+16-1,y+8);
                repeat ArrowBlink(x+arrow*8,y) until KeyPressed;
                SetColor(Black);
                Line(x,y+7,x+len*8-1,y+7);
                ch:=ReadKey;
                a[a[0,1],4] := ch;
                case ch of
                $4B00   : BuildStruct(-1);
                $4D00   : BuildStruct(1);
                $7300   : BuildStruct(-10);
                $7400   : BuildStruct(10);
                $9B00   : BuildStruct(-100);
                $9D00   : BuildStruct(100);
                ord('0')..ord('9')      : begin
                        GetStr1stKey:=ch;
                        s:=GetStr(x,y,len);
                        if GetStrKey=13 then
                          begin
                                k:=Value(s);
                                BuildStruct(k-what);
                          end;
                        end;
                end;
  end;

procedure CalcResult;         
begin
    with lplan^ do begin
      if (colonists>50) then dp:=50+trunc(sqrt(colonists-50))
      else if (colonists>0) then dp:=colonists
      else dp:=0;
      
      df:=long(GroundDefenseFactor[owner]);
      af:=long(GroundKillFactor[player]);
      
      GAmin:=long(Ceil(colonists*(df/af)));
      GAmax:=long(Ceil(colonists*df*((1+dp/20.0)/af)));     {Quapla Formula changed}
      
      ar := long(a[1,1]*af); {??}
      dr := long(trunc (colonists * df*((1+a[2,1]/20.0))));
      
      if (ar>dr) then GARem := long(TRound((ar-dr)/af))
                 else GARem := long(TRound((ar-dr)/df));
                 
      GA := long(Ceil(colonists*df*((1+a[2,1]/20.0)/af)));
      
      calc := GARem; {Only this calculated yet}
    end;
end;

procedure ShowResults;
begin
    Clear(MX0,184+8*8,639,358);
    setcolor(green);
    if a[1,1] >= 0 then OutTextXY(MX0,184+8*8,'Colonists : '+Nstr0(a[1,1]));
    if a[2,1] >= 0 then begin
      OutTextXY(MX0,184+9*8,'Defense P : ');
      if (a[2,1]>dp) then setcolor(red);
      OutTextXY(MX0+8*12,184+9*8,Nstr0(a[2,1]));
      if (a[2,1]>dp) then setcolor(green);
    end;
    if a[3,1] >= 0 then OutTextXY(MX0,184+10*8,'New Clans : '+Nstr0(a[3,1]));

    OutTextXY(MX0,184+12*8,'A-Clans   : '+Nstr0(ar));
    OutTextXY(MX0,184+13*8,'D-Clans   : '+Nstr0(dr));
    OutTextXY(MX0,184+14*8,'Cal-AForce: '+Nstr0(GA));
   
    OutTextXY(MX0,184+16*8,'Attack-DP-Remain');
    OutTextXY(MX0,184+18*8,'show new owner:');
    { Calclulate Attack Force }
    if (calc<0) then begin
      SetColor(lightred);
      OutTextXY(MX0,184+19*8,copy(RaceName[lplan^.owner],1,10)+': '+Nstr0(minL(calc*(-1),lplan^.colonists)));
    end else if (GARem>0) then OutTextXY(MX0,184+19*8,copy(RaceName[player],1,10)+': '+Nstr0(calc))
    else begin
      SetColor(Yellow);
      OutTextXY(MX0,184+19*8,'unowned Planet');
    end;  
    
    setcolor(white);
    OutTextXY(MX0,184+16*8,'A');
    OutTextXY(MX0+8*8,184+16*8,'P');
    OutTextXY(MX0+8*10,184+16*8,'R');    
end;

begin
  MouseOff;
  Calc := 0;
  for i := 1 to 3 do begin   {Initialize Data}
    a[i,1] := 0;
    a[i,2] := 0;
    a[i,3] := 9999;
    a[i,4] := 0;
    a[i,5] := MX0+8*12;
    a[i,6] := 184+8*8+(i-1)*8;
    a[i,7] := 4;
    a[i,8] := -2;
    a[i,9] := 1;
  end;
  a[0,0] := 3; a[0,1] := 1; a[3,1] := -1; a[2,3] := 999;
 
  Clear(MX0,184,639,358);
  CalcResult;
  ShowResults;    
  setcolor(green);
  OutTextXY(MX0,184,'Ground Attack Sim');
  OutTextXY(MX0,184+1*8,'===============ESC');

  OutTextXY(MX0,184+3*8,'Colonists : '+Nstr0(lplan^.colonists));
  OutTextXY(MX0,184+4*8,'Max. Def. : '+Nstr0(dp));
  OutTextXY(MX0,184+5*8,'Min-AForce: '+Nstr0(GAmin));
  OutTextXY(MX0,184+6*8,'Max-AForce: '+Nstr0(GAmax));
          
  repeat
    AdvChooseNumber(a);
    Case a[a[0,1],4] of
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    DrawMap(yes);
                    helpscr:=0;
                   {Exit Identifier for Help in Function}
                  end; 
        $4800   : begin
                    repeat
                      dec(a[0,1],1);
                      if a[0,1]<1 then a[0,1] := a[0,0]; {Identifier for UP in Function}
                    until (a[a[0,1],1]>=0);
                  end; 
        $5000   : begin
                    repeat
                      inc(a[0,1],1);
                      if a[0,1]>a[0,0] then a[0,1] := 1; {Identifier for UP in Function}                          
                    until (a[a[0,1],1]>=0);
                  end;
        ord ('a') : begin
                    if a[1,1] <= 0 then a[1,1] := 0;
                    if a[2,1] <= 0 then a[2,1] := 0;
                    a[3,1] := -1;
                    a[0,1] := 1;
                  end;
        ord ('p') : begin
                    a[1,1] := -1;
                    if a[2,1] <= 0 then a[2,1] := 0;
                    if a[3,1] <= 0 then a[3,1] := 0;
                    a[0,1] := 2;
                  end;
        ord ('r') : begin
                    if a[1,1] <= 0 then a[1,1] := 0;
                    a[2,1] := -1;
                    if a[3,1] <= 0 then a[3,1] := 0;
                    a[0,1] := 3;
                  end;
                  
       end;
       
    CalcResult;
    ShowResults;
  until (a[a[0,1],4] in [27]);
  {force:=number or LockS;}
  ForceKey:=13;
  MouseOn;
end;
*)
procedure SimOwnGroundAttack;
begin
	repeat 
		inc(iRace);
		if (iRace>11) then iRace:=0;
	until not (iRace=player);
	PlanetInfo;
end;

procedure SimGroundAttack(Input:byte);
{Input: 1: Conlonist
        2: Defense}
type  NArray = array[0..2,0..9] of int;

var dp, i : int;
    num, df, af, GAMin, GAmax, ar, dr, GARem, GA, calc : long;
    a : NArray;

{
   a - Array [Counter,Data]
   [0,0]  : Length of array [1..x]
   [0,1]  : Index
   [x,1]  : Data of variable x
   [x,2]  : Min
   [x,3]  : Max
   [x,4]  : Init Number
   [x,5]  : X-Pos on Screen
   [x,6]  : Y-Pos on Screen
   [x,7]  : length
   [x,8]  : arrow
   [x,9]  : yes=1, no=0
   
   x=1: Colonists
   x=2: Defense
   x=3: New Colonists}
         
procedure AdvChooseNumber(var a : NArray);
  var
          x,y,len,arrow,yes_no,min_,max_,what : int;
          k       : long;
          s       : string[16];
  procedure PutNum;
  var
          s       : string[16];
  begin
          Clear(x,y,x+len*8-1,y+7);
          SetColor(LightGreen);
          Str(what,s);
          OutTextXY(x,y,s);
  end;

  procedure BuildStruct(i: int);
  begin
          inc(what,i);
          a[a[0,1],1]:=max(min(what,max_),min_);
  end;

  begin
          if a[0,1] > a[0,0] then exit; {Out of limits}
          Min_ := a[a[0,1],2];
          Max_ := a[a[0,1],3];
          what := a[a[0,1],1];
          x := a[a[0,1],5];
          y := a[a[0,1],6];
          len := a[a[0,1],7];
          arrow := a[a[0,1],8];
          yes_no := a[a[0,1],9];
          
                  PutNum;
                  SetColor(Yellow);
                  Line(x,y+7,x+len*8-1,y+7);
                  if (yes_no>0) then Clear(x+arrow*8,y,x+arrow*8+16-1,y+8);
                  repeat ArrowBlink(x+arrow*8,y) until KeyPressed;
                  SetColor(Black);
                  Line(x,y+7,x+len*8-1,y+7);
                  ch:=ReadKey;
                  a[a[0,1],4] := ch;
                  case ch of
                  $4B00   : BuildStruct(-1);
                  $4D00   : BuildStruct(1);
                  $7300   : BuildStruct(-10);
                  $7400   : BuildStruct(10);
                  $9B00   : BuildStruct(-100);
                  $9D00   : BuildStruct(100);
                  ord('0')..ord('9')      : begin
                          GetStr1stKey:=ch;
                          s:=GetStr(x,y,len);
                          if GetStrKey=13 then
                            begin
                                  k:=Value(s);
                                  BuildStruct(k-what);
                            end;
                          end;
                  end;
    end;

begin
  Calc := 0;
  for i := 1 to 2 do begin   {Initialize Data}
    a[i,2] := 0;
    a[i,4] := 0;
    a[i,8] := -2;
    a[i,9] := 1;
  end;
  a[0,0] := 2; 
  a[0,1] := Input;
  a[1,1] := iColo; a[2,1] := iDefense;
  a[1,3] := 9999; a[2,3] := 999;
  a[1,5] := MX0+8*14; a[2,5] := MX0+8*11;
  a[1,6] := 200; a[2,6] := 248;
  a[1,7] := 4; a[2,7] := 3;
  repeat
    AdvChooseNumber(a);
    Case a[a[0,1],4] of
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    DrawMap(yes);
                    helpscr:=0;
                   {Exit Identifier for Help in Function}
                  end; 
        $4800   : begin
                      dec(a[0,1],1);
                      if a[0,1]<1 then a[0,1] := a[0,0]; {Identifier for UP in Function}
                  end; 
        $5000   : begin
                      inc(a[0,1],1);
                      if a[0,1]>a[0,0] then a[0,1] := 1; {Identifier for UP in Function}                          
                  end;                  
       end;
    iColo := a[1,1]; iDefense := a[2,1];
    PlanetInfo;
  until (a[a[0,1],4] in [27,13]);
end;

function GetTeleportDataTX(pl:int; var mineral:byte; var data:int) : int;
{pl:         Planet to look at
 mineral:    Char of Minerals 'CNTDMS$'
 data:       Ammount of mineral
 RET:        correspondig Planet for TX, 0 if none, -1 if no corresponding RX}
var i,p_:int;
    j:byte;
begin
  GetTeleportDataTX:=0;
  with TTurn^.data^ do begin
    if (planet[pl]=NIL) or (planet[pl]^.when<>turn) then exit;                         {No Planet/This turn}
	if (base[pl]=NIL) and (planet[pl]^.build=0) then exit; 							   {No base built}
    p_:=player; if p_>20 then dec(p_,20); {while Buildbase player+=20}
    if (planet[pl]^.owner=p_) and {only player and base}       
       (planet[pl]^.fcode[1]='T') and (planet[pl]^.fcode[2]='X') then begin
      for j := 1 to 7 do if (planet[pl]^.fcode[3]=TPFCode[j]) then begin
        GetTeleportDataTX:=-1;
        mineral:=j;
        for i:=1 to 500 do begin
          if (planet[i]<>NIL) and (planet[i]^.owner=p_) and (planet[i]^.when=turn) and (planet[i]^.fcode[1]='R') and 
             (planet[i]^.fcode[2]='X') and (planet[i]^.fcode[3]=planet[pl]^.fcode[3]) then begin
            if (base[i]=NIL) then if (planet[i]^.build=0) then continue; {next one...}
            case mineral of
              1:  data:=planet[pl]^.colonists div 5;
              2:  data:=planet[pl]^.N div 5;
              3:  Data:=planet[pl]^.T div 5;
              4:  Data:=planet[pl]^.D div 5;
              5:  Data:=planet[pl]^.M div 5;
              6:  Data:=planet[pl]^.supplies div 5;
              7:  Data:=planet[pl]^.funds div 5;
            end;
            GetTeleportDataTX:=i;
            exit; {here go, thats our RX-Base}
          end;
        end;
      end;
    end;
  end;
end;

function GetTeleportDataRX(pl:int; var mineral:byte; var data:int) : int;
{pl:         Planet to look at
 mineral:    Char of Minerals 'CNTDMS$'
 data:       Ammount of minerals, total
 RET:        correspondig nr. planets for RX, 0 if none, -1 if no corresponding TX}
var i,p_,count:int;
    j:byte;
begin
  GetTeleportDataRX:=0;
  count:=0;
  with TTurn^.data^ do begin
    if (planet[pl]=NIL) or (planet[pl]^.when<>turn) then exit;
    if (base[pl]=NIL) then if (planet[pl]^.build=0) then exit; {No base built}
    p_:=player; if p_>20 then dec(p_,20); {while Buildbase player+=20}
    if (planet[pl]^.owner=p_) and {only player and base}       
       (planet[pl]^.fcode[1]='R') and (planet[pl]^.fcode[2]='X') then begin 
      for j:=1 to 7 do if (planet[pl]^.fcode[3]=TPFCode[j]) then begin
        mineral:=j; data:=0;
        for i:=1 to (pl-1) do 
          if ((planet[i]<>NIL) and (planet[i]^.owner=p_) and (planet[pl]^.fcode=planet[i]^.fcode)) 
			 and (planet[i]^.when=turn) and ((base[i]<>NIL) or ((planet[i]^.build=1) and (base[i]=NIL))) then
          begin count:=-2; GetTeleportDataRX:=count; 
          exit; end;             {RX with lower ID}
        if count=-2 then exit;
        count:=0;
        for i:=1 to 500 do begin
          if (planet[i]<>NIL) and (planet[i]^.owner=p_) and (planet[i]^.when=turn) and (planet[i]^.fcode[1]='T') and 
             (planet[i]^.fcode[2]='X') and (planet[i]^.fcode[3]=planet[pl]^.fcode[3]) and 
             ((base[i]<>NIL) or ((planet[i]^.build=1) and (base[i]=NIL))) then begin  {this one...}
            case mineral of
              1:  inc(data,planet[i]^.colonists div 5);
              2:  inc(data,planet[i]^.N div 5);
              3:  inc(data,planet[i]^.T div 5);
              4:  inc(Data,planet[i]^.D div 5);
              5:  inc(Data,planet[i]^.M div 5);
              6:  inc(Data,planet[i]^.supplies div 5);
              7:  inc(Data,planet[i]^.funds div 5);
            end;
            inc(count,1); {here go, thats one of our TX-Base}
          end;
        end;
        if count=0 then count:=-1;                    {No TX Found}
      end;
    end;
  end;
  GetTeleportDataRX:=count;
end;

procedure GetTeleport(PlanN:int);
var i,ii,col,pla,amo       :int;
    j                   : long;
    c                   : byte;
    fc,fcsave           :fcstr;
    s,ss                :string;
begin
  if (TTurn^.data^.planet[PlanN]=NIL) or (TTurn^.data^.planet[PlanN]^.when<>turn) or
     ((TTurn^.data^.planet[PlanN]^.build=0) and (TTurn^.data^.base[PlanN]=NIL)) then exit;
  Mouseoff;
  NewMenu;
  UnLockReservedMemory(MenuSize(MX0-112,354,631,15,Yes));
  with TTurn^.data^.planet[PlanN]^ do begin
    fcsave:=fcode;
    {TX-Codes}
    fc[1]:='T';
    fc[2]:='X';
    for i:=1 to 7 do begin
      fc[3]:=TPFcode[i];
      s:=fc+': ';
      fcode := fc;
      pla := GetTeleportDataTX(PlanN, c, amo);
      if pla>0 then begin
        s:=s+'Send '+copy('   '+Nstr0(amo),length(Nstr0(amo)),4)+TPFCode[c];
        s:=s+' -> #'+copy('  '+Nstr(pla),length(Nstr(pla)),3)+' : ';
        j:=amo;
        GetTeleportDataRX(pla, c, amo);
        s:=s+copy('   '+Nstr0(amo),length(Nstr0(amo)),4)+TPFCode[c];
        col:=white;
      end else if pla<0 then begin
        s:=s+'     no RX'+fc[3];
        j:=0; col:=lightgray;
      end;
      if fc=fcsave then col:=green;
      AddMenuItem(s,col,No);
    end;
    {RX-Rodes}    
    fc[1]:='R';
    for i:=1 to 7 do begin
      fc[3]:=TPFcode[i];
      s:=fc+': ';
      fcode := fc;
      pla := GetTeleportDataRX(PlanN, c, amo);
      if pla>0 then begin
        col:=white;
        s:=s+'Get  '+copy('   '+nstr0(amo),length(nstr0(amo)),4)+fc[3]+' <- '+copy('  '+Nstr(pla),length(Nstr(pla)),3)+'^ ';
        case i of
              1:  j:=colonists+amo;
              2:  j:=N+amo;
              3:  j:=T+amo;
              4:  j:=D+amo;
              5:  j:=M+amo;
              6:  j:=supplies+amo;
              7:  j:=funds+amo;
        end;
        ss:=': '+copy('   '+Nstr0(j),length(Nstr0(j)),4)+TPFCode[i];
        for ii := PlanN+1 to 500 do begin
          pla := GetTeleportDataRX(ii, c, amo);
          if (pla=-2) and (c=i) then begin
            ss:='-> #'+copy('  '+Nstr(ii),length(Nstr(ii)),3);
            col:=lightred;
            break;
          end;
        end;
        s:=s+ss;
      end else if pla=0 then begin
        s:=s+'     no valid RX'+fc[3];
        col:=lightgray;
      end else if pla=-1 then begin
        s:=s+'     no TX'+fc[3];
        col:=lightgray;      
      end else begin
        s:=s+'     ID is too high';
        col:=lightgray;
      end;
      if fc=fcsave then col:=green;
      AddMenuItem(s,col,No);
    end;
    AddMenuItem('Reset FCode <-> ESC to exit',yellow,No);
    fcode := fcsave;
  end;
  ChooseMenu(MX0-112,354,MX0-112,631,15,White,Yellow,1,No,Yes,-1);
  if (MenuKey<>27) then begin
    if Menuvalue=15 then fc:='QPL' else begin
      if Menuvalue<8 then fc[1]:='T'
      else begin dec(MenuValue,7); fc[1]:='R'; end;
      fc[2]:='X';
      fc[3]:=TPFCode[MenuValue];
    end;
    TTurn^.data^.planet[PlanN]^.fcode:=fc; 
    ChangeData(Pl,PlanN);    
    PlanetInfo; 
{    DrawMap(yes); Done in Main-Routine, shutdown why?}
  end; 
  NewMenu;
  LockReservedMemory;
  Mouseon;
end;

procedure ShowTeleport;
var pla,amo,count,line  :int;
    c,c2                : byte;
    
begin
  Mouseoff;
  NewMenu;
  UnLockReservedMemory(MenuSize(MX0,100,mx0+17*8,30,Yes));
  line:=1;
  AddMenuItem('Teleport-Info',white,No);
	AddMenuItem('TAB   to zoom',white,No);
  AddMenuItem('SPACE to center',white,No);
	for c2 := 1 to 7 do begin
    AddMenuItem('- - - - - - -',white,No);
    AddMenuItem('TX'+TPFcode[c2]+' / RX'+TPFcode[c2],yellow,No);
    for count :=1 to 500 do begin
      pla := GetTeleportDataTX(count, c, amo);
      if (c=c2) then 
      if (pla>0) then begin
        AddMenuItem('#'+copy('  '+Nstr(count),length(Nstr(count)),3)+
          '  -> '+copy('    '+Nstr0(amo),length(Nstr0(amo)),5)+TPFCode[c],magenta,No);
      end else if (pla=-1) then begin
        AddMenuItem('#'+copy('  '+Nstr(count),length(Nstr(count)),3)+' -- No RX'+TPFcode[c2],magenta,No);
      end;
    end;
    for count :=1 to 500 do begin
      pla := GetTeleportDataRX(count, c, amo);
      if (c=c2) then
      if (pla>0) then begin
        AddMenuItem('#'+copy('  '+Nstr(count),length(Nstr(count)),3)+
          '  <- '+copy('    '+Nstr0(amo),length(Nstr0(amo)),5)+TPFCode[c],lightmagenta,No);
      end else if (pla=-2) then begin 
        AddMenuItem('#'+copy('  '+Nstr(count),length(Nstr(count)),3)+' -- ID too High',lightmagenta,No);
      end else if (pla=-1) then begin
        AddMenuItem('#'+copy('  '+Nstr(count),length(Nstr(count)),3)+' -- No TX'+TPFcode[c2],lightmagenta,No);
      end;
    end;
  end;
  AddMenuItem('- - - - - - - -',white,No);
  AddMenuItem('No TX / RX',yellow,No);
  for count :=1 to 500 do begin
    if (TTurn^.data^.planet[count]=NIL) or 
       ((TTurn^.data^.planet[count]^.build=0) and (TTurn^.data^.base[count]=NIL)) or 
       (TTurn^.data^.planet[count]^.owner<>player) then continue;
    pla := GetTeleportDataTX(count, c, amo);
    if (pla=0) then pla := GetTeleportDataRX(count, c, amo);
    if (pla<>0) then continue;
    AddMenuItem('#'+copy('  '+Nstr(count),length(Nstr(count)),3)+' -- '+TTurn^.data^.planet[count]^.fcode,lightgray,No);
  end;
  ChooseMenu(MX0,100,MX0,mx0+17*8,30,White,lightgreen,1,No,Yes,-2);
  if (MenuKey<>27) then begin
    val(copy(MENUstring,2,3),pla,amo);
    if (amo=0) and (pla>0) and (pla<501) then begin
      force:=pla or LockP; forcekey:=13; end;
  end;
  NewMenu;
  LockReservedMemory;
  Mouseon; 
end;

procedure Ini_Init_Help;
const hlp = 'Help';
			empty = 'Empty';
		 
begin
	ini_add(ini_file_vpahelp,'List-Program','vh.exe','',ini_size_bool,@VPAHelp.List);
  ini_add(ini_file_vpahelp,hlp+'1',hlp+'\'+hlp+'\index.htm','',ini_size_bool,@VPAHelp.help1);
  ini_add(ini_file_vpahelp,hlp+'2',hlp+'\Teleport.txt','',ini_size_bool,@VPAHelp.help2);
	ini_add(ini_file_vpahelp,hlp+'3',hlp+'\Starbase.txt','',ini_size_bool,@VPAHelp.help3);
	ini_add(ini_file_vpahelp,hlp+'4',hlp+'\Unity.txt','',ini_size_bool,@VPAHelp.help4);
	ini_add(ini_file_vpahelp,hlp+'5',hlp+'\hostor~1.txt','',ini_size_bool,@VPAHelp.help5);
	ini_add(ini_file_vpahelp,hlp+'6',empty,'',ini_size_bool,@VPAHelp.help6);
	ini_add(ini_file_vpahelp,hlp+'7',empty,'',ini_size_bool,@VPAHelp.help7);
	ini_add(ini_file_vpahelp,hlp+'8',empty,'',ini_size_bool,@VPAHelp.help8);
	ini_add(ini_file_vpahelp,hlp+'9',empty,'',ini_size_bool,@VPAHelp.help9);
end; { Ini_Init_Addon }

procedure ShowRules;
const 
      lexist : boolean = FALSE;
var sr	: SearchRec;
    a,b : int;
begin
  Mouseoff;
	ini_showmenu(ini_file_vpahelp,true);
	DrawRightScreen;
	Drawmap(TRUE);
	ForceKey:=13;
  Mouseon; 
end;
  
end.

