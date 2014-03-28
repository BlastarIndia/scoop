
=head1 Ads.pm

The functions in this file do the main controlling of how ads are displayed.  Though
since most of the display is done using boxes, this is more like a file full of 
utility functions for displaying ads. 

=head1 AUTHOR

Andrew Hurst B<andrew@hurstdog.org>

=head1 Functions

What follows is a bit of pod in front of the core functions, if they
are not documented here in pod, then they probably are with normal
hash-style comments, and they aren't essential to using the ads api.
=cut

package Scoop;

use strict;

my $DEBUG = 0;

=over 4

=item *
make_ad_type_list($let_choose, $title)

This makes a list of all of the ad types, with information about them.
This is used to generate the list for step 2.
$let_choose is either 'let_choose' or not.  If it is then it displays
radio buttons and a submit button at the bottom as well, and will
take you to step 3 of submitting ads.  If its not it just lists
the ads.

$title is 'title' or not.  If it is not 'title', then no title is generated.
used for the ad listing special page.

=cut

sub make_ad_type_list {
	my $S = shift;
	my $choice = shift || 'not';
	my $show_title = shift || 'none';
	my $content = '';

	# first get a list of all of the templates we need.
	my ($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		WHAT	=> 'type_template,type_name,short_desc,cpm,min_purchase_size,ad_id',
		FROM 	=> 'ad_types left join ad_info on (ad_types.type_template = ad_info.ad_tmpl AND ad_info.example = 1)',
		WHERE	=> 'ad_types.active = 1 and ad_info.example = 1',
		});

	my $ad_types = {};
	my $num = 0;
	if( $rv ) {
		while( my $tmp = $sth->fetchrow_hashref ) {
			$ad_types->{$tmp->{type_template}} = $tmp;
			$num++;
		}
	}
	$sth->finish();

	# If there's only one ad type, skip this step and just 
	# go straight on to step three with the one template name
	# ONLY if we were called from step 2 (thus the caller() hack)
	my $caller = (caller(1))[3];
	if ( $num == 1 && $caller =~ /submit_ad_step_2/ ) {
		my @templates = keys(%{$ad_types});
		$S->param->{'template'} = $templates[0];
		return $S->submit_ad_step_3();
	}
	
	# now use that info to display nicely, using the box 'show_ad' to show
	# the example.
	# 2 rows per ad.  A few conditionals in here for whether to let people choose
	# the ad or just look at the types.

	my $title = 'Advertisement type list';
	if( $choice eq 'let_choose' ) {
		$title = 'Choose the type of Advertisement';

		$content .= qq|
<form name="submitadstep2" action="%%rootdir%%/submitad" method="POST">
<input type="hidden" name="nextstep" value="3"> |;

	}

	my $fulltitle = '';
	if( $show_title eq 'title' ) {
		$fulltitle = qq|
<tr><td colspan="3" bgcolor="%%title_bgcolor%%">%%title_font%% $title %%title_font_end%%</td></tr>
|;
	}
	$content .= qq|
<table border="0" cellpadding="4" cellspacing="1" width="99%"> 
$fulltitle
<tr><td colspan="3"> &nbsp; </td></tr>
|;

	# loop through the ad templates, and display the examples.
	my $selected = ' CHECKED';
	for my $t ( sort keys %{$ad_types} ) {
		my $radio = ( $choice eq 'let_choose' ? qq|<input type="radio" name="template" value="$t"$selected>| : '&nbsp;' );
		$content .= qq|
		<tr><td valign="top" rowspan="2">$radio</td>
			<td valign="top" nowrap>%%norm_font%%<b> $ad_types->{$t}->{type_name}:</b>%%norm_font_end%%</td>
			<td valign="top">%%norm_font%% $ad_types->{$t}->{short_desc}<p>
							 \$$ad_types->{$t}->{cpm} per thousand impressions.<br />
						$ad_types->{$t}->{min_purchase_size} impression minimum purchase.%%norm_font_end%%</td>
		</tr>
		<tr><td valign="top">%%norm_font%% <b> Example: </b></td>
			<td valign="top"> %%BOX,show_ad,$ad_types->{$t}->{ad_id}%% </td></tr>
		<tr><td colspan="3" align="center"> <hr width="50%" /> </td></tr>
		|;
		$selected = '';
	}

	$content .= qq|<tr><td colspan="3">&nbsp;</td></tr>|;

	if( $choice eq 'let_choose' ) {
		$content .= qq|
		<tr><td colspan="3" align="center"><input type="submit" name="choosetemplate" value="Select Type and Continue"></td></tr>
</table></form>|;
	} else {
		$content .= q|
</table>|;
	}

	return $content;
}

=item *
ad_info_page()

Handles the op=adinfo, gets the ad_id and calls make_ad_info_table().  Also
does a bit of extra formatting to make it all look nice.

=cut

sub ad_info_page {
	my $S = shift;
	my $ad_id = $S->cgi->param('ad_id');

	my $uid = '';
	if( $ad_id =~ /^uid:(.+)$/ ) {
		warn "Found uid $1 in ad_info_page" if $DEBUG;
		$uid = $1;
	}
	warn "uid is '$uid' and ad_id is '$ad_id' in ad_info_page" if $DEBUG;

	my $content = q|
<table border="0" cellpadding="1" cellspacing="1" width="99%"> 
<tr><td colspan="2" bgcolor="%%title_bgcolor%%" align="left">%%title_font%% Advertisement Information Page %%title_font_end%%</td></tr>
<tr><td colspan="2"> &nbsp; </td></tr>
|;

	# in case of nonexistant users, have to check ad_id separately
	if( $ad_id eq 'uid:' ) {
			$content .= qq|
				<tr><td colspan="2" align="center">%%norm_font%%<i> No such user </i> %%norm_font_end%%</td></tr>
			|;
	} elsif( $uid ne '' ) {
		# now handle whether they are displaying all of a users' ads, or just
		# a single ad.  determined by 'uid:' test above

		my $nick = $S->get_nick_from_uid($uid);
		warn "nick is '$nick' in ad_info_page" if $DEBUG;

		# The "advertiser_admin_message" line below is a bit of a hack, 
		# but I need some way to keep every single advertiser from asking me 
		# the same question! :-/
		$content .= qq|
		<tr><td colspan="2">%%norm_font%% Ad listing for <a href="%%rootdir%%/user/$nick/info">$nick</a> %%norm_font_end%% </td></tr>
		<tr><td colspan="2">%%norm_font%% %%advertiser_admin_message%% %%norm_font_end%%</td></tr>	
		<tr><td colspan="2"> &nbsp; </td></tr>|;

		my @adids = @{ $S->get_adids_from_uid($uid) };

		# We're assuming here that @adids has all of the active ads first.
		my $last_type = 1;
		my $table;
		for my $a ( @adids ) {
		
			# Don't show inactive ads if I'm not the owner
			last if ($a->{active} == 0 && $S->{UID} != $uid && !$S->have_perm('ad_admin'));

			# Skip ads that aren't live unless we're the owner or we have ad_admin privs
			next if ((
						(($a->{views_left} <= 0) && !$a->{perpetual}) ||
						($a->{judged} != 1)		|| 
						($a->{paid} != 1)		||
						($a->{approved} != 1)
			  		 )					&&
					 $S->{UID} != $uid	&&
					 !$S->have_perm('ad_admin') );
			
			
			# if we're going from active to inactive ad display, say it
			if( $a->{active} ne $last_type ) {
				$table .= qq|
			<tr><td colspan="2" valign="top">%%norm_font%% <b>Inactive Ads:</b> %%norm_font_end%%</td></tr>
				|;
				$last_type = 0;
			}
				

			my $adtable = $S->make_ad_info_table($a->{ad_id});
			$table .= qq|
				<tr><td align="center"> $adtable </td></tr>
				<tr><td> &nbsp; </td></tr>
				|;
		}
		
		if ($table) {
			$content .= qq|
	<tr><td colspan="2" valign="top">%%norm_font%%<b> Active Ads: </b>%%norm_font_end%%</td></tr>
	$table|;
		} else {
			$content .= qq|
	<tr><td colspan="2">%%norm_font%% <i>No current ads found</i>%%norm_font_end%%</td></tr>|;		
		}
	} else {
		my $adtable = $S->make_ad_info_table($ad_id, 'show_sponsor', 'show_status');
		$content .= qq|
			<tr><td align="center"> $adtable </td></tr>
			<tr><td> &nbsp; </td></tr>
			|;
	}

	$content .= '</table>';
	$S->{UI}->{BLOCKS}->{CONTENT} = $content;

	return;
}

=item *
make_ad_info_table($ad_id, $show_sponsor, $show_status)

Takes an ad_id from the url and generates a nice table of all of the
information about the ad, including a preview, number of views and clicks
through, views left, sponsor (unless this in the user's personal ad info
page, and whatever other info eventually gets stuck to the ad.  Returns
a string of the table content.

If $show_sponsor is 'show_sponsor' then it will show the sponsor of the ad
as well, if not, it doesn't.

If $show_status is 'show_status' then it will show whether the ad is 
approved or disapproved as well.

=cut

sub make_ad_info_table {
	my $S = shift;
	my $ad_id = shift;
	my $show_sponsor = shift;
	my $show_status = shift;
	my $ad_hash = $S->get_ad_hash($ad_id,'db');

	unless( exists $ad_hash->{ad_id} ) {
		return "%%norm_font%% <i> No such ad $ad_id </i> %%norm_font_end%%";
	}

	my $is_owner = (($S->{UID} == $ad_hash->{sponsor}) || $S->have_perm('ad_admin')) ? 1 : 0;
	
	my $sponsor = '';
	if( $show_sponsor eq 'show_sponsor' ) {
		my $nick = $S->get_nick_from_uid($ad_hash->{sponsor});
		$sponsor = qq|<b>Sponser:</b> <a href="%%rootdir%%/user/$nick/info">$nick</a><br />|;
	}

	my $edit_link = '';
	if( $S->have_perm('ad_admin') ) {
		$edit_link = qq|
%%norm_font%% [ <a href="%%rootdir%%/admin/ads/edit?ad_id=$ad_hash->{ad_id}">edit</a> ] %%norm_font_end%% <br /><br />|;
	}

	my $renew_link = '';
	if( $S->{UI}->{VARS}->{allow_ad_renewal} && $is_owner && ($ad_hash->{paid} == 1) ) {
		$renew_link = qq|<a href="%%rootdir%%/renew?ad_id=$ad_hash->{ad_id}">Renew this ad campaign</a><br />|;
	}

	my $status_msg = '';
	if( $show_status eq 'show_status' ) {
		$status_msg =	'%%norm_font%% Status: <b>' .
						$S->get_ad_status($ad_hash) .
						'</b>%%norm_font_end%%<br />';
	}

	# don't need any divide by 0 errors here
	my $vc = $ad_hash->{view_count} || 1;
	my $percentage = sprintf("%.2f", $ad_hash->{click_throughs} / $vc * 100 );

	my $views_left = $ad_hash->{views_left};
	$views_left = 'infinite' if( $ad_hash->{perpetual} == 1 );
	$views_left = 0 unless( defined $views_left );

	my $admin_only_stuff = '';
	if( $S->have_perm('ad_admin') ) {
		my $paid = ($ad_hash->{paid} == 1 ? 'Yes' : 'No' );
		my $judge_nick = $S->get_nick_from_uid($ad_hash->{judger});
		$admin_only_stuff = qq|
<b>Initial Purchase Amount:</b> $ad_hash->{purchase_size}<br />
<b>Initial Purchase Cost:</b> \$$ad_hash->{purchase_price}<br />
<b>Paid:</b> $paid<br />
<b>Judge: $judge_nick</b> <br />
|;
	}

	my $apmsg = $ad_hash->{reason} || '<i>No message submitted.</i>';
	my $full_msg;
	$full_msg = qq|
	<b>Approve/Disapprove Message:</b><br /> $apmsg 
| if $is_owner;

	my $owner_info;
	$owner_info = qq|
		<b>Impressions:</b> $ad_hash->{view_count}<br />
		<b>Impressions Left:</b> $views_left<br />
		<b>Click Throughs:</b> $ad_hash->{click_throughs}<br />
		<b>C.T. Percentage:</b> $percentage%<br />
| if $is_owner;
	my $base_pay_url = $S->{UI}->{VARS}->{secure_site_url}.$S->{UI}->{VARS}->{rootdir}."/special/adpay?ad_id=$ad_hash->{ad_id}";

	if ($is_owner && ($ad_hash->{paid} != 1)) {
		$owner_info .= qq|
			<b>This ad has not been paid for.</b><br />|;
		$owner_info .= qq|	
			<a href="$base_pay_url;type=cc">Purchase with credit card</a><br \>| if ($S->{UI}->{VARS}->{payment_use_cc});
		$owner_info .= qq|	
			<a href="$base_pay_url;type=paypal">Purchase with Paypal</a><br \>| if ($S->{UI}->{VARS}->{payment_use_paypal});
	}		

	# this won't show up if they haven't already paid, so no worry of "pay for this ad" and "renew" on
	# the same ad.
	$owner_info .= qq|
		$renew_link|;

	my $content = qq|
<tr><td colspan="2"> &nbsp; </td></tr>
<tr><td align="center" valign="top"> $status_msg $edit_link %%BOX,show_ad,$ad_id%% <br />
%%norm_font%% $full_msg %%norm_font_end%%</td>
	<td valign="top"> %%norm_font%% $sponsor
		<b>Submitted on:</b> $ad_hash->{submitted_on}<br />
		$owner_info
		$admin_only_stuff
	</td></tr>
|;

	return $content;
}


1;
