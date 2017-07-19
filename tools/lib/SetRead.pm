#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# SetRead.pm -- SetRead parser
# Copyright (c) 2005 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: SetRead.pm
#	  $Source: /u/samba/nwn/perllib/RCS/SetRead.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 12:35 Sep 29 2005 kivinen
#	  Last Modification : 13:58 Sep 29 2005 kivinen
#	  Last check in     : $Date: 2005/10/11 15:11:20 $
#	  Revision number   : $Revision: 1.1 $
#	  State             : $State: Exp $
#	  Version	    : 1.21
#	  Edit time	    : 11 min
#
#	  Description       : Reads Set files
#
#	  $Log: SetRead.pm,v $
#	  Revision 1.1  2005/10/11 15:11:20  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package SetRead;
use strict;
use Carp;

######################################################################
# \@set = read($file)

sub read {
    my($file) = @_;
    my(%set, $top);

    open(FILE, "<$file") || croak "Cannot open file $file : $!";
    while (<FILE>) {
	chomp;
	s/[\r\n]//g;
	s/;.*//g;
	next if (/^\s*$/);
	if (/^\s*\[(.*)\]\s*$/) {
	    $top = $1;
	} elsif (/^\s*([A-Za-z0-9]*)=(.*)\s*$/) {
	    $set{$top}{$1} = $2;
	} else {
	    carp "Invalid line $_";
	}
    }
    close(FILE);
    return \%set;
}

######################################################################
# \@set = parse($data)

sub parse {
    my($data) = @_;
    my(%set, $top);

    foreach $_ (split(/\n/, $data)) {
	chomp;
	s/[\r\n]//g;
	s/;.*//g;
	next if (/^\s*$/);
	if (/^\s*\[(.*)\]\s*$/) {
	    my(%hash);
	    $top = $1;
	    $set{$top} = \%hash;
	} elsif (/^\s*([A-Za-z0-9]*)=(.*)\s*$/) {
	    $set{$top}{$1} = $2;
	} else {
	    carp "Invalid line $_";
	}
    }
    return \%set;
}


######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
