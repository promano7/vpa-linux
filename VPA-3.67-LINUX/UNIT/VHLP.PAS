Unit	VHLP;
{$I-}

Interface

uses	AuxF;

const	VHLPid	: array [1..4] of char = 'VHLP';
	VHLPver	: byte = 1;
	VHDoffs	= 5;			{ offset of the 1st dir entry }

type	VHRec	= record		{ item header }
		    t	: char;		{ T,C }
		    c	: byte;
		    x,y	: int;
		  end;
	    VDRec	= record		{ dir entry }
		    id	: int;
		    ofs	: long;
		    len	: int;
		  end;

{
	VHLP file format:
	"VHLP"<byte_ver>
	<int_pageid><long_offset><int_length>
	...
	<int_-1>
	"T"<byte_color><int_x><int_y><lstring>			text
	"C"<byte_color><int_x><int_y><int_radius>		circle
	"L"<byte_color><int_x1><int_y1><int_x2><int_y2>		line
	"F"<byte_color><int_x1><int_y1><int_x2><int_y2>		fill
	"R"<byte_color><int_x1><int_y1><int_x2><int_y2>		rectangle
	"$$"<int_key><int_pageid>				hotkey
	...
}

procedure ShowHelp (var f:file; pageid:int);

Implementation

uses	Graph,Keyboard;

procedure ShowHelp (var f:file; pageid:int);
  var   vd	: VDRec;
	vh	: VHRec;
	s	: string;
	ls	: byte absolute s;
	r,x2,y2	: int;
	keys	: array [1..100,1..2] of word;	{ up to 100 hotkeys }
	nkeys,k	: byte;
	ch	: word;
  begin
    if pageid=-1 then Exit;
    repeat
      if pageid<>-1 then
      begin
	Seek(f,VHDoffs);
	repeat
	  BlockRead(f,vd,SizeOf(vd));
	until Eof(f) or (vd.id=-1) or (vd.id=pageid);
	if vd.id<>pageid then Exit;
	nkeys:=0;
	Seek(f,vd.ofs);
	while (not Eof(f)) and (FilePos(f)<vd.ofs+vd.len) do
	begin
	  BlockRead(f,vh,SizeOf(vh));
	  case vh.t of
	    '$'	: begin				{ hotkey }
		    inc(nkeys);
		    keys[nkeys,1]:=vh.x;
		    keys[nkeys,2]:=vh.y;
		  end;
	    'C'	: begin				{ C }
		    BlockRead(f,r,2);
		    SetColor(vh.c);
		    Circle(vh.x,vh.y,r);
		  end;
	    'L'	: begin				{ L }
		    BlockRead(f,x2,2);
		    BlockRead(f,y2,2);
		    SetLineStyle(SolidLn,0,NormWidth);
		    SetColor(vh.c);
		    Line(vh.x,vh.y,x2,y2);
		  end;
	    'F'	: begin				{ F }
		    BlockRead(f,x2,2);
		    BlockRead(f,y2,2);
		    SetFillStyle(SolidFill,vh.c);
		    Bar(vh.x,vh.y,x2,y2);
		  end;
	    'R'	: begin				{ R }
		    BlockRead(f,x2,2);
		    BlockRead(f,y2,2);
		    SetLineStyle(SolidLn,0,NormWidth);
		    SetColor(vh.c);
		    Rectangle(vh.x,vh.y,x2,y2);
		  end;
	    else  begin				{ T }
		    BlockRead(f,ls,1);
		    BlockRead(f,s[1],ls);
		    SetColor(vh.c);
		    OutTextXY(vh.x,vh.y,s);
		  end;
	  end;
	end;
      end;
      ch:=ReadKey;
      pageid:=-1;
      for k:=1 to nkeys do
        if ch=keys[k,1] then begin pageid:=keys[k,2]; Break end;
    until ch=27;
  end;

End.