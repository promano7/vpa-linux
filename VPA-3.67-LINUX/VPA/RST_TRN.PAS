{$I switches.inc}
Unit	RST_TRN;	(* RST, TRN, registration, protection *)
{$I-}

Interface

uses	AuxF;

const	DeleteRST		: boolean = Yes;
	ScrambleShipNames	: boolean = No;
	ScrambledNameLen	= 8;
	ScrambledName		: array [1..ScrambledNameLen] of char = 'Serial #';

const	ExtraTargetSig	: array [1..4] of char = '1120';

procedure CheckPlanetsRegistration;
procedure MakeTRN;
procedure UnpackRST (race:int);

Implementation

uses	StrF,VPAData,Screen,Messages,ExtFeat
{$IFDEF VPACC},
        PHostM
{$ENDIF};

type	narr	= array [1..20] of char;
	pnarr	= ^narr;
	snrec	= record
		    realname,alias	: narr;
		  end;
	snames	= array [1..1000] of snrec;

function DeScrambleShipNames (race:int) : boolean;
  var	snm,dat	: file;
	plstr		: string[2];
	h	: SRec;
	vcr	: VCRData absolute h;
	i,n,sn	: int;
	sname	: ^snames;
	buf	: pointer;
	was	: boolean;
  const	RBlock	= 30000;
  function ProcessName (s:pnarr) : boolean;
    var	j	: int;
    begin
      ProcessName:=No;
      for j:=1 to sn do
	if sname^[j].alias=s^ then
	begin
	  s^:=sname^[j].realname;
	  ProcessName:=Yes;
	  DeScrambleShipNames:=Yes;
	  Exit;
	end;
    end;
  begin
    DeScrambleShipNames:=Yes;
    plstr:=NStr(race);
    if not OpenRW(snm,'VPASNM'+plstr+'.DAT',No) then Exit;
    Writeln('Descrambling ',RaceName[race],' ship names...');
    DeScrambleShipNames:=No;
    sn:=Min(FileSize(snm) div SizeOf(snrec),1000);
    CheckMem(sn*SizeOf(snrec)+RBlock);
    GetMem(sname,sn*SizeOf(snrec));
    BlockRead(snm,sname^,sn*SizeOf(snrec));

    OpenRW(dat,xFName[Sh]+plstr+'.DAT',Yes);
    BlockRead(dat,n,2);
    for i:=1 to n do
    begin
      BlockRead(dat,h,SRecordSize);
      if ProcessName(Addr(h.name)) then
      begin
	Seek(dat,FilePos(dat)-SRecordSize);
	BlockWrite(dat,h,SRecordSize);
      end;
    end;
    CloseData(dat);

    OpenRW(dat,'VCR'+plstr+'.DAT',Yes);
    BlockRead(dat,n,2);
    for i:=1 to n do
    begin
      BlockRead(dat,vcr,SizeOf(vcr));
      if ProcessName(Addr(vcr.dd[Left].name)) or
	 ProcessName(Addr(vcr.dd[Right].name)) then
      begin
	Seek(dat,FilePos(dat)-SizeOf(vcr));
	BlockWrite(dat,vcr,SizeOf(vcr));
      end;
    end;
    CloseData(dat);

    GetMem(buf,RBlock);
    OpenRW(dat,'MDATA'+plstr+'.DAT',Yes);
    repeat
      BlockRead(dat,buf^,RBlock,n);
      if IOResult=0 then ;
      if n=0 then Break;
      asm
	cld
	push	ds
	lds	si,buf
	les	di,buf
	mov	cx,n
@@11:	lodsb
	sub	al,13
	stosb
	loop	@@11
	pop	ds
      end;
      asm
	mov	was,No
	les	di,buf
	mov	al,byte ptr ScrambledName
	mov	cx,n
	sub	cx,19
@@1:	repne	scasb
	jcxz	@@2
	push	cx
	push	di
	lea	si,ScrambledName+1
	mov	cx,ScrambledNameLen-1
	repe	cmpsb
	pop	di
	pop	cx
	jne	@@1
	push	ax
	push	cx
	push	di
	push	es
	push	es
	dec	di
	push	di
	inc	di
	push	bp		{!!! local call !!!}
	call	ProcessName
	mov	was,al
	pop	es
	pop	di
	pop	cx
	pop	ax
	jmp	@@1
@@2:
      end;
      if was then
      begin
	asm
	cld
	push	ds
	lds	si,buf
	les	di,buf
	mov	cx,n
@@12:	lodsb
	add	al,13
	stosb
	loop	@@12
	pop	ds
	end;
	Seek(dat,FilePos(dat)-n);
	BlockWrite(dat,buf^,n);
      end;
      if n>=30 then Seek(dat,FilePos(dat)-30);
    until n<RBlock;
    CloseData(dat);
    FreeMem(buf,RBlock);

    FreeMem(sname,sn*SizeOf(snrec));
    CloseData(snm);
  end;

procedure CheckPlanetsRegistration;
  const	DOSPReadSize	= 1024;
	RegKReadSize	= $47D-$D4+1;
  var	f		: file;
	buf		: ^ByteArr;
	bpos		: word;
	i,j		: int;
	l,cs		: long;
	regdata		: array [1..51] of long;
	regd		: array [1..2,1..25] of long absolute regdata;
	xors		: array [1..25] of byte absolute regdata;
	regstr		: array [1..2,1..25] of char;
	regs		: array [1..50] of byte absolute regstr;
  function DOSPReadNumber : integer;
    var	b	: byte;
	c	: char absolute b;
	a	: integer;
    begin
      if bpos>DOSPReadSize then Exit;
      repeat
	b:=buf^[bpos]; inc(bpos);
      until (bpos>DOSPReadSize) or (c in ['0'..'9']);
      a:=0;
      repeat
	a:=a*10+(b-ord('0'));
	b:=buf^[bpos]; inc(bpos);
      until (bpos>DOSPReadSize) or (not (c in ['0'..'9']));
      DOSPReadNumber:=a;
    end;
  begin
    if OpenData(f,'REG.KEY',No) then
    begin
      CheckMem(RegKReadSize);
      GetMem(buf,RegKReadSize);
      Seek(f,$D4);
      BlockRead(f,buf^,RegKReadSize);
      cs:=0;
      for i:=1 to $47D-$D4+1 do inc(cs,buf^[i]);
      FreeMem(buf,RegKReadSize);
      Seek(f,$CC);
      BlockRead(f,l,4);
      if l<>cs then
      begin
	Writeln(#13#10'Run WinPlan and tell me if you can play with that REG.KEY you have...'#7);
	if not Batch then PressAnyKey;
      end
      else begin
	Seek(f,$1F9);
	BlockRead(f,regstr[1],25);
	Seek(f,$291);
	BlockRead(f,xors,25);
	for i:=1 to 25 do byte(regstr[1,i]):=byte(regstr[1,i]) xor xors[i];
	Seek(f,$1C3);
	BlockRead(f,regstr[2],25);
	Seek(f,$2AA);
	BlockRead(f,xors,25);
	for i:=1 to 25 do byte(regstr[2,i]):=byte(regstr[2,i]) xor xors[i];
	Move(regstr,PlanetsRegInfo,50);
	Writeln('Registered version of VGA Planets 3.5 found');
	SWPlan:=No;
	RegWP:=Yes;
	CloseData(f);
	OpenData(f,'VPH35.DLL',Yes);
      end;
      CloseData(f);
    end;
    if RegWP then Exit;

    if OpenData(f,'PLANETS.EXE',No) then
    begin
      CheckMem(DOSPReadSize);
      GetMem(buf,DOSPReadSize);
      Seek(f,$43A00);
      BlockRead(f,buf^,DOSPReadSize);
      CloseData(f);
      bpos:=0;
      asm
	cld
	les	di,buf
	mov	bx,di
	mov	al,'5'
	mov	cx,DOSPReadSize
@@1:	repne	scasb
	jcxz	@@2
	cmp	byte ptr es:[di],'7'
	jne	@@1
	sub	di,bx
	mov	bpos,di
@@2:
      end;
      if bpos=0 then j:=int(regdata[51])+1
      else begin
	inc(bpos,10);
	for i:=1 to 51 do regdata[i]:=DOSPReadNumber;
	for j:=1 to 2 do
	for i:=1 to 25 do
	  regstr[j,i]:=char((int(regd[j,i])-13) div i);
	j:=0;
	for i:=1 to 50 do inc(j,regs[i]);
      end;
      FreeMem(buf,DOSPReadSize);
      if j<>int(regdata[51]) then
      begin
	Writeln(#13#10'Interesting PLANETS.EXE you have...'#7);
	if not Batch then PressAnyKey;
      end
      else if Diff(regstr,PlanetsRegInfo,50) then
      begin
	Writeln('Registered version of VGA Planets 3.0 found');
	Move(regstr,PlanetsRegInfo,50);
	SWPlan:=No;
      end;
    end;
  end;

procedure MakeTRN;
  var	trn,cmd	: file;
	dat,dis	: file;
	s	: string[100];
	nc,fp,c	: long;
	i,n,k	: int;
	mb	: MsgBuf;
	b	: BRec;
	b0	: BRec absolute mb;
	p	: PRec absolute b;
	p0	: PRec absolute b0;
	h	: SRec absolute b;
	h0	: SRec absolute b0;
	omsgh	: record
		    offs	: long;
		    len,fr_,to_	: int;
		  end;
	snm	: file;
	sname	: ^snames;
	snfirst	: boolean;
  procedure PutI2 (i:int);
    begin
      BlockWrite(cmd,i,2);
    end;
  procedure PutI4 (l:long);
    begin
      BlockWrite(cmd,l,4);
    end;
  procedure PutCmd (op,len:int);
    begin
      inc(nc);
      PutI2(len);
      PutI2(op);
      PutI2(k);
    end;
  procedure DiffI0 (op,i:int);
    begin
      if i<>0 then PutCmd(op,4);
    end;
  procedure DiffI2 (op,i,i0:int);
    begin
      if i<>i0 then begin PutCmd(op,6); PutI2(i) end;
    end;
  procedure DiffI4 (op:int; l,l0:long);
    begin
      if l<>l0 then begin PutCmd(op,8); PutI4(l) end;
    end;
  procedure DiffArr (op:int; var a,a0; len:int);
    begin
      { it's pretty ugly to do that op=$35 test here, but who cares... --sr }
      if Diff(a,a0,len) or ((op=$35) and (integer(a)<>0)) then begin
        PutCmd(op,len+4); BlockWrite(cmd,a,len);
      end;
    end;
  procedure DiffTransfer (op:int; var dat);
    var a : array[1..6] of int absolute dat;
    const len = 14;
    begin
      { planets.exe generates 'dull transfers' (everything is zero
        except for the target Id. Since cargo transfer orders always
        are zero in dis files, we just check non-emptyness of the
        transfer amounts. }
      if a[1] or a[2] or a[3] or a[4] or a[5] or a[6] <> 0 then begin
        PutCmd(op,len+4);
        Blockwrite(cmd,dat,len);
      end;
    end;
  procedure CopyFileToFile(var f, t:file; L:long);
    var buffer : array[0..2047] of byte;
        now    : integer;
    begin
      while l > 0 do begin
        if l > sizeof(Buffer) then now := sizeof(Buffer) else now := L;
        Dec(L, Now);
        Blockread(f, Buffer, Now);
        Blockwrite(t, Buffer, Now);
      end;
    end;

 {$IFDEF VPACC}
  { This is part of a new feature of PHost 4.0: a file relay. TRN command
    62 allows one to put arbitrary records into his own util.dat. The
    "$send-file" command in cmdX.txt is an interface for that which causes
    VPA (and PCC, PCC II and Portable Maketurn) to send a command 62
    containing a file. If you use that feature with a different host, your
    TRN will probably be rejected. }
  procedure SendFile(const name:string);
    var T:file;
        L:long;
        datah:record
            typ    : int;
            size   : int;
            fname  : array[1..12] of char;
            flag   : byte;
        end;
    begin
      FileMode := 0;
      Assign(T, addir + name);
      Reset(t, 1);
      if IOResult<>0 then begin
        Writeln('Can''t open file ' + name + ', ignoring it.');
        Exit;
      end;
      L := FileSize(T);
      if (L < 0) or (L > 32000) then begin
        Writeln('File ' + name + ' is too large to include in turn file, ignoring it.');
        Close(T);
        Exit;
      end;

      k := 0; { receiver. 0 means same as sender }
      PutCmd(62, Sizeof(datah)+4 + L);
      FillChar(datah.fname, 12, ' ');
      Move(name[1], datah.fname, Length(name));
      datah.typ := 34;
      datah.size := L + 13;
      datah.flag := 0;
      BlockWrite(cmd, datah, Sizeof(datah));
      CopyFileToFile(T, cmd, L);
      Close(T);
    end;
  procedure SendString(recv:int; s:string);
    var i : int;
    begin
      for i:=1 to length(s) do inc(s[i], 13);
      k := length(s);
      PutCmd(60, k + 8);
      PutI2(player);
      PutI2(recv);
      BlockWrite(cmd, s[1], k);
    end;
  procedure SendPHostCommands;
    var s, s1 : string;
        p, p0 : PPHostCommand;
    begin
      p0 := phc; phc := NIL;
      LoadPHostCommands;
      p := phc;
      s := '';
      while p<>nil do begin
        if p^.Cmd=phc_SendFile then
          SendFile(p^.arg)
        else begin
          s1 := PHostCommandString(p);
          if (s1<>'') and (s1[1]<>'$') then begin
            if (integer(length(s1)) + length(s) > 250) then begin
              SendString(player, s);
              s := '';
            end;
            s := s + s1 + #13;
          end;
        end;
        p := p^.next;
      end;
      if s<>'' then SendString(player, s);
      FreePHostCommands(FALSE);
      phc := p0;
    end;
 {$ENDIF}
  begin
    s:='PLAYER'+plstr+'.TRN';
    Writeln('Making ',addir,s,'...');
    if not OpenW(trn,s,No) then Exit;
    nc:=0;
    BlockWrite(trn,player,2);
    BlockWrite(trn,nc,4);
    BlockWrite(trn,Stamp,20);	{skip +2 bytes}
    n:=0;
    for i:=1 to 18 do inc(n,byte(Stamp[i]));
    BlockWrite(trn,n,3);	{skip +1 byte}
    s:='VPATRN.TMP';		{ VPATRN.TMP structure: }
    if not OpenW(cmd,s,No) then	{ cmdlen (2), command (cmdlen), ... }
    begin
      Close(trn);
      Erase(trn);
      Exit;
    end;

    OpenRW(dat,'SHIP'+plstr+'.DAT',Yes);
    OpenRW(dis,'SHIP'+plstr+'.DIS',Yes);
    BlockRead(dat,n,2);
    BlockRead(dis,n,2);
    if ScrambleShipNames and (n>0) then
    begin
      CheckMem(n*SizeOf(snrec));
      GetMem(sname,n*SizeOf(snrec));
      snfirst:=not OpenRW(snm,'VPASNM'+plstr+'.DAT',No);
      if snfirst then
      begin
	OpenW(snm,'VPASNM'+plstr+'.DAT',Yes);
	FillChar(sname^,n*SizeOf(snrec),0);
      end
      else BlockRead(snm,sname^,n*SizeOf(snrec));
    end;
    for i:=1 to n do
    begin
      BlockRead(dat,h,SRecordSize);
      BlockRead(dis,h0,SRecordSize);
      if ScrambleShipNames then
      with sname^[i] do
      begin
	if snfirst then
	begin
	  Move(ScrambledName,alias,ScrambledNameLen);
	  for k:=ScrambledNameLen+1 to 20 do alias[k]:=FCChar[Random(36)];
	end;
	Move(h.name,realname,20);
	Move(alias,h.name,20);
      end;
      k:=h.when;	{corresponds to ID in DAT/DIS}
      DiffArr(1,h.fcode,h0.fcode,3);
      DiffI2(2,h.warp,h0.warp);
      DiffArr(3,h.wx,h0.wx,4);
      DiffI2(4,h.mission,h0.mission);
      DiffI2(5,h.enemy,h0.enemy);
      DiffI2(6,h.tow_ship,h0.tow_ship);
      DiffArr(7,h.name,h0.name,20);
      DiffTransfer(8,h.CN);
      DiffTransfer(9,h.TN);
      DiffI2($0A,h.intr_ship,h0.intr_ship);
      DiffI2($0B,h.fuel,h0.fuel);
      DiffI2($0C,h.T,h0.T);
      DiffI2($0D,h.D,h0.D);
      DiffI2($0E,h.M,h0.M);
      DiffI2($0F,h.Sup,h0.Sup);
      DiffI2($10,h.colonists,h0.colonists);
      DiffI2($11,h.TFnum,h0.TFnum);
      DiffI2($12,h.credits,h0.credits);
    end;
    CloseData(dat);
    CloseData(dis);
    if ScrambleShipNames and (n>0) then
    begin
      Seek(snm,0);
      BlockWrite(snm,sname^,n*SizeOf(snrec)); {because realnames can change}
      CloseData(snm);
      FreeMem(sname,n*SizeOf(snrec));
    end;

    OpenRW(dat,'PDATA'+plstr+'.DAT',Yes);
    OpenRW(dis,'PDATA'+plstr+'.DIS',Yes);
    BlockRead(dat,n,2);
    BlockRead(dis,n,2);
    for i:=1 to n do
    begin
      BlockRead(dat,p.when,PRecordSize);
      BlockRead(dis,p0.when,PRecordSize);
      k:=p.owner;	{corresponds to ID in DAT/DIS}
      DiffArr($15,p.fcode,p0.fcode,3);
      DiffI2($16,p.mines,p0.mines);
      DiffI2($17,p.factories,p0.factories);
      DiffI2($18,p.defense,p0.defense);
      DiffI4($19,p.N,p0.N);
      DiffI4($1A,p.T,p0.T);
      DiffI4($1B,p.D,p0.D);
      DiffI4($1C,p.M,p0.M);
      DiffI4($1D,p.colonists,p0.colonists);
      DiffI4($1E,p.supplies,p0.supplies);
      DiffI4($1F,p.funds,p0.funds);
      DiffI2($20,p.Ctax,p0.Ctax);
      DiffI2($21,p.Ntax,p0.Ntax);
      DiffI0($22,p.build);
    end;
    CloseData(dat);
    CloseData(dis);

    OpenRW(dat,'BDATA'+plstr+'.DAT',Yes);
    OpenRW(dis,'BDATA'+plstr+'.DIS',Yes);
    BlockRead(dat,n,2);
    BlockRead(dis,n,2);
    for i:=1 to n do
    begin
      BlockRead(dis,k,2);
      BlockRead(dat,k,2);
      BlockRead(dat,b,BRecordSize-2);
      BlockRead(dis,b0,BRecordSize-2);
      DiffI2($28,b.defense,b0.defense);
      DiffI2($29,b.El,b0.El);
      DiffI2($2A,b.Hl,b0.Hl);
      DiffI2($2B,b.Wl,b0.Wl);
      DiffArr($2C,b.EE,b0.EE,18);
      DiffArr($2D,b.HH,b0.HH,40);
      DiffArr($2E,b.WW,b0.WW,20);
      DiffArr($2F,b.LL,b0.LL,20);
      DiffArr($30,b.TT,b0.TT,20);
      DiffI2($31,b.fighters,b0.fighters);
      DiffI2($32,b.fShip,b0.fShip);
      DiffI2($33,b.fOp,b0.fOp);
      DiffI2($34,b.order,b0.order);
      DiffArr($35,b.cHl,b0.cHl,14);
      DiffI2($36,b.Tl,b0.Tl);
    end;
    CloseData(dat);
    CloseData(dis);

    OpenRW(dat,'MESS'+plstr+'.DAT',Yes);
    BlockRead(dat,n,2);
    for i:=1 to n do
    begin
      Seek(dat,long(i-1)*SizeOf(omsgh)+2);
      BlockRead(dat,omsgh,SizeOf(omsgh));
      k:=omsgh.len;
      if k>SizeOf(MsgBuf)-8 then k:=SizeOf(MsgBuf)-8;
      PutCmd($3C,k+8);	{ puts $3C,k }
      BlockWrite(cmd,omsgh.fr_,4);
      Seek(dat,omsgh.offs-1);
      BlockRead(dat,mb,k);
      BlockWrite(cmd,mb,k);
    end;
    CloseData(dat);

   {$IFDEF VPACC}
    SendPHostCommands;
   {$ENDIF}

    OpenRW(dat,'GEN'+plstr+'.DAT',Yes);
    Seek(dat,$8D);
    BlockRead(dat,k,2);
    if k=13 then
    begin
      k:=0;
      PutCmd($3D,14);	{ puts $3D,0 }
      BlockRead(dat,mb,10);
      BlockWrite(cmd,mb,10);
    end;
    CloseData(dat);

    CloseData(cmd);
    fp:=nc*4+$1D+1;	{offset +1 for Basic}
    Reset(cmd,1);
    for c:=1 to nc do
    begin
      BlockWrite(trn,fp,4);
      BlockRead(cmd,n,2);
      Seek(cmd, FilePos(cmd) + n); {BlockRead(cmd,mb,n);}
      inc(fp,n);
    end;
    Seek(cmd,0);
    for c:=1 to nc do
    begin
      BlockRead(cmd,n,2);
      CopyFileToFile(cmd, trn, n);
      {BlockRead(cmd,mb,n);
      BlockWrite(trn,mb,n);}
    end;
    CloseData(cmd);
    Erase(cmd);

    if RegWP then
    begin
      s:='VER3.500';
      BlockWrite(trn,s[1],8);
      OpenData(dat,'VPH35.DLL',Yes);
      Seek(dat,(today-2)*4+347);
      BlockRead(dat,c,4);
      c:=c and $7FFFFFFF;
      BlockWrite(trn,c,4);
      Seek(dat,(today-2)*4+1857);
      BlockRead(dat,c,4);
      c:=c and $7FFFFFFF;
      BlockWrite(trn,c,4);
      BlockRead(dat,s[1],50);	{just for XORing}
      CloseData(dat);
      BlockWrite(trn,s[1],25);
      for i:=1 to 25 do byte(s[i]):=byte(s[i]) xor byte(PlanetsRegInfo[1,i]);
      BlockWrite(trn,s[1],50);	{1..25 xored, 26-50 not yet}
      for i:=1 to 25 do byte(s[i+25]):=byte(s[i+25]) xor byte(PlanetsRegInfo[2,i]);
      BlockWrite(trn,s[26],25);
      s[0]:=#0;
      if OpenData(dat,'REG.KEY',No) then
      begin
	Seek(dat,$96);
	BlockRead(dat,c,4);
	if c=13 then
	begin
	  Seek(dat,0);
	  BlockRead(dat,s[1],100);
	  s[0]:=#100;
	  for i:=1 to 100 do dec(byte(s[i]),13);
	end;
	CloseData(dat);
      end;
      if s[0]=#0 then
      begin
	FillChar(s[1],100,' ');
	s:='Anonymous WinPlan owner';
      end;
      BlockWrite(trn,s[1],100);
      FillChar(s[1],100,0);
      BlockWrite(trn,s[1],100);
    end;

    fp:=FilePos(trn);
    Seek(trn,2);
    BlockWrite(trn,nc,4);

    Seek(trn,26);
    BlockRead(trn,n,2);
    Seek(trn,0);
    c:=n*3+13;
    nc:=fp;
    while nc>0 do
    begin
      if nc<SizeOf(mb) then n:=nc else n:=SizeOf(mb);
      BlockRead(trn,mb,n);
      for i:=1 to n do inc(c,mb[i]);
      dec(nc,SizeOf(mb));
    end;
    {notice that we are back at pos=fp now}
    BlockWrite(trn,c,8);	{skip +4 bytes}

    OpenRW(dat,FIZZ_BIN,Yes);
    Seek(dat,$88);
    BlockRead(dat,mb,204);
    CloseData(dat);
    BlockWrite(trn,mb,204);

    for i:=1 to 44 do mb[i]:=Random(256);
    for i:=1 to 11 do
      if (i<>player) and OpenRW(dat,'PLAYER'+NStr(i)+'.TRN',No) then
      begin
	Seek(dat,6);
	BlockRead(dat,s[1],18);
	s[0]:=#18;
	Seek(dat,FileSize(dat)-44);
	BlockRead(dat,mb[45],44);
	CloseData(dat);
	if s=Stamp then
	begin
	  Move(mb[45],mb[1],44);
	  Break;
	end;
      end;
    BlockWrite(trn,mb[1],44);

    Close(trn);
  end;

procedure UnpackRST (race:int);
  const	BufSize	= 4000*2;		{ max size is SHIPXY and MINES }
  var	content	: record
		    ship,target,pdata,bdata,
		    mdata,shipxy,gen,vcr	: long;
		    id1				: array [1..6] of char;
		    id2				: array [1..2] of char;
		    kore,leech,xufo		: long;
		    extra			: array [1..11] of long;
		  end;
	rst,dat,dis	: file;
	ctrl1,ctrl2	: file;
	plstr		: string[2];
	i,n,k,sz	: integer;
	l,nn,fs		: long;
	sig		: array [1..4] of char absolute nn;
	buf		: ^ByteArr;
	bufI		: ^IntArr absolute buf;
	stamp,stamp1	: TimeStamp;
	tail1,tail2	: array [1..10] of byte;
	turnN		: int;
	xt		: xtype;
	xsum    	: array [xtype] of long;
	xptr		: array [xtype] of long;
	snm_,snb_	: string[12];
        seen_big_id     : boolean;
  procedure CheckOffs (l:long);
    begin
      if (l<0) or (l>=fs) then
	begin Writeln(#13#10'RST file is corrupt!'); Halt end;
    end;
  begin
    plstr:=NStr(race);
    if not OpenRW(rst,'PLAYER'+plstr+'.RST',No) then Exit;
    Writeln('Unpacking ',addir,'PLAYER',plstr,'.RST...');

    CheckMem(BufSize);
    GetMem(buf,BufSize);
    fs:=FileSize(rst);
    BlockRead(rst,content,SizeOf(content));

    OpenW(dat,'GEN'+plstr+'.DAT',Yes);
    l:=content.gen-1;
    CheckOffs(l+144-1);
    Seek(rst,l);
    BlockRead(rst,buf^,18+88+2+20+3*4);	{ time stamp, score, race, password, sums }
    Move(buf^,stamp,18);
    BlockWrite(dat,buf^,18+88+2+20+1);	{ skip +1 byte }
    Move(buf^[18+88+2+11],tail1,10);
    for i:=1 to 10 do tail2[i]:=tail1[i]+i;
    FillChar(buf^,3*4+12,0);	   	{ 3 checksums, new password }
    BlockWrite(dat,buf^,3*4+12);
    BlockRead(rst,buf^,4);			{ turn, timestamp sum }
    turnN:=bufI^[1];
    BlockWrite(dat,buf^,4);
    Truncate(dat);
    CloseData(dat);

    xptr[Sh]:=content.ship-1;
    xptr[Pl]:=content.pdata-1;
    xptr[Ba]:=content.bdata-1;
    OpenW(ctrl1,'CONTROL.DAT',Yes);
    OpenW(ctrl2,'CONTRL'+plstr+'.DAT',Yes);
    seen_big_id := false;
    for xt:=Sh to Ba do
    begin
      sz:=xISize[xt];
      OpenW(dat,xFName[xt]+plstr+'.DAT',Yes);
      OpenW(dis,xFName[xt]+plstr+'.DIS',Yes);
      l:=xptr[xt];
      CheckOffs(l+2-1);
      Seek(rst,l);
      BlockRead(rst,n,2);
      CheckOffs(l+2+long(n)*sz-1);
      BlockWrite(dat,n,2);
      BlockWrite(dis,n,2);
      xsum[xt]:=(Lo(n)+Hi(n))*2;
      for i:=1 to n do
      begin
	BlockRead(rst,buf^,sz);
	BlockWrite(dat,buf^,sz);
	BlockWrite(dis,buf^,sz);
	nn:=0;
	for k:=1 to sz do inc(nn,buf^[k]);
	inc(xsum[xt],nn*2);
	k:=bufI^[xINum[xt]];
        if k>500 then seen_big_id := true;
        l:=ControlPosition(xt, k);
	Seek(ctrl1,l);
	BlockWrite(ctrl1,nn,4);
	Seek(ctrl2,l);
	BlockWrite(ctrl2,nn,4);
      end;
      BlockWrite(dat,tail2,10);
      BlockWrite(dis,tail1,10);
      for i:=1 to 10 do inc(xsum[xt],int(tail1[i])+tail2[i]);
      Truncate(dat);
      CloseData(dat);
      Truncate(dis);
      CloseData(dis);
    end;
    i:=0;
    if seen_big_id then l:=9996 else l:=6001;
    Seek(ctrl1,l);
    BlockWrite(ctrl1,i,2);
    Truncate(ctrl1);
    CloseData(ctrl1);
    Seek(ctrl2,l);
    BlockWrite(ctrl2,i,2);
    Truncate(ctrl2);
    CloseData(ctrl2);
    OpenRW(dat,'GEN'+plstr+'.DAT',Yes);
    Seek(dat,$81);
    BlockWrite(dat,xsum,12);
    CloseData(dat);

    OpenW(dat,'TARGET'+plstr+'.DAT',Yes);
    l:=content.target-1;
    CheckOffs(l+2-1);
    Seek(rst,l);
    BlockRead(rst,n,2);
    CheckOffs(l+2+long(n)*STRecordSize-1);
    BlockWrite(dat,n,2);
    for i:=1 to n do
    begin
      BlockRead(rst,buf^,STRecordSize);
      BlockWrite(dat,buf^,STRecordSize);
    end;
    BlockWrite(dat,tail2,10);
    Truncate(dat);
    CloseData(dat);
    EraseGameFile('TARGET'+plstr+'.EXT');

    OpenW(dat,'MDATA'+plstr+'.DAT',Yes);
    l:=content.mdata-1;
    CheckOffs(l+2-1);
    Seek(rst,l);
    BlockRead(rst,n,2);
    CheckOffs(l+2+long(n)*6-1);
    BlockWrite(dat,n,2);
    for i:=1 to n do
    begin
      Seek(rst,l+2+long(i-1)*6);
      BlockRead(rst,nn,4);
      dec(nn);
      BlockRead(rst,k,2);
      CheckOffs(nn);
      CheckOffs(nn+k-1);
      Seek(rst,nn);
      BlockRead(rst,buf^,k);
      dec(nn,l);
      inc(nn);
      Seek(dat,long(i-1)*6+2);
      BlockWrite(dat,nn,4);
      BlockWrite(dat,k,2);
      Seek(dat,nn-1);
      BlockWrite(dat,buf^,k);	{ must be after header writing. truncate follows! }
    end;
    Truncate(dat);
    CloseData(dat);
    i:=0;
    OpenW(dat,'MESS35'+plstr+'.DAT',Yes);
    BlockWrite(dat,i,2);
    Truncate(dat);
    CloseData(dat);
    OpenW(dat,'MESS'+plstr+'.DAT',Yes);
    BlockWrite(dat,i,2);
    Truncate(dat);
    CloseData(dat);

    OpenW(dat,'SHIPXY'+plstr+'.DAT',Yes);
    l:=content.shipxy-1;
    i:=IIF(content.gen-content.shipxy>=999*8,999,500);
    CheckOffs(l+i*8-1);
    Seek(rst,l);
    BlockRead(rst,buf^,i*8);
    BlockWrite(dat,buf^,i*8);
    BlockWrite(dat,tail2,10);
    Truncate(dat);
    CloseData(dat);

    OpenW(dat,'VCR'+plstr+'.DAT',Yes);
    l:=content.vcr-1;
    CheckOffs(l+2-1);
    Seek(rst,l);
    BlockRead(rst,n,2);
    CheckOffs(l+2+long(n)*SizeOf(VCRData)-1);
    BlockWrite(dat,n,2);
    for i:=1 to n do
    begin
      BlockRead(rst,buf^,SizeOf(VCRData));
      BlockWrite(dat,buf^,SizeOf(VCRData));
    end;
    BlockWrite(dat,tail2,10);
    Truncate(dat);
    CloseData(dat);

    if content.id1='VER3.5' then
    begin

      OpenW(dat,'KORE'+plstr+'.DAT',Yes);
      BlockWrite(dat,turnN,9);		{ skip +7 bytes }
      BlockWrite(dat,tail2,10);
      Seek(dat,$66);
      l:=content.kore-1;
      Seek(rst,l);

      CheckOffs(l+500*MRecordSize-1);
      inc(l,500*MRecordSize);
      BlockRead(rst,buf^,500*MRecordSize);
      BlockWrite(dat,buf^,500*MRecordSize);

      CheckOffs(l+50*IRecordSize-1);
      inc(l,50*IRecordSize);
      BlockRead(rst,buf^,50*IRecordSize);
      BlockWrite(dat,buf^,50*IRecordSize);

      CheckOffs(l+50*4-1);
      inc(l,50*4);
      BlockRead(rst,buf^,50*4);
      BlockWrite(dat,buf^,50*4);

      OpenW(dis,'RACE.NM',Yes);
      CheckOffs(l+11*(30+20+12)-1);
      inc(l,11*(30+20+12));
      BlockRead(rst,buf^,11*(30+20+12));
      BlockWrite(dis,buf^,11*(30+20+12));
      Truncate(dis);
      CloseData(dis);

      CheckOffs(l+100*URecordSize-1);
      inc(l,100*URecordSize);
      for i:=1 to 100 do
      begin
	BlockRead(rst,buf^,URecordSize);
	BlockWrite(dat,buf^,URecordSize);
      end;

      CheckOffs(l+4-1);
      BlockRead(rst,nn,4);
      inc(l,4);
      BlockWrite(dat,nn,20);	{ skip +16 bytes }
      if sig=ExtraTargetSig then
      begin
	CheckOffs(l+4-1);
	BlockRead(rst,nn,4);
	BlockWrite(dat,nn,4);
	n:=nn;
	CheckOffs(l+4+long(n)*STRecordSize-1);
	inc(l,4+long(n)*STRecordSize);
	for i:=1 to n do
	begin
	  BlockRead(rst,buf^,STRecordSize);
	  BlockWrite(dat,buf^,STRecordSize);
	end;
      end;

      BlockWrite(dat,tail2,10);
      Truncate(dat);
      CloseData(dat);

      l:=content.leech-1;
      if (l>=0) and (l<fs) then
      begin
	CheckOffs(l+4-1);
	Seek(rst,l);
	BlockRead(rst,nn,4);
	CheckOffs(l+4+nn-1);
	OpenW(dat,'LEECH'+plstr+'.DAT',Yes);
	while nn>0 do
	begin
	  if nn>BufSize then l:=BufSize else l:=nn;
	  BlockRead(rst,buf^,l);
	  BlockWrite(dat,buf^,l);
	  dec(nn,l);
	end;
	Truncate(dat);
	CloseData(dat);
      end;

    end	{ VER3.5 data }
    else begin
      Assign(dat,addir+'KORE'+plstr+'.DAT');
      Erase(dat);
      if IOResult=0 then ;
    end;

    if OpenRW(dat,'..\SNOOKER.DAT',No) then
    begin
      BlockRead(dat,k,2);
      for i:=1 to 40 do
      begin
	BlockRead(dat,stamp1,18);
	if stamp1=stamp then begin k:=0; Break end;
      end;
      if k<>0 then
      begin
	inc(k);
	if k>40 then k:=1;
	Seek(dat,0);
	BlockWrite(dat,k,2);
	Seek(dat,(k-1)*18+2);
	BlockWrite(dat,stamp,18);
      end;
      CloseData(dat);
    end;

    if not OpenRW(dat,'INIT.TMP',No) then
    begin
      OpenW(dat,'INIT.TMP',Yes);
      FillChar(buf^,22,0);
      BlockWrite(dat,buf^,22);
    end;
    Seek(dat,(race-1)*2);
    i:=1;
    BlockWrite(dat,i,2);
    CloseData(dat);

    CloseData(rst);
    FreeMem(buf,BufSize);
    if DeleteRST then
    begin
      Writeln('Deleting ',addir,'PLAYER',plstr,'.RST...');
      Erase(rst);
      if IOResult=0 then ;
    end;

    snm_:='VPASNM'+plstr+'.DAT';
    snb_:='VPASNB'+plstr+'.DAT';
    if OpenRW(dat,snm_,No) then
    begin
      CloseData(dat);
      if not DeScrambleShipNames(race) then
      begin
	OpenRW(dat,snm_,Yes);
	fs:=FileSize(dat);
	CheckMem(fs);
	GetMem(buf,fs);
	BlockRead(dat,buf^,fs);
	CloseData(dat);
	Erase(dat);
	if IOResult=0 then ;
	if not OpenRW(dat,snb_,No) then OpenW(dat,snb_,Yes)
				   else Seek(dat,FileSize(dat));
	BlockWrite(dat,buf^,fs);
	CloseData(dat);
	Rename(dat,addir+snm_);
	if IOResult=0 then ;
	DeScrambleShipNames(race);
      end;
      Assign(dat,addir+snb_);
      Erase(dat);
      if IOResult=0 then ;
      Assign(dat,addir+snm_);
      Rename(dat,addir+snb_);
      if IOResult=0 then ;
    end;

    ExtFeatUnpackRSTEndHook(race);
  end;

End.
