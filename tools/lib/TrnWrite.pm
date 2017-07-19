#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# TrnWrite.pm -- Trn encoder module
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: TrnWrite.pm
#	  $Source: /u/samba/nwn/perllib/RCS/TrnWrite.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 02:59 Jan 17 2007 kivinen
#	  Last Modification : 03:09 Jan 17 2007 kivinen
#	  Last check in     : $Date: 2007/01/23 22:39:42 $
#	  Revision number   : $Revision: 1.1 $
#	  State             : $State: Exp $
#	  Version	    : 1.22
#	  Edit time	    : 9 min
#
#	  Description       : Trn encoder module
#
#	  $Log: TrnWrite.pm,v $
#	  Revision 1.1  2007/01/23 22:39:42  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package TrnWrite;
use strict;
use Carp;
use Trn;

######################################################################
# $data = write(\%trn, %options);
#
# Options can be:
#
# seek_pos	=> offset
#		Position to seek in file or data.
#
# filename	=> filename
#		Filename to write data to. If this exits, then data is
#		not returned. If this does not exists then the final trn is
#		return from the write function.
#

sub write {
    my($trn, %options) = @_;
    my($data, $off, $i, $j);
    my(@directory);

    # Count strings
    $off = $trn->resource_count * 8 + 12;
    for($i = 0; $i < $trn->resource_count; $i++) {
	$directory[$i] = pack("A4V", $trn->{resource_type}[$i], $off);
	$off += $trn->{resource_size}[$i];
    }

    $data = pack("a4vvV", $trn->file_type, $trn->version_major,
		 $trn->version_minor, $trn->resource_count)
	. join("", @directory);

    # Write the data & header
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
	for($i = 0; $i < $trn->resource_count; $i++) {
	    $data = $trn->resource_data($i);
	    if (!defined(syswrite(FILE, $data))) {
		croak "Cannot write resource $i (" .
		    $trn->resource_type($i) . ") : $!";
	    }
	}
	close(FILE);
	return "";
    }
    for($i = 0; $i < $trn->resource_count; $i++) {
	$data .= $trn->resource_data($i);
    }
    return $data;
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################

__END__

=head1 NAME

TrnWrite - Perl Module to Write Trn datastructures

=head1 ABSTRACT

This module allows writing nwn2 trn/trx files. It takes Trn object in
and writes it to file or returns it as encoded string.

=head1 DESCRIPTION

The basic working is that you give hash of options to the
B<TrnWrite::write>, and get encoded data back or written to file.

=head1 B<TrnWrite::write>

B<TrnWrite::write> is used to write trn or trn file. Takes hash
table of options in, and returns either the data as a string, or writes the data directoy to file. 

=over 4

=head2 USAGE

$data = $trn->write(%options);
$data = write($trn, %options);

=head2 OPTIONS

Following options can be given to the B<TrnWrite::write>.
 
=over 4

=item B<filename> => I<filename>

Filename to write data to. If this exits, then no data is returned.
Otherwise returns the data as a string.

=item B<seek_pos> => I<offset>

Position to seek in file when writing to file.

=back

=back

=head1 SEE ALSO

trnpack(1), Trn(3), and TrnRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Created to do walkmesh height setter.

=cut
