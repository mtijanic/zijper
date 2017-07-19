#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# change-uiflags.pl -- Fix the uiflags of the models
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: change-uiflags.pl
#	  $Source: /u/samba/nwn/bin/RCS/change-uiflags.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 05:11 Jul  2 2007 kivinen
#	  Last Modification : 05:53 Jul  2 2007 kivinen
#	  Last check in     : $Date: 2007/07/02 02:54:00 $
#	  Revision number   : $Revision: 1.1 $
#	  State             : $State: Exp $
#	  Version	    : 1.87
#	  Edit time	    : 41 min
#
#	  Description       : Fix the uiflags of the models
#
#	  $Log: change-uiflags.pl,v $
#	  Revision 1.1  2007/07/02 02:54:00  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package ChangeUIFlags;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Trn;
use TrnRead;
use TrnWrite;
use Pod::Usage;

$Opt::verbose = 0;
@Opt::type_to_change = ();
@Opt::ui_flags = ();
$Opt::force = 0;

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
    read_rc_file("$ENV{'HOME'}/.changeuiflagsrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"type|t=s" => sub { push(@Opt::type_to_change, $_[1]) },
		"uiflags|u=s" => sub { push(@Opt::ui_flags, $_[1]) },
		"output|o=s" => \$Opt::output,
		"force|f" => \$Opt::force,
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

my($i);

if ($#Opt::type_to_change == -1 && $#Opt::ui_flags == -1) {
    push(@Opt::type_to_change, "rigd\$");
    push(@Opt::ui_flags, 64);
    push(@Opt::type_to_change, "(walk|col2|col3)\$");
    push(@Opt::ui_flags, 0);
} elsif ($#Opt::type_to_change != $#Opt::ui_flags) {
    die "You must give equal amount of --type and --uiflags options";
}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    my($res, $trn, $j, $k, $name, $data);
    
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $main::modified = 0;
    $trn = TrnRead::read('filename' => $i);
    if ($Opt::verbose) {
	printf("Read done\n");
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
	$data = $trn->resource_data($j);
	$res = Trn::decode_resource($data);
	if (defined($$res{Name}) && $$res{Name} ne '') {
	    $name = $$res{Name};
	} elsif ($trn->resource_type($j) eq 'WATR') {
	    $name = sprintf("_%02dx%02dy", $$res{X}, $$res{Y});
	} else {
	    $name = '_';
	}
	$name = '/' . $name . '.' . lc($trn->resource_type($j));
	printf("Decode of $name done\n") 
	    if ($Opt::verbose > 2);
	for($k = 0; $k <= $#Opt::type_to_change; $k++) {
	    if ($name =~ /$Opt::type_to_change[$k]/i) {
		printf("Fixing %s matching %s to have UIFlags %d\n", 
		       $name, $Opt::type_to_change[$k], $Opt::ui_flags[$k])
		    if ($Opt::verbose > 1);
		fix_flags($name, $res, $Opt::ui_flags[$k]);
		$trn->encode($j, $res);
	    }
	}
    }
    if ($main::modified != 0 || $Opt::force) {
	if (defined($Opt::output)) {
	    if (-d $Opt::output) {
		$name = $Opt::output . "/" . $i;
	    } elsif ($Opt::output =~ /\.mdb$/i) {
		$name = $Opt::output;
	    } else {
		$name = $Opt::output . ".mdb";
	    }
	} else {
	    $name = $i;
	}
	if ($Opt::verbose) {
	    print("Writing file $name...\n");
	}
	&TrnWrite::write($trn, filename => $name);
	if ($Opt::verbose) {
	    printf("Read done\n");
	}
    }
}

exit 0;

######################################################################
# fix_flags($name, \%trn, $uiflag);

sub fix_flags {
    my($name, $trn, $uiflag) = @_;
    if (defined($$trn{Material}) &&
	defined($$trn{Material}{Flags})) {
	if ($$trn{Material}{Flags} != $uiflag) {
	    $$trn{Material}{Flags} = $uiflag;
	    $main::modified = 1;
	}
    } elsif (defined($$trn{Flags})) {
	if ($$trn{Flags} != $uiflag) {
	    $$trn{Flags} = $uiflag;
	    $main::modified = 1;
	}
    } else {
	warn "No {Material}{Flags} found from resource $name";
    }
}

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

change-uiflags - Change UIFlags of the models

=head1 SYNOPSIS

change-uiflags [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--type>|B<-t> I<type-regexp>]
    [B<--uiflags>|B<-u> I<uiflags>]
    [B<--output>|B<-s> I<output-file-or-dir>]
    [B<--force>|B<-f>]
    I<filename> ...

change-uiflags B<--help>

=head1 DESCRIPTION

B<change-uiflags> changes the UIFlags of the model based on the list
of regexps and new values. Regexp and new uivalues are given in pairs.
If regexp given in --type matches, then uiflags is set to the value
given in --uiflags option.

If --output option is given and specifies directory then new models
are written to that directory with same name as the input file. If it
is not directory then output file is written to that file (if no mdb
prefix is specified then it is automatically added). If not --output
option is given, then the input file is overwritten with the new file.

This will only write output files if it actually changes the model
unless --force option is given (useful if used with --output option
pointing to directory). 

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

=item [B<--type>|B<-t> I<type-regexp>]
=item [B<--uiflags>|B<-u> I<uiflags>]

Regexp to match the file name and type. If the resource inside the
input file matches this then the UIFlags are changed to the matching
--uiflags. There must be equal number of --type and --uiflags options
as they act as pairs. This defaults to --type "rigd$" --uiflags 64
--type "(walk|col2|col3)$" --uiflags 0
    
=item [B<--output>|B<-s> I<output-file-or-dir>]

Output file or directory. If it is directory then outuput files are
written to that directory with same name as input file (it might be
useful to include --force option in that case). If it points to file
then output is written to that file (if multiple input file names are
given all output is still written to same file). If not given then
input files are overwritten with the new modified version.

=item [B<--force>|B<-f>]

Force writing output file even if the file is not modified.

=back

=head1 EXAMPLES

    change-uiflags --type "rigd\$" --uiflags 64 --type "(walk|col[23])$" --uiflags 0 *.mdb
    change-uiflags -o output-dir/ *.mdb

=head1 FILES

=over 6

=item ~/.changeuiflagsrc

Default configuration file.

=back

=head1 SEE ALSO

trnprint(1), Trn(3), TrnWrite(3) and TrnRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Program made for Hellfire to set the UIFlags in the models when making
tilesets.
