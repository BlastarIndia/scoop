#!/usr/bin/perl
use LWP::UserAgent;
use HTTP::Request;
use strict;

# debug levels are:
#   0    quiet (don't print anything)
#   1    errors only
#   2    basic status messages
#   3    debug messages
# each level includes all stuff from levels below it
# note that debug only affects stuff going to stdout. stderr is not affected
my $DEBUG = 1;

if ($ARGV[0] =~ /^--?h/) {
	print "usage: run_cron.pl [-d debug] [-f file] [-h] url ...

This script will connect to each of the URLs given on the command line and
(attempt) to parse their results. Each of these URLs is assumed to be the URL
to run Scoop's cron. URLs may also be specified in a file, one per line, and
passed to this script with the -f option. More than one -f is allowed. The -d
option will change the debug level to the specified value. The -h arg will
print this message.\n";
	exit;
}

print "Discovering URL's and args\n" if $DEBUG >= 2;
my $urls = &find_urls;

my $ua = LWP::UserAgent->new;

print "Starting to call cron's\n" if $DEBUG >= 2;
foreach my $u (@{$urls}) {
	my $req = HTTP::Request->new('GET', $u);
	my $res = $ua->request($req);

	unless ($res->is_success) {
		print "Error fetching $u: ", $res->status_line, "\n" if $DEBUG >= 1;
		next;
	}

	my $raw = $res->content;
	print "Got back:\n$raw\n" if $DEBUG >= 3;
	if ($raw =~ /Errors:\n([^<]+)\n</s) {
		my $errors = $1;
		if ($DEBUG >= 1) {
			$errors =~ s/\n/\n\t/g;
			print "Error running cron for $u:\n";
			print "\t$errors\n\n";
		}
	} elsif ($raw =~ /Cron finished\nRan: ([^<]*)/) {
		my $ran = $1 ? $1 : 'none';
		print "Success fetching $u; ran $ran\n" if $DEBUG >= 2;
	} else {
		print "Unknown response:\n$raw\n" if $DEBUG >= 1;
	}
}
print "Finished calling cron's\n" if $DEBUG >= 2;

sub find_urls {
	my @urls;
	my $arg_is_next = undef;

	foreach (@ARGV) {
		print "Arg is $_\n" if $DEBUG >= 3;
		if ($arg_is_next) {
			print "Passing to arg handler\n" if $DEBUG >= 3;
			push(@urls, &handle_arg($arg_is_next, $_));
			$arg_is_next = undef;
		} elsif (/^-(.)$/) {
			print "Marking next as an arg value\n" if $DEBUG >= 3;
			$arg_is_next = $1;
		} elsif (/^-(.)(.+)$/) {
			print "Found arg, passing to handler\n" if $DEBUG >= 3;
			push(@urls, &handle_arg($1, $2));
		} else {
			print "Adding URL from command line\n" if $DEBUG >= 3;
			push(@urls, $_);
		}
	}

	return \@urls;
}

sub handle_arg {
	my $arg   = shift;
	my $value = shift;

	print "Arg: $arg\tValue: $value\n" if $DEBUG >= 3;
	if ($arg eq 'f') {
		print "Passing arg to file handler\n" if $DEBUG >= 3;
		return &add_from_file($value);
	} elsif ($arg eq 'd') {
		print "Changing debug level\n" if $DEBUG >= 3;
		if ($value =~ /\d+/) {
			$DEBUG = $value;
			return;
		} else {
			warn "invalid debug level: $value\n" unless $value =~ /\d+/;
		}
	} else {
		warn "unknown option: $arg\n";
	}
}

sub add_from_file {
	my $file = shift;

	my @urls;
	print "Opening $file to read URL's from\n" if $DEBUG >= 3;
	open(URLFILE, "<$file") || (warn("couldn't open $file: $!\n") && return);
	while (my $u = <URLFILE>) {
		chomp($u);
		next unless $u;
		print "Adding URL $u\n" if $DEBUG >= 3;
		push(@urls, $u);
	}
	close(URLFILE);

	return @urls;
}
