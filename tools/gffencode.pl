#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# gffencode.pl -- Simple program to encode BioWare Gff files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: gffencode.pl
#	  $Source: /u/samba/nwn/bin/RCS/gffencode.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 13:18 Nov 20 2004 kivinen
#	  Last Modification : 01:26 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:26:38 $
#	  Revision number   : $Revision: 1.7 $
#	  State             : $State: Exp $
#	  Version	    : 1.99
#	  Edit time	    : 51 min
#
#	  Description       : Simple program to encode BioWare Gff files
#
#	  $Log: gffencode.pl,v $
#	  Revision 1.7  2007/05/23 22:26:38  kivinen
#	  	No changes.
#
#	  Revision 1.6  2007/03/07 16:20:58  kivinen
#	  	Added removing dos line endings.
#
#	  Revision 1.5  2006/11/23 17:53:39  kivinen
#	  	Added support for encoding % encoded special chars.
#
#	  Revision 1.4  2005/06/20 18:53:58  kivinen
#	  	Added support for using TemplateResRef to get the file name.
#
#	  Revision 1.3  2005/02/14 23:31:49  kivinen
#	  	Fixed error.
#
#	  Revision 1.2  2005/02/05 17:50:30  kivinen
#	  	Added documentation.
#
#	  Revision 1.1  2004/11/21 14:27:31  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package GffEncode;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Gff;
use GffWrite;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::parse_filename = 0;
$Opt::separator = ":\t";

######################################################################
# Get version information

open(PROGRAM, "<$0") || die "Cannot open myself from $0 : $!";
undef $/;
$Prog::program = <PROGRAM>;
$/ = "\n";
close(PROGRAM);
if ($Prog::program =~ /\$revision:\s*([\d.]*)\s*\$/i) {
    $Prog::revision = $1;
} else {
    $Prog::revision = "?.?";
}

if ($Prog::program =~ /version\s*:\s*([\d.]*\.)*([\d]*)\s/mi) {
    $Prog::save_version = $2;
} else {
    $Prog::save_version = "??";
}

if ($Prog::program =~ /edit\s*time\s*:\s*([\d]*)\s*min\s*$/mi) {
    $Prog::edit_time = $1;
} else {
    $Prog::edit_time = "??";
}

$Prog::version = "$Prog::revision.$Prog::save_version.$Prog::edit_time";
$Prog::progname = $0;
$Prog::progname =~ s/^.*[\/\\]//g;

$| = 1;

######################################################################
# Read rc-file

if (defined($ENV{'HOME'})) {
    read_rc_file("$ENV{'HOME'}/.gffencoderc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"filenames|f" => \$Opt::parse_filename,
		"output|o=s" => \$Opt::output_filename,
		"separator|s=s" => \$Opt::separator,
		"version|V" => \$Opt::version) || defined($Opt::help)) {
    usage();
}

if (defined($Opt::version)) {
    print("\u$Prog::progname version $Prog::version by Tero Kivinen.\n");
    exit(0);
}

while (defined($Opt::config)) {
    my($tmp);
    $tmp = $Opt::config;
    undef $Opt::config;
    if (-f $tmp) {
	read_rc_file($tmp);
    } else {
	die "Config file $Opt::config not found: $!";
    }
}

######################################################################
# Main loop

$| = 1;

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv, $i);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

my($gff, $label, $value, $curr_label, $curr_value, %temp);

$gff = Gff->new();

$Opt::output_filename = "" if (!defined($Opt::output_filename));

while (<>) {
    chomp;
    s/\015$//g;
    if ($Opt::parse_filename) {
	if (s/^([0-9a-zA-Z_]+\.[a-zA-Z0-9]{3}): //) {
	    if ($1 ne $Opt::output_filename) {
		if ($Opt::output_filename ne "") {
		    if (defined($curr_label)) {
			$gff->value($curr_label, $curr_value);
			undef $curr_label;
			undef $curr_value;
		    }
		    if ($Opt::verbose > 5) {
			print("Printing new gff\n");
			$gff->print(print_types => 1,
				    separator => $Opt::separator);
		    }
		    print("Writing old file $Opt::output_filename out\n")
			if ($Opt::verbose);
		    &GffWrite::write($gff, filename => $Opt::output_filename);
		    $gff = Gff->new();
		}
		$Opt::output_filename = $1;
		print("New filename $Opt::output_filename\n")
		    if ($Opt::verbose);
	    }
	}
    }
    if (/^(\/[^$Opt::separator]*)$Opt::separator(.*)$/) {
	$label = $1;
	$value = $2;
	$value =~ s/\%([0-9a-fA-f][0-9a-fA-f])/pack("H*", $1)/ge;
	if ($label eq "/ ____file_type") {
	    $gff->file_type($value);
	} elsif ($label eq "/ ____file_version") {
	    $gff->file_version($value);
	} else {
	    if (defined($curr_label)) {
		$gff->value($curr_label, $curr_value);
	    }
	    $curr_label = $label;
	    $curr_value = $value;
	}
    } else {
	# Continuation line
	$curr_value .= "\n" . $_;
    }
}

if (defined($curr_label)) {
    $gff->value($curr_label, $curr_value);
}

if ($Opt::verbose > 5) {
    print("Printing new gff\n");
    $gff->print(print_types => 1,
		separator => $Opt::separator);
}

if ($Opt::output_filename eq "") {
    print("No name giving, using the one from TemplateResRef\n")
	if ($Opt::verbose);
    $Opt::output_filename =
	lc($gff->value('/TemplateResRef') . "." .
	   $gff->value(' ____file_type'));
}
print("Writing file $Opt::output_filename out\n")
    if ($Opt::verbose);
&GffWrite::write($gff, filename => $Opt::output_filename);

exit 0;

######################################################################
# Read rc file

sub read_rc_file {
    my($file) = @_;
    my($next, $space);
    
    if (open(RCFILE, "<$file")) {
	while (<RCFILE>) {
	    chomp;
	    while (/\\$/) {
		$space = 0;
		if (/\s+\\$/) {
		    $space = 1;
		}
		s/\s*\\$//g;
		$next = <RCFILE>;
		chomp $next;
		if ($next =~ s/^\s+//g) {
		    $space = 1;
		}
		if ($space) {
		    $_ .= " " . $next;
		} else {
		    $_ .= $next;
		}
	    }
	    if (/^\s*([a-zA-Z0-9_]+)\s*$/) {
		eval('$Opt::' . lc($1) . ' = 1;');
	    } elsif (/^\s*([a-zA-Z0-9_]+)\s*=\s*\"([^\"]*)\"\s*$/) {
		my($key, $value) = ($1, $2);
		$value =~ s/\\n/\n/g;
		$value =~ s/\\t/\t/g;
		eval('$Opt::' . lc($key) . ' = $value;');
	    } elsif (/^\s*([a-zA-Z0-9_]+)\s*=\s*(.*)\s*$/) {
		my($key, $value) = ($1, $2);
		$value =~ s/\\n/\n/g;
		$value =~ s/\\t/\t/g;
		eval('$Opt::' . lc($key) . ' = $value;');
	    }
	}
	close(RCFILE);
    }
}


######################################################################
# Usage

sub usage {
    Pod::Usage::pod2usage(0);
    exit(0);
}

=head1 NAME

gffencode - Encodes text version of gff back to binary gff

=head1 SYNOPSIS

gffencode [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--filenames>|B<-f>]
    [B<--separator>|B<-s> I<separator>]
    [B<--output>|B<-o> I<output_filename>]
    I<filename> ...

gffencode B<--help>

=head1 DESCRIPTION

B<gffencode> takes the output of gffprint(1) and converts it back to
the binary gff. The gffprint(1) output should be generated with B<-t>
option so that it has all the internal type information. If B<-f> is
given then it reads the output of gffprint(1) with B<-b> or B<-f>, and
uses the file names of the original gff file. This can be used to
change lot of files. If no output file is given then the TemplateResRef
of the file is used.

=head1 OPTIONS

=over 4

=item B<--help> B<-h>

Prints out the usage information.

=item B<--version> B<-V>

Prints out the version information. 

=item B<--verbose> B<-v>

Enables the verbose prints. This option can be given multiple times,
and each time it enables more verbose prints. 

=item B<--config> I<config-file>

All options given by the command line can also be given in the
configuration file. This option is used to read another configuration
file in addition to the default configuration file. 

=item B<--filenames> B<-f>

Take the output file name from the input instead from command line.
This is usefull when processing the gffprint(1) B<-b> or gffprint(1)
B<-f> output.

=item B<--output> B<-o> I<output_file>

Resulting binary erf is written to this file. 

=item B<--separator> B<-s> I<separator>

Assume that the input file is using given string as a separator
between the label and value instead of default I<:\t>.

=back

=head1 EXAMPLES

    gffprint -t foo.git > file; emacs file; gffencode -o foo.git file
    gffprint -b -t *.git | sed 's/foo/bar/g' | gffencode -f

=head1 FILES

=over 6

=item ~/.gffencoderc

Default configuration file.

=back

=head1 SEE ALSO

gffprint(1), gffmodify(1), Gff(3), and GffWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program appeared as a pair to the gffprint(1) after we needed to
change a tags of all items in the given area (several hundred cases). 

