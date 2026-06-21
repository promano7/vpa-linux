Unit	Details;	(* VPA Detailed Explanation *)

Interface

procedure DetailedInfo;

Implementation

uses	AuxF,StrF,Mouse,Keyboard,Screen,Graph,VPAData;

var	number	: int;

procedure ExplainPlanet;
  var	p	: pptr;
	ep	: EPln;
	newpln	: byte;
	s,s1	: string[40];
	iswas	: string[3];
	i,k,t0	: int;
  begin
    OutTextXY(0,20,'Planet '+NStr(number)+' - '+PlanName[number]);
    with TTurn^.data^ do
    begin
      p:=planet[number];
      ep:=eplan[number];
      newpln:=newplan[number];
    end;
    SetColor(LightGray);
    if (p=nil) and (ep.activity=0) then
    begin
      OutTextXY(0,40,'We know absolutely nothing about this planet');
      Exit;
    end;
    if p=nil then
    begin
      if ep.owner<>0 then
      begin
	if ep.when=turn then iswas:='is' else iswas:='was';
	s:=RaceFull[ep.owner]; RTrim(s);
	if ep.when=turn then s1:='now'
			else s1:=NStr(turn-ep.when)+Proper(turn-ep.when,' turn')+' ago';
	OutTextXY(0,40,'All we know about this planet is that it '+iswas);
	OutTextXY(0,48,'owned by '+s+' '+s1);
	k:=ep.activity and 7;
	if k>0 then
	begin
	  if k>5 then k:=0;
	  OutTextXY(0,56,'and there '+iswas+' '+Industry[k]+' industrial activity there');
	end;
      end;
    end
    else with p^ do
    begin
      i:=Max(when,ep.when);
      k:=when0;
      if (ep.when<>0) and (ep.when<when0) then k:=ep.when;
      if i=turn then
        begin
          OutTextXY(0,40,'Our information about this planet had been gathered ');
          s:='now'
      end else s:=NStr(turn-i);
      s:='('+s;
      if t0<>i then s:=s+' - '+NStr(turn-t0)+' trn ago'
      else if t0<>turn then s:=s+Proper(turn-t0,' turn')+' ago';
      s:=s+')';
      OutTextXY(MX0,88,s);
    end;
  end;

procedure ExplainShip;
  begin
  end;

procedure ExplainMines;
  begin
  end;

procedure ExplainIons;
  begin
  end;

procedure ExplainWormhole;
  begin
  end;

procedure DetailedInfo;
  var	mx,my	: int;
  begin
    if (lock=0) or (ltype=LockA) then Exit;
    MouseOff;
    MouseDisabled:=True;
    mx:=MouseX; my:=MouseY;
    Clear(0,0,479,479);
    SetColor(White);
    OutTextXY(0,0,'DETAILED EXPLANATION');
    Line(0,10,20*8-1,10);
    number:=lock and LockLo;
    case ltype of
      LockP	: ExplainPlanet;
      LockS	: ExplainShip;
      LockM	: ExplainMines;
      LockI	: ExplainIons;
      LockW	: ExplainWormhole;
    end;
    ReadKey;
    MoveMouseTo(mx,my);
    MouseDisabled:=False;
    MouseOn;
    ch:=2;	{ redraw map }
  end;

End.
