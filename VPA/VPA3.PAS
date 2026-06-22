{
*******************************************************************
* VPA3.PAS - Main Part Actions
*
* $Id: vpa3.pas,v 1.58 2013/12/24 08:08:10 sfplanets Exp $
*
*******************************************************************
}

{$I switches.inc}
Unit    VPA3;           (* VPA Main Part - Actions *)
{$V-}

Interface

uses    AuxF,VPAData;

const
        DWdrawn : boolean = No;

procedure CalcTaxes;
procedure FindPlanet;
procedure FindShip;
procedure GoTurn;
procedure DrawUserCircle;
procedure DrawRange;
procedure DrawHYPCircles;
procedure DrawMineCircle;
procedure DrawMineCircleRadius;
procedure AdjustMinefieldUnits;
procedure AdjustMinefieldRadius;
procedure TimeShift (dt:int);
procedure InputHull;
procedure ForgetShip;
procedure SetWarp;
procedure SetFCode (p_s:xtype; rnd:boolean);
procedure RandAllPCodes;
procedure PBPInfo;
procedure SetName;
function  ChooseMission (var misn:int; var md1,md2:boolean; sh:sptr; race:int; no_tow1,no_plan1:boolean;
                         x,y,x2:int; value1, value2 :long) : boolean;
procedure SetMission;
function  ChooseEnemy (var en:int; x,y,x2:int) : boolean;
procedure SetEnemy;
function  UnloadShip (id:int) : boolean;
procedure UnloadAllShips;
procedure LoadForBuild;                         { MOT interface }
procedure BuildStructures (mfd:MFDtype);        { MOT interface }
procedure SellSupp;
procedure BuildBase;
procedure CancelBase;
procedure IncreaseBaseDefense;                  { MOT interface }
procedure SetBaseOrder;
procedure BuyShipTF;                            { MOT interface }
procedure BuyBaseTF;                            { MOT interface }
procedure TransferCargo (t:xtype);              { MOT interface }
procedure UpgradeBaseTech;                      { MOT interface }
procedure FixOrRecycleShip (bn,op,n:int);
procedure FixOrRecycle (op:byte);
function  BuildClone : boolean;
procedure NextPlanet (dn:int);
procedure NextBase (dn:int);
procedure NextShip (dn:int);
procedure NextMines (dn:int);
procedure NextIon (dn:int);
procedure NextWorm (dn:int);
procedure NextUFO (dn:int);
procedure ChangePassword;
procedure MineSim;
procedure NextActivePlanet (dn:int);
procedure NextActiveBase (dn:int);
procedure NextActiveShip (dn:int);
procedure SwitchActive (mask:int);
procedure ResetShipsInWarp;
procedure OKShip(mark:integer);
procedure DrawWarpCircles;
procedure DrawWarpCirclesSelect;
procedure PlanetYnfoSelect;
procedure DrawPlanetYnfos;

Implementation

uses    Mouse,Keyboard,Screen,ptcgraph,StrF,VPA2,VPA4,Ini

{$IFDEF VPACC}
     ,Hullfunc
{$ENDIF};

procedure CalcTaxes;
  var   p       : pptr;
        ip      : pointer;
        is      : word;
        s,s1    : string[7];
        ls      : byte absolute s;
        tax,gv  : int;
        l,nt,cl : long;
        kr,a,tr : int;
        hc      : real;
  begin
    p:=TTurn^.data^.planet[lock and LockLo];
    if (p=nil) or (p^.Nrace=-1) or (p^.natives=-1) or (p^.Ngovt=-1) or (p^.Nrace=0) then Exit;
    {MouseOff;}
    MouseDisabled:=True;
    is:=ImageSize(MX0,168,639,183);
    UnLockReservedMemory(is);
    GetMem(ip,is);
    GetImage(MX0,168,639,183,ip^);
    Clear(MX0,168,639,183);
    SetColor(LightGray);
    OutTextXY(MX0,168,' Taxes:');
    OutTextXY(MX0,176,' Money:');
    with p^ do
    begin
      nt:=natives;
      gv:=Ngovt;
      hc:=(500-SQRT(nt)-(factories+mines) div 2+50*gv)/100;
      tax:=IIF(Ntax>0,Ntax,Ceil((30+Trunc(hc)+hc)/0.85));
      cl:=colonists; if cl=-1 then cl:=0;
      kr:=IIF(Nrace=5,0,IIF(Nrace=6,2,1));
      tr:=TaxRate[IIF(p^.owner<=0,player,p^.owner)];
    end;
    repeat
      Clear(MX0+8*8,168,639,183);
      SetColor(LightGray);
      Str(tax:3,s);
      OutTextXY(MX0+8*8,168,s+'% >');
      l:=Round(nt*tax*gv/5000);
      Str((l*tr div 100)*kr,s); s1:='';
      if l>cl then
      begin
        Str((cl*tr div 100)*kr,s1);
        s1:='('+s1+')';
      end;
      OutTextXY(MX0+8*8,176,s+' '+s1);
      s:=GetStr(MX0+14*8,168,3);
      if ls>0 then Val(s,tax,a);
    until ls=0;
    PutImage(MX0,168,ip^,NormalPut);
    FreeMem(ip,is);
    LockReservedMemory;
    MouseDisabled:=False;
    {MouseOn;}
  end;

function SelectShip (x,y:int; myonly,forclone:boolean) : int;
  var   h       : sptr;
        i,k,k0,n: int;
        ns      : string[4];
        s       : string[13];
        sh      : int;
  begin
    NewMenu; UnLockReservedMemory(MenuSize(MX0,378,631,10,Yes));
    sh:=0; k:=0; k0:=0; n:=0;
    for i:=1 to 999 do
      if ShipIsHere(i,x,y) then
      begin
        h:=TTurn^.data^.ship[i];
        inc(k);
        if (h=lship) or (myonly and (h^.owner<>player)) or
           (forclone and ((h^.owner<>player) or OwnShipDesign(player,h^.hull))) then
          AddMenuItem('    ---',cSInfo,No)
        else begin
          if h^.hull<>-1 then
            if h^.owner=player then s:=h^.name else s:=Hulls[h^.hull].name
          else if h^.mass<>-1 then s:='??? ('+NStr0(h^.mass)+'kt)'
                              else s:='???';
          ns:=NStr(i)+'   ';
          AddMenuItem(ns+s,RaceColor[h^.owner,_S_],No);
          k0:=k;
          inc(n);
        end;
      end;
    if (k=0) or (n<2) then sh:=k0
    else begin
      ChooseMenu(MX0,378,MX0,631,10,cSInfo,Yellow,1,No,Yes,-1);
      if (MenuKey<>27) and (MenuString<>'    ---') then sh:=MenuValue;
    end;
    NewMenu; LockReservedMemory;
    if sh<>0 then sh:=GoToShipXY(h,x,y,sh) and LockLo;
    SelectShip:=sh;
  end;

procedure FindPlanet;
  var   s       : str20;
        i       : word;
        a       : integer;
  begin
    MouseMove;
    {MouseOff;}
    MouseDisabled:=True;
    ClearInfo;
    SetColor(White);
    OutTextXY(MX0,72,'Find which planet:');
    s:=GetStr(MX0,88,18);
    MouseDisabled:=False;
    {MouseOn;}
    if s='' then Clear(MX0,72,639,111)
    else begin
      if s[1] in ['0'..'9'] then Val(s,i,a)
      else begin
        i:=PSearchNm(s);
      end;
      if (i<=0) or (i>500) or (TTurn^.data^.xyplan[i,1]=-1) then
        begin SetColor(LightGray); OutTextXY(MX0,104,'Planet not found') end
      else begin
        {CenterMap(Planets[i].x,Planets[i].y,No);}
        force:=i or LockP;
        ForceKey:=13;
      end;
    end;
  end;

procedure FindShip;
  var   s       : str20;
        ls      : byte absolute s;
        h       : sptr;
        a       : integer;
        i       : int;
  begin
    MouseMove;
    {MouseOff;}
    MouseDisabled:=True;
    ClearInfo;
    SetColor(White);
    OutTextXY(MX0,72,'Find which ship:');
    s:=GetStr(MX0,88,18);
    MouseDisabled:=False;
    {MouseOn;}
    h:=nil;
    if s='' then Clear(MX0,72,639,111)
    else begin
      if s[1] in ['0'..'9'] then
      begin
        Val(s,i,a);
        if (i>=1) and (i<=999) then h:=TTurn^.data^.ship[i];
      end
      else
        for i:=1 to 999 do
        begin
          h:=TTurn^.data^.ship[i];
          if (h<>nil) and (h^.when=turn) and StrCmp(h^.name,s,ls) then Break
                                                                  else h:=nil;
        end;
      if h=nil then
        begin SetColor(LightGray); OutTextXY(MX0,104,'Ship not found') end
      else begin
        {CenterMap(h^.x,h^.y,No);}
        force:=i or LockS;
        ForceKey:=13;
      end;
    end;
  end;

procedure GoTurn;
  var   s       : str20;
        a       : integer;
        n_turn  : int;
  begin
    MouseMove;
    {MouseOff;}
    MouseDisabled:=True;
    ClearInfo;
    SetColor(White);
    OutTextXY(MX0,72,'Goto turn:['+nstr0(TRoot^.turn)+'-'+nstr0(today)+']');
    s:=GetStr(MX0,88,18);
    MouseDisabled:=False;
    {MouseOn;}
    if s='' then Clear(MX0,72,639,111)
    else begin
      if s[1] in ['0'..'9'] then
      begin
        Val(s,n_turn,a);
      end;
    end;
    ClearInfo;	
    if (n_turn >= TRoot^.turn) and (n_turn <= today)  then
    begin
      SetTurn(n_turn);
      TimeShift(0);
    end;
  end;

procedure DrawUserCircle;
  var   s       : str20;
        r,a     : integer;
  begin
    MouseMove;
    {MouseOff;}
    MouseDisabled:=True;
    ClearInfo;
    SetColor(White);
    OutTextXY(MX0,72,'Radius (LY):');
    SetColor(LightGray);
    OutTextXY(MX0,88,NStr(radius0));
    s:=GetStr(MX0,88,18);
    MouseOff;
    Clear(MX0,72,639,111);
    Val(s,r,a);
    if r>=0 then
    begin
      if r>0 then radius0:=r;
      SetViewPort(0,0,479,479,ClipOn);
      SetColor(DarkGray);
      DrawWCircle(MouseX,MouseY,long(radius0)*ratio2 div ratio1);
      SetViewPort(0,0,639,479,ClipOn);
      DrawMap(No);
    end;
    MouseDisabled:=False;
    MouseOn;
  end;

{ draw circles for range of a ship - i.e. how far it can travel in 1-4 turns.
  If a planet is selected, assume warp 9, otherwise the max safe speed. }
procedure DrawRange;
var
  lWarp: Integer;
begin
  if (lship=nil) OR (lShip^.El<1) OR (lShip^.El>9)
  then lWarp := 9
  else lWarp := GetSafeWarp(lShip^.El);

  MouseOff;
  SetViewPort(0,0,479,479,ClipOn);
  SetColor(DarkGray);
  DrawWCircle(MouseX,MouseY,long(lWarp*lWarp)*ratio2 div ratio1);
  DrawWCircle(MouseX,MouseY,long(2*lWarp*lWarp)*ratio2 div ratio1);
  DrawWCircle(MouseX,MouseY,long(3*lWarp*lWarp)*ratio2 div ratio1);
  DrawWCircle(MouseX,MouseY,long(4*lWarp*lWarp)*ratio2 div ratio1);
  DrawWCircle(MouseX,MouseY,long(5*lWarp*lWarp)*ratio2 div ratio1);
  DrawWCircle(MouseX,MouseY,long(6*lWarp*lWarp)*ratio2 div ratio1);
  SetViewPort(0,0,639,479,ClipOn);
  DrawMap(No);
  MouseOn;
end;


procedure DrawHYPCircles;
  begin
    MouseOff;
    SetViewPort(0,0,479,479,ClipOn);
    SetColor(DarkGray);
    { This restriction no longer applies in current hosts. }
    {if SWPlan and not PHOST then
      DrawWCircle(MouseX,MouseY,long(350)*ratio2 div ratio1)
    else} begin
      DrawWCircle(MouseX,MouseY,long(340)*ratio2 div ratio1);
      DrawWCircle(MouseX,MouseY,long(360)*ratio2 div ratio1);
      if (Addon.Unity) then DrawWCircle(MouseX,MouseY,long(690)*ratio2 div ratio1); {AHP Jump in Unity}
      if (Addon.Unity) then DrawWCircle(MouseX,MouseY,long(710)*ratio2 div ratio1); {by Quapla}
    end;
    SetViewPort(0,0,639,479,ClipOn);
    DrawMap(No);
    MouseOn;
  end;

procedure MoreInfoOnMinefield(Y0,units : long);
var
        s       : string[12];
        s1      : string[12];
        p       : double;
        safe1   : double;
        safe2   : double;
        rr      : long;
      {  units   : long;}

begin
   { More info }


       { Sweep with beam number 10 (best ones) }
        OutTextXY(MX0,Y0 +8*1,'To sweep use:');
        p := units/( 10*10*SweepRate);

        if ( p <> Trunc(p) ) then p := Trunc(p)+1.0
                             else p := Trunc(p);
        Str(p:5:0,s);
        OutTextXY(MX0,Y0 +8*2,s+' x '+Beams[10].name);

       {Safe travel with warp =9 to center probability}
        rr := Trunc(Sqrt(MaxL(units,0)));
        OutTextXY(MX0,Y0 +8*4,NStr(rr)+' LY travel prob');

        p := (100.0 - MineHitOdds)/100.0;
        safe1 := Exp(rr * Ln(p));
        p := (100.0 - MineHitOddsWhenCloakedX10/10.0)/100.0;
        safe2 := Exp(rr * Ln(p));
        Str(safe1*100.0:5:2,s);
        Str(safe2*100.0:5:2,s1);
        OutTextXY(MX0,Y0 +8*5,s+'% ('+s1+'%)');

        {Next turn decay }

        p := units * (100.0 - MineDecayRate)/100.0;
        p := Trunc(p);
        OutTextXY(MX0     ,Y0 +8*7,'Next turn     diff');

        OutTextXY(MX0     ,Y0 +8*8,'Radius: '+NStr0(Trunc(Sqrt(MaxL(Trunc(p),0)))));
        Str(Trunc(rr)-Trunc(Sqrt(MaxL(Trunc(p),0))):2,s);
        OutTextXY(MX0+8*16,Y0 +8*8,s);

        OutTextXY(MX0     ,Y0 +8*9,'Units : '+NStr0(Trunc(p)));
        Str(units-Trunc(p):4,s);
        OutTextXY(MX0+8*14,Y0 +8*9,s);

        {now web}
        OutTextXY(MX0,Y0 +8*12,'Web mines:');
        OutTextXY(MX0,Y0 +8*14,'To sweep use:');
        p := units/( 10*10*WebSweepRate);
        if ( p <> Trunc(p) ) then p := Trunc(p)+1.0
                             else p := Trunc(p);
        Str(p:5:0,s);
        OutTextXY(MX0,Y0 +8*15,s+' x '+Beams[10].name);

       {Safe travel with warp =9 to center probability}
        rr := Trunc(Sqrt(MaxL(units,0)));
        OutTextXY(MX0,Y0 +8*17,NStr(rr)+' LY travel prob');

        p := (100.0 - WebMineHitOdds)/100.0;
        safe1 := Exp(rr * Ln(p));
        p := (100.0 - WebMineHitOdds)/100.0;
        safe2 := Exp(rr * Ln(p));
        Str(safe1*100.0:5:2,s);
        Str(safe2*100.0:5:2,s1);
        OutTextXY(MX0,Y0 +8*18,s+'% ('+s1+'%)');

        {Next turn decay }

        p := units * (100.0 - WebMineDecayRate)/100.0;
        p := Trunc(p);
        OutTextXY(MX0     ,Y0 +8*20,'Next turn     diff');

        OutTextXY(MX0     ,Y0 +8*21,'Radius: '+NStr0(Trunc(Sqrt(MaxL(Trunc(p),0)))));
        Str(Trunc(rr)-Trunc(Sqrt(MaxL(Trunc(p),0))):2,s);
        OutTextXY(MX0+8*16,Y0 +8*21,s);

        OutTextXY(MX0     ,Y0 +8*22,'Units : '+NStr0(Trunc(p)));
        Str(units-Trunc(p):4,s);
        OutTextXY(MX0+8*14,Y0 +8*22,s);
end;

procedure AdjustMinefieldUnits;
begin
{to do -> integrate it somehow into procedure AdjustMinefieldRadius; Quapla}
end;

procedure AdjustMinefieldRadius;

var
       ow      : byte;
       r,yy     : int;
       m       : mptr;
       number  : word;
       s       : string[12];
       c       : byte;
       n       : int;
       i       : int; {maximal MOT value}
       _Y0     : int;
       _X0     : int;
       p,nt    : double;
       decay_units, sub_units,target_units : long;

       owner,gg : int;
begin
    if (ltype<>LockM) {or(turn<>today)} then Exit;
{
  FOR i:=1 TO 11 DO
   AddMenuItem(Elf[i] + SpacerStr + RaceName[i], 7, FALSE);
  i := SimpleListbox('Choose race', 200, 11, gg);
}

    number:=lock and LockLo;
    m:=TTurn^.data^.mines[number];
    if m<>nil then
    with m^ do
    begin
      ow:=Race[owner];

      {MouseMove;}
      MouseDisabled:=True;
      ClearInfo;
      r:=Round(Sqrt(units));

 { from vpa2.pas }
      SetColor(White);
      if (web and 2=2) and (owner=12) then s:='Someone''s'
                                      else s:=RaceName[owner];
      OutTextXY(MX0,72,s);
      if web and 1=0 then s:='field ' else s:='WEB ';
      OutTextXY(MX0,80,'mine '+s+NStr(number));
      SetColor(LightGray);
      if when=turn then OutTextXY(MX0,88,'(now)')
                   else OutTextXY(MX0,88,'('+NStr(turn-when)+Proper(turn-when,' turn')+' ago)');
      c:=RaceColor[owner,_M_];
      SetColor(c);
      OutTextXY(MX0,104,'Center:('+NStr0(x)+','+NStr0(y)+')');
      OutTextXY(MX0,112,'Radius: '+NStr0(Round(Sqrt(MaxL(units,0)))));
      s:=NStr00(units,'SWEPT OUT');
      if (web and 2=2) and (units>0) then s:='÷'+s;
      OutTextXY(MX0,120,'Units : '+s);
 {end}
 {M.O.T.}
      SetLineStyle(SolidLn,0,NormWidth);
      if (units > 0) then n:=Round(Sqrt(units))
                     else n:=0;
      _Y0 := 144+16;
      _X0 := 640-10*8;
      i   := 999;

      p := units * (100.0 - IIF(web and 1=0,MineDecayRate,WebMineDecayRate))/100.0;
      decay_units := Trunc(p);
      target_units := longint(n) * longint(n);
      OutTextXY(MX0,128,'Decay : '+NStr0(units-decay_units));

      OutTextXY(MX0,136+8,' REQUESTED');
      OutTextXY(MX0,_Y0    ,'Radius: '+NStr0(Trunc(Sqrt(MaxL(units,0)))));
      OutTextXY(MX0,_Y0+8  ,'Units : '+NStr0(target_units));

      OutTextXY(MX0,_Y0+16*8,'(using '+NStr(UnitsPerTorpRate[ow])+'% rate)');
      repeat
        Clear(_X0,_Y0,_X0+4*8,_Y0+7);
        SetColor(c);
        OutTextXY(_X0,_Y0,NStr0(n));
        SetColor(Yellow);
        Line(_X0,_Y0+7,_X0+23,_Y0+7);
        repeat ArrowBlink(_X0+4*8,_Y0) until KeyPressed;
        SetColor(Black);
        Line(_X0,_Y0+7,_X0+23,_Y0+7);
        ch:=ReadKey;
        case ch of
          $4B00 : n:=IIF(KbdFlags and KbdShft=0,Max(n-1,0),0);
          $4D00 : n:=IIF(KbdFlags and KbdShft=0,Min(n+1,i),i);
          $7300 : n:=Max(n-10,0);
          $7400 : n:=Min(n+10,i);
          $9B00 : n:=Max(n-100,0);
          $9D00 : n:=Min(n+100,i);
          ord('0')..ord('9')    : begin
                    GetStr1stKey:=ch;
                    s:=GetStr(_X0,_Y0,3);
                    if GetStrKey=13 then n:=Min(Max(Value(s),0),i);
                  end;
          $3B00 : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
        end;
      {draw prediction}
      SetColor(c);
      Clear(MX0+7*8,_Y0+5*8,MX0+13*8,_Y0+(5+10)*8+7);
      target_units := longint(n) * longint(n);
      sub_units := target_units - decay_units;
      Clear(MX0+7*8,_Y0+1*8,MX0+14*8,_Y0+1*8+7);
      OutTextXY(MX0,_Y0+1*8,'Units : '+NStr0(target_units));

      Clear(MX0+7*8,_Y0 + 3*8,MX0+14*8,_Y0 + 3*8+7);
      if (sub_units > 0 ) then OutTextXY(MX0+7*8,_Y0 + 3*8,'   Lay')
                          else OutTextXY(MX0+7*8,_Y0 + 3*8,' Scoop');

      for yy := 1 to 10 do begin
        nt := sub_units / ( (UnitsPerTorpRate[ow]/100.0)*longint(yy)*longint(yy));
        nt := Abs(nt);
        Str(nt:7:0,s);
        OutTextXY(MX0,_Y0 + 4*8 + yy*8,Torps[yy].name+s);
      end;
      until (ch=13) or (ch=27);
      Clear(_X0+4*8,_Y0,_X0+8*8,_Y0+7);
 {end M.O.T.}

      MouseOff;
      SetViewPort(0,0,479,479,ClipOn);
      SetColor(DarkGray);
      DrawWCircle(MouseX,MouseY,long(n)*ratio2 div ratio1);
      SetViewPort(0,0,639,479,ClipOn);
      DrawMap(No);

      MouseDisabled:=False;
      MouseOn;

    end;
end;

procedure DrawMineCircleRadius;
var
       y,mn    : int;
       s       : string[12];
       id,t,n  : int;
       ow      : byte;
       nt      : double;
       r       : longint;

begin
    t:=10; n:=0;
    {MouseMove;}
    {MouseOff;}
    MouseDisabled:=True;
    ClearInfo;
    ow:=Race[player];

    SetColor(White);
    OutTextXY(MX0,112-5*8,'Enter desired');
    OutTextXY(MX0,120-5*8,'minefield radius:');

    s := GetStr(MX0,128-5*8,3);
    Val(s,r,mn);
    ClearInfo;
    if mn=0 then
    begin

    OutTextXY(MX0,72,'Laying minefield');
    OutTextXY(MX0,80,'of '+NStr0(r)+' LY radius');

    for y:=1 to 10 do
    begin
      nt := r * r / ( (UnitsPerTorpRate[ow]/100.0)*longint(y)*longint(y));
      Str(nt:7:0,s);
      OutTextXY(MX0,88 + y*8,Torps[y].name+s);
    end;

    OutTextXY(MX0,96+80+8,'(using '+NStr(UnitsPerTorpRate[ow])+'% rate)');

    MoreInfoOnMinefield(96+80+8+16,r*r);
    MouseOff;
    SetViewPort(0,0,479,479,ClipOn);
    SetColor(DarkGray);
    DrawWCircle(MouseX,MouseY,long(r)*ratio2 div ratio1);
    SetViewPort(0,0,639,479,ClipOn);
    DrawMap(No);
    end;

    MouseDisabled:=False;
    MouseOn;

end;

procedure DrawMineCircle;
  var   r,y     : int;
        h       : sptr;
        id,t,n  : int;
        ow      : byte;
        nnn     : long;
        mi_race : int;

  begin
    h:=lship; id:=lock and LockLo;
    t:=10; n:=0;
    MouseMove;
    {MouseOff;}
    MouseDisabled:=True;
    ClearInfo;
    ow:=Race[player];
    if (h<>nil) and (h^.launchers>0) and (h^.Tl<>-1) then
    begin
      ow:=RealShipOwner(id);
      t:=h^.Tl;
      n:=Max(h^.TFnum,0);
      SetColor(cSInfo);
      OutTextXY(MX0,72,'Ship '+NStr(id)+' has');
      OutTextXY(MX0,80,NStr00(n,'no')+' '+Torps[t].name+' torps');
      y:=88;
      if Pos('|'+h^.fcode+'|','|mdh|mdq|md1|md2|md3|md4|md5|md6|md7|md8|md9|md0|')<>0 then
      begin
        OutTextXY(MX0,y,'and code "   "');
        WriteFCode(MX0+10*8,y,cSInfo,h^.fcode);
        y:=y+8;
        case h^.fcode[3] of
          'h'   : n:=n div 2;
          'q'   : n:=n div 4;
          '0'   : n:=Min(n,100);
          '1'..'9'      : n:=Min(n,(byte(h^.fcode[3])-ord('0'))*10);
        end;
      end;

      mi_race := pos(upcase(h^.fcode[3]), '123456789AB');
      if (h^.fcode[1]='m') and (h^.fcode[2]='i') and (mi_race<>0) then begin
        if UnitsPerTorpRate[mi_race] < UnitsPerTorpRate[ow] then
         ow := mi_race;
      end;
     { if ow=9 then OutTextXY(MX0,y,'and has 4X bonus');}
     OutTextXY(MX0,y,'(using '+NStr(UnitsPerTorpRate[ow])+'% rate)');

    end;
    SetColor(White);
    OutTextXY(MX0,112,'Enter torpedo');
    OutTextXY(MX0,120,'type and quantity:');
    NewMenu; UnLockReservedMemory(MenuSize(MX0+8,136,MX0+15*8,12,Yes));
    for y:=1 to 10 do AddMenuItem(Torps[y].name+'  '+NStr(IIF(y=t,n,0)),LightGray,No);
    AddMenuItem('------',LightGray,No);
    AddMenuItem('Units   '+NStr(0),LightGray,No);
    GetStrKey:=0;
    ChooseMenu(MX0+8,136,MX0+8,MX0+15*8,12,LightGray,Yellow,t,Yes,Yes,-1);
    NewMenu; LockReservedMemory;
    ClearInfo;
    MouseOff;
    n:=IIF(MenuData>0,MenuData,IIF(MenuValue=t,n,0));
    if (GetStrKey=13) and (n>0) then
    begin
      if MenuValue=12 then nnn:=trunc(n)         {Units Quapla}
      else nnn:=Trunc( (UnitsPerTorpRate[ow]/100.0)*long(MenuValue)*long(MenuValue)*n);
      r:=Round(Sqrt(nnn));
    {  SetColor(White);}
      if MenuValue=12 then OutTextXY(MX0,72,NStr0(n)+' units')
      else OutTextXY(MX0,72,NStr0(n)+' '+Torps[MenuValue].name+' torps');
      OutTextXY(MX0,80,'form a minefield');
      OutTextXY(MX0,88,'of '+NStr0(r)+' LY radius');
      OutTextXY(MX0,96,'('+NStr0(nnn)+' mine units)');
   {   if ow=9 then OutTextXY(MX0,104,'(using 4X bonus)');}
      OutTextXY(MX0,104,'(using '+NStr(UnitsPerTorpRate[ow])+'% rate)');

     { more info }
      MoreInfoOnMinefield(120,nnn);

      SetViewPort(0,0,479,479,ClipOn);
      SetColor(DarkGray);
      DrawWCircle(MouseX,MouseY,long(r)*ratio2 div ratio1);
      SetViewPort(0,0,639,479,ClipOn);
      DrawMap(No);
    end;
    MouseDisabled:=False;
    MouseOn;
  end;


procedure TimeShift (dt:int);
  var   bs      : boolean;
  begin
    if dt<>0 then
    begin
      if dt>0 then
      begin
        if TTurn^.next=nil then Exit
                           else SetTurn(TTurn^.next^.turn);
      end;
      if dt<0 then
      begin
        if TTurn^.prev=nil then Exit
                           else SetTurn(TTurn^.prev^.turn);
      end;
    end;
    WriteTurn(turn);
    DrawMap(Yes);
    if ltype=LockA then MouseMove;
    bs:=(ltype=LockP) and (lbase<>nil);
    if lock<>0 then
    begin
      InitObjList;
      force:=lock;
      MouseMove;
      if bs then lbase:=TTurn^.data^.base[force and LockLo];  {lock=0!}
      ForceKey:=13;
    end
    else WriteFreeMem;
  end;

procedure InputHull;
  var   i       : int;
  begin
    if (turn<>today) or (lship=nil) or
       (lship^.hull<>-1) or (lship^.owner=player) then Exit;
    i:=EnterHull(MX0-8,88,-1,Yes);
    if (i>0) and (HullFit(i,lship^.mass,lship^.mass)) then
    begin
      lship^.hull:=i;
      DataChg:=Yes;
      force:=lock;
      ForceKey:=13;
    end
  end;

procedure ForgetShip;
  begin
    with lship^ do
    begin
      if (turn<>today) or (lship=nil) or (hull=-1) or (mass=-1) or (owner=player) then Exit;
      hull:=-1;
      {if not HullFit(hull,mass1,mass2) then    <-- what's this? --sr }
      begin
        FillChar(name,20,$FF);
        mass1:=mass; mass2:=mass;
        FillChar(px1,4*2,$FF);
      end;
    end;
    DataChg:=Yes;
    force:=lock;
    ForceKey:=13;
  end;

procedure SetWarp;
  var   s       : string[4];
        ls      : byte absolute s;
        i       : int;
        number  : word;
  begin
    if (turn<>today) or (lship=nil) or
       (lship^.owner<>player) or (lship^.when<>turn) then Exit;
    number:=lock and LockLo;
    {MouseOff;}
    MouseDisabled:=True;
    {Clear(MX0+6*8,136,MX0+7*8+7,143);}
    s:=GetStr(MX0+6*8,136,1);
    if (ls=1) and (s[1] in ['0'..'9']) and (byte(s[1])<>lship^.warp+ord('0')) then
    begin
      DrawPath;
      i:=byte(s[1])-ord('0');
      lship^.warp:=i;
      {if i=0 then begin lship^.wx:=0; lship^.wy:=0 end;}
      ChangeData(Sh,number);
      SayFuel;
      DrawPath;
    end;
    SayMoving;
    MouseDisabled:=False;
    {MouseOn;}
  end;

procedure SetFCode (p_s:xtype; rnd:boolean);
  var   s,s0    : string[3];
        ls      : byte absolute s;
        rs      : fcstr;
        l0,k    : int;
        p       : pptr;
        h       : sptr absolute p;
        all     : boolean;
  begin
    if (turn<>today) or
      ((p_s=Sh) and ((lship=nil) or (lship^.when<>today) or (lship^.owner<>player))) or
      ((p_s=Pl) and ((lplan=nil) or (lplan^.when<>today) or (lplan^.owner<>player))) then Exit;
    all:=(KbdFlags and KbdCtrl<>0);
    if p_s=Sh then s0:=lship^.fcode else s0:=lplan^.fcode;
    l0:=IIF(p_s=Sh,168,112);
    if not rnd then
    begin
      {MouseOff;}
      MouseDisabled:=True;
      {Clear(MX0+7*8,l0,639,l0+7);}
      s:=GetStr(MX0+7*8,l0,3);
      MouseDisabled:=False;
      {MouseOn;}
    end
    else begin RandomFCode(rs); s:=rs end;
    if (ls<>0) and (s<>s0) then
    begin
      while ls<3 do s:=s+' ';
      for k:=1 to 999 do
      if (p_s=Sh) or (k<=500) then
      begin
        if p_s=Pl then p:=TTurn^.data^.planet[k]
                  else h:=TTurn^.data^.ship[k];
        if (p<>nil) and
           ( ((p_s=Pl) and (p^.when=today) and
              (all or (p=lplan)) and (p^.owner=player) and (p^.fcode=s0))
          or ((p_s=Sh) and (h^.when=today) and
             (all or (h=lship)) and (h^.owner=player) and (h^.fcode=s0)) ) then
        begin
          if p_s=Pl then Move(s[1],p^.fcode,3)
          else begin
            DrawPath;
            Move(s[1],h^.fcode,3);
            DrawPath;
          end;
          ChangeData(p_s,k);
{         if (p_s=Sh) and (h=lship) and HyperDrive and (IsShipFunc(h^,hfHyperDrive)) and
             (s='HYP') and (h^.warp<>1) then
          begin
            h^.warp:=1;
            if h=lship then SayMoving;
          end;}
        end;
      end;
    end
    else s:=s0;
    Move(s[1],rs,3);
    Clear(MX0+7*8,l0,639,l0+7);
    WriteFCode(MX0+7*8,l0,IIF(p_s=Sh,cSInfo,cPInfo),rs);
    if (p_s=Sh) then ShipInfo;
    if Addon.Unity or Addon.Teleport then begin force:=lock; ForceKey:=13; end; {Show changed Planets by Fcode - Quapla}
    if Addon.Teleport and showV and (p_s=Pl) then DrawMap(YES);   {Redraw Map and show new Teleport Connections}    
  end;

procedure RandAllPCodes;
  var   p,p0    : pptr;
        i       : int;
  begin
    if (turn<>today) or (lplan=nil) or (lplan^.when<>today) or (lplan^.owner<>player) then Exit;
    p0:=lplan;
    for i:=1 to 500 do
    begin
      p:=TTurn^.data^.planet[i];
      if (p<>nil) and (p^.when=today) and (p^.owner=player) and
         (p^.fcode<>'ATT') and (p^.fcode<>'NUK') and (Copy(p^.fcode,1,2)<>'mf') then
      begin
        lplan:=p;
        SetFCode(Pl,Yes)
      end;
    end;
    lplan:=p0;
    PlanetInfo;
  end;

procedure PBPInfo;
var i,j,col,clone:int;
    found:array[1..10] of int;
    fc:fcstr;
    s:string;
    p:pptr;
    b:bptr;
begin
  NewMenu;
  UnLockReservedMemory(MenuSize(MX0-112,378,631,9,Yes));
  fc[1]:='P';
  fc[2]:='B';
  for i:=1 to 9 do begin
    fc[3]:=chr((i mod 10)+48);
    found[i]:=0;
    s:='';
    col:=White;
    for j:=1 to NUM_PLANETS do begin
      p:=TTurn^.data^.planet[j];
      if ((p<>NIL) and (p^.owner=player) and (p^.fcode=fc)) then begin
        if (found[i]>0) then begin
          s:=s+' '+NStr(j);
          col:=Red;
        end else begin
          s:=NStr(j);
          found[i]:=j;
        end;
      end;
    end;
    if (col=Red) then s:='! '+s else begin
      if (found[i]>0) then begin
        b:=TTurn^.data^.base[found[i]];
        if ((b<>NIL) and (b^.owner=player)) then begin
          clone:=CheckClone(found[i]);
          if (PHOST and (clone>0) and (TTurn^.data^.ship[clone]<>NIL)) then begin
            s:=s+' cln '+Hulls[TTurn^.data^.ship[clone]^.hull].name
          end else begin
            if (b^.cHl>0) then
              s:=s+' '+Hulls[RaceHull[player,b^.cHl]].name
            else begin
              col:=Yellow;
              s:=s+' no order';
            end;
          end;
        end else begin
          col:=Yellow;
          s:=s+' no base';
        end;
      end;
    end;
    AddMenuItem(fc+' '+s,col,No);
  end;
  ChooseMenu(MX0-112,378,MX0-112,631,9,White,Yellow,1,No,Yes,-1);
  if (MenuKey<>27) then begin
    if (found[MenuValue]>0) then begin
      force:=found[MenuValue] or LockP;
      ForceKey:=13;
      lbase:=NIL;
    end else begin
      if ((ltype=LockP) and (lplan<>nil) and (lplan^.owner=player)) then begin
        fc[3]:=chr((MenuValue mod 10)+48);
        lplan^.fcode:=fc;
        for j:=1 to NUM_PLANETS DO
          if (TTurn^.data^.planet[j]=lplan) then
            ChangeData(Pl,j);
        if (lbase=nil) then begin
          Clear(MX0+7*8,112,639,112+7);
          WriteFCode(MX0+7*8,112,cPInfo,fc);
        end;
      end;
    end;
  end;
  NewMenu;
  LockReservedMemory;
end;

procedure SetName;
  var   s,s0    : string[20];
        ls      : byte absolute s;
  begin
    if (turn<>today) or (lship=nil) or
       (lship^.owner<>player) or (lship^.when<>today) then Exit;
    MouseDisabled:=True;
    s0:=lship^.name;
    s:=GetStr(MX0,96,20);
    if (ls<>0) and (s<>s0) then
    begin
      while ls<20 do s:=s+' ';
      Move(s[1],lship^.name,20);
      ChangeData(Sh,lock and LockLo);
    end;
    Clear(MX0,96,639,103);
    SetColor(LightGray);
    OutTextXY(MX0,96,lship^.name);
    ObjList;
    MouseDisabled:=False;
  end;

function ChooseMission (var misn:int; var md1,md2:boolean; sh:sptr; race:int; no_tow1,no_plan1:boolean;
                         x,y,x2:int; value1, value2 :long) : boolean;
  { enough memory must be freed already }
  { for ext.missions: I abd T values are stored in MenuData and MenuData2 }
  var   mis,mn  : int;
        s       : str20;
        ls      : byte absolute s;
        mp      : MITptr;
        i       : int;
        inter   : str40;
        hull    : int;
  label again, again2;
  begin
    ChooseMission:=No;
    mis:=IIF(misn<=15,misn,0);
    hull:=sh^.hull; { FIXME: too indirect }
    NewMenu;
    for i:=1 to 15 do
    begin
      ls:=0;
      if (not DullMissions) and
       ( ( (not IsMines) and ((i=2) or (i=3)) ) or
         ( ((i=3) or ((i=9) and (race=7))) and (Hulls[hull].launchers=0) ) or
         ( (i=7) and (no_tow1 or
           ((not OneEngineTow) and (Hulls[hull].engines<2))) ) or
         ( (i=9) and (((race=1) and ((not SuperRefit) or no_plan1)) or
                     ((race=2) and no_plan1) or
                     ((race=9) and not RobFBuild) or
                     ((race=10) and not RGA) or
                     ((race=11) and not ColFBuild)) ) or
         ( (i=9) and ((race=9) or (race=11)) and (Hulls[hull].bays=0) ) or
         ( (i=9) and (race in [2,4,5]) and (Hulls[hull].weapons=0) ) or
         ( (i in [11..15]) and no_plan1 )
       ) then begin end else
      if (i=10) and ((not IsShipFunc(sh^,hfCloak)) and { HF-FIXME }
                     (not IsShipFunc(sh^,hfAdvCloak))) then begin end else
      if i=9 then s:=SpecMisn[race]
             else s:=Missions[i];
      AddMenuItem(s,cSInfo,No);
    end;
    mn:=15;
    mp:=MIT;
    while mp<>nil do
    begin
      if mp^.param and (1 shl race)<>0 then
      begin
        if (mn=15)and(AllowExtendedMissions) then
        begin
          AddMenuItem('Ext. Misn.',cSInfo,No);
          inc(mn);
        end;
        if misn=mp^.mission then mis:=16;
      end;
      mp:=mp^.next;
    end;
    ChooseMenu(x,y,x2,x+17*8-1,mn,cSInfo,Yellow,mis,No,No,-1);
    NewMenu;
    repeat
      if MenuKey=27 then Break;
      mis:=MenuValue;
      md1:=No; md2:=No;
      if (mis=16)and(AllowExtendedMissions) then
      begin
        Clear(x,y,x+17*8-1,y+16*8-1);
        mn:=0; mis:=1;
        mp:=MIT;
        while mp<>nil do
        begin
          if mp^.param and (1 shl race)<>0 then
          begin
            AddMenuItem(mp^.name,cSInfo,No);
            inc(mn);
            if misn=mp^.mission then mis:=mn;
          end;
          mp:=mp^.next;
        end;
        ChooseMenu(x,y,x,x+17*8-1,16,cSInfo,Yellow,mis,No,No,-1);
        NewMenu;
        if MenuKey=27 then Break;
        mis:=MenuValue;
        mn:=0;
        mp:=MIT;
        while mp<>nil do
        begin
          if mp^.param and (1 shl race)<>0 then
          begin
            inc(mn);
            if mn=mis then Break;
          end;
          mp:=mp^.next;
        end;
        if mp=nil then Break;
        mis:=mp^.mission;
        md1:=mp^.param and MIT_I<>0;
        md2:=mp^.param and MIT_T<>0;
        if md1 or md2 then
        begin
          Clear(x,y,x+17*8-1,y+16*8-1);
          SetColor(Yellow);
          OutTextXY(x,y,mp^.name);
          SetColor(cSInfo);
          if md1 then
          begin
            SetColor(cSInfo);
            OutTextXY(x,y+16,mp^.iname+' =');
            if (misn = mis) then inter := NStr0(value2)
                            else inter := '';
           again:
            s:=GetStrMore(x+(byte(mp^.iname[0])+3)*8,y+16,5,inter);
            if ls=0 then Break
            else begin
              Val(s,MenuData,mn);
              if (mn<>0) or (MenuData<0) or (MenuData>10000) then begin
                inter:=s;
                goto again;
              end;
            end;
          end;
          if md2 then
          begin
            SetColor(cSInfo);
            OutTextXY(x,y+24,mp^.tname+' =');
            if (misn = mis) then inter := NStr0(value1)
                            else inter := '';
           again2:
            s:=GetStrMore(x+(byte(mp^.tname[0])+3)*8,y+24,5,inter);
            if ls=0 then Break
            else begin
              Val(s,MenuData2,mn);
              if (mn<>0) or (MenuData2<0) or (MenuData2>10000) then begin
                inter:=s;
                goto again2;
              end;
            end;
          end;
        end;
      end;
      misn:=mis;
      ChooseMission:=Yes;
    until True;
  end;

procedure SetMission;
  var   number  : word;
        mis     : int;
        md1,md2 : boolean;
        xx0,yy0 : int;
        mx,my   : int;
        dd,nd   : long;
        xx,yy   : int;
        gmt     : boolean;
        h       : sptr;
        i       : word; { word! }
        orace   : word;
  begin
    if (turn<>today) or (lship=nil) or
       (lship^.owner<>player) or (lship^.when<>today) then Exit;
    number:=lock and LockLo;
    MouseDisabled:=True;
    UnLockReservedMemory(MenuSize(MX0,192,MX0+17*8-1,16,No));
    mis:=lship^.mission;
    md1:=No; md2:=No;
    orace := Race[RealShipOwner(number)];
    gmt:=ChooseMission(mis,md1,md2,lship,orace,(ShipN<2),(PlanN=0),MX0,192,MX0+6*8-8,lship^.tow_ship,lship^.intr_ship);
    LockReservedMemory;
    if gmt then
    repeat
			if (mis<>lship^.mission) and ((mis=9) or (lship^.mission=9)) then GSOP[1]:=0;
				{Reset GetShipsOverPlanet, Ships will be recalculated}
      if mis=7 then
      begin
        Clear(MX0,ListY,639,ListY+7);
        SetColor(Yellow);
        OutTextXY(MX0,ListY,'Tow ship:');
        MenuData2:=SelectShip(lx,ly,No,No);
        if MenuData2=0 then Break;
        md2:=Yes;
      end;
      if mis=8 then
      begin
        if not (showS or showE) then Break;
        Clear(MX0,ListY,639,479);
        SetColor(Yellow);
        OutTextXY(MX0,ListY+2*8,'Select target ship');
        xx0:=MouseX; yy0:=MouseY;
        gmt:=MouseGetTarget(0,0,No);
        if gmt then
        begin
          nd:=1000000000;
          for i:=1 to 999 do
          begin
            h:=TTurn^.data^.ship[i];
            if (h<>nil) and (h^.when=turn) and
              ((showS and (h^.owner=player)) or (showE and (h^.owner<>player))) then
            begin
              dd:=Distance2(mmx,mmy,h^.x,h^.y);
              if dd<nd then begin nd:=dd; xx:=h^.x; yy:=h^.y end;
            end;
          end;
          if nd<>1000000000 then
          begin
            Abs2Scr(xx,yy,mx,my);
            MoveMouseTo(mx,my); WriteCoord;
            SetColor(Yellow);
            OutTextXY(MX0,ListY,'Intercept ship:');
            MenuData:=SelectShip(xx,yy,No,No);
            if MenuData=0 then Break;
            md1:=Yes;
          end;
        end;
        MoveMouseTo(xx0,yy0);
        if not gmt then Break;
      end;
      with lship^ do
      begin
        if (mis<>mission) or
           (md1 and (intr_ship<>MenuData)) or
           (md2 and (tow_ship<>MenuData2)) then
        begin
          mission:=mis;
          intr_ship:=IIF(md1,MenuData,0);
          tow_ship:=IIF(md2,MenuData2,0);
          ChangeData(Sh,number);
          if mis=8 then
          begin
            DrawPath;
            wx:=xx-x;
            wy:=yy-y;
            if showT then DrawMap(Yes) else DrawPath;
          end;
        end;
      end;
    until True;
    Clear(MX0-8,192-8,MX0-1,192+20*8+7);
    ShipInfo;
    MouseDisabled:=False;
  end;

function ChooseEnemy (var en:int; x,y,x2:int) : boolean;
  { enough memory must be freed already }
  var   i       : byte;
  begin
    NewMenu;
    AddMenuItem('None',cSInfo,No);
    for i:=1 to 11 do AddMenuItem(RaceName[i],cSInfo,No);
    ChooseMenu(x,y,x2,x+17*8-1,12,cSInfo,Yellow,en+1,No,Yes,-1);
    NewMenu;
    ChooseEnemy:=(MenuKey<>27);
    en:=MenuValue-1;
  end;

procedure SetEnemy;
  var   en,yy   : int;
  begin
    if (turn<>today) or (lship=nil) or
       (lship^.owner<>player) or (lship^.when<>today) then Exit;
    MouseDisabled:=True;
    en:=lship^.enemy;
    yy:=200+IIF(lship^.mission>15,8,0);
    UnLockReservedMemory(MenuSize(MX0,yy,631,12,Yes));
    if ChooseEnemy(en,MX0,yy,MX0+7*8-8) and (en<>lship^.enemy) then
    with lship^ do
    begin
      enemy:=en;
      ChangeData(Sh,lock and LockLo);
      Clear(MX0+56,yy,639,207);
      SetColor(cSInfo);
      OutTextXY(MX0+56,yy,RaceName[enemy]);
    end;
    LockReservedMemory;
    MouseDisabled:=False;
  end;

function UnloadShip (id:int) : boolean;
  var   h       : sptr;
        p       : pptr;
        pn      : int;
  begin
    UnloadShip:=No;
    h:=TTurn^.data^.ship[id];
    with h^ do
    begin
      if (turn<>today) or (h=nil) or (owner<>player) or (when<>today) or
         (T+D+M+Sup+IIF(Gambling and (IsShipFunc(h^,hfGambling)),0,colonists)+credits=0) then Exit;
      pn:=splan[id];
      if pn=0 then Exit;
      p:=TTurn^.data^.planet[pn];
      if (p=nil) or (p^.when<>today) or (p^.owner<>player) then Exit;
      inc(p^.T,T); T:=0;
      inc(p^.D,D); D:=0;
      inc(p^.M,M); M:=0;
      inc(p^.supplies,Sup); Sup:=0;
      if (not Gambling) or (hull<>42) then
        begin inc(p^.colonists,colonists); colonists:=0 end;
      inc(p^.funds,credits); credits:=0;
      SetShipMass(h^);
      ChangeData(Sh,id);
      ChangeData(Pl,pn);
      UnloadShip:=Yes;
      if (ltype=LockS) and (h=lship) then ShipInfo;
    end;
  end;

procedure UnloadAllShips;
  var   i,x,y   : int;
        was     : boolean;
  begin
    if (turn<>today) or (lplan=nil) or (lplan^.when<>today) or (lplan^.owner<>player) then Exit;
    with TTurn^.data^ do
    begin
      x:=xyplan[PlanN,1];
      y:=xyplan[PlanN,2];
    end;
    was:=No;
    for i:=1 to 999 do
      if ShipIsHere(i,x,y) then was:=UnloadShip(i) or was; { U or was! not the reverse!! }
    if was then PlanetInfo;
  end;

procedure LoadForBuild;                                         { M.O.T.}
  var   i,cost  : int;
        p       : pptr;
        real_race : int;
  procedure HowMany (fgt:boolean);
    var s       : string[10];
        ch      : word;
        n       : int;
    begin
      Clear(MX0,CY0+80,639,CY0+88+7);
      SetColor(cSInfo);
      OutTextXY(MX0,CY0+80,'Build how many');
      if fgt then s:='fighters?' else s:='torpedoes?';
      OutTextXY(MX0,CY0+88,s);
      SetLineStyle(SolidLn,0,NormWidth);
      n:=0;
      repeat
        Clear(640-4*8,CY0+88,639,CY0+88+7);
        SetColor(cSInfo);
        OutTextXY(640-4*8,CY0+88,NStr0(n));
        SetColor(Yellow);
        Line(640-4*8,CY0+88+7,640-4*8+23,CY0+88+7);
        repeat ArrowBlink(640-4*8-3*8,CY0+88) until KeyPressed;
        SetColor(Black);
        Line(640-4*8,CY0+88+7,640-4*8+23,CY0+88+7);
        ch:=ReadKey;
        case ch of
          $4B00 : n:=IIF(KbdFlags and KbdShft=0,Max(n-1,0),0);
          $4D00 : n:=IIF(KbdFlags and KbdShft=0,Min(n+1,i),i);
          $7300 : n:=Max(n-10,0);
          $7400 : n:=Min(n+10,i);
          $9B00 : n:=Max(n-100,0);
          $9D00 : n:=Min(n+100,i);
          ord('0')..ord('9')    : begin
                    GetStr1stKey:=ch;
                    s:=GetStr(640-4*8,CY0+88,3);
                    if GetStrKey=13 then n:=Min(Max(Value(s),0),i);
                  end;
          $3B00 : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
        end;
      until (ch=13) or (ch=27);
      i:=n;
    end;
  begin
    real_race := Race[RealShipOwner(lock and LockLo)];
    with lship^ do
    begin
      if (turn<>today) or (lship=nil) or (owner<>player) or (when<>today) or (PlanN=0) then Exit;
      p:=TTurn^.data^.planet[PlanN];
      if (p=nil) or (p^.when<>today) or (p^.owner<>player) then Exit;
      i:=Hulls[hull].cargo-T-D-M-Sup-colonists-TFnum;
      if (bays>0) and (real_race in [9..11]) then
      begin
        if ((real_race=9) and not RobFBuild) or ((real_race=11) and not ColFBuild) then Exit;
        if (i<10) or (p^.T<3) or (p^.M<2) or (p^.supplies<5) then Exit;
        i:=MinL(MinL(Min(p^.T div 3,p^.M div 2),p^.supplies div 5),i div 10);
        HowMany(Yes);
        if i=0 then begin ShipInfo; Exit end;
        inc(T,i*3); dec(p^.T,i*3);
        inc(M,i*2); dec(p^.M,i*2);
        inc(Sup,i*5); dec(p^.supplies,i*5);
        if (real_race<>10) and (fcode<>'lfm') then mission:=9;
      end else
      if launchers>0 then
      begin
        cost:=Torps[Tl].cost;
        if (i<3) or (p^.T=0) or (p^.D=0) or (p^.M=0) or
           (10000-credits<cost) or (p^.funds+p^.supplies<cost) then Exit;
        i:=MinL(MinL(MinL(MinL(MinL(p^.T,p^.D),p^.M),(p^.funds+p^.supplies) div cost),i div 3),(10000-credits) div cost);
        HowMany(No);
        if i=0 then begin ShipInfo; Exit end;
        inc(T,i); dec(p^.T,i);
        inc(D,i); dec(p^.D,i);
        inc(M,i); dec(p^.M,i);
        inc(credits,i*cost); dec(p^.funds,i*cost);
        if p^.funds<0 then begin inc(p^.supplies,p^.funds); p^.funds:=0 end;
        fcode:='mkt';
      end
      else Exit;
    end;
    SetShipMass(lship^);
    ChangeData(Sh,lock and LockLo);
    ChangeData(Pl,PlanN);
    ShipInfo;
  end;

procedure ChgSupplies (amt:long);
  begin
    with lplan^ do
    begin
      inc(supplies,amt);
      ChangeData(Pl,lock and LockLo);
      Clear(MX0+10*8,256,639,263);
      SetColor(cPInfo);
      OutTextXY(MX0+10*8,256,NStr0(supplies));
    end
  end;

procedure ChgFunds (amt:long);
  begin
    with lplan^ do
    begin
      inc(funds,amt);
      ChangeData(Pl,lock and LockLo);
      Clear(MX0+10*8,264,639,271);
      SetColor(cPInfo);
      OutTextXY(MX0+10*8,264,NStr0(funds));
    end
  end;

procedure SellSupplies (amt:long);
  begin
    ChgSupplies(-amt);
    ChgFunds(amt);
  end;

function SoldSupp (id:int) : long;
  var   i       : int;
        dsupp   : long;
  begin
    i:=PDSearch(id);    { MUST be i<>0 }
    with PDis^[i] do dsupp:=supplies+mines+factories+defense;
    with TTurn^.data^.planet[id]^ do dec(dsupp,supplies+mines+factories+defense);
    for i:=1 to 999 do
      if splan[i]=id then
        with TTurn^.data^.ship[i]^ do
        if owner=player then dec(dsupp,Sup+CS+TS);
    SoldSupp:=dsupp;
  end;

procedure BuildStructures (mfd:MFDtype);                        { M.O.T.}
  type  MFDarr  = array [MFDtype] of int;
  var   mfdpp   : pointer;
        mfdp    : ^MFDarr absolute mfdpp;
        mfd0,mfd1       : MFDarr;
        ch      : word;
        x,y,k   : int;
        s       : string[3];
        mf      : MFDtype;
        suppsold,l      : long;
  procedure PutNum;
    begin
      Clear(x,y,x+3*8-1,y+7);
      SetColor(cpInfo);
      Str(mfdp^[mfd]:3,s);
      OutTextXY(x,y,s);
    end;
  procedure BuildStruct (amt:long);
    begin
      amt:=Min(Max(amt+mfdp^[mfd],mfd0[mfd]),mfd1[mfd])-mfdp^[mfd];
      if amt=0 then Exit;
      with lplan^ do
      begin
        amt:=MinL(MinL(amt,supplies),(funds+supplies) div (mfdCost[mfd]+1));
        if amt=0 then Exit;
        ChgSupplies(-amt); ChgFunds(-amt*mfdCost[mfd]);
        if amt>0 then
        begin
          if funds<0 then
          begin
            dec(suppsold,funds);        { funds<0 here }
            SellSupplies(-funds);
          end;
        end
        else if suppsold>0 then
        begin
          l:=MinL(suppsold,funds);
          dec(suppsold,l);
          SellSupplies(-l);
        end;
        inc(mfdp^[mfd],amt);
        ChangeData(Pl,lock and LockLo);
        if mfd=_Mine then WriteMiningRate;
        if mfd=_Defense then WritePlanCombatStrength(PlanetID(lplan));
        if mfd<>_Defense then
        begin
          if Nrace<>0 then WriteHChange(Yes);
          WriteHChange(No);
        end;
      end;
    end;
  begin
    if (turn<>today) or (lplan=nil) or (lplan^.when<>today) or (lplan^.owner<>player) then Exit;
    with lplan^ do
    begin
      mfdpp:=Addr(mines);
      k:=PDSearch(lock and LockLo);             { MUST be k<>0 }
      Move(PDis^[k].mines,mfd0,SizeOf(MFDarr));
      for mf:=_Mine to _Defense do
      begin
        if colonists<=mfdFNum[mf] then mfd1[mf]:=colonists
        else mfd1[mf]:=Round(Sqrt(colonists-mfdFNum[mf]))+mfdFNum[mf];
        mfd1[mf]:=Max(mfd0[mf],mfd1[mf]); { mfd1 must be >= mfd0 }
      end;
    end;
    suppsold:=SoldSupp(lock and LockLo);
    {MouseOff;}
    MouseDisabled:=True;
    SetLineStyle(SolidLn,0,NormWidth);
    x:=MX0+11*8;
    y:=224+byte(mfd)*8;
    Clear(x-2*8,224,x-1,224+3*8-1);
    repeat
      PutNum;
      SetColor(Yellow);
      Line(x,y+7,x+23,y+7);
      repeat ArrowBlink(x-2*8,y) until KeyPressed;
      SetColor(Black);
      Line(x,y+7,x+23,y+7);
      ch:=ReadKey;
      case ch of
        $4800   : begin
                    Clear(x-2*8,y,x-1,y+7);
                    if mfd=_Mine then mfd:=_Defense else dec(mfd);
                    y:=224+byte(mfd)*8;
                  end;
        $5000   : begin
                    Clear(x-2*8,y,x-1,y+7);
                    if mfd=_Defense then mfd:=_Mine else inc(mfd);
                    y:=224+byte(mfd)*8;
                  end;
        $4B00   : if KbdFlags and KbdShft=0 then BuildStruct(-1)
                                            else BuildStruct(mfd0[mfd]-mfdp^[mfd]);
        $4D00   : if KbdFlags and KbdShft=0 then BuildStruct(1)
                                            else BuildStruct(mfd1[mfd]-mfdp^[mfd]);
        $7300   : BuildStruct(-10);
        $7400   : BuildStruct(10);
        $9B00   : BuildStruct(-100);
        $9D00   : BuildStruct(100);
        ord('0')..ord('9')      : begin
                    GetStr1stKey:=ch;
                    s:=GetStr(x,y,3);
                    if GetStrKey=13 then
                    begin
                      k:=Min(Max(Value(s),mfd0[mfd]),mfd1[mfd]);
                      BuildStruct(k-mfdp^[mfd]);
                    end;
                  end;
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
      end;
    until (ch=13) or (ch=27);
    PlanetInfo;
    MouseDisabled:=False;
    {MouseOn;}
  end;

procedure SellSupp;                                             { M.O.T.}
  var   x,y     : int;
        k,sp0,ds: long;
        s       : string[6];
        ch      : word;
        spp     : pointer;
        sp      : ^long absolute spp;
  begin
    if (turn<>today) or (lplan=nil) or (lplan^.when<>today) or (lplan^.owner<>player) then Exit;
    spp:=Addr(lplan^.supplies);
    sp0:=sp^+MinL(SoldSupp(lock and LockLo),lplan^.funds);
    {MouseOff;}
    MouseDisabled:=True;
    SetLineStyle(SolidLn,0,NormWidth);
    x:=MX0+10*8;
    y:=256;
    repeat
      ds:=sp0-sp^;
      Clear(x,y,x+6*8-1,y+7);
      SetColor(cpInfo);
      OutTextXY(x,y,NStr0(lplan^.supplies));
      SetColor(Yellow);
      Line(x,y+7,x+47,y+7);
      repeat ArrowBlink(640-2*8,y) until KeyPressed;
      SetColor(Black);
      Line(x,y+7,x+47,y+7);
      ch:=ReadKey;
      case ch of
        $4B00   : if KbdFlags and KbdShft=0 then SellSupplies(-MinL(1,ds))
                                            else SellSupplies(-ds);
        $4D00   : if KbdFlags and KbdShft=0 then SellSupplies(MinL(1,sp^))
                                            else SellSupplies(sp^);
        $7300   : SellSupplies(-MinL(10,ds));
        $7400   : SellSupplies(MinL(10,sp^));
        $9B00   : SellSupplies(-MinL(100,ds));
        $9D00   : SellSupplies(MinL(100,sp^));
        ord('0')..ord('9')      : begin
                    GetStr1stKey:=ch;
                    s:=GetStr(x,y,6);
                    if GetStrKey=13 then
                    begin
                      k:=MinL(MaxL(Value(s),0),sp0);
                      SellSupplies(sp^-k);
                    end;
                  end;
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
      end;
    until (ch=13) or (ch=27);
    PlanetInfo;
    MouseDisabled:=False;
    {MouseOn;}
  end;

procedure BuildBase;
  var sbc : TFullPrice;
  begin
    if (turn<>today) or (lplan=nil) then Exit;
    with lplan^ do
    begin
      if (when<>today) or (owner<>player) or
         (TTurn^.data^.eplan[lock and LockLo].activity and 128<>0) or (build=1) or
         not PlanetCanBuildBase(lplan) then Exit;
      GetBaseCost(owner, sbc);
      dec(T,sbc.Tri);
      dec(D,sbc.Dur);
      dec(M,sbc.Mol);
      dec(supplies,sbc.Supplies);
      dec(funds,sbc.MC);
      if funds<0 then SellSupplies(-funds);
      build:=1;
      ChangeData(Pl,lock and LockLo);
      with TTurn^.data^.eplan[lock and LockLo] do activity:=activity or 128;
      DrawMap(No);
    end;
    PlanetInfo;
  end;

procedure CancelBase;
  var   sbc     : TFullPrice;
  begin
    if (turn<>today) or (lplan=nil) then Exit;
    with lplan^ do
    begin
      if (when<>today) or (owner<>player) or (build=0) then Exit;
      GetBaseCost(owner, sbc);
      inc(T,sbc.Tri);
      inc(D,sbc.Dur);
      inc(M,sbc.Mol);
      inc(funds,sbc.MC);
      inc(supplies,sbc.Supplies);
      build:=0;
      ChangeData(Pl,lock and LockLo);
      with TTurn^.data^.eplan[lock and LockLo] do activity:=activity and 127;
      DrawMap(No);
    end;
    PlanetInfo;
  end;

procedure IncreaseBaseDefense;                                  { M.O.T.}
  var   ch      : word;
        bd0     : int;
        bdp     : pointer;
        bd      : ^int absolute bdp;
        x,y,k   : int;
        suppsold,l      : long;
        s       : string[3];
        b       : BRec;
  procedure WriteRes;
    begin
      Clear(x,y,639,112+7);
      SetColor(cBInfo);
      OutTextXY(x,y,NStr(lbase^.defense));
      OutTextXY(x,104,NStr(lplan^.D));
      OutTextXY(x,112,NStr(lplan^.funds+lplan^.supplies));
    end;
  procedure BuildBDef (amt:long);
    begin
      amt:=Min(Max(amt+bd^,bd0),GetMaxDefenseOnBase(lplan^.owner))-bd^;
      if amt=0 then Exit;
      with lplan^ do
      begin
        amt:=MinL(MinL(amt,D),(funds+supplies) div 10);
        if amt=0 then Exit;
        dec(D,amt);
        dec(funds,amt*10);
        if amt>0 then
        begin
          if funds<0 then
          begin
            dec(suppsold,funds);        { funds<0 here }
            inc(supplies,funds);
            funds:=0;
          end;
        end
        else if suppsold>0 then
        begin
          l:=MinL(suppsold,funds);
          dec(suppsold,l);
          inc(supplies,l);
          dec(funds,l);
        end;
        inc(lbase^.defense,amt);
        ChangeData(Pl,PlanN);
        ChangeData(Ba,PlanN);
      end;
    end;
  begin
    if (turn<>today) or (lbase=nil) or (lbase^.owner<>player) or
       (lplan=nil) or (lplan^.owner<>player) then Exit;
    bdp:=Addr(lbase^.defense);
    {bd0:=bd^;}
    LoadBDis(lock and LockLo,b);
    bd0:=b.defense;
    suppsold:=SoldSupp(lock and LockLo);
    {MouseOff;}
    MouseDisabled:=True;
    SetLineStyle(SolidLn,0,NormWidth);
    x:=MX0+11*8; y:=96;
    Clear(x-2*8,y,639,y+7);
    Clear(MX0,104,639,112+7);
    SetColor(cBInfo);
    OutTextXY(MX0,104,'Du:');
    OutTextXY(MX0,112,'mc+sup:');
    repeat
      WriteRes;
      SetColor(Yellow);
      Line(x,y+7,x+23,y+7);
      repeat ArrowBlink(x-2*8,y) until KeyPressed;
      SetColor(Black);
      Line(x,y+7,x+23,y+7);
      ch:=ReadKey;
      case ch of
        $4B00   : if KbdFlags and KbdShft=0 then BuildBDef(-1)
                                            else BuildBDef(bd0-bd^);
        $4D00   : if KbdFlags and KbdShft=0 then BuildBDef(1)
                                            else BuildBDef(GetMaxDefenseOnBase(lplan^.owner)-bd^);
        $7300   : BuildBDef(-10);
        $7400   : BuildBDef(10);
        $9B00   : BuildBDef(-100);
        $9D00   : BuildBDef(100);
        ord('0')..ord('9')      : begin
                    GetStr1stKey:=ch;
                    s:=GetStr(x,y,3);
                    if GetStrKey=13 then
                    begin
                      k:=Min(Max(Value(s),bd0),GetMaxDefenseOnBase(lplan^.owner));
                      BuildBDef(k-bd^);
                    end;
                  end;
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
      end;
    until (ch=13) or (ch=27);
    BaseInfo;
    MouseDisabled:=False;
    {MouseOn;}
  end;

procedure SetBaseOrder;
  var   i       : byte;
  begin
    if (turn<>today) or (lbase=nil) or (lbase^.owner<>player) then Exit;
    {MouseOff;}
    MouseDisabled:=True;
    NewMenu; UnLockReservedMemory(MenuSize(MX0,136,631,6,Yes));
    for i:=1 to 6 do AddMenuItem(BaseOrd[i],cBInfo,No);
    ChooseMenu(MX0,136,MX0,631,6,cBInfo,Yellow,lbase^.order,No,Yes,-1);
    NewMenu; LockReservedMemory;
    with lbase^ do
    if (MenuKey<>27) and (MenuValue<>order) then
    begin
      order:=MenuValue;
      ChangeData(Ba,lock and LockLo);
      Clear(MX0+8,128,639,128+7);
      SetColor(cBInfo);
      OutTextXY(MX0+8,128,BaseOrd[order]);
    end;
    MouseDisabled:=False;
    {MouseOn;}
  end;

function TFBuilt (id:int; tlv:byte) : int;
  var   k       : int;
        dtf     : int;
  begin
    k:=BDSearch(id);            { MUST be k<>0 }
    with TTurn^.data^.base[id]^ do
    begin
      dtf:=IIF(tlv=0,fighters,TT[tlv])-BDis^[k].TF[tlv];
    end;
    for k:=1 to 999 do
      if splan[k]=id then
        with TTurn^.data^.ship[k]^ do
        if (owner=player) and (Tl=tlv) then inc(dtf,TFnum);
    TFBuilt:=dtf;
  end;

procedure BuyTF (y0:int; c:byte; tlv:byte; limit:int; var TFn:int; xt:xtype; xn:word);
                { tlv = 1..10 for torps, 0 for fighters }       { M.O.T.}
                { use limit=30000 for torps on base }
  var   p       : pptr;                                 { MOT interface }
        ch      : word;
        l,x,k   : int;
        costT,costD,costM,costC,costS : int;
        tf0     : int;
        suppsold,sl     : long;
        s       : string[40];
        cost    : TFullPrice;
  procedure WriteBTFs;
    begin
      Clear(MX0+10*8,y0+8,639,l+8+7);
      Clear(x,l+24,639,l+32+7);
      SetColor(c);
      OutTextXY(MX0+10*8,y0+8,NStr(p^.T));
      if tlv>0 then OutTextXY(MX0+10*8,y0+16,NStr(p^.D));
      OutTextXY(MX0+10*8,l,NStr(p^.M));
      OutTextXY(MX0+10*8,l+8,NStr(p^.funds+p^.supplies));
      if limit<30000 then OutTextXY(x,l+24,NStr(limit-TFn));
      OutTextXY(x,l+32,NStr(TFn));
    end;
  procedure BuyIt (amt:long);
    begin
      amt:=MinL(MaxL(amt+TFn,tf0),limit)-TFn;
      if amt=0 then Exit;
      with p^ do
      begin
        if costT>0 then amt:=MinL(amt,T div costT);
        if costD>0 then amt:=MinL(amt,D div costD);
        if costM>0 then amt:=MinL(amt,M div costM);
        if costS>0 then amt:=MinL(amt,supplies div costS);
        if costC>0 then amt:=MinL(amt,(funds+supplies) div (costC+costS));
        if amt=0 then Exit;
        dec(T,amt*costT);
        dec(D,amt*costD);
        dec(M,amt*costM);
        dec(supplies,amt*costS);
        dec(funds,amt*costC);
        if amt>0 then
        begin
          if funds<0 then
          begin
            dec(suppsold,funds);        { funds<0 here }
            inc(supplies,funds);
            funds:=0;
          end;
        end
        else if suppsold>0 then
        begin
          sl:=MinL(suppsold,funds);
          dec(suppsold,sl);
          inc(supplies,sl);
          dec(funds,sl);
        end;
        inc(TFn,amt);
        ChangeData(Pl,PlanN);
        ChangeData(xt,xn);
      end;
    end;
  begin
    if (turn<>today) or (PlanN=0) or (TTurn^.data^.base[PlanN]=nil) then Exit;
    p:=TTurn^.data^.planet[PlanN];
    if (p=nil) or (p^.owner<>player) then Exit;
    Clear(MX0,y0,639,y0+88+7);
    SetColor(c);
    OutTextXY(MX0,y0,'Base resources:');
    OutTextXY(MX0,y0+8,'  Tr:');
    if tlv>0 then
    begin
      costT:=1; costD:=1; costM:=1; costC:=Torps[tlv].cost; costS:=0;
      OutTextXY(MX0,y0+16,'  Du:');
      l:=y0+24;
      OutTextXY(MX0,y0+24+32,'Torpedoes:');
      OutTextXY(MX0,y0+24+48,'1 '+Torps[tlv].name+' torpedo =');
      OutTextXY(MX0,y0+24+56,' 1Tr+1Du+1Mo+'+NStr0(costC)+'mc');
    end
    else begin
      GetFighterCost(p^.owner,cost);
      costT:=cost.Tri; costD:=cost.Dur; costM:=cost.Mol; costC:=cost.MC; costS:=cost.Supplies;
      l:=y0+16;
      OutTextXY(MX0,y0+16+32,'Fighters:');
      OutTextXY(MX0,y0+16+48,'1 fighter =');
      s:='';
      if costT>0 then s:=s+'+'+NStr0(costT)+'Tr';
      if costD>0 then s:=s+'+'+NStr0(costD)+'Du';
      if costM>0 then s:=s+'+'+NStr0(costM)+'Mo';
      if costC>0 then s:=s+'+'+NStr0(costC)+'mc';
      if costS>0 then s:=s+'+'+NStr0(costS)+'Su';
      if s='' then s:=' free!' else s[1]:=' ';
      OutTextXY(MX0,y0+16+56,s);
    end;
    OutTextXY(MX0,l,'  Mo:');
    OutTextXY(MX0,l+8,'  mc+sup: ');
    if limit<30000 then OutTextXY(MX0,l+24,'Cargo room:');
    {tf0:=TFn;}
    tf0:=Max(TFn-TFBuilt(PlanN,tlv),0);
    suppsold:=SoldSupp(PlanN);
    SetLineStyle(SolidLn,0,NormWidth);
    x:=MX0+14*8;
    repeat
      WriteBTFs;
      SetColor(Yellow);
      Line(x,l+32+7,x+23,l+32+7);
      repeat ArrowBlink(x-2*8,l+32) until KeyPressed;
      SetColor(Black);
      Line(x,l+32+7,x+23,l+32+7);
      ch:=ReadKey;
      case ch of
        $4B00   : if KbdFlags and KbdShft=0 then BuyIt(-1)
                                            else BuyIt(tf0-TFn);
        $4D00   : if KbdFlags and KbdShft=0 then BuyIt(1)
                                            else BuyIt(limit-TFn);
        $7300   : BuyIt(-10);
        $7400   : BuyIt(10);
        $9B00   : BuyIt(-100);
        $9D00   : BuyIt(100);
        ord('0')..ord('9')      : begin
                    GetStr1stKey:=ch;
                    s:=GetStr(x,l+32,4);
                    if GetStrKey=13 then
                    begin
                      k:=Min(Max(Value(s),tf0),limit);
                      BuyIt(k-TFn);
                    end;
                  end;
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
      end;
    until (ch=13) or (ch=27);
  end;

procedure BuyShipTF;
  var   b       : bptr;
        p       : pptr;
        free    : int;
  begin
    if (turn<>today) or (lship=nil) or (PlanN=0) then Exit;
    with lship^ do
    begin
      if (owner<>player) or (when<>today) or (bays or launchers=0) then Exit;
      p:=TTurn^.data^.planet[PlanN];
      b:=TTurn^.data^.base[PlanN];
      if (p=nil) or (p^.owner<>player) or (b=nil) then Exit;
      if (launchers>0) and (b^.Tl<Torps[Tl].tech) then
      begin
        Clear(MX0+9*8,CY0+64,639,CY0+64+7);
        SetColor(LightRed);
        OutTextXY(MX0+9*8,CY0+64,'Low tech!');
        Exit;
      end;
      free:=Hulls[hull].cargo-colonists-Sup-T-D-M;
      if free<=0 then
      begin
        Clear(MX0+9*8,CY0+64,639,CY0+64+7);
        SetColor(LightRed);
        OutTextXY(MX0+9*8,CY0+64,'No room!');
        Exit;
      end;
      {MouseOff;}
      MouseDisabled:=True;
      BuyTF(CY0,cSInfo,IIF(bays=0,Tl,0),free,TFnum,Sh,lock and LockLo);
      SetShipMass(lship^);
      MouseDisabled:=False;
      {MouseOn;}
      ShipInfo;
    end;
  end;

procedure BuyBaseTF;
  var   i       : byte;
  begin
    if (turn<>today) or (lbase=nil) or (lbase^.owner<>player) then Exit;
    {MouseOff;}
    MouseDisabled:=True;
    Clear(MX0,192,639,BL2+15);
    SetColor(cBInfo);
    OutTextXY(MX0,192,'Buy items:');
    NewMenu; UnLockReservedMemory(MenuSize(MX0+8,208,631,11,Yes));
    AddMenuItem('Fighters',cBInfo,No);
    i:=1;
    while (i<=10) and (Torps[i].tech<=lbase^.Tl) do
      begin AddMenuItem(Torps[i].name+' torpedoes',cBInfo,No); inc(i) end;
    ChooseMenu(MX0+8,208,MX0+8,631,11,cBInfo,Yellow,1,No,Yes,-1);
    NewMenu; LockReservedMemory;
    if (MenuKey<>27) and (MenuValue<>0) then
    begin
      dec(MenuValue);
      if MenuValue=0 then BuyTF(192,cBInfo,0,GetMaxFightersOnBase(lbase^.owner),lbase^.fighters,Ba,PlanN)
                     else BuyTF(192,cBInfo,MenuValue,30000,lbase^.TT[MenuValue],Ba,PlanN);
    end;
    MouseDisabled:=False;
    {MouseOn;}
    BaseInfo;
  end;

function Min20 (l:long) : int;
  begin
    if l<20000 then Min20:=l else Min20:=20000
  end;

type    SArray = array [1..3,1..12] of int;
        { 1..8 = N,T,D,M,Sup,Cl,$,T/F (0+0 - disabled);
          9 = Max Fuel (30000-unlimited);
          10 = Max Cargo (30000-unl.);
          11 = Max $ (30000-unl.);
          12 = Add Cargo (blocked amount);
          [3,12] = Max T/F for base (0 - don't count);
          [3,1..8] = amounts loaded onto ship
          [2,1..8] = amounts on other ship/planet
          [1,1..8] = amounts on this ship }

procedure Shipment (var a : SArray; x1,x2,xa,y:int; c2,lr:byte; xt:xtype; chgburn:boolean; showpop:boolean );
  var   i       : byte;                                         { M.O.T.}
        ch      : word;
        xx,yy,k : int;
        cargo   : array [1..2] of int;
        cargo0  : int;
        s       : string[5];
        allowss : boolean;
  procedure PutNum (x,y:int; c:byte; n:int);
    var s       : string[5];
    begin
      if n=0 then s:='' else if n>19999 then s:='++++' else Str(n,s);
      Clear(x,y,x+39,y+7);
      SetColor(c);
      OutTextXY(x,y,s);
    end;
  procedure MoveCargo (i1,i2,amt:int);  { move amt from i1 to i2 }
    var amt1,dm : int;
        s1,s2   : string[4];
    begin
      if allowss and (i1=2) and (i=7) and (a[2,7]=0) and (a[2,5]>0) then
      begin { auto-sell supplies }
        if amt=0 then amt:=a[2,5];
        amt:=Min(Min(amt,a[1,11]-a[1,7]),a[2,5]);
        if amt=0 then Exit;
        with TTurn^.data^.planet[PlanN]^ do
        begin
          dec(supplies,amt);
          inc(funds,amt);
          ChangeData(Pl,PlanN);
        end;
        dec(a[2,5],amt);
        inc(a[1,7],amt);
        inc(a[3,7],amt);
        dec(cargo[2],amt);
        PutNum(x1,yy,cSInfo,a[1,7]);
        PutNum(x2,yy-16,c2,a[2,5]);
        Exit;
      end;
      if i=1 then amt1:=a[i2,9]-a[i2,1]
      else if i=7 then amt1:=a[i2,11]-a[i2,7]
      else if (i=8) and (i2=2) and (a[3,12]<>0) then amt1:=a[3,12]-a[2,8]
      else amt1:=a[i2,10]-cargo[i2];
      amt:=Min(Min(amt,a[i1,i]),amt1);
      if amt=0 then Exit;
      if i2=1 then inc(a[3,i],amt) else dec(a[3,i],amt);
      if a[i1,i]<20000 then dec(a[i1,i],amt);
      if a[i2,i]<20000 then inc(a[i2,i],amt);
      if i in [2..6,8] then
      begin
        dec(cargo[i1],amt);
        inc(cargo[i2],amt);
        Str(cargo[1]+a[1,12],s1);
        Str(a[1,10]+a[1,12],s2);
        Clear(MX0+7*8,CY0,639,CY0+7);
        SetColor(cSInfo);
        OutTextXY(MX0+7*8,CY0,s1+'/'+s2+' kt');
      end;
      PutNum(x1,yy,cSInfo,a[1,i]);
      PutNum(x2,yy,c2,a[2,i]);
      if chgburn then
      with lship^ do
      begin
        dm:=cargo[1]-cargo0+a[3,1];
        inc(fuel,a[3,1]);
        inc(mass,dm);
        SayFuel;
        dec(fuel,a[3,1]);
        dec(mass,dm);
      end;
    end;

  begin
    cargo[1]:=a[1,2]+a[1,3]+a[1,4]+a[1,5]+a[1,6]+a[1,8];
    cargo0:=cargo[1];
    if a[2,10]=30000 then cargo[2]:=20000
    else cargo[2]:=a[2,2]+a[2,3]+a[2,4]+a[2,5]+a[2,6]+a[2,8];
    for i:=1 to 9 do
      if a[1,i] or a[2,i] <> 0 then Break;
    if i>8 then Exit;
    allowss:=(xt=Pl) and (PlanN<>0) and (TTurn^.data^.planet[PlanN]<>nil);
    if allowss then
      with TTurn^.data^.planet[PlanN]^ do
      allowss:=(when=today) and (owner=player);
    Clear(x1,y,639,y+8*8-1);
    yy:=y;
    for i:=1 to 8 do
    begin
      PutNum(x1,yy,cSInfo,a[1,i]);
      PutNum(x2,yy,c2,a[2,i]);
      inc(yy,8);
    end;
    SetLineStyle(SolidLn,0,NormWidth);
    i:=1;
    yy:=y;
    xx:=IIF(lr=1,x1,x2);
    repeat
      if ((i=6) and showpop) then begin
        if (lr=2) then
          WriteMaxPop(CY0+72,a[2,6])
        else
          WriteMaxPop(CY0+72,-a[3,6]);
      end else
        Clear(MX0,CY0+72,639,CY0+72+7);
      PutNum(xx,yy,IIF(lr=1,cSInfo,c2),a[lr,i]);
      SetColor(Yellow);
      Line(xx,yy+7,xx+39,yy+7);
      repeat ArrowBlink(xa,yy) until KeyPressed;
      SetColor(Black);
      Line(xx,yy+7,xx+39,yy+7);
      ch:=ReadKey;
      case ch of
        $4800   : begin
                    Clear(xa,yy,xa+15,yy+7);
                    repeat
                      dec(i); if i=0 then i:=8;
                    until (a[1,i]<>0) or (a[2,i]<>0) or ((i=7) and allowss);
                    yy:=y+(i-1)*8;
                  end;
        $5000   : begin
                    Clear(xa,yy,xa+15,yy+7);
                    repeat
                      inc(i); if i=9 then i:=1;
                    until (a[1,i]<>0) or (a[2,i]<>0) or ((i=7) and allowss);
                    yy:=y+(i-1)*8;
                  end;
        $4B00   : if KbdFlags and KbdShft=0 then MoveCargo(2,1,1)
                                            else MoveCargo(2,1,a[2,i]);
        $4D00   : if KbdFlags and KbdShft=0 then MoveCargo(1,2,1)
                                            else MoveCargo(1,2,a[1,i]);
        $7300   : MoveCargo(2,1,10);
        $7400   : MoveCargo(1,2,10);
        $9B00   : MoveCargo(2,1,100);
        $9D00   : MoveCargo(1,2,100);
        9       : begin
                    lr:=lr xor 3;
                    xx:=IIF(lr=1,x1,x2);
                  end;
        ord('0')..ord('9')      :
                  if a[lr,i]<=19999 then
                  begin
                    GetStr1stKey:=ch;
                    s:=GetStr(xx,yy,5);
                    if GetStrKey=13 then
                    begin
                      k:=Value(s);
                      if (k>=0) and (k<20000) then
                      begin
                        dec(k,a[lr,i]);
                        if k>0 then MoveCargo(lr xor 3,lr,k)
                               else MoveCargo(lr,lr xor 3,-k);
                      end;
                    end;
                  end;
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
      end;
    until (ch=13) or (ch=27);
  end;

procedure TransferCargo (t:xtype);
  label Cancel,Direct;
  var   a       : SArray;
        pn,l0,s0: int;
        number  : word;
        p       : pptr;
        b       : bptr;
        h       : sptr;
        c,lr    : byte;
        ix1,ix2 : word;
        s       : string[3];
        chgburn,showpop : boolean;
        ming,maxc,GAmin,GAmax : longint;
        { 1..8 = N,T,D,M,Sup,Cl,$,T/F (0+0 - disabled);
          9 = Max Fuel (30000-unlimited);
          10 = Max Cargo (30000-unl.);
          11 = Max $ (30000-unl.);
          12 = Add Cargo (blocked amount);
          [3,12] = Max T/F for base (0 - don't count);
          [3,1..8] = amounts loaded onto ship          }

  procedure PrepareShipTransfer (var a:SArray; h:sptr; i:byte);
    begin
      with h^ do
      begin
        a[i,1]:=fuel; a[i,2]:=T; a[i,3]:=D; a[i,4]:=M;
        a[i,5]:=Sup; a[i,6]:=colonists; a[i,7]:=credits;
        a[i,12]:=TFnum;
        a[i,9]:=Hulls[hull].fuel;
        a[i,10]:=Hulls[hull].cargo-a[i,12];
        a[i,11]:=10000;
      end;
    end;

  procedure TransferShipCargo (var a:SArray; h:sptr; hn:int; i:byte);
    var r       : int;
    begin               { NEVER use [1..2,1..8]!!!  It may be:=0!! }
      if i=1 then r:=1 else r:=-1;
      with h^ do
      begin
        inc(fuel,a[3,1]*r);
        inc(T,a[3,2]*r);
        inc(D,a[3,3]*r);
        inc(M,a[3,4]*r);
        inc(Sup,a[3,5]*r);
        inc(colonists,a[3,6]*r);
        inc(credits,a[3,7]*r);
        inc(TFnum,a[3,8]*r);
        SetShipMass(h^);
        {inc(mass,(a[3,1]+a[3,2]+a[3,3]+a[3,4]+a[3,5]+a[3,6]+a[3,8])*r);}
        ChangeData(Sh,hn);
      end;
    end;

  function Min20 (l:long) : int;
    begin
      if l<20000 then Min20:=l else Min20:=20000
    end;

  procedure EnableTF (h:sptr; i:byte);
    var s       : string[3];
    begin
      a[i,8]:=h^.TFnum;
      inc(a[i,10],a[i,8]); dec(a[i,12],a[i,8]);
      {if i=1 then
      begin
        SetColor(cSInfo);
        if h^.bays=0 then s:='Tp:' else s:='Fg:';
        OutTextXY(MX0,CY0+64,s);
      end;}
    end;

  begin
    if (turn<>today) or (lship^.owner<>player) or (lship^.when<>today) then Exit;
    number:=lock and LockLo;
    {MouseOff;}
    MouseDisabled:=True;
    FillChar(a,SizeOf(SArray),0);
    PrepareShipTransfer(a,lship,1);
    Clear(MX0,CY0+80,639,CY0+88+7);
    if t=Sh then begin c:=LightBlue; ix1:=MX0+13*8; ix2:=MX0+10*8 end
            else begin c:=LightGreen; ix1:=MX0+9*8; ix2:=MX0+15*8 end;
    SetColor(c);
    lr:=2;
    chgburn:=Yes;
    showpop:=No;
    if t=Sh then
    begin
      OutTextXY(MX0,CY0+88,'Transfer to');
      pn:=lship^.TSh;
      if pn=0 then pn:=SelectShip(lx,ly,No,No);
      if pn<>0 then
      begin
        s0:=ObjL0; l0:=lock;
        h:=TTurn^.data^.ship[pn];
        ObjL0:=(ShipNumXY(h,lx,ly)-1) div 10;
        lock:=pn or LockS;
        ltype:=LockS;
        ObjList;
        ObjL0:=s0; lock:=l0; ltype:=lock and LockHi;
      end;
      if pn=0 then goto Cancel;
      chgburn:=(lship^.mission<>7) or (lship^.tow_ship<>pn);
      if h^.owner=player then
      begin
        Clear(MX0,CY0+88,639,CY0+88+7);
        SetColor(LightBlue);
        OutTextXY(MX0,CY0+88,'Trans. to/from '+NStr0(pn));
        PrepareShipTransfer(a,h,2);
        if ((lship^.bays>0) and (h^.bays>0)) or
           ((lship^.Tl>0) and (lship^.Tl=h^.Tl)) then
        begin
          EnableTF(lship,1);
          EnableTF(h,2);
        end;
      end
      else
Direct:
      with lship^ do begin
        SetColor(LightBlue);
        OutTextXY(MX0+12*8,CY0+88,NStr0(pn));
        a[2,1]:=TN; a[2,2]:=TT; a[2,3]:=TD; a[2,4]:=TM;
        a[2,5]:=TS; a[2,6]:=TC; a[1,7]:=0;
        a[2,9]:=30000; a[2,10]:=30000;
      end;
    end
    else begin
      p:=nil; pn:=splan[number];
      if pn=0 then OutTextXY(MX0,CY0+88,'Jettison cargo!')
      else begin
        p:=TTurn^.data^.planet[pn];
        lplan:=p;
        if (p=nil) or (p^.when<>today) or (p^.owner<>player) then begin
          p:=nil;
          OutTextXY(MX0,CY0+88,'Unload to '+NStr0(pn));
          showpop:=Yes;
        end else begin
          OutTextXY(MX0,CY0+88,'Trans. to/from P'+NStr0(pn));
          lr:=1;
          showpop:=Yes;
        end;
      end;
      if p=nil then with lship^ do
      begin
        a[2,1]:=CN; a[2,2]:=CT; a[2,3]:=CD; a[2,4]:=CM; a[2,5]:=CS;
        {if pn<>0 then} a[2,6]:=CC {else a[1,6]:=0};
        a[1,7]:=0;
        a[2,9]:=30000; a[2,10]:=30000;
      end
      else begin
        with p^ do
        begin
          a[2,1]:=Min20(N); a[2,2]:=Min20(T); a[2,3]:=Min20(D); a[2,4]:=Min20(M);
          a[2,5]:=Min20(supplies); a[2,6]:=Min20(colonists); a[2,7]:=Min20(funds);
          a[2,9]:=30000; a[2,10]:=30000; a[2,11]:=30000;
        end;
        with lship^ do
        if bays+launchers<>0 then
        begin
          b:=TTurn^.data^.base[pn];
          if b<>nil then
          begin
            EnableTF(lship,1);
            if bays=0 then a[2,8]:=b^.TT[Tl] else a[2,8]:=b^.fighters;
            if (bays<>0) {and (not NoLimits)} then a[3,12]:=GetMaxFightersOnBase(b^.owner);
          end;
        end;
      end;
    end;
    Shipment(a,MX0+4*8,ix1,ix2,CY0+8,c,lr,t,chgburn,showpop);
    if a[3,1] or a[3,2] or a[3,3] or a[3,4] or
       a[3,5] or a[3,6] or a[3,7] or a[3,8]<>0 then
    begin
			if (lship^.mission=9) and ((lship^.fuel=0) or (a[1,1]=0)) then GSOP[1]:=0;
				{Fuel zero manipulated, Reset GetShipsOverPlanet, Ships will be recalculated}				
      TransferShipCargo(a,lship,number,1);
      if t=Sh then
        if (h<>nil) and (h^.owner=player) then TransferShipCargo(a,h,pn,2)
        else with lship^ do begin
          dec(TN,a[3,1]);
          dec(TT,a[3,2]);
          dec(TD,a[3,3]);
          dec(TM,a[3,4]);
          dec(TS,a[3,5]);
          dec(TC,a[3,6]);
          if TN or TT or TD or TM or TS or TC = 0 then pn:=0;
          if TSh<>pn then TSh:=pn;
          ChangeData(Sh,number);
        end
      else
        if p=nil then
        with lship^ do
        begin
          dec(CN,a[3,1]);
          dec(CT,a[3,2]);
          dec(CD,a[3,3]);
          dec(CM,a[3,4]);
          dec(CS,a[3,5]);
          dec(CC,a[3,6]);
          if CN or CT or CD or CM or CS or CC = 0 then pn:=0;
          if CPl<>pn then CPl:=pn;
          ChangeData(Sh,number);
        end
        else with p^ do begin
          dec(N,a[3,1]);
          dec(T,a[3,2]);
          dec(D,a[3,3]);
          dec(M,a[3,4]);
          dec(supplies,a[3,5]);
          dec(colonists,a[3,6]);
          dec(funds,a[3,7]);
          ChangeData(Pl,pn);
          if a[3,8]<>0 then
          begin
            if lship^.bays=0 then dec(b^.TT[lship^.Tl],a[3,8])
                             else dec(b^.fighters,a[3,8]);
            ChangeData(Ba,pn);
          end;
        end;
    end;
Cancel:
    ShipInfo;
    MouseDisabled:=False;
    {MouseOn;}
  end;

procedure UpgradeBaseTech;                                      { M.O.T.}
  const yy0     = 152;
  type  TLarr   = array [TLtype] of int;
  var   ch      : word;
        x,y     : int;
        lv      : TLtype;
        lvlp    : pointer;
        lvl     : ^TLarr absolute lvlp;
        lvl0,lvl1       : TLarr;
        suppsold        : long;
        b       : BRec;
        myrace  : int;
  procedure WriteIt;
    begin
      SetColor(cBInfo);
      Clear(MX0+8*8,yy0-2*8,639,yy0-2*8+7);
      OutTextXY(MX0+8*8,yy0-2*8,NStr0(lplan^.supplies+lplan^.funds));
      Clear(x,y,x+2*8-1,y+7);
      OutTextXY(x,y,NStr(lvl^[lv]));
    end;
  procedure UpgradeTech (amt:int);      { amt = 1 or -1 only }
    var level   : int;
        k       : long;
    begin
      level:=lvl^[lv];
      amt:=Min(Max(level+amt,lvl0[lv]),lvl1[lv])-level;
      if amt=0 then Exit;
      with lplan^ do
      begin
        if (amt=1) and (funds+supplies<level*100) then Exit;
        if amt=1 then
        begin
          dec(funds,level*100);
          if funds<0 then
          begin
            dec(suppsold,funds);        { funds<0 here }
            inc(supplies,funds);
            funds:=0;
          end;
        end
        else begin
          inc(funds,(level-1)*100);
          if suppsold>0 then
          begin
            k:=MinL(suppsold,funds);
            dec(suppsold,k);
            inc(supplies,k);
            dec(funds,k);
          end;
        end;
      end;
      inc(lvl^[lv],amt);
      ChangeData(Pl,PlanN);
      ChangeData(Ba,lock and LockLo);
    end;
  begin
    if (turn<>today) or (lbase=nil) or (lplan=nil) or (lbase^.owner<>player) then Exit;
    SetColor(cBInfo);
    OutTextXY(MX0,yy0-2*8,'mc+sup:');
    with lbase^ do
    begin
      lvlp:=Addr(El);
      Move(lvl^,lvl0,SizeOf(TLarr));
      for lv:=_El to _Tl do     { lvl1 must be >= lvl0 }
        lvl1[lv]:=Max(lvl0[lv],IIF(SWPlan and (lplan^.Nrace<>TechRace[lv]),6,10));
    end;
    LoadBDis(lock and LockLo,b);
    Move(b.El,lvl0,SizeOf(TLArr));
    if TrueHullByRace then myrace:=Race[lbase^.owner]
                      else myrace:=lbase^.owner;
    for x:=1 to 20 do
      if lbase^.HH[x]-b.HH[x]>0 then lvl0[_Hl]:=Max(lvl0[_Hl],Hulls[RaceHull[myrace,x]].tech);
    for x:=1 to 10 do
      if lbase^.EE[x]-b.EE[x]>0 then lvl0[_El]:=Max(lvl0[_El],Engines[x].tech);
    for x:=1 to 10 do
      if lbase^.WW[x]-b.WW[x]>0 then lvl0[_Wl]:=Max(lvl0[_Wl],Beams[x].tech);
    for x:=1 to 10 do
      if lbase^.LL[x]-b.LL[x]>0 then lvl0[_Tl]:=Max(lvl0[_Tl],Torps[x].tech);
    for x:=1 to 10 do
      if TFBuilt(lock and LockLo,x)>0 then lvl0[_Tl]:=Max(lvl0[_Tl],Torps[x].tech);
    suppsold:=SoldSupp(lock and LockLo);
    {MouseOff;}
    MouseDisabled:=True;
    SetLineStyle(SolidLn,0,NormWidth);
    x:=MX0+13*8;
    y:=yy0;
    lv:=_El;
    repeat
      WriteIt;
      SetColor(Yellow);
      Line(x,y+7,x+15,y+7);
      repeat ArrowBlink(640-2*8,y) until KeyPressed;
      SetColor(Black);
      Line(x,y+7,x+15,y+7);
      ch:=ReadKey;
      case ch of
        $4800   : begin
                    Clear(640-2*8,y,639,y+7);
                    if lv=_El then lv:=_Tl else dec(lv);
                    y:=yy0+byte(lv)*8;
                  end;
        $5000   : begin
                    Clear(640-2*8,y,639,y+7);
                    if lv=_Tl then lv:=_El else inc(lv);
                    y:=yy0+byte(lv)*8;
                  end;
        $4B00   : UpgradeTech(-1);
        $4D00   : UpgradeTech(1);
        $3B00   : begin
                    helpscr:=5;
                    Help;
                    helpscr:=0;
                    DrawMap(Yes);
                  end;
      end;
    until (ch=13) or (ch=27);
    BaseInfo;
    MouseDisabled:=False;
    {MouseOn;}
  end;

procedure FixOrRecycleShip (bn,op,n:int);
  var   b       : bptr;
  begin
    b:=TTurn^.data^.base[bn];
    if (b=nil) or (b^.owner<>player) then Exit;
    if b^.fShip=n then n:=0;
    b^.fShip:=n;
    if n=0 then op:=0;
    b^.fOp:=op;
    ChangeData(Ba,bn);
    if ltype=LockS then ShipInfo
                   else BaseInfo;
  end;

procedure FixOrRecycle (op:byte);
  var   n       : int;
        h       : sptr;
        s       : string[3];
        i0      : int absolute h;
  begin
    if (turn<>today) or (lbase=nil) or (lbase^.owner<>player) then Exit;
    Clear(MX0,ListY,639,ListY+7);
    SetColor(Yellow);
    if op=1 then OutTextXY(MX0,ListY,'Fix ship:')
            else OutTextXY(MX0,ListY,'Recycle ship:');
    n:=SelectShip(lx,ly,op=2,No);
    FixOrRecycleShip(lock and LockLo,op,n);
  end;

function BuildClone : boolean;
  var   h       : sptr;
  begin
    BuildClone:=No;
    if (turn<>today) or (lbase=nil) or (lbase^.owner<>player) then Exit;
    Clear(MX0,ListY,639,ListY+7);
    SetColor(Yellow);
    OutTextXY(MX0,ListY,'Clone ship:');
    cloneID:=SelectShip(lx,ly,Yes,Yes);
    if cloneID=0 then BaseInfo else BuildClone:=Yes;
  end;

function SameOwner (r1,r2:int) : boolean;
  begin
    if r1=-1 then SameOwner:=(r2=player) else
    if (r1=player) or (r1=0) then SameOwner:=(r2=r1) else
    if IsData[r1] then SameOwner:=IsData[r2] else
    SameOwner:=(r2>0) and (r2<>player) and (not IsData[r2]);
  end;

procedure NextPlanet (dn:int);
  var   n,n0    : int;
        p       : pptr;
  begin
    if lplan=nil then Exit;
    n:=lock and LockLo;
    n0:=n;
    repeat
      inc(n,dn);
      if n>500 then n:=1 else if n<1 then n:=500;
      p:=TTurn^.data^.planet[n];
    until (n=n0) or ((p<>nil) and (p^.when=turn) and SameOwner(lplan^.owner,p^.owner)
                     and (TTurn^.data^.xyplan[n,1]<>-1));
    if n=n0 then Exit;
    {CenterMap(Planets[n].x,Planets[n].y,No);}
    force:=n or LockP;
    ForceKey:=13;
  end;

procedure NextBase (dn:int);
  var   n,n0    : int;
        p       : bptr;
  begin
    if lbase=nil then Exit;
    n:=lock and LockLo;
    n0:=n;
    repeat
      inc(n,dn);
      if n>500 then n:=1 else if n<1 then n:=500;
      p:=TTurn^.data^.base[n];
    until (n=n0) or ((p<>nil) and SameOwner(lbase^.owner,p^.owner) and (TTurn^.data^.xyplan[n,1]<>-1));
    if n=n0 then Exit;
{    CenterMap(Planets[n].x,Planets[n].y,No);}
    force:=n or LockP;
    lbase:=p;
    ForceKey:=13;
  end;

procedure NextShip (dn:int);
  var   n,n0    : int;
        p       : sptr;
  begin
    n:=lock and LockLo;
    n0:=n;
    repeat
      inc(n,dn);
      if n>999 then n:=1 else if n<1 then n:=999;
      p:=TTurn^.data^.ship[n];
    until (n=n0) or ((p<>nil) and (p^.when=turn) and SameOwner((lship^.owner and LockLo),p^.owner));
    if n=n0 then Exit;
    {CenterMap(p^.x,p^.y,nO);}
    force:=n or LockS;
    ForceKey:=13;
  end;

procedure NextActivePlanet (dn:int);
  var   n,n0    : int;
        p       : pptr;
  begin
    if lplan=nil then Exit;
    if lplan^.owner<>player then Exit;
    n:=lock and LockLo;
    n0:=n;
    repeat
      inc(n,dn);
      if n>500 then n:=1 else if n<1 then n:=500;
      p:=TTurn^.data^.planet[n];
    until (n=n0) or ((p<>nil) and (p^.when=turn) and SameOwner(lplan^.owner,p^.owner)
           and (TTurn^.data^.xyplan[n,1] <> -1)
           and ((actlist[n] and LockP) <> LockP) );
    if n=n0 then Exit;
    force:=n or LockP;
    ForceKey:=13;
  end;

procedure NextActiveBase (dn:int);
  var   n,n0    : int;
        p       : bptr;
  begin
    if lbase=nil then Exit;
    if lbase^.owner<>player then Exit;
    n:=lock and LockLo;
    n0:=n;
    repeat
      inc(n,dn);
      if n>500 then n:=1 else if n<1 then n:=500;
      p:=TTurn^.data^.base[n];
    until (n=n0) or ((p<>nil) and SameOwner(lbase^.owner,p^.owner)
           and (TTurn^.data^.xyplan[n,1] <> -1)
           and ((actlist[n] and LockB) <> LockB) );
    if n=n0 then Exit;
    force:=n or LockP;
    lbase:=p;
    ForceKey:=13;
  end;

procedure NextActiveShip (dn:int);
  var   n,n0    : int;
        p       : sptr;
  begin
    n:=lock and LockLo;
    n0:=n;
    repeat
      inc(n,dn);
      if n>999 then n:=1 else if n<1 then n:=999;
      p:=TTurn^.data^.ship[n];
    until (n=n0) or ((p<>nil) and (p^.when=turn) and SameOwner(lship^.owner,p^.owner)
           and ((actlist[n] and LockS) <> LockS) );
    if n=n0 then Exit;
    {CenterMap(p^.x,p^.y,nO);}
    force:=n or LockS;
    ForceKey:=13;
  end;

procedure SwitchActive (mask:int);
  var   n : int;
  begin
    n:=lock and LockLo;
    actlist[n] := actlist[n] xor mask;
    if mask = LockB then mask := LockP;
    force:=n or mask;
    ForceKey:=13;
  end;

procedure NextMines (dn:int);
  var   n,n0    : int;
        p       : mptr;
        ow      : int;
  begin
    if ltype<>LockM then Exit;
    n:=lock and LockLo;
    ow:=TTurn^.data^.mines[n]^.owner;
    n0:=n;
    repeat
      inc(n,dn);
      if n>500 then n:=1 else if n<1 then n:=500;
      p:=TTurn^.data^.mines[n];
    until (n=n0) or ((p<>nil) and SameOwner(ow,p^.owner));
    if n=n0 then Exit;
    {CenterMap(p^.x,p^.y,nO);}
    force:=n or LockM;
    ForceKey:=13;
  end;

procedure NextIon (dn:int);
  var   n,n0    : int;
        p       : iptr;
  begin
    n:=IIF(lock=0,1,lock and LockLo);
    n0:=n;
    repeat
      inc(n,dn);
      if n>50 then n:=1 else if n<1 then n:=50;
      p:=TTurn^.data^.ion[n];
    until (n=n0) or (p<>nil);
    if n=n0 then Exit;
    {CenterMap(p^.x,p^.y,No);}
    force:=n or LockI;
    ForceKey:=13;
  end;

procedure NextWorm (dn:int);
  var   n,n0    : int;
        p       : wptr;
  begin
    n:=lock and LockLo;
    n0:=n;
    repeat
      inc(n,dn);
      if n>199 then n:=0 else if n<0 then n:=199;
      p:=TTurn^.data^.worm[n];
    until (n=n0) or (p<>nil);
    if n=n0 then Exit;
    {CenterMap(p^.x,p^.y,No);}
    force:=n or LockW;
    ForceKey:=13;
  end;

procedure NextUFO (dn:int);
  var   n,n0    : int;
        p       : uptr;
  begin
    n:=lock and LockLo;
    n0:=n;
    repeat
      inc(n,dn);
      if n>100 then n:=1 else if n<1 then n:=100;
      p:=TTurn^.data^.ufo[n];
    until (n=n0) or (p<>nil);
    if n=n0 then Exit;
    {CenterMap(p^.x,p^.y,No);}
    force:=n or LockU;
    ForceKey:=13;
  end;

procedure ChangePassword;
  var   s,s1    : string[10];
        ls      : byte absolute s;
  begin
    if not RWMode then Exit;
    MouseMove;
    ClearInfo;
    GetStrPwdChar:='*';
    if Password<>NoPassword then
    begin
      SetColor(White);
      OutTextXY(MX0,88,'Type OLD password:');
      s:=GetStr(MX0+4*8,104,10);
      if s<>Password then
      begin
        SetColor(Red);
        OutTextXY(MX0,120,'Invalid password!');
        GetStrPwdChar:=#0;
        Exit;
      end;
    end;
    SetColor(White);
    OutTextXY(MX0,120,'Type NEW password:');
    s:=GetStr(MX0+4*8,136,10);
    OutTextXY(MX0,152,'Retype to confirm:');
    s1:=GetStr(MX0+4*8,168,10);
    GetStrPwdChar:=#0;
    if s<>s1 then
    begin
      SetColor(Red);
      OutTextXY(MX0,184,'Input mismatch!');
      Exit;
    end;
    SetColor(Yellow);
    if ls=0 then s:=NoPassword;
    if s=Password then
    begin
      OutTextXY(MX0,192,'Password unchanged');
      Exit;
    end;
    if s=NoPassword then
    begin
      OutTextXY(MX0,192,'Password will be');
      OutTextXY(MX0,200,'disabled next time');
    end
    else begin
      OutTextXY(MX0,192,'Changes will take');
      OutTextXY(MX0,200,'effect next time');
    end;
    OutTextXY(MX0,208,'you run VPA');
    NewPassword:=s;
    DataChg:=Yes;
  end;

procedure MineSim;
{ TODO: sweeprange from config -ok (really OK?)
        fighter-sweep -OK
        Robot-Bonus -OK
        Mine-FCs -OK
        no sweep in IONS -OK}
var i,j,field,free:integer;
    m,m1:mptr;
    s:sptr;
    mine2:array [1..500] of mptr;
    scooped:array[1..NUM_SHIPS] of int;
    shipok:array[1..NUM_SHIPS] of BOOLEAN;
    xx,yy,xx1,yy1,sweep1,cfree:int;
    tfield,trace,tweb:int;
    dist,dist2,anz:long;
    r1,r2,d,a:real;
    UnitsPerTorp:double;
begin
  MouseMove;
  MouseDisabled:=True;
  MouseOff;
  SetViewPort(0,0,479,479,ClipOn);

  for i:=1 to NUM_SHIPS do begin
    scooped[i]:=0;
    shipok[i]:=TRUE;
    s:=TTurn^.data^.ship[i];
    if (s<>NIL) then begin
      if (((s^.mission=2) and (s^.fcode='msc')) or
        ((s^.mission=ExtMissionsStartAt+3))) then
        shipok[i]:=False;
    end;
  end;
  for i:=1 to 500 do begin
    m:=TTurn^.data^.mines[i];
    if ((m<>NIL) and (m^.units>0)) then begin
      New(mine2[i]);
      mine2[i]^:=m^;
    end else
      mine2[i]:=NIL;
  end;

   { Phase 0: Guess Mine-Alliances }
   for j:=1 to 500 do begin
      m1:=mine2[j];
      if (m1<>NIL) and (m1^.when=today) and (m1^.owner=player) then begin {was <>, fixed}
         r1:=sqrt(m1^.units);
         for i:=1 to 500 do begin
            m:=mine2[i];
            if ((m<>NIL) and (m^.owner<>player) and
                (not IsAllied(2,m1^.owner,m^.owner)) and
                (m1^.web=m^.web) and (m^.when=today)) then begin
               d:=sqrt(Distance2(m1^.x,m1^.y,m^.x,m^.y));
               r2:=sqrt(m^.units);
               if (d<r1+r2) then begin               {was (d<=r1+r2-2) why?}
                  alliance[2,m1^.owner,m^.owner]:=3;
                  alliance[2,m^.owner,m1^.owner]:=3;
               end;
            end;
         end;
      end;
   end;
  { Phase 2: lay  }
  for j:=1 to NUM_SHIPS do begin
    s:=TTurn^.data^.ship[j];
    if ((s<>NIL) and (s^.when=turn) and (s^.launchers>0) and (s^.fuel>0)) then begin
      anz:=s^.TFnum;
      tweb:=0;
      tfield:=-1;
      trace:=realshipowner(j);
      if ((s^.mission=3) or ((Race[realshipowner(j)]=7) and (s^.mission in [9,ExtMissionsStartAt+11]))) then begin
        if (s^.mission=3) then tweb:=0 else tweb:=1;
        { FC codes }
        if (s^.fcode='mdq') then anz := s^.TFnum div 4;
        if (s^.fcode='mdh') then anz := s^.TFnum div 2;
        if (s^.fcode[1]='m')AND(s^.fcode[2]='d')AND
            (s^.fcode[3] in ['1','2','3','4','5','6','7','8','9' ]) then
            anz:=MinL( (ord(s^.fcode[3])-ord('0'))*10, s^.TFnum);
        if (s^.fcode='md0') then anz := MinL(100,s^.TFnum);
        tfield:=0;
      end;
      if ((s^.mission-ExtMissionsStartAt) in [1,2]) then begin
        if (s^.mission=ExtMissionsStartAt+1) then tweb:=0 else tweb:=1;
        if (s^.intr_ship>0) then anz:=MinL(anz,s^.intr_ship);
        if (s^.tow_ship>0) then trace:=s^.tow_ship;
        tfield:=0;
      end;
      if ((s^.mission-ExtMissionsStartAt) in [16,17]) then begin
        if (s^.mission=ExtMissionsStartAt+16) then tweb:=0 else tweb:=1;
        if (s^.intr_ship>0) then anz:=MinL(anz,s^.intr_ship);
        tfield:=s^.tow_ship;
        shipok[j]:=False;
      end;
      if ((tweb>0) and (Race[Realshipowner(j)]<>7)) then begin
        shipok[j]:=False;
        continue;
      end;
      if (tfield<0) then continue;
      field:=0;
      free:=0;
      for i:=1 to NUM_MINES do begin
        m:=mine2[i];
        if ((m<>NIL) AND (m^.units>0)) then begin
          dist:=Trunc(sqrt(m^.units)-(distance(s^.x,s^.y,m^.x,m^.y)));
          if (dist>=0) then
(*          writeln('i: ', i,' Field: ',field,' TF: ',tfield,' TWeb: ',tweb,'=',m^.web and 1,' Dist<0: ',dist,
                  ' Trace: ',trace,'=',m^.owner); *)
          if ((field=0) and (dist>=0) and (tweb=(m^.web and 1)) and (trace=m^.owner) and
             ((tfield=i) or (tfield=0))) then begin
               if field=0 then begin field:=i; dist2:=dist; 
               end else if (dist<dist2) then begin field:=i; dist2:=dist; end;   {Field closer to ship?}
          end;
        end else begin
          if ((m=NIL) and (free=0)) then free:=i;
        end;
      end;
      
      if ((field=0) and (tfield=0)) then begin
        field:=free;
        if (mine2[free]=NIL) then New(mine2[free]);
        m:=mine2[free];
        UnitsPerTorp := minL(UnitsPerTorpRate[realshipowner(j)],UnitsPerTorpRate[trace]) /100.0;
        m^.units:=anz*round( UnitsPerTorp *s^.Tl* s^.Tl );
        m^.x:=s^.x;
        m^.y:=s^.y;
        m^.owner:=trace;
        m^.web:=tweb;
      end else if ((field=tfield) or ((field>0) and (tfield=0))) then begin
(*        writeln('Field: ',field,' TF: ',tfield,' TWeb: ',tweb,' Dist: ',dist); *)
        m:=mine2[field];
        UnitsPerTorp := minL(UnitsPerTorpRate[realshipowner(j)],UnitsPerTorpRate[trace]) /100.0;
        m^.units:=m^.units+anz*round( UnitsPerTorp *s^.Tl* s^.Tl );
      end;      
      if ((field>0) and (mine2[field]<>NIL)) then begin
        shipok[j]:=True;
        m1:=mine2[field];
        r1:=sqrt(m1^.units);
        for i:=1 to NUM_MINES do begin
          m:=mine2[i];
          if ((m<>NIL) and (not IsAllied(2,m1^.owner,m^.owner)) and (m1^.web=m^.web)) then begin
            d:=sqrt(Distance2(m1^.x,m1^.y,m^.x,m^.y));
            r2:=sqrt(m^.units);
            if (d<=r1+r2) then begin
              anz:=0;
              if (d<0.1) then begin
                if (r1<r2) then begin
                  anz:=m1^.units;
                end else begin
                  anz:=m^.units;
                end;
              end else begin
                a:=(r1*r1-r2*r2+d*d)/(2*d);
                if (a<0) then anz:=m1^.units
                else if (a>d) then anz:=m^.units
                else anz:=Trunc(r1*r1-a*a);
              end;
              if (anz>0) then begin
{               Writeln('EX: ',field,' ',i,' ',anz);}
                m1^.units:=m1^.units-anz;
                m^.units:=m^.units-anz;
                r1:=sqrt(m1^.units);
                Abs2Scr(m1^.x,m1^.y,xx1,yy1);
                Abs2Scr(m^.x,m^.y,xx,yy);
                SetColor(DarkGray);
                SetLineStyle(SolidLn,0,NormWidth);
                DrawWLine(xx,yy,xx1,yy1,True);
              end;
            end;
          end;
        end;
      end;
    end;
  end;
  { Phase 3: sweep+scoop }
  for j:=1 to NUM_SHIPS do begin
    s:=TTurn^.data^.ship[j];
    if ((s<>NIL) and (s^.when=turn) and (s^.fuel>0)) then begin
      if (s^.mission=2) then sweep1:=s^.weapons*s^.Wl*s^.Wl
                        else sweep1:=0;
      (* if (s^.mission<0) then
        sweep1:=hulls[s^.hull].weapons*10*10; *)
      dist2:=0; {not in ion storm}
      for i:=1 to 50 do begin
        if (TTurn^.data^.ion[i]<>NIL) then begin
          with TTurn^.data^.ion[i]^ do
          dist:=distance(s^.x,s^.y,x+Round(sin(heading*Pi/180.0)*long(warp*warp)),
                                   y+Round(cos(heading*Pi/180.0)*long(warp*warp)))-radius;
          if dist<0 then dist2:=dist;
        end;
      end;
      for i:=1 to 500 do begin
        m:=mine2[i];
        if ((m<>NIL) AND (m^.units>0)) then begin
          dist:=Trunc((distance(s^.x,s^.y,m^.x,m^.y))-sqrt(m^.units));
      
          { sweep }
          if (dist2>=0) then begin      {sweep, not inside ionstorm}
            if ((not IsAllied(2,m^.owner,realshipowner(j))) and (sweep1>0)) then begin
              if ((m^.web and 1=0) and (dist<=sweeprange)) then begin         {Mines?}
                m^.units:=MaxL(0,m^.units-sweep1*SweepRate);
                shipok[j]:=TRUE;
              end else if (dist<=websweeprange) then begin                    {WEBS?}
                m^.units:=MaxL(0,m^.units-long(sweep1*WebSweepRate));
                shipok[j]:=TRUE;
              end;
              if (s^.bays>0) and (FighterSweepRate[realshipowner(j)]>0) then begin
                 if (m^.web and 1=0) and (dist<=FighterSweepRange[realshipowner(j)]) then begin
                      m^.units:=MaxL(0,m^.units-s^.TFnum*FighterSweepRate[realshipowner(j)]);
                      shipok[j]:=TRUE;
                 end;
                 if (AllowColoniesSweepWebs) and (m^.web and 1=1) and (dist<=FighterSweepRange[realshipowner(j)]) then begin
                      m^.units:=MaxL(0,m^.units-s^.TFnum*FighterSweepRate[realshipowner(j)]);
                      shipok[j]:=TRUE;
                 end;
              end;
            end;
          end;

          { scoop }
          if ( IsAllied(2,RealshipOwner(j),m^.owner) and (s^.launchers>0) and (dist<=0)) then begin
            anz:=0;
            cfree:=Hulls[s^.hull].cargo-s^.T-s^.D-s^.M-s^.Sup-s^.colonists-s^.TFnum-scooped[j];
            if ((s^.mission=ExtMissionsStartAt+3) and ((s^.tow_ship=i) or (s^.tow_ship=0))) then begin
              if (s^.intr_ship>0) then anz:=MinL(cfree,s^.intr_ship)
              else anz:=cfree;
            end;
            if ((s^.mission=2) and (s^.fcode='msc')) then begin
              anz:=cfree;
            end;
             UnitsPerTorp := minL(UnitsPerTorpRate[realshipowner(j)],UnitsPerTorpRate[m^.owner])/100.0;
            if (anz>0) then begin
{ writeln('Scoop ',j,' ',i,' ',anz,' '); }
              if (anz*s^.Tl*s^.Tl*UnitsPerTorp)>m^.units then begin
                anz:=(m^.units DIV ( round(s^.Tl*s^.Tl*UnitsPerTorp)));
                m^.units:=0;
              end else begin
                m^.units:=m^.units-anz*round(s^.Tl*s^.Tl*UnitsPerTorp);
              end;
              scooped[j]:=scooped[j]+anz;
              if (anz>0) then
                shipok[j]:=TRUE;
            end;
          end;
        end;
      end;
    end;
  end;
  { Phase 4: Decay is after Lay/Sweep, see Donovans }
  for i:=1 to 500 do begin
    m:=mine2[i];
    if (m<>NIL) then begin
      if (m^.web and 1=0) then m^.units:=Trunc(m^.units*(100.0-MineDecayRate)/100.0)
                    else m^.units:=Trunc(m^.units*(100.0-WebMineDecayRate)/100.0);
    end;
  end;
  { Phase 5: Explosion }
  for i:=1 to 499 do begin    
    m:=mine2[i];
    if (m<>NIL) and (m^.web and 1=0) then begin
      for j:=i+1 to 500 do begin
        m1:=mine2[j];
        if (m<>NIL) and (m1<>NIL) and (m1^.web and 1=0) then begin
          if (not IsAllied(2,m^.owner,m1^.owner)) 
             and (sqrt(m^.units)+sqrt(m1^.units)>distance(m1^.x,m1^.y,m^.x,m^.y)) then begin
            while ((m<>NIL) and (m1<>NIL)) do begin
              dec(m^.units,1); dec(m1^.units,1);
              if (m^.units<=0) then m:=NIL;      {Exploded}
              if (m1^.units<=0) then m1:=NIL;
            end;
          end;
        end;
      end;
    end;
  end;
  for i:=1 to 500 do begin
    m:=mine2[i];                {Simulated Data}
    m1:=TTurn^.data^.mines[i];  {Original Data}
    if (m<>NIL) then begin
      Abs2Scr(m^.x,m^.y,xx,yy);
{      SetColor(IIF(showM,RaceColor[owner,_M_],Black));}
      SetColor(DarkGray);
      SetTextJustify(Centertext,TopText);
      if UseSmallFont then SetTextStyle(SmallFont,HorizDir,4);
      if (m^.units>0) then
        begin
        DrawWCircle(xx,yy,trunc(Sqrt(MaxL(m^.units,0))*ratio2/ratio1));
        {Show Decayed Mines? Quapla - at last i think no, 24.5.13
        if (m^.web and 1=0) then m^.units:=Trunc(m^.units*(100.0-MineDecayRate)/100.0)
        else m^.units:=Trunc(m^.units*(100.0-WebMineDecayRate)/100.0);
        DrawWCircle(xx,yy,Round(Sqrt(MaxL(m^.units,0))*ratio2/ratio1)); }
        if IsAllied(2,player,m^.owner) then DrawMark(xx,yy,DarkGray,mrkPoint)
                                       else DrawMark(xx,yy,DarkGray,mrkSkull);
        OutTextXY(xx,yy,'R: '+Nstr0(Round(Sqrt(MaxL(m^.units,0)))));
        end
      else begin
        DrawMark(xx,yy,DarkGray,mrkCactus);
        OutTextXY(xx,yy,'Swept Out');
        end;
{      if (i=39) or (i=105) then write(i,' ',TTurn^.data^.mines[i]^.units,' ',m^.units,' ',m^.web,
      ' ',m^.web and 1,' // '); Quapla}
      SetTextJustify(LeftText,TopText);
 	    if UseSmallFont then SetTextStyle(DefaultFont,HorizDir,1);
      SetColor(black);
      if (m1<>NIL) then begin
        if (m^.web and 1=0) then m^.units:=Trunc(m1^.units*(100.0-MineDecayRate)/100.0)
        else m^.units:=Trunc(m1^.units*(100.0-WebMineDecayRate)/100.0);
        DrawWCircle(xx,yy,Round(Sqrt(MaxL(m^.units,0))*ratio2/ratio1))
      end;
    end;
  end;
  for i:=1 to NUM_SHIPS do begin
    if not shipok[i] then begin
      s:=TTurn^.data^.ship[i];
      Abs2Scr(s^.x,s^.y,xx,yy);
      DrawMark(xx,yy,DarkGray,mrkFlag);
    end;
  end;
  SetViewPort(0,0,639,479,ClipOn);
  DrawMap(No);
  MouseDisabled:=False;
  MouseOn;
  for i:=1 to 500 do
    if (mine2[i]<>NIL) then
      Dispose(mine2[i]);
end;

procedure ResetShipsInWarp;
var i,pn,tow:integer;
    s:sptr;
    str:string[20];
begin
  MouseMove;
  {MouseOff;}
  MouseDisabled:=True;
  ClearInfo;
  SetColor(White);
  OutTextXY(MX0,72,'Really reset all');
  OutTextXY(MX0,80,'InWarp-Ships (Y/n)?');
  str:=GetStr(MX0,96,18);
  MouseDisabled:=False;
  {MouseOn;}

  if (str='') or (str[1]='y') or (str[1]='Y') then begin
    for i:=1 to NUM_SHIPS do begin
      s:=TTurn^.data^.ship[i];
      if ((s<>NIL)) then begin
        with s^ do begin
          pn:=PSearchXY(x,y);
          tow:=UnderTow(i);
          if ((s^.owner=player) and (pn<>0) and (warp>1) and
              ((wx<>0) or (wy<>0)) and (tow=0) and
              (abs(wx)<=GravityRange) and (abs(wy)<=GravityRange)) then begin
            wx:=0;
            wy:=0;
            ChangeData(Sh,i);
          end;
        end;
      end;
    end;
  end;
  ClearInfo;
  MouseMove;
  DrawMap(Yes);
end;

procedure OKShip(mark:integer);
{ BBU: OKShip marks ships which have got their orders
 from the player and allows switching to the next ship
 in the area by distance and not by ID-number }
var   n,n0,i,l1,l2,x,y : int;
   ps                  : sptr;
   pp                  : pptr;
   d,mind              : longint;
begin
   n:=lock and LockLo;
   if (lock and LockS)=LockS then begin
      l1:=LockSkipS;
      l2:=LockS;
      x:=lship^.x;
      y:=lship^.y;
   end else begin
      if (lock and LockP)=LockP then begin
         l1:=LockSkipP;
         l2:=LockP;
         x:=TTurn^.data^.xyplan[n,1];
         y:=TTurn^.data^.xyplan[n,2];
      end else
         Exit;
   end;
   if (mark<0) then begin
      { Clear skip-markers }
      for i:=1 to NUM_MAX do begin
         if (actlist[i] and l1)=l1 then
            actlist[i]:=actlist[i] and not l1;
      end;
      Exit;
   end;
   if (mark=1) then
      actlist[n]:=actlist[n] or l1;
   if (mark=2) then
      actlist[n]:=actlist[n] or l2;
   n0:=n;
   mind:=10000;
   n:=-1;
   for i:=1 to NUM_MAX do begin
      if l2=LockS then begin
         ps:=TTurn^.data^.ship[i];
         if ((ps<>NIL) and (i<>n0) and (ps^.when=turn) and
             SameOwner(lship^.owner,ps^.owner) and
             ((actlist[i] and (LockS or LockSkipS))=0)) then
         begin
            d:=Distance(x,y,ps^.x,ps^.y);
            if (d<mind) then begin
               mind:=d;
               n:=i;
            end;
         end;
      end else if l2=LockP then begin
         pp:=TTurn^.data^.planet[i];
         if ((pp<>NIL) and (i<>n0) and (pp^.when=turn) and
             (lplan^.owner=pp^.owner) and
             ((actlist[i] and (l1 or l2))=0)) then
         begin
            d:=Distance(x,y,TTurn^.data^.xyplan[i,1],TTurn^.data^.xyplan[i,2]);
            if (d<mind) then begin
               mind:=d;
               n:=i;
            end;
         end;
      end;
   end;
   if (n<0) then begin
      if (mark=3) then begin
         Exit;
      end;
      OKShip(-1);
      OKShip(3);
      Exit;
   end;
   {CenterMap(p^.x,p^.y,nO);}
   force:=n or l2;
   ForceKey:=13;
end;

const  showW19 = $01;
   showWgrav   = $02;
   showWmax    = $04;
   showWmaxG   = $08;
   showWallP   = $10;
   showWallS   = $20;
   showWon     = $80;

procedure DrawWarpCircles;

procedure DrawWarpCircle(x,y,warp : integer;grav : boolean;solid : integer);
var DWx,DWy,i,r : integer;
begin
   if (x<0) then Exit;
   if warp=0 then begin
      if (showW and showW19)>0 then begin
         for i:=1 to 9 do begin
            DrawWarpCircle(x,y,i,grav,solid);
         end;
      end else if (showW and showWmax)>0 then begin
         DrawWarpCircle(x,y,9,grav,-1);
      end else if (showW and showWmaxG)>0 then begin
         DrawWarpCircle(x,y,9,false,IIF(grav,0,-1));
         DrawWarpCircle(x,y,9,true ,IIF(grav,-1,0));
      end;
      Exit;
   end;
   abs2scr(x,y,DWx,DWy);
   r:=warp*warp;
   if grav then r:=r*2;
   r:=Trunc((r+0.9)*ratio2/ratio1);
   SetLineStyle(IIF((solid=warp) or (solid<0),SolidLn,DottedLn),0,NormWidth);
   DrawWXCircle(DWx,DWy,r);
end; { DrawWarpCircle }

procedure DrawWarpShip(ship : sptr);
var grav : boolean;
   x,y,w : integer;
begin
   if (IsShipFunc(lship^,hfGravitonic)) then  { FIXME: why does this read 'lship', not 'ship'? }
      grav:=true else grav:=false;
   x:=lship^.x;
   y:=lship^.y;
   w:=lship^.warp;
   DrawWarpCircle(x,y,0,grav,w);
end; { DrawWarpShip }

procedure DrawWarpPlanet(planet : integer);
var x,y,w : integer;
begin
   x:=TTurn^.data^.xyplan[planet,1];
   y:=TTurn^.data^.xyplan[planet,2];
   DrawWarpCircle(x,y,0,(showW and showWgrav)>0,0);
end; { DrawWarpPlanet }

var i  : integer;
   mdr : boolean;
   vp  : ViewPortType;

begin
   if ((showW and showWon)=0) then Exit;
   mdr:=mdraw;
   MouseOff;
   GetViewSettings(vp);
   SetViewPort(0,0,479,479,ClipOn);
   SetWriteMode(XORPut);
   SetColor(DarkGray);

   if (showW and showWallP)>0 then begin
      for i:=1 to NUM_PLANETS do
         DrawWarpPlanet(i);
   end;
   if (showW and (showWallP or showWallS))=0 then begin
      if (ltype=LockS) and (lship<>NIL) then begin
         DrawWarpShip(lship);
      end else if (ltype=LockP) then begin
         DrawWarpPlanet(lock and LockLo);
      end;
   end;
   DWdrawn:=not DWdrawn;
   SetWriteMode(NormalPut);
   SetViewPort(vp.x1,vp.y1,vp.x2,vp.y2,vp.clip);
   if mdr then MouseOn;
end; { DrawWarpCircles }

procedure DrawWarpCirclesSelect;
const maxline = 10;
   maxwidth   = 30;
var code : array[1..20] of byte;
   l : integer;
begin

   NewMenu;
   UnLockReservedMemory(MenuSize(10,10,10+8*maxwidth,maxline,Yes));
   l:=0;
   AddMenuItem('none',Yellow,No);
   l:=l+1;code[l]:=0;
   AddMenuItem('Current Max Normal+Gravitonic',Yellow,No);
   l:=l+1;code[l]:=showWmaxG;
   AddMenuItem('Current Max Normal',Yellow,No);
   l:=l+1;code[l]:=showWmax;
   AddMenuItem('Current Max Gravitonic',Yellow,No);
   l:=l+1;code[l]:=showWmax or showWgrav;
   AddMenuItem('Current 1-9 Normal',Yellow,No);
   l:=l+1;code[l]:=showW19;
   AddMenuItem('Current 1-9 Gravitonic',Yellow,No);
   l:=l+1;code[l]:=showW19 or showWgrav;
   { does anybody really want that?
   AddMenuItem('All Ships Normal or Gravitonic',Yellow,No);
   l:=l+1;code[l]:=showWmax or showWallS;
   AddMenuItem('All Planets Normal+Gravitonic',Yellow,No);
   l:=l+1;code[l]:=showWmaxG or showWallP;
   }
   ChooseMenu(10,10,10,10+8*maxwidth,maxline,White,Yellow,1,No,Yes,-1);
   If (MenuKey<>27) then
     if (MenuValue=1) then
        showW:=0 else
        showW:=code[MenuValue] or showWon;
   NewMenu;
   LockReservedMemory;
end; { DrawWarpCirclesSelect }

const  
   showYN      = $01;
   showYT      = $02;
   showYD      = $04;
   showYM      = $08;
   showYS      = $10;
   showYC      = $20;
   showYSC     = $40;
   showYNAT    = $80;
   showYAll    = $FF;

const
  Sshow        = 'Add    ';
  Srem         = 'Remove ';
  SonP         = ' on Planet';
  SN           = 'Neutronium';
  ST           = 'Tritanium';
  SD           = 'Duranium';
  SM           = 'Molybdenum';
  SS           = 'Supplies';
  SC           = 'Money';
  
procedure PlanetYnfoSelect;
const maxline = 10;
   maxwidth   = 33;
var code : array[1..20] of byte;
   l : integer;
   c : byte;
   s : array [1..7] of char;
begin

   NewMenu;
   UnLockReservedMemory(MenuSize(10,10,10+8*maxwidth,maxline,Yes));
   l:=0;
   l:=l+1;code[l]:=0;
   AddMenuItem('Show none',Yellow,No);
   l:=l+1;code[l]:=showYN;c:=l;
   if (showY and code[l]>0) then s:=Srem else s:=Sshow; 
   AddMenuItem(s+SN+SonP,c,No);
   l:=l+1;code[l]:=showYT;c:=l;
   if (showY and code[l]>0) then s:=Srem else s:=Sshow; 
   AddMenuItem(s+ST+SonP,c,No);
   l:=l+1;code[l]:=showYD;c:=l;
   if (showY and code[l]>0) then s:=Srem else s:=Sshow; 
   AddMenuItem(s+SD+SonP,c,No);
   l:=l+1;code[l]:=showYM;c:=l;
   if (showY and code[l]>0) then s:=Srem else s:=Sshow; 
   AddMenuItem(s+SM+SonP,c,No);
   l:=l+1;code[l]:=showYS;c:=l;
   if (showY and code[l]>0) then s:=Srem else s:=Sshow; 
   AddMenuItem(s+SS+SonP,c,No);
   l:=l+1;code[l]:=showYC;c:=l;
   if (showY and code[l]>0) then s:=Srem else s:=Sshow; 
   AddMenuItem(s+SC+SonP,c,No);
   l:=l+1;code[l]:=showYSC;c:=l;
   if (showY and code[l]>0) then s:=Srem else s:=Sshow; 
   AddMenuItem(s+SS+'+'+SC+SonP,c,No);
   l:=l+1;code[l]:=showYNat;c:=l;
   if (showY and code[l]>0) then s:=Srem else s:=Sshow; 
   AddMenuItem(s+'Natives'+SonP,c,No);
   l:=l+1;code[l]:=$FF;
   AddMenuItem('Show all',Yellow,No);

   ChooseMenu(10,10,10,10+8*maxwidth,maxline,White,Yellow,1,No,Yes,-1);
   If (MenuKey<>27) then
     if (MenuValue=1) then
        showY:=0 else begin
          showY:=(showY xor code[MenuValue]);
        end;
   NewMenu;
   LockReservedMemory;
end; { PlanetYnfoSelect }

procedure DrawPlanetYnfos;

procedure DrawYnfoCircle(x,y,r, clr : integer);
var DWx,DWy : integer;
begin
   if (x<0) then Exit;
   abs2scr(x,y,DWx,DWy);
   r:=Trunc((r+0.9)*ratio2/ratio1);
   SetLineStyle(UserBitLn,$3030,NormWidth);
   SetColor(clr);
   DrawWXCircle(DWx,DWy,r);
end; { DrawWarpCircle ThickWidth}

procedure DrawYnfoPlanet(planet : integer);
var x,y : integer;
begin
   x:=TTurn^.data^.xyplan[planet,1];
   y:=TTurn^.data^.xyplan[planet,2];

   if TTurn^.data^.planet[planet] <> NIL then
   with TTurn^.data^.planet[planet]^ do begin
   
    if ((showY and showYN>0) and (N>0)) then DrawYnfoCircle(x,y,trunc(sqrt(N)),2);
    if ((showY and showYT>0) and (T>0)) then DrawYnfoCircle(x,y,trunc(sqrt(T)),3);
    if ((showY and showYD>0) and (D>0)) then DrawYnfoCircle(x,y,trunc(sqrt(D)),4);
    if ((showY and showYM>0) and (M>0)) then DrawYnfoCircle(x,y,trunc(sqrt(M)),5);
    if ((showY and showYS>0) and (supplies>0)) then DrawYnfoCircle(x,y,trunc(sqrt(supplies)),6);
    if ((showY and showYC>0) and (funds>0)) then DrawYnfoCircle(x,y,trunc(sqrt(funds)),7);
    if ((showY and showYSC>0) and ((supplies+funds)>0)) then DrawYnfoCircle(x,y,trunc(sqrt(funds+supplies)),8);
    if ((showY and showYNat>0) and (natives>0)) then DrawYnfoCircle(x,y,trunc(sqrt(sqrt(natives))),9);
   end;
end; { DrawWarpPlanet }

var i  : integer;
   mdr : boolean;
   vp  : ViewPortType;

begin
   if (showY and showYall=0) then Exit;
   mdr:=mdraw;
   MouseOff;
   GetViewSettings(vp);
   SetViewPort(0,0,479,479,ClipOn);
   {SetWriteMode(XORPut);}
   for i:=1 to NUM_PLANETS do
         DrawYnfoPlanet(i);  
   {DWdrawn:=not DWdrawn;}
   {SetWriteMode(NormalPut);}
   SetViewPort(vp.x1,vp.y1,vp.x2,vp.y2,vp.clip);
   if mdr then MouseOn;
end; { DrawPlanetYnfos }

End.