=head1 Logging.pm

This file contains the subs relating to Logging administrator activity in scoop. The functions of greatest interest are log_activity and log_viewer.  

The sub log_activity is usually called from a hook, and inserts the appropriate information into the scoop database.  The sub log_viewer takes care of displaying the contents of the log table in a variety of manners.

=cut

package Scoop;
use strict;

my $DEBUG = 0;

#=over 4

=item * log_activity(log_type, [arg1], [arg2])

This sub inserts log information into the database, and if the log_type (usually a hook) is recognized it will store extended information if required.  Otherwise it will just store the information contained in the optional arguments $arg1 and $arg2.

=cut

sub log_activity {
	
	my $S        = shift;
	my $log_type = shift;
	my $arg1     = shift;
	my $arg2     = shift;

	return '' if ($S->var('use_logging') == 0);
	
	if ($log_type eq 'comment_delete') {
		$S->_log_comment_delete ($log_type, $arg1, $arg2);
	} elsif ($log_type eq 'story_update' || $log_type eq 'story_new') {
		$S->_log_story_update ($log_type, $arg1);
	} elsif ($log_type eq 'story_delete') {
		$S->_log_story_update ($log_type, $arg1);
	} else {
		$S->_log_insert($log_type, $arg1, $arg2, '');
	}

	
}

=item * log_viewer()

This sub is responsible for the display of the log viewer.  It depends on two parameters passed by CGI, 'log_type' and 'page'.  If the log_type is blank, then it will display a menu, otherwise it will display a list of the log entries stored in the database.

=cut

sub view_log {
	my $S = shift;
	my $log_type = $S->{CGI}->param('log_type') || 'main';
	my $page = $S->{CGI}->param('page') || 1; 
	my $msg;

	# check for special viewer commands
	return $S->_log_viewer_extended if ($page eq 'extended');

	$msg = $S->_log_action($page) if ($log_type eq 'act');
	return $S->_log_viewer_menu($msg) if (($log_type eq 'main') || $msg);

	my $header;
	my $where = "log_type='$log_type'";
	
	my ($col1, $col2, $title);
	if ($log_type eq 'comment_delete') {
		$title = "Deleted Comments";
		$col1  = "<td></td>";
		$col2  = "<td>%%norm_font%%<b>Comment</b>%%norm_font_end%%</td>";
	} elsif ($log_type eq 'all') {
		$title = "All Logged Records";
		$col1  = "<td>%%norm_font%%<b>Type</b>%%norm_font_end%%</td>";
		$col2  = "<td>%%norm_font%%<b>Item</b>%%norm_font_end%%</td>";
		$where = '';
	} else {
		$title = "Logged records for $log_type";
		$col1  = "<td></td>";
		$col2  = "<td>%%norm_font%%<b>Item</b>%%norm_font_end%%</td>";
	}
	$header = qq|
		<table border="0" width="100%">
		<tr>
		  <td colspan="6" bgcolor="%%title_bgcolor%%">%%title_font%%$title%%title_font_end%%</td>
		<tr>
		  $col1
		  $col2
		  <td>%%norm_font%%<b>User</b>%%norm_font_end%%</td>
		  <td>%%norm_font%%<b>IP Address</b>%%norm_font_end%%</td>
		  <td>%%norm_font%%<b>Date</b>%%norm_font_end%%</td>
		  <td></td>
		</tr>|; 

	my $items = 20;
	my $offset = (($page * $items) - $items) if $page;
	my $limit  = $offset ? "$offset, $items" : "$items";
	
	my ($rv, $sth) = $S->db_select({
		WHAT => '*',
		FROM => 'log_info',
		WHERE => "$where",
		ORDER_BY => 'log_id DESC',
		LIMIT => $limit
	});

	my $content = "<table border=0 width=100%>$header";

	# use this counter to decide if we should give a next page link
	my $items_displayed;
	while ( my $r = $sth->fetchrow_hashref ) {
		$items_displayed++;
		my $item_type = "<td></td>";
		$item_type = qq|<td valign="top">%%smallfont%%<a class="light" href="%%rootdir%%/admin/log/$r->{log_type}">$r->{log_type}</a>%%smallfont_end%%</td>| if $log_type eq 'all';
		my $more = qq| (<a class="light" href="%%rootdir%%/admin/log/$log_type/extended/$r->{log_id}">More</a>)|;
		$content .= qq|
			<tr>
			  $item_type
			  <td valign="top">%%smallfont%%$r->{log_item}%%smallfont_end%%</td>
			  <td valign="top">%%smallfont%%<a class="light" href="%%rootdir%%/user/uid:$r->{uid}/info">$r->{uid}</a>%%smallfont_end%%</td>
			  <td valign="top">%%smallfont%%$r->{ip_address}%%smallfont_end%%</td>
			  <td>%%smallfont%%$r->{log_date}%%smallfont_end%%</td>
			  <td>%%smallfont%%$more%%smallfont_end%%</td>
		</tr>|;
	};
	$sth->finish;

	my ($prev_page, $next_page);
	
	if ($page != 1) {
		$prev_page = qq|<a href="%%rootdir%%/admin/log/$log_type/| . ($page - 1) . qq|">Prev Page</a>|
	};

	if ($items_displayed == $items) {
		$next_page = qq|<a href="%%rootdir%%/admin/log/$log_type/| . ($page + 1) . qq|">Next Page</a>|;
	}

	$content .= qq|
		<tr>
		  <td colspan="3" align="left">%%norm_font%%$prev_page%%norm_font_end%%</td>
		  <td colspan="3" align="right">%%norm_font%%$next_page%%norm_font_end%%</td>
		</tr>
		<tr>
		  <td colspan="6" align="left"><a href="%%rootdir%%/admin/log">%%norm_font%%Back to main logging menu%%norm_font_end%%</a></td>
		</tr>
		</table>
	|;

	return $content;
}

sub _log_viewer_menu {
	my $S = shift;
	my $msg = shift;

	my $msg_row = $msg ?
		qq~<tr><td><font color="green">$msg</font></td></tr>~ : '';

	my $content = qq|
		<table border="0" width="100%">
		<tr>
		  <td bgcolor="%%title_bgcolor%%">%%title_font%%Logging Options%%title_font_end%%</td>
		</tr>
		$msg_row
		<tr>
		  <td>
		    %%norm_font%%
			<ul>
		      <li><a href="%%rootdir%%/admin/log/all">View list of all logged records</a></li>
		      <li><a href="%%rootdir%%/admin/log/comment_delete">View list of deleted comments</a></li>
		      <li><a href="%%rootdir%%/admin/log/story_delete">View list of deleted stories</a></li>
		      <li><a href="%%rootdir%%/admin/log/story_update">View list of updated stories</a></li>
		    </ul>
		    <b>Actions:</b>
		    <ul>|;
	$content .= qq|
		      <li><a href="%%rootdir%%/admin/log/act/clear_log">Clear logfile</a></li>| if $S->have_perm('edit_user');
	$content .= qq|
		      <li><a href="%%rootdir%%/admin/vars/edit/use_logging">Change logging level</a></li>| if $S->have_perm('edit_vars');
	$content .= qq|
		      <li><a href="%%rootdir%%/admin/log/act/enable_logging">Enable all logging hooks</a></li>| if $S->have_perm('edit_hooks');
	$content .= qq|
		      <li><a href="%%rootdir%%/admin/log/act/disable_logging">Disable all logging hooks</a></li>| if $S->have_perm('edit_hooks');
	$content .= qq|
		      <li><a href="%%rootdir%%/admin/hooks">Customize logging hooks</a></li>| if $S->have_perm('edit_hooks');
	$content .= qq|
		    </ul>
		    %%norm_font_end%%
		  </td>
		</tr>
	</table>|;
}

sub _log_action {
	my $S = shift;
	my $action = shift;

	if ($action eq 'clear_log' && $S->have_perm('edit_user')) {
		# delete extended log and logfile
		my ($rv, $sth) = $S->db_delete({FROM  => 'log_info_extended'});
		($rv, $sth) = $S->db_delete({FROM  => 'log_info'});
		
		$sth->finish;
		# insert log entry to indicate who cleared it
		$S->_log_insert('log_delete', 'all', 'Log Cleared', '');
		return "%%norm_font%%<b>Log Successfully cleared by $S->{NICK}</b>%%norm_font_end%%";	
	} elsif ($action eq 'enable_logging' && $S->have_perm('edit_hooks')) {
		$S->_log_addhooks;
		return "%%norm_font%%<b>Logging Enabled</b>";
	} elsif ($action eq 'disable_logging' && $S->have_perm('edit_hooks')) {
		$S->_log_deletehooks;
		return "%%norm_font%%<b>Logging Disabled</b>";
	} else {
		return '%%norm_font%%<b>Permission Denied</b>%%norm_font_end%%';
	}
}

sub _log_addhooks {
	my $S = shift;

	my ($rv, $sth) = $S->db_update({
		WHAT  => 'hooks',
		SET   => 'enabled = 1',
		WHERE => "func = 'log_activity'"
	});

	if ($rv) {
		$S->cache->remove('hooks');
		$S->cache->stamp('hooks');
		undef $S->{HOOKS};
		$S->_load_hooks;
	} else {
		 return "Error saving hook bindings. DB said: ". $S->{DBH}->errstr;
	}
	$sth->finish;
}

sub _log_deletehooks {
	my $S = shift;

	my ($rv, $sth) = $S->db_update({
			WHAT  => 'hooks',
			SET   => 'enabled = 0',
			WHERE => "func = 'log_activity'"
	});

	if ($rv) {
		$S->cache->remove('hooks');
		$S->cache->stamp('hooks');
		undef $S->{HOOKS};
		$S->_load_hooks;
	} else {
		 return "Error saving hook bindings. DB said: ". $S->{DBH}->errstr;
	}

	$sth->finish;
};

sub _log_viewer_extended {
	my $S = shift;
	
	my $log_id = $S->{CGI}->param('log_id');

	# Yes, it would be simpler to join them here, but I'm concerned with performance if the log is huge
	my ($rv, $sth) = $S->db_select({
		WHAT => 'extended_description',
		FROM => 'log_info_extended',
		WHERE => "log_id=$log_id"
	});

	my $r = $sth->fetchrow_hashref;
	my $extended = $r->{extended_description};
	
	($rv, $sth) = $S->db_select({
		WHAT =>	'*',
		FROM => 'log_info',
		WHERE =>"log_id=$log_id"
	});

	$r = $sth->fetchrow_hashref;
	my $user_nick = $S->get_nick_from_uid($r->{uid});
	
	my $content = qq|<table border=0 width=100%>
			  <tr>
			    <td bgcolor="%%title_bgcolor%%">%%title_font%%Extended Information%%title_font_end%%</td>
			  </tr>
			  <tr>
			    <td>
			      %%smallfont%%
				  <b>Log ID:</b> $r->{log_id}<br>
				  <b>Log Type:</b> $r->{log_type}<br>
				  <b>Item:</b> $r->{log_item}<br>
				  <b>Date:</b> $r->{log_date}<br>
				  <b>User:</b> $r->{uid} ($user_nick)<br>
				  <b>IP Address:</b> $r->{ip_address}<br>
				  <b>Description:</b> $r->{description}<br>
				  %%smallfont_end%%
			    </td>
			  </tr>
			  <tr>
			    <td>&nbsp;<br>%%smallfont%%<b>Extended:</b><br><br>$extended%%smallfont_end%%</td>
			  </tr>
			  <tr>
			    <td>
			      %%smallfont%%<br>
			        <ul>
			          <li><a href="%%rootdir%%/admin/log/$r->{log_type}">View $r->{log_type} listing</a></li>
				  <li><a href="%%rootdir%%/admin/log/all">View all log entries</a></li>
				</ul>
			      %%smallfont_end%%
			    </td>
			  </tr>
		</table>|;
	$sth->finish;

	return $content
}

sub _log_story_update {
	my $S	 = shift;
	my $log_type = shift;
	my $sid  = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT  => 'aid, title, introtext, bodytext, displaystatus',
		FROM  => 'stories',
		WHERE => "sid='$sid'"
	});

	my $story = '';
	my $r = $sth->fetchrow_hashref;
	my $title = $r->{title};
	my $status = $r->{displaystatus};
	my $aid = $S->get_nick_from_uid($r->{aid});
	$story = $r->{introtext} . '<p>---</p>' . $r->{bodytext} if $S->var('use_logging') == 2;
	
	$S->_log_insert($log_type, "$sid", "Author: $aid; Title: $title; Status: $status", $story);
	$sth->finish;	

}

sub _log_comment_delete {
	my $S    = shift;
	my $log_type = shift;
	my $sid  = shift;
	my $cid  = shift;
	
	my ($rv, $sth) = $S->db_select({
		WHAT  => 'subject, comment, uid',
		FROM  => 'comments',
		WHERE => "sid='$sid' AND cid='$cid'"
	});

	my $comment = '';
	my $r = $sth->fetchrow_hashref;
	my $subject = $r->{subject};
	$comment = $r->{comment} if $S->var('use_logging') == 2;

	my $author = $S->get_nick_from_uid($r->{uid});

	$S->_log_insert($log_type, "$sid#$cid", "Author: $author; Subject: $subject", $comment);
	$sth->finish;
}

sub _log_insert {
	my $S = shift;

	my $log_type = $S->{DBH}->quote(shift);
	my $log_item = $S->{DBH}->quote(shift);
	my $description = $S->{DBH}->quote(shift);
	my $extended_description = $S->{DBH}->quote(shift);

	my $uid = $S->{UID};
	my $extended = 0;
	my $ip_address = $S->{DBH}->quote($S->_get_remote_ip);
	my $current_date = $S->{DBH}->quote($S->_current_time);
	
	# clean up data for insert
	$extended = 1 if $extended_description;
	
	# insert into log
	my ($rv, $sth) = $S->db_insert({
		INTO   => 'log_info',
		COLS   => 'log_type, log_item, description, extended, uid, ip_address, log_date',
		VALUES => "$log_type, $log_item, $description, $extended, $uid, $ip_address, $current_date"
	});
	$sth->finish;

	# insert into extended log if applicable
	if ( $extended ) {

		# get the inserted entry log ID
		my $log_id = $S->{DBH}->{'mysql_insertid'};
		
		# clean up extended data
		
		($rv, $sth) = $S->db_insert({
			INTO   => 'log_info_extended',
			COLS   => 'log_id, extended_description',
			VALUES => "$log_id, $extended_description"
		});
		$sth->finish;
	};
}

1;
