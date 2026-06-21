{$I switches.inc}
Unit	Tasks;		(* VPA Task Processor *)
{$I-}

Interface

uses	AuxF;

const	TaskChg	: boolean = No;

	tfDeac	= 1;	{ task is deactivated }

type	taskptr		= ^TaskRec;
	TaskRec		= record
			    prev,next	: taskptr;
			    id		: int;
			    size	: int;
			    flag	: byte;
			    code	: pointer;
			  end;

procedure TaskInit;
procedure TaskFree;
procedure SaveTasks;
function  FindTask (id:int) : taskptr;
procedure TaskProgramming;

Implementation

uses	StrF,Mouse,Keyboard,Screen,Graph,VPAData,VPA2,VPA3,VPA4;

{
	Task file structure:
	task block
	task block
	...

	Task block:
	int	- object ID
	int	- size of task code (not including the header)
	byte	- flags
	[size]b	- task code

	Task code:
	byte	- opcode
	[varies]- parameters
	...

	Planet task:	list of operations

	Ship task:      (Current action:)
			  go to waypoint N	- must be the 1st op in task
			At waypoint 1:
			  list of operations
			  go to waypoint N
			...

}

const	TaskRoot	: taskptr = nil;

const	opFCode	= 0;	{ "abc", #$FF#$FF#$FF = random }
	opNTax	= 1;	{ nn }
	opCTax	= 2;	{ nn }
	opMin	= 3;	{ nn }
	opFac	= 4;	{ nn }
	opDef	= 5;	{ nn }
	opSSup	= 6;	{ llll }

	opMisn	= 7;	{ mm ii tt }
	opEnemy	= 8;	{ nn }
	opUnload= 9;	{ nn ty, ty - n,t,d,m,c,s,$ as 1..7, nn - amount }
	opLoad	= 10;	{ nn ty }
	opWarp	= 11;	{ nn }

	opWayPt	= 12;	{ id xx yy, if xx=-1 then yy=planetN }
	opRandWP= 13;	{ nn xx yy, nn - radius }
	opWaitPl= 14;
	opCurWP	= 15;	{ id }
	opDelWP	= 16;

	opNone	= 17;
	opBad	= 18;
	opEnd	= 19;

	opBlank	= $FF;

	OpSize	: array [opFCode..opDelWP] of byte =
		( 4,3,3,3,3,3,5, 7,3,5,5,3, 7,7,1,3,1 );

	OpNames	: array [1..7,1..60] of char =
		( 'Set_f.code`_to~ Set_native_tax_level`_to~ Set_colonist_tax_l',
		  'evel`_to~ Build_mines`_up_to~ Build_factories`_up_to~ Build_',
		  'defenses`_up_to~ Sell~_supply_units Set_mission`_to~ Set~_pr',
		  'imary_enemy Unload~ Load~ Set_warp_factor~ Waypoint~_ Random',
		  'ize_waypoint Wait_for_planet`_to_execute_its_program Current',
		  'ly_going_to_waypoint~ Delete_this_waypoint`_after_reaching_i',
		  't (no_command) <program_is_corrupt!> <end>                  ' );
	MaxOpLen= 22;	{ max len of op menu item }

	AllPlOps: set of byte = [opFCode..opSSup];
	AllShOps: set of byte = [opFCode,opMisn..opDelWP];
	OpMenus	= 3;
	OpMenuN	: array [1..OpMenus] of int = (7,8,6);
	MaxOpMN	= 8;
	OpMenu	: array [1..OpMenus,1..MaxOpMN] of byte =
		( { planet op menu }
		  ( opFCode,opNTax,opCTax,opMin,opFac,opDef,opSSup,0 ),
		  { op menu for waypoint at planet }
		  ( opFCode,opMisn,opEnemy,opUnload,opLoad,opWarp,opWaitPl,opDelWP ),
		  { op menu for waypoint in space }
		  ( opFCode,opMisn,opEnemy,opWarp,opRandWP,opDelWP,0,0 )	);

type	optr		= ^operation;
	operation	= record
			    prev,next	: optr;
			    opcode	: byte;
			    case byte of
			      0 : ( fc	: array [1..3] of char );
			      1 : ( n,ty: int );
			      2 : ( l	: long );
			      3 : ( mis,intr,tow: int );
			      4 : ( id,xx,yy	: int )
			  end;

procedure TaskInit;
  var	f	: file;
	th	: record
		    id	: int;
		    size: int;
		    flag: byte;
		  end;
	t,t0	: taskptr;
  begin
    if not OpenRW(f,'VPATSK'+plstr+'.DAT',No) then Exit;
    t0:=nil;
    while not Eof(f) do
    begin
      BlockRead(f,th,SizeOf(th));
      if (IOResult<>0) or (th.id<=0) or (th.size<=0) then Break;
      CheckMem(th.size+SizeOf(TaskRec));
      New(t);
      with t^ do
      begin
	id:=th.id;
	size:=th.size;
	flag:=th.flag;
	GetMem(code,size);
	BlockRead(f,code^,size);
	prev:=t0; next:=nil;
      end;
      if t0=nil then TaskRoot:=t else t0^.next:=t;
      t0:=t;
    end;
    CloseData(f);
  end;

procedure SaveTasks;
  var	f	: file;
	t	: taskptr;
  begin
    if not TaskChg then Exit;
    OpenW(f,'VPATSK'+plstr+'.DAT',Yes);
    t:=TaskRoot;
    while t<>nil do
    begin
      BlockWrite(f,t^.id,SizeOf(int)*2+SizeOf(byte));
      BlockWrite(f,t^.code^,t^.size);
      t:=t^.next;
    end;
    CloseData(f);
  end;

procedure TaskFree;
  var	t	: taskptr;
  begin
    t:=TaskRoot;
    while t<>nil do
    begin
      FreeMem(t^.code,t^.size);
      TaskRoot:=t;
      t:=t^.next;
      Dispose(TaskRoot);
    end;
    TaskRoot:=nil;
  end;

function FindTask (id:int) : taskptr;
  var	t	: taskptr;
  begin
    t:=TaskRoot;
    while (t<>nil) and (t^.id<>id) do t:=t^.next;
    FindTask:=t;
  end;

const 	ProgramStatus	: array [-1..1] of string[10] = ('NOT ACTIVE','NO PROGRAM','ACTIVE');
	CargoType	: array [1..7] of string[10] =
	('Neutronium','Tritanium','Duranium','Molybdenum','Colonists','Supplies','Money');

PROCEDURE TaskProgramming;
  var	mx,my	: int;
	chh	: word;
(*	ltp	: int; *)
	number	: int;
(*	l	: long;
	l0	: ^long; *)
	status	: int;	{ 0 - no program, 1 - active, -1 - not active }
	editing	: boolean;
(*	IsShip	: boolean; *)
	menu	: array [1..OpMenus] of pointer;
	t	: taskptr;
	task	: optr;
	tlines	: int;

  const	MaxTaskLines	= 500;
	TaskX0	= 10;
	TaskY0	= 100;
	TaskW	= 50;
	TaskH	= 25;
	HeadY	= 0;
	Head1Y	= 10;
	StatusY	= 24;
	Prompt1Y= 40;
	Prompt2Y= 50;

  procedure FreeTask;
    var	op	: optr;
    begin
      while task<>nil do
      begin
	op:=task^.next;
	Dispose(task);
	task:=op;
      end;
    end;

  procedure GetTask;
    var	i,k	: int;
	op,op0	: optr;
	opcode	: byte;
	bpp	: ^ByteArr;
	ship	: boolean;
    begin
      ship:=( t^.id and LockHi=LockS );
      task:=nil;
      tlines:=0;
      op0:=nil;
      bpp:=t^.code;
      i:=1;
      while i<=t^.size do
      begin
	CheckMem(SizeOf(operation));
	New(op);
	inc(tlines);
	op^.prev:=op0;
	op^.next:=nil;
	if op0<>nil then op0^.next:=op;
	if task=nil then task:=op;
	op0:=op;
	opcode:=bpp^[i]; inc(i);
	if opcode<>opBlank then
	  if ship then begin if not (opcode in AllShOps) then opcode:=opBad end
		  else begin if not (opcode in AllPlOps) then opcode:=opBad end;
	op^.opcode:=opcode;
	if opcode=opBad then Exit;
	k:=IIF(opcode=opBlank,1,OpSize[opcode]);
	if k>1 then begin Move(bpp^[i],op^.l,k-1); inc(i,k-1) end;
      end;
    end;

  procedure PutTask;
    var	i,k	: int;
	op	: optr;
	bpp	: ^ByteArr;
    begin
      if (t<>nil) and (t^.code<>nil) then FreeMem(t^.code,t^.size);
      if task=nil then	{ delete task }
      begin
	if t<>nil then
	begin
	  if t^.prev<>nil then t^.prev^.next:=t^.next;
	  if t^.next<>nil then t^.next^.prev:=t^.prev;
	  if TaskRoot=t then TaskRoot:=t^.next;
	  Dispose(t); t:=nil;
	end;
      end
      else begin
	if t=nil then   { create task }
	begin
	  CheckMem(SizeOf(TaskRec));
	  New(t);
	  with t^ do
	  begin
	    id:=lock;
	    flag:=0;
	    code:=nil;
	    next:=nil;
	    prev:=TaskRoot;
	  end;
	  if TaskRoot=nil then TaskRoot:=t
	  else begin
	    while t^.prev^.next<>nil do t^.prev:=t^.prev^.next;
	    t^.prev^.next:=t;
	  end;
	end;
	t^.size:=0;
	op:=task;
	while op<>nil do
	begin
	  inc(t^.size,IIF(op^.opcode=opBlank,1,OpSize[op^.opcode]));
	  op:=op^.next;
	end;
	CheckMem(t^.size);
	GetMem(t^.code,t^.size);
	bpp:=t^.code;
	i:=1;
	op:=task;
	while op<>nil do
	begin
	  k:=IIF(op^.opcode=opBlank,1,OpSize[op^.opcode]);
	  Move(op^.opcode,bpp^[i],k); inc(i,k);
	  op:=op^.next;
	end;
      end;
      TaskChg:=Yes;
    end;

  procedure TaskFrame;
    begin
      SetColor(LightGray);
      SetLineStyle(SolidLn,0,NormWidth);
      Rectangle(TaskX0-10,TaskY0-10,TaskX0+TaskW*8+10-1,TaskY0+TaskH*10+10-1);
    end;

  function DisplayLine (op:optr; y:int; c:byte) : int;
    var	s	: string[TaskW];
	ls	: byte absolute s;
	s1	: str20;
	opcode,i: byte;
	mp	: MITptr;
    begin
      if op=nil then Exit;
      opcode:=op^.opcode;
      if opcode=opBlank then
      begin
	s:='-';
	if c<>Yellow then c:=Black;
	SetColor(c);
	OutTextXY(TaskX0,y,s);
	DisplayLine:=TaskX0+ls*8;
	Exit;
      end;
      ItemStr(OpNames,opcode,s);
      i:=Pos('`',s);
      if i<>0 then Delete(s,i,1);
      StrSubst(s,'_',' ');
      s1[0]:=#0;
      case opcode of
	opFCode		: begin
			    s1:=op^.fc;
			    if s1=#$FF#$FF#$FF then s1:='random' else s1:='"'+s1+'"';
			  end;
	opNTax,opCTax	: if op^.n<0 then s1:='keep '+NStr(-op^.n)+'% happiness ' else s1:=NStr0(op^.n)+'%';
	opMin..opDef	: if op^.n=0 then s1:='the maximum' else s1:=NStr(op^.n);
	opSSup		: if op^.l=0 then s1:='all' else
			  if op^.l<0 then s1:='all but '+NStr(-op^.l)
				     else s1:=NStr0(op^.l);
	opMisn		: if (op^.mis>=0) and (op^.mis<=15) then
			  begin
			    if op^.mis<>9 then s1:=Missions[op^.mis]
					  else s1:=SpecMisn[Race[RealShipOwner(number)]];
                            Trim(s1);
			    if op^.mis in [7,8] then
			    begin
			      s:=s+' ship ';
			      if op^.mis=7 then s:=s+NStr0(op^.tow)
					   else s:=s+NStr0(op^.intr);
			    end;
			  end
			  else begin
			    mp:=MIT;
			    while (mp<>nil) and (mp^.mission<>op^.mis) do mp:=mp^.next;
			    if mp<>nil then s:=s+mp^.name
				       else s:=s+'Mission '+NStr0(op^.mis);
			    if (mp=nil) or (mp^.param and (MIT_I+MIT_T)<>0) then
			    begin
			      s:=s+' (';
			      if (mp=nil) or (mp^.param and MIT_I<>0) then s:=s+'I='+NStr0(op^.intr)+', ';
			      if (mp=nil) or (mp^.param and MIT_T<>0) then s:=s+'T='+NStr0(op^.tow);
			      if s[ls]=' ' then dec(ls,2);
			      s:=s+')';
			    end;
			  end;
	opEnemy		: if op^.n<>0 then
			  begin
			    s1:=RaceName[op^.n];
			    Trim(s1);
			    s1:=s1+' as';
			  end
			  else s1:='no';
	opUnload,opLoad	: begin
			    if op^.n=0 then s1:='all' else
			    if op^.n<0 then s1:='all but '+NStr(-op^.n)
				       else s1:=NStr0(op^.n);
			    s:=s+' ';
			    case op^.ty of
			      1..4	: begin
					    if op^.n<>0 then s:=s+'kt of ';
					    s:=s+CargoType[op^.ty];
					  end;
			      5		: s:=s+'clans';
			      6		: s:=s+'suppy units';
			      7		: if op^.n=0 then s:=s+'money'
						     else s:=s+'mc';
			    end;
			  end;
	opWarp		: s1:=NStr0(op^.n);
	opWayPt		: begin
			    s1:=NStr0(op^.id);
			    s:=s+' (';
			    if op^.xx=-1 then s:=s+PlName(op^.yy,Yes)
					 else s:=s+NStr0(op^.xx)+','+NStr0(op^.yy);
			    s:=s+') :';
			  end;
	opRandWP	: s:=s+' to somewhere near '+NStr0(op^.xx)+','+NStr0(op^.yy);
	opCurWP		: s1:=NStr(op^.id);
      end;
      StrSubst(s,'~',' '+s1);
      if (ltype=LockS) and not (opcode in [opWayPt,opCurWP,opEnd]) then s:='  '+s;
      SetColor(c);
      OutTextXY(TaskX0,y,s);
      DisplayLine:=TaskX0+ls*8;
    end;

  procedure DisplayPage (op:optr);
    var	y	: int;
    begin
      Clear(TaskX0-9,TaskY0-9,TaskX0+TaskW*8-1+9,TaskY0+TaskH*10+9-2);
      y:=TaskY0;
      while op<>nil do
      begin
	DisplayLine(op,y,LightGray);
	op:=op^.next;
	inc(y,10);
	if y>=TaskY0+TaskH*10 then Exit;
      end;
    end;

  procedure DrawPrompt;
    begin
      if editing then
      begin
	Clear(0,Prompt1Y,479,Prompt2Y+7);
	SetColor(LightGray);
	OutTextXY(0,Prompt1Y,'Press Ins to insert command, Del to delete command');
	OutTextXY(0,Prompt2Y,'Press Enter to edit command, Esc to finish');
	SetColor(White);
	OutTextXY(0,Prompt1Y,'      Ins                    Del');
	OutTextXY(0,Prompt2Y,'      Enter                  Esc');
      end
      else
	if status<>0 then
	begin
	  SetColor(White);
	  OutTextXY(IIF(status=1,8*8,12*8),StatusY,'A');
	  SetColor(LightGray);
	  OutTextXY(0,Prompt1Y,'Press Enter to edit program, Esc to exit');
	  if status<0 then OutTextXY(0,Prompt2Y,'Press A to activate program')
		      else OutTextXY(0,Prompt2Y,'Press A to deactivate program');
	  SetColor(White);
	  OutTextXY(0,Prompt1Y,'      Enter                  Esc');
	  OutTextXY(0,Prompt2Y,'      A');
	end
	else begin
	  OutTextXY(0,Prompt1Y,'Press Enter to create program, Esc to exit');
	  SetColor(White);
	  OutTextXY(0,Prompt1Y,'      Enter                    Esc');
	end;
    end;

  procedure DrawTaskScreen;
    begin
      Clear(0,HeadY,479,Prompt2Y+8-1);
      SetColor(White);
      if ltype=LockS then OutTextXY(0,HeadY,'PROGRAM FOR SHIP '+NStr(number)+' - '+lship^.name)
		     else OutTextXY(0,HeadY,'PROGRAM FOR PLANET '+NStr(number)+' - '+PlanName[number]);
      SetColor(LightGray);
      OutTextXY(0,StatusY,'STATUS: '+ProgramStatus[status]);
      DrawPrompt;
      if task<>nil then
      begin
	TaskFrame;
	DisplayPage(task);
      end;
    end;

  procedure InsertCommand (var op:optr);
    var	op1	: optr;
    begin
      CheckMem(SizeOf(operation));
      New(op1);
      op1^.opcode:=opNone;
      if op<>nil then
      begin
	op1^.prev:=op^.prev;
	op^.prev:=op1;
      end
      else op1^.prev:=nil;
      op1^.next:=op;
      if op1^.prev<>nil then op1^.prev^.next:=op1
			else task:=op1;
      op:=op1;
    end;

  procedure DeleteCommand (op:optr);
    begin
      if op^.prev<>nil then op^.prev^.next:=op^.next;
      if op^.next<>nil then op^.next^.prev:=op^.prev;
      if op=task then task:=op^.next;
      Dispose(op);
      dec(tlines);
    end;

  function FindWayPoint (op:optr) : optr;
    begin
      FindWayPoint:=nil;
      while op<>nil do
      begin
	if op^.opcode=opWayPt then begin FindWayPoint:=op; Exit end;
	op:=op^.prev;
      end;
    end;

  procedure InsertWayPoint (var op:optr);
    var	op1	: optr;
	new_id	: int;
    begin
      op1:=FindWayPoint(op^.prev);
      if op1=nil then new_id:=1
		 else new_id:=op1^.id+1;
      op1:=task;
      while op1<>nil do
      begin
	if ((op1^.opcode=opCurWP) or (op1^.opcode=opWayPt)) and (op1^.id>=new_id) then inc(op1^.id);
	op1:=op1^.next;
      end;
      InsertCommand(op);
      op^.opcode:=opNone;
      InsertCommand(op);
      op^.opcode:=opWayPt;
      op^.id:=new_id;
      op^.xx:=lship^.x;
      op^.yy:=lship^.y;
      Location(op^.xx,op^.yy);
      if LocationPlanet<>0 then begin op^.xx:=-1; op^.yy:=LocationPlanet end;
      op1:=op;
      InsertCommand(op1);
      op1^.opcode:=opBlank;
    end;

  procedure DeleteWayPoint (op:optr); { deletes all but opWayPt }
    var	op1	: optr;
    begin
      if op^.opcode<>opWayPt then Exit;
      op1:=task;
      while op1<>nil do
      begin
	if ((op1^.opcode=opCurWP) or (op1^.opcode=opWayPt)) and (op1^.id>op^.id) then dec(op1^.id);
	op1:=op1^.next;
      end;
      if (op^.prev<>nil) and (op^.prev^.opcode=opBlank) then DeleteCommand(op^.prev);
      while (op^.next<>nil) and not (op^.next^.opcode in [opWayPt,opEnd,opBlank]) do DeleteCommand(op^.next);
      if (op^.next^.opcode=opEnd) and (task^.opcode=opCurWP) and (task^.id=op^.id) then task^.id:=1;
    end;

  procedure EditWayPoint (op:optr);
    begin
      MoveMouseTo(mx,my);
      MouseDisabled:=False;
      MouseOn;
      DrawMap(Yes);
      Clear(MX0,ListY,639,479);
      SetColor(White);
      OutTextXY(MX0,ListY,   'Move cursor to the');
      OutTextXY(MX0,ListY+8, 'new location of the');
      OutTextXY(MX0,ListY+16,'waypoint and use');
      OutTextXY(MX0,ListY+24,'Ctrl-click or');
      OutTextXY(MX0,ListY+32,'Ctrl-Enter');
      if MouseGetTarget(0,0,Yes) then
      begin
	op^.xx:=mmx; op^.yy:=mmy;
	Location(op^.xx,op^.yy);
	if LocationPlanet<>0 then begin op^.xx:=-1; op^.yy:=LocationPlanet end;
      end;
      Clear(MX0,ListY,639,479);
      MouseOff;
      MouseDisabled:=True;
      Clear(0,0,479,479);
      DrawTaskScreen;
    end;

  procedure EditOp (op:optr; y:int);
    var	opcode	: byte;
	x,n,i	: int;
	s	: str20;
	ls	: byte absolute s;
	op1	: optr;
	md1,md2	: boolean;
	is	: word;
	p	: pointer;
	o	: operation;
    procedure ClearLine;
      begin
	Clear(TaskX0,y,TaskX0+TaskW*8+7,y+7);
      end;
    begin
      o:=op^;
      if o.opcode=opWayPt then begin EditWayPoint(op); Exit end;
      if o.opcode=opCurWP then opcode:=opCurWP
      else begin
	if ltype<>LockS then n:=1
	else begin
	  op1:=FindWayPoint(op);
	  if op1^.xx=-1 then n:=2 else n:=3;
	end;
	RestoreMenu(menu[n]);
	i:=OpMenuN[n];
	while (i>1) and (o.opcode<>OpMenu[n,i]) do dec(i);
	x:=TaskX0+IIF(ltype=LockS,2*8,0);
	ClearLine;
	SetColor(Yellow);
	OutTextXY(x,y,'Choose command:');
	{if y+i*8>480-8 then dec(y,y+i*8-480-8);}
	ChooseMenu(x+16*8,y,x+16*8,x+16*8+MaxOpLen*8-1,OpMenuN[n],LightGray,Yellow,i,No,Yes,-1);
	ClearLine;
	if MenuKey=27 then Exit;
	opcode:=OpMenu[n,MenuValue];
	SetColor(Yellow);
	OutTextXY(x,y,MenuString);
	inc(x,(byte(MenuString[0])+1)*8);
      end;
      RestoreMenu(nil);	{ to keep menu[n] from being destroyed }
      SetColor(LightGray);
      case opcode of
	opFCode		: begin
			    OutTextXY(x,y,'(empty code = random):');
			    s:=GetStr(x+23*8,y,3);
			    if GetStrKey=13 then
			    begin
			      if ls=0 then s:=#$FF#$FF#$FF else RPad(s,3);
			      Move(s[1],o.fc,3);
			    end
			    else opcode:=opNone;
			  end;
	opNTax,opCTax	: begin
			    OutTextXY(x,y,'(0-100, -N = N% happy):');
			    s:=GetStr(x+24*8,y,4);
			    if GetStrKey=13 then o.n:=Min(Max(Value(s),-100),100)
					    else opcode:=opNone;
			  end;
	opMin..opDef	: begin
			    OutTextXY(x,y,'up to how many (0 = maximum):');
			    s:=GetStr(x+30*8,y,3);
			    if GetStrKey=13 then o.n:=Max(Value(s),0)
					    else opcode:=opNone;
			  end;
	opSSup		: begin
			    OutTextXY(x,y,'(0 = all, -N = all but N):');
			    s:=GetStr(x+27*8,y,5);
			    if GetStrKey=13 then o.l:=Value(s)
					    else opcode:=opNone;
			  end;
	opMisn		: begin
			    if o.opcode<>opMisn then
			      begin o.mis:=0; o.intr:=0; o.tow:=0 end;
			    inc(x,8);
			    is:=ImageSize(x-8,y-8,x+18*8-1,y+16*8+7);
			    p:=nil;
			    if MaxAvail>=is then
			    begin
			      GetMem(p,is);
			      GetImage(x-8,y-8,x+18*8-1,y+16*8+7,p^);
			    end;
			    if not ChooseMission(o.mis,md1,md2,lship,Race[player],
						 No,(n=3),x,y,x,lship^.tow_ship,lship^.intr_ship) then opcode:=opNone;
			    if p<>nil then
			    begin
			      PutImage(x-8,y-8,p^,NormalPut);
			      FreeMem(p,is);
			    end;
			    if opcode<>opNone then
			      if o.mis in [7,8] then
			      begin
				o.intr:=0; o.tow:=0;
				ClearLine;
				x:=DisplayLine(Addr(o),y,Yellow);
				s:=GetStr(x,y,3);
				if GetStrKey<>13 then opcode:=opNone
				else begin
				  i:=Value(s);
				  if (i<1) or (i>500) then opcode:=opNone
				  else if o.mis=7 then o.tow:=i
						  else o.intr:=i;
				end
			      end else
			      if o.mis>15 then
			      begin
				if md1 then o.intr:=MenuData;
				if md2 then o.tow:=MenuData2;
			      end;
			  end;
	opEnemy		: begin
			    if o.opcode<>opEnemy then o.n:=0;
			    if not ChooseEnemy(o.n,x+8,y,x+8) then opcode:=opNone;
			  end;
	opUnload,opLoad	: begin
			    inc(x,8);
			    NewMenu;
			    for i:=1 to 7 do AddMenuItem(CargoType[i],cSInfo,No);
			    ChooseMenu(x,y,x,x+12*8-1,7,cSInfo,Yellow,o.ty,No,Yes,-1);
			    NewMenu;
			    if MenuKey=27 then opcode:=opNone
			    else begin
			      o.ty:=MenuValue;
			      SetColor(Yellow);
			      OutTextXY(x-8,y,CargoType[o.ty]);
			      inc(x,Min(Length(CargoType[o.ty]),9)*8);
			      SetColor(LightGray);
			      OutTextXY(x,y,'(0 = all, -N = all but N):');
			      s:=GetStr(x+27*8,y,5);
			      if GetStrKey=13 then o.n:=Value(s)
					      else opcode:=opNone;
			    end;
			  end;
	opWarp		: begin
			    OutTextXY(x,y,'(0..9):');
			    s:=GetStr(x+8*8,y,1);
			    o.n:=Value(s);
			    if o.n>9 then opcode:=opNone;
			  end;
	opCurWP		: begin
			    o.id:=0;
			    ClearLine;
			    x:=DisplayLine(Addr(o),y,Yellow);
			    i:=0;
			    op1:=task;
			    while op1<>nil do
			    begin
			      if op1^.opcode=opWayPt then i:=op1^.id;
			      op1:=op1^.next;
			    end;
			    if i=0 then opcode:=opNone
			    else begin
			      s:='(1..'+NStr(i)+') : ';
			      OutTextXY(x,y,s);
			      s:=GetStr(x+ls*8,y,3);
			      if GetStrKey<>13 then opcode:=opNone
			      else begin
				o.id:=Value(s);
				if (o.id<1) or (o.id>i) then opcode:=opNone;
			      end;
			    end;
			  end;
      end;
      if opcode<>opNone then begin o.opcode:=opcode; op^:=o end;
      ClearLine;
    end;

  procedure InsertBlanks (add_nones:boolean);
    var	op	: optr;
    begin
      op:=task;
      while op<>nil do
      begin
	if op^.opcode=opWayPt then
	begin
	  if (op^.prev=nil) or (op^.prev^.opcode<>opBlank) then
	  begin
	    InsertCommand(op);
	    op^.opcode:=opBlank;
	    op:=op^.next;
	  end;
	  if add_nones and (op^.next<>nil) and (op^.next^.opcode=opBlank) then
	  begin
	    op:=op^.next;
	    InsertCommand(op);
	    op^.opcode:=opNone;
	  end;
	end;
	op:=op^.next;
      end;
    end;

  function EditTask : boolean;
    var	ch	: word;
	op,op0	: optr;
	i,j,n,y	: int;
	s	: str40;
	ls	: byte absolute s;
    begin
      EditTask:=No;
      editing:=Yes;
      DrawPrompt;
      TaskFrame;

      op:=task;		{ add <end> at the end }
      op0:=nil;
      while op<>nil do begin op0:=op; op:=op^.next end;
      if (op0=nil) or (op0^.opcode<>opEnd) then
      begin
	CheckMem(SizeOf(operation));
	New(op);
	op^.opcode:=opEnd;
	op^.prev:=op0;
	op^.next:=nil;
	if op0<>nil then op0^.next:=op
		    else task:=op;
	inc(tlines);
	op0:=op;
	if (op0^.prev=nil) or (op0^.prev^.opcode<>opBlank) then
	begin
	  InsertCommand(op0);
	  op0^.opcode:=opBlank;
	end;
      end;
      if ltype=LockS then
      begin
	op:=FindWayPoint(op0);
	if op=nil then InsertWayPoint(op0);	{ add 1st waypoint }
	op:=task;
	if op^.opcode<>opCurWP then	{ insert opCurWP }
	begin
	  InsertCommand(op);
	  op^.opcode:=opCurWP;
	  op^.id:=1;
	end;
	InsertBlanks(Yes);
      end;

      NewMenu;
      CheckMem(MenuSize(8,8,8+MaxOpLen*8-1,MaxOpMN,Yes));
      for n:=1 to OpMenus do
      begin
	for j:=1 to OpMenuN[n] do
	begin
	  ItemStr(OpNames,OpMenu[n,j],s);
	  i:=Pos('`',s);
	  if i<>0 then ls:=i-1;
	  StrSubst(s,'~','');
	  StrSubst(s,'_',' ');
	  AddMenuItem(s,LightGray,No);
	end;
	SaveMenu(menu[n]);
      end;

      op0:=task;
      op:=task;
      y:=TaskY0;
      DisplayPage(op0);
      repeat
	DisplayLine(op,y,Yellow);
	ch:=ReadKey;
	DisplayLine(op,y,LightGray);
	case ch of
{up} 	  $4800	: if op^.prev<>nil then
		  begin
		    if y>TaskY0 then dec(y,10)
		    else begin
		      op0:=op0^.prev;
		      DisplayPage(op0);
		    end;
		    op:=op^.prev;
		  end;
{dn} 	  $5000	: if op^.next<>nil then
		  begin
		    if y<TaskY0+(TaskH-1)*10 then inc(y,10)
		    else begin
		      op0:=op0^.next;
		      DisplayPage(op0);
		    end;
		    op:=op^.next;
		  end;
{ins}	  $5200	: if (tlines<MaxTaskLines) and (op^.opcode<>opCurWP) then
		  begin
		    if (op^.opcode=opEnd) and (op^.prev<>nil) and
		       (op^.prev^.opcode=opBlank) then
		      begin op:=op^.prev; dec(y,10) end;
		    if (ltype=LockS) and (op^.opcode in [opWayPt,opBlank]) then
		    begin
		      InsertWayPoint(op);
		      if y<TaskY0+(TaskH-1)*10 then inc(y,10)
					       else op0:=op0^.next;
		    end
		    else InsertCommand(op);
		    if y=TaskY0 then op0:=op;
		    DisplayPage(op0);
		    EditTask:=Yes;
		  end;
{del}	  $5300 : if not (op^.opcode in [opCurWP,opEnd,opBlank]) then
		  begin
		    if op^.opcode=opWayPt then
		    begin
		      DeleteWayPoint(op);
		      if y>TaskY0 then dec(y,10)
				  else op0:=op0^.prev;
		    end;
		    if op0=op then op0:=op^.next;
		    op:=op^.next;
		    DeleteCommand(op^.prev);
		    DisplayPage(op0);
		    EditTask:=Yes;
		  end;
	  13	: if not (op^.opcode in [opEnd,opBlank]) then
		  begin
		    EditOp(op,y);
		    EditTask:=Yes;
		  end;
	end;
      until ch=27;

      op:=task;		{ remove empty commands and <end> }
      while op<>nil do
      begin
	op0:=op;
	op:=op^.next;
	if op0^.opcode in [opNone,opEnd,opBad,opBlank] then DeleteCommand(op0);
      end;
      if (ltype=LockS) and (task^.next=nil) then DeleteCommand(task); { opCurWP and nothing more }
      if ltype=LockS then InsertBlanks(No);
      if task=nil then Clear(TaskX0-10,TaskY0-10,TaskX0+TaskW*8+10-1,TaskY0+TaskH*10+10-1);
      for n:=1 to OpMenus do
      begin
	RestoreMenu(menu[n]);
	NewMenu;
      end;
      editing:=No;
    end;

  BEGIN
    if (not DFiles) or (not RWMode) or (turn<>today) or (lock=0) or
       ( (ltype=LockP) and ( (lplan=nil) or (lplan^.when<>today) or (lplan^.owner<>player) ) ) or
       ( (ltype=LockS) and ( (lship=nil) or (lship^.when<>today) or (lship^.owner<>player) ) )
      then Exit;
    MouseOff;
    MouseDisabled:=True;
    mx:=MouseX; my:=MouseY;
    {helpscr:=6;}
    Clear(0,0,479,479);
    UnLockReservedMemory(ReservedMemory);
(*    ltp:=ltype; *)
    number:=lock and LockLo;
    editing:=No;

    repeat
      t:=FindTask(lock);
      task:=nil;
      tlines:=0;
      if t=nil then status:=0
      else begin
	status:=IIF(t^.flag and tfDeac=0,1,-1);
	GetTask;
      end;
      DrawTaskScreen;
      repeat chh:=ReadKey until (chh=13) or (chh=27) or (chh=ord('a'));
      if (chh=ord('a')) and (t<>nil) then
      begin
	status:=-status;
	t^.flag:=t^.flag xor tfDeac;
	TaskChg:=Yes;
      end else
      if chh=13 then
	if EditTask then PutTask;
      FreeTask;
      if chh=27 then Break;
    until No;

    LockReservedMemory;
    helpscr:=0;
    MoveMouseTo(mx,my);
    MouseDisabled:=False;
    MouseOn;
    if lock<>0 then begin force:=lock; ForceKey:=13 end;
    ch:=2;		{ redraw map }
  END;

End.
