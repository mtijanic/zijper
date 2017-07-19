#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# trnprint.pl -- Simple program to print trn/trx files / resources
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: trnprint.pl
#	  $Source: /u/samba/nwn/bin/RCS/trnprint.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 22:04 Jan 17 2007 kivinen
#	  Last Modification : 20:05 Aug  2 2007 kivinen
#	  Last check in     : $Date: 2007/08/02 18:56:15 $
#	  Revision number   : $Revision: 1.7 $
#	  State             : $State: Exp $
#	  Version	    : 1.193
#	  Edit time	    : 59 min
#
#	  Description       : Simple program to print Trn/trx files / resources
#
#	  $Log: trnprint.pl,v $
#	  Revision 1.7  2007/08/02 18:56:15  kivinen
#	  	Added --linear option.
#
#	  Revision 1.6  2007/06/10 13:33:10  kivinen
#	  	Added support of printing trx and trn files directly, without
#	  	unpacking them to separate resources first.
#
#	  Revision 1.5  2007/05/30 15:20:00  kivinen
#	  	Added support for unknown# and hash#.
#
#	  Revision 1.4  2007/05/23 22:29:01  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.3  2007/05/23 22:03:49  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.2  2007/04/23 23:36:16  kivinen
#	  	Added uvw format.
#
#	  Revision 1.1  2007/01/23 22:40:58  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package TrnPrint;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Trn;
use TrnRead;
use Pod::Usage;

$Opt::verbose = 0;
$Opt::print_filename = 0;
$Opt::print_basename = 0;
$Opt::separator = ":\t";
$Opt::no_labels = 0;
$Opt::print_all = 0;
$Opt::linear = 0;

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
    read_rc_file("$ENV{'HOME'}/.trnprintrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"print-filename|f" => \$Opt::print_filename,
		"print-basename|b" => \$Opt::print_basename,
		"no-labels|l" => \$Opt::no_labels,
		"separator|s=s" => \$Opt::separator,
		"print-all|a" => \$Opt::print_all,
		"linear|L" => \$Opt::linear,
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

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    my($res, $data);
    
    if (defined($Opt::print_basename) && $Opt::print_basename) {
	$main::file = $i . ": ";
	$main::file =~ s/^.*[\/\\]//g;
    } elsif (defined($Opt::print_filename) && $Opt::print_filename) {
	$main::file = $i . ": ";
    } else {
	$main::file = "";
    }
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    undef $/;
    open(FILE, "<$i") || die "Cannot open $i : $!";
    binmode(FILE);
    $data = <FILE>;
    close(FILE);
    if ($Opt::verbose) {
	printf("Read done\n");
    }
    if (substr($data, 0, 4) eq "NWN2") {
	my($trn, $j, $name);
	$trn = TrnRead::read('data' => $data);
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
	    $res = Trn::decode_resource($data, undef, $Opt::linear);
	    if ($Opt::verbose) {
		printf("Decode done\n");
	    }
	    if (defined($$res{Name}) && $$res{Name} ne '') {
		$name = $$res{Name};
	    } elsif ($trn->resource_type($j) eq 'WATR') {
		$name = sprintf("_%02dx%02dy", $$res{X}, $$res{Y});
	    } else {
		$name = '_';
	    }
	    $name = '/' . $name . '.' . lc($trn->resource_type($j));
	    dump_trn($name, $res);
	}
    } else {
	$res = Trn::decode_resource($data, undef, $Opt::linear);
	if ($Opt::verbose) {
	    printf("Decode done\n");
	}
	dump_trn('', $res);
    }
}

exit 0;

######################################################################
# dump_rgba($prefix, \$trn);

sub dump_rgba {
    my($prefix, $trn) = @_;
    if (defined($$trn{a})) {
	dump_trn($prefix,
		 sprintf("rgba<%f, %f, %f, %f>",
			 $$trn{r}, $$trn{g}, $$trn{b}, $$trn{a}));
    } else {
	dump_trn($prefix,
		 sprintf("rgb<%f, %f, %f>", $$trn{r}, $$trn{g}, $$trn{b}));
    }
}

######################################################################
# dump_xyz($prefix, \$trn);

sub dump_xyz {
    my($prefix, $trn) = @_;
    if (defined($$trn{z})) {
	dump_trn($prefix,
		 sprintf("xyz[%f, %f, %f]", $$trn{x}, $$trn{y}, $$trn{z}));
    } else {
	dump_trn($prefix,
		 sprintf("xy[%f, %f]", $$trn{x}, $$trn{y}));
    }
}

######################################################################
# dump_uvw($prefix, \$trn);

sub dump_uvw {
    my($prefix, $trn) = @_;
    dump_trn($prefix,
	     sprintf("uvw[%f, %f, %f]", $$trn{u}, $$trn{v}, $$trn{w}));
}
######################################################################
# dump_iii($prefix, \$trn);

sub dump_iii {
    my($prefix, $trn) = @_;

    dump_trn($prefix, "iii(" . join(", ", @{$$trn{i}}) . ")");
}

######################################################################
# dump_trn($prefix, \%trn, $format);

sub dump_trn {
    my($prefix, $trn, $format) = @_;
    my($item, $i);
    
    if (UNIVERSAL::isa($trn, 'ARRAY')) {
	$i = 0;
	foreach $item (@{$trn}) {
	    dump_trn($prefix . "[" . $i . "]", $item, $format);
	    $i++;
	}
    } elsif (UNIVERSAL::isa($trn, 'HASH')) {
	if (defined($$trn{''})) {
	    $format = $$trn{''};
	}
	if (defined($format)) {
	    if ($format =~ /^-(.*)/) {
		$format = $1;
		if (!$Opt::print_all) {
		    $format = '';
		}
	    }
	    if ($format eq '') {
		# Skip printting.
	    } elsif ($format eq 'rgb' || $format eq 'rgba') {
		dump_rgba($prefix, $trn);
	    } elsif ($format eq 'xy' || $format eq 'xyz') {
		dump_xyz($prefix, $trn);
	    } elsif ($format eq 'uvw') {
		dump_uvw($prefix, $trn);
	    } elsif ($format eq 'ii' || $format eq 'iii') {
		dump_iii($prefix, $trn);
	    } elsif ($format eq 'pixmap#' ||
		     $format eq 'hash' || $format eq 'hash#' ||
		     $format eq 'unknown#' || $format eq 'unknown') {
		foreach $i (sort keys %{$trn}) {
		    next if ($i eq '');
		    $item = $$trn{$i};
		    dump_trn($prefix . "/" . $i, $item, $format);
		}
	    } else {
		die "Unknown rendered: $format";
	    }
	} else {
	    foreach $i (sort keys %{$trn}) {
		$item = $$trn{$i};
		dump_trn($prefix . "/" . $i, $item);
	    }
	}
    } else {
	if (defined($trn)) {
	    print($main::file);
	    if (!$Opt::no_labels) {
		printf("%s%s", $prefix, $Opt::separator);
	    }
	    if ($prefix =~ /%$/ || (defined($format) && $format =~ /%$/)) {
		printf("0x%x\n", $trn);
	    } elsif ($prefix =~ /\#$/ ||
		     (defined($format) && $format =~ /\#$/)) {
		printf("0x%s\n", unpack("H*", $trn));
	    } else {
		printf("%s\n", $trn);
	    }
	}
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

trnprint - Print Trn/Trx files / resources

=head1 SYNOPSIS

trnprint [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--print-filename>|B<-f>]
    [B<--print-basename>|B<-b>]
    [B<--no-labels>|B<-l>]
    [B<--separator>|B<-s> I<separator>]
    [B<--print-all>|B<-a>]
    [B<--linear>|B<-L>]
    I<filename> ...

trnprint B<--help>

=head1 DESCRIPTION

B<trnprint> prints trn/trx files or individual resources to human
readable or machine editable format. The output of the B<trnprint> can
be converted back to trn by using trnencode(1).

I<filename> is read in and selected fields are printed out from it.
The output is normally prefixed with the label (unless B<-l> is
given), and it can be prefixed with filename (if B<-f> is given), or
basefilename (if B<-b> is given).

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

=item B<--print-filename> B<-f>

Prefix the output with the full file name. 

=item B<--print-basename> B<-b>

Prefix the output with the base filename, i.e. the file name where the
path component is removed. 

=item B<--no-labels> B<-l>

Do not print the labels for each field, only print the value (and the
file name if requested)

=item B<--separator> B<-s> I<separator>

Use the given string as a separator between the label and value
instead of default I<:\t>.

=item B<--print-all> B<-a>

Print all fields (also those with low interest). 

=item B<--linear> B<-L>

Print data in linear format, i.e. do not try to parse it to XY arrays.

=back

=head1 EXAMPLES

    trnprint 0000.trwh
    trnprint -b 0001.trrn
    trnprint area1.trn

=head1 FILES

=over 6

=item ~/.trnprintrc

Default configuration file.

=back

=head1 SEE ALSO

trnencode(1), Trn(3), and TrnRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

Sample program used while reverse engineering some of the resource
fields.
