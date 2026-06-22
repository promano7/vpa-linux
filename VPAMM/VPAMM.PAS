{$IFDEF DPMI}'This module wants to be compiled for real mode'{$ENDIF}
Program	VPAMM;	(* VGA Planets Assistant (Mixed Mode) *)
{$A-,B-,D+,E+,F-,G+,I-,L+,N+,O-,P+,Q-,R-,S-,T-,V-,X+}

uses	Overlay,AuxF,Screen,VPA2,VPA3,VPAInit,VPAExit,Building,Messages,
        Report,VCS,
{$IFDEF TASKS}
        Tasks,
{$ENDIF}  
        Scores,ScrSaver{,Details},DPMI,SysExt;

{ An educated guess based on VPA 3.51's .ovr file :-) }
{$O Building}
{$O VCS}
{$O VPAExit}
{$O VPAInit}
{$O Report}
{$O Scores}
{$O MsgRead}
{$O Config}
{$O Messages}
{$O TCombat}
{$O VPA2}
{$O VPA3}
{$O VPA4}

const	Fault	: boolean = No;

var	ExitPr0	: pointer;

procedure Terminate; far;
  var f:file;
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
    if (ExitCode>=100) and (ExitCode<255) then
      Writeln(#7'Error ',ExitCode,' has occurred. Please report to author.');
    if not Fault and not (ExitCode in [249,251..254]) then
    begin
      Fault:=Yes;
      ExitPr0:=ExitProc;
      ExitProc:=@Terminate;
      Writeln;
      SaveAll;
      ExitProc:=ExitPr0;
      if _DPMI and (ExitCode<>0) then begin
        Assign(f, 'vpacore');
        Rewrite(f, 1);
        if IOResult=0 then begin
          DPMIDumpCoreFile(f);
          Close(f);
          IF IOResult=0 THEN Writeln('A core dump (vpacore) has been written.');
        end;
      end;
    end;
    ExitCode:=0;
    ErrorAddr:=nil;
  end;

TYPE TExtension = STRING[3];

PROCEDURE AppendExt(VAR N:STRING; X:TExtension; Force:BOOLEAN);
VAR i:INTEGER;
BEGIN
  i:=Length(N);
  WHILE (i<>0) AND (Pos(N[i], '.:\/')=0) DO Dec(i);
  IF (N[i]='.') AND Force THEN BEGIN
    N[0]:=CHAR(i);
    N:=N+X;
  END ELSE
  IF (i=0) OR (N[i]<>'.') THEN N:=N+'.'+X;
END;

VAR ovrname : STRING[127];

Begin
  InitDPMI;
  ovrname := ParamStr(0);
  AppendExt(ovrname, 'ovr', TRUE);
  IF _DPMI THEN BEGIN
    Writeln('VPA/MM running in protected mode');
    InitDPMIOverlay(ovrname);
  END ELSE BEGIN
    Writeln('VPA/MM running in real mode');
    OvrInit(ovrname);
    OvrInitEMS;
  END;
  ExitPr0:=ExitProc;
  ExitProc:=@Terminate;
  if StartVPA then
  begin
    InitVCR;
    DrawMap(Yes);
    repeat
      WriteFreeMem;
      Main;
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
{f8    $4200	: TaskProgramming;}
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
