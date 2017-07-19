#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# fixstrresref.pl -- Simple program to fix strresrefs
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: fixstrresref.pl
#	  $Source: /u/samba/nwn/bin/RCS/fixstrresref.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 07:04 Feb  3 2007 kivinen
#	  Last Modification : 01:26 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:26:04 $
#	  Revision number   : $Revision: 1.3 $
#	  State             : $State: Exp $
#	  Version	    : 1.55
#	  Edit time	    : 22 min
#
#	  Description       : Simple program to fix strresrefs
#
#	  $Log: fixstrresref.pl,v $
#	  Revision 1.3  2007/05/23 22:26:04  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.2  2007/05/23 20:02:37  kivinen
#	  	Updated to work for any localized string in the module. Added
#	  	skipping of non gff files.
#
#	  Revision 1.1  2007/02/03 05:26:47  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package Fixstrresref;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;
use TlkRead;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::dialog = "dialog.tlk";

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
    read_rc_file("$ENV{'HOME'}/.fixstrresrefrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"dialog|d=s" => \$Opt::dialog,
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

my($i, $t0, $tlk, $n);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

if (defined($Opt::dialog) && $Opt::dialog ne "") {
    $tlk = TlkRead::read(filename => $Opt::dialog);
    $i = $tlk->string_count - 1;
    while ($i > 0) {
	$Fixstrresref::tlk{$tlk->string($i)} = $i;
	$i--;
    }
}


foreach $i (@ARGV) {
    my($gff);
    $t0 = time();
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    next if ($i =~ /.(trx|trn|ncs|ndb|nss|2da|tlk|sef|pfx|lfx|bfx|ifx|nwm)$/i);
    $gff = GffRead::read(filename => $i);
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    $Fixstrresref::modified = 0;
    $gff->find(find_type => { 12 => 1},
	       proc => \&update_str_resref);
    if ($Fixstrresref::modified) {
	&GffWrite::write($gff, filename => $i);
    }
}

exit 0;

######################################################################
# Update strresref

sub update_str_resref {
    my($gff, $full_label, $name, $value, $parent_gffs) = @_;
    my($n, $lname);

    $lname = $name . "/0";
    if (defined($gff->value($lname)) && $gff->value($lname) ne '') {
	$n = $Fixstrresref::tlk{$gff->value($lname)};
	if (defined($n)) {
	    if ($n != $$gff{$name . '. ____string_ref'}) {
		printf("Updating %s strresref %d to %d\n",
		       $gff->value($lname), $$gff{$name . '. ____string_ref'},
		       $n);
		$$gff{$name . '. ____string_ref'} = $n;
		$Fixstrresref::modified = 1;
	    }
	} else {
	    if ($$gff{$name . '. ____string_ref'} != 4294967295) {
		printf("Clearing %s strresref %d\n",
		       $gff->value($lname), $$gff{$name . '. ____string_ref'});
		$$gff{$name . '. ____string_ref'} = 4294967295;
		$Fixstrresref::modified = 1;
	    }
	}
    }
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

fixstrresref - Simple program to fix strresrefs

=head1 SYNOPSIS

fixstrresref [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--dialog>|B<-d> I<filename.tlk>]
    I<filename> ...

fixstrresref B<--help>

=head1 DESCRIPTION

B<fixstrresref> checks out for item names and descriptions and checks
if their text and the strresref numbers match. If not it will change
the strresref to match the text field. If no matching strresref is
found then it is cleared.

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

=item B<--dialog> B<-d> I<filename.tlk>

Pointer to the tlk file. If not givem then dialog.tlk in the current
directory is assumed.

=back

=head1 EXAMPLES

    fixstrresref *.uti
    fixstrresref -d ../dialog.tlk *.uti

=head1 FILES

=over 6

=item ~/.fixstrresrefrc

Default configuration file.

=back

=head1 SEE ALSO

gffprint(1), gffencode(1), gffmodify(1), Tlk(3), Gff(3), GffWrite(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was created to fix and clear some item names which had
wrong strresrefs in the cerea2 module. 
