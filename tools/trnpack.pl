#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# trnpack.pl -- pack nwn2 trn/trx files
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: trnpack.pl
#	  $Source: /u/samba/nwn/bin/RCS/trnpack.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 03:10 Jan 17 2007 kivinen
#	  Last Modification : 01:28 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:28:55 $
#	  Revision number   : $Revision: 1.3 $
#	  State             : $State: Exp $
#	  Version	    : 1.29
#	  Edit time	    : 18 min
#
#	  Description       : Pack nwn2 trn/trx files
#
#	  $Log: trnpack.pl,v $
#	  Revision 1.3  2007/05/23 22:28:55  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.2  2007/05/17 22:02:44  kivinen
#	  	Added outversion option.
#
#	  Revision 1.1  2007/01/23 22:40:55  kivinen
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
package TrnPack;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use TrnWrite;
use Trn;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::dir = undef;
$Opt::output = undef;
$Opt::outversion = undef;

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
    read_rc_file("$ENV{'HOME'}/.trnpackrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"dir|d=s" => \$Opt::dir,
		"output|o=s" => \$Opt::output,
		"outversion|O=s" => \$Opt::outversion,
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
my($i, $j, $t0, $data, $type);

my($trn) = new Trn;

if (defined($Opt::outversion) && $Opt::outversion =~ /(\d+)\.(\d+)/) {
    $trn->version_major($1);
    $trn->version_minor($2);
}

if (!defined($Opt::output)) {
    die "No output file given";
}

if (defined($Opt::dir)) {
    if (!-d $Opt::dir) {
	die "$Opt::dir is not a directory";
    }
    push(@ARGV, <$Opt::dir/*>);
    @ARGV = sort(@ARGV);
} else {
    if (join(";", @ARGV) =~ /[*?]/) {
	my(@argv);
	foreach $i (@ARGV) {
	    push(@argv, bsd_glob($i));
	}
	@ARGV = @argv;
    }
}

$t0 = time();
$j = 0;
undef $/;
foreach $i (@ARGV) {
    if ($Opt::verbose > 1) {
	print("Adding file $i\n");
    }
    if ($i =~ /\.(....)$/) {
	$type = uc($1);
    } else {
	die "File type unknown: $i";
    }
    open(FILE, "<$i") || die "Cannot open $i : $!";
    binmode(FILE);
    $data = <FILE>;
    close(FILE);
	
    $trn->new_resource($data, $type);
    $j++;
}
if ($Opt::verbose) {
    printf("Adding $j files done, %g seconds\n", time() - $t0);
}

&TrnWrite::write($trn, filename => $Opt::output);
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
# Usage

sub usage {
    Pod::Usage::pod2usage(0);
}

=head1 NAME

trnpack - Pack files to trn/trx.

=head1 SYNOPSIS

trnpack [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--dir>|B<-d> I<directory>]
    [B<--outversion>|B<-O> I<version>]
    B<--output>|B<-o> I<output_file>
    [I<filename> ...]

trnpack B<--help>

=head1 DESCRIPTION

B<trnpack> takes files and creates trn/trx out from them. The output
is written to the file specified with B<--output> option. If list of
files is given then only those files are added to the output file. If
file list is omitted and B<--dir> is given then all files in the given
directory are added to trn.

Note that in trx/trn file it might be possible that the nwn2 requires
resources in certain order. Normally they are so that TRWH is first,
then all TRRN files (from 00x00y, 01x00y ... 99x99y), and then WATR
(in same order), and finally ASWM. It is not known how the game reacts
if this order is not followed. Items are added in the order they
appear on the command line, or sorted alphabetically in case directory
is given.

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

=item B<--output> B<-o> I<output_file>

File where the output is written. The file is always overwritten. 

=item B<--outversion> B<-O> I<version>

Version to be used when writing file out. For trn files this is
normally 2.3, but for example mdb files have version number of 1.12
and toolset will crash if given version 2.3.

=back

=head1 EXAMPLES

    trnpack -o test.trn 0000.trwh 0001.trrn 0002.trrn 
    trnpack -d area1 -o area.trx
    trnpack -o a_tk_dyoa.trn a_tk_dyoa/*

=head1 FILES

=over 6

=item ~/.trnpackrc

Default configuration file.

=back

=head1 SEE ALSO

trnunpack(1), TrnWrite(1), Trn(3), and TrnRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

