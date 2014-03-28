#!/usr/bin/perl

my $method = $ARGV[0];

if ($method
    && (($method =~ /^--?h/)
    || (($method ne 'device')
	    && ($method ne 'rand'))
    )) {
	print "usage: gen_key.pl [method]\n
  generates a random string to be used as the site_key. Possible values for
  <method> are 'device' and 'rand'. 'device' uses the /dev/random device (if
  available), and 'rand' uses Perl's rand() function. By default, /dev/random
  will be used if it is found. Otherwise, it will fall back to rand().\n";
	exit;
}

my $key;
if ($method eq 'rand') {
	$key = builtin();
} else {
	my $dev = device_found();
	if (!$dev) {
		warn "Device not available. Falling back to rand()."
			if $method eq 'device';
		$key = builtin();
	} else {
		unless ($key = device()) {
			warn "Falling back to rand().\n";
			$key = builtin();
		}
	}
}
print "$key\n";

# try to find out if the /dev/random device is available
sub device_found {
	return (-e '/dev/random' && -c '/dev/random' && -r '/dev/random');
}

sub device {
	open(RAND, '</dev/random') || die "couldn't open /dev/random: $!\n";
	binmode(RAND);
	my $raw;
	my $got = read(RAND, $raw, 28);
	if ($got != 28) {
		warn "short read: wanted 28, only got $got\n";
		return;
	}
	close(RAND);
	my $key = unpack("H56", $raw);
	return $key;
}

sub builtin {
	my $raw;
	foreach (1..28) {
		$raw .= chr(int(rand(255)));
	}
	return unpack("H56", $raw);
}
