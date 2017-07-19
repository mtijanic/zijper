#!/usr/bin/env perl
# -*- perl -*-
######################################################################
# check-module.pl -- Check that module directory has valid contents.
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: check-module.pl
#	  $Source: /u/samba/nwn/bin/RCS/check-module.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 23:21 tammi 23 2007 kivinen
#	  Last Modification : 02:29 Jul  2 2007 kivinen
#	  Last check in     : $Date: 2007/07/02 00:38:20 $
#	  Revision number   : $Revision: 1.14 $
#	  State             : $State: Exp $
#	  Version	    : 1.207
#	  Edit time	    : 81 min
#
#	  Description       : Check that module directory has valid
#			      contents, this will verify all gff files,
#		      	      and check that module.ifo has valid contents.
#
#	  $Log: check-module.pl,v $
#	  Revision 1.14  2007/07/02 00:38:20  kivinen
#	  	Added check for complex triggers. Added code to skip bbx, xml,
#	  	tga, res, and wav files.
#
#	  Revision 1.13  2007/05/23 23:51:07  kivinen
#	  	Added support for module mode.
#
#	  Revision 1.12  2007/05/23 22:22:28  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.11  2007/05/23 22:02:43  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.10  2007/05/23 20:43:21  kivinen
#	  	Added checks for broken dialogs.
#
#	  Revision 1.9  2007/05/17 21:59:44  kivinen
#	  	Added nwm to skipped files.
#
#	  Revision 1.8  2007/04/25 01:00:03  kivinen
#	  	Added skipping of ndb files.
#
#	  Revision 1.7  2007/03/31 00:50:45  kivinen
#	  	Added --dofix option.
#
#	  Revision 1.6  2007/03/29 23:24:26  kivinen
#	  	Find module.ifo and repute.fac even if they are not all
#	  	lowercase.
#
#	  Revision 1.5  2007/03/29 23:03:06  kivinen
#	  	Added checking of variable types.
#
#	  Revision 1.4  2007/01/23 22:38:36  kivinen
#	  	Changed the default argument to be '*'.
#
#	  Revision 1.3  2007/01/23 22:34:40  kivinen
#	  	Added reference to the update-ifo.
#
#	  Revision 1.2  2007/01/23 22:27:37  kivinen
#	  	Added documentation.
#
#	  Revision 1.1  2007/01/23 22:22:51  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
######################################################################
# initialization

require 5.6.0;
package CheckModule;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use ErfRead;
use ErfWrite;
use Erf;
use Pod::Usage;

$Opt::verbose = 0;
@CheckModule::TypeStr = ( 'None', 'Int', 'Float', 'String', 'Object',
			  'Location' );
$Opt::dofix = 0;

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
    read_rc_file("$ENV{'HOME'}/.checkmodulerc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"dofix" => \$Opt::dofix,
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

%CheckModule::area_resources =
    ( trx => 1,
      trn => 2,
      are => 4,
      git => 8,
      gic => 16
      );

map {
    $CheckModule::resource_numbers{$CheckModule::area_resources{$_}} = $_;
} keys(%CheckModule::area_resources);

process_files(@ARGV);

if (!defined($CheckModule::module_ifo)) {
    print("No module.ifo in the module\n");
}

if (!defined($CheckModule::repute_fac)) {
    print("No repute.fac in the module\n");
}

foreach $i (keys %CheckModule::areas) {
    if ($CheckModule::areas{$i} != 31) {
        my(@list);
        for($j = 1; $j < 32; $j *= 2) {
            if (($CheckModule::areas{$i} & $j) == 0) {
                push(@list, $CheckModule::resource_numbers{$j});
            }
        }
        print("Area $i is missing some files: ", join(", ", @list), "\n");
    }
    if (!defined($CheckModule::area{$i})) {
        print("Area $i is not listed in the module.ifo\n");
    } else {
        $CheckModule::area{$i}++;
    }
}

foreach $i (keys %CheckModule::area) {
    if ($CheckModule::area{$i} != 2) {
        print("Area $i is listed in the module.ifo, " .
              "but no area files found\n");
    }
}

exit 0;

######################################################################
# Process files

sub process_files {
    my(@files) = @_;
    my($i);
    
    foreach $i (@files) {
	if (-d $i) {
	    process_files(bsd_glob($i . "/*"));
	} elsif ($i =~ /\.mod$/i) {
	    my($erf, $j, $data, $modified);

	    $erf = ErfRead::read('filename' => $i);
	    $modified = 0;
	    for($j = 0; $j < $erf->resource_count; $j++) {
		$data = process_file($erf->resource_reference($j) . "." .
				     $erf->resource_extension($j),
				     $erf->resource_data($j));
		if (defined($data)) {
		    $erf->resource_data($j, $data);
		    $modified = 1;
		}
	    }
	    if ($modified) {
		&ErfWrite::write($erf, filename => $i);
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
    my($gff, $type, $name);
    
    $type = lc($i);
    $type =~ s/^.*\.//g;
    $name = lc($i);
    $name =~ s/^.*[\/\\]//g;
    $name =~ s/\..*$//g;
    
    if (defined($CheckModule::area_resources{$type})) {
        $CheckModule::areas{$name} = 0
	    if (!defined($CheckModule::areas{$name}));
        $CheckModule::areas{$name} |= $CheckModule::area_resources{$type};
    }

    next if ($type eq 'trx' || $type eq 'trn' ||
             $type eq 'ncs' || $type eq 'nss' || $type eq 'ndb' ||
             $type eq '2da' || $type eq 'tlk' ||
             $type eq 'sef' || $type eq 'pfx' ||
             $type eq 'lfx' || $type eq 'bfx' || $type eq 'bbx' ||
             $type eq 'ifx' || $type eq 'nwm' ||
	     $type eq 'xml' || $type eq 'tga' ||
	     $type eq 'res' || $type eq 'wav');

    $CheckModule::resource_name = $i;
    $CheckModule::modified = 0;
    if ($Opt::verbose) {
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
        printf("Error parsing file $i, might be corrupted\n");
    } else {
	if ($Opt::verbose) {
	    printf("Read done\n");
	}
	if ($i =~ /module\.ifo$/i) {
	    $gff->find(find_label => '/Mod_Area_list\[\d+\]/$', # '
		       proc => \&area_names);
	    $CheckModule::module_ifo = 1;
	}
	if ($i =~ /\.dlg$/i) {
	    $gff->find(find_label => '/Index$', # '
		       find_value => 4294967295,
		       proc => \&check_dialog);
	}
	if ($i =~ /\.git$/i) {
	    $gff->find(find_label => '/Geometry\[100\]/$', # '
		       proc => \&invalid_trigger);
	}
	$gff->find(find_label => '/VarTable\[\d+\]/$', # '
		   proc => \&check_variables);
	if ($i =~ /repute\.fac$/i) {
	    $CheckModule::repute_fac = 1;
	}
	if ($Opt::dofix && $CheckModule::modified) {
	    if (defined($data)) {
		return &GffWrite::write($gff);
	    } else {
		&GffWrite::write($gff, filename => $i);
	    }
	}
    }
    undef $gff;
    return undef;
}

######################################################################
# Check area names.

sub area_names {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($name);
    $name = lc($$gff{Area_Name});
    if (!defined($name)) {
        print("Module.ifo has /Mod_Area_list/ entry without Area_Name: " .
              $full_label);
    }
    if ($Opt::verbose > 2) {
        print("Found area $name from module.ifo\n");
    }
    if (defined($CheckModule::area{$name})) {
        print("Found area $name twice from module.ifo\n");
    }
    $CheckModule::area{$name} = 1;
}

######################################################################
# Check dialogs and warn about corrupted dialogs.

sub check_dialog {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($type, $typestr);
    
    printf("Conversation %s has invalid index entry in %s. This will cause " .
	   "nwn2server crash if player selects this entry\n", 
	   $CheckModule::resource_name, $full_label);
}

######################################################################
# Check triggers and warn about triggers having too many points.

sub invalid_trigger {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($type, $typestr);
    
    printf("Area %s has too complicated trigger with more than 100 points %s. "
	   . "This will cause dmclient to crash when dm comes to the area.\n",
	   $CheckModule::resource_name, $full_label);
}

######################################################################
# Check variable types.

sub check_variables {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($type, $typestr);
    
    if (!defined($$gff{Name})) {
        print("No Name in variable $full_label in " .
	      "$CheckModule::resource_name\n");
    } else {
	if ($$gff{'Name. ____type'} != 10) {
	    print("Wrong Name. ____type in variable $full_label: " .
		  $$gff{'Name. ____type'} .
		  " in $CheckModule::resource_name\n");
	}
    }
    if (!defined($$gff{Type})) {
        print("No Type in variable $full_label in " .
	      "$CheckModule::resource_name\n");
    } else {
	if ($$gff{'Type. ____type'} != 4) {
	    print("Wrong Type. ____type in variable $full_label: " .
		  $$gff{'Type. ____type'} .
		  " in $CheckModule::resource_name\n");
	} else {
	    $type = $$gff{Type};
	    $typestr = $CheckModule::TypeStr[$type];
	    $type = $Gff::typeID2GffType{$type};
	}
    }
    if (!defined($$gff{Value})) {
        print("No Value in variable $full_label in " .
	      "$CheckModule::resource_name\n");
    } else {
	if ($$gff{'Value. ____type'} != $type) {
	    print("Wrong Value. ____type in variable $full_label: " .
		  $$gff{'Value. ____type'} . " should be " . $type
		  . " for variable of type $typestr in "
		  . "$CheckModule::resource_name\n");
	    if ($Opt::dofix) {
		$CheckModule::modified = 1;
		$$gff{'Value. ____type'} = $type;
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

check-module - Checks module directory to see if it is ok. 

=head1 SYNOPSIS

check-module [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--dofix>]
    [I<filename> ...]

check-module B<--help>

=head1 DESCRIPTION

B<check-module> checks each files given to it, and if they are
directories, then files inside those directories, and checks if it is
valid module file. It will parse each gff file, and also verifies that
the area name lists in the module.ifo and files on the directory
match, and that each area has all required area files. If this program
prints error from the module.ifo, then you can use the B<update-ifo>
program to fix those errors.

If no arguments is given, then '*' is assumed.

If B<--dofix> option is given then it will try to fix the invalid
variable type errors. It WILL overwrite the files with errors, so make
backup before using this option. 

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

=item B<--difix>

Try to fix the variable type errors in the module. 

=back

=head1 EXAMPLES

    check-module temp0/*.*
    check-module -v temp0
    check-module

=head1 FILES

=over 6

=item ~/.checkmodulerc

Default configuration file.

=back

=head1 SEE ALSO

update-ifo(1), gffprint(1), Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This is using the B<gffprint> program as a template, but skip the
printing of the data, and instead only parses the gff files. Area file
list checking was copied fromt he fixupmodule.pl used in the cerea2
build process.
