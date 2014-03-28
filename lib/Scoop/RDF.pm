=head1 RDF.pm

Most functions involved in displaying external news feeds are in this module.
Other items related to RDF's, such as generating them and Forumzilla support,
are elsewhere (see cron scripts for the former, and L<Scoop::ForumZilla> for
the latter). Currently, all functions are kept in one file, but may be split
off at a later time.

=head1 Functions

=over 4

=cut

package Scoop;
use LWP::UserAgent;
use HTTP::Request;
use XML::RSS;
use strict;


=item * rdf_channels([channel])

Returns information of RDF channels, either as an array ref of all of them (no
args passed), or on just one channel (the one specified as an arg). Each row is
returned as a hash, with the following keys:

rid, rdf_link, link, title, description, image_title, image_url, image_link,
form_title, form_description, form_name, form_link, enabled, submitted,
submittor

=cut

sub rdf_channels {
	my $S = shift;
	my $channel = shift;    # if not defined, then array returned
	my $sub_first = shift;  # if set, then submitted by not approved feeds will
	                        # be returned first

	if ($channel) {
		my ($rv, $sth) = $S->db_select({
			WHAT  => '*',
			FROM  => 'rdf_channels',
			WHERE => qq|rid = '$channel'|
		});
		my $row = $sth->fetchrow_hashref();
		$sth->finish;
		return $row;
	} else {
		my $order = $sub_first ? 'submitted DESC, title ASC' : 'title ASC';
		my ($rv, $sth) = $S->db_select({
			WHAT => '*',
			FROM => 'rdf_channels',
			ORDER_BY => $order
		});
		my $data = [];
		while (my $row = $sth->fetchrow_hashref) {
			push(@{$data}, $row);
		}
		$sth->finish;
		return $data;
	}
}

=item * rdf_items(channel, [limit])

Returns a list of items under channel, or max B<limit> if it is specified.
Each row is a hash ref, with the following keys:

rid, idx, title, link, description

=cut

sub rdf_items {
	my $S = shift;
	my $channel = shift || return;;    # required
	my $limit = shift;      # optional, by default gets all

	my $select = {
		WHAT     => '*',
		FROM     => 'rdf_items',
		WHERE    => qq|rid = '$channel'|,
		ORDER_BY => 'idx ASC'
	};
	$select->{LIMIT} = $limit if $limit;
	my ($rv, $sth) = $S->db_select($select);

	my $data;
	while (my $row = $sth->fetchrow_hashref) {
		push(@{$data}, $row);
	}
	$sth->finish;

	return $data;
}

=item * rdf_add_channel(link, [fetch])

Adds a channel to the db, with an RDF file at B<link>. By default, that's all
this function will do, and the RDF won't be fetched and parsed until the cron
job runs again. However, if B<fetch> is true, then C<rdf_fetch_and_store>
will be called to fetch and parse the RDF.

=cut

sub rdf_add_channel {
	my $S = shift;
	my $link = shift || return;
	my $fetch = shift || 0;
	my $submit = shift;

	# note that, by default, all this method does is put the link in the db so
	# that it will be fetched next time rdf_fetch.pl is run
	my $cols= 'rid,rdf_link,submitted,submittor';

	my $values = "NULL,'$link'";
	$values .= $submit ? ",1, ".$S->{DBH}->quote($submit) : ',0, NULL';
	my ($rv, $sth) = $S->db_insert({
		INTO   => 'rdf_channels',
		COLS   => $cols,
		VALUES => $values
	});
	my $id = $sth->{'mysql_insertid'};
	$sth->finish;

	# if $fetch is true, then we will also call rdf_fetch_and_store, so that
	# there is data in the db
	my $res = $S->rdf_fetch_and_store($link, $id) if $fetch;

	return (wantarray ? ($id, $res) : $id);
}

=item * rdf_fetch_and_store(link, id)

Fetches the RDF at B<link> using LWP::Simple, and parses it with XML::RSS, then
stores the channel data and items under B<id> in the database.

=cut

sub rdf_fetch_and_store {
	my $S = shift;
	my $link = shift || return;
	my $id = shift || return;

	# fetch the RDF...
	my $req = HTTP::Request->new('GET', $link);
	my $ua  = LWP::UserAgent->new;
	my $scoop_version = $S->_rdf_get_version();
	$ua->agent("ScoopRDF/$scoop_version");

	my $proxy = $S->{UI}->{VARS}->{rdf_http_proxy};
	$ua->proxy(http => $proxy) if $proxy;
	
	my $timeout = $S->{UI}->{VARS}->{rdf_fetch_timeout} || '60';
	$ua->timeout($timeout);
	
	my $page;
	my $res = $ua->request($req);
	if ($res->is_success) {
		$page = $res->content;
	} else {
		return "error fetching RDF: " . $res->status_line;
	}

	# ...and parse it
	my $rss = XML::RSS->new;
	eval { $rss->parse($page) };
	if (my $err = $@) {
		$err =~ s/ at\s.*$//;
		$err =~ s/\n//g;
		return "error parsing: $err";
	}

	# first, a quick hack for those sites that put their name together with a
	# slogan
	($rss->{channel}->{title}) = split(/: /, $rss->{channel}->{title});

	# now update the channel data
	$S->_rdf_update_channel_data($id, $rss);

	# clear out the old items
	$S->rdf_delete_items($id);

	# finally, put in the new items
	my $index = 0;
	foreach my $i (@{ $rss->{items} }) {
		my $values;
		# escape the various data fields so they can't be abused
		$i->{title}       = $S->filter_subject($i->{title});
		$i->{description} = $S->filter_subject($i->{description});
		$i->{link}        = $S->filter_subject($i->{link});
		# now escape for placing in the db
		foreach my $p ($id,$index,$i->{title}, $i->{link}, $i->{description}) {
			$values .= $S->{DBH}->quote($p) . ",";
		}
		chop($values);   # remove extra comma
		my ($rv, $sth) = $S->db_insert({
			INTO   => 'rdf_items',
			COLS   => 'rid,idx,title,link,description',
			VALUES => $values
		});
		$sth->finish;
		$index++;
	}

	return 1;
}

sub _rdf_get_version {
	my $S = shift;

	my $ver = $S->{UI}->{VARS}->{SCOOP_VERSION};
	$ver =~ s/^scoop-//;  # takes it down to something like 0_7-dev
	$ver =~ s/_/./g;      # changes to 0.7-dev

	return $ver;
}

sub _rdf_update_channel_data {
	my $S = shift;
	my $id = shift;
	my $rss = shift;

	my %channel_data = (
		title            => $rss->{channel}->{title},
		link             => $rss->{channel}->{link},
		description      => $rss->{channel}->{description},
		image_title      => $rss->{image}->{title},
		image_url        => $rss->{image}->{url},
		image_link       => $rss->{image}->{link},
		form_title       => $rss->{textinput}->{title},
		form_description => $rss->{textinput}->{description},
		form_name        => $rss->{textinput}->{name},
		form_link        => $rss->{textinput}->{link}
	);
	my $update_set;
	while (my($k,$v) = each %channel_data) {
		$v = $S->filter_subject($v);
		$update_set .= " $k = " . $S->{DBH}->quote($v) . ",";
	}
	chop($update_set);  # remove the trailing comma
	my ($rv, $sth) = $S->db_update({
		WHAT  => 'rdf_channels',
		SET   => $update_set,
		WHERE => qq|rid = $id|
	});
	$sth->finish;
}

=item * rdf_delete_items(id)

Takes a channel id (B<id>) and removes all of the items associated with that
channel.

=cut

sub rdf_delete_items {
	my $S = shift;
	my $id = shift || return;

	my ($rv, $sth) = $S->db_delete({
		FROM  => 'rdf_items',
		WHERE => qq|rid = $id|
	});
	$sth->finish;
	
	return 1;
}

=item * rdf_change_enabled (id, value)

Changes the enabled flag on a channel (B<id>) to B<value>, which should be
either 1 or 0.

=cut

sub rdf_change_enabled {
	my $S = shift;
	my $rid = shift;
	my $newval = shift;

	return unless defined($rid) && defined($newval);

	my ($rv, $sth) = $S->db_update({
		WHAT  => 'rdf_channels',
		SET   => "enabled = $newval",
		WHERE => "rid = $rid"
	});
	$sth->finish;
}

=item * rdf_approve(id)

Updates the channel B<id> so that it is no longer submitted, and can therefore
be used (that is, if it's enabled).

=cut

sub rdf_approve {
	my $S = shift;
	my $rid = shift;

	return unless defined($rid);

	my ($rv, $sth) = $S->db_update({
		WHAT  => 'rdf_channels',
		SET   => 'submitted = 0',
		WHERE => "rid = $rid"
	});
	$sth->finish;
}

=item * rdf_remove_channel(id)

Removes channel B<id> completly, and all the items associated with it.

=cut

sub rdf_remove_channel {
	my $S = shift;
	my $id = shift || return;

	# remove old items first
	$S->rdf_delete_items($id);

	# then remove the channel info
	my ($rv, $sth) = $S->db_delete({
		FROM  => 'rdf_channels',
		WHERE => qq|rid = $id|
	});
	$sth->finish;

	return 1;
}

=item * edit_rdfs

Basis of the RDF admin tool. This function serves only to call two other
functions, and return their results. Note that I didn't choose to do it this
way, I just did it the same way all the other admin tools are done. All I want
is for my poor baby to fit in. Is that to much to ask?

=cut

sub edit_rdfs {
	my $S = shift;
	my $msg = $S->_write_rdfs();
	my $form = $S->_get_rdf_form($msg);
	return $form;
}

sub _write_rdfs {
	my $S = shift;

	return unless $S->{CGI}->param('write');
	return "Permission Denied" unless $S->have_perm('rdf_admin');

	my $action = $S->{CGI}->param('action');
	if ($action eq 'add') {
		my $link = $S->{CGI}->param('link');
		return "You must specify a URL in order to add a channel" unless $link;
		# decide if we're allowed to fetch the RDF when we add it
		my $do_fetch = $S->{UI}->{VARS}->{allow_rdf_fetch} ? 1 : 0;
		$S->rdf_add_channel($link, $do_fetch) || return "Error fetching RDF";
		return "RDF Added";
	} elsif (($action eq 'refetch') && (!$S->{UI}->{VARS}->{allow_rdf_fetch})) {
		# if fetch isn't allowed, let them know
		return "Fetching from within the admin interface has been disabled by the var 'allow_rdf_fetch'.";
	}

	# if it wasn't an add, then we have to check for multiple feeds being
	# selected
	my $error;
	my $channels = $S->rdf_channels();
	foreach my $c (@{$channels}) {
		next unless $S->{CGI}->param($c->{rid});
		if ($action eq 'delete') {
			$S->rdf_remove_channel($c->{rid});
		} elsif ($action eq 'refetch') {
			my ($id, $res) = $S->rdf_fetch_and_store($c->{rdf_link}, $c->{rid});
			$error = $id unless $id == 1;
		} elsif ($action eq 'blank') {
			$S->rdf_delete_items($c->{rid});
		} elsif ($action eq 'toggle') {
			my $changeto = ($c->{enabled} == 1) ? 0 : 1;
			$S->rdf_change_enabled($c->{rid}, $changeto);
		} elsif ($action eq 'approve') {
			$S->rdf_approve($c->{rid}) if $c->{submitted};
		}
	}

	return "Error doing $action: $error" if $error;
	return "Finished $action on selected feeds";
}

sub _get_rdf_form {
	my $S = shift;
	my $msg = shift;

	my $page = qq|
	<form action="%%rootdir%%/" method="POST">
	<input type="hidden" name="op" value="admin" />
	<input type="hidden" name="tool" value="rdf" />
	<table width="100%" border="0" cellpadding="0" cellspacing="0">
		<tr bgcolor="%%title_bgcolor%%">
			<td>%%title_font%%Edit RDF Feeds%%title_font_end%%</td>
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
				<td>%%norm_font%%<b>Site Title</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>RDF URL</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Submitter</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Enabled</b>%%norm_font_end%%</td>
			</tr>|;
	my $channels = $S->rdf_channels(undef, 1);
	foreach my $c (@{$channels}) {
		my $row_bg = $c->{submitted} ? 'bgcolor="%%submittedstory_bg%%"' : '';
		$page .= qq|
			<tr $row_bg>
				<td><input type="checkbox" name="$c->{rid}" value="1" /></td>
				<td>%%norm_font%%<a href="$c->{link}">$c->{title}</a>%%norm_font_end%%</td>
				<td>%%norm_font%%<a href="%%rootdir%%/?op=special;page=rdf_preview;rdf=$c->{rid}">$c->{rdf_link}</a>%%norm_font_end%%</td>
				<td>%%norm_font%%|;
		if ($c->{submittor}) {
			$page .= qq|<a href="%%rootdir%%/?op=user;tool=info;nick=$c->{submittor}">$c->{submittor}</a>|;
		} else {
			$page .= "<i>none</i>";
		}
		$page .= qq|%%norm_font_end%%</td>
				<td>%%norm_font%%|;
		$page .= ($c->{enabled} == 1) ? 'Yes' : 'No';
		$page .= qq|%%norm_font_end%%</td>
			</tr>|;
	}
	$page .= qq|
			</table>
			</td>
		</tr>
		<tr>
			<td><br />%%norm_font%%<b><a href="%%rootdir%%/?op=special;page=rdf_preview;rdf=all">Preview all Existing Feeds</a></b>%%norm_font_end%%</td>
		</tr>
		<tr>
			<td><br />%%norm_font%%<b>Add Feed:</b> <input type="text" name="link" size="50" /></td>
		</tr>
		<tr>
			<td>%%norm_font%%<b><br />Action:</b>
			<input type="radio" name="action" value="add" />Add 
			<input type="radio" name="action" value="delete" />Delete|;
	$page .= qq|
			<input type="radio" name="action" value="refetch" />Re-fetch|
			if $S->{UI}->{VARS}->{allow_rdf_fetch};
	$page .= qq|
			<input type="radio" name="action" value="blank" />Clear Listing
			<input type="radio" name="action" value="toggle" />Enable/Disable
			<input type="radio" name="action" value="approve" />Approve
			%%norm_font_end%%
			</td>
		</tr>
		<tr>
			<td>%%norm_font%%<br />
			<input type="submit" name="write" value="Save feeds" />
			<input type="reset" value="Reset" />
			%%norm_font_end%%</td>
		</tr>
	</table>
	</form>|;

	return $page;
}

=item * rdf_get_prefs(uid)

Returns the user preferences concerning RDF feeds for user B<uid>. This returns
a hash ref, with keys being RDF id's, and values being 1.

=cut

sub rdf_get_prefs {
	my $S = shift;
	my $uid = shift || $S->{UID};

	my ($rv, $sth) = $S->db_select({
		WHAT  => 'prefvalue',
		FROM  => 'userprefs',
		WHERE => qq|uid = $uid AND prefname = 'rdf_feeds'|
	});
	my ($feeds) = $sth->fetchrow_array();
	$sth->finish;
	return () unless $feeds;

	my $feeds_hash = {};
	foreach my $i (split(/,/, $feeds)) {
		$feeds_hash->{$i} = 1;
	}

	return $feeds_hash;
}

=item * rdf_set_prefs([uid], feeds)

If the first arg is B<feeds> (an array ref), then B<uid> is assumed to be the
current one. Otherwise, B<uid> must be specified first. The user's current
prefs regarding RDF feeds are wiped out and replaced with B<feeds>.

=cut

sub rdf_set_prefs {
	my $S = shift;
	my ($uid, $feeds);

	if (ref($_[0]) eq 'ARRAY') {
		$feeds = shift;
		$uid = $S->{UID};
	} else {
		$uid = shift;
		$feeds = shift;
	}
	my $to_insert = join(",", @{$feeds});

	my ($rv, $sth) = $S->db_delete({
		FROM  => 'userprefs',
		WHERE => qq|uid = $uid AND prefname = 'rdf_feeds'|
	});
	$sth->finish;

	($rv, $sth) = $S->db_insert({
		INTO   => 'userprefs',
		COLS   => 'uid, prefname, prefvalue',
		VALUES => qq|$uid, 'rdf_feeds', '$to_insert'|
	});
	$sth->finish;

	return 1;
}

=back

=cut

1;
