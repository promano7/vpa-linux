Unit	Keyboard;		(* Keyboard functions *)
{$C MOVEABLE PRELOAD PERMANENT}

Interface

const	KbdShft	= 3;
	KbdCtrl	= 4;
	KbdAlt	= 8;

function FastKeyPressed : boolean;
function KeyPressed : boolean;
function ReadKey : word;
function PreviewKey : word; 	{ use only if KeyPressed }
function KbdFlags : byte;

Implementation

function FastKeyPressed : boolean; assembler;
  asm
	mov	es,Seg0040
	mov	ax,es:[1Ah]
	sub	ax,es:[1Ch]
  end;

function KeyPressed : boolean; assembler;
  asm
	int	28h
	mov	ah,11h
	int	16h
	mov	al,0
	jz	@@1
	mov	al,1
@@1:
  end;

procedure FetchKey; assembler;
  asm
	int	16h
	or	al,al
	jz	@@1
	cmp	al,0E0h
	jne	@@2
	or	ah,ah
	jz	@@1
	xor	al,al
	jmp	@@1
@@2:	xor	ah,ah
@@1:
  end;

function ReadKey : word; assembler;
  asm
	int	28h
	mov	ah,10h
	call	FetchKey
  end;

function PreviewKey : word; assembler;	{ use only if KeyPressed }
  asm
	mov	ah,11h
	call	FetchKey
  end;

function KbdFlags : byte; assembler;
  asm
	mov	es,Seg0040
	mov	al,es:[17h]
  end;

End.