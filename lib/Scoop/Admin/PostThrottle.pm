package Scoop;
use strict;

my $DEBUG = 0;

sub rate_check {
	my $S = shift;
	my $op = $S->{CGI}->param('op');

	return unless $S->{UID} > 0;
	return if ($S->{GID} eq 'Superuser');

	# See if this is a comment post attempt at all
	my $attempt;
	if ($op eq 'comments') { 
		$attempt = $S->_comment_post_attempt();
		warn "Comment posting, result is $attempt\n" if $DEBUG;
	}
	
	# See if it's a story submit attempt
	if ($op eq 'submitstory') { 
		# Check if we're editing a story in the Queue
		my $sid = $S->{CGI}->param('sid');
		my $aid = $S->{CGI}->param('aid');
		if ($sid) {
			# Check that it's a valid sid.
			# So we need to check the sid is in the stories
			# table, and that the author matches.
			$sid = $S->{DBH}->quote($sid);
			$aid = $S->{DBH}->quote($aid);
			my ($rv, $sth) = $S->db_select({
				DEBUG => 0,
				WHAT => 'count(sid)',
				FROM => 'stories',
				WHERE => "sid = $sid and aid = $aid"
			});
			warn "Editing story result is $rv" if $DEBUG;
			$attempt = $S->_story_post_attempt() unless ($rv);
		} else {
			$attempt = $S->_story_post_attempt() 
		}
	};
	
	# return if it's not either.
	return 0 unless $attempt;

	# Otherwise, check the rate	
	return $S->_post_rate_check($attempt);
}

sub _post_rate_check {
	my $S = shift;
	my $attempt = shift;
	my $max_comm = $S->{UI}->{VARS}->{max_comments_submit} || 0;
	my $max_story = $S->{UI}->{VARS}->{max_stories_submit} || 0;
	
	# Make sure throttle is on
	return 0 if (($max_comm == 0) && ($attempt eq 'comment'));
	return 0 if (($max_story == 0) && ($attempt eq 'story'));

	# Check for a lock record
	my ($rv, $sth) = $S->db_select({
		WHAT => 'uid, post_lock, lock_timeout, NOW() - created_time AS elapse',
		FROM => 'post_throttle',
		WHERE => qq|uid = $S->{UID}|});
	
	# If they have a lock...
	if (my $user = $sth->fetchrow_hashref()) {
		my $timeout = ($user->{lock_timeout} * 60);
		if ($user->{elapse} < $timeout) {
			# Still in timeout. So, double the timeout.
			$S->_double_timeout($user);
			return 1;
		} else {
			# Drop the lock
			$S->_drop_lock();
			return 0;
		}
	}
	
	# Otherwise, check for rate exceeding
	my $fail;
	$fail = $S->_comment_rate_check() if ($attempt eq 'comment');
	$fail = $S->_story_rate_check() if ($attempt eq 'story');
	
	return $fail;
}


sub _drop_lock {
	my $S = shift;
	
	# Lock time elapsed, clear it.
	my $rv = $S->db_delete({
		FROM => 'post_throttle',
		WHERE => qq|uid = $S->{UID}|
	});
			
	warn(">> Warning: Could not clear post lock for $S->{UID}: ".$S->{DBH}->errstr()) unless ($rv);
	return;
}

		
sub _double_timeout() {
	my $S = shift;
	my $user = shift;
	my $new_time = $user->{lock_timeout} * 2;
	
	if ($new_time >= $S->{UI}->{VARS}->{max_timeout}) {
		warn "Timeout limit $S->{UI}->{VARS}->{max_timeout} min exceeded. User is now banned.\n";
		$S->_ban_user($user);
		$S->_drop_lock();
		return 1;
	} else {
		warn "Post rate violation detected. Timeout is now $new_time min.\n";
		my ($rv) = $S->db_update({
			WHAT => 'post_throttle',
			SET => qq|lock_timeout = '$new_time', created_time = NOW()|,
			WHERE => qq|uid = $S->{UID}|});
	}
	
	$S->{UI}->{VARS}->{timeout_minutes} = $new_time;
	return 1;	
}

sub _ban_user {
	my $S = shift;
	
	# Try to find the group to boot users into
	my $anon_grp = $S->{UI}->{VARS}->{untrusted_group} || 'Anonymous';
	
	my $rv = $S->db_update({
		WHAT => 'users',
		SET => qq|perm_group = '$anon_grp'|,
		WHERE => qq|uid = $S->{UID}|});
	
	$S->admin_alert('user banned from posting');
	
	return 1;
}
		
sub _story_rate_check {
	my $S = shift;
	my $user = shift;
	
	# Not locked out already, so let's see if they should be
	my $time_per = ($S->{UI}->{VARS}->{rate_limit_minutes} * 60);
	my $story_limit = $S->{UI}->{VARS}->{max_stories_submit};

	# How many stories have we posted in the past hour?	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'COUNT(*)',
		FROM => 'stories',
		WHERE => "aid = $S->{UID} AND time >= " . $S->db_date_sub("NOW()", "$time_per SECOND")
	});
	
	my $story_count = $sth->fetchrow();
	$sth->finish();
	
	# If this would exceed the allowed number...
	if (($story_count + 1) > $story_limit) {
		# lock the user
		my ($rv) = $S->_lock_posts();
		# Email the admin
		$S->admin_alert('story rate exceeded');
		# And return a fail
		return 1;
	}

	# Otherwise return ok.
	return 0;
}

sub _comment_rate_check {
	my $S = shift;
	my $user = shift;
	
	# Not locked out already, so let's see if they should be
	my $time_per = ($S->{UI}->{VARS}->{rate_limit_minutes} * 60);
	my $comm_limit = $S->{UI}->{VARS}->{max_comments_submit};

	# How many comments have we posted in the past whatever?	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'COUNT(*)',
		FROM => 'comments',
		WHERE => "uid = $S->{UID} AND date >= " . $S->db_date_sub("NOW()", "$time_per SECOND")
	});
	
	my $comm_count = $sth->fetchrow();
	$sth->finish();
	
	# If this would exceed the allowed number...
	if (($comm_count + 1) > $comm_limit) {
		# lock the user
		my ($rv) = $S->_lock_posts();
		# Email the admin
		$S->admin_alert('comment rate exceeded');
		# And return a fail
		return 1;
	}

	# Otherwise return ok.
	return 0;
}

sub admin_alert {
	my $S = shift;
	my $warning = shift;

	my $subject = $S->{UI}->{BLOCKS}->{admin_alert_subject};
	my $content = $S->{UI}->{BLOCKS}->{admin_alert_body};
	my $keys;
	$keys->{from} = $S->var('local_email');
	$keys->{sitename} = $S->var('sitename');
	$keys->{site_url} = $S->var('site_url');
	$keys->{rootdir} = $S->var('rootdir');
	$keys->{warning} = $warning;
	$keys->{nick} = $S->{NICK};
	$keys->{uid} = $S->{UID};
	$keys->{ip} = $S->{REMOTE_IP};
	$keys->{user_pref} = $S->var('site_url') . $S->var('rootdir') . "/user/$keys->{nick}/prefs/Protected";
	$keys->{user_info} = $S->var('site_url') . $S->var('rootdir') . "/user/$keys->{nick}";

	$subject = $S->interpolate($subject,$keys);
	$content = $S->interpolate($content,$keys);

	my $to = $S->{UI}->{VARS}->{admin_alert};
	my @send_to = split /,/, $to;
	
	foreach my $address (@send_to) {
		$S->mail($address, $subject, $content);
	}
	
	return;
}

	
sub _lock_posts {
	my $S = shift;
	my $init_timeout = $S->{UI}->{VARS}->{timeout_minutes};
	
	warn "First rate violation detected. Timeout is $init_timeout\n";
	
	my $rv = $S->db_insert({
		INTO => 'post_throttle',
		COLS => 'uid, post_lock, created_time, lock_timeout',
		VALUES => qq|'$S->{UID}', '1', NOW(), "$init_timeout"|});
	
	warn(">> Warning: Could not create post lock for $S->{UID}: ".$S->{DBH}->errstr()) unless ($rv);
	return;
}		
	
# Check for comment post rate violation
sub _comment_post_attempt {
	my $S = shift;
	
	my $tool = $S->{CGI}->param('tool');
	my $mode = $S->{CGI}->param('post');
	
	warn "Comment post? Tool is $tool, post is $mode\n" if $DEBUG;
	
	# See if they're tryng to post, and are allowed to in the first place
	return 0 unless (($tool eq 'post') && ($mode eq 'Post') && ($S->have_perm( 'comment_post' )));
	
	# So we have a comment post attempt.
	# tell the parent that that's what's going on
	return 'comment';
}

sub _story_post_attempt {
	my $S = shift;
	
	my $save = $S->{CGI}->param('save');
	return 'story' if ($save && $S->have_perm('story_post'));
	return 0;
}


1;
