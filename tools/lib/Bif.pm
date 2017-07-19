#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# Bif.pm -- Generic erf functions
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: Bif.pm
#	  $Source: /u/kivinen/nwn/perllib/RCS/Bif.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 17:05 Aug 15 2004 kivinen
#	  Last Modification : 17:13 Aug 15 2004 kivinen
#	  Last check in     : $Date: 2004/08/15 12:33:26 $
#	  Revision number   : $Revision: 1.1 $
#	  State             : $State: Exp $
#	  Version	    : 1.6
#	  Edit time	    : 3 min
#
#	  Description       : Generic bif functions
#
#	  $Log: Bif.pm,v $
#	  Revision 1.1  2004/08/15 12:33:26  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package Bif;
use strict;
use Carp;
use Erf;

######################################################################
# \%erf = new Bif;
#

sub new {
    my(%self);
    my(@resource_offsets, @resource_sizes, @resource_types);

    ($self{file_type}, $self{file_version}, 
     $self{variable_resource_count}, $self{fixed_resource_count}) =
	 ('UNKN', 'V1  ', 0, 0);

    @resource_offsets = ();
    @resource_sizes = ();
    @resource_types = ();

    $self{resource_offset} = \@resource_offsets;
    $self{resource_type} = \@resource_types;
    $self{resource_size} = \@resource_sizes;

    bless \%self, "Bif";
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
# $variable_resource_count = $self->variable_resource_count
# $self->variable_resource_count(new_variable_resource_count)

sub variable_resource_count {
    my $self = shift;
    if (@_) { $self->{variable_resource_count} = $_[0] }
    return $self->{variable_resource_count};
}

######################################################################
# $fixed_resource_count = $self->fixed_resource_count
# $self->fixed_resource_count(new_fixed_resource_count)

sub fixed_resource_count {
    my $self = shift;
    if (@_) { $self->{fixed_resource_count} = $_[0] }
    return $self->{fixed_resource_count};
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
# $resource_extension = $self->resource_extension($index);
# $self->resource_extension($index, $resource_extension);

sub resource_extension {
    my $self = shift;
    my $index = shift;
    if (@_) { $self->{resource_type}[$index] =
		  $Erf::extensions2types{$_[0]}; }
    return $Erf::types2extensions{$self->{resource_type}[$index]};
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
