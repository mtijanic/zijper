#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# rename-areas.pl -- Rename all areas
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: rename-areas.pl
#	  $Source: /u/samba/nwn/bin/RCS/rename-areas.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 20:43 Sep 11 2004 kivinen
#	  Last Modification : 01:28 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:28:29 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.117
#	  Edit time	    : 31 min
#
#	  Description       : Rename all areas
#
#	  $Log: rename-areas.pl,v $
#	  Revision 1.2  2007/05/23 22:28:29  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2004/09/20 11:44:54  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package RenameAreas;
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
    read_rc_file("$ENV{'HOME'}/.renameareasrc");
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

my($i, %name, %tag, $name, $file);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}
				 

foreach $i (@ARGV) {
    my($gff);
    $gff = GffRead::read(filename => $i);
    $file = $i;
    $file =~ s/\.are$//g;
    $name{$file} = $$gff{Name}{0};
    $tag{$file} = $$gff{Tag};
}

my(@temp);

foreach $i (sort keys %name) {
    next if ($i !~ /^area/);
    $name = lc($name{$i});
    $name =~ tr/[a-z0-9\- ]//cd;
    $name =~ s/^\s+//g;
    $name =~ s/\s+$//g;
    @temp = split(/-/, $name);
    if ($#temp == 3) {
	splice(@temp, 1, 1);
    }
    if ($temp[-1] =~ s/\s+(\S+)$//) {
	push(@temp, $1);
    }
    $name = join("-", @temp);
    $name =~ tr/ //d;
    $name =~ s/([a-z0-9]{4})[a-z0-9]+-/$1-/g;
    $name =~ tr/-//d;
    $name = substr($name, 0, 16);
    if (defined($tag{$name})) {
	die "Duplicate name, $name : $tag{$i} / $name{$i} and $tag{$name} / $name{$name}";
    }
    $tag{$name} = $tag{$i};
    $name{$name} = $name{$i};
    print("echo \'", $i, " -> ", $name, " : ", $name{$i}, "\'\n");
    print("mv -i $i.are $name.are\n");
    print("mv -i $i.git $name.git\n");
    print("mv -i $i.gic $name.gic\n");
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
	  "\n\t[--config config-file] " .
	  "\n\tfilename ...\n");
    exit(0);
}
