package Scoop;
use strict;
my $DEBUG = 0;

=pod

=head1 Admin/Calendar.pm

This is the admin tool in which calendars and events can be managed. For the
user portion of the event calendar feature, see Calendar.pm and the Calendar/
directory.

=over 4

=item $S->admin_calendars()

The main function that co-ordinates all of the calendar-related admin stuff.

=back

=cut

sub admin_calendars {
	my $S = shift;
	my $content = $S->{UI}->{BLOCKS}->{admin_calendar_main};
	my $keys; #hashref for interpolate()
	my $item = $S->cgi->param('item') || 'list';
	warn "(admin_calendars) starting calendar admin tool $item" if $DEBUG;

	if ( $item eq 'eventproperties' ) {
		$keys->{calendar_form} = $S->admin_event_properties();
	} elsif ( $item eq 'eventlist' ) {
		$keys->{calendar_form} = $S->admin_event_list();
	} elsif ( $item eq 'list' ) {
		$keys->{calendar_form} = $S->admin_calendar_list();
	}

	return $S->interpolate($content,$keys);
}

=over 4

=item $S->admin_event_properties()

The event properties management form

=back

=cut

sub admin_event_properties {
	my $S = shift;
	my $msg;

	warn "(admin_event_properties) Starting..." if $DEBUG;
	# check if we need to write the info, and write it
	if ( $S->cgi->param('write') ) {
		$msg = $S->_write_event_property();
		warn "(admin_event_properties) Wrote changes" if $DEBUG;
	}

	# display the form
	my $content = $S->{UI}->{BLOCKS}->{admin_event_properties};
	my $keys; # keys hash for later interpolation
	my $id = $S->cgi->param('id');
	my $propertyid = $S->cgi->param('property');
	my $get = $S->cgi->param('get'); # fresh property fetch from db
	my $delete = $S->cgi->param('delete');
	my $write = $S->cgi->param('write');

	if ( $id eq '' && $write ) {
		$id = $propertyid; 
		# we've just saved a new item, so let's make sure to load it
	}
	warn "(admin_event_properties) Getting form data for $id" if $DEBUG;
	my $event_properties = $S->_get_event_property($id);
	# now to fill up the keys hash
	$keys->{admin_events_errormsg} = $msg;
	$keys->{admin_events_property_menu} = $S->_event_property_list('id',$id);
	$keys->{admin_events_delete_check} = $id ? qq{\n<input type="checkbox" name="delete" value="1" /> Delete this event property} : '';
	unless ($delete) {
		$keys->{admin_events_property} = $id;
		my @items = qw(title description template calendar_template display_order requires regex);
		map { $keys->{"admin_events_$_"} = $S->admin_display_filter($event_properties->{$_},$get) } (@items);

		$keys->{admin_events_field_list} = $S->_event_field_list($event_properties->{field});
		$keys->{admin_events_field_edit} = ( $event_properties->{field} ) ? qq|[<A href="%%rootdir%%/admin/blocks/edit/default/$event_properties->{field}">edit</A>]| : '';
		$keys->{admin_events_requires_menu} = $S->_event_property_list('requires',$event_properties->{requires});

		$keys->{admin_events_enabled_checked} = $event_properties->{enabled} ? ' CHECKED' : '';
		$keys->{admin_events_required_checked} = $event_properties->{required} ? ' CHECKED' : '';
		$keys->{admin_events_html_checked} = $event_properties->{html} ? ' CHECKED' : '';
		$keys->{admin_events_is_date_checked} = $event_properties->{is_date} ? ' CHECKED' : '';
		$keys->{admin_events_is_time_checked} = $event_properties->{is_time} ? ' CHECKED' : '';
	}

	warn "(admin_event_properties) Done" if $DEBUG;
	return $S->interpolate($content, $keys);
}

=over 4

=item $S->admin_event_list()

The global event list for all calendars

=back

=cut

sub admin_event_list {
	my $S = shift;
	my $content = $S->{UI}->{BLOCKS}->{admin_event_list};
	my $keys;
	my $page = $S->cgi->param('page') || 1;
	my $num = $S->var('storylist');
	my $offset = ( ($page-1) * $num );
	$keys->{nextpage} = $page + 1;
	$keys->{prevpage} = $page - 1;
	warn "(admin_event_list) Starting..." if $DEBUG;

	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'eid',
		FROM => 'events',
		ORDER_BY => 'date_start DESC',
		LIMIT => $num + 1,
		OFFSET => $offset
	});
	my $eids;
	while ( my ($eid) = $sth->fetchrow_array() ) {
		push @$eids, $eid;
	}
	warn "(admin_event_list) getting page $page: events @$eids" if ($eids && $DEBUG);
	# next/prev stuff here
	if ( $rv > $num ) {
		$keys->{nextlink} = $S->{UI}->{BLOCKS}->{next_page_link};
		$keys->{nextlink} =~ s/%%maxstories%%/$num/;
		$keys->{nextlink} =~ s/%%LINK%%/?page=$keys->{nextpage}/;
		pop @$eids;
		# db fetched one more record than we needed, to determine if we want the next page link or not
		# so remove that last record so it doesn't get displayed
	}
	if ( $page > 1 ) {
		$keys->{prevlink} = $S->{UI}->{BLOCKS}->{prev_page_link};
		$keys->{prevlink} =~ s/%%maxstories%%/$num/;
		$keys->{prevlink} =~ s/%%LINK%%/?page=$keys->{prevpage}/;
	}

	$S->get_event($eids);
	# this gets all the events in the cache in one fell swoop
	# so we don't need to hit the db once per event in the loop below
	my $bg;
	foreach ( @$eids ) {
		my $event = $S->get_event($_);
		warn "(admin_event_list) processing event $_ ($event->{title})" if $DEBUG;
		$event->{owner_nick} = $S->get_nick_from_uid($event->{owner});
		$bg = ($bg) ? '' : $S->{UI}->{BLOCKS}->{story_mod_bg};
		$event->{rowbg} = $bg;

		foreach ( @{$event->{cals}} ) {
			# all of the calendars this event is filed in
			my $cal = $S->{CALENDARS}->{$_};
			warn "(admin_event_list) getting info for calendar $_ ($cal->{title})" if $DEBUG;
			$cal->{owner_nick} = $S->get_nick_from_uid($cal->{owner});
			$cal->{cal_id} = $_;
			$cal->{primary_marker} = ( $_ eq $event->{cal_id} ) ? $S->{UI}->{BLOCKS}->{primary_calendar_marker} : '';
			$event->{cal_list} .= $S->interpolate($S->{UI}->{BLOCKS}->{admin_event_list_item_cals},$cal);
		}

		my $item = $S->{UI}->{BLOCKS}->{admin_event_list_item};
		$item =~ s/%%cal_list%%/$event->{cal_list}/g; 
			# because I want the contents of this to have access to the keys
		$keys->{list} .= $S->interpolate($item,$event);
	}

	return $S->interpolate($content, $keys);
}

=over 4

=item $S->admin_calendar_list()

The list of calendars. This is where site-wide calendars can be created, and
any calendar can be deleted.

=back

=cut

sub admin_calendar_list {
	my $S = shift;
	my $content = $S->{UI}->{BLOCKS}->{admin_calendar_list};
	my $keys;
	warn "(admin_calendar_list) Starting..." if $DEBUG;
	my $delete = $S->cgi->param('delete');
	my $create = $S->cgi->param('create');

	# handle calendar delete
	if ( $delete ) {
		$keys->{msg} = $S->_delete_calendar($delete);
	}

	# handle calendar create
	if ( $create ) {
		$keys->{msg} = $S->_create_sitewide_calendar();
	}

	# display calendars/calendar data
	foreach ( sort {$a <=> $b} keys %{$S->{CALENDARS}} ) {
		my $line = $S->{UI}->{BLOCKS}->{admin_calendar_list_item};
		my $cal = $S->{CALENDARS}->{$_};
		warn "(admin_calendar_list) displaying calendar $_ ($cal->{title})" if $DEBUG;
		$cal->{owner_nick} = $S->get_nick_from_uid($cal->{owner});
		$keys->{calendar_list_rows} .= $S->interpolate($line,$cal);
	}
	warn "(admin_calendar_list) done." if $DEBUG;
	return $S->interpolate($content,$keys);
}

=head1 Internal Functions

=over 4

=item $S->_write_event_property()

=back

=cut

sub _write_event_property {
	my $S = shift;
	my $delete = $S->cgi->param('delete');
	my $id = $S->cgi->param('id');
	my $property = $S->cgi->param('property');
	my $return;

	my @fields = qw(property title field display_order description enabled required is_date is_time template calendar_template html regex requires);

	warn "(_write_event_property) Filtering data" if $DEBUG;
	my %data;
	map { $data{$_} = $S->admin_save_filter($S->cgi->param($_)) } (@fields);

	# mangle the display_order
	$S->_event_display_order($S->cgi->param('property'),$S->cgi->param('display_order'));
	
	my ($rv, $sth);

	if ( ($id eq $property) && !$delete ) {
		# update existing item, no delete
		warn "(_write_event_property) Updating existing item $property" if $DEBUG;
		my $set;
		map { $set .= "$_ = $data{$_}, " } ( keys %data );
		$set =~ s/, $//;
		($rv, $sth) = $S->db_update({
			WHAT => 'event_property_items',
			SET => $set,
			WHERE => qq|property = $data{property}|
		});
		$return = "$property updated" if $rv;
	} elsif ( ($id eq $property) && $delete ) {
		# delete item
		warn "(_write_event_property) Deleting item $property" if $DEBUG;
		$rv = 1;
		$return = 'delete function not written yet';
	} else {
		# new item
		warn "(_write_event_property) Saving new item $property" if $DEBUG;
		my ($cols,$values);
		foreach ( @fields ) {
			$cols .= ", $_";
			$values .= ", $data{$_}";
		}
		$cols =~ s/^, //;
		$values =~ s/^, //;
		($rv, $sth) = $S->db_insert({
			DEBUG => $DEBUG,
			INTO => 'event_property_items',
			COLS => $cols,
			VALUES => $values
		});
		$return = "$property saved" if $rv;
	}

	if ($rv) {
		# tell the cache about the new value
		$S->cache->remove('events');
		$S->cache->stamp('events', time(), 1);
		delete($S->{EVENT_PROPERTIES});
		$S->_load_event_properties_data();
		return $return;
	}
	my $err = $S->dbh->errstr;
	return "Error updating $data{title}. DB said: $err";

}

=over 4

=item $S->_event_display_order($property, $display_order)

Moves all the event properties below the current one down a notch if the
current one conflicts in display_order

=back

=cut

sub _event_display_order {
	my $S = shift;
	my $property = shift;
	my $display_order = shift;

	my $q_property = $S->dbh->quote($property);
	my $q_order = $S->dbh->quote($display_order);

	# check to see if there's an event property already using this display order
	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => '*',
		FROM => 'event_property_items',
		WHERE => "property != $q_property AND display_order = $q_order"
	});
	return if ( $rv == 0 );

	# ok, something has the same display_order and it isn't the one being saved...
	($rv,$sth) = $S->db_update({
		DEBUG => $DEBUG,
		WHAT => 'event_property_items',
		SET => 'display_order = display_order + 1',
		WHERE => "display_order >= $q_order"
	});

	return;
}

=over 4

=item $S->_get_event_property()

=back

=cut

sub _get_event_property {
	my $S = shift;
	my $id = shift;
	return unless $id;

	my $property	= $S->cgi->param('property');
	my $get		= $S->cgi->param('get');

	if ( $property && !$get ) {
		# if we have cgi parameters and aren't specifically requesting a new item
		warn "(_get_event_property) ... from cgi parameters" if $DEBUG;
		return $S->cgi->Vars_cloned;
	} elsif ( $S->{EVENT_PROPERTIES}->{$id} ) {
		# look in the cache
		warn "(_get_event_property) ... from the cache" if $DEBUG;
		return $S->{EVENT_PROPERTIES}->{$id};
	} else {
		# hit the db last
		warn "(_get_event_property) ... from the db" if $DEBUG;
		my $q_id = $S->dbh->quote($id);
		my ($rv, $sth) = $S->db_select({
			WHAT => '*',
			FROM => 'event_property_items',
			WHERE => qq|property = $q_id|
			});
		my $item = $sth->fetchrow_hashref();
		$sth->finish;
		return $item;
	}

}

=over 4

=item $S->_event_property_list($name,$id)

=back

=cut


sub _event_property_list {
	my $S = shift;
	my $name = shift;
	my $id = shift;

	my $selected = $id ? '' : ' SELECTED';
	my $out = qq{
		<select name="$name" size="1">
		<option value=""$selected>------</option>};

	$S->_load_event_properties_data() unless $S->{EVENT_PROPERTIES};
	my %properties = %{$S->{EVENT_PROPERTIES}};
	foreach my $prop (sort keys %properties) {
		my $property_data = $properties{$prop};

		next if ( ($prop eq $id) && $S->cgi->param('delete') );

		$selected = ($prop eq $id) ? ' SELECTED' : '';
		$property_data->{property} =~ s/"/&quot;/g;

		$out .= qq|
		<option value="$property_data->{property}"$selected>$property_data->{property}</option>|;
	}

	$out .= qq{
		</select>};

	return $out;
}

=over 4

=item $S->_event_field_list($blockname)

=back

=cut

sub _event_field_list {
	my $S = shift;
	my $block = shift;
	my $selected = ' SELECTED' unless $block;
	my $out = qq{
		<select name="field" size="1">
		<option value=""$selected>Select field type</option>};

	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'bid',
		FROM => 'blocks',
		WHERE => q{bid LIKE 'event_property_%'},
		ORDER_BY => 'bid'
	});
	while ( my ($bid) = $sth->fetchrow_array() ) {
		$selected = ( $block eq $bid ) ? ' SELECTED' : '';
		$out .= qq{
		<option value="$bid"$selected>$bid</option>};
	}
	$out .= qq{
		</select>};

	return $out;
}

=over 4

=item $S->_delete_calendar($cal_id)

=back

=cut

sub _delete_calendar {
	my $S = shift;
	my $cal_id = shift;
	my $msg;
	my $title = $S->{CALENDARS}->{$cal_id}->{title};
	warn " (_delete_calendar) removing calendar $cal_id ($title)" if $DEBUG;

	# the entries in calendar_link so references to this calendar don't show up
	my ($rv,$sth) = $S->db_delete({
		DEBUG => $DEBUG,
		FROM => 'calendar_link',
		WHERE => "cal_id = $cal_id"
	});
	# subscription info
	($rv,$sth) = $S->db_delete({
		DEBUG => $DEBUG,
		FROM => 'userprefs',
		WHERE => "prefname LIKE 'calendar_$cal_id%'"
	});
	# the calendar itself
	($rv,$sth) = $S->db_delete({
		DEBUG => $DEBUG,
		FROM => 'calendars',
		WHERE => qq|cal_id = $cal_id|,
	});
	$S->cache->remove('calendars');
	$S->cache->stamp('calendars');
	delete $S->{CALENDARS};

	if ($rv == 1) {
		$msg = "calendar $title deleted";
	} else {
		$msg = 'error deleting calendar! db said: ' . $S->dbh->errstr();
	}

	$sth->finish();
	$S->_load_calendar_data();
	return $msg;
}

=over 4

=item $S->_create_sitewide_calendar()

=back

=cut

sub _create_sitewide_calendar {
	my $S = shift;
	my $title = $S->dbh->quote($S->cgi->param('title'));
	my $view = $S->dbh->quote($S->cgi->param('public_view'));
	my $submit = $S->dbh->quote($S->cgi->param('public_submit'));
	my $msg;

	warn " (_create_sitewide_calendar) new calendar $title" if $DEBUG;

	my ($rv,$sth) = $S->db_insert({
		DEBUG => $DEBUG,
		INTO => 'calendars',
		COLS => 'cal_id,title,owner,public_view,public_submit',
		VALUES => qq|NULL, $title, '0', $view, $submit|
	});
	if ( $rv == 1 ) {
		$msg = "created calendar $title";
		my $new_id = $S->dbh->{'mysql_insertid'};
		$S->run_hook('calendar_new',$S->{UID},$new_id);
		$S->cache->remove('calendars');
		$S->cache->stamp('calendars');
		delete $S->{CALENDARS};
		$S->_load_calendar_data();
		# goddamn cache
	} else {
		$msg = "error creating calendar! database said: " . $S->dbh->errstr();
	}

	return $msg;
}


1;
