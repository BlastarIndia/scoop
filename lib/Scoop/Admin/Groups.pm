package Scoop;
use strict;

my $DEBUG = 0;

sub edit_groups {
	my $S = shift;
	my $msg = $S->_update_groups();
	my $form = $S->_get_group_form($msg);
	return $form;
}

sub _refresh_group_perms {
	my $S = shift;

	#Make sure perms are up to date now
	my $user = $S->user_data($S->{UID});
	$S->{GID} = $user->{perm_group};
	$S->_set_perms();
	return;
}

sub _update_groups {
	my $S = shift;
	my $write = $S->{CGI}->param('write');
	return unless $write;
	
	my $msg;
	my $perm_group_id = $S->{CGI}->param('perm_group_id');
	my $input_id = $S->{CGI}->param('group_id');
	warn "input id is $input_id" if $DEBUG;
	my $group_description = $S->{CGI}->param('group_description');
	my $default = $S->{CGI}->param('default_user_group') || 0;
	
	unless ($S->have_perm('edit_groups')) {
		return "Cannot update: Permission denied.";
	}
	
	unless ($input_id) {
		$msg = "You must include a group id<BR>";
	}
	unless ($group_description) {
		$msg .= "You must include a group description.<BR>";
	} 
	unless ( ($input_id eq $perm_group_id) || (!$perm_group_id) ) {
		$msg .= "Group ID must match selected group ID.<BR>";
	}
	
	return qq|%%title_font%%<FONT COLOR="#ff0000">$msg</FONT>%%title_font_end%%| if ($msg);
	
	# Pack the perms
	my $params = $S->{CGI}->Vars;
	my $perms = $S->get_perms();
	my $my_perms = {};
	foreach my $perm ( @{$perms} ) {
		if( $params->{$perm} ) {
		   	$my_perms->{$perm} = 1;
		}
	}

	my $packed_perms = $S->_pack_perms( $my_perms );

	# Filter stuff.
	my $f_input_id = $S->{DBH}->quote($input_id);
	my $f_group_description = $S->{DBH}->quote($group_description);
	my $f_packed_perms = $S->{DBH}->quote($packed_perms);
	
	# Is this an existing group?
	my $rv;
	if ($input_id eq $perm_group_id) {
		my $set = qq|group_perms = $f_packed_perms, group_description = $f_group_description |;
		
		if ($default) {
			$set .= qq|, default_user_group = '1'|;
		}
		$rv = $S->db_update({
			DEBUG => $DEBUG,
			WHAT => "perm_groups",
			SET => $set,
			WHERE => qq|perm_group_id = $f_input_id|});
		$msg .= $S->{DBH}->errstr() unless $rv;
	} else {	# New group

		# since its a new group, we have to update the section perms for them too
		# do this first, so we can still use the old value of default_user_group
		# just in case they are setting a new one now
		$S->_set_newgroup_sect_perms($input_id);

		$rv = $S->db_insert({
			INTO => 'perm_groups',
			COLS => 'perm_group_id, group_perms, default_user_group, group_description',
			VALUES => qq|$f_input_id, $f_packed_perms, $default, $f_group_description|});

		$msg .= $S->{DBH}->errstr() unless $rv;
	}
	
	if ($rv && $default) {
		$msg .= $S->_unset_old_default($input_id);
	}	
	
	if ($msg) {
		$msg = qq|%%title_font%%<FONT COLOR="#ff0000">$msg</FONT>%%title_font_end%%|;
	}
	
	# Make sure our perms are now up to date
	$S->_refresh_group_perms();

	# Set the new group to be the one we're editing.
	$S->{PARAMS}->{'perm_group_id'} = $input_id;
	
	return $msg	
}


sub _set_newgroup_sect_perms {
	my $S = shift;
	my $newgroup = shift;

	# first get the default group's id
	my $def_group = $S->_get_default_group();

	# then get the sect perms for each section for that group
	my ($rv,$sth) = $S->db_select({
		DEBUG	=> $DEBUG,
		FROM	=> 'section_perms',
		WHAT	=> 'section,sect_perms,default_sect_perm',
		WHERE	=> qq| group_id = '$def_group' |,
	});

	return unless( $rv );
	my $f_newgroup = $S->{DBH}->quote($newgroup);

	# then loop through all of the sections, inserting for the new group
	# the same values as for the default group on each section
	# NOTE: there might be a faster way than this to update section_perms.  Let me
	# (hurstdog) know if you find it :)
	while( my $row = $sth->fetchrow_hashref ) {

		my ($rv2,$sth2) = $S->db_insert({
			DEBUG	=> $DEBUG,
			INTO	=> 'section_perms',
			VALUES	=> qq| $f_newgroup, '$row->{section}', '$row->{sect_perms}', $row->{default_sect_perm} |,
		});
		$sth2->finish;

	}
	$sth->finish;

}


sub _unset_old_default {
	my $S = shift;
	my $id = shift;
	
	$id = $S->dbh->quote($id);
	my ($rv) = $S->db_update({
		WHAT => 'perm_groups',
		SET => 'default_user_group = 0',
		WHERE => qq|perm_group_id != $id|});
	
	my $err = $S->{DBH}->errstr() unless $rv;
	return $err;
}


sub _get_group_form {
	my $S = shift;
	my $msg = shift || '&nbsp;';
	
	my $perm_group_id = $S->{CGI}->param('perm_group_id') || 'XXX';
	
	my $group = $S->group_data($perm_group_id);
	
	my $group_selector = $S->_get_group_selector($perm_group_id);
	my $new_user_def_check = $S->_get_default_checkbox($group->{default_user_group});

    # pass perm_table the perm_group_id, the number of columns, and a flag
    # to say whether or not this is a section table or not
	my $group_perms = $S->perm_table($perm_group_id);
	
	my $page = qq|
		<FORM NAME="groups" ACTION="%%rootdir%%/" METHOD="post">
		<INPUT TYPE="hidden" NAME="op" VALUE="admin">
		<INPUT TYPE="hidden" NAME="tool" VALUE="groups">
		<TABLE WIDTH="100%" BORDER=0 CELLPADDING=0 CELLSPACING=0>
			<TR BGCOLOR="%%title_bgcolor%%">
				<TD>%%title_font%%Edit Group Permissions</FONT></TD>
			</TR>
			<TR>
				<TD>$msg</TD>
			</TR>
			<TR>
				<TD>%%norm_font%%<B>Group:</B> $group_selector 
				<INPUT TYPE="submit" NAME="get" VALUE="Get Group">%%norm_font_end%%</TD>
			</TR>
			<TR>
				<TD>%%norm_font%%<B>Group ID:</B> 
				<INPUT TYPE="text" NAME="group_id" VALUE="$group->{perm_group_id}" SIZE=40>%%norm_font_end%%</TD>
			</TR>
			<TR>
				<TD>%%norm_font%%<B>Default New User Group?</B> $new_user_def_check%%norm_font_end%%</TD>
			</TR>
			<TR>
				<TD>%%norm_font%%<B>Group Description:</B>%%norm_font_end%%</TD>
			</TR>
			<TR>
				<TD>%%norm_font%%<TEXTAREA COLS=50 ROWS=3 NAME="group_description" WRAP="soft">$group->{group_description}</TEXTAREA></FONT></TD>
			</TR>
			<TR>
				<TD>%%norm_font%%<B>Group Permissions:</B><P> 
				$group_perms%%norm_font_end%%</TD>
			</TR>
			<TR>
				<TD>%%norm_font%%<INPUT TYPE="submit" NAME="write" VALUE="Save Group"> <INPUT TYPE="reset"></FONT></TD>
			</TR>

		</TABLE>
		</FORM>|;
	
	return $page;
}		

sub _get_group_selector {
	my $S = shift;
	my $curr_id = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'perm_group_id',
		FROM => 'perm_groups',
		DEBUG => $DEBUG});
	
	my $selector = qq|
		<SELECT NAME="perm_group_id" SIZE=1>
			<OPTION VALUE="">New Group|;
	
	my $selected = '';	
	while (my $group = $sth->fetchrow()) {
		$selected = '';
		$selected = " SELECTED" if ($group eq $curr_id);
		$selector .= qq|
			<OPTION VALUE="$group"$selected>$group|;
	}
	$selector .= qq|
		</SELECT>|;
	
	return $selector;
}

sub _get_default_checkbox {
	my $S = shift;
	my $check = shift;
	
	my $checked = " CHECKED" if ($check);
	my $checkbox = qq|<INPUT TYPE=checkbox NAME="default_user_group" VALUE=1$checked>|;
	
	return $checkbox;
}


sub group_data {
	my $S = shift;
	my $gid = shift;
	
	my $quoted_gid = $S->{DBH}->quote($gid);
	
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'perm_groups',
		WHERE => qq|perm_group_id = $quoted_gid|,
		DEBUG => $DEBUG});
	
	my $group_data = $sth->fetchrow_hashref() || undef;
	return $group_data;
}

sub _get_default_group {
	my $S = shift;
	my $advertiser = shift;
	return $S->{UI}->{VARS}->{advertiser_group} if $advertiser;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'perm_group_id',
		FROM => 'perm_groups',
		WHERE => 'default_user_group = 1'});
	
	my $id = $sth->fetchrow();
	return $id;
}




1;
