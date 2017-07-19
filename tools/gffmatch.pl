#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# gffmatch.pl -- Simple program to match BioWare Gff files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: gffmatch.pl
#	  $Source: /u/samba/nwn/bin/RCS/gffmatch.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 16:00 Jul 22 2004 kivinen
#	  Last Modification : 01:26 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:26:44 $
#	  Revision number   : $Revision: 1.14 $
#	  State             : $State: Exp $
#	  Version	    : 1.942
#	  Edit time	    : 521 min
#
#	  Description       : Simple program to match BioWare Gff files
#
#	  $Log: gffmatch.pl,v $
#	  Revision 1.14  2007/05/23 22:26:44  kivinen
#	  	No changes.
#
#	  Revision 1.13  2007/05/23 22:03:19  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.12  2007/02/03 17:16:36  kivinen
#	  	Added --dialog support.
#
#	  Revision 1.11  2005/07/06 11:11:14  kivinen
#	  	Added support for parameters etc. Added support for
#	  	nonmatching tests etc.
#
#	  Revision 1.10  2005/02/05 18:10:05  kivinen
#	  	Fixed =from to =item.
#
#	  Revision 1.9  2005/02/05 17:50:33  kivinen
#	  	Added documentation.
#
#	  Revision 1.8  2004/12/05 16:49:10  kivinen
#	  	Added csv output format.
#
#	  Revision 1.7  2004/11/21 14:28:40  kivinen
#	  	Changed usage (-b prints now the basename), removed unsed
#	  	code, added -s default to '^/$', added some debug prints on
#	  	verbose level 4, 5, 6.
#
#	  Revision 1.6  2004/09/20 11:46:31  kivinen
#	  	Added internal globbing. Fixed localized string printing.
#	  	Changed to use UNIVERSAL::isa.
#
#	  Revision 1.5  2004/08/25 15:30:43  kivinen
#	  	Fixed GffParse to Gff.
#
#	  Revision 1.4  2004/08/25 15:20:29  kivinen
#	  	No changes.
#
#	  Revision 1.3  2004/08/15 12:37:28  kivinen
#	  	Updated to new Gff module support.
#
#	  Revision 1.2  2004/07/26 15:12:49  kivinen
#	  	Fixed usage.
#
#	  Revision 1.1  2004/07/22 14:50:47  kivinen
#	  	Created.
#	  $EndLog$
#
#
#
#
######################################################################
# initialization

require 5.6.0;
package GffMatch;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use TlkRead;
use Gff;
use GffRead;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::exclude = undef;
$Opt::include = undef;
$Opt::find_struct = undef;
@Opt::find_labels = ();
@Opt::find_values = ();
@Opt::find_operations = ();
@Opt::or_labels = ();
@Opt::or_values = ();
@Opt::or_operations = ();
$Opt::print_fields = undef;
$Opt::print_fields_recursive = 0;
$Opt::find_proc = undef;
$Opt::print_filename = 0;
$Opt::print_basename = 0;
@Opt::parameters = ();
@Opt::parameter_names = ();
@Opt::global_parameters = ();
@Opt::global_parameter_names = ();
@Opt::area_parameters = ();
@Opt::area_parameter_names = ();
@Opt::variable_parameters = ();
@Opt::variable_parameter_names = ();
$Opt::dialog = undef;

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
    read_rc_file("$ENV{'HOME'}/.gffmatchrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"exclude|i=s" => \$Opt::exclude,
		"include|e=s" => \$Opt::include,
		"find|f=s" => sub {
		    my($name, $value) = @_;
		    if ($value !~ /^(.*):=:(.*)$/) {
			if ($value !~ /^(.*):!:(.*)$/) {
			    die "--find needs label-regexp:=:value-regexp or label-regexp:!:value-regexp";
			} else {
			push(@Opt::find_labels, $1);
			push(@Opt::find_values, $2);
			push(@Opt::find_operations, 1);
			}
		    } else {
			push(@Opt::find_labels, $1);
			push(@Opt::find_values, $2);
			push(@Opt::find_operations, 0);
		    }
		},
		"or|o" => sub {
		    if ($#Opt::find_labels == -1) {
			die "There must be at least one --find option " .
			    "before --or";
		    }
		    push(@Opt::or_labels, [ @Opt::find_labels ]);
		    push(@Opt::or_values, [ @Opt::find_values ]);
		    push(@Opt::or_operations, [ @Opt::find_operations ]);
		    @Opt::find_labels = ();
		    @Opt::find_values = ();
		    @Opt::find_operations = ();
		},
		"global-parameter|g=s" => sub {
		    my($name, $value) = @_;
		    if ($value =~ /^([^=]*)=(.*)$/) {
			push(@Opt::global_parameter_names, $1);
			push(@Opt::global_parameters, $2);
		    } else {
			die "--global-parameter needs name=absolute-path";
		    }

		},
		"parameter|P=s" => sub {
		    my($name, $value) = @_;
		    if ($value =~ /^([^=]*)=(.*)$/) {
			push(@Opt::parameter_names, $1);
			push(@Opt::parameters, $2);
		    } else {
			die "--parameter needs name=relative-path";
		    }

		},
		"area-parameter|a=s" => sub {
		    my($name, $value) = @_;
		    if ($value =~ /^([^=]*)=(.*)$/) {
			push(@Opt::area_parameter_names, $1);
			push(@Opt::area_parameters, $2);
		    } else {
			die "--area-parameter needs name=absolute-path";
		    }

		},
		"variable-parameter=s" => sub {
		    my($name, $value) = @_;
		    if ($value =~ /^([^=]*)=(.*)$/) {
			push(@Opt::variable_parameter_names, $1);
			push(@Opt::variable_parameters, $2);
		    } else {
			die "--variable-parameter needs name=varname";
		    }

		},
		"print-fields|p=s" => \$Opt::print_fields,
		"print-fields-recursive" => \$Opt::print_fields_recursive,
		"find-struct|s=s" => \$Opt::find_struct,
		"proc=s" => \$Opt::find_proc,
		"print-filename" => \$Opt::print_filename,
		"print-basename|b" => \$Opt::print_basename,
		"dialog|d=s" => \$Opt::dialog,
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

my($i, $t0, %args, %search);

%args = (include => $Opt::include,
	 exclude => $Opt::exclude);

if ($#Opt::find_labels == -1) {
    die "No --find option given";
}

push(@Opt::or_labels, \@Opt::find_labels);
push(@Opt::or_values, \@Opt::find_values);
push(@Opt::or_operations, \@Opt::find_operations);

if (defined($Opt::find_struct)) {
    $search{find_label} = $Opt::find_struct;
} else {
    $search{find_label} = '^/$';
}

if (defined($Opt::find_proc) &&
    $Opt::find_proc eq 'struct') {
    $Opt::proc = \&print_struct;
} else {
    $Opt::proc = \&print_data;
    if (!defined($Opt::print_fields)) {
	$Opt::print_fields = '.*';
    }
    if (!defined($Opt::find_proc) ||
	$Opt::find_proc eq 'full') {
        $Opt::find_proc = "full";
	$Opt::subproc = \&print_full_field;
    } elsif ($Opt::find_proc eq 'label') {
	$Opt::subproc = \&print_label;
    } elsif ($Opt::find_proc eq 'path') {
	$Opt::subproc = \&print_path;
    } elsif ($Opt::find_proc eq 'field') {
	$Opt::subproc = \&print_field;
    } elsif ($Opt::find_proc eq 'value') {
	$Opt::subproc = \&print_value;
    } elsif ($Opt::find_proc eq 'csv') {
	$Opt::subproc = \&print_csv;
    } else {
	die "Unknown proc in find_proc";
    }
}

$search{proc} = \&find_proc;

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

if (defined($Opt::dialog) && $Opt::dialog ne "") {
    $GffMatch::tlk = TlkRead::read(filename => $Opt::dialog);
}

foreach $i (@ARGV) {
    my($gff);
    $args{'filename'} = $i;
    $t0 = time();
    if (defined($Opt::print_filename) && $Opt::print_filename) {
	$main::file = $i;
	$main::filesep = ": ";
    } else {
	if (defined($Opt::print_basename) && $Opt::print_basename) {
	    $main::file = $i;
	    $main::file =~ s/^.*[\/\\]//g;
	    $main::filesep = ": ";
	} else {
	    $main::file = "";
	    $main::filesep = "";
	}
    }
    if ($Opt::verbose) {
	print("Reading file $i...\n");
    }
    $gff = GffRead::read(%args);
    if ($Opt::verbose) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    $gff->find(%search);
}

exit 0;

######################################################################
# Find proc
sub find_proc {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($i, $j, $match, $item, $parameters);

    if ($Opt::verbose > 4) {
	print("Found structure $full_label\n");
    }
    # Match all or'ed items togther, if any of them match set the
    # $match and exit loop.
  or_loop:
    for($i = 0; $i <= $#Opt::or_labels; $i++) {

	# Loop through all and items for the given or. If any of those
	# does not match, then go to the next round of the ors
	for($j = 0; $j <= $#{$Opt::or_labels[$i]}; $j++) {
	    # Loop through all labels in the gff, and match them
	    # agains the given label and value regexps.
	    if ($Opt::or_labels[$i][$j] =~ /@/) {
		my($cmp);
		# There is params there.
		$parameters = find_params($gff, $full_label, $label,
					  $value, $parent_gffs)
		    if (!defined($parameters));
		$cmp = replace_params($Opt::or_labels[$i][$j],
					$parameters);
		if (($Opt::or_operations[$i][$j] &&
		     ($cmp !~ /$Opt::or_values[$i][$j]/)) ||
		    (!($Opt::or_operations[$i][$j]) &&
		     ($cmp =~ /$Opt::or_values[$i][$j]/))) {
		    if ($Opt::verbose > 5) {
			print("Found match for " .
			      $Opt::or_labels[$i][$j] . "(==" . $cmp . "):" .
			      ($Opt::or_operations[$i][$j] ? "!" : "=") . ":" .
			      $Opt::or_values[$i][$j] . "\n");
		    }
		    next;
		} else {
		    if ($Opt::verbose > 5) {
			print("Didn't find match for " .
			      $Opt::or_labels[$i][$j] . "(==" . $cmp . "):" .
			      ($Opt::or_operations[$i][$j] ? "!" : "=") . ":" .
			      $Opt::or_values[$i][$j] . "\n");
		    }
		    next or_loop;
		}
	    }
	    $match = 0;
	    foreach $item (keys %$gff) {
		if ($Opt::verbose > 6) {
		    print("Trying to match " .
			  $full_label . $item . ":=:" .
			  $$gff{$item} . " with " .
			  $Opt::or_labels[$i][$j] . ":" .
			  ($Opt::or_operations[$i][$j] ? "!" : "=") . ":" .
			  $Opt::or_values[$i][$j] . "\n");
		}
		if ((($full_label . $item) =~ /$Opt::or_labels[$i][$j]/) &&
		    (($Opt::or_operations[$i][$j] &&
		      ($$gff{$item} !~ /$Opt::or_values[$i][$j]/)) ||
		     (!($Opt::or_operations[$i][$j]) &&
		      ($$gff{$item} =~ /$Opt::or_values[$i][$j]/)))) {
		    $match = 1;
		    if ($Opt::verbose > 5) {
			print("Found match for " .
			      $Opt::or_labels[$i][$j] . ":" .
			      ($Opt::or_operations[$i][$j] ? "!" : "=") . ":" .
			      $Opt::or_values[$i][$j] . "\n");
		    }
		    last;
		}
	    }
	    # Check if this item matched
	    if (!$match) {
		# Didn't match, go to next or
		if ($Opt::verbose > 5) {
		    print("Didn't find match for " .
			  $Opt::or_labels[$i][$j] . ":" .
			  ($Opt::or_operations[$i][$j] ? "!" : "=") . ":" .
			  $Opt::or_values[$i][$j] . "\n");
		}
		next or_loop;
	    }
	}
	# All items in the and loop matched, this means we are done
	# call the proc and return.
	&{$Opt::proc}($gff, $full_label, $label, $value, $parent_gffs,
		      $parameters);
	return;
    }
    # Didn't match, do nothing
    return;
}

######################################################################
# Print full struct

sub print_struct {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;

    $gff->print(dialog => $GffMatch::tlk);
}

######################################################################
# Print field from struct

sub print_data {
    my($gff, $full_label, $label, $value, $parent_gffs, $parameters) = @_;
    my($i, $prefix);

    if ($Opt::print_fields =~ /@/ && !defined($parameters)) {
	$parameters = find_params($gff, $full_label, $label, $value,
				  $parent_gffs);
    }
    if ($Opt::find_proc eq 'csv') {
	my($tmp, $comma);
	$tmp = $main::file;
	if ($tmp =~ /[\s,]/) {
	    $tmp =~ s/\"/\\\"/g;
	    $tmp = "\"" . $tmp . "\"";
	}
	if ($tmp ne "") {
	    print("$tmp");
	    $comma = ',';
	} else {
	    $comma = "";
	}
	foreach $i (split(/,/, $Opt::print_fields)) {
	    print($comma);
	    print_item($gff, $full_label, $label, $i, $parameters);
	    $comma = ',';
	}
	print("\n");
    } else {
	foreach $i (sort keys %$gff) {
	    next if ($i =~
		     /____((struct_|file_|)type|string_ref|file_version)$/);
	    next if ($i eq '');
	    if (($full_label . $i) =~ /$Opt::print_fields/) {
		print_item($gff, $full_label, $label, $i, $parameters);
	    }
	}
    }
}

######################################################################
# Print item
sub print_item {
    my($gff, $full_label, $label, $i, $parameters) = @_;

    if ($i =~ /\@/) {
	&{$Opt::subproc}($gff, $full_label . $i, $i, $i, $parameters);
	return;
    }

    if (!defined($Opt::find_proc) ||
	($Opt::find_proc ne 'label' &&
	 $Opt::find_proc ne 'path')) {
	if ($$gff{$i . ". ____type"} == 12) {
	    my($v);
	    $v = $gff->value($i . "/0");
	    if (!defined($v) || $v eq '') {
		$v = $GffMatch::tlk->string($$gff{$i . ". ____string_ref"});
	    }
	    if (defined($v)) {
		&{$Opt::subproc}($gff, $full_label . $i . '/0',
				 $i . '/0', $v, $parameters);
	    }
	} elsif (UNIVERSAL::isa($$gff{$i}, 'HASH')) {
	    if (defined($Opt::print_fields_recursive) &&
		$Opt::print_fields_recursive) {
		my($prefix);
		
		if (!defined($Opt::find_proc) ||
		    $Opt::find_proc eq 'full') {
		    &Gff::print(Gff->new($$gff{$i}),
				prefix => $main::file . $main::filesep .
				$full_label . $i,
				dialog => $GffMatch::tlk);
		} elsif ($Opt::find_proc eq 'field') {
		    &Gff::print(Gff->new($$gff{$i}),
				prefix => $main::file . $main::filesep . $i,
				dialog => $GffMatch::tlk);
		} elsif ($Opt::find_proc eq 'value') {
		    &Gff::print(Gff->new($$gff{$i}),
				prefix => $main::file . $main::filesep, 
				no_labels => 1,
				dialog => $GffMatch::tlk);
		}
	    } else {
		&{$Opt::subproc}($gff, $full_label . $i, $i,
				 "<Structure>", $parameters);
	    }
	} elsif (UNIVERSAL::isa($$gff{$i}, 'ARRAY')) {
	    if (defined($Opt::print_fields_recursive) &&
		$Opt::print_fields_recursive) {
		my($j);
		
		for($j = 0; $j <= $#{$$gff{$i}}; $j++) {
		    if (!defined($Opt::find_proc) ||
			$Opt::find_proc eq 'full') {
			&Gff::print(Gff->new($$gff{$i}[$j]),
				    prefix => $main::file . $main::filesep .
				    $full_label . $i .
				    "[" . $j . "]",
				    dialog => $GffMatch::tlk);
		    } elsif ($Opt::find_proc eq 'field') {
			&Gff::print(Gff->new($$gff{$i}[$j]),
				    prefix => $main::file . $main::filesep .
				    $i . "[" . $j . "]",
				    dialog => $GffMatch::tlk);
		    } elsif ($Opt::find_proc eq 'value') {
			&Gff::print(Gff->new($$gff{$i}[$j]),
				    prefix => $main::file . $main::filesep,
				    no_labels => 1,
				    dialog => $GffMatch::tlk);
		    }
		}
	    } else {
		&{$Opt::subproc}($gff, $full_label . $i, $i, "<Array>",
				 $parameters);
	    }
	} else {
	    &{$Opt::subproc}($gff, $full_label . $i, $i, $$gff{$i},
			     $parameters);
	}
    } else {
	&{$Opt::subproc}($gff, $full_label . $i, $i, $$gff{$i}, $parameters);
    }
}

######################################################################
# Replace parameters
# $newstr = replace_params($str, \%parameters)

sub replace_params {
    my($str, $parameters) = @_;
    my($i, $changes);

    while (1) {
	$changes = 0;
	foreach $i (keys %{$parameters}) {
	    $changes += ($str =~ s/\@$i\@/$$parameters{$i}/g);
	}
	last if ($changes == 0);
    }
    $str =~ s/\@random\((\d+)\)\@/int(rand($1) + 1)/eg;
    $str =~ s/\@frandom\((\d+)\)\@/rand($1) + 1/eg;
    $str =~ s/\@random0\((\d+)\)\@/int(rand($1))/eg;
    $str =~ s/\@frandom0\((\d+)\)\@/rand($1)/eg;
    $str =~ s/\@random\@/rand(1000000)/eg;
    $str =~ s/\@counter\((\d+),(\d+)\)\@/$1 + ($main::counter++ % $2)/eg;
    $str =~ s/\@counter\((\d+)\)\@/$1 + $main::counter++/eg;
    $str =~ s/\@counter\@/$main::counter++/eg;
    while (1) {
	$changes = 0;
	$changes += ($str =~ s/\@substr\(\s*([^@]*)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*\)@/substr($1, $2, $3)/eg);
	$changes += ($str =~ s/\@substr\(\s*([^@]*)\s*,\s*(-?\d+)\s*\)@/substr($1, $2)/eg);
	last if ($changes == 0);
    }
    return $str;
}

######################################################################
# Find parameters
# \%parameters = find_params($gff, $full_label, $label, $value, $parent_gffs);

sub find_params {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my(%parameters, $i, $v);

    if (defined($main::params_file) && $main::file eq $main::params_file) {
	%parameters = %main::params_parameters;
    } else {
	if ($main::file =~ /\.(git|gic|are)$/) {
	    my($name, $tag);
	    if ($main::file =~ /\.(git|gic)$/) {
		my($areagff, $file);
		$file = $main::file;
		$file =~ s/\.(git|gic)/.are/;
		$areagff = GffRead::read(filename => $file,
					 return_errors => 1);
		if (!defined($areagff)) {
		    die "Cannot open $file";
		} else {
		    $name = $$areagff{Name}{0};
		    $tag = $$areagff{Tag};
		    for($i = 0; $i <= $#Opt::area_parameters; $i++) {
			$v = $areagff->value($Opt::area_parameters[$i]);
			$v = "" if (!defined($v));
			$parameters{$Opt::area_parameter_names[$i]} = $v;
		    }
		}
	    } else {
		$name = $$parent_gffs[0]{Name}{0};
		$tag = $$parent_gffs[0]{Tag};
	    }
	    $name = "" if (!defined($name));
	    $tag = "" if (!defined($tag));
	    $parameters{areaname} = $name;
	    $parameters{areatag} = $tag;
	}
	for($i = 0; $i <= $#Opt::global_parameters; $i++) {
	    $v = $$parent_gffs[0]->value($Opt::global_parameters[$i]);
	    $v = "" if (!defined($v));
	    $parameters{$Opt::global_parameter_names[$i]} = $v;
	}

	for($i = 0; $i <= $#Opt::variable_parameters; $i++) {
	    if ($Opt::variable_parameters[$i] =~ /^\/(.*)$/) {
		$v = $$parent_gffs[0]->variable($1);
		if (defined($v)) {
		    $v = $v->varvalue;
		    $v = "" if (!defined($v));
		    $parameters{$Opt::variable_parameter_names[$i]} = $v;
		}
	    }
	}
	%main::params_parameters = %parameters;
	$main::params_file = $main::file;
    }

    $full_label = "" if (!defined($full_label));
    $label = "" if (!defined($label));
    $parameters{path} = $full_label;
    $parameters{label} = $label;

    for($i = 0; $i <= $#Opt::parameters; $i++) {
	$v = $gff->value($Opt::parameters[$i]);
	$v = "" if (!defined($v));
	$parameters{$Opt::parameter_names[$i]} = $v;
    }

    for($i = 0; $i <= $#Opt::variable_parameters; $i++) {
	if ($Opt::variable_parameters[$i] =~ /^\/(.*)$/) {
	    next;
	} elsif ($Opt::variable_parameters[$i] =~ /^\.\.(.*)$/) {
	    my($var, $j);
	    $var = $1;
	    for($j = $#$parent_gffs; $j >= 0; $j--) {
		$v = $$parent_gffs[0]->variable($1);
		last if (defined($v));
	    }
	} else {
	    $v = $gff->variable($Opt::variable_parameters[$i]);
	}
	if (defined($v)) {
	    $v = $v->varvalue;
	    $v = "" if (!defined($v));
	    $parameters{$Opt::variable_parameter_names[$i]} = $v;
	}
    }
    return \%parameters;
}

######################################################################
# Print full node

sub print_full_field {
    my($gff, $full_label, $label, $value, $parameters) = @_;

    $value = replace_params($value, $parameters);
    print("$main::file$main::filesep$full_label: $value\n");
}

######################################################################
# Print node

sub print_field {
    my($gff, $full_label, $label, $value, $parameters) = @_;

    $value = replace_params($value, $parameters);
    print("$main::file$main::filesep$label: $value\n");
}

######################################################################
# Print label

sub print_label {
    my($gff, $full_label, $label, $value, $parameters) = @_;

    print("$main::file$main::filesep$label\n");
}

######################################################################
# Print path

sub print_path {
    my($gff, $full_label, $label, $value, $parameters) = @_;

    print("$main::file$main::filesep$full_label\n");
}

######################################################################
# Print value

sub print_value {
    my($gff, $full_label, $label, $value, $parameters) = @_;

    $value = replace_params($value, $parameters);
    print("$main::file$main::filesep$value\n");
}

######################################################################
# Print csv

sub print_csv {
    my($gff, $full_label, $label, $value, $parameters) = @_;
    my($tmp);

    $value = replace_params($value, $parameters);
    $tmp = $value;
    if ($tmp =~ /[\s,]/) {
	$tmp =~ s/\"/\\\"/g;
	$tmp = "\"" . $tmp . "\"";
    }

    print("$tmp");
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

gffmatch - Find matching items from the gff structures

=head1 SYNOPSIS

gffmatch [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--print-filename>]
    [B<--print-basename>|B<-b>]
    [B<--print-fields-recursive>]
    [B<--exclude>|B<-e> I<exclude-regexp>]
    [B<--include>|B<-i> I<include-regexp>]
    [B<--find-struct>|B<-s> I<structure-regexp>]
    [B<--print-fields>|B<-p> I<fields-to-print-regexp>]
    [B<--proc> C<struct>|C<full>|C<field>|C<value>|C<path>|C<label>|C<csv>]
    B<--find>|B<-f> I<label-regexp>C<:=:>I<value-regexp>
    [B<--find>|B<-f> I<label-regexp>C<:=:>I<value-regexp> ...]
    [B<--find>|B<-f> I<label-regexp>C<:!:>I<value-regexp> ...]
    [B<--or>|B<-o> B<--find>|B<-f> I<label-regexp>C<:=:>I<value-regexp> ...]
    [B<--parameter>|B<-P> I<name>C<=>I<relative-path>]
    [B<--global-parameter>|B<-g> I<name>C<=>I<absolute-path>]
    [B<--area-parameter>|B<-a> I<name>C<=>I<absolute-path>]
    [B<--variable-parameter> I<name>C<=>I<varname>]
    [B<--variable-parameter> I<name>C<=>I</globalvarname>]
    [B<--variable-parameter> I<name>C<=>I<..parentvarname>]
    [B<--dialog>|B<-d> I<filename.tlk>]
    I<filename> ...

gffmatch B<--help>

=head1 DESCRIPTION

B<gffmatch> first finds the structure specified with the B<-s> option
(or use root if it is not set). Then it starts matching the list of
B<-f> options in the order of all of them match then it will print out
requested information. All B<-f> options are anded together, and
multiple set of B<-f> options can be given separated with B<-o> which
are then ored together (i.e. if any of the sets ored together matches
then print out information).

Information printed out is specified with the B<-p> option, which
gives the regexp of items from the matched structure which are printed
out. If B<--print-fields-recursive> is given then those fields are
printed out completely.

If information needs to be printed out from different parts of the
tree, then named parameters can be used to do that. Named parameters
are created by using B<--parameter>, B<--global-parameter>,
B<--area-parameter> or B<--variable-parameter>. Each of those options
takes a name of the parameter and the path to use when getting the
parameter value. The B<--parameter> takes the parameters from the
given structure, i.e. the path is relative to the current matched
structure. The B<--global-parameter> takes the parameters from the
toplevel structure, and B<--area-parameter> takes them from the area
file instead of this git file (it is useful when getting for example
Name or Tag of the area). As area name and tag are so commonly used
there is always automatic paramters C<@areaname@> and C<@areatag@>
which are set to match the area name and tag.

The B<--variable-parameter> takes the parameter value from the
variables. It can take 3 different types of input. If the I<varname>
is simply normal variable then it is taken from the current structure.
If it is C</>I<varname> then it is taken from the toplevel structure,
and if it is C<..>I<varname> then it is is taken from the matching
structure, and if not set there then from the parent structure etc.

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

=item B<--print-filename>

Prefix the output with the full file name. 

=item B<--print-basename> B<-b>

Prefix the output with the base filename, i.e. the file name where the
path component is removed. 

=item B<--print-fields-recursive>

When printing out values, print them recursively, meaning that if it
is a gff structure, print that structure and all values contained in.
The default operation is to simply print the information that it is
complex structure.

=item B<--exclude> B<-e> I<exclude-regexp>

Exclude the given regexp when reading the data in. This will skip the
whole structure behind the given structure, meaning that B<--include>
cannot be used to get parts of that back. This can be used to speed up
the processing if only specific parts of the tree is required.
Normally this should be something like I<^/Creature List> meaning that
all creature list information is skipped when reading gff.

=item B<--include> B<-i> I<include-regexp>

Only include the given regexp when reading the data in. This will skip
all other structures which do not match the regexp. This can be used
to speed up the processing if only specific parts of the tree is
required. Normally this should be something like I<^/Creature List>
meaning that only  creature list information is read in. 

=item B<--find-structure> B<-s> I<structure-regexp>

The given regexp is used to match against all full paths inside the
structure when it is processed, and if the regexp match, then this
structure is given to the actual matcher. This should specify the
structure where you want to do the matching using B<-f> options. It
should be something like C<^/Creature List\\[\\d+\\]/\$>.

=item B<--print-fields> B<-p> I<fields-to-print-regexp>

When the matching structure has been found, then print out fields
matching this regexp. This regexp gets the full path to the object,
but you can only print items which are inside the matched structure.
You cannot print values from the substructure of the selected one. If
this list contains C<@>I<name>C<@> it is replaced with the named
paramter I<name>. For areas there is automatic parameters named
C<@areaname@>, and C<@areatag@>. For all items there is always the
C<@path@>. Those items can appear anywhere on the regexp and if they
are there, the values of them are printed out. So use them inside the
regexp like this: C<Name|Tag|@areaname@>.

=item B<--proc> C<struct>|C<full>|C<field>|C<value>|C<path>|C<label>|C<csv>

Select the format how to print out the information.

=over 4

=item C<struct>

Print the whole structure recursively. The B<-p> option is ignored.

=item C<full>

Print the full label and value (this is default).

=item C<field>

Print the the relative label and value. 

=item C<value>

Print the value. 

=item C<path>

Print the full path. 

=item C<label>

Print the label. 

=item C<csv>

Print line of comma separated values, where the items in the line are
taken from the comma separated list of B<-p> option. If the B<-b> or
B<--print-filanem> is given, then the file name is added as first item
in the csv line.

=back

=item B<--find> B<-f> I<label-regexp>C<:=:>I<value-regexp>>

Match the value from field matching the given I<label-regexp> (full
path) to the I<value-regexp>. If the values match then print out
information. If there is multiple B<-f> options they are anded
together, or if they are separated with B<-o> then the two (or more)
sets of find options are ored together. 

=item B<--find> B<-f> I<label-regexp>C<:!:>I<value-regexp>>

Match the value from field matching the given I<label-regexp> (full
path) to the I<value-regexp>. If the values do not match then print
out information. If there is multiple B<-f> options they are anded
together, or if they are separated with B<-o> then the two (or more)
sets of find options are ored together.

=item B<--or> B<-o>

Used to or two (or more) sets of find options together. I.e. if any of
them match then print out information. 

=item B<--parameter> B<-P> I<name>C<=>I<relative-path>

Define named parameter I<name> to have value taken from reading the
value from the item specified by the I<relative-path>. The
I<relative-path> is relative to the current matched structure. This
I<name> can then be used in the B<-p> structure in format C<@name@>.
It can also be used when modifying field or setting variables. It
cannot be used when matching the structure.

=item B<--global-parameter> B<-g> I<name>C<=>I<absolute-path>

Define named parameter I<name> to have value taken from reading the
value from the item specified by the I<absolute-path>. The
I<absolute-path> is relative to the top structure. This I<name> can
then be used in the B<-p> structure in format C<@name@>. It can also
be used when modifying field or setting variables. It cannot be used
when matching the structure.

=item B<--area-parameter> B<-a> I<name>C<=>I<absolute-path>

Define named parameter I<name> to have value taken from reading the
value from the item specified by the I<absolute-path>. The
I<absolute-path> is relative to the top structure of the matching area
file (F<.are>). This I<name> can then be used in the B<-p> structure
in format C<@name@>. It can also be used when modifying field or
setting variables. It cannot be used when matching the structure.

=item B<--variable-parameter> I<name>C<=>I<varname>

Define named parameter I<name> to have value taken from reading the
value from the variable specified by the I<varname>. If the I<varname>
starts withe C</> then then variable read from the top structure. If
it starts with C<..> then the variable is read first from mathing
structure, and if not found there, the parent structure, etc until it
is read from the top structure. In other cases the variable is read
directly from the matching structure.

This I<name> can then be used in the B<-p> structure in format
C<@name@>. It can also be used when modifying field or setting
variables. It cannot be used when matching the structure.

=item B<--dialog> B<-d> I<filename.tlk>

Pointer to the tlk file. If given then it is used to convert string
references to strings in case there is no strings in the item item
itself.

=back

=head1 EXPRESSIONS

The named parameter can also do simple expressions. I.e. instead of
only C<@name@> they can have C<@random(12)@> or similar functions
which are replaced with the output of the given function.

Supported functions are:

=item B<@random@> | B<@random(>I<number>B<)@>

Generates random number from 1 to I<number> (number included). The
default of 1000000 is used as max if no number is given.

=item B<@random0(>I<number>B<)@>

Generates random number from 0 to I<number> (number excluded).

=item B<@frandom(>I<number>B<)@>

Generates floating point random number from 1 to I<number> (up to
number + 1 - epsilon).

=item B<@frandom0(>I<number>B<)@>

Generates floating point random number from 0 to I<number> (up to
number - epsilon).

=item B<@counter@> | B<@counter(>I<number>B<)@> | B<@counter(>I<number>B<, >I<mod>B<)@>

Generates counter that is incremented every time it is used. If
I<number> is given then start from that value, otherwise start from
zero. If I<mod> is given then return numbers from I<number> to
I<number> + I<mod> - 1.

=item B<@substr(>I<str>B<, >I<start>B<)@> | B<@substr(>I<str>B<, >I<start>B<, >I<len>B<)@>

Takes a substring of the I<str> starting from offset I<start> and with
length of I<len>. I<offset> starts from 0, and if I<offset> is
negative then it is calculated from the end of the string. If I<len>
is omitted then it assumed to be rest of the string, and if it is
negative, then it will remove that many characters from the end of
string.

=head1 EXAMPLES

    gffmatch.pl --include Creature \
        --find-struct '^/Creature List\[\d+\]/$' \
        --find '/Plot:=:^1$' \
        --print-fields '/Creature List\[\d+\]/Tag$' \
        *.git
    gffmatch.pl \
        -s '^/List\[\d+\]/$' \
        -p 'LocalizedName' \
        -f 'Plot$:=:.*' \
        *.git
    gffmatch.pl \
        -s '^/Creature List\[\d+\]/$' \
        -p 'FirstName|LastName|Tag' \
        -f '/Conversation$:=:^$' \
        *.git
    gffmatch.pl \
        -s '^/[a-zA-Z0-9 ]+\[\d+\]/$' \
        -p 'Tag|CloseLockDC|Locked|Lockable|OpenLockDC|KeyName' \
        --proc full \
            -f "/OpenLockDC$:=:^([6789][0-9]|...)$" \
            -f "/KeyRequired$:=:^0$" \
            -f "/Locked$:=:^1$" \
        -o \
            -f "/OpenLockDC$:=:^([6789][0-9]|...)$" \
            -f "/KeyRequired$:=:^0$" \
            -f "/Locked$:=:^0$" \
            -f "/Lockable$:=:^1$" \
        *.git
    gffmatch.pl \
    	--proc csv \
    	-b \
    	-s '^/Creature List\[\d+\]/$' \
    	-p 'ScriptSpawn,Tag,TemplateResRef,FirstName,LastName' \
    	-f '/ScriptSpawn$:=:.' \
    	*.git > list.csv
    gffmatch.pl \
    	--proc csv \
    	-b \
    	-s '^/$' \
    	-p 'ScriptSpawn,Tag,TemplateResRef,FirstName,LastName' \
    	-f '/ScriptSpawn$:=:.' \
    	*.utc >> list.csv

=head1 FILES

=over 6

=item ~/.gffmatchrc

Default configuration file.

=back

=head1 SEE ALSO

gffencode(1), gffmodify(1), gffprint(1), Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program evolved later to gffmodify(1), and because of that
gffmodify(1) knows even more tricks than this program. 

