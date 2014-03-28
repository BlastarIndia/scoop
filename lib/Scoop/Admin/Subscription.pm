package Scoop;
use strict;
my $DEBUG = 0;

sub sub_admin {
	my $S = shift;
	my $save = $S->cgi->param('save');
	my $err;
	
	my $type = $S->cgi->param('type');
	my $new_type = $S->cgi->param('new_type');
	
	if ($type && $new_type) {
		$err = qq|<font color="#ff0000">Error! Type name does not match type selected.</font>|;
	} elsif ($new_type) {
		# Fake it for the rest of the code
		$S->{PARAMS}->{type} = $new_type;
	}
	
	if (($save eq 'Save') && !$err) {
		$err = $S->sub_save_type();
	}
	
	my $page = qq|
	<table border=0 cellpadding=0 cellspacing=0 width="99%">
	  <tr>
		<td bgcolor="%%title_bgcolor%%">
		  %%title_font%%Subscription Admin%%title_font_end%%
		</td>
       </tr>
	</table>
	<p>
	%%norm_font%% $err %%norm_font_end%%
	<p>|;

	$page .= $S->sub_admin_page();
	
	
	return $page;
}


sub sub_save_type {
	my $S = shift;
	my $err;
	
	my $data = $S->cgi->Vars();
	
	# Check that a type was entered
	unless ($data->{type}) {
		$err = 'No type selected.';
	}
	
	# Check for existing type
	my $q_type = $S->dbh->quote($data->{type});
	my ($rv, $sth) = $S->db_select({
		WHAT => 'type',
		FROM => 'subscription_types',
		WHERE => qq|type = $q_type|
	});
	
	my $exists = $sth->fetchrow();
	$sth->finish();
	
	my $action = 'saved';
	my $type = $data->{type};
	if ($exists && !$err) {
		if ($data->{delete}) {
			$err .= $S->sub_delete_type($data);
			$action = 'deleted';
			$S->{PARAMS}->{type} = '';
		} else {
			$err .= $S->sub_update_type($data);
		}
	} elsif (!$err) {
		if ($data->{delete}) {
			$err .= 'Cannot delete a type that doesn\'t exist!';
		} else {
			$err .= $S->sub_insert_type($data);
		}
	}
	
	my $return = ($err) ? 
	  qq|<font color="#ff0000">$err</font>| :
	  qq|<font color="#00ff00">Type "$type" $action.</font>|;
	
	return $return;
}


sub sub_update_type {
	my $S = shift;
	my $data = shift;

	my $set;
	foreach (qw(perm_group_id cost max_time renewable description)) {
		$set .= ',' if $set;
		$set .= "$_ = " . $S->dbh->quote($data->{$_});
	}
	my $q_type = $S->dbh->quote($data->{type});

	my ($rv, $sth) = $S->db_update({
		WHAT  => 'subscription_types',
		SET   => $set,
		WHERE => qq|type = $q_type|
	});
	$sth->finish();
	return '' if $rv;
	return $S->dbh->errstr();
}


sub sub_insert_type {
	my $S = shift;
	my $data = shift;

	my $values;
	foreach (qw(type perm_group_id cost max_time renewable description)) {
		$values .= ',' if $values;
		$values .= $S->dbh->quote($data->{$_});
	}

	my ($rv, $sth) = $S->db_insert({
		INTO   => 'subscription_types',
		COLS   => 'type, perm_group_id, cost, max_time, renewable, description',
		VALUES => $values
	});
	$sth->finish();
	return '' if $rv;
	return $S->dbh->errstr();
}
	
	
sub sub_delete_type {
	my $S = shift;
	my $data = shift;

	my $q_type = $S->dbh->quote($data->{type});
	my ($rv, $sth) = $S->db_delete({
		FROM  => 'subscription_types',
		WHERE => qq|type = $q_type|
	});
	$sth->finish();
	return '' if $rv;
	return $S->dbh->errstr();
}
	
	
sub sub_admin_page {
	my $S    = shift;
	my $op   = $S->cgi->param('op');
	my $tool = $S->cgi->param('tool');
	
	my $type = $S->cgi->param('type');
	warn "Type is $type\n" if $DEBUG;
	my $type_list = $S->sub_type_list($type);
	my $type_data = $S->sub_type_data($type);
	
	$type_data->{max_time} = '' if ($type_data->{max_time} == 0);
	
	my $renewable_list = $S->sub_renew_list($type_data);
	my $group_list = $S->sub_group_list($type_data);
	
	my $form_name = ($type && $type ne '') ? qq|$type| : qq|<input type="text" name="new_type" value="" size=30 maxsize=50>|;
	
	my $current_subs = ($type && $type ne '') ? $S->sub_count_current($type) : '';
	
	my $form = qq|
<form action="%%rootdir%%/" method="POST">
<input type="hidden" name="op" value="$op">
<input type="hidden" name="tool" value="$tool">

<table border=0 cellpadding=5 cellspacing=0 align="center">
	<tr>
		<td align="center">
		%%norm_font%%
		  <input type="submit" name="save" value="Save"> $type_list <input type="submit" name="get" value="Get">
		%%norm_font_end%%
		</td>
	</tr>
</table>
<p>
<table border=0 cellpadding=5 cellspacing=0 align="center">
	<tr>
		<td valign="top">%%norm_font%%<b>Delete?</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%<input type="checkbox" name="delete">%%norm_font_end%%</td>
	</tr>
	<tr>
		<td valign="top">%%norm_font%%<b>Name:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$form_name%%norm_font_end%%</td>
	</tr>
	<tr>
		<td valign="top">%%norm_font%%<b>Current Subscribers:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$current_subs%%norm_font_end%%</td>
	</tr>
	<tr>
		<td valign="top">%%norm_font%%<b>Group:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$group_list<br><i>Create new subscriber group first, then choose from this list</i>%%norm_font_end%%</td>
	</tr>
	<tr>
		<td valign="top">%%norm_font%%<b>Price:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%<input type="text" name="cost" value="$type_data->{cost}" size=10><br><i>Per month</i>%%norm_font_end%%</td>
	</tr>
	<tr>
		<td valign="top">%%norm_font%%<b>Maximum Time:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%<input type="text" name="max_time" value="$type_data->{max_time}" size=10><br><i>In integer months, leave blank for unlimited</i>%%norm_font_end%%</td>
	</tr>
	<tr>
		<td valign="top">%%norm_font%%<b>Renewable:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%$renewable_list<br><i>For example, make trial subscription unrenewable</i>%%norm_font_end%%</td>
	</tr>
	<tr>
		<td valign="top">%%norm_font%%<b>Description:</b>%%norm_font_end%%</td>
		<td valign="top">%%norm_font%%<textarea name="description" cols="50" rows="5" wrap="soft">$type_data->{description}</textarea>%%norm_font_end%%</td>
	</tr>
</table>
</form>
|;

	return $form;

}  


sub sub_type_data {
	my $S    = shift;
	my $type = shift;

	my $type_data = {};

	return $type_data unless $type;

	my $q_type = $S->dbh->quote($type);
	my ($rv, $sth) = $S->db_select({
		WHAT  => '*',
		FROM  => 'subscription_types',
		WHERE => "type = $q_type"
	});

	$type_data = $sth->fetchrow_hashref();

	return $type_data;
}

	
sub sub_type_list {
	my $S    = shift;
	my $type = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'type',
		FROM => 'subscription_types'
	});
	
	my @types;
	while (my $r = $sth->fetchrow()) {
		warn "Found type $r\n" if $DEBUG;
		push @types, $r;
	}
	
	$sth->finish();
	
	my $list = qq|
	<select name="type" size=1>
	  <option value="">New Subscription Type|;
	
	foreach my $t (sort @types) {
		my $s = ($type eq $t) ? ' SELECTED' : '';
		$list.= qq|
	  <option value="$t"$s>$t|;
	}
	
	$list .= qq|
	</select>|;
	
	return $list;
}


sub sub_renew_list {
	my $S         = shift;
	my $type_data = shift;	  
	
	my $s_no  = (exists($type_data->{renewable}) && ($type_data->{renewable} == 0)) ? ' SELECTED' : '';
	my $s_yes = ($type_data->{renewable} == 1) ? ' SELECTED' : '';

	my $list = qq|
	<select name="renewable" size=1>
	  <option value="">Renewable?
	  <option value="1"$s_yes>Yes
	  <option value="0"$s_no>No
	</select>|;
	
	return $list;
}


sub sub_group_list {
	my $S = shift;
	my $type_data = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => 'perm_group_id',
		FROM => 'perm_groups',
		DEBUG => 0});
	
	my @groups;
	
	while (my $r = $sth->fetchrow()) {
		push @groups, $r;
	}
	
	$sth->finish();
	
	my $list = qq|
	<select name="perm_group_id" size=1>|;
	
	foreach my $g (sort @groups) {
		my $s = ($type_data->{perm_group_id} eq $g) ? ' SELECTED' : '';
		$list.= qq|
	  <option value="$g"$s>$g|;
	}
	
	$list .= qq|
	</select>|;
	
	return $list;
}

	
sub sub_count_current {
	my $S = shift;
	my $type = shift;

	my $q_type = $S->dbh->quote($type);
	my ($rv, $sth) = $S->db_select({
		WHAT => 'COUNT(*)',
		FROM => 'subscription_info',
		WHERE => qq|type = $q_type AND active = 1|
	});
	
	my $count = $sth->fetchrow();
	$sth->finish();
	
	return $count;
}


1;
	
	
	
