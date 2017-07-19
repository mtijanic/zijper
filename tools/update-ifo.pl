#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# update-ifo.pl -- Update area names in ifo
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: update-ifo.pl
#	  $Source: /u/samba/nwn/bin/RCS/update-ifo.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 02:05 Sep 12 2004 kivinen
#	  Last Modification : 01:29 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:29:23 $
#	  Revision number   : $Revision: 1.5 $
#	  State             : $State: Exp $
#	  Version	    : 1.35
#	  Edit time	    : 14 min
#
#	  Description       : Update area names in ifo
#
#	  $Log: update-ifo.pl,v $
#	  Revision 1.5  2007/05/23 22:29:23  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.4  2007/01/23 22:38:54  kivinen
#	  	Updated manual to allow omitting filenames.
#
#	  Revision 1.3  2007/01/23 22:33:57  kivinen
#	  	Added manual.
#
#	  Revision 1.2  2004/11/14 19:47:49  kivinen
#	  	Added so that default is now *.are.
#
#	  Revision 1.1  2004/09/20 11:44:47  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package UpdateIfo;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use File::Basename;
use GffRead;
use GffWrite;
use Gff;
use Pod::Usage;

######################################################################
# Get version information

open(PROGRAM, "<$0") || die "Cannot open myself from $0 : $!";
undef $/;
$Prog::program = <PROGRAM>;
$/ = "\n";
close(PROGRAM);
if ($Prog::program =~ /\$revision:\s*([\d.]*)\s*\$/i) {
    $Prog::revision = $1;
} else {
    $Prog::revision = "?.?";
}

if ($Prog::program =~ /version\s*:\s*([\d.]*\.)*([\d]*)\s/mi) {
    $Prog::save_version = $2;
} else {
    $Prog::save_version = "??";
}

if ($Prog::program =~ /edit\s*time\s*:\s*([\d]*)\s*min\s*$/mi) {
    $Prog::edit_time = $1;
} else {
    $Prog::edit_time = "??";
}

$Prog::version = "$Prog::revision.$Prog::save_version.$Prog::edit_time";
$Prog::progname = $0;
$Prog::progname =~ s/^.*[\/\\]//g;

$| = 1;

######################################################################
# Read rc-file

if (defined($ENV{'HOME'})) {
    read_rc_file("$ENV{'HOME'}/.updateiforc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"help|h" => \$Opt::help,
		"version|V" => \$Opt::version) || defined($Opt::help)) {
    usage();
}

if (defined($Opt::version)) {
    print("\u$Prog::progname version $Prog::version by Tero Kivinen.\n");
    exit(0);
}

while (defined($Opt::config)) {
    my($tmp);
    $tmp = $Opt::config;
    undef $Opt::config;
    if (-f $tmp) {
	read_rc_file($tmp);
    } else {
	die "Config file $Opt::config not found: $!";
    }
}

######################################################################
# Main loop

$| = 1;

my($i, $name, $item, @area_list);

my($gff);
$gff = GffRead::read(filename => "module.ifo");

if ($#ARGV == -1) {
    printf("No args, defaulting to *.are\n");
    $ARGV[0] = "*.are";
}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    $name = $i;
	$name = basename($name);
    $name =~ s/\.[^\.]*$//g;
    
    $item = {'' => '/Mod_Area_List',
	     ' ____struct_type' => 6,
	     'Area_Name' => $name,
	     'Area_Name. ____type' => 11};
    push(@area_list, $item);
}
$$gff{Mod_Area_list} = \@area_list;
print("Writing module.ifo back\n");
&GffWrite::write($gff, filename => "module.ifo");

exit 0;

######################################################################
# Read rc file

sub read_rc_file {
    my($file) = @_;
    my($next, $space);
    
    if (open(RCFILE, "<$file")) {
	while (<RCFILE>) {
	    chomp;
	    while (/\\$/) {
		$space = 0;
		if (/\s+\\$/) {
		    $space = 1;
		}
		s/\s*\\$//g;
		$next = <RCFILE>;
		chomp $next;
		if ($next =~ s/^\s+//g) {
		    $space = 1;
		}
		if ($space) {
		    $_ .= " " . $next;
		} else {
		    $_ .= $next;
		}
	    }
	    if (/^\s*([a-zA-Z0-9_]+)\s*$/) {
		eval('$Opt::' . lc($1) . ' = 1;');
	    } elsif (/^\s*([a-zA-Z0-9_]+)\s*=\s*\"([^\"]*)\"\s*$/) {
		my($key, $value) = ($1, $2);
		$value =~ s/\\n/\n/g;
		$value =~ s/\\t/\t/g;
		eval('$Opt::' . lc($key) . ' = $value;');
	    } elsif (/^\s*([a-zA-Z0-9_]+)\s*=\s*(.*)\s*$/) {
		my($key, $value) = ($1, $2);
		$value =~ s/\\n/\n/g;
		$value =~ s/\\t/\t/g;
		eval('$Opt::' . lc($key) . ' = $value;');
	    }
	}
	close(RCFILE);
    }
}


######################################################################
# Usage

sub usage {
    Pod::Usage::pod2usage(0);
}

=head1 NAME

update-ifo - Updates the module.ifo file based on the area list

=head1 SYNOPSIS

update-ifo [B<--help>|B<-h>] [B<--version>|B<-V>] 
    [B<--config> I<config-file>]
    [I<filename> ...]

update-ifo B<--help>

=head1 DESCRIPTION

B<update-ifo> will read the module.ifo in from the current directory,
and replace the Mod_Area_list inside the module.ifo with the one
created from the filenames given as an argument (defaults to *.are if
no arguments are given). It will then write updated module.ifo back to
the disk. This can be used along with B<check-module> to fix the
broken module.ifo file.

=head1 OPTIONS

=over 4

=item B<--help> B<-h>

Prints out the usage information.

=item B<--version> B<-V>

Prints out the version information. 

=item B<--config> I<config-file>

All options given by the command line can also be given in the
configuration file. This option is used to read another configuration
file in addition to the default configuration file. 

=back

=head1 EXAMPLES

    update-ifo *.are
    update-ifo

=head1 FILES

=over 6

=item ~/.updateiforc

Default configuration file.

=back

=head1 SEE ALSO

check-module(1), gffprint(1), GffWrite(3), Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was used to "recover" cerea1 module few times, after its
module.ifo was broken. Later it was used when we renamed lots of area
resource files to have better names, and didn't want to manually edit
module.ifo. 
