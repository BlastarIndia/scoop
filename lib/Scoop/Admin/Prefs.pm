package Scoop;
use strict;

my $DEBUG = 0;

sub edit_prefs {
	my $S = shift;
	my $form = $S->{UI}->{BLOCKS}->{edit_prefs};
	my $get = $S->cgi->param('get');
	my $save = $S->cgi->param('save');
	my $delete = $S->cgi->param('delete');
	my $params;
	my $keys;
	my $update_msg;

	# first register saves (and deletes)
	if ($save && $save eq 'Save') {
		warn "(edit_prefs) saving something" if $DEBUG;
		if ($delete) {
			$update_msg = $S->_delete_pref_item();
			$get = 'Get';  # making sure the form is cleared
		} else {
			$update_msg = $S->_save_pref_item();
		}
	}

	# ok, now we can show whatever's supposed to be in the form now
	if ($get && $get eq 'Get') {
		# get from the db
		my $get_pref = $S->cgi->param('pref');
		warn "(edit_prefs) getting $get_pref from the db" if $DEBUG;
		$get_pref = $S->dbh->quote($get_pref);
		my ($rv, $sth) = $S->db_select({
			DEBUG => $DEBUG,
			WHAT  => '*',
			FROM  => 'pref_items',
			WHERE => "prefname = $get_pref"
		});

		$params = $sth->fetchrow_hashref();
		$sth->finish;

	} else {
		# get from the cgi params because we either saved or attempted to save.
		$params = $S->cgi->Vars_cloned;
		warn "(edit_prefs) getting $params->{prefname} from cgi params" if $DEBUG;
	}

	# now prepare the easy ones first
	$keys->{pref_name} 	= $params->{prefname};
	$keys->{pref_title} 	= $params->{title};
	$keys->{pref_desc} 	= $params->{description};
	$keys->{pref_default} 	= $params->{default_value};
	$keys->{pref_page} 	= $params->{page};
	$keys->{pref_order} 	= $params->{display_order};
	$keys->{pref_field} 	= $params->{field};
	$keys->{pref_length} 	= $params->{length};
	$keys->{pref_regex} 	= $params->{regex};
	$keys->{pref_fmt}	= $params->{display_fmt};

	# now we filter them because they all have to stay put inside their form elements
	$keys = $S->_pref_display_filter($keys, $get);

	# checkboxes
	$keys->{pref_html} 	= $params->{html} ? ' CHECKED' : '';
	$keys->{pref_tu} 	= $params->{req_tu} ? ' CHECKED' : '';
	$keys->{pref_visible}	= $params->{visible} ? ' CHECKED' : '';
	$keys->{pref_enabled}	= $params->{enabled} ? ' CHECKED' : '';

	# radio buttons
	$keys->{pref_signup_normal} = ( $params->{signup} eq 'normal' ) ? ' CHECKED' : '';
	$keys->{pref_signup_signup} = ( $params->{signup} eq 'signup' ) ? ' CHECKED' : '';
	$keys->{pref_signup_required} = ( $params->{signup} eq 'required' ) ? ' CHECKED' : '';

	# and finally the selectboxes
	$keys->{pref_selectbox}	= $S->_pref_name_select();
	$keys->{pref_template}	= $S->_pref_template_select($params->{template});
	$keys->{pref_var}	= $S->_pref_var_select($params->{var});
	$keys->{pref_perm_view}	= $S->_pref_perm_view_select($params->{perm_view});
	$keys->{pref_perm_edit}	= $S->_pref_perm_edit_select($params->{perm_edit});

	# also a couple of user preferences!
	$keys->{cols}		= $S->pref('textarea_cols');
	$keys->{rows}		= $S->pref('textarea_rows');
	# and a status report.
	$keys->{update_msg}	= $update_msg;

	$form = $S->interpolate($form, $keys);
	return $form;
}

sub _save_pref_item {
	my $S = shift;
	my $msg = '';
	my $pref = $S->cgi->param('pref');
	warn "(_save_pref_item) trying to save $pref" if $DEBUG;

	my $params;
	foreach my $item (qw(prefname title description visible html perm_view perm_edit var req_tu default_value length regex page field display_order template display_fmt enabled signup)) {
		$params->{$item} = $S->cgi->param($item);
	}

	if ( $pref eq $params->{prefname} ) {
		# editing an exiting pref?
		$params = $S->_pref_save_filter($params);

		my $set;
		foreach my $field (keys %{$params}) {
			$set .= "$field=$params->{$field}, ";
		}
		$set =~ s/, $//;

		# mangle the display_order
		$S->_pref_display_order($params->{prefname},$params->{display_order},$params->{page});

		my $q_pref = $S->dbh->quote($pref);
		my ($rv, $sth) = $S->db_update({
			DEBUG => $DEBUG,
			WHAT => 'pref_items',
			SET => $set,
			WHERE => "prefname = $q_pref"
		});
		$msg = $rv ? "$pref updated" : "error: database said " . $S->dbh->errstr();
		$sth->finish;
		$S->cache->remove('pref_items');
		$S->cache->stamp('pref_items');
		$S->_set_pref_items();
	} elsif ( !$pref ) {
		# creating a new pref?
		$params = $S->_pref_save_filter($params);

		my ($cols, $vals);
		foreach my $field (keys %{$params}) {
			$cols .= "$field, ";
			$vals .= "$params->{$field}, ";
		}
		$cols =~ s/, $//;
		$vals =~ s/, $//;

		my ($rv, $sth) = $S->db_insert({
			DEBUG => $DEBUG,
			INTO => 'pref_items',
			COLS => $cols,
			VALUES => $vals
		});
		$msg = $rv ? "$params->{prefname} added" : "error: database said " . $S->dbh->errstr();
		$sth->finish;
		$S->cache->remove('pref_items');
		$S->cache->stamp('pref_items');
		$S->_set_pref_items();
	} else {
		# something's wrong...
		$msg .= 'Pref name in field and selectbox must match, or selectbox must be set to "Add New".';
	}

	return $msg;
}

sub _delete_pref_item {
	my $S = shift;
	my $msg = '';
	my $pref = $S->cgi->param('pref');
	warn "(_delete_pref_item) trying to delete $pref" if $DEBUG;

	return "You must select a pref to delete" unless $pref;

	$pref = $S->dbh->quote($pref);
	my ($rv, $sth) = $S->db_delete({
		DEBUG => $DEBUG,
		FROM => 'pref_items',
		WHERE => "prefname = $pref"
	});
	$msg = $rv ? "$pref deleted" : "error: database said " . $S->dbh->errstr();
	$sth->finish;
	$S->cache->remove('pref_items');
	$S->cache->stamp('pref_items');
	$S->_set_pref_items();

	return $msg;
}

sub _pref_name_select {
	my $S = shift;
	my $current = ($S->cgi->param('get') && $S->cgi->param('get') eq 'Get') ? $S->cgi->param('pref') : $S->cgi->param('pref') || $S->cgi->param('prefname');
	warn "(_pref_name_select) currently selected: $current" if $DEBUG;
	my $prefnames;
	my $select = qq{
      <SELECT name="pref" size="1">
        <OPTION value="">Add New</OPTION>};

	my ($rv, $sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => 'prefname',
		FROM => 'pref_items',
		ORDER_BY => 'prefname asc'
	});
	$prefnames = $sth->fetchall_arrayref();
	$sth->finish();

	foreach my $pref (@{$prefnames}) {
		my $selected = ( $current eq $pref->[0] ) ? ' SELECTED' : '';
		$select .= qq{
        <OPTION value="$pref->[0]"$selected>$pref->[0]</OPTION>};
	}
	$select .= qq{
      </SELECT>};
	return $select;
}

sub _pref_template_select {
	my $S = shift;
	my $current = shift;
	warn "(_pref_template_select) currently selected: $current" if $DEBUG;
	my $select = qq{
      <SELECT name="template" size="1">};

	foreach my $block (sort keys %{$S->{UI}->{BLOCKS}}) {
		next unless $block =~ /_pref$/;
		my $selected = ( $current eq $block ) ? ' SELECTED' : '';
		$select .= qq{
        <OPTION value="$block"$selected>$block</OPTION>};
	}

	$select .= qq{
      </SELECT>};

	return $select;
}

sub _pref_var_select {
	my $S = shift;
	my $current = shift;
	warn "(_pref_var_select) currently selected: $current" if $DEBUG;
	my $selected = $current ? ' SELECTED' : '';
	my $select = qq{
      <SELECT name="var" size="1">
        <OPTION value=""$selected>None</OPTION>};

	foreach my $var (sort keys %{$S->{UI}->{VARS}}) {
		$selected = ( $current eq $var ) ? ' SELECTED' : '';
		$select .= qq{
        <OPTION value="$var"$selected>$var</OPTION>};
	}

	$select .= qq{
      </SELECT>};

	return $select;
}

sub _pref_perm_view_select {
	my $S = shift;
	my $current = shift;
	warn "(_pref_perm_view_select) currently selected: $current" if $DEBUG;
	my $selected = $current ? ' SELECTED' : '';
	my $select = qq{
      <SELECT name="perm_view" size="1">
        <OPTION value=""$selected>None</OPTION>};

	foreach my $perm (sort split(/,\s*/, $S->{UI}->{VARS}->{perms})) {
		$selected = ( $current eq $perm ) ? ' SELECTED' : '';
		$select .= qq{
        <OPTION value="$perm"$selected>$perm</OPTION>};
	}

	$select .= qq{
      </SELECT>};

	return $select;
}

sub _pref_perm_edit_select {
	my $S = shift;
	my $current = shift;
	warn "(_pref_perm_edit_select) currently selected: $current" if $DEBUG;
	my $selected = $current ? ' SELECTED' : '';
	my $select = qq{
      <SELECT name="perm_edit" size="1">
        <OPTION value=""$selected>None</OPTION>};

	foreach my $perm (sort split(/,\s*/, $S->{UI}->{VARS}->{perms})) {
		$selected = ( $current eq $perm ) ? ' SELECTED' : '';
		$select .= qq{
        <OPTION value="$perm"$selected>$perm</OPTION>};
	}

	$select .= qq{
      </SELECT>};

	return $select;
}

sub _pref_display_filter {
	my $S = shift;
	my $values = shift;
	my $get = shift;

	foreach my $key (keys %{$values}) {
		$values->{$key} =~ s/&/&amp;/g;
		$values->{$key} =~ s/>/&gt;/g;
		$values->{$key} =~ s/</&lt;/g;
		$values->{$key} =~ s/"/&quot;/g;
		if ($get && $get eq 'Get') {
			# overzealous quoting unless it's coming from the db...
			$values->{$key} =~ s/\|/\\|/g;
			$values->{$key} =~ s/\%\%/\|/g;
		}
	}

	return $values;
}

sub _pref_save_filter {
	my $S = shift;
	my $values = shift;

	foreach my $key (keys %{$values}) {
		$values->{$key} =~ s/\|/%%/g;
		$values->{$key} =~ s/\\%%/\|/g;

		$values->{$key} = $S->dbh->quote("$values->{$key}");
	}

	return $values;
}

sub _pref_display_order {
	my $S = shift;
	my $prefname = shift;
	my $order = shift;
	my $page = shift;

	# check to see if there's a pref using the display order value we're saving
	my ($rv,$sth) = $S->db_select({
		DEBUG => $DEBUG,
		WHAT => '*',
		FROM => 'pref_items',
		WHERE => qq|prefname!=$prefname AND display_order=$order AND page=$page|
	});
	return if ( $rv == 0 );

	# ok, something on the same page has the same display order and it isn't the current pref
	($rv,$sth) = $S->db_update({
		DEBUG => $DEBUG,
		WHAT => 'pref_items',
		SET => qq|display_order=display_order+1|,
		WHERE => qq|page=$page AND display_order>=$order|
	});
	return;
}

1;

