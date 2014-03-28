#!/usr/bin/perl -w
use strict;
use Cwd;

###############
# CVS hack to make scoop updates
# always update the VERSION file.
###############

my ($VERSIONFILE, $ROOT);
my $inargs = join ' ', @ARGV;  # Get original args for pass-thru

if ($inargs =~ /commit/i) {
	# Figure out where the version file and code root is

	if ($ENV{SCOOPVERSION} && -e $ENV{SCOOPVERSION}) {
		$VERSIONFILE = $ENV{SCOOPVERSION};
		$VERSIONFILE =~ /^(.+?)\/VERSION$/;
		$ROOT = $1;
	} else {
		my $dir = cwd;
		while ($dir) {
			if (-e "$dir/VERSION") {
				$VERSIONFILE = "$dir/VERSION";
				$ROOT = $dir;
				last;
			}
			$dir =~ s{/[^/]+$}{};
		}
	}

	unless ($VERSIONFILE && $ROOT) {
		die "Can't find VERSION file. Try setting SCOOPVERSION to the full path.\n";
	}

	&update_versionfile() if ($inargs =~ /commit/i);
}

# Now just run CVS
exec "cvs $inargs";

sub update_versionfile {
	my $vf;
	print "commit detected!\n";
	print "Scoop cvs wrapper, updating VERSION file...\n";

	# Get the version file
	open VF, "<$VERSIONFILE";
	while (<VF>) { $vf .= $_; }
	close VF;
	
	# Change the gibberish line to force a valid checkin
	my $r = rand();
	
	$r =~ s/^\d+\.//;
	$r =~ s/^0/1/;
	$vf =~ s/Gibberish: \d+/Gibberish: $r/;
	
	# Write it
	open VF, ">$VERSIONFILE";
	print VF $vf;
	close VF;
	
	# And check in the file
	my $cwd = cwd();
	chdir $ROOT;
	system("cvs commit -m \"Updating VERSION file\" VERSION");
	chdir $cwd;
	
	return;
}
