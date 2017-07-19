#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# trngraph.pl -- Program to make graphics out of trn/trx files
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: trngraph.pl
#	  $Source: /u/samba/nwn/bin/RCS/trngraph.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 23:54 Jul 30 2007 kivinen
#	  Last Modification : 00:44 Aug 18 2007 kivinen
#	  Last check in     : $Date: 2007/08/17 21:46:29 $
#	  Revision number   : $Revision: 1.7 $
#	  State             : $State: Exp $
#	  Version	    : 1.449
#	  Edit time	    : 268 min
#
#	  Description       : Program to make graphics out of trn/trx files
#
#	  $Log: trngraph.pl,v $
#	  Revision 1.7  2007/08/17 21:46:29  kivinen
#	  	Fixed directional light argument checking.
#
#	  Revision 1.6  2007/08/17 01:18:15  kivinen
#	  	Added heightmap and directed light support. Changed to work
#	  	interior areas too. Changed height and width to do automatic
#	  	scaling instead of cropping. Added checking for water levels
#	  	when drawing water.
#
#	  Revision 1.5  2007/08/15 21:53:07  kivinen
#	  	Fixed typo.
#
#	  Revision 1.4  2007/08/15 21:45:59  kivinen
#	  	Added grid options.
#
#	  Revision 1.3  2007/08/15 20:28:13  kivinen
#	  	Added some documentation.
#
#	  Revision 1.2  2007/08/15 20:08:28  kivinen
#	  	Added binmode.
#
#	  Revision 1.1  2007/08/02 18:56:24  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package TrnGraph;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Trn;
use TrnRead;
use Pod::Usage;
use GD;
use Math::Vector;

$Opt::verbose = 0;
$Opt::output = undef;
$Opt::walkmesh = undef;
$Opt::walkable = undef;
$Opt::water = undef;
$Opt::terrain = 0;
$Opt::heightmap = '';
$Opt::colors = 0;
$Opt::x_size = 0;
$Opt::y_size = 0;
$Opt::scale = 1;
$Opt::crop_usable = 0;
$Opt::megatilegrid_color = undef;
$Opt::grid = 0;
$Opt::grid_color = undef;
$Opt::dir_light = undef;

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
    read_rc_file("$ENV{'HOME'}/.trngraphrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"output|o=s" => \$Opt::output,
		"width|W=s" => \$Opt::x_size,
		"height|H=s" => \$Opt::y_size,
		"scale|s=s" => \$Opt::scale,
		"walkmesh|w=s" => \$Opt::walkmesh,
		"walkable|a=s" => \$Opt::walkable,
		"water|A=s" => \$Opt::water,
		"megatilegrid|g=s" => \$Opt::megatilegrid_color,
		"grid|G=s" => \$Opt::grid_color,
		"gridscale|S=s" => \$Opt::grid,
		"heightmap|m=s" => \$Opt::heightmap,
		"terrain|t" => \$Opt::terrain,
		"colors|C" => \$Opt::colors,
		"crop|c" => \$Opt::crop_usable,
		"light|l=s" => \$Opt::dir_light,
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

my($trn, $res);
my($j, $x, $y, $image, $exterior, $tilesize);
my(@heightmap);

foreach $i (@ARGV) {
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $trn = TrnRead::read(filename => $i);
    if ($Opt::verbose) {
	printf("Read done\n");
    }
    printf("File $i, type = %s, version = %d.%02d\n",
	   $trn->file_type, $trn->version_major, $trn->version_minor)
	if ($Opt::verbose > 1);
    printf("Resource count = %d\n", $trn->resource_count)
	if ($Opt::verbose > 1);

    $exterior = 0;
    for($j = 0; $j < $trn->resource_count; $j++) {
	if ($trn->resource_type($j) eq 'TRWH') {
	    $res = $trn->decode($j, 1);
	    $x = $$res{'Width'};
	    $y = $$res{'Height'};
	}
	if ($trn->resource_type($j) eq 'TRRN') {
	    $exterior = 1;
	}
    }

    if ($exterior) {
	$tilesize = 40;
    } else {
	$tilesize = 9;
    }

    if ($Opt::x_size || $Opt::y_size) {
	if ($Opt::x_size) {
	    if ($Opt::crop_usable && $exterior) {
		$Opt::scale = $Opt::x_size / (($x - 4) * $tilesize);
	    } else {
		$Opt::scale = $Opt::x_size / ($x * $tilesize);
	    }
	} elsif ($Opt::y_size) {
	    if ($Opt::crop_usable && $exterior) {
		$Opt::scale = $Opt::y_size / (($y - 4) * $tilesize);
	    } else {
		$Opt::scale = $Opt::y_size / ($y * $tilesize);
	    }
	}
    }
    $x = $x * $tilesize * $Opt::scale;
    $y = $y * $tilesize * $Opt::scale;

    $image = new GD::Image($x, $y, 1);
    $image->alphaBlending(1);

    if (defined($Opt::dir_light)) {
	my(@dir_light, $len, @uv);
	@dir_light = split(/[,\s]/, $Opt::dir_light);
	if ($#dir_light < 2) {
	    die "Invalid number of values in light direction vector: "
		. "$Opt::dir_light";
	}
	@uv = Math::Vector->UnitVector(@dir_light);
	if (!defined($dir_light[3])) {
	    $dir_light[3] = 0.3;
	}
	if (!defined($dir_light[4])) {
	    $dir_light[4] = 0.7;
	}
	@dir_light = (\@uv, $dir_light[3], $dir_light[4]);
	$Opt::dir_light = \@dir_light;
    }
    @heightmap = ();
    if ($Opt::terrain || $Opt::colors || $Opt::heightmap ne '') {
	for($j = 0; $j < $trn->resource_count; $j++) {
	    if ($trn->resource_type($j) eq 'TRRN') {
		$res = $trn->decode($j, 1);
		add_terrain($image, $res, $Opt::terrain, $Opt::colors,
			    lc($Opt::heightmap),
			    $Opt::dir_light);
		if (defined($Opt::water)) {
		    add_heights(\@heightmap, $res);
		}
	    }
	}
    }
    if (defined($Opt::water)) {
	for($j = 0; $j < $trn->resource_count; $j++) {
	    if ($trn->resource_type($j) eq 'WATR') {
		$res = $trn->decode($j, 1);
		add_water($image, $res, \@heightmap,
			  parse_color($Opt::water, "undef"));
	    }
	}
    }

    if (defined($Opt::walkmesh) || defined($Opt::walkable)) {
	for($j = 0; $j < $trn->resource_count; $j++) {
	    if ($trn->resource_type($j) eq 'ASWM') {
		$res = $trn->decode($j, 1);
		if (defined($Opt::walkmesh)) {
		    add_walkmesh($image, $res,
				 parse_color($Opt::walkmesh, "#008000c0"));
		}
		if (defined($Opt::walkable)) {
		    add_walkable($image, $res,
				 parse_color($Opt::walkable, "#808000c0"));
		}
	    }
	}
    }

    if ($Opt::grid != 0) {
	for($j = 0; $j < $x; $j += $Opt::scale * $Opt::grid) {
	    $image->line($j, 0, $j, $y,
			 parse_color($Opt::grid_color,
				     '#000000c0'));
	}
	for($j = 0; $j < $y; $j += $Opt::scale * $Opt::grid) {
	    $image->line(0, $j, $x, $j,
			 parse_color($Opt::grid_color,
				    '#000000c0'));
	}
    }

    if (defined($Opt::megatilegrid_color)) {
	for($j = 0; $j < $x; $j += $Opt::scale * $tilesize) {
	    $image->line($j, 0, $j, $y,
			 parse_color($Opt::megatilegrid_color,
				     '#ff000080'));
	}
	for($j = 0; $j < $y; $j += $Opt::scale * $tilesize) {
	    $image->line(0, $j, $x, $j,
			 parse_color($Opt::megatilegrid_color,
				     '#ff000080'));
	}
    }

    if ($Opt::crop_usable && $exterior) {
	my($image2);
	$x -= 160 * $Opt::scale;
	$y -= 160 * $Opt::scale;
	$image2 = new GD::Image($x, $y, 1);
	$image2->copy($image, 0, 0, 80 * $Opt::scale, 80 * $Opt::scale,
		      $x, $y);
	$image = $image2;
    }
    $image->flipVertical();
    
    if (!defined($Opt::output)) {
	print $image->png(7);
    } else {
	open(FILE, ">$Opt::output") ||
	    die "Cannot open $Opt::output for writing: $!";
	binmode(FILE);
	if ($Opt::output =~ /\.png/i) {
	    print FILE $image->png(7);
	} elsif ($Opt::output =~ /\.jpg/i) {
	    print FILE $image->jpeg(75);
	} elsif ($Opt::output =~ /\.gif/i) {
	    print FILE $image->gif();
	} elsif ($Opt::output =~ /\.gd/i) {
	    print FILE $image->gd();
	} elsif ($Opt::output =~ /\.gd2/i) {
	    print FILE $image->gd2();
	} elsif ($Opt::output =~ /\.wbmp/i) {
	    print FILE $image->wbmp();
	} else {
	    print FILE $image->png(7);
	}
	close(FILE);
    }
}

exit 0;

######################################################################
# Add walkmesh to picture

sub add_walkmesh {
    my($image, $res, $color) = @_;
    my($cnt, $i, $c, $poly);

    $cnt = $$res{'Triangle Count'};

    for($i = 0; $i < $cnt; $i++) {
	$poly = new GD::Polygon;
	foreach $c (@{$$res{'Triangles'}[$i]{'Corners'}{'i'}}) {
	    $poly->addPt($$res{'Points'}[$c]{x} * $Opt::scale,
			 $$res{'Points'}[$c]{y} * $Opt::scale);
	}
	$image->openPolygon($poly, $color);
    }
}

######################################################################
# Add walkable area to picture

sub add_walkable {
    my($image, $res, $color) = @_;
    my($cnt, $i, $c, $poly);

    $cnt = $$res{'Triangle Count'};

    for($i = 0; $i < $cnt; $i++) {
	next if (!($$res{'Triangles'}[$i]{'Flags%'} & 0x01));
	$poly = new GD::Polygon;
	foreach $c (@{$$res{'Triangles'}[$i]{'Corners'}{'i'}}) {
	    $poly->addPt($$res{'Points'}[$c]{x} * $Opt::scale,
			 $$res{'Points'}[$c]{y} * $Opt::scale);
	}
	$image->filledPolygon($poly, $color);
    }
}

######################################################################
# Add water area to picture

sub add_water {
    my($image, $res, $heightmap, $color) = @_;
    my($cnt, $i, $c, $poly, $x, $y, $water);

    $cnt = $$res{'Triangle Count'};
    if (!defined($color)) {
	$color =
	    $image->colorAllocateAlpha($$res{'Water Color'}{r} * 255,
				       $$res{'Water Color'}{g} * 255,
				       $$res{'Water Color'}{b} * 255,
				       0x40);
    }

    for($i = 0; $i < $cnt; $i++) {
	$water = 0;
	foreach $c (@{$$res{'Triangle'}{'Data'}[$i]{'Corners'}{'i'}}) {
	    $x = int($$res{'Vertex'}{'Data'}[$c]{XY1}{x} * 48 + 0.5);
	    $y = int($$res{'Vertex'}{'Data'}[$c]{XY1}{y} * 24 + 0.5);
	    next if ($x >= 48 || $y >= 24);
	    if (substr($$res{'Bitmap'}[$y], $x, 1) ne '1') {
		$water = 1;
	    }
	}
	if ($water) {
	    $poly = new GD::Polygon;
	    foreach $c (@{$$res{'Triangle'}{'Data'}[$i]{'Corners'}{'i'}}) {
		$x = int($$res{'Vertex'}{'Data'}[$c]{'Position'}{x} * 3 / 5 + 0.5);
		$y = int($$res{'Vertex'}{'Data'}[$c]{'Position'}{y} * 3 / 5 + 0.5);
		if ($$res{'Vertex'}{'Data'}[$c]{'Position'}{z} < $$heightmap[$x][$y]) {
		    undef $poly;
		    last;
		}
		$poly->addPt($$res{'Vertex'}{'Data'}[$c]{'Position'}{x} * 
			     $Opt::scale,
			     $$res{'Vertex'}{'Data'}[$c]{'Position'}{y} *
			     $Opt::scale);
	    }
	    if (defined($poly)) {
		$image->filledPolygon($poly, $color);
	    }
	}
    }
}

######################################################################
# Add terrain area to picture

sub add_terrain {
    my($image, $res, $terrain, $colors, $heightmap, $dir_light) = @_;
    my($cnt, $i, $j, $c, $poly, $x, $y, $r, $g, $b, $a,
       $rc, $gc, $bc, $height, @v, $idx);

    $cnt = $$res{'Triangle Count'};

    for($i = 0; $i < $cnt; $i++) {
	$poly = new GD::Polygon;
	$r = 0; $g = 0; $b = 0;
	$rc = 0; $gc = 0; $bc = 0;
	$height = 0;
	$idx = 0;
	foreach $c (@{$$res{'Triangle'}{'Data'}[$i]{'Corners'}{'i'}}) {
	    if ($terrain) {
		$x = int($$res{'Vertex'}{'Data'}[$c]{XY1}{x} * 127 + 0.5);
		$y = int($$res{'Vertex'}{'Data'}[$c]{XY1}{y} * 127 + 0.5);
		for($j = 0; $j < 6; $j++) {
		    $a = ord(substr($$res{'Textures'}{'Data'}{$j}[$y], $x, 1))
			/ 255;
		    next if ($a < 0.0001);
		    $r += $$res{'Texture Color'}[$j]{'r'} * $a;
		    $g += $$res{'Texture Color'}[$j]{'g'} * $a;
		    $b += $$res{'Texture Color'}[$j]{'b'} * $a;
		}
	    }
	    if (defined($dir_light)) {
		my(@t);
		@t = ( $$res{'Vertex'}{'Data'}[$c]{'Position'}{x},
		       $$res{'Vertex'}{'Data'}[$c]{'Position'}{y},
		       $$res{'Vertex'}{'Data'}[$c]{'Position'}{z} );
		$v[$idx++] = \@t;
	    }

	    $poly->addPt($$res{'Vertex'}{'Data'}[$c]{'Position'}{x} * 
			 $Opt::scale,
			 $$res{'Vertex'}{'Data'}[$c]{'Position'}{y} *
			 $Opt::scale);
	    if ($heightmap ne '') {
		$height += $$res{'Vertex'}{'Data'}[$c]{'Position'}{z};
	    }
	    if ($colors) {
		$rc += $$res{'Vertex'}{'Data'}[$c]{'color'}{r};
		$gc += $$res{'Vertex'}{'Data'}[$c]{'color'}{g};
		$bc += $$res{'Vertex'}{'Data'}[$c]{'color'}{b};
	    }
	}

	if ($terrain) {
	    $r /= 3;
	    $g /= 3;
	    $b /= 3;
	}
	if ($colors) {
	    $r *= $rc / 3;
	    $g *= $gc / 3;
	    $b *= $bc / 3;
	}

	if (defined($dir_light)) {
	    my(@v1, @v2, @n, $mul);
	    @v1 = Math::Vector->VecSub(@{$v[1]}, @{$v[0]});
	    @v2 = Math::Vector->VecSub(@{$v[2]}, @{$v[0]});
	    @n = Math::Vector->CrossProduct(@v1, @v2);
	    @n = Math::Vector->UnitVector(@n);
	    $mul = Math::Vector->DotProduct(@n, @{$$dir_light[0]});
	    $mul *= $$dir_light[2];
	    $mul += $$dir_light[1];
	    if ($mul < 0) {
		$mul = 0;
	    } elsif ($mul > 1) {
		$mul = 1;
	    }
	    $r *= $mul;
	    $g *= $mul;
	    $b *= $mul;
	}

	$a = 0;

	if ($heightmap ne '') {
	    $height /= 3;
	    if ($heightmap =~ /^(red|green|blue|alpha|gray|grey)(\d+(\.\d+)?)([+-]\d+(\.\d+)?)$/i) {
		$height += $4;
		$height /= $2;
		if ($1 eq 'red') {
		    $r += $height;
		} elsif ($1 eq 'green') {
		    $g += $height;
		} elsif ($1 eq 'blue') {
		    $b += $height;
		} elsif ($1 eq 'alpha') {
		    $a += $height;
		} elsif ($1 eq 'grey' || $1 eq 'gray') {
		    $r += $height;
		    $g += $height;
		    $b += $height;
		}
	    } else {
		die "Invalid heighmap specification: $heightmap";
	    }
	}

	$image->filledPolygon($poly,
			      $image->colorAllocateAlpha($r * 255,
							 $g * 255,
							 $b * 255,
							 $a * 128));
    }
}

######################################################################
# Create heightmap of the terrain

sub add_heights {
    my($heightmap, $res) = @_;
    my($cnt, $i, $x, $y, $z);

    $cnt = $$res{'Vertex Count'};

    for($i = 0; $i < $cnt; $i++) {
	$x = int($$res{'Vertex'}{'Data'}[$i]{'Position'}{x} * 3 / 5 + 0.5);
	$y = int($$res{'Vertex'}{'Data'}[$i]{'Position'}{y} * 3 / 5 + 0.5);
	$z = $$res{'Vertex'}{'Data'}[$i]{'Position'}{z};
	$$heightmap[$x][$y] = $z;
    }
}

%TrnGraph::colors = ( 'red' => '#ff0000',
		      'green' => '#00ff00',
		      'blue' => '#0000ff',
		      'black' => '#000000',
		      'white' => '#ffffff',
		      'cyan' => '#00ffff',
		      'yellow' => '#ffff00',
		      'magenta' => '#ff00ff' );
		      
######################################################################
# Parse color

sub parse_color {
    my($str, $def) = @_;

    $str =~ s/^\s+//g;
    $str =~ s/\s+$//g;
    if ($str eq '' || $str =~ /^default$/i) {
	$str = $def;
    }
    if ($str eq 'undef') {
	return undef;
    }
    if (defined($TrnGraph::colors{$str})) {
	$str = $TrnGraph::colors{$str};
    }
    if ($str =~ /^\#([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$/i) {
	return $image->colorAllocateAlpha(ord(pack("H*", $1)),
					  ord(pack("H*", $2)),
					  ord(pack("H*", $3)),
					  ord(pack("H*", $4)) / 2);
    }
    if ($str =~ /^\#([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$/i) {
	return $image->colorAllocateAlpha(ord(pack("H*", $1)),
					  ord(pack("H*", $2)),
					  ord(pack("H*", $3)),
					  0);
    }
    if ($str =~ /^(\d+)[\s,\/-]+(\d+)[\s,\/-]+(\d+)[\s,\/-]+(\d+)$/) {
	return $image->colorAllocateAlpha($1, $2, $3, $4);
    }
    if ($str =~ /^(\d+)[\s,\/-]+(\d+)[\s,\/-]+(\d+)$/) {
	return $image->colorAllocateAlpha($1, $2, $3, 0);
    }
    if ($str =~ /^(\d*\.\d*)[\s,\/-]+(\d*\.\d*)[\s,\/-]+(\d*\.\d*)[\s,\/-]+(\d*\.\d*)$/) {
	return $image->colorAllocateAlpha($1 * 255, $2 * 255, $3 * 255,
					  $4 * 127);
    }
    if ($str =~ /^(\d*\.\d*)[\s,\/-]+(\d*\.\d*)[\s,\/-]+(\d*\.\d*)$/) {
	return $image->colorAllocateAlpha($1 * 255, $2 * 255, $3 * 255, 0);
    }
    die "Unparseable color: $str";
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

trngraph - Print Trn/Trx files to graphs

=head1 SYNOPSIS

trngraph [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--output>|B<-o> I<output-filename>]
    [B<--width>|B<-W> I<output-width-in-pixels>]
    [B<--height>|B<-H> I<output-height-in-pixels>]
    [B<--scale>|B<-s> I<scale>]
    [B<--walkmesh>|B<-w> I<color>]
    [B<--walkable>|B<-a> I<color>]
    [B<--water>|B<-A> I<color>]
    [B<--megatilegrid>|B<-g> I<color>]
    [B<--grid>|B<-G> I<color>]
    [B<--gridscale>|B<-S> I<scale-of-grid-in-meters>]
    [B<--heightmap>|B<-m> I<heightmap-specification>]
    [B<--light>|B<-l> I<directional-light-direction>]
    [B<--terrain>|B<-t>]
    [B<--colors>|B<-C>]
    [B<--crop>|B<-c>]
    I<filename> ...

trngraph B<--help>

=head1 DESCRIPTION

B<trngraph> reads trn/trx and prints out picture having varios things
from the original trx/trn. What is printed out depends on the
arguments given.

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

=item B<--output> B<-o> I<output-filename>

Output filename. The output file format is taken from the extension of
the filename. If it is not understood then png is used. 

=item B<--width> B<-W> I<output-width-in-pixels>

Width of the output picture in pixels. If not given then I<scale>
pixels = 1 meter is used. This will overwrite the scale and height
parameters.

=item B<--height> B<-H> I<output-height-in-pixels>

Height of the output picture in pixels. If not given then I<scale>
pixels = 1 meter is used. This will overwrite the scale if given.

=item B<--scale> B<-s> I<scale>

Scale the picture, multiplying the coordinates by given scale. This
will automatically scale also the output picture if no height or
width are given.

=item B<--walkmesh> B<-w> I<color>

Print walkmesh on the picture. Walkmesh triangle outlines are printed
in color given as argument (defaults to green).

=item B<--walkable> B<-a> I<color>

Print walkable triangles on the picture. Walkable area is printed as
filled triangles of given color (defaults to yellow).

=item B<--water> B<-A> I<color>

Print water triangles on the picture. Water is printed as filled
triangles of given color (defaults to water color from file).

=item B<--megatilegrid> B<-g> I<color>

Prints grid in given color in megatile boundaries. The color defaults
to red.

=item B<--grid> B<-G> I<color>

Prints grid in given color every --gridscale meters. The color
defaults to black.

=item B<--gridscale> B<-G> I<scale-of-grid-in-meters>

Prints grid in given color every --gridscale meters. 

=item B<--heightmap> B<-m> I<heightmap-specification>

Prints the heightmap to the picture. How the heightmap is printed
depends on the heightmap-specification. The specification has form of
<channel><max>+<offset> or <channel><max>-<offset>, where the
<channel> is either 'red', 'green', 'blue', 'alpha' or 'grey' (or
'gray') and the <max> is the max height on the map (it is mapped to
the max value on the channel) and + or - <offset> is the value that is
added to the height before converting it to color. I.e. the <offset>
in meters is first added to the height in meters and then it is
divided by the <max> value. This results value between 0..1 and that
is then added to the given channel. 

=item B<--light> B<-l> I<directional-light-direction>

This will enable simple flat shading of the polygons using directional
light from the given direction. Direction is given as 3 numbers
telling x, y, and z followed by the base ambient light intensity
(defaults to 0.3 if not given) and then the directional light
intensity (defaults to 0.7 if not given).

=item B<--terrain> B<-t>

Add terrain texture color to the map.

=item B<--colors> B<-C>

Add terrain color to the map.

=item B<--crop> B<-c>

Crop the usable area from the area, i.e. remove unwalkable borders. 

=back

=head1 COLORS

Colors, can be given in few different format. They can be in
hexadesimal format using #rrggbb or #rrggbbaa syntax. They can be
desimal format using format red,green,blue,alpha or red,green,blue,
where numbers are either floating point numbers in which case they are
between 0 and 1, or they are integers between 0 and 255. 

The separator between numbers can also be / or - or simply whitespace.
Alpha is given as number between 0 and 1 (floating point format) or
between 0 and 255. Value 0 means opaque, and 1 or 255 means
transparent.

If color is empty or just having word default, then default color is
used.

=head1 EXAMPLES

    trngraph -o output.png area1.trx
    trngraph -H 500 -w default -a default -o pic.png interior_area.trx
    trngraph -w default -a default -A default -g default -G default
    	     -S 10 -t -c -C -s 5 -o output.png area1.trx
    trngraph -m 'alpha50+5' -w default -a default -A default -g default
    	     -G default -S 10 -t -c -C -s 5 -o ~/nwn2/junk/pic.png a_tk_dyoa.trx

=head1 FILES

=over 6

=item ~/.trngraphrc

Default configuration file.

=back

=head1 SEE ALSO

trnprint(1), Trn(3), and TrnRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Program requested by drakolight and nosfe to generate pictures out
from the areas.
