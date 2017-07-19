#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# builder-package.pl -- Create builders basic package
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: builder-package.pl
#	  $Source: /u/samba/nwn/bin/RCS/builder-package.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 13:02 Dec  6 2004 kivinen
#	  Last Modification : 01:22 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:22:11 $
#	  Revision number   : $Revision: 1.6 $
#	  State             : $State: Exp $
#	  Version	    : 1.283
#	  Edit time	    : 88 min
#
#	  Description       : Create builders basic package
#
#	  $Log: builder-package.pl,v $
#	  Revision 1.6  2007/05/23 22:22:11  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.5  2007/05/23 22:21:39  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.4  2005/05/01 08:49:03  kivinen
#	  	Added -a option.
#
#	  Revision 1.3  2005/02/05 14:33:09  kivinen
#	  	Added adding of the ncs automatically if .nss is added.
#	  	Cleaned up a comments from nss files a bit.
#
#	  Revision 1.2  2004/12/06 13:28:53  kivinen
#	  	Fixed directory support.
#
#	  Revision 1.1  2004/12/06 13:24:41  kivinen
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
package BuilderPackage;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use ErfRead;
use ErfWrite;
use Erf;
use GffRead;
use GffWrite;
use Gff;
use Time::HiRes qw(time);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

$Opt::verbose = 0;
$Opt::dir = ".";
$Opt::resource_list_file = "resource-list.txt";
$Opt::short_description_file = undef;
$Opt::readme_file = undef;
$Opt::comment_file = undef;
$Opt::module_file = undef;
$Opt::package_erf = undef;
$Opt::package_zip = "package.zip";
$Opt::file_listing_output_file = "filelisting.txt";
$Opt::file_descriptions_output_file = "filedescriptions.txt";
@Opt::added_files = ();

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

$Prog::version = "$Prog::revision." .
    "$Prog::save_version.$Prog::edit_time";
$Prog::progname = $0;
$Prog::progname =~ s/^.*[\/\\]//g;

$| = 1;

######################################################################
# Read rc-file

if (defined($ENV{'HOME'})) {
    read_rc_file("$ENV{'HOME'}/.builder-package");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"dir|d=s" => \$Opt::dir,
		"module|m=s" => \$Opt::module_file,
		"resources|r=s" => \$Opt::resource_list_file,
		"short-descriptions|s=s" => \$Opt::short_description_file,
		"readme|R=s" => \$Opt::readme_file,
		"comment|c=s" => \$Opt::comment_file,
		"erf|e=s" => \$Opt::package_erf,
		"zip|z=s" => \$Opt::package_zip,
		"listing-name|l=s" => \$Opt::file_listing_output_file,
		"descriptions-name|D=s" =>
		\$Opt::file_descriptions_output_file,
		"add|a=s" => sub {
		    my($name, $value) = @_;
		    push(@Opt::added_files, $value);
		},
		"version|V" => \$Opt::version) || defined($Opt::help)) {
    usage();
}

if (defined($Opt::version)) {
    print("\u$Prog::progname version " .
	  "$Prog::version by Tero Kivinen.\n");
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

my($input_erf, $output_erf, %resources, %descriptions);
my(%short_descriptions, %long_descriptions, $erf_data);

if (defined($Opt::module_file)) {
    my($file, $i);

    $input_erf = ErfRead::read(filename => $Opt::module_file);
    if (!defined($input_erf)) {
	die "Cannot open module $Opt::module_file : $!";
    }
    for($i = 0; $i < $input_erf->resource_count; $i++) {
	$file = $input_erf->resource_reference($i) . "." .
	    $input_erf->resource_extension($i);
	print("Found $file from module\n") if ($Opt::verbose > 4);
	$resources{$file} = $i;
    }
}

$output_erf = new Erf;

$output_erf->file_type("ERF ");

if (defined($Opt::short_description_file)) {
    open(FILE, "<$Opt::short_description_file") ||
	die "Cannot open $Opt::short_description_file : $!";
    while (<FILE>) {
	chomp;
	if (/^([a-zA-Z0-9_]+\.[a-zA-Z0-9_]{3})(.*)/) {
	    $descriptions{$1} = $_;
	    print("Found description for file $_\n") if ($Opt::verbose > 3);
	} else {
	    warn "Invalid line in short descriptions : $_";
	}
    }
    close(FILE);
}

print("Reading resources from $Opt::resource_list_file\n") if ($Opt::verbose);
open(FILE, "<$Opt::resource_list_file") ||
    die "Cannot open $Opt::resource_list_file : $!";
while (<FILE>) {
    my($i, $long_description);
    chomp;
    next if (/^\s*\#/);
    next if (/^\s*$/);
    print("Processing resource $_\n") if ($Opt::verbose > 1);
    if (defined($input_erf)) {
	
	if (!defined($resources{$_})) {
	    die "Resource $_ not found from module";
	}
	$i = $output_erf->new_file($_, $input_erf->
				   resource_data($resources{$_}));
	if ($_ =~ /(.*)\.nss/) {
	    if (defined($resources{$1 . ".ncs"})) {
		$output_erf->new_file($1 . ".ncs", $input_erf->
				      resource_data($resources{$1 . "\.ncs"}));
	    }
	}
    } else {
	$i = $output_erf->new_file($Opt::dir . $_);
	if ($_ =~ /(.*)\.nss/) {
	    if (-f $1 . ".ncs") {
		$output_erf->new_file($Opt::dir . $1 . ".ncs");
	    }
	}
    }
    if (defined($descriptions{$_})) {
	$short_descriptions{$_} = $descriptions{$_};
    } else {
	$short_descriptions{$_} = $_;
    }
    if ($output_erf->resource_extension($i) =~
	/^(are|ifo|bic|git|ut.|dlg|itp|gff|fac|gic|gui|jrl|ptm|ptt)$/) {
	my($gff, $data);
	
	$data = $output_erf->resource_data($i);
	$gff = GffRead::read(include => '/Comments?',
			     'include-field' => 'Comments?',
			     data => $data);
	$long_description = $$gff{Comment};
	if (!defined($long_description)) {
	    $long_description = $$gff{Comments};
	}
    } elsif ($output_erf->resource_extension($i) eq "nss") {
	$long_description = parse_script($output_erf->resource_data($i));
    }
    if (defined($long_description) &&
	$long_description ne "") {
	print("Found long description for $_\n") if ($Opt::verbose > 2);
	$long_descriptions{$_} = $long_description;
    } else {
	$long_descriptions{$_} = "";
    }
}
close(FILE);

if (defined($Opt::comment_file)) {
    my($gff, $data, $i);

    print("Reading comment from $Opt::comment_file\n") if ($Opt::verbose);
    $gff = Gff->new();
    $gff->file_type("GFF ");
    $gff->file_version("V3.2");
    undef $/;
    open(FILE, "<$Opt::comment_file") ||
	die "Cannot open comments file $Opt::comment_file : $!";
    $_ = <FILE>;
    close(FILE);
    $gff->value("/Comments", $_, 10);
    $gff->value("/ ____struct_type", 4294967295);
    $gff->value("", '');
    $data = &GffWrite::write($gff);
    $i = $output_erf->new_file("ExportInfo.gff", $data);
}

print("Generating erf file\n") if ($Opt::verbose);
$erf_data = &ErfWrite::write($output_erf);
if (defined($Opt::package_erf) &&
    $Opt::package_erf ne "") {
    if ($Opt::package_erf !~ /\.erf$/i) {
	$Opt::package_erf .= ".erf";
    }
    print("Writing erf file $Opt::package_erf\n") if ($Opt::verbose);
    open(FILE, ">$Opt::package_erf")
	|| die "Cannot write $Opt::package_erf : $!";
    binmode(FILE);
    print(FILE $erf_data);
    close(FILE);
}

if (defined($Opt::package_zip) &&
    $Opt::package_zip ne "") {
    my($zip, $member, $file);

    if ($Opt::package_zip !~ /\.zip$/i) {
	$Opt::package_zip .= ".zip";
    }
    print("Generating zip file $Opt::package_zip\n") if ($Opt::verbose);

    if (!defined($Opt::package_erf) ||
	$Opt::package_erf eq '') {
	$Opt::package_erf = "package.erf";
    }
    $Opt::package_erf =~ s/.*[\/\\]//g;

    $zip = Archive::Zip->new();
    print("Adding erf\n") if ($Opt::verbose);
    $member = $zip->addString($erf_data, $Opt::package_erf);
    $member->desiredCompressionMethod( COMPRESSION_DEFLATED );
    $member->unixFileAttributes(0644);
    if (defined($Opt::readme_file) &&
	$Opt::readme_file ne "") {
	my($temp);

	$temp = $Opt::readme_file;
	$temp =~ s/.*[\/\\]//g;
	print("Adding readme from $Opt::readme_file\n") if ($Opt::verbose);
	$member = $zip->addFile($Opt::readme_file, $temp);
	$member->desiredCompressionMethod( COMPRESSION_DEFLATED );
    }

    if (defined($Opt::file_listing_output_file) &&
	$Opt::file_listing_output_file ne "") {
	my($data);

	$data = join("\n",
		     map { $short_descriptions{$_}; }
		     sort
		     keys %short_descriptions);
	print("Adding short description file $Opt::file_listing_output_file\n")
	    if ($Opt::verbose);
	$member = $zip->addString($data, $Opt::file_listing_output_file);
	$member->desiredCompressionMethod( COMPRESSION_DEFLATED );
	$member->unixFileAttributes(0644);
    }

    if (defined($Opt::file_descriptions_output_file) &&
	$Opt::file_descriptions_output_file ne "") {
	my($data);

	$data = join("\n",
		     map { ("-" x 70) . "\nFile: $_\n" . 
			       $long_descriptions{$_}; }
		     sort
		     keys %long_descriptions);
	print("Adding short description file " .
	      "$Opt::file_descriptions_output_file\n")
	    if ($Opt::verbose);
	$member = $zip->addString($data, $Opt::file_descriptions_output_file);
	$member->desiredCompressionMethod( COMPRESSION_DEFLATED );
	$member->unixFileAttributes(0644);
    }
    foreach $file (@Opt::added_files) {
	my($temp);

	$temp = $file;
	$temp =~ s/.*[\/\\]//g;
	print("Adding file $file\n") if ($Opt::verbose);
	$member = $zip->addFile($file, $temp);
	$member->desiredCompressionMethod( COMPRESSION_DEFLATED );
    }
    print("Writing zip file $Opt::package_zip\n") if ($Opt::verbose);
    if ($zip->writeToFileNamed($Opt::package_zip) != AZ_OK) {
	die "Write error while writing zip file : $!";
    }
}
print("All done\n") if ($Opt::verbose);

exit 0;

######################################################################
# $description = parse_script($file)

sub parse_script {
    my($file) = @_;

    if ($file =~ /^([^\{]*)\{/s) {
	my($txt);
	$txt = $1;
	$txt =~ s/[^\n]*\#include[^\n]*\n//gs;
	$txt =~ s/\s*void\s+main\s*\(\s*\)\s*//gs;
	$txt =~ s/\s*int\s+StartingConditional\s*\(\s*\)\s*//gs;
	return $txt;
    } else {
	return "";
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
    print("Usage: $Prog::progname [--help] [--version] ".
	  "\n\t[--verbose|-v] " .
	  "\n\t[--config config-file] " .
	  "\n\t[--dir|-d extracted-module-dir] " .
	  "\n\t[--module|-m module-to-extract-resources-from] " .
	  "\n\t[--resources|-r file-containing-resource-filenames] " .
	  "\n\t[--short-description|-s file-containing-short-descriptions] " .
	  "\n\t[--readme|-R file-containing-readme] " .
	  "\n\t[--comment|-c file-containing-package-comment] " .
	  "\n\t[--erf|-e output-erf-file] " .
	  "\n\t[--zip|-z output-zip-file] " .
	  "\n\t[--listing-name|-l filename-in-zip-for-short-descriptions] " .
	  "\n\t[--descriptions-name|-D filename-in-zip-for-descriptions] " .
	  "\n\t[--add|-a file-to-add-to-zipfile] " .
	  "\n");
    exit(0);
}

