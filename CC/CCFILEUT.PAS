{---------------------------------------------------------------------------}
{                                                                           }
{               P l a n e t s   C o m m a n d   C e n t e r                 }
{                                                                           }
{                            1995-2002 by Streu                             }
{                                                                           }
{---------------------------------------------------------------------------}
{                                                                           }
{                  File-related Functions For PCC (and VPA)                 }
{          (This is a subset of another unit "FileUtil" I wrote)            }
{                                                                           }
{---------------------------------------------------------------------------}
{$I switches.inc}
{$S-,D-}
UNIT ccFileUtil;
{$V-}

INTERFACE

{$IFDEF VPA}
USES VPACC;
{$ELSE}
USES Objects;
{$ENDIF}

{=== Filenames ===}
TYPE TFileName=STRING[79];
     TExtension=STRING[3];

PROCEDURE AppendExt(VAR N:TFileName; X:TExtension; Force:BYTE);
FUNCTION IsPathSep(c:CHAR):BOOLEAN;

{=== File access ===}
TYPE TBuf=RECORD                { Buffer for ReadStr & friends }
       Len,Ptr:WORD;
       B:ARRAY[0..127] OF BYTE;
     END;

PROCEDURE ReadStr(H:PStream; VAR S:STRING; VAR Buf:TBuf);
FUNCTION  ReadStrD(H:PStream; VAR S:STRING; VAR Buf:TBuf; delim:CHAR) : CHAR;
FUNCTION  ReadBuf(H:PStream; VAR D; count:WORD; VAR Buf:TBuf) : WORD;
PROCEDURE InitBuf(H:PStream; VAR B:TBuf);

FUNCTION GetFAttr(Name:TFileName):WORD;
FUNCTION EraseFile(Name:TFileName):WORD;
FUNCTION RenameFile(old,new:TFileName):WORD;

{=== Constants for AppendExt ===}
CONST ae_Check     = 0;         { Check whether extension is needed }
      ae_Force     = 1;         { Always replace }

{=== File attributes ===}
CONST fa_ReadOnly  = 1;         { read-only file }
      fa_Hidden    = 2;         { hidden file }
      fa_System    = 4;         { system file }
      fa_VolumeID  = 8;         { Volume Label }
      fa_Directory = 16;        { Directory }
      fa_Archive   = 32;        { File was modified }
      fa_Sharable  = 128;       { <NetWare> }

{=== Seek directions [not used here] ===}
      sd_FileStart = 0;         { relative to file start }
      sd_CurPos    = 1;         { relative to current position }
      sd_FileEnd   = 2;         { relative to file end }

{=== File Status ===}
CONST FileError:WORD=0;         { Last I/O error }

IMPLEMENTATION

{ true iff c is a path separator }
FUNCTION IsPathSep(c:CHAR):BOOLEAN;
BEGIN
  IsPathSep:=(c='\') OR (c='/') OR (c=':');
END;

{
  Append extension to file name.
    N      file name
    X      extension (without period)
    Force  replace existing extension if =ae_Force
}
PROCEDURE AppendExt(VAR N:TFileName; X:TExtension; Force:BYTE);
VAR i:INTEGER;
BEGIN
  i:=Length(N);
  WHILE (i<>0) AND (N[i]<>'.') AND NOT IsPathSep(N[i]) DO Dec(i);
  IF (N[i]='.') AND (Force=ae_Force) THEN BEGIN
    N[0]:=CHAR(i);
    N:=N+X;
  END ELSE
  IF (i=0) OR (N[i]<>'.') THEN N:=N+'.'+X;
END;

{
  Read a line from file.
    H      file
    S      output string
    buf    buffer to use (-> InitBuf)
    delim  delimiter. Reading stops either at LF or delimiter
  Returns delimiter that caused end of read, or 0 (and FileError set to -1)
  on EOF/error.
}
FUNCTION ReadStrD(H:PStream; VAR S:STRING; VAR Buf:TBuf; delim:CHAR):CHAR;
VAR c      : CHAR;
    amount : WORD;
BEGIN
  S:='';
  REPEAT
    IF Buf.Ptr>=Buf.Len THEN BEGIN
      amount := H^.PRead(Buf.B, Sizeof(Buf.B));
      Buf.Len:=amount;
      Buf.Ptr:=0;
      IF (amount=0) OR (H^.Status<>0) THEN BEGIN
        FileError:=$FFFF;
        ReadStrD := #0;
        Exit;
      END;
    END;
    c := Chr(Buf.B[Buf.Ptr]);
    Inc(Buf.Ptr);
    IF (c = #10) OR (c = delim) THEN BEGIN
      ReadStrD := c;
      Exit;
    END;
    CASE c OF
      #13:;
      #26:BEGIN
        FileError:=$FFFF;
        ReadStrD := #0;
        Exit;
      END;
    ELSE
      { avoid dependency to LowLevel: CatChar(S, c); }
      IF Length(S)<>255 THEN BEGIN
        Inc(S[0]);
        S[Ord(S[0])] := c;
      END;
    END;
  UNTIL FALSE;
END;

{
  Read a line from file (normal reading with LF delimiter)
}
PROCEDURE ReadStr(H:PStream; VAR S:STRING; VAR Buf:TBuf);
BEGIN
  ReadStrD(H, S, Buf, #10);
END;

{
  Read a block from file, using the buffer (the buffer is not filled,
  but its contents is used when possible).
    H      file
    D      data buffer
    count  amount to read
    buf    buffer
  Returns number of bytes read.
}
FUNCTION ReadBuf(H:PStream; VAR D; count:WORD; VAR Buf:TBuf) : WORD;
VAR read : WORD;
    n    : WORD;
BEGIN
  read := 0;
  IF Buf.Ptr < Buf.Len THEN BEGIN
    n := Buf.Len - Buf.Ptr;
    IF n > count THEN n := count;
    Move(Buf.B[Buf.Ptr], D, n);
    Dec(count, n);
    Inc(read, n);
    Inc(Buf.Ptr, n);
    ASM
        mov ax, n
        add d.word, ax
    END;
  END;
  IF count > 0 THEN BEGIN
    Inc(read, H^.PRead(D, count));
  END;
  ReadBuf := read;
END;

{
  Initialize buffer before it can be used.
}
PROCEDURE InitBuf(H:PStream; VAR B:TBuf);
BEGIN
  B.Ptr:=1;
  B.Len:=0;
  FileError:=0;
END;

{
  Convert Pascal string into zero-terminated string. In-place operation,
  string is not usable as pascal string afterwards.
}
PROCEDURE FrobFN(VAR fn:TFileName);
VAR len:BYTE;
BEGIN
  len := Length(fn);
  Move(fn[1], fn[0], len);
  fn[len] := #0;
END;

{
  Fetch attributes of specified file. Returns attributes, or zero and
  FileError set on error
}
FUNCTION GetFAttr(Name:TFileName):WORD;
BEGIN
  FrobFN(name);
  ASM
                push    ds
                push    ss
                pop     ds
                lea     dx,Name
                mov     ax,4300h
                int     21h
                pop     ds
                jc      @@Error
                xor     ax,ax
                jmp     @@OK
  @@Error:      xor     cx,cx
  @@OK:         mov     @Result,cx
                mov     FileError,ax
  END;
END;

{
  Erase a file. Returns zero on success, or error code and FileError set
  on error.
}
FUNCTION EraseFile(Name:TFileName):WORD;
BEGIN
  FrobFN(name);
  ASM
                push    ds
                push    ss
                pop     ds
                lea     dx,Name
                mov     ah,41h
                int     21h
                pop     ds
                jc      @@Error
                xor     ax,ax
  @@Error:      mov     @Result,ax
                mov     FileError,ax
  END;
END;

{
  Rename a file. Returns zero on success or error code and FileError set
  on error.
}
FUNCTION RenameFile(old,new:TFileName):WORD;
BEGIN
  FrobFN(old);
  FrobFN(new);
  ASM
                push    ds
                mov     ax, ss
                mov     ds, ax
                mov     es, ax
                lea     dx, old
                lea     di, new
                mov     ah, 56h
                int     21h
                pop     ds
                jc      @error
                xor     ax, ax
  @error:       mov     @Result, ax
                mov     FileError, ax
  END;
END;

END.