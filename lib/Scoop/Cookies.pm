package Scoop;
use strict;

my $DEBUG = 0;

sub _get_cookies {
	my $S = shift;
	my $cookie = shift;
	my @cookies = split /;\s*/, $cookie;
	my $cookie_jar = {};
	foreach my $cookie_crumb (@cookies) {
		my ($name, $val) = split /=/, $cookie_crumb;
		$cookie_jar->{$name} = $val;
	}

	return $cookie_jar;
}


# Function _handle_cookies
# Sets cookies to the browser.
# Gets domain, path, session from Scoop object
# Calculates time.
sub _handle_cookies {
	my $S = shift;
	my $op = $S->cgi->param('op');
	
	# Don't do anything unless we have a session key
	warn "	(Scoop::_handle_cookies) Session is $S->{SESSION_KEY}\n" if ($DEBUG);
	return unless ($S->{SESSION_KEY});
	
	# Local time related vars
	my $now = time();

	# Expirey time = user pref or global, or default of 1 30-day month
	my $adj = $S->pref('cookie_expire') || 2592000;

	my $expire = $now + $adj;

	# Now we plonk our formatted string into a var for use.. 
#	my $fexpire = $S->_cookie_time($now + $adj);
#	my $pexpire = $S->_cookie_time(0);

	# Get cookie domain and path from config and vars, respectively
	my %cookie;
	$cookie{domain} = $S->CONFIG()->{cookie_host};
	$cookie{path}   = $S->{UI}->{VARS}->{rootdir} || '/';
	$cookie{name}   = $S->{CONFIG}->{site_id} . '_session';
	
	warn "  (Scoop::_handle_cookies) Cookie path is $cookie{path}\n" if ($DEBUG);

	# If the user wants to logout, set a blank cookie
	# and reset all the user data
	if ($op eq 'logout') {
		warn "  (Scoop::ApacheHandler) Logout requested. Resetting user and cookies.\n" if ($DEBUG);
		$S = $S->reset_user;

		$cookie{expire} = 0;
		$cookie{value}  = undef;
	}
	
	# If Scoop init has determined that we need to expire this session,
	# Just set a blank cookie
	if ($S->{EXPIRE_SESSION}) {
		warn "  (Scoop::ApacheHandler) Expiring session $S->{SESSION_KEY}\n" if ($DEBUG);
		$cookie{expire} = 0;
		$cookie{value}  = undef;
	}
	
	# If we don't already have a cookie, set a fresh one.  Whee.
	unless ($S->{GOT_COOKIE}) {
		warn "  (Scoop::ApacheHandler) Setting fresh cookie $S->{SESSION_KEY}\n" if ($DEBUG);
		$cookie{expire} = $expire;
		$cookie{value}  = $S->{SESSION_KEY};
	}

	# actually set the cookie
	$S->_cookie_set(\%cookie) if exists $cookie{value};

	# That's it.
	return;
}

sub _cookie_set {
	my $S = shift;
	my $cookie = shift;

	$cookie->{expire} = $S->_cookie_time($cookie->{expire});

	my $end = "$cookie->{value};expires=$cookie->{expire};path=$cookie->{path};domain=$cookie->{domain}";
	$S->apache->headers_out->{'Set-Cookie'} = "$cookie->{name}=$end";
}

sub _cookie_time {
	return &Time::CTime::strftime('%a, %d %b %Y %X GMT', gmtime($_[1]));
}

1;
