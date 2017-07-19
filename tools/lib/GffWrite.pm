#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# GffParse.pm -- Simple GFF file writer module
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: GffWrite.pm
#	  $Source: /u/samba/nwn/perllib/RCS/GffWrite.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 19:07 Jul 19 2004 kivinen
#	  Last Modification : 15:20 Nov 25 2006 kivinen
#	  Last check in     : $Date: 2006/11/25 13:21:07 $
#	  Revision number   : $Revision: 1.10 $
#	  State             : $State: Exp $
#	  Version	    : 1.257
#	  Edit time	    : 110 min
#
#	  Description       : Simple GFF file writer module
#
#	  $Log: GffWrite.pm,v $
#	  Revision 1.10  2006/11/25 13:21:07  kivinen
#	  	Added clearing of struct_type if not defined.
#
#	  Revision 1.9  2006/11/23 18:17:51  kivinen
#	  	Changed to use hex encoding for the VOID type.
#
#	  Revision 1.8  2006/10/24 21:16:08  kivinen
#	  	Added manual.
#
#	  Revision 1.7  2005/10/13 19:07:33  kivinen
#	  	Fixed 64-bit handling (using 32 bit operations).
#
#	  Revision 1.6  2005/10/13 17:02:00  kivinen
#	  	Changed not to use Q whan packing... use II instead.
#
#	  Revision 1.5  2004/08/25 15:21:46  kivinen
#	  	Changed to use UNIVERSAL::isa.
#
#	  Revision 1.4  2004/08/15 12:35:27  kivinen
#	  	Add Gff.pm fixes.
#
#	  Revision 1.3  2004/07/26 15:12:31  kivinen
#	  	Added binmode.
#
#	  Revision 1.2  2004/07/22 14:52:47  kivinen
#	  	Added support for filename option, now you actually can write
#	  	stuff to disk.
#
#	  Revision 1.1  2004/07/20 14:03:33  kivinen
#	  	Created.
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package GffWrite;
use strict;

######################################################################
# $data = write(\%gff, %options);
#
# Options can be:
#
# filename	=> filename
#		Filename to write data to. If this exits, then data is
#		written there, instead of returned.
#

sub write {
    my($gff, %options) = @_;
    my(%self, $data);

    $self{'options'} = \%options;
    $self{'gff'} = $gff;
    $self{'struct_index'} = 0;
    $self{'field_index'} = 0;
    $self{'label_index'} = 0;
    $self{'field_data_block'} = "";
    $self{'field_indices_index'} = 0;
    $self{'list_indices_index'} = 0;

    @{$self{'struct_array'}} = ();
    @{$self{'field_array'}} = ();
    @{$self{'label_array'}} = ();
    @{$self{'field_indices_array'}} = ();
    @{$self{'list_indices_array'}} = ();

    write_struct(\%self, $gff);

    $data = pack("a4a4VVVVVVVVVVVV",
		 $$gff{' ____file_type'},
		 $$gff{' ____file_version'},
		 56, $self{'struct_index'},
		 56 + $self{'struct_index'} * 12,
		 $self{'field_index'},
		 56 + ($self{'struct_index'} + $self{'field_index'}) * 12,
		 $self{'label_index'},
		 56 + ($self{'struct_index'} + $self{'field_index'}) * 12 +
		 $self{'label_index'} * 16,
		 length($self{'field_data_block'}),
		 56 + ($self{'struct_index'} + $self{'field_index'}) * 12 +
		 $self{'label_index'} * 16 + length($self{'field_data_block'}),
		 $self{'field_indices_index'} * 4,
		 56 + ($self{'struct_index'} + $self{'field_index'}) * 12 +
		 $self{'label_index'} * 16 +
		 length($self{'field_data_block'}) +
		 $self{'field_indices_index'} * 4,
		 $self{'list_indices_index'} * 4);
#    print("header len = ", length($data), "\n");
#
#    $data2 = pack("V*", @{$self{'struct_array'}});
#    print("struct_array_len = ", length($data2), "\n");
#    $data .= $data2;
#
#    $data2 = pack("V*", @{$self{'field_array'}});
#    print("field_array_len = ", length($data2), "\n");
#    $data .= $data2;
#
#    $data2 = pack("a16" x $self{'label_index'}, @{$self{'label_array'}});
#    print("label_array_len = ", length($data2), "\n");
#    $data .= $data2;
#
#    $data2 = $self{'field_data_block'};
#    print("field_data_block_len = ", length($data2), "\n");
#    $data .= $data2;
#
#    $data2 = pack("V*", @{$self{'field_indices_array'}});
#    print("field_indices_array_len = ", length($data2), "\n");
#    $data .= $data2;
#
#    $data2 = pack("V*", @{$self{'list_indices_array'}});
#    print("list_indices_array_len = ", length($data2), "\n");
#    $data .= $data2;


    $data .= pack("V*", @{$self{'struct_array'}}, @{$self{'field_array'}}) .
	pack("a16" x $self{'label_index'}, @{$self{'label_array'}}) .
	$self{'field_data_block'} .
	pack("V*", @{$self{'field_indices_array'}},
	     @{$self{'list_indices_array'}});

    if (defined($options{filename})) {
	open(FILE, ">$options{filename}") ||
	    die "Cannot write file $options{filename}";
	binmode(FILE);
	print(FILE $data);
	close(FILE);
    }
    return $data;
}

######################################################################
# Format chars

%GffWrite::formats = ('0' => 'Cxxx',
		      '1' => 'Cxxx',
		      '2' => 'Sxx',
		      '3' => 'sxx',
		      '4' => 'I',
		      '5' => 'i',
		      '6' => '*Q',
		      '7' => '*q',
		      '8' => 'f',
		      '9' => '*d',
		      '10' => '*V/a*',
		      '11' => '*C/a*',
		      '13' => '*HV/a*');

######################################################################
# $struct_index = write_struct(\%self, \%gff);
#
# Write one level

sub write_struct {
    my($self, $gff) = @_;
    my($i, $label, $type, $format, @fields, $index);

    $index = $$self{'struct_index'};
    if (!defined($$gff{" ____struct_type"})) {
	warn "Struct type missing from: $$gff{''}";
	$$gff{" ____struct_type"} = 0;
    }
    push(@{$$self{'struct_array'}}, $$gff{" ____struct_type"}, 0, 0);
    $$self{'struct_index'}++;
    
    foreach $i (keys %{$gff}) {
	next if ($i =~ /____((struct_|file_|)type|string_ref|file_version)$/);
	next if ($i eq '');

	if (!defined($$self{'labels'}{$i})) {
	    $$self{'labels'}{$i} = $$self{'label_index'};
	    push(@{$$self{'label_array'}}, $i);
	    $label = $$self{'label_index'}++;
	} else {
	    $label = $$self{'labels'}{$i};
	}
	$type = $$gff{$i . ". ____type"};

	if (UNIVERSAL::isa($$gff{$i}, 'ARRAY')) {
	    my($j, $cnt, $tmp, $array);

	    push(@fields, $$self{'field_index'});
	    push(@{$$self{'field_array'}}, $type, $label,
		 4 * $$self{'list_indices_index'});
	    $$self{'field_index'}++;

	    $array = $$gff{$i};
	    $cnt = $#{$array};
	    $cnt++;
	    $tmp = $$self{'list_indices_index'};

	    push(@{$$self{'list_indices_array'}}, $cnt);
	    for($j = 0; $j < $cnt; $j++) {
		push(@{$$self{'list_indices_array'}}, 0);
	    }

	    $$self{'list_indices_index'} += $cnt + 1;

	    for($j = 0; $j < $cnt; $j++) {
		$$self{'list_indices_array'}[$tmp + $j + 1] =
		    write_struct($self, $$gff{$i}[$j]);
	    }
	} elsif (UNIVERSAL::isa($$gff{$i}, 'HASH') &&
		 (!defined($type) || $type == 14)) {
	    my($tmp);

	    push(@fields, $$self{'field_index'});
	    push(@{$$self{'field_array'}}, $type, $label, 0);
	    $tmp = $$self{'field_index'};
	    $$self{'field_index'}++;
	    $$self{'field_array'}[3 * $tmp + 2] =
		write_struct($self, $$gff{$i});
	} elsif (UNIVERSAL::isa($$gff{$i}, 'HASH')) {
	    my($data, $cnt, $hash, @keys);

	    $hash = $$gff{$i};
	    @keys = keys %{$hash};
	    $cnt = $#keys + 1;

	    $data = pack("V/a*", pack("VV" . ("VV/a*" x $cnt),
				      $$gff{$i . ". ____string_ref"},
				      $cnt,
				      (%{$$gff{$i}})));

	    push(@fields, $$self{'field_index'});
	    push(@{$$self{'field_array'}}, $type, $label,
		 length($$self{'field_data_block'}));
	    $$self{'field_index'}++;
	    $$self{'field_data_block'} .= $data;
	} else {
	    $format = $GffWrite::formats{$type};
	    if (!defined($format)) {
		die "Invalid type in hash for $$gff{''}/$i: $type";
	    }
	    if (substr($format, 0, 1) eq '*') {
		$format = substr($format, 1);
		push(@fields, $$self{'field_index'});
		push(@{$$self{'field_array'}}, $type, $label,
		     length($$self{'field_data_block'}));
		$$self{'field_index'}++;
		if ($format eq "Q") {
		    $$self{'field_data_block'} .=
			pack("II",
			     int($$gff{$i} / (2**32)) & 0xffffffff,
			     ($$gff{$i} % (2**32)));
		} elsif (substr($format, 0, 1) eq "H") {
		    $format = substr($format, 1);
		    $$self{'field_data_block'} .=
			pack($format, pack("H*", $$gff{$i}));
		} else {
		    $$self{'field_data_block'} .= pack($format, $$gff{$i});
		}
	    } else {
		push(@fields, $$self{'field_index'});
		push(@{$$self{'field_array'}}, $type, $label,
		     unpack("V", pack($format, $$gff{$i})));
		$$self{'field_index'}++;
	    }
	}
    }

    $$self{'struct_array'}[3 * $index + 2] = ($#fields) + 1;
    if ($#fields < 0) {
	# The data is already ok
    } elsif ($#fields == 0) {
	# only one item, put it to the struct_array
	$$self{'struct_array'}[3 * $index + 1] = $fields[0];
    } else {
	# More than one item, push it to the field indices array
	$$self{'struct_array'}[3 * $index + 1] =
	    4 * $$self{'field_indices_index'};
	push(@{$$self{'field_indices_array'}}, @fields);
	$$self{'field_indices_index'} += ($#fields) + 1;
    }
    return $index;
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################

__END__

=head1 NAME

GffWrite - Perl Module to Write Gff datastructures

=head1 ABSTRACT

This module allows easy writing of the nwn gff back files. It can
either return the encoded gff data string, or write it to the file. 

=head1 DESCRIPTION

The basic working is that you give hash of options to the
B<GffWrite::write>, and get encoded data back or written to file.

=head1 B<GffWrite::write>

B<GffWrite::write> is used to write gff structure. Takes hash
table of options in, and returns a either the data as a string, or
writes the data directly to file. 

=over 4

=head2 USAGE

$data = $gff->write(%options);
$data = write($gff, %options);

=head2 OPTIONS

Following options can be given to the B<GffWrite::write>.
 
=over 4

=item B<filename> => I<filename>

Filename to where to write data to. If this exits, then no data is
returned. Otherwise returns the data as a string.

=back

=back

=head1 SEE ALSO

gffmodify(1), Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Created to do automated things for the cerea persistent world. 

=cut
