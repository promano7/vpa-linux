{$I switches.inc}
Unit	Messages;	(* VPA Message Processor *)
{$V-}

Interface

uses	AuxF,VPAData;

type	Msg     = record
		    lines       : byte;
		    text        : array [1..20] of string[40];
		  end;
	MsgBuf	= array [1..840] of byte;
	MsgType	= (m_In,m_Out,m_VCR);
	MsgRaces= array [1..12] of boolean;
        str8	= string[8];

const	nmsg    : array [MsgType] of word = (0,0,0);	{ # of messages }
	msgn	: array [MsgType] of word = (1,1,1);	{ current msg number }
	msgt	: MsgType = m_In;			{ current msg set }
	msgfn	: string[40] = '';			{ last file name }
	msgr	: MsgRaces = (No,No,No,No,No,No,No,No,No,No,No,No);
	PHOSTmn	: int = 0;
	PHOSTget: byte = 0;
	PGconfig= 1;
	PGraces	= 2;
	WPMess	: boolean = No;
	WPMax	= 600;

var	imsn,vcrn	: array [1..11] of word;

type	ObjType	= (oNone,oPlanet,{oBase,oShip,}oMines,oMark);
const   Obj1	= oPlanet;
	Obj2	= oMark;
	ObjName	: array [Obj1..Obj2] of string[10] =
		( 'Planet',{'Base','Ship',}'Mine field','Marker');
	ObjLock	: array [Obj1..Obj2] of word = (LockP,{LockP,LockS,}LockM,LockA);
	ObjSize	: array [Obj1..Obj2] of word =
		( SizeOf(PRec)+SizeOf(EPln),{SizeOf(BRec),SizeOf(SRec),}SizeOf(MRec),SizeOf(MapMark) );
	MaxOSize= 6*40;
	AcceptData	: array [0..11] of boolean = (No,No,No,No,No,No,No,No,No,No,No,No);
	BlankDeadRaces	: boolean = Yes;


function  ReadMessage (var f:file; i:int; var m:Msg; ofs0:long; incoming:boolean) : byte;
function  WriteMessage (var f:file; i:int; var m:Msg; ofs0,ofsm:long; incoming:boolean; _to:byte) : int;
procedure ViewMessages;
procedure CheckPHOSTMessage;
procedure CheckWinPlanMess;
procedure StoreWinPlanMess;
procedure TransmitObject;
procedure ReadKillFile;
procedure WriteKillfile;
{moved to interface section for ExtFeat}
procedure EncodeObject (var obj; var buf; len:word);
procedure DrawMsgRectangle;
function ChooseRaces (var r:MsgRaces; cstr:str8) : boolean; { Yes if Universal }
procedure Find1stOMsg;
procedure AddMessage (race:byte; var m:Msg);
procedure CloseMessageFile;

Implementation

uses	StrF,ptcgraph,Screen,Mouse,Keyboard,TCombat,DOS,ConfigIO
{$IFDEF VPACC},
        PHostM
{$ENDIF}{,PVCR};

type	
	str39	= string[39];
	OMsgH	= record
		    offs	: long;
		    len,fr_,to_	: int;
		  end;
	WPMsgH	= record
		    word0	: int;
		    races	: array [1..12] of char;
		    len		: int;
		  end;

const	IOMX	= 0;
	MLX	= 170;
	IOMY	: array [MsgType] of byte = (0,30,60);
	MsgX	= 1;
	MsgY	= 6;
	KeyY	= (MsgY+20)*16+10;
	PVEX	= 0;
	PVEY	= MsgY+22;
	CRChar	: array [MsgType] of char = 'mev';
	MHStr	: array [MsgType] of str8 = ('INCOMING','OUTGOING','VCR');
	MVStr	: array [boolean] of string[7] = ('MESSAGE','RECORD');
	CRStr	: array [1..2] of str8 = ('write','forward');
	SSMStr	: array [1..17] of char = 'Sub Space Message';
	ClStr	: string[10] = 'client VPA';
	PVCR_EXE= 'PVCR.EXE';
	pvcrlast: boolean = No;
	pvcr	: boolean = No;
	pvcrexe	: boolean = No;

var	iodx10	: array [MsgType] of int;
	m_to	: byte;
	omsg1	: int;
	ooffs1	: long;	{ 1st message offset+1 }
	offs0	: long;	{ offset for ReadMessage: =0 for .dat, >0 for .db }
	ynkey	: word;
	f,g	: file;
	ObjFile	: boolean;
	objoffs	: long;
	msgobj	: int;
	msgvcr	: int;
	nm	: array [MsgType] of int;	{ # of messages }
	nm1	: array [MsgType] of int;	{ # of messages w/o hidden }

type PKillfile = ^TKillfile;
     TKillfile = record
              Next : PKillfile;
              Head : string[40];
     end;
     TByteArray = array[0..MaxInt] of byte;
     PByteArray = ^TByteArray;

const kill_bits  : PByteArray = nil;
      kill_count : int = 0;
      kill_turn  : int = 0;
      Killfile   : PKillfile = nil;

procedure GetMessage (n:word; var m:Msg; io:MsgType); forward;

{ TRUE iff the specified subject is killfiled }
function IsKilled(const Subject:string):PKillfile;
  var pk:PKillfile;
  begin
    pk:=Killfile;
    while (pk<>nil) and (pk^.Head<>Subject) do pk:=pk^.Next;
    IsKilled:=pk;
  end;

{ Add subject to killfile. Returns true iff successful. }
function AddKillfile(const Subject:string):BOOLEAN;
  var pk:PKillfile;
  begin
    if IsKilled(Subject)<>nil then begin
      Addkillfile:=false;
      Exit;
    end;
    if MaxAvail < Sizeof(TKillfile) THEN BEGIN
      { message? }
      AddKillfile:=false;
      Exit;
    end;
    New(pk);
    pk^.Next := Killfile;
    pk^.Head := Subject;
    Killfile := pk;
    Addkillfile:=true;
  end;

{ Remove a subject from the killfile }
function RemoveKillfile(const Subject:string):boolean;
  var pk,p:PKillfile;
  begin
    pk := IsKilled(Subject);
    if pk=nil then begin
      RemoveKillfile := false;
      Exit;
    end;
    if pk=Killfile then Killfile:=pk^.Next else begin
      p:=Killfile;
      while p^.Next<>pk do p:=p^.Next;
      p^.Next:=pk^.Next;
    end;
    Dispose(pk);
    RemoveKillfile := true;
  end;

function MessageIsKilled (typ : MsgType; index : int):boolean;
  begin
    MessageIsKilled := (typ = m_In) and (index <= kill_count)
     and (kill_bits^[index div 8] and (1 shl (index and 7))<>0);
  end;

function MessageSubject(var m:Msg):string;
  var s : string[40];
      s1 : string[15];
      i : int;
  label OldMessage;
  begin
    { cut&paste from PCC }
    s := m.text[1];
    IF Length(S)<5 THEN BEGIN
      MessageSubject:='(  ) Unknown';
      Exit;
    END;
    IF (Upcase(S[2])='O') AND (S[1]='(') THEN BEGIN
      MessageSubject := '(oX) Message from earlier turn';
      Exit;
    END;
    IF S[1]<>'(' THEN BEGIN
      S1:='';
      GOTO OldMessage;
    END;
    IF Upcase(S[3])='R' THEN BEGIN
      i:=Pos(Upcase(S[4]),'123456789AB');
      S[4]:=')';
      S[0]:=#4;
      IF i=0 THEN S:=S+' Anonymous Message' ELSE
       S:=S+' '+RaceFull[i];
      MessageSubject:=S;
    END ELSE BEGIN
      i:=Pos(')',S);     { "(-x####) <<<  >>>" }
      IF i>4 THEN Delete(S,4,i-4);
      S1:=Copy(S,1,4);
      CASE Upcase(S1[3]) OF
        'D':MessageSubject := S1+' Starbase Message';
        'L':MessageSubject := S1+' Minefield laid';
       {'Z':MessageSubject := S1+' Scanner';}
        'I':MessageSubject := S1+' Ion Storm';
        'G':MessageSubject := S1+' HConfig';
      ELSE
        Delete(S,1,4);
        S1 := S1 + ' ';
       OldMessage:
        FOR i:=Length(S) DOWNTO 1 DO CASE S[i] OF
          '<','>':Delete(S,i,1);
          'A'..'Z':IF (i>1) AND (S[i-1]>='A') THEN Inc(S[i],32);
        END;
        Trim(S);
        MessageSubject := S1+S;
      END;
    END;
  END;

{ Regenerate the killfile cache (kill_bits).
  action is 0 (message was un-killed), 1 (message was killed),
  -1 (regenerate cache on entry of message viewer)
  returns true if it did something. }
function GenerateKillfile (action:int) : boolean;
  var i, j, k : int;
      mask    : byte;
      plonk   : boolean;
      m       : Msg;
  begin
    if (action < 0) and (kill_count = nm1[m_In]) and (kill_turn = Turn) then begin
      GenerateKillfile := false;
      Exit;
    end;
    if (kill_count <> nm1[m_In]) or (kill_turn <> Turn) then begin
      if (kill_count <> 0) then FreeMem(kill_bits, 1 + kill_count div 8);
      i := 1 + nm1[m_In] div 8;
      if MaxAvail < i then begin
        { FIXME: error message }
        kill_count := 0;
        GenerateKillfile := true;
        Exit;
      end;
      GetMem(kill_bits, i);
      kill_count := nm1[m_In];
      kill_turn := Turn;
      action := -1;
    end;
    for i:=1 to kill_count do begin
      plonk := false;
      mask := 1 shl (i and 7);
      if Killfile<>nil then begin
        { shortcut: if we're killing a message, but this one is already
          killed, or we're un-killing one and this one is already shown,
          do not process it. }
        if ((action=0) and (kill_bits^[i div 8] and mask=0))
         or ((action=1) and (kill_bits^[i div 8] and mask<>0))
          then continue;
        GetMessage(i, m, m_In);
        plonk := IsKilled(MessageSubject(m))<>nil;
      end;
      if plonk then kill_bits^[i div 8] := kill_bits^[i div 8] or mask
               else kill_bits^[i div 8] := kill_bits^[i div 8] and not mask;
    end;
    GenerateKillfile := true;
  end;

type CMessageConfigIO = object(CConfigIO)
         function    Match(const s:string):boolean; virtual;
         procedure   Assign(const s:string); virtual;
         procedure   Write(var p:text; anew:boolean); virtual;
     END;

function CMessageConfigIO.Match(const s:string):BOOLEAN;
  var s7 : string[7];
  begin
    s7 := s;
    Upper(s7);
    Match := s7='FILTER';
  end;

procedure CMessageConfigIO.Assign(const s:string);
  begin
    AddKillfile(s);
  end;

procedure CMessageConfigIO.Write(var p:text; anew:boolean);
  var i, j : INTEGER;
      pk   : PKillfile;
  begin
    if anew then WriteLn(p, '# VPA Message Configuration File');

    pk := Killfile;
    while pk<>nil do begin
      Writeln(p, 'Filter=', pk^.Head);
      pk := pk^.Next;
    end;
  end;

{ Load killfile. This is the same file as used by PCC 1.1.5 and PCC II }
procedure ReadKillFile;
  var mio : CMessageConfigIO;
  begin
    mio.Init('msg' + plstr + '.ini');
    mio.ReadConfig;
  end;

{ Write killfile. For forward-compatibility, don't blindly overwrite it.
  PCC also uses it for the signature, maybe we have something to say, too,
  someday. }
procedure WriteKillfile;
  var mio : CMessageConfigIO;
  begin
    mio.Init('msg' + plstr + '.ini');
    mio.WriteConfig;
  end;

function DetermineSender (var m:Msg) : byte;
  var	m_to	: byte;
	s	: array [1..30] of char;
  begin
    m_to:=0;
    with m do
    if (text[1,1]='(') and (text[1,3]='r') then m_to:=Pos(text[1,4],'123456789AB')
    else begin
      if (lines>=3) and (Copy(text[2],1,4)='FROM') and (Copy(text[3],1,2)='TO') then
      begin
	Move(text[2,7],s,30);
	m_to:=11;
	while m_to>0 do
	begin
	  if s=RaceFull[m_to] then Break;
	  dec(m_to);
	end;
      end;
    end;
    DetermineSender:=m_to;
  end;

function ReadMessage (var f:file; i:int; var m:Msg; ofs0:long; incoming:boolean) : byte;
	{ returns TO race number for outgoing messages and FROM - for incoming }
	{ f must be open! }
  var   buf     : array [1..5] of word;
	bufl    : array [1..2] of long absolute buf;
	msgb	: MsgBuf;
	l,j     : int;
  begin
    if i<=0 then Exit;
    l:=IIF(incoming,6,10);
    Seek(f,ofs0+2+long(i-1)*l);
    BlockRead(f,buf,l);
    if not incoming then ReadMessage:=buf[5];
    Seek(f,ofs0+bufl[1]-1);
    l:=Min(buf[3],SizeOf(msgb));
    BlockRead(f,msgb,l);
    with m do
    begin
      lines:=1; text[1]:='';
      for j:=1 to l do
	if msgb[j]<>26 then
	begin
	  if msgb[j]<>23 then text[lines]:=text[lines]+chr(msgb[j]-13);
	end
	else begin
	  RTrim(text[lines]);
	  if lines<20 then begin inc(lines); text[lines]:='' end;
	end;
      while (lines>0) and (text[lines]='') do dec(lines);
    end;
    if IOResult=0 then ;
    if incoming then ReadMessage:=DetermineSender(m);
  end;

function PackMessage (var m:Msg; var buf:MsgBuf) : int;
	{ returns the length of packed message }
  var	i,j,k	: int;
  begin
    j:=0;
    with m do
      for k:=1 to 20 do
      begin
	if k<=lines then
	  for i:=1 to byte(text[k,0]) do
	    begin inc(j); buf[j]:=byte(text[k,i])+13 end;
	inc(j); buf[j]:=26;
      end;
    PackMessage:=j;
  end;

function WriteMessage (var f:file; i:int; var m:Msg; ofs0,ofsm:long; incoming:boolean; _to:byte) : int;
	{ f must be open! }
	{ there must be place to store another message }
	{ _to are used only for outgoing messages }
	{ returns the length of message written }
	{ leaves FilePos right after the message data }
  var   buf     : array [1..5] of word;
	bufl    : array [1..2] of long absolute buf;
	msgb	: MsgBuf;
	l	: int;
  begin
    if i<=0 then Exit;
    bufl[1]:=ofsm+1;
    buf[3]:=PackMessage(m,msgb);
    buf[4]:=player;
    buf[5]:=_to;
    l:=IIF(incoming,6,10);
    Seek(f,ofs0+2+long(i-1)*l);
    BlockWrite(f,buf,l);
    Seek(f,ofs0+ofsm);
    BlockWrite(f,msgb,buf[3]);
    if IOResult=0 then ;
    WriteMessage:=buf[3];
  end;

procedure OpenMsgFile;
  begin
    if DFiles and (turn=today) then
    begin
      case msgt of
	m_In	: OpenRW(f,'MDATA'+plstr+'.DAT',Yes);
	m_Out	: OpenRW(f,'MESS'+plstr+'.DAT',Yes);
	m_VCR	: OpenRW(f,'VCR'+plstr+'.DAT',Yes);
      end;
      offs0:=0;
    end
    else begin
      OpenRW(f,dbname,Yes);
      case msgt of
	m_In	: offs0:=TTurn^.data^.ipos;
	m_Out	: offs0:=TTurn^.data^.opos;
	m_VCR	: offs0:=TTurn^.data^.vpos;
      end;
    end;
  end;

function MsgSpace (offs:long) : long; { mess.dat must be open, offs=offset+1 }
  var	i	: int;
	a	: OMsgH;
	noffs	: long;
  begin
    noffs:=FileSize(f)+1000;
    Seek(f,2);
    for i:=1 to nm[m_Out] do
    begin
      BlockRead(f,a,SizeOf(OMsgH));
      if (a.offs>offs) and (a.offs<noffs) then noffs:=a.offs;
    end;
    if IOResult=0 then ;
    MsgSpace:=noffs-offs;
  end;

procedure Find1stOMsg;
  var	i	: int;
	a	: OMsgH;
  begin
    OpenRW(f,'MESS'+plstr+'.DAT',Yes);
    BlockRead(f,nm[m_Out],2);
    ooffs1:=1000000;
    for i:=1 to nm[m_Out] do
    begin
      BlockRead(f,a,SizeOf(OMsgH));
      if a.offs<ooffs1 then
	begin ooffs1:=a.offs; omsg1:=i end;
    end;
    CloseData(f);
    OpenMsgFile;
  end;

procedure DrawMsgMark (io:MsgType; i:word; c:byte);
  begin
    if nm1[io]=0 then Exit;
    if c=Black then begin
      if MessageIsKilled(io, i) then c:=cMsgKilled else c:=cMsg;
    end;
    SetColor(c);
    OutTextXY(MLX+((i-1)*iodx10[io]) div 10,IOMY[io],'.');
    if c<>White then SetColor(Black);
    SetTextJustify(CenterText,TopText);
    OutTextXY(MLX+((i-1)*iodx10[io]) div 10+3,IOMY[io]+9,NStr(i));
    SetTextJustify(LeftText,TopText);
  end;

function NNStr (a:word; ss:str39) : str39;
  var	s	: str39;
  begin
    if a=0 then s:='NO' else Str(a,s);
    s:=s+' '+ss;
    if a<>1 then s:=s+'S';
    NNStr:=s;
  end;

procedure WriteMsgLine (io:MsgType);
  var	i	: word;
  begin
    Clear(IOMX,IOMY[io],479,IOMY[io]+7);
    SetColor(cMsg);
    OutTextXY(IOMX,IOMY[io],NNStr(nm1[io],MHStr[io]+' '+MVStr[io=m_VCR]));
    if nm1[io]>0 then
    begin
      i:=Max(Min((460-MLX)*10 div nm1[io],200),1);
      if i>10 then i:=(i div 10)*10;
      iodx10[io]:=i;
      for i:=1 to nm1[io] do DrawMsgMark(io,i,0);
    end;
  end;

procedure DrawMsgRectangle;
  begin
    SetColor(cMsg);
    SetLineStyle(SolidLn,0,NormWidth);
    Rectangle(MsgX*8-4,MsgY*16-4,(MsgX+40)*8+3,(MsgY+20)*16+3);
  end;

procedure DrawMsgScreen;
  var	ii	: MsgType;
  begin
    Clear(0,0,479,479);
    for ii:=m_In to m_VCR do WriteMsgLine(ii);
    if nm1[m_In] or nm1[m_Out] or nm1[m_VCR]<>0 then DrawMsgRectangle;
  end;

procedure ClearKeyArea;
  begin
    Clear(MsgX*8,KeyY,(MsgX+40)*8-1,KeyY+8+7);
  end;

procedure ClearMsgArea;
  begin
    Clear(MsgX*8,MsgY*16,(MsgX+40)*8-1,(MsgY+20)*16-1);
    ClearKeyArea;
  end;

procedure WriteFName;
  begin
    ClearKeyArea;
    SetColor(LightGray);
    OutTextXY(MsgX*8,KeyY+8,msgfn);
  end;

function AskYN (ykey,nkey:char) : boolean;
  begin
    repeat ynkey:=ReadKey until ynkey in [13,27,byte(ykey),byte(nkey)];
    AskYN:=(ynkey in [13,byte(ykey)]);
  end;

procedure WriteLine (y:byte; s:str40);
  var	ls	: byte absolute s;
	sa	: str40;
	ss	: string[80];
	lss	: byte absolute ss;
	i	: byte;
  procedure HighLight (c:char; a:byte{; spaceend: boolean});
    var	i,k	: byte;
    begin
      k:=0;
      for i:=1 to ls do
	if s[i]=c then
	  if k=0 then k:=i
	  else begin
	    FillChar(sa[k],i-k+1,a);
	    k:=0;
	  end
	{else if spaceend and (s[i]=' ') then k:=0};
    end;
  begin
    FillChar(sa[1],ls,IIF(s[1]='>',LightGray,TextAttr));
    HighLight('/',cMsgHL1{,No});
    HighLight('_',cMsgHL2{,Yes});
    HighLight('*',cMsgHL3{,No});
    lss:=0;
    for i:=1 to ls do ss:=ss+s[i]+sa[i];
    WriteXYAttr(MsgX,MsgY+y-1,ss);
  end;

procedure WriteOMsgHeader (r:MsgRaces);
  var	s	: str39;
	ls	: byte absolute s;
	i,j	: byte;
  begin
    TextAttr:=cMsg xor 8;
    WriteLine(1,'<< '+SSMStr+' >>');
    WriteLine(2,'FROM: '+RaceFull[player]);
    s:='Races ';
    for i:=1 to 12 do
      if r[i] then begin s:=s+NStr(i)+','; j:=i end;
    dec(ls);
    if ls<9 then s:=RaceFull[j]
    else if r[12] then
    begin
      dec(ls,3);
      if Pos(',',s)=0 then Delete(s,5,1);
      s:=s+' and the Host'
    end;
    WriteLine(3,'TO: '+s);
  end;

procedure DrawMessage (var m:Msg);
  var	i,di,j	: int;
	r	: MsgRaces;
	s,s1	: str39;
	kx	: int;
  procedure WriteKey (s:str8);
    var	ls	: byte absolute s;
    begin
      SetColor(White);
      OutTextXY(kx,KeyY,s[1]);
      SetColor(cMsg);
      OutTextXY(kx,KeyY,s);
      SetColor(White);
      OutTextXY(kx,KeyY,s[1]);
      inc(kx,(ls+2)*8);
    end;
  begin
    ClearMsgArea;
    with m do
    begin
      j:=1;
      case msgt of
	m_In	: begin
		    TextAttr:=cMsg xor 8;
		    WriteLine(1,text[1]);
		    j:=2;
		    if (Copy(text[2],1,6)='FROM: ') and (Copy(text[3],1,2)='TO') then
		    begin
		      WriteLine(2,text[2]);
		      WriteLine(3,text[3]);
		      j:=4;
		    end;
		    di:=0;
		  end;
	m_Out	: begin
		    FillChar(r,SizeOf(r),0);
		    r[m_to]:=Yes;
		    WriteOMsgHeader(r);
		    di:=4;
		  end;
	m_VCR	: begin
		    TextAttr:=cMsg xor 8;
		    WriteLine(1,'<<< Visual Combat Recording >>>');
		    di:=2;
		  end;
      end;
      TextAttr:=cMsg;
      for i:=j to lines do
	if di+i<=20 then WriteLine(di+i,text[i]);
      kx:=MsgX*8;
      if (msgobj and LockHi=LockP) and (TTurn^.data^.xyplan[msgobj and LockLo,1]=-1) then msgobj:=0;
      if msgobj<>0 then WriteKey('Map');
      if RWMode and (turn=today) then WriteKey('New');
      WriteKey('Save');
      if RWMode and (turn=today) then
      begin
	WriteKey('Load');
	if (msgt=m_In) and (m_to>0) then WriteKey('Reply');
	if msgt=m_Out then begin WriteKey('Edit'); WriteKey('Delete') end;
	WriteKey('Forward');
      end;
      if msgt=m_In then begin
        if MessageIsKilled(m_In, msgn[m_In]) then WriteKey('Unkill')
                                             else WriteKey('Kill');
      end;
      if (msgvcr<>0) and ((not pvcr) or pvcrexe) then WriteKey('View');
    end;
  end;

function EditMessage (var m:Msg) : boolean;
  var	i		: int;
	x,y,x1,y1	: byte;
	cur		: boolean;
	t0		: long;
	ch		: word;
	c		: char;
	msize		: int;
  procedure DrawCursor;
    begin
      SetWriteMode(XORPut);
      SetColor(cMsg);
      Rectangle((MsgX+x-1)*8,(MsgY+3+y)*16+14,(MsgX+x-1)*8+7,(MsgY+3+y)*16+15);
      SetWriteMode(NormalPut);
      cur:=not cur;
    end;
  procedure WrLine (y:byte);
    begin
      WriteLine(y+4,m.text[y]);
    end;
  procedure CutLine;
    var	i	: byte;
    begin
      if y<16 then
      with m do
      begin
	for i:=16 downto y+2 do
	  begin text[i]:=text[i-1]; WrLine(i) end;
	text[y+1]:=Copy(text[y],x,40);
	LTrim(text[y+1]);
	RPad(text[y+1],40);
	text[y,0]:=chr(x-1);
	RPad(text[y],40);
	WrLine(y);
	inc(y); x:=1;
      end;
    end;
  procedure DeleteLine;
    var	i	: byte;
    begin
      with m do
      begin
	for i:=y to 16 do text[i]:=text[i+1];
	text[16,0]:=#0;
	RPad(text[16],40);
      end;
      for i:=y to 16 do WrLine(i);
    end;
  begin
    ClearKeyArea;
    SetColor(cMsg);
    OutTextXY(MsgX*8,KeyY,'Edit the message text');
    OutTextXY(MsgX*8,KeyY+8,'Press Esc when done');
    SetColor(White);
    OutTextXY((MsgX+6)*8,KeyY+8,'Esc');
    TextAttr:=cMsg;
    with m do
    begin
      for i:=1 to 16 do
      begin
	if i>lines then text[i,0]:=#0;
	RPad(text[i],40);
	WrLine(i);
      end;
      x:=1; y:=IIF(Pos('<<<',text[1])=0,1,2);
      cur:=Off; t0:=Timer;
      repeat
	msize:=-2;	{ last CR/LF may be omitted }
	if WPMess then
	begin
	  i:=16;
	  while (i>0) and (RLen(text[i])=0) do dec(i);
	  while i>0 do
	  begin
	    inc(msize,RLen(text[i])+2);
	    dec(i);
	  end;
	end;
	while not KeyPressed do
	  if Timer>t0+1 then begin DrawCursor; t0:=Timer end;
	if cur then DrawCursor;
	ch:=ReadKey;
	case ch of
{Left}	  $4B00	: if x>1 then dec(x);
{Right}	  $4D00	: if x<41 then inc(x);
{Up}	  $4800	: if y>1 then dec(y);
{Down}	  $5000	: if y<16 then inc(y);
{Home}	  $4700	: x:=1;
{End}	  $4F00	: x:=RLen(text[y])+1;
{PgUp}	  $4900	: y:=1;
{PgDn}	  $5100	: y:=16;
{Del}	  $5300	: begin
		    y1:=RLen(text[y]);
		    if x<=y1 then
		      begin Delete(text[y],x,1); text[y]:=text[y]+' ' end
		    else if y<16 then
		    begin
		      x1:=40-y1-1+1;
		      while (x1>0) and (text[y+1,x1]<>' ') do dec(x1);
		      text[y]:=Copy(text[y],1,y1)+' '+Copy(text[y+1],1,x1);
		      RPad(text[y],40);
		      Delete(text[y+1],1,x1);
		      RPad(text[y+1],40);
		      if RLen(text[y+1])=0 then
			begin inc(y); DeleteLine; dec(y) end
		      else WrLine(y+1);
		    end;
		  end;
{BkSp}	  8	: if x>1 then
		  begin
		    Delete(text[y],x-1,1); text[y]:=text[y]+' ';
		    dec(x);
		  end;
{chars}	  32..254: {if msize<WPMax then}	{ WinPlan... }
		   begin
		     x1:=x; y1:=y;
		     if (x=41) or (text[y,40]<>' ') then
		     begin
		       x:=40;
		       if (x1=41) and (ch=32) then ch:=0
		       else while (x>0) and (text[y,x]<>' ') do dec(x);
		       if x<x1 then
		       begin
			 x1:=x1-x;
			 if y1<16 then inc(y1);
		       end;
		       inc(x);
		       if x=1 then begin x:=41; x1:=1 end;
		       CutLine;
		       x:=x1;
		       if y<>y1 then begin WrLine(y); y:=y1 end;
		     end;
		     if ch<>0 then
		     begin
		       Insert(chr(ch),text[y],x);
		       inc(x);
		     end;
		   end;
{Enter}	  13	: CutLine;
{^Y}	  25	: DeleteLine;
	end;
	WrLine(y);
      until (ch=27) or (ch=$3C00) or (ch=$4400);
      for i:=1 to 16 do RTrim(text[i]);
      i:=16;
      while (i>0) and (text[i,0]=#0) do dec(i);
      lines:=i;
    end;
    ClearKeyArea;
    SetColor(cMsg);
    OutTextXY(MsgX*8,KeyY,'Save message(s)? Y/N');
    SetColor(Yellow);
    OutTextXY((MsgX+17)*8,KeyY,'Y N');
    EditMessage:=AskYN('y','n');
  end;

function ChooseRaces (var r:MsgRaces; cstr:str8) : boolean; { Yes if Universal }
  var	i,i0,im	: byte;
	ch	: word;
	alive	: MsgRaces;
	sco	: array [1..2] of long;
  procedure DrawRace (highlight:boolean);
    begin
      TextAttr:=IIF((i>=13) or alive[i],IIF(highlight,Yellow,cMsg),DarkGray);
      if i<13 then
      begin
	WriteXY(MsgX+4,MsgY+1+i,chr(IIF(r[i],ord('*'),ord(' '))));
	WriteXY(MsgX+6,MsgY+1+i,RaceFull[i]);
      end
      else if i=13 then WriteXY(MsgX+6,MsgY+1+13,'Universal Message')
      else WriteXY(MsgX+6,MsgY+1+14,'Team Message');
    end;
  begin
    ClearMsgArea;
    TextAttr:=cMsg;
    WriteXY(MsgX+4,MsgY,'Select races to '+cstr+' message to:');
    WriteXY(MsgX+4,MsgY+17,'Use Spacebar to select/deselect');
    WriteXY(MsgX+4,MsgY+18,'    Enter to finish selection');
    WriteXY(MsgX+4,MsgY+19,'    Esc to cancel message');
    TextAttr:=White;
    WriteXY(MsgX+8,MsgY+17,'Spacebar');
    WriteXY(MsgX+8,MsgY+18,'Enter');
    WriteXY(MsgX+8,MsgY+19,'Esc');
    im:=13;
    for i:=1 to 11 do
      if IsData[i] then begin im:=14; Break end;
    alive[12]:=Yes;
    for i:=1 to im do
    begin
      if i<12 then
	if BlankDeadRaces then
	begin
	  Move(TTurn^.score[i],sco,8);
	  alive[i]:=(sco[1] or sco[2])<>0;
	end
	else alive[i]:=Yes;
      DrawRace(No);
    end;
    i:=1; while (i<=11) and (not r[i]) do inc(i);
    if i>11 then
    begin
      i:=1;
      while (i<=11) and (not alive[i]) do inc(i);
    end;
    ChooseRaces:=No;
    repeat
      DrawRace(Yes);
      ch:=ReadKey;
      DrawRace(No);
      case ch of
	$4800	: repeat i:=IIF(i=1,im,i-1) until (i>=12) or alive[i];
	$5000	: repeat i:=IIF(i=im,1,i+1) until (i>=12) or alive[i];
	32	: if i<13 then r[i]:=not r[i]
		  else begin
		    if i=13 then begin r:=alive; r[12]:=No end
			    else Move(IsData[1],r,11);
		    ch:=13;
		    ChooseRaces:=Yes;
		  end;
	13	: if i<13 then
		  begin
		    i0:=i; i:=1;
		    while (i<=12) and (r[i]=No) do inc(i);
		    if i>12 then r[i0]:=Yes;
		  end
		  else begin
		    if i=13 then begin r:=alive; r[12]:=No end
			    else Move(IsData[1],r,11);
		    ChooseRaces:=Yes;
		  end;
	27	: FillChar(r,SizeOf(MsgRaces),No);
      end;
    until ch in [13,27];
  end;

procedure AddMessage (race:byte; var m:Msg);
  var	buf	: MsgBuf;
	a	: OMsgH;
	fs,hp	: long;
  begin
    inc(nm[m_Out]);
    inc(nm1[m_Out]);
    inc(nmsg[m_Out]);
    fs:=FileSize(f);
    Seek(f,0);
    BlockWrite(f,nm[m_Out],2);
    if nm[m_Out]=1 then
    begin
      FillChar(buf,500,0);
      BlockWrite(f,buf,500);
      fs:=502;
    end
    else if ooffs1<=2+nm[m_Out]*10 then	{ relocate 1st message if needed }
    begin
      hp:=2+long(omsg1-1)*10;
      Seek(f,hp);
      BlockRead(f,a,10);
      a.offs:=fs+1;
      Seek(f,hp);
      BlockWrite(f,a,10);
      Seek(f,ooffs1-1);
      BlockRead(f,buf,a.len);
      Seek(f,fs);
      BlockWrite(f,buf,a.len);
      inc(fs,a.len);
    end;
    WriteMessage(f,nm[m_Out],m,0,fs,No,race);
    CloseData(f);
    DataChg:=Yes;
    Find1stOMsg;
  end;

procedure SaveMessage (n:int; var m:Msg);
  var	buf	: MsgBuf;
	a	: OMsgH;
	l	: int;
	hp	: long;
  begin
    hp:=2+long(n-1)*10;
    Seek(f,hp);
    BlockRead(f,a,10);
    l:=PackMessage(m,buf);
    if (l>a.len) and (l>MsgSpace(a.offs)) then a.offs:=FileSize(f)+1;
    a.len:=l;
    Seek(f,hp);
    BlockWrite(f,a,10);
    Seek(f,a.offs-1);
    BlockWrite(f,buf,a.len);
    if IOResult=0 then ;
    DataChg:=Yes;
  end;

function LoadMessage (var m:Msg; height:byte) : boolean;
  var	s	: str40;
	ls	: byte absolute s;
	g	: file;
	i,x0	: byte;
	k,nk,j	: int;
	fp0	: long;
	buf	: MsgBuf;
	refresh	: boolean;
	ch	: word;
  procedure ReadBlock;
    begin
      BlockRead(g,buf,SizeOf(buf),nk);
      if IOResult=0 then ;
      k:=0;
    end;
  function ReadChar : char;
    begin
      inc(k);
      if k>nk then
	if nk=SizeOf(buf) then
	begin
	  ReadBlock;
	  if nk=0 then begin ReadChar:=#10; Exit end;
	  inc(k);
	end
	else begin dec(k); ReadChar:=#10; Exit end;
      ReadChar:=chr(buf[k]);
    end;
  procedure ReadTextWindow;
    var	i,j	: byte;
    begin
      Seek(g,fp0);
      ReadBlock;
      TextAttr:=cMsg;
      with m do
      for i:=1 to height do
      begin
	text[i,0]:=#0;
	for j:=1 to x0-1 do
	  if ReadChar in [#13,#10] then Break;
	for j:=1 to 40 do
	begin
	  text[i]:=text[i]+ReadChar;
	  if text[i,j] in [#13,#10] then
	    begin dec(text[i,0]); Break end;
	end;
	if text[i,j]<>#10 then while (nk>0) and (ReadChar<>#10) do ;
	RPad(text[i],40);
	WriteLine(4+i,text[i]);
      end;
    end;
  begin
    LoadMessage:=No;
    WriteFName;
    SetColor(cMsg);
    OutTextXY(MsgX*8,KeyY,'Enter file name to load message from:');
    s:=GetStr(MsgX*8,KeyY+8,40);
    if GetStrKey=27 then Exit;
    if (ls=0) and (GetStrKey=13) then s:=msgfn else msgfn:=s;
    Assign(g,msgfn);
    Reset(g,1);
    if IOResult<>0 then
    begin
      WriteFName;
      SetColor(LightRed);
      OutTextXY(MsgX*8,KeyY,'Can''t read file. Press any key...');
      ReadKey;
      Exit;
    end;
    ClearKeyArea;
    SetColor(cMsg);
    OutTextXY(MsgX*8,KeyY,'Use arrow keys to navigate text window,');
    OutTextXY(MsgX*8,KeyY+8,'Enter to finish selection, Esc to cancel');
    SetColor(White);
    OutTextXY(MsgX*8,KeyY,'    arrow keys');
    OutTextXY(MsgX*8,KeyY+8,'Enter                      Esc');
    m.lines:=height;
    fp0:=0; x0:=1;
    refresh:=Yes;
    repeat
      if refresh then begin ReadTextWindow; refresh:=No end;
      ch:=ReadKey;
      with m do
      case ch of
	$4B00	: if x0>1 then begin dec(x0); refresh:=Yes end;
	$4D00	: for i:=1 to height do
		    if RLen(text[i])>1 then
		      begin inc(x0); refresh:=Yes; Break end;
	$4800	: if fp0>0 then
		  begin
		    dec(fp0,SizeOf(buf));
		    j:=SizeOf(buf)-1;
		    if fp0<0 then begin j:=j+fp0; fp0:=0 end;
		    Seek(g,fp0);
		    ReadBlock;
		    k:=j;
		    while (k>0) and (buf[k]<>10) do dec(k);
		    inc(fp0,k);
		    refresh:=Yes;
		  end;
	$5000	: begin
		    Seek(g,fp0);
		    ReadBlock;
		    repeat inc(k) until (k>nk) or (buf[k]=10);
		    if k<=nk then begin inc(fp0,k); refresh:=Yes end;
		  end;
      end;
    until ch in [13,27];
    Close(g);
    LoadMessage:=(ch=13);
  end;

procedure NewMessage (var m:Msg; msgtype:byte);
	{ 1-new, 2-forward, 3-reply, 4-load }
  var	i,j	: int;
	univ	: boolean;
  begin
    if (msgtype in [2,3]) and (msgn[msgt]=0) then Exit;
    FillChar(msgr,SizeOf(MsgRaces),No);
    if msgtype=3 then
    begin
      if (msgt<>m_In) or (m_to=0) then Exit;
      msgr[m_to]:=Yes;
      univ:=No;
    end
    else univ:=ChooseRaces(msgr,CRStr[msgtype]);
    i:=1;
    while (i<=12) and (msgr[i]=No) do inc(i);
    if i>12 then Exit;
    ClearMsgArea;
    WriteOMsgHeader(msgr);
    with m do
    begin
      case msgtype of
	1	: begin
		    for i:=1 to 16 do text[i,0]:=#0;
		    lines:=16;
		  end;
	2	: begin
		    if lines<16 then
		    begin
		      text[lines+1]:='>>>>>>>>>>>>>>>>> END <<<<<<<<<<<<<<<<<';
		      for i:=lines+2 to 16 do text[i,0]:=#0;
		    end;
		    lines:=16;
		    for i:=16 downto 2 do text[i]:=text[i-1];
		    text[1]:='>>>>>>>>>> FORWARDED MESSAGE <<<<<<<<<<';
		  end;
	3	: begin
		    for i:=lines+1 to 20 do text[i,0]:=#0;
		    j:=4;
		    while (j<=20) and (text[j,0]=#0) do inc(j);
		    dec(j);
		    lines:=16;
		    for i:=1 to 16 do
		    begin
		      if i+j>20 then Break;
		      text[i]:=text[i+j];
		      if text[i,0]<>#0 then
		      begin
			if text[i,1]<>'>' then text[i]:=' '+text[i];
			text[i]:='>'+text[i];
		      end;
		    end;
		  end;
	4	: if not LoadMessage(m,16-byte(univ)) then Exit;
      end;
      if univ then
      begin
	for i:=16 downto 2 do text[i]:=text[i-1];
	if msgr[player] then text[1]:='  <<< Universal Message >>>'
			else text[1]:='  <<< Team Message >>>';
	m.lines:=16;	{ specially for LoadMessage }
      end;
    end;
    if EditMessage(m) then
    begin
      msgn[m_Out]:=nm[m_Out]+1;
      msgt:=m_Out;
      CloseData(f);
      OpenMsgFile;
      for i:=1 to 12 do
	if msgr[i] then AddMessage(i,m);
    end;
    if univ then FillChar(msgr,SizeOf(MsgRaces),No);
  end;

procedure DeleteMessage (n:int);
  var	i	: int;
	fp	: long;
	a	: OMsgH;
  begin
    ClearKeyArea;
    SetColor(cMsg);
    OutTextXY(MsgX*8,KeyY,'Delete this message? Y/N');
    SetColor(Yellow);
    OutTextXY((MsgX+21)*8,KeyY,'Y N');
    if AskYN('y','n') then
    begin
      if msgn[m_Out]=nm[m_Out] then dec(msgn[m_Out]);
      dec(nm[m_Out]);
      dec(nm1[m_Out]);
      dec(nmsg[m_Out]);
      if nm1[m_Out]=0 then msgt:=m_In;
      Seek(f,0);
      BlockWrite(f,nm[m_Out],2);
      Seek(f,2+long(n)*10);
      for i:=n to nm[m_Out] do
      begin
	fp:=FilePos(f);
	BlockRead(f,a,SizeOf(OMsgH));
	Seek(f,fp-10);
	BlockWrite(f,a,SizeOf(OMsgH));
	Seek(f,fp+10);
      end;
      if IOResult=0 then ;
    end;
  end;

procedure FileMessage (var m:Msg);
  var	s	: str40;
	ls	: byte absolute s;
	t	: text;
	over	: boolean;
	i	: byte;
  begin
    WriteFName;
    SetColor(cMsg);
    OutTextXY(MsgX*8,KeyY,'Enter file name to save message to:');
    s:=GetStr(MsgX*8,KeyY+8,40);
    if GetStrKey=27 then Exit;
    if (ls=0) and (GetStrKey=13) then s:=msgfn else msgfn:=s;
    if msgfn[0]=#0 then Exit;
    over:=No;
    Assign(t,msgfn);
    Reset(t);
    if IOResult=0 then
    begin
      Close(t);
      WriteFName;
      SetColor(cMsg);
      OutTextXY(MsgX*8,KeyY,'File already exists.Append or Overwrite?');
      SetColor(Yellow);
      OutTextXY((MsgX+20)*8,KeyY,'A         O');
      if AskYN('a','o') then Append(t)
      else begin
	if ynkey=27 then Exit;
	over:=Yes;
      end;
    end
    else over:=Yes;
    if over then
    begin
      Rewrite(t);
      if IOResult<>0 then
      begin
	WriteFName;
	SetColor(LightRed);
	OutTextXY(MsgX*8,KeyY,'Can''t write file. Press any key...');
	ReadKey;
	Exit;
      end;
    end;
    with m do
    for i:=1 to lines do Writeln(t,text[i]);
    Close(t);
    if IOResult=0 then ;
    WriteFName;
    SetColor(cMsg);
    OutTextXY(MsgX*8,KeyY,'Message has been saved. Press any key...');
    ReadKey;
  end;

procedure GetVCR (n:word; var vcr:VCRData);
  var	v	: file;
  begin
    if n>nm[m_VCR] then Exit;
    if DFiles and (turn=today) then
    begin
      OpenRW(v,'VCR'+plstr+'.DAT',Yes);
      Seek(v,long(n-1)*SizeOf(VCRData)+2);
      BlockRead(v,vcr,SizeOf(VCRData));
      CloseData(v);
    end
    else begin
      Seek(f,TTurn^.data^.vpos+2+long(n-1)*SizeOf(VCRData));
      BlockRead(f,vcr,SizeOf(VCRData));
      if IOResult=0 then ;
    end;
  end;

procedure GetVCRMessage (n:word; var m:Msg);
  var	vcr	: VCRData;
	lr	: LRType;
	s	: string[11];
	i	: int;
	oo	: array [1..2] of int;
       {$IFDEF VPACC}
        pres    : PBattleResult;
       {$ENDIF}
  procedure VTLine (i:byte; lr:LRType; s:str20);
    var	ls	: byte absolute s;
    begin
      RPad(s,18); ls:=18;
      if lr=Left then m.text[i]:=s+'    '
		 else m.text[i]:=m.text[i]+s;
    end;
  procedure VTResult (i:byte; lr:LRType; result:int);
    begin
      if result=1 then VTLine(i, lr, '/Captured/') else
      if result=2 then VTLine(i, lr, '/Destroyed/') else
                       VTLine(i, lr, '');
    end;
  begin
    GetVCR(n,vcr);
    with vcr do
    for lr:=Left to Right do
    begin
      VTLine(1,lr,RaceName[dd[lr].race]);
      if (lr=Left) or (planet=0) then s:='ship' else s:='planet';
      VTLine(2,lr,s+' #'+NStr0(dd[lr].id));
      VTLine(3,lr,dd[lr].name);
    end;
    m.text[1,20]:='v';
    m.text[1,21]:='s';
    m.lines:=3;
    if pvcr then
    begin
      m.text[4]:='';
      m.text[5]:='(generated by PHOST)';
      m.lines:=5;
     {$IFDEF VPACC}
      pres := GetBattleResult(vcr);
      if pres<>nil then begin
        VTResult(5, Left, pres^.u.outcome1);
        VTResult(5, Right, pres^.u.outcome2);
      end;
     {$ENDIF}
      if not pvcrexe then
      begin
	m.text[6]:='';
	m.text[7]:='Copy '+PVCR_EXE+' to your PLANETS directory';
	m.text[8]:='to view PHOST-generated battles';
	m.lines:=8;
      end;
    end;
    msgvcr:=n;
    Seek(g,objoffs);
    for i:=1 to nm[m_In] do
    begin
      BlockRead(g,oo,4);
      if oo[2]=n then begin msgobj:=oo[1]; Break end;
    end;
    if msgobj=0 then
    with vcr do
    begin
      if planet<>0 then msgobj:=dd[Right].id or LockP else
      for lr:=Left to Right do
	if TTurn^.data^.ship[dd[lr].id]<>nil then msgobj:=dd[lr].id or LockS;
    end;
    if IOResult=0 then ;
    if pvcr then exit;
    DrawMessage(m);
    for lr:=Left to Right do vcr.dd[lr].race:=Race[vcr.dd[lr].race];
    Combat(vcr,No,9,Off,Yes);
    if not KeyPressed then
    begin
      m.text[4]:='';
      for lr:=Left to Right do
      begin
	s:='';
	i:=vcr.dd[lr].pic;
	if i=ExplPic then s:='/Destroyed/' else
	if i=SurrPic then s:='/Captured/';
	VTLine(5,lr,s);
      end;
      m.lines:=5;
    end;
  end;

procedure GetMessage (n:word; var m:Msg; io:MsgType);
  var	i	: int;
  begin
    if n=0 then Exit;
    if n>nm[msgt] then n:=nm[msgt];
    msgobj:=0;
    msgvcr:=0;
    if io=m_VCR then
    begin
      GetVCRMessage(n,m);
      m_to:=0;
      Exit;
    end;
    m_to:=ReadMessage(f,n,m,offs0,io=m_In);
    if io=m_In then
      if ObjFile then
      begin
	Seek(g,objoffs+(n-1)*4);
	BlockRead(g,msgobj,2);
	BlockRead(g,msgvcr,2);
	if IOResult=0 then ;
      end
      else with TTurn^.data^ do
	for i:=1 to nmark do
	  if (mark^[i].mtype<>mrkNone) and (mark^[i].bind=n) then
	    begin msgobj:=i or LockA; Break end;
  end;

function CheckObj : int;
  var	i	: int;
	n1,n,n2	: int;	{ n1 and n2 are for stack-independent reading }
  begin
    CheckObj:=0;
    ObjFile:=No;
    if DFiles and (turn=today) then
    begin
      if OpenRW(g,'VPAMSG'+plstr+'.DAT',No) then
      begin
	ObjFile:=Yes;
	objoffs:=0;
      end
    end
    else if TTurn^.data^.mopos<>0 then
    begin
      OpenRW(g,dbname,Yes);
      ObjFile:=Yes;
      objoffs:=TTurn^.data^.mopos;
    end;
    if lock=0 then Exit;
    if ObjFile then
    begin
      Seek(g,objoffs);
      for i:=1 to nm[m_In] do
      begin
	BlockRead(g,n,4);
	if IOResult=0 then ;
	if n=lock then begin CheckObj:=i; Exit end;
      end;
      if (ltype=LockA) and DFiles and (turn=today) then
      begin
	i:=TTurn^.data^.mark^[lock and LockLo].bind;
	if i<=0 then Exit;
	Seek(g,nm[m_In]*4+(i-1)*2);
	BlockRead(g,i,2);
	if IOResult=0 then ;
	CheckObj:=i;
	Exit;
      end;
    end;
    if ltype=LockA then
    begin
      i:=TTurn^.data^.mark^[lock and LockLo].bind;
      if i>0 then CheckObj:=i;
    end;
  end;

procedure ViewVCR (n:word);
  var	vcr,vcrp: VCRData;
	v	: file;
	i,ii	: word;
        magic   : word;
	a,b	: int;
	lr	: LRType;
	vs	: string[79];
	errr	: boolean;
  begin
    if n>nm[m_VCR] then Exit;
    GetVCR(n,vcr);
    errr:=No;
    if not pvcr then
    begin
      UnlockReservedMemory(ReservedMemory);
      TCombatInit(Yes);
      for lr:=Left to Right do vcr.dd[lr].race:=Race[vcr.dd[lr].race];
      Combat(vcr,Yes,VCSpeed,VCSet and 8<>0,No);
      TCombatFinish;
      LockReservedMemory;
    end
    else begin
     GetVCR(1, vcrp);
     magic := vcrp.plnpic;
     if pvcrlast then GetVCR(nm[m_VCR],vcrp);
     CloseData(f);	{ must close! it is renamed for PVCR }
     repeat		{ try }
      vs:=addir+'VCR'+plstr+'.';
      Assign(v,vs+'TMP');
      Erase(v); if IOResult=0 then ;
      if DFiles then
      begin
	Assign(v,vs+'DAT');
	Rename(v,vs+'TMP');
	if IOResult<>0 then
	begin
	  TextAttr:=LightRed;
	  WriteXY(PVEX,PVEY,'Can''t rename file '+vs+'DAT to *.TMP');
	  errr:=Yes;
	  Break;
	end;
      end;
     { Construct a temporary VCR file. We must have two copies of the
       battle: according to pvcr.htm, `pvcr -b 1' plays the first battle.
       In 3.3e and before, that option is broken; -b 1 means the second
       one and -b 0 is ignored. This works both for the broken and the
       good PVCR.  --sr }
      Assign(v,vs+'DAT');
      Rewrite(v,1);
      i:=IIF(pvcrlast,3,2);
      BlockWrite(v,i,2);
      vcr.int0:=48879-vcr.K0;
      vcr.plnpic := magic;       { needed by PVCR 4.0+ }
      BlockWrite(v,vcr,SizeOf(VCRData));
      vcr.int0:=0;
      vcr.plnpic := 0;
      BlockWrite(v,vcr,SizeOf(VCRData));
      if pvcrlast then BlockWrite(v,vcrp,SizeOf(VCRData));
      BlockWrite(v,vs[1],10);
      CloseData(v);
      {$IFDEF VPAMM}IF HeapPtr<>NIL THEN{$ENDIF} SwapVectors;
      Exec(PVCR_EXE,'-b 1 -p '+plstr+' -s '+addir);
      a:=DosError;
      b:=DosExitCode;
      {$IFDEF VPAMM}IF HeapPtr<>NIL THEN{$ENDIF} SwapVectors;
      Erase(v); if IOResult<>0 then ;
      if DFiles then
      begin
	Assign(v,vs+'TMP');
	Rename(v,vs+'DAT'); if IOResult<>0 then ;
      end;
      if a<>0 then
      begin
	TextAttr:=LightRed;
	WriteXY(PVEX,PVEY,'Can''t run '+PVCR_EXE+' (DOS Error '+NStr0(a)+')');
	errr:=Yes;
	Break;
      end;
     until True;	{ finally }
     OpenMsgFile;
    end;
    if not errr then
    begin
      if BadVideoOrMouse then RestoreCrtMode;
      if customBGI then SetGraphMode(bgiMode) else
        if not useSVGA then SetGraphMode(VGAHi) else SetGraphMode(gmVesa640x480x256);
      DrawRightScreen;
      DrawMsgScreen;
    end;
  end;

procedure CheckPVCR;
  var	vcr	: VCRData;
	sr	: SearchRec;
	msgt0	: MsgType;
  begin
    pvcr:=No;
    pvcrlast:=No;
    if nm[m_VCR]=0 then Exit;
    msgt0:=msgt;
    msgt:=m_VCR;
    OpenMsgFile;
    GetVCR(1,vcr);
    pvcr:=(word(vcr.K0+vcr.int0)=48879);
    if pvcr then
    begin
      if nm[m_VCR]>1 then begin
        GetVCR(nm[m_VCR],vcr);
        pvcrlast:=(word(vcr.K0+vcr.int0)=48879);
      end else pvcrlast:=false;
      FindFirst(PVCR_EXE,$21,sr);
      pvcrexe:=(DosError=0) and (sr.size>0);
    end;
    CloseData(f);
    msgt:=msgt0;
  end;

procedure ViewMessages;
  var	chh	: word;
	m	: Msg;
	mx,my	: int;
	ii	: MsgType;
	nn	: int;
	mn1	: int;
        killed  : boolean;
  procedure NextMsg(with_killed:boolean);
    var start:int;
    begin
      if nm1[msgt]>0 then begin
        start := msgn[msgt];
        repeat
          if (chh=$4B00) or (chh=$4F00) then msgn[msgt]:=IIF(msgn[msgt]=1,nm[msgt],msgn[msgt]-1)
                                        else msgn[msgt]:=IIF(msgn[msgt]=nm[msgt],1,msgn[msgt]+1);
        until (msgn[msgt]=start) or (with_killed) or not MessageIsKilled(msgt, msgn[msgt]);
      end;
      mn1:=msgn[msgt];
    end;
  begin
    killed := false;
    MouseOff;
    MouseDisabled:=True;
    mx:=MouseX; my:=MouseY;
    if DFiles and (turn=today) then
    begin
      nm[m_In]:=nmsg[m_In];
      nm[m_Out]:=nmsg[m_Out];
      nm[m_VCR]:=nmsg[m_VCR];
    end
    else begin
      nm[m_In]:=TTurn^.data^.inum;
      nm[m_Out]:=TTurn^.data^.onum;
      nm[m_VCR]:=TTurn^.data^.vnum;
    end;
    Move(nm,nm1,SizeOf(nm));
    {if (turn=today) and (PHOSTmn<>0) then dec(nm1[m_Out]);}
    CheckPVCR;
    if pvcrlast then dec(nm1[m_VCR]);
    DrawMsgScreen;
    for ii:=m_In to m_VCR do
      if nm1[ii]=0 then msgn[ii]:=0
      else if (msgn[ii]=0) or (msgn[ii]>nm[ii]) then msgn[ii]:=1;
    if RWMode and (turn=today) then Find1stOMsg else OpenMsgFile;
    GenerateKillfile(-1);
    WriteMsgLine(m_In);
    nn:=CheckObj;
    if nn<>0 then begin msgt:=m_In; msgn[m_In]:=nn end;
    if nm1[msgt]=0 then
      if nm1[m_In]>0 then msgt:=m_In else
	if nm1[m_Out]>0 then msgt:=m_Out else
	  if nm1[m_VCR]>0 then msgt:=m_VCR else msgt:=m_In;
    helpscr:=6;
    ii:=succ(msgt);
    chh:=0;
    repeat
      mn1:=msgn[msgt];
      {if (turn=today) and (msgt=m_Out) and (PHOSTmn<>0) then
      begin
	if msgn[m_Out]=PHOSTmn then NextMsg;
	if mn1>PHOSTmn then dec(mn1);
      end;}
      if (msgt=m_VCR) and pvcrlast and (msgn[m_VCR]=nm[m_VCR]) then NextMsg(true);
      DrawMsgMark(msgt,mn1,White);
      if (ii<>msgt) or (nn<>msgn[msgt]) then
      begin
	if nm1[msgt]>0 then
	begin
	  if ii<>msgt then begin CloseData(f); OpenMsgFile end;
	  GetMessage(msgn[msgt],m,msgt);
	  if not KeyPressed then DrawMessage(m);
	end;
	ii:=msgt; nn:=msgn[msgt];
      end;
      chh:=ReadKey;
      DrawMsgMark(msgt,mn1,0);
      if chh=13 then chh:=ord(CRChar[msgt]);
      if (msgt=m_In) and (m_to<>0) and ((chh=ord('m')) and (msgobj=0)) then chh:=ord('r');
      case chh of
	$4B00	: NextMsg((KbdFlags and KbdShft)<>0);
	$4D00	: NextMsg((KbdFlags and KbdShft)<>0);
	$4800	: if msgt<>m_In then
		  begin
		    repeat msgt:=pred(msgt) until (nm1[msgt]>0) or (msgt=m_In);
		    if nm1[msgt]=0 then msgt:=ii;
		  end;
	$5000	: if msgt<>m_VCR then
		  begin
		    repeat msgt:=succ(msgt) until (nm1[msgt]>0) or (msgt=m_VCR);
		    if nm1[msgt]=0 then msgt:=ii;
		  end;
	$4700	: msgn[msgt]:=1;
	$4F00	: msgn[msgt]:=nm[msgt];
	$5200,ord('f'),ord('r'),ord('l'),
	ord('n'): if RWMode and (turn=today) then
		  begin
		    if chh=$5200 then chh:=ord('n');
		    NewMessage(m,Pos(chr(chh),'nfrl'));
		    WriteMsgLine(m_Out);
		    ii:=succ(msgt);
		  end;
	ord('e'): if RWMode and (turn=today) and (msgt=m_Out) and (msgn[m_Out]>0) then
		  begin
		    ClearKeyArea;
		    if EditMessage(m) then SaveMessage(msgn[m_Out],m);
		    WriteMsgLine(m_Out);
		    ii:=succ(msgt);
		  end;
	$5300,
	ord('d'): if RWMode and (turn=today) and (msgt=m_Out) and (msgn[m_Out]>0) then
		  begin
		    DeleteMessage(msgn[m_Out]);
		    WriteMsgLine(m_Out);
		    ii:=succ(msgt);
		  end;
	ord('s'): if msgn[msgt]>0 then
		  begin
		    FileMessage(m);
		    ii:=succ(msgt);
		  end;
	ord('m'): if (msgn[msgt]>0) and (msgobj<>0) then
		  begin
		    lock:=msgobj;
		    lbase:=nil;
		    chh:=27;
		  end;
	ord('v'): if (msgn[msgt]>0) and (msgvcr<>0) and ((not pvcr) or pvcrexe) then
		  begin
		    ViewVCR(msgvcr);
		    ii:=succ(msgt);
		  end;
        ord('k'): if (msgt=m_In) and (msgn[m_In]>0) then begin
                    if AddKillfile(MessageSubject(m)) then begin
                      killed := true;
                      GenerateKillfile(1);
                      WriteMsgLine(m_In);
                      DrawMessage(m);
                    end;
                  end;
        ord('u'): if (msgt=m_In) and (msgn[m_In]>0) then begin
                    if RemoveKillfile(MessageSubject(m)) then begin
                      killed := true;
                      GenerateKillfile(0);
                      WriteMsgLine(m_In);
                      DrawMessage(m);
                    end;
                  end;
	$3B00	: begin
		    Help;
		    DrawMsgScreen;
		    ii:=succ(msgt);
		  end;
      end;
    until chh=27;
    helpscr:=0;
    CloseData(f);
    if ObjFile then CloseData(g);
    if killed then WriteKillfile;
    MoveMouseTo(mx,my);
    MouseDisabled:=False;
    MouseOn;
    ResetMouse;
    if lock<>0 then begin force:=lock; ForceKey:=13 end;
    ch:=2;		{ redraw map }
  end;

procedure CheckPHOSTMessage;
  var	i	: int;
	m	: Msg;
	s	: str40;
  procedure AddLine (s:str40);
    begin
      inc(m.lines);
      m.text[m.lines]:=s;
    end;
  begin
    msgt:=m_Out;
    Find1stOMsg;
    for i:=1 to nm[m_Out] do
      if (ReadMessage(f,i,m,0,No)=player) and (m.lines>=1) then
      begin
	s:=m.text[1]; Trim(s);
	if Copy(s,1,10)=ClStr then
	begin
	  PHOSTmn:=i;
	  Break;
	end;
      end;
    if RWMode and (PHOSTmn=0) then
    begin
      m.lines:=1;
      m.text[1]:=ClStr;
      if PHOSTget<>0 then
      begin
	if PHOSTget and PGconfig<>0 then AddLine('send config');
	if PHOSTget and PGraces<>0 then AddLine('send racenames');
	AddLine('message '+plstr);
	AddLine('        <<< Message from VPA >>>');
	AddLine('');
	s:='VPA could not find correct ';
	if PHOSTget and PGconfig<>0 then s:=s+'PCONFIG.SRC'
				    else s:=s+'RACE.NM';
	AddLine(s);
	AddLine('file in the directory of this game.');
	AddLine('VPA requested this file to be sent to');
	AddLine('you via UTIL'+plstr+'.DAT. If the request fails');
	AddLine('by some reason, you should obtain this');
	AddLine('file from your game host manually and');
	AddLine('place it into the game directory');
	AddLine('to ensure proper work of VPA.');
	if PHOSTget=PGconfig or PGraces then AddLine('The same goes for RACE.NM');
      end;
      AddMessage(player,m);
      PHOSTmn:=nmsg[m_Out];
    end;
    CloseData(f);
    msgt:=m_In;
  end;

procedure CheckWinPlanMess;
  var	ft1,ft5	: long;
	f1,f5	: file;
	i,n,r,k	: int;
	wph	: WPMsgH;
	oh	: OMsgH;
	buf	: MsgBuf;
	hp,mp	: long;
  begin
    if OpenRW(f5,'MESS35'+plstr+'.DAT',No) then
    begin
      WPMess:=Yes;
      GetFTime(f5,ft5);
      if OpenRW(f1,'MESS'+plstr+'.DAT',No) then
      begin
	GetFTime(f1,ft1);
	CloseData(f1);
      end
      else ft1:=0;
      if ft5>ft1 then
      begin
	Rewrite(f1,1);
	BlockRead(f5,n,2);
	BlockWrite(f1,n,2);
	if n>0 then
	begin
	  k:=0;
	  Seek(f5,$13);
	  for i:=1 to n do
	  begin
	    BlockRead(f5,wph,SizeOf(wph));
	    for r:=1 to 12 do
	      if wph.races[r]='1' then inc(k);
	    Seek(f5,FilePos(f5)+wph.len);
	  end;
	  hp:=2; mp:=Max(k,50)*SizeOf(oh)+2;
	  Seek(f5,$13);
	  for i:=1 to n do
	  begin
	    BlockRead(f5,wph,SizeOf(wph));
	    wph.len:=Min(wph.len,SizeOf(MsgBuf));
	    BlockRead(f5,buf,wph.len);
	    for r:=1 to 12 do
	      if wph.races[r]='1' then
	      begin
		Seek(f1,hp);
		oh.offs:=mp+1;
		oh.len:=wph.len;
		oh.fr_:=player;
		oh.to_:=r;
		BlockWrite(f1,oh,SizeOf(oh));
		inc(hp,SizeOf(oh));
		Seek(f1,mp);
		BlockWrite(f1,buf,wph.len);
		inc(mp,wph.len);
	      end;
	  end;
	  Seek(f1,0);
	  BlockWrite(f1,k,2);
	  Seek(f5,0);
	  BlockWrite(f5,n,2);
	end;
	CloseData(f1);
      end;
      CloseData(f5);
    end;
  end;

procedure StoreWinPlanMess;
  var	ft1,ft5	: long;
	f1,f5	: file;
	i,n,r	: int;
	k,j	: int;
	wph	: WPMsgH;
	oh	: OMsgH;
	buf	: MsgBuf;
	wpbuf	: array [1..601] of byte;
  begin
    if OpenRW(f1,'MESS'+plstr+'.DAT',Yes) then
    begin
      GetFTime(f1,ft1);
      if OpenRW(f5,'MESS35'+plstr+'.DAT',No) then
      begin
	GetFTime(f5,ft5);
	if ft1>ft5 then
	begin
	  CloseData(f5);
	  Writeln('Storing messages for WinPlan...');
	  Rewrite(f5,1);
	  BlockRead(f1,n,2);
	  BlockWrite(f5,n,2);
	  wph.word0:=$3100;
	  Seek(f5,$13);
	  for i:=1 to n do
	  begin
	    Seek(f1,long(i-1)*SizeOf(OMsgH)+2);
	    BlockRead(f1,oh,SizeOf(oh));
	    oh.len:=Min(oh.len,SizeOf(MsgBuf));
	    if (oh.to_<1) or (oh.to_>12) then oh.to_:=12;
	    wph.len:=WPMax;		{ WinPlan sucks! }
	    FillChar(wph.races,12,'0');
	    wph.races[oh.to_]:='1';
	    BlockWrite(f5,wph,SizeOf(wph));
	    Seek(f1,oh.offs-1);
	    BlockRead(f1,buf,oh.len);
	    while (oh.len>0) and (buf[oh.len]=13+13) do dec(oh.len);
	    j:=0;
	    for k:=1 to oh.len do
	    begin
	      inc(j); wpbuf[j]:=buf[k];
	      if (buf[k]=13+13) and (buf[k+1]<>10+13) then
		begin inc(j); wpbuf[j]:=10+13 end;
	      if j>=WPMax then Break;
	    end;
	    while j<WPMax do
	      begin inc(j); wpbuf[j]:=$2D end;
	    BlockWrite(f5,wpbuf,WPMax);	{ WinPlan sucks! }
	  end;
	  Seek(f5,0);
	  BlockWrite(f5,n,2);
	  Seek(f1,0);
	  BlockWrite(f1,n,2);
	end;
	CloseData(f5);
      end;
      CloseData(f1);
    end;
  end;

procedure EncodeObject (var obj; var buf; len:word);
  label	a1;
  var src : array[0..65535] of byte absolute obj;
      dst : array[0..65535] of word absolute buf;
      i   : word;  b : byte;
  begin
    { codifica cada byte en 2 chars: nibble bajo y nibble alto desplazados a 'a'..'p'
      (equivalente al AAM 16 + add 'a' + stosw del asm original) }
    if len<>0 then
      for i := 0 to len-1 do
      begin
        b := src[i];
        dst[i] := word(ord('a') + (b and $0F)) or (word(ord('a') + (b shr 4)) shl 8);
      end;
  end;

procedure TransmitObject;
  var	mx,my	: int;
	m	: Msg;
	i,n	: int;
	o	: ObjType;
	size	: word;
	op	: pointer;
	buf	: array [0..MaxOSize-1] of word;
	a	: MapMark;
	s	: string;
	ls	: byte absolute s;
	dl	: array [1..2] of word;
	ll	: long absolute dl;
  begin
    if (not RWMode) or (lock=0) then Exit;
    o:=Obj1;
    while (o<=Obj2) and (ltype<>ObjLock[o]) do inc(o);
    if o>Obj2 then Exit;
    size:=ObjSize[o];
    n:=lock and LockLo;
    MouseOff;
    MouseDisabled:=True;
    mx:=MouseX; my:=MouseY;
    Clear(0,0,479,479);
    DrawMsgRectangle;
    ChooseRaces(msgr,'transmit');
    i:=1;
    while (i<=11) and (msgr[i]=No) do inc(i);
    while i<=11 do		{ while, not if }
    begin
      {if (o=oPlanet) and (lbase<>nil) then o:=oBase;}
      m.text[1]:='<<< VPA Data Transmission >>>';
      m.text[2]:='';
      m.text[3]:='OBJECT: '+ObjName[o];
      if o<>oMark then m.text[3]:=m.text[3]+' '+NStr0(n);
      with TTurn^.data^ do
      begin
	case o of
	  oPlanet	: op:=planet[n];
	  {oBase		: op:=base[n];
	  oShip		: op:=ship[n];}
	  oMines	: op:=mines[n];
	  oMark		: begin a:=mark^[n]; op:=Addr(a) end;
	end;
	if op<>nil then EncodeObject(op^,buf,size)
	else if (o=oPlanet) and (eplan[n].owner<>0) then FillChar(buf,SizeOf(PRec)*2,'P')
	else Break;
	if o=oPlanet then EncodeObject(eplan[n],buf[SizeOf(PRec)],SizeOf(EPln));
	if o=oMark then
	begin
	  s:=GetMarkText(n);
	  EncodeObject(s,buf[SizeOf(MapMark)],ls+1);
	  inc(size,ls+1);
	end;
      end;
      m.lines:=(size-1) div 20+1+4;
      for i:=1 to m.lines-4 do
      begin
	Move(buf[(i-1)*20],m.text[i+4,1],40);
	m.text[i+4,0]:=#40;
      end;
      m.text[m.lines,0]:=char((size*2-1) mod 40+1);
      dl[1]:=size;
      dl[2]:=0;
      for i:=1 to dl[1] do dl[2]:=(dl[2] shl 1)+buf[i-1];
      m.text[4]:='DATA: '+NStr0(ll);

      n:=turn; turn:=today;
      msgt:=m_Out;
      Find1stOMsg;
      for i:=1 to 11 do
	if msgr[i] then AddMessage(i,m);
      CloseData(f);
      turn:=n;
      Break;
    end;
    MoveMouseTo(mx,my);
    MouseDisabled:=False;
    MouseOn;
    ResetMouse;
    if lock<>0 then begin force:=lock; ForceKey:=13 end;
    ch:=2;		{ redraw map }
  end;

{added this for ExtFeat}
procedure CloseMessageFile;
  begin
    CloseData(f);
  end;

End.