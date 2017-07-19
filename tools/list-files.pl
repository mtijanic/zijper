#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# list-files.pl -- List files in hak / mod / erf
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: list-files.pl
#	  $Source: /u/samba/nwn/bin/RCS/list-files.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 23:32 Sep  7 2007 kivinen
#	  Last Modification : 00:20 Sep  8 2007 kivinen
#	  Last check in     : $Date: 2007/09/07 21:21:12 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.68
#	  Edit time	    : 26 min
#
#	  Description       : List files in hak / mod / erf
#
#	  $Log: list-files.pl,v $
#	  Revision 1.2  2007/09/07 21:21:12  kivinen
#	  	Added --matched and --remove-matched options.
#
#	  Revision 1.1  2007/09/07 20:51:49  kivinen
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
package ListFiles;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use ErfRead;
use Erf;
use Time::HiRes qw(time);
use Pod::Usage;
eval("use Archive::Zip qw( :ERROR_CODES :CONSTANTS );");

$Opt::verbose = 0;
$Opt::output = undef;
$Opt::filename = 0;
$Opt::matched_lines = undef;
$Opt::remove_matched_lines = undef;

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
    read_rc_file("$ENV{'HOME'}/.listfilesrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"output|o=s" => \$Opt::output,
		"filename|f" => \$Opt::filename,
		"matched|m=s" => \$Opt::matched_lines,
		"remove-matched|M=s" => \$Opt::remove_matched_lines,
		"help|h" => \$Opt::help,
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
my($i);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

if (defined($Opt::output)) {
    open(FILE, ">$Opt::output") || die "Cannot open $Opt::output for writing: $!";
}

foreach $i (@ARGV) {
    my($erf);
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    if ($i =~ /\.zip$/i) {
	my($zip, @members, $j, $data);
	$zip = Archive::Zip->new();
	if ($zip->read($i) != &AZ_OK) {
	    die "Error reading zip file $i : $!";
	}
	print("Reading zip-file $i...\n") if ($Opt::verbose);
	@members = $zip->memberNames();
	foreach $j (@members) {
	    if ($j =~ /\.(mod|erf|hak|pwc)/i) {
		print("Reading file $j from $i...\n")
		    if ($Opt::verbose);
		$data = $zip->contents($j);
		$erf = ErfRead::read('data' => $data);
		printf("Read done\n") if ($Opt::verbose);
		process_file($i . ":" . $j, $erf);
	    }
	}
    } else {
	$erf = ErfRead::read('filename' => $i);
	process_file($i, $erf);
	printf("Read done\n") if ($Opt::verbose);
    }
}

exit 0;

######################################################################
# process_file

sub process_file {
    my($file, $erf) = @_;
    my($name, $j, $text);
    
    if ($Opt::filename) {
	$name = $file . ": ";
    } else {
	$name = "";
    }
   
    printf("File %s, type = %s, version = %s\n",
	   $file, $erf->file_type, $erf->file_version)
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
	$text = $name . $erf->resource_reference($j) . "." .
	    $erf->resource_extension($j);
	next if (defined($Opt::remove_matched_lines) &&
		 $text =~ /$Opt::remove_matched_lines/i);
	if (!defined($Opt::matched_lines) ||
	    $text =~ /$Opt::matched_lines/i) {
	    if (defined($Opt::output)) {
		print(FILE $text, "\n");
	    } else {
		print($text, "\n");
	    }
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
    Pod::Usage::pod2usage(0);
}

=head1 NAME

list-files - List files in hak / mod / erf

=head1 SYNOPSIS

list-files [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--output>|B<-o> I<outputfilename>]
    [B<--matched>|B<-m> I<match-regexp>]
    [B<--remove-matched>|B<-M> I<remove-matched-regexp>]
    [B<--filename>|B<-f>]
    [I<filename> ...]

list-files B<--help>

=head1 DESCRIPTION

B<list-files> takes mod, hak, erf, or pwc and lists files inside it.
If given zip file, searches the contents of the zip and prints all
files inside mods, haks, erfs or pwcs inside the zip.

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

=item B<--output>|B<-o> I<outputfilename>

Stores the list of files to the file named outputfilename.

=item B<--matched>|B<-m> I<match-regexp>

If this is given, then only print lines which match given regexp
(unless they also match the --remove-matched regexp).

=item B<--remove-matched>|B<-m> I<remove-matched-regexp>

If this is given, do not print lines which match the given regexp (not
even if they also match the --matched regexp).

=item B<--filename>|B<-f>

Adds name of the file from where the file is to the beginning of line.

=back

=head1 EXAMPLES

    list-files foo.erf
    list-files -f cerea109o.mod
    list-files -o output.txt cerea2.zip
    list-files -o output.txt -M '\.(mdb|tga)$' file.hak

=head1 FILES

=over 6

=item ~/.listfilesrc

Default configuration file.

=back

=head1 SEE ALSO

erfpack(1), erfunpack(1), Erf(3), and ErfWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was created for Carter / Tyrnis (requested by Drakolight)
to list contents of the hak for plugin use.
