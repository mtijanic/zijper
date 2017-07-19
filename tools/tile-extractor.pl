#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# tile-extractor.pl -- Extract tiles from tileset files
# Copyright (c) 2005 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: tile-extractor.pl
#	  $Source: /u/samba/nwn/bin/RCS/tile-extractor.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 12:42 Sep 29 2005 kivinen
#	  Last Modification : 01:28 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:28:35 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.153
#	  Edit time	    : 81 min
#
#	  Description       : Extract tiles from tileset files
#
#	  $Log: tile-extractor.pl,v $
#	  Revision 1.2  2007/05/23 22:28:35  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2005/10/11 15:26:37  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package TileExtractor;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Key;
use KeyRead;
use Gff;
use GffRead;
use GffWrite;
use SetRead;
use Time::HiRes qw(time);
use Pod::Usage;

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
    read_rc_file("$ENV{'HOME'}/.tileextractorrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"nwn|n=s" => \$Opt::nwn_path,
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

my($i, $j, $t0, @key_files, $key, $filename);

push(@key_files, bsd_glob($Opt::nwn_path . "/*.key"));

foreach $i (@key_files) {
    $t0 = time();
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $key = KeyRead::read(filename => $i,
			 path => $Opt::nwn_path);
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    for($j = 0; $j < $key->key_count; $j++) {
	$filename = $key->resource_reference($j) . "." .
	    $key->resource_extension($j);
	if ($filename =~ /\.set$/) {
	    $TileExtractor::tiles{$key->resource_reference($j)} =
		SetRead::parse($key->resource_data($j));
	}
    }
}

# foreach $i (keys %TileExtractor::tiles) {
#    my($tcnt, $ccnt, $name);
#    $tcnt = $TileExtractor::tiles{$i}{'TERRAIN TYPES'}{Count};
#    $ccnt = $TileExtractor::tiles{$i}{'CROSSER TYPES'}{Count};
#    print("Tile = $i, tcnt = $tcnt, ccnt = $ccnt\n");
#    
#    for($j = 0; $j < $tcnt; $j++) {
#	$name = $TileExtractor::tiles{$i}{'TERRAIN' . $j}{Name};
#	if ($name !~ /^(Water|Cliff|Rock|Trees|Forest|Building|EvilCastle|GoodCastle|Svirfneblin|Drow|Poor|Pit|Chasm|Chasym|Lava|Floor|Plaza|Rich|Library|Jail|Stone|Livingroom|Kitchen|Inn|Shop|Cobble|Storage|Desert|Snow|Grass|floor|Floor2|2x2|Wall|wall)$/) {
#	    print("Terrain $j ", $name, "\n");
#	}
#    }
#    for($j = 0; $j < $ccnt; $j++) {
#	$name = $TileExtractor::tiles{$i}{'CROSSER' . $j}{Name};
#	if ($name !~ /^(Bridge|Corridor|Doorway|Tracks|Road|Alley|Door|Dock|Wall|Wall1|Wall2|Fence|Stream|Trench)$/) {
#	    print("Corrser $j ", $name, "\n");
#	}
#    }
#
#}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

my($tileset, $tile, $gff, $tile_list, $tl, $tr, $bl, $br, $l, $r, $t, $b);
my($width, $height, $file);
foreach $i (@ARGV) {
    $file = $i;
    $file =~ s/\..*//g;
    if ($Opt::verbose) {
	print("Reading file $file.are...\n");
    }
    $t0 = time();
    $gff = GffRead::read(filename => $file . ".are");
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    $tileset = $$gff{Tileset};
    $width = $$gff{Width};
    $height = $$gff{Height};

#    print("Tileset = $tileset $width x $height\n");

    # Terrains
    # Water = /Water/
    # Stone = /Cliff|Rock/
    # Tree = /Trees|Forest/
    # Building = /Building|EvilCastle|GoodCastle|Svirfneblin|Drow|Poor/
    # Pit = /Pit|Chasm|Chasym|Lava/
    # Floor = /Floor|Plaza|Rich|Library|Jail|Stone|Livingroom|Kitchen|
    #          Inn|Shop|Cobble|Storage|Desert|Snow|Grass|floor|Floor2|2x2/
    # Wall = /Wall|wall/

    # Crossers
    # Road = /Bridge|Corridor|Doorway|Tracks|Road|Alley|Door|Dock/
    # Wall = /Wall|Wall1|Wall2|Fence/
    # Stream = /Stream|Trench/

    my($water, $road, $stone, $trees, $blocked, $val, $var);
    $var = "";
    $tile_list = $$gff{Tile_List};
    foreach $j (@{$tile_list}) {
	$tile = $$j{Tile_ID};
	$tl = $TileExtractor::tiles{$tileset}{'TILE' . $tile}{TopLeft};
	$tr = $TileExtractor::tiles{$tileset}{'TILE' . $tile}{TopRight};
	$bl = $TileExtractor::tiles{$tileset}{'TILE' . $tile}{BottomLeft};
	$br = $TileExtractor::tiles{$tileset}{'TILE' . $tile}{BottomRight};
	$t = $TileExtractor::tiles{$tileset}{'TILE' . $tile}{Top};
	$b = $TileExtractor::tiles{$tileset}{'TILE' . $tile}{Bottom};
	$r = $TileExtractor::tiles{$tileset}{'TILE' . $tile}{Right};
	$l = $TileExtractor::tiles{$tileset}{'TILE' . $tile}{Left};

	# Check if we have water
	$water = ($tl =~ /^Water$/) + ($tr =~ /^Water$/) +
	    ($bl =~ /^Water$/) + ($br =~ /^Water$/) +
	    ($t =~ /^Stream$/) + ($b =~ /^Stream$/) +
	    ($r =~ /^Stream$/) + ($l =~ /^Stream$/);
	$road =
	    ($t =~ /^(Bridge|Corridor|Doorway|Tracks|Road|Alley|Door|Dock)$/) +
	    ($b =~ /^(Bridge|Corridor|Doorway|Tracks|Road|Alley|Door|Dock)$/) +
	    ($r =~ /^(Bridge|Corridor|Doorway|Tracks|Road|Alley|Door|Dock)$/) +
	    ($l =~ /^(Bridge|Corridor|Doorway|Tracks|Road|Alley|Door|Dock)$/);
	$stone = ($tl =~ /^(Cliff|Rock)$/) + ($tr =~ /^(Cliff|Rock)$/) + # 
	    ($bl =~ /^(Cliff|Rock)$/) + ($br =~ /^(Cliff|Rock)$/);
	$trees = ($tl =~ /^(Trees|Forest)$/) + ($tr =~ /^(Trees|Forest)$/) + # 
	    ($bl =~ /^(Trees|Forest)$/) + ($br =~ /^(Trees|Forest)$/);
	$blocked =
	    ($tl =~ /^(Water|Cliff|Trees|Building|EvilCastle|GoodCastle|Svirfneblin|Drow|Poor|Wall|wall|Pit|Chasm|Chasym|Lava)$/) +
	    ($tr =~ /^(Water|Cliff|Trees|Building|EvilCastle|GoodCastle|Svirfneblin|Drow|Poor|Wall|wall|Pit|Chasm|Chasym|Lava)$/) +
	    ($bl =~ /^(Water|Cliff|Trees|Building|EvilCastle|GoodCastle|Svirfneblin|Drow|Poor|Wall|wall|Pit|Chasm|Chasym|Lava)$/) +
	    ($br =~ /^(Water|Cliff|Trees|Building|EvilCastle|GoodCastle|Svirfneblin|Drow|Poor|Wall|wall|Pit|Chasm|Chasym|Lava)$/) +
	    ($t =~ /^(Wall|Wall1|Wall2|Fence)$/) +
	    ($b =~ /^(Wall|Wall1|Wall2|Fence)$/) +
	    ($r =~ /^(Wall|Wall1|Wall2|Fence)$/) +
	    ($l =~ /^(Wall|Wall1|Wall2|Fence)$/);
	
#	print("Tile = $tile $tl $tr $bl $br $t $b $r $l $water $road $stone $trees\n");
	$water = 1 if ($water);
	$road = 1 if ($road);
	$stone = 1 if ($stone);
	$trees = 1 if ($trees);
	$blocked = 1 if ($blocked);

	$val = $water | ($road << 1) | ($stone << 2) | ($trees << 3) |
	    ($blocked << 4);
	$var .= substr("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", $val, 1);
    }
    
    if ($Opt::verbose) {
	print("Reading file $file.git...\n");
    }
    $t0 = time();
    $gff = GffRead::read(filename => $file . ".git");
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
#    print("/VarTable/Name: TileSet\n");
#    print("/VarTable/Value: $tileset\n");
#    print("/VarTable/Name: Width\n");
#    print("/VarTable/Value: $width\n");
#    print("/VarTable/Name: Height\n");
#    print("/VarTable/Value: $height\n");
#    print("/VarTable/Name: Tiles\n");
#    print("/VarTable/Value: $var\n");

    $gff->variable('TileSet', $tileset, 3);
    $gff->variable('Width', $width, 1);
    $gff->variable('Height', $height, 1);
    $gff->variable('Tiles', $var, 3);

    if ($Opt::verbose) {
	print("Writing file $file.git...\n");
    }
    $t0 = time();
    &GffWrite::write($gff, filename => $file . ".git");
    if ($Opt::verbose) {
	printf("Write done, %g seconds\n", time() - $t0);
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

tile-extractor - Extract tile information from area files

=head1 SYNOPSIS

tile-extractor [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--nwn>|B<-n> I<nwn-install-dir>]
    I<filename> ...

tile-extractor B<--help>

=head1 DESCRIPTION

B<tile-extractor> extracts the tile set and tile information from the
are-file, and then stores the information in to a variable in the
area. 

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

=item B<--nwn> B<-n> I<nwn-install-dir>

Path to the NWN install directory. This should point to the directory
having the *.key files, and also the data directory having all the bif
files. 

=back

=head1 EXAMPLES

    tile-extractor vesperlake.are

=head1 FILES

=over 6

=item ~/.tileextractorrc

Default configuration file.

=back

=head1 SEE ALSO

gffencode(1), gffmodify(1), Key(3), KeyRead(3), SetRead(3),
Gff(3), GffWrite(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Created to make possible to get inforamtion if any tiles have water or
stone or roads, so we can make scripts to walk along the roads, or
mine metals anywhere where there is stones or cut woods, anywhere
there is trees. 
