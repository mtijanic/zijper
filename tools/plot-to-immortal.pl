#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# p2i.pl -- Change creatures from plot to immortal
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: p2i.pl
#	  $Source: /u/samba/nwn/bin/RCS/plot-to-immortal.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 21:48 Sep 11 2004 kivinen
#	  Last Modification : 01:28 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:28:06 $
#	  Revision number   : $Revision: 1.3 $
#	  State             : $State: Exp $
#	  Version	    : 1.71
#	  Edit time	    : 27 min
#
#	  Description       : Change cretures from plot to immortal
#
#	  $Log: plot-to-immortal.pl,v $
#	  Revision 1.3  2007/05/23 22:28:06  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.2  2005/07/06 11:17:21  kivinen
#	  	Changed to check StayPlot variable.
#
#	  Revision 1.1  2004/09/20 11:45:04  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package PlotToImmortal;
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
    read_rc_file("$ENV{'HOME'}/.plottoimmortalrc");
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
    next if ($i eq "entry.git");
    if ($i =~ /^(.*)\.git$/) {
	$gff = GffRead::read(filename => $1 . ".are");
	$main::name = $$gff{Name}{0};
	$main::tag = $$gff{Tag};
	$gff = GffRead::read(filename => $i);
	$gff->find(find_label => '^/Creature List\[\d+\]/$',
		   proc => \&find_proc);
    } elsif ($i =~ /\.utc$/) {
	$main::name = "";
	$main::tag = "";
	$gff = GffRead::read(filename => $i);
	find_proc($gff, "/", undef, undef, $gff);
    } else {
	warn "Unknown file $i, not a utc or git file\n";
    }
    if ($main::modified) {
	print("Writing $i back\n");
	&GffWrite::write($gff, filename => $i);
    }
}

exit 0;

######################################################################
# Find proc
sub find_proc {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;

    if ($$gff{Plot} == 1 && $$gff{IsImmortal} == 0) {
	my($name);
	if (defined($$gff{FirstName}{0})) {
	    $name = $$gff{FirstName}{0};
	}
	if (defined($$gff{LastName}{0}) && $$gff{LastName}{0} ne "") {
	    $name .= " " if ($name ne "");
	    $name .= $$gff{LastName}{0};
	}
	if ($gff->variable('StayPlot') == 1) {
	    if ($main::name ne "") {
		print("$main::file - $main::name : $name plot -> Staying Plot\n");
	    } else {
		print("$main::file : $name plot -> Staying Plot\n");
	    }
	} else {
	    $$gff{Plot} = 0;
	    $$gff{IsImmortal} = 1;
	    $main::modified++;
	    if ($main::name ne "") {
		print("$main::file - $main::name : $name plot -> immortal\n");
	    } else {
		print("$main::file : $name plot -> immortal\n");
	    }
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
