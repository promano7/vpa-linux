Unit	Scores;
{$V-}

Interface

uses	VPAData,AuxF;

type	Score2          =       array [1..11,1..2] of int;
	Scor	= record
		    sc	: ScoreList;
		    sl	: Score2;
		    pbp	: PBPList;
		  end;

procedure ArrangeScores (var sc:Scor);
procedure ReArrangeScores (var sc,sc0:Scor);
procedure WriteScores;

Implementation

uses	ptcgraph,StrF,Screen,Mouse,Keyboard;

const	RaceColor	: array [1..11] of byte =
			(White,Yellow,LightGreen,Brown,Cyan,LightMagenta,
			 LightGray,LightRed,Magenta,LightBlue,LightCyan);

function CalcScore (sc:Score4) : int;
  const kF      = 1;
	kP      = 10;
	kC      = 10;
	kB      = 120;
  begin
    CalcScore:=sc[1]*kP+sc[2]*kC+sc[3]*kF+sc[4]*kB;
  end;

procedure ArrangeScores (var sc:Scor);
  var   i,j,k,p	: int;
	s       : Score4;
  begin
    with sc do
    begin
      for i:=1 to 11 do
      begin
	sl[i,1]:=i;
	sl[i,2]:=CalcScore(sc[i]);
      end;
      for i:=1 to 10 do
	for j:=i+1 to 11 do
	  if sl[j,2]>sl[i,2] then
	  begin
	    s:=sc[i]; sc[i]:=sc[j]; sc[j]:=s;
	    p:=pbp[i]; pbp[i]:=pbp[j]; pbp[j]:=p;
	    k:=sl[i,1]; sl[i,1]:=sl[j,1]; sl[j,1]:=k;
	    k:=sl[i,2]; sl[i,2]:=sl[j,2]; sl[j,2]:=k;
	  end;
    end;
  end;

procedure ReArrangeScores (var sc,sc0:Scor);
  var	sc1	: Scor;
	i,j	: byte;
  begin
    for i:=1 to 11 do
    begin
      j:=1;
      while sc0.sl[j,1]<>sc.sl[i,1] do inc(j);
      sc1.sc[i]:=sc0.sc[j];
      sc1.pbp[i]:=sc0.pbp[j];
      sc1.sl[i]:=sc0.sl[j];
    end;
    sc0:=sc1;
  end;

procedure DrawHistory;
  const	XSize	= 550;
	YSize	= 200;
	X0	= 54;
	Y0	= 465;
	Yn	= 10;
  var	t	: tptr;
	i,k,sc	: int;
	m1,m2	: int;
	t0	: int;
	dx,dy	: int;
	r	: array [1..11] of boolean;
  begin
    if (TRoot=nil) or (TRoot=TEnd) then Exit;
    SetColor(DarkGray);
    Rectangle(X0-1,Y0+1,X0+XSize,Y0-YSize);
    FillChar(r,11,No);
    t:=TRoot; m1:=20000; m2:=0;
    t0:=t^.turn;
    while t<>nil do
    begin
      for i:=1 to 11 do
      begin
	k:=CalcScore(t^.score[i]);
	if k>0 then
	begin
	  r[i]:=Yes;
	  m1:=Min(m1,k);
	  m2:=Max(m2,k);
	end;
      end;
      t:=t^.next;
    end;
    dx:=Max(XSize div (today-t0),1);	{ pixels per turn }
    dy:=(m2-m1) div YSize+1;    	{ points per pixel }
    for i:=1 to 11 do
      if r[i] then
      begin
	SetColor(RaceColor[i]);
	MoveTo(X0+(TRoot^.turn-t0)*dx,Y0-(CalcScore(TRoot^.score[i])-m1) div dy);
	t:=TRoot^.next;
	while t<>nil do
	begin
	  sc:=CalcScore(t^.score[i]);
	  if sc>0 then LineTo(X0+(t^.turn-t0)*dx,Y0-(sc-m1) div dy)
		  else MoveTo(X0+(t^.turn-t0)*dx,Y0-(sc-m1) div dy);
	  t:=t^.next;
	end;
      end;
    SetTextJustify(CenterText,TopText);
    SetColor(White);
    OutTextXY(X0+XSize div 2,Y0-YSize+16,'POWER GRAPH');
    SetColor(DarkGray);
    t:=TRoot; i:=0;
    while t<>nil do
    begin
      k:=X0+(t^.turn-t0)*dx;
      MoveTo(k,Y0+1);
      if k-i<32 then LineRel(0,2)
      else begin
	LineRel(0,3);
	OutTextXY(k,Y0+7,NStr(t^.turn));
	i:=k;
      end;
      t:=t^.next;
    end;
    SetTextJustify(RightText,CenterText);

    dx:=Max((((m2-m1) div Yn) div 5)*5,10);
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

procedure WriteScores;
  const	CX1	= 21*8+4;
	CX2	= 57*8+4;
	CX3	= 70*8+4;
  var	sc,sc0	: Scor;
	i,lnr	: byte;
	s	: string[20];
	s1,s2,s3,s4,s5,s6	: string[6];
	t,t0	: tptr;
	chh	: word;
	n1,n2,n3,n4	: int;
	n01,n02,n03,n04	: int;
	mx,my	: int;
	RName	: array [1..11,1..20] of char;
	f	: file;
        show    : boolean;
  procedure Clr;
    var	yy	: int;
    begin
      yy:=40+i*16+24+7;
      Clear(1,56-4,CX1-1,yy);
      Clear(CX1+1,56-4,CX2-1,yy);
      Clear(CX2+1,56-4,IIF(PHOST,638,CX3-1),yy);
      if not PHOST then Clear(CX3+1,56-4,638,yy);
    end;
  procedure DrawFirst;
    begin
      ClearDevice;
      SetLineStyle(SolidLn,0,NormWidth);
      SetColor(White);
      OutTextXY(640-22*8,0,'G A M E   S C O R E S');
      Line(640-22*8,9,637-8,9);
      if PHOST then s:='' else s:='P.B.P.';
      SetColor(LightGray);
      OutTextXY(0+4,32,'         Race name    Planets  Bases   Warships  Freight.  Score        '+s);
      Line(0,24,639,24);
      Line(0,47,639,47);
      Line(0,24,0,63);
      Line(CX1,24,CX1,55);
      Line(CX2,24,CX2,55);
      if not PHOST then Line(CX3,24,CX3,55);
      Line(639,24,639,55);
      DrawHistory;
    end;
  begin
    MouseOff;
    MouseDisabled:=True;
    mx:=MouseX; my:=MouseY;
    OpenData(f,'RACE.NM',Yes);
    Seek(f,11*30);
    BlockRead(f,RName,11*20);
    CloseData(f);
    DrawFirst;
    helpscr:=7;
    t:=TTurn;
    t0:=t^.prev;
    chh:=27;
    repeat
      s:=NStr(t^.turn);
      Clear(5*8,0,5*8+24*8-1,7);
      SetColor(White);
      OutTextXY(0,0,'Turn '+s);
      if t0<>nil then
      begin
        SetColor(DarkGray);
        OutTextXY(5*8+byte(s[0])*8+8,0,'(compared to '+NStr(t0^.turn)+')');
      end;
      sc.sc:=t^.score;
      FillChar(sc.pbp,SizeOf(PBPList),$FF);
      if t^.IsPBP then sc.pbp:=t^.PBP;
      ArrangeScores(sc);
      if t0<>nil then
      begin
        sc0.sc:=t0^.score;
        FillChar(sc0.pbp,SizeOf(PBPList),$FF);
        if t0^.IsPBP then sc0.pbp:=t0^.PBP;
        ArrangeScores(sc0);
        RearrangeScores(sc,sc0);
      end;
      n1:=0; n2:=0; n3:=0; n4:=0;
      n01:=0; n02:=0; n03:=0; n04:=0;
      i:=1;
      lnr:=1;
      while (i<=11) {and ((sc.sl[i,2]<>0) or (sc0.sl[i,2]<>0))} do
      begin
        show:=((sc.sl[i,2]<>0) or (sc0.sl[i,2]<>0));
	with sc do
	begin
	  inc(n1,sc[i,1]);
	  inc(n2,sc[i,4]);
	  inc(n3,sc[i,2]);
	  inc(n4,sc[i,3]);
	  s:=RName[sl[i,1]]; Trim(s); LPad(s,20);
	  s1:=NStrMax(sc[i,1],3,'+');
	  s2:=NStrMax(sc[i,4],3,'+');
	  s3:=NStrMax(sc[i,2],3,'+');
	  s4:=NStrMax(sc[i,3],3,'+');
	  s5:=NStrMax(sl[i,2],5,'+');
	  if pbp[i]<>-1 then s6:=NStrMax(pbp[i],3,'+') else s6:='';
	  SetColor(RaceColor[sl[i,1]]);
          if show then begin
	    OutTextXY(0+4,40+lnr*16,s+'  '+s1+'     '+s2+'      '+s3+'      '+s4+'       '+s5+'        '+s6);
	    {12345678901234567890  PPP(+19)BBB(+11) CCC(+19) FFF(+19)  SSSSS(+111) PBP(-12)}
	    if sl[i,1]=player then Rectangle(2,36+lnr*16,637,51+lnr*16);
          end;
	end;
	if t0<>nil then
	begin
	  inc(n01,sc0.sc[i,1]);
	  inc(n02,sc0.sc[i,4]);
	  inc(n03,sc0.sc[i,2]);
	  inc(n04,sc0.sc[i,3]);
	  s1:=NStrDiff(sc.sc[i,1]-sc0.sc[i,1],2);
	  s2:=NStrDiff(sc.sc[i,4]-sc0.sc[i,4],2);
	  s3:=NStrDiff(sc.sc[i,2]-sc0.sc[i,2],2);
	  s4:=NStrDiff(sc.sc[i,3]-sc0.sc[i,3],2);
	  s5:=NStrDiff(sc.sl[i,2]-sc0.sl[i,2],3);
	  if (sc.pbp[i]<>-1) and (sc0.pbp[i]<>-1) then s6:=NStrDiff(sc.pbp[i]-sc0.pbp[i],2) else s6:='';
	  SetColor(DarkGray);
          if show then
	    OutTextXY(20*8+4,40+lnr*16,'     '+s1+'   '+s2+'    '+s3+'    '+s4+'       '+s5+'     '+s6);
	    {  PPP(+19)BBB(+11) CCC(+19) FFF(+19)  SSSSS(+111)  PB(-12)}
	end;
	inc(i);
        if show then inc(lnr);
      end;
      i:=11;
      dec(lnr);
      SetColor(LightGray);
      Line(0,56-4,0,56+lnr*16);
      Line(CX1,56-4,CX1,56+lnr*16);
      Line(CX2,56-4,CX2,56+lnr*16);
      if not PHOST then Line(CX3,56-4,CX3,56+lnr*16);
      Line(639,56-4,639,56+lnr*16);
      Line(0,56+lnr*16,639,56+lnr*16);
      Clear(0,56+lnr*16+1,639,40+11*16+24+7);
      s1:=NStrMax(n1,3,'+');
      s2:=NStrMax(n2,3,'+');
      s3:=NStrMax(n3,3,'+');
      s4:=NStrMax(n4,3,'+');
      s5:=NStrMax(n3+n4,3,'+');
      OutTextXY(14*8+4,40+lnr*16+24,'Total:  '+s1+'     '+s2+'      '+s3+'      '+s4+'       Total ships: '+s5);
      {Total:  PPP(+19)BBB(+11) CCC(+19) FFF(+19)  Total ships: AAA(+12)}
      if t0<>nil then
      begin
	s1:=NStrDiff(n1-n01,2);
	s2:=NStrDiff(n2-n02,2);
	s3:=NStrDiff(n3-n03,2);
	s4:=NStrDiff(n4-n04,2);
	s5:=NStrDiff(n3+n4-n03-n04,2);
	SetColor(DarkGray);
	OutTextXY(14*8+4,40+lnr*16+24,'           '+s1+'   '+s2+'    '+s3+'    '+s4+'                  '+s5);
	{Total:  PPP(+19)BBB(+11) CCC(+19) FFF(+19)  Total ships: AAA(+12)}
      end;
      chh:=ReadKey;
      case chh of
	ord('-'),ord('_')
		: if KbdFlags and KbdShft=0 then
		  begin
		    if t^.prev<>nil then
		    begin
		      t:=t^.prev;
		      if t0=t then t0:=t0^.prev;
		      Clr;
		    end;
		  end
		  else if (t0<>nil) and (t0^.prev<>nil) then
			 begin t0:=t0^.prev; Clr end;
	ord('+'),ord('=')
		: if KbdFlags and KbdShft=0 then
		  begin
		    if t^.next<>nil then
		    begin
		      if t0=t^.prev then t0:=t;
		      t:=t^.next;
		      Clr;
		    end;
		  end
		  else if (t0<>nil) and (t0^.next<>nil) and (t0^.next<>t) then
			 begin t0:=t0^.next; Clr end;
	$8E00	: if t<>TRoot then begin t:=TRoot; t0:=nil; Clr end;
	$9000	: if t<>TEnd then begin if t0=t^.prev then t0:=TEnd^.prev;
					t:=TEnd; Clr			end;
	$3B00	: begin
		    ClearDevice;
		    Help;
		    DrawFirst;
		  end;
      end;
    until chh=27;
    helpscr:=0;
    DrawRightScreen;
    MoveMouseTo(mx,my);
    MouseDisabled:=False;
    MouseOn;
    ResetMouse;
    if lock<>0 then begin force:=lock; ForceKey:=13 end;
    ch:=2;		{ redraw map }
  end;

End.
