=head1 Utils.pm

This module is full of useful utilities relating to polls.  Functions to get
poll hashes, answer hashes, qid's, etc.  

=head1 Functions

Here are the utilities and their prototypes

=cut

package Scoop;

use strict;

my $DEBUG = 0;


=pod

=over 4

=item *
poll_comment_num($qid)

This takes a qid and returns the number of comments to the given poll

=back

=cut

sub poll_comment_num {
	my $S = shift;
	my $qid = shift;
	$qid = $S->dbh->quote($qid);

	my $c_num = 0;

	my ($rv, $sth) = $S->db_select({
		DEBUG   => 0,
		WHAT	=> 'cid',
		FROM	=> 'comments',
		WHERE   => "sid = $qid",
	});

	if( $rv ) {
		while( my $tmp = $sth->fetchrow_hashref ) {
			$c_num++;
		}
	}
	$sth->finish;

	return $c_num;
}


=pod

=over 4

=item *
get_poll_hash($qid)

Passed in a qid this function returns the hash for that poll 

=back

=cut

sub get_poll_hash {
	my $S = shift;
	my $qid = shift;
	my $action = shift;

	my ($rv, $sth);
	my $return_hash = {};
 
	my $current_qid = $qid || $S->_get_current_poll;
	$current_qid = $S->dbh->quote($current_qid);

	# first just get the pollquestion. if its a preview get it from $S->{CGI}
	# else get it from the db
	if( $action eq 'preview' ) {

		$return_hash->{'question'} = $S->{CGI}->param('question');
		$return_hash->{'qid'} = $qid;
		$return_hash->{'voters'} = $S->{CGI}->param('voters');

	} else {

		($rv, $sth) = $S->db_select({
				DEBUG   => 0,
				WHAT	=> "qid,question,voters,post_date",
				FROM	=> 'pollquestions',
				WHERE   => "qid = $current_qid",
				});
 
		unless ($rv) {
			return 0;
		}

		$return_hash = $sth->fetchrow_hashref(); 
		$sth->finish;
	}

	$return_hash->{'question'} = $S->filter_subject($return_hash->{'question'});
	return $return_hash;

}


=pod

=over 4

=item *
get_poll_answers($qid)

This function takes a poll qid and returns a hash of all of the possible answers
for that poll

=back

=cut

sub get_poll_answers {
	my $S = shift;
	my $poll_qid = shift;
	my $action = shift;

	$poll_qid = $S->{DBH}->quote($poll_qid);

	my ($rv, $sth);
	my $answers = [];

	# first just get the pollanswers
	# if action is a preview get it from the $S->{CGI} object
	if( $action eq 'preview' ) {

		for(my $aid = 1; $aid <= $S->{UI}->{VARS}->{'poll_num_ans'}; $aid++ ) {
			my $answer = $S->{CGI}->param("answer" . $aid);
			my $votes = $S->{CGI}->param("votes" . $aid);
			last if ( $answer eq "" );			

			$answer = $S->filter_subject($answer);

			push @{$answers}, { qid		=> $poll_qid,
							 	aid		=> $aid,
							 	answer	=> $answer,
							 	votes	=> $votes };
		}

	} else {
		($rv, $sth) = $S->db_select({
				DEBUG 	 => 0,
				WHAT 	 => "qid,aid,answer,votes",
				FROM 	 => 'pollanswers',
				WHERE	 => "qid = $poll_qid",
				ORDER_BY => "aid ASC"
				});

		unless ($rv) {
			return 0;
		}
		unless ( $#{$answers} > 0 ) {
			while( my $tmp = $sth->fetchrow_hashref() ) {
				push @{$answers}, $tmp;
			}
			$sth->finish();
		}
	}
	
	return $answers;
}


=pod

=over 4

=item *
get_sid_from_qid($qid)

Like the name says, this function returns the sid of the story the poll is attached
to.  If the poll is not attached it returns 0.

=back

=cut

sub get_sid_from_qid {
	my $S = shift;
	my $qid = shift;
	my $sid;

	$qid = $S->{DBH}->quote($qid);
	my ($rv, $sth) = $S->db_select({
		DEBUG	=> 0,
		FROM	=> 'stories',
		WHAT	=> 'sid',
		WHERE	=> qq| attached_poll = $qid |
	});

	if ($rv eq "0E0") {
		$rv = 0;
	}
	# if not there, look in the archive
	if ($S->{HAVE_ARCHIVE} && !$rv) {
		($rv, $sth) = $S->db_select({
			DEBUG	=> 0,
			ARCHIVE => 1,
			FROM	=> 'stories',
			WHAT	=> 'sid',
			WHERE	=> qq| attached_poll = $qid |
		});
		if ($rv eq "0E0") {
			$rv = 0;
		}
	}

	# found it somewhere, so get the sid
	if ($rv) {
		my $tmphash = $sth->fetchrow_hashref;
		$sid = $tmphash->{sid};
		return $sid;
	# poll doesn't seem to be attached to any story
	} else {
		return 0;
	}
}


=pod

=over 4

=item *
get_qid_from_sid($sid)

This returns the qid of the poll attached to story $sid.  If there is no
attached poll it returns 0.

=back

=cut

sub get_qid_from_sid {
	my $S = shift;
	my $sid = shift;
	my $qsid = $S->{DBH}->quote($sid);
	my $qid;
	
	my ($rv, $sth) = $S->db_select({
		DEBUG	=> 0,
		ARCHIVE => $S->_check_archivestatus($sid),	
		FROM 	=> 'stories',
		WHAT	=> 'attached_poll',
		WHERE	=> qq| sid = $qsid |,
	});

	unless( $rv ) {
		return 0;
	}

	my $hash = $sth->fetchrow_hashref;
	$qid = $hash->{attached_poll};

	return $qid;
}


=pod

=over 4

=item *
get_qid_to_show()

This function came about because of some really really messy code in poll_box.  What it does 
is determines the qid of the poll to display, whether it should be an attached poll or the current
poll, and returns that.  If it shouldn't be displaying a poll, it returns 0.
This function returns ($qid, $action).  $action is 'preview', 'normal', or 'novote'.
If preview, the values are from $S->{CGI}, if normal, from the db, and if novote,
from the db and the vote stuff isn't displayed.

=back

=cut

sub get_qid_to_show {
	my $S = shift;
	my $pollqid;

	my $op = $S->{CGI}->param('op');
	my $mode = $S->{CGI}->param('mode');
	my $tool = $S->{CGI}->param('tool');
	
	my $form_qid = $S->{CGI}->param('qid');
	my $current_poll = $S->{UI}->{VARS}->{current_poll};

	my $action = 'normal';
	my $preview = 0;

	return 0 if $op eq 'modsub';
	return 0 if $op eq 'view_poll';
	return 0 unless( $S->have_perm('view_polls') );

	return $form_qid if $op eq 'poll_vote';

	$preview = 1 if $op eq 'submitstory';
	$preview = 1 if $mode eq 'moderate';
	$preview = 1 if ($op eq 'admin' && $tool eq 'story');

	# check to see if this is to display an attached poll by checking the sid parameter
	# the reason for the crazy if stuff is so that the eval doesn't complain
	my $attach_flag = (my $sid = $S->{CGI}->param('sid'));
	unless( $attach_flag ) {
		$attach_flag = $preview;
	}

	# to fix a bug, if they hotlisted a story from the front page, the front page
	# poll was replaced with the story's poll.  This should fix that.
	if( $op eq 'main' ) {
		$attach_flag = 0;
	}

	if ( $attach_flag ) {
		# of course return if they don't have any poll entered, so they don't see the current_poll
   		 return '' if ($S->{CGI}->param('question') eq '' && $op eq 'submitstory' );

		my $qsid = $S->{DBH}->quote($sid);

		unless( $S->{CGI}->param('preview') eq 'Preview' ){
			my ($rv, $sth) = $S->db_select({
				ARCHIVE => $S->_check_archivestatus($sid),
				WHAT => 'attached_poll,displaystatus',
				FROM => 'stories',
				WHERE => qq|sid = $qsid| });
			
			if (my $att_poll = $sth->fetchrow_hashref()) {
				$pollqid = $att_poll->{attached_poll} || 'nonexistant_poll';
				$action = 'novote' if( $att_poll->{displaystatus} == -3 );
			} else {
				warn "returning 0 because not previewing and nothing attached to this sid" if $DEBUG;
				return 0;
			}

		} else {	# if it gets here its a preview, so set the $action to preview
			$action = 'preview';
			$pollqid = $S->{CGI}->param('editqid');
  		}
	} 

	$pollqid = $current_poll if ($pollqid eq '');
	
	unless( $S->_does_poll_exist($pollqid) || $action eq 'preview') {
		return 0;
	} else {
		return ( $pollqid, $action );
		
	}

}


=pod

=over 4

=item *
_does_poll_exist($qid)

This takes a qid and checks to see if a poll by that qid
exists, if it does, it returns 1, else 0
It used to just make a db call everytime, but now with IPC::Cache it
will cache it all unless it doesn't recognize the qid, in which it will 
look for it, and if that qid is actually a sid, then it will cache it as
not_qid_$qid.

=back

=cut

sub _does_poll_exist {
	my $S = shift;
	my $testqid = shift;
	my $quote_qid = $S->{DBH}->quote($testqid);
	my $retval;

	# see if the qid is already cached, either as a not_qid (a sid)
	# or a existing poll
	my $cached_qid = $S->{qid_cache}->{$testqid};
	my $cached_sid = $S->{sid_cache}->{$testqid};	

	return 1 if ( $cached_qid );
	return 0 if ( $cached_sid );

	unless( defined( $cached_qid ) ) {
		# warn "cached_qid wasn't defined.  it equals '$cached_qid'";
		my ($rv, $sth) = $S->db_select( {
							DEBUG 	=> 0,
							WHAT 	=> 'qid',
							FROM 	=> 'pollquestions',
							WHERE	=> qq| qid = $quote_qid |,
						});

		# If $rv == 1 then it exists, but if it gets here,
		# then its not cached, so cache it			
		if( $rv == 1 ) {

			# get the qid
			my $row = $sth->fetchrow_hashref;
			$row = $row->{'qid'};

			# set the qid in the cache, and the retval to 1
			$S->{qid_cache}->{$testqid} = 1;
			
			# Make sure the sid cache isn't set!
			$S->{sid_cache}->{$testqid} = 0;
			
			#warn "poll_$testqid in the cache was set to 1";
			$retval = 1;

		} else {
			# ok, check to see if this is definitly not a poll (a sid)
			# and cache it as not_poll_$testqid if its not a poll.
			#warn "0 rv is $rv, qid is '$testqid'";

			# if the testqid is a story, cache it
			if( $S->_check_for_story($testqid) ) {
				# Set the sid cache
				$S->{sid_cache}->{$testqid} = 1;
				
				# Make sure qid cache is unset
				$S->{qid_cache}->{$testqid} = 0;
			}

			$retval = 0;
		}

		$sth->finish();

	} else {
		$retval = 1;
	}

	return $retval;
}


=pod

=over 4

=item *
_get_status($qid)

Given a qid this function returns the status of that poll according to a hash.  
Right now this function acts as follows:
If its a current poll return 'C', an attached poll -E<gt> 'A', or only in section
 -E<gt> 'S'.
Thats all this has support for now (well, actually it only has support for current
poll, but the rest will come soon.
This output is used to color code the polls in the poll listing page, similar to
the story listing.

=back

=cut

sub _get_status {
	my $S = shift;
	my $qid = shift;
	my $status;

	if( $qid eq $S->_get_current_poll ) {
		$status = 'current';
	} elsif( $S->get_sid_from_qid($qid) ) {
		$status = 'attached';
	}

	return $status;
}


=pod

=over 4

=item *
_get_current_poll()

This returns the qid of the current poll.

=back

=cut

sub _get_current_poll {
	my $S = shift;
	my $retval;

	# get the poll qid
	my ($rv, $sth) = $S->db_select( {
			DEBUG 	=> 0,
			WHAT 	=> "name, value",
			FROM 	=> 'vars',
			WHERE	=> "name='current_poll'",
			});

	unless ($rv) {
		return 0;
	}

	$retval = $sth->fetchrow_hashref->{'value'};
	$sth->finish;
	return $retval;
}


=pod

=over 4

=item *
_can_vote($qid)

This function returns 1 if the user can vote.  The user can vote if they have
the correct permission ('poll_vote') and they havn't already voted
on this poll

=back

=cut

sub _can_vote {
	my $S = shift;
	my $qid = shift;

	return 0 unless ($S->have_perm('poll_vote')); 

	return 0 if ($S->_is_poll_archived($qid));

	$qid = $S->{DBH}->quote($qid);
	
	my $where = "qid=$qid";
	
	# if they are anon, check the ip as well
	if( $S->{GID} eq 'Anonymous' ) {
		$where .= " AND user_ip='$S->{REMOTE_IP}'";
	}

	$where .= " AND uid='$S->{UID}' ";

	my ($rv, $sth) = $S->db_select({
		DEBUG	=> 0,
		WHAT	=> 'COUNT(*)',
		FROM	=> 'pollvoters',
		WHERE	=> $where,
		});

	my $voted = $sth->fetchrow();
	$sth->finish;
	# warn "Voted: <<$voted>>\n";

	# if the select succeeds they have already voted
	return 0 if( $voted );

	# we don't want them to be able to vote on polls that are attached to
	# stories that are still in editing
	($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		WHAT	=> 'COUNT(*)',
		FROM	=> 'stories',
		WHERE	=> "attached_poll = $qid AND displaystatus = -3",
		});

	$voted = $sth->fetchrow();
	$sth->finish();

	return 0 if( $voted );

	# otherwise, they're ok to vote, so return true
	# warn "Returning 1\n";
	return 1;
}

sub _is_poll_multiple_choice {
	my $S = shift;
	my $qid = shift;

	# Always false if the admin disables it, else check the DB
	return 0 unless $S->{UI}->{VARS}->{allow_multiple_choice};

	my $multiple_choice;

	$qid = $S->{DBH}->quote($qid);

	my $where = "qid=$qid";

	my ($rv, $sth) = $S->db_select({
		DEBUG   => 0,
		WHAT    => 'is_multiple_choice',
		FROM    => 'pollquestions',
		WHERE   => $where,
		});

	$multiple_choice = $sth->fetchrow();
	$sth->finish();

	return $multiple_choice;
}


sub _is_poll_archived {
	my $S = shift;
	my $qid = shift;
	my $archived;

	$qid = $S->{DBH}->quote($qid);

	my $where = "qid=$qid";

	my ($rv, $sth) = $S->db_select({
		DEBUG   => 0,
		WHAT    => 'archived',
		FROM    => 'pollquestions',
		WHERE   => $where,
		});

	$archived = $sth->fetchrow();
	$sth->finish();
	#warn "Poll Archived: $archived\n";

	return $archived;
}

sub _get_poll_title {
	my $S = shift;
	my $qid = shift;
	
	if ($S->{POLLS}->{$qid}->{question}) {
		return $S->{POLLS}->{$qid}->{question};
	}

	$qid = $S->dbh->quote($qid);
	my ($rv, $sth) = $S->db_select({
		WHAT => 'question',
		FROM => 'pollquestions',
		WHERE => qq|qid = $qid|});
	
	my $title = $sth->fetchrow();
	$sth->finish();
	# Save for later
	$S->{POLLS}->{$qid}->{question} = $title || undef;
	return $title;
}

sub poll_archive {
	my $S = shift;
	my $age = $S->{UI}->{VARS}->{poll_archive_age};
	
	if ($age <= 0) {
		return;
	}
	
	my ($rv, $sth) = $S->db_select({
		DEBUG => 0,
		WHAT => 'qid',
		FROM => 'pollquestions',
		WHERE => '(to_days(post_date) + '.$age.') < to_days(now()) AND archived <> 1'
		});
	my $polls;
	my ($rv2, $sth2);

	while ( $polls = $sth->fetchrow_hashref ) {
		#warn "Archiving poll : ".$polls->{qid};
		($rv2, $sth2) = $S->db_update({
			DEBUG => 0,
			WHAT => 'pollquestions',
			SET => qq|archived = 1|,
			WHERE => qq|qid = '$polls->{qid}'|});
		$sth2->finish();
		if ($rv2) {
			($rv2, $sth2) = $S->db_delete({
				DEBUG => 0,
				FROM => 'pollvoters',
				WHERE => qq|qid = '$polls->{qid}'|});
			$sth2->finish();
		}
	}


	$sth->finish();
}

1;
