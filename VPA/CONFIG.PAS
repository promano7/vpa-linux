{$I switches.inc}
Unit    Config;         { INI maintenance unit }
{$V-}

{       Format:
                        ; This is a comment. Next line is empty. Ignored.

                        [Section1]
                        ; unknown sections are ignored

                        [Section2]
                        ; some keys have a value assigned
                        key1=AAA
                        ; some keys don't have any value. ignored.
                        key2
}

Interface

uses    StrF,AuxF;

const   PCONFIG_SRC     : array [1..11] of char = 'PCONFIG.SRC';
var     VPADATA_INI     : string[12];
        VPACLR_INI      : string[12];
const   HConfChg        : boolean = No;
        OptimizeFuel    : boolean = No;
        AutoAdjustWarp  : boolean = No;

type    cfgSec  = (sColor,sMarkers,sInterface,sSystem,sConfig,sPHOST,sRace,sData,sMap,sFreeCISReg,sUnknown);
                   { colors MUST be the first, UNKNOWN - the last }

procedure ReadConfig1;
procedure ReadConfig2 (RWMode:boolean);
function  ReadConfigFile (fnm:str79; sec:cfgSec) : boolean;
procedure WriteHConfig;
procedure WriteDConfig;
procedure InitHullFunc;

{$ifdef VPAMM}
const mo_DisableLFB = 1;
      mo_DisableVesaPal = 2;

const MainOptions : LONGINT = mo_DisableLFB;

const ModeLine:array[1..8] of integer = (
            832,           { htotal }
            696,           { hsync start }
            752,           { hsync end }
            509,           { vtotal }
            481,           { vsync start }
            484,           { vsync end }
            3,             { flags }
            69             { refresh rate }
      );
      UseModeline : boolean = false;
{$endif}

Implementation

uses    Screen,ptcgraph,VPAData,Messages,VPAInit,RST_TRN,ExtFeat
{$IFDEF VPACC},
        Hullfunc
{$ENDIF};

const   VPA_INI         : array [1..7] of char = 'VPA.INI';
        HCONFIG_INI     : array [1..11] of char = 'HCONFIG.INI';
        RACES_INI       : array [1..9] of char = 'RACES.INI';

const   SecNames: array [1..101] of char =
      'COLORS MARKERS INTERFACE SYSTEM HCONFIG PHOST RACES DATA MAP MAP  ';

type    cfgKey  = (
  kcPInfo,kcOPInfo,kcBInfo,kcSInfo,kcIInfo,kcWInfo,kcUInfo,kcmPNeut,
  kcmIWeak,kcmIMod,kcmIDang,kcmWorm,
  kcmRoute,kcmTow,kcmTrace,kcmDist,
  kcMsg,kcMsgHL1,kcMsgHL2,kcMsgHL3,
  kcProfile,
  kcRace1,kcRace2,kcRace3,kcRace4,kcRace5,kcRace6,
  kcRace7,kcRace8,kcRace9,kcRace10,kcRace11,

  kiAutoScroll,kiStickyMouse,kiLargePlanets,kiPlanetNames,kiSmallFont,kiScreenSaverTime,
  kiKeepWayPoints,kiAutoUseGravity,kiDullMissions,kiDullMessages,
  kiDeleteRST,kiScrambleShipNames,

  kHelpFile,kResFile,kBadVideoOrMouse,

  kIsMines,kAlchemy,kColFB,kRobFB,kRGA,kSuperRefit,
  kDetectMine,kHissEffect,kWebMines,kSweepRate,kWebSweepRate,kESBonus,
  kFedCrew,kGravity,kMaxIncome,kCloakFB,kCloning,kGambling,kChunnel,
  kTerraformers,kCPDamage,kOneEngTow,kHyperDrive,kNoFuelMove,
  kGloryDevice,kAntiCloak,kAssault,kAdvRef,kBioScan,kRamScoop,
  kTax1,kTax2,kTax3,kTax4,kTax5,kTax6,kTax7,kTax8,kTax9,kTax10,kTax11,
  kMin1,kMin2,kMin3,kMin4,kMin5,kMin6,kMin7,kMin8,kMin9,kMin10,kMin11,

  kRace1,kRace2,kRace3,kRace4,kRace5,kRace6,kRace7,kRace8,kRace9,kRace10,kRace11,

  kAcceptData0,kAcceptData1,kAcceptData2,kAcceptData3,kAcceptData4,kAcceptData5,
  kAcceptData6,kAcceptData7,kAcceptData8,kAcceptData9,kAcceptData10,kAcceptData11,

  kpIsMines,kpAlchemy,kpColFB,kpRobFB,kpRGA,kpSuperRefit,
  kpMineScanRange,kpHissEffect,kpWebMines,kpSweepRate,
  kpIsESBonus,kpESBonus,kpFedCrew,kpGravity,kpGravityRange,kpRoundWells,
  kpMaxIncome,kpTaxRates,kpMinRates,kpPlayerRace,
  kpCloakFB,kpCloning,kpCloneCost,kpWormholes,kpWormPower,
  kpGambling,kpChunnel,kpTerraformers,kpCPDamage,kpOneEngTow,kpNoFuelMove,
  kpHyperDrive,kpHYPGravity,kpGloryDevice,kpAntiCloak,kpAssault,kpAdvRef,
  kpBioScan,kpRamScoop,kpTrueHullByRace,kpScoringMethod,
  kpAccurateFuelModel,

  kmSize,kmWrap,kmExplMap,

  kgMasks,
  kgNone,kgFlag,kgCircle,kgCross,kgSquare,kgRhombe,
  kgPoint,kgRCircle,kgLine,kgDLine,kgGrave,kgCactus,
  kgFlag1,kgFlag2,kgFlag3,kgArrow1,kgArrow2,kgArrow3,
  kgArrow4,kgArrow5,kgArrow6,kgArrow7,kgArrow8,kgNe,
  kgTr,kgDu,kgMo,kgSkull,

  kpNativeTaxRate, kpColonistTaxRate, kpMineHitDamageFor100KT,
  kpWebHitDamageFor100KT, kpUnitsPerTorpRate, kpMaxShipsHissing,
  kpMineHitOdds, kpWebMineHitOdds, kpMineHitOddsWhenCloakedX10,
  kpWebSweepRate, kpMineDecayRate, kpWebMineDecayRate,
  kpWrmTravelDistDivisor, kpWrmTravelWarpSpeed, kpWrmTravelCloaked,

  kiShowFinalHappy, kiAltWormholes,

  kpEnableGive, kpEnableRemote, kpAllowExtendedMissions, kpExtMissionsStartAt,
  kpFreeFighters, kpProductionRate, kpRecycleRate,
  kpDamageLevelForChunnelFail, kpMinimumChunnelDistance, kpAllowAlliedChunneling,
  kpExperienceLevelNames,

  kFont,

  kpGroundKillFactor, kpGroundDefenseFactor, kpMaxColTempSlope, kpClimateLimitsPopulation,
  kpClimateDeathRate, kpCrystalsLikeDesert, kpCrystalSinTemp, kpSweepRange, kpWebSweepRange,
  kpFighterSweepRange, kpFighterSweepRate, kpAllowColoniesSweepWebs,

  kAssimilationRate, kCrystalDesertAdvantage, kClimateLimitsPopulation,
  kEatSupplies, kStructureDecay, kSweepRange, kWebSweepRange, kMineDecay, kWebDecay, 

  kiShowMaxPop, kiShowCombatStrength,

  kpCrystalSinTempBehavior, kpNativeClimateDeathRate, kpRaceGrowthRate,
  kpStructureDecay, kpAllowAlternativeCombat,

  kiShowMineTrack,

  kpNumExperienceLevels,

  kpStarbaseCost, kpBaseFighterCost, kpFreeFighterCost, kpShipFighterCost,
  kpMaximumFightersOnBase, kpMaximumDefenseOnBase, kiOptimizeFuel, kiAutoAdjustWarp,
  kpAllowWraparoundMap, kpWraparoundRectangle,
  kFF1, kFF2, kFF3, kFF4, kFF5, kFF6, kFF7, kFF8, kFF9, kFF10, kFF11,
  kVPAExtra,


  kUnknown
);      { UNKNOWN must be the last }

const   ConfKey1= kIsMines;
        ConfKey2= kUnknown;
        DataKey1= kAcceptData0;
        DataKey2= kAcceptData11;
        KeyNames: array [1..36,1..100] of char = (
              'PLANETINFO OLDPLANETINFO BASEINFO SHIPINFO STORMINFO WORMINFO UFOINFO NEUTRALPLANET WEAKSTORM MODERA',
              'TESTORM DANGEROUSSTORM WORMHOLE FLYPATH TOWPATH TRACE DISTLINE MESSAGE HIGHLIGHT/ HIGHLIGHT_ HIGHLIG',
              'HT* PROFILE RACECOLOR1 RACECOLOR2 RACECOLOR3 RACECOLOR4 RACECOLOR5 RACECOLOR6 RACECOLOR7 RACECOLOR8 ',
              'RACECOLOR9 RACECOLOR10 RACECOLOR11 AUTOSCROLL STICKYMOUSE LARGEPLANETS PLANETNAMES SMALLFONT SCREENS',
              'AVERTIME KEEPWAYPOINTS AUTOUSEGRAVITY DULLMISSIONS DULLMESSAGES DELETERST SCRAMBLESHIPNAMES HELPFILE',
              ' RESOURCEFILE BADVIDEOORMOUSE MINES ALCHEMY COLONIALFBUILD ROBOTICFBUILD RGA SUPERREFIT DETECTMINERA',
              'NGE HISSEFFECT WEBMINES SWEEPRATE WEBSWEEPRATE ESBONUS FEDCREWBONUS GRAVITYWELLS MAXINCOME CLOAKFUEL',
              ' CLONING GAMBLING CHUNNEL TERRAFORMERS CLOAKPREVENTDAMAGE ONEENGINETOW HYPERDRIVE NOFUELMOVE GLORYDE',
              'VICE ANTI-CLOAK IMPERIALASSAULT ADVREFINERY BIOSCANNERS RAMSCOOP TAXRATE1 TAXRATE2 TAXRATE3 TAXRATE4',
              ' TAXRATE5 TAXRATE6 TAXRATE7 TAXRATE8 TAXRATE9 TAXRATE10 TAXRATE11 MININGRATE1 MININGRATE2 MININGRATE',
              '3 MININGRATE4 MININGRATE5 MININGRATE6 MININGRATE7 MININGRATE8 MININGRATE9 MININGRATE10 MININGRATE11 ',
              'PLAYERRACE1 PLAYERRACE2 PLAYERRACE3 PLAYERRACE4 PLAYERRACE5 PLAYERRACE6 PLAYERRACE7 PLAYERRACE8 PLAY',
              'ERRACE9 PLAYERRACE10 PLAYERRACE11 ACCEPTDATA0 ACCEPTDATA1 ACCEPTDATA2 ACCEPTDATA3 ACCEPTDATA4 ACCEPT',
              'DATA5 ACCEPTDATA6 ACCEPTDATA7 ACCEPTDATA8 ACCEPTDATA9 ACCEPTDATA10 ACCEPTDATA11 ALLOWMINEFIELDS ALLO',
              'WALCHEMY COLONIESBUILDFIGHTERS ROBOTSBUILDFIGHTERS ALLOWREBELGROUNDATTACK ALLOWSUPERREFIT MINESCANRA',
              'NGE HISSEFFECTRATE ALLOWWEBMINES MINESWEEPRATE ALLOWENGINESHIELDBONUS ENGINESHIELDBONUSRATE ALLOWFED',
              'COMBATBONUS ALLOWGRAVITYWELLS GRAVITYWELLRANGE ROUNDGRAVITYWELLS MAXPLANETARYINCOME RACETAXRATE RACE',
              'MININGRATE PLAYERRACE CLOAKFUELBURN ALLOWSHIPCLONING SHIPCLONECOSTRATE ALLOWWORMHOLES WRMENTRYPOWERX',
              '100 ALLOWGAMBLINGSHIPS ALLOWCHUNNELING ALLOWSCIENCEMISSIONS DAMAGELEVELFORCLOAKFAIL ALLOWONEENGINETO',
              'WING ALLOWNOFUELMOVEMENT ALLOWHYPERWARPS ALLOWHYPERJUMPGRAVWELLS ALLOWGLORYDEVICE ALLOWANTICLOAKSHIP',
              'S ALLOWIMPERIALASSAULT ALLOWADVANCEDREFINERY ALLOWBIOSCANNERS RAMSCOOPFUELPERLY MAPTRUEHULLBYPLAYERR',
              'ACE SCORINGMETHOD USEACCURATEFUELMODEL SIZE WRAP EXPLORE MASKS MARKNONE FLAG CIRCLE CROSS SQUARE RHO',
              'MBE POINT RCIRCLE LINE DLINE GRAVE CACTUS FLAG1 FLAG2 FLAG3 ARROW1 ARROW2 ARROW3 ARROW4 ARROW5 ARROW',
              '6 ARROW7 ARROW8 NE TR DU MO SKULL NATIVETAXRATE COLONISTTAXRATE MINEHITDAMAGEFOR100KT WEBHITDAMAGEFO',
              'R100KT UNITSPERTORPRATE MAXSHIPSHISSING MINEHITODDS WEBMINEHITODDS MINEHITODDSWHENCLOAKEDX10 WEBMINE',
              'SWEEPRATE MINEDECAYRATE WEBMINEDECAYRATE WRMTRAVELDISTDIVISOR WRMTRAVELWARPSPEED WRMTRAVELCLOAKED SH',
              'OWFINALHAPPY ALTWORMHOLES CPENABLEGIVE CPENABLEREMOTE ALLOWEXTENDEDMISSIONS EXTMISSIONSSTARTAT FREEF',
              'IGHTERS PRODUCTIONRATE RECYCLERATE DAMAGELEVELFORCHUNNELFAIL MINIMUMCHUNNELDISTANCE ALLOWALLIEDCHUNN',
              'ELING EXPERIENCELEVELNAMES FONT GROUNDKILLFACTOR GROUNDDEFENSEFACTOR MAXCOLTEMPSLOPE CLIMATELIMITSPO',
              'PULATION CLIMATEDEATHRATE CRYSTALSLIKEDESERT CRYSTALSINTEMP MINESWEEPRANGE WEBMINESWEEPRANGE FIGHTER',
              'SWEEPRANGE FIGHTERSWEEPRATE ALLOWCOLONIESSWEEPWEBS ASSIMILATIONRATE CRYSTALDESERTADVANTAGE CLIMATELI',
              'MITSPOP EATSUPPLIES STRUCTUREDECAY SWEEPRANGE WEBSWEEPRANGE MINEDECAY WEBDECAY SHOWMAXPOP SHOWCOMBAT',
              'STRENGTH CRYSTALSINTEMPBEHAVIOR NATIVECLIMATEDEATHRATE RACEGROWTHRATE STRUCTUREDECAYPERTURN ALLOWALT',
              'ERNATIVECOMBAT SHOWMINETRACK NUMEXPERIENCELEVELS STARBASECOST BASEFIGHTERCOST FREEFIGHTERCOST SHIPFI',
              'GHTERCOST MAXIMUMFIGHTERSONBASE MAXIMUMDEFENSEONBASE OPTIMIZEFUEL AUTOADJUSTWARP ALLOWWRAPAROUNDMAP ',
              'WRAPAROUNDRECTANGLE FF1 FF2 FF3 FF4 FF5 FF6 FF7 FF8 FF9 FF10 FF11 VPAEXTRA                        '
        );
        MaxKLen = 26;   { max key name len -- used for HCONFIG, VPADATA, RACES, colors, not relevant for PCONFIG }

type    cpptr           = ^ColorProfile;
        ColorProfile    = record
                            next        : cpptr;
                            name        : string[12];
                            colors      : ColorProf;
                          end;
var     cproot  : cpptr;

procedure AddColorProfile (var cp:ColorProfile);
  var   cpp     : cpptr;
  begin
    cpp:=cproot;
    while (cpp<>nil) and (cpp^.name<>cp.name) do cpp:=cpp^.next;
    if cpp=nil then
    begin
      CheckMem(SizeOf(ColorProfile));
      New(cpp);
      cp.next:=cproot; cproot:=cpp;
    end
    else cp.next:=cpp^.next;
    cpp^:=cp;
  end;

procedure InitColorProfiles;
  var   cp      : ColorProfile;
  begin
    cproot:=nil;
    cp.name:='OWN';
    cp.colors[_P_]:=LightBlue; cp.colors[_B_]:=LightCyan;
    cp.colors[_S_]:=Green; cp.colors[_M_]:=Cyan;
    AddColorProfile(cp);
    cp.name:='ENEMY';
    cp.colors[_P_]:=Yellow; cp.colors[_B_]:=LightRed;
    cp.colors[_S_]:=LightRed; cp.colors[_M_]:=Magenta;
    AddColorProfile(cp);
    cp.name:='ALLY';
    cp.colors[_P_]:=Magenta; cp.colors[_B_]:=LightMagenta;
    cp.colors[_S_]:=LightGray; cp.colors[_M_]:=Cyan;
    AddColorProfile(cp);
    FillChar(RaceColor,SizeOf(RaceColor),0);
  end;

procedure AssignRaceColors (r:byte; s:str20);
  var   cpp     : cpptr;
  begin
    Trim(s); Upper(s);
    cpp:=cproot;
    while (cpp<>nil) and (cpp^.name<>s) do cpp:=cpp^.next;
    if cpp<>nil then RaceColor[r]:=cpp^.colors;
  end;

{ This function borrowed from PCC, slightly hacked. }
PROCEDURE ParseCost(VAR costs:T11Costs; CONST s:STRING);
VAR
  i, j   : INTEGER;
  amount : INTEGER;
  race   : INTEGER;
  adr    : ARRAY[0..10, 1..5] OF INTEGER ABSOLUTE costs;
CONST PConfigCost_Types : STRING[5] = '$TDMS';
BEGIN
  { We accept two formats: cargospecs and PHost format.
      Cargospec:  123TDM
      PHost:      T123 D123 M123
    Therefore, we cannot re-use the ParseCargospec nor
    ReadBumCommand routines, but that would produce ugly
    interdependencies anyway. }
  amount := 0;

  { Clear this option completely }
  FillChar(costs, Sizeof(costs), 0);
  race := 0;

  i := 1;
  WHILE TRUE DO BEGIN
    { Skip whitespace }
    WHILE (i <= Length(s)) AND ((s[i] = ' ') OR (s[i] = #9)) DO Inc(i);
    IF i > Length(s) THEN Break;

    { Looking at a cargospec? }
    IF (s[i] >= '0') AND (s[i] <= '9') THEN BEGIN
      { parse the count }
      amount := 0;
      REPEAT
        amount := 10*amount + Ord(s[i])-Ord('0');
        Inc(i);
      UNTIL (i > Length(s)) OR (s[i] < '0') OR (s[i] > '9');
      { now parse the assignments }
      WHILE i <= Length(s) DO BEGIN
        j := Pos(Upcase(s[i]), PConfigCost_Types);
        IF j=0 THEN Break;
        Inc(adr[race, j], amount);
        Inc(i);
      END;
    END ELSE IF s[i] = ',' THEN BEGIN
      { Next race }
      Inc(i);
      Inc(race);
      IF race >= 11 THEN Break;
    END ELSE BEGIN
      j := Pos(Upcase(s[i]), PConfigCost_Types);
      IF j=0 THEN Break;
      { Looking at a PHost-style assignment }
      Inc(i);
      amount := 0;
      WHILE (i <= Length(s)) AND (s[i] >= '0') AND (s[i] <= '9') DO BEGIN
        amount := 10*amount + Ord(s[i])-Ord('0');
        Inc(i);
      END;
      Inc(adr[race, j], amount);
    END;
  END;

  { Now, complete arrayized option }
  WHILE race < 10 DO BEGIN
    FOR i:=1 TO 5 DO adr[race+1, i] := adr[race, i];
    Inc(race);
  END;
END;

function ReadConfigFile (fnm:str79; sec:cfgSec) : boolean;
  var   f       : text;
        s,s1    : string;
        ls      : byte absolute s;
        ls1     : byte absolute s1;
        i,j     : byte;
        key     : cfgKey;
        mark    : MarkType;
        Race11  : IArr11 absolute Race;
  function YesNo : boolean;
    begin
      Trim(s); Upper(s);
      YesNo:=(s='YES') or (s='ON') or (s='RULEZ') or (s='EXTERNAL') or (s='ALLIES') or (s='TRUE');
    end;
  procedure GetArray (var a:IArr11);
    var i       : byte;
    begin
      for i:=1 to 11 do
      begin
        Parse(s,s1,',');
        if (ls1=0) and (i>1) then a[i]:=a[i-1]
                             else a[i]:=Value(s1);
      end;
    end;
  procedure GetArrayL (var a:LArr11);
    { como GetArray pero 32-bit, para distancias/rangos de combate }
    var i : byte;
    begin
      for i:=1 to 11 do
      begin
        Parse(s,s1,',');
        if (ls1=0) and (i>1) then a[i]:=a[i-1]
                             else a[i]:=Value(s1);
      end;
    end;
  procedure ReadCombatKey;
    { s1=nombre de clave (mayusculas), s=valor. Captura las claves de combate de
      PHost que el visor nativo (PVCRALG) necesita y que NO estan en la tabla
      posicional KeyNames, sin acoplarlas a ella. Por jugador con GetArray;
      escalares con Value/YesNo. Las claves EMod* (experiencia) se difieren a la
      fase F y aqui se ignoran (caen por el final del if sin asignar). }
    begin
      with CombatCfg do
      if      s1='BEAMHITODDS'           then GetArray(BeamHitOdds)
      else if s1='BEAMHITBONUS'          then GetArray(BeamHitBonus)
      else if s1='BEAMRECHARGERATE'      then GetArray(BeamRechargeRate)
      else if s1='BEAMRECHARGEBONUS'     then GetArray(BeamRechargeBonus)
      else if s1='TORPHITODDS'           then GetArray(TorpHitOdds)
      else if s1='TORPHITBONUS'          then GetArray(TorpHitBonus)
      else if s1='TUBERECHARGERATE'      then GetArray(TubeRechargeRate)
      else if s1='TUBERECHARGEBONUS'     then GetArray(TubeRechargeBonus)
      else if s1='BAYRECHARGERATE'       then GetArray(BayRechargeRate)
      else if s1='BAYRECHARGEBONUS'      then GetArray(BayRechargeBonus)
      else if s1='BAYLAUNCHINTERVAL'     then GetArray(BayLaunchInterval)
      else if s1='SHIELDDAMAGESCALING'   then GetArray(ShieldDamageScaling)
      else if s1='SHIELDKILLSCALING'     then GetArray(ShieldKillScaling)
      else if s1='HULLDAMAGESCALING'     then GetArray(HullDamageScaling)
      else if s1='CREWKILLSCALING'       then GetArray(CrewKillScaling)
      else if s1='MAXFIGHTERSLAUNCHED'   then GetArray(MaxFightersLaunched)
      else if s1='STRIKESPERFIGHTER'     then GetArray(StrikesPerFighter)
      else if s1='FIGHTERMOVEMENTSPEED'  then GetArray(FighterMovementSpeed)
      else if s1='FIGHTERBEAMEXPLOSIVE'  then GetArray(FighterBeamExplosive)
      else if s1='FIGHTERBEAMKILL'       then GetArray(FighterBeamKill)
      else if s1='FIGHTERFIRINGRANGE'    then GetArrayL(FighterFiringRange)
      else if s1='FIGHTERKILLODDS'       then GetArray(FighterKillOdds)
      else if s1='BEAMFIRINGRANGE'       then GetArrayL(BeamFiringRange)
      else if s1='BEAMHITFIGHTERRANGE'   then GetArrayL(BeamHitFighterRange)
      else if s1='BEAMHITFIGHTERCHARGE'  then GetArray(BeamHitFighterCharge)
      else if s1='BEAMHITSHIPCHARGE'     then GetArray(BeamHitShipCharge)
      else if s1='TORPFIRINGRANGE'       then GetArrayL(TorpFiringRange)
      else if s1='STANDOFFDISTANCE'      then StandoffDistance:=Value(s)
      else if s1='FIREONATTACKFIGHTERS'  then FireOnAttackFighters:=YesNo
      else if s1='PLANETSHAVETUBES'      then PlanetsHaveTubes:=YesNo;
    end;
  procedure GetWraparoundRectangle;
    var i  : byte;
        xy : array[1..4] of integer;
    begin
      for i:=1 to 4 do begin
        Parse(s,s1,',');
        if (ls1=0) and (i>1) then xy[i]:=xy[i-1]
                             else xy[i]:=Value(s1);
      end;
      MapSize := xy[3] - xy[1];
      if (xy[1]<>xy[2]) or (xy[3]<>xy[4]) or (xy[1]+xy[3]<>4000) then begin
        Writeln(#13#10'This game uses a WraparoundRectangle not supported by VPA.'#13#10,
                '  WraparoundRectangle=',xy[1],',',xy[2],',',xy[3],',',xy[4],#13#10,
                'VPA only supports square maps centered at (2000,2000).'#13#10,
                'Map display will be wrong.'#13#10);
        GPause:=Yes;
      end;
    end;

  procedure GetColorProfile;
    var cp      : ColorProfile;
    begin
      Parse(s,s1,','); Upper(s1); cp.name:=s1;
      Parse(s,s1,','); cp.colors[_P_]:=Value(s1);
      Parse(s,s1,','); cp.colors[_B_]:=Value(s1);
      Parse(s,s1,','); cp.colors[_S_]:=Value(s1);
      Parse(s,s1,','); cp.colors[_M_]:=Value(s1);
      AddColorProfile(cp);
    end;
  begin
    ReadConfigFile:=No;
    Assign(f,fnm);
    Reset(f);
    if IOResult<>0 then Exit;
    Writeln('Reading ',fnm,'...');
    while not Eof(f) do
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
      end;
      Trim(s);
      if (ls=0) or (s[1] in [';','#']) then Continue;
      if ExtFeatReadConfigFileHook( s, sec ) then Continue;
      if ((s[1]='[') and (s[ls]=']')) or (s[1]='%') then
      begin
      {pconfig.src can have sections delimited with %KEYWORD }
        if (s[1]<>'%') then dec(ls);
        Delete(s,1,1);
        Trim(s); Upper(s);
        sec:=cfgSec(ItemPos(s,SecNames));
        if sec=sFreeCISReg then
        begin
          StrSubst(s,'_',' ');
          Writeln(s);
          RegVPA:=Yes;
        end;
      end
      {pconfig.src can have sections delimited with %KEYWORD }
      else if sec<sUnknown then
        begin
          i:=Pos('=',s); if i=0 then Continue;
          s1:=Copy(s,1,i-1);
          Trim(s1); Upper(s1);
          Delete(s,1,i); LTrim(s);
          i:=Pos('#',s);
          if i<>0 then begin
            s[0] := chr(i-1); Trim(s);
          end;
          key:=cfgKey(ItemPos(s1,KeyNames));
          if key<kUnknown then
            case sec of
              sColor    : case key of
                kcPInfo..kcMsgHL3: cColors[byte(key)]:=Value(s);
                kcProfile        : GetColorProfile;
                kcRace1..kcRace11: AssignRaceColors(byte(key)-byte(kcRace1)+1,s);
                          end;
              sMarkers: begin
                mark := MarkType(Ord(key) - Ord(kgNone));
                if (s<>'') and (mark in [mrkNone..LastMark]) then begin
                  while length(s) < 15 do s := s + s[length(s)];  { 15 colors }
                  MarkGroup[mark] := s;
                end
                else if key = kgMasks then begin
                  while s <> '' do begin
                    Parse(s,s1,',');
                    if LastMarkMask < MarkMaskMax then begin
                      Inc(LastMarkMask);
                      MarkMask[LastMarkMask] := s1;
                    end;
                  end;
                end;
              end;
              sInterface: case key of
                kiAutoScroll    : AutoScroll:=YesNo;
                kiStickyMouse   : StickyMouse:=YesNo;
                kiLargePlanets  : LargePlanets:=YesNo;
                kiPlanetNames   : PlanetNames:=YesNo;
                kiSmallFont     : UseSmallFont:=YesNo;
                kiScreenSaverTime: ScreenSaverTime:=Value(s)*60*18;
                kiKeepWayPoints : KeepWayPoints:=YesNo;
                kiAutoUseGravity: AutoUseGravity:=YesNo;
                kiDullMissions  : DullMissions:=YesNo;
                kiDullMessages  : BlankDeadRaces:=not YesNo;
                kiOptimizeFuel  : OptimizeFuel := YesNo;
                kiAutoAdjustWarp: AutoAdjustWarp := YesNo;
                kiDeleteRST     : DeleteRST:=YesNo;
                kiScrambleShipNames: ScrambleShipNames:=YesNo;
                kiShowFinalHappy   : ShowFinalHappy:=YesNo;
                kiAltWormholes  : AltWormholes := YesNo;
                kiShowMaxPop    : ShowMaxPop := YesNo;
                kiShowCombatStrength : ShowCombatStrength := YesNo;
                kiShowMineTrack : ShowMineTrack := YesNo;
                          end;
              sSystem   : case key of
                kHelpFile       : begin Trim(s); HelpName:=s end;
                kResFile        : begin Trim(s); ResName:=s end;
                kBadVideoOrMouse: BadVideoOrMouse:=YesNo;
                kFont           : begin Trim(s); FontName:=s; end;
                          end;
              sConfig   : case key of
                kIsMines        : IsMines:=YesNo;
                kAlchemy        : Alchemy:=YesNo;
                kColFB          : ColFBuild:=YesNo;
                kRobFB          : RobFBuild:=YesNo;
                kRGA            : RGA:=YesNo;
                kSuperRefit     : SuperRefit:=YesNo;
                kDetectMine     : DetectMineRange:=Value(s);
                kHissEffect     : HissEffect:=Value(s);
                kWebMines       : WebMines:=YesNo;
                kSweepRate      : SweepRate:=Value(s);
                kWebSweepRate   : WebSweepRate:=Value(s);
                kSweepRange     : SweepRange:=Value(s);
                kWebSweepRange  : WebSweepRange:=Value(s);
                kESBonus        : ESBonus:=Value(s);
                kFedCrew        : FedCrew:=YesNo;
                kGravity        : Gravity:=YesNo;
                kMaxIncome      : MaxIncome:=Value(s);
                kCloakFB        : CloakFuelBurn:=Value(s);
                kCloning        : Cloning:=YesNo;
                kGambling       : Gambling:=YesNo;
                kChunnel        : Chunnel:=YesNo;
                kTerraformers   : Terraformers:=YesNo;
                kCPDamage       : CloakPreventDamage:=Value(s);
                kOneEngTow      : OneEngineTow:=YesNo;
                kNoFuelMove     : NoFuelMove:=YesNo;
                kHyperDrive     : HyperDrive:=YesNo;
                kGloryDevice    : GloryDevice:=YesNo;
                kAntiCloak      : AntiCloak:=YesNo;
                kAssault        : ImperialAssault:=YesNo;
                kAdvRef         : AdvancedRefinery:=YesNo;
                kBioScan        : BioScanners:=YesNo;
                kRamScoop       : RamScoop:=Value(s);
                kTax1..kTax11   : TaxRate[byte(key)-byte(kTax1)+1]:=Value(s);
                kMin1..kMin11   : MinRate[byte(key)-byte(kMin1)+1]:=Value(s);
                kAssimilationRate        : AssimilationRate:=Value(s);
                kCrystalDesertAdvantage  : CrystalsLikeDesert:=YesNo;
                kClimateLimitsPopulation : ClimateLimitsPopulation:=YesNo;
                kpClimateDeathRate       : ClimateDeathRate:=Value(s);
                kEatSupplies             : OverpopulationEatsSupplies:=YesNo;
                kStructureDecay          : StructureDecay:=Value(s);
                kMineDecay      : MineDecayRate:=Value(s);
                kWebDecay       : WebMineDecayRate:=Value(s);
                kVPAExtra       : VPAExtra:=YesNo;
                kFF1..kFF11     : FreeFighters[ord(key)-ord(kFF1)+1]:=Value(s);
                          end;
      sPHOST    : case key of
                kpIsMines       : IsMines:=YesNo;
                kpAlchemy       : Alchemy:=YesNo;
                kpColFB         : ColFBuild:=YesNo;
                kpRobFB         : RobFBuild:=YesNo;
                kpRGA           : RGA:=YesNo;
                kpSuperRefit    : SuperRefit:=YesNo;
                kpMineScanRange : DetectMineRange:=Value(s);
                kpHissEffect    : HissEffect:=Value(s);
                kpMaxShipsHissing : MaxShipsHissing:=Value(s);
                kpWebMines      : WebMines:=YesNo;
                kpSweepRate     : SweepRate:=Value(s);
                kpWebSweepRate  : WebSweepRate:=Value(s);
                kpUnitsPerTorpRate : GetArray(UnitsPerTorpRate);
                kpMineHitOdds     : MineHitOdds:=Value(s);
                kpWebMineHitOdds  : WebMineHitOdds:=Value(s);
                kpMineHitOddsWhenCloakedX10 : MineHitOddsWhenCloakedX10:=Value(s);
                kpMineDecayRate   : MineDecayRate:=Value(s);
                kpWebMineDecayRate: WebMineDecayRate:=Value(s);
                kpMineHitDamageFor100KT : MineHitDamageFor100KT:=Value(s);
                kpWebHitDamageFor100KT  : WebHitDamageFor100KT :=Value(s);
                kpIsESBonus     : IsESBonus:=YesNo;
                kpESBonus       : ESBonus:=Value(s);
                kpFedCrew       : FedCrew:=YesNo;
                kpGravity       : Gravity:=YesNo;
                kpGravityRange  : GravityRange:=Value(s);
                kpRoundWells    : RoundWells:=YesNo;
                kpMaxIncome     : MaxIncome:=Value(s);
                kpTaxRates      : GetArray(TaxRate);
                kpNativeTaxRate : GetArray(TaxNRate);
                kpColonistTaxRate : GetArray(TaxCRate);
                kpMinRates      : GetArray(MinRate);
                kpPlayerRace    : GetArray(Race11);
                kpCloakFB       : CloakFuelBurn:=Value(s);
                kpCloning       : Cloning:=YesNo;
                kpCloneCost     : GetArray(CloneCost);
                kpWormholes     : Wormholes:=YesNo;
                kpWormPower     : WormPower:=Value(s);
                kpWrmTravelDistDivisor : WrmTravelDistDivisor:=Value(s);
                kpWrmTravelWarpSpeed   : WrmTravelWarpSpeed:=Value(s);
                kpWrmTravelCloaked     : WrmTravelCloaked:=YesNo;
                kpGambling      : Gambling:=YesNo;
                kpChunnel       : Chunnel:=YesNo;
                kpTerraformers  : Terraformers:=YesNo;
                kpCPDamage      : CloakPreventDamage:=Value(s);
                kpOneEngTow     : OneEngineTow:=YesNo;
                kpNoFuelMove    : NoFuelMove:=YesNo;
                kpHyperDrive    : HyperDrive:=YesNo;
                kpHYPGravity    : HYPGravity:=YesNo;
                kpGloryDevice   : GloryDevice:=YesNo;
                kpAntiCloak     : AntiCloak:=YesNo;
                kpAssault       : ImperialAssault:=YesNo;
                kpAdvRef        : AdvancedRefinery:=YesNo;
                kpBioScan       : BioScanners:=YesNo;
                kpRamScoop      : RamScoop:=Value(s);
                kpTrueHullByRace: TrueHullByRace:=YesNo;
                kpScoringMethod : begin Upper(s); if s='NONE' then BlankDeadRaces:=No end;
                kpAccurateFuelModel: AccurateFuelModel:=YesNo;
                kpEnableGive    : EnableGive:=YesNo;
                kpEnableRemote  : EnableRemote:=YesNo;
                kpAllowExtendedMissions : AllowExtendedMissions:=YesNo;
                kpExtMissionsStartAt : ExtMissionsStartAt:=Value(s);
                kpFreeFighters       : GetArray(FreeFighters);
                kpProductionRate     : GetArray(ProductionRate);
                kpRecycleRate        : RecycleRate:=Value(s);
                kpDamageLevelForChunnelFail: DamageLevelForChunnelFail :=Value(s);
                kpMinimumChunnelDistance : MinimumChunnelDistance:=Value(s);
                kpAllowAlliedChunneling  : AllowAlliedChunneling:=YesNo;
                kpExperienceLevelNames   : ExperienceLevelNames:=s;
                kpGroundKillFactor       : GetArray(GroundKillFactor);
                kpGroundDefenseFactor    : GetArray(GroundDefenseFactor);
                kpMaxColTempSlope        : MaxColTempSlope:=Value(s);
                kpClimateLimitsPopulation: ClimateLimitsPopulation:=YesNo;
                kpClimateDeathRate       : ClimateDeathRate:=Value(s);
                kpCrystalsLikeDesert     : CrystalsLikeDesert:=YesNo;
                kpCrystalSinTemp         : CrystalSinTemp:=YesNo;
                kpSweepRange             : SweepRange:=Value(s);
                kpWebSweepRange          : WebSweepRange:=Value(s);
                kpFighterSweepRange      : GetArray(FighterSweepRange);
                kpFighterSweepRate       : GetArray(FighterSweepRate);
                kpAllowColoniesSweepWebs : AllowColoniesSweepWebs:=YesNo;
                kpCrystalSinTempBehavior : CrystalSinTemp:=YesNo;
                kpNativeClimateDeathRate : NativeClimateDeathRate:=Value(s);
                kpRaceGrowthRate         : GetArray(RaceGrowthRate);
                kpStructureDecay         : StructureDecay:=Value(s);
                kpAllowAlternativeCombat : AllowAlternativeCombat:=YesNo;
                kpNumExperienceLevels    : NumExperienceLevels:=Value(s);
                kpStarbaseCost           : begin ParseCost(StarbaseCost, s); StarbaseCostSet:=Yes end;
                kpFreeFighterCost        : begin ParseCost(FreeFighterCost, s); FreeFighterCostSet:=Yes end;
                kpBaseFighterCost        : begin ParseCost(BaseFighterCost, s); BaseFighterCostSet:=Yes end;
                kpShipFighterCost        : begin ParseCost(ShipFighterCost, s); ShipFighterCostSet:=Yes end;
                kpMaximumFightersOnBase  : GetArray(MaximumFightersOnBase);
                kpMaximumDefenseOnBase   : GetArray(MaximumDefenseOnBase);
                { Wrap parameters: pconfig.src is always read after map.ini, so it
                  overrides its parameters, which is just what we need.
                  - map.ini is read in ReadConfig1
                  - pconfig.src is read in ReadConfig2, which is called by ReadData
                  - pconfig.src is possibly read again in ReadMessages, called by ReadData
                  MapInit is called after ReadConfig2, but not after ReadMessages,
                  causing this to break when someone changes map geometry via a
                  pconfig.src file transfer. }
                kpAllowWraparoundMap     : MapWrap:=YesNo;
                kpWraparoundRectangle    : GetWraparoundRectangle;
              end;
              sRace     : case key of
                kRace1..kRace11 : begin
                                    i:=Value(s);
                                    if i in [1..11] then Race[byte(key)-byte(kRace1)+1]:=i;
                                  end;
                          end;
              sData     : case key of
                kAcceptData0..kAcceptData11     : AcceptData[byte(key)-byte(kAcceptData0)]:=YesNo;
                          end;
              sMap      : case key of
                kmSize          : MapSize:=Min(Max(Value(s),1000),4000);
                kmWrap          : MapWrap:=YesNo;
                kmExplMap       : ExplMap:=YesNo;
              end;
            end
            else if sec=sPHOST then ReadCombatKey;
        end;
    end;
    Close(f);
    ReadConfigFile:=Yes;
  end;

const   YNStr   : array [boolean] of string[3] = ('NO','YES');

procedure WriteHConfig;
  var   f       : text;
        s       : string[6];
        s1      : string [MaxKLen];
        key     : cfgKey;
  begin
    Assign(f,addir+HCONFIG_INI);
    Writeln('Writing ',addir,HCONFIG_INI,'...');
    Rewrite(f);
    if IOResult<>0 then Exit;
    for key:=ConfKey1 to ConfKey2 do
    begin
      s:='';
      case key of
        kIsMines        : s:=YNStr[IsMines];
        kAlchemy        : s:=YNStr[Alchemy];
        kColFB          : s:=YNStr[ColFBuild];
        kRobFB          : s:=YNStr[RobFBuild];
        kRGA            : s:=YNStr[RGA];
        kSuperRefit     : s:=YNStr[SuperRefit];
        kDetectMine     : Str(DetectMineRange,s);
        kHissEffect     : Str(HissEffect,s);
        kWebMines       : s:=YNStr[WebMines];
        kSweepRate      : Str(SweepRate,s);
        kWebSweepRate   : Str(WebSweepRate,s);
        kSweepRange     : Str(SweepRange,s);
        kWebSweepRange  : Str(WebSweepRange,s);
        kESBonus        : Str(ESBonus,s);
        kFedCrew        : s:=YNStr[FedCrew];
        kGravity        : s:=YNStr[Gravity];
        kMaxIncome      : Str(MaxIncome,s);
        kCloakFB        : Str(CloakFuelBurn,s);
        kCloning        : s:=YNStr[Cloning];
        kGambling       : s:=YNStr[Gambling];
        kChunnel        : s:=YNStr[Chunnel];
        kTerraformers   : s:=YNStr[Terraformers];
        kCPDamage       : Str(CloakPreventDamage,s);
        kOneEngTow      : s:=YNStr[OneEngineTow];
        kNoFuelMove     : s:=YNStr[NoFuelMove];
        kHyperDrive     : s:=YNStr[HyperDrive];
        kGloryDevice    : s:=YNStr[GloryDevice];
        kAntiCloak      : s:=YNStr[AntiCloak];
        kAssault        : s:=YNStr[ImperialAssault];
        kAdvRef         : s:=YNStr[AdvancedRefinery];
        kBioScan        : s:=YNStr[BioScanners];
        kRamScoop       : Str(RamScoop,s);
        kTax1..kTax11   : Str(TaxRate[byte(key)-byte(kTax1)+1],s);
        kMin1..kMin11   : Str(MinRate[byte(key)-byte(kMin1)+1],s);
        kAssimilationRate         : Str(AssimilationRate,s);
        kCrystalDesertAdvantage   : s:=YNStr[CrystalsLikeDesert];
        kClimateLimitsPopulation  : s:=YNStr[ClimateLimitsPopulation];
        kpClimateDeathRate        : Str(ClimateDeathRate,s);
        kEatSupplies              : s:=YNStr[OverpopulationEatsSupplies];
        kStructureDecay           : Str(StructureDecay,s);
        kMineDecay      : Str(MineDecayRate,s);
        kWebDecay       : Str(WebMineDecayRate,s);
        kVPAExtra       : s:=YNStr[VPAExtra];
        kFF1..kFF11     : Str(FreeFighters[ord(key)-ord(kFF1)+1],s);
      end;
      if (length(s)>0) then
      begin
        ItemStr(KeyNames,word(key),s1);
        RPad(s1,MaxKLen);
        Writeln(f,s1,' = ',s);
      end
    end;
    Close(f);
    HConfChg:=No;
  end;

procedure WriteDConfig;
  var   f       : text;
        s       : string [6];
        s1      : string [MaxKLen];
        key     : cfgKey;
  begin
    Assign(f,addir+VPADATA_INI);
    Reset(f);
    if IOResult=0 then begin Close(f); Exit end;
    Writeln('Writing ',addir,VPADATA_INI,'...');
    Rewrite(f);
    if IOResult<>0 then Exit;
    for key:=DataKey1 to DataKey2 do
    begin
      case key of
        kAcceptData0..kAcceptData11     : s:=YNStr[AcceptData[byte(key)-byte(kAcceptData0)]];
      end;
      ItemStr(KeyNames,word(key),s1);
      RPad(s1,MaxKLen);
      Writeln(f,s1,' = ',s);
    end;
    Close(f);
  end;

procedure WriteRConfig;
  var   f       : text;
        i       : byte;
        s       : string [MaxKLen];
  begin
    Assign(f,addir+RACES_INI);
    Reset(f);
    if IOResult=0 then begin Close(f); Exit end;
    Writeln('Writing ',addir,RACES_INI,'...');
    Rewrite(f);
    if IOResult<>0 then Exit;
    for i:=1 to 11 do
    begin
      ItemStr(KeyNames,word(kRace1)+i-1,s);
      Writeln(f,s,' = ',Race[i]);
    end;
    Close(f);
  end;

procedure ReadMIT;
  var   f       : text;
        s       : string;
        ls      : byte absolute s;
        s1      : str20;
        ls1     : byte absolute s1;
        m,m1    : MITptr;
        n       : int;
  begin
    Assign(f,addir+'MISSION.INI');
    Reset(f);
    if IOResult<>0 then Exit;
    Writeln('Reading MISSION.INI...');
    while not Eof(f) do
    begin
      Readln(f,s);
      n:=Value(Copy(s,1,3));
      if (n>=20) and (n<=999) then
      begin
        New(m); m^.next:=nil;
        if MIT=nil then MIT:=m else m1^.next:=m;
        m1:=m;
        m^.mission:=n;
        Delete(s,1,3); Trim(s);
        n:=Pos('/',s);
        if n=0 then m^.param:=$FFE
        else begin
          s1:=Copy(s,n+1,20);
          ls:=n-1;
          Upper(s1);
          m^.param:=0;
          for n:=1 to 11 do
            if Pos(Copy('123456789AB',n,1),s1)<>0 then m^.param:=m^.param or (1 shl n);
        end;
        n:=Pos('*',s);
        if n<>0 then
        begin
          m^.param:=m^.param or MIT_I;
          Delete(s,n,1);
        end;
        n:=Pos('#',s);
        if n<>0 then
        begin
          m^.param:=m^.param or MIT_T;
          Delete(s,n,1);
        end;
        m^.name:=s;
        n:=Pos('(',m^.name);
        if n>0 then begin m^.name[0]:=char(n-1); Trim(m^.name) end;
        m^.iname:='';
        m^.tname:='';
        n:=Pos('I:',s); if n=0 then n:=Pos('i:',s);
        if n>0 then
        begin
          s1:=Copy(s,n+2,20);
          Parse(s1,m^.iname,' )'#9);
        end;
        n:=Pos('T:',s); if n=0 then n:=Pos('t:',s);
        if n>0 then
        begin
          s1:=Copy(s,n+2,20);
          Parse(s1,m^.tname,' )'#9);
        end;
      end;
    end;
    Close(f);
  end;

procedure FinishColorSetup;
  var   cpp,cpp1: cpptr;
        r       : byte;
        f       : text;
        s       : string [MaxKLen];
        s1      : string[5];
  begin
    RaceColor[0,_P_]:=cmPNeut;
    RaceColor[0,_B_]:=cmPNeut;
    RaceColor[0,_S_]:=LightGray;
    RaceColor[0,_M_]:=LightGray;
    AssignRaceColors(12,'ENEMY');
    for r:=1 to 11 do
      if RaceColor[r,_P_]=0 then
        if r=player then AssignRaceColors(r,'OWN') else
        if IsData[r] then AssignRaceColors(r,'ALLY')
                     else AssignRaceColors(r,'ENEMY');
    cpp:=cproot;                { dispose profiles }
    while cpp<>nil do
    begin
      cpp1:=cpp;
      cpp:=cpp^.next;
      Dispose(cpp1);
    end;
    if not RWMode then Exit;
    Assign(f,addir+VPACLR_INI);
    Reset(f);
    if IOResult=0 then begin Close(f); Exit end;
    Writeln('Writing ',addir,VPACLR_INI,'...');
    Rewrite(f);
    if IOResult<>0 then Exit;
    for r:=1 to 11 do
    begin
      ItemStr(KeyNames,word(kcRace1)+r-1,s);
      if r=player then s1:='OWN' else if IsData[r] then s1:='ALLY' else s1:='ENEMY';
      Writeln(f,s,' = ',s1);
    end;
    Close(f);
  end;

procedure ReadConfig1;
  begin
    InitColorProfiles;
    VPADATA_INI:='VPADAT'+plstr+'.INI';
    VPACLR_INI:='VPACLR'+plstr+'.INI';
    FileMode:=0;
    ReadConfigFile(VPA_INI,sUnknown);
    if addir[0]<>#0 then ReadConfigFile(addir+VPA_INI,sUnknown);
    ReadConfigFile(addir+VPACLR_INI,sColor);
    FinishColorSetup;
    ReadConfigFile(addir+'MAP.INI',sMap);
    ReadMIT;
  end;

procedure InitCombatCfgDefaults;
  { Fija en CombatCfg los valores por defecto de PHost (los usados por el visor
    nativo PVCRALG) ANTES de leer pconfig.src, de modo que las claves ausentes
    del fichero queden con el default de PHost. Valores tomados de PCC2ng
    (game/config/hostconfiguration.cpp, setDefaultValues). }
  procedure F (var a:IArr11; v:int);
    var i : byte;
    begin for i:=1 to 11 do a[i]:=v; end;
  procedure FL (var a:LArr11; v:longint);
    var i : byte;
    begin for i:=1 to 11 do a[i]:=v; end;
  begin
    with CombatCfg do begin
      F(BeamHitOdds,100);          F(BeamHitBonus,0);
      F(BeamRechargeRate,8);       F(BeamRechargeBonus,0);
      F(TorpHitOdds,65);           F(TorpHitBonus,0);
      F(TubeRechargeRate,45);      F(TubeRechargeBonus,0);
      F(BayRechargeRate,52);       F(BayRechargeBonus,2);
      F(BayLaunchInterval,3);
      F(ShieldDamageScaling,80);   F(ShieldKillScaling,0);
      F(HullDamageScaling,80);     F(CrewKillScaling,80);
      F(MaxFightersLaunched,19);   F(StrikesPerFighter,7);
      F(FighterMovementSpeed,235);
      F(FighterBeamExplosive,2);   F(FighterBeamKill,2);
      FL(FighterFiringRange,3000); F(FighterKillOdds,20);
      FL(BeamFiringRange,20000);   FL(BeamHitFighterRange,100000);
      F(BeamHitFighterCharge,500); F(BeamHitShipCharge,600);
      FL(TorpFiringRange,30000);
      StandoffDistance     := 3000;
      FireOnAttackFighters := No;
      PlanetsHaveTubes     := No;
    end;
  end;

procedure ReadConfig2 (RWMode:boolean);
  begin
    InitCombatCfgDefaults;
    if PHOST then PHOSTget:=PHOSTget or byte(not ReadConfigFile(addir+PCONFIG_SRC,sPHOST))
    else begin
      if (not ReadConfigFile(addir+HCONFIG_INI,sConfig)) and RWMode then WriteHConfig;
      if (not ReadConfigFile(addir+RACES_INI,sRace)) and RWMode then WriteRConfig;
    end;
    if not IsESBonus then ESBonus:=0;
    if GravityRange<=0 then Gravity:=No;
  end;

{$IFNDEF VPACC}
type    DHFRec  = record
                    h   : byte;
                    f   : HullFuncs;
                  end;
const   DefaultHullFunc : array [1..40] of DHFRec =
                        ( (h:3;f:hfHeat50), (h:3;f:hfAllWormScan), { Bohemian }
                          (h:7;f:hfAntiCloak),          { Loki }
                          (h:8;f:hfCool50),             { Eros }
                          (h:9;f:hfBioScan),            { Brynhild }
                          (h:21;f:hfCloak),             { Reptile }
                          (h:22;f:hfCloak),             { Lizard }
                          (h:25;f:hfCloak),             { Saurian }
                          (h:26;f:hfCloak),             { White Falcon }
                          (h:27;f:hfCloak),             { Swift Heart }
                          (h:28;f:hfCloak),             { Fearless Wing }
                          (h:29;f:hfAdvCloak),          { Dark Wing }
                          (h:31;f:hfAdvCloak),          { Resolute }
                          (h:32;f:hfCloak),             { Bright Heart }
                          (h:33;f:hfCloak),             { Deth Specula }
                          (h:36;f:hfCloak),             { D7 ColdPain }
                          (h:38;f:hfCloak),             { D3 Thorn }
                          (h:39;f:hfGloryDeviceH),      { D19b Nefarious }
                          (h:41;f:hfGloryDeviceL),      { Saber }
                          (h:42;f:hfGambling),          { Lady Royale }
                          (h:43;f:hfCloak),             { DwarfStar }
                          (h:44;f:hfGravitonic), (h:44;f:hfCloak), { BR4 }
                          (h:45;f:hfGravitonic), (h:45;f:hfCloak), { BR5 }
                          (h:46;f:hfGravitonic), (h:46;f:hfCloak), { Meteor }
                          (h:47;f:hfCloak),             { Red Wind }
                          (h:51;f:hfHyperDrive),        { B200 }
                          (h:56;f:hfChunneling),        { FireCloud }
                          (h:64;f:hfHeat100),           { Onyx }
                          (h:69;f:hfImperialAssault),   { SSD }
                          (h:77;f:hfHyperDrive),        { PL21 }
                          (h:84;f:hfFullBioScan),       { Pawn }
                          (h:87;f:hfHyperDrive),        { Falcon }
                          (h:96;f:hfRamScoop), (h:96;f:hfBioScan), { Cobol }
                          (h:97;f:hfAdvRefinery),       { Aries }
                          (h:104;f:hfRefinery),         { N.Refinery }
                          (h:105;f:hfAlchemy)           { Merlin }
                        );

procedure InitHullFunc;
  var   f       : text;
        hs      : file;
        fnm     : str79;
        HullFull: array [1..105,1..30] of char;
        s       : string;
        ls      : byte absolute s;
        s1,s2   : str79;
        ls1     : byte absolute s1;
        ls2     : byte absolute s2;
        l       : long;
        hull    : byte;
        func    : byte;
        size    : word;
        i       : int;
        p       : pointer;
  procedure Warning;
    begin
      Writeln(s,' in line ',l,' of ',fnm);
      GPause:=Yes;
    end;
  procedure BadValue;
    begin
      s:='Invalid value of "'+s1+'"';
      Warning;
    end;
  procedure ClearInit;
    begin
      FillChar(HullFunc^,HullFN*2,0);
    end;
  procedure DefaultInit;
    begin
      ClearInit;
      Move(DefaultHullFunc,HullFunc^,SizeOf(DefaultHullFunc));
    end;
  procedure CheckAllow (rp:byte);
    var allow   : boolean;
        rs      : string[2];
        i       : int;
    begin
      if (hull=0) or (func=255) then
      begin
        s:='Hull and Function must be set before "'+s1+'"';
        Warning;
        Exit;
      end;
      rs:=NStr0(rp);
      allow:=No;
      while ls>0 do
      begin
        Parse(s,s2,' '#9);
        if (s2='-') or (s2='-'+rs) then allow:=No else
        if (s2='+') or (s2=rs) or (s2='+'+rs) then allow:=Yes;
      end;
      i:=IsHullFunc(hull,HullFuncs(func));
      if (i<>0) and (not allow) then HullFunc^[i]:=0 else
      if (i=0) and allow then
      begin
        for i:=1 to HullFN do
          if HullFunc^[i]=0 then begin HullFunc^[i]:=func*256+hull; Exit end;
        inc(HullFN,10);
        CheckMem(HullFN*2);
        GetMem(p,HullFN*2);
        FillChar(p^,HullFN*2,0);
        Move(HullFunc^,p^,(HullFN-10)*2);
        FreeMem(HullFunc,(HullFN-10)*2);
        HullFunc:=p;
        HullFunc^[HullFN]:=func*256+hull;
      end;
    end;
  begin
    CheckMem(SizeOf(DefaultHullFunc));
    GetMem(HullFunc,SizeOf(DefaultHullFunc));
    HullFN:=SizeOf(DefaultHullFunc) div 2;
    DefaultInit;

    fnm:=addir+'HULLFUNC.TXT';
    Assign(f,fnm);
    Reset(f);
    if IOResult<>0 then Exit;
    Writeln('Reading ',fnm,'...');

    OpenData(hs,'HULLSPEC.DAT',Yes);
    for hull:=1 to 105 do
    begin
      BlockRead(hs,HullFull[hull,1],30);
      BlockRead(hs,s,30);
    end;
    CloseData(hs);

    ClearInit;
    hull:=0; func:=255;
    l:=0;
    while not Eof(f) do
    begin
      Readln(f,s); Trim(s);
      inc(l);
      if (ls=0) or (s[1] in [';','#']) then Continue;
      if Parse(s,s1,'=')=#0 then begin s:='No "=" character'; Warning; Continue end;
      RTrim(s1); LTrim(s);
      if StrCmp(s1,'Initialize',Min(ls1,10)) then
      begin
        if StrCmp(s,'Clear',Min(ls,5)) then ClearInit else
        if StrCmp(s,'Default',Min(ls,7)) then DefaultInit else
        begin BadValue; Continue end;
      end else
      if StrCmp(s1,'Hull',Min(ls1,4)) then
      begin
        hull:=Value(s);
        if (hull<1) or (hull>105) then
        begin
          hull:=105;
          while (hull>0) and (not StrCmp(s,HullFull[hull],Min(ls,30))) do dec(hull);
          if hull=0 then begin BadValue; Continue end;
        end;
      end else
      if StrCmp(s1,'Function',Min(ls1,8)) then
      begin
        if s[1] in ['0'..'9'] then func:=Value(s)
        else begin
          func:=byte(HullFunc1);
          while func<=byte(HullFunc2) do
          begin
            ItemStr(HullFuncName,func,s2);
            if StrCmp(s,s2,Min(ls,ls2)) then Break;
            inc(func);
          end;
          if func>byte(HullFunc2) then begin BadValue; func:=255; Continue end;
        end;
      end else
      if StrCmp(s1,'RacesAllowed',Min(ls1,12)) then CheckAllow(Race[player]) else
      if StrCmp(s1,'PlayersAllowed',Min(ls1,14)) then CheckAllow(player) else
      begin s:='Invalid keyword "'+s1+'"'; Warning end;
    end;
    Close(f);

    size:=HullFN*2;
    while (HullFN>1) and (HullFunc^[HullFN]=0) do dec(HullFN);
    i:=1;
    while i<HullFN do
    begin
      if HullFunc^[i]=0 then
      begin
        HullFunc^[i]:=HullFunc^[HullFN];
        dec(HullFN);
        while (HullFN>1) and (HullFunc^[HullFN]=0) do dec(HullFN);
      end;
      inc(i);
    end;
    CheckMem(HullFN*2);
    GetMem(p,HullFN*2);
    Move(HullFunc^,p^,HullFN*2);
    FreeMem(HullFunc,size);
    HullFunc:=p;
  end; { InitHullFunc }
{$ELSE}
procedure InitHullFunc;
  begin
    Hullfunc.LoadHullfuncFile;
  end;
{$ENDIF}

End.
