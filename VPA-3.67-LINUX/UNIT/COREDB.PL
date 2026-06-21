#!/usr/bin/perl -w
#
#  DPMI for Turbo Pascal -- Core dump debugger
#
#  This program can be used to inspect core dumps written by
#  `DPMIDumpCore'. In order to make any use of it, you need to
#  generate a .MAP file when compiling your program:
#     tpc yourprog /gp
#  Then, when you have a core file, invoke this program
#     perl coredb.pl corefile yourprog.map
#  where corefile is the name of the core dump. It will take a
#  while to load the core dump, and then prompt you with `$'.
#
#  You can now enter commands. To get detailed descriptions of
#  commands, search for `COMMAND:' below.
#
#  The most important command when you debug a crash is probably
#  `bt'; it will display a backtrace (function call stack), similar
#  to what you get with Ctrl-F3 in Turbo Pascal. In addition, you
#  can use the `x' command to inspect variables, and `d' to get
#  raw memory dumps. `q' quits.
#
#  You can only inspect data; code segments are not (yet) available
#  in this debugger (they are not contained in the core dump). Use
#  only protected mode addresses. If there are multiple addresses
#  for one item (code and data), both should work equally well.
#
#  Commands can be abbreviated to the shortest unique prefix.
#
#  I use this with Perl 5.005_03 for dos-djgpp, simply because that
#  makes handling large data sets very easy...
#
#########################################################################
#
#  Format of core dumps: a core dump consists of a sequence of
#  blocks of the following format:
#   +0  4 bytes   type
#   +4  4 bytes   length of block
#   +8  n bytes   data
#
#  The following types are currently defined:
#   'SEGM': define segment numbers and other variables, should be first
#           entry. The data contains a sequence of WORDs:
#              ss (stack segment, protected)
#              sp (stack pointer)
#              bp (frame pointer)
#              ds (data segment, protected)
#              PrefixSeg (protected)
#              real-mode code segment of DPMI kernel
#              real-mode data segment
#              real-mode stack segment
#              real-mode load address (= real-mode PrefixSeg+16)
#              nseg (number of segments in program)
#              real_seg[nseg] (absolute real-mode segment numbers)
#              prot_seg[nseg] (corresponding protected mode code selectors)
#              prot_dseg[nseg] (corresponding pm data selectors)
#   'OVRS': one word with a real-mode segment number, plus the complete
#           overlay stub at that address (including the procedure pointers).
#           The segment number is absolute.
#   'DATA': one word with a protected-mode selector, plus the complete
#           segment (usually 64k). This is used to store the data segment,
#           the stack, the PSP, and the heap.
#   'SWAP': used to store the contents of a swap file. Not used by D4TP
#           itself, but PCC needs it.
#

print STDERR "DPMI for Turbo Pascal -- Core Dump Debugger -- (c) 2001 Stefan Reuther\n";

if($#ARGV < 0) {
    print STDERR "usage: $0 corefile [mapfile]";
    exit 1;
}

my $core = shift @ARGV;
my $map = shift @ARGV;

$swap = 0;                # will be image of swap file
%data = ();               # data segments; indexed by protected mode segment number
%over_stub_to_code = ();  # code selector from stub segment
%over_code_to_stub = ();  # stub segment from code selector

%command_map = (
    "?"            => \&cm_help,
    "q"            => \&cm_quit,
    "bt"           => \&cm_backtrace,
    "w"            => \&cm_backtrace,
    "d"            => \&cm_dump,
    "sym"          => \&cm_sym,
    "glob"         => \&cm_glob,
    "status"       => \&cm_status,
    "seg"          => \&cm_seg,
    "name"         => \&cm_name,
    "load"         => \&cm_load,
    "info"         => \&cm_info,
    "find"         => \&cm_find,
    "x"            => \&cm_examine,
    "heap"         => \&cm_heap
);
$help = '  ?              Help
  bt [n]         Print backtrace [of max length n]
  d s:o [l]      Dump memory
  sym a b c      Look up symbols a b c
  glob a*        Glob symbols
  status         Show program status
  seg a b c      Look up segment
  x/mode sym     Examine variable
  name s:o       Get name for symbol
  load module    Load a module
  find[/i] t [s [l]] Find t [in symbol s [length l]] [case insensitive]
  info           Information on debugger status
  heap           Show information about heap
  q              Quit
';

&read_core ($core);
&read_map ($map) if defined $map;

my $val = &get_sym_val ("_ERROR_SP", 2);
$ex_sp = defined $val ? unpack "v", $val: $sptr;
$val = &get_sym_val ("_ERROR_SS", 2);
$ex_ss = defined $val ? unpack "v", $val: $sseg;
$val = &get_sym_val ("_ERROR_IP", 2);
$ex_ip = defined $val ? unpack "v", $val: 0;
$val = &get_sym_val ("_ERROR_CS", 2);
$ex_cs = defined $val ? unpack "v", $val: 0;

&cm_status();
while(1) {
    print STDERR '$ ';
    my $command = <>;
    exit 0 if !defined $command;
    chomp $command;
    my @command = split /\s+/, $command;
    next if $#command < 0;
    my $verb = shift @command;
    if($verb =~ s,(/.*)$,,) {           # `x/w name'
        unshift @command, $1;
    }
    my @verbs = grep /^\Q$verb/, keys %command_map;
    if($#verbs < 0) {
        print STDERR "unknown command `$verb'\n";
        next;
    }
    if($#verbs > 0) {
        print STDERR "ambiguous: can be `", (join "', `", @verbs), "'\n";
        next;
    }
    $verb = $verbs[0];

    &{$command_map{$verb}} (@command);
}

#########################################################################

#
#  COMMAND: bt, w -- get backtrace
#
#  This command will show a backtrace of your program. This will consist
#  of lines of the form
#    0907:5833 (3cb4)  PDATA::BUILD +07a6
#  where 0907:5833 is the protected mode address, 3cb4 is the address of
#  the stack frame (use this as a rough guide where local variables are),
#  PDATA is the module name, and BUILD is the nearest public symbol.
#  +07a6 means the offset from that symbol.
#
#  When this command is used with a numeric argument, the backtrace
#  will be limited to that many lines (`bt 10').
#
#  This command can also be used as `bt/seg:ofs', and will then start the
#  backtrace from there. `bt/x' will start at the `Exception SS:SP'
#  reported by `status', but that is usually worthless. When a backtrace
#  was truncated, it can be continued by using the value `(sseg = ...)'
#  shown in the topmost line for seg, and the last displayed frame
#  address for ofs.
#
sub cm_backtrace {
    # Print backtrace
    # Stack layout is
    #            parent_cp
    #            parent_ip
    #   ss:bp -> parent_bp

    my ($ss, $bp) = ($sseg, $bptr);
    my $n = shift || -1;
    if($n =~ m,^/,) {
        if($n eq '/x') {
            $ss = $ex_ss;
            $bp = $ex_sp;
        } elsif($n =~ m,^/([0-9a-f]+):([0-9a-f]+)$,i) {
            $ss = hex $1;
            $bp = hex $2;
        } else {
            print STDERR "invalid argument `$n' to backtrace command\n";
            return;
        }
        $n = shift || -1;
    }
    printf "segm:offs (fram)  name    (sseg = %04x)\n", $ss;
    print  "--------- ------  --------------\n";
    while($bp != 0) {
        my $frame = &get_memory ($ss, $bp, 6);
        my ($parent_bp, $ip, $cs) = unpack "v3", $frame;
        printf "%04x:%04x (%04x)  %s\n", $cs, $ip, $parent_bp, (&get_sym_name ($cs, $ip));
        $bp = $parent_bp;
        last if !--$n;
    }
}

#
#  COMMAND: h -- Help
#
#  Shows a brief description of all commands
#
sub cm_help {
    print "
D4TP Core Dump Debugger

$help
";
}

#
#  COMMAND: q -- quit
#
#  Exit the core debugger.
#
sub cm_quit {
    exit 0;
}

#
#  COMMAND: d -- dump memory
#
#  Syntax: d seg:ofs len
#
#  Shows a hex-dump of the specified location. seg:ofs is a protected
#  mode address specified in hex. len is the length of the block to dump;
#  if omitted, defaults to 256 (16 lines).
#
#  To inspect a symbol, find out its address with `sym' first, or use
#  the `x' command.
#
sub cm_dump {
    my $addr = shift;
    my $length = shift || 0x100;
    return if ! $length;

    if($addr !~ /^([0-9a-f]+):([0-9a-f]+)$/) {
        print STDERR "malformed address `$addr'\n";
        return;
    }

    my $seg = hex $1;
    my $ofs = hex $2;
    my $data = &get_memory ($seg, $ofs, $length);
    my @chars = split //, $data;
    while($#chars >= 0) {
        my $line = "";
        printf "%04x:%04x ", $seg, $ofs;
        foreach(0..15) {
            if($#chars >= 0) {
                my $c = shift @chars;
                printf " %02x", ord $c;
                $line .= ((ord $c) >= 32 && (ord $c) < 127) ? $c : ".";
            } else {
                print "   ";
            }
            print " " if $_ eq 7;
            print " " if $_ eq 3 || $_ eq 11;
        }
        print "  $line\n";
        $ofs += 16;
    }
}

#
#  COMMAND: name -- Get name for address
#
#  Usage: name seg:offs
#
#  Attempt to name the specified addresses
#
sub cm_name {
    foreach (@_) {
        if(/^([0-9a-f]+):([0-9a-f]+)$/i) {
            $seg = hex $1;
            $ofs = hex $2;
            print "$_: ", (&get_sym_name ($seg, $ofs)), "\n";
        } else {
            print "$_: invalid address\n";
        }
    }
}

#
#  COMMAND: sym -- Look up symbol
#
#  Usage: sym symbol1 symbol2 ...
#
#  Finds out the address of the symbols. For each symbol, prints a line
#  like this:
#    ExitCode: 42af:8f7c real  01df:8f7c code  01df:8f7c data
#    Build: 1b5c:508d real  0357:508d code  035f:508d code
#  `real' is the real mode address which is of no real use in this
#  debugger. `code' is, for procedures, the address of the procedure
#  with a code selector. `data' is the address with a data selector.
#  `ExitCode' is a variable, so code and data selector are the same.
#  `Build' is a procedure, so it has a code selector (which is used
#  when calling the procedure), and a data selector (which could be
#  used by self-modifying code, and which is used by the protected mode
#  loader). Note that the offset relative to the segment and to the
#  selectors is the same.
#
sub cm_sym {
    foreach (@_) {
        my $s = uc;
        if(!defined $sym_seg{$s}) {
            print "$_: unknown\n";
        } else {
            printf "%s: %04x:%04x real", $_, $sym_seg{$s}, $sym_ofs{$s};
            printf "  %04x:%04x code", $real_to_code{$sym_seg{$s}}, $sym_ofs{$s}
                if defined $real_to_code{$sym_seg{$s}};
            printf "  %04x:%04x data", $real_to_data{$sym_seg{$s}}, $sym_ofs{$s}
                if defined $real_to_data{$sym_seg{$s}};
            print "\n";
        }
    }
}

#
#  COMMAND: info -- show information on debugger status
#
sub cm_info {
    foreach (sort keys %data) {
        my $name = &get_sym_name ($_, 0);
        $name =~ s/(::| \+).*//;
        printf "selector %04x (limit = %d)  %s\n",
            $_, length $data{$_}, $name;
    }
}

#
#  COMMAND: glob -- look for symbols
#
#  Can be used when you don't recall the exact spelling of a symbol.
#  `glob foo*' returns all symbols which start with `foo'. You can
#  use Unix shell wildcards here (in a nutshell: same as DOS wildcards,
#  except that `*' and `?' can stand anywhere: `*foo*' matches anything
#  with a foo inside).
#
sub cm_glob {
    foreach (@_) {
        my $re = $_;
        $re =~ s/\./\\./g;
        $re =~ s/\*/.*/g;
        my @match = grep { /^$re$/i } keys %sym_ofs;
        print "$_: no matches\n" if $#match < 0;
        print "$_: ", (join " ", @match), "\n" if $#match >= 0;
    }
}

#
#  COMMAND: status -- show status
#
#  Shows important segment/selector numbers as they were when the dump
#  was written, including the error address and code.
#
#  Note that the `Exception DS' values are only valid when the program
#  actually died with an exception (#00, #gp, #sf).
#
sub cm_status {
    printf "Program State at Death:\n";
    printf "  Stack at:       %04x:%04x (%04x real)\n", $sseg, $sptr, $real_ss;
    printf "  Current frame:  %04x\n", $bptr;
    printf "  Data at:        %04x (%04x real)\n", $dseg, $real_ds;
    printf "  PSP at:         %04x (%04x real)\n", $prefixseg, $real_seg0-0x10;
    printf "  DPMI unit at:   %04x real\n", $real_cs;
    printf "  Segments:       %d\n", $nseg;

    my $adr = &get_sym_val ('ERRORADDR', 4);
    my $sig = &get_sym_val ('EXITCODE', 2);
    if(defined $adr) {
        my ($o, $s) = unpack "vv", $adr;
        $s += $prefixseg+16;
        printf "  Error address:  %04x:%04x  (%s)\n", $s, $o, &get_sym_name ($s, $o);
    }
    printf "  Exit code:      %d\n", unpack "v", $sig
        if defined $sig;

    my $first = 1;
    foreach ('DS', 'ES', 'SS', 'SP', 'CS', 'IP') {
        my $val = &get_sym_val ("_ERROR_$_", 2);
        if(defined $val) {
            print "  Exception regs: " if $first;
            print ", " if !$first;
            printf "$_=%04x", unpack "v", $val;
            $first = 0;
        }
    }
    print "\n    (valid only if exception caused core dump)\n" if !$first;
    printf "  Exception addr: %04x:%04x  (%s)\n", $ex_cs, $ex_ip, &get_sym_name ($ex_cs, $ex_ip)
        if ($ex_cs);
}

#
#  COMMAND: find -- Find information in image
#
#  Usage: find string [seg:ofs [len]]
#
#  Searches for a (printable) string in the image. Use when you don't
#  have a map file and don't know the version.
#
sub cm_find {
    my $pat = shift;
    my $foldcase = 0;
    if($pat eq '/i') {
        $pat = shift;
        $foldcase = 1;
    }
    if(! defined $pat) {
        print "No search string specified.\n";
        return;
    }
    my $adr = shift;
    if(defined $adr) {
        my $len = shift || 65536;
        my $data = &get_sym_val ($adr, $len);
        if(!defined $data) {
            print "$adr: unknown\n";
        } else {
            &cm_find_help ($pat, $data, "$adr +", $foldcase);
        }
    } else {
        foreach (sort keys %data) {
            &cm_find_help ($pat, $data{$_}, (sprintf "%04x:", $_), $foldcase);
        }
    }
}

sub cm_find_help {
    my ($pat, $data, $pre, $foldcase) = @_;
    my $index = 0;
    my $next;

    if($foldcase) {
        $data = uc $data;
        $pat = uc $pat;
    }

    while (($next = index $data, $pat, $index) >= $index) {
        # found a match. Get max length.
        my $beg = $next;
        my $end = $next;
        while($beg > 0) {
            my $c = ord substr $data, $beg-1, 1;
            last if ($c < 32 || $c >= 127);
            $beg--;
        }
        while($end < length $data) {
            my $c = ord substr $data, $end, 1;
            last if ($c < 32 || $c >= 127);
            $end++;
        }
        printf "%s%04x  %s\n", $pre, $beg, substr $data, $beg, $end-$beg;

        $index = 1 + $end;
    }
}

#
#  COMMAND: heap -- Get information on heap
#
#  Usage: heap
#
#  Shows information on the heap (MemAvail, MaxAvail), including the
#  selectors of all heap segments. The heap is also checked for
#  consistency.
#
sub cm_heap {
    my $heapseg = &get_sym_val("HEAP_SEG", 2);
    if(!defined $heapseg) {
        print "Can't get heap address.\n";
        return;
    }
    $heapseg = unpack "v", $heapseg;
    my @heapsegs = ();
    my $maxavail = 0;
    my $memavail = 0;

    print "Heap status:\n";
    while($heapseg != 0) {
        # okay, a heap segment
        push @heapsegs, $heapseg;

        # walk the heap chain
        my $heapofs = unpack "v", &get_memory ($heapseg, 2, 2);
        while($heapofs) {
            my ($size, $next) = unpack "vv", &get_memory($heapseg, $heapofs, 4);
            $memavail += $size;
            $maxavail = $size if $size > $maxavail;
            if($size < 0 || ($next != 0 && $next < $heapofs + $size)) {
                printf "  Warning: arena damaged: bad free node at %04x:%04x\n",
                    $heapseg, $heapofs;
            }
            $heapofs = $next;
        }
        $heapseg = unpack "v", &get_memory($heapseg, 0, 2);
        if(grep { $_ == $heapseg } @heapsegs) {
            printf "  Warning: arena damaged: circular segment list at %04x:0000\n",
                $heapseg;
            last;
        }
    }

    my $n = $#heapsegs + 1;
    my $nbu = &get_sym_val ("DPMIBLOCKSUSED", 2);

    print "  Maxavail:         $maxavail\n";
    print "  Memavail:         $memavail\n";
    print "  Number of blocks: $n (", 64*$n, " k)\n";
    if (defined $nbu) {
        $nbu = unpack "v", $nbu if defined $nbu;
        print "  Warning: DPMIBlocksUsed is $nbu\n" if $nbu != $n;
    } else {
        print "  Warning: DPMIBlocksUsed can't be accessed\n";
    }
    print "  Heap segments:   ";
    foreach(@heapsegs) {
        printf " %04x", $_;
    }
    print "\n";
}

#
#  COMMAND: seg -- Information on a segment
#
#  Usage: seg SEGMENTNAME SEGMENTNAME
#
#  Shows the addresses of a segment. Displays something like this:
#    PDATA  : 1b5c real  0357 code  035f data  (overlay code at 0907)
#    STACK  : 51f8 real  01d7 code  01d7 data
#    CC     : 1581 real  01f7 code  01ff data
#  `real' is the real mode segment number, `code' is a code selector,
#  `data' is a data selector. In the above example, PDATA is a module
#  from an overlay, the displaid values are the addresses of the stub
#  ("procedure linkage table"); the actual code is at 0907. Oddly enough,
#  the `sym' command will report the address of procedures to be
#  relative to 0357 (that's what Turbo Pascal writes to the map file).
#  Resolving addresses in a backtrace will work correctly, though.
#  Other pecularities: the STACK segment is a data segment, so its code
#  selector is the same as the data selector. CC finally is a "normal"
#  code segment.
#
sub cm_seg {
   SEGMENT:
    foreach (@_) {
        my $sn = uc;
        foreach (keys %seg_name) {
            if($sn eq $seg_name{$_}) {
                printf "%-10s: %04x real", $sn, $_;
                printf "  %04x code", $real_to_code{$_}
                    if defined $real_to_code{$_};
                printf "  %04x data", $real_to_data{$_}
                    if defined $real_to_data{$_};
                printf "  (overlay code at %04x)", $over_stub_to_code{$_}
                    if defined $over_stub_to_code{$_};
                print "\n";
                next SEGMENT;
            }
        }
        printf "%-10s: not known\n", $sn;
    }
}

#
#  COMMAND: x -- Examine variable
#
#  Usage: x/4m name name
#
#  The /4m construction specifies the type of the variable you want to
#  inspect. 4 is the number of items to display, m is the type code:
#  + l -- LONGINT
#  + b -- SHORTINT
#  + p -- POINTER
#  + s -- STRING (count is ignored here)
#  + c -- CHAR
#  + w -- INTEGER (this is the default if the `/4m' construct is omitted)
#
#  The names are either symbol names or addresses in the form `seg:ofs'.
#  Example: `x/p erroraddr' yields `erroraddr: 4e54:00e0'.
#
sub cm_examine {
    return if $#_ < 0;
    my $mode = shift;
    my $typ = 'w';
    my $count = 1;
    if($mode =~ m,^/(.*),) {
        if($mode !~ m,^/([0-9]*)([a-z])$,) {
            print STDERR "invalid mode: `$mode' in `x' command\n";
            return;
        }
        $typ = $2;
        $count = $1 if $1 ne '';
    } else {
        unshift @_, $mode;
    }

    if($typ eq 'l') {
        # long
        foreach (@_) {
            my $val = &get_sym_val (uc, 4*$count);
            if(defined $val) {
                my @val = unpack "V$count", $val;
                print "$_: ", (join ", ", @val), "\n";
            } else {
                print "$_: unknown\n";
            }
        }
    } elsif($typ eq 'b') {
        # byte
        foreach (@_) {
            my $val = &get_sym_val (uc, $count);
            if(defined $val) {
                my @val = unpack "c$count", $val;
                print "$_: ", (join ", ", @val), "\n";
            } else {
                print "$_: unknown\n";
            }
        }
    } elsif($typ eq 'p') {
        # pointer
        foreach (@_) {
            my $val = &get_sym_val (uc, 4*$count);
            if(defined $val) {
                my @val = unpack "V$count", $val;
                print "$_: ", (join ", ", map { sprintf "%04x:%04x", $_ >> 16, $_ & 0xFFFF } @val), "\n";
            } else {
                print "$_: unknown\n";
            }
        }
    } elsif($typ eq 's') {
        # string
        foreach (@_) {
            my $val = &get_sym_val (uc, 255);
            if(defined $val) {
                my $len = ord substr $val, 0, 1;
                print "$_: '", (substr $val, 1, $len), "'\n";
            } else {
                print "$_: unknown\n";
            }
        }
    } elsif($typ eq 'c') {
        # char array
        foreach (@_) {
            my $val = &get_sym_val (uc, $count);
            if(defined $val) {
                my $sep = ' ';
                print "$_:";
                foreach (split //, $val) {
                    if(ord >= 32 && ord != 127) {
                        print "$sep'$_'";
                        print "'" if $_ eq "'";
                    } else {
                        print "$sep#", ord;
                    }
                    $sep = ', ';
                }
                print "\n";
            } else {
                print "$_: unknown\n";
            }
        }
    } else {
        print "invalid type code `$typ' in `x' command, assuming `w'\n"
            if $typ ne 'w';
        foreach (@_) {
            my $val = &get_sym_val (uc, 2*$count);
            if(defined $val) {
                my @val = unpack "v$count", $val;
                print "$_: ", (join ", ", @val), "\n";
            } else {
                print "$_: unknown\n";
            }
        }
    }
}

#
#  COMMAND: load -- Load module
#
#  Usage: load modulename [args]
#
#  Load another debugger module (Perl program). This makes available
#  more commands, etc.
#
#  This simply executes the specified file with extension `.dm' and
#  @ARGV set to the arguments specified with `load'. The module can
#  contain any code: it can make available commands by adding them
#  to %command_map (`$command_map{'my_command'} = \&my_command;') and
#  to $help. Good things for these commands to do is parsing data
#  structures of your program by calling `&get_sym_val' and formatting
#  the results.
#
sub cm_load {
    my $mod = shift;
    if(!defined $mod) {
        print STDERR "usage: load modulename\n";
    } else {
        local @ARGV = @_;
        $mod .= ".dm" if $mod =~ m,/[^.]+$, || $mod =~ m,^[^.]+$,;
        do "$mod" or print STDERR "unable to load `$mod'\n";
    }
}

### Access ##############################################################

# &get_sym_val ("name", leng)
#   Returns data block of length leng corresponding to the specified
#   symbol. Returns undef if symbol not known.
sub get_sym_val {
    my ($name, $len) = @_;
    my ($seg, $ofs);

    $name = uc $name;
    if($name =~ /^([0-9a-f]+):([0-9a-f]+)$/i) {
        $seg = hex $1;
        $ofs = hex $2;
    } else {
        if(!defined $sym_ofs{$name}) {
            return undef;
        }
        if(!defined $real_to_data{$sym_seg{$name}}) {
            print STDERR "No selector known for `$name'\n";
            return undef;
        }
        $seg = $real_to_data{$sym_seg{$name}};
        $ofs = $sym_ofs{$name};
    }

    return &get_memory ($seg, $ofs, $len);
}

# &get_memory (selector, offset, length)
#   return data block.
#   FIXME: handling for invalid addresses could be better
sub get_memory {
    my ($sel_ori, $ofs, $len) = @_;
    my $sel = $sel_ori;
    if ($sel == 0) {
        print STDERR "Null pointer dereference\n";
        return "\0" x $len;
    }
    if(! defined $data{$sel}) {
        if (defined $code_to_data{$sel}) {
            $sel = $code_to_data{$sel};
        } elsif (defined $data_to_code{$sel}) {
            $sel = $data_to_code{$sel};
        }
    }
    if(! defined $data{$sel}) {
        printf STDERR "Referencing unknown address %04x:%04x\n", $sel_ori, $ofs;
        return "\0" x $len;
    } elsif($ofs >= length $data{$sel}) {
        printf STDERR "Offset %04x exceeds segment limit (%04x)\n", $ofs, length $data{$sel};
        return "\0" x $len;
    } else {
        return substr $data{$sel}, $ofs, $len;
    }
}

# &get_sym_name ($seg, $ofs)
#   Return user-readable description of that memory location
sub get_sym_name {
    my ($seg, $ofs) = @_;
    my $x = undef;
    if(defined $code_to_real{$seg}) {
        $x = $code_to_real{$seg};
    } elsif(defined $data_to_real{$seg}) {
        $x = $data_to_real{$seg};
    } elsif(defined $over_code_to_stub{$seg}) {
        $x = $over_code_to_stub{$seg};
    } else {
        return "<unknown>";
    }

    my $seg_name = (sprintf "<unknown-%04x>", $x);
    if(defined $seg_name{$x}) {
        $seg_name = $seg_name{$x};
    }

    my $sym = sprintf " +%04x", $ofs;
    if(defined $addr_sym{$x}) {
        my $symofs = -1;
        foreach (sort { $a <=> $b} keys %{$addr_sym{$x}}) {
            last if $_ > $ofs;
            $symofs = $_;
        }
        if($symofs >= 0) {
            $sym = "::$addr_sym{$x}{$symofs}" . (sprintf " +%04x", $ofs - $symofs);
        }
    }

    return $seg_name . $sym;
}

### Loading #############################################################

# &read_core ("file")
#   Load the core file into memory, set all important variables, etc.
sub read_core {
    my $core = shift;
    my $had_segm = 0;
    open CORE, "< $core" or die "can't open $core: $!";
    binmode CORE;
    while(read CORE, $head, 8) {
        my ($id, $len) = unpack "A4V", $head;
        read CORE, $data, $len;
        if($id ne 'SEGM' && !$had_segm) {
            print STDERR "error: no `SEGM' header in core file\n";
            exit 1;
        }
        if($id eq 'SEGM') {
            ($sseg, $sptr, $bptr, $dseg, $prefixseg,
             $real_cs, $real_ds, $real_ss, $real_seg0,
             $nseg) = unpack "v10", substr $data, 0, 20;

            my (@real) = unpack "v$nseg", substr $data, 20, 2*$nseg;
            my (@protc) = unpack "v$nseg", substr $data, 20+2*$nseg, 2*$nseg;
            my (@protd) = unpack "v$nseg", substr $data, 20+4*$nseg, 2*$nseg;

            foreach (0..$#real) {
                $real_to_code{$real[$_]} = $protc[$_];
                $real_to_data{$real[$_]} = $protd[$_];
                $data_to_real{$protd[$_]} = $real[$_];
                $code_to_real{$protc[$_]} = $real[$_];
                $code_to_data{$protc[$_]} = $protd[$_];
                $data_to_code{$protd[$_]} = $protc[$_];
            }
            $had_segm = 1;
        } elsif($id eq 'OVRS') {
            my ($seg, $ignore, $sel) = unpack "vA35v", $data;
            # $seg = overlay segment with stub (as shown in map file)
            # $sel = actual segment with code
            printf "warning: no code selector allocated for overlay header %04x\n", $seg
                unless defined $real_to_code{$seg};
            $over_stub_to_code{$seg} = $sel;
            $over_code_to_stub{$sel} = $seg;
        } elsif($id eq 'DATA') {
            my $id = unpack "v", substr $data, 0, 2;
            $data{$id} = substr $data, 2;
        } elsif($id eq 'SWAP') {
            $swap = $data;
        } else {
            print STDERR "warning: skipping unknown block `$id' ($len bytes)\n";
        }
    }
    if(!$had_segm) {
        print STDERR "error: no `SEGM' header in core file\n";
        exit 1;
    }
    close CORE;
}

# &read_map ("file.map")
#   Load a map file (symbols)
sub read_map {
    my $map = shift;
    open MAP, "< $map" or die "can't open $map: $!";
    while(<MAP>) {
        s/[\n\r]+$//;
        $_ = uc $_;

        if(/^ ([0-9A-F]{4})0H [0-9A-F]{5}H [0-9A-F]{5}H (\w+)/) {
            # segment definition
            my $seg = (hex $1) + $real_seg0;
            my $name = $2;
            $seg_name{$seg} = $name;
            printf "warning: no pm selector allocated for segment %04x (%s)\n", $seg, $name
                if ! defined $real_to_code{$seg} && $name ne 'HEAP';
        } elsif(/^ ([0-9A-F]{4}):([0-9A-F]{4})\s+(\S+)/) {
            my $seg = (hex $1) + $real_seg0;
            my $ofs = hex $2;
            $sym_seg{$3} = $seg;
            $sym_ofs{$3} = $ofs;
            $addr_sym{$seg}{$ofs} = $3;
            printf "warning: no segment name known for symbol %s (segment %04x)\n", $3, $seg
                if ! defined $seg_name{$seg};
        }
    }
    close MAP;
}
