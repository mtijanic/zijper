#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# add-onopen.pl -- Add onopen if not existing
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: add-onopen.pl
#	  $Source: /u/samba/nwn/bin/RCS/add-onopen.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 01:17 Sep 12 2004 kivinen
#	  Last Modification : 01:21 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:21:19 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.36
#	  Edit time	    : 20 min
#
#	  Description       : Add onopen if not existing
#
#	  $Log: add-onopen.pl,v $
#	  Revision 1.2  2007/05/23 22:21:19  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2004/09/20 11:48:11  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package AddOnOpen;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;

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
    read_rc_file("$ENV{'HOME'}/.addonopenrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
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

my($i, $name, $tag, %file);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    my($gff);
    $main::file = $i;
    $main::modified = 0;
    $gff = GffRead::read(filename => $i);
    $gff->find(find_label => '^/Door List\[\d+\]/$',
	       proc => \&fix_door);
    if ($main::modified) {
	print("Writing $i back\n");
	&GffWrite::write($gff, filename => $i);
    }
}

exit 0;

######################################################################
# fix_door
sub fix_door {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;

    if ($$gff{OnOpen} eq "") {
	my($head);
	$head = "$main::file: $$gff{Tag}: $full_label:";
	$main::modified = 1;
	$$gff{OnOpen} = "_gen_closedoor";
	print("$head OnOpen -> _gen_closedoor\n");
	if (!$$gff{Plot}) {
	    $$gff{Plot} = 1;
	    print("$head Plot -> 1\n");
	}
	if ($$gff{Locked} && $$gff{OnClosed} eq "") {
	    $$gff{OnClosed} = "_gen_lockdoornow";
	    print("$head OnClosed -> _gen_lockdoornow\n");
	}
    }
}

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
	  "\n\t[--config config-file] " .
	  "\n\tfilename ...\n");
    exit(0);
}
