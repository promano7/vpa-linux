{$I switches.inc}
Unit TCombat;           (* The True VGA Planets Combat Simulation *)
{$V-}
{$A-}
{DEFINE GR_DEBUG}
{DEFINE TIMEBAR}

Interface

uses    AuxF,VPAData;

const   RotPic  : set of byte =
                [ 5..7,9..20,29..34,45..47,49,50,54..69,72..74,76..82,85..90,
                  92,96..105,108..110,112..114,119,120,128..136,140,
                  142,143,146,147 ];
        FliPic  : set of byte = [ 1..4,23..28,39..43,84,106,117,125,141,144 ];
        ExplPic = 51;
        SurrPic = 115;
        { VCR palette colors (default Black & White) }
        _Green  = 11;
        _Red    = 12;
        _Gray   = 13;
        _Yellow = 14;
        { Colores dedicados del planeta-disco (indices libres de la paleta 256;
          los sprites usan 0..15, SetPal fija 1..15, asi que 208..211 estan libres).
          RGB muestreados del planeta de PVCR.EXE. }
        clPlSalmon = 208;   { base salmon/coral }
        clPlTan    = 209;   { tan claro (brillo) }
        clPlDark   = 210;   { rojo oscuro (relieve) }
        clPlMid    = 211;   { salmon medio (sombra) }
        { PLANETS palette colors (default Black,White,Brown,LGray,LBlue,LGreen,LRed,Yellow)}
        __Gray          = 8;
        __DarkGray      = 11;
        __VeryDarkGray  = 13;

        ImgSize = 12 + 104*104*2; { imagen ptcgraph 8bpp: 3 longint cabecera + 1 word/pixel }

var     img     : array [LRtype] of ^IntArr;
        pal     : array [0..15,1..3] of byte;
        img256: array [0..104*104+16] of byte;

procedure convertImage(var sr; var dst:array of byte);
procedure Combat (var vcr:VCRData; Animate:boolean; speed:byte; Sounds,KeyIntr:boolean);
procedure CombatPHost (var vcr:VCRData; Animate:boolean; speed:byte; Sounds,KeyIntr:boolean);
procedure TCombatInit (VCRPalette:boolean);
procedure TCombatFinish;
procedure LoadPic (lr:LRtype; pic:byte; rot,fli,truncpal,process:boolean);
procedure SetPal;

Implementation

uses    ptcgraph,StrF,Screen,Keyboard,PVCRALG;

const   SY      = 146;
        SR      = 30;
        BR      = 2;
        LY      = 416;
        LN      = 4;
        TN      = 10;
        TR      = 5;
        TY      = 391;
        FR      = 7;
        ER      = 3;
        DDelay  = 5;
        WAIT    : byte = 5*DDelay;
        TX      : array [LRType] of byte = (13,53);

type    ImArr   = array[0..103,0..103] of byte;

const   VCRpal  : array [0..3*16-1] of byte =           { VCR palette }
                      ( 0,0,0,          {0}  {Black}
                        0,0,0,          {1}  {l-1}
                        0,0,0,          {2}  {l-2}
                        0,0,0,          {3}  {l-3}
                        0,0,0,          {4}  {l-4}
                        0,0,0,          {5}  {l-5}
                        0,0,0,          {6}  {r-1}
                        0,0,0,          {7}  {r-2}      { R,B,G }
                        0,0,0,          {8}  {r-3}
                        0,0,0,          {9}  {r-4}
                        0,0,0,          {10} {r-5}
                        $0C, $0C, $37,  {11} {Green}
                        $3A, $00, $00,  {12} {Red}
                        $0B, $0B, $0B,  {13} {Gray}
                        $3C, $00, $3B,  {14} {Yellow}
                        $39, $39, $39   {15} {White}    );

        PLpal   : array [0..3*16-1] of byte =           { PLANETS.EXE palette }
                      ( $00, $00, $00,
                        $18, $00, $01,
                        $1F, $15, $16,
                        $22, $18, $1D,          { R,B,G }
                        $1C, $17, $20,
                        $12, $0E, $09,
                        $25, $03, $12,
                        $2A, $2A, $2A,
                        $14, $16, $13,
                        $00, $3E, $00,
                        $0C, $0C, $37,
                        $11, $11, $11,
                        $3A, $00, $00,
                        $0B, $0B, $0B,
                        $3C, $00, $3B,
                        $39, $39, $39 );

        (* Lemmings Gag *)

        Lemming : array [0..7,LRType,1..52] of byte =
        (
             ( (7,0,11,0,
                $00,$00,$00,$00,
{........}      $00,$00,$00,$00,        { 2 = Green = 11 = 1011 }
{..2222..}      $3C,$00,$3C,$3C,        { 0 = White = 15 = 1111 }
{..220...}      $38,$08,$38,$38,        { 1 = Red   = 12 = 1100 }
{...000..}      $1C,$1C,$1C,$1C,
{...01...}      $18,$18,$08,$08,
{...01...}      $18,$18,$08,$08,
{...01...}      $18,$18,$08,$08,
{...11...}      $18,$18,$00,$00,
{..011...}      $38,$38,$20,$20,
{...00...}      $18,$18,$18,$18,
                $00,$00,$00,$00),
               (7,0,11,0,
                $00,$00,$00,$00,
                $00,$00,$00,$00,
                $3C,$00,$3C,$3C,
                $1C,$10,$1C,$1C,
                $38,$38,$38,$38,
                $18,$18,$10,$10,
                $18,$18,$10,$10,
                $18,$18,$10,$10,
                $18,$18,$00,$00,
                $1C,$1C,$04,$04,
                $18,$18,$18,$18,
                $00,$00,$00,$00) ),
             ( (7,0,11,0,
                $00,$00,$00,$00,
{...2.2..}      $14,$00,$14,$14,
{..222...}      $38,$00,$38,$38,
{..220...}      $38,$08,$38,$38,
{...000..}      $1C,$1C,$1C,$1C,
{...01...}      $18,$18,$10,$10,
{..011...}      $38,$38,$20,$20,
{..011.0.}      $3A,$3A,$22,$22,
{...11.0.}      $1A,$1A,$02,$02,
{..11.0..}      $34,$34,$04,$04,
{..00....}      $30,$30,$30,$30,
                $00,$00,$00,$00),
               (7,0,11,0,
                $00,$00,$00,$00,
                $28,$00,$28,$28,
                $1C,$00,$1C,$1C,
                $1C,$10,$1C,$1C,
                $38,$38,$38,$38,
                $18,$18,$08,$08,
                $1C,$1C,$04,$04,
                $5C,$5C,$44,$44,
                $58,$58,$40,$40,
                $2C,$2C,$20,$20,
                $0C,$0C,$0C,$0C,
                $00,$00,$00,$00) ),
             ( (7,0,11,0,
                $00,$00,$00,$00,
{........}      $00,$00,$00,$00,
{..2.2...}      $28,$00,$28,$28,
{..222...}      $38,$00,$38,$38,
{...20...}      $18,$08,$18,$18,
{...000..}      $1C,$1C,$1C,$1C,
{..001...}      $38,$38,$30,$30,
{..011...}      $38,$38,$20,$20,
{.00111..}      $7C,$7C,$60,$60,
{..1111..}      $3C,$3C,$00,$00,
{.00..00.}      $66,$66,$66,$66,
                $00,$00,$00,$00),
               (7,0,11,0,
                $00,$00,$00,$00,
                $00,$00,$00,$00,
                $14,$00,$14,$14,
                $1C,$00,$1C,$1C,
                $18,$10,$18,$18,
                $38,$38,$38,$38,
                $1C,$1C,$0C,$0C,
                $1C,$1C,$04,$04,
                $3E,$3E,$06,$06,
                $3C,$3C,$00,$00,
                $66,$66,$66,$66,
                $00,$00,$00,$00) ),
             ( (7,0,11,0,
                $00,$00,$00,$00,
{........}      $00,$00,$00,$00,
{...22...}      $18,$00,$18,$18,
{..2202..}      $3C,$08,$3C,$3C,
{..2000..}      $3C,$1C,$3C,$3C,
{...01...}      $18,$18,$10,$10,
{...01...}      $18,$18,$10,$10,
{..011...}      $38,$38,$20,$20,
{...11...}      $18,$18,$00,$00,
{.01111..}      $7C,$7C,$40,$40,
{.0..00..}      $4C,$4C,$4C,$4C,
                $00,$00,$00,$00),
               (7,0,11,0,
                $00,$00,$00,$00,
                $00,$00,$00,$00,
                $18,$00,$18,$18,
                $3C,$10,$3C,$3C,
                $3C,$38,$3C,$3C,
                $18,$18,$08,$08,
                $18,$18,$08,$08,
                $1C,$1C,$04,$04,
                $18,$18,$00,$00,
                $3E,$3E,$02,$02,
                $32,$32,$32,$32,
                $00,$00,$00,$00) ),
             ( (7,0,11,0,
                $00,$00,$00,$00,
{........}      $00,$00,$00,$00,
{..2222..}      $3C,$00,$3C,$3C,
{..220...}      $38,$08,$38,$38,
{..2000..}      $3C,$1C,$3C,$3C,
{...01...}      $18,$18,$10,$10,
{...10...}      $18,$18,$08,$08,
{...01...}      $18,$18,$10,$10,
{...11...}      $18,$18,$00,$00,
{..011...}      $38,$38,$20,$20,
{...00...}      $18,$18,$18,$18,
                $00,$00,$00,$00),
               (7,0,11,0,
                $00,$00,$00,$00,
                $00,$00,$00,$00,
                $3C,$00,$3C,$3C,
                $1C,$10,$1C,$1C,
                $3C,$38,$3C,$3C,
                $18,$18,$08,$08,
                $18,$18,$10,$10,
                $18,$18,$08,$08,
                $18,$18,$00,$00,
                $1C,$1C,$04,$04,
                $18,$18,$18,$18,
                $00,$00,$00,$00) ),
             ( (7,0,11,0,
                $00,$00,$00,$00,
{...2.2..}      $14,$00,$14,$14,
{..222...}      $38,$00,$38,$38,
{..220...}      $38,$08,$38,$38,
{...000..}      $1C,$1C,$1C,$1C,
{...01...}      $18,$18,$10,$10,
{...10...}      $18,$18,$08,$08,
{...10.0.}      $1A,$1A,$0A,$0A,
{...11.0.}      $1A,$1A,$02,$02,
{..11.0..}      $34,$34,$04,$04,
{..00....}      $30,$30,$30,$30,
                $00,$00,$00,$00),
               (7,0,11,0,
                $00,$00,$00,$00,
                $28,$00,$28,$28,
                $1C,$00,$1C,$1C,
                $1C,$10,$1C,$1C,
                $38,$38,$38,$38,
                $18,$18,$08,$08,
                $18,$18,$10,$10,
                $58,$58,$50,$50,
                $58,$58,$40,$40,
                $2C,$2C,$20,$20,
                $0C,$0C,$0C,$0C,
                $00,$00,$00,$00) ),
             ( (7,0,11,0,
                $00,$00,$00,$00,
{........}      $00,$00,$00,$00,
{..2.2...}      $28,$00,$28,$28,
{..222...}      $38,$00,$38,$38,
{...20...}      $18,$08,$18,$18,
{...000..}      $1C,$1C,$1C,$1C,
{...10...}      $18,$18,$08,$08,
{...10...}      $18,$18,$08,$08,
{...110..}      $1C,$1C,$04,$04,
{..1111..}      $3C,$3C,$00,$00,
{.00..00.}      $66,$66,$66,$66,
                $00,$00,$00,$00),
               (7,0,11,0,
                $00,$00,$00,$00,
                $00,$00,$00,$00,
                $14,$00,$14,$14,
                $1C,$00,$1C,$1C,
                $18,$08,$18,$18,
                $38,$38,$38,$38,
                $18,$18,$10,$10,
                $18,$18,$10,$10,
                $38,$38,$20,$20,
                $3C,$3C,$00,$00,
                $66,$66,$66,$66,
                $00,$00,$00,$00) ),
             ( (7,0,11,0,
                $00,$00,$00,$00,
{........}      $00,$00,$00,$00,
{...22...}      $18,$00,$18,$18,
{..2202..}      $3C,$08,$3C,$3C,
{..2000..}      $3C,$1C,$3C,$3C,
{...01...}      $18,$18,$10,$10,
{...01...}      $18,$18,$10,$10,
{...10...}      $18,$18,$08,$08,
{...11...}      $18,$18,$00,$00,
{.01111..}      $7C,$7C,$40,$40,
{.0..00..}      $4C,$4C,$4C,$4C,
                $00,$00,$00,$00),
               (7,0,11,0,
                $00,$00,$00,$00,
                $00,$00,$00,$00,
                $18,$00,$18,$18,
                $3C,$10,$3C,$3C,
                $3C,$38,$3C,$3C,
                $18,$18,$08,$08,
                $18,$18,$08,$08,
                $18,$18,$10,$10,
                $18,$18,$00,$00,
                $3E,$3E,$02,$02,
                $32,$32,$32,$32,
                $00,$00,$00,$00) )      );

        BeamSoundBase   = 256;
        BeamSound       : array [0..10] of int = (1760,1440,1152,896,672,480,320,192,96,32,0);
        TorpSoundBase   = 1000;
        TorpSound       : array [0..10] of int = (1760,1440,1152,896,672,480,320,192,96,32,0);
        ToneFreq        : array ['@'..'H'] of int = (233,465,493,277,310,348,391,414,522);
                          { all tones are Octave 3. F is F#. @ is A from O2 }
        LemmiThemeLen   = 120;
        LemmiTheme      : array [1..LemmiThemeLen] of char =
{       'F.,F.GA,,F.,F,GAGAG,,C.,G.,G.AH,,,,AH.,G.AF,,C.,F.,F.GA,,F.,F,GAGAG.,,,,H.,HAHI,.A.AG.,G.GF,.,,,';}
        'D.,F,@D.,@.,D.,F,DE.,A.,'+
        'E.,F,GA,,.,GF.,E,DE.,@.,'+
        'D.,F.@D.,@.,D.,FEDE.,,,,'+
        'H.,G.EF.,A.AE.,F.FD,.,,,'+
        'H.,GFEF.,A.AE.,F.FD,.,,,';

        bclr    : array [LRType] of byte = (_Green,_Yellow);
        barX    : array [LRType] of int = (100,420);
        bshY    = 306;
        bdaY    = 322;
        bcrY    = 338;
        bamY    = 354;

const   RLen    = 5537; { 105x93 + palette + zero fill }
        RSize   = 5330; { 105x93 + palette }
        POffs   = 5300;

var     rbuf    : pointer;
        buf     : ^ImArr;
        x,y     : array [LRtype] of int;
        szx,szy : array [LRtype] of int;
        las     : array [LRtype,1..20,1..2] of byte; {ship lasers}
        nlas    : array [LRType] of byte;
        ftr     : array [LRtype,1..20,1..2] of byte; {fighter targets}
        fy      : array [1..20] of int;
        s       : string[79];
        x01,y01,x02,y02 : word;
        savedPal: array [0..15,0..2] of smallint;  { paleta del juego salvada en combate }

type    PImgBytes = ^TImgBytes;
        TImgBytes = array [0..ImgSize-1] of byte;
        PRawBytes = ^TRawBytes;
        TRawBytes = array [0..RLen-1] of byte;

{ Ancho/alto del img montado en formato ptcgraph (longint en offsets 0 y 4). }
function ImgW (lr:LRType): int;
  var pb: PImgBytes;
  begin pb := PImgBytes(img[lr]); ImgW := pb^[0] + pb^[1] shl 8; end;
function ImgH (lr:LRType): int;
  var pb: PImgBytes;
  begin pb := PImgBytes(img[lr]); ImgH := pb^[4] + pb^[5] shl 8; end;

const   Rand  : array [1..119] of int =
            ( $19B,$165,$216,$183,$E3, $C5, $196,$1C1,$2D8,$27,
              $1D3,$85, $2C4,$37D,$7,  $2B5,$2F8,$33A,$2B, $9A,
              $1EF,$278,$308,$362,$20B,$1D4,$294,$147,$28, $16F,
              $271,$25F,$36F,$118,$268,$244,$FC, $25C,$120,$299,
              $98, $C,  $3D8,$30E,$329,$39, $169,$1CB,$372,$8A,
              $3D9,$2FC,$331,$2F0,$EF, $3BE,$315,$2AA,$2B, $2C8,
              $21B,$F3, $1AB,$363,$2EF,$A6, $7A, $23C,$30B,$3BB,
              $232,$366,$201,$26E,$27E,$165,$80, $2B, $2DA,$DF,
              $23F,$118,$1D7,$106,$1AA,$2FD,$3DD,$3B1,$36E,{ $232,
              $1B7,$246,$2C3,$2DA,$10D,$10D,$15E,$345,$384,}$348,
              $226,$9,  $8B, $236,$143,$260,$2F8,$D0, $132,$25C,
              $64, $79, $12F,$2BB,$1C0,$396,$261,$67, $323,$2C2,
              $84, $264,$1B7,$2B8,$21, $18B,$138,$A7, $2E5  );

var     aa      : array [LRtype,1..20] of int;
                { aa    0..2    0-no fighter, 1-flying forward, 2-returning }
        dd      : array [LRtype,1..20] of int;
                { dd            fighter X coordinate }
        bb      : array [LRtype,1..20] of int;
                { bb    0..100  beam charge status }
                { VCR BUG: Only 10 beams are recharged if shld2=100 }
        cc      : array [LRtype,1..20] of int;  {* 20! DIFFERENCE WITH VCR - 10 *}
                { cc    0..100  launcher ready status }
        shpw,dam,crew,race,pic,wl,
        weaps,bays,tl,tfn,tf,launs,shld : array [LRtype] of int;
        name    : array [LRType] of str20;
        planet  : int;
        SX      : array [LRtype] of int;
        Dist    : int;
        r       : word;
        i,n     : int;
        rr      : int;
        lr      : LRType;
        Show,Beep,KeyStop       : boolean;
        SingleStep              : boolean;

procedure convertImage(var sr; var dst:array of byte);
type
        BArr = Array [0..12000] of byte;
        _BArr = ^BArr;
var
        src: _BArr;
        width,height,length,i,j,period,k,kk:word;
begin
        src:=_BArr(@sr);
        move(sr,dst,4);
        width := src^[0]+1+src^[1]*256;
        height := src^[2]+1+src^[3]*256;
        length := width*height;
        period := width div 8;
        if (width mod 8) > 0 then inc(period);
        i:=4;
        j:=4;
        while j<width*height+4 do
        begin
        k:=0;
                 for kk:=1 to width do
                 begin
                   if k<8 then inc(k)
                   else
                        begin
                                k:=1;
                                inc(i);
                        end;
                   if j+pred(kk) > length-1+4 then break;
                   dst[j+pred(kk)] :=
                        src^[i] and (256 shr k) shr (8-k)*8 +
                        src^[i+period] and (256 shr k) shr (8-k)*4 +
                        src^[i+period*2] and (256 shr k) shr (8-k)*2 +
                        src^[i+period*3] and (256 shr k) shr (8-k);
                 end;
                 inc(j,width);
                 inc(i,period*3+1);
        end;
end;

procedure GetStep;
  var   ch      : word;
  begin
    if SingleStep then
    begin
      ch:=ReadKey;
      if (ch=13) or (ch=27) then SingleStep:=Off;
    end;
  end;

function RND (k1,k2:int) : int;
  begin
    {Writeln('RND:  r=',r,' k1=',k1,' k2=',k2);}
    inc(r);
    if r>119 then r:=1;
    rr:=Trunc(((longint(Rand[r])*(k2-k1))/1000+0.5)+k1);
    {Writeln(rr);}
    RND:=rr;
  end;

procedure Lemmings (lr:LRType);
  var   x1,x2,y1,y2     : int;
        xl,yl,dxl,ddy,n : int;
        dyl             : single;
        i               : byte;
        xs,ys,yy,dy     : array [LRType] of int;
        l,nl            : LRType;
        gc,bc,theme     : byte;
        tone            : char;
  begin
    for l:=Left to Right do
    begin
      n:=1; ys[l]:=ftr[l,1,2];
      for i:=1 to 20 do
        if ftr[l,i,2]<ys[l] then
          begin ys[l]:=ftr[l,i,2]; n:=i end;
      xs[l]:=x[l]+ftr[l,n,1];
      inc(ys[l],y[l]-1);
    end;
    yy[Left]:=30; yy[Right]:=30; dy[Left]:=2; dy[Right]:=2; ddy:=-7;
    SetWriteMode(XORPut);
    SetColor(White);
{$IFDEF GR_DEBUG}
    Line(xs[Left],ys[Left],xs[Right],ys[Right]);
{$ENDIF}
    repeat
      Line(xs[Left],yy[Left],xs[Right],yy[Right]);
      Delay(13);
      if KeyPressed then begin SetWriteMode(NormalPut); Exit end;
      Line(xs[Left],yy[Left],xs[Right],yy[Right]);
      for l:=Left to Right do
      begin
        nl:=LRType(byte(l) xor 1);
        if (yy[l]>=ys[l]) and (dy[nl]>0) then
          begin dy[l]:=ddy; inc(ddy); inc(yy[nl],2) end;
        if dy[l]<2 then inc(dy[l]);
        if (yy[l]<ys[l]) or (dy[l]<0) then inc(yy[l],dy[l]);
      end;
    until (yy[Left]>=ys[Left]) and (yy[Right]>=ys[Right]);
    Line(xs[Left],ys[Left],xs[Right],ys[Right]);
    SetWriteMode(NormalPut);
    x1:=xs[LRType(byte(lr) xor 1)];
    x2:=xs[lr];
    y1:=ys[LRType(byte(lr) xor 1)];
    y2:=ys[lr];
    dxl:=IIF(x2>x1,1,-1);
    dyl:=(y2-y1)/Abs(x2-x1);
    xl:=x1; n:=0;
    gc:=1; bc:=1; theme:=0;
    repeat
      dec(gc);
      if gc=0 then
      begin
        yl:=y1+Round(dyl*n);
        if useSVGA then
        if lr=Left then
        begin
            convertImage(Lemming[7-xl and 7,Right],img256);
            PutImage(xl-4,yl-11,img256,NormalPut);
        end
        else
        begin
            convertImage(Lemming[xl and 7,Left],img256);
            PutImage(xl-4,yl-11,img256,NormalPut);
        end
        else
        if lr=Left then PutImage(xl-4,yl-11,Lemming[7-xl and 7,Right],NormalPut)
               else PutImage(xl-4,yl-11,Lemming[xl and 7,Left],NormalPut);
        Line(xs[Left],ys[Left],xs[Right],ys[Right]);
        inc(xl,dxl);
        inc(n);
        gc:=2;
      end;
      if Beep then
      begin
        dec(bc);
        if bc=0 then
        begin
          bc:=3;
          inc(theme);
          if theme>LemmiThemeLen then theme:=1;
          tone:=LemmiTheme[theme];
          if tone<>',' then
            if tone='.' then NoSound
                        else Sound(ToneFreq[tone]);
        end;
      end;
      Delay(50);
    until KeyPressed or (xl=x2+dxl);
    if Beep then NoSound;
    if KeyPressed then Exit;
    if useSVGA then
    begin
        convertImage(Lemming[xl and 7,Left],img256);
        PutImage(xl-4,yl-11,img256,NormalPut);
        end
        else
        PutImage(xl-4,yl-11,Lemming[xl and 7,Left],NormalPut);
    SetFillStyle(1,Black);
    Bar(xl-dxl-4,yl-11,xl-dxl+3,yl-1);
    if useSVGA then
    begin
        convertImage(Lemming[0,lr],img256);
        PutImage(xl-5*dxl-4,yl-11,img256,NormalPut);
    end
    else
            PutImage(xl-5*dxl-4,yl-11,Lemming[0,lr],NormalPut);
    Line(xs[Left],ys[Left],xs[Right],ys[Right]);
    Line(xs[lr],ys[lr],xs[lr],ys[lr]-15);
    SetFillStyle(1,White);
    Bar(xs[lr],ys[lr]-25,xs[lr]+15,ys[lr]-16);
  end;

procedure Gauge (bX,bY:int; c:byte; x1,x2:int);
  begin
    x1:=bX-Min(Max(x1,0),100);
    x2:=bX-Min(Max(x2,0),100);
    if x1=x2 then Exit;
    if x1<x2 then
    begin
      SetFillStyle(1,Black);
      Bar(x1,bY,x2-1,by+9);
    end
    else begin
      SetFillStyle(1,c);
      Bar(x2,bY,x1-1,by+9);
    end;
  end;

function Fmt1w (t:longint; w:byte) : string;
  { tenths -> "X.Y" alineado a la derecha en w columnas (un decimal, como PVCR). }
  var rs,p1,p2 : string; neg:boolean;
  begin
    neg := t<0; if neg then t:=-t;
    Str(t div 10, p1); Str(t mod 10, p2);
    rs := p1 + '.' + p2;
    if neg then rs := '-' + rs;
    while Length(rs) < w do rs := ' ' + rs;
    Fmt1w := rs;
  end;

procedure DrawShield (lr:LRType; draw:boolean);
  var   ry      : int;
        a1,a2   : int;
  begin
    if shld[lr]<=0 then Exit;
    ry:=szy[lr] div 2+10;
    if lr=Left then begin a1:=270; a2:=90 end
               else begin a1:=90; a2:=270 end;
    SetColor(IIF(draw,IIF(shld[lr]>60,_Green,IIF(shld[lr]>25,_Yellow,_Red)),Black));
    Ellipse(x[lr]+IIF(lr=Left,szx[lr],-1),y[lr]+ry-10,a1,a2,9,ry);
  end;

procedure Hit (lr:LRtype; damg,kill:int);
  var   j,k     : int;
        xs      : byte;
        s0,d0,c0: int;
  begin
    if Show then
      begin s0:=shld[lr]; d0:=dam[lr]; c0:=crew[lr] end;
    xs:=23+byte(lr)*40;
    j:=Round(shld[lr]-(damg/(shpw[lr]+1))*80-1);
    if Show and (s0>0) and (j<=0) then DrawShield(lr,Off);
    if j<0 then
    begin
      shld[lr]:=0;
      j:=-j;
      dam[lr]:=Round(dam[lr]+(j/(shpw[lr]+1))*80+1);
      if (lr=Right) and (planet=1) and (wl[Right]>0) and (damg>1) then
      begin
        k:=10-dam[Right] div 10;
        if k<wl[Right] then
        begin
          wl[Right]:=k;
          if Show and (weaps[Right]>0) and (k in [1..10]) then
          begin
            Clear(TX[Right]*8,25*16,639,25*16+15);
            s:=Beams[wl[lr]].name; Trim(s);
            WriteXY(TX[Right],25,Proper(weaps[Right],s)+' ('+NStr0(weaps[Right])+')');
          end;
        end;
      end;
      j:=0;
    end;
    if shld[lr]=0 then
    begin
      if (lr=Left) or (planet=0) then crew[lr]:=Round(crew[lr]-(kill/(shpw[lr]+1))*80);
      if crew[lr]<0 then crew[lr]:=0;
      if Show and ((lr=Left) or (planet=0)) then
      begin
        Str(crew[lr]:4,s);
        WriteXY(xs,21,s);
        Gauge(barX[lr],bcrY,_Yellow,c0,crew[lr]);
      end;
    end;
    shld[lr]:=j;
    if Show then
    begin
      DrawShield(lr,On);
      Str(shld[lr]:3,s);
      WriteXY(xs,19,s);
      Str(dam[lr]:3,s);
      WriteXY(xs,20,s);
      Gauge(barX[lr],bshY,_Green,s0,shld[lr]);
      Gauge(barX[lr],bdaY,_Red,d0,dam[lr]);
    end;
  end;

procedure Blast (x,y:int);
  procedure DrawBlast;
    begin
      Line(x-ER,y-ER,x+ER,y+ER);
      Line(x-ER,y+ER,x+ER,y-ER);
      Line(x,y-ER,x,y+ER);
      Line(x-ER,y,x+ER,y);
    end;
  begin
    SetWriteMode(XORPut);
    SetColor(_Red);
    DrawBlast;
    Delay(WAIT);
    DrawBlast;
    SetWriteMode(NormalPut);
  end;

procedure Beam (x1,y1,x2,y2,c,sn:int);
  var   i,dx,dy,bs,bsi  : int;
  procedure DrawBeam;
    begin
      Line(x1+(i-1)*dx,y1+(i-1)*dy,x1+i*dx,y1+i*dy);
    end;
  begin
    if not Show then Exit;
    bs:=BeamSound[sn]+BeamSoundBase;
    bsi:=bs div 20;
    SetWriteMode(XORPut);
    SetColor(c);
    dx:=(x2-x1) div LN;
    dy:=(y2-y1) div LN;
    for i:=1 to LN do
    begin
      if Beep then Sound(bs-i*bsi);
      DrawBeam;
      Delay(WAIT);
      DrawBeam;
    end;
    if Beep then NoSound;
    SetWriteMode(NormalPut);
    Blast(x2,y2);
  end;

procedure Fighter (i,x,h,c:int);
  { i - index, x - coord, h - heading (1-right, 2-left), c - color }
  var   y       : int absolute i;
  begin
    if not Show then Exit;
    SetColor(c);
    y:=fy[i];
    h:=h*2-3;
    Line(x+h,y-2,x+h,y+2);
    Line(x+h,y-2,x-h,y);
    Line(x+h,y+2,x-h,y);
  end;

procedure Laser (lr:LRtype; i:int);
  var   y,xs    : int;
  begin
    if not Show then Exit;
    xs:=104+320*byte(lr);
    y:=LY+i*3;
    SetLineStyle(0,0,2);
    SetColor(_Red);
    Line(xs,y,xs+100,y);
    SetColor(_Green);
    Line(xs,y,xs+bb[lr,i],y);
    SetLineStyle(0,0,1);
  end;

procedure Launcher (lr:LRtype; i:int);
  var   k,c     : byte;
        xs      : int;
  begin
    if not Show then Exit;
    xs:=104+320*byte(lr);
    c:=0;
    if cc[lr,i]=1 then c:=_Red;
    if cc[lr,i]=15 then c:=_Yellow;
    if byte(cc[lr,i]) in [29,30] then c:=_Green;
    if c=0 then Exit;
    SetColor(c);
    for k:=1 to TR-1 do Circle(xs-TR+i*TR*2,TY,k);
  end;

procedure Torpedo (x1,y1,x2,y2,c,sn:int);
  var   i,xx,yy,ts,tsi  : int;
  procedure DrawTorp;
    begin
      SetColor(_Red);
      Line(xx-TR,yy,xx+TR,yy);
      SetColor(c);
      Line(xx-TR+2,yy-1,xx+TR-2,yy-1);
      Line(xx-TR+2,yy+1,xx+TR-2,yy+1);
    end;
  begin
    if not Show then Exit;
    ts:=TorpSound[sn]+TorpSoundBase;
    tsi:=ts div 50;
    SetWriteMode(XORPut);
    for i:=1 to TN do
    begin
      if Beep then Sound(ts-i*tsi);
      xx:=x1+(((x2-x1)*10 div TN)*i+5) div 10;
      yy:=y1+(((y2-y1)*10 div TN)*i+5) div 10;
      DrawTorp;
      Delay(WAIT);
      DrawTorp;
    end;
    SetWriteMode(NormalPut);
    Blast(x2,y2);
{    for i:=1 to 3 do}
    if (x2>0) and (x2<639) then
      for i:=1 to WAIT*5 div 10 do
      begin
        if Beep then Sound(100+Random(500));
        Delay(5);
      end;
    if Beep then NoSound;
  end;

var     bexpl0,bkill0   : int;

procedure FireBeam (lr:LRtype; n:int);
  var   damg,kill,i     : int;
        nlr             : LRtype;
  begin
    nlr:=LRtype(byte(lr) xor 1);
    if wl[lr] in [1..10] then
    begin
      bexpl0:=Beams[wl[lr]].expl;
      bkill0:=Beams[wl[lr]].kill;
    end;
    damg:=Round((bexpl0*bb[lr,n])/100);
    kill:=Round((bkill0*bb[lr,n])/100);
    if race[lr]=5 then kill:=kill*3;
    if Show then
    begin
      i:=Random(nlas[nlr])+1;
      Beam(x[lr]+las[lr,n,1],   y[lr]+las[lr,n,2],
           x[nlr]+las[nlr,i,1], y[nlr]+las[nlr,i,2], bclr[lr], wl[lr]);
      Laser(lr,n);
    end;
    Hit(nlr,damg,kill);
    bb[lr,n]:=0;
    if Show then GetStep;
  end;

procedure FireAFB (lr:LRtype; n:int);
  var   i,j,k,l : int;
        nlr     : LRtype;
  begin
    nlr:=LRtype(byte(lr) xor 1);
    j:=0;
    k:=600;                   { find closest fighter -> j }
    for i:=1 to 20 do
      if aa[nlr,i]>0 then
      begin
        l:=Abs(SX[lr]-dd[nlr,i]);
        if l<k then begin j:=i; k:=l end;
      end;
    if (j>0) and (aa[nlr,j]>0) then
    begin
      Beam(x[lr]+las[lr,n,1],y[lr]+las[lr,n,2],dd[nlr,j],fy[j],bclr[lr],wl[lr]);
      Fighter(j,dd[nlr,j],aa[nlr,j] xor 3*byte(nlr),Black);
      Laser(lr,n);
      bb[lr,n]:=0;
      aa[nlr,j]:=0;
      if Show then
      begin
        dec(tf[nlr]);
        Str(tf[nlr]:4,s);
        WriteXY(23+byte(nlr)*40,22,s);
        Gauge(barX[nlr],bamY,White,tf[nlr]+1,tf[nlr]);
        GetStep;
      end;
    end;
  end;

var     texpl0,tkill0   : int;

procedure FireTorpedo (lr:LRtype; n:byte);
  var   damg,kill,xx,yy,y0      : int;
        nlr                     : LRtype;
        yeah                    : boolean;
        i,dy,mdy                : byte;
  begin
    nlr:=LRtype(byte(lr) xor 1);
    yeah:=RND(1,100)>=35;
    if Show then
    begin
      y0:=SY+(n-(launs[lr]+1) div 2)*TR;
      if yeah then
      begin
        mdy:=200;
        for i:=1 to nlas[nlr] do
        begin
          dy:=Abs(y0-(y[nlr]+las[nlr,i,2]));
          if dy<mdy then
          begin
            mdy:=dy;
            xx:=x[nlr]+las[nlr,i,1];
            yy:=y[nlr]+las[nlr,i,2];
          end;
        end;
      end
      else begin
        if lr=Left then xx:=639+TR else xx:=-TR;
        yy:=SY+((tfn[lr] and 1)*2-1)*SR*2;
      end;
      Torpedo(SX[lr],y0,xx,yy,_Green,tl[lr]);
    end;
    if yeah then           { hit! }
    begin
      if tl[lr] in [1..10] then
      begin
        texpl0:=Torps[tl[lr]].expl;
        tkill0:=Torps[tl[lr]].kill;
      end;
      damg:=texpl0*2;
      kill:=tkill0*2;
      Hit(nlr,damg,kill);
    end
  end;

procedure LaunchFighter (lr:LRtype);
  var   i,j     : int;
  begin
    i:=0; j:=0;
    while (i<20) and (j=0) do
    begin
      inc(i);
      if i=9 then i:=10;
      if aa[lr,i]=0 then
      begin
        dec(tfn[lr]);
        aa[lr,i]:=1;
        dd[lr,i]:=SX[lr];
        j:=1;
        Fighter(i,dd[lr,i],1+byte(lr),bclr[lr]);
        if Show then GetStep;
      end;
    end;
  end;

procedure MoveFighters;
  var   i,j     : int;
        lr,nlr  : LRtype;
  begin
    for i:=1 to 20 do
    begin
      if aa[Left,i]<>0 then Fighter(i,dd[Left,i],aa[Left,i],Black);
      if aa[Right,i]<>0 then Fighter(i,dd[Right,i],aa[Right,i] xor 3,Black);
      if (aa[Left,i]=1) and (dd[Left,i]>SX[Right]+10) then aa[Left,i]:=2;  { turn around }
      if (aa[Right,i]=1) and (dd[Right,i]<SX[Left]-10) then aa[Right,i]:=2;
      if (aa[Left,i]=2) and (dd[Left,i]<SX[Left]) then  { land }
      begin
        aa[Left,i]:=0;
        inc(tfn[Left]);
      end;
      if (aa[Right,i]=2) and (dd[Right,i]>SX[Right]) then
      begin
        aa[Right,i]:=0;
        inc(tfn[Right]);
      end;
      if aa[Left,i]=1 then dd[Left,i]:=dd[Left,i]+4;   { move }
      if aa[Left,i]=2 then dd[Left,i]:=dd[Left,i]-4;
      if aa[Right,i]=1 then dd[Right,i]:=dd[Right,i]-4;
      if aa[Right,i]=2 then dd[Right,i]:=dd[Right,i]+4;
      if aa[Left,i]<>0 then Fighter(i,dd[Left,i],aa[Left,i],_Green);
      if aa[Right,i]<>0 then Fighter(i,dd[Right,i],aa[Right,i] xor 3,_Yellow);
    end;
    for i:=1 to 20 do           { fire at enemy ship }
    for lr:=Left to Right do
    begin
      nlr:=LRtype(byte(lr) xor 1);
      if (aa[lr,i]=1) and (Abs(dd[lr,i]-SX[nlr])<20) then
      begin
        Beam(dd[lr,i],fy[i],x[nlr]+ftr[nlr,i,1],y[nlr]+ftr[nlr,i,2],_Red,0);
        Hit(nlr,2,2);
        if Show then GetStep;
      end;
    end;
    for i:=1 to 20 do                   { inter-fighter combats }
      if aa[Left,i]>0 then
        for j:=1 to 20 do
          if (aa[Right,j]>0) and (dd[Left,i]=dd[Right,j]) then
            if RND(1,200)<100 then
              begin
                Beam(dd[Right,j],fy[j],dd[Left,i],fy[i],_Red,0);
                Fighter(i,dd[Left,i],aa[Left,i],Black);
                aa[Left,i]:=0;
                if Show then
                begin
                  dec(tf[Left]);
                  Str(tf[Left]:4,s);
                  WriteXY(23,22,s);
                  Gauge(barX[Left],bamY,White,tf[Left]+1,tf[Left]);
                  GetStep;
                end;
              end
            else
              begin
                Beam(dd[Left,i],fy[i],dd[Right,j],fy[j],_Red,0);
                Fighter(j,dd[Right,j],aa[Right,j] xor 3,Black);
                aa[Right,j]:=0;
                if Show then
                begin
                  dec(tf[Right]);
                  Str(tf[Right]:4,s);
                  WriteXY(63,22,s);
                  Gauge(barX[Right],bamY,White,tf[Right]+1,tf[Right]);
                  GetStep;
                end;
              end;
  end;

procedure RechargeLasers (lr:LRtype);
  var   i       : int;
  begin
    if weaps[lr]>0 then
      for i:=1 to weaps[lr] do
      begin
        inc(bb[lr,i],RND(0,1));
        if bb[lr,i]>100 then bb[lr,i]:=100 else Laser(lr,i);
      end;
  end;

procedure Battle;
  var   i,time          : int;
        d               : array [LRtype] of int;
        xx,x1,yy1,yy2   : int;
        lr              : LRtype;
        ch              : word;
  begin
    if Show then
    begin
      SingleStep:=Off;
{$IFDEF TIMEBAR}
      SetFillStyle(1,_Gray);
      Bar(0,475,499,479);
{$ENDIF}
      szx[Left]:=ImgW(Left);
      szx[Right]:=ImgW(Right);
      szy[Left]:=ImgH(Left);
      szy[Right]:=ImgH(Right);
      x[Left]:=SX[Left]-szx[Left] div 2;
      x[Right]:=SX[Right]-szx[Right] div 2;
      yy1:=ImgH(Left);
      yy2:=ImgH(Right);
      y[Left]:=SY-yy1 div 2;
      y[Right]:=SY-yy2 div 2;
      if yy1>yy2 then begin yy2:=y[Left]+yy1; yy1:=y[Left] end
                 else begin yy1:=y[Right]; yy2:=y[Right]+yy2 end;
      for i:=1 to 10 do
      begin
        fy[i]:=yy1-FR*i;
        fy[i+10]:=yy2+FR*i;
      end;
    end;
    time:=0;
    FillChar(aa,SizeOf(aa),0);  { don't gather them together - stack!!! }
    FillChar(bb,SizeOf(bb),0);
    FillChar(cc,SizeOf(cc),0);
    FillChar(dd,SizeOf(dd),0);
    for lr:=Left to Right do
    if shld[lr]=100 then        { if full shield then lasers & launs are ready }
      for i:=1 to 20 do         {* 20! DIFFERENCE WITH VCR - 10 *}
      begin
        cc[lr,i]:=30;
        bb[lr,i]:=100;
      end;
    for lr:=Left to Right do
    for i:=1 to 10 do
    begin
      if i<=weaps[lr] then Laser(lr,i);
      if i<=launs[lr] then Launcher(lr,i);
    end;
    for lr:=Left to Right do
      if race[lr]=2 then d[lr]:=151 else d[lr]:=100;

    { finish the battle if one side is destroyed, killed, or time is out }
    while (dam[Left]<d[Left]) and (dam[Right]<d[Right]) and
          ((crew[Left]>0) and (crew[Right]>0) or (planet<>0)) and (time<2000) do
    begin
      inc(time);
      if Show then
      begin
{$IFDEF TIMEBAR}
        if time and 3=0 then
        begin
          xx:=500-time div 4;
          SetColor(Black);
          Line(xx,475,xx,479);
        end;
{$ENDIF}
        if (Show and KeyPressed) or (not Show and FastKeyPressed) then
        begin
          ch:=ReadKey;
          case ch of
            27                  : Show:=No;
            ord('1')..ord('9')  : WAIT:=(10-(ch-ord('0')))*DDelay;
            ord('-')            : if WAIT<9*DDelay then inc(WAIT,DDelay);
            ord('+')            : if WAIT>1*DDelay then dec(WAIT,DDelay);
            32                  : SingleStep:=On;
            ord('o')            : Beep:=not Beep;
          end;
        end;
      end
      else if KeyStop and FastKeyPressed then Exit;
      if Dist>30 then         { move them towards each other }
      begin
        inc(SX[Left]);
        if planet=0 then dec(SX[Right]);
      end;
      Dist:=SX[Right]-SX[Left];
      if Show then
      begin
        Str(Dist:3,s);
        WriteXY(42,17,s);
{$IFDEF GR_DEBUG}
  SetColor(_Green);
  Line(SX[Left],16*16-4,SX[Left],16*16-1);
  Line(SX[Right],16*16-4,SX[Right],16*16-1);
{$ENDIF}
        if planet=0 then xx:=(SX[Left]+SX[Right]) div 2
                    else xx:=x[Right]-10;
        x1:=Min( Max(SX[Left]-szx[Left] div 2,0) , xx-10-szx[Left] );
        if x1<>x[Left] then
        begin
          DrawShield(Left,Off);
          x[Left]:=x1;
        end;
        DrawShield(Left,On);
        if useSVGA then
        begin
          convertImage(img[Left]^,img256);
          PutImage(x[Left],y[Left],img256,NormalPut)
        end
    else
        PutImage(x[Left],y[Left],img[Left]^,NormalPut);
        if planet=0 then
        begin
          x1:=Max( Min(SX[Right]-szx[Right] div 2,640-szx[Right]) ,  xx+10 );
          if x1<>x[Right] then
          begin
            DrawShield(Right,Off);
            x[Right]:=x1;
          end;
        end;
        DrawShield(Right,On);
        if useSVGA then
        begin
          convertImage(img[Right]^,img256);
          PutImage(x[Right],y[Right],img256,NormalPut);
        end
    else
        PutImage(x[Right],y[Right],img[Right]^,NormalPut);
        Delay(WAIT);
        GetStep;
      end;

      if (weaps[Left]>0) and (Dist<200) then   { fire beams 1 at enemy }
        for i:=1 to weaps[Left] do
          if (RND(1,20)<7) and (bb[Left,i]>50) then FireBeam(Left,i);

      if weaps[Left]>0 then                { fire beams 1 at enemy fighters }
        for i:=1 to weaps[Left] do
          if (RND(1,20)<5) and (bb[Left,i]>40) then FireAFB(Left,i);

      if weaps[Right]>0 then                { fire beams 2 at enemy fighters }
        for i:=1 to weaps[Right] do
          if (RND(1,20)<5) and (bb[Right,i]>40) then FireAFB(Right,i);

      if (weaps[Right]>0) and (Dist<200) then   { fire beams 2 at enemy }
        for i:=1 to weaps[Right] do
          if (RND(1,20)<7) and (bb[Right,i]>50) then FireBeam(Right,i);

      for lr:=Left to Right do
      if (Dist<300) and (launs[lr]>0) and (tfn[lr]>0) then    { fire torpedoes }
        for i:=1 to launs[lr] do
          if tfn[lr]>0 then
          begin
            if ((RND(1,17)<tl[lr]) and (cc[lr,i]>30)) or (cc[lr,i]>40) then
            begin
              dec(tfn[lr]);
              dec(tf[lr]);
              cc[lr,i]:=0;
              FireTorpedo(lr,i);
              if Show then
              begin
                Str(tf[lr]:4,s);
                WriteXY(23+byte(lr)*40,22,s);
                Gauge(barX[lr],bamY,White,tf[lr]+1,tf[lr]);
                GetStep;
              end;
            end;
            inc(cc[lr,i]);          { recharge }
            Launcher(lr,i);
          end;

      for lr:=Left to Right do
        if (bays[lr]>0) and (RND(1,20)<=bays[lr]) and (tfn[lr]>0) then LaunchFighter(lr);
      if (bays[Left]>0) or (bays[Right]>0) then MoveFighters;   {move fighters and fight}

      RechargeLasers(Left);
      RechargeLasers(Right);
    end;  { main while }

    for lr:=Left to Right do
    begin
      for i:=1 to 20 do          { gather all remaining fighters }
        if (bays[lr]>0) and (aa[lr,i]>0) then inc(tfn[lr]);
      if (((lr=Left) or (planet=0)) and (dam[lr]>=d[lr])) or
         ((lr=Left) and (planet<>0) and (crew[Left]<=0)) then
      begin
        pic[lr]:=ExplPic;
        if Show then
        begin
          inc(x[lr],ImgW(lr) div 2);
          LoadPic(lr,ExplPic,No,No,Yes,Yes);
          x[lr]:=x[lr]-ImgW(lr) div 2;
          y[lr]:=SY-ImgH(lr) div 2;
          SetPal;
        end;
      end;
      if Show then
      begin
        DrawShield(lr,Off);
        if useSVGA then
        begin
        convertImage(img[lr]^,img256);
        PutImage(x[lr],y[lr],img256,OrPut);
    end
    else
        PutImage(x[lr],y[lr],img[lr]^,OrPut);
        if Beep and (pic[lr]=ExplPic) then
        begin
          for i:=1 to 150 do
          begin
            Sound(100+Random(500));
            Delay(5);
          end;
          NoSound;
        end;
      end;
      if (time<2000) and (pic[lr]<>ExplPic) and
         ( ((crew[lr]<=0) and (dam[lr]<d[lr])) or
           ((lr=Right) and (planet<>0) and (dam[Right]>=100)) ) then
      begin                                           { not d[Right] here! }
        pic[lr]:=SurrPic;
        if Show then Lemmings(lr);
      end;
    end;
    if Show and (time>=2000) and (pic[Left]<>ExplPic) and (pic[Right]<>ExplPic) then
      WriteXY(30,17,'...to be continued...');
    if Show then ReadKey;

  end;

procedure LoadPic (lr:LRtype; pic:byte; rot,fli,truncpal,process:boolean);
  var   x,y,x1,x2,y1,y2 : word;
        i,k,p,bx,bit,off,w,h,pbase : int;
        f               : file;
        b               : byte;
        haveData,found  : boolean;
        rb              : PRawBytes;
        ib              : PImgBytes;
        tmp             : ImArr;
  begin
    if (pic<=0) or (pic>151) then begin pic:=111; rot:=No end;
    haveData := False;
    if OpenFile(f,ResName,0,No) then
    begin
      Seek(f,longint(pic-1)*RLen);
      BlockRead(f,rbuf^,RSize);
      CloseData(f);
      haveData := True;
    end;
    rb := PRawBytes(rbuf);

    { --- paleta: 15 words (byte bajo) en POffs -> 5 colores RGB (orden R,B,G).
          Left ocupa pal[1..5]; Right ocupa pal[6..10]. --- }
    if haveData then
    begin
      if lr=Left then pbase:=1 else pbase:=6;
      for i:=0 to 4 do
      begin
        pal[pbase+i,1] := rb^[POffs + (i*3+0)*2];   { R }
        pal[pbase+i,2] := rb^[POffs + (i*3+1)*2];   { B }
        pal[pbase+i,3] := rb^[POffs + (i*3+2)*2];   { G }
      end;
    end;

    x1:=0; y1:=0; x2:=103; y2:=103;

    if process then
    begin
      FillChar(buf^, SizeOf(buf^), 0);
      if haveData then
      begin
        { --- decodificar planar VGA (4 planos): 93 lineas, 4 planos,
              13 bytes (104 px) + 1 byte de relleno por plano. MSB primero. --- }
        off := 4;
        for y:=0 to 92 do
          for p:=0 to 3 do
          begin
            for bx:=0 to 12 do
            begin
              b := rb^[off]; inc(off);
              for bit:=0 to 7 do
                if (b shr (7-bit)) and 1 = 1 then
                  buf^[y,bx*8+bit] := buf^[y,bx*8+bit] or (1 shl p);
            end;
            inc(off);          { saltar 14o byte }
          end;

        { --- truncado de paleta: apaga 6..10; si es Right desplaza 1..5 -> 6..10
              (asi cada bando usa sus propios indices de paleta). --- }
        if truncpal then
          for y:=0 to 103 do
            for x:=0 to 103 do
            begin
              b := buf^[y,x];
              if (b>=6) and (b<=10) then buf^[y,x]:=0
              else if (lr<>Left) and (b>=1) and (b<=5) then buf^[y,x]:=b+5;
            end;

        { --- rotacion 90 (pics verticales) --- }
        if rot then
        begin
          tmp := buf^;
          for y:=0 to 103 do
            for x:=0 to 103 do
              buf^[x,103-y] := tmp[y,x];
        end;

        { --- espejo horizontal --- }
        if fli then
          for y:=0 to 103 do
            for x:=0 to 51 do
            begin
              b := buf^[y,x]; buf^[y,x]:=buf^[y,103-x]; buf^[y,103-x]:=b;
            end;

        { --- apagar el borde (col 0 para Left, col 103 para Right) --- }
        if lr=Left then for y:=0 to 103 do buf^[y,0]:=0
                   else for y:=0 to 103 do buf^[y,103]:=0;

        { --- caja real de la imagen (pixeles no-cero) --- }
        found:=False; x1:=103; y1:=103; x2:=0; y2:=0;
        for y:=0 to 103 do
          for x:=0 to 103 do
            if buf^[y,x]<>0 then
            begin
              found:=True;
              if x<x1 then x1:=x;  if x>x2 then x2:=x;
              if y<y1 then y1:=y;  if y>y2 then y2:=y;
            end;
        if not found then begin x1:=0; y1:=0; x2:=0; y2:=0; end;
        { Incluir un borde en blanco de 1px alrededor. El salvapantallas desplaza la
          nave 1px por fotograma con NormalPut (en horizontal o vertical); ese borde
          negro borra el rastro del fotograma anterior y evita los surcos. Es
          inofensivo en combate (solo relleno negro). }
        if found then
        begin
          if x1>0   then dec(x1);
          if y1>0   then dec(y1);
          if x2<103 then inc(x2);
          if y2<103 then inc(y2);
        end;
      end;

      { --- montar img[lr]^ en formato ptcgraph 8bpp (recortado a la caja):
            longint ancho, longint alto, longint reservado, luego 1 word/pixel. --- }
      ib := PImgBytes(img[lr]);
      if ib<>nil then
      begin
        w := x2-x1+1; h := y2-y1+1;
        FillChar(ib^, 12, 0);
        ib^[0]:=w and $ff; ib^[1]:=(w shr 8) and $ff;
        ib^[4]:=h and $ff; ib^[5]:=(h shr 8) and $ff;
        k := 12;
        for y:=y1 to y2 do
          for x:=x1 to x2 do
          begin
            ib^[k] := buf^[y,x]; ib^[k+1] := 0; inc(k,2);
          end;
      end;
    end;

    x01:=x1; y01:=y1; x02:=x2; y02:=y2;
  end;

procedure AnalysePic (lr:LRtype; pic:byte);
  var   x,y     : word;
        i,k     : int;
        nlr     : LRType;
  begin

{$IFDEF GR_DEBUG}
    for x:=0 to 103 do
    for y:=0 to 103 do
      putpixel(x,y,buf^[y,x]);
    setcolor(white);
    rectangle(x01,y01,x02,y02);
{$ENDIF}

    nlr:=LRtype(byte(lr) xor 1);
    nlas[lr]:=Min(Max(weaps[lr],Max(weaps[nlr],launs[nlr])),20);
    if nlas[lr]>0 then
    begin
      k:=(y02-y01+1-4) div nlas[lr];
      for i:=1 to nlas[lr] do
      begin
        y:=2+i*k-k div 2;
        las[lr,i,2]:=y;
        inc(y,y01);
        if lr=Left then
        begin
          x:=x02;
          while (x>x01) and (buf^[y,x]=0) do
            begin dec(x); {$IFDEF GR_DEBUG} PutPixel(x,y,Yellow); {$ENDIF} end;
        end
        else begin
          x:=x01;
          while (x<x02) and (buf^[y,x]=0) do
            begin inc(x); {$IFDEF GR_DEBUG} PutPixel(x,y,Yellow); {$ENDIF} end;
        end;
        las[lr,i,1]:=x-x01;
      end;
    end
    else begin
      las[lr,1,1]:=(x02+x01) div 2-x01;
      las[lr,1,2]:=(y02+y01) div 2-y01;
    end;

    k:=(x02-x01-1) div 10;
    for i:=1 to 10 do
    begin
      if lr=Left then x:=x02-2-k*(i-1)
                 else x:=x01+2+k*(i-1);
      ftr[lr,i,1]:=x-x01;
      ftr[lr,i+10,1]:=x-x01;
      y:=y01;
      while (y<=y02) and (buf^[y,x]=0) do
        begin inc(y); {$IFDEF GR_DEBUG} PutPixel(x,y,LightRed); {$ENDIF} end;
      ftr[lr,i,2]:=IIF(y<=y02,y-y01,(y02-y01) div 2);
      y:=y02;
      while (y>=y01) and (buf^[y,x]=0) do
        begin dec(y); {$IFDEF GR_DEBUG} PutPixel(x,y,LightRed); {$ENDIF} end;
      ftr[lr,i+10,2]:=IIF(y>=y01,y-y01,(y02-y01) div 2);
    end;
{$IFDEF GR_DEBUG} readkey; {$ENDIF}
  end;

procedure SetPal;
  var   i : int;
  begin
   {$IFDEF VPAMM}
    for i:=1 to 15 do SetRGBPalette(i, 4*pal[i,1], 4*pal[i,3], 4*pal[i,2]);
   {$ELSE}
    { Aplica la paleta de sprites de combate (indices 1..15): los colores estan
      almacenados como 6 bits (0..63) en orden R,B,G; ptcgraph quiere 0..255 RGB. }
    for i:=1 to 15 do SetRGBPalette(i, 4*pal[i,1], 4*pal[i,3], 4*pal[i,2]);
   {$ENDIF}
    { colores del planeta-disco (muestreados de PVCR.EXE), en indices libres }
    SetRGBPalette(clPlSalmon, 224, 144, 112);
    SetRGBPalette(clPlTan,    224, 192, 160);
    SetRGBPalette(clPlDark,   128,   0,   0);
    SetRGBPalette(clPlMid,    192, 144, 112);
  end;

procedure Combat (var vcr:VCRData; Animate:boolean; speed:byte; Sounds,KeyIntr:boolean);
var     lr      : LRType;
        x       : int;
        ttt     : text;
begin
  Show:=Animate;
  Beep:=Sounds;
  KeyStop:=KeyIntr;
  WAIT:=(10-speed)*DDelay;

  planet:=vcr.planet;
  r:=vcr.K0;
  for lr:=Left to Right do
  begin
    shpw[lr]:=vcr.shpw[lr];
    dam[lr]:=vcr.dd[lr].dam;
    crew[lr]:=vcr.dd[lr].crew;
    race[lr]:=vcr.dd[lr].race;
    pic[lr]:=vcr.dd[lr].pic;
    wl[lr]:=vcr.dd[lr].wl;
    weaps[lr]:=Min(vcr.dd[lr].weaps,20);
    bays[lr]:=vcr.dd[lr].bays;
    tl[lr]:=vcr.dd[lr].tl;
    tfn[lr]:=vcr.dd[lr].tfn;
    tf[lr]:=vcr.dd[lr].tfn;
    launs[lr]:=Min(vcr.dd[lr].launs,20);
    shld[lr]:=Max(vcr.shld[lr],0);
    name[lr]:=vcr.dd[lr].name;
  end;
  if pic[Right]=0 then pic[Right]:=vcr.plnpic;
  Trim(name[Left]); LPad(name[Left],20);
  SX[Left]:=30;
  SX[Right]:=IIF(planet=0,$262,$23A);

  Dist:=SX[Right]-SX[Left];
  for lr:=Left to Right do
  begin
    i:=Max(100-dam[lr],0);
    if i<shld[lr] then shld[lr]:=i;
  end;
  if (weaps[Left]=0) and (launs[Left]=0) and (bays[Left]=0) then shld[Left]:=0;
  if (planet=0) and (weaps[Right]=0) and (launs[Right]=0) and (bays[Right]=0) then shld[Right]:=0;
  if (planet=1) and (crew[Right]<1) then shld[Right]:=0;

  if Show then
  begin
    LoadPic(Left,pic[Left],pic[Left] in RotPic,pic[Left] in FliPic,Yes,Yes);
    AnalysePic(Left,pic[Left]);
    LoadPic(Right,pic[Right],pic[Right] in RotPic,not(pic[Right] in FliPic),Yes,Yes);
    AnalysePic(Right,pic[Right]);
    ClearDevice;
    SetPal;
    TextAttr:=White;
    WriteXY(10,0,name[Left]+'       versus       '+name[Right]);
    WriteXY(32,17,'Distance:    00');
    for lr:=Left to Right do
    begin
      x:=TX[lr];
      Str(shld[lr]:3,s);
      WriteXY(x,19,'Shield:   '+s+'% ('+NStr0(shpw[lr])+'tw)');
      Str(dam[lr]:3,s);
      WriteXY(x,20,'Damage:   '+s+'%');
      if (lr=Left) or (planet=0) then
      begin
        Str(crew[lr]:4,s);
        WriteXY(x,21,'Crew  :   '+s);
      end;
      if (tl[lr]>0) and (launs[lr] or tf[lr]>0) then
      begin
        Str(tf[lr]:4,s);
        WriteXY(x,22,'Torps :   '+s);
        s:=Torps[tl[lr]].name; Trim(s);
        WriteXY(x,23,s+Proper(launs[lr],' tube')+' ('+NStr00(launs[lr],'NTP')+')');
      end else
      if bays[lr] or tf[lr]>0 then
      begin
        Str(tf[lr]:4,s);
        WriteXY(x,22,'Fgtrs :   '+s);
        WriteXY(x,23,Proper(bays[lr],'Fighter bay')+' ('+NStr00(bays[lr],'NTP')+')');
      end;
      if weaps[lr]>0 then
      begin
        s:=Beams[wl[lr]].name; Trim(s);
        WriteXY(x,25,Proper(weaps[lr],s)+' ('+NStr0(weaps[lr])+')');
      end;
      x:=barX[lr];
      Gauge(x,bshY,_Green,0,shld[lr]);
      Gauge(x,bdaY,_Red,0,dam[lr]);
      if ((lr=Left) or (planet=0)) then Gauge(x,bcrY,_Yellow,0,crew[lr]);
      Gauge(x,bamY,White,0,tf[lr]);
    end;
  end;

  bexpl0:=0; bkill0:=0;
  texpl0:=0; tkill0:=0;
  Battle;
  if Animate then ClearDevice;

  for lr:=Left to Right do
  begin
    vcr.shld[lr]:=shld[lr];
    vcr.dd[lr].dam:=dam[lr];
    vcr.dd[lr].crew:=crew[lr];
    vcr.dd[lr].tfn:=tfn[lr];
    vcr.dd[lr].pic:=pic[lr];
  end;
end;

procedure TCombatInit (VCRPalette:boolean);
  var i: int; r,g,b: smallint;
  begin
    CheckMem(RSize);
    GetMem(rbuf,RSize);
    CheckMem(104*104);          { 104!! the rightmost col is omitted }
    GetMem(buf,104*104);
    CheckMem(ImgSize);
    GetMem(img[Left],ImgSize);
    CheckMem(ImgSize);
    GetMem(img[Right],ImgSize);
    { dejar img[] como imagen vacia valida hasta que LoadPic la rellene }
    FillChar(img[Left]^, ImgSize, 0);
    FillChar(img[Right]^, ImgSize, 0);
    { guardar la paleta 0..15 para restaurarla al salir (combate la reescribe) }
    {$IFDEF UNIX}
    for i:=0 to 15 do
    begin
      GetRGBPalette(i, r, g, b);
      savedPal[i,0]:=r; savedPal[i,1]:=g; savedPal[i,2]:=b;
    end;
    {$ENDIF}
    if VCRPalette then Move(VCRpal,pal,3*16)
                  else Move(PLpal,pal,3*16);
  end;

procedure TCombatFinish;
  var i: int;
  begin
    {$IFDEF UNIX}
    { restaurar la paleta del juego (que el combate habia reescrito en 1..15) }
    for i:=0 to 15 do
      SetRGBPalette(i, savedPal[i,0], savedPal[i,1], savedPal[i,2]);
    {$ENDIF}
    FreeMem(rbuf,RSize);
    FreeMem(buf,104*104);
    FreeMem(img[Left],ImgSize);
    FreeMem(img[Right],ImgSize);
        if useSVGA then
                SetGraphMode(3);
  end;


{ ===========================================================================
  Visor de combate PHost nativo (Fase C). Conecta el algoritmo bit-exacto de
  PVCRALG con las primitivas de dibujo de esta unit. A diferencia del Battle
  clasico (THost), aqui la MATEMATICA la hace PVCRALG; estos callbacks SOLO
  renderizan su estado (leido por los accessors Vcr*), sin recalcular nada.
  Mapeo de coordenadas: pantalla_X = 320 + metros/100 (ver README, Fase C2).
  =========================================================================== }

const pvMaxFtr = 50;   { = VCR_MAX_FTRS de PVCRALG }

var   pvFX : array [TVcrSide, 0..pvMaxFtr-1] of int;  { ultima X en pantalla, -1=ausente }
      pvFH : array [TVcrSide, 0..pvMaxFtr-1] of int;  { h con que se dibujo (para borrar igual y no dejar estela) }
      pvDead : array [LRtype] of boolean;             { objeto destruido: pintar explosion al final }

function pvSX (m:longint) : int;            { metros -> pixel X de pantalla }
  begin pvSX := 320 + m div 100; end;

function pvLR (side:TVcrSide) : LRtype;
  begin if side=vsLeft then pvLR:=Left else pvLR:=Right; end;

function pvFY (side:TVcrSide; track:int) : int;   { Y de un fighter (escalonado) }
  begin
    if side=vsLeft then pvFY := SY - 18 - (track mod 10)*FR
                   else pvFY := SY + 18 + (track mod 10)*FR;
  end;

procedure pvDrawFighter (x,y,h,c:int);   { dibuja la nave-caza (espejo de Fighter()) }
  begin
    if not Show then Exit;
    SetColor(c); h:=h*2-3;
    Line(x+h,y-2,x+h,y+2); Line(x+h,y-2,x-h,y); Line(x+h,y+2,x-h,y);
  end;

procedure pvRefreshAmmo (side:TVcrSide);
  var lr:LRtype; nf:int; oi:TVcrObject;
  begin
    lr:=pvLR(side); oi:=VcrObjInfo(side);
    { PVCR muestra solo los cazas en RESERVA (bahias); los que estan en vuelo no
      se cuentan (numFighters baja al lanzar y sube al aterrizar). Asi el contador
      coincide fotograma a fotograma con PVCR.EXE. }
    if oi.numBays>0 then nf:=oi.numFighters
                    else nf:=oi.numTorps;
    if Show then
    begin
      Gauge(barX[lr],bamY,White,tf[lr],nf);
      Str(nf:4,s); WriteXY(23+byte(lr)*40,22,s);
    end;
    tf[lr]:=nf;
  end;

procedure pvRefreshGauges (side:TVcrSide);   { escudo/dano/tripa desde el estado real }
  var lr:LRtype; ns,nd,nc:int;
  begin
    lr:=pvLR(side);
    ns:=VcrCurShield(side); nd:=VcrCurDamage(side); nc:=VcrCurCrew(side);
    if Show then
    begin
      DrawShield(lr,Off);
      Gauge(barX[lr],bshY,_Green,shld[lr],ns);
      Gauge(barX[lr],bdaY,_Red,dam[lr],nd);
      if (lr=Left) or (planet=0) then Gauge(barX[lr],bcrY,_Yellow,crew[lr],nc);
      shld[lr]:=ns; DrawShield(lr,On);
      WriteXY(TX[lr]+8,19, Fmt1w(VcrCurShieldT(side),5));
      WriteXY(TX[lr]+8,20, Fmt1w(VcrCurDamageT(side),5));
      if (lr=Left) or (planet=0) then WriteXY(TX[lr]+8,21, Fmt1w(VcrCurCrewT(side),6));
    end;
    shld[lr]:=ns; dam[lr]:=nd; crew[lr]:=nc;
  end;

{ --- los 8 eventos del visualizador (firmas = TVcrVisualizer de PVCRALG) --- }

procedure pvStartFighter (side:TVcrSide; track:int);
  begin
    pvFX[side,track]:=-1;       { lo dibuja pvUpdateFighters en su posicion actual }
    pvRefreshAmmo(side);
  end;

procedure pvLandFighter (side:TVcrSide; track:int);
  begin
    if pvFX[side,track]>=0 then pvDrawFighter(pvFX[side,track],pvFY(side,track),pvFH[side,track],Black);
    pvFX[side,track]:=-1;
    pvRefreshAmmo(side);
  end;

procedure pvKillFighter (side:TVcrSide; track:int);
  begin
    if pvFX[side,track]>=0 then
    begin
      pvDrawFighter(pvFX[side,track],pvFY(side,track),pvFH[side,track],Black);
      Blast(pvFX[side,track],pvFY(side,track));
    end;
    pvFX[side,track]:=-1;
    pvRefreshAmmo(side);
  end;

procedure pvFireBeam (side:TVcrSide; track,target,hit,damage,kill:int);
  var opp:TVcrSide; x1,y1,x2,y2:int;
  begin
    if side=vsLeft then opp:=vsRight else opp:=vsLeft;
    if Show then
    begin
      if track<0 then begin x1:=pvSX(VcrObjectX(side)); y1:=SY; end
                 else begin x1:=pvSX(VcrFighterX(side,track)); y1:=pvFY(side,track); end;
      if target<0 then begin x2:=pvSX(VcrObjectX(opp)); y2:=SY; end
                  else begin x2:=pvSX(VcrFighterX(opp,target)); y2:=pvFY(opp,target); end;
      Beam(x1,y1,x2,y2,IIF(hit>0,_Red,_Gray),0);
    end;
    if (hit>0) and (target<0) then pvRefreshGauges(opp);
  end;

procedure pvFireTorpedo (side:TVcrSide; hit,launcher:int);
  var opp:TVcrSide; x1,y1,x2,y2:int;
  begin
    if side=vsLeft then opp:=vsRight else opp:=vsLeft;
    if Show then
    begin
      x1:=pvSX(VcrObjectX(side)); y1:=SY;
      x2:=pvSX(VcrObjectX(opp));  y2:=SY;
      Torpedo(x1,y1,x2,y2,_Green,tl[pvLR(side)]);
    end;
    if hit>=0 then pvRefreshGauges(opp);
    pvRefreshAmmo(side);
  end;

procedure pvKillObject (side:TVcrSide);
  { Marca el objeto como destruido (para pintar la explosion al final, encima de
    todo) y hace el sonido. La explosion en si la dibuja el driver tras los
    refrescos, para que no la tape el redibujo de escudos/gauges. }
  var i:int;
  begin
    pvDead[pvLR(side)]:=true;
    if Show and Beep then
    begin
      for i:=1 to 150 do begin Sound(100+Random(500)); Delay(5); end;
      NoSound;
    end;
  end;

{ --- movimiento por tick (naves y fighters), leido del estado de PVCRALG --- }

procedure pvUpdateShips;
  var nx:int;
  begin
    if not Show then Exit;
    SX[Left]:=pvSX(VcrObjectX(vsLeft));
    SX[Right]:=pvSX(VcrObjectX(vsRight));
    Dist:=SX[Right]-SX[Left];
    Str(Dist:3,s); WriteXY(42,17,s);
    nx:=SX[Left]-szx[Left] div 2; if nx<0 then nx:=0;
    { En combate contra planeta, no dejar que la nave se meta dentro del disco:
      su borde derecho se detiene un poco antes del planeta. Solo se limita la
      posicion de DIBUJO (nx); SX[Left] y la distancia mostrada no se tocan. }
    if planet=1 then
      if nx > SX[Right]-szx[Right] div 2 - szx[Left] - 10 then
        nx := SX[Right]-szx[Right] div 2 - szx[Left] - 10;
    if nx<0 then nx:=0;
    if nx<>x[Left] then begin DrawShield(Left,Off); x[Left]:=nx; end;
    DrawShield(Left,On);
    if useSVGA then begin convertImage(img[Left]^,img256); PutImage(x[Left],y[Left],img256,NormalPut); end
               else PutImage(x[Left],y[Left],img[Left]^,NormalPut);
    nx:=SX[Right]-szx[Right] div 2; if nx>640-szx[Right] then nx:=640-szx[Right];
    if nx<>x[Right] then begin DrawShield(Right,Off); x[Right]:=nx; end;
    DrawShield(Right,On);
    if useSVGA then begin convertImage(img[Right]^,img256); PutImage(x[Right],y[Right],img256,NormalPut); end
               else PutImage(x[Right],y[Right],img[Right]^,NormalPut);
  end;

procedure pvUpdateFighters;
  var side:TVcrSide; track,nx,h,c,st:int;
  begin
    if not Show then Exit;
    for side:=vsLeft to vsRight do
      for track:=0 to pvMaxFtr-1 do
      begin
        st:=VcrFighterStatus(side,track);
        if st<>0 then
        begin
          if pvFX[side,track]>=0 then pvDrawFighter(pvFX[side,track],pvFY(side,track),pvFH[side,track],Black);
          nx:=pvSX(VcrFighterX(side,track));
          if st=1 then h:=IIF(side=vsLeft,1,2) else h:=IIF(side=vsLeft,2,1);
          if side=vsLeft then c:=_Green else c:=_Yellow;
          pvDrawFighter(nx,pvFY(side,track),h,c);
          pvFX[side,track]:=nx; pvFH[side,track]:=h;
        end
        else if pvFX[side,track]>=0 then
        begin
          pvDrawFighter(pvFX[side,track],pvFY(side,track),pvFH[side,track],Black);
          pvFX[side,track]:=-1;
        end;
      end;
  end;

{ --- driver principal: setup (= Combat) + InitBattle/PlayCycle/DoneBattle --- }

procedure BuildPlanetDisc (lr:LRtype; diam:int);
  { Rellena img[lr]^ con un planeta texturizado estilo PVCR.EXE (esfera salmon
    moteada con relieve, brillo tan arriba y borde difuminado), en el formato de
    imagen de ptcgraph (cabecera 12 bytes + 1 word/pixel). Sustituye al sprite de
    nave que cargaria LoadPic, para dibujar el planeta como planeta. La textura se
    genera una vez (la imagen se reutiliza cada frame). }
  var ib:PImgBytes; cx,cy,rr,dx,dy,d2,k,px,py,c,rnd:int;
  begin
    ib:=PImgBytes(img[lr]); if ib=nil then Exit;
    if diam>104 then diam:=104; if diam<8 then diam:=8;
    FillChar(ib^,12,0);
    ib^[0]:=diam and $ff; ib^[1]:=(diam shr 8) and $ff;   { ancho }
    ib^[4]:=diam and $ff; ib^[5]:=(diam shr 8) and $ff;   { alto }
    cx:=diam div 2; cy:=diam div 2; rr:=(diam div 2)-1;
    k:=12;
    for py:=0 to diam-1 do
      for px:=0 to diam-1 do
      begin
        dx:=px-cx; dy:=py-cy; d2:=dx*dx+dy*dy;
        if d2 > rr*rr then c:=0                             { fuera: fondo negro }
        else
        begin
          rnd:=Random(100);
          c:=clPlSalmon;                                    { base salmon }
          if rnd<20 then c:=clPlDark                        { relieve rojo oscuro }
          else if rnd<34 then c:=clPlTan                    { manchas claras }
          else if rnd<46 then c:=clPlMid;                   { salmon medio }
          if (dy < -(rr div 4)) and (Random(100)<45) then c:=clPlTan;   { brillo arriba }
          if (d2 > (rr-3)*(rr-3)) and (Random(100)<55) then c:=0;       { borde difuminado }
        end;
        ib^[k]:=c; ib^[k+1]:=0; inc(k,2);
      end;
  end;

procedure CombatPHost (var vcr:VCRData; Animate:boolean; speed:byte; Sounds,KeyIntr:boolean);
  var lobj,robj : TVcrObject;
      seed,sig,flags,btype : word;
      vis : TVcrVisualizer;
      lr  : LRtype; xx : int; side:TVcrSide; track:int; ch:word;
      res : TVcrResult;
  begin
    Show:=Animate; Beep:=Sounds; KeyStop:=KeyIntr; WAIT:=(10-speed)*DDelay;
    planet:=vcr.planet; r:=vcr.K0;
    for lr:=Left to Right do
    begin
      shpw[lr]:=vcr.shpw[lr]; dam[lr]:=vcr.dd[lr].dam; crew[lr]:=vcr.dd[lr].crew;
      race[lr]:=vcr.dd[lr].race; pic[lr]:=vcr.dd[lr].pic; wl[lr]:=vcr.dd[lr].wl;
      weaps[lr]:=Min(vcr.dd[lr].weaps,20); bays[lr]:=vcr.dd[lr].bays; tl[lr]:=vcr.dd[lr].tl;
      tfn[lr]:=vcr.dd[lr].tfn; tf[lr]:=vcr.dd[lr].tfn; launs[lr]:=Min(vcr.dd[lr].launs,20);
      shld[lr]:=Max(vcr.shld[lr],0); name[lr]:=vcr.dd[lr].name;
    end;
    if pic[Right]=0 then pic[Right]:=vcr.plnpic;
    Trim(name[Left]); LPad(name[Left],20);
    SX[Left]:=30; SX[Right]:=IIF(planet=0,$262,$23A); Dist:=SX[Right]-SX[Left];
    for lr:=Left to Right do begin i:=Max(100-dam[lr],0); if i<shld[lr] then shld[lr]:=i; end;

    if Show then
    begin
      LoadPic(Left,pic[Left],pic[Left] in RotPic,pic[Left] in FliPic,Yes,Yes); AnalysePic(Left,pic[Left]);
      LoadPic(Right,pic[Right],pic[Right] in RotPic,not(pic[Right] in FliPic),Yes,Yes); AnalysePic(Right,pic[Right]);
      { El planeta se dibuja como disco (como PVCR), no como el sprite de nave. }
      if planet=1 then BuildPlanetDisc(Right,66);
      ClearDevice; SetPal; TextAttr:=White;
      WriteXY(10,0,name[Left]+'       versus       '+name[Right]);
      WriteXY(32,17,'Distance:    00');
      for lr:=Left to Right do
      begin
        xx:=TX[lr];
        WriteXY(xx,19,'Shield: '+Fmt1w(longint(shld[lr])*10,5)+'% ('+NStr0(shpw[lr])+'tw)');
        WriteXY(xx,20,'Damage: '+Fmt1w(longint(dam[lr])*10,5)+'%');
        if (lr=Left) or (planet=0) then WriteXY(xx,21,'Crew  : '+Fmt1w(longint(crew[lr])*10,6));
        if (tl[lr]>0) and (launs[lr] or tf[lr]>0) then
        begin
          Str(tf[lr]:4,s); WriteXY(xx,22,'Torps :   '+s);
          s:=Torps[tl[lr]].name; Trim(s);
          WriteXY(xx,23,s+Proper(launs[lr],' tube')+' ('+NStr00(launs[lr],'NTP')+')');
        end else
        if bays[lr] or tf[lr]>0 then
        begin
          Str(tf[lr]:4,s); WriteXY(xx,22,'Fgtrs :   '+s);
          WriteXY(xx,23,Proper(bays[lr],'Fighter bay')+' ('+NStr00(bays[lr],'NTP')+')');
        end;
        if weaps[lr]>0 then begin s:=Beams[wl[lr]].name; Trim(s); WriteXY(xx,25,Proper(weaps[lr],s)+' ('+NStr0(weaps[lr])+')'); end;
        xx:=barX[lr];
        Gauge(xx,bshY,_Green,0,shld[lr]);
        Gauge(xx,bdaY,_Red,0,dam[lr]);
        if (lr=Left) or (planet=0) then Gauge(xx,bcrY,_Yellow,0,crew[lr]);
        Gauge(xx,bamY,White,0,tf[lr]);
      end;
      szx[Left]:=ImgW(Left); szx[Right]:=ImgW(Right);
      szy[Left]:=ImgH(Left); szy[Right]:=ImgH(Right);
      x[Left]:=SX[Left]-szx[Left] div 2; x[Right]:=SX[Right]-szx[Right] div 2;
      y[Left]:=SY-szy[Left] div 2; y[Right]:=SY-szy[Right] div 2;
    end;

    for side:=vsLeft to vsRight do for track:=0 to pvMaxFtr-1 do begin pvFX[side,track]:=-1; pvFH[side,track]:=1; end;
    pvDead[Left]:=false; pvDead[Right]:=false;
    vis.startFighter:=pvStartFighter; vis.landFighter:=pvLandFighter; vis.killFighter:=pvKillFighter;
    vis.fireBeam:=pvFireBeam; vis.fireTorpedo:=pvFireTorpedo;
    vis.updateBeam:=nil; vis.updateLauncher:=nil; vis.killObject:=pvKillObject;
    MapVCR(vcr,lobj,robj,seed,sig,flags,btype);
    SetCapabilities(flags);
    SetPhost3(True);    { PHost 3.x/4.x usan la rama "true" (intercept de fighters per-player);
                          solo PHost 2.x (obsoleto) usaria false. Ver pvcralgorithm.hpp. }
    InitBattle(lobj,robj,seed,vis);

    while PlayCycle do
      if Show then
      begin
        pvUpdateShips;
        pvUpdateFighters;
        Delay(WAIT);
        if KeyPressed then
        begin
          ch:=ReadKey;
          case ch of
            27                 : Show:=No;
            ord('1')..ord('9') : WAIT:=(10-(ch-ord('0')))*DDelay;
            ord('-')           : if WAIT<9*DDelay then inc(WAIT,DDelay);
            ord('+')           : if WAIT>1*DDelay then dec(WAIT,DDelay);
          end;
        end;
      end;

    DoneBattle(lobj,robj);
    pvRefreshGauges(vsLeft); pvRefreshGauges(vsRight);
    { refrescar municion/cazas: tras DoneBattle los cazas en vuelo de un objeto
      destruido se pierden (m_activeFighters:=0), asi que el contador mostrado
      debe pasar de reserva+vuelo al valor final (solo reserva), como en PVCR. }
    pvRefreshAmmo(vsLeft); pvRefreshAmmo(vsRight);

    { explosiones de los objetos destruidos, encima de todo (tras los refrescos,
      para que el redibujo de escudos/gauges no las tape); se quita antes el
      escudo, como el Battle clasico. }
    if Show then
      for lr:=Left to Right do
        if pvDead[lr] then
        begin
          DrawShield(lr,Off);
          xx:=x[lr]+szx[lr] div 2;
          LoadPic(lr,ExplPic,No,No,Yes,Yes);
          szx[lr]:=ImgW(lr); szy[lr]:=ImgH(lr);
          x[lr]:=xx-szx[lr] div 2; y[lr]:=SY-szy[lr] div 2;
          SetPal;
          PutImage(x[lr],y[lr],img[lr]^,OrPut);
        end;

    vcr.shld[Left]:=VcrCurShield(vsLeft);   vcr.shld[Right]:=VcrCurShield(vsRight);
    vcr.dd[Left].dam:=VcrCurDamage(vsLeft); vcr.dd[Right].dam:=VcrCurDamage(vsRight);
    vcr.dd[Left].crew:=VcrCurCrew(vsLeft);  vcr.dd[Right].crew:=VcrCurCrew(vsRight);
    vcr.dd[Left].tfn:=VcrObjInfo(vsLeft).numFighters;   vcr.dd[Right].tfn:=VcrObjInfo(vsRight).numFighters;
    { resultado -> pic, para los rotulos /Destroyed/ /Captured/ del resumen }
    res:=BattleResult;
    if res.leftDestroyed  then vcr.dd[Left].pic :=ExplPic else if res.leftCaptured  then vcr.dd[Left].pic :=SurrPic;
    if res.rightDestroyed then vcr.dd[Right].pic:=ExplPic else if res.rightCaptured then vcr.dd[Right].pic:=SurrPic;

    { Captura (nave con tripulacion a 0 pero sin destruir): no explota, pero se
      anuncia arriba, como PVCR.EXE. }
    if Show and (res.leftCaptured or res.rightCaptured) then
    begin
      TextAttr:=_Yellow;
      WriteXY(28,2,'SHIP HAS BEEN CAPTURED!');
    end;

    if Show then    { pausa al final (como el Battle clasico) para ver el resultado }
    begin
      TextAttr:=_Yellow;
      WriteXY(30,28,'PRESS ENTER TO RETURN');
      ReadKey;
    end;
    if Animate then ClearDevice;
  end;

End.