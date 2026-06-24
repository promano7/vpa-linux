Unit	ScrSaver;	{* VPA Screen Saver *}
{$V-}

Interface

procedure ScreenSaver;

Implementation

uses	AuxF,ptcgraph,Keyboard,Mouse,Screen,VPAData,TCombat;

const	ShipPic	: set of byte =
		[ 5..7,9..20,29..33,45..47,49,50,54..69,72..74,76..80,
		  84..90,97..114,117..125,128..137,140..144,146..149 ];

(*procedure GrayScale;
  var	gpal	: array [0..15] of byte;
	i,k	: int;
  begin
    for i:=0 to 15 do
    begin
      k:=pal[i,1]+pal[i,2]+pal[i,3];
      if k<48  then k:=Black else
      if k<96  then k:=DarkGray else
      if k<144 then k:=LightGray else
      k:=White;
      gpal[i]:=k;
    end;
    asm
	push	ds
	cld
	lds	si,dword ptr img+4
	lodsw		{ image header contains xsize-1, ysize-1 }
	shr	ax,3
	inc	ax
	mov	di,ax	{ di = x size in bytes }
	lodsw
	inc	ax
	mov	dx,ax	{ dh = y size }

@@1:	mov	bx,di
	push	si
	mov	bh,1	{ bh = bit mask }

@@2:	mov	cl,8

@@3:	xor	ah,ah
	mov	ch,4

	push	si
@@4:    mov	al,[si]	{ get color into ah }
	and	al,bh
	shl	ah,1
	or	al,al
	jz	@@41
	inc	ah
@@41:   add	si,di
	dec	ch
	jnz	@@4
	pop	si

	push	bx
	lea	bx,gpal	{ convert color in ah }
	xchg	al,ah
	xor	ah,ah
	add	bx,ax
	mov	ah,ss:[bx]
	pop	bx

	mov	ch,4
	ror	ah,3
	push	si
@@5:	mov	al,[si]	{ set new color from ah }
	not	bh
	and	al,bh
	not	bh
	test	ah,1
	jz	@@51
	or	al,bh
@@51:   mov	[si],al
	rol	ah,1
	add	si,di
	dec	ch
	jnz	@@5
	pop	si

	rol	bh,1
	dec	cl
	jnz	@@3

	inc	si
	dec	bl
	jnz	@@2

	pop	si
	add	si,di
	add	si,di
	add	si,di
	add	si,di
	dec	dx
	jnz	@@1

	pop	ds
    end;
  end;*)

procedure ScreenSaver;
  var	pic		: byte;
	x,y,dx,dy,sx,sy	: int;	{ sx,sy = image dimensions-1 }
	vert		: boolean;
	lr		: LRType;
{	eimg	: pointer;}
	pal0,pal1,pal2	: array [0..15,1..3] of byte;
  begin
    MouseOff;
    ClearDevice;
    UnlockReservedMemory(ReservedMemory);
    TCombatInit(No);
    Move(pal,pal0,SizeOf(pal0));	{ store initial palette }
{    CheckMem(ImgSize);
    GetMem(eimg,ImgSize);}
    lr:=Right;
{    GrayScale;}
{    Move(img[Right]^,eimg^,ImgSize);}
    repeat
      repeat pic:=Random(150)+1 until pic in ShipPic;
      vert:=(pic in RotPic) and (Random(100) and 1=0);
      if not vert then lr:=LRType(Random(100) and 1);
      Move(pal0,pal,SizeOf(pal0));	{ restore initial palette }
      LoadPic(Left,pic,No,No,No,No);	{ just to get ship palette }
      Move(pal,pal1,SizeOf(pal1));	{ store uncut ship palette }
      FillChar(img[lr]^,ImgSize,0);
      LoadPic(lr,pic,(not vert) and (pic in RotPic),(lr=Right) xor (pic in FliPic),No,Yes);
      LoadPic(LRType(byte(lr) xor 1),ExplPic,No,No,Yes,Yes);
      Move(pal,pal2,SizeOf(pal2));	{ store ship+expl palette }
      Move(pal1,pal,SizeOf(pal1));	{ set uncut ship palette }
      SetPal;
{      GrayScale;}
(*      asm
	{ create a combination of 2 images }
	push	ds

	les	di,dword ptr img
	lds	si,dword ptr img+4
	lodsw		{ image header contains xsize-1, ysize-1 }
	mov	sx,ax
	mov	dl,al
	shr	dl,3
	inc	dl	{ dl = x size in bytes }
	stosw		{ x size = unchanged }
	lodsw
	mov	sy,ax
	mov	dh,al
	inc	dh	{ dh = y size in lines }
	cmp	vert,Yes
	jne	@@65
	inc	ax	{ new y size = +1 }
@@65:	stosw
	mov	al,dh
	mul	dl
	shl	ax,2
	mov	bx,ax	{ bx = image size in bytes }
	mov	cx,ax
	push	si
	push	di
	rep	movsb	{ copy image 1 to image 2 }
	cmp	vert,Yes
	jne	@@66
	xor	ax,ax
	mov	cl,dl
	shl	cl,4
	rep	stosb	{ add 1 blank line (4 bit planes) }
@@66:	pop	di
	pop	si

	cmp	vert,Yes
	jne	@@60

	{ vertical shift }
	mov	al,dl
	shl	ax,2
	add	di,ax	{ shift by 1 line (4 bit planes) }
	mov	cx,bx
@@61:	lodsb
	xor	es:[di],al
	inc	di
	loop	@@61
	jmp	@@69

@@60:	{ horizontal shift; note: there is a blank column at the right edge }
	mov	cx,bx
	xor	bh,bh
@@62:	lodsb
	xor	ah,ah
	ror	ax,1
	or	al,bh
	mov	bh,ah
	xor	es:[di],al
	inc	di
	loop	@@62

@@69:   pop	ds
      end; *)
      sx:=img[lr]^[1];
      if vert then inc(img[lr]^[3]);
      sy:=img[lr]^[3];
      if vert then
      begin
	x:=Random(639-sx); y:=479-sy;
	dx:=0; dy:=-1;
      end
      else begin
	y:=Random(479-sy-30)+30;
	dy:=0;
	if lr=Right then begin x:=639-sx; dx:=-1 end
		    else begin x:=1; dx:=1 end;
      end;
{      PutImage(x,y,img[Right]^,NormalPut);
      Delay(500);}
      repeat
{	if dx<=0 then begin}
{	end;}
	Delay(18);
		{ (int 28h = ceder CPU en DOS; no aplica en Linux) }
	inc(x,dx); inc(y,dy);
	WaitRetrace;
        if not useSVGA then PutImage(x,y,img[lr]^,NormalPut)
                       else
                         begin
	                   convertImage(img[lr]^,img256);
                           PutImage(x,y,img256,NormalPut);
                         end;
	  until (x<=0) or (x>=640-sx) or (y<=0) or KeyPressed or (mEvent<>0);
      {delete ship picture}
        if not useSVGA then PutImage(x,y,img[lr]^,XORPut)
                       else
                         begin
	                   convertImage(img[lr]^,img256);
                           PutImage(x,y,img256,XORPut);
                         end;
	  dx:=Min(Max(x+sx div 2-52,0),640-104);
      dy:=Max(y+sy div 2-46,0);
      lr:=LRType(byte(lr) xor 1);
      Move(pal2,pal,SizeOf(pal2));	{ set ship+expl palette }
      SetPal;
        if not useSVGA then
                         begin
	                   PutImage(dx,dy,img[lr]^,XORPut);	{ draw expl }
	                   Delay(500);
	                   PutImage(dx,dy,img[lr]^,XORPut);
                         end
                       else
                         begin
	                   convertImage(img[lr]^,img256);
	                   PutImage(dx,dy,img256,XORPut);	{ draw expl }
	                   Delay(500);
	                   convertImage(img[lr]^,img256);
	                   PutImage(dx,dy,img256,XORPut);
                         end;
    until KeyPressed or (mEvent<>0);
    if KeyPressed then ReadKey;
    mEvent:=0;
{    FreeMem(eimg,ImgSize);}
    TCombatFinish;
    LockReservedMemory;
    if BadVideoOrMouse then RestoreCrtMode;
	if useSVGA then
    	SetGraphMode(3)
    else	
      if customBGI then SetGraphMode(bgiMode)
      else SetGraphMode(VGAHi);
    DrawRightScreen;
    MouseOn;
    ResetMouse;
    if lock<>0 then begin force:=lock; ForceKey:=13 end;
    ch:=2;		{ redraw map }
  end;

End.
