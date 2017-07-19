#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# erfunpack.pl -- unpack BioWare erf/mod etc files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: erfunpack.pl
#	  $Source: /u/samba/nwn/bin/RCS/erfunpack.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 16:28 Jul 24 2004 kivinen
#	  Last Modification : 23:50 Sep  7 2007 kivinen
#	  Last check in     : $Date: 2007/09/07 20:51:30 $
#	  Revision number   : $Revision: 1.10 $
#	  State             : $State: Exp $
#	  Version	    : 1.123
#	  Edit time	    : 58 min
#
#	  Description       : Unpack BioWare erf/mod etc files
#
#	  $Log: erfunpack.pl,v $
#	  Revision 1.10  2007/09/07 20:51:30  kivinen
#	  	Put language list printing inside verbose checks.
#
#	  Revision 1.9  2007/05/23 22:23:23  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.8  2007/01/10 14:17:46  kivinen
#	  	Fixed support for unknown extension types.
#
#	  Revision 1.7  2005/10/11 15:25:45  kivinen
#	  	Added Archive::Zip to be optional.
#
#	  Revision 1.6  2005/07/06 11:09:11  kivinen
#	  	Added support to expand erfs and modules directly from zip
#	  	files.
#
#	  Revision 1.5  2005/02/05 18:17:52  kivinen
#	  	Fixed typos.
#
#	  Revision 1.4  2005/02/05 17:50:20  kivinen
#	  	Added documentation.
#
#	  Revision 1.3  2004/09/20 11:47:25  kivinen
#	  	Added internal globbing. Added code to skip empty entries.
#
#	  Revision 1.2  2004/08/15 12:36:09  kivinen
#	  	Added better printing. Removed debug stuff.
#
#	  Revision 1.1  2004/07/26 15:11:39  kivinen
#	  	Created.
#	  $EndLog$
#
#
#
#
######################################################################
# initialization

require 5.6.0;
package ErfUnPack;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use ErfRead;
use Erf;
use Time::HiRes qw(time);
use Pod::Usage;
eval("use Archive::Zip qw( :ERROR_CODES :CONSTANTS );");

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
    read_rc_file("$ENV{'HOME'}/.erfunpackrc");
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
    my($erf, $filename);
    $t0 = time();
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    if ($i =~ /\.zip$/i) {
	my($zip, @members, $j, $file, $data);
	$zip = Archive::Zip->new();
	if ($zip->read($i) != &AZ_OK) {
	    die "Error reading zip file $i : $!";
	}
	print("Reading zip-file $i...\n") if ($Opt::verbose);
	@members = $zip->memberNames();
	foreach $j (@members) {
	    if ($j =~ /\.(mod|erf)/i) {
		$file = $j;
		last;
	    }
	}
	if (!defined($file)) {
	    die "Could not find any mod or erf files from the archive, members = " .
		join(", ", @members);
	}
	print("Reading file $file from $i...\n") if ($Opt::verbose);
	$data = $zip->contents($file);
	$erf = ErfRead::read('data' => $data);
    } else {
	$erf = ErfRead::read('filename' => $i);
    }
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    printf("File $i, type = %s, version = %s\n",
	   $erf->file_type, $erf->file_version)
	if ($Opt::verbose > 1);
    printf("Language count = %d, build_year = %d, day = %s\n",
	   $erf->language_count, $erf->build_year + 1900, $erf->build_day)
	if ($Opt::verbose > 1);
    printf("String ref of description = %d\n", $erf->description_string_ref)
	if ($Opt::verbose > 1);
    printf("Resource count = %d\n", $erf->resource_count)
	if ($Opt::verbose > 1);
    if ($Opt::verbose > 1) {
	foreach $j ($erf->localized_string) {
	    printf("Language %d = %s\n",
		   $j, $erf->localized_string($j));
	}
    }
    for($j = 0; $j < $erf->resource_count; $j++) {
	printf("Filename = %s.%s, type = %d, offset = %d, size = %d\n",
	       $erf->resource_reference($j),
	       $erf->resource_extension($j),
	       $erf->resource_type($j),
	       $erf->resource_offset($j),
	       $erf->resource_size($j))
	    if ($Opt::verbose > 2);
	if (!defined($erf->resource_reference($j)) ||
	    !defined($erf->resource_extension($j)) ||
	    !defined($erf->resource_type($j)) ||
	    $erf->resource_reference($j) eq "" ||
	    $erf->resource_extension($j) eq "") {
	    warn "Found filename `" .
		$erf->resource_reference($j) . "' with type " .
		$erf->resource_type($j) . " with size = " .
		$erf->resource_size($j) . " (offset = " .
		$erf->resource_offset($j) ."), skipped";
	} else {
	    $filename = $Opt::dir . "/" . $erf->resource_reference($j) . "." .
		$erf->resource_extension($j);
	    if (!$Opt::no_write) {
		open(FILE, ">$filename")
		    || die "Cannot write $filename : $!";
		binmode(FILE);
		print(FILE $erf->resource_data($j));
		close(FILE);
	    }
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

erfunpack - UnPack erf file

=head1 SYNOPSIS

erfpack [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--dir>|B<-d> I<directory>]
    [B<--mkdir>|B<-m>]
    [B<--no-write>|B<-n>]
    [I<filename> ...]

erfunpack B<--help>

=head1 DESCRIPTION

B<erfunpack> takes erf and unpacks it to given directory (B<-d>) or to
the current directory. If B<-m> is given then the directory is created
if it does not exists. 

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

Do not write anything to disk, but otherwise parse the erf.

=back

=head1 EXAMPLES

    erfunpack -d xx -m foo.erf
    erfunpack ../cerea109o.mod
    erfunpack -d 109o -m cerea109.mod

=head1 FILES

=over 6

=item ~/.erfunpackrc

Default configuration file.

=back

=head1 SEE ALSO

erfpack(1), gffprint(1), Erf(3), and ErfWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.
