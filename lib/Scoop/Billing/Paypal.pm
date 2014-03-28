package Scoop;
use strict;
my $DEBUG = 0;

sub paypal_ipn_confirm {
	my $S = shift;
	
	my $content = $S->paypal_make_validate_req();
	
	my $ua = new LWP::UserAgent;
	$ua->agent("Scoop Paybot 0.3 " . $ua->agent);

	my $req = new HTTP::Request POST => 'https://www.paypal.com/cgi-bin/webscr';
	$req->content_type('application/x-www-form-urlencoded');
	$req->content($content);

	my $res = $ua->request($req);

	if ($res->is_error()) {
		my $code = $res->code();
		my $message = $res->message();
		warn "IPN verify request failed! Code: <<$code>>, Message: <<$message>>\n" if $DEBUG;
		return '';
	}

	my $answer = $res->content();

	warn "IPN verify answer is <<$answer>>\n" if $DEBUG;
	return $answer;
}


sub paypal_make_validate_req {
	my $S = shift;
	
	# Get all the form variables.
	my $vars = $S->cgi->Vars();
	my $content;

	# Get all the args and validate them
	foreach my $key (keys %{$vars}) {
		next if ($key eq 'op' or $key eq 'page');
		my $val = $S->urlify($vars->{$key});
		$content .= "&$key=$val";
	}

	warn "IPN: Have content <<$content>>\n" if $DEBUG;

	return '' unless ($content);

	$content .= '&cmd=_notify-validate';
	$content =~ s/^\&//;

	warn "Replying to IPN: <<$content>>\n" if $DEBUG;
	return $content;
}

sub paypal_invalid_mail {
	my $S = shift;
	my $answer = shift;
	my $vars = $S->cgi->Vars();
	
	my $subject = 'Invalid Paypal Instant Confirm';
	my $message = qq{
Warning! Paypal instant confirm failed with the message $answer. Below are the
contents of the POST.

};
	
	foreach my $key (keys %{$vars}) {
		$message .= qq{
<$key> = <$vars->{$key}>};
	}

	my $to = $S->{UI}->{VARS}->{admin_alert};
	my @send_to = split /,/, $to;

	foreach my $address (@send_to) {
		$S->mail($address, $subject, $message);
	}
	return;
}

sub paypal_activate_ad {
	my $S = shift;
	my $vars = shift;
	
	return if ($S->paypal_check_txn_id($vars->{'txn_id'}, 'ad_payments'));
	my $q_oid = $S->dbh->quote($vars->{'txn_id'});
	
	# Ok, this seems to all be good! Let the system know about it then
	my $ad_id = $vars->{item_number};

	warn "IPN: Ad ID is <<$ad_id>>\n" if $DEBUG;
	return unless ($ad_id);

	#populate the payment table.
	my ($rv, $sth) = $S->db_insert({
		INTO => 'ad_payments',
		COLS => 'ad_id, order_id, cost, pay_type, auth_date',
		VALUES => "$ad_id, $q_oid, '$vars->{payment_gross}', 'paypal', NOW()"
	});
	$sth->finish();

	# Cool. Now we mark the ad rec paid.
	($rv, $sth) = $S->db_update({
		WHAT => 'ad_info',
		SET	=> 'paid = 1',
		WHERE => qq{ad_id = $ad_id}
	});
	$sth->finish();
	return;

}

sub paypal_do_renewal {
	my $S = shift;
	my $vars = shift;
	
	return if ($S->paypal_check_txn_id($vars->{'txn_id'}, 'ad_payments'));
	my $q_oid = $S->dbh->quote($vars->{'txn_id'});
	my $ad_id = $vars->{item_number};
	my $count = $vars->{custom};
	
	return unless ($ad_id && $count);
	
	$S->cc_finish_renewal($ad_id, $vars->{'txn_id'}, $vars->{payment_gross}, 'paypal', $count);
	
	return;
}

sub paypal_do_sub {
	my $S = shift;
	my $vars = shift;
	return if ($S->paypal_check_txn_id($vars->{'txn_id'}, 'subscription_payments'));
	my ($uid,$months) = split /:/, $vars->{custom};
	my $in = {
		type => $vars->{item_number},
		ctype => 'paypal',
		months => $months,
		uid => $uid
	};
	$S->sub_finish_subscription($in, $vars->{txn_id}, $vars->{payment_gross});
	return;
}

sub paypal_do_donate {
	my $S = shift;
	my $vars = shift;
	return if ($S->paypal_check_txn_id($vars->{'txn_id'}, 'donation_payments'));
	$S->finish_donation($vars->{custom}, $vars->{txn_id}, $vars->{payment_gross}, 'paypal'); 
	return;
}

	

sub paypal_check_txn_id {
	my $S = shift;
	my $oid = shift;
	my $table = shift;
	
	# Check trans id
	my $q_oid = $S->dbh->quote($oid);
	my ($rv, $sth) = $S->db_select({
		WHAT => 'COUNT(*)',
		FROM => "$table",
		WHERE => "order_id = $q_oid"
	});
	my $count = $sth->fetchrow();
	$sth->finish();

	# If count is not zero, this is a dupe
	warn "IPN: Checked for old oid, found <<$count>>\n" if $DEBUG;
	return $count;
}


1;
