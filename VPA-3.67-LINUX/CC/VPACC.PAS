{
  VPA / PCC Glue

  Some definitions to make PCC source code work inside VPA. Not
  all of this is actually used.
}
UNIT VPACC;

INTERFACE

USES Screen, VPAData;

CONST NUM_SHIPS   = 999;
CONST NUM_PLANETS = 500;

CONST MaxHulls = 105;
CONST HullCnt  = 105;

{ type aliases }
TYPE Str15 = STRING[15];
     Str63 = STRING[63];

{ VCR record. This one's needed for PHost instant battle result }
TYPE TWho   = LRType;

TYPE TVCRObject=RECORD
	   Name                  : ARRAY[1..20] OF CHAR; { Name }
	   Damage                : INTEGER;              { Damage % }
	   Crew                  : INTEGER;              { Crew }
	   Id                    : INTEGER;              { ID }
	   Owner                 : INTEGER;              { Owner (PHost/PlayerRace encoding is resolved during load) }
	   Pic                   : BYTE;                 { Picture }
	   Hull                  : BYTE;                 { Hull or 0 }
	   BeamType              : INTEGER;              { Beam ID }
	   BeamCount             : INTEGER;              { Beam Type }
	   FighterCount          : INTEGER;              { # Fighterbays }
	   TorpType              : INTEGER;              { Torpedo type }
	   TFCount               : INTEGER;              { # Torps/Fighters }
	   TLauncherCount        : INTEGER;              { # Torp launchers }
     END;

{--- Full VCR Record ---}
     TVCR=RECORD
	   PsRandSeedInit  : WORD;                      { Randomizer initial value }
	   Magic           : WORD;                      { PHost magic number }
	   PlanetTemp      : INTEGER;                   { Planet Temp }
	   BattleType      : INTEGER;                   { Battle type (0=s/s, 1=s/p) }
	   Mass            : ARRAY[Left..Right] OF INTEGER;    { Masses (kt) }
	   Objs            : ARRAY[Left..Right] OF TVCRObject; { Warriors }
	   Shield          : ARRAY[Left..Right] OF INTEGER;    { Shields % }
     END;

{ Variable name aliases }
VAR gr       : BOOLEAN ABSOLUTE GrMode;
VAR GameDir  : STRING[Sizeof(addir)-1] ABSOLUTE addir;
VAR PlayerStr : STRING[Sizeof(plstr)-1] ABSOLUTE plstr;
VAR PlayerId  : INTEGER ABSOLUTE player;

{ some string literals }
CONST Leerstring : STRING[1] = '';
CONST Kilotons   : STRING[3] = ' kt';
CONST LetterH    : STRING[1] = 'H';
CONST PlusStr    : STRING[1] = '+';
CONST MinusStr   : STRING[1] = '-';
CONST ClosePar   : STRING[1] = ')';
CONST StartIdStr : STRING[3] = ' (#';
CONST YesStr     : STRING[3] = 'Yes';
CONST NoStr      : STRING[2] = 'No';
CONST DATExt     : STRING[4] = '.dat';
CONST DISExt     : STRING[4] = '.dis';
CONST CCExt      : STRING[3] = '.cc';
CONST Percent    : STRING[1] = '%';
CONST OutOfMemory: STRING[13] = 'Out of memory';
CONST SpacerStr  : STRING[3] = ' - ';
CONST Lightyears : STRING[3] = ' ly';
CONST Megacredits: STRING[3] = ' mc';
CONST ColonSP    : STRING[2] = ': ';
CONST Elf        : STRING[11] = '123456789AB';

{ was there an error? }
CONST Error      : BOOLEAN = FALSE;

PROCEDURE CatChar(VAR s:STRING; c:CHAR);
PROCEDURE Strip1(VAR s:STRING);
PROCEDURE RedrawScreen;
FUNCTION  Malloc(size:WORD):POINTER;
FUNCTION  Realloc(count:WORD; old:POINTER; oldsz:WORD):POINTER;
FUNCTION  itoa(l:LONGINT):Str15;

(*PROCEDURE AddListItem(value:INTEGER; CONST text:STRING);*)
FUNCTION SimpleListbox(CONST title:STRING; wi,he:INTEGER; val:INTEGER):INTEGER;

{ Simple version of TDosStream }
CONST stCreate    = $3C00;       { Create file }
      stOpenRead  = $3D00;       { Read only }
      stOpenWrite = $3D01;       { Write only }
      stOpen      = $3D02;       { Random access }

TYPE TDosStream = OBJECT
           handle : INTEGER;
           status : INTEGER;
           CONSTRUCTOR Init(CONST fn : STRING; mode : WORD);
           DESTRUCTOR  Done;
           FUNCTION    PRead(VAR buf; size : WORD):WORD;
           FUNCTION    PWrite(VAR buf; size : WORD):WORD;
           PROCEDURE   Seek(pos:LONGINT);
           FUNCTION    GetPos:LONGINT;
           FUNCTION    GetSize:LONGINT;
           PROCEDURE   Read(VAR buf; size : WORD);
           PROCEDURE   Write(VAR buf; size : WORD);
      PRIVATE
           FUNCTION    LSeek(pos:LONGINT; whence:INTEGER):LONGINT;
     END;
     PDosStream = ^TDosStream;

     { originally, TStream was the base class of TDosStream }
     PStream    = PDosStream;

PROCEDURE OpenFile(CONST Name:Str15; ResID:INTEGER);
PROCEDURE CloseFile;

VAR ofStream : PDosStream;
VAR RaceIDs  : ARRAY[1..11] OF INTEGER ABSOLUTE Race;

IMPLEMENTATION

USES StrF, VPA2, Graph;

PROCEDURE CatChar(VAR s:STRING; c:CHAR);
BEGIN
  s := s + c;
END;

PROCEDURE Strip1(VAR s:STRING);
BEGIN
  Trim(s);
END;

PROCEDURE RedrawScreen;
BEGIN
  DrawMap(True);
END;

FUNCTION Malloc(size:WORD):POINTER;
VAR p : POINTER;
BEGIN
  IF MaxAvail < size THEN Malloc := NIL ELSE BEGIN
    GetMem(p, size);
    Fillchar(p^, size, 0);
    Malloc := p;
  END;
END;

FUNCTION Realloc(count:WORD; old:POINTER; oldsz:WORD):POINTER;
VAR p : POINTER;
BEGIN
  p := Malloc(count);
  IF p<>NIL THEN BEGIN
    IF count>oldsz THEN count:=oldsz;
    IF count<>0 THEN Move(old^, p^, count);
    FreeMem(old, oldsz);
  END;
  Realloc := p;
END;

{*** TDosStream **********************************************************}
{
  Cut & paste & hacked from the library used by PCC. Which in turn stole
  it years ago from Turbo Vision.
}

CONSTRUCTOR TDosStream.Init(CONST fn : STRING; mode : WORD); ASSEMBLER;
VAR NameBuf:ARRAY[0..79] OF CHAR;
ASM
        PUSH    DS
        LDS     SI,fn           { zero-terminate filename }
        LEA     DI,NameBuf
        MOV     DX,DI
        PUSH    SS
        POP     ES
        CLD
        LODSB
        CMP     AL,79           { 79 = max length of DOS file name }
        JB      @Kurz
        MOV     AL,79
  @Kurz:CBW
        XCHG    AX,CX
        REP     MOVSB
        XCHG    AX,CX
        STOSB
        PUSH    SS
        POP     DS

        XOR     CX,CX
        MOV     AX,Mode         { Mode = DOS Function number + access mode }
        INT     21H
        POP     DS
        LES     DI,Self
        MOV     ES:[DI].TDosStream.Status,0
        JNC     @OK
        MOV     ES:[DI].TDosStream.Status,AX
        MOV     AX,-1
  @OK:  LES     DI,Self
        MOV     ES:[DI].TDosStream.Handle,AX
END;

DESTRUCTOR TDosStream.Done; ASSEMBLER;
ASM
        les     di, Self
        mov     ah, 3Eh
        mov     bx, es:[di].TDosStream.Handle
        or      bx, bx
        js      @no
        int     21h
@no:
END;

FUNCTION TDosStream.PRead(VAR buf; size : WORD):WORD; ASSEMBLER;
ASM
        LES     DI,Self
        CMP     ES:[DI].TDosStream.Status,0
        JNE     @Fehler            { refuse read when there was an error }

        PUSH    DS
        LDS     DX,Buf
        MOV     CX,size
        MOV     BX,ES:[DI].TDosStream.Handle
        MOV     AH,3FH
        INT     21H
        POP     DS
        jnc     @ok
        LES     DI,Self
        mov     es:[di].TDosStream.Status,ax
@Fehler:xor     ax, ax          { 0 Bytes read }
@OK:
END;

FUNCTION TDosStream.PWrite(VAR buf; size : WORD):WORD; ASSEMBLER;
ASM
        LES     DI,Self
        xor     ax, ax
        CMP     ES:[DI].TDosStream.Status,0
        JNE     @Nix            { go on holiday after error }

        PUSH    DS
        LDS     DX,Buf
        MOV     CX,size
        MOV     BX,ES:[DI].TDosStream.Handle
        MOV     AH,40H
        INT     21H
        POP     DS
        jnc     @nix
@Fehler:LES     DI,Self
        mov     es:[di].TDosStream.Status, ax
        xor     ax, ax
@Nix:
END;

PROCEDURE TDosStream.Seek(pos:LONGINT);
BEGIN
  IF Status=0 THEN LSeek(pos, 0);
END;

FUNCTION TDosStream.GetPos:LONGINT;
BEGIN
  IF Status=0 THEN GetPos:=LSeek(0, 1) ELSE GetPos := -1;
END;

FUNCTION TDosStream.GetSize:LONGINT;
VAR L : LONGINT;
BEGIN
  IF Status=0 THEN BEGIN
    L := LSeek(0, 1);
    GetSize := LSeek(0, 2);
    LSeek(L, 0);
  END ELSE GetSize := -1;
END;

PROCEDURE TDosStream.Read(VAR buf; size : WORD);
BEGIN
  IF PRead(Buf, Size)<>Size THEN BEGIN
    FillChar(Buf, Size, 0);
    IF Status=0 THEN Status:=1;
  END;
END;

PROCEDURE TDosStream.Write(VAR buf; size : WORD);
BEGIN
  IF PWrite(Buf, Size)<>Size THEN BEGIN
    IF Status=0 THEN Status:=1;
  END;
END;

FUNCTION TDosStream.LSeek(pos:LONGINT; whence:INTEGER):LONGINT; ASSEMBLER;
ASM
        les     di, Self
        mov     bx, es:[di].TDosStream.Handle
        mov     ah, 42h
        mov     al, whence.byte
        mov     cx, pos.word.2
        mov     dx, pos.word.0
        int     21h
        jnc     @ok
        xor     ax,ax           { unclean, but who cares. }
        cbw
@ok:
END;

(*
{ NOTE: VPA assumes that the values come in in order 1..N, so be
  careful with this one. }
CONST MenuItemCount : INTEGER = 0;

PROCEDURE AddListItem(value:INTEGER; CONST text:STRING);
BEGIN
  AddMenuItem(text, 7, FALSE);
  Inc(MenuItemCount);
END;*)

FUNCTION SimpleListbox(CONST title:STRING; wi,he:INTEGER; val:INTEGER):INTEGER;
BEGIN
  MouseOff;
  SetColor(White);
  SetLineStyle(SolidLn, 0, 1);
  SetFillStyle(SOLIDFILL, 0);
  Bar(5, 100, wi+11, 112);
  Rectangle(5, 100, wi+11, 112);
  SetTextJustify(0, 2);
  OutTextXY(10, 102, title);

  ChooseMenu(8, 124, 10, 8+wi, he, White, White, val, FALSE, FALSE,-1);
  NewMenu;
  IF MenuKey<>27 THEN SimpleListbox:=MenuValue ELSE SimpleListbox:=-1;
  DrawMap(True);

  MouseOn;
END;

FUNCTION itoa(L:LONGINT):Str15;
VAR s:Str15;
BEGIN
  Str(L,s);
  itoa:=s;
END;

{
  Open a (specification) file. Check game dir first, then
  current directory. In PCC, this also tries the resource file.
}
PROCEDURE OpenFile(CONST Name:Str15; ResID:INTEGER);
VAR PS:PStream;
BEGIN
  PS := New(PDosStream, Init(addir + Name, stOpenRead));
  IF PS^.Status<>0 THEN BEGIN
    Dispose(PS, Done);
    PS := New(PDosStream, Init(Name, stOpenRead));
    IF PS^.Status<>0 THEN BEGIN
      Dispose(PS, Done);
      IF ResID<>0 THEN BEGIN Writeln(#13#10'Can''t read file ',name); Halt END;
      PS := NIL;
    END ELSE Writeln('Reading ', name, '...');
  END ELSE Writeln('Reading ', addir, name, '...');
  ofStream:=PS;
END;

{
  Close file opened with last OpenFile
}
PROCEDURE CloseFile;
BEGIN
  IF (ofStream<>NIL) THEN Dispose(ofStream,Done);
  ofStream:=NIL;
END;

END.
