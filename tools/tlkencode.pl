#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# tlkencode.pl -- Simple program to encode BioWare tlk files
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: tlkencode.pl
#	  $Source: /u/samba/nwn/bin/RCS/tlkencode.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 23:51 Jan  2 2007 kivinen
#	  Last Modification : 01:28 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:28:41 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.48
#	  Edit time	    : 21 min
#
#	  Description       : Simple program to encode BioWare Tlk files
#
#	  $Log: tlkencode.pl,v $
#	  Revision 1.2  2007/05/23 22:28:41  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2007/01/02 23:20:50  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package TlkEncode;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Tlk;
use TlkWrite;
use Pod::Usage;

$Opt::verbose = 0;
$Opt::separator = ":\t";

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
    read_rc_file("$ENV{'HOME'}/.tlkencoderc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"output|o=s" => \$Opt::output_filename,
		"separator|s=s" => \$Opt::separator,
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

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv, $i);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

my($tlk, $index, $label, $value, %temp, $prev_index);

$tlk = Tlk->new();

if (!defined($Opt::output_filename) || $Opt::output_filename eq "") {
    die "Output file name not given";
}

$prev_index = 0;
while (<>) {
    chomp;
    if (/^\[(\d+)\]([^$Opt::separator]*)$Opt::separator(.*)$/) {
	# Actual string item.
	$index = $1;
	$label = $2;
	$value = $3;
	$value =~ s/\%([0-9a-fA-f][0-9a-fA-f])/pack("H*", $1)/ge;
	if ($label eq 'Flags') {
	    $value = oct $value if ($value =~ /^0/);
	}
	if ($index != $prev_index) {
	    $tlk->string($prev_index, $temp{Text});
	    delete $temp{Text};
	    $tlk->string_info($prev_index, %temp);
	    %temp = ();
	}
	$prev_index = $index;
	$temp{$label} = $value;
    } elsif (/^([^$Opt::separator]*)$Opt::separator(.*)$/) {
	$label = $1;
	$value = $2;
	$value =~ s/\%([0-9a-fA-f][0-9a-fA-f])/pack("H*", $1)/ge;
	if ($label eq "File_type") {
	    $tlk->file_type($value);
	} elsif ($label eq "File_version") {
	    $tlk->file_version($value);
	} elsif ($label eq "Language_ID") {
	    $tlk->language_id($value);
	} elsif ($label eq "String_count") {
	    $tlk->string_count($value);
	} else {
	    die "Unknown label : $label";
	}
    } else {
	die "Parse error on line $_";
    }
}

$tlk->string($prev_index, $temp{Text});
delete $temp{Text};
$tlk->string_info($prev_index, %temp);

print("Writing file $Opt::output_filename out\n")
    if ($Opt::verbose);
&TlkWrite::write($tlk, filename => $Opt::output_filename);

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
    exit(0);
}

=head1 NAME

tlkencode - Encodes text version of tlk back to binary tlk

=head1 SYNOPSIS

tlkencode [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--separator>|B<-s> I<separator>]
    B<--output>|B<-o> I<output_filename>
    I<filename> ...

tlkencode B<--help>

=head1 DESCRIPTION

B<tlkencode> takes the output of tlkprint(1) and converts it back to
the binary tlk. The tlkprint(1) output must be generated with B<-S>
option so that it has all control characters encoded as %xx.

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

=item B<--output> B<-o> I<output_file>

Resulting binary tlk is written to this file. 

=item B<--separator> B<-s> I<separator>

Assume that the input file is using given string as a separator
between the label and value instead of default I<:\t>.

=back

=head1 EXAMPLES

    tlkprint -S dialog.tlk > file; emacs file; tlkencode -o dialog2.tlk file
    tlkprint -S dialog.tlk | sed 's/God/Deity/g' | tlkencode -o dialog2.tlk

=head1 FILES

=over 6

=item ~/.tlkencoderc

Default configuration file.

=back

=head1 SEE ALSO

tlkprint(1), Tlk(3), and TlkWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program appeared as a pair to the tlkprint(1) after we needed to
create our own custom tlk files. 

