=head1 Admin::Ads.pm

This is the main file for all Advertising administration in scoop.

=head1 AUTHOR

Andrew Hurst, B<hurstdog@kuro5hin.org>

=head1 FUNCTIONS

=head2 Display 

Following is some pod for the functions that control ad admin display.
These generate forms, and process them.  The first controls which
gets called.

=cut

package Scoop;

use strict;
my $DEBUG = 0;

=over 4

=item *
ad_admin_choice

This is the main function to choose between which type of administration
you are going to do while in the advertising admin tool.  Depending on the
type key given in the url this will decide what function to call to generate
the page.  If none is chosen, then it will call the ad_list function, to
list the latest ads and their status.

=cut 

sub ad_admin_choice {
	my $S = shift;

	my $type = $S->{CGI}->param('type');

	$S->{UI}->{BLOCKS}->{CONTENT} = $S->ad_admin_header();

	if( $type eq 'templatelist' ) {
		$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/Ad Template List/g;
		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->ad_admin_templatelist();
	} elsif( $type eq 'edit_example' ) {
		$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/Edit Example Ad/g;
		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->ad_admin_edit_example();
	} elsif( $type eq 'edit' ) {

		if( defined( $S->cgi->param('ad_id') )) {
			$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/Edit Advertisement/g;
		} else {
			$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/New Advertisement/g;
		}

		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->ad_admin_edit_ad();
	} elsif( $type eq 'adlist' ) {
		$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/Advertising List/g;
		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->ad_admin_adlist();
	} elsif( $type eq 'adprop' ) {
		$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/Edit Ad Properties/g;
		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->ad_admin_adprop();
	} elsif( $type eq 'judge' ) {
		$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/Judge Submissions/g;
		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->ad_admin_judge();

	# defaults to just submitted list
	} elsif( $type eq '' or !defined($type) ) {
		$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/Judge Submissions/g;
		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->ad_admin_judge();
	} else {
		$S->{UI}->{BLOCKS}->{CONTENT} =~ s/%%TYPE_TITLE%%/Bad Type/g;
		$S->{UI}->{BLOCKS}->{CONTENT} .= "There is no such ad editor type '$type',
		please check your link and try again";
	}

	$S->{UI}->{BLOCKS}->{CONTENT} .= q{
		</table>};

}


#-------------------------------------------------------------------------------
# The following functions control display, and what gets shown to the user
# Below these are the utilty functions
#-------------------------------------------------------------------------------

=item *
ad_admin_header

This generates the navigation bar at the top of every advertising administration
page.  It should have links to each of the relevant categories.

=cut

sub ad_admin_header {
	my $S = shift;

	# the leading characters are for sorting, and easy removal later in display
	my $ad_admin_types = {	Aadlist			=> "Ad Listing",
							Btemplatelist	=> "Template Listing",
							Cjudge			=> "Judge Submissions",
							Dedit			=> "New Advertisement",
							Eedit_example	=> "Edit Example Ad",
							Fadprop			=> "Edit Ad Properties",
						};
						# probably won't need these two types to be directly accessible
							#addetail	=> "Ad Detail",
							#advertiserdetail	=> "Advertiser Detail",

	my $header = q{<table border=0 cellpadding=0 cellspacing=0 width="99%"> };
	$header .= q{	<tr>
		<td bgcolor="%%title_bgcolor%%">%%title_font%%Advertising Admin : %%TYPE_TITLE%% %%title_font_end%%</td></TR>};

	# I like 3.  It can be anything, this is the number of
	# columns in the edit ads admin tool navigator
	my $type_cols = 3;

	$header .= qq{ <tr><td>
		<table border=0 cellpadding=0 cellspacing=0 width="99%">
		<tr><td colspan="$type_cols">&nbsp;</td></TR>
		};

	my $type_count = 0;
	my $type = $S->{CGI}->param('type') || 'judge';
	# if on the edit screen, and ad_id is set, then change the type so that the
	# New Ad link is still valid
	$type = 'edit_cur' if ($type eq 'edit' && $S->{CGI}->param('ad_id'));
	for my $t ( sort keys %{$ad_admin_types} ) {
		my $clean_t = $t;
		$clean_t =~ s/^\w//;

		$header .= q{ <tr> } if( ($type_count % $type_cols) == 0 );

		# first the link, then 'unlink' it if we're at that page
		my $link = qq{ %%norm_font%%<a href="%%rootdir%%/admin/ads/$clean_t">$ad_admin_types->{$t}</a>%%norm_font_end%% };
		$link = "%%norm_font%%$ad_admin_types->{$t}%%norm_font_end%%" if($type eq $clean_t);

		$header .= qq{ <td align="center">$link</td>
			};

		$type_count++;
		# if we reach the intended number of columns, add in a </TR><tr>
		if( ($type_count % $type_cols) == 0 ) {
			$header .= q{ </TR>
			};
		}
	}

	# now we need to even up the number of <td>'s etc, valid html and all
	while( ($type_count % $type_cols) != 0 ) {
		$type_count++;
		$header .= qq{ <td>&nbsp;</td> };

		$header .= q{ </TR> } if( ($type_count % $type_cols) == 0 );
	}

	
	# Get ad stats
	my ($rv, $sth) = $S->db_select({
		WHAT => 'count(*), sum(views_left)',
		FROM => 'ad_info',
		WHERE => 'active = 1'});
	
	my ($ad_count, $view_count) = $sth->fetchrow();
	$sth->finish();
	
	$header .= qq| </table>
		</td></TR>
		<tr><td>&nbsp;</td></TR>
		<tr><td align="center">%%norm_font%%Active ads: $ad_count, Active Impressions: $view_count%%norm_font_end%%</td></TR>|;

	return $header;
}


=item *
ad_admin_templatelist

Displays a neatly formatted list of the ad templates, for you to click on one to 
edit or to preview.  Also lists the number of ads using that template (this feature
is classified under NiftyInfo ;)

=cut

sub ad_admin_templatelist {
	my $S = shift;

	my $list = q{<tr><td>
		<table border=0 cellpadding=1 cellspacing=1 width="99%">
			<tr><th bgcolor="%%title_bgcolor%%">%%title_font%%<b>Template name</b>%%title_font_end%%</th>
			<th bgcolor="%%title_bgcolor%%"><b>&nbsp;</b></th>
			<th bgcolor="%%title_bgcolor%%"><b>&nbsp;</b></th>
			<th bgcolor="%%title_bgcolor%%"><b>&nbsp;</b></th>
			<th bgcolor="%%title_bgcolor%%">%%title_font%%<b>Use Count</b>%%title_font_end%%</th></tr>
		};


	my $tmpl_array = $S->get_ad_tmpl_list();
	my $tmpl_ex_hash = $S->get_ad_tmpl_examples();

	for my $t ( sort @$tmpl_array ) {
		$list .= qq|
	<tr><td align="center">%%norm_font%% $t %%norm_font_end%%</td>
		<td align="center">%%norm_font%%<a href="%%rootdir%%/admin/blocks/edit/default/$t">Edit Template</a>%%norm_font_end%%</td>
		<td align="center">%%norm_font%%<a href="%%rootdir%%/admin/ads/edit_example/$t">Edit Example</a>%%norm_font_end%%</td>
		<td align="center">%%norm_font%%<a href="%%rootdir%%/showad/$tmpl_ex_hash->{$t}[1]">Preview</a>%%norm_font_end%%</td>
		<td align="center">%%norm_font%%$tmpl_ex_hash->{$t}[0] %%norm_font_end%%</td>
	</TR>
		|;
	}

	$list .= q|
	</table>
	<p>%%norm_font%%To add a new template, use the <a href="%%rootdir%%/admin/blocks">block editor</a> to create a block with a name ending with "_ad_template".%%norm_font_end%%</p>
	</td></tr>
	|;
	return $list;
}


=item *
ad_admin_edit_example

This controls the /admin/ads/edit_example page.  It similar to the block editor, 
but has multiple fields, and controls what will be displayed in each example ad
(example ads show up when people are submitting ads)

=cut

sub ad_admin_edit_example {
	my $S = shift;
	my $to_edit = $S->{CGI}->param('template') || 'dummy';
	my $save = $S->{CGI}->param('write');
	my $get = $S->{CGI}->param('get');

	my $save_msg = '';
	my $form_hash = {};

	$save_msg = $S->save_ad($to_edit, 'example') if( $save && $save eq 'Save' && $to_edit ne 'dummy' );

	$form_hash = $S->get_example_ad($to_edit) if( $to_edit && $to_edit ne 'dummy' );

	my $templ_chooser = $S->make_tmpl_chooser($to_edit);

	my $edit_form = qq|
		<tr><td>

		<form name="edittmpl" method="POST" action="%%rootdir%%/admin/ads/edit_example" enctype="multipart/form-data">
		<input type="hidden" name="orig_tmpl" value="$to_edit">
		<input type="hidden" name="ad_id" value="$form_hash->{ad_id}">
		<table border=0 cellpadding=1 cellspacing=1 width="99%">
		$save_msg
		<tr><td align="center" colspan="2" ><input type="submit" name="write" value="Save">&nbsp;
		$templ_chooser
		&nbsp; <input type="submit" name="get" value="Get">
		</td></TR>
	|;

	my @path =  split( '/', $form_hash->{ad_file} );
	my $ul_filename = $path[ $#path ];

	if( $to_edit ne 'dummy' ) {
		$edit_form .= qq|
			<tr><td colspan="2" align="left"><br />%%norm_font%%<a href="%%rootdir%%/showad/$form_hash->{ad_id}" target="_new">Preview Example</A> (opens in new window)%%norm_font_end%%<br></td></TR>
		|;

	} else {
		$edit_form .= qq|
			<tr><td colspan="2"><br />&nbsp;<br />&nbsp;</td></TR>
			<tr><td colspan="2">&nbsp;</td></TR>
		|;
	}

	my $req_fields = $S->get_ad_reqd_fields( $to_edit );
	if( $req_fields->{ad_file} ) {
		$edit_form .= qq|
				<tr><td colspan="2" align="center">%%norm_font%%<i>The current image filename for this example is $ul_filename</i>%%norm_font_end%%</td></TR>|;
	}

	# if there was an error in saving the page, then get the values from cgi so they don't
	# have to reinput them
	my $source = 'fromhash';
	$source = 'fromcgi' if( $save_msg =~ /ERROR/ );

	$edit_form .= $S->make_ad_edit_form($source, $to_edit, $form_hash);
	$edit_form .= $S->adex_show_block($to_edit) if ($to_edit ne 'dummy');

	$edit_form .= q|
		</table>
		</FORM>
	|;

	return $edit_form;
}


=item *
ad_admin_edit_ad

Very similar to ad_admin_edit_example but this allows you to edit the
properties of a specific possibly active ad.  Generates a text box at
the top to allow you to choose which ad to edit.  Then generates a form
to allow you to set anything about the ad you're editing, including
views_left, active or not, first_day, perpetual, or any of the standard
ad parameters.

=cut

sub ad_admin_edit_ad {
	my $S = shift;
	my $form_adid = $S->{CGI}->param('ad_id') || 0;
	my $template = $S->{CGI}->param('template');
	my $save = $S->{CGI}->param('write');
	my $get = $S->{CGI}->param('get');
	my $delete = $S->{CGI}->param('delete') || 0;

	my $save_msg = '';
	my $form_hash = {};

	$template = $S->get_most_used_adtmpl() unless( defined $template && $template ne '' );

	warn "ad_id is $form_adid in make_ad_edit_form" if $DEBUG;
	my $ad_hash = $S->get_ad_hash($form_adid) if( $form_adid > 0 );

	$template = $ad_hash->{ad_tmpl} if $ad_hash->{ad_tmpl};
	
	$save_msg = $S->save_ad($template) if( $save &&
										( $form_adid > 0  && $save eq 'Save' && $delete == 0 ) ||
										( $form_adid == 0 && $save eq 'Create New Ad') );

	$save_msg = $S->delete_ad($form_adid) if( $save && $save eq 'Save' && $delete == 1 );

	my $tmpl_chooser = $S->make_tmpl_chooser( $template );

	# if they just saved or created a new ad set a few values from the form.
	if( $save_msg ne '' && !$delete) {
		$ad_hash->{judged} = $S->cgi->param('judged') || 0;
		$ad_hash->{approved} = $S->cgi->param('approved') || 0;
		$ad_hash->{active} = $S->cgi->param('active') || 0;
		$ad_hash->{active} = 0 unless( $ad_hash->{judged} == 1 && $ad_hash->{approved} == 1 );
		$ad_hash->{views_left} = $S->cgi->param('views_left') || 0;
		$ad_hash->{perpetual} = $S->cgi->param('perpetual') || 0;
		$ad_hash->{paid} = $S->cgi->param('paid') || 0;
	}

	my $save_value = 'Save';
	my $change_button = '';
	if( $form_adid == 0 ) {
		$save_value = 'Create New Ad';
		$change_button = q|<input type="submit" name="get" value="Change Template">|;
	}

	my $pos = $ad_hash->{pos} || '';

	# start the table and form
	my $edit_form = qq|
		<tr><td>
		<form name="edittmpl" method="POST" action="%%rootdir%%/admin/ads/edit" enctype="multipart/form-data">
		<input type="hidden" name="orig_tmpl" value="$template">
		<input type="hidden" name="ad_id" value="$form_adid">
		<input type="hidden" name="pos" value="$pos">		
		<table border="0" cellpadding="1" cellspacing="1" width="99%">
		<tr><td colspan="2">%%norm_font%% $save_msg %%norm_font_end%%</td></TR>
		<tr><td align="right"><input type="submit" name="write" value="$save_value"></td>
			<td>&nbsp;</td></tr>
		|;

	# if its a real ad put in a preview link
	if( $form_adid > 0 ) {
		$edit_form .= qq|
			<tr><td>&nbsp;</td>
				<td align="left" valign="center"><br />%%norm_font%%<a href="%%rootdir%%/showad/$ad_hash->{ad_id}" target="_new">Preview Ad</A> (opens in new window)%%norm_font_end%%<br></td></tr>
			<tr><td align="right">%%norm_font%% <b>Delete Ad:</b>%%norm_font_end%%</td>
				<td align="left">%%norm_font%% <input type="checkbox" name="delete" value="1"> %%norm_font_end%%</td></tr>
			<tr><td align="right">%%norm_font%% <b>Current Ad ID:</b>%%norm_font_end%%</td>
				<td align="left">%%norm_font%% $form_adid %%norm_font_end%%</td></tr>
		|;

	} else {
		$edit_form .= qq|
			<tr><td>&nbsp;</td></tr>
		|;
	}

	$edit_form .= qq|
		<tr><td align="right">%%norm_font%% <b>Ad Template:</b>%%norm_font_end%%</td>
			<td align="left">%%norm_font%% $tmpl_chooser %%norm_font_end%% $change_button</td></tr>
		|;

	my @path =  split( '/', $ad_hash->{ad_file} );
	my $ul_filename = $path[ $#path ];

	# change the template so we get the correct fields displayed
	$ad_hash->{ad_tmpl} = $template;
	$edit_form .= $S->ad_edit_admin_tools($ad_hash);

	my $req_fields = $S->get_ad_reqd_fields( $template );
	if( $req_fields->{ad_file} ) {
		$edit_form .= qq|
				<tr><td colspan="2" align="center">%%norm_font%% The current image filename for this ad is <i>$ul_filename</i>%%norm_font_end%%</td></TR>|;
	}

	# if they just saved the form, then give them the values from cgi so it looks like
	# they actually saved, instead of lost all the data.
	my $source = 'fromhash';
	$source = 'fromcgi' if( $save_msg ne '' );
	$edit_form .= $S->make_ad_edit_form($source, $template, $ad_hash);

	$edit_form .= q|
		</table>
		</FORM>
	|;

	return $edit_form;
}

=item *
ad_admin_adprop

From this page you can edit the properties of any ad type.  The CPM, the maximum size
of an image, max number of characters in any of the fields.  This function makes the
page, and decides which options to give you, depending on what are in the ad_template
for this type.

=cut

sub ad_admin_adprop {
	my $S = shift;
	my $to_edit = $S->{CGI}->param('template');

	my $save = $S->{CGI}->param('write') || 'dummy';
	my $get = $S->{CGI}->param('get');

	my $save_msg = '';
	my $save_it = ( ($save && $save eq 'Save' && $to_edit ne '') ? 1 : 0);
	my $form_hash = {};

	$save_msg = $S->save_adtype($to_edit) if $save_it;

	# we want the ad template chooser at the top
	my $templ_chooser = $S->make_tmpl_chooser($to_edit);
	my $form = qq|
		<tr><td>

		<form name="edittmpl" method="POST" action="%%rootdir%%/admin/ads/adprop" enctype="multipart/form-data">
		<input type="hidden" name="cur_adprop" value="$to_edit">
		<table border="0" cellpadding="2" cellspacing="2" width="99%">
		<tr><td align="center" colspan="2" ><input type="submit" name="write" value="Save">&nbsp;
		$templ_chooser
		&nbsp; <input type="submit" name="get" value="Get">
		</td></TR>
		<tr><td colspan="2">&nbsp;</td></TR>
		<tr><td colspan="2">%%norm_font%% $save_msg %%norm_font_end%%</td></TR>
		<tr><td colspan="2">&nbsp;</td></TR>
	|;

	# now we need the part for editing the values
	$form .= $S->make_adprop_editform($to_edit);

	$form .= qq{
		</table></FORM></td></TR>
	};

	return $form;
}

=item *
ad_admin_adlist()

Displays a list of all the ads on the site, with a little bit of info about each.
Doesn't page yet, like Story list, but will in the future.

=cut

sub ad_admin_adlist {
	my $S = shift;
	my $page = $S->{CGI}->param('page') || 1;
	my $next_page = $page + 1;
	my $last_page = $page - 1;
	my $num = $S->{UI}->{VARS}->{storylist};
	my $limit;
	my $get_num = $num + 1;
	my $offset = ($num * ($page - 1));
	
	if ($page > 1) {
		$limit = "$offset, $get_num";
	} else {
		$limit = "$get_num";
	}

	my $list = q{<tr><td>
		<table border="0" cellpadding="1" cellspacing="1" width="99%">
			<tr><TH bgcolor="%%title_bgcolor%%"> %%title_font%% &nbsp; %%title_font_end%%</TH>
			<TH bgcolor="%%title_bgcolor%%"> %%title_font%% <b>Ad Title</b>%%title_font_end%%</TH>
			<TH bgcolor="%%title_bgcolor%%">%%title_font%%<b>Sponsor</b>%%title_font_end%%</TH>
			<TH bgcolor="%%title_bgcolor%%">%%title_font%%<b>Status</b>%%title_font_end%%</TH>
			<TH bgcolor="%%title_bgcolor%%">%%title_font%%<b>Edit</b>%%title_font_end%%</TH>
			<TH bgcolor="%%title_bgcolor%%">%%title_font%%<b>Views Left</b>%%title_font_end%%</TH></TR>
		};

	my $ad_array = $S->get_ad_list($limit);

	my $color_count = 0;

	for my $a ( @$ad_array ) {

		my $bgcolor = '#ffffff';
		$bgcolor = '#eeeeee' if( ($color_count % 2) == 1 );
		$color_count++;

		my $sponsor = $S->get_nick_from_uid($a->{sponsor});

		my $status = '';
		if( $a->{judged} == 0 ) {
			$status = 'Unjudged';
		} elsif( $a->{judged} == 1 && 
		         $a->{approved} == 1 && 
				 !$a->{active} &&
				 $a->{views_left} > 0) {
			$status = 'Approved';
		} elsif ($a->{judged} == 1 && 
		         $a->{approved} == 1 && 
				 !$a->{active} &&
				 $a->{views_left} <= 0) {
			$status = 'Completed';
		} elsif( $a->{judged} == 1 && 
		         !$a->{approved} && 
				 !$a->{active}) {
			$status = 'Disapproved';
		} elsif( $a->{active} == 1 ) {
			$status = 'Active';
		} else {
			$status = 'Inactive';
		}

		my $vl = $a->{views_left};
		$vl = '(example)' if( $a->{example} == 1 );	
	
		my $active = ( $a->{active} ? 'Active' : '&nbsp;' );
		$list .= qq|
	<TR bgcolor="$bgcolor"><td align="left">%%norm_font%% $a->{ad_id}) %%norm_font_end%% </td>
		<td align="left">%%norm_font%% <a href="%%rootdir%%/showad/$a->{ad_id}">$a->{ad_title}%%norm_font_end%%</td>
		<td align="center">%%norm_font%%<a href="%%rootdir%%/user/$sponsor/ads">$sponsor</a>%%norm_font_end%%</td>
		<td align="center">%%norm_font%%$status%%norm_font_end%%</td>
		<td align="center" nowrap>%%norm_font%%[ <a href="%%rootdir%%/admin/ads/edit?ad_id=$a->{ad_id}">edit</a> ]%%norm_font_end%%</td>
		<td align="center">%%norm_font%% $vl %%norm_font_end%%</td>
	</TR>
		|;

	}

	$list .= qq|
		<tr><td COLSPAN="6">&nbsp;</td></TR>
		<tr>
			<td COLSPAN="3">%%norm_font%%<b>|;

	if ($last_page >= 1) {
		$list .= qq|&lt; <A HREF="%%rootdir%%/admin/ads/adlist?page=$last_page">Last $num</A>|;
	} else {
		$list .= '&nbsp;';
	}
	$list .= qq|</b>%%norm_font_end%%</td>
		<td ALIGN="right" COLSPAN="3">%%norm_font%%<b>|;
	
	if ( scalar( @$ad_array ) >= ($num + 1)) {
		$list .= qq|
		<A HREF="%%rootdir%%/admin/ads/adlist?page=$next_page">Next $num</A> &gt;%%norm_font_end%%|;
	} else {
		$list .= '&nbsp;';
	}
	
	$list .= qq|</b>%%norm_font_end%%</td>
	</TR>|;

	$list .= q|</table></td></TR>|;

	return $list;
}

=item *
ad_admin_judge()

This displays the list of the most currently submitted ads, that haven't
been judged yet.  The admin can choose whether or not to approve or dissapprove
the ad or may refrain from judgement.  If they approve, the ad will be set active
on the next run of ad_cron if they have made their payment.  If the admin wants it
to go active immediately they set the var 'activate_upon_approve' to 1. If they
dissaprove, they fill in a field saying why, and an email goes off to the
submitter with a text message the admin fills in.

=cut

sub ad_admin_judge {
	my $S = shift;
	my $submit = $S->cgi->param('Submit');
	my $err = '';
	my $content = '';

	if( defined( $submit ) && $submit eq 'Submit Choices' ) {
		$err = $S->save_ad_judgements();
	}

	$content = qq{<tr><td>
		<form action="%%rootdir%%/admin/ads/judge" method="POST" name="judgeform">
		<table border="0" cellpadding="1" cellspacing="1" width="99%">
			<tr><TH bgcolor="%%title_bgcolor%%"> %%title_font%% <b>Judge New Advertisements </b>%%title_font_end%%</TH>
			<TH bgcolor="%%title_bgcolor%%"> &nbsp; </TH></TR>
			<tr><td colspan="2">%%norm_font%% $err %%norm_font_end%%</td></TR>
			<tr><td colspan="2">&nbsp;</td></TR>
		};

	my $adref = $S->get_unjudged_ad_list();
	my @ads = ( defined( $adref ) ? @{ $adref } : () );
	my $adid_list = '';
	unless( scalar( @ads ) > 0 ) {
		$content .= "<tr><td>%%norm_font%% <i> No ads recently submitted. </i></td></TR>
				</table></form>";
		return $content;
	}

	for my $a ( @ads ) {
		$adid_list .= "$a->{ad_id},";
		my $sponsor = $S->get_nick_from_uid( $a->{sponsor} );
		$content .= qq|
			<tr><td align="center" valign="top"> %%BOX,show_ad,$a->{ad_id}%% </td>
				<td align="left">
					%%norm_font%%
					<b>Sponser:</b> <a href="%%rootdir%%/user/$sponsor/info">$sponsor</a> <br>
					<b>Purchase: $a->{purchase_size} (\$$a->{purchase_price}) <br>
					<b>Approve/Disapprove:</b> <select name="judgement_$a->{ad_id}">
					<option value="nojudgement">Choose Action
					<option value="approve">Approve
					<option value="disapprove">Disapprove
					</select><br>
					<b>Message:</b><br>
					<textarea rows="4" cols="20" name="reason_$a->{ad_id}"></textarea>
					%%norm_font_end%%
				</td>
			</TR>
			<tr><td colspan="2" align="center"><br /><hr width="50%" /><br /></td></TR>
			|;
	}
	$adid_list =~ s/,$//;

	$content .= qq|<input type="hidden" name="adid_list" value="$adid_list">
				<tr><td colspan="2" align="center"><input type="submit" name="Submit" value="Submit Choices"></td></TR>|;
	$content .= "</table></FORM>";

	return $content;
}

=item *
make_ad_edit_form($ad_hash, $source, $reqd, $hidden)

This generates a form that contains the fields needed to submit
an ad, or edit an ad, and returns it.

 $source - defines the source to get
 the values to populate the form.  Either
 'fromhash' to get from $ad_hash,
 'fromcgi' to get from $S->cgi, or 'blank'
 to leave the form blank. It must be one of
 the three.

 $tmpl - The name of the ad template this
 form is for.

 $ad_hash - if this is called from the
 admin page then the calling function will
 supply a hash of the needed values. optional

 $hidden - optional flag.  if 1 it makes
 this generate all hidden fields, w/out table
 rows.

=cut

sub make_ad_edit_form {
	my $S = shift;
	my $source = shift;
	my $tmpl = shift;
	my $ad_hash = shift;
	my $hidden = shift;

	# make sure they called this correctly
	$Scoop::ASSERT && $S->assert(	$source eq 'fromhash'	||
									$source eq 'fromcgi'	||
									$source eq 'blank'		);

	unless( $S->is_valid_ad_tmpl($tmpl) ) {
		warn "Returning an empty ad edit form since $tmpl is not a valid template" if $DEBUG;
		return '';
	}

	# these are needed to determine which fields to include and the max size for each
	# field, respectively
	my %required = %{ $S->get_ad_reqd_fields( $tmpl ) };
	my %tmpl_info = %{ $S->get_ad_tmpl_info( $tmpl ) };

	# to populate the form, we have a choice between 3 things, using the hash, using cgi, 
	# or leaving it blank.  Check here to see if using hash, and set %vals accordingly,
	# in each if(), check to see if using cgi and set accordingly.
	my %vals = ();
	if( $source eq 'fromhash' ) {
		%vals = %$ad_hash;
	}
	
	my $edit_form = '';
	if( $required{ad_file} ) {
		$vals{ad_file} = $S->cgi->param('ad_file') if( $source eq 'fromcgi' );
		if( $hidden ) {
			$edit_form .= qq|
				<input type="hidden" name="ad_file" value="$vals{ad_file}">
				|;
		} else {
			$edit_form .= qq|
				<tr><td align="right">%%norm_font%%<b>Image File:</b>%%norm_font_end%%</td>
					<td align="left">%%norm_font%%<input type="file" name="ad_file" value="$vals{ad_file}">%%norm_font_end%%</td>
				</tr>
				<tr><td>&nbsp;</td><td align="left">%%norm_font%%<i>The maximum file size allowed to upload for this ad type is <b>$tmpl_info{max_file_size} kilobytes</b></i>%%norm_font_end%%</td></tr>|;
		}
	}
	if( $required{ad_url} ) {
		$vals{ad_url} = $S->cgi->param('ad_url') if( $source eq 'fromcgi' );
		$vals{ad_url} = $S->filter_url($vals{ad_url});
		if( $hidden ) {
			$edit_form .= qq|
				<input type="hidden" name="ad_url" value="$vals{ad_url}">|;
		} else {
			$edit_form .= qq|
			<tr><td align="right">%%norm_font%%<b>Link:</b>%%norm_font_end%%</td>
				<td align="left">%%norm_font%%<input type="text" name="ad_url" size="40" value="$vals{ad_url}">%%norm_font_end%%</td>
			</tr>
			<tr><td>&nbsp;</td><td>%%norm_font%%<i>Example: http://www.kuro5hin.org/</i>%%norm_font_end%%</td></tr>|;
		}
	}
	if( $required{ad_title} ) {
		$vals{ad_title} = $S->cgi->param('ad_title') if( $source eq 'fromcgi' );
		$vals{ad_title} = $S->filter_subject($vals{ad_title});
		if( $hidden ) {
			$edit_form .= qq|
				<input type="hidden" name="ad_title" value="$vals{ad_title}">|;
		} else {
			$edit_form .= qq|
			<tr><td align="right">%%norm_font%%<b>Ad Title:</b>%%norm_font_end%%</td>
				<td align="left">%%norm_font%%<input type="text" name="ad_title" size="40" value="$vals{ad_title}" maxlength="$tmpl_info{max_title_chars}">%%norm_font_end%%</td>
			</tr>
			<tr><td>&nbsp;</td><td>%%norm_font%%<i>Example: Visit Kuro5hin.org</i>%%norm_font_end%%</td></tr>
			<tr><td>&nbsp;</td><td align="left">%%norm_font%%<i>The maximum number of characters allowed in the above title field is <b>$tmpl_info{max_title_chars}</b></i>%%norm_font_end%%</td></TR>|;
		}
	}
	if( $required{ad_text1} ) {
		$vals{ad_text1} = $S->cgi->param('ad_text1') if( $source eq 'fromcgi' );
		$vals{ad_text1} = $S->filter_subject($vals{ad_text1});
		if( $hidden ) {
			$edit_form .= qq|
				<input type="hidden" name="ad_text1" value="$vals{ad_text1}">|;
		} else {
			$edit_form .= qq|
			<tr><td align="right" valign="top">%%norm_font%%<b>Ad Text 1:</b>%%norm_font_end%%</td>
				<td align="left">%%norm_font%%<textarea name="ad_text1" rows="4" cols="40">$vals{ad_text1}</textarea>%%norm_font_end%%</td>
			</TR>
			<tr><td>&nbsp;</td><td>%%norm_font%%<i>Example: Technology and culture, from the trenches.</i>%%norm_font_end%%</td></tr>
			<tr><td>&nbsp;</td><td align="left">%%norm_font%%<i>The maximum number of characters allowed in the above text field is <b>$tmpl_info{max_text1_chars}</b></i>%%norm_font_end%%</td></TR>|;
		}
	}
	if( $required{ad_text2} ) {
		$vals{ad_text2} = $S->cgi->param('ad_text2') if( $source eq 'fromcgi' );
		$vals{ad_text2} = $S->filter_subject($vals{ad_text2});
		if( $hidden ) {
			$edit_form .= qq|
				<input type="hidden" name="ad_text2" value="$vals{ad_text2}">|;
		} else {
			$edit_form .= qq|
			<tr><td align="right">%%norm_font%%<b>Ad Text 2:</b>%%norm_font_end%%</td>
				<td align="left">%%norm_font%%<textarea name="ad_text2" rows="4" cols="40">$vals{ad_text2}</textarea>%%norm_font_end%%</td>
			</TR>
			<tr><td>&nbsp;</td><td align="left">%%norm_font%%<i>The maximum number of characters allowed in the above text field is <b>$tmpl_info{max_text2_chars}</b></i>%%norm_font_end%%</td></TR>|;
		}
	}
	if( $tmpl_info{allow_discussion} == 1 ) {
		$vals{discuss_ad} = $S->cgi->param('discuss_ad') if( $source eq 'fromcgi' );
		my $discuss_chk = ( $vals{discuss_ad} ? 'CHECKED' : '' );
		if( $hidden ) {
			$edit_form .= qq|
				<input type="hidden" name="discuss_ad" value="1" $discuss_chk>|;
		} else {
			$edit_form .= qq|
			<tr><td align="right">%%norm_font%%<b>Allow Comments:</b>%%norm_font_end%%</td>
				<td align="left">%%norm_font%%<input type="checkbox" value="1" name="discuss_ad" $discuss_chk>%%norm_font_end%%</td>
			</TR>
			<tr><td>&nbsp;</td><td align="left">%%norm_font%%<i>If you check this box a story will be created when you submit the ad so that people can comment on your advertisement</i>%%norm_font_end%%</td></TR>|;
		}
	}

	return $edit_form;
}


# A small function to make ad_admin_edit_ad not so large and
# full of html.
# Shows options only admins can change, and a few stats about the
# ad.
sub ad_edit_admin_tools {
	my $S = shift;
	my $ad_hash = shift;
	my $edit_form = '';

	my $sponsor = $S->get_nick_from_uid( $ad_hash->{sponsor} );

	my $active_checked    = ( $ad_hash->{active}    ? 'CHECKED' : '' );
	my $judged_checked    = ( $ad_hash->{judged}    ? 'CHECKED' : '' );
	my $approved_checked  = ( $ad_hash->{approved}  ? 'CHECKED' : '' );
	my $perpetual_checked = ( $ad_hash->{perpetual} ? 'CHECKED' : '' );
	my $paid_checked      = ( $ad_hash->{paid}      ? 'CHECKED' : '' );

	# only show this section if there are values to put in there.
	# i.e. only if they're editing an ad, not if its new
	if( $ad_hash->{ad_id} > 0 ) {

		my $judger = $S->get_nick_from_uid($ad_hash->{judger});
		$judger = $judger || 'no judge listed.';
		my $msg = $ad_hash->{reason} || 'no reason given.';

		my $status = $S->get_ad_status($ad_hash);

		$edit_form .= qq|
			<tr><td colspan="2">&nbsp;</td></TR>
			<tr><td>&nbsp;</td>
				<td align="left"> %%norm_font%% This ad is <b>$status</b>%%norm_font_end%%</td></TR>
			<tr><td>&nbsp;</td>
				<td align="left"> %%norm_font%% Submitted on <b>$ad_hash->{submitted_on}</b>%%norm_font_end%%</td></TR>
			<tr><td> &nbsp;</td>
				<td align="left"> %%norm_font%% Sponsored by <a href="%%rootdir%%/user/uid:$ad_hash->{sponsor}/">$sponsor</a> %%norm_font_end%%</td></TR>
			<tr><td>&nbsp;</td>
				<td align="left"> %%norm_font%% Judged by <b>$judger</b>%%norm_font_end%%</td></TR>
			<tr><td>&nbsp;</td>
				<td align="left"> %%norm_font%% Judge Message: <i>$msg</i>%%norm_font_end%%</td></TR>
			<tr><td>&nbsp;</td>|;
	} else {
		$edit_form .= qq|
			<tr><td colspan="2">&nbsp;</td></TR>|;
	}

	$edit_form .= qq|
		<tr><td align="right">%%norm_font%% <b>Active:</b>%%norm_font_end%%</td>
			<td align="left"><input type="checkbox" name="active" value="1" $active_checked> &nbsp;%%norm_font%% <i>Note: An ad can only be active if it has been judged and approved.</i> %%norm_font_end%% </td></TR>
		<tr><td align="right">%%norm_font%% <b>Judged:</b>%%norm_font_end%%</td>
			<td align="left"><input type="checkbox" name="judged" value="1" $judged_checked> </td></TR>
		<tr><td align="right">%%norm_font%% <b>Approved:</b>%%norm_font_end%%</td>
			<td align="left"><input type="checkbox" name="approved" value="1" $approved_checked> </td></TR>
		<tr><td align="right">%%norm_font%% <b>Perpetual:</b>%%norm_font_end%%</td>
			<td align="left"><input type="checkbox" name="perpetual" value="1" $perpetual_checked></td></TR>
		<tr><td align="right">%%norm_font%% <b>Paid for:</b>%%norm_font_end%%</td>
			<td align="left"><input type="checkbox" name="paid" value="1" $paid_checked></td></TR>
		<tr><td align="right">%%norm_font%% <b>Views Left:</b>%%norm_font_end%%</td>
			<td align="left">%%norm_font%%<input type="text" name="views_left" value="$ad_hash->{views_left}" size="7">%%norm_font_end%%</td></TR>
	|;

	return $edit_form;
}


# This makes the part of the example ad editor that displays the contents
# of the template block, the preview link, and the current image filename line
sub adex_show_block {
	my $S = shift;
	my $to_edit = shift;;

	my $ex_block = $S->{UI}->{BLOCKS}->{$to_edit};
	$ex_block =~ s/>/&gt;/g;
	$ex_block =~ s/</&lt;/g;
	$ex_block =~ s/%%/\|/g;

	my $edit_form = qq|
		<tr><td colspan="2"> &nbsp; </td></TR>
		<tr><td colspan="2" align="left">
			%%norm_font%%<i>Content of ad template </i>$to_edit &nbsp;&nbsp [ <a href="%%rootdir%%/admin/blocks/edit/default/$to_edit">Edit</a> ]%%norm_font_end%%<br><br>
			<hr width="20%" />
			<pre>
$ex_block
			</pre>
			<hr width="20%" />
		</td></TR>
	|;

	return $edit_form;
}


#  This looks at the template to edit, and changes the edit form fields to match.
#  $to_edit - the template to edit
sub make_adprop_editform {
	my $S = shift;
	my $to_edit = shift;
	my $cur_vals = $S->get_ad_tmpl_info( $to_edit );
	my $tmpl = $S->{UI}->{BLOCKS}->{$to_edit};
	my %reqd = %{ $S->get_ad_reqd_fields( $to_edit ) };

	my $editform = '';
	return $editform unless( defined( $to_edit ) && defined( $tmpl ) );

	# a checkbox to see if it is active.  make sure to note that it won't be made active
	# unless there is an ad example for it already.
	my $checked = ( $cur_vals->{active} ? 'CHECKED' : '' );
	$editform .= qq{
		<tr>
		<td align="right" width="60%">
			%%norm_font%% Activate this ad type. i.e. let people submit ads for this ad type.<br />
			<font color="#FF0000">NOTE: Unless there is an ad example for this ad type, you cannot make it active</font> %%norm_font_end%%
		</td>
		<td align="left">
			<input type="checkbox" name="active" value="1" $checked>
		</td></TR>
	}; #"

	# let them choose whether to allow ad discussions or not
	my $discuss_chk = ( $cur_vals->{allow_discussion} ? 'CHECKED' : '' );
	$editform .= qq{
		<tr>
		<td align="right" width="60%">
			%%norm_font%% <b>Allow Ad Discussions:</b> %%norm_font_end%%
		</td>
		<td align="left">
			<input type="checkbox" name="allow_discussion" value="1" $discuss_chk>
		</td></TR>
	}; #"

	# a spot for them to name this ad type, enter a short description, and put in some submit 
	# instructions as well.
	$editform .= qq{
		<tr>
		<td align="right" width="60%">
			%%norm_font%% <b> Ad Type Name:</b> %%norm_font_end%%
		</td>
		<td align="left">
			<input type="text" name="type_name" value="$cur_vals->{type_name}" size="30" maxlength="30">
		</td></TR>
	}; #"

	# always have a cpm input, a min purchase size and a max purchase size
	$editform .= qq{
		<tr><td align="right" width="60%">
			%%norm_font%% <b>CPM:</b> Cost per 1000 ad impressions. %%norm_font_end%%
		</td><td align="left" valign="center">
			%%norm_font%% \$ <input type="text" name="cpm" value="$cur_vals->{cpm}" size="6" maxlength="7">%%norm_font_end%%
		</td></TR>
		<tr><td align="right" width="60%">
			%%norm_font%% <b>Minimum Purchase Size:</b> %%norm_font_end%%
		</td><td align="left">
			%%norm_font%%<input type="text" name="min_purchase_size" value="$cur_vals->{min_purchase_size}" size="7" maxlength="7">%%norm_font_end%% 
		</td></TR>
		<tr><td align="right" width="60%">
			%%norm_font%% <b>Maximum Purchase Size:</b> %%norm_font_end%%
		</td><td align="left">
			%%norm_font%%<input type="text" name="max_purchase_size" value="$cur_vals->{max_purchase_size}" size="7" maxlength="7">%%norm_font_end%% 
		</td></TR>
		<tr><td align="right" width="60%">
			%%norm_font%% <b>Ad Position (integer):</b> %%norm_font_end%%
		</td><td align="left">
			%%norm_font%%<input type="text" name="pos" value="$cur_vals->{pos}" size="7" maxlength="7">%%norm_font_end%% 
		</td></TR>
		
	}; #"

	# if it has TITLE in it, let them set max title size
	if( $reqd{ad_title} ) {
		$editform .= qq{
		<tr><td align="right" width="60%">
			%%norm_font%% Maximum number of characters to allow in the <b>TITLE</b> field of this ad type. %%norm_font_end%%
		</td><td align="left">
			%%norm_font%%<input type="text" name="max_title_chars" value="$cur_vals->{max_title_chars}" size="4" maxlength="5">
%%norm_font_end%%
		</td></TR>
		}; #"
	} else {
		$editform .= qq{ <input type="hidden" name="max_title_chars_isnthere" value="1"> };
	}

	# check for TEXT1
	if( $reqd{ad_text1} ) {
		$editform .= qq{
		<tr><td align="right" width="60%">
			%%norm_font%% Maximum number of characters to allow in the <b>TEXT1</b> field of this ad type. %%norm_font_end%%
		</td><td align="left">
			%%norm_font%%<input type="text" name="max_text1_chars" value="$cur_vals->{max_text1_chars}" size="4" maxlength="5">%%norm_font_end%%
		</td></TR>
		}; #"
	} else {
		$editform .= qq{ <input type="hidden" name="max_text1_chars_isnthere" value="1"> };
	}

	# check for TEXT2
	if( $reqd{ad_text2} ) {
		$editform .= qq{
		<tr><td align="right" width="60%">
			%%norm_font%% Maximum number of characters to allow in the <b>TEXT2</b> field of this ad type. %%norm_font_end%%
		</td><td align="left">
			%%norm_font%%<input type="text" name="max_text2_chars" value="$cur_vals->{max_text2_chars}" size="4" maxlength="5">%%norm_font_end%%
		</td></TR>
		}; #"
	} else {
		$editform .= qq{ <input type="hidden" name="max_text2_chars_isnthere" value="1"> };
	}

	# check for files to upload
	if( $reqd{ad_file} ) {
		$editform .= qq{
		<tr><td align="right" width="60%">
			%%norm_font%% Maximum size of files advertisers are allowed to upload for this ad type, in Kilobytes. %%norm_font_end%%
		</td><td align="left">
			%%norm_font%%<input type="text" name="max_file_size" value="$cur_vals->{max_file_size}" size="4" maxlength="7">%%norm_font_end%%
		</td></TR>
		}; #"
	} else {
		$editform .= qq{ <input type="hidden" name="max_file_size_isnthere" value="1"> };
	}

	# now for the short description field and the submit_instructions field
	# make sure that these going into the textareas are html friendly


	$editform .= qq{
		<tr><td colspan="2">&nbsp;</td></TR>
		<tr><td align="center" colspan="2">
		%%norm_font%%<b>Short Description:</b> This is what the advertiser will see next to an example, when choosing the ad type to submit.<br />(Note: Max 255 characters here).  This should be plain text.%%norm_font_end%%<br>
		%%norm_font%%<textarea name="short_desc" rows="4" cols="50">$cur_vals->{short_desc}</textarea>%%norm_font_end%%
		</td></TR>
		<tr><td colspan="2">&nbsp;</td></TR>
		<tr><td align="center" colspan="2">
		%%norm_font%%<b>Submit Instructions:</b> This is for any special instructions for submitting this type of ad.This will display on the page where the user will set the values for their ad submission, url, title, etc.<br /> HTML is allowed here.%%norm_font_end%%<br>
		%%norm_font%%<textarea name="submit_instructions" rows="6" cols="50">$cur_vals->{submit_instructions}</textarea>%%norm_font_end%%
		</td></TR>
	};


	return $editform;	
}

=pod

=back

=head2 Utility

The following are all more general use functions, that might be of some use
to modules other than Scoop::Admin::Ads

=over 4

=cut

#-------------------------------------------------------------------------------
# What follows are utility functions, i.e. ones that will get a list of all
# of the ad templates, generate a select box for them, get a hash of the
# values for them, etc
#-------------------------------------------------------------------------------

=item *
save_ad($tmpl, $example)

Checks the input by calling $S->check_ad_form_input, and
returns its error message if there is one.  Otherwise
saves the ad with the template $tmpl.  If $example is 1
sets the example field to 1 in the ad_info table as well.
Written so that functions that display the edit forms don't
have to check the input themselves.

The ad to save (when updating) is determined by the field
ad_id.

=cut

sub save_ad {
	my $S = shift;
	my $ad_tmpl = shift;
	my $example = shift;

	my $err = '';
	my $orig = $S->cgi->param('orig_tmpl');

	if( $orig && ($ad_tmpl ne $orig)) {
		return qq|<tr><td colspan="2">%%norm_font%%<font color="#FF0000">ERROR: Sorry, but you cannot change the template after an ad has been created.</font>%%norm_font_end%%</td></TR>|;
	}

	# test the input, to make sure that the submitted ad checks out
	# with the rules for this ad type.  It can be argued that admins should be 
	# able to write whatever they want for an ad, so this should check ad_admin perms as well,
	# I say change the ad rules if you want to break them.
	my $test_err;
	$test_err = $S->check_ad_form_input( $ad_tmpl ) unless ($S->have_perm('ad_admin'));
	unless( $test_err eq '' ) {
		return qq|%%norm_font%%<font color="FF0000"> $test_err </font>%%norm_font_end%%|;
	}

	my $reqd = $S->get_ad_reqd_fields($ad_tmpl);
	warn "reqd->ad_file is '$reqd->{ad_file}'" if $DEBUG;
	warn "cgi->param('ad_file') is " . $S->cgi->param('ad_file') if $DEBUG;

	# below, I change the required hash.  We don't want to change the value of an existing file
	# if they didn't input a value.  i.e. don't require them to upload a file everytime they change
	# the example, so set the required hash accordingly
	my ($filename, $size);
	if( $S->cgi->param('ad_file') && $S->cgi->param('ad_file') ne '' && $reqd->{ad_file} ) {
		warn "file is " . $S->cgi->param('ad_file') if $DEBUG;
		my $adver_id = ( $example ? 'example' : $S->{UID} );
		# save the upload, and return error if need be
		($filename, $size, $err) = $S->save_file_upload($adver_id,$ad_tmpl);
		if( $err && $err ne '' ) {
			return qq|
			<tr><td colspan="2">
				%%norm_font%%<font color="#FF0000">ERROR: $err</font>%%norm_font_end%%</td></TR>|;
		}
		$reqd->{ad_file} = 1;
	} elsif ($reqd->{ad_file} && ($filename = $S->session('tmp_ad_file'))) {
		delete $S->{SESSION}->{tmp_ad_file};
		$reqd->{ad_file} = 1;
	} else {
		$reqd->{ad_file} = 0;
	}

	# first make sure we quote all of the values we'll need
	my %vals = ();
	$vals{ad_id}    = $S->{CGI}->param('ad_id');
	$vals{ad_tmpl}  = $S->filter_subject( $S->{CGI}->param('orig_tmpl') );
	$vals{ad_url}   = $S->filter_url( $S->{CGI}->param('ad_url') );
	$vals{ad_title} = $S->filter_subject( $S->{CGI}->param('ad_title') ) unless ($S->have_perm('ad_admin'));
	$vals{ad_title} = $S->{CGI}->param('ad_title') if ($S->have_perm('ad_admin'));
	$vals{ad_text1} = $S->filter_subject( $S->{CGI}->param('ad_text1') ) unless ($S->have_perm('ad_admin'));
	$vals{ad_text1} = $S->{CGI}->param('ad_text1') if ($S->have_perm('ad_admin'));
	$vals{ad_text2} = $S->filter_subject( $S->{CGI}->param('ad_text2') ) unless ($S->have_perm('ad_admin'));
	$vals{ad_text2} = $S->{CGI}->param('ad_text2') if ($S->have_perm('ad_admin'));
	$vals{ad_file}  = $filename;

	if( $example ) {
		$vals{example}   = 1;
		$reqd->{example} = 1;
	}

	# ad_tmpl is always required
	$reqd->{ad_tmpl} = 1;

	# If they are an admin editing an ad let them mess with the display
	# settings
	if( $S->have_perm('ad_admin') && ($S->cgi->param('op') eq 'admin') ) {

		$vals{judged}   = $S->cgi->param('judged') || 0;
		$reqd->{judged} = 1;

		$vals{approved}   = $S->cgi->param('approved') || 0;
		$reqd->{approved} = 1;

		# only let them activate it if its been judged
		$vals{active}   = $S->cgi->param('active') || 0;
		$vals{active}   = 0 unless( $vals{judged} == 1 && $vals{approved} == 1 );
		$reqd->{active} = 1;

		$vals{views_left}   = $S->cgi->param('views_left');
		$reqd->{views_left} = 1;

		$vals{perpetual}   = $S->cgi->param('perpetual') || 0;
		$reqd->{perpetual} = 1;
		
		$vals{paid}    = $S->cgi->param('paid') || 0;
		$reqd->{paid}  = 1;
	}

	my $tmpl_info = $S->get_ad_tmpl_info($vals{ad_tmpl});
	$vals{pos} = $tmpl_info->{pos};
	$reqd->{pos}  = 1;

	# if they're submitting an ad, store a bit more info
	if( $S->cgi->param('op') eq 'submitad' ) {
		$vals{views_left}   = $S->cgi->param('purchase_size');
		$reqd->{views_left} = 1;

		$vals{purchase_size} = $vals{views_left};
		$reqd->{purchase_size} = 1;

		$vals{purchase_price} = $tmpl_info->{cpm} * $vals{purchase_size} / 1000;
		$reqd->{purchase_price} = 1;
	}

	# if the ad_id is > 0 and they have permission to edit ads,
	# then let them update.  Otherwise if its just > 0, tell
	# them they don't have permission to update, else insert the new ad
	my ($tmp_err, $new_id);
	if( ($vals{ad_id} > 0) && $S->have_perm('ad_admin') ) {
		$err .= $S->update_ad( \%vals, $reqd );

	} elsif( $vals{ad_id} > 0)  {
		$err .= qq|%%norm_font%%<font color="#FF0000">ERROR: Sorry but you don't have permission to update ads.</font>%%norm_font_end%%|;

	} else {

		# inserting a new ad. Create the story too if need be.
		($new_id, $tmp_err) = $S->insert_ad( \%vals, $reqd );
		$err .= $tmp_err;

		$vals{ad_id} = $new_id;

		my $sid = '';
		my $story_err = '';
		if( $tmpl_info->{allow_discussion} && $S->cgi->param('discuss_ad') == 1 ) {
			$story_err = $S->make_ad_story(\%vals);
			$err .= $story_err;
		}

	}

	return ($new_id, $err);
}

=item *
update_ad(\%vals,\%reqd)

Simply does a $S->db_update on the ad_info table for the
required values (from %reqd) in the %vals hash. It is assumed that
the keys of the hash are field names for the values, and
that the values are unquoted coming in.

This should only be called from $S->save_ad

=cut

sub update_ad {
	my $S = shift;
	my $unquote_vals = shift;
	my $reqd = shift;
	my $err = '';
	my $vals = {};

	# quote everything
	for my $k ( keys %$unquote_vals ) {
		$vals->{$k} = $S->dbh->quote($unquote_vals->{$k});
	}

	# small loop to generate a correct update statement based on what's required
	my $set = '';
	for my $p ( keys %$vals ) {
		next if( $p eq 'ad_id' );
		$set .= qq| $p = $vals->{$p},| if( $reqd->{$p} );
	}

	$set =~ s/,$//;

	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'ad_info',
		SET		=> $set,
		WHERE	=> qq| ad_id = $vals->{ad_id} |,
	});

	unless( $rv ) {
		$err .= qq|<font color="#FF0000">ERROR: There was a problem updating the example ad.  Values not updated.   The database said: "$DBI::errstr"</font>|;
	} else {
		$err .= qq|<font color="#00AA00">Advertisement updated correctly.</font>|;
	}

	return $err;
}

=item *
insert_ad(\%vals,\%reqd)

Inserts the values from \%vals into ad_info if they
are required as determined by \%reqd.  It is assumed that
the keys of the hash are field names for the values, and
that the values are unquoted coming in.

This should only be called from $S->save_ad

=cut

sub insert_ad {
	my $S = shift;
	my $unquote_vals = shift;
	my $reqd = shift;
	my $is_ex = shift;
	my $err = '';
	my $vals = {};

	# quote everything
	for my $k ( keys %$unquote_vals ) {
		$vals->{$k} = $S->dbh->quote($unquote_vals->{$k});
	}

	# small loop to generate the correct columns and values for the insert
	my $cols = '';
	my $values = '';
	for my $p ( keys %$vals ) {
		next if( $p eq 'ad_id' );

		if( $reqd->{$p} ) {
			$cols .= "$p, ";
			$values .= "$vals->{$p}, ";
		}
	}

	# add in sponsor and date fields
	$cols .= 'sponsor, submitted_on';
	$values .= "$S->{UID}, NOW()";

	my ($rv,$sth) = $S->db_insert({
		INTO	=> 'ad_info',
		COLS	=> $cols,
		VALUES	=> $values,
	});
	
	unless( $rv ) {
		$err .= qq|<font color="#FF0000">ERROR: There was a problem inserting the ad.  Values not updated.   The database said: "$DBI::errstr"</font>|;
	} else {
		$err .= qq|<font color="#00AA00">Successfully created advertisement</font>|;
	}
    
	($rv, $sth) = $S->db_select({
		WHAT => 'LAST_INSERT_ID()',
		FROM => 'ad_info'});
	my $new_id = $sth->fetchrow();
	
	return ($new_id, $err);
}

=item *
delete_ad( $adid )

Deletes the ad identified by $adid.  Should only be called from 
ad_admin_edit_ad.  Since its possible to delete an example ad from the
edit ad interface, this function tests to see if the ad thats being
deleted is an example ad.  If its an example, it disables that ad type
as well, and returns a message that it had to.

=cut

sub delete_ad {
	my $S = shift;	
	my $adid = shift || 0;
	my $q_adid = $S->dbh->quote($adid);

	# don't delete non-existant ads!  This is mostly to make sure its not called wrong.
	$Scoop::ASSERT && $S->assert( $adid > 0 );

	my ($rv,$sth);
	my $retmsg = '';
	my $adhash = $S->get_ad_hash($adid, 'db');
	if( $adhash->{example} == 1 ) {
		# uh oh, they're deleting an example.  Let them know, and disable
		# this ad type.
		$retmsg = q|<font color="FF0000">WARNING:  You have just deleted an example ad!  Because of this, I disabled that ad type as well.  Please create another example ad (via <a href="%%rootdir%%/admin/ads/edit_example">the example ad edit menu</a>) and then re-enable this ad type if you want people to continue submitting ads of this type.</font><br />|;

		my $q_tmpl = $S->dbh->quote($adhash->{ad_tmpl});
		($rv,$sth) = $S->db_update({
			DEBUG	=> 0,
			WHAT	=> 'ad_types',
			SET		=> 'active = 0',
			WHERE	=> qq| type_template = $q_tmpl |,
			});
	}

	($rv,$sth) = $S->db_delete({
		DEBUG	=> 0,
		FROM	=> 'ad_info',
		WHERE	=> qq| ad_id = $q_adid|,
		});

	if($rv) {
		$retmsg .= qq|<font color="00AA00">Ad #$adid deleted.</font>|;
	} else {
		$retmsg .= qq|<font color="FF0000">ERROR: Ad #$adid not deleted: $DBI::errstr</font>|;
	}

	return $retmsg;
}

=item *
check_ad_form_input($tmpl)

Checks the input from the form generated by make_ad_edit_form() to make sure that it follows
the parameters specified in the ad_types table.  So it will check to make sure that there isn't
too many title/text1/text2 characters and the the image uploaded isn't too big.  Returns an
empty string if all went well.  If something went wrong it returns an error message for the user
to see.

=cut

sub check_ad_form_input {
	my $S = shift;
	my $tmpl = shift;
	my $err = '';

	return "Error: invalid ad template" unless( $S->is_valid_ad_tmpl( $tmpl ) );

	my %tmpl_info = %{ $S->get_ad_tmpl_info($tmpl) };
	my %required = %{ $S->get_ad_reqd_fields($tmpl) };

	# depending on what is required, there are different fields to test.
	# for each required field, check to make sure they didn't input too many characters
	# and that they inputted at least one character

	# ad url -- no limit on url length.
	if( $required{ad_url}		&&
		(!defined( $S->cgi->param('ad_url')) || $S->cgi->param('ad_url') eq '') ) {
		$err .= "Error: Please fill in a value for the ad url field.<br />";
	}
	if( $required{ad_url}		&&
		!($S->cgi->param('ad_url') =~ /^http:\/\//) ) {
		$err .= "Error: Link must start with http://<br />";
	}

	# title field
	if( $required{ad_title}		&&
		length($S->cgi->param('ad_title')) > $tmpl_info{max_title_chars} ) {

		my $too_many = length($S->cgi->param('ad_title')) - $tmpl_info{max_title_chars};
		$err .= "Error: The Ad Title has $too_many too many characters, max length is <b>$tmpl_info{max_title_chars}</b> characters.<br />\n";
	}
	if( $required{ad_title}		&&
		(!defined( $S->cgi->param('ad_title')) || $S->cgi->param('ad_title') eq '') ) {
		$err .= "Error: Please fill in a value for the ad title field.<br />";
	}

	# text 1
	if( $required{ad_text1}		&&
		length($S->cgi->param('ad_text1')) > $tmpl_info{max_text1_chars} ) {

		my $too_many = length($S->cgi->param('ad_text1')) - $tmpl_info{max_text1_chars};
		$err .= "Error: The Ad Text 1 field has $too_many too many characters, max length is <b>$tmpl_info{max_text1_chars}</b> characters.<br />\n";
	}
	if( $required{ad_text1}		&&
		(!defined( $S->cgi->param('ad_text1')) || $S->cgi->param('ad_text1') eq '') ) {
		$err .= "Error: Please fill in a value for the ad text1 field.<br />";
	}

	# ad text2
	if( $required{ad_text2}		&&
		length($S->cgi->param('ad_text2')) > $tmpl_info{max_text2_chars} ) {

		my $too_many = length($S->cgi->param('ad_text2')) - $tmpl_info{max_text2_chars};
		$err .= "Error: The Ad Text 2 has $too_many too many characters, max length is <b>$tmpl_info{max_text2_chars}</b> characters.<br />\n";
	}
	if( $required{ad_text2}		&&
		(!defined( $S->cgi->param('ad_text2')) || $S->cgi->param('ad_text2') eq '') ) {

		$err .= "Error: Please fill in a value for the ad text2 field.<br />";
	}


	# if they're submitting an ad check to make sure they submitted a valid number
	# of views to buy.
	if( $S->cgi->param('op') eq 'submitad'	&&
		$S->cgi->param('purchase_size') < $tmpl_info{min_purchase_size} ) {
			$err .= "Error: You must purchase at least <b>$tmpl_info{min_purchase_size}</b> ads at a time.<br />\n";
	}
	if( $S->cgi->param('op') eq 'submitad'	&&
		$S->cgi->param('purchase_size') > $tmpl_info{max_purchase_size} ) {
			$err .= "Error: You can only purchase <b>$tmpl_info{max_purchase_size}</b> ads at a time.<br />\n";
	}

	warn "Bad ad form input: $err" if( $DEBUG && $err ne '' );

	return $err;
}

=item *
make_ad_story()

Given an ad hash, it will make a story for the ad, and mark it as hidden.
The story will be put in the section given by the var 'ad_story_section'.
Later, in the ad properties page, you will be able to specify if the ad
should be in the introtext or bodytext of the story.  For now its just
introtext.

=cut

sub make_ad_story {
	my $S = shift;
	my $ad_hash = shift;
	my $err = '';

	# make/get new story sid
	my $sid = $S->make_new_sid();
	my $q_sid = $S->dbh->quote($sid);

	# first story odds and ends
	my $time = $S->dbh->quote( $S->_current_time() );
	my $section = $S->{UI}->{VARS}->{ad_story_section} || 'Advertising';
	my $topic = $S->{UI}->{VARS}->{ad_story_topic} || 'ads';
	my $title = $S->dbh->quote($ad_hash->{ad_title});

	# now the meat of the story
	my $body = '';
	my $intro = '';
	if( exists $S->{BOX_DATA}->{ad_story_format} ) {
		$intro = qq| %%BOX,ad_story_format,$ad_hash->{ad_id}%% |;
	}
	else {
		$intro = qq| %%BOX,show_ad,$ad_hash->{ad_id}%% |;
	}

	# quote stuff that could be bad
	$section = $S->dbh->quote($section);
	$topic = $S->dbh->quote($topic);
	$intro = $S->dbh->quote($intro);

	# set up the status values so that its never shown.  Later we'll set it to
	# show only in section if it gets approved/activated
	my $write_s = 0;
	my $display_s = -1;
	my $comment_s = 0;

	my ($rv, $sth) = $S->db_insert({
		DEBUG	=> 0,
		INTO	=> 'stories',
		COLS	=> 'sid, tid, aid, title, dept, time, introtext, bodytext, writestatus, section, displaystatus, commentstatus',
		VALUES	=> qq|$q_sid, $topic, $S->{UID}, $title, '', $time, $intro, '$body', $write_s, $section, $display_s, $comment_s|
	});
	$sth->finish;

	unless( $rv ) {
		$err = '<br>ERROR: Could not create ad story.  Database said: ' . $S->dbh->errstr();
	}

	# now that the story is created, associate it with the advertisement
	unless( $err ) {
		$err .= $S->update_ad( { ad_id => $ad_hash->{ad_id}, ad_sid => $sid }, { ad_sid => 1 } );
	}

	return $err;
}

=item *
activate_ad_story($sid)

Given the sid of an ad story, sets it to display to section only.

=cut

sub activate_ad_story {
	my $S = shift;
	my $sid = shift;
	my $q_sid = $S->dbh->quote($sid);

	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'stories',
		SET		=> 'displaystatus = 1',
		WHERE	=> qq| sid = $q_sid |,
	});

	return;
}

=item *
save_ad_judgements()

Saves the approvals and disapprovals from the admin ad judgement screen.  If
the choice for the ad is "Choose Action" then no action will be taken on that
ad. (i.e. they must explicitly choose approve or disapprove for an action to
be taken.).  If they choose disapprove, then whatever text is in the "Reason:"
field will be sent off in an email to the user that submitted the ad.  If no
reason is given it will state that.

=cut

sub save_ad_judgements {
	my $S = shift;
	my $message = '';

	return "You don't have permission to judge ads" unless( $S->have_perm('ad_admin') );

	# for each adid in the adid_list (if its a valid adid) update the judgement
	# on it.
	my $adids = $S->cgi->param("adid_list");
	my @adid_list = split(",", $adids);
	for my $a ( @adid_list ) {
		unless( $a =~ /^\d+$/ ) {
			warn "False adid given: $a" if $DEBUG;
			next;
		}

		# now it seems like a lot of extra queries, to get the ad hash here.  But
		# we need to ensure against duplicate emails.  So if the ad is already
		# judged, then skip it.
		my $adhash = $S->get_ad_hash($a,'db');
		if( $adhash->{judged} == 1 ) {
			$message .= qq|<font color="FF0000">Skipping ad "$adhash->{ad_title}" -- its already been judged</font><br />\n|;
			next;
		}

		my $judgement = $S->cgi->param("judgement_$a");
		if( $judgement eq 'approve' ) {
			warn "approving ad $a" if $DEBUG;
			$message .= $S->approve_ad($a);
		} elsif( $judgement eq 'disapprove' ) {
			warn "disapproving ad $a" if $DEBUG;
			$message .= $S->disapprove_ad($a);
		} else {
			warn "no action taken for ad $a" if $DEBUG;
		}
	}

	warn "returning $message in save_ad_judgements" if $DEBUG;
	return $message;
}

=item *
approve_ad($adid)

Approves an ad id given as the only argument.  Makes sure that
it doesn't approve an ad that has already been judged as well, by
making sure judged = 0 in the sql query.  When the ad is approved
active is set to 1.

=cut
sub approve_ad {
	my $S = shift;
	my $adid = shift;

	return "You don't have permission to approve ads" unless( $S->have_perm('ad_admin') );

	my $q_adid = $S->dbh->quote($adid);

	my $adhash = $S->get_ad_hash($adid, 'db');
	my $to = $S->get_email_from_uid($adhash->{sponsor});

	$adhash->{reason} = $S->cgi->param("reason_".$adhash->{ad_id}) || 'No reason given.';
	my $q_reason = $S->dbh->quote($adhash->{reason});

	my $msg = $S->{UI}->{BLOCKS}->{ad_approval_mail};
	$msg = $S->escape_adjudge_mail($msg, $adhash);
	my $subject = "Ad approval on ". $S->{UI}->{VARS}->{sitename};

	$S->mail($to,$subject,$msg);

	# since you can mark ads ad paid for on the judge screen for convenience, check
	# and set in the db if they set it.
	my $paid = '';
	if( $S->cgi->param("paidfor_$adid") == 1 ) {
		$paid = ', paid = 1 ';
	}

	my $activate_ua = '';
	if( $S->{UI}->{VARS}->{activate_upon_approve} == 1) {
		$activate_ua = ', active = 1 ';
		$S->activate_ad_story($adhash->{ad_sid});
	}

	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'ad_info',
		SET		=> "judged = 1, approved = 1, reason = $q_reason, judger = $S->{UID} $paid $activate_ua",
		WHERE	=> "ad_id = $q_adid and judged = 0",
		});

	unless( $rv ) {
		return qq|<font color="#FF0000">Advertisement id# $adid not updated correctly, still unjudged</font>|;
	}

	return qq|<font color="#00CC00">Ad id#$adid approved</font><br />\n|;
}

=item *
disapprove_ad($adid)

Disapproves an ad id given as the only argument.  Makes sure that
it doesn't disapprove an ad that has already been judged as well, by
making sure judged = 0 in the sql query.  When the ad is disapproved
active is set to 0.

=cut

sub disapprove_ad {
	my $S = shift;
	my $adid = shift;
	my $q_adid = $S->dbh->quote($adid);

	return "You don't have permission to disapprove ads" unless( $S->have_perm('ad_admin') );

	my $adhash = $S->get_ad_hash($adid, 'db');
	my $to = $S->get_email_from_uid($adhash->{sponsor});

	$adhash->{reason} = $S->cgi->param("reason_".$adhash->{ad_id}) || 'No reason given.';
	my $q_reason = $S->dbh->quote($adhash->{reason});

	my $msg = $S->{UI}->{BLOCKS}->{ad_disapproval_mail};
	$msg = $S->escape_adjudge_mail($msg, $adhash);

	my $subject = "Ad disapproval on ". $S->{UI}->{VARS}->{sitename};

	$S->mail($to,$subject,$msg);

	# since you can mark ads ad paid for on the judge screen for convenience, check
	# and set in the db if they set it.
	my $paid = '';
	if( $S->cgi->param("paidfor_$adid") == 1 ) {
		$paid = ', paid = 1 ';
	}

	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'ad_info',
		SET		=> "judged = 1, approved = 0, reason = $q_reason, judger = $S->{UID} $paid",
		WHERE	=> "ad_id = $q_adid and judged = 0",
		});

	unless( $rv ) {
		return qq|<font color="#FF0000">Advertisement id#$adid not updated correctly, still unjudged</font>|;
	}

	return qq|<font color="#00CC00">Ad id# $adid disapproved</font><br />\n|;
}

# This saves a submitted page from Edit Ad Type Properties to the database, it does some error
# checking first, and will return error to the page if needed.
sub save_adtype {
	my $S = shift;
	my $tmpl_name = shift;
	my $msg = '';
	my ($rv, $sth);

	return unless( $S->have_perm('ad_admin') );
 
	my $val_hash = $S->get_adprop_form_values();
	return $val_hash->{ERROR} if( $val_hash->{ERROR} ne '' );

	my $ad_type = $S->cgi->param('template');
	my $old_ad_type_hash = $S->get_ad_tmpl_info($ad_type);

	# don't let them save it as active unless they have an example ad defined
	my $ad_ex_hash = $S->get_example_ad($ad_type);
	my $set_inactive = 0;
	if ($ad_ex_hash->{example} != 1 && $val_hash->{active}) {
		$val_hash->{active} = 0;
		$set_inactive = 1;
	}

	# determine if new or update
	# if there is no entry in ad_types for the property that they are 
	# editing then we have to insert.  Determined by checking $old_ad_type_hash
	# for the existance of active
	if( $S->cgi->param('cur_adprop') eq $ad_type && !exists( $old_ad_type_hash->{active} ) ) {

		# need to make a column and value list for the insert
		my $values = $S->dbh->quote( $ad_type ) . ', ';
		my $cols = 'type_template, ';
		for my $c ( keys %$val_hash ) {
			next if $c eq 'ERROR';
			$cols .= "$c, ";
			$val_hash->{$c} = $S->dbh->quote($val_hash->{$c});
			$values .= $val_hash->{$c} . ', ';
		}

		# clean up the statements
		$values =~ s/, $//;
		$cols =~ s/, $//;

		($rv,$sth) = $S->db_insert({
			DEBUG	=> 0,
			INTO	=> 'ad_types',
			COLS	=> $cols,
			VALUES	=> $values
		});

		if( $rv ) {
			$msg = qq|<tr><td colspan="2" align="center">%%norm_font%%<font color="00AA00"> Successfully inserted the parameters for ad type '$ad_type' %%INACTIVE_MSG%%</font>%%norm_font_end%%</td></TR>|;
		} else {
			$msg = qq|<tr><td colspan="2" align="center">%%norm_font%%<font color="FF0000"> Error inserting parameters for ad type '$ad_type': $DBI::errstr </font>%%norm_font_end%%</td></TR>|;
		}

	# update if value already in db
	} elsif( $S->cgi->param('cur_adprop') eq $ad_type && $old_ad_type_hash->{type_template} eq $ad_type ) {
		
		my $where = ' type_template = ' . $S->dbh->quote( $ad_type );
		my $set = '';
		for my $c ( keys %$val_hash ) {
			next if $c eq 'ERROR';
			$val_hash->{$c} = $S->dbh->quote($val_hash->{$c});
			$set .= "$c = $val_hash->{$c}, ";
		}
		$set =~ s/, $//;

		($rv,$sth) = $S->db_update({
			DEBUG	=> 0,
			WHAT	=> 'ad_types',
			SET		=> $set,
			WHERE	=> $where
		});

		if( $rv ) {
			$msg = qq|<tr><td colspan="2" align="center">%%norm_font%%<font color="00AA00"> Successfully updated the parameters for ad type '$ad_type' %%INACTIVE_MSG%%</font>%%norm_font_end%%</td></TR>|;
		} else {
			$msg = qq|<tr><td colspan="2" align="center">%%norm_font%%<font color="FF0000"> Error updating values for ad type '$ad_type': $DBI::errstr </font>%%norm_font_end%%</td></TR>|;
		}

	# return error if cur_adprop eq 'foo' and pulldown != 'foo'
	} else {
		$msg = qq|<tr><td colspan="2" align="center">%%norm_font%%<font color="FF0000">Sorry, but you can't save changes to a different ad type than you started editing.</font>%%norm_font_end%%|;
	}

	# if we force inactive, let them know
	if( $set_inactive ) {
		my $inactive_msg = qq| <br /><font color="FF0000">Sorry, but you cannot set an ad type as active unless there is an example ad defined for it.  This ad has been saved inactive.</font>|;
		$msg =~ s/%%INACTIVE_MSG%%/$inactive_msg/;
	} else {
		$msg =~ s/%%INACTIVE_MSG%%//;
	}

	return $msg;
}


# returns the adproperty form values in a hash, with the key ERROR containing the error
sub get_adprop_form_values {
	my $S = shift;
	my $msg = '<font color="FF0000">Please fill in the following fields: ';
	my $oldmsg = $msg;
	my $val_hash = {};

	# handle the values that require input
	for my $v ( qw( pos type_name max_title_chars max_text1_chars max_text2_chars max_file_size short_desc submit_instructions min_purchase_size max_purchase_size cpm ) ) {

		$val_hash->{$v} = $S->cgi->param($v);

		# also, don't say a field is not here if it isn't supposed to be
		#  (thats what the hidden vars with names like foo_isnthere are for)
		$msg .= "$v, " unless(	( defined($val_hash->{$v})			&&
								  ($val_hash->{$v} ne '')  )		||
								($S->cgi->param("${v}_isnthere") == 1) );
	}
	$msg =~ s/, $//;

	# handle the checkboxes	
	for my $c ( qw( active allow_discussion ) ) {
		unless( $S->cgi->param($c) ) {
			$val_hash->{$c} = 0;
		} else {
			$val_hash->{$c} = $S->cgi->param($c);
		}
	}

	unless( $msg eq $oldmsg ) {
		$val_hash->{ERROR} = $msg;
	} else {
		$val_hash->{ERROR} = '';
	}

	return $val_hash;
}

# this makes a pulldown menu of all of the ad templates, with 
# A default choice of "Choose Ad Template" with a value of 'dummy'
sub make_tmpl_chooser {
	my $S = shift;
	my $which = shift;

	my $chooser = q| 
		<SELECT name="template">
		<OPTION value="dummy">Choose Ad Template
	|;

	for my $option ( @{ $S->get_ad_tmpl_list } ) {

		my $select = ( $option eq $which ? 'SELECTED' : '' );
		$chooser .= qq|	<OPTION VALUE="$option" $select>$option\n|;

	}

	$chooser .= "</SELECT>";

	return $chooser;
}

=item *
mark_ad_paid($ad_id)

Given an adid marks it as paid.  Returns 1 if it
succeeded, 0 otherwise.

=cut

sub mark_ad_paid {
	my $S = shift;
	my $adid = shift;

	return unless( $S->have_perm('ad_admin') );

	$adid = $S->dbh->quote($adid);
	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'ad_info',
		SET		=> 'paid = 1',
		WHERE	=> "ad_id = $adid",
		});
	$sth->finish();
	
	if($rv) {
		return 1;
	} else {
		return 0;
	}
}

=item *
save_renewal_impressions( $ad_id, $impression_amt )

This takes an ad_id and the number of impressions to store and 
saves them in the ad's impression_cache for later transfer to
views_left.  Returns 1 for successful save, 0 otherwise.

=cut

sub save_renewal_impressions {
	my $S = shift;
	my $ad_id = shift;
	my $impression_amt = shift;

	$ad_id = $S->dbh->quote( $ad_id );
	$impression_amt = $S->dbh->quote( $impression_amt );

	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'ad_info',
		SET		=> "impression_cache = impression_cache + $impression_amt",
		WHERE	=> "ad_id = $ad_id"
	});
	$sth->finish();

	if( $rv ) {
		return 1;
	}
	else {
		return 0;
	}
}

=item *
activate_renewal_impressions( $ad_id )

This takes all of the impressions an ad has in its impression_cache and adds
them to the views_left of the ad.  Returns 1 on success, 0 otherwise.

=cut

sub activate_renewal_impressions {
	my $S = shift;
	my $ad_id = shift;

	$ad_id = $S->dbh->quote($ad_id);

	# UPDATE assignments are evaluated from left to right, this is very important
	# for the following queries
	
	# First, if views_left is NULL, we need to update it to be zero.
	# MySQL won't add to NULL, so it has to be a number. If it's not null,
	# the following will just leave it alone.
	my ($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'ad_info',
		SET		=> 'views_left = 0',
		WHERE	=> "ad_id = $ad_id and views_left IS NULL"
	});
	$sth->finish();
	
	# Get the renewal impressions
	($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		FROM	=> 'ad_info',
		WHAT	=> 'impression_cache',
		WHERE	=> "ad_id = $ad_id"
	});
	my $add = $sth->fetchrow();
	$sth->finish();
	
	unless ($add) {warn "No impressions in cache! Bailing.\n";}
	return unless ($add);
	
	# Ok, now shift from impression_cache
	($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'ad_info',
		SET		=> qq|views_left = (views_left + $add), impression_cache = 0|,
		WHERE	=> "ad_id = $ad_id"
	});
	$sth->finish();

	if( $rv ) {
		return 1;
	}
	else {
		return 0;
	}
}


=item *
send_renewal_mail( $ad_id, $imps )

Sends a renewal notice to the sponsor of ad $ad_id that there are
only $imps impressions left on the campaign and they might want to 
renew

=cut

sub send_renewal_mail {
	my $S = shift;
	my $ad_id = shift;
	my $imps = shift;

	my $adhash = $S->get_ad_hash($ad_id, 'db');
	$adhash->{impressions} = $imps;
	
	my $to = $S->get_email_from_uid($adhash->{sponsor});
	
	my $msg = $S->{UI}->{BLOCKS}->{ad_renewal_mail};
	$msg = $S->escape_adjudge_mail($msg, $adhash);
	my $subject = "Ad renewal on ". $S->{UI}->{VARS}->{sitename};

	$S->mail($to,$subject,$msg);
	
	return;
}
	
=item *
update_ad_discussion_time( $discussion_sid )

Given the sid for an ad discussion, it will update the story post time to 
the time now, so that when an ad is renewed, its discussion jumps to the top
of the ad discussion section.  Returns 1 for success, 0 for failure.

=cut

sub update_ad_discussion_time {
	my $S = shift;
	my $ad_id = shift;

	# Fetch the discussion sid, if there is one
	my ($rv, $sth) = $S->db_select({
		WHAT => 'ad_sid',
		FROM => 'ad_info',
		WHERE => "ad_id = $ad_id"
	});
	my $dis_sid = $sth->fetchrow();
	$sth->finish();
	
	return unless ($dis_sid);
	
	my $now = $S->dbh->quote( $S->_current_time() );
	$dis_sid = $S->dbh->quote($dis_sid);

	($rv,$sth) = $S->db_update({
		DEBUG	=> 0,
		WHAT	=> 'stories',
		SET		=> "time = $now",
		WHERE	=> "sid = $dis_sid"
	});
	$sth->finish();

	if( $rv ) {
		return 1;
	}
	else {
		return 0;
	}
}

1;
