#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# find-unused-conversations.pl -- Find unused conversations
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: find-unused-conversations.pl
#	  $Source: /u/samba/nwn/bin/RCS/find-unused-conversations.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 17:42 Sep 29 2004 kivinen
#	  Last Modification : 01:24 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:24:19 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.33
#	  Edit time	    : 16 min
#
#	  Description       : Find and list unused conversations
#
#	  $Log: find-unused-conversations.pl,v $
#	  Revision 1.2  2007/05/23 22:24:19  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2004/09/29 15:06:16  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package FindUnusedConversations;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;

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
    read_rc_file("$ENV{'HOME'}/.findunusedconversationsrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"help|h" => \$Opt::help,
		"verbose|v+" => \$Opt::verbose,
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

my($i, $name, $tag, %file);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}
				 
foreach $i (@ARGV) {
    my($gff);
    $main::file = $i;
    if ($i =~ /^(.*)\.git$/) {
	$gff = GffRead::read(filename => $i);
	$gff->find(find_label => '^/(Creature|Door|Placeable) List\[\d+\]/$',
		   proc => \&find_proc);
    } elsif ($i =~ /^(.*)\.nss$/) {
	check_script($i);
    } elsif ($i =~ /^(.*)\.dlg$/) {
	$main::dialogs{$1}++;
    } else {
	warn "Unknown file $i, not a git file\n";
    }
}

foreach $i (sort keys %main::dialogs) {
    if (!defined($main::conversation{$i})) {
	print("Unused conversation: ") if ($Opt::verbose);
	print($i,"\n");
    }
}

exit 0;

######################################################################
# Find proc
sub find_proc {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;

    if (defined($$gff{Conversation}) && $$gff{Conversation} ne "") {
	$main::conversation{$$gff{Conversation}}++;
	print("Found $$gff{Conversation} from $main::file\n")
	    if ($Opt::verbose > 1);
    }
    if (defined($$gff{ScriptDialogue}) &&
	$$gff{ScriptDialogue} eq "openconveronentr") {
	my($tag);
	$tag = $$gff{Tag};
	if (!defined($tag)) {
	    warn "No tag for $full_label at $main::file";
	} else {
	    print("Found openconveronentr from $main::file, tag = $tag\n")
		if ($Opt::verbose > 1);
	    $main::conversation{$tag}++;
	}
    }
}
	
######################################################################
# Check script
sub check_script {
    my($file) = @_;
    my($script);

    open(FILE, "<$file") || die "Cannot open $file : $!";
    while (<FILE>) {
	if (/ActionStartConversation/) {
	    if (/ActionStartConversation[^\"]*\"(.+)\"/) {
		$main::conversation{$1}++;
		print("Found $1 from $file\n")
		    if ($Opt::verbose > 1);
	    }
	}
    }
    close(FILE);
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
    print("Usage: $Prog::progname [--help|-h] [--version|-V] [--verbose|-v]".
	  "\n\t[--config|-c config-file] " .
	  "\n\tfilename ...\n");
    exit(0);
}
