#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# import-texts.pl -- Imports localized string texts back to the module
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: import-texts.pl
#	  $Source: /u/samba/nwn/bin/RCS/import-texts.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 16:30 May 30 2007 kivinen
#	  Last Modification : 03:20 Jun  8 2007 kivinen
#	  Last check in     : $Date: 2007/06/08 00:24:40 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.63
#	  Edit time	    : 59 min
#
#	  Description       : Imports localized string texts back to the 
#			      module 
#
#	  $Log: import-texts.pl,v $
#	  Revision 1.2  2007/06/08 00:24:40  kivinen
#	  	Added support for selecting language and gender.
#
#	  Revision 1.1  2007/05/30 15:20:36  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package ImportTexts;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use ErfRead;
use ErfWrite;
use Erf;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::input_texts = undef;
$Opt::output_module = undef;
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
    read_rc_file("$ENV{'HOME'}/.importtextsrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"texts|t=s" => \$Opt::input_texts,
		"output|o=s" => \$Opt::output_module,
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

if (!defined($Opt::input_texts)) {
    $Opt::input_texts = "-";
}
open(FILE, "<$Opt::input_texts") ||
    die "Opening input text file $Opt::input_texts failed: $!";

my(@resources, $txt);
while (<FILE>) {
    # Check if we start new resource.
    if (/^\[.*\]\\?$/ && defined($txt)) {
	# Yes.
	$txt =~ tr/\015//d;
	$txt =~ s/\n$//s;
	$txt =~ s/\n/\r\n/g;
	foreach $i (@resources) {
	    $ImportTexts::resources{$i} = $txt;
	}
	@resources = ();
	undef $txt;
    }
    if (!defined($txt)) {
	if (/^(\[.*\])(\\?)$/) {
	    push(@resources, $1);
	    if (!defined($2) || $2 eq '') {
		$txt = '';
	    }
	}
    } else {
	$txt .= $_;
    }
}

$txt =~ tr/\015//d;
$txt =~ s/\n$//s;
$txt =~ s/\n/\r\n/g;
foreach $i (@resources) {
    $ImportTexts::resources{$i} = $txt;
}

process_files(@ARGV);

exit 0;

######################################################################
# Process files

sub process_files {
    my(@files) = @_;
    my($i, $ret);
    
    print("Processing files: ", join(", ", @files), "\n")
	if ($Opt::verbose);
    foreach $i (@files) {
	if (-d $i) {
	    process_files(bsd_glob($i . "/*"));
	} elsif ($i =~ /\.mod$/i) {
	    my($erf, $j, $file);
	    
	    $erf = ErfRead::read('filename' => $i);
	    for($j = 0; $j < $erf->resource_count; $j++) {
		$ret =
		    process_file($erf->resource_reference($j) . "." .
				 $erf->resource_extension($j),
				 $erf->resource_data($j));
		if (defined($ret)) {
		    $erf->resource_data($j, $ret);
		}
	    }
	    if (defined($Opt::output_module)) {
		$file = $Opt::output_module;
	    } else {
		$file = $i;
	    }
	    print("Writing $file...\n")
		if ($Opt::verbose);
	    &ErfWrite::write($erf, 'filename' => $file . ".new");
	    unlink($file . ".old");
	    rename($file, $file . ".old");
	    rename($file . ".new", $file) ||
		die "Rename of new failed: $!";
	    printf("Finished writing %s, wrote %d resources\n",
		   $file, $erf->resource_count())
		if ($Opt::verbose);
	    undef $erf;
	} else {
	    $ret = process_file($i);
	    if (defined($ret)) {
		print("Writing $i...\n")
		    if ($Opt::verbose);
		open(FILE, ">$i") || die "Cannot open $i: $!";
		binmode(FILE);
		print(FILE $ret);
		close(FILE);
		print("Finished writing $i, wrote %1 resources\n")
		    if ($Opt::verbose);
	    }
	}
    }
    print("Done processing files: ", join(", ", @files), "\n")
	if ($Opt::verbose);
}

######################################################################
# Process file 

sub process_file {
    my($i, $data) = @_;
    my($gff);

    $t0 = time();
    $main::file = $i;
    $main::file =~ s/^.*[\\\/]//g;

    return undef
	if ($i =~ /.(trx|trn|ncs|ndb|nss|2da|tlk|sef|pfx|lfx|bfx|ifx|nwm)$/i);
    if ($Opt::verbose > 2) {
	print(STDERR "Reading file $i...\n");
    }
    if (defined($data)) {
	$gff = GffRead::read(data => $data);
    } else {
	$gff = GffRead::read(filename => $i);
    }
    if ($Opt::verbose > 3) {
	printf(STDERR "Read done, %g seconds\n", time() - $t0);
    }
    $ImportTexts::modified = 0;
    $gff->find(find_type => { 12 => 1},
	       proc => \&find_proc);
    if ($ImportTexts::modified) {
	return GffWrite::write($gff);
    }
    return undef;
}

######################################################################
# Find proc
sub find_proc {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($key);

    $key = "[" . $main::file . $full_label . "]";
    return if (!defined($ImportTexts::resources{$key}));
    print(STDERR "$key: Found $full_label, label = $label\n")
	if ($Opt::verbose > 4);
    if (defined($gff->value($label))) {
	if (defined($gff->value($label . "/" . $Opt::lang_code))) {
	    my($val) = $gff->value($label . "/" . $Opt::lang_code);
	    if ($val ne $ImportTexts::resources{$key}) {
		printf(STDERR "%s: Replacing %s with %s\n", $key,
		       $val, $ImportTexts::resources{$key})
		    if ($Opt::verbose > 1);
		$gff->value($label . "/" . $Opt::lang_code,
			    $ImportTexts::resources{$key});
		$ImportTexts::modified = 1;
	    }
	} else {
	    printf(STDERR "%s: Adding %s\n", $key,
		   $ImportTexts::resources{$key})
		if ($Opt::verbose > 1);
	    $gff->value($label . "/" . $Opt::lang_code,
			$ImportTexts::resources{$key});
	    $ImportTexts::modified = 1;
	}
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

import-texts - Import texts back to the module

=head1 SYNOPSIS

import-texts [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--output>|B<-o> I<outputmodule.mod>]
    [B<--texts>|B<-t> I<textfile.txt>]
    [B<--language>|B<-l> I<language-name>]
    [B<--gender>|B<-g> I<gender>]
    [B<--languagecode>|B<-L> I<language-code-number>]
    I<filename> ...

import-texts B<--help>

=head1 DESCRIPTION

B<import-texts> reads in the text file generated by B<export-texts>
and imports those texts back to the module. If B<--output> option is
given and module is in module mode, then output is written to that
file. If input is directory mode, then B<--output> option is ignored
and files are modified inplace. If no B<--texts> option is given then
file is read from the stdin.

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

Language name of the language to where to import the text. Can either
be number or strings like 'English', 'French' etc.

=item B<--gender> B<-g> I<gender>

Gender where to import text. Can either be number or "Male", or
"Female".

=item B<--languagecode> B<-L> I<language-code-number>

Numeric code of the language where to import texts.

=item B<--config> I<config-file>

All options given by the command line can also be given in the
configuration file. This option is used to read another configuration
file in addition to the default configuration file. 

=item B<--output> B<-o> I<output-mod-file>

If input file was given in mod mode then write the output to this mod
file. If input was directory mode or individual files, then ignore
this option.

=item B<--texts> B<-t> I<input-txt-file>

Text input file to be imported to the module. This is normally
generated by B<export-texts> program and then edited. If this option
is not given then defaults to stdin. 

=back

=head1 EXAMPLES

    import-texts -t file.txt -o newmod.mod oldmod.mod
    import-texts moddirectory < texts.txt

=head1 FILES

=over 6

=item ~/.importtextsrc

Default configuration file.

=back

=head1 SEE ALSO

export-texts(1), gffprint(1), ErfRead(3), ErfWrite(3), Gffwrite(3),
Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was created to help Qk to make translations of modules to
different languages.
