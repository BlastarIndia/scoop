package Scoop;
use strict;
my $DEBUG = 0;


sub subscribe {
	my $S = shift;
	
	unless ($S->have_perm('allow_subscription')) {
		$S->{UI}->{BLOCKS}->{CONTENT} .= qq|
		%%norm_font%%$S->{UI}->{BLOCKS}->{subscribe_denied_message}%%norm_font_end%%|;
		return;
	};

	my $sub_purchase_type_list = $S->sub_purchase_type_list();

	my $page = qq|
	<table border=0 cellpadding=0 cellspacing=0 width="99%">
	  <tr>
		<td bgcolor="%%title_bgcolor%%">
		  %%title_font%%Subscribe%%title_font_end%%
		</td>
       </tr>
	</table>
	<table border=0 cellpadding=8 cellspacing=0 width="99%">
	<tr>
		<td>
			%%norm_font%%
			%%subscribe_intro_text%%
			%%norm_font_end%%
		</td>
	</tr>
	<tr>
		<td>
			%%norm_font%%
			$sub_purchase_type_list
			%%norm_font_end%%
		</td>
	</tr>
	</table>
	|;

	$S->{UI}->{BLOCKS}->{CONTENT} .= $page;
	return;
}


sub sub_purchase_type_list {
	my $S = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'subscription_types',
		ORDER_BY => 'cost DESC'
	});
	
	my @types;
	while (my $r = $sth->fetchrow_hashref()) {
		push @types, $r;
	}
	$sth->finish();
	
	my $page = qq|
	<table border=0 cellpadding=8 cellspacing=0 width="100%">|;
	
	foreach my $type (@types) {
		# Check renewable status
		next if ($S->sub_check_renewable($type->{type}));
		$type->{cost_print} = '$'.$type->{cost};
		if ($type->{cost} eq '0.00') {
			$type->{cost_print} = 'Free!';
		}
		my ($max, $buy);
		if ($type->{max_time}) {
			my $end = ($type->{max_time} > 1) ? 's' : '';
			$max = qq|<b>Limit:</b> $type->{max_time} month$end<br>|;
		}
		
		$buy = qq|
		<form action="%%rootdir%%/" method="post">
		<input type="hidden" name="type" value="$type->{type}">
		<input type="hidden" name="op" value="subpay">
		<b>Purchase</b> |;
		
		if ($type->{max_time} == 1) {
			$buy .= qq|
		<input type="hidden" name="months" value="1"><b>1</b> month|;
		} else {
			$buy .= qq|
		<input type="text" name="months" size=3> months|;
			if ($type->{max_time}) {
				$buy .= qq|(Limit $type->{max_time})|;
			}
		}
		
		$buy .= qq| <small><input type="submit" name="buy" value="Buy &gt;"></small></form>|;
		
		$page .= qq|
		<tr>
			<td>
			%%norm_font%%
			<b>$type->{type}</b><br>
			$type->{description}<br>
			<b>Price:</b> $type->{cost_print}<br>
			$max
			$buy
			%%norm_font_end%%
			</td>
		</tr>|;
	}

	$page .= qq|
	</table>|;
	
	return $page;
}

sub sub_check_renewable {
	my $S = shift;
	my $type = shift;
	my $t_data = $S->sub_get_type($type);
	return 0 if ($t_data->{renewable});
		
	my $q_type = $S->dbh->quote($type);
	
	# Check for free type
	my ($rv, $sth) = $S->db_select({
		WHAT => 'uid',
		FROM => 'subscription_info',
		WHERE => "uid = $S->{UID} AND type = $q_type"
	});
	my $check = $sth->fetchrow();
	$sth->finish();
	
	return 1 if ($check);
	
	# If not found, find out what kind the free sub mirrors
	($rv, $sth) = $S->db_select({
		WHAT => 'type',
		FROM => 'subscription_types',
		WHERE => qq|perm_group_id = '$t_data->{perm_group_id}' AND type != $q_type|
	});
	
	while (my $mirror_type = $sth->fetchrow()) {
		my ($rv2, $sth2) = $S->db_select({
			WHAT => 'uid',
			FROM => 'subscription_info',
			WHERE => qq|uid = $S->{UID} AND type = '$mirror_type'|
		});
		my $check = $sth2->fetchrow();
		$sth2->finish();
		return 1 if ($check);
	}	
	$sth->finish();
	
	return 0;
}

sub sub_get_type {
	my $S = shift;
	my $type = shift;
	
	my $q_type = $S->dbh->quote($type);
	my ($rv, $sth) = $S->db_select({
	  WHAT  => '*',
	  FROM  => 'subscription_types',
	  WHERE => "type = $q_type",
	  DEBUG => 0
	});
	my $type_data = $sth->fetchrow_hashref();
	$sth->finish();
	return $type_data;
}


sub sub_get_billing_price {
	my $S = shift;
	my $in = shift;

	# Get basic price
	my ($price, $trash) = $S->sub_calculate_purchase_cost($in->{type}, $in->{months});
	
	# Check for dupes
	$price = $S->sub_adjust_for_dupes($price, $in->{ctype});

	return $price;
}
	
sub sub_get_price {
	my $S = shift;
	my $in = shift;
	
	my $type = $S->dbh->quote($in->{type});
	
	# Get the unit price
	my ($rv, $sth) = $S->db_select({
		WHAT => 'cost',
		FROM => 'subscription_types',
		WHERE => qq|type = $type|
	});
	my $per_month = $sth->fetchrow();
	$sth->finish();
	
	return undef unless ($per_month);
	
	# Calculate total
	my $price = sprintf("%1.2f", ($in->{months} * $per_month));
	
	return $price;
}

sub sub_adjust_for_dupes {
	my $S = shift;
	my $price = shift;
	my $ctype = shift;
	
	my $dupe = 1;
	while ($dupe) {
		my ($rv, $sth) = $S->db_select({
			WHAT  => 'COUNT(*)',
			FROM  => 'subscription_payments',
			WHERE => qq{uid = $S->{UID}  AND 
			            cost = "$price" AND
						auth_date = NOW() AND
						pay_type = "$ctype"}
		});
		
		# If zero, we'll break out of the loop.
		$dupe = $sth->fetchrow();
		$sth->finish();
		warn "Dupe: $dupe. Price: $price\n" if $DEBUG;
		$price -= 0.01 if ($dupe);
	}	
	
	return $price;
}

sub sub_activate_immediate {
	my $S = shift;
	my $type = shift;
	my $months = shift;

	my ($r, $price) = $S->sub_calculate_purchase_cost($type, $months);

	return unless ($price == 0);

	# Ok, price is indeed zero, so just update the subscription info
	$S->sub_add_to_subscription($months, $type);

	# Change the user's group
	my $change = $S->sub_update_user_group($type);

	if ($change eq 'manual') {
		# Send an admin email
		$S->sub_email_manual_change($months, $type, $S->{UID});
	} else {
		# Send an email to the user.
		$S->sub_email_success($months, $type, $S->{UID});
	}

	my $return = qq|%%norm_font%%
	<center><b>Your subscription is now active!</b> Thank you for supporting $S->{UI}->{VARS}->{sitename}.</center>
	%%norm_font%%|;

	return $return;
}
	
		
sub sub_finish_subscription {
	my $S = shift;
	my $in = shift;
	my $oid = shift;
	my $total = shift;

	my $uid = $in->{uid} || $S->{UID};

	# Write the payment record
	return unless $S->sub_save_payment($oid, $total, $in->{ctype}, $in->{type}, $uid);

	# Update the sub info record
	return unless $S->sub_add_to_subscription($in->{months}, $in->{type}, $uid);
	
	# Change the user's group
	my $change = $S->sub_update_user_group($in->{type}, $uid);
	if ($change eq 'manual') {
		# Send an admin email
		$S->sub_email_manual_change($in->{months}, $in->{type}, $uid);
	} else {
		# Send an email to the user.
		$S->sub_email_success($in->{months}, $in->{type}, $uid);
	}

	return;
}

sub sub_update_user_group {
	my $S = shift;
	my $type = shift;
	my $uid = shift || $S->{UID};
	my $user = $S->user_data($uid);
	
	# First, check the user's current group, to see if it has 
	# "subscription_allow_group_change" perm
	return 'manual' unless ($S->have_perm("suballow_group_change", $user->{perm_group}));

	my $type_info = $S->sub_get_type($type);
	my $q_group = $S->dbh->quote($type_info->{perm_group_id});

	my ($rv, $sth) = $S->db_update({
		WHAT => 'users',
		SET => qq|perm_group = $q_group|,
		WHERE => qq|uid = $uid|
	});
	$sth->finish();

	# And refresh the perms
	$S->_refresh_group_perms();

	return $rv;
}	


sub sub_save_payment {
	my $S        = shift;
	my $oid      = shift;
	my $total    = shift;
	my $pay_type = shift;
	my $type     = shift;
	my $uid 	 = shift || $S->{UID};
	
	my $q_oid     = $S->dbh->quote($oid);
	my $q_total   = $S->dbh->quote($total);
	my $q_paytype = $S->dbh->quote($pay_type);
	my $q_type    = $S->dbh->quote($type);

	my ($rv, $sth) = $S->db_insert({
		INTO   => 'subscription_payments',
		COLS   => 'uid, order_id, cost, pay_type, auth_date, final_date, paid, type',
		VALUES => qq|$uid, $q_oid, $q_total, $q_paytype, NOW(), NOW(), 1, $q_type|
	});
	$sth->finish();
	
	return $rv;
}

sub sub_add_to_subscription {
	my $S      = shift;
	my $months = shift;
	my $type   = shift;
	my $uid	   = shift || $S->{UID};
	
	my ($new_exp, $existing) = $S->sub_new_expiration($type, $months, $uid);
	warn "New expiration is $new_exp\n" if ($DEBUG);
	
	# Check for an inactive sub record, if not existing
	unless ($existing) {
		my ($rv, $sth) = $S->db_select({
			WHAT => 'uid',
			FROM => 'subscription_info',
			WHERE => "uid=$uid"
		});
		$existing = $sth->fetchrow();
		$sth->finish();
	}
	
	($existing) ? $S->sub_update_subscription($months, $type, $new_exp, $uid) :
	              $S->sub_create_subscription($months, $type, $new_exp, $uid);
	
	return 1;
}

sub sub_update_subscription {
	my $S = shift;
	my $months = shift;
	my $type = shift;
	my $new_exp = shift;
	my $uid	   = shift;
	my $q_type  = $S->dbh->quote($type);
	
	my ($rv, $sth) = $S->db_update({
		WHAT => 'subscription_info',
		SET  => qq|expires=$new_exp, last_updated=NOW(), updated_by='system', active=1, type=$q_type|,
		WHERE => qq|uid=$uid|
	});
	$sth->finish();
	return;
}

sub sub_create_subscription {
	my $S = shift;
	my $months = shift;
	my $type = shift;
	my $new_exp = shift;
	my $uid	   = shift;
	my $q_type  = $S->dbh->quote($type);
	
	my ($rv, $sth) = $S->db_insert({
		INTO => 'subscription_info',
		COLS => 'uid, expires, created, last_updated, updated_by, active, type',
		VALUES => qq|$uid, $new_exp, NOW(), NOW(), 'system', 1, $q_type|
	});
	$sth->finish();
	return;
}

sub sub_calculate_purchase_cost {
	my $S = shift;
	my $type = shift;
	my $months = shift;
	my $uid = $S->{UID};
	my $return;
	
	# Find the base cost
	my $in = {};
	$in->{type} = $type;
	$in->{months} = $months;
	my $price = $S->sub_get_price($in);
	my $type_data = $S->sub_get_type($type);
	
	my $pl = ($months == 1) ? '' : 's';

	$return .= qq|<p>You are ordering <b>$months month$pl</b> of $type, for a total cost of 
<b>\$$price</b>.</p>|;

	# Find out if the user is already a subscriber
	my ($old_type, $remaining_days, $value_remaining) = $S->sub_check_existing_subscription($uid);
	if ($old_type) {
		$return .= qq|<p>You are already subscribed as $old_type. |;
		
		my $old_type_data = $S->sub_get_type($old_type);
	
		if ($old_type eq $type) {
			$return .= qq|
				Your existing subscription has <b>$remaining_days</b> days remaining. 
				Your new subscription period will be added to that.</p>|;
		} elsif ($price - $value_remaining > 0) {
			$return .= qq|
				Your existing subscription has <b>$remaining_days</b> days remaining, with a prorated value of <b>\$$value_remaining</b>. 
				Your new subscription will start immediately, with this amount subtracted from the total cost.</p>|;
			
			# subtract the remaining value from the base price
			$price -= $value_remaining;
			
			$return .= qq|<p>The final price for this subscription is <b>\$$price</b></p>|;
			
		} elsif ($price - $value_remaining < 0) {
			my $minimum = ($value_remaining % $type_data->{cost} > 0) ? 
				(int($value_remaining / $type_data->{cost}) + 1) :
				($value_remaining / $type_data->{cost});

			$return .= qq|
				Your existing subscription has <b>$remaining_days</b> days remaining, with a prorated value of <b>\$$value_remaining</b>. 
				Your altered subscription must cost at least <b>\$$value_remaining</b>, as we cannot currently provide refunds. 
				You may change your subscription, but if you wish to subscribe at this price, it must be for at least <b>$minimum</b> months.
				Please use your back button to change your purchase amount.</p>|;
				
			$price = 'ERROR';
		} elsif ($price - $value_remaining == 0) {
			$return .= qq|
				Your existing subscription has <b>$remaining_days</b> days remaining, with a prorated value of <b>\$$value_remaining</b>. 
				Your new subscription will start immediately, with this amount subtracted from the total cost.</p>
				<p>Your total cost for this change is <b>\$0.00</b>, so we'll just skip the whole billing process and activate 
				your new subscription right now. Please click the button below to complete this change.</p>|;
			$price -= $value_remaining;
		}
	}
		

	return ($price, $return);
}

sub sub_check_existing_subscription {
	my $S = shift;
	my $uid = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'expires, type',
		FROM => 'subscription_info',
		WHERE => qq|uid = $uid AND active = 1|});
	my ($expires, $type) = $sth->fetchrow();
	$sth->finish();
	
	return unless ($expires && $type);
	
	my $type_data = $S->sub_get_type($type);
	my $day_cost = $type_data->{cost} / 31;
	my $now = time;
	
	# Subtract the current time from the time the sub expires
	# to determine remaining seconds on the sub. Then divide by
	# 86400 to get remaining days, then truncate that to integer portion only, 
	# and add a day to be customer-friendly in estimating.
	my $remaining_days = (int((($expires - $now) / 86400)) + 1);
	
	my $vr = $remaining_days * $day_cost;
	my $vr_formatted = sprintf("%1.2f", $vr);

	return ($type, $remaining_days, $vr_formatted);
}

sub sub_new_expiration {
	my $S = shift;
	my $type = shift;
	my $months = shift;
	my $uid = shift;
		
	my ($old_type, $remaining_days, $value_remaining) = $S->sub_check_existing_subscription($uid);
	warn "Old: $old_type, Remain: $remaining_days, Value: $value_remaining\n" if ($DEBUG);
	
	return ((time + ($months * 2678400)), 0) unless ($old_type);
	
	warn "Not new. New type is $type\n" if ($DEBUG);
	
	my $old_type_data = $S->sub_get_type($old_type);
	my $type_data = $S->sub_get_type($type);
	my $now = time;
	
	my $new_exp;
	if ($old_type eq $type) {
		warn "Same type\n" if ($DEBUG);
		$new_exp = $now + ($remaining_days * 86400) + ($months * 2678400);
	} else {
		warn "Different type\n" if ($DEBUG);
		$new_exp = $now + ($months * 2678400);
	}
	
	warn "Sending back a new expiration of $new_exp\n" if ($DEBUG);
	return ($new_exp, 1);
}
	

sub sub_email_manual_change	{
	my $S = shift;
	my $months = shift;
	my $type = shift;
	my $uid = shift;
	my $user = $S->user_data($uid);

	my $message = $S->{UI}->{BLOCKS}->{sub_manual_change_email};
	my $url = $S->{UI}->{VARS}->{site_url}.$S->{UI}->{VARS}->{rootdir}."/user/uid:$uid";

	$message = $S->sub_escape_mail($message, {months=>$months, type=>$type, url=>$url, nick=>$user->{nickname}});
	my $subj = 'Manual subscription change needed';

	foreach my $to (split /,/, $S->{UI}->{VARS}->{admin_alert}) {
		$S->mail($to, $subj, $message);
	}

	return;
}

sub sub_email_success {
	my $S = shift;
	my $months = shift;
	my $type = shift;
	my $uid = shift || $S->{UID};

	my $to = $S->get_email_from_uid($uid);
	my $message = $S->{UI}->{BLOCKS}->{sub_email_success};
	my $subj = "Thank you for subscribing to $S->{UI}->{VARS}->{sitename}";

	# $%^@&*& bug That Would Not Die!!!!
	my $sub = $S->sub_current_subscription_info($uid);
	my $f_exp = &Time::CTime::strftime('%e %b %Y', localtime($sub->{expires}));

	my $in = {
		months=>$months, 
		type=>$type,
		expiration=>$f_exp
	};

	$message = $S->sub_escape_mail($message, $in);
	my $rv = $S->mail($to, $subj, $message);

	return;
}
		
sub sub_escape_mail {
	my $S = shift;
	my $msg = shift;
	my $in = shift;

	$msg =~ s/%%NICK%%/$in->{nick}/g;
	$msg =~ s/%%TYPE%%/$in->{type}/g;
	$msg =~ s/%%MONTHS%%/$in->{months}/g;
	$msg =~ s/%%URL%%/$in->{url}/g;
	$msg =~ s/%%EXP_DATE%%/$in->{expiration}/g;
	$msg =~ s/%%sitename%%/$S->{UI}->{VARS}->{sitename}/g;
	$msg =~ s/%%site_url%%/$S->{UI}->{VARS}->{site_url}/g;
	$msg =~ s/%%local_email%%/$S->{UI}->{VARS}->{local_email}/g;

	return $msg;
}

sub sub_user_info {
	my $S = shift;
	my $uid = shift;
	return '' unless $S->{UI}->{VARS}->{use_subscriptions}
		&& $S->have_perm('allow_subscription', $S->user_data($uid)->{perm_group});

	my $sub = $S->sub_current_subscription_info($uid);

	return $S->{UI}->{BLOCKS}->{subscribe} unless ($sub);

	my $expires = &Time::CTime::strftime('%e %b %Y', localtime($sub->{expires}));
	
	my $info = "<p>You are currently subscribed as \"$sub->{type}\".<br>
	Your subscription expires on $expires.<br>
	You may alter or extend your subscription <a href=\"%%rootdir%%/subscribe\">here</a>.
	</p>";
	
	return $info;
}

sub sub_current_subscription_info {
	my $S = shift;
	my $uid = shift || $S->{UID};
	
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'subscription_info',
		WHERE => "uid = $uid AND active = 1"
	});
	
	my $sub = $sth->fetchrow_hashref();
	$sth->finish();
	
	return $sub;
}

1;
