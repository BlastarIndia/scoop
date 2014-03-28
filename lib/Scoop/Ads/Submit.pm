
=head1 Ads/Submit.pm

This contains the code for submitting advertisements.

=head1 AUTHOR

Andrew Hurst <andrew@hurstdog.org>

=cut


package Scoop;

use strict;

my $DEBUG = 0;


=head1 Submitting Ads

Submitting ads is a 4 step process.  Each function will be apty named
submit_ad_step_N where N is what step you are in.  The end result will
be that the user has an ad submitted, and waiting to be approved for
display on the site.

=over 4

=item *
choose_submit_ad_step()

Since it would be rather unwieldy in ApacheHandler to have an option
for each of these steps, the url will be of the form 
%%rootdir%%/submitad/[stepnumber]
When ApacheHandler sees submitad, it calls this function, which decides
which step we're in and which function to call.

=cut

sub choose_submit_ad_step {
	my $S = shift;
	my $step = $S->cgi->param('nextstep') || 1;
	my $content = '';

	unless( $S->have_perm('submit_ad') ) {
		$S->{UI}->{BLOCKS}->{CONTENT} = $S->{UI}->{BLOCKS}->{no_submit_ad_perm};
		return;
	}

	# only 4 steps
	if( $step == 1 || $step >= 5 ) {
		$content = $S->submit_ad_step_1();
	} elsif( $step == 2 ) {
		$content = $S->submit_ad_step_2();
	} elsif( $step == 3 ) {
		$content = $S->submit_ad_step_3();
	} elsif( $step == 4 ) {
		$content = $S->submit_ad_step_4();
	}

	$S->{UI}->{BLOCKS}->{CONTENT} = $content;
}

=item *
submit_ad_step_1()

In this step the user will be presented with a page that shows the
disclaimer about ads on this site.  "We will not accept porn ads,
etc etc." or whatever the admin feels like writing.  The disclaimer
will be in a block named 'ad_step1_rules'.  The ad submitter will
then click on a 'continue >>' button to go to step 2.

=cut

sub submit_ad_step_1 {
	my $S = shift;

	my $content = qq|
<form name="step1form" action="%%rootdir%%/submitad" method="POST">
<input type="hidden" name="nextstep" value="2">
$S->{UI}->{BLOCKS}->{ad_step1_rules}
</form>
|;
	$content =~ s/%%NEXT_LINK%%/<input type="submit" name="continue" value="I Agree">/g;

	return $content;
}


=item *
submit_ad_step_2()

This second step in the ad submission process is where the user gets 
a chance to choose which ad type they want to purchase space for.  The
page will be in one big list format, with a short description of the ad
type, and an example ad shown beside it.  They will have a radio box
beside each ad type so they can choose it, and click continue if thats
the type they want.  If there is only 1 ad type for them to choose, this 
automatically redirects to step 3.

=cut

sub submit_ad_step_2 {
	my $S = shift;
	my $content = '';

	$content = $S->make_ad_type_list('let_choose', 'title');

	return $content;
}


=item *
submit_ad_step_3()

The third step is where the user fills out the parameters specific to
the ad type they selected.  If the ad type they selected only allows
for 3 different text lines, of 50 chars each, then thats all they get
to fill out.  If it allows for a .java file, then they can upload that
too.  Once they've filled out all of the entry fields, they can click
the Preview button which will preview their ad for them in the same
page.  It also adds a button, "Purchase Advertisement" in which they
will go on to step_4, to purchase the ad.

Any errors will be displayed at the top of the page.

This takes one argument, an error string.  If it is supplied it will be
put at the top of the page as an error.

=cut

sub submit_ad_step_3 {
	my $S = shift;
	my $err = shift;

	my $tmpl = $S->cgi->param('template');
	my $content = '';

	my $preview = 0;
	$preview = 1 if( $S->cgi->param('preview') eq 'Preview' );

	my $purchase = $S->cgi->param('purchase');
	return $S->submit_ad_step_4() if( defined($purchase) && $purchase eq 'Purchase Advertisement' );

	# first make sure they chose a valid template, if they didn't, then
	# generate the page from submit_ad_step_2
	unless( $S->is_valid_ad_tmpl( $tmpl ) ) {
		warn "Going back to adstep2 from adstep3 since '$tmpl' is not a valid template" if $DEBUG;
		return $S->submit_ad_step_2();
	}

	$err .= $S->check_ad_form_input($tmpl) if( $preview );

	my $reqd_fields = $S->get_ad_reqd_fields($tmpl);
	my $submit_form = $S->make_ad_edit_form('fromcgi', $tmpl );
	my $tmpl_info = $S->get_ad_tmpl_info($tmpl);

	# if it's a preview, still need to upload the file
	if ($reqd_fields->{ad_file} && $S->cgi->param('ad_file') && $S->cgi->param('ad_file') ne '') {
		my ($filename, $size, $up_err) = $S->save_file_upload($S->{UID}, $tmpl);
		if ($up_err && $up_err ne '') {
			$err .= "Error uploading: $up_err<br />\n";
		}
		# check to see if they uploaded a file during an earlier preview. if
		# so, remove that one to save space
		if (my $old_file = $S->session('tmp_ad_file')) {
			$S->remove_ad_file($S->{UID}, $old_file);
		}

		# update the param (so the image can be previewed) and the session (so
		# that it can be placed with the ad during step 4)
		$S->param->{ad_file} = $filename;
		$S->session('tmp_ad_file', $filename);
	} elsif ($reqd_fields->{ad_file} && (my $filename = $S->session('tmp_ad_file'))) {
		$S->param->{ad_file} = $filename;
	}

	# figure out how much this will cost them
	my $count = $S->cgi->param('purchase_size');
	my $cost = $tmpl_info->{cpm};
	my $totalcost = sprintf( "%.2f", $count * $cost / 1000 );

	my $cost_info = '';
	my $show_ad_box = '';
	my $check_url = '';
	my $order_count = $tmpl_info->{min_purchase_size};

	# if they are previewing, show their ad and their cost info.  Else just show the example ad.
	# also if they're previewing tell them to check their url, and make sure that the order box 
	# has the correct value.
	if( $preview ) {

		my $url = $S->filter_url($S->cgi->param('ad_url'));
		$show_ad_box = qq|%%BOX,show_ad,allcgi%%|;
		$order_count = $count;

		$cost_info = qq|<tr><td colspan="2" align="left"> %%norm_font%% $count impressions at \$$cost per thousand = <b>\$$totalcost</b> total cost %%norm_font_end%%
		</td></tr>
		<tr><td align="left" colspan="2">%%norm_font%% %%ad_confirm_text%% %%norm_font_end%% </td></tr>
<tr><td colspan="2">%%norm_font%% <b> Be sure you checked your url above! </b> %%norm_font_end%% </td></tr>
<tr><td colspan="2">&nbsp;</td></tr>
		|;

		$check_url = qq|
		  %%norm_font%%<font color="#ff0000">This is your link. 
		  <b>CLICK IT</b> at least once (opens in a new window) to make sure it works!</font>%%norm_font_end%%<br>
		  <b>%%smallfont%%[Link: <b><a href="$url" target="_blank">$url</a></b>]%%smallfont_end%%|;
#'
	} else {
		$show_ad_box = qq|%%BOX,show_ad,showfields,$tmpl%%|;
	}

	warn "show_ad_box -> $show_ad_box" if $DEBUG;

	$content .= qq|
<form name="submitadstep3" action="%%rootdir%%/submitad" method="POST" enctype="multipart/form-data">
<input type="hidden" name="nextstep" value="3">
<input type="hidden" name="template" value="$tmpl">
<input type="hidden" name="orig_tmpl" value="$tmpl">
<table border="0" cellpadding="1" cellspacing="1" width="99%"> 
<tr><td colspan="2" bgcolor="%%title_bgcolor%%">%%title_font%% Design Your Ad %%title_font_end%%</td></tr>
<tr><td colspan="2"> &nbsp; </td></tr>
<tr><td colspan="2" align="left">%%norm_font%%<font color="FF0000">$err</font>%%norm_font_end%%</td></tr>
<tr><td colspan="2" align="center">
  <table width="60%" border=0 cellpadding=5 cellspacing=0>
    <tr>
	  <td>%%norm_font%%<b>Preview:</b><p>
	      <center>
		  $show_ad_box 
		   <hr width="60%" size=1 noshade>
           $check_url
		   </center>
      </td></tr>
  </table>
</td></tr>
<tr><td colspan="2"> &nbsp; </td></tr>
<tr><td colspan="2" align="left">%%norm_font%% $tmpl_info->{submit_instructions} %%norm_font_end%% </td></tr>
<tr><td colspan="2"> &nbsp; </td></tr>
<tr><td align="right">%%norm_font%%<b>Order Size:</b>%%norm_font_end%%</td>
	<td align="left">%%norm_font%%<input type"text" name="purchase_size" value="$order_count" size="6"> %%norm_font_end%%</td></tr>
<tr><td>&nbsp;</td><td>%%norm_font%%<i>Minimum order is $tmpl_info->{min_purchase_size} impressions.  Maximum order is $tmpl_info->{max_purchase_size} impressions.<br>Order must be in multiples of 1000 impressions.</i>%%norm_font_end%%</td></tr>
$submit_form
<tr><td colspan="2"> &nbsp; </td></tr>
|;

	my $purchase_button = '';
	if( $preview && !$err) {
		$purchase_button = qq|&nbsp;&nbsp;&nbsp;&nbsp;<input type="submit" name="purchase" value="Purchase Advertisement">|;

		$content .= $cost_info;
	}

	$content .= qq|
<tr><td colspan="2" align="center"><input type="submit" name="preview" value="Preview"> $purchase_button</td></tr>|;

	$content .= qq|
	</table></form>
	<p>
	$S->{UI}->{BLOCKS}->{ad_submit_help}|;
	return $content;
}


=item *
submit_ad_step_4()

Checks to make sure that the input from step 3 is correct,
and saves. If the input is incorrect or there was any error
then the user returns to step 3. Then this displays the
billing page.  The billing page is generated by a box,
for maximum customization. That box is submit_ad_pay_box.

=cut

sub submit_ad_step_4 {
	my $S = shift;

	my $tmpl = $S->cgi->param('template');
	my $err = $S->check_ad_form_input($tmpl);
	my $new_id;

	if ( !$err ) {
		($new_id, $err) = $S->save_ad($tmpl);
	} else {
		$S->param->{purchase} = 'error';
		warn "Going back to step 3 since there was an error submitting the ad" if $DEBUG;
		return $S->submit_ad_step_3($err);
	}
	
	my $content = qq|%%BOX,submit_ad_pay_box,single_ad,$new_id%%|;

	return $content;
}

=back

=cut

1;
