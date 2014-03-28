package Scoop::ApacheHandler;
use strict;
Apache::SIG->set() unless $Scoop::MP2;

my $DEBUG = 0;    # Enable warnings for this module
my $DB_DEBUG = 0; # Enable DB query debugging
my $DB_CACHE_DEBUG = 0;
my $PARANOID = 0; # Enable paranoid request logging

######################################################################
=pod

=head1 handler()

The interface to Apache (as required by mod_perl). This method is 
automatically called by Apache to handle all Scoop requests. It 
creates the request $S object, does some checking and preprocessing on 
the request, calls the subhandler according to op, calls $S->page_out() 
to print the response, and cleans up afterward.

=cut
######################################################################

sub handler {
	my $r = shift;
	Apache->request($r);
	my $time; # = localtime(time());
	warn "\n<<ApacheHandler: $time>> I've got this one...\n" if $DEBUG;
	if ($PARANOID) {
		my $P = {}; # Placeholder. We don't have $S yet
		&_do_paranoid_log($P, 'start');
		undef $P;
	}

	# Get an $S object, and make sure it's initialized
	my $S = Scoop->instance();
	$S->initialize();

	# Parse the path-info out. Op translation is done here too.
	&_parse_path($S);

	# finish the initialization; we needed the path parsed to get section and/or sid
	# to choose section-based themes
	$S->more_initialize();

	# Check for "safe mode"
	# If set, Scoop will only serve pages to superuser or those with the right perm
	if ($S->{UI}->{VARS}->{safe_mode} && ($S->{GID} ne 'Superuser') && !($S->have_perm('bypass_safe_mode'))) {
		my $ret = $Scoop::MP2 ? &Apache::HTTP_SERVICE_UNAVAILABLE : &Apache::Constants::HTTP_SERVICE_UNAVAILABLE;
		# check if a redirect page is set
		my $redir_page = $S->{UI}->{VARS}->{safe_mode_redirect};

		if($redir_page) {
			$S->apache->header_out('Location', $redir_page);
			$ret  = $Scoop::MP2 ? &Apache::HTTP_MOVED_TEMPORARILY : &Apache::Constants::HTTP_MOVED_TEMPORARILY;
		}
		$S->cleanup();
		undef $Scoop::_instance;
		return $ret;
	} # done checking for safe mode.

	# if this is set at any point before the op select tree is reached, it will
	# be skipped and page generation will be done with whatever is available
	my $skip_op_select = 0;
	my $op = $S->{CGI}->param('op');

	# if the op is blank, then see if the user has over-ridden it with a pref
	if (!$op && $S->{prefs}->{start_page}) {
		my $sp = $S->{prefs}->{start_page};
		if ($sp eq '__main__') {
			$op = 'main';
		} else {
			$op = 'section';
			$S->param->{section} = $sp;
		}
	}

	$op ||= 'main';
	$S->param->{op} = $op;

	# check to make sure that the op exists and is enabled. if not, pass the
	# request back to apache
	unless ($S->{OPS}->{$op} && $S->{OPS}->{$op}->{enabled}) {
		$S->cleanup();
		undef $Scoop::_instance;
		return $Scoop::MP2 ? &Apache::DECLINED : &Apache::Constants::DECLINED;
	}

	# check to make sure the user has permission to to use this op
	if ($S->{OPS}->{$op}->{perm} && !$S->have_perm($S->{OPS}->{$op}->{perm})) {
		# if not, set an error and note that op selection and calling shouldn't
		# be done later on
		$S->{CURRENT_TEMPLATE} = $S->{OPS}->{main}->{template};
		$S->{UI}->{BLOCKS}->{CONTENT} = '<b>Permission Denied.</b>';
		$skip_op_select = 1;
	}

	# in case Apache has set it for some reason, clear it first. We'll set it
	# later. Do this only after we decide to process the request.
	$S->apache->content_type('');

	# Get referrer from apache
	my $ref = $S->{APACHE}->headers_in->{"Referer"};
	warn "  Referrer is <<$ref>>\n" if $DEBUG;

	# Apache::Filter support
	# if Filter is set in our dir_config, go ahead and register ourselves
	$S->{FILTERED} = 0;
	if (lc($S->{APACHE}->dir_config('Filter')) eq "on") {
		warn "Registering for Apache::Filter\n" if $DEBUG;
		$S->{APACHE}->filter_register;
		$S->{FILTERED} = 1;
	}

	# Check for posting rate violation
	# If the post rate is violated, send them to the nasty warning page.
	if ($S->rate_check()) {
		$S->param->{'op'} = 'special';
		$S->param->{'page'} = 'rate_warn';
	}

	# Check for hotlist activity
	# this must be done before choosing the template in case hotlist() changes
	# the op
	$S->hotlist();
	$op = $S->{CGI}->param('op');   # in case it changed

	unless ($S->{CURRENT_TEMPLATE}) {		
		$S->{CURRENT_TEMPLATE} = $S->{OPS}->{$op}->{template}
			|| $S->{OPS}->{main}->{template};
	}
	warn "  Op is <<$op>>\n" if $DEBUG;
	warn "  Using template <<$S->{CURRENT_TEMPLATE}>>\n" if ($DEBUG);

	# Check for comment rating action
	if ($S->{CGI}->param('rate')) {
		$S->rate_comment();
	}
	
	$S->{UI}->{BLOCKS}->{subtitle} = '';

	if($S->{UI}->{VARS}->{allow_dynamic_comment_mode} && $S->pref('dynamic_interface')) {
		# Set dynamic blocks if the user has dynamic interface elements
		# enabled.
		$S->_setup_dynamic_blocks($S->{CGI}->param('sid'));
	}

	# Set these first, so comment select will come out right
	# Only set if we have a param or a session
	
	#$S->_set_comment_rating_choice();
	#$S->_set_comment_order();
	#$S->_set_comment_rating_thresh();
	#$S->_set_comment_type();
	
	# See if we can just try for a static cached page
	my $page_modifier = $S->check_do_static();
	if ($page_modifier) {
		warn "Looking for static page <$page_modifier>\n" if $DEBUG;
		$S->{UI}->{BLOCKS}->{'__stat_page__'} = $S->get_static_page($page_modifier);
		# If we got back data, then use that as "template"
		if ($S->{UI}->{BLOCKS}->{'__stat_page__'}) {
			$S->{CURRENT_TEMPLATE} = '__stat_page__';
			$skip_op_select = 1;
		} else {
			warn "No love from the cache. Going ahead wih normal page processing.\n" if $DEBUG;
		}
		# otherwise, we need to fetch the actual page like normal
	} 
	
	# The main decision tree.
	# Check the op and choose what we should do, calling
	# appropriate interfaces
	unless ($skip_op_select) {
		# we've already established above that the op exists, so no need to
		# worry about that. we do need to check for a function, though. if it
		# has one, call it. otherwise, it probably gets handled as a special
		# case at some point, or as a box once the page is being generated
		my $op_info = $S->{OPS}->{$op};
		if (my $func = $op_info->{func}) {
			my $return;
			if ($op_info->{is_box}) {
				$return = $S->box_magic($func, $op);
			} else {
				$return = $S->$func($op);
			}
			if ($return
			  && !$S->{UI}->{BLOCKS}->{CONTENT}
			  && !$S->{UI}->{VARS}->{CONTENT}) {
				$S->{UI}->{BLOCKS}->{CONTENT} = $return;
			}
		}
	}

	if (($page_modifier) && (!$S->{UI}->{BLOCKS}->{'__stat_page__'})) {
		warn "Trying to write new static page\n" if $DEBUG;
		$S->write_static_page($page_modifier);
	}
	
	warn "  (Scoop::ApacheHandler) Got content.\n" if ($DEBUG);
	
	$S->{UI}->{BLOCKS}->{subtitle} = $S->{UI}->{BLOCKS}->{slogan} unless $S->{UI}->{BLOCKS}->{subtitle};

	#$time = localtime(time());	

	# note: the call to _handle_cookies has moved to page_out so that boxes can
	# be taken into account when deciding whether to send a session cookie
	
	warn "  (Scoop::ApacheHandler $time) starting page_out...\n" if ($DEBUG);
	$S->page_out() unless ($op eq 'test');
	#$time = localtime(time());	
	warn "  (Scoop::ApacheHandler $time) Done.\n" if ($DEBUG);
	
	# Check for session to remove?
	if ($S->{EXPIRE_SESSION}) {
		warn "  (Scoop::ApacheHandler) Deleting expired session: $S->{SESSION_KEY}.\n" if ($DEBUG);
		$S->session->flush;
	}

	#my $get_me = $S->{APACHE}->as_string();
	#warn "  (Scoop::ApacheHandler) Query was: $get_me\n" if ($DB_DEBUG);

	# Paranoid request logging?
	if ($PARANOID || $S->{UI}->{VARS}->{paranoid_logging} ) {
		&_do_paranoid_log($S);
	}
	warn "  (Scoop::ApacheHandler) Total query count: $Scoop::DB_QUERY_COUNT\n\n" if $DB_DEBUG;
	$Scoop::DB_QUERY_COUNT = 0;
	warn "  (Scoop::ApacheHandler) CACHE HITS: $Scoop::DB_CACHE_HITS\n  (Scoop::ApacheHandler) CACHE MISS: $Scoop::DB_CACHE_MISSES\n  (Scoop::ApacheHandler) NO CACHE: $Scoop::DB_NOCACHE\n" if $DB_CACHE_DEBUG;
	$Scoop::DB_CACHE_HITS = 0;
	$Scoop::DB_CACHE_MISSES = 0;
	$Scoop::DB_NOCACHE = 0;
	
	$S->cleanup();
	undef $Scoop::_instance;
	
	return 'OK';
}


######################################################################
=pod

=head1 _do_paranoid_log

If $PARANOID is set to true in ApacheHandler.pm, this routine will write 
a bunch of useful request data to the apache error log, including time, 
date, IP of client, username, and all form parameters passed in.

This is very useful for tracking security issues, but can lead to large 
error logs.

=cut
######################################################################
sub _do_paranoid_log {
	my $S = shift;
	my $stage = shift;
	my $time = localtime(time());
	my $log;
	
	if ($stage eq 'start') {
		$log = "[$time] Starting new request, httpd: $$";		 	
	} else {
		my $req_type = $S->{APACHE}->method();
		$log = "[$time] Request from $S->{REMOTE_IP}, httpd: $$, Type: $req_type, UID: $S->{UID}, Nick: $S->{NICK}, Session: $S->{SESSION_KEY}, Args were: ";
		foreach my $arg (sort keys %{$S->{PARAMS}}) {
			$log .= "$arg: $S->{PARAMS}->{$arg}, ";
		}
	}
	$log .= "\n";
	warn $log;
}

=head1 _parse_path

Parse the URL by pulling off the op from the front of the path, calling
_find_op_template to choose the correct template from the ops table, then
using that template to put different parts of the path in various params.

=cut

sub _parse_path {
	my $S = shift;

	my $pinfo = $S->apache->uri();
	
	$pinfo =~ s/^$S->{UI}->{VARS}->{rootdir}//;
	$pinfo =~ s{^/}{};  # could combine these, but then if you put two on so
	$pinfo =~ s{/$}{};  # that a field would be empty, this would mess it up

	# Unless there's pathinfo or a template to EVAL, the job is much simpler
	unless ($S->{PARAMS}->{op} || $pinfo || $S->{UI}->{VARS}->{main_op_eval}) {
		&_translate_ops($S);  # still need to be done
		return;
	}

	my @path;
	foreach my $p (split(/\//, $pinfo)) {
		if ($p =~ /=/) {
			my ($k, $v) = split(/=/, $p);
			$S->param->{$k} = $v;
		} else {
			push(@path, $p);
		}
	}

	# Make sure if we received an op from a form, it gets passed on
	$S->param->{op} = $S->{PARAMS}->{op} || shift(@path) || 'main';
	
	&_translate_ops($S);
	my $op = $S->cgi->param('op');   # get translated one

	my $caller_op = $S->cgi->param('caller_op');
	my $template = &_find_op_template($S, $op, \@path) || return;
	warn "URL (OP) Template is $template\n" if $DEBUG;
	$template =~ s{^/|/$}{}g;
	$template =~ s/[\n\r]//g;
	if ($template =~ /^EVAL{(.*)}$/) {
		my $params = eval $1;
		if ($@) {
			warn "Eval failed! $@\n";
		} else {
			foreach my $k (keys %{$params}) {
				#warn "$k, $params->{$k}\n";
				$S->param->{$k} = $params->{$k} if defined($params->{$k});
			}
		}
	} else {
		my @host;
		if ($S->{UI}->{VARS}->{use_host_parse}) {
			for (split(/\./, $S->apache->hostname)) {
				push(@host, ($host[$#host]) ? $host[$#host] . '.' . $_ : $_);
			}
		}
		unshift(@host, $S->apache->hostname);
		foreach my $p (split(/\//, $template)) {
			if (my($name,$value) = $p =~ /^([^=]+)=(.*)$/) {  # set a var
			#	$S->param->{$name} = ($value =~ /\$host\[\d+\]/)?${$value}:$value;
				if ($S->{UI}->{VARS}->{use_host_parse}) {
					$S->param->{$name} = ($value =~ /\$host\[(\d+)\]/) ? $host[$1] : $value;
				} else{
					$S->param->{$name} = $value;
				}
				warn "_parse_path: setting $name to ".$S->param->{$name}."\n" if $DEBUG;
			} elsif ($p =~ s/\*$//) {  # fill this with all remaining path info
				$S->param->{$p} = join('/', @path);
			} elsif ($p =~ s/\{(\d+)\}$//) {  # take the next $1
				my $add;
				foreach (1 .. $1) {
					my $v = shift(@path);
					$add .= $v . '/' if $v;
				}
				chop($add);  # remove trailing slash
				$S->param->{$p} = $add if $add;
			} else {  # just take the next one
				my $v = shift(@path);
				$S->param->{$p} = $v if $v;
			}
		}
	}
}

=head1 _find_op_template

Search through the templates in the ops table until we find one that matches any
condition that might be set. If it finds a conditional, takes the first one it
finds that matches. Otherwise, uses the default. If none, then returns
undefined.

=cut

sub _find_op_template {
	my $S    = shift;
	my $op   = shift || return;
	my $path = shift || return;
	return unless ($S->{OPS}->{$op});
	
	foreach my $l (split(/,/, $S->{OPS}->{$op}->{'urltemplates'})) {
		$l =~ s/\015|\012//;
		$l =~ s/^[\n\r\s]*//;
		$l =~ s/[\n\r\s]*$//;
		$l =~ s/__COMMA__/,/g;

		return $l if ($l =~ /EVAL/);	# Use the EVAL if we find one
		$l =~ s/\s//g;			# Else, Continue Processing

		if ($l =~ s/^element\.(\d+)\=//) {	# This includes a match
			my ($part) = $1; $part--;	# Store Element Number
			my ($match, $template) = split(/:/, $l);
			return $template if $path->[$part] eq $match;
		} elsif ($l =~ s/^length=//) {
			my ($match, $template) = split(/:/, $l);
			return $template if scalar @{$path} == $match;
		} elsif ($l =~ m/^\//) {		# Generic Template
			return $l;
		}
	}
	return '';	# If We Got This Far, We've Got Nothing
}

=head1 _translate_ops

Does the job early on of checking to see if this is an alias to an op, and if
so, changing the current op to be a real one.

=cut

sub _translate_ops {
	my $S = shift;

	my $op = $S->cgi->param('op');
	return unless $op;
	for my $a (keys %{$S->{OPS}}){
		if ($op =~ m/^$a$/i) {
			$S->param->{op} = $S->{OPS}->{$a}->{op};
			$S->param->{caller_op} = $op;
			last;
		}
	}
}

sub DESTROY {
	my $self = shift;
	warn "<<Another ", ref( $self ), " bites the dust>>\n"	if $DEBUG;
}


1;
