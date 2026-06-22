{$I switches.inc}
Unit	Report;		(* VPA Report Maker *)
{$V-}
{$A-}

Interface

uses	StrF;

procedure WriteReport (frmname,rptname:str79);

Implementation

uses	ptcgraph,Dos,VPAData,Screen,AuxF,Mouse,Scores;

type	strg	= string[30];
	Section = (_General,_Scores,_Planets,_Bases,_Ships,_Fleet,_Enemies,_Unknown);
	KeyWord	= (Count,
		   gTurn,gRace,
		   cRace,cScore,cPlanets,cBases,cCapShips,cFrShips,cAllShips,cPBP,
		   pID,pBase,pName,pFCode,pPop,pHappy,pTaxes,pMines,pMaxMines,pFact,pMaxFact,pDef,pMaxDef,
		   pSupp,pFunds,pIncome,pN,pT,pD,pM,pCN,pCT,pCD,pCM,pMN,pDN,pMT,pDT,
		   pMD,pDD,pMM,pDM,pTemp,pClimate,pNRace,pNRatio,pNPop,pNTaxes,pNHappy,
		   bID,bName,bDefense,bDamage,bFighters,bEL,bHL,bWL,bTL,bOrder,bFixRec,
		   bBldHull,bBldEL,bBldWeaps,bBldWName,bBldWL,bBldTubes,bBldTName,bBldTL,
		   sID,sHull,sName,sLocation,sWayPoint,sDistance,sWarp,sTime,sFTM,sFuel,sMaxFuel,
		   sMass,sCrew,sDamage,sFCode,sMission,sEnemy,sEL,
		   sWeapons,sWName,sWL,sTubes,sTName,sTL,sBays,sFish,sT,sD,sM,sSupp,sClans,sMoney,
		   fHull,fNumber,
		   eID,eRace,eHull,eName,eLocation,eWarp,eMass,eLoad);

const   Sections: array [1..50] of char =
		  'GENERAL SCORES PLANETS BASES SHIPS FLEET ENEMIES  ';
	SecKeys	: array [Section,1..2] of KeyWord =
		( (gTurn,gRace),
		  (cRace, cPBP),
		  (pID,pNHappy),
		  (bID,bBldTL),
		  (sID,sMoney),
		  (fHull,fNumber),
		  (eID,eLoad),
		  (gTurn,gTurn) );

	KeyWords: array [1..13,1..50] of char =
		( 'COUNT TURN RACE RACE SCORE PLANETS BASES CAPSHIPS ',
		  'FRSHIPS ALLSHIPS PBP ID BASE NAME FCODE POP HAPPY ',
		  'TAXES MINES MAXMINES FACT MAXFACT DEF MAXDEF SUPP ',
		  'FUNDS INCOME N T D M CN CT CD CM MN DN MT DT MD DD',
		  ' MM DM TEMP CLIMATE NRACE NRATIO NPOP NTAXES NHAPP',
		  'Y ID NAME DEFENSE DAMAGE FIGHTERS EL HL WL TL ORDE',
		  'R FIXREC BLDHULL BLDEL BLDWEAPONS BLDWNAME BLDWL B',
		  'LDTUBES BLDTNAME BLDTL ID HULL NAME LOCATION WAYPO',
		  'INT DISTANCE WARP TIME FUELTOMOVE FUEL MAXFUEL MAS',
		  'S CREW DAMAGE FCODE MISSION ENEMY EL WEAPONS WNAME',
		  ' WL TUBES TNAME TL BAYS FISH T D M SUPP CLANS MONE',
		  'Y HULL NUMBER ID RACE HULL NAME LOCATION WARP MASS',
		  ' LOAD                                             ' );
	MaxKeyLen = 10;


type	cptr	= ^Scor;

PROCEDURE WriteReport (frmname,rptname:str79);

var	frm,rpt	: text;
	format	: string;
	lformat	: byte absolute format;
	values	: string;
	lvalues	: byte absolute values;
	sect	: Section;
	pnn,rnn	: word;		{ object indexes  }
	p,p0	: pointer;	{ -> object records for curr & prev turn }
	sc,sc0	: Scor;
	nnn	: long;
	ss	: strg;
	lss	: byte absolute ss;
	grmode	: boolean;

function CountHull (hull:word) : int;
  var	i,n	: int;
	h	: sptr;
  begin
    n:=0;
    for i:=1 to 999 do
    begin
      h:=TTurn^.data^.ship[i];
      if (h<>nil) and (h^.when=turn) and
	 (h^.owner=player) and (h^.hull=hull) then inc(n);
    end;
    CountHull:=n;
  end;

procedure InitData;
  var	t	: tptr;
  begin
    FillChar(sc,SizeOf(Scor),0);
    t:=TSearch(turn);
    if t<>nil then
    begin
      sc.sc:=t^.score;
      FillChar(sc.pbp,SizeOf(PBPList),$FF);
      if t^.IsPBP then sc.pbp:=t^.PBP;
      ArrangeScores(sc);
    end;
    t:=TSearch(turn-1);
    if t<>nil then
    begin
      sc0.sc:=t^.score;
      FillChar(sc0.pbp,SizeOf(PBPList),$FF);
      if t^.IsPBP then sc0.pbp:=t^.PBP;
      ArrangeScores(sc0);
      ReArrangeScores(sc,sc0);
    end
    else Move(sc,sc0,SizeOf(Scor));
  end;

function NextObject : boolean;
  begin
    NextObject:=No;
    p:=nil; p0:=nil;
    case sect of
      _General	: NextObject:=Yes;
      _Scores	: begin
		    inc(pnn);
		    p:=Addr(sc); p0:=Addr(sc0);
		    NextObject:=((pnn<=11) and ((sc.sl[pnn,2]>0) or (sc0.sl[pnn,2]>0)));
		  end;
      _Planets	: begin
		    repeat
		      inc(pnn);
		      p:=TTurn^.data^.planet[pnn];
		      if (TPrev<>nil) and (TPrev^.data<>nil) then p0:=TPrev^.data^.planet[pnn];
		      if (p0<>nil) and ((pptr(p0)^.owner<>player) or (pptr(p0)^.when<>turn-1)) then p0:=nil;
		    until (pnn>500) or ((p<>nil) and (pptr(p)^.owner=player) and (pptr(p)^.when=turn));
		    NextObject:=(pnn<=500);
		  end;
      _Bases	: begin
		    repeat
		      inc(pnn);
		      p:=TTurn^.data^.base[pnn];
		      if (TPrev<>nil) and (TPrev^.data<>nil) then p0:=TPrev^.data^.base[pnn];
		    until (pnn>500) or (p<>nil);
		    NextObject:=(pnn<=500);
		  end;
      _Ships	: begin
		    repeat
		      inc(pnn);
		      p:=TTurn^.data^.ship[pnn];
		      if (TPrev<>nil) and (TPrev^.data<>nil) then p0:=TPrev^.data^.ship[pnn];
		      if (p0<>nil) and ((sptr(p0)^.owner<>player) or (sptr(p0)^.when<>turn-1)) then p0:=nil;
		    until (pnn>999) or ((p<>nil) and (sptr(p)^.owner=player) and (sptr(p)^.when=turn));
		    NextObject:=(pnn<=999);
		  end;
      _Fleet	: begin
		    repeat
		      inc(pnn);
		    until (pnn>105) or (CountHull(pnn)>0);
		    NextObject:=(pnn<=105);
		  end;
      _Enemies	: begin
		    repeat
		      repeat
			inc(pnn);
			p:=TTurn^.data^.ship[pnn];
			if (TPrev<>nil) and (TPrev^.data<>nil) then p0:=TPrev^.data^.ship[pnn];
			if (p0<>nil) and ((sptr(p0)^.owner<>player) or (sptr(p0)^.when<>turn-1)) then p0:=nil;
		      until (pnn>999) or ((p<>nil) and (sptr(p)^.owner=rnn) and (sptr(p)^.when=turn));
		      if pnn>999 then
		      begin
			inc(rnn);
			if rnn=player then inc(rnn);
			pnn:=0
		      end;
		    until (rnn>11) or ((p<>nil) and (sptr(p)^.owner=rnn) and (sptr(p)^.when=turn));
		    NextObject:=(rnn<=11) and (pnn<=999);
		  end;
    end;
    if p0=nil then p0:=p;
  end;

procedure FormatNNN (len:byte; plus:boolean);
  begin
    if nnn=0 then ss:='0'
    else begin
      Str(nnn,ss);
      if plus and (nnn>0) then ss:='+'+ss;
    end;
    if lss>len then
    begin
      if nnn>0 then ss[1]:='+' else ss[1]:='-';
      lss:=1;
      while lss<len do ss:=ss+ss[1];
    end
    else while lss<len do ss:=' '+ss;
  end;

function GetValue (pntr:pointer; k:KeyWord) : long;
  var   c	: cptr absolute pntr;
	p	: pptr absolute pntr;
	b	: bptr absolute pntr;
	h	: sptr absolute pntr;
	d	: single;
	i,e	: integer;
  begin
    GetValue:=nnn;
    lss:=0; nnn:=0;
    case k of
      Count	: nnn:=1;
      gTurn	: Str(turn,ss);
      gRace	: ss:=RaceFull[player];
      cRace	: ss:=RaceName[c^.sl[pnn,1]];
      cScore	: nnn:=c^.sl[pnn,2];
      cPlanets	: nnn:=c^.sc[pnn,1];
      cBases	: nnn:=c^.sc[pnn,4];
      cCapShips	: nnn:=c^.sc[pnn,2];
      cFrShips	: nnn:=c^.sc[pnn,3];
      cAllShips	: nnn:=c^.sc[pnn,2]+c^.sc[pnn,3];
      cPBP	: nnn:=Max(c^.pbp[pnn],0);
      pID	: nnn:=pnn;
      pBase	: if ((p^.when=turn) and (TTurn^.data^.eplan[pnn].activity and 128<>0)) or
		     ((p^.when=turn-1) and (TPrev^.data^.eplan[pnn].activity and 128<>0))
		    then ss:='*'
		  else if PlanetCanBuildBase(p) then ss:='.';
      pName	: ss:=PlanName[pnn];
      pFCode	: ss:=p^.fcode;
      pPop	: nnn:=p^.colonists*100;
      pHappy	: nnn:=p^.Cstat;
      pTaxes	: nnn:=p^.Ctax;
      pMines	: nnn:=p^.mines;
      pMaxMines	: nnn:=IIF(p^.Nc+p^.Tc+p^.Dc+p^.Mc=0,0,MaxPlanetStruct(p,200));
      pFact	: nnn:=p^.factories;
      pMaxFact	: nnn:=MaxPlanetStruct(p,100);
      pDef	: nnn:=p^.defense;
      pMaxDef	: nnn:=MaxPlanetStruct(p,50);
      pSupp	: nnn:=p^.supplies;
      pFunds	: nnn:=p^.funds;
      pIncome	: nnn:=PlanetIncome(p,pnn,TRUE); {Quapla speed break - incl. Movement}
      pN	: nnn:=p^.N;
      pT	: nnn:=p^.T;
      pD	: nnn:=p^.D;
      pM	: nnn:=p^.M;
      pCN	: nnn:=p^.Nc;
      pCT	: nnn:=p^.Tc;
      pCD	: nnn:=p^.Dc;
      pCM	: nnn:=p^.Mc;
      pDN	: nnn:=IIF(p^.Nc=0,0,p^.Nm);
      pDT	: nnn:=IIF(p^.Tc=0,0,p^.Tm);
      pDD	: nnn:=IIF(p^.Dc=0,0,p^.Dm);
      pDM	: nnn:=IIF(p^.Mc=0,0,p^.Mm);
      pMN	: nnn:=MiningRate(p,p^.Nc,p^.Nm,nil);
      pMT	: nnn:=MiningRate(p,p^.Tc,p^.Tm,nil);
      pMD	: nnn:=MiningRate(p,p^.Dc,p^.Dm,nil);
      pMM	: nnn:=MiningRate(p,p^.Mc,p^.Mm,nil);
      pTemp	: nnn:=100-p^.climate;
      pClimate	: ss:=ClimStr[ClimateType(p^.climate)];
      pNRace	: ss:=NatRace[p^.Nrace];
      pNRatio	: nnn:=p^.Ngovt*20;
      pNPop	: nnn:=p^.natives*100;
      pNTaxes	: nnn:=p^.Ntax;
      pNHappy	: nnn:=p^.Nstat;
      bID	: nnn:=pnn;
      bName	: ss:=PlanName[pnn];
      bDefense	: nnn:=b^.defense;
      bDamage	: nnn:=b^.damage;
      bFighters	: nnn:=b^.fighters;
      bEL	: nnn:=b^.El;
      bHL	: nnn:=b^.Hl;
      bWL	: nnn:=b^.Wl;
      bTL	: nnn:=b^.Tl;
      bOrder	: ss:=BaseOrd[b^.order];
      bFixRec	: if b^.fOp<>0 then
      		  begin
		    Str(b^.fShip,ss);
		    if b^.fOp=1 then ss:='Fix #'+ss;
		    if b^.fOp=2 then ss:='Recycle #'+ss
		  end;
      bBldHull	: if b^.cHl<>0 then ss:=Hulls[RaceHull[IIF(TrueHullByRace,Race[b^.owner],b^.owner),
					      b^.cHl]].name;
      bBldEL	: nnn:=b^.cEl;
      bBldWeaps	: nnn:=b^.cWn;
      bBldWName	: if b^.cWl<>0 then ss:=Beams[b^.cWl].name;
      bBldWL	: nnn:=b^.cWl;
      bBldTubes	: nnn:=b^.cTn;
      bBldTName	: if b^.cTl<>0 then ss:=Torps[b^.cTl].name;
      bBldTL	: nnn:=b^.cTl;
      sID	: nnn:=pnn;
      sHull	: if h^.hull<>-1 then ss:=Hulls[h^.hull].name;
      sName	: ss:=h^.name;
      sLocation	: ss:=Location(h^.x,h^.y);
      sWayPoint	: if (h^.warp<>0) and (h^.wx or h^.wy <> 0) then ss:=Location(h^.x+h^.wx,h^.y+h^.wy);
      sDistance	: if (h^.warp<>0) and (h^.wx or h^.wy <> 0) then
		    begin d:=Sqrt(Distance2(0,0,h^.wx,h^.wy)); Str(d:3:1,ss) end;
      sWarp	: if h^.wx or h^.wy <> 0 then nnn:=h^.warp;
      sTime	: begin CalcMovement(h,StdTowPtr(h^),i,e); nnn:=e end;
      sFTM	: begin CalcMovement(h,StdTowPtr(h^),i,e); nnn:=i end;
      sFuel	: nnn:=h^.fuel;
      sMaxFuel	: if h^.hull<>-1 then nnn:=Hulls[h^.hull].fuel;
      sMass	: nnn:=h^.mass;
      sCrew	: nnn:=h^.crew;
      sDamage	: nnn:=h^.damage;
      sFCode	: ss:=h^.fcode;
      sMission	: begin
                    if (h^.mission<0) or (h^.mission>15) then begin
                      ss := 'Misn.' + NStr(h^.mission);
                      if h^.intr_ship<>0 then ss := ss + ' I:' + NStr(h^.intr_ship);
                      if h^.tow_ship<>0 then ss := ss + ' T:' + NStr(h^.tow_ship);
                    end else begin
                      if h^.mission in [7,8] then Str(IIF(h^.mission=7,h^.tow_ship,h^.intr_ship),ss)
                                             else ss:='';
                      if h^.mission<>9 then ss:=Missions[h^.mission]+' '+ss
                                       else ss:=SpecMisn[Race[RealShipOwner(pnn)]];
                    end;
      		  end;
      sEnemy	: ss:=RaceName[h^.enemy];
      sEL	: nnn:=h^.El;
      sWeapons	: nnn:=h^.weapons;
      sWName	: if h^.Wl<>0 then ss:=Beams[h^.Wl].name;
      sWL	: nnn:=h^.Wl;
      sTubes	: nnn:=h^.launchers;
      sTName	: if h^.Tl<>0 then ss:=Torps[h^.Tl].name;
      sTL	: nnn:=h^.Tl;
      sBays	: nnn:=h^.bays;
      sFish	: nnn:=h^.TFnum;
      sT	: nnn:=h^.T;
      sD	: nnn:=h^.D;
      sM	: nnn:=h^.M;
      sSupp	: nnn:=h^.Sup;
      sClans	: nnn:=h^.colonists;
      sMoney	: nnn:=h^.credits;
      fHull	: ss:=Hulls[pnn].name;
      fNumber	: nnn:=CountHull(pnn);
      eID	: nnn:=pnn;
      eRace	: ss:=RaceName[h^.owner];
      eHull	: if h^.hull<>-1 then ss:=Hulls[h^.hull].name;
      eName	: ss:=h^.name;
      eLocation	: ss:=Location(h^.x,h^.y);
      eWarp	: if h^.warp<>-1 then nnn:=h^.warp;
      eMass	: if h^.mass<>0 then nnn:=h^.mass;
      eLoad	: if (h^.hull<>-1) and (h^.mass<>0) then ss:=FuelCargoMass(h);
    end;
  end;

procedure FormatPrint;
  var	fi,vi	: byte;
	fs,fl	: byte;
	vs,vl	: byte;
	s	: string;
	key,ks	: string[MaxKeyLen];
	lkey	: byte absolute key;
	k,k2	: KeyWord;
	sum,dif	: boolean;
	nnn1	: long;
	pnn1,rnn1	: int;
  begin
    s:=format;	{ output string }
    fi:=1;      { format string index }
    vi:=1;	{ value list index }
    repeat
      if (RLen(format)=0) or (RLen(values)=0) then Break;
      while (fi<=lformat) and (format[fi]<>'#') do inc(fi);
      fs:=fi;    { field start }
      while (fi<=lformat) and (format[fi]='#') do inc(fi);
      fl:=fi-fs; { field length }
      while (vi<=lvalues) and (values[vi] in [' ',#9]) do inc(vi);
      sum:=No; dif:=No;
      if values[vi]='*' then begin sum:=Yes; inc(vi) end;
      if values[vi]='+' then begin dif:=Yes; inc(vi) end;
      vs:=vi;    { value start }
      while (vi<=lvalues) and (values[vi]<>',') do inc(vi);
      vl:=vi-vs; { field start }
      inc(vi);
      if (fl<>0) and (vl<>0) then
      begin
	key:=Copy(values,vs,vl);
	while (lkey>0) and (key[lkey] in [' ',#9]) do dec(lkey);
	if ItemPos(key,KeyWords)=word(Count) then begin k:=Count; k2:=Count end
	else begin
	  k2:=SecKeys[sect,2];
	  k:=SecKeys[sect,1];
	  while k<=k2 do
	  begin
	    ItemStr(KeyWords,word(k),ks);
	    if key=ks then Break;
	    inc(k);
	  end;
	end;
	lss:=0;
	if k>k2 then while lss<fl do ss:=ss+'?'
	else begin
	  if sum then
	  begin
	    pnn1:=pnn; rnn1:=rnn;
	    pnn:=0; rnn:=0; nnn1:=0;
	    while NextObject do
	    begin
	      GetValue(p,k);
	      if dif then nnn:=GetValue(p0,k)-nnn;
	      inc(nnn1,nnn);
	    end;
	    nnn:=nnn1;
	    pnn:=pnn1;
	  end
	  else begin
	    GetValue(p,k);
	    if dif then nnn:=GetValue(p0,k)-nnn;
	  end;
	end;
	if (nnn<>0) or ((k in [pHappy,pNHappy,pTemp]) and (not dif))
	  then FormatNNN(fl,dif)
	  else while lss<fl do ss:=ss+' ';
	Move(ss[1],s[fs],fl);
	LTrim(ss);
	if (lss=0) and (s[fs+fl]='%') then s[fs+fl]:=' ';
	if (lss=0) and (s[fs+fl]='x') then s[fs+fl]:=' ';
	if (lss=0) and (s[fs+fl+1]='x') then s[fs+fl+1]:=' ';
	if (lss=0) and (s[fs-1]='/') and (s[fs-2]=' ') then s[fs-1]:=' ';
	if (s[fs-1]='(') and (s[fs+fl]=')') then
	  if lss=0 then
	    begin s[fs-1]:=' '; s[fs+fl]:=' ' end
	  else if lss<fl then
	    begin s[fs-1+fl-lss]:='('; s[fs-1]:=' ' end;
      end;
    until fi>lformat;
    Writeln(rpt,s);
  end;

procedure MakeReport;
  var	e	: Section;
	s	: string;
	l	: int;
	lnum	: long;
  begin
    InitData;
    sect:=_General; l:=104; lnum:=0;
    while not Eof(frm) do
    begin
      Readln(frm,s); inc(lnum);
      if s[1]<>'~' then Writeln(rpt,s)
      else begin
	s:=Copy(s,2,7); Upper(s);
	if s='FORMAT' then
	  begin Readln(frm,s); format:=s end else
	if s='PRINT' then
	  begin Readln(frm,s); Upper(s); values:=s+',';
		NextObject; FormatPrint end else
	if s='CYCLE' then
	  begin Readln(frm,s); Upper(s); values:=s+',';
		while NextObject do FormatPrint	end
	else begin
	  e:=Section(ItemPos(s,Sections));
	  if e<_Unknown then
	  begin
	    if grmode then begin OutTextXY(MX0+8,l,s+'...'); inc(l,8) end
		      else Writeln(s+'...');
	    sect:=e;
	    pnn:=0; rnn:=0;
	  end
	  else begin
	    Writeln(rpt,'~',s,' -- ERROR: Invalid keyword');
	    if not grmode then
	    begin
	      Writeln('ERROR: Invalid keyword ~',s,' in line ',lnum,' of ',rptname);
	      GPause:=Yes;
	    end;
	    sect:=_General;
	  end;
	end;
      end;
    end;
    if grmode then OutTextXY(MX0,l+16,'Finished.')
	      else Writeln('Finished.'#13#10);
  end;

procedure CreateReport;
  var	sr	: SearchRec;
	i	: int;
  begin
    if grmode then
    begin
      NewMenu; UnLockReservedMemory(MenuSize(MX0+8,96,631,10,Yes));
      i:=0;
      FindFirst('*.frm',Archive,sr);
      while DosError=0 do
      begin
				inc(i);
				AddMenuItem(sr.name,LightGray,No);
				FindNext(sr);
      end;
				SetColor(White);
      if i=0 then
      begin
				OutTextXY(MX0,80,'No FRM files found');
				OutTextXY(MX0,96,'Can''t write report');
				NewMenu; LockReservedMemory;
	Exit;
      end;

      OutTextXY(MX0,80,'Choose report form');
      ChooseMenu(MX0+8,96,MX0+16,631,10,LightGray,Yellow,1,No,Yes,-1);
      NewMenu; LockReservedMemory;
      Clear(MX0,80,639,87);
      if MenuKey=27 then Exit;
      frmname:=MenuString;

      SetColor(White);
      OutTextXY(MX0,80,'Report file name:');
      rptname:=GetStr(MX0,88,18);
      Clear(MX0,80,639,88+7);
      if rptname[0]=#0 then Exit;
    end
    else Writeln(#13#10'VPA Report Generator started');

    Assign(frm,frmname);
    FileMode:=0;
    Reset(frm);
    if IOResult<>0 then
      if grmode then
      begin
	SetColor(LightRed);
	OutTextXY(MX0,80,'Can''t read file');
	OutTextXY(MX0,92,MenuString);
	Exit;
      end
      else begin
	Writeln('ERROR: Can''t read form file ',frmname,#13#10);
	GPause:=Yes;
	Exit;
      end;

    Assign(rpt,addir+rptname);
    Rewrite(rpt);
    if IOResult<>0 then
    begin
      if grmode then
      begin
	SetColor(LightRed);
	OutTextXY(MX0,80,'Can''t write file');
	OutTextXY(MX0,92,rptname);
      end
      else begin
	Writeln('ERROR: Can''t write report file ',rptname,#13#10);
	GPause:=Yes;
      end;
      Close(frm);
      Exit;
    end;

    if grmode then
    begin
      SetColor(White);
      OutTextXY(MX0,80,'Creating report');
      OutTextXY(MX0,88,'file '+rptname+':');
    end
    else Writeln('Creating report ',rptname,' using form ',frmname,'...');
    MakeReport;
    Close(frm);
    Close(rpt);
  end;

  BEGIN
    TPrev:=TSearch(turn-1);
    if TPrev<>nil then
    begin
      LoadTurnData(TPrev);
      if TPrev^.data=nil then TPrev:=nil;
    end;
    grmode:=(frmname[0]=#0);
    if grmode then
    begin
      WriteFreeMem;
      MouseOff;
      MouseDisabled:=True;
      Clear(MX0,72,639,479);
    end;
    CreateReport;
    if grmode then
    begin
      NewMenu;
      MouseDisabled:=False;
      MouseOn;
      ch:=1;		{ don't redraw map }
    end;
  END;

End.
