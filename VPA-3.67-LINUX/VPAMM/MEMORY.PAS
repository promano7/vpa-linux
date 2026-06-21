{$A+,B-,D+,E+,F-,G+,I+,L+,N-,O+,R-,S-,V-,X+}
{$M 16384,0,655360}
{**************************************************************************

           U N I T   F ö R   S P E I C H E R V E R W A L T U N G

**************************************************************************}

UNIT Memory;

INTERFACE

TYPE TFreeProc=PROCEDURE(VAR P:POINTER); { Prozedur zum Freigeben von     }
                                         { Speicher                       }
     PSharedBlock=^TSharedBlock;         { ØRegistrierungsrecordÆ fÅr     }
     TSharedBlock=RECORD                 { Shared Blocks                  }
         Next:PSharedBlock;              { NÑchster Block                 }
         Where:POINTER;                  { Position des Blocks            }
         Users:WORD;                     { Anzahl der Nutzer des Blocks   }
         Proc:TFreeProc;                 { Prozedur zum Freigeben d.Blocks}
         Name:STRING[49];                { Max. 49 Zeichen Name           }
     END;

FUNCTION GetShared(Name:STRING):POINTER; { Ist Block ØNameÆ geladen?      }
                                         { Wenn ja, gib Zeiger zurÅck und }
                                         { melde Nutzer an. Wenn nein,    }
                                         { liefere NIL                    }
PROCEDURE InitBlock(Name:STRING; Where:POINTER; Proc:TFreeProc);
                                         { Melde neuen Shared-Block an    }
                                         { Proc ist die Prozedur zum Frei-}
                                         { geben des Blockes              }
PROCEDURE ReleaseBlock(Where:POINTER);   { Melde einen Nutzer ab. wenn    }
                                         { nîtig, rufe Proc(Where) auf,   }
                                         { um Block freizugeben           }

{ Wichtig: Jeder Shared-Block sollte von allen Nutzern in gleicher Weise  }
{          genutzt werden. Die Prozedur ØProcÆ zu jedem Block mu· auf den }
{          Typ des Blockes abgestimmt sein und die richtige Anzahl Bytes  }
{          freigeben. Keiner der Nutzer darf einen Shared-Block freigeben.}
{          Jeder, der einen Shared-Block nutzt, sollte folgende Code-     }
{          sequenzen verwenden:                                           }
{          Daten laden (Init):  P:=GetShared(Name);                       }
{                               IF P=NIL THEN BEGIN                       }
{                                 New(P);                                 }
{                                 ...                                     }
{                                 InitBlock(Name,P,Proc);                 }
{                               END;                                      }
{          Zum Freigeben reicht: ReleaseBlock(P)                          }
{ Achtung: Die Namen mÅssen in Gro·buchstaben Åbergeben werden, der Ver-  }
{          gleich ist case-sensitive                                      }

CONST SharedBlocks:PSharedBlock=NIL;

{$IFNDEF DPMI}
{=== Diverse Pointer-Rechenoperationen ===}
FUNCTION AddPointer(P:POINTER; W:WORD):POINTER;
FUNCTION Linear(P:POINTER):LONGINT;
FUNCTION Physical(P:POINTER):LONGINT;

{=== Der Safety-Pool ===}
FUNCTION LowMemory:BOOLEAN;
CONST SafetySize:WORD=4096 DIV 16; { 4k in Paragraphen }
{$ENDIF}

TYPE TXMSStruc=RECORD
              Length:LONGINT;
              sHandle:WORD;
              sAdr:LONGINT;
              dHandle:WORD;
              dAdr:LONGINT;
     END;

{=== XMS-Schnittstelle ===}
FUNCTION XMSDetect:BOOLEAN;     { Ist XMM installiert? }
FUNCTION XMSFree:LONGINT;       { Wieviel XMS ist frei }
FUNCTION XMSAllocate(Size:WORD):WORD; { XMS allokieren, Size in KB }
PROCEDURE XMSRelease(Handle:WORD);
PROCEDURE XMSMove(VAR XS:TXMSStruc);

CONST XMSDriver:POINTER=NIL;
      XMSVersion:WORD=0;
      SwapXMS:BOOLEAN=TRUE;     { Swapping in EMS erlaubt?                 }
      SwapEMS:BOOLEAN=TRUE;     { Swapping in XMS erlaubt?                 }

IMPLEMENTATION

{$IFNDEF DPMI}
FUNCTION AddPointer; ASSEMBLER;
ASM
        MOV     AX,WORD PTR P
        MOV     DX,WORD PTR P+2
        ADD     AX,W
        JNC     @Novf
        ADD     DX,1000h
@Novf:  END;
{$ENDIF}

FUNCTION GetShared(Name:STRING):POINTER;
VAR P:PSharedBlock;
BEGIN
  P:=SharedBlocks;
  WHILE P<>NIL DO BEGIN
    IF P^.Name=Name THEN BEGIN
      Inc(P^.Users);
      GetShared:=P^.Where;
      Exit;
    END;
    P:=P^.Next;
  END;
  GetShared:=NIL;
END;

PROCEDURE InitBlock(Name:STRING; Where:POINTER; Proc:TFreeProc);
VAR P:PSharedBlock;
BEGIN
  New(P);
  P^.Next:=SharedBlocks;
  P^.Name:=Name;
  P^.Where:=Where;
  P^.Proc:=Proc;
  P^.Users:=1;
  SharedBlocks:=P;
END;

PROCEDURE ReleaseBlock(Where:POINTER);
VAR P,Q:PSharedBlock;
BEGIN
  P:=SharedBlocks;              { Aktueller Block                         }
  Q:=NIL;                       { Block davor                             }
  WHILE P<>NIL DO BEGIN
    IF P^.Where=Where THEN BEGIN
      Dec(P^.Users);            { Ein User weniger                        }
      IF P^.Users=0 THEN BEGIN
        IF @P^.Proc<>NIL THEN P^.Proc(P^.Where);
                                { Freigeben                               }
        IF Q=NIL THEN BEGIN     { Erster Block                            }
          SharedBlocks:=P^.Next;{ Liste verketten                         }
          Dispose(P);           { freigeben                               }
        END ELSE BEGIN
          Q^.Next:=P^.Next;     { Liste verketten                         }
          Dispose(P);           { freigeben                               }
        END;
      END;
      Exit;
    END;
    Q:=P;
    P:=P^.Next;
  END;
END;

{$IFNDEF DPMI}
FUNCTION Linear; ASSEMBLER;
ASM
        MOV     AX,WORD PTR P+2
        MOV     DX,16
        MUL     DX
        ADD     AX,WORD PTR P
        ADC     DX,0
END;

FUNCTION Physical;
BEGIN
  Physical:=Linear(P);
END;

FUNCTION LowMemory;
BEGIN
  LowMemory:=(Seg(HeapEnd^)-Seg(HeapPtr^))<SafetySize;
END;
{$ENDIF}

{***************************************************************************

   X M S - S c h n i t t s t e l l e

***************************************************************************}
 
FUNCTION XMSDetect:BOOLEAN; ASSEMBLER;
ASM
{$IFNDEF DPMI}       { XMS brauchen wir in DPMI nicht }
        MOV     AX,4300h
        INT     2Fh
        CMP     AL,80h
        JNE     @NoXMS
        MOV     AX,4310h
        INT     2Fh
        MOV     WORD PTR XMSDriver[0],BX
        MOV     WORD PTR XMSDriver[2],ES
        MOV     AH,0
        CALL    XMSDriver
        MOV     XMSVersion,AX
        MOV     AL,1
        JMP     @Ende
{$ENDIF}
@NoXMS: MOV     AL,0
@Ende:  END;

FUNCTION XMSFree:LONGINT; ASSEMBLER;
ASM
{$IFNDEF DPMI}
        CMP     XMSVersion,200h
        JB      @NoXMS
        MOV     AH,8
        CALL    XMSDriver
        MOV     AX,DX
        TEST    BL,80h
        JE      @Ende
@NoXMS: XOR     AX,AX
@Ende:  MOV     DX,1024
        MUL     DX
{$ELSE}
	xor	ax,ax
	cwd
{$ENDIF}
END;

FUNCTION XMSAllocate(Size:WORD):WORD; ASSEMBLER;
ASM
{$IFNDEF DPMI}
        CMP     XMSVersion,200h
        JB      @NoXMS
        MOV     AH,9
        MOV     DX,Size
        CALL    XMSDriver
        MOV     AX,DX
        TEST    BL,80h
        JE      @Ende
{$ENDIF}
@NoXMS: XOR     AX,AX
@Ende:  END;

PROCEDURE XMSRelease(Handle:WORD); ASSEMBLER;
ASM
{$IFNDEF DPMI}
        CMP     XMSVersion,200h
        JB      @NoXMS
        MOV     AH,10
        MOV     DX,Handle
        CALL    XMSDriver
{$ENDIF}
@NoXMS: END;

PROCEDURE XMSMove(VAR XS:TXMSStruc); ASSEMBLER;
ASM
{$IFNDEF DPMI}
        CMP     XMSVersion,200h
        JB      @NoXMS
        PUSH    DS
        PUSH    DS
        POP     ES
        MOV     AH,11
        LDS     SI,XS
        CALL    ES:XMSDriver
        POP     DS
{$ENDIF}
@NoXMS: END;

END.
