{---------------------------------------------------------------------------}
{                                                                           }
{               P l a n e t s   C o m m a n d   C e n t e r                 }
{                                                                           }
{                            1999-2003 by Streu                             }
{                                                                           }
{---------------------------------------------------------------------------}
{                                                                           }
{                      PHost Support - Command Processor                    }
{                         (and some stuff for THost)                        }
{                                                                           }
{---------------------------------------------------------------------------}
{$I switches.inc}
{$IFNDEF VPA}
UNIT PHost;
{$V-}

INTERFACE

USES UtilFmt, Objects;
{$ELSE}
UNIT PHostM;

INTERFACE

USES VPACC, UtilFmt;
{$ENDIF}

                                { ID           Arg }
CONST phc_Language      = 0;    { -            Code }
      phc_SendConfig    = 1;    { -            - }
      phc_SendRacenames = 2;    { -            - }
      phc_SetRaceName   = 3;    { 1..3         Name }
         phcrn_Long     = 1;
         phcrn_Short    = 2;
         phcrn_Adj      = 3;
      phc_Filter        = 4;    { -            Yes/No }
      phc_ConfigAlly    = 5;    { Rasse        Codes }
      phc_AddDropAlly   = 6;    { Rasse        Add/Drop}
      phc_GiveShip      = 7;    { SID          Race }
      phc_GivePlanet    = 8;    { PID          Race }
      phc_RemoteControl = 9;    { SID          Control/Drop/Forbid/Allow }
      phc_RemoteDefault = 10;   { -            Forbid/Allow }
      phc_Beamup        = 11;   { SID          Codes }

      phc_TAlliance     = 12;   { -            Sequence of fcodes }

      phc_SendFcodes    = 13;   { -            - }
      phc_SendFile      = 14;
      phc_Enemies       = 15;
      phc_Other         = 16;   { must be last }
      nPHostCommands    = 16;

      phc_IgnoreTag     = $8000;

CONST nSidCommands = 3;
      SidCommands:ARRAY[1..nSidCommands] OF BYTE=(
          phc_GiveShip,
          phc_RemoteControl,
          phc_Beamup);

      nPidCommands = 1;
      PidCommands:ARRAY[1..nPidCommands] OF BYTE=(
          phc_GivePlanet);

CONST BeamUpMultiple_Tags:STRING[8] = 'TDMS C$N';
{ Order must equal -> Transfer::el_XXXX }

TYPE PPHostAllianceRecord = ^TPHostAllianceRecord;
     TPHostAllianceRecord = RECORD
          OfferedTo       : ARRAY[1..11] OF BYTE;
          OfferedFrom     : ARRAY[1..11] OF BYTE;
          ConditionalTo   : ARRAY[1..11] OF BYTE;
          ConditionalFrom : ARRAY[1..11] OF BYTE;
     END;

     PHStr63 = STRING[63];
     PHStr15 = STRING[15];

{... Alliance Levels ...}
{ Originally the same as in utilx.dat, now remapped so that bits 0..6 are
  alliance levels and bit 7 is valid bit }
CONST pha_Ship     = 1;
      pha_Planet   = 2;
      pha_Mines    = 4;
      pha_Combat   = 8;
      pha_Vision   = 16;
      pha_Enemy    = 32;
      pha_XXValid  = 32;        { pha_Valid in utilx.dat }
      pha_Valid    = 128;       { only in OfferedTo/From }

      phat_Vision  = 1;         { THost "Vision Level" }

      pha_String : STRING[5] = 'spmcv';

      {         offer conditional
         nothing  0     ?
         cond.    1     1
         uncond.  1     0         }

TYPE TRemoteControlSetting = (
      rc_Forbidden,                   { own ship, RC disallowed }
      rc_Normal,                      { own ship, normal }
      rc_RemoteControlled,            { enemy ship, we control it }
      rc_Applying,                    { enemy ship, control requested }
      rc_Dropping,                    { enemy ship, control being given back }
      rc_Other,                       { enemy ship, normal (we don't control) }
      rc_OtherForbidden,              { enemy ship, RC disallowed }
      rc_OurRemoteControlled);        { own ship under foreign control }

{ Colors corresponding to states, see UI.PAS -> cf_XXX }
CONST rc_Colors:ARRAY[TRemoteControlSetting] OF BYTE=(2, 0, 1, 1, 3, 0, 2, 0);

TYPE Str43 = STRING[43];

TYPE PPHostCommand = ^TPHostCommand;
     TPHostCommand = RECORD
          Next     : PPHostCommand;
          Cmd, Id  : WORD;
          Arg      : STRING;
     END;

CONST phostcommand_Fixed1 = 9;   { Next + Cmd + Id + Arg[0] }

CONST phc:PPHostCommand = NIL;

FUNCTION GetPHostCmd(cmd, id:INTEGER):PPHostCommand;
FUNCTION SetPHostCmd(cmd, id:INTEGER; CONST Arg:STRING):PPHostCommand;
FUNCTION RemovePHostCmd(cmd, id:INTEGER):BOOLEAN;

FUNCTION PHostCommandString(p : PPHostCommand):STRING;

FUNCTION LoadPHostCommands : BOOLEAN;
PROCEDURE FreePHostCommands(Save:BOOLEAN);
PROCEDURE SavePHostCommands;

FUNCTION GetNewRCFlag(SID:INTEGER):TRemoteControlSetting;

PROCEDURE NRemoteControl(bid, sid:INTEGER);
FUNCTION BringShipIntoRCState(sid, target:INTEGER) : BOOLEAN;
PROCEDURE NGive(bid,sid,cmd:INTEGER; owner:INTEGER);
{$IFNDEF VPA}
PROCEDURE RenameMyRace;
PROCEDURE EditAlliances;
PROCEDURE ReadAllianceCommands(VAR a:TPHostALlianceRecord);
PROCEDURE ReadTAllianceCommands(VAR n:TPHostAllianceRecord);
{$ENDIF}

FUNCTION ReverseEngineerPHostCommand(S : PHStr63; fromfile:BOOLEAN) : PPHostCommand;
FUNCTION IsPHostMessageIntroducer(S : PHStr63) : BOOLEAN;
FUNCTION FindWord(CONST s:PHStr63; i:INTEGER):PHStr63;
FUNCTION PMatch(CONST cmd, usr: PHStr15):BOOLEAN;

{$IFNDEF VPA}
PROCEDURE MaybeRequestPConfig;
{$ENDIF}

TYPE PBattleResult = ^TBattleResult;
     TBattleResult = RECORD
           Next  : PBattleResult;
           Size  : WORD;
           u     : Util7Battle;
     END;

PROCEDURE AddBattleResult(VAR data; size:WORD);
PROCEDURE FreeBattleResults;
FUNCTION  GetBattleResult(VAR vcr):POINTER;

PROCEDURE AddBuildQueueEntry(VAR data : Util39QueueEntry);
FUNCTION  GetQueueEntry(base:INTEGER):PUtil39QueueEntry;
PROCEDURE FreeQueueEntries;

TYPE TUnitScoreEntry = RECORD id, value, turn:INTEGER; END;
     TUnitScoreArray = ARRAY[1..1000] OF TUnitScoreEntry;
     PUnitScoreArray = ^TUnitScoreArray;

     PUnitScore = ^TUnitScore;
     TUnitScore = RECORD
           next   : PUnitScore;
           count  : INTEGER;
           alloc  : INTEGER;
           header : Util49ShipScore;
           data   : PUnitScoreArray;
     END;
     TUnitScoreHandle = PUnitScore;
     PInteger = ^INTEGER;

     TSaveUnitScoreCallback = PROCEDURE (ship    : BOOLEAN;
                                         VAR header:Util49ShipScore;
                                         count    : INTEGER;
                                         VAR data : TUnitScoreArray;
                                         arg      : POINTER);

FUNCTION  AddUnitScore(ship:BOOLEAN; head:Util49ShipScore; count:INTEGER) : TUnitScoreHandle;
PROCEDURE AddUnitScoreEntry(score:TUnitScoreHandle; id, value, turn:INTEGER);
PROCEDURE FreeScores;
FUNCTION  GetUnitScore(ship:BOOLEAN; score_id:INTEGER):TUnitScoreHandle;
FUNCTION  GetUnitScoreEntry(e:TUnitScoreHandle; id:INTEGER; ageptr:PInteger):INTEGER;
FUNCTION  GetExperienceLevel(ship:BOOLEAN; id:INTEGER):INTEGER;
PROCEDURE SaveUnitScores(cb:TSaveUnitScoreCallback; arg:POINTER);
PROCEDURE ClearUnitScores(ship:BOOLEAN; id:INTEGER; before_turn:INTEGER);

VAR PAlliance:TPHostAllianceRecord;

{***************************************************************************}

IMPLEMENTATION

{$IFNDEF VPA}
USES Drivers, Global, MsgWin, Lowlevel, Config, PConfig,
     AAFont, Keyboard, ccHelp, Bits, ccFileUtil, Team, UI, Listbox, Swapper,
     User, MsgH;
{$ELSE}
USES MsgWin, VPAData, ccFileUtil, Screen;
{$ENDIF}

FUNCTION ParseCmdFileLine(S:STRING) : BOOLEAN; FORWARD;

{
  Free a PHost command
}
PROCEDURE FreePHostCommand(p:PPHostCommand);
BEGIN
  FreeMem(p, phostcommand_Fixed1 + Length(p^.Arg));
END;

FUNCTION IsUniqId(cmd:INTEGER):BOOLEAN;
BEGIN
  IsUniqId := (cmd <> phc_Other) AND (cmd <> phc_SendFile);
END;

{
  Return pointer to PHost command CMD/ID, or NIL if no such thing.
}
FUNCTION GetPHostCmd(cmd, id:INTEGER):PPHostCommand;
VAR p:PPHostCommand;
BEGIN
  IF NOT IsUniqId(cmd) THEN GetPHostCmd := NIL ELSE BEGIN
    p:=phc;
    WHILE (p<>NIL) AND ((p^.id<>id) OR (p^.cmd<>cmd)) DO p:=p^.Next;
    GetPHostCmd := p;
  END;
END;

{
  Create a PHost command with CMD/ID and ARG; returns command or NIL
  if out of memory.

  Not the most efficient way (runs through list twice); that should be
  improved someday.
}
FUNCTION SetPHostCmd(cmd, id:INTEGER; CONST Arg:STRING):PPHostCommand;
VAR p, q:PPHostCommand;
CONST phost_Order : ARRAY[0..nPHostCommands] OF BYTE=(0,1,2,0,0,1,0,0,0,0,0,0,0,1,0,0,0);
BEGIN
  IF IsUniqId(cmd) THEN RemovePHostCmd(cmd, id);
  p := Malloc(phostcommand_Fixed1 + Length(arg));
  IF p <> NIL THEN BEGIN
    p^.Cmd := cmd;
    p^.Id := id;
    p^.arg := arg;
    IF (phc=NIL) OR (phost_Order[cmd] < phost_Order[phc^.cmd]) THEN BEGIN
      p^.Next := phc;
      phc     := p;
    END ELSE BEGIN
      q := phc;
      WHILE (q^.Next<>NIL) AND (phost_Order[cmd] >= phost_Order[q^.Next^.Cmd])
      DO q := q^.Next;
      p^.Next := q^.Next;
      q^.Next := p;
    END;
  END;
  SetPHostCmd := p;
END;

{
  Load CMDx.TXT from the game directory
  Returns true when there were errors
}
FUNCTION LoadPHostCommands : BOOLEAN;
VAR td:TDosStream;
    p:PPHostCommand;
    buf:TBuf;
    s:STRING;
LABEL Break;
BEGIN
  LoadPHostCommands:=FALSE;
  phc := NIL;

  td.Init(GameDir + 'cmd' + PlayerStr + '.txt', stOpenRead);
  IF td.Status<>0 THEN Exit;
  InitBuf(@td, buf);

  WHILE FileError=0 DO BEGIN
    ReadStr(@td, s, buf);
    IF NOT ParseCmdFileLine(s) THEN GOTO Break;
  END;
 Break:
  td.Done;
END;

{
  Return string corresponding to PHost command p
}
FUNCTION PHostCommandString(p : PPHostCommand):STRING;
VAR S7 : STRING[7];
CONST rnId:ARRAY[1..3] OF STRING[6]=('long ', 'short ', 'adj ');

  FUNCTION MakeCommand(cmd:Str15; CONST app:STRING):STRING;
  BEGIN
    WHILE (Length(cmd) > 2) AND (Length(cmd)+Length(app) >= 40) DO Dec(cmd[0]);
    MakeCommand := cmd + ' ' + app;
  END;

BEGIN
  Str(p^.Id, S7);
  CASE p^.Cmd OF
    phc_Other:         PHostCommandString := p^.arg;
    phc_Language:      PHostCommandString := 'language ' + p^.arg;
    phc_SendConfig:    PHostCommandString := 'send config';
    phc_SendRacenames: PHostCommandString := 'send racenames';
    phc_SendFcodes:    PHostCommandString := 'send fcodes';
    phc_SetRaceName:   PHostCommandString := MakeCommand('race', rnId[p^.Id] + p^.arg);
    phc_Filter:        PHostCommandString := 'filter ' + p^.arg;
    phc_ConfigAlly:    PHostCommandString := 'allies config ' + S7 + ' ' + p^.arg;
    phc_AddDropAlly:   PHostCommandString := 'allies ' + p^.arg + ' ' + S7;
    phc_RemoteControl: PHostCommandString := 'remote ' + p^.arg + ' ' + S7;
    phc_RemoteDefault: PHostCommandString := 'remote ' + p^.arg + ' default';
    phc_Beamup:        PHostCommandString := MakeCommand('beamup', S7 + ' ' + p^.arg);
    phc_GiveShip:      PHostCommandString := 'give ship ' + S7 + ' to ' + p^.arg;
    phc_GivePlanet:    PHostCommandString := 'give planet ' + S7 + ' to ' + p^.arg;
    phc_TAlliance:     PHostCommandString := '$thost-allies ' + p^.arg;
    phc_SendFile:      PHostCommandString := '$send-file ' + p^.arg;
    phc_Enemies:       PHostCommandString := 'enemies ' + p^.arg + ' ' + S7;
  ELSE PHostCommandString := '';
  END;
END;

{
  Mail all PHost commands (=send them in outbox). Marks all sent commands
  with phc_IgnoreTag.
}
PROCEDURE MailPHostCommands;
VAR p        : PPHostCommand;
    S        : STRING[63];
    tc       : TChar;
BEGIN
{$IFNDEF vpa}
  p := phc;
  tc.Len := 0;
  WHILE p<>NIL DO BEGIN
    S := PHostCommandString(p);
    IF (S<>'') AND (S[1]<>'$') THEN BEGIN
      AddStr(@tc, S + #13);
      p^.Cmd := p^.Cmd OR phc_IgnoreTag;
    END;
    p:=p^.Next;
    IF (tc.Len<>0) AND ((p=NIL) OR (tc.Len > 500)) THEN BEGIN
      IF NOT __SendBuf(1 SHL Pred(PlayerId), tc.Text, tc.Len, NIL) THEN BEGIN
        Warning('Error saving PHost commands');
        Exit;
      END;
      tc.Len := 0;
    END;
  END;
{$ELSE}
  { FIXME FIXME }
{$ENDIF}
END;

{
  Save PHost commands pointed to by phc into game directory
}
PROCEDURE SavePHostCommandsI(phc:PPHostCommand);
VAR p:PPHostCommand;
    td:TDosStream;
    count:INTEGER;
    S:STRING;
CONST crlf : WORD = $0A0D;
BEGIN
  Count := 0;
  p := phc;
  WHILE p<>NIL DO BEGIN
    IF p^.Cmd AND phc_IgnoreTag=0 THEN Inc(Count);
    p := p^.Next;
  END;
  S := GameDir + 'cmd' + PlayerStr + '.txt';
  IF Count = 0 THEN BEGIN
   {--- Erase file if it would be empty ---}
    EraseFile(S);
  END ELSE BEGIN
   {--- Make file ---}
    td.Init(S, stCreate);
   { Synch this with ccUnp::SaveTHostAlliance }
    S := '# Additional Commands'#13#10'$time ' + {$IFDEF VPA}Stamp{$ELSE}Gen.Timestamp{$ENDIF} + #13#10;
    td.Write(S[1], Length(S));
    p := phc;
    WHILE p<>NIL DO BEGIN
      IF p^.Cmd AND phc_IgnoreTag=0 THEN BEGIN
        S := PHostCommandString(p);
        td.Write(S[1], Length(S));
        td.Write(crlf, 2);
      END;
      p := p^.Next;
    END;
    td.Done;
    IF td.Status<>0 THEN Warning('Can''t save PHost commands.');
  END;
END;

PROCEDURE SavePHostCommands;
BEGIN
  SavePHostCommandsI(phc);
END;

{
  Free PHost commands. Optionally save them before.
}
PROCEDURE FreePHostCommands(Save:BOOLEAN);
VAR p:PPHostCommand;
BEGIN
  IF Save THEN BEGIN
{$IFNDEF VPA}
    IF MainOptions AND mo_NoCommandMsg=0 THEN MailPHostCommands;
{$ENDIF}
    SavePHostCommandsI(phc);
  END;
 {--- free them ---}
  WHILE phc<>NIL DO BEGIN
    p := phc;
    phc := phc^.Next;
    FreePHostCommand(p);
  END;
END;

{---------------------------------------------------------------------------}

{
  Get remote control status for ship /sid/ (value at beginning of turn)
}
FUNCTION GetRCFlag(SID:INTEGER):TRemoteControlSetting;
VAR i:INTEGER;
    o:INTEGER;
BEGIN
{$IFNDEF VPA}
  i := Ships^[SID].RCFlag;
  o := Ships^[SID].Owner;
{$ELSE}
  i := rcflags[sid];
  IF TTurn^.data^.ship[sid]<>NIL THEN o := TTurn^.data^.ship[sid]^.owner ELSE o := 0;
  IF i=0 THEN i:=o;
{$ENDIF}
  IF (i=255) THEN BEGIN
    IF o=PlayerID THEN
         GetRCFlag := rc_Forbidden
    ELSE
         GetRCFlag := rc_OtherForbidden;
  END ELSE IF (i=PlayerID) THEN BEGIN
    IF o=PlayerID THEN
         GetRCFlag := rc_Normal
    ELSE
         GetRCFlag := rc_OurRemoteControlled;
  END ELSE IF (o=PlayerID) THEN
         GetRCFlag := rc_RemoteControlled
    ELSE
         GetRCFlag := rc_Other
END;

{
  Get remote control status for ship /sid/ (current value, after command
  processing)
}
FUNCTION GetNewRCFlag(SID:INTEGER):TRemoteControlSetting;
VAR phc:PPHostCommand;
    i:INTEGER;
BEGIN
  phc := GetPHostCmd(phc_RemoteControl, SID);
  IF phc=NIL THEN BEGIN
    GetNewRCFlag := GetRCFlag(SID);
  END ELSE
   CASE Chr(Ord(phc^.Arg[1]) OR $20) OF
     'c': GetNewRCFlag := rc_Applying;
     'a': GetNewRCFlag := rc_Normal;
     'd': GetNewRCFlag := rc_Dropping;
   ELSE   GetNewRCFlag := rc_Forbidden;
   END;
END;

{
  Remove PHost command with CMD/ID, if any.
}
FUNCTION RemovePHostCmd(cmd, id:INTEGER):BOOLEAN;
VAR p,q:PPHostCommand;
BEGIN
  p := phc;
  q := NIL;
  WHILE (p<>NIL) AND ((p^.Cmd <> cmd) OR (p^.Id <> id)) DO BEGIN
    q := p;
    p := p^.Next;
  END;
  IF p<>NIL THEN BEGIN
    IF q=NIL THEN phc := p^.Next ELSE q^.Next := p^.Next;
    FreePHostCommand(p);
    RemovePHostCmd := TRUE;
  END ELSE RemovePHostCmd := FALSE;
END;

{
  rcNames:        command words
  rc2State[X]:    returns the command word which with we can *leave* state X
                  (i.e. the command word we can switch to)
  rc2newState[X]: returns the command word we're currently in
  i.e., rc_Forbidden: rc2State[x] yields 1 -> allow, rc2newState[x] yields
                  forbid, i.e., by toggling we get to allow.
  Don't ask why the names are this.
}
CONST rcNames:ARRAY[1..4] OF STRING[7] = ('allow', 'forbid', 'drop', 'control');
      rc2State   :ARRAY[TRemoteControlSetting] OF BYTE=(1,2,3,3,4,4,4,2);
      rc2newState:ARRAY[TRemoteControlSetting] OF BYTE=(2,1,4,4,3,3,3,1);

{
  Bring ship SID into RC status TARGET.
  TARGET = index into rcNames
  returns TRUE when there was something changed, FALSE if not, possibly
  calls NMemError.
}
FUNCTION BringShipIntoRCState(sid, target:INTEGER) : BOOLEAN;
VAR i, j : TRemoteControlSetting;
BEGIN
  BringShipIntoRCState := FALSE;

  i := GetRCFlag(sid);
  j := GetNewRCFlag(sid);

  { I am already in correct state }
  IF rc2newState[j]=target THEN Exit;

  { At the beginning of the turn, I was in the correct state }
  IF rc2newState[i]=target THEN BEGIN
    BringShipIntoRCState := RemovePHostCmd(phc_RemoteControl, sid);
    Exit;
  END;

  { I can reach the state by issuing a command }
  IF rc2State[j]=target THEN BEGIN
    IF SetPHostCmd(phc_RemoteControl, sid, rcNames[target])=NIL THEN BEGIN
      IF NOT Error THEN NMemError;
      Exit;
    END;
    BringShipIntoRCState := TRUE;
    Exit;
  END;

  { here: state can't be reached (shouldn't happen) }
END;

{
  User interface for remote control on ship SID
  BID = invoking button Id
}
PROCEDURE NRemoteControl(bid,sid:INTEGER);
VAR rc:TRemoteControlSetting;
    i,j,cur:INTEGER;
    o:BOOLEAN;
    S:STRING[23];
BEGIN
{$IFNDEF VPA}
  IF bid > 0 THEN current_window^.PushButton(bid, NIL);
{$ENDIF}

  rc := GetNewRCFlag(sid);
  CASE rc OF
    rc_Forbidden:                 S := 'Allow';
    rc_Normal:                    S := 'Forbid';
    rc_RemoteControlled:          S := 'Drop';
    rc_Applying:                  S := 'Cancel request for';
    rc_Dropping:                  S := 'Cancel dropping';
    rc_Other, rc_OtherForbidden:  S := 'Request';
    rc_OurRemoteControlled:       S := 'Forbid';
  END;
  i   := rc2State[rc];
  cur := rc2newState[GetRCFlag(SID)];

  o := NYesNo(S + ' remote control of this ship?', 'Remote Control');
{$IFNDEF VPA}
  IF bid > 0 THEN current_window^.ReleaseButton(bid);
{$ENDIF}

  IF o THEN BEGIN
    IF cur=i THEN BEGIN
      RemovePHostCmd(phc_RemoteControl, sid);
    END ELSE
    IF (SetPHostCmd(phc_RemoteControl, sid, rcNames[i])=NIL) THEN NMemError;
  END;
END;

PROCEDURE NGive(bid,sid,cmd:INTEGER; owner:INTEGER);
VAR p     : PPHostCommand;
    gg, i : INTEGER;
BEGIN
  p := GetPHostCmd(cmd, sid);
  i := 1;
  IF p<>NIL THEN Val(p^.arg, gg, i);
  IF i<>0 THEN gg:=owner;

 {$IFNDEF VPA}
  IF bid>0 THEN current_window^.PushButton(bid, NIL);
  FOR i:=1 TO 11 DO
   IF i=owner THEN AddListItem(i, Elf[i] + SpacerStr + '(don''t give it away)')
              ELSE AddListItem(i, Elf[i] + SpacerStr + RaceNames[i].Short);
  i := NDoListbox('Give to...', 260, -1, hcGive, gg);
  IF bid>0 THEN current_window^.ReleaseButton(bid);
 {$ELSE}
  FOR i:=1 TO 11 DO
   IF i=owner THEN AddMenuItem(Elf[i] + SpacerStr + '(don''t give it away)', 7, FALSE)
              ELSE AddMenuItem(Elf[i] + SpacerStr + RaceName[i], 7, FALSE);
  i := SimpleListbox('Give to...', 200, 11, gg);
 {$ENDIF}
  IF (i > 0) AND (i <> gg) THEN BEGIN
    IF i=owner THEN RemovePHostCmd(cmd, sid)
               ELSE IF SetPHostCmd(cmd, sid, itoa(i))=NIL THEN NMemError;
  END;
END;

{---------------------------------------------------------------------------}
{ Race name input window }
{$IFNDEF VPA}
TYPE PRenameRaceWindow = ^CRenameRaceWindow;
     CRenameRaceWindow = OBJECT(CUIWindow)
           PROCEDURE DrawInterior; VIRTUAL;
     END;

PROCEDURE CRenameRaceWindow.DrawInterior;
BEGIN
  Color:=0;
  JustX := 0; JustY := 0;
  AAColor:=Dark;
  OutTextXY(110, 165, 'Full name:');
  OutTextXY(110, 200, 'Short name:');
  OutTextXY(110, 235, 'Adjective:');
  OutTextXY(110, 270, 'Changes will get effective next turn.');
END;

PROCEDURE RenameMyRace;
VAR il  : ARRAY[1..3] OF PInputLine;
    pw  : PWindow;
    E   : CEvent;
    phc : PPhostCommand;
    i   : INTEGER;
BEGIN
  il[1] := New(PInputLine, Init(225, 165, 225+300, 30, 0, ilf_Framed, 1));
  il[1]^.SetText(Racenames[PlayerID].Full);
  il[2] := New(PInputLine, Init(225, 200, 225+200, 20, 0, ilf_Framed, 2));
  il[2]^.SetText(Racenames[PlayerID].Short);
  il[3] := New(PInputLine, Init(225, 235, 225+120, 12, 0, ilf_Framed, 3));
  il[3]^.SetText(Racenames[PlayerID].Adj);

  pw := New(PRenameRaceWindow, Init(95, 130, 545, 350, 'Rename Empire', wfc_BlueWindow, Gray));
  FOR i:=1 TO 3 DO BEGIN
    phc := GetPHostCmd(phc_SetRaceName, i);
    IF phc<>NIL THEN il[i]^.SetText(phc^.Arg);
    pw^.Add(il[i]);
  END;
  pw^.SetFocus(il[1]);
  pw^.Add(New(PButton, InitR(cm_Enter,   110, 310,  40, 25, OKtext,     0, 13))^.SetHelp(OKhelp));
  pw^.Add(New(PButton, InitR(cm_Escape,  160, 310,  70, 25, Canceltext, 0, 27))^.SetHelp(ESChelp));
  pw^.Add(New(PButton, InitR(cm_Help,    400, 310, 130, 25, 'Alt-H - Help', bf_Help, 0)));
  pw^.Add(New(PFocusIterator, Init(1, 3, fi_Vert + fi_Tab)));

  OpenWindow(pw, TRUE);
  REPEAT
    WinLoop(0, E);
    CASE E.Cmd OF
      cm_Enter:BEGIN
        IF NOT ((SetPHostCmd(phc_SetRaceName, phcrn_Long, il[1]^.Text)<>NIL)
            AND (SetPHostCmd(phc_SetRaceName, phcrn_Short, il[2]^.Text)<>NIL)
            AND (SetPHostCmd(phc_SetRaceName, phcrn_Adj, il[3]^.Text)<>NIL))
        THEN NMemError;
        E.Cmd := cm_Escape;
      END;
      cm_Help:NHelp(hcRenameRace);
    END;
  UNTIL E.Cmd = cm_Escape;
  CloseWindow(TRUE);
END;

{---------------------------------------------------------------------------}
{ Alliance data }

CONST MAX_ALLIANCE_LEVELS = 7;      { 7 bits + pha_Valid }

      ai_ShipNeeded       = 1;
      ai_Conditional      = 2;
      ai_OfferNeeded      = 4;
      ai_Enemy            = 8;

VAR alliance_levels : ARRAY[0..MAX_ALLIANCE_LEVELS-1] OF STRING[31];
    num_alliance_levels : INTEGER;
    alliance_info   : ARRAY[0..MAX_ALLIANCE_LEVELS-1] OF RECORD
          flags : BYTE;
          code  : CHAR;
    END;

{---------------------------------------------------------------------------}
{ Alliances: panel (race list) }
TYPE PAlliancePanel = ^CAlliancePanel;
     CAlliancePanel = OBJECT(CListbox)
             race : INTEGER;
             ally : PPHostAllianceRecord;
             mb   : BYTE;
             modi : BOOLEAN;
             CONSTRUCTOR Init(ax1, ay1: INTEGER; aid: INTEGER; arace: INTEGER;
                              pally : PPHostAllianceRecord; amod : BOOLEAN);
             PROCEDURE DrawPart(afm, ato : INTEGER); VIRTUAL;
             FUNCTION Accessible(apos : INTEGER):BOOLEAN; VIRTUAL;
             FUNCTION Handle(VAR E:CEvent; pass:BOOLEAN):BOOLEAN; VIRTUAL;
             PROCEDURE SetState(astate:INTEGER; enable:BOOLEAN); VIRTUAL;
     END;

CONSTRUCTOR CAlliancePanel.Init(ax1, ay1 : INTEGER; aid : INTEGER;
                                arace : INTEGER; pally : PPHostAllianceRecord;
                                amod : BOOLEAN);
BEGIN
  CListbox.Init(ax1, ay1, ax1 + 286, ay1 + 176, aid);
  max  := 11;
  race := arace;
  ally := pally;
  mb   := 0;
  modi := amod;
  IF race=1 THEN pos:=2;
  state:=state OR lb_Framed;
END;

PROCEDURE CAlliancePanel.DrawPart(afm, ato : INTEGER);
VAR i, j, p, y : INTEGER;
    ax1        : INTEGER;
    ene_mask   : INTEGER;
    bi, bc, bx : INTEGER;
    S15        : STRING[15];
    S31        : STRING[31];
BEGIN
  ax1 := x1;
  TextStyle := 3;
  SetFillStyle(SOLIDFILL);
  JustX := 0;
  JustY := 0;

  ene_mask := 0;
  FOR i:=0 TO num_alliance_levels-1 DO
   IF alliance_info[i].flags AND ai_Enemy<>0 THEN
    ene_mask := ene_mask OR (1 SHL i);

  FOR i:=afm TO ato DO BEGIN
    y := 16*i + y1;
    Color := 0;
    AABg := Gray;
    p := i+1;
    IF p = race THEN Color := Dark ELSE
    IF p = pos THEN BEGIN
      Color := 15;
      IF state AND ws_Focus<>0 THEN AABg := 0;
    END;
    OutFTextXY(ax1 + 5, Y, 179, RaceNames[p].Short);
    ExtdBar(ax1, Y, ax1 + 4, Y+15, AABg);
    AABg := -1;
    Frame(ax1 + 185, Y, x2, Y+15);
    IF ally^.OfferedTo[p] AND pha_Valid<>0 THEN BEGIN
      IF ally^.OfferedFrom[p] AND pha_Valid<>0 THEN BEGIN
        Color := GreenBlack;
        j     := White;
        S31   := 'Established';
      END ELSE BEGIN
        Color := Yellow;
        j     := Black;
        S31   := 'We offered';
      END;
      S15 := 'cancel';
    END ELSE BEGIN
      IF ally^.OfferedFrom[p] AND pha_Valid<>0 THEN BEGIN
        Color := Yellow;
        j     := Black;
        S31   := 'They offered';
        S15   := 'accept';
      END ELSE BEGIN
        Color := Red;
        j     := Yellow;
        S31   := NoneStr;
        S15   := 'offer';
      END;
    END;
    IF p=PlayerId THEN BEGIN
      Color := BlueGray;
      j     := White;
      S31   := '';
    END;
{$IFDEF col256}
    IF _col256 THEN BEGIN
      CASE Color OF
        Red:        Color := $45;
        GreenBlack: Color := $A9;
        BlueGray:   Color := $64;
      END;
    END;
{$ENDIF}
    IF ally^.OfferedTo[p] AND ene_mask<>0 THEN BEGIN
      IF Color<>$45 THEN BEGIN
        bx := (ax1+x2+(186+7)) SHR 1;
        FOR bi:=1 TO 14 DO HLine(ax1+186, Y+bi, bx-bi);
        IF Color=Red THEN Color := Black ELSE Color := Red;
        FOR bi:=1 TO 14 DO HLine(bx-bi+1, Y+bi, x2-1);
      END ELSE BEGIN
        Color:=Red;
        Bar(ax1+186, Y+1, x2-1, Y+14, 0);
      END;
    END ELSE BEGIN
      Bar(ax1+186, Y+1, x2-1, Y+14, 0);
    END;
    Color := j;
    JustX:=1;
    OutTextXY(ax1 + 235, Y, S31);
    JustX:=0;
    IF p=pos THEN BEGIN
      AABg:=Gray;
      Color:=0;
      OutFTextXY(ax1, y1+184, 285, 'Press [Space] to ' + S15 + ' alliance.');
    END;
  END;
  TextStyle:=0;
  AABg:=-1;
END;

FUNCTION CAlliancePanel.Accessible(apos : INTEGER): BOOLEAN;
BEGIN
  Accessible := apos <> race;
END;

FUNCTION CAlliancePanel.Handle(VAR E:CEvent; pass:BOOLEAN):BOOLEAN;
VAR i:INTEGER;
BEGIN
  Handle := TRUE;
  CASE E.Typ OF
    ev_Mouse: IF (E.X >= x1 + 185) AND Inside(E.X, E.Y) THEN BEGIN
      owner^.Select(@Self);
      IF E.B = 0 THEN BEGIN
        IF (mb<>0) AND (pos=(E.Y-y1) DIV 16+1) THEN BEGIN
          IF modi THEN XorByte(ally^.OfferedTo[pos], pha_Valid);
          PutCommand(cm_Update, 0);
        END;
        mb := 0;
      END ELSE BEGIN
        owner^.SetFocus(@Self);
        i := (E.Y - y1) DIV 16 + 1;
        IF i<>race THEN ScrollTo(i, 1);
        mb := E.B;
      END;
      Exit;
    END ELSE mb:=0;
    ev_Command: CASE E.Cmd OF
      cm_Update: IF pass THEN UpdateCurrent;
    END;
    ev_Key: IF (state AND ws_Focus<>0) AND (E.Key = 32) THEN BEGIN
      IF modi THEN XorByte(ally^.OfferedTo[pos], pha_Valid);
      PutCommand(cm_Update, 0);
      Exit;
    END;
  END;
  Handle := CListbox.Handle(E, pass);
END;

PROCEDURE CAlliancePanel.SetState(astate:INTEGER; enable:BOOLEAN);
BEGIN
  CListbox.SetState(astate, enable);
  IF state AND ws_Select=0 THEN mb:=0;
END;

{
  Parse PHost alliance commands and apply them to A
}
PROCEDURE ReadAllianceCommands(VAR a:TPHostALlianceRecord);
VAR p:PPHostCommand;
    i,j:INTEGER;
    S:STRING[63];
BEGIN
  p := phc;
  WHILE p<>NIL DO BEGIN
    CASE p^.Cmd OF
      phc_ConfigAlly:FOR j:=1 TO Length(p^.Arg)-1 DO BEGIN
        i:=Pos(Chr(Ord(p^.Arg[j+1]) OR $20), pha_String)-1;
        IF i>=0 THEN BEGIN
          i := 1 SHL i;
          CASE p^.Arg[j] OF
            '-':BEGIN
              AndByte(a.OfferedTo[p^.Id], BYTE(NOT i));
              AndByte(a.ConditionalTo[p^.Id], BYTE(NOT i));
            END;
            '+':BEGIN
              OrByte(a.OfferedTo[p^.Id], i);
              AndByte(a.ConditionalTo[p^.Id], BYTE(NOT i));
            END;
            '~':BEGIN
              OrByte(a.OfferedTo[p^.Id], i);
              OrByte(a.ConditionalTo[p^.Id], i);
            END;
          END;
        END;
      END;
      phc_AddDropAlly:IF Ord(p^.Arg[1]) OR $20 = Ord('a') THEN
        OrByte(a.OfferedTo[p^.Id], pha_Valid)
      ELSE
        AndByte(a.OfferedTo[p^.Id], BYTE(NOT pha_Valid));
      phc_Enemies:IF Ord(p^.Arg[1]) OR $20 = Ord('a') THEN
        a.OfferedTo[p^.Id] := a.OfferedTo[p^.Id] OR pha_Enemy
      ELSE
        a.OfferedTo[p^.Id] := a.OfferedTo[p^.Id] AND NOT pha_Enemy;
    END;
    p := p^.Next;
  END;
END;

{
  Generate alliance command for one race. offer,cond = values
}
FUNCTION GenAllianceString(offer,cond:INTEGER):Str31;
VAR S31:STR31;
    j:INTEGER;
BEGIN
  S31:='';
  FOR j:=0 TO 4 DO BEGIN
    IF j<>0 THEN CatChar(S31, ' ');
    IF Odd(offer SHR j) THEN BEGIN
      IF Odd(cond SHR j) THEN CatChar(S31, '~') ELSE CatChar(S31, '+');
    END ELSE CatChar(S31, '-');
    CatChar(S31, pha_String[j+1]);
  END;
  GenAllianceString := S31;
END;

{
  Send PHost alliance commands
}
PROCEDURE SendAllianceCommands(VAR old, new:TPHostAllianceRecord);
VAR p,q,r:PPHostCommand;
    i,j:INTEGER;
    o:BOOLEAN;
    S31:STRING[31];
BEGIN
 {--- Delete alliance commands ---}
  p := phc;
  q := NIL;
  WHILE p<>NIL DO BEGIN
    IF (p^.Cmd=phc_AddDropAlly) OR (p^.Cmd=phc_ConfigAlly) OR (p^.Cmd=phc_Enemies) THEN BEGIN
      r := p;
      p := p^.Next;
      IF q<>NIL THEN q^.Next:=p ELSE phc:=p;
      FreePHostCommand(r);
    END ELSE BEGIN
      q := p;
      p := p^.Next;
    END;
  END;
 {--- Send new commands ---}
  o := TRUE;
  FOR i:=1 TO 11 DO IF PlayerID<>i THEN BEGIN
    { first do enemies }
    IF ((new.OfferedTo[i] XOR old.OfferedTo[i]) AND pha_Enemy) <> 0 THEN BEGIN
      IF new.OfferedTo[i] AND pha_Enemy=0 THEN S31 := 'drop' ELSE S31 := 'add';
      IF SetPHostCmd(phc_Enemies, i, S31)=NIL THEN o:=FALSE;
    END;
    { now do allies }
    j := 0;
    IF new.OfferedTo[i] AND pha_Valid=0 THEN new.OfferedTo[i] := 0;
    IF (old.OfferedTo[i] XOR new.OfferedTo[i]) AND pha_Valid<>0 THEN BEGIN
      IF new.OfferedTo[i] AND pha_Valid<>0 THEN BEGIN
        S31:='add';
        j:=1;
      END ELSE S31:='drop';
      IF SetPHostCmd(phc_AddDropAlly, i, S31)=NIL THEN o:=FALSE;
    END;
    S31 := GenAllianceString(new.OfferedTo[i], new.ConditionalTo[i]);
    IF (j<>0) OR (S31<>GenAllianceString(old.OfferedTo[i], old.ConditionalTo[i])) THEN BEGIN
      IF SetPHostCmd(phc_ConfigAlly, i, S31)=NIL THEN o:=FALSE;
    END;
  END;
  IF NOT o THEN NMemError;
END;

{
  Parse THost alliance commands
}
PROCEDURE ReadTAllianceCommands(VAR n:TPHostAllianceRecord);
VAR p:PPHostCommand;
    i:INTEGER;
    value:INTEGER;
BEGIN
  p := GetPHostCmd(phc_TAlliance, 0);
  IF p = NIL THEN Exit;
  value := 0;
  { pretty hackish parser :) }
  FOR i:=1 TO Length(p^.Arg) DO CASE p^.Arg[i] OF
    'e': Value := 0;
    'f': Value := pha_Valid;
    'F': Value := pha_Valid + phat_Vision;
    '1'..'9': n.OfferedTo[Ord(p^.Arg[i]) - 48] := Value;
    'a', 'A': n.OfferedTo[10]                  := Value;
    'b', 'B': n.OfferedTo[11]                  := Value;
  ELSE Value := 0;
  END;
END;

{
  Send alliance commands for THost
}
PROCEDURE SendTAllianceCommands(VAR old,new:TPHostAllianceRecord; noship:BOOLEAN);
VAR s:STRING[41];
    c:CHAR;
    i:INTEGER;
BEGIN
  s := '';
  FOR i:=1 TO 11 DO IF (old.OfferedTo[i] XOR new.OfferedTo[i]) AND (pha_Valid + phat_Vision)<>0 THEN BEGIN
    IF new.OfferedTo[i] AND pha_Valid=0    THEN S := S + 'ee' ELSE
    IF new.OfferedTo[i] AND phat_Vision<>0 THEN S := S + 'FF' ELSE
     S := S + 'ff';
    CatChar(S, Chr(Ord(Elf[i]) OR $20));
  END;

  IF S<>'' THEN BEGIN
    IF noship THEN NMessagebox('You do not have any ships. Alliance changes will not be sent.', Leerstring)
              ELSE SetPHostCmd(phc_TAlliance, 0, S);
  END ELSE RemovePHostCmd(phc_TAlliance, 0);
END;

{===========================================================================}

{
  Initialize alliance_levels / alliance_info structures
}
PROCEDURE InitAlliances;
VAR c : BYTE;
BEGIN
  num_alliance_levels := 0;
  IF HostType = host_PHost THEN BEGIN
    alliance_levels[0] := 'Ships';
    alliance_levels[1] := 'Planets';
    alliance_levels[2] := 'Minefields';
    alliance_levels[3] := 'Combat';
    alliance_levels[4] := 'Vision';
    alliance_info[0].flags := ai_Conditional + ai_OfferNeeded;
    alliance_info[0].code  := 's';
    alliance_info[1].flags := ai_Conditional + ai_OfferNeeded;
    alliance_info[1].code  := 'p';
    alliance_info[2].flags := ai_Conditional + ai_OfferNeeded;
    alliance_info[2].code  := 'm';
    alliance_info[3].flags := ai_Conditional + ai_OfferNeeded;
    alliance_info[3].code  := 'c';
    alliance_info[4].flags := ai_Conditional + ai_OfferNeeded;
    alliance_info[4].code  := 'v';
    num_alliance_levels := 5;
    IF (HostVersion >= 400008) AND (pconf<>NIL) AND (pconf^.main.CPEnableEnemies<>0) THEN BEGIN
      alliance_info[5].flags := ai_Enemy;
      alliance_info[5].code := 'e';
      alliance_levels[5] := 'Enemy!';
      num_alliance_levels := 6;
    END;
  END ELSE IF (HostVersion = 0) OR (HostVersion >= 322039) THEN BEGIN
    alliance_levels[0] := 'Vision';
    alliance_info[0].flags := ai_ShipNeeded + ai_OfferNeeded;
    alliance_info[0].code  := 'v';
    num_alliance_levels := 1;
  END;
END;

TYPE PAllyWindow = ^CAllyWindow;
     CAllyWindow = OBJECT(CUIWindow)
             PROCEDURE DrawInterior; VIRTUAL;
     END;

TYPE TGenCheckboxList = ARRAY[1..2, 0..MAX_ALLIANCE_LEVELS-1] OF PCheckbox;

PROCEDURE CAllyWindow.DrawInterior;
VAR i:INTEGER;
BEGIN
  JustX:=0; JustY:=0;
  Color:=0;
  AAColor:=Dark;
  OutTextXY(x1+10, y1+30,'Alliances:');
  IF num_alliance_levels<>0 THEN BEGIN
    ShowBmp(x1+324, y1+56, 403, FALSE);
    OutTextXY(x1+310, y1+30,'Status:');
    FOR i:=0 TO num_alliance_levels-1 DO OutTextXY(x1+390, y1+102+25*i, alliance_levels[i]);
    FrameDown(x1+310, y1+55, x2-15, y2-78);
  END;
END;

{
  Display one alliance configuration (=update checkboxes)
}
PROCEDURE DisplayGenAllianceConfig(pid:INTEGER; VAR A:TPHostAllianceRecord; VAR cb:TGenCheckboxList; mask:BYTE);
VAR offer,cond:ARRAY[1..2] OF BYTE;
    i,j:INTEGER;
BEGIN
  offer[1] := A.OfferedTo[pid];
  offer[2] := A.OfferedFrom[pid];
  cond[1] := A.ConditionalTo[pid];
  cond[2] := A.ConditionalFrom[pid];
  IF offer[1] AND pha_Valid=0 THEN offer[1] := offer[1] AND mask;
  IF offer[2] AND pha_Valid=0 THEN offer[2] := offer[2] AND mask;
  i:=0;
  WHILE i < num_alliance_levels DO BEGIN
    FOR j:=1 TO 2 DO BEGIN
      IF Odd(Offer[j] SHR i) THEN BEGIN
        IF Odd(Cond[j] SHR i) THEN
         cb[j, i]^.SetVal(2)
        ELSE
         cb[j, i]^.SetVal(1)
      END ELSE
       cb[j, i]^.SetVal(0);
    END;
    Inc(i);
  END;
END;

{
  Regenerate alliance offers (=update A from checkboxes CB)
}
PROCEDURE RegenGenOffers(race:INTEGER; VAR A:TPHostAllianceRecord; VAR cb:TGenCheckboxList);
VAR i:INTEGER;
BEGIN
  A.OfferedTo[race] := A.OfferedTo[race] AND pha_Valid;
  A.ConditionalTo[race] := 0;
  i:=0;
  WHILE i<num_alliance_levels DO BEGIN
    IF cb[1,i]^.val <> 0 THEN BEGIN
      Inc(A.OfferedTo[race], 1 SHL i);
      IF alliance_info[i].flags AND ai_OfferNeeded<>0 THEN
       A.OfferedTo[race] := A.OfferedTo[race] OR pha_Valid;
    END;
    IF cb[1,i]^.val = 2 THEN Inc(A.ConditionalTo[race], 1 SHL i);
    Inc(i);
  END;
END;

PROCEDURE SendGenAllianceCommands(VAR old, new : TPHostAllianceRecord;
                                  needsh : BOOLEAN);
BEGIN
  IF HostType = host_PHost THEN SendAllianceCommands(old, new)
                           ELSE SendTAllianceCommands(old, new, needsh);
END;

{
  Generic Alliance Editor

  This is more general than currently needed.
}
PROCEDURE EditAlliances;
VAR NewAlly        : TPHostAllianceRecord;
    pap            : PAlliancePanel;
    pw             : PAllyWindow;
    pg             : PGroup;
    x1, y1, x2, y2 : INTEGER;
    i, j, k        : INTEGER;
    E              : CEvent;
    pcb            : TGenCheckboxList;
    mask           : INTEGER;
    needsh         : BOOLEAN;
BEGIN
  InitAlliances;

  mask := 0;
  needsh := (HostType <> host_PHost);
  FOR i:=0 TO num_alliance_levels-1 DO BEGIN
    IF alliance_info[i].flags AND ai_OfferNeeded=0 THEN mask := mask OR (1 SHL i);
    IF alliance_info[i].flags AND ai_ShipNeeded<>0 THEN needsh := TRUE;
  END;
  NewAlly := PAlliance;
  FOR i:=1 TO 11 DO
   IF NewAlly.OfferedTo[i] AND pha_Valid=0 THEN
    NewAlly.OfferedTo[i] := NewAlly.OfferedTo[i] AND mask;
  IF HostType = host_PHost THEN ReadAllianceCommands(NewAlly)
                           ELSE ReadTAllianceCommands(NewAlly);

  IF num_alliance_levels=0 THEN BEGIN
    x1 := 160;
    y1 := 80;
    x2 := 475;
    y2 := 390;
  END ELSE BEGIN
    i  := num_alliance_levels;
    IF i < 5 THEN i := 5;
    x1 := 50;
    y1 := 80+12*5 - 12*i;
    x2 := 590;
    y2 := 390-13*5 + 13*i;
  END;
  pw := New(PAllyWindow, Init(x1, y1, x2, y2, 'Alliance Status', wfc_BlueWindow, Gray));
  pap := New(PAlliancePanel, Init(x1+15, y1+56, 1000, PlayerId, @NewAlly, TRUE{changeable}));
  pw^.Add(pap);
  pw^.SetFocus(pap);
  pw^.Add(New(PButton, InitR(cm_Enter,  x1+14, y2-40,  40, 25, OKtext, 0, 13))
                       ^.SetHelp(OKhelp));
  pw^.Add(New(PButton, InitR(cm_Escape, x1+59, y2-40,  70, 25, CancelText, 0, 27))
                       ^.SetHelp(ESChelp));
  pw^.Add(New(PButton, InitR(cm_Help,   x2-40, y2-40,  25, 25, LetterH, bf_Help, Ord('H'))));
  pw^.Add(New(PButton, InitR(4, x1+134, y2-40, 380-294, 25, 'Teams...', 0, Ord('T')))
                       ^.SetHelp('Assign players to teams'));
  IF num_alliance_levels<>0 THEN BEGIN
    pg := New(PGroup, Init(360, 135, 575, 312, 1001));
    FOR i:=1 TO 2 DO FOR j:=0 TO num_alliance_levels-1 DO BEGIN
      IF alliance_info[j].flags AND ai_Conditional<>0 THEN k:=cb_Cond
                                                      ELSE k:=cb_On;
      pcb[i,j] := New(PCheckbox, Init(2001 + j + 10*i,
                                      340 + 30*i, y1+100 + 25*j,
                                      0, k, 0));
      pg^.Add(pcb[i,j]);
    END;
    FOR j:=0 TO num_alliance_levels-1 DO pcb[2,j]^.state := ws_Disabled;
    pg^.SetFocus(pcb[1,0]);
    pg^.Add(New(PFocusIterator, Init(2011, 2011+num_alliance_levels, fi_Vert)));
    pw^.Add(pg);
    pw^.Add(New(PFocusIterator, Init(1000, 1001, fi_Horz + fi_Tab)));
  END;

  OpenWindow(New(PBlankScreen, Init(0, 0, 639, 479, 0)), TRUE);
  OpenWindow(pw, TRUE);
  IF needsh THEN
   FOR i:=1 TO NUM_SHIPS DO
    IF Ships^[i].HUser<>NIL THEN needsh := FALSE;
  IF needsh THEN
    NMessageBox('You do not have any ships. A ship is needed to '+
                'transmit alliance settings to the host. '+
                'Your changes might not be transmitted.', 'Alliances');
  REPEAT
    DisplayGenAllianceConfig(pap^.pos, NewAlly, pcb, mask);
    WinLoop(0, E);
    CASE E.Cmd OF
      cm_Checkbox: BEGIN
        RegenGenOffers(pap^.pos, NewAlly, pcb);
        pap^.UpdateCurrent;
      END;
      cm_Enter: SendGenAllianceCommands(PAlliance, NewAlly, needsh);
      cm_Escape: E.Cmd := cm_Enter;
      cm_Help: NHelp(hcPHostAlliance);
      4: BEGIN
        SendGenAllianceCommands(PAlliance, NewAlly, needsh);
        i := EditTeams;
        IF i = 0 THEN E.Cmd := cm_Enter ELSE DrawUI;
      END;
    END;
  UNTIL E.Cmd = cm_Enter;
  CloseWindow(FALSE);
  CloseWindow(FALSE);
END;
{$ENDIF}

{===========================================================================}

{
  String match, PHost way: CMD=command, mandatory letters in upper case,
  USR=what user said. Returns true iff matches
}
FUNCTION PMatch(CONST cmd, usr: PHStr15):BOOLEAN;
VAR i:INTEGER;
BEGIN
  IF (Length(usr) > Length(cmd)) OR (usr='') THEN BEGIN
    PMatch := FALSE;
    Exit;
  END;
  i := 0;
  REPEAT
    Inc(i);
    IF i > Length(usr) THEN BEGIN
      PMatch := (i > Length(cmd)) OR ((cmd[i] >= 'a') AND (cmd[i] <= 'z'));
      Exit;
    END;
  UNTIL (Upcase(cmd[i]) <> Upcase(usr[i]));
  PMatch := FALSE;
END;

VAR wortanfang : INTEGER;       { after FindWord, contains index of word start }

{ Find i'th word from s (0=first, 1=second, ...) }
FUNCTION FindWord(CONST s:PHStr63; i:INTEGER):PHStr63;
VAR j, k : INTEGER;
BEGIN
  k := 1;
  WHILE i > 0 DO BEGIN
    WHILE (k<=Length(S)) AND (S[k]<>' ') DO Inc(k);
    WHILE (k<=Length(S)) AND (S[k]=' ') DO Inc(k);
    Dec(i);
  END;
 { k -> Wortanfang }
  j := k;
  wortanfang := j;
  WHILE (j<=Length(S)) AND (S[j]<>' ') DO Inc(j);
  FindWord := Copy(S, k, j-k);
END;

{
  Parse line from command file. Returns false iff reading command file
  should be stopped (=wrong timestamp, maybe).
}
FUNCTION ParseCmdFileLine(S:STRING) : BOOLEAN;
BEGIN
  Strip1(S);
  IF (S='') OR (S[1]='#') THEN BEGIN
    {... Comment ...}
    ParseCmdFileLine := TRUE;
    Exit;
  END;
  IF PMatch('$TIMEstamp', FindWord(s, 0)) THEN BEGIN
    {... Timestamp marker ...}
    ParseCmdFileLine := (FindWord(s, 1)={$IFDEF VPA}Stamp{$ELSE}Gen.Timestamp{$ENDIF});
    Exit;
  END;
  IF ReverseEngineerPHostCommand(S, TRUE)=NIL THEN BEGIN
    { FIXME: out of memory handler }
    SetPHostCmd(phc_Other, 0, S);
  END;
  ParseCmdFileLine := TRUE;
END;

{
  "Decompile" PHost command. Returns command or NIL
  FROMFILE=true iff we're reading cmdX.txt. The special `$' commands
  should be recognized only there.
}
FUNCTION ReverseEngineerPHostCommand(S : PHStr63; fromfile:BOOLEAN) : PPHostCommand;
VAR i, j, k  : INTEGER;
    verb, s1 : STR15;
BEGIN
  ReverseEngineerPHostCommand := NIL;
  Strip1(S);
  verb := FindWord(s, 0);
  s1 := FindWord(s, 1);
  {=== Special commands from CMDx.TXT file ===}
  IF fromfile THEN BEGIN
    IF PMatch('$THOST-ALLIES', verb) THEN BEGIN
      ReverseEngineerPHostCommand := SetPHostCmd(phc_TAlliance, 0, Copy(S, wortanfang, 255));
      Exit;
    END;
    IF PMatch('$SEND-File', verb) THEN BEGIN
      ReverseEngineerPHostCommand := SetPHostCmd(phc_SendFile, 0, Copy(S, wortanfang, 255));
      Exit;
    END;
  END;
  IF PMatch('Send', verb) THEN BEGIN
   {--- send (config|racenames|fcodes) ---}
    IF PMatch('Config',    s1) THEN ReverseEngineerPHostCommand := SetPHostCmd(phc_SendConfig,    0, Leerstring) ELSE
    IF PMatch('Racenames', s1) THEN ReverseEngineerPHostCommand := SetPHostCmd(phc_SendRacenames, 0, Leerstring) ELSE
    IF PMatch('Fcodes',    s1) THEN ReverseEngineerPHostCommand := SetPHostCmd(phc_SendFCodes,    0, Leerstring);
    Exit;
  END ELSE IF PMatch('Language', verb) THEN BEGIN
   {--- language <string> ---}
    IF s1<>'' THEN ReverseEngineerPHostCommand := SetPHostCmd(phc_Language, 0, s1);
  END ELSE IF PMatch('Filter', verb) THEN BEGIN
   {--- filter (yes|no) ---}
    IF s1<>'' THEN ReverseEngineerPHostCommand := SetPHostCmd(phc_Filter, 0, s1);
  END ELSE IF PMatch('Give', verb) THEN BEGIN
   {--- give (ship|planet) <id> [to] <race> ---}
    Val(FindWord(s, 2), i, j);
    IF j=0 THEN BEGIN
      k := 3;
      IF PMatch('To', FindWord(s, 3)) THEN k := 4;
      IF PMatch('Ship', FindWord(s, 1)) THEN
       ReverseEngineerPHostCommand := SetPHostCmd(phc_GiveShip, i, FindWord(s, k)) ELSE
      IF PMatch('Planet', FindWord(s, 1)) THEN
       ReverseEngineerPHostCommand := SetPHostCmd(phc_GivePlanet, i, FindWord(s, k));
    END;
  END ELSE IF PMatch('Allies', verb) THEN BEGIN
    Val(FindWord(s, 2), i, j);
    IF j=0 THEN BEGIN
      IF PMatch('Config', s1) THEN BEGIN
       {--- allies config <race> <string> ---}
        IF FindWord(s, 3)<>'' THEN BEGIN
          ReverseEngineerPHostCommand := SetPHostCmd(phc_ConfigAlly, i, Copy(s, wortanfang, 255));
        END;
      END ELSE IF PMatch('Add', s1) OR PMatch('Drop', s1) THEN BEGIN
       {--- allies (add|drop) <race> ---}
        ReverseEngineerPHostCommand := SetPHostCmd(phc_AddDropAlly, i, s1);
      END;
    END;
  END ELSE IF PMatch('REmote', verb) THEN BEGIN
   {--- remote <verb> (<id>|default) ---}
    s1 := FindWord(s, 2);
    IF PMatch('Default', s1) THEN BEGIN
      ReverseEngineerPHostCommand := SetPHostCmd(phc_RemoteDefault, 0, FindWord(s, 1));
    END ELSE BEGIN
      verb := FindWord(s, 1);
      Val(s1, i, j);
      IF (j=0) AND (PMatch('Control', verb) OR PMatch('Allow', verb)
                    OR PMatch('Forbid', verb) OR PMatch('Drop', verb))
      THEN
       ReverseEngineerPHostCommand := SetPHostCmd(phc_RemoteControl, i, verb);
    END;
  END ELSE IF PMatch('BEamup', verb) THEN BEGIN
   {--- beamup <sid> <spec> ---}
    Val(FindWord(s, 1), i, j);
    IF (j=0) AND (FindWord(s, 2)<>'') THEN BEGIN
      ReverseEngineerPHostCommand := SetPHostCmd(phc_BeamUp, i, Copy(s, wortanfang, 255));
    END;
  END ELSE IF PMatch('RAcename', verb) THEN BEGIN
   {--- racename (long|short|adj) <name> ---}
    IF PMatch('Long', s1) THEN i:=1 ELSE
    IF PMatch('Short', s1) THEN i:=2 ELSE
    IF PMatch('Adjective', s1) THEN i:=3 ELSE Exit;
    IF (FindWord(S, 2)<>'') THEN BEGIN
      ReverseEngineerPHostCommand := SetPHostCmd(phc_SetRacename, i, Copy(s, wortanfang, 255));
    END;
  END ELSE IF PMatch('ENEmies', verb) THEN BEGIN
    IF PMatch('Add', s1) OR PMatch('Drop', s1) THEN BEGIN
      i := 2;
      WHILE TRUE DO BEGIN
        verb := FindWord(S, i);
        IF verb='' THEN Break;
        Val(verb, j, k);
        IF (k=0) AND (j>0) AND (j<=11) THEN
         ReverseEngineerPHostCommand := SetPHostCmd(phc_Enemies, j, s1);
        Inc(i);
      END;
    END;
  END;
END;

{
  True iff s is a command that tells PHost to process the following lines
  as a message (i.e., we should no longer try to interpret it as commands)
}
FUNCTION IsPHostMessageIntroducer(S : PHStr63) : BOOLEAN;
VAR s1 : Str15;
BEGIN
  Strip1(s);
  s1 := FindWord(S, 0);
  IsPHostMessageIntroducer := PMatch('RUmour', s1) OR PMatch('RUmor', s1) OR PMatch('Message', s1);
END;

{$IFNDEF VPA}
PROCEDURE MaybeRequestPConfig;
VAR S : STRING[63];
BEGIN
  IF pconf<>NIL THEN Exit;
  IF GetPHostCmd(phc_SendConfig, 0)<>NIL THEN Exit;
  SetPHostCmd(phc_SendConfig, 0, Leerstring);

  S := '';
  IF MainOptions AND mo_NoCommandMsg<>0 THEN
    S := #13'You must use PCC''s built-in Maketurn for this to work.';
  NMessagebox('This game seems to use PHost, but you do not have PCONFIG.SRC. '
            + 'I have requested it for you using a command message.' + S,
              'Note');
END;
{$ENDIF}

{--------------------------------------------------------------------------}

CONST battle_results : PBattleResult = NIL;

PROCEDURE AddBattleResult(VAR data; size:WORD);
VAR p : PBattleResult;
BEGIN
  IF size >= 30 THEN BEGIN
    p := Malloc(Sizeof(TBattleResult));
    IF p<>NIL THEN BEGIN
      IF Size > Sizeof(Util7Battle) THEN Size := Sizeof(Util7Battle);
      p^.Next := battle_results;
      p^.Size := Size;
      Move(data, p^.u, Size);
      battle_results := p;
    END;
  END;
END;

PROCEDURE FreeBattleResults;
VAR p : PBattleResult;
BEGIN
  WHILE battle_results<>NIL DO BEGIN
    p := battle_results;
    battle_results := p^.Next;
    Dispose(p);
  END;
END;

FUNCTION GetBattleResult(VAR vcr):POINTER;
VAR p : PBattleResult;
    t : TVcr ABSOLUTE vcr;
BEGIN
  p := battle_results;
  WHILE (p<>NIL) AND ((p^.u.sid1<>t.Objs[Left].Id)
                      OR (p^.u.sid2<>t.Objs[Right].Id)
                      OR (p^.u.isplanet2<>t.BattleType)
                      OR (p^.u.owner1<>t.Objs[Left].Owner)
                      OR (p^.u.owner2<>t.Objs[Right].Owner)
                      OR ((p^.size >= Sizeof(Util7Battle)) AND (WORD(p^.u.seed)<>WORD(t.PsRandSeedInit))))
  DO p := p^.Next;
  GetBattleResult := p;
END;

{--- Build Queue ----------------------------------------------------------}

TYPE TQEntryArray = ARRAY[1..NUM_PLANETS] OF Util39QueueEntry;

CONST queue : ^TQEntryArray = NIL;

PROCEDURE AddBuildQueueEntry(VAR data : Util39QueueEntry);
BEGIN
  IF (data.bid<=0) OR (data.bid>NUM_PLANETS) THEN Exit;
  IF queue=NIL THEN BEGIN
    queue := Malloc(Sizeof(TQEntryArray));
    IF queue=NIL THEN Exit;      { ignore. It's just supplementary information }
  END;
  queue^[data.bid] := data;
END;

FUNCTION GetQueueEntry(base:INTEGER):PUtil39QueueEntry;
BEGIN
  IF (queue<>NIL) AND (queue^[base].bid=base)
   THEN GetQueueEntry := @queue^[base]
   ELSE GetQueueEntry := NIL;
END;

PROCEDURE FreeQueueEntries;
BEGIN
  IF queue<>NIL THEN BEGIN
    Dispose(queue);
    queue := NIL;
  END;
END;

{--- Scores ---------------------------------------------------------------}

CONST unit_scores : ARRAY[BOOLEAN] OF PUnitScore = (NIL, NIL);

{
  Add a unit score.
    ship    true if ship score, false if planet score
    head    header, from util.dat
    count   expected number of entries
  Returns score entry, or null if out of memory.
}
FUNCTION AddUnitScore(ship:BOOLEAN; head:Util49ShipScore; count:INTEGER) : TUnitScoreHandle;
VAR p : PUnitScore;
BEGIN
  p := GetUnitScore(ship, head.id);
  IF p=NIL THEN BEGIN
    p := Malloc(Sizeof(TUnitScore));
    IF p<>NIL THEN BEGIN
      IF count < 16 THEN count:=16;
      p^.data := Malloc(count*Sizeof(TUnitScoreEntry));
      IF p^.data=NIL THEN BEGIN
        Dispose(p);
        p := NIL;
      END ELSE BEGIN
        p^.count := 0;
        p^.alloc := count;
        p^.header := head;
        p^.next := unit_scores[ship];
        unit_scores[ship] := p;
      END;
    END;
  END;
  AddUnitScore := p;
END;

{ Add entry to a unit score }
PROCEDURE AddUnitScoreEntry(score:TUnitScoreHandle; id, value, turn:INTEGER);
VAR i : INTEGER;
    p : POINTER;
BEGIN
  IF score=NIL THEN Exit;
  FOR i:=1 TO score^.count DO
   IF score^.data^[i].id = id THEN BEGIN
     IF score^.data^[i].turn <= turn THEN BEGIN
       score^.data^[i].value := value;
       score^.data^[i].turn := turn;
     END;
     Exit;
   END;
  IF score^.count >= score^.alloc THEN BEGIN
    i := score^.alloc + 16;
    p := Realloc(i*Sizeof(TUnitScoreEntry), score^.data, score^.alloc*Sizeof(TUnitScoreEntry));
    IF p=NIL THEN Exit;
    score^.data := p;
    score^.alloc := i;
  END;
  Inc(score^.count);
  score^.data^[score^.count].id := id;
  score^.data^[score^.count].value := value;
  score^.data^[score^.count].turn := turn;
END;

{ Free all unit scores }
PROCEDURE FreeScores;
VAR b : BOOLEAN;
    p : PUnitScore;
BEGIN
  FOR b:=FALSE TO TRUE DO
   WHILE unit_scores[b]<>NIL DO BEGIN
     p := unit_scores[b];
     unit_scores[b] := p^.next;
     FreeMem(p^.data, p^.alloc*Sizeof(TUnitScoreEntry));
     Dispose(p);
   END;
END;

{ Get handle to a particular unit score }
FUNCTION GetUnitScore(ship:BOOLEAN; score_id:INTEGER):TUnitScoreHandle;
VAR p : PUnitScore;
BEGIN
  p := unit_scores[ship];
  WHILE (p<>NIL) AND (p^.header.id<>score_id) DO BEGIN
    p := p^.next;
  END;
  GetUnitScore := p;
END;

{ Get entry of a unit score }
FUNCTION GetUnitScoreEntry(e:TUnitScoreHandle; id:INTEGER; ageptr:PInteger):INTEGER;
VAR i:INTEGER;
BEGIN
  IF e<>NIL THEN BEGIN
    FOR i:=1 TO e^.count DO
     IF e^.data^[i].id = id THEN BEGIN
       IF ageptr<>NIL THEN ageptr^ := e^.data^[i].turn;
       GetUnitScoreEntry := e^.data^[i].value;
       Exit;
     END;
  END;
  GetUnitScoreEntry := -1;
END;

FUNCTION GetExperienceLevel(ship:BOOLEAN; id:INTEGER):INTEGER;
BEGIN
 {$IFDEF VPA}
  IF FALSE {FIXME}
 {$ELSE}
  IF (pconf=NIL) OR (pconf^.main.NumExperienceLevels=0)
 {$ENDIF}
   THEN GetExperienceLevel := -1
   ELSE GetExperienceLevel := GetUnitScoreEntry(GetUnitScore(ship, uscore_Experience), id, NIL);
END;

PROCEDURE SaveUnitScores(cb:TSaveUnitScoreCallback; arg:POINTER);
VAR y : BOOLEAN;
    p : PUnitScore;
BEGIN
  FOR y:=FALSE TO TRUE DO BEGIN
    p := unit_scores[y];
    WHILE p<>NIL DO BEGIN
      cb(y, p^.header, p^.count, p^.data^, arg);
      p := p^.next;
    END;
  END;
END;

PROCEDURE ClearUnitScores(ship:BOOLEAN; id:INTEGER; before_turn:INTEGER);
VAR p : PUnitScore;
    i : INTEGER;
BEGIN
  p := unit_scores[ship];
  WHILE p<>NIL DO BEGIN
    FOR i:=1 TO p^.count DO
     IF p^.data^[i].id = id THEN BEGIN
       IF p^.data^[i].turn < before_turn THEN
         p^.data^[i].value := -1;
       Break;
     END;
    p := p^.next;
  END;
END;

END.
