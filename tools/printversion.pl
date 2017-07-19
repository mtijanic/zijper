#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# printversion.pl -- Print version numbers of files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: printversion.pl
#	  $Source: /u/samba/nwn/bin/RCS/printversion.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 18:32 Aug 25 2004 kivinen
#	  Last Modification : 01:28 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:28:17 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.3
#	  Edit time	    : 4 min
#
#	  Description       : Program to print version numbers of files
#
#	  $Log: printversion.pl,v $
#	  Revision 1.2  2007/05/23 22:28:17  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2004/08/25 15:36:53  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
#
######################################################################
# initialization

require 5.6.0;
package PrintVersion;
use strict;
my($i, $progname, $version); 

foreach $i (@ARGV) {
    ($progname, $version) = get_version($i);
    print("  <LI><A HREF=\"$progname\">$progname $version</A>\n");
}

######################################################################
# Get version information
sub get_version {
    my($file) = @_;
    my($program, $revision, $save_version, $edit_time, $version, $progname);
    open(PROGRAM, "<$file") || die "Cannot open file $file : $!";
    undef $/;
    $program = <PROGRAM>;
    $/ = "\n";
    close(PROGRAM);
    if ($program =~ /\$revision:\s*([\d.]*)\s*\$/i) {
	$revision = $1;
    } else {
	$revision = "?.?";
    }

    if ($program =~ /version\s*:\s*([\d.]*\.)*([\d]*)\s/mi) {
	$save_version = $2;
    } else {
	$save_version = "??";
    }

    if ($program =~ /edit\s*time\s*:\s*([\d]*)\s*min\s*$/mi) {
	$edit_time = $1;
    } else {
	$edit_time = "??";
    }

    $version = "$revision.$save_version.$edit_time";
    $progname = $file;
    $progname =~ s/^.*[\/\\]//g;
    return ($progname, $version);
}
