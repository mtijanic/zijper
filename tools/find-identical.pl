#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# find-identical.pl -- Simple program to compare BioWare Gff files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: find-identical.pl
#	  $Source: /u/samba/nwn/bin/RCS/find-identical.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 20:15 Aug 10 2004 kivinen
#	  Last Modification : 01:23 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:23:46 $
#	  Revision number   : $Revision: 1.4 $
#	  State             : $State: Exp $
#	  Version	    : 1.42
#	  Edit time	    : 10 min
#
#	  Description       : Simple program to find identical BioWare
#			      Gff files
#
#	  $Log: find-identical.pl,v $
#	  Revision 1.4  2007/05/23 22:23:46  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.3  2004/09/20 11:47:01  kivinen
#	  	Added internal globbing.
#
#	  Revision 1.2  2004/08/25 15:20:54  kivinen
#	  	Finished.
#
#	  Revision 1.1  2004/08/15 12:36:13  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package FindIdentical;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Gff;
use GffRead;
use Time::HiRes qw(time);

$Opt::verbose = 0;

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
    read_rc_file("$ENV{'HOME'}/.findidenticalrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
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

my($i, $j, @gff, $ret, $t0);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

$t0 = time();
print("Reading files\n");
for($i = 0; $i <= $#ARGV; $i++) {
    if ($Opt::verbose > 2) {
	print("Reading $i $ARGV[$i]...\n");
    }
    $gff[$i] = GffRead::read(exclude_field => '^TemplateResRef$',
			     filename => $ARGV[$i]);
}
printf("Read done, %g seconds\n", time() - $t0);

if ($Opt::verbose) {
    print("Starting compare\n");
}

for($i = 0; $i <= $#ARGV; $i++) {
    if ($Opt::verbose > 1) {
	print("Using basefile $ARGV[$i]...\n");
    }
    for($j = $i + 1; $j <= $#ARGV; $j++) {
	print("Comparing to $ARGV[$j]...\n")
	    if ($Opt::verbose > 3);

	$ret = Gff::match($gff[$i], $gff[$j]);
	if (!$ret) {
	    print("Files $ARGV[$i] and $ARGV[$j] match\n");
	}
    }
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
    print("Usage: $Prog::progname [--help] [--version] ".
	  "\n\t[--verbose|-v] " .
	  "\n\t[--config config-file] " .
	  "\n\tfilename ...\n");
    exit(0);
}
