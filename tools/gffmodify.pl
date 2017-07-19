#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# gffmodify.pl -- Simple program to modify BioWare Gff files
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: gffmodify.pl
#	  $Source: /u/samba/nwn/bin/RCS/gffmodify.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 14:53 Nov 21 2004 kivinen
#	  Last Modification : 01:26 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:26:58 $
#	  Revision number   : $Revision: 1.7 $
#	  State             : $State: Exp $
#	  Version	    : 1.462
#	  Edit time	    : 283 min
#
#	  Description       : Simple program to modify BioWare Gff files
#
#	  $Log: gffmodify.pl,v $
#	  Revision 1.7  2007/05/23 22:26:58  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.6  2005/07/06 11:13:14  kivinen
#	  	Added support for non-matching match. Added ability to use
#	  	parameters in compare, added new functions.
#
#	  Revision 1.5  2005/02/05 17:50:37  kivinen
#	  	Added documentation.
#
#	  Revision 1.4  2005/02/05 14:36:14  kivinen
#	  	Added support of parameters, and default value for ask (can
#	  	come from parameters too)
#
#	  Revision 1.3  2004/12/06 09:31:23  kivinen
#	  	Fixed bug.
#
#	  Revision 1.2  2004/12/05 16:52:23  kivinen
#	  	Added interactive query. Added @ask@ support. Added @areaname@
#	  	and @areatag@ support. Added print_fields support. Added
#	  	variable add support.
#
#	  Revision 1.1  2004/11/21 14:28:49  kivinen
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
package GffModify;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Gff;
use GffRead;
use GffWrite;
use Time::HiRes qw(time);
use Pod::Usage;

$Opt::verbose = 0;
$Opt::find_struct = undef;
@Opt::find_labels = ();
@Opt::find_values = ();
@Opt::find_operations = ();
@Opt::or_labels = ();
@Opt::or_values = ();
@Opt::or_operations = ();
$Opt::no_write = 0;
$Opt::interactive = 0;
$Opt::backup = 0;
@Opt::modify_label = ();
@Opt::modify_type = ();
@Opt::modify_value = ();
$Opt::print_fields = undef;
@Opt::variable_label = ();
@Opt::variable_type = ();
@Opt::variable_value = ();
@Opt::parameters = ();
@Opt::parameter_names = ();
@Opt::global_parameters = ();
@Opt::global_parameter_names = ();
@Opt::area_parameters = ();
@Opt::area_parameter_names = ();
@Opt::variable_parameters = ();
@Opt::variable_parameter_names = ();

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
    read_rc_file("$ENV{'HOME'}/.gffmodifyrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"no-write|n" => \$Opt::no_write, 
		"backup|b" => \$Opt::backup,
		"interactive|i" => \$Opt::interactive,
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
		"find-struct|s=s" => \$Opt::find_struct,
		"print-fields|p=s" => \$Opt::print_fields,
		"modify|m=s" => sub {
		    my($name, $value) = @_;
		    if ($value =~ /^([^=\#]*)\#(\d+)=(.*)$/) {
			push(@Opt::modify_label, $1);
			push(@Opt::modify_type, $2);
			push(@Opt::modify_value, $2);
		    } elsif ($value =~ /^([^=\#]*)=(.*)$/) {
			push(@Opt::modify_label, $1);
			push(@Opt::modify_type, undef);
			push(@Opt::modify_value, $2);
		    } else {
			die "--modfify needs label[#type]=value";
		    }
		},
		"variable=s" => sub {
		    my($name, $value) = @_;
		    if ($value =~ /^([^=\#]*)\#(\d+|int|float|string)=(.*)$/) {
			push(@Opt::variable_label, $1);
			push(@Opt::variable_type, $2);
			push(@Opt::variable_value, $3);
		    } elsif ($value =~ /^([^=\#]*)=(.*)$/) {
			push(@Opt::variable_label, $1);
			push(@Opt::variable_type, undef);
			push(@Opt::variable_value, $2);
		    } else {
			die "--variable needs label[#type]=value";
		    }
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

%args = ();

if ($#Opt::modify_label == -1 && $#Opt::variable_label == -1) {
    warn "No --modify or --variable options given";
}

push(@Opt::or_labels, \@Opt::find_labels);
push(@Opt::or_values, \@Opt::find_values);
push(@Opt::or_operations, \@Opt::find_operations);

if (defined($Opt::find_struct)) {
    $search{find_label} = $Opt::find_struct;
} else {
    $search{find_label} = '^/$';
}

$search{proc} = \&find_proc;

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    my($gff);
    $args{'filename'} = $i;
    $main::file = $i;
    $t0 = time();
    if ($Opt::verbose > 1) {
	print("Reading file $i...\n");
    }
    $gff = GffRead::read(%args);
    if ($Opt::verbose > 2) {
	printf("Read done, %g seconds\n", time() - $t0);
    }
    $main::modified = 0;
    $gff->find(%search);
    if (!$Opt::no_write) {
	if ($main::modified) {
	    if ($Opt::backup) {
		if ($Opt::verbose > 1) {
		    print("Renaming $i -> $i.bak...\n");
		}
		rename($i, $i . ".bak");
	    }
	    if ($Opt::verbose) {
		print("Writing file $i...\n");
	    }
	    &GffWrite::write($gff, filename => $i);
	} else {
	    if ($Opt::verbose) {
		print("Skipped unmodified file $i...\n");
	    }
	}
    }
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
	modify_struct($gff, $full_label, $label, $value, $parent_gffs);
	return;
    }
    # Didn't match, do nothing
    return;
}

######################################################################
# Modify structure

sub modify_struct {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($i, $parameters);

    $parameters = find_params($gff, $full_label, $label, $value, $parent_gffs);
    if (defined($Opt::print_fields)) {
	print_struct($gff, $full_label, $label, $value, $parent_gffs,
		     $parameters);
    }
    if ($Opt::interactive) {
	my($reply);

	print("Modify '$full_label'? ");
	$reply = <STDIN>;
	chomp $reply;
	if ($reply eq "q") {
	    print("Exiting\n");
	    exit(0);
	} elsif ($reply ne "y") {
	    return;
	}
    }
    for($i = 0; $i <= $#Opt::modify_label; $i++) {
	my($old, $new, $default);

	$old = $gff->value($Opt::modify_label[$i]);
	$new = $Opt::modify_value[$i];
	$old = '' if (!defined($old));

	if ($new =~ /^\@ask(\(.*\))?\@$/) {
	    if (defined($1)) {
		$default = $1;
		$default =~ s/^\(//;
		$default =~ s/\)$//;
	    } else {
		$default = $old;
	    }
	    $default = replace_params($default, $parameters);
	    print("Give new value for '" .
		  $full_label . $Opt::modify_label[$i] .
		  "' (default '$default', old value '$old')? ");
	    $new = <STDIN>;
	    chomp $new;
	    if ($new eq '') {
		$new = $default ;
	    }
	}

	$new = replace_params($new, $parameters);
	if ($Opt::verbose > 3) {
	    if ($old ne '') {
		print("Modifying $Opt::modify_label[$i] in $full_label " .
		      "from $old to $new\n");
	    } else {
		print("Adding $Opt::modify_label[$i] in $full_label " .
		      "to have value $new\n");
	    }
	}
	if ($old ne $new) {
	    $main::modified = 1;

	    $gff->value($Opt::modify_label[$i],
			$new,
			$Opt::modify_type[$i]);
	}
    }
    for($i = 0; $i <= $#Opt::variable_label; $i++) {
	my($old, $new, $default);
	$old = $gff->variable($Opt::variable_label[$i]);
	if (defined($old)) {
	    $old = $old->varvalue;
	}
	$old = '' if (!defined($old));
	$new = $Opt::variable_value[$i];
	
	if ($new =~ /^\@ask(\(.*\))?\@$/) {
	    if (defined($1)) {
		$default = $1;
		$default =~ s/^\(//;
		$default =~ s/\)$//;
	    } else {
		$default = $old;
	    }
	    $default = replace_params($default, $parameters);
	    print("Give new value for '" .
		  $full_label . $Opt::variable_label[$i] .
		  "' variable (default '$default', old value '$old')? ");
	    $new = <STDIN>;
	    chomp $new;
	    if ($new eq '') {
		$new = $old;
	    }
	}
	$new = replace_params($new, $parameters);
	if ($Opt::verbose > 3) {
	    if ($old ne '') {
		print("Modifying variable $Opt::variable_label[$i] " .
		      "in $full_label from $old to $new\n");
	    } else {
		print("Adding variable $Opt::variable_label[$i] " .
		      "in $full_label to have value $new\n");
	    }
	}
	if ($old ne $new || $new eq '@remove@') {
	    $main::modified = 1;
	    if ($new eq '@remove@') {
		$new = undef;
	    }

	    $gff->variable($Opt::variable_label[$i],
			   $new,
			   $Opt::variable_type[$i]);
	}
    }
}

######################################################################
# Print field from struct

sub print_struct {
    my($gff, $full_label, $label, $value, $parent_gffs, $parameters) = @_;
    my($i, $prefix);

    foreach $i (sort keys %{$parameters}) {
	if ($Opt::print_fields =~ /\@$i\@/i) {
	    print("$main::file: \@$i\@: $$parameters{$i}\n");
	}
    }

    foreach $i (sort keys %$gff) {
	next if ($i =~ /____((struct_|file_|)type|string_ref|file_version)$/);
	next if ($i eq '');
	if (($full_label . $i) =~ /$Opt::print_fields/) {
	    if ($$gff{$i . ". ____type"} == 12) {
		if (defined($$gff{$i}{0})) {
		    print_entry($gff, $full_label . $i . '/0',
				$i . '/0', $$gff{$i}{0});
		}
	    } elsif (UNIVERSAL::isa($$gff{$i}, 'HASH')) {
		&Gff::print(Gff->new($$gff{$i}),
			    prefix => $main::file . ": " . $full_label . $i);
	    } elsif (UNIVERSAL::isa($$gff{$i}, 'ARRAY')) {
		my($j);

		for($j = 0; $j <= $#{$$gff{$i}}; $j++) {
		    &Gff::print(Gff->new($$gff{$i}[$j]),
				prefix => $main::file . ": " .
				$full_label . $i .
				"[" . $j . "]");
		}
	    } else {
		print_entry($gff, $full_label . $i, $i, $$gff{$i});
	    }
	}
    }
}

######################################################################
# Print full entry

sub print_entry {
    my($gff, $full_label, $label, $value) = @_;

    print("$main::file: $full_label: $value\n");
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

gffmodify - Find matching items and modify them from the gff structures

=head1 SYNOPSIS

gffmodify [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--no-write>|B<-n>]
    [B<--interactive>|B<-i>]
    [B<--backup>|B<-b>]
    [B<--find-struct>|B<-s> I<structure-regexp>]
    [B<--print-fields>|B<-p> I<fields-to-print-regexp>]
    B<--find>|B<-f> I<label-regexp>C<:=:>I<value-regexp>
    [B<--find>|B<-f> I<label-regexp>C<:=:>I<value-regexp> ...]
    [B<--find>|B<-f> I<label-regexp>C<:!:>I<value-regexp> ...]
    [B<--or>|B<-o> B<--find>|B<-f> I<label-regexp>C<:=:>I<value-regexp> ...]
    [B<--modify>|B<-m> I<label>C<=>I<value>]
    [B<--modify>|B<-m> I<label>[C<#>I<type>]C<=>I<value>|C<@ask>[C<(>I<default>C<)>]C<@>]
    [B<--variable> I<varname>C<=>I<value>]
    [B<--variable> I<varname>[C<#>C<int>|C<float>|C<string>]C<=>I<value>]
    [B<--parameter>|B<-P> I<name>C<=>I<relative-path>]
    [B<--global-parameter>|B<-g> I<name>C<=>I<absolute-path>]
    [B<--area-parameter>|B<-a> I<name>C<=>I<absolute-path>]
    [B<--variable-parameter> I<name>C<=>I<varname>]
    [B<--variable-parameter> I<name>C<=>I</globalvarname>]
    [B<--variable-parameter> I<name>C<=>I<..parentvarname>]
    I<filename> ...

gffmodify B<--help>

=head1 DESCRIPTION

B<gffmodify> first finds the structure specified with the B<-s> option
(or use root if it is not set). Then it starts matching the list of
B<-f> options in the order of all of them match then it will start
modifying the structure. All B<-f> options are anded together, and
multiple set of B<-f> options can be given separated with B<-o> which
are then ored together (i.e. if any of the sets ored together matches
then modify structure).

When the matching structure is found, then the modifications listed in
the B<--modify> are done in the order they are given. There can be
multiple B<--modify> options. If the value is C<@ask@> then the
program will ask for new value for the field. If you want to use some
other default than the old value, simply use C<@ask(>I<default>C<)@>
as a new value.

In addition to changing the value of fields, the B<gffmodify> can add
variables to the given structure. This can be done by using
B<--variable> option. The B<--variable> option works just like
B<--modify> but it will add variable instead of modifying field. 

When using interactive options (-i to prompt before, or C<@ask@>) then
the B<-p> option might be useful to print out some field from the
struct.

If information needs to be copied from different parts of the tree to
some other parts, then named parameters can be used to do that. Named
parameters are created by using B<--parameter>, B<--global-parameter>,
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

When adding new items the type normally needs to be given. Types are
given in numbers just like the __type field has (0 = byte, 1 = char, 2
= word, etc). If you are modifying old value, then no need to set
type. You cannot add items to arrays using this tool yet, you can only
add or modify fields in the structures.

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

=item B<--no-write> B<-n>

Do not write anything, but do the modifications etc. This can be used
to check that everything is modified properly before actually doing
the modification.

=item B<--interactive> B<-i>

Ask for verification before doing the actual change. 

=item B<--backup> B<-b>

Take backup copy of the file before writing it back. The backup copy
will be named F<file.git.bak>.

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

=item B<--modify> B<-m> I<label>[C<#>I<type>]C<=>I<value>

Do the actual modification. Modify the I<label> (relative to the
current matched structure, but it can contain path), and set it to
have I<value>. If this is new value then I<type> needs to be given.
The I<value> can also be special value C<@ask@> in which case the
value will be asked from user. The default for the C<@ask@> can be
given in parenthesis after the ask text, i.e. C<@ask(>I<default>C<)@>.
The value can also contain any of the named parameters, and those
named parameters can even be used as a default value (i.e.
C<@ask(@areaname@)@>.

=item B<--variable> I<varname>[C<#>C<int>|C<float>|C<string>]C<=>I<value>]

Add, change or remove variable of the current structure. Modify the
I<varname>, and set it to have I<value>. If this is new value then
I<type> is only needed in case it cannot be guessed properly from the
value (i.e. if value is only numbers then the type defaults to int, if
it floating point number then it defaults to float, and otherwise it
defaults to string). If you want to remove variable simply set its
value to C<@remove@>.


The I<value> can also be special value C<@ask@> in which case the
value will be asked from user. The default for the C<@ask@> can be
given in parenthesis after the ask text, i.e. C<@ask(>I<default>C<)@>.
The value can also contain any of the named parameters, and those
named parameters can even be used as a default value (i.e.
C<@ask(@areaname@)@>.

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

    gffmodify.pl \
        -v \
        -s '^/$' \
        -f '^/ScriptOnNotice$:=:^X$' \
        -m '/ScriptOnNotice=Y' \
        -m '/ScriptSpawn=Z' \
        *.utc
    gffmodify.pl \
        -v \
        -s '^/Placeable List\[\d+\]/$' \
    	-f '/OnOpen$:=:^X$' \
    	-m '/OnOpen=Y' \
    	*.git
    gffmodify.pl -v -f '/Tag$:=:^CELIALIAMYN$' -m 'Tag=CELIASAD' Celia.utc
    gffmodify.pl \
        -p 'Fog|Tag|@areaname@' \
        -f '^/FogClipDist$:=:.' \
        -m 'FogClipDist=@ask(55)@' \
        -v \
        *.are 
    gffmodify.pl \
        -p 'Plot|Static|Useable|LocName|Tag|@areaname@' \
        -s '^/Placeable List\[\d+\]/$' \
        -f '/Plot$:=:^0$' \
        -m 'Plot=@ask@' \
        -v *.git
    gffmodify.pl \
        -v \
        -s '^/Door List\[\d+\]/$' \
        -f '/Locked$:=:^0$' \
        -f '/Lockable$:=:^0$' \
        -f '/KeyRequired$:=:^0$' \
        -f '/KeyName$:=:^$' \
        -m '/KeyRequired=1' \
        -m 'KeyName=dm_quest_key' \
        *.git
    gffmodify.pl \
        -p '@areaname@|@areatag@|/Var' \
        --variable 'X2_L_WILD_MAGIC=1' \
        -v \
        *.git
    gffmodify.pl \
        -p 'FirstName|@areaname@|@areatag@|@wild@|@height@|@item@|@tag@' \
        -P 'tag=Tag' \
        -variable-parameter 'wild=/X2_L_WILD_MAGIC' \
        -a 'width=/Width' \
        -a 'height=/Height' \
        -s '^/Creature List\[\d*\]/$' \
        --variable-parameter 'item=giveitem1' \
        -f '/ChallengeRating$:=:.' \
        -m 'ClassList[0]/ClassLevel=@ask(@height@)@' -v foo.git

=head1 FILES

=over 6

=item ~/.gffmodifyrc

Default configuration file.

=back

=head1 SEE ALSO

gffencode(1), gffmatch(1), gffprint(1), Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program evolved from gffmatch(1) and has been enchanced after
that to support variables and parameters etc.

