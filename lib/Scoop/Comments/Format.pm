package Scoop;
use strict;

sub format_comment {
	my $S = shift;
	my $comment = shift; # HASHREF
	my $dispmode = $S->get_comment_option('commentmode');
	my ($nick, $this_comment, $replies, $user) = ('') x 4;
	my $op = $S->{CGI}->param('op');
	my $dynamic = ($op eq 'dynamic');
	my $sid = $S->{CGI}->param('sid');
	my $cid = $S->{CGI}->param('cid');	
	my $pid = $S->{CGI}->param('pid');	
	my $tool = $S->{CGI}->param('tool');
	my $commentstatus = $S->_check_commentstatus($sid); # 1 = read only

	my ($start, $end, $level_start, $level_end, $item_start, $item_end) =
		$S->_get_comment_list_delimiters($comment->{sid}, $dispmode);
	
	$user = $S->user_data($comment->{uid});

	if ($comment->{mode} ne 'alone' && $comment->{mode} ne 'Preview') {	
		$replies = ($S->get_list($comment->{sid}, $comment->{cid}))[0] || ''; 
	}

	# This is so that when you rate a comment on a poll page it doesn't kick you out
	# to the main page
	$sid = "";
	if( $S->_does_poll_exist( $comment->{sid} )) {
		$sid = qq|<INPUT TYPE="hidden" NAME="qid" VALUE="$comment->{sid}">
			|;
		$op = "view_poll";
	} else {
		$sid = qq|<INPUT TYPE="hidden" NAME="sid" VALUE="$comment->{sid}">
			|;
	}

	# return nothing unless they have permission to read the comments
	my $section = $S->_get_story_section( $comment->{sid} );
	unless ( ($S->_does_poll_exist( $comment->{sid} ) && $S->have_perm('poll_read_comments') )	||
			$S->have_section_perm('norm_read_comments', $section )) {

		return '';
	}

	if ( !$S->have_perm('editorial_comments') && $comment->{pending} ) {
		return '';
	} 
	
	my $sect_perm_post = $S->have_section_perm('norm_post_comments', $section );
	$sect_perm_post = 1 if ($S->_does_poll_exist($comment->{sid}) && $S->have_perm('poll_post_comments'));
	
	my $rate = $S->get_comment_option('ratingchoice');
	my $action;

	my $posting_comment = ($op eq 'comments' && $tool eq 'post') ? 1 : 0 ;
	
	my $comm_options;
	
	if (($dynamic || $dispmode eq 'dthreaded' || $dispmode eq 'dminimal')  && ($comment->{mode} ne 'Preview')) {
		# Add a button to collapse this comment, and expand/collapse
		# its subthread
		my $minus = $S->{UI}->{BLOCKS}->{dynamic_collapse_bottom_link} || '-';
		my $pplus = $S->{UI}->{BLOCKS}->{dynamic_expand_thread_link} || '++';
		my $mminus = $S->{UI}->{BLOCKS}->{dynamic_collapse_thread_link} || '--';
		$comm_options .= qq|
			<TT><A STYLE="text-decoration:none" HREF="javascript:void(toggle($comment->{cid},1))">$minus</A></TT> \|
			<TT><A STYLE="text-decoration:none" HREF="javascript:void(toggleList(replies[$comment->{cid}],0))">$mminus</A></TT>
			<TT><A STYLE="text-decoration:none" HREF="javascript:void(toggleList(replies[$comment->{cid}],1))">$pplus</A></TT> \||;
	}

	if ($comment->{pid} != 0) {
		my $opstring = 'comments';
		
		my $parent_link = ($dispmode eq 'flat_unthread') ?
						  "#$comment->{pid}" :
						  "%%rootdir%%/$opstring/$comment->{sid}/$comment->{pid}#$comment->{pid}";

		$comm_options .= qq| <A CLASS="light" HREF="$parent_link">Parent</A> |;
		#warn "Comments/Format.pm: Reply to this ".$comment->{sid};
		if (($comment->{mode} ne 'Preview') && ($S->have_perm('comment_post')) && !$posting_comment && !$commentstatus && $sect_perm_post && !$S->_check_archivestatus($comment->{sid}) ) {
			$comm_options .= qq|\| <A CLASS="light" HREF="%%rootdir%%/comments/$comment->{sid}/$comment->{cid}/post#here">Reply to This</A> |;
		}

	} else {
		#warn "Comments/Format.pm: Reply to this ".$comment->{sid};
		if (($comment->{mode} ne 'Preview') && $S->have_perm('comment_post') && !$posting_comment && !$commentstatus && $sect_perm_post && !$S->_check_archivestatus($comment->{sid}) ) {
			$comm_options .= qq| <A CLASS="light" HREF="%%rootdir%%/comments/$comment->{sid}/$comment->{cid}/post#here">Reply to This</A> |;
		}
	}
	
	if ((!$rate || $rate eq 'yes') && ($S->{UID} != $comment->{uid}) && !$S->_check_archivestatus($comment->{sid})) {
		my $curr_rating = $S->_get_current_rating($comment->{sid}, $comment->{cid}, $S->{UID});
		my $rate_form = $S->_rating_form($curr_rating, $comment->{cid});
		if ($rate_form) {
			if ($comm_options) {
				$comm_options .= qq|\||;
			}
			$comm_options .= qq|$rate_form|;
		}
	}
		
		
	my ($user_info, $edit_user, $comment_ip) = ('') x 3;
	if ($comment->{uid} != -1) {
		my $nick = $S->urlify($S->get_nick_from_uid($comment->{uid}));
		$user_info = qq|(<A CLASS="light" HREF="%%rootdir%%/user/$nick">User Info</A>)|;
		if ($S->have_perm('edit_user')) {
			$edit_user = qq| [<A CLASS="light" HREF="%%rootdir%%/user/$nick/edit">Edit User</A>]|;
		}
	}

	# display the IP that the user posted the comment with
	if ($S->have_perm('view_comment_ip')
			&& $S->{UI}->{VARS}->{view_ip_log}
			&& $S->{UI}->{VARS}->{comment_ip_log} ){
		$comment->{commentip} ||= 'unknown';
		$comment_ip = $S->{UI}->{BLOCKS}->{comment_ip_display};
		$comment_ip =~ s/%%ip%%/$comment->{commentip}/g;
	}
	
	my $new = '';
	# Check for highest index
	if (($S->{UI}->{VARS}->{show_new_comments} eq 'all') && !$S->_check_archivestatus($comment->{sid})) {
		
		if ($S->{UI}->{VARS}->{use_static_pages} && $S->{GID} eq 'Anonymous') {
			#$new = '%%new_'.$comment->{cid}.'%%';
		} elsif ($S->{UID} >= 0) {
			my $highest = $S->story_highest_index($comment->{sid});
			if ($comment->{cid} > $highest) {
				$new = $S->{UI}->{BLOCKS}->{new_comment_marker};
			}
		}
	}

	if ($comm_options) {
		$action .= qq|[ $comm_options ]|;
	}
	
	if ($S->have_perm( 'comment_delete' ) && !$posting_comment) {
		my $delete = $S->{UI}->{BLOCKS}->{comment_delete_link};
		$delete =~ s/%%sid%%/$comment->{sid}/g;
		$delete =~ s/%%cid%%/$comment->{cid}/g;
		$action .= $delete;
	}
	if ($S->have_perm( 'comment_remove' ) && !$posting_comment) {
		my $remove = $S->{UI}->{BLOCKS}->{comment_remove_link};
		$remove =~ s/%%sid%%/$comment->{sid}/g;
		$remove =~ s/%%cid%%/$comment->{cid}/g;
		$action .= $remove;
	}
	if ($S->have_perm( 'comment_toggle' ) && !$posting_comment && $S->{UI}->{VARS}->{use_editorial_comments}) {
		my $toggle = 'toggle_normal';
		$toggle = 'toggle_editorial' unless $comment->{pending};
		my $t_link = $S->{UI}->{BLOCKS}->{comment_toggle_link};
		$t_link =~ s/%%sid%%/$comment->{sid}/g;
		$t_link =~ s/%%cid%%/$comment->{cid}/g;
		$t_link =~ s/%%toggle%%/$toggle/g;

		$action .= $t_link;
	}

	if (( ($dispmode eq 'minimal' || $dispmode eq 'dminimal') && ($comment->{mode} ne 'Preview')) && $pid == 0 && (!$cid || $cid != $comment->{cid}) && $comment->{mode} ne 'alone') {
		my $replyblock;
		if ($replies && $replies ne '&nbsp;') {
			$replyblock = qq|$replies|;
		}
		my $item_start_subst = $item_start;
		$item_start_subst =~ s/!cid!/$comment->{cid}/g;

		$this_comment = 
			$item_start_subst .
			$S->_get_comment_subject($comment->{sid}, $pid, $dispmode, $comment) .
			$item_end .
			$replyblock;
	
		return $this_comment;
	}
			
	$this_comment = $S->{UI}->{BLOCKS}->{comment};
	
	if ($comment->{pending}) {
		$this_comment = $S->{UI}->{BLOCKS}->{moderation_comment};
	}

	my $member = $S->{UI}->{BLOCKS}->{"mark_$user->{perm_group}"};

	# See if we can help along the validation process...
	# commented these out, because they seem stupid to me. don't see the point
	# in throwing out a perfectly good paragraph tag
	#$comment->{comment} =~ s/^\s*<p>//gi;
	#$comment->{comment} =~ s/^\s*<br>//gi;
	#$comment->{comment} =~ s/<P>/<BR><BR>/gi;
	#$comment->{comment} =~ s/<\/P>//gi;

	$this_comment =~ s/%%uid%%/$comment->{uid}/g;
	$this_comment =~ s/%%edit_user%%/$edit_user/g;
	$this_comment =~ s/%%name%%/$user->{nickname}/g;
	$this_comment =~ s/%%date%%/$comment->{f_date}/g;
	$this_comment =~ s/%%subject%%/$comment->{subject}/g;
	$this_comment =~ s/%%new%%/$new/g;
	$this_comment =~ s/%%member%%/$member/g;
	
	my ($sig, $comment_text);
	$comment_text = $comment->{comment};
	# check for sig behavior and act accordingly
	if ($user->{prefs}->{sig}) {
		$user->{sig} =~ s/\<\s*a\s*href/<a rel="nofollow" href/ig;
		if ($comment->{sig_behavior} eq 'retroactive' || $comment->{sig_status} == 1) {
			#if normal sig, then proceed as usual
			$sig = $user->{prefs}->{sig};

		} elsif ($comment->{sig_behavior} eq 'sticky' || $comment->{sig_status} == 0) { 
			#if sticky sig and in preview mode, then place sig below comment
			$sig = $comment->{sig};

		} else {
			#the user has a sig but doesn't want it shown
			$sig = "";

		}
	} else {
		$sig = "";
	}
	if (exists($S->{UI}->{VARS}->{use_macros}) && $S->{UI}->{VARS}->{use_macros}) {
		$comment_text = $S->process_macros($comment_text,'comment');
		$sig = $S->process_macros($sig,'pref') if ($sig);
	}

	$this_comment =~ s/%%sig%%/$sig/g;
	$this_comment =~ s/%%rating_format%%/$S->{UI}->{BLOCKS}->{rating_format}/g unless $rate eq 'hide';
	$this_comment =~ s/%%rating_format%%//g; # If not already replaced in previous line, then remove the ey altogether
	$this_comment =~ s/%%comment%%/$comment_text/g;
	$this_comment =~ s/%%cid%%/$comment->{cid}/g;
	$this_comment =~ s/%%actions%%/$action/g;
	$this_comment =~ s/%%comment_ip%%/$comment_ip/g;
	$this_comment =~ s/%%sid%%/$comment->{sid}/g;
	$this_comment =~ s/%%score%%/$comment->{points}/g unless $rate eq 'hide';
	$this_comment =~ s/%%num_ratings%%/$comment->{numrate}/g unless $rate eq 'hide';
	
	if ($user->{fakeemail}) {
		$this_comment =~ s/%%email%%/(<a class="light" href="mailto:$user->{fakeemail}">$user->{fakeemail}<\/a>)/g;
	} else {
		$this_comment =~ s/%%email%%//g;
	}
	if ($user->{homepage}) {
		$this_comment =~ s/%%url%%/<A CLASS="light" HREF="$user->{homepage}" rel="nofollow">$user->{homepage}<\/A>/g;
	} else {
		$this_comment =~ s/%%url%%//g;
	}
	# In dynamic modes, add the dynamic collapse link
	if ((!$dynamic && ($dispmode eq 'dthreaded' || $dispmode eq 'dminimal')) && ($comment->{mode} ne 'Preview')) {
		my $item_start_subst = $item_start;
		$item_start_subst =~ s/!cid!/$comment->{cid}/g;
		$this_comment = $item_start_subst . $this_comment;
		if ($comment->{mode} eq 'alone' && $comment->{mode} ne 'Preview') {
			$this_comment .= $item_end;
		} else {
			$replies = $item_end . $replies;
		}
	}

	if ($comment->{mode} ne 'alone' && $comment->{mode} ne 'Preview') {
		$this_comment =~ s/%%replies%%/$replies/g;
	}

	return $this_comment;
}

# is this sub even used anymore? it doesn't seem to be
sub comment_choices_box {
	my $S = shift;
	my $sid = shift;
	my $pid = $S->{CGI}->param('pid');
	my $cid = $S->{CGI}->param('cid');
	
	my $commentmode_select = $S->_comment_mode_select();
	my $comment_order_select = $S->_comment_order_select();
	my $comment_rating_select = $S->_comment_rating_select();
	my $rating_choice = $S->_comment_rating_choice();
	my $comment_type_select = $S->_comment_type_select();
	
	my $form_op = 'op';
	my $form_op_value = 'displaystory';
	my $id = 'sid';
	
	if ($S->_does_poll_exist($sid)) {
		$form_op       = 'op';
		$form_op_value = 'view_poll';
		$id 		   = 'qid';
	}
		
	my $comment_sort = qq|
			<FORM NAME="commentmode" ACTION="%%rootdir%%/" METHOD="post">
		<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH="100%" BGCOLOR="%%box_content_bg%%">
			<INPUT TYPE="hidden" NAME="$form_op" VALUE="$form_op_value">
			<INPUT TYPE="hidden" NAME="$id" VALUE="$sid">
		
			<TR>
				<TD VALIGN="middle">
					%%norm_font%%
						View:
					%%norm_font_end%%
				</TD>
				<TD VALIGN="top">
					%%norm_font%%<SMALL>
						$comment_type_select
					</SMALL>%%norm_font_end%%
				</TD>
			</TR>
		
		<TR>
			<TD VALIGN="middle">
				%%norm_font%%
					Display:
				%%norm_font_end%%
			</TD>
			<TD>
			%%norm_font%%<SMALL>
				$commentmode_select
			</SMALL>%%norm_font_end%%
			</TD>
		</TR>
		
		<TR>
			<TD VALIGN="middle">
				%%norm_font%%
					Sort:
				%%norm_font_end%%
			</TD>
			<TD VALIGN="top">
				%%norm_font%%<SMALL>
					$comment_rating_select
				</SMALL>%%norm_font_end%%
			</TD>
		</TR>
		<TR>
			<TD>
				%%norm_font%%&nbsp;%%norm_font_end%%
			</TD>
			<TD>
				%%norm_font%%<SMALL>
					$comment_order_select
				</SMALL>%%norm_font_end%%
			</TD>
		</TR>
	|;
		
			
	if ($S->have_perm( 'comment_rate' )) {
		$comment_sort .= qq|
		<TR>
		<TD VALIGN="middle">%%norm_font%%
		Rate?
		%%norm_font_end%%
		</TD>
		<TD VALIGN="top">%%norm_font%%
		<SMALL>$rating_choice</SMALL>
		%%norm_font_end%%
		</TD>
		</TR>|;
	}
	
	$comment_sort .= qq|
	<TR><TD COLSPAN=2 ALIGN="right">%%norm_font%%<INPUT TYPE="submit" NAME="setcomments" VALUE="Set">%%norm_font_end%%</TD></TR>
	</TABLE>
	</FORM>|;

	my $box = $S->make_box("Comment Controls", $comment_sort);
	return $box;
}

sub comment_controls {
	my $S = shift;
	my $sid = shift;
	my $pid = $S->{CGI}->param('pid');
	my $cid = $S->{CGI}->param('cid');

	# don't even bother if they don't have permission to view the story,
	# BUT! let them see this if they have post permissions.  never know how someone
	# would set this up, but if they want to allow posting but not reading, eh.
	my $section = $S->_get_story_section($sid);
	return '' unless( $S->have_section_perm('norm_read_comments', $section )	|| 
						( $S->_does_poll_exist($sid)	&& 
						( $S->have_perm('poll_read_comments') || $S->have_perm('poll_post_comments') )) );
	
	my $s_info = $S->{UI}->{BLOCKS}->{story_info};
	
	my $commentstatus = $S->_check_commentstatus($sid);

	my $story_info_txt = '';
	my $q_sid = $S->dbh->quote($sid);
	unless ( $S->_does_poll_exist($sid) ) {
		my ($rv, $sth) = $S->db_select({
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT => 'title',
			FROM => 'stories',
			WHERE => qq|sid = $q_sid|
			});

		(my $story_info = $sth->fetchrow_hashref);
		$sth->finish;

		$story_info_txt = qq|<A CLASS="light" HREF="%%rootdir%%/story/$sid">$story_info->{title}</A> |;

		# don't display comment stats if comments are disabled
		unless (($commentstatus == -1) || ($S->have_section_perm('hide_read_comments', $section))) {
			my ($topical,  $editorial, $review) = $S->_comment_breakdown($sid);
			$story_info->{commentcount} = ($topical + $editorial);
			my $r_inf;
			if ($S->{UI}->{VARS}->{use_mojo}) {
				#warn "Review is $review\n";
				$r_inf = ", $review hidden";
			}

			my $plural = ($story_info->{commentcount} == 1) ? '' : 's';
			my $edcomments = ($S->{UI}->{VARS}->{use_editorial_comments}) ? ", $editorial editorial" : '';
			$story_info_txt .= qq|\| <B>$story_info->{commentcount}</B> comment$plural ($topical topical${edcomments}${r_inf}) |;
		}

	} else {
		my $comment_num = $S->poll_comment_num($sid);
		my $poll_q = $S->get_poll_hash($sid);

		# put a link to the poll in there, since if they are here they can see it, and know what its attached to
		$story_info_txt = qq|<A CLASS="light" HREF="%%rootdir%%/poll/$sid">$poll_q->{question}</A>|;

		# now if they can read the comments too, put the comment count
		if( $S->have_perm('poll_read_comments') ) {
			$story_info_txt .= qq| \| <B>$comment_num</B> comments |;
		}

	}

	# only give Post Comment link if commentstatus is zero (Comments Enabled)
	unless ($commentstatus) {
		if ($S->have_perm('comment_post')) {
			if ($S->_check_archivestatus($sid)) {
				$story_info_txt .= "| Cannot post in Archive ";
			} else {
				$story_info_txt .= qq|\| <A HREF="%%rootdir%%/comments/$sid/0/post#here"><B>Post A Comment</B></A> | 
			if ($S->have_section_perm('norm_post_comments',$section) && !$S->_does_poll_exist($sid));

				$story_info_txt .= qq|\| <A HREF="%%rootdir%%/comments/poll/$sid/0/post#here"><B>Post A Comment</B></A> | 
			if ($S->_does_poll_exist($sid) && $S->have_perm('poll_post_comments'));
			}
		}
	}
	if ($S->_does_poll_exist($sid) && $S->have_perm('edit_polls')) {
		$story_info_txt .= qq|\| <A CLASS="light" HREF="%%rootdir%%/admin/editpoll/$sid">Edit Poll</A>|;
	} elsif (!$S->_does_poll_exist($sid) && $S->check_edit_story_perms($sid)) {
		$story_info_txt .= qq|\| <A CLASS="light" HREF="%%rootdir%%/admin/story/$sid">Edit Story</A>|;
	}

	$s_info =~ s/%%story_info%%/$story_info_txt/;
	
	return $s_info;
}


sub _comment_mode_select {
	my $S = shift;
	my $mode = $S->get_comment_option('commentmode');
	
	my ($selected_n, $selected_f, $selected_m, $selected_dt, $selected_dm, $selected_u);
	if ($mode eq 'nested') {
		$selected_n = ' SELECTED';
	} elsif ($mode eq 'flat') {
		$selected_f = ' SELECTED';
	} elsif ($mode eq 'minimal') {
		$selected_m = ' SELECTED';
	} elsif ($mode eq 'flat_unthread') {
		$selected_u = ' SELECTED';
	} elsif ($S->{UI}->{VARS}->{allow_dynamic_comment_mode} && $S->pref('dynamic_interface') eq 'on') {
		if ($mode eq 'dthreaded') {
			$selected_dt = ' SELECTED';
		} elsif ($mode eq 'dminimal') {
			$selected_dm = ' SELECTED';
		}
	}
	
	my $select = qq|<SELECT NAME="commentmode" SIZE=1>
		<OPTION VALUE="threaded">Threaded
		<OPTION VALUE="minimal"$selected_m>Minimal
		<OPTION VALUE="nested"$selected_n>Nested
		<OPTION VALUE="flat"$selected_f>Flat
		<OPTION VALUE="flat_unthread"$selected_u>Flat Unthreaded|;
	if ($S->{UI}->{VARS}->{allow_dynamic_comment_mode} && $S->pref('dynamic_interface') eq 'on') {
		$select .= qq|<OPTION VALUE="dthreaded"$selected_dt>Dynamic Threaded|;
		$select .= qq|<OPTION VALUE="dminimal"$selected_dm>Dynamic Minimal|;
	}
	$select .= qq|</SELECT>|;
	
	return $select;
}

sub _comment_type_select {
	my $S = shift;
	my $type = $S->get_comment_option('commenttype');
	
	return '' unless $S->have_perm('editorial_comments') && $S->{UI}->{VARS}->{use_editorial_comments};

	my ($editorial_s, $all_s, $none_s, $topical_s);
	
	if ($type eq 'editorial') {
		$editorial_s = ' SELECTED';
	} elsif ($type eq 'all') {
		$all_s = ' SELECTED';
	} elsif ($type eq 'none') {
		$none_s = ' SELECTED';
	} elsif ($type eq 'topical') {
		$topical_s = ' SELECTED';
	}
	
	
	my $select = qq|<SELECT NAME="commenttype" SIZE=1>
		<OPTION VALUE="mixed">Mixed (default)
		<OPTION VALUE="topical"$topical_s>Topical Only
		<OPTION VALUE="editorial"$editorial_s>Editorial Only
		<OPTION VALUE="all"$all_s>All Comments
		<OPTION VALUE="none"$none_s>No Comments</SELECT>|;
	
	return $select;	
}

sub _comment_order_select {
	my $S = shift;
	my $order = $S->get_comment_option('commentorder');
	
	my ($selected_o);
	if ($order eq 'oldest') {
		$selected_o = ' SELECTED';
	} 
	
	my $select = qq|<SELECT NAME="commentorder" SIZE=1>
		<OPTION VALUE="newest">Newest First
		<OPTION VALUE="oldest"$selected_o>Oldest First
		</SELECT>|;
	
	return $select;
} 


sub _set_comment_mode {
	my $S = shift;
	my $count = shift;
	return unless $count;
	
	# Dynamic subthreads should always be dynamic themselves
	if($S->{UI}->{VARS}->{allow_dynamic_comment_mode} && ($S->{CGI}->param('op') eq 'dynamic')) {
		return 'dynamic';
	}

	my $thismode = $S->cgi->param('commentmode');
	if ($thismode) {
		$S->session('commentmode', $thismode);
		return;
	}
	
	return unless ($S->{SESSION_KEY});

	my $mode = $S->pref('commentmode');
	my $overflow = $S->pref('commentmode_overflow');
	my $overflow_at = $S->pref('commentmode_overflow_at');
	my $return;

	if ( $count > $overflow_at || $mode eq 'use_overflow' ) {
		$return = $overflow;
	} else {
		$return = $mode;
	}
	
	$S->session('commentmode', $return);
	return;
}

sub comment_toggle_pending {
	#mostly verbatim from Elby's Adequacy code
	my $S = shift;
	my $sid = shift;
	my $cid = shift;
	my $tool = shift;

	if ($tool eq 'toggle_editorial') {
		$tool = 1;
	} else {
		$tool = 0;
	}
	if ($S->have_perm('comment_delete')) {
		my ($change, $pending) = $S->_findchildren($sid, $cid);

		my $where = qq|(sid = "$sid") and (cid = $cid|;
		foreach my $cid (@$change) {
			$where .= " or cid = $cid";
		}
                $where .= ")";


		my ($rv, $sth) = $S->db_update({
			DEBUG	=> 0,
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT	=> 'comments',
			SET	=> "pending=$tool",
			WHERE   => $where});
		$sth->finish;

                push @{ $change }, $cid;
		$S->{UI}->{BLOCKS}->{TOP_CONTENT} = "The following comments were changed from " 
			. ($pending ? "Editorial" : "Topical") . " to " 
			. ($pending ? "Topical" : "Editorial") . ": " . (join ", ", @$change) . "\n<P>";
		$S->_count_cache_drop($sid);
                $S->run_hook('comment_toggle', $sid, $cid, $tool);
	}
}

# icky recursion
sub _findchildren {
	# verbatim from Elby's adequacy code (except re-formating by panner)
	my $S = shift;
	my $sid = shift;
	my $cid = shift;
	my $has_parent = shift || [];
	my @cid;

	if (scalar @$has_parent) {
		foreach my $comment (@{ ${$has_parent}[$cid] }) {
			@cid = (
				$comment->{cid},
				@cid,
				$S->_findchildren($sid, $comment->{cid}, $has_parent)
			);
		}
		return @cid;
	} else { 
		my @has_parent;
		my $pending;

		my $q_sid = $S->dbh->quote($sid);
		my ($rv, $sth) = $S->db_select({
        	DEBUG => 0,
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT => 'pending, cid, pid',
			FROM => 'comments',
			WHERE => qq|sid = $q_sid|
		});

		while (my ($s_pending, $s_cid, $s_pid) = $sth->fetchrow()) {
			push @{ $has_parent[$s_pid] }, {
				cid => $s_cid, pid => $s_pid, pending => $s_pending
			};
			if ($s_cid == $cid) {
				$pending = $s_pending;
			}
		}
		@cid = $S->_findchildren($sid, $cid, \@has_parent);
		return (\@cid, $pending);
	}
}

1;
