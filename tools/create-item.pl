#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# create-item.pl -- Create item
# Copyright (c) 2005 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: create-item.pl
#	  $Source: /u/samba/nwn/bin/RCS/create-item.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2005 <kivinen@iki.fi>
#
#	  Creation          : 18:53 Jan  9 2005 kivinen
#	  Last Modification : 01:22 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:22:36 $
#	  Revision number   : $Revision: 1.3 $
#	  State             : $State: Exp $
#	  Version	    : 1.244
#	  Edit time	    : 116 min
#
#	  Description       : Create random looking item for given name
#
#	  $Log: create-item.pl,v $
#	  Revision 1.3  2007/05/23 22:22:36  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.2  2007/04/23 23:35:59  kivinen
#	  	Updated to new use of Twoda.
#
#	  Revision 1.1  2005/02/05 14:33:22  kivinen
#	  	Create wand and potions.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package CreateItem;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;
use Twoda;

$Opt::twodadir = "/u/samba/nwn/1.64/";
$Opt::type = "p";
$Opt::maximized = 0;

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
    read_rc_file("$ENV{'HOME'}/.createitemrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"help|h" => \$Opt::help,
		"spell|s=s" => \$Opt::spell_id,
		"maximized|m" => \$Opt::maximized,
		"name|n=s" => \$Opt::name,
		"twoda|2=s" => \$Opt::twodadir,
		"potion|p" => sub { $Opt::type = "p"; },
		"wand|w" => sub { $Opt::type = "W"; },
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

my($spell_id, $name, $i, $prop_id);

$CreateItem::des_crft_spells = Twoda::read($Opt::twodadir .
					   "des_crft_spells.2da");
$CreateItem::baseitems = Twoda::read($Opt::twodadir . "baseitems.2da");
$CreateItem::spells = Twoda::read($Opt::twodadir . "spells.2da");
$CreateItem::itempropdef = Twoda::read($Opt::twodadir . "itempropdef.2da");
$CreateItem::iprp_costtable = Twoda::read($Opt::twodadir .
					  "iprp_costtable.2da");

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

if ($#ARGV == -1) {
    if (!defined($Opt::spell_id)) {
	die "Need --spell unless reading them from file";
    }
    $prop_id =
	$$CreateItem::des_crft_spells{Data}[$Opt::spell_id]{'IPRP_SpellIndex'};
    create_one($Opt::spell_id, $Opt::name, $prop_id, $prop_id);
} else {
    while (<>) {
	chomp;
	($spell_id, $name) = split;
	if (defined($name)) {
	    $name =~ s/_/ /g;
	}
	$prop_id =
	    $$CreateItem::des_crft_spells{Data}[$spell_id]{'IPRP_SpellIndex'};
	create_one($spell_id, $name, $prop_id);
    }
}

exit 0;

######################################################################
# Create one item

sub create_one {
    my($spell_id, $name, $prop_id) = @_;
    my($gff, $file, $model1, $model2, $model3, $baseitem, $description);
    my($propertyname, $costvalue, $paletteid, $costtable, $cost, $charges);

    if (!defined($name)) {
	$name = $$CreateItem::spells{Data}[$spell_id]{Label};
	$name =~ s/_/ /g;
	if ($Opt::type eq "p") {
	    $name = "Potion of " . $name;
	} else {
	    $name = "Wand of " . $name;
	}
	if ($Opt::maximized) {
	    $name = "Maximized " . $name;
	}
    }

    printf("Creating spell_id = %d, prop_id = %d, name = %s\n",
	   $spell_id, $prop_id, $name);

    if ($Opt::maximized) {
	$file = sprintf("si_%04d%s00_04", $spell_id, $Opt::type);
    } else {
	$file = sprintf("si_%04d%s", $spell_id, $Opt::type);
    }
    $gff = Gff->new();
    $gff->file_type("UTI ");
    $gff->file_version("V3.2");
    if ($Opt::type eq "p") {
	$model1 = (int(rand(7)) + 1) * 10 + int(rand(8)) + 1;
	$model2 = (int(rand(7)) + 1) * 10 + int(rand(3)) + 1;
	$model3 = (int(rand(7)) + 1) * 10 + int(rand(3)) + 1;
	$baseitem = 49;
	$description = 'This is magic potion brewed by some skillfull craftsman. ';
	$paletteid = 24;
	$costvalue = 1;
	$charges = 0;
    } elsif ($Opt::type eq "W") {
	$model1 = (int(rand(6)) + 1) * 10 + int(rand(4)) + 1;
	$model2 = (int(rand(6)) + 1) * 10 + int(rand(4)) + 1;
	$model3 = (int(rand(6)) + 1) * 10 + int(rand(4)) + 1;
	$baseitem = 46;
	$description = 'This is magic wand crafted by some skillfull craftsman. ';
	$paletteid = 50;
	$costvalue = 6;
	$charges = 25;
    } else {
	die "Unknown type $Opt::type";
    }
    if ($Opt::maximized) {
	$description .= "\n\nThis item seems to be modified to have maximium power.";
    }
    $propertyname = 15;
    $costtable = 3;

    $cost = nwn_cost($baseitem, { 'CostTable' => $costtable,
				  'CostValue' => $costvalue,
				  'PropertyName' => $propertyname,
				  'Subtype' => $prop_id});
    if ($Opt::maximized) {
	$cost *= 2;
    }

    print("Cost = $cost\n");
    $gff->value('/ ____struct_type', 4294967295);
    $gff->value('/AddCost', 0);
    $gff->value('/AddCost. ____type', 4);
    $gff->value('/BaseItem', $baseitem);
    $gff->value('/BaseItem. ____type', 5);
    $gff->value('/Charges', $charges);
    $gff->value('/Charges. ____type', 0);
    $gff->value('/Comment', );
    $gff->value('/Comment. ____type', 10);
    $gff->value('/Cost', $cost);
    $gff->value('/Cost. ____type', 4);
    $gff->value('/Cursed', 0);
    $gff->value('/Cursed. ____type', 0);
    $gff->value('/DescIdentified/0', $description);
    $gff->value('/DescIdentified. ____string_ref', 4294967295);
    $gff->value('/DescIdentified. ____type', 12);
    $gff->value('/Description/0', '');
    $gff->value('/Description. ____string_ref', 4294967295);
    $gff->value('/Description. ____type', 12);
    $gff->value('/Identified', 1);
    $gff->value('/Identified. ____type', 0);
    $gff->value('/LocalizedName/0', $name);
    $gff->value('/LocalizedName. ____string_ref', 4294967295);
    $gff->value('/LocalizedName. ____type', 12);
    $gff->value('/ModelPart1', $model1);
    $gff->value('/ModelPart1. ____type', 0);
    $gff->value('/ModelPart2', $model2);
    $gff->value('/ModelPart2. ____type', 0);
    $gff->value('/ModelPart3', $model3);
    $gff->value('/ModelPart3. ____type', 0);
    $gff->value('/PropertiesList[0]/', '/PropertiesList[0]');
    $gff->value('/PropertiesList[0]/ ____struct_type', 0);
    $gff->value('/PropertiesList[0]/ChanceAppear', 100);
    $gff->value('/PropertiesList[0]/ChanceAppear. ____type', 0);
    $gff->value('/PropertiesList[0]/CostTable', $costtable);
    $gff->value('/PropertiesList[0]/CostTable. ____type', 0);
    $gff->value('/PropertiesList[0]/CostValue', $costvalue);
    $gff->value('/PropertiesList[0]/CostValue. ____type', 2);
    $gff->value('/PropertiesList[0]/Param1', 255);
    $gff->value('/PropertiesList[0]/Param1. ____type', 0);
    $gff->value('/PropertiesList[0]/Param1Value', 0);
    $gff->value('/PropertiesList[0]/Param1Value. ____type', 0);
    $gff->value('/PropertiesList[0]/PropertyName', $propertyname);
    $gff->value('/PropertiesList[0]/PropertyName. ____type', 2);
    $gff->value('/PropertiesList[0]/Subtype', $prop_id);
    $gff->value('/PropertiesList[0]/Subtype. ____type', 2);
    $gff->value('/PropertiesList. ____type', 15);
    $gff->value('/PaletteID', $paletteid);
    $gff->value('/PaletteID. ____type', 0);
    $gff->value('/Plot', 0);
    $gff->value('/Plot. ____type', 0);
    $gff->value('/StackSize', 10);
    $gff->value('/StackSize. ____type', 2);
    $gff->value('/Stolen', 0);
    $gff->value('/Stolen. ____type', 0);
    $gff->value('/Tag', $file);
    $gff->value('/Tag. ____type', 10);
    $gff->value('/TemplateResRef', $file);
    $gff->value('/TemplateResRef. ____type', 11);
    &GffWrite::write($gff, filename => $file . ".uti");
}

######################################################################
# ($propertycost, $costvalue, $subtypecost) =
#      nwn_property_costs(\%property);
sub nwn_property_costs {
    my($property) = @_;
    my($costtable, $costvalue, $propertyname, $subtype);
    my($subtyperesref2da, $subtypecosttable);
    my($costtable2da, $costtabletable);
    my($propertycost_ret, $costvalue_ret, $subtypecost_ret);

    $costtable = $$property{CostTable};
    $costvalue = $$property{CostValue};
    $propertyname = $$property{PropertyName};
    $subtype = $$property{Subtype};

#    print("Counting cost for costtable = $costtable, " .
#	  "costvalue = $costvalue, propertyname = $propertyname, " .
#	  "subtype = $subtype\n");
    $costvalue_ret = 0;
    $subtypecost_ret = 0;
    $propertycost_ret = $$CreateItem::itempropdef{Data}[$propertyname]{'Cost'};
    $propertycost_ret = 0 if ($propertycost_ret eq "****");
    if ($propertycost_ret == 0) {
	$subtyperesref2da =
	    $$CreateItem::itempropdef{Data}[$propertyname]{'SubTypeResRef'};
	if ($subtyperesref2da ne "****") {
	    $subtypecosttable =
		Twoda::read($Opt::twodadir . lc($subtyperesref2da) . ".2da");
	    $subtypecost_ret =
		$$subtypecosttable{Data}[$subtype]{'Cost'};
	}
    }
    $costtable2da = $$CreateItem::iprp_costtable{Data}[$costtable]{'Name'};
    if ($costtable2da ne "****") {
	$costtabletable = Twoda::read($Opt::twodadir .
				      lc($costtable2da) . ".2da");
	$costvalue_ret = $$costtabletable{Data}[$costvalue]{'Cost'};
    }
    return ($propertycost_ret, $costvalue_ret, $subtypecost_ret);
}

######################################################################
# $cost = nwn_cost($baseitem, \%property, ...)
# Each property have CostTable, CostValue, PropertyName, Subtype fields. 
# Calculate cost

sub nwn_cost {
    my($baseitem, @properties) = @_;
    my($itemcost, $i);
    my($basecost, $basemult, $multiplier, $negmultiplier, $spellcosts);
    my($first, $second);

    $basecost = $$CreateItem::baseitems{Data}[$baseitem]{'BaseCost'};
    $basemult = $$CreateItem::baseitems{Data}[$baseitem]{'ItemMultiplier'};
    $multiplier = 0;
    $negmultiplier = 0;
    $spellcosts = 0;
    $first = 0;
    $second = 0;
    # XXX Basecost is incorrect for armors. 

    foreach $i (@properties) {
	my($prop_propertycost, $prop_costvalue, $prop_subtypecost, $cost);
	($prop_propertycost, $prop_costvalue, $prop_subtypecost) =
	    nwn_property_costs($i);
	if ($$i{PropertyName} == 15) {
	    # Spells.
	    $cost = ($prop_propertycost + $prop_costvalue) *
		$prop_subtypecost;
	    if ($cost > $first) {
		$spellcosts += $second * 0.5;
		$second = $first;
		$first = $cost;
	    } elsif ($cost > $second) {
		$spellcosts += $second * 0.5;
		$second = $cost;
	    } else {
		$spellcosts += $cost * 0.5;
	    }
	} else {
	    $cost = $prop_propertycost + $prop_costvalue + $prop_subtypecost;
	    # Others
	    if ($cost > 0) {
		$multiplier += $cost;
	    } else {
		$negmultiplier -= $cost;
	    }
	}
    }
    $spellcosts += $first + $second * 0.75;
    $itemcost = ($basecost + 1000 * ($multiplier * $multiplier -
				     $negmultiplier * $negmultiplier) +
		 $spellcosts) * $basemult;
    return $itemcost;
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
	  "\n\t[--config config-file] " .
	  "\n\t[--spell spell_id] " .
	  "\n\t[--maximized] " .
	  "\n\t[--wand | --potion] " .
	  "\n\t[--twoda directory_of_2da_files] " .
	  "\n\tfilename ...\n");
    exit(0);
}
