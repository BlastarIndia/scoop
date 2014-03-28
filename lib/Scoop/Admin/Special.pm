package Scoop;
use strict;

sub edit_special {
	my $S = shift;
	my $msg = $S->_write_special_page();
	my $form = $S->_get_special_form($msg);
	return $form;
}


sub _get_special_form {
	my $S = shift;
	my $keys = {};
	$keys->{msg} = shift || '&nbsp;';
	my $id = $S->{CGI}->param('id');
	my $pageid = $S->{CGI}->param('pageid');
	my $get = $S->{CGI}->param('get');
	my $delete = $S->{CGI}->param('delete');
	my $check_html = $S->{CGI}->param('html_check') || 0;
	my $spell_check = $S->{CGI}->param('spell_check') || 0;
	my $direct_link = $S->{CGI}->param('direct_link');

	if ($id eq '' && !$get) {
		$id = $pageid;
	}
	$keys->{id} = $id;

	my $page_data;
	($keys->{page_list}, $page_data) = $S->_special_page_selector($id);

	unless ($page_data) {
		$page_data->{content} = $S->{CGI}->param('content');
		$page_data->{title}  = $S->{CGI}->param('title');
		$page_data->{description} = $S->{CGI}->param('description');
	}

	$page_data->{content} =~ s/\|/\\\|/g;
	$page_data->{content} =~ s/%%/\|/g;
	$page_data->{title} =~ s/"/&quot;/g;

	# Preserve &'s literally.
	$page_data->{content} =~ s/&/&amp;/g;

	# this is so that any tags in the special page don't trail out of the <textblock>
	$page_data->{content} =~ s/\</&lt;/g;
	$page_data->{content} =~ s/\>/&gt;/g;

	if ($id && !$delete) {
		$keys->{preview} = $S->interpolate($S->{UI}->{BLOCKS}->{special_edit_preview}, {pageid => $keys->{id}, title => $page_data->{title}});
		$keys->{delete} = $S->{UI}->{BLOCKS}->{special_edit_delete};
	}
	
	$keys->{chkhtml_checked} = $check_html ? ' checked="checked"' : '';
	
	unless ($get) {
		$keys->{directlink_checked} = $direct_link ? ' checked="checked"' : '';
	}
	
	$keys->{directlink_checked} ||= ($S->check_for_special_alias($keys->{id})) ? ' checked="checked"' : '';
	
	if ($S->spellcheck_enabled()) {
		$keys->{spellcheck} = $spell_check ? $S->interpolate($S->{UI}->{BLOCKS}->{special_edit_spellcheck}, {splchk_checked => ' checked="checked"'}) : $S->{UI}->{BLOCKS}->{special_edit_spellcheck};
	}
	
	my $upload_page = $S->display_upload_form(0,'content');
	warn "Upload page: $upload_page\n";
	$keys->{upload_page} = $S->interpolate($S->{UI}->{BLOCKS}->{special_edit_upload}, {upload_form => $upload_page}) unless $upload_page eq '';

	foreach my $k (keys %{$page_data}) { 
		$keys->{$k} = $page_data->{$k}; 
	}
	
	my $page = $S->interpolate($S->{UI}->{BLOCKS}->{special_edit_form}, $keys);

	return $page;
}

sub _special_page_selector {
	my $S = shift;
	my $id = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'special'});
	
	my $select = '';
	$select = ' selected="selected"' unless $id;
	my $page = qq|
		<select name="id" size="1">
		<option value=""$select>Select Special Page</option>|;
	
	my $return_data;	
	while (my $page_data = $sth->fetchrow_hashref) {
		$select = '';
		$page_data->{title} =~ s/"/&quot;/g;
		if ($id eq $page_data->{pageid}) {
			$select = ' selected="selected"';
			$return_data = $page_data;
		}
		$page .= qq|
			<option value="$page_data->{pageid}"$select>$page_data->{title}</option>|;
	}
	$sth->finish;
	$page .= qq|
		</select>|;
	
	return ($page, $return_data);
}

sub _write_special_page {
	my $S = shift;
	my $write = $S->{CGI}->param('write');

	return unless $write;

	my $id = $S->{CGI}->param('id');
	my $pageid = $S->{CGI}->param('pageid');
	my $title = $S->{CGI}->param('title');
	my $description = $S->{CGI}->param('description');
	my $content = $S->{CGI}->param('content');
	my $check_html = $S->{CGI}->param('html_check');
	my $spell_check = $S->{CGI}->param('spell_check');
	my $direct_link = $S->{CGI}->param('direct_link');
	
	my $q_id = $S->{DBH}->quote($pageid);
	# get this out of the way first, since it doesn't depend on anything else
	if ($S->{CGI}->param('delete') && $id) {
		my ($rv, $sth) = $S->db_delete({
			FROM  => 'special',
			WHERE => "pageid = $q_id"
		});
		$sth->finish;
		
		# Remove the special op alias, if there is one
		$S->special_remove_op_alias($pageid);
		
		return "Page \"$title\" deleted.";
	}

	my ($errs, $files_written);
	if ($S->{CGI}->param('file_upload')) {
		my $file_upload_type = $S->{CGI}->param('file_upload_type');
		my ($return, $file_name, $file_size, $file_link) = $S->get_file_upload($file_upload_type);

		if ($file_upload_type eq 'content') {
			#replace content with uploaded file
			$content= $return unless $file_size ==0;
		} else { 
			# $return should be empty if we are doing a file upload, if not they are an error message
			$errs = $return;
			$files_written = qq{Saved File: <a href="$file_link">$file_name</a>}
				unless $file_link eq '';
		}
	}

	my @mis_spell;
	if ($spell_check && $S->spellcheck_enabled()) {
		my $callback = sub {
			my $word = shift;
			push(@mis_spell, $word);
			return $word;
		};

		if ($check_html) {
			$S->spellcheck_html_delayed($callback);
		} else {
			$S->spellcheck_html($content, $callback);
		}
	}

	if ($check_html) {
		my $page_ref = $S->html_checker->clean_html(\$content, '', 1);
		$content = $$page_ref;

		$errs .= $S->html_checker->errors_as_string
	}

	if (@mis_spell) {
		my $words_are = (@mis_spell == 1) ? 'word is' : 'words are';
		my $sc_errs = "The following $words_are mis-spelled:<br />\n<ul>\n";
		foreach my $m (@mis_spell) {
			$sc_errs .= "<li>$m<br />\n";
		}
		$sc_errs .= "</ul>\n";

		$errs .= "<p>" if $errs;
		$errs .= $sc_errs;
	}
	
	# add special op alias, if requested
	$errs .= $S->special_add_op_alias($pageid) if $direct_link;

	# Or, do we need to remove an op alias?
	if ($S->check_for_special_alias($pageid) && !$direct_link) {
		$S->special_remove_op_alias($pageid);
	}
	
	return $errs if $errs;

	my $write_cont = $content;
	$write_cont =~ s/\|/%%/g;
	$write_cont =~ s/\\%%/\|/g;
	$write_cont = $S->{DBH}->quote($write_cont);
	my $q_title = $S->{DBH}->quote($title);
	my $q_desc  = $S->{DBH}->quote($description);

	my ($rv, $sth);
	if ($id eq $pageid) {
		($rv, $sth) = $S->db_update({
			WHAT => 'special',
			SET => qq|title = $q_title, description = $q_desc, content = $write_cont|,
			WHERE => qq|pageid = $q_id|});
	} else {
		($rv, $sth) = $S->db_insert({
			INTO => 'special',
			COLS => 'pageid, title, description, content',
			VALUES => qq|$q_id, $q_title, $q_desc, $write_cont|});
	}
	$sth->finish;
	
	return "Page \"$title\" updated. $files_written" if $rv;
	my $err = $S->{DBH}->errstr;
	return "Error updating \"$title\". DB said: $err";
}


sub special_remove_op_alias {
	my $S = shift;
	my $id = shift;
	
	return unless $id;
	
	my @aliases = split /\s+/, $S->{OPS}->{special}->{aliases};
	
	my @new_aliases;
	foreach my $a (@aliases) {
		next if $a eq $id;
		push @new_aliases, $a;
	}
	
	my $aliases = join ' ', @new_aliases;
	$S->update_special_aliases($aliases);

	return;	
}

sub special_add_op_alias {
	my $S = shift;
	my $id = shift;
	
	return unless $id;
	
	# Look for an existing op named this
	my $collision = $S->check_op_collision($id);
	return "<br>Error: Can't add direct alias. It conflicts with an existing op." if ($collision);
	
	# Look for a special page alias already, and if it's there just return.
	my $exists = $S->check_for_special_alias($id);
	return if $exists;
	
	# Ok, no collision and no extant alias, so add one
	my $aliases = "$id " . $S->{OPS}->{special}->{aliases};
	$S->update_special_aliases($aliases);
	
	return;
}

sub update_special_aliases {
	my $S = shift;
	my $aliases = shift;
	my $q_aliases = $S->dbh->quote($aliases);
	
	my ($rv,$sth) = $S->db_update({
		WHAT => 'ops',
		SET   => qq|aliases = $q_aliases|,
		WHERE => 'op = "special"'
	});
	$sth->finish();
	
	# Clear the cache
	$S->cache->clear({resource => 'ops', element => 'OPS'});
	$S->cache->stamp_cache('ops', time(), 1);
	$S->_load_ops();
	
	return;
}	
	
sub check_op_collision {
	my $S = shift;
	my $id = shift;

	return unless $id;

	foreach my $op (keys %{$S->{OPS}}) {
		next if $op eq 'special';
		return 1 if $op eq $id;
		my @aliases = split /\s+/, $S->{OPS}->{$op}->{aliases};
		foreach my $alias (@aliases) {
			return 1 if $alias eq $id;
		}
	}
	
	return 0;
}

sub check_for_special_alias {
	my $S = shift;
	my $id = shift;
	return unless $id;
	
	foreach my $alias (split /\s+/, $S->{OPS}->{special}->{aliases}) {
		return 1 if $alias eq $id;
	}
	
	return 0;
}

	
1;
