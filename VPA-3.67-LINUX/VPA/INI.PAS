{
*******************************************************************
* INI.PAS - Main Part - Ini-Handlings
*
* $Id: ini.pas,v 1.12 2013/12/29 06:41:03 sfplanets Exp $
*
  New unit intended to handle access to all ini-stuff:
  read, store, display and make available entries of ini-files
  and read/write changed ini-files.

  this unit is an early version yet - I think I should change to
  objects to handle the different data-types better, also I need
  some faster search structures and all data-types except bool/boolinv
  need to be implemented. So this file is to be changed by me completely
  from one day to another.

  If saving works we need a function to read in the ini-Files again.

  We needed a new way to read ini-files because the method of config.pas
  is not flexible enough to add new options regularly - I hop this unit
  will do that better.
 
  BBU
*
*********************************************************************
}

Unit Ini;

Interface

uses strf;

type
   ini_files  = (ini_file_vpa,ini_file_cmistakes,ini_file_addon,ini_file_vpahelp);
   ini_sizes  = (ini_size_void,ini_size_bool,ini_size_boolinv,ini_size_int);
    
procedure ini_add(ini_file : ini_files;section:str20;name:str20;text:str20;size:ini_sizes;buf:pointer);
procedure ini_showmenu(ini_file : ini_files;cansave:boolean);
function ini_initialized(ini_file : ini_files):boolean;
procedure ini_save(ini_file : ini_files);
procedure ini_read(ini_file : ini_files);
procedure ini_resetstate(ini_file : ini_files);
procedure ini_initialize;
procedure Check_VPAHelp;
function GetIniFile(ini_file : ini_files):string;

{
 % intended new functions:
 % get/set entries without accesing the memory directly (for all types)
function ini_getbool(ini_file:ini_files;name:str20):boolean;
procedure ini_setbool(ini_file:ini_files;name:str20;value:boolean);
 % for parsing ini-files : do we know this key?
function ini_findkey(ini_file:ini_files;name:str20):boolean;
 % parse a line of an ini-file (only after successfull findkey);
procedure ini_parseline(ini_file:ini_files;name:str20;line:string);
 %
 % todo:
 % - handle different data-types better
 % - complete saving of ini-files
 % - implement reading of ini-files
 % - make compatible to pconfig.src
 % - improve memory usage (shorter strings)
 % - improve search speed (no sequential lists - better trees and
     at least several separate lists for the different ini-files,
     fast searching by trees or hash-tables)
}

Implementation

uses Graph,auxf,Screen,Vpadata,vpainit,rst_trn,extfeat,vpa3,messages, Config,vpa4,dos,vpa2;

type
   Pini_entry = ^Tini_entry;
   Tini_entry = record
       next      : Pini_entry;
       ini_file    : ini_files;
       section     : str20;
       name      : str20;
       text      : str20;
       found     : boolean;
       changed     : boolean;
       case size     : ini_sizes of
         ini_size_void : (buf:Pointer);
         ini_size_bool    : (EBool:^Boolean); 
         ini_size_boolinv : (EBoolinv:^Boolean); 
         ini_size_int     : (EInt:^int);
    end;

var
   ini_entries : Pini_entry;

Procedure ini_init_vpa;
begin
   ini_add(ini_file_vpa,'Interface','AutoScroll','',ini_size_bool,@AutoScroll);
   ini_add(ini_file_vpa,'Interface','StickyMouse','',ini_size_bool,@StickyMouse);
   ini_add(ini_file_vpa,'Interface','LargePlanets','',ini_size_bool,@LargePlanets);
   ini_add(ini_file_vpa,'Interface','PlanetNames','',ini_size_bool,@PlanetNames);
   ini_add(ini_file_vpa,'Interface','SmallFont','',ini_size_bool,@UseSmallFont);
   ini_add(ini_file_vpa,'Interface','KeepWayPoints','',ini_size_bool,@KeepWayPoints);
   ini_add(ini_file_vpa,'Interface','AutoUseGravity','',ini_size_bool,@AutoUseGravity);
   ini_add(ini_file_vpa,'Interface','DullMissions','',ini_size_bool,@DullMissions);
   ini_add(ini_file_vpa,'Interface','DullMessages','',ini_size_boolinv,@BlankDeadRaces);
   ini_add(ini_file_vpa,'Interface','OptimizeFuel','',ini_size_bool, @OptimizeFuel);
   ini_add(ini_file_vpa,'Interface','AutoAdjustWarp','',ini_size_bool, @AutoAdjustWarp);
   ini_add(ini_file_vpa,'Interface','AltWormholes','',ini_size_bool,@AltWormholes);
   { ScreenSaverTime:int }
   ini_add(ini_file_vpa,'Interface','DeleteRST','',ini_size_bool,@DeleteRST);
   ini_add(ini_file_vpa,'Interface','ScrambleShipNames','',ini_size_bool,@ScrambleShipNames);
   ini_add(ini_file_vpa,'Interface','ShowFinalHappy','',ini_size_bool,@ShowFinalHappy);
   ini_add(ini_file_vpa,'Interface','ShowMaxPop','',ini_size_bool,@ShowMaxPop);
   ini_add(ini_file_vpa,'Interface','ShowColonistPrediction','',ini_size_bool,@ShowColonistPrediction);
   ini_add(ini_file_vpa,'Interface','ShowCombatStrength','',ini_size_bool,@ShowCombatStrength);
   ini_add(ini_file_vpa,'Interface','ShowMapBorder','',ini_size_bool,@ShowMapBorder);
   ini_add(ini_file_vpa,'Interface','ShowCheckMark','',ini_size_bool,@ShowCheckMark);
   ini_add(ini_file_vpa,'Interface','ShowScoreValue','',ini_size_bool,@ShowScoreValue);
   ini_add(ini_file_vpa,'Interface','AutoDisapprove','',ini_size_bool,@AutoDisapprove);
   ini_add(ini_file_vpa,'Interface','ConfirmNotes','',ini_size_bool,@ConfirmNotes);
   { ScoringMethod:string }
   ini_add(ini_file_vpa,'System','BadVideoOrMouse','',ini_size_bool,@BadVideoOrMouse);
{   ini_add(ini_file_vpa,'Test','Test','',ini_size_bool,@BadVideoOrMouse); }
end; { ini_init_vpa }


procedure ini_add(ini_file : ini_files;section:str20;name:str20;text:str20;size:ini_sizes;buf:pointer);
var entries : Pini_entry;
begin
   entries:=ini_entries;
   while (entries^.next<>NIL) do entries:=entries^.next;
   entries^.ini_file:=ini_file;
   entries^.section:=section;
   Upper(entries^.section);
   entries^.name:=name;
   Upper(entries^.name);
   if (text='') then entries^.text:=name else entries^.text:=text;
   entries^.size:=size;
   if (buf<>NIL) then
      entries^.buf:=buf
   else
      case size of
  ini_size_bool  : New(entries^.EBool);
  ini_size_boolinv : New(entries^.EBoolinv);
  ini_size_int     : New(entries^.Eint);
      else
   buf:=NIL;
      end;
   new(entries^.next);
   entries^.next^.next:=NIL;
end; { ini_add }

procedure ini_showmenu(ini_file : ini_files;cansave:boolean);
const
   maxline    = 20;
   maxwidth   = 35;
   maxentries   = 50;
	 On_ = 'On  ';
	 Off_ = 'Off ';
	 hlpfile : string = '';
var
   entries  : Pini_entry;
   lines  : array[1..maxentries] of Pini_entry;
	 hlpfound : array[1..maxentries] of boolean;
   linenum  : integer;
   controllines : integer;
   tstr   : string;
   leave  : boolean;	 
	 clr : int;
	 
begin
  leave:=False;
  { todo: keep cursor position after selecting an entry }
  while not leave do begin
		NewMenu;
		UnLockReservedMemory(MenuSize(10,10,10+8*maxwidth,maxline,Yes));
		controllines:=2;
		AddMenuItem('Done',Green,No);
		if cansave then begin
			AddMenuItem('Reload from '+GetIniFile(ini_file),Green,No);
			AddMenuItem('Save '+GetIniFile(ini_file),Green,No);
			AddMenuItem('Edit file with ''Edit.com''',Green,No);
			controllines:=controllines+3;
		end;
		AddMenuItem('------------------------------------',Green,No);
		linenum:=controllines;
		entries:=ini_entries;
		while (entries^.next<>NIL) do begin
			if ini_file=entries^.ini_file then
				with entries^ do begin
				 { use ini_valuestr here }
					case size of
						 ini_size_bool    : if (EBool^) then tstr:=On_ else tstr:=Off_;
						 ini_size_boolinv : if (EBoolinv^) then tstr:=Off_ else tstr:=On_;
						 ini_size_int     : tstr:=Nstr00(EInt^,'0000');
					end; { case }
					if (ini_file = ini_file_vpahelp) then begin 
						if tstr='Off ' then begin
							clr := red;
							tstr:= 'N/A  ';
							hlpfound[linenum+1] := FALSE;
						end else begin
							clr := green;
							hlpfound[linenum+1] := TRUE;
							if (linenum>controllines+1) then tstr:= 'Help'+nstr(linenum-controllines) 													 else tstr:= 'Exec ';							
						end;
					end else begin
						clr := yellow;
				 end;
				 tstr:=tstr+' : '+text;
				 AddMenuItem(tstr,clr,No);
				 linenum:=linenum+1;
				 lines[linenum]:=entries;
				 if (linenum>=maxentries-1) then begin
					AddMenuItem('Too much entries - report to author',Red,No);
					lines[linenum+1]:=entries;
		break;
				 end;
			end;
			entries:=entries^.next;
		end;
		ChooseMenu(10,10,10,10+8*maxwidth,maxline,White,Yellow,1,No,Yes,-1);
		If (MenuKey<>27) and (MenuValue<maxentries) then begin
		if (MenuValue>controllines) then begin
			with lines[MenuValue]^ do begin
				if (ini_file = ini_file_vpahelp) then begin 
					if (hlpfound[1+controllines]) and (hlpfound[MenuValue]) then begin 
						RestoreCrtMode;										{files are here}
						if (MenuValue-controllines = 1) then hlpfile := '  ' else hlpfile:=name;
						Exec(lines[1+controllines]^.name,hlpfile); 
						if DosError<>0 then begin 
							Writeln('Can''t run '+lines[1+controllines]^.name+' '+hlpfile+'(DOS Error '+NStr0(DosError)+')');
							PressAnyKey;
						end;
						if customBGI then SetGraphMode(bgiMode) else
						if not useSVGA then SetGraphMode(VGAHi) else SetGraphMode(gmVesa640x480x256);						
						NewMenu;
						LockReservedMemory;
						ResetMouseAndVideo;
						exit;
					end;
				end else begin
					case size of
						ini_size_bool : EBool^:=not EBool^;
						ini_size_boolinv : EBoolinv^:=not EBoolinv^;
						ini_size_int     : begin         {Quapla: Valid 0-5000 only }
																Eint^:=Eint^+1000;
																if Eint^>5000 then Eint^:=0;
															 end;
					end; { case }
					changed:=True;
				end;
			end;
		end else begin
			if (MenuValue=1) then leave:=True;
			if ((MenuValue=2) and cansave) then ini_read(ini_file);
			if ((MenuValue=3) and cansave) then ini_save(ini_file);
			if ((MenuValue=4) and cansave) then begin
			  RestoreCrtMode;
				Exec('edit.com',GetIniFile(ini_file));
				if DosError<>0 then begin 
							Writeln('Can''t run ''edit.com'' '+GetIniFile(ini_file)+'(DOS Error '+NStr0(DosError)+')');
							PressAnyKey;
				end else begin
					Ini_Read(ini_file_vpahelp); 
					Check_VPAHelp;
				end;
				if customBGI then SetGraphMode(bgiMode) else
				if not useSVGA then SetGraphMode(VGAHi) else SetGraphMode(gmVesa640x480x256);
				NewMenu;
				LockReservedMemory;
				ResetMouseAndVideo;
				exit;
			end;
 end;
		end else if ((MenuKey=27) or (MenuValue<controllines)) then begin
			leave:=True;
		end;
		NewMenu;
		LockReservedMemory;
 end;
end; { ini_showmenu }

function ini_initialized(ini_file : ini_files):boolean;
var entries : Pini_entry;
begin
   entries:=ini_entries;
   while (entries^.next<>NIL) do begin
      if (entries^.ini_file=ini_file) then begin
				ini_initialized:=True;
				Exit;
      end;
      entries:=entries^.next;
   end;
   ini_initialized:=False;
end;

function ini_issection(ini_file : ini_files;s:string):str20;
var
   ls : byte absolute s;
begin
   Trim(s);
   if (s[1]='[') and (s[ls]=']') then begin
      dec(ls);
      Delete(s,1,1);
      Trim(s);
      Upper(s);
      ini_issection:=s;
   end else begin
      ini_issection:='';
   end;
end; { ini_issection }

function ini_findmissing(ini_file : ini_files;section:str20):Pini_entry;
var entries : Pini_entry;
begin
   entries:=ini_entries;
   while (entries^.next<>NIL) do begin
      if (entries^.ini_file=ini_file) and (entries^.found=false) and
   ((section='') or (section=entries^.section)) then begin
      ini_findmissing:=entries;
      Exit;
   end;
      entries:=entries^.next;
   end;
   ini_findmissing:=NIL;
end;

function ini_valuestr(entries : Pini_entry):str20;
var s : str20;
begin
   s:='';
   case entries^.size of
     ini_size_bool    : if entries^.EBool^ then s:='Yes' else s:='No';
     ini_size_boolinv : if entries^.EBoolinv^ then s:='No' else s:='Yes';
     ini_size_int     : s:=Nstr00(entries^.EInt^,'0000');
   end; { case }
   ini_valuestr:=s;
end;

function ini_getvalue(entries : Pini_entry;s:string):boolean;
var
   ok : boolean;
begin
  ok:=True;
  case entries^.size of
		ini_size_bool: begin
      Upper(s);
      entries^.EBool^:=((s='YES') or (s='ON') or (s='RULEZ') or (s='EXTERNAL') or (s='ALLIES') or (s='TRUE'));
    end;
    ini_size_boolinv: begin
      Upper(s);
      entries^.EBoolinv^:=not ((s='YES') or (s='ON') or (s='RULEZ') or (s='EXTERNAL') or (s='ALLIES') or (s='TRUE'));
    end;
    ini_size_int: begin
      entries^.EInt^:=Value(s);         {Quapla check if that works...}
    end;
   else begin
      Writeln('ini_size_error: ini_getvalue');
      ok :=False;
   end;
   end;
   if not ok then
     Writeln('Could not understand "',s,'" (',entries^.text,')');
     ini_getvalue := ok;
end; { ini_getvalue }   

function ini_copy(entry1 : Pini_entry):Pini_entry;
var entry2 : Pini_entry;
begin
   new(entry2);
   entry2^:=entry1^;
   case entry1^.size of
     ini_size_bool    : begin
        new(entry2^.EBool);
        entry2^.EBool^:=entry1^.EBool^;
     end;
     ini_size_boolinv : begin
        new(entry2^.EBoolinv);
        entry2^.EBoolinv^:=entry1^.EBoolinv^;
     end;
     ini_size_int : begin
        new(entry2^.Eint);
        entry2^.Eint^:=entry1^.Eint^;
     end;
   else begin       
      Writeln('ini_size_error: ini_copy');
   end;
   end;
   entry2^.size:=entry1^.size;
   entry2^.text:=entry1^.text;
   ini_copy:=entry2;
end; { ini_copy }

function ini_equal(entry1,entry2 : Pini_entry):boolean;
begin
   if (entry1^.size<>entry2^.size) then begin
      ini_equal:=False;
      writeln('Different size');
      Exit;
   end;
   case entry1^.size of
     ini_size_bool : 
        ini_equal:=(entry2^.EBool^=entry1^.EBool^);
     ini_size_boolinv : 
        ini_equal:=(entry2^.EBoolinv^=entry1^.EBoolinv^);
     ini_size_int:
        ini_equal:=(entry2^.Eint^=entry1^.Eint^);
   else
      Writeln('ini_size_error: ini_equal');      
   end;
end; { ini_equal }

procedure ini_free(entry : Pini_entry);
begin
   case entry^.size of
     ini_size_bool    : Dispose(entry^.EBool);
     ini_size_boolinv : Dispose(entry^.EBoolinv);
     ini_size_int     : Dispose(entry^.Eint);
   end; { case }
   Dispose(entry);
end; { ini_free }

function ini_checkchanged(ini_file : ini_files;section:str20;s:string):Pini_entry;
var
   entries  : Pini_entry;
   ls     : byte absolute s;
   i      : integer;
   key      : string;
   tmpentry : Pini_entry;
begin
   ini_checkchanged:=NIL;
   Trim(s);
   if (ls=0) then Exit;
   i:=Pos('=',s); if i=0 then Exit;
   key:=Copy(s,1,i-1);
   Trim(key);
   Upper(key);
   Delete(s,1,i);
   LTrim(s);
   i:=Pos('#',s);
   if i<>0 then begin
      ls := i-1;
      Trim(s);
   end;
   
   entries:=ini_entries;
   while (entries^.next<>NIL) do begin
      if (entries^.ini_file=ini_file) and (entries^.found=false) and
   (section=entries^.section) and (key=entries^.name) then begin
      entries^.found:=true;
      tmpentry:=ini_copy(entries);
      if ini_getvalue(tmpentry,s) then begin
         if (not ini_equal(entries,tmpentry)) then begin
      ini_checkchanged:=entries;
         end;
      end;
      ini_free(tmpentry);
      Exit;
   end;
      entries:=entries^.next;
   end;
end;

function ini_readentry(ini_file : ini_files;section:str20;s:string):Pini_entry;
var
   entries  : Pini_entry;
   ls     : byte absolute s;
   i      : integer;
   key      : string;
begin
   ini_readentry:=NIL;
   Trim(s);
   if (ls=0) then Exit;
   i:=Pos('=',s); if i=0 then Exit;
   key:=Copy(s,1,i-1);
   Trim(key);
   Upper(key);
   Delete(s,1,i);
   LTrim(s);
   i:=Pos('#',s);
   if i<>0 then begin
      ls := i-1;
      Trim(s);
   end;   
   entries:=ini_entries;
   while (entries^.next<>NIL) do begin
			if (entries^.ini_file=ini_file_vpahelp) then begin
				if (section=entries^.section) then begin 
					entries^.name := key; entries^.text:=key; 
					ini_readentry:=entries;
					exit;
				end;
			end else if (entries^.ini_file=ini_file) and
			            (section=entries^.section) and (key=entries^.name) then begin
				if ini_getvalue(entries,s) then begin
					ini_readentry:=entries;
				end;
				Exit;
			end;
			entries:=entries^.next;
   end;  
end;

procedure ini_save(ini_file : ini_files);
var
   inname,bakname   : string;
   infile,tmpfile,bakfile : text;
   save       : boolean;
   section,s20      : str20;
   hasinput     : boolean;
   s,s1       : string;
   entries      : Pini_entry;
begin
   { todo: save to a tmp-file and rename this file when finished
     at the moment this function writes the config to the screen for debugging

     -keep spaces and comments in the same line as changed keys
    }
   
  case ini_file of
    ini_file_vpa  : begin
      inname:=addir+'VPA.INI';
      bakname:=addir+'VPA.BAK';
      Assign(infile,inname);
      Assign(tmpfile,addir+'VPA.TMP');
      Assign(bakfile,bakname);
(*    save:=false;		Why this? Quapla *)
      save:=true;
      end;
    ini_file_cmistakes  : begin
      inname:=addir+'VPACM'+plstr+'.INI';
      bakname:=addir+'VPACM'+plstr+'.BAK';
      Assign(infile,inname);
      Assign(tmpfile,addir+'VPACM'+plstr+'.TMP');
      Assign(bakfile,bakname);
      save:=true;
      end;
    ini_file_addon  : begin
      inname:=addir+'VPAADDON.INI';
      bakname:=addir+'VPAADDON.BAK';
      Assign(infile,inname);
      Assign(tmpfile,addir+'VPAADDON.TMP');
      Assign(bakfile,bakname);
      save:=true;
      end;
    ini_file_vpahelp  : begin
      inname:='VPAHELP.INI';
      bakname:='VPAHELP.BAK';
      Assign(infile,inname);
      Assign(tmpfile,'VPAHELP.TMP');
      Assign(bakfile,bakname);
      save:=true;
      end;

    else Exit;
   end;
   ini_resetstate(ini_file);
   reset(infile);
   if IOResult=0 then hasinput:=True else hasinput:=False;
   rewrite(tmpfile);
   section:='';
   while true do begin
      if (hasinput) and (eof(infile)) then begin
        close(infile);
        hasinput:=False;
      end;
      if (hasinput) then begin
        readln(infile,s);
        s20:=ini_issection(ini_file,s);
        if (s20<>'') then begin
            if (section<>'') then begin
              entries:=ini_findmissing(ini_file,section);
              while (entries<>NIL) do begin
                writeln(tmpfile,entries^.text,' = ',ini_valuestr(entries));
                entries^.found:=True;
                entries:=ini_findmissing(ini_file,section);
              end;
            end;
            section:=s20;
            writeln(tmpfile,s);
            end else begin
            if (section<>'') then begin
              entries:=ini_checkchanged(ini_file,section,s);
            end else entries:=NIL;
            if entries<>NIL then begin
              writeln(tmpfile,entries^.text,' = ',ini_valuestr(entries));
              entries^.found:=True;
            end else
              writeln(tmpfile,s);
        end;
      end else begin
        if (section<>'') then begin
          entries:=ini_findmissing(ini_file,section);
          while (entries<>NIL) do begin
            writeln(tmpfile,entries^.text,' = ',ini_valuestr(entries));
            entries^.found:=True;
            entries:=ini_findmissing(ini_file,section);
          end;
        end;
        entries:=ini_findmissing(ini_file,'');
        if entries=NIL then
          break;
        section:=entries^.section;
        writeln(tmpfile,'[',section,']');
        end;
      end;
      if hasinput then close(infile);
      close(tmpfile);
      if save then begin
        erase(bakfile);
        rename(infile,bakname);
        rename(tmpfile,inname);
      end else begin
        Writeln('Saving not implemented yet - Press Enter to continue');
        readln(s);
   end;
end; { ini_save }

function GetIniFile(ini_file : ini_files):string;
begin
	GetIniFile:='';
	case ini_file of   ini_file_vpa  : GetIniFile:='VPA.INI';
										 ini_file_cmistakes : GetIniFile:=addir+'VPACM'+plstr+'.INI';
										 ini_file_addon  : GetIniFile:=addir+'VPAADDON.INI';
										 ini_file_vpahelp  : GetIniFile:='VPAHELP.INI';
	end;
end;									 

procedure ini_read(ini_file : ini_files);
var
   infile      : text;
   s         : string;
   s20,section : str20;
begin
   s:=GetIniFile(ini_file);
	 if (s='') then exit;
   Assign(infile,s);
   reset(infile);
   if IOResult<>0 then Exit;
   section:='';
   while (not eof(infile)) do begin
      readln(infile,s);
      s20:=ini_issection(ini_file,s);
      if (s20<>'') then begin
				section:=s20;
      end else begin
				ini_readentry(ini_file,section,s);
      end;
   end;
   close(infile);
end; { ini_read }

procedure Check_VPAHelp;
var sr	: SearchRec;
    entries : Pini_entry;
		found : boolean;
begin
   entries:=ini_entries;
   while (entries^.next<>NIL) do begin
      if (entries^.ini_file=ini_file_vpahelp) then 
      with entries^ do begin
				FindFirst(name,$21,sr);
				if (DosError=0) and (sr.size>0) then found:=true else found:=false;
				case size of
					ini_size_bool    : EBool^:=found;
					ini_size_boolinv : EBoolinv^:=not found;
				end; { case } 
				{write(text,' (',name,') ');
				if not found then write('not ');
				writeln('found...');}
      end;
      entries:=entries^.next;
   end;
	 ini_save(ini_file_vpahelp);
end; { ini_Check }
	 
procedure ini_resetstate(ini_file : ini_files);
var entries : Pini_entry;
begin
   entries:=ini_entries;
   while (entries^.next<>NIL) do begin
      if (entries^.ini_file=ini_file) then begin
        entries^.found:=False;
      end;
      entries:=entries^.next;
   end;
end; { ini_resetstate }

procedure ini_initialize;
begin
   New(ini_entries);
   ini_entries^.next:=NIL;
   ini_init_vpa;
   ini_init_cmistakes;
   ini_init_addon;
	 ini_init_help;
end; { ini_initialize }

end.