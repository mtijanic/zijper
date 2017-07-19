#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# GffRead.pm -- Simple GFF file read module
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: GffRead.pm
#	  $Source: /u/samba/nwn/perllib/RCS/GffRead.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 14:01 Jul 19 2004 kivinen
#	  Last Modification : 02:27 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 23:27:44 $
#	  Revision number   : $Revision: 1.18 $
#	  State             : $State: Exp $
#	  Version	    : 1.995
#	  Edit time	    : 281 min
#
#	  Description       : Simple GFF file read module
#
#	  $Log: GffRead.pm,v $
#	  Revision 1.18  2007/05/23 23:27:44  kivinen
#	  	Added filename to most of the error messages.
#
#	  Revision 1.17  2007/04/23 23:27:45  kivinen
#	  	Added warning if we have same label twice.
#
#	  Revision 1.16  2006/11/23 18:17:58  kivinen
#	  	Changed to use hex encoding for the VOID type.
#
#	  Revision 1.15  2006/11/01 19:21:05  kivinen
#	  	Added debug print function.
#
#	  Revision 1.14  2006/10/24 21:15:57  kivinen
#	  	Added manual. Removed debug prints. Optimized parsing by
#	  	sorting ifs of type.
#
#	  Revision 1.13  2005/10/13 19:07:16  kivinen
#	  	Fixed 64-bit handling (using 32 bit operations).
#
#	  Revision 1.12  2005/10/11 15:09:20  kivinen
#	  	Changed to use II instead of Q when reading 64-bit values.
#
#	  Revision 1.11  2005/02/05 14:32:03  kivinen
#	  	Fixed byte processing so it is now handled as number not as
#	  	string.
#
#	  Revision 1.10  2004/12/05 16:47:15  kivinen
#	  	Added read_area_name function.
#
#	  Revision 1.9  2004/08/15 12:35:12  kivinen
#	  	Moved stuff to Gff.pm. Lots of other fixes.
#
#	  Revision 1.8  2004/07/26 15:12:11  kivinen
#	  	Added binmode.
#
#	  Revision 1.7  2004/07/22 14:52:02  kivinen
#	  	Changed find function so it can be used to find the full
#	  	structures too.
#
#	  Revision 1.6  2004/07/20 15:26:50  kivinen
#	  	Changed so that $gff{''} will have full path including the
#	  	array index. This make is possible to find specific items from
#	  	the arrays, and to know which item it actually did find.
#
#	  Revision 1.5  2004/07/20 14:03:26  kivinen
#	  	Added more documenation to include and exclude. They really
#	  	only work for top level. Added automatic exclusion of
#	  	everything if only include is given. Changed include to use
#	  	full path, but that really does not help, as no partial match
#	  	are done... Renamed dump to print. Added option to print types
#	  	also. Added find routine. Added GffVar package for easy adding
#	  	of variables to objects.
#
#	  Revision 1.4  2004/07/19 14:11:51  kivinen
#	  	Fixed exclude to exclude_field.
#
#	  Revision 1.3  2004/07/19 14:01:25  kivinen
#	  	Removed debug statements.
#
#	  Revision 1.2  2004/07/19 13:59:18  kivinen
#	  	New version.
#
#	  Revision 1.1  2004/07/19 11:09:02  kivinen
#	  	Initial version.
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package GffRead;
use Gff;
use strict;
use Carp;

######################################################################
# \%gff = read(%options);
#
# Options can be:
#
# include	=> regexp
#		Include structures if their label match the regexp.
#		Note, that if this does not match the whole subtree
#		is skipped, meaning that all the lower level labels
#		cannot match. Use this to include top level
#		structures.
# exclude	=> regexp
#		Exclude structures if their label match the regexp
#		Note, that if this does match the whole subtree
#		is skipped, meaning that all the lower level labels
#		cannot match. Use this to exclude full path structures.
# include_field => regexp
#		Include the fields if their labels match the regexp
# exclude_field => regexp
#		Exclude the fields if their labels match the regexp
#
# find_label	=> regexp
#		Find lables having value matching regexp
# find_label_proc => proc($topgff, $full_label, $label, $value, $type);
#		Perl procedure to call if label is found
#
# find_field	=> regexp
#		Find fields having value matching regexp
# find_field_proc => proc($top_gff, $full_label, $label, $value, $type);
#		Perl procedure to call if field is found
#
# check_recursion => boolean
#		Verify that the file does not have recursion
#		This uses more memory
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
    my(%gff, %self);
    my(@struct_array, @field_array, @label_array, $field_data_block,
       @field_indices_array, @list_indices_array, $len);
    my($struct_len, $field_len, $label_len, $field_data_len,
       $field_indices_len, $list_indices_len);
    my($file_type, $file_version, $skipme, $struct_offset, $struct_count, 
       $field_offset, $field_count, $label_offset, $label_count, 
       $field_data_offset, $field_data_count, 
       $field_indices_offset, $field_indices_count, 
       $list_indices_offset, $list_indices_count);
    my($data, $off, $ret, $filename);

    # If we have include but no exclude, make default exclude of everything
    if (defined($options{'include'}) && !defined($options{'exclude'})) {
	$options{'exclude'} = '.*';
    }

    # If we have include but no exclude, make default exclude of everything
    if (defined($options{'include_field'}) &&
	!defined($options{'exclude_field'})) {
	$options{'exclude_field'} = '.*';
    }

    $self{'options'} = \%options;

    if (defined($options{'filename'})) {
	if (!open(FILE, "<$options{'filename'}")) {
	    return error(\%self, "Cannot open $options{'filename'}");
	}
	binmode(FILE);
	$filename = $options{'filename'};
    } else {
	$filename = "<data given in argument>";
    }

    $off = 0;

    if (defined($options{'seek_pos'})) {
	if (defined($options{'filename'})) {
	    if (!sysseek(FILE, $options{'seek_pos'}, 0)) {
		return error(\%self, "Cannot seek in file $filename");
	    }
	} else {
	    $off = $options{'seek_pos'};
	}
    }

    # Read the header

    if (defined($options{'filename'})) {
	if (sysread(FILE, $data, 56) != 56) {
	    return error(\%self,
			 "Could not read the header in file $filename");
	}
    } else {
	if ($off + 56 > length($options{'data'})) {
		return error(\%self,
			 "End of data while reading header in file $filename");
	}
	$data = substr($options{'data'}, $off, 56);
	#$data = $options{'data'};
    }

    # Parse the header

    ($file_type, $file_version, $struct_offset, $struct_count, 
     $field_offset, $field_count, $label_offset, $label_count, 
     $field_data_offset, $field_data_count, 
     $field_indices_offset, $field_indices_count, 
     $list_indices_offset, $list_indices_count) = 
	 unpack("a4a4VVVVVVVVVVVV", $data);

    if ($file_version ne "V3.2") {
	return error(\%self,
		     "Invalid version : $file_version in file $filename");
    }

#   &Debug::debug(3, "File type = $file_type");

    $gff{' ____file_type'} = $file_type;
    $gff{' ____file_version'} = $file_version;

    # Parse struct array

    $struct_len = $struct_count * 12;
    if ($struct_offset != 56) {
	return error(\%self, "Struct array not after header, " .
		     "offset = $struct_offset instead of 56 in " .
		     "file $filename, filetype $file_type, fileversion $file_version, header_data = $data");
    }
    if (defined($options{'filename'})) {
	if (sysread(FILE, $data, $struct_len) != $struct_len) {
	    return error(\%self,
			 "Could not read struct array in file $filename");
	}
    } else {
	if ($off + $struct_offset + $struct_len > length($options{'data'})) {
	    return error(\%self, "End of data while reading struct array " .
			 "in file $filename");
	}
	$data = substr($options{'data'}, $off + $struct_offset, $struct_len);
    }

#    &Debug::debug(5, "Struct array, offset = $struct_offset, len = $struct_len");

    @struct_array = unpack("V*", $data);

    if ($struct_count == 0) {
	return error(\%self, "No top level struct entry in file $filename");
    }

    # Parse field array

    $field_len = $field_count * 12;
    if ($field_offset != $struct_offset + $struct_len) {
	return error(\%self, "Field array not after struct array, " .
		     "offset = $field_offset instead of " .
		     ($struct_offset + $struct_len) . " in file $filename");
    }
    if (defined($options{'filename'})) {
	if (sysread(FILE, $data, $field_len) != $field_len) {
	    return error(\%self, "Could not read field array in " .
			 "file $filename");
	}
    } else {
	if ($off + $field_offset + $field_len > length($options{'data'})) {
	    return error(\%self, "End of data while reading field array " .
			 "in file $filename");
	}
	$data = substr($options{'data'}, $off + $field_offset, $field_len);
    }

#    &Debug::debug(5, "Field array, offset = $field_offset, len = $field_len");

    @field_array = unpack("V*", $data);

    # Parse label array

    $label_len = $label_count * 16;
    if ($label_offset != $field_offset + $field_len) {
	return error(\%self, "Label array not after field array, " .
		     "offset = $label_offset instead of " .
		     ($field_offset + $field_len) . " in file $filename");
    }
    if (defined($options{'filename'})) {
	if (sysread(FILE, $data, $label_len) != $label_len) {
	    return error(\%self,
			 "Could not read label array in file $filename");
	}
    } else {
	if ($off + $label_offset + $label_len > length($options{'data'})) {
	    return error(\%self, "End of data while reading label array" .
			 " in file $filename");
	}
	$data = substr($options{'data'}, $off + $label_offset, $label_len);
    }
    
#    &Debug::debug(5, "Label array, offset = $label_offset, len = $label_len");

    @label_array = unpack("A16" x $label_count, $data);

    # Parse field data block

    $field_data_len = $field_data_count;
    if ($field_data_offset != $label_offset + $label_len) {
	return error(\%self, "Field data block not after label array, " .
		     "offset = $field_data_offset instead of " .
		     ($label_offset + $label_len) . " in file $filename");
    }
    if (defined($options{'filename'})) {
	if (sysread(FILE, $field_data_block, $field_data_len) !=
	    $field_data_len) {
	    return error(\%self, "Could not read field data block" .
			 " in file $filename");
	}
    } else {
	if ($off + $field_data_offset + $field_data_len >
	    length($options{'data'})) {
	    return error(\%self, "End of data while reading field data" .
			 " in file $filename");
	}
	$field_data_block = substr($options{'data'},
				   $off + $field_data_offset, $field_data_len);
    }
    
#    &Debug::debug(5, "Field data, offset = $field_data_offset, len = $field_data_len");

    # Parse field indices array

    $field_indices_len = $field_indices_count;
    if ($field_indices_offset != $field_data_offset + $field_data_len) {
	return error(\%self,
		     "Field indices array not after field data block, " .
		     "offset = $field_indices_offset instead of " .
		     ($field_data_offset + $field_data_len) .
		     " in file $filename");
    }
    if (defined($options{'filename'})) {
	if (sysread(FILE, $data, $field_indices_len) != $field_indices_len) {
	    return error(\%self, "Could not read field indices array" .
			 " in file $filename");
	}
    } else {
	if ($off + $field_indices_offset + $field_indices_len >
	    length($options{'data'})) {
	    return error(\%self, "End of data while reading field indices" .
			 " in file $filename");
	}
	$data = substr($options{'data'}, $off + $field_indices_offset,
		       $field_indices_len);
    }

#    &Debug::debug(5, "Field indices, offset = $field_indices_offset, len = $field_indices_len");

    @field_indices_array = unpack("V*", $data);
    

    # Parse field data block
    
    $list_indices_len = $list_indices_count;
    if ($list_indices_offset != $field_indices_offset + $field_indices_len) {
	return error(\%self,
		     "List indices array not after field indices array, " .
		     "offset = $list_indices_offset instead of " .
		     ($field_indices_offset + $field_indices_len) .
		     " in file $filename");
    }
    if (defined($options{'filename'})) {
	if (sysread(FILE, $data, $list_indices_len) != $list_indices_len) {
	    return error(\%self, "Could not read list indices array" .
			 " in file $filename");
	}
    } else {
	if ($off + $list_indices_offset + $list_indices_len >
	    length($options{'data'})) {
	    return error(\%self, "End of data while reading list indices" .
			 " in file $filename");
	}
	$data = substr($options{'data'}, $off + $list_indices_offset,
		       $list_indices_len);
    }
    
#    &Debug::debug(5, "List indices, offset = $list_indices_offset, len = $list_indices_len");

    @list_indices_array = unpack("V*", $data);

    if (defined($options{'filename'})) {
	close(FILE);
    }

    $self{'struct_array'} = \@struct_array;
    $self{'field_array'} = \@field_array;
    $self{'label_array'} = \@label_array;
    $self{'field_data_block'} = $field_data_block;
    $self{'field_indices_array'} = \@field_indices_array;
    $self{'list_indices_array'} = \@list_indices_array;
    $self{'topgff'} = \%gff;

    $gff{''} = '';
    $ret = read_struct(\%self, \%gff, 0);
    if (!defined($ret)) {
	return undef;
    }

    return Gff->new(\%gff);

}

######################################################################
# $ret = read_struct(\%self, \%gff, $structure_index);
#
# return undef on error, and 1 otherwise

sub read_struct {
    my($self, $gff, $struct_index) = @_;
    my($type, $data_or_offset, $count, $ret);

#    if (defined($$self{'options'}{'check_recursion'})) {
#	if (defined($$self{'structs'}{$struct_index})) {
#	    return error($self, "Parsing same struct twice");
#	}
#	$$self{'structs'}{$struct_index} = 1;
#    }
    
    $type = $$self{'struct_array'}[$struct_index * 3];
    $data_or_offset = $$self{'struct_array'}[$struct_index * 3 + 1];
    $count = $$self{'struct_array'}[$struct_index * 3 + 2];

    if ($struct_index * 3 + 3 > $#{$$self{'struct_array'}} + 1) {
	return error($self,
		     "Struct index $struct_index outside of struct_array");
    }

    if (!defined($$self{'options'}{'no_store'}) ||
	!$$self{'options'}{'no_store'}) {
	$$gff{" ____struct_type"} = $type;
    }
    if ($count == 1) {
	$ret = read_field($self, $gff, $data_or_offset);
	if (!defined($ret)) {
	    return $ret;
	}
    } else {
	my($i);
	
	return 1 if ($count == 0);
	
	if ($data_or_offset % 4 != 0) {
	    return error($self,
			 "Struct index not divisable by 4 : $data_or_offset");
	}

	$data_or_offset = $data_or_offset / 4;
	for($i = $data_or_offset; $i < $data_or_offset + $count; $i++) {
	    $ret = read_field($self, $gff, $$self{'field_indices_array'}[$i]);
	    if (!defined($ret)) {
		return $ret;
	    }
	}
    }
    return 1;
}

######################################################################
# $ret = read_field(\%self, \%gff, $field_index);
#
# return undef on error, and 1 otherwise

sub read_field {
    my($self, $gff, $field_index) = @_;
    my($type, $label_index, $data_or_offset);
    my($label, $value);

    $field_index *= 3;

    $type = $$self{'field_array'}[$field_index];
    $label_index = $$self{'field_array'}[$field_index + 1];
    $data_or_offset = $$self{'field_array'}[$field_index + 2];

    $label = $$self{'label_array'}[$label_index];
    
    if ($label_index > $#{$$self{'label_array'}}) {
	return error($self,
		     "Label index $label_index outside of label_array");
    }

    if ($type == 14 || $type == 15) {
	if (defined($$self{'options'}{'include'}) &&
	    ($$gff{''} . '/' . $label) =~ /$$self{'options'}{'include'}/) {
	} elsif (defined($$self{'options'}{'exclude'}) &&
		 ($$gff{''} . '/' . $label) =~
		 /$$self{'options'}{'exclude'}/) {
	    return 1;
	}
    } else {
	if (defined($$self{'options'}{'include_field'}) &&
	    $label =~ /$$self{'options'}{'include_field'}/) {
	} elsif (defined($$self{'options'}{'exclude_field'}) &&
		 $label =~ /$$self{'options'}{'exclude_field'}/) {
	    return 1;
	}
    }
    if ($type == 0) {		# Byte
	$value = $data_or_offset & 0xff;
    } elsif ($type == 8) {	# Float
	# XXX this needs to be fixed if ever run on the non intel machine
	($value) = unpack("f", pack("V", $data_or_offset));
    } elsif ($type == 2) {	# Word
	$value = $data_or_offset & 0xffff;
    } elsif ($type == 1) {	# Char
	$value = $data_or_offset & 0xff;
    } elsif ($type == 3) {	# Short
	($value) = unpack("s", pack("S", $data_or_offset & 0xffff));
    } elsif ($type == 4) {	# DWord
	$value = $data_or_offset;
    } elsif ($type == 5) {	# Int
	($value) = unpack("i", pack("I", $data_or_offset));
    } elsif ($type == 14) {	# Struct
	my(%struct, $ret);

	$struct{''} = $$gff{''} . '/' . $label;
	$ret = read_struct($self, \%struct, $data_or_offset);
	if (!defined($ret)) {
	    return $ret;
	}
	$value = \%struct;
    } elsif ($type == 15) {	# List
	my(@list, $count, $i);

	if ($data_or_offset % 4 != 0) {
	    return error($self, "List index not divisable by 4");
	}

	$data_or_offset = $data_or_offset / 4;
	
	if ($data_or_offset > $#{$$self{'list_indices_array'}}) {
	    return error($self, "List index outside the list indices array");
	}
	
	$count = $$self{'list_indices_array'}[$data_or_offset];
	
#	if (defined($$self{'options'}{'check_recursion'})) {
#	    if (defined($$self{'lists'}{$data_or_offset})) {
#		return error($self, "Parsing same list twice");
#	    }
#	    $$self{'lists'}{$data_or_offset} = 1;
#	}
	if ($data_or_offset + $count > $#{$$self{'list_indices_array'}}) {
	    return error($self,
			 "List index overflow the list indices array");
	}

	$data_or_offset++;
	
	for($i = $data_or_offset; $i < $data_or_offset + $count; $i++) {
	    my(%struct, $ret);

	    $struct{''} = $$gff{''} . '/' . $label .
		"[" . ($i - $data_or_offset) . "]";
	    $ret = read_struct($self, \%struct,
				$$self{'list_indices_array'}[$i]);
	    if (!defined($ret)) {
		return $ret;
	    }
	    push(@list, \%struct);
	}
	$value = \@list;
    } else {
	my($len);

	if ($data_or_offset > length($$self{'field_data_block'})) {
	    return error($self, "Field data offset $data_or_offset " .
			 "outside of field data block");
	}

	if ($type == 6) {	# DWord64
	    $len = 8;
#	    ($value) = unpack("Q", substr($$self{'field_data_block'},
#					  $data_or_offset, 8));
 	    my($value1, $value2);
	    ($value1, $value2) = unpack("II", substr($$self{'field_data_block'},
						     $data_or_offset, 8));
	    $value = ($value1 * (2**32) + $value2);
	} elsif ($type == 7) {	# Int64
	    $len = 8;
	    ($value) = unpack("q", substr($$self{'field_data_block'},
					  $data_or_offset, 8));
	} elsif ($type == 9) {	# Double
	    $len = 8;
	    ($value) = unpack("d", substr($$self{'field_data_block'},
					  $data_or_offset, 8));
	} elsif ($type == 10) {	# CExoString
	    $len = unpack("V", substr($$self{'field_data_block'},
				      $data_or_offset, 4));
	    $value = substr($$self{'field_data_block'},
			    $data_or_offset + 4, $len);
	} elsif ($type == 11) {	# ResRef
	    $len = unpack("C", substr($$self{'field_data_block'},
				      $data_or_offset, 1));
	    $value = substr($$self{'field_data_block'},
			    $data_or_offset + 1, $len);
	} elsif ($type == 12) {	# CExoLocString
	    my($size, $string_ref, $string_count);
	    my(%loc_strings, $data);

	    ($size, $string_ref, $string_count) =
		unpack("VVV", substr($$self{'field_data_block'},
				     $data_or_offset, 12));
	    if (!defined($$self{'options'}{'no_store'}) ||
		!$$self{'options'}{'no_store'}) {
		$$gff{$label . ". ____string_ref"} = $string_ref;
	    }
	    $data = substr($$self{'field_data_block'},
			   $data_or_offset + 12, $size - 8);
	    %loc_strings = unpack("VV/a" x $string_count, $data);
	    
	    $value = \%loc_strings;
	    $len = $size + 4;
	} elsif ($type == 13) {	# VOID
	    $len = unpack("V", substr($$self{'field_data_block'},
				      $data_or_offset, 4));
	    $value = unpack("H*", substr($$self{'field_data_block'},
					 $data_or_offset + 4, $len));
	}
	if ($data_or_offset + $len > length($$self{'field_data_block'})) {
	    return error($self, "Field data overflows from the field " .
			 "data block area offset = " .
			 ($data_or_offset + $len) . ", len = " .
			 length($$self{'field_data_block'}));
	}
    }
    if (!defined($$self{'options'}{'no_store'}) ||
	!$$self{'options'}{'no_store'}) {
	if (defined($$gff{$label})) {
	    carp "Label $label twice in the $$gff{''}";
	}
	$$gff{$label . ". ____type"} = $type;
	$$gff{$label} = $value;
    }

    if (defined($$self{'options'}{'find_label'}) &&
	defined($$self{'options'}{'find_label_proc'}) &&
	defined($$self{'options'}{'find_field'}) &&
	defined($$self{'options'}{'find_field_proc'}) &&
	$$self{'options'}{'find_label_proc'} eq
	$$self{'options'}{'find_field_proc'}) {
	if (($$gff{''} . "/" . $label) =~ /$$self{'options'}{'find_label'}/ &&
	    !ref($value) &&
	    $value =~ /$$self{'options'}{'find_field'}/) {
	    &{$$self{'options'}{'find_label_proc'}}($$self{'topgff'},
						    $$gff{''} . "/" . $label,
						    $label,
						    $value,
						    $type);
	}
    } else {
	if (defined($$self{'options'}{'find_label'}) &&
	    defined($$self{'options'}{'find_label_proc'}) &&
	    ($$gff{''} . "/" . $label) =~ /$$self{'options'}{'find_label'}/) {
	    &{$$self{'options'}{'find_label_proc'}}($$self{'topgff'},
						    $$gff{''} . "/" . $label,
						    $label,
						    $value,
						    $type);
	}
	if (defined($$self{'options'}{'find_field'}) &&
	    defined($$self{'options'}{'find_field_proc'}) &&
	    !ref($value) &&
	    $value =~ /$$self{'options'}{'find_field'}/) {
	    &{$$self{'options'}{'find_field_proc'}}($$self{'topgff'},
						    $$gff{''} . "/" . $label,
						    $label,
						    $value,
						    $type);
	}
    }
    return 1;
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
    
	croak "Error parsing GFF: " . @text[0];
}

######################################################################
# debug(level, $text)

sub Debug::debug {
    my($level, $str) = @_;
    print(STDERR $str, "\n");
}

######################################################################
# ($name, $tag) = read_area_name($file);

sub read_area_name {
    my($file) = @_;
    my($gff, $name, $tag);

    if ($file =~ s/\.[^.\/]*$/.are/) {
    } else {
	$file .= ".are";
    }
    
    $gff = GffRead::read(filename => $file,
			 return_errors => 1);
    if (!defined($gff)) {
	croak "Cannot open $file";
    } else {
	$name = $$gff{Name}{0};
	$tag = $$gff{Tag};
	if (!defined($name) || !defined($tag)) {
	    croak "Cannot find Name or Tag from $file";
	} else {
	    return ($name, $tag);
	}
    }
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################

__END__

=head1 NAME

GffRead - Perl Module to Read Gff datastructures

=head1 ABSTRACT

This module allows easy reading and parsing of the nwn gff files. It
returns a hash structure having everything from the gff as a
hierarchical hash-structure.

=head1 DESCRIPTION

The basic working is that you give hash of options to the
B<GffRead::read>, and get Gff object back from there. The data is
either read from the string given to the read function, or from the
file given to the read function.

=head1 B<GffRead::read>

B<GffRead::read> is used to read and parse gff structure. Take hash
table of options in, and returns a reference to the B<Gff(3)> object
back. 

=over 4

=head2 USAGE

\%gff = read(%options);

=head2 OPTIONS

Following options can be given to the B<GffRead::read>.
 
=over 4

=item B<filename> => I<filename>

Filename to read data from. If this exits, then data is ignored.

=item B<data> => I<data>

Data buffer to use instead of filename. This only used if filename
is no present.

=item B<find_label> => I<regexp>

Find lables having value matching regexp.

=item B<find_label_proc> => I<proc($topgff, $full_label, $label, $value, $type);>

Perl procedure to call if label is found.

=item B<find_field> => I<regexp>

Find fields having value matching regexp.

=item B<find_field_proc> => I<proc($top_gff, $full_label, $label, $value, $type);>

Perl procedure to call if field is found.

=item B<include> => I<regexp>

Include structures if their label match the regexp. Note, that if this
does not match the whole subtree is skipped, meaning that all the
lower level labels cannot match. Use this to include top level
structures.

=item B<exclude> => I<regexp>

Exclude structures if their label match the regexp Note, that if this
does match the whole subtree is skipped, meaning that all the lower
level labels cannot match. Use this to exclude full path structures.

=item B<include_field> => I<regexp>

Include the fields if their labels match the regexp.

=item B<exclude_field> => I<regexp>

Exclude the fields if their labels match the regexp.

=item B<no_store> => I<boolean>

Do not store anything, simply parse the structure.

=item B<seek_pos> => I<offset>

Position to seek in file or data.

=item B<return_errors> => I<boolean>

If false then die on errors, otherwise return undef on error.

=back

=back

=head1 B<GffRead::read_area_name>

B<GffRead::read_area_name> is used to quickly read are anem and tag
from the area file. The file given can be either area file directly or
some other area file (git or gic). Returns list having 2 elements,
area name and area tag.

=head2 USAGE

($name, $tag) = read_area_name($file);

=head1 SEE ALSO

gffprint(1), Gff(3), and GffWrite(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Created to do automated things for the cerea persistent world. 

=cut
