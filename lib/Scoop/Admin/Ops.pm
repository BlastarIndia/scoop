package Scoop;
use strict;

sub edit_ops {
	my $S = shift;
	my $msg  = $S->_write_ops();
	my $form = $S->_get_ops_form($msg);
	return $form;
}

sub _get_ops_form {
	my $S   = shift;
	my $msg = shift;

	my $opcode  = $S->cgi->param('opcode');
	my $tmpl_id = $S->cgi->param('tmpl_id');
	my $perm    = $S->cgi->param('perm');
	
	my $ops = $S->cgi->param('ops');
	my $get = $S->cgi->param('get');

	$opcode = $ops if $get;

	my $op_info = $S->{OPS}->{$opcode};

	my $op_list   = $S->_ops_selector($opcode);
	my $tmpl_list = $S->_ops_tmpl_selector($op_info->{template});
	my $perm_list = $S->_ops_perm_selector($op_info->{perm});

	my $is_box_checked  = $op_info->{is_box}  ? ' checked="checked"' : '';
	my $enabled_checked = $op_info->{enabled} ? ' checked="checked"' : '';
	my $delete_check    = '
		<tr>
			<td>&nbsp;</td>
			<td>%%norm_font%%
				<input type="checkbox" name="delete" value="1" />
				Delete this op%%norm_font_end%%
			</td>
		</tr>' if $opcode;
	my $edit_box;
	if ($op_info->{func} && $op_info->{is_box} && $S->{BOX_DATA}->{$op_info->{func}}) {
		my $box = $S->urlify($op_info->{func});
		$edit_box = qq| %%norm_font%%<a href="%%rootdir%%/admin/boxes/$box" target="_blank">[edit]</a>%%norm_font_end%%|;
	}

	my $page = $S->{UI}->{BLOCKS}->{edit_ops};
	
	$page =~ s/%%msg%%/$msg/g;
	$page =~ s/%%op_list%%/$op_list/g;
	$page =~ s/%%opcode%%/$op_info->{op}/g;
	$page =~ s/%%tmpl_list%%/$tmpl_list/g;
	$page =~ s/%%func%%/$op_info->{func}/g;
	$page =~ s/%%is_box_checked%%/$is_box_checked/g;
	$page =~ s/%%perm_list%%/$perm_list/g;
	$page =~ s/%%aliases%%/$op_info->{aliases}/g;
	$page =~ s/%%urltemplates%%/$op_info->{urltemplates}/g;
	$page =~ s/%%enabled_checked%%/$enabled_checked/g;
	$page =~ s/%%desc%%/$op_info->{description}/g;
	$page =~ s/%%delete_check%%/$delete_check/g;
	$page =~ s/%%edit_box%%/$edit_box/g;

	return $page;
}

sub _ops_selector {
	my $S = shift;
	my $opcode = shift;
	my $isalias;

	for (keys %{$S->{OPS}}) {
		map { $isalias->{$_} = $_; } split(/\s+/, $S->{OPS}->{$_}->{aliases});
	}

	my $page = qq|\t<select name="ops" size="1">
		<option value="">----------</option>|;
	foreach my $op (sort keys %{ $S->{OPS} }) {
		next if $isalias->{$op};
		my $selected = ($op eq $opcode) ? ' selected="selected"' : '';
		$page .= qq|
		<option value="$op"$selected>$op</option>|;
	}
	$page .= "\n</select>";

	return $page;
}

sub _ops_tmpl_selector {
	my $S = shift;
	my $cur_tmpl = shift;

	my ($rv,$sth) = $S->db_select({
		DISTINCT => 1,
		WHAT  => 'bid',
		FROM  => 'blocks',
		WHERE => 'bid LIKE \'%template\''
	});
	my @templates;
	while (my ($tmpl) = $sth->fetchrow_array) {
		# don't show ad_templates in the list
		next if $tmpl =~ /_ad_template$/;
		push(@templates, $tmpl);
	}
	$sth->finish;

	my $page = qq|\t<select name="tmpl_id" size="1">
		<option value="">----------</option>|;
	foreach my $t (sort @templates) {
		my $selected = ($t eq $cur_tmpl) ? ' selected="selected"' : '';
		$page .= qq|
		<option value="$t"$selected>$t</option>|;
	}
	$page .= "\n</select>";

	if ($cur_tmpl) {
		my $tmpl = $S->urlify($cur_tmpl);
		$page .= qq| %%norm_font%%<a href="%%rootdir%%/admin/blocks/edit/default/$tmpl" target="_blank">[edit]</a>%%norm_font_end%%|;
	}

	return $page;
}

sub _ops_perm_selector {
	my $S = shift;
	my $perm = shift;

	my $page = qq|\t<select name="perm" size="1">
		<option value="">----------</option>|;
	foreach my $p (sort @{ $S->get_perms() }) {
		my $selected = ($p eq $perm) ? ' selected="selected"' : '';
		$page .= qq|
		<option value="$p"$selected>$p</option>|;
	}
	$page .= "\n</select>";

	return $page;
}

sub _write_ops {
	my $S = shift;

	my $save   = $S->cgi->param('save');
	my $opcode  = $S->cgi->param('opcode');

	return unless $save && $opcode;
	my $urltpl = $S->cgi->param('urltemplates');
	$urltpl    =~ s/\\,/__COMMA__/g;	# Do Some Cleanup before saving
	my $tmpl    = $S->{DBH}->quote( $S->cgi->param('tmpl_id') );
	my $func    = $S->{DBH}->quote( $S->cgi->param('func'   ) ) || '';
	my $perm    = $S->{DBH}->quote( $S->cgi->param('perm'   ) ) || '';
	my $aliases = $S->{DBH}->quote( $S->cgi->param('aliases'   ) ) || '';
	$urltpl     = $S->{DBH}->quote( $urltpl ) || '';
	my $desc    = $S->{DBH}->quote( $S->cgi->param('desc'   ) ) || '';
	my $is_box  = $S->cgi->param('is_box' ) ? 1 : 0;
	my $enabled = $S->cgi->param('enabled') ? 1 : 0;
	my $delete = $S->cgi->param('delete');

	my $f_opcode = $S->{DBH}->quote($opcode);

	my $exists = $S->{OPS}->{$opcode} ? 1 : 0;

	my ($rv, $sth, $msg);
	# update an existing op
	if ($exists && !$delete) {
		($rv,$sth) = $S->db_update({
			WHAT  => 'ops',
			SET   => qq|template = $tmpl, func = $func, perm = $perm, aliases=$aliases, urltemplates = $urltpl, description = $desc, is_box = $is_box, enabled = $enabled|,
			WHERE => qq|op = $f_opcode|
		});
		$msg = "Op '$opcode' updated." if $rv;
	# delete an existing op
	} elsif ($exists && $delete) {
		($rv,$sth) = $S->db_delete({
			FROM  => 'ops',
			WHERE => qq|op = $f_opcode|
		});
		delete $S->{OPS}->{$opcode};
		$msg = "Op '$opcode' deleted." if $rv;
	# an insert
	} else {
		($rv,$sth) = $S->db_insert({
			INTO   => 'ops',
			COLS   => 'op, template, func, is_box, enabled, perm, aliases, urltemplates, description',
			VALUES => qq|$f_opcode, $tmpl, $func, $is_box, $enabled, $perm, $aliases, $urltpl, $desc|
		});
		$msg = "Op '$opcode' added." if $rv;
	}

	if ($rv) {
		$S->cache->clear({resource => 'ops', element => 'OPS'});
		$S->cache->stamp_cache('ops', time(), 1);
		$S->_load_ops();
	} else {
		$msg = "Error updating '$opcode'. DB said: " . $S->{DBH}->errstr;
	}

	return $msg;
}

1;
