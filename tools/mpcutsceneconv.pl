#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# mpcutsceneconv.pl -- Disable MPCutscene conversations
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: mpcutsceneconv.pl
#	  $Source: /u/samba/nwn/bin/RCS/mpcutsceneconv.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 05:59 Jan 25 2007 kivinen
#	  Last Modification : 01:27 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:27:54 $
#	  Revision number   : $Revision: 1.4 $
#	  State             : $State: Exp $
#	  Version	    : 1.52
#	  Edit time	    : 19 min
#
#	  Description       : Disable MPCutscene conversations
#
#	  $Log: mpcutsceneconv.pl,v $
#	  Revision 1.4  2007/05/23 22:27:54  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.3  2007/01/26 19:39:08  kivinen
#	  	Added *.mod as default arg.
#
#	  Revision 1.2  2007/01/25 04:59:54  kivinen
#	  	Disabled renaming of the old module, as it does not seem to
#	  	work on windows.
#
#	  Revision 1.1  2007/01/25 04:25:45  kivinen
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
package Mpcutsceneconv;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use ErfWrite;
use ErfRead;
use Erf;
use GffWrite;
use GffRead;
use Gff;
use Pod::Usage;

$Opt::verbose = 1;

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
    read_rc_file("$ENV{'HOME'}/.mpcutsceneconvrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
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
my($module, $i, $changed);

if ($#ARGV == -1) {
    push(@ARGV, "*.mod");
}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $module (@ARGV) {
    my($erf, $filename);
    if ($Opt::verbose > 1) {
	print("Reading file $module...\n");
    }
    $erf = ErfRead::read('filename' => $module);
    if ($Opt::verbose > 1) {
	printf("Read done\n");
    }
    printf("File $module, type = %s, version = %s\n",
	   $erf->file_type, $erf->file_version)
	if ($Opt::verbose);
    printf("Language count = %d, build_year = %d, day = %s\n",
	   $erf->language_count, $erf->build_year + 1900, $erf->build_day)
	if ($Opt::verbose > 2);
    printf("String ref of description = %d\n", $erf->description_string_ref)
	if ($Opt::verbose > 2);
    printf("Resource count = %d\n", $erf->resource_count)
	if ($Opt::verbose > 2);
    $changed = 0;
    for($i = 0; $i < $erf->resource_count; $i++) {
	printf("Filename = %s.%s, type = %d, offset = %d, size = %d\n",
	       $erf->resource_reference($i),
	       $erf->resource_extension($i),
	       $erf->resource_type($i),
	       $erf->resource_offset($i),
	       $erf->resource_size($i))
	    if ($Opt::verbose > 3);
	if (!defined($erf->resource_reference($i)) ||
	    !defined($erf->resource_extension($i)) ||
	    !defined($erf->resource_type($i)) ||
	    $erf->resource_reference($i) eq "" ||
	    $erf->resource_extension($i) eq "") {
	    die "Found filename `" .
		$erf->resource_reference($i) . "' with type " .
		$erf->resource_type($i) . " with size = " .
		$erf->resource_size($i) . " (offset = " .
		$erf->resource_offset($i) ."), skipped";
	}
	if ($erf->resource_extension($i) eq 'dlg') {
	    my($gff);
	    $gff = GffRead::read(data => $erf->resource_data($i));
	    if (!defined($gff)) {
		die "Cannot read " . $erf->resource_reference($i) . "." .
		    $erf->resource_extension($i);
	    }
	    if ($$gff{MPCutscene} == 1) {
		$$gff{MPCutscene} = 0;
		$changed++;
		$erf->resource_data($i, GffWrite::write($gff));
	    }
	}
    }
    if ($changed > 0) {
	print("Writing $module.new...\n")
	    if ($Opt::verbose > 1);
	&ErfWrite::write($erf, 'filename' => $module . ".new");
#	rename($module, $module . ".bak") ||
#	    die "Rename of old failed: $!";
#	rename($module . ".new", $module) ||
#	    die "Rename of new failed: $!";
	printf("Wrote $module.new, modified %d conversations " .
	       "wrote %d resources\n",
	       $changed, $erf->resource_count())
	    if ($Opt::verbose);
    } else {
	printf("No conversations to be converted, skipped\n")
	    if ($Opt::verbose);
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

mpcutsceneconv - Disable MPCutscene conversations

=head1 SYNOPSIS

erfpack [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [I<filename> ...]

mpcutsceneconv B<--help>

=head1 DESCRIPTION

B<mpcutsceneconv> takes module, and converts each conversation inside
it so that it disables the MPCutscene setting. The new module is
created with .new extension and you need to manually rename it to have
proper name. By default it will fix all modules in the current
directory.

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

=back

=head1 EXAMPLES

    mpcutsceneconv
    mpcutsceneconv foo.mod
    mpcutsceneconv *.mod

=head1 FILES

=over 6

=item ~/.mpcutsceneconvrc

Default configuration file.

=back

=head1 SEE ALSO

erfpack(1), erfunpack(1), gffmodify(1), Gff(3), GffRead(3),
GffWrite(3), Erf(3), ErfRead(3) and ErfWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.
