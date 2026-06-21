{---------------------------------------------------------------------------}
{                                                                           }
{               P l a n e t s   C o m m a n d   C e n t e r                 }
{                                                                           }
{                            2005,2006 by Streu                             }
{                                                                           }
{---------------------------------------------------------------------------}
{                                                                           }
{                          Hull Function Management                         }
{                                                                           }
{---------------------------------------------------------------------------}
{
  This manages the following information:
  - association of hull functions to hulls
    . whether function is associated to hull or newly-built ships
    . race restrictions
  - ship-specific functions
  - definition of modified functions
    . basic function + level restriction
    . the number under which PHost refers to the function

  Memory usage:
  - Tim's ship list:  10k
  - PList 3:          13.5k

  Of that, 8k is for the "per-ship functions" array and can potentially
  be saved.
}
{
  TODO:
  - Tow, PlanetImmunity specials
  - synthesize specials like 'Tow' depending on host config
}
{$I switches.inc}
UNIT Hullfunc;

INTERFACE

USES UtilFmt;

{ Underlying hull function names, same as in PHost }
CONST
  SPC_Alchemy           = 0;
  SPC_Refinery          = 1;
  SPC_AdvancedRefinery  = 2;
  SPC_HeatsTo50         = 3;
  SPC_CoolsTo50         = 4;
  SPC_HeatsTo100        = 5;
  SPC_Hyperdrive        = 6;
  SPC_Gravitonic        = 7;
  SPC_ScansAllWormholes = 8;
  SPC_Gambling          = 9;
  SPC_AntiCloak         = 10;
  SPC_ImperialAssault   = 11;
  SPC_Chunneling        = 12;
  SPC_Ramscoop          = 13;
  SPC_FullBioscan       = 14;
  SPC_AdvancedCloak     = 15;
  SPC_Cloak             = 16;
  SPC_Bioscan           = 17;
  SPC_GloryDeviceLow    = 18;
  SPC_GloryDeviceHigh   = 19;
  SPC_Unclonable        = 20;
  SPC_CloneOnce         = 21;
  SPC_Ungiveable        = 22;
  SPC_GiveOnce          = 23;
  SPC_Level2Tow         = 24;
  SPC_Tow               = 25;
  SPC_ChunnelSelf       = 26;
  SPC_ChunnelOthers     = 27;
  SPC_ChunnelTarget     = 28;
  SPC_PlanetImmunity    = 29;
  SPC_OreCondenser      = 30;
  SPC_Boarding          = 31;
  SPC_AntiCloakImmunity = 32;
  SPC_Academy           = 33;
  SPC_Repairs           = 34;
  SPC_FullWeaponry      = 35;
  SPC_HardenedEngines   = 36;
  SPC_Commander         = 37;
  SPC_IonShield         = 38;
  SPC_HardenedCloak     = 39;
  SPC_AdvancedAntiCloak = 40;

CONST
  ALL_LEVELS  = (1 SHL 11) - 1;
  ALL_PLAYERS = (1 SHL 12) - 2;

  FIRST_SYNTH = 100;

TYPE
  THullFunctionAssignment = (asHull, asNewShips, asShip, asRace);

TYPE
  THullFunction = RECORD
                    { Basic hull function (e.g. 1=Refinery) }
                    BasicFunction : INTEGER;
                    { Level mask. Set of 1 SHL Level }
                    LevelMask     : INTEGER;
                    { Player mask. Set of 1 SHL Player }
                    RaceMask      : INTEGER;
                    { For modified functions, the number under which
                      this function is known to the host }
                    HostId        : INTEGER;
                    { How this function is assigned to the ship }
                    AssignedTo    : THullFunctionAssignment;
                  END;
  PHullFunction = ^THullFunction;

TYPE
  THullFunctionArray = ARRAY[1..1000] OF THullFunction;
  PHullFunctionArray = ^THullFunctionArray;

CONST
  hf_NoNewShips        = 1;   { EnumHullfuncsForHull: no functions for new ships only }
  hf_NoRacialAbilities = 2;   { do not include racial abilities in list }

PROCEDURE InitHullfunc;
PROCEDURE DoneHullfunc;
PROCEDURE LoadHullfuncFile;
PROCEDURE AddSpecialDef(CONST sd : Util57SpecialDef);
PROCEDURE AddShipFunctions(VAR data; size : INTEGER);

FUNCTION EnumHullfuncsForHull(hull      : INTEGER;
                              ptr       : PHullFunctionArray;
                              index     : INTEGER;
                              racemask  : INTEGER;
                              levelmask : INTEGER;
                              flags     : INTEGER) : INTEGER;
FUNCTION EnumHullfuncsForShip(ship  : INTEGER;
                              ptr   : PHullFunctionArray;
                              index : INTEGER;
                              flags : INTEGER) : INTEGER;
FUNCTION ShipDoes(sid : INTEGER; f1, f2, f3 : INTEGER):BOOLEAN;
FUNCTION HullDoes(hull : INTEGER; f1, f2, f3 : INTEGER; ownermask:INTEGER; levelmask:INTEGER;
                  flags : INTEGER):BOOLEAN;
FUNCTION ShipOrHullDoes(sid : INTEGER; f1, f2, f3 : INTEGER):BOOLEAN;

FUNCTION ShipHasAnySpecificHullfunc(sid : INTEGER) : BOOLEAN;

FUNCTION GetBasicFunctionName(f : INTEGER):STRING;
FUNCTION GetBasicFunctionTitle(f : INTEGER):STRING;
FUNCTION GetBasicFunctionByName(CONST s : STRING):INTEGER;

TYPE TSortFunction = FUNCTION (CONST a, b : THullFunction; arg : INTEGER) : BOOLEAN;

PROCEDURE SortHullfuncArray(ptr : PHullFunctionArray; len : INTEGER; sf : TSortFunction; arg : INTEGER);
FUNCTION  SortForNewShip(CONST a, b : THullFunction; arg : INTEGER):BOOLEAN;

FUNCTION FormatLevelMask(lm : INTEGER):STRING;
FUNCTION FormatRaceMask(rm : INTEGER):STRING;

FUNCTION HaveAnyRacialAbilities : BOOLEAN;

TYPE
  THullFuncSelection = RECORD
                         ship_id            : INTEGER; { ship Id, -1 for new ships }
                         hull_id            : INTEGER; { hull Id }
                         filter_owner_mask  : INTEGER; { owner mask (-1 = everyone) }
                         filter_level_mask  : INTEGER; { level mask (-1 = all levels) }
                         display_owner_mask : INTEGER;
                         display_level_mask : INTEGER;
                       END;

FUNCTION EnumHullfuncs(CONST select : THullFuncSelection;
                       ptr          : PHullFunctionArray;
                       index        : INTEGER;
                       more_flags   : INTEGER) : INTEGER;

IMPLEMENTATION 

{$IFDEF VPA}
{============================================================

   Porting Interface: VPA

 ============================================================}
USES PHostM, VPAData, StrF, ccFileUtil, VPACC;

PROCEDURE MemoryFailure;
BEGIN
  Writeln(#13#10'Out of memory.');
  Halt;
END; { MemoryFailure }

FUNCTION GetShipExperience(sid : INTEGER):INTEGER;
BEGIN
  GetShipExperience := ShipExperience(sid);
END; { GetShipExperience }

FUNCTION GetPossibleExperienceLevels : INTEGER;
BEGIN
  IF PHOST THEN
    GetPossibleExperienceLevels := 2*(1 SHL NumExperienceLevels) - 1
  ELSE
    GetPossibleExperienceLevels := 1;
END;

FUNCTION IsFunctionExistOnThisHost(f : INTEGER):BOOLEAN;
BEGIN
  CASE f OF
    SPC_Tow .. SPC_HardenedEngines:     IsFunctionExistOnThisHost := PHOST AND (PHOSTver >= '4.0i');
    SPC_Commander .. SPC_HardenedCloak: IsFunctionExistOnThisHost := PHOST AND (PHOSTver >= '4.0j');
    SPC_Unclonable .. SPC_Level2Tow:    IsFunctionExistOnThisHost := PHOST AND (PHOSTver >= '4.0');
    SPC_ScansAllWormholes: IsFunctionExistOnThisHost := PHOST;
  ELSE
    IsFunctionExistOnThisHost := TRUE;
  END;
END; { IsFunctionExistOnThisHost }

FUNCTION Upstr(s : STRING):STRING;
BEGIN
  Upper(s);
  Upstr := s;
END; { Upstr }

{
  Split string S at Divider. Returns left/right part in LI/RE.
}
PROCEDURE Split(S,Divider:STRING; VAR Li,Re:STRING);
VAR i:INTEGER;
BEGIN
  Li:='';
  Re:='';
  i:=Pos(Divider,S);
  IF i=0 THEN Li:=S ELSE BEGIN
    Li:=Copy(S,1,i-1);
    Re:=Copy(S,i+Length(Divider),255);
  END;
END; { Split }

PROCEDURE Strip(VAR s:STRING);
BEGIN
  Trim(s);
END;  
{$ELSE}
{============================================================

   Porting Interface: PCC

 ============================================================}
USES Global, PHost, PConfig, Swapper, ShipAcc, LowLevel, Objects, ccFileUtil, User;

PROCEDURE MemoryFailure;
BEGIN
  Cancel(OutofMemory);
END; { MemoryFailure }

{
  Get experience level of a ship.
}
FUNCTION GetShipExperience(sid : INTEGER):INTEGER;
BEGIN
  GetShipExperience := GetExperienceLevel(TRUE, sid);
END;

{
  Get bitfield of all possible experience levels. Used to filter display.
  (Could also return ALL_LEVELS, this would display the contents of
  hullfunc.txt without adapting to the config)
}
FUNCTION GetPossibleExperienceLevels : INTEGER;
BEGIN
  IF pconf<>NIL THEN BEGIN
    GetPossibleExperienceLevels := 2*(1 SHL pconf^.main.NumExperienceLevels) - 1
  END ELSE BEGIN
   {$IFDEF ccShips}
    GetPossibleExperienceLevels := ALL_LEVELS;
   {$ELSE}
    GetPossibleExperienceLevels := 1;
   {$ENDIF}
  END;
END; { GetPossibleExperienceLevels }

{
  Check whether the specified function exists on this host. If we know that
  it does not exist, do not show it.
}
FUNCTION IsFunctionExistOnThisHost(f : INTEGER):BOOLEAN;
BEGIN
  CASE f OF
   {$IFDEF Client}
    SPC_Tow .. SPC_HardenedEngines:     IsFunctionExistOnThisHost := (pconf<>NIL) AND (HostVersion >= 400009);
    SPC_Commander .. SPC_HardenedCloak: IsFunctionExistOnThisHost := (pconf<>NIL) AND (HostVersion >= 400010);
    SPC_Unclonable .. SPC_Level2Tow:    IsFunctionExistOnThisHost := (pconf<>NIL) AND (HostVersion >= 400000);
   {$ENDIF}
    SPC_ScansAllWormholes: IsFunctionExistOnThisHost := (pconf<>NIL);
  ELSE
    IsFunctionExistOnThisHost := TRUE;
  END;
END; { IsFunctionExistOnThisHost }
{$ENDIF}

{******************************** Tables *******************************}

CONST
  NUM_FUNCTIONS = 40;

CONST
  HullfuncNames : ARRAY[0 .. NUM_FUNCTIONS] OF STRING[21] = (
    'Alchemy', 'Refinery', 'AdvancedRefinery', 'HeatsTo50', 'CoolsTo50',
    'HeatsTo100', 'Hyperdrive', 'Gravitonic', 'ScansAllWormholes', 'Gambling',
    'AntiCloak', 'ImperialAssault', 'Chunneling', 'Ramscoop', 'FullBioscan',
    'AdvancedCloak', 'Cloak', 'Bioscan', 'GloryDeviceLowDamage', 'GloryDeviceHighDamage',
    'Unclonable', 'CloneOnce', 'Ungiveable', 'GiveOnce', 'Level2Tow',
    'Tow', 'ChunnelSelf', 'ChunnelOthers', 'ChunnelTarget', 'PlanetImmunity',
    'OreCondenser', 'Boarding', 'AntiCloakImmunity', 'Academy', 'Repairs',
    'FullWeaponry', 'HardenedEngines', 'Commander', 'IonShield',
    'HardenedCloak', 'AdvancedAntiCloak'
  );

{
  Given a function name (from hullfunc.txt), get its Id.
  Returns -1 on error
}
FUNCTION GetBasicFunctionByName(CONST s : STRING):INTEGER;
VAR
  i, j : INTEGER;
BEGIN
  Val(s, i, j);
  IF j > 1 THEN Val(Copy(s, 1, j-1), i, j);
  IF (j = 0) THEN BEGIN
    IF (i >= 0) AND (i <= NUM_FUNCTIONS) THEN GetBasicFunctionByName := i
    ELSE GetBasicFunctionByName := -1;
  END ELSE BEGIN
    FOR i:=0 TO NUM_FUNCTIONS DO BEGIN
      IF (Length(HullfuncNames[i]) >= Length(s))
        AND (UpStr(s) = UpStr(Copy(HullfuncNames[i], 1, Length(s))))
        THEN BEGIN
          GetBasicFunctionByName := i;
          Exit;
        END;
    END;
    GetBasicFunctionByName := -1;
  END;
END;

{************************** Modified Functions *************************}

{
  Internally, we identify every function with a 16-bit integer, called
  "Id". The following convention applies:
    0 .. NUM_FUNCTIONS    unmodified function
    > FIRST_SYNTH         modified function
  Each function can be defined by a pair of
    BasicFunction         0 .. NUM_FUNCTIONS, the underlying function
    LevelMask             mask of experience levels where this applies
  (potentially, more modifiers follow in future PHost versions)

  In addition, we store HostId, which is the number PHost uses to refer
  to that function, which need not correspond to our Ids. All this is
  stored in a THullFunction structure (the .RaceMask and .AssignedTo
  fields are ignored here).

  GetFunctionId() maps a THullFunction into an integer.
}

VAR
  synth_num, synth_alloc : INTEGER;
  synth_ptr              : PHullFunctionArray;

{
  Given a complete hull function spec, return an integer handle we use to
  refer to that function.

  Returns -1 for unknown functions.
}
FUNCTION GetFunctionId(CONST hf : THullFunction) : INTEGER;
VAR
  lm, i : INTEGER;
  p     : PHullFunctionArray;
BEGIN
  lm := ALL_LEVELS;
  { do we know the basic function? }
  IF (hf.BasicFunction < 0) OR (hf.BasicFunction > NUM_FUNCTIONS) THEN BEGIN
    GetFunctionId := -1;
    Exit;
  END;
  { is it a basic function that needs no definition? }
  IF ((hf.LevelMask AND lm) = lm) AND (hf.HostId < 0) THEN BEGIN
    GetFunctionId := hf.BasicFunction;
    Exit;
  END;
  { figure out whether we know it }
  FOR i:=1 TO synth_num DO BEGIN
    IF (synth_ptr^[i].BasicFunction = hf.BasicFunction)
      AND (synth_ptr^[i].LevelMask = hf.LevelMask AND lm)
    THEN BEGIN
      IF synth_ptr^[i].HostId < 0 THEN
       synth_ptr^[i].HostId := hf.HostId;
      GetFunctionId := FIRST_SYNTH + i;
      Exit;
    END;
  END;
  { we do not know it, create it }
  IF synth_num >= synth_alloc THEN BEGIN
    i := 2*synth_alloc;
    IF i < 16 THEN i:=16;
    p := Realloc(i * Sizeof(THullFunction), synth_ptr, synth_alloc * Sizeof(THullFunction));
    IF p=NIL THEN MemoryFailure;
    synth_ptr := p;
    synth_alloc := i;
  END;
  Inc(synth_num);
  synth_ptr^[synth_num] := hf;
  synth_ptr^[synth_num].LevelMask := synth_ptr^[synth_num].LevelMask AND lm;
  GetFunctionId := FIRST_SYNTH + synth_num;
END; { GetFunctionId }

{
  Get definition of a hull function.
  Initializes hf.BasicFunction, .LevelMask, .HostId.
}
PROCEDURE GetFunctionDef(id : INTEGER; VAR hf : THullFunction);
BEGIN
  IF (id >= 0) AND (id <= NUM_FUNCTIONS) THEN BEGIN
    hf.BasicFunction := id;
    hf.LevelMask := ALL_LEVELS;
    hf.HostId := id;
  END ELSE IF (id > FIRST_SYNTH) AND (id <= FIRST_SYNTH + synth_num) THEN BEGIN
    hf := synth_ptr^[id - FIRST_SYNTH];
  END ELSE BEGIN
    FillChar(hf, Sizeof(hf), 0);
  END;
END; { GetFunctionDef }

{
  Get our Id for the hull function with the given HostId.
  Returns -1 if there is no such function.
}
FUNCTION GetFunctionFromHostId(hostid : INTEGER) : INTEGER;
VAR i : INTEGER;
BEGIN
  GetFunctionFromHostId := -1;
  IF (hostid >= 0) AND (hostid <= NUM_FUNCTIONS) THEN BEGIN
    GetFunctionFromHostId := hostid;
  END ELSE IF hostid > 0 THEN BEGIN
    FOR i:=1 TO synth_num DO
      IF synth_ptr^[i].HostId = hostid THEN BEGIN
        GetFunctionFromHostId := i + FIRST_SYNTH;
        Break;
      END;
  END;
END;

{********************* Functions assigned to hulls *********************}

{
  This corresponds to the stuff stored in hullfunc.txt / shiplist.txt.

  We store an array of THullAssignData for each hull, with at most one
  instance of each function per hull. This way, we can easily handle
  removal of races ('RacesAllowed = -5'). In addition, we have to know
  whether the assignment goes to ships or hulls, so we can distinguish
  between datasheets for new ships (=show all assignments) and those
  for existing ships (=only functions assigned to the hull; those assigned
  to the ship will come out the Ship interface).
}

TYPE
  THullAssignData = RECORD
                       Id         : INTEGER;
                       RaceMask   : INTEGER;
                       AssignedTo : THullFunctionAssignment;
                     END;
  THullAssignList  = ARRAY[1..1000] OF THullAssignData;
  PHullAssignList  = ^THullAssignList;
  THullAssignEntry = RECORD
                       p            : PHullAssignList;
                       count, alloc : INTEGER;
                     END;
  PHullAssignEntry = ^THullAssignEntry;
  THullAssignArray = ARRAY[0..MaxHulls] OF THullAssignEntry;
  PHullAssignArray = ^THullAssignArray;

VAR hull_funcs : PHullAssignArray;

{
  Modify a ship's functions

    hull      hull number
    id        our function Id
    addraces  add these races
    remraces  and remove these races
    asgn      type of assignment (asNewShips or asHull)
}
PROCEDURE AddFunctionToHull(hull : INTEGER; id : INTEGER;
                            addraces, remraces : INTEGER;
                            asgn : THullFunctionAssignment);
VAR
  phae : PHullAssignEntry;
  i    : INTEGER;
BEGIN
  IF (hull < 0) OR (hull > HullCnt) THEN Exit;
  phae := @hull_funcs^[hull];
  FOR i:=1 TO phae^.count DO BEGIN
    IF (phae^.p^[i].Id = id) AND (phae^.p^[i].AssignedTo = asgn) THEN BEGIN
      phae^.p^[i].RaceMask := (phae^.p^[i].RaceMask OR addraces) AND NOT remraces;
      Exit;
    END;
  END;
  IF addraces AND NOT remraces = 0 THEN Exit;

  { add new entry }
  IF phae^.count >= phae^.alloc THEN BEGIN
    i := 2*phae^.alloc;
    IF i < 8 THEN i := 8;
    phae^.p := Realloc(Sizeof(THullAssignData)*i, phae^.p, Sizeof(THullAssignData)*phae^.alloc);
    IF phae^.p=NIL THEN MemoryFailure;
    phae^.alloc := i;
  END;
  Inc(phae^.count);
  phae^.p^[phae^.count].Id := Id;
  phae^.p^[phae^.count].RaceMask := addraces AND NOT remraces;
  phae^.p^[phae^.count].AssignedTo := asgn;
END;

{
  Enumerate functions associated with a hull

    hull       hull number
    ptr        pointer to enumeration, or nil
    index      current position into array
    racemask   list only items available to these races
    levelmask  list only items available to any of these levels
    flags      options
                  hf_NoNewShips
                    exclude items assigned to ships when they're built

  Returns updated index.
}
FUNCTION EnumHullfuncsForHull(hull      : INTEGER;
                              ptr       : PHullFunctionArray;
                              index     : INTEGER;
                              racemask  : INTEGER;
                              levelmask : INTEGER;
                              flags     : INTEGER) : INTEGER;
VAR
  i    : INTEGER;
  phad : ^THullAssignData;
  hf   : THullFunction;
LABEL again;
BEGIN
  racemask := racemask AND ALL_PLAYERS;
  levelmask := levelmask AND GetPossibleExperienceLevels;
  IF (hull > 0) AND (hull <= HullCnt) THEN BEGIN
   Again:
    FOR i:=1 TO hull_funcs^[hull].count DO BEGIN
      phad := @hull_funcs^[hull].p^[i];
      IF (phad^.RaceMask AND racemask<>0)
        AND ((phad^.AssignedTo <> asNewShips) OR (flags AND hf_NoNewShips = 0))
      THEN BEGIN
        GetFunctionDef(phad^.id, hf);
        IF (hf.LevelMask AND levelmask<>0) AND IsFunctionExistOnThisHost(hf.BasicFunction) THEN BEGIN
          Inc(index);
          IF ptr<>NIL THEN BEGIN
            hf.AssignedTo := phad^.AssignedTo;
            hf.RaceMask := phad^.RaceMask;
            ptr^[index] := hf;
          END;
        END;
      END;
    END;
    IF (hull<>0) AND (flags AND hf_NoRacialAbilities = 0) THEN BEGIN
      hull := 0;
      GOTO Again;
    END;
  END;
  EnumHullfuncsForHull := index;
END; { EnumHullfuncsForHull }

{
  Check whether a hull does one of a set of functions

    hull        hull number
    f1, f2, f3  check these functions
    ownermask, levelmask, flags
                see EnumHullfuncsForHull
}
FUNCTION HullDoes(hull : INTEGER; f1, f2, f3 : INTEGER; ownermask:INTEGER; levelmask:INTEGER;
                  flags : INTEGER):BOOLEAN;
VAR
  i, n : INTEGER;
  phad : ^THullAssignData;
  hf   : THullFunction;
LABEL Again;
BEGIN
  IF (hull <= 0) OR (hull > HullCnt) THEN BEGIN
    HullDoes := FALSE;
    Exit;
  END;
 Again:
  FOR i:=1 TO hull_funcs^[hull].count DO BEGIN
    phad := @hull_funcs^[hull].p^[i];
    IF (phad^.RaceMask AND ownermask<>0)
      AND ((phad^.AssignedTo <> asNewShips) OR (flags AND hf_NoNewShips = 0))
    THEN BEGIN
      GetFunctionDef(phad^.id, hf);
      IF (hf.BasicFunction = f1) OR (hf.BasicFunction = f2) OR (hf.BasicFunction = f3) THEN BEGIN
        IF (hf.LevelMask AND levelmask<>0) AND IsFunctionExistOnThisHost(hf.BasicFunction) THEN BEGIN
          HullDoes := TRUE;
          Exit;
        END;
      END;
    END;
  END;
  IF (hull<>0) AND (flags AND hf_NoRacialAbilities = 0) THEN BEGIN
    hull := 0;
    GOTO Again;
  END;
  HullDoes := FALSE;
END; { HullDoes }

{
  Find racial abilities. A racial ability is a function which is
  assigned to all ship classes of a race.
}
PROCEDURE FindRacialAbilities;
VAR
  fun_idx  : INTEGER;
  hid, fid : INTEGER;
  thad     : THullAssignData;
  phad     : ^THullAssignData;
  mask     : INTEGER;
  found    : BOOLEAN;
BEGIN
  FOR fun_idx:=1 TO hull_funcs^[1].count DO BEGIN
    thad := hull_funcs^[1].p^[fun_idx];
    IF thad.AssignedTo = asHull THEN BEGIN
      mask := thad.RaceMask AND ALL_PLAYERS;
      FOR hid := 2 TO HullCnt DO BEGIN
        found := FALSE;
        FOR fid := 1 TO hull_funcs^[hid].count DO BEGIN
          phad := @hull_funcs^[hid].p^[fid];
          IF (phad^.Id = thad.Id) AND (phad^.AssignedTo = asHull) THEN BEGIN
            mask := mask AND phad^.RaceMask;
            found := TRUE;
            Break;
          END;
        END;
        IF NOT found OR (mask = 0) THEN BEGIN
          mask := 0;
          Break;
        END;
      END;
      IF mask<>0 THEN BEGIN
        AddFunctionToHull(0, thad.Id, mask, 0, asRace);
        FOR hid := 1 TO HullCnt DO BEGIN
          FOR fid := 1 TO hull_funcs^[hid].count DO BEGIN
            phad := @hull_funcs^[hid].p^[fid];
            IF (phad^.Id = thad.Id) AND (phad^.AssignedTo = asHull) AND (phad^.RaceMask = mask) THEN
              phad^.RaceMask := 0;
          END;
        END;
      END;
    END;
  END;
END;

{********************* Functions assigned to Ships *********************}

{
  For each ship that has a function individually assigned to it,
  this stores an array of HostIds. There is no need to handle ownership
  restrictions or assignment types here.
}
TYPE
  TShipFunctionList  = ARRAY[1..1000] OF INTEGER;
  PShipFunctionList  = ^TShipFunctionList;
  TShipFunctionEntry = RECORD
                         p            : PShipFunctionList;
                         count, alloc : INTEGER;
                       END;
  PShipFunctionEntry = ^TShipFunctionEntry;
  TShipFunctionArray = ARRAY[1..NUM_SHIPS] OF TShipFunctionEntry;
  PShipFunctionArray = ^TShipFunctionArray;

VAR ship_funcs : PShipFunctionArray;

{ Add a function to a ship }
PROCEDURE AddFunctionToShip(sid : INTEGER; hostid : INTEGER);
VAR
  psfe : PShipFunctionEntry;
  i    : INTEGER;
BEGIN
  IF (sid <= 0) OR (sid > NUM_SHIPS) THEN Exit;
  psfe := @ship_funcs^[sid];
  FOR i:=1 TO psfe^.count DO
    IF psfe^.p^[i] = hostid THEN Exit;

  { it's not yet there, add it }
  IF psfe^.count >= psfe^.alloc THEN BEGIN
    i := 2*psfe^.alloc;
    IF i < 8 THEN i := 8;
    psfe^.p := Realloc(2*i, psfe^.p, 2*psfe^.alloc);
    IF psfe^.p=NIL THEN MemoryFailure;
    psfe^.alloc := i;
  END;
  Inc(psfe^.count);
  psfe^.p^[psfe^.count] := hostid;
END;

{
  Enumerate functions for a ship

  ship    Ship Id
  ptr     Array of THullFunction of sufficient size, can be 0
  index   First available index in array /ptr/
  flags   currently unused

  Returns updated index. To figure out the "sufficient size" for
  the array, first call this function with ptr=0.
}
FUNCTION EnumHullfuncsForShip(ship  : INTEGER;
                              ptr   : PHullFunctionArray;
                              index : INTEGER;
                              flags : INTEGER) : INTEGER;
VAR
  i  : INTEGER;
  n  : INTEGER;
  lm : INTEGER;
  hf : THullFunction;
BEGIN
  lm := GetPossibleExperienceLevels;
  IF (ship > 0) AND (ship <= NUM_SHIPS) THEN BEGIN
    FOR i:=1 TO ship_funcs^[ship].count DO BEGIN
      n := GetFunctionFromHostId(ship_funcs^[ship].p^[i]);
      IF n >= 0 THEN BEGIN
        GetFunctionDef(n, hf);
        IF (hf.LevelMask AND lm <> 0) AND IsFunctionExistOnThisHost(hf.BasicFunction) THEN BEGIN
          Inc(index);
          IF ptr<>NIL THEN BEGIN
            hf.RaceMask := -1;
            hf.AssignedTo := asShip;
            ptr^[index] := hf;
          END;
        END;
      END;
    END;
  END;
  EnumHullfuncsForShip := index;
END; { EnumHullfuncsForShip }

{
  Check whether ship does any of the three functions
}
FUNCTION ShipDoes(sid : INTEGER; f1, f2, f3 : INTEGER):BOOLEAN;
VAR
  i, n : INTEGER;
  hf   : THullFunction;
  lm   : INTEGER;
BEGIN
  IF (sid <= 0) OR (sid > NUM_SHIPS) THEN BEGIN
    ShipDoes := FALSE;
    Exit;
  END;
  lm := ALL_LEVELS;
  FOR i:=1 TO ship_funcs^[sid].count DO BEGIN
    n := GetFunctionFromHostId(ship_funcs^[sid].p^[i]);
    IF n >= 0 THEN BEGIN
      GetFunctionDef(n, hf);
      IF (hf.BasicFunction = f1) OR (hf.BasicFunction = f2) OR (hf.BasicFunction = f3) THEN BEGIN
        n := GetShipExperience(sid);
        IF ((hf.LevelMask = lm)
            OR ((n >= 0) AND (hf.LevelMask AND (1 SHL n) <> 0)))
          AND IsFunctionExistOnThisHost(hf.BasicFunction)
        THEN BEGIN
          ShipDoes := TRUE;
          Exit;
        END;
      END;
    END;
  END;
  ShipDoes := FALSE;
END; { ShipDoes }

FUNCTION EnumHullfuncs(CONST select : THullFuncSelection;
                       ptr : PHullFunctionArray;
                       index : INTEGER;
                       more_flags : INTEGER):INTEGER;
BEGIN
  IF select.ship_id > 0 THEN BEGIN
    index := EnumHullfuncsForHull(select.hull_id,
                                  ptr, index,
                                  select.filter_owner_mask,
                                  select.filter_level_mask,
                                  hf_NoNewShips OR more_flags);
    index := EnumHullfuncsForShip(select.ship_id,
                                  ptr, index,
                                  more_flags);
  END ELSE BEGIN
    index := EnumHullfuncsForHull(select.hull_id,
                                  ptr, index,
                                  select.filter_owner_mask,
                                  select.filter_level_mask,
                                  more_flags);
  END;
  EnumHullfuncs := index;
END;

{**************************** Hullfunc File ****************************}

{
  Initialize defaults.

  This should load the same defaults for all hosts. Host version handling
  is done at the time we're reading out the lists. Rationale: we do not
  necessarily know the host version when we're loading this. Maybe players
  even change the config on-the-fly.
}
PROCEDURE LoadDefaultHullfuncs;
VAR
  i : INTEGER;
CONST
  num_cloakers = 15;
  cloakers : ARRAY[1..num_cloakers] OF BYTE =
        (21, 22, 25, 26, 27, 28, 32, 33, 36, 38, 43, 44, 45, 46, 47);
BEGIN
  { Bohemian }
  AddFunctionToHull(3, SPC_HeatsTo50,         ALL_PLAYERS, 0, asHull);
  AddFunctionToHull(3, SPC_ScansAllWormholes, ALL_PLAYERS, 0, asHull);
  { Loki }
  AddFunctionToHull(7, SPC_AntiCloak,         ALL_PLAYERS, 0, asHull);
  { Eros }
  AddFunctionToHull(8, SPC_CoolsTo50,         ALL_PLAYERS, 0, asHull);
  { Brynhild }
  AddFunctionToHull(9, SPC_Bioscan,           ALL_PLAYERS, 0, asHull);
  { Darkwing }
  AddFunctionToHull(29, SPC_AdvancedCloak,    ALL_PLAYERS, 0, asHull);
  { Resolute }
  AddFunctionToHull(31, SPC_AdvancedCloak,    ALL_PLAYERS, 0, asHull);
  { D19b }
  AddFunctionToHull(39, SPC_GloryDeviceHigh,  ALL_PLAYERS, 0, asHull);
  { Saber }
  AddFunctionToHull(41, SPC_GloryDeviceLow,   ALL_PLAYERS, 0, asHull);
  { Lady Royale }
  AddFunctionToHull(42, SPC_Gambling,         ALL_PLAYERS, 0, asHull);
  { BR4, BR5, MBR }
  FOR i:=44 TO 46 DO
    AddFunctionToHull(i, SPC_Gravitonic,      ALL_PLAYERS, 0, asHull);
  { B200 }
  AddFunctionToHull(51, SPC_Hyperdrive,       ALL_PLAYERS, 0, asHull);
  { Firecloud }
  AddFunctionToHull(56, SPC_Chunneling,       ALL_PLAYERS, 0, asHull);
  { Onyx }
  AddFunctionToHull(64, SPC_HeatsTo100,       ALL_PLAYERS, 0, asHull);
  { SSD }
  AddFunctionToHull(69, SPC_ImperialAssault,  ALL_PLAYERS, 0, asHull);
  { PL21 }
  AddFunctionToHull(77, SPC_Hyperdrive,       ALL_PLAYERS, 0, asHull);
  { Pawn }
  AddFunctionToHull(84, SPC_FullBioscan,      ALL_PLAYERS, 0, asHull);
  { Falcon }
  AddFunctionToHull(87, SPC_Hyperdrive,       ALL_PLAYERS, 0, asHull);
  { Cobol }
  AddFunctionToHull(96, SPC_Ramscoop,         ALL_PLAYERS, 0, asHull);
  AddFunctionToHull(96, SPC_Bioscan,          ALL_PLAYERS, 0, asHull);
  { Aries }
  AddFunctionToHull(97, SPC_AdvancedRefinery, ALL_PLAYERS, 0, asHull);
  { NRS }
  AddFunctionToHull(104, SPC_Refinery,        ALL_PLAYERS, 0, asHull);
  { Merlin }
  AddFunctionToHull(105, SPC_Alchemy,         ALL_PLAYERS, 0, asHull);

  FOR i:=1 TO num_cloakers DO
    AddFunctionToHull(cloakers[i], SPC_Cloak, ALL_PLAYERS, 0, asHull);
END; { LoadDefaultHullfuncs }

{
  Clear everything. Same as 'Initialize=Clear'.
}
PROCEDURE LoadBlankHullfuncs;
VAR i : INTEGER;
BEGIN
  FOR i:=0 TO HullCnt DO
    hull_funcs^[i].count := 0;
END;

{
  Parse hullfunc.txt file.

   fn      file name
   in_sec  whether we already are in the correct section
}
FUNCTION LoadHullfuncPart(CONST fn : STRING; in_sec : BOOLEAN):BOOLEAN;
VAR
  buf        : TBuf;
  s, s1, s2  : STRING;
  i, j, k, l : INTEGER;

VAR
  Hull     : SET OF BYTE;
  AssignTo : THullFunctionAssignment;
  Level    : INTEGER;
  Func     : INTEGER;

  PROCEDURE ParseAllowed(VAR s, tmp : STRING; race:BOOLEAN);
  VAR
    Add, Rem : INTEGER;
    v        : INTEGER;
    i, j     : INTEGER;
    neg      : BOOLEAN;
    hf       : THullFunction;
  BEGIN
    { Bail out early if we have a problem }
    IF Func < 0 THEN Exit;

    { Figure out what to add and remove }
    Add := 0;
    Rem := 0;
    WHILE s<>'' DO BEGIN
      Split(s, ' ', tmp, s);
      IF tmp<>'' THEN BEGIN
        IF (tmp='*') OR (tmp='+') THEN BEGIN
          Add := ALL_PLAYERS;
          Rem := 0;
        END ELSE IF (tmp='-') THEN BEGIN
          Add := 0;
          Rem := ALL_PLAYERS;
        END ELSE BEGIN
          IF tmp[1]='-' THEN BEGIN
            neg := TRUE;
            Delete(tmp,1,1);
          END ELSE neg := FALSE;
          Val(tmp, i, j);
          IF j=0 THEN BEGIN
            v := 0;
            IF race THEN BEGIN
              FOR j:=1 TO 11 DO IF RaceIDs[j]=i THEN Inc(v, 1 SHL j);
            END ELSE BEGIN
              IF (i>0) AND (i<=11) THEN v:=1 SHL i;
            END;
            IF neg THEN BEGIN
              Add := Add AND NOT v;
              Rem := Rem OR v;
            END ELSE BEGIN
              Add := Add OR v;
              Rem := Rem AND NOT v;
            END;
          END;
        END;
      END;
    END;

    { Now do it }
    hf.LevelMask := Level;
    hf.BasicFunction := Func;
    hf.HostId := -1;
    j := GetFunctionId(hf);
    IF j >= 0 THEN
      FOR i:=1 TO HullCnt DO
        IF i IN Hull THEN
          AddFunctionToHull(i, j, Add, Rem, AssignTo);
  END;

BEGIN
  OpenFile(fn, 0);
  IF ofStream=NIL THEN BEGIN
    LoadHullfuncPart := FALSE;
    Exit;
  END;

  LoadBlankHullfuncs;
  InitBuf(ofStream, buf);
  Hull := [];
  AssignTo := asHull;
  Level := ALL_LEVELS;
  Func := -1;
  WHILE FileError=0 DO BEGIN
    ReadStr(ofStream, s, buf);
    i := Pos('#', s);
    IF i<>0 THEN s[0] := Chr(i-1);
    FOR i:=1 TO Length(s) DO IF s[i]=#9 THEN s[i]:=' ';
    Strip1(s);
    IF (s='') THEN BEGIN
      { comment or blank line }
    END ELSE IF (s[1]='%') THEN BEGIN
      Delete(s, 1, 1);
      Strip1(s);
      in_sec := Upstr(s) = 'HULLFUNC';
    END ELSE IF in_sec THEN BEGIN
      i := Pos('=', s);
      IF i<>0 THEN BEGIN
        s1 := Copy(s, 1, i-1);
        Delete(s, 1, i);
        Strip1(s1);
        Strip1(s);
        IF PMatch('AssignTo', s1) THEN BEGIN
          IF PMatch('Ship', s) THEN AssignTo := asNewShips ELSE
          IF PMatch('Hull', s) THEN AssignTo := asHull;
        END ELSE IF PMatch('Hull', s1) THEN BEGIN
          Hull := [];
          WHILE s<>'' DO BEGIN
            Split(s,',',s1,s);
            IF (s1[1]>='0') AND (s1[1]<='9') THEN BEGIN
              { numeric }
              Split(s1,'-',s1,s2);
              Strip1(s1);
              Strip1(s2);
              Val(s1, k, j);
              IF (j>1) THEN Val(Copy(s1,1,j-1), k, j);
              IF (j=0) AND (k>0) AND (k<=HullCnt) THEN BEGIN
                IF s2='' THEN BEGIN
                  Include(Hull, k);
                END ELSE BEGIN
                  Val(s2, l, j);
                  IF (j>1) THEN Val(Copy(s,1,j-1), l, j);
                  IF (j=0) AND (l<=HullCnt) THEN BEGIN
                    WHILE (k <= l) DO BEGIN
                      Include(Hull, k);
                      Inc(k);
                    END;
                  END;
                END;
              END;
            END ELSE BEGIN
              { name or '*' }
              Strip1(s1);
              IF s1='*' THEN BEGIN
                Hull := [1 .. HullCnt];
              END ELSE BEGIN
                s1 := UpStr(s1);
                FOR i:=1 TO HullCnt DO BEGIN
                  {$IFDEF VPA}
                  s2 := Hulls[i].Name;
                  Upper(s2);
                  {$ELSE}
                  s2 := UpStr(GetStr(Hulls^[i].Name, 30));
                  {$ENDIF}
                  IF (Length(s1) <= Length(s2)) AND (Copy(s2, 1, Length(s1)) = s1) THEN BEGIN
                    Include(Hull, i);
                    Break;
                  END;
                END;
              END;
            END;
          END;
        END ELSE IF PMatch('Function', s1) THEN BEGIN
          Func := GetBasicFunctionByName(s);
        END ELSE IF PMatch('RacesAllowed', s1) THEN BEGIN
          ParseAllowed(s, s1, TRUE);
          Level := ALL_LEVELS;
        END ELSE IF PMatch('PlayersAllowed', s1) THEN BEGIN
          ParseAllowed(s, s1, FALSE);
          Level := ALL_LEVELS;
        END ELSE IF PMatch('Initialize', s1) THEN BEGIN
          IF PMatch('Clear', s) THEN LoadBlankHullfuncs ELSE
          IF PMatch('Default', s) THEN LoadDefaultHullfuncs;
        END ELSE IF PMatch('Level', s1) THEN BEGIN
          Split(s,'-',s1,s2);
          Strip(s1);
          Strip(s2);
          Val(s1, k, j);
          IF (j=0) AND (k>=0) AND (k<=10) THEN BEGIN
            IF s2='' THEN l := 10 ELSE BEGIN
              Val(s2, l, j);
              IF j<>0 THEN l := 10;
            END;
            Level := 0;
            WHILE k <= l DO BEGIN
              Inc(Level, 1 SHL k);
              Inc(k);
            END;
            Level := Level AND ALL_LEVELS;
          END;
        END;
      END;
    END;
  END;
  CloseFile;
  LoadHullfuncPart := TRUE;
END;

{*************************** Public Interface **************************}

{
  Get name of a basic function
}
FUNCTION GetBasicFunctionName(f : INTEGER):STRING;
VAR s : STRING[7];
BEGIN
  IF (f >= 0) AND (f <= NUM_FUNCTIONS) THEN BEGIN
    GetBasicFunctionName := HullfuncNames[f];
  END ELSE BEGIN
    Str(f, s);
    GetBasicFunctionName := '<' + s + '>';
  END;
END; { GetBasicFunctionName }

FUNCTION GetBasicFunctionTitle(f : INTEGER):STRING;
{$I hullfunc.inc}
BEGIN
  IF (f >= 0) AND (f <= NUM_FUNCTIONS) THEN BEGIN
    GetBasicFunctionTitle := STRING(Ptr(DSeg, HullfuncNames[f+1])^);
  END ELSE BEGIN
    GetBasicFunctionTitle := GetBasicFunctionName(f);
  END;
END;

{
  Add definition of ship function from util.dat
}
PROCEDURE AddSpecialDef(CONST sd : Util57SpecialDef);
VAR
  hf : THullFunction;
BEGIN
  hf.BasicFunction := sd.func;
  hf.LevelMask := sd.levelmask AND ALL_LEVELS;
  hf.HostId := sd.id;
  GetFunctionId(hf);
END;

{
  Add ship functions from util.dat
}
PROCEDURE AddShipFunctions(VAR data; size : INTEGER);
VAR
  a : ARRAY[0 .. 1000] OF INTEGER ABSOLUTE data;
  i : INTEGER;
BEGIN
  FOR i := 1 TO (size DIV 2) - 1 DO
    AddFunctionToShip(a[0], a[i]);
END; { AddShipFunctions }

{
  Initialize hull function management
}
PROCEDURE InitHullfunc;
BEGIN
  ship_funcs := Malloc(Sizeof(TShipFunctionArray));
  IF ship_funcs=NIL THEN MemoryFailure;
  hull_funcs := Malloc(Sizeof(THullAssignEntry) * (HullCnt + 1));
  IF hull_funcs=NIL THEN MemoryFailure;
  synth_num := 0;
  synth_alloc := 0;
  synth_ptr := NIL;
END; { InitHullfunc }

{
  Shut down hull function management
}
PROCEDURE DoneHullfunc;
VAR
  i : INTEGER;
BEGIN
  FreeMem(synth_ptr, synth_alloc * Sizeof(THullFunction));
  synth_num := 0;
  synth_alloc := 0;
  synth_ptr := NIL;
  FOR i:=1 TO NUM_SHIPS DO
    IF ship_funcs^[i].alloc<>0 THEN
      FreeMem(ship_funcs^[i].p, 2*ship_funcs^[i].alloc);
  FreeMem(ship_funcs, Sizeof(TShipFunctionArray));
  ship_funcs := NIL;
  FOR i:=0 TO HullCnt DO
    IF hull_funcs^[i].alloc<>0 THEN
      FreeMem(hull_funcs^[i].p, Sizeof(THullAssignData)*hull_funcs^[i].alloc);
  FreeMem(hull_funcs, Sizeof(THullAssignEntry) * (HullCnt + 1));
  hull_funcs := NIL;
END; { DoneHullfunc }

PROCEDURE LoadHullfuncFile;
BEGIN
  IF NOT (LoadHullfuncPart('shiplist.txt', FALSE)
          OR LoadHullfuncPart('hullfunc.txt', TRUE))
  THEN LoadDefaultHullfuncs;
  FindRacialAbilities;
END; { LoadHullfuncFile }

{******************************* Sorting *******************************}

{
  Sort an array of hull functions
}
PROCEDURE SortHullfuncArray(ptr : PHullFunctionArray; len : INTEGER; sf : TSortFunction; arg : INTEGER);
VAR
  tmp : THullFunction;
  i   : INTEGER;
BEGIN
  i := 2;
  WHILE i <= len DO BEGIN
    IF sf(ptr^[i], ptr^[i-1], arg) THEN BEGIN
      tmp := ptr^[i-1];
      ptr^[i-1] := ptr^[i];
      ptr^[i] := tmp;
      IF i > 2 THEN Dec(i);
    END ELSE Inc(i);
  END;
END; { SortHullfuncArray }

FUNCTION CompareLevelMask(a, b : INTEGER):BOOLEAN;
VAR
  la, lb : INTEGER;
BEGIN
  la := 0;
  WHILE (a AND (1 SHL la) = 0) AND (la < 16) DO Inc(la);
  lb := 0;
  WHILE (b AND (1 SHL lb) = 0) AND (lb < 16) DO Inc(lb);
  IF la<>lb THEN
    CompareLevelMask := la < lb
  ELSE
    CompareLevelMask := a > b;
END;

{ Sort by function Id, then by level, then by player, then by assigned status.
  Arg is player mask. }
FUNCTION SortForNewShip(CONST a, b : THullFunction; arg : INTEGER):BOOLEAN;
BEGIN
  IF (a.AssignedTo = asRace) <> (b.AssignedTo = asRace) THEN
    SortForNewShip := (a.AssignedTo = asRace) < (b.AssignedTo = asRace)
  ELSE IF ((a.RaceMask AND arg)=0) <> ((b.RaceMask AND arg)=0) THEN
    SortForNewShip := ((a.RaceMask AND arg)=0) < ((b.RaceMask AND arg)=0)
  ELSE IF a.LevelMask <> b.LevelMask THEN
    SortForNewShip := CompareLevelMask(a.LevelMask, b.LevelMask)
  ELSE IF a.BasicFunction <> b.BasicFunction THEN
    SortForNewShip := a.BasicFunction < b.BasicFunction
  ELSE IF a.RaceMask <> b.RaceMask THEN
    SortForNewShip := a.RaceMask > b.RaceMask
  ELSE
    SortForNewShip := a.AssignedTo < b.AssignedTo;
END;

{****************************** Formatting *****************************}

FUNCTION FormatLevelMask(lm : INTEGER):STRING;
VAR
  am : INTEGER;
  i  : INTEGER;
  s  : STRING[63];
BEGIN
  am := GetPossibleExperienceLevels;
  lm := lm AND am;
  IF lm = am THEN BEGIN
    FormatLevelMask := '';
  END ELSE IF lm = 0 THEN BEGIN
    FormatLevelMask := 'no level';
  END ELSE IF (lm AND (lm-1) = 0) THEN BEGIN
    { one level }
    i := 0;
    WHILE (lm AND (1 SHL i) = 0) DO
      Inc(i);
    FormatLevelMask := 'level ' + itoa(i);
  END ELSE BEGIN
    i := 0;
    WHILE lm AND (1 SHL i) = 0 DO Inc(i);
    { now, i is the minimum level. }
    IF lm OR ((1 SHL i)-1) = am THEN BEGIN
      { valid from level i onwards }
      FormatLevelMask := 'level ' + itoa(i) + '+';
    END ELSE BEGIN
      { mixed bag }
      s := '';
      WHILE i <= 10 DO BEGIN
        IF lm AND (1 SHL i) <> 0 THEN BEGIN
          IF s<>'' THEN CatChar(s, ',');
          s := s + itoa(i);
        END;
        Inc(i);
      END;
      FormatLevelMask := 'levels ' + s;
    END;
  END;
END; { FormatLevelMask }

FUNCTION FormatRaceMask(rm : INTEGER):STRING;
VAR
  n, i : INTEGER;
  s    : STRING[63];
BEGIN
  rm := rm AND ALL_PLAYERS;
  IF (rm = ALL_PLAYERS) THEN BEGIN
    FormatRaceMask := '';
  END ELSE IF (rm = 0) THEN BEGIN
    FormatRaceMask := 'nobody';
  END ELSE IF (rm AND (rm-1) = 0) THEN BEGIN
    { one race }
    i := 1;
    WHILE (rm AND (1 SHL i) = 0) AND (i < 12) DO
      Inc(i);
    FormatRaceMask := 'player ' + itoa(i);
  END ELSE BEGIN
    n := (NOT rm) AND ALL_PLAYERS;
    IF (n AND (n-1) = 0) THEN BEGIN
      { all but one race }
      i := 1;
      WHILE (n AND (1 SHL i) = 0) AND (i < 12) DO
        Inc(i);
      FormatRaceMask := 'all but player ' + itoa(i);
    END ELSE BEGIN
      { mixed bag }
      s := '';
      FOR i:=1 TO 11 DO
        IF rm AND (1 SHL i) <> 0 THEN BEGIN
          IF s<>'' THEN CatChar(s, ',');
          s := s+itoa(i);
        END;
      FormatRaceMask := 'players ' + s;
    END;
  END;
END; { FormatRaceMask }

{ All-in-one test }
FUNCTION ShipOrHullDoes(sid : INTEGER; f1, f2, f3 : INTEGER):BOOLEAN;
VAR n : INTEGER;
BEGIN
  IF ShipDoes(sid, f1, f2, f3) THEN BEGIN
    ShipOrHullDoes := TRUE;
  END ELSE BEGIN
    n := GetShipExperience(sid);
    IF n >= 0 THEN n := 1 SHL n;
    {$IFDEF VPA}
    ShipOrHullDoes := HullDoes(TTurn^.data^.ship[sid]^.hull, f1, f2, f3,
                               1 SHL RealShipOwner(sid),
                               n,
                               hf_NoNewShips);
    {$ELSE}
    ShipOrHullDoes := HullDoes(HullNumber(sid), f1, f2, f3,
                               1 SHL RealShipOwner(sid),
                               n,
                               hf_NoNewShips);
    {$ENDIF}
  END;
END; { ShipOrHullDoes }

{ Check whether ship has any hullfunc assigned to the ship
  (and not to the class) }
FUNCTION ShipHasAnySpecificHullfunc(sid : INTEGER) : BOOLEAN;
BEGIN
  ShipHasAnySpecificHullfunc := (sid > 0) AND (sid <= NUM_SHIPS) AND (ship_funcs^[sid].count<>0);
END; { ShipHasAnySpecificHullfunc }

FUNCTION HaveAnyRacialAbilities : BOOLEAN;
BEGIN
  HaveAnyRacialAbilities := hull_funcs^[0].count <> 0;
END;

END.
