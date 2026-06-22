{===========================================================================}
{                                                                           }
{                           DPMI for Turbo Pascal                           }
{                                                                           }
{   For Turbo Pascal 6 or 7.                                                }
{                                                                           }
{   (c) copyright 2000,2001,2002 by Stefan Reuther                          }
{   See dpmi.txt for (un)restrictions and warranty information.             }
{                                                                           }
{===========================================================================}
{$I-,S-,R-,G+,O-}
UNIT DPMI;

{ If the following symbol is defined, include code to automatically load
  the DPMI server "dpmi16bi.ovl". If not defined, D4TP-compiled programs
  need a resident server. }
{$DEFINE AUTO_LOAD_DPMI_SERVER}

{ If the following is defined, include a workaround for "dpmi16bi.ovl"
  under plain DOS. It seems to ignore calls to INT 31/AX=0201, so we
  "emulate" it by directly hacking the IVT. }
{$DEFINE RMI_WORKAROUND}

INTERFACE

TYPE _DPMI_PathStr = STRING[79];

CONST _D4TP_VERSION = '20/Dec/2002';

{--- Initialisation ---}
PROCEDURE InitDPMI;
FUNCTION  InitDPMIOverlay(ovrname:_DPMI_PathStr):INTEGER;

PROCEDURE DeclareRealModeProcedure(start, after : POINTER);

{--- DPMI system call bindings ---}
FUNCTION  DPMISegmentToData(w : WORD) : WORD;

PROCEDURE DPMIGetRealmodeInt(n:BYTE; VAR p:POINTER);
PROCEDURE DPMISetRealmodeInt(n:BYTE; p:POINTER; is_real:BOOLEAN);

PROCEDURE DPMIInvokeRealmodeInterrupt(n:BYTE; res, rds:WORD);

{--- Translation Services ---}
FUNCTION  TranslateRealToCode(seg:WORD):WORD;
FUNCTION  TranslateFunctionPointer(p:POINTER):POINTER;
FUNCTION  TranslateCodeToData(seg : WORD): WORD;
PROCEDURE TranslateTextfile(VAR f:TEXT);
FUNCTION  TranslateDataPointer(p:POINTER):POINTER;

{ Maximum number of segments in EXE }
CONST DPMI_MAX_SEGMENTS = 128;
      DPMI_MAX_RM_PROCS = 10;

{ Runtime configuration }
CONST df_HeapPrealloc = 1;       { Attempt to make MaxAvail always
                                   return $FFF8 }

CONST DPMIFlags : WORD = df_HeapPrealloc;

{ Statistics }
CONST DPMI_BLOCK_SIZE = 65536;
CONST DPMIBlocksUsed : WORD = 0;

{ Overlay Return Codes }
CONST dovr_OK          = 0;
      dovr_Error       = -1;
      dovr_OutOfMemory = -2;

{ Debugging }
PROCEDURE DPMIDumpSegmentAssignments(VAR F:TEXT);
PROCEDURE DPMIDumpCore(fd:INTEGER);
PROCEDURE DPMIDumpCoreFile(VAR F:FILE);

VAR _realcs, _realds, _realss : WORD;    { always valid }
    _real_seg0                : WORD;    { only valid when DPMI active }

VAR _error_ds, _error_es, _error_ss, _error_cs, _error_ip,
    _error_sp : WORD;

CONST heap_seg  : WORD = 0;      { Pointer to first segment }
                                 { exported to be visible from debugger }

IMPLEMENTATION

{$F-     important! }

USES DOS, SysExt;

VAR seg_zero    : INTEGER;

{ EXE Header }
TYPE TExeHeader = RECORD
             mz             : WORD;
             partial, pages : WORD;
             relo           : WORD;
             header_para    : WORD;
             min, max       : WORD;
             ss, sp         : WORD;
             checksum       : WORD;
             ip, cs         : WORD;
             relo_ofs       : WORD;
             ovr_num        : WORD;
     END;

{ Overlay-Stub Segment Header }
TYPE POverlay = ^TOverlay;
     TOverlay = RECORD
           { Entries marked * are used internally by TP's overlay manager }
           ReturnAddr:LONGINT; { "Virtual return address"                * }
           FileOfs:LONGINT;    { position in overlay file }
           CodeSize:WORD;      { code size in bytes }
           FixupSize:WORD;     { fixup table size }
           EntryPts:WORD;      { number of entry points }
           CodeListNext:WORD;  { segment of next entry }
           LoadSeg:WORD;       { "Start segment in memory"               * }
           Reprieved:WORD;     { "Loaded in memory flag"                 * }
           LoadListNext:WORD;  { "Segment of next in load list"          * }
           UserHandle:LONGINT; { part of user data: DPMI segment handle }
           UserData:ARRAY[1..3] OF WORD;
           Entries : ARRAY[1..1000] OF RECORD  { [1..EntryPts], actually }
               CASE BYTE OF
                 0: (intr:WORD; ofs:WORD; blank:BYTE);  { before patch }
                 1: (jmp:BYTE; jofs, jsel:WORD);        { after patch }
           END;
     END;

TYPE PWordArray = ^TWordArray;
     TWordArray = ARRAY[0..10000] OF WORD;

{ Hooked interrupts }
CONST NUM_INTS   = 7;
      IntTab     : ARRAY[1..NUM_INTS] OF BYTE = ($23, $24, 0, 12, 13, $23, $23);
      IntTypeTab : ARRAY[1..NUM_INTS] OF BYTE = (0,   0,   2, 2,  2,  4,   4);
      { 0=RM int, 2=PM exception, 4=PM int }

TYPE TSegmentArray = ARRAY[1..DPMI_MAX_SEGMENTS] OF WORD;

VAR real_seg  : TSegmentArray;         { Real Mode segment numbers }
    prot_seg  : TSegmentArray;         { Protected Mode Code Selectors }
    prot_dseg : TSegmentArray;         { Protected Mode Data Selectors }
    nseg      : WORD;                  { Number of segments }
    IntSave   : ARRAY[1..NUM_INTS] OF LONGINT;

    rmptr     : ARRAY[1..DPMI_MAX_RM_PROCS] OF LONGINT;
    rmlen     : ARRAY[1..DPMI_MAX_RM_PROCS] OF WORD;

CONST nrmprocs : INTEGER = 0;
      orig_ovrseg : WORD = 0;

{
  Fatal error. Can be called in any mode.
}
PROCEDURE Crash; ASSEMBLER;
CONST _fatal = 'DPMI: fatal error -- ABORT'#13#10;
      fatal : ARRAY[1..Length(_fatal)] OF CHAR=_fatal;
      len = Length(_fatal);
ASM
        mov     dx, offset fatal
        mov     cx, len
        mov     bx, 2
        mov     ah, 40h
        int     21h
        mov     ax, 4CFFh
        int     21h
END;

{*** Translation Services **************************************************}

{
  Translate one segment value into another
  docrash = true     => crash on error
  docrash = false    => return 0
}
FUNCTION TranslateSegment(VAR src, dest : TSegmentArray; w : WORD;
                          docrash : BOOLEAN):WORD;
VAR i:INTEGER;
BEGIN
  FOR i:=1 TO nseg DO IF w = src[i] THEN BEGIN
    TranslateSegment := dest[i];
    Exit;
  END;
  IF docrash THEN Crash ELSE TranslateSegment := 0;
END;

{
  Real Mode Segment -> Code Selector
  The real mode segment must be an actual segment from your program
  Translating the data/stack segment will yield a DATA selector
}
FUNCTION TranslateRealToCode(seg : WORD): WORD;
BEGIN
  TranslateRealToCode := TranslateSegment(real_seg, prot_seg, seg, TRUE);
END;

{
  Code Selector -> Data Selector
  The selector must be an actual segment from your program
}
FUNCTION TranslateCodeToData(seg : WORD): WORD;
BEGIN
  TranslateCodeToData := TranslateSegment(prot_seg, prot_dseg, seg, TRUE);
END;

{
  Real Mode Segment -> Data Selector
  The real mode segment must be an actual segment from your program
}
FUNCTION TranslateRealToData(seg : WORD): WORD;
BEGIN
  TranslateRealToData := TranslateSegment(real_seg, prot_dseg, seg, TRUE);
END;

{
  Translate an open text file variable from real to protected
}
PROCEDURE TranslateTextFile(VAR F:TEXT);
VAR ff : RECORD
         handle, mode, bufsize, priv, bufpos, bufend : WORD;
         buf : POINTER;
         open, inout, flush, close : POINTER;
    END ABSOLUTE f;
BEGIN
  ff.buf   := TranslateDataPointer(ff.buf);
  ff.open  := TranslateFunctionPointer(ff.open);
  ff.inout := TranslateFunctionPointer(ff.inout);
  ff.flush := TranslateFunctionPointer(ff.flush);
  ff.close := TranslateFunctionPointer(ff.close);
END;

{
  Translate data pointer from real to protected
}
FUNCTION TranslateDataPointer(p : POINTER):POINTER; ASSEMBLER;
ASM
        mov     ax, p.word.2
        or      ax, ax
        jz      @skip
        push    ax
        call    TranslateRealToData
@skip:
        mov     dx, ax
        mov     ax, p.word.0
END;

{
  Translate function pointer from real to protected
}
FUNCTION TranslateFunctionPointer(p : POINTER):POINTER; ASSEMBLER;
ASM
        mov     ax, p.word.2
        or      ax, ax
        jz      @skip
        push    ax
        call    TranslateRealToCode
@skip:
        mov     dx, ax
        mov     ax, p.word.0
END;

{*** DPMI Bindings *********************************************************}

{
  In: Realmode Segment  Out: Data Selector
  Crashes if out of selectors (never happened to me). To translate a
  program segment (e.g. your real mode CS) to protected mode, you should
  use TranslateRealToData instead.
}
FUNCTION DPMISegmentToData(w : WORD) : WORD; ASSEMBLER;
ASM
        mov     bx, w
        mov     ax, 2
        int     31h
        jnc     @@okay
        jmp     Crash
@@okay:
END;

PROCEDURE FixDPL; ASSEMBLER;
ASM
	mov	ax, cs
	lar	ax, ax
	and	ah, 60h
	or	ah, 9Fh
	and	cl, ah
END;

{
  In: Realmode Segment  Out: Code Selector
  Crashes if out of selectors (never happened to me). To translate a
  program segment (e.g. your real mode CS) to protected mode, you should
  use TranslateRealToCode instead.
}
FUNCTION DPMISegmentToCode(w : WORD) : WORD; ASSEMBLER;
ASM
        mov     cx, 1
        mov     ax, 0
        int     31h             { allocate selector }
        jc      @Crash

        mov     si, ax          { the selector... }

        mov     ax, 16
        mov     dx, w
        mul     dx              { dx:ax = linear address }

        mov     cx, dx
        mov     dx, ax
        mov     bx, si
        mov     ax, 7
        int     31h             { set base address }
        jc      @Crash

        mov     cx, 0
        mov     dx, -1
        mov     ax, 8
        int     31h             { set limit }
        jc      @Crash

        mov     cx, 00FBh
	call	FixDPL
        mov     ax, 9           { set rights }
        int     31h
        jnc     @okay
@crash: jmp     Crash

@okay:  mov     ax, si
END;

{
  Get real mode interrupt vector. Out: p = real mode pointer
}
PROCEDURE DPMIGetRealmodeInt(n:BYTE; VAR p:POINTER); ASSEMBLER;
ASM
        mov     ax, 200h
        mov     bl, n
        int     31h
        les     di, p
        mov     es:[di], dx
        mov     es:[di+2], cx
END;

{
  Set real mode interrupt vector
  In: is_real=TRUE ->  p = real mode pointer
      is_real=FALSE -> p = protected mode pointer to a function in
                           our program (not on heap!)
}
PROCEDURE DPMISetRealmodeInt(n:BYTE; p:POINTER; is_real:BOOLEAN); ASSEMBLER;
ASM
        cmp     is_real, 0
        mov     cx, p.word.2
        jnz     @@adr_ok
        push    ds
        push    offset prot_seg
        push    ds
        push    offset real_seg
        push    cx
        push    1
        call    TranslateSegment
        mov     cx, ax
@@adr_ok:
{$IFNDEF RMI_WORKAROUND}
        mov     ax, 0201h
        mov     bl, n
        mov     dx, p.word.0
        int     31h
{$ELSE}
        mov     es, seg_zero
        mov     bl, n
        mov     bh, 0
        add     bx, bx
        add     bx, bx
        mov     ax, p.word.0
        mov     es:[bx], ax
        mov     es:[bx+2], cx
{$ENDIF}
END;

{
  Invoke real mode interrupt. In: res, rds = segment register values,
  ax..di = other parameters; Out: ax..di = return values
  Must be called from assembler block:
    ASM
      (* ... *)
      cmp     _DPMI, 0
      jz      @Real
      push    49h         (* interrupt number *)
      push    _realss     (* value for ES *)
      push    _realds     (* value for DS *)
      call    DPMIInvokeRealmodeInterrupt
      jmp     @Done
    @Real:
      int     49h
    @Done:
    END;
  Interrupts which do not take pointers/values in ds/es can be invoked
  directly (`int' instruction).
}
PROCEDURE DPMIInvokeRealmodeInterrupt(n:BYTE; res, rds:WORD); ASSEMBLER;
VAR rax : WORD;
ASM
        mov     rax, ax
        mov     ax, sp
        sub     ax, 100h        { 100h stack for this, rest for real mode }
        push    _realss
        push    ax
        push    0       { cs }
        push    0       { ip }
        push    0       { gs }
        push    0       { fs }
        push    rds
        push    res
        pushf
        push    0; push    rax
        push    0; push    cx
        push    0; push    dx
        push    0; push    bx
        push    0; push    0
        push    0; push    bp
        push    0; push    si
        push    0; push    di
        mov     ax, 300h
        mov     bl, n
        mov     bh, 0
        mov     cx, 0
        mov     di, sp
        push    ss
        pop     es
        int     31h
        pop     di; pop    ax
        pop     si; pop    ax
        pop     bp; pop    ax
        pop     ax; pop    ax
        pop     bx; pop    ax
        pop     dx; pop    ax
        pop     cx; pop    ax
        pop     rax; pop   ax
 (* Turbo's stack frame dumps these...
       add     sp, 18  { flags, ds, es, fs, gs, ss, sp, cs, ip }
 *)
        mov     ax, rax
END;

{***************************************************************************}

{ Internal: `the program contains a segment /seg/' }
PROCEDURE AddSeg(seg : WORD);
VAR i:WORD;
BEGIN
  i:=1;
  WHILE i<=nseg DO BEGIN
    IF real_seg[i]=seg THEN Exit;
    Inc(i);
  END;
  Inc(nseg);
  IF nseg > DPMI_MAX_SEGMENTS THEN BEGIN
    Writeln('DPMI: too many segments in executable -- ABORT');
    Halt(255);
  END;
  real_seg[nseg] := seg;
END;

{ HACK ALERT: if `Addr(MemAvail)' would work, we could get away without
  this hack: read the function code to access the addresses }
TYPE Relay = RECORD
         {$IFOPT G+}
            enter   : LONGINT;
         {$ELSE}
            pushbp  : BYTE;
            movbpsp : WORD;
            subsp   : ARRAY[1..3] OF BYTE;
         {$ENDIF}
            call    : BYTE;
            w, s    : WORD;
     END;

PROCEDURE MemRelay;
VAR L:LONGINT;
BEGIN
  L := MemAvail;
END;

PROCEDURE MaxRelay;
VAR L:LONGINT;
BEGIN
  L := MaxAvail;
END;

{
  Return the segment/selector address (depending on mode) of unit SYSTEM;
}
FUNCTION GetSysSeg : WORD;
BEGIN
  GetSysSeg := Relay(@MaxRelay^).s;
END;

{
  Allocate a new segment of the specified size, and create r/w data
  selector. Returns the selector or 0. The segment handle is stored at
  MemL[sel:4]. Currently, it is never used, though.
}
FUNCTION AllocateSegment(size : LONGINT) : WORD; ASSEMBLER;
VAR address : LONGINT;
    sel     : WORD;
ASM
        cmp     size.word.2, 0
        jnz     @@ok
        cmp     size.word.0, 8
        jae     @@ok
        mov     size.word.0, 8
@@ok:
        mov     ax, 501h
        mov     bx, size.word.2
        mov     cx, size.word.0 { 64k }
        int     31h             { 310501 Allocate Memory }
        jc      @error          { bx:cx = Adresse, si:di = Handle }

        mov     address.word.0, cx
        mov     address.word.2, bx

        mov     ax, 0
        mov     cx, 1
        int     31h             { 310000 Allocate descriptor }
        jc      @memerror

        mov     sel, ax

        mov     ax, 0007h       { 310007 Set Base }
        mov     bx, sel
        mov     cx, address.word.2
        mov     dx, address.word.0
        int     31h

        xor     cx, cx          { 310008 Set Limit }
        xor     dx, dx
        cmp     size.word.2, dx { Size > 64k -- set 64k limit }
        jnz     @skip
        mov     dx, size.word.0
@skip:
        dec     dx
        mov     ax, 0008h
        int     31h

        mov     es, bx
        mov     word ptr es:[4], di
        mov     word ptr es:[6], si

        mov     ax, bx
        jmp     @okay
@memerror:
        mov     ax, 0502h       { 310502 Free Memory }
        int     31h
@error:
        xor     ax, ax
@okay:
END;

PROCEDURE FreeSegment(L:LONGINT); ASSEMBLER;
ASM
        mov     si, L.word.2    { 310502 Free Memory }
        mov     di, L.word.0
        mov     ax, 0502h
        int     31h
END;

{*** Memory Management *****************************************************}

{
  Format of each Heap Segment:
   +0   WORD    next segment or 0
   +2   WORD    address of first free block (8 at start)
   +4   DWORD   DPMI Segment Handle
  Free Block:
   +0   WORD    Size (including this header)
   +2   WORD    Offset of next block or 0
   +4   DWORD   unused
}

TYPE TFreeBlock = RECORD
          size : WORD;
          next : WORD;
          unused : LONGINT;
     END;

TYPE TSegmentHeader = RECORD
          next : WORD;
          free : WORD;
          handle : LONGINT;
          first : TFreeBlock;
     END;

{
  allocate a new segment and initialize it. Where = "Next" pointer to
  use in that segment
}
FUNCTION AllocateNewSegment(where : WORD) : WORD;
VAR seg : WORD;
BEGIN
  { FIXME: implement a memory limit? }
  seg := AllocateSegment(DPMI_BLOCK_SIZE);
  IF seg<>0 THEN BEGIN
    MemW[seg : 0] := where;
    MemW[seg : 2] := 8;
    MemW[seg : 8] := DPMI_BLOCK_SIZE - 8;
    MemW[seg : 10] := 0;
    Inc(DPMIBlocksUsed);
  END;
  AllocateNewSegment := seg;
END;

{
  Try to allocate /len/ bytes in the specified segment.
  Standard first fit allocator.
  Returns offset or 0
}
FUNCTION AllocateInSegment(seg, len : WORD) : WORD;
VAR prev, this : WORD;
BEGIN
  prev := 0;
  this := MemW[seg:2];
  WHILE (this<>0) AND (MemW[seg:this] < len) DO BEGIN
    prev := this;
    this := MemW[seg:this + 2];
  END;
  IF this = 0 THEN AllocateInSegment := 0 ELSE
  IF MemW[seg:this] > len THEN BEGIN
    Dec(MemW[seg:this], len);
    AllocateInSegment := this + MemW[seg:this];
  END ELSE BEGIN
    { destroy this free block }
    MemW[seg:prev+2] := MemW[seg:this+2];
    AllocateInSegment := this;
  END;
END;

{
  GetMem replacement. Allocate /w/ bytes. Return pointer or NIL.
  Assumes w<>0.
}
FUNCTION MyGetMemReal(w:WORD):POINTER;
VAR i, q : WORD;
BEGIN
  w := (w+7) AND $FFF8;
  IF w=0 THEN BEGIN
    MyGetMemReal := NIL;
    Exit;
  END;
  i := heap_seg;
  WHILE i<>0 DO BEGIN
    q := AllocateInSegment(i, w);
    IF q<>0 THEN BEGIN
      MyGetMemReal := Ptr(i, q);
      Exit;
    END;
    i := MemW[i:0];
  END;
  i := AllocateNewSegment(heap_seg);
  IF i<>0 THEN BEGIN
    heap_seg := i;
    q := AllocateInSegment(i, w);
    IF q<>0 THEN BEGIN
      MyGetMemReal := Ptr(i, q);
      Exit;
    END;
  END;
  MyGetMemReal := NIL;
END;

{
  FreeMem replacement. Free /w/ bytes at /pt/. Returns false
  iff invalid arguments.
}
FUNCTION MyFreeMemReal(w:WORD; pt:POINTER) : BOOLEAN;
VAR s, o, p, q, r : WORD;
BEGIN
  IF w=0 THEN BEGIN
    MyFreeMemReal := TRUE;
    Exit;
  END;
  w := (w+7) AND $FFF8;
  IF w=0 THEN BEGIN
    MyFreeMemReal := FALSE;
    Exit;
  END;
  s := Seg(pt^);
  q := heap_seg;
  WHILE (q<>0) AND (q<>s) DO q:=MemW[q:0];
  IF q=0 THEN BEGIN
    MyFreeMemReal := FALSE;
    Exit;
  END;
 {--- free /w/ bytes in segment /s/ ---}
  q := 0;
  p := MemW[s:2];
  r := Ofs(pt^);
  WHILE (p<>0) AND (r > p) DO BEGIN
    q := p;
    p := MemW[s:p+2];
  END;

  { FIXME: IF (r overlaps another block) THEN RETURN FALSE; }

 { create new freelist entry }
  MemW[s:r+2] := p;
  MemW[s:r]   := w;
  MemW[s:q+2] := r;

 { merge with predecessor, if possible }
  IF (q<>0) AND (q + MemW[s:q] = r) THEN BEGIN
    Inc(MemW[s:q], w);
    MemW[s:q+2] := p;
    r := q;
  END;

 { merge with successor, if possible }
  IF (p<>0) AND (r + MemW[s:r] = p) THEN BEGIN
    Inc(MemW[s:r], MemW[s:p]);
    MemW[s:r+2] := MemW[s:p+2];
  END;

  MyFreeMemReal := TRUE;
END;

{ Replacement for heap.asm::NewMemory: In: ax = size; Out: DX:AX = pointer,
  or CF set for RunError 203 }
PROCEDURE MyGetMem; FAR; ASSEMBLER;
CONST alloc_size : WORD = 0;
ASM
        mov     alloc_size, ax
        or      ax, ax
        jz      @nil
@again: push    ax
        call    MyGetMemReal
        mov     cx, dx
        or      cx, ax
        jnz     @okay

        push    alloc_size
        call    HeapError
        cmp     al, 1
        jb      @return         { Return error }
        je      @nil
        mov     ax, alloc_size
        jmp     @again
@nil:   xor     ax, ax
        cwd
@okay:  clc
@return:
END;

{ Replacement for heap.asm::DisMemory: In: ax = size, bx:cx = pointer;
  Out: CF set on error }
PROCEDURE MyFreeMem; FAR; ASSEMBLER;
ASM
        push    ax
        push    bx
        push    cx
        call    MyFreeMemReal
        clc                        { not necessary, but prevents tputuner from
                                     optimizing away the `cmp al, 1' }
        cmp     al, 1
END;

{
  MemAvail replacement
}
FUNCTION MyMemAvail:LONGINT; FAR;
VAR s, o : WORD;
    l    : LONGINT;
BEGIN
  l := 0;
  s := heap_seg;
  WHILE s<>0 DO BEGIN
    o := MemW[s:2];
    WHILE o<>0 DO BEGIN
      Inc(l, MemW[s:o]);
      o := MemW[s:o+2];
    END;
    s := MemW[s:0];
  END;
  MyMemAvail := l;
END;

{
  MaxAvail replacement
}
FUNCTION MyMaxAvail:LONGINT; FAR;
VAR s, o : WORD;
    p    : WORD;
    max  : WORD;
BEGIN
  max := 0;
  p := 0;
  s := heap_seg;
  WHILE s<>0 DO BEGIN
    o := MemW[s:2];
    WHILE o<>0 DO BEGIN
      IF MemW[s:o] > max THEN max := MemW[s:o];
      o := MemW[s:o+2];
    END;
    p := s;
    s := MemW[s:0];
  END;
  IF (DPMIFlags AND df_HeapPrealloc <> 0) AND (max < DPMI_BLOCK_SIZE - 8) THEN BEGIN
    s := AllocateNewSegment(0);
    IF s<>0 THEN BEGIN
      IF p<>0 THEN MemW[p:0] := s ELSE heap_seg := s;
      max := DPMI_BLOCK_SIZE - 8;
    END;
  END;
  MyMaxAvail := max;
END;

{***************************************************************************}

{ Patch Mem[s:w] with code in /dest/, preceded by /nopc/ NOP insns }
PROCEDURE PatchData(s, w : WORD; dest : STRING; nopc : INTEGER);
VAR k : INTEGER;
BEGIN
  s := TranslateCodeToData(s);
  FOR k:=1 TO Length(dest) DO Mem[s:w+k-1] := Ord(dest[k]);
  FOR k:=1 TO nopc DO Mem[s:w-k] := $90;
END;

{ Patch system unit: scan for /src/, replace with /dest/ preceded
  by /nopc/ NOPs }
PROCEDURE PatchSystem(src, dest : STRING; nopc : INTEGER);
VAR s : WORD;
    w,k:WORD;
LABEL Break;
BEGIN
  s := GetSysSeg;
  { 22222, because system.tpu contains ~20k code }
  { FIXME: we could compute the unit SYSTEM size }
  FOR w:=nopc TO 22222 DO BEGIN
    FOR k:=1 TO Length(src) DO IF Mem[s:w+k-1]<>Ord(src[k]) THEN GOTO Break;
    PatchData(s, w, dest, nopc);
    Exit;
   Break:
  END;
END;

{*** Exception Handler *****************************************************}

{ Ignore Ctrl-C }
PROCEDURE Int23Handler; ASSEMBLER;
ASM
        clc
        retf    2
END;

{ Signal errors by return code }
PROCEDURE Int24Handler; ASSEMBLER;
ASM
        mov     al, 3
        iret
(* "interesting" solution:
	pop	ax	{ caller ip }
	pop	ax	{ caller cs }
	pop	ax	{ caller flags }
	pop	ax	{ original AX }
	cmp	ah, 39h
	{ if DOS function < 39h, error signal is AX=-1
	  if DI bit 7 set, error signal is AX=DI+19, CF set
	  otherwise, error signal is AX=31, CF set }
	mov	ax, -1
	jz	@ErrOK
	mov	bx, sp
	or	word ptr ss:[bx+20], 1	{ set cf }
	mov	ax, 31
	test	di, 128
	jz	@ErrOK
	lea	ax, [di+19]
@ErrOK:	pop	bx
	pop	cx
	pop	dx
	pop	si
	pop	di
	pop	bp
	pop	ds
	pop	es
	iret *)
END;

PROCEDURE ExceptionHalt; FAR;
BEGIN
  ASM
        mov     ax, seg @Data
        mov     ds, ax
  END;
  RunError(ExitCode);
END;

PROCEDURE Exception; FAR; ASSEMBLER;
ASM
        push    bp
        mov     bp, sp
     { Stack: [bp+2] = Code
              [bp+4] = Return address to DPMI server
              [bp+8] = Exception Code
              [bp+10] = Return address for user program
              [bp+14] = Flags
              [bp+16] = User SS:SP }
        push    ds
        push    ax

        push    seg @Data
        pop     ds
        mov     ax, [bp+2]
        mov     ExitCode, ax
        mov     _error_es, es
        mov     ax, [bp+18];    mov     _error_ss, ax
        mov     ax, [bp+16];    mov     _error_sp, ax
        mov     ax, [bp-2];     mov     _error_ds, ax
        mov     ax, [bp+10];    mov     _error_ip, ax
        mov     ax, [bp+12];    mov     _error_cs, ax
        mov     word ptr [bp+10], offset ExceptionHalt
        mov     word ptr [bp+12], cs
        cmp     word ptr [bp+16], 1024
        jae     @@stackok
        mov     word ptr [bp+16], 1024
  @@stackok:
        pop     ax
        pop     ds
        pop     bp
        inc     sp
        inc     sp
        retf
END;

{ Int 0 = Runerror 200 }
PROCEDURE Exception0; FAR; ASSEMBLER;
ASM
        push    200
        jmp     Exception
END;

{ Int 12/13 (#SF/#GP) = Runerror 216 }
PROCEDURE Exception12or13; FAR; ASSEMBLER;
ASM
        push    216
        jmp     Exception
END;

VAR OldExit : POINTER;

PROCEDURE DPMIExitProc; FAR;
VAR i, s:INTEGER;
BEGIN
  ExitProc := OldExit;
  FOR i:=0 TO NUM_INTS-1 DO ASM
        mov     si, i
        mov     ah, 2
        mov     al, IntTypeTab[si].byte
        mov     bl, IntTab[si].byte
        shl     si, 2
        inc     ax
        mov     dx, IntSave[si].word
        mov     cx, IntSave[si].word.2
        int     31h
  END;

  { Free all memory we allocated. The PMODE DPMI implementation does not
    do this for us. First, the heap. }
  WHILE heap_seg<>0 DO BEGIN
    i := heap_seg;
    heap_seg := MemW[i:0];
    FreeSegment(MemL[i:4]);  { FIXME? Free descriptor }
  END;
  { Now, the overlay }
  i := orig_ovrseg;
  WHILE i<>0 DO BEGIN
    s := TranslateSegment(real_seg, prot_dseg, i + _real_seg0, FALSE);
    IF s=0 THEN i:=0 ELSE BEGIN
      FreeSegment(POverlay(Ptr(s, 0))^.UserHandle);
      i := POverlay(Ptr(s, 0))^.CodeListNext;
    END;
  END;

  { the following code is problematic, the Turbo Pascal runtime library
    seems to dereference the ErrorAddr pointer }
{ IF ErrorAddr<>NIL THEN BEGIN
    i := TranslateSegment(prot_seg, real_seg, Seg(ErrorAddr^), FALSE);
    IF i<>0 THEN ErrorAddr := Ptr(i, Ofs(ErrorAddr^));
  END; }
END;

{ shrink this program's memory block to end after /pt/. Only valid
  in real mode }
PROCEDURE SetMemTop(mt: POINTER); ASSEMBLER;
ASM
	mov	bx, mt.word.0
	add     bx, 15
	shr     bx, 4
	add     bx, mt.word.2
	mov     ax, PrefixSeg
	sub     bx, ax
	mov     es, ax
	mov     ah, 4Ah
	int     21h
END;

{*** DOS Function Bindings *************************************************}
{
  Note: as useful as it might seem -- do not export these via the
  `Interface' clause. They must be called using a NEAR frame.
}
TYPE DOSOpenStr = STRING[127];

{
  Open file, return fd. fname must include the zero byte.
  Returns negative value on error.
}
FUNCTION DOSOpenRead(fname:DOSOpenStr):INTEGER; ASSEMBLER;
ASM
        push    ds
        lds     dx, fname
        inc     dx
        mov     ax, 3D00h
        int     21h
        pop     ds
        jnc     @ok
        neg     ax
@ok:
END;

{
  Read from fd. Returns number of bytes read.
}
FUNCTION DOSRead(fd:INTEGER; VAR buf; len:WORD):WORD; ASSEMBLER;
ASM
        push    ds
        mov     ah, 3Fh
        mov     bx, fd
        mov     cx, len
        lds     dx, buf
        int     21h
        pop     ds
        jnc     @ok
        xor     ax, ax
@ok:
END;

FUNCTION DOSSeek(fd:INTEGER; whence:BYTE; pos:LONGINT):LONGINT; ASSEMBLER;
ASM
        mov     ah, 42h
        mov     al, whence
        mov     bx, fd
        mov     cx, pos.word.2
        mov     dx, pos.word.0
        int     21h
        jnc     @ok
        xor     ax,ax
        cwd
@ok:
END;

{
  Close fd.
}
PROCEDURE DOSClose(fd:INTEGER); ASSEMBLER;
ASM
        mov     ah, 3Eh
        mov     bx, fd
        int     21h
END;

{*** DPMI Loader ***********************************************************}

{
  Declare the area between /start/ and /after/ as a real mode
  procedure (will not be translated into protected mode).
  Assumes Seg(start^) = Seg(after^). Must be called before
  InitDPMI.
}
PROCEDURE DeclareRealModeProcedure(start, after : POINTER);
BEGIN
  IF nrmprocs > DPMI_MAX_RM_PROCS THEN BEGIN
    Writeln('DPMI: too many real-mode procedures');
    Halt(255);
  END;
  Inc(nrmprocs);
  rmptr[nrmprocs] := 16*LONGINT(Seg(start^)) + Ofs(start^);
  rmlen[nrmprocs] := Ofs(after^) - Ofs(start^);
END;

{ compute linear address of Mem[s:o] }
FUNCTION Linear(s,o:WORD):LONGINT; ASSEMBLER;
ASM
        mov     ax, 16
        mul     s
        add     ax, o
        adc     dx, 0
END;

{
  Main function: DPMI Initialisation
}
PROCEDURE LoadServer; FAR; FORWARD;

PROCEDURE InitDPMI;
CONST RELO_PER_CHUNK = 50;
VAR entry : POINTER;    { Mode Switch Entry Point }
    para  : WORD;       { DOS Extender Private Data }
    dxseg : WORD;
    i,j,k : WORD;
    fd    : INTEGER;
    l,m   : WORD;
    adr   : LONGINT;
    h     : TExeHeader;
    hack1 : RECORD
       CASE BYTE OF
         0: (s : STRING[7]);
         1: (len, call : BYTE;
             p : POINTER;
             retn : BYTE);
    END;
    buf   : ARRAY[1..RELO_PER_CHUNK] OF RECORD o,s:WORD; END;
    fname : STRING[127];
    auto_tried : BOOLEAN;

LABEL Next, Again;
BEGIN
  IF _DPMI THEN Exit;

  fname := GetEnv('DPMI');
  FOR i:=1 TO Length(fname) DO fname[i] := Upcase(fname[i]);
  IF fname='NO' THEN Exit;

  auto_tried := FALSE;
 Again:
  entry := NIL;
  ASM
        mov     ax, 1687h
        int     2Fh
        or      ax, ax
        jnz     @NoDPMI
        mov     entry.word.0, di
        mov     entry.word.2, es
        mov     para, si
  @NoDPMI:
  END;
  IF entry = NIL THEN BEGIN
   {$IFDEF AUTO_LOAD_DPMI_SERVER}
    IF NOT auto_tried THEN BEGIN
      auto_tried := TRUE;
      LoadServer;
      GOTO Again;
    END;
   {$ENDIF}
    Exit;
  END;
 {--- DPMI is available ---}
  ASM
        mov     ah, 62h         { getpid() }
        int     21h
        add     bx, 10h         { PSP = 100h Bytes }
        mov     _real_seg0, bx
  END;
  fname := ParamStr(0) + #0;
  fd := DOSOpenRead(fname);
  IF fd<0 THEN BEGIN
    Writeln('DPMI: can''t open executable');
    Exit;
  END;
  i := DOSRead(fd, h, Sizeof(h));
  IF (i<>Sizeof(h)) OR (h.mz<>$5A4D) THEN BEGIN
    DOSClose(fd);
    Writeln('DPMI: executable file damaged');
    Exit;
  END;
  nseg := 0;
  {... Register "standard" segments ...}
  AddSeg(SSeg);
  AddSeg(DSeg);
  {... Register addresses of active stack frames ...}
  { This is needed when the main module only contains NEAR procedures,
    it will then not have a relocation in the .exe file }
  ASM
        mov     bx, bp
  @@loop:
        cmp     word ptr ss:[bx], 0     { top frame }
        jz      @ok
        push    bx
        push    word ptr ss:[bx+4]
        call    AddSeg
        pop     bx
        mov     bx, ss:[bx]
        jmp     @@loop
  @ok:
  END;
  {... Register relocation addresses ...}
  DOSSeek(fd, 0, h.relo_ofs);
  k := h.relo;
  WHILE k<>0 DO BEGIN
    IF k > RELO_PER_CHUNK THEN i:=RELO_PER_CHUNK ELSE i:=k;
    DOSRead(fd, buf, i*4);
    FOR j:=1 TO i DO BEGIN
      AddSeg(MemW[buf[j].s + _real_seg0 : buf[j].o]);
      AddSeg(buf[j].s + _real_seg0);
    END;
    Dec(k, i);
  END;
  DOSClose(fd);
  k := OvrCodeList;
  WHILE k<>0 DO BEGIN
    Inc(k, _real_seg0);
    AddSeg(k);
    k := POverlay(Ptr(k, 0))^.CodeListNext;
  END;
  fname := ParamStr(0) + #0;
 {--- Prepare mode switch ---}
  SwapVectors;                     { Kick out Turbo Pascal's exception handlers }
  SetMemTop(HeapPtr);
  dxseg := 0;
  IF para<>0 THEN BEGIN
    ASM
	mov	ah, 48h
	mov	bx, para
	int	21h
	jc	@error
        mov     dxseg, ax
    @error:
    END;
    IF dxseg=0 THEN BEGIN
      Writeln('DPMI: Not enough memory to initialize DPMI');
      Exit;
    END;
  END;
 {!!! NO FAR CALLS BELOW THIS LINE !!!}
  ASM
        mov     es, dxseg
        xor     ax, ax
        call    entry
        sbb     ax, ax          { -> 0 = ok, -1 = error }
        mov     i, ax
        mov     j, es
  END;
  IF i<>0 THEN BEGIN
    IF dxseg<>0 THEN ASM
	mov	ah, 49h
	mov	es, dxseg
	int	21h
    END;
    Writeln('DPMI: Failure to switch to protected mode');
    SetMemTop(HeapEnd);
    Exit;
  END;
 {--- Relocate program ---}
  HeapPtr := NIL; HeapEnd := NIL;
  PrefixSeg := j;
  _DPMI := TRUE;
  FOR i:=1 TO nseg DO BEGIN
    IF real_seg[i]=_realds THEN BEGIN
      prot_seg[i]:=DSeg;
      prot_dseg[i]:=DSeg;
    END ELSE
    IF real_seg[i]=_realss THEN BEGIN
      prot_seg[i]:=SSeg;
      prot_dseg[i]:=SSeg;
    END ELSE BEGIN
      prot_seg[i] := DPMISegmentToCode(real_seg[i]);
      prot_dseg[i] := DPMISegmentToData(real_seg[i]);
    END;
  END;
  ASM
        lea     dx, fname + 1
        push    ds
        push    ss
        pop     ds
        mov     ax, 3D00h
        int     21h             { open }
        pop     ds
        jnc     @ok
        jmp     Crash
  @ok:
        mov     fd, ax
        mov     bx, ax
        mov     ax, 4200h
        mov     cx, 0
        mov     dx, h.relo_ofs
        int     21h             { seek }
  END;
  k := h.relo;
  WHILE k<>0 DO BEGIN
    IF k > RELO_PER_CHUNK THEN i:=RELO_PER_CHUNK ELSE i:=k;
    DOSRead(fd, buf, i*4);
    FOR j:=1 TO i DO BEGIN
      adr := Linear(buf[j].s + _real_seg0, buf[j].o);
      FOR l:=1 TO nrmprocs DO IF (adr >= rmptr[l]) AND (adr < rmptr[l] + rmlen[l])
       THEN GOTO Next;
      l := TranslateRealToData(buf[j].s + _real_seg0);
      MemW[l:buf[j].o] := TranslateRealToCode(MemW[l : buf[j].o]);
     Next:
    END;
    Dec(k, i);
  END;
  DOSClose(fd);
  ASM
       {--- Translate stack ---}
        mov     bx, bp
  @@loop:
        cmp     word ptr ss:[bx], 0
        jz      @@finito
         push    bx
         push    word ptr ss:[bx+4]
         call    TranslateRealToCode
         pop     bx
         mov     ss:[bx+4], ax
         mov     bx, ss:[bx]
        jmp      @@loop
  @@finito:
  END;
 {--- from here, the program runs rather safe in protected mode ---}
  { Save interrupts }
  FOR i:=0 TO NUM_INTS-1 DO ASM
        mov     si, i
        mov     ah, 2
        mov     al, IntTypeTab[si].byte
        mov     bl, IntTab[si].byte
        shl     si, 2
        int     31h
        mov     IntSave[si].word, dx
        mov     IntSave[si].word.2, cx
  END;

  { Translate pointers }
  TranslateTextfile(Input);
  TranslateTextfile(Output);
  PatchSystem(#$FC#$2E#$AC#$B4#$25,     { Don't restore interrupts in HaltTurbo }
              #$FC#$2E#$AC#$EB#$06,     { we do that with our exit procedure }
              0);
  hack1.p := @MyGetMem;
  hack1.len := 6;
  hack1.call := $9A;
  hack1.retn := $C3;
  PatchSystem(#$8C#$D9#$8E#$C1#$8B#$CF#$8C#$C3#$26#$C4#$3D#$8C#$C6#$3B#$36,
              hack1.s, 6);
  hack1.p := @MyFreeMem;
  PatchSystem(#$0B#$C0#$74#$5A#$F7#$C1#$F7#$FF#$75#$53#$3B#$1E,
              hack1.s, 0);
  hack1.call := $EA;            { jmp far }
  hack1.p := @MyMemAvail;
  PatchData(Relay(@MemRelay^).s, Relay(@MemRelay^).w,
            hack1.s, 0);
  hack1.p := @MyMaxAvail;
  PatchData(Relay(@MaxRelay^).s, Relay(@MaxRelay^).w,
            hack1.s, 0);
  HeapError := TranslateFunctionPointer(HeapError);
  OldExit := TranslateFunctionPointer(ExitProc);
  ExitProc := @DPMIExitProc;

  seg_zero := DPMISegmentToData(0);

  { Install own interrupts }
{$IFDEF RMI_WORKAROUND}
  ASM
        mov     es, seg_zero
        mov     cx, _realcs
        mov     word ptr es:[23h*4], offset Int23Handler
        mov     word ptr es:[23h*4+2], cx
        mov     word ptr es:[24h*4], offset Int24Handler
        mov     word ptr es:[24h*4+2], cx
  END;
{$ELSE}
  ASM
        mov     ax, 201h
        mov     bl, 23h
        mov     cx, _realcs
        mov     dx, offset Int23Handler
        int     31h
        mov     ax, 201h
        mov     bl, 24h
        mov     dx, offset Int24Handler
        int     31h
  END;
{$ENDIF}

  ASM
        mov     ax, 205h
        mov     bl, 23h
        mov     cx, cs
        mov     dx, offset Int23Handler
        int     31h
        mov     ax, 205h
        mov     bl, 24h
        mov     dx, offset Int24Handler
        int     31h

        mov     ax, 203h
        mov     bl, 0
        mov     cx, cs
        mov     dx, offset Exception0
        int     31h
        mov     ax, 203h
        mov     bl, 12
        mov     dx, offset Exception12or13
        int     31h
        inc     bx
        int     31h
  END;

  Seg0040 := DPMISegmentToData($0040);
  SegA000 := DPMISegmentToData($A000);
  SegB000 := DPMISegmentToData($B000);
  SegB800 := DPMISegmentToData($B800);
END;

{
  Load overlay. Must be called instead of OvrInit if DPMI is being used:
    InitDPMI;
    IF _DPMI THEN BEGIN
      IF InitDPMIOverlay(...)<>0 THEN Halt;
    END ELSE BEGIN
      OvrInit(...);
      OvrInitXMS;
      OvrInitEMS;
      ...
    END;
  Return code:
   =0                OK
   >0                DOS error code from opening overlay file
   dovr_OutOfMemory  not enough DPMI memory
   dovr_Error        not in protected mode
  or Runtime Error 203 (not enough memory for relocation table)

  This *could* easily be changed to do OvrInit &c automatically if
  called from real mode. However, I decided against doing so because
  that would make the DPMI unit depend on the Overlay (and OverXMS)
  unit.
}
FUNCTION InitDPMIOverlay(ovrname:_DPMI_PathStr):INTEGER;
VAR i : INTEGER;
    k : INTEGER;
    w : WORD;
    j : WORD;
    p : POverlay;
    csel : WORD;
    pw : PWordArray;
    fd : INTEGER;
BEGIN
  IF NOT _DPMI THEN BEGIN
    InitDPMIOverlay := dovr_Error;
    Exit;
  END;
  fd := DOSOpenRead(ovrname + #0);
  IF fd<0 THEN BEGIN
    InitDPMIOverlay := -fd;
    Exit;
  END;
 {--- Overlay file now open; load overlays ---}
  w := OvrCodeList;
  orig_ovrseg := w;
  WHILE w<>0 DO BEGIN
    p := Ptr(TranslateRealToData(_real_seg0 + w), 0);
    csel := AllocateSegment(p^.CodeSize);
    IF csel=0 THEN BEGIN
      InitDPMIOverlay := dovr_OutOfMemory;
      DOSClose(fd);
      Exit;
    END;
    p^.UserHandle := MemL[csel:4];

    {... Load code block ...}
    DOSSeek(fd, 0, p^.FileOfs);
    DOSRead(fd, Mem[csel:0], p^.CodeSize);

    {... Fixups ...}
    IF p^.FixupSize<>0 THEN BEGIN
      GetMem(pw, p^.FixupSize);
      DOSRead(fd, pw^, p^.FixupSize);
      FOR j:=0 TO Pred(p^.FixupSize DIV 2) DO BEGIN
        k := TranslateSegment(real_seg, prot_seg, MemW[csel : pw^[j]] + _real_seg0, FALSE);
        IF k=0 THEN BEGIN
          AddSeg(MemW[csel : pw^[j]] + _real_seg0);
          k := DPMISegmentToCode(real_seg[nseg]);
          prot_seg[nseg] := k;
          prot_dseg[nseg] := DPMISegmentToData(real_seg[nseg]);
        END;
        MemW[csel:pw^[j]] := k;
      END;
      FreeMem(pw, p^.FixupSize);
    END;

    {... Translate entry points ...}
    FOR j:=1 TO p^.EntryPts DO WITH p^.Entries[j] DO BEGIN
      jofs := ofs;
      jsel := csel;
      jmp  := $EA;
    END;

    {... Turn selector into a code segment ...}
    ASM
        mov     bx, csel
        mov     cx, $FB
	call	FixDPL
	mov	ax, 9
        int     31h
    END;

    w := p^.CodeListNext;
    OvrCodeList := w;
  END;
  InitDPMIOverlay := 0;
  DOSClose(fd);
END;

{*** Debugging *************************************************************}

TYPE Str7 = STRING[7];

FUNCTION hex(w:WORD):Str7;
CONST hd:ARRAY[0..15] OF CHAR='0123456789abcdef';
BEGIN
  hex := hd[w SHR 12] + hd[(w SHR 8) AND 15] + hd[(w SHR 4) AND 15] + hd[w AND 15];
END;

{
  If you're getting runtime errors, call this procedure somewhere in
  your program. If you get `Runtime error 123 at 0123:4567', look up
  `0123' in the `(code)' column. Then call `tpc /f1357:4567 myfile.pas'
  where 1357 is the value from the `(real)' column.
}
PROCEDURE DPMIDumpSegmentAssignments(VAR F:TEXT);
VAR i:INTEGER;
BEGIN
  Writeln(F, '     (real)  (data)  (code)');
  Writeln(F, 'PSP  ', hex(_real_seg0), '    ', hex(PrefixSeg));
  Writeln(F, 'DS   ', hex(_realds),   '    ', hex(DSeg));
  Writeln(F, 'SS   ', hex(_realss),   '    ', hex(SSeg));
  Writeln(F, 'CS   ', hex(_realcs),   '            ', hex(CSeg));
  Writeln(F, '(following addresses are relative)');
  FOR i:=1 TO nseg DO
   Writeln(F, i:3,'  ', hex(real_seg[i]-_real_seg0), '    ', hex(prot_dseg[i]-PrefixSeg), '    ', hex(prot_seg[i]-PrefixSeg));
END;

{*** Auto-Loading the DPMI Server ******************************************}

VAR dpmi_overlay : STRING[Sizeof(_DPMI_PathStr)];

FUNCTION DOSAlloc(para:WORD):WORD; ASSEMBLER;
ASM
        mov     ah, 48h
        mov     bx, para
        int     21h
        jnc     @@ok
        xor     ax, ax
@@ok:
END;

PROCEDURE DOSResize(segm, para:WORD); ASSEMBLER;
ASM
        mov     ah, 4Ah
        mov     es, segm
        mov     bx, para
        int     21h
END;

PROCEDURE DOSFree(segm:WORD); ASSEMBLER;
ASM
        mov     ah, 49h
        mov     es, segm
        int     21h
END;

FUNCTION DOSLoadOverlay(VAR name; VAR para):BOOLEAN; ASSEMBLER;
ASM
        push    ds

        mov     ax, 4B03h
        lds     dx, name
        les     bx, para
        int     21h
        mov     al, 1
        sbb     al, 0

        pop     ds
END;

FUNCTION OpenServer(name : _DPMI_PathStr) : INTEGER;
BEGIN
  dpmi_overlay := name + #0;
  OpenServer := DOSOpenRead(dpmi_overlay);
END;

{
  The actual DPMI server loader
}
PROCEDURE LoadServer;
VAR fd                  : INTEGER;
    exh                 : TExeHeader;
    fsize, hsize, csize : LONGINT;
    segm                : WORD;
    load_para           : ARRAY[1..2] OF WORD;
    i                   : INTEGER;
    s                   : _DPMI_PathStr;
CONST servername = 'dpmi16bi.ovl';
BEGIN
  { Try to find the server }
  s  := ParamStr(0);
  WHILE (S<>'') AND (Pos(S[Length(s)], '\/:')=0) DO Dec(S[0]);
  fd := OpenServer(s + servername);
  IF fd < 0 THEN fd := OpenServer(servername);
  IF fd < 0 THEN Exit;

  IF (DOSRead(fd, exh, Sizeof(exh))=Sizeof(exh)) AND (exh.mz=$5A4D) THEN BEGIN
    SetMemTop(HeapPtr);
    { Compute sizes }
    fsize := DOSSeek(fd, 2, 0);
    hsize := LONGINT(exh.header_para) * 16;
    csize := 512*LONGINT(exh.pages) - exh.partial;
    IF (exh.partial<>0) AND (exh.pages>0) THEN Dec(csize, 512);
    Dec(csize, hsize);
    DOSClose(fd);

    { Allocate a block of memory for us }
    segm := DOSAlloc((fsize - hsize) SHR 4);
    IF segm=0 THEN BEGIN
      SetMemTop(HeapEnd);
      Exit;
    END;

    { Load overlay }
    load_para[1] := segm;
    load_para[2] := segm;
    Inc(exh.cs, segm);
    IF NOT DOSLoadOverlay(dpmi_overlay[1], load_para) THEN BEGIN
      DOSFree(segm);
      SetMemTop(HeapEnd);
      Exit;
    END;

    { Adjust memory to csize }
    DOSResize(segm, csize DIV 16);

    { Call overlay. Magic invocation sequence. }
    ASM
        mov     ax, 14h
        mov     es, segm
        push    es
        call    dword ptr exh.&ip
        pop     bx
        mov     i, ax
    END;

    IF i<>0 THEN BEGIN
      Writeln('DPMI: server returned error ', i, ' -- not loaded');
      DOSFree(segm);
      SetMemTop(HeapEnd);
    END;
  END ELSE DOSClose(fd);
END;

{*** Core Dumping **********************************************************}

PROCEDURE DOSWrite(fd:INTEGER; VAR f; len:WORD); ASSEMBLER;
ASM
        push    ds
        lds     dx, f
        mov     bx, fd
        mov     cx, len
        mov     ah, 40h
        int     21h
        pop     ds
END;

PROCEDURE DumpWriteSel(fd, sel:INTEGER);
VAR lim   : WORD;
    sh    : ARRAY[0..1] OF LONGINT;
BEGIN
  ASM
        lsl     ax, sel
        mov     lim, ax
  END;
  sh[0] := $41544144;
  sh[1] := LONGINT(lim) + 3;
  DOSWrite(fd, sh, 8);
  DOSWrite(fd, sel, 2);
  DOSWrite(fd, Mem[sel:0], lim);
  DOSWrite(fd, Mem[sel:lim], 1);
END;

PROCEDURE DPMIDumpCore(fd:INTEGER);
VAR sh    : ARRAY[0..1] OF LONGINT;
    a     : ARRAY[0..9] OF WORD;
    i, s  : INTEGER;
    l     : LONGINT;
BEGIN
 {--- Registers ---}
  sh[0] := $4D474553;   { 'SEGM' }
  sh[1] := 6*nseg + Sizeof(a);
  a[0] := SSeg;
  a[1] := SPtr;
  ASM mov a.4.word, bp END;
  a[3] := DSeg;
  a[4] := PrefixSeg;
  a[5] := _realcs;
  a[6] := _realds;
  a[7] := _realss;
  a[8] := _real_seg0;
  a[9] := nseg;
  DOSWrite(fd, sh, 8);
  DOSWrite(fd, a, Sizeof(a));
  DOSWrite(fd, real_seg, 2*nseg);
  DOSWrite(fd, prot_seg, 2*nseg);
  DOSWrite(fd, prot_dseg, 2*nseg);

 {--- Overlay ---}
  IF orig_ovrseg<>0 THEN BEGIN
    sh[0] := $5352564F;
    i := orig_ovrseg;
    WHILE i<>0 DO BEGIN
      Inc(i, _real_seg0);
      s := TranslateSegment(real_seg, prot_dseg, i, FALSE);
      IF s=0 THEN i:=0 ELSE BEGIN
        sh[1] := 2 + 32 + POverlay(Ptr(s, 0))^.EntryPts*5;
        DOSWrite(fd, sh, 8);
        DOSWrite(fd, i, 2);
        DOSWrite(fd, Ptr(s, 0)^, sh[1]-2);
        i := POverlay(Ptr(s, 0))^.CodeListNext;
      END;
    END;
  END;

 {--- Some Segments ---}
  DumpWriteSel(fd, DSeg);
  DumpWriteSel(fd, SSeg);
  DumpWriteSel(fd, PrefixSeg);
  i := heap_seg;
  WHILE i<>0 DO BEGIN
    DumpWriteSel(fd, i);
    i := MemW[i:0];
  END;
END;

PROCEDURE DPMIDumpCoreFile(VAR F:FILE);
VAR fd:WORD ABSOLUTE f;
BEGIN
  DPMIDumpCore(fd);
END;

BEGIN
  _realds := DSeg;
  _realss := SSeg;
  _realcs := CSeg;
END.
