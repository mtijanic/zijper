#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# keyunpack.pl -- print BioWare key files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: keyunpack.pl
#	  $Source: /u/samba/nwn/bin/RCS/keyunpack.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 17:31 Aug 15 2004 kivinen
#	  Last Modification : 01:27 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:27:21 $
#	  Revision number   : $Revision: 1.4 $
#	  State             : $State: Exp $
#	  Version	    : 1.27
#	  Edit time	    : 10 min
#
#	  Description       : Unpack BioWare key/bif files
#
#	  $Log: keyunpack.pl,v $
#	  Revision 1.4  2007/05/23 22:27:21  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.3  2004/10/12 15:26:39  kivinen
#	  	Convert filename to lower case before creating to it.
#
#	  Revision 1.2  2004/09/20 11:45:25  kivinen
#	  	Added internal globbing.
#
#	  Revision 1.1  2004/08/15 12:36:45  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
#
######################################################################
# initialization

require 5.6.0;
package Keyunpack;
use strict;
use Getopt::Long;
use KeyRead;
use Key;
use File::Glob ':glob';
use Time::HiRes qw(time);

$Opt::verbose = 0;
$Opt::dir = ".";
$Opt::mkdir = 0;
$Opt::no_write = 0;
$Opt::file_pattern = '';

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

$Prog::version = "$Prog::revision." .
    "$Prog::save_version.$Prog::edit_time";
$Prog::progname = $0;
$Prog::progname =~ s/^.*[\/\\]//g;

$| = 1;

######################################################################
# Read rc-file

if (defined($ENV{'HOME'})) {
    read_rc_file("$ENV{'HOME'}/.keyunpackrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"dir|d=s" => \$Opt::dir,
		"mkdir|m" => \$Opt::mkdir,
		"no-write|n" => \$Opt::no_write,
		"pattern|p=s" => \$Opt::file_pattern,
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
my($i, $j, $t0);

if ($Opt::mkdir && !$Opt::no_write) {
    mkdir_p($Opt::dir, 0777);
}
if (!-d $Opt::dir && !$Opt::no_write) {
    die "$Opt::dir is not a directory";
}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    my($key, $filename);
    $t0 = time();
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $key = KeyRead::read('filename' => $i);
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    printf("File $i, type = %s, version = %s\n",
	   $key->file_type, $key->file_version)
	if ($Opt::verbose > 1);
    printf("bif_count = %d, key_count = %d, build_year = %d, day = %s\n",
	   $key->bif_count, $key->key_count,
	   $key->build_year + 1900, $key->build_day)
	if ($Opt::verbose > 1);
    if ($Opt::verbose > 2) {
	for($j = 0; $j < $key->bif_count; $j++) {
	    printf("Filename = %s:%s, size = %d\n",
		   $key->drive($j),
		   $key->file_name($j),
		   $key->file_size($j));
	}
    }
    for($j = 0; $j < $key->key_count; $j++) {
	$filename = $key->resource_reference($j) . "." .
	    $key->resource_extension($j);
	if ($filename =~ /$Opt::file_pattern/) {
	    if ($Opt::no_write) {
		printf("Not writing resource = %s.%s, from file %s:%s, " .
		       "index %d\n",
		       $key->resource_reference($j),
		       $key->resource_extension($j),
		       $key->resource_drive($j),
		       $key->resource_filename($j),
		       $key->resource_index($j))
		    if ($Opt::verbose);
	    } else {
		$filename = $Opt::dir . "/" . lc($filename);
		printf("Writing resource = %s.%s, from file %s:%s, index %d\n",
		       $key->resource_reference($j),
		       $key->resource_extension($j),
		       $key->resource_drive($j),
		       $key->resource_filename($j),
		       $key->resource_index($j))
		    if ($Opt::verbose);
		open(FILE, ">$filename") || die "Cannot write $filename : $!";
		binmode(FILE);
		print(FILE $key->resource_data($j));
		close(FILE);
	    }
	} else {
	    printf("Skipping resource = %s.%s, from file %s:%s, " .
		   "index %d\n",
		   $key->resource_reference($j),
		   $key->resource_extension($j),
		   $key->resource_drive($j),
		   $key->resource_filename($j),
		   $key->resource_index($j))
		if ($Opt::verbose > 5);
	}
    }
    if ($Opt::verbose) {
	printf("Write done, %g seconds\n", time() - $t0);
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
	  "\n\t[--config config-file] " .
	  "\n\t[--dir|-d dir] " .
	  "\n\t[--mkdir|-m] " .
	  "\n\t[--no-write|-n] " .
	  "\n\t[--pattern|-p file-name-regexp] " .
	  "\n\tfilename ...\n");
    exit(0);
}

