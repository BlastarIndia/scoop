package Scoop;
use strict;
my $DEBUG = 0;

# Billing.pm
#
# Functions for use with CSI's linkpoint service
# for credit card billing
sub cc_place_order {
	my $S = shift;
	my $thing = shift;
	my $in = $S->cgi->Vars();

	$in = $S->cc_filter_input($in);
	$S->cc_input_sanity_check($in);
	
	my $ad_id = $in->{ad_id};
	
	unless ($ad_id || $thing eq 'subscription') {
		$S->{CC_ERR} .= qq|Couldn't find an ad id!<br>|;
	}
	
	# Get price from database fresh
	my ($price, $imps, %cc_result, $renew);
	if ($thing eq 'subscription') {

		$price = $S->sub_get_billing_price($in);
		$imps = $in->{months};
		%cc_result = $S->cc_immediate_payment($price, $in);
		$cc_result{chargetotal} = $cc_result{total};
	} elsif ($in->{count}) {

		# Doing a renew, Get total price
		$renew = 1;
		my ($rv, $sth) = $S->db_select({
			WHAT  => 'ad_types.cpm',
			FROM  => 'ad_info, ad_types',
			WHERE => "ad_info.ad_id = $ad_id AND ad_info.ad_tmpl = ad_types.type_template"
		});
		my ($cpm) = $sth->fetchrow();
		$price = ($in->{count}/1000) * $cpm;
		$imps = $in->{count};
		$price = $S->cc_adjust_for_dupes($price, $in->{ctype});
		%cc_result = $S->cc_immediate_payment($price, $in);
		
		# lperl.pm is a stupid worthless piece of shit.
		# Why in God's name would you return "chargetotal"
		# from one function, and "total" from another, when
		# they're the same goddamn piece of information?
		$cc_result{chargetotal} = $cc_result{total};
		
	} else {
	
		# Fresh buy, not a renewal. Do regular process	
		my ($rv, $sth) = $S->db_select({
		  WHAT => 'purchase_price,purchase_size',
		  FROM => 'ad_info',
		  WHERE => "ad_id=$ad_id"});
		my ($price, $imps) = $sth->fetchrow();
		$sth->finish();


		unless ($price) {
			$S->{CC_ERR} .= qq|Couldn't get price from database!<br>|;
		}

		# To avoid dupes, check to see if this user has bought something with this 
		# price today. Also, sanity check for the same ad_id in the database
		($rv, $sth) = $S->db_select({
				WHAT  => 'COUNT(*)',
				FROM => 'ad_payments',
				WHERE => qq|ad_id=$ad_id|});
		my $already_charged = $sth->fetchrow();

		if ($already_charged) {
			# Eek! There should not be a row in here yet. This is a dupe.
			return qq| 
			There seems to already be a payment record for this ad. We don't want to charge you twice!<p>
			Thank you for ordering, your ad should be on it's way to going up live. If you do not receive 
			a confirmation email within the next day or so, please email %%local_email%%, and reference ad id $ad_id.|;
		}

		$price = $S->cc_adjust_for_dupes($price, $in->{ctype});

		%cc_result = $S->cc_pre_auth($price, $in);
	}
	
	my $addnl_txt;
	if ($cc_result{statusCode} == 1) {
		
		if ($thing eq 'subscription') {
			$S->sub_finish_subscription($in, $cc_result{neworderID}, $cc_result{chargetotal});
			$addnl_txt = qq|
			Your subscription is now active.
			|;
		} elsif ($renew) {
			$S->cc_finish_renewal($ad_id, $cc_result{neworderID}, $cc_result{chargetotal}, $in->{ctype}, $imps);
			$addnl_txt = qq|
			Your renewal is complete, and your ad is now active again.
			|;
		} else {	
			$S->cc_finish_ad_sale($ad_id, $cc_result{neworderID}, $cc_result{chargetotal}, $in->{ctype});
			$addnl_txt = qq|
			Now an administrator will review your ad, and it will start 
			running as soon as it is approved. If your ad is not approved, you will receive a notice 
			via email, and your card will not be charged. We currently have a hold on the funds 
			necessary to pay for this ad. If it isn't approved, the hold will be released in a few days 
			(depending on your card issuer's policies).
			|;
		}
	} else {
		# D'oh! Something went wrong.
		if ($cc_result{statusMessage}) {
			my $err = $cc_result{statusMessage};
			$S->{CC_ERR} .= qq|
			An error occurred when I tried to process this transaction. 
			The credit card processor said: $err<br>
			This is order number $cc_result{neworderID}.|;
		}
	}
	
	if ($S->{CC_ERR}) {
		#Go back! There's a problem
		$S->param->{'pay'} = 1;
		return;
	}
	
	# If we get here, it all went smoothly.
	$in->{cardnumber} =~ s/[^\d]//g;
	my $digits = length $in->{cardnumber};
	my $hide = ($digits == 16) ? "xxxx-xxxx-xxxx-" : "x-xxxx-xxxx-";
	
	substr($in->{cardnumber}, 0, -4) = $hide;
		
	my $invoice = $S->cc_make_invoice($in, $cc_result{chargetotal}, $imps, $thing);
	
	my $return = qq|
	%%norm_font%%
	<b>Your order has been processed!</b><br>
	Your order id is: $cc_result{neworderID}
	<br>
	Your invoice is below. Please print it for your records.  
	<p>
	$addnl_txt
	<p>
	Thank you for supporting %%sitename%%!
	<p>
	$invoice
	%%norm_font%%|;
	
	return $return;
		
}

sub cc_bill_approved_ads {
	my $S = shift;
	my $orders = shift;
	my $err;
	
	my $post_orders = $S->cc_post_auth($orders);

	foreach my $order (@{$post_orders}) {
		if ($order->{statusCode} == 1) {
			# Success. Set active.
			$err .=  "Success! Billed ad $order->{ad_id} (OID: $order->{orderID})<br>" if $DEBUG;

			my ($rv, $sth) = $S->db_update({
				WHAT  => 'ad_payments',
				SET   => 'paid=1, final_date=NOW()',
				WHERE => "ad_id=$order->{ad_id}"});

			($rv, $sth) = $S->db_update({
				WHAT  => 'ad_info',
				SET   => 'active=1',
				WHERE => "ad_id=$order->{ad_id}"});
			
			($rv, $sth) = $S->db_select({
				WHAT => 'ad_sid',
				FROM => 'ad_info',
				WHERE => qq{ad_id = $order->{ad_id}}});
			my $sid = $sth->fetchrow();
			
			if ($sid) {
				$S->activate_ad_story($sid);
			}
			
		} else {
			#$err .=  "Failure! What do I do? Message: $order->{statusMessage}<br>" if $DEBUG;
			# Send a mail to admins notifying of failure
			my $subj = 'Bill Post-Process Failed';

			my ($rv, $sth) = $S->db_select({
				WHAT => 'sponsor',
				FROM => 'ad_info',
				WHERE => "ad_id=$order->{ad_id}"
			});
			my $uid = $sth->fetchrow();
			$sth->finish();

			my $user = $S->user_data($uid);
			my $url = $S->{UI}->{VARS}->{site_url}.$S->{UI}->{VARS}->{rootdir};
			my $message = qq{
Ad ID      : $order->{ad_id}
Order ID   : $order->{orderID}
User ID    : $uid
User Nick  : $user->{nickname}
User Email : $user->{realemail}
Error      : $order->{statusMessage}

Edit ad    : $url/admin/ads/edit?ad_id=$order->{ad_id}};

			foreach my $to (split /,/, $S->{UI}->{VARS}->{admin_alert}) {
				$S->mail($to, $subj, $message);
			}
			
			# Mark it "not paid"
			($rv, $sth) = $S->db_update({
				WHAT => 'ad_payments',
				SET => 'paid = 0',
				WHERE => "ad_id = $order->{ad_id}"
			});
			$sth->finish();
		}
	}
	
	return $err;	
}


sub cc_adjust_for_dupes {
	my $S = shift;
	my $price = shift;
	my $ctype = shift;
	
	my $dupe = 1;
	while ($dupe) {
		my ($rv, $sth) = $S->db_select({
			WHAT  => 'COUNT(*)',
			FROM  => 'ad_payments, ad_info',
			WHERE => qq{ad_info.sponsor = $S->{UID}  AND 
			            ad_info.ad_id = ad_payments.ad_id AND
						ad_payments.cost = "$price" AND
						ad_payments.auth_date = NOW() AND
						ad_payments.pay_type = "$ctype"}
		});
		
		# If zero, we'll break out of the loop.
		$dupe = $sth->fetchrow();
		$sth->finish();
		warn "Dupe: $dupe. Price: $price\n" if $DEBUG;
		$price -= 0.01 if ($dupe);
	}	
	
	return $price;
}


sub cc_finish_ad_sale {
	my $S = shift;
	my $ad_id = shift;
	my $oid = shift;
	my $total = shift;
	my $ctype = shift;
	
	# For adverts with no order id, make one up
	unless ($oid) {
		$oid = $ad_id . time();
	}
	my $q_oid = $S->dbh->quote($oid);

	#populate the payment table.
	my ($rv, $sth) = $S->db_insert({
		INTO => 'ad_payments',
		COLS => 'ad_id, order_id, cost, pay_type, auth_date',
		VALUES => qq|'$ad_id', $q_oid, '$total', '$ctype', NOW()|
	});
	$sth->finish();

	# Cool. Now we mark the ad rec paid.
	($rv, $sth) = $S->db_update({
		WHAT => 'ad_info',
		SET	=> 'paid = 1',
		WHERE => qq|ad_id = '$ad_id'|
	});
	$sth->finish();
	return;
}

sub cc_finish_renewal {
	my $S = shift;
	my $ad_id = shift;
	my $oid = shift;
	my $total = shift;
	my $ctype = shift;
	my $imps = shift;
	
	# For adverts with no order id, make one up
	unless ($oid) {
		$oid = $ad_id . time();
	}
	my $q_oid = $S->dbh->quote($oid);

	#populate the payment table.
	my ($rv, $sth) = $S->db_insert({
		INTO => 'ad_payments',
		COLS => 'ad_id, order_id, cost, pay_type, auth_date, final_date, paid',
		VALUES => qq|'$ad_id', $q_oid, '$total', '$ctype', NOW(), NOW(), '1'|
	});
	$sth->finish();

	# Cool. Now we mark the ad rec paid.
	($rv, $sth) = $S->db_update({
		WHAT => 'ad_info',
		SET	=> 'paid = 1',
		WHERE => qq|ad_id = '$ad_id'|
	});
	$sth->finish();
	
	# And save then activate the renewal imps
	$S->save_renewal_impressions($ad_id, $imps);
	$S->activate_renewal_impressions($ad_id);
	$S->update_ad_discussion_time($ad_id);
	$S->send_renewal_mail($ad_id, $imps);
	
	# And reactivate the ad, if it's not already active
	($rv, $sth) = $S->db_update({
		WHAT  => 'ad_info',
		SET   => 'active = 1',
		WHERE => "ad_id = $ad_id"
	});
	$sth->finish();
	
	return;
}

		
sub cc_preview_order {
	my $S = shift;
	my ($price, $num, $thing) = @_;
	
	#warn "Previewing order\n";
	my $in = $S->cgi->Vars();
	
	
	$in = $S->cc_filter_input($in);
	$S->cc_input_sanity_check($in);
	
	if ($S->{CC_ERR}) {
		#warn "Got errors. returning: $S->{CC_ERR}\n";
		return qq|
		%%norm_font%%<font color="#FF0000"><b>The following errors were found in your order form:</b><br>$S->{CC_ERR}</font>%%norm_font_end%%|;
	}
	
	# Make the final payment form
	my $payment_form = $S->cc_make_finalize_form($in);
		foreach my $k (keys %{$in}) {
			warn "\t$k -> $in->{$k}\n" if ($DEBUG);
		}
	
	my $pre_invoice = $S->cc_make_invoice($in, $price, $num, $thing);
		
	my $preview = qq|
	%%norm_font%%
	<b>Confirm Order:</b><p>
	You have entered the following information. If this is correct, click the "Place Order" button below to finalize your purchase.
	<p>
	$pre_invoice
	<p>
	If the information above is not correct, you may scroll down and edit your entries. 
	When you are ready to preview again, press the "Preview Order" button at the bottom of this page (below the form). 
	<p>
	If the information above is correct, click the "Place Order" button below. 
	<b>Your card will be charged when you click this button. Please click only once. 
	Processing may take a minute or two. Please be patient!</b>
	$payment_form
	%%norm_font_end%%|;

	

	return $preview;
}


sub cc_make_invoice {
	my $S = shift;
	my $in = shift;
	my ($price, $num, $thing) = @_;
	
	my $purchase = ($thing eq 'subscription') ? 'Months' : 'Impressions';
	$price = sprintf("%1.2f", $price);

	# Format the address
	my $address = $in->{baddr1};
	$address .= "<br>$in->{baddr2}" if ($in->{baddr2});
	$address .= "<br>$in->{bcity}";
	$address .= ", $in->{bstate}" if $in->{bstate};
	$address .= "<br>$in->{bcountry} $in->{bzip}";
	
	my $phone = qq|
	  <tr>
	    <td valign="top">%%norm_font%%<b>Phone:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$in->{phone}%%norm_font_end%%</td>
	  </tr>
	| if ($in->{phone});
	
	my $type = ($in->{ctype} eq 'visa') ? 'Visa' : 'MasterCard';
	
	my $invoice = qq|
	<table border=0 cellpadding=1 bgcolor="#000000" cellspacing=0 align="center">
	<tr><td>
	<table border=0 cellpadding=8 cellspacing=0 width="100%" align="center" bgcolor="#eeeeee">
	  <tr>
	    <td valign="top">%%norm_font%%<b>Name:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$in->{fname} $in->{lname}%%norm_font_end%%</td>
	  </tr>
	  <tr>
	    <td valign="top">%%norm_font%%<b>Address:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$address%%norm_font_end%%</td>
	  </tr>
	  $phone	  
	  <tr>
	    <td valign="top">%%norm_font%%<b>Card Type:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$type%%norm_font_end%%</td>
	  </tr>
	  <tr>
	    <td valign="top">%%norm_font%%<b>Card Number:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$in->{cardnumber}%%norm_font_end%%</td>
	  </tr>
	  <tr>
	    <td valign="top">%%norm_font%%<b>Expires:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$in->{expmonth}/$in->{expyear}%%norm_font_end%%</td>
	  </tr>
	  <tr>
	    <td valign="top">%%norm_font%%<b>Order:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$num $purchase%%norm_font_end%%</td>
	  </tr>
	  <tr>
	    <td valign="top">%%norm_font%%<b>Total:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%\$$price%%norm_font_end%%</td>
	  </tr>
	</table>
	</td></tr>
	</table>|;
	
	return $invoice;
}


sub cc_make_finalize_form {
	my $S = shift;
	my $in = shift;
	
	my @fields = qw(
		fname     
		lname     
		baddr1  
		baddr2   
		bcity   
		bstate   
		bcountry  
		bzip      
		bphone 
		ctype     
		expmonth  
		expyear   
		cardnumber 
		ad_id 
		type 
		op 
		page 
		count
		months 
		pay_type);
	
	my $formkey = $S->get_formkey_element();
	my $form = qq|
	<form name="pay_final" METHOD="post" ACTION="%%rootdir%%">
	$formkey|;
		
	foreach my $field (@fields) {
		$form .= qq|
		<input type="hidden" name="$field" value="$in->{$field}">
		|;
	}
	
	$form .= qq|
		<center><input type="submit" name="final_pay" value="Place Order"></center>
	</form>
	<p>
	<hr width="70%" size=1 noshade>|;
	
	return $form;
}

	
sub cc_make_person_form {
	my $S = shift;
	my $in = $S->cgi->Vars();
   
    # Filter form input
	$in = $S->cc_filter_input($in);
	
  	my $state_list   = $S->cc_state_list($in->{bstate});
	my $country_list = $S->cc_country_list($in->{bcountry});
	
	my $form = qq|
	<table border=0 cellpadding=3 cellspacing=0>
	  <tr>
	    <td>
	      %%norm_font%%<font color="#ff0000">Name: (First Last)</font>%%norm_font_end%%
	    </td>
	    <td colpsan=2>
	      %%norm_font%%<input type="text" name="fname" size=15 value="$in->{fname}"> 
	      %%norm_font%%<input type="text" name="lname" size=15 value="$in->{lname}">%%norm_font_end%%
	    </td>
	  </tr>
	  <tr>
	    <td>
	      %%norm_font%%<font color="#ff0000">Address Line 1:</font>%%norm_font_end%%
	    </td>
	    <td colspan=2>
	      %%norm_font%%<input type="text" name="baddr1" size=25 value="$in->{baddr1}">%%norm_font_end%%
	    </td>
	  </tr> 
	  <tr>
	    <td>
	      %%norm_font%%Address Line 2:%%norm_font_end%%
	    </td>
	    <td colspan=2>
	      %%norm_font%%<input type="text" name="baddr2" size=25 value="$in->{baddr2}">%%norm_font_end%%
	    </td>
	  </tr> 
	  <tr>
	    <td>
	      %%norm_font%%<font color="#ff0000">City, State:</font>%%norm_font_end%%
	    </td>
	    <td colspan=2>
	      %%norm_font%%<input type="text" name="bcity" size=25 value="$in->{bcity}">, 
	      %%norm_font%%$state_list%%norm_font_end%%
	    </td>
	  </tr> 
	  <tr>
	    <td>&nbsp;</td>
		<td colspan=2>
		  %%norm_font%%<i>For non-US orders, leave state blank.</i>%%norm_font_end%%
		</td>
	  </tr>
	  <tr>
	    <td>
	      %%norm_font%%<font color="#ff0000">Country:</font>%%norm_font_end%%
	    </td>
	    <td colspan=2>
	      %%norm_font%%$country_list%%norm_font_end%%
	    </td>
	  </tr> 
	  <tr>
	    <td>
	      %%norm_font%%<font color="#ff0000">Postal Code:</font>%%norm_font_end%%
	    </td>
	    <td colspan=2>
	      %%norm_font%%<input type="text" name="bzip" size=10 value="$in->{bzip}">%%norm_font_end%%
	    </td>
	  </tr> 
 	  <tr>
	    <td>
	      %%norm_font%%Phone number:%%norm_font_end%%
	    </td>
	    <td colspan=2>
	      %%norm_font%%<input type="text" name="phone" size=15 value="$in->{phone}">%%norm_font_end%%
	    </td>
	  </tr> 
    </table>|;

	return $form;
}


sub cc_make_card_form {
	my $S = shift;
	my $in = $S->cgi->Vars();

    # Filter form input
	$in = $S->cc_filter_input($in);
	
	my $card_list = $S->cc_card_type_list($in->{ctype});
	my ($exp_month_form, $exp_year_form) = $S->cc_exp_list($in->{expmonth}, $in->{expyear});

	my $form = qq|
	<table border=0 cellpadding=3 cellspacing=0>
	  <tr>
	    <td>
		  %%norm_font%%<font color="#ff0000">Card Type:</font>%%norm_font_end%%
		</td>
	    <td>
		  %%norm_font%%$card_list%%norm_font_end%%
		</td>
	  </tr>
	  <tr>
	    <td>
		  %%norm_font%%<font color="#ff0000">Card Number:</font>%%norm_font_end%%
		</td>
	    <td>
		  %%norm_font%%<input type="text" name="cardnumber" value="$in->{cardnumber}" size=20>%%norm_font_end%%
		</td>
	  </tr>
	  <tr>
	    <td>
		  %%norm_font%%<font color="#ff0000">Expiration:</font>%%norm_font_end%%
		</td>
	    <td>
		  %%norm_font%%$exp_month_form $exp_year_form%%norm_font_end%%
		</td>
	  </tr>
	  
	</table>|;

	return $form;
}

	
sub cc_filter_input {
	my $S = shift;
	my $in = shift;
	
	foreach my $key (keys %{$in}) {
		$in->{$key} =~ s/[^a-zA-Z0-9\-\s\.,()'#]+//g;
		$in->{$key} =~ s/^\s*(.*)\s*$/$1/;
	}
	
	# Filter cardnumber
	$in->{cardnumber} =~ s/[^0-9\s\-]//g;
	
	return $in;
}


# Check for required input, check that input meets required criteria
# Adds error messages to $S->{CC_ERR} for easy portability.
sub cc_input_sanity_check {
	my $S = shift;
	my $in = shift;
	
	my $req_list = {
		fname      => 'a first name',
		lname      => 'a last name',
		baddr1     => 'an address',
		bcity      => 'a city',
		bcountry   => 'a country',
		bzip       => 'a postal code (zip code)',
		ctype      => 'a credit/debit card type',
		expmonth   => 'a card expiration month',
		expyear    => 'a card expiration year',
		cardnumber => 'a credit/debit card number'
	};	
	
	foreach my $key (keys %{$req_list}) {
		$S->{CC_ERR} .= qq|You must enter $req_list->{$key}<br>|
		  unless ($in->{$key});
	}
	
	# Check special cases
	if ($in->{bcountry} eq 'US') {
		$S->{CC_ERR} .= qq|You must enter a state for US orders<br>| 
		  unless ($in->{bstate});
	}
	
	my @date = localtime(time);
	if ($in->{expyear} && $in->{expmonth} && 
	    ($in->{expyear} <= $date[5]+1900) &&
		($in->{expmonth} < $date[4]+1)) {
		$S->{CC_ERR} .= qq|Your card seems to be expired. Did you enter the expiration date incorrectly?<br>| 
	}
	
	#count card digits
	my $cnum = $in->{cardnumber};
	$cnum =~ s/[^0-9]//g;
	my $digits = length $cnum;
	if ($digits != 16 && $digits != 13) {
		$S->{CC_ERR} .= qq|Credit card number seems to be the wrong length<br>|;
	}
	
	# Check card type
	if (($in->{ctype} eq 'visa' && ($in->{cardnumber} !~ /^4/)) ||
	    ($in->{ctype} eq 'mc' && ($in->{cardnumber} !~ /^5/))) {
		$S->{CC_ERR} .= qq|Credit card number does not match card type<br>|;
	} 

	if ($in->{ctype} ne 'visa' && $in->{ctype} ne 'mc') {
		$S->{CC_ERR} .= qq|Invalid card type<br>|;
	}

	return;
}


sub cc_card_type_list {
	my $S = shift;
	my $ctype = shift;
	
	my $list = qq|
	<select name="ctype" size=1>
	  <option value="">Select Card Type
	  <option value="visa">Visa
	  <option value="mc">MasterCard
	</select>|;
	
	$list =~ s/"$ctype"/"$ctype" SELECTED/;
	return $list;
}


sub cc_exp_list {
	my $S = shift;
	my ($mo, $yr) = @_;
	
	my $mo_list = qq|
	<select name="expmonth" size=1>
	  <option value="">Month|;
	
	for (my $i=1; $i<13; $i++) {
	  my $v = ($i < 10) ? "0".$i : $i;
	  $mo_list .= qq|
	  <option value="$v">$v|;
	}
	
	$mo_list .= qq|
	</select>|;
	
	$mo_list =~ s/"$mo"/"$mo" SELECTED/;
	
	my @now = localtime(time);
	
	my $yr_list = qq|
	<select name="expyear" size=1>
	  <option value="">Year|;
	
	for (my $i=0; $i<11; $i++) {
	  my $v = $now[5] + 1900 + $i;
	  $yr_list .= qq|
	  <option value="$v">$v|;
	}
	
	$yr_list .= qq|
	</select>|;
	
	$yr_list =~ s/"$yr"/"$yr" SELECTED/;
			  
	return ($mo_list, $yr_list);
}


sub cc_state_list {
	my $S = shift;
	my $bstate = shift;

	my $list = qq|
<select name="bstate" size=1>
<option value="">Select a state
<option value="AL">Alabama
<option value="AK">Alaska
<option value="AZ">Arizona
<option value="AR">Arkansas
<option value="CA">California
<option value="CO">Colorado
<option value="CT">Connecticut
<option value="DE">Delaware
<option value="FL">Florida
<option value="GA">Georgia
<option value="HI">Hawaii
<option value="ID">Idaho
<option value="IL">Illinois
<option value="IN">Indiana
<option value="IA">Iowa
<option value="KS">Kansas
<option value="KY">Kentucky
<option value="LA">Louisiana
<option value="ME">Maine
<option value="MD">Maryland
<option value="MA">Massachusetts
<option value="MI">Michigan
<option value="MN">Minnesota
<option value="MS">Mississippi
<option value="MO">Missouri
<option value="MT">Montana
<option value="NE">Nebraska
<option value="NV">Nevada
<option value="NH">New Hampshire
<option value="NJ">New Jersey
<option value="NM">New Mexico
<option value="NY">New York
<option value="NC">North Carolina
<option value="ND">North Dakota
<option value="OH">Ohio
<option value="OK">Oklahoma
<option value="OR">Oregon
<option value="PA">Pennsylvania
<option value="RI">Rhode Island
<option value="SC">South Carolina
<option value="SD">South Dakota
<option value="TN">Tennessee
<option value="TX">Texas
<option value="UT">Utah
<option value="VT">Vermont
<option value="VA">Virginia
<option value="WA">Washington
<option value="DC">Washington, DC
<option value="WV">West Virginia
<option value="WI">Wisconsin
<option value="WY">Wyoming
</select>|;

	$list =~ s/"$bstate"/"$bstate" SELECTED/;
	return $list;
}

sub cc_country_list {
	my $S = shift;
	my $bcountry = shift;
	
	my $list = qq|
<select name="bcountry" size=1>
<option value="">Select country
<option value="US">UNITED STATES
<option value="CA">CANADA
<option value="GB">UNITED KINGDOM
<option value="">--------
<option value="AF">AFGHANISTAN
<option value="AL">ALBANIA
<option value="DZ">ALGERIA
<option value="AS">AMERICAN SAMOA
<option value="AD">ANDORRA
<option value="AO">ANGOLA
<option value="AI">ANGUILLA
<option value="AQ">ANTARCTICA
<option value="AG">ANTIGUA AND BARBUDA
<option value="AR">ARGENTINA
<option value="AM">ARMENIA
<option value="AW">ARUBA
<option value="AU">AUSTRALIA
<option value="AT">AUSTRIA
<option value="AZ">AZERBAIJAN
<option value="BS">BAHAMAS
<option value="BH">BAHRAIN
<option value="BD">BANGLADESH
<option value="BB">BARBADOS
<option value="BY">BELARUS
<option value="BE">BELGIUM
<option value="BZ">BELIZE
<option value="BJ">BENIN
<option value="BM">BERMUDA
<option value="BT">BHUTAN
<option value="BO">BOLIVIA
<option value="BA">BOSNIA AND HERZEGOVINA
<option value="BW">BOTSWANA
<option value="BV">BOUVET ISLAND
<option value="BR">BRAZIL
<option value="IO">BRITISH INDIAN OCEAN TERRITORY
<option value="BN">BRUNEI DARUSSALAM
<option value="BG">BULGARIA
<option value="BF">BURKINA FASO
<option value="BI">BURUNDI
<option value="KH">CAMBODIA
<option value="CM">CAMEROON
<option value="CA">CANADA
<option value="CV">CAPE VERDE
<option value="KY">CAYMAN ISLANDS
<option value="CF">CENTRAL AFRICAN REPUBLIC
<option value="TD">CHAD
<option value="CL">CHILE
<option value="CN">CHINA
<option value="CX">CHRISTMAS ISLAND
<option value="CC">COCOS (KEELING) ISLANDS
<option value="CO">COLOMBIA
<option value="KM">COMOROS
<option value="CG">CONGO
<option value="CD">CONGO, THE DEMOCRATIC REPUBLIC OF THE
<option value="CK">COOK ISLANDS
<option value="CR">COSTA RICA
<option value="CI">COTE D'IVOIRE
<option value="HR">CROATIA
<option value="CU">CUBA
<option value="CY">CYPRUS
<option value="CZ">CZECH REPUBLIC
<option value="DK">DENMARK
<option value="DJ">DJIBOUTI
<option value="DM">DOMINICA
<option value="DO">DOMINICAN REPUBLIC
<option value="TP">EAST TIMOR
<option value="EC">ECUADOR
<option value="EG">EGYPT
<option value="SV">EL SALVADOR
<option value="GQ">EQUATORIAL GUINEA
<option value="ER">ERITREA
<option value="EE">ESTONIA
<option value="ET">ETHIOPIA
<option value="FK">FALKLAND ISLANDS (MALVINAS)
<option value="FO">FAROE ISLANDS
<option value="FJ">FIJI
<option value="FI">FINLAND
<option value="FR">FRANCE
<option value="GF">FRENCH GUIANA
<option value="PF">FRENCH POLYNESIA
<option value="TF">FRENCH SOUTHERN TERRITORIES
<option value="GA">GABON
<option value="GM">GAMBIA
<option value="GE">GEORGIA
<option value="DE">GERMANY
<option value="GH">GHANA
<option value="GI">GIBRALTAR
<option value="GR">GREECE
<option value="GL">GREENLAND
<option value="GD">GRENADA
<option value="GP">GUADELOUPE
<option value="GU">GUAM
<option value="GT">GUATEMALA
<option value="GN">GUINEA
<option value="GW">GUINEA-BISSAU
<option value="GY">GUYANA
<option value="HT">HAITI
<option value="HM">HEARD ISLAND AND MCDONALD ISLANDS
<option value="VA">HOLY SEE (VATICAN CITY STATE)
<option value="HN">HONDURAS
<option value="HK">HONG KONG
<option value="HU">HUNGARY
<option value="IS">ICELAND
<option value="IN">INDIA
<option value="ID">INDONESIA
<option value="IR">IRAN, ISLAMIC REPUBLIC OF
<option value="IQ">IRAQ
<option value="IE">IRELAND
<option value="IL">ISRAEL
<option value="IT">ITALY
<option value="JM">JAMAICA
<option value="JP">JAPAN
<option value="JO">JORDAN
<option value="KZ">KAZAKSTAN
<option value="KE">KENYA
<option value="KI">KIRIBATI
<option value="KP">KOREA, DEMOCRATIC PEOPLE'S REPUBLIC OF
<option value="KR">KOREA, REPUBLIC OF
<option value="KW">KUWAIT
<option value="KG">KYRGYZSTAN
<option value="LA">LAO PEOPLE'S DEMOCRATIC REPUBLIC
<option value="LV">LATVIA
<option value="LB">LEBANON
<option value="LS">LESOTHO
<option value="LR">LIBERIA
<option value="LY">LIBYAN ARAB JAMAHIRIYA
<option value="LI">LIECHTENSTEIN
<option value="LT">LITHUANIA
<option value="LU">LUXEMBOURG
<option value="MO">MACAU
<option value="MK">MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF
<option value="MG">MADAGASCAR
<option value="MW">MALAWI
<option value="MY">MALAYSIA
<option value="MV">MALDIVES
<option value="ML">MALI
<option value="MT">MALTA
<option value="MH">MARSHALL ISLANDS
<option value="MQ">MARTINIQUE
<option value="MR">MAURITANIA
<option value="MU">MAURITIUS
<option value="YT">MAYOTTE
<option value="MX">MEXICO
<option value="FM">MICRONESIA, FEDERATED STATES OF
<option value="MD">MOLDOVA, REPUBLIC OF
<option value="MC">MONACO
<option value="MN">MONGOLIA
<option value="MS">MONTSERRAT
<option value="MA">MOROCCO
<option value="MZ">MOZAMBIQUE
<option value="MM">MYANMAR
<option value="NA">NAMIBIA
<option value="NR">NAURU
<option value="NP">NEPAL
<option value="NL">NETHERLANDS
<option value="AN">NETHERLANDS ANTILLES
<option value="NC">NEW CALEDONIA
<option value="NZ">NEW ZEALAND
<option value="NI">NICARAGUA
<option value="NE">NIGER
<option value="NG">NIGERIA
<option value="NU">NIUE
<option value="NF">NORFOLK ISLAND
<option value="MP">NORTHERN MARIANA ISLANDS
<option value="NO">NORWAY
<option value="OM">OMAN
<option value="PK">PAKISTAN
<option value="PW">PALAU
<option value="PS">PALESTINIAN TERRITORY, OCCUPIED
<option value="PA">PANAMA
<option value="PG">PAPUA NEW GUINEA
<option value="PY">PARAGUAY
<option value="PE">PERU
<option value="PH">PHILIPPINES
<option value="PN">PITCAIRN
<option value="PL">POLAND
<option value="PT">PORTUGAL
<option value="PR">PUERTO RICO
<option value="QA">QATAR
<option value="RE">REUNION
<option value="RO">ROMANIA
<option value="RU">RUSSIAN FEDERATION
<option value="RW">RWANDA
<option value="SH">SAINT HELENA
<option value="KN">SAINT KITTS AND NEVIS
<option value="LC">SAINT LUCIA
<option value="PM">SAINT PIERRE AND MIQUELON
<option value="VC">SAINT VINCENT AND THE GRENADINES
<option value="WS">SAMOA
<option value="SM">SAN MARINO
<option value="ST">SAO TOME AND PRINCIPE
<option value="SA">SAUDI ARABIA
<option value="SN">SENEGAL
<option value="SC">SEYCHELLES
<option value="SL">SIERRA LEONE
<option value="SG">SINGAPORE
<option value="SK">SLOVAKIA
<option value="SI">SLOVENIA
<option value="SB">SOLOMON ISLANDS
<option value="SO">SOMALIA
<option value="ZA">SOUTH AFRICA
<option value="GS">SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS
<option value="ES">SPAIN
<option value="LK">SRI LANKA
<option value="SD">SUDAN
<option value="SR">SURINAME
<option value="SJ">SVALBARD AND JAN MAYEN
<option value="SZ">SWAZILAND
<option value="SE">SWEDEN
<option value="CH">SWITZERLAND
<option value="SY">SYRIAN ARAB REPUBLIC
<option value="TW">TAIWAN, PROVINCE OF CHINA
<option value="TJ">TAJIKISTAN
<option value="TZ">TANZANIA, UNITED REPUBLIC OF
<option value="TH">THAILAND
<option value="TG">TOGO
<option value="TK">TOKELAU
<option value="TO">TONGA
<option value="TT">TRINIDAD AND TOBAGO
<option value="TN">TUNISIA
<option value="TR">TURKEY
<option value="TM">TURKMENISTAN
<option value="TC">TURKS AND CAICOS ISLANDS
<option value="TV">TUVALU
<option value="UG">UGANDA
<option value="UA">UKRAINE
<option value="AE">UNITED ARAB EMIRATES
<option value="GB">UNITED KINGDOM
<option value="US">UNITED STATES
<option value="UM">UNITED STATES MINOR OUTLYING ISLANDS
<option value="UY">URUGUAY
<option value="UZ">UZBEKISTAN
<option value="VU">VANUATU
<option value="VE">VENEZUELA
<option value="VN">VIET NAM
<option value="VG">VIRGIN ISLANDS, BRITISH
<option value="VI">VIRGIN ISLANDS, U.S.
<option value="WF">WALLIS AND FUTUNA
<option value="EH">WESTERN SAHARA
<option value="YE">YEMEN
<option value="YU">YUGOSLAVIA
<option value="ZM">ZAMBIA
<option value="ZW">ZIMBABWE
</select>|;

	$list =~ s/"$bcountry"/"$bcountry" SELECTED/;
	return $list;
}


sub finish_donation {
	my $S = shift;
	my ($uid, $oid, $amount, $type) = @_;
	
	my ($rv, $sth) = $S->db_insert({
		INTO => 'donation_payments',
		COLS => 'uid, order_id, cost, pay_type, auth_date, final_date, paid',
		VALUES => qq|$uid, '$oid', '$amount', '$type', NOW(), NOW(), 1|
	});
	$sth->finish();
	
	if ($uid != -1) {
		my $to = $S->get_email_from_uid($uid);
		my $message = $S->{UI}->{BLOCKS}->{donate_email_success};
		$message =~ s/%%AMOUNT%%/$amount/g;
		my $subj = "Thank you for donating to $S->{UI}->{VARS}->{sitename}";
		$S->mail($to, $subj, $message);
	}
		
	return;
}


sub record_pledge {
	my $S = shift;
	my ($uid, $amount) = @_;
	my $oid = $S->_random_pass();

	my ($rv, $sth) = $S->db_insert({
		INTO => 'donation_payments',
		COLS => 'uid, order_id, cost, pay_type, auth_date, paid',
		VALUES => qq|$uid, '$oid', '$amount', 'pledge', NOW(), 0|
	});
	
	$sth->finish();

	if ($uid != -1) {
		my $to = $S->get_email_from_uid($uid);
		my $message = $S->{UI}->{BLOCKS}->{donate_email_pledge};
		$message =~ s/%%AMOUNT%%/$amount/g;
		my $subj = "Thank you for donating to $S->{UI}->{VARS}->{sitename}";
		$S->mail($to, $subj, $message);
	}
	
	return;
}
	
1;
