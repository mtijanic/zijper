#!/usr/bin/env perl

require 5.6.0;
package AddOnExit;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;

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

my($i, $name, $tag, %file, $changed);

if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}

foreach $i (@ARGV) {
    my($gff);

    $gff = GffRead::read(filename => $i);
    if (!defined($$gff{OnExit})) {
      die "OnExit missing from $i, not a are file?";
    }
    if ($$gff{OnEnter} =~ /^\s*$/) {
      $name = $$gff{Name}{4};
      print("Missing OnEnter in area $name\n");
      
    }
    $changed = 0;
    
   
    if ($$gff{OnHeartbeat} =~ /^\s*$/ ||
        $$gff{OnExit} =~ /^\s*$/ ||
        $$gff{OnUserDefined} =~ /^\s*$/) {
      $changed = 1;
    }
    
    $$gff{OnHeartbeat} = "_area_hb";
    $$gff{OnUserDefined} = "_area_udef";
    $$gff{OnExit} = "_area_leave";
    
    if ($changed) {
      print("$i: Saving.\n");
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
    print("Usage: $Prog::progname [--help] [--version] ".
	  "\n\t[--config config-file] " .
	  "\n\tfilename ...\n");
    exit(0);
}
