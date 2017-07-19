#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# fix-spell-scripts.pl -- Fix spell scripts
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: fix-spell-scripts.pl
#	  $Source: /u/samba/nwn/bin/RCS/fix-spell-scripts.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 23:19 Sep  4 2004 kivinen
#	  Last Modification : 01:25 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:25:50 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.20
#	  Edit time	    : 14 min
#
#	  Description       : Fix spell scripts so that replace GetCasterLevel
#			      and GetMetaMagicFeat with Ztk* versions. 
#
#	  $Log: fix-spell-scripts.pl,v $
#	  Revision 1.2  2007/05/23 22:25:50  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2004/09/20 11:46:45  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package FixSpellScripts;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Time::HiRes qw(time);

$Opt::verbose = 0;
$Opt::dir = ".";
$Opt::mkdir = 0;

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
    read_rc_file("$ENV{'HOME'}/.fixspellscriptsrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"dir|d=s" => \$Opt::dir,
		"mkdir|m" => \$Opt::mkdir,
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

if ($Opt::mkdir) {
    mkdir_p($Opt::dir, 0777);
}
if (!-d $Opt::dir) {
    die "$Opt::dir is not a directory";
}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv, $i);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

# Note, that x0_s0_firebrand.nss assumes you have new x0_i0_spells, but we still have old one
# The new one calculates reflex save, and gives one argument to the DoMissileStorm
# to indicate that. 
my($i, $data);

undef $/;
foreach $i (@ARGV) {
    if ($i eq "nw_s0_shadconj.nss" ||
	$i eq "nw_s0_grshconj.nss" ||
	$i eq "nw_s0_shades.nss" ||
	$i eq "nw_s0_massdomn.nss") {
	print("Skipping obsolete file $i\n");
	next;
    }
    if ($i eq "x2_s2_wildshpedk.nss") {
	print("Skipping file $i\n");
	next;
    }
    open(FILE, "<$i") || die "Cannot open $i : $!";
    binmode(FILE);
    $data = <FILE>;
    close(FILE);
    print("Processing $i\n") if ($Opt::verbose);
    if ($data =~ /^\s*\#\s*include\s*\"(x0_i0_spells|x0_i0_spells)\"/i) {
	print("No need to add include to $i\n");
    } else {
	$data = "#include \"inc_ztk_cg\"\r\n" . $data;
    }
    $data =~ s/GetMetaMagicFeat/ZtkGetMetaMagicFeat/g;
    $data =~ s/GetCasterLevel/ZtkGetCasterLevel/g;
    open(FILE, ">$Opt::dir/$i") || die "Cannot open $Opt::dir/$i : $!";
    binmode(FILE);
    print(FILE $data);
    close(FILE);
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
# mkdir_p

sub mkdir_p {
    my($dir, $mask) = @_;
    my(@dirs) = split(/\//, $dir);
    my($d, $i);

    $d = '';
    foreach $i (@dirs) {
	$d .= $i;
	mkdir($d, $mask);
	$d .= "/";
    }
}

######################################################################
# Usage

sub usage {
    print("Usage: $Prog::progname [--help] [--version] ".
	  "\n\t[--verbose|-v] " .
	  "\n\t[--dir|-d dir] " .
	  "\n\t[--mkdir|-m] " .
	  "\n\t[--config config-file] " .
	  "\n\tfilename ...\n");
    exit(0);
}
