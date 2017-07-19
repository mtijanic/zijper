#!/usr/bin/perl -w 

require 5.6.0;
package FindUnusedScripts;
use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;

$Opt::verbose = 0;

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
	if (/ExecuteScript/) {
	    if (/ExecuteScript[^\"]*\"(.+)\"/) {
		$main::script{$1}++;
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
