{
  UTILx.DAT format definition. This file is shared between VPA and PCC.
}
{$I switches.inc}
UNIT UtilFmt;
{$V-}

INTERFACE

{$IFNDEF VPA}
USES Global;
{$ELSE}
USES VPAData;

TYPE TFCode = ARRAY[1..3] OF CHAR;
     TTimestamp = TimeStamp;
     TTarget = RECORD
         id   : INTEGER;
         t    : STRec;
     END;
{$ENDIF}

{ Type 0: Mine field }
TYPE Util0Minefield = RECORD
          id       : INTEGER;
          x, y     : INTEGER;
          owner    : INTEGER;
          units    : LONGINT;
          web      : INTEGER;
          fcplanet : INTEGER;
          action   : INTEGER;
     END;

TYPE Util1Explosion = RECORD
          x, y     : INTEGER;
          sid      : INTEGER;
     END;

TYPE Util2MineHit = RECORD
          sid      : INTEGER;
          x, y     : INTEGER;
          damage   : INTEGER;
     END;

TYPE Util3DarkSense = RECORD
          pid     : INTEGER;
          owner   : INTEGER;
          n, t, d, m : LONGINT;
          mc      : LONGINT;
          base    : INTEGER;
     END;

TYPE Util4SuperSpy = RECORD
          pid        : INTEGER;
          mines, factories, defense : INTEGER;
          fc         : TFCode;
          n, t, d, m : LONGINT;
          mc         : LONGINT;
          supplies   : LONGINT;
     END;

TYPE Util5Explore = RECORD
          pid        : INTEGER;
          temp       : INTEGER;
          owner      : INTEGER;
          colonists  : LONGINT;
          base       : INTEGER;
     END;

TYPE Util6Sensor = RECORD
          pid        : INTEGER;
          owner      : INTEGER;
          activity   : INTEGER;
     END;

TYPE Util7Battle = RECORD
          sid1, sid2         : INTEGER;
          isplanet2          : INTEGER;
          owner1, owner2     : INTEGER;
          damage1, damage2   : INTEGER;
          torps1, torps2     : INTEGER;
          ftr1, ftr2         : INTEGER;
          outcome1, outcome2 : INTEGER;
          locx, locy         : INTEGER;
          seed               : INTEGER;
     END;

TYPE Util8Meteor = RECORD
          pid        : INTEGER;
          n, t, d, m : LONGINT;
     END;

TYPE Util9Meteor = Util8Meteor;

TYPE Util10Target = TTarget;

TYPE Util11Base = RECORD
          bid        : INTEGER;
          owner      : INTEGER;
     END;

TYPE Util12Planet = RECORD
          pid        : INTEGER;
          owner      : INTEGER;
          temp       : INTEGER;
          ntype      : INTEGER;
          ngov       : INTEGER;
          natives    : LONGINT;
          n, t, d, m : LONGINT;
          colonists  : LONGINT;
          sup, mc    : LONGINT;
     END;

TYPE Util13Control = RECORD
          timestamp  : TTimestamp;
          turn       : INTEGER;
          player     : INTEGER;
          major, minor : BYTE;
          digest     : ARRAY[1..8] OF LONGINT;
          game       : ARRAY[1..32] OF CHAR;
          release    : CHAR;
     END;

TYPE Util14Wormhole = RECORD
          x, y       : INTEGER;
          mass       : INTEGER;
          stable     : INTEGER;
          id         : INTEGER;
     END;

TYPE Util15WormTravel = RECORD
          sid        : INTEGER;
          x, y       : INTEGER;
          newdamage  : INTEGER;
          totaldamage : INTEGER;
          wormid     : INTEGER;
     END;

TYPE Util16Recycle = RECORD
          sid, bid   : INTEGER;
     END;

TYPE Util17IonStorm = RECORD
          stormid    : INTEGER;
          x, y       : INTEGER;
          volt       : INTEGER;
          head       : INTEGER;
          speed      : INTEGER;
          radius     : INTEGER;
          class      : INTEGER;
          grow       : INTEGER;
     END;

TYPE Util18LnD = RECORD
          sid, pid   : INTEGER;
     END;

TYPE Util19Surrender = RECORD
          sid, bid   : INTEGER;
          baseowner  : INTEGER;
     END;

TYPE Util20ShipBuilt = RECORD
          sid, bid   : INTEGER;
          cloned     : INTEGER;
     END;

TYPE Util21ShipTrade = RECORD
          sid        : INTEGER;
          oldown, newown : INTEGER;
     END;

{ Alliance report. This one is special. Because we binary-fiddle it
  before using it, do not define it as TPHostAllianceRecord. }
TYPE Util22Alliance = ARRAY[1..44] OF BYTE;

TYPE Util23Bioscan = RECORD
          pid        : INTEGER;
          ntype      : INTEGER;
          npop       : LONGINT;
          temp       : INTEGER;
     END;

TYPE Util24Glory = RECORD
          sid, x, y  : INTEGER;
     END;

TYPE Util25GloryDamage = RECORD
          sid, x, y  : INTEGER;
          damage, owner : INTEGER;
     END;

TYPE Util26Boarding = RECORD
          sid        : INTEGER;
          oldown, newown : INTEGER;
          boarderid  : INTEGER;
     END;

{ TYPE Util27 = no longer used }

TYPE Util28GroundCombat = RECORD
          pid        : INTEGER;
          owner      : INTEGER;
          attacker   : INTEGER;
          outcome    : INTEGER;
     END;

TYPE Util29MinesExplode = RECORD
          x1, y1, mid1 : INTEGER;
          x2, y2, mid2 : INTEGER;
          units      : LONGINT;
     END;

{ TYPE Util30EndOfPHost = void }

TYPE Util31MineScoop = RECORD
          sid, mid   : INTEGER;
          torps      : INTEGER;
          units      : LONGINT;
          origunits  : LONGINT;
     END;

TYPE Util32Pillage = RECORD
          pid        : INTEGER;
          colonists  : LONGINT;
          natives    : LONGINT;
     END;

TYPE Util33GO = RECORD
          oid, x, y  : INTEGER;
          color      : INTEGER;
          radius     : INTEGER;
          speed      : INTEGER;
          head       : INTEGER;
          name, info1, info2 : ARRAY[1..20] OF CHAR;
          utilcode   : INTEGER;
     END;

{ TYPE Util34FTP = ... }

TYPE Util35CloakFail = RECORD
          sid        : INTEGER;
          reason     : INTEGER;
     END;

TYPE Util36Loki = RECORD
          sid        : INTEGER;
          x, y, owner : INTEGER;
     END;

{ TYPE Util37RC }

TYPE Util38PAL = RECORD
          old, decay, new, total : LONGINT;
     END;

TYPE PUtil39QueueEntry = ^Util39QueueEntry;
     Util39QueueEntry = RECORD
          bid        : INTEGER;
          hull       : INTEGER;
          qpos       : INTEGER;
          prio       : LONGINT;
     END;

TYPE Util40WebDrain = RECORD
          sid        : INTEGER;
     END;

TYPE Util41RGA = RECORD
          pid        : INTEGER;
          native_flag : INTEGER;
     END;

TYPE Util42GODestruction = RECORD
          oid        : INTEGER;
          typecode   : INTEGER;
     END;

TYPE Util43MinefieldStatus = RECORD
          limits, counts : ARRAY[1..11] OF INTEGER;
     END;

TYPE Util44Failure = RECORD
          action     : INTEGER;
          sid, pid   : INTEGER;
          cause      : INTEGER;
     END;

TYPE Util45PlanetTrade = Util21ShipTrade;

TYPE Util46Minefield = Util0Minefield;

{ 47 = Non-existant planet list = array of integer }

{ 48 = PAL summary = array of long }

TYPE Util49ShipScore = RECORD
          name       : ARRAY[1..50] OF CHAR;
          id         : INTEGER;
          limit      : INTEGER;
          { followed by id/score pairs }
     END;
     Util50PlanetScore = Util49ShipScore;

CONST uscore_Experience = 1;

TYPE Util51PlayerScore = RECORD
          name       : ARRAY[1..50] OF CHAR;
          id         : INTEGER;
          turnlimit  : INTEGER;
          scorelimit : LONGINT;
          scores     : ARRAY[1..11] OF LONGINT;
     END;

CONST pscore_GameScore    = 1;
      pscore_BuildPoints  = 2;
      pscore_MinesAllowed = 3;
      pscore_MinesLaid    = 4;

{ 52 - Ship Abilities = array of integer, first is ship Id }

TYPE Util53OneMinefieldExploding = RECORD
                                     x, y  : INTEGER;
                                     id    : INTEGER;
                                     units : LONGINT;
                                   END;

{ 54 - enemies = word }

TYPE Util55Production = RECORD
                          sid    : INTEGER;
                          what   : INTEGER;
                          how    : INTEGER;
                          amount : INTEGER;
                        END;

TYPE Util56Repair = RECORD
                      sid         : INTEGER;
                      reason      : INTEGER;
                      repairer_id : INTEGER;
                      damage      : INTEGER;
                      crew        : INTEGER;
                    END;

TYPE Util57SpecialDef = RECORD
                          id        : INTEGER;
                          func      : INTEGER;
                          levelmask : INTEGER;
                        END;

IMPLEMENTATION

END.
