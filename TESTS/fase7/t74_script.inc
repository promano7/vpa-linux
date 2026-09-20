{ T7.4 - guion de dibujo comun a la referencia (ptcgraph) y a la via A.
  Solo Line + SetLineStyle + SetWriteMode + SetColor + SetViewPort. }
procedure DrawScript;
const
  Styles: array[0..4] of Word = (SolidLn, DottedLn, CenterLn, DashedLn, UserBitLn);
var
  i, s, t, x, y: Integer;
  a: Double;
begin
  { 1. abanico de 48 angulos desde un centro, solido fino }
  for i := 0 to 47 do
  begin
    a := i * Pi / 24;
    SetColor(1 + i mod 15);
    Line(120, 120, 120 + Round(110 * Cos(a)), 120 + Round(110 * Sin(a)));
  end;
  { 2. cada estilo x cada grosor, en las ocho direcciones y en los dos
       sentidos (la fase del patron depende de por donde se empieza) }
  for s := 0 to 4 do
    for t := 0 to 1 do
    begin
      SetLineStyle(Styles[s], $C3A5, 1 + 2 * t);
      SetColor(9 + s);
      x := 250 + s * 78; y := 10 + t * 120;
      Line(x, y, x + 70, y);            Line(x + 70, y + 8, x, y + 8);
      Line(x, y + 16, x, y + 100);      Line(x + 10, y + 100, x + 10, y + 16);
      Line(x + 18, y + 16, x + 70, y + 68);   Line(x + 70, y + 76, x + 18, y + 24);
      Line(x + 18, y + 100, x + 70, y + 84);  Line(x + 70, y + 90, x + 18, y + 106);
      Line(x + 30, y + 16, x + 44, y + 100);  Line(x + 56, y + 100, x + 50, y + 16);
    end;
  { 3. XOR: fondo de lineas solidas gruesas y, encima, lineas XOR de todos
       los estilos; la mitad se repiten para que se borren solas }
  SetWriteMode(NormalPut);
  SetLineStyle(SolidLn, 0, ThickWidth);
  for i := 0 to 19 do
  begin
    SetColor(1 + i mod 7);
    Line(10, 260 + i * 6, 310, 260 + i * 6);
  end;
  SetWriteMode(XORPut);
  for s := 0 to 4 do
    for t := 0 to 1 do
    begin
      SetLineStyle(Styles[s], $C3A5, 1 + 2 * t);
      SetColor(15 - s);
      Line(15 + s * 60, 250, 60 + s * 60, 390);
      Line(60 + s * 60 + t * 9, 250, 15 + s * 60 + t * 9, 390);
      if s mod 2 = 0 then
        Line(15 + s * 60, 250, 60 + s * 60, 390);
    end;
  { 4. viewport con recorte: lineas que lo cruzan por los cuatro lados }
  SetWriteMode(NormalPut);
  SetViewPort(340, 260, 620, 460, True);
  for s := 0 to 4 do
    for t := 0 to 1 do
    begin
      SetLineStyle(Styles[s], $C3A5, 1 + 2 * t);
      SetColor(10 + s);
      Line(-40, 10 + s * 35 + t * 12, 330, 40 + s * 35 + t * 12);
      Line(20 + s * 50 + t * 14, -30, 60 + s * 50 + t * 14, 240);
      Line(300, -20 + s * 9, -20, 230 - t * 17);
    end;
  SetViewPort(0, 0, 639, 479, True);
end;
