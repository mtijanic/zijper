#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# TrnRead.pm -- Simple TRN file read module
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: TrnRead.pm
#	  $Source: /u/samba/nwn/perllib/RCS/TrnRead.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 01:49 Jan 17 2007 kivinen
#	  Last Modification : 17:41 May 29 2007 kivinen
#	  Last check in     : $Date: 2007/05/30 15:17:43 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.69
#	  Edit time	    : 27 min
#
#	  Description       : Simple TRN file read module
#
#	  $Log: TrnRead.pm,v $
#	  Revision 1.2  2007/05/30 15:17:43  kivinen
#	  	Fixed bug in seek_pos and data given directly.
#
#	  Revision 1.1  2007/01/23 22:39:38  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package TrnRead;
use Trn;
use strict;
use Carp;

######################################################################
# \%trn = read(%options);
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
    my($file_type, $version_major, $version_minor, $res_cnt);
    my($directory_len, @type, @offset, $type, $len);
    my($data, $res_data, $off, $i);

    $self{'options'} = \%options;

    if (defined($options{'filename'})) {
	if (!open(FILE, "<$options{'filename'}")) {
	    return error(\%self, "Cannot open $options{'filename'}");
	}
	binmode(FILE);
    }

    $off = 0;

    if (defined($options{'seek_pos'})) {
	if (defined($options{'filename'})) {
	    if (!sysseek(FILE, $options{'seek_pos'}, 0)) {
		return error(\%self, "Cannot seek");
	    }
	} else {
	    $off = $options{'seek_pos'};
	}
    }

    # Read the header

    if (defined($options{'filename'})) {
	if (sysread(FILE, $data, 12) != 12) {
	    return error(\%self, "Could not read the header");
	}
    } else {
	if ($off + 12 > length($options{'data'})) {
	    return error(\%self, "End of data while reading header");
	}
	$data = substr($options{'data'}, $off, 12);
    }
    $off += 12;

    # Parse the header

    ($file_type, $version_major, $version_minor, $res_cnt) = 
	 unpack("a4vvV", $data);

    if ($file_type ne "NWN2") {
	return error(\%self, "Invalid version : $file_type");
    }

    $self{'file_type'} = $file_type;
    $self{'version_major'} = $version_major;
    $self{'version_minor'} = $version_minor;
    $self{'resource_count'} = $res_cnt;

    # Parse resource list

    $directory_len = $res_cnt * 8;
    if (defined($options{'filename'})) {
	if (sysread(FILE, $data, $directory_len) != $directory_len) {
	    return error(\%self, "Could not read directory");
	}
    } else {
	if ($off + $directory_len > length($options{'data'})) {
	    return error(\%self, "End of data while reading directory");
	}
	$data = substr($options{'data'}, $off, $directory_len);
    }
    $off += $directory_len;

    @type = unpack("A4x4" x $res_cnt, $data);
    @offset = unpack("x4V" x $res_cnt, $data);

    for($i = 0; $i < $res_cnt; $i++) {
	$self{'resource_type'}[$i] = $type[$i];
	if ($off != $offset[$i] && defined($options{'filename'})) {
	    if (!sysseek(FILE, $off, 0)) {
		return error(\%self, "Cannot seek");
	    }
	}
	if (defined($options{'filename'})) {
	    if (sysread(FILE, $data, 8) != 8) {
		return error(\%self, "Could not read resource header");
	    }
	} else {
	    if ($off + 8 > length($options{'data'})) {
		return error(\%self, "End of data while reading resource header");
	    }
	    $data = substr($options{'data'}, $off, 8);
	}
	$off += 8;
	($type, $len) = unpack("A4V", $data);
	if ($type ne $type[$i]) {
	    return error(\%self, "Invalid type inside the resource $type != $type[$i]");
	}
	if (defined($options{'filename'})) {
	    if (sysread(FILE, $res_data, $len) != $len) {
		return error(\%self, "Could not read resource data");
	    }
	} else {
	    if ($off + $len > length($options{'data'})) {
		return error(\%self, "End of data while reading resource data");
	    }
	    $res_data = substr($options{'data'}, $off, $len);
	}
	$off += $len;
	
	$self{'resource_size'}[$i] = $len;
	$self{'resource_data'}[$i] = $data . $res_data;
    }

    if (defined($options{'filename'})) {
	close(FILE);
    } else {
	delete $options{'data'};
    }
    
    return Trn->new(\%self);

}

######################################################################
# $ret = error(\%self, $text);

sub error {
    my($self, @text) = @_;

    print(@text, "\n");
    if (defined($$self{'options'}{'return_errors'}) &&
	$$self{'options'}{'return_errors'}) {
	return undef;
    }
    croak "Error parsing TRN";
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################

__END__

=head1 NAME

TrnRead - Perl Module to Read Trn datastructures

=head1 ABSTRACT

This module allows easy reading and parsing of the nwn2 trn/trx files.
It returns a hash structure having everything from the trn/trx.

=head1 DESCRIPTION

The basic working is that you give hash of options to the
B<TrnRead::read>, and get Trn object back from there. The data is
either read from the string given to the read function, or from the
file given to the read function.

=head1 B<TrnRead::read>

B<TrnRead::read> is used to read and parse trn structure. Take hash
table of options in, and returns a reference to the B<Trn(3)> object
back. 

=over 4

=head2 USAGE

\%trn = read(%options);

=head2 OPTIONS

Following options can be given to the B<TrnRead::read>.
 
=over 4

=item B<filename> => I<filename>

Filename to read data from. If this exits, then data is ignored.

=item B<data> => I<data>

Data buffer to use instead of filename. This only used if filename
is no present.

=item B<seek_pos> => I<offset>

Position to seek in file or data.

=item B<return_errors> => I<boolean>

If false then die on errors, otherwise return undef on error.

=back

=back

=head1 SEE ALSO

trnunpack(1), Trn(3), and TrnWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Created to do walkmesh height setter.

=cut
