#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# Erf.pm -- Generic erf functions
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: Erf.pm
#	  $Source: /u/samba/nwn/perllib/RCS/Erf.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 07:23 Jul 31 2004 kivinen
#	  Last Modification : 05:18 Jan 25 2007 kivinen
#	  Last check in     : $Date: 2007/01/25 03:18:53 $
#	  Revision number   : $Revision: 1.10 $
#	  State             : $State: Exp $
#	  Version	    : 1.168
#	  Edit time	    : 109 min
#
#	  Description       : Generic erf functions
#
#	  $Log: Erf.pm,v $
#	  Revision 1.10  2007/01/25 03:18:53  kivinen
#	  	Fixed cases where filename has multiple dots.
#
#	  Revision 1.9  2007/01/10 14:17:25  kivinen
#	  	Added all nwn2 extension types. Added support for unknown
#	  	extension types.
#
#	  Revision 1.8  2006/12/21 17:47:27  kivinen
#	  	Nuke windows path names too.
#
#	  Revision 1.7  2006/11/15 00:46:56  kivinen
#	  	Added ult.
#
#	  Revision 1.6  2006/11/03 22:11:49  kivinen
#	  	Added xml type.
#
#	  Revision 1.5  2006/10/25 19:58:37  kivinen
#	  	Changed so that extensions are lowercased before searched from
#	  	the extensions2types hash.
#
#	  Revision 1.4  2006/10/25 18:23:55  kivinen
#	  	Added upe, sef, pfx file extensions. Added resource_has_data
#	  	function. Added support for filenames > 16 characters.
#
#	  Revision 1.3  2006/10/24 21:10:59  kivinen
#	  	Updated to understand 1.1 version.
#
#	  Revision 1.2  2004/12/06 13:26:02  kivinen
#	  	Added support for adding file and data to Erf without having
#	  	the actual file on disk.
#
#	  Revision 1.1  2004/08/15 12:33:33  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package Erf;
use strict;
use Carp;

######################################################################
# \%erf = new Erf;
#

sub new {
    my(%self);
    my($year, $yday);
    my(%localized_strings, @res_refs, @res_types, @res_offsets, @res_sizes);
    my(@res_data, @res_filenames);

    (undef, undef, undef, undef, undef, $year, undef, $yday) =
	localtime(time());
    ($self{file_type}, $self{file_version}, $self{language_count},
     $self{build_year}, $self{build_day}, $self{description_string_ref}) =
	 ('UNKN', 'V1.0', 0, $year, $yday, -1);

    $self{resource_count} = 0;

    %localized_strings = ();
    $self{localized_strings} = \%localized_strings;

    @res_refs = ();
    @res_types = ();
    @res_offsets = ();
    @res_sizes = ();
    $self{resource_reference} = \@res_refs;
    $self{resource_type} = \@res_types;
    $self{resource_offset} = \@res_offsets;
    $self{resource_size} = \@res_sizes;

    @res_data = ();
    @res_filenames = ();
    $self{resource_data} = \@res_data;
    $self{resource_filename} = \@res_filenames;
    bless \%self, "Erf";
    return \%self;
}

######################################################################
# $file_type = $self->file_type
# $self->file_type("New type")

sub file_type {
    my $self = shift;
    if (@_) { $self->{file_type} = $_[0] }
    return $self->{file_type};
}

######################################################################
# $file_version = $self->file_version
# $self->file_version("New version")

sub file_version {
    my $self = shift;
    if (@_) { $self->{file_version} = $_[0] }
    return $self->{file_version};
}

######################################################################
# $language_count = $self->language_count
# $self->language_count(new_language_count)

sub language_count {
    my $self = shift;
    if (@_) { $self->{language_count} = $_[0] }
    return $self->{language_count};
}

######################################################################
# $localized_string = $self->localized_string($language_id);
# $self->localized_string($language_id, $localized_string);
# (@language_ids) = $self->localized_string

sub localized_string {
    my $self = shift;
    if ($#_ == -1) {
	return keys %{$self->{localized_strings}};
    }
    my $language_id = shift;
    if (@_) { $self->{localized_strings}{$language_id} = $_[0]; }
    return $self->{localized_strings}{$language_id};
}

######################################################################
# $build_year = $self->build_year
# $self->build_year(new_build_year)

sub build_year {
    my $self = shift;
    if (@_) { $self->{build_year} = $_[0] }
    return $self->{build_year};
}

######################################################################
# $build_day = $self->build_day
# $self->build_day(new_build_day)

sub build_day {
    my $self = shift;
    if (@_) { $self->{build_day} = $_[0] }
    return $self->{build_day};
}

######################################################################
# $description_string_ref = $self->description_string_ref
# $self->description_string_ref(new_descr_str_ref)

sub description_string_ref {
    my $self = shift;
    if (@_) { $self->{description_string_ref} = $_[0] }
    return $self->{description_string_ref};
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
# $resource_reference = $self->resource_reference($index);
# $self->resource_reference($index, $resource_reference);

sub resource_reference {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{resource_reference}[$index] = $_[0] }
    return $self->{resource_reference}[$index];
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
# $resource_offset = $self->resource_offset($index);
# $self->resource_offset($index, $resource_offset);

sub resource_offset {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{resource_offset}[$index] = $_[0] }
    return $self->{resource_offset}[$index];
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
# $resource_index = $self->new_resource($resource_reference, $resource_type,
#					[$resource_size, $resource_offset]);

sub new_resource {
    my $self = shift;
    my($index);

    if ($#_ < 1) {
	croak "Too few arguments to new_resource";
    }
	
    $index = $self->{resource_count}++;
    $self->resource_reference($index, $_[0]);
    $self->resource_type($index, $_[1]);
    $self->resource_size($index, $_[2]);
    $self->resource_offset($index, $_[3]);
    return $index;
}

######################################################################
# Conversion from extensions to types and back.

%Erf::extensions2types = ('res' => 0,
			  'bmp' => 1,
			  'mve' => 2,
			  'tga' => 3,
			  'wav' => 4,
			  'wfx' => 5,
			  'plt' => 6,
			  'ini' => 7,
			  'mp3' => 8,
			  'mpg' => 9,
			  'txt' => 10,
			  'plh' => 2000,
			  'tex' => 2001,
			  'mdl' => 2002,
			  'thg' => 2003,
			  'fnt' => 2005,
			  'lua' => 2007,
			  'slt' => 2008,
			  'nss' => 2009,
			  'ncs' => 2010,
			  'mod' => 2011,
			  'are' => 2012,
			  'set' => 2013,
			  'ifo' => 2014,
			  'bic' => 2015,
			  'wok' => 2016,
			  '2da' => 2017,
			  'tlk' => 2018,
			  'txi' => 2022,
			  'git' => 2023,
			  'bti' => 2024,
			  'uti' => 2025,
			  'btc' => 2026,
			  'utc' => 2027,
			  'dlg' => 2029,
			  'itp' => 2030,
			  'btt' => 2031,
			  'utt' => 2032,
			  'dds' => 2033,
			  'bts' => 2034,
			  'uts' => 2035,
			  'ltr' => 2036,
			  'gff' => 2037,
			  'fac' => 2038,
			  'bte' => 2039,
			  'ute' => 2040,
			  'btd' => 2041,
			  'utd' => 2042,
			  'btp' => 2043,
			  'utp' => 2044,
			  'dft' => 2045,
			  'gic' => 2046,
			  'gui' => 2047,
			  'css' => 2048,
			  'ccs' => 2049,
			  'btm' => 2050,
			  'utm' => 2051,
			  'dwk' => 2052,
			  'pwk' => 2053,
			  'btg' => 2054,
			  'utg' => 2055,
			  'jrl' => 2056,
			  'sav' => 2057,
			  'utw' => 2058,
			  '4pc' => 2059,
			  'ssf' => 2060,
			  'hak' => 2061,
			  'nwm' => 2062,
			  'bik' => 2063,
			  'ndb' => 2064,
			  'ptm' => 2065,
			  'ptt' => 2066,
			  'bak' => 2067,
			  'osc' => 3000,
			  'usc' => 3001,
			  'trn' => 3002,
			  'utr' => 3003,
			  'uen' => 3004,
			  'ult' => 3005,
			  'sef' => 3006,
			  'pfx' => 3007,
			  'cam' => 3008,
			  'lfx' => 3009,
			  'bfx' => 3010,
			  'upe' => 3011,
			  'ros' => 3012,
			  'rst' => 3013,
			  'ifx' => 3014,
			  'pfb' => 3015,
			  'zip' => 3016,
			  'wmp' => 3017,
			  'bbx' => 3018,
			  'tfx' => 3019,
			  'wlk' => 3020,
			  'xml' => 3021,
			  'scc' => 3022,
			  'ptx' => 3033,
			  'ltx' => 3034,
			  'trx' => 3035,
			  'mdb' => 4000,
			  'mda' => 4001,
			  'spt' => 4002,
			  'gr2' => 4003,
			  'fxa' => 4004,
			  'fxe' => 4005,
			  'jpg' => 4007,
			  'pwc' => 4008,
			  'ids' => 9996,
			  'erf' => 9997,
			  'bif' => 9998,
			  'key' => 9999,
			  );
map {
    $Erf::types2extensions{$Erf::extensions2types{$_}} = $_;
} keys(%Erf::extensions2types);

######################################################################
# $resource_extension = $self->resource_extension($index);
# $self->resource_extension($index, $resource_extension);

sub resource_extension {
    my $self = shift;
    my $index = shift;
    my($ext);
    if (@_) {
	$self->{resource_type}[$index] =
	    $Erf::extensions2types{lc($_[0])};
	if (!defined($self->{resource_type}[$index])) {
	    carp "Unknown resource extension: $_[0]";
	    if ($_[0] =~ /^\d+$/) {
		$self->{resource_type}[$index] = $_[0] + 0;
	    }
	}
    }
    if ($self->{resource_type}[$index] > 3000) {
	$self->file_version("V1.1");
    }
    $ext = $Erf::types2extensions{$self->{resource_type}[$index]};
    if (!defined($ext)) {
	carp "Unknown resource extension number: " .
	    $self->{resource_type}[$index];
	$ext = sprintf("%04d", $self->{resource_type}[$index]);
    }
    return $ext;
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
    if (!defined($self->{resource_size}[$index])) {
	croak "Unknown resource";
    }
    if (defined($self->{resource_data}[$index])) {
	return $self->{resource_data}[$index];
    }
    if (defined($self->{resource_filename}[$index])) {
	open(FILE, "<$self->{resource_filename}[$index]") ||
	    croak "Cannot open $self->{resource_filename}[$index] : $!";
	binmode(FILE);
	if (sysread(FILE, $data, $self->{resource_size}[$index]) !=
	    $self->{resource_size}[$index]) {
	    croak "Cannot read data from " .
		$self->{resource_filename}[$index] . " : $!";
	}
	close(FILE);
	return $data;
    }
    if (defined($self->{options}{filename})) {
	# We have file...
	if (!sysseek($self->{file}, $self->{seek_pos} +
		     $self->{resource_offset}[$index], 0)) {
	    croak "Cannot seek to " .
		($self->{seek_pos} + $self->{resource_offset}[$index]);
	}
	if (sysread($self->{file}, $data,
		    $self->{resource_size}[$index]) !=
	    $self->{resource_size}[$index]) {
	    croak "Cannot read data : $!";
	}
    } else {
	if ($self->{seek_pos} + $self->{resource_offset}[$index] +
	    $self->{resource_size}[$index] >
	    length($self->{options}{data})) {
	    croak "End of data";
	}
	$data = substr($self->{options}{data},
		       $self->{seek_pos} +
		       $self->{resource_offset}[$index], 
		       $self->{resource_size}[$index]);
    }
    return $data;
}

######################################################################
# $has_data = $self->resource_has_data($index);

sub resource_has_data {
    my $self = shift;
    my $index = shift;
    return defined($self->{resource_data}[$index]);
}

######################################################################
# $resource_filename = $self->resource_filename($index);
# $self->resource_filename($index, $filename);

sub resource_filename {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{resource_filename}[$index] = $_[0] }
    return $self->{resource_filename}[$index];
}

######################################################################
# $resource_index = $self->new_file($filename);
# $resource_index = $self->new_file($filename, $data);

sub new_file {
    my $self = shift;
    my($index, $filename, $extension, $data);

    if ($#_ < 0 || $#_ > 1 ) {
	croak "Invalind number of arguments to new_file";
    }

    $filename = shift;
    $index = $self->{resource_count}++;
    $self->resource_filename($index, $filename);
    
    if ($#_ >= 0) {
	$data = shift;
	$self->resource_data($index, $data);
    } else {
	if (!-f $filename) {
	    croak "Cannot find $filename";
	}
	$self->resource_size($index, (stat(_))[7]);
    }
    $filename =~ s/^.*[\/\\]//g;
    $filename =~ s/\.([^.]*)$//g;
    $extension = $1;
    if (length($filename) > 32) {
	croak "Filename length too long : $filename, max length 32 chars";
    }
    if (length($filename) > 16) {
	$self->file_version("V1.1");
    }
    $self->resource_reference($index, $filename);
    $self->resource_extension($index, $extension);
    if (!defined($self->resource_type($index))) {
	croak "Unknown extension : $extension";
    }
    $self->resource_offset($index, undef);
    return $index;
}

######################################################################
# DESTROY(self);
sub DESTROY {
    my $self = shift;
    if (defined($self->{file})) {
	close($self->{file});
	undef $self->{file};
    }
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
