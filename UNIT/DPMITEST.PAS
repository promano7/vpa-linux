{ Sample program: shows environment access, and reflection
  of interrupts to real mode }
{$I+}
USES DPMI, SysExt, DOS;

VAR i : INTEGER;
    p : POINTER;

BEGIN
  InitDPMI;
  IF _DPMI THEN Writeln('Hello, DPMI.') ELSE Writeln('Hello, REALMODE.');

  Writeln('COMSPEC = ', GetEnv('COMSPEC'));
  Writeln('MaxAvail = ', MaxAvail);
  Writeln('MemAvail = ', MemAvail);
  Writeln('Seg0040  = ', Seg0040);
  { Writeln('Mem[$40:$17] = ', Mem[$40:$17]); -- this works under some DPMI hosts but not all }
  ASM
        mov     ax, 0
        int     33h
  END;
  Writeln('Try pressing mouse buttons. Exit by pressing any key.');
  REPEAT
    ASM
        mov     ax, 3
        int     33h
        mov     i, bx
    END;
    Write(i:10,#13);
    i := 0;
    ASM
        mov	ah, 1
	int	16h
	jz      @@nokey
        mov     ah, 0
	int	16h
	mov	i, ax
     @@nokey:
    END;
  UNTIL i<>0;
END.
