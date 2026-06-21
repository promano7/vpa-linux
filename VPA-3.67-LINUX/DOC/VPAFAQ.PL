#!/who/cares/where/I/have/perl -w
#
#  This script will add some HTML tags to vpa.faq.
#
#  Usage: perl vpafaq.pl >vpafaq.html
#
#  This applies some heuristics for what is preformatted text and what
#  is a standard paragraph. Hence, keep standard paragraphs indented
#  three spaces.
#
#     -- Stefan Reuther
#

use strict;
use vars qw{$body $qlist $current $qnum};

my $INPUT = (shift @ARGV or "vpafaq.txt");

open IN, "< $INPUT" or die "$INPUT: $!\n";
while (<IN>) { last if /^----/ }        # skip header

while (<IN>) {
    chomp;
    if (/^-------/) {
        # divider line
        close_tag ();
        $body .= "<hr>\n";
    } elsif (/^\s*$/) {
        # paragraph boundary
        close_tag ();
    } elsif (/^[\*\-]\s+(.*)/) {
        # Subseacion heading
        my $rest = $1;
        close_tag ();
        open_tag ("h2");
        $body .= escape ($1, 0) . "\n";
    } elsif (/^Q:\s+(.*)/) {
        # A question. Read whole paragraph.
        my $para = $1;
        my $anchor = "Q" . ++$qnum;
        my $tmp;
        close_tag ();
        open_tag ("p", " class=\"q\"");
        while (chomp($tmp = <IN>), $tmp !~ /^\s*$/) {
            $para .= "\n$tmp";
        }
        $body .= "<a name=\"$anchor\"><b>Question:</b></a> " . escape($para, 0) . "\n";
        $qlist .= "   <li><a href=\"#$anchor\">" . escape($para, 0) . "</a></li>\n";
        close_tag ();
    } elsif (/^A:\s+(.*)/) {
        # Answer
        close_tag ();
        open_tag ("p");
        $body .= "<b>Answer:</b> " . escape($1, 1) . "\n";
    } elsif (/^\s\s\s\s/ || /\S\s\s/ || /^\s*\d+\)/ || /^\s*\([a-z]\)/) {
        # use preformatted text for
        #   - indented stuff
        #   - stuff with embedded spaces ("ASCII art")
        #   - "1)" lists
        #   - "(a)" lists
        open_tag ("pre");
        $body .= escape("$_\n", 1);
    } else {
        open_tag ("p");
        $body .= escape("$_\n", 1);
    }
}

print <<EOF;
<html>
 <head>
  <title>VPA FAQ</title>
  <style type="text/css">
   .q { font-size: 110%; font-style: italic; color: #400000; }
  </style>
 </head>
 <body>
  <h1>VGA Planets Assistant -- Frequently Asked Questions</h1>

  <ol>
$qlist
  </ol>
  <hr>

$body

  <address>This document has been generated automatically from the 
   plain-ASCII version.<br>
   Best viewed with Netscape Navigator 2.02 for Windows 3.1.
   <!-- sure, that's what I tested it with *veg* -->
  </address>
 </body>
</html>
EOF
exit 0;

sub open_tag {
    my $tag = shift;
    if (!defined $current || $current eq "") {
        $body .= "<$tag@_>";
    } elsif ($tag ne $current) {
        $body .= "</$current>\n<$tag@_>";
    }
    $current = $tag;
}

sub close_tag {
    if (defined $current && $current ne "") {
        $body .= "</$current>\n";
    }
    $current = "";
}

sub escape {
    my ($text, $urls) = @_;
    $text =~ s/\&/\&amp;/g;
    $text =~ s/</\&lt;/g;
    $text =~ s/>/\&gt;/g;
    $text =~ s/\"/\&quot;/g;
    if ($urls) {
        $text =~ s{((f|ht)tp://[a-z0-9.A-Z\-:/_]+)}{<a href="$1">$1</a>}g;
        $text =~ s{[a-z0-9.A-Z\-:/_]+@[a-z0-9.A-Z\-:/_]+}{<a href="mailto:$1">$1</a>}g;
    }
    # this one looks good for the file format list, but not for VPA:
    # $text =~ s{\b([A-Z0-9nx\.]{2,})\b}{$1 eq "VPA" ? $1 : "<tt>$1</tt>"}eg;
    $text;
}
