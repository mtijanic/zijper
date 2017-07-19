#!/usr/bin/perl -w 

require 5.6.0;
package UpdateItp;
#use strict;
use Getopt::Long;
use File::Glob ':glob';
use GffRead;
use GffWrite;
use Gff;
use Pod::Usage;

$| = 1;

######################################################################
# Option handling

Getopt::Long::Configure("no_ignore_case");

if (!GetOptions("help|h" => \$Opt::help,
		"version|V" => \$Opt::version) || defined($Opt::help)) {
    usage();
}

######################################################################
# Main loop

$| = 1;

my $target = "ptest.itp";
my ($i);
# main{main_id}->{id=PaletteID,strref, list{},  }

my @main;


if (join(";", @ARGV) =~ /[*?]/) {
    my(@argv);
    foreach $i (@ARGV) {
	push(@argv, bsd_glob($i));
    }
    @ARGV = @argv;
}
if ($#ARGV == -1) {
    printf("No args, defaulting to *.utp\n");
    $ARGV[0] = "*.utp";
}


foreach $i (@ARGV) {
	
	# Read the file and prepare the hash
	my $tmpgff = GffRead::read(filename => $i);
	my $paletteID = $tmpgff->{PaletteID};
	my %item = (
		'RESREF' => $tmpgff->{TemplateResRef},
		'NAME' => defined $tmpgff->{LocName}->{4} ? $tmpgff->{LocName}->{4} : $tmpgff->{LocName}->{5},
	);
	# $item{NAME} = undef if (defined $item->{NAME} and $item->{NAME} eq "");

	# See if we have one already
	my $found = 0;
	my %f;

	foreach $%item (@main) {
		print "item $item\n";
		if (${$item}{ID} eq $paletteID) {
			$found = 1;
			%f = $item;
			print "Found Hash for $paletteID\n";
		};
	};

	
	if (!$found) {
		print "Pushing onto main for $paletteID\n";
		%h = (
			'ID', $paletteID,
			'STRREF', "fs",
			'List', (),
		);

		push @main, (%h);
	}

}


exit 0;




######################################################################
# Usage

sub usage {
    Pod::Usage::pod2usage(0);
}

=head1 NAME

update-ifo - Updates the module.ifo file based on the area list

=head1 SYNOPSIS

update-ifo [B<--help>|B<-h>] [B<--version>|B<-V>] 
    [B<--config> I<config-file>]
    [I<filename> ...]

update-ifo B<--help>

=head1 DESCRIPTION

B<update-ifo> will read the module.ifo in from the current directory,
and replace the Mod_Area_list inside the module.ifo with the one
created from the filenames given as an argument (defaults to *.are if
no arguments are given). It will then write updated module.ifo back to
the disk. This can be used along with B<check-module> to fix the
broken module.ifo file.

=head1 OPTIONS

=over 4

=item B<--help> B<-h>

Prints out the usage information.

=item B<--version> B<-V>

Prints out the version information. 

=item B<--config> I<config-file>

All options given by the command line can also be given in the
configuration file. This option is used to read another configuration
file in addition to the default configuration file. 

=back

=head1 EXAMPLES

    update-ifo *.are
    update-ifo

=head1 FILES

=over 6

=item ~/.updateiforc

Default configuration file.

=back

=head1 SEE ALSO

check-module(1), gffprint(1), GffWrite(3), Gff(3), and GffRead(3).

=head1 AUTHOR

Tero Kivinen <kivinen@iki.fi>.

=head1 HISTORY

This program was used to "recover" cerea1 module few times, after its
module.ifo was broken. Later it was used when we renamed lots of area
resource files to have better names, and didn't want to manually edit
module.ifo. 
