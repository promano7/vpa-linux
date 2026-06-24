{
*******************************************************************
* Extended Features for VPA
*  2004 by Christian Graefe
* based on 'CGExtensions to VPA' version 0.38 for VPA 3.61e
* (c) 2003 by Christian Graefe <cg@graefe.net>
* (c) 2013 by VPA-Team
*
* $Id: extfeat.pas,v 1.29 2013/12/29 06:41:03 sfplanets Exp $
*
* The features implemented here originate from an extension to VPA
* formerly known to only a few people as 'CGExt'. They have been
* merged with the main source tree and will no longer be maintained.
* separately.
*
*******************************************************************
}

{$I switches.inc}
unit ExtFeat;
{$V-}

interface

uses    AuxF,Strf,VPAData,Mouse,Keyboard,Messages,Config,TCombat,ptcgraph,Screen,Building;

const
  CGExtVersion = '0.38';

  CheckMarkChar          = Chr(251);
  CheckMarkColor         = Yellow;

  NoteIconColor          = White;
  NoteIconColorInactive  = DarkGray;

  MaxPopulation          = 100000;

  ShowMapBorder          : boolean = Yes;
  ShowColonistPrediction : boolean = No;
  ShowCheckMark          : boolean = Yes;
  ShowScoreValue         : boolean = No;
  AutoDisapprove         : boolean = No;
  ConfirmNotes           : boolean = No;
  ScoringMethod          : str20   = 'AutoScore';

{hooks}
procedure ExtFeatStartVPAHook;
procedure ExtFeatQuitVPAHook;
procedure ExtFeatKeyHook( ch: word );
procedure ExtFeatInfoDisplayHook;
procedure ExtFeatDrawMapBeginHook;
procedure ExtFeatDrawMapEndHook;
procedure ExtFeatSaveAllHook;
function ExtFeatReadConfigFileHook( s: string; sec:cfgSec ): boolean;
procedure ExtFeatReadDataHook;
procedure ExtFeatChangeDataHook(xt:xtype; n:int);
procedure ExtFeatBuildingWriteCalcHook(Hn,En,blW,Wn,blT,Tn: int);
procedure ExtFeatUnpackRSTEndHook(race: int);
function ExtFeatReadMessagesHook(sender:byte; m:Msg): boolean;

{quality assurance aka. actual list}
procedure ShowQAOverview(filter : byte);
procedure DrawCheckMark(x,y:int; c:byte);

{planet connections}
procedure DrawConnections(dist:int; color:byte; dist_is_warp:boolean);
procedure ShowConnections;

{needed internally}
procedure ExtFeatTransmitDataChoose(name:str20; obj:pointer; size:word);
procedure BuildConnectionData(dist: long; dist_is_warp: boolean);
function GetShipScoreCurrent(ship: sptr): long;
procedure DrawNoteIcon(x,y:int; c:byte);
function HasNote(item:int): boolean;
function GetActList( obj: int ): boolean;

{misc}
function TRound( d: double ): long;
function DecayMineUnits( units: long; web: boolean ): long;
function MineRadius( units: long ): int;
function SupplyProduction(p: pptr): long;     

{PlanetEconomy}
procedure ReCalcPlanet (new: pptr; old: pptr);
procedure ReCalcDecay (new: pptr; old: pptr);

implementation

uses    VPA2,VPA3,MsgRead,VPA4;

type
  DataMsgPtr = ^DataMsgBuf;
  DataMsgBuf = array [0..MaxOSize-1] of word;

  ResStatPtr = ^ResStatRec;
  ResStatRec = record
                 prev,next    : ResStatPtr;
                 race, turn   : int;
                 colonists0,colonists1     : long;
                 natives0,natives1         : long;
                 mines0                    : int;
                 factories0                : int;
                 defenses0                 : int;
                 supplies0,supplies1       : long;
                 funds0,funds1             : long;
                 N0,N1,N2,
                 T0,T1,T2,
                 D0,D1,D2,
                 M0,M1,M2                  : long;
                 planets0                  : int;
                 bases0,bases1             : int;
                 ships0,ships1             : int;
               end;

  BCLinePtr  = ^BCLine;
  BCLine     = record
                 prev,next    : BCLinePtr;
                 turn         : int;
                 pid          : int;
                 p            : pptr;
               end;

  NotePtr    = ^Note;
  Note       = record
                 next        : NotePtr;
                 item        : int;
                 lines       : byte;
                 text        : array [1..20] of string[16];
               end;

  ItemNotesPtr = ^ItemNotes;
  ItemNotes  = record
                 prev,next  : ItemNotesPtr;
                 turn       : int;
                 root       : NotePtr;
               end;

  FleetReportPtr = ^FleetReportArr;
  FleetReportArr = array[1..999] of int;

  CGExtDXCSec  = (dxcsPlanets,dxcsUnknown);

const
  ConnectionDist   : int   = 9;
  cConn            : byte  = DarkGray;

  qaDisplayN          = 14;
  qaHeight            = 3*8+3;
  qaDataChg : boolean = No;

  dist0                 : int = 9;
  tmpConnDist           : int = -1;

  StatListMax        = 10;
  StatMaskValue      = $00FF;
  StatMaskVariant    = $FF00;

  TransmissionMarker = '<<< VPA Data Transmission >>>';
  MaxOSize  = 10*40;

  BCStrategiesN      = 5;
  BCStrategies       : array[1..BCStrategiesN] of str20 =
                       ('none','Borg Growth Opt.','Borg Constant Tax','Growth Optimized','Constant Tax');

  NoteX              = 63;
  NoteY              = 12;
  NoteCols           = 16;
  NoteLines          = 20;
  NoteLineHeight     = 10;
  NoteKeyY           = (NoteY+NoteLines+1)*NoteLineHeight+10;
  NoteDataChg        : boolean = No;

  DXC_PREFIX         : array [1..6]  of char = 'VPADXC';
  DXC_POSTFIX        : array [1..4]  of char = '.INI';
  DXC_RACE_CHAR      : array [1..11] of char = '123456789ab';

  CGExtDXCSecNames: array [1..10] of char =
      'PLANETS  ';

  PlayerRSTUnpacked  : boolean = false;

var
  qaCursor              : int;
  qaOffset              : int;
  qaItemCount           : int;

  currentStatRace       : int;
  statOwnRoot           : ResStatPtr;
  statRoot              : ResStatPtr;
  statList              : array[1..StatListMax] of int;

  bcRoot                : BCLinePtr;
  bcFilename            : String[64];
  bcStrat               : byte;

  itemNotesRoot         : ItemNotesPtr;

  fleetReport           : FleetReportPtr;

{** new config values **}

type
  ScoringMethodKey = (smAutoScore,smPTScore,smUnknown);
  CGExtCfgKey  = (extCConnection,extConnectionDist,extShowMapBorder,extAutoDisapprove,
                  extShowColonistPrediction,extScoringMethod,extShowCheckMark,
                  extShowScoreValue,extConfirmNotes,kUnknown);

const
  ScoringMethodNames      : array[1..20] of char = 'AUTOSCORE PTSCORE   ';
  ScoringMethodLabels     : array[smAutoScore..smUnknown] of str8 = ('AScore','PTScore','unknown');
  ScoringMethodLongLabels : array[smAutoScore..smUnknown] of str20 = ('AutoScore','PTScore','unknown');
  CGExtKeyNames: array [1..135] of char =
      'CONNECTION CONNECTIONDIST SHOWMAPBORDER AUTODISAPPROVE SHOWCOLONISTPREDICTION SCORINGMETHOD SHOWCHEC'+
      'KMARK SHOWSCOREVALUE CONFIRMNOTES  ';

{** territory ** }

const
  MAX_NEIGHBORS   = 60;

type
  PConnPtr = ^PConn;
  PConn  = record
            id          : int;
            neighbor    : array[1..MAX_NEIGHBORS] of int;
           end;
  {We need to allocate this dynamically since free memory in the data segment
   is very rare...}
  PConnArrPtr = ^PConnArr;
  PConnArr = array[1..500] of PConnPtr;
var
  {pCon           : array[1..500] of PConnPtr;}
  pCon           : PConnArrPtr;
  pConDist       : int;
  pConDistIsWarp : boolean;
  pConTurn       : int;
  dummyShip      : sptr;
      

{*****************************************************************************}
{** common ** }

procedure TestSound;
var i:int;
begin
  for i:=1 to 50 do
  begin
    Sound(100+Random(500));
    Delay(5);
  end;
  NoSound;
end;

procedure TestChar;
var i,j:int;
begin
  for i:=0 to 15 do
    for j:=0 to 15 do
      OutTextXY(i*8,j*8,Chr(j*16+i));
end;

function CheckClone (t: tptr; baseId:int) : int;
{ -1 - impossible, 0 - possible but not active, 1..999 - id being cloned }
var   i,x,y   : int;
      h       : sptr;
begin
  if (t=nil) or (t^.data=nil) then Exit;
  CheckClone:=-1;
  if (not Cloning) or (CloneCost[player]=32767) then Exit;
  with t^.data^ do
  begin
    x:=xyplan[baseId,1];
    y:=xyplan[baseId,2];
  end;
  for i:=1 to 999 do
  begin
    h:=t^.data^.ship[i];
    if (h<>nil) and (h^.when=turn) and (h^.owner=player) and not OwnShipDesign(player,h^.hull) then
    begin
      if h^.fcode<>'cln' then CheckClone:=0
                         else begin CheckClone:=i; Exit end;
    end;
  end;
end;

procedure DrawCredits;
begin
  Clear(MX0, 639, 463, 479);
  SetColor(DarkGray);
  {OutTextXY(MX0, 463, 'Extended Features');}
  {OutTextXY(MX0, 471, '2003/04 C.Graefe');}
end;

procedure InitWarning(msg: string);
begin
  writeln;
  writeln('WARNING: '+msg);
  GPause:=Yes;
end;

{
 Alternative happyness calculation for Borgculator. Hiss-Mission is ignored
 but this function works on planet record *only*
 }
function CGExtCHappyChange( p:pptr ) : int;
var   i       : int;
      tempCtax: int;
begin
  i:=0;
  if p<>nil then
  with p^ do
  begin
    tempCtax := Ctax;
    if (Cstat < 31) then tempCtax:=0; {No taxation below happy=31 -> corrected }
    if (colonists>0) and (owner<>-1) and (tempCtax<>-1) and
       (climate<>-1) and (mines<>-1) and (factories<>-1) then
      i:=Round( 1000-Sqrt(colonists)-tempCtax*80
                    -Abs(climate-IIF(Race[owner]=7,0,50))*3
                    -(mines+factories) div 3 ) div 100
                    ;
  end;
  CGExtCHappyChange:=i;
end;

{Special round function used in THost.}
function TRound( d: double ): long;
begin
  if ( Abs(d)-Trunc(Abs(d)) = 0.5 ) then
    if (Trunc(d) mod 2 = 0) then
      TRound:=Trunc(d)
    else
      if (d>0) then
        TRound:=Trunc(d)+1
      else
        TRound:=Trunc(d)-1
  else
    TRound:=Round(d);
end;

{Calculate one turn of mine decay and return resulting units.}
function DecayMineUnits( units: long; web: boolean ): long;
begin
  if PHOST then
    if (web) then DecayMineUnits := Trunc( ((100.0 - WebMineDecayRate)/100.0) * units )
             else DecayMineUnits := Trunc( ((100.0 - MineDecayRate)/100.0) * units )
  else
    if (web) then DecayMineUnits := units - TRound((WebMineDecayRate/100.0) * units) - 1
             else DecayMineUnits := units - TRound((MineDecayRate/100.0) * units) - 1;
end;

function MineRadius( units: long ): int;
begin
  if (PHOST) then
    MineRadius:=Round(Sqrt(MaxL(units,0)))
  else
    MineRadius:=TRound(Sqrt(MaxL(units,0)));
end;

{
 Alternative happyness calculation for Borgculator. Hiss-Mission is ignored
 but this function works on planet record *only*
 }
function CGExtNHappyChange( p:pptr ) : int;
var   i       : int;
      tempNtax: int;
begin
  i:=0;
  if p<>nil then
  with p^ do
  begin
    tempNtax := Ntax;
    if (Nstat < 31) then tempNtax:=0; {No taxation below happy=31 -> corrected }
    if (Nrace>0) and (natives>0) and (Ntax<>-1) and (Ngovt<>-1) and
       (mines<>-1) and (factories<>-1) then
      i:=Round( 500-Sqrt(natives)-tempNtax*85
                   -(mines+factories) div 2+Ngovt*50 ) div 100
                   +IIF(Nrace=4,10,0)
                   ;
  end;
  CGExtNHappyChange:=i;
end;

{ PlanetIncome function using alternative happiness functions. }
function ExtFeatPlanetIncome(p:pptr) : long;
var   l       : long;
      c       : long;
      nt      : int;
begin
  l:=0;
  if p<>nil then
  with p^ do
    if (colonists>0) and (Ctax<>-1) and
       (Nrace<>-1) and (natives<>-1) and (Ntax<>-1) and (Ngovt<>-1) and (Owner>0) then
      if colonists<>0 then
      begin
        l:=0;
        if Nrace<>5 then l:=Round(natives*Ntax*Ngovt/5000);
        if colonists<l then l:=colonists;
        if Nrace=6 then l:=l*2;
        if (Nstat+CGExtNHappyChange(p)<31) then l:=0; {No tax cash when happy < 31}
        if (Cstat+CGExtCHappyChange(p)<31) then c:=0 {No tax cash when happy < 31}
                                       else c:=colonists;

        {Correct native tax calculation for Cyborg: Natives will never pay more than 20%!}
        if (Ntax > TaxNBound[owner]) then begin
          nt:=TaxNBound[owner];
          l:=0;
          if Nrace<>5 then l:=Round(natives*nt*Ngovt/5000);
          if colonists<l then l:=colonists;
          if Nrace=6 then l:=l*2;
        end;

        if PHOSTver[1]>char(50) then { char(50) = '2' }
          l:=l*TaxNRate[owner] div 100+          { Phost 3 }
             Round(c*Ctax/1000)*TaxCRate[owner] div 100
        else
          l:=l*TaxRate[owner] div 100+      { Thost + Phost 2}
             Round(c*Ctax/1000)*TaxRate[owner] div 100;
        if l>MaxIncome then l:=MaxIncome;
      end;
  ExtFeatPlanetIncome:=l;
end;

{*****************************************************************************}
{** quality assurance feature, now downgraded and merged with actual list   **}
const 
  FPlanet     = 1;
  FBase       = 2;
  FShip       = 4;
  FTeleport   = 8;
  FIs         = $10; {Object is Teleport, to call GetTransport}
  FNoIs       = $EF; {Object is not Teleport, to call GetTransport}
procedure DrawCheckMark(x,y:int; c:byte);
begin
  SetLineStyle(SolidLn,0,NormWidth);
  SetWriteMode(NormalPut);
  SetColor(c);
  Line(x+1,y+3,x+3,y+5);
  Line(x+3,y+5,x+3,y);
  Line(x+3,y,x+4,y);
end;

procedure DrawCommonItem(offs:int);
begin
  SetColor(DarkGray);
  SetLineStyle(SolidLn,0,NormWidth);
  Line( MX0+1, 72+offs*qaHeight-1, 638, 72+offs*qaHeight-1 );
  Line( MX0+1, 72+(offs+1)*qaHeight-3, 638, 72+(offs+1)*qaHeight-3 );
end;

procedure DrawPlanetItem(number:int; offs:int);
var
  s         : string[100];
  p         : pptr;
  ep        : EPln;
  col       : byte;
  note      : boolean;
begin
  DrawCommonItem(offs);
  if (number<1) or (number>500) then Exit;

  with TTurn^.data^ do begin
    p:=planet[number];
    ep:=eplan[number];
  end;
  if (p=nil) then Exit;

  note := HasNote(number or LockP);
  col := IIF( ((actlist[number] and LockP) = LockP), DarkGray, cPInfo );
  s:=NStr(number);
  if length(s) < 3 then LPad(s,3);
  SetColor(col);
  OutTextXY(MX0,72+offs*qaHeight, '[P'+ s +'] ' );
  OutTextXY(MX0+(7+IIF(note,1,0))*8,72+offs*qaHeight, PlanName[number] );

  {friendly code}
  if p^.fcode<>#$FF#$FF#$FF then
    WriteFCode(MX0+4+0*8,72+offs*qaHeight+8,col,p^.fcode);

  {colonist tax}
  if p^.Ctax=0 then s:='' else s:='C'+NStr(p^.Ctax)+'%';
  if length(s) < 5 then LPad(s,5);
  SetColor(col);
  OutTextXY(MX0+4+4*8,72+offs*qaHeight+8, s );

  {native tax}
  if (p^.NRace<>0) then begin
    if p^.Ntax=0 then s:='' else s:='N'+NStr(p^.Ntax)+'%';
    if length(s) < 5 then LPad(s,5);
    SetColor(col);
    OutTextXY(MX0+4+9*8,72+offs*qaHeight+8, s );
  end;

  {funds}
  if (p^.funds<>-1) then begin
    if p^.funds=0 then s:='' else s:='$'+NStr(p^.funds);
    if length(s) < 6 then LPad(s,6);
    SetColor(col);
    OutTextXY(MX0+4+0*8,72+offs*qaHeight+16, s );
  end;

  {supplies}
  if (p^.supplies<>-1) then begin
    if p^.supplies=0 then s:='' else s:='Sp'+NStr(p^.supplies);
    if length(s) < 7 then LPad(s,7);
    SetColor(col);
    OutTextXY(MX0+4+7*8,72+offs*qaHeight+16, s );
  end;

  {note icon}
  if note then
    DrawNoteIcon( MX0+7*8, 72+offs*qaHeight, IIF( GetActList(number or LockP), NoteIconColorInactive, NoteIconColor ));
end;

procedure DrawTeleportItem(number:int; offs:int);
var
  s         : string[100];
  col,c   : byte;
  pla       : int;
  amount    : int;
begin
  DrawCommonItem(offs);
  if (number<1) or (number>500) then Exit;
  if (TTurn^.data^.planet[number]=nil) then Exit;
  with TTurn^.data^.planet[number]^ do begin
  
   (* s:=NStr(number);
    if length(s) < 3 then LPad(s,3); *)

    {Get TX-Transfer}
    pla := GetTeleportDataTX(number, c, amount);
    if pla=-1   then begin s:=' -> No RX'+TPFcode[c];
                           col:=lightmagenta;
    end else if pla>0 then begin 
      s:='-> #'+copy('  '+Nstr(pla),length(Nstr(pla)),3)+':';
      col:=magenta;
      if amount>9999 then s:=s+'>10'+#39 else s:=s+copy('   '+nstr0(amount),length(nstr0(amount)),4);
      s:=s+TPFcode[c];
    end else begin        {No TX-Code check RX-Code}
      pla := GetTeleportDataRX(number, c, amount);
      col:=lightgreen;
      if pla=-1 then s:=' <- No TX'+TPFcode[c]
      else if pla=-2 then s:=' <- ID too high'
      else if pla>0 then begin 
        s:='<- '+copy('  '+Nstr(pla),length(Nstr(pla)),3)+'^ :';
        col:=green;
        if amount>9999 then s:=s+'>10'+#39 else s:=s+copy('   '+nstr0(amount),length(nstr0(amount)),4);
        s:=s+TPFcode[c];
      end else begin
        s:='No RX/TX Code';
        if (fcode[1]='P') and (fcode[2]='B') and 
           (fcode[3] in ['1','2','3','4','5','6','7','8','9']) then col:=Yellow
        else col := LightGray; 
      end;
    end;
            
    SetColor(col);
    if fcode<>#$FF#$FF#$FF then
      WriteFCode(MX0+4,72+offs*qaHeight,col,fcode);
      OutTextXY(MX0+4+4*8,72+offs*qaHeight, s );
    
    {Show Ressources}
    if colonists>9999 then s:='>10'+#39 else s:=copy('   '+nstr0(colonists),length(nstr0(colonists)),4);
    s:=s+'C ';
    if N>9999 then s:=s+'>10'+#39 else s:=s+copy('   '+nstr0(N),length(nstr0(N)),4);
    s:=s+'N ';
    if T>9999 then s:=s+'>10'+#39 else s:=s+copy('   '+nstr0(T),length(nstr0(T)),4);
    s:=s+'T ';
    OutTextXY(MX0+4,8+72+offs*qaHeight, s );
    if D>9999 then s:='>10'+#39 else s:=copy('   '+nstr0(D),length(nstr0(D)),4);
    s:=s+'D ';
    if M>9999 then s:=s+'>10'+#39 else s:=s+copy('   '+nstr0(M),length(nstr0(M)),4);
    s:=s+'M ';
    if (supplies+funds)>9999 then s:=s+'>10'+#39 
       else s:=s+copy('   '+nstr0(supplies+funds),length(nstr0(supplies+funds)),4);
    s:=s+'$ ';
    OutTextXY(MX0+4,16+72+offs*qaHeight, s );
  end;
end;

procedure DrawBaseItem(number:int; offs:int);
var
  s         : string[100];
  b         : bptr;
  col       : byte;
  myrace    : int;
  clone     : int;
  sh        : sptr;
begin
  DrawCommonItem(offs);
  if (number<1) or (number>500) then Exit;

  b:=TTurn^.data^.base[number];
  if (b=nil) then Exit;

  col := IIF( ((actlist[number] and LockB) = LockB), DarkGray, cBInfo );
  s:=NStr(number);
  if length(s) < 3 then LPad(s,3);
  SetColor(col);
  OutTextXY(MX0,72+offs*qaHeight, '[B'+ s +'] '+PlanName[number] );

  with b^ do begin
    if TrueHullByRace then myrace:=Race[owner]
                      else myrace:=owner;
    clone:=CheckClone(TTurn, number);
    if (cHl<>0) then begin
      s:=Hulls[RaceHull[myrace,cHl]].name;
      OutTextXY(MX0+4+0*8, 72+offs*qaHeight+8, 'B'+Chr(26)+s);
    end else
    if (clone>0) then begin
      sh:=TTurn^.data^.ship[clone];
      s:=Hulls[sh^.hull].name;
      OutTextXY(MX0+4+0*8, 72+offs*qaHeight+8, 'C'+Chr(26)+s);
    end;
    s:='';
    if Hl>0 then 
      if hl<10 then s:=s+'H:'+Nstr(Hl) else s:=s+'H10';
    if El>0 then 
      if el<10 then s:=s+' E:'+Nstr(el) else s:=s+' E10';
    if Wl>0 then 
      if wl<10 then s:=s+' W:'+Nstr(wl) else s:=s+' W10';
    if Tl>0 then 
      if tl<10 then s:=s+' T:'+Nstr(tl) else s:=s+' T10';
    OutTextXY(MX0+4, 72+offs*qaHeight+16,s);
  end;

end;

procedure DrawShipItem(number:int; offs:int);
var
  s         : string[100];
  sh        : sptr;
  col       : byte;
  note      : boolean;
begin
  DrawCommonItem(offs);
  if (number<1) or (number>500) then Exit;

  sh:=TTurn^.data^.ship[number];
  if (sh=nil) then Exit;

  note := HasNote(number or LockS);
  col := IIF( ((actlist[number] and LockS) = LockS), DarkGray, cSInfo );
  s:=NStr(number);
  if length(s) < 3 then LPad(s,3);
  SetColor(col);
  OutTextXY(MX0,72+offs*qaHeight, '[S'+ s +'] ' );
  OutTextXY(MX0+(7+IIF(note,1,0))*8,72+offs*qaHeight, sh^.name );

  if sh^.fcode<>#$FF#$FF#$FF then
    WriteFCode(MX0+4+0*8,72+offs*qaHeight+8,col,sh^.fcode);

  s:='W'+NStr0(sh^.warp);
  SetColor(col);
  OutTextXY(MX0+4+4*8,72+offs*qaHeight+8, s );

  s:=NStr0(sh^.fuel);
  if length(s) < 3 then LPad(s,3);
  SetColor(col);
  OutTextXY(MX0+4+7*8,72+offs*qaHeight+8, s );

  {note icon}
  if note then
    DrawNoteIcon( MX0+7*8, 72+offs*qaHeight, IIF( GetActList(number or LockS), NoteIconColorInactive, NoteIconColor ));
end;

procedure DrawItem(item:int; offs:int);
begin
  case (item and LockHi) of
    LockP : DrawPlanetItem( item and LockLo, offs );
    LockB : DrawBaseItem( item and LockLo, offs );
    LockS : DrawShipItem( item and LockLo, offs );
  end;
end;

procedure DrawCursor(offs:int; color:byte);
begin
  SetColor(color);
  SetLineStyle(SolidLn,0,NormWidth);
  Line( MX0, 72+offs*qaHeight-2, 639, 72+offs*qaHeight-2 );
  Line( MX0, 72+(offs+1)*qaHeight-2, 639, 72+(offs+1)*qaHeight-2 );
  Line( MX0, 72+offs*qaHeight-2, MX0, 72+(offs+1)*qaHeight-2 );
  Line( 639, 72+offs*qaHeight-2, 639, 72+(offs+1)*qaHeight-2 );
end;

procedure ClearArea;
begin
  Clear(MX0,64,639,479);
end;

function ItemCount(var filter:byte): int;
var
  count   : int;
  plan    : pptr;
  ship    : sptr;
  base    : bptr;
  i       : int;
begin
  count:=0;
  for i:=1 to 500 do begin
    plan:=TTurn^.data^.planet[i];
    if (plan<>nil) and (plan^.owner=player) and (plan^.when=turn) then begin
      base:=TTurn^.data^.base[i];
      if  (filter and FPlanet>0) and (((filter and FTeleport>0) and (base<>NIL)) or (filter and FTeleport=0)) then 
        inc(count);
      if (base<>nil) then 
        if ((filter and FBase)>0) then inc(count);
      if ((base=NIL) and (plan^.build=1)) or (base<>NIL) then 
        if ((filter and FTeleport)>0) then inc(count);
    end;
  end;
  for i:=1 to 999 do begin
    ship:=TTurn^.data^.ship[i];
    if (ship<>nil) and (ship^.owner=player) and ((filter and FShip)>0) then
      inc(count);
  end;
  ItemCount:=count;
end;

procedure DrawChoice(filter:byte);
begin
  if (filter and FPlanet>0) then setcolor(white) else setcolor(DarkGray);
  OutTextXY(MX0+4, 450, 'P');
  if (filter and FBase>0) then setcolor(white) else setcolor(DarkGray);
  OutTextXY(MX0+8+4, 450, 'B');
  if (filter and FShip>0) then setcolor(white) else setcolor(DarkGray);
  OutTextXY(MX0+16+4, 450, 'S');
  if (filter and FTeleport>0) then setcolor(white) else setcolor(DarkGray);
  OutTextXY(MX0+24+4, 450, 'V');
  DrawHelpPrompt;
end;

procedure DrawItems(var filter:byte);
var
  plan    : pptr;
  ship    : sptr;
  base    : bptr;
  count   : int;
  i       : int;
begin
  ClearArea;
  DrawCredits;
  DrawChoice(filter);
  count:=0;
  for i:=1 to 500 do begin
    plan:=TTurn^.data^.planet[i];
    if (plan<>nil) and (plan^.owner=player) and (plan^.when=turn) then begin
      base:=TTurn^.data^.base[i];
      if  (filter and FPlanet>0) and (((filter and FTeleport>0) and (base<>NIL)) or (filter and FTeleport=0)) then begin
        if (count>=qaOffset) then
          DrawItem( i or LockP, count-qaOffset );
        inc(count);
        if (count-qaOffset>=qaDisplayN) then Break;
      end;
      if (base<>nil) then begin
        if ((filter and FBase)>0) then begin
          if (count>=qaOffset) then
            DrawItem( i or LockB, count-qaOffset );
          inc(count);
          if (count-qaOffset>=qaDisplayN) then Break;
        end;
      end;
      if ((base=NIL) and (plan^.build=1)) or (base<>NIL) then begin
        if ((filter and FTeleport)>0) then begin
          if (count>=qaOffset) then
            DrawTeleportItem( i, count-qaOffset );
          inc(count);
          if (count-qaOffset>=qaDisplayN) then Break;
        end;
      end;
    end;
  end;
  if (count-qaOffset<qaDisplayN) then
    for i:=1 to 999 do begin
      ship:=TTurn^.data^.ship[i];
      if (ship<>nil) and (ship^.owner=player) and ((filter and FShip)>0) then begin
        if (count>=qaOffset) then
          DrawItem( i or LockS, count-qaOffset );
        inc(count);
        if (count-qaOffset>=qaDisplayN) then Break;
      end;
    end;
  SetColor(LightGray);
  if (qaOffset>0) then begin
    OutTextXY( 631, 64, Chr(24) );
  end;
  if (qaOffset+qaDisplayN<qaItemCount) then begin
    OutTextXY( 631, 72+qaDisplayN*qaHeight, Chr(25) );
  end;
end;

function ItemAt(offs:int; var filter:byte): int;
var
  plan    : pptr;
  ship    : sptr;
  base    : bptr;
  i       : int;
  count   : int;
begin
  count:=0;
  for i:=1 to 500 do begin
    plan:=TTurn^.data^.planet[i];
    if (plan<>nil) and (plan^.owner=player) and (plan^.when=turn) then begin
      base:=TTurn^.data^.base[i];
      if  (filter and FPlanet>0) and (((filter and FTeleport>0) and (base<>NIL)) or (filter and FTeleport=0)) then begin
        if (count=offs) then begin
          ItemAt:=(i or LockP);
          Exit;
        end;
        inc(count);
      end;      
      if (base<>nil) then begin
        if ((filter and FBase)>0) then begin
          if (count=offs) then begin
            ItemAt:=(i or LockB);
            Exit;
          end;
          inc(count);
        end;
      end;
      if ((base=NIL) and (plan^.build=1)) or (base<>NIL) then begin
        if ((filter and FTeleport)>0) then begin
          if (count=offs) then begin
            ItemAt:=(i or LockW); {Wormhole GetTeleport}            
            Exit;
          end;
          inc(count);
        end;
      end;
    end;
  end;
  for i:=1 to 999 do begin
    ship:=TTurn^.data^.ship[i];
    if (ship<>nil) and (ship^.owner=player) and ((filter and FShip)>0) then begin
      if (count=offs) then begin
        ItemAt:=(i or LockS);
        Exit;
      end;
      inc(count);
    end;
  end;
end;

procedure SetActList( obj: int; approved: boolean );
var
  n  : int;
  f  : int;
begin
  n := obj and LockLo;
  f := obj and LockHi;
  if (n<1) or (n>999) then Exit;
  if (approved) then
    actlist[n]:=actlist[n] or f
  else
    actlist[n]:=actlist[n] and not f;
end;

function GetActList( obj: int ): boolean;
var
  n  : int;
  f  : int;
begin
  GetActList:=false;
  n := obj and LockLo;
  f := obj and LockHi;
  if (n<1) or (n>999) then Exit;
  GetActList:=(actlist[n] and f = f);
end;

procedure ShowQAOverview(Filter: byte);
{Filter: 1 Planet, 2 Base, 4 Ship, 8 Teleport, 16 Is Teleport}
var
  offs       : int;
  obj        : int;
  item,item0 : int;
  focus      : Boolean;
  x,y        : int;
  sx,sy      : int;  
begin
  MouseDisabled:=True;
  qaItemCount:=ItemCount(filter);
  DrawItems(filter);
  item:=0;
  repeat
    item0:=ItemAt(qaCursor,filter);
    if (item0<>item) then begin
      item:=item0;
      case (item and LockHi) of 
        LockP : begin obj:=item; focus:=True; lbase:=nil; filter:=filter and FNoIs; end;
        LockW : begin obj:=(item and LockLo) or LockP; focus:=True; lbase:=nil; filter:=filter or FIs; end; {UFO for Transport}
        LockB : begin
                  obj:=(item and LockLo) or LockP;
                  focus:=True; filter:=filter and FNoIs;
                  lbase:=TTurn^.data^.base[item and LockLo];
                end;
        LockS : begin obj:=item; focus:=True; lbase:=nil; filter:=filter and FNoIs; end;
      end;
    end;
    if (focus) then begin
      focus:=False;
      GetObjectCoord(obj, x, y);
      CenterMap(x,y,No);
      Abs2Scr(x,y,sx,sy);
      MoveMouseTo(sx,sy);
      WriteCoord;
      if showF and (item and LockHi=LockP or LockB) then ShowForecast;  
    end;

    DrawCursor( qaCursor-qaOffset, White );
    ch:=ReadKey;
    DrawCursor( qaCursor-qaOffset, Black );
    case ch of
{up}   $4800 : begin
                 if (qaCursor>0) then begin
                   qaCursor:=qaCursor-1;
                   if (qaCursor-qaOffset<0) then begin
                     qaOffset:=qaOffset-1;
                     DrawItems(filter);
                   end;
                 end;
               end;
{down} $5000 : begin
                 if (qaCursor+1<qaItemCount) then begin
                   qaCursor:=qaCursor+1;
                   if (qaCursor-qaOffset>=qaDisplayN) then begin
                     qaOffset:=qaOffset+1;
                     DrawItems(filter);
                   end;
                 end;
               end;
{Pup}  $4900 : begin
                 qaCursor:=qaCursor-qaDisplayN;
                 if (qaCursor<0) then qaCursor:=0;
                 if (qaCursor-qaOffset<0) then begin
                   qaOffset:=qaCursor;
                   DrawItems(filter);
                 end;
               end;
{Pdown}$5100 : begin
                 qaCursor:=qaCursor+qaDisplayN;
                 if (qaCursor>=qaItemCount) then qaCursor:=qaItemCount-1;
                 if (qaCursor-qaOffset>=qaDisplayN) then begin
                   qaOffset:=qaCursor-qaDisplayN+1;
                   if (qaOffset<0) then qaOffset:=0;
                   DrawItems(filter);
                 end;
               end;
{home} $4700 : begin qaCursor:=0; qaOffset:=0; DrawItems(filter); end;
{end}  $4f00 : begin
                 qaCursor:=qaItemCount-1;
                 qaOffset:=qaCursor-qaDisplayN+1;
                 if (qaOffset<0) then qaOffset:=0;
                 DrawItems(filter);
               end;
{^a}  1       : if (turn=today) then begin
                  SetActList(item, true);
                  DrawItems(filter);
                end;
{^d}  4       : if (turn=today) then begin
                  SetActList(item, false);
                  DrawItems(filter);
                end;
{z}   ord('z'): CenterMap(x,y,Yes);
{/}   ord('/'): if (turn=today) then begin
                  SetActList(item, not GetActList(item));
                  DrawItems(filter);
                end;
{_P}  ord('P'): begin
                  if (filter and FPlanet)>0 then dec(filter,Fplanet) else inc(filter,Fplanet);
                  qaItemCount:=ItemCount(filter);
                  DrawItems(filter);
                  item:=0;
                end;
{_S}  ord('S'): begin
                  if (filter and FShip)>0 then dec(filter,FShip) else inc(filter,FShip);
                  qaItemCount:=ItemCount(filter);
                  DrawItems(filter);
                  item:=0;
                end;
{_B}  ord('B'): begin
                  if (filter and FBase)>0 then dec(filter,FBase) else inc(filter,FBase);
                  qaItemCount:=ItemCount(filter);
                  DrawItems(filter);
                  item:=0;
                end;
{_V}  ord('V'): if Addon.Teleport then begin
                  if (filter and FTeleport)>0 then dec(filter,FTeleport) else inc(filter,FTeleport);
                  qaItemCount:=ItemCount(filter);
                  DrawItems(filter);
                  item:=0;
                end;
{F1}  $3B00   : begin
                    helpscr:=15;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                end;
{RET} 13      : if (filter and FIs>0) then begin
                  ch:=0; 
                  GetTeleport(obj and LockLo);
                  DrawItems(filter);
                end;
    end;
  until (ch=13) or (ch=27);
  ClearArea;
  if (ch=13) then force:=obj;
  ForceKey:=13;
  MouseDisabled:=False;
end;


{*****************************************************************************}
{** planet connections feature ** }

procedure ShowConnections;
var   s       : str20;
      d,a     : integer;
      i,j     : int;
      x1,y1   : int;
      x2,y2   : int;
begin
  MouseMove;
  MouseDisabled:=True;
  {ClearInfo;}
  ClearArea;
  DrawCredits;
  SetColor(White);
  OutTextXY(MX0,72,'Max. Distance :');
  OutTextXY(MX0,80,' [warp or lys]');
  SetColor(LightGray);
  OutTextXY(MX0,96,NStr(dist0));
  s:=GetStr(MX0,96,18);
  MouseOff;
  Clear(MX0,72,639,111);
  Val(s,d,a);

  if d>=0 then
  begin
    if (d>0) then dist0:=d;
    tmpConnDist:=dist0;
    DrawMap(Yes);
  end;
  MouseDisabled:=False;
  MouseOn;
end;


{new version using pre-built connection data}
procedure DrawConnections(dist:int; color:byte; dist_is_warp:boolean);
var   i,j,n   : int;
      x1,y1   : int;
      x2,y2   : int;
      os1,os2 : boolean;
      tx1,ty1 : int;
      tx2,ty2 : int;
      dx,dy   : long;
      dist2   : long;
      scdist  : long;
      smapsz  : long;
      xw,yw   : int;
begin
  if dist>=0 then
  begin
    if (dist<>pConDist) or (dist_is_warp and not pConDistIsWarp) or (not dist_is_warp and pConDistIsWarp)
    or (TTurn^.turn<>pConTurn) then
      BuildConnectionData(dist, dist_is_warp);

    SetColor(color);
    SetLineStyle(SolidLn,0,NormWidth);
    {calculate screen sizes needed for MapWrap}
    if (MapWrap) then begin
      scdist := dist+150; {hack!}
      scdist := scdist*ratio2;
      scdist := scdist div ratio1;
      smapsz := MapSize;
      smapsz := smapsz*ratio2;
      smapsz := smapsz div ratio1;
    end;
    with TTurn^.data^ do
      for i:=1 to 500 do
        if (pCon^[i]<>nil) then
          for n:=1 to MAX_NEIGHBORS do begin
            j:=pCon^[i]^.neighbor[n];
            if (j<0) then Break;

            os1 := Abs2Scr(xyplan[i,1],xyplan[i,2],x1,y1);
            os2 := Abs2Scr(xyplan[j,1],xyplan[j,2],x2,y2);
            if ( os1 or os2 ) then
            begin
              if MapWrap then begin
                dx := abs(x1-x2);
                dy := abs(y1-y2);
                dist2 := dx*dx+dy*dy;
                if (dist2 <= scdist*scdist) then begin
                  {standard connection}
                  DrawWLine( x1, y1, x2, y2, No );
                end else begin
                  {wraped connection, draw twice from planet to off-screen area}
                  if (os2) then begin
                    xw:=x1; yw:=y1;
                    if (dx>scdist) then if(x1>x2) then xw := x1-smapsz else xw := x1+smapsz;
                    if (dy>scdist) then if(y1>y2) then yw := y1-smapsz else yw := y1+smapsz;
                    DrawWLine( xw, yw, x2, y2, No );
                  end;
                  if (os1) then begin
                    xw:=x2; yw:=y2;
                    if (dx>scdist) then if(x1>x2) then xw := x2+smapsz else xw := x2-smapsz;
                    if (dy>scdist) then if(y1>y2) then yw := y2+smapsz else yw := y2-smapsz;
                    DrawWLine( x1, y1, xw, yw, No );
                  end;
                end;
              end else
                DrawWLine( x1, y1, x2, y2, No );
            end;

          end;
  end;
end;


{*****************************************************************************}
{** resource stats ** }

procedure ResRecClear( rec: ResStatPtr );
var i: int;
begin
  with rec^ do begin
    prev := nil;
    next := nil;
    turn := -1;
    race := -1;

    colonists0      := 0;
    colonists1      := 0;
    natives0        := 0;
    natives1        := 0;
    mines0          := 0;
    factories0      := 0;
    defenses0       := 0;
    supplies0       := 0;
    supplies1       := 0;
    funds0          := 0;
    funds1          := 0;
    N0              := 0;
    N1              := 0;
    N2              := 0;
    T0              := 0;
    T1              := 0;
    T2              := 0;
    D0              := 0;
    D1              := 0;
    D2              := 0;
    M0              := 0;
    M1              := 0;
    M2              := 0;
    planets0        := 0;
    bases0          := 0;
    bases1          := 0;
    ships0          := 0;
    ships1          := 0;

  end;
end;

procedure DisposeStats;
var item: ResStatPtr;
begin
  item:=statRoot;
  while (item<>nil) and (item^.next<>nil) do begin
    item:=item^.next;
    Dispose(item^.prev);
  end;
  if (item<>nil) then Dispose(item);
  statRoot:=nil;
end;


function GetStat(turn:int): ResStatPtr;
var item: ResStatPtr;
begin
  item:=statRoot;
  while (item<>nil) and (item^.turn<>turn) do begin
    item:=item^.next;
  end;
  GetStat:=item;
end;

function GetPrevStat(turn:int): ResStatPtr;
var item: ResStatPtr;
begin
  item:=statRoot;
  GetPrevStat:=nil;
  while (item<>nil) and (item^.turn<turn) do begin
    GetPrevStat:=item;
    item:=item^.next;
  end;
end;

function GetClosestStat(turn:int): ResStatPtr;
var
  item: ResStatPtr;
  diff: int;
begin
  diff:=9999;
  item:=statRoot;
  GetClosestStat:=nil;
  while (item<>nil) and (Abs(item^.turn-turn)<diff) do begin
    GetClosestStat:=item;
    diff:=Abs(item^.turn-turn);
    item:=item^.next;
  end;
end;

procedure AddStat(rec: ResStatPtr);
var item: ResStatPtr;
begin
  if (rec=nil) or (rec^.turn<=0) then Exit;
  rec^.prev:=nil;
  rec^.next:=nil;
  item:=GetStat(rec^.turn);
  if (item=nil) then begin
    item:=GetPrevStat(rec^.turn);
    if (item=nil) then begin
      if (statRoot<>nil) then begin
        {insert before root item}
        rec^.next:=statRoot;
        statRoot^.prev:=rec;
      end;
      statRoot:=rec;
    end else begin
      {insert item}
      if (item^.next<>nil) then begin
        item^.next^.prev:=rec;
        rec^.next:=item^.next;
      end;
      rec^.prev:=item;
      item^.next:=rec;
    end;
  end else begin
    {replace item}
    rec^.next:=item^.next;
    rec^.prev:=item^.prev;
    if (item^.prev<>nil) then item^.prev^.next:=rec;
    if (item^.next<>nil) then item^.next^.prev:=rec;
  end;
end;

function SupplyProduction(p: pptr): long;       
var prod,tmp: long;
begin
  prod:=0;
  if (p<>nil) then with p^ do begin

    if (Addon.Unity) then prod := Unity_Disassemble(p);     {Adds DA? Supps Quapla}
    if (factories>0) then prod := prod + factories;
    {supplies produced by Bovinoids}
    if (Nrace=2) and (natives>0) then begin
      tmp := (natives) div 100;
      if (tmp>colonists) then tmp:=colonists;
      prod := prod + tmp;
    end;                                        
  end;
  SupplyProduction:=prod;
end;

function NPopulationLimit(p: pptr): long;
var
  l  : long;
  g    : double;
  temp : int;
begin
  l:=MaxPopulation;
  if (p<>nil) then
    with p^ do begin
      temp:=100-climate;

      if (p^.Nrace=9) then begin
        {exception for siliconoids}
        l:=temp; {cast}
        l:=l * 1000;
      end else begin
        l:=Round(sin(3.14 * ( (100-temp) / 100)) * 150000);
      end;

    end;
  NPopulationLimit:=l;
end;

function NativeGrowth(p: pptr; num: int): long;
var
  g       : double;
  current : long;
  limit   : long;
  tmp     : long;
  temp    : int;
  CstatCh, NstatCh : int;
begin
  NativeGrowth:=0;
  g:=0;
  if (p<>nil) and (p^.owner>0) then {Natives won't grow without owner}
    with p^ do begin
      if (Nrace<=0) or (natives<=0) then Exit;
      limit   := NPopulationLimit(p);
      current := natives;
      temp    := 100-climate;
      if (num>0) then begin
        CstatCh := CHappyChange(num,TRUE);
        NstatCh := NHappyChange(num,TRUE);
      end else begin
        CstatCh := CGExtCHappyChange(p);
        NstatCh := CGExtNHappyChange(p);
      end;

      {cyborg assimilates natives first}
      if (owner=6) and (natives>0) and (Nrace<>5) then begin
        tmp := (colonists * AssimilationRate) div 100;
        if (natives<=tmp) then current:=0
        else current:=current-tmp;
      end;

      {normal growth rate}
      if (natives<limit) and (Nstat+NstatCh>=70) then begin
        if (Nrace=9) then
          g:=(temp/100) * (current/25) * (5/(Ntax+5))
        else
          g:=sin(3.14 * ((100-temp)/100)) * (current/25) * (5/(Ntax+5));
        current := current + Round(g);
      end;

      {civil war}
      if ((Nstat+NstatCh<0) or (Cstat+CstatCh<0)) and   (Nrace<>5) then begin
        tmp:=Trunc(current*0.3)+100;
        current := current - tmp;
      end;

      if (current<0) then current:=0;
      NativeGrowth:=current-natives;
    end;
end;


function CPopulationLimit(p: pptr): long;
var
  l  : long;
  g    : double;
  temp : int;
begin
  l:=MaxPopulation;
  if (p<>nil) and ClimateLimitsPopulation then
    with p^ do begin
      temp:=100-climate;

      if (p^.owner=7) and CrystalsLikeDesert then begin
        l:=temp; {cast}
        l:=l * 1000;
      end else
        if (temp>=15) and (temp<=84) then
          l:=Round(sin(3.14 * ( (100-temp) / 100) ) * 100000)
        else begin
          if (temp<15) then begin
            l:=Trunc( (299.9 + 200 * temp) / ClimateDeathRate );
          end else begin
            l:=Trunc( (20099.9 - 200 * temp) / ClimateDeathRate );
          end;
          {rebel}
          if (temp<20) and (owner=10) then
            l:=90000;
          {fascist,robot,rebel,colonies -> is this correct??}
          if (temp>80) and (owner in [4,9,10,11]) then
            if (l<60) then
              l:=60;
        end;

    end;
  CPopulationLimit:=l;
end;

function ColonistGrowth(p: pptr; num: int; var supplEaten: long): long;
var
  g       : double;
  current : long;
  limit   : long;
  tmp     : long;
  temp    : int;
  suppl,newSuppl,currMaxPop: long;
  CstatCh, NstatCh : int;
begin
  ColonistGrowth:=0;
  supplEaten:=0;
  g:=0;
  if (p<>nil) then
    with p^ do begin
      limit   := CPopulationLimit(p);
      current := colonists;
      temp    := 100-climate;
      if (num>0) then begin
        CstatCh := CHappyChange(num,TRUE);
        NstatCh := NHappyChange(num,TRUE);
      end else begin {CG Kalkulation num=-1 }
        CstatCh := CGExtCHappyChange(p);
        NstatCh := CGExtNHappyChange(p);
      end;

      {Add-On Unity -> Planet-Code DA? -> 100*? Borg Clans will be disassembled into 50% Supplys Quapla}
      if Addon.Unity and (owner=6) and (fcode[1]='D')AND(fcode[2]='A')AND
               (fcode[3] in ['1','2','3','4','5','6','7','8','9' ]) then begin
        tmp:=-(ord(fcode[3])-ord('0'))*100;          {Quick hack -> DA5 -> assim := -500}
        if -tmp > colonists then tmp := -colonists; {all Clans disassembled}
        current := current+tmp;
      end;
      
      (*
      {Pillage/RGA Colonists}
      if (GetShipsOverPlanet (PlanetID(p), 4, TRUE)>0) then current := current - TRound ((current*0.2)+20);
      if (GetShipsOverPlanet (PlanetID(p), 10, TRUE)>0) then current := trunc (current * 0.8);
      *)
      
      {cyborg assimilates natives first}
      if (owner=6) and (natives>0) and (Nrace<>5) then begin
        tmp := (current * AssimilationRate) div 100;
        if (natives<=tmp) then current:=current+natives
        else current:=current+tmp;
      end;

      {normal growth and death rate}
      if (temp>=15) and (temp<=84) then begin

        if (Cstat+CstatCh>=70) and (current<limit) then
        begin
          if (owner=7) and CrystalsLikeDesert then begin
            g:=current/20;
            g:=(temp/100) * (current/20) * (5/(Ctax+5));
          end else
            g:=sin(3.14*((100-temp)/100)) * (current/20) * (5/(Ctax+5));
          if (current>66000) then g:=g/2;
          current:=current+Round(g);
        end;
        if current>limit then current:=limit;

      end else
        if (current>limit) then begin
          if (temp<15) then
            limit:=current - Trunc(ClimateDeathRate*current/100) + 2*(temp+1)
          else
            limit:=current - Trunc(ClimateDeathRate*current/100) + 2*(100-temp);
          suppl := supplies + SupplyProduction(p);
          if OverpopulationEatsSupplies and (suppl>0) then begin
            {calculate current max population}
            newsuppl := suppl - 1 - (colonists - limit) div 40;
            currMaxpop := limit + newsuppl div 40;
            supplEaten := suppl-newsuppl;
          end else
            currMaxPop:=limit;
          if (current>currMaxPop) then current:=currMaxPop;
        end else
          {should happen for Crystals *only*}
          if (owner=7) and CrystalsLikeDesert and (Cstat+CstatCh>=70) then begin
            g:=(temp/100) * (current/20) * (5/(Ctax+5));
            if (current>66000) then g:=g/2;
            current:=current+Round(g);
            if current>limit then current:=limit;
          end;

      {amorphous worms eat clans}
      if (Nrace=5) then begin
        tmp := 95 - (Nstat+NstatCh);
        if (tmp<5) then tmp:=5;
        current := current - tmp;
      end;

      {civil war}
      if (Nstat+NstatCh<0) or (Cstat+CstatCh<0) then begin
        tmp:=Trunc(current*0.3)+100;
        current := current - tmp;
      end;

      if (current<0) then current:=0;
      ColonistGrowth:=current-colonists;
    end;
end;

procedure CountResources( trec: tptr; rec: ResStatPtr );
var
  i,j     : int;
  p       : pptr;
  sh      : sptr;
  b       : bptr;
  tmp     : long;
  supplEaten: long;
  n1,n2   : int;
  function CalcMining(mines,rate,core:long):long;
  var tmp     : long;
  begin
    tmp := Round((mines * rate) / 100);
    if (tmp>core) then tmp:=core;
    CalcMining:=tmp;
  end;
begin
  {if (rec=nil) then rec := New( ResStatPtr ); too dagerous}
  ResRecClear( rec );
  with rec^ do begin
    race := player;
    turn := trec^.turn;

    n1:=0; n2:=0;
    for i:=1 to 500 do begin
      p:=trec^.data^.planet[i];
      b:=trec^.data^.base[i];
      if (p<>nil) and (p^.owner = player) and (p^.when=rec^.turn) then
      begin
        {*** resources currently available ***}
        inc(planets0);
        if (p^.colonists>=0) then colonists0 := colonists0 + p^.colonists;
        if (p^.natives>=0) then natives0 := natives0 + p^.natives;
        if (p^.mines>=0) then mines0 := mines0 + p^.mines;
        if (p^.factories>=0) then factories0 := factories0 + p^.factories;
        if (p^.defense>=0) then defenses0 := defenses0 + p^.defense;
        if (p^.supplies>=0) then supplies0 := supplies0 + p^.supplies;
        if (p^.funds>=0) then funds0 := funds0 + p^.funds;
        if (p^.N>=0) then N0 := N0 + p^.N;
        if (p^.T>=0) then T0 := T0 + p^.T;
        if (p^.D>=0) then D0 := D0 + p^.D;
        if (p^.M>=0) then M0 := M0 + p^.M;
        if (b<>nil) then inc(bases0);
        {*** production per turn ***}
        colonists1:=colonists1 + ColonistGrowth(p,i,supplEaten);
        natives1:=natives1 + NativeGrowth(p,i);
        supplies1 := supplies1 + SupplyProduction(p) - supplEaten;
        tmp := PlanetIncome( p, i, TRUE ); if (tmp>0) then funds1 := funds1 + tmp;
        if (p^.mines>0) and (p^.Nm>=0) then
          N1 := N1 + CalcMining(p^.mines, p^.Nm, p^.Nc);
        if (p^.mines>0) and (p^.Tm>=0) then
          T1 := T1 + CalcMining(p^.mines, p^.Tm, p^.Tc);
        if (p^.mines>0) and (p^.Dm>=0) then
          D1 := D1 + CalcMining(p^.mines, p^.Dm, p^.Dc);
        if (p^.mines>0) and (p^.Mm>=0) then
          M1 := M1 + CalcMining(p^.mines, p^.Mm, p^.Mc);
        if (p^.build=1) then inc(bases1);
        if (b<>nil) then begin
          if (b^.cHl<>0) or (CheckClone(trec, i)>0) then inc(ships1);
        end;
        {*** reserves ***}
        if (p^.Nc>=0) then N2 := N2 + p^.Nc;
        if (p^.Tc>=0) then T2 := T2 + p^.Tc;
        if (p^.Dc>=0) then D2 := D2 + p^.Dc;
        if (p^.Mc>=0) then M2 := M2 + p^.Mc;
      end;
    end;
    {if (turn = today) then repeat until keypressed; }

    for i:=1 to 999 do begin
      sh:=trec^.data^.ship[i];
      if (sh<>nil) and (sh^.owner = player) then
      begin
        {ship}
        inc(ships0);
        if (sh^.colonists>=0) then colonists0 := colonists0 + sh^.colonists;
        if (sh^.Sup>=0) then supplies0 := supplies0 + sh^.Sup;
        if (sh^.credits>=0) then funds0 := funds0 + sh^.credits;
        if (sh^.fuel>=0) then N0 := N0 + sh^.fuel;
        if (sh^.T>=0) then T0 := T0 + sh^.T;
        if (sh^.D>=0) then D0 := D0 + sh^.D;
        if (sh^.M>=0) then M0 := M0 + sh^.M;
      end;
    end;

  end;

end;

procedure InitOwnStatData;
var
  t       : tptr;
  rec     : ResStatPtr;
begin
  DisposeStats;
  statRoot:=statOwnRoot;
  DisposeStats;
  {DisposeTurnData(TTurn);}
  t:=TRoot;
  if (t=nil) then begin TestSound; Exit; end; {oops}
  repeat
    {WriteFreeMem; Clear(0,0,100,10); OutTextXY(0,0,'A '+NStr0(t^.turn)); repeat until keypressed; readkey;}
    rec := New( ResStatPtr );
    if (t^.data<>nil) or (LoadTurnData(t) and (t^.data<>nil)) then begin
        CountResources( t, rec );
        AddStat(rec);
        {if (TTurn<>t) then DisposeTurnData(t);}
    end;
    t:=t^.next;
  until (t=nil);
  if (TTurn^.data=nil) then LoadTurnData(TTurn);
  currentStatRace:=player;
  statOwnRoot:=statRoot;
end;

procedure SelectStatData(race: int);
var
  f       : file;
  rec     : ResStatPtr;
begin
  if (statRoot<>statOwnRoot) then DisposeStats;
  statRoot:=nil;
  currentStatRace:=race;
  if (race=player) then begin
    statRoot:=statOwnRoot;
    Exit;
  end;
  if OpenData(f,'VPASTA'+NStr0(race)+'.DAT',No) then begin
    while not eof(f) do begin
      rec := New( ResStatPtr );
      BlockRead(f, rec^, sizeof(rec^));
      AddStat(rec);
    end;
    CloseData(f);
  end;
end;

procedure SaveStatData;
var
  f       : file;
  rec     : ResStatPtr;
begin
  if (statRoot=nil) then Exit;
  if (currentStatRace=player) then Exit;
  OpenW(f,'VPASTA'+NStr0(currentStatRace)+'.DAT',Yes);
  rec:=statRoot;
  while (rec<>nil) do begin
    BlockWrite( f, rec^, sizeof(rec^) );
    rec:=rec^.next;
  end;
  CloseData(f);
end;

procedure ClearStatList;
var
  i       : int;
begin
  for i:=1 to StatListMax do
    statList[i]:=0;
end;

procedure ToggleStatValue(listItem: int);
var
  i       : int;
begin
  for i:=1 to StatListMax do
    if (statList[i]=listItem) then begin
      statList[i]:=0;
      Exit;
    end;
  for i:=1 to StatListMax do
    if (statList[i]=0) then begin
      statList[i]:=listItem;
      Exit;
    end;
end;

procedure DrawHistory(turnDisplayed: int);
const XSize = 550;
      YSize = 200;
      X0  = 54;
      Y0  = 465;
      Yn  = 10;
var   rec       : ResStatPtr;
      k         : long;
      i,sc  : long;
      m1,m2 : long;
      t0  : int;
      dx        : int;
      dy  : double;
      nx,ny     : int;

  function GetValue(rec: ResStatPtr; listItem:int): long;
  var
    value, variant       : int;
  begin
    {value := listItem and StatMaskValue;}
    {variant := (listItem and StatMaskVariant) shr 8;}
    GetValue:=0;
    case listItem of
      $0001  : GetValue:=rec^.colonists0 div 10;
      $0101  : GetValue:=rec^.colonists1 div 10;
      $0002  : GetValue:=rec^.natives0 div 10;
      $0102  : GetValue:=rec^.natives1 div 10;
      $0003  : GetValue:=rec^.mines0;
      $0004  : GetValue:=rec^.factories0;
      $0005  : GetValue:=rec^.defenses0;
      $0006  : GetValue:=rec^.supplies0;
      $0106  : GetValue:=rec^.supplies1;
      $0007  : GetValue:=rec^.funds0;
      $0107  : GetValue:=rec^.funds1;
      $0008  : GetValue:=rec^.N0;
      $0108  : GetValue:=rec^.N1;
      $0208  : GetValue:=rec^.N2;
      $0009  : GetValue:=rec^.T0;
      $0109  : GetValue:=rec^.T1;
      $0209  : GetValue:=rec^.T2;
      $000a  : GetValue:=rec^.D0;
      $010a  : GetValue:=rec^.D1;
      $020a  : GetValue:=rec^.D2;
      $000b  : GetValue:=rec^.M0;
      $010b  : GetValue:=rec^.M1;
      $020b  : GetValue:=rec^.M2;
      $000c  : GetValue:=rec^.planets0;
      $000d  : GetValue:=rec^.bases0;
      $010d  : GetValue:=rec^.bases1;
      $000e  : GetValue:=rec^.ships0;
      $010e  : GetValue:=rec^.ships1;
    end;
  end;
  function GetValueName(listItem:int): str20;
  begin
    GetValueName:='?????';
    case listItem of
      $0001  : GetValueName:='Clans/10';
      $0002  : GetValueName:='Natives/10';
      $0003  : GetValueName:='Mines';
      $0004  : GetValueName:='Factories';
      $0005  : GetValueName:='Defenses';
      $0006  : GetValueName:='Supplies';
      $0007  : GetValueName:='Funds';
      $0008  : GetValueName:='Ne';
      $0009  : GetValueName:='Tr';
      $000a  : GetValueName:='Du';
      $000b  : GetValueName:='Mo';
      $000c  : GetValueName:='Planets';
      $000d  : GetValueName:='Bases';
      $000e  : GetValueName:='Ships';

      $0101  : GetValueName:='Clans/10(P)';
      $0102  : GetValueName:='Natives/10(P)';
      $0106  : GetValueName:='Supplies(P)';
      $0107  : GetValueName:='Funds(P)';
      $0108  : GetValueName:='Ne(P)';
      $0109  : GetValueName:='Tr(P)';
      $010a  : GetValueName:='Du(P)';
      $010b  : GetValueName:='Mo(P)';
      $010d  : GetValueName:='Bases(P)';
      $010e  : GetValueName:='Ships(P)';

      $0208  : GetValueName:='Ne(R)';
      $0209  : GetValueName:='Tr(R)';
      $020a  : GetValueName:='Du(R)';
      $020b  : GetValueName:='Mo(R)';
    end;
  end;
begin
  if (statRoot=nil) or (statRoot^.next=nil) then Exit;
  Clear(0,Y0-YSize-32,639,479);
  SetColor(DarkGray);
  Rectangle(X0-1,Y0+1,X0+XSize,Y0-YSize);

  rec:=statRoot; m1:=2000000; m2:=0;
  t0:=rec^.turn;
  while rec<>nil do
  begin
    for i:=1 to StatListMax do
      if (statList[i]>0) then begin
        k:=GetValue(rec,statList[i]);
        {if k>=0 then begin}
          m1:=MinL(m1,k);
          m2:=MaxL(m2,k);
        {end;}
      end;
    rec:=rec^.next;
  end;
  if (m1=m2) then m2:=m1+1;
  dx:=MaxL(XSize div (today-t0),1); { pixels per turn }
  dy:=(m2-m1) / YSize;              { units per pixel }

  nx:=0;
  ny:=Y0-YSize-24;
  for i:=1 to StatListMax do
    if (statList[i]>0) then begin
      SetColor(i);
      {legend}
      if (nx+Length(GetValueName(statList[i]))*8)>639 then begin nx:=0; ny:=ny+8; end;
      OutTextXY(nx, ny, GetValueName(statList[i]));
      nx:=nx + (Length(GetValueName(statList[i]))+1)*8;
      {graph}
      MoveTo(X0+(statRoot^.turn-t0)*dx, Round(Y0-(GetValue(statRoot,statList[i])-m1) / dy));
      rec:=statRoot^.next;
      while rec<>nil do
      begin
        sc:=GetValue(rec,statList[i]);
        {if sc>0 then LineTo(X0+(rec^.turn-t0)*dx,Round(Y0-(sc-m1) / dy))
                else MoveTo(X0+(rec^.turn-t0)*dx,Round(Y0-(sc-m1) / dy));}
        LineTo(X0+(rec^.turn-t0)*dx,Round(Y0-(sc-m1) / dy));
        rec:=rec^.next;
      end;
    end;

  {
  SetTextJustify(CenterText,TopText);
  SetColor(White);
  OutTextXY(X0+XSize div 2,Y0-YSize+16,'POWER GRAPH');
  }

  SetColor(DarkGray);
  rec:=statRoot; i:=0;
  while rec<>nil do
  begin
    k:=X0+(rec^.turn-t0)*dx;
    MoveTo(k,Y0+1);
    if k-i<32 then LineRel(0,2)
    else begin
      if (turnDisplayed<>turn) and (turnDisplayed=rec^.turn) then
        Line(k,Y0,k,Y0-YSize);
      LineRel(0,3);
      OutTextXY(k,Y0+7,NStr(rec^.turn));
      i:=k;
    end;
    rec:=rec^.next;
  end;

  SetTextJustify(RightText,CenterText);
  dx:=MaxL((((m2-m1) div Yn) div 5)*5,10);
  i:=(m1 div 5)*5;
  while i<m1+YSize*dy do
  begin
    k:=Round(Y0-(i-m1) / dy);
    MoveTo(X0-1,k); LineRel(-3,0);
    OutTextXY(X0-5,k,NStr(i));
    inc(i,dx);
  end;
  SetTextJustify(LeftText,TopText);
  OutTextXY(0,Y0+7,'turn:');
end;

procedure WriteResourceStats;
const CX1 = 14*8+4;
      CX2 = 50*8+4;
      CX3 = 70*8+4;
      lheight   = 10;
      lines     = 14;
var
      i,tmpRace: int;
      s,s1,s2,s3,s4,s5,s6 : str20;
      f : file;
      mx,my : int;
      chh : word;
      rec,tmp   : ResStatPtr;


  procedure Clr;
  var yy  : int;
  begin
    yy:=40+lines*lheight+24+7;
    Clear(1,54-4,CX1-1,yy);
    Clear(CX1+1,54-4,CX2-1,yy);
    Clear(CX3+1,54-4,638,yy);
  end;

  procedure DrawFirst;
  begin
    ClearDevice;
    SetLineStyle(SolidLn,0,NormWidth);
    SetColor(White);
    OutTextXY(640-20*8,0,'RESOURCE STATISTICS');
    Line(640-20*8,9,637-8,9);
    SetColor(LightGray);
    OutTextXY(0+4,32,' Resource      Available    Production  Reserve    ');
    Line(0,24,CX2,24);
    Line(0,47,CX2,47);
    Line(0,24,0,55);
    Line(CX1,24,CX1,55);
    Line(CX2,24,CX2,55);
    DrawHistory(turn);
  end;

  procedure DrawStatLine(i:int; k:byte; s,s1,s2,s3:str20);
  var
    s0      : str20;
    ls      : byte absolute s;
    ls0     : byte absolute s0;
    ls1     : byte absolute s1;
    ls2     : byte absolute s2;
    j       : int;
  begin
    Trim(s);
    s0:=s;
    LPad(s0,11);
    SetColor(LightGray);
    {OutTextXY(0+4, 40+i*lheight, Chr(Ord('a')+i-1)+')'+s0+'   '+s1+'   '+s2+'   '+s3);}
    OutTextXY(0+4, 40+i*lheight, '  '+s0+'   '+s1+'   '+s2+'   '+s3);
    SetColor(White);
    OutTextXY(0+4 + k*8-8 + (13-ls)*8, 40+i*lheight, s[k]);
    for j:=1 to StatListMax do
      if (statList[j] and StatMaskValue) = i then begin
        SetColor(j);
        case ( (statList[j] and StatMaskVariant) shr 8 ) of
          $00 : OutTextXY(0+4+(ls0+5)*8, 40+i*lheight, s1);
          $01 : OutTextXY(0+4+(ls0+5)*8+(ls1+3)*8, 40+i*lheight, s2);
          $02 : OutTextXY(0+4+(ls0+5)*8+(ls1+3)*8+(ls2+3)*8, 40+i*lheight, s3);
        end;
      end;
  end;

begin
  MouseOff;
  MouseDisabled:=True;
  mx:=MouseX; my:=MouseY;

  InitOwnStatData;
  DrawFirst;
  rec:=GetStat(turn);
  chh:=27;
  repeat
    s:=NStr(rec^.turn);
    Clear(5*8,0,5*8+24*8-1,7);
    SetColor(White);
    OutTextXY(0,0,'Turn '+s);
    OutTextXY(72, 0, '-  '+RaceName[rec^.race]);

    with rec^ do begin
      DrawStatLine(1,1, 'Colonists', NStrMax(colonists0*100,9,'+'), NStrMax(colonists1*100,9,'+'), '');
      DrawStatLine(2,1, 'Natives', NStrMax(natives0*100,9,'+'), NStrMax(natives1*100,9,'+'), '');
      DrawStatLine(3,1, 'Mines', NStrMax(mines0,9,'+'), '', '');
      DrawStatLine(4,2, 'Factories', NStrMax(factories0,9,'+'), '', '');
      DrawStatLine(5,1, 'Defenses', NStrMax(defenses0,9,'+'), '', '');
      DrawStatLine(6,1, 'Supplies', NStrMax(supplies0,9,'+'), NStrMax(supplies1,9,'+'), '');
      DrawStatLine(7,1, 'Funds', NStrMax(funds0,9,'+'), NStrMax(funds1,9,'+'), '');
      DrawStatLine(8,2, 'Ne', NStrMax(N0,9,'+'), NStrMax(N1,9,'+'), NStrMax(N2,9,'+'));
      DrawStatLine(9,2, 'Tr', NStrMax(T0,9,'+'), NStrMax(T1,9,'+'), NStrMax(T2,9,'+'));
      DrawStatLine(10,2, 'Du', NStrMax(D0,9,'+'), NStrMax(D1,9,'+'), NStrMax(D2,9,'+'));
      DrawStatLine(11,2, 'Mo', NStrMax(M0,9,'+'), NStrMax(M1,9,'+'), NStrMax(M2,9,'+'));
      DrawStatLine(12,1, 'Planets', NStrMax(planets0,9,'+'), '', '');
      DrawStatLine(13,1, 'Bases', NStrMax(bases0,9,'+'), NStrMax(bases1,9,'+'), '');
      DrawStatLine(14,2, 'Ships', NStrMax(ships0,9,'+'), NStrMax(ships1,9,'+'), '');
    end;

    {finish table border}
    SetColor(LightGray);
    Line(0,56,0,56+lines*lheight);
    Line(CX1,56,CX1,56+lines*lheight);
    Line(CX2,56,CX2,56+lines*lheight);
    Line(0,56+lines*lheight,CX2,56+lines*lheight);

    chh:=ReadKey;
    case chh of
      ord('-'): begin
                  if rec^.prev<>nil then
                  begin
                    rec:=rec^.prev;
                    Clr;
                    DrawHistory(rec^.turn);
                  end;
                end;
      ord('+'): begin
                  if rec^.next<>nil then
                  begin
                    rec:=rec^.next;
                    Clr;
                    DrawHistory(rec^.turn);
                  end;
                end;

      ord('c'): begin ToggleStatValue($0001); DrawHistory(rec^.turn); end;
      ord('n'): begin ToggleStatValue($0002); DrawHistory(rec^.turn); end;
      ord('m'): begin ToggleStatValue($0003); DrawHistory(rec^.turn); end;
      ord('a'): begin ToggleStatValue($0004); DrawHistory(rec^.turn); end;
      ord('d'): begin ToggleStatValue($0005); DrawHistory(rec^.turn); end;
      ord('s'): begin ToggleStatValue($0006); DrawHistory(rec^.turn); end;
      ord('f'): begin ToggleStatValue($0007); DrawHistory(rec^.turn); end;
      ord('e'): begin ToggleStatValue($0008); DrawHistory(rec^.turn); end;
      ord('r'): begin ToggleStatValue($0009); DrawHistory(rec^.turn); end;
      ord('u'): begin ToggleStatValue($000a); DrawHistory(rec^.turn); end;
      ord('o'): begin ToggleStatValue($000b); DrawHistory(rec^.turn); end;
      ord('p'): begin ToggleStatValue($000c); DrawHistory(rec^.turn); end;
      ord('b'): begin ToggleStatValue($000d); DrawHistory(rec^.turn); end;
      ord('h'): begin ToggleStatValue($000e); DrawHistory(rec^.turn); end;

      ord('C'): begin ToggleStatValue($0101); DrawHistory(rec^.turn); end;
      ord('N'): begin ToggleStatValue($0102); DrawHistory(rec^.turn); end;
      {ord('M'): begin ToggleStatValue($0103); DrawHistory(rec^.turn); end;}
      {ord('A'): begin ToggleStatValue($0104); DrawHistory(rec^.turn); end;}
      {ord('D'): begin ToggleStatValue($0105); DrawHistory(rec^.turn); end;}
      ord('S'): begin ToggleStatValue($0106); DrawHistory(rec^.turn); end;
      ord('F'): begin ToggleStatValue($0107); DrawHistory(rec^.turn); end;
      ord('E'): begin ToggleStatValue($0108); DrawHistory(rec^.turn); end;
      ord('R'): begin ToggleStatValue($0109); DrawHistory(rec^.turn); end;
      ord('U'): begin ToggleStatValue($010a); DrawHistory(rec^.turn); end;
      ord('O'): begin ToggleStatValue($010b); DrawHistory(rec^.turn); end;
      {ord('P'): begin ToggleStatValue($010c); DrawHistory(rec^.turn); end;}
      ord('B'): begin ToggleStatValue($010d); DrawHistory(rec^.turn); end;
      ord('H'): begin ToggleStatValue($010e); DrawHistory(rec^.turn); end;

      { 3      : begin ToggleStatValue($0201); DrawHistory(rec^.turn); end;}
      {14      : begin ToggleStatValue($0202); DrawHistory(rec^.turn); end;}
      {13      : begin ToggleStatValue($0203); DrawHistory(rec^.turn); end;}
      { 1      : begin ToggleStatValue($0204); DrawHistory(rec^.turn); end;}
      { 4      : begin ToggleStatValue($0205); DrawHistory(rec^.turn); end;}
      {19      : begin ToggleStatValue($0206); DrawHistory(rec^.turn); end;}
      { 6      : begin ToggleStatValue($0207); DrawHistory(rec^.turn); end;}
       5      : begin ToggleStatValue($0208); DrawHistory(rec^.turn); end;
      18      : begin ToggleStatValue($0209); DrawHistory(rec^.turn); end;
      21      : begin ToggleStatValue($020a); DrawHistory(rec^.turn); end;
      15      : begin ToggleStatValue($020b); DrawHistory(rec^.turn); end;
      {16      : begin ToggleStatValue($020c); DrawHistory(rec^.turn); end;}
      { 2      : begin ToggleStatValue($020d); DrawHistory(rec^.turn); end;}
      { 8      : begin ToggleStatValue($020e); DrawHistory(rec^.turn); end;}

{~c}  $2e00   : begin
                  ClearStatList;
                  DrawHistory(rec^.turn);
                end;
{f1}  $3B00   : begin
                  ClearDevice;
                  helpscr:=11;
                  Help;
                  DrawFirst;
                end;
{_f3} $5600   : begin
                  ExtFeatTransmitDataChoose('Statistic T'+NStr0(rec^.turn), rec, SizeOf(rec^));
                  DrawFirst;
                end;
{^f3} $6000   : begin
{
                  tmp:=statRoot;
                  ChooseReceivers;
                  while (tmp<>nil) do begin
                    TransmitCGExtDataDirect('Statistic T'+NStr0(tmp^.turn), tmp, SizeOf(tmp^));
                    tmp:=tmp^.next;
                  end;
                  DrawFirst;
}                
                end;
{left} $4B00  : if (currentStatRace>1) then begin
                  i:=rec^.turn;
                  tmpRace:=currentStatRace;
                  dec(currentStatRace);
                  SelectStatData(currentStatRace);
                  while (currentStatRace>1) and (statRoot=nil) do begin
                    dec(currentStatRace);
                    SelectStatData(currentStatRace);
                  end;
                  if (statRoot=nil) then begin
                    currentStatRace:=tmpRace;
                    SelectStatData(currentStatRace);
                  end else
                    rec:=GetClosestStat(i);
                  DrawFirst;
                end;
{right}$4D00  : if (currentStatRace<11) then begin
                  i:=rec^.turn;
                  tmpRace:=currentStatRace;
                  inc(currentStatRace);
                  SelectStatData(currentStatRace);
                  while (currentStatRace<11) and (statRoot=nil) do begin
                    inc(currentStatRace);
                    SelectStatData(currentStatRace);
                  end;
                  if (statRoot=nil) then begin
                    currentStatRace:=tmpRace;
                    SelectStatData(currentStatRace);
                  end else
                    rec:=GetClosestStat(i);
                  DrawFirst;
                end;
    end;
  until chh=27;

  {free memory}
  if (statRoot=statOwnRoot) then statOwnRoot:=nil
  else begin
    DisposeStats;
    statRoot:=statOwnRoot;
    statOwnRoot:=nil;
  end;
  DisposeStats;


  helpscr:=0;
  DrawRightScreen;
  MoveMouseTo(mx,my);
  MouseDisabled:=False;
  MouseOn;
  ResetMouse;
  if lock<>0 then begin force:=lock; ForceKey:=13 end;
  {ch:=2;}    { redraw map }
  DrawMap(true);
end;


{*****************************************************************************}
{** data transmission ** }

{
  Note: Most of the code in this section originates from the Message unit. But
  here we are able to send arbitrary data without tideous modifications to the
  original code and provide a more flexible interface. Maybe I will manage to
  integrate this into the Message unit later.
}

function CheckSender (sender:byte): boolean;
var rs      : str20;
begin
  CheckSender:=true;
  if (not (sender in [1..11])) then InitWarning('Data sender is unknown');
  if not AcceptData[sender] then
  begin
    if sender=0 then rs:='unknown senders'
                else rs:='race '+NStr(sender);
    InitWarning('Data rejected: transmissions from '+rs+' are disabled in '+VPADATA_INI);
    CheckSender:=false;
  end;
end;

procedure ExtFeatParseData(sender:byte; m:Msg; offs:byte);
var dl      : array [1..2] of word;
    ll      : long absolute dl;
    crc     : word;
    buf     : array [0..MaxOSize-1] of word;
    i       : int;
    rec     : ResStatPtr;

  function GetNumber(s:string; offs:byte): long;
  var l       : long;
      a       : int;
      ls      : byte absolute s;
  begin
    Delete(s,1,offs); LTrim(s);
    a:=1;
    while (a<=ls) and (s[a] in ['+','-','0'..'9']) do inc(a);
    ls:=a-1;
    Val(s,l,a);
    if a<>0 then InitWarning('Actual field value ('+s+') is invalid');
    GetNumber:=l;
  end;

begin
  if CheckSender(sender) then begin
  {if True then begin}

    crc:=0;
    ll:=GetNumber(m.text[offs+3],6);
    if ll=0 then crc:=1;
    dl[1]:=Max(Min(dl[1],MaxOSize div 2),0);
    if (dl[1])>SizeOf(buf) then begin
      InitWarning('Data rejected: transmission error 1');
      Exit;
    end;

    for i:=1 to (dl[1]-1) div 20+1 do
      Move(m.text[offs+3+i,1],buf[(i-1)*20],40);
    for i:=1 to dl[1] do crc:=(crc shl 1)+buf[i-1];
    if crc<>dl[2] then begin
      InitWarning('Data rejected: transmission error 2');
      Exit;
    end;

    if (Pos('OBJECT: Statistic',m.text[offs+2])>0) then begin
      rec := New(ResStatPtr);
      DecodeObject(buf,rec^,SizeOf(rec^));
      SelectStatData(sender);
      AddStat(rec);
      SaveStatData;
    end;

  end;

end;

procedure ChooseReceivers;
begin
  if (not RWMode) then Exit;
  Clear(0,0,639,479);
  DrawMsgRectangle;
  ChooseRaces(msgr,'transmit');
end;

procedure ExtFeatTransmitDataEncoded(name:str20; buf:DataMsgPtr; size:word);
var
  i,n    : int;
  m      : Msg;
  dl     : array [1..2] of word;
  ll     : long absolute dl;
begin
  if (buf=nil) then Exit;
  i:=1;
  while (i<=11) and (msgr[i]=No) do inc(i);
  while i<=11 do    { while, not if }
  begin
    m.text[1]:=TransmissionMarker;
    m.text[2]:='';
    m.text[3]:='OBJECT: '+name;
    m.lines:=(size-1) div 20+1+4;
    for i:=1 to m.lines-4 do
    begin
      Move(buf^[(i-1)*20],m.text[i+4,1],40);
      m.text[i+4,0]:=#40;
    end;
    m.text[m.lines,0]:=char((size*2-1) mod 40+1);
    dl[1]:=size;
    dl[2]:=0;
    for i:=1 to dl[1] do dl[2]:=(dl[2] shl 1)+buf^[i-1];
    m.text[4]:='DATA: '+NStr0(ll);

    n:=turn; turn:=today;
    msgt:=m_Out;
    Find1stOMsg;
    for i:=1 to 11 do
      if msgr[i] then AddMessage(i,m);
    CloseMessageFile;
    turn:=n;
    Break;
  end;
end;

procedure ExtFeatTransmitData(name:str20; obj:pointer; size:word);
var
  buf  : DataMsgBuf;
begin
  EncodeObject(obj^,buf,size);
  ExtFeatTransmitDataEncoded(name, Addr(buf), size);
end;

procedure ExtFeatTransmitDataChoose(name:str20; obj:pointer; size:word);
begin
  if (not RWMode) then Exit;
  ChooseReceivers;
  ExtFeatTransmitData(name, obj, size);
end;

procedure TransmitObjectTo(lock,recipient: int);
var
      i,n       : int;
      o         : ObjType;
      size  : word;
      op  : pointer;
      buf : array [0..MaxOSize-1] of word;
      a         : MapMark;
      s         : string;
      ls  : byte absolute s;
      name      : str20;
      ltype     : int;
begin
  if (not RWMode) or (lock=0) then Exit;
  ltype := lock and LockHi;
  o:=Obj1;
  while (o<=Obj2) and (ltype<>ObjLock[o]) do inc(o);
  if o>Obj2 then Exit;
  size:=ObjSize[o];
  n:=lock and LockLo;

  {set recipient}
  for i:=1 to 12 do msgr[i]:=No;
  msgr[recipient]:=Yes;

  {set object name}
  name:=ObjName[o];
  if o<>oMark then name:=name+' '+NStr0(n);

  {prepare data}
  with TTurn^.data^ do
  begin
    case o of
      oPlanet : op:=planet[n];
      {oBase    : op:=base[n];
      oShip   : op:=ship[n];}
      oMines  : op:=mines[n];
      oMark   : begin a:=mark^[n]; op:=Addr(a) end;
    end;
    if op<>nil then EncodeObject(op^,buf,size)
    else if (o=oPlanet) and (eplan[n].owner<>0) then FillChar(buf,SizeOf(PRec)*2,'P')
    else Exit;
    if o=oPlanet then EncodeObject(eplan[n],buf[SizeOf(PRec)],SizeOf(EPln));
    if o=oMark then
    begin
      s:=GetMarkText(n);
      EncodeObject(s,buf[SizeOf(MapMark)],ls+1);
      inc(size,ls+1);
    end;
  end;

  ExtFeatTransmitDataEncoded( name, Addr(buf), size );
end;

{*****************************************************************************}
{** data exchange subscriptions ** }

{
Create a file names VPADXCxy.INI in your game directory where x is the id of
your own race (1..B) and y the id of the receiving race (e.g. VPADXC9A.INI if
you are the Robot and want data to be sent to the Rebel). Create a section
within the file and add object ids to subscribe to:

[planets]
237
483
102

This will create messages to the receiver (y, see above) containing the data
for planets 237, 483, and 102 every time you unpack your new RST file.
}

function OpenText(var f:text; name:filename; mustbe:boolean) : boolean;
begin
  OpenText:=No;
  FileMode:=0;
  Assign(f,addir+name);
  Reset(f);
  if (IOResult<>0) or EOF(f) then
  begin
    Assign(f,name);
    Reset(f);
    if (IOResult<>0) or EOF(f) then
      if mustbe then begin Writeln(#13#10'Can''t read file ',name); Halt end
                else Exit;
  end;
  OpenText:=Yes;
end;

procedure CloseText(var f:text);
begin
  Close(f); if IOResult=0 then ;
end;

procedure HandleDXCSubscriptions;
var
  m     : byte;

  procedure HandleFile(fnm: filename; receiver: byte);
  var
    f       : text;
    s       : string;
    ls      : byte absolute s;
    sec     : CGExtDXCSec;
    id      : int;
    function GetId(s: string): int;
    var id,err: int;
    begin
      Trim(s);
      Val(s,id,err);
      if (err<>0) then id:=-1;
      GetId:=id;
    end;
  begin
    if not OpenText(f, fnm, false) then Exit;
    Writeln('Reading ',fnm,'...');
    while not eof(f) do
    begin
      Readln(f,s);
      if Pos(#10,s)<>0 then
      begin
        Writeln(#13#10#7'!!! Attention !!!'#13#10,
                'The file ',fnm,' is a UNIX-style text file!'#13#10,
                'Its format is not readable for most non-UNIX programs, including VPA.'#13#10,
                'The contents of this file are ignored.'#13#10,
                'Please provide a DOS-style version of this file.'#13#10);
        GPause:=Yes;
        CloseText(f);
        Exit;
      end;
      Trim(s);
      if (ls=0) or (s[1] in [';','#']) then Continue; {skip comments}

      {section}
      if ((s[1]='[') and (s[ls]=']')) or (s[1]='%') then
      begin
        if (s[1]<>'%') then dec(ls);
        Delete(s,1,1);
        Trim(s); Upper(s);
        sec:=CGExtDXCSec(ItemPos(s,CGExtDXCSecNames));
      end

      {values}
      else if sec<dxcsUnknown then
      begin

        if sec=dxcsPlanets then begin
          id := GetId(s);
          if (id>0) and (id<=500) then begin
            TransmitObjectTo( id or LockP, receiver );
          end;
        end;

      end;

    end;
    CloseText(f);
  end;

begin
  for m:=1 to 11 do
    if (player<>m) then
      HandleFile( DXC_PREFIX + DXC_RACE_CHAR[player] + DXC_RACE_CHAR[m] + DXC_POSTFIX, m );
end;



{*****************************************************************************}
{** borgculator ** }

procedure DisposeBC;
var
  line,tmp: BCLinePtr;
begin
  line:=bcRoot;
  repeat
    if (line<>nil) then begin
      if (line^.p<>nil) then Dispose(line^.p);
      tmp:=line;
      line:=line^.next;
      Dispose(tmp);
    end;
  until (line=nil);
  bcRoot:=nil;
end;

function GetLastBCLine: BCLinePtr;
var
  line: BCLinePtr;
begin
  line:=bcRoot;
  while (line<>nil) and (line^.next<>nil) do
    line:=line^.next;
  GetLastBCLine:=line;
end;

procedure InitBC;
var
  planet  : pptr;
begin
  if (bcRoot<>nil) then DisposeBC;
  bcStrat:=1;
  planet := New(pptr);
  bcRoot := New(BCLinePtr);
  bcRoot^.prev   := nil;
  bcRoot^.next   := nil;
  bcRoot^.turn   := 1;
  bcRoot^.pid    := 0;
  bcRoot^.p      := planet;
end;

procedure ReCalcDecay (new: pptr; old: pptr);
begin
        {structure decay}
        if (new^.factories > MaxPlanetStruct(new, 100)) then
          new^.factories := Max(MaxPlanetStruct(new, 100), new^.factories-StructureDecay);
        if (new^.mines > MaxPlanetStruct(new, 200)) then
          new^.mines := Max(MaxPlanetStruct(new, 200), new^.mines-StructureDecay);
end;

procedure ReCalcPlanet (new: pptr; old: pptr);
var tmp : long;
begin
        {happiness}
        new^.Cstat := new^.Cstat+CGExtCHappyChange(new);
        if (new^.Cstat>100) then new^.Cstat:=100
        else if (new^.Cstat<-300) then new^.Cstat:=-300;
        new^.Nstat := new^.Nstat+CGExtNHappyChange(new);
        if (new^.Nstat>100) then new^.Nstat:=100
        else if (new^.Nstat<-300) then new^.Nstat:=-300;
        {produce supplies}
        new^.supplies := new^.supplies+SupplyProduction(new);
        {produce taxes}
        new^.funds := new^.funds+ExtFeatPlanetIncome(new);
        {population growth+Overpop+Amorph+Civil War}
        new^.colonists := new^.colonists + ColonistGrowth(new, -1, tmp);
        new^.natives   := new^.natives   + NativeGrowth(new, -1);
        {Riots}
        if (new^.Cstat<40) then begin
          new^.factories := max(new^.factories-8,0);
          new^.mines := max(new^.mines-10,0);
        end;
        if (new^.Nstat<40) then begin
          new^.factories := max(new^.factories-3,0);
          new^.mines := max(new^.mines-5,0);
        end;
        {Civil War}
        if (new^.Cstat<0) then begin
          new^.factories := max(new^.factories-8,0);
          new^.mines := max(new^.mines-10,0);
        end;
        if (new^.Nstat<0) then begin
          new^.factories := max(new^.factories-8,0);
          new^.mines := max(new^.mines-10,0);
        end;
        
end;

procedure RecalcBC(start: BCLinePtr);
var
  line    : BCLinePtr;
  tmp     : long;
begin
  if (start=nil) then Exit;
  line := start;
  while (line<>nil) do begin
    if (line^.prev<>nil) then begin
      if (line^.p=nil) then begin
        line^.turn := line^.prev^.turn + 1;
        line^.pid  := line^.prev^.pid;
        line^.p    := New(pptr);
        line^.p^   := line^.prev^.p^;
      end;
      {calc changes}
      ReCalcDecay (line^.p, line^.prev^.p);
      ReCalcPlanet (line^.p, line^.prev^.p);
      (* with line^.prev^ do begin
        {structure decay}
        if (line^.p^.factories > MaxPlanetStruct(line^.p, 100)) then
          line^.p^.factories := Max(MaxPlanetStruct(line^.p, 100), line^.p^.factories-StructureDecay);
        {happiness}
        line^.p^.Cstat := p^.Cstat+CGExtCHappyChange(p);
        if (line^.p^.Cstat>100) then line^.p^.Cstat:=100
        else if (line^.p^.Cstat<-300) then line^.p^.Cstat:=-300;
        line^.p^.Nstat := p^.Nstat+CGExtNHappyChange(p);
        if (line^.p^.Nstat>100) then line^.p^.Nstat:=100
        else if (line^.p^.Nstat<-300) then line^.p^.Nstat:=-300;
        {produce supplies}
        line^.p^.supplies := p^.supplies+SupplyProduction(p);
        {produce taxes}
        line^.p^.funds := p^.funds+ExtFeatPlanetIncome(p);
        {population growth}
        line^.p^.colonists := p^.colonists + ColonistGrowth(p, -1, tmp);
        line^.p^.natives   := p^.natives   + NativeGrowth(p, -1);
{Clear(0,0,30,8);OutTextXY(0,0,NStr0(PlanetIncome(p,-1,TRUE)));}
      end; *)
    end;
    line:=line^.next;
  end;
end;


procedure AppendBCLine(parent: BCLinePtr);
var
  {planet  : pptr;}
  line    : BCLinePtr;
begin
  {if (parent^.p^.owner<=0) then Exit;}
  line    := New(BCLinePtr);
  line^.prev  := parent;
  if (parent^.next<>nil) then begin
    parent^.next^.prev := line;
    line^.next  := parent^.next;
  end else
    line^.next  := nil;
  parent^.next := line;
  {line^.p      := planet;}
  line^.p      := nil;
  RecalcBC( line );
end;

procedure BCChangeOwner(owner:int);
var
  line    : BCLinePtr;
begin
  line:=bcRoot;
  while (line<>nil) do begin
    line^.p^.owner:=owner;
    line:=line^.next;
  end;
  RecalcBC(bcRoot);
end;

procedure BCAcceptPln;
var
  planet  : pptr;
  id      : int;
begin
  if (bcRoot=nil) then Exit;
  id := lock and LockLo;
  planet:=TTurn^.data^.planet[id];
  if planet=nil then Exit;
  bcRoot^.turn  := turn;
  bcRoot^.pid   := id;
  bcRoot^.p^    := planet^;
end;

procedure BCDump(var t: text);
var
  l       : BCLinePtr;
  i,j     : byte;
  s       : str20;
begin
  writeln(t, 'BORGCULATOR REPORT');
  writeln(t, '------------------');
  writeln(t);
  writeln(t, 'Planet          : '+PlanName[bcRoot^.pid]);
  writeln(t, 'Number          : '+NStr0(bcRoot^.pid));
  writeln(t, 'Owner           : '+RaceName[bcRoot^.p^.owner]);
  writeln(t, 'Preset Strategy :  '+BCStrategies[bcStrat]);
  writeln(t);
  writeln(t, 'Trn Temp NatClan Hap. Tax  Funds  Mine Fact Def  Suppl ColClan Hap. Tax  Income');
  writeln(t, '-------------------------------------------------------------------------------');

  l := bcRoot;
  i:=0;
  while (l<>nil) do begin
    SetColor(LightGray);
    if (l^.p=nil) then Continue;
    with l^ do begin
      s:=NStr0(turn); LPad(s, 3);
      write(t, s);
      s:=NStr0(100-p^.climate); LPad(s, 5);
      write(t, s);
      s:=NStr0(p^.natives); LPad(s, 8);
      write(t, s);
      s:=NStr0(p^.Nstat)+'%'; LPad(s, 5);
      write(t, s);
      s:=NStr0(p^.Ntax)+'%'; LPad(s, 5);
      write(t, s);
      {funds}
      s:=NStr0(p^.funds); LPad(s, 7);
      write(t, s);
      s:=NStr0(p^.mines); LPad(s, 5);
      write(t, s);
      s:=NStr0(p^.factories); LPad(s, 5);
      write(t, s);
      s:=NStr0(p^.defense); LPad(s, 5);
      write(t, s);
      s:=NStr0(p^.supplies); LPad(s, 6);
      write(t, s);
      s:=NStr0(p^.colonists); LPad(s, 8);
      write(t, s);
      s:=NStr0(p^.Cstat)+'%'; LPad(s, 5);
      write(t, s);
      s:=NStr0(p^.Ctax)+'%'; LPad(s, 5);
      write(t, s);
      if (l^.prev<>nil) then begin
        s:=NStr0(p^.funds - l^.prev^.p^.funds); LPad(s, 7);
        write(t, s);
      end;
      writeln(t);
    end;
    inc(i);
    l:=l^.next;
  end;

  writeln(t, '-------------------------------------------------------------------------------');
  writeln(t);
end;

procedure BCFile;
var   s : str40;
      ls  : byte absolute s;
      t : text;
      over  : boolean;
      i : byte;
      ynkey : word;
  procedure ClearKeyArea;
  begin
    Clear(0,464,639,479);
  end;
  procedure WriteFName;
  begin
    ClearKeyArea;
    SetColor(LightGray);
    OutTextXY(0,472,bcfilename);
  end;
  function AskYN (ykey,nkey:char) : boolean;
  begin
    repeat ynkey:=ReadKey until ynkey in [13,27,byte(ykey),byte(nkey)];
    AskYN:=(ynkey in [13,byte(ykey)]);
  end;
begin
  WriteFName;
  SetColor(White);
  OutTextXY(0,464,'Enter file name to save message to:');
  s:=GetStr(0,472,40);
  if GetStrKey=27 then Exit;
  if (ls=0) and (GetStrKey=13) then s:=bcfilename else bcfilename:=s;
  if bcfilename[0]=#0 then Exit;
  over:=No;
  Assign(t,bcfilename);
  Reset(t);
  if IOResult=0 then
  begin
    Close(t);
    WriteFName;
    SetColor(White);
    OutTextXY(0,464,'File already exists.Append or Overwrite?');
    SetColor(Yellow);
    OutTextXY(20*8,464,'A         O');
    if AskYN('a','o') then Append(t)
    else begin
      if ynkey=27 then Exit;
      over:=Yes;
    end;
  end
  else over:=Yes;
  if over then
  begin
    Rewrite(t);
    if IOResult<>0 then
    begin
      WriteFName;
      SetColor(LightRed);
      OutTextXY(0,464,'Can''t write file. Press any key...');
      ReadKey;
      Exit;
    end;
  end;

  BCDump(t);

  Close(t);
  if IOResult=0 then ;
  WriteFName;
  SetColor(White);
  OutTextXY(0,464,'Report has been saved. Press any key...');
  ReadKey;
  ClearKeyArea;
end;

procedure BCStratToolStructures(p:pptr; mineralThh, miningThh, maxMines: int);
var
  gMines,
  gFact,
  gDef    : int;
  i,j     : long;
begin
  if (p=nil) then Exit;
  with p^ do begin
    {Determine goals for planetary structures.}
    gDef  := Min( IIF( (natives>colonists), 20, 15 ), MaxPlanetStruct(p, 50) );
    gFact := MaxPlanetStruct(p, 100) - 5;
    if ( ((Nc>mineralThh) and (Nm>miningThh))
         or ((Nc>mineralThh) and (Nm>miningThh))
         or ((Nc>mineralThh) and (Nm>miningThh)) )
    then
      gMines := Min( maxMines, MaxPlanetStruct(p, 200) )
    else
      gMines := 20;

    {Build up to 14 factories w/o defense.}
    if (factories<14) and (factories<gFact) then begin
      i:=Min( 14-factories, Min( funds div 3, supplies ) );
      if (i>0) then begin
        inc(factories, i); dec(funds, (i*3)); dec(supplies, i);
      end;
    end;
    {Build defenses to protect from sensor sweeps.}
    if (factories>=14) then begin
      i:=Min( gDef-defense, Min( funds div 10, supplies ) );
      if (i>0) then begin
        inc(defense, i); dec(funds, (i*10)); dec(supplies, i);
      end;
    end;
    {Build more structures if enough defenses present.}
    if (defense>=gDef) then begin
      if (factories<gFact) then begin
        i:=Min( gFact-factories, Min( funds div 3, supplies ) );
        if (i>0) then begin
          inc(factories, i); dec(funds, (i*3)); dec(supplies, i);
        end;
      end;
      if (mines<gMines) then begin
        i:=Min( gMines-mines, Min( funds div 4, supplies ) );
        if (i>0) then begin
          inc(mines, i); dec(funds, (i*4)); dec(supplies, i);
        end;
      end;
    end;
  end;
end;

procedure BCStratToolTax(p:pptr; minHap:int; nat: boolean);
var
  i,j     : long;
begin
  if (minHap>=0) and (p<>nil) then begin
    with p^ do begin
      if (nat) then begin
        i:=ExtFeatPlanetIncome(p);
        while (Ntax>0) and ( (ExtFeatPlanetIncome(p)=i)
                             or (ExtFeatPlanetIncome(p)>MaxIncome)
                             or (Nstat+CGExtNHappyChange(p)<minHap)) do begin
          i:=ExtFeatPlanetIncome(p);
          j:=Nstat+CGExtNHappyChange(p);
          dec(Ntax);
        end;
        {TODO: implement threshold based on income-steps?}
        if (ExtFeatPlanetIncome(p)<i) and (j>=minHap) then
          inc(Ntax);
      end else begin
        i:=ExtFeatPlanetIncome(p);
        while (Ctax>0) and ( (ExtFeatPlanetIncome(p)=i)
                             or (ExtFeatPlanetIncome(p)>MaxIncome)
                             or (Cstat+CGExtCHappyChange(p)<minHap) ) do
        begin
          i:=ExtFeatPlanetIncome(p);
          j:=Cstat+CGExtCHappyChange(p);
          dec(Ctax);
        end;
        {TODO: implement threshold based on income-steps?}
        if (ExtFeatPlanetIncome(p)<i) and (j>=minHap) then
          inc(Ctax);
      end;
    end;
  end;
end;

procedure BCStratBorgGrowthOptimized(maxLines:byte);
const
  mineralThh       = 1500;
  miningThh        = 50;
var
  l,ltmp  : BCLinePtr;
  n       : byte;
  minHap  : int;
  gMines,
  gFact,
  gDef    : int;
  i,j,tmp : long;
  term    : boolean;
begin
  if (bcRoot=nil) then Exit;
  l:=bcRoot;
  term:=false;
  n:=0;
  while (l<>nil) and (n<maxLines) and not term do begin
    BCStratToolStructures(l^.p, mineralThh, miningThh, 200);
    with l^.p^ do begin

      {Tax natives for as much money as we can collect but don't let then
       slip below happy=40 or happy=31 if they will be assimilated completely.}
      if (natives>0) and (Nrace<>5) then begin
        minHap:=IIF( ((natives<colonists) and (owner=6)), 31, 40 );
        Ntax:=20;
        BCStratToolTax(l^.p, minHap, true);
      end else Ntax:=0;

      {Determine Ctax.}
      Ctax:=0;
      if (ColonistGrowth(l^.p, -1, tmp)<=0) then
        {Tax clans down to happy=40 if they are not growing any more.}
        minHap:=40
      else begin
        if (natives>0) and (Nrace<>5) then
          {Keep clans at happy=100 during assimilation process.}
          minHap:=100
        else begin
          ltmp:=l; i:=0; Ctax:=0;
          while (ltmp<>nil) and (ltmp^.p^.Ctax=0) do begin inc(i); ltmp:=ltmp^.prev; end;
          if (i>2) or (l=bcRoot) or (Cstat>92) then
            {Tax clans down to happy=70 every 3 turns.}
            minHap:=70
          else
            minHap:=-1; {Leave Ctax at 0%.}
        end;
      end;
      if (minHap>0) then begin
        Ctax:=100;
        BCStratToolTax(l^.p, minHap, false);
      end;

    end;

    if (l^.next=nil) then
      if (n<maxLines-1) then
        AppendBCLine(l)
    else
      RecalcBC(l^.next);
    l:=l^.next;
    inc(n);
  end;
end;

procedure BCStratBorgConstantTax(maxLines:byte);
const
  mineralThh       = 1500;
  miningThh        = 50;
var
  l,ltmp  : BCLinePtr;
  n       : byte;
  minHap  : int;
  gMines,
  gFact,
  gDef    : int;
  i,j,tmp : long;
  term    : boolean;
begin
  if (bcRoot=nil) then Exit;
  l:=bcRoot;
  term:=false;
  n:=0;
  while (l<>nil) and (n<maxLines) and not term do begin
    BCStratToolStructures(l^.p, mineralThh, miningThh, 200);
    with l^.p^ do begin

      {Tax natives for as much money as we can collect but don't let then
       slip below happy=40 or happy=31 if they will be assimilated completely.}
      if (natives>0) and (Nrace<>5) then begin
        minHap:=IIF( ((natives<colonists) and (owner=6)), 31, 40 );
        Ntax:=20;
        BCStratToolTax(l^.p, minHap, true);
      end else Ntax:=0;

      {Determine Ctax.}
      if (ColonistGrowth(l^.p, -1, tmp)<=0) then
        {Tax clans down to happy=40 if PopLimit is reached.}
        minHap:=40
      else begin
        if (natives>0) and (Nrace<>5) then
          {Keep clans at happy=100 during assimilation process.}
          minHap:=100
        else begin
          {Always tax clans down to happy=70.}
          minHap:=70
        end;
      end;
      if (minHap>0) then begin
        Ctax:=100;
        BCStratToolTax(l^.p, minHap, false);
      end;

    end;

    if (l^.next=nil) then
      if (n<maxLines-1) then
        AppendBCLine(l)
    else
      RecalcBC(l^.next);
    l:=l^.next;
    inc(n);
  end;
end;

procedure BCStratGrowthOptimized(maxLines:byte);
const
  mineralThh       = 1500;
  miningThh        = 50;
var
  l,ltmp  : BCLinePtr;
  n       : byte;
  minHap  : int;
  i,j,tmp : long;
  term    : boolean;
begin
  if (bcRoot=nil) then Exit;
  l:=bcRoot;
  term:=false;
  n:=0;
  while (l<>nil) and (n<maxLines) and not term do begin
    BCStratToolStructures(l^.p, mineralThh, miningThh, 200);
    with l^.p^ do begin

      {Determine Ntax.}
      Ntax:=0;
      if (natives>0) and (Nrace<>5) then begin
        if (natives>=NPopulationLimit(l^.p)) then
          {Tax natives down to happy=40 if PopLimit is reached.}
          minHap:=40
        else begin
          ltmp:=l; i:=0;
          while (ltmp<>nil) and (ltmp^.p^.Ntax=0) do begin inc(i); ltmp:=ltmp^.prev; end;
          if (i>2) or (l=bcRoot) or (Nstat>92) then
            {Tax clans down to happy=70 every 3 turns.}
            minHap:=70
          else
            minHap:=-1; {Leave Ntax at 0%.}
        end;
        if (minHap>0) then begin
          Ntax:=100;
          BCStratToolTax(l^.p, minHap, true);
        end;
      end;

      {Determine Ctax.}
      Ctax:=0;
      if (ColonistGrowth(l^.p, -1, tmp)<=0) then
        {Tax clans down to happy=40 if PopLimit is reached.}
        minHap:=40
      else begin
        {Tax clans down to happy=70 every 3 turns.}
        ltmp:=l; i:=0;
        while (ltmp<>nil) and (ltmp^.p^.Ctax=0) do begin inc(i); ltmp:=ltmp^.prev; end;
          if (i>2) or (l=bcRoot) or (Cstat>92) then
          minHap:=70
        else
          minHap:=-1; {Leave Ctax at 0%.}
      end;
      if (minHap>0) then begin
        Ctax:=100;
        BCStratToolTax(l^.p, minHap, false);
      end;

    end;

    if (l^.next=nil) then
      if (n<maxLines-1) then
        AppendBCLine(l)
    else
      RecalcBC(l^.next);
    l:=l^.next;
    inc(n);
  end;
end;

procedure BCStratConstantTax(maxLines:byte);
const
  mineralThh       = 1500;
  miningThh        = 50;
var
  l,ltmp  : BCLinePtr;
  n       : byte;
  minHap  : int;
  i,j,tmp : long;
  term    : boolean;
begin
  if (bcRoot=nil) then Exit;
  l:=bcRoot;
  term:=false;
  n:=0;
  while (l<>nil) and (n<maxLines) and not term do begin
    BCStratToolStructures(l^.p, mineralThh, miningThh, 200);
    with l^.p^ do begin

      {Determine Ntax.}
      Ntax:=0;
      if (natives>0) and (Nrace<>5) then begin
        if (natives>=NPopulationLimit(l^.p)) then
          {Tax natives down to happy=40 if PopLimit is reached.}
          minHap:=40
        else begin
          {Always tax clans down to happy=70.}
          minHap:=70
        end;
        if (minHap>0) then begin
          Ntax:=100;
          BCStratToolTax(l^.p, minHap, true);
        end;
      end;

      {Determine Ctax.}
      Ctax:=0;
      if (ColonistGrowth(l^.p, -1, tmp)<=0) then
        {Tax clans down to happy=40 if PopLimit is reached.}
        minHap:=40
      else begin
        {Always tax clans down to happy=70.}
        minHap:=70
      end;
      if (minHap>0) then begin
        Ctax:=100;
        BCStratToolTax(l^.p, minHap, false);
      end;

    end;

    if (l^.next=nil) then
      if (n<maxLines-1) then
        AppendBCLine(l)
    else
      RecalcBC(l^.next);
    l:=l^.next;
    inc(n);
  end;
end;

procedure Borgculator;
const
  CX0 = 4;
  CX1 = 14*8+4;
  CX3 = 80*8;
  {CY0   = 32; CY1   = 46;}
  CY0   = 120;
  CY1   = CY0+14;
  lheight   = 12;
  lines     = 25;

var
  i         : int;
  mx,my     : int;
  chh       : word;
  tmpline   : BCLinePtr;
  cursor    : BCLinePtr;
  cursPos   : int;

  procedure SetOwner;
  var   x,y,owner  : int;
        ch         : word;
        s          : str20;
  begin
    if (bcRoot=nil) then Exit;
    x:=18*8;
    y:=56;
    Clear(x, y, x+20*8, y+7);
    owner:=bcRoot^.p^.owner;
    repeat
      Clear(x, y, x+20*8, y+7);
      SetColor(White);
      OutTextXY(x,y,'  '+RaceName[owner]);
      repeat ArrowBlink(x,y) until KeyPressed;
      ch:=ReadKey;
      case ch of
        $4B00   : begin
                    dec(owner);
                    if (owner)<1 then owner:=11;
                  end;
        $4D00   : begin
                    inc(owner);
                    if (owner)>11 then owner:=1;
                  end;
      end;
    until (ch=13) or (ch=27);
    if (ch=13) then begin
       BCChangeOwner(owner);
    end;
    Clear(x, y, x+20*8, y+7);
  end;

  procedure SetStrategy;
  var   x,y        : int;
        strat      : byte;
        ch         : word;
        s          : str20;
  begin
    if (bcRoot=nil) then Exit;
    x:=18*8;
    y:=68;
    Clear(x, y, x+20*8, y+7);
    strat:=bcStrat;
    repeat
      Clear(x, y, x+20*8, y+7);
      SetColor(White);
      OutTextXY(x,y,'  '+BCStrategies[strat]);
      repeat ArrowBlink(x,y) until KeyPressed;
      ch:=ReadKey;
      case ch of
        $4B00   : begin
                    dec(strat);
                    if strat<1 then strat:=1;
                  end;
        $4D00   : begin
                    inc(strat);
                    if strat>BCStrategiesN then strat:=BCStrategiesN;
                  end;
      end;
    until (ch=13) or (ch=27);
    if (ch=13) then begin
       bcStrat:=strat;
    end;
    Clear(x, y, x+20*8, y+7);
  end;

  procedure SetPercent(xc: byte; var perc:int);
  var   x,y,perc0  : int;
        ch         : word;
        s          : str20;
  begin
    if (cursor=nil) then Exit;
    x:=CX0+xc*8;
    y:=CY1+lheight*cursPos;
    Clear(x, y, x+5*8, y+7);
    perc0:=perc;
    repeat
      Clear(x, y, x+5*8, y+7);
      SetColor(White);
      s:=NStr0(perc)+'%'; LPad(s,5); OutTextXY(x, CY1+lheight*cursPos, s);
      repeat ArrowBlink(x,y) until KeyPressed;
      ch:=ReadKey;
      case ch of
        $4B00   : if perc>0 then
                  begin
                    if KbdFlags and KbdShft=0 then dec(perc) else perc:=0;
                  end;
        $4D00   : if perc<100 then
                  begin
                    if KbdFlags and KbdShft=0 then inc(perc) else perc:=100;
                  end;
        $7300   : if perc>=10 then
                  begin
                    dec(perc,10);
                  end;
        $7400   : if perc<=90 then
                  begin
                    inc(perc,10);
                  end;
      end;
    until (ch=13) or (ch=27);
    if (ch=27) then perc:=perc0;
    Clear(x, y, x+5*8, y+7);
  end;

  procedure SetValue(xc,l: byte; maxv:long; var v:long);
  var   x,y,v0  : int;
        ch         : word;
        s          : str20;
        k          : long;
  begin
    if (cursor=nil) then Exit;
    x:=CX0+xc*8;
    y:=CY1+lheight*cursPos;
    Clear(x, y, x+l*8+8, y+7);
    v0:=v;
    repeat
      Clear(x, y, x+l*8+8, y+7);
      SetColor(White);
      s:='  '+NStr0(v); OutTextXY(x, y, s);
      {SetColor(Yellow); Line(x,y+7,x+47,y+7);}
      repeat ArrowBlink(x,y) until KeyPressed;
      {SetColor(Black); Line(x,y+7,x+47,y+7);}
      ch:=ReadKey;
      case ch of
        $4B00   : if KbdFlags and KbdShft=0 then
                    if v>0 then dec(v)
                  else
                    v:=0;
        $4D00   : if KbdFlags and KbdShft=0 then
                    if v<maxv then inc(v)
                  else
                    v:=maxv;
        $7300   : if (v>10) then dec(v,10);
        $7400   : if (v<maxv-10) then inc(v,10);
        $9B00   : if (v>100) then dec(v,100);
        $9D00   : if (v<maxv-100) then inc(v,100);
        ord('0')..ord('9')      : begin
                    GetStr1stKey:=ch;
                    s:=GetStr(x+16,y,6);
                    if GetStrKey=13 then
                    begin
                      v:=MinL( maxv, MaxL(Value(s), 0) );
                    end;
                  end;
      end;
    until (ch=13) or (ch=27);
    if (ch=27) then v:=v0;
    Clear(x, y, x+l*8+8, y+7);
  end;

  procedure SetIntValue(xc,l: byte; maxv:int; var v:int);
  var
    v0: long;
  begin
    v0:=v;
    SetValue(xc,l,maxv,v0);
    if (v0>maxv) then v:=maxv
    else v:=v0;
  end;

  procedure Clr;
  var yy  : int;
  begin
    yy:=CY1+lines*lheight;
    Clear(CX0-2,CY1-2,CX3+2,yy+1);
  end;

  procedure DrawFirst;
  begin
    ClearDevice;
    SetLineStyle(SolidLn,0,NormWidth);
    SetColor(White);
    OutTextXY(320-5*8-4,0,'BORGCULATOR');
    Line(320-5*8-4,9,320-5*8-4+11*8,9);

    if (bcRoot<>nil) then begin
      SetColor(LightGray);
      OutTextXY(0,32,' Planet          :  '+PlanName[bcRoot^.pid]);
      OutTextXY(0,44,' Number          :  '+NStr0(bcRoot^.pid));
      OutTextXY(0,56,' Owner           :  '+RaceName[bcRoot^.p^.owner]);
      OutTextXY(0,68,' Preset Strategy :  '+BCStrategies[bcStrat]);
    end;

    OutTextXY(400, 32,'R     - Report to File');
    OutTextXY(400, 40,'<SPC> - Import locked Planet');
    OutTextXY(400, 48,'Del   - Remove last line');
    OutTextXY(400, 56,'Alt-C - Reset Borgculator');
    OutTextXY(400, 64,'F1    - Help');

    SetColor(LightGray);
    OutTextXY(CX0,CY0,'Trn Temp NatClan Hap. Tax  Funds  Mine Fact Def  Suppl ColClan Hap. Tax  Income');
    Line(CX0,CY0-2,CX3-1,CY0-2);
    Line(CX0,CY0+9,CX3-1,CY0+9);
    Line(CX0,CY1+lines*lheight+2,CX3-1,CY1+lines*lheight+2);
    SetColor(White);
    OutTextXY(8,56,'O');
    OutTextXY(112,68,'g');
    OutTextXY(CX0+5*8,CY0,'e');
    OutTextXY(CX0+9*8,CY0,'N');
    OutTextXY(CX0+17*8,CY0,'H');
    OutTextXY(CX0+22*8,CY0,'T');
    OutTextXY(CX0+28*8,CY0,'u');
    OutTextXY(CX0+34*8,CY0,'M');
    OutTextXY(CX0+40*8,CY0,'a');
    OutTextXY(CX0+44*8,CY0,'D');
    OutTextXY(CX0+49*8,CY0,'S');
    OutTextXY(CX0+55*8,CY0,'C');
    OutTextXY(CX0+65*8,CY0,'p');
    OutTextXY(CX0+70*8,CY0,'x');
  end;

  procedure DrawBCLines;
  var
    l       : BCLinePtr;
    i,j     : byte;
    s       : str20;
  begin
    Clr;
    l := bcRoot;
    i:=0;
    while (l<>nil) do begin
      SetColor(LightGray);
      if (l^.p=nil) then Continue;
      with l^ do begin
        s:=NStr0(turn); LPad(s, 3);
        OutTextXY(CX0     , CY1+i*lheight, s);
        s:=NStr0(100-p^.climate); LPad(s, 5);
        OutTextXY(CX0+ 3*8, CY1+i*lheight, s);
        s:=NStr0(p^.natives); LPad(s, 8);
        OutTextXY(CX0+ 8*8, CY1+i*lheight, s);
        s:=NStr0(p^.Nstat)+'%'; LPad(s, 5);
        OutTextXY(CX0+16*8, CY1+i*lheight, s);
        s:=NStr0(p^.Ntax)+'%'; LPad(s, 5);
        OutTextXY(CX0+21*8, CY1+i*lheight, s);
        {funds}
        s:=NStr0(p^.funds); LPad(s, 7);
        OutTextXY(CX0+26*8, CY1+i*lheight, s);
        s:=NStr0(p^.mines); LPad(s, 5);
        OutTextXY(CX0+33*8, CY1+i*lheight, s);
        s:=NStr0(p^.factories); LPad(s, 5);
        OutTextXY(CX0+38*8, CY1+i*lheight, s);
        s:=NStr0(p^.defense); LPad(s, 5);
        OutTextXY(CX0+43*8, CY1+i*lheight, s);
        s:=NStr0(p^.supplies); LPad(s, 6);
        OutTextXY(CX0+48*8, CY1+i*lheight, s);
        s:=NStr0(p^.colonists); LPad(s, 8);
        OutTextXY(CX0+54*8, CY1+i*lheight, s);
        s:=NStr0(p^.Cstat)+'%'; LPad(s, 5);
        OutTextXY(CX0+62*8, CY1+i*lheight, s);
        s:=NStr0(p^.Ctax)+'%'; LPad(s, 5);
        OutTextXY(CX0+67*8, CY1+i*lheight, s);
        if (l^.prev<>nil) then begin
          s:=NStr0(p^.funds - l^.prev^.p^.funds); LPad(s, 7);
          OutTextXY(CX0+72*8, CY1+i*lheight, s);
        end;
      end;
      if (l=cursor) then begin
        SetColor(White);
        Line(CX0-2, CY1+i*lheight-2, CX0-2, CY1+i*lheight+9);
        Line(CX3-2, CY1+i*lheight-2, CX3-2, CY1+i*lheight+9);
        Line(CX0-2, CY1+i*lheight-2, CX3-2, CY1+i*lheight-2);
        Line(CX0-2, CY1+i*lheight+9, CX3-2, CY1+i*lheight+9);
      end;
      inc(i);
      l:=l^.next;
    end;
  end;

begin
  if (lock=0) or (TTurn^.data^.planet[lock and LockLo]=nil) then Exit;

  MouseOff;
  MouseDisabled:=True;
  mx:=MouseX; my:=MouseY;

  if (bcRoot=nil) then begin InitBC; BCAcceptPln; end;
  cursor:=bcRoot;
  cursPos:=0;
  DrawFirst;

  chh:=27;
  repeat
    DrawBCLines;

    chh:=ReadKey;
    case chh of

{f1}  $3B00   : begin
                  ClearDevice;
                  helpscr:=12;
                  Help;
                  DrawFirst;
                end;
  32  : if (ltype=LockP) then begin BCAcceptPln; DrawFirst; end;
{~c}    $2e00   : begin
                    DisposeBC; InitBC; BCAcceptPln; cursor:=bcRoot; cursPos:=0; DrawFirst;
                  end;
{up}    $4800   : if (cursor<>bcRoot) then begin cursor:=cursor^.prev; dec(cursPos); end;
{down}  $5000   : if (cursor^.turn-bcRoot^.turn < lines-1) then begin
                    if (cursor^.next<>nil) then begin
                      cursor:=cursor^.next;
                      inc(cursPos);
                    end else begin
                      AppendBCLine(cursor);
                      if (cursor^.next<>nil) then begin
                        cursor:=cursor^.next;
                        inc(cursPos);
                      end;
                    end;
                  end;
{del}   $5300   : if (bcRoot^.next<>nil) then begin
                    tmpline:=GetLastBCLine;
                    if (cursor=tmpline) then begin cursor:=cursor^.prev; dec(cursPos); end;
                    tmpline^.prev^.next:=nil;
                    Dispose(tmpline);
                  end;
  ord('e'): begin
                    i:=100-cursor^.p^.climate;
                    SetIntValue(3,5,100,i);
                    cursor^.p^.climate:=100-i;
                    RecalcBC(cursor^.next);
                  end;
  ord('o'): begin SetOwner; DrawFirst; end;
  ord('g'): begin
                    i:=bcStrat;
                    SetStrategy;
                    if (i<>bcStrat) then
                      case bcStrat of
                        02 : BCStratBorgGrowthOptimized(lines);
                        03 : BCStratBorgConstantTax(lines);
                        04 : BCStratGrowthOptimized(lines);
                        05 : BCStratConstantTax(lines);
                      end;
                    DrawFirst;
                  end;
  ord('n'): begin SetValue(8,8,160000, cursor^.p^.natives); RecalcBC(cursor^.next); end;
  ord('h'): begin SetPercent(16, cursor^.p^.Nstat); RecalcBC(cursor^.next); end;
  ord('t'): begin SetPercent(21, cursor^.p^.Ntax); RecalcBC(cursor^.next); end;
  ord('u'): begin SetValue(26,7,99999, cursor^.p^.funds); RecalcBC(cursor^.next); end;
  ord('m'): begin
                    i:=cursor^.p^.mines;
                    SetIntValue(33,5,9999, cursor^.p^.mines);
                    if (cursor^.p^.mines > MaxPlanetStruct(cursor^.p, 200)) then
                      cursor^.p^.mines := MaxPlanetStruct(cursor^.p, 200);
                    cursor^.p^.funds := cursor^.p^.funds - (cursor^.p^.mines-i)*4;
                    cursor^.p^.supplies := cursor^.p^.supplies - (cursor^.p^.mines-i);
                    RecalcBC(cursor^.next);
                  end;
  ord('a'): begin
                    i:=cursor^.p^.factories;
                    SetIntValue(38,5,9999, cursor^.p^.factories);
                    if (cursor^.p^.factories > MaxPlanetStruct(cursor^.p, 100)) then
                      cursor^.p^.factories := MaxPlanetStruct(cursor^.p, 100);
                    cursor^.p^.funds := cursor^.p^.funds - (cursor^.p^.factories-i)*3;
                    cursor^.p^.supplies := cursor^.p^.supplies - (cursor^.p^.factories-i);
                    RecalcBC(cursor^.next);
                  end;
  ord('d'): begin
                    i:=cursor^.p^.defense;
                    SetIntValue(43,5,9999, cursor^.p^.defense);
                    if (cursor^.p^.defense > MaxPlanetStruct(cursor^.p, 50)) then
                      cursor^.p^.defense := MaxPlanetStruct(cursor^.p, 50);
                    cursor^.p^.funds := cursor^.p^.funds - (cursor^.p^.defense-i)*10;
                    cursor^.p^.supplies := cursor^.p^.supplies - (cursor^.p^.defense-i);
                    RecalcBC(cursor^.next);
                  end;
  ord('s'): begin SetValue(48,6,99999, cursor^.p^.supplies); RecalcBC(cursor^.next); end;
  ord('c'): begin SetValue(54,8,100000, cursor^.p^.colonists); RecalcBC(cursor^.next); end;
  ord('p'): begin SetPercent(62, cursor^.p^.Cstat); RecalcBC(cursor^.next); end;
  ord('x'): begin SetPercent(67, cursor^.p^.Ctax); RecalcBC(cursor^.next); end;
  ord('r'): begin BCFile; end;
    end;
  until chh=27;

  {free memory}
  {DisposeBC;}

  helpscr:=0;
  DrawRightScreen;
  MoveMouseTo(mx,my);
  MouseDisabled:=False;
  MouseOn;
  ResetMouse;
  if lock<>0 then begin force:=lock; ForceKey:=13 end;
  {ch:=2;}    { redraw map }
  DrawMap(true);
end;


{*****************************************************************************}
{** item notes ** }

procedure ClearNote( n: NotePtr );
var i: int;
begin
  if (n=nil) then Exit;
  for i:=1 to NoteLines do n^.text[i]:='';
  n^.lines:=NoteLines;
end;

procedure CopyNote( n1:Note; var n2: Note );
var i: int;
begin
  for i:=1 to NoteLines do
    n2.text[i]:=n1.text[i];
  n2.lines:=n1.lines;
  n2.item:=n1.item;
end;

function CreateNote(item:int): NotePtr;
var
  note         : NotePtr;
begin
  New( note );
  ClearNote( note );
  note^.next := nil;
  note^.item := item;
  CreateNote:=note;
end;

function GetItemNotesRoot: ItemNotesPtr;
begin
  if (itemNotesRoot = nil) then begin
    New( itemNotesRoot );
    itemNotesRoot^.turn := turn;
    itemNotesRoot^.root := nil;
    itemNotesRoot^.next := nil;
    itemNotesRoot^.prev := nil;
    NoteDataChg := Yes;
  end;
  GetItemNotesRoot := itemNotesRoot;
end;

procedure DisposeNotes;
var
  note,tmpNote            : NotePtr;
  itemNotes,tmpItemNotes  : ItemNotesPtr;
begin
  itemNotes := GetItemNotesRoot;
  while (itemNotes<>nil) do begin
    note := itemNotes^.root;
    while (note<>nil) do begin
      tmpNote:=note^.next;
      Dispose(note);
      note:=tmpNote;
    end;
    tmpItemNotes:=itemNotes^.next;
    Dispose(itemNotes);
    itemNotes:=tmpItemNotes;
  end;
end;

function GetItemNotes(turn:int): ItemNotesPtr;
var
  itemNotes,tmp    : ItemNotesPtr;
begin
  itemNotes := GetItemNotesRoot;
  while ( (itemNotes^.next <> nil) and (itemNotes^.next^.turn <= turn) ) do
    itemNotes := itemNotes^.next;
  if (itemNotes^.turn <> turn) then begin
    tmp := itemNotes;
    New( itemNotes );
    itemNotes^.turn := turn;
    itemNotes^.root := nil;
    if (tmp^.turn<turn) then begin
      itemNotes^.next := tmp^.next;
      itemNotes^.prev := tmp;
      tmp^.next := itemNotes;
    end else begin
      itemNotes^.prev := tmp^.prev;
      itemNotes^.next := tmp;
      tmp^.prev := itemNotes;
    end;
  end;
  GetItemNotes := itemNotes;
end;

function GetNote( item:int; turn:int ): NotePtr;
var
  itemNotes    : ItemNotesPtr;
  note         : NotePtr;
begin
  itemNotes := GetItemNotes(turn);
  note := nil;
  while ( (itemNotes <> nil) and (note = nil) ) do begin
    note := itemNotes^.root;
    while ( (note <> nil) and (note^.item<>item) ) do 
      note := note^.next;
    itemNotes := itemNotes^.prev;
  end;
  GetNote := note;
end;

procedure SetNote( note: NotePtr; turn: int );
var
  itemNotes    : ItemNotesPtr;
  tmp          : NotePtr;
begin
  itemNotes := GetItemNotes(turn);
  tmp := itemNotes^.root;
  if (tmp = nil) then begin
    itemNotes^.root := note;
  end else if (tmp^.item = note^.item) then begin
    itemNotes^.root := note;
    note^.next := tmp^.next;
  end else begin
    while ( (tmp^.next<>nil) and (tmp^.next^.item<>note^.item) ) do
      tmp := tmp^.next;
    if (tmp^.next<>nil) then begin
      note^.next := tmp^.next^.next;
      Dispose(tmp^.next);
    end;
    tmp^.next:=note;
  end;
  NoteDataChg := Yes;
end;

procedure SaveNotes;
var
  g          : file;
  note       : NotePtr;
  itemNotes  : ItemNotesPtr;
  c          : int;
begin
  itemNotes := GetItemNotesRoot;
  if (itemNotes=nil) then Exit;  
  OpenW(g,'VPANOT'+plstr+'.DAT',Yes);

  while (itemNotes<>nil) do begin

    {count}
    c:=0;
    note:=itemNotes^.root;
    while (note<>nil) do begin
      c:=c+1;
      note:=note^.next;
    end;

    if (c>0) then begin
      {save}
      BlockWrite( g, itemNotes^, sizeof(itemNotes^) );
      BlockWrite( g, c, sizeof(c) );
      note:=itemNotes^.root;
      while (note<>nil) do begin
        BlockWrite( g, note^, sizeof(note^) );
        note:=note^.next;
      end;
    end;

    itemNotes:=itemNotes^.next;
  end;

  NoteDataChg := No;
  CloseData(g);
end;

procedure LoadNotes;
var
  g                        : file;
  note,lastNote            : NotePtr;
  itemNotes,lastItemNotes  : ItemNotesPtr;
  c,i                      : int;
begin
  lastItemNotes := nil;
  if OpenData(g,'VPANOT'+plstr+'.DAT',No) then begin
    DisposeNotes;
    while not eof(g) do begin
      New(itemNotes);
      BlockRead( g, itemNotes^, sizeof(itemNotes^) );
      itemNotes^.prev := nil;
      itemNotes^.next := nil;
      BlockRead( g, c, sizeof(c) );
      lastNote:=nil;
      for i:=1 to c do begin
        New(note);
        BlockRead( g, note^, sizeof(note^) );
        note^.next:=nil;
        if (lastNote=nil) then
          itemNotes^.root := note
        else
          lastNote^.next := note;
        lastNote := note;
      end;
      if (lastItemNotes=nil) then
        itemNotesRoot := itemNotes
      else begin
        lastItemNotes^.next := itemNotes;
        itemNotes^.prev     := lastItemNotes;
      end;
      lastItemNotes := itemNotes;
    end;

    NoteDataChg := No;
    CloseData(g);
  end;
end;


function HasNote(item:int): boolean;
var
  i,j        : int;
  note       : NotePtr;
begin
  HasNote := false;
  note := GetNote( item, turn );
  if (note<>nil) and (note^.lines>0) then begin
    for i:=1 to note^.lines do begin
      for j:=1 to Length(note^.text[i]) do begin
        if (note^.text[i,j]<>#32) then begin
          HasNote := true;
          Exit;
        end;
      end;
    end;
  end;
end;

procedure DrawNoteIcon(x,y:int; c:byte);
begin
  SetLineStyle(SolidLn,0,NormWidth);
  SetWriteMode(NormalPut);
  SetColor(c);
  Line(x,y,x+6,y);
  Line(x,y,x,y+7);
  Line(x+6,y+7,x,y+7);
  Line(x+6,y+7,x+6,y);
  Line(x+2,y+2,x+4,y+2);
  Line(x+2,y+4,x+4,y+4);
end;

procedure DrawNoteScreen;
begin
  Clear(MX0,NoteY*NoteLineHeight-6,639,479);
  DrawCredits;
  SetColor(DarkGray);
  SetLineStyle(SolidLn,0,NormWidth);
  Rectangle(NoteX*8-4,NoteY*NoteLineHeight-4,(NoteX+NoteCols)*8+3,(NoteY+NoteLines)*NoteLineHeight+3);
end;

procedure ClearKeyArea;
begin
  Clear(NoteX*8,NoteKeyY,(NoteX+NoteCols)*8-1,NoteKeyY+8+7);
end;

procedure ClearNoteArea;
begin
  Clear(NoteX*8,NoteY*NoteLineHeight,(NoteX+NoteCols)*8-1,(NoteY+NoteLines)*NoteLineHeight-1);
  ClearKeyArea;
end;

procedure WriteLine (y:byte; s:str40);
var
  sx,sy   : word;
begin
  sx := NoteX*8;
  sy := (NoteY+y-1)*NoteLineHeight;
  setFillStyle(SolidFill,black);
  bar(sx, sy, sx+(NoteCols*8)-1, sy+NoteLineHeight-1);
  SetColor(LightGray);
  OutTextXY( sx, sy, s );
end;

function AskYN (ykey,nkey:char) : boolean;
var ynkey : word;
begin
  repeat ynkey:=ReadKey until ynkey in [13,27,byte(ykey),byte(nkey)];
  AskYN:=(ynkey in [13,byte(ykey)]);
end;

function EditNote (note:NotePtr) : boolean;
var   i   : int;
      x,y,x1,y1 : byte;
      cur : boolean;
      t0  : long;
      ch  : word;
      c   : char;
      msize : int;
  procedure DrawCursor;
  begin
    SetWriteMode(XORPut);
    SetColor(cMsg);
    SetLineStyle(SolidLn,0,NormWidth);
    Rectangle((NoteX+x-1)*8,(NoteY+y)*NoteLineHeight-2,(NoteX+x-1)*8+7,(NoteY+y)*NoteLineHeight-1);
    SetWriteMode(NormalPut);
    cur:=not cur;
  end;
  procedure WrLine(y:byte);
  begin
    WriteLine(y,note^.text[y]);
  end;
  procedure CutLine;
  var i : byte;
  begin
    if y<NoteLines then
    with note^ do
    begin
      for i:=NoteLines downto y+2 do
        begin text[i]:=text[i-1]; WrLine(i) end;
      text[y+1]:=Copy(text[y],x,NoteCols);
      LTrim(text[y+1]);
      RPad(text[y+1],NoteCols);
      text[y,0]:=chr(x-1);
      RPad(text[y],NoteCols);
      WrLine(y);
      inc(y); x:=1;
    end;
  end;
  procedure DeleteLine;
  var i : byte;
  begin
    with note^ do
    begin
      for i:=y to NoteLines do text[i]:=text[i+1];
      text[NoteLines,0]:=#0;
      RPad(text[NoteLines],NoteCols);
    end;
    for i:=y to NoteLines do WrLine(i);
  end;
begin
  if (note=nil) then begin EditNote:=false; Exit; end;
  {ClearNoteArea;}
  DrawNoteScreen;
  SetColor(cMsg);
  OutTextXY(NoteX*8,NoteKeyY,'Edit the note.');
  OutTextXY(NoteX*8,NoteKeyY+8,'Esc when done.');
  SetColor(White);
  OutTextXY(NoteX*8,NoteKeyY+8,'Esc');
  with note^ do
  begin
    for i:=1 to NoteLines do
    begin
      if i>lines then text[i,0]:=#0;
      RPad(text[i],NoteCols);
      WrLine(i);
    end;
    x:=1; y:=IIF(Pos('<<<',text[1])=0,1,2);
    cur:=Off; t0:=Timer;
    repeat
      msize:=-2;  { last CR/LF may be omitted }
      if WPMess then
      begin
        i:=NoteLines;
        while (i>0) and (RLen(text[i])=0) do dec(i);
        while i>0 do
        begin
          inc(msize,RLen(text[i])+2);
          dec(i);
        end;
      end;
      while not KeyPressed do
        if Timer>t0+1 then begin DrawCursor; t0:=Timer end;
      if cur then DrawCursor;
      ch:=ReadKey;
      case ch of
{Left}    $4B00 : if x>1 then dec(x);
{Right}   $4D00 : if x<NoteCols+1 then inc(x);
{Up}    $4800 : if y>1 then dec(y);
{Down}    $5000 : if y<NoteLines then inc(y);
{Home}    $4700 : x:=1;
{End}   $4F00 : x:=RLen(text[y])+1;
{PgUp}    $4900 : y:=1;
{PgDn}    $5100 : y:=NoteLines;
{Del}   $5300 : begin
                  y1:=RLen(text[y]);
                  if x<=y1 then
                    begin Delete(text[y],x,1); text[y]:=text[y]+' ' end
                  else if y<NoteLines then
                  begin
                    x1:=NoteCols-y1-1+1;
                    while (x1>0) and (text[y+1,x1]<>' ') do dec(x1);
                    text[y]:=Copy(text[y],1,y1)+' '+Copy(text[y+1],1,x1);
                    RPad(text[y],NoteCols);
                    Delete(text[y+1],1,x1);
                    RPad(text[y+1],NoteCols);
                    if RLen(text[y+1])=0 then
                      begin inc(y); DeleteLine; dec(y) end
                    else WrLine(y+1);
                  end;
                end;
{BkSp}    8 : if x>1 then
                begin
                  Delete(text[y],x-1,1); text[y]:=text[y]+' ';
                  dec(x);
                end;
{chars}   32..254: {if msize<WPMax then}  { WinPlan... }
                 begin
                   x1:=x; y1:=y;
                   if (x=NoteCols+1) or (text[y,NoteCols]<>' ') then
                   begin
                     x:=NoteCols;
                     if (x1=NoteCols+1) and (ch=32) then ch:=0
                     else while (x>0) and (text[y,x]<>' ') do dec(x);
                     if x<x1 then
                     begin
                       x1:=x1-x;
                       if y1<NoteLines then inc(y1);
                     end;
                     inc(x);
                     if x=1 then begin x:=NoteCols+1; x1:=1 end;
                     CutLine;
                     x:=x1;
                     if y<>y1 then begin WrLine(y); y:=y1 end;
                   end;
                   if ch<>0 then
                   begin
                     Insert(chr(ch),text[y],x);
                     inc(x);
                   end;
                 end;
{Enter}   13  : CutLine;
{^Y}    25  : DeleteLine;
      end;
      WrLine(y);
    until (ch=27) or (ch=$3C00) or (ch=$4400);
    for i:=1 to NoteLines do RTrim(text[i]);
    i:=NoteLines;
    while (i>0) and (text[i,0]=#0) do dec(i);
    lines:=i;
  end;
  if ConfirmNotes then begin
    ClearKeyArea;
    SetColor(cMsg);
    OutTextXY(NoteX*8,NoteKeyY,'Save? Y/N');
    SetColor(Yellow);
    OutTextXY((NoteX+6)*8,NoteKeyY,'Y N');
    EditNote:=AskYN('y','n');
  end else
    EditNote:=true;
end;


procedure NoteHeaderPlanet(item:int);
var
  number  : word;
  p       : pptr;
  ep      : EPln;
  newpln  : byte;
  s       : string[18];
  i,t0    : int;
begin
  number:=item and LockLo;
  if (number=0) or (number>500) then Exit;
  Clear(MX0,72,639,NoteY*NoteLineHeight-7);
  SetColor(White);
  OutTextXY(MX0,72,'Planet '+NStr(number));
  OutTextXY(MX0,80,PlanName[number]);
  with TTurn^.data^ do
  begin
    p:=planet[number];
    ep:=eplan[number];
    newpln:=newplan[number];
  end;
  SetColor(LightGray);
  if (p=nil) and (ep.activity=0) then OutTextXY(MX0,104,'(No data)') else
  if p=nil then begin
    if ep.when=turn then s:='now'
                    else s:=NStr(turn-ep.when)+Proper(turn-ep.when,' turn')+' ago';
    OutTextXY(MX0,88,'('+s+')');
    SetColor(IIF(ep.when=turn,cPInfo,cOPInfo));
    if ep.owner<>0 then OutTextXY(MX0,104,'Race: '+RaceName[ep.owner]);
  end else with p^ do begin
    i:=Max(when,ep.when);
    t0:=when0;
    if (ep.when<>0) and (ep.when<when0) then t0:=ep.when;
    if i=turn then s:='now' else s:=NStr(turn-i);
    s:='('+s;
    if t0<>i then s:=s+' - '+NStr(turn-t0)+' trn ago'
    else if t0<>turn then s:=s+Proper(turn-t0,' turn')+' ago';
    s:=s+')';
    OutTextXY(MX0,88,s);
    if owner<>-1 then begin
      SetColor(IIF(newpln and NP_Owner=0,cOPInfo,cPInfo));
      OutTextXY(MX0,104,'Race: '+RaceName[IIF(ep.owner<>0,ep.owner,owner)]);
    end;
  end;
  {indicate note on this object}
  if HasNote(item) then
    DrawNoteIcon( 615, 72, IIF( GetActList(lock), NoteIconColorInactive, NoteIconColor ));
end;

procedure NoteHeaderShip(item:int);
var
  number  : word;
  h       : sptr;
  b       : bptr;
begin
  number:=item and LockLo;
  if (number=0) or (number>999) then Exit;
  Clear(MX0,72,639,NoteY*NoteLineHeight-7);
  h:=TTurn^.data^.ship[number];
  if (h=nil) or (h^.when<>turn) then Exit;
  if PlanN<>0 then b:=TTurn^.data^.base[PlanN] else b:=nil;
  with h^ do
  begin
    SetColor(White);
    OutTextXY(MX0,72,'Ship: '+NStr(number));
    OutTextXY(MX0,80,'Race: '+RaceName[owner]);
    SetColor(cSInfo);
    {OutTextXY(MX0,112,'at '+Location(x,y));}
    if name[1]<>#$FF then
    begin
      SetColor(LightGray);
      OutTextXY(MX0,96,name);
    end;
    SetColor(White);
    if hull<>-1 then OutTextXY(MX0,88,Hulls[hull].name);
  end;
  {indicate note on this object}
  if HasNote(item) then
    DrawNoteIcon( 615, 72, IIF( GetActList(lock), NoteIconColorInactive, NoteIconColor ));
end;

procedure DrawNote(note:NotePtr);
var
  i,ltype    : int;
  x,y        : int;
  sx,sy      : int;
begin
  DrawNoteScreen;
  SetColor(cMsg);
  for i:=1 to NoteLines do
  begin
    if i>note^.lines then note^.text[i,0]:=#0;
    RPad(note^.text[i],NoteCols);
    WriteLine(i,note^.text[i]);
  end;

  {draw header based on standard info screen}  
  if note^.item>0 then
  begin
    ltype:=note^.item and LockHi;
    case ltype of
      LockP: NoteHeaderPlanet(note^.item);
      LockS: NoteHeaderShip(note^.item);
    end;
    GetObjectCoord(note^.item, x, y);
    CenterMap(x,y,No);
    Abs2Scr(x,y,sx,sy);
    MoveMouseTo(sx,sy);
    WriteCoord;
  end;
end;

procedure ShowNote(item:int);
var
  x,y,i      : int;
  tmpNote    : NotePtr;
  note       : NotePtr;
  isTmp      : boolean;
  reload     : boolean;
  clear      : boolean;
begin

  isTmp  := false;
  reload := true;

  repeat
    if (reload) then begin
      if (isTmp) then Dispose(note);
      isTmp := false;
      note := GetNote( item, turn );
      if (note=nil) then begin
        note := CreateNote(item);
        isTmp := true;
      end;
      reload:=false;
    end;

    DrawNote(note);

    {menu}
    ClearKeyArea;
    if (turn=today) then begin
      SetColor(cMsg);
      OutTextXY(NoteX*8,NoteKeyY,'Edit');
      OutTextXY(NoteX*8,NoteKeyY+8,'Clear');
      SetColor(White);
      OutTextXY(NoteX*8,NoteKeyY,'E');
      OutTextXY(NoteX*8,NoteKeyY+8,'C');
    end;

    ch:=ReadKey;
    case ch of
{-}   ord('-'): begin TimeShift(-1); reload:=true; end;
{+}   ord('+'): begin TimeShift(1); reload:=true; end;
{e}   ord('e'): if (turn=today) then begin
                  tmpNote:=CreateNote(note^.item);
                  CopyNote(note^, tmpNote^);
                  if EditNote( tmpNote ) then begin
                    SetNote( tmpNote, turn);
                    if (isTmp) then Dispose(note);
                    note := tmpNote;
                    isTmp := false;
                  end else
                    Dispose(tmpNote);
                  ch:=27;
                end;
{c}   ord('c'): if (turn=today) then begin
                  if ConfirmNotes then begin
                    ClearKeyArea;
                    SetColor(cMsg);
                    OutTextXY(NoteX*8,NoteKeyY,'Clear note? Y/N');
                    SetColor(Yellow);
                    OutTextXY((NoteX+12)*8,NoteKeyY,'Y N');
                    clear:=AskYN('y','n');
                  end else
                    clear:=true;
                  if clear then begin
                    if (isTmp) then ClearNote(note)
                    else begin
                      note:=CreateNote(note^.item);
                      SetNote( note, turn);
                    end;
                  end;
                  ch:=27;
                end;
    end;
  until (ch=13) or (ch=27);
  ClearArea;
  {if (ch=13) then }force:=note^.item;
  ForceKey:=13;
  if (isTmp) then Dispose( note );
end;


{*****************************************************************************}
{** ion storm navigation ** }

procedure IonStormWayPoint;
var
  ion     : iptr;
  i,j     : int;
  mx,my   : int;
  sx,sy   : int;
  px,py   : int;
  d       : long;
  dstr    : int;
  PrTurn  : tptr;

  function InStorm(ion: iptr; sx,sy: int): boolean;
  var
    r      : long;
    h      : double;
    ix,iy   : int;
  begin
    with ion^ do begin
      r  := radius;
      ix := x + Round(sin(heading*Pi/180.0)*long(warp*warp));
      iy := y + Round(cos(heading*Pi/180.0)*long(warp*warp));
      if (Distance2(ix, iy, sx, sy) <= (r*r)) then
        InStorm:=true
      else
        InStorm:=false;
    end;
  end;

  procedure CompensateDrag(var mx, my: int; heading, dist: int);
  begin
    dec( mx, Round(sin(heading*Pi/180.0)*dist) );
    dec( my, Round(cos(heading*Pi/180.0)*dist) );
  end;

  procedure Drag(var mx, my: int; heading, dist: int);
  begin
    inc( mx, Round(sin(heading*Pi/180.0)*dist) );
    inc( my, Round(cos(heading*Pi/180.0)*dist) );
  end;

  procedure HandleStorm(var mx, my: int; ion: iptr);
  const
    MaxChange = 20;
    Change1   = 15;
    Change2   = 10;
    Change3   = 5;
  var
    d       : long;
    x,y     : int;
    x0,y0   : int;
    x1,y1   : int;
    px,py   : int;
    i       : int;
    color   : int;
  begin
    {storms drag for 75% of own movement}
    d:=Round( long(ion^.warp*ion^.warp) * 0.75 );

    {assume unchanged heading for default location}
    CompensateDrag(mx, my, ion^.heading, d);
    Abs2Scr(mx,my,px,py);
    MoveMouseTo(px,py);
    WriteCoord;
    LockDistTarget(mx,my);

    {show possible locations after drag}
    SetLineStyle(SolidLn,0,NormWidth);
    x0:=-1; y0:=-1;
    for i:= -MaxChange to MaxChange do begin
      if Abs(i)>Change1 then color:=DarkGray
      else if Abs(i)>Change2 then color:=Green
      else if Abs(i)>Change3 then color:=LightGreen
      else color:=White;
      SetColor(color);
      x:=mx; y:=my;
      Drag(x, y, ion^.heading+i, d);
      Abs2Scr(x,y,x1,y1);
      {draw connection between possible locations}
      {if (x0>0) and (y0>0) then
        Line(x0,y0,x1,y1);}
      PutPixel(x1,y1,color);
      x0:=x1; y0:=y1;
    end;
  end;

begin
  {if (turn<>today) or (distlock=0) then Exit;}
  if (distlock=0) then Exit;

  MouseMove;

  Scr2Abs(MouseX,MouseY,mx,my);
  sx := dlx; sy := dly;
  Clear(0,0,100,40);

  with TTurn^.data^ do
  begin
    for i:=1 to 50 do
      if (ion[i]<>nil) then begin
        {TODO: when exactly do ion storms increase/decrease in strength?}
        {
        dstr:=0;
        PrTurn := TSearch(TTurn^.turn-1);
        if (PrTurn^.turn=TTurn^.turn-1) then begin
          if (PrTurn^.data=nil) then LoadTurnData(PrTurn);
          if ( (PrTurn^.data<>nil) and (PrTurn^.data^.ion[i]<>nil) ) then begin
            dstr:=ion[i]^.voltage-PrTurn^.data^.ion[i]^.voltage;
          end;
        end;
        if ((ion[i]^.voltage>=150) or (ion[i]^.voltage+dstr>=150))}
        if ((ion[i]^.voltage>=150) or ((ion[i]^.voltage+dstr>=143) and ion[i]^.grow))
          and InStorm(ion[i], sx, sy)
        then begin
          HandleStorm(mx, my, ion[i]);
        end;
      end;
  end;
end;

{*****************************************************************************}
{** score value of ships ** }

{Calculate costs of a ship, cloning not considered. Costs will be *added* to t,d,m, and c.}
procedure CalcShipCosts(hull,engine,nBeam,beam,nTorp,torp: int;  var t,d,m,c: long);
var
  e       : int;
begin
  {hull}
  inc( t, Hulls[hull].T );
  inc( d, Hulls[hull].D );
  inc( m, Hulls[hull].M );
  inc( c, Hulls[hull].cost );
  {engines}
  e:=Hulls[hull].engines;
  inc( t, e*Engines[engine].T );
  inc( d, e*Engines[engine].D );
  inc( m, e*Engines[engine].M );
  inc( c, e*Engines[engine].cost );
  {beams}
  inc( t, nBeam*Beams[beam].T );
  inc( d, nBeam*Beams[beam].D );
  inc( m, nBeam*Beams[beam].M );
  inc( c, nBeam*Beams[beam].cost );
  {torps}
  inc( t, nTorp*Torps[torp].T );
  inc( d, nTorp*Torps[torp].D );
  inc( m, nTorp*Torps[torp].M );
  inc( c, nTorp*Torps[torp].tcost );
end;

function GetScoringMethod: ScoringMethodKey;
var s: str20;
begin
  s:=ScoringMethod;
  Upper(s);
  GetScoringMethod:=ScoringMethodKey(ItemPos(s,ScoringMethodNames));
end;

function GetShipScoreEmpty(hull,engine,nBeam,beam,nTorp,torp: int): long;
var
  t,d,m,c   : long;
  s         : string;
begin
  GetShipScoreEmpty:=0;
  case (GetScoringMethod) of
    smAutoScore : begin
                    {Score for warships only.}
                    if (Hulls[hull].bays>0) or (Hulls[hull].launchers>0) or
                       (Hulls[hull].weapons>0) then
                    begin
                      t:=0; d:=0; m:=0; c:=0;
                      CalcShipCosts(hull,engine,nBeam,beam,nTorp,torp, t,d,m,c);
                      GetShipScoreEmpty:= (t+d+m)*5 + c;
                    end;
                  end;
    smPTScore   : begin
                    t:=0; d:=0; m:=0; c:=0;
                    CalcShipCosts(hull,engine,nBeam,beam,nTorp,torp, t,d,m,c);
                    GetShipScoreEmpty:= (t+d+m)*3 + c;
                  end;
  end;
end;

function GetShipScoreCargo(hull,torp: int): long;
var
  score   : long;
begin
  score := 0;
  case (GetScoringMethod) of
    smAutoScore : begin
                    {cargo may be either fighters or torpedos}
                    if (Hulls[hull].bays>0) then begin
                      score := Hulls[hull].cargo;
                      score := score * 125;
                    end else
                    if (Hulls[hull].launchers>0) then begin
                      score := Hulls[hull].cargo;
                      score := score * (15+Torps[torp].cost);
                    end;
                  end;
    smPTScore   : begin
                    {cargo may be either fighters or torpedos}
                    if (Hulls[hull].bays>0) then begin
                      score := Hulls[hull].cargo;
                      score := score * 20;
                    end else
                    if (Hulls[hull].launchers>0) then begin
                      score := Hulls[hull].cargo;
                      score := score * (9+Torps[torp].cost);
                    end;
                  end;
  end;
  GetShipScoreCargo := score;
end;

function GetShipScoreTotal(hull,engine,nBeam,beam,nTorp,torp: int): long;
begin
  GetShipScoreTotal := 0;
  case (GetScoringMethod) of
    smAutoScore : begin
                    {Score for warships only.}
                    if (Hulls[hull].bays>0) or (Hulls[hull].launchers>0) or
                    (Hulls[hull].weapons>0) then
                    begin
                      GetShipScoreTotal:=GetShipScoreEmpty(hull,engine,nBeam,beam,nTorp,torp) +
                                         GetShipScoreCargo(hull,torp);
                    end;
                  end;
    smPTScore   : begin
                    GetShipScoreTotal:=GetShipScoreEmpty(hull,engine,nBeam,beam,nTorp,torp) +
                                       GetShipScoreCargo(hull,torp);
                  end;
  end;
end;

function GetShipScoreCurrent(ship: sptr): long;
var
  score,tmp   : long;
begin
  score:=0;
  case (GetScoringMethod) of
    smAutoScore : begin
                    with ship^ do begin
                      score := GetShipScoreEmpty(hull,El,weapons,Wl,launchers,Tl);
                      tmp := TFnum;
                      if (Hulls[hull].bays>0) then begin
                        score := score + tmp * 125;
                      end else
                      if (Hulls[hull].launchers>0) then begin
                        score := score + tmp * (15+Torps[Tl].cost);
                      end;
                    end;
                  end;
    smPTScore   : begin
                    with ship^ do begin
                      score := GetShipScoreEmpty(hull,El,weapons,Wl,launchers,Tl);
                      tmp := TFnum;
                      if (Hulls[hull].bays>0) then begin
                        score := score + tmp * 20;
                      end else
                      if (Hulls[hull].launchers>0) then begin
                        score := score + tmp * (9+Torps[Tl].cost);
                      end;
                    end;
                  end;
  end;
  GetShipScoreCurrent := score;
end;

{*****************************************************************************}
{** fleet report ** }

procedure InitFleetReport;
var
  i,j     : int;
begin
  new(fleetReport);
  j:=0;
  with TTurn^.data^ do
    for i:=1 to 999 do begin
      if (ship[i] <> nil) and (ship[i]^.owner=player) then begin
        inc(j);
        fleetReport^[j]:=i;
      end;
    end;
  for i:=j+1 to 999 do
    fleetReport^[i]:=-1;
end;

procedure SortFleet;
var
  done    : boolean;
  i,j     : int;
begin
  {bubble-sort by beams}
  repeat
    done := true;
    for i:=1 to 998 do
      if (fleetReport^[i]>0) and (fleetReport^[i+1]>0) then
        with TTurn^.data^ do
          if (ship[fleetReport^[i]]<>nil) and (ship[fleetReport^[i+1]]<>nil) then
            if (ship[fleetReport^[i]]^.Wl > ship[fleetReport^[i+1]]^.Wl) then begin
              j:=fleetReport^[i];
              fleetReport^[i]:=fleetReport^[i+1] ;
              fleetReport^[i+1]:=j;
              done:=false;
            end;
  until done;
  {bubble-sort by torps}
  repeat
    done := true;
    for i:=1 to 998 do
      if (fleetReport^[i]>0) and (fleetReport^[i+1]>0) then
        with TTurn^.data^ do
          if (ship[fleetReport^[i]]<>nil) and (ship[fleetReport^[i+1]]<>nil) then
            if (ship[fleetReport^[i]]^.Tl > ship[fleetReport^[i+1]]^.Tl) then begin
              j:=fleetReport^[i];
              fleetReport^[i]:=fleetReport^[i+1] ;
              fleetReport^[i+1]:=j;
              done:=false;
            end;
  until done;
  {bubble-sort by engine}
  repeat
    done := true;
    for i:=1 to 998 do
      if (fleetReport^[i]>0) and (fleetReport^[i+1]>0) then
        with TTurn^.data^ do
          if (ship[fleetReport^[i]]<>nil) and (ship[fleetReport^[i+1]]<>nil) then
            if (ship[fleetReport^[i]]^.El > ship[fleetReport^[i+1]]^.El) then begin
              j:=fleetReport^[i];
              fleetReport^[i]:=fleetReport^[i+1] ;
              fleetReport^[i+1]:=j;
              done:=false;
            end;
  until done;
  {bubble-sort by hull}
  repeat
    done := true;
    for i:=1 to 998 do
      if (fleetReport^[i]>0) and (fleetReport^[i+1]>0) then
        with TTurn^.data^ do
          if (ship[fleetReport^[i]]<>nil) and (ship[fleetReport^[i+1]]<>nil) then
            if (ship[fleetReport^[i]]^.hull > ship[fleetReport^[i+1]]^.hull) then begin
              j:=fleetReport^[i];
              fleetReport^[i]:=fleetReport^[i+1] ;
              fleetReport^[i+1]:=j;
              done:=false;
            end;
  until done;
end;

procedure DrawPic(lr:LRType; x,y: int);
begin
  { img[lr]^ esta en formato ptcgraph: ancho=longint en offset 0 (word [1]),
    alto=longint en offset 4 (word [3]). El word [2] es el word alto del ancho (=0). }
  if useSVGA then begin
    convertImage(img[lr]^,img256);
    PutImage(x + (104-img[lr]^[1]) div 2, y + (104-img[lr]^[3]) div 2, img256, NormalPut);
  end else
    PutImage(x + (104-img[lr]^[1]) div 2, y + (104-img[lr]^[3]) div 2, img[lr]^, NormalPut);
end;

procedure ShowFleetReport;
const
  vpx1      = 0;
  vpy1      = 32;
  vpx2      = 639;
  vpy2      = 479;
  sheight   = 18;
var
  i,j       : int;
  chh       : word;
  mx,my     : int;
  cursor    : int;
  offset    : int;
  vp        : ViewPortType;
  shpscr    : int;

  procedure DrawFirst;
  begin
    ClearDevice;
    SetLineStyle(SolidLn,0,NormWidth);
    SetColor(White);
    OutTextXY(320-6*8,0,'FLEET REPORT');
    Line(320-6*8,9,320-6*8+12*8,9);
  end;

  procedure DrawShipXY(dx,dy,idx: int);
  var
    ship    : sptr;
    s       : string;
    s1,s2   : str20;
  begin
    if (idx<1) or (idx>999) or (fleetReport^[idx]<0) then Exit;
    ship := TTurn^.data^.ship[ fleetReport^[idx] ];
    if (ship=nil) then Exit;
    with ship^ do begin
      SetColor(White);
      SetLineStyle(DottedLn,0,NormWidth);
      Line( dx, dy, vpx2-vpx1, dy );
      Line( dx, dy+sheight, vpx2-vpx1, dy+sheight );
      SetColor(White);
      s1:=Nstr0(idx); LPad(s1,3);
      s2:=NStr0(fleetReport^[idx]); LPad(s2,3);
      OutTextXY(dx+2, dy+2, s1+' '+s2+' '+name);
      SetColor(white);
      if hull<>-1 then begin
        OutTextXY(dx+224, dy+2, Hulls[hull].name);
        OutTextXY(dx+432, dy+2, 'Score: '+NStr0(GetShipScoreCurrent(ship))); 
        s:='';
        if (bays>0) then s:=s + NStr(bays)+Proper(bays,' Fighter bay');
        if (launchers>0) then begin
          if (length(s)>0) then s:=s+', ';
          s:=s + NStr(launchers)+Proper(launchers,' '+Torps[Tl].name+' tube');
        end;
        if (weapons>0) then begin
          if (length(s)>0) then s:=s+', ';
          s:=s + NStr(weapons)+Proper(weapons,' '+Beams[Wl].name);
        end;
        OutTextXY(dx+240, dy+10, s);
      end;
    end;
  end;

  procedure DrawFleet;
  const
    picHeight   = 104;
  var
    i,j,k       : int;
    ship        : sptr;
    lastHull    : int;
    hullCount   : int;
    hullStart   : int;
    space,tmp   : int;
    score       : long;
    fixed       : boolean;
  begin
    GetViewSettings(vp);

    {picture does not respect viewport}
    SetViewPort(0,0,639,479,ClipOff);
    Clear(1,1,104,104);

    SetViewPort(vpx1,vpy1,vpx2,vpy2,ClipOn);
    Clear(0,0,vpx2-vpx1,vpy2-vpy1);

    space    := 0;
    tmp      := 0;
    lastHull :=-1;
    hullStart:=-1;
    hullCount:= 0;
    i:=1+offset;
    k:=0;
    fixed:=false;
    while ( (i<=999) and (fleetReport^[i]>0) and (sheight*(i-offset)+space<vpy2-vpy1) ) do begin

      ship := TTurn^.data^.ship[ fleetReport^[i] ];
      if (ship^.hull<>lastHull) then begin
        if (tmp>0) then inc(space,tmp);
        lastHull:=ship^.hull;

        if (hullStart>0) then hullStart:=i
        else begin
          j:=i;
          while (j>1) and (TTurn^.data^.ship[fleetReport^[j-1]]^.hull=ship^.hull) do
            dec(j);
          hullStart:=j;
        end;
        if (k=3) then exit;
        if (k =2) then begin
          LoadPic(Right,Hulls[ship^.hull].pic,No,No,yes,Yes);
          DrawPic(Right,0,sheight*(hullStart-offset-1)+space);
          inc(k);
        end;
        if (k =1) then begin
          LoadPic(Right,Hulls[ship^.hull].pic,No,No,yes,Yes);
          DrawPic(Right,0,sheight*(hullStart-offset-1)+space);
          SetPal;
          inc(k);
        end;
        if (k =0) then begin
        if (sheight*(hullStart-offset-1)+space>=-36) then begin
          LoadPic(Left,Hulls[ship^.hull].pic,No,No,yes,yes);
          DrawPic(Left,0,sheight*(hullStart-offset-1)+space);
          SetPal;
          inc(k);
        end
        else
        begin
           tmp := 0;
           j:=hullStart+1;
           while (j<=999) and (fleetReport^[j]>0)
           and (TTurn^.data^.ship[fleetReport^[j]]^.hull=ship^.hull) do begin
             inc(tmp);
             inc(j);
           end;
           if (i+4<hullStart+tmp) then begin
             LoadPic(Left,Hulls[ship^.hull].pic,No,No,yes,yes);
             DrawPic(Left,0,-36);
             SetPal;
             inc(k);
             fixed:=true;
           end;
        end;
        end;
        {count number of ships with current hull and collect some data}
        j:=hullStart;
        score:=0;
        while (j<=999) and (fleetReport^[j]>0)
        and (TTurn^.data^.ship[fleetReport^[j]]^.hull=ship^.hull) do begin
          score := score + GetShipScoreCurrent(TTurn^.data^.ship[fleetReport^[j]]);
          inc(j);
        end;
        hullCount := j-hullStart;
        SetColor(Yellow);
        if (fixed) then begin
          OutTextXY(8, picHeight+4-36, 'Count: '+NStr0(hullCount));
          OutTextXY(8, picHeight+16-36, ScoringMethodLongLabels[GetScoringMethod]+': ');
          OutTextXY(8, picHeight+24-36, ' '+NStr0(score));
          fixed:=false;
        end else begin
          OutTextXY(8, sheight*(hullStart-offset-1)+space+picHeight+4, 'Count: '+NStr0(hullCount));
          OutTextXY(8, sheight*(hullStart-offset-1)+space+picHeight+16, ScoringMethodLongLabels[GetScoringMethod]+': ');
          OutTextXY(8, sheight*(hullStart-offset-1)+space+picHeight+24, ' '+NStr0(score));
        end;
        {make room for the picture if there are too few ships of this kind}
        tmp := picHeight + 16 + 20 - sheight;
        j:=hullStart+1;
        while (tmp>0) and (j<=999) and (fleetReport^[j]>0)
        and (TTurn^.data^.ship[fleetReport^[j]]^.hull=ship^.hull) do begin
          dec(tmp, sheight);
          inc(j);
        end;

        if (i=hullStart) then begin
          SetColor(White);
          SetLineStyle(DottedLn,0,NormWidth);
          Line( 0, sheight*(i-offset-1)+space, vpx2-vpx1, sheight*(i-offset-1)+space );
        end;
      end;

      DrawShipXY(100, sheight*(i-offset-1)+space, i);

      inc(i);
    end;

   {SetPal;    }
    SetViewPort(vp.x1,vp.y1,vp.x2,vp.y2,vp.clip);
  end;

begin
  MouseOff;
  MouseDisabled:=True;
  mx:=MouseX; my:=MouseY;

  {TCombat unit for pictures}
  UnlockReservedMemory(ReservedMemory);
  TCombatInit(Yes);

  {init fleet report}
  InitFleetReport;
  SortFleet;
  cursor:=1;
  offset:=0;

  shpscr := (vpy2-vpy1) div sheight;
  DrawFirst;

  chh:=27;
  repeat
    DrawFleet;

    chh:=ReadKey;
    case chh of
{up}    $4800   : if (offset>0) then dec(offset);
{down}  $5000   : if (offset<999) and (fleetReport^[offset+1+1]>0) then inc(offset);
{Pup}   $4900   : begin dec(offset, shpscr); if (offset<0) then offset:=0; end;
{Pdown} $5100   : begin
                    inc(offset, shpscr);
                    if (offset>999) then offset:=999;
                    while (fleetReport^[offset+1]<0) and (offset>0) do dec(offset);
                  end;
{home}  $4700   : offset:=0;
{end}   $4f00   : begin
                    offset:=999 - shpscr;
                    while (fleetReport^[offset+shpscr]<0) and (offset>0) do dec(offset);
                  end;
    end;
  until chh=27;

  {TCombat unit for pictures}
  TCombatFinish;
  LockReservedMemory;
  if BadVideoOrMouse then RestoreCrtMode;
  if not useSVGA then
    if customBGI then SetGraphMode(bgiMode)
    else SetGraphMode(VGAHi);
  
  helpscr:=0;
  DrawRightScreen;
  MoveMouseTo(mx,my);
  MouseDisabled:=False;
  MouseOn;
  ResetMouse;
  dispose(fleetReport);
  if lock<>0 then begin force:=lock; ForceKey:=13 end;
  DrawMap(true);
end;

{*****************************************************************************}
{** territory ** }

procedure ResetDummyShip(s:sptr);
begin
  if (s=nil) OR (s^.hull<1) OR (s^.hull>105) then Exit;
  {set all but hull which must be set priot to this}
  with s^ do begin
    when      := turn;
    owner     := player;
    fcode     := 'aaa';
    warp      := 9;
    wx        := 0;
    wy        := 0;
    x         := 1500;
    y         := 1500;
    El        := 9;
    Wl        := 9;
    Tl        := 9;
    TFnum     := 0;
    weapons   := Hulls[hull].weapons;
    bays      := Hulls[hull].bays;
    launchers := Hulls[hull].launchers;
    mission   := 5;
    enemy     := 0;
    tow_ship  := 0;
    damage    := 0;
    crew      := Hulls[hull].crew;
    colonists := 0;
    name      := '                    ';
    fuel      := Hulls[hull].fuel;
    T:=0; D:=0; M:=0; Sup:=0;
    CN:=0; CT:=0; CD:=0; CM:=0; CC:=0; CS:=0; CPl:=0;
    TN:=0; TT:=0; TD:=0; TN:=0; TC:=0; TS:=0; TSh:=0;
    intr_ship := 0;
    credits   := 0;
  end;
end;

procedure InitConnectionData;
var
  i       : int;
begin
  {Create a dummy ship. Any one which can fly 81ly without grav. will do.}
  new(dummyShip);
  for i:=1 to 105 do begin
    dummyShip^.hull := i;
    dummyShip^.owner := player;
    if (not IsShipFunc(dummyShip^,hfGravitonic)) AND (Hulls[i].mass<300) AND (Hulls[i].fuel>200) then
      Break;
  end;
  ResetDummyShip(dummyShip);
  {Init connection data structure.}
  new(pCon);
  for i:=1 to 500 do
    pCon^[i] := nil;
  pConDist := -1;
  pConDistIsWarp := false;
  pConTurn := -1;
end;

procedure DisposeConnectionData;
var
  i       : int;
begin
  for i:=1 to 500 do begin
    if pCon^[i] <> nil then Dispose(pCon^[i]);
    pCon^[i] := nil;
  end;
  Dispose(pCon);
end;

procedure BuildConnectionData(dist: long; dist_is_warp: boolean);
var
  i,j,n   : int;

  procedure AddNeighbor(p1,p2: int);
  var n: int;
  begin
    if (pCon^[p1]=nil) or (pCon^[p2]=nil) then Exit;
    for n:=1 to MAX_NEIGHBORS do
      if pCon^[p1]^.neighbor[n] = -1 then begin pCon^[p1]^.neighbor[n]:=p2; Break; end;
    for n:=1 to MAX_NEIGHBORS do
      if pCon^[p2]^.neighbor[n] = -1 then begin pCon^[p2]^.neighbor[n]:=p1; Break; end;
  end;

  function TimeToTravel(x1,y1,x2,y2,speed:int) : int;
  var
    burn : int;
    time : int;
    dx,dy: int;
  begin
    dx:=x2-x1; dy:=y2-y1;
    if mapwrap then begin
      while (2*dx> MapSize) do dx:=dx-MapSize;
      while (2*dx<-MapSize) do dx:=dx+MapSize;
      while (2*dy> MapSize) do dy:=dy-MapSize;
      while (2*dy<-MapSize) do dy:=dy+MapSize;
    end;
    ResetDummyShip(dummyShip);
    with dummyShip^ do begin
      x:=x1; y:=y1; wx:=dx; wy:=dy; warp:=speed;
    end;
    CalcMovement(dummyShip, nil, burn, time);
    TimeToTravel:=time;
  end;

  function IsConnected(x1,y1,x2,y2,d: int; dist_is_warp,Gravity: boolean): boolean;
  var
    i,j,dist: int;
    d1 : int;
  begin
    IsConnected:=false;
    if (dist_is_warp) then dist:=d*d else dist:=d;
    d1:=Round(SQRT(Distance2(x1, y1, x2, y2)));
    if (d1 <= dist) then
      IsConnected:=true
    else if not Gravity and (d1-1<=dist) and (dist_is_warp) then
      IsConnected:=(TimeToTravel(x1,y1,x2,y2,d)<=1)
    else if Gravity and (d1-GravityRange-1<=dist) then begin
      {trial-and-error through warp well}
      for i:=-GravityRange to GravityRange do
        for j:=-GravityRange to GravityRange do begin
          if (i<>0) or (j<>0) then
            if RoundWells and (i*i+j*j<=GravityRange*GravityRange) or
                (not RoundWells) and (Abs(i)<=GravityRange) and (Abs(j)<=GravityRange) then
            begin
              if (IsConnected(x1,y1,x2+i,y2+j,d,dist_is_warp,false)) then begin
                IsConnected:=true;
                Exit;
              end;
            end;
        end;
    end;
  end;

begin
  with TTurn^.data^ do begin

    {clear data}
    for i:=1 to 500 do begin
      if pCon^[i] <> nil then Dispose(pCon^[i]);
      if (xyplan[i,1] = -1) then begin
        pCon^[i] := nil;
      end else begin
        New(pCon^[i]);
        pCon^[i]^.id := i;
        for n:=1 to MAX_NEIGHBORS do
          pCon^[i]^.neighbor[n] := -1;
      end;
    end;

    {build data}
    for i:=1 to 500 do
      for j:=i+1 to 500 do
        if (pCon^[i]<>nil) and (pCon^[j]<>nil) then
          if IsConnected(xyplan[i,1], xyplan[i,2], xyplan[j,1], xyplan[j,2], dist, dist_is_warp, Gravity) then begin
            AddNeighbor(i,j);
            {if (Distance2(xyplan[i,1], xyplan[i,2], xyplan[j,1], xyplan[j,2])>84*84) then
              OutTextXY(0, i div 2, NStr0(i)+','+NStr0(j));}
          end;

  end;

  pConDist := dist;
  pConDistIsWarp := dist_is_warp;
  pConTurn := TTurn^.turn;
end;

function IsNeighbor(p1,p2,dist: int; dist_is_warp: boolean): boolean;
var n : int;
begin
  if (dist<>pConDist) or (dist_is_warp and not pConDistIsWarp) or (not dist_is_warp and pConDistIsWarp)
  or (TTurn^.turn<>pConTurn) then
    BuildConnectionData(dist, dist_is_warp);
  IsNeighbor := false;
  if (pCon^[p1]<>nil) and (pCon^[p2]<>nil) then
    for n:=1 to MAX_NEIGHBORS do
      if (pCon^[p1]^.neighbor[n] = p2) then begin IsNeighbor:=true; Break; end;
end;

procedure DrawTerritory;
const
  radius    = 84;
const RaceColor : array [1..11] of word =
      (White,Yellow,LightGreen,Brown,Cyan,LightMagenta,
       LightGray,LightRed,Magenta,LightBlue,LightCyan);
var
  i       : int;
  function DistAbs2Scr(dist: long):long;
  begin
    DistAbs2Scr := (dist*ratio2) div ratio1;
  end;
  function DistScr2Abs(dist: long):long;
  begin
    DistScr2Abs := (dist*ratio1) div ratio2;
  end;
  function PlanetDist2(x,y,p: int): long;
  begin
    with TTurn^.data^ do
      PlanetDist2 := Distance2(x,y,xyplan[p,1],xyplan[p,2]);
  end;
  procedure DrawPlanet(p : int);
  var
    xp,yp                : int;
    x1,y1,x2,y2          : int;
    xr,yr                : int;
    i,j,n                : int;
    put                  : boolean;
    pdist2               : long;
  begin
    with TTurn^.data^ do begin
      {ignore planets without owner info}
      if (planet[p]=nil) or (planet[p]^.owner<1) then Exit;
      {ignore old information about own planets}
      if (turn<>planet[p]^.when) and (planet[p]^.owner=player) then Exit;

      Abs2Scr(xyplan[p,1],xyplan[p,2],xp,yp);
      x1 := xp-radius;
      y1 := yp-radius;
      x2 := xp+radius;
      y2 := yp+radius;
      if ( ((x1>=0) and (x1<480) and (y1>=0) and (y1<480))
      or ((x2>=0) and (x2<480) and (y2>=0) and (y2<480))
      or ((x2>=0) and (x2<480) and (y1>=0) and (y1<480))
      or ((x1>=0) and (x1<480) and (y2>=0) and (y2<480))
      ) then begin
        {at least part of this planet's territory will be on screen}
        for i:=x1 to x2 do
          for j:=y1 to y2 do begin
            {if ((i+j) mod 2 = 0) then begin}
            Scr2Abs(i,j,xr,yr);
            pdist2 := PlanetDist2(xr,yr,p);
            if ( pdist2 <= radius*radius ) then begin
              put := true;
              for n:=1 to MAX_NEIGHBORS do
                if ((pCon^[p]^.neighbor[n]>0)
                and (planet[pCon^[p]^.neighbor[n]]<>nil)
                and (planet[pCon^[p]^.neighbor[n]]^.owner>0)
                and ( (planet[pCon^[p]^.neighbor[n]]^.when=turn) or (planet[pCon^[p]^.neighbor[n]]^.owner<>player) )
                and (PlanetDist2(xr,yr,pCon^[p]^.neighbor[n])<pdist2))
                then begin
                  put := false;
                  Break;
                end;
              if put then
                PutPixel( i, j, RaceColor[planet[p]^.owner] );
              {end;}
            end;
          end;
      end;
    end;
  end;
begin
  if (radius*2<>pConDist) or (pConDistIsWarp) or (TTurn^.turn<>pConTurn) then
    BuildConnectionData(radius*2, false);
  SetViewPort(0,0,479,479,ClipOn);
  MouseOff;
  for i:=1 to 500 do
    if (pCon^[i]<>nil) then
      DrawPlanet(i);
  MouseOn;
end;

{*****************************************************************************}
{** hooks ** }

procedure ExtFeatKeyHook( ch: word );
var
  i,j     : int;
  tmpNote : NotePtr;
  isTmp   : boolean;
begin
  {OutTextXY(MX0,48,NStr(ch));}
  case ch of

{#}     ord('#'): if (turn=today) then begin MouseMove; ShowQAOverview(7); end;
{~v}    $2F00   : if (turn=today) then begin MouseMove; ShowQAOverview(8); end;

{^a}    1       : if RWMode and (turn=today) then begin
                    if (ltype=LockS) and showS and (lship^.owner=player) then SetActList( lock, true )
                    else if (lplan<>nil) then
                      if (ltype=LockP) and (lplan^.owner=player) and (lplan^.when=turn) then
                        if (lbase=nil) then SetActList( lock, true )
                                       else SetActList( (lock and LockLo) or LockB, true );
                    force:=lock;
                    ForceKey:=13;
                  end;
{^d}    4       : if RWMode and (turn=today) then begin
                    if (ltype=LockS) and showS and (lship^.owner=player) then SetActList( lock, false )
                    else if (lplan<>nil) then
                      if (ltype=LockP) and (lplan^.owner=player) and (lplan^.when=turn) then
                        if (lbase=nil) then SetActList( lock, false )
                                       else SetActList( (lock and LockLo) or LockB, false );
                    force:=lock;
                    ForceKey:=13;
                  end;
{_j}    ord('J'): if (ltype=LockP) and (lplan<>nil) and (lbase=nil) then begin
                    if (ShowMaxPop) then begin ShowColonistPrediction:=false; ShowMaxPop:=false; end
                      else if (ShowColonistPrediction) then begin ShowMaxPop:=true; ShowColonistPrediction:=false; end
                      else ShowColonistPrediction:=true;
                    force:=lock;
                    ForceKey:=13;
                  end;
{_l}    ord('L'): begin showL:=not showL; WriteShows; MouseMove; DrawMap(Yes) end;
{^l}    12      : ShowConnections;

{^b}    2       : if (ltype=LockP) then Borgculator;
{^c}    3       : DrawMap(No);
{^n}    14      : if (lock>0) and ((ltype=LockP) or (ltype=LockS)) then begin
                    ShowNote(lock);
                  end;

{^f10}  $6700   : WriteResourceStats;
{^f11}  $8900   : ShowFleetReport;

{~i}    $1700   : IonStormWayPoint;

{^e}    5       : begin
                    DrawTerritory;
                    DrawMap(false);
                  end;

{test}  {ord('_'): begin OutTextXY(0, 0, NStr0(dlx)+','+NStr0(dly));OutTextXY(0, 8, NStr0(lx)+','+NStr0(ly)); end;}
{test}  {ord('_'): begin
                    SetColor(white);
                    for j:=0 to 15 do
                      for i:=0 to 15 do
                        OutTextXY(9+i*9, 9+j*9, Chr(i+j*16));
                  end;}
  end;
end;

procedure ExtFeatInfoDisplayHook;
var
  p       : pptr;
  sh      : sptr;
  number  : int;
  tmp,tmp2: long;
  b       : byte;
begin
  number:=lock and LockLo;
  if (number=0) or (number>500) then Exit;

  if (ltype=LockP) and (lbase<>nil) then begin
    {nothing do do for starbases right now}
  end else
  if ltype=LockP then begin
    {display estimated colonists for next turn}         {Quapla DA-Code}
    if (ShowColonistPrediction) then begin
      p:=TTurn^.data^.planet[number];
      if (p<>nil) and (p^.owner=player) then begin
        Clear(MX0, 216, 639, 223);
        tmp2 := p^.colonists+ColonistGrowth(p,number,tmp);
        if (tmp2>0) then SetColor(Green) else SetColor(Lightred);
        OutTextXY(MX0,216,' Next : '+NStr0(tmp2));
      end;
    end;
    {indicate note on this object}
    if HasNote(lock) then
      DrawNoteIcon( 615, 72, IIF( GetActList(lock), NoteIconColorInactive, NoteIconColor ));
  end else
  if ltype=LockS then begin
    if (ShowScoreValue) then begin
      sh:=TTurn^.data^.ship[number];
      if (sh<>nil) and (sh^.owner=player) and (sh^.when=turn) then begin
        Clear(MX0, 248, 639, 255);
        SetColor(DarkGray);
        OutTextXY(MX0, 248, ScoringMethodLabels[GetScoringMethod]+': '+
                  NStr0(GetShipScoreCurrent(sh)));
      end;
    end else begin {Show Pillage Gains Quapla}
        sh:=TTurn^.data^.ship[number];
        if (sh<>nil) and ((sh^.owner=4) or (sh^.owner=1)) {and (sh^.weapons>0) and (sh^.fuel>0) and (sh^.mission=9)}
        then begin    
          GetPillage(number);
      end;
    end;
    {indicate note on this object}
    if HasNote(lock) then
      DrawNoteIcon( 615, 72, IIF( GetActList(lock), NoteIconColorInactive, NoteIconColor ));
  end;
end;

procedure ExtFeatChangeDataHook(xt:xtype; n:int);
begin
  if (AutoDisapprove) then
    case xt of
      Sh : SetActList( LockS or n, false );
      Pl : SetActList( LockP or n, false );
      Ba : SetActList( LockB or n, false );
    end;
end;

procedure ExtFeatStartVPAHook;
begin
  {init array for planet connections}
  InitConnectionData;
  {handle DXC subscriptions}
  if (PlayerRSTUnpacked) then
    HandleDXCSubscriptions;
end;

procedure ExtFeatQuitVPAHook;
begin
  {dispoe array for planet connections}
  DisposeConnectionData;
end;

procedure ExtFeatDrawMapBeginHook;
var   xx,yy     : int;
begin
  if showL then
  begin
    {DrawTerritory;}
    if (ConnectionDist<10) then
      DrawConnections( ConnectionDist, cConn, true )
    else
      DrawConnections( ConnectionDist, cConn, false );
  end;
  if (tmpConnDist>0) then begin
{    SetViewPort(0,0,479,479,ClipOn);}
    if (tmpConnDist<10) then
      DrawConnections( tmpConnDist, cConn, true )
    else
      DrawConnections( tmpConnDist, cConn, false );
    tmpConnDist:=-1;
  end;
end;

procedure ExtFeatDrawMapEndHook;
begin
end;

procedure CGExtOpenGraphHook;
var
  s: String;
  i: int;
begin
  s:='CGExt '+CGExtVersion;
  i:=((17-Length(s)) div 2);
  SetColor(LightMagenta);
  OutTextXY(MX0+i*8, 32*8, s);
  SetLineStyle(SolidLn,0,NormWidth);
  Line(MX0+i*8, 33*8, MX0+i*8+Length(s)*8, 33*8);
  SetColor(Cyan);
  OutTextXY(MX0,34*8,  'Copyright (c) 2003');
  OutTextXY(MX0,34*8+12,'   by C. Graefe   ');
end;

procedure ExtFeatSaveAllHook;
begin
  if (NoteDataChg) then
    SaveNotes;
end;

{return true if line was handled here}
function ExtFeatReadConfigFileHook( s: string; sec:cfgSec ): boolean;
var
  i,j     : byte;
  {sec     : CGExtCfgSec;}
  key     : CGExtCfgKey;
  s1      : string;
  ls      : byte absolute s;
  ls1     : byte absolute s1;
  r       : boolean;

  function YesNo : boolean;
  begin
    Trim(s); Upper(s);
    YesNo:=(s='YES') or (s='ON') or (s='RULEZ');
  end;
begin
  ExtFeatReadConfigFileHook:=false;
  r:=false;
  if ((s[1]='[') and (s[ls]=']')) or (s[1]='%') then
  begin
  {
    if (s[1]<>'%') then dec(ls);
    Delete(s,1,1);
    Trim(s); Upper(s);
    sec:=cfgSec(ItemPos(s,CGExtSecNames));
  }
  end
  else if sec<sUnknown then
  begin
    i:=Pos('=',s); if i=0 then Exit;
    s1:=Copy(s,1,i-1);
    Trim(s1); Upper(s1);
    Delete(s,1,i); LTrim(s);
    key:=CGExtCfgKey(ItemPos(s1,CGExtKeyNames));

    if key<kUnknown then
      case sec of
        sColor    : case key of
          extCConnection            : begin cConn:=Value(s); r:=true; end;
                    end;
        sInterface: case key of
          extConnectionDist         : begin ConnectionDist:=Value(s); r:=true; end;
          extShowMapBorder          : begin ShowMapBorder:=YesNo; r:=true;  end;
          extShowColonistPrediction : begin ShowColonistPrediction:=YesNo; r:=true; 
                                       if ShowMaxPop then ShowColonistPrediction:=false; end;
          extShowCheckMark          : begin ShowCheckMark:=YesNo; r:=true;  end;
          extShowScoreValue         : begin ShowScoreValue:=YesNo; r:=true;  end;
          extAutoDisapprove         : begin AutoDisapprove:=YesNo; r:=true;  end;
          extScoringMethod          : begin ScoringMethod:=s; r:=true; end;
          extConfirmNotes           : begin ConfirmNotes:=YesNo; r:=true;  end;
                    end;
        {moved to config.pas}
        {
        sConfig   : case key of
                    end;
        }
      end;
  end;
  ExtFeatReadConfigFileHook:=r;
end;

{return true if message was handled here}
function ExtFeatReadMessagesHook(sender:byte; m:Msg): boolean;
var
  i       : int;
  l       : byte;
  s       : string[40];
begin
  ExtFeatReadMessagesHook:=false;
  {writeln('-->'+m.text[5]);}
  for l:=1 to m.lines do begin
    s := m.text[l];
    Trim(s);
    if (StrCmp(s,TransmissionMarker,RLen(TransmissionMarker))) and
       (l<=m.lines-2) and (StrCmp(m.text[l+2],'OBJECT: Statistic T',19)) then
    begin
      ExtFeatParseData(sender,m,l);
      ExtFeatReadMessagesHook:=true;
      Exit;
    end;
  end;
end;

procedure ExtFeatReadDataHook;
begin
  LoadNotes;
end;

procedure ExtFeatBuildingWriteCalcHook(Hn,En,blW,Wn,blT,Tn: int);
var
  sm : ScoringMethodKey;
begin
  sm:=GetScoringMethod;
  if (sm<smUnknown) then begin
    SetColor(LightGray);
    SetLineStyle(SolidLn,0,NormWidth);
    SetWriteMode(NormalPut);
    Line(0,469,183,469);
    Clear(0,472,182,479);
    OutTextXY(0,472, ScoringMethodLabels[sm]+
      ': '+NStr0(GetShipScoreEmpty(Hn,En,blW,Wn,blT,Tn))+
      ' ('+NStr0(GetShipScoreTotal(Hn,En,blW,Wn,blT,Tn))+')');
  end;
end;

procedure ExtFeatUnpackRSTEndHook(race: int);
var i: integer;
begin
  if (race=player) then
    PlayerRSTUnpacked := true;
end;

end.
