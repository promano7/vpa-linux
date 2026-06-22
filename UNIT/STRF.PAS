Unit    StrF;           (* String Functions *)
{$V-}


Interface

type    str20   = string[20];
	str40   = string[40];
	str79   = string[79];
  str30   = string[30];
  str60   = string[60];
	filename= string[12];
	fileext	= string[3];

procedure LTrim (var s:string);
procedure RTrim (var s:string);
procedure Trim (var s:string);
function  ITrim (s:string) : string;
function  RLen (s:string) : byte;
procedure LPad (var s:string; l:byte);
procedure RPad (var s:string; l:byte);
procedure Upper (var s:string);
procedure Lower (var s:string);
procedure Capitalize (var s:string);
procedure ProcessTabs (var s:string);
function  Value (s:str20) : longint;
function  NStr (a:longint) : str20;
function  NStr0 (a:longint) : str20;
function  NStr00 (a:longint; s0:str20) : str20;
function  NSStr(a:longint):str20;
function  NStrMax (a:longint; n:byte; c:char) : str20;
function  NStrDiff (a:longint; n:byte) : str20;
function  Proper (n:byte; s:str20) : str20;
function  LeftWord (s:string) : str20;
function  Parse (var s,s1:string; delim:str20) : char;
procedure StrSubst (var s:string; a,b:str20);
function  StrCmp (s1,s2:str40; l:byte) : boolean;
function  PosInStr (var s1,s2: string) : byte;
function  ItemPos (var s1:string; var s) : word;
procedure ItemStr (var s; n:word; var s1:string);

const   UChr    : array [0..255] of char =
	#$00#$01#$02#$03#$04#$05#$06#$07#$08#$09#$0A#$0B#$0C#$0D#$0E#$0F+
	#$10#$11#$12#$13#$14#$15#$16#$17#$18#$19#$1A#$1B#$1C#$1D#$1E#$1F+
	#$20#$21#$22#$23#$24#$25#$26#$27#$28#$29#$2A#$2B#$2C#$2D#$2E#$2F+
	#$30#$31#$32#$33#$34#$35#$36#$37#$38#$39#$3A#$3B#$3C#$3D#$3E#$3F+
	#$40'ABCDEFGHIJKLMNOPQRSTUVWXYZ'#$5B#$5C#$5D#$5E#$5F+
	#$60'ABCDEFGHIJKLMNOPQRSTUVWXYZ'#$7B#$7C#$7D#$7E#$7F+
	'€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ'+
	'€‚ƒ„…†‡ˆ‰Š‹ŒŽ'+
	#$B0#$B1#$B2#$B3#$B4#$B5#$B6#$B7#$B8#$B9#$BA#$BB#$BC#$BD#$BE#$BF+
	#$C0#$C1#$C2#$C3#$C4#$C5#$C6#$C7#$C8#$C9#$CA#$CB#$CC#$CD#$CE#$CF+
	#$D0#$D1#$D2#$D3#$D4#$D5#$D6#$D7#$D8#$D9#$DA#$DB#$DC#$DD#$DE#$DF+
	'‘’“”•–—˜™š›œžŸ'+
	#$F0#$F1#$F2#$F3#$F4#$F5#$F6#$F7#$F8#$F9#$FA#$FB#$FC#$FD#$FE#$FF;
	LChr    : array [0..255] of char =
	#$00#$01#$02#$03#$04#$05#$06#$07#$08#$09#$0A#$0B#$0C#$0D#$0E#$0F+
	#$10#$11#$12#$13#$14#$15#$16#$17#$18#$19#$1A#$1B#$1C#$1D#$1E#$1F+
	#$20#$21#$22#$23#$24#$25#$26#$27#$28#$29#$2A#$2B#$2C#$2D#$2E#$2F+
	#$30#$31#$32#$33#$34#$35#$36#$37#$38#$39#$3A#$3B#$3C#$3D#$3E#$3F+
	#$40'abcdefghijklmnopqrstuvwxyz'#$5B#$5C#$5D#$5E#$5F+
	#$60'abcdefghijklmnopqrstuvwxyz'#$7B#$7C#$7D#$7E#$7F+
	' ¡¢£¤¥¦§¨©ª«¬­®¯àáâãäåæçèéêëìíîï'+
	' ¡¢£¤¥¦§¨©ª«¬­®¯'+
	#$B0#$B1#$B2#$B3#$B4#$B5#$B6#$B7#$B8#$B9#$BA#$BB#$BC#$BD#$BE#$BF+
	#$C0#$C1#$C2#$C3#$C4#$C5#$C6#$C7#$C8#$C9#$CA#$CB#$CC#$CD#$CE#$CF+
	#$D0#$D1#$D2#$D3#$D4#$D5#$D6#$D7#$D8#$D9#$DA#$DB#$DC#$DD#$DE#$DF+
	'àáâãäåæçèéêëìíîï'+
	#$F0#$F1#$F2#$F3#$F4#$F5#$F6#$F7#$F8#$F9#$FA#$FB#$FC#$FD#$FE#$FF;

Implementation

procedure LTrim (var s:string);
  var   ls      : byte absolute s;
  begin
    while (ls>0) and (s[1] in [' ',#9]) do Delete(s,1,1);
  end;

procedure RTrim (var s:string);
  var   ls      : byte absolute s;
  begin
    while (ls>0) and (s[ls] in [' ',#9]) do dec(ls);
  end;

procedure Trim (var s:string);
  begin
    RTrim(s);
    LTrim(s);
  end;

function ITrim(s:string):string;
  begin  Trim(s); ITrim:=s;  end;

function RLen (s:string) : byte;
  var   ls      : byte absolute s;
  begin
    RTrim(s);
    RLen:=ls;
  end;

procedure LPad (var s:string; l:byte);
  var   ls      : byte absolute s;
  begin
    while ls<l do s:=' '+s;
  end;

procedure RPad (var s:string; l:byte);
  var   ls      : byte absolute s;
  begin
    while ls<l do s:=s+' ';
  end;

procedure Upper (var s:string);
  var   ls      : byte absolute s;
	i       : byte;
  begin
    for i:=1 to ls do s[i]:=UChr[byte(s[i])];
  end;

procedure Lower (var s:string);
  var   ls      : byte absolute s;
	i       : byte;
  begin
    for i:=1 to ls do s[i]:=LChr[byte(s[i])];
  end;

procedure Capitalize (var s:string);
  var   ls      : byte absolute s;
	i       : byte;
  begin
    i:=1;
    while i<=ls do
    begin
      while (i<=ls) and (s[i] in [' ',#9]) do inc(i);
      s[i]:=UChr[byte(s[i])]; inc(i);
      while (i<=ls) and not (s[i] in [' ',#9]) do
       begin s[i]:=LChr[byte(s[i])]; inc(i) end;
    end;
  end;

procedure ProcessTabs (var s:string);
  var   ls      : byte absolute s;
	i       : byte;
	s1	: string[7];
  begin
    i:=Pos(#9,s);
    while i<>0 do
    begin
      byte(s1[0]):=9-(i and 7);
      FillChar(s1[1],byte(s1[0]),' ');
      s:=Copy(s,1,i-1)+s1+Copy(s,i+1,255);
      i:=Pos(#9,s);
    end;
  end;

function Value (s:str20) : longint;
  var   a       : integer;
	i	: byte absolute a;
	ls	: byte absolute s;
	l       : longint;
  begin
    Trim(s);
    Upper(s);
    i:=1;
    if (ls>1) and (s[1] in ['-','$']) then inc(i);
    while (i<=ls) and ( (s[i] in ['0'..'9']) or ((s[1]='$') and (s[i] in ['A'..'F'])) ) do inc(i);
    ls:=i-1;
    Val(s,l,a); Value:=l;
  end;

function NStr (a:longint) : str20;
  var   s       : str20;
  begin
    if a=0 then s:=''
	   else Str(a,s);
    NStr:=s;
  end;

function NStr0 (a:longint) : str20;
  var   s       : str20;
  begin
    if a=0 then s:='0'
	   else Str(a,s);
    NStr0:=s;
  end;

function NStr00 (a:longint; s0:str20) : str20;
  var   s       : str20;
  begin
    if a=0 then s:=s0
	   else Str(a,s);
    NStr00:=s;
  end;

function NSStr(a:longint):str20;
  var s:str20;
  begin
    s:=NStr0(a);
    if a>=0 then s:='+'+s;
    NSStr:=s;
  end;

function NStrMax (a:longint; n:byte; c:char) : str20;
  var   s       : str20;
	ls	: byte absolute s;
  begin
    Str(a:n,s);
    if ls>n then
    begin
      ls:=0;
      while ls<n do s:=s+c;
    end;
    NStrMax:=s;
  end;

function NStrDiff (a:longint; n:byte) : str20;
  var	s	: str20;
	ls	: byte absolute s;
	c	: char;
  begin
    ls:=0;
    if a<>0 then
    begin
      if a>0 then c:='+' else c:='-';
      s:=NStrMax(Abs(a),n,c);
      LTrim(s);
      s:='('+c+s+')';
    end;
    RPad(s,n+3);
    NStrDiff:=s;
  end;

function Proper (n:byte; s:str20) : str20;
  var   ls      : byte absolute s;
  begin
    while (ls>0) and (s[ls] in [' ',#9]) do dec(ls);
    if n<>1 then s:=s+'s';
    Proper:=s;
  end;

function LeftWord (s:string) : str20;
  var   i       : byte;
	ls      : byte absolute s;
	a       : str20;
  begin
    LTrim(s);
    a:=''; i:=1;
    while (i<=ls) and not (s[i] in [' ',#9]) do
      begin a:=a+s[i]; inc(i) end;
    LeftWord:=a;
  end;

function Parse (var s,s1:string; delim:str20) : char;
  var   i	: byte;
	ls	: byte absolute s;
	ls1	: byte absolute s1;
	ddel	: boolean;
  begin
    LTrim(s);		{ erase spaces and tabs at the beginning of s }
    ls1:=0;
    i:=1;
    repeat
      while (i<=ls) and (Pos(s[i],delim)=0) do
	begin s1:=s1+s[i]; inc(i) end;
      ddel:=(i<ls) and (not (s[i] in [' ',#9])) and (s[i]=s[i+1]);
      if ddel then begin s1:=s1+s[i]; inc(i,2) end;
    until not ddel;
    if i>ls then Parse:=#0
	    else Parse:=s[i];	{ returns delimiter or #0 if eol }
    Delete(s,1,i);
  end;

procedure StrSubst (var s:string; a,b:str20);
  var   k,k0	: integer;
	ls	: byte absolute s;
	la	: byte absolute a;
	lb	: byte absolute b;
  begin
    k0:=0;
    repeat
      k:=Pos(a,Copy(s,k0+1,255));
      if k<>0 then s:=Copy(s,1,k0+k-1)+b+Copy(s,k0+k+la,255);
      k0:=k+lb-1;
    until (k=0) or (k>ls);
  end;

function StrCmp (s1,s2:str40; l:byte) : boolean;
  var   i       : byte;
	ls1	: byte absolute s1;
	ls2	: byte absolute s2;
  begin
    if (ls1<l) or (ls2<l) then begin StrCmp:=False; Exit end;
    StrCmp:=True;
    for i:=1 to l do
      if UChr[byte(s1[i])]<>UChr[byte(s2[i])] then
	begin StrCmp:=False; Break end;
  end;

function PosInStr (var s1,s2: string) : byte;
	 (* returns the position of s1 in s2, case-independent *)
  var	i,j	: byte;
	c1	: char;
	ls1	: byte absolute s1;
	ls2	: byte absolute s2;
	found	: boolean;
  begin
    PosInStr:=0;
    if (ls1=0) or (ls1>ls2) then Exit;
    c1:=UChr[byte(s1[1])];
    for i:=1 to ls2 do
      if UChr[byte(s2[i])]=c1 then
      begin
	found:=True;
	for j:=1 to ls1-1 do
	  if UChr[byte(s2[i+j])]<>UChr[byte(s1[1+j])] then
	    begin found:=False; Break end;
	if found then begin PosInStr:=i; Exit end;
      end;
  end;

function ItemPos (var s1:string; var s) : word; { item no. is 0-based }
  { s MUST be terminated with two spaces }
  type TBuf = array[0..65535] of char;
  var  sb : TBuf absolute s;
       ls1, di, k, item : word;
  begin
    ls1 := Length(s1);
    item := 0;
    di := 0;
    repeat
      k := 1;
      while (k <= ls1) and (sb[di] <> ' ') and (sb[di] = s1[k]) do
        begin inc(di); inc(k); end;
      if (k > ls1) and (sb[di] = ' ') then
        begin ItemPos := item; Exit; end;
      while sb[di] <> ' ' do inc(di);
      inc(di);
      inc(item);
    until sb[di] = ' ';
    ItemPos := item;
  end;

procedure ItemStr (var s; n:word; var s1:string);
  { item #n terminated by a space must exist in s; n is 0-based }
  type TBuf = array[0..65535] of char;
  var  sb : TBuf absolute s;
       di, len : word;
  begin
    di := 0;
    while n > 0 do
      begin
        while sb[di] <> ' ' do inc(di);
        inc(di);
        dec(n);
      end;
    len := 0;
    while sb[di] <> ' ' do
      begin inc(len); s1[len] := sb[di]; inc(di); end;
    s1[0] := Chr(len);
  end;

End.
