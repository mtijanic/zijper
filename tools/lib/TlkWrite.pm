#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# TlkWrite.pm -- Simple TLK file write module
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: TlkWrite.pm
#	  $Source: /u/samba/nwn/perllib/RCS/TlkWrite.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 22:36 Jan  2 2007 kivinen
#	  Last Modification : 01:19 Jan  3 2007 kivinen
#	  Last check in     : $Date: 2007/01/02 23:20:20 $
#	  Revision number   : $Revision: 1.1 $
#	  State             : $State: Exp $
#	  Version	    : 1.48
#	  Edit time	    : 33 min
#
#	  Description       : Simple TLK file write module
#
#	  $Log: TlkWrite.pm,v $
#	  Revision 1.1  2007/01/02 23:20:20  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package TlkWrite;
use Tlk;
use strict;
use Carp;

######################################################################
# $data = write(%tlk, %options);
#
# Options can be:
#
# seek_pos	=> offset
#		Position to seek in file or data.
#
# filename	=> filename
#		Filename to write data to. If this exits, then data is
#		written there, instead of returned.
#

sub write {
    my($tlk, %options) = @_;
    my($i, $off, $data, $string_data_table, $string_entries_table);
    my($text, %string);

    $off = 0;
    $string_data_table = '';
    $string_entries_table = '';
    for($i = 0; $i < $$tlk{string_count}; $i++) {
	$text = $tlk->string($i);
	%string = $tlk->string_info($i);
	$string{text} = '' if (!defined($string{text}));
	$string{StringSize} = length($string{text});
	$string{SoundResRef} = '' if (!defined($string{SoundResRef}));
	$string{VolumeVariance} = 0 if (!defined($string{VolumeVariance}));
	$string{PitchVariance} = 0 if (!defined($string{PitchVariance}));
	$string{SoundLength} = 0.0 if (!defined($string{SoundLength}));
	if (!defined($string{Flags})) {
	    $string{Flags} = 0;
	    if ($string{StringSize} != 0) { $string{Flags} |= 0x0001; }
	    if ($string{SoundResRef} ne '') { $string{Flags} |= 0x0002; }
	    if ($string{SoundLength} != 0.0) { $string{Flags} |= 0x0004; }
	}
	if ($string{Flags} == 0 && $text eq '') {
	    $string{OffsetToString} = 0;
	} else {
	    $string{OffsetToString} = $off;
	}
	$off += $string{StringSize};
	$string_data_table .=
	    pack("Va16VVVVf", $string{Flags}, $string{SoundResRef},
		 $string{VolumeVariance}, $string{PitchVariance},
		 $string{OffsetToString}, $string{StringSize},
		 $string{SoundLength});
	$string_entries_table .= $text;
    }
    $$tlk{file_type} = "TLK " if (!defined($$tlk{file_type}));
    $$tlk{file_version} = "V3.0" if (!defined($$tlk{file_version}));
    $$tlk{language_id} = 0 if (!defined($$tlk{language_id}));

    $$tlk{string_entries_offset} = length($string_data_table) + 20;
    $data = pack("a4a4VVV", $$tlk{file_type}, $$tlk{file_version},
		 $$tlk{language_id}, $$tlk{string_count}, 
		 $$tlk{string_entries_offset});

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
	if (!defined(syswrite(FILE, $string_data_table))) {
	    croak "Could not write data table : $!";
	}
	if (!defined(syswrite(FILE, $string_entries_table))) {
	    croak "Could not write data table : $!";
	}
	close(FILE);
	return "";
    }
    return $data . $string_data_table . $string_entries_table;
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
