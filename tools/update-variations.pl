#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# update-variations.pl -- Take the tiles.2da file and update variation counts
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: update-variations.pl
#	  $Source: /u/samba/nwn/bin/RCS/update-variations.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 00:40 Apr 24 2007 kivinen
#	  Last Modification : 01:29 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:29:29 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.61
#	  Edit time	    : 22 min
#
#	  Description       : Take the tiles.2da file and update
#			      variation counts
#
#	  $Log: update-variations.pl,v $
#	  Revision 1.2  2007/05/23 22:29:29  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2007/04/23 23:35:45  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package UpdateVariations;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Twoda;
use Pod::Usage;

$Opt::verbose = 0;
$Opt::output = undef;
$Opt::input = undef;

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
    read_rc_file("$ENV{'HOME'}/.updatevariationsrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"output|o=s" => \$Opt::output,
		"input|i=s" => \$Opt::input,
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

my($i);

if (!defined($Opt::input)) {
    die "Mandatory input argument missing";
}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}


my($tiles, %tiles);

foreach $i (@ARGV) {
    $i = lc($i);
    if ($i =~ /^tl_(..)_(....)_([0-9][0-9])\.mdb$/) {
	if (!defined($tiles{$1}) || !defined($tiles{$1}{$2})) {
	    $tiles{$1}{$2} = $3 + 0;
	} elsif ($tiles{$1}{$2} < $3) {
	    $tiles{$1}{$2} = $3 + 0;
	}
    }
}

$tiles = Twoda::read($Opt::input);
my($tileset, $type, $variations);
for($i = 0; $i <= $#{$$tiles{Data}}; $i++) {
    $tileset = lc($$tiles{Data}[$i]{TILESET});
    $type = lc($$tiles{Data}[$i]{TILE_TYPE});
    $variations = $$tiles{Data}[$i]{VARIATIONS};
    if (defined($tiles{$tileset}{$type})) {
	if ($tiles{$tileset}{$type} > $variations) {
	    if ($Opt::verbose) {
		printf("Updating variations for tile %s_%s from %d to %d\n",
		       $tileset, $type, $variations, $tiles{$tileset}{$type});
	    }
	    $$tiles{Data}[$i]{VARIATIONS} = $tiles{$tileset}{$type};
	}
    }
}

Twoda::write($tiles, $Opt::output);

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

update-variations - Take the tiles.2da file and update variation counts

=head1 SYNOPSIS

update-variations [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--input>|B<-i> I<inputfile>]
    [B<--output>|B<-i> I<outputfile>]
    I<filename> ...

update-variations B<--help>

=head1 DESCRIPTION

B<update-variations> will read the list of tiles and checks what is
the maximum number of variations for each tileset and for each tile
type in those files. Then it will read the tiles.2da input file and
update that so that the variations count is up to the max number seen
on the tile files. Finally it writes the new tiles.2da file out to the
disk. 

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

=item B<--input> B<-i> I<inputfile>

Input file name. Normally tiles.2da.

=item B<--output> B<-o> I<outputfile>

Output file name. Can be same as input i.e. tiles.2da or some new file
name.

=back

=head1 EXAMPLES

    update-variations -i tiles.2da -o tilesnew.2da *.mdb

=head1 FILES

=over 6

=item ~/.updatevariationsrc

Default configuration file.

=back

=head1 SEE ALSO

remove-roof(1), and Twoda(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was created as we needed to have some rooms without
roofs, as the creatures living is those rooms are so big that most of
the creature goes through the roof. As I didn't want to manually start
updating the tiles.2da file for each of those variations, I made this
program to update tiles.2da automatically. 
