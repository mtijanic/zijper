#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# export-shops.pl -- Export shops
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: export-shops.pl
#	  $Source: /u/samba/nwn/bin/RCS/export-shops.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 13:36 Jul  2 2005 kivinen
#	  Last Modification : 01:23 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:23:31 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.43
#	  Edit time	    : 20 min
#
#	  Description       : Export shops on area
#
#	  $Log: export-shops.pl,v $
#	  Revision 1.2  2007/05/23 22:23:31  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2005/07/06 11:14:13  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package ExportShops;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;
use ErfWrite;
use Erf;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::output = 0;
$Opt::verbose = 0;

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
    read_rc_file("$ENV{'HOME'}/.exportshopsrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"help|h" => \$Opt::help,
		"output|o=s" => \$Opt::output,
		"verbose|v+" => \$Opt::verbose,
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

$main::erf = new Erf;
my($gff);

if (!defined($Opt::output)) {
    die "No output file given";
}

$main::erf->file_type('ERF ');

$t0 = time();
foreach $i (@ARGV) {
    $main::file = $i;
    if ($Opt::verbose > 1) {
	print("Reading file $i\n");
    }
    $gff = GffRead::read(filename => $i);
    $gff->find(find_label =>
		       '^/StoreList\[\d+\]/StoreList\[\d+\]/ItemList\[\d+\]/$',
	       proc => \&export_item);
}
if ($Opt::verbose) {
    printf("Reading done, %g seconds\n", time() - $t0);
}

&ErfWrite::write($main::erf, filename => $Opt::output);

if ($Opt::verbose) {
    printf("Write done, %g seconds\n", time() - $t0);
}

exit 0;

######################################################################
# export_item

sub export_item {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($filename, $data, $new_gff);

    $new_gff = $gff->copy_to_top('UTI ', 'V3.2');
    $filename = $$new_gff{TemplateResRef} . ".uti";

    if (defined($main::resources{$filename})) {
	if ($main::resources{$filename} == 1) {
	    warn
		"File $filename already added to erf, skipped later instances";
	}
	$main::resources{$filename}++;
    } else {
	$main::resources{$filename} = 1;
	if ($Opt::verbose > 2) {
	    print("Adding file $filename from $main::file\n");
	}
    }
    $data = &GffWrite::write($new_gff);
    $main::erf->new_file($filename, $data);
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

export-shops - Export shops on the area

=head1 SYNOPSIS

export-shops [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    B<--output>|B<-o> I<output filename>
    I<filename> ...

export-shops B<--help>

=head1 DESCRIPTION

B<export-shops> takes a area and creates an erf, having all the items
on all the shops on the area. If there is multiple copies of the same
item in teh shops, then only the first one is stored to the erf, and
rest are ignored.

The output is written to given file. 
    
=head1 OPTIONS

=over 4

=item B<--help> B<-h>

Prints out the usage information.

=item B<--version> B<-V>

Prints out the version information. 

=item B<--verbose> B<-v>

Enables the verbose prints. 

=item B<--config> I<config-file>

All options given by the command line can also be given in the
configuration file. This option is used to read another configuration
file in addition to the default configuration file. 

=item B<--output> B<-o> I<output filename>

Output erf file, where the output is written. 

=back

=head1 EXAMPLES

    export-shops -o market.erf cereacentral.git

=head1 FILES

=over 6

=item ~/.exportshopsrc

Default configuration file.

=back

=head1 SEE ALSO

gffprint(1), gffencode(1), gffmodify(1), Gff(3), GffRead(3), Erf(3),
and ErfWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was added to make it easy to export items from shops on
the area to erfs.
