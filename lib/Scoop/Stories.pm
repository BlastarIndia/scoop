package Scoop;
use strict;
my $DEBUG = 0;

sub main_page {
	my $S = shift;
	my $op = shift; # the op

	if ($op eq 'section') {
		my $section = $S->cgi->param('section');
		$S->{UI}{BLOCKS}{subtitle} = $S->{SECTION_DATA}{$section}{title};
		$S->{UI}{BLOCKS}{subtitle} = 'All Stories' if ($section eq '__all__');
		if( $S->have_section_perm('hide_read_stories', $section ) ) {
			$S->{UI}{BLOCKS}{subtitle} = '';
		}
	}

	return $S->frontpage_view($op);
}

sub get_filter {
	my $S = shift;
	my $p = shift;
	my $q = {};
	
	my $topic     = $p->{'topic'};
	my $section   = $p->{'section'};
	my $author    = $p->{'author'};
	my $day       = $p->{'day'};
	my $last      = $p->{'last'};
	my $from      = $p->{'from'};
	my $to        = $p->{'to'};
	my $fromday   = $p->{'fromday'};
	my $today     = $p->{'today'};
	my $max       = $p->{'max'};
	my $posted_to = $p->{'posted-to'};
	my $keyword   = $p->{'keyword'};
	my $fields    = $p->{'fields'} || '*';
	
	my ($t_where, $s_where, $a_where, $k_where);
	if ($topic) {
		$t_where = $S->parse_options($topic, 'tid');
	}
	if ($section) {
		$s_where = $S->parse_options($section, 'section');
	}
	if ($author) {
		$a_where = $S->parse_options($author, 'aid');
	} 
	if ($keyword) {
		$k_where = $S->parse_keywords($keyword);
	}

	my $tsa_where = $t_where;
	
	if ($s_where) {
		$tsa_where .= ($tsa_where) ? " AND ( $s_where )" : $s_where;
	}
	if ($a_where) {
		$tsa_where .= ($tsa_where) ? " AND ( $a_where )" : $a_where;
	}
	
	my $all_cond = ($tsa_where && $k_where) ? "( $tsa_where ) OR ( $k_where )" : 
		($tsa_where) ? $tsa_where : $k_where;
	
	
	my $page_where;
	if ($posted_to =~ /front/i) {
		$page_where .= ' displaystatus = 0 ';
	} elsif ($posted_to =~ /section/i) {
		$page_where .= ' displaystatus = 1 ';
	} else {
		$page_where .= ' displaystatus >= 0 ';
	}

	my $time_cond = $S->parse_time($day, $last, $from, $to, $fromday, $today);
	
	$q->{WHERE} = ($all_cond) ? "( $all_cond ) AND ( $page_where )" : $page_where;
	$q->{WHERE} .= ($time_cond) ? " AND ( $time_cond )" : '';
	$q->{LIMIT} = $max;
	$q->{ORDER_BY} = 'time DESC';
	$q->{WHAT} = $fields;
	$q->{FROM} = 'stories';
	$q->{DEBUG} = 0;

	my ($rv, $sth) = $S->db_select($q);	
	
	my $stories = [];
	while (my $story = $sth->fetchrow_hashref()) {
		$story->{commentcount} = $S->_commentcount($story->{sid});	
		push @{$stories}, $story;
	}
	$sth->finish();
	return $stories;
}


sub parse_options {
	my $S = shift;
	my $str = shift;
	my $field = shift;
	my @ops = split /\s*,\s*/, $str;
	
	# Filter out required and refused topics
	my @require;
	my @prevent;
	my $where;
	while (my $op = shift @ops) {
		if ($op =~ /\!/) {
			$op =~ s/\!//g;
			push @prevent, $op;
		} else {
			push @require, $op;
		}
	}
	
	if ($#require >= 0) {	
		for (0..$#require) {
			$require[$_] = $S->{DBH}->quote($require[$_]);
		}
		$where = "$field = ".join(" OR $field = ", @require);
    }
	
	if ($#prevent >= 0) {
		for (0..$#prevent) {
			$prevent[$_] = $S->{DBH}->quote($prevent[$_]);
		}
		my $p_where .= " $field != ".join(" AND $field != ", @prevent);
		if ($where) {
			$where = $where." AND ( ".$p_where." ) ";
		} else {
			$where = $p_where;
		}
	}
	
	return $where;
}

sub parse_keywords {
	my $S = shift;
	my $k = shift;
	
	my @words = split /\s*,\s*/, $k;
	
	my @where;
	foreach my $w (@words) {
		$w =~ s/['"%]//g;
		my $wordstring = "'%$w%'";
		if ($w =~ /^!/) {
			$w =~ s/^!//;
			$wordstring = "'% $w %'";
		}
		
		push @where, qq|title LIKE $wordstring OR introtext LIKE $wordstring OR bodytext LIKE $wordstring|;
	}
	
	return join(' OR ', @where);
}

# Why is this here? Is it used anywhere?
# If it is it needs to be rewritten to not use
# TO_DAYS(), which is MySQL specific. If it's not
# then it should be deleted
sub parse_time {
	my $S = shift;
	my ($day, $last, $from, $to, $fromday, $today) = @_;		
	
	my ($adjust_time, $zone) = $S->time_localize('time');
	
	if ($day && $day =~ /^\d{8}$/) {
		$day =~ /(\d\d)(\d\d)(\d\d\d\d)/;
		my $d = $1;
		my $m = $2;
		my $y = $3;
		return qq|TO_DAYS($adjust_time) = TO_DAYS("$y-$m-$d")|;
	} elsif ($last && $last =~ /^\d+$/) {
		return qq|time >= DATE_SUB(NOW(), INTERVAL $last SECOND)|;
	} elsif ($fromday && $fromday =~ /^\d{8}$/) {
		$fromday =~ /(\d\d)(\d\d)(\d\d\d\d)/;
		my $d = $1;
		my $m = $2;
		my $y = $3;
		my $range = qq|time >= "$y-$m-$d 00:00:00"|;
		if ($today && $today =~ /^\d{8}$/) {
			$today =~ /(\d\d)(\d\d)(\d\d\d\d)/;
			my $td = $1;
			my $tm = $2;
			my $ty = $3;
			$range .= qq| AND time <= "$ty-$tm-$td 23:59:59"|;
		}
		return $range;
	} elsif ($today && $today =~ /^\d{8}$/) {
		$today =~ /(\d\d)(\d\d)(\d\d\d\d)/;
		my $td = $1;
		my $tm = $2;
		my $ty = $3;
		
		return qq|time <= "$ty-$tm-$td"|;
	} elsif ($from && $from =~ /^\d+$/) {
		my $now = 'NOW()';
		if ($to && $to =~ /^\d+$/) {
			$now = "DATE_SUB(NOW(), INTERVAL $to SECOND)";
		}
		return qq|time >= DATE_SUB($now, INTERVAL $from SECOND)|;
	} elsif ($to && $to =~ /^\d+$/) {
		return qq|time <= DATE_SUB(NOW(), INTERVAL $to SECOND)|;
	}
	return '';
}

		
sub special {
	my $S = shift;

	
	my $id = $S->{CGI}->param('page');
	my $page = $S->_get_special_page($id);
	
	# Set the page title
	$S->{UI}->{BLOCKS}->{subtitle} = $page->{title};

	my $content = $S->interpolate($S->{UI}->{BLOCKS}->{special_page_layout}, $page);

	$S->{UI}->{BLOCKS}->{CONTENT} = $content;
	return ;
}

sub _get_special_page {
	my $S = shift;
	my $id = shift;
	my $f_id = $S->{DBH}->quote($id);
	
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'special',
		WHERE => qq|pageid = $f_id|});
	
	my $page = {};
	if ($rv && ($rv == 0)) {
		$page->{content} = qq|
			I'm sorry. I couldn't find that page.|;
		$page->{title} = "Page not found";
		return $page;
	}
	$page = $sth->fetchrow_hashref;
	$sth->finish;
	return $page;
}


sub submit_story {
	my $S = shift;

	if ($S->{CGI}->param('spellcheck')) {
		$S->param->{save} = undef;
		$S->param->{preview} = 'Preview';
	}

	my $save = $S->{CGI}->param('save') || undef;

	# Set the page title
	$S->{UI}->{BLOCKS}->{subtitle} = $S->{UI}->{BLOCKS}->{submit_page_title};

	$S->{UI}->{BLOCKS}->{STORY} = qq|
		<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=100%><TR><TD>|;
	$S->{UI}->{BLOCKS}->{CONTENT} = qq|
		<TABLE BORDER=0 CELLPADDING=0 CELLSPACING=2 WIDTH=100%>|;
	
	my $sid = undef;			
	my $error;

	# Check the formkey, to prevent duplicate postings
	unless ($S->check_formkey()) {
		$error = "Invalid form key. This is probably because you clicked 'Post' or 'Preview' more than once. DO NOT HIT 'BACK'! Make sure you haven't already posted this once, then go ahead and post or preview from this screen.";
		$save = 0;
		$S->param->{preview} = 'preview';
	}

	my $done = 0;
	if ($save) {
		($sid, $error) = $S->save_story('public');
		
		if ($sid) {
			$done = 1;
			if ( my $eid = $S->cgi->param('event') ) {
				my $q_eid = $S->dbh->quote($eid);
				my $q_sid = $S->dbh->quote($sid);
				my ($rv,$sth) = $S->db_insert({
					DEBUG => $DEBUG,
					INTO => 'event_story',
					COLS => 'eid,sid',
					VALUES => "$q_eid,$q_sid"
				});
				($rv,$sth) = $S->db_update({
					DEBUG => $DEBUG,
					WHAT => 'events',
					SET => 'last_update = NULL',
					WHERE => "eid=$q_eid"
				});
			}
			my $section = $S->{CGI}->param('section');
			$S->param->{sid} = $sid;

			my $story = $S->story_data([$sid]);
			$story = $story->[0];
			my $toget = lc($section) . "_";
			my $msg_type;
			if ($story->{displaystatus} < 0) {
				$msg_type = "submission_message";
			} else {
				$msg_type = "post_message";
			}
			$toget .= $msg_type;
			my $message = $S->{UI}->{BLOCKS}->{$toget};
			$message = $S->{UI}->{BLOCKS}->{$msg_type} unless ($message);

			$S->{UI}->{BLOCKS}->{CONTENT} .= qq|
			<TR>
				<TD align="center">%%norm_font%%$message%%norm_font_end%%</TD>
			</TR>|;
			$S->{UI}->{BLOCKS}->{STORY} .= $S->displaystory($sid);
		} else {
			$S->{UI}->{BLOCKS}->{CONTENT} .= qq|
			<TR>
				<TD BGCOLOR="%%title_bgcolor%%">%%title_font%%<B>$S->{UI}->{BLOCKS}->{submit_page_title}</B>%%title_font_end%%</TD>
			</TR>
			<TR>
				<TD align="center">
				 %%norm_font%%<FONT COLOR="#FF0000"><B>$error</B></FONT>%%norm_font_end%%
				</TD>
			</TR>|;
		}
	} else {
		$S->{UI}->{BLOCKS}->{CONTENT} .= qq|
			<TR>
				<TD BGCOLOR="%%title_bgcolor%%">%%title_font%%<B>$S->{UI}->{BLOCKS}->{submit_page_title}</B>%%title_font_end%%</TD>
			</TR>|;
		$S->{UI}->{BLOCKS}->{CONTENT} .= qq|
			<TR>
				<TD align="center">
				%%norm_font%%<FONT %COLOR="#FF0000"><B>$error</B></FONT>%%norm_font_end%%
				</TD>
			</TR>| if $error;
	}

	unless ($done) {	
		if ($save) {
			$S->param->{preview} = 'preview';
		}
		my ($story, $content) = $S->submit_story_form();
		$S->{UI}->{BLOCKS}->{STORY} .= "<!-- story output--> <TR><TD>$story</TD></TR> <!-- x Story output -->";
		$S->{UI}->{BLOCKS}->{CONTENT} .= "<TR><TD>$content</TD></TR>";
	}
	
	$S->{UI}->{BLOCKS}->{CONTENT} .= qq|
		</TABLE>|;
	$S->{UI}->{BLOCKS}->{STORY} .= qq|
		</TD></TR></TABLE>|;
			
	return ;
}

sub _check_story_mode {
	my $S = shift;
	my $sid = shift;

	if (defined($S->{STORIES}->{$sid}->{displaystatus})) {
		return $S->{STORIES}->{$sid}->{displaystatus};
	}

	my $quoted_sid = $S->dbh->quote($sid);
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'displaystatus',
		FROM => 'stories',
		WHERE => qq|sid = $quoted_sid|});
		
	my $stat = $sth->fetchrow();

	# Save for later
	$S->{STORIES}->{$sid}->{displaystatus} = $stat;
	return $stat;
}

sub _check_commentstatus {
	my $S = shift;
	my $sid = shift;

	if (defined($S->{STORIES}->{$sid}->{commentstatus})) {
		return $S->{STORIES}->{$sid}->{commentstatus};
	}

	my $quoted_sid = $S->dbh->quote($sid);
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'commentstatus',
		FROM => 'stories',
		WHERE => qq|sid = $quoted_sid|});
		
	my $stat = $sth->fetchrow();

	# Save for later
	$S->{STORIES}->{$sid}->{commentstatus} = $stat;
	return $stat;
}

sub _check_archivestatus {
	my $S = shift;
	my $sid = shift;
	my $stat;

	if (defined($S->{STORIES}->{$sid}->{archivestatus})) {
		#warn "_check_archivestatus (cached) = $S->{STORIES}->{$sid}->{archivestatus}";
		return $S->{STORIES}->{$sid}->{archivestatus};
	}

	if ($S->{DBHARCHIVE}) {
	my $q_sid = $S->dbh->quote($sid);

	my ($rv, $sth) = $S->db_select({
		DEBUG => 0,
		WHAT => 'count(sid)',
		FROM => 'stories',
		WHERE => qq|sid = $q_sid|});
		
	$stat = $sth->fetchrow();
	$sth->finish();
	
	if (!$stat) {
		#warn "sid $sid not in main. checking archive";
		($rv, $sth) = $S->db_select({
			ARCHIVE => 1,
			WHAT => 'count(sid)',
			FROM => 'stories',
			WHERE => qq|sid = $q_sid|});
		$stat = $sth->fetchrow() unless !$rv;
		#warn "sid $sid not in archive\n" if !$stat;
		$sth->finish();
		if (!$stat) {
			#warn "sid $sid not in archive story table. Checking comments";
			($rv, $sth) = $S->db_select({
				ARCHIVE => 1,
				WHAT => 'count(sid)',
				FROM => 'comments',
				LIMIT => 1,
				WHERE => qq|sid = $q_sid|});
			$stat = $sth->fetchrow() unless !$rv;
			#warn "sid $sid not in archived comments table";
			$sth->finish();
		}
	} else {
		$stat = 0;
	}
	
	} else
	{
		$stat = 0;	
	}
	#warn "_check_archivestatus = $stat";

	# Save for later
	$S->{STORIES}->{$sid}->{archivestatus} = $stat;
	return $stat;
}

sub _get_story_title {
	my $S = shift;
	my $sid = shift;
	
	if ($S->{STORIES}->{$sid}->{title}) {
		return $S->{STORIES}->{$sid}->{title};
	}
	
	my $quoted_sid = $S->dbh->quote($sid);
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'title',
		FROM => 'stories',
		WHERE => qq|sid = $quoted_sid|});
	
	my $title = $sth->fetchrow();
	$sth->finish();
	# Save for later
	$S->{STORIES}->{$sid}->{title} = $title || undef;
	return $title;
}

sub _get_story_section {
	my $S = shift;
	my $sid = shift;
	my $quoted_sid = $S->dbh->quote($sid);
	
	if ($S->{STORIES}->{$sid}->{section}) {
		return $S->{STORIES}->{$sid}->{section};
	}
	
	my ($rv, $sth) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'section',
		FROM => 'stories',
		WHERE => qq|sid = $quoted_sid|});
	
	my $title = $sth->fetchrow();
	$sth->finish();

	# Save for later
	$S->{STORIES}->{$sid}->{section} = $title || undef;
	return $title;
}

sub cut_title {
	my $S = shift;
	my ($str, $length) = @_;

	# cut it down to length
	$str =~ s/(.{$length}).*/$1/;
	# strip any entities that were cut in half
	$str =~ s/&[A-Za-z0-9#]*$//;

	return $str;
}

1;
