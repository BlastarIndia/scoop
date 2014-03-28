=pod

=head1 Scoop.pm

Scoop.pm mainly creates and populates the $S object. This is a central 
"portmanteau" object that carries around lots of information about the 
current user, server, scoop system, etc. It is blessed into the package 
"Scoop", and since almost every library in the system is also part of 
this package, every method (subroutine) here can usually be called from $S, 
with the usual perl OO syntax. So, $S is a pretty important thing to 
know about.

What follows will be a description of the $S object, first, and then 
documentation on some of the more useful methods defined within Scoop.pm.
Please note that this is developer documentation, not user documentation. 
If you want to know how to run a Scoop system, look for information 
on http://scoop.kuro5hin.org/guide/ currently. We hope to have better 
admin docs available very soon.

Developer docs are, or will soon be, in all of the other .pm files here as 
well, so if you're looking for a function, for example, do a perldoc [file.pm] 
on a likely looking library, and you should be able to find out if it's there.

=head1 The $S Object

=head2 Methods

=cut

package Scoop;
use strict;
use vars qw( $AUTOLOAD $CACHE );
$AUTOLOAD = undef;

@Scoop::ISA = qw(Class::Singleton);
$Scoop::ASSERT = 0;
my $DEBUG = 0;
my $CACHE_DEBUG = 0;
my $LOG_IP = 0;

# 
# Simply creates a new blessed object in package Scoop.
# This is not called "new" because $S is a Class::Singleton
# See perldoc Class::Singleton for more about that.
#
sub _new_instance {
	my $pkg = shift;
	
	my $class = ref( $pkg ) || $pkg;
	my $self = bless( {}, $class );
	
	return $self;
}


#
# Main init routine. Only called once per run of the code.
# What this mostly does is calles the subroutines below
# to populate various bits of the object. Order is kind
# of important, since some init methods rely on other info
# already being there.
#
sub initialize {
	my $self = shift;
	
	# Set the apache request object 
	$self->_set_apache_request();
	
	# Config stuff
	$self->_set_config();
	
	# Get the request params
	$self->_set_request_params();
	
	# Set up the CGI object
	$self->_set_cgi();
	
	# Get server info
	$self->{SERVER_NAME} = $self->{CONFIG}->{mailname} || $self->apache->hostname();
	
	# Get user IP
	$self->{REMOTE_IP} = $self->_get_remote_ip();
	warn "IP is $self->{REMOTE_IP}\n" if $LOG_IP;
	
	# set referer for easy access
	$self->{REFERER} = $self->apache->headers_in->{'Referer'};
	
	# Import the header_only flag so it can be modified if needed
	$self->{HEADER_ONLY} = $self->apache->header_only;

	# Make the DB object
	$self->_set_dbh();
 	
	# Set this site's cache namespace
	$self->_set_cache();

	# and set up the memcached object
	$self->_set_memcached();
	
	# set the session object
	$self->_set_session();
			
	# Set $S->{UI}->{VARS}
	$self->_set_vars();

	# set the version ifno
	$self->_set_version_info();

	# See who's asking
	$self->_check_user();
	
	# Set user perm hash
	$self->_set_perms();
	
	# User pref definitions
	$self->_set_pref_items();

	# User prefs, at long last!
	$self->_set_prefs();
		warn "  before (Scoop::_update_pref_config) Cache norm_font is $self->cache->{BLOCKS}->{norm_font}\n" if $DEBUG;
	$self->_update_pref_config();
		warn "  after (Scoop::_update_pref_config) Cache norm_font is $self->cache->{BLOCKS}->{norm_font}\n" if $DEBUG;

	# And set the boxes namespace
	$self->_set_boxes();
	
	# Load all boxes
	$self->_load_box_data();

	# Load event property definitions
	$self->_load_event_properties_data();
	$self->_load_calendar_data();
	
#	$self->_check_subscription();
	
	# Hotlist stuff
	$self->{HOTLIST} = $self->get_hotlist();
		
	# Load the ops
	$self->_load_ops();
	
	return $self;
}

sub more_initialize {
	my $self = shift;

	# Set the theme used
	$self->_set_theme();

	# Set $S->{UI}->{BLOCKS}
	$self->_set_blocks();

	# Set $S->{UI}->{MACROS}
	$self->_set_macros();

	# Load topics
	$self->_load_topic_data();
	
	# Load sections
	$self->_load_section_data();
	
	# Load admin tools
	$self->_load_admin_tools();

	# Load hooks
	$self->_load_hooks();

	# Init the HTML checker, or reset it
	$self->_set_html_checker;

	return $self;
}

sub param		{ return $_[0]->{PARAMS}	}
sub error		{ return $_[0]->{ERROR}		}
sub apache		{ return $_[0]->{APACHE}	}
sub cgi 		{ return $_[0]->{CGI} 		}
sub dbh 		{ return $_[0]->{DBH}		}
# for DB module... sigh...
sub db			{ return $_[0]->{DBH}		}
sub auth		{ return $_[0]->{AUTH}		}
sub user		{ return $_[0]->{USER}		}
sub CONFIG		{ return $_[0]->{CONFIG}	}
sub currtheme	 	{ return $_[0]->{THEME}		}
sub cache		{ return $_[0]->{CACHE}		}
sub memcached		{ return $_[0]->{MEMCACHED}	}
sub boxes		{ return $_[0]->{BOXES} 	}
sub handler		{ return $_[0]->{HANDLER}	}
sub html_checker 	{ return $_[0]->{HTML_CHECKER}	}
sub apr          	{ return $_[0]->{APR}		}

sub reset_user {
	my $self = shift;
	delete $self->{SESSION_KEY};
	delete $self->{HOTLIST};
	$self->session->flush;
	$self->{UID} = -1;
	my $user = $self->user_data(-1);
	$self->{USER} = $user;
	# Set group
	$self->{GID} = $user->{'perm_group'};
	
	# Legacy fields. I'll be getting rid of these
	$self->{NICK} = $user->{'nickname'};
	$self->{TRUSTLEV} = $user->{'trustlev'} || 1;
	
	# Reset permissions
	$self->_refresh_group_perms();
	$self->_set_prefs(1);
	$self->_set_vars();
	$self->_set_blocks();
	$self->_set_macros();
	$self->_update_pref_config();

	return $self;
}


sub cleanup {
	my $self = shift;

	$self->session->cleanup;
	$self->dbh->disconnect;
	$self->cache->cleanup;
	# Paranoid cleanup. 
	#delete $self->{prefs};
	#delete $self->{UI}->{VARS};
	#delete $self->{UI}->{BLOCKS};
	#delete $self->{CACHE};
	
	# Super-paranoid cleanup. Try to break circ references...
	foreach my $key (keys %{$self}) {
		delete $self->{$key};
	}
	
	$self = {};
	undef $self;
	return;
}

sub AUTOLOAD {
	my $self = shift;
	my $request = $AUTOLOAD;
	warn "  (Scoop::AUTOLOAD): Trying to fulfill $request from ", ref( $self ), "\n"               if ( $DEBUG );
	$request =~ s/.*://;
	if ( exists $self->{ $request } ) {
		warn "  (Scoop::AUTOLOAD): Fulfilling request because it's a parameter.\n"                   if ( $DEBUG );	
		warn "  (Scoop::AUTOLOAD): Returning data from AUTOLOAD\n"                                   if ( $DEBUG );
	  return $self->{ $request };
	}
	my $error_msg = "Cannot access the method $request via <<" . ref( $self ) .
                 ">> with the parameters " . join ' ', @_;
	warn "  (Scoop::AUTOLOAD): AUTOLOAD Error: $error_msg\n";
	return undef;
}

sub DESTROY {
	my $self = shift;
	warn "<<Another ", ref( $self ), " bites the dust>>\n"	if $DEBUG;
}

=pod

=over 4

=item $S->session
=item $S->session(name,[value])

Provides access to session data. Without arguments, it returns the
Scoop::Session object for this request. Otherwise, it acts as a shortcut method
and compatibility layer. Giving only B<name> is the same as calling
C<$S->session->fetch(B<name>)>. Giving both B<name> and B<value> is the same as
calling C<$S->session->store(B<name>, B<value>)>.

=back

=cut

sub session {
	my $S = shift;
	return $S->{SESSION} unless @_;
	return $_[1] ? $S->{SESSION}->store($_[0], $_[1])
		: $S->{SESSION}->fetch($_[0]);
}

=pod

=over 4

=item $S->page_out()

This routine is called to produce the actual webpage output. It takes no 
arguments and returns a string representing the webpage resulting from the 
user request.

=back

=cut

sub page_out {
	my $S = shift;
	warn "    (Scoop::page_out) Starting page_out\n" if ($DEBUG);

	$S->{FORM} = $S->{UI}->{BLOCKS}->{$S->{CURRENT_TEMPLATE}};
	warn "    (Scoop::page_out) Template = $S->{CURRENT_TEMPLATE}\n" if ($DEBUG);
	
	# See if there are more keys, or if we've rolled through 
	# the max rounds of keyreplace
	my $recurse = $S->{UI}->{VARS}->{template_recurse} || 4;
	my $count = 0;
	my $time = localtime(time());
	warn "    (Scoop::page_out $time) starting keyreplace\n" if ($DEBUG);
	while ($S->{FORM} =~ /%%(.*?)%%/ && $count < $recurse) {
		warn "    (Scoop::page_out) Key round $count\n" if ($DEBUG);
		$S->{FORM} = $S->interpolate($S->{FORM},$S->{UI}->{BLOCKS},{special =>'true'});
		warn "    (Scoop::page_out) Key round $count end\n" if ($DEBUG);
		warn "    (Scoop::page_out) Page is now:\n $S->{FORM}\n\n" if ($DEBUG);
		$count++;
	}
	$S->{FORM} = $S->interpolate($S->{FORM},$S->{UI}->{VARS},{clear => 'true'});
	warn "    (Scoop::page_out $time) done keyreplace\n" if ($DEBUG);

	# do cookie-related things. moved here from ApacheHandler so that boxes can
	# create sessions and have them persist
	$S->_handle_cookies();

    # check the text of the template to see if it starts with an XML declaration
    # and set the content type accordingly (so RDF/RSS files have the right type)
	unless ($S->apache->content_type) {
	    if ( $S->{FORM} =~ /^<\?xml/ && $S->{FORM} !~ /<x?html/) {
			 $S->apache->content_type('text/xml; charset='.($S->{UI}->{VARS}->{charset} || 'ISO-8859-1'));
	    } else {
			$S->apache->content_type('text/html; charset='.($S->{UI}->{VARS}->{charset} || 'ISO-8859-1'));
	    }
	}

	# Everything is dynamic. Prevent proxies from caching it...
	# Set vars/no_cache to enable
	if ($S->{UI}->{VARS}->{no_cache}){
		$S->apache->headers_out->{'Cache-control'} = 'no-cache'; # HTTP 1.1
		$S->apache->headers_out->{'Pragma'} = 'no-cache';        # HTTP 1.0
		$S->apache->no_cache(1);	# Expires Header
	}
	
	unless ($S->{FILTERED}) {
		$S->{APACHE}->headers_out->{'Content-Length'} = length($S->{FORM});
		if ($S->{APACHE}->headers_out->{'Location'}) {
			$S->{APACHE}->headers_out->{'Content-Length'} = 0; # Required by IE for some reason
			$S->{APACHE}->status(301) if ($S->{APACHE}->status == 200);
			$S->{HEADER_ONLY} = 1;	# Avoid sending content
		}
		$S->{APACHE}->send_http_header unless $Scoop::MP2;
		return if $S->{HEADER_ONLY};   # we're done

		my $start = 0;
		my $len = 63000;
		while (my $p = substr($S->{'FORM'}, $start, $len)) {
			$start += $len;
			warn "  (Scoop::page_out) Start Printing response page\n" if $DEBUG;
			$S->{APACHE}->print($p);
			warn "  (Scoop::page_out) Done Printing response page\n" if $DEBUG;
		}
		$S->{APACHE}->rflush();
	} else {
		print $S->{FORM};
	}

	return;
}

=pod

=over 4

=item $S->interpolate(<template>, <key replacement hashref>, <options hashref>)

This method does the actual work of key replacement. It performs regex 
replacement of the keys found in the key replacement hash, for the values in 
that hash.

There are two options currently recognized, 'special' and 'clear'.

$output = $S->interpolate($template,$replacementHash,{special=>'true'})

causes special keys to be parsed. Currently the only special key is 'BOX'.
The 'clear' option should only be used once in the last interpolate() call.
It causes all unmatched keys to be deleted from the template.

=back

=cut

sub interpolate {
	my $S        = shift; #Duh
	my $template = shift || ''; # Interpolation target
	my $data     = shift; # Hash containing keys for replacement
	my $flags    = shift; # Hash containing other args

	my $special_keys = { "BOX" => 'Scoop::box_magic' };
	$template =~ s/__box__/BOX,/g;    # backward compatibility

	my $return   = $template; # have to make changes to a copy 
				  # to avoid infinite loops

	if ($flags->{special}) {
		my $keys_re = '(?:' . join('|', keys %{$special_keys}) . ')';
		while ($template =~ /%%($keys_re.*?)%%/og) {
			my $fullkey = $1;
			warn "Fullkey is $fullkey\n" if ($DEBUG);

			my @args;
			while ($fullkey =~ /\s*(?:(?:(['"])(.*?)(?:(?<!\\)\1))|(?:([^,]+)))\s*(?:,|$)/g) {
				my $item = $2 || $3;
				$item =~ s/\\([\\'"%])/$1/g;
				push(@args, $item);
			}
			my $func = shift @args;

			# Bail unless we got a function along with the key
			unless ($args[0] && defined($special_keys->{$func})) {
				$return =~ s/%%$fullkey%%//;
				warn "Special key <<$fullkey>> called, but not found. Clearing key.\n";
				next;
			}

			my $replace;
			{
				no strict 'refs';
				$replace = &{$special_keys->{$func}}($S, @args); # || warn "\tCan't find &{$special_keys->{$func}}\n";
			}

			if ($DEBUG) {
				#warn "Replacement box text is: <<$replace>>\n";
				warn "Key ($fullkey) not found!\n" unless ($return =~ /%%$fullkey%%/);
			}

			$return =~ s/%%$fullkey%%/$replace/g;
		}
	} # end $flags->{special} test

	while ($template =~ /%%(.*?)%%/go) {
		my $key = $1;
		if ( exists $data->{$key} ) {
			warn "Replacing key $key" if ($DEBUG);
			$return =~ s/%%$key%%/$data->{$key}/ge;
#		} elsif ( $flags->{clear} ) {
#			$return =~ s/%%$key%%//g;
		}
	}

	if ($flags->{clear}) {
		warn "Clearing extra keys\n" if $DEBUG;
		$return =~ s/%%.*?%%//g;
	}

	return $return;
}

# This is a simple function to parse the VERSION file and populate
# a few environment vars with some useful info
sub _set_version_info {
	my $self = shift;
	
	# set a sane default, so we can know if there is an error
	$self->{UI}->{VARS}->{SCOOP_VERSION}	= $self->CONFIG->{scoop_version} || 'Undeterminable';
	$self->{UI}->{VARS}->{SCOOP_DATE}	= $self->CONFIG->{scoop_date};
	$self->{UI}->{VARS}->{SCOOP_REVISION}   = $self->CONFIG->{scoop_revision};
	$self->{UI}->{VARS}->{SCOOP_AUTHOR}	= $self->CONFIG->{scoop_author};
	$self->{UI}->{VARS}->{SCOOP_STATE}	= $self->CONFIG->{scoop_state};
	
	# clean them up a bit
	$self->{UI}->{VARS}->{SCOOP_DATE}	=~ s/\$Date: //;
	$self->{UI}->{VARS}->{SCOOP_DATE}	=~ s/\$$//;
	$self->{UI}->{VARS}->{SCOOP_REVISION}	=~ s/\$Revision: //;
	$self->{UI}->{VARS}->{SCOOP_REVISION}	=~ s/\$$//;
	$self->{UI}->{VARS}->{SCOOP_AUTHOR}	=~ s/\$Author: //;
	$self->{UI}->{VARS}->{SCOOP_AUTHOR}	=~ s/\$$//;
	$self->{UI}->{VARS}->{SCOOP_STATE}	=~ s/\$State: //;
	$self->{UI}->{VARS}->{SCOOP_STATE}	=~ s/\$$//;
	
	warn qq/
			version: $self->{UI}->{VARS}->{SCOOP_VERSION}
			date: $self->{UI}->{VARS}->{SCOOP_DATE}
			revision: $self->{UI}->{VARS}->{SCOOP_REVISION}
			last modification by: $self->{UI}->{VARS}->{SCOOP_AUTHOR}
			state: $self->{UI}->{VARS}->{SCOOP_STATE}\n/ if $DEBUG;
}

sub _set_pref_items {
	my $self = shift;

	if (my $cached = $self->cache->fetch_data({resource => 'pref_items',
							element => 'PREF_ITEMS'})) {
		$self->{PREF_ITEMS} = $cached;
		return $self;
	}

	warn "Reloading pref cache.\n" if $CACHE_DEBUG;
	# get all the pref data
	my ($rv, $sth) = $self->db_select({
		WHAT => '*',
		FROM => 'pref_items'});

	# stick it in $self
	while (my $pref = $sth->fetchrow_hashref()) {
		$self->{PREF_ITEMS}->{$pref->{prefname}} = $pref;
	}

        # And also update the cache
	$self->cache->cache_data({resource => 'pref_items',
				element => 'PREF_ITEMS',
				data => $self->{PREF_ITEMS}});

	return $self;
}

sub _set_boxes {
	my $self = shift;
	#my $rootdir = $self->{UI}->{VARS}->{rootdir} || 'noroot';
	#my $server = $self->{SERVER_NAME} || 'noserv';
	
	$self->{BOXES} = 'Scoop::BOXES::'.$self->{CONFIG}->{site_id};
	return;
}

sub _load_box_data {
	my $self = shift;
	my $time = time();
	
	if (my $cached = $self->cache->fetch_data({resource => "boxes", 
		                                        element => 'BOXES'})) {
		$self->{BOX_DATA} = $cached;
		return $self;
	}

	warn "Reloading Box cache.\n" if $CACHE_DEBUG;	
	# Get all the box data
	my ($rv, $sth) = $self->db_select({
		WHAT => '*',
		FROM => 'box'});

	# stick it in $self
	while (my $box = $sth->fetchrow_hashref()) {
		$self->{BOX_DATA}->{$box->{boxid}} = $box;
	}

	# And also update the cache
	$self->cache->store("boxes", $self->{BOX_DATA}, '+30m');
							  		
	# Now do a compile on all the boxes. Whee.
	foreach my $box (keys %{$self->{BOX_DATA}}) {
		$self->_load_box($self->{BOX_DATA}->{$box});
	}
	
	return $self;
	
}


sub _load_event_properties_data {
	my $self = shift;
	my $time = time();

	if (my $cached = $self->cache->fetch('events')) {
		$self->{EVENT_PROPERTIES} = $cached;
		warn "(_load_event_properties_data) getting from cache" if $DEBUG;
		return $self;
	}

	warn "Reloading event properties cache.\n" if $CACHE_DEBUG;	
	# Get all the event properties data
	my ($rv, $sth) = $self->db_select({
		WHAT => '*',
		FROM => 'event_property_items'});

	# stick it in $self
	while (my $prop = $sth->fetchrow_hashref()) {
		$self->{EVENT_PROPERTIES}->{$prop->{property}} = $prop;
	}
	warn "(_load_event_properties_data) getting from db" if $DEBUG;

	# And also update the cache
	$self->cache->cache_data({resource => 'events', 
		                  element => 'EVENTS', 
				  data => $self->{EVENT_PROPERTIES}});
							  		
	return $self;
	
}

sub _load_calendar_data {
	my $self = shift;
	my $time = time();

	if ( my $cached = $self->cache->fetch('calendars') ) {
		$self->{CALENDARS} = $cached;
		warn "(_load_calendar_data) getting from cache" if $DEBUG;
		return $self;
	}

	warn "Reloading calendar cache." if $CACHE_DEBUG;
	my ($rv,$sth) = $self->db_select({
		WHAT => '*',
		FROM => 'calendars'});

	$self->{CALENDARS} = $sth->fetchall_hashref('cal_id');
	warn "(_load_calendar_data) got all calendars from db" if $DEBUG;
	# update the cache
	$self->cache->store('calendars', $self->{CALENDARS});

	return $self;
}

sub _load_topic_data {
	my $self = shift;
	my $time = time();
	
	if (my $cached = $self->cache->fetch_data({resource => 'topics', 
		                                   element => 'TOPICS'})) {
		$self->{TOPIC_DATA} = $cached;
		return $self;
	}

	warn "Reloading Topic cache.\n" if $CACHE_DEBUG;	
	
	my ($rv, $sth) = $self->db_select({
		WHAT => '*',
		FROM => 'topics'});
	
	while (my $topic = $sth->fetchrow_hashref()) {
		$self->{TOPIC_DATA}->{$topic->{tid}} = $topic;
	}

	# And also update the cache
	$self->cache->cache_data({resource => 'topics', 
		element => 'TOPICS', data => $self->{TOPIC_DATA}});

	return $self;
}

sub _load_section_data {
	my $self = shift;
	my $time = time();

	if (my $cached = $self->cache->fetch_data({resource => 'sections', 
			element => 'SECTIONS'})) {
		$self->{SECTION_DATA} = $cached;
		return $self;
	}

	warn "Reloading Section cache.\n" if $CACHE_DEBUG;	
	
	my ($rv, $sth) = $self->db_select({
		WHAT => '*',
		FROM => 'sections'});
	
	while (my $section = $sth->fetchrow_hashref()) {
		$self->{SECTION_DATA}->{$section->{section}} = $section;
	}

	$sth->finish;
	
	my ($rv2, $sth2) = $self->db_select({
		WHAT => '*',
		FROM => 'subsections'});

	while (my $subsect = $sth2->fetchrow_hashref()) {
		$self->{SECTION_DATA}->{$subsect->{section}}->{children}->{$subsect->{child}}->{invisible} = $subsect->{invisible};
		$self->{SECTION_DATA}->{$subsect->{child}}->{parents}->{$subsect->{section}}->{invisible} = $subsect->{invisible};
		$self->{SECTION_DATA}->{$subsect->{section}}->{children}->{$subsect->{child}}->{inheritable} = $subsect->{inheritable};
		$self->{SECTION_DATA}->{$subsect->{child}}->{parents}->{$subsect->{section}}->{inheritable} = $subsect->{inheritable};
	}

	$sth2->finish;

	# And also update the cache
	$self->cache->cache_data({resource => 'sections', 
		element => 'SECTIONS', data => $self->{SECTION_DATA}});
		
	return $self;
}

sub _load_admin_tools {
	my $self = shift;
	my $time = time();

	if (my $cached = $self->cache->fetch_data({resource => 'admin_tools',
	                                           element  => 'ADMIN_TOOLS'})) {
		$self->{ADMIN_TOOLS} = $cached;
		return $self;
	}

	warn "Reloading admin tools cache.\n" if $CACHE_DEBUG;

	my ($rv, $sth) = $self->db_select({
		WHAT => '*',
		FROM => 'admin_tools'
	});

	while (my $tool = $sth->fetchrow_hashref()) {
		$self->{ADMIN_TOOLS}->{ $tool->{tool} } = $tool;
	}
	$sth->finish;

	$self->cache->cache_data({resource => 'admin_tools',
	                          element  => 'ADMIN_TOOLS',
							  data     => $self->{ADMIN_TOOLS}});
	
	return $self;
}

sub _load_ops {
	my $self = shift;
	my $time = time();

	if (my $cached = $self->cache->fetch_data({resource => 'ops',
	                                           element  => 'OPS'})) {
		$self->{OPS} = $cached;
		return $self;
	}

	warn "Reloading ops cache.\n" if $CACHE_DEBUG;

	my ($rv, $sth) = $self->db_select({
		WHAT => '*',
		FROM => 'ops'
	});

	while (my $op = $sth->fetchrow_hashref()) {
		$self->{OPS}->{ $op->{op} } = $op;
		my @aliases = split(/[\s,]+/, $op->{aliases});
		for (@aliases) {
			$self->{OPS}->{ $_ } = $self->{OPS}->{ $op->{op} };
		}
	}
	$sth->finish;

	$self->cache->cache_data({resource => 'ops',
	                          element  => 'OPS',
	                          data     => $self->{OPS}});

	return $self;
}

sub _load_hooks {
	my $self = shift;

	if (my $cached = $self->cache->fetch('hooks')) {
		$self->{HOOKS} = $cached;
		return $self;
	}

	warn "Reloading hooks cache.\n" if $CACHE_DEBUG;

	my ($rv, $sth) = $self->db_select({
		WHAT => '*',
		FROM => 'hooks'
	});

	$self->{HOOKS} = {};
	while (my $hook = $sth->fetchrow_hashref()) {
		unless (exists $self->{HOOKS}->{ $hook->{hook} }) {
			$self->{HOOKS}->{ $hook->{hook} } = [];
		}
		push @{ $self->{HOOKS}->{ $hook->{hook} } }, $hook;
	}
	$sth->finish;

	$self->cache->store('hooks', $self->{HOOKS});

	return $self;
}

##########################################
# END OF PUBLIC FUNCTIONS
##########################################

=pod

=head2 Properties


=over 4

=item * $S->{SERVER_NAME}

This holds the name of the current server. Usually it will be whatever 
the vhost of apache was set to. 

=item * $S->{REMOTE_IP}

The IP of the client machine (the user accessing this page).

=item * $S->{REFERER}

The refering document. Stored here for easy access later.

=item * $S->{HEADER_ONLY}

The HEADER_ONLY flag will always have an itintial value of '0' 
unless the HTTP request method is HEAD, in which case it will
have a value of '1'. It is exported from the Apache object so
it can be altered based on certainonditions such as use of
'Location' headers to redirect the client (in which case it's
undesirable to output anything other than the headers. In this 
special case, the flag is set to 1, and if the return code is
200, it's automatically chaged to 301. Any oter return code
will stand as set regardless of the presence of a location tag.

=item * $S->{APACHE}

A pass-through to the mod_perl apache request object (known in the mod_perl 
docs as $r, usually). See perldoc Apache for more on this.

=cut
sub _set_apache_request {
	my $self = shift;
	my $r = Apache->request();
	
	# set {APACHE} to the request obj
	$self->{APACHE} = $r;
	return $self;
}

=pod

=item * $S->{PARAMS}

A hash reference containing all GET or POST arguments passed in this request. 
This should not be accessed directly, but through the $S->param() method. 
But here's where param() gets it's answers from.

=cut
sub _set_request_params {
	my $self = shift;

	use Apache::Request;
	my $q = Apache::Request->new( $self->{APACHE} );
	$self->{APR} = $q;

	my $all_args = {};
	foreach my $key ($q->param()) {
		my @tmp = $q->param($key);

		if( $#tmp > 0 ) {   # must be an array
			$all_args->{$key} = \@tmp;
		} else {
			$all_args->{$key} = $tmp[0];
		}
	}

	if ($DEBUG) {
		my $warn;
		foreach my $key (keys %{$all_args}) {
			my $v = $all_args->{$key};
			$v = join(" - ", @{$v}) if ref($v);
			$warn .= "\t$key => $v\n";
		}
		warn "  (Scoop::_set_request_params): Request params are: \n$warn";
	}

	$self->{PARAMS} = $all_args;
	
	return $self;
}

=pod

=item * $S->{CONFIG}

All that stuff in the httpd.conf? Here's where it ends up. This is another 
simple pass-through to the return value of Apache dir_config(). Generally 
it will be a hashref with simple key/value pairs.

=cut
sub _set_config {
	my $self = shift;
	warn "  (Scoop::_set_config) Setting config object...\n" if ($DEBUG);
	my $dir_config = $self->apache->dir_config();
	
	$self->{CONFIG} = $dir_config;
	
	warn "  (Scoop::_set_config) done.\n" if ($DEBUG);
	return $self;
}

=pod

=item * $S->{CGI}

A pass-through to a Scoop::CGI object. This used to be a normal CGI object, 
until I realized that I was trading a meg of memory per httpd for about three 
of the methods of CGI. So I wrote a quick drop-in replacement for the bits 
of CGI I did use. Look at perldoc Scoop::CGI for more info. Oh yeah, you 
probably won't need to touch this directly too-- everything useful it does 
through methods.

=cut
sub _set_cgi {
	my $self = shift;
	my $cgi = new Scoop::CGI;
	$self->{CGI} = $cgi;
	warn "  (Scoop::_set_cgi) done.\n" if ($DEBUG);
	return $self;
}

=pod

=item * $S->_get_remote_ip

This checks whether we have a proxy in front of us, which is fairly common 
to mod_perl. Either way, it returns the real remote client IP. 

=cut

sub _get_remote_ip {
	my $self = shift;

	# we'll only look at the X-Forwarded-For header if the requests
    # comes from our proxy at localhost
    return $self->apache->connection->remote_ip() 
		unless ($self->apache->headers_in->{'X-Forwarded-For'});
	
	# Select last value in the chain -- original client's ip
	if (my ($ip) = $self->apache->headers_in->{'X-Forwarded-For'} =~ /([^,\s]+)$/) {
		return $ip;
	}	
	warn "  (Scoop::_get_remote_ip) done.\n" if ($DEBUG);
	# If that failed. Eek! Return whatever we have.
	return $self->apache->connection->remote_ip()
}

=pod 

=item * $S->{DBH}

A pass-through to a normal DBI database handle object. This is especially 
useful in quoting data, which is as easy as $S->{DBH}->quote($foo)

=cut
sub _set_dbh {
	my $self = shift;
	
	my $dbname  	= $self->CONFIG->{db_name};
	my $username 	= $self->CONFIG->{db_user};
	my $password  	= $self->CONFIG->{db_pass};
	my $dbhost  	= $self->CONFIG->{db_host};
	my $dbtype	= $self->CONFIG->{DBType};

	# need to lowercaseify for MySQL, but not Pg
	$dbtype = "mysql" if(lc($dbtype) eq "mysql"); 
	
	# Set the DB connection. Should use persistent connections via Apache::DBI
	my $data_source = "DBI:$dbtype:dbname=$dbname;host=$dbhost";
	my $zzz;
	my $dbh = DBI->connect($data_source, $username, $password) ||
		warn "  (Scoop::_set_dbh) Can't connect to database! $@\n", $zzz++;
	if($zzz){
		# If you've upgraded your Scoop install and down have
		# 'PerlSetVar dbdown_page <page to redirect to> in there
		# somewhere, add it to have Scoop redirect to a page letting
		# people now that the db is down rather than giving a generic
		# ISE page. if 'dbdown_page' is not set, it will just return
		# and give you the usual ISE.
		return unless $self->{CONFIG}->{dbdown_page};
		$self->{APACHE}->headers_out->{'Location'} = $self->{CONFIG}->{dbdown_page};
		$self->{APACHE}->status(302);
		$self->{HEADER_ONLY} = 1;
		$self->{APACHE}->send_http_header;
		undef $Scoop::_instance;
		exit; 
		}
	# Make it part of the object
	$self->{DBH} = $dbh;
	
	warn "  (Scoop::_set_dbh) done.\n" if ($DEBUG);
	
	$dbname  	= $self->CONFIG->{db_name_archive};
	$username 	= $self->CONFIG->{db_user_archive};
	$password  	= $self->CONFIG->{db_pass_archive};
	$dbhost  	= $self->CONFIG->{db_host_archive};

	if ($dbhost) {
		$data_source = "DBI:$dbtype:dbname=$dbname;host=$dbhost";
	
		$dbh = DBI->connect($data_source, $username, $password) ||
			warn "  (Scoop::_set_dbh) Can't connect to archive database! $@\n";
		# Make it part of the object
		$self->{DBHARCHIVE} = $dbh;
		$self->{HAVE_ARCHIVE} = 1;
	} else {
		$self->{HAVE_ARCHIVE} = 0;
	}
        # That's not funny. I was a slave!
        $dbname         = $self->CONFIG->{db_name_slave};
        $username       = $self->CONFIG->{db_user_slave};
        $password       = $self->CONFIG->{db_pass_slave};
        $dbhost         = $self->CONFIG->{db_host_slave};
        if($dbhost){
                my @slaves = split /,/, $dbhost;
                for (my $s = 0; $s <= $#slaves; $s++){
                        $data_source = "DBI:$dbtype:dbname=$dbname;host=$slaves[$s]";
                        $dbh = DBI->connect($data_source, $username, $password)
||
                        warn "  (Scoop::_set_dbh) Can't connect to slave database! $@\n";
                        $self->{SLAVEDB}->[$s] = $dbh;
                        warn "connect to slave SLAVEDB $s\n";
                        }
                $self->{HAVE_SLAVE} = 1;
                $self->{NUMSLAVES} = $#slaves + 1;
                }
        else {
                $self->{HAVE_SLAVE} = 0;
                }
	# And set up the archive db slaves as well, if we decide we want some.
	$dbname         = $self->CONFIG->{db_name_slave_arch};
        $username       = $self->CONFIG->{db_user_slave_arch};
        $password       = $self->CONFIG->{db_pass_slave_arch};
        $dbhost         = $self->CONFIG->{db_host_slave_arch};
        if($dbhost){
                my @slaves = split /,/, $dbhost;
                for (my $s = 0; $s <= $#slaves; $s++){
                        $data_source = "DBI:$dbtype:dbname=$dbname;host=$slaves[$s]";
                        $dbh = DBI->connect($data_source, $username, $password)
||
                        warn "  (Scoop::_set_dbh) Can't connect to slave database! $@\n";
                        $self->{SLAVEARCHDB}->[$s] = $dbh;
                        warn "connect to slave SLAVEARCHDB $s\n";
                        }
                $self->{HAVE_SLAVE_ARCHIVE} = 1;
                $self->{NUMARCHSLAVES} = $#slaves + 1;
                }
        else {
                $self->{HAVE_SLAVE_ARCHIVE} = 0;
                }


	return $self;
}

=pod

=item * $S->{SESSION}

This holds the user session object. Don't use this member directly. 
Access it through the $S->session() method.

=item * $S->{SESSION_KEY}

The unique identifier for the current user session. See perldoc Apache::Session 
for more on how all that works. You probably won't need this, ever.

=cut
sub _set_session {
	my $self = shift;

	#See if there's a session cookie
	my $cookie = $self->apache->headers_in->{'Cookie'};

	my $cookie_jar = $self->_get_cookies($cookie);
	$self->{COOKIES} = $cookie_jar;   # tuck this away, just in case we need it

	warn "  (Scoop::_set_session) Got cookie: $cookie, session is $cookie_jar->{session}\n"	if $DEBUG;
	my $cookie_name = "$self->{CONFIG}->{site_id}_session";
	$self->{SESSION_KEY} = $cookie_jar->{$cookie_name} ||  undef;
	$self->{GOT_COOKIE} = 1 if ($self->{SESSION_KEY});

	# create the object now. if we get a session id, then we'll tell the object
	# about it later
	$self->{SESSION} = Scoop::Session->new(scoop => $self);

	# Bail unless we got a session ID. 
	unless ($self->{GOT_COOKIE}) {
		warn "	(Scoop::_set_session) No cookie provided. Holding off on session until we definitely need it.\n" if ($DEBUG);
		return $self;
	}

	# attach the existing session to the session object. if it fails, then the
	# session key is invalid and we need to expire the cookie that gave us a
	# bad key
	unless ($self->{SESSION}->session_id($self->{SESSION_KEY})) {
		$self->{EXPIRE_SESSION} = 1;
	}

	return $self;
}

=pod

=item * $S->{UI}

This is the top-level container for all those nifty vars and blocks. It is 
a hashref with two parts; $S->{UI}->{VARS} and $S->{UI}->{BLOCKS}. See below 
for more on each.

=item * $S->{UI}->{VARS}

This holds all the things that appear in the "Vars" web interface. To get 
the value of var 'foo', just look in $S->{UI}->{VARS}->{foo}. Simple as that. 
Generally if you want something to be user-configurable, this is the best way 
to do it-- create a new default Var, and then use that in your code.

=item * $S->{UI}->{BLOCKS}

This, like VARS, is where the Blocks are found. Same as above. If you're adding 
code that could use a longer chunk of configurable HTML, add a Block and use it 
with $S->{UI}->{BLOCKS}->{bar}.

=item * $S->{UI}->{MACROS}

Same for macros; we just put them in their own section to avoid crowding
the blocks and vars areas.

=cut
sub _set_vars {
	my $S = shift;
	$S->{UI} = {};

	my %vars = $S->get_vars();
	$S->{UI}->{VARS} = \%vars;

	# Make sure the post thresholds are processed right
	$S->_refresh_thresholds();
}

sub _set_macros {
	my $S = shift;

	my %macros = $S->get_macros();
	$S->{UI}->{MACROS} = \%macros;

}

sub _set_blocks {
	my $S = shift;

	my %blocks = $S->get_themed_blocks();
	$S->{UI}->{BLOCKS} = \%blocks;
	
	# Update prefs to override themed blocks
	$S->_update_pref_config();
}

sub _set_theme {
	my $S = shift;

	if ($S->{UI}->{VARS}->{use_themes}) {
		my $sec = $S->param->{"section"};
		my $sid = $S->param->{"sid"};
		warn qq|params: param->("section") is $sec\n| if $DEBUG;
		warn qq|params: param->("sid") is $sid\n| if $DEBUG;
		$S->{THEME} = $S->run_box("theme_chooser");
		# the box should return a string of comma-separated theme names, 
		# in order from base theme to specific
	} else {
		# if themes aren't enabled, don't bother calling the box, as it will
		# just add overhead
		$S->{THEME} = $S->{UI}->{VARS}->{default_theme};
	}
	warn "Theme has been set to $S->{THEME}" if $DEBUG;
}

sub _check_user {
	my $self = shift;
	
	# See if we got login data w/the request
	my $uid = $self->check_for_login();
	
	# If we did, then this'll be a real uid (greater than 0)
	if ($uid > 0) {
		warn "  (Scoop::_check_user) Found user from login: $uid. Setting session."	if $DEBUG;
		$self->session('UID', $uid);
		warn "Session ".$self->session->session_id.", UID ".$self->session('UID')	if $DEBUG;
		# Set the uid
		$self->{UID} = $uid;
	} else {
		warn "  (Scoop::_check_user) No user login, looking for session uid"	if $DEBUG;
		$uid = $self->session('UID');
		if ($uid) { 
			#$self->session('UID', $uid);
			# Set the uid
			$self->{UID} = $uid;
			warn "  (Scoop::_check_user) User is ".$self->session('UID')	if $DEBUG;
		} else {
			$uid = -1; 
			# Set the uid
			$self->{UID} = $uid;
			warn "  (Scoop::_check_user) No session uid found. Using -1."	if $DEBUG; 
		}
	}
	
	
	# Get the data about this user
	warn "  (Scoop::_check_user) Getting user data for user $uid"	if $DEBUG;
	
	my $user = $self->user_data($uid);
	#unless ($user) { warn "Error! Nothing returned from Scoop::User"	if $DEBUG;}
	
	# Set user group id
	$self->{GID} = $user->{'perm_group'};
	#warn "  GID is <<$self->{GID}>>\n";

	# Set trust level for mojo
	$self->{TRUSTLEV} = $user->{'trustlev'} || 1;
	
	# Legacy fields. I'll be getting rid of these
	$self->{NICK} = $user->{'nickname'};

	# Set the stuff for who's online.
	if($self->{UI}->{VARS}->{'use_whosonline'}){
                $self->_insert_whos_online($self->{REMOTE_IP}, $self->{UID});
		}
	return $self;
}

sub _set_perms {
	my $self = shift;
	
	$self->{PERMS} = $self->group_perms($self->{GID});
	$self->{SECTION_PERMS} = $self->group_section_perms( $self->{GID} );
	
	return $self;
}

sub _set_prefs {
	my $self = shift;
	my $force = shift;
	return unless ($self->{UID} && ($self->{UID} > 0));
	
	warn "  (Scoop::_set_prefs) Before setting prefs!\n" if ($DEBUG);

	delete $self->{prefs};
	if ($force) {
		delete($self->{USER_DATA_CACHE}->{$self->{UID}});
	}
	
	unless ($self->{USER_DATA_CACHE}->{$self->{UID}}) {
		$self->user_data($self->{UID});
	}
	
	$self->{prefs} = $self->{USER_DATA_CACHE}->{$self->{UID}}->{prefs};
	
	$self->{TRUSTLEV} = '2' if ( $self->have_perm('super_mojo') );
	
	return $self;
}

### shouldn't this check the subscriptions table, not the userprefs?
##sub _check_subscription {
##	my $self = shift;
##	# Do we even use subscriptions?
##	return unless ($self->{UI}->{VARS}->{use_subscriptions});
##	# Is this user a subscriber?
##	return unless ($self->{prefs}->{subscriber} == 1);
##	# Is the subscription expired?
##	return unless ($self->{prefs}->{subscription_expire} < time);
##	
##	# Hmmm. Seems to be buggy. If we get here, check for absolutely sure
##	my $time = time;
##	my ($rv, $sth) = $self->db_select({
##		WHAT => 'prefvalue',
##		FROM => 'userprefs',
##		WHERE => "uid = $self->{UID} AND prefname = 'subscription_expire'"
##	});
##	my $exp = $sth->fetchrow();
##	$sth->finish();
##	
##	return unless ($exp < $time);
##	
##	# If we get here, then the subscription is expired. Remove it
##	# from their prefs.
##	($rv, $sth) = $self->db_delete({
##		FROM  => 'userprefs',
##		WHERE => "uid = $self->{UID} AND (prefname = 'subscriber' OR prefname = 'subscription_expire' OR prefname = 'showad')"
##	});
##	
##	# and reset the prefs
##	$self->_set_prefs(1);
##}
	
sub _set_cache {
	my $self = shift;

	my $cache = Scoop::Cache->new($self);
	$self->{CACHE} = $cache;
	
	return;
}

sub _set_memcached {
	my $self = shift;
	return '' if !$self->{CONFIG}->{memcached_servers};
	my $memserv = $self->{CONFIG}->{memcached_servers};
	my $memcomp = $self->{CONFIG}->{memcached_compress};
	my @memarr = split /,/, $memserv;
	
	my $memd = new Cache::Memcached;
	$memd->set_servers(\@memarr);
	$memd->set_compress_threshold($memcomp);
	$self->{MEMCACHED} = $memd;
	return;
	}

sub _set_html_checker {
	my $self = shift;

	if ($self->{HTML_CHECKER}) {
		$self->{HTML_CHECKER}->reset();
	} else {
		my $checker = Scoop::HTML::Checker->new($self);
		$self->{HTML_CHECKER} = $checker;
	}

	return;
}

sub _update_pref_config {
	my $self = shift;
	
#	return unless ($self->{UID} && ($self->{UID} > 0) && $self->{prefs});

	
	# Reset a bunch of stuff w/user prefs or the pref defaults
	$self->{UI}->{BLOCKS}->{norm_font_size} = $self->pref('norm_font_size');
	$self->{UI}->{BLOCKS}->{norm_font_face} = $self->pref('norm_font_face');
	$self->{UI}->{BLOCKS}->{maxstories} = $self->pref('maxstories');
	$self->{UI}->{BLOCKS}->{maxtitles} = $self->pref('maxtitles');
	$self->{UI}->{BLOCKS}->{imagedir} = $self->pref('imagedir');
	$self->{UI}->{BLOCKS}->{textarea_rows} = $self->pref('textarea_rows');
	$self->{UI}->{BLOCKS}->{textarea_cols} = $self->pref('textarea_cols');
	
#	warn "  (Scoop::_update_pref_config) Cache norm_font is $self->cache->{DATA}->{BLOCKS}->{norm_font}\n" if $DEBUG;
	return;
}

	
##############################
# Looks for "uname" and "pass" form elements, and 
# calls $S->check_password to see if they're valid.
# Returns the $uid of a confirmed user, or '0' if no
# user is found, for whatever reason
##############################
sub check_for_login {
	my $S = shift;
	my $uname = $S->{CGI}->param('uname') || undef;
	my $pass = $S->{CGI}->param('pass') || undef;
	my $mail = $S->{CGI}->param('mailpass') || undef;
	my $uid = 0;
	my $message = '';

	my $login_err;
	my $login_mail;
	my $login_mail_fail;

	# Blocks aren't loaded yet!
	my ($rv, $sth) = $S->db_select({
				WHAT => 'bid, block',
				FROM => 'blocks',
				WHERE => "bid='login_error_message' OR bid='login_mail_message' OR bid='login_mail_failed'"});
	while (my $results = $sth->fetchrow_hashref) {
		if ( $results->{bid} eq "login_error_message" ) {
			$login_err = $results->{block};
		} elsif ( $results->{bid} eq "login_mail_message" ) {
			$login_mail = $results->{block};
		} elsif ( $results->{bid} eq "login_mail_failed" ) {
			$login_mail_fail = $results->{block};
		} else {
			warn "got a bid I wasn't expecting..." if $DEBUG;
		}
	}

	# Mail password, but no username?
	if (!$uname && $mail) {
		$message = $login_err;
	}
	
	# No password?
	if (($uname && !$pass) && !$mail) {
		$message = $login_err;
	}

	# Only a password? 
	if ((!$uname && $pass) && !$mail) {
		$message = $login_err;
	}		

	# Standard case
	if (($uname && $pass) && !$mail) {
		$uid = $S->check_password($uname, $pass);
		unless ($uid) {

			$message = $login_err;

			if ($S->{DEBUG}->{LOGIN}) {warn "  (Scoop::check_for_login) UID came back $uid. That's all I can do.";}
		}
	}

	# Show the preferences if the user logs in for the first time
	# and the respective var is set. 	
	# Set is_new_account=0 if it was previously 1.
	if($uid) {				
		my $user=$S->user_data($uid);
		if ($user->{is_new_account}) {
			# Run user_confirm hook
			$S->run_hook('user_confirm', $user->{nickname});
			
			if($S->{UI}->{VARS}->{show_prefs_on_first_login}) {
				
				warn "  (Scoop::check_for_login) First login for user ID <<$uid>>, showing preferences page\n" if ($DEBUG);							
				$S->param->{'op'}="user";
				$S->param->{'tool'}="prefs";
				$S->param->{'uid'}=$uid;
				$S->param->{'nick'}=$user->{nickname};
				# this is passed to the prefs page so it can display a welcome message
				$S->param->{'firstlogin'}="1";
			}
			warn "  (Scoop::check_for_login) First login for user ID <<$uid>>, setting is_new_account=0\n" if ($DEBUG);
			my ($rv, $sth) = $S->db_update({
			 WHAT  => "users",
			 SET   => qq|is_new_account = 0|,
			 WHERE => "uid = $uid"});
			$sth->finish();
		
		}
		
	}	


	# User clicked "Mail password":
	# Send new password to user. Both passwords will be valid until
	# new one is set.	
	if ($uname && $mail) {
		my $mailed = $S->_mailpass($uname);
		if ($mailed) {
			$message = $login_mail;
		} else {

			$message = $login_mail_fail;
		}
	}
	$message =~ s/%%uname%%/$uname/g;
	$S->{LOGIN_ERROR} = $message;
	
	return $uid;
}


##############################
# Takes a username and a password and checks the users
# DB for them. If found, it returns the uid. Otherwise
# It returns '0'.
##############################
sub check_password {
	my $S = shift;
	my ($uname, $pass) = @_;

	#crypt the passwd received
	my $c_pass = $S->crypt_pass($pass);
	warn "  (Scoop::check_password) Crypted pass is: $c_pass\n"	if ($DEBUG);
	
	my $q_cpass = $S->{DBH}->quote($c_pass);
	my $q_uname = $S->{DBH}->quote($uname);
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'uid',
		FROM => 'users',
		WHERE => qq|nickname = $q_uname AND passwd = $q_cpass|});
		
	if ($rv != 1) {
		$sth->finish;
		
		# check if user logged in using new password, and if he did,
		# reset the password.
		
		($rv, $sth) = $S->db_select({
			WHAT => 'uid',
			FROM => 'users',
			WHERE => qq|nickname = $q_uname AND newpasswd = $q_cpass and is_new_account = 0|
		});
		if ($rv !=1) {
			$sth->finish;
			warn "  (Scoop::check_password) Login ERROR: incorrect password for $uname."	if $DEBUG;
			return 0;
		} else {
			my ($rv2, $sth2) = $S->db_update({
				WHAT => 'users',
				SET => qq|newpasswd="",passwd=$q_cpass|,
				WHERE => qq|nickname = $q_uname AND newpasswd = $q_cpass|
			});
			$sth2->finish;
		}
			
	}
	
	warn "  (Scoop::check_password) Login SUCCESS: Valid password for $uname."	if $DEBUG;
	my $uidref = $sth->fetchrow_hashref();
	$sth->finish;
	my $uid = $uidref->{'uid'};
	return $uid;
}

##############################
# Simple password encryption scheme. Takes a word, 
# perl crypt()'s it with itself, and cuts off the first 2 
# characters, which will be the salt-- that is, the first
# 2 chars of the word in plaintext. It always worries me
# having that plaintext lying arounbd, so I chop it.
##############################
sub crypt_pass {
	my $S = shift;
	my $p_pass = shift;
	Crypt::UnixCrypt::crypt($p_pass, $p_pass) =~ /..(.*)/;
	my $c_pass = $1;
	return $c_pass;
}

sub _set_auth_handler {
	my $self = shift;
	my $handler = shift;
	
	my $HANDLERS = {
		normal	=>	'Scoop::User::Auth'
	};
	
	my $auth = $HANDLERS->{$handler}->new($self);
	
	$self->{AUTH} = $auth;
}

##############################
# Sends the user a new password. The new password will be stored in
# a separate column in the USERS table until the user first logs in
# using that password. This makes sure that attackers cannot reset
# a user's password against his will. 
# Also note that new passwords can only be requested after a defined
# interval, to prevent spamming a user with password mails. 
##############################
sub _mailpass {

	my $self = shift;
	my $uname = shift;
	warn "  (Scoop::_mailpass) Mailing password to $uname\n" if ($DEBUG);
	my $uid = $self->get_uid_from_nick($uname);
	unless ($uid) {return 0;}	
	
	my $user = $self->user_data($uid);
	
	# check if user may request new password (min interval 
	# to prevent flooding)
	if ($user->{newpasswd} && $user->{pass_sent_at}) {
		require Time::Local;
		$user->{pass_sent_at} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
		my @date = ($6, $5, $4, $3, $2, $1);
		$date[4] -= 1;
		my $secs = Time::Local::timelocal(@date);
		warn "secs: $secs\tnow: ", time, "\n";
		if ($secs > (time - ($self->{UI}->{VARS}->{min_pw_request_interval} * 60))) {
			return 0;
		}
	}

	my $pass = $self->_random_pass();
	my $path = $self->{UI}->{VARS}->{rootdir} || "/";
	my $serv_port = ($ENV{SERVER_PORT} ne 80) ? ":$ENV{SERVER_PORT}" : undef;

	# Mail the new pass to the user
	my $message = qq|	
Someone from the IP number $self->{REMOTE_IP} requested that a new password 
be mailed for '$uname' on the site $self->{UI}->{VARS}->{site_url}$path

If it wasn't you, don't panic! Passwords are only mailed to the secret email
address for a user, so no one but you will see this. Your old password will
continue to work until you login with the new one. Note that you will not
be able to request another password for the next $self->{UI}->{VARS}->{min_pw_request_interval} minutes.

You may login with the following information:

Username: $uname
Password: $pass

Please remember to change your password right away, or you'll never remember 
it! If you have any problems, please reply to this message with a detailed
description. Thanks!

$self->{UI}->{VARS}->{local_email}|;

	my $email = $user->{realemail};
	my $subject = "New Password for $uname";
	my $rv = $self->mail($email, $subject, $message);
	
	warn "  (Scoop::mailpass) Mail of $pass to $email returned $rv" if ($DEBUG);

	
	if ($rv == 1) {
		# encrypt the new password - we only store hashes, never the cleartext
		my $c_pass = $self->crypt_pass($pass);
		my ($rv2, $sth) = $self->db_update({
			WHAT => 'users',
			SET => qq|newpasswd = '$c_pass', pass_sent_at = NOW()|,
			WHERE => qq|nickname = '$uname'|});
		$sth->finish;
		return $rv2;			
	}
	return $rv;
}
	

##############################
# Utility function to look up unames. Takes a userid and returns
# the relevant nick
##############################
sub get_nick {
	my $S = shift;
	my $id = shift;

	return $S->{UI}->{VARS}->{anon_user_nick} if $id == -1;
	return $S->{USER_DATA_CACHE}->{$id}->{nickname} if $S->{USER_DATA_CACHE}->{$id};

	my $q_id = $S->{DBH}->quote($id);
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'nickname',
		FROM => 'users',
		WHERE => qq|uid = $q_id|,
		DEBUG => 0});
	my $result = $sth->fetchrow;
	$sth->finish;
	return $result;
}

#############################
# Provides the number of bytes (or K or M) for a story.
# Takes an sid (scalar) and returns a string expressing bytes in a 
# Human Readable format
#############################
sub count_bits {
	my $S = shift;
	my $sid = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => qq|LENGTH(bodytext) as bits|,
		FROM => 'stories',
		WHERE => qq|sid = '$sid'|});
	
	my $ret = $sth->fetchrow_hashref;
	$sth->finish;
	my $bits = $ret->{bits};
	
	my $return = "$bits bytes";
	
	if ($bits <= 0) {
		$return = '';
	} elsif ($bits >= 1000000) {
		$bits = int $bits/1000000;
		$return = "$bits Mb";
	} elsif ($bits >= 1000) {
		$bits = int $bits/1000;
		$return = "$bits Kb";
	}
	
	return $return;
}


##############################
# Gets info on a topic image
##############################
sub get_topic {
	my $S = shift;
	my $tid = shift;
	
	my $topic = {};
	
	return $topic unless $S->{UI}->{VARS}->{use_topics};
	if ($tid) {
		$topic = $S->{TOPIC_DATA}->{$tid};
	}
	
	return $topic;
}


################################
# Get user data. The operating theory here is that SQL selects are free,
# Performance-wise. So I'd rather do a select than try to cache all user data.
# This may not scale well, we'll have to see.
#
# Input is a uid, output is a hashref w/all the relevant user stuff for comments
################################
sub user_data {
	my $S = shift;
	my $uid = shift;
	return unless defined($uid);
	warn "In user_data. UID is $uid\n" if $DEBUG;

	# go ahead and define the anonymous psuedo-user here, to make it easier to
	# change later if needed. most fields aren't defined, as they are never
	# used with the anonymous user
	$S->{USER_DATA_CACHE}->{anon} = {
		uid        => -1,
		nickname   => $S->{UI}->{VARS}->{anon_user_nick},
		perm_group => $S->{UI}->{VARS}->{anon_user_group},
		trustlev   => 0
	};

	my $user;
	my ($rv, $sth);
	
	my $get = {
		WHAT => '*',
		FROM => 'users'
	};
	
	my $pref = {	
		WHAT => '*',
		FROM => 'userprefs'
	};
	
	my $subs;
	if ($S->{UI}->{VARS}->{use_subscriptions}) {
		$subs = {
			WHAT => '*',
			FROM => 'subscription_info'
		};
	}

	# If we only want one user, pass off to get_one_user, and return info
	if (ref($uid) !~ /ARRAY/) {
		warn "In user_data: UID is single. Fetching for $uid\n" if $DEBUG;

		# Handle anonymous specially...
		return $S->{USER_DATA_CACHE}->{anon} if $uid == -1;

		# Check the temp cache?
		if ($S->{USER_DATA_CACHE}->{$uid}) {
			warn "In user_data: Found cached data for user $uid\n" if $DEBUG;
			return $S->{USER_DATA_CACHE}->{$uid};
		} 

		# or refresh...
		warn "In user_data: Need to refresh cache for $uid\n" if $DEBUG;
		$get->{WHERE} = qq|uid = $uid|;
		$pref->{WHERE} = qq|uid = $uid|;
		$subs->{WHERE} = qq|uid = $uid AND active = 1| if ($subs);
		
		($rv, $sth) = $S->db_select($get);
		$user = $sth->fetchrow_hashref;
		$sth->finish();

		($rv, $sth) = $S->db_select($pref);	
		while (my $p = $sth->fetchrow_hashref()) {
			warn "  (Scoop::user_data) $p->{prefname} = $p->{prefvalue}\n" if ($DEBUG);
			$user->{prefs}->{$p->{prefname}} = $p->{prefvalue};
		}
		$sth->finish();
		
		if ($subs) {
			($rv, $sth) = $S->db_select($subs);	
			my $sub = $sth->fetchrow_hashref();
			$user->{sub} = $sub;
			$sth->finish();
		}
		
		# Save for later...
		warn "Saving data for user $uid...\n" if $DEBUG;
		$S->{USER_DATA_CACHE}->{$uid} = $user;
		
		# and return
		return $user;
	}

	warn "In user_data: UID is array. Fetching multiple\n" if $DEBUG;

	# If $uid is an arrayref, then we need to fetch and cache all users
	# referred to.
	my (@filtered_users);
	foreach my $u (@{$uid}) {
		# Handle anonymous specially...
		next if $u == -1;
		if (!$S->{USER_DATA_CACHE}->{$u}) {
			warn "In user_data: Adding $u to query\n" if $DEBUG;
			push @filtered_users, $u;
		}
	}
	
	# If we had all cached, the forget about it
	return unless $#filtered_users >= 0;

	$get->{WHERE} = "uid IN (" . join (',', @filtered_users) . ")";
	$pref->{WHERE} = "uid IN (" . join (',', @filtered_users) . ")";
	$subs->{WHERE} = "uid IN (" . join (',', @filtered_users) . ") AND active = 1" if $subs;
	
	# Do the user select
	warn "In user data: Getting user array\n" if $DEBUG;
	($rv, $sth) = $S->db_select($get);
	while (my $u = $sth->fetchrow_hashref()) {
		# Handle anonymous specially...
		warn "In user_data: Caching $u->{uid}\n" if $DEBUG;
		$S->{USER_DATA_CACHE}->{ $u->{uid} } = $u;
	}
	$sth->finish();
	
	# Fill in prefs
	($rv, $sth) = $S->db_select($pref);
	while (my $u = $sth->fetchrow_hashref()) {
		# Handle anonymous specially...
		next unless $S->{PREF_ITEMS}->{$u->{prefname}}->{enabled};
		$S->{USER_DATA_CACHE}->{$u->{uid}}->{prefs}->{$u->{prefname}} = $u->{prefvalue};
	}
	$sth->finish();

	#and subs, if necessary
	if ($subs) {
		($rv, $sth) = $S->db_select($subs);
		while (my $u = $sth->fetchrow_hashref()) {
			$S->{USER_DATA_CACHE}->{$u->{uid}}->{sub} = $u;
		}
		$sth->finish();
	}	

	# And don't return anything
	return;
}
	
################################
# Your basic emailer. Give it a "to" address, a subject, and some content, and away you go.
################################
sub mail {
	my $S = shift;
	my ($to, $subject, $content, $from) = @_;
	$from ||= $S->{UI}->{VARS}->{local_email};
	
	my %mail = (
		to => $to,
		from => $from,
		subject => $subject,
		message => $content,
		smtp => $S->{CONFIG}->{SMTP}
	);
	
	my $error;
	if( ($mail{smtp} eq '-') && ( $S->localmail( \%mail )) ) {
		return 1;
	} elsif (&Mail::Sendmail::sendmail(%mail)) {
		return 1;
	}

	# log the reported error so the admin can fix any mis-configurations
	my $now = localtime;
	warn "[$now] (Scoop::mail) Error sending mail: $Mail::Sendmail::error\n";

	$error = $S->{UI}->{BLOCKS}->{email_error}; 
	$error =~ s/%%error%%/$Mail::Sendmail::error/;
	return $error;
}

# send mail via sendmail 
sub localmail { 
	my $S = shift;
	my $mail = shift; 
	my $sendmail = $S->{UI}->{VARS}->{sendmail_program};

	unless( -f $sendmail && -x _ ) {
		warn "$sendmail doesn't exist or we don't have permission to run it.  Can't send out mail";
		return 0;
	}

	if(!open(M,"|$sendmail -t")) { 
		warn "Can't run sendmail: $!"; 
		return 0; 
	} 

	print M "To: $mail->{to}\n"; 
	print M "From: $mail->{from}\n"; 
	print M "Subject: $mail->{subject}\n"; 
	print M "\n"; 
	print M $mail->{message};

	if(!close(M)) { 
		warn "sendmail failed: $!"; 
		return 0; 
	} 

	return 1; 
} 


# Debugging dumper
sub dump {
	my $S = shift;
	my ($vars, $names, $format) = @_;
	
	my $dump = Data::Dumper->Dump($vars, $names); # Arrayrefs!

	if ($format eq 'html') {
		$dump =~ s/\n/<BR>/g;
		$dump =~ s/ /&nbsp;/g;
	}
	
	return $dump;
}

sub _refresh_thresholds {
	my $S = shift;
	
	my $post_thresh = $S->{UI}->{VARS}->{post_story_threshold};
	my $hide_thresh = $S->{UI}->{VARS}->{hide_story_threshold};
	my $stop_thresh = $S->{UI}->{VARS}->{end_voting_threshold};
	
	unless ($post_thresh =~ /%/ || $hide_thresh =~ /%/ || $stop_thresh =~ /%/) {
		return $S;
	}
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'COUNT(*)',
		FROM => 'users'});
	my $uid = $sth->fetchrow();
	$sth->finish;
	
	my $one_percent = ($uid / 100);
	#$one_percent = 1 unless $one_percent;
	
	my ($thresh_percent, $hard_limit);
	
	if ($post_thresh =~ /^(\d*\.*\d*)%$/) {
		$thresh_percent = sprintf("%1.4f", $1);
		$hard_limit = int($one_percent * $thresh_percent);
		$hard_limit = 1 unless ($hard_limit >= 1);
		$S->{UI}->{VARS}->{post_story_threshold} = $hard_limit;
	}
	
	if ($hide_thresh =~ /^(\d*\.*\d*)%$/) {
		$thresh_percent = sprintf("%1.4f", $1);
		$hard_limit = '-'.int($one_percent * $thresh_percent);
		$hard_limit = -1 unless ($hard_limit <= -1 && !$S->{UI}->{VARS}->{use_alternate_scoring});
		$S->{UI}->{VARS}->{hide_story_threshold} = $hard_limit;
	}
	
	if ($stop_thresh =~ /^(\d*\.*\d*)%$/) {
		$thresh_percent = sprintf("%1.4f", $1);
		$hard_limit = int($one_percent * $thresh_percent);
		$hard_limit = 1 unless ($hard_limit >= 1);
		$S->{UI}->{VARS}->{end_voting_threshold} = $hard_limit;
	}
	
	return $S;
}


sub _current_time {
	my $S = shift;
	my @date = localtime(time);
	my $mon = $date[4]+1;
	my $day = $date[3];
	my $year = $date[5]+1900;
	my $currtime = qq|$year-$mon-$day $date[2]:$date[1]:$date[0]|;
	
	return $currtime;
}

##############################
# Get the mySQL DATE_FORMAT stuff all in one place here.
# In the future, we ought to localize by preference, and
# this will make it easier
##############################
sub date_format {
	my $S = shift;
	my $fieldname = shift || '';
	my $format = shift || '';
	my $date_format='';
	my ($adjust_time, $zone) = $S->time_localize($fieldname);

        # For default format strings
        my $time_format;
        if (lc($S->{CONFIG}->{DBType}) eq "mysql") {
                $time_format = $S->{UI}->{VARS}->{time_24h_format} ? "%T" : "%r";
        } else {
                $time_format = $S->{UI}->{VARS}->{time_24h_format} ? "HH24:MI:SS" : "HH12:MI:SS PM";
        }

        if ($format eq 'short') {

                # Var contains special key "zone" -- replace if it's there
                my $tmpl = $S->{UI}->{VARS}->{date_format_short};
                $tmpl =~ s/\|zone\|/$zone/g;

                if(lc($S->{CONFIG}->{DBType}) eq "mysql") {
                        $date_format = $tmpl || "%m/%d/%Y $time_format $zone";
                } else {
                        $date_format = $tmpl || "MM/DD/YY $time_format \"$zone\"";
                }

        } elsif ($format eq 'WMD') {

                # Var contains special key "zone" -- replace if it's there
                my $tmpl = $S->{UI}->{VARS}->{date_format_wmd};
                $tmpl =~ s/\|zone\|/$zone/g;

                if (lc($S->{CONFIG}->{DBType}) eq "mysql") {
                        $date_format = $tmpl || "%W %M %D";
                } else {
                        $date_format = $tmpl || "WW MM DD";
                }

        } elsif ($format eq 'W3C') {
                # Use the subset of the ISO8601 date format standard which is described
                # in a W3C note and is the preferred format for the Dublin Core and RSS.
                # Example: YYYY-MM-DDThh:mm:ssTZD (eg 1997-07-16T19:20:30+01:00)
                # See Also: http://www.w3.org/TR/NOTE-datetime  http://dublincore.org/

                # No format changing var for this one, since it's a defined format and should be changed.

                # Determine whether the field is in the Scoop server's or the user's
                # time zone and how many seconds the value will be offset from UTC
                my ($offset, $offset_as_string);
                $offset = &Time::Timezone::tz_offset(lc($S->pref('time_zone')));

               # Create a string that describes the field's offset from UTC in the format
                # "+|-HH:MM" (or "Z" if the field is in UTC)
                if ($offset != 0) {
                        my $sign = $offset > 0 ? "+" : "-";
                        my $offset_hours = int(abs($offset) / 3600);
                        my $offset_minutes = int((abs($offset) % 3600) / 60);

                        # make sure offset hours and minutes are two digits long
                        if ($offset_hours < 10) { $offset_hours = "0$offset_hours"; }
                        if ($offset_minutes < 10) { $offset_minutes = "0$offset_minutes"; }

                        $offset_as_string = "$sign$offset_hours:$offset_minutes";
                } else {
                        $offset_as_string = "Z"; # shorthand for "+00:00"
                }

                if(lc($S->{CONFIG}->{DBType}) eq "mysql") {
                        # MySQL date formatting string
                        $date_format = "%Y-%m-%dT%H:%i:%S$offset_as_string";
                } else {
                        $date_format = 'YYYY-MM-DD"T"HH:MI:SS"$offset_as_string"';
                }


        } else {

                # Var contains special key "zone" -- replace if it's there
                my $tmpl = $S->{UI}->{VARS}->{date_format_default};
                $tmpl =~ s/\|zone\|/$zone/g;

                if (lc($S->{CONFIG}->{DBType}) eq "mysql") {
                        $date_format = $tmpl || "%a %b %D, %Y at $time_format $zone";
                        if ($S->{CONFIG}->{mysql_version} eq '3.22') {
                                $date_format = $tmpl || "%a %b %D, %Y %r";
                        }
                } else {
                        $date_format = $tmpl || "Dy Mon DD, YYYY at $time_format \"$zone\"";
                }
        }

	
	my $full_str;
		if(lc($S->{CONFIG}->{DBType}) eq "mysql") {
			$full_str = qq|DATE_FORMAT(($adjust_time), "$date_format")|;
		} else {
			$full_str = qq|TO_CHAR(($adjust_time), '$date_format')|;
		}
	
	
	return $full_str;
}

sub time_localize {
	my $S = shift;
	my $fieldname = shift;
	
	my $adjust_time = $fieldname;
	my $zone = uc($S->pref('time_zone'));
	
	warn "  (Scoop::date_format) Local zone is $S->{UI}->{VARS}->{time_zone}.\n" if ($DEBUG);
	warn "  (Scoop::date_format) User's zone is $zone.\n" if ($DEBUG);

	# get the difference in seconds between the Scoop server's time zone and UTC
	my $loc_offset = &Time::Timezone::tz_offset(lc($S->{UI}->{VARS}->{time_zone}));
	warn "  (Scoop::date_format) Local offset is $loc_offset.\n" if ($DEBUG);

	# get the difference in seconds between the user's time zone and UTC in seconds
	my $user_offset = &Time::Timezone::tz_offset(lc($zone));
	warn "  (Scoop::date_format) User's offset is $user_offset.\n" if ($DEBUG);

	# calculate the difference in seconds between the Scoop server's time zone
	# and the user's time zone
	my $diff = ($user_offset + -($loc_offset));

	# if the difference is a positive number, prepend a plus sign to it
	unless ($diff =~ /^([-])/) {
		$diff = "+$diff";
	}

	# figure out whether the difference is positive or negative (i.e. what sign it has)
	$diff =~ s/^(.)//;
	my $pl_min = $1;


	# convert the name of the date field into a MySQL function call
	# that returns the value of the field converted into the user's time zone
	if ($pl_min eq '+') {
		$adjust_time = $S->db_date_add($fieldname, "$diff SECOND");
	} else {
		$adjust_time = $S->db_date_sub($fieldname, "$diff SECOND");
	}

	warn "  (Scoop::date_format) Time diff is $diff\n" if ($DEBUG);

	
	return ($adjust_time, $zone);
}


# Make a random password of upper and lowercase letters
sub _random_pass {
	my $S = shift;
	my $foo = new String::Random;
  	$foo->{'A'} = [ 'A'..'Z', 'a'..'z' ];
	my $pass = $foo->randpattern("AAAAAAAA");
	return $pass;
}
		
sub rand_stuff {
	my $S = shift;
	my $bytes = shift || 5;

	return String::Random->new->randpattern('n' x $bytes);

	# I've had enough of this crap ;)

	#my $crap;
	#open CRAP, "</dev/urandom";
	#read CRAP, $crap, $bytes;
	#close CRAP;
	#my $crap_2 = unpack "I*", $crap;

	#return $crap_2;
}

# insert who's online info into the appropriate table
sub _insert_whos_online {

	my $S = shift;
	my $ip = shift;
	my $uid = shift;

	# Try updating first. If that doesn't work, then insert

	my ($rv, $sth) = $S->db_update({
		WHAT => "whos_online",
		SET => "last_visit = NOW()",
		WHERE => "ip = '$ip' AND uid = '$uid'"});
	warn "rv = $rv" if $DEBUG;
	
	$sth->finish;
	unless ($rv == 1) {
		my ($rv2, $sth2) = $S->db_insert({
			INTO => 'whos_online',
			COLS => 'ip, uid, last_visit',
			VALUES => "'$ip', '$uid', NOW()"});
		$sth2->finish;
		}

	}

1;

