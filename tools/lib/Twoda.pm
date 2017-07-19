#!/usr/local/bin/perl
# -*- perl -*-
######################################################################
# Twoda.pm -- 2DA parser
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: Twoda.pm
#	  $Source: /u/samba/nwn/perllib/RCS/Twoda.pm,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 20:57 Jan  9 2005 kivinen
#	  Last Modification : 01:13 Apr 24 2007 kivinen
#	  Last check in     : $Date: 2007/04/23 23:28:54 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.96
#	  Edit time	    : 31 min
#
#	  Description       : 2DA parser
#
#	  $Log: Twoda.pm,v $
#	  Revision 1.2  2007/04/23 23:28:54  kivinen
#	  	Added writing 2da files code. Changed the basic format of the
#	  	%twoda structure from array to hash having {Header} and
#	  	{Data}.
#
#	  Revision 1.1  2005/02/05 14:32:15  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package Twoda;
use strict;
use Carp;

######################################################################
# \%twoda = read($file)

sub read {
    my($file) = @_;
    my(@header, $line, @line, $i, %twoda);

    open(FILE, "<$file") || croak "Cannot open file $file : $!";
    $line = <FILE>;
    $line =~ s/[\r\n\t]*$//g;
    if ($line !~ /^2DA V2.0$/) {
	croak "Invalid first line of 2da file : $line";
    }
    $line = <FILE>;
    $line =~ s/[\r\n]*$//g;
    if ($line ne '') {
	croak "2nd line should be empty: $line";
    }
    $line = <FILE>;
    $line =~ s/[\r\n]*$//g;
    @header = split(/[ \t]+/, $line);
    $twoda{Header} = \@header;
    $line = 0;
    while (<FILE>) {
	s/[\r\n]$//g;
	next if (/^\s*$/);
	@line = split(/[ \t]+/, $_);
	if ($#line != $#header) {
	    croak "Number of items $#line on line $line differs from header $#header: $_";
	}
	for($i = 0; $i <= $#header; $i++) {
	    $twoda{Data}[$line]{$header[$i]} = $line[$i];
	}
	$line++;
    }
    close(FILE);
    return \%twoda;
}

######################################################################
# $data = write(\%twoda, $file)

sub write {
    my($twoda, $file) = @_;
    my($i, $j, $data, @header, @line);

    $data = "2DA V2.0\r\n\r\n";
    @header = @{$$twoda{Header}};
    $data .= join("\t", @header) . "\r\n";
    for($i = 0; $i <= $#{$$twoda{Data}}; $i++) {
	for($j = 0; $j <= $#header; $j++) {
	    $line[$j] = $$twoda{Data}[$i]{$header[$j]};
	}
	$data .= join("\t", @line) . "\r\n";
    }
    if (defined($file)) {
	open(FILE, ">$file") || croak "Cannot open output file $file : $!";
	binmode(FILE);
	print(FILE $data);
	close(FILE);
    }
    return $data;
}


######################################################################
# Return Success

1;

######################################################################
# EOF
######################################################################
