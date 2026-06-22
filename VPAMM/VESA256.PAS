{**************************************************************************

		   U N I T   M I T   V E S A - T R E I B E R

**************************************************************************}
{$I switches.inc}
{$A+,B-,D+,E+,F-,G+,I-,L+,N-,O-,R-,S-,V-,X+}

UNIT Vesa256;

INTERFACE

USES Drivers;

PROCEDURE Mult640;
PROCEDURE Mult800;

{=== Modi ===}
TYPE TMode=RECORD
	Nr:WORD;
	X,Y:WORD;
	Mult:POINTER;   { Funktion fr DX:AX := X*AX, „ndert SI/DI/ES nicht }
	BankMult:INTEGER; { Bank Multiplier (fr Granularity != 64K) }
     END;

CONST Vesa640x480:TMode=(Nr:$101; X:640; Y:480; Mult:@Mult640);
CONST Vesa800x600:TMode=(Nr:$103; X:800; Y:600; Mult:@Mult800);

CONST ve_OK      = 0;
      ve_NoVesa  = 1;
      ve_ModeNa  = 2;
      ve_Unsupported = 3;
      ve_BadRefresh = 4;

CONST VesaErr:BYTE     = 0;
      VesaPal:BOOLEAN  = FALSE ;
CONST VesaWinR:INTEGER = 0;
CONST VesaWinW:INTEGER = -1;

{=== Hilfs"variable" ===}
CONST VesaSeg:WORD=$A000;

{=== Treiberobjekt ===}
TYPE PVesa=^TVesa;
     TVesa=OBJECT(TGraph)
	    CONSTRUCTOR Init(VAR AMode:TMode);
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
	    PROCEDURE ClearScreen; VIRTUAL;}
	    FUNCTION GetPixel(X,Y:INTEGER):BYTE; VIRTUAL;
     END;

VAR VesaMemory:WORD;    { blocks   64 k }
VAR VesaDS:WORD;
VAR CurMode:TMode;
VAR VesaFB:LONGINT;
VAR BankR,BankW:WORD;
CONST picadd:BYTE=0;            { im 256er Modus: Zahl, die zu Bild-Farb-
				  indizes addiert wird }
CONST VesaVersion:WORD = 0;

FUNCTION CanDo(VAR M:TMode):BOOLEAN;
PROCEDURE SetBank(aBank:INTEGER; rw:BOOLEAN);
PROCEDURE SetNextBank(rw:BOOLEAN);

PROCEDURE VesaSetRGB(index:INTEGER; r,g,b:BYTE);

{PROCEDURE VesaFrobHLine(X1,Y1,X2:INTEGER);}

{*************************************************************************}

IMPLEMENTATION

USES {$IFDEF DPMISupport} DPMI, {$ENDIF} SysExt, Config;

{---------------------------------------------------------------------------}
{ Multiplikation DX:AX := AX*640                                            }
{---------------------------------------------------------------------------}
PROCEDURE Mult640; ASSEMBLER;
ASM
	mov     dx,640
	mul     dx
END;

{---------------------------------------------------------------------------}
{ Multiplikation DX:AX := AX*800                                            }
{---------------------------------------------------------------------------}
PROCEDURE Mult800; ASSEMBLER;
ASM
	mov     dx,800
	mul     dx
END;

procedure bang(x:INTEGER);
begin
  writeln('dpmi error code ', x);
  runerror(123);
end;

VAR descriptor : ARRAY[0..7] OF BYTE;
PROCEDURE SetBaseAddress; ASSEMBLER;
ASM
        stc
        mov     ax, 7
        int     31h
        jnc @ok
        push ax
        call bang

@ok:    push cx
        push dx
        mov ax,6
        int 31h
        pop ax
        cmp dx,ax
        jnz @mm
        pop ax
        cmp cx,ax
        jz @nmm
@mm:    push 99
        call bang
@nmm:
        push    es
        pop     es

{       push    es
        push    di

        push    ds
        pop     es
        mov     di, offset descriptor
        mov     ax, 11
        int     31h

        mov     ax, descriptor.word.5
        and     ax, 0060h                  keep DPL
        or      ax, 4092h                  set D=32bit, P=present, W=writable
        mov     descriptor.word.5, ax
        mov     descriptor.word.0, -1

        mov     descriptor.word.2, dx
        mov     descriptor.byte.4, cl
        mov     descriptor.byte.7, ch
        mov     ax, 12
        int     31h
        jnc     @ok
        push    ax
        call    bang
@ok:

        pop     di
        pop     es }
END;

PROCEDURE SetBank(aBank:INTEGER; rw:BOOLEAN); ASSEMBLER;
ASM
	push    ds
	push    ax
	push    bx
	push    dx
        push    cx
	mov     ax,seg @Data
	mov     ds,ax
	mov     ax,CurMode.BankMult
	imul    aBank

        mov     cx,VesaFB.word.2
        jcxz    @nofb
        cmp     ax,BankW
        jz      @@skipr

        mov     BankW,ax
        mov     BankR,ax
        add     cx,ax
        mov     dx,VesaFB.word.0
        mov     bx,VesaSeg
        call    SetBaseAddress
        jmp     @@skipr

@nofb:	cmp     ax,BankW
	xchg    dx,ax
	je      @@Skip
	mov     BankW,dx
	mov     ax,4F05h
	mov     bx,VesaWinW
	int     10h

@@Skip: cmp     rw,0
	je      @@SkipR
	mov     bx,VesaWinR
	or      bx,bx
	js      @@SkipR
	cmp     dx,BankR
	je      @@SkipR
	mov     BankR,dx
	mov     ax,4F05h
	int     10h

@@SkipR:pop     cx
        pop     dx
	pop     bx
	pop     ax
	pop     ds
END;

PROCEDURE SetNextBank(rw:BOOLEAN); ASSEMBLER;
ASM
	push    ds
	push    ax
	push    bx
	push    dx
        push    cx
	mov     ax,seg @Data
	mov     ds,ax
	mov     dx,BankW
	add     dx,CurMode.BankMult
	mov     BankW,dx

        mov     cx,VesaFB.word.2
        jcxz    @normal
        mov     BankR,dx
        add     cx,dx
        mov     dx,VesaFB.word.0
        mov     bx,VesaSeg
        call    SetBaseAddress
        jmp     @@skip

@normal:
        mov     ax,4F05h
	mov     bx,VesaWinW
	int     10h

	cmp     rw,0
	je      @@Skip
	mov     bx,VesaWinR
	or      bx,bx
	js      @@Skip
	mov     BankR,dx
	mov     ax,4F05h
	int     10h

@@Skip: pop     cx
        pop     dx
	pop     bx
	pop     ax
	pop     ds
END;

PROCEDURE Video; ASSEMBLER;
ASM
{$IFDEF DPMISupport}
        cmp     _DPMI, 0
        jz      @real
        push    10h
        push    _realss
        push    _realds
        call    DPMIInvokeRealmodeInterrupt
        jmp     @ok
@real:  mov     es, _realss
        int     10h
@ok:
{$ELSE}
        push    ss
        pop     es
        int     10h
{$ENDIF}
END;

{---------------------------------------------------------------------------}
{                                                                           }
{   C a n D o                                                               }
{ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - }
{                                                                           }
{   TRUE, wenn VESA mit dem Modus M untersttzt wird                        }
{                                                                           }
{---------------------------------------------------------------------------}
FUNCTION CanDo(VAR M:TMode):BOOLEAN;
VAR Buf:RECORD
	Sign:LONGINT;              { - Memory=0 -> kein VESA               }
	Ver:WORD;                  { - Memory!=0 -> Modus n/a              }
	OEM,Cap:LONGINT;
	Mode:POINTER;
	Mem:WORD;
       { VBE 2.0 }
        SWVer:WORD;
        Vendor,Product,ProductRev:POINTER;
        VBEAFVersion:INTEGER;
        AccModeList:POINTER;
	x:ARRAY[0..255+216] OF BYTE;
    END;
    P:POINTER;
    i:INTEGER;
BEGIN
  VesaErr:=ve_NoVesa;
  CanDo:=FALSE;
  VesaMemory:=0;
  Buf.Sign:=$32454256; {'VBE2' }
  ASM
	      { push    ss
		pop     es }
		lea     di,Buf
		mov     ax,4F00h
                call    Video  { int     10h }
		cmp     ax,004Fh
		je      @@OK
		mov     byte ptr Buf,0
  @@OK:
  END;
  IF (Buf.Sign<>$41534556) OR (Buf.Ver<257) THEN Exit;
  VesaVersion := Buf.Ver;
  VesaMemory:=Buf.Mem;
  VesaErr:=ve_ModeNA;
  P:=Buf.Mode;
{$IFDEF DPMISupport}
  IF _DPMI THEN ASM
    push  p.word.2
    call  DPMISegmentToData
    mov   p.word.2, ax
  END;
{$ENDIF}
  WHILE WORD(P^)<>$FFFF DO BEGIN
    IF WORD(P^)=M.Nr THEN BEGIN
      CanDo:=TRUE;
      Exit;
    END;
    ASM add p.word,2 END;
  END;
  VesaErr:=0;
END;

{***************************************************************************}
{                                                                           }
{   M e t h o d e n   v o n   T V e s a                                     }
{                                                                           }
{***************************************************************************}
CONSTRUCTOR TVesa.Init;            { Initialisiert den Treiber, wenn kein  }
VAR i:INTEGER;                     { VESA vorhanden: FAIL                  }
    Buf:ARRAY[0..128] OF WORD;
    foobuf:RECORD
      filler:ARRAY[0..$3D] OF BYTE;
      max_pixel_clock : LONGINT;
    END ABSOLUTE Buf;
    mult:INTEGER;
    flag:INTEGER;
    m:RECORD
           htotal          : INTEGER;
           hsync_start     : INTEGER;
           hsync_end       : INTEGER;
           vtotal          : INTEGER;
           vsync_start     : INTEGER;
           vsync_end       : INTEGER;
           flags           : INTEGER;
           pixel_clock     : LONGINT;
           refreshX100     : INTEGER;     { frames per 100 s }
           reserved        : ARRAY[0..39] OF BYTE;
    END;
BEGIN
  IF NOT CanDo(aMode) THEN Fail;
  ASM
		les     di,aMode
		mov     cx,es:[di].TMode.Nr
		lea     di,Buf
		mov     ax,4F01h
                call Video
  END;
  IF NOT Odd(Buf[0]) THEN BEGIN
    VesaErr:=ve_ModeNA;
    Fail;
  END;
  VesaErr:=ve_Unsupported;

  IF (Buf[3]<>64) THEN Fail;
  IF (Buf[2]=0) THEN Buf[2]:=64; {FIXME ????}
  IF (Buf[2]>64) OR (Buf[3] MOD Buf[2]<>0) THEN Fail;
  mult:=Buf[3] DIV Buf[2];

  IF (Buf[1] AND 7=7) THEN BEGIN        { Fenster 1 read/write }
    VesaWinW:=0;
    VesaWinR:=-1;
    VesaSeg:=Buf[4];
  END ELSE
  IF (Buf[1] AND $700=$700) THEN BEGIN  { Fenster 2 read/write }
    VesaWinW:=1;
    VesaWinR:=-1;
    VesaSeg:=Buf[5];
  END ELSE
  IF (Buf[1] AND $101=$101) AND ((Buf[1] OR Hi(Buf[1])) AND 7=7)
   AND (Buf[4]=Buf[5]) THEN BEGIN       { Eins read, eins write }
    IF Buf[1] AND 2=2 THEN BEGIN
      VesaWinR:=0;
      VesaWinW:=1;
    END ELSE BEGIN
      VesaWinR:=1;
      VesaWinW:=0;
    END;
    VesaSeg:=Buf[4];
  END ELSE
   Fail;

  { Initialize Modeline }
  flag := 0;
  IF UseModeline AND (VesaVersion>=$300) THEN BEGIN
    FillChar(m, Sizeof(m), 0);
    m.htotal := Modeline[1];
    m.hsync_start := Modeline[2];
    m.hsync_end := Modeline[3];
    m.vtotal := Modeline[4];
    m.vsync_start := Modeline[5];
    m.vsync_end := Modeline[6];
    m.flags := 4*Modeline[7];
    m.refreshX100 := Modeline[8]*100;
    m.pixel_clock := LONGINT(Modeline[8])*Modeline[1]*Modeline[4];
    IF m.pixel_clock > foobuf.Max_Pixel_Clock THEN BEGIN
      VesaErr := ve_BadRefresh;
      Fail;
    END;
    ASM
        mov     ax, 4f0bh
        mov     bx, 0
        db 66h
        mov     cx, m.pixel_clock.word
        les     si, aMode
        mov     dx, es:[si].TMode.Nr
        int     10h
        mov     i, ax
        db 66h
        mov     m.pixel_clock.word, cx
    END;
    IF i<>$4F THEN BEGIN
      VesaErr := ve_BadRefresh;
      Fail;
    END;
    flag := 1 SHL 11;
  END;

  VesaErr:=0;
  OldMode:=3;
  CurMode:=aMode;
  CurMode.BankMult:=mult;
  Mode:=0;
 {$IFDEF DPMISupport}
  VesaFB := 0;
  IF _DPMI AND (Buf[0] AND 128<>0) AND (VesaVersion>=$200) AND (Buf[$15]<>0) AND (MainOptions AND mo_DisableLFB=0) THEN ASM
        mov     bx, Buf.word.2Ah
        mov     cx, Buf.word.28h
        { map two meg = $20 * $10000 }
        mov     si, 20h
        mov     di, 0
        mov     ax, 0800h
        stc
        int     31h
        jc      @novesafb
        mov     VesaFB.word.0, cx
        mov     VesaFB.word.2, bx
        { allocate a descriptor }
        xor     ax, ax
        mov     cx, 1
        int     31h
        jc      @novesafb
        mov     VesaSeg, ax
        mov     bx, ax
        mov     ax, 8           { set descriptor limit }
        mov     cx, 0
        mov     dx, -1
        int     31h
        mov     cx, VesaFB.word.2  { set base address }
        mov     dx, VesaFB.word.0
        call    SetBaseAddress
        mov     CurMode.BankMult,1
        or      CurMode.Nr, 4000h
      @novesafb:
  END;
 {$ENDIF}

  ASM
		mov     ax,4F02h
		mov     bx,CurMode.Nr
                or      bx, flag
                lea     di, m
                call    Video
		mov     i,ax
  END;
  IF i<>$004F THEN Fail;
  BankR:=0;
  BankW:=0;
  MaxX:=CurMode.X;
  MaxY:=CurMode.Y;
 {$IFDEF DPMISupport}
  IF _DPMI THEN BEGIN
    IF VesaFB=0 THEN VesaSeg := DPMISegmentToData(VesaSeg);
    VesaDS  := TranslateCodeToData(CSeg);
  END ELSE
 {$ENDIF}
  BEGIN
    VesaDS  := CSeg;
  END;
  VesaPal := (VesaVersion>=$200) AND (MainOptions AND mo_DisableVesaPal=0);
END;

DESTRUCTOR TVesa.Done;             { Gibt das Objekt frei und schaltet in  }
BEGIN                              { den originalen Videomodus zurck      }
  TGraph.Done;
END;

PROCEDURE TVesa.PutPixel;          { Setzt ein Pixel ber OUT, nicht ber  }
		     ASSEMBLER;    { das langsame BIOS                     }
ASM
	mov     ax,Y
	mov     di,X
	call    CurMode.Mult
	add     di,ax
	adc     dx,0
	mov     bl,op
	push    dx
	push    bx
	call    SetBank
@@ok:   mov     bh,0
	mov     es,VesaSeg
	add     bx,bx
	mov     al,C
	jmp     word ptr cs:@@Tab[bx]
@@Tab:  dw      @@Mov
	dw      @@And
	dw      @@Or
	dw      @@Xor
@@And:  and     es:[di],al
	jmp     @@ok1
@@Xor:  xor     es:[di],al
	jmp     @@ok1
@@Or :  or      es:[di],al
	jmp     @@ok1
@@Mov:  mov     es:[di],al
@@ok1:
END;

FUNCTION TVesa.GetPixel;
		     ASSEMBLER;
ASM
	mov     ax,Y
	mov     di,X
	call    CurMode.Mult
	add     di,ax
	adc     dx,0
	cmp     dx,0
	jl      @@Zero
	push    dx
	push    1
	call    SetBank
@@ok:   mov     es,VesaSeg
	mov     al,es:[di]
@@zero:
END;

(*
{$I dark.inc}
PROCEDURE VesaFrob(Adr:WORD; Len:WORD); ASSEMBLER;
ASM
        mov     bx, offset DarkColors
        cld
        mov     es, VesaSeg
        mov     si, Adr
        mov     cx, Len
        mov     di, si
        mov     ax, si
        add     ax, cx
        jz      @@nosplit
        jnb     @@nosplit

	mov     cx,di
	neg     cx
	sub     Len,cx
@@loop: seges lodsb
        xlat
        stosb
        loop    @@loop
        push    1
        call    SetNextBank
@@nosplit:
        mov     cx, Len
@@loop2: seges lodsb
        xlat
        stosb
        loop    @@loop2
END;

PROCEDURE VesaFrobHLine(X1,Y1,X2:INTEGER); ASSEMBLER;
ASM
	mov     ax,Y1
	call    CurMode.Mult    { DX:AX = Adresse }
	mov     di,X1
	add     di,ax
	adc     dx,0
	push    di
	push    dx
	push    1
	call    SetBank
				{ addresse iss schon gePUSHt }
	mov     ax,X2
	sub     ax,X1
	inc     ax
	push    ax
	call    VesaFrob
END;
*)

CONST Opcodes:ARRAY[0..3] OF BYTE=($88,$20,$08,$30);

PROCEDURE VesaFill(Adr:WORD; Len:WORD; Pattern,Color,op:BYTE); ASSEMBLER;
ASM
	mov     di,Adr
	mov     bx,offset Opcodes
	mov     al,op
	cmp     al,0                            { setzt CF }
	xlat
        mov     es,VesaDS
	mov     byte ptr es:[@@Patch+1],al
	mov     es,VesaSeg
	mov     cx,di
	mov     dl,Pattern
	mov     al,Color
	jnz     @@NoSolid                       { cmp al,0 oben }
	cmp     dl,255
	je      @@SolidFill
@@NoSolid:
	and     cl,7
	rol     dl,cl
	mov     cx,Len
	jcxz    @@Ende
@@Loop: rol     dl,1
	jnc     @@Skip
@@Patch:db      26h,88h,05h     { mov es:[di],al }
@@Skip: inc     di
	jz      @@NextBank
@@Go:   loop    @@Loop
	jmp     @@Ende
@@NextBank:
	push    word ptr op
	call    SetNextBank
	mov     al,Color
	jmp     @@Go
{--- Optimierung fr solid fill ---}
@@SolidFill:
	{ CX = DI = Adresse }
	mov     dx,Len
	mov     al,Color
	add     cx,dx
	cld
	jz      @@NoSplit
	jnb     @@NoSplit
 {--- muá aufgeteilt werden ---}
	mov     cx,di
	neg     cx
	sub     dx,cx
	shr     cx,1
	mov     ah,al
	rep stosw
	rcl     cx,1
	rep stosb
	xor     di,di
	mov     cx,dx
	push    0
	call    SetNextBank
 {--- komplett in dieser Seite enthalten ---}
@@NoSplit:
	sub     cx,di
	shr     cx,1
	mov     ah,al
	rep stosw
	rcl     cx,1
	rep stosb
	or      di,di
	jnz     @@Ende
	call    SetNextBank
@@Ende:
END;

PROCEDURE TVesa.Bar(X1,Y1,X2,Y2:INTEGER; Patt:TPattern; C,Op:BYTE); ASSEMBLER;
ASM
	mov     ax,X1
	dec     ax
	sub     X2,ax           { X2 = Breite }
	mov     ax,Y1
	call    CurMode.Mult    { DX:AX = Adresse }
	mov     di,X1
	add     di,ax
	adc     dx,0
	push    di
	push    dx
	push    word ptr op
	call    SetBank
	pop     di
	mov     bx,Y1

	mov     ax,CurMode.X
	sub     ax,X2
	mov     X1,ax

@@Loop:                         { DI = Adresse }
	cmp     bx,Y2           { BX = Y1 }
	jg      @@Ende
	and     bx,7
	les     si,Patt
	push    di

	push    di
	push    X2
	push    word ptr es:[si+bx]
	push    word ptr C
	push    word ptr Op
	call    VesaFill

	pop     di
	add     di,X2
	add     di,X1
	jc      @@NextBank
@@NoBS:
	mov     bx,Y1
	inc     bx
	mov     Y1,bx
	jmp     @@Loop
@@NextBank:
	push    word ptr Op
	call    SetNextBank
	jmp     @@NoBS
@@Ende:
END;

PROCEDURE TVesa.HLine(X1,Y1,X2:INTEGER; Mask,C,Op:BYTE); ASSEMBLER;
ASM
	mov     ax,Y1
	call    CurMode.Mult    { DX:AX = Adresse }
	mov     di,X1
	add     di,ax
	adc     dx,0
	push    di
	push    dx
	push    word ptr Op
	call    SetBank

				{ addresse iss schon gePUSHt }
	mov     ax,X2
	sub     ax,X1
	inc     ax
	push    ax
	push    word ptr Mask
	push    word ptr C
	push    word ptr Op
	call    VesaFill
END;

PROCEDURE TVesa.VLine(X1,Y1,Y2:INTEGER; Mask,C,Op:BYTE); ASSEMBLER;
ASM
	mov     bx,offset Opcodes
	mov     al,Op
	xlat
        mov     es, VesaDS
	mov     byte ptr es:[@@Patch+1],al

	mov     ax,Y1
	call    CurMode.Mult    { DX:AX = Adresse }
	mov     di,X1
	add     di,ax
	adc     dx,0
	push    di
	push    dx
	push    word ptr Op
	call    SetBank
	pop     di
	mov     bx,Y1
	mov     cl,bl
	and     cl,7
	mov     ch,Mask
	mov     al,C
	rol     ch,cl
	mov     es,VesaSeg
	dec     bx
@@Loop: inc     bx              { DI = Adresse }
	cmp     bx,Y2           { BX = Y1 }
	jg      @@Ende

	rol     ch,1
	jnc     @@Skip

@@Patch:db      26h,88h,05h     { mov es:[di],al }
@@Skip: add     di,CurMode.X
	jnc     @@Loop
@@NextBank:
	push    word ptr Op
	call    SetNextBank
	jmp     @@Loop
@@Ende:
END;

PROCEDURE TVesa.ResetVideo;
BEGIN
  SetBank(0,TRUE);
END;

PROCEDURE TVesa.PutBitMap(X1,Y1,X2,Y2:INTEGER; VWidth:INTEGER; VAR Map;
				   C,Back,Op:BYTE); ASSEMBLER;
ASM
	mov     al,Op
	mov     bx,offset Opcodes
	xlat
        mov     es, VesaDS
	mov     byte ptr es:[@@Patch+1],al
	mov     al,picadd
	mov     byte ptr es:[@@Patch2+1],al

	mov     ax,Y1
	call    CurMode.Mult
	mov     di,X1
	add     di,ax
	adc     dx,0

	push    di
	push    dx
	push    word ptr Op
	call    SetBank
	pop     di
	mov     cx,X2
	inc     cx
	sub     cx,X1
	mov     X2,cx                   { X2 = Breite (real) }
	mov     ax,CurMode.X
	sub     ax,cx
	mov     X1,ax                   { X1 = Breite des Schirms - Realbreite }

	mov     ah,PicAdd
	push    ds
	mov     es,VesaSeg
	lds     si,Map
	mov     cx,Y2
	sub     cx,Y1
	inc     cx

	mov     al,op
	or      al,Back
	or      al,C
	je      @@FunnyOptimisation

@@Loop: push    cx              { CX = Zeilenz„hler }
	push    si              { DS:SI -> Bild }
				{ ES:DI -> Schirm }
	mov     cx,X2
@@Line: mov     al,[si]
	inc     si
@@Patch2:db     04h,0           { add al,x }
	jne     @@nobg
	mov     al,Back
	jmp     @@ok
@@nobg: cmp     al,&C
	je      @@Skip
@@ok:
@@patch:db      26h,88h,05h
@@Skip: inc     di
	mov     ax,offset @@Weiter
	jz      @@SetBank
@@Weiter:
	loop    @@Line

	pop     si
	pop     cx
	add     si,VWidth
	add     di,X1
	mov     ax,offset @@NextLine
	jc      @@SetBank
@@NextLine:
	loop    @@Loop
	pop     ds
	jmp     @@Ende
@@SetBank:
	push    word ptr Op
	call    SetNextBank
	jmp     ax

{--- ES:DI -> Schirm,  DS:SI -> Bild,  CX = #Zeilen ---}
@@FunnyOptimisation:
	cld
	mov     Y1,cx
	mov     dl,ah
	mov     dh,ah
	mov     bx,si
@@FOLineLoop:
	mov     si,bx
	mov     cx,X2
	add     cx,di
	jnc     @@FOGehtInEins
	push    cx
	mov     cx,di
	neg     cx

@@FOLoop1:
	shr     cx,1
	jnc     @@FOLoop1a
	lodsb
	add     al,dl
	stosb
	jcxz    @@FOSkip1a
@@FOLoop1a:
	lodsw
	add     ax,dx
	stosw
	loop    @@FOLoop1a
@@FOSkip1a:
	push    cx              { CX=0 }
	call    SetNextBank
	pop     cx
@@FOGehtInEins:
	sub     cx,di
	jz      @@FOSkip2
	shr     cx,1
	jnc     @@FOLoop2a
	lodsb
	add     al,dl
	stosb
	jcxz    @@FOSkip2
@@FOLoop2a:
	lodsw
	add     ax,dx
	stosw
	loop    @@FOLoop2a
@@FOSkip2:
	add     bx,VWidth
	dec     Y1
	jz      @@FOEnde
	add     di,X1
	jnc     @@FOLineLoop
	push    0
	call    SetNextBank
	jmp     @@FOLineLoop
@@FOEnde:
	pop     ds
@@Ende:
END;

PROCEDURE VesaSetRGB(index:INTEGER; r,g,b:BYTE); ASSEMBLER;
VAR rgba:LONGINT;
ASM
        push    ds
        mov     ax, seg @data
        mov     ds, ax

        cmp     VesaPal, 0
        jz      @old
        { SDD wants the colors in "BGR" order (like Windows), not "RGB"
          as Ralf Brown documents. Allegro also uses BGR, so it must be
          right :-) }
        mov     al, b
        mov     ah, g
        mov     rgba.word.0, ax
        mov     al, r
        mov     ah, 0
        mov     rgba.word.2, ax
        mov     ax, 4F09h
        mov     bl, 0
        mov     cx, 1
        mov     dx, index
        lea     di, rgba
        call    Video
        cmp     ah, 0
        jz      @ok
@old:   mov     dx, 3C8h
        mov     al, index.byte
        cli
        out     dx, al
        inc     dx
        mov     al, r
        out     dx, al
        mov     al, g
        out     dx, al
        mov     al, b
        out     dx, al
        sti
@ok:
        pop     ds
END;

END.
