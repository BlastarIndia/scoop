package Scoop;
use strict;


sub edit_topics {
	my $S = shift;
	my $update = $S->{CGI}->param('update');

	my $error;
	if ($update eq 'Write') {
		if ($S->{CGI}->param('delete')) {
			my $rv = $S->delete_topic;
			my $badtid = $S->{CGI}->param('tid');
			unless ($rv) {
				$error = qq|<b>Error! While Deleting Topic "$badtid"</b>|;
			}
		} else {
			my $rv = $S->write_topic;
			$error = qq|<b>$rv</b>| if $rv;
		}
	}

	my $content = qq|
	<table border="0" cellpadding="0" cellspacing="0" width="100%">|;

	my $editform = $S->topic_form;

	$content .= qq|
		<tr>
		<td colspan="2" bgcolor="%%title_bgcolor%%">%%title_font%%<b>Edit Topics</b>%%title_font_end%%</td>
		</tr>
		<tr>
		<td colspan="2">%%norm_font%%$error%%norm_font_end%%</td></tr>
		<tr>
			<td valign="top">$editform</td>
			<td valign="top">|;
	
	$content .= qq|
		<table border="0" cellpadding"3" align="center">
		<tr>|;
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'topics',
		ORDER_BY => 'tid asc'
	});

	my $i = 0;
	if ($rv ne '0E0') {
		while (my $topic = $sth->fetchrow_hashref) {
			unless ($topic->{tid}) {
				$topic->{tid} = "New";
			}
			# url escape the links to the tid
			my $tidlink = $S->urlify($topic->{tid});

			$content .= qq|
			<td align="center">
				<a href="%%rootdir%%/?op=admin;tool=topics;tid=$tidlink"><img src="%%imagedir%%%%topics%%/$topic->{image}" border="0" height="$topic->{height}" width="$topic->{width}" alt="$topic->{alttext}"><br>$topic->{tid}</a>
			</td>
			|;
			$i++;
			if (($i % 3) == 0) {
				$content .= qq|
					</tr><tr>|;
			}
		}
	}
	$sth->finish;
	
	$content .= qq|
		</tr></table></td></tr>|;
	$content .= qq|
		</table></form>|;
	
	return $content;
}

sub topic_form {
	my $S = shift;
	my $new = 0;
	my $tid = $S->{CGI}->param('tid');
	my $tidold = $tid;

	if ($tid eq 'New') {
		$tid = '';
	}

	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'topics',
		WHERE => qq|tid = '$tid'|
	});
	my $topic = $sth->fetchrow_hashref;
	$sth->finish;

	if ($rv == 0) {
		$topic = {
			width   => ($S->{CGI}->param('width'  ) || ''),
			height  => ($S->{CGI}->param('height' ) || ''),
			alttext => ($S->{CGI}->param('alttext') || ''),
			image   => ($S->{CGI}->param('image'  ) || '')
		};
		$new = 1;
		$tidold = '';
 	}

	my $form = qq|
		%%norm_font%%
		<form name="edittopics" action="%%rootdir%%/" method="POST">
		<input type="hidden" name="op" value="admin" />
		<input type="hidden" name="tool" value="topics" />
		<input type="hidden" name="tidold" value="$tidold" />
		TID:<br />
		<input type="text" name="tid" value="$tid" maxlength="20" /><br />
		Dimensions (w x h)<br />
		<input type="text" name="width" value="$topic->{width}" size="4" maxlength="11" />
		<input type="text" name="height" value="$topic->{height}" size="4" maxlength="11" /><br />
		Alt Text<br />
		<input type="text" name="alttext" value="$topic->{alttext}" maxlength="40" /><br />
		Image Name<br />
		<input type="text" name="image" value="$topic->{image}" maxlength="30" /><br />|;

	unless ($new) {
		$form .= qq|
			<hr align="left" width="50%" noshade="noshade" />
			Delete? <input type="checkbox" name="delete" value="1" /><br />
			Tid to move stories posted under "$tid" to on delete:<br />|;

		my $options = $S->_make_topic_optionlist($tid);
		$form .= qq| <select name="changeto_tid">
				$options
				</select><br />
				<hr align="left" width="50%" noshade="noshade"/><br />|;
	}

	$form .= qq|
		<input type="submit" name="update" value="Write" />
		%%norm_font_end%%</form>|;

	return $form;
}


#
# This deletes the topic and changes all stories under that
# topic to be under topic "All".  In the future may get this 
# dynamically
sub delete_topic {
	my $S = shift;

	my $params = $S->{CGI}->Vars;
	my ($rv, $sth);

	# first make sure all the data matches, if it doesn't
	# return 0 for error.
	($rv, $sth) = $S->db_select({
		DEBUG	=> 0,
		FROM 	=> 'topics',
		WHAT	=> 'tid',
		WHERE	=> qq| tid='$params->{tid}' AND image='$params->{image}' AND alttext='$params->{alttext}' AND width='$params->{width}' AND height='$params->{height}'|,
	});
	$sth->finish;

	unless($rv == 1) {
		return 0;
	}

	# Since the topic exists, lets delete it!
	($rv, $sth) = $S->db_delete({
		DEBUG	=> 0,
		FROM	=> 'topics',
		WHERE	=> qq| tid='$params->{tid}' |,
	});

	# Don't forget to update the stories table!
	($rv, $sth)= $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'stories',
		SET	=> qq| tid='$params->{changeto_tid}' |,
		WHERE	=> qq| tid='$params->{tid}' |,
	});
	$sth->finish;

	# Update the cache
	$S->cache->clear({resource => 'topics', element => 'TOPICS'});
	$S->cache->stamp_cache('topics', time());
	$S->_load_topic_data();

	return 1;
}

sub write_topic {
	my $S = shift;
	my $params = $S->{CGI}->Vars;
	my ($rv, $sth);

	# check the topic to make sure it's defined and valid
	return "Please choose a TID for the topic." unless $params->{tid};
	if ($params->{tid} =~ /[^-_\w]/) {
		return "TIDs can only contain alphanumeric characters, dashes, and underscores."
	}
	# make sure they entered some alttext
	return "Please enter some alt text for this topic." unless $params->{alttext};
	# check width and height to make sure they're numbers (if defined)
	if (($params->{width}  && $params->{width}  =~ /\D/) ||
	    ($params->{height} && $params->{height} =~ /\D/)) {
		return "Width and Height must be numbers."
	}

	# put together the data that we have
	my %data = (tid => $params->{tid}, alttext => $params->{alttext});
	$data{image} = $params->{image} if $params->{image};
	if ($params->{height} && $params->{width}) {
		$data{height} = $params->{height};
		$data{width}  = $params->{width};
	}

	if ($params->{tidold} eq 'New' || $params->{tidold} eq '' || $params->{tidold} ne $params->{tid}) {
		# prepares for insert, including quoting
		my $cols   = join(', ', keys %data);
		my $values = join(', ', map { $S->dbh->quote($_) } values %data);

		($rv, $sth) = $S->db_insert({
			INTO => 'topics',
			COLS => $cols,
			VALUES => $values
		});
	} else {
		# puts together a string for update, including quoting the data
		my $set = join(', ', 
			map { "$_ = " . $S->dbh->quote($data{$_}) } keys %data
		);
		my $q_tid = $S->dbh->quote($params->{tid});

		($rv, $sth) = $S->db_update({
			WHAT => 'topics',
			SET => $set,
			WHERE => qq|tid = $q_tid|
		});
	}
	$sth->finish;

	# Update the DB cache
	$S->cache->remove('topics');
	$S->cache->stamp('topics');
	$S->_load_topic_data();

	if ($rv) {
		return 0;
	} else {
		return "Error accessing DB: " . $S->{DBH}->errstr;
	}
}

sub _make_topic_optionlist {
	my $S = shift;
	my $tid_to_del = shift;
	my $list = "";

	my ($rv, $sth) = $S->db_select({ 
		DEBUG	=> 0,
		WHAT	=> 'tid',
		FROM 	=> 'topics',
	});

	if( $rv ){
		my $topic;
		while( $topic = $sth->fetchrow_hashref ) {
			next if ($topic->{tid} eq $tid_to_del);
			$list .= qq|
					<option value="$topic->{tid}">$topic->{tid}</option>|;
		}
	}
	$sth->finish;

	return $list;
}

1;
