package Scoop;
use strict;
my $DEBUG = 0;

# Linkpoint.pm
#
# CC processing module for the Linkpoint LPERL wrapper.
# See doc/Linkpoint.howto.


# Process a full payment immediately.
# Uses the LPERL ApproveSale function to do
# pre and post-auth at the same time.
sub cc_immediate_payment {
	my $S = shift;
	my $price = shift;
	my $args = shift;
	
	unless ($price) {
		$S->{CC_ERR} .= qq|No price received.<br>|;
	}

	# Make a new lperl
	my $lperl = new LPPERL();
	
	my $transaction_hash = $S->lperl_input_hash($price, $args);
	$transaction_hash->{ordertype} = 'SALE';
	
	# Ok, go ahead then
	my %cc_result;
	unless ($S->{CC_ERR}) {
		%cc_result = $lperl->curl_process($transaction_hash);
	}

	my $ret_result = $S->cc_backport_result($price, \%cc_result);
	
	return %{$ret_result};
}

# cc_pre_auth: Pre-authorize a transaction. 
sub cc_pre_auth {
	my $S = shift;
	my $price = shift;
	my $in = shift;
	
	# Make a new lperl
        my $lperl = new LPPERL();
	
	my $transaction_hash = $S->lperl_input_hash($price, $in);
        $transaction_hash->{ordertype} = 'PREAUTH';
	
	# Ok, go ahead then
	my %cc_result;
	unless ($S->{CC_ERR}) {
		%cc_result = $lperl->curl_process($transaction_hash);
	}
	
	my $ret_result = $S->cc_backport_result($price, \%cc_result);

	return %{$ret_result};
}

# $orders is a reference to an array of hashes which must
# include, on input, {orderID => $oid}. On return, 
# $orders is updated with statusCode and eerorMessage
sub cc_post_auth {
	my $S = shift;
	my $orders = shift;
	
	# Finish sale
	my $transaction_hash = {
		host			=>	$S->{CONFIG}->{linkpt_host},
		port			=>	$S->{CONFIG}->{linkpt_port},
		configfile		=>	$S->{CONFIG}->{linkpt_store},
		keyfile			=>	$S->{CONFIG}->{linkpt_keyfile},
		ordertype 		=>	'POSTAUTH'
	};

        my $lperl = new LPPERL();

	my @return_orders;
	foreach my $o (@{$orders}) {
		my $th = $transaction_hash;
		$th->{'oid'} = $o->{'orderID'};
		$th->{'chargetotal'} = $o->{'amount'};
		my %cc_result = $lperl->curl_process($transaction_hash);
	        my $ret_result = $S->cc_backport_result($th->{'chargetotal'}, \%cc_result);
		foreach my $k (keys %{$o}) {
			$ret_result->{$k} = $o->{$k};
		}
		push @return_orders, $ret_result; 
	}

	return \@return_orders;
}



# Create input hash for LPERL functions.
#
sub lperl_input_hash {
	my $S = shift;		
	my $price = shift;
	my $in = shift;
		
	# Pull out numeric part of address, if possible
	my $addrnum = $in->{baddr1};
	$addrnum =~ s/^\s*(\d+).*$/$1/g;
	
	# Make expiration year two-digit
	$in->{expyear} =~ s/.*(\d\d)$/$1/;

	my $transaction_hash = {
		host			=>	$S->{CONFIG}->{linkpt_host},
		port			=>	$S->{CONFIG}->{linkpt_port},
		configfile		=>	$S->{CONFIG}->{linkpt_store},
		keyfile			=>	$S->{CONFIG}->{linkpt_keyfile},
		chargetotal		=>	$price,
		cardnumber		=>	$in->{cardnumber},
		cardexpmonth		=>	$in->{expmonth},
		cardexpyear		=>	$in->{expyear},
		name			=>	"$in->{fname} $in->{lname}",
		address1		=>	$in->{baddr1},
		address2		=>	$in->{baddr2},
		city			=>	$in->{bcity},
		state			=>	$in->{bstate},
		country			=>	$in->{bcountry},
		zip			=>	$in->{bzip},
		phone			=>	$in->{phone},
		ip			=>	$S->{REMOTE_IP},
		transactionorigin	=>	'ECI',
		cvmindicator		=>	'not_provided',
		result			=> 	'LIVE'
	};
	
	# Use for testing purposes. Comment out in a live trans
	#$transaction_hash->{result} = 'GOOD';
	
	if ($addrnum) {
		warn "Addrnum is $addrnum\n";
		$transaction_hash->{addrnum} = $addrnum;
	}
	
	unless (
		$transaction_hash->{host} 	&&
		$transaction_hash->{port}		&&
		$transaction_hash->{configfile}	&&
		$transaction_hash->{keyfile}	  ) {
		$S->{CC_ERR} .= qq|Server is not properly configured to process this transaction.<br>|;
	}
	
	return $transaction_hash;
}


# Convert some of the new fields to old field names, so i don't have to rewrite every goddamn thing
sub cc_backport_result {
	my $S = shift;
	my $price = shift;
	my $cc_result = shift;

	my $ret_result = $cc_result;
	$ret_result->{chargetotal} = $price;
	$ret_result->{total} = $price;
	$ret_result->{statusCode} = ($cc_result->{'r_approved'} eq 'APPROVED') ? 1 : 0;
	$ret_result->{neworderID} = $cc_result->{r_ordernum};
	$ret_result->{statusMessage} = $cc_result->{r_error};
	
	return $ret_result;
}

1;
