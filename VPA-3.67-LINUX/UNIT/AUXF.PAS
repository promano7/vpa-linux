Unit	AuxF;		(* Auxiliary Functions And Definitions *)
{$C MOVEABLE PRELOAD PERMANENT}

Interface

type	int	= integer;
	long	= longint;
	CharArr	= array [1..MaxInt] of char;
	ByteArr	= array [1..MaxInt] of byte;
	IntArr	= array [1..MaxInt] of int;
	LongArr	= array [1..MaxInt div 2] of long;

const	Yes	= True;
	No	= False;
	On	= True;
	Off	= False;

function  IIF (b:boolean; a1,a2:int) : int;
function  IIFL(b:boolean; a1,a2:long) : long;
function  Within (a,a1,a2:int) : boolean;
function  Sign (a:int) : int;
function  Min (a,b:int) : int;
function  Max (a,b:int) : int;
function  MinL (a,b:long) : long;
function  MaxL (a,b:long) : long;
function  Diff (var arg1,arg2; count:word) : boolean;
procedure Delay (ms:word);
procedure Sound (hz:word);
procedure NoSound;
function  Timer : long;
(* procedure RealModeInt (n:byte;_ds,_es,_ax,_cx,_dx,_bx,_bp,_si,_di:word); *)

Implementation

var	DelayCnt: long;

function IIF (b:boolean; a1,a2:int) : int; assembler;
  asm
	mov	ax,a1
	cmp	b,True
	je	@@1
	mov	ax,a2
@@1:
  end;

function IIFL(b:boolean; a1,a2:long) : long; begin;
  if b then IIFL:=a1 else IIFL:=a2;
end;

function Within (a,a1,a2:int) : boolean; assembler;
  asm
	mov	al,No
	mov	bx,a
	cmp	bx,a1
	jl	@@1
	cmp	bx,a2
	je	@@1
	mov	al,Yes
@@1:
  end;

function Sign (a:int) : int; assembler;
  asm
	mov	ax,a
	or	ax,ax
	jz	@@1
	xchg	al,ah
	cbw
	mov	al,ah
	or	al,1
@@1:
  end;

function Min (a,b:int) : int; assembler;
  asm
	mov	ax,a
	cmp	ax,b
	jle	@@1
	mov	ax,b
@@1:
  end;

function Max (a,b:int) : int; assembler;
  asm
	mov	ax,a
	cmp	ax,b
	jge	@@1
	mov	ax,b
@@1:
  end;

function MinL (a,b:long) : long;
  begin
    if a<b then MinL:=a else MinL:=b;
  end;

function MaxL (a,b:long) : long;
  begin
    if a>b then MaxL:=a else MaxL:=b;
  end;

function Diff (var arg1,arg2; count:word) : boolean; assembler;
  asm
	push	ds
	cld
	lds	si,arg1
	les	di,arg2
	mov	cx,count
	repe	cmpsb
	mov	al,No
	je	@@1
	mov	al,Yes
@@1:	pop	ds
  end;

procedure DelayLoop; assembler;
  asm
@@1:    sub     ax,1
	sbb     dx,0
	jc      @@2
	cmp     bl,es:[di]
	je      @@1
@@2:
  end;

procedure Delay (ms:word); assembler;
  asm
	mov     cx,ms
	jcxz    @@2
	mov     es,seg0040
	xor     di,di
	mov     bl,es:[di]
@@1:    mov     ax,word ptr DelayCnt
	mov	dx,word ptr DelayCnt+2
	call    DelayLoop
	loop    @@1
@@2:
  end;

procedure Sound (hz:word); assembler;
  asm
	mov     bx,hz
	mov     ax,34DDh
	mov     dx,0012h
	cmp     dx,bx
	jnc     @@2
	div     bx
	mov     bx,ax
	in      al,61h
	test    al,3
	jnz     @@1
	or      al,3
	out     61h,al
	mov     al,0B6h
	out     43h,al
@@1:    mov     al,bl
	out     42h,al
	mov     al,bh
	out     42h,al
@@2:
  end;

procedure NoSound; assembler;
  asm
	in      al,61h
	and     al,0FCh
	out     61h,al
  end;

function Timer : long; assembler;
  asm
	mov	es,Seg0040
	mov	ax,es:[6Ch]
	mov	dx,es:[6Eh]
  end;

(*
type	RealRegs = record
		     EDI,ESI,EBP,dd0,EBX,EDX,ECX,EAX	: long;
		     Flags,ES,DS,FS,GS,IP0,CS0,SP,SS	: word;
		   end;

procedure RealModeInt (n:byte;_ds,_es,_ax,_cx,_dx,_bx,_bp,_si,_di:word); assembler;
  asm
	lea	di,RealModeRegs
	push	di
	push	ds

	push	ds
	pop	es
	push	ss
	pop	ds
	lea	si,_di
	xor	ax,ax
	cld

	movsw
	stosw		{EDI}
	movsw
	stosw		{ESI}
	movsw
	stosw		{EBP}
	stosw
	stosw		{dword 0}
	movsw
	stosw		{EBX}
	movsw
	stosw		{EDX}
	movsw
	stosw		{ECX}
	movsw
	stosw		{EAX}
	stosw		{flags}
	movsw		{ES}
	movsw		{DS}
	stosw		{FS}
	stosw		{GS}
	stosw		{IP}
	stosw		{CS}
	stosw		{SP}
	stosw		{SS}

	pop	ds
	pop	di

	mov	ax,0300h
	mov	bl,n
	xor	bh,bh
	xor	cx,cx
	int	31h
  end;
*)

Begin
  asm
	mov     es,Seg0040
	mov     di,006Ch
	mov     bl,es:[di]
@@2:    cmp     bl,es:[di]
	je      @@2
	mov     bl,es:[di]
	mov     ax,-28
	cwd
	call    DelayLoop
	not     ax
	not     dx
	mov     cx,55
	xor	bx,bx
	jmp	@@4
@@5:	inc	bx
	sub	dx,cx
@@4:	cmp	dx,cx
	jae	@@5
@@3:	div     cx
	mov     word ptr DelayCnt,ax
	mov     word ptr DelayCnt+2,bx
  end;
End.
