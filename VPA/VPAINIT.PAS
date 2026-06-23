{
*******************************************************************
* VPAINIT.PAS - Main Part - Initialisation
*
* $Id: vpainit.pas,v 1.50 2013/12/29 06:41:03 sfplanets Exp $
*
*
*******************************************************************
}
{$I switches.inc}
{DEFINE TASKS}  {Set $DEFINE to include undone Tasks by Alex Ivlev 2002}

Unit  VPAInit;  (* VPA Initialization Part *)
{$V-}

Interface

uses
  AuxF,VPAData;

const
  KeepWayPoints : boolean = No;
        VPACTLIST_INI : string[12] = '';

procedure GetShipTarget (id:int; var h:SRec; var ht:STRec);
procedure LoadPlanetsData;
function  StartVPA : boolean;

Implementation

uses
  StrF,ptcgraph,{$IFDEF UNIX}xfocus,{$ENDIF}Screen,Mouse,Keyboard,Config,MsgRead,Messages,Report,ExtFeat,Ini,
{$IFDEF VPACC}
        PHostM,Hullfunc,
{$ENDIF}
        RST_TRN,
{$IFDEF Tasks}
        Tasks,
{$ENDIF}
        SVGA;

Const
  ReadMsg : boolean = No;
  PHOSTcli: boolean = No;
  HostMode: boolean = No;
  ReadAll : boolean = Yes;
{ DoVCL : boolean = Yes;}

  XYPLAN1 : array [1..6] of char = 'XYPLAN';
  XYPLAN2 : array [1..4] of char = '.DAT';

type
  PwdType = array [1..2,1..10] of byte;
  PwdStr  = string[10];
var
  ppassw  : array [1..11] of PwdStr;
  passwn  : byte;
  frm,rep : str79;

  HaveShip: array [1..999] of boolean;

procedure InvalidParm (var parm:string);
  begin
    Writeln('Invalid parameter "',parm,'"');
    Halt;
  end;

procedure Parameters;
  var i,j : int;
  parm  : string[127];
  hlp : boolean;

  const feat : boolean = false;

  procedure WriteFeature(const s:string);
  begin
    if not feat then writeln(#13#10'Options compiled in:');
    writeln(#9,s);
    feat := true;
  end;

  begin
    if (length(ParamStr(1))>2) then { jump out here as plstr is only string[2] }
      begin Writeln('Race = 1..11'); Halt end;
    plstr:=ParamStr(1);
    passwn:=0;
    frm[0]:=#0; rep[0]:=#0;
    hlp:=(plstr='/?');
    if hlp or (ParamCount=0) then
    begin
    Writeln('Use: VPA race [dir] [/B] [/K] [/M] [/O] [/P] [/PW:pwd] [/R] [/S] [/REP:frm,rep]');
      if not hlp then Writeln(' or  VPA /?   for help')
      else begin
  Write(#13#10'Where    race          is  a number in 1..11'+
        #13#10'         dir           is  current game directory'+
        #13#10'Use      /B            to  run VPA in batch mode'+
              #13#10'         /K            for keyboard-only mode (no mouse)',
        #13#10'         /M            to  enforce incoming message processing'+
        #13#10'         /O            to  read the specified race data only'+
        #13#10'         /P            for pause before switching to graphics'+
        #13#10'         /PW:pwd       to  specify player password',
        #13#10'         /R            to  run VPA in read-only mode'+
        #13#10'         /REP:frm,rep  to  generate report file'+
        #13#10'         /S            to  run VPA in SVGA mode',
        #13#10'         /BGI:drv,dir,mode  to  load and use another BGI driver'+
{       #13#10'         /V            to  ignore VCL command file'+}
        #13#10'Read the complete description in VPA.FAQ'+
        #13#10);
        {$IFDEF VPACC} WriteFeature('command messages (VPACC)'); {$ENDIF}
        {$IFDEF VPAMM} WriteFeature('mixed mode (VPAMM)'); {$ENDIF}
        {$IFDEF TASKS} WriteFeature('auto tasks (TASKS)'); {$ENDIF}
      end;
      Halt;
    end;
    Val(plstr,player,i);
    if not (player in [1..11]) then
      begin Writeln('Race = 1..11'); Halt end;
    dbname:='VPA'+plstr+'.DB';
    for i:=2 to ParamCount do
    begin
      parm:=ParamStr(i);
      if parm[1]='/' then
      begin
  case UChr[byte(parm[2])] of
    'B' : if (byte(parm[0])>5) and (UChr[byte(parm[3])]='G') and (UChr[byte(parm[4])]='I') then
      begin
        Delete(parm,1,5);
                    bgiDrv:=Copy(parm,1,Pos(',',parm)-1);
                    Delete(parm,1,Pos(',',parm));
        Parse(parm,bgiDir,',');
        bgiMode:=Value(parm);
                    CustomBGI:=Yes;
      end
                  else Batch:=Yes;
    'K' : MousePresent:=No;
    'M' : ReadMsg:=Yes;
    'O' : ReadAll:=No;
    'P' : if (byte(parm[0])>4) and (UChr[byte(parm[3])]='W') and (passwn<11) then
      begin
        Delete(parm,1,4);
        inc(passwn);
        ppassw[passwn]:=parm;
      end
      else GPause:=Yes;
    'R' : if (byte(parm[0])>5) and (UChr[byte(parm[3])]='E') and (UChr[byte(parm[4])]='P') then
      begin
        Delete(parm,1,5);
        Parse(parm,frm,',');
        rep:=parm;
      end
      else RWMode:=Off;
    'S' : useSVGA := true;
{   'V' : DoVCL:=No;}
    else      InvalidParm(parm)
  end;
      end
      else if byte(addir[0])=0 then
      begin
  addir:=ParamStr(i);
  if not (addir[byte(addir[0])] in [#0,'/']) then addir:=addir+'/';  { Linux: separador '/' (era '\' de DOS) }
      end
      else InvalidParm(parm);
    end;
  end;

procedure EraseBoundMarkers (id:int);
  var i : int;
  begin
    with TEnd^.data^ do
    for i:=1 to nmark do
      if mark^[i].bind=-id then EraseMark(i);
  end;

function MayBeThatShip (var h0,h:SRec; id:int) : boolean;
  var   maybe : boolean;
{ d1  : long;}
  begin
{    d1:=IIF(h0.hull in GraviHulls,166,IIF(h0.hull in HyperHulls,364,85))*(h.when-h0.when);}
    maybe:=(h0.owner=h.owner) and ((h0.hull=h.hull) or (h0.hull=-1) or
     ((h0.hull<>-1) and (h.hull=-1))  );
    {and
      ( (Distance2(h0.x,h0.y,h.x,h.y)<=d1*d1) or
  (MapWrap and (Within(Abs(h0.x-h.x),MapSize-d1,MapSize) or
          Within(Abs(h0.x-h.x),0,d1))
     and (Within(Abs(h0.y-h.y),MapSize-d1,MapSize) or
          Within(Abs(h0.y-h.y),0,d1)) ) );}
    MayBeThatShip:=maybe;
    if not maybe then EraseBoundMarkers(id);
  end;

procedure BackTrack (h0:sptr; var h:SRec; id:int; KeepWP:boolean);
  var xx,yy,xx0,yy0,p : int;
  hyp   : boolean;
  begin
    FillChar(h.px1,8,$FF);
    if h0=nil then Exit;
    if h0^.when=today then Move(h0^.px1,h.px1,8) else
    if MayBeThatShip(h0^,h,id) then
    begin
      if h0^.when=today-1 then
      begin
  h.px1:=h0^.x; h.py1:=h0^.y;
  h.px2:=h0^.px1; h.py2:=h0^.py1;
      end else
      if h0^.when=today-2 then
  begin h.px2:=h0^.x; h.py2:=h0^.y end;
      if KeepWP and (h0^.warp>0) and (h0^.wx or h0^.wy<>0) and (h.mission<>8) then
      begin
        hyp:=HyperDrive and (IsShipFunc(h,hfHyperDrive)) and (h.fcode='HYP');
  if ((h.warp>0) and (h.wx or h.wy<>0)) or (hyp and (h.fuel>0)) then
  begin
    xx0:=h0^.x+h0^.wx;
    yy0:=h0^.y+h0^.wy;
    xx:=h.x+h.wx;
    yy:=h.y+h.wy;
    if MapWrap then begin WrapXY(xx0,yy0); WrapXY(xx,yy) end;
    if (xx<>xx0) or (yy<>yy0) then
    begin
      if MapWrap then WrapWayPoint(h.x,h.y,xx0,yy0);
      h.wx:=xx0-h.x;
      h.wy:=yy0-h.y;
      if hyp and (h.warp=0) then
        if (h.fuel>=50) and (Distance2(h.x,h.y,xx0,yy0)>=200*200)
    then h.warp:=1
    else h.warp:=GetOptimalWarp(addr(h));
      ChangeData(Sh,id);
    end
    else begin
      p:=PSearchXY(h.x,h.y);
      if p<>0 then
      begin
        Location(xx0,yy0);
        if LocationPlanet=p then
        begin
    h.wx:=0;
    h.wy:=0;
    ChangeData(Sh,id);
        end;
      end;
    end;
  end;
      end;
    end;
  end;


{ Convert a possibly null-terminated name into a regular
  space-padded one }
procedure ProcessName(var name; len:int);
  var a : array[1..100] of char absolute name;
      i : int;
      did : boolean;
  begin
    did:=false;
    for i:=1 to len do begin
      if a[i]=#0 then did:=true;
      if did then a[i]:=' ';
    end;
  end;

procedure LoadPlanetsData;
  var i : int;
  s : str30;
  f : file;
  begin
    Writeln('Loading PLANETS data...');

    OpenData(f,'PLANET.NM',Yes);
    BlockRead(f,PlanName,500*20);
    CloseData(f);

    if OpenData(f,'STORM.NM',No) then
    begin
      BlockRead(f,StormName,50*20);
      CloseData(f);
    end
    else FillChar(StormName,SizeOf(StormName),' ');

    OpenData(f,'RACE.NM',Yes);
    BlockRead(f,RaceFull,11*30);
    RaceFull[12]:='The Game Host                 ';
    Seek(f,30*11+20*(player-1));
    BlockRead(f,pname,20);
    Seek(f,(30+20)*11);
    BlockRead(f,RaceName[1],12*11);
    RaceName[0]:='            ';
    RaceName[12]:='??????????  ';
    CloseData(f);

    OpenData(f,'BEAMSPEC.DAT',Yes);
    for i:=1 to 10 do
    begin
      BlockRead(f,Beams[i].name,20);
      BlockRead(f,Beams[i].cost,SizeOf(BeamType)-18);
      ProcessName(Beams[i].name,Sizeof(Beams[i].name));
    end;
    CloseData(f);

    OpenData(f,'TORPSPEC.DAT',Yes);
    for i:=1 to 10 do
    begin
      BlockRead(f,Torps[i].name,20);
      BlockRead(f,Torps[i].cost,SizeOf(TorpType)-6);
      ProcessName(Torps[i].name,Sizeof(Torps[i].name));
    end;
    CloseData(f);

    wmm:=0; tmm:=0;
    for i:=1 to 10 do
    begin
      wmm:=Max(wmm,Beams[i].mass);
      tmm:=Max(tmm,Torps[i].mass);
    end;

    OpenData(f,'ENGSPEC.DAT',Yes);
    for i:=1 to 9 do
    begin
      BlockRead(f,Engines[i].name,20);
      BlockRead(f,Engines[i].cost,SizeOf(EngType)-18-9*4);
      BlockRead(f,Engines[i].burn,9*4);
      ProcessName(Engines[i].name,Sizeof(Engines[i].name));
    end;
    CloseData(f);

    OpenData(f,'TRUEHULL.DAT',Yes);
    BlockRead(f,RaceHull,SizeOf(RaceHull));
    CloseData(f);

    OpenData(f,'HULLSPEC.DAT',Yes);
    for i:=1 to 105 do
    begin
      BlockRead(f,s[1],30); s[0]:=#30;
      ProcessName(s[1],30);
      CutShipNames(s); {moved to VPA Data}
      with Hulls[i] do
      begin
        Move(s[1],name,18);
        BlockRead(f,pic,SizeOf(HullType)-18);
        maxmass:=mass+cargo+fuel+weapons*wmm+launchers*tmm;
        if mass<MinSM then MinSM:=mass;
        if maxmass>MaxSM then MaxSM:=maxmass;
      end;
    end;
    Hulls[0].name:='LAMER DAVE FRIGATE';
    CloseData(f);
  end;

procedure ClearAlienShip (var h:SRec);
  begin
    FillChar(h.fcode,3+2+2*2,$FF);
    FillChar(h.mission,6*2,$FF);
    FillChar(h.fuel,2+4*2+7*2+7*2+2+2,$FF);
  end;

procedure GetShipTarget (id:int; var h:SRec; var ht:STRec);
  begin
    if HaveShip[id] then Exit;
    with TEnd^.data^ do
    begin
      FillChar(h,SizeOf(SRec),$FF);
      h.hull:=ht.hull;    { early setting of owner and hull  }
      h.owner:=ht.owner;  { is necessary for MayBeThatShip() }
      if (ship[id]<>nil) and MayBeThatShip(ship[id]^,h,id) then
      begin
  Move(ship[id]^,h,SizeOf(SRec)-2);
  if h.when<>today then ClearAlienShip(h);
  h.hull:=ht.hull;  { in case hull was -1 in ship[id]^ }
        h.ship_id := id;
      end;
      h.when:=today;
      h.x:=ht.x;
      h.y:=ht.y;
      h.warp:=ht.warp;
      Move(ht.name,h.name,20);
      h.mission:=-1;
      h.enemy:=ht.heading;
      BackTrack(ship[id],h,id,No);
      if (ship[id]=nil) or Diff(h,ship[id]^,SizeOf(SRec)-2) then
      begin
  if ship[id]=nil then
    begin CheckMem(SizeOf(SRec)); New(ship[id]) end;
  ship[id]^:=h;
  DataChg:=Yes;
      end;
    end;
  end;

procedure CheckPHOST;
  var f : file;
  m : Msg;
  n,i,k : int;
  s,s1  : string[40];
  ls  : byte absolute s;
  begin
    if not PHOST then
    begin
      if not DFiles then Exit;
      OpenRW(f,'MDATA'+plstr+'.DAT',Yes);
      Write('Checking for PHOST...');
      BlockRead(f,n,2);
      if n>0 then
      for i:=n downto 1 do
      begin
  ReadMessage(f,i,m,0,Yes);
  s:=m.text[1];
  k:=Pos('PHOST v',s);
  if k>0 then
  begin
    PHOST:=Yes;
    Delete(s,1,k+6);
    Trim(s);
          k := Pos(' ', s);
          if k<>0 then s[0] := chr(k-1);
    PHOSTver:=s;
    Break;
  end;
  k:=Pos('Priority Points',s);
  if k>0 then Break;
      end;
      CloseData(f);
      Write(#13);
    end;
    if PHOST then
    begin
      Writeln('PHOST version ',PHOSTver,' detected');
      s:=PHOSTver;
      while (ls>0) and (Pos(s[ls],'0123456789')=0) do dec(ls);
      Parse(s,s1,'.');
      k:=Value(s1);
      PHOSTcli:=(k>2) or ((k=2) and (Value(s)>=12));
      if k<3 then TrueHullByRace:=No;
    end;
  end;

procedure MapInit;
  begin
    MapX0:=2000-MapSize div 2;
    MapY0:=MapX0+MapSize;
    Ratios[1,1]:=MapSize;
    Ratios[1,2]:=479;
    InitRatios;
  end;

procedure LoadMap;
  type  xypair  = array [1..2] of int;
  var pxy : array [1..500] of xypair;
  r : byte;
  f : file;
  nMaps : byte;
        mapFound: boolean;
  procedure LoadXYPlan; { f must be opened; f gets closed }
    var i,a : int;
  xy  : xypair;
    begin
      for i:=1 to 500 do
      begin
  BlockRead(f,xy,4);
  if (xy[1]>=MapX0) and (xy[1]<=MapY0) and
     (xy[2]>=MapX0) and (xy[2]<=MapY0) then pxy[i]:=xy;
  BlockRead(f,a,2);
      end;
      CloseData(f);
    end;
  procedure MergeMaps;
    const Xsum  = 998681;
    var   pxy1  : array [1..500] of xypair;
    xs  : long;
    i,n : int;
    begin
      xs:=Xsum; n:=0;
      for i:=1 to 500 do
      begin
  pxy1[i]:=pxy[i];
  if pxy1[i,1]=-1 then
  begin
    inc(pxy1[i,1]);
    inc(pxy1[i,2]);
    n:=i;
  end
  else dec(xs,pxy1[i,1]);
      end;
      if n<>0 then
      begin
  while (xs>=20000) and (i<=500) do
  begin
    i:=1;
    while (i<=500) and (pxy1[i,1]<>0) do inc(i);
    if i<=500 then
    begin
      pxy1[i,1]:=10000;
      dec(xs,10000);
      n:=i;
    end;
  end;
  inc(pxy1[n,1],xs);
      end;
      if not OpenW(f,XYPLAN1+XYPLAN2,No) then GPause:=Yes
      else begin
  Writeln('Merging multiple maps into a single file '+addir+XYPLAN1+XYPLAN2+'...');
  n:=0;
  for i:=1 to 500 do
  begin
    BlockWrite(f,pxy1[i],4);
    BlockWrite(f,n,2);
  end;
  CloseData(f);
      end;
    end;
  begin
    if TEnd^.data=nil then Exit;
    Writeln('Reading starmap...');
    FillChar(pxy,SizeOf(pxy),$FF);
    nMaps:=0;
    mapFound := false;
    if DFiles and ExplMap then begin
      for r:=1 to 11 do begin
  if (r=player) or IsData[r] then begin
    if (OpenRW(f,XYPLAN1+NStr(r)+XYPLAN2, False)) then begin
       LoadXYPlan;
             mapFound:=true;
       inc(nMaps);
          end
          else begin
            writeln('warning: ' + XYPLAN1+NStr(r)+XYPLAN2 + ' not found');
          end;
  end;
      end;
    end;
    if (not mapFound) and OpenData(f,XYPLAN1+XYPLAN2,TEnd^.data^.xyplan[1,1]=-30000)
    then LoadXYPlan;
    if ReadMsg or Diff(pxy,TEnd^.data^.xyplan,SizeOf(pxy)) then
    begin
      Move(pxy,TEnd^.data^.xyplan,SizeOf(pxy));
      DataChg:=Yes;
      if nMaps>1 then MergeMaps;  {generate XYPLAN.DAT}
    end;
  end;

procedure MergeScores(var score : ScoreList; const other : ScoreList);
var pl, ix : integer;
begin
  for pl:=1 to 11 do
   for ix:=1 to 4 do
    if (score[pl][ix]=0) then
     score[pl][ix] := other[pl][ix];
end;

procedure ReadData;
  var i,j,k,n,r: int;
        kk,ii,hf: int;
  p : PRec;
  b : BRec;
  h : SRec;
  ht  : STRec;
  hv  : SVRec;
  m : MRec;
  mk  : MKRec;
  u : URec;
  t0 : tptr;                      { get old Turn Data}
  ep  : array [1..500] of EPln;
  f : file;
  s : string[12] absolute ep;
  sig : array [1..4] of char;
  web_unk : boolean;
  web_race: int;
  kore_r  : array [1..11] of boolean;
  kore_m  : array [1..500] of int;
  LargeSXY: boolean;
        CanDelete:Boolean;
        tmpscore : ScoreList;
        racenr   : int;
        decayed  : word;
  begin
   {$IFDEF VPACC}
    Hullfunc.InitHullFunc;
    LoadPHostCommands;
   {$ENDIF}
    Write('Reading VPA database file ',addir,dbname,'...');
    ReadTurnList;
    if not DFiles then
      if today=0 then
      begin
  Writeln(#13#10'Neither VPA database nor game data files found for race ',plstr,'!');
  Halt;
      end
      else begin
  s:=RaceName[player]; Trim(s);
  Writeln(s,' game data files not found. Read-only mode.');
      end;

    LoadTurnData(TTurn);  { load last turn from db }

    NewTurn:=ReadMsg or (TTurn=nil) or (TTurn<>TEnd) or (TurnVer<>VerNum);

    CheckPHOST;
    ReadConfig2(RWMode);
    MapInit;  { map must be initialized before reading ship data (KeepWayPoints) }

    if not DFiles then begin LoadMap; Exit end;

    if (TTurn<>nil) and (TTurn<>TEnd) then  { today's turn is not in db }
    begin
      TEnd^.data:=TTurn^.data;  { copy last turn's data into today's }
      TTurn^.data:=nil;
    end;
    if (TTurn<>TEnd) then  { init scores for new turn }
      FillChar(TEnd^.score, Sizeof(TEnd^.score), 0);

    NewTurnData(TEnd);  { does nothing if TEnd^.data<>nil }
    NewBuildQData(Tend); { New Array QData, if not already done}
    
    LoadMap;  { must be after MapInit, because it uses MapX0,MapY0 }

    Writeln('Reading game data...');

    OpenRW(f,'GEN'+plstr+'.DAT',Yes);
    Seek(f,18);
    BlockRead(f,tmpscore,SizeOf(ScoreList));
    MergeScores(TEnd^.score, tmpscore);
    CloseData(f);

    with TEnd^.data^ do
    begin

      Move(eplan,ep,SizeOf(eplan));

      for i:=1 to 500 do    { clear epln data for our planets }
      if (eplan[i].owner=player) or IsData[eplan[i].owner] then
      begin
        eplan[i].when:=0;
        eplan[i].activity:=0;
      end;

      if NewTurn then FillChar(newplan,SizeOf(newplan),0);

      FillChar(tmpscore, Sizeof(tmpscore), 0);

      for r:=1 to 12 do
      if (r=12) or IsData[r] then
      begin
        racenr := IIF(r=12,player,r);
        OpenRW(f,xFName[Pl]+NStr(racenr)+'.DAT',Yes);
        BlockRead(f,n,2);
        for i:=1 to n do
        begin
          BlockRead(f,p.owner,2);
          BlockRead(f,k,2);
          BlockRead(f,p.fcode,PRecordSize-4);
                if p.owner=racenr then Inc(tmpscore[racenr][1]);
          p.when:=today;
          p.when0:=today;
          if (planet[k]<>nil) and (planet[k]^.when=today) then
          with planet[k]^ do
          begin
            if p.fcode=#$FF#$FF#$FF then p.fcode:=fcode;
            if p.mines=-1 then p.mines:=mines;
            if p.factories=-1 then p.factories:=factories;
            if p.defense=-1 then p.defense:=defense;
            if p.N=-1 then p.N:=N;
            if p.T=-1 then p.T:=T;
            if p.D=-1 then p.D:=D;
            if p.M=-1 then p.M:=M;
            if p.colonists=-1 then p.colonists:=colonists;
            if p.supplies=-1 then p.supplies:=supplies;
            if p.funds=-1 then p.funds:=funds;
            if p.Nc=-1 then p.Nc:=Nc;
            if p.Tc=-1 then p.Tc:=Tc;
            if p.Dc=-1 then p.Dc:=Dc;
            if p.Mc=-1 then p.Mc:=Mc;
            if p.Nm=-1 then p.Nm:=Nm;
            if p.Tm=-1 then p.Tm:=Tm;
            if p.Dm=-1 then p.Dm:=Dm;
            if p.Mm=-1 then p.Mm:=Mm;
            if p.Ctax=-1 then p.Ctax:=Ctax;
            if p.Ntax=-1 then p.Ntax:=Ntax;
            if p.Cstat=-1 then p.Cstat:=Cstat;
            if p.Nstat=-1 then p.Nstat:=Nstat;
            if p.Ngovt=-1 then p.Ngovt:=Ngovt;
            if p.natives=-1 then p.natives:=natives;
            if p.Nrace=-1 then p.Nrace:=Nrace;
            if p.climate=-1 then p.climate:=climate;
            if p.build=-1 then p.build:=build;
          end;
          if (planet[k]=nil) or Diff(p,planet[k]^,SizeOf(PRec)) then
          begin
            if planet[k]=nil then
              begin CheckMem(SizeOf(PRec)); New(planet[k]) end;
            planet[k]^:=p;
            DataChg:=Yes;
          end;
          eplan[k].owner:=p.owner;
          eplan[k].when:=0; { yes! clear it again, because the 1st clear }
          eplan[k].activity:=0; { works for planets that were our last turn  }
          if p.build=1 then eplan[k].activity:=EP_Base;
          if NewTurn then newplan[k]:=newplan[k] or NP_See_It;
        end;
        CloseData(f);
      end;

      if NewTurn then
      begin
        for i:=1 to 500 do begin
          k:=eplan[i].owner;
          if (planet[i]=nil) and (eplan[i].activity=0) then k:=0
          else if planet[i]<>nil then
          begin
            k:=planet[i]^.owner;
            if ((k=player) or IsData[k]) and (planet[i]^.when<>today) then k:=0;
          end;
          if eplan[i].owner<>k then
          begin
            eplan[i].owner:=k;
            eplan[i].when:=0;
            eplan[i].activity:=0;
          end;
          buildq^[i] := 0;     {Reset last built ships to 0}
        end;

        for i:=1 to 500 do      { dispose old base data! }
          if base[i]<>nil then
            begin Dispose(base[i]); base[i]:=nil end;

        for i:=1 to 500 do      { clear old base builds }
          with planet[i]^ do
          if (planet[i]<>nil) and (when<>today) then build:=0;
        end;

        for r:=1 to 12 do
        if (r=12) or IsData[r] then
        begin
          racenr := IIF(r=12,player,r);
          OpenRW(f,xFName[Ba]+NStr(racenr)+'.DAT',Yes);
          BlockRead(f,n,2);
          for i:=1 to n do
          begin
            BlockRead(f,k,2);
            BlockRead(f,b.owner,BRecordSize-2);
            if (base[k]=nil) or Diff(b,base[k]^,SizeOf(BRec)) then
            begin
              if base[k]=nil then
              begin CheckMem(SizeOf(BRec)); New(base[k]) end;
              base[k]^:=b;
              DataChg:=Yes;
            end;
            eplan[k].owner:=b.owner;
            eplan[k].activity:=EP_Base;
            if b.owner=racenr then Inc(tmpscore[racenr][4]);
          end;
          CloseData(f);
        end;

        FillChar(HaveShip,SizeOf(HaveShip),0);

        for r:=1 to 12 do
        if (r=12) or IsData[r] then
        begin
          racenr := IIF(r=12,player,r);
          OpenRW(f,xFName[Sh]+NStr(racenr)+'.DAT',Yes);
          BlockRead(f,n,2);
          for i:=1 to n do
          begin
            BlockRead(f,k,2);
            FillChar(h,SizeOf(SRec),$FF);
            h.when:=today;
            h.ship_id:=k;
            BlockRead(f,h.owner,SRecordSize-2);
            if h.owner=racenr then begin
              if (h.weapons>0) or (h.bays>0) or (h.launchers>0)
               then Inc(tmpscore[racenr][2])
               else Inc(tmpscore[racenr][3]);
            end;
            BackTrack(ship[k],h,k,NewTurn and RWMode and KeepWayPoints and (h.owner=player));
            SetShipMass(h);
            if (ship[k]=nil) or Diff(h,ship[k]^,SizeOf(SRec)-2) then
            begin
              if ship[k]=nil then
              begin CheckMem(SizeOf(SRec)); New(ship[k]) end;
              ship[k]^:=h;
              DataChg:=Yes;
            end;
            HaveShip[k]:=Yes;
          end;
          CloseData(f);
        end;

        for r:=1 to 12 do
        if (r=12) or IsData[r] then
        begin
          OpenRW(f,'TARGET'+NStr(IIF(r=12,player,r))+'.DAT',Yes);
          BlockRead(f,n,2);
          for i:=1 to n do
          begin
            BlockRead(f,k,2);
            BlockRead(f,ht.owner,SizeOf(STRec));
            GetShipTarget(k,h,ht);
          end;
          CloseData(f);
          if OpenRW(f,'TARGET'+NStr(IIF(r=12,player,r))+'.EXT',No) then begin
            BlockRead(f,n,2);
            for i:=1 to n do
            begin
              BlockRead(f,k,2);
              BlockRead(f,ht.owner,SizeOf(STRec));
              GetShipTarget(k,h,ht);
            end;
            CloseData(f);
          end;
        end;

        for r:=1 to 12 do
        if (r=12) or IsData[r] then
        begin
          OpenRW(f,'SHIPXY'+NStr(IIF(r=12,player,r))+'.DAT',Yes);
          LargeSXY:=(FileSize(f)>=SizeOf(SVRec)*999);
          for k:=1 to 999 do
          if (k<=500) or LargeSXY then
          begin
            BlockRead(f,hv,SizeOf(SVRec));
            if HaveShip[k] then Continue;
            { Winplan999 unpacks *all* RSTs as Host999. When unpacking shipxy,
              it "runs into" the gen.dat image. Hence the first bogus ship has
              an X coordinate of >= $3030 (first two digits of timestamp).  -sr }
            if (k=501) and ((hv.x < 0) or (hv.x >= $3030)) then Break;
            if (hv.owner=0) or (hv.owner=player) or IsData[hv.owner] then Continue;
            FillChar(h,SizeOf(SRec),$FF);
            h.when:=today;
            h.owner:=hv.owner;
            h.x:=hv.x;
            h.y:=hv.y;
            h.ship_id:=k;
            if (ship[k]<>nil) and
            ((ship[k]^.when=today) or MayBeThatShip(ship[k]^,h,k)) then
            begin
              Move(ship[k]^,h,SizeOf(SRec));
              h.x:=hv.x;
              h.y:=hv.y;
              if h.when<>today then ClearAlienShip(h);
            end;
            h.when:=today;
            h.mass:=hv.mass;
            if (h.mass1=-1) or (hv.mass<h.mass1) then h.mass1:=hv.mass;
            if hv.mass>h.mass2 then h.mass2:=hv.mass;
            BackTrack(ship[k],h,k,No);
            if (ship[k]=nil) or Diff(h,ship[k]^,SizeOf(SRec)-2) then
            begin
              if ship[k]=nil then
              begin CheckMem(SizeOf(SRec)); New(ship[k]) end;
              ship[k]^:=h;
              DataChg:=Yes;
            end;
          end;
          CloseData(f);
        end;

        for r:=1 to 12 do
        if (r=12) or IsData[r] then
        begin
          if OpenRW(f,'KORE'+NStr(IIF(r=12,player,r))+'.DAT',No) then
          begin
            BlockRead(f,n,2);
            if n<>today then begin
              CloseData(f);
              Continue;
            end;
            Seek(f,$319E);  { extra targets }
            BlockRead(f,sig,4);
            if sig=ExtraTargetSig then
            begin
              Seek(f,$31B2);
              BlockRead(f,n,2);
              BlockRead(f,i,2); { skip +2 bytes }
              for i:=1 to n do
              begin
                BlockRead(f,k,2);
                BlockRead(f,ht.owner,SizeOf(STRec));
                for j:=1 to 20 do ht.name[j]:=char( byte(ht.name[j]) xor (byte($9B)-byte(j)) );
                GetShipTarget(k,h,ht);
              end;
            end;

            Seek(f,$1326);  { UFOs }
            for i:=1 to 100 do
            begin
              BlockRead(f,u.color,URecordSize);
              if u.color<>0 then
              begin
                u.when:=today;
                FillChar(u.px1,8,$FF);
                if ufo[i]<>nil then
                with ufo[i]^ do
                if when=today then Move(px1,u.px1,8) else
                if when=today-1 then
                begin
                  u.px1:=x; u.py1:=y;
                  u.px2:=px1; u.py2:=py1;
                end else
                if when=today-2 then
                begin u.px2:=x; u.py2:=y end;
                if (ufo[i]=nil) or Diff(u,ufo[i]^,SizeOf(URec)) then
                begin
                  if ufo[i]=nil then
                  begin CheckMem(SizeOf(URec)); New(ufo[i]) end;
                  ufo[i]^:=u;
                  DataChg:=Yes;
                end;
              end;
            end;
            CloseData(f);
          end;
        end;

        if NewTurn then       {Already NewTurn cheked}
        begin
          for k:=1 to 999 do  { clear lost our ships }
          with ship[k]^ do
          if (ship[k]<>nil) and (when<>today) and ((owner=player) or IsData[owner]) then
          begin EraseBoundMarkers(k); Dispose(ship[k]); ship[k]:=nil
        end;

        for k:=1 to 50 do { pre-clear old ion storms }
        if ion[k]<>nil then
        with ion[k]^ do
        begin
          px2:=px1; py2:=py1;
          px1:=x; py1:=y;
          radius:=0;
        end;

        for k:=1 to 500 do  { clear exhausted mine fields }
          if (mines[k]<>nil) and (mines[k]^.units<=0) then
            begin Dispose(mines[k]); mines[k]:=nil end;

        for k:=1 to nmark do  { clear marks bound to old msgs and lost ships }
        begin     { change bound marks' coordinates }
          i:=-mark^[k].bind;
          if i<0 then EraseMark(k) else
          if i>0 then
            if ship[i]=nil then EraseMark(k)
            else begin mark^[k].x:=ship[i]^.x; mark^[k].y:=ship[i]^.y end;
          end;
        end;

        for k:=1 to 500 do
        if eplan[k].owner=255 then eplan[k].owner:=0;
        if RWMode then
        begin
          OpenRW(f,xFName[Pl]+plstr+'.DIS',Yes);
          BlockRead(f,n,2);
          PDisN:=n;
          k:=n*SizeOf(PDRec);
          CheckMem(k);
          GetMem(PDis,k);
          for i:=1 to n do
          begin
            BlockRead(f,p.owner,2); { owner MUST BE = player here }
            BlockRead(f,k,2);
            BlockRead(f,p.fcode,PRecordSize-4);
            with PDis^[i] do
            begin
              id:=k;
              mines:=p.mines;
              factories:=p.factories;
              defense:=p.defense;
              supplies:=p.supplies;
            end;
          end;
          CloseData(f);
          OpenRW(f,xFName[Ba]+plstr+'.DIS',Yes);
          BlockRead(f,n,2);
          BDisN:=n;
          k:=n*SizeOf(BDRec);
          CheckMem(k);
          GetMem(BDis,k);
          for i:=1 to n do
          begin
            BlockRead(f,k,2);
            BlockRead(f,b,BRecordSize-2);   { owner MUST be = player }
            with BDis^[i] do
            begin
              id:=k;
              fpos:=FilePos(f)-BRecordSize+2;
              TF[0]:=b.fighters;
              Move(b.TT[1],TF[1],10*2);
            end;
          end;
          CloseData(f);
          OpenRW(f,xFName[Sh]+plstr+'.DIS',Yes);
          BlockRead(f,n,2);
          for i:=1 to n do
          begin
            BlockRead(f,h,SRecordSize); { h.when = id here }
            if (h.owner=player) and (h.Sup+h.CS+h.TS+h.TFnum<>0) then
            begin
              r:=PSearchXY(h.x,h.y);
              if r<>0 then
              begin
                k:=PDSearch(r);
                if k<>0 then inc(PDis^[k].supplies,h.Sup+h.CS+h.TS);
                k:=BDSearch(r);
                if k<>0 then inc(BDis^[k].TF[h.Tl],h.TFnum);
              end;
            end;
          end;
          CloseData(f);
        end;

      for r:=1 to 12 do     { player MUST be the last }
        if (r=12) or IsData[r] then { (to merge other races' e-mail first) }
          ReadMessages(IIF(r=12,player,r),NewTurn);
      if MCRC<>nil then FreeMem(MCRC,MCRC^[1]*2);
      if VCRC<>nil then FreeMem(VCRC,VCRC^[1]*2);

      if NewTurn then
      begin
        { THost: the built-in score blanker zaps all scores, and gives
          us not even our own score. So we count them and use that.
          PHost: the built-in score blanker does send us our own score,
          so our counting would not improve anything. Worse yet, PHost
          has remote control so we might count wrong (i.e. if we have
          20 ships, we might only own 18 of them). }
        if not PHOST then MergeScores(TEnd^.score, tmpscore);

        { Read mine field information from KOREx.DAT. }
      n:=0;
      for r:=1 to 11 do
        if Race[r]=7 then begin inc(n); web_race:=r end;
      web_unk:=(n<>1);
      FillChar(kore_r,SizeOf(kore_r),0);
      FillChar(kore_m,SizeOf(kore_m),0);
      for r:=1 to 12 do
      if (r=12) or IsData[r] then
      begin
        k:=IIF(r=12,player,r);
        if OpenRW(f,'KORE'+NStr(k)+'.DAT',No) then
        begin
          BlockRead(f,n,2);
          if n<>today then Continue;
          kore_r[k]:=Yes;
          Seek(f,$66);
          for i:=1 to 500 do
          begin
            BlockRead(f,mk,SizeOf(MKRec));
            if mk.owner<>0 then
            begin
        kore_m[i]:=kore_m[i] or (1 shl k);
    {writeln('kore mines: id=',i,'  race=',mk.owner,'  radius=',mk.radius);}
        if mines[i]<>nil then m:=mines[i]^
        else begin
          CheckMem(SizeOf(MRec));
          New(mines[i]);
          m.when:=0;
          m.owner:=0;
          m.units:=0;
          m.web:=0;
        end;
        if mk.owner=12 then
        begin
          m.web:=m.web or 1;
          if not web_unk then mk.owner:=web_race;
        end;
        if not ( (mk.owner=12) and (m.owner<>12) and
           (m.x=mk.x) and (m.y=mk.y) ) then m.owner:=mk.owner;
        m.x:=mk.x;
        m.y:=mk.y;
                    {Calculate mine decay for this turn, since it is included in
                     kore.dat but *not* in our mine-scan messages. TODO: Is this
                     the same with PHost?}
                    decayed:=DecayMineUnits( m.units, (m.web and 1=1) );
                    {Check whether kore.dat or message information is more precise.}
        if ( (m.when=today) and (m.web and 2=0) and (Round(Sqrt(decayed))=mk.radius) ) then begin
                      {Message is more precise but does not contain this turn's mine decay.
                       The latter is noted in bit 3:}
                      m.web:=m.web or 4;
                    end else begin
          {m.units:=long(mk.radius)*long(mk.radius+1);}
                      {writeln('mine mismatch: t',m.when,' #',i,': ',m.units,' ',mk.radius,' (',m.x,',',m.y,')');}
          m.units:=long(mk.radius)*long(mk.radius);
          m.web:=m.web or 2; {Information from kore.dat.}
                      m.web:=m.web and not 4;
        end;
        m.when:=today;
        mines[i]^:=m;
        DataChg:=Yes;
            end;
          end;
          CloseData(f);
        end;
      end;
    end;

      if NewTurn then
      begin
        for k:=1 to 500 do  { check old mines }
          if (mines[k]<>nil) and (mines[k]^.when<>today) then
            for i:=1 to 999 do
              with ship[i]^ do
              if (ship[i]<>nil) and (when=today) and
           ((owner=player) or IsData[owner]) and (mission=2) and (px1<>-1) and
           ( Sqrt(Distance2(px1,py1,mines[k]^.x,mines[k]^.y)) <=
             Sqrt(mines[k]^.units)+DetectMineRange          ) then
              begin
          Dispose(mines[k]);
          mines[k]:=nil;
          Break;
        end;
        for k:=1 to 500 do  { check newly-swept mines }
          if (mines[k]<>nil) and (mines[k]^.when=today) then
            for i:=1 to 999 do
              with ship[i]^ do
              if (ship[i]<>nil) and (when=today) and
           ((owner=player) or IsData[owner]) and (mission=2) and (px1<>-1) and
           kore_r[owner] and (kore_m[k] and (1 shl owner)=0) and
           ( Sqrt(Distance2(px1,py1,mines[k]^.x,mines[k]^.y)) <=
             Sqrt(mines[k]^.units)+DetectMineRange          ) then
              begin
          mines[k]^.units:=0;
          Break;
              end;
        for k:=1 to 50 do { clear old ion storms }
          if (ion[k]<>nil) and (ion[k]^.radius=0) then
            begin Dispose(ion[k]); ion[k]:=nil end;
              if Not AltWormholes then
        for k:=0 to 199 do      { check active wormholes }
          if (worm[k]<>nil) and (worm[k]^.when<>today) then
            for i:=1 to 999 do
              with ship[i]^ do
              if (ship[i]<>nil) and (when=today) and
           ((owner=player) or IsData[owner]) and (fcode='WRS') and
           ( Sqrt(Distance2(x,y,worm[k]^.x,worm[k]^.y)) <=
             Exp(Ln(worm[k]^.mass)/3)*10          ) then
                    if not PHOST then
              begin
          Dispose(worm[k]);
          worm[k]:=nil;
          Break;
              end
                    else
                    {PHOST}
                    begin
                    CanDelete:=True;
                    {if there are 2 or more wormholes in range don't delete them.}
              for kk:=0 to 199 do      { check active wormholes }
                if (worm[kk]<>nil) and (kk <> k) then
                        if ( Sqrt(Distance2(x,y,worm[kk]^.x,worm[kk]^.y)) <=
                   Exp(Ln(worm[kk]^.mass)/3)*10          ) then
                                  CanDelete:=False;  { next wormhole found in range}
                    { Now check if ship can scan all wormholes }
                    { If ship does full wormhole scan, wormhole can be deleted}

                    {$IFDEF VPACC}
                      { FIXME. What to do here? Sorry guys, I don't really understand
                        what is going on here. }
                    {$ELSE}
                    for ii:=1 to HullFN do
                    begin
                      hf:=HullFunc^[ii];
                      if Lo(hf)=hull then
                      begin
                        if (HullFuncs(Hi(hf))=hfAllWormScan) and not Wormholes then Continue;
                        CanDelete:=True;
                      end;
                    end;
                    {$ENDIF}

                    if CanDelete then
                    begin
          Dispose(worm[k]);
          worm[k]:=nil;
          Break;
        end;
      end;
      for k:=1 to 100 do      { check visible UFOs }
        if (ufo[k]<>nil) and (ufo[k]^.when<>today) then
        begin
          j:=ufo[k]^.x; r:=ufo[k]^.y;
          for i:=1 to 999 do
            with ship[i]^ do
            if (ship[i]<>nil) and (when=today) and
         ((owner=player) or IsData[owner]) and
         ( Distance2(x,y,j,r) <= Sqr(long(ufo[k]^.rangeS)) ) then
            begin
        Dispose(ufo[k]);
        ufo[k]:=nil;
        Break;
            end;
         if ufo[k]<>nil then
          for i:=1 to 500 do
            with planet[i]^ do
            if (planet[i]<>nil) and (when=today) and
         ((owner=player) or IsData[owner]) and
         ( Distance2(xyplan[i,1],xyplan[i,2],j,r) <= Sqr(long(ufo[k]^.rangeP)) ) then
            begin
        Dispose(ufo[k]);
        ufo[k]:=nil;
        Break;
      end;
    end;
        { Adjust ship speeds - no change for warp 0 or 1 }
        if (AutoAdjustWarp) then begin
          for i:=1 to 999 do with ship[i]^ do begin
            if (ship[i]<>nil) and (when=today) and
               ((owner=player) or IsData[owner]) and AutoAdjustWarp and
               (ship[i]^.warp > 1)
            then warp := GetOptimalWarp(ship[i]);
          end;
        end;
      end; { if new turn }

      if Diff(eplan,ep,SizeOf(eplan)) then DataChg:=Yes;

      VPACTLIST_INI:='VPACTL'+plstr+'.INI';
      if OpenRW(f,VPACTLIST_INI,No) then
      begin
        BlockRead(f,actlist,SizeOf(actlist));
        CloseData(f);
      end;
      if actlist[0] <> today then
      begin
        FillChar(actlist,SizeOf(actlist),0);
        actlist[0] := today;
      end;
    end;

    ExtFeatReadDataHook;
  end;

procedure OpenGraph;
  var gd,gm : int;
  s : string[6];
  f : file;
  procedure GrErr (err:int);
    begin
      if err>=0 then Exit;
      err:=GraphResult;
      if err=grOk then Exit;
      Writeln('Graphics initialization failure'{,GraphErrorMsg(err)});
      Halt;
    end;
  begin
    LoadAlternateFont;
    OpenFile(f,ResName,0,Yes);
    CloseData(f);
    FillChar(ScreenPos,SizeOf(ScreenPos),0);
    VPASCR_INI:='VPASCR'+plstr+'.INI';
    if OpenRW(f,VPASCR_INI,No) then
    begin
      gd:=FileSize(f);
      if gd=VPASCR_Size then
      begin
  BlockRead(f,ratioN,SizeOf(VPAScr)-2);
  BlockRead(f,force,2);
  if force<>0 then ForceKey:=13;
  BlockRead(f,ScreenPos,SizeOf(ScreenPos));
      end;
      CloseData(f);
      if gd<>VPASCR_Size then Erase(f);
    end;
    InitRatios;
    GrMode0:=3;   { sin BIOS en Linux; CloseGraph gestiona la restauracion }

    { --- Init grafica con ptcgraph (Linux): no usa drivers .bgi; se elige el
          modo nativo directamente. 640x480, 256 colores. --- }
    gd := D8bit;
    gm := m640x480;
    InitGraph(gd, gm, '');
    GrErr(-1);
    GrMode:=Yes;
    { Cargar la fuente vectorial de las etiquetas del mapa (en DOS venia como
      litt_vpa.obj enlazado como SmallFont; aqui se carga el .CHR equivalente).
      Si falla la carga, queda SmallFont (comportamiento anterior). }
    LittFont := InstallUserFont('LITT_VPA.CHR');
    if LittFont <= 0 then LittFont := SmallFont;
    {$IFDEF UNIX}DbgFont(LittFont);{$ENDIF}
   {$IFDEF VPAMM}
    { VPA/MM behaves as SVGA most of the time: we need to do manual
      text output, and mouse cursor }
    useSVGA := TRUE;
   {$ENDIF}

    SetColor(cmDist);
    Circle(4,4,4);
    GetMem(BrownC,ImageSize(0,0,8,8));
    GetImage(0,0,8,8,BrownC^);
    Clear(0,0,8,8);
    DrawRightScreen;
    SetColor(LightMagenta);
    OutTextXY(MX0+3*8+4,20*8,'VGA PLANETS');
    OutTextXY(MX0+2*8,22*8,'ASSISTANT '+Version);
    SetLineStyle(SolidLn,0,NormWidth);
    Line(MX0+3*8+4,21*8,MX0+3*8+4+11*8-2,21*8);
    Line(MX0+2*8,23*8,MX0+2*8+14*8-2,23*8);
    SetColor(Cyan);
    OutTextXY(MX0,26*8,   'Copyright (c) 1998');
    OutTextXY(MX0,26*8+12,' by Alex V. Ivlev');
    OutTextXY(MX0,26*8+30, '  (c) 2002-2014');
    OutTextXY(MX0,26*8+42, '    VPA Group');
    SetColor(Blue);
    OutTextXY(MX0,46*8,'  VGA Planets game');
    OutTextXY(MX0,47*8,'       was created');
    OutTextXY(MX0,48*8,'   by Tim Wisseman');
    OutTextXY(MX0,49*8,'     (c) 1991-1998');
  end;

procedure CheckOutMap;
  var h : sptr;
  i,k,xx,yy,xy1 : int;
  was,mw0   : boolean;
  x00,y00   : int;
  begin
    SetColor(LightRed);
    ratio1:=10;
    ratio2:=1;
    MapSSize:=MapSize div 10;
    xy1:=(480-MapSSize) div 2;
    x00:=x0; x0:=0;
    y00:=y0; y0:=0;
    mw0:=MapWrap; MapWrap:=No;
    was:=No;
    with TEnd^.data^ do
    for k:=1 to 999 do
    if ship[k]<>nil then
    with ship[k]^ do
      if (when=today) and ((x<MapX0) or (x>MapY0) or (y<MapX0) or (y>MapY0)) then
      begin
  if not was then
  begin
    for i:=1 to 500 do
    if xyplan[i,1]<>-1 then
    begin
      Abs2Scr(xyplan[i,1],xyplan[i,2],xx,yy);
      PutPixel(xy1+xx,xy1+yy,White);
    end;
    SetColor(DarkGray);
    Rectangle(xy1-1,xy1-1,480-xy1,480-xy1);
    SetColor(LightRed);
    OutTextXY(148,32,'A T T E N T I O N ! ! !');
    OutTextXY(116,56,'THERE ARE SHIPS OUTSIDE OF MAP!');
    was:=Yes;
  end;
  Abs2Scr(x,y,xx,yy);
  PutPixel(xy1+xx,xy1+yy,LightRed);
  Circle(xy1+xx,xy1+yy,1);
      end;
    if was then
    begin
      repeat until KeyPressed or (mEvent=EvLtPress);
      if KeyPressed then ReadKey;
    end;
    InitRatios;
    x0:=x00; y0:=y00;
    MapWrap:=mw0;
  end;

procedure InitMouse;
begin
  if useSVGA OR not MousePresent then
    GetMem(Cross0,ImageSize(0,0,14,14));
  if MousePresent then
  begin
    EnableMouse;
    SetMouseRange(0,0,479,479);
    if useSVGA then
    begin
      HideMouse;
      HookMouseEvent(EvMouseMove,@MouseMotionHandler)
    end
    else
    begin
        SetPointerShape(CrossPointer,7,7);
        HookMouseEvent(EvMouseMove,@MouseHandler);
      end;
    HookMouseEvent(EvLtPress,@MouseHandler);
    HookMouseEvent(EvRtPress,@MouseHandler);
    HookMouseEvent(EvCtPress,@MouseHandler);
    AllocateStatusBuffer;
    SaveMouseStatus;
  end;
  MoveMouse(240,240);
  MouseOn;
  Scr2Abs(MouseX,MouseY,mmx,mmy);
end;

function DecryptPassword (var f:file) : PwdStr; { f must be open and seeked }
  var a : PwdType;
  p : PwdStr;
  lp  : byte absolute p;
  i,c : byte;
  begin
    BlockRead(f,a,20);
    lp:=0;
    for i:=1 to 10 do
    begin
      c:=a[1,i]-a[2,11-i]+32;
      if (c>31) and (c<127) then p:=p+char(c) else Break;
    end;
    DecryptPassword:=p;
  end;

function HavePassword (s:PwdStr) : boolean;
  var i : byte;
  begin
    HavePassword:=No;
    for i:=1 to passwn do
      if s=ppassw[i] then begin HavePassword:=Yes; Break end;
  end;

procedure CheckDataFiles;
  var f,g : file;
  xt  : xtype;
  i,j : int;
  regdata : array [1..51] of long;
  regd  : array [1..2,1..25] of long absolute regdata;
  sums  : array [xtype] of long;
  stmp  : TimeStamp;
  s : string[12];
  begin
    FillChar(IsData,SizeOf(IsData),No);
    DFiles:=OpenRW(f,'GEN'+plstr+'.DAT',No);
    if not DFiles then Exit;

    s:=RaceName[player]; Trim(s);
    Writeln(s,' data files found');
    BlockRead(f,Stamp,SizeOf(TimeStamp));
    Seek(f,$6A);
    BlockRead(f,i,2);
    if i<>player then
      begin Writeln('ERROR: File ',addir,'GEN',plstr,'.DAT is invalid'); Halt end;
    Seek(f,$99);
    BlockRead(f,today,2);
    CloseData(f);

    if OpenRW(f,'NEXTTURN.HST',No) then
    begin
      BlockRead(f,stmp,SizeOf(TimeStamp));
      BlockRead(f,i,2);
      CloseData(f);
      if (stmp=Stamp) and (i=today) then
      begin
  Writeln('Running in HOST mode. Password protection is OFF');
  HostMode:=Yes;
      end;
    end;

    if RWMode then
      if not OpenRW(f,FIZZ_BIN,No) then OpenW(f,FIZZ_BIN,Yes);
    for i:=1 to 11 do
    begin
      FillChar(sums,SizeOf(sums),0);
      if OpenRW(g,'GEN'+NStr(i)+'.DAT',No) then
      begin
  if ReadAll and (i<>player) then
  repeat
    s:=RaceName[i]; Trim(s);
    Write(s,' data also found');
    BlockRead(g,stmp,SizeOf(TimeStamp));  { XREF to CheckNewRST }
    Seek(g,$99);
    BlockRead(g,j,2);
    if (stmp<>Stamp) or (j<>today) then
      begin Writeln(' ...but it is from another turn'); Break end;
    Seek(g,$6A);
    BlockRead(g,j,2);
    if j<>i then
      begin Writeln(' ...but it is invalid'); Break end;
    if not HostMode then
    begin
      Seek(g,$8D);
      BlockRead(g,j,2);
      Seek(g,$6C);
      s:=DecryptPassword(g);
      if (j=13) or ((s<>NoPassword) and not HavePassword(s))then
        begin Writeln(' ...but it is password-protected'); Break end;
    end;
    Writeln;
    IsData[i]:=Yes;
  until Yes;
  Seek(g,$81);
  BlockRead(g,sums,12);
  CloseData(g);
      end;
      for xt:=Sh to Ba do inc(sums[xt],xFizz[xt]);
      if RWMode then BlockWrite(f,sums,12);
    end;

    if RWMode then
    begin
      sums[Sh]:=0;
      BlockWrite(f,sums[Sh],4);
      for j:=1 to 2 do
      for i:=1 to 25 do
  regd[j,i]:=long(PlanetsRegInfo[j,i])*i*13;
      regdata[51]:=668;
      for i:=1 to 50 do
  inc(regdata[51],regdata[i]);
      Seek(f,$88);
      BlockWrite(f,regdata,51*4);
      CloseData(f);
    end;
  end;

procedure CheckNewRST;
  var r,j,t : int;
  f : file;
  l : long;
  stmp  : TimeStamp;
  rsts  : array [1..11] of boolean;
  yesrst  : boolean;
  begin
    if today>0 then Writeln('Current turn is ',today,' [host date: ',Copy(Stamp,1,10),' ',Copy(Stamp,11,8),']');

    if OpenRW(f,'PLAYER'+plstr+'.RST',No) then
    begin
      Seek(f,$18);
      BlockRead(f,l,4);
      Seek(f,l-1);
      BlockRead(f,stmp,SizeOf(TimeStamp));
      Seek(f,l-1+18+88);
      BlockRead(f,j,2);
      Seek(f,l-1+18+88+2+20+12);
      BlockRead(f,t,2);
      CloseData(f);
      if (j=player) and (stmp<>Stamp) then  { new RST! }
      begin
  Writeln(#13#10'New RST file(s) found! (turn ',t,' [host date: ',Copy(stmp,1,10),' ',Copy(stmp,11,8),'])');
  if not Batch then
  begin
    Write('Unpack (y/n) ? ');
    yesrst:=YesNo;
    Writeln;
  end
  else yesrst:=Yes;
  if yesrst then
  begin
    for r:=1 to 11 do UnpackRST(r);
    CheckDataFiles; { re-check data files }
    Exit;     { don't check for additional RSTs }
  end;
      end;
    end;

    if ReadAll then { scan for additional current turn's RSTs }
    begin
      FillChar(rsts,11,No);
      yesrst:=No;
      for r:=1 to 11 do
      if (r<>player) and (not IsData[r]) and OpenRW(f,'PLAYER'+NStr(r)+'.RST',No) then
      begin
  Seek(f,$18);
  BlockRead(f,l,4);
  Seek(f,l-1);
  BlockRead(f,stmp,SizeOf(TimeStamp));
  Seek(f,l-1+18+88);
  BlockRead(f,j,2);
  Seek(f,l-1+18+88+2+20+12);
  BlockRead(f,t,2);
  CloseData(f);
  if (j<>r) or (t<>today) or (stmp<>Stamp) then Continue;
  if OpenRW(f,'GEN'+NStr(r)+'.DAT',No) then
  begin
    BlockRead(f,stmp,SizeOf(TimeStamp));  { XREF to CheckDataFiles }
    Seek(f,$99);
    BlockRead(f,t,2);
    Seek(f,$6A);
    BlockRead(f,j,2);
    CloseData(f);
    if (j=r) and (t=today) and (stmp=Stamp) then Continue;
  end;
  rsts[r]:=Yes;
  yesrst:=Yes;
      end;
      if yesrst then
      begin
  Write(#13#10'Additional RST file(s) found for race(s):');
  for r:=1 to 11 do
    if rsts[r] then Write(' ',r);
  Writeln;
  if not Batch then
  begin
    Write('Unpack (y/n) ? ');
    yesrst:=YesNo;
    Writeln;
  end;
  if yesrst then
  begin
    for r:=1 to 11 do
      if rsts[r] then UnpackRST(r);
    CheckDataFiles; { re-check data files }
  end;
      end;
    end;
  end;

procedure CheckPassword;
  var f : file;
  i : int;
  s : string[12];
  ls  : byte absolute s;
  ch  : word;
  begin
    if HostMode then begin Password:=NoPassword; Exit end;
    repeat      { extracting password }
      if DFiles then
      begin
  OpenRW(f,'GEN'+plstr+'.DAT',Yes);
  Seek(f,$8D);
  BlockRead(f,i,2);
  if i=13 then
  begin
    BlockRead(f,Password[1],10);
    i:=1;
    repeat
      dec(byte(Password[i]),50);
      if Password[i]=#0 then Break;
      inc(i);
    until i>10;
    Password[0]:=char(i-1);
    Break;
  end;
  Seek(f,$6C);
      end
      else if PWpos<>0 then
      begin
  OpenRW(f,dbname,Yes);
  Seek(f,PWpos);
      end
      else Exit;
      Password:=DecryptPassword(f);
    until Yes;
    CloseData(f);
    if Batch and (frm[0]=#0) then Exit;
    if Password=NoPassword then Exit;
    if (passwn=0) and (not Batch) then
    begin
      s:=RaceName[player]; Trim(s);
      Write(#13#10'Enter the ',s,' password: ');
      ls:=0;
      repeat
  ch:=ReadKey;
  case ch of
    32..255 : begin inc(ls); s[ls]:=char(ch); Write('*') end;
    8 : if ls>0 then begin dec(ls); Write(#8' '#8) end else Write(#7);
    13,27 : ;
    else  Write(#7);
  end;
      until (ls=10) or (ch=13) or (ch=27);
      Writeln(#13#10);
      ppassw[1]:=s;
      inc(passwn);
    end;
    if not HavePassword(Password) then
      begin Writeln('Invalid password. Access denied.'); Halt end;
  end;

procedure InitHelp;
  begin
    OpenFile(helpfile,HelpName,0,Yes);
  end;

procedure LoadDistanceTable;
  var f : file;
      r : word;
  begin
    New(distance_table);
    OpenData(f, 'disttabl.dat', Yes);
    BlockRead(f, distance_table^, Sizeof(TDistanceTable), r);
    if r <> Sizeof(TDistanceTable) then begin
      writeln('File ''disttabl.dat'' is damaged, exiting.');
      halt(1);
    end;
    Close(f);
  end;

procedure InitMarkers;
  var i : MarkType;
  begin
    MarkXAlg := CenterText;
    MarkYAlg := TopText;
    for i := mrkNone to LastMark do begin
      MarkGroup[i] := '123456789ABCDEF';
    end;
    LastMarkMask := 0;
    MarkMask[0] := '*';
    CurMarkMask := 0;
  end;

function StartVPA : boolean;
  begin
    ini_initialize;
    InitVPAData;
{    Writeln(ReadKey); Writeln(ReadKey); Writeln(ReadKey); writeln(readkey); readkey;}
  Writeln(#13#10'-= VGA Planets Assistant '+Version+'  (c) 1993-98 Alex V. Ivlev, 2002-14 VPA Team =-');
  Writeln(      '=============================================================================='#13#10);
  Parameters;
  Writeln('Running with ',MemAvail div 1024,'K of free memory');
  Writeln;
  CheckPlanetsRegistration;
  InitMarkers;
  ReadConfig1;
  Ini_Read(ini_file_cmistakes);
  Ini_Read(ini_file_addon);
	Ini_Read(ini_file_vpahelp);
	Check_VPAHelp;
  LoadPlanetsData;
  CheckDataFiles;
  CheckNewRST;
  { (bloque asm original: codigo muerto, el jmp saltaba los mov; eliminado) }
  if not DFiles then RWMode:=Off;
    ReadData; { includes CheckPHOST, ReadConfig2 and MapInit }
  { XYPLANn must not be sent in UTILn, because ReadMessages needs it }
    Config.InitHullFunc;
    ReadKillfile;
    SetTurn(today);
    if PHOSTcli and DFiles then CheckPHOSTMessage;
    CheckPassword;
    if not PHost then LoadDistanceTable;
    {$IFDEF TASKS}
    if DFiles then TaskInit;
    {$ENDIF}
  {if DoVCL then ExecuteCommands;}
    if frm[0]<>#0 then WriteReport(frm,rep);
    StartVPA:=not Batch;
    ExtFeatStartVPAHook;
    if not Batch then
    begin
    if GPause then PressAnyKey;
      InitHelp;
      { (apagaba CapsLock via BIOS; no aplica en Linux) }
      OpenGraph;
      {$IFDEF UNIX}GrabInputFocus;{$ENDIF}   { reclamar foco de teclado para la ventana ptcgraph }
      {$IFDEF UNIX}ApplyWindowScale;{$ENDIF}  { ventana mas grande opcional (VPA_SCALE=N), redimensionando NUESTRA ventana }
      InitMouse;
      if NewTurn then CheckOutMap;
    end;
    CheckMem(ReservedMemory);
    LockReservedMemory;   { VPAExit (SaveData) needs it! }
    MaySave:=Yes;
  end;

End.
