=head1 Polls.pm

This is the main polling module.  It has 4 functions, 1 of which is deprecated.
These functions are what are used to display the polls.  Various utilities relating
to polls are in Polls/Utils.pm, and functions to display forms for editing and creating
polls are in Polls/Forms.pm.  All poll admin and editing functions are in Admin/Polls.pm

=head1 Functions

Here are the prototypes and explanations of the functions

=cut

package Scoop;

use strict;
my $DEBUG = 0;

=pod

=over 4

=item *
just_vote()

This is so that if they haven't voted on a poll, but they got to it from the Other Polls
link.  It just displays the poll box in the place where story_summary usually would be

=back

=cut

sub just_vote {
	my $S = shift;

	$S->{UI}->{BLOCKS}->{subtitle} = 'Vote: ';
	
	my $qid = $S->{CGI}->param('qid');
	
	my $poll = $S->box_magic('poll_box', $qid); #$S->poll_box($qid);
	
	$S->{UI}->{BLOCKS}->{STORY} .= $poll;
	my $comments = $S->display_comments($qid, '0');
	
	$S->{UI}->{BLOCKS}->{CONTENT} .= $S->comment_controls($qid, 'top');
	$S->{UI}->{BLOCKS}->{CONTENT} = qq|$comments|;
	$S->{UI}->{BLOCKS}->{CONTENT} .= $S->comment_controls($qid, 'top');
	
	return;
}


=pod

=over 4

=item *
poll_listing()

This function generates the Other Polls page.
DEPRECATED -- Will be replaced by the Polls choice on the Search page
On the other hand, use it if you want to stress test your db :-)

=back

=cut

sub poll_listing {
	my $S = shift;


	my $polllist = "";
	my ($rv, $sth) = $S->db_select({
		DEBUG	=> $DEBUG,
		WHAT	=> 'qid, question',
		FROM	=> 'pollquestions',
	});	
	
	if( $rv ) {
		while( my $row = $sth->fetchrow_hashref ) {
			$polllist .= qq|
				<tr><td width="50%">%%norm_font%%$row->{'question'}%%norm_font_end%%</td>
					<td>%%norm_font%%[ |;

			# only show the vote stuff if they can vote:
			if( $S->_can_vote($row->{'qid'}) ) {
				$polllist .= qq|
						<a href="%%rootdir%%/?op=poll_vote;qid=$row->{'qid'}">Vote</a> \| |;
			}
			$polllist .= qq|<a href="%%rootdir%%/?op=view_poll;qid=$row->{'qid'}">Results</a> ]</font></td></tr>|;
		}
	}
	$sth->finish;

	my $page .= qq|
		<TABLE CELLPADDING=0 CELLSPACING=2 BORDER=0 width="100%">
		<table width="100%" cellpadding="0" cellspacing="0" border="0">
		<tr><td bgcolor="%%title_bgcolor%%" colspan="2">%%title_font%%<b>Polls</b></font></td></tr>
		$polllist
		</TABLE>|;
	
	$S->{UI}->{BLOCKS}->{CONTENT} .= $page;
	
	return;
}


=pod

=over 4

=item *
poll_focus_view()

This is a version of Views.pm::focus_view() hacked up for displaying polls.
This function gets the page layout all set up, gets the blocks in order, etc.
The main displaying of the poll is handled by display_poll.

=back

=cut

sub poll_focus_view {
	my $S = shift;


	my $mode = $S->{CGI}->param('mode');
	my $qid = $S->{CGI}->param('qid');

	warn "Using qid $qid in poll_focus_view" if $DEBUG;

	my $comments;

	unless ( $S->_does_poll_exist( $qid ) ) {
		$S->{UI}->{BLOCKS}->{CONTENT} .= qq|
    	    <TR><TD>%%norm_font%%<B>Sorry. I can\'t seem to find poll "$qid".</B>%%norm_font_end%%</TD></TR>
	    </TABLE>|;  #'
		return;
	}

	my $poll = $S->display_poll($qid);

	$S->{UI}->{BLOCKS}->{STORY} .= $poll;

	$comments = $S->display_comments($qid, '0');

	# if its attached to a story, then make sure all comments and stuff post to that story
	if( $S->get_sid_from_qid($qid) ) {
		$qid = $S->get_sid_from_qid($qid);
	} else {
		# not attached to a story, so update the seen record
		$S->update_seen_if_needed($qid);
	}

	#$S->{UI}->{BLOCKS}->{CONTENT} .= $S->story_nav($qid);
	#$S->{UI}->{BLOCKS}->{CONTENT} .= '<TR><TD>&nbsp;</TD></TR>';

	$S->{UI}->{BLOCKS}->{CONTENT} .= $S->comment_controls($qid, 'top');
	$S->{UI}->{BLOCKS}->{CONTENT} .= qq|$comments|;
	if ($comments) {
		#$S->{UI}->{BLOCKS}->{CONTENT} .= '<TR><TD>&nbsp;</TD></TR>';
		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->comment_controls($qid, 'top');
	}

	return;
}


=pod

=over 4

=item *
display_poll($qid)

Takes the qid of a poll to display and displays it neatly.  This is what creates
the pollbars and shows the percentages. It also gets the comment display set up. 

=back

=cut

sub display_poll {
	my $S = shift;
	my $qid = shift;

	# if they don't have permission to view polls on this site, let them know
	unless( $S->have_perm('view_polls') ) {
		# looks odd when they view a poll's comments but don't have permission to view the poll.  So return nothing
		#return q|<B>%%norm_font%%Sorry, you don't have permission to view polls on this site%%norm_font_end%%</B>|;
		return '';
	}

	#Make sure comment controls are set
	#$S->_set_comment_mode();
	#$S->_set_comment_order();
	#$S->_set_comment_rating_thresh();
	#$S->_set_comment_type();

	#my $rating_choice;
	#$S->_set_comment_rating_choice();
 
	my $rating_choice = $S->get_comment_option('ratingchoice');
 
	# if they're voting update tables, otherwise do nothing

	my $tovote = $S->{CGI}->param('vote');
	if( $tovote && $tovote eq "Vote"  && $S->_can_vote($qid)) {
		# if they didn't choose anything just display results
		unless ( $S->{CGI}->param('aid') eq "" ) {
			# otherwise call vote handler	
			$S->_update_votes($qid, $S->{CGI}->param('aid'));
		}
	}

	# get and store the poll question and # of votes
	my ($question, $totalvotes, $actual_totalvotes);
	my ($rv, $sth) = $S->db_select({
		DEBUG => $DEBUG,
		FROM  => 'pollquestions',
		WHAT  => 'question, voters',
		WHERE => "qid='$qid'",
	    });

	# Maybe I should check $rv here, but I'll add that later
	my $qhash = $sth->fetchrow_hashref;
	$sth->finish;
	$question = $qhash->{'question'};
	$totalvotes = $actual_totalvotes = $qhash->{'voters'};
	
	# Set the title to the poll question
	$S->{UI}->{BLOCKS}->{subtitle} = $question;
	$S->{UI}->{BLOCKS}->{subtitle} =~ s/<.*?>//g;

	($rv, $sth) = $S->db_select({
		DEBUG => $DEBUG,
		FROM  => 'pollanswers',
		WHAT  => 'aid, answer, votes',
		WHERE => "qid='$qid'",
				ORDER_BY => "aid ASC"
    	});
	my $pollimage = "";
	my $poll_img = $S->{UI}->{BLOCKS}->{poll_img};

	# The var poll_image_width stores the width of the 100% mark for a poll
	while (my $answerhash = $sth->fetchrow_hashref) {
		# so we don't get a "dividing by zero' error
		($totalvotes = 1 ) if ($totalvotes == 0);
		my $voteword = 'votes';
		if ($answerhash->{'votes'} == 1) {
			$voteword = 'vote';
		}
	
		my $full_width = $S->{UI}->{BLOCKS}->{poll_img_width} || 300;
	
		my $width = $answerhash->{'votes'} / $totalvotes;  
	 	my $imagewidth = $width * $full_width;
		if ($imagewidth == 0 ) {
			$imagewidth = 1;
		} 
		$width = int ($width * 100);

		$pollimage .= qq|			
		    <tr>
			<td align="right">%%norm_font%%$answerhash->{'answer'}<spacer type="horizontal" size=20></TD>
		    <td>
			    |;

		if( $poll_img )
		{
		    $pollimage .= qq|
			%%norm_font%%
			    <img src="%%imagedir%%/$poll_img" width="$imagewidth" height="15">
&nbsp;&nbsp;$answerhash->{'votes'} $voteword - $width %
    %%norm_font_end%%
	|;
		} else {
		    $pollimage .= qq|

			    <table bgcolor=red width="$imagewidth" height=15><tr><td>&nbsp;</td></tr></table>
%%norm_font%%
<!--img src="%%imagedir%%/$poll_img" width="$imagewidth" height="15"-->
&nbsp;&nbsp;$answerhash->{'votes'} $voteword - $width %
    </font>|;
		}
		$pollimage .= qq|</td></tr>|;

	}
	$sth->finish;

	$pollimage .= qq|
		<tr><td align="center" colspan="2">&nbsp;</TD></TR>
		<tr><td align="center" colspan="2">%%norm_font%%$actual_totalvotes Total Votes%%norm_font_end%%</td></tr>|;

	my $page = $S->{UI}->{BLOCKS}->{'poll_block'};
	$page =~ s/%%title%%/$question/g;
	$page =~ s/%%poll_image%%/$pollimage/;
	
	return $page;
}


1;

