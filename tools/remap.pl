#!/usr/bin/env perl
# -*- perl -*-
######################################################################
# remap.pl -- Remap numbers inside the modules / haks
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: remap.pl
#	  $Source: /u/samba/nwn/bin/RCS/remap.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 14:57 Aug 15 2007 kivinen
#	  Last Modification : 14:13 Aug 17 2007 kivinen
#	  Last check in     : $Date: 2007/08/17 11:45:07 $
#	  Revision number   : $Revision: 1.3 $
#	  State             : $State: Exp $
#	  Version	    : 1.121
#	  Edit time	    : 69 min
#
#	  Description       : Remap numbers in modules / haks
#
#	  $Log: remap.pl,v $
#	  Revision 1.3  2007/08/17 11:45:07  kivinen
#	  	Added removeroofs type.
#
#	  Revision 1.2  2007/08/15 12:56:27  kivinen
#	  	Added --output option.
#
#	  Revision 1.1  2007/08/15 12:44:04  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package Remap;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use ErfRead;
use ErfWrite;
use Erf;
use Twoda;
use Pod::Usage;

$Opt::verbose = 0;
$Opt::type = 'placeables';
$Opt::output = undef;

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
    read_rc_file("$ENV{'HOME'}/.remaprc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"start|s=s" => \$Opt::start,
		"end|e=s" => \$Opt::end,
		"newstart|S=s" => \$Opt::newstart,
		"tiles|T=s" => \$Opt::tiles,
                "type|t=s" => \$Opt::type,
		"output|o=s" => \$Opt::output,
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

%Remap::operations =
    ( 'placeables' =>
      {
	  'check' => \&placeables_arg_check,
	  'do' => \&placeables_do,
      },
      'removeroofs' =>
      {
	  'check' => \&removeroofs_arg_check,
	  'do' => \&removeroofs_do,
      } );

$| = 1;

my($i, $j);

if ($#ARGV == -1) {
    push(@ARGV, "*");
}

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}


$Opt::type = lc($Opt::type);
$Opt::type =~ tr/ \t\n//d;

if (!defined($Remap::operations{$Opt::type})) {
    
    die "Invalid type: $Opt::type, currently only supported ones are: "
	. join(", ", keys %Remap::operations);
}

if (defined($Remap::operations{$Opt::type}{check})) {
    &{$Remap::operations{$Opt::type}{check}}();
}

process_files(@ARGV);

exit 0;

######################################################################
# Process files

sub process_files {
    my(@files) = @_;
    my($i);
    
    foreach $i (@files) {
	if (-d $i) {
	    process_files(bsd_glob($i . "/*"));
	} elsif ($i =~ /\.(mod|hak|erf)$/i) {
	    my($erf, $j, $data, $modified);

	    $erf = ErfRead::read('filename' => $i);
	    $modified = 0;
	    for($j = 0; $j < $erf->resource_count; $j++) {
		$data = process_file($erf->resource_reference($j) . "." .
				     $erf->resource_extension($j),
				     $erf->resource_data($j));
		if (defined($data)) {
		    if ($Opt::verbose > 2) {
			printf("Storing file %s...\n",
			       $erf->resource_reference($j) . "." .
			       $erf->resource_extension($j));
		    }
		    $erf->resource_data($j, $data);
		    $modified = 1;
		}
	    }
	    if ($modified) {
		if (defined($Opt::output)) {
		    if ($Opt::verbose) {
			print("Writing file $Opt::output...\n");
		    }
		    &ErfWrite::write($erf, filename => $Opt::output);
		} else {
		    if ($Opt::verbose) {
			print("Writing file $i.new...\n");
		    }
		    &ErfWrite::write($erf, filename => $i . ".new");
		}
		if ($Opt::verbose > 1) {
		    print("Write done\n");
		}
	    }
	    undef $erf;
	} else {
	    process_file($i);
	}
    }
}

######################################################################
# Process file 

sub process_file {
    my($i, $data) = @_;
    my($type, $name);
    
    $type = lc($i);
    $type =~ s/^.*\.//g;
    $name = lc($i);
    $name =~ s/^.*[\/\\]//g;
    $name =~ s/\..*$//g;

    if (defined($Remap::operations{$Opt::type}{'do'})) {
	return &{$Remap::operations{$Opt::type}{'do'}}($i, $data,
						       $type, $name);
    }
    return undef;
}

######################################################################
# Placeables argument check

sub placeables_arg_check {
    if (!defined($Opt::start)) {
	die "Mandatory option --start missing";
    }
    if (!defined($Opt::newstart)) {
	die "Mandatory option --newstart missing";
    }
}

######################################################################
# Placeables main function

sub placeables_do {
    my($i, $data, $type, $name) = @_;
    
    if ($type eq 'git' || $type eq 'utp') {
	my($gff);
	$Remap::resource_name = $i;
	$Remap::modified = 0;
	if ($Opt::verbose > 1) {
	    print("Reading file $i...\n");
	}
	if (defined($data)) {
	    $gff = GffRead::read('data' => $data,
				 'check_recursion' => 1,
				 'return_errors' => 1);
	} else {
	    $gff = GffRead::read('filename' => $i,
				 'check_recursion' => 1,
				 'return_errors' => 1);
	}
	if (!defined($gff)) {
	    print("Error parsing file $i, might be corrupted\n");
	} else {
	    if ($Opt::verbose > 2) {
		print("Read done\n");
	    }
	    if ($type eq 'utp') {
		update_appearance_field($gff, '/', '/', $gff, undef);
	    } elsif ($type eq 'git') {
		$gff->find(find_label =>
			   '^/(Placeable |Environment)List\[\d+\]/$', # '
			   proc => \&update_appearance_field);
	    }
	    if ($Remap::modified) {
		if ($Opt::verbose > 1) {
		    print("Made $Remap::modified changes in $i...\n");
		}
		if (defined($data)) {
		    return &GffWrite::write($gff);
		} else {
		    if (defined($Opt::output)) {
			$i = $Opt::output;
		    }
		    if ($Opt::verbose > 1) {
			print("Writing file $i...\n");
		    }
		    &GffWrite::write($gff, filename => $i);
		    if ($Opt::verbose > 2) {
			print("Write done\n");
		    }
		}
	    }
	}
	undef $gff;
    }
    return undef;
}

######################################################################
# Update appearance field

sub update_appearance_field {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    $value = $$value{Appearance};

    if ($value >= $Opt::start &&
        (!defined($Opt::end) || $value <= $Opt::end)) {
	my($new);
	$new = $value - $Opt::start + $Opt::newstart;
	if ($Opt::verbose > 3) {
	    printf("Updating %s %d -> %d...\n", $full_label,
		   $value, $new);
	}
        $$gff{Appearance} = $new;
        $Remap::modified++;
    }
}

######################################################################
# Remove roofs argument check

sub removeroofs_arg_check {
    if (!defined($Opt::tiles)) {
	die "Mandatory option --tiles missing";
    }
    $Remap::tiles = Twoda::read($Opt::tiles);
}

######################################################################
# Remove roofs main function

sub removeroofs_do {
    my($i, $data, $type, $name) = @_;
    
    if ($type eq 'are') {
	my($gff);
	$Remap::resource_name = $i;
	$Remap::modified = 0;
	if ($Opt::verbose > 1) {
	    print("Reading file $i...\n");
	}
	if (defined($data)) {
	    $gff = GffRead::read('data' => $data,
				 'check_recursion' => 1,
				 'return_errors' => 1);
	} else {
	    $gff = GffRead::read('filename' => $i,
				 'check_recursion' => 1,
				 'return_errors' => 1);
	}
	if (!defined($gff)) {
	    print("Error parsing file $i, might be corrupted\n");
	} else {
	    if ($Opt::verbose > 2) {
		print("Read done\n");
	    }
	    $gff->find(find_label =>
		       '^/TileList\[\d+\]/$', # '
		       proc => \&update_variation_field);
	    if ($Remap::modified) {
		if ($Opt::verbose > 1) {
		    print("Made $Remap::modified changes in $i...\n");
		}
		if (defined($data)) {
		    return &GffWrite::write($gff);
		} else {
		    if (defined($Opt::output)) {
			$i = $Opt::output;
		    }
		    if ($Opt::verbose > 1) {
			print("Writing file $i...\n");
		    }
		    &GffWrite::write($gff, filename => $i);
		    if ($Opt::verbose > 2) {
			print("Write done\n");
		    }
		}
	    }
	}
	undef $gff;
    }
    return undef;
}

######################################################################
# update variation field

sub update_variation_field {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($appearance, $variation, $max, $new);
    $appearance = $$value{Appearance};
    $variation = $$value{Variation};

    $max = $$Remap::tiles{Data}[$appearance]{VARIATIONS} / 2;
    if ($max > $variation) {
	$new = $variation + $max;
	if ($Opt::verbose > 3) {
	    printf("Updating %s/Variation %d -> %d...\n", $full_label,
		   $variation, $new);
	}
        $$gff{Variation} = $new;
        $Remap::modified++;
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

remap - Remap numbers inside the modules / haks

=head1 SYNOPSIS

remap [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--start>|B<-s> I<start-number>]
    [B<--end>|B<-e> I<end-number>]
    [B<--newstart>|B<-S> I<new-start-number>]
    [B<--tiles>|B<-T> I<path-to-roofless-tiles-2da-file>]
    [B<--type>|B<-t> I<type-of-modification>]
    [B<--output>|B<-o> I<output-filename>]
    [I<filename> ...]

remap B<--help>

=head1 DESCRIPTION

B<remap> will find specific types of things inside the modules, haks,
or erfs, and renumbed them so that all numbers between I<start-number>
and I<end-number> (inclusive) are mapped so that I<start-number> is
mapped to I<new--start-number>. The I<end-number> is not mandatory,
and if it is not given, then map all numbers starting from I<start-number>.

If no arguments is given, then '*' is assumed.

If given files are direct resource files from directory mode, then
modified files are written back to the same place (i.e. this tool
overwrites old files). If hak, mod or erf is given then this tool will
write new hak, mod or erf with .new extension back unless --output
option is given.

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

=item B<--type>|B<-t> I<type>

Currently only supported types are 'placeables' and 'removeroofs'

=item B<--output>|B<-o> I<output-filename>

Output filename if hak, erf or mod is given. This is ignored if we
work in directory mode, and if multiple input files are given they are
all written to this same file (i.e. only last file will be stored
there).

=back

=head1 PLACEABLES remap type

This mapping fixes placeables. This will update the 'Placeable List',
and 'EnvironmentList' fields in the *.git files and Appearance field
in the *.utp files. This requires --start and --newstart options.

=over 4

=item B<--start>|B<-s> I<start-number>

Starting number from where to start mapping numbers. This is the first
number which is mapped, and it is mapped to I<new-start-number>.

=item B<--end>|B<-e> I<end-number>

End number from where to end mapping numbers. This is the last number
which is mapped. If this is not given then assume that all numbers
starting from I<start-number> are mapped.

=item B<--newstart>|B<-S> I<new-start-number>

New starting number to where to map numbers. The old I<start-number>
is mapped to this value.

=back

=head1 REMOVEROOFS remap type

This mapping removes roofs from tiles, by chaing their variation. This
requires --tiles option that will point to the tiles.2da file of the
roofless hak. This will update the 'Variation' in the .are file.

=over 4

=item B<--tiles>|B<-T> I<path-to-roofless-tiles-2da-file>

Path to the tiles.2da file of the roofless hak. 

=back

=head1 EXAMPLES

    remap --start 2001 --newstart 3001 mymod.mod myhak.hak myhak.erf
    remap --start 5000 --end 5999 --newstart 7000
    	  -o itemplaceablesnew.erf itemplaceables.erf
    remap --type removeroofs --tiles tiles.2da myarea.are

=head1 FILES

=over 6

=item ~/.remaprc

Default configuration file.

=back

=head1 SEE ALSO

gffmodify(1), gffprint(1), Erf(3), ErfWrite(3), ErfRead(3),
Gff(3), GffWrite(3) and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was written to help to remap external haks so they do not
overlap with the haks already in the module. 
