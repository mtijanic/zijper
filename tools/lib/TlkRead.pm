#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# TlkRead.pm -- Simple TLK file read module
# Copyright (c) 2005 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: TlkRead.pm
#	  $Source: /u/samba/nwn/perllib/RCS/TlkRead.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 11:14 Oct 25 2005 kivinen
#	  Last Modification : 12:18 Oct 25 2005 kivinen
#	  Last check in     : $Date: 2005/10/27 17:03:54 $
#	  Revision number   : $Revision: 1.1 $
#	  State             : $State: Exp $
#	  Version	    : 1.19
#	  Edit time	    : 22 min
#
#	  Description       : Simple TLK file read module
#
#	  $Log: TlkRead.pm,v $
#	  Revision 1.1  2005/10/27 17:03:54  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package TlkRead;
use Tlk;
use strict;
use Carp;

######################################################################
# \%tlk = read(%options);
#
# Options can be:
#
# no_store	=> boolean
#		Do not store anything, simply parse the structure
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
    my(%tlk);
    my($data, $off, $ret);
    my($file_type, $file_version, $language_id, $string_count,
       $string_entries_offset);
    my($struct_len, $i);

    $tlk{options} = \%options;

    if (defined($options{filename})) {
	if (!open(FILE, "<$options{filename}")) {
	    return error(\%tlk, "Cannot open $options{filename}");
	}
	binmode(FILE);
	$tlk{file} = \*FILE;
    }

    $off = 0;

    if (defined($options{seek_pos})) {
	if (defined($options{filename})) {
	    if (!sysseek(FILE, $options{seek_pos}, 0)) {
		return error(\%tlk, "Cannot seek");
	    }
	} else {
	    $off = $options{seek_pos};
	}
    }

    # Read the header

    if (defined($options{filename})) {
	if (sysread(FILE, $data, 20) != 20) {
	    return error(\%tlk, "Could not read the header");
	}
    } else {
	if ($off + 20 > length($options{data})) {
	    return error(\%tlk, "End of data while reading header");
	}
	$data = substr($options{data}, $off, 20);
    }

    # Parse the header

    ($file_type, $file_version, $language_id,
     $string_count, $string_entries_offset) = 
	 unpack("a4a4VVV", $data);

    if ($file_version ne "V3.0") {
	return error(\%tlk, "Invalid version : $file_version");
    }

    $tlk{file_type} = $file_type;
    $tlk{file_version} = $file_version;
    $tlk{language_id} = $language_id;
    $tlk{string_count} = $string_count;
    $tlk{string_entries_offset} = $string_entries_offset;
    $tlk{base_offset} = $off;

    # Parse struct array

    $struct_len = $string_count * 40;
    if ($string_entries_offset != 20 + $struct_len) {
	return error(\%tlk, "String entry table not after string data " .
		     "table, offset = $string_entries_offset instead of " .
		     (20 + $struct_len));
    }
    if (defined($options{filename})) {
	if (sysread(FILE, $data, $struct_len) != $struct_len) {
	    return error(\%tlk, "Could not read struct array");
	}
    } else {
	if ($off + 20 + $struct_len > length($options{data})) {
	    return error(\%tlk, "End of data while reading struct array");
	}
	$data = substr($options{data}, $off + 20, $struct_len);
    }

    for($i = 0; $i < $string_count; $i++) {
	my(%string);
	($string{Flags}, $string{SoundResRef}, $string{VolumeVariance},
	 $string{PitchVariance}, $string{OffsetToString},
	 $string{StringSize}, $string{SoundLength}) =
	     unpack("VA16VVVVf", substr($data, $i * 40, 40));
	push(@{$tlk{strings}}, \%string);
    }

    return Tlk->new(\%tlk);

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
    croak "Error parsing TLK";
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
