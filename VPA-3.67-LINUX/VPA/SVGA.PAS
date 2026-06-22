Unit SVGA;
{$V-}

Interface

Procedure SVGAProc;

Implementation

{ svga.obj (driver SVGA/VESA) descartado en el port }

Procedure SVGAProc;
begin
  { stub no-op: SVGA/VESA no se usa en el port (useSVGA siempre False) }
end;

END.
