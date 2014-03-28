package Scoop;
use strict;

my $DEBUG = 0;

sub frontpage_view {
	my $S = shift;
	my $story_type = shift;
	my $user    = $S->cgi->param('user');
	my $topic   = $S->cgi->param('topic');
	my $params;	# The important stuff args are stored here
	# Added to allow the use of this to create specialty index
	# pages based on factors like posting time, or whatever
	$params->{where} = shift;
	$params->{from} =shift;
	
	my $spage   = $S->cgi->param('page') || 1;
	my $op      = $S->cgi->param('op');
	my $section = $S->cgi->param('section');
	my $disp    = $S->cgi->param('displaystatus');
	my $tag     = $S->cgi->param('tag');

	$params->{topic} = $topic if $topic;
	$params->{user} = $user if $user;
	$params->{page} = $spage if $spage;
	if ( $story_type eq 'main' ) {
		$params->{displaystatus} = $disp || '0';
	} elsif ( $story_type eq 'section' ) {
		$params->{displaystatus} = $disp || [0,1];
		$params->{section} = $section;
	} elsif ($story_type eq 'tag' ) {
		$params->{displaystatus} = $disp || [0,1];
		$params->{tag} = $tag;
	}
	
	# if they don't have permission to view this section, let them know
	if( $section && $section ne ''		&&
		$section ne '__all__'			&&
		!$S->have_section_perm( 'norm_read_stories', $section ) ) {

		if( $S->have_section_perm( 'deny_read_stories', $section ) ) {
			return qq|<b>%%norm_font%%Sorry, you don't have permission to read stories posted to section '$section'.%%norm_font_end%%</b>|;
		} else {
			return qq|<b>%%norm_font%%Sorry, I can't seem to find section '$section'.%%norm_font_end%%</b>|;
		}

	}

	if ($user) {
		my $uid = $S->get_uid_from_nick($user);
		return qq|<b>%%norm_font%%Sorry, I can't seem to find that user.%%norm_font_end%%</b>| unless ($uid);
	}

	my $sids = $S->get_sids($params);
	my $stories = $S->story_data($sids);

	my $page;
	foreach my $story (@{$stories}) {
		$page .= $S->story_summary($story);
		my ($more, $stats, $section) = $S->story_links($story);
		$page =~ s/%%readmore%%/$more/g;
		$page =~ s/%%stats%%/$stats/g;
		$page =~ s/%%section_link%%/$section/g;
	}

	# now make the links for next/previous pages, and put them on
	my ($np, $pp) = ($spage + 1, $spage - 1);
	my $pre_link  = ($op eq 'section') ? "section/$section" : "$op";

	if ($section eq 'Diary' && $user) {
		$pre_link = "user/$user/diary";
	} elsif ($op eq 'tag') {
		$pre_link = "tag/$tag";
	}
	
	my $change_page = $S->{UI}->{BLOCKS}->{next_previous_links};
	my ($prev_page, $next_page);
	if ($pp >= 1) {
		$prev_page = $S->{UI}->{BLOCKS}->{prev_page_link};
		$prev_page =~ s/%%LINK%%/%%rootdir%%\/$pre_link\/$pp/g;
	}
	if (@{$stories} && @{$stories} == $S->pref('maxstories')) {
		$next_page = $S->{UI}->{BLOCKS}->{next_page_link};
		$next_page =~ s/%%LINK%%/%%rootdir%%\/$pre_link\/$np/g;
	}
	$change_page =~ s/%%PREVIOUS_LINK%%/$prev_page/g;
	$change_page =~ s/%%NEXT_LINK%%/$next_page/g;

	#$page  = $change_page . $page if $pp >= 1;
	$page .= $change_page;

	return $page;
}

sub story_links {
	my $S = shift;
	my $story = shift;
	
	my $edit = '';
	if ($S->have_perm('story_list') || ($S->have_perm('edit_my_stories') && $story->{aid} == $S->{UID})) {
		$edit = qq|[<A CLASS="light" HREF="%%rootdir%%/admin/story/$story->{sid}">edit</A>]|;
	} 

	# This is so that if there is no body to the article, it just shows
	# "Comments >>" (or whatever no_body_txt is), instead of Read More
	my $text = ($story->{bodytext} ne '')? '%%readmore_txt%%' : '%%no_body_txt%%';
	# just in case you don't have no_body_txt set
	$text = ($text eq '') ? 'Comments >>' : $text;	

	my $more .= qq|<A CLASS="light" HREF="%%rootdir%%/story/$story->{sid}">$text</A> | unless
		(($S->have_section_perm(hide_read_comments => $story->{section})) &&
		($S->have_section_perm(hide_post_comments => $story->{section})) &&
		($story->{bodytext} eq ''));
			
	# either count words or bytes in the story
	# if you count bytes, it costs you an extra SELECT statement
	# to the database
	# if you count words, it costs you an extra call to 
	# split

	my $bits;
	my @tmp_array;
	if( $S->{UI}->{VARS}->{story_count_words} == 1 )
	{
		# used to split to @_, but that gave a 'deprecated' message on startup, thus tmp_array
		@tmp_array = split /\s/, $story->{bodytext}.$story->{introtext};
		$bits = @tmp_array;
		$bits .= ($bits == 1) ? " word" : " words";
	} else {
		$bits = $S->count_bits($story->{sid});

	}

	my @readmore = ();
	my $comment_word = $S->{UI}->{BLOCKS}->{comment_word} || 'comment';
	my $comment_plural = $S->{UI}->{BLOCKS}->{comment_plural} || 's';
	push @readmore, sprintf( "$S->{UI}->{BLOCKS}->{comment_num_format_start}%d$S->{UI}->{BLOCKS}->{comment_num_format_end} %s%s",
				 $story->{comments},
				 $comment_word,
				 $story->{comments} != 1 ? $comment_plural : ''
				 ) if( $story->{comments} && $S->have_section_perm('norm_read_comments',$story->{section}) );

	my $show = $S->{UI}->{VARS}->{show_new_comments};
	if ($show eq "all" && !$S->have_section_perm('hide_read_comments',$story->{section}) ) {
		my $new_comment_format_start = $S->{UI}->{BLOCKS}->{new_comment_format_start} || '<b>';
		my $new_comment_format_end = $S->{UI}->{BLOCKS}->{new_comment_format_end} || '</b>';
		my $num_new = $S->new_comments_since_last_seen($story->{sid});
		push @readmore, "$new_comment_format_start$num_new$new_comment_format_end new" if $num_new;
	}

	push @readmore, "$bits in story" if ($bits and $story->{bodytext});
	
	my $section = $S->get_section($story->{section});
	my $sec_url = qq|%%rootdir%%/section/$story->{section}|;
	
	my $section_link = qq(<A CLASS="section_link" href="$sec_url">$section->{title}</a>);
		
	my $stats = sprintf( '(%s)', join ', ', @readmore );

	# get rid of empty parenthasis if 0 comments and 0 bytes in body
	if( $stats eq '()' ) {
		$stats = '';
	}

	$more .= qq| $edit |;
	
	return ($more, $stats, $section_link);
}


sub focus_view {
	my $S = shift;

	my $mode = $S->{CGI}->param('mode');
	my $sid = $S->{CGI}->param('sid');
	
	my $comments;
	
	#$S->{UI}->{BLOCKS}->{STORY} = qq|
	#	<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 width="100%">|;
	#$S->{UI}->{BLOCKS}->{COMMENTS} = qq|
	#	<TABLE CELLPADDING=0 CELLSPACING=0 BORDER=0 width="100%">|;

	# Filter this through get_sids for perms
	my $sids = $S->get_sids({'sid' => $sid});
	$sid = $sids->[0];

	my ($story_data, $story) = $S->displaystory($sid);

	my $checkstory = $S->_check_for_story($sid);

	my $commentstatus = $S->_check_commentstatus($sid);
	
	# Run a hook here to do any processing we need to do on a story
	# before we display it.
	$S->run_hook('story_view', $sid, $story_data);

	unless ($checkstory && $story_data && $story) {
		$S->{UI}->{BLOCKS}->{STORY} .= qq|
			<table cellpadding="0" cellspacing="0" border="0" width="100%">
				<tr><td>%%norm_font%%<b>Sorry. I can\'t seem to find that story.</b>%%norm_font_end%%</td></tr>
			</table>|;
			
		return;
	}
	
	
	$S->{UI}->{BLOCKS}->{STORY} .= $story;
	if ($story_data->{displaystatus} == -2) {
		$mode = 'moderate';
	}	
	
	if ($story_data->{displaystatus} <= -2) { 
		if (!$S->have_perm('moderate')) {
			$S->{UI}->{BLOCKS}->{STORY} = qq|
			<table width="100%" border="0" cellpadding="0" cellspacing="0">
			<tr bgcolor="%%title_bgcolor%%">
				<td>%%title_font%%Permission Denied.%%title_font_end%%</td>
			</tr>
			<tr><tr>%%norm_font%%Sorry, but you can only moderate stories if you have a valid user account. 
			Luckily for you, making one is easy! Just <a HREF="%%rootdir%%/newuser">go here</a> to get started.
			%%norm_font_end%%</td></tr>
			</table>|;
			return;
		}
		
		my $message = $S->_story_mod_write($sid);
		if ($message) {
			$S->{UI}->{BLOCKS}->{STORY} .= qq|<table width="100%" border=0 cellpadding=0 cellspacing=0><tr><td>%%norm_font%%$message %%norm_font_end%%</td></tr></table>|;
			$S->{UI}->{BLOCKS}->{STORY} .= '<P>';
		}
		my ($which, $mod_stuff) = $S->story_mod_display($sid);
		my $author_control = $S->author_control_display($story_data);
		warn "Author block is:\n$author_control\n" if $DEBUG;

		$S->{UI}->{BLOCKS}->{STORY} .= $author_control;
		
		if ($which eq 'content') {
			$S->{UI}->{BLOCKS}->{STORY} .= $mod_stuff if ($story_data->{aid} ne $S->{UID});
		} else {
			$S->{UI}->{BLOCKS}->{BOXES} .= $mod_stuff;
		}
	}
	
	$comments = $S->display_comments($sid, '0') unless $commentstatus == -1;

	$S->update_seen_if_needed($sid);# unless ($S->{UI}->{VARS}->{use_static_pages});
	
	$S->{UI}->{BLOCKS}->{STORY} .= $S->story_nav($sid);
	#$S->{UI}->{BLOCKS}->{STORY} .= '<TR><TD>&nbsp;</TD></TR>';

	$S->{UI}->{BLOCKS}->{COMMENTS} .= $S->comment_controls($sid, 'top');
	$S->{UI}->{BLOCKS}->{COMMENTS} .= qq|$comments|;

	if ($comments) {
		$S->{UI}->{BLOCKS}->{COMMENTS} .= $S->comment_controls($sid, 'top');
	}
	
	#$S->{UI}->{BLOCKS}->{STORY} .= '</TABLE>';
	#$S->{UI}->{BLOCKS}->{COMMENTS} .= '</TABLE>';

	$S->{UI}->{BLOCKS}->{subtitle} .= $story_data->{title} || $S->{UI}->{BLOCKS}->{slogan};
	$S->{UI}->{BLOCKS}->{subtitle} =~ s/</&lt;/g;
	$S->{UI}->{BLOCKS}->{subtitle} =~ s/>/&gt;/g;

	return;
}

# DEPRECATED
# SHOULD PROBABLY REMOVE.
sub olderlist {
	my $S = shift;
	
	my $page = $S->{CGI}->param('page') || 1;
	
	my $next_page = $page + 1;
	my $last_page = $page - 1;
	my $num = $S->{UI}->{VARS}->{storylist};
	my $limit;
	my $get_num = $num + 1;
	my $displayed = $S->pref('maxstories') + $S->pref('maxtitles');
	my $offset = ($num * ($page - 1)) + $displayed;
	my $date_format;
	my $op = $S->{CGI}->param('op');
	
	if(lc($S->{CONFIG}->{DBType}) eq "mysql") {
		$date_format = 'DATE_FORMAT(time, "%a %b %D, %Y at %r")';
	} else {
		$date_format = "TO_CHAR(time, 'Dy Mon DD, YYYY at HH12:MI:SS PM')";
	}
	$limit = "$offset, $get_num";
	
	my ($rv, $sth) = $S->db_select({
		WHAT => qq|sid, aid, users.nickname AS nick, tid, $date_format AS ftime, title|,
		FROM => 'stories LEFT JOIN users ON stories.aid = users.uid',
		WHERE => 'displaystatus >= 0',
		ORDER_BY => 'time DESC',
		LIMIT => $get_num,
		OFFSET => $offset
	});
	
	my $list;
	my $i = $offset + 1;
	my $stop = $offset + $num;
	
	while ((my $story = $sth->fetchrow_hashref) && ($i <= $stop)) {
		warn "In olderlist, getting count for $story->{sid}\n" if $DEBUG;
		$story->{commentcount} = $S->_commentcount($story->{sid});
		$story->{nick} = $S->{UI}->{VARS}->{anon_user_nick} if $story->{aid} == -1;
		$list .= qq|
		<P>
		<B>$i) <A CLASS="light" HREF="%%rootdir%%/story/$story->{sid}">$story->{title}</A></B> by $story->{nick}, $story->{commentcount} comments<BR>
		posted on $story->{ftime}|;
		$i++;
	}
	$sth->finish;
	
	my $content = qq|
		<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=100%>
		<TR>
		<TD COLSPAN=2 BGCOLOR="%%title_bgcolor%%">%%title_font%%<B>Older Stories</B>%%title_font_end%%</TD>
		</TR>
		<TR><TD COLSPAN=2>&nbsp;</TD></TR>
		<TR><TD COLSPAN=2>%%norm_font%%
		$list
		%%norm_font_end%%</TD></TR>|;
	
	$content .= qq|
		<TR><TD COLSPAN=2>&nbsp;</TD></TR>
		<TR>
			<TD>%%norm_font%%<B>|;
	if ($last_page >= 1) {
		$content .= qq|&lt; <A CLASS="light" HREF="%%rootdir%%/?op=$op;page=$last_page">Last $num</A>|;
	} else {
		$content .= '&nbsp;';
	}
	$content .= qq|</B>%%norm_font_end%%</TD>
		<TD ALIGN="right" COLSPAN=2>%%norm_font%%<B>|;
	
	if ($rv >= ($num + 1)) {
		$content .= qq|
		<A CLASS="light" HREF="%%rootdir%%/?op=$op;page=$next_page">Next $num</A> &gt;%%norm_font_end%%|;
	} else {
		$content .= '&nbsp;';
	}
	
	$content .= qq|</B>%%norm_font_end%%</TD>
	</TR>
	</TABLE>|;
	
	$S->{UI}->{BLOCKS}->{CONTENT} = $content;
	return;
}
		
	
1;
