package Scoop;
use strict;

sub post_form {
	my $S = shift;
	
	# Get input data
	my $sid = $S->{CGI}->param('sid');
	my $pid = $S->{CGI}->param('cid');
	
	my $subject = $S->{CGI}->param('subject');
	my $comment = $S->{CGI}->param('comment');
	my $preview = $S->{CGI}->param('preview');
	my $post = $S->{CGI}->param('post');
	my $uid = $S->{CGI}->param('uid') || $S->{UID};
	my $pending = $S->{CGI}->param('pending');
	my $spellcheck = $S->{CGI}->param('spellcheck');
	my $user = $S->user_data($uid);
	
	my $posttype = $S->set_comment_posttype();
	my $sig_behavior = $S->set_comment_sig_behavior();
	
	my $quoted_sid = $S->dbh->quote($sid);
	my $keys;
	$keys->{'sid'} = $sid;
	$keys->{'pid'} = $pid;
	
	# Decided this was a bad idea, but need the pending value...
	# Set the default subject, if necessary
	my $comm;
	if ($pid) {
		my ($rv, $sth) = $S->db_select({
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT => 'pending, subject',
			FROM => 'comments',
			WHERE => qq|cid = $pid AND sid = $quoted_sid|});
		$comm = $sth->fetchrow_hashref;
		$sth->finish;
	
		if ($S->{UI}->{VARS}->{carry_comment_titles} && !$subject) {
			if ($comm->{'subject'} !~ /^Re:/) {
				$subject = "Re: $comm->{'subject'}";
			} else {
				$subject = "$comm->{'subject'}";
			}
		}
	} else {
		# If we want to carry titles forward, grab the story title
		if ($S->{UI}->{VARS}->{carry_comment_titles} && !$subject) {
			my $title = $S->_get_story_title($sid);
			if ($comm->{'subject'} !~ /^Re:/) {
				$subject = "Re: $title";
			} else {
				$subject = "$comm->{'subject'}";
			}
		}
	}
		
	if ($spellcheck && $S->spellcheck_enabled()) {
		$S->spellcheck_html_delayed();  # set it to spellcheck
	}

	# Filter for the preview
	my $f_subject = $S->filter_subject($subject);
	my $f_comment = $S->filter_comment($comment, 'comment', $posttype, 1);
	$S->html_checker->clear_text_callbacks() if $spellcheck;
	my $filter_errors = $S->html_checker->errors_as_string;
	$S->{UI}->{BLOCKS}->{COMM_ERR} .= $filter_errors if $filter_errors;

	# check the length of the subject (where 50 is the db field length)
	# if too long, trim it (for preview) and warn the user
	if (length($f_subject) > 50) {
		$f_subject = $S->cut_title($f_subject, 50);
		$S->{UI}->{BLOCKS}->{COMM_ERR} .= "<br />\n"
			if $S->{UI}->{BLOCKS}->{COMM_ERR};
		$S->{UI}->{BLOCKS}->{COMM_ERR} .= 'Subject is too long (max is 50 characters).'
	}

	# now spellcheck the subject, if requested. we do it after filter_subject
	# so that our HTML isn't wiped out
	if ($spellcheck && $S->spellcheck_enabled()) {
		$f_subject = $S->spellcheck_string($f_subject);
	}

	my $form = $S->{UI}->{BLOCKS}->{comment_post_form};

	# Make the preview box if necessary
	$keys->{'here'} = 'here';
	if ($preview) {
		my $user = $S->user_data( $S->{UID} );
		my $cur_sig = $user->{prefs}->{sig};

		my $sig_states = { retroactive => 1, sticky => 0, none => -1 };

		my $pre_comment = {
			uid => $uid,
			cid => 0,
			pid => $pid,
			sid => $sid,
			f_date => 'soon',
			mode => 'Preview',
			subject => $f_subject,
			comment => $f_comment,
			pending => $pending,
			sig_behavior => $sig_behavior,
			sig_status => $sig_states->{$sig_behavior},
			sig => $cur_sig };
		
		$keys->{'preview_msg'} = $S->{UI}->{BLOCKS}->{comment_preview_msg};

		$keys->{'PRE_COMMENT'} = $S->format_comment($pre_comment);
		
		$keys->{'here'} = 'there';
	} 
	
	my $anon = $S->get_nick_from_uid('-1');

	if ($S->{UID} <= 0) {
		$keys->{'not_logged_in'} = $S->{UI}->{BLOCKS}->{comment_not_logged_in};
		$keys->{'not_logged_in'} =~ s/%%anon_user_nick%%/$anon/g;
	}

	my $self = $S->{NICK};
	my $content = '';

	if ( $S->{UID} > 0 && $S->have_perm('comment_post','Anonymous') ) {
		$keys->{'post_as'} = qq|Post as:
			<SELECT SIZE=1 NAME="uid">
			<OPTION VALUE="$S->{UID}">$self
			<OPTION VALUE="-1">$anon
			</SELECT>|;
	}

	$keys->{'formkey_element'} = $S->get_formkey_element();

	my $storymode = $S->_check_story_mode($sid);
	
	if ($storymode <= -2 && !$pid && $S->{UI}->{VARS}->{use_editorial_comments}) {
		$keys->{'pending_form'} = $S->pending_select($pending);                
	} else {
		if (defined $comm->{pending}) {
			$pending=$comm->{pending};
		} elsif (defined $pending && ($pending != -1)) {
			$pending=$pending;
		} else {
			$pending=0;
		}
		
		$keys->{'pending_form'} = qq|<INPUT TYPE="hidden" NAME="pending" VALUE="$pending">|;
	}
	if ( !$S->have_perm('editorial_comments') && $pending != 0 ) {
		return 'Permission to post Editorial Comments Denied.';
	}
	
	# Filter subject and comment for output
	$subject =~ s/&quot;/"/g;

	$comment = $S->comment_text($comment);
	$subject = $S->comment_text($subject);

	$keys->{'textarea_cols'} = $S->pref('textarea_cols');
	$keys->{'textarea_rows'} = $S->pref('textarea_rows');
	$keys->{'subject'} = $subject;
	$keys->{'comment_body'} = $comment;

	$keys->{'post_opt'} = $S->_postmode_option_form();
	$keys->{'allow_tags'} = $S->html_checker->allowed_html_as_string('comment') unless ($S->{UI}->{VARS}->{hide_comment_allowed_html});

	if ($S->spellcheck_enabled()) {
                # We will only have a formkey if they have already used the submit form.  
		# We only want to set the default spellcheck the first time they submit
		# We don't want to override the setting.
		$spellcheck = $S->pref('spellcheck_default') unless ($S->{CGI}->param('formkey'));
		my $checked = ($spellcheck eq 'on') ? ' CHECKED' : '';
		$keys->{'spellcheck_form'} = $S->{UI}->{BLOCKS}->{spellcheck_form_item};
		$keys->{'spellcheck_form'} =~ s/%%checked%%/$checked/;
	}

	if ($S->{UID} > 0 && $S->{UI}->{VARS}->{allow_sig_behavior} ) {	
		my $sig_opt  = $S->_sig_option_form($user);
		$keys->{'sig_behavior_form'} = qq{Signature Behavior: $sig_opt};
	}

	$form = $S->interpolate($form,$keys);
	return $form;
}

sub set_comment_posttype {
	my $S = shift;
	
	my $posttype = $S->{CGI}->param('posttype') || $S->pref('comment_posttype');
	if ($posttype) {
		$S->session('posttype', $posttype);
	}
	
	return $posttype;
}

sub set_comment_sig_behavior {
	my $S = shift;
	
	my $sig_behavior = $S->{CGI}->param('sig_behavior') || $S->pref('comment_sig_behavior');
	if ($sig_behavior) {
		$S->session('sig_behavior',$sig_behavior);
	}
	
	return $sig_behavior;
}
	
sub _sig_option_form {
	my $S = shift;
	my $user = shift;
	
	my $form;
	
	if ($S->{UID} > 0 && $S->{UI}->{VARS}->{allow_sig_behavior} ) {		#is non-retroactive sig behavior allowed and is user logged in?
		$form = qq|
			<SELECT NAME="sig_behavior" SIZE=1>|;

		my ($sticky_sig, $reg_sig, $no_sig);
		my $sig_behavior = $S->session('sig_behavior') || $S->pref('sig_behavior');
		if ($sig_behavior eq 'sticky') {
			$sticky_sig = ' SELECTED';
		} elsif ($sig_behavior eq 'none') {
			$no_sig = ' SELECTED';
		} else {
			$reg_sig = ' SELECTED';
		}

		if ($user->{prefs}->{sig}) {
			$form .= qq|
				<OPTION VALUE="retroactive"$reg_sig>Retroactive
				<OPTION VALUE="sticky"$sticky_sig>Sticky
				<OPTION VALUE="none"$no_sig>Never Apply Sig|;
		} else {
			$form .= qq|
				<OPTION VALUE="retroactive"$reg_sig>Retroactive
				<OPTION VALUE="none"$no_sig>Never Apply Sig|;
		}
		$form .= qq|
			</SELECT>|;
	} elsif ($S->{UID} > 0 && ! $S->{UI}->{VARS}->{allow_sig_behavior} ){	#user's logged in but sticky sigs/no sigs aren't allowed
		$form .= qq|
			<INPUT TYPE="hidden" NAME="sig_behavior" value="retroactive">|;
	} else {									#user is not logged in so no sig
		$form .= qq|
			<INPUT TYPE="hidden" NAME="sig_behavior" value="none">|;
	}	

	return $form;
}

sub _postmode_option_form {
	my $S = shift;
	
	my $form = qq|
		<SELECT NAME="posttype" SIZE=1>|;
 		
	my ($plainpost, $htmlpost, $autopost);

	my $posttype = $S->session('posttype') || $S->pref('posttype');

	if ($posttype eq 'text') {
		$plainpost = ' SELECTED';
	} elsif ($posttype eq 'html') {
		 $htmlpost = ' SELECTED';
	} elsif ($posttype eq 'auto') {
		 $autopost = ' SELECTED';
	}

	$form .= qq|
		<OPTION VALUE="html"$htmlpost>HTML Formatted
		<OPTION VALUE="text"$plainpost>Plain Text
		<OPTION VALUE="auto"$autopost>Auto Format
		</SELECT>|;
	
	return $form;
}


sub _make_cid {
	my $S = shift;
	my $sid = shift;
	my $quoted_sid = $S->dbh->quote($sid);
	# Make new cid
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'cid',
		FROM => 'comments',
		WHERE => qq|sid = $quoted_sid|,
		ORDER_BY => 'cid desc',
		LIMIT => '1',
		NOCACHE => 1});
	
	my $cid;
	if ($rv eq '0') {
		$cid = 1;
	} else {
		my $last = $sth->fetchrow_hashref;
		$cid = ($last->{cid} + 1);
	}
	$sth->finish;
	
	return $cid;
}


sub pending_select {
	my $S = shift;
	my $pending = shift;
	my $eselected = '';
	my $tselected = '';
	
	if (defined $pending) {
		if ($pending == 0) {
			$tselected = ' SELECTED';
		} elsif ($pending == 1) {
			$eselected = ' SELECTED';
	 	} 
	} else {
		if ($S->{UI}->{VARS}->{editorial_comment_default} == 1) {
			$eselected = ' SELECTED';
	 	}
	}

	my $form = qq|
		<SELECT NAME="pending" SIZE=1>
		<OPTION VALUE="-1">Choose comment
		<OPTION VALUE="1"$eselected>Editorial comment
		<OPTION VALUE="0"$tselected>Topical comment
		</SELECT>|;

	return $form;
}

sub comment_text {
	my $S = shift;
	my $text = shift;

	#$text =~ s/&amp;/&/g;
	$text =~ s/&/&amp;/g;
	$text =~ s/\%\%/&#37;&#37;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/"/&quot;/g;

	return $text;
}

sub filter_comment {
	my $S = shift;
	my $comment = shift;
	my $context = shift;
	my $postmode = shift;
	my $final = shift;
	
        if ($comment =~ /\<ul\>\<ul\>\<ul\>\<ul\>/) {
                return '';
        }

	# And, just to be sure, DEMORONIZE!
	$comment = $S->demoronize($comment);
	
	# Squash those %&^*$$ carat entities
	$comment =~ s/&#139;/</g;
	$comment =~ s/&#155;/>/g;
        $comment =~ s/%0\d+//g;

	# Translate template keys for safety
	$comment =~ s/\%\%/&#37;&#37;/g;

	if ($S->{UI}->{VARS}->{wrap_long_lines}) {
		my $wrap_at = $S->{UI}->{VARS}->{wrap_long_lines_at};
		$S->html_checker->add_text_callback(sub {
			my $text = shift;
			$text =~ s/(\S{$wrap_at})/$1\n/g;
			return $text;
		});
	}

	if ($postmode eq 'text') {
		return $S->plaintext_format($comment); # Moved to Utility.pm
		}

	if ($postmode eq 'auto') {
		return $S->auto_format($comment, $context);
	}

	# if it's not a
	$comment =~ s/&(?![A-Za-z0-9#]+;)/&amp;/g;

	# strip out disallowed html
	my $comment_ref = $S->html_checker->clean_html(\$comment, $context);
	$comment = $$comment_ref;

	if ($S->{UI}->{VARS}->{wrap_pre} && ($comment =~ /<pre>/)) {
		local $Text::Wrap::columns = $S->{UI}->{VARS}->{wrap_pre_at};
		$comment =~ s/<pre>(.+?)<\/pre>/_wrap_pre_text($1)/egs;
	}

	return $comment;
}

sub _wrap_pre_text {
	my $text = shift;
	return '<pre>' . Text::Wrap::wrap('', '', $text) . '</pre>';
}

sub filter_subject {
	my $S = shift;
	my $subject = shift;
	
	# And, just to be sure, DEMORONIZE!
	$subject = $S->demoronize($subject);

	# Squash those %&^*$$ carat entities
	$subject =~ s/&#139;/</g;
	$subject =~ s/&#155;/>/g;

	#$subject =~ s/&amp;/&/g;
	$subject =~ s/&quot;/"/g;

	# Translate &'s first, so we don't translate what we do later
	$subject =~ s/&/&amp;/g;

	# Translate template keys for safety
	$subject =~ s/\%\%/&#37;&#37;/g;
       
	# My monument to stupidity.	
	#$subject =~ s/<.*?>//g;
	$subject =~ s/</&lt;/g;
	$subject =~ s/>/&gt;/g;
	$subject =~ s/"/&quot;/g;

	return $subject;
}

sub demoronize {
	my $S = shift;
	my $str = shift;

	# NOTE: this is cut 'n' paste from demoronizer.pl
	# by John Walker -- January 1998
	#	http://www.fourmilab.ch/
	#
	# Thanks John!
	#
    #   Map strategically incompatible non-ISO characters in the
    #   range 0x82 -- 0x9F into plausible substitutes where
    #   possible.
	
    $str =~ s/\x82/,/g;
    $str =~ s-\x83-<em>f</em>-g;
    $str =~ s/\x84/,,/g;
    $str =~ s/\x85/.../g;

    $str =~ s/\x88/^/g;
    $str =~ s-\x89- °/°°-g;

    $str =~ s/\x8B/</g;
    $str =~ s/\x8C/Oe/g;

    $str =~ s/\x91/`/g;
    $str =~ s/\x92/'/g;
    $str =~ s/\x93/"/g;
    $str =~ s/\x94/"/g;
    $str =~ s/\x95/*/g;
    $str =~ s/\x96/-/g;
    $str =~ s/\x97/--/g;
    $str =~ s-\x98-<sup>~</sup>-g;
    $str =~ s-\x99-<sup>TM</sup>-g;

    $str =~ s/\x9B/>/g;
    $str =~ s/\x9C/oe/g;
	
	return $str;
}

sub post_comment {
	my $S = shift;
	my $sid = $S->{CGI}->param('sid');
	my $pid = $S->{CGI}->param('cid') || 0;
	my $subject = $S->{CGI}->param('subject');
	my $comment = $S->{CGI}->param('comment');
	my $uid = $S->{CGI}->param('uid') || $S->{UID};
	my $posttype = $S->{CGI}->param('posttype');
	my $pending = $S->{CGI}->param('pending');
	my $sig_behavior = $S->{CGI}->param('sig_behavior');# || 'retroactive';
	my $sig_status;
	## This is for tracking comments by IP
	my $commentip;
	if ($S->{UI}->{VARS}->{comment_ip_log}) {
		$commentip = $S->{REMOTE_IP};
	}
	## That's the end of that for a moment

	return 0 unless $S->anon_comment_warn($subject);
	
	return 0 unless !$S->_check_archivestatus($sid);

	# if pending isn't 0, get it from the parent, if no parent, check story displaystatus
	my ($rv2,$sth2);
	my $f_pid = $S->{DBH}->quote($pid);
	my $f_sid = $S->{DBH}->quote($sid);

	# Does the alleged parent even exist?
	if( $pid && $pid ne '') {
		($rv2,$sth2) = $S->db_select({
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT	=> 'cid',
			FROM	=> 'comments',
			WHERE	=> qq|sid=$f_sid AND cid=$f_pid|,
		});
		my $test = $sth2->fetchrow();
		$sth2->finish();
		return 0 unless $test;
	}
	
	if( $pid && $pid ne '' && $pending == 1 ) {
		
		($rv2,$sth2) = $S->db_select({
			ARCHIVE => $S->_check_archivestatus($sid),
			WHAT	=> 'pending',
			FROM	=> 'comments',
			WHERE	=> qq|sid=$f_sid AND cid=$f_pid|,
		});

		if( $rv2 ) {
			$pending = $sth2->fetchrow();
			$sth2->finish();
		} 

	} elsif( $pending == 1 ) {

		($rv2,$sth2) = $S->db_select({
			WHAT	=> 'displaystatus',
			FROM	=> 'stories',
			WHERE	=> qq| sid=$f_sid |,
		});

		if( $rv2 ) {
			my $s = $sth2->fetchrow_hashref;
			$pending = ($s->{displaystatus} <= -2) ? 1 : 0;
		}

	} else {
		$pending = 0;
	}

	
	# If we got a uid, make sure it matches our own,
	# or that it's '-1' and anon posting is allowed
	if ($uid) {
		return 0 unless (($uid == $S->{UID}) || ($uid == '-1' && $S->have_perm('comment_post', 'Anonymous')));
	}
	
	my $user = $S->user_data($uid);

	my $sig = $user->{prefs}->{sig};

	# taken out the part where appending to the comment, it should be attached
	# separately, so that sigs are not posted as text, and not included in 
	# searches
	if ($sig_behavior eq 'sticky' ) {
	#	if ($sig && $sig_behavior eq 'sticky') {
	#			$comment .= "<br>$sig<br>";
	#	}
		$sig_status = 0; 
	} elsif( $sig_behavior eq 'none' ) {
		$sig_status = -1;
	} else {
		$sig_status = 1;
	}

	$comment = $S->filter_comment($comment, 'comment', $posttype, 1);
	return if $S->html_checker->errors_as_string;
	$sig = $S->filter_comment($sig, 'prefs', 'html', 1);

	# if using macros, and 'render on save' is on, then render the macro(s) before saving.

	if (exists($S->{UI}->{VARS}->{use_macros}) && $S->{UI}->{VARS}->{use_macros} && defined($S->{UI}->{VARS}->{macro_render_on_save}) && $S->{UI}->{VARS}->{macro_render_on_save}) {
		$comment = $S->process_macros($comment,'comment');
		$sig = $S->process_macros($sig,'pref');
	}

	$comment = $S->{DBH}->quote($comment);
	$sig = $S->{DBH}->quote($sig);
	$subject = $S->filter_subject($subject);
	# check the length of the filtered subject to make sure it won't be cut
	# off by the db
	return 0 if length($subject) > 50;
	$subject = $S->{DBH}->quote($subject);
	$commentip = $S->{DBH}->quote($commentip);

	my $points = undef;
	my $set_rating = 0;
	my $cols = 'sid, pid, date, subject, comment, uid, pending, sig_status, sig, commentip';
	my $vals = qq|"$sid", $pid, NOW(), $subject, $comment, $uid, $pending, $sig_status, $sig, $commentip|;
	if ($S->{UI}->{VARS}->{use_initial_rating}) {
		$points = ($uid == -1) ? $S->{UI}->{VARS}->{anonymous_default_points} : $S->{UI}->{VARS}->{user_default_points};
		$set_rating = 1 ? ($S->{UI}->{VARS}->{real_initial_rating}) : 0;
	}
		
	if ($S->{UI}->{VARS}->{use_mojo}) {
		if ((defined($user->{mojo})) &&
			($user->{mojo} < $S->{UI}->{VARS}->{rating_min}) &&
			($S->{TRUSTLEV} == 0) &&
			(!$S->have_perm('super_mojo'))) {
			$points = $user->{mojo};
			$set_rating = 1;
		}
	}
	
	if ($points) {
		$cols .= ', points';
		$vals .= qq|, '$points'|;
	}
	
	my $cid = $S->_make_cid($sid);

	$cols .= ', cid';
	$vals .= qq|, $cid|;
		
	my ($rv, $sth) = $S->db_insert({
		DEBUG => 0,
		ARCHIVE => $S->_check_archivestatus($sid),
		INTO => 'comments',
		COLS => $cols,
		VALUES => $vals});
	
	$sth->finish;
	if ($set_rating) {
		$S->_write_one_rating($sid, $cid, $points, 1);
	}

	$S->run_hook('comment_new', $sid, $cid);
	
	if ($rv) {
		# Drop the commentcount cache value for this article
		$S->_count_cache_drop($sid);
		# Mark the story modified in the cache
		my $time = time();
		my $r = $sid.'_mod';
		$S->cache->stamp_cache($r, $time);
		return $cid;
	}
	return 0;
}


1;
