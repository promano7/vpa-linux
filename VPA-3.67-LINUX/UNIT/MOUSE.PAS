Unit	Mouse;
{$C MOVEABLE PRELOAD PERMANENT}
{$A-}
Interface

const	EvMouseMove	= 1;
	EvLtPress	= 2;
	EvLtRelease	= 4;
	EvRtPress	= 8;
	EvRtRelease	= $10;
	EvCtPress	= $20;
	EvCtRelease	= $40;
	AllEvents	= $7F;
	DisableHandler	= 0;
	LeftButton	= 1;
	RightButton	= 2;
	CenterButton	= 4;

type	PointerShape	= array [1..2,1..16] of word;

const	MousePresent		: boolean = False;
	MouseHandlerInstalled	: boolean = False;
	MouseDisabled		: boolean = True;

var	MouseX,MouseY		: integer;
	MouseButtons		: word;
	MouseEvent		: word;
	StatusBufferSize	: word;

{$IFDEF DPMI}
	StatusBufferSel,
	StatusBufferSeg		: word;
{$ELSE}
const	StatusBuffer		: pointer = nil;
{$ENDIF}

procedure EnableMouse;
procedure DisableMouse;
procedure ShowMouse;
procedure HideMouse;
procedure SuspendMouse;
procedure ResumeMouse;
procedure HookMouseEvent (event:byte; handler:pointer);
procedure UnHookMouseEvent (event:byte);
procedure SetPointerShape (var shape:PointerShape; hx,hy:word);
procedure SetMouseSensitivity (mx,my,mt:byte);
procedure SetMouseRange (x1,y1,x2,y2:word);
procedure MoveMouse (x,y:word);
procedure AllocateStatusBuffer;

{$IFDEF DPMI}
procedure DeAllocateStatusBuffer;
{$ENDIF}

procedure SaveMouseStatus;
procedure RestoreMouseStatus;


Implementation

{$IFDEF DPMI}

uses	WinAPI;

type	TRealRegs = record
		      RealEDI: Longint;
		      RealESI: Longint;
		      RealEBP: Longint;
		      Reserved: Longint;
		      RealEBX: Longint;
		      RealEDX: Longint;
		      RealECX: Longint;
		      RealEAX: Longint;
		      RealFlags: Word;
		      RealES: Word;
		      RealDS: Word;
		      RealFS: Word;
		      RealGS: Word;
		      RealIP: Word;
		      RealCS: Word;
		      RealSP: Word;
		      RealSS: Word;
		    end;
{$ENDIF}

procedure NullHandler; far; assembler;
  asm
  end;

const	HandlerTable	: array [0..6] of procedure =
	( NullHandler,NullHandler,NullHandler,NullHandler,NullHandler,NullHandler,NullHandler );
	HandlerBusy	: boolean = False;

procedure MouseHandler; far; assembler;
  asm
	push	ds
	mov	si,seg MouseDisabled
	mov	ds,si
	cmp	MouseDisabled,True
	jne	@@4
	cmp     ax,EvLtPress
	jne	@@3
	mov	ah,5
	mov	cl,13
	int	16h
	jmp	@@3
@@4:	cmp	HandlerBusy,True
	je	@@3
	mov	HandlerBusy,True
	mov	MouseEvent,ax
	mov	MouseX,cx
	mov	MouseY,dx
	mov	MouseButtons,bx
	lea     si,HandlerTable
@@1:	test	al,1
	jne	@@2
	shr	al,1
	add	si,4
	jmp	@@1
@@2:    call	dword ptr [si]
	mov	HandlerBusy,False
@@3:	pop	ds
  end;

{$IFDEF DPMI}
procedure MouseHandlerCB; far; assembler;
asm
        { ds:si -> real-mode ss:sp
          es:di -> registers }
        push    si
        push    ds
        push    di
        push    es

        { set up registers for mouse handler }
        mov     ax,es:[di].TRealRegs.RealEAX.word
        mov     bx,es:[di].TRealRegs.RealEBX.word
        mov     cx,es:[di].TRealRegs.RealECX.word
        mov     dx,es:[di].TRealRegs.RealEDX.word
        call    MouseHandler

        pop     es
        pop     di
        pop     ds
        pop     si

        { simulate real-mode return }
        cld
        lodsw
        mov     es:[di].TRealRegs.RealIP, ax
        lodsw
        mov     es:[di].TRealRegs.RealCS, ax
        add     es:[di].TRealRegs.RealSP, 4

        { es:di -> registers }
        iret
end;

const MouseHandlerRMCB : pointer = nil;

var   MouseHandlerRegs : TRealRegs;

procedure EnableMouse; assembler;
  asm
	cmp	MousePresent,True
	jne	@@1
	cmp	MouseHandlerInstalled,True
	je	@@1

        { allocate real-mode callback if needed }
        mov     ax, MouseHandlerRMCB.word.2
        or      ax, ax
        jnz     @cbok

        push    ds
        push    ds
        pop     es
        mov     di, offset MouseHandlerRegs
        mov     ax, seg MouseHandlerCB
        mov     ds, ax
        mov     si, offset MouseHandlerCB
        mov     ax, 0303h
        int     31h
        pop     ds
        jc      @cbfail         { ignore silently }

        mov     MouseHandlerRMCB.word.0, dx
        mov     MouseHandlerRMCB.word.2, cx

  @cbok:
        mov     MouseHandlerRegs.RealEAX.word, 0Ch
        mov     MouseHandlerRegs.RealECX.word, AllEvents
        mov     ax, MouseHandlerRMCB.word.0
        mov     MouseHandlerRegs.RealEDX.word, ax
        mov     ax, MouseHandlerRMCB.word.2
        mov     MouseHandlerRegs.RealES, ax

        mov     ax, 300h
        mov     bx, 33h
        mov     cx, 0
        mov     di, offset MouseHandlerRegs
        push    ds
        pop     es
	int	31h

  @cbfail:
	mov	ax,1
	int	33h
	mov	MouseHandlerInstalled,True
	mov	MouseDisabled,False
	mov	MouseX,160
	mov	MouseY,100
	mov	MouseButtons,0
@@1:
  end;
{$ELSE}
procedure EnableMouse; assembler;
  asm
	cmp	MousePresent,True
	jne	@@1
	cmp	MouseHandlerInstalled,True
	je	@@1
	mov	ax,0Ch
	mov	cx,AllEvents
	mov	dx,seg MouseHandler
	mov	es,dx
	lea	dx,MouseHandler
	int	33h
	mov	ax,1
	int	33h
	mov	MouseHandlerInstalled,True
	mov	MouseDisabled,False
	mov	MouseX,160
	mov	MouseY,100
	mov	MouseButtons,0
@@1:
  end;
{$ENDIF}

procedure DisableMouse; assembler;
  asm
	cmp	MouseHandlerInstalled,True
	jne	@@1
	mov	ax,0Ch
	xor	cx,cx
	int	33h
	mov	ax,2
	int	33h
	mov	MouseHandlerInstalled,False
@@1:
  end;

procedure ShowMouse; assembler;
  asm
	mov	ax,1
	int	33h
  end;

procedure HideMouse; assembler;
  asm
	mov	ax,2
	int	33h
  end;

procedure SuspendMouse; assembler;
  asm
	mov	ax,1Fh
	int	33h
  end;

procedure ResumeMouse; assembler;
  asm
	mov	ax,20h
	int	33h
  end;

procedure HookMouseEvent (event:byte; handler:pointer); assembler;
  asm
	mov	al,event
	push	ds
	pop	es
	lea	di,HandlerTable
@@1:	test	al,1
	jne	@@2
	shr	al,1
	add	di,4
	jmp	@@1
@@2:	mov	ax,word ptr handler
	stosw
	mov	ax,word ptr handler+2
	stosw
  end;

procedure UnHookMouseEvent (event:byte);
  begin
    HookMouseEvent(event,@NullHandler)
  end;

procedure SetPointerShape (var shape:PointerShape; hx,hy:word);
{$IFDEF DPMI}
  var	segment,selector : word;
{$ENDIF}
  begin
    asm
{$IFDEF DPMI}
	push	0
	push	64
	call	GlobalDOSAlloc
	mov	segment,dx
	mov	selector,ax

	push	ds
	lds	si,shape
	mov	es,ax
	xor	di,di
	cld
	mov	cx,32
	rep	movsw
	pop	ds

	mov	ax,ds
	mov	es,ax
	lea	di,RealModeRegs
	mov     word ptr [di].TRealRegs.RealEAX,9
	mov	ax,hx
	mov     word ptr [di].TRealRegs.RealEBX,ax
	mov	ax,hy
	mov     word ptr [di].TRealRegs.RealECX,ax
	mov     word ptr [di].TRealRegs.RealES,dx	{dx=segment}
	mov     word ptr [di].TRealRegs.RealEDX,0
	mov     word ptr [di].TRealRegs.RealSS,0
	mov     word ptr [di].TRealRegs.RealSP,0	{SS=SP=0}
	mov	ax,0300h
	mov	bx,0033h
	xor	cx,cx
	int	31h

	push	selector
	call	GlobalDOSFree
{$ELSE}
	mov	ax,9
	mov	bx,hx
	mov	cx,hy
	les	dx,shape
	int	33h		{this causes GPF in Protected Mode}
{$ENDIF}
   end;
  end;

procedure SetMouseSensitivity (mx,my,mt:byte); assembler;
  asm
	mov	ax,001Ah
	xor	bx,bx
	xor	cx,cx
	xor	dx,dx
	mov	bl,mx
	mov	cl,my
	mov	dl,mt
	int	33h
  end;

procedure SetMouseRange (x1,y1,x2,y2:word); assembler;
  asm
	mov	ax,7
	mov	cx,x1
	mov	dx,x2
	int	33h
	mov	ax,8
	mov	cx,y1
	mov	dx,y2
	int	33h
  end;

procedure MoveMouse (x,y:word); assembler;
  asm
	mov	ax,4
	mov	cx,x
	mov	dx,y
	int	33h
	mov	ax,3
	int	33h
	mov	MouseX,cx
	mov	MouseY,dx
  end;

{$IFDEF DPMI}

procedure AllocateStatusBuffer; assembler;
  asm
	mov	ax,15h
	int	33h
	mov	StatusBufferSize,bx
	or	bx,bx
	jz	@@1
	push	0
	push	StatusBufferSize
	call	GlobalDOSAlloc
	mov	StatusBufferSeg,dx
	mov	StatusBufferSel,ax
@@1:
  end;

procedure DeAllocateStatusBuffer; assembler;
  asm
	cmp	StatusBufferSize,0
	jz	@@1
	push	StatusBufferSel
	call	GlobalDOSFree
@@1:
  end;

procedure SaveMouseStatus; assembler;
  asm
	mov	ax,ds
	mov	es,ax
	lea	di,RealModeRegs
	mov     word ptr [di].TRealRegs.RealEAX,16h
	mov	ax,StatusBufferSize
	mov     word ptr [di].TRealRegs.RealEBX,ax
	mov	ax,StatusBufferSeg
	mov     word ptr [di].TRealRegs.RealES,ax
	mov     word ptr [di].TRealRegs.RealEDX,0
	mov     word ptr [di].TRealRegs.RealSS,0
	mov     word ptr [di].TRealRegs.RealSP,0	{SS=SP=0}
	mov	ax,0300h
	mov	bx,0033h
	xor	cx,cx
	int	31h
  end;

procedure RestoreMouseStatus; assembler;
  asm
	mov	ax,ds
	mov	es,ax
	lea	di,RealModeRegs
	mov     word ptr [di].TRealRegs.RealEAX,17h
	mov	ax,StatusBufferSize
	mov     word ptr [di].TRealRegs.RealEBX,ax
	mov	ax,StatusBufferSeg
	mov     word ptr [di].TRealRegs.RealES,ax
	mov     word ptr [di].TRealRegs.RealEDX,0
	mov     word ptr [di].TRealRegs.RealSS,0
	mov     word ptr [di].TRealRegs.RealSP,0	{SS=SP=0}
	mov	ax,0300h
	mov	bx,0033h
	xor	cx,cx
	int	31h
  end;

{$ELSE}

procedure AllocateStatusBuffer;
  begin
    asm
	mov	ax,15h
	int	33h
	mov	StatusBufferSize,bx
    end;
    if StatusBufferSize<>0 then GetMem(StatusBuffer,StatusBufferSize);
  end;

procedure SaveMouseStatus; assembler;
  asm
	mov	ax,16h
	les	dx,StatusBuffer
	mov	bx,StatusBufferSize
	int	33h
  end;

procedure RestoreMouseStatus; assembler;
  asm
	mov	ax,17h
	les	dx,StatusBuffer
	mov	bx,StatusBufferSize
	int	33h
  end;

{$ENDIF}

Begin	      (* Initialization part *)
  asm
	xor	ax,ax
	int	33h
	xor	bx,bx
	and	al,1
	mov	MousePresent,al
  end;
End.
