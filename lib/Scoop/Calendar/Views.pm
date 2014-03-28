package Scoop;
use strict;
my $DEBUG = 0;

=pod

=head1 Views.pm

This file contains the display routines for the three different calendar views
(monthly, weekly, and daily), and their associated support functions.

=over 4

=item $S->calendar_monthly($cal_ids,$title)

Formats a monthly calendar view containing events in all calendars listed.  One
parameter: an arrayref containing a list of calendars whose events should be
displayed.

=back

=cut

sub calendar_monthly {
	my $S = shift;
	my $cal_ids = shift; #arrayref
	my $title = shift;
	my $date = $S->cgi->param('date') || 'today';
	my @date = $S->_get_date_array($date);
	my @today = $S->time_localize_array(Date::Calc::Today_and_Now(),1);

	my $page .= $S->{UI}->{BLOCKS}->{calendar_body_monthly};
	my $body;

	my $days; #keys for interpolate()
	my $first_of_month = Date::Calc::Day_of_Week($date[0],$date[1],1);
	my $days_in_month = Date::Calc::Days_in_Month($date[0],$date[1]);
	my $tmp = $days_in_month - 28 + $first_of_month;
	my $weeks = ( $tmp == 1 ) ? 4 : ( $tmp >= 9 ) ? 6 : 5;
	warn "(calendar_monthly) there are $weeks weeks in this month and the first day falls on $first_of_month" if $DEBUG;

	foreach my $a (1..$weeks) {
		my $wk = $S->{UI}->{BLOCKS}->{calendar_monthly_one_week};
		$wk =~ s/%%week%%/$a/g;
		$body .= $wk;
	}
	$page =~ s/%%rows%%/$body/;

	my $i = 0;
	my ($dow,$wom,@mow); # day of week, week of month, monday of week
#	$S->_get_months_events($date[0],$date[1],$cal_ids);
# FIXME commented out until date range issue with event cache is worked out

	warn $cal_ids ? "(calendar_monthly) formatting monthly calendar for $date[0]-$date[1]-$date[2] for calendars " . join(',',@{$cal_ids}) : "(calendar_monthly) blank calendar" if $DEBUG;

	# the month in question
	while ( $i++ < $days_in_month ) {
		$dow = Date::Calc::Day_of_Week($date[0],$date[1],$i);
		$wom = int(($i + Date::Calc::Day_of_Week($date[0],$date[1],1) - 2) /7)+1;
		my $hilight = ($date[0] == $today[0] && $date[1] == $today[1] && $i == $today[2]) ? '1' : '0';
		$days->{"wk${wom}_d$dow"} = $S->_calendar_format_one_day(@date[0,1],$i,'monthly',$cal_ids,$hilight);

		@mow = Date::Calc::Monday_of_Week(Date::Calc::Week_of_Year($date[0],$date[1],$i));
		$days->{"wk$wom"} = "$mow[0]-$mow[1]-$mow[2]";
	}

	# days outside the month
	my $hilight = '2';
	#beginning
	$i = $first_of_month;
	$dow = 1;
	while ( --$i > 0 ) {
		my @d = Date::Calc::Add_Delta_YMD(@date[0,1],1,0,0,-$i);
		$days->{"wk1_d$dow"} = $S->_calendar_format_one_day(@d,'monthly',$cal_ids,$hilight);
		$dow++;
	}
	#ending
	$dow = 7; 
	$i = 8 - Date::Calc::Day_of_Week($date[0],$date[1],$days_in_month);
	while ( --$i > 0 ) {
		my @d = Date::Calc::Add_Delta_YMD(@date[0,1],$days_in_month,0,0,$i);
		$days->{"wk${weeks}_d$dow"} = $S->_calendar_format_one_day(@d,'monthly',$cal_ids,$hilight);
		$dow--;
	}

	$days->{cal_id} = $S->cgi->param('calendar') || 0;
	$days->{view} = 'monthly';
	$days->{date} = "$date[0]-$date[1]";
	$days->{longdate} = Date::Calc::Month_to_Text($date[1]) . " " . $date[0];
	$days->{month} = Date::Calc::Month_to_Text($date[1]);
	$days->{monthnum} = $date[1];
	$days->{year} = $date[0];
	$days->{calendar_title} = $title;

	if ( ($S->cgi->param('caller_op') eq 'user' || $S->cgi->param('caller_op') =~ /^~(.+)$/ || $S->cgi->param('caller_op') eq 'my') && $S->cgi->param('uid') == $S->{UID} ) {
		# show link to subscribe to this calendar
		$days->{usercal} = "/user/" . $S->get_nick_from_uid($S->cgi->param('uid'));
	}
	my $sub_link = $S->_calendar_subscribe_link();
	$page =~ s/%%subscribe_link%%/$sub_link/;

	return $S->interpolate($page,$days);
}

=over 4

=item $S->calendar_weekly($cal_ids)

Formats a weekly calendar view containing events in all calendars listed.

=back

=cut

sub calendar_weekly {
	my $S = shift;
	my $cal_ids = shift; #arrayref
	my $title = shift;
	my $date = $S->cgi->param('date') || 'today';
	warn "(calendar_weekly) got date $date" if $DEBUG;
	my @date = Date::Calc::Monday_of_Week(Date::Calc::Week_of_Year($S->_get_date_array($date)));
	my @today = $S->time_localize_array(Date::Calc::Today_and_Now(),1);

	my $page;
	my $days; #keys for interpolate()
	my $i = 0;
	warn $cal_ids ? "(calendar_weekly) formatting weekly calendar for $date[0]-$date[1]-$date[2] for calendars " . join(',',@{$cal_ids}) : "(calendar_weekly) blank calendar" if $DEBUG;

	while ( $i++ < 7 ) {
		warn "(calendar_weekly) processing " . Date::Calc::Day_of_Week_to_Text($i) if $DEBUG;
		my @cdate = Date::Calc::Add_Delta_YMD($date[0],$date[1],$date[2],0,0,$i-1);
		my $hilight = ($cdate[0] == $today[0] && $cdate[1] == $today[1] && $cdate[2] == $today[2]) ? '1' : '0';
		$days->{"d$i"} = $S->_calendar_format_one_day(@cdate,'weekly',$cal_ids,$hilight);
	}
	$days->{cal_id} = $S->cgi->param('calendar') || 0;
	$days->{view} = 'weekly';
	$days->{date} = "$date[0]-$date[1]-$date[2]";
	$days->{mediumdate} = Date::Calc::Date_to_Text($date[0],$date[1],$date[2]);
	$days->{longdate} = Date::Calc::Date_to_Text_Long($date[0],$date[1],$date[2]);
	$days->{month} = Date::Calc::Month_to_Text($date[1]);
	$days->{monthnum} = $date[1];
	$days->{year} = $date[0];
	$days->{day_num} = $date[2];
	$days->{day_ord} = Date::Calc::English_Ordinal($date[2]);
	$days->{dow} = Date::Calc::Day_of_Week_to_Text(Date::Calc::Day_of_Week($date[0],$date[1],$date[2]));
	$days->{dow_short} = Date::Calc::Day_of_Week_Abbreviation(Date::Calc::Day_of_Week($date[0],$date[1],$date[2]));
	$days->{calendar_title} = $title;
	$page .= $S->{UI}->{BLOCKS}->{calendar_body_weekly};
	if ( ($S->cgi->param('caller_op') eq 'user' || $S->cgi->param('caller_op') =~ /^~(.+)$/ || $S->cgi->param('caller_op') eq 'my') && $S->cgi->param('uid') == $S->{UID} ) {
		# show link to subscribe to this calendar
		$days->{usercal} = "/user/" . $S->get_nick_from_uid($S->cgi->param('uid'));
	}
	my $sub_link = $S->_calendar_subscribe_link();
	$page =~ s/%%subscribe_link%%/$sub_link/;

	return $S->interpolate($page,$days);
}

=over 4

=item $S->calendar_daily($cal_ids)

Formats a daily calendar view containing events in all calendars listed.

=back

=cut

sub calendar_daily {
	my $S = shift;
	my $cal_ids = shift; #arrayref
	my $title = shift;
	my $date = $S->cgi->param('date') || 'today';
	my @date = $S->_get_date_array($date);
	my @today = $S->time_localize_array(Date::Calc::Today_and_Now(),1);

	my $page;
	my $days; #keys for interpolate()
	my $i = 0;
	warn $cal_ids ? "(calendar_daily) formatting daily calendar for $date[0]-$date[1]-$date[2] for calendars " . join(',',@{$cal_ids}) : "(calendar_daily) blank calendar" if $DEBUG;

	my $hilight = ($date[0] == $today[0] && $date[1] == $today[1] && $date[2] == $today[2]) ? '1' : '0';
	$days->{day} = $S->_calendar_format_one_day(@date,'daily',$cal_ids,$hilight);
	$days->{cal_id} = $S->cgi->param('calendar') || 0;
	$days->{view} = 'daily';
	$days->{date} = "$date[0]-$date[1]-$date[2]";
	$days->{mediumdate} = Date::Calc::Date_to_Text($date[0],$date[1],$date[2]);
	$days->{longdate} = Date::Calc::Date_to_Text_Long($date[0],$date[1],$date[2]);
	$days->{day_num} = $date[2];
	$days->{day_ord} = Date::Calc::English_Ordinal($date[2]);
	$days->{month} = Date::Calc::Month_to_Text($date[1]);
	$days->{monthnum} = $date[1];
	$days->{year} = $date[0];
	$days->{dow} = Date::Calc::Day_of_Week_to_Text(Date::Calc::Day_of_Week($date[0],$date[1],$date[2]));
	$days->{dow_short} = Date::Calc::Day_of_Week_Abbreviation(Date::Calc::Day_of_Week($date[0],$date[1],$date[2]));
	$days->{calendar_title} = $title;
	$page .= $S->{UI}->{BLOCKS}->{calendar_body_daily};
	if ( ($S->cgi->param('caller_op') eq 'user' || $S->cgi->param('caller_op') =~ /^~(.+)$/ || $S->cgi->param('caller_op') eq 'my') && $S->cgi->param('uid') == $S->{UID} ) {
		# show link to subscribe to this calendar
		$days->{usercal} = "/user/" . $S->get_nick_from_uid($S->cgi->param('uid'));
	}
	my $sub_link = $S->_calendar_subscribe_link();
	$page =~ s/%%subscribe_link%%/$sub_link/;

	return $S->interpolate($page,$days);
}

=over 4

=item $S->calendar_none()

=back

=cut

sub calendar_none {
	my $S = shift;
	return $S->{UI}->{BLOCKS}->{calendar_error_body};
}

=head1 Private functions

=over 4

=item $S->_calendar_title($id)

Returns the calendar title

=back

=cut

sub _calendar_title {
	my $S = shift;
	my $id = shift;

	$id = $S->dbh->quote($id);
	my ($rv, $sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'title',
		FROM => 'calendars',
		WHERE => qq{cal_id = $id}
	});
	my ($title) = $sth->fetchrow_array();
	$sth->finish;
	return $title;
}


=over 4

=item $S->_calendar_date_navigation($view,@date)

Returns an arrayref of hashrefs containing the link and date arrayref for the
current calendar view. The current item has a hash key called 'current' which
is set to true.

The number of items returned on either side of 'current' depends on the Site
Control calendar_navigation_range.

=back

=cut

sub _calendar_date_navigation {
	my $S = shift;
	my $view = shift;
	my @date = @_[0,1,2];

	my ($navbar, $i);
	my $range = $S->var('calendar_navigation_range');
	my $return = [];
	my $link_prefix;

	if ( $S->cgi->param('caller_op') eq 'user' || $S->cgi->param('caller_op') =~ /^~(.+)$/ || $S->cgi->param('caller_op') eq 'my' ) {
		warn "(_calendar_date_navigation) this is a user calendar for " . $S->cgi->param('uid') if $DEBUG;
		$link_prefix = "/user/" . $S->get_nick_from_uid($S->cgi->param('uid'));
	}

	my ($w_year,$w_month,$w_day,$w_item); #working copies of variables
	my $cal_id = $S->cgi->param('calendar') || 0;

	if ( $view eq 'monthly' ) {
		# $range previous
		$i = $range +1;
		while (--$i > 0) {
			($w_year,$w_month,$w_day) = Date::Calc::Add_Delta_YMD(@date,0,-$i,0);
			$w_item = {};
			
			$w_item->{date_array} = [$w_year,$w_month,1]; #FIXME can this be an array or must it be an arrayref?
			$w_month = ( $w_month < 10 ) ? "0$w_month" : $w_month;
			$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$w_year-$w_month";
			push @$return, $w_item;
		}

		# current month
		$w_item = {};
		$w_item->{date_array} = \@date;
		$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$date[0]-$date[1]";
		$w_item->{current} = 1;
		push @$return, $w_item;

		# $range following
		$i = 0;
		while ($i++ < $range) {
			($w_year,$w_month,$w_day) = Date::Calc::Add_Delta_YMD(@date,0,$i,0);
			$w_item = {};

			$w_item->{date_array} = [$w_year,$w_month,1];
			$w_month = ( $w_month < 10 ) ? "0$w_month" : $w_month;
			$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$w_year-$w_month";
			push @$return, $w_item;
		}

	} elsif ( $view eq 'weekly' ) {
		# range previous
		$i = $range +1;
		while (--$i > 0) {
			($w_year,$w_month,$w_day) = Date::Calc::Add_Delta_YMD(@date,0,0,-$i*7);
			$w_item = {};

			$w_item->{date_array} = [$w_year,$w_month,$w_day];
			$w_month = ( $w_month < 10 ) ? "0$w_month" : $w_month;
			$w_day = ( $w_day < 10 ) ? "0$w_day" : $w_day;
			$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$w_year-$w_month-$w_day";
			push @$return, $w_item;
		}

		# current week
		$w_item = {};
		$w_item->{date_array} = \@date;
		$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$date[0]-$date[1]-$date[2]";
		$w_item->{current} = 1;
		push @$return, $w_item;

		# $range following
		$i = 0;
		while ($i++ < $range) {
			($w_year,$w_month,$w_day) = Date::Calc::Add_Delta_YMD(@date,0,0,$i*7);
			$w_item = {};

			$w_item->{date_array} = [$w_year,$w_month,$w_day];
			$w_month = ( $w_month < 10 ) ? "0$w_month" : $w_month;
			$w_day = ( $w_day < 10 ) ? "0$w_day" : $w_day;
			$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$w_year-$w_month-$w_day";
			push @$return, $w_item;
		}

	} elsif ( $view eq 'daily' ) {
		# range previous
		$i = $range +1;
		while (--$i > 0) {
			($w_year,$w_month,$w_day) = Date::Calc::Add_Delta_YMD(@date,0,0,-$i);
			$w_item = {};

			$w_item->{date_array} = [$w_year,$w_month,$w_day];
			$w_month = ( $w_month < 10 ) ? "0$w_month" : $w_month;
			$w_day = ( $w_day < 10 ) ? "0$w_day" : $w_day;
			$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$w_year-$w_month-$w_day";
			push @$return, $w_item;
		}

		# current week
		$w_item = {};
		$w_item->{date_array} = \@date;
		$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$date[0]-$date[1]-$date[2]";
		$w_item->{current} = 1;
		push @$return, $w_item;

		# $range following
		$i = 0;
		while ($i++ < $range) {
			($w_year,$w_month,$w_day) = Date::Calc::Add_Delta_YMD(@date,0,0,$i);
			$w_item = {};

			$w_item->{date_array} = [$w_year,$w_month,$w_day];
			$w_month = ( $w_month < 10 ) ? "0$w_month" : $w_month;
			$w_day = ( $w_day < 10 ) ? "0$w_day" : $w_day;
			$w_item->{link_url} = "%%rootdir%%$link_prefix/calendar/$view/$cal_id/$w_year-$w_month-$w_day";
			push @$return, $w_item;
		}

	}
	return $return;
}

=over 4

=item $S->_calendar_format_one_day($year,$month,$day,$view,$cal_ids)

Formats one day for use in daily, weekly, and monthly calendars. $view
parameter tells it how much detail to put in, $cal_ids is an arrayref
containing the list of calendars to look in for events.

=back

=cut

sub _calendar_format_one_day {
	my $S = shift;
	my @date = @_[0,1,2];
	my $view = $_[3];
	my $cal_ids = $_[4];

	warn " (_calendar_format_one_day) formatting $date[0]-$date[1]-$date[2] for calendars " . join(',',@{$cal_ids}) if ( $cal_ids && $DEBUG );
	my $keys; #hashref for interpolate()
	$keys->{year} = $date[0];
	$keys->{month} = $date[1];
	$keys->{date_number} = $date[2];
	$keys->{cal_id} = $S->cgi->param('calendar') || 0;
	$keys->{hilight} = ($_[5] == 1 ) ? $S->{UI}->{BLOCKS}->{calendar_today_hilight} : ($_[5] == 2) ? $S->{UI}->{BLOCKS}->{calendar_other_month_hilight} : '';

	if ( $S->cgi->param('caller_op') eq 'user' || $S->cgi->param('caller_op') =~ /^~(.+)$/ || $S->cgi->param('caller_op') eq 'my' ) {
		warn "(_calendar_format_one_day) user calendar - preserving user info" if $DEBUG;
		$keys->{usercal} = "/user/" . $S->get_nick_from_uid($S->cgi->param('uid'));
	}
	my ($events, $properties);
	my $eventlist = $S->_get_days_events(@date,$cal_ids) if $cal_ids;
	if ( $eventlist ) {
		my $sql_eids = join(',', map { $S->{DBH}->quote($_) } @{$eventlist});
		warn " (_calendar_format_one_day) getting events $sql_eids from db" if $DEBUG;
		my ($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => '*',
			FROM => 'event_properties',
			WHERE => qq|eid IN ($sql_eids)|
		});
		while ( my $tmp = $sth->fetchrow_hashref() ) {
			next unless $tmp->{value};
			if ($S->{EVENT_PROPERTIES}->{$tmp->{property}}->{calendar_template}) {
				$properties->{$tmp->{eid}}->{$tmp->{property}} = $S->{EVENT_PROPERTIES}->{$tmp->{property}}->{calendar_template};
				$properties->{$tmp->{eid}}->{$tmp->{property}} =~ s/%%value%%/$tmp->{value}/;
				$properties->{$tmp->{eid}}->{$tmp->{property}} =~ s/%%eid%%/$tmp->{eid}/;
			} else {
				$properties->{$tmp->{eid}}->{$tmp->{property}} = $tmp->{value};
			}
		}
		$sth->finish;
		my $y = $date[0];
		my $m = $date[1];
		my $d = $date[2];
		$m = "0$m" if $m < 10;
		$d = "0$d" if $d < 10;
		foreach my $eid ( @{$eventlist} ) {
			warn "(_calendar_format_one_day) formatting $eid" if $DEBUG;
			foreach my $prop ( keys %{$properties->{$eid}} ) {
				if ($S->{EVENT_PROPERTIES}->{$prop}->{is_date} && $properties->{$eid}->{$prop} =~ /$y-$m-$d/ ) {
					$properties->{$eid}->{alt_date} = $S->{EVENT_PROPERTIES}->{$prop}->{title};
					warn "(_calendar_format_one_day) marking as additional date" if $DEBUG;
				}
			}
			$events .= $S->interpolate($S->{UI}->{BLOCKS}->{"event_format_$view"}, $properties->{$eid});
		}
		$keys->{events} = $events;
	}

	return $S->interpolate($S->{UI}->{BLOCKS}->{calendar_body_one_day},$keys);
}

=over 4

=item $S->_calendar_subscribe_link();

Creates the subscribe/unsubscribe link for the current calendar, if users can
create their own personal calendar views.

=back

=cut

sub _calendar_subscribe_link {
	my $S = shift;
	my ($sub_link, $can_subscribe);
	my $cal = $S->cgi->param('calendar');

	return unless $S->var('allow_personal_calendar_view' && $S->have_perm('edit_own_calendar'));
	# no point in subscription links if we don't allow personalized views...
	warn " (_calendar_subscribe_link) making link for calendar $cal" if $DEBUG;
	if ( $cal ) {
		# specific calendar requested
		warn " (_calendar_subscribe_link) subscription to $cal is " . $S->pref("calendar_${cal}_subscribe") if $DEBUG;
		if ( $S->pref("calendar_${cal}_subscribe") eq 'on' ) {
			warn " (_calendar_subscribe_link) making unsubscribe link for $cal" if $DEBUG;
			# already subscribed
			$sub_link = $S->{UI}->{BLOCKS}->{calendar_unsubscribe_link};
		} else {
			warn " (_calendar_subscribe_link) making subscribe link for $cal" if $DEBUG;
			$sub_link = $S->{UI}->{BLOCKS}->{calendar_subscribe_link};
		}
	} else {
		$can_subscribe = $S->_calendar_can_view('all');
		warn " (_calendar_subscribe_link) getting subscription info for calendars @$can_subscribe" if $DEBUG;
		return unless ( ( ( $S->cgi->param('caller_op') eq 'user' || $S->cgi->param('caller_op') =~ /^~(.+)$/ || $S->cgi->param('caller_op') eq 'my') && $S->cgi->param('uid') == $S->{UID} ) || ( $S->cgi->param('caller_op') eq 'calendar' ));
		$sub_link = $S->{UI}->{BLOCKS}->{calendar_subscribe_multi_form};
		my $sql_can_sub = join(',', map { $S->{DBH}->quote($_) } @$can_subscribe);
		my ($rv,$sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT => 'title,cal_id',
			FROM => 'calendars',
			WHERE => "cal_id IN ($sql_can_sub)"
		});
		my ($checkboxes, $checked);
		while ( my ($title,$id) = $sth->fetchrow_array() ) {
			$checkboxes .= $S->{UI}->{BLOCKS}->{calendar_subscribe_item};
			$checkboxes =~ s/%%cal_title%%/$title/g;
			$checkboxes =~ s/%%cal_value%%/$id/g;
			$checked = ( $S->pref("calendar_${id}_subscribe") eq 'on' ) ? ' CHECKED' : '';
			$checkboxes =~ s/%%cal_checked%%/$checked/g;
		}
		$sth->finish;
		$sub_link =~ s/%%calendar_checks%%/$checkboxes/;
	}

	return $sub_link;
}



1;
