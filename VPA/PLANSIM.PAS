  {
*******************************************************************
* PLANSIM - Simulation of planet economy (F6)
*
* $Id: plansim.pas,v 1.19 2013/05/26 09:17:14 sfplanets Exp $
*
*
*******************************************************************
}

{$I switches.inc}
Unit    Plansim;  (* Simulation of planet economy  *)
{$V-}

interface

uses VPAData,vpa4,vpa2;

procedure PlanSimDo;

 type

  MyPlanetPtr    = ^MyPlanet;
  MyPlanet = RECORD
  
   OWNER :double;
    CLANS ,CHAPPY :double;
    NATCLANS ,NHAPPY :double;
    CTAX ,NTAX :double;
    SUP ,MC :double;
    DP ,M ,F :double;
    NEU ,TRI ,DUR ,MOL :double;
    NEUDEN ,TRIDEN ,DURDEN ,MOLDEN :double;
    NEUCORE ,TRICORE ,DURCORE ,MOLCORE :double;
    NATTYPE ,NATGOV :double;
    TEMP ,TURN :double;
    TAKECLANS :double;
    AAA ,AF ,AM ,ADP :double;
    SS ,MCS ,TSS ,TMCS :double ;
    CTL ,NTL ,NTTURN :double;
    NOPILL, PILLSUP, PILLMC, NORGA, HISS :double;   {Quapla}    
end; 

implementation

uses
      StrF,AuxF,ptcgraph,Screen,Mouse,Keyboard;

var
cfg_ClimateLimitsPopulation: integer;
cfg_NativeClimateDeathRate: integer;
cfg_CrystalSinTempBehavior: integer;
cfg_CrystalsLikeDesert: integer;
cfg_MaxColTempSlope: integer;
cfg_AllowEatingSupplies: integer;
cfg_ClimateDeathRate: integer;
cfg_AssimRate: integer;
cfg_StructureDecayPerTurn: integer;
cfg_MaxPlanetaryIncome: integer;
cfg_HissEffectRate: integer;
TerraForm:integer;
TerraFormLimit:integer;
TerraFormStep:integer;
RaceGrowth:integer;
RaceMine :integer;
RaceProduction:integer;
CTaxRate      :integer;
NTaxRate      :integer;



function myRND (in_ :double ):double;
begin
myRND:= trunc (in_ +0.5);
end;

function max (a,b :double ):double;
begin
 if a>b then max:=a
 else max:=b;
end;
function min (a,b :double ):double;
begin
 if a<b then min:=a
 else min:=b;
end;

function maxL (a,b :long ):long;
begin
 if a>b then maxL:=a
 else maxL:=b;
end;
function minL (a,b :long ):long;
begin
 if a<b then minL:=a
 else minL:=b;
end;

function MaxMonPlanet ( var  in_:MyPlanet ):double;
 begin
if (in_.CLANS <200)then MaxMonPlanet:=in_.CLANS
else  MaxMonPlanet:=myRND (200+SQRT (in_.CLANS -200));
end;

function MaxFonPlanet (var in_:  MyPlanet  ):double;
 begin
if (in_.CLANS <100) then MaxFonPlanet:=in_.CLANS
else MaxFonPlanet:= myRND (100+SQRT (in_.CLANS -100));
end;

function MaxDPonPlanet (   var in_ :MyPlanet):double;
 begin
if (in_.CLANS <50) then MaxDPonPlanet:=in_.CLANS
else MaxDPonPlanet:= myRND (50+SQRT (in_.CLANS -50));
end;

procedure MineMinerals (  var out_ :MyPlanet;   in_ :MyPlanet;  RACE_MINING_RATE: double);
  var
 MINING_RATE :double;
begin
out_:= in_ ;

MINING_RATE := (RACE_MINING_RATE *in_.NEUDEN )/100.0;
if (in_.NATTYPE  =  3) then MINING_RATE := MINING_RATE*2;
MINING_RATE := (MINING_RATE * in_.M / 100.0);
if (MINING_RATE > out_.NEUCORE) then MINING_RATE := out_.NEUCORE;
out_.NEU := out_.NEU + ROUND (MINING_RATE);
out_.NEUCORE := max(out_.NEUCORE-MINING_RATE,0);

MINING_RATE := (RACE_MINING_RATE *in_.TRIDEN )/100.0;
if (in_.NATTYPE  =  3) then MINING_RATE := MINING_RATE*2;
MINING_RATE := (MINING_RATE * in_.M / 100.0);
if (MINING_RATE > out_.TRICORE) then MINING_RATE := out_.TRICORE;
out_.TRI := out_.TRI + ROUND (MINING_RATE);
out_.TRICORE := max(out_.TRICORE-MINING_RATE,0);

MINING_RATE := (RACE_MINING_RATE *in_.DURDEN )/100.0;
if (in_.NATTYPE  =  3) then MINING_RATE := MINING_RATE*2;
MINING_RATE := (MINING_RATE * in_.M / 100.0);
if (MINING_RATE > out_.DURCORE) then MINING_RATE := out_.DURCORE;
out_.DUR := out_.DUR + ROUND (MINING_RATE);
out_.DURCORE := max(out_.DURCORE-MINING_RATE,0);

MINING_RATE := (RACE_MINING_RATE *in_.MOLDEN )/100.0;
if (in_.NATTYPE  =  3) then MINING_RATE := MINING_RATE*2;
MINING_RATE := (MINING_RATE * in_.M / 100.0);
if (MINING_RATE > out_.MOLCORE) then MINING_RATE := out_.MOLCORE;
out_.MOL := out_.MOL + ROUND (MINING_RATE);
out_.MOLCORE := max(out_.MOLCORE-MINING_RATE,0);

end;

procedure SuppliesProduction (  var out_:MyPlanet  ;  in_ :MyPlanet ;  RACE_PRODUCTION_RATE :double);
  var
 COLONIST_SUPPLIES ,BOVINOID_SUPPLIES :double;
begin
out_:= in_;

COLONIST_SUPPLIES := in_.F ;

BOVINOID_SUPPLIES := 0;
if (in_.NATTYPE  =  2) then BOVINOID_SUPPLIES := MIN (in_.NATCLANS / 100.0,in_.CLANS );

out_.SUP := out_.SUP+TRUNC ((COLONIST_SUPPLIES +BOVINOID_SUPPLIES )*RACE_PRODUCTION_RATE / 100.0);
end;

procedure PILL (  var out_:MyPlanet  ;  in_ :MyPlanet);
begin
  out_.MC := out_.MC+trunc ((out_.NATCLANS+out_.CLANS)/100);
  out_.SUP := out_.SUP+trunc ((out_.NATCLANS+out_.CLANS)/100);
    
  out_.NATCLANS := out_.NATCLANS - trunc ((out_.NATCLANS*0.2)+121);
  out_.CLANS := out_.CLANS - trunc ((out_.CLANS*0.2)+20);
  
  if out_.NATCLANS < 0 then begin
    out_.NATCLANS := 0;
    out_.NATTYPE := 0;
  end;
  if out_.CLANS < 0 then out_.CLANS := 0;
  
  out_.CHAPPY := out_.CHAPPY-10;
  out_.NHAPPY := out_.NHAPPY-10;
  
  out_.PILLMC := out_.MC;
  out_.MC := 0;
  out_.PILLSUP := out_.SUP;
  out_.SUP := 0;

end;

function ClansIncome (in_:  MyPlanet ; RACE_TAX_RATE :double):double;
  var
 MC :double;
begin
if (in_.CHAPPY <30) then MC := 0;
if (in_.CHAPPY >= 30) then
MC := TRUNC ((in_.CLANS *in_.CTAX *5+2500.0)/5000.0);

ClansIncome:= TRUNC ((MC *RACE_TAX_RATE +50.0)/100.0);
end;

function NativesIncome ( in_: MyPlanet ; RACE_TAX_RATE :double):double;
 var
 MC :double;
 begin
if trunc(in_.NATTYPE)<=0 then begin NativesIncome:=0; exit; end;
if ((in_.NHAPPY <30)OR  (in_.NATTYPE  =  5)) then MC := 0
else
   begin
  MC := MIN (TRUNC ((in_.NATCLANS *in_.NATGOV *in_.NTAX +2500.0)/5000.0),in_.CLANS );
  if (in_.NATTYPE  =  6) then MC :=MC* 2;
end;
NativesIncome:= TRUNC ((MC *RACE_TAX_RATE +50.0)/100.0);
end;

function MaxNATonPlanet (   var in_ : MyPlanet):double;
begin
if (cfg_ClimateLimitsPopulation=1 ) then
MaxNATonPlanet := myRND (sin (in_.TEMP *3.14159/100.0)*15600000.0)
else
MaxNATonPlanet := 15600000;
end;

function NATgrowth (  var in_: MyPlanet):double;
 var
 MaxNAT :double;
 NAT_GROWTH_RATE :double;
 NATgrowth_ :double;
begin
        if trunc(in_.NATTYPE)<=0 then begin NATgrowth:=0; exit; end;
MaxNAT := MaxNATonPlanet (in_ );

if (in_.NHAPPY <70) then
NAT_GROWTH_RATE := 0
else
NAT_GROWTH_RATE := 4*sin (in_.TEMP *3.14159/100)/(1+in_.NTAX / 5);

NATgrowth_ := (NAT_GROWTH_RATE *in_.NATCLANS *100+50)/100;
if (NATgrowth_ +in_.NATCLANS *100>MaxNAT ) then
NATgrowth_ := MaxNAT -in_.NATCLANS *100;

if (NATgrowth_ >0) then NATgrowth :=NATgrowth_
else NATgrowth:= 0.0;
end;

function NATclimatedeaths (   var in_: MyPlanet):double;
 var
 MaxNAT: double;
 NATclimatedeaths_: double;
begin
if trunc(in_.NATTYPE)<=0 then begin NATclimatedeaths:=0; exit; end;
MaxNAT := MaxNATonPlanet (in_ );

if (in_.NATCLANS *100>25000000) then
NATclimatedeaths_ := (25000000-in_.NATCLANS *100)
else
   begin
  if (NOT cfg_ClimateLimitsPopulation=1 ) then NATclimatedeaths_ := 0
  else
     begin
    if (in_.NATCLANS *100<MaxNAT ) then NATclimatedeaths_ := 0
    else
       begin
         NATclimatedeaths_ := TRUNC ((in_.NATCLANS *100*  cfg_NativeClimateDeathRate )/100);
         if (in_.NATCLANS *100-NATclimatedeaths_ <MaxNAT ) then   NATclimatedeaths_ := in_.NATCLANS *100-MaxNAT ;
      end;
    end;
end;

if (NATclimatedeaths_ >0)
then NATclimatedeaths := NATclimatedeaths_
else NATclimatedeaths := 0.0;
end;

function BaseMaxCOLonPlanet ( var  in_ :MyPlanet):double;
  var BaseMaxCOLonPlanet_ :double; tmp:double;
begin
  tmp:=100-in_.TEMP;
  if ((cfg_CrystalsLikeDesert=1 )AND  (in_.OWNER  = 7)) then begin
    if (phost and (cfg_CrystalSinTempBehavior=1)) then begin
      if (tmp>84) then
        BaseMaxCOLonPlanet_ := 300+cfg_MaxColTempSlope *in_.TEMP
      else
        BaseMaxCOLonPlanet_ := MAX (10000000*sin (in_.TEMP *3.14159/200),100);
    end else
      BaseMaxCOLonPlanet_ := MAX (100000*in_.TEMP ,100);
  end  else     begin
    if ((in_.OWNER = 10) AND (tmp<20)) then BaseMaxCOLonPlanet_ := 9000000;
    if (tmp>84) then begin
      if phost then BaseMaxCOLonPlanet_ := 300+cfg_MaxColTempSlope *in_.TEMP
               else  BaseMaxCOLonPlanet_ := trunc((20099.9-200.0*(100-in_.temp))/cfg_ClimateDeathRate)*100.0;
      end;
    if (tmp<15) then begin
      if phost then BaseMaxCOLonPlanet_ := 100+(100-in_.TEMP )*cfg_MaxColTempSlope 
               else BaseMaxCOLonPlanet_ := trunc((299.9+200*(100-in_.temp))/cfg_ClimateDeathRate)*100.0;
      end;
    if ((tmp >= 15)AND  (tmp <= 84)) then begin
      if phost then BaseMaxCOLonPlanet_ := sin (in_.TEMP *3.14159/100.0)*10000000.0
               else BaseMaxCOLonPlanet_ := (sin((100-in_.temp)*3.14/100.0)*100000.0)*100.0;
      end;
    if (tmp>80) then
    if ((in_.OWNER  = 4) OR  (in_.OWNER  =  9) OR (in_.OWNER  = 10)OR (in_.OWNER  =  11)) then
      BaseMaxCOLonPlanet_ := MAX (BaseMaxCOLonPlanet_ ,6000);
  end;
  {!   if (maxc<100/ClimateDeathRate-1) then maxc:=Trunc(99/ClimateDeathRate-1); Do not undertand this}
  BaseMaxCOLonPlanet:= myRND (BaseMaxCOLonPlanet_ );  
end;

function MaxCOLonPlanet (   in_ :MyPlanet):double;
  var
 MaxCOLSupplyBonus :double;
 BaseMaxCOLonPlanet_ :double;
begin
if (cfg_AllowEatingSupplies=1 ) then
MaxCOLSupplyBonus := TRUNC (100*in_.SUP / 40)
else
MaxCOLSupplyBonus := 0;

BaseMaxCOLonPlanet_ := BaseMaxCOLonPlanet (in_ );

if (cfg_ClimateLimitsPopulation =1) then
MaxCOLonPlanet:= MaxCOLSupplyBonus +BaseMaxCOLonPlanet_
else
MaxCOLonPlanet:= 25000000;
end;

function COLgrowth (   in_: MyPlanet; RACE_GROWTH_RATE :double):double;
var
 MaxCOL :double;
 COL_GROWTH_RATE :double;
 COLgrowth_ :double;
begin
MaxCOL := MaxCOLonPlanet (in_ );

if ((in_.CHAPPY <70)OR  (in_.CLANS *100>= MaxCOL )) then
COL_GROWTH_RATE := 0
else
   begin
  if ((cfg_CrystalsLikeDesert=1 )AND (in_.OWNER  = 7)) then
     begin
    if (cfg_CrystalSinTempBehavior=1 ) then
       begin
      if (in_.TEMP <15) then
      COL_GROWTH_RATE := 0
      else
      COL_GROWTH_RATE := 5*sin (in_.TEMP *3.14159/200)/(1+in_.CTAX /5 );
    end
    else
    COL_GROWTH_RATE := 5*(in_.TEMP / 100)/(1+in_.CTAX /5 );
  end
  else
     begin
    if ((in_.TEMP <15)OR (in_.TEMP >84)) then COL_GROWTH_RATE := 0
    else
    COL_GROWTH_RATE := 5*sin (in_.TEMP *3.14159/100)/(1+in_.CTAX / 5);
  end;
end;
COLgrowth_ := myRND (COL_GROWTH_RATE *in_.CLANS *100/10000)*RACE_GROWTH_RATE ;
if (COLgrowth_ +in_.CLANS *100>MaxCOL ) then
COLgrowth_ := MaxCOL -in_.CLANS *100;

if (COLgrowth_ >0) then COLgrowth:=COLgrowth_
else COLgrowth:= 0.0;
end;

function COLclimatedeaths (   in_ :MyPlanet):double;
var
 COLclimatedeaths_ :double;
 MaxCOL :double;

begin

MaxCOL := MaxCOLonPlanet (in_ );

if (in_.CLANS *100>25000000) then
COLclimatedeaths_ := (in_.CLANS *100-25000000)
else
   begin
  if (NOT cfg_ClimateLimitsPopulation=1 ) then
  COLclimatedeaths_ := 0
  else
     begin
    if (in_.CLANS *100<= MaxCOL ) then
    COLclimatedeaths_ := 0
    else
    COLclimatedeaths_ := TRUNC (in_.CLANS *100*cfg_ClimateDeathRate / 100);
  end;
end;

if (in_.CLANS *100-COLclimatedeaths_ <MaxCOL ) then
COLclimatedeaths_ := in_.CLANS *100-MaxCOL ;
if (COLclimatedeaths_ <100) then
COLclimatedeaths_ := 0;

COLclimatedeaths:= COLclimatedeaths_ ;
end;

function CHappyChange (var   in_: MyPlanet):double;
  var
 TargetTemp ,TempDivisor ,CHAPPY :double;
begin

if ((in_ .OWNER  = 7) AND (cfg_CrystalsLikeDesert=1 )) then
   begin
  TargetTemp := 100;
  TempDivisor := 66;
end
else
   begin
  TargetTemp := 50;
  TempDivisor := 33;
end;

CHAPPY := 10-SQRT (in_.CLANS / 10000.0)
-ABS (in_.TEMP -TargetTemp )/TempDivisor
-(in_.M +in_.F )/300
-in_.CTAX *0.8;

CHappyChange:= CHAPPY ;
end;

function NHappyChange (var in_ :MyPlanet):double;
var
 TargetTemp ,TempDivisor ,NHAPPY :double;

begin
if trunc(in_.NATTYPE)<=0 then begin NHappyChange:=0; exit; end;
if ((in_.OWNER  =  7)AND (cfg_CrystalsLikeDesert=1 )) then
   begin
  TargetTemp := 100;
  TempDivisor := 66;
end
else
   begin
  TargetTemp := 50;
  TempDivisor := 33;
end;

NHAPPY := 5.0 + in_.NATGOV/2.0 - SQRT (in_.NATCLANS / 10000.0)
-(in_.M +in_.F )/200.0
-in_.NTAX *0.85;
if (in_.NATTYPE  =  4) then NHAPPY := NHAPPY + 10;
NHappyChange:= NHAPPY;
end;

procedure NativesAssimilation (   var out_ ,  in_ :MyPlanet);
var
 assim: double;
begin
if (trunc(in_.NATTYPE)<=0) or (round(in_.NATTYPE) = 5)  then begin exit; end;
out_ :=in_ ;
assim := MIN (in_.CLANS *100*cfg_AssimRate / 100,in_.NATCLANS *100);

out_.NATCLANS := out_.NATCLANS-TRUNC (assim / 100);
out_.CLANS :=out_.CLANS +TRUNC (assim / 100);
end;

function COLdeathsAmorphous ( var  in_: MyPlanet):double ;
 begin
if (in_.NATTYPE  = 5) then
   begin
  if (in_.NHAPPY >= 70) then COLdeathsAmorphous:= 500
  else
  if (in_.NHAPPY >= 50) then COLdeathsAmorphous:= 2000
  else COLdeathsAmorphous:= 4000;
end
else
COLdeathsAmorphous:= 0.0;
end;

function COLdeathsfighting (   var in_ :MyPlanet):double;
  var
 death :double;
begin
death := 0;
if (in_.CHAPPY <20) then
begin
  death := death+in_.CLANS *100*(40-in_.CHAPPY )/500;
  COLdeathsfighting:= death ;
end
else
begin
if ((in_.NHAPPY <20)AND  (in_.NATCLANS >0)) then
death := death+in_.CLANS *100*(40-in_.NHAPPY )/2500;
COLdeathsfighting:= death ;
end;
end;

function NATdeathsfighting (    var in_ :MyPlanet):double;
  var
 death: double;
begin
if trunc(in_.NATTYPE)<=0 then begin NATdeathsfighting:=0; exit; end;
death := 0;
if (in_.NHAPPY <20) then
begin
  death :=death+ in_.NATCLANS *100*(40-in_.NHAPPY )/500;
  NATdeathsfighting:= death ;
end
else
begin
if ((in_.CHAPPY <20)AND  (in_.CLANS >0)) then
death :=death+ in_.NATCLANS *100*(40-in_.CHAPPY )/2500;

NATdeathsfighting:= death ;
end;
end;

function OverpopulationSupplLoss (   in_: MyPlanet):double;
  var
 BaseMaxCOLonPlanet_: double;
 OSL :double;
begin
BaseMaxCOLonPlanet_ := BaseMaxCOLonPlanet (in_ );

if (NOT cfg_ClimateLimitsPopulation=1 ) then OSL := 0
else
   begin
  if (in_.CLANS *100<= BaseMaxCOLonPlanet_ ) then OSL := 0
  else
  OSL := MIN (TRUNC ((in_.CLANS *100-BaseMaxCOLonPlanet_ )/4000)+1,in_.SUP );
end;
OverpopulationSupplLoss:= OSL ;
end;

procedure DoNextTurn (   var Next :MyPlanet; var  Now :MyPlanet);
  var
 temp1 ,temp2 ,hiss_ :double;
begin
  
(*
  ReCalcDecay (@next,@now);  ReCalcPlanet (@next,@now); Try to Implement that one... 
  or this one
  CalcMaxPop(plan:pptr;var colo,ming,maxc,grow,maxnat,grownat,GAmin,GAmax, GA,GARem:long); *)
  
  Next := Now;

{Hiss }
  next.CHAPPY := next.CHAPPY + (next.HISS*cfg_HissEffectRate);
  next.NHAPPY := next.NHAPPY + (next.HISS*cfg_HissEffectRate);
  next.CHAPPY := MIN (next.CHAPPY ,100);
  next.NHAPPY := MIN (next.NHAPPY ,100);

{ Terra Form }
  if (TerraForm =1) then
  if (next.TEMP <> TerraFormLimit ) then
     begin
    if (next.TEMP <TerraFormLimit ) then
       begin
      next.TEMP := next.TEMP+TerraFormStep ;
      if (next.TEMP >TerraFormLimit )then next.TEMP := TerraFormLimit ;
    end;
    if (next.TEMP >TerraFormLimit ) then
       begin
      next.TEMP := next.TEMP- TerraFormStep ;
      if (next.TEMP <TerraFormLimit )then next.TEMP := TerraFormLimit ;
    end;
  end;

{Structure Decay}
  if (((next.NHAPPY <40)AND(next.NATTYPE>0) )OR  (next.CHAPPY <40))then
     begin
    next.M := MAX (next.M -10,0);
    next.F := MAX (next.F -10,0);
  end;

{Pillage by Quapla 2013 }
  if (now.NOPILL=0) then PILL (Next, Now); 

{ RGA }
  if (now.NORGA=0) then begin
    next.MC := trunc (0.7 * next.MC);
    next.SUP := trunc (0.6 * next.SUP);
    next.CLANS := trunc (0.8 * next.CLANS);
    next.M := trunc (0.4 * next.M);
    next.F := trunc (0.7 * next.F);
    next.DP := trunc (0.8 * next.DP);
    next.CHAPPY := next.CHAPPY - 60;
    next.NHAPPY := MIN (next.NHAPPY+30 ,100);
  end;

{Production }
  MineMinerals (Next ,Next ,RaceMine );
  SuppliesProduction (Next ,Next ,RaceProduction );

{Planetary happy change }
  next.CHAPPY := next.CHAPPY+TRUNC (CHappyChange (Next ));
  next.NHAPPY := next.NHAPPY+TRUNC (NHappyChange (Next ));

  next.CHAPPY := MIN (next.CHAPPY ,100);
  next.NHAPPY := MIN (next.NHAPPY ,100);

{Planetary tax }
  next.MC := next.MC+MIN (ClansIncome (Next ,CTaxRate )+NativesIncome (Next ,NTaxRate ),cfg_MaxPlanetaryIncome );

{Col i Nat growth }
  next.CLANS    := next.CLANS   +TRUNC (COLgrowth (Next ,RaceGrowth )/100);
  next.NATCLANS := next.NATCLANS+TRUNC (NATgrowth (Next )/100);

{COL i Nat loss }
  temp1 := COLclimatedeaths (Next );
  temp2 := NATclimatedeaths (Next );

  if (cfg_AllowEatingSupplies=1 )then next.SUP := max(0,next.SUP-OverpopulationSupplLoss (Next ));

{clear tax if < 30}
  if (next.NHAPPY <30) and (next.NTAX<>0) then  next.NTAX:=0;
  if (next.CHAPPY <30) and (next.CTAX<>0) then  next.CTAX:=0;

  if (next.M >MaxMonPlanet (Next ))then
    next.M := next.M-MIN (next.M -MaxMonPlanet (Next ),cfg_StructureDecayPerTurn );

  if (next.F >MaxFonPlanet (Next )) then
    next.F := next.F-MIN (next.F -MaxFonPlanet (Next ),cfg_StructureDecayPerTurn );

  if (next.DP >MaxDPonPlanet (Next ))then
    next.DP := next.DP-MIN (next.DP -MaxDPonPlanet (Next ),cfg_StructureDecayPerTurn );

  temp1 := temp1+COLdeathsfighting (Next );
  temp2 := temp2+NATdeathsfighting (Next );

  temp1 := temp1+COLdeathsAmorphous (Next );

  next.CLANS    := max(0.0,next.CLANS-TRUNC (temp1 / 100.0));
  next.NATCLANS := max(0.0,next.NATCLANS-TRUNC (temp2 / 100.0));

{Assimilation by BORG}
  if (next.OWNER  = 6) then
    NativesAssimilation (Next ,Next );
  
next.TURN := next.TURN +1;
end;

procedure CopyToMyPlanet(var in_:myplanet; p :pptr; turn_ :int);
begin
        if (p<>nil) then
         with p^ do
         begin
   in_.OWNER   :=p^.owner;
    in_.CLANS   :=p^.colonists;
    in_.CHAPPY  :=p^.Cstat;
    in_.NATCLANS:=p^.natives;
    in_.NHAPPY  :=p^.Nstat;
    in_.CTAX    :=p^.Ctax;
    in_.NTAX    :=p^.Ntax;
    in_.SUP     :=p^.supplies;
    in_.MC      :=p^.funds;
    in_.DP      :=p^.defense;
    in_.M       :=p^.mines;
    in_.F       :=p^.factories;
    in_.NEU     :=p^.N;
    in_.TRI     :=p^.T;
    in_.DUR     :=p^.D;
    in_.MOL     :=p^.M;
    in_.NEUDEN  :=p^.Nm;
    in_.TRIDEN  :=p^.Tm;
    in_.DURDEN  :=p^.Dm;
    in_.MOLDEN  :=p^.Mm;
    in_.NATTYPE :=p^.Nrace;
    in_.NATGOV  :=p^.Ngovt;
    in_.TEMP    :=p^.climate;
    in_.TURN    := turn_;
    in_.NEUCORE :=p^.Nc;
    in_.TRICORE :=p^.Tc;
    in_.DURCORE :=p^.Dc;
    in_.MOLCORE :=p^.Mc;
         end;
end;

function NStrD(a:double):string;
begin
        NStrD := NStr0(trunc(a));
end;

procedure DrawPlanet(sx,sy : int; in_:myplanet);
var
        ystep   : int;
        c       : byte;
        s       : string[18];
        s1      : string[8];
        l       : long;
function WriteTaxes (tax:int):string;
var   s       : string[7];
begin
    if tax=0 then s:='No' else s:=NStr(tax)+'%';
    WriteTaxes:=' Taxes: '+s;
end;

function MaxPlanetStruct (colonists:double; limit:int) : int;
begin
    MaxPlanetStruct:=0;
    if colonists>0.0 then
      if colonists<=limit then 
        MaxPlanetStruct:=trunc(colonists) else
        MaxPlanetStruct:=Round(Sqrt(trunc(colonists)-limit))+limit;
end;

begin
        c:=LightGreen;
        SetColor(c);
        ystep:=8;
        OutTextXY(sx,sy,'Turn    '+NStrD(in_.TURN));
        inc(sy,ystep);

        OutTextXY(sx,sy,'Race: '+RaceName[trunc(in_.OWNER)]);
        inc(sy,2*ystep);
        OutTextXY(sx,sy,'Climate: '+NStrMax(trunc(100-in_.TEMP),3,'+')+' '+ClimStr[ClimateType(trunc(in_.TEMP))]);
        inc(sy,ystep);
        if (in_.NATTYPE >0) then begin
                OutTextXY(sx,sy,'Natives:');
                inc(sy,ystep);
                OutTextXY(sx,sy,' Race : '+NatRace[trunc(in_.NATTYPE)]);
                inc(sy,ystep);
                OutTextXY(sx,sy,' Gov. : '+NatGovt[trunc(in_.NATGOV)]);
                inc(sy,ystep);
                OutTextXY(sx,sy,' Pop. : '+NStrD(in_.NATCLANS)+'00');
                inc(sy,ystep);
                OutTextXY(sx,sy,WriteTaxes(trunc(in_.NTAX)));
                inc(sy,ystep);
                SetColor(IIF(trunc(in_.NHAPPY)>=70,c,IIF(trunc(in_.NHAPPY)<30,LightRed,Yellow)));
                OutTextXY(sx,sy,' Happy: '+NStrD(in_.NHAPPY)+'%');
                SetColor(c);
                inc(sy,ystep);
        end
        else
        begin
                inc(sy,ystep);
                OutTextXY(sx,sy,'(no native life)');
                inc(sy,5*ystep);
        end;
        if (in_.CLANS >0) then begin
                OutTextXY(sx,sy,'Colonists:');
                inc(sy,ystep);
                OutTextXY(sx,sy,' Pop. : '+NStrD(in_.CLANS)+'00');
                inc(sy,ystep);
                OutTextXY(sx,sy,WriteTaxes(trunc(in_.CTAX)));
                inc(sy,ystep);
                SetColor(IIF(trunc(in_.CHAPPY)>=70,c,IIF(trunc(in_.CHAPPY)<30,LightRed,Yellow)));
                OutTextXY(sx,sy,' Happy: '+NStrD(in_.CHAPPY)+'%');
        end else begin
                inc(sy,ystep);
                SetColor(LightRed);
                OutTextXY(sx,sy,'no Colonists');
                inc(sy,ystep);
                OutTextXY(sx,sy,'(Planet lost)');
                inc(sy,ystep);
        end;
        SetColor(c);
        inc(sy,2*ystep);
        SetColor(c);
        l:=MaxPlanetStruct(in_.CLANS,200);
        Str(in_.m:3:0,s); Str(l,s1);
        OutTextXY(sx,sy,'Mines    :    /'+s1);
        if trunc(in_.m)>l then SetColor(Red);
        OutTextXY(sx+11*8,sy,s);
        SetColor(c);
        OutTextXY(sx+21*8,sy,'LIZ Hissing Ships: '+NStrD(in_.HISS)); {Quapla}
        inc(sy,ystep);
        l:=MaxPlanetStruct(in_.CLANS,100);
        Str(in_.f:3:0,s); Str(l,s1);
        OutTextXY(sx,sy,'Factories:    /'+s1);
        if trunc(in_.f)>l then SetColor(Red);
        OutTextXY(sx+11*8,sy,s);
        SetColor(c);
        OutTextXY(sx+21*8,sy,'Klingon Pillage  :'); {Quapla}
        if (in_.NOPILL >0) then OutTextXY(sx+40*8,sy,'No ')
                           else OutTextXY(sx+40*8,sy,'Yes');
        inc(sy,ystep);
        l:=MaxPlanetStruct(in_.CLANS,50);
        Str(in_.dp:3:0,s); Str(l,s1);
        OutTextXY(sx,sy,'Defense  :    /'+s1);
        if trunc(in_.dp)>l then SetColor(Red);
        OutTextXY(sx+11*8,sy,s);
        SetColor(c);
        OutTextXY(sx+21*8,sy,'Rebel RGA        : '); {Quapla}
                if (in_.NORGA >0) then OutTextXY(sx+40*8,sy,'No ')
                                  else OutTextXY(sx+40*8,sy,'Yes');      
        inc(sy,2*ystep);
        OutTextXY(sx,sy,'Supplies: '+NStrD(in_.SUP));
        inc(sy,ystep);
        OutTextXY(sx,sy,'Funds   : '+NStrD(in_.MC));
        inc(sy,2*ystep);
        OutTextXY(sx,sy,'Neutronium: '+NStrD(in_.NEU));
        inc(sy,ystep);
        OutTextXY(sx,sy,'Tritanium : '+NStrD(in_.TRI));
        inc(sy,ystep);
        OutTextXY(sx,sy,'Duranium  : '+NStrD(in_.DUR));
        inc(sy,ystep);
        OutTextXY(sx,sy,'Molybdenum: '+NStrD(in_.MOL));
        inc(sy,ystep);
end;

procedure PlanSimDo;
const
        MaxHistoryIndex = 184;
        MaxShow         = 8;
var
        mx,my,i         : int;
        chh             : word;
        nowPlanet       : myplanet;
        nextPlanet      : myplanet;
        history         : array [1..MaxHistoryIndex] of MyPlanetPtr;
        historyStart, historyEnd, historyIndex : int;
        showPlot        : int;
        show            : array[1..MaxShow] of Boolean;

function calc(i:int ; planet:MyPlanetPtr):long;
var
    ret : long;
begin
        if (show[i]) then
        begin
                case i of
                1 : ret := trunc(planet^.CLANS);
                2 : ret := trunc(planet^.CHAPPY);
                3 : ret := trunc(planet^.CTAX);
                4 : ret := trunc(planet^.NATCLANS);
                5 : ret := trunc(planet^.NHAPPY);
                6 : ret := trunc(planet^.NTAX);
                7 : ret := trunc(planet^.SUP);
                8 : ret := trunc(planet^.MC);
                end;
                calc := ret;
                if ret=0 then calc:=1;
        end
        else
        calc :=1;

end;

procedure DrawShortCuts(x,y : int; nattype :int; clans :int);
begin
        SetColor(White);
        {OutTextXY(x+8,y,'u');}
        inc(y,8);
        OutTextXY(x+8*3,y,'e');
        inc(y,8*2);
        OutTextXY(x,y,'C');
        inc(y,8*2);

        if (nattype<>0) then
        begin
                OutTextXY(x+8,y,'R');
                inc(y,8);
                OutTextXY(x+8,y,'G');
                inc(y,8);
                OutTextXY(x+8,y,'P');
                inc(y,8);
                OutTextXY(x+8,y,'T');
                inc(y,8);
                OutTextXY(x+8,y,'H');
                inc(y,8);
        end else inc(y,8*5);            
        inc(y,8);
        if (clans >0) then begin  {Quapla}
                OutTextXY(x+8*2,y,'o');
                inc(y,8);
                OutTextXY(x+8*3,y,'x');
                inc(y,8);
                OutTextXY(x+8*5,y,'y');
        end else inc(y,2*8);
        inc(y,8);
        inc(y,8);
        OutTextXY(x,y,'M');
        OutTextXY(x+8*23,y,'Z');
        inc(y,8);
        OutTextXY(x+8,y,'a');
        OutTextXY(x+8*21,y,'K'); {Quapla}
        inc(y,8);
        OutTextXY(x,y,'D');
        OutTextXY(x+8*23,y,'b'); {Quapla}
        inc(y,8);
        inc(y,8);
        OutTextXY(x,y,'S');
        inc(y,8);
        OutTextXY(x,y,'F');
        inc(y,8);
        inc(y,8);
        OutTextXY(x,y,'N');
        inc(y,8);
        OutTextXY(x+8*2,y,'i');
        inc(y,8);
        OutTextXY(x+8,y,'u');
        inc(y,8);
        OutTextXY(x+8*2,y,'l');
        inc(y,8);
end;

procedure DrawHistory;
  const XSize   = 550;
        YSize   = 200;
        X0      = 54;
        Y0      = 465;
        Yn      = 10;
const   RaceColor       : array [1..11] of byte =
                (White,Yellow,LightGreen,Brown,Cyan,LightMagenta,
                 LightGray,LightRed,Magenta,LightBlue,LightCyan);

        Text : array [1..MaxShow] of string[8] =
        ('Clans','Happy','Tax','Clans','Happy','Tax','Supplies','Funds');

  var   t       : MyPlanetPtr;
        i,i_    : long;
        m1,m2,k,sc      : long;
        m1_,m2_ : array [1..MaxShow] of long;
        t0,j    : long;
        dx,dy   : long;
        r       : array [1..MaxShow] of boolean;
        ii_     : long;
        x,y     : int;
        s       : string;
  begin
    i_:=0;
    for i:=1 to maxShow do if (show[i]) then begin i_:=i; break; end;
    ii_:=showplot;
    SetColor(DarkGray);
    Rectangle(X0-1,Y0+1,X0+XSize,Y0-YSize);
    dx := XSize div maxShow;
    x:=ii_*dx+IIF(ii_=8,16,0)+IIF((ii_=7) or (ii_=4),-8,0)-16-1;
    y:=Y0-YSize-8-2;
    setcolor(lightGray);
    OutTextXY(dx    ,y-8,'______COLONISTS_____');
    OutTextXY(dx*4-8,y-8,'_______NATIVES_______');
    SetColor(LightBlue);
    if (i_<>0) then begin
        MoveTo(x,y);
        LineTo(x+8,y);LineTo(x+8,y+8);LineTo(x,y+8);LineTo(x,y);
    end;
    inc(y);
    for i:=1 to maxShow do begin
    SetColor(RaceColor[i]);
    OutTextXY(i*dx+IIF(i=8,16,0)+IIF((i=7) or (i=4),-8,0),y,Text[i]);
    SetColor(White);
    OutTextXY(i*dx-16+IIF(i=8,16,0)+IIF((i=7) or (i=4),-8,0),y,NStr(i));
    SetColor(LightGray);
    if (show[i]) then s:='+' else s:='-';
    OutTextXY(i*dx-8+IIF(i=8,16,0)+IIF((i=7) or (i=4),-8,0),y,s);
    end;


    ii_:=0;
    for i:=1 to maxShow do if (show[i]) then begin ii_:=i; break; end;
    if (ii_=0) then exit;
    ii_:=showplot;
    if (historyIndex=1) then exit;

    j:=1;
    t:= history[j];

    FillChar(r,11,No);
    for i:=1 to maxShow do begin m1_[i]:=200000; m2_[i]:=0; end;
    m1:=200000; m2:=-1;

    t0:=trunc(T^.turn);

    while t<>nil do
    begin
      for i:=1 to maxShow do
      begin
        k:= calc(i,t);
        if k>0 then
        begin
          r[i]:=show[i];
          m1_[i]:=MinL(m1_[i],k);
          m2_[i]:=MaxL(m2_[i],k);
        end;
      end;
      inc(j);
      t:= history[j];
      if (j=MaxHistoryIndex) then t:=nil;
    end;

    m1 := m1_[ii_];
    m2 := m2_[ii_];

    dx:=MaxL(XSize div (historyEnd-t0),1);      { pixels per turn }
    dy:=(m2-m1)div YSize+1;     { points per pixel }

    for i_:=1 to maxShow+1 do
    begin
      if (i_<=maxShow) then if (i_<>ii_) then i:=i_ else i:=0
                       else i:=ii_;

      if (i>0)and(r[i]) then
      begin
        dx:=MaxL(XSize div (historyEnd-t0),1);  { pixels per turn }
        dy:=(m2_[i]-m1_[i])div YSize+1;         { points per pixel }
        SetColor(RaceColor[i]);
        j:=1;
        t:= history[j];
        MoveTo(X0+(trunc(T^.turn)-t0)*dx,Y0-(calc(i,t)-m1_[i]) div dy);

        while t<>nil do
        begin
          sc:=calc(i,t);
          if sc>=0 then LineTo(X0+(trunc(t^.turn)-t0)*dx,Y0-(sc-m1_[i]) div dy)
                   else MoveTo(X0+(trunc(t^.turn)-t0)*dx,Y0-(sc-m1_[i]) div dy);
        inc(j);
        t:= history[j];
        if (j=MaxHistoryIndex) then t:=nil;
        end;
      end;
    end;
    dx:=MaxL(XSize div (historyEnd-t0),1);      { pixels per turn }
    dy:=(m2-m1)div YSize+1;     { points per pixel }

    SetTextJustify(CenterText,TopText);
    SetColor(DarkGray);
    j:=1;
    t:= history[j];
    i:=0;
    while t<>nil do
    begin
      k:=X0+(trunc(t^.turn)-t0)*dx;
      MoveTo(k,Y0+1);
      if k-i<32 then LineRel(0,2)
      else begin
        LineRel(0,3);
        OutTextXY(k,Y0+7,NStr(trunc(t^.turn)));
        i:=k;
      end;
      inc(j);
        t:= history[j];
        if (j=MaxHistoryIndex) then t:=nil;
    end;

    SetTextJustify(RightText,CenterText);

    dx:=MaxL((((m2-m1) div Yn) div 5)*5,10);
    i:=(m1 div 5)*5;
    while i<m1+YSize*dy do
    begin
      k:=Y0-(i-m1) div dy;
      MoveTo(X0-1,k); LineRel(-3,0);
      OutTextXY(X0-5,k,NStr(i));
      inc(i,dx);
    end;
    SetTextJustify(LeftText,TopText);
    OutTextXY(0,Y0+7,'turn:');
  end;

procedure ShowForecast;
var
        temp :double;
        x,y : int;
        ystep   : int;
        c       : byte;
        s1      : string;
begin
        c:=LightGreen;
        SetColor(c);
        ystep:=8;
        y := 12+8*7;
        x := 21*8;

        if (nowPlanet.NATTYPE>0) and (trunc(nowPlanet.NATCLANS)<>0) then
        begin
                temp := trunc((nextPlanet.NATCLANS-nowPlanet.NATCLANS)/nowPlanet.NATCLANS * 100);
                Str(temp:5:2,s1);
                OutTextXY(x,y,'growth: '+s1+' Clans');
                inc(y,2*ystep);
                temp := (nextPlanet.NHAPPY-nowPlanet.NHAPPY);
                Str(temp:3:0,s1);
                if (trunc(temp)>=0) then begin delete(s1,1,1); s1:='+'+s1; end;
                OutTextXY(x,y,' happy: '+s1);
                inc(y,ystep);

        end
        else
        inc(y,3*ystep);

        inc(y,ystep);

        temp := trunc((nextPlanet.CLANS-nowPlanet.CLANS)/nowPlanet.CLANS * 100);
        Str(temp:5:2,s1);
        OutTextXY(x,y,'growth: '+s1+' Clans');
        inc(y,2*ystep);
        temp := (nextPlanet.CHAPPY-nowPlanet.CHAPPY);
        Str(temp:2:0,s1);
        if (trunc(temp)>=0) then begin delete(s1,1,1); s1:='+'+s1; end;
        OutTextXY(x,y,' happy: '+s1);
        inc(y,6*ystep);

        temp := (nextPlanet.SUP-nowPlanet.SUP);
        Str(temp:2:0,s1);
        if (trunc(temp)=0) then begin delete(s1,1,1); s1:='+'+s1; end;
        if (trunc(temp)>0) then s1:='+'+s1;
        OutTextXY(x,y,'supplies: '+s1);
        if (nowPlanet.NOPILL =0) then OutTextXY(x+17*8,y,'Pillaged: '+NStrD(nextPlanet.PILLSUP));
        inc(y,ystep);
        temp := (nextPlanet.MC-nowPlanet.MC);
        Str(temp:2:0,s1);
        if (trunc(temp)=0) then begin delete(s1,1,1); s1:='+'+s1; end;
        if (trunc(temp)>0) then s1:='+'+s1;
        OutTextXY(x,y,'income  : '+s1);
        if (nowPlanet.NOPILL =0) then OutTextXY(x+17*8,y,'Pillaged: '+NStrD(nextPlanet.PILLMC));

        inc(y,2*ystep);

        temp := (nextPlanet.NEU-nowPlanet.NEU);
        Str(trunc(temp),s1);
        OutTextXY(x,y,'extract : +'+s1);
        Str(trunc(nowPlanet.NEUCORE),s1);
        OutTextXY(x+17*8,y,'core: '+s1);
        inc(y,ystep);
        temp := (nextPlanet.TRI-nowPlanet.TRI);
        Str(trunc(temp),s1);
        OutTextXY(x,y,'extract : +'+s1);
        Str(trunc(nowPlanet.TRICORE),s1);
        OutTextXY(x+17*8,y,'core: '+s1);
        inc(y,ystep);
        temp := (nextPlanet.DUR-nowPlanet.DUR);
        Str(trunc(temp),s1);
        OutTextXY(x,y,'extract : +'+s1);
        Str(trunc(nowPlanet.DURCORE),s1);
        OutTextXY(x+17*8,y,'core: '+s1);
        inc(y,ystep);
        temp := (nextPlanet.MOL-nowPlanet.MOL);
        Str(trunc(temp),s1);
        OutTextXY(x,y,'extract : +'+s1);
        Str(trunc(nowPlanet.MOLCORE),s1);
        OutTextXY(x+17*8,y,'core: '+s1);
        inc(y,ystep);
end;

procedure DrawFirst;
const
        HeadX   = 28*8;
begin
        ClearDevice;

        SetColor(Yellow);
        OutTextXY(HeadX,0,'PLANET SIMULATOR');
        SetLineStyle(SolidLn,0,NormWidth);
        Line(HeadX,12,HeadX+16*8-1,12);

        DrawPlanet(1,12,nowPlanet);
        DrawShortCuts(1,12,trunc(nowPlanet.NATTYPE),trunc(nowPlanet.CLANS));
        DrawPlanet(640-18*8,12,nextPlanet);
        DrawHistory;
        ShowForecast;
end;

function ChooseNatRace(initrace:int):int;
var
        i,j:int;
        x,y:int;
begin
        x:=8*6;
        y:=8*7-4;
        j:=initrace+1;
        NewMenu;
        AddMenuItem('(none)',LightGray,No);
        for i:=1 to 9 do AddMenuItem(NatRace[i],LightGray,No);
        Clear(x-3,y,x+11*8-1-3,y+8*11-4);
        ChooseMenu(x,y,x+2,x+11*8,10,LightGray,Yellow,j,No,No,-1);
        if (MenuKey<>27) and (MenuValue<>0) then
        ChooseNatRace := MenuValue-1
        else ChooseNatRace :=initrace;
end;

function ChooseNatGov(initrace:int):int;
var
        i,j:int;
        x,y:int;
begin
        x:=8*6;
        y:=8*8-4;
        j:=initrace;
        NewMenu;
        for i:=1 to 9 do AddMenuItem(NatGovt[i],LightGray,No);
        Clear(x-3,y,x+14*8-1-3,y+8*10-4);
        ChooseMenu(x,y,x+2,x+14*8,9,LightGray,Yellow,j,No,No,-1);
        if (MenuKey<>27) and (MenuValue<>0) then
        ChooseNatGov := MenuValue
        else ChooseNatGov :=initrace;
end;

function ChooseRace(initrace:int):int;
var
        i,j:int;
        x,y:int;
begin
        x:=8*6;
        y:=8*3-4;
        j:=initrace;
        NewMenu;
        for i:=1 to 11 do AddMenuItem(RaceName[i],LightGray,No);
        Clear(x-3,y,x+11*8-1-3,y+8*12-4);
        ChooseMenu(x,y,x+2,x+11*8,11,LightGray,Yellow,j,No,No,-1);
        if (MenuKey<>27) and (MenuValue<>0) then
        ChooseRace := MenuValue
        else ChooseRace :=initrace;

end;

function ChooseNumber(x_,y_,len_,arrow_: long; yes_no_ : Boolean; min__,max__,initnumber_ : long):long;
var CN : long;
begin
  CN := -999;
  while (CN = -999) do begin 
    CN := DoChooseNumber(x_,y_,len_,arrow_,yes_no_,min__,max__,initnumber_);
    if (CN=-999) then begin 
      helpscr:=5;
      Help;
      helpscr:=0;
      DrawFirst;
    end;
  end;
  ChooseNumber := CN;
end;

begin
        if (ltype<>LockP) or (lplan=nil) then exit;
        if (lplan^.Nc = -1) or (lplan^.N = -1) or (lplan^.Nm =-1) then exit;
        CopyToMyPlanet(nowPlanet,lplan,turn);

        if (nowPlanet.NATTYPE <=0) then begin
                nowPlanet.NATGOV        :=0;
                nowPlanet.NATCLANS      :=0;
                nowPlanet.NTAX          :=0;
                nowPlanet.NHAPPY        :=0;
        end;
        if (nowPlanet.OWNER <=0) then nowPlanet.OWNER   :=player;
        if (nowPlanet.CLANS <=0) then begin
                 nowPlanet.CLANS        :=100;
                 nowPlanet.CHAPPY       :=80;
                 nowPlanet.CTAX         :=0;
                 nowPlanet.SUP          :=0;
                 nowPlanet.MC           :=0;
        end;
        
        { Getting Ship-Data Quapla - Who knows how to get Ship-Info here? Mail: sfplanets@gmx.de}
        nowPlanet.HISS := 0;
        nowPlanet.NOPILL := 1;
        nowPlanet.NORGA := 1;
        
        historyStart    := turn;
        historyEnd      := turn;

        for i:= 1 to maxHistoryIndex do history[i]:=nil;
        show[1]  := true;
        showplot :=1;
        for i := 2 to maxShow do show[i] := False;

        historyIndex    := 1;
        New(history[1]);
        history[1]^     := nowPlanet;

        cfg_ClimateLimitsPopulation     :=1;
        cfg_NativeClimateDeathRate      :=0;
        cfg_CrystalSinTempBehavior      :=0;
        cfg_CrystalsLikeDesert          :=1;
        cfg_MaxColTempSlope             :=1000;
        cfg_AllowEatingSupplies         :=1;
        cfg_ClimateDeathRate            :=10;
        cfg_AssimRate                   :=100;
        cfg_StructureDecayPerTurn       :=5;
        cfg_MaxPlanetaryIncome          :=MaxIncome;
        cfg_HissEffectRate              :=HissEffect;

        TerraForm       :=0;
        TerraFormLimit  :=0;
        TerraFormStep   :=0;
        RaceGrowth      :=100;
        RaceMine        :=MinRate[trunc(nowPlanet.OWNER)];
        RaceProduction  :=ProductionRate[trunc(nowPlanet.OWNER)];
        CTaxRate        :=TaxCRate[trunc(nowPlanet.OWNER)];
        NTaxRate        :=TaxNRate[trunc(nowPlanet.OWNER)];

        MouseOff;
        MouseDisabled:=True;
        mx:=MouseX; my:=MouseY;
        helpscr:=9;

        DoNextTurn(nextPlanet,nowPlanet);   
        DrawFirst;

        repeat
                chh:=ReadKey;
                case chh of
                $3B00   : begin
                        ClearDevice;
                        Help;
                        DrawFirst;
                        end;
{tab}           9       : begin
                        i:=1;
                        while (i<=maxShow) do
                        begin
                                inc(showplot);
                                if (showplot > MaxShow) then showplot:=1;
                                if (show[showplot]) then break;
                                inc(i);
                        end;
                        DrawFirst;
                        end;
                ord('1')..ord('1')+MaxShow : begin
                        if (show[chh-ord('1')+1])       then show[chh-ord('1')+1] := False
                                                        else show[chh-ord('1')+1] := True;
                        if (NOT show[showplot]) then
                        begin
                                i:=1;
                                while (i<maxShow) do
                                begin
                                        inc(showplot);
                                        if (showplot > MaxShow) then showplot:=1;
                                        if (show[showplot]) then break;
                                        inc(i);
                                end;
                        end;
                        DrawFirst;
                        end;
                ord('+'),ord('='),$4D00
                        : begin
                                if (historyIndex< MaxHistoryIndex) then
                                begin
                                        nowPlanet := nextPlanet;

                                        inc(historyIndex);
                                        New(history[historyIndex]);
                                        history[historyIndex]^  := nowPlanet;

                                        inc(historyEnd);
                                        DoNextTurn(nextPlanet,nowPlanet);
                                        DrawFirst;
                                end;
                          end;
{ctrl rt}       $7400  : begin
                         i:=0;
                         while ((i<10)and(historyIndex<MaxHistoryIndex))do
                         begin
                                nowPlanet := nextPlanet;
                                inc(historyIndex);
                                New(history[historyIndex]);
                                history[historyIndex]^  := nowPlanet;
                                inc(historyEnd);
                                DoNextTurn(nextPlanet,nowPlanet);
                                inc(i);
                         end;
                         DrawFirst;
                         end;


                ord('-'),ord('_'),$4B00
                        : begin
                                if (historyIndex> 1) then
                                begin
                                        Dispose(history[historyIndex]);
                                        history[historyIndex]:=nil;
                                        dec(historyIndex);
                                        nowPlanet := history[historyIndex]^;
                                        dec(historyEnd);
                                        DoNextTurn(nextPlanet,nowPlanet);
                                        DrawFirst;
                                end;
                           end;

{ctrl lf}       $7300  : begin
                         i:=0;
                         while ((i<10)and(historyIndex>1))do
                         begin
                                Dispose(history[historyIndex]);
                                history[historyIndex]:=nil;
                                dec(historyIndex);
                                nowPlanet := history[historyIndex]^;
                                dec(historyEnd);
                                inc(i);
                         end;
                         DoNextTurn(nextPlanet,nowPlanet);
                         DrawFirst;
                        end;
                ord('r') : begin
                        nowPlanet.NATTYPE := ChooseNatRace(trunc(nowPlanet.NATTYPE));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('k') : begin      {Pillage by Quapla}
                        if (nowPlanet.NOPILL >0) then nowPlanet.NOPILL := 0
                                                 else nowPlanet.NOPILL := 1;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('b') : begin      {RGA by Quapla}
                        if (nowPlanet.NORGA >0) then nowPlanet.NORGA := 0
                                                 else nowPlanet.NORGA := 1;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('z'): begin     {Hiss by Quapla}
                        nowPlanet.HISS := ChooseNumber(1+8*40,12+8*15,3,-2,yes,0,500,trunc(nowPlanet.HISS));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('g') : begin
                        if (nowPlanet.NATTYPE>0) then begin
                        nowPlanet.NATGOV := ChooseNatGov(trunc(nowPlanet.NATGOV));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end; end;
                ord('e') : begin
                        nowPlanet.OWNER := ChooseRace(trunc(nowPlanet.OWNER));
                        history[historyIndex]^  := nowPlanet;
                        RaceMine        :=MinRate[trunc(nowPlanet.OWNER)];
                        RaceProduction  :=ProductionRate[trunc(nowPlanet.OWNER)];
                        CTaxRate        :=TaxCRate[trunc(nowPlanet.OWNER)];
                        NTaxRate        :=TaxNRate[trunc(nowPlanet.OWNER)];
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('m'): begin
                        nowPlanet.M     := ChooseNumber(1+8*11,12+8*15,3,-2,yes,0,999,trunc(nowPlanet.M));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('a'): begin
                        nowPlanet.F     := ChooseNumber(1+8*11,12+8*16,3,-2,yes,0,999,trunc(nowPlanet.F));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('d'): begin
                        nowPlanet.DP    := ChooseNumber(1+8*11,12+8*17,3,-2,Yes,0,999,trunc(nowPlanet.DP));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('s'): begin
                        nowPlanet.sup   := ChooseNumber(1+8*10,12+8*19,6,-2,Yes,0,999999,trunc(nowPlanet.sup));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('f'): begin
                        nowPlanet.mc    := ChooseNumber(1+8*10,12+8*20,6,-2,Yes,0,999999,trunc(nowPlanet.mc));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('p'): begin
                        if (nowPlanet.NATTYPE>0) then begin
                        nowPlanet.NATCLANS      := ChooseNumber(1+8*8,12+8*7,6,-2,Yes,0,999999,trunc(nowPlanet.NATCLANS));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end; end;
                ord('t'): begin
                        if (nowPlanet.NATTYPE>0) then begin
                        nowPlanet.NTAX  := ChooseNumber(1+8*8,12+8*8,3,-2,Yes,0,100,trunc(nowPlanet.NTAX));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end; end;
                ord('h'): begin
                        if (nowPlanet.NATTYPE>0) then begin
                        nowPlanet.NHAPPY        := ChooseNumber(1+8*8,12+8*9,4,-2,Yes,-300,100,trunc(nowPlanet.NHAPPY));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end; end;
                ord('o'): begin
                        nowPlanet.CLANS := ChooseNumber(1+8*8,12+8*11,6,-2,Yes,0,999999,trunc(nowPlanet.CLANS));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('x'): begin
                        nowPlanet.CTAX  := ChooseNumber(1+8*8,12+8*12,3,-2,Yes,0,100,trunc(nowPlanet.CTAX));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('y'): begin
                        nowPlanet.CHAPPY        := ChooseNumber(1+8*8,12+8*13,4,-2,Yes,-300,100,trunc(nowPlanet.CHAPPY));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('c'): begin
                        nowPlanet.TEMP  := 100-ChooseNumber(1+8*9,12+8*3,3,-2,Yes,0,100,trunc(100-nowPlanet.TEMP));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('n'): begin
                        nowPlanet.neu   := ChooseNumber(1+8*12,12+8*22,6,-2,Yes,0,999999,trunc(nowPlanet.neu));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('i'): begin
                        nowPlanet.tri   := ChooseNumber(1+8*12,12+8*23,6,-2,Yes,0,999999,trunc(nowPlanet.tri));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('u'): begin
                        nowPlanet.dur   := ChooseNumber(1+8*12,12+8*24,6,-2,Yes,0,999999,trunc(nowPlanet.dur));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;
                ord('l'): begin
                        nowPlanet.mol   := ChooseNumber(1+8*12,12+8*25,6,-2,Yes,0,999999,trunc(nowPlanet.mol));
                        history[historyIndex]^  := nowPlanet;
                        DoNextTurn(nextPlanet,nowPlanet);
                        DrawFirst;
                        end;

                end;
        until chh=27;

        for i:= 1 to historyIndex do Dispose(history[i]);

        helpscr:=0;
        DrawRightScreen;
        MoveMouseTo(mx,my);
        MouseDisabled:=False;
        MouseOn;
        ResetMouse;
        if lock<>0 then begin force:=lock; ForceKey:=13 end;
        {20040308 cgraefe: 'ch:=2' commented out. What do we need this for? It
                           disturbs the usage of ctrl-b in vpa2.pas.}
        {ch:=2;}                { redraw map }
end;


end.