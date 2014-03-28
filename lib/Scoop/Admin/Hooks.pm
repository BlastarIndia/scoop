package Scoop;
use strict;

# Usage: $S->run_hook($hook, @params);
sub run_hook {
	my $S = shift;
	my $hook = shift;

	my $funcs = $S->{HOOKS}->{$hook};
	foreach my $func (@$funcs) {
		my $return;
		my $fname = $func->{func};
		if ($func->{enabled}) {
			if($func->{is_box}) {
				$return = $S->box_magic($fname, $hook, @_);
			} else {
				$return = $S->$fname($hook, @_);
			}
		}
	}
}

sub edit_hooks {
	my $S = shift;
#	my $msg = '';
	my $msg  = $S->_write_hooks();
	my $form = $S->_get_hooks_form($msg);
	return $form;
}

sub _write_hooks {
	my $S = shift;

	my $action = $S->cgi->param('action');

	return unless $action;

	my ($rv, $sth, $msg);
	if ($action eq 'add') {
		my $hook    = $S->cgi->param('new_hook');
		my $func    = $S->cgi->param('new_func');
		my $is_box  = $S->cgi->param('new_is_box')  ? 1 : 0;
		my $enabled = $S->cgi->param('new_enabled') ? 1 : 0;
		my $fb      = $is_box ? 'box' : 'function';

		return if (!$hook || !$func);

		my $f_hook = $S->{DBH}->quote($hook);
		my $f_func = $S->{DBH}->quote($func);

		($rv, $sth) = $S->db_insert({
			INTO   => 'hooks',
			COLS   => 'hook, func, is_box, enabled',
			VALUES => qq|'$hook', '$func', $is_box, $enabled|
		});
		$msg = "Bound $fb '$func' to hook '$hook'.";
	} elsif ($action eq 'delete') {
		my $vars = $S->cgi->Vars();
		my (@del, @msg);
		foreach my $parm (keys %$vars) {
			my ($hook,$func) = ($parm =~ /^del_([^,]+),(.+)$/);
			next if (!$hook || !$func);

			my $f_hook = $S->{DBH}->quote($hook);
			my $f_func = $S->{DBH}->quote($func);
			push @del, qq|(hook = $f_hook AND func = $f_func)|;
			push @msg, qq|hook '$hook' to function '$func'|;
		}
		return unless ($#del >= 0);

		my $del = join ' OR ', @del;
		($rv, $sth) = $S->db_delete({
			FROM  => 'hooks',
			WHERE => $del
		});
		$msg = "Removed bindings from:<br />&nbsp;  ".join('<br />&nbsp; ', @msg);
	} elsif ($action eq 'toggle') {
		my (@enable, @disable, @msg);
		# go through all of the hooks
		while (my ($hook, $funcs) = each %{ $S->{HOOKS} }) {
			# and all of the functions for each hook
			foreach my $f (@{ $funcs }) {
				# look to see if this hook/function combo is being changed
				if ($S->cgi->param("del_$f->{hook},$f->{func}")) {
					my $f_hook = $S->{DBH}->quote($f->{hook});
					my $f_func = $S->{DBH}->quote($f->{func});
					# toggle it's enabled status either on or off
					if ($f->{enabled}) {
						push(@disable, "(hook = $f_hook AND func = $f_func)");
						push(@msg, "$f->{hook}/$f->{func} off");
					} else {
						push(@enable, "(hook = $f_hook AND func = $f_func)");
						push(@msg, "$f->{hook}/$f->{func} on");
					}
				}
			}
		}

		if (@enable) {
			my $where = join(' OR ', @enable);
			($rv, $sth) = $S->db_update({
				WHAT  => 'hooks',
				SET   => 'enabled = 1',
				WHERE => $where
			});
			$sth->finish;
		}

		if (@disable) {
			my $where = join(' OR ', @disable);
			($rv, $sth) = $S->db_update({
				WHAT => 'hooks',
				SET  => 'enabled = 0',
				WHERE => $where
			});
			$sth->finish;
		}

		if (@msg) {
			$msg = "Toggled " . join(', ', @msg);
		} else {
			return;
		}
	} else {
		return;
	}

	if ($rv) {
		$S->cache->remove('hooks');
		$S->cache->stamp('hooks');
		undef $S->{HOOKS};
		$S->_load_hooks;
	} else {
		 $msg = "Error saving hook bindings. DB said: ". $S->{DBH}->errstr;
	}

	return $msg;
}

sub _get_hooks_form {
	my $S   = shift;
	my $msg = shift;

	my $hook = $S->cgi->param('hooks');
	my $get  = $S->cgi->param('get');

	my %hook_info = %{ $S->{HOOKS} || {} };

	my $hook_list = $S->_hook_select($hook, 'new_hook');

	# Build a table of existing hook functions
	my $funcs = qq|
		<table>
			<tr>
				<td>&nbsp;</td>
				<td>%%norm_font%%<b>Hook</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Binds To</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Is Box?</b>%%norm_font_end%%</td>
				<td>%%norm_font%%<b>Enabled</b>%%norm_font_end%%</td>
			</tr>|;
	foreach my $hk (sort { $a->[0]->{hook} cmp $b->[0]->{hook} } values %hook_info) {
		foreach my $func (@$hk) {
			my ($is_box, $func_link);

			if ($func->{is_box}) {
				my $box = $S->urlify($func->{func});
				$is_box = 'Yes';
				$func_link = qq|<a href="%%rootdir%%/admin/boxes/$box" target="_blank">$func->{func}</a>|;
			} else {
				$is_box = 'No';
				$func_link = $func->{func};
			}

			my $enabled = $func->{enabled} ? 'Yes' : 'No';

			$funcs .= qq|
			<tr>
				<td><input type="checkbox" name="del_$func->{hook},$func->{func}" /></td>
				<td>%%norm_font%%$func->{hook}%%norm_font_end%%</td>
				<td>%%norm_font%%$func_link%%norm_font_end%%</td>
				<td>%%norm_font%%$is_box%%norm_font_end%%</td>
				<td>%%norm_font%%$enabled%%norm_font_end%%</td>
			</tr>|;
		}
	}
	$funcs .= qq|
			<tr>
				<td>&nbsp;</td>
				<td>$hook_list</td>
				<td><input type="text" name="new_func" value="" /></td>
				<td><input type="checkbox" name="new_is_box" checked="checked" /></td>
				<td><input type="checkbox" name="new_enabled" checked="checked" /></td>
				<td>&nbsp;</td>
			</tr>
		</table>|;

	my $page = qq|
	<form action="%%rootdir%%/admin/hooks" method="POST">
	<table width="100%" border="0" cellpadding="2" cellspacing="0">
		<tr bgcolor="%%title_bgcolor%%">
			<td colspan="2">%%title_font%%Edit Hook Bindings%%title_font_end%%</td>
		</tr>
		<tr>
			<td colspan="2">%%norm_font%%<font color="#ff0000">$msg</font>%%norm_font_end%%</td>
		</tr>
		<tr>
			<td>$funcs</td>
		</tr>
		<tr>
			<td>
				%%norm_font%%<b>Action:</b>
				<input type="radio" name="action" value="add" /> Add Hook
				<input type="radio" name="action" value="delete" /> Delete Hooks
				<input type="radio" name="action" value="toggle" /> Toggle Enabled
				%%norm_font_end%%
			</td>
		</tr>
		<tr>
			<td>
				<input type="submit" name="save" value="Save Hooks" />
				<input type="reset" value="Reset" />
			</td>
		</tr>
		<tr>
			<td><br />%%norm_font%%<a href="%%rootdir%%/admin/vars?edit=GET;var=hooks">Edit Hook List</a>%%norm_font_end%%</td>
		</tr>
	</table>
	</form>|;

	return $page;
}

sub _hook_select {
	my $S = shift;
	my $hook_sel = shift;
	my $name = shift;

	my $page = qq|\t<select name="$name" size="1">
		<option value="">----------</option>|;
	my $hooks = $S->_hook_list();
	foreach my $h (sort keys %{$hooks}) {
		my $selected = ($hook_sel eq $h)? ' selected="selected"' : '';
		$page .= qq|
		<option value="$h"$selected>$h $hooks->{$h}</option>|;
	}
	$page .= "\n</select>";

	return $page;
}

sub _hook_list {
	my $S = shift;

	my $hooks_block = $S->{UI}->{VARS}->{hooks};
	$hooks_block =~ s/\r//g;
	my %hooks;
	foreach my $h (split /\n/, $hooks_block) {
		# seperate the hook name from the arguments in parenthesis
		$h =~ /^\s*(\w+)\s*(\([^\)]*\))\s*$/;
		$hooks{$1} = $2;
	}

	return \%hooks;
}

1;
