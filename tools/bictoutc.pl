#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# bictoutc.pl -- Convert PC to NPC
# Copyright (c) 2007 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: bictoutc.pl
#	  $Source: /u/samba/nwn/bin/RCS/bictoutc.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2007 <kivinen@iki.fi>
#
#	  Creation          : 21:17 Jan 10 2007 kivinen
#	  Last Modification : 01:21 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:21:28 $
#	  Revision number   : $Revision: 1.3 $
#	  State             : $State: Exp $
#	  Version	    : 1.48
#	  Edit time	    : 35 min
#
#	  Description       : Convert PC to NPC
#
#	  $Log: bictoutc.pl,v $
#	  Revision 1.3  2007/05/23 22:21:28  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.2  2007/01/12 20:09:54  kivinen
#	  	Fixed faction id setting, in case it wasn't already in the bic
#	  	file, and then it didn't have proper type.
#
#	  Revision 1.1  2007/01/10 21:23:32  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
#
######################################################################
# initialization

#gffprint.pl -t --exclude-field '^(Age|AmbientAnimState|AnimationDay|AnimationTime|AreaId|ArmorClass|AttackResult|BaseAttackBonus|BlockBroadcast|BlockCombat|BlockRespond|BodyBagId|Color_Tattoo.|CombatMode|CreatnScrptFird|CreatureSize|DamageMax|DamageMin|DeadSelectable|DefCastMode|DetectMode|Experience|FortSaveThrow|Gold|IgnoreTarget|IsCommandable|IsDM|IsDestroyable|IsRaiseable|Listening|MClassLevUpIn|MasterID|MovementRate|OffHandAttacks|OnHandAttacks|OrientOnDialog|Origin.*|OverrideBAB.*|PM_IsPolymorphed|Portrait|PossBlocked|PregameCurrent|RefSaveThrow|RosterMember|RosterTag|ScriptsBckdUp|SitObject|SkillPoints|StealthMode|TrackingMode|WillSaveThrow|.Orientation|.Position|oidTarget)$' --exclude '^/(CombatInfo|HotbarList|LvlStatList|ItemList|VarTable)' perumgrenmert.bic | sed '/Equip_ItemList[^/]*\/[A-Za-z]/ { s/TemplateResRef/EquippedRes/g; /EquippedRes/p; d; }; s/\(FactionID:\).*/\1        2/g' |  gffencode.pl -o ../cerea257/cr_tk_pp.utc

require 5.6.0;
package BicToUtc;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use Gff;
use GffRead;
use GffWrite;
use Pod::Usage;

$Opt::verbose = 0;

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
    read_rc_file("$ENV{'HOME'}/.bictoutcrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"verbose|v+" => \$Opt::verbose,
		"help|h" => \$Opt::help,
		"output|o=s" => \$Opt::output,
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

my($i);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    my($gff, $j, $k, $subgff, $resref, $type);
    if ($Opt::verbose > 1) {
	print("Reading file $i...\n");
    }
    $gff = GffRead::read(filename => $i,
			 exclude_field => '^(Age|AmbientAnimState|AnimationDay|AnimationTime|AreaId|ArmorClass|AttackResult|BaseAttackBonus|BlockBroadcast|BlockCombat|BlockRespond|BodyBagId|Color_Tattoo.|CombatMode|CreatnScrptFird|CreatureSize|DamageMax|DamageMin|DeadSelectable|DefCastMode|DetectMode|Experience|FortSaveThrow|Gold|IgnoreTarget|IsCommandable|IsDM|IsDestroyable|IsRaiseable|Listening|MClassLevUpIn|MasterID|MovementRate|OffHandAttacks|OnHandAttacks|OrientOnDialog|Origin.*|OverrideBAB.*|PM_IsPolymorphed|Portrait|PossBlocked|PregameCurrent|RefSaveThrow|RosterMember|RosterTag|ScriptsBckdUp|SitObject|SkillPoints|StealthMode|TrackingMode|WillSaveThrow|.Orientation|.Position|oidTarget)$', #'
			 exclude => '^\/(CombatInfo|HotbarList|LvlStatList|ItemList|VarTable)');
    if ($Opt::verbose > 2) {
	printf("Read done\n");
    }
    $gff->value("FactionID", 2, 2);
    for($j = 0; $j <= $#{$$gff{Equip_ItemList}}; $j++) {
	$subgff = $gff->value("/Equip_ItemList[$j]/");
	$resref = $subgff->value("TemplateResRef");
	$type = $subgff->type("TemplateResRef");
	foreach $k ($subgff->struct_keys()) {
	    delete $$subgff{$k};
	}
	$subgff->value("EquippedRes", $resref, $type);
    }
    if ($Opt::verbose) {
	print("Writing file $i...\n");
    }
    if (defined($Opt::output)) {
	&GffWrite::write($gff, filename => $Opt::output);
    } else {
	$i =~ s/\.bic/\.utc/g;
	&GffWrite::write($gff, filename => $i);
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

bictoutc - Convert PC bic file to NPC utc file.

=head1 SYNOPSIS

bictoutc [B<--help>|B<-h>] [B<--version>|B<-V>] [B<--verbose>|B<-v>]
    [B<--config> I<config-file>]
    [B<--output> I<filename>]
    I<filename> ...

bictoutc B<--help>

=head1 DESCRIPTION

B<bictoutc> converts player bic file to NPC utc file, by removing
extra information from the PC file. This includes all items in
inventory.

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

Store the output to I<filename>. The default is to change the .bic
extension to .utc extension. Note that if you use this and give
multiple input files, then all of them are written to same output file
(i.e. only the last of them is actually saved). 

=head1 EXAMPLES

    bictoutc.pl -v pc.bic
    bictoutc.pl -v -o npc.utc pc.bic

=head1 FILES

=over 6

=item ~/.bictoutcrc

Default configuration file.

=back

=head1 SEE ALSO

gffencode(1), gffmodify(1), Gff(3), GffWrite(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program evolved from gffencode(1) by removing most of the
complicated processing and by replacing it with the very simple
ignoring of fields. 
