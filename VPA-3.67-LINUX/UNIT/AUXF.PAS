Unit	AuxF;		(* Auxiliary Functions And Definitions *)
{$V-}


Interface

type	int	= integer;
	long	= longint;
	CharArr	= array [1..MaxInt] of char;
	ByteArr	= array [1..MaxInt] of byte;
	IntArr	= array [1..MaxInt] of int;
	LongArr	= array [1..MaxInt div 2] of long;

const	Yes	= True;
	No	= False;
	On	= True;
	Off	= False;

function  IIF (b:boolean; a1,a2:int) : int;
function  IIFL(b:boolean; a1,a2:long) : long;
function  Within (a,a1,a2:int) : boolean;
function  Sign (a:int) : int;
function  Min (a,b:int) : int;
function  Max (a,b:int) : int;
function  MinL (a,b:long) : long;
function  MaxL (a,b:long) : long;
function  Diff (var arg1,arg2; count:word) : boolean;
procedure Delay (ms:word);
procedure Sound (hz:word);
procedure NoSound;
function  Timer : long;
(* procedure RealModeInt (n:byte;_ds,_es,_ax,_cx,_dx,_bx,_bp,_si,_di:word); *)

Implementation

uses SysUtils;  { Sleep, GetTickCount64 }



function IIF (b:boolean; a1,a2:int) : int;
  begin if b then IIF:=a1 else IIF:=a2; end;

function IIFL(b:boolean; a1,a2:long) : long;
  begin if b then IIFL:=a1 else IIFL:=a2; end;

function Within (a,a1,a2:int) : boolean;
  { Semantica EXACTA del asm original: True si (a>=a1) y (a<>a2) }
  begin Within := (a >= a1) and (a <> a2); end;

function Sign (a:int) : int;
  begin if a<0 then Sign:=-1 else if a>0 then Sign:=1 else Sign:=0; end;

function Min (a,b:int) : int;
  begin if a<=b then Min:=a else Min:=b; end;

function Max (a,b:int) : int;
  begin if a>=b then Max:=a else Max:=b; end;

function MinL (a,b:long) : long;
  begin if a<b then MinL:=a else MinL:=b; end;

function MaxL (a,b:long) : long;
  begin if a>b then MaxL:=a else MaxL:=b; end;

function Diff (var arg1,arg2; count:word) : boolean;
  { True si los 'count' bytes difieren }
  begin Diff := CompareByte(arg1, arg2, count) <> 0; end;

procedure Delay (ms:word);
  begin Sleep(ms); end;

procedure Sound (hz:word);
  begin { TODO: altavoz PC no portable a Linux userspace; no-op por ahora } end;

procedure NoSound;
  begin { TODO: ver Sound } end;

function Timer : long;
  { ticks ~18.2 Hz como la cuenta de la BIOS (1 tick ~ 55 ms) }
  begin Timer := long(GetTickCount64 div 55); end;

End.
