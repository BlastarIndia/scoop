=head1 Ads/Info.pm

This contains the functions for getting information about advertisements.  Either
individual ads as in the case of get_ad_hash() or lots at once, with get_ad_list()

=head1 AUTHOR

Andrew Hurst <andrew@hurstdog.org>

=head1 FUNCTIONS

=over 4

=cut

package Scoop;

use strict;

my $DEBUG = 0;

=item *
get_ad_hash($adid, $source)

This takes an ad id and returns a hash of the values for that ad
If $source is 'cgi', then all values are taken from $S->cgi, else
they are retrieved from the db.

=cut

sub get_ad_hash {
	my $S = shift;
	my $adid = shift;
	my $source = shift;

	my $ad_info = {};

	if( $source eq 'cgi' ) {

		# only get these values since if the source is cgi, then its coming
		# from the submitad forms, so its a user, so they can't use any of
		# the rest of the values (like active, perpetual, etc)
		$ad_info->{ad_text1} = $S->filter_subject( $S->cgi->param('ad_text1') );
		$ad_info->{ad_text2} = $S->filter_subject( $S->cgi->param('ad_text2') );
		$ad_info->{ad_title} = $S->filter_subject( $S->cgi->param('ad_title') );
		$ad_info->{ad_url}   = $S->filter_url( $S->cgi->param('ad_url') );
		$ad_info->{ad_file}  = $S->filter_subject( $S->cgi->param('ad_file') );
		$ad_info->{ad_tmpl}  = $S->filter_subject( $S->cgi->param('template') );
		$ad_info->{sponsor}  = $S->{UID};
	} else {
		my ($rv, $sth) = $S->db_select({
			DEBUG	=> 0,
			FROM	=> 'ad_info',
			WHAT	=> 'ad_id,ad_tmpl,ad_file,ad_url,ad_text1,ad_text2,views_left,perpetual,last_seen,sponsor,active,example,ad_title,submitted_on,view_count,click_throughs,judged,reason,paid,purchase_size,purchase_price,judger,approved,pos,ad_sid',
			WHERE	=> qq| ad_id = $adid |,
		});

		if( $rv ) {
			$ad_info = $sth->fetchrow_hashref || {};
		}
	}

	return $ad_info;
}

=item *
get_adids_from_uid($uid)

Given a uid, returns an array of all of the ad_ids for the ads that
user has submitted.

=cut

sub get_adids_from_uid {
	my $S = shift;
	my $uid = shift;
	my $q_uid = $S->dbh->quote($uid);

	my $ret_array = [];

	my($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		WHAT	=> 'ad_id,active,views_left,judged,paid,approved,perpetual',
		FROM	=> 'ad_info',
		WHERE	=> "sponsor = $q_uid and example = 0",
		ORDER_BY	=> 'active desc, views_left desc',
		});

	if( $rv ) {
		while( my $r = $sth->fetchrow_hashref ) {
			push( @$ret_array, $r );
		}
	}

	return $ret_array;
}


=item *
get_ad_status($ad_hash)

Given a hashref of the ads info (all it really needs are the
fields judged, active, and paid) it will return a string describing
the ad as "approved", "disapproved", or "unjudged".

=cut

sub get_ad_status {
	my $S = shift;
	my $ad_hash = shift;
	my $status_msg = '';

	$Scoop::ASSERT && $S->assert( ref($ad_hash) eq 'HASH',
								'Get ad status not called with a hashref argument' );

	if( $ad_hash->{judged} == 0 ) {
		$status_msg .= 'unjudged';
	} elsif( $ad_hash->{approved} == 1 ) {
		$status_msg .= 'approved';
	} else {
		$status_msg .= 'disapproved';
	}

	return $status_msg;
}


=item *
get_ad_list( $limit, $order_by )

Gets all of the ads, limited by $limit, and ordered by 
$order_by.  sticks in a hashref, and returns

=cut

sub get_ad_list {
	my $S = shift;
	my $limit = shift || 15;
	my $order_by = shift || 'ad_id desc';
	my $adarray = ();

	my ($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		WHAT	=> 'ad_id,submitted_on,sponsor,ad_title,active,ad_tmpl,views_left,judged,approved,example',
		FROM	=> 'ad_info',
		LIMIT	=> $limit,
		ORDER_BY	=> $order_by,
		});

	if( $rv ) {
		while( my $r = $sth->fetchrow_hashref ) {
			push( @$adarray, $r );
		}
	}

	return $adarray;
}


=item *
get_unjudged_ad_list()

When called this returns an arrayref of hashrefs of all of the ads that haven't been
judged yet.  The has contains ad_id,sponsor,purchase_size, and purchase_price.  If
the var ads_judge_unpaid is 0 then this won't include ads that haven't been paid
for yet.

=cut

sub get_unjudged_ad_list {
	my $S = shift;
	my $adarray = ();

	my $get = {
		DEBUG	=> 0,
		WHAT	=> 'ad_id,sponsor,purchase_size,purchase_price',
		FROM	=> 'ad_info',
		WHERE	=> 'judged = 0 and example = 0',
	};
	
	unless ($S->{UI}->{VARS}->{ads_judge_unpaid}) {
		$get->{WHERE} .= ' and paid = 1';
	}
	
	my ($rv,$sth) = $S->db_select($get);

		
	while( my $r = $sth->fetchrow_hashref ) {
		push( @$adarray, $r );
	}

	return $adarray;
}

1;
