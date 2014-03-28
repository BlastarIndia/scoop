package Scoop;
use strict;
my $DEBUG = 0;

=pod

=head1 EditCalendar.pm

This file contains the calendar creation and management functions. Anything to
do with creating calendars, managing calendar permissions, including or
excluding events from calendars, is all here.

=over 4

=item $S->edit_calendar()

This is the function for the editcalendar op. Based on the parameters it gets,
it'll let you create, moderate, and manage individual calendars.

=cut

sub edit_calendar {
	my $S = shift;
	my $tool = $S->cgi->param('tool') || 'settings';
	my $id = $S->cgi->param('id');
	my $content;
	my $title;
	my $msg;

	$id = $S->user_calendar($S->{UID}) unless $id;
	$id = '' unless $S->have_calendar_perm('edit',$id);

	warn "(edit_calendar) starting..." if $DEBUG;
	unless ( $S->var('allow_user_calendars') || $S->have_perm('edit_calendars' ) ) {
		$S->{UI}->{BLOCKS}->{CONTENT} = "Permission Denied";
		return;
	}
	
	if ( $tool eq 'moderate' ) {
		unless ( $id ) {
			$S->{UI}->{BLOCKS}->{CONTENT} = "Permission Denied";
			return;
		}
		$msg = $S->_save_event_moderation($id) if $S->cgi->param('save');
		$content = $S->_event_moderation_form($id);
	} elsif ( $tool eq 'settings' ) {
		$msg = $S->_save_calendar_settings($id) if $S->cgi->param('save');
		$content = $S->_calendar_settings_form($id);
	} elsif ( $tool eq 'listevents' ) {
		unless ( $id ) {
			$S->{UI}->{BLOCKS}->{CONTENT} = "Permission Denied";
			return;
		}
		$content = $S->_list_events($id);
		# event list... 
	} elsif ( $tool eq 'addevent' ) {
		# will need more capable URL Template for event add/remove/etc
		$content = $S->_event_addremove($id);
	} elsif ( $tool eq 'invite' ) {
		unless ( $id ) {
			$S->{UI}->{BLOCKS}->{CONTENT} = "Permission Denied";
			return;
		}
		$content = $S->_invitation_list('calendar',$id);
		# manage which users are invited to view/submit
	} else {
		#error, no other tools
	}
	my $editcal_links = $S->{UI}->{BLOCKS}->{edit_calendar_links};
	$content =~ s/%%edit_calendar_links%%/$editcal_links/;
	$content =~ s/%%msg%%/$msg/;
	$content =~ s/%%cal_id%%/$id/g;
	$S->{UI}->{BLOCKS}->{CONTENT} = $content;
}

=over 4

=item $S->get_calendar($cal_id)

Gets the data for the calendar and returns a hashref with all the info.

=back

=cut

sub get_calendar {
	my $S = shift;
	my $cal_id = shift;
#	my $calendar;
#	my $q_id = $S->dbh->quote($cal_id);
#
#	my ($rv,$sth) = $S->db_select({
#		DEBUG => $DEBUG,
#		WHAT => '*',
#		FROM => 'calendars',
#		WHERE => qq|cal_id=$q_id|
#	});
#	$calendar = $sth->fetchrow_hashref();
#	$sth->finish;
#
#	return $calendar;
	return $S->{CALENDARS}->{$cal_id};
}

=head1 Private Functions

=over 4

=item $S->_event_moderation_form($id)

=back

=cut

sub _event_moderation_form {
	my $S = shift;
	my $cal_id = shift;
	my $content = $S->{UI}->{BLOCKS}->{event_moderate};
	my $q_id = $S->dbh->quote($cal_id);
	my $keys;
	$keys->{cal_id} = $cal_id;
	my ($event,$line,$items);

	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'events.eid',
		FROM => 'events left join calendar_link using (eid)',
		WHERE => qq|cal_id=$q_id AND is_primary_calendar = 1 AND displaystatus='-2'|
	});

	warn " (_event_moderation_form) Getting $rv events from calendar $cal_id" if $DEBUG;
	while ( my ($eid) = $sth->fetchrow_array() ) {
		warn " (_event_moderation_form) Processing event $eid" if $DEBUG;
		$event = $S->get_event($eid);
		$line = $S->{UI}->{BLOCKS}->{event_moderate_item};
		$event->{owner_nick} = $S->get_nick_from_uid($event->{owner});
		$event->{date_delim} = ' to ' if $event->{date_end};
		$items .= $S->interpolate($line,$event);
	}
	$sth->finish;
	$keys->{eventlist} = $items;
	$content = $S->interpolate($content,$keys);
	$S->{UI}->{BLOCKS}->{subtitle} = "Calendars %%bars%% Moderate Events";
	return $content;
}

=over 4

=item $S->_save_event_moderation($id)

=back

=cut

sub _save_event_moderation {
	my $S = shift;
	my $cal_id = shift;
	my $vars = $S->cgi->Vars_cloned();
	return "Permission Denied" if ( $vars->{id} && $cal_id != $vars->{id} );
		# if the cgi param id is set and doesn't match what's passed
		# in, somebody is trying to save to a calendar they don't have
		# permission to save to, by futzing with the form.
	my $msg;
	my $q_id = $S->dbh->quote($cal_id);
	my ($where, @update_eids);

	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'events.eid',
		FROM => 'events left join calendar_link using (eid)',
		WHERE => qq|calendar_link.cal_id=$q_id AND calendar_link.is_primary_calendar=1 AND displaystatus='-2'|
	});
	while ( my ($eid) = $sth->fetchrow_array() ) {
		push @update_eids, $eid if $vars->{$eid};
	}
	$sth->finish();
	$where = "eid IN (" . join (',', map {$S->dbh->quote($_)} (@update_eids)) . ")";
	my $ds = ($vars->{action} eq 'approve') ? '0' : '-1';

	map { $vars->{$_} = $S->dbh->quote($vars->{$_}) } (keys %$vars);
	
	($rv,$sth) = $S->db_update({
		DEBUG => $DEBUG,
		WHAT => 'calendar_link',
		SET => qq|displaystatus = $ds|,
		WHERE => $where
	});
	if ( $rv > 0 ) {
		$msg = 'Saved event moderation';
	} else {
		$msg = 'Error saving: database said "' . $S->dbh->errstr() . '"';
	}
	$sth->finish;
	return $msg;
}

=over 4

=item $S->_calendar_settings_form($id)

=back

=cut


sub _calendar_settings_form {
	my $S = shift;
	my $cal_id = shift;
	my $content = $S->{UI}->{BLOCKS}->{calendar_settings};
	my $keys;

	$keys = $S->get_calendar($cal_id);
	warn " (_calendar_settings_form) editing calendar $cal_id" if $DEBUG;

	if ( $cal_id ) {
		$keys->{pagetitle} = "Edit Calendar";
	} else {
		$keys->{pagetitle} = "Create Calendar";
	}

	$keys->{view_public_checked} = ( $keys->{public_view} eq 'public' ) ? ' CHECKED' : '';
	$keys->{view_invite_checked} = ( $keys->{public_view} eq 'invite' ) ? ' CHECKED' : '';
	$keys->{view_private_checked} = ( $keys->{public_view} eq 'private' ) ? ' CHECKED' : '';

	$keys->{submit_public_checked} = ( $keys->{public_submit} eq 'public' ) ? ' CHECKED' : '';
	$keys->{submit_modpublic_checked} = ( $keys->{public_submit} eq 'modpublic' ) ? ' CHECKED' : '';
	$keys->{submit_invite_checked} = ( $keys->{public_submit} eq 'invite' ) ? ' CHECKED' : '';
	$keys->{submit_modinvite_checked} = ( $keys->{public_submit} eq 'modinvite' ) ? ' CHECKED' : '';
	$keys->{submit_private_checked} = ( $keys->{public_submit} eq 'private' ) ? ' CHECKED' : '';

	$content = $S->interpolate($content,$keys);
	$S->{UI}->{BLOCKS}->{subtitle} = "Calendars %%bars%% Settings";
	return $content;
}

=over 4

=item $S->_save_calendar_settings($cal_id)

=back

=cut

sub _save_calendar_settings {
	my $S = shift;
	my $cal_id = shift;
	my $vars = $S->cgi->Vars_cloned();
	return "Permission Denied" if ( $vars->{id} && $cal_id != $vars->{id} );
		# if the cgi param id is set and doesn't match what's passed
		# in, somebody is trying to save to a calendar they don't have
		# permission to save to, by futzing with the form.

	my $msg;
	my $set;
	map { $vars->{$_} = $S->dbh->quote($vars->{$_}) } (keys %$vars);
	map { $set .= qq|$_=$vars->{$_},| } (qw(title description public_view public_submit));
	$set =~ s/,$//;

	my ($rv,$sth) = $S->db_update({
		DEBUG => $DEBUG,
		WHAT => 'calendars',
		SET => $set,
		WHERE => qq|cal_id=$vars->{id}|
	});
	$sth->finish;
	if ( $rv != 1 ) {
		#update failed, try insert
		($rv,$sth) = $S->db_insert({
			DEBUG => $DEBUG,
			INTO => 'calendars',
			COLS => 'cal_id,title,owner,description,public_view,public_submit',
			VALUES => qq|NULL,$vars->{title},$S->{UID},$vars->{description},$vars->{public_view},$vars->{public_submit}|
		});
		if ( $rv == 1 ) {
			#success! now subscribe the user to their new calendar
			my $new_id = $S->dbh->{'mysql_insertid'};
			if ( $S->var('allow_personal_calendar_view') ) {
				$S->_save_pref($S->user_data($S->{UID}),"calendar_${new_id}_subscribe","on");
			}
			$msg = "Created Calendar";
			$S->run_hook('calendar_new',$S->{UID},$new_id);
		} else {
			$msg = "Error saving calendar";
		}
		$sth->finish;
	} else {
		$msg = "Updated Calendar";
		$S->run_hook('calendar_update',$cal_id);
	}
	$S->cache->stamp('calendars');

	return $msg;
}

=over 4

=item $S->_list_events($cal_id)

=back

=cut

sub _list_events {
	my $S = shift;
	my $cal_id = shift;
	my $content = $S->{UI}->{BLOCKS}->{event_list};
	my ($keys,$eid,$event);
	my ($item,$list);
	my $page = $S->cgi->param('page') || 1;
	my $limit = $S->var('storylist');
	my $offset = ( ($page -1) * $limit );
	warn " (_list_events) getting events for calendar $cal_id" if $DEBUG;
	$keys->{cal_id} = $cal_id;
	$keys->{nextpage} = $page + 1;
	$keys->{prevpage} = $page - 1;

	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'events.eid',
		FROM => 'events left join calendar_link using (eid)',
		WHERE => qq|calendar_link.cal_id=$cal_id|,
		ORDER_BY => 'date_start DESC',
		LIMIT => $limit,
		OFFSET => $offset
	});
	if ( $rv >= $limit ) {
		$keys->{nextlink} = $S->{UI}->{BLOCKS}->{next_page_link};
		$keys->{nextlink} =~ s/%%LINK%%/?page=$keys->{nextpage}/;
		$keys->{nextlink} =~ s/%%maxstories%%/$limit/;
	}
	if ( $page > 1 ) {
		$keys->{prevlink} = $S->{UI}->{BLOCKS}->{prev_page_link};
		$keys->{prevlink} =~ s/%%LINK%%/?page=$keys->{prevpage}/;
		$keys->{prevlink} =~ s/%%maxstories%%/$limit/;
	}
	while ( ($eid) = $sth->fetchrow_array() ) {
		warn " (_list_events) processing event $eid" if $DEBUG;
		$event = $S->get_event($eid);
		$item = $S->{UI}->{BLOCKS}->{event_list_item};
		$event->{owner_nick} = $S->get_nick_from_uid($event->{owner});
		# background colours to show status
		if ( $event->{displaystatus} == '-1' ) {
			$event->{event_bg} = $S->{UI}->{BLOCKS}->{undisplayedstory_bg};
		} elsif ( $event->{displaystatus} == '-2' ) {
			$event->{event_bg} = $S->{UI}->{BLOCKS}->{editqueuestory_bg};
		} elsif ( $event->{cal_id} == $cal_id ) {
			$event->{event_bg} = '';
		} else {
			$event->{event_bg} = $S->{UI}->{BLOCKS}->{story_mod_bg};
		}
		# actions
		if ( $event->{cal_id} == $cal_id ) {
			$event->{actions} .= $S->{UI}->{BLOCKS}->{event_list_action_edit};
			if ( $event->{displaystatus} == '-2' ) {
				$event->{actions} .= $S->{UI}->{BLOCKS}->{event_list_action_approve};
			}
		} else {
			$event->{actions} .= $S->{UI}->{BLOCKS}->{event_list_action_remove};
			$event->{cal_id} = $cal_id; # gotta make sure the right calendar is removed!
		}
		$item =~ s/%%actions%%/$event->{actions}/;
		$list .= $S->interpolate($item,$event);
	}
	$sth->finish;

	$keys->{eventlist} = $list;
	$keys->{title} = $S->_calendar_title($cal_id);

	$content = $S->interpolate($content,$keys);
	$S->{UI}->{BLOCKS}->{subtitle} = "Calendars %%bars%% List Events";
	return $content;
}

=over 4

=item $S->_event_addremove($cal_id)

=back

=cut

sub _event_addremove {
	my $S = shift;
	my $cal_id = shift;
	my $eid = $S->cgi->param('eid');
	my $action = $S->cgi->param('action');
	my $keys;
	my $content = $S->{UI}->{BLOCKS}->{event_addremove};

	if ( $action eq 'add' ) {
		my ($rv,$sth) = $S->db_insert({
			DEBUG => $DEBUG,
			INTO => 'calendar_link',
			COLS => 'eid,cal_id,is_primary_calendar',
			VALUES => qq|$eid,$cal_id,'0'|
		});
		if ( $rv != 1 ) {
			$keys->{msg} = qq|Error adding event $eid to calendar $cal_id: database said "| . $S->dbh->errstr() . '"';
		}
		$sth->finish;
	} elsif ( $action eq 'remove' ) {
		my ($rv,$sth) = $S->db_delete({
			DEBUG => $DEBUG,
			FROM => 'calendar_link',
			WHERE => qq|eid=$eid AND cal_id=$cal_id|
		});
		if ( $rv != 1 ) {
			$keys->{msg} = qq|Error removing event $eid from calendar $cal_id: database said "| . $S->dbh->errstr() . '"';
		}
		$sth->finish;
	} else {
		$keys->{msg} = "invalid command";
	}

	if ($keys->{msg}) {
		# there was an error
		return $S->interpolate($content,$keys);
	} else {
		# back to where we came from
		$S->{APACHE}->headers_out->{'Location'} = $S->{REFERER};
	}
}

=over 4

=item $S->_invitation_list($type,$id)

=back

=cut

sub _invitation_list {
	my $S = shift;
	my $type = shift;
	my $id = shift;
	my $action = $S->cgi->param('action');
	my ($rv,$sth);
	my ($content,$keys);
	$keys->{id} = $id;

	my $uid = $S->get_uid_from_nick($S->cgi->param('nick'));
	if ($uid) {
		warn " (_invitation_list) handling invitations for uid $uid" if $DEBUG;
		# save any changes ($action contains which list (submit/view) was changed)
		if ( $action =~ /_add$/ ) {
			my ($list,$act) = split(/_/,$action);
			warn " (_invitation_list) adding uid $uid to $type $id $list" if $DEBUG;
			my $rv = $S->_save_pref($S->user_data($uid),"${type}_${id}_$list",'on');
			warn " (_invitation_list) added to $type $id $list" if $DEBUG;
			if ( $rv =~ /saved/i ) {
				$keys->{msg} .= "Added " . $S->cgi->param('nick') . " to $list list";
			} else {
				$keys->{msg} .= $rv;
			}
		} elsif ( $action =~ /_remove$/ ) {
			my ($list,$act) = split(/_/,$action);
			warn " (_invitation_list) removing uid $uid from $type $id $list" if $DEBUG;
			my $rv = $S->_save_pref($S->user_data($uid),"${type}_${id}_$list",'off');
			warn " (_invitation_list) removed from $type $id $list" if $DEBUG;
			if ( $rv =~ /saved/i ) {
				$keys->{msg} .= "Removed " . $S->cgi->param('nick') . " from $list list";
			} else {
				$keys->{msg} .= $rv;
			}
		}
	} else {
		$keys->{msg} .= "No such user " . $S->cgi->param('nick');
	}

	warn " (_invitation_list) getting info from $type $id" if $DEBUG;
	if ( $type eq 'calendar' ) {
		$keys->{op} = 'editcalendar';
		$content = $S->{UI}->{BLOCKS}->{calendar_invitations};
		($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => '*',
			FROM => 'calendars',
			WHERE => "cal_id = $id"
		});
		my $calendar = $sth->fetchrow_hashref();
		$sth->finish;

		warn " (_invitation_list) calendar $id has view permission $calendar->{public_view}, submit permission $calendar->{public_submit}" if $DEBUG;
		if ( $calendar->{public_view} ne 'private' ) {
			# it is invite-only
			warn " (_invitation_list) checking for people invited to view calendar $id" if $DEBUG;
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'uid',
				FROM => 'userprefs',
				WHERE => qq|prefname = 'calendar_${id}_invite' && prefvalue = 'on'|
			});
			if ( $rv == 0 ) {
				# nobody invited yet
				$keys->{view_list} = 'Nobody has been invited yet';
			} else {
				# list of invitees
				while ( my ($u) = $sth->fetchrow_array() ) {
					my $user_keys;
					$user_keys->{op} = 'editcalendar';
					my $item = $S->{UI}->{BLOCKS}->{calendar_invitations_item};
					$user_keys->{uid} = $u;
					$user_keys->{nickname} = $S->get_nick_from_uid($u);
					$user_keys->{urlnick} = $S->urlify($user_keys->{nickname});
					$user_keys->{list} = 'invite';

					$keys->{view_list} .= $S->interpolate($item,$user_keys);
				}
			}
			$sth->finish;
			# invitee add form
			$keys->{view_add} = $S->{UI}->{BLOCKS}->{calendar_invitations_add};
			$keys->{view_add} =~ s/%%list%%/invite/;
			$keys->{view_add} =~ s/%%op%%/editcalendar/;
		} else {
			# it is not invite-only
			$keys->{view_list} = 'This calendar is not visible to anybody else';
			$keys->{view_add} = '';
		}

		if ( $calendar->{public_submit} =~ /invite$/ ) {
			# it is invite-only
			warn " (_invitation_list) checking for people invited to submit to calendar $id" if $DEBUG;
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'uid',
				FROM => 'userprefs',
				WHERE => qq|prefname = 'calendar_${id}_submit' && prefvalue = 'on'|
			});
			if ( $rv == 0 ) {
				# nobody invited yet
				$keys->{submit_list} = 'Nobody has been invited yet';
			} else {
				# list of invitees
				while ( my ($u) = $sth->fetchrow_array() ) {
					my $user_keys;
					$user_keys->{op} = 'editcalendar';
					my $item = $S->{UI}->{BLOCKS}->{calendar_invitations_item};
					$user_keys->{uid} = $u;
					$user_keys->{nickname} = $S->get_nick_from_uid($u);
					$user_keys->{urlnick} = $S->urlify($user_keys->{nickname});
					$user_keys->{list} = 'submit';

					$keys->{submit_list} .= $S->interpolate($item,$user_keys);
				}
			}
			$sth->finish;
			# invitee add form
			$keys->{submit_add} = $S->{UI}->{BLOCKS}->{calendar_invitations_add};
			$keys->{submit_add} =~ s/%%list%%/submit/;
			$keys->{submit_add} =~ s/%%op%%/editcalendar/;
		} else {
			# it is not invite-only
			$keys->{submit_list} = 'This calendar does not require an invitation for event submission';
			$keys->{submit_add} = '';
		}
	} elsif ( $type eq 'event' ) {
		my $event = $S->get_event($id);
		$content = $S->{UI}->{BLOCKS}->{event_invitations};
		warn " (_invitation_list) event $id has view permission $event->{public_view}" if $DEBUG;
		if ( $event->{public_view} ne 'private' ) {
			# it is invite-only
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'uid',
				FROM => 'userprefs',
				WHERE => qq|prefname = 'event_${id}_invite' && prefvalue = 'on'|
			});
			if ( $rv == 0 ) {
				# nobody invited yet
				$keys->{view_list} = 'Nobody has been invited yet';
			} else {
				# list of invitees
				while ( my ($u) = $sth->fetchrow_array() ) {
					my $user_keys;
					$user_keys->{op} = 'submitevent';
					my $item = $S->{UI}->{BLOCKS}->{calendar_invitations_item};
					$user_keys->{uid} = $u;
					$user_keys->{nickname} = $S->get_nick_from_uid($u);
					$user_keys->{urlnick} = $S->urlify($user_keys->{nickname});
					$user_keys->{list} = 'invite';
					$user_keys->{cal_id} = $id;
					$keys->{view_list} .= $S->interpolate($item,$user_keys);
				}
			}
			$sth->finish;
			# invitee add form
			$keys->{view_add} = $S->{UI}->{BLOCKS}->{calendar_invitations_add};
			$keys->{view_add} =~ s/%%list%%/invite/;
			$keys->{view_add} =~ s/%%op%%/submitevent/;
			$keys->{view_add} =~ s/%%cal_id%%/$id/;
		} else {
			$keys->{view_list} = 'This event is private';
			$keys->{view_add} = '';
		}
		if ( $event->{public_submit} eq 'invite' ) {
			# it is invite-only
			warn " (_invitation_list) checking for people invited to submit to event $id" if $DEBUG;
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'uid',
				FROM => 'userprefs',
				WHERE => qq|prefname = 'event_${id}_submit' && prefvalue = 'on'|
			});
			if ( $rv == 0 ) {
				# nobody invited yet
				$keys->{submit_list} = 'Nobody has been invited yet';
			} else {
				# list of invitees
				while ( my ($u) = $sth->fetchrow_array() ) {
					my $user_keys;
					$user_keys->{op} = 'submitevent';
					my $item = $S->{UI}->{BLOCKS}->{calendar_invitations_item};
					$user_keys->{uid} = $u;
					$user_keys->{nickname} = $S->get_nick_from_uid($u);
					$user_keys->{urlnick} = $S->urlify($user_keys->{nickname});
					$user_keys->{list} = 'submit';
					$user_keys->{cal_id} = $id;
					$keys->{submit_list} .= $S->interpolate($item,$user_keys);
				}
			}
			$sth->finish;
			# invitee add form
			$keys->{submit_add} = $S->{UI}->{BLOCKS}->{calendar_invitations_add};
			$keys->{submit_add} =~ s/%%list%%/submit/;
			$keys->{submit_add} =~ s/%%op%%/submitevent/;
			$keys->{submit_add} =~ s/%%cal_id%%/$id/;
		} else {
			# it is not invite-only
			$keys->{submit_list} = 'This event does not require an invitation for story submission';
			$keys->{submit_add} = '';
		}

	}

	return $S->interpolate($content,$keys);
}

=over 4

=item $S->_make_user_invite_list($item_tmpl,$uids)

Builds a list using whatever $item_tmpl (template) you provide it once for each
user in the $uids arrayref.

Supports uid, nickname, urlnick.

=back

=cut

sub _make_user_invite_list {
	my $S = shift;
	my $item_tmpl = shift;
	my $uids = shift;
	my $page;

	foreach my $uid (@$uids) {
	}

	return $page;
}

1;
