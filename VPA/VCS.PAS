Unit	VCS;		(* Video Combat Simulator *)
{$V-}
{A-}

Interface

procedure InitVCR;
procedure CombatSimulation;

Implementation

uses	VPAData,ptcgraph,Screen,Mouse,Keyboard,StrF,AuxF,TCombat;

type    CArr20	= array [1..20] of char;
	VRec	= record
		    shpw	: int;
		    name	: CArr20;
		    dam,crew	: int;		{ pln: crew=base? (0 or 100) }
		    w0		: int;
		    owner	: word;
		    pic		: word;
		    Wl,weaps,bays,Tl,TFn,launs	: int;  { pln: launs=base def }
		    shld	: int;                  {      Tl   =base dam }
		    El		: byte;
		    hull	: byte;
		  end;

var	WName	: array [1..10,1..6] of char;
const	VRSize	= SizeOf(VRec);
	SX	: array [LRType] of int = (16,304);
	RName	: array [1..5,1..6] of char = ('Fed','Lizard','Usual','','Privat');
	PBName1	: CArr20 = 'PLANET WITH BASE    ';
	PBName2	: CArr20 = 'PLANET WITHOUT BASE ';
	RY	= 200;
	RX	= 20;
	RFPlan	: array [1..12] of byte = (1,2,3,4,24,25,26,39,40,41,42,43);
	RFBase	= 23;
	RR	: byte = 1;
	halpha	: array [LRType] of byte = (0,0);
	VPAVCR	: array [1..10] of char = 'VPAVCR.INI';
	INISize	= VRSize*2+1+1+1+1+2+1;
	VCStPos	= VRSize*2;
	VCSpPos	= VRSize*2+1+1+1;

const	WNSkipChars	: array [1..5] of char = 'aeiou';

procedure InitVCR;
  var	f	: file;
	i	: byte;
	s	: string[18];
	ls	: byte absolute s;
  begin
    RR:=Random(118)+1;
    if OpenRW(f,VPAVCR,No) then
    begin
      if FileSize(f)<>INISize then
	begin CloseData(f); Erase(f) end
      else begin
	Seek(f,VCStPos);
	BlockRead(f,VCSet,1);
	Seek(f,VCSpPos);
	BlockRead(f,VCSpeed,1);
	if not (VCSpeed in [1..9]) then VCSpeed:=5;
	CloseData(f);
      end;
    end;
    for i:=1 to 10 do
    begin
      s:=Beams[i].name;
      StrSubst(s,'Heavy ','H.');
      if (ls>6) and (Pos(s[6],WNSkipChars)<>0) and
	 (s[7]<>' ') and (Pos(s[7],WNSkipChars)=0) then Delete(s,6,1);
  { ('Laser ','X-Ray ','Plasma','Blastr','Positr','Disrup','H.Blas','Phaser','H.Disr','H.Phas');}
      Move(s[1],WName[i,1],6);
    end;
  end;

PROCEDURE CombatSimulation;

var	v	: array [LRType] of VRec;
	sett	: byte;
	wl0,tl0	: byte;
	el0	: byte;
	rhull0	: byte;
	d	: VCRData;
	result	: boolean;
	bfn	: int;
	alw_rnd	: int;

procedure InitVCS;
  var	f	: file;
  begin
    FillChar(v,VRSize*2,0);
    v[Left].name[20]:=' ';
    v[Right].name[20]:=' ';
    el0:=0;
    alw_rnd:=Random(1000);

    if OpenRW(f,VPAVCR,No) then
    begin
      BlockRead(f,v,VRSize*2);
      BlockRead(f,VCSet,1);
      VCSet:=(VCSet and $FE) or (byte(not FedCrew) and 1);
      if PHOST then VCSet:=VCSet or 4;
      BlockRead(f,wl0,1);
      if not (wl0 in [1..10]) then wl0:=10;
      BlockRead(f,tl0,1);
      if not (tl0 in [1..10]) then tl0:=10;
      BlockRead(f,VCSpeed,1);
      if not (VCSpeed in [1..9]) then VCSpeed:=5;
      BlockRead(f,halpha,2);
      if not (halpha[Right] in [1..105]) then
	begin halpha[Left]:=1; halpha[Right]:=1 end;
      BlockRead(f,rhull0,1);
      if not (rhull0 in [1..105]) then rhull0:=1;
      CloseData(f);
    end;
  end;

const   HeadX	= 21*8;
	StartX	= 25*8;
	StartY	= 248;
	VersusX	= 26*8;
	VersusY	= 56;
	PromptY	= 460;
	SettX	= 640-18*8;
	SettY	= 230;
	ResultX	= 26*8;
	ResultY	= 308;
	ResY	= 320;
	ResGX	= 15;
	ResGY	= ResY+10;
	ViewX	= 27*8;
	ViewY	= 272;

procedure WriteAtt;
  var	s	: string[38];
  begin
    SetColor(_Yellow);
    OutTextXY(HeadX,0,'COMBAT SIMULATOR');
    SetLineStyle(SolidLn,0,NormWidth);
    Line(HeadX,12,HeadX+16*8-1,12);
    OutTextXY(StartX,StartY,'S');
    OutTextXY(48,PromptY,'Enter  +     -                       Tab');
    OutTextXY(SettX+8,SettY+12,'E');
    OutTextXY(SettX+8,SettY+2*12,'F');
    OutTextXY(SettX+6*8,SettY+3*12,'L');
    OutTextXY(SettX+2*8,SettY+4*12,'o');
    OutTextXY(SettX+8,SettY+5*12,'A');
    OutTextXY(SettX+8*8,SettY+6*12,'1 9');
    SetColor(White);
    OutTextXY(VersusX,VersusY,'versus');
    OutTextXY(SettX,SettY,'Settings:');
    Clear(SettX+14*8,SettY+12,SettX+18*8-1,SettY+6*12+7);
    if ESBonus=0 then s:='OFF' else s:=NStr(ESBonus)+'%';
    OutTextXY(SettX+2*8,SettY+12,'ngine bonus '+s);
    if VCSet and 1=0 then s:='ON' else s:='OFF';
    OutTextXY(SettX+2*8,SettY+2*12,'ed bonus    '+s);
    if VCSet and 4=0 then s:='ON' else s:='OFF';
    OutTextXY(SettX+8,SettY+3*12,'Anti- eftWin '+s);
    if VCSet and 8=0 then s:='OFF' else s:='ON';
    OutTextXY(SettX+8,SettY+4*12,'S und        '+s);
    if VCSet and 2=0 then s:='ON' else s:='OFF';
    OutTextXY(SettX+2*8,SettY+5*12,'nimation    '+s);
    OutTextXY(SettX+8,SettY+6*12,'Speed ( - )  '+chr(VCSpeed+ord('0')));
    OutTextXY(StartX+8,StartY,'IMULATE');
    OutTextXY(0,PromptY,'Press      ,   and   to modify parameters,     to swap ships');
    OutTextXY(48,PromptY+12,'Space to accept');
    s:='locked known ship/planet (if any)';
    if (ltype=LockP) or (ltype=LockS) then
    begin
      if ltype=LockP then
      begin
	if TTurn^.data^.planet[lock and LockLo]<>nil then
	  s:='planet '+PlanName[lock and LockLo];
      end
      else if (lship<>nil) and (lship^.hull>0) then
	begin
	  s:=Hulls[lship^.hull].name; Trim(s);
	  if lship^.name[1]<>' ' then
	  begin
	    s:=s+' "'+lship^.name;
	    RTrim(s); s:=s+'"';
	  end;
	end;
      SetColor(_Yellow);
      OutTextXY(48,PromptY+12,'Space');
    end;
    SetColor(White);
    OutTextXY(176,PromptY+12,s);
  end;

procedure ClearResult;
  begin
    if result then
    begin
      Clear(0,ResultY,479,ResY+4*12+7);
      Clear(ViewX,ViewY,ViewX+4*8-1,ViewY+7);
      result:=Off;
    end;
  end;

procedure ClearStats;
  begin
    Clear(0,ResY+5*12,639,ResY+6*12+7);
  end;

procedure WriteResult;
  var	s	: string[4];
	lr	: LRType;
	x	: int;
  begin
    ClearResult;
    SetColor(_Yellow);
    OutTextXY(ResultX,ResultY,'R');
    OutTextXY(ViewX,ViewY,'V');
    SetColor(White);
    OutTextXY(ResultX+8,ResultY,'esult');
    OutTextXY(ViewX+8,ViewY,'iew');
    for lr:=Left to Right do
    with d.dd[lr] do
    begin
      SetColor(White);
      Str(d.shld[lr],s);
      OutTextXY(SX[lr],ResY,'Shield      : '+s+'%');
      Str(dam,s);
      OutTextXY(SX[lr],ResY+12,'Damage      : '+s+'%');
      if (lr=Left) or (d.planet=0) then
      begin
	Str(crew,s);
	OutTextXY(SX[lr],ResY+2*12,'Crew        : '+s);
	Str(tfn,s);
	if v[lr].bays>0 then OutTextXY(SX[lr],ResY+3*12,'Fighters    : '+s)
	else if v[lr].launs>0 then OutTextXY(SX[lr],ResY+3*12,'Torpedoes   : '+s);
      end
      else begin
	Str(Max(v[Right].shpw-Round(v[Right].shpw*dam/100)-Max(bfn-tfn-v[Right].TFn,0),0),s);
	OutTextXY(SX[Right],ResY+2*12,'Defense     : '+s);
	if v[Right].crew<>0 then
	begin
	  Str(Max(v[Right].TFn-(bfn-tfn),0),s);
	  OutTextXY(SX[Right],ResY+3*12,'Fighters    : '+s);
	  Str(dam+v[Right].Tl,s);
	  OutTextXY(SX[Right],ResY+4*12,'Base damage : '+s+'%');
	end;
      end;
      x:=ResultX+IIF(lr=Left,-ResGX-24,6*8-2+ResGX);
      if pic=ExplPic then
      begin
	SetColor(_Red);
	SetLineStyle(SolidLn,0,ThickWidth);
	Line(x,ResGY,x+25,ResGY+25);
	Line(x,ResGY+25,x+25,ResGY);
	SetLineStyle(SolidLn,0,NormWidth);
      end
      else if pic=SurrPic then
      begin
	SetFillStyle(1,White);
	Bar(x,ResGY,x+25,ResGY+10);
	Line(x,ResGY+11,x,ResGY+25);
      end;
    end;
    result:=On;
  end;

procedure LoadPicture (lr:LRType);
  var	pic	: byte;
  begin
    Clear(SX[lr]+RX,RY,SX[lr]+RX+103,RY+103);
    pic:=v[lr].pic;
    if (pic<=0) or (pic>151) then pic:=111;
    LoadPic(lr,pic,pic in RotPic,(lr=Right) xor (pic in FliPic),Yes,Yes);
    SetPal;
  end;

procedure DrawPicture (lr:LRType);
  begin
  	if useSVGA then
  	begin
        convertImage(img[lr]^,img256);
        PutImage(SX[lr]+RX+(104-img[lr]^[1]) div 2,RY+(104-img[lr]^[3]) div 2,img256,NormalPut);
    end
    else
        PutImage(SX[lr]+RX+(104-img[lr]^[1]) div 2,RY+(104-img[lr]^[3]) div 2,img[lr]^,NormalPut);
  end;

procedure FillShip (lr:LRType; hull:word);
  begin
    if v[lr].weaps>0 then wl0:=v[lr].Wl;
    if v[lr].launs>0 then tl0:=v[lr].Tl;
    el0:=v[lr].El; if not (el0 in [1..9]) then el0:=9;
    FillChar(v[lr],VRSize,0);
    with Hulls[hull] do
    begin
      v[lr].hull:=hull;
      v[lr].shpw:=mass;
      FillChar(v[lr].name,20,' ');
      Move(name[1],v[lr].name,18);
      v[lr].dam:=0;
      v[lr].crew:=crew;
      v[lr].w0:=0;
      v[lr].owner:=IIF(hull in [1..13,19,20],1,
		   IIF(hull in [21..25,49],2,
		   IIF(hull in [42..46,50],5,3)));
      v[lr].pic:=pic;
      LoadPicture(lr);
      v[lr].weaps:=weapons;
      if weapons>0 then	v[lr].Wl:=IIF(wl0 in [1..10],wl0,10);
      v[lr].bays:=bays;
      v[lr].launs:=launchers;
      if launchers>0 then v[lr].Tl:=IIF(tl0 in [1..10],tl0,10);
      if (bays or launchers)<>0 then v[lr].TFn:=cargo;
      if (weapons or bays or launchers)<>0 then v[lr].shld:=100;
      v[lr].El:=el0;
    end
  end;

procedure DrawPln;
  var	s	: string[6];
  begin
    SetColor(White);
    with v[Right] do
    begin
      Str(shpw,s);
      OutTextXY(SX[Right],72,'Defense     : '+s);
      Str(shld:3,s);
      OutTextXY(SX[Right],84 ,'Shield      : '+s+'%');
      OutTextXY(SX[Right],96,'Base        : '+chr(IIF(crew=0,ord('N'),ord('Y'))));
      if crew<>0 then
      begin
	Str(launs,s);
	OutTextXY(SX[Right],108,' Defense    : '+s);
	Str(Tl:3,s);
	OutTextXY(SX[Right],120,' Damage     : '+s+'%');
	Str(Wl,s);
	OutTextXY(SX[Right],132,' Weapon lvl : '+s);
	Str(TFn,s);
	OutTextXY(SX[Right],144,' Fighters   : '+s);
      end
      else Clear(SX[Right],108,SX[Right]+20*8-1,144+7);
      OutTextXY(SX[Right],192,'Owning race : '+RName[owner]);
      if crew=0 then pic:=RFPlan[Random(12)+1]
		else pic:=RFBase;
      LoadPicture(Right);
      DrawPicture(Right);
    end;
    OutTextXY(SX[Right],44,'Planet');
  end;

procedure DrawShip (lr:LRType);
  var	s	: string[4];
  begin
    with v[lr] do
    begin
      Clear(SX[lr]-8,44,SX[lr]+20*8-1,199);
      SetColor(_Yellow);
      if name[1]=#0 then
      begin
	OutTextXY(SX[lr],56,'<None>');
	Exit;
      end;
      OutTextXY(SX[lr],56,name);
      if hull=0 then begin DrawPln; Exit end;
      SetColor(White);
      Str(shpw,s);
      OutTextXY(SX[lr],72 ,'Shield power: '+s);
      if (weaps or bays or launs)<>0 then
      begin
	Str(shld:3,s);
	OutTextXY(SX[lr],84 ,'Shield      : '+s+'%');
      end;
      Str(dam:3,s);
      OutTextXY(SX[lr],96 ,'Damage      : '+s+'%');
      Str(crew,s);
      OutTextXY(SX[lr],108,'Crew        : '+s);
      Str(El,s);
      OutTextXY(SX[lr],120,'Engine level: '+s);
      if Wl>0 then
      begin
	OutTextXY(SX[lr],132,'Weapon level: '+WName[Wl]);
	Str(weaps,s);
	OutTextXY(SX[lr],144,'Weapons     : '+s);
      end;
      if Tl>0 then
      begin
	OutTextXY(SX[lr],156,'Torp. level : '+Torps[Tl].name);
	Str(launs,s);
	OutTextXY(SX[lr],168,'T-Launchers : '+s);
	Str(TFn,s);
	OutTextXY(SX[lr],180,'Torpedoes   : '+s);
      end;
      if bays>0 then
      begin
	Str(bays,s);
	OutTextXY(SX[lr],168,'Fighter bays: '+s);
	Str(TFn,s);
	OutTextXY(SX[lr],180,'Fighters    : '+s);
      end;
      OutTextXY(SX[lr],192,'Owning race : '+RName[owner]);
      DrawPicture(lr);
    end;
    if lr=Right then OutTextXY(SX[Right],44,'Ship');
  end;

procedure GetResult;
  var	lr	: LRType;
  begin
    for lr:=Left to Right do
    with d.dd[lr] do
      if not (pic in [ExplPic,SurrPic]) then
      begin
	v[lr].shld:=d.shld[lr];
	if (lr=Left) or (d.planet=0) then
	begin
	  v[lr].dam:=dam;
	  v[lr].crew:=crew;
	  v[lr].tfn:=tfn;
	end
	else begin
	  v[Right].shpw:=Max(v[Right].shpw-Round(v[Right].shpw*dam/100)-Max(bfn-tfn-v[Right].TFn,0),0);
	  if v[Right].crew<>0 then
	  begin
	    v[Right].launs:=Max(v[Right].launs-Round(v[Right].launs*dam/100),0);
	    v[Right].Wl:=Max(v[Right].Wl-Round(v[Right].Wl*dam/100),1);
	    v[Right].TFn:=Max(v[Right].TFn-(bfn-tfn),0);
	    inc(v[Right].Tl,dam);
	    if v[Right].Tl>99 then
	    begin
	      v[Right].crew:=0;
	      v[Right].name:=PBName2;
	      v[Right].launs:=0;
	      v[Right].Tl:=0;
	      v[Right].dam:=0;
	      v[Right].TFn:=0;
	    end;
	  end;
	end;
	DrawShip(lr);
      end;
  end;

procedure ModShip (lr:LRType; n:byte);

  function EnterRace (x,y,ha0:int; restore: boolean) : int;
    const xsize=8; lines=4; cI=White; cH=Yellow; cB=White;
    var   i : int;
    begin
      NewMenu;
      for i:=1 to 5 do if i<>4 then AddMenuItem(RName[i],cI,Yes);
      ChooseMenu(x,y,x,x+xsize*8,lines,cB,cH,ha0,No,restore,-1);
      if (MenuKey=13) and (MenuValue>0) and (MenuValue<=4) then begin
        for i:=1 to 5 do if RName[i]=MenuString then 
          begin  EnterRace:=i; Break;  end;
      end else EnterRace:=ha0;
      NewMenu;
    end;

  var	s	: str20;
	ls	: byte absolute s;
	a	: int;
	i,k	: word;
	x1,x2,y	: int;
	nlr	: LRType;
  begin
    nlr:=LRtype(byte(lr) xor 1);
    case n of
      0	: begin				{ ship/planet }
	    rhull0:=v[Right].hull;
	    v[Right].hull:=0;
	    v[Right].name:=PBName1;
	    v[Right].shpw:=100;
	    v[Right].shld:=100;
	    v[Right].crew:=100;
	    v[Right].launs:=10;
	    v[Right].Tl:=0;
	    v[Right].Wl:=1;
	    v[Right].TFn:=20;
	    if not (v[Right].owner in [1,2,3,5]) then v[Right].owner:=3;
	    DrawShip(Right);
	  end;
      1	: begin				{ hull }
	    x1:=SX[lr]; x2:=x1+20*8-1; y:=56;
	    MenuHiliteColor:=_Gray;
	    k:=EnterHull(x1,y,halpha[lr],No);
	    MenuHiliteColor:=DefaultHilite;
	    if (MenuKey=13) and (k in [1..105]) then
	      begin FillShip(lr,k); halpha[lr]:=MenuValue end;
	    DrawShip(lr);
	  end;
      3	: if (v[lr].weaps or v[lr].bays or v[lr].launs)<>0 then	{ shield }
	  begin
	    x1:=SX[lr]+14*8; x2:=x1+3*8-1; y:=84;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,3);
	    Val(s,k,a);
	    if (k>0) or ((k=0) and (s[1]='0')) then v[lr].shld:=k;
	    v[lr].shld:=Max(0,Min(v[lr].shld,100-IIF(v[lr].owner=2,Max(v[lr].dam-50,0),v[lr].dam)));
	    Clear(x1,y,x2,y+7);
	    Str(v[lr].shld:3,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      4	: begin					{ damage }
	    x1:=SX[lr]+14*8; x2:=x1+3*8-1; y:=96;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,3);
	    Val(s,k,a);
	    if (k>0) or ((k=0) and (s[1]='0')) then v[lr].dam:=Min(k,IIF(v[lr].owner=2,150,99));
	    v[lr].shld:=Max(0,Min(v[lr].shld,100-IIF(v[lr].owner=2,Max(v[lr].dam-50,0),v[lr].dam)));
	    DrawShip(lr);
	  end;
      5	: begin					{ crew }
	    x1:=SX[lr]+14*8; x2:=x1+4*8-1; y:=108;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,4);
	    Val(s,k,a);
	    if k>0 then v[lr].crew:=Min(k,Max(Hulls[v[lr].hull].crew,10));
	    Clear(x1,y,x2,y+7);
	    Str(v[lr].crew,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      6 : begin                                 { El }
            x1:=SX[lr]+14*8; x2:=x1+8-1; y:=120;
            case ch of
              ord('-'): if (v[lr].El>1) then dec(v[lr].El);
              ord('+'): if (v[lr].El<9) then inc(v[lr].El);
              13 : begin
                     MenuHiliteColor:=_Gray;
                     k:=EnterEngine(x1,y,v[lr].El,Yes);
                     MenuHiliteColor:=DefaultHilite;
                     if (MenuKey=13) and (MenuValue<>v[lr].El) and (k in [1..9]) then
                       v[lr].El:=MenuValue
            end;   end;
            Clear(x1,y,x2,y+7);
            SetColor(White);
            OutTextXY(x1,y,chr(ord('0')+v[lr].El));
          end;
      7 : if (v[lr].weaps>0) then begin         { Wl }
            x1:=SX[lr]+14*8; x2:=x1+6*8-1; y:=132;
            case ch of 
              ord('-') : if (v[lr].Wl>1) then dec(v[lr].Wl);
              ord('+') : if (v[lr].Wl<10) then inc(v[lr].Wl);
              13 : begin
                     MenuHiliteColor:=_Gray;
                     k:=EnterBeam(x1,y,v[lr].Wl,Yes);
                     MenuHiliteColor:=DefaultHilite;
                     if (MenuKey=13) and (MenuValue<>v[lr].Wl) and (k in [1..10]) then
                       v[lr].Wl:=MenuValue
            end;   end;
            Clear(x1,y,x2,y+7);
            SetColor(White);
            OutTextXY(x1,y,WName[v[lr].Wl]);
          end;
      8	: if (v[lr].weaps>=0) and			{ weaps }
	     (((ch=ord('-')) and (v[lr].weaps>0)) or
	     ((ch=ord('+')) and (v[lr].weaps<Hulls[v[lr].hull].weapons))) then
	  begin
	    x1:=SX[lr]+14*8; x2:=x1+2*8-1; y:=144;
	    if ch=ord('-') then dec(v[lr].weaps)
			   else inc(v[lr].weaps);
	    Clear(x1,y,x2,y+7);
	    SetColor(White);
	    Str(v[lr].weaps,s);
	    OutTextXY(x1,y,s);
	  end;
      9 : if (v[lr].launs>0) then begin         { Tl }
            x1:=SX[lr]+14*8; x2:=x1+6*8-1; y:=156;
            case ch of 
              ord('-') : if (v[lr].Tl>1) then dec(v[lr].Tl);
              ord('+') : if (v[lr].Tl<10) then inc(v[lr].Tl);
              13 : begin
                     MenuHiliteColor:=_Gray;
                     k:=EnterTorp(x1,y,v[lr].Tl,Yes);
                     MenuHiliteColor:=DefaultHilite;
                     if (MenuKey=13) and (MenuValue<>v[lr].Tl) and (k in [1..10]) then
                       v[lr].Tl:=MenuValue
            end;   end;
            Clear(x1,y,x2,y+7);
            SetColor(White);
            OutTextXY(x1,y,Torps[v[lr].Tl].name);
          end;
      10: if (v[lr].launs>=0) then		{ launs }
	  begin
	    if (((ch=ord('-')) and (v[lr].launs>0)) or
	       ((ch=ord('+')) and (v[lr].launs<Hulls[v[lr].hull].launchers))) then
	    begin
	      x1:=SX[lr]+14*8; x2:=x1+2*8-1; y:=168;
	      if ch=ord('-') then dec(v[lr].launs)
			     else inc(v[lr].launs);
	      Clear(x1,y,x2,y+7);
	      SetColor(White);
	      Str(v[lr].launs,s);
	      OutTextXY(x1,y,s);
	    end
	  end;
      11: if (v[lr].launs>0) or (v[lr].bays>0) then	{ t/f }
	  begin
	    x1:=SX[lr]+14*8; x2:=x1+3*8-1; y:=180;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,3);
	    Val(s,k,a);
	    if (k>0) or ((k=0) and (s[1]='0')) then v[lr].TFn:=Min(k,Hulls[v[lr].hull].cargo);
	    Clear(x1,y,x2,y+7);
	    Str(v[lr].TFn,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      12: begin						{ owner }
	    x1:=SX[lr]+14*8; x2:=x1+6*8-1;
	    y:=v[lr].owner;
          if (ch=13) then begin
            y:=IIF(y=5,3,IIF(y=3,4,y));
            MenuHiliteColor:=_Gray;
            y:=EnterRace(x1,192,y,Yes);
            MenuHiliteColor:=DefaultHilite;
            if (MenuKey=27) then y:=v[lr].owner;
	    end else repeat
	      if ch=ord('-') then dec(y) else inc(y);
	    until y<>4;
	    v[lr].owner:=IIF(y=0,5,IIF(y=6,1,y));
	    y:=192;
	    Clear(x1,y,x2,y+7);
	    SetColor(White);
	    OutTextXY(x1,y,RName[v[lr].owner]);
	  end;
    end;
  end;

procedure ModPln (n:byte);
  var	s	: str20;
	ls	: byte absolute s;
	a	: int;
	i,k	: int;
	x1,x2,y	: int;
  begin
    case n of
      0	: begin FillShip(Right,rhull0); DrawShip(Right) end;
      1 : if v[Right].crew=0 then DrawShip(Right);
      2	: begin					{ planetary defense }
	    x1:=SX[Right]+14*8; x2:=x1+3*8-1; y:=72;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,3);
	    Val(s,k,a);
	    if (k>0) or ((k=0) and (s[1]='0')) then v[Right].shpw:=k;
	    Clear(x1,y,x2,y+7);
	    Str(v[Right].shpw,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      3 : begin					{ shield }
	    x1:=SX[Right]+14*8; x2:=x1+3*8-1; y:=84;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,3);
	    Val(s,k,a);
	    if (k>0) or ((k=0) and (s[1]='0')) then v[Right].shld:=Min(k,100);
	    Clear(x1,y,x2,y+7);
	    Str(v[Right].shld:3,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      4 : if ((ch=ord('-')) and (v[Right].crew<>0)) or		{ base }
	     ((ch=ord('+')) and (v[Right].crew=0)) then
	  begin
	    x1:=SX[Right]+14*8; x2:=x1+1*8-1; y:=96;
	    v[Right].crew:=IIF(ch=ord('-'),0,100);
	    if v[Right].crew<>0 then v[Right].name:=PBName1
	    else begin
	      v[Right].name:=PBName2;
	      v[Right].launs:=0;
	      v[Right].Tl:=0;
	      v[Right].dam:=0;
	      v[Right].TFn:=0;
	    end;
	    Clear(x1,y,x2,y+7);
	    DrawPln;
	    SetColor(_Yellow);
	    Clear(SX[Right],56,SX[Right]+19*8-1,63);
	    OutTextXY(SX[Right],56,v[Right].name);
	  end;
      5	: if v[Right].crew<>0 then		{ base defense }
	  begin
	    x1:=SX[Right]+14*8; x2:=x1+3*8-1; y:=108;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,3);
	    Val(s,k,a);
	    if (k>0) or ((k=0) and (s[1]='0')) then v[Right].launs:=Min(k,GetMaxDefenseOnBase(v[Right].owner));
	    Clear(x1,y,x2,y+7);
	    Str(v[Right].launs,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      6	: if v[Right].crew<>0 then              { base damage }
	  begin
	    x1:=SX[Right]+14*8; x2:=x1+3*8-1; y:=120;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,3);
	    Val(s,k,a);
	    if (k>0) or ((k=0) and (s[1]='0')) then v[Right].Tl:=Min(k,99);
	    Clear(x1,y,x2,y+7);
	    Str(v[Right].Tl,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      7	: if (v[Right].crew<>0) and			{ base Wl }
	     (((ch=ord('-')) and (v[Right].Wl>1)) or
	      ((ch=ord('+')) and (v[Right].Wl<10))) then
	  begin
	    x1:=SX[Right]+14*8; x2:=x1+2*8-1; y:=132;
	    if ch=ord('-') then dec(v[Right].Wl)
			   else inc(v[Right].Wl);
	    Clear(x1,y,x2,y+7);
	    Str(v[Right].Wl,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      8	: if v[Right].crew<>0 then		{ base fighters }
	  begin
	    x1:=SX[Right]+14*8; x2:=x1+2*8-1; y:=144;
	    Clear(x1,y,x2,y+7);
	    s:=GetStr(x1,y,2);
	    Val(s,k,a);
	    if (k>0) or ((k=0) and (s[1]='0')) then v[Right].TFn:=Min(k,GetMaxFightersOnBase(v[Right].owner));
	    Clear(x1,y,x2,y+7);
	    Str(v[Right].TFn,s);
	    SetColor(White);
	    OutTextXY(x1,y,s);
	  end;
      12: begin				{ owner }
	    x1:=SX[Right]+14*8; x2:=x1+6*8-1;
	    y:=v[Right].owner;
	    repeat
	      if ch=ord('-') then dec(y) else inc(y);
	    until y<>4;
	    v[Right].owner:=IIF(y=0,5,IIF(y=6,1,y));
	    y:=192;
	    Clear(x1,y,x2,y+7);
	    SetColor(White);
	    OutTextXY(x1,y,RName[v[Right].owner]);
	  end;
    end;
  end;

procedure AcceptShip (lr:LRType);
  begin
    with lship^ do
    begin
      FillShip(lr,hull);
      if name[1]<>#$FF then Move(name,v[lr].name,20);
      if damage<>-1 then v[lr].dam:=damage;
      if crew<>-1 then v[lr].crew:=crew;
      v[lr].owner:=IIF(Race[owner] in [1,2,3,5],Race[owner],3);
      if (Wl<>-1) and (weapons<>-1) then
      begin
	v[lr].weaps:=weapons;
	v[lr].Wl:=Wl;
      end;
      if (Tl<>-1) and (launchers<>-1) then
      begin
	v[lr].Tl:=Tl;
	v[lr].launs:=launchers;
      end;
      if TFnum<>-1 then v[lr].TFn:=TFnum
      else if mass<>-1 then v[lr].TFn:=Min(mass-Hulls[hull].mass,v[lr].TFn);
      if (damage<>-1) and ((weapons>0) or (bays>0) or (launchers>0)) then
	v[lr].shld:=100-IIF(Race[owner]=2,Max(damage-50,0),damage);
      if El<>-1 then v[lr].El:=El;
    end;
  end;

procedure AcceptPln;
  var	p	: pptr;
	b	: bptr;
  begin
    p:=TTurn^.data^.planet[lock and LockLo];
    if p=nil then Exit;
    with v[Right] do
    begin
      v[Right].hull:=0;
      FillChar(name,20,' ');
      Move(PlanName[lock and LockLo],name,20);
      owner:=IIF(Race[p^.owner] in [1,2,3,5],Race[p^.owner],3);
      if (p^.defense<>-1) then shpw:=p^.defense
      else if (p^.colonists>50) then shpw:=50+round(SQRT(p^.colonists-50))
      else if (p^.colonists>0) then shpw:=p^.colonists
      else shpw:=0;
      shld:=100;
      b:=TTurn^.data^.base[lock and LockLo];
      if b=nil then
      begin
	crew:=0;
	launs:=0;
	Tl:=0;
	TFn:=0;
	Wl:=1;
      end
      else begin
	crew:=100;
	launs:=b^.defense;
	Tl:=b^.damage;
	TFn:=b^.fighters;
	Wl:=b^.Wl;
      end;
    end;
    DrawShip(Right);
  end;

procedure StartCombat (RND:byte; Show:boolean);
  var	f	: file;
	pln	: boolean;
	i,k	: int;
	mw,mb,ml: byte;
	lr	: LRType;
  begin
    if (v[Left].name[1]=#0) or (v[Right].name[1]=#0) then Exit;
    pln:=(v[Right].hull=0);
    if RND>119 then RND:=1 else if RND=0 then RND:=119;
    RR:=RND;
    d.K0:=RR;
    d.int0:=0;
    if not pln then
    begin
      d.plnpic:=0; d.planet:=0;
      d.shpw[Left]:=v[Left].shpw+Engines[v[Left].El].cost*ESBonus div 100;
      d.shpw[Right]:=v[Right].shpw+Engines[v[Right].El].cost*ESBonus div 100;
    end
    else begin
      d.plnpic:=Random(49)+1;
      d.planet:=1;
      d.shpw[Left]:=v[Left].shpw;
      d.shpw[Right]:=v[Right].shpw+100+IIF(v[Right].crew=0,0,v[Right].launs); { Pl.def. }
      v[Right].dam:=0;	{ pln: damage is always 0 }
    end;
    Move(v[Left].name,d.dd[Left].name,42);
    Move(v[Right].name,d.dd[Right].name,22);
    if not pln then Move(v[Right].crew,d.dd[Right].crew,20)
    else with d.dd[Right] do
    begin
      id:=0;
      race:=v[Right].owner;			{ race }
      pic:=v[Right].pic;			{ pic }
      wl:=Max(1,Max(Min(Round(Sqrt(v[Right].shpw/2)),10),IIF(v[Right].crew<>0,v[Right].Wl,0)));	{ Wl }
      weaps:=Min(Round(Sqrt((d.shpw[Right]-100)/3)),10); { weaps }
      bays:=Round(Sqrt(v[Right].shpw));  	{ bays }
      tfn:=bays+v[Right].TFn;			{ TFn }
      crew:=tfn;				{ crew }
      if v[Right].crew<>0 then inc(bays,5);	{ base: +5 bays }
      tl:=0; launs:=0;				{ Tl,launs }
      bfn:=tfn;
    end;
    for lr:=Left to Right do
    begin
      d.shld[lr]:=v[lr].shld;
      if (lr=Right) and pln then Break;
      if (d.dd[lr].race=1) and (VCSet and 1=0) then	{ VCSet and 1=0 -> Fed ON }
      begin
	inc(d.shpw[lr],50);
	d.shld[lr]:=Min(d.shld[lr]+25,100-d.dd[lr].dam);
	if d.dd[lr].bays>0 then inc(d.dd[lr].bays,3);
      end
      else begin
	k:=IIF(d.dd[lr].race=2,Max(d.dd[lr].dam-50,0),d.dd[lr].dam);
	if PHOST then
	with Hulls[v[lr].hull] do
	begin
	  mw:=weapons-weapons*k div 100;
	  mb:=bays-bays*k div 100;
	  ml:=launchers-launchers*k div 100;
	end
	else begin mw:=10-k div 10; mb:=mw; ml:=mb end;
	d.dd[lr].weaps:=Max(0,Min(d.dd[lr].weaps,mw));
	d.dd[lr].bays:=Max(0,Min(d.dd[lr].bays,mb));
	d.dd[lr].launs:=Max(0,Min(d.dd[lr].launs,ml));
      end;
    end;
    if (not PHOST) and (VCSet and 4=0) and (not pln) and
       (alw_rnd>=400) and (d.shpw[Right]>140) and (v[Left].bays>0) then
      inc(d.shpw[Right],360);	{ Anti-LeftWin: heuristica de THost (solo THost; en PHost el
                                  combate es por masa y sumar 360 falsearia el resultado). }
    if not Show then
    begin
      Clear(StartX-3*8,StartY,StartX+11*8-1,StartY+7);
      SetColor(White);
      OutTextXY(StartX-3*8,StartY,'SIMULATING....');
    end;
    if PHOST then
    begin
      { Partida PHost: usar la matematica PHost portada (PVCRALG via CombatPHost).
        Las naves del simulador son de nivel 0 (no hay UI de experiencia), asi que
        se desactiva la capacidad de experiencia -> combate PHost base, sin rango. }
      VcrFileCaps:=0;
      CombatPHost(d,Show,VCSpeed,VCSet and 8<>0,No);
    end
    else
      Combat(d,Show,VCSpeed,VCSet and 8<>0,No);   { Partida THost: matematica clasica de VPA. }
    if not Show then Clear(StartX-3*8,StartY,StartX+11*8-1,StartY+7);
    WriteAtt;
    WriteResult;
    if Show then
      for lr:=Left to Right do
      begin
	if d.dd[lr].pic=ExplPic then LoadPicture(lr);
	DrawShip(lr);
      end;
  end;
  
procedure FindWorstCase(lr:LRType);
var
	i,j   : int;
	other : LRType;
	maxDam: int;
	minDam: int;
	maxSh : int;
	minSh : int;
	idx   : byte;
	limit : array [LRType] of int;
	destr : array [LRType] of int;
	captu : array [LRType] of int;
  procedure CountStats( lr: LRType );
  begin
    if (d.dd[lr].dam > limit[lr]) then
      destr[lr] := destr[lr] + 1
    else if ((lr=Left) or (d.planet=0)) then
      if (d.dd[lr].crew<=0) then
        captu[lr] := captu[lr] +1;
  end;
  procedure WriteStats;
  var f: double;
      s: string;
  begin
    ClearStats;
    SetColor(Lightgray);
    f:=destr[Left]; f:=f/119; Str(f*100.0:5:1,s);
    OutTextXY(SX[Left],ResY+5*12, 'Killed      : '+NStr0(destr[Left])+' ('+s+'%)');
    f:=captu[Left]; f:=f/119; Str(f*100.0:5:1,s);
    OutTextXY(SX[Left],ResY+6*12, 'Captured    : '+NStr0(captu[Left])+' ('+s+'%)');
    if (d.planet=0) then begin
      f:=destr[Right]; f:=f/119; Str(f*100.0:5:1,s);
      OutTextXY(SX[Right],ResY+5*12,'Killed      : '+NStr0(destr[Right])+' ('+s+'%)');
      f:=captu[Right]; f:=f/119; Str(f*100.0:5:1,s);
      OutTextXY(SX[Right],ResY+6*12,'Captured    : '+NStr0(captu[Right])+' ('+s+'%)');
    end else begin
      f:=destr[Right]; f:=f/119; Str(f*100.0:5:1,s);
      OutTextXY(SX[Right],ResY+6*12,'Captured    : '+NStr0(destr[Right])+' ('+s+'%)');
    end;
  end;
  procedure UpdateExtrema;
  begin
    maxDam := Max(d.dd[lr].dam,maxDam);
    minSh := Min(d.shld[lr],minSh);
    minDam := Min(d.dd[other].dam,minDam);
    maxSh := Max(d.shld[other],maxSh);
  end;
begin
  if (lr=Left) then other:=Right else other:=Left;
  maxDam := 0;
  minDam := 9999;
  maxSh  := 0;
  minSh  := 100;
  limit[Left]  := IIF(v[Left].owner=2,150,99);
  limit[Right] := IIF((v[Right].owner=2) and (d.planet=0),150,99);
  destr[Left]  := 0;
  destr[Right] := 0;
  captu[Left]  := 0;
  captu[Right] := 0;
  j:=0;
  for i:=1 to 119 do begin
    alw_rnd:=Random(1000);
    StartCombat(i,false);
    {count losses and captures}
    CountStats(Left);
    CountStats(Right);
    {remember worst case}
    if ((d.dd[lr].dam > maxDam) and (maxDam <= limit[lr])) then begin
      UpdateExtrema;
      idx := i;
    end else if ((d.dd[lr].dam = maxDam) or (d.dd[lr].dam>limit[lr])) then begin
      if (d.shld[lr] < minSh) then begin
        UpdateExtrema;
        idx := i;
      end else begin
    {OutTextXY(j*40,ResY+6*12, NStr0(maxSh)); inc(j);}
        if (d.dd[other].dam < minDam) then begin
          UpdateExtrema;
          idx := i;
        end else if (d.shld[other] > maxSh) then begin
          UpdateExtrema;
          idx := i;
        end;
      end;
    end;
  end;
  alw_rnd:=Random(1000);
  StartCombat(idx,false);
  WriteStats;
end;

procedure CombatSimulator;
  var	f	: file;
	pp	: byte;
	pn	: LRType;
	s	: string[3];
	a	: int;
	v0	: VRec;
  begin
    UnlockReservedMemory(ReservedMemory);
    TCombatInit(Yes);

    WriteAtt;
    LoadPicture(Left);
    DrawShip(Left);
    LoadPicture(Right);
    DrawShip(Right);
    result:=Off;
    pn:=Left; pp:=1;
    repeat
      SetColor(_Yellow);
      OutTextXY(SX[pn]-16,48+pp*12-IIF(pp<=1,4,0),#7);
      ch:=ReadKey;
      SetColor(Black);
      OutTextXY(SX[pn]-16,48+pp*12-IIF(pp<=1,4,0),#7);
      case ch of
	$4800	: if v[pn].name[1]<>#0 then
		    if pp=IIF(pn=Right,0,1) then pp:=12 else dec(pp)
		  else pp:=1;
	$5000	: if v[pn].name[1]<>#0 then
		    if pp=12 then pp:=IIF(pn=Right,0,1) else inc(pp)
		  else pp:=1;
	$4B00	: begin pn:=Left; if pp=0 then pp:=1 end;
	$4D00	: pn:=Right;
	13	: if (pp in [0,1,3,4,5,6,7,9,11,12]) and (v[pn].hull<>0) then
		    begin ModShip(pn,pp); ClearResult; ClearStats end
		  else if (pp=1) and (v[pn].name[1]=#0) then
		    begin ModShip(pn,1); ClearResult; ClearStats end
		  else if (pp in [0,1,2,3,5,6,8,12]) and (v[pn].hull=0) then
		    begin ModPln(pp); ClearResult; ClearStats end;
	ord('+'),ord('-')	:
		  if (pp in [0,6,7,8,9,10,12]) and (v[pn].hull<>0) then
		    begin ModShip(pn,pp); ClearResult; ClearStats end
		  else if (pp in [0,4,7,12]) and (v[pn].hull=0) then
		    begin ModPln(pp); ClearResult; ClearStats end;
	32	: if (ltype=LockS) and (lship^.hull>0) then
		  begin
		    AcceptShip(pn);
		    ClearResult;
		    ClearStats;
		    DrawShip(pn);
		  end
		  else if (pn=Right) and (ltype=LockP) then AcceptPln;
	9	: if v[Right].hull<>0 then
		    begin v0:=v[Left]; v[Left]:=v[Right]; v[Right]:=v0;
			  ClearResult;
			  ClearStats;
			  LoadPicture(Left); LoadPicture(Right);
			  DrawShip(Left); DrawShip(Right); 		 end;
	ord('f'): begin
		    VCSet:=VCSet xor 1;
		    FedCrew:=not FedCrew;
		    ClearResult;
		    ClearStats;
		    WriteAtt;
		  end;
	ord('l'): begin
		    VCSet:=VCSet xor 4;
		    ClearResult;
		    ClearStats;
		    WriteAtt;
		  end;
	ord('a'): begin VCSet:=VCSet xor 2; WriteAtt end;
	ord('o'): begin VCSet:=VCSet xor 8; WriteAtt end;
	ord('s'): begin
		    alw_rnd:=Random(1000);
		    StartCombat(RR+1,VCSet and 2=0);
		  end;
	ord('S'): begin
		    alw_rnd:=Random(1000);
		    StartCombat(RR-1,VCSet and 2=0);
		  end;
	ord('w'): begin
	            FindWorstCase(Left);
	          end;
	ord('W'): begin
	            FindWorstCase(Right);
	          end;
	ord('v'): if result then StartCombat(RR,Yes);
	ord('e'): begin
		    Clear(SettX+14*8,SettY+12,SettX+18*8-1,SettY+12+7);
		    s:=GetStr(SettX+14*8,SettY+12,3);
		    Val(s,ESBonus,a);
		    if ESBonus>100 then ESBonus:=100;
		    ClearResult;
		    ClearStats;
		    WriteAtt;
		  end;
	ord('1')..ord('9'):
		  begin
		    VCSpeed:=ch-ord('0');
		    WriteAtt;
		  end;
	ord('r'): if result then begin GetResult; ClearResult; ClearStats end;
	$3B00	: begin
		    if BadVideoOrMouse then RestoreCrtMode;
		    if not useSVGA then
                      if customBGI then SetGraphMode(bgiMode)
                      else SetGraphMode(VGAHi);
		    Help;
		    ClearDevice;
		    WriteAtt;
		    SetPal;
		    DrawShip(Left);
		    DrawShip(Right);
		  end;
      end;
    until ch=27;
    Assign(f,addir+'VPAVCR.INI');
    Rewrite(f,1);
    if IOResult=0 then
    begin
      BlockWrite(f,v,VRSize*2);
      BlockWrite(f,VCSet,1);
      BlockWrite(f,wl0,1);
      BlockWrite(f,tl0,1);
      BlockWrite(f,VCSpeed,1);
      BlockWrite(f,halpha,2);
      BlockWrite(f,rhull0,1);
      Close(f);
      if IOResult<>0 then ;
    end;
    TCombatFinish;
    LockReservedMemory;
  end;

  var	mx,my	: int;
  BEGIN
    MouseOff;
    MouseDisabled:=True;
    mx:=MouseX; my:=MouseY;
    ClearDevice;
    InitVCS;
    helpscr:=4;
    CombatSimulator;
    helpscr:=0;
    if BadVideoOrMouse then RestoreCrtMode;
    if not useSVGA then
      if customBGI then SetGraphMode(bgiMode)
      else SetGraphMode(VGAHi);
    DrawRightScreen;
    MoveMouseTo(mx,my);
    MouseDisabled:=False;
    MouseOn;
    ResetMouse;
    if lock<>0 then begin force:=lock; ForceKey:=13 end;
    ch:=2;		{ redraw map }
  END;

End.
