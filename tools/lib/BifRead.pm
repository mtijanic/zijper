#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# BifRead.pm -- Bif parser module
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: BifRead.pm
#	  $Source: /u/samba/nwn/perllib/RCS/BifRead.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 14:58 Aug 15 2004 kivinen
#	  Last Modification : 13:17 Sep 29 2005 kivinen
#	  Last check in     : $Date: 2005/10/11 15:07:13 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.26
#	  Edit time	    : 13 min
#
#	  Description       : Bif file parser module
#
#	  $Log: BifRead.pm,v $
#	  Revision 1.2  2005/10/11 15:07:13  kivinen
#	  	Commented out some debug prints.
#
#	  Revision 1.1  2004/08/15 12:33:30  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package BifRead;
use strict;
use Carp;
use Bif;

######################################################################
# \%key = read(%options);
#
# Options can be:
#
# seek_pos	=> offset
#		Position to seek in file or data.
#
# filename	=> filename
#		Filename to read data from. If this exits, then data is
#		ignored.
#
# data		=> data
#		Data buffer to use instead of filename. This only used if
#		filename is no present.
#
# return_errors	=> boolean
#		If false then die on errors, otherwise return undef on error

sub read {
    my(%options) = @_;
    my(%self);
    my($offset_to_variable_table);
    my(@resource_ids, @resource_offsets, @resource_sizes, @resource_types);
    my($data, $off, $i);
    
    if (defined($options{filename})) {
	if (!open($self{file}, "<$options{filename}")) {
	    return error(\%self, "Cannot open $options{filename}");
	}
	binmode($self{file});
    }

    $self{options} = \%options;
    $self{seek_pos} = $options{seek_pos};
    $self{seek_pos} = 0 if (!defined($self{seek_pos}));

    $off = 0;

    if (defined($options{seek_pos})) {
	$off = $options{seek_pos};
	if (defined($options{filename})) {
	    if (!sysseek($self{file}, $options{seek_pos}, 0)) {
		return error(\%self, "Cannot seek");
	    }
	}
    }

    # Read the header

    if (defined($options{filename})) {
	if (sysread($self{file}, $data, 20) != 20) {
	    return error(\%self, "Could not read the header");
	}
    } else {
	if ($off + 20 > length($options{data})) {
	    return error(\%self, "End of data while reading header");
	}
	$data = substr($options{data}, $off, 20);
    }

    # Parse the header

    ($self{file_type}, $self{file_version},
     $self{variable_resource_count}, $self{fixed_resource_count},
     $offset_to_variable_table) =
	 unpack("a4a4VVV", $data);

#    print("Variable resource count = $self{variable_resource_count}\n");
#    print("Fixed resource count = $self{fixed_resource_count}\n");
#    print("Offset to variable table = $offset_to_variable_table\n");

    if ($self{file_version} ne "V1  ") {
	return error(\%self, "Invalid version : $self{file_version}");
    }

    if ($self{fixed_resource_count} != 0) {
	carp "Fixed resource count != 0 : " .
	    "$self{fixed_resource_count}, unimplemented";
    }

    # Read the string table

    if ($offset_to_variable_table != 20) {
	carp("Variable table not after header, " .
	     "offset = $offset_to_variable_table instead of 20");
	if (!sysseek($self{file}, $off + $offset_to_variable_table, 0)) {
	    return error(\%self, "Cannot seek");
	}
    }
    if (defined($options{filename})) {
	if (sysread($self{file}, $data, $self{variable_resource_count} * 16) !=
	    $self{variable_resource_count} * 16) {
	    return error(\%self, "Could not read variable reource table");
	}
    } else {
	if ($off + $offset_to_variable_table +
	    $self{variable_resource_count} * 16 >
	    length($options{data})) {
	    return error(\%self,
			 "End of data while reading variable resource table");
	}
	$data = substr($options{data}, $off + $offset_to_variable_table,
		       $self{variable_resource_count} * 16);
    }

    @resource_ids = unpack("Vx4x4x4" x $self{variable_resource_count},
			   $data);
    @resource_offsets = unpack("x4Vx4x4" x $self{variable_resource_count},
			       $data);
    @resource_sizes = unpack("x4x4Vx4" x $self{variable_resource_count},
			     $data);
    @resource_types = unpack("x4x4x4V" x $self{variable_resource_count},
			     $data);

    for($i = 0; $i <= $#resource_ids; $i++) {
	if (($resource_ids[$i] & 0xfffff) != $i) {
	    return error(\%self, "Warning file indexs do not match " .
			 "$resource_ids[$i] vs $i");
	}
    }

    $self{resource_offset} = \@resource_offsets;
    $self{resource_size} = \@resource_sizes;
    $self{resource_type} = \@resource_types;

    bless \%self, "Bif";
    return \%self;
}

######################################################################
# $ret = error(\%self, $text);

sub error {
    my($self, @text) = @_;

    print(@text, "\n");
    if (defined($$self{options}{return_errors}) &&
	$$self{options}{return_errors}) {
	return undef;
    }
    croak "Error parsing Bif";
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
