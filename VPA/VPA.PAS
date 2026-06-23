{$I switches.inc}
Program	VPA;		(* VGA Planets Assistant *)
{$V-}
{$A-,B-,D+,E+,F-,G+,I-,L+,N+,O-,P+,Q-,R-,S-,T-,V-,X+}

uses
{$IFDEF UNIX}
	cthreads,	{ Linux: ptcgraph usa hilos para el bucle de eventos X11; cthreads debe ir primero }
	{$IFDEF UNIX}xfocus,{$ENDIF}
{$ENDIF}
	AuxF,Screen,VPA2,VPAInit,VPAExit,Building,Messages,Report,VCS,
{$IFDEF TASKS}
    Tasks,
{$ENDIF}  
  Scores,ScrSaver{,Details};

const	Fault	: boolean = No;

var	ExitPr0	: pointer;

procedure WriteHex(w : word);
  var i : int;
  const hexdig : array[0..15] of char='0123456789ABCDEF';
  begin
    for i := 3 downto 0 do
     Write(hexdig[(w shr (4*i)) and 15]);
  end;

procedure Terminate; far;
  begin
    ExitProc:=ExitPr0;
    CloseGraphics;
    if ExitCode=216 then Writeln(#7'ERROR: General Protection Fault. Please report to author.') else
{    if ExitCode=249 then Writeln(#7'FATAL ERROR! System crash is possible! Please report to author.') else}
    if ExitCode=250 then Writeln(#7'ERROR: NOT ENOUGH MEMORY') else
    if ExitCode=251 then Writeln(#7'ERROR: Internal memory management fault. Please report to author.') else
    if ExitCode=252 then Writeln(#7'ERROR: Error writing VPA database') else
    if ExitCode=253 then Writeln(#7'ERROR: Error reading VPA database') else
    if ExitCode=254 then Writeln(#7'ERROR: VPA database is corrupt') else
    if ExitCode>0 then
      Writeln(#7'Error ',ExitCode,' has occurred. Please report to author.');
    if ErrorAddr<>nil then begin
      Write('Error address is ');
      WriteHex(PtrUInt(ErrorAddr) shr 16);
      Write(':');
      WriteHex(PtrUInt(ErrorAddr) and 65535);
      Writeln('.');
    end;
    if not Fault and not (ExitCode in [249,251..254]) then
    begin
      Fault:=Yes;
      ExitPr0:=ExitProc;
      ExitProc:=@Terminate;
      Writeln;
      SaveAll;
      ExitProc:=ExitPr0;
    end;
    ExitCode:=0;
    ErrorAddr:=nil;
  end;

Begin
  ExitPr0:=ExitProc;
  ExitProc:=@Terminate;
  if StartVPA then
  begin
    InitVCR;
    DrawMap(Yes);    
    repeat
      WriteFreeMem;
      Main;
      {$IFDEF UNIX}xfocus.DbgDispatch(ch);{$ENDIF}
      case ch of
{enter} 13	: ScreenSaver;
{b}	ord('b'),
{c}	ord('c'): BaseBuild;
{f1}	$3B00	: Help;
{_f1	$5400	: DetailedInfo;}
{f2}	$3C00	: SaveChanges;
{f3}    $3D00	: ViewMessages;
{_f3}	$5600	: TransmitObject;
{f4}    $3E00	: WriteReport('','');
{f5}    $3F00	: CombatSimulation;
{$IFDEF TASKS}
{f8}    $4200	: TaskProgramming;
{$ENDIF}
{f10}	$4400	: WriteScores;
{~x}	$2D00	: Break;
{~f4}	$6B00	: Break;
      end;
      if ch=2 then DrawMap(Yes);
    until False;
  end;
  QuitVPA;
  ExitProc:=ExitPr0;
End.
