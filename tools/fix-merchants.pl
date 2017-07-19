#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# fix-marchants.pl -- Find merchants with generic program and fix them
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: gffparse.pl
#	  $Source: /u/kivinen/nwn/bin/RCS/fix-merchants.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 17:00 Jul 19 2004 kivinen
#	  Last Modification : 19:51 Aug  6 2004 kivinen
#	  Last check in     : $Date: 2004/08/15 12:37:13 $
#	  Revision number   : $Revision: 1.6 $
#	  State             : $State: Exp $
#	  Version	    : 1.364
#	  Edit time	    : 184 min
#
#	  Description       : Find merchants with generic program and fix them
#
#	  $Log: fix-merchants.pl,v $
#	  Revision 1.6  2004/08/15 12:37:13  kivinen
#	  	Updated to new Gff module support.
#
#	  Revision 1.5  2004/07/26 15:13:41  kivinen
#	  	Added binmode.
#
#	  Revision 1.4  2004/07/26 14:37:12  kivinen
#	  	Changed to use internal globbing.
#
#	  Revision 1.3  2004/07/23 02:17:17  kivinen
#	  	Added support for writing. Added find_script function which
#	  	will simply search for scripts, nothing else. Changed the code
#	  	so that each identical Tag in script uses only one store
#	  	number. Removed .orig renames. Added removing of .nss, .ncs
#	  	and .ndb script files.
#
#	  Revision 1.2  2004/07/20 14:04:45  kivinen
#	  	Created.
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package FixMerchants;
use strict;
use GffRead;
use GffWrite;
use Gff;

undef $/;
if ($#ARGV == -1) {
    print("Usage: $0 dir [ files ]\n");
    exit(0);
}
chdir(shift);
$main::opt_n = 0;

# find_script();
find_items_to_fix();
fix_items();

######################################################################
# Find items to fix

sub find_items_to_fix {
    my($i, @files);
    print("\n\nReading areas...\n");
    if ($#ARGV == -1) {
	@files = <*.git>;
    } else {
	@files = @ARGV;
    }
    foreach $i (@files) {
#    print(STDERR "Reading file $i\n");
	$main::area = $i;
	&GffRead::read(no_store => 1,
		       include => 'Creature List',
		       exclude => '.*',
		       find_label => '/Conversation$',
		       find_label_proc => \&found_merchant,
		       find_field => '.',
		       find_field_proc => \&found_merchant,
		       filename => $i);
    }
}

######################################################################
# Found merchant, check for script in the conversation file

sub found_merchant {
    my($gff, $full_label, $label, $value) = @_;

#    print(STDERR "Found creature $full_label, $value\n");

    if (-f $value . ".dlg") {
	$main::conversation = $value;
	&GffRead::read(no_store => 1,
		       find_label => '/Script$',
		       find_label_proc => \&found_script,
		       find_field => '.',
		       find_field_proc => \&found_script,
		       filename => $value . ".dlg");
    } else {
#	warn "Conversation file $value.dlg not found";
    }
}

######################################################################
# Found script from the conversation file, check if it use OpenStore

sub found_script {
    my($gff, $full_label, $label, $value) = @_;

#    print(STDERR "Found script $full_label, $value\n");

    if (-f $value . ".nss") {
	my($data);

	return if ($value =~ /^_gen_openstore\d?$/ ||
		   $value =~ /inc_genstore$/ ||
		   $value =~ /^guild_openstore\d?$/);
	
	open(FILE, "<$value.nss") || die "Cannot open";
	binmode(FILE);
	$data = <FILE>;
	close(FILE);
	return if ($data !~ /OpenStore/);
#	print(STDERR "Found script $full_label, $value\n");
#	print(STDERR $data, "\n");
	$data =~ s/\/\/.*//g;
	$data =~ s/^\s*\#include.*//g;
	$data =~ s/\/\*.*\*\///gm;
	$data =~ s/[ \t\n\r]+/ /gm;
#	print(STDERR $data, "\n");
	$data =~ s/ //g;
	if ($data =~ /^voidmain\(\)\{(?:gplotAppraise)?OpenStore\(GetNearestObjectByTag\(\"([a-zA-Z0-9_]*)\"\),GetPCSpeaker\(\)\);\}$/ ||
	    $data =~ /voidmain\(\)\{object[a-zA-Z0-9_]*=GetNearestObjectByTag\(\"([a-zA-Z0-9_]*)\"\);if\(GetObjectType\([a-zA-Z0-9_]*\)==OBJECT_TYPE_STORE\)\{?(?:gplotAppraise)?OpenStore\([a-zA-Z0-9_]*,GetPCSpeaker\(\)\);\}?else\{?ActionSpeakStringByStrRef\(53090,TALKVOLUME_TALK\);\}\}?/ ||
	    $data =~ /voidmain\(\)\{SetLocalInt\(GetPCSpeaker\(\),\"firsttimetalked\",2\);object[a-zA-Z0-9_]*=GetNearestObjectByTag\(\"([a-zA-Z0-9_]*)\"\);if\(GetObjectType\([a-zA-Z0-9_]*\)==OBJECT_TYPE_STORE\)\{?(?:gplotAppraise)?OpenStore\([a-zA-Z0-9_]*,GetPCSpeaker\(\)\);\}?else\{?ActionSpeakStringByStrRef\(53090,TALKVOLUME_TALK\);\}\}?/ ||
	    $data =~ /voidmain\(\)\{object[a-zA-Z0-9_]*=GetPCSpeaker\(\);OpenStore\(GetNearestObjectByTag\(\"([a-zA-Z0-9_]*)\"\),[a-zA-Z0-9_]*\);\}/) {
	    my($tag);
	    $tag = $1;
#	    print(STDERR "Found $full_label, $value OpenStore to Tag $tag\n");
	    print($value, ", Tag = ", $tag,"\n");
	    push(@{$main::script{$main::area}{$main::conversation}}, $value);
	    push(@{$main::tag{$main::area}{$main::conversation}}, $tag);
	    $main::taghash{$main::area}{$main::conversation}{$tag} = 1;
	    if ($data =~ /firsttimetalked/) {
		$main::firsttime{$main::area}{$main::conversation}{$tag} = 1;
	    }
	} else {
	    print(STDERR "Found $full_label, $value unrecognized OpenStore script: $data\n");
	}
    } else {
#	warn "Script file $value.nss not found";
    }
}

######################################################################
# Fix those items

sub fix_items {
    my($i, $j, $k, $n);
    my($area_gff, $conversation_gff);

    print("\n\nFixing areas and items...\n");
    
    foreach $i (keys %main::tag) {
	$main::area = $i;
	print("Area $i\n");
	$area_gff = &GffRead::read(filename => $i);
	
	foreach $j (keys %{$main::tag{$i}}) {
	    $main::conversation = $j;
	    print("Conversation $j\n");
	    $conversation_gff = &GffRead::read(filename => $j . ".dlg");
	    for($k = 0; $k <= $#{$main::tag{$i}{$j}}; $k++) {
		print("Tag = ", $main::tag{$i}{$j}[$k], "\n");
		print("Script = ", $main::script{$i}{$j}[$k], "\n");
	    }
	    $n = 0;
	    foreach $k (keys (%{$main::taghash{$main::area}{$j}})) {
		$main::taghash{$i}{$j}{$k} = $n++;
	    }
	    
#	    &Gff::print($conversation_gff);
	    # Search for the script and fix it
	    $conversation_gff->find(find_label => '/Script$',
				    find_field => '.',
				    proc => \&fix_script);
	    if ($main::opt_n) {
		$conversation_gff->print();
	    } else {
		print("Writing $j.dlg\n");
		&GffWrite::write($conversation_gff, filename => $j . ".dlg");
		for($k = 0; $k <= $#{$main::script{$i}{$j}}; $k++) {
		    print("Removing $main::script{$i}{$j}[$k]\n");
		    unlink($main::script{$i}{$j}[$k] . ".nss", 
			   $main::script{$i}{$j}[$k] . ".ncs", 
			   $main::script{$i}{$j}[$k] . ".ndb");
		}
	    }
	}
	$area_gff->find(find_label => '/Conversation$',
			find_field => '.',
			proc => \&fix_npc);
	if ($main::opt_n) {
	    $area_gff->print();
	} else {
	    print("Writing $i\n");
	    &GffWrite::write($area_gff, filename => $i);
	}
    }
}

######################################################################
# fix_script($gff, $full_label, $label, $value, \@parent_gffs);
# Fix script in conversation file

sub fix_script {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($k, $n);

#    print("Found label $full_label, with value $value\n");
    for($k = 0;
	$k <= $#{$main::script{$main::area}{$main::conversation}};
	$k++) {
	if ($main::script{$main::area}{$main::conversation}[$k] eq $value) {
	    $n = $main::taghash{$main::area}{$main::conversation}{
		$main::tag{$main::area}{$main::conversation}[$k]};
	    print("Fixing label $full_label, with value $value to " .
		  "_gen_openstore$n\n");
	    $gff->value('Script', "_gen_openstore" . $n, 11);
	    return;
	}
    }
    return;
}

######################################################################
# fix_npc(($gff, $full_label, $label, $value, \@parent_gffs);
# Add variable to the NPC having the suitable conversation scripts.

sub fix_npc {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;
    my($j, $k, $n);
    
    foreach $j (keys %{$main::tag{$main::area}}) {
	if ($j eq $value) {
	    print("Found NPC $full_label with conv $value Tag = $$gff{Tag}\n");

	    foreach $k (keys (%{$main::taghash{$main::area}{$j}})) {
		$n = $main::taghash{$main::area}{$j}{$k};
		print("Adding variable Store$n with value $k\n");
		$gff->variable("Store" . $n, $k, "string");
		if (defined($main::firsttime{$main::area}{$j}{$k})) {
		    print("Adding variable Store${n}var = firsttimetalked " .
			  "and Store${n}int = 2\n");
		    $gff->variable("Store" . $n . "var", "firsttimetalked");
		    $gff->variable("Store" . $n . "int", "2");
		}
	    }
	    return;
	}
    }
    return;
}

######################################################################
# Match script

sub find_script {
    my($i);

    foreach $i (@ARGV) {
	my($data);
	
	next if ($i =~ /_gen_openstore\d?\.nss$/ ||
		 $i =~ /inc_genstore\.nss$/ ||
		 $i =~ /guild_openstore\d?\.nss$/);
	
	open(FILE, "<$i") || die "Cannot open";
	binmode(FILE);
	$data = <FILE>;
	close(FILE);
	next if ($data !~ /OpenStore/);
#	print(STDERR "Found script $full_label, $i\n");
#	print(STDERR $data, "\n");
	$data =~ s/\/\/.*//g;
	$data =~ s/^\s*\#include.*//g;
	$data =~ s/\/\*.*\*\///gm;
	$data =~ s/[ \t\n\r]+/ /gm;
#	print(STDERR $data, "\n");
	$data =~ s/ //g;
	if ($data =~ /^voidmain\(\)\{(?:gplotAppraise)?OpenStore\(GetNearestObjectByTag\(\"([a-zA-Z0-9_]*)\"\),GetPCSpeaker\(\)\);\}$/ ||
	    $data =~ /voidmain\(\)\{object[a-zA-Z0-9_]*=GetNearestObjectByTag\(\"([a-zA-Z0-9_]*)\"\);if\(GetObjectType\([a-zA-Z0-9_]*\)==OBJECT_TYPE_STORE\)\{?(?:gplotAppraise)?OpenStore\([a-zA-Z0-9_]*,GetPCSpeaker\(\)\);\}?else\{?ActionSpeakStringByStrRef\(53090,TALKVOLUME_TALK\);\}\}?/ ||
	    $data =~ /voidmain\(\)\{SetLocalInt\(GetPCSpeaker\(\),\"firsttimetalked\",2\);object[a-zA-Z0-9_]*=GetNearestObjectByTag\(\"([a-zA-Z0-9_]*)\"\);if\(GetObjectType\([a-zA-Z0-9_]*\)==OBJECT_TYPE_STORE\)\{?(?:gplotAppraise)?OpenStore\([a-zA-Z0-9_]*,GetPCSpeaker\(\)\);\}?else\{?ActionSpeakStringByStrRef\(53090,TALKVOLUME_TALK\);\}\}?/ ||
	    $data =~ /voidmain\(\)\{object[a-zA-Z0-9_]*=GetPCSpeaker\(\);OpenStore\(GetNearestObjectByTag\(\"([a-zA-Z0-9_]*)\"\),[a-zA-Z0-9_]*\);\}/) {
#	    print(STDERR "Found $full_label, $i OpenStore to Tag $1\n");
	    print($i, ", Tag = ", $1,"\n");
#	    unlink($i);
	} else {
	    print(STDERR "Found $i unrecognized OpenStore script: $data\n");
	}
    }
}
