package Scoop;
use strict;

sub hotlist {
	my $S = shift;
	return unless ($S->{UID} >= 0);
#	my $edit = $S->{CGI}->param('edit');
#	return unless ($edit eq 'hotlist');
	my $op = $S->{CGI}->param('op');
	return unless $op eq 'hotlist';

	my $tool = $S->{CGI}->param('tool');
#	my $op = $S->{CGI}->param('op');
	my $new_op = $S->{CGI}->param('new_op');
	my $sid = $S->{CGI}->param('sid');
	my $oplink;

	return unless $sid;

	my $story = $S->getstories({
		-type => 'summaries',
		-sid => $sid,
		-dispstatus => undef
	})->[0];
	return unless defined($story->{displaystatus})
		&& ($story->{displaystatus} >= 0);

	if ($tool eq 'add') {
		$S->add_to_hotlist;
	} elsif ($tool eq 'remove') {
		$S->remove_from_hotlist;
	}
	
	if ($new_op && $sid) {
		$oplink = qq|?op=$new_op;sid=$sid|;
	}

	$S->param->{op} = $new_op;

	return;
}

sub add_to_hotlist {
	my $S = shift;

	my $sid = $S->{CGI}->param('sid');
	my $hotlisted = $S->check_for_hotlist_story($sid);
	return if $hotlisted;

	# first, we hotlist it in the DB
	my $seen = $S->story_last_seen($sid);
	if (defined($seen)) {  # the row exists, but is not marked hotlisted
		my ($rv, $sth) = $S->db_update({
			WHAT  => 'viewed_stories',
			SET   => qq|hotlisted = 1|,
			WHERE => qq|uid = $S->{UID} AND sid = '$sid'|
		});
		$sth->finish;
	} else {  # no row in the database
		my ($rv, $sth) = $S->db_insert({
			INTO   => 'viewed_stories',
			COLS   => 'uid, sid, hotlisted',
			VALUES => qq|$S->{UID}, '$sid', 1|
		});
		$sth->finish;
	}

	# next, we hotlist it locally
	$S->{HOTLIST} = [] unless $S->{HOTLIST};
	push(@{ $S->{HOTLIST} }, $sid);

	return 1;
}

sub remove_from_hotlist {
	my $S = shift;
	
	# Let code pass in an sid to remove, if it wants
	# The hotlist box can do this for deleted stories
	my $sid = shift;
	# Otherwise get it from the url
	# This is the normal "remove link" method
	$sid = $S->{CGI}->param('sid') unless ($sid);
	my $hotlisted = $S->check_for_hotlist_story($sid);
	return unless $hotlisted;

	# first, do the db
	my $show_new = $S->{UI}->{VARS}->{show_new_comments};
	if ($show_new eq "all" && !$S->_check_archivestatus($sid)) {    # keep the row around
		my ($rv, $sth) = $S->db_update({
			WHAT  => 'viewed_stories',
			SET   => qq|hotlisted = 0|,
			WHERE => qq|uid = $S->{UID} AND sid = '$sid'|
		});
		$sth->finish;
	} else {    # remove the row
		my ($rv, $sth) = $S->db_delete({
			FROM  => 'viewed_stories',
			WHERE => qq|uid = $S->{UID} AND sid = '$sid'|
		});
		$sth->finish;
	}

	# now, do it locally
	my $new_hotlist = [];
	foreach my $hitem (@{ $S->{HOTLIST} }) {
		push(@{$new_hotlist}, $hitem) unless ($hitem eq $sid);
	}
	$S->{HOTLIST} = $new_hotlist;

	return $S;
}

sub get_hotlist {
	my $S = shift;

	my $list = $S->get_sids({hotlisted => 1, limit => '0'});

	return $list;
}

sub check_for_hotlist_story {
	my $S = shift;
	my $sid = shift || return;

	foreach my $hitem (@{ $S->{HOTLIST} }) {
		return 1 if ($hitem eq $sid);
	}

	return 0;
}

sub populate_last_seen {
	my $S = shift;
	my $sid = shift;
	
	return unless ($S->{UID} > 0);
	return unless (!$S->_check_archivestatus($sid));
	#$S->{LAST_SEEN} = {};
	my ($rv, $sth) = $S->db_select({
		WHAT  => 'lastseen, hotlisted, sid, highest_idx',
		FROM  => 'viewed_stories',
		WHERE => qq|uid = $S->{UID} AND sid = '$sid'|
	});
	while (my $item = $sth->fetchrow_hashref()) {
		$S->{LAST_SEEN}->{$item->{sid}} = $item;
	}
	$sth->finish;
}
	
sub story_highest_index {
	my $S = shift;
	my $sid = shift || return 0;
	return unless ($S->{UID} > 0);
	return unless (!$S->_check_archivestatus($sid));
	unless (defined($S->{LAST_SEEN}->{$sid})) {
		$S->populate_last_seen($sid);
	}
	return $S->{LAST_SEEN}->{$sid}->{highest_idx} || 0;
}


sub story_last_seen {
	my $S = shift;
	my $sid = shift || return;

	return unless ($S->{UID} > 0);
	return unless (!$S->_check_archivestatus($sid));
	unless (defined($S->{LAST_SEEN}->{$sid})) {
		$S->populate_last_seen($sid);
	}
	
	return $S->{LAST_SEEN}->{$sid}->{lastseen};
}

sub update_seen {
	my $S = shift;
	my $sid = shift || return;
	my $q_sid = $S->dbh->quote($sid);

	my $seen = $S->story_last_seen($sid);
	my $count = $S->_commentcount($sid) || 0;
	my $highest = $S->_comment_highest($sid) || 0;
	
	if (defined($seen)) {    # the row already exists
		my ($rv, $sth) = $S->db_update({
			WHAT  => 'viewed_stories',
			SET   => qq|lastseen = $count, highest_idx = $highest|,
			WHERE => qq|uid = $S->{UID} AND sid = $q_sid|,
			DEBUG => 0
		});
		$sth->finish();
	} else {   # need to add the row
		my ($rv, $sth) = $S->db_insert({
			INTO   => 'viewed_stories',
			COLS   => 'uid, sid, lastseen, highest_idx',
			VALUES => qq|$S->{UID}, $q_sid, $count, $highest|,
			DEBUG => 0
		});
		$sth->finish();
	}

	# Update the request cache
	$S->{LAST_SEEN}->{$sid}->{lastseen} = $count;
	$S->{LAST_SEEN}->{$sid}->{highest_idx} = $highest;
	
	return 1;
}

sub update_seen_if_needed {
	my $S = shift;
	my $sid = shift || return;

	return unless ($S->{UID} > 0);
	return unless (!$S->_check_archivestatus($sid));
	my $show = $S->{UI}->{VARS}->{show_new_comments};
	if ($show eq 'hotlist') {
		my $hotlisted = $S->check_for_hotlist_story($sid);
		$S->update_seen($sid) if $hotlisted;
	} elsif ($show eq 'all') {
		$S->update_seen($sid);
	}
}

sub new_comments_since_last_seen {
	my $S = shift;
	my $sid = shift || return;

	return unless ($S->{UID} > 0);
	return unless (!$S->_check_archivestatus($sid));
	my $lastseen = $S->story_last_seen($sid) || 0;
	my $current_count = $S->_commentcount($sid);
	my $new = ($current_count - $lastseen);
	
	return ($new >= 0) ? $new : 0;
}

1;
