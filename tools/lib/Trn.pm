#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# Trn.pm -- Trn object module
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: Trn.pm
#	  $Source: /u/samba/nwn/perllib/RCS/Trn.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 02:16 Jan 17 2007 kivinen
#	  Last Modification : 20:07 Aug  2 2007 kivinen
#	  Last check in     : $Date: 2007/08/02 18:55:21 $
#	  Revision number   : $Revision: 1.7 $
#	  State             : $State: Exp $
#	  Version	    : 1.963
#	  Edit time	    : 486 min
#
#	  Description       : Trn object module
#
#	  $Log: Trn.pm,v $
#	  Revision 1.7  2007/08/02 18:55:21  kivinen
#	  	Added support for linear format of some maps, i.e. instead of
#	  	using [y][x] format us [index] format so they can be more
#	  	easily used in scripts using vertex indexes.
#
#	  Revision 1.6  2007/06/10 13:32:50  kivinen
#	  	Moved some data to be hidden by default.
#
#	  Revision 1.5  2007/05/30 15:17:18  kivinen
#	  	Fixed color encode/decode. Fixed dds decode/encode. Added watr
#	  	and aswm encoding.
#
#	  Revision 1.4  2007/05/23 22:30:58  kivinen
#	  	Added encode_color, encode_vertex_trrn, encode_vertex_watr,
#	  	encode_dds, and encode_trrn. Fixed footsteps flags in aswm.
#
#	  Revision 1.3  2007/05/17 22:03:24  kivinen
#	  	Added object rotation, translate, and finding bbox.
#
#	  Revision 1.2  2007/04/23 23:30:25  kivinen
#	  	Added support for deleting resources, encoding structures,
#	  	decoding rigd, walk, col2, col3, and hooks.
#
#	  Revision 1.1  2007/01/23 22:39:30  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package Trn;
use strict;
use Carp;
use Compress::Zlib;
use Math::Quaternion;

######################################################################
# Set trn

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    if (!ref($_[0])) {
	my(%temp);
	$temp{'file_type'} = 'NWN2';
	$temp{'version_major'} = 2;
	$temp{'version_minor'} = 3;
	$temp{'resource_count'} = 0;
	bless \%temp, $class;
	return \%temp;
    } 
    bless $_[0], $class;
    return $_[0];
}

######################################################################
# $file_type = $self->file_type()
# $file_type = $self->file_type($file_type);
#
# Get or set file type

sub file_type {
    my $self = shift;
    if (@_) { $self->{file_type} = $_[0] }
    return $self->{file_type};
}

######################################################################
# $version_major = $self->version_major()
# $version_major = $self->version_major($version_major);
#
# Get or set file version

sub version_major {
    my $self = shift;
    if (@_) { $self->{version_major} = $_[0] }
    return $self->{version_major};
}

######################################################################
# $version_minor = $self->version_minor()
# $version_minor = $self->version_minor($version_minor);
#
# Get or set file version

sub version_minor {
    my $self = shift;
    if (@_) { $self->{version_minor} = $_[0] }
    return $self->{version_minor};
}

######################################################################
# $resource_count = $self->resource_count
# $self->resource_count(new_res_count)

sub resource_count {
    my $self = shift;
    if (@_) { $self->{resource_count} = $_[0] }
    return $self->{resource_count};
}

######################################################################
# $resource_type = $self->resource_type($index);
# $self->resource_type($index, $resource_type);

sub resource_type {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{resource_type}[$index] = $_[0] }
    return $self->{resource_type}[$index];
}

######################################################################
# $resource_size = $self->resource_size($index);
# $self->resource_size($index, $resource_size);

sub resource_size {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{resource_size}[$index] = $_[0] }
    return $self->{resource_size}[$index];
}

######################################################################
# $resource_index = $self->new_resource($resource_data, $resource_type,
#					[$resource_size]);

sub new_resource {
    my $self = shift;
    my($index);

    if ($#_ < 1) {
	croak "Too few arguments to new_resource";
    }
	
    $index = $self->{resource_count}++;
    $self->resource_data($index, $_[0]);
    $self->resource_type($index, $_[1]);
    if (defined($_[2])) {
	$self->resource_size($index, $_[2]);
    }
    return $index;
}

######################################################################
# $self->delete_resource($index);

sub delete_resource {
    my $self = shift;
    my $index = shift;

    $self->{resource_count}--;
    splice(@{$self->{resource_data}}, $index, 1);
    splice(@{$self->{resource_type}}, $index, 1);
    splice(@{$self->{resource_size}}, $index, 1);
}

######################################################################
# $data = $self->resource_data($index);
# $self->resource_data($index, $data);

sub resource_data {
    my $self = shift;
    my $index = shift;
    my($data);

    if (@_) {
	$data = $_[0];
	$self->{resource_data}[$index] = $data;
	$self->{resource_size}[$index] = length($data);
	return;
    }
    if (defined($self->{resource_data}[$index])) {
	return $self->{resource_data}[$index];
    }
    croak "Unknown resource";
}

######################################################################
# \%resource = decode_trwh($data, $linear)

sub decode_trwh {
    my($data, $linear) = @_;
    my(%resource);
    if (length($data) != 12) {
	croak "Invalid data length (should be 12): " . lenght($data);
    }
    ($resource{'Width'}, $resource{'Height'},
     $resource{'IdNumber'}) =
	unpack("VVV", $data);
    return \%resource;
}

######################################################################
# \%resource = encode_trwh(\%resource)

sub encode_trwh {
    my($resource) = @_;
    return pack("VVV", $$resource{'Width'}, $$resource{'Height'},
		$$resource{'IdNumber'});
}

######################################################################
# get_color(\%resource, $data)

sub get_color {
    my($resource, $data) = @_;
    my($r, $g, $b);

    ($r, $g, $b) = unpack("f3", $data);
    # No color
    if ($r == 1 && $g == 1 && $b == 1) {
	$$resource{''} = '-rgb';
    } else {
	$$resource{''} = 'rgb';
    }
    $$resource{r} = $r; 
    $$resource{g} = $g; 
    $$resource{b} = $b; 
}

######################################################################
# $data = encode_color(\%resource)

sub encode_color {
    my($resource) = @_;
    return pack("f3", $$resource{r}, $$resource{g}, $$resource{b});
}

######################################################################
# get_material(\%resource, $data)

sub get_material {
    my($resource, $data) = @_;

    ($$resource{'DiffuseMap'}, $$resource{'NormalMap'},
     $$resource{'TintMap'}, $$resource{'GlowMap'}) =
	 unpack("Z32Z32Z32Z32", $data);
    get_color(\%{$$resource{'Diffuse Color'}}, substr($data, 128, 12));
    get_color(\%{$$resource{'Specular Color'}}, substr($data, 140, 12));
    ($$resource{'Specular Power'}, $$resource{'Specular Value'},
     $$resource{'Flags'}) =
	unpack("ffV", substr($data, 152, 12));
}

######################################################################
# $data = encode_material(\%resource)

sub encode_material {
    my($resource) = @_;

    return pack("Z32Z32Z32Z32f3f3f2V",
		$$resource{'DiffuseMap'}, $$resource{'NormalMap'},
		$$resource{'TintMap'}, $$resource{'GlowMap'},
		$$resource{'Diffuse Color'}{r}, 
		$$resource{'Diffuse Color'}{g}, 
		$$resource{'Diffuse Color'}{b}, 
		$$resource{'Specular Color'}{r},
		$$resource{'Specular Color'}{g},
		$$resource{'Specular Color'}{b},
		$$resource{'Specular Power'},
		$$resource{'Specular Value'},
		$$resource{'Flags'});
}


######################################################################
# decode_vertex_trrn(\%resource, $count, $data, $linear);

sub decode_vertex_trrn {
    my($resource, $count, $data, $linear) = @_;
    my($color);

    if ($count != 625 || $linear) {
	my($i);

	for($i = 0; $i < $count; $i++) {
	    $$resource[$i]{Position}{''} = 'xyz';
	    $$resource[$i]{Normal}{''} = 'xyz';
	    $$resource[$i]{XY10}{''} = 'xy';
	    $$resource[$i]{XY1}{''} = 'xy';
	    ($$resource[$i]{Position}{x},
	     $$resource[$i]{Position}{y},
	     $$resource[$i]{Position}{z},
	     $$resource[$i]{Normal}{x},
	     $$resource[$i]{Normal}{y},
	     $$resource[$i]{Normal}{z},
	     $color,
	     $$resource[$i]{XY10}{x},
	     $$resource[$i]{XY10}{y},
	     $$resource[$i]{XY1}{x},
	     $$resource[$i]{XY1}{y}) =
		 unpack("f6Vf4", substr($data, $i * 44, 44));
	    if (abs($$resource[$i]{XY10}{x} +
		    10 * $$resource[$i]{XY1}{x}) < 0.001 &&
		abs($$resource[$i]{XY10}{y} -
		    10 * $$resource[$i]{XY1}{y}) < 0.001 &&
		abs($$resource[$i]{XY10}{x} * 4 +
		    ($$resource[$i]{Position}{x} -
		     $$resource[0]{Position}{x})) < 0.001 &&
		abs($$resource[$i]{XY10}{y} * 4 -
		    ($$resource[$i]{Position}{y} -
		     $$resource[0]{Position}{y})) < 0.001) {
		$$resource[$i]{XY10}{''} = '-xy';
		$$resource[$i]{XY1}{''} = '-xy';
	    }
	    if ($color == 0xffffffff) {
		$$resource[$i]{color}{''} = '-rgba';
	    } else {
		$$resource[$i]{color}{''} = 'rgba';
	    }
	    $$resource[$i]{color}{'r'} = (($color >> 16) & 0xff) / 255;
	    $$resource[$i]{color}{'g'} = (($color >> 8) & 0xff) / 255;
	    $$resource[$i]{color}{'b'} = ($color & 0xff) / 255;
	    if ((($color >> 24) & 0xff) != 255) {
		$$resource[$i]{color}{'a'} = (($color >> 24) & 0xff) / 255;
	    }
	}
    } else {
	my($x, $y);
	for($y = 0; $y < 25; $y++) {
	    for($x = 0; $x < 25; $x++) {
		$$resource[$x][$y]{Position}{''} = 'xyz';
		$$resource[$x][$y]{Normal}{''} = 'xyz';
		$$resource[$x][$y]{XY10}{''} = 'xy';
		$$resource[$x][$y]{XY1}{''} = 'xy';
		($$resource[$x][$y]{Position}{x},
		 $$resource[$x][$y]{Position}{y},
		 $$resource[$x][$y]{Position}{z},
		 $$resource[$x][$y]{Normal}{x},
		 $$resource[$x][$y]{Normal}{y},
		 $$resource[$x][$y]{Normal}{z},
		 $color,
		 $$resource[$x][$y]{XY10}{x},
		 $$resource[$x][$y]{XY10}{y},
		 $$resource[$x][$y]{XY1}{x},
		 $$resource[$x][$y]{XY1}{y}) =
		     unpack("f6Vf4", substr($data, $x * 44 +
					    $y * 44 * 25, 44));
		if (abs($$resource[$x][$y]{XY10}{x} +
			10 * $$resource[$x][$y]{XY1}{x}) < 0.001 &&
		    abs($$resource[$x][$y]{XY10}{y} -
			10 * $$resource[$x][$y]{XY1}{y}) < 0.001 &&
		    abs($$resource[$x][$y]{XY10}{x} * 4 +
			($$resource[$x][$y]{Position}{x} -
			 $$resource[0][0]{Position}{x})) < 0.001 &&
		    abs($$resource[$x][$y]{XY10}{y} * 4 -
			($$resource[$x][$y]{Position}{y} -
			 $$resource[0][0]{Position}{y})) < 0.001) {
		    $$resource[$x][$y]{XY10}{''} = '-xy';
		    $$resource[$x][$y]{XY1}{''} = '-xy';
		}
		if ($color == 0xffffffff) {
		    $$resource[$x][$y]{color}{''} = '-rgba';
		} else {
		    $$resource[$x][$y]{color}{''} = 'rgba';
		}
		$$resource[$x][$y]{color}{'r'} = (($color >> 16) & 0xff) / 255;
		$$resource[$x][$y]{color}{'g'} = (($color >> 8) & 0xff) / 255;
		$$resource[$x][$y]{color}{'b'} = ($color & 0xff) / 255;
		if ((($color >> 24) & 0xff) != 255) {
		    $$resource[$x][$y]{color}{'a'} =
			(($color >> 24) & 0xff) / 255;
		}
	    }
	}
    }
}

######################################################################
# $data = encode_vertex_trrn(\%resource, $count);

sub encode_vertex_trrn {
    my($resource, $count) = @_;
    my($i, $data, $color);
    $data = '';
    if ($count != 625) {
	for($i = 0; $i < $count; $i++) {
	    $color = (($$resource[$i]{color}{'r'} * 255) << 16) |
		(($$resource[$i]{color}{'g'} * 255) << 8) |
		($$resource[$i]{color}{'b'} * 255);
	    if (defined($$resource[$i]{color}{'a'})) {
		$color |= (($$resource[$i]{color}{'a'} * 255) << 24);
	    } else {
		$color |= (255 << 24);
	    }
	    $data .= pack("f6Vf4", 
			  $$resource[$i]{Position}{x},
			  $$resource[$i]{Position}{y},
			  $$resource[$i]{Position}{z},
			  $$resource[$i]{Normal}{x},
			  $$resource[$i]{Normal}{y},
			  $$resource[$i]{Normal}{z},
			  $color,
			  $$resource[$i]{XY10}{x},
			  $$resource[$i]{XY10}{y},
			  $$resource[$i]{XY1}{x},
			  $$resource[$i]{XY1}{y});
	}
    } else {
	my($x, $y);
	for($y = 0; $y < 25; $y++) {
	    for($x = 0; $x < 25; $x++) {
		$color = (($$resource[$x][$y]{color}{'r'} * 255) << 16) |
		    (($$resource[$x][$y]{color}{'g'} * 255) << 8) |
		    ($$resource[$x][$y]{color}{'b'} * 255);
		if (defined($$resource[$x][$y]{color}{'a'})) {
		    $color |= (($$resource[$x][$y]{color}{'a'} * 255) << 24);
		} else {
		    $color |= (255 << 24);
		}
		$data .= pack("f6Vf4", 
			      $$resource[$x][$y]{Position}{x},
			      $$resource[$x][$y]{Position}{y},
			      $$resource[$x][$y]{Position}{z},
			      $$resource[$x][$y]{Normal}{x},
			      $$resource[$x][$y]{Normal}{y},
			      $$resource[$x][$y]{Normal}{z},
			      $color,
			      $$resource[$x][$y]{XY10}{x},
			      $$resource[$x][$y]{XY10}{y},
			      $$resource[$x][$y]{XY1}{x},
			      $$resource[$x][$y]{XY1}{y});
	    }
	}
    }
    return $data;
}


######################################################################
# decode_vertex_watr(\%resource, $count, $data, $linear);

sub decode_vertex_watr {
    my($resource, $count, $data, $linear) = @_;
    
    if ($count != 625 || $linear) {
	my($i);

	for($i = 0; $i < $count; $i++) {
	    $$resource[$i]{Position}{''} = 'xyz';
	    $$resource[$i]{XY5}{''} = 'xy';
	    $$resource[$i]{XY1}{''} = 'xy';
	    ($$resource[$i]{Position}{x},
	     $$resource[$i]{Position}{y},
	     $$resource[$i]{Position}{z},
	     $$resource[$i]{XY5}{x},
	     $$resource[$i]{XY5}{y},
	     $$resource[$i]{XY1}{x},
	     $$resource[$i]{XY1}{y}) =
		 unpack("f7", substr($data, $i * 28, 28));
	}
    } else {
	my($x, $y);
	for($y = 0; $y < 25; $y++) {
	    for($x = 0; $x < 25; $x++) {
		$$resource[$x][$y]{Position}{''} = 'xyz';
		$$resource[$x][$y]{XY5}{''} = 'xy';
		$$resource[$x][$y]{XY1}{''} = 'xy';
		($$resource[$x][$y]{Position}{x},
		 $$resource[$x][$y]{Position}{y},
		 $$resource[$x][$y]{Position}{z},
		 $$resource[$x][$y]{XY5}{x},
		 $$resource[$x][$y]{XY5}{y},
		 $$resource[$x][$y]{XY1}{x},
		 $$resource[$x][$y]{XY1}{y}) =
		     unpack("f7", substr($data, $x * 28 +
					 $y * 28 * 25, 28));
		if (abs(($$resource[$x][$y]{XY5}{x} / 5 * 24) - $x) < 0.001 &&
		    abs(($$resource[$x][$y]{XY5}{y} / 5 * 24) - $y) < 0.001 &&
		    abs($$resource[$x][$y]{XY1}{x} * 24 - $x) < 0.001 &&
		    abs($$resource[$x][$y]{XY1}{y} * 24 - $y) < 0.001) {
		    $$resource[$x][$y]{XY5}{''} = '-xy';
		    $$resource[$x][$y]{XY1}{''} = '-xy';
		}
	    }
	}
    }
}

######################################################################
# $data = encode_vertex_watr(\%resource, $count);

sub encode_vertex_watr {
    my($resource, $count) = @_;
    my($i, $data);
    $data = '';
    if ($count != 625) {
	for($i = 0; $i < $count; $i++) {
	    $data .= pack("f7", 
			  $$resource[$i]{Position}{x},
			  $$resource[$i]{Position}{y},
			  $$resource[$i]{Position}{z},
			  $$resource[$i]{XY5}{x},
			  $$resource[$i]{XY5}{y},
			  $$resource[$i]{XY1}{x},
			  $$resource[$i]{XY1}{y});
	}
    } else {
	my($x, $y);
	for($y = 0; $y < 25; $y++) {
	    for($x = 0; $x < 25; $x++) {
		$data .= pack("f7", 
			      $$resource[$x][$y]{Position}{x},
			      $$resource[$x][$y]{Position}{y},
			      $$resource[$x][$y]{Position}{z},
			      $$resource[$x][$y]{XY5}{x},
			      $$resource[$x][$y]{XY5}{y},
			      $$resource[$x][$y]{XY1}{x},
			      $$resource[$x][$y]{XY1}{y});
	    }
	}
    }
    return $data;
}

######################################################################
# decode_vertex_rigd(\%resource, $count, $data, $linear);

sub decode_vertex_rigd {
    my($resource, $count, $data, $linear) = @_;
    my($i);
    for($i = 0; $i < $count; $i++) {
	$$resource[$i]{Position}{''} = 'xyz';
	$$resource[$i]{Normal}{''} = 'xyz';
	$$resource[$i]{Tangent}{''} = 'xyz';
	$$resource[$i]{Binormal}{''} = 'xyz';
	$$resource[$i]{'Texture UVW'}{''} = 'uvw';
	($$resource[$i]{Position}{x},
	 $$resource[$i]{Position}{y},
	 $$resource[$i]{Position}{z},
	 $$resource[$i]{Normal}{x},
	 $$resource[$i]{Normal}{y},
	 $$resource[$i]{Normal}{z},
	 $$resource[$i]{Tangent}{x},
	 $$resource[$i]{Tangent}{y},
	 $$resource[$i]{Tangent}{z},
	 $$resource[$i]{Binormal}{x},
	 $$resource[$i]{Binormal}{y},
	 $$resource[$i]{Binormal}{z},
	 $$resource[$i]{'Texture UVW'}{u},
	 $$resource[$i]{'Texture UVW'}{v},
	 $$resource[$i]{'Texture UVW'}{w}) = 
	     unpack("f15", substr($data, $i * 60, 60));
    }
}

######################################################################
# $data = encode_vertex_rigd(\%resource, $count);

sub encode_vertex_rigd {
    my($resource, $count) = @_;
    my($i, $data);
    $data = '';
    for($i = 0; $i < $count; $i++) {
	$data .= pack("f15", 
		      $$resource[$i]{Position}{x},
		      $$resource[$i]{Position}{y},
		      $$resource[$i]{Position}{z},
		      $$resource[$i]{Normal}{x},
		      $$resource[$i]{Normal}{y},
		      $$resource[$i]{Normal}{z},
		      $$resource[$i]{Tangent}{x},
		      $$resource[$i]{Tangent}{y},
		      $$resource[$i]{Tangent}{z},
		      $$resource[$i]{Binormal}{x},
		      $$resource[$i]{Binormal}{y},
		      $$resource[$i]{Binormal}{z},
		      $$resource[$i]{'Texture UVW'}{u},
		      $$resource[$i]{'Texture UVW'}{v},
		      $$resource[$i]{'Texture UVW'}{w});
    }
    return $data;
}

######################################################################
# decode_vertex_cvert(\%resource, $count, $data, $linear);

sub decode_vertex_cvert {
    my($resource, $count, $data, $linear) = @_;
    my($i);
    for($i = 0; $i < $count; $i++) {
	$$resource[$i]{Position}{''} = 'xyz';
	$$resource[$i]{Normal}{''} = 'xyz';
	$$resource[$i]{'Texture UVW'}{''} = 'uvw';
	($$resource[$i]{Position}{x},
	 $$resource[$i]{Position}{y},
	 $$resource[$i]{Position}{z},
	 $$resource[$i]{Normal}{x},
	 $$resource[$i]{Normal}{y},
	 $$resource[$i]{Normal}{z},
	 $$resource[$i]{'Texture UVW'}{u},
	 $$resource[$i]{'Texture UVW'}{v},
	 $$resource[$i]{'Texture UVW'}{w}) = 
	     unpack("f15", substr($data, $i * 36, 36));
    }
}

######################################################################
# $data = encode_vertex_cvert(\%resource, $count);

sub encode_vertex_cvert {
    my($resource, $count) = @_;
    my($i, $data);
    $data = '';
    for($i = 0; $i < $count; $i++) {
	$data .= pack("f9", 
		      $$resource[$i]{Position}{x},
		      $$resource[$i]{Position}{y},
		      $$resource[$i]{Position}{z},
		      $$resource[$i]{Normal}{x},
		      $$resource[$i]{Normal}{y},
		      $$resource[$i]{Normal}{z},
		      $$resource[$i]{'Texture UVW'}{u},
		      $$resource[$i]{'Texture UVW'}{v},
		      $$resource[$i]{'Texture UVW'}{w});
    }
    return $data;
}

######################################################################
# decode_vertex_point3(\%resource, $count, $data, $linear);

sub decode_vertex_point3 {
    my($resource, $count, $data, $linear) = @_;
    my($i);
    for($i = 0; $i < $count; $i++) {
	$$resource[$i]{Position}{''} = 'xyz';
	($$resource[$i]{Position}{x},
	 $$resource[$i]{Position}{y},
	 $$resource[$i]{Position}{z}) =
	     unpack("f15", substr($data, $i * 12, 12));
    }
}

######################################################################
# $data = encode_vertex_point3(\%resource, $count);

sub encode_vertex_point3 {
    my($resource, $count) = @_;
    my($i, $data);
    $data = '';
    for($i = 0; $i < $count; $i++) {
	$data .= pack("f3", 
		      $$resource[$i]{Position}{x},
		      $$resource[$i]{Position}{y},
		      $$resource[$i]{Position}{z});
    }
    return $data;
}

######################################################################
# decode_triangles(\%resource, $count, $data, $linear);

sub decode_triangles {
    my($resource, $count, $data, $linear) = @_;
    my($i);
    
    for($i = 0; $i < $count; $i++) {
	$$resource[$i]{Corners}{''} = '-iii';
	($$resource[$i]{Corners}{i}[0],
	 $$resource[$i]{Corners}{i}[1],
	 $$resource[$i]{Corners}{i}[2]) =
	     unpack("v3", substr($data, $i * 6, 6));
    }
}

######################################################################
# $data = encode_triangles(\%resource, $count);

sub encode_triangles {
    my($resource, $count) = @_;
    my($i, $data);
    $data = '';
    
    for($i = 0; $i < $count; $i++) {
	$data .= pack("v3", 
		      $$resource[$i]{Corners}{i}[0],
		      $$resource[$i]{Corners}{i}[1],
		      $$resource[$i]{Corners}{i}[2]);
    }
    return $data;
}

######################################################################
# decode_wtri(\%resource, $count, $data, $linear);

sub decode_wtri {
    my($resource, $count, $data, $linear) = @_;
    my($i);
    
    for($i = 0; $i < $count; $i++) {
	$$resource[$i]{Corners}{''} = '-iii';
	($$resource[$i]{Corners}{i}[0],
	 $$resource[$i]{Corners}{i}[1],
	 $$resource[$i]{Corners}{i}[2],
	 $$resource[$i]{Corners}{i}[3]) =
	     unpack("v3V", substr($data, $i * 10, 10));
    }
}

######################################################################
# $data = encode_wtri(\%resource, $count);

sub encode_wtri {
    my($resource, $count) = @_;
    my($i, $data);
    $data = '';
    
    for($i = 0; $i < $count; $i++) {
	$data .= pack("v3V", 
		      $$resource[$i]{Corners}{i}[0],
		      $$resource[$i]{Corners}{i}[1],
		      $$resource[$i]{Corners}{i}[2],
		      $$resource[$i]{Corners}{i}[3]);
    }
    return $data;
}


######################################################################
# decode_dds(\%resource, $data, $index, $r_name, $g_name, $b_name, $a_name);

sub decode_dds {
    my($resource, $data, $index, $r, $g, $b, $a) = @_;
    my($picture, $y);

    $$resource{Info}[$index]{''} = '-hash';
    ($$resource{Info}[$index]{'Magic'},
     $$resource{Info}[$index]{'Size'},
     $$resource{Info}[$index]{'Flags%'},
     $$resource{Info}[$index]{'Height'},
     $$resource{Info}[$index]{'Width'},
     $$resource{Info}[$index]{'Pitch'},
     $$resource{Info}[$index]{'Depth'},
     $$resource{Info}[$index]{'Minimaps'},
     $$resource{Info}[$index]{'Pixelformat Size'},
     $$resource{Info}[$index]{'Pixelformat Flags%'}, 
     $$resource{Info}[$index]{'Pixelformat Fourcc'}, 
     $$resource{Info}[$index]{'Pixelformat Rgbbitcount'}, 
     $$resource{Info}[$index]{'Pixelformat Rbitmask%'}, 
     $$resource{Info}[$index]{'Pixelformat Gbitmask%'}, 
     $$resource{Info}[$index]{'Pixelformat Bbitmask%'}, 
     $$resource{Info}[$index]{'Pixelformat Alphamask%'},
     $$resource{Info}[$index]{'Ddscap1s%'},
     $$resource{Info}[$index]{'Ddscap2s%'}) =
	 unpack("A4VVVVVVVx44VVA4VVVVVVV", $data);
    $picture = substr($data, $$resource{Info}[$index]{'Size'} + 4);
    if (length($picture) != 
	($$resource{Info}[$index]{'Width'} *
	 $$resource{Info}[$index]{'Height'} *
	 $$resource{Info}[$index]{'Pixelformat Rgbbitcount'} / 8)) {
	carp "Length does not match " . length($picture) . " vs " .
	    ($$resource{Info}[$index]{'Width'} *
	     $$resource{Info}[$index]{'Height'} *
	     $$resource{Info}[$index]{'Pixelformat Rgbbitcount'} / 8);
    }
    if ($$resource{Info}[$index]{'Pixelformat Rgbbitcount'} == 8 &&
	$$resource{Info}[$index]{'Pixelformat Rbitmask%'} == 0xff &&
	$$resource{Info}[$index]{'Pixelformat Gbitmask%'} == 0x00 &&
	$$resource{Info}[$index]{'Pixelformat Bbitmask%'} == 0x00 &&
	$$resource{Info}[$index]{'Pixelformat Alphamask%'} == 0x00) {
	$$resource{Data}{''} = '-pixmap#';
	for($y = 0; $y < $$resource{Info}[$index]{'Height'}; $y++) {
	    $$resource{Data}{$r}[$y] =
		substr($picture, $y * $$resource{Info}[$index]{'Height'},
		       $$resource{Info}[$index]{'Width'});
	}
    } elsif ($$resource{Info}[$index]{'Pixelformat Rgbbitcount'} == 32 &&
	     $$resource{Info}[$index]{'Pixelformat Rbitmask%'} == 0x00ff0000 &&
	     $$resource{Info}[$index]{'Pixelformat Gbitmask%'} == 0x0000ff00 &&
	     $$resource{Info}[$index]{'Pixelformat Bbitmask%'} == 0x000000ff &&
	     $$resource{Info}[$index]{'Pixelformat Alphamask%'} ==
	     0xff000000) {
	my(@c, $cnt, $row);
	$$resource{Data}{''} = '-pixmap#';
	$cnt = $$resource{Info}[$index]{'Width'} + 0;
	for($y = 0; $y < $$resource{Info}[$index]{'Height'}; $y++) {
	    $row = substr($picture, $y *
			  $$resource{Info}[$index]{'Height'} * 4, $cnt * 4);
	    @c = unpack("V" x $cnt, $row);
	    $$resource{Data}{$a}[$y] =
		pack("C*", map { ($_ >> 24) & 0xff } @c);
	    $$resource{Data}{$r}[$y] = 
		pack("C*", map { ($_ >> 16) & 0xff } @c);
	    $$resource{Data}{$g}[$y] = 
		pack("C*", map { ($_ >> 8) & 0xff } @c);
	    $$resource{Data}{$b}[$y] = 
		pack("C*", map { ($_ & 0xff) } @c);
	}
    } else {
	carp "Rgbbitcount != 8 or 32, " .
	    $$resource{Info}[$index]{'Pixelformat Rgbbitcount'};
    }
}

######################################################################
# $data = encode_dds(\%resource, $index, $r_name, $g_name, $b_name, $a_name);

sub encode_dds {
    my($resource, $index, $r, $g, $b, $a) = @_;
    my($y, $x, $data);
    
    $data = pack("A4VVVVVVVx44VVA4VVVVVVVx8x4",
		 $$resource{Info}[$index]{'Magic'},
		 $$resource{Info}[$index]{'Size'},
		 $$resource{Info}[$index]{'Flags%'},
		 $$resource{Info}[$index]{'Height'},
		 $$resource{Info}[$index]{'Width'},
		 $$resource{Info}[$index]{'Pitch'},
		 $$resource{Info}[$index]{'Depth'},
		 $$resource{Info}[$index]{'Minimaps'},
		 $$resource{Info}[$index]{'Pixelformat Size'},
		 $$resource{Info}[$index]{'Pixelformat Flags%'}, 
		 $$resource{Info}[$index]{'Pixelformat Fourcc'}, 
		 $$resource{Info}[$index]{'Pixelformat Rgbbitcount'}, 
		 $$resource{Info}[$index]{'Pixelformat Rbitmask%'}, 
		 $$resource{Info}[$index]{'Pixelformat Gbitmask%'}, 
		 $$resource{Info}[$index]{'Pixelformat Bbitmask%'}, 
		 $$resource{Info}[$index]{'Pixelformat Alphamask%'},
		 $$resource{Info}[$index]{'Ddscap1s%'},
		 $$resource{Info}[$index]{'Ddscap2s%'});
    if ($$resource{Info}[$index]{'Pixelformat Rgbbitcount'} == 8 &&
	$$resource{Info}[$index]{'Pixelformat Rbitmask%'} == 0xff &&
	$$resource{Info}[$index]{'Pixelformat Gbitmask%'} == 0x00 &&
	$$resource{Info}[$index]{'Pixelformat Bbitmask%'} == 0x00 &&
	$$resource{Info}[$index]{'Pixelformat Alphamask%'} == 0x00) {
	for($y = 0; $y < $$resource{Info}[$index]{'Height'}; $y++) {
	    $data .= $$resource{Data}{$r}[$y];
	}
    } elsif ($$resource{Info}[$index]{'Pixelformat Rgbbitcount'} == 32 &&
	     $$resource{Info}[$index]{'Pixelformat Rbitmask%'} == 0x00ff0000 &&
	     $$resource{Info}[$index]{'Pixelformat Gbitmask%'} == 0x0000ff00 &&
	     $$resource{Info}[$index]{'Pixelformat Bbitmask%'} == 0x000000ff &&
	     $$resource{Info}[$index]{'Pixelformat Alphamask%'} ==
	     0xff000000) {
	my(@c, $cnt, @a, @r, @g, @b);
	$cnt = $$resource{Info}[$index]{'Width'} + 0;
	for($y = 0; $y < $$resource{Info}[$index]{'Height'}; $y++) {
	    @c = ();
	    @a = unpack("C*", $$resource{Data}{$a}[$y]);
	    @r = unpack("C*", $$resource{Data}{$r}[$y]);
	    @g = unpack("C*", $$resource{Data}{$g}[$y]);
	    @b = unpack("C*", $$resource{Data}{$b}[$y]);
	    for($x = 0; $x < $cnt; $x++) {
		push(@c,
		     ($a[$x] << 24) | ($r[$x] << 16) | ($g[$x] << 8) | $b[$x]);
	    }
	    $data .= pack("V*", @c);
	}
    } else {
	carp "Rgbbitcount != 8 or 32, " .
	    $$resource{Info}[$index]{'Pixelformat Rgbbitcount'};
    }
    return $data;
}

######################################################################
# \%resource = decode_trrn($data, $linear)

sub decode_trrn {
    my($data, $linear) = @_;
    my(%resource, $off, $i, $j, $len, $dds1, $dds2, $x);

    $off = 0;
    ($resource{'Name'}, $resource{'Texture'}[0],
     $resource{'Texture'}[1], $resource{'Texture'}[2],
     $resource{'Texture'}[3], $resource{'Texture'}[4],
     $resource{'Texture'}[5]) =
	 unpack("Z128Z32Z32Z32Z32Z32Z32", $data);
    $off += 128 + 6 * 32;
    for($i = 0; $i < 6; $i++) {
	get_color(\%{$resource{'Texture Color'}[$i]},
		  substr($data, $off, 12));
	$off += 12;
    }
    ($resource{'Vertex Count'}, $resource{'Triangle Count'}) =
	unpack("VV", substr($data, $off, 8));
    $off += 8;

    $len = $resource{'Vertex Count'} * 44;
    decode_vertex_trrn(\@{$resource{Vertex}{Data}}, 
		       $resource{'Vertex Count'},
		       substr($data, $off, $len), $linear);
    $resource{Vertex}{''} = '-hash';
    $off += $len;
    $len = $resource{'Triangle Count'} * 6;
    decode_triangles(\@{$resource{Triangle}{Data}},
		     $resource{'Triangle Count'},
		     substr($data, $off, $len), $linear);
    $resource{Triangle}{''} = '-hash';
    $off += $len;

    ($dds1, $dds2) = unpack("V/aV/a", substr($data, $off));
    decode_dds(\%{$resource{Textures}}, $dds1, 1, "0", "1", "2", "3");
    decode_dds(\%{$resource{Textures}}, $dds2, 2, "4", "5", "6", "7");
    $off += 4 + length($dds1) + 4 + length($dds2);

    $x = unpack("V", substr($data, $off, 4));
    $off += 4;

    for($i = 0; $i < $x; $i++) {
	my($k, $item_cnt);
	($resource{Grass}[$i]{'Name'},
	 $resource{Grass}[$i]{'Type'}) =
	     unpack("Z32Z32", substr($data, $off, 64));
	$off += 64;

	$item_cnt = unpack("V", substr($data, $off, 4));
	$off += 4;
	$resource{Grass}[$i]{'Item Count'} = $item_cnt;

	$k = substr($data, $off, $item_cnt * 36);
	$resource{Grass}[$i]{'Data'}{''} = '-hash';
	for($j = 0; $j < $item_cnt; $j++) {
	    $resource{Grass}[$i]{Data}{Grass}[$j]{'Position'}{''} = 'xyz';
	    $resource{Grass}[$i]{Data}{Grass}[$j]{'Orientation'}{''} = 'xyz';
	    $resource{Grass}[$i]{Data}{Grass}[$j]{'Offset'}{''} = 'xyz';
	    ($resource{Grass}[$i]{Data}{Grass}[$j]{'Position'}{'x'},
	     $resource{Grass}[$i]{Data}{Grass}[$j]{'Position'}{'y'},
	     $resource{Grass}[$i]{Data}{Grass}[$j]{'Position'}{'z'},
	     $resource{Grass}[$i]{Data}{Grass}[$j]{'Orientation'}{'x'},
	     $resource{Grass}[$i]{Data}{Grass}[$j]{'Orientation'}{'y'},
	     $resource{Grass}[$i]{Data}{Grass}[$j]{'Orientation'}{'z'},
	     $resource{Grass}[$i]{Data}{Grass}[$j]{'Offset'}{'x'},
	     $resource{Grass}[$i]{Data}{Grass}[$j]{'Offset'}{'y'},
	     $resource{Grass}[$i]{Data}{Grass}[$j]{'Offset'}{'z'}) =
		 unpack("f9", substr($k, $j * 36, 36));
	}
	$off += length($k);
    }
    if ($off != length($data)) {
 	croak "Extra data used = $off, len = " . length($data) .
 	    " extra = " . (length($data) - $off);
    }
    return \%resource;
}

######################################################################
# $data = encode_trrn(\%resource);

sub encode_trrn {
    my($resource) = @_;
    my($i, $j, $data, $dds, $x);

    $data = pack("Z128Z32Z32Z32Z32Z32Z32",
		 $$resource{'Name'}, $$resource{'Texture'}[0],
		 $$resource{'Texture'}[1], $$resource{'Texture'}[2],
		 $$resource{'Texture'}[3], $$resource{'Texture'}[4],
		 $$resource{'Texture'}[5]);
    for($i = 0; $i < 6; $i++) {
	$data .= encode_color($$resource{'Texture Color'}[$i]);
    }
    $data .= pack("VV", $$resource{'Vertex Count'},
		  $$resource{'Triangle Count'});
    $data .= encode_vertex_trrn($$resource{Vertex}{Data},
				$$resource{'Vertex Count'});
    $data .= encode_triangles($$resource{Triangle}{Data},
			      $$resource{'Triangle Count'});
    $dds = encode_dds($$resource{Textures}, 1, "0", "1", "2", "3");
    $data .= pack("V/a*", $dds);
    $dds = encode_dds($$resource{Textures}, 2, "4", "5", "6", "7");
    $data .= pack("V/a*", $dds);
    if (defined($$resource{Grass})) {
	$x = $#{$$resource{Grass}} + 1;
	$data .= pack("V", $x);
	for($i = 0; $i < $x; $i++) {
	    $data .= pack("Z32Z32V", $$resource{Grass}[$i]{'Name'},
			  $$resource{Grass}[$i]{'Type'},
			  $$resource{Grass}[$i]{'Item Count'});
	    for($j = 0; $j < $$resource{Grass}[$i]{'Item Count'}; $j++) {
		$data .=
		    pack("f9", 
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Position'}{'x'},
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Position'}{'y'},
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Position'}{'z'},
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Orientation'}{'x'},
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Orientation'}{'y'},
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Orientation'}{'z'},
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Offset'}{'x'},
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Offset'}{'y'},
			 $$resource{Grass}[$i]{Data}{Grass}[$j]
			 {'Offset'}{'z'});
	    }
	}
    } else {
	$data .= pack("V", 0);
    }
    return $data;
}

######################################################################
# \%resource = decode_watr($data, $linear)

sub decode_watr {
    my($data, $linear) = @_;
    my(%resource, $off, $i, $len, $dds, $y);

    $off = 0;
    ($resource{'Name'}) = unpack("Z128", $data);
    $off += 128;
    get_color(\%{$resource{'Water Color'}}, substr($data, $off, 12));
    $off += 12;
    ($resource{'RippleX'}, $resource{'RippleY'}, $resource{'Smoothness'},
     $resource{'Ref Bias'}, $resource{'Ref Power'},
     $resource{'Unknown 1'}, $resource{'Unknown 2'}) =
	 unpack("f7", substr($data, $off, 28));
    $off += 28;
    for($i = 0; $i < 3; $i++) {
	($resource{'Texture'}[$i]{Name},
	 $resource{'Texture'}[$i]{'X Direction'},
	 $resource{'Texture'}[$i]{'Y Direction'},
	 $resource{'Texture'}[$i]{'Rate'},
	 $resource{'Texture'}[$i]{'Angle'}) = 
	     unpack("Z32f4", substr($data, $off, 48));
	$off += 48;
    }
    ($resource{'X8'}, $resource{'Y8'},
     $resource{'Vertex Count'}, $resource{'Triangle Count'}) =
	 unpack("ffVV", substr($data, $off, 16));
    $off += 16;
    $len = $resource{'Vertex Count'} * 28;
    decode_vertex_watr(\@{$resource{Vertex}{Data}}, 
		       $resource{'Vertex Count'},
		       substr($data, $off, $len), $linear);
    $resource{Vertex}{''} = '-hash';
    $off += $len;
    $len = $resource{'Triangle Count'} * 6;
    decode_triangles(\@{$resource{Triangle}{Data}},
		     $resource{'Triangle Count'},
		     substr($data, $off, $len), $linear);
    $resource{Triangle}{''} = '-hash';
    $off += $len;
    for($y = 0; $y < 24; $y++) {
	$resource{Bitmap}[$y] = 
	    join("", unpack("V48",
			    substr($data, $off + $y * 192, 192)));
    }
    $off += 1152 * 4;

    $dds = unpack("V/a", substr($data, $off));
    decode_dds(\%{$resource{Textures}}, $dds, 1, "0", "1", "2", "3");
    $off += 4 + length($dds);

    ($resource{X}, $resource{Y}) = unpack("VV", substr($data, $off, 8));
    $off += 8;

    if ($off != length($data)) {
	croak "Extra data used = $off, len = " . length($data) .
	    " extra = " . (length($data) - $off);
    }
    return \%resource;
}

######################################################################
# $data = encode_watr(\%resource);

sub encode_watr {
    my($resource) = @_;
    my($i, $j, $data, $dds);

    $data = pack("Z128", $$resource{'Name'});
    $data .= encode_color($$resource{'Water Color'});
    $data .= pack("f7", $$resource{'RippleX'}, $$resource{'RippleY'},
		  $$resource{'Smoothness'}, $$resource{'Ref Bias'},
		  $$resource{'Ref Power'},
		  $$resource{'Unknown 1'}, $$resource{'Unknown 2'});
    for($i = 0; $i < 3; $i++) {
	$data .= pack("Z32f4",
		      $$resource{'Texture'}[$i]{Name},
		      $$resource{'Texture'}[$i]{'X Direction'},
		      $$resource{'Texture'}[$i]{'Y Direction'},
		      $$resource{'Texture'}[$i]{'Rate'},
		      $$resource{'Texture'}[$i]{'Angle'});
    }
    $data .= pack("ffVV",
		  $$resource{'X8'}, $$resource{'Y8'},
		  $$resource{'Vertex Count'},
		  $$resource{'Triangle Count'});
    $data .= encode_vertex_watr($$resource{Vertex}{Data},
				$$resource{'Vertex Count'});
    $data .= encode_triangles($$resource{Triangle}{Data},
			      $$resource{'Triangle Count'});
    for($i = 0; $i < 24; $i++) {
	my(@c);
	@c = ();
	for($j = 0; $j < 48; $j++) {
	    push(@c, substr($$resource{Bitmap}[$i], $j, 1));
	}
	$data .= pack("V48", @c);
    }

    $dds = encode_dds($$resource{Textures}, 1, "0", "1", "2", "3");
    $data .= pack("V/a*", $dds);

    $data .= pack("VV", $$resource{X}, $$resource{Y});

    return $data;
}

######################################################################
# \%resource = decode_aswm($data, $linear)

sub decode_aswm {
    my($data) = @_;
    my(%resource, $i, $j, $comp, $infl, $out, $status, $off);

    ($resource{Type}, $resource{'Compressed Length'}, $resource{Length}) =
	unpack("A4VV", $data);
    $comp = substr($data, 12, $resource{'Compressed Length'});
    $off = 12;
    $off += $resource{'Compressed Length'};

    if ($off != length($data)) {
	croak "Extra data used = $off, len = " . length($data) .
	    " extra = " . (length($data) - $off);
    }
    $infl = inflateInit() || die "Cannot create inflation stream";
    ($out, $status) = $infl->inflate(\$comp);
    if ($status != Z_OK && $status != Z_STREAM_END) {
	warn "Could not decompress data: " . $infl->msg();
	return;
    }
    $off = 0;
    if (length($out) != $resource{Length}) {
	warn "Compressed length " . length($out) .
	    " does not match the outer data $resource{Length}";
    }
    if (length($comp) != 0) {
	warn "Extra data after compressed data len = " .
	    length($comp);
    }
    $resource{u1}{''} = 'unknown#';
    $resource{u1}{Data} = substr($out, 0, 37);
    $resource{u1C} = join(", ", unpack("C37", substr($out, 0, 37)));
    $resource{u1V} = join(", ", unpack("V9", substr($out, 0, 36)));
    $resource{u1xV} = join(", ", unpack("xV9", substr($out, 0, 37)));
    $resource{u1v} = join(", ", unpack("v18", substr($out, 0, 36)));
    $resource{u1xv} = join(", ", unpack("xv18", substr($out, 0, 37)));
    $off += 37;
    ($resource{'Point Count'},
     $resource{'Edge Count'},
     $resource{'Triangle Count'},
     $resource{u2}) =
	 unpack("VVVV", substr($out, $off, 16));
    $off += 16;
    for($i = 0; $i < $resource{'Point Count'}; $i++) {
	$resource{'Points'}[$i]{''} = '-xyz';
	($resource{'Points'}[$i]{'x'},
	 $resource{'Points'}[$i]{'y'},
	 $resource{'Points'}[$i]{'z'}) = 
	     unpack("f3", substr($out, $off + $i * 12, 12));
    }
    $off += 12 * $resource{'Point Count'};
    for($i = 0; $i < $resource{'Edge Count'}; $i++) {
	$resource{'Edges'}[$i]{'Points'}{''} = '-ii';
	$resource{'Edges'}[$i]{'Triangles'}{''} = '-ii';
	# p1 and p2 are walkmesh edge indexes to Points table
	# p3 and p4 are the indexes to Triangles table where those
	# edges are used (-1 means only one index)
	($resource{'Edges'}[$i]{'Points'}{'i'}[0],
	 $resource{'Edges'}[$i]{'Points'}{'i'}[1],
	 $resource{'Edges'}[$i]{'Triangles'}{'i'}[0],
	 $resource{'Edges'}[$i]{'Triangles'}{'i'}[1]) = 
	    unpack("V4", substr($out, $off + $i * 16, 16));
	for($j = 0; $j < 2; $j++) {
	    if ($resource{'Edges'}[$i]{'Triangles'}{'i'}[$j] == 4294967295) {
		$resource{'Edges'}[$i]{'Triangles'}{'i'}[$j] = -1;
	    }
	}
    }
    $off += 16 * $resource{'Edge Count'};
    
    for($i = 0; $i < $resource{'Triangle Count'}; $i++) {
	$resource{'Triangles'}[$i]{''} = '-hash';
	$resource{'Triangles'}[$i]{'Normal'}{''} = '-xyz';
	$resource{'Triangles'}[$i]{'Unknown'}{''} = '-xyz';
	$resource{'Triangles'}[$i]{'Corners'}{''} = '-iii';
	$resource{'Triangles'}[$i]{'Edges'}{''} = '-iii';
	$resource{'Triangles'}[$i]{'Neighbour Triangles'}{''} = '-iii';
	# p1, p2, p3 = Corner point indexes to Points table
	# p4, p5, p6 = Edge indexes to Edges Table
	# p7, p8, p9 = Neighbours indexes to Triangles table
	# xyz = center point of the triangle (normal of trinagle?)
	($resource{'Triangles'}[$i]{'Corners'}{'i'}[0],
	 $resource{'Triangles'}[$i]{'Corners'}{'i'}[1],
	 $resource{'Triangles'}[$i]{'Corners'}{'i'}[2],
	 $resource{'Triangles'}[$i]{'Edges'}{'i'}[0],
	 $resource{'Triangles'}[$i]{'Edges'}{'i'}[1],
	 $resource{'Triangles'}[$i]{'Edges'}{'i'}[2],
	 $resource{'Triangles'}[$i]{'Neighbour Triangles'}{'i'}[0],
	 $resource{'Triangles'}[$i]{'Neighbour Triangles'}{'i'}[1],
	 $resource{'Triangles'}[$i]{'Neighbour Triangles'}{'i'}[2],
	 $resource{'Triangles'}[$i]{'Normal'}{'x'},
	 $resource{'Triangles'}[$i]{'Normal'}{'y'},
	 $resource{'Triangles'}[$i]{'Normal'}{'z'},
	 $resource{'Triangles'}[$i]{'Unknown'}{'x'},
	 $resource{'Triangles'}[$i]{'Unknown'}{'y'},
	 $resource{'Triangles'}[$i]{'Unknown'}{'z'},
	 $resource{'Triangles'}[$i]{'X1%'},
	 $resource{'Triangles'}[$i]{'Flags%'}) =
	     unpack("V9f6vv", substr($out, $off + $i * 64, 64));
	for($j = 0; $j < 3; $j++) {
	    if ($resource{'Triangles'}[$i]{'Neighbour Triangles'}{'i'}[$j]
		== 4294967295) {
		$resource{'Triangles'}[$i] {'Neighbour Triangles'}{'i'}[$j]
		    = -1;
	    }
	}
    }
    $off += 64 * $resource{'Triangle Count'};

    if ($off != $resource{Length}) {
	warn "Extra compressed data off = $off, " .
	    "len = $resource{Length}, extra = " .
	    ($resource{Length} - $off);
	$resource{Extra}{Data} = substr($out, $off);
	$resource{Extra}{''} = '-unknown#';
    }
    return \%resource;
}

######################################################################
# $data = encode_aswm(\%resource);

sub encode_aswm {
    my($resource) = @_;
    my($i, $data);

    $data = $$resource{u1}{Data};
    $data .= pack("VVVV", $$resource{'Point Count'},
		  $$resource{'Edge Count'},
		  $$resource{'Triangle Count'},
		  $$resource{u2});
    for($i = 0; $i < $$resource{'Point Count'}; $i++) {
	$data .= pack("f3", 
		      $$resource{'Points'}[$i]{'x'},
		      $$resource{'Points'}[$i]{'y'},
		      $$resource{'Points'}[$i]{'z'});
    }
    for($i = 0; $i < $$resource{'Edge Count'}; $i++) {
	$data .= pack("V4", $$resource{'Edges'}[$i]{'Points'}{'i'}[0],
		      $$resource{'Edges'}[$i]{'Points'}{'i'}[1],
		      $$resource{'Edges'}[$i]{'Triangles'}{'i'}[0],
		      $$resource{'Edges'}[$i]{'Triangles'}{'i'}[1]);
    }
    for($i = 0; $i < $$resource{'Triangle Count'}; $i++) {
	$data .=
	    pack("V9f6vv", 
		 $$resource{'Triangles'}[$i]{'Corners'}{'i'}[0],
		 $$resource{'Triangles'}[$i]{'Corners'}{'i'}[1],
		 $$resource{'Triangles'}[$i]{'Corners'}{'i'}[2],
		 $$resource{'Triangles'}[$i]{'Edges'}{'i'}[0],
		 $$resource{'Triangles'}[$i]{'Edges'}{'i'}[1],
		 $$resource{'Triangles'}[$i]{'Edges'}{'i'}[2],
		 $$resource{'Triangles'}[$i]{'Neighbour Triangles'}{'i'}[0],
		 $$resource{'Triangles'}[$i]{'Neighbour Triangles'}{'i'}[1],
		 $$resource{'Triangles'}[$i]{'Neighbour Triangles'}{'i'}[2],
		 $$resource{'Triangles'}[$i]{'Normal'}{'x'},
		 $$resource{'Triangles'}[$i]{'Normal'}{'y'},
		 $$resource{'Triangles'}[$i]{'Normal'}{'z'},
		 $$resource{'Triangles'}[$i]{'Unknown'}{'x'},
		 $$resource{'Triangles'}[$i]{'Unknown'}{'y'},
		 $$resource{'Triangles'}[$i]{'Unknown'}{'z'},
		 $$resource{'Triangles'}[$i]{'X1%'},
		 $$resource{'Triangles'}[$i]{'Flags%'});
    }
    $data .= $$resource{Extra}{Data};

    if (length($data) != $$resource{Length}) {
	warn "Data lengths differ, data len = " .
	    length($data) . " resource has length of " .
	    $$resource{Length};
    }
    
    my($defl, $out, $out2, $status);
    $defl = deflateInit(-Level => Z_BEST_COMPRESSION)
	|| die "Cannot create deflate stream";
    ($out, $status) = $defl->deflate($data);
    if ($status != Z_OK && $status != Z_STREAM_END) {
	warn "Could not compress data: " . $defl->msg();
	return undef;
    }
    ($out2, $status) = $defl->flush();
    if ($status != Z_OK && $status != Z_STREAM_END) {
	warn "Could not compress data: " . $defl->msg();
	return undef;
    }
    $out .= $out2;
    if ($$resource{'Compressed Length'} != length($out)) {
	warn "Compressed data size differs: data size " .
	    length($out) . " vs resource size " . 
	    $$resource{'Compressed Length'};
    }
    return pack("A4VV", $$resource{Type}, length($out),
		length($data)) . $out;
}

######################################################################
# \%resource = decode_rigd($data, $linear)

sub decode_rigd {
    my($data, $linear) = @_;
    my(%resource, $off, $i, $len);

    $off = 0;
    ($resource{'Name'}) = unpack("Z32", $data);
    $off += 32;
    get_material(\%{$resource{'Material'}}, substr($data, $off, 164));
    $off += 164;
    ($resource{'Vertex Count'}, $resource{'Triangle Count'}) =
	unpack("VV", substr($data, $off, 8));
    $off += 8;
    $len = $resource{'Vertex Count'} * 60;
    decode_vertex_rigd(\@{$resource{Vertex}{Data}}, 
		       $resource{'Vertex Count'},
		       substr($data, $off, $len), $linear);
    $resource{Vertex}{''} = '-hash';
    $off += $len;
    $len = $resource{'Triangle Count'} * 6;
    decode_triangles(\@{$resource{Triangle}{Data}},
		     $resource{'Triangle Count'},
		     substr($data, $off, $len), $linear);
    $resource{Triangle}{''} = '-hash';
    return \%resource;
}

######################################################################
# $data = encode_rigd(\%resource);

sub encode_rigd {
    my($resource) = @_;

    return pack("Z32A*VVA*A*",
		$$resource{'Name'},
		encode_material($$resource{'Material'}),
		$$resource{'Vertex Count'}, $$resource{'Triangle Count'},
		encode_vertex_rigd($$resource{Vertex}{Data},
				   $$resource{'Vertex Count'}),
		encode_triangles($$resource{Triangle}{Data},
				 $$resource{'Triangle Count'}));
}

######################################################################
# \%resource = decode_walk($data, $linear)

sub decode_walk {
    my($data, $linear) = @_;
    my(%resource, $off, $i, $len);

    $off = 0;
    $resource{'Name'} = unpack("Z32", $data);
    $off += 32;
    ($resource{'Flags'}, $resource{'Vertex Count'},
     $resource{'Triangle Count'}) =
	 unpack("VVV", substr($data, $off, 12));
    $off += 12;
    $len = $resource{'Vertex Count'} * 12;
    decode_vertex_point3(\@{$resource{Vertex}{Data}}, 
		       $resource{'Vertex Count'},
		       substr($data, $off, $len), $linear);
    $resource{Vertex}{''} = '-hash';
    $off += $len;
    $len = $resource{'Triangle Count'} * 10;
    decode_wtri(\@{$resource{Triangle}{Data}},
		$resource{'Triangle Count'},
		substr($data, $off, $len), $linear);
    $resource{Triangle}{''} = '-hash';
    return \%resource;
}

######################################################################
# $data = encode_walk(\%resource);

sub encode_walk {
    my($resource) = @_;

    return pack("Z32VVVA*A*",
		$$resource{'Name'}, $$resource{'Flags'},
		$$resource{'Vertex Count'}, $$resource{'Triangle Count'},
		encode_vertex_point3($$resource{Vertex}{Data},
				     $$resource{'Vertex Count'}),
		encode_wtri($$resource{Triangle}{Data},
			    $$resource{'Triangle Count'}));
}

######################################################################
# \%resource = decode_col($data, $linear)

sub decode_col {
    my($data, $linear) = @_;
    my(%resource, $off, $i, $len);

    $off = 0;
    $resource{'Name'} = unpack("Z32", $data);
    $off += 32;
    get_material(\%{$resource{'Material'}}, substr($data, $off, 164));
    $off += 164;
    ($resource{'Vertex Count'}, $resource{'Triangle Count'}) =
	 unpack("VV", substr($data, $off, 8));
    $off += 8;
    $len = $resource{'Vertex Count'} * 36;
    decode_vertex_cvert(\@{$resource{Vertex}{Data}}, 
		       $resource{'Vertex Count'},
		       substr($data, $off, $len), $linear);
    $resource{Vertex}{''} = '-hash';
    $off += $len;
    $len = $resource{'Triangle Count'} * 6;
    decode_triangles(\@{$resource{Triangle}{Data}},
		     $resource{'Triangle Count'},
		     substr($data, $off, $len), $linear);
    $resource{Triangle}{''} = '-hash';
    return \%resource;
}

######################################################################
# $data = encode_col(\%resource);

sub encode_col {
    my($resource) = @_;

    return pack("Z32A*VVA*A*",
		$$resource{'Name'}, 
		encode_material($$resource{'Material'}),
		$$resource{'Vertex Count'}, $$resource{'Triangle Count'},
		encode_vertex_cvert($$resource{Vertex}{Data},
				    $$resource{'Vertex Count'}),
		encode_triangles($$resource{Triangle}{Data},
				 $$resource{'Triangle Count'}));
}

######################################################################
# \%resource = decode_hook($data, $linear)

sub decode_hook {
    my($data, $linear) = @_;
    my(%resource, $off, $i, $j);

    $off = 0;
    $resource{'Name'} = unpack("Z32", $data);
    $off += 32;
    ($resource{'Hook Point Type'}, $resource{'Hook Point Size'},
     $resource{'Position'}{x}, $resource{'Position'}{y},
     $resource{'Position'}{z}) = unpack("vvfff", substr($data, $off, 16));
    $resource{'Position'}{''} = 'xyz';
    $off += 16;
    for($j = 0; $j < 3; $j++) {
	for($i = 0; $i < 3; $i++) {
	    $resource{'Rotation'}[$j][$i] =
		unpack("f", substr($data, $off, 4));
	    $off += 4;
	}
    }
    return \%resource;
}

######################################################################
# $data = encode_hook(\%resource);

sub encode_hook {
    my($resource) = @_;

    return pack("Z32vvf3f9",
		$$resource{'Name'}, $$resource{'Hook Point Type'},
		$$resource{'Hook Point Size'},
		$$resource{'Position'}{x},
		$$resource{'Position'}{y},
		$$resource{'Position'}{z},
		$$resource{'Rotation'}[0][0],
		$$resource{'Rotation'}[0][1],
		$$resource{'Rotation'}[0][2],
		$$resource{'Rotation'}[1][0],
		$$resource{'Rotation'}[1][1],
		$$resource{'Rotation'}[1][2],
		$$resource{'Rotation'}[2][0],
		$$resource{'Rotation'}[2][1],
		$$resource{'Rotation'}[2][2]);
}

######################################################################
# \%resource = decode_resource($resource_data, [$resource_type], $linear)

sub decode_resource {
    my($data, $type, $linear) = @_;
    my($type2, $len);

    ($type2, $len) = unpack("A4V", $data);
    if (!defined($type)) {
	$type = $type2;
    } elsif ($type2 ne $type) {
	carp "Resource type $type2 is not matching the given type $type";
    }
    if ($len + 8 < length($data)) {
	carp "Extra data after the resource: " .
	    (length($data) - $len - 8) . " bytes";
    } elsif ($len + 8 > length($data)) {
	croak "Not enough data to decode, length = " . ($len + 8) .
	    ", data length = " . length($data);
    }
    if ($type eq 'TRWH') {
	return decode_trwh(substr($data, 8, $len), $linear);
    } elsif ($type eq 'TRRN') {
	return decode_trrn(substr($data, 8, $len), $linear);
    } elsif ($type eq 'WATR') {
	return decode_watr(substr($data, 8, $len), $linear);
    } elsif ($type eq 'ASWM') {
	return decode_aswm(substr($data, 8, $len), $linear);
    } elsif ($type eq 'RIGD') {
	return decode_rigd(substr($data, 8, $len), $linear);
    } elsif ($type eq 'WALK') {
	return decode_walk(substr($data, 8, $len), $linear);
    } elsif ($type eq 'COL2') {
	return decode_col(substr($data, 8, $len), $linear);
    } elsif ($type eq 'COL3') {
	return decode_col(substr($data, 8, $len), $linear);
    } elsif ($type eq 'HOOK') {
	return decode_hook(substr($data, 8, $len), $linear);
    } else {
	croak "Invalid type: $type";
    }
}

######################################################################
# \%data = $self->decode($index, $linear);

sub decode {
    my $self = shift;
    my $index = shift;
    my $linear = shift;

    return decode_resource($self->{resource_data}[$index],
			   $self->{resource_type}[$index],
			   $linear);
}

######################################################################
# $data = encode_resource(\%resource_data, $type)

sub encode_resource {
    my($resource, $type) = @_;
    my($len, $data);

    if ($type eq 'TRWH') {
	$data = encode_trwh($resource);
    } elsif ($type eq 'TRRN') {
	$data = encode_trrn($resource);
    } elsif ($type eq 'WATR') {
	$data = encode_watr($resource);
    } elsif ($type eq 'ASWM') {
	$data = encode_aswm($resource);
    } elsif ($type eq 'RIGD') {
	$data = encode_rigd($resource);
    } elsif ($type eq 'WALK') {
	$data = encode_walk($resource);
    } elsif ($type eq 'COL2') {
	$data = encode_col($resource);
    } elsif ($type eq 'COL3') {
	$data = encode_col($resource);
    } elsif ($type eq 'HOOK') {
	$data = encode_hook($resource);
    } else {
	croak "Invalid type: $type";
    }
    return pack("A4V", $type, length($data)) . $data;
}

######################################################################
# $data = $self->encode($index, \%data, $type);

sub encode {
    my $self = shift;
    my $index = shift;
    my $data = shift;

    if (@_) { $self->{resource_type}[$index] = $_[0]; }
    $self->{resource_data}[$index] =
	encode_resource($data, $self->{resource_type}[$index]);
    $self->{resource_size}[$index] = length($self->{resource_data}[$index]);
    return $self->{resource_data}[$index];
}

######################################################################
# \%data = rotate(\%data, $quaternion);

sub rotate {
    my($data, $q) = @_;
    my($i, $item);
    
    if (UNIVERSAL::isa($data, 'ARRAY')) {
	foreach $item (@{$data}) {
	    rotate($item, $q);
	}
    } elsif (UNIVERSAL::isa($data, 'HASH')) {
	if (defined($$data{''}) &&
	    $$data{''} =~ /^-?xyz$/) {
	    ($$data{x}, $$data{y}, $$data{z})
		= $q->rotate_vector($$data{x}, $$data{y}, $$data{z});
	} else {
	    foreach $i (sort keys %{$data}) {
		$item = $$data{$i};
		rotate($item, $q);
	    }
	}
    }
    return $data;
}

######################################################################
# \%data = translate(\%data, $x, $y, $z, $field, $parent);

sub translate {
    my($data, $x, $y, $z, $field, $parent) = @_;
    my($i, $item);
    
    if (UNIVERSAL::isa($data, 'ARRAY')) {
	foreach $item (@{$data}) {
	    translate($item, $x, $y, $z, $field, $parent);
	}
    } elsif (UNIVERSAL::isa($data, 'HASH')) {
	if (defined($$data{''}) &&
	    $$data{''} =~ /^-?xyz$/ &&
	    ((defined($parent) && defined($field) && $parent eq $field) ||
	     (!defined($parent) || !defined($field)))) {
	    $$data{x} += $x;
	    $$data{y} += $y;
	    $$data{z} += $z;
	} else {
	    foreach $i (sort keys %{$data}) {
		$item = $$data{$i};
		translate($item, $x, $y, $z, $field, $i);
	    }
	}
    }
    return $data;
}

######################################################################
# ($minx, $miny, $minz, $maxx, $maxy, $maxz) =
# find_bbox(\%data, $field, $parent);

sub find_bbox {
    my($data, $field, $parent) = @_;
    my($i, $item, @ret, @tmp);

    if (UNIVERSAL::isa($data, 'ARRAY')) {
	foreach $item (@{$data}) {
	    @tmp = find_bbox($item, $field, $parent);
	    next if ($#tmp == -1);
	    $ret[0] = $tmp[0] if (!defined($ret[0]) || $tmp[0] < $ret[0]);
	    $ret[1] = $tmp[1] if (!defined($ret[1]) || $tmp[1] < $ret[1]);
	    $ret[2] = $tmp[2] if (!defined($ret[2]) || $tmp[2] < $ret[2]);
	    $ret[3] = $tmp[3] if (!defined($ret[3]) || $tmp[3] > $ret[3]);
	    $ret[4] = $tmp[4] if (!defined($ret[4]) || $tmp[4] > $ret[4]);
	    $ret[5] = $tmp[5] if (!defined($ret[5]) || $tmp[5] > $ret[5]);
	}
    } elsif (UNIVERSAL::isa($data, 'HASH')) {
	if (defined($$data{''}) &&
	    $$data{''} =~ /^-?xyz$/ &&
	    ((defined($parent) && defined($field) && $parent eq $field) ||
	     (!defined($parent) || !defined($field)))) {
	    $ret[0] = $$data{x} if (!defined($ret[0]) || $$data{x} < $ret[0]);
	    $ret[1] = $$data{y} if (!defined($ret[1]) || $$data{y} < $ret[1]);
	    $ret[2] = $$data{z} if (!defined($ret[2]) || $$data{z} < $ret[2]);
	    $ret[3] = $$data{x} if (!defined($ret[3]) || $$data{x} > $ret[3]);
	    $ret[4] = $$data{y} if (!defined($ret[4]) || $$data{y} > $ret[4]);
	    $ret[5] = $$data{z} if (!defined($ret[5]) || $$data{z} > $ret[5]);
	} else {
	    foreach $i (sort keys %{$data}) {
		$item = $$data{$i};
		@tmp = find_bbox($item, $field, $i);
		next if ($#tmp == -1);
		$ret[0] = $tmp[0] if (!defined($ret[0]) || $tmp[0] < $ret[0]);
		$ret[1] = $tmp[1] if (!defined($ret[1]) || $tmp[1] < $ret[1]);
		$ret[2] = $tmp[2] if (!defined($ret[2]) || $tmp[2] < $ret[2]);
		$ret[3] = $tmp[3] if (!defined($ret[3]) || $tmp[3] > $ret[3]);
		$ret[4] = $tmp[4] if (!defined($ret[4]) || $tmp[4] > $ret[4]);
		$ret[5] = $tmp[5] if (!defined($ret[5]) || $tmp[5] > $ret[5]);
	    }
	}
    }
    return @ret;
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################

__END__

=head1 NAME

Trn - Perl Module to modify Trn datastructures in memory

=head1 ABSTRACT

This module includes functions to read, and modify trn objects. The
objects are represented as array of resources, each having resource
type, size, and data.

=head1 DESCRIPTION

You first need either to greate new B<Trn> with B<Trn::new> or read
trn structure from disk using B<TrnRead::read>. Then you can modify
the trn structure in memory with functions defined here (or simply
reading values from hash table or assigning new values to them). When
you are done you can write trn back to disk using B<TrnWrite::write>.

=head1 B<Trn::new>

B<Trn::new> is used to bless any other hash to be B<Trn> hash or just
to return new empty B<Trn> hash.

=over 4

=head2 USAGE

\%trn = Trn->new();
\%trn = Trn->new(\%hash);

=back

=head1 B<Trn::file_type>

B<Trn::file_type> is used either to set or get file type. 

=over 4

=head2 USAGE

$file_type = $trn->file_type();
$file_type = $trn->file_type($file_type);

=back

=head1 B<Trn::version_major>

B<Trn::version_major> is used either to set or get file major version
number. Currently this matches 2 (nwn2). 

=over 4

=head2 USAGE

$version_major = $trn->version_major();
$version_major = $trn->version_major($version_major);

=back

=head1 B<Trn::version_minor>

B<Trn::version_minor> is used either to set or get file minor version
number. Currently this matches 3 (1.03?). 

=over 4

=head2 USAGE

$version_minor = $trn->version_minor();
$version_minor = $trn->version_minor($version_minor);

=back

=head1 B<Trn::resource_count>

B<Trn::resource_count> is used either to return or set the number of
resources in the trn/trx file.

=over 4

=head2 USAGE

$resource_count = $trn->resource_count();
$resource_count = $trn->resource_count($resource_count);

=back

=head1 B<Trn::resource_type>

B<Trn::resource_type> is used either to return or set the resource
type for given resource number. This can be 4 letter string, and is
normally 'TRRH' (header), 'TRRN' (terrain), 'WATR' (water), or 'ASWM'
(walkmesh).

=over 4

=head2 USAGE

$resource_type = $trn->resource_type($index);
$resource_type = $trn->resource_type($index, $resource_type);

=back

=head1 B<Trn::resource_size>

B<Trn::resource_size> is used either to return or set the resource
size for given resource index. 

=over 4

=head2 USAGE

$resource_size = $trn->resource_size($index);
$resource_size = $trn->resource_size($index, $resource_size);

=back

=head1 B<Trn::new_resource>

B<Trn::new_resource> is used to add new resource to the trn/trx file.
Resource data and type must be given, and size can be given (normally
it is take from the length of the resource_data. This returns the new
index used to store the resource. 

=over 4

=head2 USAGE

$resource_index = $trn->new_resource($resource_data, $resource_type);
$resource_index = $trn->new_resource($resource_data, $resource_type,
				     $resource_size);

=back

=head1 B<Trn::resource_data>

B<Trn::resource_data> is used either to return or set the resource
data for given resource index. If resource data is set then the
resource_size is also set.

=over 4

=head2 USAGE

$resource_data = $trn->resource_data($index);
$resource_data = $trn->resource_data($index, $resource_data);

=back

=back

=head1 SEE ALSO

trnunpack(1), TrnRead(3), and TrnWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Created to do walkmesh height setter.

=cut
