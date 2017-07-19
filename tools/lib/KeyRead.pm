#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# KeyRead.pm -- Key parser module
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: KeyRead.pm
#	  $Source: /u/samba/nwn/perllib/RCS/KeyRead.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 15:16 Aug 14 2004 kivinen
#	  Last Modification : 13:17 Sep 29 2005 kivinen
#	  Last check in     : $Date: 2005/10/11 15:11:12 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.80
#	  Edit time	    : 42 min
#
#	  Description       : Key file parser module
#
#	  $Log: KeyRead.pm,v $
#	  Revision 1.2  2005/10/11 15:11:12  kivinen
#	  	Added path support. Removed some debug prints.
#
#	  Revision 1.1  2004/08/15 12:34:35  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package KeyRead;
use strict;
use Carp;
use Key;

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
#
# path		=> path
#		Path to the nwn install file, i.e. what is prepended to the
#		filename before it is read.

sub read {
    my(%options) = @_;
    my(%self);
    my($offset_to_file_table, $offset_to_key_table, $reserved);
    my(@file_sizes, @file_name_offsets, @file_name_sizes, @drives,
       @file_names, @res_refs, @res_types, @res_ids);
    my($data, $off, $i, $len, $start, $name);
    
    if (defined($options{filename})) {
	if (!open($self{file}, "<$options{filename}")) {
	    return error(\%self, "Cannot open $options{filename}");
	}
	binmode($self{file});
    }

    $self{options} = \%options;
    $self{path} = $options{path};
    if (!defined($self{path})) {
	$self{path} = '';
    } elsif ($self{path} !~ /\/$/) {
	$self{path} .= '/';
    }
	
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
	if (sysread($self{file}, $data, 48) != 48) {
	    return error(\%self, "Could not read the header");
	}
    } else {
	if ($off + 48 > length($options{data})) {
	    return error(\%self, "End of data while reading header");
	}
	$data = substr($options{data}, $off, 48);
    }

    # Parse the header

    ($self{file_type}, $self{file_version},
     $self{bif_count}, $self{key_count},
     $offset_to_file_table, $offset_to_key_table, 
     $self{build_year}, $self{build_day},
     $reserved) =
	 unpack("a4a4VVVVVVa32", $data);

#    print("Bif count = $self{bif_count}\n");
#    print("Key count = $self{key_count}\n");
#    print("Offset to file table = $offset_to_file_table\n");
#    print("Offset to key table = $offset_to_key_table\n");

    if ($self{file_version} ne "V1  ") {
	return error(\%self, "Invalid version : $self{file_version}");
    }

    # Read the string table

    if ($offset_to_file_table != 48) {
#	carp("File table not after header, " .
#	     "offset = $offset_to_file_table instead of 48");
	if (!sysseek($self{file}, $off + $offset_to_file_table, 0)) {
	    return error(\%self, "Cannot seek");
	}
    }
    if (defined($options{filename})) {
	if (sysread($self{file}, $data, $self{bif_count} * 12) !=
	    $self{bif_count} * 12) {
	    return error(\%self, "Could not read file table");
	}
    } else {
	if ($off + $offset_to_file_table + $self{bif_count} * 12 >
	    length($options{data})) {
	    return error(\%self,
			 "End of data while reading file table");
	}
	$data = substr($options{data}, $off + $offset_to_file_table,
		       $self{bif_count} * 12);
    }

    @file_sizes = unpack("Vx4x2x2" x $self{bif_count}, $data);
    @file_name_offsets = unpack("x4Vx2x2" x $self{bif_count}, $data);
    @file_name_sizes = unpack("x4x4vx2" x $self{bif_count}, $data);
    @drives = unpack("x4x4x2v" x $self{bif_count}, $data);

    $self{file_size} = \@file_sizes;
    $self{drive} = \@drives;

    # Read the file name table

    $len = $offset_to_key_table - $offset_to_file_table -
	$self{bif_count} * 12;
    $start = $offset_to_file_table + $self{bif_count} * 12;

    if (defined($options{filename})) {
	if (sysread($self{file}, $data, $len) != $len) {
	    return error(\%self, "Could not read file name table");
	}
    } else {
	if ($off + $offset_to_file_table + $len > length($options{data})) {
	    return error(\%self, "End of data while reading file name table");
	}
	$data = substr($options{data}, $off + $offset_to_file_table, $len);
    }

    @file_names = ();
    for($i = 0; $i < $self{bif_count}; $i++) {
	if ($file_name_offsets[$i] < $offset_to_file_table ||
	    $file_name_offsets[$i] + $file_name_sizes[$i] >
	    $offset_to_key_table) {
	    return error(\%self, "File name $i outside of file name buffer," .
			 "offset = $file_name_offsets[$i], " .
			 "len = file_name_sizes[$i]");
	}
	$name = substr($data, $file_name_offsets[$i] - $start,
		       $file_name_sizes[$i]);
	if (substr($name, -1, 1) eq "\0") {
	    $name = substr($name, 0, -1);
	}
	$name =~ s/\\/\//g;
	push(@file_names, $name);
    }

    # Read the key list

    $self{file_name} = \@file_names;

    if (defined($options{filename})) {
	if (sysread($self{file}, $data, $self{key_count} * 22)
	    != $self{key_count} * 22) {
	    return error(\%self, "Could not read key table");
	}
    } else {
	if ($off + $offset_to_key_table + $self{key_count} * 22 >
	    length($options{data})) {
	    return error(\%self, "End of data while reading key table");
	}
	$data = substr($options{data}, $off + $offset_to_key_table,
		       $self{key_count} * 22);
    }

    @res_refs = unpack("A16x2x4" x $self{key_count}, $data);
    @res_types = unpack("x16vx4" x $self{key_count}, $data);
    @res_ids = unpack("x16x2V" x $self{key_count}, $data);
    $self{resource_reference} = \@res_refs;
    $self{resource_type} = \@res_types;
    $self{resource_id} = \@res_ids;

    close($self{file});
    undef $self{file};

    bless \%self, "Key";
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
    croak "Error parsing Key";
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
