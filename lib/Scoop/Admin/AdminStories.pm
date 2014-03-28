=head1 AdminStories.pm

This is just a bit of documentation I've added in here while fixing a bug
that GandalfGreyhame first discovered in the wild
-Andrew

=head1 Functions

=cut


package Scoop;
use strict;
my $DEBUG = 0;

=pod

=over 4

=item *
edit_story()

This is what generates the Admin Edit Story form.  It takes no arguments, other than what
it gets from the form, through $S->{CGI}->param(). If the user wants to save the story, or 
update it, $S->save_story() is called. Otherwise the form is set up for more editing.

=back

=cut

sub edit_story {
	my $S = shift;
	warn "(edit_story) Starting..." if $DEBUG;
	# don't check for spellcheck perm here because fiddiling with params won't
	# do any damage
	if ($S->{CGI}->param('spellcheck')) {
		$S->param->{save} = undef;
		$S->param->{preview} = 'Preview';
	}

	my $sid = $S->{CGI}->param('sid');
	my $preview = $S->{CGI}->param('preview');
	my $save = $S->{CGI}->param('save');
	my $delete = $S->{CGI}->param('delete');
	my $archive = $S->{CGI}->param('archive');
	my $params = $S->{CGI}->Vars_cloned;

	# Check for extended perms here -- if users are allowed to edit their own entries,
	# they will only have "edit_my_stories", not "story_admin"
	return unless ($S->check_edit_story_perms($sid));

	if ($S->{CGI}->param('spellcheck') && $S->spellcheck_enabled()) {
		foreach my $e (qw(introtext bodytext)) {
			$params->{$e} = $S->spellcheck_html($params->{$e});
		}

		foreach my $e (qw(title dept)) {
			$params->{$e} = $S->spellcheck_string($params->{$e});
		}
	}

	my $content;
	my $keys = {};
	
	if ($archive) {

		if ($S->archive_story($sid)) {
			$content = $S->{UI}->{BLOCKS}->{edit_story_archive_success};
			return $content;
		} else {
			$content = $S->{UI}->{BLOCKS}->{edit_story_archive_fail};
			return $content;
		}

	} elsif ($delete) {

		$content = $S->delete_story($sid);
		
		return $content;
	}

	my $tmpsid;
	my $error;
	my $save_error;		# this is used later, when we call edit_story_form,
						# to let it know that the save failed, thus redisplay the data
						# not used right now, will be used later

	# Check the formkey, to prevent duplicate postings
	unless ($S->check_formkey()) {
		$error = "Invalid form key. This is probably because you clicked 'Post' or 'Preview' more than once. DO HIT 'BACK'! Make sure you haven't already posted this once, then go ahead and post or preview from this screen.";
		$preview = 'Preview';
	}

	if ($save) {
		warn "Saving $sid..." if $DEBUG;
		($sid, $error) = $S->save_story();
		if ($sid) {
			$preview = 'Saved';
		} else {
			$preview = 'Preview';
			$save_error = 'Save Error';
		}

		# if we are using editorial auto-voting, clear votes on story update
		# to re-mark as "new"
		$S->_clear_auto_votes($sid);
	}

	if ($preview) {
		warn "Previewing $sid..." if $DEBUG;
		$tmpsid = 'preview';
		
		if ($preview eq 'Update') {
			warn "This is an update" if $DEBUG;
			($sid, $error) = $S->save_story();
			$tmpsid = $sid;
			$S->_clear_auto_votes($sid);
		}

		# Give a helpful message
		$keys->{error} = $error;
		warn "Preview: Getting $tmpsid for display" if $DEBUG;
		$keys->{story} = $S->displaystory($tmpsid, $params);
	
	} 


	# This if and the above if will never both happen, since $tmpsid is set
	# right away in the above one.
	if ($sid && !$tmpsid) {

		$keys->{error} = $error;

		warn "SID: Getting $sid for display" if $DEBUG;
		$keys->{story} = $S->displaystory($sid);
	}
	
	if ($preview ne 'Saved') {
		$keys->{edit_form} = $S->edit_story_form();
	}
	
	$content = $S->interpolate($S->{UI}->{BLOCKS}->{edit_story_admin_page}, $keys);	
	return $content;
}

sub check_edit_story_perms {
	my $S = shift;
	my $sid = shift;

	# story_admin is the universal story edit perm
	return 1 if ($S->have_perm('story_admin'));
	
	# if not, we have to be editing an existing story
	return 0 unless ($sid);

	my $r = $S->story_data([$sid]);
	my $story = $r->[0];

	return 1 if ($S->have_perm('edit_my_stories') && $story->{aid} == $S->{UID});
	return 0;
}


sub _clear_auto_votes {
	my $S = shift;
	my $sid = shift;

	return unless $S->{UI}->{VARS}->{story_auto_vote_zero} && $sid;

	my ($rv, $sth) = $S->db_delete({
		FROM  => 'storymoderate',
		WHERE => "sid = '$sid'"
	});
	$sth->finish;

	$S->save_vote($sid, '0', 'N');
}

=pod

=over 4

=item * delete_story

This routine will delete the story $sid

=cut

sub delete_story {
	my $S = shift;
	my $sid = $S->{CGI}->param('sid');
 	my $quote_sid = $S->{DBH}->quote($sid);

	# If not admin, just hide the story
	if (!$S->have_perm('story_admin')) {
		my ($rv, $sth) = $S->db_update({
			WHAT => 'stories',
			SET => 'displaystatus = -1',
			WHERE => qq{sid = $quote_sid}
		});
		$sth->finish();
		$S->run_hook('story_hide', $sid);
	 	my $return = $S->{UI}->{BLOCKS}->{story_hide_message};
		$return =~ s/%%sid%%/$sid/g;
		return $return;
	}	

	my $archived = $S->_check_archivestatus($sid);
 	my @clean_up_args = ("comments", "ratings", "votes");
	push(@clean_up_args, 'viewed_stories') unless $archived;
 
 	my $attached_poll_qid = $S->get_qid_from_sid($sid);
 	if( $attached_poll_qid ) {
 		push(@clean_up_args, "poll");
 	}
 	
	$S->run_hook('story_delete', $sid);
	
	
 	$S->_clean_up_db($sid, @clean_up_args);

 	my ($rv, $sth) = $S->db_delete({
 		DEBUG => 0,
		ARCHIVE => $archived,
 		FROM => 'stories',
 		WHERE => qq|sid = $quote_sid|});
 		
 	
 	my $return = $S->{UI}->{BLOCKS}->{story_delete_message};
	$return =~ s/%%sid%%/$sid/g;

 	return $return;
}

sub archive_stories {
	my $S = shift;
	my $story_age = $S->{UI}->{VARS}->{story_archive_age};
	my $comment_age = $S->{UI}->{VARS}->{comment_archive_age};

	return "story_age not set" unless ($story_age >0);

	return "No archive setup" unless ($S->{HAVE_ARCHIVE});

	my ($rv, $sth) = $S->db_select({
		DEBUG => 0,
		WHAT => 'sid',
		FROM => 'stories',
		WHERE => $S->db_date_add(time, "$story_age day") . "< now()"
	});

	my (@sids, $rv2, $sth2, $qsid, $sid);
	while ($sid = $sth->fetchrow()) {
		if ($comment_age > 0) {
			$qsid = $S->{DBH}->quote($sid);
			($rv2, $sth2) = $S->db_select({
				DEBUG => 0,
				FROM => 'comments',
				WHAT => 'sid',
				WHERE => $S->db_date_add('date', '$comment_age day') . ' >= now() AND sid = $qsid',
				LIMIT => 1
			});
			if ($sth2->fetchrow() ne $sid) {
				push(@sids, $sid);
			}
			$sth2->finish();
		} else {
			push(@sids, $sid);
		}
	}
	$sth->finish();

	# now go through the list, and archive those sids.
	# Check they are not attatched to valid adverts first.
	
	my ($ad, $canarchive);
	foreach $sid (@sids) {
		$qsid = $S->{DBH}->quote($sid);
		($rv, $sth) = $S->db_select({
			DEBUG => 0,
			FROM => 'ad_info',
			WHAT => 'views_left, perpetual',
			WHERE => 'active = 1 AND ad_sid = '.$qsid});
		$canarchive = 1;
		if ($rv ne '0E0') {
			$ad = $sth->fetchrow_hashref();
			if (($ad->{views_left} > 0) || ($ad->{perpetual} = 1)) {
				#warn "Can't Archive story : $sid : active advert";
				$canarchive = 0;
			}
		}
		if ($canarchive) {	
			#warn "Archive story : $sid";
			$S->archive_story($sid);
		}
		$sth->finish();
	}
	return 1;

}

sub archive_story {
	my $S = shift;
	my $sid = shift;
	my $result = 0;

	#warn "Archive_story: $sid";

	return 0 if ($S->_check_archivestatus($sid));
	return 0 unless ($S->{DBHARCHIVE});

 	#my $attached_poll_qid = $S->get_qid_from_sid($sid);
	
 	#if( $attached_poll_qid ) {
 		#archive poll
	#}

 	my $quote_sid = $S->{DBH}->quote($sid);

	my ($rv, $sth) = $S->db_select({
		DEBUG => 0,
		WHAT => '*',
		FROM => 'stories',
		WHERE => qq|sid = $quote_sid|});
	my $story = $sth->fetchrow_hashref();
	$sth->finish();

	# if using macros, then render the macro(s) before archiving.
	# Render both introtext and bodytext.

	my $introtext = $story->{introtext};
	my $bodytext = $story->{bodytext};

	if (exists($S->{UI}->{VARS}->{use_macros}) && $S->{UI}->{VARS}->{use_macros}) {
		$introtext = $S->process_macros($introtext,'intro');
		$bodytext = $S->process_macros($bodytext,'body');
	}

	my @tosave = ($S->{DBHARCHIVE}->quote($story->{sid}),
		      $S->{DBHARCHIVE}->quote($story->{tid}),
		      $S->{DBHARCHIVE}->quote($story->{aid}),
		      $S->{DBHARCHIVE}->quote($story->{title}),
		      $S->{DBHARCHIVE}->quote($story->{dept}),
		      $S->{DBHARCHIVE}->quote($story->{time}),
		      $S->{DBHARCHIVE}->quote($introtext),
		      $S->{DBHARCHIVE}->quote($bodytext),
		      $story->{writestatus},
		      $story->{hits},
		      $S->{DBHARCHIVE}->quote($story->{section}),
		      $story->{displaystatus},
		      $story->{commentstatus},
		      $story->{totalvotes},
		      $story->{score},
		      $story->{rating},
		      $S->{DBHARCHIVE}->quote($story->{attached_poll}),
		      $story->{sent_email},
		      $story->{edit_category});

	my ($rvarch, $stharch) = $S->db_insert({
		DEBUG => 0,
		ARCHIVE => 1,
		INTO => 'stories',
		COLS => 'sid, tid, aid, title, dept, time, introtext, bodytext, writestatus, hits, section, displaystatus, commentstatus, totalvotes, score, rating, attached_poll, sent_email, edit_category',
		VALUES => "$tosave[0],$tosave[1],$tosave[2],$tosave[3],$tosave[4],$tosave[5],$tosave[6],$tosave[7],$tosave[8],$tosave[9],$tosave[10],$tosave[11],$tosave[12],$tosave[13],$tosave[14],$tosave[15],$tosave[16],$tosave[17],$tosave[18]"
	});
	$stharch->finish();

	if ($rvarch) {
		($rv, $sth) = $S->db_delete({
			DEBUG => 0,
			FROM => 'stories',
			WHERE => qq|sid = $quote_sid|});
	}
	$story = '';

	($rv, $sth) = $S->db_select({
		DEBUG => 0,
		WHAT => '*',
		FROM => 'comments',
		WHERE => qq|sid = $quote_sid|});
	my $comments;
	my @archived = ();
	while ($comments = $sth->fetchrow_hashref()) {

		# if using macros, then render the macro(s) before archiving comments.

		my $comment = $comments->{comment};

		if (exists($S->{UI}->{VARS}->{use_macros}) && $S->{UI}->{VARS}->{use_macros}) {
			$comment = $S->process_macros($comment,'comment');
			$comments->{sig} = $S->process_macros($comments->{sig},'pref');
		}

		@tosave = ($S->{DBHARCHIVE}->quote($comments->{sid}),
			   $comments->{cid},
			   $comments->{pid},
			   $S->{DBHARCHIVE}->quote($comments->{date}),
			   $comments->{rank} || "NULL",
			   $S->{DBHARCHIVE}->quote($comments->{subject}),
		 	   $S->{DBHARCHIVE}->quote($comment),
			   $comments->{pending} || "0",
			   $comments->{uid},
			   $comments->{points} || "NULL",
			   $comments->{lastmod} || "NULL",
			   $comments->{sig_status} || "NULL",
		  	   $S->{DBHARCHIVE}->quote($comments->{sig}) || "NULL",
			   $S->{DBHARCHIVE}->quote($comments->{commentip}) || "NULL");
		($rvarch, $stharch) = $S->db_insert({
			DEBUG => 0,
			ARCHIVE => 1,
			INTO => 'comments',
			COLS => 'sid, cid, pid, date, rank, subject, comment, pending, uid, points, lastmod, sig_status, sig, commentip',
			VALUES => "$tosave[0],$tosave[1],$tosave[2],$tosave[3],$tosave[4],$tosave[5],$tosave[6],$tosave[7],$tosave[8],$tosave[9],$tosave[10],$tosave[11],$tosave[12],$tosave[13]"});
		$stharch->finish();
		if ($rvarch) {
			push(@archived,($tosave[1]));
		}
	}
	$comments = '';
	$sth->finish();

	foreach my $todelete (@archived) {
		($rv, $sth) = $S->db_delete({
			DEBUG => 0,
			FROM => 'comments',
			WHERE => qq|sid = $quote_sid AND cid = $todelete|});
		$sth->finish()
	}
	
	$rvarch = 1;
	if ($S->{UI}->{VARS}->{archive_moderations}) {
		($rv, $sth) = $S->db_select({
			DEBUG => 0,
			WHAT => '*',
			FROM => 'storymoderate',
			WHERE => qq|sid = $quote_sid|});
		$rvarch = $rv;
		my $moderation;
		while ($moderation = $sth->fetchrow_hashref()) {
			@tosave = ( $S->{DBHARCHIVE}->quote($moderation->{sid}),
				  $moderation->{uid},
				  $S->{DBHARCHIVE}->quote($moderation->{time}),
				  $moderation->{vote},
				  $S->{DBHARCHIVE}->quote($moderation->{section_only}));
			($rvarch, $stharch) = $S->db_insert({
				DEBUG => 0,
				ARCHIVE => 1,
				INTO => 'storymoderate',
				COLS => 'sid, uid, time, vote, section_only',
				VALUES => "$tosave[0],$tosave[1],$tosave[2],$tosave[3],$tosave[5]"});
			$stharch->finish();
		}
		$sth->finish();
	}
	if ($rvarch) {
		($rv, $sth) = $S->db_delete({
			DEBUG => 0,
			FROM => 'storymoderate',
			WHERE => qq|sid = $quote_sid|});
		$sth->finish();
	}

	$rvarch = 1;
	if ($S->{UI}->{VARS}->{archive_ratings}) {
		($rv, $sth) = $S->db_select({
			DEBUG => 0,
			WHAT => '*',
			FROM => 'commentratings',
			WHERE => qq|sid = $quote_sid|});
		my $ratings;
		$rvarch = $rv;
		while ($ratings = $sth->fetchrow_hashref()) {
			@tosave = ( $ratings->{uid},
				    $ratings->{rating},
				    $ratings->{cid},
				    $S->{DBHARCHIVE}->quote($ratings->{sid}),
				    $S->{DBHARCHIVE}->quote($ratings->{rating_time}));
			($rvarch, $stharch) = $S->db_insert({
				DEBUG => 0,
				ARCHIVE => 1,
				INTO => 'commentratings',
				VALUES => "$tosave[0],$tosave[1],$tosave[2],$tosave[3],$tosave[4]"});
			$stharch->finish();
		}
		$sth->finish();
	}
	if ($rvarch) {
		($rv, $sth) = $S->db_delete({
			DEBUG => 0,
			FROM => 'commentratings',
			WHERE => qq|sid = $quote_sid|});
		$sth->finish();
	}

	($rv, $sth) = $S->db_delete({
			DEBUG => 0,
			FROM => 'viewed_stories',
			WHERE => qq|sid = $quote_sid AND hotlisted = 0|});
	$sth->finish();

	return 1;

}

=item *
save_story($mode)

This is the main routine for saving stories.  When you click save, or update, this is called.
$mode is by default 'full', but it can also be anything else you like, since there are only 
2 behaviors here.  NOTE: As of 2/23/00 save_story now returns a list!  2 values!  Element 0 is
the $qid/return code, Element 1 is the error message (only if Element 0 is 0)

=back

=cut

sub save_story {
	my $S = shift;
	my $mode = shift || 'full';
	my $parms = $S->{CGI}->Vars;
	my %params;
	foreach my $key (keys %{$parms}) {
		$params{$key} = $parms->{$key};
	}
	my $sid = $params{sid};
	my ($rv, $sth);

	my $currtime = $S->_current_time;
	my $posttype = $params{'posttype'};
	
	my ($test_ret, $error) = $S->_check_story_validity($sid, $parms);
	unless( $test_ret ) {
		return ($test_ret, $error);
	}
	
	# log it in case of script attack with an account
	my $nick = $S->get_nick_from_uid($S->{UID});
	warn "<< WARNING >> Story posted by $nick with uid=$S->{UID} at $currtime, IP: $S->{REMOTE_IP}   Title: \"$params{title}\"\n" if ($DEBUG);

	if ($mode ne 'full') {
		
		unless ($S->have_perm('story_displaystatus_select')) {
			$params{writestatus} = -2;
			if ($params{edit_in_queue}) {
				$params{displaystatus} = -3;
			} else {
				$params{displaystatus} = -2;
				$params{timeupdate} = 'now';
				$S->move_story_to_voting($sid);
			}
		}
		
		if ($params{section} eq 'Diary') {
			$params{displaystatus} = 1;
		}
		
		unless ($S->have_perm('story_commentstatus_select')) {
			$params{comment_status} = $S->{UI}->{VARS}->{default_commentstatus};
			$params{comment_status} ||= $S->dbh->quote('0');
		}

		my $filter_errors;
		$params{introtext} = $S->filter_comment($params{introtext}, 'intro', $posttype);
		$filter_errors = $S->html_checker->errors_as_string;
		return (0, $filter_errors) if $filter_errors;

		$params{bodytext} = $S->filter_comment($params{bodytext}, 'body', $posttype);
		$filter_errors = $S->html_checker->errors_as_string;
		return (0, $filter_errors) if $filter_errors;

		$params{title} = $S->filter_subject($params{title});
		$params{dept} = $S->filter_subject($params{dept});

		# one more constraint on posting: title length
		# if it's more than 100 (the db field size), don't let them post
		if (length($params{title}) > 100) {
			return (0, 'Please choose a shorter title.');
		}
                # and make sure we have tags if we require them
                if($S->var('use_tags') && $S->var('require_tags')){
                        return (0, 'Please include at least one tag with your story.') unless $params{tags};
                        }
	} elsif ($mode eq 'full' && !$S->have_perm('story_admin')) {
		my $filter_errors;

		# gotta set displaystatus to whatever it was before, since
		# it's not set if you can't select the display status
		if(!$S->have_perm('story_displaystatus_select')){
			my ($rv, $sth) = $S->db_select({
				WHAT => 'displaystatus',
				FROM => 'stories',
				WHERE => "sid = '$sid'"
				});
			my $r = $sth->fetchrow;
			$sth->finish;
			$params{displaystatus} = $r;
			}
		# might as well get comment status too
		unless($S->have_perm('story_commentstatus_select')){
			my ($rv, $sth) = $S->db_select({
				WHAT => 'commentstatus',
				FROM => 'stories',
				WHERE => "sid = '$sid'"
				});
			my $c = $sth->fetchrow;
			$sth->finish;
			$params{comment_status} = ($c) ? $c : $S->dbh->quote(0);
			}

                $params{introtext} = $S->filter_comment($params{introtext}, 'intro', $posttype);
                $filter_errors = $S->html_checker->errors_as_string;
                return (0, $filter_errors) if $filter_errors;

                $params{bodytext} = $S->filter_comment($params{bodytext}, 'body', $posttype);
                $filter_errors = $S->html_checker->errors_as_string;
                return (0, $filter_errors) if $filter_errors;

		$params{title} = $S->filter_subject($params{title});
                $params{dept} = $S->filter_subject($params{dept});

                # one more constraint on posting: title length
                # if it's more than 100 (the db field size), don't let them post
		if (length($params{title}) > 100) {
                        return (0, 'Please choose a shorter title.');
                        }
                # and make sure we have tags
                if($S->var('use_tags') && $S->var('require_tags')){
                        return (0, 'Please include at least one tag with your story.') unless $params{tags};
                        }
	} else {
		# check to see if story is moving out of edit queue
		if ($sid && ($params{displaystatus} != -3) && ($S->_check_story_mode($sid) == -3)) {
			$S->move_story_to_voting($sid);
		}
		unless ($S->have_perm('story_displaystatus_select')) {
			$params{'displaystatus'} = $S->_check_story_mode($sid)
		}
	}
	
	
	my $update = "<B>Update [$currtime by $S->{NICK}]:</B>";
	my $editorsnote = "<B>[editor's note, by $S->{NICK}]</B>";
	foreach (qw(introtext bodytext)) {
		$params{$_} =~ s/\[UPDATE\]/$update/g;
		$params{$_} =~ s/\[ED\]/$editorsnote/g;
	}

	# if using macros, and 'render on save' is on, then render the macro(s) before saving.
	# Render both introtext and bodytext.

	my $introtext = $params{introtext};	
	my $bodytext = $params{bodytext};

	if ( $S->var('use_macros') && $S->var('macro_render_on_save') ) {
		$introtext = $S->process_macros($introtext,'intro');
		$bodytext = $S->process_macros($bodytext,'body');
	}

	$introtext = $S->{DBH}->quote($introtext);
	$bodytext = $S->{DBH}->quote($bodytext);	

	my $title = $S->{DBH}->quote($params{title});
	my $dept = $S->{DBH}->quote($params{dept});
	my $section = $S->{DBH}->quote($params{section});
	my $q_sid = $S->{DBH}->quote($sid);
	my $edit_category = $params{edit_category} || 0;
	my $commentstatus = $params{comment_status} || 0;
	my $time = $params{time};
        my $aid = ($S->have_perm('story_admin')) ? $S->dbh->quote($params{aid}) : $S->dbh->quote($S->{UID});

	if ($params{timeupdate} eq 'now' || $time eq '') {
			$time = $currtime;
	}

	if ($sid && $sid ne '') {
		($rv, $sth) = $S->db_update({
			DEBUG => 0,
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT => 'stories',
			SET => qq|tid='$params{tid}',
			 aid=$aid,
			 title=$title, 
			 dept=$dept, 
			 time='$time', 
			 introtext=$introtext, 
			 bodytext=$bodytext, 
			 edit_category=$edit_category,
			 section=$section, 
			 displaystatus=$params{displaystatus}, 
			 commentstatus=$commentstatus|,
			WHERE => qq|sid = $q_sid|});

		# Save story tags, if we're using them
		$S->save_tags($sid, $params{'tags'}) if $S->var('use_tags');
		$S->run_hook('story_update', $sid);
	} else {
		$sid = $S->make_new_sid();
	
		if( $params{op} eq 'submitstory' && $params{section} ne 'Diary' && !$S->var('post_story_threshold') ) {
			$params{displaystatus} = "0";
			$params{writestatus} = "0";
		}

		# don't want to automatically auto-post if its an admin editing a story or something
		unless( $params{op} eq 'admin' ) {
			if( $S->have_section_perm('autofp_post_stories', $params{section}) ) {
				$params{displaystatus} = "0";
			} elsif( $S->have_section_perm('autosec_post_stories', $params{section}) ) {
				$params{displaystatus} = "1";
			}
		}
		
		$time = $currtime;
		my $q_sid = $S->dbh->quote($sid);
		my $q_tid = $S->dbh->quote($params{tid});
		($rv, $sth) = $S->db_insert({
			DEBUG => 0,
			INTO => 'stories',
			COLS => 'sid, tid, aid, title, dept, time, introtext, bodytext, section, displaystatus, commentstatus, edit_category',
			VALUES => qq|$q_sid, $q_tid, $aid, $title, $dept, '$time', $introtext, $bodytext, $section, $params{displaystatus}, $commentstatus, $edit_category|});

		# Save story tags, if we're using them
		$S->save_tags($sid, $params{'tags'}) if $S->var('use_tags');
		$S->run_hook('story_new', $sid);
	}
	$sth->finish;

	# don't try to write a poll if they aren't allowed to 
	# they must have attach_poll perms
	if( $S->{CGI}->param('qid') && $S->have_perm( 'attach_poll' ) ) {
		# try to write the poll
		my $eiq = $S->cgi->param('edit_in_queue') || $S->update_own_poll($sid);
		$S->write_attached_poll($sid, $eiq );
	}
	
	if ($rv) {
		# Mark the story modified in the cache
		my $time = time();
		my $r = $sid.'_mod';
		$S->cache->stamp_cache($r, $time);
		delete $S->{STORY_CACHE}->{$sid};
		return ($sid, "Story $sid saved");
	} else {
		return (0, "There was an error saving your story. It was not saved");
	}
	
}

sub edit_story_form {
	my $S = shift;
	my $form_values;
	my $mode = shift || 'full';
	my $sid = 	$S->{CGI}->param('sid');
	my $eiq = $S->cgi->param('edit_in_queue');
	my $confirm_cancel = $S->cgi->param('confirm_cancel');
	my ($story_mode, $stuff) = $S->_mod_or_show($sid);
	$sid = '' if ( ($confirm_cancel && $eiq) || $S->cgi->param('delete') );

	if ( ($sid ne '') && ($story_mode ne 'edit') )  {
		unless ( $S->have_perm('story_admin') || $S->have_perm('edit_my_stories')) {return "<P><B>Story ($sid) cannot be 
edited because it is currently in $story_mode mode.</B></P>"; }
	}
	my $params = $S->{CGI}->Vars;
	my $story_data;

	if ($S->{CGI}->param('file_upload')) {
		my $file_upload_type=$S->{CGI}->param('file_upload_type');
		my ($return, $file_name, $file_size) = $S->get_file_upload($file_upload_type);
		if ($file_upload_type eq 'content') {
		#replace content with uploaded file
			$S->param->{bodytext} = $return unless $file_size ==0;
		} else {
			# $return should be empty if we are doing a file upload, if not they are an error message
			return (0, $return) unless $return eq '';
		}
	}

	$form_values->{allowed_html_intro} = $S->html_checker->allowed_html_as_string('intro')
		if $mode ne 'full' && !$S->var('hide_story_allowed_html');
	$form_values->{allowed_html_body} = $S->html_checker->allowed_html_as_string('body')
		if $mode ne 'full' && !$S->var('hide_story_allowed_html');

	
	if ($mode eq 'full') {
		$form_values->{notes} = $S->{UI}->{BLOCKS}->{story_edit_notes};
	}
	
	if ($params->{delete}) {
	  	if ($params->{confirm_cancel}) {
			$S->story_post_write('-1', '-1', $S->{CGI}->param('sid'));
			return '<P><B>Story cancelled.</B></P>'; }
		else {
			return '<P><B>"Confirm cancel" check box was not selected, the story will not be cancelled.</B></P>';}
	
	}
	
	if ($params->{preview} || $mode eq 'Save Error') {
			$story_data = $params;
	} elsif ($sid && $mode eq 'full') {
		my $qsid = $S->dbh->quote($sid);
		my ($rv, $sth) = $S->db_select({
		 		ARCHIVE => $S->_check_archivestatus($sid),
				WHAT => '*',
				FROM => 'stories',
				WHERE => qq|sid = $qsid|});
		$story_data = $sth->fetchrow_hashref;
		$sth->finish;
	}
	
	$form_values->{tid} = $S->{CGI}->param('tid') || $story_data->{tid};
	$form_values->{section} = $S->{CGI}->param('section') || $story_data->{section};
	$form_values->{parent} = $S->cgi->param('parent_section') || '';
	$form_values->{topic_select} = $S->topic_select($form_values->{tid});
	$form_values->{topic_select} = qq|<input type="hidden" name="tid" value="$form_values->{tid}">| unless ($form_values->{topic_select});
	$form_values->{section_select} = $S->section_select($form_values->{parent}, $form_values->{section});
	
	my ($del_button, $archive_button);
	
	$form_values->{displaystatus_select} = $S->displaystatus_select($story_data->{displaystatus}) 
		if ($S->have_perm('story_displaystatus_select'));
	
	$form_values->{commentstatus_select} = $S->commentstatus_select($story_data->{commentstatus})
		if ($S->have_perm('story_commentstatus_select'));
	
	if ($mode eq 'full') {
		if ($S->var('use_edit_categories') ) {
			$form_values->{edit_category_select} = $S->edit_category_select($story_data->{edit_category});}
		#Not deleting this line quite yet in case someone needs it
		#$writestatus_select = $S->writestatus_select($story_data->{writestatus});
		if ($sid) {
			$del_button = qq|
				<INPUT TYPE="submit" NAME="delete" VALUE="Delete">&nbsp;|;
			$archive_button = qq|
				<INPUT TYPE="submit" NAME="archive" VALUE="Archive">&nbsp;| if $S->{HAVE_ARCHIVE} && (!$S->_check_archivestatus($sid));

		}
	} else {
		$form_values->{postmode_select} = $S->_postmode_option_form();	
	}
	
	if ($mode eq 'full') {
		$form_values->{all_buttons} = qq|
			<INPUT TYPE="submit" NAME="preview" VALUE="Update">&nbsp;
			<INPUT TYPE="submit" NAME="preview" VALUE="Preview">&nbsp;
			$del_button
			$archive_button|;
	} else {
		$form_values->{all_buttons} = qq|
			<INPUT TYPE="submit" NAME="preview" VALUE="Preview">&nbsp;|;
		if ($params->{preview} || $S->var('require_story_preview') == 0 ) {
			$form_values->{all_buttons} .= qq|	
			<INPUT TYPE="submit" NAME="save" VALUE="Submit">&nbsp;|;
			if ( $S->have_perm('edit_own_story') ) {
				$form_values->{all_buttons} .= $del_button;
			}
		}
	}
			
	$form_values->{aid} = $story_data->{aid} || $S->{UID};
	my $tool = '';
	
	if ($mode eq 'full') {
		$tool = qq|<INPUT TYPE="hidden" NAME="tool" VALUE="story">|;
	}
	my $event;
	if ( my $eid = $S->cgi->param('event') ) {
		$event = qq|<INPUT type="hidden" name="event" value="$eid">|;
	}
	my $formkey = $S->get_formkey_element();
 	
	$form_values->{upload_page} = $S->{UI}->{BLOCKS}->{story_edit_upload};
	my $upload_form = $S->display_upload_form(0, 'content');
	$form_values->{upload_page} =~ s/%%form%%/$upload_form/g;		
	
	$form_values->{hidden_form_data} = qq|
		%%submit_include_top%%
		<INPUT TYPE="hidden" NAME="op" VALUE="$params->{op}">
		$tool
		<INPUT TYPE="hidden" NAME="sid" VALUE="$sid">
		<INPUT TYPE="hidden" NAME="aid" VALUE="$form_values->{aid}">
		$event
		$formkey
		<INPUT TYPE="hidden" NAME="time" VALUE="$story_data->{time}">|;

	
#	$story_data->{title} =~ s/"/&quot;/g;
	$story_data->{title} = $S->comment_text($story_data->{title});
	$story_data->{title} =~ s/"/&quot;/g;

	$form_values->{title} = $story_data->{title};

	if ($S->var('show_dept')) {
		$form_values->{dept} = $S->{UI}->{BLOCKS}->{story_edit_dept};
		$form_values->{dept} =~ s/%%dept%%/$story_data->{dept}/g;
	}

	if ($S->var('use_tags')) {
		$form_values->{tags} = $S->story_tag_field();
	}
		
	if ($S->spellcheck_enabled()) {
		# We will only have a formkey if they have already used the submit form.
		# We only want to set the default spellcheck the first time they submit
		# We don't want to override the setting.

		$params->{spellcheck} = $S->pref('spellcheck_default') unless ($S->{CGI}->param('formkey'));
		my $check = ($params->{spellcheck} eq 'on') ? ' CHECKED' : '';
		$form_values->{spellcheck} = $S->{UI}->{BLOCKS}->{story_edit_spellcheck};
		$form_values->{spellcheck} =~ s/%%check%%/$check/g;
	}
	
	# show edit in queue checkbox only if the var is set and the mode is normal (non-admin)
 	if ( ($S->have_perm('edit_own_story')) && ($mode ne 'full') && ($params->{section} ne 'Diary')){
 		my $check =  $params->{'preview'} ? 
		             ($params->{edit_in_queue} ? ' CHECKED' : '') 
					 : ' CHECKED';
		$form_values->{edit_queue} = $S->{UI}->{BLOCKS}->{story_edit_editqueue};
		$form_values->{edit_queue} =~ s/%%check%%/$check/g;
 	}
	
	if ($S->have_perm('story_time_update')) {
		my $check = ' CHECKED' if ($params->{timeupdate} eq 'now');
		$form_values->{time_update} = $S->{UI}->{BLOCKS}->{story_edit_timeupdate};
		$form_values->{time_update} =~ s/%%check%%/$check/g;
	}
	
	if ($mode eq 'full') {	
		$form_values->{update_txt} = $S->{UI}->{BLOCKS}->{story_edit_updatetxt};
		$form_values->{edit_txt}   = $S->{UI}->{BLOCKS}->{story_edit_edittxt};
	}

	foreach (qw(introtext bodytext)) {
		$story_data->{$_} = $S->comment_text($story_data->{$_});
	}

	$form_values->{textarea_cols} = $S->pref('textarea_cols'); 
	$form_values->{textarea_rows} = $S->pref('textarea_rows'); 

	$form_values->{introtext} = $story_data->{introtext};
	$form_values->{bodytext} = $story_data->{bodytext};

	# if they can attach polls generate the form
	if( $S->have_perm( 'attach_poll' ) ) {
		$form_values->{poll_message} = $S->{UI}->{BLOCKS}->{attach_poll_message};
	
		# if they are previewing pass the args to the function.  else give them the real story $sid
		if($params->{preview} && !$params->{retrieve_poll}) {
			$form_values->{poll_form} = $S->make_attached_poll_form('preview', $params);
		} else {
			$form_values->{poll_form} .= $S->make_attached_poll_form('normal', $sid);
		}
	}
	
	if ($mode ne 'full') {
		$form_values->{guidelines} = $S->{UI}->{BLOCKS}->{submission_guidelines};
	}
	
	my $content = $S->interpolate($S->{UI}->{BLOCKS}->{edit_story_form}, $form_values);
		
	return $content;
}
	
sub topic_select {
	my $S = shift;
	my $tid = shift;
	my $selected= '';
	
	return '' unless $S->var('use_topics');
	
	# Check for diary
	my $section = $S->cgi->param('section');
	my $sid = $S->cgi->param('sid');
	# if we're editing an existing story, we won't have the section in the
	# cgi params when we first load it. It doesn't seem to matter to
	# folks with story_admin, but it does for normal users, so...
	if($sid && !$section){
		my $s = $S->story_data([$sid]);
		$section = $s->[0]->{section}; # voila
		}

	if (!$S->var('diary_topics')) {
		if ($S->have_perm('story_admin') && $sid) {
			warn "SID is $sid\n" if $DEBUG;
			my $stories = $S->story_data([$sid]);
			my $story = $stories->[0];
			if ($story->{tid} && $story->{section} eq 'Diary') {
				warn "Topic is $story->{tid}\n" if $DEBUG;
				return qq|<INPUT TYPE="hidden" NAME="tid" VALUE="$tid"><B>[ $story->{tid} ]</B>|;
			}
		} elsif ($section eq 'Diary') {
			return qq|<INPUT TYPE="hidden" NAME="tid" VALUE="diary"><B>[ $S->{NICK} ]</B>|;
		}
	}
	
	my $topic_select = qq|
		<SELECT NAME="tid" SIZE=1>
	|;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'tid, alttext',
		FROM => 'topics',
		ORDER_BY => 'tid asc'});
	if ($rv ne '0E0') {
		while (my $topic = $sth->fetchrow_hashref) {
			next if (($topic->{tid} eq 'diary') && !$S->var('diary_topics'));

			if (($topic->{tid} eq $tid) || (($tid eq '') && ($topic->{tid} eq 'diary') && ($section eq 'Diary'))) {
				$selected = ' SELECTED';
			} else {
				$selected = '';
			}
			$topic_select .= qq|
				<OPTION VALUE="$topic->{tid}"$selected>$topic->{alttext}|;
		}
	}
	$sth->finish;
	
	$topic_select .= qq|
		</SELECT>&nbsp;|;
	return $topic_select;
}


sub writestatus_select {
	my $S = shift;
	my $stat = shift;
	my $selected= '';
	
	my $status_select = qq|
		<SELECT NAME="writestatus" SIZE=1>
	|;
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'statuscodes',
		ORDER_BY => 'code asc'});
	if ($rv ne '0E0') {
		while (my $status = $sth->fetchrow_hashref) {
			if ($status->{code} eq $stat) {
				$selected = ' SELECTED';
			} else {
				$selected = '';
			}
			$status_select .= qq|
				<OPTION VALUE="$status->{code}"$selected>$status->{name}|;
		}
	}
	$sth->finish;
	
	$status_select .= qq|
		</SELECT>&nbsp;|;
	return $status_select;
}

sub edit_category_select {
	my $S = shift;
	my $stat = shift;
	my $selected= '';
	
	my $edit_category_select = qq|
		<SELECT NAME="edit_category" SIZE=1>
	|;
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'editcategorycodes',
		ORDER_BY => 'orderby asc'});
	if ($rv ne '0E0') {
		while (my $status = $sth->fetchrow_hashref) {
			if ($status->{code} eq $stat) {
				$selected = ' SELECTED';
			} else {
				$selected = '';
			}
			$edit_category_select .= qq|
				<OPTION VALUE="$status->{code}"$selected>$status->{name}|;
		}
	}
	$sth->finish;
	
	$edit_category_select .= qq|
		</SELECT>&nbsp;|;
	return $edit_category_select;
}

sub displaystatus_select {
	my $S = shift;
	my $tmpstat = shift; # || $S->{UI}->{VARS}->{default_displaystatus};
	my $stat = (defined($tmpstat))? $tmpstat : $S->var('default_displaystatus');
	# have to test if $tmpstat is defined; if it's zero (front page) it used the var
	my $selected= '';
	
	my $status_select = qq|
		<SELECT NAME="displaystatus" SIZE=1>
	|;
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'displaycodes',
		ORDER_BY => 'code asc'});
	if ($rv ne '0E0') {
		while (my $status = $sth->fetchrow_hashref) {
			if ($status->{code} eq $stat) {
				$selected = ' SELECTED';
			} else {
				$selected = '';
			}
			$status_select .= qq|
				<OPTION VALUE="$status->{code}"$selected>$status->{name}|;
		}
	}
	$sth->finish;
	
	$status_select .= qq|
		</SELECT>&nbsp;|;
	return $status_select;
}


sub commentstatus_select {
	my $S = shift;
	my $stat = shift;
	
	my $status_select = qq|
		<SELECT NAME="comment_status" SIZE=1>
	|;
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'commentcodes',
		ORDER_BY => 'code asc'});
	if ($rv ne '0E0') {
		while (my $status = $sth->fetchrow_hashref) {
			my $selected = '';
			my $default = $S->var('default_commentstatus');
			if (defined($stat) && ($status->{code} == $stat)) {
				$selected = ' SELECTED';
			} elsif (!defined($stat) && ($status->{code} == $default)) {
				$selected = ' SELECTED';
			}

			$status_select .= qq|
				<OPTION VALUE="$status->{code}"$selected>$status->{name}|;
		}
	}
	$sth->finish;
	
	$status_select .= qq|
		</SELECT>&nbsp;|;
	return $status_select;
}

sub section_select {
	my $S = shift;
	my $parent = shift;
	my $sec = shift;
	my $selected = '';
	
	#warn "Parent is ($parent), Section is ($sec)\n";
	
	my $op = $S->cgi->param('op');
	
	# Send back a hidden field if it's a diary
	if ($parent eq 'Diary' || $sec eq 'Diary') {
		my $section = qq|
			<B>[ Diary ]</B>
			<INPUT TYPE="hidden" NAME="section" VALUE="Diary">
			<INPUT TYPE="hidden" NAME="parent_section" VALUE="Diary">|;
		return $section;
	}
	# or an event
	if ( $S->cgi->param('event') ) {
		my $e_section = $S->var('event_story_section');
		my $section = qq|
			<B>[ Event ]</B>
			<INPUT TYPE="hidden" NAME="section" VALUE="$e_section">
			<INPUT TYPE="hidden" NAME="parent_section" VALUE="$e_section">|;
		return $section;
	}
	
	my $section_select;
	my ($parent_selections, $child_selections, $divider);
	my $section_siblings = {};
	
	if ($S->var('restrict_story_submit_to_subsect')) {
		if ($op eq 'admin') {

			foreach my $p (sort keys %{$S->{SECTION_DATA}->{$sec}->{parents}}) {
				$parent_selections .= qq|
				<option value="$p">&nbsp;&nbsp;&nbsp;$S->{SECTION_DATA}->{$p}->{title}|;
				
				# While we're at it, get siblings of this section
				$section_siblings = $S->{SECTION_DATA}->{$p}->{children}
			}
			$parent_selections = qq|
				<option value="">----Parents----| . $parent_selections if ($parent_selections);
			
			foreach my $p (sort keys %{$S->{SECTION_DATA}->{$sec}->{children}}) {
				$child_selections .= qq|
				<option value="$p">&nbsp;&nbsp;&nbsp;$S->{SECTION_DATA}->{$p}->{title}|;
			}
			$child_selections = qq|
				<option value="">---Children---| . $child_selections if ($child_selections);
			
			$divider = qq|
				<option value="">--------------| if ($parent_selections || $child_selections);
				
		} else {
			$section_select .= qq|
		<input type="hidden" name="parent_section" value="$parent">
		<b>[ <a href="%%rootdir%%/section/$parent">$S->{SECTION_DATA}->{$parent}->{title}</a> ]</b> |;
		}
	}
	
	$section_select .= qq|
		<SELECT NAME="section" SIZE=1>
		$parent_selections
		$child_selections
		$divider|;

	# pass get_dis....() a regexp, since more than one match is ok
	my $no_perm_hash = $S->get_disallowed_sect_hash('(norm|autofp|autosec)_post_stories');
	
	# Put the parent section up front, as a choice
	if ($S->var('restrict_story_submit_to_subsect') && $op eq 'submitstory' && !$no_perm_hash->{ $parent }) {
		my $selected = (!$sec || $parent eq $sec) ? ' SELECTED' : '';
		$section_select .= qq|
		<option value="$parent"$selected>$S->{SECTION_DATA}->{$parent}->{title}
		|;
	}
	
	#warn "Section is $sec\n";
	foreach my $key ( sort keys %{$S->{SECTION_PERMS}}) {
		next if ($key eq 'Diary');
		next if ( $no_perm_hash->{ $key } );
		next if ($S->var('restrict_story_submit_to_subsect') && $op eq 'admin' && !$section_siblings->{$key});
		next if ($S->var('restrict_story_submit_to_subsect') && $op eq 'submitstory' && !$S->{SECTION_DATA}->{$parent}->{children}->{$key});
		 
		my $section = $S->{SECTION_DATA}->{$key};
			
		$selected = ($section->{section} eq $sec) ? ' SELECTED' : '';

		$section_select .= qq|
			<OPTION VALUE="$section->{section}"$selected>$section->{title}|;
	}

	$section_select .= qq|
		</SELECT>&nbsp;|;
	return $section_select;
}

sub make_new_sid {
	my $S = shift;
	my $sid = '';

	my $rand_stuff = $S->rand_stuff;
	$rand_stuff =~ /^(.....)/;
	$rand_stuff = $1;
	
	my @date = localtime(time);
	my $mon = $date[4]+1;
	my $day = $date[3];
	my $year = $date[5]+1900;

	$sid = "$year/$mon/$day/$date[2]$date[1]$date[0]/$rand_stuff";
	$sid =~ /(.{1,20})/;
	$sid = $1;

	return $sid;
}

sub _clean_up_db {
	my $S = shift;
	my $sid = shift;

	my %opt2table = (
		comments       => "comments",
		ratings        => "commentratings",
		votes          => "storymoderate",
		poll           => "pollquestions",
                viewed_stories => "viewed_stories"
	);

	foreach my $o (@_) {
		next unless $opt2table{$o};
		
		# if there is an attached poll, delete it
		if( $opt2table{$o} eq 'pollquestions' ) {
 			my $attach_qid = $S->get_qid_from_sid($sid);
			$S->_delete_poll($attach_qid);
			
		} else {    # otherwise just delete the story, comments, and ratings
			my $qsid = $S->dbh->quote($sid);
			my ($rv, $sth) = $S->db_delete({
				DEBUG => 0,
				ARCHIVE => $S->_check_archivestatus($sid),
				FROM => $opt2table{$o},
				WHERE => qq|sid = $qsid|
				});
}
	}
}

sub _story_mod_write {
	my $S = shift;
	my $sid = shift;
	return unless ($S->_check_story_mode($sid) <= -2);
	
	my $save = $S->{CGI}->param('save');
	return unless $save;
	
	my $check_vote = $S->_check_vote;
	return if $check_vote;
	
	# MAke sure they came from a vote form!
	my $fk = $S->check_vote_formkey();
	return unless ($fk);
	
	my $vote = $S->{CGI}->param('vote');
	my $s_o = 'X';

	if( $vote == 2 ) {
	    $s_o = 'Y';
	} elsif ( $vote == 1) {
		$s_o = 'N';
	}

	if ($vote > 0) {
		$vote = 1;
	} elsif ($vote < 0) {
		$vote = -1;
	}

	# this doesn't appear to be used anymore
	#my $comment = $S->{CGI}->param('comments');
	#$comment = $S->filter_comment($comment);
	#my $filter_errors = $S->html_checker->errors_as_string;
	#return $filter_errors if $filter_errors;
	#$comment = $S->{DBH}->quote($comment);
	
	$S->save_vote($sid, $vote, $s_o);

	$S->run_hook('story_vote', $sid, $S->{UID}, $vote, $s_o);

	my $message;
	if ( $S->{CGI}->param('mode') eq 'spam' ) {
		# mark the spam vote if it occurred
		$message = $S->{UI}->{BLOCKS}->{story_spam_vote_msg};
		$S->_update_story_votes($sid, $vote);
		$S->_spam_check_story($sid);
	} else {
		# update the story record, eh?
		my ($curr_votes, $curr_score) = $S->_update_story_votes($sid, $vote);
		$message = $S->{UI}->{BLOCKS}->{story_vote_msg};
		$message =~ s/%%vote%%/$vote/g;
		$message =~ s/%%curr_score%%/$curr_score/g;
		
		$message .= $S->_post_story($sid);
	}
	return $message;
}

sub save_vote {
	my $S = shift;
	my $sid = shift;
	my $vote = shift; #value of the vote
	my $s_o = shift;  #vote for section, or front page
	
	my $uid = $S->{UID};
	my $time = $S->_current_time;

	my $check_vote = $S->_check_vote;
	return if $check_vote;
	
	# save the vote itself
	my ($rv, $sth) = $S->db_insert({
		INTO => 'storymoderate',
		COLS => 'sid, uid, time, vote, section_only',
		VALUES => "'$sid', '$uid', '$time', '$vote', '$s_o'"});
	$sth->finish;
	
}
		

sub _check_vote {
	my $S = shift;
	my $uid = $S->{UID};
	my $sid = $S->dbh->quote($S->{CGI}->param('sid'));
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'uid',
		FROM => 'storymoderate',
		WHERE => qq|uid = $uid AND sid = $sid|});
	$sth->finish;
	
	if ($rv == 0) {
		return 0;
	} else {
		return 1;
	}
}

sub check_vote_formkey {
	my $S = shift;
	my $key = $S->{CGI}->param('formkey');
	
	my $user = $S->user_data($S->{UID});
	Crypt::UnixCrypt::crypt($user->{'realemail'}, $user->{passwd}) =~ /..(.*)/;	
	
	return 1 if ($key eq $1);
	return 0;
}

sub _update_story_votes {
	my $S = shift;
	my ($sid, $vote) = @_;
	my ($rv, $sth);
	
	$vote = int $vote;
	
	#warn "Vote is $vote";
	
	if ($vote || $vote == 0) {
			my $q_sid = $S->dbh->quote($sid);
			($rv, $sth) = $S->db_update({
			DEBUG => 0,
			WHAT => 'stories',
			SET => qq|totalvotes = (totalvotes + 1), score = (score + $vote)|,
			WHERE => qq|sid = $q_sid|});
		$sth->finish;
}
	
	my ($newvotes, $newscore) = $S->_get_total_votes($sid);
	#warn "Total is now $newvotes";
	
	return ($newvotes, $newscore);
}	

sub _get_total_votes {
	my $S = shift;
	my $sid = shift;
	my $q_sid = $S->dbh->quote($sid);
	
	my ($rv, $sth) = $S->db_select({
		DEBUG => 0,
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'totalvotes, score',
		FROM => 'stories',
		WHERE => qq|sid = $q_sid|});
	
	my $votes = $sth->fetchrow_hashref;
	$sth->finish;
	my $newvotes = $votes->{totalvotes};
	my $score = $votes->{score};
	
	return ($newvotes, $score);
}	

sub _get_story_userviews {
	#returns the number of unique users that have viewed the story
	#this was directly 'borrowed' Andrew Hurst's story_count box in the Scoop box exchange
	
	my $S = shift;
	my $sid = shift;
	
	my ($rv, $sth) = $S->db_select({
		FROM	=> 'viewed_stories',
		WHAT	=> 'count(uid) as c',
		WHERE	=> "sid = '$sid'"
	});

	my $count = 0;

	if ( $rv ) {
		my $r = $sth->fetchrow_hashref;
		$count = $r->{c};
	}
	$sth->finish();
	return $count;
}

sub _get_user_voted {
	#return the count of votes that the $uid has voted for $sid

	my $S = shift;
	my ($uid, $sid) = @_;
	
	my ($rv, $sth) = $S->db_select({
		FROM	=> 'storymoderate',
		WHAT	=> 'count(vote) as v',
		WHERE   => "sid='$sid' AND uid='$uid'"
	});

	my $count = 0;

	if ( $rv ) {
		my $r = $sth->fetchrow_hashref;
		$count = $r->{v};
	}
	$sth->finish();
	return $count;
}

sub _spam_check_story {
	my $S = shift;
	my $sid = shift;

	return unless $S->var('use_anti_spam');

	# Double check story's current status
	# Don't want to run this unless it's in edit
	my ($dstat, $wstat) = $S->_check_story_status($sid);
	return unless ($dstat == -3);

	my $votes_threshold	= $S->var('spam_votes_threshold');
	my $spam_percent	= $S->var('spam_votes_percentage');
	
	my ($spam_votes, $dummy)= $S->_get_total_votes($sid);
	if ($spam_votes >= $votes_threshold) {
		my $page_userviews	= $S->_get_story_userviews($sid);
		
		if ( ($spam_votes / $page_userviews) > $spam_percent ) {
			$S->move_story_to_voting($sid);	
		}
	}
	
}

sub move_story_to_voting {
	my $S = shift;
	my $sid = shift;
	
	# move the story to the normal queue
	$S->story_post_write('-2', '-2', $sid);

	$S->run_hook('story_leave_editing', $sid) if ($sid);

	# delete registered votes
	my ($rv, $sth) = $S->db_delete({
		DEBUG => 0,
		FROM  => 'storymoderate',
		WHERE => "sid='$sid'"});
	
	$sth->finish;	

	# reset story totals
	($rv, $sth) = $S->db_update({
		DEBUG => 0,
		WHAT =>  'stories',
		SET => 	 'totalvotes=0, score=0',
		WHERE => "sid='$sid'"});
	$sth->finish;
}

sub _post_story {
	my $S = shift;
	my $sid = shift;
	
	my ($votes, $score) = $S->_get_total_votes($sid);
	my $threshold		= $S->var('post_story_threshold');
	my $hide_threshold	= $S->var('hide_story_threshold');
	my $stop_threshold	= $S->var('end_voting_threshold') || -1;

	my $msg;
	my $num;
	my ($dstat, $wstat) = $S->_check_story_status($sid);
	my $sth = $S->_get_story_mods($sid);

	my ($for_votes, $against_votes) = 0;

	# Aha!  Wizardry.  If they want the 'old' scoring then we use $score

	if ( $S->var('use_alternate_scoring') ) {
		while (my $mod_rec = $sth->fetchrow_hashref) {
			if ($mod_rec->{vote} == 1) {
				$for_votes++;
			} elsif ($mod_rec->{vote} == -1) {
				$against_votes--;
			}
		}
	} else {
		$for_votes = $score;
		$against_votes = $score;
	} 

	$sth->finish;
	
	warn "(_post_story) score is: $score ($for_votes/$against_votes); thresholds are $threshold and $hide_threshold" if $DEBUG;
	warn "(_post_story) dstat: $dstat; wstat: $wstat" if $DEBUG;
	if ($for_votes >= $threshold && $dstat < 0) {    
		# figure out if this story should post to the section or
		# front page
	
		my ($rv1, $sth1) = $S->db_select({
		      WHAT => 'section_only, count(*) as CNT',
		      FROM => 'storymoderate',
		      WHERE => qq|sid = '$sid' AND section_only != 'X'|,
		      GROUP_BY => 'section_only',
		      ORDER_BY => 'CNT DESC'
		    });
	
		my $sec_votes = {};
		while (my ($sec, $num) = $sth1->fetchrow) {
			$sec_votes->{$sec} = $num;
		}
		$sth1->finish();
		
		my $total = $sec_votes->{Y} + $sec_votes->{N};
		my $ratio = $sec_votes->{N} / $total;
		$ratio = sprintf("%.2f", $ratio);
		
		my ($ws, $ds, $where);
		
		$S->{UI}->{VARS}->{front_page_ratio} ||= 0.5;
		
		if( $ratio < $S->{UI}->{VARS}->{front_page_ratio}) {
			$ws = -2;
			$ds = 1;
			$where = "Section";
		} else {
			$ws = 0;
			$ds = 0;
			$where = "front";
		}

		# Post the story
		my $rv = $S->story_post_write($ds, $ws, $sid);
	
		$S->run_hook('story_post', $sid, $where);
		
		if ($rv) {
			$msg = $S->{UI}->{BLOCKS}->{story_post_message};
			$msg =~ s/%%where%%/$where/;
		}

		# Send e-mail to the author
		$S->_send_story_mail($sid, 'posted') if ($S->{UI}->{VARS}->{notify_author} == 1);

	# END: if ($for_votes >= $threshold && $dstat < 0)
	} elsif ($for_votes >= $threshold && $dstat >= 0 && $wstat >= 0) {

		$msg = $S->{UI}->{BLOCKS}->{story_already_post_msg};

	} elsif ($against_votes == $hide_threshold && $dstat < -1) {

		#Story is now hidden
		warn "(_post_story) hiding story $sid" if $DEBUG;
		my $rv = $S->story_post_write('-1', '-1', $sid);

		$S->run_hook('story_hide', $sid);

		$S->_send_story_mail($sid, 'hidden') if ($S->var('notify_author') == 1);
		$msg = $S->{UI}->{BLOCKS}->{story_dumped_message};

	  # This will activate the default (max_votes based) auto-clear
	} elsif ($S->{UI}->{VARS}->{use_auto_post} && !$S->{UI}->{VARS}->{auto_post_use_time} && $votes >= $stop_threshold) {

		$msg .= $S->auto_clear_story($sid);	
      
	  # This will activate the time-based auto clear, if auto_post_use_time is set
	} elsif ($S->{UI}->{VARS}->{use_auto_post} && $S->{UI}->{VARS}->{auto_post_use_time}) {
	    
		# Check for time in auto_clear, instead of above.
		$msg .= $S->auto_clear_story($sid);	
	
	}
	
	return $msg;
}

sub auto_clear_story {
	my $S = shift;
	my $sid = shift;
	
	my $qsid = $S->dbh->quote($sid);
	# Check the current score and posting time. 
	my ($rv, $sth) = $S->db_select({
		WHAT => 'score,  time',
		FROM => 'stories',
		WHERE => qq|sid = $qsid|});
	
	my ($curr_sc, $post_time) = $sth->fetchrow();
	$sth->finish();
	
	# Check the time if necessary 
	if ($S->{UI}->{VARS}->{auto_post_use_time}) {
		my $post_sec = $S->time_absolute_to_seconds($post_time);
		my $diff_minutes = (time() - $post_sec) / 60;
		return unless ($diff_minutes > $S->{UI}->{VARS}->{auto_post_max_minutes});
	}	

	my ($avg, $vote_score, $comment_score) = 0;
	my $msg;
	my $vote_floor = $S->{UI}->{VARS}->{auto_post_floor} || 0;
	my $vote_ceiling = $S->{UI}->{VARS}->{auto_post_ceiling} || $S->{UI}->{VARS}->{post_story_threshold};
	my $section = $S->{UI}->{VARS}->{auto_post_section};
	my $front = $S->{UI}->{VARS}->{auto_post_frontpage};
	
	if ($curr_sc >= $vote_floor) {
		# Get the vote_score
		$vote_score = $S->get_story_vote_score($sid);

		# Then get the weighted comment score
		$comment_score = $S->get_story_comment_score($sid);

		# Then get the average of those
		$avg = ($vote_score + $comment_score) / 2;
		
		# Check for boundary cases
		if ($curr_sc >= $vote_ceiling && $avg < $section) {
			$avg = $section;
		}
	} else {
		$msg = "Overall score less than voting floor ($curr_sc < $vote_floor)";
	}
	
	
	my $ws = -1;
	my $ds = -1;
	
	$ds = 1 if ($avg >= $section);
	$ds = 0 if ($avg >= $front);
	
	# post or drop the story
	$rv = $S->story_post_write($ds, $ws, $sid);
	my $status = ($ds != -1) ? 'posted' : 'hidden';
	my $path = $S->var('rootdir');
	my $url = "http://$S->{SERVER_NAME}$path/story/$sid";
	if ($vote_score && $comment_score) {
		$msg = "Vote score: $vote_score, Comment score: $comment_score, Avg: $avg";
	}
	# temp admin alert
	$S->admin_alert("Story auto-$status: story: $url, $msg") if ($S->var('auto_post_alert'));

	# Send e-mail to the author
	if ($rv) {
		$S->_send_story_mail($sid, $status) if($S->var('notify_author') == 1);
		my $returnmsg = $S->{UI}->{BLOCKS}->{story_autopost_message};
		$returnmsg =~ s/%%status%%/$status/;
		return $returnmsg;
	}
	return '';
}

	
sub story_post_write {
	my $S = shift;
	my ($ds, $ws, $sid) = @_;
	
	my $q_sid = $S->dbh->quote($sid);
	my $time = $S->dbh->quote($S->_current_time());
	my ($rv, $sth) = $S->db_update({
		WHAT => 'stories',
		SET => qq|displaystatus = $ds, writestatus = $ws, time = $time|,
		WHERE => qq|sid = $q_sid|});
	$sth->finish;
	
	return $rv;
}
	
sub get_story_comment_score {
	my $S = shift;
	my $sid = shift;

	my $rating_min = $S->dbh->quote($S->{UI}->{VARS}->{rating_min});
	my $qsid = $S->dbh->quote($sid);
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'points, lastmod',
		FROM => 'comments',
		WHERE => qq|points IS NOT NULL and points >= $rating_min and sid = $qsid and pending = 0|,
		DEBUG => 0});

	my ($sum, $count, $comment_score) = 0;
	while (my ($rating, $number) = $sth->fetchrow()) {
		$count += $number;
		$sum += ($rating * $number);
	}
	
	my $min_ratings = $S->{UI}->{VARS}->{auto_post_min_ratings} || 1;
	$count = $min_ratings if ($count < $min_ratings);
	$comment_score = ($sum / $count);
	return $comment_score;
}

sub get_story_vote_score {
	my $S = shift;
	my $sid = shift;

	# First, fetch all the current votes
	my ($dump, $dontcare, $section, $frontpage);
	my ($rv, $sth) = $S->db_select({
		WHAT     => 'COUNT(vote) AS score, vote, section_only',
		FROM     => 'storymoderate',
		WHERE    => qq|sid = '$sid'|,
		GROUP_BY => 'vote, section_only'
	});
	while (my @votes = $sth->fetchrow_array) {
		if ($votes[1] == -1) {
			$dump = $votes[0];
		} elsif ($votes[1] == 0) {
			$dontcare = $votes[0];
		} elsif ($votes[1] == 1 && $votes[2] == 'Y') {
			$section = $votes[0];
		} elsif ($votes[1] == 1 && $votes[2] == 'N') {
			$frontpage = $votes[0];
		}
	}
	$sth->finish;

	# Get the highest rating value
	my $max_multiplier = $S->{UI}->{VARS}->{rating_max};
	
	# Divide by the three voting options
	my $div = ($max_multiplier / 3);
	
	
	# Now, calculate the story's vote score
	my $t = ($frontpage	* $max_multiplier) + ($section * ($max_multiplier - $div)) + ($dontcare * ($max_multiplier - (2 * $div))) + ($dump);
	my $count = $frontpage + $section + $dontcare + $dump;
	
	my $vote_score = $t / $count;
	
	return $vote_score;
}


=pod

=over 4

=item *
_check_story_validity($sid, $params)

Takes an array ref of the parameters to save_story, and returns 1 if the story
can be posted, 0 otherwise, with an error message.  This checks to see if they have 
permissions to save the story, if the story is too big, if they've chosen a topic, etc.

=back

=cut

sub _check_story_validity {
	my $S = shift;
	my $sid = shift;
	my $params = shift;

	my $currtime = $S->_current_time;

	# Don't let them save if it's an editing story, and 
	# They're over the limit
	if ($params->{edit_in_queue}) {
		my ($disp_mode, $stuff) = $S->_mod_or_show($sid); 
		my $count_in_queue = $S->_count_edit_stories($params->{sid});
		if ($count_in_queue >= $S->var('max_edit_stories')) {
			my $s = ($S->var('max_edit_stories') == 1) ? 'y' : 'ies';
			return (0, "Error: You may not have more than $S->var('max_edit_stories') stor$s in editing at a time.");
		} if ($sid && $disp_mode ne 'edit') {
			return (0, "Error: Story is not currently in editing mode");
		}
	}
	
	# must have:
	# - a non-whitespace title and intro
	# - a topic (if we're using topics)
	# - a section
	my @missing = ();
	if($params->{title} !~ /\S/) {
		push @missing, 'Title';
	}
	if($params->{introtext} !~ /\S/) {
		push @missing, 'Intro text';
	}
	if ($S->var('use_topics') && !($params->{tid} && $params->{tid} ne 'all')) {
		push @missing, 'Topic';
	}
	if( !($params->{section} && $params->{section} ne 'all')) {
		push @missing, 'Section';
	}
	if(@missing) {
		if ($DEBUG) {
			warn "Not saving: insufficient data.\n";
			foreach my $key (keys %{$params}) {
				warn "\t$key, $params->{$key}\n";
			}
		}

		return (0, "Error: invalid/empty fields: " . (join ", ", @missing));
	}

	# don't let them post to a section they don't have permission to 
	unless( $S->have_section_perm('(norm|autofp|autosec)_post_stories', $params->{'section'}) ) {
	warn "trying to post to section $params->{section}";
		if( $S->have_section_perm('deny_post_stories', $params->{'section'}) ) {
			return (0, "Sorry, but you don't have permission to post stories to section '$params->{'section'}'.");
		} else {
			return (0, "Sorry, that section does not exist.");
		}
	}

	# return 0 if they aren't who they say they are or they are not an editor
	if ($S->{UID} ne $params->{aid} && !$S->have_perm('story_list')) {
	
		# then they are a phoney, return
		warn "Not saving: uid doesn't match aid\n" if ($DEBUG);
		return (0, "Sorry, you don't appear to be a valid editor for this story");
	}

	# Check for sid overwrite
	if( ($S->_check_for_story($sid)) && !$S->have_perm('story_list') ) {
		unless ( ($S->{UID} eq $params->{aid}) ) {	
			# this is an attempt to update an existing story by someone 
			# who doesn't have permission to do so.
			warn "Not saving: sid already exists\n" if ($DEBUG);
			return (0, "Sorry, you don't have permission to update this story");
		}
	}
	
	# Check for posting permissions
	unless( $S->have_perm( 'story_post' ) ) {
		
		# log it in case of script attack
		warn "<< WARNING >> Anonymous Story Posting Denied at $currtime, IP: $S->{REMOTE_IP}   Title: \"$params->{title}\"\n";
		return (0, "Sorry, you don't have permission to post a story here");
	}

	# get word/char maxes for the intro
        # Set it to zero if we have evade_intro_limits perm
	my $max_intro_words = (!$S->have_perm('evade_intro_limits')) ? $S->{UI}->{VARS}->{max_intro_words} : 0;
        my $max_intro_chars = (!$S->have_perm('evade_intro_limits')) ? $S->{UI}->{VARS}->{max_intro_chars} : 0;
        my $min_intro_words = (!$S->have_perm('evade_intro_limits')) ? $S->{UI}->{VARS}->{min_intro_words} : 0;
        my $min_intro_chars = (!$S->have_perm('evade_intro_limits')) ? $S->{UI}->{VARS}->{min_intro_chars} : 0;
	my $max_title_len = $S->{UI}->{VARS}->{max_title_len} || 100;
        my $max_warn = $S->{UI}->{BLOCKS}->{'max_intro_warning'};
        my $min_warn = $S->{UI}->{BLOCKS}->{'min_intro_warning'};

	# Check number of chars in title
	my $tchars = $S->count_chars($params->{title});
	if( $max_title_len && ($max_title_len < $tchars) ) {
		return (0, "You have $tchars characters in the title of your story. The limit is $max_title_len characters.");
	}
	warn $tchars, " chars in title" if $DEBUG;
	
	# Check number of words in intro
        if( $max_intro_words && ($max_intro_words < $S->count_words($params->{introtext}) )) {
                $max_warn =~ s/__MAXINTRO__/$max_intro_words/g;
                $max_warn =~ s/__UNIT__/words/g;
                return (0, $max_warn);
        }
        warn $S->count_words($params->{introtext}), " words in intro" if $DEBUG;
        # Check number of chars in intro
        if( $max_intro_chars && ($max_intro_chars < $S->count_chars($params->{introtext}) )) {
                $max_warn =~ s/__MAXINTRO__/$max_intro_chars/g;
                $max_warn =~ s/__UNIT__/characters/g;
                return (0, $max_warn);
        }
        warn $S->count_chars($params->{introtext}), " chars in intro" if $DEBUG;

        # And same for min
        if( $min_intro_words && (($min_intro_words > $S->count_words($params->{introtext})) && !$params->{bodytext} )) {
                $min_warn =~ s/__MININTRO__/$min_intro_words/g;
                $min_warn =~ s/__UNIT__/words/g;
                return (0, $min_warn);
        }
        warn $S->count_words($params->{introtext}), " words in intro" if $DEBUG;        if( $min_intro_chars && (($min_intro_chars > $S->count_chars($params->{introtext})) && !$params->{bodytext} )) {
                $min_warn =~ s/__MININTRO__/$min_intro_chars/g;
                $min_warn =~ s/__UNIT__/characters/g;
                return (0, $min_warn);
        }
        warn $S->count_chars($params->{introtext}), " chars in intro" if $DEBUG;

	return (1, "Success!");
}


sub _count_edit_stories {
	my $S = shift;
	my $sid = shift;
	my $q_aid = $S->dbh->quote($S->{UID});
	my $q_sid = $S->dbh->quote($sid);
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'COUNT(*)',
		FROM => 'stories',
		WHERE => "displaystatus = -3 AND aid = $q_aid AND sid != $q_sid"});
	
	my $count = $sth->fetchrow();
	$sth->finish();
	
	return $count;
}


sub _send_story_mail {
	my $S = shift;
	my $sid = shift;
	my $mode = shift;

	my ($rv, $sth) = $S->db_update({
		WHAT  => 'stories',
		SET   => 'sent_email = 1',
		WHERE => qq|sid = '$sid' AND sent_email = 0|
	});
	$sth->finish;

	# check to make sure the query actually did something. if not, either the
	# sid doesn't exist, or more likely, the email was already sent, and we
	# don't want to send a duplicate
	unless ($rv >= 1) {
		return;
	}

	# get the info needed to send the email
	($rv, $sth) = $S->db_select({
		WHAT => 'aid, title',
		FROM => 'stories',
		WHERE => qq|sid = '$sid'|});
	my $info = $sth->fetchrow_arrayref;
	$sth->finish;
	$info->[1] =~ s/&quot;/"/g;    # unfilter the title
	$info->[1] =~ s/&amp;/&/g;

    my $uid = $info->[0];
    return if $uid == -1;	# anon user doesn't get any e-mail
	my $uname = $S->get_nick_from_uid($uid);
	my $user = $S->user_data($uid);
    my $path = $S->{UI}->{VARS}->{rootdir};
	my $subject;
	my $message;
	my $url = "$S->{UI}->{VARS}->{site_url}$path/story/$sid";
	if ($mode eq "posted") {
		$subject = "Story by $uname has been posted";
		$message = qq|
A story that you submitted titled "$info->[1]" on $S->{UI}->{VARS}->{sitename} has been posted.

If you would like to view the story, it is available at the following URL:

$url

Thanks for using $S->{UI}->{VARS}->{sitename}!

$S->{UI}->{VARS}->{local_email}|;
	} else {
		$subject = "Story by $uname has been hidden";
		$message = qq|
A story that you submitted titled "$info->[1]" on $S->{UI}->{VARS}->{sitename} has been declined by the voters.

It may still be viewed at the following URL, where any posted comments may
give you insight as to why the score dropped:

$url

If you'd like, you may make any needed changes and resubmit your story.

Thanks for using $S->{UI}->{VARS}->{sitename}!

$S->{UI}->{VARS}->{local_email}|;
	}

	$rv = $S->mail($user->{realemail}, $subject, $message);
}#'


sub _check_story_status {
	my $S = shift;
	my $sid = shift;
	$sid = $S->dbh->quote($sid);
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'displaystatus, writestatus',
		ARCHIVE => $S->_check_archivestatus($sid),
		FROM => 'stories',
		WHERE => qq|sid = $sid|});
	
	my $info = $sth->fetchrow_hashref;
	$sth->finish;
	my $dispstat = $info->{displaystatus};
	my $writestat = $info->{writestatus};
	
	return ($dispstat, $writestat);
}


sub _transfer_comments {
	my $S = shift;
	my $sid = shift;
	my $pid = 0;
	my ($uid, $cid, $points, $comment, $subject, $date, $nick);
	$sid = $S->dbh->quote($sid);
	
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'storymoderate',
		WHERE => qq|sid = $sid|});
	
	my $i = 0;
	while (my $vote = $sth->fetchrow_hashref) {
		if ($vote->{comment}) {
			$cid = $S->_make_cid($sid);
			$uid = $vote->{uid};
			$points = 0;
			$date = $vote->{time};
			$comment = $vote->{comment};
			$subject = $vote->{comment};
			$subject =~ s/<.*?>//g;
			$subject =~ /(.{1,35})/;
			$subject = $1.'...';
			$nick = $S->get_nick($uid);
			$comment = qq|
			<I>$nick voted $vote->{vote} on this story.</I><P>|.$comment;
		
			$comment = $S->{DBH}->quote($comment);
			$subject = $S->{DBH}->quote($subject);
			my ($rv2, $sth2) = $S->db_insert({
				DEBUG => 0,
				INTO => 'comments',
				COLS => 'sid, cid, pid, date, subject, comment, uid, points',
				VALUES => qq|$sid, $cid, $pid, '$date', $subject, $comment, $uid, $points|});
		
			$i++;
		}
	}
	$sth->finish;
	
	$S->_delete_mod_comments($sid);
	return $i;
}


sub _delete_mod_comments {
	my $S = shift;
	my $sid = shift;
	$sid = $S->dbh->quote($sid);
	
	my $rv = $S->db_delete({
		FROM => 'storymoderate',
		WHERE => qq|sid = $sid|});
	
	return 1;
}

1;
