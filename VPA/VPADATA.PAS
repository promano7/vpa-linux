{
*******************************************************************
* VPADATA.PAS - Mainpart DATA Structures
*
* $Id: vpadata.pas,v 1.116 2013/12/29 06:41:03 sfplanets Exp $
*
*******************************************************************
}

{$I switches.inc}
Unit    VPAData;        (* VPA Data Structures *)
{$V-}


Interface

uses    Mouse,AuxF,StrF,ptcgraph, Config; 

const   Version = '3.67.1';
        VerNum  = 367;

const   NUM_SHIPS    = 999;
        NUM_PLANETS  = 500;
        NUM_MINES    = 500;
        NUM_MAX      = 999;

type    IArr11  = array [1..11] of int;
        EArr    = array [1..10] of int;   { modificadores de experiencia (EMod*), por nivel 1..NumExperienceLevels }
        fcstr   = array [1..3] of char;
{$IFOPT N-}
        single  = real;
        double  = real;
{$ENDIF}

type    pptr    = ^PRec;
        PRec    = record
                    when0       : int;  { earliest data }
                    when        : int;  { latest data }
{ dat---> }         owner       : int;                  (* mandatory *)
                    {number     : int;  - in .dat only}
                    fcode       : fcstr;
                    mines       : int;
                    factories   : int;
                    defense     : int;
                    N,T,D,M     : long; { on surface }  { Dark Sense: }
                    colonists   : long;                 { N,T,D,M<>-1 }
                    supplies    : long;                 { Nc,Tc,Dc,Mc=-1 }
                    funds       : long;
                    Nc,Tc,Dc,Mc : long; { in core }     { =-2 for UTIL.DAT }
                    Nm,Tm,Dm,Mm : int;  { 100 mines per 1 turn }
                    Ctax,Ntax   : int;
                    Cstat,Nstat : int;
                    Ngovt       : int;
                    natives     : long;
                    Nrace       : int;
                    climate     : int;
{ dat---> }         build       : int;
                  end;
        bptr    = ^BRec;
        BRec    = record
{ dat---> }         {planet     : int; - in .dat only}
                    owner       : int;                  (* mandatory *)
                    defense     : int;
                    damage      : int;
                    El,Hl,Wl,Tl : int;
                    EE          : array [1..9] of int;
                    HH          : array [1..20] of int;
                    WW,LL,TT    : array [1..10] of int;
                    fighters    : int;
                    fShip,fOp   : int;
                    order       : int;
{ dat---> }         cHl,cEl,cWl,cWn,cTl,cTn,cBn : int;
                  end;
        sptr    = ^SRec;
        SRec    = record
                    when        : int;
{ dat---> }         {number     : int; - in .dat only}
                    owner       : int;                  (* mandatory *)
                    fcode       : fcstr;
                    warp        : int;
                    wx,wy       : int;  { waypoint }
                    x,y         : int;  { location }    (* mandatory *)
                    El,hull,Wl,weapons,bays,Tl,TFnum,launchers  : int;
                    mission     : int;  { if mission=-1 then enemy=heading }
                    enemy       : int;  {               else wx,wy - waypoint }
                    tow_ship    : int;
                    damage      : int;
                    crew        : int;
                    colonists   : int;
                    name        : array [1..20] of char;
                    fuel        : int;
                    T,D,M,Sup   : int;
                    CN,CT,CD,CM,CC,CS,CPl       : int;  { Unload/Jettison }
                    TN,TT,TD,TM,TC,TS,TSh       : int;  { Transfer }
                    intr_ship   : int;
{ dat---> }         credits     : int;
                    mass,mass1,mass2    : int;
                    px1,py1,px2,py2     : int;
                    ship_id     : int;  { added by Stefan Reuther. Must be last. NOT STORED IN DATABASE. }
                  end;
        STRec   = record
{ dat---> }         {number     : int; - in .dat only}
                    owner       : int;
                    warp        : int;
                    x,y         : int;
                    hull        : int;
                    heading     : int;
{ dat---> }         name        : array [1..20] of char;
                  end;
        SVRec   = record
{ dat---> }         x,y         : int;
                    owner       : int;
{ dat---> }         mass        : int;
                  end;
        mptr    = ^MRec;
        MRec    = record
                    when        : int;
                    x,y         : int;
                    owner       : int;
                    units       : long;
                    web         : int;  { bit 0 - web, bit 1 - from KORE }
                  end;
        MKRec   = record        { mine record in KORE.DAT }
                    x,y         : int;
                    radius      : int;
                    owner       : int;
                  end;
        iptr    = ^IRec;
        IRec    = record
                    x,y         : int;
                    radius      : int;
                    voltage     : int;
                    heading     : int;
                    warp        : byte;
                    grow        : boolean;
                    px1,py1,px2,py2     : int;
                  end;
        uptr    = ^URec;
        URec    = record
                    when        : int;
{ dat---> }         color       : int;
                    name        : array [1..20] of char;
                    info        : array [1..2,1..20] of char;
                    x,y         : int;
                    warp        : int;
                    heading     : int;
                    rangeP      : int;
                    rangeS      : int;
                    radius      : int;
{ dat---> }         parent      : int;
                    px1,py1,px2,py2     : int;
                  end;
        wptr    = ^WRec;
        WRec    = record
                    when        : int;
                    x,y         : int;
                    mass        : int;
                    stable      : int;
                  end;
        EPln    = record
                    when        : int;  { for sensor sweep }
                    owner       : byte;
                    activity    : byte;
                      { bits 0-2        (and 7)         = industrial activity
                        bit  7          (and 128)       = base  }
                  end;
const   EP_Activity     = 7;    { mask for all industrial activity }
        EP_Base         = 128;  { mask for base }
        EP_NoBase       = 64;   { mask for no base }

        { these bits in newplan[i] indicate which fields are from this turn }
        NP_Owner        = 1;
        NP_NTDM_Funds   = 2;
        NP_MFD_FCode    = 4;
        NP_CPop         = 8;
        NP_NRace_NPop   = 16;
        NP_Climate      = 32;
        NP_Base         = 64;
        NP_Supplies     = 128;
        NP_See_It       = 63+128;

type    MarkType= (mrkNone,mrkFlag,mrkCircle,mrkCross,mrkSquare,
                   mrkRhombe,mrkPoint,mrkRCircle,mrkLine,mrkDLine,
                   mrkGrave,mrkCactus,mrkFlag1,mrkFlag2,mrkFlag3,
                   mrkArrow1,mrkArrow2,mrkArrow3,mrkArrow4,
                   mrkArrow5,mrkArrow6,mrkArrow7,mrkArrow8,
                   mrkNe,mrkTr,mrkDu,mrkMo,mrkSkull);
const   LastMark= mrkSkull;
type    MapMark = record
                    mtype       : MarkType;
                    color       : byte;
                    x,y         : int;
                    bind        : int;  { msgn if > 0, ship id if < 0 }
                    case byte of
                      0 : (text         : word;         { for all others }
                           xalg,yalg    : byte);
                      1 : (word0        : word;         { for RCircle }
                           radius       : word);
                      2 : (dx,dy        : int)          { for Line, DLine }
                  end;
        Marks   = array [1..2047] of MapMark;
const
    MarkMaskMax = 15;
var
    MarkXAlg : byte;
    MarkYAlg : byte;
    MarkGroup : array[MarkType] of String[15];
    LastMarkMask : int;
    MarkMask : array[0..MarkMaskMax] of String[127];
    CurMarkMask : int;

        zz                      : int; {Quapla BUG}
        
type MineExplosionRecordPtr = ^MineExplosionRecord;
     MineExplosionRecord = record
          x1,y1,mid1 : word;
          x2,y2,mid2 : word;
          units : long;
          next : MineExplosionRecordPtr;
        end;
var MineExplosions : MineExplosionRecordPtr;

type    ShipSortRecord = record
                           Id   : word;
                           Key  : word;
                           Key2 : word;
                           Icon : MarkType;
                           Color: byte;
                         end;
        ShipSortArray = array[1..NUM_SHIPS] OF ShipSortRecord;
var
        ShipSortTableType     : word;
const
        NO_ICON                  = mrkNone;
        NO_COLOR                 = 0;
        ICON_SHIP_BEFORE_PLANET  = mrkCircle;
        COLOR_SHIP_BEFORE_PLANET = Blue;
        ICON_SHIP_AFTER_PLANET   = mrkCircle;
        COLOR_SHIP_AFTER_PLANET  = Green;
        ICON_SHIP_NO_FUEL        = mrkCross;
        COLOR_SHIP_NO_FUEL       = Red;
        ICON_SHIP_NO_FC          = mrkCircle;
        COLOR_SHIP_NO_FC         = Yellow;
        ICON_SHIP_NO_FIGHT       = mrkRhombe;
        COLOR_SHIP_NO_FIGHT      = Brown;
        ICON_SHIP_PASSIVE        = mrkRhombe;
        COLOR_SHIP_PASSIVE       = White;


        ICON_SHIP_OWN_DESIGN     = mrkSquare;
        COLOR_SHIP_OWN_DESIGN    = Green;

        COLOR_SHIP_TOWED              = Green;
        COLOR_SHIP_TOWED_BY_TWO_SHIPS = Red;
        COLOR_SHIP_TOWED_HAS_WARP     = Yellow;
        ICON_SHIP_TOWED               = mrkCross;
        ICON_SHIP_TOWING              = mrkSquare;
        COLOR_SHIP_TOWING             = Green;

        ShipSortTableMaxType     = 3;

type
        ShipExpData   = array[1..NUM_SHIPS] of shortint;
        PlanetExpData = array[1..NUM_PLANETS] of shortint;
        BuildQData    = array[0..NUM_PLANETS] of int;      {0: Last Base that built, 1..NUM: 1 = built}
        boolptr = ^boolean;

type
        tdptr           = ^TurnData;
        TurnData        = record
                            planet      : array [1..500] of pptr;
                            base        : array [1..500] of bptr;
                            ship        : array [1..999] of sptr;
                            mines       : array [1..500] of mptr;
                            ion         : array [1..50]  of iptr;
                            worm        : array [0..199] of wptr;
                            ufo         : array [1..100] of uptr;
                            eplan       : array [1..500] of EPln;
                            newplan     : array [1..500] of byte;
                            xyplan      : array [1..500,1..2] of int;

                            nmark       : int;
                            mark        : ^Marks;
                            mtsize      : word;
                            mtext       : ^ByteArr;
                            ipos,opos,vpos : long;      { f.positions of msg blocks }
                            inum,onum,vnum : int;       { # of msgs in .db }
                            mopos          : long;      { f.pos of msgobj block }
                            shipexp        : ^ShipExpData;
                            planetexp      : ^PlanetExpData;
                            buildQ         : ^BuildQData;       {last Base that built}
                          end;

        Score4          =       array [1..4] of int;
        ScoreList       =       array [1..11] of Score4; { PCFB }
        PBPList         =       array [1..11] of int;
        tptr    = ^TRec;
        TRec    = record
                    prev,next   : tptr;
                    turn        : int;
                    fpos        : long;
                    unk         : boolean;      { unknown blocks present }
                    score       : ScoreList;
                    IsPBP       : boolean;
                    PBP         : PBPList;
                    data        : tdptr;
                  end;

{        Planett = record
                    x,y         : int;
                    name        : array [1..20] of char;
                  end;}

        HullType= record
                    name        : array [1..18] of char;
                    pic         : int;
                    maxmass     : int;
                    T,D,M       : int;
                    fuel        : int;
                    crew        : int;
                    engines     : int;
                    mass        : int;
                    tech        : int;
                    cargo       : int;
                    bays,launchers,weapons      : int;
                    cost        : int;
                  end;
        EngType = record
                    name        : array [1..18] of char;
                    cost        : int;
                    T,D,M       : int;
                    tech        : int;
                    burn        : array [1..9] of long;
                  end;
        BeamType= record
                    name        : array [1..18] of char;
                    cost        : int;
                    T,D,M       : int;
                    mass        : int;
                    tech        : int;
                    kill,expl   : int;
                  end;
        TorpType= record
                    name        : array [1..6] of char;
                    cost,tcost  : int;  { cost = torp, tcost = tube! }
                    T,D,M       : int;
                    mass        : int;
                    tech        : int;
                    kill,expl   : int;
                  end;
        MITptr  = ^MITmisn;
        MITmisn = record
                    next        : MITptr;
                    mission     : int;
                    name        : string[18];
                    iname,tname : string[12];
                    param       : word;         { bit mask: 1 shl race }
                  end;                          { I = $8000, T = 1 }
        { Price for an item, allowing for supplies not just TDM$.
          Used for PHost 4.1 price options. }
        TFullPrice = record
                  MC,Tri,Dur,Mol: int;
                  Supplies      : int;
        end;
        T11Costs = array[1..11] of TFullPrice;
const
                MIT_I   = $8000;
        MIT_T   = 1;

                DBHeader        : array [1..14] of char = 'VPA Database'#13#10;
        DBVersion       : byte = 6;
        DBHeadLen       = 15;

        PRecordSize     = 85;           { planet }
        BRecordSize     = 156;          { base }
        SRecordSize     = 107;          { ship }
        STRecordSize    = 34;           { target }
        MRecordSize     = 8;            { mines in KOREn.DAT }
        IRecordSize     = 12;           { ions in KOREn.DAT }
        URecordSize     = 78;           { UFO in KOREn.DAT }

type    DBlock          = record
                            tag         : long;
                            size        : long;
                            number      : int;
                          end;
        TimeStamp       = array [1..18] of char;
        TBlock          = record
                            tag         : long;
                            size        : long;
                            number      : int;
                            stamp       : TimeStamp;
                            score       : ScoreList;
                          end;

(*
        VPA.db ver 6 file structure:

        DBHeader        14
        DBVersion       1

        T_TAG           4
        Size            4
        Turn number     2
        TimeStamp       18              { stamp[1] = #0 means no stamp }
        Score           88
        Turn data       Size
        ...

        T_TAG           4
        Size            4
        Turn number     2
        TimeStamp       18
        Score           88
        Turn data       Size
        ...

        Turn data structure:

        Data block TAG  4
        Size            4
        # of records    2
        Data block      Size

        Planet record:
        id number       2
        PRec            SizeOf(PRec)

        Incoming message data block:
        message headers N*6
        message data    Size-N*6        (Size from DBlock)

        Incoming message header:
        offset from start       4
        length                  2

        Outgoing message data block:
        message headers N*10
        message data    Size-N*10       (Size from DBlock)

        Outgoing message header:
        offset from # of recs   4       (# of recs from DBlock)
        length                  2
        from                    2
        to                      2

*)

const
        T_TAG   = $4E525554;    { TURN } 
        P_TAG   = $4E414C50;    { PLAN }
        B_TAG   = $45534142;    { BASE }
        S_TAG   = $50494853;    { SHIP }
        M_TAG   = $454E494D;    { MINE }
        I_TAG   = $534E4F49;    { IONS }
        U_TAG   = $534F4655;    { UFOS }
        W_TAG   = $4D524F57;    { WORM }
        E_TAG   = $4E4C5045;    { EPLN }
        N_TAG   = $4E4C504E;    { NPLN }
        A_TAG   = $4B52414D;    { MARK }
        V_TAG   = $53524356;    { VCRS }
        IM_TAG  = $47534D49;    { IMSG }
        OM_TAG  = $47534D4F;    { OMSG }
        MO_TAG  = $4F47534D;    { MSGO }
        PP_TAG  = $53504250;    { PBPS }
        VE_TAG  = $53524556;    { VERS }
        PH_TAG  = $54534850;    { PHST }
        PW_TAG  = $53534150;    { PASS }
        SC_TAG  = $524F4353;    { SCOR }
        RE_TAG  = $53464552;    { REFS }
        XY_TAG  = $4C505958;    { XYPL }
        PEXP_TAG = $50584550;   { PEXP } 
        SEXP_TAG = $50584553;   { SEXP }
        BQ_TAG  = $51444c42;    { BLDQ } 

        TurnVer : int = 0;

    TRoot   : tptr = nil;
        TEnd    : tptr = nil;

        LockLo  = $07FF;        { lo and hi lock masks }
        LockHi  = $7800;        { 16 types * 2047 objects supported }
        LockP   = $0800;        { planet }
        LockS   = $1000;        { ship }
        LockB   = $4000;        { base }
        LockM   = $1800;        { minefield }
        LockI   = $2000;        { ion storm }
        LockA   = $2800;        { marker }
        LockW   = $3000;        { wormhole }
        LockU   = $3800;        { UFO }
   { Only used for actlist: }
   LockSkipS    = $0001;
   LockSkipP    = $0002;

    addir   : string[67] = '';
    lock    : int = 0;
    ltype   : int = 0;
        force   : int = 0;
    distlock: int = 0;
        dll     : int = 468;
        SWPlan  : boolean = Yes;
        RegWP   : boolean = No;
        RegVPA  : boolean = No;
        RWMode  : boolean = Yes;
        NewTurn : boolean = No;
    DFiles  : boolean = Yes;
    GPause  : boolean = No;
        Batch   : boolean = No;
        MaySave : boolean = No;
        PHOST   : boolean = No;

var
        PHOSTver: string[7];

{ Table with distance computation results for Tim-Host. We do not store
  all distances; instead, we just store a '1' bit if the value increases
  at this point. }
type TDistanceTable = array[1..168, 0..20] of byte;
     PDistanceTable = ^TDistanceTable;

const distance_table : PDistanceTable = nil;

const
        NatRace : array [0..10] of string[10] =
                ('','Humanoid','Bovinoid','Reptilian','Avian','Amorphous',
                 'Insectoid','Amphibian','Ghipsoldal','Siliconoid','??????????');
        NatGovt : array [0..9] of string[14] =
                ('Communism!!!','Anarchy','Pre-Tribal','Early Tribal','Tribal',
                 'Feudal','Monarchy','Representative','Participatory','Unity');
        NatGRate : array [0..9] of string[14] =
                ('','20%','40%','60%','80%','100%','120%','140%','160%','180%');
        Missions: array [0..15] of string[12] =
                ('','Exploration','Mine Sweep','Lay Mines','KILL!!!',
                 'Sensor Sweep','Colonize','Tow','Intrcept','','Cloak',
                 'Beam Up Fuel','Beam Up Du','Beam Up Tr','Beam Up Mo','Beam Up Supp');
        SpecMisn: array [1..11] of string[12] =
                ('Super Refit','Hissssss!','Super Spy','Pillage','Rob Ship','Repair Self',
                 'Web Mines','Dark Sense','Bld Fighters','Grnd Attack','Bld Fighters');
        BaseOrd : array [0..6] of string[17]=
                ('','Refuel','Maximize Defense','Load Torpedoes','Unload Freighters','Repair Base','Force a Surrender');
        Industry: array [0..5] of string[11] =
                ('Strange','Minimal','Light','Moderate','Substantial','Heavy');
        IonGrow : array [boolean] of string[9] = ('weakening','growing');
        IonLevel: array [1..5] of string[15] =
                ('Harmless','Moderate','Strong','Dangerous','Very DANGEROUS!');
        Stability: array [0..6] of string[18] =
                ('Strange','Very stable','Stable','Mostly stable',
                 'Unstable','Very unstable','Completely unstabl');
        Stability2: array [0..6] of string[18] =
                ('Strange','( 0% -  5%)','( 5% - 15%)','(15% - 30%)',
                 '(30% - 50%)','(50% - 80%)','(80% - 100%)');

type
        climate = (Arctic,Cool,Warm,Tropic,Desert);
        MFDtype = (_Mine,_Factory,_Defense);
        TLtype  = (_El,_Hl,_Wl,_Tl);
const
        ClimStr : array [climate] of string[6] = ('Arctic','Cool','Warm','Tropic','Desert');
        TScale  : array [climate] of byte = (0,15,40,65,85);
        mfdFNum : array [MFDtype] of int = (200,100,50);
        mfdCost : array [MFDtype] of int = (4,3,10);
        TechRace: array [TLtype] of int = (8,1,7,9);
        MIT     : MITptr = nil;

    MinSM   : int = 1000;
        MaxSM   : int = 0;
        today   : int = 0;
        Stamp   : TimeStamp = #0#0#0#0#0#0#0#0#0#0#0#0#0#0#0#0#0#0;

{var     Planets : array [1..500] of Planett;}
var
        PlanName: array [1..500,1..20] of char;
        StormName:array [1..50,1..20] of char;
        Hulls   : array [0..105] of HullType;
        Engines : array [1..9] of EngType;
        Beams   : array [1..10] of BeamType;
        Torps   : array [1..10] of TorpType;
        wmm,tmm : int;          { weap and torp max mass }
        RaceHull: array [1..11,1..20] of word;
        RaceName: array [0..12,1..12] of char;
        RaceFull: array [1..12,1..30] of char;
        pname   : array [1..20] of char;
        player  : int;
        plstr   : string[2];
        dbname  : filename;
        TTurn   : tptr;
        TPrev   : tptr;
        turn    : int;
        lship   : sptr;
        lplan   : pptr;
        lbase   : bptr;
        cloneID : int;          { ship ID to be cloned }
        splan   : array [1..999] of int;
        chuns   : boolean;
        actlist : array [0..NUM_MAX] of int; { actlist[0] is turn number }
var
        rcflags : array[1..NUM_SHIPS] of byte;
        alliance: array[0..4,1..11,1..11] of byte;

const
        IsData  : array [-1..11] of boolean = (No,No,No,No,No,No,No,No,No,No,No,No,No);
        Race    : array [1..12] of int = (1,2,3,4,5,6,7,8,9,10,11,12);
        TrueHullByRace  : boolean = Yes;
        TaxRate : IArr11 = (200,100,100,100,100,100,100,100,100,100,100);
        TaxCRate : IArr11 = (200,100,100,100,100,100,100,100,100,100,100);
        TaxNRate : IArr11 = (200,100,100,100,100,100,100,100,100,100,100);
        TaxNBound : IArr11 = (100,100,100,100,100,20,100,100,100,100,100);
        MinRate : IArr11 = (70,200,100,100,100,100,100,100,100,100,100);
        FreeFighters : IArr11 =  (  0,  0,  0,  0,  0,  0,  0,  5,  0,  0,  0); 
        ProductionRate: IArr11 = (100,100,100,100,100,100,100,100,100,100,100);
        GroundKillFactor:IArr11= (1,30,1,15,1,1,1,1,1,1,1);
        GroundDefenseFactor:IArr11= (1,10,1,5,1,1,1,1,1,1,1);

        MaxColTempSlope : int = 1000;
        ClimateLimitsPopulation : boolean = Yes;
        ClimateDeathRate : int = 10;
        NativeClimateDeathRate : int = 0;
        CrystalsLikeDesert: boolean = Yes;
        CrystalSinTemp  : boolean = No;
        RaceGrowthRate : Iarr11 = (100,100,100,100,100,100,100,100,100,100,100);
        {TODO: use GrowthRate for calculation of required clans for growth}
        AssimilationRate : int = 100;
        OverpopulationEatsSupplies : boolean = No;
        IsHiss          : boolean = Yes;
        HissEffect      : byte = 5;
        MaxShipsHissing : int = 999; { Is this THost limit ??? PW }
        DetectMineRange : int = 200;
        WebMines        : boolean = Yes;
        SweepRate       : int = 4;
        WebSweepRate    : int = 3;
        SweepRange      : int = 5;
        WebSweepRange   : int = 0;
        FighterSweepRange : IArr11 = (0,0,0,0,0,0,0,0,0,0,100);
        FighterSweepRate  : IArr11 = (0,0,0,0,0,0,0,0,0,0,20);
        AllowColoniesSweepWebs : boolean = No;
        UnitsPerTorpRate : IArr11 = (100,100,100,100,100,100,100,100,400,100,100);
        MineHitDamageFor100KT : int = 100;
        WebHitDamageFor100KT  : int = 10;
        MineDecayRate   : int = 5;
        WebMineDecayRate: int = 5;
        StructureDecay  : int = 1;
        MineHitOdds     : int = 1;
        WebMineHitOdds  : int = 5;
        MineHitOddsWhenCloakedX10 : int = 5;
        IsESBonus       : boolean = Yes;
        ESBonus         : byte = 50;
        FedCrew         : boolean = Yes;
        Gravity         : boolean = Yes;
        GravityRange    : byte = 3;
        RoundWells      : boolean = Yes;
        HYPGravity      : boolean = Yes;
        AccurateFuelModel : boolean = No;
        MaxIncome       : long = 5000;
        CloakFuelBurn   : int = 5;
        CloakPreventDamage : byte = 1;
        Cloning         : boolean = Yes;
        CloneCost       : IArr11 = (200,200,200,200,32767,200,32767,200,200,200,200);
        Wormholes       : boolean = No;
        WormPower       : int = 25;
        WrmTravelDistDivisor : int = 100;
        WrmTravelWarpSpeed   : int = 9;
        WrmTravelCloaked     : boolean = Yes;
        Gambling        : boolean = Yes;
        Chunnel         : boolean = Yes;
        IsMines         : boolean = Yes;
        Alchemy         : boolean = Yes;
        ColFBuild       : boolean = Yes;
        RobFBuild       : boolean = Yes;
        RGA             : boolean = Yes;
        SuperRefit      : boolean = Yes;
        Terraformers    : boolean = Yes;
        OneEngineTow    : boolean = No;
        HyperDrive      : boolean = Yes;
        GloryDevice     : boolean = Yes;
        AntiCloak       : boolean = Yes;
        ImperialAssault : boolean = Yes;
        AdvancedRefinery: boolean = Yes;
        BioScanners     : boolean = Yes;
        VPAExtra        : boolean = Yes; {VPA Extra Features by Quapla} 
        RamScoop        : byte = 2;
        NoFuelMove      : boolean = Yes;
        EnableRemote    : boolean = No;
        EnableGive      : boolean = No;
        AllowExtendedMissions     : Boolean = Yes;
        ExtMissionsStartAt        : int = 20;
        RecycleRate               : int = 75;
        DamageLevelForChunnelFail : int = 100;
        MinimumChunnelDistance    : int = 100;
        AllowAlliedChunneling     : Boolean = No;
        NumExperienceLevels       : int = 0;
        VcrFileCaps               : word = 0;   { capabilities del fichero VCR (regla PCC2: del 1er registro) }
        ExperienceLevelNames      : string = 'Recruit,Soldier,Experienced,Elite,Ultra Elite';
        AllowAlternativeCombat    : boolean = No;

        StarbaseCostSet           : boolean = No;
        BaseFighterCostSet        : boolean = No;
        FreeFighterCostSet        : boolean = No;
        ShipFighterCostSet        : boolean = No;
        MaximumFightersOnBase     : IArr11 = (60,60,60,60,60,60,60,60,60,60,60);
        MaximumDefenseOnBase      : IArr11 = (200,200,200,200,200,200,200,200,200,200,200);

var Addon : record
   Unity, SB_Plus, Teleport                : boolean;
   SB_PlusMM                               : int;           {Quapla Starbase+ Max Money }
{  abhost,raceplus   : boolean; more to come later}
end;                                        { true = Enable Addon Quapla }

const TPFCode : array [1..7] of char = 'CNTDMS$';

var
        StarbaseCost,
        BaseFighterCost,
        FreeFighterCost,
        ShipFighterCost           : T11Costs;

var
        Password        : string[10];
const
        NoPassword      : array [1..10] of char = 'NOPASSWORD';
        NewPassword     : string[10] = '';
        PlanetsRegInfo  : array [1..2,1..25] of char =
                        ( 'VGA Planets shareware    ', 'Version 3.00             ' );
        PWpos           : long = 0;

type
        xtype   = (Sh,Pl,Ba);           { EXACTLY this order!!! }
var
        Changed : array [xtype,0..1000 div 8] of byte;
const
        DataChg : boolean = No;
        FIZZ_BIN: array [1..8] of char = 'FIZZ.BIN';
        xFName  : array [xtype] of string[5] = ('SHIP','PDATA','BDATA');
        xISize  : array [xtype] of byte = (SRecordSize,PRecordSize,BRecordSize);
        xINum   : array [xtype] of byte = (1,2,1);
        xFizz   : array [xtype] of int = (667,1667,1262);

type
        ch20    = array [1..20] of char;
        LRtype  = (Left,Right);
        VCRData = record
                    K0          : int;
                    int0        : int;
                    plnpic      : int;
                    planet      : int;
                    shpw        : array [LRType] of int;
                    dd          : array [LRType] of record
                      name      : ch20;
                      dam,crew,id : int;
                      race,realrace : byte;
                      pic,wl,
                      weaps,bays,tl,tfn,launs   : int;
                                  end;
                    shld        : array [LRType] of int;
                  end;

        { Config de combate de PHost para el visor nativo (PVCRALG). Casi todas
          las opciones son por jugador (IArr11; la convencion PHost de "un valor
          se repite a los 11" la aplica GetArray en CONFIG.PAS). Los defaults los
          fija InitCombatCfgDefaults (CONFIG.PAS) antes de leer pconfig.src.
          Ver README seccion 7. }
        LArr11  = array [1..11] of longint;
        TCombatCfg = record
          { 16-bit: caben en los limites que PHost admite para estas opciones }
          BeamHitOdds, BeamHitBonus,
          BeamRechargeRate, BeamRechargeBonus,
          TorpHitOdds, TorpHitBonus,
          TubeRechargeRate, TubeRechargeBonus,
          BayRechargeRate, BayRechargeBonus, BayLaunchInterval,
          ShieldDamageScaling, ShieldKillScaling, HullDamageScaling, CrewKillScaling,
          MaxFightersLaunched, StrikesPerFighter, FighterMovementSpeed,
          FighterBeamExplosive, FighterBeamKill, FighterKillOdds,
          BeamHitFighterCharge, BeamHitShipCharge, ShipMovementSpeed : IArr11;
          { Modificadores por experiencia (EMod*), indexados por nivel 1..NumExperienceLevels.
            Valor efectivo en combate = clamp(base[jugador] + EMod[nivel], min, max). }
          EModBeamHitOdds, EModBeamHitBonus,
          EModBeamRechargeRate, EModBeamRechargeBonus,
          EModTorpHitOdds, EModTorpHitBonus,
          EModTubeRechargeRate, EModTubeRechargeBonus,
          EModBayRechargeRate, EModBayRechargeBonus,
          EModShieldDamageScaling, EModShieldKillScaling,
          EModHullDamageScaling, EModCrewKillScaling,
          EModMaxFightersLaunched, EModStrikesPerFighter, EModFighterMovementSpeed,
          EModFighterBeamExplosive, EModFighterBeamKill,
          EModBeamHitFighterCharge : EArr;
          { 32-bit: distancias/rangos en metros; pueden superar 32767 (p.ej.
            BeamHitFighterRange por defecto = 100000) }
          FighterFiringRange, BeamFiringRange,
          BeamHitFighterRange, TorpFiringRange    : LArr11;
          StandoffDistance     : longint;
          FireOnAttackFighters : boolean;
          PlanetsHaveTubes     : boolean;
        end;

var     CombatCfg : TCombatCfg;

const
        VCSpeed : byte = 5;
        VCSet   : byte = 8;

type
                PDRec   = record
                    id          : int;
                    mines       : int;
                    factories   : int;
                    defense     : int;
                    supplies    : long; { total supp on the pl and all ships }
            end;
                PDArr   = array [1..500] of PDRec;
const
                PDis    : ^PDArr = nil;
        PDisN   : int = 0;
type
                BDRec   = record
                    id          : int;
                    fpos        : long;         { -> owner }
                    TF          : array [0..10] of int;  { 0 - fighters }
                  end;                  { total on base and all ships }
                BDArr   = array [1..500] of BDRec;
const
                BDis    : ^BDArr = nil;
        BDisN   : int = 0;

var
        LocationPlanet          : int;
        LocationX,LocationY     : int;

type
        HullFuncs       = (hfAlchemy,hfRefinery,hfAdvRefinery,
                           hfHeat50,hfCool50,hfHeat100,
                           hfHyperDrive,hfGravitonic,
                           hfAllWormScan,hfGambling,hfAntiCloak,
                           hfImperialAssault,hfChunneling,hfRamScoop,
                           hfFullBioScan,hfAdvCloak,hfCloak,hfBioScan,
                           hfGloryDeviceL,hfGloryDeviceH);
{$IFNDEF VPACC}
const
        HullFunc1       = hfAlchemy;
        HullFunc2       = hfGloryDeviceH;
        HullFuncName    : array [1..5,1..50] of char =
                        ( 'Alchemy Refinery AdvancedRefinery HeatsTo50 CoolsT',
                          'o50 HeatsTo100 Hyperdrive Gravitonic ScansAllWormh',
                          'oles Gambling AntiCloak ImperialAssault Chunneling',
                          ' RamScoop FullBioscan AdvancedCloak Cloak Bioscan ',
                          'GloryDeviceLowDamage GloryDeviceHighDamage        ' );

var
        HullFunc: ^IntArr;      { [Hull,Fn],[Hull,Fn],... }
        HullFN  : int;

{ ==========================================================================
  Compat Linux (VPACC off): definiciones que el nucleo usa SIN guarda y que,
  con VPACC activo vendrian de la rama VPACC-on (abajo) o de CC/HULLFUNC.PAS.
  Los usos de Enum / THullFuncQueryResult del nucleo SI van guardados por
  IFDEF VPACC, por eso aqui no hacen falta stubs de esas funciones.
  ========================================================================== }
type
  THullFuncQueryResult = record data:pointer; count:int; end;
{ Block from VPA2.PAS (estado del nucleo) }
var     mt0,mt1         : longint;
        MineN,IonN,WormN,UfoN,MarkN : int;
        BL0             : int;
        bOver           : boolean;
        AllH,eAllH,hOver: boolean;
        ScanH           : int;
        lsxy            : array [1..2,1..2] of int;
        dlship          : SRec;
        dlf             : long;
        dlt             : int;
        dlc             : byte;
        mEv0            : word;
const   iBeam : int = 10;
        jBeam : int = 10;
        jAmmo : int = 0;
        iColo : int = 0;
        iDefense : int = 0;
        iRace : int = 0;
var     GSOP : array [1..8] of int;
var     DScolorR, DScolorO, DScolorT, DSwm : byte;
const   DSdrawn : boolean = No;
        SRdrawn : boolean = No;
        forceDL : boolean = No;
var     SRradius : word;
const   ShipSortTablePtr : ^ShipSortArray = nil;
var     ShipSortTableIndex : word;
        ShipSortTableLock  : boolean;
{ Codigos de habilidades de casco (SPC_*), de CC/HULLFUNC.PAS }
const
  SPC_Alchemy=0;  SPC_Refinery=1;  SPC_AdvancedRefinery=2;  SPC_HeatsTo50=3;
  SPC_CoolsTo50=4;  SPC_HeatsTo100=5;  SPC_Hyperdrive=6;  SPC_Gravitonic=7;
  SPC_ScansAllWormholes=8;  SPC_Gambling=9;  SPC_AntiCloak=10;  SPC_ImperialAssault=11;
  SPC_Chunneling=12;  SPC_Ramscoop=13;  SPC_FullBioscan=14;  SPC_AdvancedCloak=15;
  SPC_Cloak=16;  SPC_Bioscan=17;  SPC_GloryDeviceLow=18;  SPC_GloryDeviceHigh=19;
  SPC_Unclonable=20;  SPC_CloneOnce=21;  SPC_Ungiveable=22;  SPC_GiveOnce=23;
  SPC_Level2Tow=24;  SPC_Tow=25;  SPC_ChunnelSelf=26;  SPC_ChunnelOthers=27;
  SPC_ChunnelTarget=28;  SPC_PlanetImmunity=29;  SPC_OreCondenser=30;  SPC_Boarding=31;
  SPC_AntiCloakImmunity=32;  SPC_Academy=33;  SPC_Repairs=34;  SPC_FullWeaponry=35;
  SPC_HardenedEngines=36;  SPC_Commander=37;  SPC_IonShield=38;  SPC_HardenedCloak=39;
{ Representacion antigua de hull-functions (VPACC off): IsHullFunc se implementa
  en la rama ELSE de la implementacion; se declara aqui para uso cross-unit (CONFIG). }
function IsHullFunc (h:byte; f:HullFuncs) : int;
{ Consulta de hull-functions estilo HULLFUNC: stub compat (ver implementacion) }
function ShipOrHullDoes(sid:integer; f1,f2,f3:integer):boolean;
{$ELSE}
type
  THullFuncQueryResult = record
                           data  : pointer;
                           count : int;
                         end;

{Block Start from VPA2.PAS}                         
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
        jBeam : int = 10;
        jAmmo : int = 0;     {needed for ShowMines Simulation Quapla}
        iColo : int = 0;
        iDefense : int = 0;     {needed for GroundAttack Simulation Quapla}
				iRace : int = 0;				  {attacking Ground Attack Race}
									
var			GSOP : array [1..8] of int;
				{	planet 		: int;
					when			: int;
					Hiss			: int;
					Pillage		: int;
					RGA				: int;
					H50				: int;
					C50				: int;
					H100			: int;		GetShipsOverPlanet}

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
{Block End from VPA2.PAS}                         

procedure EnumNewShipFunctions(var qr:THullFuncQueryResult; hull:int);
procedure EnumExistingShipFunctions(var qr:THullFuncQueryResult; sh:sptr; all:boolean);
procedure FreeShipFuncQueryResult(var qr:THullFuncQueryResult);
{$ENDIF}
var
        bgiDrv,bgiDir : str79;
        bgiMode : int;

{ ReservedMemory is old real-mode cruft to reserve a linear block of memory
  for important/emergency use. Ideally, it should better go away.
  Currently, it is used to make sure reservation of screen buffers always
  succeeds, but that requires that the screen buffer size is smaller than
  the ReservedMemory. In VPAMM, screen buffers are twice as big as in regular
  VPA, so we need twice the space.
  Linux port: VPA now runs in 256 colours (D8bit), where ptcgraph's ImageSize
  is ~2 bytes/pixel instead of the 4-bit planar packing of the DOS 16-colour
  BGI. A wide menu save (e.g. Buy torps/fighters, ~30 KB) therefore exceeds the
  old 30000 limit and made UnLockReservedMemory raise RunError(250). The screen
  buffers themselves are stored in a word (<=65535 bytes), so 65536 covers every
  non-truncated save; on Linux memory is abundant, so reserving 64 KB is free. }
const
       {$IFDEF VPAMM}
        ReservedMemory  = 131072;
       {$ELSE}
        ReservedMemory  = 65536;
       {$ENDIF}
        ResMem  : pointer = nil;
    FCChar  : array [0..61] of char = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
        useSVGA   : boolean = false;
        customBGI : boolean = false;

procedure CheckMem (m:long);
procedure LockReservedMemory;
procedure UnLockReservedMemory (m:long);
function  Distance2 (x1,y1,x2,y2:int) : long;
function  Distance (x1,y1,x2,y2:int) : long;
function  Distance2Wrap (x1,y1,x2,y2:int) : long;
function  Ceil (a:single) : longint;
function  ERND (a:single) : longint;
function  TSearch (turn:int) : tptr;
function  PSearchXY (xx,yy:int) : int;
function  PSearchNm (s:str20) : int;
function  PDSearch (id:int) : int;
function  BDSearch (id:int) : int;
procedure LoadBDis (id:int; var b:BRec);
function  ShipIsHere (i,x,y:int) : boolean;
function  ShipIsCloaking (player, mission:int) : boolean;
function  MSearchXY (x,y:int) : int;
function  EraseGameFile (const name:string) : boolean;
function  OpenFile (var f:file; name:str79; mode:byte; mustbe:boolean) : boolean;
function  OpenData (var f:file; name:filename; mustbe:boolean) : boolean;
function  Exists (name:filename) : boolean;
function  OpenRW (var f:file; name:filename; mustbe:boolean) : boolean;
function  OpenW (var f:file; name:filename; mustbe:boolean) : boolean;
procedure CloseData (var f:file);
procedure ReadTurnList;
function  LoadTurnData (t:tptr) : boolean;
procedure NewTurnData (t:tptr);
procedure SetTurn (t:int);
function  CreateMark (var m:MapMark) : int;
procedure EraseMark (k:int);
procedure SetMarkText (k:int; var s:string);
function  GetMarkText (k:int) : str20;
function  PlanetIncome (p:pptr; id:int; accurate:boolean) : long;
function  MiningRate (p:pptr; NTDMc:long; NTDMm:int; plimited:boolptr) : int;
function  MaxPlanetStruct (p:pptr; limit:int) : int;
function  HissHChange (id:int) : int;
function  GetShipsOverPlanet (id, myrace:int; move:boolean) : int;
function  CHappyChange (id:int; accurate:boolean) : int;
function  NHappyChange (id:int; accurate:boolean) : int;
procedure CalcMaxPop(plan:pptr;var colo,ming,maxc,grow,maxnat,grownat,GAmin,GAmax, GA, GARem:longint);
function  ClimateType (t:int) : climate;
function  PlName (n:int; SayPlanet:boolean) : str20;
function  Location (x,y:int) : str20;
function  HullFit (n:byte; m1,m2:int) : boolean;
function  OwnShipDesign (owner,hull:byte) : boolean;
function  FuelCargoMass (h:sptr) : str20;
{function  CloakFuel (h:sptr) : int;
function  CalcFuel (h:sptr) : long;
function  ETA (h:sptr) : int;}
function StdTowPtr(h: SRec): sptr;
function StdTowPtrID(id: int): sptr;
procedure CalcMove (var sh:SRec; tow_sh:sptr; limit_fuel:boolean);
procedure CalcMovement (h,tow_h:sptr; var burn,time:int);
procedure SetShipMass (var h:SRec);
procedure RandomFCode (var s:fcstr);
procedure ChangeData (xt:xtype; n:int);
function  IfChanged (xt:xtype; n:int) : boolean;
function  IsShipFunc (const sh:SRec; f:HullFuncs):boolean;
function  IsShipFunc3 (const sh:SRec; a,b,c:int):boolean;
function  RealShipOwner(sid:int):int;
function  IsAllied(bit:int;r1,r2:int):boolean;
{$IFOPT N-}
function  Round(n : real):long;
{$ENDIF}

function  ShipExperience(sid : int):int;
function  PlanetExperience(pid : int):int;
procedure PutShipExperience(sid, exp : int);
procedure PutPlanetExperience(pid, exp : int);
function  ExperienceLevelName(exp:int):string;
function  BuildQ(pid : int):int;
procedure NewBuildQData(t : tptr);
procedure PutBuildQ(pid, exp : int);
function ControlPosition(xt:xtype; id:int):long;
function  UnderTow (id:int) : int;       { tower's id or 0 }
function  InGravityWell(pid:int;x,y:int):boolean;
function  NextTurnOnPlanet(pid:int;sid:int;speed:int):boolean;
function  ShipID(p:sptr):integer;
function  PlanetID(p:pptr):integer;

PROCEDURE GetBaseCost(player : INTEGER; VAR c:TFullPrice);
PROCEDURE GetFighterCost(player : INTEGER; VAR c:TFullPrice);
PROCEDURE GetShipFighterCost(player : INTEGER; VAR c:TFullPrice);
PROCEDURE GetFreeFighterCost(player : INTEGER; VAR c:TFullPrice);
FUNCTION GetMaxFightersOnBase(player : INTEGER):INTEGER;
FUNCTION GetMaxDefenseOnBase(player : INTEGER):INTEGER;

function PlanetCanBuildBase(p:pptr) : boolean;
function PlanetMayBuildBase(id:int) : boolean;
function PlanetCanBuildFighter(p:pptr) : boolean;

procedure InitVPAData;

{ return the highest warp that the engine can fly without
  consuming excessive fuel }
function  GetSafeWarp(engineLevel: integer): integer;

{ return the optimal warp for a ship }
function  GetOptimalWarp(pShip: sptr): integer; 
function Unity_Disassemble(Unity_Planet : pptr) : int;
procedure CutShipNames(var s : string);

Implementation

uses    Screen,ExtFeat
{$IFDEF VPACC},
        VPACC,Hullfunc
{$ENDIF};

procedure CheckMem (m:long);
  begin
    if MaxAvail<m+15 then RunError(250);
  end;

procedure LockReservedMemory;
  begin
    if ResMem<>nil then RunError(251);
    if MaxAvail<ReservedMemory then RunError(250);
    GetMem(ResMem,ReservedMemory);
  end;

procedure UnLockReservedMemory (m:long);
  begin
    if ResMem=nil then RunError(251);
    if m>ReservedMemory then RunError(250);
    FreeMem(ResMem,ReservedMemory);
    ResMem:=nil;
  end;

function Distance2 (x1,y1,x2,y2:int) : long;
  var   dx,dy   : long;
  begin
    dx:=x1-x2; dy:=y1-y2;
    if mapwrap then begin
      while (2*dx> MapSize) do dx:=dx-MapSize;
      while (2*dx<-MapSize) do dx:=dx+MapSize;
      while (2*dy> MapSize) do dy:=dy-MapSize;
      while (2*dy<-MapSize) do dy:=dy+MapSize;
    end;
    Distance2:=dx*dx+dy*dy
  end;

function Distance (x1,y1,x2,y2:int) : long; begin
  Distance:=Trunc(sqrt(Distance2(x1,y1,x2,y2)));
end;

function Distance2Wrap (x1,y1,x2,y2:int) : long;
  var   dx,dy,t   : long;
  begin
    dx:=abs(x1-x2);
    dy:=abs(y1-y2);
    if (MapWrap) then
    begin
      t := MapSize - dx;
      if (dx>t) then dx := t;
      t := MapSize - dy;
      if (dy>t) then dy := t;
    end;
    Distance2Wrap:=dx*dx+dy*dy
  end;


function Ceil (a:single) : longint;
  begin
    if Frac(a)=0 then Ceil:=Round(a)
    else if a>0 then Ceil:=Round(a+0.5)
                else Ceil:=Round(a-0.5);
  end;

function ERND (a:single) : longint;
var
   f : single;
   b : longint;

  begin

    f := Frac(a);
    b := Trunc(a);

    if (b div 2)*2 = b then
      if f<=0.5 then ERND := b
      else           ERND := b + 1
    else
      if f< 0.5 then ERND := b
      else           ERND := b + 1

  end;


function TSearch (turn:int) : tptr;
  var   t       : tptr;
  begin
    t:=TEnd;
    while (t<>nil) and (t^.turn<>turn) do t:=t^.prev;
    TSearch:=t;
  end;

function PSearchXY (xx,yy:int) : int;
  var   i       : int;
        data    : tdptr;
  begin
    PSearchXY:=0;
    if (TTurn=nil) or (TTurn^.data=nil) then data:=TEnd^.data
                                        else data:=TTurn^.data;
    with data^ do
    for i:=1 to 500 do
      if (xyplan[i,1]=xx) and (xyplan[i,2]=yy) then
        begin PSearchXY:=i; Break end;
  end;

function PSearchNm (s:str20) : int;
  var   i,found,len : word;
        ls      : byte absolute s;
  begin
    len:=ls;
    found:=0;
    for i:=ls+1 to 20 do
      s[i]:=' ';
    ls:=20;
    with TTurn^.data^ do begin
      for i:=1 to 500 do
        if (xyplan[i,1]<>-1) and (StrCmp(PlanName[i],s,ls)) then
          begin found:=i; Break end;
      ls:=len;
      if (found=0) then
        for i:=1 to 500 do
          if (xyplan[i,1]<>-1) and (StrCmp(PlanName[i],s,ls)) then
            begin found:=i; Break end;
    end;
    PSearchNm:=found;
  end;

function PDSearch (id:int) : int;
  var   i       : int;
  begin
    for i:=1 to PDisN do
      if PDis^[i].id=id then begin PDSearch:=i; Exit end;
    PDSearch:=0;
  end;

function BDSearch (id:int) : int;
  var   i       : int;
  begin
    for i:=1 to BDisN do
      if BDis^[i].id=id then begin BDSearch:=i; Exit end;
    BDSearch:=0;
  end;

procedure LoadBDis (id:int; var b:BRec);
  var   i       : int;
        f       : file;
  begin
    i:=BDSearch(id);            { MUST be i<>0 }
    OpenRW(f,xFName[Ba]+plstr+'.DIS',Yes);
    Seek(f,BDis^[i].fpos);
    BlockRead(f,b,BRecordSize-2);
    CloseData(f);
  end;

function ShipIsHere (i,x,y:int) : boolean;
  var   h       : sptr;
  begin
    h:=TTurn^.data^.ship[i];
    ShipIsHere:=(h<>nil) and (h^.when=turn) and (h^.x=x) and (h^.y=y);
  end;

function  ShipIsCloaking (player, mission:int) : boolean;
  begin
    ShipIsCloaking := (mission in [10, ExtMissionsStartAt+10])
                   or ((Race[player]=3) and (mission in [9, ExtMissionsStartAt+9, ExtMissionsStartAt+11]));
  end;

function MSearchXY (x,y:int) : int;
  var   i       : int;
        m       : mptr;
  begin
    for i:=1 to 500 do
    begin
      m:=TTurn^.data^.mines[i];
      if (m<>nil) and (m^.x=x) and (m^.y=y) then begin MSearchXY:=i; Exit end;
    end;
    MSearchXY:=0;
  end;


function EraseGameFile (const name:string) : boolean;
  var f :  file;
  begin
    Assign(f,addir+name);
    Erase(f);
    EraseGameFile := IOResult=0;
  end;

{ Nota (port Linux): igual que OpenData/OpenRW/Exists/OpenText, el nombre pasa
  por ResolveCase para tolerar la caja del nombre en disco. Por aqui entran
  RESOURCE.PLN, VPA.HLP y la fuente del mapa, que en DOS venian siempre en
  mayusculas pero pueden llegar en minusculas desde cualquier otra fuente. }
function OpenFile (var f:file; name:str79; mode:byte; mustbe:boolean) : boolean;
  begin
    OpenFile:=No;
    FileMode:=mode;
    Assign(f,ResolveCase(name));
    Reset(f,1);
    if (IOResult<>0) or (FileSize(f)=0) then
      if mustbe then begin Writeln(#13#10'Can''t read file ',name); Halt end
                     else Exit;
    OpenFile:=Yes;
  end;



function OpenData (var f:file; name:filename; mustbe:boolean) : boolean;
  begin
    OpenData:=No;
    FileMode:=0;
    Assign(f,ResolveCase(addir+name));
    Reset(f,1);
    if (IOResult<>0) or (FileSize(f)=0) then
    begin
      Assign(f,ResolveCase(name));
      Reset(f,1);
      if (IOResult<>0) or (FileSize(f)=0) then
        if mustbe then begin Writeln(#13#10'Can''t read file ',name); Halt end
                  else Exit;
    end;
    OpenData:=Yes;
  end;

function Exists (name:filename) : boolean;
  var f : file;
  begin
    Exists:=No;
    FileMode:=0;
    Assign(f,ResolveCase(addir+name));
    Reset(f,1);
    if (IOResult<>0) or (FileSize(f)=0) then
      Exit;
    Close(f);
    Exists:=Yes;
  end;

function OpenRW (var f:file; name:filename; mustbe:boolean) : boolean;
  begin
    OpenRW:=Yes;
    FileMode:=2;
    Assign(f,ResolveCase(addir+name));
    Reset(f,1);
    if IOResult<>0 then
      if mustbe then
        begin Writeln(#13#10'Can''t read/write file ',addir,name); Halt end
      else OpenRW:=No;
  end;

function OpenW (var f:file; name:filename; mustbe:boolean) : boolean;
  begin
    Assign(f,addir+name);
    Rewrite(f,1);
    if IOResult=0 then OpenW:=Yes
    else begin
      Writeln(#13#10'Can''t write file ',addir,name);
      if mustbe then Halt;
      OpenW:=No;
    end;
  end;

procedure CloseData (var f:file);
  begin
    Close(f); if IOResult=0 then ;
  end;

  { Ensure that turn t has space for planet experience levels }
  procedure NewBuildQData(t : tptr);
  begin
    if t^.data^.BuildQ=nil then begin
      New(t^.data^.BuildQ);
      FillChar(t^.data^.BuildQ^, Sizeof(t^.data^.BuildQ^), 0);
    end;
  end;
  
{ Ensure that turn t has space for planet experience levels }
procedure NewPlanetExpData(t : tptr);
  begin
    if t^.data^.planetexp=nil then begin
      New(t^.data^.planetexp);
      FillChar(t^.data^.planetexp^, Sizeof(t^.data^.planetexp^), 255);
    end;
  end;

{ Ensure that turn t has space for ship experience levels }
procedure NewShipExpData(t : tptr);
  begin
    if t^.data^.shipexp=nil then begin
      New(t^.data^.shipexp);
      FillChar(t^.data^.shipexp^, Sizeof(t^.data^.shipexp^), 255);
    end;
  end;

  
{ Experience level of ship /sid/ in current turn. -1 if unknown or
  experience not used. }
function  ShipExperience(sid : int):int;
  var t : tptr;
  begin
    { NOTE: We generally want TTurn^.data. However, this function
      is called during turn setup, when TTurn^.data is nil, but
      TEnd contains the new/old data. So we fall back to using
      TEnd in this case. This may use the old experience levels
      for BackTrack(), but that's actually a good thing (the old
      levels were used to move the old ships), and in addition,
      level-restricted hyperjumpers are rare. }
    if (TTurn<>nil) and (TTurn^.data<>nil) then t := TTurn ELSE t := TEnd;
    if (t<>nil) and (t^.data<>nil) and (t^.data^.shipexp<>nil)
    then ShipExperience := t^.data^.shipexp^[sid]
    else ShipExperience := -1;
  end;

{ Experience level of planet /pid/ in current turn. -1 if unknown or
  experience not used. }
function  PlanetExperience(pid : int):int;
  var t : tptr;
  begin
    if (TTurn<>nil) and (TTurn^.data<>nil) then t := TTurn ELSE t := TEnd;
    if (t<>nil) and (t^.data<>nil) and (t^.data^.planetexp<>nil)
    then PlanetExperience := t^.data^.planetexp^[pid]
    else PlanetExperience := -1;
  end;

  { Build Ship at that Planet? Planet 0 for Last Basein current turn. 0 if unknown or
  BuilQ not used. }
function  BuildQ(pid : int) : int;
  var t : tptr;
  begin
    if (TTurn<>nil) and (TTurn^.data<>nil) then t := TTurn ELSE t := TEnd;
    if (t<>nil) and (t^.data<>nil) and (t^.data^.BuildQ<>nil)
    then BuildQ := t^.data^.BuildQ^[pid]
    else BuildQ := 0; 
  end;

  
{ Put ship experience level of ship /sid/ in most-recent turn. This does
  range checks and can thus be passed the raw, unchecked data from util.dat. }
procedure PutShipExperience(sid, exp : int);
  begin
    if (exp >= 0) and (sid > 0) and (sid <= NUM_SHIPS) then begin
      NewShipExpData(TEnd);
      TEnd^.data^.shipexp^[sid] := exp;
    end;
  end;

{ Put planet experience level of planet /pid/ in most-recent turn. This does
  range checks and can thus be passed the raw, unchecked data from util.dat. }
procedure PutPlanetExperience(pid, exp : int);
  begin
    if (exp >= 0) and (pid > 0) and (pid <= NUM_PLANETS) then begin
      NewPlanetExpData(TEnd);
      TEnd^.data^.planetexp^[pid] := exp;
    end;
  end;
  
{ Put planet Build in most-recent turn.}
procedure PutBuildQ(pid, exp : int);
  begin
    if (exp >= 0) and (pid >= 0) and (pid <= NUM_PLANETS) then begin
      NewBuildQData(TEnd);
      TEnd^.data^.buildq^[pid] := exp;
    end;
  end;
  
  
function  ExperienceLevelName(exp:int):string;
  var  i : int;
       s : string;
  begin
    if exp < 0 then begin
      ExperienceLevelName := '';
    end else begin
      s := ExperienceLevelNames;
      while exp > 0 do begin
        i := Pos(',', s);
        if i > 0 then Delete(s, 1, i);
        dec(exp);
      end;
      i := Pos(',', s);
      if i > 0 then s[0] := chr(i-1);
      Trim(s);
      ExperienceLevelName := s;
    end;
  end;

{
  Read turn list. This will build up a list of turns in 'TRoot', and set
  'TEnd' to the data block of the current turn. It will initialize all
  file pointers. When you're unpacking an old turn, or a new version
  (rehost) of an existing turn, everything after that will be discarded.
               --sr
}
procedure ReadTurnList;
  var   id      : array [1..DBHeadLen] of char;
        tb      : TBlock;
        b       : DBlock;
        t       : tptr;
        fp      : long;
        f       : file;
  procedure AddTurn;
    begin
      CheckMem(SizeOf(TRec));
      New(t); t^.next:=nil;
      if TRoot=nil then
      begin
        t^.prev:=nil;
        TRoot:=t;
      end
      else begin
        TEnd^.next:=t;
        t^.prev:=TEnd;
      end;
      TEnd:=t;
      t^.fpos:=fp;
      t^.unk:=No;
      t^.IsPBP:=No;
      t^.data:=nil;
    end;
  begin
    fp:=0;
    Assign(f,addir+dbname);
    Reset(f,1);
    if IOResult<>0 then Writeln(' doesn''t exist yet.')
    else begin
      Writeln;
      BlockRead(f,id,DBHeadLen);
      if Copy(id,1,14)<>DBHeader then RunError(254);
      if byte(id[15])<>DBVersion then
        begin Writeln('ERROR: Unknown version of VPA database'); Halt end;
      fp:=FilePos(f);
      while not Eof(f) do
      begin
        BlockRead(f,tb,SizeOf(tb));
        if (IOResult<>0) or
           (tb.tag<>T_TAG) or (tb.size<0) or (tb.number<=0) then RunError(254);
        if (today<>0) and ((tb.number>today) or ((tb.number=today) and
           (tb.stamp[1]<>#0) and (tb.stamp<>Stamp))) then Break;
        AddTurn;
        t^.turn:=tb.number;
        t^.score:=tb.score;
        if tb.size>=SizeOf(b) then
        begin
          BlockRead(f,b,SizeOf(b));
          if b.tag=PP_TAG then
          begin
            t^.IsPBP:=Yes;
            BlockRead(f,t^.PBP,SizeOf(PBPList));
          end;
        end;
        Seek(f,fp+SizeOf(tb)+tb.size);
        if IOResult<>0 then RunError(254);
        fp:=FilePos(f);
      end;
      CloseData(f);
    end;
    TTurn:=TEnd;        { set TTurn to the last turn in db }
    if (today<>0) and ((TEnd=nil) or (TEnd^.turn<>today)) then
    begin
      AddTurn;
      t^.turn:=today;
    end;
    if TEnd<>nil then today:=TEnd^.turn;
  end;

procedure NewTurnData (t:tptr);
  var   i       : int;
  begin
    if t^.data<>nil then Exit;
    New(t^.data);
    FillChar(t^.data^,SizeOf(TurnData),0);
    t^.data^.xyplan[1,1]:=-30000;       { XREF to LoadMap }
  end;

procedure DisposeTurnData (t:tptr);
  var   i       : int;
  begin
    if t^.data=nil then Exit;
    with t^.data^ do
    begin
      for i:=0 to 999 do          {Bug? This should't be on 500, Quapla}
      begin
        if (i>=1) and (i<=500) then
        begin
          if planet[i]<>nil then Dispose(planet[i]);
          if base[i]<>nil then Dispose(base[i]);
          if mines[i]<>nil then Dispose(mines[i]);
        end;
        if (i>=1) and (i<=999) then
          if ship[i]<>nil then Dispose(ship[i]);
        if (i>=1) and (i<=50) and (ion[i]<>nil) then Dispose(ion[i]);
        if (i>=1) and (i<=100) and (ufo[i]<>nil) then Dispose(ufo[i]);
        if (i>=0) and (i<=199) and (worm[i]<>nil) then Dispose(worm[i]);
      end;
      if mark<>nil then FreeMem(mark,nmark*SizeOf(MapMark));
      if mtext<>nil then FreeMem(mtext,mtsize);
      if shipexp<>nil then Dispose(shipexp);
      if planetexp<>nil then Dispose(planetexp);
    end;
    Dispose(t^.data);
    t^.data:=nil;
  end;

function FreeDataMemory (size:long; critical:boolean) : boolean;
  var   t,t1,t2 : tptr;
        m       : long;
  begin
    m:=MaxAvail;
    t1:=TRoot;
    t2:=TEnd^.prev; if t2=nil then t2:=t1;
    while (m<size) and ((t1<>TTurn) or (t2<>TTurn)) do
    begin
      if Abs(t1^.turn-turn)>Abs(t2^.turn-turn) then
        begin t:=t1; t1:=t1^.next end
      else
        begin t:=t2; t2:=t2^.prev end;
      if t=nil then Break;
      DisposeTurnData(t);
      m:=MaxAvail;
    end;
    FreeDataMemory:=(m>=size);
    if critical and (m<size) then RunError(250);
  end;


function LoadTurnData (t:tptr) : boolean;
  var   i,k     : word; { word, not int }
        b       : DBlock;
        fp      : long;
        f       : file;
        isxyplan: boolean;
  function NoMem (m:word) : boolean;
    begin
      NoMem:=No;
      if not FreeDataMemory(m,Yes) then
      begin
        Close(f);
        NoMem:=Yes;
      end;
    end;
  begin
    LoadTurnData:=No;
    if (t=nil) or (t^.fpos=0) or (t^.data<>nil) then Exit;
    if not FreeDataMemory(SizeOf(TurnData),Yes) then Exit;
    Assign(f,addir+dbname);
    Reset(f,1);
    if IOResult<>0 then RunError(253);
    Seek(f,t^.fpos+SizeOf(TBlock));
    if IOResult<>0 then RunError(253);
    NewTurnData(t);
    with t^.data^ do
    begin
      repeat
        BlockRead(f,b,SizeOf(b));
        if IOResult<>0 then RunError(253);
        fp:=FilePos(f);
        if b.tag=PP_TAG then
        begin
          t^.IsPBP:=Yes;
          BlockRead(f,t^.PBP,SizeOf(PBPList));
        end     else
        if b.tag=P_TAG then
          for i:=1 to b.number do
          begin
            BlockRead(f,k,2);
            if (k<1) or (k>500) or NoMem(SizeOf(PRec)) then Exit;
            if planet[k]=nil then New(planet[k]);
            BlockRead(f,planet[k]^,SizeOf(PRec));
          end   else
        if b.tag=B_TAG then
          for i:=1 to b.number do
          begin
            BlockRead(f,k,2);
            if (k<1) or (k>500) or NoMem(SizeOf(BRec)) then Exit;
            if base[k]=nil then New(base[k]);
            BlockRead(f,base[k]^,SizeOf(BRec));
          end   else
        if b.tag=S_TAG then
          for i:=1 to b.number do
          begin
            BlockRead(f,k,2);
            if (k<1) or (k>999) or NoMem(SizeOf(SRec)) then Exit;
            if ship[k]=nil then New(ship[k]);
            BlockRead(f,ship[k]^,SizeOf(SRec) - 2);
            ship[k]^.ship_id := k;
          end   else
        if b.tag=M_TAG then
          for i:=1 to b.number do
          begin
            BlockRead(f,k,2);
            if (k<1) or (k>500) or NoMem(SizeOf(MRec)) then Exit;
            if mines[k]=nil then New(mines[k]);
            BlockRead(f,mines[k]^,SizeOf(MRec));
          end   else
        if b.tag=I_TAG then
          for i:=1 to b.number do
          begin
            BlockRead(f,k,2);
            if (k<1) or (k>50) or NoMem(SizeOf(IRec)) then Exit;
            if ion[k]=nil then New(ion[k]);
            BlockRead(f,ion[k]^,SizeOf(IRec));
          end   else
        if b.tag=U_TAG then
          for i:=1 to b.number do
          begin
            BlockRead(f,k,2);
            if (k<1) or (k>100) or NoMem(SizeOf(URec)) then Exit;
            if ufo[k]=nil then New(ufo[k]);
            BlockRead(f,ufo[k]^,SizeOf(URec));
          end   else
        if b.tag=W_TAG then
          for i:=1 to b.number do
          begin
            BlockRead(f,k,2);
            if (k<0) or (k>199) or NoMem(SizeOf(WRec)) then Exit;
            if worm[k]=nil then New(worm[k]);
            BlockRead(f,worm[k]^,SizeOf(WRec));
          end   else
        if b.tag=E_TAG then BlockRead(f,eplan,SizeOf(eplan)) else
        if b.tag=N_TAG then BlockRead(f,newplan,SizeOf(newplan)) else
        if b.tag=XY_TAG then BlockRead(f,xyplan,SizeOf(xyplan)) else { number=500, size=2000 }
        if b.tag=A_TAG then
        begin
          if mark<>nil then FreeMem(mark,nmark*SizeOf(MapMark));
          if mtext<>nil then FreeMem(mtext,mtsize);
          if NoMem(b.size+16) then Exit;
          nmark:=b.number;
          k:=nmark*SizeOf(MapMark);
          if nmark>0 then
          begin
            GetMem(mark,k);
            BlockRead(f,mark^,k);
          end;
          mtsize:=b.size-k;
          if mtsize>0 then
          begin
            GetMem(mtext,mtsize);
            BlockRead(f,mtext^,mtsize);
          end;
        end     else
        if b.tag=IM_TAG then
        begin
          ipos:=fp-2;
          inum:=b.number;
          Seek(f,fp+b.size);
        end     else
        if b.tag=OM_TAG then
        begin
          opos:=fp-2;
          onum:=b.number;
          Seek(f,fp+b.size);
        end     else
        if b.tag=V_TAG then
        begin
          vpos:=fp-2;
          vnum:=b.number;
          Seek(f,fp+b.size);
        end     else
        if b.tag=MO_TAG then
        begin
          mopos:=fp;
          Seek(f,fp+b.size);
        end     else
        if b.tag=PW_TAG then
        begin
          if t^.turn=today then PWpos:=fp;
          Seek(f,fp+b.size);
        end     else
        if b.tag=VE_TAG then
        begin
          TurnVer:=b.number;
          {Seek(f,fp+b.size);}  { size = 0 }
        end     else
        if b.tag=PH_TAG then
        begin
          if t^.turn=today then
          begin
            PHOST:=Yes;
            PHOSTver[0]:=char(b.size);
            BlockRead(f,PHOSTver[1],b.size);
          end
          else Seek(f,fp+b.size);
        end     else
        if b.tag=PEXP_TAG then
        begin
          NewPlanetExpData(t);
          i := Min(b.size, NUM_PLANETS);
          BlockRead(f,planetexp^,i);
          Seek(f,fp+b.size);
        end else
        if b.tag=SEXP_TAG then
        begin
          NewShipExpData(t);
          i := Min(b.size, NUM_SHIPS);
          BlockRead(f,shipexp^,i);
          Seek(f,fp+b.size);
        end else
        if b.tag=BQ_TAG then
        begin
          NewBuildQData(t);
          i := Min(b.size, NUM_PLANETS+1);
          BlockRead(f,BuildQ^,i);
          Seek(f,fp+b.size);
        end else
        if b.tag<>T_TAG then
        begin
          t^.unk:=Yes;
          Seek(f,fp+b.size);
        end;
        if IOResult<>0 then RunError(253);
      until Eof(f) or (b.tag=T_TAG);
      if (t<>TEnd) and (xyplan[1,1]=-30000) then        { XREF to LoadMap }
        Move(TEnd^.data^.xyplan,xyplan,SizeOf(xyplan));
    end;
    Close(f);
    LoadTurnData:=Yes;
  end;

procedure SetSPlan;
  var   i       : int;
  begin
    FillChar(splan,SizeOf(splan),0);
    chuns:=No;
    for i:=1 to 999 do
      if TTurn^.data^.ship[i]<>nil then
      with TTurn^.data^.ship[i]^ do
      begin
        splan[i]:=PSearchXY(x,y);
        if (not chuns) and (turn=TTurn^.turn)
         and (IsShipFunc3(TTurn^.data^.ship[i]^,SPC_Chunneling,SPC_ChunnelSelf,SPC_ChunnelOthers))
          then chuns:=Yes;
      end;
  end;

procedure SetTurn (t:int);
  begin
    TTurn:=TSearch(t);
    if TTurn=nil then Exit;
    turn:=t;
    if TTurn^.data=nil then LoadTurnData(TTurn);
    TPrev:=TSearch(t-1);
    if (TPrev<>nil) and (TPrev^.data=nil) then TPrev:=nil;
    SetSPlan;
  end;

function CreateMark (var m:MapMark) : int;
  var   i       : int;
        s       : word;
        p       : pointer;
  begin
    CreateMark:=0;
    with TEnd^.data^ do
    begin
        i:=1;
        while (i<=nmark) and (mark^[i].mtype<>mrkNone) do inc(i);
        if i>nmark then
        begin
          if (i>2047) or (i>65520 div SizeOf(MapMark)) then Exit;
          s:=i*SizeOf(MapMark);
          if not FreeDataMemory(s,No) then Exit;
          GetMem(p,s);
          if nmark>0 then
          begin
            dec(s,SizeOf(MapMark));
            Move(mark^,p^,s);
            FreeMem(mark,s);
          end;
          mark:=p;
          inc(nmark);
        end;
        mark^[i]:=m;
    end;
    CreateMark:=i;
  end;

procedure EraseMark (k:int);
  var   s       : string[1];
  begin
    with TEnd^.data^.mark^[k] do
    begin
      if mtype=mrkNone then Exit;
      if not (mtype in [mrkRCircle..mrkDLine]) and (text<>0) then
      begin
        s[0]:=#0;
        SetMarkText(k,s);
      end;
      mtype:=mrkNone;
    end;
  end;

procedure SetMarkText (k:int; var s:string);
  var   p       : word;
        i,mts   : int;
        ls      : byte absolute s;
        m       : ^ByteArr;
  begin
    with TEnd^.data^ do
    begin
      if (k>nmark) or (mark^[k].mtype in [mrkNone,mrkRCircle..mrkDLine]) then Exit;
      mts:=0;
      for i:=1 to nmark do
        if (i<>k) and (not (mark^[i].mtype in [mrkNone,mrkRCircle..mrkDLine])) and (mark^[i].text<>0) then
          inc(mts,mtext^[mark^[i].text]+1);
      inc(mts,IIF(ls=0,0,word(ls)+1));
      if MaxAvail<mts then Exit;
      GetMem(m,mts);
      p:=1;
      for i:=1 to nmark do
        if (i<>k) and (not (mark^[i].mtype in [mrkNone,mrkRCircle..mrkDLine])) and (mark^[i].text<>0) then
        begin
          Move(mtext^[mark^[i].text],m^[p],mtext^[mark^[i].text]+1);
          mark^[i].text:=p;
          inc(p,m^[p]+1);
        end;
      if ls=0 then mark^[k].text:=0
      else begin
        Move(s,m^[p],ls+1);
        mark^[k].text:=p;
      end;
      FreeMem(mtext,mtsize);
      mtext:=pointer(m);
      mtsize:=mts;
    end;
  end;

function GetMarkText (k:int) : str20;
  var   s       : str20;
        ls      : byte absolute s;
        p       : word;
  begin
    s:='';
    with TTurn^.data^ do
    if (k<=nmark) and not (mark^[k].mtype in [mrkNone,mrkRCircle..mrkDLine]) then
    begin
      p:=mark^[k].text;
      if p>0 then
      begin
        Move(mtext^[p],s,Min(mtext^[p]+1,20));
        if ls>20 then ls:=20;
      end;
    end;
    GetMarkText:=s;
  end;

function PlanetIncome (p:pptr; id:int; accurate:boolean) : long;
  var   l       : long;
        c       : long;
        nt      : int;
  begin
    l:=-1;
    if p<>nil then
    with p^ do
      if (colonists>0) and (Ctax<>-1) and
         (Nrace<>-1) and (natives<>-1) and (Ntax<>-1) and (Ngovt<>-1) then
        if colonists<>0 then
        begin
          l:=0;
          nt:=Ntax;
          if (not PHost) and (nt > TaxNBound[owner]) then nt:=TaxNBound[owner];
          if Nrace<>5 then l:=Round(natives*nt*Ngovt/5000);
          if colonists<l then l:=colonists;
          if Nrace=6 then l:=l*2;
          if (PHost) then begin
            if (Nstat+NHappyChange(id,accurate)<30) then l:=0; {No tax cash when happy < 30}
            if (Cstat+CHappyChange(id,accurate)<30) then c:=0 {No tax cash when happy < 30}
                                           else c:=colonists;
          end else begin
            if (Nstat+NHappyChange(id,accurate)<31) then l:=0; {No tax cash when happy < 31}
            if (Cstat+CHappyChange(id,accurate)<31) then c:=0 {No tax cash when happy < 31}
                                           else c:=colonists;
          end;
          if PHOSTver[1]>char(50) then { char(50) = '2' }
            l:=l*TaxNRate[owner] div 100+          { Phost 3 }
               Round(c*Ctax/1000)*TaxCRate[owner] div 100
          else
            l:=l*TaxRate[owner] div 100+      { Thost + Phost 2}
               Round(c*Ctax/1000)*TaxRate[owner] div 100;
          if l>MaxIncome then l:=MaxIncome;
        end;
    PlanetIncome:=l;
  end;

function MiningRate (p:pptr; NTDMc:long; NTDMm:int; plimited:boolptr) : int;
  var   l      : int;
        add    : int;
  begin
    l:=0;
    if p<>nil then
     with p^ do
      if (owner>0) and (owner<=11) and (Nrace<>-1) and (mines<>-1) and (NTDMc<>0) then begin
        if PHost then begin
          if (PHOSTver >= '4.1') OR ((PHOSTver < '4') AND (PHOSTver >= '3.5')) then add := 50
                                                                               else add := 0;
          l:=((((long(NTDMm)*MinRate[owner]+add) div 100)*IIF(Nrace=3,2,1) )*mines+add) div 100
        end else
         l:=Round(Round(long(NTDMm)*mines/100) * MinRate[owner]/100) * IIF(Nrace=3,2,1);
        if plimited<>nil then plimited^ := (l > NTDMc);
        if l > NTDMc then l := NTDMc;
      end;
    MiningRate:=l;
  end;

function MaxPlanetStruct (p:pptr; limit:int) : int;
  begin
    MaxPlanetStruct:=0;
    with p^ do
    if colonists>0 then
      if colonists<=limit then MaxPlanetStruct:=colonists
                          else MaxPlanetStruct:=Round(Sqrt(colonists-limit))+limit;
  end;

function HissHChange (id:int) : int;
begin
  HissHChange:=Min(GetShipsOverPlanet(id,2,FALSE),MaxShipsHissing)*HissEffect;	
end;
  
function GetShipsOverPlanet (id, myrace:int; move:boolean) : int;
{Parameter: id:     Ships over that Planet next turn
            MyRace: 2:  Mission Hisss
                    4:  Mission Pillage
                    10: Mission RGA
            move:   TRUE/FALSE (seek ship after move)
						
						uses record: GSOP
                    }
  var   k,hn,x,y: int;
        h       : SRec;
  begin		
    hn:=0; 
{		write(id,' ',myrace,' ');
		if (move) then write('True ') else write('False ');
		if (showF) then writeln('True ') else writeln('False ');}
    GetShipsOverPlanet:=hn; 
		if (GSOP[1]<>id) or (GSOP[2]<>turn) then begin
			x:=TTurn^.data^.xyplan[id,1];
			y:=TTurn^.data^.xyplan[id,2];
			GSOP[1] := id; GSOP[2] := turn;
			for k:=3 to 8 do GSOP[k]:=0;
			for k:=1 to NUM_SHIPS do
			begin
				if (TTurn^.data^.ship[k]<>NIL) then begin 
          h:=TTurn^.data^.ship[k]^;
          if (h.when=turn) then begin
            if (h.x=x) and (h.y=y) and (h.weapons>0) and (h.fuel>0) then begin {before move! QUAPLA!!}
  {Hiss}			if (h.mission in [9, ExtMissionsStartAt+11]) and (Race[RealShipOwner(k)]=2)
                      then inc(GSOP[3]);				
  {HEAT 50}   if IsShipFunc(h,hfHeat50) then inc(GSOP[6]);
  {COOL 50}   if IsShipFunc(h,hfCool50) then inc(GSOP[7]);
  {HEAT 100}  if IsShipFunc(h,hfHeat100) then inc(GSOP[8]); 
            end; 
            if (showF) and (move) then begin			{Move Ships only if ShowF and move:TRUE}
              if (UnderTow(k)>0) then h:=TTurn^.data^.ship[UnderTow(k)]^; {being towed}
              CalcMove(h,StdTowPtr(h),No);  
            end;
            if (h.x=x) and (h.y=y) and (h.weapons>0) and (h.fuel>0) then begin {after move}
  {Pill}		  if (h.mission in [9, ExtMissionsStartAt+11]) and (Race[RealShipOwner(k)]=4)
                      then inc(GSOP[4]);				
  {RGA}	  		if (h.mission in [9, ExtMissionsStartAt+11]) and (Race[RealShipOwner(k)]=10)
                      then inc(GSOP[5]);				
            end; 
          end;        
        end; 
      end;
		end;			{Same Parameters, end Calculation}
		case myrace of
			2		:	GetShipsOverPlanet:=GSOP[3];
			4		:	GetShipsOverPlanet:=GSOP[4];
			10	: GetShipsOverPlanet:=GSOP[5];
			50	: GetShipsOverPlanet:=GSOP[6];
			0		: GetShipsOverPlanet:=GSOP[7];
			100	: GetShipsOverPlanet:=GSOP[8];
		end;
	end;


(*  
function GetShipsOverPlanet (id, myrace:int; move:boolean) : int;
  var   k,hn,x,y: int;
        h       : sptr;
  begin
    hn:=0; 
    with TTurn^.data^ do
    begin
      x:=xyplan[id,1];
      y:=xyplan[id,2];
      for k:=1 to 999 do
      begin
        h:=ship[k];
        if (h<>nil) and (h^.when=turn) and (h^.x=x) and (h^.y=y) and
        (h^.mission in [9, ExtMissionsStartAt+11]) and (h^.weapons>0) and (h^.fuel>0) then
        if (Race[RealShipOwner(k)]=myrace) then inc(hn); {Special Mission for Race}
      end;
    end;

    GetShipsOverPlanet:=hn;
  end;
*)  

function CHappyChange ( id:int; accurate:boolean) : int;
  var   i       : int;
        p       : pptr;
        tempCtax: int;
  begin
    i:=0;
    p:=TTurn^.data^.planet[id];
    if p<>nil then
    with p^ do
    begin
      tempCtax := Ctax;
      if (Cstat < 30) then tempCtax:=0; {No taxation below happy=30 }
      if (colonists>0) and (owner<>-1) and (tempCtax<>-1) and
         (climate<>-1) and (mines<>-1) and (factories<>-1) then begin
            i:=Min(HissHChange(id),Max(100-Cstat,0));						
            if GetShipsOverPlanet(id,4,TRUE) > 0 then i:=i-10; {Pillage}
            if GetShipsOverPlanet(id,10,TRUE) > 0 then i:=i-60; {RGA}
            i:=i+trunc( 1000-Sqrt(colonists)-tempCtax*80
                      -Abs(climate-IIF(Race[owner]=7,0,50))*3
                      -(mines+factories) div 3 ) div 100;
          end;
    end;
    CHappyChange:=i;
  end;

function NHappyChange (id:int; accurate:boolean) : int;
  var   i       : int;
        p       : pptr;
        tempNtax: int;
  begin
		i:=0;
    p:=TTurn^.data^.planet[id];
    if p<>nil then
    with p^ do
    begin
      tempNtax := Ntax;
      if (Nstat < 30) then tempNtax:=0; {No taxation below happy=30 }
      if (Nrace>0) and (natives>0) and (Ntax<>-1) and (Ngovt<>-1) and
         (mines<>-1) and (factories<>-1) then begin
            i:=Min(HissHChange(id),Max(100-Nstat,0)); {Hisss Quapla}
            if GetShipsOverPlanet(id,4,accurate) > 0 then i:=i-10; 
						{Pillage+RGA no move with accurate=false}
            if GetShipsOverPlanet(id,10,accurate) > 0 then i:=i+Min(30,Max(100-(Nstat+i),0)); {RGA}         
            i:=i+trunc( (500-Sqrt(natives)-tempNtax*85
                     -(mines+factories) div 2+Ngovt*50 )/100)
                     +IIF(Nrace=4,10,0); (*Dacian*)
        (*
        i:=Round( 500-Sqrt(natives)-tempNtax*85
                     -(mines+factories) div 2+Ngovt*50 ) div 100
                     +IIF(Nrace=4,10,0)
                     +Min(HissHChange(id,TRUE),Max(100-Nstat,0));
                     *)
      end;
    end;
    NHappyChange:=i;
  end;


  procedure CalcMaxPop(plan:pptr;var colo,ming,maxc,grow,maxnat,grownat,GAmin,GAmax, GA,GARem:long);
  var newnat,Amin,Amax,amorph,assim,supp,ar,dr,af,df:long;
      tax,dp,temp,r,i:integer;
  begin
    with plan^ do begin
      temp:=100-climate; {should be predicted}
      if (colonists=0) then r:=race[player] else r:=race[owner];
      if (r=0) then r:=race[player];
      grow:=0; supp:=0;
      colo := colonists; 
      
      {Add-On Unity -> Planet-Code DA? -> 100*? Borg Clans will be disassempled into 50% Supplys Quapla}
      assim:=0;
      if Addon.Unity and (r=6) and (fcode[1]='D')AND(fcode[2]='A')AND
               (fcode[3] in ['1','2','3','4','5','6','7','8','9' ]) then begin
        assim:=-(ord(fcode[3])-ord('0'))*100;          {Quick hack -> DA5 -> assim := -500}
        if -assim > colo then assim := -colo; {all Clans disassembled}
      end;
      
      {Pillage/RGA Colonists}
      if (GetShipsOverPlanet(PlanetID(plan), 4, TRUE)>0) then begin 
        colo := colo - Trunc((colo * 0.2)+20.9);
        newnat := natives - Trunc((colo * 0.2)+120.9);
        end else newnat := natives;
      if (GetShipsOverPlanet(PlanetID(plan), 10, TRUE)>0) then colo := trunc (colo * 0.8);

      
      {Maximum population: maxc}
      if (not ClimateLimitsPopulation) then maxc:=250000
      else if ((r=7) and CrystalsLikeDesert) then begin
        if (PHost and CrystalSinTemp) then
          if (temp<15) then maxc:=Trunc(3+MaxColTempSlope*temp/100)
          else maxc:=Trunc(100000*sin(temp*3.14159/200))
        else maxc:=1000*LongInt(temp);
      end else if ((r=10) and (temp<20)) then maxc:=90000
      else if (temp<15) then
        if PHost then maxc:=Trunc(3+temp*MaxColTempSlope/100)
        else maxc:=Trunc((299.9+200*temp)/ClimateDeathRate)
      else if (temp>84) then
        if PHost then maxc:=Trunc(1+(100-temp)*MaxColTempSlope/100)
        else maxc:=Trunc((20099.9-200*temp)/ClimateDeathRate)
      else
        if PHost then maxc:=Round(sin(temp*3.14159/100)*100000)
        else maxc:=Round(sin((100-temp)*3.14/100)*100000);
      if (maxc=0) then maxc:=1;
      if ((maxc<60) and (r in [4,9,10,11]) and (temp>80)) then maxc:=60; {Donovan says Temp>80, was 84)
{!}   if (maxc<100/ClimateDeathRate-1) then maxc:=Trunc(99/ClimateDeathRate-1);
       {TODO: check above formula}

        {Make Supplies on planet}
        if (Addon.Unity) then supp := Unity_Disassemble(plan); {Adds DA? Supps Quapla}
{!}     if (factories>0) then supp:=supp+factories;  {should be predicted - decay?}
        if ((Nrace=2) and (natives>0)) then
         supp:=supp+minL(colo,natives DIV 100);
        if (PHost) then supp:=Trunc(supp*ProductionRate[r]/100);

      {Supplies production before assimilation, before growth, after decay}
      if (OverpopulationEatsSupplies) and (colo>maxc) then begin
        supp:=(supp+supplies)-1-trunc((colo-maxc)/40); {-trunc((colo-maxc)/40) added by quapla}
        maxc:=maxc+Round((supp div 40){*(100/ClimateDeathRate)}); {omitted by quapla}
      end;

      {Minimum population to get at least 1 clan growth, considering amorphous}
      amorph:=0;
      if ((Nrace=5) and (Natives>0)) then begin
         if (PHost) then begin
           if ((owner>0) or (Nstat<>-1)) then
             case Nstat+NHappyChange(PlanetID(plan),TRUE) of
               70..200:amorph:=5;
               50..69:amorph:=20;
               else amorph:=40;
             end
           else amorph:=5;
        end else
          amorph:=Max(5,95-(Nstat+NHappyChange(PlanetID(plan),TRUE)));
      end;
      
      if ((r=7) and CrystalsLikeDesert and (temp>0)) then
        if ((Nrace=5) and (Natives>0)) then begin
          ming:=ceil(11000/temp);
          Amin:=Max(NHappyChange(PlanetID(plan),TRUE),0);  {only helper variable}
          if (Amin=0) then ming:=ceil(2000*(amorph+0.5)/temp)
          else if (PHost) then begin
            Amax:=Max((69-Nstat) div (Amin),0);
            for i:=1 to Amax DO
             ming:=round(2000*(ming+IIF(Nstat+i*Amin<50,40,20))/(2000+temp));
          end else begin
            Amax:=Max((89-Nstat) div (Amin),0);
            for i:=1 to Amax DO
             ming:=round(2000*(ming+95-(Nstat+i*Amin))/(2000+temp));
          end;
        end else ming:=ceil(1000/temp)
      else if ((temp<15) or (temp>84)) then ming:=0
      else if ((Nrace=5) and (Natives>0)) then begin
        ming:=ceil(110/sin(3.14*(100-temp)/100));
          Amin:=Max(NHappyChange(PlanetID(plan),TRUE),0);  {only helper variable}
        if (Amin=0) then ming:=ceil(20*(amorph+0.5)/sin(3.14*(100-temp)/100))
        else if (PHost) then begin
          Amax:=Max((69-Nstat) div (Amin),0);
          for i:=1 to Amax DO
           ming:=round(20*(ming+IIF(Nstat+i*Amin<50,40,20))/(20+sin(3.14*(100-temp)/100)));
        end else begin
          Amax:=Max((89-Nstat) div (Amin),0);
          for i:=1 to Amax DO
           ming:=round(20*(ming+95-(Nstat+i*Amin))/(20+sin(3.14*(100-temp)/100)));
        end;
      end else ming:=ceil(10/sin(3.14*(100-temp)/100));
      
      {population growth through borg assimilation (only if not Amorphous=5)} 
      if ((r=6) and (Nrace>0) and (Nrace<>5) and (Natives>0)) then begin
        assim:=MinL(round((colo+assim)*AssimilationRate/100),Natives)+assim; 
        ming:=MaxL(ming-Natives,1);
      end;
      if (colo+assim=0) then colo := -3 else colo:=colo+assim;
      {To identify full assimilation later in WriteMaxPop}
      
      if ((colonists>0) and (owner<>0) and (owner<>player)) then begin 
      {original colononist, since no more DP can be built because of assimilation}
        {Enemy planet, calculate Ground Attack Amin and Amax}
        if (colonists>50) then dp:=50+trunc(sqrt(colonists-50))
        else if (colonists>0) then dp:=colonists
        else dp:=0;
        df:=long(GroundDefenseFactor[owner]);
        af:=long(GroundKillFactor[player]);
        GAmin:=long(Ceil(colo*(df/af)));
        GAmax:=long(Ceil(colo*df*((1+dp/20.0)/af)));     {Quapla Formula changed}
        ar := long(iColo*af); {??}
        dr := long(trunc (colo * df*((1+iDefense/20.0))));
        if (ar>dr) then GARem := long(TRound((ar-dr)/af))
                   else GARem := long(TRound((ar-dr)/df));
        GA := long(Ceil(colo*df*((1+iDefense/20.0)/af)));
      end else begin {Ground Attack Calculation}
				if (iRace>0) then begin						{=0 shows nothing but Key}
					if (colonists>50) then dp:=50+trunc(sqrt(colonists-50))
					else if (colonists>0) then dp:=colonists
					else dp:=0;
					df:=long(GroundDefenseFactor[player]);
					af:=long(GroundKillFactor[iRace]);
					GAmin:=long(Ceil(colo*df*((1+defense/20.0)/af)));
					GAmax:=long(Ceil(colo*df*((1+dp/20.0)/af)));
				end;
				
        if (colo<ming) then begin
          grow:=0;
        end else if (colo<maxc) then begin
          if (ctax>=0) then tax:=ctax else tax:=0;
          {grow:assimilation, add growth, minus amorph, limited by maxc}
          if (Cstat+CHappyChange(PlanetID(plan),TRUE)>69) then begin
            if ((r=7) and CrystalsLikeDesert) then
              if (PHost) then
                if (CrystalSinTemp and (temp>=15)) then grow:=round(
                   sin(temp*3.14159/200)*colo*RaceGrowthRate[player]/(2000*(1+tax/5)))
                else grow:=round(temp*colo*RaceGrowthRate[player]/(200000*(1+tax/5)))
              else grow:=round(colo*temp/(400*(tax+5)))      {No PHOST but r=7}
            else if ((temp>=15) and (temp<=84)) then begin        {No r=7 and grow-temp}
              if (PHost) then grow:=assim+round(SIN(temp*3.14159/100)
                              *colo*RaceGrowthRate[player]/((1+tax/5)*2000))
              else                                                {No PHOST, no R=7, grow-temp}
                grow:=assim+round(sin(3.14*(100-temp)/100)*colo/(4*(5+tax)));
                
              if (colo+grow>maxc) then grow:=maxc-colo; {no R=7, grow-temp}
            end else grow:=assim;                                 {no R=7, no grow temp -> just assimimilation}
          end else grow:=assim;                                   {no grow because unhappy, just assimilation}
            
          grow:=grow-amorph;
        end else if (colo=maxc) then begin
          grow:=assim-amorph;
        end else begin
          {population exceeds maxc, overpop die}
          if (ClimateLimitsPopulation) then
             if (PHost) then
               if (colo>250000) then
                 grow:=maxc-colo
               else begin
                 grow:=-Ceil(colo*ClimateDeathRate/100);
                 if (colo-grow<maxc) then grow:=maxc-colo;
               end
             else if ((r=7) and CrystalsLikeDesert) then grow:=maxc-colo
             else if (temp<15) then
               grow:=assim+(temp+1)*2-Trunc(colo*ClimateDeathRate/100)+(supp div 40)
             else if (temp>84) then
               grow:=assim+(100-temp)*2-Trunc(colo*ClimateDeathRate/100)+(supp div 40)
             else grow:=maxc-colo;
          grow:=grow-amorph;
        end;
        grow := grow  - (colonists-colo);
        if colo < 0 then colo := -1;
      end;
      
      {max and growth for natives}
      if ((Nrace>0) and (newnat>0)) then begin
        if (Ntax>=0) then tax:=Ntax else tax:=0;
        grownat:=0;
        if (Nrace=9) and (not PHost or (PHost and CrystalsLikeDesert)) then begin
          maxnat:=1000*LongInt(temp);
          if (PHost) then begin
            grownat:=trunc((newnat-assim)/2500*temp/(1+tax/5));
          end else if (newnat-assim<maxnat) then grownat:=round(temp/500*(newnat-assim)/(tax+5))
        end else if (PHost) then begin
          maxnat:=trunc(sin(temp*3.1415927/100)*156000+0.01);
{         if (temp=50) then maxnat:=156000;}
          grownat:=trunc(sin(temp*3.14159/100)*(newnat-assim)/(25*(1+tax/5)));
        end else begin
          maxnat:=trunc(sin(3.14*(100-temp)/100)*150000);
          if (newnat-assim<maxnat) then
            grownat:=round(sin(3.14*(100-temp)/100)*(newnat-assim)/(5*(tax+5)));
        end;
        if (Nstat+NHappyChange(PlanetID(plan),TRUE)<70) then grownat:=0;
        if (PHost) then begin
          if (newnat>maxnat) then
            grownat:=-minL(newnat-maxnat,trunc((newnat*NativeClimateDeathRate)/100))
          else if (newnat+grownat>maxnat) then
            grownat:=maxnat-newnat;
        end else if (newnat-assim>66000) then
          grownat:=grownat div 2;
        grownat:=grownat-assim;
      end else maxnat:=-1;
      grownat := grownat + (newnat-natives);
    end;
  end;

function ClimateType (t:int) : climate;
  var   c       : climate;
  begin
    for c:=Arctic to Desert do
      if 100-t>=TScale[c] then ClimateType:=c;
  end;

function PlName (n:int; SayPlanet:boolean) : str20;
  var   s       : str20;
  begin
    if PlanetNames then s:=PlanName[n]
    else begin
      s:=NStr0(n);
      if SayPlanet then s:='Planet '+s;
    end;
    Trim(s);
    PlName:=s;
  end;

function Location (x,y:int) : str20;
  var   k,xx,yy : int;
        gr2     : long;
        data    : tdptr;
  begin
    if MapWrap then WrapXY(x,y);
    LocationPlanet:=PSearchXY(x,y);
    LocationX:=x;
    LocationY:=y;
    if LocationPlanet<>0 then Location:=PlName(LocationPlanet,Yes)
    else begin
      if Gravity then
      begin
        if (TTurn=nil) or (TTurn^.data=nil) then data:=TEnd^.data
                                            else data:=TTurn^.data;
        with data^ do
        for k:=500 downto 1 do
        begin
          xx:=xyplan[k,1];
          yy:=xyplan[k,2];
          gr2:=GravityRange*GravityRange;
          if (RoundWells and (Distance2(x,y,xx,yy)<=gr2)) or
             ((not RoundWells) and (Abs(x-xx)<=GravityRange) and (Abs(y-yy)<=GravityRange)) then
          begin
            LocationPlanet:=k;
            LocationX:=xx;
            LocationY:=yy;
            Break;
          end;
        end;
      end;
      if LocationPlanet<>0 then Location:='÷'+PlName(LocationPlanet,Yes)
                           else Location:='('+NStr0(x)+','+NStr0(y)+')';
    end;
  end;

function HullFit (n:byte; m1,m2:int) : boolean;
  begin
    HullFit:=(m1>=Hulls[n].mass) and (m2<=Hulls[n].maxMass);
  end;

function OwnShipDesign (owner,hull:byte) : boolean;
  var   i       : byte;
        myrace  : int;
  begin
    OwnShipDesign:=No;
    if TrueHullByRace then myrace:=Race[owner]
                      else myrace:=owner;
    for i:=1 to 20 do
      if hull=RaceHull[myrace,i] then begin OwnShipDesign:=Yes; Break end;
  end;

function FuelCargoMass (h:sptr) : str20;
  var   i,j     : int;
        s,s1    : string[6];
  begin
    s:=''; s1:='';
    with h^ do
    if (hull<>-1) and (mass<>-1) then
    begin
      j:=mass-Hulls[hull].mass;
      Str(j,s);
      i:=Hulls[hull].launchers*tmm+Hulls[hull].weapons*wmm;
      if i>0 then
      begin
        if j<=i then s1:='0' else Str(j-i,s1);
        s1:=s1+'-';
      end;
    end;
    FuelCargoMass:=s1+s;
  end;

{This function returns pointer to ship beeing towed using std data
 The function is called when adjusting ship speeds in turn processing -
 in this case we don't want a fallback to TEnd since we may no longer
 tow the ship }
function StdTowPtrID(id: int): sptr;
var
        i       : int;
        h,h1    : sptr;
begin
    h  := TTurn^.data^.ship[id];
    h1 := nil;
    if (h <> nil) and (h^.mission=7) then
    begin
      i:=IIF(h^.mission=7,h^.tow_ship,0);
      if i>0 then h1 :=TTurn^.data^.ship[i];
    end;
    StdTowPtrID := h1;
end;

{This function returns pointer to ship beeing towed using std data}
function StdTowPtr(h: SRec): sptr;
var
        i       : int;
        h1      : sptr;
begin
    h1 := nil;
    if (h.mission=7) then
    begin
      i:=IIF(h.mission=7,h.tow_ship,0);

      if (TTurn <> nil) and (TTurn^.data <> nil) and (i>0)
      then h1 :=TTurn^.data^.ship[i];
    end;
    StdTowPtr := h1;
end;

{
  Compute distance, Tim-style.

  Tim's compiler disagrees with this one (and both differ from IEEE) when
  considering pythagoras terms. INT(SQR(3^2)) yields 2 with PDS BASIC.

  Instead of finding a formula which matches that behaviour, we just build
  a table of distances. Only distances <= 162 ly matter, for other
  distances it just matters that they're larger. Therefore we don't
  need to care about precision for large values, and our table has a
  bounded size.
}
FUNCTION TimDist(dx, dy : INTEGER): INTEGER;
VAR value, index, bit : INTEGER;
TYPE ArrayType = ARRAY[1..168, 0..20] OF BYTE;
CONST fuel_ptr : ^ArrayType = NIL;

  FUNCTION BitCount(a : INTEGER):INTEGER;
  BEGIN
    a := (a AND $55) + ((a AND $AA) SHR 1);
    a := (a AND $33) + ((a AND $CC) SHR 2);
    BitCount := (a AND $0F) + ((a AND $F0) SHR 4);
  END;

BEGIN
  IF dx < 0 THEN dx := -dx;
  IF dy < 0 THEN dy := -dy;
  IF dy = 0 THEN BEGIN
    IF dx = 0 THEN BEGIN
      TimDist := 0;
      Exit;
    END;
    dy := dx;
    dx := 0;
  END;

  { Imprecise mode. We do this if the value is out of range anyway, and
    if the distance table is not available. The latter can happen when
    PHost was not detected upon load, but user browses to a previous
    turn which did use PHost. }
  IF (dx >= 168) OR (dy >= 168) OR (distance_table = NIL) THEN BEGIN
    TimDist := Trunc(Sqrt(Distance2(0, 0, dx, dy)));
    Exit;
  END;

  value := dy-1;
  index := 0;
  WHILE dx >= 8 DO BEGIN
    Inc(value, BitCount(distance_table^[dy][index]));
    Inc(index);
    Dec(dx, 8);
  END;

  FOR bit := 0 TO dx DO
   IF distance_table^[dy][index] AND (1 SHL bit) <> 0 THEN
    Inc(value);
  TimDist := Value;
END;

PROCEDURE CalcMove (var sh:SRec; tow_sh:sptr; limit_fuel:boolean);
  VAR   _fuel,_mass,_pmass      : long;
        _mass_save              : long;
        _dist,_travel,i         : int;
        _hypfuel                : int;            {for Unity AHP-Jump - Quapla}
        _hypdist                : long;
        h1                      : sptr;
        _sdist                  : single;
        dist_squared            : long;
        dx,dy                   : int;
        gr0,rw0                 : boolean;
        
  { This function corrects ship mass prediction due to
    alchemy, rafinery, torpedo and fighter building,
    Borg Self repair and supplies repairing damage}
  { Mines laying should be here too }
  procedure CorrectShipMass( p :sptr; var _mass : long);
    var
      mkt,k : long;
      _damage : int;
    begin
      with p^ do
      begin
      {Ship cannot Alchemy and Rafinery at once}
      {FIXME: in PHost 4, it can}
      if (IsShipFunc(p^,hfAlchemy)) and (fcode<>'NAL') then
            _mass := _mass - Sup + Sup div 3 + Sup mod 3;
      if (IsShipFunc(p^,hfRefinery)) and (fcode<>'NAL') then
            _mass := _mass - Min(Sup,Min(M+D+T,Hulls[hull].fuel-fuel)); { -2 + 1 }
      {Advanced Rafinery does not change ship mass}
     {minefield laying}
      if ((mission in [3,ExtMissionsStartAt+1,ExtMissionsStartAt+16])OR
           ((Race[owner]=7)and(mission in [9,ExtMissionsStartAt+2,ExtMissionsStartAt+11,ExtMissionsStartAt+17])))AND
           (launchers>0)and(fuel>0)and(TFnum>0) then begin
          k :=0;
          if (mission in [3,9,ExtMissionsStartAt+11]) then begin
            k :=TFnum;
            if (fcode='mdq') then k := TFnum div 4;
            if (fcode='mdh') then k := TFnum div 2;
            if (fcode[1]='m')AND(fcode[2]='d')AND
               (fcode[3] in ['1','2','3','4','5','6','7','8','9' ]) then
               k:=min( (ord(fcode[3])-ord('0'))*10, TFnum);
            if (fcode='md0') then k := min(100,TFnum);
          end;
          if (mission in [ExtMissionsStartAt+1,ExtMissionsStartAt+2,
                         ExtMissionsStartAt+16,ExtMissionsStartAt+17]) then
            if (intr_ship=0) then k := TFnum
            else                  k := min(intr_ship,TFnum);
          dec(_mass,k);
      end;
      {Borg self repair - fixed Quapla}
       _damage := damage;
       if (Race[owner]=6)and(mission=9)and(_damage>0)and(fuel>0) then
         _damage:=  _damage - Min(_damage,10);
      { fighter building: mission=9 or FC=lfm for race 9 and 11
        no mission needed for race 10
        ship must have bays}
      if (Race[owner] in [9..11]) and (bays>0) and (fuel>0) then begin
        if ((mission=9) and (Race[owner] in [9,11])) or (fcode = 'lfm') then begin
          mkt := Min(T div 3,M div 2);
          mkt := Min(mkt,Sup div 5);
          _mass := _mass - mkt * 9; { - 10 + 1 }
        end;
      end;
      { 'mkt' and mission 20 }
      if ((fcode='mkt')or(mission=ExtMissionsStartAt) )and(launchers>0) then
        begin
          mkt := Min(T,D);
          mkt := Min(mkt,M);
          mkt := Min(mkt,credits div Torps[Tl].cost);
          _mass := _mass - mkt * 2; { -3 +1 }
        end;
      {using supplies for ship repair }
      if (_damage>0)and(Sup>0) then
      begin
        mkt  := Min(_damage,Sup div 5);
        _mass := _mass - mkt *5;
      end;
      end;  {with p^}
    end;

  procedure CalcMoveTim;
    var tdist : long;
    begin
      tdist := TimDist(sh.wx, sh.wy);
      with sh do
      begin
        if tdist<=_travel then begin
          _fuel:=long(_fuel)*tdist*_mass div (long(_travel)*10000);
          if (_fuel>fuel) and (fuel>0) then
            _fuel:=Max(fuel,Ceil(Trunc(_sdist+0.44)*_fuel/_travel));
            { distance = ERnd(max_travel*fuel/fuelusage) transformed for fuel
              _sdist is used because Tim checks a rounded distance-moved
              (0.55 rounded down) against _travel to determin if wp is reached }

        end else _fuel:=long(_fuel)*_mass div 10000;

        if limit_fuel and (_fuel>fuel) then
        begin
          if fuel>0 then
          begin
            _travel:=Round(long(_travel)*fuel/_fuel);
            fuel:=0;
          end
          else _travel:=0;
          _fuel:=0;
        end;

        if _sdist > _travel then begin
          if Abs(wx) > Abs(wy) then begin
            dx := Trunc(long(_travel) * Abs(wx) / _sdist  + 0.5);
            dy := Trunc(long(dx)      * Abs(wy) / Abs(wx) + 0.5);
          end else begin
            dy := Trunc(long(_travel) * Abs(wy) / _sdist  + 0.5);
            dx := Trunc(long(dy)      * Abs(wx) / Abs(wy) + 0.5);
          end;
          if wx<0 then dx := -dx;
          if wy<0 then dy := -dy;
        end else begin
          dx := wx;
          dy := wy;
        end;

        _sdist := Sqrt(long(dx)*dx+long(dy)*dy);  { for Cobol }
        _dist := Trunc(_sdist);
      end;
    end;

  { Compute movement for one turn.
    Input:  _fuel    EngineFuelConsumption, i.e. 8100 for TWD at Warp 9
            _mass    ship mass, corrected
            _pmass   ship mass, not corrected
            _travel  warp^2 * gravfactor
    Output: _fuel    fuel usage
            dx,dy    relative movement
            _dist    position }
  procedure CalcMovePHOST;
    var _rate   : single;
        _distf  : single;
        _move   : single;

    begin
      with sh do
      begin
        if _sdist>_travel then _move:=_travel
                          else _move:=_sdist;

        _rate:=_fuel/(long(_travel)*100000);
        if AccurateFuelModel then _fuel:=Round((1.0-Exp(-_rate*_move))*_pmass)
                             else _fuel:=Trunc(_rate*10*_mass*Trunc(_move));
        if limit_fuel and (_fuel>fuel) then
        begin
          if fuel=0 then _move:=0 else
          if AccurateFuelModel then _move:=Ln(_pmass/(_pmass-fuel))/_rate
          else begin
            _distf:=_mass*_rate*10;
            _dist:=Trunc(fuel/_distf);
            while Trunc(_distf*_dist)<=fuel do inc(_dist);
           _move:=_dist-0.000001;
          end;
          fuel:=0;
        end;

        if _move=_sdist then
        begin
          dx:=wx;
          dy:=wy;
        end
        else begin
          if wx=0 then dx:=0 else dx:=Ceil(wx*_move/_sdist);
          if wy=0 then dy:=0 else dy:=Ceil(wy*_move/_sdist);
        end;
        _dist:=Trunc(_move);    {was: for Cobol. probably no longer used -sr}
        _sdist:=Trunc(_move);   {for Cobol}
      end;
    end;

  BEGIN (* CalcMove *)
    with sh do
    begin
    
      if (IsShipFunc3(sh,SPC_Cloak,SPC_HardenedCloak,-1)) and
         ShipIsCloaking(owner, mission) and
         (not ShipOrHullDoes(ship_id, int(SPC_AdvancedCloak), -1, -1)) then
      begin
        _fuel:=Max(Hulls[hull].mass*CloakFuelBurn div 100,CloakFuelBurn);
        if (fuel>_fuel) or (not limit_fuel) then
        begin
          dec(fuel,_fuel);      {assuming that Cl.F.B. works before movement}
          dec(mass,Max(Min(_fuel,fuel),0));
        end
        else mission:=0;
      end;

      if (warp<1) or (wx or wy=0) then Exit;
      dist_squared := Distance2(0, 0, wx, wy);
      _sdist:=Sqrt(dist_squared);

      _hypdist := 0; _hypfuel := 0;
      if Addon.Unity and (fcode='AHP') and (fuel>=60) then begin
        _hypdist := 700; _hypfuel := 60; end;
      if (fcode='HYP') and (fuel>=50) then begin
        _hypdist := 350; _hypfuel := 50; end;

      if HyperDrive and (IsShipFunc(sh,hfHyperDrive)) and (_hypdist>0)  {only true if HYP/AHP}
        then begin
        { in PHost, a 340 ly jump is exact; in THost it isn't. }
        if PHOST then i:=0 else i:=1;
        if (dist_squared-i>=long(_hypdist-10)*(_hypdist-10)) and (dist_squared+i<=long(_hypdist+10)*(_hypdist+10)) then
        begin
          dx:=wx; dy:=wy;
        end
        else begin
          dx:=Trunc(_hypdist/_sdist*Abs(wx)+0.4999999)*Sign(wx);
          dy:=Trunc(_hypdist/_sdist*Abs(wy)+0.4999999)*Sign(wy);
        end;
        inc(x,dx); dec(wx,dx);
        inc(y,dy); dec(wy,dy);
        {wx:=0; wy:=0; warp:=0;}
        fcode:='hyp';
        dec(fuel,_hypfuel);
        if HYPGravity then
        begin
          if not PHOST then
          begin
            gr0:=Gravity; i:=GravityRange; rw0:=RoundWells;
            Gravity:=Yes; GravityRange:=2; RoundWells:=No;
          end;
          Location(x,y);      
          x:=LocationX;
          y:=LocationY;
          if not PHOST then
          begin
            Gravity:=gr0; GravityRange:=i; RoundWells:=rw0;
          end;
        end;
        Exit;
      end;

      _dist:=Trunc(_sdist);
      _travel:=warp*warp;
      if IsShipFunc(sh,hfGravitonic) then _travel:=_travel*2;
      _fuel:=Engines[El].burn[warp];
      _pmass:=mass;
      CorrectShipMass( @sh, _pmass);
      _mass_save := _pmass;
      _mass:=Max(_pmass div 10,1);
      if not AccurateFuelModel and PHOST then _mass:=Max(ERND(_pmass/10.0),1);
      i:=IIF(mission=7,tow_ship,0);
      if i>0 then               { tow }
      begin                     { what about self-towing? }
        {h1:=TTurn^.data^.ship[i];}
        h1 := tow_sh;
        if (h1<>nil) and (h1^.mass<>-1) and (h1^.hull<>-1) then
        begin
          _pmass:=h1^.mass;
          {Ship cannot Alchemy and Rafinery at once}
          CorrectShipMass( h1, _pmass);
          if TSh=i then inc(_pmass,TN+TT+TD+TM+TC+TS);
          if PHOST then { HOST rounds both masses to multiple of 10, PHost rounds just the sum }
          begin
            inc(_pmass,_mass_save);
            _mass:=0;
          end;
          inc(_mass,Max(_pmass div 10,1));
          if not AccurateFuelModel and PHOST then _mass:=Max(ERND(_pmass/10.0),1);
        end;
      end;
    
      if PHOST then CalcMovePHOST
               else CalcMoveTim;
      inc(x,dx); dec(wx,dx);
      inc(y,dy); dec(wy,dy);
      dec(mass,Max(Min(_fuel,fuel),0));
      dec(fuel,_fuel);
    
      if fuel>=0 then   { don't add fuel in Cobol runs out of fuel - to show BURN, not MAKE }
       if Mission<>8 then
        if IsShipFunc(sh, hfRamScoop) then
         fuel:=Min(Round(fuel+_sdist*RamScoop),Hulls[hull].fuel);

      if warp>1 then
      begin
        Location(x,y);  
        x:=LocationX;
        y:=LocationY;
      end;
    end;
  END;  (* CalcMove *)

procedure CalcMovement (h,tow_h:sptr; var burn,time:int);
  var   sh      : SRec;
  begin
    with h^ do
    if (hull=-1) or (mission=-1) or (fuel=-1) or (mass=-1) or (warp=-1) or (El=-1) then
    begin
      burn:=20000;
      time:=20000;
      Exit;
    end;
    sh:=h^;
    time:=0;
    repeat { CalcMove must be called at least once for cloaking without moving }
      if time>=100 then
      begin
        burn:=20000;
        time:=20000;
        Break;
      end;
      {if (not NoFuelMove) and (sh.fuel=0) then Break;}
      CalcMove(sh,tow_h,No);
      inc(time);
    until (sh.warp=0) or (sh.wx or sh.wy=0);
    burn:=h^.fuel-sh.fuel;
  end;

{function CloakFuel (h:sptr) : int;
  begin
    CloakFuel:=0;
    with h^ do
    if (IsShipFunc(h^,hfCloak)) and
       ((mission in [10,ExtMissionsStartAt+10]) or ((Race[owner]=3) and (mission in [9,ExtMissionsStartAt+9]))) then
      CloakFuel:=Max(Hulls[hull].mass*CloakFuelBurn div 100,CloakFuelBurn);
  end;}

(*function CalcFuel (h:sptr) : long;
  var   mm,i2,n         : int;
        ef,r            : long;
        n1              : int;
        h1              : sptr;
        nd,dd,kf        : single;
  begin
    r:=0; n:=0;
    with h^ do
    begin
      if (warp=-1) or (mission=-1) then r:=-1 else
      if (warp>0) and (wx or wy<>0) then
      begin
        dd:=wx; nd:=wy;
        dd:=Sqrt(dd*dd+nd*nd);            [ XREF to LockDistTarget ]
        mm:=mass;
        n1:=IIF(mission=7,tow_ship,0);
        if n1>0 then               [ tow ]
        begin
          h1:=TTurn^.data^.ship[n1];
          if (h1<>nil) and (h1^.mass<>-1) then inc(mm,h1^.mass);
          if TSh=n1 then inc(mm,TN+TT+TD+TM+TC+TS);
        end;
        i2:=warp*warp;
        if IsShipFunc(h^,hfGravitonic) then i2:=i2*2;
        ef:=Engines[El].burn[warp];
        kf:=ef/100000;
        n:=Ceil(dd/i2);
        dec(n);
        if n>0 then inc(r,Trunc(long(mm)*(1-Exp(n*Ln(1-kf)))));
        nd:=dd-i2*n;
        inc( r , Trunc(nd*((long(mm)-MinL(r,fuel)) div 10)*(ef/i2)/10000) );
      end;
      inc(n);
      inc(r,long(CloakFuel(h))*n);
    end;
    CalcFuel:=r;
  end;*)

(*function ETA (h:sptr) : int;
  var   i2      : int;
        dd      : long;
  begin
    ETA:=0;
    with h^ do
    begin
      if (warp=0) or (wx or wy=0) then Exit;
      i2:=warp*warp;                    [ XREF to LockDistTarget ]
      if IsShipFunc(h^,hfGravitonic) then i2:=i2*2;
      dd:=Distance2(0,0,wx,wy);
      if dd<(i2+1)*(i2+1) then ETA:=1 else ETA:=Ceil(Sqrt(dd)/i2);     [ XREF to Report ]
    end;
  end;*)

procedure SetShipMass (var h:SRec);
  begin
    h.mass:=Hulls[h.hull].mass+h.weapons*Beams[h.Wl].mass+h.launchers*Torps[h.Tl].mass+
            h.fuel+h.T+h.D+h.M+h.Sup+h.colonists+h.TFnum;
    h.mass1:=h.mass;
    h.mass2:=h.mass;
  end;

procedure RandomFCode (var s:fcstr);
  begin
    s[1]:=FCChar[Random(36)];
    s[2]:=FCChar[36+Random(26)];
    s[3]:=FCChar[Random(62)];
  end;

procedure ChangeData (xt:xtype; n:int);
  begin
    dec(n);
    Changed[xt,n div 8]:=Changed[xt,n div 8] or (1 shl (n and 7));
    DataChg:=Yes;
    ExtFeatChangeDataHook(xt, n+1);
  end;

function IfChanged (xt:xtype; n:int) : boolean;
  begin
    dec(n);
    IfChanged:=(Changed[xt,n div 8] and (1 shl (n and 7)) <> 0);
  end;

{$IFDEF VPACC}
function IsShipFunc3 (const sh:SRec; a,b,c:int):boolean;
  var omask,xmask,i:int;
  begin
    if (sh.ship_id > 0) and (sh.ship_id <= NUM_SHIPS) then begin
      { do we know the hull? }
      if sh.hull > 0 then begin
        if sh.owner > 0 then omask := 1 shl sh.owner else omask := -1;
        i := ShipExperience(sh.ship_id);
        if i >= 0 then xmask := 1 shl i else xmask := -1;
        if HullDoes(sh.hull, a, b, c, omask, xmask, hf_NoNewShips) then begin
          IsShipFunc3 := true;
          Exit;
        end;
      end;
      { just ask whether it has a ship-specific function }
      IsShipFunc3 := ShipDoes(sh.ship_id, a, b, c);
    end else begin
      IsShipFunc3 := false;
    end;
  end;

{ check whether ship has a function }
function IsShipFunc (const sh:SRec; f:HullFuncs):boolean;
  begin
    IsShipFunc := IsShipFunc3(sh, int(f), -1, -1);
  end;

procedure EnumNewShipFunctions(var qr:THullFuncQueryResult; hull:int);
  var player_ :int;
  begin
    if player>20 then player_ := player-20 else player_ := player;
    qr.count := EnumHullfuncsForHull(hull, nil, 0, 1 shl player_, -1, hf_NoRacialAbilities);
    if qr.count<>0 then begin
      qr.data := Malloc(qr.count * SizeOf(THullFunction));
      if qr.data=nil then qr.count := 0
                     else EnumHullfuncsForHull(hull, qr.data, 0, 1 shl player_, -1, hf_NoRacialAbilities);
    end;
  end;

procedure EnumExistingShipFunctions(var qr:THullFuncQueryResult; sh:sptr; all:boolean);
  var q : THullFuncSelection;
      i : int;
  begin
    q.ship_id := sh^.ship_id;
    q.hull_id := sh^.hull;
    if (sh^.owner > 0) and not all then q.filter_owner_mask := 1 shl sh^.owner else q.filter_owner_mask := -1;
    i := ShipExperience(q.ship_id);
    if (i >= 0) and not all then q.filter_level_mask := 1 shl i else q.filter_level_mask := -1;
    if all then i:=0 else i:=hf_NoRacialAbilities;
    qr.count := EnumHullfuncs(q, nil, 0, i);
    if qr.count<>0 then begin
      qr.data := Malloc(qr.count * SizeOf(THullFunction));
      if qr.data=nil then qr.count := 0
                     else EnumHullfuncs(q, qr.data, 0, i);
    end;
  end;

procedure FreeShipFuncQueryResult(var qr:THullFuncQueryResult);
  begin
    if qr.count<>0 then FreeMem(qr.data, qr.count * SizeOf(THullFunction));
  end;

{$ELSE}
function IsHullFunc (h:byte; f:HullFuncs) : int;
  { devuelve el indice 1-based del par (h,f) en HullFunc, o 0 si no esta }
  var i : int;  key : word;
  begin
    IsHullFunc := 0;
    key := (word(ord(f)) shl 8) or h;
    for i := 1 to HullFN do
      if word(HullFunc^[i]) = key then begin IsHullFunc := i; Exit; end;
  end;

{ check whether ship has a function }
function IsShipFunc (const sh:SRec; f:HullFuncs):boolean;
  begin
    IsShipFunc := (IsHullFunc(sh.hull, f) <> 0);
  end;
function ShipOrHullDoes(sid:integer; f1,f2,f3:integer):boolean;
  { La nave sid (o su casco) tiene alguna de las funciones f1/f2/f3 (codigos SPC_*)?
    VPA usa el modelo antiguo de hull-functions (array HullFunc^, funciones 0..19,
    cargado en CONFIG), que ya combina casco + ajustes del host. Para ese modelo
    IsHullFunc equivale al hullHasSpecial del PDK; aqui solo puenteamos los SPC_*. }
  begin
    ShipOrHullDoes := False;
    if (sid>=1) and (sid<=999) and (TTurn<>nil) and (TTurn^.data<>nil)
       and (TTurn^.data^.ship[sid]<>nil) then
      ShipOrHullDoes := IsShipFunc3(TTurn^.data^.ship[sid]^, f1, f2, f3);
  end;
function IsShipFunc3 (const sh:SRec; a,b,c:int):boolean;
  { Tiene la nave alguna de las funciones a/b/c (codigos SPC_*)? Los SPC_* 0..19
    coinciden con el ordinal de HullFuncs; los >=20 (ChunnelSelf/Others/Target,
    HardenedCloak...) son refinamientos de PHost que el modelo antiguo de VPA no
    distingue (los agrupa en hfChunneling/hfCloak), asi que se ignoran. }
  var r : boolean;
  begin
    r := False;
    if (a>=0) and (a<=ord(hfGloryDeviceH)) then r := r or IsShipFunc(sh, HullFuncs(a));
    if (b>=0) and (b<=ord(hfGloryDeviceH)) then r := r or IsShipFunc(sh, HullFuncs(b));
    if (c>=0) and (c<=ord(hfGloryDeviceH)) then r := r or IsShipFunc(sh, HullFuncs(c));
    IsShipFunc3 := r;
  end;
{$ENDIF}

{ Real owner of a ship }
function RealShipOwner(sid:int):int;
begin
  if (rcflags[sid]<>0) and (rcflags[sid]<>255)
   then RealShipOwner:=rcflags[sid]
   else RealShipOwner:=TTurn^.data^.ship[sid]^.owner;
end;

function IsAllied(bit:int;r1,r2:int):boolean;
begin
   if ((r1=r2) or (alliance[bit,r1,r2]=3)) then begin
      IsAllied:=TRUE;
      Exit;
   end;
   if ((alliance[4,r1,r2]>0) and
       ((alliance[bit,r1,r2]=2) or ((alliance[bit,r1,r2]>0) and (alliance[bit,r2,r1]>0)))) then
      IsAllied:=TRUE
   else
      IsAllied:=FALSE;
end;

function ControlPosition(xt:xtype; id:int):long;
begin
  if (xt=Sh) and (id>500) then
   ControlPosition := (1499+id)*4
  else
   ControlPosition := int(xt)*2000+(id-1)*4;
end;

{$IFOPT N-}
{ round to nearest or even. In IEEE FP mode, Turbo's "Round" already does
  what we want, but not in 48-bit-FP mode }
function  Round(n : real):long;
var  res : long;
begin
  res := System.Round(n);
  if odd(res) and (res - n = 0.5) then dec(res);
  Round := res;
end;
{$ENDIF}

function UnderTow (id:int) : int;       { tower's id or 0 }
  var   i       : int;
        h0,h1   : sptr;
  begin
    UnderTow:=0;
    h0:=TTurn^.data^.ship[id];
    if (h0=NIL) or (h0^.when<>turn) then Exit;
    for i:=1 to 999 do
    begin
      h1:=TTurn^.data^.ship[i];
      if (i<>id) and (h1<>nil) and (h1^.when=turn) and
         (h1^.mission=7) and (h1^.tow_ship=id) and
         (h0^.x=h1^.x) and (h0^.y=h1^.y) then
        begin UnderTow:=i; Exit end;
    end;
  end;


function InGravityWell(pid:int;x,y:int):boolean;
var xx,yy:int;
begin
  xx:=TTurn^.data^.xyplan[pid,1];
  yy:=TTurn^.data^.xyplan[pid,2];
  InGravityWell:=((RoundWells and
                  (Distance2(x,y,xx,yy)<=GravityRange*GravityRange)) or
                  ((not RoundWells) and
                  (Abs(x-xx)<=GravityRange) and (Abs(y-yy)<=GravityRange)))
end;
function NextTurnOnPlanet(pid:int;sid:int;speed:int):boolean;
var s:sptr;
    x,y,d:int;
begin
  s:=TTurn^.data^.ship[sid];
  if ((s<>NIL) and (s^.when=today)) then begin
    if (speed<0) then speed:=s^.warp;
    speed:=speed*speed;
    d:=Round(sqrt(s^.wx*s^.wx+s^.wy*s^.wy));
    if (d<=speed) then begin
      x:=s^.x+s^.wx;
      y:=s^.y+s^.wy;
    end else begin
      x:=s^.x+round(long(s^.wx)*speed/d);
      y:=s^.y+round(long(s^.wy)*speed/d);
    end;
    NextTurnOnPlanet:=InGravityWell(pid,x,y)
  end else
    NextTurnOnPlanet:=FALSE
end;

function  ShipID(p:sptr):integer;
var i:integer;
begin
  if p=NIL then ShipID:=0
  else begin
    for i:=1 to NUM_SHIPS do
      if (TTurn^.data^.ship[i]=p) then begin
        ShipID:=i;
        exit;
      end;
  end;
  ShipID:=0;
end;
function  PlanetID(p:pptr):integer;
var i:integer;
begin
  if p=NIL then PlanetID:=0
  else begin
    for i:=1 to NUM_PLANETS do
      if (TTurn^.data^.planet[i]=p) then begin
        PlanetID:=i;
        exit;
      end;
  end;
  PlanetID:=0;
end;

{ The following functions copied from PCC: }
{ Get cost of a starbase }
PROCEDURE GetBaseCost(player : INTEGER; VAR c:TFullPrice);
BEGIN
  IF StarbaseCostSet THEN BEGIN
    IF (player > 0) AND (player <= 11) THEN c := StarbaseCost[player]
                                       ELSE c := StarbaseCost[1]
  END ELSE BEGIN
    c.MC := 900;
    c.Tri := 402;
    c.Dur := 120;
    c.Mol := 340;
    c.Supplies := 0;
  END;
END;

{ Get cost of a fighter }
PROCEDURE GetFighterCost(player : INTEGER; VAR c:TFullPrice);
BEGIN
  IF BaseFighterCostSet THEN BEGIN
    IF (player > 0) AND (player <= 11) THEN c := BaseFighterCost[player]
                                       ELSE c := BaseFighterCost[1]
  END ELSE BEGIN
    c.MC := 100;
    c.Tri := 3;
    c.Dur := 0;
    c.Mol := 2;
    c.Supplies := 0;
  END;
END;

{ Get cost of a fighter on ship }
PROCEDURE GetShipFighterCost(player : INTEGER; VAR c:TFullPrice);
BEGIN
  IF ShipFighterCostSet THEN BEGIN
    IF (player > 0) AND (player <= 11) THEN c := ShipFighterCost[player]
                                       ELSE c := ShipFighterCost[1]
  END ELSE BEGIN
    c.MC := 0;
    c.Tri := 3;
    c.Dur := 0;
    c.Mol := 2;
    c.Supplies := 5;
  END;
END;

{ Get cost of a "free" fighter }
PROCEDURE GetFreeFighterCost(player : INTEGER; VAR c:TFullPrice);
BEGIN
  IF FreeFighterCostSet THEN BEGIN
    IF (player > 0) AND (player <= 11) THEN c := FreeFighterCost[player]
                                       ELSE c := FreeFighterCost[1]
  END ELSE BEGIN
    c.MC := 0;
    c.Tri := 3;
    c.Dur := 0;
    c.Mol := 2;
    c.Supplies := 0;
  END;
END;

{ Get maximum allowed fighters on a base }
FUNCTION GetMaxFightersOnBase(player : INTEGER):INTEGER;
BEGIN
  IF (player>0) AND (player<=11) THEN BEGIN
    GetMaxFightersOnBase := MaximumFightersOnBase[player];
  END ELSE BEGIN
    GetMaxFightersOnBase := 60;
  END;
END;

{ Get maximum allowed defense on a base }
FUNCTION GetMaxDefenseOnBase(player : INTEGER):INTEGER;
BEGIN
  IF (player>0) AND (player<=11) THEN BEGIN
    GetMaxDefenseOnBase := MaximumDefenseOnBase[player];
  END ELSE BEGIN
    GetMaxDefenseOnBase := 200;
  END;
END;

function PlanetCanBuildBase(p:pptr) : boolean;
var sbc : TFullPrice;
begin
  GetBaseCost(p^.owner, sbc);
  PlanetCanBuildBase := (p^.funds+p^.supplies >= sbc.Supplies+sbc.MC)   
                    and (p^.supplies          >= sbc.Supplies)
                    and (p^.T                 >= sbc.Tri)
                    and (p^.D                 >= sbc.Dur)
                    and (p^.M                 >= sbc.Mol);
end;

function PlanetMayBuildBase(id:int) : boolean;
var sbc,rc : TFullPrice;
    j : int;
    p : pptr;
    s : sptr;
begin
  p := TTurn^.data^.planet[id];
  GetBaseCost(p^.owner, sbc);
  rc.MC := p^.funds;
  rc.supplies := p^.supplies;
  rc.Tri := p^.T;
  rc.Dur := p^.D;
  rc.Mol := p^.M;
  for j := 1 to NUM_SHIPS do begin
    s:=TTurn^.data^.ship[j];
    if ((s<>NIL)) then begin
      if ((s^.owner=player) and (TTurn^.data^.xyplan[id,1]=s^.x) 
      and (TTurn^.data^.xyplan[id,2]=s^.y)) then begin
        inc(rc.Tri,s^.T); inc(rc.Dur,s^.D); inc(rc.Mol,s^.M);
        inc(rc.MC,s^.credits); inc(rc.supplies,s^.sup);                           
      end;
    end;
  end;
  PlanetMayBuildBase := (rc.Supplies+rc.MC      >= sbc.Supplies+sbc.MC)   
                    and (rc.Supplies            >= sbc.Supplies)
                    and (rc.Tri                 >= sbc.Tri)
                    and (rc.Dur                 >= sbc.Dur)
                    and (rc.Mol                 >= sbc.Mol);
end;


function PlanetCanBuildFighter(p:pptr) : boolean;
var sbc : TFullPrice;
begin
  GetFighterCost(p^.owner, sbc);
  PlanetCanBuildFighter := (p^.funds+p^.supplies >= sbc.Supplies+sbc.MC)
                    and (p^.supplies          >= sbc.Supplies)
                    and (p^.T                 >= sbc.Tri)
                    and (p^.D                 >= sbc.Dur)
                    and (p^.M                 >= sbc.Mol);
end;

procedure InitVPAData;
Begin
  Randomize;
  FillChar(Changed,SizeOf(Changed),0);
  FillChar(rcflags, Sizeof(rcflags), 0);
  FillChar(alliance, Sizeof(alliance), 0);
  New(MineExplosions);
  MineExplosions^.next:=NIL;
End;

{ return the highest warp that the engine can fly without
  consuming excessive fuel - within 120% of the norm }
function  GetSafeWarp(engineLevel: integer): integer;
var lWarp: long;
begin
  for lWarp:=9 downto 1 do begin
    if (Engines[engineLevel].burn[lWarp] <= lWarp*lWarp*120) then begin
      GetSafeWarp := lWarp;
      exit;
    end;
  end;
end;


{ return the optimal warp for a ship }
function  GetOptimalWarp(pShip: sptr): integer;
var                                                         
  lDummyShip: SRec;
  eta, fuel, warp,
  newEta, newFuel, i: integer;
begin
  if (not OptimizeFuel) then begin
    GetOptimalWarp := GetSafeWarp(pShip^.el);
    exit;
  end;
  
  if (pShip^.mission = 8) then begin { intercept }
    GetOptimalWarp := GetSafeWarp(pShip^.El);
    exit;
  end;

  Location(pShip^.x+pShip^.wx,pShip^.y+pShip^.wy);
  if (LocationPlanet = 0) then begin
    { destination is no planet }
    GetOptimalWarp := GetSafeWarp(pShip^.El);
    exit;
  end;
  
  { start with safe warp, go down if it saves fuel }
  lDummyShip := pShip^;
  lDummyShip.warp := getSafeWarp(lDummyShip.El);
  warp := lDummyShip.warp;
  CalcMovement(@lDummyShip,StdTowPtr(lDummyShip), fuel, eta);


  for i:=lDummyShip.warp-1 downto 1 do begin
    lDummyShip.warp := i;
    CalcMovement(@lDummyShip,StdTowPtr(lDummyShip), newFuel, newEta);
    if (newEta = eta) and (newFuel < fuel) then begin
       warp := i;
       fuel := newFuel;
    end;
  end;
  GetOptimalWarp := warp;
end;

{Unity Addon disassembles 100 Colos in 50 Supps - Called from different points - Quapla}
function Unity_Disassemble(Unity_Planet : pptr) : int;
var _tmp : int;
begin
  Unity_Disassemble:=0;
  with Unity_planet^ do begin
    if ((owner=6) and (fcode[1]='D') AND (fcode[2]='A') AND
       (fcode[3] in ['1','2','3','4','5','6','7','8','9' ])) then begin
      _tmp:=(ord(fcode[3])-ord('0'))*50;      
      if (_tmp>(colonists-(_tmp*2))) then Unity_Disassemble := colonists div 2 
      else Unity_Disassemble:=_tmp;
    end;
  end;
end;

procedure CutShipNames(var s : string);
  var ls  : byte absolute s;
  begin
      ls:=RLen(s);
      StrSubst(s,' CLASS','');
      StrSubst(s,' TORPEDO','');
      if ls>18 then begin
        StrSubst(s,' DEEP SPACE','');
        StrSubst(s,' BLOCKADE','');
        StrSubst(s,'EY SHIP','EYER');
        StrSubst(s,' VESSEL','ER');
        StrSubst(s,'BATTLE','B-');
        StrSubst(s,'NEUTRONIC','N.');
        StrSubst(s,'T FREIGHTER','T');
        StrSubst(s,'SUPER-','');
        StrSubst(s,' LIGHT','');
        if ls>18 then begin
            StrSubst(s,'CRUISER','CR.');
            StrSubst(s,'CARRIER','CARR.');
            StrSubst(s,'DESTROYER','DS.');
            StrSubst(s,'FRIGATE','FR.');
            StrSubst(s,'TRANSPORT','TR.');
            StrSubst(s,'BASESHIP','BS.');
            StrSubst(s,'SHIP','SH.');
        end;
      end;
      if ls>18 then ls:=18;
      while ls<18 do s:=s+' ';
  end;

end.
