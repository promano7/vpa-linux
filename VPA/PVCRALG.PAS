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
procedure SetPhost3   (flag:boolean);  { PHost 3 vs 4 (afecta intercept de fighters); def. False }
procedure SetCapabilities (caps:word); { flags del VCR (capabilities); 0 por defecto }
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

{ --- RNG de PHost (bit-exacto). Generador congruencial lineal de 32 bits, el
  mismo de PHost (pvcr.pas / VcrPlayerPHost). Expuesto para poder validarlo y
  porque el algoritmo (InitBattle/PlayCycle) lo usa. --- }
procedure RngSeed         (seed:word);            { m_seed := seed shl 16 }
function  Random64k       : dword;                { LCG base }
function  RandomRange     (max:dword) : dword;    { uniforme en [0,max) }
function  RandomRange100  : int;                  { uniforme en [0,100) }
function  RandomRange100LT(comp:int) : boolean;   { rnd[0,100) < comp }

Implementation

const
  { limites de PCC2ng }
  VCR_MAX_BEAMS = 20;
  VCR_MAX_TORPS = 20;
  VCR_MAX_FTRS  = 50;
  VCR_MAX_BAYS  = 50;
  { tasas "Nu" del Object: VPA solo maneja PHost/THost (no Nu), asi que son las
    constantes por defecto de PCC2ng (object.cpp) }
  cBeamKillRate    = 1;
  cBeamChargeRate  = 1;
  cTorpMissRate    = 35;
  cTorpChargeRate  = 1;
  cCrewDefenseRate = 0;
  { estados de fighter }
  FighterIdle    = 0;
  FighterAttacks = 1;
  FighterReturns = 2;
  { bits de capability del VCR (game/v3/structures.hpp) }
  cDeathRayCapability   = 1;
  cExperienceCapability = 2;
  cBeamCapability       = 4;   { comportamiento beam/fighter nuevo desde 4.0k }

type
  { Valores precalculados que no cambian durante el combate (por lado).
    Modelo entero (PVCR_INTEGER, siempre activo en PCC2ng). Los recharge se
    guardan como el 'max' que se pasa a RandomRange (modelo no-prepared). }
  TFixedStatus = record
    side          : TVcrSide;
    beam_recharge, bay_recharge, torp_recharge : longint;
    beam_hit_odds, torp_hit_odds : longint;   { pueden superar 16-bit con bonus altos }
    beam_kill, beam_damage, torp_kill, torp_damage : int;
    scale, max_scaled, damage_limit_scaled, mass_plus1 : longint;
    ShieldDamageScaling, ShieldKillScaling, HullDamageScaling, CrewKillScaling : int;
    MaxFightersLaunched, StrikesPerFighter, BayLaunchInterval, FighterMovementSpeed : int;
    FighterBeamExplosive, FighterBeamKill, BeamHitFighterCharge, BeamHitShipCharge : int;
    FighterFiringRange, BeamHitFighterRange, BeamFiringRange,
    TorpFiringRange, ShipMovementSpeed : longint;
  end;

  { Valores que cambian durante el combate (por lado). }
  TRunningStatus = record
    obj              : TVcrObject;
    m_beamStatus     : array [0..VCR_MAX_BEAMS-1] of longint;  { [0,~1000] }
    m_launcherStatus : array [0..VCR_MAX_TORPS-1] of longint;
    m_bayStatus      : array [0..VCR_MAX_BAYS-1]  of longint;
    m_fighterStatus  : array [0..VCR_MAX_FTRS-1]  of byte;     { 0..2 }
    m_fighterStrikesLeft : array [0..VCR_MAX_FTRS-1] of longint;
    m_fighterX       : array [0..VCR_MAX_FTRS-1] of longint;
    m_objectX        : longint;                                { posicion baseship, en metros }
    m_activeFighters : int;
    m_launchCountdown: int;
    shield_scaled    : longint;   { escalado con scale }
    damage_scaled2   : longint;   { escalado con scale*100 }
    crew_scaled2     : longint;   { escalado con scale*100 }
  end;

  TSideStatus = record
    f : TFixedStatus;
    r : TRunningStatus;
  end;

var
  { Estado del combate activo (un combate a la vez). }
  m_status      : array [TVcrSide] of TSideStatus;
  gVis          : TVcrVisualizer;
  m_seed        : dword;     { semilla del RNG de PHost (32-bit) }
  m_alternativeCombat    : boolean;
  m_fireOnAttackFighters : boolean;
  m_standoffDistance     : longint;
  m_phost3Flag           : boolean;   { PHost 3 vs 4 (afecta intercept de fighters) }
  m_capabilities         : word;      { flags del VCR: DeathRay/Experience/Beam }
  m_interceptProbability : int;
  m_rightProbability     : int;
  m_done                 : boolean;
  m_time                 : longint;

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

{ ---------------------------------------------------------------------------
  RNG de PHost, bit-exacto. Aritmetica unsigned de 32 bits (dword); el wrap a
  2^32 se produce en la asignacion a m_seed (con overflow checks off, como el
  build). Referencias: pvcralgorithm.cpp (random64k/randomRange/...), pvcr.pas.
  --------------------------------------------------------------------------- }
procedure RngSeed (seed:word);
begin
  m_seed := dword(seed) shl 16;        { m_seed = uint32_t(seed) << 16 }
end;

function Random64k : dword;
begin
  { m_seed = 13489*65536 + m_seed * (-259), todo en uint32 (envuelve a 2^32) }
  m_seed := dword(13489*65536) + m_seed * dword(-259);
  Random64k := m_seed;
end;

function RandomRange (max:dword) : dword;
  var divisor, i : dword;
begin
  divisor := (dword(65535) div max) * dword(65536);
  repeat i := Random64k div divisor until i < max;
  RandomRange := i;
end;

function RandomRange100 : int;
  var i : dword;
begin
  repeat i := Random64k until i < dword(65500)*dword(65536);
  RandomRange100 := i div (dword(65536)*dword(655));
end;

function RandomRange100LT (comp:int) : boolean;
  var i : dword;
begin
  repeat i := Random64k until i < dword(65500)*dword(65536);
  i := i shr 16;
  { comp puede ser >100; 65536*655*comp rebosaria, asi que se desplaza i antes }
  RandomRange100LT := i < dword(comp) * dword(655);
end;

{ ---------------------------------------------------------------------------
  Precalculo (bloque 1 de la Fase B): port de initBattle de pvcralgorithm.cpp
  con PVCR_INTEGER (modelo entero, siempre activo en PCC2ng). Specs de armas:
  Beams[]/Torps[] de VPA (campo kill = kill power; expl = damage/destructive).
  --------------------------------------------------------------------------- }

function DivRound (a, b : longint) : longint;
  { util::divideAndRound / ccvcr.pas:RDiv : (a + b/2) / b (trunc hacia cero) }
begin DivRound := (a + (b div 2)) div b; end;

function PlayerRace (owner : int) : int;
  { getPlayerRaceNumber(owner): VPA mapea jugador->raza via Race[] }
begin
  if (owner >= 1) and (owner <= 11) then PlayerRace := Race[owner]
                                    else PlayerRace := owner;
end;

function EMV (var opt:IArr11; owner, lo, hi : int) : int;
  { getExperienceModifiedValue sin experiencia (EMod diferido a Fase F):
    clamp(opt[owner], lo, hi). }
  var v : int;
begin
  if (owner >= 1) and (owner <= 11) then v := opt[owner] else v := opt[1];
  { Fase F: if obj.experience<>0 then v := v + EModOpt[experience]; }
  if v < lo then v := lo else if v > hi then v := hi;
  EMV := v;
end;

{ Formulas documentadas de PHost. bkill/bdmg = kill+damage power del arma. }
function ComputeBeamHitOdds (bkill, bdmg : int; var o:TVcrObject) : longint;
  var i : longint;
begin
  i := longint(EMV(CombatCfg.BeamHitBonus, o.owner, -4095, 4095)) * (bkill + bdmg) div 100
       + EMV(CombatCfg.BeamHitOdds, o.owner, 0, 100);
  if i < 0 then i := 0;
  ComputeBeamHitOdds := i;
end;

function ComputeBeamRechargeRate (bkill, bdmg : int; var o:TVcrObject) : longint;
  var i : longint;
begin
  i := ( longint(bkill + bdmg) * EMV(CombatCfg.BeamRechargeBonus, o.owner, -4095, 4095) div 100
         + EMV(CombatCfg.BeamRechargeRate, o.owner, 0, 16384) ) * cBeamChargeRate;
  if i < 1 then i := 1;
  ComputeBeamRechargeRate := i;
end;

function ComputeTorpHitOdds (tkill, tdmg : int; var o:TVcrObject) : longint;
  var i : longint;
begin
  i := longint(EMV(CombatCfg.TorpHitBonus, o.owner, -4095, 4095)) * (tkill + tdmg) div 100
       + EMV(CombatCfg.TorpHitOdds, o.owner, 0, 100);
  if i < 0 then i := 0;
  ComputeTorpHitOdds := i;
end;

function ComputeTubeRechargeRate (tkill, tdmg : int; var o:TVcrObject) : longint;
  var i : longint;
begin
  i := ( longint(EMV(CombatCfg.TubeRechargeBonus, o.owner, -4095, 4095)) * (tkill + tdmg) div 100
         + EMV(CombatCfg.TubeRechargeRate, o.owner, 0, 16384) ) * cTorpChargeRate;
  if i < 1 then i := 1;
  ComputeTubeRechargeRate := i;
end;

function ComputeBayRechargeRate (num : int; var o:TVcrObject) : longint;
  var i : longint;
begin
  i := longint(EMV(CombatCfg.BayRechargeBonus, o.owner, -500, 500)) * num
       + EMV(CombatCfg.BayRechargeRate, o.owner, 0, 16384);
  if i < 1 then i := 1;
  ComputeBayRechargeRate := i;
end;

{ --------------------------------------------------------------------------- }
procedure SetPhost3 (flag:boolean);
begin m_phost3Flag := flag; end;

procedure SetCapabilities (caps:word);
begin m_capabilities := caps; end;

{ --------------------------------------------------------------------------- }
procedure InitBattle (var left, right: TVcrObject; seed: word;
                      var vis: TVcrVisualizer);

  procedure PrepSide (var st : TSideStatus; var o : TVcrObject);
    var i, owner, bt, tt, j, charge : int;
    begin
      st.r.obj := o;
      if m_alternativeCombat then st.f.scale := o.mass + 1
                             else st.f.scale := 1;
      st.r.shield_scaled  := longint(o.shield) * st.f.scale;
      st.r.crew_scaled2   := longint(o.crew)   * st.f.scale * 100;
      st.r.damage_scaled2 := longint(o.damage) * st.f.scale * 100;
      st.f.max_scaled     := longint(10000) * st.f.scale;
      st.f.mass_plus1     := longint(o.mass) + 1;
      owner := o.owner;
      { --- beams --- }
      if o.numBeams > 0 then begin
        bt := o.beamType;
        if (bt >= 1) and (bt <= 10) then begin
          st.f.beam_hit_odds := ComputeBeamHitOdds(Beams[bt].kill, Beams[bt].expl, o);
          st.f.beam_recharge := ComputeBeamRechargeRate(Beams[bt].kill, Beams[bt].expl, o);
          st.f.beam_kill     := Beams[bt].kill;
          st.f.beam_damage   := Beams[bt].expl;
        end else begin
          st.f.beam_hit_odds := 0; st.f.beam_recharge := 1;
          st.f.beam_kill := 0; st.f.beam_damage := 0;
        end;
      end else begin
        st.f.beam_hit_odds := 0; st.f.beam_recharge := 1;
        st.f.beam_kill := 0; st.f.beam_damage := 0;
      end;
      { --- torpedos --- }
      if o.numLaunchers > 0 then begin
        tt := o.torpType;
        if (tt >= 1) and (tt <= 10) then begin
          st.f.torp_hit_odds := ComputeTorpHitOdds(Torps[tt].kill, Torps[tt].expl, o);
          st.f.torp_recharge := ComputeTubeRechargeRate(Torps[tt].kill, Torps[tt].expl, o);
          st.f.torp_kill     := Torps[tt].kill;
          st.f.torp_damage   := Torps[tt].expl;
        end else begin
          st.f.torp_hit_odds := 0; st.f.torp_recharge := 1;
          st.f.torp_kill := 0; st.f.torp_damage := 0;
        end;
        if not m_alternativeCombat then begin
          st.f.torp_kill   := st.f.torp_kill   * 2;
          st.f.torp_damage := st.f.torp_damage * 2;
        end;
      end else begin
        st.f.torp_hit_odds := 0; st.f.torp_recharge := 1;
        st.f.torp_kill := 0; st.f.torp_damage := 0;
      end;
      { --- bahias --- }
      if o.numBays > 0 then st.f.bay_recharge := ComputeBayRechargeRate(o.numBays, o)
                       else st.f.bay_recharge := 0;
      { --- estado inicial --- }
      if o.shield >= 100 then charge := 1000 else charge := 0;
      for i := 0 to VCR_MAX_BEAMS-1 do st.r.m_beamStatus[i]     := charge;
      for i := 0 to VCR_MAX_TORPS-1 do st.r.m_launcherStatus[i] := charge;
      for i := 0 to VCR_MAX_BAYS-1  do st.r.m_bayStatus[i]      := 0;
      for i := 0 to VCR_MAX_FTRS-1  do begin
        st.r.m_fighterStatus[i]      := FighterIdle;
        st.r.m_fighterX[i]           := 0;
        st.r.m_fighterStrikesLeft[i] := 0;
      end;
      st.r.m_launchCountdown := 0;
      st.r.m_activeFighters  := 0;
      { --- damage limit (entero): Lizard (raza 2) llega a 150, resto a 100 --- }
      if PlayerRace(owner) = 2 then st.f.damage_limit_scaled := longint(150*2-1) * 50 * st.f.scale
                               else st.f.damage_limit_scaled := longint(100*2-1) * 50 * st.f.scale;
      { --- config cacheada/ajustada --- }
      if (owner>=1) and (owner<=11) then j := owner else j := 1;
      st.f.ShieldDamageScaling  := EMV(CombatCfg.ShieldDamageScaling, owner, 0, 32767);
      st.f.ShieldKillScaling    := EMV(CombatCfg.ShieldKillScaling,   owner, 0, 32767);
      st.f.HullDamageScaling    := EMV(CombatCfg.HullDamageScaling,   owner, 0, 32767);
      st.f.MaxFightersLaunched  := EMV(CombatCfg.MaxFightersLaunched, owner, 0, VCR_MAX_FTRS);
      st.f.StrikesPerFighter    := EMV(CombatCfg.StrikesPerFighter,   owner, 1, 100);
      st.f.BayLaunchInterval    := CombatCfg.BayLaunchInterval[j];
      st.f.FighterMovementSpeed := EMV(CombatCfg.FighterMovementSpeed, owner, 1, 10000);
      st.f.FighterBeamExplosive := EMV(CombatCfg.FighterBeamExplosive, owner, 1, 1000);
      st.f.FighterBeamKill      := EMV(CombatCfg.FighterBeamKill,      owner, 1, 1000);
      st.f.BeamHitFighterCharge := EMV(CombatCfg.BeamHitFighterCharge, owner, 1, 1000);
      st.f.FighterFiringRange   := CombatCfg.FighterFiringRange[j];
      st.f.BeamHitFighterRange  := CombatCfg.BeamHitFighterRange[j];
      st.f.BeamFiringRange      := CombatCfg.BeamFiringRange[j];
      st.f.BeamHitShipCharge    := CombatCfg.BeamHitShipCharge[j];
      st.f.TorpFiringRange      := CombatCfg.TorpFiringRange[j];
      st.f.ShipMovementSpeed    := CombatCfg.ShipMovementSpeed[j];
      st.f.CrewKillScaling      := DivRound( longint(100 - cCrewDefenseRate) *
                                    EMV(CombatCfg.CrewKillScaling, owner, 0, 32767), 100);
      { TorpFiringRange += 100*getFiringRangeBonus(): VPA no carga ese bonus
        (extension de PHost), asi que se asume 0. TODO si hiciera falta. }
    end;

  var left_odds, right_odds, left_f, right_f : longint;
begin
  gVis   := vis;
  m_done := false;
  m_time := 0;
  RngSeed(seed);
  m_alternativeCombat    := AllowAlternativeCombat;          { boolean de VPADATA }
  m_fireOnAttackFighters := CombatCfg.FireOnAttackFighters;
  m_standoffDistance     := CombatCfg.StandoffDistance;
  { TODO: checkBattle (validar combate) e initActivityDetector (bloque 6). }

  m_status[vsLeft ].f.side := vsLeft;
  m_status[vsRight].f.side := vsRight;
  m_status[vsLeft ].r.m_objectX := -29000;
  m_status[vsRight].r.m_objectX := +29000;
  PrepSide(m_status[vsLeft ], left);
  PrepSide(m_status[vsRight], right);

  { --- probabilidad de intercepcion de fighters (FighterKillOdds) --- }
  if (m_status[vsLeft ].r.obj.owner>=1) and (m_status[vsLeft ].r.obj.owner<=11)
    then left_odds  := CombatCfg.FighterKillOdds[m_status[vsLeft ].r.obj.owner]
    else left_odds  := CombatCfg.FighterKillOdds[1];
  if (m_status[vsRight].r.obj.owner>=1) and (m_status[vsRight].r.obj.owner<=11)
    then right_odds := CombatCfg.FighterKillOdds[m_status[vsRight].r.obj.owner]
    else right_odds := CombatCfg.FighterKillOdds[1];
  if m_phost3Flag then begin
    left_f  := (100 - left_odds)  * right_odds;
    right_f := (100 - right_odds) * left_odds;
    m_interceptProbability := (left_f + right_f) div 100;
    if m_interceptProbability = 0 then m_rightProbability := 50
                                  else m_rightProbability := left_f div m_interceptProbability;
  end else begin
    m_interceptProbability := CombatCfg.FighterKillOdds[1];
    m_rightProbability     := 50;
  end;
end;

{ ---------------------------------------------------------------------------
  Recarga (bloque 2). Cada tick, lo que no esta a tope (<1000) gana
  RandomRange(rate). RandomRange asume rate <= 65535 (igual que PHost: con un
  rate mayor su RNG se rompe, asi que los juegos validos no llegan ahi). El
  ORDEN de las llamadas al RNG (izq/der, beam/torp/bay) lo fija playCycle
  (bloque 6) y es lo que mantiene la bit-exactitud.
  --------------------------------------------------------------------------- }
procedure BeamRecharge (var st : TSideStatus);
  var i, mx : int;
begin
  mx := st.r.obj.numBeams;
  for i := 0 to mx-1 do
    if st.r.m_beamStatus[i] < 1000 then
    begin
      st.r.m_beamStatus[i] := st.r.m_beamStatus[i] + longint(RandomRange(st.f.beam_recharge));
      if Assigned(gVis.updateBeam) then gVis.updateBeam(st.f.side, i);
    end;
end;

procedure TorpsRecharge (var st : TSideStatus);
  var i, mx : int;
begin
  mx := st.r.obj.numLaunchers;
  for i := 0 to mx-1 do
    if st.r.m_launcherStatus[i] < 1000 then
    begin
      st.r.m_launcherStatus[i] := st.r.m_launcherStatus[i] + longint(RandomRange(st.f.torp_recharge));
      if Assigned(gVis.updateLauncher) then gVis.updateLauncher(st.f.side, i);
    end;
end;

procedure FighterRecharge (var st : TSideStatus);
  var i, mx : int;
begin
  mx := st.r.obj.numBays;
  for i := 0 to mx-1 do
    if st.r.m_bayStatus[i] < 1000 then
      st.r.m_bayStatus[i] := st.r.m_bayStatus[i] + longint(RandomRange(st.f.bay_recharge));
end;

{ ---------------------------------------------------------------------------
  Beams y modelo de dano (bloque 3). Compute*S y Hit aplican el dano al escudo,
  casco y tripulacion (valores escalados, PVCR_INTEGER). beamFire dispara como
  mucho un beam por llamada. CRITICO para bit-exactitud: el 'missing' del path
  de fighter consume RNG aunque luego no haya fighter al que disparar.
  --------------------------------------------------------------------------- }

function MinL (a, b : longint) : longint;
begin if a < b then MinL := a else MinL := b; end;

function ComputeShieldDamageS (expl, kill : int; var st : TSideStatus) : longint;
begin
  if m_alternativeCombat then
    ComputeShieldDamageS := MinL( longint(st.f.ShieldDamageScaling)*expl
                                + longint(st.f.ShieldKillScaling)*kill, st.f.max_scaled )
  else
    ComputeShieldDamageS := MinL( DivRound( longint(st.f.ShieldDamageScaling)*expl
                                + longint(st.f.ShieldKillScaling)*kill, st.f.mass_plus1 ) + 1, 10000 );
end;

function ComputeHullDamageS (expl, kill : int; var st : TSideStatus) : longint;
begin
  if m_alternativeCombat then
    ComputeHullDamageS := MinL( longint(expl) * st.f.HullDamageScaling, st.f.max_scaled )
  else
    ComputeHullDamageS := MinL( DivRound( ComputeShieldDamageS(expl,kill,st) * st.f.HullDamageScaling,
                                st.f.mass_plus1 ) + 1, 10000 );
end;

function ComputeCrewKilledS (kill : int; death : boolean; var st : TSideStatus) : longint;
  var rv : longint;
begin
  if m_alternativeCombat then
    ComputeCrewKilledS := longint(st.f.CrewKillScaling) * kill
  else begin
    rv := DivRound( longint(st.f.CrewKillScaling) * kill, st.f.mass_plus1 );
    if death and (rv = 0) then rv := 1;
    ComputeCrewKilledS := rv;
  end;
end;

{ Aplica un impacto. Devuelve True si el objetivo queda destruido. }
function Hit (var st : TSideStatus; kill, expl : int; is_death_ray : boolean) : boolean;
  var damage_rate, damage_s, killed_s : longint;
begin
  Hit := false;
  if kill <= 0 then kill := 1;
  if expl <= 0 then expl := 1;
  if (m_capabilities and cDeathRayCapability) = 0 then is_death_ray := false;
  damage_rate := 100;
  if not is_death_ray then
  begin
    { golpear escudos }
    if st.r.shield_scaled > 0 then
    begin
      damage_s := ComputeShieldDamageS(expl, kill, st);
      if st.r.shield_scaled < damage_s then
      begin
        damage_rate := (damage_s - st.r.shield_scaled) * 100 div damage_s;
        st.r.shield_scaled := 0;
      end
      else begin
        damage_rate := 0;
        st.r.shield_scaled := st.r.shield_scaled - damage_s;
      end;
      if damage_rate <= 0 then exit;
    end;
    { escudos a cero -> dano al casco }
    st.r.damage_scaled2 := st.r.damage_scaled2 + ComputeHullDamageS(expl, kill, st) * damage_rate;
    if st.r.damage_scaled2 >= st.f.damage_limit_scaled then begin Hit := true; exit; end;
  end;
  if not st.r.obj.isPlanet then
  begin
    killed_s := ComputeCrewKilledS(kill, is_death_ray, st) * damage_rate;
    st.r.crew_scaled2 := st.r.crew_scaled2 - killed_s;
    if st.r.crew_scaled2 < 50*st.f.scale then
    begin
      st.r.crew_scaled2 := 0;
      Hit := true;
    end;
  end;
end;

function GetDistance : longint;
begin GetDistance := m_status[vsRight].r.m_objectX - m_status[vsLeft].r.m_objectX; end;

{ Indice del fighter enemigo mas cercano dentro de BeamHitFighterRange, o -1. }
function BeamFindNearestFighter (var st, opp : TSideStatus) : int;
  var fighter, retreatingFighter, i, limit, fs : int;
      mindist, my_x, d : longint;
      foaf, hasAttackingFighter : boolean;
begin
  fighter := -1;
  if opp.r.m_activeFighters <> 0 then
  begin
    mindist := st.f.BeamHitFighterRange + 1;
    my_x := st.r.m_objectX;
    foaf := m_fireOnAttackFighters;
    retreatingFighter := -1;
    hasAttackingFighter := false;
    limit := opp.f.MaxFightersLaunched;
    for i := 0 to limit-1 do
    begin
      fs := opp.r.m_fighterStatus[i];
      if fs <> FighterIdle then
      begin
        if fs = FighterAttacks then hasAttackingFighter := true;
        if (fs = FighterAttacks) or (not foaf) then
        begin
          d := Abs(my_x - opp.r.m_fighterX[i]);
          if d < mindist then begin mindist := d; fighter := i; end;
        end;
        if (fs <> FighterAttacks) and (retreatingFighter < 0) and foaf then
          retreatingFighter := i;
      end;
    end;
    if foaf and (not hasAttackingFighter) then fighter := retreatingFighter;
  end;
  BeamFindNearestFighter := fighter;
end;

{ Dispara los beams de un lado. Devuelve True si el combate termina. }
function BeamFire (var st, opp : TSideStatus) : boolean;
  var beam, beam_mx, fighter, kill, dest : int;
      missing, hitr : boolean;
begin
  BeamFire := false;
  beam_mx := st.r.obj.numBeams;
  for beam := 0 to beam_mx-1 do
  begin
    { fuego a un fighter }
    if st.r.m_beamStatus[beam] >= st.f.BeamHitFighterCharge then
    begin
      missing := not RandomRange100LT(st.f.beam_hit_odds);  { RNG: consumido aunque no haya fighter }
      fighter := BeamFindNearestFighter(st, opp);
      if fighter >= 0 then
      begin
        st.r.m_beamStatus[beam] := 0;
        if Assigned(gVis.updateBeam) then gVis.updateBeam(st.f.side, beam);
        if Assigned(gVis.fireBeam) then
          if missing then gVis.fireBeam(st.f.side, -1-beam, fighter, -1, st.f.beam_damage, st.f.beam_kill)
                     else gVis.fireBeam(st.f.side, -1-beam, fighter, +1, st.f.beam_damage, st.f.beam_kill);
        if not missing then
        begin
          if Assigned(gVis.killFighter) then gVis.killFighter(opp.f.side, fighter);
          opp.r.m_fighterStatus[fighter] := FighterIdle;
          Dec(opp.r.m_activeFighters);
        end;
        exit;   { BeamFire = false }
      end;
    end;
    { fuego a la nave enemiga }
    if ( (opp.r.m_activeFighters <= 0) or ((m_capabilities and cBeamCapability) <> 0) )
       and (st.r.m_beamStatus[beam] >= st.f.BeamHitShipCharge)
       and (GetDistance <= st.f.BeamFiringRange) then
    begin
      missing := not RandomRange100LT(st.f.beam_hit_odds);
      kill := (longint(st.f.beam_kill)   * (st.r.m_beamStatus[beam] div 10) div 100) * cBeamKillRate;
      dest := (longint(st.f.beam_damage) * (st.r.m_beamStatus[beam] div 10) div 100);
      st.r.m_beamStatus[beam] := 0;
      if Assigned(gVis.updateBeam) then gVis.updateBeam(st.f.side, beam);
      if not missing then
      begin
        hitr := Hit(opp, kill, dest, st.f.beam_damage = 0);
        if Assigned(gVis.fireBeam) then gVis.fireBeam(st.f.side, -1-beam, -1, 1, dest, kill);
        if hitr then begin BeamFire := true; exit; end;
      end
      else
        if Assigned(gVis.fireBeam) then gVis.fireBeam(st.f.side, -1-beam, -1, -1, dest, kill);
      exit;   { BeamFire = false }
    end;
  end;
end;

{ ---------------------------------------------------------------------------
  Torpedos (bloque 4). Dispara como mucho un torpedo por llamada desde el primer
  tubo cargado (status>=1000): gasta un torpedo, consume RNG (RandomRange100) y,
  si rr <= torp_hit_odds, aplica Hit. torp_kill/torp_damage ya llevan el x2 de
  no-AC aplicado en InitBattle. Devuelve True si el combate termina.
  --------------------------------------------------------------------------- }
function TorpsFire (var st, opp : TSideStatus) : boolean;
  var launcher, limit, rr, kill, damage : int;
begin
  TorpsFire := false;
  if (GetDistance > st.f.TorpFiringRange) or (st.r.obj.numTorps = 0) then exit;
  limit := st.r.obj.numLaunchers;
  for launcher := 0 to limit-1 do
    if st.r.m_launcherStatus[launcher] >= 1000 then
    begin
      rr := RandomRange100;
      Dec(st.r.obj.numTorps);
      st.r.m_launcherStatus[launcher] := 0;
      if Assigned(gVis.updateLauncher) then gVis.updateLauncher(st.f.side, launcher);
      if rr <= st.f.torp_hit_odds then
      begin
        kill   := st.f.torp_kill;
        damage := st.f.torp_damage;
        TorpsFire := Hit(opp, kill, damage, damage = 0);
        if Assigned(gVis.fireTorpedo) then gVis.fireTorpedo(st.f.side, rr, launcher);
        exit;
      end
      else begin
        if Assigned(gVis.fireTorpedo) then gVis.fireTorpedo(st.f.side, -1-rr, launcher);
        exit;
      end;
    end;
end;

function PlayCycle : boolean;
begin
  { STUB: la matematica del turno (recarga, disparo, fighters, hits, fin) se
    porta en los bloques 2-6 de la Fase B. }
  PlayCycle := False;
end;

procedure PlayFastForward;
begin
  { STUB: bloque 6. }
end;

{ --------------------------------------------------------------------------- }
procedure DoneBattle (var left, right: TVcrObject);

  procedure Back (var st:TSideStatus; var o:TVcrObject);
  begin
    o := st.r.obj;
    if m_alternativeCombat then begin
      o.damage := DivRound(st.r.damage_scaled2, st.f.scale * 100);
      o.crew   := DivRound(st.r.crew_scaled2,   st.f.scale * 100);
      o.shield := DivRound(st.r.shield_scaled,  st.f.scale);
    end else begin
      o.damage := DivRound(st.r.damage_scaled2, 100);
      o.crew   := DivRound(st.r.crew_scaled2,   100);
      o.shield := st.r.shield_scaled;          { scale = 1 }
    end;
    if o.damage > 100 then o.damage := 100;
    { TODO (bloque 6): fijar resultado ganador/perdedor (canStillFight). }
  end;

begin
  Back(m_status[vsLeft ], left);
  Back(m_status[vsRight], right);
end;

{ --- Consulta de estado en curso (modelo entero: des-escala los valores). --- }
function GetShield      (side:TVcrSide): int;
begin GetShield := DivRound(m_status[side].r.shield_scaled, m_status[side].f.scale); end;

function GetDamage      (side:TVcrSide): int;
begin GetDamage := DivRound(m_status[side].r.damage_scaled2, m_status[side].f.scale * 100); end;

function GetCrew        (side:TVcrSide): int;
begin GetCrew := DivRound(m_status[side].r.crew_scaled2, m_status[side].f.scale * 100); end;

function GetNumTorps    (side:TVcrSide): int;
begin GetNumTorps := m_status[side].r.obj.numTorps; end;

function GetNumFighters (side:TVcrSide): int;
begin GetNumFighters := m_status[side].r.obj.numFighters; end;

function GetObjectX     (side:TVcrSide): int;
begin GetObjectX := m_status[side].r.m_objectX; end;

end.
