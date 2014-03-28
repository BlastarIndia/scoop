=head1 Forms.pm

This file contains all of the functions that generate the forms to create
and edit polls.  None of these generate the whole form, thats taken care
of in Admin/Polls.pm.  

=head1 Functions

Following is a listing of the functions and their usage

=cut

package Scoop;

use strict;
my $DEBUG = 0;


=pod

=over 4

=item *
make_attached_poll_form($sid)

This takes the sid of a story and makes the form at the bottom of the edit stories (or
 submit story)
page and fills it with the appropriate values. This is similar to edit_polls, but it d
oesn't make the
buttons at the top of the page, and its coded so it can be put inside another form.

=back

=cut

sub make_attached_poll_form {
	my $S = shift;
	my $action = shift;
	my $page = '';
	my $qid;

	# if the $sid eq 'preview'  Then set all the cgi params from the next parameter
	if( $action eq 'preview' ) {
		my $params = shift;
		$qid = $params->{qid};
	} else {
		my $sid = shift;
		$qid = $S->get_qid_from_sid($sid);
	}

	# now generate the question area
	my ($form, $nqid) = $S->_make_edit_input($action,$qid);
	$page .= $form;

	# now the answer stuff
	$page .= $S->_make_edit_answers($action,$nqid);

	return $page;
}


=pod

=over 4

=item *
_make_edit_chooser($qid)

This makes the "Write Poll" and "Edit Poll" buttons and menu on the edit
polls page.

=back

=cut

sub _make_edit_chooser {
	my $S = shift;
	my $unquote_qid = shift;
	my $is_current = ($unquote_qid eq $S->_get_current_poll());

	# this gets the write button etc. setup
	my $content .= qq| <TR>
		<TD>%%norm_font%%
		|;

	$content .= qq|
		<Input type="submit" name="writepoll" value="Write Poll">
		|;

	unless ($unquote_qid eq '') {
		$content .= qq|<INPUT type="submit" name="delete" value="Delete">
		|;
	}
	my $main_state = $is_current ? ' checked="checked"' : '';
    $content .= qq|<br><input type="checkbox" name="makemain" value="1"$main_state> Make main|;

	$content .= qq|
		</TD>
		</TR> |;

	return $content;
}


=pod

=over 4

=item *
_make_edit_input($action,$qid)

Given a poll qid this makes the top half of the edit polls form.  This is what displays
the date, the qid and question fields, and some of the hidden fields.  Note: this is in the process of getting rid of the qid field.  stuff might break in here :)  Returns an array!!!  Do not get tripped up on that!

=back

=cut

sub _make_edit_input {
	my $S = shift;
	my $action = shift;
	my $editqid = shift || $S->_generate_unique_qid();
	my $newqid = $S->{DBH}->quote($editqid);
	my $content;
	my ($rv, $sth);
	my $question;
	my $voters;
	my $last_write;
	my $is_multiple_choice_checked;

	## Generate the form depending on whether or not they are previewing
	if( $action eq 'preview' ) {
		# get info from $S->{CGI}
		$question = $S->{CGI}->param('question');
		$voters = $S->{CGI}->param('voters');
		$is_multiple_choice_checked = $S->{CGI}->param('is_multiple_choice') ? ' CHECKED' : '';

	} else {

		# first set up the question
		# skip it if $editqid is empty
		if( $S->_does_poll_exist($editqid) ) {
			($rv, $sth) = $S->db_select( {
				DEBUG   => 0,
				FROM	=> 'pollquestions',
				WHAT	=> qq|qid, question, voters, post_date, is_multiple_choice|,
				WHERE   => qq| qid=$newqid |,
			});
		} else {
			$rv = 0;
		}

		if ( $rv ) {
			my $rowhash = $sth->fetchrow_hashref;
			$question = $rowhash->{'question'};
			$voters = $rowhash->{'voters'};
			$last_write = $rowhash->{'post_date'};
			$is_multiple_choice_checked = $rowhash->{'is_multiple_choice'} ? ' CHECKED' : '';
			$sth->finish;
		}
	}


	# put in the date it was last updated and the story its attached to if it is
	# not a preview (i.e. an attached poll)
	unless ($editqid eq '' || $action eq 'preview') {
		$content->{last_update} = qq|This poll last updated on $last_write<br>|;

		if( my $sid = $S->get_sid_from_qid($editqid) ) {
			$content->{attached_to} = qq|This poll is attached to story <a href="%%rootdir%%/story/$sid">$sid</a><br>|;
		}
		if( $editqid eq $S->_get_current_poll() ) {
			$content->{current} = qq|This is the current poll.<br>|;
		}

	} 

	# escape the metachars  -- use the functions we have!
	#$question =~ s/"/&quot;/g;
	#$question =~ s/>/&gt;/g;
	#$question =~ s/</&lt;/g;
	
	$question = $S->filter_subject($question);

	# these should not be here, they can only break stuff.  Thus they are now commented out
	#$editqid =~ s/"/&quot;/g;
	#$editqid =~ s/>/&gt;/g;
	#$editqid =~ s/</&lt;/g;

	# qid is deprecated, it will be taken out later
	$content->{hidden_form_input} = qq|
		<INPUT type="hidden" name="editqid" value="$editqid">
		<INPUT type="hidden" name="qid" value="$editqid">
		<INPUT type="hidden" name="voters" value="$voters">|;
		
	$content->{question} = $question;
	
	my $form = $S->{UI}->{BLOCKS}->{poll_form_question};
	
	if ($S->{UI}->{VARS}->{allow_multiple_choice}) {
		$form =~ s/%%multiple_choice%%/$S->{UI}->{BLOCKS}->{poll_form_multi}/g;
		$content->{allow_multiple} = $is_multiple_choice_checked;
	}

	my $return = $S->interpolate($form, $content);
	return ($return, $editqid);
}


=pod

=over 4

=item *
_make_edit_answers($action,$qid)

This function sets up the answer field for the Edit Polls page.  It inserts the answer
s if
there are some, otherwise it leaves the input fields blank

=back

=cut

sub _make_edit_answers {
	my $S = shift;
	my $action = shift;
	my $newqid = shift;
	my $content;
	my $allow_ballot_stuffing = $S->{UI}->{VARS}->{allow_ballot_stuffing};
	my $have_perms = $S->have_perm('edit_polls');
	my $votes_input_type = ($allow_ballot_stuffing && $have_perms) ? "text" : "hidden";

	my @answers;

	# if your not an author you should never be able to stuff the ballot
	unless ( $S->have_perm('edit_polls') ) {
		$allow_ballot_stuffing = 0;
	}

	# if they have no qid to show generate a blank form
	if($newqid eq '') {
		for( my $j=1; $j<= $S->{UI}->{VARS}->{poll_num_ans}; $j++ ) {
			$content .= qq|
				<INPUT type="text" size="60" name="answer$j" value="">
				<INPUT type="$votes_input_type" size="3" name="votes$j" value=""><br>
				|;
		}

		return $content;
	}

	# Now generate the input in the form.  If they are previewing get it from
	# $S->{CGI}->param otherwise get it from the database
	if( $action eq 'preview' ) {
		for( my $j=1; $j <= $S->{UI}->{VARS}->{poll_num_ans}; $j++ ) {

			my $answer = $S->{CGI}->param('answer' . $j);
			my $votes = $S->{CGI}->param('votes' . $j);
			my $hash = {answer => "$answer",
						votes  => "$votes"};
			# get the answers and push them onto an array of hashes
			push(@answers, ($hash));

		}

	} else {

		# don't forget to quote the intput!
		my $quoted_qid = $S->{DBH}->quote($newqid);

		my ($rv, $sth) = $S->db_select( {
			DEBUG   => 0,
			FROM	=> 'pollanswers',
			WHAT	=> 'aid, answer, votes',
			WHERE   => qq| qid=$quoted_qid |,
			ORDER_BY => "aid ASC"
		});

		if($rv) {
			while( my $row = $sth->fetchrow_hashref ) {
				push(@answers, ($row));
			}
			$sth->finish;

		} else {
			$content .= 'select failed<BR>';
		}
	}

	my $i = 1;
	foreach my $answer ( @answers ) {
		# once again, use the functions that we have
		#$answer->{'answer'} =~ s/"/&quot;/g;
		#$answer->{'answer'} =~ s/>/&gt;/g;
		#$answer->{'answer'} =~ s/</&lt;/g;
		$answer->{'answer'} = $S->filter_subject($answer->{'answer'});
		$content .= qq|
			<INPUT type="text" size="60" name="answer$i" value="$answer->{'answer'}">
			<INPUT type="$votes_input_type" size="3" name="votes$i" value="$answer->{'votes'}"><br> 			|;
		$i++;
	}

	while ($i <= $S->{UI}->{VARS}->{poll_num_ans} ) {
		$content .= qq|
			<INPUT type="text" size="60" name="answer$i" value="">
			<INPUT type="$votes_input_type" size="3" name="votes$i" value=""><br> |;
		$i++;
	}

	return $content;
}




1;
