{***************************************************************************}
{                                                                           }
{                    A N T I - A L I A S E D - F O N T                      }
{                                                                           }
{                     Nur im VGA-Modus, ohne Clipping!                      }
{                                                                           }
{***************************************************************************}

UNIT AAFont;

INTERFACE

USES Drivers,Objects;

TYPE PAAFont=^TAAfont;
     TAAFont=OBJECT(TFont)
          FontPtr:POINTER;
          FontSize:LONGINT;
          Bitmap:POINTER;
          BmpSize:LONGINT;
          {VPA}
          CONSTRUCTOR InitPtr(P:POINTER);
          {/VPA}
          CONSTRUCTOR Init(VAR S:TStream);
          DESTRUCTOR Done; VIRTUAL;
          PROCEDURE OutText(X,Y:INTEGER; S:STRING); VIRTUAL;
          FUNCTION TextWidth(S:STRING):INTEGER; VIRTUAL;
          FUNCTION TextHeight(S:STRING):INTEGER; VIRTUAL;
          PROCEDURE LoadFont(VAR S:TStream); VIRTUAL;
          PROCEDURE Show(X,Y:INTEGER; Wi,Hei,VWi:INTEGER; Col:BYTE; VAR P); VIRTUAL;
          PROCEDURE ShowXX(X,Y:INTEGER; Wi,Hei,VWi:INTEGER; Col:BYTE; VAR P);
     END;

CONST AAColor:INTEGER=7;
      AABg:INTEGER=-1;
      AAClip:BOOLEAN=FALSE;     { Clipping von AAFonts. Noch nicht fertig }

IMPLEMENTATION

USES VGA640,SysExt;

PROCEDURE TAAFont.Show(X,Y:INTEGER; Wi,Hei,VWi:INTEGER; Col:BYTE; VAR P); ASSEMBLER;
ASM
        mov     ax,Wi
        sub     VWi,ax
        push    ds
        mov     ax,y
        mov     bx,ax
        shl     ax,2
        add     ax,bx
        shl     ax,4
        mov     di,x
        add     di,ax
        mov     es,SegA000
        mov     dx,3CEh
        mov     ax,0205h
        out     dx,ax
        mov     ax,0003h
        out     dx,ax
        mov     cx,Hei
        lds     si,p
        cld
        mov     al,8
        out     dx,al
        inc     dx
        mov     bh,Col
@@L1:   push    cx
        push    di
        mov     cx,Wi
@@L2:   outsb
        mov     bl,es:[di]
        mov     es:[di],bh
        inc     di
        loop    @@L2
        pop     di
@@Skip: pop     cx
        add     di,80
        add     si,VWi
        loop    @@L1
        pop     ds
END;

PROCEDURE TAAFont.ShowXX(X,Y:INTEGER; Wi,Hei,VWi:INTEGER; Col:BYTE; VAR P);
VAR i:INTEGER;
    yy:BYTE;
BEGIN
  IF AAClip THEN BEGIN
    WHILE Y<WinY1 DO BEGIN
      Dec(Hei);
      IF Hei<=0 THEN Exit;
      Inc(Y);
      ASM
          mov     ax,VWi
          add     word ptr P,ax
      END;
    END;
    i:=WinY2-Y+1;
    IF i<Hei THEN Hei:=i;
    IF Hei<=0 THEN Exit;
    i:=WinX1 DIV 8 - X;
    IF i>=0 THEN BEGIN
      Inc(X,i);
      Dec(Wi,i);
      IF Wi<=0 THEN Exit;
      ASM
          mov     ax,i
          add     word ptr p,ax
      END;
      ASM
          mov     cl,byte ptr WinX1
          neg     cl
          and     cl,7
          je      @skip
          mov     al,255
          shl     al,cl
          not     al
          mov     cx,hei
          les     bx,p
      @@1:and     es:[bx],al
          add     bx,VWi
          loop    @@1
      @skip:
      END;
    END;
    i:=(WinX2 DIV 8)-X;
    IF i<0 THEN Exit;
    IF i<Wi THEN BEGIN
      Wi:=i+1;
      ASM
          mov     al,255
          mov     cl,byte ptr WinX2
          and     cl,7
          xor     cl,7
          jz      @@Skip
          shl     al,cl
          les     bx,p
          mov     dx,Wi
          dec     dx
          add     bx,dx
          mov     cx,Hei
      @@1:and     es:[bx],al
          add     bx,VWi
          loop    @@1
      @@Skip:
      END;
    END;
  END;
  IF (Wi>0) AND (Hei>0) THEN Show(X,Y,Wi,Hei,VWi,Col,P);
END;

CONSTRUCTOR TAAFont.Init;
BEGIN
  TObject.Init;
  LoadFont(S);
END;

{VPA}
CONSTRUCTOR TAAFont.InitPtr(P:POINTER);
VAR Y:WORD;
BEGIN
  FontPtr:=P;
  FontSize:=0;
  Y:=TextHeight('A');
  BmpSize:=80*Y;
  Bitmap:=NIL;
  IF (BmpSize>=MaxAvail) OR (BmpSize>65520) THEN Fail;
  GetMem(Bitmap,BmpSize);
END;
{/VPA}

DESTRUCTOR TAAFont.Done;
BEGIN
  IF Bitmap<>NIL THEN Freemem(Bitmap,BmpSize);
  IF (FontPtr<>NIL) AND (FontSize>0) THEN Freemem(FontPtr,FontSize);
  TObject.Done;
END;

PROCEDURE TAAFont.LoadFont;
VAR Y:WORD;
BEGIN
  IF Bitmap<>NIL THEN Freemem(Bitmap,BmpSize);
  IF (FontPtr<>NIL) AND (FontSize>0) THEN Freemem(FontPtr,FontSize);
  FontSize:=S.GetSize;
  IF (FontSize>=MaxAvail) OR (FontSize>65520) THEN BEGIN
    Bitmap:=NIL;
    FontPtr:=NIL;
    Exit;
  END;
  GetMem(FontPtr,FontSize);
  S.Read(FontPtr^,FontSize);
  Y:=TextHeight('A');
  BmpSize:=80*Y;
  IF (BmpSize>=MaxAvail) OR (BmpSize>65520) THEN BEGIN
    Bitmap:=NIL;
    FreeMem(FontPtr,FontSize);
    FontPtr:=NIL;
    Exit;
  END;
  GetMem(Bitmap,BmpSize);
END;

VAR AAPtr:ARRAY[BYTE] OF WORD;
    Wid:ARRAY[BYTE] OF WORD;

PROCEDURE TAAFont.OutText;
VAR i,j,k:INTEGER;
    Ptr:LONGINT;
    Shift,XX,XXX,Hei:INTEGER;
    C:CHAR;
    Width:INTEGER;
    Typ:BYTE;
    Shift1,b,b1:BYTE;
    Total:INTEGER;
TYPE TFH=ARRAY[0..1] OF LONGINT;
BEGIN
  Inc(X,XOrg);
  Inc(Y,YOrg);
  IF Y>WinY2 THEN Exit;
  IF Y+Textheight('')<WinY1 THEN Exit;
  IF FontPtr=NIL THEN Exit;
  IF S='' THEN Exit;
  Ptr:=TFH(FontPtr^)[1];
  FillChar(Bitmap^,BmpSize,0);
  Shift:=X AND 7;
  Shift1:=Shift;
  XX:=0;
  Total:=0;
  FOR i:=1 TO Length(S) DO BEGIN
    C:=S[i];
    ASM
        push    ds
        les     di,Self
        lds     si,es:[di].TAAFont.FontPtr
        les     di,es:[di].TAAFont.Bitmap
        mov     dx,si
        add     di,XX
        add     si,word ptr &Ptr
        cld
        lodsw
        mov     Typ,al
        mov     cx,[si]                         { Font-H”he }
        mov     Hei,cx
        mov     bl,c
        mov     bh,0
        shl     bx,3
        mov     ax,[si+bx+10]                   { Breite }
        mov     Width,ax
	or	ax,ax
	jz	@@Skipit
        add     ax,7
        shr     ax,3
        mov     bx,[si+bx+4]                    { Zeichendaten }
        add     dx,bx
        mov     si,dx
        cld
@@L1:   push    cx
        push    ax
        push    di
        mov     cx,ax
@@L2:   push    cx
        mov     ah,0
        lodsb
        mov     cl,byte ptr Shift
        ror     ax,cl
        or      es:[di],ax
        inc     di
        pop     cx
        loop    @@L2
        pop     di
        pop     ax
        pop     cx
        add     di,80
        loop    @@L1
@@Skipit:
        pop     ds
        mov     bx,i
        add     bx,bx
        mov     word ptr AAPtr[bx],si
        mov     ax,Width
        mov     word ptr Wid[bx],ax
        add     total,ax
    END;
    Inc(Shift,Width);
    Inc(XX,Shift SHR 3);
    Shift:=Shift AND 7;
  END;
  XXX:=XX;
  IF (X+Total<WinX1) THEN Exit;
  IF Shift<>0 THEN Inc(XXX);
{  IF (Y>WinY2) OR (Y+Hei<WinY1) OR (X>WinX2) OR (X+8*XX<WinX1) THEN Exit;}
  ASM
        mov     ax,x
        sar     ax,3
        mov     k,ax
  END;
  j:=k+XX;
{  IF ((X<0) OR (j>=80)) AND (XX<>0) THEN BEGIN
    ASM
        les     di,Self
        les     di,es:[di].TAAFont.Bitmap
        mov     bx,X
        sar     bx,3
        mov     dx,XX
        mov     al,0
        cld
    @@Loop:
        cmp     bx,0
        jl      @@zero
        cmp     bx,80
        jl      @@Ok
    @@Zero:
        mov     cx,Hei
        push    di
    @@L:stosb
        add     di,79
        loop    @@L
        pop     di
    @@Ok:inc    di
        inc     bx
        dec     dx
        jne     @@Loop
    END;
  END;}
  ShowXX(k,Y,XXX,Hei,80,Color,Bitmap^);
  IF AABg<>-1 THEN BEGIN
    ASM
        les     di,Self
        les     di,es:[di].TAAFont.Bitmap
        mov     si,di
        mov     cx,Hei
        mov     dx,cx
        shl     cx,2
        add     cx,dx
        shl     cx,3
        cld
    @@Loop:
        seges lodsw
        not     ax
        stosw
        loop    @@Loop
    END;
    b:=$FF SHR Shift1;
    b1:=NOT ($FF SHR Shift);
    FOR i:=0 TO Hei-1 DO BEGIN
      PByteArray(Bitmap)^[80*i]:=PByteArray(Bitmap)^[80*i] AND b;
      IF Shift<>0 THEN
       PByteArray(Bitmap)^[80*i+XX]:=PByteArray(Bitmap)^[80*i+XX] AND b1;
    END;
    ShowXX(k,Y,XXX,Hei,80,AABg,Bitmap^);
  END;
  IF Typ=3 THEN
  FOR i:=1 TO Length(S) DO BEGIN
    ASM
        les     di,Self
        les     si,es:[di].TAAFont.FontPtr
        mov     bx,i
        add     bx,bx
        mov     si,word ptr AAPtr[bx]
        cld
        seges lodsw
        mov     cx,ax
        jcxz    @@Skip
    @@Loop:
        push    cx
        push    si
        push    es
     mov dl, AAclip
        seges lodsw
        add     ax,X
     or dl, dl
     mov dh, 0
     jz @@xok
     cmp ax, WinX1
     adc dh, 0
     cmp WinX2, ax
     adc dh, 0
 @@xok: xchg    ax,bx
        seges lodsw
        add     ax,Y
     or dl, dl
     jz @@yok
     cmp ax, WinY1
     adc dh, 0
     cmp WinY2, ax
     adc dh, 0
 @@yok:
     or dh, dh
     jnz @@notok
        push    bx
        push    ax
        push    AAColor
        push    wmPut
        les     di,Graph
        push    es
        push    di
        mov     di,es:[di]
        call    dword ptr [di+TGraph_PutPixel]
 @@notok:
        pop     es
        pop     si
        pop     cx
        add     si,4
        loop    @@Loop
    @@Skip:
    END;
    Inc(X,Wid[i]);
  END;
END;

FUNCTION TAAFont.TextWidth(S:STRING):INTEGER;
VAR i:INTEGER;
    Ptr:LONGINT;
    Shift,XX,Hei:INTEGER;
    C:CHAR;
    Width:INTEGER;
TYPE TFH=ARRAY[0..1] OF LONGINT;
BEGIN
  IF FontPtr=NIL THEN Exit;
  TextWidth:=0;
  IF S='' THEN Exit;
  Ptr:=TFH(FontPtr^)[1];
  Width:=0;
  FOR i:=1 TO Length(S) DO BEGIN
    C:=S[i];
    ASM
        push    ds
        les     di,Self
        lds     si,es:[di].TAAFont.FontPtr
        add     si,word ptr &Ptr
        mov     bl,c
        mov     bh,0
        shl     bx,3
        mov     ax,[si+bx+12]                   { Breite }
        add     Width,ax
        pop     ds
    END;
  END;
  TextWidth:=Width;
END;

FUNCTION TAAFont.TextHeight(S:STRING):INTEGER;
TYPE TFH=ARRAY[0..1] OF LONGINT;
VAR Ptr:LONGINT;
    i:INTEGER;
BEGIN
  Ptr:=TFH(FontPtr^)[1];
  ASM
        les     di,Self
        les     di,es:[di].TAAFont.FontPtr
        add     di,word ptr &Ptr
        mov     ax,es:[di+2]
        mov     i,ax
  END;
  TextHeight:=i;
END;

END.
