#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# ErfWrite.pm -- Erf encoder module
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: ErfWrite.pm
#	  $Source: /u/samba/nwn/perllib/RCS/ErfWrite.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 07:21 Jul 31 2004 kivinen
#	  Last Modification : 21:21 Oct 25 2006 kivinen
#	  Last check in     : $Date: 2006/10/25 18:23:12 $
#	  Revision number   : $Revision: 1.4 $
#	  State             : $State: Exp $
#	  Version	    : 1.124
#	  Edit time	    : 49 min
#
#	  Description       : Erf encoder module
#
#	  $Log: ErfWrite.pm,v $
#	  Revision 1.4  2006/10/25 18:23:12  kivinen
#	  	Do not put resource_offsets to the erf yet, as the writing erf
#	  	might require reading from the old file using old offsets.
#
#	  Revision 1.3  2006/10/24 21:11:14  kivinen
#	  	Updated to understand 1.1 version.
#
#	  Revision 1.2  2004/09/20 11:42:04  kivinen
#	  	Fixed localized string encoding. Fixed resource file name
#	  	padding (from space to nuls).
#
#	  Revision 1.1  2004/08/15 12:34:01  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package ErfWrite;
use strict;
use Carp;
use Erf;

######################################################################
# $data = write(\%erf, %options);
#
# Options can be:
#
# seek_pos	=> offset
#		Position to seek in file or data.
#
# filename	=> filename
#		Filename to read data from. If this exits, then data is
#		not returned. If this does not exists then the final erf is
#		return from the write function.
#

sub write {
    my($erf, %options) = @_;
    my($localized_string_size, 
       $offset_to_localized_strings, $offset_to_key_list,
       $offset_to_resource_list, $offset_to_resource_data);
    my($data, $off, $i, $j);
    my($localized_strings, $key_list, $resource_list, $filenamelen);
    my(@resource_offset);

    # Count strings
    $j = 0;
    foreach $i ($erf->localized_string) {
	$j++;
    }
    $erf->language_count($j);

    if ($erf->file_version eq "V1.0") {
	$filenamelen = 16;
    } elsif ($erf->file_version eq "V1.1") {
	$filenamelen = 32;
    } else {
 	return error($erf, "Invalid version (not V1.0 or V1.1) : " .
		     "$erf->file_version");
    }

    # Pack strings
    $localized_strings = pack("VV/a*" x $j, %{$erf->{localized_strings}});
    $localized_string_size = length($localized_strings);

    # Calculate offsets
    $offset_to_localized_strings = 160;
    $offset_to_key_list = $offset_to_localized_strings +
	$localized_string_size;
    $offset_to_resource_list = $offset_to_key_list +
	$erf->resource_count * (8 + $filenamelen);
    $offset_to_resource_data = $offset_to_resource_list +
	$erf->resource_count * 8;

    $key_list = '';
    $resource_list = '';
    $off = $offset_to_resource_data;
    for($i = 0; $i < $erf->resource_count; $i++) {
	$key_list .= pack("a${filenamelen}Vvv",
			  $erf->{resource_reference}[$i],
			  $i,
			  $erf->{resource_type}[$i],
			  0);
	$resource_offset[$i] = $off;
	$resource_list .= pack("VV", $off, $erf->{resource_size}[$i]);
	$off += $erf->{resource_size}[$i];
    }

    $data = pack("A4A4VVVVVVVVVa116",
		 $erf->file_type,
		 $erf->file_version,
		 $erf->language_count,
		 $localized_string_size,
		 $erf->resource_count,
		 $offset_to_localized_strings,
		 $offset_to_key_list,
		 $offset_to_resource_list,
		 $erf->build_year, 
		 $erf->build_day,
		 $erf->description_string_ref,
		 "") . $localized_strings . $key_list . $resource_list;

    # Write the header
    if (defined($options{filename})) {
	if (!open(FILE, ">$options{filename}")) {
	    croak "Cannot open $options{filename} : $!";
	}
	binmode(FILE);
	if (defined($options{seek_pos})) {
	    if (!sysseek(FILE, $options{seek_pos}, 0)) {
		croak "Cannot seek : $!";
	    }
	}
	if (!defined(syswrite(FILE, $data))) {
	    croak "Could not write header : $!";
	}
	for($i = 0; $i < $erf->resource_count; $i++) {
	    $data = $erf->resource_data($i);
	    if (!defined(syswrite(FILE, $data))) {
		croak "Cannot write resource $i (" .
		    $erf->resource_reference($i) . ") : $!";
	    }
	}
	close(FILE);
	$$erf{resource_offset} = \@resource_offset;
	return "";
    }
    for($i = 0; $i < $erf->resource_count; $i++) {
	$data .= $erf->resource_data($i);
    }
    $$erf{resource_offset} = \@resource_offset;
    return $data;
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
