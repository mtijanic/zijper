#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# erfpack.pl -- pack BioWare erf/mod etc files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: erfpack.pl
#	  $Source: /u/samba/nwn/bin/RCS/erfpack.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 09:07 Jul 31 2004 kivinen
#	  Last Modification : 01:23 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:23:14 $
#	  Revision number   : $Revision: 1.7 $
#	  State             : $State: Exp $
#	  Version	    : 1.93
#	  Edit time	    : 43 min
#
#	  Description       : Pack BioWare erf/mod etc files
#
#	  $Log: erfpack.pl,v $
#	  Revision 1.7  2007/05/23 22:23:14  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.6  2007/01/10 14:30:39  kivinen
#	  	Added --hak option.
#
#	  Revision 1.5  2006/12/21 17:45:05  kivinen
#	  	Added --erfversion flag.
#
#	  Revision 1.4  2005/02/05 17:50:14  kivinen
#	  	Added documentation.
#
#	  Revision 1.3  2004/09/29 15:20:23  kivinen
#	  	Fixed usage.
#
#	  Revision 1.2  2004/09/20 11:47:58  kivinen
#	  	Added internal globbing. Added support for module description
#	  	from the module.ifo file.
#
#	  Revision 1.1  2004/08/15 12:35:39  kivinen
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
package ErfPack;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use ErfWrite;
use Erf;
use GffRead;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::dir = undef;
$Opt::output = undef;
$Opt::type = "MOD ";
$Opt::erfversion = undef;

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
    read_rc_file("$ENV{'HOME'}/.erfpackrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"dir|d=s" => \$Opt::dir,
		"output|o=s" => \$Opt::output,
		"type=s" => \$Opt::type,
		"module|m" => sub { $Opt::type = "MOD " },
		"erf|e" => sub { $Opt::type = "ERF " },
		"hak|H" => sub { $Opt::type = "HAK " },
		"erfver|E=s" => \$Opt::erfversion,
		"version|V" => \$Opt::version) || defined($Opt::help)) {
    usage();
}

if (defined($Opt::version)) {
    print("\u$Prog::progname version " .
	  "$Prog::version by Tero Kivinen.\n");
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

my($erf) = new Erf;

if (!defined($Opt::output)) {
    die "No output file given";
}

if (defined($Opt::dir)) {
    if (!-d $Opt::dir) {
	die "$Opt::dir is not a directory";
    }
    push(@ARGV, <$Opt::dir/*>);
} else {
    if (join(";", @ARGV) =~ /[*?]/) {
	my(@argv);
	foreach $i (@ARGV) {
	    push(@argv, bsd_glob($i));
	}
	@ARGV = @argv;
    }
}

$erf->file_type($Opt::type);
if (defined($Opt::erfversion)) {
    if ($Opt::erfversion =~ /^\d+.\d+$/) {
	$Opt::erfversion = "V" . $Opt::erfversion;
    } elsif ($Opt::erfversion =~ /^\d+$/) {
	$Opt::erfversion = "V1." . $Opt::erfversion;
    }
    $erf->file_version($Opt::erfversion);
}

# XXX localized strings, build_year, build_day etcs settings.

$t0 = time();
$j = 0;
foreach $i (@ARGV) {
    if ($Opt::type eq "MOD " && $i =~ /module\.ifo$/) {
	my($gff);
	
	$gff = GffRead::read(filename => $i);
	if (defined($$gff{Mod_Description}) &&
	    defined($$gff{Mod_Description}{0}) &&
	    $$gff{Mod_Description}{0} ne "") {
	    $erf->localized_string(0, $$gff{Mod_Description}{0});
	}
    }
    if ($Opt::verbose > 1) {
	print("Adding file $i\n");
    }
    $erf->new_file($i);
    $j++;
}
if ($Opt::verbose) {
    printf("Adding $j files done, %g seconds\n", time() - $t0);
}

&ErfWrite::write($erf, filename => $Opt::output);
if ($Opt::verbose) {
    printf("Write done, %g seconds\n", time() - $t0);
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
    Pod::Usage::pod2usage(0);
}

=head1 NAME

erfpack - Pack files to erf.

=head1 SYNOPSIS

erfpack [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--dir>|B<-d> I<directory>]
    [B<--type> I<type> | B<--module>|B<-m> | B<--erf>|B<-e> | B<--hak>|B<-H>]
    [B<--erfver> I<version> | B<-E> I<version]
    B<--output>|B<-o> I<output_file>
    [I<filename> ...]

erfpack B<--help>

=head1 DESCRIPTION

B<erfpack> takes files and creates erf out from them. If B<--module>
is given it creates a erf which can be used as module, the default is
to generate normal erf. The output is written to the file specified
with B<--output> option. If list of files is given then only those
files are added to the output file. If file list is omitted and
B<--dir> is given then all files in the given directory are added to
erf. 

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

=item B<--dir> B<-d> I<directory>

All files from this given directory are added to the output file. 

=item B<--type> I<type>

Sets the output erf type to be I<type>. The I<type> must be 4
characters. 

=item B<--module> B<-m>

Set the output erf type to "MOD ", i.e. it is normal bioware module. 

=item B<--erf> B<-e>

Set the output erf type to "ERF ", i.e. it is normal bioware erf. 

=item B<--hak> B<-H>

Set the output erf type to "HAK ", i.e. it is hak pak.

=item B<--erfver> B<-E> I<version>

Set the output erf version to be given version. Version can either be
full version string (i.e. "V1.1"), or floating point version ("1.1")
or just the final number (i.e. "1"). 

=item B<--output> B<-o> I<output_file>

File where the output is written. The file is always overwritten. 

=back

=head1 EXAMPLES

    erfpack -e -o test.erf test.uti test.utc
    erfpack -e -d 109o -o cerea109o.mod
    erfpack -e -o newstuff.mod newstuff/*

=head1 FILES

=over 6

=item ~/.erfpackrc

Default configuration file.

=back

=head1 SEE ALSO

erfunpack(1), gffencode(1), Erf(3), and ErfRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.
