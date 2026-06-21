{$A+,B-,D+,E+,F-,G+,I+,L+,N-,O+,R-,S-,V-,X+}
{$M 16384,0,655360}
{***************************************************************************

                         B A S I S O B J E K T E

                I N T E R - U N I - A L L E S - M A K E R

***************************************************************************}

{--------------------- ProzedÅrchen fÅr alle FÑlle ------------------------}

{$DEFINE NO_ASM_VMT_CALLS}

UNIT Objects;

INTERFACE

CONST msgAbstract='Objects: Call to abstract method.'#13#10;
      msgRegError='Objects: Bad object data.'#13#10;
      msgNoIni='Objects: USER.INI not found.'#13#10;

{=== Nicht-Objekt-Typen ===}
TYPE PStreamRec=^TStreamRec;
     TStreamRec=RECORD          { Registrierungsrecord fÅr Objekte         }
       ObjType:WORD;            { Identifikationsnummer                    }
       VmtLink:WORD;            { VMT-Offset                               }
       Load:POINTER;            { LOAD-CONSTRUCTOR                         }
       Store:POINTER;           { STORE-Prozedur                           }
       Next:WORD;               { Verkettete Listen...                     }
     END;

     PResource=^TResource;
     TRezItemName=STRING[31];
     TResourceName=ARRAY[0..15] OF CHAR;
     PResourceName=^TREsourceName;

     PString=^STRING;

     PResourceRec=^TResourceRec;
     TResourceRec=RECORD        { Registrierungsrecord fÅr Ressourcen      }
       Next:PResourceRec;       { Verkettete Liste...                      }
       Ident:TResourceName;     { Ressourcename fÅr Referenzen...          }
       Typ:WORD;                { 0=open, 1=closed                         }
       Link:PResource;          { Verbundene Ressource                     }
       Name:PString;
     END;

{=== Typen fÅr Ressource-Inhalte ===}
     TVersionInfo=RECORD        { VERSIONINFO_SYSTEM - Struktur            }
       Date:ARRAY[0..7] OF CHAR;
       Version:ARRAY[0..3] OF CHAR;
       Language:ARRAY[0..7] OF CHAR;
       RezID:TResourceName;
       Fill:ARRAY[0..27] OF BYTE;
     END;

     TResourceHeader=RECORD
       Ident:ARRAY[0..7] OF CHAR; { Kennung ØSF___REZÆ                     }
       Typ:WORD;                { Typ: 1=Daten 2=Dialoge 0=unspec          }
       CRC:WORD;                { PrÅfsumme                                }
       HeaderSize:LONGINT;      { Grî·e des Headers (i.A. 64)              }
       GNTSize:WORD;
       GNTPos:LONGINT;
       Comment:ARRAY[0..41] OF CHAR;
     END;

     PRezIndex=^TRezIndex;
     TRezIndex=RECORD           { Struktur eines Ressourcen-Index', nur im }
       Name:TRezItemName;       { Speicher, nicht im Stream                }
       Pos:LONGINT;
       Next:PRezIndex;
       CASE INTEGER OF
         0:(Typ:WORD);
         1:(Len:LONGINT);
     END;

{=== Hilfstypen ===}

     PByte=^BYTE;               { Zeiger auf Typen fÅr div. Operationen    }
     PWord=^WORD;
     PBoolean=^BOOLEAN;

     PDWordList=^TDWordList;    { Liste aus je 2 Worten                    }
     TDWordList=RECORD
        Next:PDWordList;
        CASE INTEGER OF
          0:(Word1,Word2:WORD);
          1:(Long:LONGINT);
     END;

     TPointer=RECORD            { Typumwandlung eines Zeigers              }
       Offset,Segment:WORD;
     END;

     TByteArray=ARRAY[0..64000] OF BYTE;
     TWordArray=ARRAY[0..32000] OF WORD;
     TPtrArray=ARRAY[0..16000] OF POINTER;

     PByteArray=^TByteArray;    { Inter-Uni-Alles-Typen zur Bearbeitung    }
     PPtrArray=^TPtrArray;      { von Speicherbereichen                    }
     PWordArray=^TWordArray;

     PGNTEntry=^TGNTEntry;
     TGNTEntry=RECORD
         Typ:WORD;              { 1=Class, 2=Object, 3=Resource }
         Name:STRING;
     END;

{=== Basisobjekt ===}
     PObject=^TObject;
     TObject=OBJECT             { VMT-Feld = erste Variable               }
            CONSTRUCTOR Init;
            DESTRUCTOR Done; VIRTUAL;
     END;

     PStream=^TStream;

{=== Prozedur fÅr ØWriteRefÆ ===}
     TPutProc=PROCEDURE(S:PStream; VAR P:POINTER);
     TGetProc=PROCEDURE(S:PStream; VAR P:POINTER);

{=== Datenstrom ===}
     TStream=OBJECT(TObject)
            Link:PResource;
            Status,ErrorInfo:WORD;
            CONSTRUCTOR Init;
            FUNCTION PRead(VAR Buf; Size:WORD):WORD; VIRTUAL;
            FUNCTION PWrite(VAR Buf; Size:WORD):WORD; VIRTUAL;
            PROCEDURE Read(VAR Buf; Size:WORD);
            PROCEDURE Write(VAR Buf; Size:WORD);
            PROCEDURE Put(P:PObject);
            PROCEDURE Error(AState,AErrorInfo:WORD); VIRTUAL;
            PROCEDURE Reset;
            PROCEDURE Seek(APos:LONGINT); VIRTUAL;
            PROCEDURE Truncate; VIRTUAL;
            PROCEDURE WriteStr(S:STRING);
            PROCEDURE WriteRef(VAR P:POINTER; PP:TPutProc);
            PROCEDURE GetRef(VAR P:POINTER; PP:TGetProc);
            PROCEDURE CopyFrom(VAR S:TStream; Size:LONGINT);
            FUNCTION ReadStr:STRING;
            FUNCTION HandleCommand(A:WORD):PObject; VIRTUAL;
            FUNCTION Get:PObject;
            FUNCTION GetObject(A:WORD):PObject;
            FUNCTION GetPos:LONGINT; VIRTUAL;
            FUNCTION GetSize:LONGINT; VIRTUAL;
     END;
{=== Strîme auf Disketten - DOS-Stream ===}
     PDosStream=^TDosStream;
     TDosStream=OBJECT(TStream)
            Handle:WORD;
            CONSTRUCTOR Init(FileName:STRING; Mode:WORD);
            DESTRUCTOR Done; VIRTUAL;
            FUNCTION GetPos:LONGINT; VIRTUAL;
            FUNCTION GetSize:LONGINT; VIRTUAL;
            FUNCTION PRead(VAR Buf; Count:WORD):WORD; VIRTUAL;
            {PROCEDURE Read(VAR Buf; Count:WORD); VIRTUAL;}
            PROCEDURE Seek(Pos:LONGINT); VIRTUAL;
            PROCEDURE Truncate; VIRTUAL;
            FUNCTION PWrite(VAR Buf; Count:WORD):WORD; VIRTUAL;
            {PROCEDURE Write(VAR Buf; Count:WORD); VIRTUAL;}
          END;
{=== Datenstrom im Speicher ===}
     PMemoryStream=^TMemoryStream;
     TMemoryStream=OBJECT(TStream)
            Size,Pos:LONGINT;
            Field:POINTER;
            FieldSize:WORD;
            CONSTRUCTOR Init(aSize:LONGINT);
            DESTRUCTOR Done; VIRTUAL;
            {PROCEDURE Read(VAR Buf; aSize:WORD); VIRTUAL;
            PROCEDURE Write(VAR Buf; aSize:WORD); VIRTUAL;}
            FUNCTION PRead(VAR Buf; aSize:WORD):WORD; VIRTUAL;
            FUNCTION PWrite(VAR Buf; aSize:WORD):WORD; VIRTUAL;
            PROCEDURE Seek(APos:LONGINT); VIRTUAL;
            PROCEDURE Truncate; VIRTUAL;
            FUNCTION GetPos:LONGINT; VIRTUAL;
            FUNCTION GetSize:LONGINT; VIRTUAL;
     END;

{=== Datenstrom im XMS-Speicher ===}
     PXMSStream=^TXMSStream;
     TXMSStream=OBJECT(TStream)
            Handle:WORD;
            Pos,Size:LONGINT;
            CONSTRUCTOR Init(aSize:LONGINT);
            DESTRUCTOR Done; VIRTUAL;
            {PROCEDURE Read(VAR Buf; aSize:WORD); VIRTUAL;
            PROCEDURE Write(VAR Buf; aSize:WORD); VIRTUAL;}
            FUNCTION PRead(VAR Buf; aSize:WORD):WORD; VIRTUAL;
            FUNCTION PWrite(VAR Buf; aSize:WORD):WORD; VIRTUAL;
            PROCEDURE Seek(APos:LONGINT); VIRTUAL;
            PROCEDURE Truncate; VIRTUAL;
            FUNCTION GetPos:LONGINT; VIRTUAL;
            FUNCTION GetSize:LONGINT; VIRTUAL;
     END;

{=== High-End-Streams: 2D-indizierte Ressource ===}
     TResource=OBJECT(TObject)
            Status:WORD;            { Fehlercode                            }
            SomeStream:PStream;     { Jemand fÅr die Dreckarbeit            }
            Header:TResourceHeader; { Header fÅr schnellen Zugriff          }
            Index:PRezIndex;        { Index der Klassen                     }
            CurIndex:PRezIndex;     { Index der Objekte in aktueller Klasse }
            CurName:TRezItemName;   { Aktuelle Klasse                       }
            MyName:TResourceName;   { Mein Name ist...                      }
            GNT:POINTER;            { Global Names Table                    }
            CONSTRUCTOR Init(S:PStream);
            DESTRUCTOR Done; VIRTUAL;
            PROCEDURE BuildIndex;   { Index aufbauen                        }
            PROCEDURE LoadGNT;      { Global Names Table laden              }
            PROCEDURE FreeIndex;    { Index lîschen (beide Indizes)         }
            PROCEDURE SeekClass(S:STRING); { Gehe zu Klasse ØSÆ             }
            PROCEDURE Seek(AClass,AnObject:TRezItemName);
            PROCEDURE GetRef(RefType:BYTE; VAR P:POINTER; PP:TGetProc);
                 VIRTUAL;           { Es gibt keine Hilfe, nur Querverweise }
            FUNCTION Get(AClass,AnObject:TRezItemName):PObject;
                                 { Der Lebenszweck von Ressourcen - Objekte }
            FUNCTION HandleCommand(A:WORD):PObject;
     END;

{=== "Hilfs"prozeduren ===}
PROCEDURE RegisterType(VAR R:TStreamRec);
PROCEDURE RegisterRez(P:PResource; N:TResourceName);
PROCEDURE FreeRez(N:TResourceName);
PROCEDURE Abstract;
PROCEDURE RegisterError;
PROCEDURE Print(S:STRING);
FUNCTION UpStr(S:STRING):STRING;
FUNCTION IsTrue(S:STRING):BOOLEAN;
FUNCTION IsFalse(S:STRING):BOOLEAN;
FUNCTION GetRezPtr(S:TRezItemName):PResource;

{=== Ressourcen-Verwaltung ===}
PROCEDURE AddLink(ID:TResourceName; FN:STRING);
FUNCTION LoadRez(S:STRING):PResource;
PROCEDURE InitObjects;
PROCEDURE DoneObjects;
FUNCTION RSeek(ARez,AClass,AnObject:TRezItemName):PResource;
FUNCTION RGet(ARez,AClass,AnObject:TRezItemName):PObject;

{=== Variablen & mehr ===}
CONST StreamTypes:WORD=0;       { Registrieren Sie hier!                   }
      StreamError:POINTER=NIL;  { Extra-Stream-Fehlerbehandlungsroutine    }

CONST RezRegister:BOOLEAN=TRUE; { Registrieren Ressourcen sich selber?     }
      RezList:PResourceRec=NIL; { Registrierte Ressourcen                  }
CONST RezIdent:ARRAY[0..7] OF CHAR='SF___REZ'; { Ressourcen-Kennbytes      }

CONST Numbers:ARRAY[0..9] OF BYTE=(0,1,2,3,4,5,6,7,8,9);

CONST WriteRef:POINTER=NIL;     { Parameter: VAR S:TStream; VAR P:POINTER; }
                                { PP:TPutProc)                             }

CONST LoadRezProc:POINTER=NIL;  { Resource laden, wenn nicht registriert   }
                                { Parameter: VAR N:TResourceName           }
                                { Ergebnis: PResource                      }

CONST LastName:STRING='';       { Letzter Name aus Ressource               }
                                { Damit ØGetRefÆ-Objekte mitkriegen, wie   }
                                { sie hei·en                               }

CONST XMSFreeOnRun:LONGINT=0;

(*    TStream_Read=8;           { VMT-Offsets fÅr die entspr. Routinen...  }
      TStream_Write=12; *)
{$IFNDEF NO_ASM_VMT_CALLS}
  {$IFDEF VER60}
      TStream_Error=16;
  {$ENDIF}
  {$IFDEF VER70}
      TStream_Error=20;
  {$ENDIF}
{$ENDIF}

{=== Stream-Fehlercodes ===}
      stOK=0;                   { Kein Fehler                              }
      stPutError=1;             { Unregistriertes Objekt                   }
      stGetError=2;             { -"- oder falscher Befehl                 }
      stSeekError=3;            { Seek Åber Ende hinaus                    }
      stReadError=4;            { Dateiende                                }
      stWriteError=5;           { Diskette voll                            }
      stInitError=6;            { Datei kann nicht angelegt werden         }
      stError=7;                { generischer Fehler                       }

{=== Ressourcen-Fehler ===}
      rezOK=0;                  { Kein Fehler                              }
      rezClassNotFound=1;       { Klasse nicht gefunden                    }
      rezObjectNotFound=2;      { Objekt nicht gefunden                    }
      rezInitError=3;           { Kann Name nicht ermitteln                }
                                {               (VERSIONINFO_SYSTEM fehlt) }
      rezIndexError=4;          { Ressource hat fehlerhaften Index         }

{=== TDosStream-Zugriffsmodi ===}
      stCreate=$3C00;           { Datei anlegen                            }
      stOpenRead=$3D00;         { Nur lesen                                }
      stOpenWrite=$3D01;        { Nur schreiben                            }
      stOpen=$3D02;             { Wahlfreier Zugriff                       }

{**************************************************************************}

VAR IniFile:TDosStream;

CONST IniLoaded:BOOLEAN=FALSE;

FUNCTION StreamOK(PS:PStream):BOOLEAN;

{**************************************************************************}

IMPLEMENTATION

USES Memory,DOS;

{=== Armer Irrer macht die Dreckarbeit: ===}
PROCEDURE DoRead(VAR S:TStream; VAR P:POINTER; PP:TGetProc); ASSEMBLER;
ASM
  PUSH   WORD PTR S[2]
  PUSH   WORD PTR S[0]
  PUSH   WORD PTR P[2]
  PUSH   WORD PTR P[0]
  CALL   DWORD PTR PP
END;

{***************************************************************************

   " M e t h o d e n "   v o n   T O b j e c t

***************************************************************************}

CONSTRUCTOR TObject.Init;       { Initialisiert ein Objekt und lîscht alle }
TYPE Image=RECORD               { Felder                                   }
       VMTLink:WORD;            { VMT-Feld nicht lîschen!!!                }
       Data:RECORD END;         { Daten des Erben                          }
     END;
BEGIN { (c) Borland }
  FillChar(Image(Self).Data,SizeOf(Self)-SizeOf(TObject),0);
END;

DESTRUCTOR TObject.Done;        { Virtuelle Methode erzwingt Anlage einer  }
BEGIN                           { VMT                                      }
END;

{***************************************************************************

    M e t h o d e n   v o n   T S t r e a m

***************************************************************************}

{$IFDEF NO_ASM_VMT_CALLS}
PROCEDURE DoStreamError(a, b:INTEGER; VAR s:TStream);
BEGIN
  s.Error(a, b);
END;
{$ENDIF}

CONSTRUCTOR TStream.Init;       { Initialisiert den Datenstrom und lîscht  }
BEGIN                           { die Verbindung zu einer eventuellen      }
  TObject.Init;                 { Ressource.                               }
  Link:=NIL;
END;

PROCEDURE TStream.Read;
BEGIN
  IF PRead(Buf, Size)<>Size THEN BEGIN
    FillChar(Buf, Size, 0);
    IF Status=0 THEN Error(stReadError, 0);
  END;
END;

PROCEDURE TStream.Write;
BEGIN
  IF PWrite(Buf, Size)<>Size THEN BEGIN
    IF Status=0 THEN Error(stWriteError, 0);
  END;
END;

FUNCTION TStream.PRead;         { Liest ØSizeÆ Bytes aus dem Stream in den }
BEGIN                           { Puffer ØBufÆ.                            }
  Abstract;
END;

FUNCTION TStream.PWrite;        { Schreibt ØSizeÆ Bytes aus ØBufÆ in den   }
BEGIN                           { Stream                                   }
  Abstract;
END;

PROCEDURE TStream.Put; ASSEMBLER; { Schreibt polymorphe Daten (Objekte)    }
ASM
  LES   DI,P                    { Hole Adresse von Objekt                  }
  MOV   DX,ES
  OR    DX,DI                   { NIL?                                     }
  JZ    @WriteNIL
  MOV   AX,ES:[DI]              { Hole VMT-Feld                            }
  MOV   BX,StreamTypes
 @Loop:
  OR    BX,BX                   { Kein Objekt registriert?                 }
  JZ    @Nix                    { Dann auch keins schreiben                }
  CMP   AX,TStreamRec([BX]).VMTLink
  JE    @Juchu                  { Gefunden !!!                             }
  MOV   BX,TStreamRec([BX]).Next
  JMP   @Loop                   { DÑr nÑchstÑ bittÑ                        }
 @Nix:                          { So'n Mist. Unbekanntes Flug-Objekt       }
  MOV   BX,stPutError
  PUSH  BX
  PUSH  AX                      { AX ist Typeof(P^)                        }
  LES   DI,Self
  PUSH  ES
  PUSH  DI                      { Fehler behandeln wir selber              }
{$IFDEF NO_ASM_VMT_CALLS}
  call  DoStreamError
{$ELSE}
  MOV   DI,ES:[DI]              { Wo ist denn unser Error?                 }
  CALL  DWORD PTR [DI+TStream_Error]
{$ENDIF}
  JMP   @Ende
 @Juchu:
  MOV   DX,TStreamRec([BX]).ObjType
 @WriteNIL:
  PUSH  BX                      { BX sichern                               }
  PUSH  DX                      { Wir schreiben DX ...                     }
  MOV   AX,SP
  PUSH  SS                      { ...das steht an SS:SP...                 }
  PUSH  AX
  MOV   AX,2                    { ...und ist immer noch 2 Byte gro·...     }
  PUSH  AX
  LES   DI,Self
  PUSH  ES
  PUSH  DI                      { ...und wir schreiben es selber...        }
(*MOV   DI,ES:[DI]              { ...(jo wer sind wir denn)...             }*)
(*CALL  DWORD PTR [DI+TStream_Write] { ...Write macht die Drecksarbeit     }*)
  call  TStream.Write
  POP   DX                      { Hoffentlich geschrieben...               }
  POP   BX                      { In BX steht normalerweise ein Zeiger...  }
  OR    DX,DX
  JZ    @Ende                   { Oder auch nicht                          }
  PUSH  Self[2].WORD
  PUSH  Self[0].WORD            { ICH bin hier der Stream...               }
  PUSH  P[2].WORD
  PUSH  P[0].WORD               { ...und DU das Objekt...                  }
  CALL  DWORD PTR TStreamRec([BX]).Store { ...also mach DU den Dreck...    }
 @Ende:
END;

PROCEDURE TStream.Error;        { Im Falle eines Fehlers...                }
TYPE StreamErrorProc=PROCEDURE(S:PStream);
BEGIN
  Status:=AState;
  ErrorInfo:=AErrorInfo;
  IF StreamError<>NIL THEN StreamErrorProc(StreamError)(@Self);
END;

FUNCTION TStream.HandleCommand; { Wird von ØGetÆ aufgerufen, wenn im       }
BEGIN                           { Stream ein Befehl (Verweis) steht        }
  IF Link<>NIL THEN HandleCommand:=Link^.HandleCommand(A);
END;

FUNCTION TStream.Get;           { Lesen Polymorpher Daten & Unterscheidung }
VAR V:WORD;                     { der Befehle                              }
BEGIN
  Read(V,2);                    { Lies ID...                               }
  IF V=0 THEN
    Get:=NIL                    { NULL hei·t NIL...                        }
  ELSE BEGIN
    IF V<=1000 THEN             { 1..1000 sind Befehle                     }
      Get:=HandleCommand(V)
    ELSE                        { ...und der Rest Objekte                  }
      Get:=GetObject(V);
  END;
END;

FUNCTION TStream.GetObject;     { Liest das Objekt mit der Nummer ØaÆ aus  }
                   ASSEMBLER;   { dem Stream.                              }
ASM
  MOV   AX,A                    { Wen haben wir denn da?                   }
  MOV   BX,StreamTypes          { Hoffentlich registiert...                }
 @Loop:
  OR    BX,BX
  JZ    @NotRegistered          { nicht registriert - zur Strafe ERROR     }
  CMP   AX,TStreamRec([BX]).ObjType
  JE    @Found                  { Gefunden!!!                              }
  MOV   BX,TStreamRec([BX]).Next
  JMP   @Loop                   { Noch einmal das schîne Spiel...          }
 @Notregistered:
  MOV   BX,stGetError
  PUSH  BX
  PUSH  AX                      { AX ist ObjType des Bîsewichtes           }
  LES   DI,Self
  PUSH  ES
  PUSH  DI                      { Self=ich selber                          }
{$IFDEF NO_ASM_VMT_CALLS}
  call  DoStreamError
{$ELSE}
  MOV   DI,ES:[DI]              { wo ist meine VMT?                        }
  CALL  DWORD PTR [DI+TStream_Error]
{$ENDIF}
  XOR   AX,AX
  MOV   DX,AX                   { NIL zurÅckgeben                          }
  JMP   @Ende
 @Found:
  LES   DI,Self                 { Self=der Stream                          }
  PUSH  ES
  PUSH  DI
  PUSH  TStreamRec([BX]).VMTLink { VMT-Parameter fÅr LOAD                  }
  XOR   AX,AX
  PUSH  AX
  PUSH  AX                      { NIL=Selber initialisieren                }
  CALL  DWORD PTR TStreamRec([BX]).Load
 @Ende:
END;

PROCEDURE TStream.Reset;        { Lîscht eventuelle Fehler                 }
BEGIN
  Status:=0;
  ErrorInfo:=0;
END;

PROCEDURE TStream.Seek;         { Geht zu bestimmter (Datei-)Position      }
BEGIN
  Abstract;
END;

PROCEDURE TStream.Truncate;     { Schneidet (Datei) an aktueller Position  }
BEGIN                           { ab                                       }
  Abstract;
END;

PROCEDURE TStream.WriteStr;     { Schreibt eine Zeichenkette in den Stream }
BEGIN
  Write(S,Length(S)+WORD(1));
END;

PROCEDURE TStream.WriteRef;     { Schreibt eine Referenz in einen Stream:  }
BEGIN                           { Daten folgen, Prozedur kennt Referenz-   }
  IF P<>NIL THEN BEGIN          { werte oder NIL-Objekt                    }
    Write(Numbers[0],1);        { 0 = Daten folgen                         }
    PP(@Self,P);
  END ELSE BEGIN
    IF Objects.WriteRef<>NIL THEN BEGIN
      ASM
        PUSH   WORD PTR Self[2]
        PUSH   WORD PTR Self[0]
        PUSH   WORD PTR P[2]    { Das hier entspricht WriteRef(@Self,P,PP) }
        PUSH   WORD PTR P[0]
        PUSH   WORD PTR PP[2]
        PUSH   WORD PTR PP[0]
        CALL   DWORD PTR Objects.WriteRef
      END;
    END ELSE
      Write(Numbers[4],1);      { 4 = NIL-Object                           }
  END;
END;

PROCEDURE TStream.GetRef;       { Holt Referenz: Daten folgen, NIL-Objekt  }
VAR B:BYTE;                     { oder Ressource kennt Position            }
BEGIN
  Read(B,1);
  CASE B OF
    0:DoRead(Self,P,PP);
    4:P:=NIL;
  ELSE
    IF Link<>NIL THEN
      Link^.GetRef(B,P,PP)
    ELSE BEGIN                  { FD FE FF = Verweis aus GNT }
      P:=NIL;                   { Ohne verbundene Ressource->kein Verweis  }
      CASE B OF                 { aber Daten Åberlesen                     }
        2:BEGIN
          ReadStr;ReadStr; {˙˙˘ Verweis mit Class/Object }
        END;
        3:BEGIN
          ReadStr;ReadStr;ReadStr; {˙˙˘ Verweis mit ID/Class/Object }
        END;
      END;
    END;
  END;
END;

PROCEDURE TStream.CopyFrom;
VAR P:POINTER;
    N,M:LONGINT;
BEGIN
  N:=MaxAvail;
  IF N>32768 THEN N:=32768;
  GetMem(P,N);
  WHILE Size<>0 DO BEGIN
    IF Size>N THEN M:=N ELSE M:=Size;
    Dec(Size,M);
    S.Read(P^,M);
    Write(P^,M);
  END;
  FreeMem(P,N);
END;

FUNCTION TStream.ReadStr;       { Liest eine Zeichenkette                  }
VAR S:STRING;
BEGIN
  Read(S[0],1);
  IF S[0]<>#0 THEN Read(S[1],BYTE(S[0]));
  ReadStr:=S;
END;

FUNCTION TStream.GetPos;        { Holt die aktuelle Position im Stream     }
BEGIN
  Abstract;
END;

FUNCTION TStream.GetSize;       { Holt die Grî·e des Stream                }
BEGIN
  Abstract;
END;

{***************************************************************************

    M e t h o d e n   v o n   T D o s S t r e a m

(c) BorlÑnd InternÑtionÑl Inc.
***************************************************************************}
CONSTRUCTOR TDosStream.Init; ASSEMBLER;
VAR NameBuf:ARRAY[0..79] OF CHAR;
ASM
        XOR     AX,AX
        PUSH    AX              { Bin schon initialisiert...               }
        LES     DI,Self
        PUSH    ES
        PUSH    DI
        CALL    TStream.Init    { Nur noch Variablen setzen                }
        PUSH    DS
        LDS     SI,FileName     { Dateiname in 0-terminierten String um-   }
        LEA     DI,NameBuf      { wandeln...                               }
        MOV     DX,DI
        PUSH    SS
        POP     ES
        CLD
        LODSB
        CMP     AL,79           { max. 79 Zeichen Dateiname, sonst hat MS- }
        JB      @Kurz           { DOSe was dagegen                         }
        MOV     AL,79
  @Kurz:CBW                     { AL -> Sign-Extend                        }
        XCHG    AX,CX
        REP     MOVSB           { kopieren...                              }
        XCHG    AX,CX
        STOSB                   { und Null anhÑngen (ZÑhler nach REP = 0)  }
        PUSH    SS
        POP     DS
        XOR     CX,CX
        MOV     AX,Mode         { Mode enthÑlt schon DOS-Fn-Nummer         }
        INT     21H             { Datei îffnen...                          }
        POP     DS
        JNC     @OK             { kein Fehler                              }
        LES     DI,Self
        MOV     DX,stInitError
        PUSH    DX
        PUSH    AX
        PUSH    ES
        PUSH    DI
{$IFDEF NO_ASM_VMT_CALLS}
        call  DoStreamError
{$ELSE}
        MOV     DI,ES:[DI]      { War wohl nix                             }
        CALL    DWORD PTR [DI+TStream_Error]
{$ENDIF}
        MOV     AX,-1
  @OK:  LES     DI,Self
        MOV     ES:[DI].TDosStream.Handle,AX
END;

DESTRUCTOR TDosStream.Done; ASSEMBLER;
ASM
        LES     DI,Self
        MOV     BX,ES:[DI].TDosStream.Handle
        CMP     BX,-1           { Ist die Datei offen?                     }
        JE      @IstZu          { Nein!                                    }
        MOV     AH,3EH          { Schlie·en...                             }
        INT     21H
 @IstZu:XOR     AX,AX           { NULL - Direkter Aufruf                   }
        PUSH    AX
        PUSH    ES
        PUSH    DI
        CALL    TStream.Done
END;

FUNCTION TDosStream.GetPos; ASSEMBLER;
ASM
        LES     DI,Self
        XOR     DX,DX           { War da was wie'n Fehler?                 }
        CMP     DX,ES:[DI].TDosStream.Status
        JNE     @DaWarWas
        MOV     CX,DX
        MOV     BX,ES:[DI].TDosStream.Handle
        MOV     AX,4201H        { Dateiposition via DOS-Fn                 }
        INT     21H
        JNC     @OK
        MOV     DX,stError      { Fehler beim Grî·e-Feststellen            }
        PUSH    DX
        PUSH    AX
        PUSH    ES
        PUSH    DI
{$IFDEF NO_ASM_VMT_CALLS}
        call    DoStreamError
{$ELSE}
        MOV     DI,ES:[DI]
        CALL    DWORD PTR [DI+TStream_Error]
{$ENDIF}
   @DaWarWas:                   { Im Falle eines Fehlers: Grî·e=-1         }
        MOV     AX,-1
        CWD                     { DX:AX := AX                              }
   @OK:
END;

FUNCTION TDosStream.GetSize; ASSEMBLER;
ASM
        LES     DI,Self
        XOR     DX,DX
        CMP     DX,ES:[DI].TDosStream.Status
        JNE     @Fehler
        MOV     CX,DX
        MOV     BX,ES:[DI].TDosStream.Handle
        MOV     AX,4201H
        INT     21H             { Aktuelle Position holen                  }
        PUSH    DX
        PUSH    AX
        XOR     DX,DX
        MOV     CX,DX
        MOV     AX,4202H        { Seek ans Ende der Datei                  }
        INT     21H
        POP     SI
        POP     CX
        PUSH    DX
        PUSH    AX
        MOV     DX,SI
        MOV     AX,4200H        { ...und zurÅck zur aktuellen Position     }
        INT     21H
        POP     AX
        POP     DX
        JNC     @OK             { im Falle keines Fehlers...               }
        MOV     DX,stError
        PUSH    DX
        PUSH    AX
        LES     DI,Self
        PUSH    ES
        PUSH    DI
{$IFDEF NO_ASM_VMT_CALLS}
        call    DoStreamError
{$ELSE}
        MOV     DI,ES:[DI]
        CALL    DWORD [DI+TStream_Error]
{$ENDIF}
@Fehler:MOV     AX,-1
        CWD                     { Bei Fehlern Grî·e=-1                     }
    @OK:
END;

FUNCTION TDosStream.PRead; ASSEMBLER;
ASM
        LES     DI,Self
        CMP     ES:[DI].TDosStream.Status,0
        JNE     @Fehler         { Fehler=Arbeitsverweigerung               }

        PUSH    DS
        LDS     DX,Buf
        MOV     CX,Count
        MOV     BX,ES:[DI].TDosStream.Handle
        MOV     AH,3FH          { via Dos-Fn lesen                         }
        INT     21H
        POP     DS
        MOV     DX,stReadError
        jnc     @ok
(*      JC      @DosError       { öberhaupt etwas gelesen?                 }
        CMP     AX,CX
        JE      @OK             { Genug gelesen?                           }
        XOR     AX,AX
        MOV     DX,stReadError *)
@DosError:
        PUSH    DX
        PUSH    AX
        LES     DI,Self
        PUSH    ES
        PUSH    DI
{$IFDEF NO_ASM_VMT_CALLS}
        call  DoStreamError
{$ELSE}
        MOV     DI,ES:[DI]
        CALL    DWORD PTR [DI+TStream_Error]
{$ENDIF}
@Fehler:(*LES     DI,Buf
        MOV     CX,Count        { im Falle eines Fehlers...               }
        XOR     AL,AL           { lesen wir Nullen                        }
        CLD
        REP     STOSB*)
        xor     ax, ax          { 0 Bytes gelesen }
@OK:
END;

PROCEDURE TDosStream.Seek; ASSEMBLER;
ASM
        LES     DI,Self
        CMP     ES:[DI].TDosStream.Status,0
        JNE     @OK             { War da'n Fehler?                         }
        MOV     DX,Pos.Word[0]
        MOV     CX,Pos.Word[2]  { Nein. Dann wird gearbeitet               }
        OR      CX,CX
        JNS     @Positiv        { Negative Werte = NULL                    }
        XOR     DX,DX
        XOR     CX,CX
@Positiv:MOV    BX,ES:[DI].TDosStream.Handle
        MOV     AX,4200H
        INT     21H             { Dos macht die Drecksarbeit               }
        JNC     @OK
        MOV     DX,stSeekError  { Oder auch nicht                          }
        PUSH    DX
        PUSH    AX
        LES     DI,Self
        PUSH    ES
        PUSH    DI
{$IFDEF NO_ASM_VMT_CALLS}
  call  DoStreamError
{$ELSE}
        MOV     DI,ES:[DI]
        CALL    DWORD PTR [DI+TStream_Error]
{$ENDIF}
    @OK:
END;

PROCEDURE TDosStream.Truncate; ASSEMBLER;
ASM
        LES     DI,Self         { Bei Fehlern wird gestreikt=nichts pass.  }
        XOR     CX,CX
        CMP     CX,ES:[DI].TDosStream.Status
        JNE     @OK
        MOV     BX,ES:[DI].TDosStream.Handle
        MOV     AH,40H          { Versuche, 0 Bytes zu schreiben. DOS      }
        INT     21H             { schneidet dann die Datei ab              }
        JNC     @OK
        MOV     DX,stError
        PUSH    DX
        PUSH    AX
        LES     DI,Self
        PUSH    ES
        PUSH    DI
{$IFDEF NO_ASM_VMT_CALLS}
  call  DoStreamError
{$ELSE}
        MOV     DI,ES:[DI]
        CALL    DWORD PTR [DI+TStream_Error]
{$ENDIF}
   @OK:
END;

FUNCTION TDosStream.PWrite; ASSEMBLER;
ASM
        LES     DI,Self
        xor     ax, ax
        CMP     ES:[DI].TDosStream.Status,0
        JNE     @Nix            { Im Falle eines FéHLéRS                   }

        PUSH    DS
        LDS     DX,Buf
        MOV     CX,Count
        MOV     BX,ES:[DI].TDosStream.Handle
        MOV     AH,40H          { Sonst schreiben...                       }
        INT     21H
        POP     DS
        MOV     DX,stWriteError
        jnc     @nix
(*      JC      @Fehler         { Alles i.O. (auf deutsch: OK)             }
        CMP     AX,CX
        JE      @Nix
        XOR     AX,AX
        MOV     DX,stWriteError *)
@Fehler:PUSH    DX
        PUSH    AX
        LES     DI,Self
        PUSH    ES
        PUSH    DI
{$IFDEF NO_ASM_VMT_CALLS}
  call  DoStreamError
{$ELSE}
        MOV     DI,ES:[DI]
        CALL    DWORD PTR [DI+TStream_Error]
{$ENDIF}
        xor     ax, ax
@Nix:
END;

{***************************************************************************

    M e t h o d e n   v o n   T M e m o r y S t r e a m

***************************************************************************}

CONSTRUCTOR TMemoryStream.Init;
VAR ToGet:LONGINT;
    i,j:WORD;
BEGIN
  TStream.Init;
  Size:=aSize;
  Pos:=0;
  FieldSize:=(aSize+32767) DIV 32767;
  IF MaxAvail<4*FieldSize THEN Fail;
  ToGet:=aSize;
  GetMem(Field,4*FieldSize);
  FOR i:=1 TO FieldSize DO BEGIN
    IF ToGet>32768 THEN j:=32768 ELSE j:=ToGet;
    IF MaxAvail<j THEN Fail;
    GetMem(PPtrArray(Field)^[Pred(i)],j);
    FillChar(PPtrArray(Field)^[Pred(i)]^,j,0);
    Dec(ToGet,j);
  END;
  { ToGet mÅ·te jetzt Null sein ... }
END;

DESTRUCTOR TMemoryStream.Done;
VAR ToFree:LONGINT;
    i,j:WORD;
BEGIN
  ToFree:=Size;
  FOR i:=1 TO FieldSize DO BEGIN
    IF ToFree>32768 THEN j:=32768 ELSE j:=ToFree;
    FreeMem(PPtrArray(Field)^[Pred(i)],j);
    Dec(ToFree,j);
  END;
  FreeMem(Field,4*FieldSize);
  TStream.Done;
END;

FUNCTION TMemoryStream.PRead;
VAR CurOfs,CurBank,NochToRead,DOfs,InCurBank:WORD;
BEGIN            { ^- geiles Englisch. Morgen kommt der Weihnachtsmann... }
  IF Status<>0 THEN BEGIN
    PRead := 0;
    Exit;
  END;
  IF Pos+aSize>Size THEN BEGIN
    IF Pos <= Size THEN aSize := Size - Pos ELSE aSize := 0;
(*  FillChar(Buf,aSize,0);
    Error(stReadError,0) *)
  END;
  BEGIN
    NochToRead:=aSize;
    DOfs:=0;
    WHILE NochToRead>0 DO BEGIN
      CurOfs:=Pos AND $7FFF;
      CurBank:=Pos SHR 15;
      InCurBank:=32768-CurOfs;
      IF NochToRead<InCurBank THEN InCurBank:=NochToRead;
      Move(PByteArray(PPtrArray(Field)^[CurBank])^[CurOfs],
                         TByteArray(Buf)[DOfs],InCurBank);
      Inc(Pos,InCurBank);
      Inc(DOfs,InCurBank);
      Dec(NochToRead,InCurBank);
    END;
  END;
  PRead := aSize;
END;

FUNCTION TMemoryStream.PWrite;
VAR CurOfs,CurBank,NochToRead,DOfs,InCurBank:WORD;
BEGIN
  IF Pos+aSize>Size THEN BEGIN
    IF Pos <= Size THEN aSize := Size - Pos ELSE aSize := 0;
{   Error(stWriteError,0) }
  END;
  BEGIN
    NochToRead:=aSize;
    DOfs:=0;
    WHILE NochToRead>0 DO BEGIN
      CurOfs:=Pos AND $7FFF;
      CurBank:=Pos SHR 15;
      InCurBank:=32768-CurOfs;
      IF NochToRead<InCurBank THEN InCurBank:=NochToRead;
      Move(TByteArray(Buf)[DOfs],
           PByteArray(PPtrArray(Field)^[CurBank])^[CurOfs],
                         InCurBank);
      Inc(Pos,InCurBank);
      Inc(DOfs,InCurBank);
      Dec(NochToRead,InCurBank);
    END;
  END;
  PWrite := aSize;
END;

PROCEDURE TMemoryStream.Seek;
BEGIN
  IF Status=0 THEN BEGIN
    IF (APos>=Size) OR (APos<0) THEN Error(stSeekError,0) ELSE
      Pos:=APos;
  END;
END;

PROCEDURE TMemoryStream.Truncate;
BEGIN
END;

FUNCTION TMemoryStream.GetPos;
BEGIN
  IF Status<>0 THEN GetPos:=-1 ELSE GetPos:=Pos;
END;

FUNCTION TMemoryStream.GetSize;
BEGIN
  IF Status<>0 THEN GetSize:=-1 ELSE GetSize:=Size;
END;

{***************************************************************************

    M e t h o d e n   v o n   T X M S S t r e a m

***************************************************************************}

CONSTRUCTOR TXMSStream.Init;
BEGIN
  TStream.Init;
  Size:=(aSize+1023) DIV 1024;
  Handle:=XMSAllocate(Size);
  IF Handle=0 THEN Fail;
  Pos:=0;
END;

DESTRUCTOR TXMSStream.Done;
BEGIN
  XMSRelease(Handle);
  TStream.Done;
END;

FUNCTION TXMSStream.PRead(VAR Buf; aSize:WORD):WORD;
VAR XMS:TXMSStruc;
    Bytes:LONGINT;
    o:BOOLEAN;
    W:WORD;
BEGIN
  PRead := 0;
  IF Status<>0 THEN BEGIN
    {FillChar(Buf,aSize,0);}
    Exit;
  END;
  IF aSize=0 THEN Exit;
  Bytes:=1024*Size-Pos;
  IF Bytes<aSize THEN BEGIN
    {FillChar(Buf,aSize,0);
    Error(stReadError,0);
    Exit;}
    IF Bytes>0 THEN aSize := Bytes ELSE Exit;
  END;
  PRead := aSize;
  o:=Odd(aSize);
  aSize:=aSize AND (NOT 1);
  IF aSize<>0 THEN BEGIN
    XMS.Length:=aSize;
    XMS.sHandle:=Handle;
    XMS.sAdr:=Pos;
    XMS.dHandle:=0;
    XMS.dAdr:=LONGINT(@Buf);
    XMSMove(XMS);
  END;
  Inc(Pos,aSize);
  IF o THEN BEGIN
    Read(W,2);
    Dec(Pos);
    ASM
        LES     DI,Buf
        ADD     DI,aSize
        MOV     AL,BYTE PTR W
        MOV     BYTE PTR ES:[DI],AL
    END;
  END;
END;

FUNCTION TXMSStream.PWrite(VAR Buf; aSize:WORD):WORD;
VAR XMS:TXMSStruc;
    Bytes:LONGINT;
    O:BOOLEAN;
    W:WORD;
BEGIN
  PWrite:=0;
  IF Status<>0 THEN Exit;
  IF aSize=0 THEN Exit;
  Bytes:=1024*Size-Pos;
  IF Bytes<aSize THEN BEGIN
    {Error(stWriteError,0);
    Exit;}
    IF Bytes>0 THEN aSize:=Bytes ELSE Exit;
  END;
  PWrite := aSize;
  O:=Odd(aSize);
  aSize:=aSize AND (NOT 1);
  IF Size<>0 THEN BEGIN
    XMS.Length:=aSize;
    XMS.sHandle:=0;
    XMS.sAdr:=LONGINT(@Buf);
    XMS.dHandle:=Handle;
    XMS.dAdr:=Pos;
    XMSMove(XMS);
  END;
  Inc(Pos,aSize);
  IF O THEN BEGIN
    Read(W,2);
    Dec(Pos);
    ASM
        LES     DI,Buf
        ADD     DI,aSize
        MOV     AL,BYTE PTR ES:[DI]
        MOV     BYTE PTR W,AL
    END;
    XMS.Length:=2;
    XMS.sHandle:=0;
    XMS.sAdr:=LONGINT(@W);
    XMS.dHandle:=Handle;
    XMS.dAdr:=Pos-1;
    XMSMove(XMS);
  END;
END;

PROCEDURE TXMSStream.Seek(APos:LONGINT);
BEGIN
  IF Status<>0 THEN Exit;
  IF APos>Size*1024 THEN
    Error(stSeekError,0)
  ELSE
    Pos:=APos;
END;

PROCEDURE TXMSStream.Truncate;
BEGIN END;

FUNCTION TXMSStream.GetPos:LONGINT;
BEGIN
  GetPos:=Pos;
END;

FUNCTION TXMSStream.GetSize:LONGINT;
BEGIN
  GetSize:=Size*1024;
END;

{***************************************************************************

    M e t h o d e n   v o n   T R e s o u r c e

***************************************************************************}

CONSTRUCTOR TResource.Init;
LABEL KeinFehler;
VAR VerSys:TVersionInfo;
BEGIN                           { Initialisiere Ressourcendatei            }
  TObject.Init;
  SomeStream:=S;
  S^.Link:=@Self;
  IF (S=NIL) OR (S^.Status<>0) THEN Fail; { Stream fÅr Dreckarbeit         }
  SomeStream^.Seek(0);          { ≥<<-   Rewind                            }
  SomeStream^.Read(Header,64);
  IF Header.Ident<>RezIdent THEN BEGIN
    Done;
    Fail;
  END;
  {...evtl. CRC-Test...}
  LoadGNT;
  BuildIndex;
  Seek('VERSIONINFO','SYSTEM');
  IF Status<>0 THEN BEGIN
    Status:=rezInitError;
    Exit;
  END;
  SomeStream^.Read(VerSys,64);
  MyName:=VerSys.RezID;
  RegisterRez(@Self,VerSys.RezID);
END;

DESTRUCTOR TResource.Done;      { Gibt Ressource frei, wenn der Stream     }
BEGIN                           { nicht statisch (Datensegment) oder lokal }
  IF SomeStream<>NIL THEN BEGIN { (Stacksegment) ist, wird er freigegeben  }
    IF (Ofs(SomeStream^)<>DSeg) AND (Ofs(SomeStream^)<>SSeg) THEN
      Dispose(SomeStream,Done)
    ELSE
      SomeStream^.Done;
  END;
  IF GNT<>NIL THEN FreeMem(GNT,Header.GNTSize);
  FreeIndex;
  FreeRez(MyName);
  TObject.Done;
END;

PROCEDURE TResource.LoadGNT;
BEGIN
  IF Header.GNTSize=0 THEN GNT:=NIL ELSE BEGIN
    GetMem(GNT,Header.GNTSize);
    SomeStream^.Seek(Header.GNTPos);
    SomeStream^.Read(GNT^,Header.GNTSize);
  END;
END;

PROCEDURE TResource.Seek;       { Gehe zu Objekt ØAClass_AnObjectÆ         }
VAR P:PRezIndex;
BEGIN
  Status:=0;
  IF AnObject='' THEN BEGIN     { Leerer Objektname geht nicht             }
    Status:=rezObjectnotFound;
    Exit;
  END;
  AClass:=UpStr(AClass);
  AnObject:=UpStr(AnObject);
  IF AClass='' THEN             { Leerer Klassenname hei·t aktuelle Klasse }
               AClass:=CurName;
  IF AClass='' THEN BEGIN
    Status:=rezClassNotFound;
    Exit;
  END;
  IF AClass<>CurName THEN SeekClass(AClass);
  LastName:=MyName;
  WHILE LastName[Length(LastName)]=' ' DO Dec(LastName[0]);
  LastName:=LastName+':'+AClass+'_'+AnObject;
  P:=CurIndex;
  WHILE (P<>NIL) AND (P^.Name<>AnObject) DO P:=P^.Next;
  IF P=NIL THEN BEGIN
    Status:=rezObjectnotFound;
    Exit;
  END;
  SomeStream^.Seek(P^.Pos);
END;

PROCEDURE TResource.SeekClass;  { Initialisiere Klasse ØSÆ                 }
VAR P,Q:PRezIndex;
BEGIN
  S:=UpStr(S);
  IF S=CurName THEN Exit;       { Wenn sich nichts Ñndert auch nichts tun  }
  CurName:=S;
  P:=Index;
  WHILE (P<>NIL) AND (P^.Name<>S) DO P:=P^.Next;
  IF P=NIL THEN BEGIN
    Status:=rezClassNotFound;   { Klasse existiert nicht...                }
    Exit;                       { ...Pech gehabt                           }
  END;
  WHILE CurIndex<>NIL DO BEGIN  { Klasse existiert doch...                 }
    Q:=CurIndex^.Next;          { alten Index lîschen                      }
    Dispose(CurIndex);
    CurIndex:=Q;
  END;                          { Und neuen Index aufbauen                 }
  SomeStream^.Seek(P^.Pos);     { Gehe zu Liste                            }
  REPEAT
    S:=SomeStream^.ReadStr;     { Namen lesen...                           }
    IF S<>'' THEN BEGIN
      IF CurIndex=NIL THEN BEGIN
        New(CurIndex);          { Liste aufbauen                           }
        P:=CurIndex;
      END ELSE BEGIN
        New(P^.Next);
        P:=P^.Next;
      END;
      P^.Next:=NIL;             { und Werte eintragen                      }
      P^.Name:=S;
      SomeStream^.Read(P^.Pos,4);
      SomeStream^.Read(P^.Len,4);
    END;
  UNTIL S='';                   { Kein Name bedeutet Ende                  }
END;

PROCEDURE TResource.FreeIndex;  { Lîscht den aktuellen Index der Ressource }
VAR P:PRezIndex;
BEGIN
  CurName:='';                  { Keine Klasse ausgewÑhlt                  }
  WHILE Index<>NIL DO BEGIN
    P:=Index^.Next;
    Dispose(Index);
    Index:=P;
  END;
  WHILE CurIndex<>NIL DO BEGIN
    P:=CurIndex^.Next;
    Dispose(CurIndex);
    CurIndex:=P;
  END;
END;

PROCEDURE TResource.BuildIndex; { Baut den Index f.d. aktuelle Klasse auf  }
VAR Pos:LONGINT;
    T:WORD;
    S,S1:TRezItemName;
    P:PRezIndex;
BEGIN
  FreeIndex;                    { FÅr alle FÑlle...                        }
  Pos:=64;
  SomeStream^.Seek(64);
  REPEAT
    S:=SomeStream^.ReadStr;     { Name lesen...                            }
    IF S<>'' THEN BEGIN
      Inc(Pos,Length(S));
      Inc(Pos,3);
      SomeStream^.Read(T,2);    { Typ der Gruppe...                        }
      IF Index=NIL THEN BEGIN
        New(Index);             { Aufbau der verketteten Liste             }
        P:=Index;
      END ELSE BEGIN
        New(P^.Next);
        P:=P^.Next;
      END;
      P^.Name:=S;               { Zuweisung der Werte an den Listeneintrag }
      P^.Pos:=Pos;
      P^.Typ:=T;
      P^.Next:=NIL;
      REPEAT                    { öberspringen der Objektdefinitionen      }
        S1:=SomeStream^.ReadStr;
        IF S1<>'' THEN BEGIN
          Inc(Pos,Length(S1));
          Inc(Pos,9);
          SomeStream^.Read(S[1],8);
        END;
      UNTIL S1='';
      Inc(Pos);                 { Letztes Byte Åberspringen                }
    END;
  UNTIL S='';                   { Leerer String bedeutet Ende              }
END;

PROCEDURE TResource.GetRef;     { Lîst eine ØClass/ObjectÆ oder ØID/Class/ }
VAR aClass,anObj,aRez:STRING[40];  { ObjectÆ - Referenz auf                }
    op:LONGINT;
    W:WORD;
    P1,P2,P3:PGNTEntry;
    R:PResource;
BEGIN
{$IFNDEF DPMI}		{ keinen Bock das zu portieren }
  CASE RefType OF
    2:BEGIN
      aClass:=SomeStream^.ReadStr;
      anObj:=SomeStream^.ReadStr;
      op:=SomeStream^.GetPos;
      Seek(aClass,anObj);
      IF Status<>0 THEN
        P:=NIL
      ELSE
        DoRead(SomeStream^,P,PP);
      SomeStream^.Seek(op);
    END;
    3:BEGIN
      aClass:=SomeStream^.ReadStr;
      anObj:=SomeStream^.ReadStr;
      aRez:=SomeStream^.ReadStr;
      op:=SomeStream^.GetPos;
      R:=GetRezPtr(aRez);
      IF R=NIL THEN P:=NIL ELSE BEGIN
        R^.Seek(aClass,anObj);
        IF R^.Status<>0 THEN
          P:=NIL
        ELSE
          DoRead(R^.SomeStream^,P,PP);
        SomeStream^.Seek(op);
      END;
    END;
    $FD:BEGIN
      SomeStream^.Read(W,2);
      P1:=AddPointer(GNT,W);
      SomeStream^.Read(W,1);
      IF Lo(W)<>$FE THEN Status:=rezObjectNotFound ELSE BEGIN
        SomeStream^.Read(W,2);
        P2:=AddPointer(GNT,W);
        op:=SomeStream^.GetPos;
        Seek(P1^.Name,P2^.Name);
        IF Status<>0 THEN
          P:=NIL
        ELSE
          DoRead(SomeStream^,P,PP);
        SomeStream^.Seek(op);
      END;
    END;
    $FF:BEGIN
      SomeStream^.Read(W,2);
      P1:=AddPointer(GNT,W);
      SomeStream^.Read(W,1);
      IF Lo(W)<>$FD THEN Status:=rezObjectNotFound ELSE BEGIN
        SomeStream^.Read(W,2);
        P2:=AddPointer(GNT,W);
        SomeStream^.Read(W,1);
        IF Lo(W)<>$FE THEN Status:=rezObjectNotFound ELSE BEGIN
          SomeStream^.Read(W,2);
          P3:=AddPointer(GNT,W);
          op:=SomeStream^.GetPos;
          R:=GetRezPtr(P1^.Name);
          IF R<>NIL THEN BEGIN
            R^.Seek(P2^.Name,P3^.Name);
            IF R^.Status<>0 THEN
              P:=NIL
            ELSE
              DoRead(R^.SomeStream^,P,PP);
            SomeStream^.Seek(op);
          END ELSE Status:=rezObjectNotFound;
        END;
      END;
    END;
  ELSE
    Status:=rezObjectNotFound;
  END;
{$ENDIF}
END;

FUNCTION TResource.HandleCommand; { Behandelt ØClass/ObjectÆ und ØID/Class/}
BEGIN                           { ObjectÆ - Kommandos                      }
END;

FUNCTION TResource.Get;         { Holen eines Objektes aus der Ressource   }
BEGIN
  Seek(AClass,AnObject);
  IF Status=0 THEN Get:=SomeStream^.Get ELSE Get:=NIL;
END;

{***************************************************************************

    W i c h t i g e   P r o z e d u r e n

***************************************************************************}

PROCEDURE RegisterType;         { Registriert einen Objekttyp fÅr die      }
BEGIN                           { Arbeit mit Streams (Schei· BÅrokratie)   }
  IF Seg(R)<>DSeg THEN RegisterError;
  R.Next:=StreamTypes;
  StreamTypes:=Ofs(R);
END;

PROCEDURE RegisterRez;          { Registriert eine Ressource fÅr die Zusam-}
VAR R:PResourceRec;             { menarbeit mit anderen Ressourcen (Quer-  }
BEGIN                           { verweise)                                }
  R:=RezList;
  WHILE R<>NIL DO BEGIN
    IF R^.Ident=N THEN BEGIN
      IF R^.Name<>NIL THEN Dispose(R^.Name);
      R^.Name:=NIL;
      R^.Typ:=0;
      R^.Link:=P;
      Exit;
    END;
    R:=R^.Next;
  END;
  New(R);                       { Wird i.A. von TResource.Init aufgerufen  }
  R^.Link:=P;
  R^.Ident:=N;
  R^.Name:=NIL;
  R^.Next:=RezList;
  R^.Typ:=0;
  RezList:=R;
END;

PROCEDURE AddLink(ID:TResourceName; FN:STRING);
VAR R:PResourceRec;
BEGIN
  R:=RezList;
  WHILE R<>NIL DO BEGIN
    IF R^.Ident=ID THEN BEGIN
      IF R^.Typ=1 THEN BEGIN
        IF R^.Name<>NIL THEN New(R^.Name);
        R^.Name^:=FN;
      END;
      Exit;
    END;
    R:=R^.Next;
  END;
  New(R);
  New(R^.Name);
  R^.Name^:=FN;
  R^.Ident:=ID;
  R^.Link:=NIL;
  R^.Next:=RezList;
  R^.Typ:=1;
  RezList:=R;
END;

PROCEDURE FreeRez;              { Lîscht Ressource aus Liste               }
VAR P,Q:PResourceRec;           { Wird i.A. von TResource.Done aufgerufen  }
BEGIN
  P:=RezList;
  IF P=NIL THEN Exit;
  WHILE P<>NIL DO BEGIN
    IF P^.Ident=N THEN BEGIN
      P^.Typ:=0;
      P^.Link:=NIL;
      Exit;
    END;
    P:=P^.Next;
  END;
END;

FUNCTION LoadRez(S:STRING):PResource;
VAR R:PResource;
    D,DD:PStream;
    Z,F:LONGINT;
LABEL 0;
BEGIN
  LoadRez:=NIL;
  D:=New(PDosStream,Init(S,stOpenRead));
  IF D=NIL THEN Exit;
  IF D^.Status<>0 THEN BEGIN
    0:Dispose(D,Done);
    Exit;
  END;
  Z:=D^.GetSize;
  F:=XMSFree;
  IF SwapXMS AND (F>=Z) THEN BEGIN
    DD:=New(PXMSStream,Init(Z));
    IF DD<>NIL THEN DD^.CopyFrom(D^,Z);
    DD^.Seek(0);
    Dispose(D,Done);
    D:=DD;
  END;
  R:=New(PResource,Init(D));
  IF R=NIL THEN GOTO 0;
  IF R^.Status<>0 THEN BEGIN
    Dispose(R,Done);
    Exit;
  END;
  LoadRez:=R;
END;

FUNCTION GetRezPtr;             { Liefert einen Zeiger auf die Ressource   }
VAR P:PResourceRec;             { mit dem Namen N zurÅck                   }
    N:TresourceName;            { Falls diese Ressource noch nicht geladen }
BEGIN                           { ist, wird versucht, sie Åber LoadRezProc }
  P:=RezList;                   { zu laden                                 }
  FillChar(N,SizeOf(N),' ');
  IF Length(S)>SizeOf(n) THEN S[0]:=CHAR(SizeOf(N));
  Move(S[1],N,Length(S));
  WHILE P<>NIL DO BEGIN
    IF P^.Ident=N THEN BEGIN
      IF P^.Typ=0 THEN BEGIN
        GetRezPtr:=P^.Link;
        Exit;
      END ELSE BEGIN
        GetRezPtr:=LoadRez(P^.Name^);
        Exit;
      END;
    END;
    P:=P^.Next;
  END;
  IF @LoadRezProc<>NIL THEN ASM
        LEA     BX,N
        PUSH    SS              { VAR N:TResourceName }
        PUSH    BX
        CALL    DWORD PTR LoadRezProc
        MOV     WORD PTR P[0],AX
        MOV     WORD PTR P[2],DX
  END;
  GetRezPtr:=PResource(P);
END;

PROCEDURE Abstract;             { Beendet Programm mit Fehlermeldung       }
BEGIN
  Print(msgAbstract);
  RunError(255);
END;

PROCEDURE RegisterError;        { Analog Abstract                      }
BEGIN
  Print(msgRegError);
  RunError(255);
END;

FUNCTION UpStr;                 { String in Gro·buchstaben - WIE SCHîN     }
VAR I:INTEGER;
BEGIN
  FOR i:=1 TO Length(S) DO S[i]:=Upcase(S[i]);
  UpStr:=S;
END;

FUNCTION IsTrue;
VAR I:INTEGER;
BEGIN
  FOR i:=1 TO Length(S) DO S[i]:=Upcase(S[i]);
  IsTrue:=(S='YES') OR (S='1') OR (S='ON');
END;

FUNCTION IsFalse;
VAR I:INTEGER;
BEGIN
  FOR i:=1 TO Length(S) DO S[i]:=Upcase(S[i]);
  IsFalse:=(S='NO') OR (S='0') OR (S='OFF');
END;

PROCEDURE Print; ASSEMBLER;
ASM
        PUSH    DS
        LDS     SI,S
        CLD
        LODSB
        XOR     AH,AH
        XCHG    AX,CX
        MOV     AH,40h
        MOV     BX,1
        MOV     DX,SI
        INT     21h
        POP     DS
END;

PROCEDURE InitObjects;
BEGIN
  IF SwapXMS THEN BEGIN
    XMSDetect;
    XMSFreeOnRun:=XMSFree;
  END ELSE XMSFreeOnRun:=0;
END;

PROCEDURE DoneObjects;
VAR P:PResourceRec;
BEGIN
  IF IniLoaded THEN IniFile.Done;
  WHILE RezList<>NIL DO BEGIN
    P:=RezList;
    IF P^.Link<>NIL THEN Dispose(P^.Link,Done);
    IF P^.Name<>NIL THEN Dispose(P^.Name);
    RezList:=RezList^.Next;
    Dispose(P);
  END;
END;

FUNCTION RSeek;
VAR R:PResource;
BEGIN
  R:=GetRezPtr(ARez);
  IF R<>NIL THEN BEGIN
    R^.Seek(AClass,AnObject);
    IF R^.Status<>0 THEN BEGIN
      R^.Status:=0;
      R:=NIL;
    END;
  END;
  RSeek:=R;
END;

FUNCTION RGet;
VAR R:PResource;
    P:PObject;
BEGIN
  P:=NIL;
  R:=GetRezPtr(ARez);
  IF R<>NIL THEN BEGIN
    P:=R^.Get(AClass,AnObject);
    IF R^.Status<>0 THEN BEGIN
      R^.Status:=0;
      P:=NIL;
    END;
  END;
  RGet:=P;
END;

FUNCTION StreamOK(PS:PStream):BOOLEAN;
BEGIN
  StreamOK:=FALSE;
  IF PS<>NIL THEN BEGIN
    IF PS^.Status=0 THEN StreamOK:=TRUE ELSE Dispose(PS,Done);
  END;
END;

END.
