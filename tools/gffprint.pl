#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# gffprint.pl -- Simple program to print BioWare Gff files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: gffprint.pl
#	  $Source: /u/samba/nwn/bin/RCS/gffprint.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 02:02 Jul 19 2004 kivinen
#	  Last Modification : 01:27 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:27:07 $
#	  Revision number   : $Revision: 1.17 $
#	  State             : $State: Exp $
#	  Version	    : 1.703
#	  Edit time	    : 350 min
#
#	  Description       : Simple program to print BioWare Gff files
#
#	  $Log: gffprint.pl,v $
#	  Revision 1.17  2007/05/23 22:27:07  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.16  2007/05/23 22:03:29  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.15  2007/05/17 22:00:03  kivinen
#	  	Added --print-code option.
#
#	  Revision 1.14  2005/10/27 17:07:38  kivinen
#	  	Added support for expanding string refs from the tlk file.
#
#	  Revision 1.13  2005/02/05 18:09:30  kivinen
#	  	Fixed =from to =item.
#
#	  Revision 1.12  2005/02/05 17:50:41  kivinen
#	  	Added documentation.
#
#	  Revision 1.11  2005/02/05 14:46:29  kivinen
#	  	Documented --skip-empty.
#
#	  Revision 1.10  2005/02/05 14:36:44  kivinen
#	  	Added -skip-empty option to skip empty items when printing
#	  	gff.
#
#	  Revision 1.9  2004/09/20 11:45:46  kivinen
#	  	Added internal globbing.
#
#	  Revision 1.8  2004/08/15 12:38:00  kivinen
#	  	Updated to new Gff module support. Removed matching support,
#	  	and now this is only used for printing.
#
#	  Revision 1.7  2004/07/26 15:12:41  kivinen
#	  	Fixed usage.
#
#	  Revision 1.6  2004/07/22 14:50:16  kivinen
#	  	Added short options to some options. Added support for
#	  	--print-filename and --print-basename options.
#
#	  Revision 1.5  2004/07/20 15:27:21  kivinen
#	  	Changed proc functions to use one common option. Added path
#	  	proc.
#
#	  Revision 1.4  2004/07/20 14:14:14  kivinen
#	  	Changed to use time instead of hires time. If you do not have
#	  	hires time, just simply uncomment the use Time::Hires line in
#	  	the beginning of file.
#
#	  Revision 1.3  2004/07/20 14:04:17  kivinen
#	  	Added option to print types also.
#
#	  Revision 1.2  2004/07/19 13:59:23  kivinen
#	  	New version.
#
#	  Revision 1.1  2004/07/19 11:08:54  kivinen
#	  	Created.
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package GffPrint;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use TlkRead;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::exclude = undef;
$Opt::include = undef;
$Opt::exclude_field = undef;
$Opt::include_field = undef;
$Opt::print_filename = 0;
$Opt::print_basename = 0;
$Opt::print_types = 0;
$Opt::separator = ":\t";
$Opt::no_labels = 0;
$Opt::skip_empty = 0;
$Opt::dialog = undef;
$Opt::print_code = 0;

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
    read_rc_file("$ENV{'HOME'}/.gffprintrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"exclude|e=s" => \$Opt::exclude,
		"include|i=s" => \$Opt::include,
		"exclude-field=s" => \$Opt::exclude_field,
		"include-field=s" => \$Opt::include_field,
		"print-types|t" => \$Opt::print_types,
		"print-filename|f" => \$Opt::print_filename,
		"print-basename|b" => \$Opt::print_basename,
		"print-code|c" => \$Opt::print_code,
		"no-labels|l" => \$Opt::no_labels,
		"separator|s=s" => \$Opt::separator,
		"skip-empty|S" => \$Opt::skip_empty,
		"dialog|d=s" => \$Opt::dialog,
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

my($i, $t0, %args, $tlk);

%args = (include => $Opt::include,
	 exclude => $Opt::exclude,
	 include_field => $Opt::include_field,
	 exclude_field => $Opt::exclude_field);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

if (defined($Opt::dialog) && $Opt::dialog ne "") {
    $tlk = TlkRead::read(filename => $Opt::dialog);
}


foreach $i (@ARGV) {
    my($gff);
    $args{'filename'} = $i;
    $t0 = time();
    if (defined($Opt::print_basename) && $Opt::print_basename) {
	$main::file = $i . ": ";
	$main::file =~ s/^.*[\/\\]//g;
    } elsif (defined($Opt::print_filename) && $Opt::print_filename) {
	$main::file = $i . ": ";
    } else {
	$main::file = "";
    }
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $gff = GffRead::read(%args);
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    $gff->print(print_types => $Opt::print_types,
		prefix => $main::file,
		print_code => $Opt::print_code,
		($Opt::skip_empty ? (skip_matching_value => '^$') : ()),
		no_labels => $Opt::no_labels,
		separator => $Opt::separator,
		dialog => $tlk);
}

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
}

=head1 NAME

gffprint - Print Gff structures

=head1 SYNOPSIS

gffprint [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--print-types>|B<-t>]
    [B<--print-filename>|B<-f>]
    [B<--print-basename>|B<-b>]
    [B<--print-code>|B<-c>]
    [B<--exclude>|B<-e> I<exclude-regexp>]
    [B<--include>|B<-i> I<include-regexp>]
    [B<--exclude-field> I<exclude-regexp>]
    [B<--include-field> I<include-regexp>]
    [B<--no-labels>|B<-l>]
    [B<--separator>|B<-s> I<separator>]
    [B<--skip-empty>|B<-S>]
    [B<--dialog>|B<-d> I<filename.tlk>]
    I<filename> ...

gffprint B<--help>

=head1 DESCRIPTION

B<gffprint> prints gff structures to human readable or machine
editable format. The output of the B<gffprint> can be converted back
to gff by using gffencode(1) (you most likely need to use B<-t> and
B<-b> options).

I<filename> is read in and selected fields are printed out from it.
The output is normally prefixed with the label (unless B<-l> is
given), and it can be prefixed with filename (if B<-f> is given), or
basefilename (if B<-b> is given). If B<-t> is given then also the
internal type information is printed (this is needed in case of the
output needs to be converted back to gff).

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

=item B<--print-types> B<-t>

Print also the gff specific type information. This option is needed in
case the output of B<gffprint> is wanted to convert back to the gff
using gffencode(1).

=item B<--print-filename> B<-f>

Prefix the output with the full file name. 

=item B<--print-basename> B<-b>

Prefix the output with the base filename, i.e. the file name where the
path component is removed. 

=item B<--print-code> B<-c>

Print out the gff as a perl code. 

=item B<--exclude> B<-e> I<exclude-regexp>

Exclude the given regexp when reading the data in. This will skip the
whole structure behind the given structure, meaning that B<--include>
cannot be used to get parts of that back. This can be used to speed up
the processing if only specific parts of the tree is required.
Normally this should be something like I<^/Creature List> meaning that
all creature list information is skipped when reading gff.

=item B<--include> B<-i> I<include-regexp>

Only include the given regexp when reading the data in. This will skip
all other structures which do not match the regexp. This can be used
to speed up the processing if only specific parts of the tree is
required. Normally this should be something like I<^/Creature List>
meaning that only  creature list information is read in. 

=item B<--exclude-field> I<exclude-regexp>

Exclude given fields to be read in in case their labels match the
given regexp. This only matches the end labels, not intermediate
structure labels. 

=item B<--include-field> I<include-regexp>

Only include given fields matching the given regexp to the structures.
This only matches the end labels, not intermediate structure labels.

=item B<--no-labels> B<-l>

Do not print the labels for each field, only print the value (and the
file name if requested)

=item B<--separator> B<-s> I<separator>

Use the given string as a separator between the label and value
instead of default I<:\t>.

=item B<--skip-empty> B<-S>

Skip all empty fields from the output.

=item B<--dialog> B<-d> I<filename.tlk>

Pointer to the tlk file. If given then it is used to convert string
references to strings in case there is no strings in the item item
itself.

=back

=head1 EXAMPLES

    gffprint cereaadminbuildi.git
    gffprint -b cereaadminbuildi.git
    gffprint -b -t cereaadminbuildi.git | sed 's/foo/bar/g' | gffencode -f

=head1 FILES

=over 6

=item ~/.gffprintrc

Default configuration file.

=back

=head1 SEE ALSO

gffencode(1), gffmodify(1), Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program originally appeared as B<gffparse>, which mostly was a
test program for the GffRead(3) library. It was renamed to gffprint(1)
after the test program came large enough. 
