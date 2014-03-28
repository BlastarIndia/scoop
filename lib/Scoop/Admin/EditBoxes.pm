package Scoop;
use strict;

=pod

=head1 Scoop/Admin/EditBoxes.pm

This module defines the box admin interface. It has only one public method. 
The rest are private and should not be called from ouside this file. Most
notably here is that the HTML is abstracted from the codebase using the
 interpolate() method which has replaced the Template object.

=head2 Public Methods

=over 4

=item $S->edit_boxes()

This is the main method that generates the box administration interface by
first writing any existing data, then printing out the form interface.

=back

=cut

sub edit_boxes {
	my $S = shift;
	my $msg = $S->_write_box_page();
	my $form = $S->_get_box_form($msg);
	return $form;
}

=pod

=head2 Private Methods

=over 4

=item $S->_get_box_form()

This method handles the actual generation of the html form that comprises 
the box admin interface. There are static and dynamic elements to the form,
where the dynamic elements are assigned to keys in a substitution hash and
the static elements are defined in a block stored in the database (the
'admin_boxes_form' block), and local keys for the dynamic content
are interpolated using the $S->interpolate() interpolate. The approach of 
interpolating keys locally rather than create a per-request key namespace 
and have them interpolated once at the end of request processing is for 
simplicity and flexibility. Interpolating local keys piece-meil also avoids 
keynamespace collisions - although we hope people will use a proper naming 
convention to avoid such collisions anyway.

The recommended naming convention for local keys is:

<opcode>_<toolName>_<variableName>

where the hashRef to which these keys belong, would then be substituted back 
into the block representing the HTML of the interface, using the 
$S->interpolate() method.

=back

=cut

sub _get_box_form {
	my $S = shift;

	my $formData;	# Hash of data for interpolation
	$formData->{admin_boxes_errormsg} = shift || '&nbsp;';
	my $id     = $S->{CGI}->param('id');
	my $get    = $S->{CGI}->param('get');
	my $boxid  = $S->{CGI}->param('boxid');
	my $delete = $S->{CGI}->param('delete');
	my $write  = $S->{CGI}->param('write');

	if ( $id eq '' && !$get) {
		$id = $boxid;
	}
	
	my $box_data = $S->get_this_box($id);
	
	$formData->{admin_boxes_box_menu} = $S->_box_selector($id);
	$formData->{admin_boxes_template_menu} = $S->_template_selector($box_data->{template});
	$formData->{admin_boxes_template_link} = qq|<a href="%%rootdir%%/admin/blocks/edit/default/$box_data->{template}">[edit]</a>| if $box_data->{template};
	$formData->{admin_boxes_delete_check} = qq{
		<input type="checkbox" name="delete" value="1" />&nbsp;Delete this box};
	$formData->{admin_boxes_delete_check} = '' unless( $id && $id ne '' );

	unless ($delete == 1) {
		$formData->{admin_boxes_boxid} = $id;
		$formData->{admin_boxes_title} = $box_data->{title};
		$formData->{admin_boxes_description} = $box_data->{description};
		$formData->{admin_boxes_content} = $box_data->{content};
		$formData->{admin_boxes_choose_checked} = $box_data->{user_choose} ? "CHECKED" : "";

		# NOTE: This is the location of a bug in the box editor that has
		# been fixed and re-inserted more times than I can even count.
		# DO NOT TOUCH THIS CODE. Seriously. If we have to fix this one more time
		# there is going to be news of a massive cranial explosion
		# somewhere off the coast of Maine.
		#
		# The key fact is that in _write_box_page() below, the contents of the box
		# have already been munged for pipes and escaped pipes. So it's coming back
		# to us just like it is in the DB, regardless of whether this is a get or a save.
		#
		# If that didn't make sense, don't worry about it. Just know that it works, and if
		# you think it needs more fixing, you are wrong.
		#
		$formData->{admin_boxes_content} =~ s/\|/\\|/g;
		$formData->{admin_boxes_content} =~ s/%%/|/g;
		$formData->{admin_boxes_content} =~ s/&amp;/&amp;amp;/g;
		$formData->{admin_boxes_content} =~ s/&lt;/&amp;lt;/g;
		$formData->{admin_boxes_content} =~ s/&gt;/&amp;gt;/g;
		$formData->{admin_boxes_content} =~ s/&nbsp;/&amp;nbsp;/g;
		$formData->{admin_boxes_title} =~ s/"/&quot;/g;
		# Ok, that's all. You may now resume your regularly scheduled hacking.
		
		$formData->{admin_boxes_content} =~ s/</&lt;/g;
		$formData->{admin_boxes_content} =~ s/>/&gt;/g;
	}

	return $S->interpolate($S->{UI}->{BLOCKS}->{admin_boxes_form},$formData);
}

sub get_this_box {
	my $S = shift;
	my $id = shift;
	return undef unless $id;

	my $boxid = $S->{CGI}->param('boxid');
	my $template = $S->{CGI}->param('template');
	my $title = $S->{CGI}->param('title');
	my $description = $S->{CGI}->param('description');
	my $content = $S->{CGI}->param('content');
	my $get = $S->{CGI}->param('get');
	my $user_choose = $S->{CGI}->param('choose');

	if ( !$get && $template && $title && $description && $content && $boxid) {
		# If we got form values for everything, return those, UNLESS they
		# specifically requested a new box via pressing Get Box
		return {template    => $template,
		        title       => $title,
				boxid       => $boxid,
				description => $description,
				content     => $content,
				user_choose => $user_choose};
	} elsif ($S->{BOX_DATA}->{$id}) {
		# Otherwise, look in the cache
		return $S->{BOX_DATA}->{$id};
	} else {
		# Still no Then check the db
		my ($rv, $sth) = $S->db_select({
			WHAT => '*',
			FROM => 'box',
			WHERE => qq|boxid = '$id'|});
		my $box = $sth->fetchrow_hashref();
		$sth->finish();
		return $box;
	}
}
			
sub _template_selector {
	my $S = shift;
	my $id = shift;
	
	my ($rv, $sth) = $S->db_select({
		DISTINCT => 1,
		WHAT => 'bid',
		FROM => 'blocks',
		WHERE => qq|bid like '%box'|,
		ORDER_BY => 'bid'
	    });
	
	my $select = '';
	$select = ' selected="selected"' unless $id;
	my $page = qq|
		<select name="template" size="1">
		<option value=""$select>Select Template</option>|;
	
	while (my $data = $sth->fetchrow_hashref) {
		$select = '';
		if ($id eq $data->{bid}) {
			$select = ' selected="selected"';
		}
		$page .= qq|
			<option value="$data->{bid}"$select>$data->{bid}</option>|;
	}
	$page .= qq|
		</select>|;
	
	return $page;
}


sub _box_selector {
	my $S = shift;
	my $id = shift;
	
	my $select = '';
	$select = ' selected="selected"' unless $id;
	my $page = qq|
		<select name="id" size="1">
		<option value=""$select>Select Box</option>|;
	
	my %boxes = %{$S->{BOX_DATA}};
	foreach my $box (sort keys %boxes) {
		my $box_data = $boxes{$box};

		next if ( ($box eq $id) && $S->{CGI}->param('delete') );
	
		$select = ($box eq $id) ? ' selected="selected"' : '';
		$box_data->{boxid} =~ s/"/&quot;/g;

		$page .= qq|
			<option value="$box_data->{boxid}"$select>$box_data->{boxid}</option>|;
	}
	$page .= qq|
		</select>|;
	
	return ($page);
}

sub _write_box_page {
	my $S = shift;
	my $write = $S->{CGI}->param('write');
	my $delete = $S->{CGI}->param('delete') || 0;

	return unless $write;

	my $id = $S->{CGI}->param('id');
	my $boxid = $S->{CGI}->param('boxid');
	my $title = $S->{CGI}->param('title');
	my $description = $S->{CGI}->param('description');
	my $content = $S->{CGI}->param('content');
	my $template = $S->{CGI}->param('template');
	my $user_choose = $S->{CGI}->param('choose') ? 1 : 0;

	my $write_cont = $content;
	$write_cont =~ s/\|/%%/g;
	$write_cont =~ s/\\%%/\|/g;
	#$write_cont =~ s/&lt;/</g;
	#$write_cont =~ s/&gt;/>/g;
	#NO! Don't filter < and >, because the posted data doesn't contain 
	#those characters. The posted data is the exact data we WANT, apart
	#from the | and %% characters.

	# Do a test-compile of the box, to make sure it's good code.
	my $test_c = $S->_check_box($write_cont);
	return $test_c unless ($test_c == 1);
	
	#warn "In EditBoxes: Content (unescaped) is:\n$write_cont\n\n";
	
	$write_cont = $S->{DBH}->quote($write_cont);
	my $write_desc = $S->{DBH}->quote($description);
	
	$title =~ s/&quot;/"/g;
	$title = $S->{DBH}->quote($title);
	
	my ($rv, $sth);

	my $f_boxid = $S->{DBH}->quote($boxid);
	my $f_choose = $S->{DBH}->quote($user_choose);
	my $f_temp = $S->{DBH}->quote($template);

	# first, if its an update, and they aren't deleting
	if (($id eq $boxid) && !$delete ) {

		($rv, $sth) = $S->db_update({
			WHAT => 'box',
			SET => qq|title = $title, description = $write_desc, content = $write_cont, template = $f_temp, user_choose = $f_choose|,
			WHERE => qq|boxid = $f_boxid|
		});

	# if they're deleting, delete
	} elsif (($id eq $boxid) && $delete ) {

		($rv, $sth) = $S->db_delete({
			DEBUG	=> 0,
			FROM	=> 'box',
			WHERE	=> qq|boxid = $f_boxid|,
		});


	# must be an insert
	} else {
		($rv, $sth) = $S->db_insert({
			INTO => 'box',
			COLS => 'boxid, title, description, content, template, user_choose',
			VALUES => qq|$f_boxid, $title, $write_desc, $write_cont, $f_temp, $f_choose|
		});
	}
	
	if ($rv) {

		# Tell the cache!
		$S->cache->clear({resource => 'boxes', element => 'BOXES'});
		$S->cache->stamp_cache('boxes', time(), 1);
		$S->_load_box_data();
	
		unless( $delete ) {
			return "Box \"$boxid\" updated.";
		} else {
			return "Box \"$boxid\" deleted.";
		}

	}
	my $err = $S->{DBH}->errstr;
	return "Error updating \"$title\". DB said: $err";
}


sub _check_box {
	my $S = shift;
	my $code = shift;
	
	my $sandbox = 'sub { my ($S, $title, $template, @ARGS) = @_;
' . $code . '
}';
	
	eval( $sandbox );
	
	if ($@) {
		return "Error compiling box: $@";
	}
	
	return 1;
}

1;
