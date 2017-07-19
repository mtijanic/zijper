#!/usr/bin/env perl 
# -*- perl -*-
######################################################################
# list-conversations.pl -- List all conversations
# Copyright (c) 2004 Tero Kivinen
# All Rights Reserved.
######################################################################
#         Program: list-conversations.pl
#	  $Source: /u/samba/nwn/bin/RCS/list-conversations.pl,v $
#	  Author : $Author: kivinen $
#
#	  (C) Tero Kivinen 2004 <kivinen@iki.fi>
#
#	  Creation          : 12:01 Dec  6 2004 kivinen
#	  Last Modification : 01:27 May 24 2007 kivinen
#	  Last check in     : $Date: 2007/05/23 22:27:35 $
#	  Revision number   : $Revision: 1.2 $
#	  State             : $State: Exp $
#	  Version	    : 1.7
#	  Edit time	    : 5 min
#
#	  Description       : List all conversations
#
#	  $Log: list-conversations.pl,v $
#	  Revision 1.2  2007/05/23 22:27:35  kivinen
#	  	Fixed path splitting to accept windows paths.
#
#	  Revision 1.1  2004/12/06 10:07:26  kivinen
#	  	Created.
#
#	  $EndLog$
#
#
#
######################################################################
# initialization

require 5.6.0;
package ListConversations;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;

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
    read_rc_file("$ENV{'HOME'}/.listconversationsrc");
}

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("config=s" => \$Opt::config,
		"help|h" => \$Opt::help,
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

my($i);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

my($gff);

foreach $i (@ARGV) {
    next if ($i =~ /\.(fac|ncs)$/);
    $main::file = $i;
    if ($i =~ /\.nss$/) {
	parse_script($i);
    } else {
	$gff = GffRead::read(filename => $i);
	$gff->find(find_label => '/Conversation$', 
		   proc => \&find_proc);
    }
}

exit 0;

######################################################################
# Find proc
sub find_proc {
    my($gff, $full_label, $label, $value, $parent_gffs) = @_;

    return if ($$gff{$label . ". ____type"} != 11);
    return if ($value eq "");
    print("$value: $main::file: $full_label\n");
}

######################################################################
# Parse script and find ExecuteScript runs

sub parse_script {
    my($file) = @_;

    $/ = "\n";
    open(FILE, "<$file") || die "Cannot open $i : $!";
    while (<FILE>) {
	chomp;
	if (/BeginConversation\s*\(\s*\"([^\"]+)\"/) {
	    next if ($1 eq "");
	    print("\L$1\E: $main::file: $_\n");
	} elsif (/BeginConversation\s*\(\s*\)/) {
	    next;
	} elsif (/BeginConversation\s*\(\s*([^,]+)\)/) {
	    warn "Using conversation through variable $1 in file $file";
	} elsif (/ActionStartConversation\s*\(\s*[^,]+\s*,\s*\"([^\"]+)\"/) {
	    next if ($1 eq "");
	    print("\L$1\E: $main::file: $_\n");
	} elsif (/ActionStartConversation\s*\(\s*[^,]+\s*\)/) {
	    next;
	} elsif (/ActionStartConversation\s*\(\s*[^,]+\s*,\s*([^,]+)\)/) {
	    warn "Using conversation through variable $1 in file $file";
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
    print("Usage: $Prog::progname [--help] [--version] ".
	  "\n\t[--config config-file] " .
	  "\n\tfilename ...\n");
    exit(0);
}
