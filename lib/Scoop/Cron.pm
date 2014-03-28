=head1 Cron.pm

The module responsible for op=cron, and the cron admin. When it's called, it
deals with running all of the cron jobs that need to be, and updates the
database concerning when it was last run. This way, one real cron job can run
all of the ones for Scoop.

=head1 Functions

=over 4

=cut

package Scoop;
use strict;
my $DEBUG = 0;

=item * get_crons()

Gets all the cron info out of the database and returns it as a hash with key of
name, value of hash ref of func, run_every, last_run, and enabled.

=cut

sub get_crons {
	my $S = shift;

	my ($rv, $sth) = $S->db_select({
		WHAT => 'name, func, run_every, last_run, enabled, is_box',
		FROM => 'cron'
	});
	my $ret = {};
	while (my $row = $sth->fetchrow_arrayref) {
		$ret->{$row->[0]} = {
			func      => $row->[1],
			run_every => $row->[2],
			last_run  => $row->[3],
			enabled   => $row->[4],
			is_box    => $row->[5]
		};
	}
	$sth->finish;

	return $ret;
}

=item * _cron_to_run()

Gets the cron info, then figures out which of them need to be run. Returns the
info for all of the runs that should be run.

=cut

sub _cron_to_run {
	my $S = shift;

	require Time::Local;

	my $crons = $S->get_crons();
	my $to_run = {};
	my $now = time();
	while (my($k, $v) = each %{$crons}) {
		next unless $v->{enabled};
		my $secs;
		if ($v->{last_run} && ($v->{last_run} ne '0000-00-00 00:00:00')) {
			$v->{last_run} =~ /(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;
			# seconds, minutes, hours, days, months, years
			my @date = ($6, $5, $4, $3, $2, $1);
			$date[4] -= 1;     # month
			$secs = Time::Local::timelocal(@date);
		} else {
			$secs = 0;
		}

		if (($secs + $v->{run_every}) <= $now) {
			$to_run->{$k} = [$v->{func}, $v->{is_box}];
			warn "<<CRON>> running $k\n" if $DEBUG;
		}
	}

	return $to_run;
}

=item * _cron_run(to run)

Given a hash ref (the very same that C<_cron_to_run> returns), runs each of the
cron jobs and returns 1 if everything goes okay. Otherwise, returns a hash ref
with keys of cron jobs that failed, and values the error they failed with.

=cut

sub _cron_run {
	my $S = shift;
	my $to_run = shift || return;

	my $errors = {};
	my $did_error = 0;
	# We want to run the crons as the anonymous user
	my $user_data = $S->user_data(-1);
	my $old_uid;
 	if ($S->{UID} != -1) {
 		$old_uid = $S->{UID};
 		$S->{UID} = -1;
 		$S->_refresh_group_perms();
 	}

	while (my($k, $v) = each %{$to_run}) {
		warn "[cron] Running $v->[0]\n" if ($DEBUG);

		my $ret;
		# check if it's a box or a function
		if ($v->[1]) {
			$ret = $S->run_box($v->[0]);
		} else {
			my $func = $v->[0];
			$ret = $S->$func();  # this works... cool
		}

		if ($ret != 1) {
			$errors->{$k} = $ret;
			$did_error = 1;
		}
	}

	# Back to old uid permissions now we've run everything
 	if (defined $old_uid) {
 		$S->{UID} = $old_uid;
 		$S->_refresh_group_perms();
 	}

	return 1 unless $did_error;
	return $errors;
}

=item * cron()

Handles the cron op. Mainly dispatches to other methods.

=cut

sub cron {
	my $S = shift;

	my $now = time();
	my $to_run = $S->_cron_to_run();
	$S->cron_update_last_run($now, keys %{$to_run});
	my $errors = $S->_cron_run($to_run);

	if ($errors == 1) {
		my $ran = join(", ", keys %{$to_run});
		$S->{UI}->{BLOCKS}->{CONTENT} = "Cron finished\nRan: $ran";
	} else {
		my $content = "Errors:\n";;
		foreach (keys %{$errors}) {
			$content .= "$_: $errors->{$_}\n";
		}

		$content =~ s/</&lt;/g;
		$content =~ s/>/&gt;/g;
		$S->{UI}->{BLOCKS}->{CONTENT} = $content;
	}
}

=item * cron_update_last_run(time, crons)

For each of the crons passed to it, updates the last_run time to B<time>.

=cut

sub cron_update_last_run {
	my $S = shift;
	my $now = $S->_cron_date(shift);

	my $update = {};
	foreach (@_) {
		$update->{$_} = { last_run => $now };
	}

	return $S->save_cron($update);
}

sub _cron_date {
	my $S = shift;
	my $time = shift || time();

	my @now = localtime($time);
	$now[5] += 1900;   # year
	$now[4]++;         # month
	
	return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $now[5], $now[4], $now[3], $now[2], $now[1], $now[0]);
}

=item * save_cron(crons)

Crons is a hash ref, with keys cron names, and each value is a hash ref of
fields to update for that one, and their values.

=cut

sub save_cron {
	my $S = shift;
	my $crons = shift || return;

	while (my($cron, $change) = each %{$crons}) {
		my $set;
		foreach (keys %{$change}) {
			$set .= ' AND ' if $set;   # don't add first first one
			$change->{$_} =~ s/'/''/g;
			$set .= qq|$_ = '$change->{$_}'|;
		}

		my ($rv, $sth) = $S->db_update({
			WHAT  => 'cron',
			SET   => $set,
			WHERE => "name = '$cron'"
		});
		$sth->finish;
	}

	return 1;
}

=item * add_cron({name, is_box, function, run_every, enabled})

Adds a new cron to the database using the args passed as a hash.

=cut

sub add_cron {
	my $S = shift;
	my %fields = (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_;

	my $vals;
	foreach my $f (qw(name is_box function run_every enabled)) {
		if ($f eq 'is_box' || $f eq 'enabled') {
			$fields{$f} = $fields{$f} ? 1 : 0;
		} elsif ($f eq 'run_every') {
			$fields{$f} = $S->time_relative_to_seconds($fields{$f});
		}

		$vals .= ', ' if $vals;
		$vals .= $S->{DBH}->quote($fields{$f});
	}

	my ($rv,$sth) = $S->db_insert({
		INTO   => 'cron',
		COLS   => 'name, is_box, func, run_every, enabled',
		VALUES => $vals
	});
	$sth->finish;

	return "Error: $DBI::errstr" unless $rv;
	return 1;
}

=item * rem_cron(cron, [...])

Given a list of crons, it removes all of them.

=cut

sub rem_cron {
	my $S = shift;
	my @crons = @_;

	my $where;
	foreach my $c (@crons) {
		$where .= ' OR ' if $where;
		$where .= 'name = ' . $S->{DBH}->quote($c);
	}

	my ($rv, $sth) = $S->db_delete({
		FROM  => 'cron',
		WHERE => $where
	});
	$sth->finish;

	return unless $rv;
	return 1;
}

=item * cron_change_enabled(cron, value)

Changes the enabled value of B<cron> to B<value>.

=cut

sub cron_change_enabled {
	my $S = shift;
	my $cron = shift || return;
	my $newval = shift;

	return unless defined($newval);

	my ($rv, $sth) = $S->db_update({
		WHAT => 'cron',
		SET  => "enabled = $newval",
		WHERE => "name = '$cron'"
	});
	$sth->finish;
}	

=item * edit_cron()

The basis of the cron admin tool, this function is called by Admin.pm, and then
serves only to call some other functions and return their result.

=cut

sub edit_cron {
	my $S = shift;
	my $msg = $S->_write_cron();
	my $form = $S->_get_cron_form($msg);
	return $form;
}

sub _write_cron {
	my $S = shift;

	return unless $S->{CGI}->param('write');
	return "Permission Denied" unless $S->have_perm('cron_admin');

	my $action = $S->{CGI}->param('action');

	if ($action eq 'add') {
		my $err;
		my %fields = (
			new_cron => 'name', new_is_box => 'is_box', new_func => 'function',
			new_re   => 'run_every', new_enabled => 'enabled'
		);
		my %to_pass;
		foreach my $f (qw(new_cron new_func new_re)) {
			if (my $v = $S->{CGI}->param($f)) {
				$to_pass{ $fields{$f} } = $v;
			} else {
				$err .= $err ? ', ' : 'The following fields need to be filled in: ';
				$err .= $fields{$f};
			}
		}
		return $err if $err;
		# these two, being checkboxes, can't be part of the loop, because not
		# being defined is valid for them
		$to_pass{enabled} = $S->{CGI}->param('new_enabled');
		$to_pass{is_box}  = $S->{CGI}->param('new_is_box');

		my $ret = $S->add_cron(%to_pass);

		return $ret unless $ret == 1;
		return "Successfully added $to_pass{name}";
	}

	my @which  = $S->{CGI}->param('which');
	my $crons  = $S->get_crons();

	my $error;
	my $to_run = {};
	foreach my $c (@which) {
		unless ($crons->{$c}) {
			$error .= ", " if $error;
			$error .= "cron '$c' unknown";
		}

		if ($action eq 'toggle_enabled') {
			my $changeto = ($crons->{$c}->{enabled}) ? 0 : 1;
			$S->cron_change_enabled($c, $changeto);
		} elsif ($action eq 'edit_run_every') {
			my $newval = $S->{CGI}->param($c . "_re");
			next unless $newval;
			$newval = $S->time_relative_to_seconds($newval);
			$S->save_cron({$c => { run_every => $newval }});
		} elsif ($action eq 'clear_last_run') {
			$S->save_cron({$c => { last_run => 0 }});
		} elsif ($action eq 'run') {
			$to_run->{$c} = [$crons->{$c}->{func}, $crons->{$c}->{is_box}];
		} elsif ($action eq 'remove') {
			$S->rem_cron($c);
		} else {
			$error = "action '$action' is unknown";
			last;
		}
	}

	if ($action eq 'run') {
		my $now = time();
		$error .= '.' if $error;

		my $run_errs = $S->_cron_run($to_run);

		unless ($run_errs == 1) {
			$error .= "<br>\n";
			foreach (keys %{$run_errs}) {
				$error .= "$_: $run_errs->{$_}<br>\n";
			}
		}
		$S->cron_update_last_run($now, keys %{$to_run});
	}

	return "Error doing $action: $error" if $error;
	return "Finished $action of selected crons";
}

sub _get_cron_form {
	my $S = shift;
	my $msg = shift;

	my $page = qq|
	<form action="%%rootdir%%/" method="POST">
	<input type="hidden" name="op" value="admin" />
	<input type="hidden" name="tool" value="cron" />
	<table width="100%" border="0" cellpadding="0" cellspacing="0">
		<tr bgcolor="%%title_bgcolor%%">
			<td>%%title_font%%Edit Crons%%title_font_end%%</td>
		</tr>|;
	$page .= qq|
		<tr>
			<td>%%title_font%%<font color="#ff0000">$msg</font>%%title_font_end%%</td>
		</tr>| if $msg;
	$page .= qq|
		<tr>
			<td>
			<table width="100%" border="0" cellpadding="0" cellspacing="0">
			<tr>
				<td>&nbsp;</td>
				<td>%%norm_font%%<b>Cron</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Box?</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Function</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Run Every</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Last Run</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Enabled</b>%%norm_font_end%%</td>
			</tr>|;
	my $crons = $S->get_crons();
	foreach my $c (sort keys %{$crons}) {
		my $v = $crons->{$c};
		$v->{run_every} = $S->time_seconds_to_relative($v->{run_every});
		my $is_box_str  = $v->{is_box}  ? 'Yes' : 'No';
		my $enabled_str = $v->{enabled} ? 'Yes' : 'No';
		my $func_link = $v->{is_box} ? qq|<a href="%%rootdir%%/admin/boxes/$v->{func}" target="_blank">$v->{func}</a>| : $v->{func};
		$page .= qq|
			<tr>
				<td><INPUT TYPE="checkbox" NAME="which" VALUE="$c"></td>
				<td>%%norm_font%%$c%%norm_font_end%%</td>
				<td>%%norm_font%%$is_box_str%%norm_font_end%%</td>
				<td>%%norm_font%%$func_link%%norm_font_end%%</td>
				<td>%%norm_font%%<input type="text" name="${c}_re" value="$v->{run_every}" size="10" />%%norm_font_end%%</td>
				<td>%%norm_font%%$v->{last_run}%%norm_font_end%%</td>
				<td>%%norm_font%%$enabled_str%%norm_font_end%%</td>
			</tr>|;
	}
	$page .= qq|
			<tr>
				<td>&nbsp;</td>
				<td>%%norm_font%%<input type="text" name="new_cron" />%%norm_font_end%%</td>
				<td>%%norm_font%%<input type="checkbox" name="new_is_box" checked="checked" />%%norm_font_end%%</td>
				<td>%%norm_font%%<input type="text" name="new_func" />%%norm_font_end%%</td>
				<td>%%norm_font%%<input type="text" name="new_re" size="10" />%%norm_font_end%%</td>
				<td>&nbsp;</td>
				<td>%%norm_font%%<input type="checkbox" name="new_enabled" checked="checked" />%%norm_font_end%%</td>
			</tr>
			</table>
			</td>
		</tr>
		<tr>
			<td>%%norm_font%%<b><br />Action:</b>
			<input type="radio" name="action" value="run" />Force Run 
			<input type="radio" name="action" value="toggle_enabled" />Toggle Enabled 
			<input type="radio" name="action" value="edit_run_every" />Change Run Every 
			<input type="radio" name="action" value="clear_last_run" />Clear Last Run
			<input type="radio" name="action" value="add" />Add Cron
			<input type="radio" name="action" value="remove" />Remove Cron
			%%norm_font_end%%</td>
		</tr>
		<tr>
			<td>%%norm_font%%<br /><a href="%%rootdir%%/?op=cron">Run Cron Now</a>%%norm_font_end%%</td>
		</tr>
		<tr>
			<td>%%norm_font%%<br />
			<input type="submit" name="write" value="Save crons" />
			<input type="reset" value="Reset" />
			%%norm_font_end%%</td>
		</tr>
	</table>
	</form>|;

	return $page;
}

=back

=head1 Cron Jobs

After this point, it's all code for cron jobs.

=over 4

=item * cron_rdf

Job to generate an RDF file for the site.

Vars used: rdf_file, rdf_image, rdf_days_to_show, rdf_max_stories,
rdf_copyright, max_rdf_intro, slogan, sitename, rdf_creator, rdf_publisher

=cut

sub cron_rdf {
	my $S = shift;

	use XML::RSS;

	#my $rss = XML::RSS->new(encoding => $S->{UI}->{VARS}->{charset});
	my $rss = XML::RSS->new(encoding => $S->{UI}->{VARS}->{charset});

	my $url = "$S->{UI}->{VARS}->{site_url}$S->{UI}->{VARS}->{rootdir}/";
	$rss->channel(
		title => $S->strip_invalid($S->{UI}->{VARS}->{sitename}),
		link  => $url,
		description => $S->{UI}->{BLOCKS}->{slogan},
		dc => {
#			date      => scalar localtime,
			date      => $S->_rss_datetime(),
			creator   => $S->strip_invalid($S->{UI}->{VARS}->{rdf_creator}   || $S->{UI}->{VARS}->{sitename}),
			publisher => $S->strip_invalid($S->{UI}->{VARS}->{rdf_publisher} || $S->{UI}->{VARS}->{sitename}),
			rights    => $S->strip_invalid($S->{UI}->{VARS}->{rdf_copyright}),
			language  => 'en-us'
		}
	);

	$rss->image(
		title => $S->strip_invalid($S->{UI}->{VARS}->{sitename}),
		url   => $S->strip_invalid($S->{UI}->{VARS}->{rdf_image}),
		link  => $url
	);

	$rss->textinput(
		title => $S->strip_invalid("Search $S->{UI}->{VARS}->{sitename}"),
		name  => "string",
		link  => $url . 'search/'
	);

	my $story_params;
	$story_params->{-type} = 'section';
	$story_params->{-section} = '__all__';
	my $max_stories  = $S->{UI}->{VARS}->{rdf_max_stories};
	if ($max_stories) { 
		$story_params->{-maxstories} = $max_stories;
	}
	my $days_to_show = $S->{UI}->{VARS}->{rdf_days_to_show};
	if ($days_to_show) {
		$story_params->{-maxdays} = $days_to_show;
	}
	my $stories = $S->getstories($story_params);

	foreach my $story (@{$stories}) {
		$story->{introtext} =~ s/[\n\r]/ /g;
		foreach (qw(title introtext)) {
			# (crudely) remove HTML
			$story->{$_} =~ s/<.*?>//g;
			# unfilter &lt; and &gt;, so that we don't turn them into &amp;lt;
			$story->{$_} =~ s/&lt;/</g;
			$story->{$_} =~ s/&gt;/>/g;
			# filter &
			$story->{$_} =~ s/&/&amp;/g;
			# (re-)filter < and >
			$story->{$_} =~ s/</&lt;/g;
			$story->{$_} =~ s/>/&gt;/g;
		}

		my $max_intro = $S->{UI}->{VARS}->{max_rdf_intro};
		if ($max_intro) {
			my @intro = split(' ', $story->{introtext});
			@intro = splice(@intro, 0, $max_intro);
			$story->{introtext} = join(' ', @intro) . '...';
		}

		my $link = $url . "story/$story->{sid}";
		$rss->add_item(
			title => $S->strip_invalid($story->{title}),
			link  => $link,
			description => $S->strip_invalid($story->{introtext})
		);
	}

	$rss->strict(1);
	eval { $rss->save($S->{UI}->{VARS}->{rdf_file}) };
	if ($@) {
		my $error = $@;
		chomp($error);
		return $error;
	}

	return 1;
}

sub _rss_datetime {
	my ($s,$m,$h,$d,$mo,$y) = (gmtime(time))[0..5];

	$y  += 1900;
	$mo += 1;
	return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $y, $mo, $d, $h, $m, $s);
}

=item * cron_rdf_fetch()

Job to fetch RDF's from other sites, and put them in the db.

Vars used: use_rdf_feeds, rdf_http_proxy

=cut

sub cron_rdf_fetch {
	my $S = shift;

	return "RDF feeds not enabled" unless $S->{UI}->{VARS}->{use_rdf_feeds};

	my $channels = $S->rdf_channels();

	my $errored;
	foreach my $c (@{$channels}) {
		next unless $c->{enabled};

		my $ret = $S->rdf_fetch_and_store($c->{rdf_link}, $c->{rid});
		$errored .= "$c->{title} ($c->{rid}), " unless $ret == 1;
	}
	$errored =~ s/, $//;

	return 1 unless $errored;
	return "Couldn't fetch $errored";
}

=item * cron_sessionreap()

Job to clean up old sessions in the db, and remove them.

Vars used: keep_sessions_for (in format "<time> <unit>")

=cut

sub cron_sessionreap {
	my $S = shift;

	$S->var('keep_sessions_for') =~ /(\d+)\s*(.+)/;
	my ($length, $unit) = ($1, $2);

	my ($rv, $sth) = $S->db_delete({
		DEBUG => $DEBUG,
		FROM  => 'sessions',
		WHERE => "last_update < " . $S->db_date_sub("NOW()", "$length $unit")
	});
	my $ret = $rv ? 1 : "couldn't cleanup sessions";
	$sth->finish;

	return $ret;
}

=item * cron_digest()

Job to send out digest mailings.

Vars used: enable_story_digests, local_email

Blocks used: digest_storyformat, digest_headerfooter, digest_subject

=cut

# this is basically a direct port from cron.pl style to web-based style cron,
# so it may be a little rough.

sub cron_digest {
	my $S = shift;

	return "can't run because enable_story_digests is false"
		unless $S->{UI}->{VARS}->{enable_story_digests};

	my @date = localtime();

	my $users = $S->_cron_digest_fetch_userlist(\@date);
	my $data  = $S->_cron_digest_fetch_email_conts(\@date);

	my $errors;
	foreach my $user (@{$users}) {
		my $ret = $S->_cron_digest_send_email($user, $data);
		if ($ret != 1) {
			$errors .= ", " if $errors;
			$errors .= $ret;
		}
	}

	return $errors if $errors;
	return 1;
}

sub _cron_digest_fetch_userlist {
	my $S = shift;
	my $date = shift;

	my $where = "userprefs.prefname = 'digest' AND userprefs.uid = users.uid AND userprefs.prefvalue != 'Never' AND userprefs.prefvalue != ''";
	# don't get weekly digests if today isn't Sunday
	$where .= " AND userprefs.prefvalue != 'Weekly'" if $date->[6] != 0;
	# don't get monthly digests if it's not the first of the month
	$where .= " AND userprefs.prefvalue != 'Monthly'" if $date->[3] != 1;

	my ($rv, $sth) = $S->db_select({
		WHAT  => "userprefs.uid, userprefs.prefvalue, users.realemail",
		FROM  => "userprefs, users",
		WHERE => $where
	});

	my @users;
	while (my($uid, $prefval, $email) = $sth->fetchrow()) {
		push(@users, {uid => $uid, email => $email, freq => $prefval});
	}
	$sth->finish();

	return \@users;
}

sub _cron_digest_fetch_email_conts {
	my $S = shift;
	my $date = shift;
	my $data = {};

	$data->{Daily}   = $S->_cron_digest_getdata('Daily');
	$data->{Weekly}  = $S->_cron_digest_getdata('Weekly');
	$data->{Monthly} = $S->_cron_digest_getdata('Monthly');

	return $data;
}

sub _cron_digest_getdata {
	my $S = shift;
	my $frequency = shift;

	# Populate $rollback with the user preferences for digest frequency. Timed
	# in minutes! days ends lots of redundant stuff
	my $rollback;
	if   ($frequency eq 'Daily')   { $rollback = 60 * 24;      }
	elsif($frequency eq 'Weekly')  { $rollback = 60 * 24 * 7;  }
	elsif($frequency eq 'Monthly') { $rollback = 60 * 24 * 30; }

	# Get topic and section names
	# NOTE: I think there's a func to do this, but I don't know of it as I do
	# this, so I'll just port the SQL   -kas
	#my ($rv, $sth) = $S->db_select({
	#	FROM => 'topics',
	#	WHAT => 'tid, alttext'
	#});
	#my $topics = {};
	#while (my($tid, $text) = $sth->fetchrow()) {
	#	$topics->{$tid} = $text;
	#}
	#$sth->finish();

	# NOTE: same here  -kas
	#($rv, $sth) = $S->db_select({
	#	FROM => 'sections',
	#	WHAT => 'section, title',
	#});
	#my $sections = {};
	#while (my($sec, $title) = $sth->fetchrow()) {
	#	$sections->{$sec} = $title;
	#}
	#$sth->finish();

	my $data = "";

	my $ad_section = $S->{UI}->{VARS}->{ad_story_section} || 'advertisements';
	$ad_section = $S->dbh->quote($ad_section);
	my ($rv, $sth) = $S->db_select({
		FROM  => 'stories LEFT JOIN users ON stories.aid = users.uid',
		WHAT  => 'sid, tid, aid, users.nickname AS nick, time, title, dept, introtext, section',
		WHERE => "displaystatus >= 0 AND section != $ad_section AND section != 'Diary' AND time >= " . $S->db_date_sub("NOW()", "$rollback minute"),
		ORDER_BY => 'time desc'
	});
	my $count = 0;
	while (my $storydata = $sth->fetchrow_hashref()) {
		$count = 1;
		$storydata->{nick} = $S->{UI}->{VARS}->{anon_user_nick}
			if $storydata->{aid} == -1;
		$data .= $S->_cron_digest_format_stories($storydata);
	}
	$sth->finish();

	if ($count) {
		return $data;
	} else {
		return undef;
	}
}

sub _cron_digest_format_stories {
	my $S = shift;
	my $story = shift;

	my $story_template = $S->{UI}->{BLOCKS}->{digest_storyformat};
	my $url = "$S->{UI}->{VARS}->{site_url}$S->{UI}->{VARS}->{rootdir}/";
	$story->{url} = "${url}story/$story->{sid}";

	$story->{tid} = $S->{TOPIC_DATA}->{ $story->{tid} }->{alttext};
	$story->{section} = $S->{SECTION_DATA}->{ $story->{section} }->{title};

	# fix up the introtext
	# Replace hrefs with plaintext
	$story->{introtext} =~ s/<A\s+HREF\s*=\s*['"]([^'"]*?)['"]\s*>\s*(.*?)\s*<\/A>/$2 [$1]/gi;

	$story->{introtext} =~ s/[\n\r]/ /g;
	$story->{introtext} =~ s/<P>/\n\n/g;
	$story->{introtext} =~ s/<BR>/\n/g;
	$story->{introtext} =~ s/<.*?>//g;

	require Text::Wrap;
	$Text::Wrap::columns = 75;
	$story->{introtext} = Text::Wrap::wrap('', '', $story->{introtext});

	$story->{aid} = $story->{nick};

	foreach my $key (keys %{$story}) {
		my $find = "%%${key}%%";
		$story_template =~ s/$find/$story->{$key}/g;
	}

	return $story_template;
}

sub _cron_digest_send_email {
	my $S = shift;
	my ($user, $data) = @_;
	my $nick = $S->get_nick_from_uid($user->{uid});
	
	my $email_header = $S->{UI}->{BLOCKS}->{digest_header} || $S->{UI}->{BLOCKS}->{digest_headerfooter};
	my $email_footer = $S->{UI}->{BLOCKS}->{digest_footer} || $S->{UI}->{BLOCKS}->{digest_headerfooter};

	$email_header =~ s/%%FREQUENCY%%/$user->{freq}/g;
	$email_header =~ s/%%USERID%%/$user->{uid}/g;
	$email_header =~ s/%%NICKNAME%%/$nick/g;
	$email_footer =~ s/%%FREQUENCY%%/$user->{freq}/g;
	$email_footer =~ s/%%USERID%%/$user->{uid}/g;
	$email_footer =~ s/%%NICKNAME%%/$nick/g;

	return unless $data->{ $user->{freq} };

	my $mail = join("", $email_header, $data->{ $user->{freq} }, "\n\n", $email_footer);

	if ($mail) {  # if the body is empty, for some reason, don't send
		my $ret = $S->mail($user->{email}, $S->{UI}->{BLOCKS}->{digest_subject}, $mail);
		return 1 if $ret == 1;
		return "couldn't send digest for $user->{email}";
	}
}

=back

=cut

1;
