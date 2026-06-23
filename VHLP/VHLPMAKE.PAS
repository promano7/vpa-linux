Program	VHLPMake;	(* VHLP Compiler *)
{$V-}
{$I-}
{$M 2048,0,0}

{
	VHLP input file format:
	VHLP
	WIDTH width
	PAGE id
	T	color	x	y	string			//text
	C	color	x	y	radius                  //circle
	L	color	x1	y1	x2	y1		//line
	F	color	x1	y1	x2	y1		//fill
	R	color	x1	y1	x2	y1		//rectangle
	KEY	key	page_id					//hotkey
	...
}

uses	{$IFDEF UNIX}cthreads,{$ENDIF}AuxF,StrF,VHLP;

var	f	: file;
	t	: text;
	s,s1	: string;
	ls	: byte absolute s;
	ls1	: byte absolute s1;
	i	: int;
	l	: long;
	vh	: VHRec;
	vd	: VDRec;
	pages	: int;
	nextdpos: long;
	fp	: long;

const	Width	: int = 480;

procedure GetItem;
  begin
    Parse(s,s1,' ,'#9);
    Upper(s1);
    if ls1=0 then
    begin
      Writeln('ERROR: Missing item in line ',l);
      Close(t);
      Close(f);
      Erase(f);
      Halt;
    end;
  end;

Begin
  Writeln(#13#10'-= VHLP Compiler 1.1  (c) Alex V. Ivlev, 1996 =-');
  if ParamCount=0 then
    begin Writeln('Usage:   VHLPMAKE inputfile'); Halt end;

  s:=ParamStr(1);
  Assign(t,s);
  Reset(t);
  if IOResult<>0 then
    begin Writeln('Can''t read file ',s); Halt end;
  Writeln('Reading file ',s);
  Readln(t,s1);
  if s1<>'VHLP' then
    begin Writeln('This file is not a VHLP input file'); Halt end;

  pages:=0;
  while not Eof(t) do
  begin
    Readln(t,s1);
    Trim(s1); Upper(s1);
    if LeftWord(s1)='PAGE' then inc(pages);
  end;
  if pages=0 then begin Writeln('No pages found in the VHLP file'); Halt end;

  i:=ls;
  while (i>0) and not (s[i] in ['.','\']) do dec(i);
  if (i>0) and (s[i]='.') then ls:=i-1;
  s:=s+'.hlp';
  Assign(f,s);
  Rewrite(f,1);
  if IOResult<>0 then
    begin Writeln('Can''t write file ',s); Halt end;
  Writeln('Writing file ',s);
  BlockWrite(f,VHLPid,SizeOf(VHLPid));
  BlockWrite(f,VHLPver,1);
  nextdpos:=FilePos(f);
  vd.id:=-1;
  for i:=1 to pages do BlockWrite(f,vd,SizeOf(vd));
  BlockWrite(f,vd.id,2);

  Reset(t); Readln(t,s);
  l:=1;
  while not Eof(t) do
  begin
    Readln(t,s); Trim(s);
    inc(l);
    if (ls=0) or (s[1]=';') then Continue;
    GetItem;
    if s1='PAGE' then
    begin
      fp:=FilePos(f);
      if vd.id<>-1 then
      begin
	vd.len:=fp-vd.ofs;
	Seek(f,nextdpos);
	BlockWrite(f,vd,SizeOf(vd));
	nextdpos:=FilePos(f);
	Seek(f,fp);
      end;
      GetItem;
      vd.id:=Value(s1);
      vd.ofs:=fp;
      vh.y:=0;
      Continue;
    end;
    if s1='WIDTH' then
    begin
      GetItem;
      Width:=Value(s1);
      Continue;
    end;
    if vd.id=-1 then
      begin Writeln('ERROR: Page not defined in line ',l); Halt end;
    if s1='KEY' then
    begin
      s1:='$$';
      BlockWrite(f,s1[1],2);
      GetItem; i:=Value(s1); BlockWrite(f,i,2);
      GetItem; i:=Value(s1); BlockWrite(f,i,2);
      Continue;
    end;
    vh.t:=s1[1];
    GetItem; vh.c:=Value(s1);
    GetItem; if s1='*' then vh.x:=-1 else vh.x:=Value(s1);
    GetItem; if s1[1]='+' then begin Delete(s1,1,1); inc(vh.y,Value(s1)) end
			  else vh.y:=Value(s1);
    Trim(s);
    if (vh.x=-1) and (vh.t='T') then vh.x:=(Width-ls*8) div 2;
    BlockWrite(f,vh,SizeOf(vh));
    case vh.t of
      'C'	: begin					{ C }
		    GetItem; i:=Value(s1); BlockWrite(f,i,2);
		  end;
      'L','F','R' : begin				{ L }
		    GetItem; i:=Value(s1); BlockWrite(f,i,2);
		    GetItem; if s1[1]='+' then begin Delete(s1,1,1); i:=vh.y+Value(s1) end
					  else i:=Value(s1);
		    BlockWrite(f,i,2);
		  end;
      else 	  begin					{ T }
		    StrSubst(s,#23,#26);
		    BlockWrite(f,s,ls+1);
		  end;
    end;
  end;
  Close(t);
  vd.len:=FilePos(f)-vd.ofs;
  Seek(f,nextdpos);
  BlockWrite(f,vd,SizeOf(vd));
  Close(f);
End.