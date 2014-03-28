package Scoop;
use strict;

my $DEBUG = 0;

=head1 EditUser.pm

This contains all of the functions where you might need to edit a user.
Everything for creating a user is in Users.pm.  This controls the
User Preferences page.

=head1 Functions

=cut


sub _get_user_files {
	my $S = shift;
	my $uid = shift;
	my $page;

	# check for incoming uploads
	if ($S->{CGI}->param('file_upload')) {
		my $file_upload_type = $S->{CGI}->param('file_upload_type');
		my ($return, $file_name, $file_size, $file_link) = $S->get_file_upload($file_upload_type);
		my $message;
		if ($return eq '') {
			$message = qq|Saved File: <a href="$file_link">$file_name</a>|;
		} else {
			$message = qq|Error: $return|;
		}
		$page .= qq{<tr><td>%%norm_font%%<b><font color="red">$message</font></b>%%norm_font_end%%<br/>&nbsp;</td></tr>};
	}
	
	my $file_name = $S->{CGI}->param('file_name');

	# check for delete activity
	if ( $S->{CGI}->param('confirm_delete') && $S->{CGI}->param('delete') && $file_name ) {
		my $path;
		return 'Permission Denied' if ($uid ne $S->{UID}) || !$S->var('upload_delete');
		if ( $S->{CGI}->param('list_type') eq 'user' ) {
			$path = $S->var('upload_path_user') . "$uid/";
		} else {
			$path = $S->var('upload_path_admin');
		};

		unlink "$path$file_name";

		$page .= qq{<tr><td>%%norm_font%%<b><font color="red">$file_name deleted.</font></b>%%norm_font_end%%<br/>&nbsp;</td></tr>};
	} 

	# check for rename activity
	if ( $S->{CGI}->param('rename_filename') && $S->{CGI}->param('rename') && $file_name ) {
		my $path;
		my $file_name_new = $S->clean_filename($S->{CGI}->param('rename_filename'));

		return 'Permission Denied' if ($uid ne $S->{UID}) || !$S->var('upload_rename');
		if ( $S->{CGI}->param('list_type') eq 'user' ) {
			$path = $S->var('upload_path_user') . "$uid/";
		} else {
			$path = $S->var('upload_path_admin');
		};

		my $message;
		if (rename "$path$file_name", "$path$file_name_new") {
			$message = "$file_name renamed to $file_name_new.";
		} else {
			$message = "Couldn't rename $file_name to $file_name_new.";
		}

		$page .= qq{<tr><td>%%norm_font%%<b><font color="red">$message</font></b>%%norm_font_end%%<br/>&nbsp;</td></tr>};
	} 

	if($S->have_perm('view_user_files') || $S->have_perm('upload_user')){
		# always build the user file list
		$page .= $S->_build_file_list('user', $uid);
	}
 
	# if they are looking at their own files
	if ($S->{UID} eq $uid) {
		# if they are an admin, display those too
		if ($S->have_perm('upload_admin')) {
			$page .= $S->_build_file_list('admin');
		}

		# if they are allowed, show upload form
		if ($S->have_perm('upload_admin') || $S->have_perm('upload_user')) {
			$page .= '<tr><td>' .
				$S->display_upload_form(1, 'files') .
				'</td></tr>';
		}
	}
	$S->{UI}->{BLOCKS}->{subtitle} = 'User Files';
	$S->{UI}->{BLOCKS}->{CONTENT} = "<table width=\"100%\">\n$page\n</table>";
}

sub _build_file_list {
	my $S = shift;
	my $list_type = shift || 'user';
	my $uid = shift || $S->{UID};

	my $file_link;
	if ($list_type eq 'admin') {
		$file_link = $S->var('upload_link_admin');
	} else {
		$file_link = $S->var('upload_link_user') . "$uid/";
	}
	
	my $title = 'User Files:';
	
	$title = 'Admin Files:' if $list_type eq 'admin';
	my $file_list = qq{
		<tr>
			<TD BGCOLOR="%%title_bgcolor%%">%%title_font%%<B>$title</B>%%title_font_end%%</TD>
		</tr>
		<tr>
			<td><form method="post" name="file_$list_type" action="%%rootdir%%/user/uid:$uid/files/">
			<input type="hidden" name="list_type" value="$list_type">
			%%norm_font%%};

	my @files = $S->get_file_list($uid, $list_type);
	my $file_total_count = scalar @files;
	foreach my $file_name (@files) {
		my $marker;
		if ( ($S->var('upload_rename') || $S->var('upload_delete')) && $uid eq $S->{UID} ) {
			$marker = qq{<input type="radio" name="file_name" value="$file_name">};
		} else {
			$marker = "%%dot%%";
		}
		$file_list .= qq{$marker <a href="$file_link$file_name">$file_name</a><br/>};
	}

	$file_list .= "<p>$file_total_count files found.</p>" if $file_total_count != 1;
	$file_list .= "<p>$file_total_count file found. </p>" if $file_total_count == 1;

	my $buttons;
	if ( $uid eq $S->{UID} && $S->var('upload_rename') ) {
		$buttons .= qq{
			<tr>
			    <td><input type="submit" name="rename" value="Rename Selected File"></td>
			    <td>To: <input type="text" name="rename_filename"></td>
			</tr>
		};
	}

	if ( $uid eq $S->{UID} && $S->var('upload_delete') ) {
		$buttons .= qq{
			<tr>
			    <td><input type="submit" name="delete" value="Delete Selected File"></td>
			    <td>Confirm: <input type="checkbox" name="confirm_delete"></td>
			</tr>
		};
	}
	
	$buttons = qq{<table border=0>$buttons</table>} if $buttons ne '';

	$file_list .= qq|$buttons
		%%norm_font_end%%</form>
			</td>
		</tr>|;
	return $file_list;
}


sub _num_replies {
	my $S = shift;
	my $cid = shift;
	my $sid = shift;
	
	my ($rv) = $S->db_select({
		ARCHIVE => $S->_check_archivestatus($sid),
		WHAT => 'cid',
		FROM => 'comments',
		WHERE => qq|pid = $cid AND sid = '$sid'|});
	if ($rv eq '0E0') {
		$rv = 0;
	}
	return $rv;
}


sub add_to_subscription	{
	my $S = shift;
	my $user = shift;
	my $months = shift;
	
	my $add = $months * 2678400;
	my $exp = $user->{prefs}->{subscription_expire} || time;
	
	return ($exp + $add);
}


=item *
pref()

This is a nice convenient method for getting preferences for the logged in
user. You should use this instead of accessing the userprefs table directly
because it uses cached values - both more convenient and faster.

my $value = $S->pref('pref1');	# Returns the value for the named preference

=cut

sub pref {
	my $S     = shift;
	my $key   = shift;

	return unless defined $key;
	$S->_set_prefs() unless $S->{prefs}; # you can force a reload of prefs by deleting $S->{prefs}
					     # very useful when you're changing prefs as part of a request

	return defined($S->{prefs}->{$key}) ? $S->{prefs}->{$key} : $S->{PREF_ITEMS}->{$key}->{default_value};

	return;
}

=item *
clear_prefs( \@prefs )

Given a list of prefs, it will delete them from the userprefs table.
Given a single pref, it will just delete that one.  Given the single pref
'CLEAR_ALL_USER_PREFS' it will clear all of the prefs for the current user.
Not a safe thing to do.  Returns nothing or the error generated by $S->dbh->errstr()
.

=cut

sub clear_prefs {
	my $S = shift;
	my $prefs = shift;
	my ($rv, $sth);

	# if changing a list of prefs, create a sql query to delete all listed
	if( ref($prefs) eq 'ARRAY' ) {
		my $where = "uid = $S->{UID} AND (";
		for my $p ( @$prefs ) {
			$p = $S->dbh->quote($p);
			$where .= qq|prefname = $p OR |;

			# Don't forget to update the cache and stuff
			$S->{prefs}->{$p} = undef;
			$S->{USER_DATA_CACHE}->{ $S->{UID} }->{prefs}->{$p} = undef;
		}
		$where =~ s/OR $/\)/;

		# now that we have the list, delete
		($rv, $sth) = $S->db_delete({
			FROM	=> 'userprefs',
			WHERE	=> $where,
			DEBUG	=> 0,
		});

	}
	else {
		# else just delete the one pref, unless its the special pref, then delete
		# all
		warn "deleting prefs $prefs" if $DEBUG;
		my $where = "uid = $S->{UID}";
		unless( $prefs eq 'CLEAR_ALL_USER_PREFS' ) {
			$prefs = $S->dbh->quote($prefs);
			$where .= " AND prefname = $prefs";
		}

		($rv, $sth) = $S->db_delete({
			FROM	=> 'userprefs',
			WHERE	=> $where,
			DEBUG	=> 0,
		});

		# Get all of this users' prefs out of the cache
		$S->{prefs} = undef;
		$S->{USER_DATA_CACHE}->{ $S->{UID} }->{prefs} = undef;


	}

	unless( $rv ) {
		return $S->dbh->errstr();
	}

	return;
}

1;
