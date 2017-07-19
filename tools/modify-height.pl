#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# modify-height.pl -- Modify base height 
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: modify-height.pl
#	  $Source: /u/samba/nwn/bin/RCS/modify-height.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 12:18 Jul  1 2005 kivinen
#	  Last Modification : 01:27 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:27:48 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.27
#	  Edit time	    : 43 min
#
#	  Description       : Modify base height of map
#
#	  $Log: modify-height.pl,v $
#	  Revision 1.2  2007/05/23 22:27:48  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2005/07/06 11:16:11  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package ModifyHeight;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;
use Pod::Usage;

$Opt::height = 0;

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
    read_rc_file("$ENV{'HOME'}/.modifyheightrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"help|h" => \$Opt::help,
		"height|H=s" => \$Opt::height,
		"verbose|v" => \$Opt::verbose,
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

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

if ($Opt::height == 0) {
    die "Nothing to do, height = 0";
}

if (int($Opt::height) != $Opt::height) {
    die "Height needs to be integer number";
}

foreach $i (@ARGV) {
    $main::file = $i;
    if ($i =~ /^(.*)\.(git|gic|are)$/) {
	my($gff_are, $gff_git);
	my($base) = $1;
	$gff_are = GffRead::read(filename => $1 . ".are");
	$gff_git = GffRead::read(filename => $1 . ".git");
	$gff_are->find(find_label => '^/Tile_List\[\d+\]/$',
		   proc => \&modify_area);
	$gff_git->find(find_label =>
		       '^/(Door |Placeable |Creature |Sound|Waypoint|Store|)List\[\d+\]/$',
		   proc => \&modify_git);
	$gff_git->find(find_label =>
		       '^/(Trigger|Encounter )List\[\d+\]/Geometry\[\d+\]/$',
		   proc => \&modify_triggers);
	print("Writing $base.are back\n");
	&GffWrite::write($gff_are, filename => $base . ".are");
	print("Writing $base.git back\n");
	&GffWrite::write($gff_git, filename => $base . ".git");
    } else {
	die "Unknown file type $i";
    }
}

exit 0;

######################################################################
# modify_are

sub modify_area {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;

    $$gff{Tile_Height} += $Opt::height;
    printf("Modifying %s.are %s{Tile_Height} => %g\n",
	   $main::file, $full_label, $$gff{Tile_Height})
	if ($Opt::verbose);
    if ($$gff{Tile_Height} < 0 ||
	$$gff{Tile_Height} >= 32) {
	die "Height goes negative or too large: $$gff{Tile_Height}";
    }
}


######################################################################
# modify_git

sub modify_git {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;

    if (defined($$gff{Z})) {
	$$gff{Z} += $Opt::height * 5;
	printf("Modifying %s.git %s{Z} => %g\n",
	       $main::file, $full_label, $$gff{Z})
	    if ($Opt::verbose);
    }
    if (defined($$gff{ZPosition})) {
	$$gff{ZPosition} += $Opt::height * 5;
	printf("Modifying %s.git %s{ZPosition} => %g\n",
	       $main::file, $full_label, $$gff{ZPosition})
	    if ($Opt::verbose);
    }
    
}

######################################################################
# modify_triggers

sub modify_triggers {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;

    if (defined($$gff{PointZ})) {
	$$gff{PointZ} += $Opt::height * 5;
	printf("Modifying %s.git %s{PointZ} => %g\n",
	       $main::file, $full_label, $$gff{PointZ})
	    if ($Opt::verbose);
    }
    if (defined($$gff{Z})) {
	$$gff{Z} += $Opt::height * 5;
	printf("Modifying %s.git %s{Z} => %g\n",
	       $main::file, $full_label, $$gff{Z})
	    if ($Opt::verbose);
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

modify-height - Modify height of area

=head1 SYNOPSIS

modify-height [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--height>|B<-H> I<height modification as integer steps>]
    I<filename> ...

modify-height B<--help>

=head1 DESCRIPTION

B<modify-height> takes a area and modifies the height of the all tiles
in the area and all creatures, doors, placeables, items, sounds,
waypoints, stores, encounters and triggers in the git-file. The height
given to it, must be integer number which is added to the current
height. It can be negative to lower the level, but the final tile
height cannot be negative or over 32.

I<filename> can be either git, gic or are file, and the
B<modify-height> will process both git and are files.

The output is written so that it overwrites the given files. 
    
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

=item B<--height> B<-H> I<height>

Set the value to be added to the height. The value must be integer
value from -31 to 31. It specifies the number of steps the tile is
moved up (positive) or down (negative). Each step in the tile is 5
meters in the placeables and other objects.

=back

=head1 EXAMPLES

    modify-height -H 2 vesperlake.git

=head1 FILES

=over 6

=item ~/.modifyheightrc

Default configuration file.

=back

=head1 SEE ALSO

gffprint(1), gffencode(1), gffmodify(1), Gff(3), GffRead(3), and GffWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was added because we needed to combine few areas which
are not on the same level. Cut & paste of the areas of different level
do work, but all doors are on wrong height after that. 
