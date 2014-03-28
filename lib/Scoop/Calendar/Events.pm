package Scoop;
use strict;
my $DEBUG = 0;

=pod

=head1 Events.pm

This file contains the user interface for submitting and updating events.

=over 4

=item $S->submit_event()

The main function called for the submitevent op. Depending on CGI arguments and
permissions, it'll display forms for submitting and updating events, and
managing users invited to view events.

=back

=cut

sub submit_event {
	my $S = shift;
	warn "(submit_event) starting..." if $DEBUG;

	my $tool = $S->cgi->param('tool') || 'submit';
	my $id = $S->cgi->param('id');
	my $save = $S->cgi->param('save');
	my $newchild = $S->cgi->param('newchild');
	warn "(submit_event) tool $tool, id $id, new child? $newchild" if $DEBUG;
	my ($content, $keys, $cal_id, $eid);

	if ( $tool eq 'edit' || $tool eq 'invite' || ($tool eq 'submit' && $newchild) ) {
		my $event = $S->get_event($id);
		unless ( defined($event) ) {
			$S->{UI}->{BLOCKS}->{subtitle} = 'invalid event';
			$S->{UI}->{BLOCKS}->{CONTENT} = "Sorry, I couldn't find that event";
			return;
		}
		$cal_id = $S->cgi->param('cal_id') || $event->{cal_id};
		$eid = $id;
	} else {
		warn "(submit_event) new event" if $DEBUG;
		$cal_id = $S->cgi->param('cal_id') || $id;
		$eid = undef;
	}

	if ( $save ) {
		($keys->{msg},$eid) = $S->_save_event($cal_id,$tool,$eid);
	}

	if ( $keys->{msg} =~ /saved/i && $tool eq 'submit' ) {
		warn "(submit_event) new event saved" if $DEBUG;
		my $event = $S->get_event($eid);
		if ( $event->{public_view} eq 'invite' || $event->{public_submit} eq 'invite' || $event->{public_edit} eq 'invite' ) {
			$content = $S->_invitation_list('event',$eid);
		} else {
			$content = $S->{UI}->{BLOCKS}->{event_saved_msg};
		}
		$content = $S->interpolate($content,$event);
	} elsif ( ($tool eq 'submit' && $keys->{msg} !~ /saved/i) || $tool eq 'edit' ) {
		warn "(submit_event) not saved, or editing event: show form" if $DEBUG;
		$content = $S->_build_event_form($tool, $cal_id, $eid);
	} elsif ( $tool eq 'invite' ) {
		warn "(submit_event) event invitation list" if $DEBUG;
		$content = $S->_invitation_list('event',$eid);
	}

	$keys->{action} = $tool;
	$keys->{id} = $id;
	$keys->{eid} = $eid;
	$keys->{cal_id} = $cal_id;

	$S->{UI}->{BLOCKS}->{subtitle} = "Edit Event";
	$S->{UI}->{BLOCKS}->{CONTENT} = $S->interpolate($content,$keys);
}



=over 4

=item $S->get_event($eid)

=back

=cut

sub get_event {
	my $S = shift;
	my $eid = shift;
	my $event = {};
	return unless $eid;
	my ($rv,$sth);

	if ( ref($eid) eq 'ARRAY' ) {
		# cache multiple events, return nothing
		my $in_eids = join(',', map { $S->dbh->quote($_) } (@$eid) );
		warn "  (get_event) getting events $in_eids..." if $DEBUG;

		($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => '*',
			FROM => 'events left join calendar_link using (eid)',
			WHERE => qq|events.eid IN ($in_eids) AND is_primary_calendar=1|
		});
		my $cache = $sth->fetchall_hashref('eid');
		$sth->finish();

		($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => 'eid,property,value',
			FROM => 'event_properties',
			WHERE => qq|eid IN ($in_eids)|
		});
		while ( my ($id,$property,$value) = $sth->fetchrow_array() ) {
			$cache->{$id}->{$property} = $value;
		}
		$sth->finish();

		($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => 'eid,cal_id',
			FROM => 'calendar_link',
			WHERE => qq|eid IN ($in_eids)|,
			ORDER_BY => 'is_primary_calendar DESC'
		});
		while ( my ($id,$cal_id) = $sth->fetchrow_array() ) {
			push @{$cache->{$id}->{cals}}, $cal_id;
		}

		$S->{EVENT_DATA_CACHE} = {} unless $S->{EVENT_DATA_CACHE};
		# define it so the next line doesn't cause a "Can't use an
		# undefined value as a HASH reference" error, but only if it
		# doesn't already exist
		%{$S->{EVENT_DATA_CACHE}} = (%{$S->{EVENT_DATA_CACHE}}, %$cache);
		# it's cached now - call get_event with a single eid to get the info from the cache
		return;
	} else {
		# cache and return one event
		warn "  (get_event) getting event $eid..." if $DEBUG;
	
		if ( $S->{EVENT_DATA_CACHE}->{$eid} ) {
			warn "  (get_event) found cached data for event $eid" if $DEBUG;
			return $S->{EVENT_DATA_CACHE}->{$eid};
		}
	
		my $q_eid = $S->dbh->quote($eid);
	
		warn "  (get_event) event $eid not in cache - fetching from db" if $DEBUG;
		($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => '*',
			FROM => 'events left join calendar_link using (eid)',
			WHERE => qq|events.eid = $q_eid AND is_primary_calendar=1|
		});
		if ( $rv == 1 ) {
			$event = $sth->fetchrow_hashref();
			$sth->finish;
		
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'property,value',
				FROM => 'event_properties',
				WHERE => qq|eid = $q_eid|
			});
			while ( my ($property,$value) = $sth->fetchrow_array() ) {
				$event->{$property} = $value;
			}
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'cal_id',
				FROM => 'calendar_link',
				WHERE => qq|eid = $q_eid|
			});
			while ( my ($cal_id) = $sth->fetchrow_array() ) {
				push @{$event->{cals}}, $cal_id;
			}
		
			$S->{EVENT_DATA_CACHE}->{$eid} = $event;
			warn "  (get_event) saved event $eid ($S->{EVENT_DATA_CACHE}->{$eid}->{title}) to the cache" if $DEBUG;
			return $event;
		}
		return undef;
	}
}

=head1 Private Functions

=over 4

=item $S->_build_event_form($cal_id, $action, $eid)

=back

=cut

sub _build_event_form {
	my $S = shift;
	my $action = shift;
	my $cal_id = shift;
	my $eid = shift;
	my ($fields, $data, $event, $perm) = ('', {}, {}, '');


	if ( $action eq 'submit' ) {
		$perm = $S->have_calendar_perm($action,$cal_id);
	} else {
		$perm = $S->have_event_perm($action,$eid);
		$event->{invite_link} = $S->{UI}->{BLOCKS}->{event_invitation_link};
	}
	return "Permission Denied" unless $perm;

	warn " (_build_event_form) putting the $action form together" if $DEBUG;

	if ( !$S->cgi->param('save') && $eid && $action eq 'edit' ) {
		warn " (_build_event_form) getting data from the db" if $DEBUG;
		# get the data to fill the form with
		$data = $S->get_event($eid);
		# do strange things for dates (have to break them into components)
		$data->{date_start} =~ /(\d+)-(\d+)-(\d+)/;
		$data->{date_start_year} = $1;
		$data->{date_start_month} = $2;
		$data->{date_start_day} = $3;
		$data->{date_end} =~ /(\d+)-(\d+)-(\d+)/;
		$data->{date_end_year} = $1;
		$data->{date_end_month} = $2;
		$data->{date_end_day} = $3;
	} elsif ( $S->cgi->param('save') ) {
		warn " (_build_event_form) getting data from cgi" if $DEBUG;
		# from cgi if event was saved
		$data = $S->cgi->Vars_cloned();
		$data->{cal_id} = $S->get_event($eid)->{cal_id} unless $data->{cal_id};
		$data->{eid} = $eid unless $data->{eid};
		$data->{date_start} = "$data->{date_start_year}-$data->{date_start_month}-$data->{date_start_day}";
		$data->{date_end} = "$data->{date_end_year}-$data->{date_end_month}-$data->{date_end_day}";
	} else {
		warn " (_build_event_form) blank form" if $DEBUG;
		$data = {};
		if ( $S->cgi->param('newchild') ) {
			$data->{date_start} = $S->get_event($eid)->{date_start};
			#FIXME need to break the date up
		}
		$data->{cal_id} = $cal_id;
	}

	$event->{formkey} = $S->get_formkey_element();
	my $form = $S->{UI}->{BLOCKS}->{event_edit_form};
	unless ( $S->cgi->param('newchild') || $data->{parent} ) {
		$form =~ s/%%also_submit_line%%/$S->{UI}->{BLOCKS}->{event_other_calendars}/;
		$form =~ s/%%parent_event_line%%/$S->{UI}->{BLOCKS}->{event_parent_line}/;
	}

	# core event info
	$event->{public_submit_checked} = ($data->{public_submit} eq 'public') ? ' CHECKED' : '';
	$event->{private_submit_checked} = ($data->{public_submit} eq 'private') ? ' CHECKED' : '';
	$event->{invite_submit_checked} = ($data->{public_submit} eq 'invite') ? ' CHECKED' : '';
	$event->{public_checked} = ($data->{public_view} eq 'public') ? ' CHECKED' : '';
	$event->{private_checked} = ($data->{public_view} eq 'private') ? ' CHECKED' : '';
	$event->{invite_checked} = ($data->{public_view} eq 'invite') ? ' CHECKED' : '';
	$event->{is_parent} = ($data->{is_parent}) ? ' CHECKED' : '';
	$event->{volunteers} = ($data->{volunteers}) ? ' CHECKED' : '';
	$event->{parent} = $S->cgi->param('newchild') ? $eid : '';
	$event->{newchild} = $S->cgi->param('newchild');
	$event->{displaystatus} = ( $perm eq 'admin' ) ? $S->_event_displaystatus_select($eid) : ($eid) ? $S->_event_displaystatus($eid) : 'New Event';
	$event->{also_submit} = $S->_calendar_additional_submit($data->{cal_id},$data->{eid});

	$event->{date_start} = $data->{date_start};
	$event->{date_start_year} = $data->{date_start_year};
	$event->{date_start_month} = $data->{date_start_month};
	$event->{date_start_day} = $data->{date_start_day};
	$event->{date_end} = $data->{date_end};
	$event->{date_end_year} = $data->{date_end_year};
	$event->{date_end_month} = $data->{date_end_month};
	$event->{date_end_day} = $data->{date_end_day};

	warn " (_build_event_form) some data: date_start=$event->{date_start}; public_view=$data->{public_view}" if $DEBUG;
	$form = $S->interpolate($form,$event);
	$form =~ s/%%date_start_year%%/$event->{date_start_year}/g; #interpolate doesn't seem to catch args to boxes
	$form =~ s/%%date_start_month%%/$event->{date_start_month}/g;
	$form =~ s/%%date_start_day%%/$event->{date_start_day}/g;
	$form =~ s/%%date_end_year%%/$event->{date_end_year}/g;
	$form =~ s/%%date_end_month%%/$event->{date_end_month}/g;
	$form =~ s/%%date_end_day%%/$event->{date_end_day}/g;



	# event properties
	foreach ( sort {$S->{EVENT_PROPERTIES}->{$a}->{display_order} <=> $S->{EVENT_PROPERTIES}->{$b}->{display_order}} keys %{$S->{EVENT_PROPERTIES}} ) {
		my %item = {};
		%item = %{$S->{EVENT_PROPERTIES}->{$_}};
		next unless $item{enabled};
		warn " (_build_event_form) processing $_ ($data->{$_})" if $DEBUG;
		$item{required} = $item{required} ? $S->{UI}->{BLOCKS}->{required_pref_marker} : '';
		if ( ( $data->{$_} && $S->cgi->param('save') ) || $action eq 'edit' ) {
			# a value was passed in while we were trying to save, or we're editing.
			$item{value} = $data->{$_};
			if ( $item{is_date} ) {
				warn " (_build_event_form) $_ is a date" if $DEBUG;
				# value is split into parts
				if ( $data->{$_} && ( $S->cgi->param('save') || $data->{$_} ne '0000-00-00' ) ) {
					$item{use_date} = ' CHECKED';
					$item{no_date} = '';
					$data->{$_} =~ /(\d+)-(\d+)-(\d+)/;
					$item{year} = $data->{"${_}_year"} || $1;
					$item{month} = $data->{"${_}_month"} || $2;
					$item{day} = $data->{"${_}_day"} || $3;
					$item{value} = "$item{year}-$item{month}-$item{day}";
				} else {
					$item{no_date} = ' CHECKED';
					$item{use_date} = '';
				}
			}
			if ( $item{is_time} ) {
				warn " (_build_event_form) $_ is a time" if $DEBUG;
				# value is split into parts FIXME
			}
		}
		my $field = $S->interpolate($S->{UI}->{BLOCKS}->{$item{field}},\%item);
		$field =~ s/%%year%%/$item{year}/g;	# interpolate() doesn't seem to catch args to boxes
		$field =~ s/%%month%%/$item{month}/g;
		$field =~ s/%%day%%/$item{day}/g;
		$fields .= $field;
	}

	$form =~ s/%%event_form_items%%/$fields/;
	return $form;
}

=over 4

=item $S->_save_event($cal_id, $action, $eid)

Saves a new or existing event. If saving a new event, $eid is the event ID of
the parent (optional) and a new event ID is created. If editing an existing
event, $eid is the event ID of the event being edited, and is required.

Returns a status/error message and the event ID (mainly useful when a new event
is created).

=back

=cut

sub _save_event {
	my $S = shift;
	my $cal_id = shift;
	my $action = shift;
	my $eid = shift;
	my $event_props;
	my $event;
	my $oldevent = $S->get_event($eid);
	my $perm;

	unless ( $S->check_formkey() ) {
		# formkey is only used for new event submission, but
		# check_formkey returns true if there's no formkey used.
		return $S->{UI}->{BLOCKS}->{formkey_err};
	}

	if ( $action eq 'submit' ) {
		$perm = $S->have_calendar_perm($action,$cal_id);
	} else {
		$perm = $S->have_event_perm($action,$eid);
	}
	return "Permission Denied" unless $perm;

	my $msg;
	my ($rv,$sth);
	warn " (_save_event) starting $action" if $DEBUG;

	foreach ( keys %{$S->{EVENT_PROPERTIES}} ) {
		my $item = $S->{EVENT_PROPERTIES}->{$_};
		next unless $item->{enabled};
		warn " (_save_event) processing $_" if $DEBUG;
		warn " (_save_event) $_ requires $item->{requires} if set" if $DEBUG;
		if ( $item->{requires} && $S->cgi->param($_) && !$S->cgi->param($item->{requires}) ) {
			$msg .= "<BR>$item->{title} requires a value in $S->{EVENT_PROPERTIES}->{$item->{requires}}->{title}\n";
		}
		if ( $item->{is_date} ) {
			warn " (_save_event) $_ is a date" if $DEBUG;
			if ( $S->cgi->param($_) ) {
				my $year = $S->cgi->param("${_}_year");
				my $month = $S->cgi->param("${_}_month");
				my $day = $S->cgi->param("${_}_day");
				$month = "0$month" if $month < 10;
				$day = "0$day" if $day <10;
				my $tmp = $year . "-" . $month . "-" . $day;
				warn " (_save_event) $_ changed, validating" if $DEBUG;
				if ( Date::Calc::check_date($year,$month,$day) ) {
					$event_props->{$_} = $tmp;
				} else {
					$msg .= "<BR> $item->{title} ($tmp) is not a valid date" 
				}
			} else {
				$event_props->{$_} = '0000-00-00';
			}
			warn " (_save_event) checking $event_props->{$_} against $oldevent->{$_}" if $DEBUG;
			if ( $oldevent->{$_} eq $event_props->{$_} ) {
				delete $event_props->{$_};
				next;
			}
		} else {
			next if ( $oldevent->{$_} eq $S->cgi->param($_) );
			$event_props->{$_} = $S->cgi->param($_);
		}
		if ( $item->{required} && ( !$event_props->{$_} || ( $item->{is_date} && $event_props->{$_} eq '0000-00-00' ) ) ) {
			$msg .= "<BR>$item->{title} is required\n";
		}
		if ( $item->{html} ) {
			$event_props->{$_} = $S->filter_comment($event_props->{$_}, 'event');
			my $filter_errors = $S->html_checker->errors_as_string;
			warn " (_save_event) property $_ generated html error $filter_errors" if ( $filter_errors && $DEBUG );
			$msg .= $filter_errors if $filter_errors;
		} else {
			$event_props->{$_} = $S->filter_subject($event_props->{$_});
		}
		if ( $item->{regex} && $event_props->{$_} ) {
			warn " (_save_event) testing $_ against its regex" if $DEBUG;
			unless ( $event_props->{$_} =~ /$item->{regex}/ ) {
				$msg .= "<BR>$item->{title} ($event_props->{$_}) does not validate\n";
			}
		}
	} # end foreach EVENT_PROPERTIES

	my $uid = $S->dbh->quote($S->{UID});
	my $q_cal_id = $S->dbh->quote($cal_id);

	map { $event->{$_} = $S->cgi->param($_) || 0 } ('public_view','public_submit','is_parent','parent','volunteers');
	if ( $S->have_perm('edit_events') ) {
		# site admin
		$event->{displaystatus} = $S->cgi->param('displaystatus');
	} elsif ( $action eq 'submit' && $perm =~ /^mod/ ) {
		$event->{displaystatus} = -2;
	} elsif ( $action eq 'submit' ) {
		$event->{displaystatus} = 0;
		# if we've gotten this far we have permission to submit
		# the only question was, moderated or not?
	}

	# start and end dates
	if ( $S->cgi->param('date_start_year') > 0 && $S->cgi->param('date_start_month') > 0 && $S->cgi->param('date_start_day') > 0 ) {
		my $tmp = $S->cgi->param('date_start_year') . "-" . $S->cgi->param('date_start_month') . "-" . $S->cgi->param('date_start_day');
		warn " (_save_event) checking start date $tmp" if $DEBUG;
		if ( Date::Calc::check_date($S->cgi->param("date_start_year"),$S->cgi->param("date_start_month"),$S->cgi->param("date_start_day")) ) {
			$event->{date_start} = $tmp;
		} else {
			$msg .= "<BR> Start Date ($tmp) is not a valid date";
		}
	} else {
		$msg .= "<BR>Event must have a start date\n";
	}

	if ( $S->cgi->param('date_end') && $S->cgi->param('date_end_year') > 0 && $S->cgi->param('date_end_month') > 0 && $S->cgi->param('date_start_day') > 0 ) {
		my $tmp2 = $S->cgi->param('date_end_year') . "-" . $S->cgi->param('date_end_month') . "-" . $S->cgi->param('date_end_day');
		warn " (_save_event) checking end date $tmp2" if $DEBUG;
		if ( Date::Calc::check_date($S->cgi->param("date_end_year"),$S->cgi->param("date_end_month"),$S->cgi->param("date_end_day")) ) {
			$event->{date_end} = $tmp2;
		} else {
			$msg .= "<BR> End Date ($tmp2) is not a valid date";
		}
	} else {
		$event->{date_end} = 0;
	}

	map { $event->{$_} = $S->dbh->quote($event->{$_}) } (keys %$event);

	return $msg if $msg; # there were validation errors at some point, so skip the save
	warn " (_save_event) all filters passed successfully; starting save" if $DEBUG;
	# save the event
	if ( $action eq 'submit' && $perm ) {
		warn " (_save_event) adding a new event" if $DEBUG;
		$event->{parent} = $eid || 0;
		($rv, $sth) = $S->db_insert({
			DEBUG => $DEBUG,
			INTO => 'events',
			COLS => 'eid,last_update,owner,date_start,date_end,public_view,public_submit,is_parent,parent,volunteers',
			VALUES => qq|NULL,NULL,$uid,$event->{date_start},$event->{date_end},$event->{public_view},$event->{public_submit},$event->{is_parent},$event->{parent},$event->{volunteers}|
		});
		$eid = $S->dbh->{'mysql_insertid'};
		if ( $rv == 1 ) {
			$S->run_hook('event_new',$uid,$eid);
			my $other_cals = $S->cgi->param('other_cals');
			($rv,$sth) = $S->db_insert({
				DEBUG => $DEBUG,
				INTO => 'calendar_link',
				COLS => 'eid,cal_id,is_primary_calendar,displaystatus',
				VALUES => qq|$eid,$q_cal_id,1,$event->{displaystatus}|
			});  # primary calendar

			my $values;
			if ( ref($other_cals) eq 'ARRAY' ) {
				warn " (_save_event) submitting to multiple secondary calendars" if $DEBUG;
				foreach my $alt ( @{$other_cals} ) {
					my $secondary_perm = $S->have_calendar_perm('submit',$alt);
					if ( $secondary_perm =~ /mod/ ) {
						$values = qq|$eid, $alt, 0, '-2'|;
					} elsif ($secondary_perm) {
						$values = qq|$eid, $alt, 0, '0'|;
					}
					($rv,$sth) = $S->db_insert({
						DEBUG => $DEBUG,
						INTO => 'calendar_link',
						COLS => 'eid,cal_id,is_primary_calendar,displaystatus',
						VALUES => $values
					}); # secondary calendars
				}
			} else { # just one
				warn " (_save_event) submitting to one secondary calendar" if $DEBUG;
				my $secondary_perm = $S->have_calendar_perm('submit',$other_cals);
				if ( $secondary_perm =~ /mod/ ) {
					$values = qq|$eid, $other_cals, 0, '-2'|;
				} elsif ($secondary_perm) {
					$values = qq|$eid, $other_cals, 0, 0|;
				}
				($rv,$sth) = $S->db_insert({
					DEBUG => $DEBUG,
					INTO => 'calendar_link',
					COLS => 'eid,cal_id,is_primary_calendar,displaystatus',
					VALUES => $values
				}); # secondary calendar
			}
		} else {
			$msg = 'Error saving event: database said ' . $sth->errstr();
		}
	} elsif ( $action == 'edit' && $eid && $perm ) {
		warn " (_save_event) editing an existing event" if $DEBUG;
		($rv, $sth) = $S->db_update({
			DEBUG => $DEBUG,
			WHAT => 'events',
			SET => qq|last_update = NULL, date_start = $event->{date_start}, date_end = $event->{date_end}, public_view = $event->{public_view}, public_submit = $event->{public_submit}, is_parent = $event->{is_parent}, volunteers = $event->{volunteers}|,
			WHERE => qq|eid = $eid|
		});
		if ( $rv == 1 ) {
			$S->run_hook('event_update',$eid);
			my $other_cals = $S->cgi->param('other_cals');

			warn " (_save_event) displaystatus is $event->{displaystatus}" if $DEBUG;
			if ( defined($event->{displaystatus}) ) {
				warn " (_save_event) updating displaystatus" if $DEBUG;
				($rv,$sth) = $S->db_update({
					DEBUG => $DEBUG,
					WHAT => 'calendar_link',
					SET => qq|displaystatus = $event->{displaystatus}|,
					WHERE => qq|eid = $eid AND cal_id = $q_cal_id|
				});
			}
			# get the list of secondary calendars it's subscribed to already
			my @cals_used;
			my $q_eid = $S->dbh->quote($eid);
			($rv,$sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'cal_id',
				FROM => 'calendar_link',
				WHERE => qq|eid=$q_eid AND is_primary_calendar=0|
			});
			while ( my ($cal) = $sth->fetchrow_array() ) {
				push @cals_used,$cal;
			}
			# get the list of calendars we're allowed to submit to
			my @cals_allowed;
			my $cal;
			foreach ( keys %{$S->{CALENDARS}} ) {
				$cal = $S->get_calendar($_);
				next if $cal->{cal_id} == $cal_id;
				next unless $S->have_calendar_perm('submit',$cal->{cal_id});
				push @cals_allowed,$cal->{cal_id};
			}

			my $values;
			if ( ref($other_cals) eq 'ARRAY' ) {
				warn " (_save_event) submitting to multiple secondary calendars" if $DEBUG;
				foreach my $alt ( @cals_allowed ) {
					my $q_alt = $S->dbh->quote($alt);
					# adding/removing secondary calendars 
					if ( grep { /^$alt$/ } (@cals_used) ) {
						warn " (_save_event) $alt is in the db" if $DEBUG;
						next if grep { /^$alt$/ } (@$other_cals);

						warn " (_save_event) $alt is unchecked: removing" if $DEBUG;
						# a delete for those not checked
						($rv,$sth) = $S->db_delete({
							DEBUG => $DEBUG,
							FROM => 'calendar_link',
							WHERE => qq|eid=$q_eid AND cal_id=$q_alt|
						});
					} else {
						warn " (_save_event) $alt is not in the db" if $DEBUG;
						next if !grep { /^$alt$/ } (@$other_cals);

						warn " (_save_event) $alt is checked: adding" if $DEBUG;
						# an insert for those checked
						my $secondary_perm = $S->have_calendar_perm('submit',$alt);
						if ( $secondary_perm =~ /mod/ ) {
							$values = qq|$eid, $alt, 0, '-2'|;
						} elsif ($secondary_perm) {
							$values = qq|$eid, $alt, 0, '0'|;
						}
						($rv,$sth) = $S->db_insert({
							DEBUG => $DEBUG,
							INTO => 'calendar_link',
							COLS => 'eid,cal_id,is_primary_calendar,displaystatus',
							VALUES => $values
						});
					}
				} # end foreach @cals_allowed
			} else { # just one (or none)
				warn " (_save_event) submitting to one (or no) secondary calendar" if $DEBUG;
				foreach my $alt ( @cals_allowed ) {
					my $q_alt = $S->dbh->quote($alt);
					if ( grep { /^$alt$/ } (@cals_used) ) {
						warn " (_save_event) $alt is in the db" if $DEBUG;
						next if $alt eq $other_cals;

						warn " (_save_event) $alt is unchecked: removing" if $DEBUG;
						# a delete for those not checked
						($rv,$sth) = $S->db_delete({
							DEBUG => $DEBUG,
							FROM => 'calendar_link',
							WHERE => qq|eid=$q_eid AND cal_id=$q_alt|
						});
					} else {
						warn " (_save_event) $alt is not in the db" if $DEBUG;
						next unless $alt eq $other_cals;

						warn " (_save_event) $alt is checked: adding" if $DEBUG;
						# an insert for the one checked
						my $secondary_perm = $S->have_calendar_perm('submit',$other_cals);
						if ( $secondary_perm =~ /mod/ ) {
							$values = qq|$eid, $other_cals, 0, '-2'|;
						} elsif ($secondary_perm) {
							$values = qq|$eid, $other_cals, 0, 0|;
						}
						($rv,$sth) = $S->db_insert({
							DEBUG => $DEBUG,
							INTO => 'calendar_link',
							COLS => 'eid,cal_id,is_primary_calendar,displaystatus',
							VALUES => $values
						});
					}
				} # end foreach @cals_allowed
			}

		} else {
			$msg = 'Error updating event: database said ' . $sth->errstr();
		}
	} else {
		#error - not a valid action or no permission
		return 'Error';
	}

	return $msg if $msg; # there was a save error in the event, so don't save the properties
	# save the event properties
	foreach ( keys %$event_props ) {

		my $q_eid = $S->dbh->quote($eid);
		my $q_key = $S->dbh->quote($_);
		my $q_value = $S->dbh->quote($event_props->{$_});
		($rv,$sth) = $S->db_update({
			DEBUG => $DEBUG,
			WHAT => 'event_properties',
			SET => qq|value = $q_value|,
			WHERE => qq|property = $q_key AND eid=$q_eid|
		});
		$sth->finish;
		warn " (_save_event) tried update: db rv is $rv" if $DEBUG;
		if ($rv != 1) { # couldn't update, try inserting
			($rv,$sth) = $S->db_insert({
				DEBUG => $DEBUG,
				INTO => 'event_properties',
				COLS => 'eid,property,value',
				VALUES => qq|$q_eid,$q_key,$q_value|
			});
			$sth->finish;
		}
	}

	if ( $perm =~ /^mod/ ) {
		$msg = "Saved event $eid\n<BR>Your event will appear in the calendar once the moderator approves it";
	} else {
		$msg = "Saved event $eid";
	}
	#refresh the cache
	delete $S->{EVENT_DATA_CACHE}->{$eid};
	return ($msg,$eid);
}

=over 4

=item $S->_event_displaystatus_select($eid)

=back

=cut

sub _event_displaystatus_select {
	my $S = shift;
	my $eid = shift;
	my $selectbox = $S->{UI}->{BLOCKS}->{event_edit_displaystatus};
	my ($keys, $dispstat);

	if ( $eid ) {
		my ($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => 'displaystatus',
			FROM => 'calendar_link',
			WHERE => "eid=$eid AND is_primary_calendar=1"
		});
	
		($dispstat) = $sth->fetchrow_array();
	}
	$keys->{pending_selected} = ' SELECTED' if $dispstat == -2;
	$keys->{never_selected} = ' SELECTED' if $dispstat == -1;
	$keys->{always_selected} = ' SELECTED' if $dispstat == 0;
	

	return $S->interpolate($selectbox,$keys);
}

=over 4

=item $S->_event_displaystatus($eid)

=back

=cut

sub _event_displaystatus {
	my $S = shift;
	my $eid = shift;
	my $dispstat;

	if ($eid) {
		my ($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => 'd.name',
			FROM => 'calendar_link c left join displaycodes d on c.displaystatus=d.code',
			WHERE => "c.eid=$eid AND c.is_primary_calendar=1"
		});
		($dispstat) = $sth->fetchrow_array();
		warn "(_event_displaystatus) event $eid has displaystatus $dispstat" if $DEBUG;
	}

	return $dispstat;
}

=over 4

=item $S->_calendar_additional_submit($cal_id)

=back

=cut

sub _calendar_additional_submit {
	my $S = shift;
	my $cal_id = shift;
	my $eid = shift;
	my ($content, $cal, $keys);
	my ($rv,$sth);
	my @cals_used;

	return unless ( $S->var('allow_user_calendars') );
	warn " (_calendar_additional_submit) building list for $eid, subscribed to $cal_id" if $DEBUG;
	if ( $eid ) {
		# need a list of the calendars this event is filed in
		my $q_eid = $S->dbh->quote($eid);
		($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => 'cal_id',
			FROM => 'calendar_link',
			WHERE => qq|eid=$q_eid AND is_primary_calendar=0|
		});
		while ( ($cal) = $sth->fetchrow_array() ) {
			push @cals_used,$cal;
		}
		warn " (_calendar_additional_submit) currently subscribed to calendars @cals_used" if $DEBUG;
	}

	my $cals = $S->_cal_submit_list();
	foreach ( @$cals ) {
		$cal = $S->get_calendar($_);

		warn " (_calendar_additional_submit) making checkbox for $cal->{cal_id} ($cal->{title})" if $DEBUG;
		my $item = $S->{UI}->{BLOCKS}->{event_also_submit};
		$keys->{cal_value} = $cal->{cal_id};
		$keys->{cal_title} = $cal->{title};
		if ( grep {/^$cal->{cal_id}$/} @cals_used ) {
			$keys->{cal_checked} = ' CHECKED';
		} else {
			$keys->{cal_checked} = '';
		}

		$content .= $S->interpolate($item,$keys);
	}
	return $content;
}

=over 4

=item $S->_cal_submit_list()

Returns an arraryref of calendars the current user may submit events to.

=back

=cut

sub _cal_submit_list {
	my $S = shift;
	my $cals = [];
	my $cal;

	foreach ( keys %{$S->{CALENDARS}} ) {
		$cal = $S->get_calendar($_);
		next unless $S->have_calendar_perm('submit',$cal->{cal_id});
		push @$cals,$cal->{cal_id};
	}
	
	return $cals;
}

=over 4

=item $S->_event_rsvp()

Handles the RSVP for an event. This will also take the names of volunteers and
send mail to the event owner when somebody volunteers, so they can contact the
volunteer promptly.

=back

=cut

sub _event_rsvp {
	my $S = shift;
	my $attend = $S->cgi->param('attend') || 0;
	my $volunteer = $S->cgi->param('volunteer');
	my $eid = $S->cgi->param('eid');

	warn "  (_event_rsvp) recording RSVP from $S->{UID}" if $DEBUG;

	if ( ref($volunteer) eq 'ARRAY' ) {
		$volunteer = join(',',@$volunteer);
	}
	my $q_attend = $S->dbh->quote($attend);
	my $q_volunteer = $S->dbh->quote($volunteer);
	my $q_eid = $S->dbh->quote($eid);
	my $q_uid = $S->dbh->quote($S->{UID});

	my ($rv,$sth) = $S->db_insert({
		DEBUG => $DEBUG,
		INTO => 'event_rsvp',
		COLS => 'uid,eid,attend,volunteer',
		VALUES => qq|$q_uid,$q_eid,$q_attend,$q_volunteer|
	});

	if ( $volunteer ) {
		warn "  (_event_rsvp) somebody volunteered to help" if $DEBUG;
		my $event = $S->get_event($eid);
		my $body = $S->{UI}->{BLOCKS}->{rsvp_volunteer_email};
		$event->{url} = $S->var('site_url') . $S->var('rootdir') . "/events/$eid";
		$event->{sitename} = $S->var('sitename');
		$event->{owner_nick} = $S->get_nick_from_uid($event->{owner});
		$event->{volunteer_nick} = $S->{NICK};
		$event->{volunteer_email} = $S->user_data($S->{UID})->{realemail};
		$body = $S->interpolate($body,$event);
		$S->mail($S->user_data($event->{owner})->{realemail},'New Volunteer for your event',$body);
	}

	return;
}


1;
