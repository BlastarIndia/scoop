=head1 Polls.pm

This contains all of the main functions for editing polls.  Some of the functions called to 
generate parts of the forms are in Scoop/Polls/Forms.pm, and some of the random functions
called to get qid's, sid's, etc. are in Scoop/Polls/Utils.pm

=head1 Functions

This is just a quick overview of all of the functions.  

=cut

package Scoop;

use strict;
my $DEBUG = 0;

=pod

=over 4

=item *
admin_polls($message)

This function generates the Poll List page.  $message is for when you delete or 
something happens.  It is displayed in red at the top of the page.
The functionality is a cut and paste from story_list minus the moderation stuff.

=back

=cut

sub admin_polls {
	my $S = shift;
	my $message = shift;
	my $op = $S->{CGI}->param('op');
	my $tool = $S->{CGI}->param('tool');
	my $page = $S->{CGI}->param('page') || 1;
	my $next_page = $page + 1;
	my $last_page = $page - 1;
	my $num = $S->{UI}->{VARS}->{storylist};
	my $limit;
	my $get_num = $num + 1;
	my $offset = ($num * ($page - 1));

	if ($page > 1) {
		$limit = "$offset, $get_num";
	} else {
		$limit = "$get_num";
	}
	
	my ($content, $select, $last_col);
	
	$select = {
		DEBUG => 0,
		WHAT => qq|qid, question, voters, post_date|,
		FROM => 'pollquestions',
		LIMIT => "$limit",
		ORDER_BY => 'post_date DESC'};
	$last_col = '&nbsp;';
	
	$content = qq|
	<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=100%>
	<TR>
	<TD COLSPAN=4 BGCOLOR="%%title_bgcolor%%">%%title_font%%<B>Polls Listing</B>%%title_font_end%%</TD>		</TR>|;

	$content .= qq|
		<TR><TD COLSPAN=4><FONT face="%%norm_font_face%%" size="%%norm_font_size%%" color="FF0000">$message&nbsp;</FONT></TD></TR>
			|;

	$content .= qq|
	<TR><TD COLSPAN=4>&nbsp;</TD></TR>
	<TR BGCOLOR="%%title_bgcolor%%">
	<TD valign="top">%%title_font%%<B>Title</B>%%title_font_end%%</TD>
	<TD valign="top">%%title_font%%<B>Date</B>%%title_font_end%%</TD>
	<TD align="center" valign="top">%%title_font%%<B>&nbsp;</B>%%title_font_end%%</TD>
	<TD valign="top">%%title_font%%$last_col%%title_font_end%%</TD>
	</TR>|;

	my ($rv, $sth) = $S->db_select($select);
	
	my $color;
	my $i = 1;
	my $qid;
	my $qid_num;
	$qid = $sth->fetchrow_hashref;
	
	my ($question, $vote_count, $date, $del_link, $edit_link);

	my $bgcolors = { current	=> '%%undisplayedstory_bg%%',
					 attached	=> '%%submittedstory_bg%%',
					};
	
	while ($i <= $num && $qid) {
		$vote_count = qq| ($qid->{voters} Votes)|;
		my $status = $S->_get_status($qid->{qid});
		my $color = $bgcolors->{$status};
		#my $is_current = ( $S->_get_current_poll eq $qid->{qid} ? 1 : 0 );
		my $change_option;

		$del_link = qq|(<A HREF="%%rootdir%%/admin/editpoll?editqid=$qid->{qid};delete=Delete">delete</A>)|;
		$edit_link = qq|<A HREF="%%rootdir%%/admin/editpoll?editqid=$qid->{qid}">$qid->{question}</a>|;
		
		$color = qq| BGCOLOR="$color"|;

		if( $qid->{qid} eq $S->_get_current_poll() ) { 
			$change_option = qq| (<A HREF="%%rootdir%%/admin/editpoll?editqid=$qid->{qid};option=UndoMain">Remove from Main</A>)|;

		} elsif ( $status eq 'attached' ) {
			$change_option = qq| (<A HREF="%%rootdir%%/admin/editpoll?editqid=$qid->{qid};option=Unattach">Unattach</A>)|;

		} else {
			$change_option = qq| (<A HREF="%%rootdir%%/admin/editpoll?editqid=$qid->{qid};option=MakeMain">make main</A>)|;
		}
		
		$qid_num = $offset + $i;
		
		$content .= qq|
		<TR $color>
			<TD valign="top">%%norm_font%%$qid_num) $edit_link $vote_count [<A HREF="%%rootdir%%/?op=poll_vote;qid=$qid->{qid}">Vote</A>]%%norm_font_end%%</TD>
			<TD valign="top">%%norm_font%%$qid->{post_date}%%norm_font_end%%</TD>
			<TD align="center" valign="top">%%norm_font%%$change_option%%norm_font_end%%</TD>
			<TD valign="top">%%norm_font%%$del_link%%norm_font_end%%</TD>
		</TR>|; # "
		$i = $i+1;
		$qid = $sth->fetchrow_hashref;
	}
	$sth->finish;
	
	$content .= qq|
		<TR><TD COLSPAN=4>&nbsp;</TD></TR>
		<TR>
			<TD COLSPAN=2>%%norm_font%%<B>|;
	if ($last_page >= 1) {
		$content .= qq|&lt; <A HREF="%%rootdir%%/$op/$tool?page=$last_page">Last $num</A>|;
	} else {
		$content .= '&nbsp;';
	}
	$content .= qq|</B>%%norm_font_end%%</TD>
		<TD ALIGN="right" COLSPAN=2>%%norm_font%%<B>|;
	
	if ($rv >= ($num + 1)) {
		$content .= qq|
		<A HREF="%%rootdir%%/$op/$tool?page=$next_page">Next $num</A> &gt;%%norm_font_end%%|;
	} else {
		$content .= '&nbsp;';
	}
	
	$content .= qq|</B>%%norm_font_end%%</TD>
	</TR>|;
	
	
		
	$content .= qq|
		</TABLE>|;
	
	return $content;
}


=pod

=over 4

=item *
edit_polls()

This is the main function that displays the Edit Polls page.  This is what generates
the form you see when you write a new poll.  It used to be huge, now it just makes a whole
lot of calls to functions that each do a bit of what needs to be done.

=back

=cut

sub edit_polls {
	my $S = shift;

	my $write = $S->{CGI}->param('writepoll');
	my $delete = $S->{CGI}->param('delete');
	my $option = $S->{CGI}->param('option');

	my ($rv, $sth);
	my $content;
	my $editqid = $S->{CGI}->param('editqid') || $S->_generate_unique_qid();
	
	# for now $qid == $editqid;  I'll clean this up later
	my $qid = $editqid;
	my $unquote_qid = $qid;
	$qid = $S->{DBH}->quote($qid);

	my $message;

	# skip is so that I don't store the answers to a poll that has a bad qid
	my $update_answers = 0;
	my $current_time = $S->_current_time;	

	# These next if and elsifs decide what action the user wants to take
	# and delegates authority appropriatly.  This all deal with updating
	# the database in some way. 
	if ( $delete && $delete eq "Delete" && $editqid ne '') {

		# if they want to delete it, do it!
		$message .= $S->_delete_poll( $editqid );	
		return $S->admin_polls($message);

	} elsif( $write && $write eq "Write Poll" && ! $S->_does_poll_exist($unquote_qid) ) {

		# ok, they are writing a new poll, so call the write_new_poll function
		$update_answers = $S->_write_new_poll;

		# so that if they create a new page, it reloads with the info they just made
		if( $update_answers ) {
			$editqid = $unquote_qid;
		}

	} elsif( $write && $write eq "Write Poll" ) {

		# they are just updating a current poll, fix accordingly	
		$update_answers = $S->_update_poll;
	} elsif( $option && $option eq 'MakeMain' ) {
		
		# make this the main poll
		$message .= $S->_make_main_poll( $editqid );
		return $S->admin_polls($message);
	} elsif( $option && $option eq 'UndoMain' ) {
		
		# remove the poll from the main page
		my ($rv, $sth) = $S->db_update({
						DEBUG	=> 0,
						WHAT	=> 'vars',
						SET		=> "value=''",
						WHERE	=> "name='current_poll'",
					});
		$S->cache->stamp('vars');
		my $question = $S->get_poll_hash($editqid)->{'question'};

		return $S->admin_polls( "Poll \"$question\" has been removed from the main page." );
	} elsif( $option && $option eq 'Unattach' ) {

		# de-attach
		my ($rv, $sth) = $S->db_update({
                        DEBUG   => 0,
                        WHAT    => 'stories',
						SET		=> 'attached_poll=NULL',
						WHERE	=> qq| attached_poll=$qid |,
					});

		my $question = $S->get_poll_hash($editqid)->{'question'};

        return $S->admin_polls( "Poll \"$question\" has been un-attached from its story." );
	}

	# If we have written the poll, check to see if its "main" state matches the "Make main"
	# checkbox.  If it doesn't, update the current_poll var.
	if( $write && $write eq "Write Poll" ) {
		my $makemain = $S->{CGI}->param('makemain');
		my $is_current = ($editqid eq $S->_get_current_poll());
		if ($makemain != $is_current) {
			if ($makemain) {
				$S->_make_main_poll( $editqid );
			} else {
				my ($rv, $sth) = $S->db_update({
						DEBUG	=> 0,
						WHAT	=> 'vars',
						SET		=> "value=''",
						WHERE	=> "name='current_poll'",
					});
				$S->cache->stamp('vars');
			}
		}
	}

	# update answers unless the update or create poll didn't go through,
	# i.e. invalid input into form
	if( $update_answers ) {
		$S->_update_poll_answers($unquote_qid);
	}

	# Get the Edit Poll form set up
	my $title;
	if( $S->_does_poll_exist( $editqid )) {
		my $question = $S->get_poll_hash($editqid)->{'question'};
		$title = "Edit Poll \"$question\"";
	} else {
		$title = "New Poll";
	}

	$content .= qq| <FORM name="editpolls" action="%%rootdir%%/" method="POST">
		<INPUT type="hidden" name="op" value="admin">
		<INPUT type="hidden" name="tool" value="editpoll">
		<table border=0 cellpadding=0 CELLSPACING=2 WIDTH=100%>
		<TR>
			<TD BGCOLOR="%%title_bgcolor%%"> %%title_font%%<B>$title </B>%%title_font_end%%</TD>
		</TR>
		<TR>
			<TD>%%title_font%%<FONT COLOR="#FF0000">$message %%title_font_end%%</TD>
		</TR>|;

	# Make the "menu" portion of the page
	$content .= $S->_make_edit_chooser($editqid);

	# Make the input area, where they choose the question etc.
	# and fill in with correct values
	my ($tmp_content, $qid_not_used) = $S->_make_edit_input("normal",$editqid);
	# FIXME: html in code here. I'm not fixing it because I already have enough 
	# changes in this particular patch. --R
	$content .= qq|<TR><TD>%%norm_fonr%%$tmp_content|;

	# Make the answer area, and fill in with correct values
	$content .= $S->_make_edit_answers("normal",$editqid);

	# End the table and form
	$content .= qq| </TD></TR></TABLE></FORM> |;

	return $content;
}


=pod

=over 4

=item *
write_attached_poll($sid)

This takes a sid and writes the poll as a new poll or updates it, whichever is appropriate.
It also sets it up so that it is attached to the story identified by $sid. 

=back

=cut

sub write_attached_poll {
	my $S = shift;
	my $sid = shift;
	my $eiq = shift;  # edit in queue flag

	my $newqid = $S->{CGI}->param('qid');

	my $exists = ( $S->_does_poll_exist($newqid) ? 1 : 0 );
	
	# don't let them update a poll that already exists from here if they don't
	# have edit_polls permission, or if they are not editing their story in teh queue
	return 0 if ( $exists && !( $S->have_perm('edit_polls') || $eiq ) ); 

	my $retval = 0;

	if( $exists ) {
		$retval = $S->_update_poll;
	} else {
		$retval = $S->_write_new_poll;
	}

	if( $retval ) {
		$S->_update_poll_answers($newqid);

		# quote stuff
		$newqid = $S->{DBH}->quote($newqid);
		$sid = $S->{DBH}->quote($sid);

		# attach it.
		my ($rv,$sth) = $S->db_update({
							DEBUG	=> 0,
							WHAT	=> 'stories',
							SET		=> qq| attached_poll=$newqid |,
							WHERE	=> qq| sid=$sid |,
						});
	}

	return $retval;
}


=pod

=over 4

=item *
_generate_unique_qid()

This function generates and returns a unique qid.  So that admins don't have to mess with
making a unique one themselves

=back

=cut

sub _generate_unique_qid {
	my $S = shift;
	my $qid;

	do {
		my $time = time();
		my $random = $S->_random_pass();
		$qid = $time . "_" . $random;
	} 
	while( $S->_does_poll_exist($qid) );

	# make sure its only 20 char long
	$qid = substr($qid, 0, 20);

	warn $qid if $DEBUG;

	return $qid;
}


=pod

=over 4

=item *
_delete_poll($qid)

Given a poll qid this function will delete that poll.  It deletes the poll question,
the poll answers, all of the votes for the poll, and all of the comments dealing with
that poll.  Now with attached polls it deletes its being attached to any story. It also
deletes that poll from the cache that says that the poll $qid exists.

=back

=cut

sub _delete_poll {
	my $S = shift;
	my $unquote_qid = shift;
	my $qid = $S->{DBH}->quote($unquote_qid);

	# test the permission
	(return 0) unless ($S->have_perm('edit_polls'));

	# delete from pollquestions
	$S->db_delete({
		DEBUG	=> 0,
		FROM	=> 'pollquestions',
		WHERE	=> qq|qid=$qid|
	});

	# delete from pollanswers
	$S->db_delete({
		DEBUG	=> 0,
		FROM	=> 'pollanswers',
		WHERE	=> qq|qid=$qid|
	});

	# delete voter records
	$S->db_delete({
		DEBUG	=> 0,
		FROM	=> 'pollvoters',
		WHERE	=> qq|qid=$qid|
	});

	# delete comments
	$S->db_delete({
		DEBUG	=> 0,
		FROM	=> 'comments',
		WHERE	=> qq|sid=$qid|
	});

	# remove where it is attached
	$S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'stories',
		SET	=> "attached_poll=''",
		WHERE	=> qq|attached_poll=$qid|,
	}); 

	# Don't forget to remove it from the cache as well
	#$S->cache()->set("poll_$unquote_qid", undef);

	my $message = qq|Deleted poll "$unquote_qid"|;

	return $message;
}


=pod

=over 4

=item *
_write_new_poll()

This function writes a new poll to the db if that poll qid doesn't already exist.
It returns 0 if it fails, and 1 if it succeeds.

=back

=cut

sub _write_new_poll {
	my $S = shift;

	my $current_time = $S->_current_time;
	my $qid = $S->{CGI}->param('qid');
#	my $qid = $S->_generate_unique_qid();
	my $newqid = $S->dbh->quote($qid);

	return 0 if ($qid eq "");

	# so we don't create duplicate polls I won't let them
	# create a new poll with an already used qid
	if ( $S->_does_poll_exist( $qid ) ) {
		return 0; 
	}
 
	my $voters;
	for(my $num=1; $num<= $S->{UI}->{VARS}->{poll_num_ans}; $num++) {
		$voters += $S->{CGI}->param('votes' . $num);
	}
	
	# Dont' create the poll unless there's a question.
	my $question = $S->{CGI}->param('question');
	return 0 unless $question;
	
	# escape all html in the polls
	$question = $S->filter_subject($question);

	$question = $S->dbh->quote($question);
	$current_time = $S->dbh->quote($current_time);
	$voters = $S->dbh->quote($voters);

	my $is_multiple_choice = $S->cgi->param('is_multiple_choice') ? 1 : 0;
	$is_multiple_choice = 0 unless ( $S->var('allow_multiple_choice') );

	my ($rv, $sth) = $S->db_insert({
		DEBUG   => 0,
		INTO    => 'pollquestions',
		VALUES  => qq|$newqid, $question, $voters, $current_time, 0, $is_multiple_choice |,
	});
	$sth->finish;

	# if they want it on the main page, do it!
	if( $S->{CGI}->param('maindisplay') ) {
		($rv, $sth) = $S->db_update({
			DEBUG   => 0,
			WHAT    => 'vars',
			SET     => "value=$newqid",
			WHERE   => "name='current_poll'",
		});
		$sth->finish;
		
		# And reload the vars cache
		$S->cache->clear({resource => 'vars', element => 'VARS'});
		$S->cache->stamp('vars');
		$S->_set_vars();
		$S->_set_blocks();
	}

	return 1;
}


=pod

=over 4

=item *
_update_poll()

This function takes some input from the edit Polls page and updates the poll in
the database.  It gets all of its data from the form that calls edit_polls on
submit.  Returns 1 if it succeeds, 0 if it fails.

=back

=cut

sub _update_poll {
	my $S = shift;

	my $current_time = $S->_current_time;
	my $editqid = $S->cgi->param('editqid');
	my $newqid = $S->cgi->param('qid');
	my $question = $S->cgi->param('question');
	# Quote stuff for the DB's pleasure
	$question = $S->filter_subject($question);
	$question = $S->dbh->quote($question);
	$editqid = $S->dbh->quote($editqid);
	$newqid = $S->dbh->quote($newqid);
	$current_time = $S->dbh->quote($current_time);
	my $set = qq| qid = $newqid, question = $question, post_date=$current_time|; 

	# The next couple of lines count the number of votes set by the admin
	# but we all know this could just be $voters=0 since no scoop using admin
	# would _ever_ doctor a poll ;-)
	
	my $is_multiple_choice = $S->{CGI}->param('is_multiple_choice')?1:0;

	my $voters = 0;

	# make sure they can't set # votes unless they are an admin 
	if ($S->have_perm('edit_polls') && $S->{UI}->{VARS}->{allow_ballot_stuffing}) {
		for(my $num=1; $num<= $S->{UI}->{VARS}->{poll_num_ans}; $num++) {
			my $vote_count = 'votes' . $num;
			my $these_votes = $S->{CGI}->param($vote_count);
			$voters += int $these_votes;
		}
		$set .= qq|, voters = "$voters"|;
	} else {
		$voters = 0;
	}
	$set .= ", is_multiple_choice=$is_multiple_choice" if ($S->{UI}->{VARS}->{allow_multiple_choice});

	# update pollquestions
	my ($rv, $sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'pollquestions',
		SET	=> $set,
		WHERE	=> qq|qid=$editqid|,
	});
	$sth->finish;

	# update pollanswers so we don't leave unmatched answers in the db
	($rv, $sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'pollanswers',
		SET	=> qq| qid = $newqid|,
		WHERE	=> qq|qid=$editqid|,
	});
	$sth->finish;

	# return sucessfully
	return 1;
}


=pod

=over 4

=item *
_update_poll_answers($qid)

Takes a poll qid and updates all of the answers for it in the db.  It gets its input
from the form that calls edit_polls and from the attached poll form.  

=back

=cut

sub _update_poll_answers {
	my $S = shift;
	my $newqid = shift;
	my $quoted_qid = $S->{DBH}->quote($newqid);
	my $editqid = $S->{CGI}->param('editqid');
	my ($rv, $sth);
	my $aid;

	for($aid = 1; $aid <= $S->{UI}->{VARS}->{'poll_num_ans'}; $aid++ ) {
		my $answer = $S->{CGI}->param("answer" . $aid);
		my $votes = $S->{CGI}->param("votes" . $aid) || 0;
		my $setvotes = 0;
		# make sure they can't set # votes unless they are an admin 
		if ($S->have_perm('edit_polls') && $S->{UI}->{VARS}->{allow_ballot_stuffing}) {
			$setvotes = 1;
		} else {
			$votes = 0;
		}

		last if ( $answer eq "" );

		# don't forget to quote $answer, $votes
		$answer = $S->{DBH}->quote($answer);
		$votes = $S->{DBH}->quote($votes);

		# make sure they can't put html in the answer
		$answer = $S->filter_subject($answer);

		# there is probly a cleaner way of doing this... 
		($rv, $sth) = $S->db_select( {
			DEBUG	=> 0,
			FROM	=> 'pollanswers',
			WHAT	=> 'answer',
			WHERE	=> "qid=$quoted_qid AND aid='$aid'",
		});
		$sth->finish;

		# if the select works, there is already a matching aid/qid answer,
		# so just update, else insert the new answer
		if($rv == 1) {
			
			my $set = qq|answer=$answer|;
			$set .= qq|, votes=$votes| if ($setvotes);
			
			($rv, $sth) = $S->db_update({
				DEBUG	=> 0,
				WHAT	=> 'pollanswers',
				SET	=> $set,
				WHERE	=> qq|qid=$quoted_qid and aid=$aid|,
			});
			$sth->finish;

		} else {
			($rv, $sth) = $S->db_insert({
				DEBUG   => 0,
				INTO    => 'pollanswers',
				COLS    => qq|qid, aid, answer, votes|,
				VALUES  => qq|$quoted_qid, $aid, $answer, $votes|,
			});
			$sth->finish;
		}
	}

	# This checks and removes all answers greater than $aid, just in case
	# the admin removes an answer
	for( ; $aid <= $S->{UI}->{VARS}->{'poll_num_ans'}; $aid++ ) {
		($rv, $sth) = $S->db_delete({ 
			DEBUG	=> 0,
			FROM	=> 'pollanswers',
			WHERE	=> qq|qid=$quoted_qid AND aid=$aid|,
		});
	}

}


=pod

=over 4

=item *
_make_main_poll($qid)

This takes a qid and sets the var 'current_poll' to that qid so that that 
poll is displayed on the main page

=back

=cut

sub _make_main_poll {
	my $S = shift;
	my $qid = shift;
	my $quoteqid = $S->{DBH}->quote($qid);
	my $message;

	my ($rv, $sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'vars',
		SET		=> "value=$quoteqid",
		WHERE	=> "name='current_poll'",
	});
	$sth->finish;

	if ($rv) {

		my $question = $S->get_poll_hash($qid)->{'question'};
		$message = qq| Set poll "$question" to display on main page |;
		$S->cache->stamp('vars');
	}

	return $message;
}


=pod

=over 4

=item *
_update_votes($qid, $aid)

This adds 1 to the vote count for the answer identified by question id $qid and 
answer id $aid.

=back

=cut

sub _update_votes {
	my $S = shift;
	my $qid = shift;
	my $aid = shift;
	my $userid = $S->{UID};
	my $aidclause;

	return unless $S->_can_vote($qid);

	if ($S->_is_poll_multiple_choice($qid)) {
		$aidclause = 'aid in ('.join (', ', map { $S->{DBH}->quote($_) } $S->{CGI}->param('aid')).')';
	} else {
		$aidclause = 'aid = '.$S->{DBH}->quote($S->{CGI}->param('aid'));
	}
	
	# first update pollanswers
	my ($rv, $sth) = $S->db_update({
		DEBUG   => 0,
		WHAT	=> 'pollanswers',
		SET		=> 'votes = (votes + 1)',
		WHERE	=> "qid='$qid' and $aidclause",
		});
	return unless $rv;
	$sth->finish;

	# now update pollquestions
	($rv, $sth) = $S->db_update({
		DEBUG   => 0,
		WHAT    => 'pollquestions',
		SET     => 'voters = (voters + 1)',
		WHERE   => qq| qid='$qid'|,
		});
	return unless $rv;
	$sth->finish;

	# first get the user info
	my $nickname = 'anon';
	
	if ($userid > 0) {
		$nickname = $S->get_nick($userid);
	}
	
	my $q_nick = $S->{DBH}->quote($nickname);
	my $ip = $S->{REMOTE_IP};
	my $time = $S->_current_time();

	
	# now store the fact that they voted in the db
	($rv, $sth) = $S->db_insert({
		DEBUG	=> 0,
		INTO	=> 'pollvoters',
		COLS	=> 'qid, id, time, uid, user_ip',
		VALUES	=> qq|'$qid', $q_nick, '$time', '$userid', '$ip'|,
		});
	$sth->finish;

}

sub update_own_poll {
	my $S = shift;
	my $sid = shift;
	
	return 0 unless $sid;
	
	return 1 if (($S->have_perm('attach_poll') || $S->have_perm('edit_polls')) && $S->check_edit_story_perms($sid));

	return 0;
}

1;
