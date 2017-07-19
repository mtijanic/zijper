#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# tlkprint.pl -- Simple program to print BioWare Tlk files
# Copyright (c) 2005 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: tlkprint.pl
#	  $Source: /u/samba/nwn/bin/RCS/tlkprint.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 11:56 Oct 25 2005 kivinen
#	  Last Modification : 01:28 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:28:48 $
#	  Revision number   : $Revision: 1.3 $
#	  State             : $State: Exp $
#	  Version	    : 1.75
#	  Edit time	    : 46 min
#
#	  Description       : Simple program to print BioWare Tlk files
#
#	  $Log: tlkprint.pl,v $
#	  Revision 1.3  2007/05/23 22:28:48  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.2  2007/01/02 23:21:16  kivinen
#	  	Added --long and --safe options. Changed output routines.
#
#	  Revision 1.1  2005/10/27 17:08:16  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package TlkPrint;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use TlkRead;
use Tlk;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::separator = ":\t";
$Opt::only_string = 0;
$Opt::no_labels = 0;
$Opt::long = 0;
$Opt::safe = 0;

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
    read_rc_file("$ENV{'HOME'}/.tlkprintrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"only-string|o" => \$Opt::only_string,
		"no-labels|l" => \$Opt::no_labels,
		"separator|s=s" => \$Opt::separator,
		"long|L" => \$Opt::long,
		"safe|S" => \$Opt::safe,
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

my($i, $t0);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    my($tlk);
    $t0 = time();
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $tlk = TlkRead::read(filename => $i);
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    if (!$Opt::only_string) {
	output("File_type", -1, $tlk->file_type);
	output("File_version", -1, $tlk->file_version);
	output("Language_ID", -1, $tlk->language_id);
	output("String_count", -1, $tlk->string_count);
    }
    for($i = 0; $i < $tlk->string_count; $i++) {
	if ($Opt::no_labels) {
	    output("", $i, $tlk->string($i), 0);
	} else {
	    output("Text", $i, $tlk->string($i), 0);
	}
	if (!$Opt::only_string) {
	    my(%string);
	    %string = $tlk->string_info($i);
	    if ($string{Flags} != 1 || $Opt::long || $tlk->string($i) eq '') {
		output("Flags", $i, "0x" . $string{Flags});
	    }
	    if ($string{SoundResRef} ne '' || $Opt::long) {
		output("SoundResRef", $i, $string{SoundResRef});
	    }
	    if ($string{VolumeVariance} != 0 || $Opt::long) {
		output("VolumeVariance", $i, $string{VolumeVariance});
	    }
	    if ($string{PitchVariance} != 0 || $Opt::long) {
		output("PitchVariance", $i, $string{PitchVariance});
	    }
	    if ($Opt::long) {
		output("OffsetToString", $i, $string{OffsetToString});
	    }
	    if (!$Opt::safe) {
		output("StringSize", $i, $string{StringSize});
	    }
	    if ($string{SoundLength} != 0 || $Opt::long) {
		output("SoundLength", $i, $string{SoundLength});
	    }
	}
    }
}

exit 0;

######################################################################
# output($header, $index, $data)

sub output {
    my($header, $index, $data, $no_labels) = @_;
    $no_labels = $Opt::no_labels if (!defined($no_labels));
    if ($index != -1) {
	printf("[%d]%s%s", $index, $header, $Opt::separator) if (!$no_labels);
    } else {
	printf("%s%s", $header, $Opt::separator) if (!$no_labels);
    }
    if ($Opt::safe) {
	$data =~ s/([\000-\037\177-\377%])/"%" . unpack("H2", $1)/ge;
    }
    printf("%s\n", $data);
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
    Pod::Usage::pod2usage(0);
    exit(0);
}

=head1 NAME

tlkprint - Print Tlk structures

=head1 SYNOPSIS

tlkprint [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--only-strings>|B<-o>]
    [B<--no-labels>|B<-l>]
    [B<--long>|B<-L>]
    [B<--safe>|B<-S>]
    [B<--separator>|B<-s> I<separator>]
    I<filename> ...

tlkprint B<--help>

=head1 DESCRIPTION

B<tlkprint> prints tlk structures to human readable or machine
editable format. 

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

=item B<--only-strings> B<-l>

Do not print extra information, only the string table.

=item B<--no-labels> B<-l>

Do not print labels for fields.

=item B<--long> B<-L>

Long format, print all fields (even unused ones). 

=item B<--safe> B<-S>

Safe format, i.e. encode all control etc characters with %xx encoding. 

=item B<--separator> B<-s> I<separator>

Use the given string as a separator between the label and value
instead of default I<:\t>.

=back

=head1 EXAMPLES

    tlkprint dialog.tlk

=head1 FILES

=over 6

=item ~/.tlkprintrc

Default configuration file.

=back

=head1 SEE ALSO

gffprint(1), Tlk(3), and TlkRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Created in vugth when I realized that the Text fields quite often do
have string ref that I can use to convert the name to strings by using
the tlk files.
