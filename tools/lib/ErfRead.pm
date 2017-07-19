#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# ErfRead.pm -- Erf parser module
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: ErfRead.pm
#	  $Source: /u/samba/nwn/perllib/RCS/ErfRead.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 13:32 Jul 20 2004 kivinen
#	  Last Modification : 06:16 Jan 25 2007 kivinen
#	  Last check in     : $Date: 2007/01/25 04:25:55 $
#	  Revision number   : $Revision: 1.5 $
#	  State             : $State: Exp $
#	  Version	    : 1.192
#	  Edit time	    : 94 min
#
#	  Description       : Erf parser module
#
#	  $Log: ErfRead.pm,v $
#	  Revision 1.5  2007/01/25 04:25:55  kivinen
#	  	Commented out some extra prints.
#
#	  Revision 1.4  2006/10/24 21:11:07  kivinen
#	  	Updated to understand 1.1 version.
#
#	  Revision 1.3  2004/08/15 12:33:56  kivinen
#	  	Moved stuff to Erf.pm.
#
#	  Revision 1.2  2004/07/26 15:11:54  kivinen
#	  	Changed binmode to use parenthes.
#
#	  Revision 1.1  2004/07/26 15:11:16  kivinen
#	  	Created.
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package ErfRead;
use strict;
use Carp;
use Erf;

######################################################################
# \%erf = read(%options);
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
    my($localized_string_size, 
       $entry_count, $offset_to_localized_strings, $offset_to_key_list,
       $offset_to_resource_list, $reserved);
    my(%localized_strings, @res_refs, @res_ids, @res_types,
       @res_offsets, @res_sizes, $filenamelen);
    my($data, $off);
    
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
	if (sysread($self{file}, $data, 160) != 160) {
	    return error(\%self, "Could not read the header");
	}
    } else {
	if ($off + 160 > length($options{data})) {
	    return error(\%self, "End of data while reading header");
	}
	$data = substr($options{data}, $off, 160);
    }

    # Parse the header

    ($self{file_type}, $self{file_version}, $self{language_count},
     $localized_string_size, $entry_count,
     $offset_to_localized_strings, $offset_to_key_list,
     $offset_to_resource_list, $self{build_year}, 
     $self{build_day}, $self{description_string_ref},
     $reserved) =
	 unpack("a4a4VVVVVVVVVa116", $data);

    # print("Localized string size = $localized_string_size\n");
    # print("Offset to localized strings = $offset_to_localized_strings\n");
    # print("Offset to key list = $offset_to_key_list\n");
    # print("Offset to resource list = $offset_to_resource_list\n");
    # print("Entry count = $entry_count\n");

    $self{resource_count} = $entry_count;

    if ($self{file_version} eq "V1.0") {
	$filenamelen = 16;
    } elsif ($self{file_version} eq "V1.1") {
	$filenamelen = 32;
    } else {
 	return error(\%self, "Invalid version (not V1.0 or V1.1) : " .
		     "$self{file_version}");
    }

    # Read the string table

    if ($offset_to_localized_strings != 160) {
	return error(\%self, "Localized string list not after header, " .
		     "offset = $offset_to_localized_strings instead of 160");
    }
    if (defined($options{filename})) {
	if (sysread($self{file}, $data, $localized_string_size) !=
	    $localized_string_size) {
	    return error(\%self, "Could not read localized string list");
	}
    } else {
	if ($off + $offset_to_localized_strings + $localized_string_size >
	    length($options{data})) {
	    return error(\%self,
			 "End of data while reading localized string list");
	}
	$data = substr($options{data}, $off + $offset_to_localized_strings,
		       $localized_string_size);
    }

    %localized_strings = unpack("VV/a" x $self{language_count}, $data);
    $self{localized_strings} = \%localized_strings;

    # Read the key list

    if ($offset_to_key_list !=
	$offset_to_localized_strings + $localized_string_size) {
	return error(\%self, "Key list not after localized string list, " .
		     "offset = $offset_to_key_list instead of " .
		     ($offset_to_localized_strings + $localized_string_size));
    }
    if (defined($options{filename})) {
	if (sysread($self{file}, $data, $entry_count * ($filenamelen + 8))
	    != $entry_count * ($filenamelen + 8)) {
	    return error(\%self, "Could not read key list");
	}
    } else {
	if ($off + $offset_to_key_list + $entry_count * ($filenamelen + 8) >
	    length($options{data})) {
	    return error(\%self, "End of data while reading key list");
	}
	$data = substr($options{data}, $off + $offset_to_key_list,
		       $entry_count * ($filenamelen + 8));
    }

    if ($filenamelen == 16) {
	@res_refs = unpack("A16x4x2x2" x $entry_count, $data);
#    @res_ids = unpack("x16Vx2x2" x $entry_count, $data);
	@res_types = unpack("x16x4vx2" x $entry_count, $data);
    } else {
	@res_refs = unpack("A32x4x2x2" x $entry_count, $data);
#    @res_ids = unpack("x32Vx2x2" x $entry_count, $data);
	@res_types = unpack("x32x4vx2" x $entry_count, $data);
    }
    $self{resource_reference} = \@res_refs;
    # No point of storing those.
#    $self{res_ids} = \@res_ids;
    $self{resource_type} = \@res_types;

    # Read the resource list

    if ($offset_to_resource_list != $offset_to_key_list + $entry_count *
	($filenamelen + 8)) {
	carp("Resource list not after key list, " .
	     "offset = $offset_to_resource_list instead of " .
	     ($offset_to_key_list + $entry_count * ($filenamelen + 8)));
	if (!sysseek($self{file}, $off + $offset_to_resource_list, 0)) {
	    return error(\%self, "Cannot seek");
	}
    }
    if (defined($options{filename})) {
	if (sysread($self{file}, $data, $entry_count * 8) !=
	    $entry_count * 8) {
	    return error(\%self, "Could not read resource list");
	}
    } else {
	if ($off + $offset_to_resource_list + $entry_count * 8 >
	    length($options{data})) {
	    return error(\%self, "End of data while reading resource list");
	}
	$data = substr($options{data}, $off + $offset_to_resource_list,
		       $entry_count * 8);
    }

    @res_offsets = unpack("Vx4" x $entry_count, $data);
    @res_sizes = unpack("x4V" x $entry_count, $data);

    $self{resource_offset} = \@res_offsets;
    $self{resource_size} = \@res_sizes;

    bless \%self, "Erf";
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
    croak "Error parsing Erf";
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
