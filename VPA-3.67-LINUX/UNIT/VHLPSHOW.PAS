Program	VHLPShow;	(* VHLP Show Utility *)
{$I-}
{$M 8192,20000,20000}

uses	AuxF,StrF,VHLP,Graph;

procedure EGAVGADriverProc; external;
{$L egavga.obj}


var	f	: file;
	vhd	: array [1..SizeOf(VHLPid)] of char;
	vhver	: byte;
	gd,gm	: int;
	pageid	: int;
procedure GrErr (err:int);
    begin
      if err>=0 then Exit;
      err:=GraphResult;
      if err=grOk then Exit;
      Writeln('Graphics initialization failure'{,GraphErrorMsg(err)});
      Halt;
    end;
Begin
  Writeln(#13#10'-= VHLP Show Utility 1.0  (c) Alex V. Ivlev, 1996 =-');
  if ParamCount=0 then
    begin Writeln('Usage:   VHLPSHOW file.hlp'); Halt end;

  FileMode:=0;
  Assign(f,ParamStr(1));
  Reset(f,1);
  if IOResult<>0 then
    begin Writeln('Can''t read file ',ParamStr(1)); Halt end;
  Writeln('Reading file ',ParamStr(1));
  BlockRead(f,vhd,SizeOf(vhd));
  if vhd<>VHLPid then
    begin Writeln('This is not a VHLP file'); Halt end;
  BlockRead(f,vhver,1);
  if vhver<>VHLPver then
    begin Writeln('Unknown VHLP version'); Halt end;

  BlockRead(f,pageid,2);
  GrErr(RegisterBGIDriver(@EGAVGADriverProc));
  gd:=Detect;
  InitGraph(gd,gm,'');
  gd:=GraphResult;
  if gd<>grOK then
    begin Writeln(GraphErrorMsg(gd)); Halt end;
  ShowHelp(f,pageid);
  Close(f);
  CloseGraph;
End.