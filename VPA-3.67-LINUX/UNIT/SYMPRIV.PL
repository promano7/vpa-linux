#!/usr/bin/perl
#
#  Convert MAP file with line numbers to file with private symbols instead
#
#  Usage:
#      tpc file /gd
#      perl sympriv.pl [-k] [file.map [filesym.map]]
#
#  Turbo Pascal does not show "private" symbols in map files; private
#  is anything not declared in the INTERFACE part of a file. This script
#  uses the line number information to fill in the blanks. It reads
#  all source files, and if a line refers to the BEGIN of a procedure,
#  emits a symbol entry to the output file.
#
#  If the file names are not specified, they default to stdin and stdout,
#  respectively. The `-k' option causes all line number records not
#  translated by this script to be deleted (library code).
#

my $kill_lines = 0;
if($#ARGV >= 0 && $ARGV[0] eq '-k') {
    shift @ARGV;
    $kill_lines = 1;
}

open IN, "< " . shift @ARGV or open IN, "< -" or die "can't open input";
open OUT, "> " . shift @ARGV or open OUT, "> -" or die "can't create output";

my $reading = 0;
my $killing = 0;
my @file = ();
my $blank = 0;
while(<IN>) {
    if(/^Line numbers for \w+\((.*)\)/) {
        my $fn = $1;
        $fn =~ s,^\.\.[\\/],,;
        if(open FILE, "< $fn") {
            print STDERR "Reading $fn...\n";
            @file = <FILE>;
            close FILE;
            $reading = 1;
        } else {
            print STDERR "Skipping $fn.\n";
            $reading = 0;
            $killing = $kill_lines;
            print unless $killing;
        }
    } elsif($reading && /^[ 0-9A-F:]+$/) {
        while(s/^\s+(\d+)\s+([0-9A-F:]+)//) {
            my $line = $1;
            my $adr = $2;
            next if ($line < 0 || $line >= $#file);
            my $f = $file[$line - 1];
            if($f =~ /^\s*(PROCEDURE|FUNCTION|CONSTRUCTOR|DESTRUCTOR)\s+([A-Z0-9_.]+)/i) {
                # one-liner
                print OUT " $adr       $2\n";
                $blank = 0;
            } elsif($f =~ /^(BEGIN|ASM)\b/i) {
                # multi-liner
                while($line-- > 0) {
                    $f = $file[$line-1];
                    last if($f =~ /\b(BEGIN|ASM)\b/i);
                    if($f =~ /^(PROCEDURE|FUNCTION|CONSTRUCTOR|DESTRUCTOR)\s+([A-Z0-9_.]+)/i) {
                        print OUT " $adr       $2\n";
                        $blank = 0;
                        last;
                    }
                }
            }
        }
    } elsif(/^[ \t\r\n]*$/) {
        print OUT unless $blank || $killing;
        $blank = 1;
    } else {
        print OUT unless $killing && /^\s+\d+\s/;
        $blank = 0;
    }
}
close IN;
close OUT;
