=head1 Ads/Utilities.pm

This contains functions that help with the running of ads.  Stuff to get the next ad,
count impressions and clickthroughs, redirect for ads, send mail for renewals, etc.

=head1 AUTHOR

Andrew Hurst <andrew@hurstdog.org>

=head1 FUNCTIONS

=over 4

=cut

package Scoop;

use strict;

my $DEBUG = 0;

=item *
get_next_ad()

Returns a hashref of the values for the next ad to display.
The way ads are displayed are controlled by a var (or will be:)
called ad_display_algo which will be 'rotate' or whatever
else I can think of, later.  For now it just assumes rotate.

=cut

sub get_next_ad {
	my $S = shift;
	my $pos  = shift;
	my $adhash = {};

	# select the next ad from the database,	
	my $get = {
		DEBUG	=> 0,
		WHAT	=> 'ad_id,ad_tmpl,ad_title,ad_text1,ad_text2,ad_file,ad_url,sponsor,views_left,ad_sid',
		FROM	=> 'ad_info',
		WHERE	=> "active = 1 and (views_left > 0 or perpetual = 1)",
		ORDER_BY	=> 'last_seen asc limit 1',
		};

	if ($pos) {
		$get->{WHERE} .= qq| and pos = $pos|;
	}
	
	my ($rv,$sth) = $S->db_select($get);	

	$adhash = $sth->fetchrow_hashref;
	unless( defined $adhash ) {
		return { ERROR => 1 };
	}

	$S->count_ad_impression($adhash->{ad_id}, $adhash->{views_left});

	# Mail out a reminder or message telling the sponsor that their ad has
	# finished its run, if the admin wants the reminders sent.  Later
	# add the functionality for the user to choose whether or not to get the
	# emails as a pref.
	if( $S->{UI}->{VARS}->{mail_ad_reminders} ) {

		if ($S->{UI}->{VARS}->{mail_ad_reminder_on} &&
				$S->{UI}->{VARS}->{mail_ad_reminder_on} == $adhash->{views_left}) {

				warn "Mailing reminder cause there are $adhash->{views_left} views left and we mail at $S->{UI}->{VARS}->{mail_ad_reminder_on}" if $DEBUG;

				$S->mail_almost_done_reminder($adhash);

		} elsif ($S->{UI}->{VARS}->{mail_ad_finished_reminder} && $adhash->{views_left} == 1) {
				# it seems odd that we mail a ad finished reminder with 1 view left.  But the
				# client that requests this particular ad, is that 1 view!  so after
				# count_ad_impression() there is none left.
				warn "Mailing campaign finished cause there are $adhash->{views_left} views left." if $DEBUG;
				$S->mail_ad_finished_run($adhash); 
		}	
	}

	return $adhash;
}

=item *
count_ad_impression($adid, $views_left)

Given an adid increments the impression count, etc.
Views left is optional.  If its supplied it makes sure that
the ad's veiws_left count doesn't go below 0

=cut

sub count_ad_impression {
	my $S = shift;
	my $adid = shift;
	my $views_left = shift || 0;

	my $q_adid = $S->dbh->quote($adid);

	# don't let views_left get below 0
	my $vl = 'views_left = views_left - 1, ';
	unless( $views_left > 0 ) {
		$vl = '';
	}

	if( $S->cgi->param('op') ne 'submitad' ) {
		$S->log_ad_request($adid, 'impression');
	}

	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'ad_info',
		SET		=> "$vl view_count = view_count+1, last_seen = NOW()",
		WHERE	=> qq| ad_id = $q_adid and sponsor != $S->{UID} |,
	});
	
	return;
}

=item *
count_ad_clickthrough($adid)

Given an adid increments the clickthrough count.

=cut

sub count_ad_clickthrough {
	my $S = shift;
	my $adid = shift;
	my $f_adid = $S->dbh->quote($adid);

	if( $S->cgi->param('op') ne 'submitad' ) {
		$S->log_ad_request($adid, 'clickthrough');
	}

	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,	
		WHAT	=> 'ad_info',
		SET		=> 'click_throughs = click_throughs + 1',
		WHERE	=> "ad_id = $f_adid and sponsor != $S->{UID} and click_throughs < view_count",
		});

	return;
}

=item *
log_ad_request($adid, $type)

This logs the ip, uid, time, and ad that was requested into the
ad_logs table.  This is so that people that want info about every
ad viewed can get it nice and easy.  $type is either 
'clickthrough' or 'impression'.  If it is neither then an assertion
is thrown.

=cut

sub log_ad_request {
	my $S = shift;
	my $adid = shift;
	my $type = shift;

	$Scoop::ASSERT && $S->assert( $type eq 'clickthrough' || $type eq 'impression' );

	return unless($S->{UI}->{VARS}->{log_ip_for_ads});
	return unless( $S->cgi->param('op') ne 'submitad' );

	my $time = time;

	$adid = $S->dbh->quote($adid);
	$type = $S->dbh->quote($type);

	my($rv,$sth) = $S->db_insert({
		DEBUG	=> 0,
		INTO	=> 'ad_log',
		COLS	=> 'req_time, requestor, request_ip, ad_id, req_type',
		VALUES	=> qq|$time, $S->{UID}, '$S->{REMOTE_IP}', $adid, $type|,
		});

	return;
}

=item * 
redirect()

Gets ad_id off of the url, and sets the Location: header
to redirect to that ads site.  Also collects the stats for
the clickthrough.

=cut

sub redirect {
	my $S = shift;
	my $adid = $S->cgi->param('ad_id');

	if( $adid =~ /^\d+$/ ) {
		my $adinfo = $S->get_ad_hash($adid,'db');
		$S->count_ad_clickthrough($adid);

		$S->{APACHE}->headers_out->{'Location'} = "$adinfo->{ad_url}";
	}

	return;
}

=item *
mail_almost_done_reminder()

This function will send out emails to the advertisers given by the uid in
$adhash, about the ad $adhash represents, using the 'mail_ad_almost_done_msg' 
block as a template for the email.  This is to be called when the ad is
about to run out of impressions.

=cut

sub mail_almost_done_reminder {
	my $S = shift;
	my $adhash = shift;

	my $ad_email = $S->get_email_from_uid($adhash->{sponsor});

	my $msg = $S->{UI}->{BLOCKS}->{mail_ad_almost_done_msg};
	$msg = $S->escape_adjudge_mail($msg, $adhash);
	my $subject = "Your ad on $S->{UI}->{VARS}->{sitename} will expire soon.";

	$S->mail($ad_email, $subject, $msg);

	return;
}

=item *
mail_ad_finished_run($adhash)

This function will send out emails to the advertisers given by the uid in
$adhash, about the ad $adhash represents, using the 'mail_ad_done_msg' 
block as a template for the email.  This is to be called when the ad
has finished its campaign.

=cut

sub mail_ad_finished_run {
	my $S = shift;
	my $adhash = shift;

	my $ad_email = $S->get_email_from_uid($adhash->{sponsor});

	my $msg = $S->{UI}->{BLOCKS}->{mail_ad_done_msg};
	$msg = $S->escape_adjudge_mail($msg, $adhash);
	my $subject = "Your ad on $S->{UI}->{VARS}->{sitename} has expired.";

	$S->mail($ad_email, $subject, $msg);

	return;
}


=item *
escape_adjudge_mail

Escapes a few keys from the ad_approve_mail and
ad_disapprove_mail blocks.  TITLE, TEXT1, URL, REASON
sitename, site_url and local_email

=cut

sub escape_adjudge_mail {
	my $S = shift;
	my $msg = shift;
	my $adhash = shift;

	$msg =~ s/%%REASON%%/$adhash->{reason}/g;
	$msg =~ s/%%sitename%%/$S->{UI}->{VARS}->{sitename}/g;
	$msg =~ s/%%site_url%%/$S->{UI}->{VARS}->{site_url}/g;
	$msg =~ s/%%local_email%%/$S->{UI}->{VARS}->{local_email}/g;
	$msg =~ s/%%TITLE%%/$adhash->{ad_title}/g;
	$msg =~ s/%%TEXT1%%/$adhash->{ad_text1}/g;
	$msg =~ s/%%TEXT2%%/$adhash->{ad_text2}/g;
	$msg =~ s/%%FILE%%/$adhash->{ad_file}/g;
	$msg =~ s/%%URL%%/$adhash->{ad_url}/g;
	$msg =~ s/%%VIEWS_LEFT%%/$adhash->{views_left}/g;
	$msg =~ s/%%IMPRESSIONS%%/$adhash->{impressions}/g;
	$msg =~ s/%%AD_ID%%/$adhash->{ad_id}/g;
	
	return $msg;
}



1;
