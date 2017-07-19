#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# Tlk.pm -- Tlk object module
# Copyright (c) 2005 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: Tlk.pm
#	  $Source: /u/samba/nwn/perllib/RCS/Tlk.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 11:29 Oct 25 2005 kivinen
#	  Last Modification : 01:13 Jan  3 2007 kivinen
#	  Last check in     : $Date: 2007/01/02 23:20:46 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.53
#	  Edit time	    : 29 min
#
#	  Description       : Tlk object module
#
#	  $Log: Tlk.pm,v $
#	  Revision 1.2  2007/01/02 23:20:46  kivinen
#	  	Added support for writing tlk files.
#
#	  Revision 1.1  2005/10/27 17:03:45  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package Tlk;
use strict;
use Carp;

######################################################################
# Set tlk

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    if (!ref($_[0])) {
	my(%temp);
	bless \%temp, $class;
	return \%temp;
    } 
    bless $_[0], $class;
    return $_[0];
}

######################################################################
# $value = $self->get_or_set($field)
# $value = $self->get_or_set($field, $value);
#
# Get or set field

sub get_or_set {
    my $self = shift;
    my $field = shift;

    if (@_) {
	$$self{$field} = $_[0];
    }
    return $$self{$field};
}
    
######################################################################
# $file_type = $self->file_type()
# $file_type = $self->file_type($file_type);
#
# Get or set file type

sub file_type {
    my $self = shift;
    return $self->get_or_set('file_type', @_);
}

######################################################################
# $file_version = $self->file_version()
# $file_version = $self->file_version($file_version);
#
# Get or set file version

sub file_version {
    my $self = shift;
    return $self->get_or_set('file_version', @_);
}


######################################################################
# $language_id = $self->language_id()
# $language_id = $self->language_id($language_id);
#
# Get or set language id

sub language_id {
    my $self = shift;
    return $self->get_or_set('language_id', @_);
}

######################################################################
# $string_count = $self->string_count()
# $string_count = $self->string_count($string_count);
#
# Get or set language id

sub string_count {
    my $self = shift;
    return $self->get_or_set('string_count', @_);
}

######################################################################
# %string = $self->string_info($string_ref)
# %string = $self->string_info($string_ref, %string)

sub string_info {
    my $self = shift;
    my $i = shift;


    if ($i < 0) {
	return undef;
    }
    if ($i >= $$self{string_count} && !@_) {
	return undef;
    }

    if (@_) {
	my(%string) = @_;
	my($text);
	$text = $$self{strings}[$i]{text};
	$$self{strings}[$i] = \%string;
	$$self{strings}[$i]{text} = $text;
	if ($i >= $$self{string_count}) {
	    $$self{string_count} = $i + 1;
	}
    }
    return %{$$self{strings}[$i]};
}

######################################################################
# $string = $self->string($string_ref)
# $string = $self->string($string_ref, $string)

sub string {
    my($self) = shift;
    my($i) = shift;

    if ($i < 0) {
	return undef;
    }
    if ($i >= $$self{string_count} && !@_) {
	return undef;
    }

    if (@_) {
	$$self{strings}[$i]{text} = $_[0];
	if ($i >= $$self{string_count}) {
	    $$self{string_count} = $i + 1;
	}
    } else {
	if (!defined($$self{strings}[$i]{text})) {
	    my($off, $len);
	    if (!defined($$self{strings}[$i]{OffsetToString})) {
		return '';
	    }
	    $off = $$self{base_offset} +
		$$self{string_entries_offset} +
		$$self{strings}[$i]{OffsetToString};
	    $len = $$self{strings}[$i]{StringSize};
	    if (!defined($len) || $len == 0) {
		return '';
	    }
	    if (defined($$self{options}{filename})) {
		seek($$self{file}, $off, 0);
		if (read($$self{file}, $$self{strings}[$i]{text}, $len) !=
		    $len) {
		    confess "Read error reading string $i";
		}
	    } else {
		if ($off + $len > length($$self{options}{data})) {
		    confess "Out of bounds error reading string $i";
		}
		$$self{strings}[$i]{text} =
		    substr($$self{options}{data}, $off, $len);
	    }
	}
    }
    return $$self{strings}[$i]{text};
}

######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
