#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# trnunpack.pl -- unpack nwn2 trn/trx files
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: trnunpack.pl
#	  $Source: /u/samba/nwn/bin/RCS/trnunpack.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 02:46 Jan 17 2007 kivinen
#	  Last Modification : 01:29 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:29:11 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.30
#	  Edit time	    : 12 min
#
#	  Description       : Unpack nwn2 trn/trx files
#
#	  $Log: trnunpack.pl,v $
#	  Revision 1.2  2007/05/23 22:29:11  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2007/01/23 22:41:02  kivinen
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
package TrnUnPack;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use TrnRead;
use Trn;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::dir = ".";
$Opt::mkdir = 0;
$Opt::no_write = 0;

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
    read_rc_file("$ENV{'HOME'}/.trnunpackrc");
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
    my($trn, $filename);
    $t0 = time();
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $trn = TrnRead::read('filename' => $i);
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    printf("File $i, type = %s, version = %d.%02d\n",
	   $trn->file_type, $trn->version_major, $trn->version_minor)
	if ($Opt::verbose > 1);
    printf("Resource count = %d\n", $trn->resource_count)
	if ($Opt::verbose > 1);
    for($j = 0; $j < $trn->resource_count; $j++) {
	printf("Filename = %04d.%s, type = %s, size = %d\n",
	       $j,
	       lc($trn->resource_type($j)),
	       $trn->resource_type($j),
	       $trn->resource_size($j))
	    if ($Opt::verbose > 2);
	$filename = sprintf("%s/%04d.%s", $Opt::dir, $j,
			    lc($trn->resource_type($j)));
	if (!$Opt::no_write) {
	    open(FILE, ">$filename")
		|| die "Cannot write $filename : $!";
	    binmode(FILE);
	    print(FILE $trn->resource_data($j));
	    close(FILE);
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
    Pod::Usage::pod2usage(0);
}

=head1 NAME

trnunpack - UnPack trn/trx file

=head1 SYNOPSIS

trnpack [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--dir>|B<-d> I<directory>]
    [B<--mkdir>|B<-m>]
    [B<--no-write>|B<-n>]
    [I<filename> ...]

trnunpack B<--help>

=head1 DESCRIPTION

B<trnunpack> takes trn/trx and unpacks it to given directory (B<-d>)
or to the current directory. If B<-m> is given then the directory is
created if it does not exists.

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

Output directory (default is current directory).

=item B<--mkdir> B<-m>

Create the output directory before extracting files. 

=item B<--no-write> B<-n>

Do not write anything to disk, but otherwise parse the trn.

=back

=head1 EXAMPLES

    trnunpack -d xx -m area1.trn
    trnunpack ../a_tk_dyoa.trx
    trnunpack -d a_tk_dyoa -m a_tk_dyoa.trx

=head1 FILES

=over 6

=item ~/.trnunpackrc

Default configuration file.

=back

=head1 SEE ALSO

trnpack(1), TrnRead(3), Trn(3), and TrnWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.
