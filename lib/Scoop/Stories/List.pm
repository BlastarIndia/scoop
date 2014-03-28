=head1 List.pm

This is a collection of subs that were formerly located it lib/Scoop/Admin/AdminStories.pm and control the story list available to editors, and the moderation queue.

=head1 Functions

=cut


package Scoop;
use strict;
my $DEBUG = 0;


=pod

=over 4

=item *
list_stories($mode)

This generates both story lists.  The one by moderating submissions (when $mode eq 'mod')
and the one for Admins only (op=admin;tool=storylist) when given no arguments.  ($mode 
defaults to 'full', which displays the editors version of the storylist).

=back

=cut

sub list_archive {
	my $S = shift;
	$S->list_stories ('archive');
}

sub list_stories {
	my $S = shift;
	my $mode = shift || 'full';	
	my $op = $S->{CGI}->param('op');
	my $tool = $S->{CGI}->param('tool');
	my $page = $S->{CGI}->param('page') || 1;
	my $next_page = $page + 1;
	my $last_page = $page - 1;
	my $num = $S->{UI}->{VARS}->{storylist};
	my $offset = ($num * ($page - 1));
	my $get_num = $num +1;	
	my $limit;
	if ($page > 1) {
		$limit = "$offset, $get_num";
	} else {
		$limit = "$get_num";
	}
	
	my $title;
	if ($mode eq 'full') {
		$title = $S->{UI}->{BLOCKS}->{story_list_title};
	} else {
		if ($mode eq 'archive') {
			$title = $S->{UI}->{BLOCKS}->{archive_list_title};
		} else {
			$title = $S->{UI}->{BLOCKS}->{pending_list_title};
		}
	}
	
	#begin table
	my $content = qq|
		<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=100%>
		<TR>
		<TD COLSPAN=4 BGCOLOR="%%title_bgcolor%%">%%title_font%%<B>$title</B>%%title_font_end%%</TD>
		</TR>|;

	# output appropriate story list
	my ($rv, $story_list);
	
	if ( $mode eq 'full' ) {
		($rv, $story_list) = $S->_list_storylist($limit, $num, 0);
	} elsif ( $mode eq 'archive' ) {	
		($rv, $story_list) = $S->_list_storylist($limit, $num, 1);
	} else {
		if ( $S->{UI}->{VARS}->{use_edit_categories} ) {
			($rv, $story_list) = $S->_list_categorylist($limit, $num);
		} else {
			($rv, $story_list) = $S->_list_modsub($limit, $num);
		}
	}

	#finish table
	$content .= qq|
		$story_list
		<TR><TD COLSPAN=4>&nbsp;</TD></TR>
		<TR>
			<TD COLSPAN=2>%%norm_font%%<B>|;
	
	if ($last_page >= 1) {	$content .= qq|&lt; <A HREF="%%rootdir%%/?op=$op;tool=$tool;page=$last_page">Last $num</A>|; }
	
	$content .= qq|&nbsp;</B>%%norm_font_end%%</TD>
		<TD ALIGN="right" COLSPAN=2>%%norm_font%%<B>|;
	
	if ($rv >= ($num + 1)) {$content .= qq|<A HREF="%%rootdir%%/?op=$op;tool=$tool;page=$next_page">Next $num</A> &gt;%%norm_font_end%%|; }
	
	$content .= qq|&nbsp;</B>%%norm_font_end%%</TD>
		</TR></TABLE>|;
}

sub _list_storylist {
	my $S = shift;
	my $limit = shift;
	my $get_num = shift;
	my $archive = shift;

	my ($content, $select, $last_col);
	my $dateformat = $S->date_format( 'time', 'short' );

	my $excl_sect_sql = ( $S->get_disallowed_sect_sql('norm_read_stories') || '1=1');

	$select = {
		WHAT		=> "sid, aid, u.nickname AS nick, $dateformat as ftime, title, displaystatus, tid, section",
		ARCHIVE		=> $archive,
		FROM		=> "stories s LEFT JOIN users u ON s.aid = u.uid",
		WHERE		=> $excl_sect_sql,
		LIMIT		=> "$limit",
		ORDER_BY	=> 'time DESC'};

	$content = qq|
		<TR>
			<TD COLSPAN=4>&nbsp;</TD>
		</TR>
		<TR>
			<TD COLSPAN=4>&nbsp;</TD>
		</TR>
		<TR BGCOLOR="%%title_bgcolor%%">
			<TD valign="top">%%title_font%%<B>Title (Comments)</B>%%title_font_end%%</TD>
			<TD valign="top">%%title_font%%<B>Date</B>%%title_font_end%%</TD>
			<TD valign="top">%%title_font%%<B>Author</B>%%title_font_end%%</TD>
			<TD align="center" valign="top">%%title_font%%$last_col%%title_font_end%%</TD>
		</TR>|;

	my ($rv, $sth) = $S->db_select($select);
	return ($rv, $content) if ($rv eq '0E0');

	my ($tid, $section);
	my $color;
	my $i = 1;
	my $story;
	my $story_num;
	my $archive_link;
	my ($displaystatus, $edit_link, $comment_count, $mod_set, $story_link, $info, $story_read_link);
	$story = $sth->fetchrow_hashref;

	while ($i <= $get_num && $story) {

		$story->{commentcount} = $S->_commentcount($story->{sid});
		$comment_count = qq{($story->{commentcount}) };
		$displaystatus = $story->{displaystatus};
		$edit_link = qq| [<A HREF="%%rootdir%%/?op=admin;tool=story;sid=$story->{sid};delete=Delete">delete</A>]|;
		$archive_link = qq| [<A HREF="%%rootdir%%/?op=admin;tool=story;sid=$story->{sid};archive=Archive">archive</A>]| if $S->{HAVE_ARCHIVE} && !$archive;
		$story_link = "admin/story/$story->{sid}";
		$story_read_link = qq|, $story->{commentcount} comments [<A HREF="%%rootdir%%/displaystory/$story->{sid}">Read</A>]|;

		
		$info = "Section: $S->{SECTION_DATA}->{$story->{section}}->{title}, Topic: $S->{TOPIC_DATA}->{$story->{tid}}->{alttext}";

		if ($displaystatus == -1) {
			$color = " BGCOLOR=\"%%undisplayedstory_bg%%\"";
		} elsif ($displaystatus == 1) {
			$color = " BGCOLOR=\"%%sectiononlystory_bg%%\"";
		} elsif ($displaystatus == -2) {
			$color = " BGCOLOR=\"%%submittedstory_bg%%\"";
		} elsif ($displaystatus == -3) {
			$color = " BGCOLOR=\"%%editqueuestory_bg%%\"";
		} else {
			$color = '';
		}
		
		$story_num = ((($S->{CGI}->param('page') || 1)-1) * $get_num) + $i;
		$story->{nick} = $S->{UI}->{VARS}->{anon_user_nick} if $story->{aid} == -1;

		$content .= qq|
		<TR$color>
			<TD valign="top">%%norm_font%%$story_num) <A HREF="%%rootdir%%/$story_link">$story->{title}</A>$story_read_link<BR>$info%%norm_font_end%%</TD>
			<TD valign="top">%%norm_font%%$story->{ftime}%%norm_font_end%%</TD>
			<TD valign="top">%%norm_font%%$story->{nick}%%norm_font_end%%</TD>
			<TD align="center" valign="top">%%norm_font%%$edit_link<br>$archive_link%%norm_font_end%%</TD>
		</TR>|;
		$i = $i+1;
		$story = $sth->fetchrow_hashref;
	}

	$sth->finish;

	return ($rv, $content);
}

sub _list_categorylist {
	my $S = shift;
	my $limit = shift;
	my $get_num = shift;
	
	my ($content, $select);
	my $dateformat = $S->date_format( 'time', 'short' );

	my $excl_sect_sql = ( $S->get_disallowed_sect_sql('norm_read_stories') || '1=1');
	
	$select = {
		WHAT		=> "sid, aid, u.nickname AS nick, $dateformat as ftime, title, displaystatus, tid, section, edit_category, e.name as edit_category_name, e.orderby",
		FROM		=> 'stories s LEFT JOIN editcategorycodes e ON (e.code=s.edit_category) LEFT JOIN users u ON s.aid = u.uid',
		WHERE		=> "$excl_sect_sql AND displaystatus IN (-2, -3)",
		LIMIT		=> "$limit",
		ORDER_BY	=> 'e.orderby ASC, edit_category ASC, s.time DESC'};
	
	$content = qq|
		<TR>
			<TD COLSPAN=4>&nbsp;</TD>
		</TR>
		<TR BGCOLOR="%%title_bgcolor%%">
			<TD colspan="2" valign="top">%%title_font%%<B>Story Information</B>%%title_font_end%%</TD>
			<TD align="center" valign="top">%%title_font%%<B>Comments</B>%%title_font_end%%</TD>
			<TD align="center" valign="top">%%title_font%%<B>Date</B>%%title_font_end%%</TD>
		</TR>
		|;
	
	my ($tid, $section, $color, $i, $story, $story_num, $last_edit_category, $displaystatus, $edit_link, $comment_count, $new_comments, $mod_set, $story_link, $info, $read_link);
	
	my ($rv, $sth) = $S->db_select($select);
	$story = $sth->fetchrow_hashref;

	$i = 1;
	$last_edit_category = -1;

	while ($i <= $get_num && $story) {
		$comment_count=$S->_commentcount($story->{sid});
		$new_comments= $S->new_comments_since_last_seen($story->{sid});
		if ( $new_comments==0 ) {
			$new_comments='';
		} else {
			$new_comments='[' . $new_comments . ' new]';
		}
		if ( $last_edit_category ne $story->{edit_category} ) {
			$content .= qq|<TR><TD COLSPAN=4>&nbsp;</TD></TR>
				<TR><TD COLSPAN=4>%%title_font%%<B>$story->{edit_category_name}</B>%%title_font_end%%</TD></TR>|;
		}

 		$story_num = ((($S->{CGI}->param('page') || 1)-1) * $get_num) + $i;
		$edit_link = qq{<A HREF="%%rootdir%%/admin/story/$story->{sid}">Edit</A>};
		$read_link = qq{<a href="%%rootdir%%/displaystory/$story->{sid}">Read</a>};
		$story_link = qq|$story_num) <a href="%%rootdir%%/displaystory/$story->{sid}">$story->{title}</a>|;
	
		$info = "Section: $S->{SECTION_DATA}->{$story->{section}}->{title}, Topic: $S->{TOPIC_DATA}->{$story->{tid}}->{alttext}";
		
		if ( $S->_get_user_voted($S->{UID}, $story->{sid}) ) {
			$color = '';	
		} else {
			$color = ' BGCOLOR="%%undisplayedstory_bg%%"'; 
		}

		$story->{nick} = $S->{UI}->{VARS}->{anon_user_nick} if $story->{aid} == -1;

		$content .= qq|
			<TR$color>
				<TD valign="top" colspan="2">%%norm_font%%$story_link <i>by $story->{nick}</i>
					<BR>&nbsp;&nbsp;&nbsp;&nbsp;$info %%norm_font_end%%</TD>
				<TD valign="top" align="center">%%norm_font%%($comment_count comments)<BR>
						$new_comments%%norm_font_end%%</TD>
				<TD valign="top" align="right">%%norm_font%%$story->{ftime}<BR>
						$read_link  \|   $edit_link %%norm_font_end%%</TD>
			</TR>|;
		$i = $i+1;
		$last_edit_category=$story->{edit_category};
		$story = $sth->fetchrow_hashref;
	}

	$sth->finish;
	
	return ($rv, $content);
}
	
sub _list_modsub {
	my $S = shift;
	my $limit; #= shift;
	my $get_num = 10000000; #shift;
	
	my ($content, $select, $vote_queue, $edit_queue);
	my $dateformat = $S->date_format( 'time', 'short' );
	my $hidescore = $S->{UI}->{VARS}->{hide_story_threshold};

	my $excl_sect_sql = ( $S->get_disallowed_sect_sql('norm_read_stories') || '1=1');


	$select = {
		WHAT => "stories.sid, aid, users.nickname AS nick, tid, $dateformat as ftime, title, stories.score AS score, section, count(comments.cid) as comments",
		FROM => 'stories LEFT JOIN users ON stories.aid = users.uid LEFT JOIN comments on stories.sid = comments.sid',
		WHERE => "((displaystatus = -2 AND stories.score > $hidescore) OR displaystatus = -3) AND $excl_sect_sql",
		LIMIT => "$limit",
		GROUP_BY => 'stories.sid',
		ORDER_BY => 'time DESC'};
	
	if ( $S->{UI}->{VARS}->{show_threshold} ) { $content .= $S->_show_threshold_text; }

	my $topic = '';
	$topic = ' (topic)' if $S->var('use_topics');

	$vote_queue = qq|
		<TR><TD COLSPAN=4>&nbsp;</TD></TR>
		<TR><TD COLSPAN=4>%%title_font%%<B>Stories currently in voting:</b>%%title_font_end%%</TD></TR>
		<TR BGCOLOR="%%title_bgcolor%%">
		<TD valign="top">%%title_font%%<B>Title$topic</B>%%title_font_end%%</TD>
		<TD valign="top">%%title_font%%<B>Date</B>%%title_font_end%%</TD>
		<TD align="center" valign="top">%%title_font%%<B>Author</B>%%title_font_end%%</TD>
		<TD align="center" valign="top">%%title_font%%<B>Score</B>%%title_font_end%%</TD>
		</TR>|;

	$edit_queue = qq|
                <TR><TD COLSPAN=4>&nbsp;</TD></TR>
                <TR><TD COLSPAN=4>%%title_font%%<B>Stories currently in editing:</b>%%title_font_end%%</TD></TR>
                <TR BGCOLOR="%%title_bgcolor%%">
                <TD valign="top">%%title_font%%<B>Title$topic</B>%%title_font_end%%</TD>
                <TD valign="top">%%title_font%%<B>Date</B>%%title_font_end%%</TD>
                <TD align="center" valign="top">%%title_font%%<B>Author</B>%%title_font_end%%</TD>
                <TD valign="top">%%title_font<B>Score</B>title_font_end%%</TD>
                </TR>|;

	my ($tid, $section, $color, $story, $story_num, $displaystatus, $edit_link, $comment_count, $mod_set, $story_link, $info, $story_read_link, $i);
	
	my ($rv, $sth) = $S->db_select($select);
	$story = $sth->fetchrow_hashref;
	$i = 1;
	my $vote_i = 1;
	my $edit_i = 1;
        warn "Building modsub list\n";
	while ($story && ($i <= $get_num) ) {
		
		$story_link = "story/$story->{sid}";
		my ($disp_mode, $stuff) = $S->_mod_or_show($story->{sid});

		if ($disp_mode eq 'moderate') {
			$displaystatus = 1;
			$edit_link = qq|<A HREF="%%rootdir%%/displaystory/$story->{sid}">vote</A>|;
		} elsif ($disp_mode eq 'edit') {
			$displaystatus = -3;
			$edit_link = qq|<A HREF="%%rootdir%%/displaystory/$story->{sid}">edit</A>|;
		} else {
			$displaystatus = 0;
			$edit_link = qq|$story->{score}|;
		}
		
		$info = "Section: $S->{SECTION_DATA}->{$story->{section}}->{title}";
		$info .= ", Topic: $S->{TOPIC_DATA}->{$story->{tid}}->{alttext}" if $S->var('use_topics');

		if ($displaystatus == -1) {
			$color = " BGCOLOR=\"%%undisplayedstory_bg%%\"";
		} elsif ($displaystatus == 1) {
			$color = " BGCOLOR=\"%%sectiononlystory_bg%%\"";
		} elsif ($displaystatus == -2) {
			$color = " BGCOLOR=\"%%submittedstory_bg%%\"";
		} elsif ($displaystatus == -3) {
			# Check and see if we've voted 'spam' on this story.
			# Checking the use_anti_spam var here seems a little redundant,
			# but it can't hurt, can it?
			if ($S->{UI}->{VARS}->{use_anti_spam} &&
			   ($S->_get_user_voted($S->{UID}, $story->{sid}) != 0)) {
				$color = " BGCOLOR=\"%%editqueuespam_bg%%\"";
			}else{
				$color = " BGCOLOR=\"%%editqueuestory_bg%%\"";
			}
		} else {
			$color = '';
		}
		
		$story_num = ((($S->{CGI}->param('page') || 1)-1) * $get_num) + $i;
        $story->{nick} = $S->{UI}->{VARS}->{anon_user_nick} if $story->{aid} == -1;

		if ($displaystatus == -3) {
                        $edit_queue .= qq|
                        <TR$color>
                                <TD valign="top">%%norm_font%%$edit_i) <A HREF="%%rootdir%%/$story_link">$story->{title}</A> ($story->{comments} comments)$story_read_link
                                <BR>$info%%norm_font_end%%</TD>
                                <TD valign="top">%%norm_font%%$story->{ftime}%%norm_font_end%%</TD>
                                <TD align="center" valign="top">%%norm_font%%$story->{nick}%%norm_font_end%%</TD>
                                <TD valign="top">%%norm_font%%$edit_link%%norm_font_end%%</TD>
                        </TR>|;
                        $edit_i++;
        } else {
                        $vote_queue .= qq|
                        <TR$color>
                                <TD valign="top">%%norm_font%%$vote_i) <A HREF="%%rootdir%%/$story_link">$story->{title}</A> ($story->{comments} comments)$story_read_link
                                <BR>$info%%norm_font_end%%</TD>
                                <TD valign="top">%%norm_font%%$story->{ftime}%%norm_font_end%%</TD>
                                <TD align="center" valign="top">%%norm_font%%$story->{nick}%%norm_font_end%%</TD>
                                <TD valign="top">%%norm_font%%$edit_link%%norm_font_end%%</TD>
                        </TR>|;
                        $vote_i++;
        }
		$i = $i+1;
		$story = $sth->fetchrow_hashref;
	}
	$sth->finish;
	
	$content .= $vote_queue . $edit_queue;	
	return ($rv, $content);
}

sub _show_threshold_text {
	my $S = shift;
	my $postscore = $S->{UI}->{VARS}->{post_story_threshold};
	my $hidescore = $S->{UI}->{VARS}->{hide_story_threshold};
	my $content = qq|
		<TR><TD COLSPAN=4>%%norm_font%%Post threshold: $postscore<br>Hide threshold: $hidescore|;
	if ($S->{UI}->{VARS}->{use_auto_post}) {
		$content .= qq|<br>Auto-post is on. A posting decision will be made after |;
		if ($S->{UI}->{VARS}->{auto_post_use_time}) {
			my $h = int($S->{UI}->{VARS}->{auto_post_max_minutes} / 60);
			my $m = $S->{UI}->{VARS}->{auto_post_max_minutes} % 60;
			$content .= qq|$h hour| if ($h > 0);
			$content .= ($h > 1) ? qq|s | : qq| |;
			$content .= qq|and | if ($h && $m);
			$content .= qq|$m minute| if ($m > 0);
			$content .= ($m > 1) ? qq|s | : qq| |;
		} else {
			$content .= qq|$S->{UI}->{VARS}->{end_voting_threshold} vote|;
			$content .= qq|s| if ($S->{UI}->{VARS}->{end_voting_threshold} > 1);
		}
		$content .= qq| if no threshold is reached.|
	}
	$content .= qq|%%norm_font_end%%</TD></TR>|;
	return $content;
}

1;
