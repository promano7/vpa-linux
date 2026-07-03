{
*******************************************************************
* MSGREAD.PAS - Import Data from Message to VPA
*
* $Id: msgread.pas,v 1.38 2013/04/21 21:14:41 sfplanets Exp $
*
*******************************************************************
}
{$I switches.inc}
Unit    MsgRead;        (* VPA Incoming Message Data Processing *)
{$V-}

Interface

uses    AuxF;

type    IntArrPtr       = ^IntArr;

const   keepmsg : IntArrPtr = nil;      { #messages,msgno1,msgno2,... }
        MCRC    : IntArrPtr = nil;      { #allocated,#filled,crc1,crc2... }
        VCRC    : IntArrPtr = nil;

procedure ReadMessages (race:byte; lookmsg:boolean);
{Moved here for ExtFeat.}
procedure DecodeObject (var buf; var obj; len:word);

Implementation

uses    VPAData,StrF,Keyboard,Screen,Messages,Config,VPAInit,UtilFmt,ExtFeat
{$IFDEF VPACC},
        PHostM,Hullfunc
{$ENDIF};

const   FirstRun: boolean = Yes;

const   VPA_MSG         : array [1..7] of char = 'VPA.MSG';
        VPAMSG_DAT      : array [1..10] of char = 'VPAMSG.DAT';

type    MsgType = (mData,
                   mEMail,
                   mCommon,mMarker,
                   mOwnMines,mGatherMines,mEnemyMines,mEnemyMinesOutside,
                   mEnemyMinesInside,mSensorSweep,mDistressCall,mSurrender,
                   mExploration,mDarkSense,mSuperSpy,mBioScanner,
                   mIonStorm,mWormhole,
                   mBattle,mPlanetBattle,mExplosion,
                   mHConfig1,mHConfig2,mHConfig3,mHConfig4,mHConfig5,
                   mHConfig6,mHConfig7,mHConfig8,mHConfig9,mHConfig10,
                   mPBP,mPillage,mSpaceDock,mMineExplosion,  {35 + unknwon}
                   mUnknown );  { UNKNOWN must be the last }
const   MsgT1   = mData;
        MsgT2   = mMineExplosion;
        MsgNames: array [1..7,1..50] of char =
                ( 'DATA E-MAIL COMMON MARKER OWNMINES GATHERMINES ENE',
                  'MYMINES ENEMYMINESOUTSIDE ENEMYMINESINSIDE SENSORS',
                  'WEEP DISTRESSCALL SURRENDER EXPLORATION DARKSENSE ',
                  'SUPERSPY BIOSCANNER IONSTORM WORMHOLE BATTLE PLANE',
                  'TBATTLE EXPLOSION HCONFIG1 HCONFIG2 HCONFIG3 HCONF',
                  'IG4 HCONFIG5 HCONFIG6 HCONFIG7 HCONFIG8 HCONFIG9 H',
                  'CONFIG10 PBP PILLAGE SPACEDOCK MINEEXPLOSION      '); {35}
        MsgRType: array [MsgT1..MsgT2] of char = '@!!AMMMMMEEEPPPPIWYZXHHHHHHHHHH!PBU'; {35}
type    MsgFlds = (mfObject,mfData,
                   mfX,mfY,mfId,mfOwner,mfMines,mfWeb,mfGather,mfActivity,mfRadius,
                   mfVoltage,mfHeading,mfWarp,mfGrow,
                   mfMass,mfStable,
                   mfId1,mfId2,mfName1,mfName2,mfName,
                   mfPlanet,mfClimate,mfClans,mfN,mfT,mfD,mfM,mfFunds,mfSupplies,
                   mfFactories,mfDefenses,mfFCode,mfNRace,mfNatives,
                   mfAlchemy,mfColFB,mfRobFB,mfRGA,mfSuperRefit,mfWebs,mfMinRate,
                   mfTaxRate,mfDetectMine,mfNoFuelMove,mfSweepRate,mfWebSweepRate,
                   mfFedCrew,mfESBonus,mfESRate,mfHiss,mfHissEffect,mfGravity,
                   mfMaxIncome,mfCloakFB,mfCloning,mfGambling,mfChunnel,mfTerraform,
                   mfCPDamage,mfOneEngTow,mfHyperDrive,mfGlory,mfLoki,mfAssault,
                   mfAdvRef,mfBioScan,mfRamScoop,mfPBP,mfNClans,mfX2,mfY2,
                   mfAssRate, mfCrystalDesert, mfClimateLimits, mfCDR, mfEatSupplies,
                   mfStructDecay, mfSweepRange, mfWebSweepRange, mfDist, mfSweepDist,
                   mfMinesDest, mfFreeFighter, mfVPAExtra, mfMineDecay, 
                   mfShipName, mfWebDecay); {89}
const   MsgF1   = mfObject;
        MsgF2   = mfWebDecay;
        MsgFNames: array [1..14,1..50] of char =
                ( 'OBJECT DATA X Y ID OWNER MINES WEB GATHER ACTIVITY',
                  ' RADIUS VOLTAGE HEADING WARP GROW MASS STABLE ID1 ',
                  'ID2 NAME1 NAME2 NAME PLANET CLIMATE CLANS N T D M ',
                  'FUNDS SUPPLIES FACTORIES DEFENSES FCODE NRACE NATI',
                  'VES ALCHEMY COLFB ROBFB RGA SUPERREFIT WEBS MINRAT',
                  'E TAXRATE DETECTMINE NOFUELMOVE SWEEPRATE WEBSWEEP',
                  'RATE FEDCREW ESBONUS ESRATE HISS HISSEFFECT GRAVIT',
                  'Y MAXINCOME CLOAKFB CLONING GAMBLING CHUNNEL TERRA',
                  'FORMERS CPDAMAGE ONEENGTOW HYPERDRIVE GLORYDEVICE ',
                  'ANTICLOAK ASSAULT ADVREFINERY BIOSCANNERS RAMSCOOP',
                  ' PBP NCLANS X2 Y2 ASSRATE CRYSTALDESERT CLIMATELIM',
                  'ITS CDR EATSUPPLIES STRUCTDECAY SWEEPRANGE WEBSWEE',
                  'PRANGE DIST SWEEPDIST MINESDEST FREEFIGHTERS VPAEX',
                  'TRA MINEDECAY SHIPNAME WEBDECAY                   ');  {89}
        MsgFl   : array [MsgT1..MsgT2] of set of MsgFlds =
                ( [mfObject,mfData],
                  [],
                  [],[mfX,mfY,mfX2,mfY2,mfRadius],
                  [mfId,mfX,mfY,mfMines,mfWeb],
                  [mfId,mfX,mfY,mfMines,mfGather],
                  [mfId,mfOwner,mfX,mfY,mfMines,mfWeb],
                  [mfId,mfOwner,mfX,mfY,mfDist,mfSweepDist,mfMines,mfWeb],
                  [mfId,mfOwner,mfX,mfY,mfMinesDest,mfMines,mfWeb],
                  [mfId,mfOwner,mfActivity],[mfPlanet,mfOwner],[mfPlanet,mfOwner],
                  [mfPlanet,mfOwner,mfClimate,mfClans],
                  [mfId,mfOwner,mfN,mfT,mfD,mfM,mfFunds],
                  [mfPlanet,mfMines,mfFactories,mfDefenses,mfFCode,mfN,mfT,mfD,mfM,mfFunds,mfSupplies],
                  [mfId,mfNRace,mfNatives,mfClimate],
                  [mfX,mfY,mfRadius,mfVoltage,mfHeading,mfWarp,mfGrow],
                  [mfId,mfX,mfY,mfMass,mfStable],
                  [mfX,mfY,mfId1,mfId2],[mfName1,mfName2],[mfX,mfY,mfName],
                  [mfMines,mfAlchemy,mfColFB,mfRobFB],
                  [mfHiss,mfRGA,mfSuperRefit,mfWebs],
                  [mfCloakFB,mfAssRate],[mfFreeFighter,mfMineDecay,mfWebDecay,mfStructDecay],
                  [mfMinRate,mfEatSupplies,mfDetectMine,mfNoFuelMove],
                  [mfTaxRate,mfESBonus,mfESRate],
                  [mfFedCrew,mfHissEffect,mfSweepRate,mfWebSweepRate,mfSweepRange,mfWebSweepRange,mfTerraform,mfCPDamage],
                  [mfGravity,mfOneEngTow,mfHyperDrive,mfCDR,mfCrystalDesert,mfClimateLimits],
                  [mfMaxIncome,mfCloning,mfGambling,mfChunnel,mfGlory,mfLoki,mfAssault],
                  [mfAdvRef,mfBioScan,mfRamScoop,mfVPAExtra],
                  [mfPBP],
                  [mfId,mfNClans], [mfShipName,mfPlanet],
                  [mfX,mfY,mfX2,mfY2,mfMines] ); {35}
        MsgTChar: array [1..14] of char = '9defilmnpstwyz';
        MsgTLock: array [1..14] of word =
                 (0,LockP,LockS,LockS,LockI,LockM,LockM,0,LockP,LockS,LockP,LockS,LockP,LockP);
        MarkName: array [mrkNone..LastMark] of string[6] =
                ('XXXXXX','FLAG','CIRCLE','CROSS','SQUARE','RHOMBE',
                 'POINT','XXXXXX','XXXXXX','XXXXXX','GRAVE','CACTUS',
                 'FLAG1','FLAG2','FLAG3',
                 'ARROW1','ARROW2','ARROW3','ARROW4',
                 'ARROW5','ARROW6','ARROW7','ARROW8',
                 'NE','TR','DU','MO','SKULL');
        StarBase: string[8] = 'starbase';
        PlanStr : string[6] = 'planet';
        RobStr  : string[6] = 'robbed';
        WebStr  : string[3] = 'WEB';
        UtilStr = 'Data generated by VPA for THost.';

procedure DecodeObject (var buf; var obj; len:word);
  var ps, pd : ^ByteArr;  i : word;  lo, hi : byte;
  begin
    if len<>0 then
    begin
      ps := @buf; pd := @obj;
      for i := 0 to len-1 do
      begin
        lo := byte(ps^[i*2+1] - ord('a'));
        hi := byte(ps^[i*2+2] - ord('a'));
        pd^[i+1] := byte(lo or (hi shl 4));
      end;
    end;
  end;

PROCEDURE ReadMessages (race:byte; lookmsg:boolean);

  var   s       : string[79];
        ls      : byte absolute s;
        s1      : string[79];
        ls1     : byte absolute s1;
        keepstr : string[29];
        fl      : set of MsgFlds;
        mfl     : MsgFlds;
        n       : int;
        k,i     : byte;
        l       : long;
        mm      : Msg;
        t       : text;
        mt      : MsgType;
        keep    : boolean;
        keeplist: ^IntArr;
        klsize  : word;
        vcrlist : ^ByteArr;
        vlsize  : word;
        b       : BRec;
        p       : PRec absolute b;
        h       : SRec absolute b;
        m       : MRec absolute b;
        is      : IRec absolute b;
        w       : WRec absolute b;
        a       : MapMark absolute b;
        e       : EPln;
        x,y     : int;
        radius  : int;
        id      : int;
        owner   : int;
        id1,id2 : int;
        name1,name2     : str20;
        shipname     : str30;
        f,g,v,u : file;
        msgobj,msgvcr   : int;
        o       : ObjType;
        sender  : byte;
        pls     : string[2];
        nmes    : int;
        UTIL_DAT: string[10];
        newpln  : byte;
        msgdate : int;
        x2,y2   : int;
        dist,sdist : int; {distance from mine field outer edge}
        minesDest  : int; {mine units swept}
        units      : long; {mine units exploding}
        writeUtilData : boolean;

  procedure Warning (s:string; cancel:boolean);
    begin
      Writeln(s);
      s:=RaceName[race]; Trim(s);
      Writeln('  (',VPA_MSG,' line ',l,', ',s,' incoming message ',n,')');
      GPause:=Yes;
      if cancel then mt:=mUnknown;
    end;

  function GetLinePos (LineNo:byte; before:boolean) : byte;
    var k       : byte;
        ss      : string[79];
        lss     : byte absolute ss;
    begin
      Parse(s,ss,','); RTrim(ss);
      GetLinePos:=0;
      if ss[1]<>'[' then
      begin
        k:=Value(ss);
        if k=0 then Warning('Syntax error',Yes);
      end
      else begin
        if ss[lss]<>']' then begin Warning('Syntax error',Yes); Exit end;
        Delete(ss,1,1); dec(lss);
        if LineNo=0 then        { searching for line number }
        begin
          k:=IIF(ss='(',1,0);   { !!! exception !!! Don't search for '(' in the 1st line! }
          repeat inc(k) until (k>mm.lines) or (PosInStr(ss,mm.text[k])<>0);
          if k>mm.lines then k:=0;
        end
        else begin                      { searching for pos in line }
          k:=PosInStr(ss,mm.text[LineNo]);
          if (k<>0) and not before then inc(k,lss);
        end;
      end;
      GetLinePos:=k;
    end;

  function GetNumber : long;
    var l       : long;
        a       : int;
    begin
      s:=mm.text[k];
      Delete(s,1,i-1); LTrim(s);
      a:=1;
      while (a<=ls) and (s[a] in ['+','-','0'..'9']) do inc(a);
      ls:=a-1;
      Val(s,l,a);
      if a<>0 then Warning('Actual field value ('+s+') is invalid',Yes);
      GetNumber:=l;
    end;

  function GetName : str20;
    var ss      : str40;        { 40, not 20! }
        j       : int;
    begin
      if ls<>0 then j:=GetLinePos(k,Yes) else j:=0;
      if j=0 then j:=byte(mm.text[k,0])+1;
      ss:=Copy(mm.text[k],i,j-i);
      Trim(ss);
      RPad(ss,20);
      GetName:=ss;
    end;

  function GetShipName : str30;
    var ss      : str60;        { 60, not 30! }
        j       : int;
    begin
      if ls<>0 then j:=GetLinePos(k,Yes) else j:=0;
      if j=0 then j:=byte(mm.text[k,0])+1;
      ss:=Copy(mm.text[k],i,j-i);
      Trim(ss);
      RPad(ss,30);
      GetShipName:=ss;
    end;
    
  function GetRace : int;
    var r       : int;
    begin
      s:=Copy(mm.text[k],i,40);
      LTrim(s);
      r:=1;
      while (r<=11) and (not StrCmp(s,RaceName[r],RLen(RaceName[r]))) do inc(r);
      if r=12 then
      begin
        Warning('Actual race name ("'+s+'") is unknown',No);
        PHOSTget:=PHOSTget or PGraces;
      end;
      GetRace:=r;
    end;

  function GetNRace : int;
    var r       : int;
    begin
      s:=Copy(mm.text[k],i,40);
      LTrim(s);
      if StrCmp(s,'No Native Life',14) then GetNRace:=0
      else begin
        r:=1;
        while (r<=9) and (not StrCmp(s,NatRace[r],RLen(NatRace[r]))) do inc(r);
        if r=10 then Warning('Actual native race name ("'+s+'") is unknown',No);
        GetNRace:=r;
      end;
    end;

  function GetPlanet : int;
    var pn      : int;
    begin
      if msgobj<>0 then begin GetPlanet:=msgobj and LockLo; Exit end;
      s:=Copy(mm.text[k],i,40);
      Trim(s);
      pn:=1;
      while pn<=500 do
      begin
        s1:=PlanName[pn];
        Trim(s1);
        if s=s1 then Break;
        inc(pn);
      end;
      if pn>500 then Warning('Actual planet name ("'+LeftWord(s)+'") is unknown',Yes);
      GetPlanet:=pn;
      msgobj:=pn or LockP;
    end;
      
  function GetWeb : byte;
    begin
      s:=LeftWord(Copy(mm.text[k],i,40));
      Upper(s);
      GetWeb:=byte(s=WebStr);
    end;

  function GetActivity : byte;
    var n       : byte;
    begin
      GetActivity:=0;
      s:=LeftWord(Copy(mm.text[k],i,40));
      Capitalize(s);
      for n:=1 to 5 do
        if s=Industry[n] then begin GetActivity:=n; Exit end;
    end;

  function GetStable : byte;
    var n       : byte;
    begin
      GetStable:=0;
      s:=Copy(mm.text[k],i,40);
      Trim(s);
      for n:=1 to 5 do
        if StrCmp(s,Stability[n],byte(Stability[n,0])) then begin GetStable:=n; Exit end;
    end;

  function GetYN : boolean;
    begin
      s:=LeftWord(Copy(mm.text[k],i,40));
      Upper(s);
      GetYN:=(s='YES') or (s='ON');
    end;

  procedure GetRates (var Rates:IArr11);
    var j,r     : byte;
    begin
      for j:=1 to 11 do
      begin
        s:=mm.text[k];
        if Copy(s,1,2)<>'  ' then Exit;
        s:=Copy(mm.text[k],3,12);
        i:=16;
        for r:=1 to 11 do
          if s=RaceName[r] then begin Rates[r]:=GetNumber; Break end;
        inc(k);
      end;
    end;
    
  procedure GetPBP;
    var j,r     : byte;
    begin
      TEnd^.IsPBP:=Yes;
      FillChar(TEnd^.PBP,SizeOf(PBPList),$FF);
      DataChg:=Yes;
      for j:=1 to 11 do
      begin
        s:=mm.text[k];
        i:=Pos(':',s)+1;
        if i=1 then Exit;
        ls:=i-2; Trim(s);
        if s[ls]='!' then dec(ls);
        if s[ls]='+' then dec(ls);
        RPad(s,12);
        for r:=1 to 11 do
          if s=RaceName[r] then begin TEnd^.PBP[r]:=GetNumber; Break end;
        inc(k);
      end;
    end;

  procedure CheckSender (warning1:boolean);
    var rs      : str20;
    begin
      if warning1 and (not (sender in [1..11])) then Warning('Data sender is unknown',No);
      if not AcceptData[sender] then
      begin
        if sender=0 then rs:='unknown senders'
                    else rs:='race '+NStr(sender);
        Warning('Data rejected: transmissions from '+rs+' are disabled in '+VPADATA_INI,Yes);
      end;
    end;

  procedure GetObject;
    begin
      CheckSender(No);
      s:=Copy(mm.text[k],i,40);
      Trim(s);
      o:=Obj2;
      while (o>oNone) and (not StrCmp(s,ObjName[o],byte(ObjName[o,0]))) do dec(o);
      if o=oNone then
      begin
        Warning('Data rejected: invalid object type',Yes);
        Exit;
      end;
      if o=oMark then Exit;
      Delete(s,1,byte(ObjName[o,0])+1);
      id:=Value(s);
      if (id<=0) or (id>500) then
      begin
        Warning('Data rejected: invalid object ID',Yes);
        Exit;
      end;
    end;

  procedure GetData;
    var dl      : array [1..2] of word;
        ll      : long absolute dl;
        crc     : word;
        buf     : array [0..MaxOSize-1] of word;
        b1      : bptr;
        p1      : pptr absolute b1;
        h1      : sptr absolute b1;
        m1      : mptr absolute b1;
        i       : int;
        p00     : PRec;
    begin
      CheckSender(Yes);
      crc:=0;
      ll:=GetNumber;
      if ll=0 then crc:=1;
      dl[1]:=Max(Min(dl[1],MaxOSize div 2),0);
      for i:=1 to (dl[1]-1) div 20+1 do
        Move(mm.text[k+i,1],buf[(i-1)*20],40);
      for i:=1 to dl[1] do crc:=(crc shl 1)+buf[i-1];
      if crc<>dl[2] then
      begin
        Warning('Data rejected: transmission error',Yes);
        Exit;
      end;
      DecodeObject(buf,b,ObjSize[o]);
      with TEnd^.data^ do
      case o of
        oPlanet : begin
                    DecodeObject(buf[SizeOf(PRec)],e,SizeOf(EPln));
                    if (e.owner=player) or IsData[e.owner] then Exit;
                    if (e.when=0) or (e.when>eplan[id].when) then eplan[id]:=e;
                    if (p.owner=-1) and (e.owner<>-1) then p.owner:=e.owner;
                    DataChg:=Yes;
                    msgobj:=id or LockP;
                    FillChar(p00,SizeOf(PRec),$FF);
                    if not Diff(p,p00,SizeOf(PRec)) then Exit;
                    p1:=planet[id];
                    if (p1<>nil) and ((p1^.owner=player) or IsData[p1^.owner] or (p1^.when>=p.when)) then Exit;
                    if p1=nil then
                      begin CheckMem(SizeOf(PRec)); New(planet[id]) end;
                    planet[id]^:=p;
                  end;
{       oBase   : begin
                    b1:=base[id];
                    if (b1<>nil) and (b1^.owner=player) then Exit;
                    if b1=nil then
                      begin CheckMem(SizeOf(BRec)); New(base[id]) end;
                    base[id]^:=b;
                  end;}
{       oShip   : begin
                    h1:=ship[id];
                    if (h1<>nil) and ((h1^.owner=player) or (h1^.when>=h.when)) then Exit;
                    if h1=nil then
                      begin CheckMem(SizeOf(SRec)); New(ship[id]) end;
                    h.ship_id := id;
                    ship[id]^:=h;
                  end;}
        oMines  : begin
                    m1:=mines[id];
                    if (m1<>nil) and ((m1^.owner=player) or IsData[m1^.owner] or (m1^.when>=m.when)) then Exit;
                    if m1=nil then
                      begin CheckMem(SizeOf(MRec)); New(mines[id]) end;
                    mines[id]^:=m;
                  end;
        oMark   : begin
                    ls:=0;
                    if dl[1]>SizeOf(MapMark) then
                    begin
                      DecodeObject(buf[SizeOf(MapMark)],s[0],1);
                      DecodeObject(buf[SizeOf(MapMark)+1],s[1],ls);
                    end;
                    a.bind:=0;
                    if not (a.mtype in [mrkNone,mrkRCircle..mrkDLine]) then a.text:=0;
                    id:=CreateMark(a);
                    if ls>0 then SetMarkText(id,s);
                  end;
      end;
      DataChg:=Yes;
      msgobj:=id or ObjLock[o];
    end;

  procedure FindVCR (ch:char);  { must be NEVER called with race<>player }
    var vcr     : VCRData;
        i,di    : int;
        n1,n2   : str20;
    begin
      i:=IIF(ch='X',nmsg[m_VCR],1);
      di:=IIF(ch='X',-1,1);
      while (i>0) and (i<=nmsg[m_VCR]) do
      begin
        Seek(v,long(i-1)*SizeOf(VCRData)+2);
        BlockRead(v,vcr,SizeOf(VCRData));
        if ch<>'Y' then
        begin
          n1:=vcr.dd[Left].name;
          StrSubst(n1,#0,' ');
          n2:=vcr.dd[Right].name;
          StrSubst(n2,#0,' ');
        end;
        if (vcrlist^[i]=0) and
          ( (ch='Z') and (n1=name1) and (n2=name2)
          or
            (ch='X') and ((n1=name1) or (n2=name2))
          or
            (ch='Y') and ((vcr.dd[Left].id=id1) and (vcr.dd[Right].id=id2) or
                          (vcr.dd[Left].id=id2) and (vcr.dd[Right].id=id1)) ) then
        begin
          if ch='Z' then
          begin
            id1:=vcr.dd[Left].id;
            id2:=vcr.dd[Right].id;
            {x:=Planets[id2].x;
            y:=Planets[id2].y;}
            msgobj:=id2 or LockP;
          end;
          msgvcr:=i;
          vcrlist^[i]:=1;
          Break;
        end;
        inc(i,di);
      end;
    end;

  procedure KeepMark;
    var mrk     : MarkType;
        a       : MapMark;
        tt,nn   : word;
    begin
      if (x=0) or (y=0) then
      begin
        if msgobj=0 then Exit;
        tt:=msgobj and LockHi;
        nn:=msgobj and LockLo;
        with TEnd^.data^ do
        case tt of
          LockP : begin x:=xyplan[nn,1]; y:=xyplan[nn,2] end;
          LockS : if ship[nn]<>nil then begin x:=ship[nn]^.x; y:=ship[nn]^.y end;
          LockM : if mines[nn]<>nil then begin x:=mines[nn]^.x; y:=mines[nn]^.y end;
          LockI : if ion[nn]<>nil then begin x:=ion[nn]^.x; y:=ion[nn]^.y end;
        end;
      end;
      if (x<=0) or (y<=0) then Exit;
      Parse(keepstr,s1,' '#9); Upper(s1);
      if ls1=0 then Exit;
      FillChar(a,SizeOf(a),0);
      a.mtype:=mrkCross;
      a.x:=x; a.y:=y;
      a.bind:=keeplist^[1];
      if s1='LINE' then a.mtype:=mrkLine else
      if s1='DLINE' then a.mtype:=mrkDLine else
      for mrk:=mrkNone to LastMark do
        if s1=MarkName[mrk] then begin a.mtype:=mrk; Break end;
      if byte(keepstr[0])>0 then a.color:=Value(keepstr);
      if not (a.color in [1..15]) then a.color:=13;
      if (radius > 0) and (a.mtype=mrkCircle) then begin
        a.radius := radius;
        a.mtype := mrkRCircle;
      end;
      if (a.mtype=mrkLine) or (a.mtype=mrkDLine) then begin
        if (x2<0) or (y2<0) then begin
          Warning('LINE marker must define X2 and Y2 field', false);
          Exit;
        end;
        a.dx := x - x2;
        a.dy := y - y2;
      end;
      nn:=CreateMark(a) or LockA;
      DataChg:=Yes;
      if msgobj=0 then msgobj:=nn;
    end;

  function CheckCRC (crc:int; var ACRC:IntArrPtr) : boolean;
    var i       : int;
        p       : pointer;
    begin
      CheckCRC:=No;
      for i:=3 to ACRC^[2] do
        if crc=ACRC^[i] then Exit;
      CheckCRC:=Yes;
      if ACRC^[2]=ACRC^[1] then
        if MaxAvail>=(ACRC^[1]+10)*2+16 then
        begin
          GetMem(p,(ACRC^[1]+10)*2);
          Move(ACRC^,p^,ACRC^[1]*2);
          FreeMem(ACRC,ACRC^[1]*2);
          ACRC:=p;
          inc(ACRC^[1],10);
        end
        else dec(ACRC^[2]);
      inc(ACRC^[2]);
      ACRC^[ACRC^[2]]:=crc;
    end;

  function CheckMessageCRC : boolean;
    var i,j,crc : int;
    begin
      crc:=0;
      for i:=4 to mm.lines do
      begin
        s:=mm.text[i];
        for j:=1 to ls do
        begin
          crc := int((word(crc) shl 1) or (word(crc) shr 15));   { rol 16-bit }
          inc(crc,byte(s[j]));
        end;
      end;
      CheckMessageCRC:=CheckCRC(crc,MCRC);
    end;

  function CheckVcrCRC (var vcr:VCRData) : boolean;
    const       VCRSize = SizeOf(VCRData);
    var         crc     : int;
      pb      : ^ByteArr;  w, bi : word;
    begin
      w := 0;  pb := @vcr;
      for bi := 1 to VCRSize do
      begin
        w := word((w shl 1) or (w shr 15));   { rol 16-bit }
        w := word(w + pb^[bi]);
      end;
      crc := int(w);
      CheckVcrCRC:=CheckCRC(crc,VCRC);
    end;

  procedure MergeMessage;       { add mm to player's MDATA.DAT }
    var f       : file;
        i,n     : int;
        fs,fp,fp0,fp1   : long;
        ih      : record
                    offs        : long;         { offs = offset + 1 }
                    len         : word;
                  end;
        mb      : MsgBuf;
    begin
      OpenRW(f,'MDATA'+plstr+'.DAT',Yes);
      fs:=FileSize(f);
      BlockRead(f,n,2);
      inc(n);
      Seek(f,0);
      BlockWrite(f,n,2);
      fp:=2+long(n)*SizeOf(ih);
      for i:=1 to n-1 do        { relocate messages if needed }
      begin
        BlockRead(f,ih,SizeOf(ih));
        if ih.offs-1<fp then
        begin
          fp0:=FilePos(f);
          fp1:=ih.offs-1;
          Seek(f,fp0-SizeOf(ih));
          ih.offs:=fs+1;
          ih.len:=Min(ih.len,SizeOf(mb));
          BlockWrite(f,ih,SizeOf(ih));
          Seek(f,fp1);
          BlockRead(f,mb,ih.len);
          Seek(f,fs);
          BlockWrite(f,mb,ih.len);
          inc(fs,ih.len);
          Seek(f,fp0);
        end;
      end;
      WriteMessage(f,n,mm,0,fs,Yes,0);
      CloseData(f);
      DataChg:=Yes;
    end;

  procedure MergeVCRs;          { add race's VCRs to player's VCR.DAT }
    var f,v             : file;
        i,j,n,nv,nv1    : int;
        vcr,pvcr        : VCRData;
        pvc             : boolean;
        last10          : array [1..10] of byte;
    begin
      if vcrn[race]=0 then Exit;
      OpenRW(f,'VCR'+pls+'.DAT',Yes);
      OpenRW(v,'VCR'+plstr+'.DAT',Yes);
      BlockRead(f,n,2);
      BlockRead(v,nv,2);
      Seek(v,long(nv)*SizeOf(vcr)+2);
      BlockRead(v,last10,10);
      pvc:=No;
      if nv>1 then
      begin
        Seek(v,long(nv-1)*SizeOf(vcr)+2);
        BlockRead(v,pvcr,SizeOf(vcr));
        if word(pvcr.K0+pvcr.int0)=48879 then pvc:=Yes;
      end;
      if pvc then begin dec(n); dec(nv) end;
      nv1:=nv;
      for i:=1 to n do
      begin
        BlockRead(f,vcr,SizeOf(vcr));
        if CheckVcrCRC(vcr) then
        begin
          Seek(v,long(nv1)*SizeOf(vcr)+2);
          BlockWrite(v,vcr,SizeOf(vcr));
          inc(nv1);
        end;
      end;
      if nv1<>nv then
      begin
        Seek(v,long(nv1)*SizeOf(vcr)+2);
        if pvc then
        begin
          BlockWrite(v,pvcr,SizeOf(vcr));
          inc(nv1);
        end;
        BlockWrite(v,last10,10);
        Seek(v,0);
        BlockWrite(v,nv1,2);
      end;
      CloseData(f);
      CloseData(v);
    end;

  procedure WriteHConfigTxt;
    var t       : text;
        i       : int;
    begin
      if race<>player then Exit;
      Assign(t,addir+'HCONFIG.TXT');
      if mt=mHConfig1 then
      begin
        Writeln('Writing ',addir,'HCONFIG.TXT...');
        Rewrite(t);
      end
      else Append(t);
      if IOResult<>0 then Exit;
      for i:=IIF(mt=mHConfig1,5,2) to mm.lines do Writeln(t,mm.text[i]);
      Close(t);
    end;

  function PurgeUtilData(force: boolean): boolean;
    var uh      : record
                    rtype       : int;
                    rsize       : word;
                  end;
        util_buf: array[1..100] of byte;
        util_ct : Util13Control ABSOLUTE util_buf;
        rcount  : word;
        newpos  : longint;
        byVpa   : boolean;
        current : boolean;
    begin
      PurgeUtilData:=false;
      if (PHOST) then Exit; {PHOST does not need this}
      UTIL_DAT:='UTIL'+pls+'.DAT';
      if Exists(UTIL_DAT) then begin
        byVpa:=false;
        {utilX.dat exists. Check if it was created by us so we may delete it.}
        if OpenRW(u,UTIL_DAT,No) then begin
          while (IOResult=0) and (not Eof(u)) do begin
            BlockRead(u,uh,SizeOf(uh),rcount);
            if rcount < SizeOf(uh) then Break;
            newpos := filepos(u) + uh.rsize;
            if (uh.rtype = 13) then begin
              BlockRead(u,util_ct,Sizeof(util_ct));
              if (util_ct.major=0) or (util_ct.minor=0) or (util_ct.game=UtilStr) then
                byVpa:=true;
              current:=util_ct.turn=today;
              Break;
            end;
            seek(u, newpos);
          end;
          CloseData(u);
        end;
        {Delete util.dat if it was created by VPA.}
        if (byVpa and (force or not current)) then begin
          Erase(u);
          PurgeUtilData:=true;
        end;
      end else
        PurgeUtilData:=true;
    end;

  procedure PrepareUtilData;
    var uh      : record
                    rtype       : int;
                    rsize       : word;
                  end;
        util_buf: array[1..100] of byte;
        util_ct : Util13Control ABSOLUTE util_buf;
        rcount  : word;
        newpos  : longint;
    begin
      writeUtilData:=false;
      if (PHOST) then Exit; {PHOST does not need this}
      UTIL_DAT:='UTIL'+pls+'.DAT';
      if (PurgeUtilData(true)) then begin
        if OpenW(u,UTIL_DAT,No) then begin
          {OpenW(u,UTIL_DAT,Yes);}
          Writeln('Creating ',addir,UTIL_DAT,'...');
          {Write header.}
          FillChar(util_ct, Sizeof(util_ct), 0);
          util_ct.timestamp:=Stamp;
          util_ct.turn:=today;
          util_ct.player:=race;
          util_ct.major:=0;
          util_ct.minor:=0;
          util_ct.game:=UtilStr;
          uh.rtype:=13; uh.rsize:=SizeOf(util_ct);
          BlockWrite(u,uh,SizeOf(uh));
          BlockWrite(u,util_ct,SizeOf(util_ct));
          writeUtilData:=true;
        end;
      end else
        Writeln('Skipping creation of ',addir,UTIL_DAT,'.');
    end;

  procedure FinishUtilData;
    var uh      : record
                    rtype       : int;
                    rsize       : word;
                  end;
        util_buf: array[1..100] of byte;
        util_ct : Util13Control ABSOLUTE util_buf;
    begin
      if (writeUtilData) then begin
        {close file}
        uh.rtype:=30; uh.rsize:=0;
        BlockWrite(u,uh,SizeOf(uh));
        CloseData(u);
      end;
    end;

  { Write changes to util.dat for THost. }
  procedure StoreUtilData;
    var uh      : record
                    rtype       : int;
                    rsize       : word;
                  end;
        util_buf : array[1..100] of byte;
        util_mexp : Util29MinesExplode ABSOLUTE util_buf;
    procedure StoreRecord(rtype: int; rsize: word);
      begin
        uh.rtype:=rtype; uh.rsize:=rsize;
        BlockWrite(u,uh,SizeOf(uh));
        BlockWrite(u,util_buf,rsize);
      end;
    begin
      if (not writeUtilData) then Exit;
      FillChar(util_buf, Sizeof(util_buf), 0);
      case MsgRType[mt] of
        'U'     : if (mt=mMineExplosion) then begin
                    util_mexp.x1 := x;
                    util_mexp.y1 := y;
                    util_mexp.x2 := x2;
                    util_mexp.y2 := y2;
                    util_mexp.units := units;
                    StoreRecord( 29, SizeOf(util_mexp) );
                  end;
      end;
    end;

  procedure InitRec;
    begin
      with TEnd^.data^ do
      case MsgRType[mt] of
        'P'     : if (id>=1) and (id<=500) then
                  begin
                    if planet[id]<>nil
                    then p:=planet[id]^
                    else FillChar(p,SizeOf(p),#$FF);
                    e:=eplan[id];
                    newpln:=newplan[id];
                  end;
        'M'     : if (id>=1) and (id<=500) then
                  begin
                    if mines[id]<>nil then m:=mines[id]^
                    else FillChar(m,SizeOf(m),#$FF);
                    owner:=race;
                  end;
        'I'     : if msgobj<>0 then
                  begin
                    id:=msgobj and LockLo;
                    if (id>=1) and (id<=50) then
                      if ion[id]<>nil then is:=ion[id]^
                                      else FillChar(is,SizeOf(is),#$FF);
                  end;
        'E'     : if (id>=1) and (id<=500) then e:=eplan[id];
      end;
    end;

  procedure InitRecU(amt:MsgType; aid:int);
    begin
      mt := amt;
      id := aid;
      InitRec;
    end;

  { write back changes (called via StoreRec or StoreRecU) }
  procedure StoreRecGen(from_msg : boolean);
    var sb      : boolean;
        mexptr  : MineExplosionRecordPtr;
        i       : int;
    begin
      with TEnd^.data^ do
      case MsgRType[mt] of
        'P'     : if (id>=1) and (id<=500) and (owner<>player) and (not IsData[owner]) and
                     ((p.when<>today) or ((p.owner<>player) and not IsData[p.owner])) then
                  begin
                    newplan[id]:=newpln;
                    p.when:=msgdate;
                    if p.when0=-1 then p.when0:=p.when;
                    if newpln and NP_MFD_FCode=0 then p.fcode:=#$FF#$FF#$FF;
                    if (owner=-1) and (newpln and NP_Owner<>0) and
                       not (eplan[id].owner in [0,255]) then owner:=eplan[id].owner;
                    if (Owner <> -1) then begin
                      p.owner:=owner;
                      eplan[id].owner:=owner;
                    end;
                    if planet[id]=nil then
                      begin CheckMem(SizeOf(PRec)); New(planet[id]) end;
                    planet[id]^:=p;
                    if from_msg and (mt in [mExploration,mDarkSense]) then
                    begin
                      sb:=PosInStr(StarBase,mm.text[mm.lines])<>0;
                      eplan[id].activity:=(eplan[id].activity and ($FF-EP_Base-EP_NoBase)) or IIF(sb,EP_Base,EP_NoBase);
                      newplan[id]:=newplan[id] or NP_Base;
                    end;
                    msgobj:=id or LockP;
                    DataChg:=Yes;
                  end;
        'M'     : if (id>=1) and (id<=500) then
                  begin
                    {if m.mines=0 then
                    begin
                      if mines[id]<>nil then Dispose(mines[id]);
                    end
                    else begin}
                      m.x:=x; m.y:=y;
                      m.owner:=owner;
                      m.when:=msgdate;
                      if (not PHOST) then begin
                        {check for web mines by distance}
                        if (dist>=0) and (sdist>=0) then
                          if (SweepRange <> WebSweepRange) then
                          begin
                            if (dist-sdist = WebSweepRange) then
                              m.web := m.web or 1;
                          end;
                        {check for web mines by number of units swept}
                        {unfortunately, we don't have the id of the ship that swept...}
                        if (minesDest>=0) and (m.units > 0) then
                          if (minesDest mod SweepRate > 0) and (minesDest mod WebSweepRate = 0) then
                            m.web := m.web or 1;
                      end;
                      if mines[id]=nil then
                        begin CheckMem(SizeOf(MRec)); New(mines[id]) end;
                      mines[id]^:=m;
                      msgobj:=id or LockM;
                    {end;}
                    DataChg:=Yes;
                  end;
        'I'     : if (id>=1) and (id<=50) then
                  begin
                    is.x:=x; is.y:=y;
                    if ion[id]=nil then
                      begin CheckMem(SizeOf(IRec)); New(ion[id]) end;
                    ion[id]^:=is;
                    msgobj:=id or LockI;
                    DataChg:=Yes;
                  end;
        'W'     : if (id>=0) and (id<=199) then
                  begin
                    w.when:=msgdate;
                    w.x:=x; w.y:=y;
                    if worm[id]=nil then
                      begin CheckMem(SizeOf(WRec)); New(worm[id]) end;
                    worm[id]^:=w;
                    msgobj:=id or LockW;
                    DataChg:=Yes;
                  end;
        'E'     : if (id>=1) and (id<=500) and
                     (e.owner<>player) and (not IsData[e.owner]) and
                     (owner<>player) and (not IsData[owner]) then
                  begin
                    if mt=mSensorSweep then e.when:=msgdate;
                    if owner<>-1 then
                    begin
                      e.owner:=owner;
                      newplan[id]:=newplan[id] or NP_Owner;
                    end;
                    if mt=mSurrender then
                    begin
                      e.activity:=(e.activity and $FF-EP_NoBase) or EP_Base;
                      newplan[id]:=newplan[id] or NP_Base;
                    end;
                    eplan[id]:=e;
                    if planet[id]<>nil then planet[id]^.owner:=owner;
                    msgobj:=id or LockP;
                    DataChg:=Yes;
                  end;
        'B'     : begin                       { Store building bases, Quapla }
                      DataChg:=Yes;
                      CutShipNames(ShipName);                   {ShipName:= Built Ship }                      
                      for i := 1 to 105 do 
                          if (Hulls[i].name=ShipName) then break; {i:= Ship ID}
                      PutBuildQ(id,i);                 { Planet id built ship i }
                      if (planet[id]^.fcode[1]='P') and (planet[id]^.fcode[2]='B') and
                      (planet[id]^.fcode[3] in ['1','2','3','4','5','6','7','8','9']) then
                      begin                            { FCode = PBx }
                        i := id;
                        repeat
                          if i=1 then i:=500 else dec(i);
                          if base[i]<>NIL then begin
                            if i=BuildQ^[0] then PutBuildQ(0,id); { possibly built inline the Q, more checks necessary}
                          end;
                        until (i=id);
                      end else PutBuildQ(0,id);                 { Q-Build: Base-ID stored as last}
{                      writeln('New ship ',ShipName,'(',i,') built at: Base No. ',id);}
                  end;
        { the following three must not happen with from_msg = false }
        'Y','Z','X'     : if race=player then FindVCR(MsgRType[mt]);
        'H'     : begin HConfChg:=Yes; WriteHConfigTxt end;
        '!'     : if RWMode and (mt=mEMail) and (race<>player) and CheckMessageCRC then MergeMessage;
        'U'     : if (mt=mMineExplosion) then
                  begin
                    {writeln('MineExplosion',x);}
                    mexptr:=MineExplosions;
                    while (mexptr^.next<>NIL) do
                      mexptr:=mexptr^.next;
                    if (mexptr^.next=NIL) then begin
                       mexptr^.x1:=x;
                       mexptr^.y1:=y;
                       mexptr^.mid1:=0;
                       mexptr^.x2:=x2;
                       mexptr^.y2:=y2;
                       mexptr^.mid2:=0;
                       mexptr^.units:=units;
                       new(mexptr^.next);
                       mexptr:=mexptr^.next;
                       mexptr^.next:=NIL;
                    end;
                  end;
(*      Add here code to store mineexplosions in memory and permanently
        as messages are not read on each start of vpa. Idea: create an own
        utilx.dat for games without utilx.dat from host? *)
      end;
    end;

  { write back changes after parsing util.dat }
  procedure StoreRecU;
    begin
      StoreRecGen(false);
    end;

  { write back changes after parsing a message }
  procedure StoreRec;
    begin
      StoreRecGen(true);
      if (writeUtilData) then
        StoreUtilData;
      if race=player then
      begin
        if keep then
        begin
          inc(keeplist^[1]);
          keeplist^[1+keeplist^[1]]:=n;
          KeepMark;
        end;
      end;
    end;

  procedure CheckMsgObj;                {    v-race        }
    var t       : byte;                 { (-p6409)         }
        w,lw    : word;                 {   ^ ^^^object id }
        h       : sptr;                 { type             }
        m       : mptr;
    begin
      msgobj:=0;
      if (mm.text[1,1]<>'(') or (not (mm.text[1,2] in ['-','o'])) or (mm.text[1,8]<>')') then Exit;
      t:=Pos(mm.text[1,3],MsgTChar);
      if t=0 then Exit;
      w:=Value(Copy(mm.text[1],5,3));
      if w=0 then Exit;
      lw:=MsgTLock[t];
      if lw=0 then
        if MsgTChar[t]='9' then lw:=IIF(PosInStr(RobStr,mm.text[4])=0,LockP,LockS)
                           else lw:=IIF(PosInStr(PlanStr,mm.text[2])=0,LockS,LockP);
      msgobj:=w or lw;
      if lw=LockS then
      begin
        h:=TEnd^.data^.ship[w];
        if (h=nil) or (h^.when<>today) then msgobj:=0;
      end else
      if lw=LockM then
      begin
        m:=TEnd^.data^.mines[w];
        if (m=nil) or (m^.when<>today) then msgobj:=0;
      end;
    end;

  function WriteFile (fn:filename; fsize:word; txt:boolean) : boolean;
    var pf      : file;
        pp      : ^ByteArr;
        pw,pw1  : word;
        i,i0    : word;
        crlf    : word;
    begin
      WriteFile:=No;
      i:=Pos('.',fn);
      if i<>0 then
      begin
        s:=fn;
        Delete(s,1,i);
        if (ls>0) and (Pos(s,'EXE,COM,BAT,OVR,SYS')<>0) then
        begin
          Writeln(#13#10#7'                     !!! SECURITY VIOLATION !!!'#7#13#10+
                  #13#10'An attempt has been made to transmit an executable file via '+UTIL_DAT+'.'+
                  #13#10'This might cause a security breach, virus infection or data destruction.',
                  #13#10'The attempt is denied by VPA. The name of the file was "'+fn+'".'+
                  #13#10'Please report this to your game master immediately!');
          GPause:=Yes;
          Exit;
        end;
      end;
      Writeln('Writing ',addir,fn,'...');
      if not OpenW(pf,fn,No) then
      begin
        GPause:=Yes;
        Exit;
      end;
      crlf:=$0A0D;
      if MaxAvail>long(fsize) then pw:=fsize else pw:=MaxAvail;
      GetMem(pp,pw);
      while fsize>0 do
      begin
        if pw<=fsize then pw1:=pw else pw1:=fsize;
        BlockRead(f,pp^,pw1);
        if not txt then BlockWrite(pf,pp^,pw1)
        else begin
          i:=0;
          repeat
            i0:=i;
            repeat inc(i) until ((i>pw1) or (pp^[i]=10));
            if i<=pw1 then
            begin
              BlockWrite(pf,pp^[i0+1],i-i0-1);
              BlockWrite(pf,crlf,2);
            end;
          until i>pw1;
        end;
        dec(fsize,pw1);
      end;
      FreeMem(pp,pw);
      CloseData(pf);
      WriteFile:=Yes;
    end;

  procedure ReadUtilData;
    var uh      : record
                    rtype       : int;
                    rsize       : word;
                  end;
        ht      : STRec;
        pt      : record
                    id          : int;
                    owner       : int;
                    temp        : int;
                    Nrace       : int;
                    Ngovt       : int;
                    natives     : long;
                    N,T,D,M     : long;
                    colonists   : long;
                    supplies    : long;
                    funds       : long;
                  end;
        wr      : record
                    x,y         : int;
                    mass        : int;
                    stable      : int;
                    id          : int;
                  end;
        fh      : record
                    name        : filename;
                    flag        : byte;
                  end;
        lfhn    : byte absolute fh;
        crec    : record
                    stamp       : TimeStamp;
                    turn        : int;
                    race        : int;
                  end;
        util_rc : record
                    sid         : int;
                    flag        : int;
                  end;
        util_exp_entry : record  id, value : int; end;
        abend   : boolean;
        newpos  : longint;
        rcount  : word;
        i,j,k   : int;
        util_buf : array[1..100] of byte;       { allocate some memory }
        util_mf : Util0Minefield ABSOLUTE util_buf;
        util_ds : Util3DarkSense ABSOLUTE util_buf;
        util_ss : Util4SuperSpy  ABSOLUTE util_buf;
        util_ex : Util5Explore   ABSOLUTE util_buf;
        util_scan : Util6Sensor  ABSOLUTE util_buf;
        util_all  : Util22Alliance ABSOLUTE util_buf;
        util_bio  : Util23Bioscan ABSOLUTE util_buf;
        util_mexp : Util29MinesExplode ABSOLUTE util_buf;
        util_pill : Util32Pillage ABSOLUTE util_buf;
        util_batt : Util7Battle  ABSOLUTE util_buf;
        util_bq   : Util39QueueEntry ABSOLUTE util_buf;
        util_drain: Util40WebDrain ABSOLUTE util_buf;
        util_exp  : Util49ShipScore ABSOLUTE util_buf;
        util_sdef : Util57SpecialDef ABSOLUTE util_buf;
        mexptr    : MineExplosionRecordPtr;
    begin
      UTIL_DAT:='UTIL'+pls+'.DAT';
      if not OpenRW(f,UTIL_DAT,No) then Exit;
      Writeln('Reading ',addir,UTIL_DAT,'...');
      abend:=No;
      msgdate:=today;
      while (not abend) and (IOResult=0) and (not Eof(f)) do
      begin
        BlockRead(f,uh,SizeOf(uh),rcount);
        if rcount < SizeOf(uh) Then Break;
        newpos := filepos(f) + uh.rsize;
        msgvcr:=0;
        id:=0; owner:=-1;
        x:=0; y:=0; x2:=-1; y2:=-1; radius:=-1;
        o:=oNone;
        case uh.rtype of
          0     : begin                                 { minefield }
                    BlockRead(f,util_mf,Sizeof(util_mf));
                    InitRecU(mEnemyMines, util_mf.id);
                    x := util_mf.x;
                    y := util_mf.y;
                    owner := util_mf.owner;
                    m.web := util_mf.web;
                    m.units := util_mf.units;
                    StoreRecU;
                  end;
          { 1 - Explosion (can this be done?) }
          { 2 - Mine Hit (not processed by vpa.msg) }
          3     : begin                                 { dark sense }
                    BlockRead(f, util_ds, Sizeof(util_ds));
                    InitRecU(mDarkSense, util_ds.pid);
                    owner := util_ds.owner;
                    p.N := util_ds.n; p.Nc := -1;
                    p.T := util_ds.t; p.Tc := -1;
                    p.D := util_ds.d; p.Dc := -1;
                    p.M := util_ds.m; p.Mc := -1;
                    p.funds := util_ds.mc;
                    newpln := newpln OR (NP_Owner OR NP_NTDM_Funds OR NP_Base);
                    with TEnd^.data^ do
                    begin
                       if util_ds.base <> 0 then eplan[id].activity:=eplan[id].activity OR EP_Base
                       else eplan[id].activity:= eplan[id].activity OR EP_NoBase;
                    end;
                    StoreRecU;
                  end;
          4     : begin                                 { super spy }
                    BlockRead(f, util_ss, Sizeof(util_ss));
                    InitRecU(mSuperSpy, util_ss.pid);
                    p.mines := util_ss.mines;
                    p.factories := util_ss.factories;
                    p.defense := util_ss.defense;
                    Move(util_ss.fc, p.fcode, 3);
                    p.N := util_ss.n; p.Nc := -1;
                    p.T := util_ss.t; p.Tc := -1;
                    p.D := util_ss.d; p.Dc := -1;
                    p.M := util_ss.m; p.Mc := -1;
                    p.funds := util_ss.mc;
                    p.supplies := util_ss.supplies;
                    newpln := newpln OR (NP_Owner OR NP_NTDM_Funds OR NP_MFD_FCode OR NP_Supplies);
                    StoreRecU;
                  end;
          5     : begin                                 { planet visited }
                    BlockRead(f, util_ex, Sizeof(util_ex));
                    InitRecU(mExploration, util_ex.pid);
                    p.climate := 100 - util_ex.temp;
                    p.colonists := util_ex.colonists DIV 100;
                    owner := util_ex.owner;
                    newpln := newpln OR (NP_Climate OR NP_CPop);
                    { FIXME: update starbase status. This is pretty hairy. }
                    StoreRecU;
                  end;
          6     : begin
                    BlockRead(f, util_scan, Sizeof(util_scan));
                    InitRecU(mSensorSweep, util_scan.pid);
                    owner := util_scan.owner;
                    if (util_scan.activity>=0) and (util_scan.activity<5) then
                     e.activity:=(e.activity and (EP_Base or EP_NoBase)) or (util_scan.activity+1);
                    StoreRecU;
                  end;
          { 7 - VCR }
          7     : begin
                   {$IFDEF VPACC}
                    if word(uh.rsize) > Sizeof(util_batt) then uh.rsize := Sizeof(util_batt);
                    BlockRead(f, util_batt, uh.rsize);
                    AddBattleResult(util_batt, uh.rsize);
                   {$ENDIF}
                  end;
          { 8 - Meteorite. Not handled by VPA.MSG }
          { 9 - Giant meteor. VPA.MSG generates a marker. }
          10    : begin                                 { ship target }
                    BlockRead(f,id,2);
                    BlockRead(f,ht,SizeOf(ht));
                    GetShipTarget(id,h,ht);
                  end;
          11    : begin                                 { base target }
                    BlockRead(f,id,2);
                    BlockRead(f,owner,2);
                    if (owner<>player) and (not IsData[owner]) then
                    with TEnd^.data^ do
                    begin
                      eplan[id].owner:=owner;
                      eplan[id].activity:=EP_Base;
                    end;
                  end;
          12    : begin                                 { planet target }
                    BlockRead(f,pt,SizeOf(pt));
                    if (pt.owner<>player) and (not IsData[pt.owner]) then
                    with TEnd^.data^ do
                    begin
                      FillChar(p,SizeOf(p),#$FF);
                      p.when:=today;
                      p.when0:=today;
                      p.owner:=pt.owner;
                      p.climate:=100-pt.temp;
                      p.Nrace:=pt.Nrace;
                      p.Ngovt:=pt.Ngovt;
                      p.natives:=pt.natives div 100;
                      p.N:=pt.N; p.Nc:=-2;
                      p.T:=pt.T; p.Tc:=-2;
                      p.D:=pt.D; p.Dc:=-2;
                      p.M:=pt.M; p.Mc:=-2;
                      p.colonists:=pt.colonists div 100;
                      p.supplies:=pt.supplies;
                      p.funds:=pt.funds;
                      if (planet[pt.id]<>nil) then with planet[pt.id]^ do begin
                        if Nc>=0 then p.Nc:=Nc;
                        if Tc>=0 then p.Tc:=Tc;
                        if Dc>=0 then p.Dc:=Dc;
                        if Mc>=0 then p.Mc:=Mc;
                        if Nm>=0 then p.Nm:=Nm;
                        if Tm>=0 then p.Tm:=Tm;
                        if Dm>=0 then p.Dm:=Dm;
                        if Mm>=0 then p.Mm:=Mm;
                      end;
                      if planet[pt.id]=nil then
                        begin CheckMem(SizeOf(PRec)); New(planet[pt.id]) end;
                      planet[pt.id]^:=p;
                      eplan[pt.id].owner:=pt.owner;
                      eplan[pt.id].activity:=0;
                      DataChg:=Yes;
                    end;
                  end;
          13    : begin
                    BlockRead(f,crec,SizeOf(crec));
                    if (crec.race<>race) or (crec.turn<>today) or
                       (crec.stamp<>Stamp) then
                    begin
                      abend:=Yes;
                      GPause:=true;
                      if (crec.turn<>today) then
                        Writeln(#9'File is from a different turn (', crec.turn, ') - skipping it...')
                      else if (crec.race<>race) then
                        Writeln(#9'File is from a different race (', crec.race, ') - skipping it...')
                      else
                        Writeln(#9'File has wrong time-stamp (', crec.stamp, ') - skipping it...');
                    end;
                    {else Seek(f,FilePos(f)+uh.rsize-SizeOf(crec));}
                  end;
{         14    : begin
                    BlockRead(f,wr,SizeOf(wr));
                    w.when:=today;
                    w.x:=wr.x;
                    w.y:=wr.y;
                    w.mass:=wr.mass;
                    w.stable:=wr.stable;
                    with TEnd^.data^ do
                    begin
                      if worm[wr.id]=nil then
                        begin CheckMem(SizeOf(WRec)); New(worm[wr.id]) end;
                      worm[wr.id]^:=w;
                    end;
                    DataChg:=Yes;
                  end;}
          22    : begin                                 { Alliance }
                    BlockRead(f,util_all,Sizeof(util_all));
                    for i:=0 to 4 do begin
                      k:=32+(1 shl i);
                      for j:=1 to 11 do begin
                        if ((util_all[j] and k)=k) then alliance[i,race,j]:=2;
                        if ((util_all[j+11] and k)=k) then alliance[i,j,race]:=2;
                        if ((util_all[j+22] and k)=k) then alliance[i,race,j]:=1;
                        if ((util_all[j+33] and k)=k) then alliance[i,j,race]:=1;
                      end;
                    end;
                  end;
          23    : begin                                 { bioscan }
                    BlockRead(f,util_bio,Sizeof(util_bio));
                    InitRecU(mBioScanner, util_bio.pid);
                    p.nrace := util_bio.ntype;
                    if p.nrace<>0 then p.natives:=util_bio.npop div 100;
                    p.climate := 100-util_bio.temp;
                    newpln := newpln or (NP_NRace_NPop or NP_Climate);
                    StoreRecU;
                  end;
          27    : if lookmsg and (race=player) and WriteFile(PCONFIG_SRC,uh.rsize,No) then
                    ReadConfigFile(addir+PCONFIG_SRC,sPHOST);
          29    : begin                                     { Minefield Explosions }
                    BlockRead(f,util_mexp,Sizeof(util_mexp));
                    mexptr:=MineExplosions;
                    while (mexptr^.next<>NIL) do begin
                       if (mexptr^.mid1=util_mexp.mid1) and
                          (mexptr^.mid2=util_mexp.mid2) and
                          (util_mexp.mid1>0) then break;
                       mexptr:=mexptr^.next;
                    end;
                    if (mexptr^.next=NIL) then begin
                       mexptr^.x1:=util_mexp.x1;
                       mexptr^.y1:=util_mexp.y1;
                       mexptr^.mid1:=util_mexp.mid1;
                       mexptr^.x2:=util_mexp.x2;
                       mexptr^.y2:=util_mexp.y2;
                       mexptr^.mid2:=util_mexp.mid2;
                       mexptr^.units:=util_mexp.units;
                       new(mexptr^.next);
                       mexptr:=mexptr^.next;
                       mexptr^.next:=NIL;
                    end;
                  end;
          32    : begin                                     { pillage }
                    BlockRead(f,util_pill,Sizeof(util_pill));
                    InitRecU(mPillage, util_pill.pid);
                    p.natives:=util_pill.natives;
                    if (p.natives=0) then p.nrace:=0;
                    if (p.nrace<0) then p.nrace:=10;
                    newpln := newpln or NP_NRace_NPop;
                    StoreRecU;
                  end;
          34    : if lookmsg and (race=player) then
                  begin
                    BlockRead(f,fh.name[1],13); lfhn:=12;
                    while (lfhn>0) and (fh.name[lfhn]=#0) do dec(lfhn);
                    Upper(fh.name);
                    if WriteFile(fh.name,uh.rsize-13,fh.flag and 1=1) then
                    begin
                      if fh.name=PCONFIG_SRC then ReadConfigFile(addir+PCONFIG_SRC,sPHOST);
                      if Pos(fh.name,
'PLANET.NM,STORM.NM,RACE.NM,BEAMSPEC.DAT,TORPSPEC.DAT,ENGSPEC.DAT,HULLSPEC.DAT,TRUEHULL.DAT'
                         )<>0 then LoadPlanetsData;
                    end;
                  end;
          37    : begin
                    while (uh.rsize >= 4) do begin
                      BlockRead(f, util_rc, 4);
                      dec(uh.rsize, 4);
                      if (util_rc.sid > 0) and (util_rc.sid <= NUM_SHIPS) then rcflags[util_rc.sid] := util_rc.flag;
                    end;
                  end;
{$IFDEF VPACC}
          39    : begin
                    while (uh.rsize >= sizeof(util_bq)) do begin
                      BlockRead(f, util_bq, sizeof(util_bq));
                      dec(uh.rsize, sizeof(util_bq));
                      AddBuildQueueEntry(util_bq);
                    end;
                  end;
          52    : begin
                    { FIXME: quick & dirty }
                    if uh.rsize > sizeof(util_buf) then uh.rsize := sizeof(util_buf);
                    if uh.rsize > 0 then begin
                      BlockRead(f, util_buf, uh.rsize);
                      AddShipFunctions(util_buf, uh.rsize);
                    end;
                  end;
          57    : begin
                    BlockRead(f, util_sdef, sizeof(util_sdef));
                    AddSpecialDef(util_sdef);
                  end;
{$ENDIF}
          40    : begin
                    BlockRead(f,util_drain,Sizeof(util_drain));
                    if (TEnd^.data^.ship[util_drain.sid]<>NIL) and
                       (Tend^.data^.ship[util_drain.sid]^.fuel<0) then
                      TEnd^.data^.ship[util_drain.sid]^.fuel:=0;
                  end;
          49, 50: if lookmsg then begin
                    BlockRead(f, util_exp, Sizeof(util_exp));
                    Dec(uh.rsize, Sizeof(util_exp));
                    if util_exp.id = uscore_Experience then begin
                      while (uh.rsize >= Sizeof(util_exp_entry)) do begin
                        Blockread(f, util_exp_entry, Sizeof(util_exp_entry));
                        Dec(uh.rsize, Sizeof(util_exp_entry));
                        if uh.rtype=49 then PutShipExperience(util_exp_entry.id, util_exp_entry.value)
                                       else PutPlanetExperience(util_exp_entry.id, util_exp_entry.value);
                      end;
                    end;
                  end;
        end;
        seek(f, newpos);
      end;
      CloseData(f);
    end;

    procedure CheckIMSN;
      var       r       : byte;
                stmp    : TimeStamp;
      begin
        if OpenRW(f,VPAMSG_DAT,No) then
        begin
          BlockRead(f,stmp,SizeOf(TimeStamp));
          BlockRead(f,imsn,SizeOf(imsn));
          BlockRead(f,vcrn,SizeOf(vcrn));
          CloseData(f);
          if stmp=Stamp then Exit;
        end;
        OpenW(f,VPAMSG_DAT,Yes);
        BlockWrite(f,Stamp,SizeOf(TimeStamp));
        for r:=1 to 11 do
          if OpenRW(g,'MDATA'+NStr(r)+'.DAT',No) then
          begin
            BlockRead(g,imsn[r],2);
            CloseData(g);
            OpenRW(g,'VCR'+NStr(r)+'.DAT',Yes);
            BlockRead(g,vcrn[r],2);
            CloseData(g);
          end;
        BlockWrite(f,imsn,SizeOf(imsn));
        BlockWrite(f,vcrn,SizeOf(vcrn));
        CloseData(f);
      end;

  procedure MakeMCRC;   { f is already open }
    var i       : int;
    begin
      CheckMem(12*2);
      GetMem(MCRC,12*2);
      MCRC^[1]:=12;
      MCRC^[2]:=2;
      for i:=1 to imsn[player] do
        if ReadMessage(f,i,mm,0,Yes)<>0 then CheckMessageCRC;
    end;

  procedure MakeVCRC;   { f is already open }
    var i       : int;
        vcr     : VCRData;
    begin
      CheckMem(12*2);
      GetMem(VCRC,12*2);
      VCRC^[1]:=12;
      VCRC^[2]:=2;
      Seek(f,2);
      for i:=1 to vcrn[player] do
      begin
        BlockRead(f,vcr,SizeOf(VCRData));
        CheckVcrCRC(vcr);
      end;
    end;

  BEGIN
    if FirstRun and RWMode then
    begin
      CheckIMSN;
      if lookmsg then
      begin
        OpenRW(f,'MDATA'+plstr+'.DAT',Yes);
        BlockWrite(f,imsn[player],2);
        MakeMCRC;
        CloseData(f);
        OpenRW(f,'VCR'+plstr+'.DAT',Yes);
        BlockWrite(f,vcrn[player],2);
        Seek(f,FileSize(f)-10);
        BlockRead(f,s,10);
        Seek(f,long(vcrn[player])*SizeOf(VCRData)+2);
        BlockWrite(f,s,10);
        MakeVCRC;
        CloseData(f);
      end;
    end;

    pls:=NStr(race);

    OpenRW(f,'MDATA'+pls+'.DAT',Yes);
    BlockRead(f,nmes,2);

    if race=player then
    begin
      nmsg[m_In]:=nmes;

      CheckWinPlanMess;
      OpenRW(v,'MESS'+pls+'.DAT',Yes);
      BlockRead(v,nmsg[m_Out],2);
      CloseData(v);

      OpenRW(v,'VCR'+pls+'.DAT',Yes);
      BlockRead(v,nmsg[m_VCR],2);
    end
    else begin
      nmes:=imsn[race];
      if RWMode and lookmsg then MergeVCRs;
    end;
    CloseData(f);

    {if PHOST then ReadUtilData;}
    PurgeUtilData(false);
    ReadUtilData;

    if not lookmsg then
    begin
      if race=player then CloseData(v);
      Exit;
    end;

    if FirstRun then
    begin
      if not ReadConfigFile(addir+VPADATA_INI,sData) then Move(IsData[1],AcceptData[1],11);
      WriteDConfig;

      Writeln('Reading messages...');
      FirstRun:=No;
    end;

    if race=player then OpenW(g,'VPAMSG'+plstr+'.DAT',Yes);

    Assign(t,ResolveCase(VPA_MSG));   { tolerancia de caja: vpa.msg / VPA.MSG en Linux }
    Reset(t);
    if IOResult<>0 then
    begin
      WriteLn('WARNING: Message-File "'+VPA_MSG+'" missing - can not parse messages');
      if race=player then begin CloseData(g); CloseData(v) end;
      GPause:=Yes;
      Exit;
    end;
    Readln(t,s);
    if ((Pos(#10,s)<>0) and (race=player)) then
    begin
        Writeln(#13#10#7'!!! Attention !!!'#13#10,
                'The file ',VPA_MSG,' is a UNIX-style text file!'#13#10,
                'Its format is not readable for most non-UNIX programs, including VPA.'#13#10,
                'The contents of this file are ignored.'#13#10,
                'Please provide a DOS-style version of this file.'#13#10);
        GPause:=Yes;
    end;


    if race=player then
    begin
      klsize:=(nmsg[m_In]+1)*2;
      CheckMem(klsize);
      GetMem(keeplist,klsize);
      keeplist^[1]:=0;

      vlsize:=nmsg[m_VCR];
      CheckMem(vlsize);
      GetMem(vcrlist,vlsize);
      FillChar(vcrlist^,vlsize,0);
    end;

    OpenRW(f,'MDATA'+pls+'.DAT',Yes);
    PrepareUtilData;
    Seek(f,2);
    for n:=1 to nmes do
    begin
      sender:=ReadMessage(f,n,mm,0,Yes);
      CheckMsgObj;
      msgvcr:=0;
      id:=0; owner:=-1;
      dist:=-1; sdist:=-1;
      minesDest:=-1;
      msgdate:=IIF(mm.text[1,2]='o',today-1,today);
      x:=0; y:=0; x2:=-1; y2:=-1; radius:=-1;
      o:=oNone;

      if ExtFeatReadMessagesHook(sender,mm) then Continue;

      mt:=mUnknown;
      Reset(t); l:=0;
      while not Eof(t) do
      begin
        Readln(t,s); inc(l);
        { Blindaje: si el VPA.MSG viniera en CRLF (DOS), Readln en Linux deja un CR
          colgante que RTrim no quita; lo eliminamos para que las plantillas casen. }
        if (ls>0) and (s[ls]=#13) then dec(ls);
        ProcessTabs(s); Trim(s);
        if (ls=0) or (s[1]=';') then Continue;
        Parse(s,s1,' '#9); Upper(s1);
        if s1='MESSAGE' then
        begin
          s1:=LeftWord(s); Upper(s1);
          mt:=MsgType(ItemPos(s1,MsgNames));
          if mt>=mUnknown then
            begin Warning('Unknown message type "'+s1+'"',Yes); Continue end
          else begin
            fl:=MsgFl[mt];
            keep:=No;
          end;
        end else
        if mt=mUnknown then Continue else
        if s1='CHECK' then
        begin
          k:=GetLinePos(0,No);
          if k=0 then
            begin mt:=mUnknown; Continue end;
          if ls=0 then Continue;        { no pos and str specified }
          i:=GetLinePos(k,No);
          if i=0 then
            begin mt:=mUnknown; Continue end;
          if ls=0 then Continue;        { no str specified }
          if PosInStr(s,mm.text[k])<>i then
            begin mt:=mUnknown; Continue end;
        end else
        if s1='KEEP' then begin keep:=Yes; keepstr:=s end else
        if s1='END' then
        begin
          { in "Marker", radius is optional and magic. When there is
            a "radius" tag, we make a RCircle; when there is none - Circle
            fl is set of *missing* tags. }
          if (mt=mMarker) then begin
            if (mfRadius in fl) then begin
              exclude(fl, mfRadius);
              radius := -1;
            end;
            if (mfX2 in fl) or (mfY2 in fl) then begin
              exclude(fl, mfX2);
              exclude(fl, mfY2);
              x2 := -1;
              y2 := -1;
            end;
          end;
          if fl=[] then begin StoreRec; Break end
          else begin
            ls:=0;
            for mfl:=MsgF1 to MsgF2 do
            begin
              ItemStr(MsgFNames,word(mfl),s1);
              if mfl in fl then s:=s+s1+',';
            end;
            dec(ls);
            Warning('Field(s) '+s+' must be defined before END',Yes);
          end;
          mt:=mUnknown;
        end else
        begin
          mfl:=MsgFlds(ItemPos(s1,MsgFNames));
          if (mfl>MsgF2) then begin Warning('Unknown field "' + s1 + '"', Yes); Continue end;
          if not(mfl in fl) then begin Warning('Duplicate field "'+s1+'"',Yes); Continue end;
          fl:=fl-[mfl];
          k:=GetLinePos(0,No);
          if k=0 then
            begin Warning('Bad line number',Yes); Continue end;
          i:=GetLinePos(k,No);
          if i=0 then
            begin Warning('Bad string position',Yes); Continue end;
          case mfl of
            mfObject    : GetObject;
            mfData      : GetData;
            mfX         : x:=GetNumber;
            mfY         : y:=GetNumber;
            mfX2        : x2:=GetNumber;
            mfY2        : y2:=GetNumber;
            mfId        : begin id:=GetNumber; InitRec end;
            mfOwner     : begin owner:=GetRace;
                                newpln:=newpln or NP_Owner end;
            mfMines     : if MsgRType[mt]='M' then m.units:=GetNumber else
                          if MsgRType[mt]='H' then IsMines:=GetYN else
                          if MsgRType[mt]='U' then units:=GetNumber
                                              else p.mines:=GetNumber;
            mfMinesDest : minesDest:=GetNumber;
            mfDist      : dist:=GetNumber;
            mfSweepDist : sdist:=GetNumber;
            mfWeb       : m.web:=GetWeb;
            mfGather    : dec(m.units,MinL(GetNumber,m.units));
            mfActivity  : e.activity:=(e.activity and (EP_Base or EP_NoBase)) or GetActivity;
            mfRadius    : if mt=mIonStorm then begin InitRec; is.radius:=GetNumber end
                          else radius := GetNumber;
            mfVoltage   : is.voltage:=GetNumber;
            mfHeading   : is.heading:=GetNumber;
            mfWarp      : is.warp:=GetNumber;
            mfGrow      : is.grow:=(LeftWord(Copy(mm.text[k],i,20))=IonGrow[Yes]);
            mfMass      : w.mass:=GetNumber;
            mfStable    : w.stable:=GetStable;
            mfId1       : id1:=GetNumber;
            mfId2       : id2:=GetNumber;
            mfName1     : name1:=GetName;
            mfName2     : name2:=GetName;
            mfName      : begin name1:=GetName; name2:=name1 end;
            mfShipName  : ShipName:=GetShipName;
            mfPlanet    : begin
                            if (mt=mSurrender) or (mt=mSpaceDock) then msgobj:=0; { yes, from text }
                            id:=GetPlanet;
                            InitRec;
                          end;
            mfClimate   : begin p.climate:=100-GetNumber;
                                newpln:=newpln or NP_Climate end;
            mfClans     : begin p.colonists:=GetNumber;
                                newpln:=newpln or NP_CPop end;
            mfN         : if p.Nc=-2 then p.Nc:=GetNumber-p.N   {util.dat}
                                     else begin p.N:=GetNumber; p.Nc:=-1 end;
            mfT         : if p.Tc=-2 then p.Tc:=GetNumber-p.T   {util.dat}
                                     else begin p.T:=GetNumber; p.Tc:=-1 end;
            mfD         : if p.Dc=-2 then p.Dc:=GetNumber-p.D   {util.dat}
                                     else begin p.D:=GetNumber; p.Dc:=-1 end;
            mfM         : if p.Mc=-2 then p.Mc:=GetNumber-p.M   {util.dat}
                                     else begin p.M:=GetNumber; p.Mc:=-1 end;
            mfFunds     : begin p.funds:=GetNumber;
                                newpln:=newpln or NP_NTDM_Funds end;
            mfSupplies  : begin p.supplies:=GetNumber;
                                newpln:=newpln or NP_Supplies end;
            mfFactories : p.factories:=GetNumber;
            mfDefenses  : p.defense:=GetNumber;
            mfFCode     : begin
                            s:=LeftWord(Copy(mm.text[k],i,40));
                            Move(s[1],p.fcode,3);
                            newpln:=newpln or NP_MFD_FCode;
                          end;
            mfNRace     : begin p.nrace:=GetNRace;
                                newpln:=newpln or NP_NRace_NPop end;
            mfNatives   : if p.nrace<>0 then p.natives:=GetNumber div 100;
            mfAlchemy   : Alchemy:=GetYN;
            mfColFB     : ColFBuild:=GetYN;
            mfRobFB     : RobFBuild:=GetYN;
            mfRGA       : RGA:=GetYN;
            mfSuperRefit: SuperRefit:=GetYN;
            mfWebs      : WebMines:=GetYN;
            mfMinRate   : GetRates(MinRate);
            mfTaxRate   : GetRates(TaxRate);
            mfEatSupplies: OverpopulationEatsSupplies:=GetYN;
            mfDetectMine: DetectMineRange:=GetNumber;
            mfNoFuelMove: NoFuelMove:=GetYN;
            mfSweepRate : SweepRate:=GetNumber;
            mfWebSweepRate : WebSweepRate:=GetNumber;
            mfSweepRange: SweepRange:=GetNumber;
            mfWebSweepRange : WebSweepRange:=GetNumber;
            mfFedCrew   : FedCrew:=GetYN;
            mfESBonus   : begin IsESBonus:=GetYN; if not IsESBonus then ESBonus:=0 end;
            mfESRate    : if IsESBonus then ESBonus:=GetNumber;
            mfHiss      : begin IsHiss:=GetYN; if not IsHiss then HissEffect:=0 end;
            mfHissEffect: if IsHiss then HissEffect:=GetNumber;
            mfGravity   : Gravity:=GetYN;
            mfMaxIncome : MaxIncome:=GetNumber;
            mfCloning   : Cloning:=GetYN;
            mfGambling  : Gambling:=GetYN;
            mfChunnel   : Chunnel:=GetYN;
            mfCloakFB   : CloakFuelBurn:=GetNumber;
            mfAssRate   : AssimilationRate:=GetNumber;
            mfCPDamage  : CloakPreventDamage:=GetNumber;
            mfTerraform : Terraformers:=GetYN;
            mfOneEngTow : OneEngineTow:=GetYN;
            mfHyperDrive: HyperDrive:=GetYN;
            mfCDR       : ClimateDeathRate:=GetNumber;
            mfCrystalDesert: CrystalsLikeDesert:=GetYN;
            mfClimateLimits: ClimateLimitsPopulation:=GetYN;
            mfGlory     : GloryDevice:=GetYN;
            mfLoki      : AntiCloak:=GetYN;
            mfAssault   : ImperialAssault:=GetYN;
            mfAdvRef    : AdvancedRefinery:=GetYN;
            mfBioScan   : BioScanners:=GetYN;
            mfRamScoop  : RamScoop:=GetNumber;
            mfVPAExtra   : VPAExtra:=GetYN;
            mfStructDecay : StructureDecay:=GetNumber;
            mfFreeFighter : GetRates(FreeFighters);
            mfMineDecay : MineDecayRate:=GetNumber;
            mfWebDecay  : WebMineDecayRate:=GetNumber;
            mfPBP       : GetPBP;
            mfNClans    : begin
                            p.natives:=GetNumber;
                            if (p.natives=0) then p.nrace:=0;
                            if (p.nrace<0) then p.nrace:=10;
                          end;
          end;
        end;
      end;
      if race=player then
      begin
        BlockWrite(g,msgobj,2);
        BlockWrite(g,msgvcr,2);
      end;
    end;
    Close(t);
    CloseData(f);
    FinishUtilData;
    if race=player then
    begin
      BlockWrite(g,keeplist^[2],keeplist^[1]*2);
      CloseData(g);
    end;
    CloseData(v);

    if race=player then
    begin
      if keeplist^[1]>0 then
      begin
        n:=(keeplist^[1]+1)*2;
        CheckMem(n);
        GetMem(keepmsg,n);
        Move(keeplist^,keepmsg^,n);
        DataChg:=Yes;
      end;
      FreeMem(keeplist,klsize);
    end;

  END;

End.
