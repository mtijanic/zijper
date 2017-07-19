#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# create-placeable.pl -- Create placeable from item
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: create-placeable.pl
#	  $Source: /u/samba/nwn/bin/RCS/create-placeable.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 00:37 Apr 26 2007 kivinen
#	  Last Modification : 04:03 Jul  2 2007 kivinen
#	  Last check in     : $Date: 2007/07/02 01:09:14 $
#	  Revision number   : $Revision: 1.3 $
#	  State             : $State: Exp $
#	  Version	    : 1.223
#	  Edit time	    : 138 min
#
#	  Description       : Create placeable model from item model
#
#	  $Log: create-placeable.pl,v $
#	  Revision 1.3  2007/07/02 01:09:14  kivinen
#	  	Added documentation. Changed blueprint to have inventory, and
#	  	make sure they have non existing key and key is required.
#	  	Added default c_tk_item_placeable_on_* scripts. Changed
#	  	placeables to plot.
#
#	  Revision 1.2  2007/05/23 22:22:43  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2007/05/17 21:59:48  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package CreatePlaceable;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Gff;
use GffWrite;
use Trn;
use TrnRead;
use TrnWrite;
use Math::Quaternion;
use Math::Trig;
use Pod::Usage;

$Opt::verbose = 0;
$Opt::output = undef;
@Opt::axis = ();
@Opt::angle = ();
$Opt::adjust = 0;
$Opt::quaternion = undef;
$Opt::utp_ref = undef;
$Opt::utp_name = undef;
$Opt::utp_class = undef;

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
    read_rc_file("$ENV{'HOME'}/.createplaceablerc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"output|o=s" => \$Opt::output,
		"axis|a=s" => sub { push(@Opt::axis, $_[1]) },
		"angle|A=s" => sub { push(@Opt::angle, $_[1]) },
		"adjust|j" => \$Opt::adjust,
		"quaternion|q=s" => \$Opt::quaternion,
		"utp|u=s" => \$Opt::utp_ref,
		"utpname|N=s" => \$Opt::utp_name,
		"utpclass|C=s" => \$Opt::utp_class,
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

my($i, $j, $t0, $q);
my($trn, $res, $name, $outtrn, $cnt, @bbox, @tmp, $a, $c, $az, $cz);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

if (defined($Opt::quaternion)) {
    $q = Math::Quaternion->new(split(/\s+/, $Opt::quaternion));
} elsif ($#Opt::axis != -1 && $#Opt::angle != -1) {
    if ($#Opt::axis != $#Opt::angle) {
	die "Invalid number of axis and angle option pairs";
    }
    
    $q = Math::Quaternion->new({
	axis => [ split(/\s+/, $Opt::axis[0])] ,
	angle => deg2rad($Opt::angle[0])});
    if ($Opt::adjust) {
	if (join(' ', split(/\s+/, $Opt::axis[0])) eq '1 0 0') {
	    $Opt::adjust = 2;
	} elsif (join(' ', split(/\s+/, $Opt::axis[0])) eq '0 1 0') {
	    $Opt::adjust = 3;
	} else {
	    die "Invalid axis to rotate for adjust option, first axis must be x or y";
	}
    }
    for($i = 1; $i <= $#Opt::axis; $i++) {
	$q = Math::Quaternion->new({
	    axis => [ split(/\s+/, $Opt::axis[$i])] ,
	    angle => deg2rad($Opt::angle[$i])}) * $q;
    }
}

$outtrn = new Trn;

$outtrn->version_major(1);
$outtrn->version_minor(12);

if (!defined($Opt::output)) {
    $Opt::output = $ARGV[0];
    $Opt::output =~ s/_[a-z]\./\./g;
    $Opt::output = "plc_" . $Opt::output;
}
$Opt::output =~ s/\.mdb$//g;
$cnt = '';

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

    $name = $i;
    $name =~ s/\.mdb$//g;

    @bbox = ();
    
    for($j = 0; $j < $trn->resource_count; $j++) {
	$res = $trn->decode($j);
	if ($$res{'Name'} =~ /^$name$/i) {
	    if ($cnt eq '') {
		$$res{'Name'} = $Opt::output;
		$cnt = 'a';
	    } else {
		$$res{'Name'} = $Opt::output . $cnt++;
	    }
	}
	if (lc($trn->resource_type($j)) ne 'hook') {
	    @tmp = &Trn::find_bbox($res, 'Position');
	    $bbox[0] = $tmp[0] if (!defined($bbox[0]) || $tmp[0] < $bbox[0]);
	    $bbox[1] = $tmp[1] if (!defined($bbox[1]) || $tmp[1] < $bbox[1]);
	    $bbox[2] = $tmp[2] if (!defined($bbox[2]) || $tmp[2] < $bbox[2]);
	    $bbox[3] = $tmp[3] if (!defined($bbox[3]) || $tmp[3] > $bbox[3]);
	    $bbox[4] = $tmp[4] if (!defined($bbox[4]) || $tmp[4] > $bbox[4]);
	    $bbox[5] = $tmp[5] if (!defined($bbox[5]) || $tmp[5] > $bbox[5]);
	    $outtrn->new_resource($trn->encode($j, $res),
				  $trn->resource_type($j));
	}
    }

    printf("bbox = [%.3g, %.3g, %.3g] - [%.3g, %.3g, %.3g]\n",
	   @bbox)
	if ($Opt::verbose);
    if ($i =~ /_a\.mdb$/i) {
	if ($Opt::adjust == 2) {
	    $a = $bbox[1];
	} elsif ($Opt::adjust == 3) {
	    $a = $bbox[0];
	}
	$az = $bbox[5];
    } elsif ($i =~ /_c\.mdb$/i) {
	if ($Opt::adjust == 2) {
	    $c = $bbox[1];
	} elsif ($Opt::adjust == 3) {
	    $c = $bbox[0];
	}
	$cz = $bbox[2];
    }   
}

if ($Opt::adjust && defined($a) && defined($c)) {
    printf("A = %g, C = %g, diff = %g, length = %g, angle = %g\n",
	   $a, $c, $a - $c, $az - $cz,
	   rad2deg(atan2($a - $c, $az - $cz)))
	if ($Opt::verbose);
    
    $q = Math::Quaternion->new({
	axis => [ split(/\s+/, $Opt::axis[0])] ,
	angle => (deg2rad($Opt::angle[0]) + atan2($a - $c, $az - $cz))});
    for($i = 1; $i <= $#Opt::axis; $i++) {
	$q = Math::Quaternion->new({
	    axis => [ split(/\s+/, $Opt::axis[$i])] ,
	    angle => deg2rad($Opt::angle[$i])}) * $q;
    }
}
    
@bbox = ();
for($j = 0; $j < $outtrn->resource_count; $j++) {
    $res = $outtrn->decode($j);
    if (defined($q)) {
	$res = Trn::rotate($res, $q);
    }
    @tmp = &Trn::find_bbox($res, 'Position');
    $bbox[0] = $tmp[0] if (!defined($bbox[0]) || $tmp[0] < $bbox[0]);
    $bbox[1] = $tmp[1] if (!defined($bbox[1]) || $tmp[1] < $bbox[1]);
    $bbox[2] = $tmp[2] if (!defined($bbox[2]) || $tmp[2] < $bbox[2]);
    $bbox[3] = $tmp[3] if (!defined($bbox[3]) || $tmp[3] > $bbox[3]);
    $bbox[4] = $tmp[4] if (!defined($bbox[4]) || $tmp[4] > $bbox[4]);
    $bbox[5] = $tmp[5] if (!defined($bbox[5]) || $tmp[5] > $bbox[5]);
    if (defined($q)) {
	$outtrn->encode($j, $res);
    }
}

printf("bbox = [%.3g, %.3g, %.3g] - [%.3g, %.3g, %.3g]\n",
       @bbox)
    if ($Opt::verbose);

for($j = 0; $j < $outtrn->resource_count; $j++) {
    $res = $outtrn->decode($j);
    # Make sure the z coordinate is positive
    $res = Trn::translate($res, 0, 0, (-$bbox[2]) + 0.00001, 'Position');
    $outtrn->encode($j, $res);
}

if ($Opt::verbose) {
    printf("Writing to %s.mdb\n", $Opt::output);
}
&TrnWrite::write($outtrn, filename => $Opt::output . ".mdb");

if ($Opt::verbose) {
    printf("Write done, %g seconds\n", time() - $t0);
}

if (defined($Opt::utp_ref)) {
    my($gff) = Gff->new();
    my($class, $name);

    if (defined($Opt::utp_class)) {
	$class = $Opt::utp_class;
    } else {
	$class = $Opt::output;
	$class =~ s/plc_//g;
	$class =~ s/[0-9]+$//g;
	$class =~ tr/_/\|/;
    }
    if (defined($Opt::utp_name)) {
	$name = $Opt::utp_name;
    } else {
	$name = $Opt::output;
    }
    if ($Opt::verbose) {
	printf("Writing to %s.utp\n", $Opt::output);
    }
    $gff->file_type('UTP ');
    $gff->file_version('V3.2');
    $gff->value('/ ____struct_type', '4294967295');
    $gff->value('/AnimationState', '0', 0);
    $gff->value('/Appearance', $Opt::utp_ref, 4);
    $gff->value('/AppearanceSEF', '', 11);
    $gff->value('/AutoRemoveKey', '0', 0);
    $gff->value('/BodyBag', '0', 0);
    $gff->value('/Classification', $class, 10);
    $gff->value('/CloseLockDC', '0', 0);
    $gff->value('/Comment', '', 10);
    $gff->value('/ContainerUI', '0', 0);
    $gff->value('/Conversation', '', 11);
    $gff->value('/CurrentHP', '15', 3);
    $gff->value('/DefAction', '1', 0);
    $gff->value('/Description. ____type', '12');
    $gff->value('/Description. ____string_ref', '4294967295');
    $gff->value('/DisarmDC', '15', 0);
    $gff->value('/DynamicCl', '0', 0);
    $gff->value('/Faction', '1', 4);
    $gff->value('/Fort', '16', 0);
    $gff->value('/HP', '15', 3);
    $gff->value('/Hardness', '5', 0);
    $gff->value('/HasInventory', '1', 0);
    $gff->value('/Interruptable', '1', 0);
    $gff->value('/InventorySize', '136', 3);
    $gff->value('/IsWalkable', '1', 0);
    $gff->value('/ItemList. ____type', '15');
    $gff->value('/KeyName', 'does not exists', 10);
    $gff->value('/KeyRequired', '1', 0);
    $gff->value('/LocName/0', $name);
    $gff->value('/LocName. ____type', '12');
    $gff->value('/LocName. ____string_ref', '4294967295');
    $gff->value('/Lockable', '0', 0);
    $gff->value('/Locked', '0', 0);
    $gff->value('/ModelScale/ ____struct_type', '0');
    $gff->value('/ModelScale/x', '1', 8);
    $gff->value('/ModelScale/y', '1', 8);
    $gff->value('/ModelScale/z', '1', 8);
    $gff->value('/ModelScale. ____type', '14');
    $gff->value('/OnClosed', 'c_tk_item_placeable_on_closed', 11);
    $gff->value('/OnDamaged', 'c_tk_item_placeable_on_damaged', 11);
    $gff->value('/OnDeath', 'c_tk_item_placeable_on_death', 11);
    $gff->value('/OnDialog', 'c_tk_item_placeable_on_dialog', 11);
    $gff->value('/OnDisarm', 'c_tk_item_placeable_on_disarm', 11);
    $gff->value('/OnHeartbeat', 'c_tk_item_placeable_on_heartb', 11);
    $gff->value('/OnInvDisturbed', 'c_tk_item_placeable_on_invdist', 11);
    $gff->value('/OnLock', 'c_tk_item_placeable_on_lock', 11);
    $gff->value('/OnMeleeAttacked', 'c_tk_item_placeable_on_attacked', 11);
    $gff->value('/OnOpen', 'c_tk_item_placeable_on_open', 11);
    $gff->value('/OnSpellCastAt', 'c_tk_item_placeable_on_spell', 11);
    $gff->value('/OnTrapTriggered', 'c_tk_item_placeable_on_triggered', 11);
    $gff->value('/OnUnlock', 'c_tk_item_placeable_on_unlock', 11);
    $gff->value('/OnUsed', 'c_tk_item_placeable_on_used', 11);
    $gff->value('/OnUserDefined', 'c_tk_item_placeable_on_userder', 11);
    $gff->value('/OpenLockDC', '99', 0);
    $gff->value('/PlcblCastsShadow', '1', 0);
    $gff->value('/PlcblRcvShadow', '1', 0);
    $gff->value('/Plot', '1', 0);
    $gff->value('/Ref', '0', 0);
    $gff->value('/Static', '0', 0);
    $gff->value('/Tag', $Opt::output, 10);
    $gff->value('/TalkPlayerOwn', '0', 5);
    $gff->value('/TemplateResRef', $Opt::output, 11);
    $gff->value('/Tintable/ ____struct_type', '0');
    $gff->value('/Tintable/Tint/ ____struct_type', '0');
    $gff->value('/Tintable/Tint/1/ ____struct_type', '0');
    $gff->value('/Tintable/Tint/1/a', '255', 0);
    $gff->value('/Tintable/Tint/1/b', '255', 0);
    $gff->value('/Tintable/Tint/1/g', '255', 0);
    $gff->value('/Tintable/Tint/1/r', '255', 0);
    $gff->value('/Tintable/Tint/1. ____type', '14');
    $gff->value('/Tintable/Tint/2/ ____struct_type', '0');
    $gff->value('/Tintable/Tint/2/a', '255', 0);
    $gff->value('/Tintable/Tint/2/b', '255', 0);
    $gff->value('/Tintable/Tint/2/g', '255', 0);
    $gff->value('/Tintable/Tint/2/r', '255', 0);
    $gff->value('/Tintable/Tint/2. ____type', '14');
    $gff->value('/Tintable/Tint/3/ ____struct_type', '0');
    $gff->value('/Tintable/Tint/3/a', '255', 0);
    $gff->value('/Tintable/Tint/3/b', '255', 0);
    $gff->value('/Tintable/Tint/3/g', '255', 0);
    $gff->value('/Tintable/Tint/3/r', '255', 0);
    $gff->value('/Tintable/Tint/3. ____type', '14');
    $gff->value('/Tintable/Tint. ____type', '14');
    $gff->value('/Tintable. ____type', '14');
    $gff->value('/TrapDetectDC', '0', 0);
    $gff->value('/TrapDetectable', '1', 0);
    $gff->value('/TrapDisarmable', '1', 0);
    $gff->value('/TrapFlag', '0', 0);
    $gff->value('/TrapOneShot', '1', 0);
    $gff->value('/TrapType', '0', 0);
    $gff->value('/Type', '0', 0);
    $gff->value('/UVScroll/ ____struct_type', '0');
    $gff->value('/UVScroll/Scroll', '0', 5);
    $gff->value('/UVScroll/U', '0', 8);
    $gff->value('/UVScroll/V', '0', 8);
    $gff->value('/UVScroll. ____type', '14');
    $gff->value('/Useable', '1', 0);
    $gff->value('/VarTable. ____type', '15');
    $gff->value('/Will', '0', 0);
    &GffWrite::write($gff, filename => $Opt::output . ".utp");
    
    if ($Opt::verbose) {
	printf("Write done, %g seconds\n", time() - $t0);
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

create-placeable - Convert items model to placeable model

=head1 SYNOPSIS

create-placeable [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--output>|B<-o> I<filename>]
    [B<--axis>|B<-a> I<axis>]
    [B<--angle>|B<-A> I<angle>]
    [B<--adjust>|B<-j>]
    [B<--quaternion>|B<-q> I<quaternion>]
    [B<--utp>|B<-u> I<utp-number>]
    [B<--utpname>|B<-N> I<utp-name>]
    [B<--utpclass>|B<-C> I<utp-class>]
    I<filename> ...

create-placeable B<--help>

=head1 DESCRIPTION

B<create-placeable> takes item model mdb files (usually 3, having a,
b, and c parts), and creates one output mdb file having different
name, and renaming each mesh inside to have new name matching the
output placeable.

In case B<--output> parameter is given then output is written to that
file, otherwise first input file name is used to create output name,
by removing the model part letter from the end and adding plc_ prefix
to the name.

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

Output file name. 

=item [B<--axis>|B<-a> I<axis>]

Set the axis of the rotation for the next Angle option. Axis is given
as vector having 3 floats, in xyz format. I.e. '0 0 1' specifies the
z-axies for rotation. There can be multiple axis and angles, but they
must always come in pairs.

=item [B<--angle>|B<-A> I<angle>]

Rotate the object around the axis given with --axis option with given
angle in degres. There can be multiple axis and angles, but they must
always come in pairs.

=item [B<--adjust>|B<-j>]

If given tries to adjust the angle to make the object flat on the
ground. Can only be used if axis is x or z.

=item [B<--quaternion>|B<-q> I<quaternion>]

Set the rotation as quaternion. Given as 4 floats separated by spaces. 

=item [B<--utp>|B<-u> I<utp-number>]

If given then genereate utp placeable blueprint using this as a
appearance number. The entry to the placeables.2da needs to be added
manually still, but this make placeable blueprint and sets the name
and class as given in the options below.

=item [B<--utpname>|B<-N> I<utp-name>]

Set the name of the bluepritn to utp-name. If not given then default
to the output filename.

=item [B<--utpclass>|B<-C> I<utp-class>]

Set the classification of the blueprint to utp-class. If not given
then default to the output filename, so that plc_ prefix and numbers
at the end are removed, and all underscores are changed to hierarchy.

=back

=head1 EXAMPLES

    create-placeable w_whamr01_*.mdb
    create-placeable -o plc_warhammer.mdb w_whamr01_[abc].mdb

=head1 FILES

=over 6

=item ~/.createplaceablerc

Default configuration file.

=back

=head1 SEE ALSO

remove-roof(1), trnprint(1), Trn(3), TrnWrite(3) and TrnRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was created to make placeable models from each item model
in the game, so we can place those on the ground. 
