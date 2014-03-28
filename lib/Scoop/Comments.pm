package Scoop;
use strict;
my $DEBUG = 0;

sub comment_dig {
	my $S = shift;

	my $sid = $S->{CGI}->param('sid');
	my $pid = $S->{CGI}->param('pid');
	my $cid = $S->{CGI}->param('cid');
	my $tool = $S->{CGI}->param('tool');
	my $mode = $S->{CGI}->param('mode');
	my $post = $S->cgi->param('post');
	my $preview = $S->cgi->param('preview');
	my $showrate = $S->{CGI}->param('showrate');
	my $check_comment = $S->{CGI}->param('pending');
	my ($dynamic, $dynamicmode);
	if ($S->{UI}->{VARS}->{allow_dynamic_comment_mode}) {
		$dynamic = ($S->{CGI}->param('op') eq 'dynamic') ? 1 : 0;
		$dynamicmode = $S->{CGI}->param('dynamicmode');
	} else {
		$dynamic = 0;
		$dynamicmode = 0;
	}

	# some variables for use in the plethora of conditionals below
	my $section = $S->_get_story_section($sid);
	my $sect_post_perm;
	my $sect_read_perm;
	# this can be set to true during the perm checking to supress displaying
	# the story title, for security purposes
	my $no_title = 0;

	# make sure you treat it properly if its a poll
	if ($S->_does_poll_exist($sid)) {
		$sect_post_perm = $S->have_perm('poll_post_comments');
		$sect_read_perm = $S->have_perm('poll_read_comments');
	} else {
		$sect_post_perm = $S->have_section_perm('norm_post_comments',$section);
		$sect_read_perm = $S->have_section_perm('norm_read_comments',$section);
	}

	$S->{UI}->{BLOCKS}->{subtitle} = 'Comments %%bars%% ';
	
	# Set variables for the dynamic template, and coerce into dynamic mode
	# if we're in a dynamic page
	if ($S->{UI}->{VARS}->{allow_dynamic_comment_mode} && $dynamic) {
		$S->_setup_dynamic_blocks($sid);
		$S->{UI}->{VARS}->{dynamicmode} = ($dynamicmode? 1 : 0);
		$S->{UI}->{VARS}->{mainpid} = 0; # No longer used
		$mode = 'dynamic';
	}

	my $quoted_sid = $S->dbh->quote($sid);
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'title, displaystatus',
		FROM => 'stories',
		WHERE => qq|sid = $quoted_sid|
	});
	my ($story_title, $story_status) = $sth->fetchrow_array();
	$sth->finish;

	my $delete_confirm;
	if ($tool eq 'delete' && $S->have_perm( 'comment_delete' )) {
		if ($S->{CGI}->param('confirm') eq 'delete') {
			$S->_delete_comment($sid, $cid, $pid);
		} else {
			$delete_confirm = $S->_confirm_delete_comment($sid, $cid, $tool);
		}
	}
	if ($tool eq 'remove' && $S->have_perm( 'comment_remove' )) {
		if ($S->{CGI}->param('confirm') eq 'delete') {
			$S->_remove_comment($sid, $cid, $pid);
		} else {
			$delete_confirm = $S->_confirm_delete_comment($sid, $cid, $tool);
		}
	}
	
	if ( ($tool eq 'toggle_editorial' || $tool eq 'toggle_normal') && $S->have_perm( 'comment_toggle' )) {
		$S->comment_toggle_pending($sid, $cid, $tool);
	}
	
	if ( $S->{CGI}->param('spellcheck') ) {
		$preview = 'Preview';
		$post = '';
	}

	# Check formkey
	unless ($S->check_formkey()) {
		$S->{UI}->{BLOCKS}->{COMM_ERR} = qq|
		<table cellpadding="1" cellspacing="0" border="0" width="100%">
			<tr><td>%%norm_font%%<font color="FF0000"><b>Form key invalid. This is probably because you clicked 'Post' or 'Preview' more than once. DO NOT HIT 'BACK'! If you're sure you haven't already posted this once, go ahead and post (or preview) from this screen.</b></font>%%norm_font_end%%<p></td></tr>
		</table>|;
		$preview = 'Preview';
		$post = '';
	}

	if ( $tool eq 'post' && $post ) {
		my $err;
		if ($S->have_perm( 'comment_post' ) && !$S->_check_archivestatus($sid)) {

			# Check for editorial/topical
			if ( $S->{CGI}->param('pending') == -1) {
				$err .= qq|
					%%norm_font%%<font color="FF0000"><b>Before posting your comment you must either choose for it to be editorial or topical.</b></font>%%norm_font_end%%<p>|;
				$preview = 'Preview';
				$post = '';
			} 
			
			# Check for subject line
			my $check_subj = $S->{CGI}->param('subject');
			$check_subj =~ s/\&nbsp\;//gi;	# Filter spaces out for the check
			unless ( $check_subj && ($check_subj =~ /\w+/) ) {
				$err .= qq|
					%%norm_font%%<font color="FF0000"><b>Please enter a subject for your comment.</b></font>%%norm_font_end%%<p>|;
				$preview = 'Preview';
				$post = '';
			}

			# Now try to post.
			if ( !$preview ) {
				if (my $new_cid = $S->post_comment()) {
					$cid = $new_cid;
					$mode = 'confirm';
				} else {
					$err .= qq|
						%%norm_font%%<b>Post Failed.</b> |.$S->{DBH}->errstr."%%norm_font_end%%<p>";
					$err .= $S->{DBH}->errstr . "<br />\n" if $S->{DBH}->errstr;
					my $checker_error = $S->html_checker->errors_as_string;
					$err .= $checker_error . "\n" if $checker_error;
					$err .= "%%norm_font_end%%<p>";
					$preview = 'Preview';
					$post = '';
				}
			}
		} else {
			$err .= qq|
				%%norm_font%%<b>Post Failed.</b> |.$S->{DBH}->errstr."%%norm_font_end%%<p>";
			$preview = 'Preview';
			$post = '';
		}


		$err .= $S->{DBH}->errstr . "<br />\n" if $S->{DBH}->errstr;
		my $checker_error = $S->html_checker->errors_as_string;
		$err .= $checker_error . "\n" if $checker_error;
		$err .= "%%norm_font_end%%<p>";

		$S->{UI}->{BLOCKS}->{COMM_ERR} = $err if ($err);
	} 
	
	if ($cid && $cid =~ /\d+/) {
		my $quoted_sid = $S->dbh->quote($sid);
		my ($rv, $sth) = $S->db_select({
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT => 'pid',
			FROM => 'comments',
			WHERE => qq|cid = $cid AND sid = $quoted_sid|});
		my $id = $sth->fetchrow_hashref;
		$sth->finish;
		$pid = $id->{pid};
	} 
	
	# Make sure the mode reflects the current mode, for post_form
	$S->{PARAMS}->{'post'} = $post;
	$S->{PARAMS}->{'preview'} = $preview;
	
	my $page;
	my $keys;

	if ($tool eq 'post' && !$post && $S->have_perm( 'comment_post' ) && $sect_post_perm && !$S->_check_archivestatus($sid) ) {
		$page = $S->{UI}->{BLOCKS}->{commentreply_display};

		if (!$cid) {
			$keys->{'replying_to'} = $S->displaystory($sid);
		} else {
			$keys->{'replying_to'} = $S->display_comments($sid, $pid, 'alone');
		}

		$keys->{'post_form'} = $S->post_form();
	} elsif ($tool eq 'post' && $mode eq 'confirm' && $S->have_perm( 'comment_post' ) && $sect_post_perm && !$S->_check_archivestatus($sid)) {
		$page = $S->{UI}->{BLOCKS}->{comment_posted_display};
		$keys->{'comment_controls'} = $S->comment_controls($sid, 'top');
		if ($S->{UI}->{VARS}->{use_mojo} && $S->{TRUSTLEV} == 0) {
			$keys->{'post_msg'} = $S->{UI}->{BLOCKS}->{untrusted_post_message};
		} else {
			$keys->{'post_msg'} = $S->{UI}->{BLOCKS}->{comment_posted_message};
		}
		
		$keys->{'new_comment'} = $S->display_comments($sid, $pid, 'alone', $cid);
	} elsif (!$S->have_perm('moderate') && ($story_status <= -2)) {
		$page = qq|<p><b>%%norm_font%%Sorry, you don't have permission to see comments in the queue.%%norm_font_end%%</b></p>|;
		$no_title = 1;
	} elsif ( $sect_read_perm ) {
		if ($dynamic && !$dynamicmode) {
			# In collapsed mode, just show the comment counts
			$page = $S->display_comments($sid, $pid, 'collapsed');
		} else {
			# Get all relevant ratings
			my $rate = $S->get_comment_option('ratingchoice');

			my $comments = $S->display_comments($sid, $pid, $mode);

			if ($showrate) {
				$comments .= '%%BOX,show_comment_raters%%';
			}

			if (!$dynamic) {
				$page .= $S->comment_controls($sid, 'top');
			}

			$page .= "<p>$delete_confirm</p>" if $delete_confirm;
			$page .= qq|$comments|;

			if ($comments && !$dynamic) {
				$page .= '<p>';
				$page .= $S->comment_controls($sid, 'top');
			}
		}
	} else {
		if ( $tool eq 'post' && $S->have_section_perm('deny_post_comments', $section )) {
			$page = qq|
				<b>%%norm_font%%You don't have permission to post comments to this section.%%norm_font_end%%</b>|;
		} elsif ( $tool ne 'post' && $S->have_section_perm('deny_read_comments', $section )) {
			$page = qq|
				<b>%%norm_font%%You don't have permission to read comments in this section.%%norm_font_end%%</b>|;
		} else {
			$page = qq|<b>%%norm_font%%Sorry, I couldn't find that story.%%norm_font_end%%</b>|;
		}
		$no_title = 1;
	}

	unless ($no_title) {
		$S->{UI}->{BLOCKS}->{subtitle} .= $story_title;
		$S->{UI}->{BLOCKS}->{subtitle} =~ s/</&lt;/g;
		$S->{UI}->{BLOCKS}->{subtitle} =~ s/>/&gt;/g;
	}

	$page = $S->interpolate($page,$keys);
	$S->{UI}->{BLOCKS}->{CONTENT} = $page;
	return;
}

sub _setup_dynamic_blocks {
	my $S = shift;
	my $sid = shift;

	my $collapse_symbol = $S->js_quote($S->{UI}->{BLOCKS}->{dynamic_collapse_link});
	my $expand_symbol = $S->js_quote($S->{UI}->{BLOCKS}->{dynamic_expand_link});
	my $loading_symbol = $S->js_quote($S->{UI}->{BLOCKS}->{dynamic_loading_link});
	my $loading_message = $S->js_quote($S->{UI}->{BLOCKS}->{dynamic_loading_message});
	my $rootdir = $S->js_quote($S->{UI}->{VARS}->{rootdir} . '/');
	$sid = $S->filter_param($sid);
	my $sidesc = $S->js_quote($sid);

	$S->{UI}->{BLOCKS}->{dynamicmode_javascript} = $S->{UI}->{BLOCKS}->{dynamic_js_tag};
	# Sorry about the ugly indentation here, but some less
	# intelligent JS parsers (like Konqueror 2.x's) won't execute
	# JS statements that don't start at the beginning of the line
	$S->{UI}->{BLOCKS}->{dynamicmode_javascript} .= qq|
<SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript"><!--
collapse_symbol = '$collapse_symbol';
expand_symbol = '$expand_symbol';
loading_symbol = '$loading_symbol';
loading_message = '$loading_message';
rootdir = '$rootdir';
sid = '$sidesc';
//--></SCRIPT>|;
	$S->{UI}->{BLOCKS}->{dynamicmode_iframe} = qq|<IFRAME WIDTH=0 HEIGHT=0 BORDER=0 STYLE="width:0;height:0;border:0" ID="dynamic" NAME="dynamic" SRC="about:blank"></IFRAME>|;
}

sub _confirm_delete_comment {
	my $S = shift;
	my ($sid, $cid, $tool) = @_;

	return qq~%%norm_font%%To actually delete this comment, <a href="%%rootdir%%/comments/$sid/$cid/$tool?confirm=delete">click here</a>.%%norm_font_end%%~;
}

sub _delete_comment {
	my $S = shift;
	my ($sid, $cid, $pid) = @_;
	
	$pid = 0 unless $pid;

	$S->run_hook('comment_delete', $sid, $cid);

	my $q_sid = $S->dbh->quote($sid);
	my $q_cid = $S->dbh->quote($cid);
	my $q_pid = $S->dbh->quote($pid);

	# First, get the uid of comment poster
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'uid',
		FROM => 'comments',
		WHERE => qq|cid = $q_cid AND sid = $q_sid|});
	
	my $uid = $sth->fetchrow();
	
	# Then delete the comment
	$rv = $S->db_delete({
		ARCHIVE => $S->_check_archivestatus($sid),
		FROM => 'comments',
		WHERE => qq|cid = $q_cid AND sid = $q_sid|});
	
	return unless ($rv);
	
	# Then reparent children of this comment
	$S->db_update({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'comments',
		SET => qq|pid = $q_pid|,
		WHERE => qq|sid = $q_sid AND pid = $q_cid|});
	
	# Drop ratings for comment and recalculate mojo
	$S->_delete_ratings($sid, $cid, $uid);

	# Drop the commentcount cache value.
	$S->_count_cache_drop($sid);
	
	
	# Ok, now we've done it up right.
	return 1;
}

# Instead of completely deleting a comment, replace it with a 
# comment saying that the comment was deleted
sub _remove_comment {
	my $S = shift;
	my ($sid, $cid, $pid) = @_;
	
	$pid = 0 unless $pid;
	return unless $S->have_perm('comment_remove');

	$S->run_hook('comment_delete', $sid, $cid);

	my $removed_body = $S->{UI}->{BLOCKS}->{removed_comment_body};
	my $removed_subject = $S->{UI}->{BLOCKS}->{removed_comment_subject};
	$removed_body =~ s/%%nick%%/$S->{NICK}/g;
	$removed_subject =~ s/%%nick%%/$S->{NICK}/g;
	$removed_body = $S->dbh->quote($removed_body);
	$removed_subject = $S->dbh->quote($removed_subject);

	my $q_sid = $S->dbh->quote($sid);
	my $q_cid = $S->dbh->quote($cid);
	my $q_pid = $S->dbh->quote($pid);

	# Then "delete" the comment
	my ($rv, $sth) = $S->db_update({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'comments',
		SET => qq|comment = $removed_body, subject = $removed_subject|,
		WHERE => qq|cid = $q_cid AND sid = $q_sid|});
	
	return unless ($rv);
	# First, get the uid of comment poster
	($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'uid',
		FROM => 'comments',
		WHERE => qq|cid = $q_cid AND sid = $q_sid|});
	
	my $uid = $sth->fetchrow();
	
	# Drop ratings for comment and recalculate mojo
	$S->_delete_ratings($sid, $cid, $uid);
	
	# Ok, now we've done it up right.
	return 1;
}


sub get_comment_option {
	my $S = shift;
	my $option = shift;
	my $count = shift;
	return unless $option;
	
	# If we're trying to find the mode, we need to know how many comments
	# Can be overridden in the call, or just get all comments
	if ($option eq 'commentmode' && $count) {
		$S->_set_comment_mode($count);
	}
	
	# Check ratingchoice permission specially
	if ($option eq 'ratingchoice' && !$S->have_perm('comment_rate')) {
		return 'no';
	}
	# Check hidingchoice permission specially too
	if ($option eq 'hidingchoice' && ($S->{TRUSTLEV} != 2 && !$S->have_perm('super_mojo'))) {
		return 'no';
	}
	

	my $value;
	# try to find a value for the option by searching, in order, the params,
	# the session, the user prefs, and the site wide defaults
	if ($value = $S->cgi->param($option)) {
		# if the option was passed by param, make it the session default
		$S->session($option, $value);
		return $value;

	} elsif (
		($value = $S->session($option)) ||
		($value = $S->pref($option)) 
	) {
		# hack to make sure dynamic comment mode isn't accidently enabled when
		# it shouldn't be
		if (
			$option eq 'commentmode' &&
			!$S->{UI}->{VARS}->{allow_dynamic_comment_mode} && 
			($value eq 'dthreaded' || $value eq 'dminimal')
		) {
			$value = 'threaded';
		}

		return $value;
	}
}


sub display_comments {
	my $S = shift;
	my $sid = shift;
	my $pid = shift || 0;
	my $mode = shift;
	my $dispmode = $S->get_comment_option('commentmode');
	my $type = $S->get_comment_option('commenttype');
	my $tool = $S->{CGI}->param('tool');
	my $qid = $S->{CGI}->param('qid');
	my $cgipid = $S->{CGI}->param('pid');
	my $cid = shift || $S->{CGI}->param('cid') || 0;
	my @cids = split /\D+/, $S->{CGI}->param('cids');
	my $op = $S->{CGI}->param('op');
	my ($start, $end, $level_start, $level_end, $item_start, $item_end) =
		$S->_get_comment_list_delimiters($sid, $dispmode);

	if($type eq 'none') {
		# If the user is trying to look at a particular comment,
		# fall back to mixed mode
		if($pid || $cid) {
			$type = 'mixed';
		} else {
			return '';
		}
	}

	my $dynamic;
	my $dynamicmode;
	if ($S->{UI}->{VARS}->{allow_dynamic_comment_mode}) {
		$dynamic = ($op eq 'dynamic') ? 1 : 0;
		$dynamicmode = $S->{CGI}->param('dynamicmode');
		if($dynamic) {
			if($dynamicmode) {
				# Expanded comment
				$mode = 'alone';
			} else {
				# Collapsed comment
				$mode = 'collapsed';
			}
		}
	} else {
		$dynamic = 0;
		$dynamicmode = 0;
	}


	if($S->_check_commentstatus($sid)==-1){	# If comments disabled, just bail out
		return '<b>Comments have been Disabled for this Article</b>';
	}	# This would only result from users viewing comments directly

	#$S->_set_comment_order();
	#$S->_set_comment_rating_thresh();
	#$S->_set_comment_type();

	#my $rating_choice;
	#$S->_set_comment_rating_choice();
	
	my $rating_choice = $S->get_comment_option('ratingchoice');
	
	# this is for attaching polls.  So the comments viewed with the poll 
	# are from the story that the poll was attached to.
	if ( $S->_does_poll_exist($sid) ) {
	
		# this if() is so that we only change the sid if its an attached poll,
		# not if its just a normal poll	
		if ( $S->get_sid_from_qid($sid) ) {
			$sid = $S->get_sid_from_qid($sid);
		}
	}

	my $select_this;
	my $order_by;

	my $order = $S->get_comment_option('commentorder');
	my $rating = $S->get_comment_option('commentrating');
	
	if ($rating =~ /^unrate_/) {
		if ($S->{CONFIG}->{mysql_version} =~ /^4/) {
			$order_by = qq|norate asc, |;
		} else {
			$order_by = qq|norate desc, |;
		}	 
	}
	
	if ($rating =~ /highest/) {
		$order_by .= qq|points desc, |;
	} elsif ($rating eq 'lowest') {
		$order_by .= qq|points asc, |;
	}
	
	if ($order eq 'oldest') {
		$order_by .= qq|date asc|;
	} else {
		$order_by .= qq|date desc, cid desc|;
	}
	
	my $date_format = $S->date_format('date');
	my $short_date = $S->date_format('date', 'short');
	
	my $quoted_sid = $S->dbh->quote($sid);
	my $where = qq|sid = $quoted_sid AND cid > $pid|;
	
	my $storymode = $S->_check_story_mode($sid);
	
	if ($type eq 'topical' && $pid == 0) {
		$where .= qq| AND pending = 0|;
	} elsif ($type eq 'editorial' && $pid == 0) {
		$where .= qq| AND pending = 1|;
	} else {
		if (($storymode > -1 && $type ne 'all') && !$cid && $pid == 0) {
			$where .= qq| AND pending = 0|;
		}
	}
	
	$select_this = {
		DEBUG => 0,
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => qq|sid, cid, pid, $date_format as f_date, $short_date as mini_date, subject, comment, uid, points, lastmod AS numrate, points IN (NULL) AS norate, pending, sig_status, sig, commentip|,
 		FROM => 'comments',
		WHERE => qq|$where|,
 		ORDER_BY => $order_by
	};

	
	if ($mode eq 'alone' || $mode eq 'collapsed') {
		if(@cids) {
			my $cids = join ',', @cids;
			$select_this->{WHERE} = qq|sid = $quoted_sid AND cid IN ($cids)|;
			# Treat each comment we're fetching as toplevel
			$pid = 0;
		} else {
			$select_this->{WHERE} = qq|sid = $quoted_sid AND cid = $cid|;
		} 
	} 

	if ($cid && ($tool ne 'post') && ($mode ne 'alone') && ($mode ne 'collapsed')) {
		$select_this->{WHERE} = qq|sid = '$sid' AND cid >= $cid|;
	}

	my ($rv, $sth) = $S->db_select($select_this);
	$#{$S->{CURRENT_COMMENT_LIST}} = $rv;
	
	# Get all the comments
	my $i = 0;
	my %users;
	while (my $com = $sth->fetchrow_hashref()) {
		warn "Found comment: $com->{cid}\n" if ($DEBUG);

		# Set points and numrate to friendlier values if the comment
		# hasn't yet been rated
		$com->{points} = 'none'	unless defined($com->{points});
		$com->{numrate} = '0'	if ($com->{numrate} == '-1');

		# When grabbing a list of comments, treat them all as toplevel
		$com->{pid} = 0         if @cids;

		# Push this comment on the global list
		$S->{CURRENT_COMMENT_LIST}->[$i] = $com;
		# And add the index to its parent slot in the thread list
		push @{$S->{CURRENT_COMMENT_THREAD}->{$com->{pid}}}, $i;

		# For unthreaded, keep a second list in original select order.
		# Is there a better way to do this? I can't think of one.
		# This is just a reference list though. Shouldn't be too bad.
		push @{$S->{ORIGINAL_COMMENT_ORDER}}, $i;
		
		# And add the uid to the users list, so we can precache those
		$users{$com->{uid}} = 1;
		$i++;
	}
	$sth->finish();

	my $count_top = $cid || $pid;
	my $count = $S->_count_current_comments($count_top);
	warn "Count is $count\n" if ($DEBUG);
	#$S->_set_comment_mode($count);
	$dispmode = $S->get_comment_option('commentmode', $count);
	warn "Set mode to $dispmode\n" if ($DEBUG);
	if ($dispmode eq 'dthreaded' || $dispmode eq 'dminimal') {
		$S->_setup_dynamic_blocks($sid);
	}

	# Prefetch user info
	my @u = keys(%users);
	$S->user_data(\@u);
	
	my $comment_start = "";

	# Make the initial rating form...
	$comment_start .= qq|<FORM NAME="rate" ACTION="%%rootdir%%/" METHOD="POST">
						<INPUT TYPE="hidden" NAME="sid" VALUE="$sid">
						<INPUT TYPE="hidden" NAME="op" VALUE="$op">
						<INPUT TYPE="hidden" NAME="pid" VALUE="$pid">| unless ($dynamic);

	# if it's a poll, add a line about the qid
	if ( $S->_does_poll_exist($sid) ) {
		$comment_start .= qq| <INPUT TYPE="hidden" NAME="qid" VALUE="$sid"> |;
	} elsif ( $qid ) {
		$comment_start .= qq| <INPUT TYPE="hidden" NAME="qid" VALUE="$qid"> |;
	}

	my $comments;
 	if (!$dynamic && ($dispmode eq 'minimal' || $dispmode eq 'dminimal')) {
 		$comments .= $start;
	} 	
	
	# See which list to use
	my $list_to_use = ($dispmode eq 'flat_unthread') ? 
					  $S->{ORIGINAL_COMMENT_ORDER} : 
	                  $S->{CURRENT_COMMENT_THREAD}->{$pid};
					  
	foreach my $i (@{$list_to_use}) {
		warn "($pid) Looking at list item $i (cid: $S->{CURRENT_COMMENT_LIST}->[$i]->{cid}, pid: $S->{CURRENT_COMMENT_LIST}->[$i]->{pid})\n" if ($DEBUG);
		# Skip this if it's not the right level
		#if ($S->{CURRENT_COMMENT_LIST}->[$i]->{pid} != $pid) {
		#	warn "($pid) Wanted pid $pid. Skipping\n" if ($DEBUG);
		#	$i++;
		#	next;
		#} 
		if ($cid && ($S->{CURRENT_COMMENT_LIST}->[$i]->{cid} != $cid)) {
			warn "($pid) Right parent, but we want only one thread ($cid). Skipping.\n" if ($DEBUG);
			next;
		}
		
		# Skip the comment entirely if we don't have perm to see it
		next if ($S->skip_hidden_comment($S->{CURRENT_COMMENT_LIST}->[$i]));
		
		# Otherwise, splice off this comment and get busy
		my $comment = $S->{CURRENT_COMMENT_LIST}->[$i];
		warn "($pid) We want this one! Formatting.\n" if ($DEBUG);
		
		# Set $i back to 0, because we don't know how many comments
		# we'll be pulling off the list after this...
		#$i = 0;
		
		$comment->{mode} = $mode;
		#$comment->{sid} = $sid;

		$comments .= qq|<DIV ID="$comment->{cid}">| if $dynamic;
		if($mode eq 'collapsed') {
			$comments .= $S->_get_comment_subject($sid, $pid, 'collapsed', $comment);
		} else {
			$comments .= $S->format_comment($comment);
		}
		$comments .= qq|</DIV>| if $dynamic;
	}

        if (!$dynamic && ($dispmode eq 'minimal' || $dispmode eq 'dminimal')) { 
                $comments .= $end;
        }

	#$sth->finish;
	
	my $comments_end = qq|</FORM>| unless $dynamic;
	
	if ($comments) {
		$comments = $comment_start.$comments.$comments_end;
	}
	delete $S->{CURRENT_COMMENT_LIST};
	delete $S->{CURRENT_COMMENT_THREAD};
	delete $S->{ORIGINAL_COMMENT_ORDER};
	
	# I don't know why this line was here.
	# It made "seen stories" update on comment view
	# *only* if you weren't using the page cache.
	# I wrote it, but fucked if I know what I was thinking. --rusty
	#$S->update_seen_if_needed($sid) unless ($S->{UI}->{VARS}->{use_static_pages});   # does the seen stories work
	
	return $comments;
}

sub skip_hidden_comment	{
	my $S = shift;
	my $comment = shift; # hashref of current comment
	my $hide_thresh = $S->{UI}->{VARS}->{hide_comment_threshold} || $S->{UI}->{VARS}->{rating_min};
	if (($S->{UI}->{VARS}->{use_mojo}) &&
	    ($comment->{points} ne 'none') && 
		($comment->{points} < $hide_thresh)) {
		
		# If we just don't have permission, skip it
		if (($S->{TRUSTLEV} != 2) && 
			(!$S->have_perm('super_mojo'))) {
			warn "($comment->{pid}) Permissions not granted. Skipping.\n" if ($DEBUG);
			return 1;
		}
		# If we do have permission, see if we chose not to see
		my $hide = $S->get_comment_option('hidingchoice');
		if ($hide eq 'no') {
			warn "($comment->{pid}) Chose to hide hidden comments. Skipping.\n" if ($DEBUG);
			return 1;
		} elsif ($hide eq 'untilrating') {
			# Did I rate this comment?
			my $qsid = $S->dbh->quote($comment->{sid});
			my ($rv, $sth) = $S->db_select({
				WHAT => 'uid',
				FROM => 'commentratings',
				WHERE => qq|uid = $S->{UID} AND cid = $comment->{cid} and sid = $qsid|
			});
			my $rated = $sth->fetchrow();
			if ($rated) {
				warn "($comment->{pid}) Chose to hide hidden comments after rating, and has rated. Skipping.\n" if ($DEBUG);
				return 1;
			}
		}

	}
	return 0;
}

sub _count_current_comments {
	my $S = shift;
	my $pid = shift;
	my $count = shift || 0;
	
	if ($pid && !$count) {
		$count = 1;
	}
	
	foreach my $i (@{$S->{CURRENT_COMMENT_THREAD}->{$pid}}) {
		warn "($pid) Looking at list item $i (cid: $S->{CURRENT_COMMENT_LIST}->[$i]->{cid}, pid: $S->{CURRENT_COMMENT_LIST}->[$i]->{pid})\n" if ($DEBUG);

		if ($S->{CURRENT_COMMENT_LIST}->[$i]->{pid} != $pid) {
			warn "Wrong parent ($S->{CURRENT_COMMENT_LIST}->[$i]->{pid}). Skipping.\n" if ($DEBUG);
			next;
		}
		
		# Skip the comment entirely if we don't have perm to see it
		next if ($S->skip_hidden_comment($S->{CURRENT_COMMENT_LIST}->[$i]));
		
		$count++;
		warn "Incremented counter to $count, exploring thread\n" if ($DEBUG);
		$count = $S->_count_current_comments($S->{CURRENT_COMMENT_LIST}->[$i]->{cid}, $count);
	}
	
	return $count;
}

sub _get_comment_subject {
	my $S = shift;
	my $sid = shift;
	my $pid = shift;
	my $mode = shift;
	my $comment = shift;
	
	my $user = $S->user_data($comment->{uid});
	my $postername = $user->{nickname};
	my $ed_tag = '';
	if ($comment->{pending}) {
		$ed_tag = 'Editorial: ';
	}
			
	my $new = '';
	# Check for highest index
	if ($S->{UI}->{VARS}->{show_new_comments} eq 'all') {
		#if ($S->{UI}->{VARS}->{use_static_pages} && $S->{GID} eq 'Anonymous') {
			#$new = '%%new_'.$comment->{cid}.'%%';
			#warn "New is $new\n";
		#} elsif (($S->{UID} >= 0) && !$S->_check_archivestatus($sid)) {
		if (($S->{UID} >= 0) && !$S->_check_archivestatus($sid)) {
			my $highest = $S->story_highest_index($sid);
			if ($comment->{cid} > $highest) {
				$new = $S->{UI}->{BLOCKS}->{new_comment_marker};
			}
		}
	}

	my ($link,$open_link);
	my $openurl = "%%rootdir%%/comments/$sid";

	if(!$pid) {
		$openurl .= "/$comment->{cid}#$comment->{cid}";
	} else {
		$openurl .= "?pid=$pid#$comment->{cid}";
	}

	# Make the subject an expand link for dynamic mode, or an open link
	# otherwise.
	if($mode eq 'dminimal' || $mode eq 'dthreaded' || $mode eq 'collapsed') {
		$link = qq|javascript:void(toggle($comment->{cid}))|;
		$open_link = qq| [<a href="$openurl">open</a>]|;
	} else {
		$link = qq|$openurl|;
		$open_link = '';
	}

	my $member = $S->{UI}->{BLOCKS}->{"mark_$user->{perm_group}"};

	# This should probably be made into a block
	return qq|%%norm_font%%$new $ed_tag<a class="light" href="$link">$comment->{subject}</a> by $postername$member, %%norm_font_end%%%%smallfont%%$comment->{mini_date} (<b>$comment->{points} / $comment->{numrate}</b>)$open_link%%smallfont_end%%|;

}

sub _get_comment_list_delimiters {
	my $S = shift;
	my $sid = shift;
	my $dispmode = shift;
	my $depth = shift || 0;
	my $plus = $S->{UI}->{BLOCKS}->{dynamic_expand_link} || '+';
	my $minus = $S->{UI}->{BLOCKS}->{dynamic_collapse_link} || '-';
	my $pid = $S->{CGI}->param('pid');
	my $cid = $S->{CGI}->param('cid');

	my ($start, $end, $level_start, $level_end, $item_start, $item_end);

	if ($dispmode ne 'flat' && $dispmode ne 'flat_unthread' && $dispmode ne 'nested' && $dispmode ne 'dthreaded' && $dispmode ne 'dminimal') {
		$start = $S->{UI}->{BLOCKS}->{delimiter_default_start};
		$end = $S->{UI}->{BLOCKS}->{delimiter_default_end};
		$level_start = $S->{UI}->{BLOCKS}->{delimiter_default_levelstart};
		$level_end = $S->{UI}->{BLOCKS}->{delimiter_default_levelend};
		$item_start = $S->{UI}->{BLOCKS}->{delimiter_default_itemstart};
		$item_end = $S->{UI}->{BLOCKS}->{delimiter_default_itemend};
	} elsif ($dispmode eq 'dthreaded' || $dispmode eq 'dminimal') {
		# We don't want to indent the first level
		if($depth <= 0) {
			$start = '';
			$end = '';
		} else {
			$start = $S->{UI}->{BLOCKS}->{delimiter_dyn_start};
			$end = $S->{UI}->{BLOCKS}->{delimiter_dyn_end};
		}
		# If we're at the top level of a dthreaded thread, make a
		# collapse link. Otherwise, make an expand link.
		my($class,$text);
		if($depth <= 0
		   && ($dispmode eq 'dthreaded' || $pid || $cid)) {
			$class = 'dynexpanded';
			$text = $minus;
		} else {
			$class = 'dyncollapsed';
			$text = $plus;
		}

		$item_start = $S->{UI}->{BLOCKS}->{delimiter_dyn_itemstart};
		$item_end = $S->{UI}->{BLOCKS}->{delimiter_dyn_itemend};
                $item_start =~ s/%%text%%/$text/g;
                $item_start =~ s/%%class%%/$class/g;
                $item_end =~ s/%%text%%/$text/g;
                $item_end =~ s/%%class%%/$class/g;
	} elsif ($dispmode eq 'nested') {
		$start = $S->{UI}->{BLOCKS}->{delimiter_nested_start};
		$level_start = $S->{UI}->{BLOCKS}->{delimiter_nested_levelstart};
		$end = $S->{UI}->{BLOCKS}->{delimiter_nested_end};
		$level_end = $S->{UI}->{BLOCKS}->{delimiter_nested_levelend};
	} 
		
	return ($start, $end, $level_start, $level_end, $item_start, $item_end);
}	

sub get_list {
	my $S = shift;
	my $sid = shift;
	my $pid = shift;
	my $dispmode = shift || $S->get_comment_option('commentmode');
	
	# No thread list if unthreaded flat. just return.
	return if ($dispmode eq 'flat_unthread');
	
	my $depth = shift || 1;
	my $cid = $S->{CGI}->param('cid');
	my $plus = $S->{UI}->{BLOCKS}->{dynamic_expand_link} || '+';
	my $wait = $S->{UI}->{BLOCKS}->{dynamic_loading_link} || 'x';
	my @cids;
	
	my ($count, $newcount, $list, $nick, $start, $end, $level_start, $level_end, $item_start, $item_end);
	
	if (!$S->{UI}->{VARS}->{allow_dynamic_comment_mode}) {
		if ($dispmode eq 'dthreaded') {
			$dispmode = 'threaded';
		} elsif ($dispmode eq 'dminimal') {
			$dispmode = 'minimal';
		}
	}

	($start, $end, $level_start, $level_end, $item_start, $item_end) =
		$S->_get_comment_list_delimiters($sid, $dispmode, $depth);

	foreach my $i (@{$S->{CURRENT_COMMENT_THREAD}->{$pid}}) {
		warn "($pid) Looking at list item $i (cid: $S->{CURRENT_COMMENT_LIST}->[$i]->{cid}, pid: $S->{CURRENT_COMMENT_LIST}->[$i]->{pid})\n" if ($DEBUG);
		# Skip this if it's not the right level
		#if ($S->{CURRENT_COMMENT_LIST}->[$i]->{pid} != $pid) {
		#	warn "($pid) Wanted pid $pid. Skipping\n" if ($DEBUG);
		#	$i++;
		#	next;
		#} 
		
		# Skip the comment entirely if we don't have perm to see it
		next if ($S->skip_hidden_comment($S->{CURRENT_COMMENT_LIST}->[$i]));
		
		# Otherwise, splice off this comment and get busy
		#my $S->{CURRENT_COMMENT_LIST}->[$i] = $S->{CURRENT_COMMENT_LIST}->[$i];
		warn "($pid) We want this one! Formatting.\n" if ($DEBUG);
		push @cids, $S->{CURRENT_COMMENT_LIST}->[$i]->{cid};

		# Set $i back to 0, because we don't know how many comments
		# we'll be pulling off the list after this...
		#$i = 0;
				 
		my $user = $S->user_data($S->{CURRENT_COMMENT_LIST}->[$i]->{uid});
		$S->{CURRENT_COMMENT_LIST}->[$i]->{points} = 'none'	unless defined($S->{CURRENT_COMMENT_LIST}->[$i]->{points});
		$S->{CURRENT_COMMENT_LIST}->[$i]->{numrate} = '0' if ($S->{CURRENT_COMMENT_LIST}->[$i]->{numrate} == '-1');

		if ($dispmode eq 'nested' || $dispmode eq 'flat' || $dispmode eq 'flat_unthread') {
			$list .= $level_start;
			$list .= $S->format_comment($S->{CURRENT_COMMENT_LIST}->[$i]);
			$list .= $level_end;
		} else {
			my $item_start_subst = $item_start;
			$item_start_subst =~ s/!cid!/$S->{CURRENT_COMMENT_LIST}->[$i]->{cid}/g;
			$list .= $item_start_subst.$S->_get_comment_subject($sid, $pid, $dispmode, $S->{CURRENT_COMMENT_LIST}->[$i]).$item_end;
			}
			
		if ($dispmode ne 'nested' && $dispmode ne 'flat' && $dispmode ne 'flat_unthread') {
		 	my($sublist,@subcids) = $S->get_list($sid, $S->{CURRENT_COMMENT_LIST}->[$i]->{cid}, $dispmode, $depth+1);
			$list .= $sublist;
			push @cids, (@subcids);
		}
			
	}
	
		$list = $start.$list.$end if ($list);

	if(@cids && ($dispmode eq 'dminimal' || $dispmode eq 'dthreaded')) {
		# Add a bit of script to save the replies list
		my $cids = join ',', @cids;
		if(scalar(@cids) == 1) {
			$cids .= ',null';
		}
		$list .= qq|
<SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript"><!--
replies[$pid] = new Array($cids);
//--></SCRIPT>|;
	}
	return ($list,@cids);
}

sub anon_comment_warn {
	my $S = shift;
	my $subject = shift;
	if (!$S->have_perm( 'comment_post' )) {
		my $time = localtime;
		warn "<< WARNING >> Anonymous comment disallowed at $time. IP: $S->{REMOTE_IP}, Subject: $subject\n";
		return 0;
	}
	return 1;
}

sub fetch_highest_cid {
	my $S = shift;
	my $sid = shift;
	
	my $quoted_sid = $S->dbh->quote($sid);
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'cid',
		FROM => 'comments',
		WHERE => qq|sid = $quoted_sid|,
		ORDER_BY => 'cid DESC',
		LIMIT => 1
	});
	my $highest = $sth->fetchrow();
	$sth->finish();
	return $highest;
}


sub _comment_breakdown {
	my $S = shift;
	my $sid = shift;
	my ($topical, $editorial, $pending, $highest);
	
	my $resource = $sid.'_comments';
	my $element = $sid.'_commentcounts';
	
	if (my $cached = $S->cache->fetch_data({resource => $resource, 
	                                        element => $element})) {
		$topical   = $cached->{topical};
		$editorial = $cached->{editorial};
		$pending   = $cached->{pending};
		$highest   = $cached->{highest};
		
		return ($topical, $editorial, $pending, $highest);
	}
	
	my $cache_me;
	my $quoted_sid = $S->dbh->quote($sid);
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'pending, count(*)',
		FROM => 'comments',
		WHERE => qq|sid = $quoted_sid|,
		GROUP_BY => 'pending'
	});
	
	while (my $row = $sth->fetchrow_arrayref()) {
		($row->[0] == 0) ? $topical = $row->[1] : $editorial = $row->[1];
	}
	$sth->finish();
	$cache_me->{topical} = $topical || 0;
	$cache_me->{editorial} = $editorial || 0;
	
	if ($S->{UI}->{VARS}->{use_mojo}) {
		my $hide_thresh = $S->{UI}->{VARS}->{hide_comment_threshold} || $S->{UI}->{VARS}->{rating_min};
		my ($rv, $sth) = $S->db_select({
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT => 'COUNT(*)',
			FROM => 'comments',
			WHERE => qq|sid = $quoted_sid AND points < $hide_thresh|
		});
		
		$pending = $sth->fetchrow() || 0;
		$sth->finish();
		$cache_me->{pending} = $pending;	
	}

	$highest = $S->fetch_highest_cid($sid);
	$cache_me->{highest} = $highest;
	
	$S->cache->cache_data({resource => $resource,
	                       element => $element,
	                       data => $cache_me});

	return ($topical, $editorial, $pending, $highest);
}

sub _commentcount {
	my $S = shift;
	my $sid = shift;
                
	my $count = 0;  
                
	my($a,$b,$c,$d) = $S->_comment_breakdown($sid);
	$count = $a + $b;
        
	return $count;
}

sub _comment_highest {
	my $S = shift;
	my $sid = shift;
	
	my ($a,$b,$c,$d) = $S->_comment_breakdown($sid);
	return $d;
}

sub _count_cache_drop {
	my $S = shift;
	my $sid = shift;
	my $resource = $sid.'_comments';
	my $element = $sid.'_commentcounts';
	
	# Drop our memory cache for this story
	$S->cache->clear({resource => $resource, element => $element});
	$S->cache->stamp_cache($resource, time(), 1);
	$S->_commentcount($sid);
	
	return;
}	

1;	
