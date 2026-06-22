{ Sample program: just allocates memory,
  and prints how much it could get }
USES DPMI, SysExt;

VAR k:LONGINT;
    p:POINTER;

BEGIN
  InitDPMI;
  Writeln('DPMI = ', _DPMI);
  k := 0;
  WHILE MaxAvail > 1024 DO BEGIN
    GetMem(p, 1024);
    Inc(k);
    IF k AND 255 = 0 THEN Write(k, #13);
  END;
  Writeln('Could allocate ', k, ' kB');
END.
