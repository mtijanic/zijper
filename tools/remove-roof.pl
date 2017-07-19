#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# remove-roof.pl -- Remove roof from the tile
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: remove-roof.pl
#	  $Source: /u/samba/nwn/bin/RCS/remove-roof.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 19:10 Apr 23 2007 kivinen
#	  Last Modification : 01:28 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:28:23 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.87
#	  Edit time	    : 38 min
#
#	  Description       : Remove roof from the tile
#
#	  $Log: remove-roof.pl,v $
#	  Revision 1.2  2007/05/23 22:28:23  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2007/04/23 23:35:50  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package RemoveRoof;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Trn;
use TrnRead;
use TrnWrite;
use Pod::Usage;

$Opt::verbose = 0;
$Opt::output = undef;
$Opt::variation = undef;

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
    read_rc_file("$ENV{'HOME'}/.removeroofrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"output|o=s" => \$Opt::output,
		"variation|n=i" => \$Opt::variation,
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

my($i, $j, $t0);
my($trn, $res, $modified);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

$modified = 0;

foreach $i (@ARGV) {
    $t0 = time();
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $trn = TrnRead::read('filename' => $i);
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    printf("File $i, type = %s, version = %d.%02d\n",
	   $trn->file_type, $trn->version_major, $trn->version_minor)
	if ($Opt::verbose > 1);
    printf("Resource count = %d\n", $trn->resource_count)
	if ($Opt::verbose > 1);
    for($j = 0; $j < $trn->resource_count; $j++) {
	printf("Filename = %04d.%s, type = %s, size = %d\n",
	       $j,
	       lc($trn->resource_type($j)),
	       $trn->resource_type($j),
	       $trn->resource_size($j))
	    if ($Opt::verbose > 2);
	if ($trn->resource_type($j) eq 'RIGD') {
	    $res = $trn->decode($j);
	    printf("Rigd model = %s\n", $$res{'Name'})
		if ($Opt::verbose > 1);
	    if ($$res{'Name'} =~ /_R$/) {
		if ($Opt::verbose) {
		    printf("Removing roof %s\n", $$res{'Name'});
		}
		$trn->delete_resource($j);
		$modified = 1;
	    }
	}
    }
    if ($modified) {
	my($file, $var);
	
	if (defined($Opt::variation)) {
	    $var = $Opt::variation;
	} else {
	    $file = $i;
	    $file =~ s/[0-9][0-9]\.mdb$//;
	    for($var = 1; $var < 100; $var++) {
		if (!-f sprintf("%s%02d.mdb", $file, $var)) {
		    last;
		}
	    }
	}
	$var = sprintf("%02d", $var);
	for($j = 0; $j < $trn->resource_count; $j++) {
	    $res = $trn->decode($j);
	    $$res{'Name'} =~
		s/(_)[0-9][0-9](|_W|_F|_R|_C2|_C3)$/$1$var$2/i;
	    $trn->encode($j, $res);
	}
	
	if (!defined($Opt::output)) {
	    $file = $i;
	    $file =~ s/[0-9][0-9]\./$var./g;
	} else {
	    $file = $Opt::output;
	}
	if ($Opt::verbose) {
	    printf("Writing to %s\n", $file);
	}
	&TrnWrite::write($trn, filename => $file);
	
	if ($Opt::verbose) {
	    printf("Write done, %g seconds\n", time() - $t0);
	}
    }
}

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

remove-roof - Remove roof from the tile(s)

=head1 SYNOPSIS

remove-roof [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--output>|B<-o> I<filename>]
    [B<--variation>|B<-n> I<variation>]
    I<filename> ...

remove-roof B<--help>

=head1 DESCRIPTION

B<remove-roof> decodes the mdb tile file and removes the roof from the
file (if it exists, if not then nothing is done). Then it will write
new tile back to disk. In case B<--variation> parameter is given then
that variation number is used. If no variation number is given then it
will check the current directory for the tiles and take first free
variation number. In case B<--output> parameter is given then output
is written to that file, otherwise input file name is used, but
variation number is simply replaced with the new variation number.

=head1 OPTIONS

=over 4

=item B<--help> B<-h>

Prints out the usage information.

=item B<--version> B<-V>

Prints out the version information. 

=item B<--verbose> B<-v>

Enables the verbose prints. This option can be given multiple times,
and each time it enables more verbose prints. 

=item B<--config> I<config-file>

All options given by the command line can also be given in the
configuration file. This option is used to read another configuration
file in addition to the default configuration file. 

=item B<--output> B<-o> I<filename>

Output file name. If this is given, then all output is written to the
same file, thus you should only give one input file name. If this is
not given, then same file name prefix is used as the input file name,
but variation number is updated to match the given variation number.

=item B<--variation> B<-n> I<variation>

Variation number to use. If this is given then all files will be using
this variation number. If it is not given then the current directory
is checked for the first free variation number and that is used
instead.

=back

=head1 EXAMPLES

    remove-roof *.mdb
    remove-roof -o tl_sf_cccc_04.mdb -n 04 tl_sf_cccc_01.mdb

=head1 FILES

=over 6

=item ~/.removeroofrc

Default configuration file.

=back

=head1 SEE ALSO

update-variations(1), trnprint(1), Trn(3), TrnWrite(3) and TrnRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was created as we needed to have some rooms without
roofs, as the creatures living is those rooms are so big that most of
the creature goes through the roof. 
