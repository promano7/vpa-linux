{***************************************************************************}
{                                                                           }
{                    A N T I - A L I A S E D - F O N T                      }
{                                                                           }
{                     Nur im VESA-Modus, ohne Clipping ?                    }
{                                                                           }
{***************************************************************************}
{$A+,B-,D+,E-,F+,G+,I-,L-,N-,O-,R-,S-,V-,X+}

UNIT AAVesa;

INTERFACE

USES Drivers,Objects,AAFont;

TYPE PAAVesa=^TAAVesa;
     TAAVesa=OBJECT(TAAFont)
       PROCEDURE Show(X,Y:INTEGER; Wi,Hei,VWi:INTEGER; Col:BYTE; VAR P); VIRTUAL;
     END;

IMPLEMENTATION

USES Vesa256;

{$DEFINE drittens}   { wie Fonts rendern? }

PROCEDURE TAAVesa.Show(X,Y:INTEGER; Wi,Hei,VWi:INTEGER; Col:BYTE; VAR P); ASSEMBLER;
ASM
{$IFDEF zwotens}
        push    ds

        mov     cx,Wi
        sub     VWi,cx                  { Zu SI zu addieren nach Operation }
        shl     cx,3
        push    cx
        mov     ax,Y
        call    CurMode.Mult
        mov     es,VesaSeg
        mov     di,X
        shl     di,3
        add     di,ax
        adc     dx,0                    { ES:DI -> Screen Puffer, DX = Bank }
        push    dx
        push    0
        call    SetBank

        mov     ax,CurMode.X
        pop     cx
        sub     ax,cx
        mov     X,ax                    { zu DI zu addieren }

        lds     si,P                    { DS:SI -> Daten }

        mov     al,Col
        mov     ah,al

{--- los geht's ---}
        mov     dx,Hei
@@LineLoop:
        mov     cx,Wi
@@ColLoop:
        clc
@@BLLoop:
        mov     bl,[si]
        shr     bl,3
        and     bx,30
        clc
        jmp     word ptr cs:[@@Jumps+bx]

@@Jumps:dw      @@0,@@1, @@2, @@3, @@4, @@5, @@6, @@7
        dw      @@8,@@9,@@10,@@11,@@12,@@13,@@14,@@15
@@5:    mov     es:[di+1],al
@@1:    mov     es:[di+3],al
        jmp     @@Done
@@10:   mov     es:[di],al
@@2:    mov     es:[di+2],al
        jmp     @@Done
@@7:    mov     es:[di+1],al
@@3:    mov     es:[di+2],ax
        jmp     @@Done
@@4:    mov     es:[di+1],al
        jmp     @@Done
@@6:    mov     es:[di+1],ax
        jmp     @@Done
@@9:    mov     es:[di+3],al
@@8:    mov     es:[di],al
        jmp     @@Done
@@11:   mov     es:[di],al
        mov     es:[di+2],ax
        jmp     @@Done
@@13:   mov     es:[di+3],al
@@12:   mov     es:[di],ax
        jmp     @@Done
@@14:   mov     es:[di],ax
        mov     es:[di+2],al
        jmp     @@Done
@@15:   mov     es:[di],ax
        mov     es:[di+2],ax
@@0:
@@Done:
        jc      @@RealDone
        add     di,4
        mov     bl,[si]
        shl     bl,1
        inc     si
        and     bx,30
        stc
        jmp     word ptr cs:[@@Jumps+bx]
@@RealDone:
        add     di,4
        jnc     @@NoInc
        push    0
        call    SetNextBank
@@NoInc:
        dec     cx
        jnz     @@ColLoop

        dec     dx
        jz      @@Quit
        add     si,VWi
        add     di,X
        jnc     @@LineLoop
        push    0
        call    SetNextBank
        jmp     @@LineLoop
@@Quit:
        pop     ds
{$ENDIF}

{$IFDEF drittens}
        mov     ax,Wi
        sub     VWi,ax

        push    ds
        mov     ax,y
        call    CurMode.Mult    { -> DX:AX = Adresse }
        mov     es,VesaSeg
        mov     di,X
        shl     di,3
        add     di,ax
        adc     dx,0
        push    di
        push    dx
        push    0
        call    SetBank
        pop     di              { ES:DI -> Speicher }
        push    ds
        lds     si,P            { DS:SI -> Bitmap }
        mov     cx,Hei
@@Lines:push    cx
        mov     cx,Wi
        mov     al,Col
        mov     ah,al
@@Cols: mov     bl,[si]
        inc     si
        mov     dx,4
@@8:    add     bl,bl
        jnc     @@notCF
        jns     @@notSF
        mov     es:[di],ax
        jmp     @@nothing
@@notSF: { CF=1, SF=0 }
        mov     es:[di],al
        jmp     @@nothing
@@notCF: { CF = 0 }
        jns     @@nothing
        mov     es:[di+1],al
@@nothing:
        add     bl,bl
        add     di,2
        dec     dx
        jnz     @@8
        jnc     @@nonew
        push    0
        call    SetNextBank
@@nonew:loop    @@Cols
        pop     cx
        pop     ds
        add     si,VWi
        mov     ax,Wi
        shl     ax,3
        mov     bx,CurMode.X
        push    ds
        mov     ds,word ptr p+2
        sub     bx,ax
        add     di,bx
        jnc     @@none
        push    0
        call    SetNextBank
@@none: loop    @@Lines
        pop     ds
{$ENDIF}

{$IFDEF erstens}
        mov     ax,Wi
        sub     VWi,ax

        push    ds
        mov     ax,y
        call    CurMode.Mult    { -> DX:AX = Adresse }
        mov     es,VesaSeg
        mov     di,X
        shl     di,3
        add     di,ax
        adc     dx,0
        push    di
        push    dx
        push    0
        call    SetBank
        pop     di              { ES:DI -> Speicher }
        push    ds
        lds     si,P            { DS:SI -> Bitmap }
        mov     cx,Hei
@@Lines:push    cx
        mov     cx,Wi
        mov     ah,Col
@@Cols: mov     al,[si]
        inc     si
        mov     dx,8
@@8:    add     al,al
        jnc     @@nopix
        mov     es:[di],ah
@@nopix:add     di,1
        dec     dx
        jnz     @@8
        jnc     @@nonew
        push    0
        call    SetNextBank
@@nonew:loop    @@Cols
        pop     cx
        pop     ds
        add     si,VWi
        mov     ax,Wi
        shl     ax,3
        mov     bx,CurMode.X
        push    ds
        mov     ds,word ptr p+2
        sub     bx,ax
        add     di,bx
        jnc     @@none
        push    0
        call    SetNextBank
@@none: loop    @@Lines
        pop     ds
{$ENDIF}
END;

END.