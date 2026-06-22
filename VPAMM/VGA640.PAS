{$A+,B-,D+,E+,F-,G+,I+,L+,N-,O+,R-,S-,V-,X+}
{**************************************************************************

                   U N I T   M I T   V G A - T R E I B E R

**************************************************************************}

UNIT VGA640;

INTERFACE

USES Drivers;

{=== Modi ===}

CONST VGA200=$0E;    { 640 x 200, 16 Farben (EGA) }
      VGA350=$10;    { 640 x 350, 16 Farben (EGA) }
      VGA480=$12;    { 640 x 480, 16 Farben (VGA) }

{=== Hilfs"variable" ===}
{     VGASeg:WORD=$A000; }

{=== Treiberobjekt ===}

TYPE PVGA=^TVGA;
     TVGA=OBJECT(TGraph)
            CONSTRUCTOR Init(AMode:BYTE);
            DESTRUCTOR Done; VIRTUAL;
            PROCEDURE PutPixel(X,Y:INTEGER; C,Op:BYTE); VIRTUAL;
            PROCEDURE HLine(X1,Y1,X2:INTEGER; Mask,C,Op:BYTE); VIRTUAL;
            PROCEDURE VLine(X1,Y1,Y2:INTEGER; Mask,C,Op:BYTE); VIRTUAL;
            PROCEDURE Bar(X1,Y1,X2,Y2:INTEGER; Patt:TPattern; C,Op:BYTE);
                                                                     VIRTUAL;
            PROCEDURE ResetVideo; VIRTUAL;
            PROCEDURE PutBitMap(X1,Y1,X2,Y2:INTEGER; VWidth:INTEGER; VAR Map;
                                                    C,Back,Op:BYTE); VIRTUAL;
{            PROCEDURE PutPattern(X1div8,Y1,X2div8,Y2:INTEGER; VWidth:INTEGER;
                                                VAR Map; C,Op:BYTE); VIRTUAL;
            PROCEDURE ClearScreen; VIRTUAL;
            FUNCTION GetPixel(X,Y:INTEGER):BYTE; VIRTUAL;}
     END;

{*************************************************************************}

IMPLEMENTATION

USES SysExt;

{**************************************************************************

   M e t h o d e n   v o n   T V G A

**************************************************************************}

CONSTRUCTOR TVGA.Init;            { Initialisiert den Treiber, wenn kein  }
BEGIN                             { VGA-Modus angegeben war: FAIL         }
  CASE AMode OF
    VGA200, VGA350, VGA480: TGraph.Init(AMode);
  ELSE Fail;
  END;
END;

DESTRUCTOR TVGA.Done;             { Gibt das Objekt frei und schaltet in  }
BEGIN                             { den originalen Videomodus zurÅck      }
  TGraph.Done;
END;

PROCEDURE TVGA.PutPixel;          { Setzt ein Pixel Åber OUT, nicht Åber  }
                     ASSEMBLER;   { das langsame BIOS                     }
ASM
    PUSHF
    {CLI}
    MOV   ES,SegA000
    MOV   AX,Y
    MOV   BX,AX
    SHL   AX,2                    { Y * 4  ...  }
    ADD   AX,BX                   { + Y = Y * 5 }
    SHL   AX,4                    { Y * 5 * 16 = Y * 80 }
    MOV   BX,X
    MOV   DX,BX
    SHR   BX,3                    { X / 8 ... }
    ADD   BX,AX                   { + Y * 80 }
    AND   DL,7
    MOV   CL,DL                   { Zustand: BX = Adresse, CL = Shifts, }
    MOV   DX,03CEH                {          DX = Port                  }
    MOV   AL,ES:[BX]              { Latchregs. laden }
    MOV   AX,8008H                { Register 8 = Maske }
    SHR   AH,CL                   { Maske schieben }
    OUT   DX,AX
    MOV   AX,0205H                { Register 5 = Modus }
    OUT   DX,AX
    MOV   AH,Op
    MOV   CL,3
    AND   AH,CL
    SHL   AH,CL
    MOV   AL,CL                   { Register 3 = Rotieren/VerknÅpfung }
    OUT   DX,AX
    MOV   AL,C
    MOV   ES:[BX],AL              { Farbe schreiben }
    POPF
END;

PROCEDURE TVGA.Bar;
VAR MaskL,MaskR:BYTE;
    Adr:WORD;
    Len:WORD;
LABEL Ende;
BEGIN
  ASM
    PUSHF
    {CLI}
    MOV   ES,SegA000
    MOV   AX,Y1
    MOV   SI,AX
    AND   SI,7                    { SI = Index in das Muster }
    SHL   AX,4
    MOV   BX,AX
    SHL   AX,2
    ADD   BX,AX
    MOV   AX,X1
    SHR   AX,3
    MOV   DX,X2
    SHR   DX,3
    ADD   BX,AX
    MOV   Adr,BX                  { Adresse eingestellt }
    SUB   DX,AX
    JBE   @UseOld                 { Balken zu schmal }
    DEC   DX
    MOV   Len,DX                  { LÑnge OK }
    MOV   AX,0FFFFH
    MOV   CL,BYTE PTR X1
    AND   CL,7
    SHR   AH,CL
    MOV   MaskL,AH
    MOV   CL,BYTE PTR X2
    AND   CL,7
    XOR   CL,7
    MOV   AL,0FFH
    SHL   AL,CL
    MOV   MaskR,AL                { Masken OK }
    MOV   DX,03CEH
    MOV   AX,0005H                { Modus 0 }
    OUT   DX,AX
    MOV   AX,0F01H                { Alle Bits der Farbe beachten }
    OUT   DX,AX
    MOV   AH,C
    MOV   AL,00H                  { Farbe }
    OUT   DX,AX
    MOV   CL,3
    MOV   AH,Op
    SHL   AH,CL
    MOV   AL,3                    { Operation }
    OUT   DX,AX
  @Schleife:
    MOV   BX,Y1
    CMP   BX,Y2
    JA    Ende
    MOV   DI,Adr
    MOV   BL,BYTE PTR Patt[SI]    { Hole Muster nach BL }
    MOV   AH,MaskL
    MOV   AL,8
    AND   AH,BL                   { Muster links }
    OUT   DX,AX
    MOV   AL,ES:[DI]
    MOV   ES:[DI],AL
    INC   DI
    MOV   CX,Len
    JCXZ  @Nix
    MOV   AH,BL
    MOV   AL,8
    OUT   DX,AX
  @Loop:
    MOV   AL,ES:[DI]
    MOV   ES:[DI],AL
    INC   DI
    LOOP  @Loop
  @Nix:
    MOV   AH,BL
    AND   AH,MaskR
    MOV   AL,8
    OUT   DX,AX                   { Muster rechts }
    MOV   AL,ES:[DI]
    MOV   ES:[DI],AL
    ADD   Adr,80
    INC   Y1
    INC   SI
    AND   SI,7
    JMP   @Schleife
  @UseOld:
  END;
  TGraph.Bar(X1,Y1,X2,Y2,Patt,C,Op);
  Ende:
  ASM
    POPF
  END;
END;

PROCEDURE TVGA.VLine; ASSEMBLER;
ASM
    PUSHF
    {CLI}
    MOV   ES,SegA000
    MOV   AX,Y1
    MOV   BX,AX
    SHL   AX,2                    { Y * 4  ...  }
    ADD   AX,BX                   { + Y = Y * 5 }
    SHL   AX,4                    { Y * 5 * 16 = Y * 80 }
    MOV   BX,X1
    MOV   CX,BX
    SHR   BX,3                    { X / 8 ... }
    ADD   BX,AX                   { + Y * 80 }
    AND   CL,7                    { Zustand: BX = Adresse, CL = Shifts, }
    MOV   DX,03CEH                {          DX = Port                  }
    MOV   AX,8008H                { Register 8 = Maske }
    SHR   AH,CL                   { Maske schieben }
    OUT   DX,AX
    MOV   AX,0205H                { Register 5 = Modus }
    OUT   DX,AX
    MOV   AH,Op
    AND   AH,3
    SHL   AH,3
    MOV   AL,3                    { Register 3 = Rotieren/VerknÅpfung }
    OUT   DX,AX
    MOV   AL,C
    MOV   CX,Y1
    MOV   DX,Y2
  @Loop:
    CMP   CX,DX
    JA    @Ende
    MOV   AH,Mask
    PUSH  CX
    AND   CL,7
{   SHR   AH,CL
    AND   AH,1
    JZ    @Nixlos }
    SHL AH,CL
    TEST AH, 80H
    JZ @nixlos
    MOV   AH,ES:[BX]              { Latchregs. laden }
    MOV   ES:[BX],AL              { Farbe schreiben }
  @NixLos:
    POP   CX
    ADD   BX,80
    INC   CX
    JMP   @Loop
  @Ende:
    POPF
END;

PROCEDURE TVGA.HLine;
VAR Patt:TPattern;
BEGIN
  ASM
        mov     al, mask
        mov     di, y1
        and     di, 7
        mov     patt.byte[di], al
{       mov     ah, al
        mov     patt.word, ax
        mov     patt.word.2, ax
        mov     patt.word.4, ax
        mov     patt.word.6, ax }
  END;
{ FillChar(Patt,8,Mask); }
  Bar(X1,Y1,X2,Y1,Patt,C,Op);
END;

PROCEDURE TVGA.ResetVideo; ASSEMBLER;
ASM
  PUSHF
  CLI
  MOV   DX,03CEH
  MOV   AX,0FF08H    { Maske = alle Bits }
  OUT   DX,AX
  MOV   AX,0005H     { R/W-Mode 0 }
  OUT   DX,AX
  MOV   AX,0003H     { Operation MOV }
  OUT   DX,AX
  MOV   AX,0000H     { keine Plane selektiert }
  OUT   DX,AX
  MOV   AX,0001H     { keine Plane freigegeben }
  OUT   DX,AX
  POPF
END;

PROCEDURE TVGA.PutBitMap(X1,Y1,X2,Y2:INTEGER; VWidth:INTEGER; VAR Map;
                                   C,Back,Op:BYTE); ASSEMBLER;
ASM
  {CLI}
  PUSH  DS
  mov es, SegA000
  LDS   SI,Map          { Register: AX=Akku  DI=BS-Adr, DS:SI=Map }
                        {           DX=Port  CX=Spaltenzahl  BL=Bitpos }
  MOV   AX,Y1
  SHL   AX,4            { AX := 16 * Y }
  MOV   DI,AX
  SHL   AX,2
  ADD   DI,AX           { DI := 80 * Y }
  MOV   AX,X1
  SHR   AX,3
  ADD   DI,AX
  MOV   CX,X1
  AND   CL,7
  MOV   BL,80h
  SHR   BL,CL
  MOV   CX,X2
  INC   CX
  SUB   CX,X1
  MOV   DX,3CEh
  MOV   AH,Op
  AND   AH,3
  SHL   AH,3
  MOV   AL,3                    { Register 3 = Rotieren/VerknÅpfung }
  OUT   DX,AX
  MOV   AX,0205h
  OUT   DX,AX
  CLD
@Schleife:
  PUSH  SI
  PUSH  DI
  PUSH  BX
  PUSH  CX
@Zeile:
  MOV   AL,8
  MOV   AH,BL    { ein Bit }
  OUT   DX,AX
  LODSB
  CMP   AL,C
  JE    @Keinpixel
  CMP   AL,0
  JNE   @OKay
  MOV   AL,Back
@OKay:
  MOV   AH,ES:[DI]
  MOV   ES:[DI],AL
@Keinpixel:
  ROR   BL,1
  ADC   DI,0
  LOOP  @Zeile
  POP   CX
  POP   BX
  POP   DI
  POP   SI
  ADD   DI,80
  ADD   SI,VWidth
  INC   Y1
  MOV   AX,Y2
  CMP   Y1,AX
  JNA   @Schleife
  POP   DS
  STI
END;

END.
