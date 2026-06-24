{$I switches.inc}            
Unit	VPAExit;	(* VPA Final Part *)
{$V-}

Interface

procedure SaveAll;
procedure SaveChanges;
procedure QuitVPA;

Implementation

uses	AuxF,StrF,Mouse,Keyboard,ptcgraph,Screen,VPAData,Messages,MsgRead,Config,RST_TRN,VPAInit
{$IFDEF TASKS}
    ,Tasks
{$ENDIF}
    ,ExtFeat
{$IFDEF VPACC}
    ,PHostM
{$ENDIF};

const	CreatedNewBase	: boolean = No;

const   KnownTagN	= 21;
	KnownTag	: array [-3..KnownTagN] of long =
			( T_TAG,V_TAG,IM_TAG,MO_TAG, { -3..0 are not rewritten }
			  P_TAG,B_TAG,S_TAG,M_TAG,
			  I_TAG,U_TAG,W_TAG,E_TAG,N_TAG,XY_TAG,
			  A_TAG,OM_TAG,PP_TAG,VE_TAG,
			  PH_TAG,PW_TAG,SC_TAG,RE_TAG,
        SEXP_TAG,PEXP_TAG,BQ_TAG );

procedure SaveData;
  var	tb		: TBlock;
	b       	: DBlock;
	fp0,fp1,fp2,l	: long;
	i,pn,bn,sn,mn,isn,un,wn	: int;
	f,g		: file;
	m		: Msg;
	a		: array [1..2,1..10] of byte absolute m;
  begin
    if ResMem=nil then RunError(251);
    if TEnd^.fpos=0 then
    begin
      Writeln('Creating VPA database...');
      OpenW(f,dbname,Yes);
      BlockWrite(f,DBHeader,DBHeadLen);
      CloseData(f);
      TEnd^.fpos:=DBHeadLen;
      CreatedNewBase:=Yes;
    end
    else Writeln('Updating VPA database...');
    OpenRW(f,dbname,Yes);

    Seek(f,TEnd^.fpos);
    tb.tag:=T_TAG;
    tb.number:=today;
    tb.stamp:=Stamp;
    tb.score:=TEnd^.score;
    BlockWrite(f,tb,SizeOf(tb));
    if IOResult<>0 then RunError(252);

    fp0:=FilePos(f);
    fp1:=FilePos(f);

    if (not NewTurn) and
       (TEnd^.unk or (TEnd^.data^.ipos or TEnd^.data^.vpos<>0)) then
    begin
      repeat
	BlockRead(f,b,SizeOf(b));
	if IOResult<>0 then RunError(253);
	if b.tag=T_TAG then Break;
	i:=1;
	while (i<=KnownTagN) and (b.tag<>KnownTag[i]) do inc(i);
	if i<=KnownTagN then Seek(f,FilePos(f)+b.size)	{ the block will be rewritten }
	else begin
	  fp2:=FilePos(f);
	  Seek(f,fp1);
	  BlockWrite(f,b,SizeOf(b));
	  if IOResult<>0 then RunError(252);
	  fp1:=FilePos(f);
	  Seek(f,fp2);
	  while b.size>0 do
	  begin
	    l:=MinL(b.size,ReservedMemory);
	    dec(b.size,l);
	    BlockRead(f,ResMem^,l);
	    if IOResult<>0 then RunError(253);
	    fp2:=FilePos(f);
	    Seek(f,fp1);
	    BlockWrite(f,ResMem^,l);
	    if IOResult<>0 then RunError(252);
	    fp1:=FilePos(f);
	    Seek(f,fp2);
	  end;
	end;
      until Eof(f); { or T_TAG }
      Seek(f,fp1);
    end;

    if TEnd^.IsPBP then
    begin
      b.tag:=PP_TAG;
      b.size:=SizeOf(PBPList);
      b.number:=0;
      BlockWrite(f,b,SizeOf(b));
      BlockWrite(f,TEnd^.PBP,SizeOf(PBPList));
      if IOResult<>0 then RunError(252);
    end;

    with TEnd^.data^ do
    begin

      pn:=0; bn:=0; sn:=0; mn:=0; isn:=0; un:=0; wn:=0;
      for i:=0 to 999 do
      begin
	if (i>=1) and (i<=500) then
	begin
	  if planet[i]<>nil then inc(pn);
	  if base[i]<>nil then inc(bn);
	  if mines[i]<>nil then inc(mn);
	end;
	if (i>=1) and (i<=999) then
	  if ship[i]<>nil then inc(sn);
	if (i>=1) and (i<=50) and (ion[i]<>nil) then inc(isn);
	if (i>=1) and (i<=100) and (ufo[i]<>nil) then inc(un);
	if (i>=0) and (i<=199) and (worm[i]<>nil) then inc(wn);
      end;

      if pn>0 then
      begin
	b.tag:=P_TAG;
	b.size:=long(pn)*(SizeOf(PRec)+2);
	b.number:=pn;
	BlockWrite(f,b,SizeOf(b));
	for i:=1 to 500 do
	  if planet[i]<>nil then
	  begin
	    BlockWrite(f,i,2);
	    BlockWrite(f,planet[i]^,SizeOf(PRec));
	  end;
	if IOResult<>0 then RunError(252);
      end;

      if bn>0 then
      begin
	b.tag:=B_TAG;
	b.size:=long(bn)*(SizeOf(BRec)+2);
	b.number:=bn;
	BlockWrite(f,b,SizeOf(b));
	for i:=1 to 500 do
	  if base[i]<>nil then
	  begin
	    BlockWrite(f,i,2);
	    BlockWrite(f,base[i]^,SizeOf(BRec));
	  end;
	if IOResult<>0 then RunError(252);
      end;

      if sn>0 then
      begin
	b.tag:=S_TAG;
	b.size:=long(sn)*(SizeOf(SRec)-2+2);
	b.number:=sn;
	BlockWrite(f,b,SizeOf(b));
	for i:=1 to 999 do
	  if ship[i]<>nil then
	  begin
	    BlockWrite(f,i,2);
	    BlockWrite(f,ship[i]^,SizeOf(SRec)-2);
	  end;
	if IOResult<>0 then RunError(252);
      end;

      if mn>0 then
      begin
	b.tag:=M_TAG;
	b.size:=long(mn)*(SizeOf(MRec)+2);
	b.number:=mn;
	BlockWrite(f,b,SizeOf(b));
	for i:=1 to 500 do
	  if mines[i]<>nil then
	  begin
	    BlockWrite(f,i,2);
	    BlockWrite(f,mines[i]^,SizeOf(MRec));
	  end;
	if IOResult<>0 then RunError(252);
      end;

      if isn>0 then
      begin
	b.tag:=I_TAG;
	b.size:=long(isn)*(SizeOf(IRec)+2);
	b.number:=isn;
	BlockWrite(f,b,SizeOf(b));
	for i:=1 to 50 do
	  if ion[i]<>nil then
	  begin
	    BlockWrite(f,i,2);
	    BlockWrite(f,ion[i]^,SizeOf(IRec));
	  end;
	if IOResult<>0 then RunError(252);
      end;

      if un>0 then
      begin
	b.tag:=U_TAG;
	b.size:=long(un)*(SizeOf(URec)+2);
	b.number:=un;
	BlockWrite(f,b,SizeOf(b));
	for i:=1 to 100 do
	  if ufo[i]<>nil then
	  begin
	    BlockWrite(f,i,2);
	    BlockWrite(f,ufo[i]^,SizeOf(URec));
	  end;
	if IOResult<>0 then RunError(252);
      end;

      if wn>0 then
      begin
	b.tag:=W_TAG;
	b.size:=long(wn)*(SizeOf(WRec)+2);
	b.number:=wn;
	BlockWrite(f,b,SizeOf(b));
	for i:=0 to 199 do
	  if worm[i]<>nil then
	  begin
	    BlockWrite(f,i,2);
	    BlockWrite(f,worm[i]^,SizeOf(WRec));
	  end;
	if IOResult<>0 then RunError(252);
      end;

      b.tag:=E_TAG;
      b.size:=SizeOf(eplan);
      b.number:=500;
      BlockWrite(f,b,SizeOf(b));
      BlockWrite(f,eplan,SizeOf(eplan));
      if IOResult<>0 then RunError(252);

      b.tag:=N_TAG;
      b.size:=SizeOf(newplan);
      b.number:=500;
      BlockWrite(f,b,SizeOf(b));
      BlockWrite(f,newplan,SizeOf(newplan));
      if IOResult<>0 then RunError(252);

      b.tag:=XY_TAG;
      b.size:=SizeOf(xyplan);
      b.number:=500;
      BlockWrite(f,b,SizeOf(b));
      BlockWrite(f,xyplan,SizeOf(xyplan));
      if IOResult<>0 then RunError(252);

      if shipexp<>nil then begin
        b.tag := SEXP_TAG;
        b.size := sizeof(shipexp^);
        b.number := NUM_SHIPS;
        BlockWrite(f,b,Sizeof(b));
        BlockWrite(f,shipexp^,Sizeof(shipexp^));
        IF IOResult<>0 then RunError(252);
      end;

      if planetexp<>nil then begin
        b.tag := PEXP_TAG;
        b.size := sizeof(planetexp^);
        b.number := NUM_PLANETS;
        BlockWrite(f,b,Sizeof(b));
        BlockWrite(f,planetexp^,Sizeof(planetexp^));
        IF IOResult<>0 then RunError(252);
      end;

      if BuildQ<>nil then begin
        b.tag := BQ_TAG;
        b.size := sizeof(BuildQ^);
        b.number := NUM_PLANETS+1;
        BlockWrite(f,b,Sizeof(b));
        BlockWrite(f,BuildQ^,Sizeof(BuildQ^));
        IF IOResult<>0 then RunError(252);
      end;

      while (nmark>0) and (mark^[nmark].mtype=mrkNone) do dec(nmark);
      if nmark>0 then
      begin
	b.tag:=A_TAG;
	b.number:=nmark;
	b.size:=long(b.number)*(SizeOf(MapMark))+mtsize;
	BlockWrite(f,b,SizeOf(b));
	for i:=1 to nmark do BlockWrite(f,mark^[i],SizeOf(MapMark));
	if mtsize>0 then BlockWrite(f,mtext^,mtsize);
	if IOResult<>0 then RunError(252);
      end;

    end {with TEnd^.data};

    if (keepmsg<>nil) and (keepmsg^[1]>0) then
    begin
      b.tag:=IM_TAG;
      b.size:=long(keepmsg^[1])*6;
      b.number:=keepmsg^[1];
      BlockWrite(f,b,SizeOf(b));
      l:=FilePos(f);
      Seek(f,l+b.size);
      dec(l,2);
      OpenRW(g,'MDATA'+plstr+'.DAT',Yes);
      for i:=1 to keepmsg^[1] do
      begin
	inc(b.size,WriteMessage(f,i,m,l,FilePos(f)-l,Yes,ReadMessage(g,keepmsg^[1+i],m,0,Yes)));
	if IOResult<>0 then RunError(252);
      end;
      CloseData(g);
      fp2:=FilePos(f);
      Seek(f,l-8);
      BlockWrite(f,b,SizeOf(b));
      Seek(f,fp2);
      if IOResult<>0 then RunError(252);

      if OpenRW(g,'VPAMSG'+plstr+'.DAT',No) then
      begin
	b.tag:=MO_TAG;
	b.size:=long(keepmsg^[1])*4;
	b.number:=keepmsg^[1];
	BlockWrite(f,b,SizeOf(b));
	for i:=1 to keepmsg^[1] do
	begin
	  Seek(g,(keepmsg^[1+i]-1)*4);
	  BlockRead(g,l,4);
	  BlockWrite(f,l,4);
	  if IOResult<>0 then RunError(252);
	end;
	CloseData(g);
	if IOResult<>0 then RunError(252);
      end;
    end;

    mn:=nmsg[m_Out]-IIF(PHOSTmn=0,0,1);
    if mn>0 then
    begin
      b.tag:=OM_TAG;
      b.number:=mn;
      b.size:=long(mn)*10;
      BlockWrite(f,b,SizeOf(b));
      l:=FilePos(f);
      Seek(f,l+b.size);
      dec(l,2);
      OpenRW(g,'MESS'+plstr+'.DAT',Yes);
      for i:=1 to mn+IIF(PHOSTmn=0,0,1) do
      if i<>PHOSTmn then
      begin
	inc(b.size,WriteMessage(f,i-IIF( PHOSTmn=0,0,IIF(i>PHOSTmn,1,0)),m,l,FilePos(f)-l,No,ReadMessage(g,i,m,0,No)));
	if IOResult<>0 then RunError(252);
      end;
      CloseData(g);
      fp2:=FilePos(f);
      Seek(f,l-8);
      BlockWrite(f,b,SizeOf(b));
      Seek(f,fp2);
      if IOResult<>0 then RunError(252);
    end;

    if (nmsg[m_VCR]>0) and (NewTurn or (TEnd^.data^.vpos=0)) then
    begin
      b.tag:=V_TAG;
      b.size:=long(nmsg[m_VCR])*SizeOf(VCRData);
      b.number:=nmsg[m_VCR];
      BlockWrite(f,b,SizeOf(b));
      OpenRW(g,'VCR'+plstr+'.DAT',Yes);
      BlockRead(g,i,2);
      for i:=1 to nmsg[m_VCR] do
      begin
	BlockRead(g,m,SizeOf(VCRData));
	BlockWrite(f,m,SizeOf(VCRData));
      end;
      if IOResult<>0 then RunError(252);
      CloseData(g);
    end;

    if Password<>NoPassword then
    begin
      b.tag:=PW_TAG;
      b.size:=20;
      b.number:=0;
      BlockWrite(f,b,SizeOf(b));
      for i:=1 to 10 do
      begin
	pn:=IIF(i>byte(Password[0]),0,byte(Password[i]));
	a[1,i]:=Random(256);
	a[2,11-i]:=a[1,i]+32-byte(pn);
      end;
      BlockWrite(f,a,20);
      if IOResult<>0 then RunError(252);
    end;

    b.tag:=VE_TAG;
    b.size:=0;
    b.number:=VerNum;
    BlockWrite(f,b,SizeOf(b));
    if IOResult<>0 then RunError(252);

    if PHOST then
    begin
      b.tag:=PH_TAG;
      b.size:=byte(PHOSTver[0]);
      b.number:=0;
      BlockWrite(f,b,SizeOf(b));
      BlockWrite(f,PHOSTver[1],b.size);
      if IOResult<>0 then RunError(252);
    end;

    fp1:=FilePos(f);
    tb.size:=fp1-fp0;
    Seek(f,fp0-SizeOf(ScoreList)-SizeOf(TimeStamp)-6);
    BlockWrite(f,tb.size,4);
    Seek(f,fp1);
    Truncate(f);
    Close(f);
  end;

procedure SaveGameData;
  const	sChanged= SizeOf(Changed);
  var	really	: boolean;
	xBuf	: ^ByteArr absolute ResMem;
	xBufI	: ^IntArr absolute ResMem;
	xt	: xtype;
	f,ctrl1,ctrl2	: file;
	i,n,k,j	: int;
	fp,isum	: long;
	p	: pointer;
	pb	: ^ByteArr;
  procedure OpenCtrl (var ctrl:file; cn:str20);
    begin
      if not OpenRW(ctrl,cn,No) then OpenW(ctrl,cn,Yes);
    end;
  procedure WriteNewPassword;
    var	i	: int;
	f	: file;
    begin
      Password:=NewPassword;
      Writeln('Saving new password...');
      OpenRW(f,'GEN'+plstr+'.DAT',Yes);
      Seek(f,$8D);
      i:=13;
      BlockWrite(f,i,2);
      for i:=1 to 10 do
      begin
	if i>byte(NewPassword[0]) then NewPassword[i]:=#0;
	inc(byte(NewPassword[i]),50);
      end;
      BlockWrite(f,NewPassword[1],10);
      CloseData(f);
    end;
  function ReadAndSum (var f:file; size:long) : long;
    var	sum	: long;
	n,i	: int;
    begin
      sum:=0;
      repeat
	n:=MinL(size,ReservedMemory);
	BlockRead(f,xBuf^,n);
	dec(size,n);
	for i:=1 to n do inc(sum,xBuf^[i]);
      until size=0;
      ReadAndSum:=sum;
    end;
  begin
    if NewPassword[0]<>#0 then WriteNewPassword;
   {$IFDEF VPACC}
    SavePHostCommands;
   {$ENDIF}
    really:=No;
    really := No;
    pb := @Changed;
    i := 1;
    while (i <= sChanged) and (not really) do
    begin
      if pb^[i] <> 0 then really := Yes;
      inc(i);
    end;
    if not really then Exit;
    Writeln('Updating game data... ');
    OpenCtrl(ctrl1,'CONTROL.DAT');
    OpenCtrl(ctrl2,'CONTRL'+plstr+'.DAT');
    for xt:=Sh to Ba do
    begin
      OpenRW(f,xFName[xt]+plstr+'.DAT',Yes);
      BlockRead(f,n,2);
      for i:=1 to n do
      begin
	fp:=FilePos(f);
	isum:=ReadAndSum(f,xISize[xt]);
	k:=xBufI^[xINum[xt]];
	if IfChanged(xt,k) then
	with TEnd^.data^ do
	begin
	  Seek(f,fp+4);
	  case xt of
	    Sh	: p:=Addr(ship[k]^.fcode);
	    Pl	: p:=Addr(planet[k]^.fcode);
	    Ba	: p:=Addr(base[k]^.defense);
	  end;
	  BlockWrite(f,p^,xISize[xt]-4);
	  Seek(f,fp);
	  isum:=ReadAndSum(f,xISize[xt]);
	end;
	fp:=ControlPosition(xt, k);
	Seek(ctrl1,fp);
	BlockWrite(ctrl1,isum,4);
	Seek(ctrl2,fp);
	BlockWrite(ctrl2,isum,4);
      end;
      Seek(f,0);
      isum:=ReadAndSum(f,FileSize(f));
      CloseData(f);
      OpenRW(f,xFName[xt]+plstr+'.DIS',Yes);
      inc(isum,ReadAndSum(f,FileSize(f)));
      CloseData(f);
      OpenRW(f,'GEN'+plstr+'.DAT',Yes);
      Seek(f,$81+byte(xt)*4);
      BlockWrite(f,isum,4);
      CloseData(f);
      inc(isum,xFizz[xt]);
      OpenRW(f,FIZZ_BIN,Yes);
      Seek(f,int(player-1)*12+byte(xt)*4);
      BlockWrite(f,isum,4);
      CloseData(f);
    end;
    CloseData(ctrl1);
    CloseData(ctrl2);
  end;

{ Greets (greets.obj) descartado en el port; WriteGreeting usa un stub }

procedure WriteGreeting;
  var	p	: pointer;
	l,n,i	: word;
	s	: string;
	ls	: byte absolute s;
	rs	: string[50];
	lrs	: byte absolute rs;
	f	: file;
  procedure GetGreetStr (k:word);
    var	i	: byte;
    begin
      ItemStr(p^,k,s);
      for i:=1 to ls do s[i]:=char(byte(s[i]) xor $40);
    end;
  begin
    if (not CreatedNewBase) and (Random(100)>20) then Exit;
    { GREETS (greets.obj) descartado en el port: sin datos de saludo }
    p := nil; l := 0; n := 0;
    rs:=PlanetsRegInfo[1];
    if (Pos('WINPLAN',PlanetsRegInfo[2])<>0) and OpenData(f,'REG.KEY',No) then
    begin
      BlockRead(f,rs[1],50); lrs:=50;
      for i:=1 to 50 do dec(byte(rs[i]),13);
    end;
    Trim(rs); Upper(rs);
    for i:=1 to n do
    begin
      GetGreetStr(i*2-2);
      if s=rs then
      begin
	GetGreetStr(i*2-1);
	Writeln(#13#10,s);
      end;
    end;
  end;

procedure SaveScr;
  var	f	: file;
  begin
    if byte(VPASCR_INI[0])=0 then Exit;
    if not OpenRW(f,VPASCR_INI,No) then Rewrite(f,1);
    if IOResult<>0 then Exit;
    BlockWrite(f,ratioN,SizeOf(VPAScr)-2);
    BlockWrite(f,lock,2);
    BlockWrite(f,ScreenPos,SizeOf(ScreenPos));
    CloseData(f);
  end;

procedure SaveActList;
  var	f	: file;
        i       : word;
  begin
    for i:=1 to NUM_MAX do
      if actlist[i] <> 0 then
       begin
         if not OpenRW(f,VPACTLIST_INI,No) then Rewrite(f,1);
         if IOResult<>0 then Exit;
         BlockWrite(f,actlist,SizeOf(actlist));
         CloseData(f);
         exit;
       end;
  end;

procedure SaveAll;
  begin
    if RWMode then begin
      if not Batch then SaveScr;
      if MaySave and (NewTurn or DataChg
{$IFDEF TASKS}
      or TaskChg
{$ENDIF}
      ) then begin
        if DataChg then SaveGameData;
        SaveData;
        StoreWinPlanMess;
{$IFDEF TASKS}
        if TaskChg then SaveTasks;
{$ENDIF}        
        MakeTRN;
        NewTurn:=No;
        DataChg:=No;
{$IFDEF TASKS}        
        TaskChg:=No;
{$ENDIF}        
      end;
      if (MaySave) then ExtFeatSaveAllHook;
      if HConfChg then WriteHConfig;
      SaveActList;
    end;
  end;

procedure SaveChanges;
  begin
    Clear(0,0,479,479);
    { (en DOS aqui se posicionaba el cursor de texto por BIOS; no aplica) }
    SaveAll;
    ch:=2;
  end;

{$IFDEF UNIX}
{ Confirmacion grafica "salir sin guardar" (Ctrl-Alt-X). Debe ejecutarse ANTES de
  CloseGraphics: al cerrar la ventana ptc el teclado deja de generar eventos, asi
  que el prompt de texto del original colgaria. Devuelve True si el usuario confirma
  que quiere salir SIN guardar. }
function ConfirmQuitNoSave : boolean;
  var ch : word;
  begin
    SetFillStyle(SolidFill, Black);
    Bar(96, 218, 560, 260);
    SetColor(White);
    Rectangle(96, 218, 560, 260);
    OutTextXY(112, 233, 'No changes will be saved. Are you sure? (Y/N)');
    repeat ch := ReadKey
    until (ch=ord('y')) or (ch=ord('Y')) or (ch=ord('n')) or (ch=ord('N'));
    ConfirmQuitNoSave := (ch=ord('y')) or (ch=ord('Y'));
  end;
{$ENDIF}

procedure QuitVPA;
  var	save	: boolean;
  begin
    save := not KbdQuitNoSave;   { Ctrl-Alt-X => no guardar; Alt-X / [X] => guardar }
    if not Batch then
    begin
{$IFDEF UNIX}
      { Preguntar (graficamente) antes de cerrar el grafico. }
      if (not save) and MaySave and (NewTurn or DataChg) then
        save := not ConfirmQuitNoSave;
      CloseGraphics;
      CloseData(helpfile);
{$ELSE}
      CloseGraphics;
      CloseData(helpfile);
      if (not save) and MaySave and (NewTurn or DataChg) then
      begin
	Write('No changes will be saved. Are you sure (y/n)? ');
	save:=not YesNo;
	Writeln;
      end;
{$ENDIF}
    end;
    if save then SaveAll;
    ExtFeatQuitVPAHook;
    WriteGreeting;
  end;

End.
