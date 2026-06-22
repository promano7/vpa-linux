{ This is a port of the configuration reader class of PCC 1.1.5.
  It provides a nice way to read and write configuration files
  with minimum effort. }

{$I switches.inc}

UNIT ConfigIO;
{$V-}

INTERFACE

TYPE CConfigIO = OBJECT
         basename : STRING[15];
         CONSTRUCTOR Init(CONST bn:STRING);
         FUNCTION    Match(CONST s:STRING):BOOLEAN; VIRTUAL;
         PROCEDURE   Assign(CONST s:STRING); VIRTUAL;
         PROCEDURE   Write(VAR p:TEXT; anew:BOOLEAN); VIRTUAL;

         PROCEDURE   WriteConfig;
         FUNCTION    ReadConfig:BOOLEAN;
     END;

IMPLEMENTATION

USES VPAData, StrF, Screen;

{$I-}

CONSTRUCTOR CConfigIO.Init(CONST bn:STRING);
BEGIN
  basename := bn;
END;

{ Match one config key, true iff matched }
FUNCTION CConfigIO.Match(CONST s:STRING):BOOLEAN;
BEGIN
END;

{ Assign S to the config key matched last }
PROCEDURE CConfigIO.Assign(CONST s:STRING);
BEGIN
END;

{ Write configuration, anew = true if completely new file }
PROCEDURE CConfigIO.Write(VAR p:TEXT; anew:BOOLEAN);
BEGIN
END;

PROCEDURE CConfigIO.WriteConfig;
VAR p, q  : TEXT;
    s, s1 : STRING;
    i     : INTEGER;
BEGIN
  System.Assign(p, addir + basename);
  Reset(p);
  IF IOResult<>0 THEN BEGIN
    Rewrite(p);
    IF IOResult=0 THEN BEGIN
      Write(p, TRUE);
      Close(p);
    END;
    Exit;
  END;

  { okay, we're modifying an existing file }
  System.Assign(q, addir + 'cf$$.tmp');
  Rewrite(q);
  IF IOResult=0 THEN BEGIN
    WHILE NOT EOF(p) DO BEGIN
      {... read config key ...}
      Readln(p, s);
      Trim(s);
      i := Pos('=', s);
      IF (s='') OR (s[1]='#') OR (i=0) THEN BEGIN
        Writeln(q, s);
      END ELSE BEGIN
        s1 := Copy(s, 1, i-1);
        Trim(s1);
        IF NOT Match(s1) THEN Writeln(q, s);
      END;
    END;
    Write(q, FALSE);
    Close(p);
    Close(q);
    Erase(p);
    IF IOResult<>0 THEN;
    Rename(q, addir + basename);
    IF IOResult<>0 THEN;
  END ELSE BEGIN
    Close(p);
  END;
END;

FUNCTION CConfigIO.ReadConfig:BOOLEAN;
VAR p     : TEXT;
    s, s1 : STRING;
    i     : INTEGER;
BEGIN
  System.Assign(p, addir + basename);
  Reset(p);
  IF IOResult<>0 THEN BEGIN
    System.Assign(p, basename);
    Reset(p);
    IF IOResult<>0 THEN BEGIN
      ReadConfig := FALSE;
      Exit;
    END;
    IF NOT GrMode THEN Writeln('Reading ',basename,'...');
  END ELSE BEGIN
    IF NOT GrMode THEN Writeln('Reading ',addir,basename,'...');
  END;
  WHILE NOT EOF(p) DO BEGIN
    Readln(p, s);
    Trim(s);
    i := Pos('=', s);
    IF (s<>'') AND (s[1]<>'#') AND (i<>0) THEN BEGIN
      s1 := Copy(s, i+1, 255);
      s  := Copy(s, 1, i-1);
      LTrim(s1);
      RTrim(s);
      IF Match(s) THEN Assign(s1);
    END;
  END;
  Close(p);
  ReadConfig:=TRUE;
END;

END.
