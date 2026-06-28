{$I switches.inc}
Unit PVCRALG;   (* Algoritmo de combate PHost nativo (port de PCC2ng) *)
{$V-}
{ ===========================================================================
  Port a Free Pascal del algoritmo de combate de PHost de PCC2ng:
  game/vcr/classic/pvcralgorithm.cpp y su interfaz Visualizer.
  Derivado de PCC2ng (c2ng), (c) Stefan Reuther & contributors, bajo los
  "PCC II License Terms" (licencia permisiva tipo BSD: retener este copyright
  y marcar las modificaciones; no es GPL).

  FASE A (andamiaje): tipos del combatiente (Object), interfaz de visualizador
  (los 8 eventos) y el mapeo del registro VCR de VPA -> Object. El algoritmo en
  si (initBattle/playCycle/...) queda como STUB; su matematica se porta en la
  Fase B. Ver README seccion 7.
  =========================================================================== }

Interface

uses AuxF, VPAData;   { int (AuxF); VCRData, LRtype, ch20 (VPAData) }

type
  { Un combatiente del VCR (equivalente a game::vcr::Object de PCC2ng). }
  TVcrObject = record
    name        : ch20;
    mass        : int;
    shield      : int;
    damage      : int;
    crew        : int;
    id          : int;
    owner       : int;
    raceOrZero  : int;
    picture     : int;
    hullOrZero  : int;
    beamType    : int;
    numBeams    : int;
    torpType    : int;
    numTorps    : int;     { municion de torpedos }
    numLaunchers: int;
    numBays     : int;
    numFighters : int;
    experience  : int;
    isPlanet    : boolean;
  end;

  { Lado del combate (left/right del registro). }
  TVcrSide = (vsLeft, vsRight);

  { --- Interfaz "visualizador": los 8 eventos que el algoritmo emite. VPA los
    implementara con sus rutinas de TCOMBAT (Fase C), inyectandolas en este
    record. En el momento del evento, el implementador puede consultar el estado
    via las funciones Get* de abajo (posiciones, escudos, municion...). --- }
  TVcrFtrProc   = procedure (side:TVcrSide; track:int);
  TVcrBeamProc  = procedure (side:TVcrSide; track,target,hit,damage,kill:int);
  TVcrTorpProc  = procedure (side:TVcrSide; hit,launcher:int);
  TVcrUpdProc   = procedure (side:TVcrSide; id:int);
  TVcrKillProc  = procedure (side:TVcrSide);

  TVcrVisualizer = record
    startFighter   : TVcrFtrProc;
    landFighter    : TVcrFtrProc;
    killFighter    : TVcrFtrProc;
    fireBeam       : TVcrBeamProc;
    fireTorpedo    : TVcrTorpProc;
    updateBeam     : TVcrUpdProc;
    updateLauncher : TVcrUpdProc;
    killObject     : TVcrKillProc;
  end;

{ --- Mapeo de datos (verificado por offset contra game/v3/structures.hpp de
  PCC2ng: Vcr=100 bytes, VcrObject=42). El VCRData de VPA se lee tal cual de
  VCRx.DAT, asi que ES el registro VCR clasico con otros nombres de campo. --- }
procedure MapVCR (var vcr: VCRData;
                  var lobj, robj: TVcrObject;
                  var seed, signature, flags, battleType: word);

{ --- Algoritmo (STUB en Fase A; se implementa en la Fase B). --- }
procedure InitBattle (var left, right: TVcrObject; seed: word;
                      var vis: TVcrVisualizer);
function  PlayCycle : boolean;      { ejecuta un turno; False cuando el combate termina }
procedure PlayFastForward;          { ejecuta hasta el final sin emitir animacion }
procedure DoneBattle (var left, right: TVcrObject);

{ --- Consulta de estado en curso (la usa el visualizador). STUB en Fase A. --- }
function  GetShield      (side:TVcrSide): int;
function  GetDamage      (side:TVcrSide): int;
function  GetCrew        (side:TVcrSide): int;
function  GetNumTorps    (side:TVcrSide): int;
function  GetNumFighters (side:TVcrSide): int;
function  GetObjectX     (side:TVcrSide): int;   { posicion del baseship, en metros }

Implementation

var
  { Estado del combate activo (un combate a la vez). La Fase B lo ampliara con
    los arrays de estado de beams/launchers/bays/fighters, el RNG, etc. }
  gLeft, gRight : TVcrObject;
  gVis          : TVcrVisualizer;
  gSeed         : word;

{ --------------------------------------------------------------------------- }
procedure MapVCR (var vcr: VCRData;
                  var lobj, robj: TVcrObject;
                  var seed, signature, flags, battleType: word);

  procedure MapSide (lr: LRtype; var o: TVcrObject);
  begin
    with vcr.dd[lr] do
    begin
      o.name        := name;
      o.damage      := dam;
      o.crew        := crew;
      o.id          := id;
      o.owner       := race;                   { byte @26 = owner }
      o.raceOrZero  := realrace;               { byte @27 = raceOrZero }
      o.picture     := word(pic) and $FF;          { byte bajo @28 = pictureNumber }
      o.hullOrZero  := (word(pic) shr 8) and $FF;  { byte alto @29 = hullTypeOrZero }
      o.beamType    := wl;                      { int @30 = beamType }
      o.numBeams    := word(weaps) and $FF;         { byte bajo @32 = numBeams }
      o.experience  := (word(weaps) shr 8) and $FF; { byte alto @33 = experienceLevel }
      o.numBays     := bays;                    { int @34 = numBays }
      o.torpType    := tl;                      { int @36 = torpedoType }
      o.isPlanet    := (lr = Right) and (vcr.planet <> 0);
      { Desempaquetar municion (logica de database.cpp): tfn=ammo @38,
        launs=numLaunchersPacked @40. }
      if launs <> 0 then
      begin
        { TODO (fase config): si isPlanet y PlanetsHaveTubes, 'launs' codifica
          launchers(byte bajo)+torps(byte alto) y la municion son fighters.
          Por ahora se asume la rama de naves con torpedos. }
        o.numLaunchers := launs;
        o.numTorps     := tfn;
        o.numFighters  := 0;
      end
      else begin
        o.numLaunchers := 0;
        o.numTorps     := 0;
        if bays <> 0 then o.numFighters := tfn else o.numFighters := 0;
      end;
    end;
    o.mass   := vcr.shpw[lr];
    o.shield := vcr.shld[lr];
  end;

begin
  seed       := word(vcr.K0);
  signature  := word(vcr.int0);
  flags      := word(vcr.plnpic);
  battleType := word(vcr.planet);
  MapSide(Left,  lobj);
  MapSide(Right, robj);
end;

{ --------------------------------------------------------------------------- }
procedure InitBattle (var left, right: TVcrObject; seed: word;
                      var vis: TVcrVisualizer);
begin
  gLeft := left;  gRight := right;
  gVis  := vis;   gSeed  := seed;
  { STUB Fase A: la Fase B precalcula config (hit odds, recharge rates,
    kill/damage), inicializa el RNG y el estado de beams/launchers/bays. }
end;

function PlayCycle : boolean;
begin
  { STUB Fase A: la Fase B ejecuta un turno de combate (recarga, disparo de
    beams/torps, fighters, hits, comprobacion de fin) emitiendo los eventos. }
  PlayCycle := False;   { 'terminado' por ahora }
end;

procedure PlayFastForward;
begin
  { STUB Fase A: la Fase B ejecuta hasta el final sin emitir animacion. }
end;

procedure DoneBattle (var left, right: TVcrObject);
begin
  { STUB Fase A: la Fase B hace las explosiones finales y copia el estado
    resultante (damage/crew/shield/municion) de vuelta a los objetos. }
  left := gLeft;  right := gRight;
end;

{ --- Consulta de estado (STUB Fase A; la Fase B lee el estado real). --- }
function GetShield      (side:TVcrSide): int;
begin if side=vsLeft then GetShield:=gLeft.shield else GetShield:=gRight.shield; end;

function GetDamage      (side:TVcrSide): int;
begin if side=vsLeft then GetDamage:=gLeft.damage else GetDamage:=gRight.damage; end;

function GetCrew        (side:TVcrSide): int;
begin if side=vsLeft then GetCrew:=gLeft.crew else GetCrew:=gRight.crew; end;

function GetNumTorps    (side:TVcrSide): int;
begin if side=vsLeft then GetNumTorps:=gLeft.numTorps else GetNumTorps:=gRight.numTorps; end;

function GetNumFighters (side:TVcrSide): int;
begin if side=vsLeft then GetNumFighters:=gLeft.numFighters else GetNumFighters:=gRight.numFighters; end;

function GetObjectX     (side:TVcrSide): int;
begin GetObjectX := 0; end;   { STUB: posicion la calcula la Fase B }

end.
