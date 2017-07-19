#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# Key.pm -- Generic Key functions
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: Key.pm
#	  $Source: /u/samba/nwn/perllib/RCS/Key.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 15:47 Aug 14 2004 kivinen
#	  Last Modification : 13:14 Sep 29 2005 kivinen
#	  Last check in     : $Date: 2005/10/11 15:10:13 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.54
#	  Edit time	    : 35 min
#
#	  Description       : Generic Key table functions
#
#	  $Log: Key.pm,v $
#	  Revision 1.2  2005/10/11 15:10:13  kivinen
#	  	Fixed to use path when reading files.
#
#	  Revision 1.1  2004/08/15 12:34:32  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package Key;
use strict;
use Carp;
use Erf;
use Bif;
use BifRead;

######################################################################
# \%key = new Key;
#

sub new {
    my(%self);
    my($year, $yday);
    my(@file_sizes, @drives, @file_names, @res_refs, @res_types, @res_ids);

    (undef, undef, undef, undef, undef, $year, undef, $yday) =
	localtime(time());
    ($self{file_type}, $self{file_version}, $self{bif_count}, $self{key_count},
     $self{build_year}, $self{build_day}) =
	 ('KEY ', 'V1  ', 0, 0, $year, $yday, -1);

    @file_sizes = ();
    @drives = ();
    @file_names = ();
    @res_refs = ();
    @res_types = ();
    @res_ids = ();
    $self{file_size} = \@file_sizes;
    $self{drive} = \@drives;
    $self{file_name} = \@file_names;
    $self{resource_reference} = \@res_refs;
    $self{resource_type} = \@res_types;
    $self{resource_id} = \@res_ids;

    bless \%self, "Key";
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
# $bif_count = $self->bif_count
# $self->bif_count(new_bif_count)

sub bif_count {
    my $self = shift;
    if (@_) { $self->{bif_count} = $_[0] }
    return $self->{bif_count};
}

######################################################################
# $key_count = $self->key_count
# $self->key_count(new_key_count)

sub key_count {
    my $self = shift;
    if (@_) { $self->{key_count} = $_[0] }
    return $self->{key_count};
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
# $file_size = $self->file_size($index);
# $self->file_size($index, $file_size);

sub file_size {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{file_size}[$index] = $_[0] }
    return $self->{file_size}[$index];
}

######################################################################
# $drives = $self->drive($index);
# $self->drives($index, $drive);

sub drive {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{drive}[$index] = $_[0] }
    return $self->{drive}[$index];
}

######################################################################
# $file_names = $self->file_name($index);
# $self->file_name($index, $file_names);

sub file_name {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{file_name}[$index] = $_[0] }
    return $self->{file_name}[$index];
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
# $resource_filename = $self->resource_filename($index);

sub resource_filename {
    my $self = shift;
    my $index = shift;
    my $id = $self->{resource_id}[$index];
    $id = $id >> 20;
    return $self->{file_name}[$id];
}

######################################################################
# $resource_drive = $self->resource_drive($index);

sub resource_drive {
    my $self = shift;
    my $index = shift;
    my $id = $self->{resource_id}[$index];
    $id = $id >> 20;
    return $self->{drive}[$id];
}

######################################################################
# $resource_index = $self->resource_index($index);

sub resource_index {
    my $self = shift;
    my $index = shift;
    my $id = $self->{resource_id}[$index];
    return $id & 0xfffff;
}

######################################################################
# $resource_extension = $self->resource_extension($index);
# $self->resource_extension($index, $resource_extension);

sub resource_extension {
    my $self = shift;
    my $index = shift;
    my $ext;
    if (@_) { $self->{resource_type}[$index] =
		  $Erf::extensions2types{$_[0]}; }
    $ext = $Erf::types2extensions{$self->{resource_type}[$index]};
    if (!defined($ext)) {
	carp "Invalid type $self->{resource_type}[$index] index $index";
    }
    return $ext;
}

######################################################################
# $bif = $self->file($index)

sub file {
    my $self = shift;
    my $index = shift;

    return Bif::read(filename => $self->{file_name}[$index]);
}

######################################################################
# $data = $self->resource_data($index);

sub resource_data {
    my $self = shift;
    my $index = shift;
    my($bif_index, $bif_file);

    $bif_index = $self->{resource_id}[$index] & 0xfffff;
    $bif_file = $self->{resource_id}[$index] >> 20;
    if (!defined($self->{current_index}) ||
	$self->{current_index} != $bif_file) {
	$self->{current_index} = $bif_file;
	$self->{current_bif} =
	    BifRead::read(filename => $self->{path} .
			  $self->resource_filename($index));
    }

    if ($self->{current_bif}->resource_type($bif_index) !=
	$self->{resource_type}[$index]) {
	crock("Bif type $self->{current_bif}->resource_type($bif_index) " .
	      "does not match key file type $self->{resource_type}[$index]");
    }

    return $self->{current_bif}->resource_data($bif_index);
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
