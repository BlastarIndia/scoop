package Scoop;
use strict;
my $DEBUG = 0;

=pod

=head1 Calendar.pm

Calendar.pm holds the main calendar and event related functions that are the
most generic.

See the other files in the Calendar/ directory for more.

=over 4

=item $S->display_calendar()

The function called by the calendar op; displays whichever calendar(s) are
requested.

=back

=cut

sub display_calendar {
	my $S = shift;
	my $view = $S->cgi->param('view') || $S->pref('calendar_view');
	my $cal_id = $S->cgi->param('calendar') || 'personal';
	my $uid = $S->cgi->param('uid') || $S->{UID};
	my $subscribe = $S->cgi->param('subscribe');
	my $content;

	$S->_calendar_subscribe() if $subscribe;

	# Get calendar info
	# First get list of calendar IDs to show - many if personal view
	# but only one if calendar id is a parameter
	my ($rv, $sth, $calendar, $cal_ids, $title);

	if ( $cal_id eq 'personal' && $S->var('allow_personal_calendar_view') && $S->have_perm('edit_own_calendar')) {
		$cal_ids = $S->_personal_calendar_list($uid);
		$title = $S->{UI}->{BLOCKS}->{personal_calendar_title};
		my $nick = $S->get_nick_from_uid($uid);
		$title =~ s/%%nick%%/$nick/;
	} elsif ( $cal_id && $cal_id ne 'personal' ) {
		$cal_ids->[0] = $cal_id;
		$title = $S->_calendar_title($cal_id);
	} else {
		$cal_ids->[0] = $S->var('default_calendar_id');
		$title = $S->_calendar_title($cal_ids->[0]);
	}
	my $view_cals = $S->_calendar_can_view($cal_ids);
	# Call the appropriate calendar display function based on the view parameter
	if ( $view_cals || ( $cal_id eq 'personal' && $S->var('allow_personal_calendar_view') ) ) {
		if ( $view eq 'monthly' ) {
			warn "(display_calendar) monthly view" if $DEBUG;
			$content = $S->calendar_monthly($view_cals, $title);
		} elsif ( $view eq 'weekly' ) {
			warn "(display_calendar) weekly view" if $DEBUG;
			$content = $S->calendar_weekly($view_cals, $title);
		} elsif ( $view eq 'daily' ) {
			warn "(display_calendar) daily view" if $DEBUG;
			$content = $S->calendar_daily($view_cals, $title);
		} else {
			# no view set - something is wrong
			warn "(display_calendar) no view set";
		}
	} else {
		# no calendars for us to view
		$content = $S->calendar_none();
	}

	$S->{UI}->{BLOCKS}->{CONTENT} = $content;
}

=over 4

=item $S->display_event()

The function called by the event op; displays whichever event is requested if
the user has permission to see it.

=back

=cut

sub display_event {
	my $S = shift;
	my $eid = $S->cgi->param('eid');
	my $view_eid = $S->_event_can_view([$eid]);
	my ($content,$keys);
	my ($rv,$sth);
	$content = $S->{UI}->{BLOCKS}->{event};
	my $q_eid = $S->dbh->quote($eid);

	my $subscribe = $S->cgi->param('subscribe');
	$S->_event_subscribe() if $subscribe;
	my $rsvp = $S->cgi->param('rsvp');
	$S->_event_rsvp() if $rsvp;

	if ( $view_eid ) {
		$keys = $S->get_event($view_eid->[0]);
		$keys->{calendar_title} = $S->_calendar_title($keys->{cal_id});
		$keys->{owner_nick} = $S->get_nick_from_uid($keys->{owner});
		warn "(display_event) event $view_eid->[0] is owned by $keys->{owner_nick}" if $DEBUG;

		foreach ( keys %{$S->{EVENT_PROPERTIES}} ) {
			next unless $keys->{$_};
			if ( $keys->{$_} eq '0000-00-00' && $S->{EVENT_PROPERTIES}->{$_}->{is_date} == 1 ) {
				delete $keys->{$_};
				next;
			}
			next unless $S->{EVENT_PROPERTIES}->{$_}->{template};
			warn "(display_event) formatting $_" if $DEBUG;
			my $template = $S->{EVENT_PROPERTIES}->{$_}->{template};
			warn "(display_event) $_ template is $template" if $DEBUG;
			$template =~ s/%%value%%/$keys->{$_}/g;
			$template =~ s/%%eid%%/$eid/g;
			warn "(display_event) $_ ($keys->{$_}) is $template" if $DEBUG;
			$keys->{$_} = $template;
		}

		# edit event link
		if ( $S->{UID} == $keys->{owner} || $S->have_perm('edit_event') ) {
			$keys->{edit_link} = qq|<A href="%%rootdir%%/submitevent/edit/$eid">[edit]</A>|;
		}

		# add/remove event from calendar
		my $my_cal = $S->user_calendar();
		warn "(display_event) current user's calendar is $my_cal" if $DEBUG;
		if ( $my_cal && $S->var('allow_user_calendars') ) {
			my $sub_eid = $keys->{parent} || $keys->{eid}; 
			my $q_sub_eid = $S->dbh->quote($sub_eid);
				# can't subscribe a child event, but can subscribe its parent...
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => '*',
				FROM => 'calendar_link',
				WHERE => qq|eid=$q_sub_eid AND cal_id=$my_cal|
			});
			if ( $rv == 1 ) {
				$keys->{add_cal_link} = qq|<A href="%%rootdir%%/editcalendar/addevent/$my_cal/remove/$sub_eid">[remove from my calendar]</A>|;
			} else {
				$keys->{add_cal_link} = qq|<A href="%%rootdir%%/editcalendar/addevent/$my_cal/add/$sub_eid">[add to my calendar]</A>|;
			}
		}

		# submit story to event link
		if ( $S->have_event_perm('submit',$keys->{eid}) && $S->have_perm('story_post') ) {
			$keys->{add_story_link} = $S->{UI}->{BLOCKS}->{event_add_story_link};
			$keys->{add_story_link} =~ s/%%eid%%/$keys->{eid}/g;
		}

		# link to child events / parent event
		if ( $keys->{is_parent} ) {
			if ( $S->have_calendar_perm('submit',$keys->{cal_id}) ) {
				# this is a parent event - must provide a link for people to submit child events
				$keys->{add_child_link} = $S->{UI}->{BLOCKS}->{event_add_child_link};
				$keys->{add_child_link} =~ s/%%eid%%/$eid/;
			}
			# show child events
			my $children = $S->{UI}->{BLOCKS}->{event_child_list};
			my $lines;
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'eid',
				FROM => 'events',
				WHERE => qq|parent = $q_eid|
			});
			while ( my ($e) = $sth->fetchrow_array() ) {
				my $child = $S->get_event($e);
				my $line = $S->{UI}->{BLOCKS}->{event_child_list_item};
				$lines .= $S->interpolate($line,$child);
			}
			$sth->finish();
			$children =~ s/%%child_list%%/$lines/;
			$keys->{child_events} = $children if $rv > 0;
		} elsif ( $keys->{parent} ) {
			my $parent = $S->{UI}->{BLOCKS}->{event_parent_item};
			my $event = $S->get_event($keys->{parent});
			$parent = $S->interpolate($parent,$event);
			$keys->{child_events} = $parent;
		}
		
		if ($S->{UID} > 0) {
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => '*',
				FROM => 'event_watch',
				WHERE => qq|eid = $q_eid AND uid = $S->{UID}|
			});

			# subscribe/unsubscribe link for event
			if ( $rv == 1 ) {
				if ( $sth->fetchrow_hashref()->{subscribed} == 1 ) {
					$keys->{event_sub_link} = $S->{UI}->{BLOCKS}->{event_unsubscribe_link};
					$keys->{event_sub_link} =~ s/%%eid%%/$eid/g;
				} else {
					warn "(display_event) not subscribed to event $eid" if $DEBUG;
					$keys->{event_sub_link} = $S->{UI}->{BLOCKS}->{event_subscribe_link};
					$keys->{event_sub_link} =~ s/%%eid%%/$eid/g;
				}
				$sth->finish();
				warn "(display_event) we're watching event $eid - updating timestamp" if $DEBUG;
				# update the "last_viewed" for this event
				($rv,$sth) = $S->db_update({
					DEBUG => $DEBUG,
					WHAT => 'event_watch',
					SET => 'last_viewed=NULL',
					WHERE => qq|eid = $q_eid AND uid = $S->{UID}|
				});
				$sth->finish();
			} else {
				warn "(display_event) not subscribed to event $eid" if $DEBUG;
				$keys->{event_sub_link} = $S->{UI}->{BLOCKS}->{event_subscribe_link};
				$keys->{event_sub_link} =~ s/%%eid%%/$eid/g;
				$sth->finish();
			}
		}
		
		# event RSVP
		if ( $keys->{owner} == $S->{UID} ) {
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => '*',
				FROM => 'event_rsvp',
				WHERE => qq|eid = $q_eid|,
				ORDER_BY => 'volunteer DESC'
			});
			if ( $rv > 0 ) {
				warn "(display_event) $rv people signed up" if $DEBUG;
				my ($attending,$attending_line);
				while ( my $rsvp = $sth->fetchrow_hashref() ) {
					$attending_line = $S->{UI}->{BLOCKS}->{rsvp_list_item};
					$rsvp->{nick} = $S->get_nick_from_uid($rsvp->{uid});
					$rsvp->{urlnick} = $S->urlify($rsvp->{nick});
					$rsvp->{volunteer} ||= 'no';
					$attending .= $S->interpolate($attending_line,$rsvp);
				}
				$keys->{rsvp} = $S->{UI}->{BLOCKS}->{rsvp_list};
				$keys->{rsvp} =~ s/%%number%%/$rv/;
				$keys->{rsvp} =~ s/%%attending%%/$attending/;
			} else {
				warn "(display_event) nobody signed up" if $DEBUG;
				$keys->{rsvp} = $S->{UI}->{BLOCKS}->{rsvp_list};
				$keys->{rsvp} =~ s/%%number%%/no/;
			}
		} else {
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => '*',
				FROM => 'event_rsvp',
				WHERE => qq|eid = $q_eid AND uid = $S->{UID}|
			});
			
			if ($S->{UID} <= 0) {
				$keys->{rsvp} = $S->{UI}->{BLOCKS}->{anonymous_rsvp_form};
			} elsif ( $rv == 1 ) {
				$keys->{rsvp} = $S->{UI}->{BLOCKS}->{rsvp_received};
			} else {
				$keys->{rsvp} = $S->{UI}->{BLOCKS}->{rsvp_form};
				$keys->{rsvp} =~ s/%%eid%%/$eid/;
				if ( $keys->{volunteers} ) {
					$keys->{rsvp} =~ s/%%volunteer%%/$S->{UI}->{BLOCKS}->{rsvp_volunteer_form}/;
				}
			}
		}
		$sth->finish();
	} else {
		$keys->{title} = $S->{UI}->{BLOCKS}->{event_error_title};
		$content = $S->{UI}->{BLOCKS}->{event_error_body};
	}
	$S->{UI}->{BLOCKS}->{subtitle} = "Events %%bars%% $keys->{title}";
	$S->{UI}->{BLOCKS}->{CONTENT} = $S->interpolate($content,$keys);
}

=over 4

=item $S->have_calendar_perm($action,$cal_id)

got to re-do _calendar_can_view/_event_can_view to use have_calendar_perm/have_event_perm

=back

=cut

sub have_calendar_perm {
	my $S = shift;
	my $action = shift;
	my $cal_id = shift;

	warn " (have_calendar_perm) checking $action permission for calendar $cal_id" if $DEBUG;
	return 'admin' if $S->have_perm('edit_calendars'); #shortcut for admins

	my ($rv, $sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => '*',
		FROM => 'calendars',
		WHERE => qq|cal_id = $cal_id|
	});
	my $calendar = $sth->fetchrow_hashref();
	$sth->finish;

	return 'owner' if $calendar->{owner} == $S->{UID};

	if ( $action eq 'submit' ) {
		return 1 if $calendar->{public_submit} eq 'public';
		return 'mod' if $calendar->{public_submit} eq 'modpublic';
		if ( $calendar->{public_submit} =~ /invite/ && $S->pref("calendar_${cal_id}_submit") ) {
			return 1 if $calendar->{public_submit} eq 'invite';
			return 'mod' if $calendar->{public_submit} eq 'modinvite';
		}
	} elsif ( $action eq 'edit' ) {
		if ( $calendar->{public_edit} eq 'invite' ) {
			return 1 if $S->pref("calendar_${cal_id}_edit");
			# people can be invited to edit particular calendars
		}
	}

	return 0;
}

=over 4

=item $S->have_event_perm($action,$eid)

Checks whether or not the current user has permission to perform $action (edit,
submit (story)) on event $eid. It checks the calendar permission as necessary
via $S->have_calendar_perm

Returns various true values if the user has permission, and false if not. (The
true values indicate the difference between the owner and somebody who has
permission but must be moderated, etc.)

The owner of a particular calendar always has permission to edit events in that
calendar, and admins can edit any event at all.

=back

=cut


sub have_event_perm {
	my $S = shift;
	my $action = shift;
	my $eid = shift;

	my $event = $S->get_event($eid);
	my $cal_id = $event->{cal_id};
	warn " (have_event_perm) checking $action permission for calendar $cal_id, event $eid" if $DEBUG;

	return 'admin' if $S->have_perm('edit_events'); #shortcut for admins
	return 'owner' if $event->{owner} == $S->{UID} && $S->have_perm('update_own_event'); #shortcut for the event owner

	if ( $action eq 'edit' ) {
		my $cal_perm = $S->have_calendar_perm($action,$cal_id);
		return 'admin' if $cal_perm eq 'owner';
		# the calendar owner can edit events filed primarily in the calendar
		if ( $event->{public_edit} eq 'invite' ) {
			return 1 if $S->pref("event_${eid}_edit");
			# people can be invited to edit particular events
		}
	} elsif ( $action eq 'submit' ) {
		# submitting stories to events. Submitting events is handled by calendar perms
		return 1 if $event->{public_submit} eq 'public';
		
		if ( $event->{public_submit} eq 'invite' ) {
			return 1 if $S->pref("event_${eid}_invite");
		}
	}
	

	return 0;
}

=over 4

=item $S->user_calendar($uid)

Returns the calendar ID of the given user's calendar. If no UID is given, the
current user is assumed.

=back

=cut

sub user_calendar {
	my $S = shift;
	my $uid = shift || $S->{UID};

	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'cal_id',
		FROM => 'calendars',
		WHERE => "owner=$uid"
	});
	my ($cal_id) = $sth->fetchrow_array();
	warn "(user_calendar) user $uid owns calendar $cal_id" if $DEBUG;
	return $cal_id;
}

=head1 Private Functions

=over 4

=item $S->_calendar_can_view($cal_ids,$uid)

Takes as argument an arrayref of calendar ID numbers to check
Returns an arrayref of calendar ID numbers the current user can view,
a subset of the list passed in.

If $cal_ids eq 'all' then return a list of all calendars the user is allowed to
view. If $uid is not provided, the current user is assumed.

=back

=cut

sub _calendar_can_view {
	my $S = shift;
	my $cal_ids = shift;
	my $uid = shift || $S->{UID};

	return unless $cal_ids;
	my $where;

	# now we check the perms for all the calendars, and remove those we aren't allowed to see
	if ( $cal_ids eq 'all' ) {
		$where = '';
		warn "(_calendar_can_view) checking perms for all calendars" if $DEBUG;
	} else {
		$where = "cal_id IN (" . join(',', map { $S->dbh->quote($_) } @{$cal_ids}) . ")";
		warn "(_calendar_can_view) checking perms for calendars @$cal_ids" if $DEBUG;
	}

	my ($rv, $sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => '*',
		FROM => 'calendars',
		WHERE => $where
	});

	my ($show_cal, $calendar);
	
	while ( $calendar = $sth->fetchrow_hashref() ) {
		warn "(_calendar_can_view) checking permission for calendar $calendar->{cal_id}" if $DEBUG;
		# Check that the user has permission to view the calendar
		if ( $calendar->{'public_view'} eq 'public' ) {
			# calendar is public, show it off
			push @{$show_cal}, $calendar->{cal_id};
		} elsif ( $calendar->{'owner'} == $uid || $S->have_perm('edit_calendars') ) {
			# calendar owner or an admin, show it
			push @{$show_cal}, $calendar->{cal_id};
		} elsif ( $calendar->{'public_view'} eq 'invite' && $S->pref("calendar_${_}_invite") ) {
			# visitor is on calendar's invitation list, show it
			push @{$show_cal}, $calendar->{cal_id};
		}
	}
	$sth->finish;
	return $show_cal; #arrayref
}

=over 4

=item $S->_event_can_view($eids)

Takes as argument an arrayref of event ID numbers to check.
Returns an arrayref of event ID numbers the current user can view, a subset of
the list passed in.

=back

=cut

sub _event_can_view {
	my $S = shift;
	my $eids = shift;
	my $where;

	return unless $eids;
	# now we check the perms for all the events, and remove those we aren't allowed to see
	if ( $eids eq 'all' ) {
		$where = '';
	} else {
		$where = "e.eid IN (" . join(',', map { $S->dbh->quote($_) } @{$eids}) . ")";
	}

	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'e.eid, e.public_view, e.owner, c.displaystatus',
		FROM => 'events e left join calendar_link c using (eid)',
		WHERE => $where
	});

	my ($show_eids, $event);

	while ( $event = $sth->fetchrow_hashref() ) {
		warn "(_event_can_view) checking permissions for event $event->{eid}" if $DEBUG;
		if ( $event->{public_view} eq 'public' && $event->{displaystatus} == 0 ) {
			push @{$show_eids}, $event->{eid} unless grep { /^$event->{eid}$/ } @$show_eids;
		} elsif ( $event->{owner} == $S->{UID} || $S->have_perm('edit_events') ) {
			push @{$show_eids}, $event->{eid} unless grep { /^$event->{eid}$/ } @$show_eids;
		} elsif ( $event->{public_view} eq 'invite' && $S->pref("event_${_}_invite") && $event->{displaystatus} == 0 ) {
			push @{$show_eids}, $event->{eid} unless grep { /^$event->{eid}$/ } @$show_eids;
		}

	}
	$sth->finish;

	return $show_eids;
}

=over 4

=item $S->_personal_calendar_list 

Returns the list of calendar IDs the given user is subscribed to

=back

=cut

sub _personal_calendar_list {
	my $S = shift;
	my $uid = shift || $S->{UID};
	my $cal_ids;
	my ($rv, $sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'prefname,prefvalue',
		FROM => 'userprefs',
		WHERE => qq|uid=$uid AND prefname RLIKE '^calendar_.*_subscribe'|
	});
	my ($prefname,$prefvalue);
	while ( ($prefname,$prefvalue) = $sth->fetchrow_array() ) {
		if ( $prefvalue eq 'on' ) {
			$prefname =~ /calendar_(\d+)_subscribe/;
			push @{$cal_ids}, $1;
			warn "(_personal_calendar_list) subscribed to calendar $1" if $DEBUG;
		}
	}
	$sth->finish;

	return $cal_ids;
}

=over 4

=item $S->_calendar_can_submit($uid)

Returns an arrayref of calendar IDs that the given user (by default the current
user) can submit events to.

=back

=cut

sub _calendar_can_submit {
	my $S = shift;
	my $uid = shift || $S->{UID};
	my $cal_ids;

	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => '*',
		FROM => 'calendars',
	});

	my $calendar;
	
	while ( $calendar = $sth->fetchrow_hashref() ) {
		warn "(_calendar_can_submit) checking permission for calendar $calendar->{cal_id}" if $DEBUG;
		# Check that the user has permission to submit events to the calendar
		if ( $calendar->{'public_submit'} eq 'public' || $calendar->{'public_submit'} eq 'modpublic' ) {
			# calendar is public
			push @{$cal_ids}, $calendar->{cal_id};
		} elsif ( $calendar->{'owner'} == $uid || $S->have_perm('edit_calendars') ) {
			# calendar owner or an admin
			push @{$cal_ids}, $calendar->{cal_id};
		} elsif ( ( $calendar->{'public_submit'} eq 'invite' || $calendar->{'public_submit'} eq 'modinvite' ) && $S->pref("calendar_${_}_submit") ) {
			# visitor is on calendar's invitation list
			push @{$cal_ids}, $calendar->{cal_id};
		}
	}
	$sth->finish;


	return $cal_ids;
}

=over 4

=item $S->_calendar_subscribe($uid)

Handles the subscription and unsubscription from calendars for the given user.
If no uid is provided, the current user is assumed.

=back

=cut

sub _calendar_subscribe {
	my $S = shift;
	my $uid = shift || $S->{UID};
	my $subscribe = $S->cgi->param('subscribe');
	my $cal_id = $S->cgi->param('calendar');
	my $user = $S->user_data($uid);
	my $rv;

	# check for a subscribe or unsubscribe request and handle it
	if ( $subscribe eq 'add' ) {
		# add this calendar to their subscription
		warn "(_calendar_subscribe) subscribing $user->{nickname} to calendar $cal_id" if $DEBUG;
		$rv = $S->_save_pref($user,"calendar_${cal_id}_subscribe",'on');
		$S->run_hook('calendar_subscribe',$uid,$cal_id,$subscribe) if $rv =~ /Saved/i;
	} elsif ( $subscribe eq 'remove' ) {
		# remove this calendar from their subscription
		warn "(_calendar_subscribe) unsubscribing $user->{nickname} from calendar $cal_id" if $DEBUG;
		$rv = $S->_save_pref($user,"calendar_${cal_id}_subscribe",'off');
		$S->run_hook('calendar_subscribe',$uid,$cal_id,$subscribe) if $rv =~ /Saved/i;
	} elsif ( $subscribe eq 'multi' ) {
		# several calendars - cgi param subscribe_item is an arrayref or scalar, depending
		my $choices = $S->cgi->param('subscribe_item');
		my $all_subs = $S->_calendar_can_view('all');
		foreach my $i (@$all_subs) {
			my $value = 'off';
			if ( ref($choices) eq 'ARRAY' ) {
				$value = 'on' if ( grep { /^$i$/ } @{$choices} );
#				if ( grep { /^$i$/ } @{$choices} ) {
#					warn "$i matches @$choices";
#					$value = 'on';
#				} else {
#					warn "$i doesn't match @$choices";
#					$value = 'off';
#				}
				warn "(_calendar_subscribe) $i in \$choices? (@$choices) $value" if $DEBUG;
			} else {
				$value = ( $choices == $i ) ? 'on' : 'off';
			}
			warn "(_calendar_subscribe) setting $user->{nickname}'s subscription for $i to $value" if $DEBUG;
			$rv = $S->_save_pref($user,"calendar_${i}_subscribe",$value);
			if ( $value == 'on' ) {
				$S->run_hook('calendar_subscribe',$uid,$i,'add');
			} else {
				$S->run_hook('calendar_subscribe',$uid,$i,'remove');
			}
		}
	}
	return;
}


=over 4

=item $S->_event_subscribe()

Handles the subscription and unsubscription from events for the given user.
If no uid is provided, the current user is assumed.

=back

=cut

sub _event_subscribe {
	my $S = shift;
	my $uid = shift || $S->{UID};
	my $subscribe = $S->cgi->param('subscribe');
	my $eid = $S->cgi->param('eid');
	my $q_uid = $S->dbh->quote($uid);
	my $q_eid = $S->dbh->quote($eid);
	my ($rv,$sth);

	if ( $subscribe eq 'add' ) {
		($rv,$sth) = $S->db_update({
			DEBUG => $DEBUG,
			WHAT => 'event_watch',
			SET => 'last_viewed=NULL,subscribed=1',
			WHERE => qq|uid=$q_uid AND eid=$q_eid|
		});
		if ( $rv == 0 ) {
			# update didn't work, so insert
			($rv,$sth) = $S->db_insert({
				DEBUG => $DEBUG,
				INTO => 'event_watch',
				COLS => 'uid,eid,last_viewed,subscribed',
				VALUES => qq|$q_uid, $q_eid, NULL, 1|
			});
		}
	} elsif ( $subscribe eq 'remove' ) {
		($rv,$sth) = $S->db_delete({
			DEBUG => $DEBUG,
			FROM => 'event_watch',
			WHERE => qq|uid = $q_uid AND eid = $q_eid|
		});
	}
	$S->run_hook('event_subscribe',$uid,$eid,$subscribe) if ( $rv == 1 );
	$sth->finish();
}

=over 4

=item $S->_get_date_array($date)

Takes a string which should contain date information, either as a month string
(eg, "August") or a YYYY-MM-DD or YYYY-Month-DD format (DD is optional).

Returns a Date::Calc format date array ($year,$month,$day)

=back

=cut

sub _get_date_array {
	my $S = shift;
	my $input = shift;
	warn "(_get_date_array) getting a Date::Calc format date array from $input" if $DEBUG;
	my ($w_year,$w_month,$w_day,$w_hour); # working copies of the variables
	# Today() is the baseline - if any part of the date is not set
	# through the parameter, the value initialized here is used
	my ($year,$month,$day,$hour,$min,$sec) = $S->time_localize_array(Date::Calc::Today_and_Now(),1);

	# now to try and parse the date string we're passed in
	if ( $w_month = Date::Calc::Decode_Month($input) ) {
		# it's the name of a month
		warn "(_get_date_array) month only: $w_month" if $DEBUG;
		$month = $w_month;
	} elsif ( $input =~ /(.+?)-(.+?)(?:-(.+?))?$/ ) {
		$w_year = $1;
		$w_month = $2;
		$w_day = $3 if $3;
		warn "(_get_date_array) YYYY-MM(-DD) format: year is $w_year, month is $w_month, (optional) day is $w_day" if $DEBUG;
		# now filter them
		$year = $w_year if ( $w_year =~ /\d{4}/ );
		if ( $w_month > 0 && $w_month < 13 ) {
			$month = $w_month;
		} else {
			$w_month = Date::Calc::Decode_Month($w_month);
			$month = $w_month if $w_month;
		}
		$day = $w_day if ( $w_day && $w_day > 0 && $w_day <= Date::Calc::Days_in_Month($year, $month) );
	}

	return ($year,$month,$day);
}

=over 4

=item $S->_get_days_events($year,$month,$day,$cal_ids)

Fetches event IDs for the given day and calendar ID(s). 
$cal_ids is an arrayref of the calendar ID(s) to check.
Returns an arrayref of event IDs.

=back

=cut

sub _get_days_events {
	my $S = shift;
	my @date = @_[0,1,2];
	my $cal_ids = $_[3];

	warn "\n  (_get_days_events) fetching @date" if $DEBUG;
#	$cal_ids = $S->_calendar_can_view($cal_ids);

	my ($cache_eid_list,$nocache_cal_ids);
	foreach ( @$cal_ids ) {
		unless ( defined($S->{CALENDAR_DAY_CACHE}->{$_}) ) {
			push @$nocache_cal_ids, $_;
			warn "  (_get_days_events) $_ isn't in the cache" if $DEBUG;
			next;
		}
		warn "  (_get_days_events) calendar $_ is in the cache with dates " . join(',', keys %{$S->{CALENDAR_DAY_CACHE}->{$_}}) if $DEBUG;
		my $month = $date[1] + 0;
		$month = "0$month" if $month < 10;
		my $day = $date[2] + 0;
		$day = "0$day" if $day < 10;
		warn "  (_get_days_events) looking for $date[0]-$month-$day" if $DEBUG;
		if ( $S->{CALENDAR_DAY_CACHE}->{$_}->{"$date[0]-$month-$day"} ) {
			warn qq|  (_get_days_events) for $date[0]-$month-$day I see events @{$S->{CALENDAR_DAY_CACHE}->{$_}->{"$date[0]-$month-$day"}}| if $DEBUG;
			push @$cache_eid_list, @{$S->{CALENDAR_DAY_CACHE}->{$_}->{"$date[0]-$month-$day"}};
		}
		if ($DEBUG && $cache_eid_list) {
			warn "  (_get_days_events) cache hit: returning @$cache_eid_list for calendar $_";
		}
	}
	$cache_eid_list = $S->_event_can_view($cache_eid_list);
	return $cache_eid_list unless $nocache_cal_ids;
	my ($event, $cal, $member, $eid_list, $cal_list, $other_dates, $sql_eids, $sql_cals);

	$cal_ids = $nocache_cal_ids; # different list of calendars to fetch events for
	$eid_list = $cache_eid_list; # don't lose the cached events when looking for non-cached ones

	warn "  (_get_days_events) not in cache: checking db" if $DEBUG;
	
	my $month = $date[1] + 0;
	$month = "0$month" if $month < 10;
	my $day = $date[2] + 0;
	$day = "0$day" if $day < 10;
	my $sql_date = $S->dbh->quote("$date[0]-$month-$day");
	my $sql_cal_ids = join(',', map{$S->dbh->quote($_)} @$cal_ids );
	foreach my $prop (keys %{$S->{EVENT_PROPERTIES}}) {
		next unless $S->{EVENT_PROPERTIES}->{$prop}->{is_date};
		warn "  (_get_days_events) checking for additional dates in $S->{EVENT_PROPERTIES}->{$prop}->{property}" if $DEBUG;
		$other_dates .= " OR (p.property = '$S->{EVENT_PROPERTIES}->{$prop}->{property}' AND p.value = $sql_date)";
	}
	warn "  (_get_days_events) getting events for $sql_date" if $DEBUG;
	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		DISTINCT => 1,
		WHAT => 'e.eid, c.cal_id',
		FROM => 'events e left join event_properties p using (eid) left join calendar_link c using (eid)',
		WHERE => qq|e.parent=0 AND c.displaystatus=0 AND (e.date_start = $sql_date OR (e.date_start < $sql_date AND e.date_end >= $sql_date)$other_dates) AND c.cal_id IN ($sql_cal_ids) |
	});

	while ( ($event,$cal) = $sth->fetchrow_array() ) {
		push @$eid_list, $event;
		push @$cal_list, $cal;
	}
	$sth->finish;

	$eid_list = $S->_event_can_view($eid_list);
	$cal_list = $S->_calendar_can_view($cal_list);
	my $final_eids;

	if ( $eid_list && $cal_list ) {
		$sql_eids = join(',', map { $S->dbh->quote($_) } @$eid_list);
		$sql_cals = join(',', map { $S->dbh->quote($_) } @$cal_list);
		($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			DISTINCT => 1,
			WHAT => 'eid',
			FROM => 'calendar_link',
			WHERE => qq|cal_id IN ($sql_cals) AND eid IN ($sql_eids)|
		});

		while ( ($event) = $sth->fetchrow_array() ) {
			push @$final_eids, $event;
		}
		$sth->finish;
	}

	if ( $DEBUG ) {
		warn $final_eids ? "  (_get_days_events) returning event IDs " . join(',',@{$final_eids}) 
				: "  (_get_days_events) no events today";
	}
	$S->{CALENDAR_DAY_CACHE}->{$_}->{"$date[0]-$date[1]-$date[2]"} = $final_eids;
	return $final_eids;
}

=over 4

=item $S->_get_months_events($year,$month,$cal_ids)

Fills the calendar day cache with event IDs for each day for the given month
and calendar ID(s).  $cal_ids is an arrayref of the calendar ID(s) to check.
Returns nothing; fills the cache so _get_days_events doesn't have to hit the db

=back

=cut

sub _get_months_events {
	my $S = shift;
	my $year = shift;
	my $month = shift;
	my $cal_ids = shift;

	my ($other_dates);
	$month = "0$month" if $month < 10;
	my $sql_date = $S->dbh->quote("$year-$month-%");
	my $sql_cal_ids = join(',', map{$S->dbh->quote($_)} @$cal_ids );

	foreach my $prop (keys %{$S->{EVENT_PROPERTIES}}) {
		next unless $S->{EVENT_PROPERTIES}->{$prop}->{is_date};
		warn "  (_get_months_events) checking for additional dates in $S->{EVENT_PROPERTIES}->{$prop}->{property}" if $DEBUG;
		$other_dates .= " OR (p.property = '$S->{EVENT_PROPERTIES}->{$prop}->{property}' AND p.value LIKE $sql_date)";
	}
	warn "  (_get_months_events) getting events for $sql_date" if $DEBUG;
	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		DISTINCT => 1,
		WHAT => 'e.eid, c.cal_id, e.date_start, e.date_end, p.value',
		FROM => 'events e left join event_properties p using (eid) left join calendar_link c using (eid)',
		WHERE => qq|e.parent=0 AND c.displaystatus=0 AND (e.date_start LIKE $sql_date OR (e.date_start < $sql_date AND e.date_end >= $sql_date)$other_dates) AND c.cal_id IN ($sql_cal_ids) |
	});

	while ( my $event = $sth->fetchrow_hashref() ) {
		warn "  (_get_months_events) processing event $event->{eid} from calendar $event->{cal_id}" if $DEBUG;
		if ( $event->{date_start} =~ /$year-$month/ && !grep { /^$event->{eid}$/ } @{$S->{CALENDAR_DAY_CACHE}->{$event->{cal_id}}->{$event->{date_start}}} ) {
			push @{$S->{CALENDAR_DAY_CACHE}->{$event->{cal_id}}->{$event->{date_start}}}, $event->{eid};
			warn "  (_get_months_events) adding event $event->{eid}'s start date ($event->{date_start}) to the cache" if $DEBUG;
		}
		if ( $event->{date_end} =~ /$year-$month/ && !grep { /^$event->{eid}$/ } @{$S->{CALENDAR_DAY_CACHE}->{$event->{cal_id}}->{$event->{date_end}}} ) {
			push @{$S->{CALENDAR_DAY_CACHE}->{$event->{cal_id}}->{$event->{date_end}}}, $event->{eid};
			warn "  (_get_months_events) adding event $event->{eid}'s end date ($event->{date_end}) to the cache" if $DEBUG;
		}
		if ( $event->{date_start} && $event->{date_end} != '0000-00-00' ) {
			my @date_start = split(/-/,$event->{date_start});
			my @date_end = split(/-/,$event->{date_end});
			my $Dd = Date::Calc::Delta_Days($date_start[0],$date_start[1],$date_start[2],@date_end);
			my @working_date = @date_start;
			my $i = $Dd - 1;
			while ( $i ) {
				@working_date = Date::Calc::Add_Delta_Days(@working_date,1);
				$working_date[1] = "0$working_date[1]" if $working_date[1] < 10;
				$working_date[2] = "0$working_date[2]" if $working_date[2] < 10;
				my $working_date = join('-',@working_date);
				$i--;
				next if (grep { /^$event->{eid}$/ } @{$S->{CALENDAR_DAY_CACHE}->{$event->{cal_id}}->{$working_date}});
				push @{$S->{CALENDAR_DAY_CACHE}->{$event->{cal_id}}->{$working_date}}, $event->{eid};
				warn "  (_get_months_events) adding event $event->{eid}'s continuing date @working_date" if $DEBUG;
			}
		}
		if ( $event->{value} =~ /$year-$month/ && !grep { /^$event->{eid}$/ } @{$S->{CALENDAR_DAY_CACHE}->{$event->{cal_id}}->{$event->{value}}} ) {
			push @{$S->{CALENDAR_DAY_CACHE}->{$event->{cal_id}}->{$event->{value}}}, $event->{eid};
			warn "  (_get_months_events) adding event $event->{eid}'s additional date ($event->{value}) to the cache" if $DEBUG;
		}
	}

	if ($DEBUG) {
		foreach my $debug_cal (keys %{$S->{CALENDAR_DAY_CACHE}}) {
			warn "  (_get_months_events) in calendar $debug_cal: dates cached are " . join (':', sort keys %{$S->{CALENDAR_DAY_CACHE}->{$debug_cal}});
			foreach my $debug_date (sort keys %{$S->{CALENDAR_DAY_CACHE}->{$debug_cal}}) {
				warn "  (_get_months_events) calendar $debug_cal, date $debug_date: @{$S->{CALENDAR_DAY_CACHE}->{$debug_cal}->{$debug_date}}";
			}
		}
	}
	return;
}

=over 4

=item $S->_invite_notify($type,$id,$uid)

=back

=cut

sub _invite_notify {
	my $S = shift;
	my $type = shift;
	my $id = shift;
	my $uid = shift;
	my ($subject,$body);

	warn "  (_invite_notify) $type notification for $id (user $uid)" if $DEBUG;
	return unless ( $uid && $id );

	if ( $type eq 'event' ) {
		# add the invitation line to the db
		my ($rv,$sth) = $S->db_insert({
			DEBUG => $DEBUG,
			INTO => 'event_watch',
			COLS => 'uid,eid,last_viewed,subscribed',
			VALUES => qq|$uid, $id, 0, 0|
		});
		my $user = $S->user_data($uid);
		warn "  (_invite_notify) user $user->{nickname} allows email? $user->{prefs}->{send_mail}" if $DEBUG;
		warn "  (_invite_notify) $user->{nickname} has email $user->{realemail}" if $DEBUG;
		# send the email - but only if they say it's ok (via the send_mail pref)
		# and also only if a line was actually added to the db - if they've already been invited
		# or are already subscribed, no point in sending them more email
		if ( $rv == 1 && $user->{prefs}->{send_mail} eq 'on' && $user->{realemail} ) {
			warn "  (_invite_notify) preparing email" if $DEBUG;
			$subject = $S->{UI}->{BLOCKS}->{event_invite_mail_subject};
			$body = $S->{UI}->{BLOCKS}->{event_invite_mail};
			my $keys = $S->get_event($id);
			$keys->{sitename} = $S->var('sitename');
			$keys->{sender_nick} = $S->{NICK};
			$keys->{nick} = $user->{nickname};
			$keys->{event_url} = $S->var('site_url') . $S->var('rootdir') . qq|/event/$id|;
			$body = $S->interpolate($body,$keys);
			my $err = $S->mail($user->{realemail},$subject,$body);
			warn "  (_invite_notify) mail said $err" if $DEBUG;
		}
	} elsif ( $type eq 'calendar' ) {
		# FIXME write this at some point
	}

	return;
}


1;
