#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# export-texts.pl -- Extract all localized string texts from the module
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: export-texts.pl
#	  $Source: /u/samba/nwn/bin/RCS/export-texts.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 21:42 May 23 2007 kivinen
#	  Last Modification : 03:05 Jun  8 2007 kivinen
#	  Last check in     : $Date: 2007/06/08 00:24:50 $
#	  Revision number   : $Revision: 1.6 $
#	  State             : $State: Exp $
#	  Version	    : 1.62
#	  Edit time	    : 62 min
#
#	  Description       : Extract all localized string texts from the
#			      module 
#
#	  $Log: export-texts.pl,v $
#	  Revision 1.6  2007/06/08 00:24:50  kivinen
#	  	Added support for selecting language and gender.
#
#	  Revision 1.5  2007/05/30 15:20:31  kivinen
#	  	Added removing of CR in output texts.
#
#	  Revision 1.4  2007/05/23 23:56:52  kivinen
#	  	Changed format and sorted entries.
#
#	  Revision 1.3  2007/05/23 23:27:57  kivinen
#	  	Added support for the module mode.
#
#	  Revision 1.2  2007/05/23 22:23:39  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2007/05/23 21:31:53  kivinen
#	  	Initial version.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package ExportTexts;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use ErfRead;
use Erf;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::lang_code = 0;

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
    read_rc_file("$ENV{'HOME'}/.exporttextsrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"language|l=s" => \$Opt::language,
		"gender|g=s" => \$Opt::gender,
		"languagecode|L=s" => \$Opt::lang_code,
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

if (defined($Opt::language)) {
    $Opt::lang_code = Gff::language($Opt::language, $Opt::gender);
} elsif (defined($Opt::gender)) {
    $Opt::lang_code = Gff::language($Opt::lang_code, $Opt::gender);
}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

process_files(@ARGV);

foreach $i (sort { $main::text{$a}[0] cmp $main::text{$b}[0]}
	    keys (%main::text)) {
    printf("%s\n%s\n",
	   join("\\\n", @{$main::text{$i}}),
	   $i);
}
exit 0;

######################################################################
# Process files

sub process_files {
    my(@files) = @_;
    my($i);
    
    foreach $i (@files) {
	if (-d $i) {
	    process_files(bsd_glob($i . "/*"));
	} elsif ($i =~ /\.mod$/i) {
	    my($erf, $j);
	    
	    $erf = ErfRead::read('filename' => $i);
	    for($j = 0; $j < $erf->resource_count; $j++) {
		process_file($erf->resource_reference($j) . "." .
			     $erf->resource_extension($j),
			     $erf->resource_data($j));
	    }
	} else {
	    process_file($i);
	}
    }
}

######################################################################
# Process file 

sub process_file {
    my($i, $data) = @_;
    my($gff);

    $t0 = time();
    $main::file = $i;
    $main::file =~ s/^.*[\\\/]//g;

    return
	if ($i =~ /.(trx|trn|ncs|ndb|nss|2da|tlk|sef|pfx|lfx|bfx|ifx|nwm)$/i);
    if ($Opt::verbose) {
	print(STDERR "Reading file $i...\n");
    }
    if (defined($data)) {
	$gff = GffRead::read(data => $data);
    } else {
	$gff = GffRead::read(filename => $i);
    }
    if ($Opt::verbose) {
	printf(STDERR "Read done, %g seconds\n", time() - $t0);
    }
    $gff->find(find_type => { 12 => 1},
	       proc => \&find_proc);
}

######################################################################
# Find proc
sub find_proc {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($item);
    
    if ($Opt::verbose > 4) {
	print(STDERR "Found structure $full_label, label = $label, value = $value\n");
    }
    if (defined($gff->value($label)) &&
	defined($gff->value($label . "/" . $Opt::lang_code))) {
	my($val) = $gff->value($label . "/" . $Opt::lang_code);
	$val =~ tr/\015//d;
	if (!defined($main::text{$val})) {
	    @{$main::text{$val}} = ();
	}
	push(@{$main::text{$val}}, "[" . $main::file . $full_label . "]");
    }
    return;
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
}

=head1 NAME

export-texts - Export texts from the module

=head1 SYNOPSIS

export-texts [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--language>|B<-l> I<language-name>]
    [B<--gender>|B<-g> I<gender>]
    [B<--languagecode>|B<-L> I<language-code-number>]
    [B<--config> I<config-file>]
    I<filename> ...

export-texts B<--help>

=head1 DESCRIPTION

B<export-texts> prints out text file having all texts from the module.
This can be used to translate them and then import them back to the
module using B<import-texts> script.

=head1 OPTIONS

=over 4

=item B<--help> B<-h>

Prints out the usage information.

=item B<--version> B<-V>

Prints out the version information. 

=item B<--verbose> B<-v>

Enables the verbose prints. This option can be given multiple times,
and each time it enables more verbose prints. 

=item B<--language> B<-l> I<language-name>

Language name of the language which text to export. Can either be
number or strings like 'English', 'French' etc.

=item B<--gender> B<-g> I<gender>

Gender whose text to export. Can either be number or "Male", or
"Female".

=item B<--languagecode> B<-L> I<language-code-number>

Numeric code of the language to select texts which to export.

=item B<--config> I<config-file>

All options given by the command line can also be given in the
configuration file. This option is used to read another configuration
file in addition to the default configuration file. 

=back

=head1 EXAMPLES

    export-texts *.ut* *.dlg *.git

=head1 FILES

=over 6

=item ~/.exporttextsrc

Default configuration file.

=back

=head1 SEE ALSO

import-texts(1), gffprint(1), Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was created to help Qk to make translations of modules to
different languages.
