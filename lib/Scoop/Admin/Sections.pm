package Scoop;
use strict;

=pod

=head1 Admin/Sections.pm

Sections.pm provided the administrative sections management interface, 
including section permissions and management of subsections.

=head1 Functions

=over 4

=item * edit_subsections()

This is the main function, called ApacheHandler.pm for display of the Sections
Admin interface. It is one of the two public functions found here. The vast 
majority of the HTML found in this file is contained in this function and has 
been reorganizedto facilitate migration of the HTML into a block when someone 
gets around to establishing block typing and language support.

=cut

sub edit_sections {
	my $S = shift;
	my ( $section, $sectionold );
	my $update = $S->{CGI}->param('update');
	my $delete = $S->{CGI}->param('delete');
	unless ($delete) {
		$section = $S->{CGI}->param('section');
		$sectionold = $S->{CGI}->param('sectionold') || $section;
	}
	my ( $rv, $sth );

	my $error;
	if ( $update =~ m/Section/ && !$delete ) {
		my $rv = $S->write_section;
		if ($rv) {
			$error = qq|<b>Error:</b> <font color="FF0000"><b>$rv</b></font>|;
			$section = $sectionold;    # Reset it just in case
		}
	} elsif ( $update =~ m/Section/ && $delete ) {
		my $rv = $S->delete_section;
		unless ($rv) {
			$error = qq|<b>Error! While Deleting Section "$section"</b>|;
		}
	}

	#-----------------
	if ( $section eq 'New' ) { $section = ''; }

	( $rv, $sth ) = $S->db_select(
		{
			WHAT  => '*',
			FROM  => 'sections',
			WHERE => qq|section = '$section'|
		}
	);

	my $section_form = $sth->fetchrow_hashref;
	$sth->finish;

	my $sect_perm_form  = $S->sect_perm_form($section);
	my $sect_parentlist = $S->_make_section_parentlist($section);
	my $sect_childlist  = $S->_make_section_childlist($section);
	my $sect_childmenu  = $S->_make_section_childmenu($section);
	my $submit_name     = ( $section =~ /^\s*$/ ) ? 'Write' : 'Update';

	my $content = qq{
<table border="0" cellpadding="0" cellspacing="0" width="100%">
  <tr>
    <td colspan="2" bgcolor="%%title_bgcolor%%">
      %%title_font%%Edit Section%%title_font_end%%
    </td>
  </tr>
  <tr>
    <td colspan="2">%%norm_font%%$error%%norm_font_end%%</td></tr>
  <tr>
    <td valign="top">
<!-- Edit Form Start -->
      <form name="editsections" action="%%rootdir%%/admin/sections" method="post">
        <input type="hidden" name="sectionold" value="$sectionold" />
        %%norm_font%%<b>Section:</b>%%norm_font_end%%<br />
        <input type="text" size="25" name="section" value="$section" /><br />
        %%norm_font%%<b>Display Title:</b>%%norm_font_end%%<br />
        <input type="text" size="50" name="title" value="$section_form->{title}" /><br />
        %%norm_font%%<b>Description:</b>%%norm_font_end%%<br />
        <textarea cols="50" rows="5" name="description">$section_form->{description}</textarea><br />
        %%norm_font%%<b>Section Icon:</b> (path after "imagedir")%%norm_font_end%%<br />
        <input type="text" size="50" name="icon" value="$section_form->{icon}" />
        <hr width="50%" noshade="noshade" />

	};

	unless ( $section eq '' ) {
		$content .= qq{
        <input type="checkbox" name="delete" value="1" />
        %%norm_font%%Delete this section? <b>|</b>%%norm_font_end%%
        <input type="checkbox" name="recursive" value="1" />
        %%norm_font%%Recursively<br />
        Section to move stories posted under "$section" to on delete:%%norm_font_end%%<br />};

		my $options = $S->_make_section_optionlist( $section, 'all' );
		$content .= qq{
        <select name="changeto_section">$options
        </select><hr width="50%" noshade="noshade" />};
	}

	$content .= qq{$sect_perm_form<br />};

	if ( $S->{UI}->{VARS}->{enable_subsections} ) {
		$content .= qq{
<br />$sect_parentlist
        <table border="0" width="99%">
          <tr><td align="center">$sect_childlist</td></tr>
          <tr>
            <td>%%norm_font%%<b>Add Child:</b>%%norm_font_end%%
$sect_childmenu
            </td>
          </tr>
        </table><br />
	};
	}
	$content .= qq{
        <center>
          <input type="submit" name="update" value="$submit_name Section" />
        </center>
      </form>
<!-- Edit Form End -->
    </td>
    <td valign="top">
      <table border="0" cellpadding="3" align="center">
        <tr>
          <td bgcolor="%%box_title_bg%%">
            %%box_title_font%%&nbsp;Sections:%%box_title_font_end%%
          </td>
        </tr>
        <tr>
          <td>};

	( $rv, $sth ) = $S->db_select(
		{
			WHAT     => '*',
			FROM     => 'sections',
			ORDER_BY => 'section asc'
		}
	);

	unless ( $rv eq '0E0' ) {
		while ( my $section = $sth->fetchrow_hashref ) {
			unless ( $section->{section} ) {
				$section->{section} = "New";
			}
			my $sect_link = $S->urlify( $section->{section} );
			$content .= qq{
            <a href="%%rootdir%%/admin/sections/$sect_link">%%norm_font%%$section->{title}%%norm_font_end%%</a><br />};
		}
	} else {
		$content .= qq{%%norm_font%%<b>None</b>%%norm_font_end%%};
	}
	$sth->finish;

	$content .= qq{
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
	};
	return $content;
}

=item * sect_perm_form()

Display the section permissions table. This function is calledfrom the 
edit_sections() function. This is a private function.

=cut

sub sect_perm_form {
	my $S       = shift;
	my $section = shift;

	# get a list of all of the groups
	my $groups = [];
	my $perms  = {};

	my ( $rv, $sth ) = $S->db_select(
		{
			DEBUG => 0,
			WHAT  => 'perm_group_id',
			FROM  => 'perm_groups',
		}
	);

	if ($rv) {
		while ( my $g = $sth->fetchrow_hashref ) {
			push ( @$groups, $g->{perm_group_id} );
		}
	}

	my $f_sect = $S->{DBH}->quote($section);

	my $where;
	unless ( $section && $section ne '' ) {
		$where = 'default_sect_perm = 1';
	} else {
		$where = "section = $f_sect";
	}

	# now get the permissions for each group in the given section
	( $rv, $sth ) = $S->db_select(
		{
			DEBUG => 0,
			WHAT  => 'group_id,sect_perms,default_sect_perm',
			FROM  => 'section_perms',
			WHERE => $where,
		}
	);

	# now generate a hash for ease of use when building the table
	# $perms->{groupnames}->{permission} = 1
	my $makedefchecked = '';
	if ($rv) {
		while ( my $sp = $sth->fetchrow_hashref ) {

			$perms->{ $sp->{group_id} } = {};
			for my $l ( split ( ",", $sp->{sect_perms} ) ) {
				next unless $l;
				$perms->{ $sp->{group_id} }->{$l} = 1;
			}

			if ( $sp->{default_sect_perm} == 1 && $section && $section ne '' ) {
				$makedefchecked = 'checked';
			}
		}
	}

	# generate the table
	my $form = qq{        <br />
        %%norm_font%%Make Default Section Permissions:%%norm_font_end%%
        <input type="checkbox" name="makedefault" value="1" $makedefchecked />
        <table width="100%" border="1" cellpadding="0" cellspacing="1">
          <tr>
            <th bgcolor="%%box_title_bg%%">%%box_title_font%%&nbsp;%%box_title_font_end%%</th>
            <th bgcolor="%%box_title_bg%%">%%box_title_font%%Post Stories%%box_title_font_end%%</th>
            <th bgcolor="%%box_title_bg%%">%%box_title_font%%Read Stories%%box_title_font_end%%</th>
            <th bgcolor="%%box_title_bg%%">%%box_title_font%%Post Comments%%box_title_font_end%%</th>
            <th bgcolor="%%box_title_bg%%">%%box_title_font%%Read Comments%%box_title_font_end%%</th>
          </tr>};

	# for each group, and each perm, see if they have the perm
	# and set the checkbox checked if they do.  
	for my $g (@$groups) {
		my $urlg = $S->urlify($g);
		$form .= qq{
          <tr>
            <td align="center">
              %%norm_font%%<b>$g</b>%%norm_font_end%%
            </td>};

		for my $p (qw( post_stories read_stories post_comments read_comments ))
		{

			$form .= qq{
            <td>
              <select name="${urlg}_${p}">};

			my ( $nrmsel, $hidsel, $dnysel, $autofpsel, $autosecsel );
			if ( $perms->{$g}->{"norm_$p"} ) {
				$nrmsel = " selected";
			} elsif ( $perms->{$g}->{"hide_$p"} ) {
				$hidsel = " selected";
			} elsif ( $perms->{$g}->{"deny_$p"} ) {
				$dnysel = " selected";
			} elsif ( $perms->{$g}->{"autofp_$p"} ) {
				$autofpsel = " selected";
			} elsif ( $perms->{$g}->{"autosec_$p"} ) {
				$autosecsel = " selected";
			}

			$form .= qq{
                <option value="Allow"$nrmsel>Allow</option>
                <option value="Hide"$hidsel>Hide</option>
                <option value="Deny"$dnysel>Deny</option>};

			if ( $p eq 'post_stories' ) {
				$form .= qq{
                <option value="autofp"$autofpsel>Auto-post Front Page</option>
                <option value="autosec"$autosecsel>Auto-post to Section</option>};
			}

			$form .= qq{
              </select>
            </td>	};

		}
		$form .= qq{
          </tr>};
	}

	$form .= qq{
        </table>};
	return $form;
}

=item * delete_section()

This deletes the section and changes all the stories under that section to 
appear under the specified target section. Sections may also be deleted 
recursively, such that any subsections are also deleted. In this case, the 
content of those subsections are also moved to the specified target section. 
Use this feature with care.

=cut

sub delete_section {
	my $S = shift;
	my ( $rv, $sth );
	my $params   = $S->cgi->Vars;
	my @sections = ( $params->{'section'} );    # Start with one section

	# quote!  Don't want people screwing with our database!
	my $f_newsect = $S->{DBH}->quote( $params->{changeto_section} );

	while ( my $sect = shift (@sections) ) {
		push ( @sections, keys %{ $S->{SECTION_DATA}->{$sect}->{children} } )
		  if $params->{recursive};
		my $f_sect = $S->{DBH}->quote($sect);

		# first make sure all the data matches, if it doesn't
		# return 0 for error.
		( $rv, $sth ) = $S->db_select(
			{
				DEBUG => 0,
				FROM  => 'sections',
				WHAT  => 'section',
				WHERE => qq| section=$f_sect |,
			}
		);
		$sth->finish;

		unless ( $rv == 1 ) { return 0; }

		# Since the section exists, lets delete it!
		( $rv, $sth ) = $S->db_delete(
			{
				DEBUG => 0,
				FROM  => 'sections',
				WHERE => qq| section=$f_sect |,
			}
		);
		$sth->finish;

		# Don't forget to update the stories table!
		( $rv, $sth ) = $S->db_update(
			{
				DEBUG => 0,
				WHAT  => 'stories',
				SET   => qq| section=$f_newsect |,
				WHERE => qq| section=$f_sect |,
			}
		);
		$sth->finish;

		# and get it out of the section_perms too!
		( $rv, $sth ) = $S->db_delete(
			{
				DEBUG => 0,
				FROM  => 'section_perms',
				WHERE => qq| section=$f_sect |,
			}
		);

		# Now Clean Up Subsections
		my ( $rv, $sth ) = $S->db_delete(
			{
				DEBUG => 0,
				FROM  => 'subsections',
				WHERE => qq{ section=$f_sect OR child=$f_sect },
			}
		);
		$sth->finish;
	}

	# Clear and update the cache
	$S->cache->clear( { resource => 'sections', element => 'SECTIONS' } );
	$S->cache->stamp_cache( 'sections', time() );
	$S->_load_section_data();

	return 1;
}

=item * write_section()

All that's being done here is writing/updating section data i nthe DB and
Updating the sections hash. That's about it here.

=cut

sub write_section {
	my $S      = shift;
	my $params = $S->{CGI}->Vars;
	my ( $rv, $sth, $error );

	# Do some basic tests
	unless ( $params->{'section'} =~ m/^[-_\w]+$/ ) {
		$error .=
"Section names can contain only alphanumeric characters, '-' and '_'<br />";
	}
	if ( $params->{'title'} =~ m/^\s*$/ ) {
		$error .= "Please Specify a Display Title<br />";
	}
	return ($error) if $error;

	my $f_param = {};

	foreach my $key ( keys %{$params} ) {
		$f_param->{$key} = $S->{DBH}->quote( $params->{$key} );
	}

	if ( $params->{sectionold} eq 'New'
		|| $params->{sectionold} eq ''
		|| $params->{sectionold} ne $params->{section} )
	{
		( $rv, $sth ) = $S->db_insert(
			{
				INTO   => 'sections',
				COLS   => 'section, title, description, icon',
				VALUES =>
qq|$f_param->{section}, $f_param->{title}, $f_param->{description}, $f_param->{icon}|
			}
		);
		$sth->finish;

		# make sure everyone gets permissions to post to the new section too
		$S->_save_sect_perms( $params, 'new' );
		$S->_handle_subsections();

	} else {
		( $rv, $sth ) = $S->db_update(
			{
				WHAT => 'sections',
				SET  =>
qq|title=$f_param->{title}, description=$f_param->{description}, icon=$f_param->{icon}|,
				WHERE => qq|section = $f_param->{section}|
			}
		);

		$S->_save_sect_perms( $params, 'old' );
		$S->_handle_subsections();
	}
	$sth->finish;

	# Update the DB cache
	$S->cache->clear( { resource => 'sections', element => 'SECTIONS' } );
	$S->cache->stamp_cache( 'sections', time(), 1 );
	$S->_load_section_data();

	if ($rv) { return 0; }
	else { return $S->{DBH}->errstr; }
}

=item * _save_sect_perms()

Here we're actually doing the work of of INSERTing/UPDATEing the section 
permissions table.

=cut

sub _save_sect_perms {
	my $S      = shift;
	my $params = shift;
	my $new    = shift;

	my $f_sect      = $S->{DBH}->quote( $params->{section} );
	my $group_perms = {};

	# get a list of all the groups, and make a hash of the perms they have
	my ( $rv, $sth ) = $S->db_select(
		{
			WHAT => 'perm_group_id',
			FROM => 'perm_groups',
		}
	);

	return unless ($rv);

	# Now, for each group, get its values from the form, and update their
	# permissions in the section_perms table
	while ( my $g = $sth->fetchrow_hashref ) {

		my $group   = $g->{perm_group_id};
		my $urlperm = $S->urlify( $g->{perm_group_id} );

		for my $p (qw( read_comments post_comments read_stories post_stories ))
		{
			$p =~ /\w{4}_(\w+)/;
			my $ptype = $1;
			my $pname = '';
			if ( $params->{"${urlperm}_${p}"} eq 'Allow' ) {
				$pname = "norm_$p";
			} elsif ( $params->{"${urlperm}_${p}"} eq 'Deny' ) {
				$pname = "deny_$p";
			} elsif ( $params->{"${urlperm}_${p}"} eq 'Hide' ) {
				$pname = "hide_$p";
			} elsif ( $params->{"${urlperm}_${p}"} eq 'autofp' ) {
				$pname = "autofp_$p";
			} elsif ( $params->{"${urlperm}_${p}"} eq 'autosec' ) {
				$pname = "autosec_$p";
			}
			$group_perms->{$group} .= ',' . $pname;
		}

		my $default = $S->{CGI}->param('makedefault');
		unless ( $default == 1 ) {
			$default = 0;
		}

		if ( $new eq 'new' ) {

			my ( $rv2, $sth2 ) = $S->db_insert(
				{
					DEBUG  => 0,
					INTO   => 'section_perms',
					VALUES =>
qq| '$group', $f_sect, '$group_perms->{$group}', $default |,
				}
			);
			$sth2->finish;

		} else {

			my ( $rv2, $sth2 ) = $S->db_update(
				{
					DEBUG => 0,
					WHAT  => 'section_perms',
					SET   =>
qq| sect_perms = '$group_perms->{$group}', default_sect_perm = $default |,
					WHERE => qq| section = $f_sect and group_id = '$group' |,
				}
			);
			$sth2->finish;

		}

	}
}

=item * _make_section_optionlist()

Take a list of sections from the DB and generate a set of links to the admin 
interfacefor that section. We could probably get this from the 
$S->{SECTION_DATA} data structure, since hopefully the structure is up-to-date
(asuming we have properly updated it after each of the admin operations.

=cut

sub _make_section_optionlist {
	my $S              = shift;
	my $section_to_del = shift;
	my $type           = shift || 'all';
	my $list           = "";

	my ( $rv, $sth ) = $S->db_select(
		{
			DEBUG    => 0,
			WHAT     => 'section, title',
			FROM     => 'sections',
			ORDER_BY => 'section ASC'
		}
	);

	my $no_read_sects = $S->get_disallowed_sect_hash('norm_read_stories');
	$no_read_sects = {} if ( $type eq 'all' );

	if ($rv) {
		my $section;
		while ( $section = $sth->fetchrow_hashref ) {
			next if ( $section->{section} eq $section_to_del );
			next if ( $no_read_sects->{ $section->{section} } == 1 );

			$list .= qq{
          <option value="$section->{section}">$section->{title}</option>}; #"
		}
	}
	$sth->finish;

	return $list;
}

=item * get_section()

This silly little stub function exists for backard compatibility. All it does
is return data from the $S->{SECTION_DATA} data structure.

=cut

sub get_section {
	my $S       = shift;
	my $section = shift;

	return unless $section;

	my $ret_sec = $S->{SECTION_DATA}->{$section};

	return $ret_sec;
}

=item get_sections()

This returns an array ref of all the sections. People change sections too much
to hardcode this like get_perms, so get it from the SECTION_DATA hash

=cut

sub get_sections {
	my $S        = shift;
	my @sections = keys( %{ $S->{SECTION_DATA} } );
	return \@sections;
}

=item * get_disallowed_sect_hash()

This returns a list of the sections the group given doesn't have permission to 
do whatever perm is given.

=cut

sub get_disallowed_sect_hash {
	my $S    = shift;
	my $perm = shift;

	return {} unless ( defined $perm );

	my $sect_hash = {};
	for my $s ( keys %{ $S->{SECTION_PERMS} } ) {

		if ( $S->{SECTION_PERMS}->{$s} !~ /$perm/ ) {
			$sect_hash->{$s} = 1;
		}

	}

	return $sect_hash;
}

=item * get_disallowed_sect_sql($sect_perm, $group)

This returns some sql of the form 'section != '$section' AND section ...'
for use in random queries so people don't get stories from sections they
aren't allowed to.  Takes at least one param, the permission to check against.
The second parameter is the group to check for.

=cut

sub get_disallowed_sect_sql {
	my $S    = shift;
	my $perm = shift;
	my $group = shift || $S->{GID};

	return '' unless ( defined $perm );

	my $sect_sql = '';
	my $sect_hash = {};
	if( $group eq $S->{GID} ) {
		$sect_hash = $S->{SECTION_PERMS};
	}
	else {
		$sect_hash = $S->group_section_perms($group);
	}

	for my $s ( keys %{ $sect_hash } ) {
		if ( $sect_hash->{$s} !~ /$perm/ ) {
			$sect_sql .= qq| section != '$s' AND |;
		}

	}

	# get rid of the trailing AND
	$sect_sql =~ s/ AND $//;

	return $sect_sql;
}

=item * get_inheritable_sect_sql()

This returns some sql of the form 'section = 'inheritedSect' AND section ...'
so as to allow the stories display code to determine what stories to inherit 
from child sections.

=cut

sub get_inheritable_sect_sql {
	my $S = shift;
	return ( join ( ' OR ', map{'section='.$S->dbh->quote($_)} $S->get_inheritable_sect_array(shift) ) );
}


=item * get_inheritable_sect_array()

Takes a string section name and generate an array of sections from which to 
inherit content. If no section name is provided, take it from param('section')

=cut

sub get_inheritable_sect_array {
	my $S = shift;
	my @sections = ( shift || $S->cgi->param('section') );
	my @sectout=@sections;
	while ( my $section = shift (@sections) ) {
		next unless $S->{SECTION_DATA}->{$section}->{children};
		for ( keys %{ $S->{SECTION_DATA}->{$section}->{children} } ) {
			if ( $S->{SECTION_DATA}->{$section}->{children}->{$_}->{inheritable} ){
				if($S->have_section_perm( 'norm_read_stories', $_ )){
					push ( @sections, $_ );
					push ( @sectout, $_ );
				}
			}
		}
	}
	return (wantarray)?@sectout:\@sectout;
}

=item * _make_section_parentlist()

This private function generates the list of section parents shown near the 
bottom of the sections admin interface. This mechanism may change so don't use
this function outside of Sections.pm

=cut

sub _make_section_parentlist {
	my $S       = shift;
	my $section = shift;
	my $return;
	my @paths = $S->section_paths($section);
	for (@paths) {
		s/\/?$section$//;    # Remove if Current Section
s/([^\/]+)/<\/b><a href="%%rootdir%%\/admin\/sections\/$1">%%norm_font%%<b>$S->{SECTION_DATA}->{$1}->{title}<\/b>%%norm_font_end%%<\/a><b>/g;
		s/^<\/b>//;          # Clean Up After Ourselves
		s/<b>$//;            # And some more cleaning
		$return .=
"              $_<b>/</b>%%norm_font%%$S->{SECTION_DATA}->{$section}->{title}%%norm_font_end%%<br />\n"
		  if $_;
	}
	return qq{
        <table border="0" width="98%">
          <tr>
            <td valign="top"><b>Parent Sections:</b></td>
            <td valign="top" nowrap="nowrap">\n}
	  . ( ($return) ? $return : '<b>Top Level</b>' ) . qq{            </td>
          </tr>
        </table>
	};
}

=item * _make_section_childlist()

This private function displays the list if children with the checkboxes for 
child section characteristics. Again, there's no excuse to use this outside of
Sections.pm

=cut

sub _make_section_childlist {
	my $S       = shift;
	my $section = shift;
	my $return;
	for ( keys %{ $S->{SECTION_DATA}->{$section}->{children} } ) {

		my $checked =
		  ( $S->{SECTION_DATA}->{$section}->{children}->{$_}->{inheritable} )
		  ? ' checked="checked"'
		  : '';

		my $checked2 =
		  ( $S->{SECTION_DATA}->{$section}->{children}->{$_}->{invisible} )
		  ? ' checked="checked"'
		  : '';

		$return .= qq{
<tr><td align="center"><input type="checkbox" name="delete-child" value="$_" /></td>
<td align="center">&nbsp;<a href="%%rootdir%%/admin/sections/$_">%%norm_font%%$S->{SECTION_DATA}->{$_}{title}%%norm_font_end%%</a>&nbsp;</td>
<td align="center"><input type="checkbox" name="inheritable" value="$_"$checked /></td>
<td align="center"><input type="checkbox" name="invisible" value="$_"$checked2 /></td></tr>
		};

	}

	$return = qq{<table border="1">
<tr><th bgcolor="%%box_title_bg%%">&nbsp;%%box_title_font%%Delete%%box_title_font_end%%&nbsp;</th>
<th bgcolor="%%box_title_bg%%">&nbsp;%%box_title_font%%Child%%box_title_font_end%%&nbsp;</th>
<th bgcolor="%%box_title_bg%%">&nbsp;%%box_title_font%%Inheritable%%box_title_font_end%%&nbsp;</th>
<th bgcolor="%%box_title_bg%%">&nbsp;%%box_title_font%%Invisible%%box_title_font_end%%&nbsp;</th></tr>
$return</table><br />} if $return;

	return $return;
}

=item * _make_section_childmenu()

This private function generates the list of sections eligable for addition as a
child of the section currently being displayed in the admin interface. Again, 
don't call this from outside of Sections.pm

=cut

sub _make_section_childmenu {
	my $S       = shift;
	my $section = shift;
	my $return;
	my $parents = $S->section_paths($section);

	for ( sort keys %{ $S->{SECTION_DATA} } ) {
		next if ( $parents->{$_} );
		next if ( $S->{SECTION_DATA}->{$section}->{children}->{$_} );
		next unless ( defined $_ && $_ ne '' );
		$return .=
			qq{                <option value="$_">$S->{SECTION_DATA}->{$_}->{title}</option>\n};
	}

	$return = qq{              <select name="add-child">
                <option value="" selected="selected">----------</option>
$return              </select>} if $return;

	return $return;
}

=item * _handle_subsections()

This function does all the work of adding and updating subsections. It's quite 
efficient but could do with a little explanation. We don't take function args 
at all. We work directly from the CGI args. The value of this is depatable. We 
care about four things. The section being administered, the child section we're
INSERTing/UPDATEing, and the characteristics of the child section, which are 
'invisible' and 'inheritable'.

First, we get the name of the section being administered, then weprocess the 
arrays containing each of the child section characteristics. We then identify 
the child section(s) which are being added/edited, generating the appropriate 
SQL statements as we go. We then take those statements and loop through then 
applying the changes to the DB. That's all folks.

=cut

sub _handle_subsections {
	my $S       = shift;
	my $updates = {};
	my $section = $S->cgi->param('section');
	my ( %invisible, %inheritable );

	# The params invisible and inheritable are arrays - don't forget that
	map { $invisible{$_}   = 1; } $S->cgi->param('invisible');
	map { $inheritable{$_} = 1; } $S->cgi->param('inheritable');

	for ( keys %{ $S->{SECTION_DATA}->{$section}->{children} } ) {
		$invisible{$_}   = ( $invisible{$_} )   ? '1' : '0';
		$inheritable{$_} = ( $inheritable{$_} ) ? '1' : '0';
		unless ( $invisible{$_} ==
			$S->{SECTION_DATA}->{$section}->{children}->{$_}->{invisible} )
		{
			$updates->{$_} = "invisible='$invisible{$_}'";
		}
		unless ( $inheritable{$_} ==
			$S->{SECTION_DATA}->{$section}->{children}->{$_}->{inheritable} )
		{
			$updates->{$_} .= ", " if $updates->{$_};
			$updates->{$_} .= "inheritable='$inheritable{$_}'";
		}
	}
	for ( keys %{$updates} ) {
		my ( $rv, $sth ) = $S->db_update(
			{
				DEBUG => 0,
				WHAT  => 'subsections',
				SET   => qq{$updates->{$_}},
				WHERE => qq{section = '$section' AND child = '$_'}
			}
		);
		$sth->finish;
	}
	for my $child ( $S->cgi->param('delete-child') ) {
		my ( $rv, $sth ) = $S->db_delete(
			{
				DEBUG => 0,
				FROM  => 'subsections',
				WHERE => qq{ section='$section' AND child='$child' },
			}
		);
		$sth->finish;
	}
	if ( my $child = $S->cgi->param('add-child') ) {
		my ( $rv, $sth ) = $S->db_insert(
			{
				DEBUG  => 0,
				INTO   => 'subsections',
				COLS   => 'section, child',
				VALUES => qq{'$section', '$child'}
			}
		);
		$sth->finish;
	}
}

=item section_paths()

This public function generates an array containing 'paths' from the sections 
passed as args, to the top of the section structure. It does this by iterating 
through the data structure and constructing strings that represent these paths.

It's important to note that child sections may have multiple parents, so 
multiple paths may be returned for any one section argument. The function will 
take an array of sections as arguments.

The function iterates through the argument list, and all of the parents of that
list of sections. A map() statement is used to evaluate whether the current 
section name should be incorporated as an element of any of the returned paths.
To make this determination, the section permissions 'hide_read_stories', 
'deny_read_stories', and the permission 'show_hidden_sections' as well as the 
subsection characteristic 'invisible' were evaluated. Also, the special case 
of top level sections had to be tested outside the map(). There was much debate
as to the best way for this function to be implemented. The debate can be found
at : http://www.kuro5hin.org/story/2002/3/22/134555/995

The function will return either an array of strings representing 'paths' to the
top of the section structure for the site, or a hash reference with element 
names being the names of sections contained in path from the argment section(s)
with the value of each, set to '1'. The latter return type is used within the 
Sections.pm file and while it's available outside of Sections.pm, developers 
will be far more likely to find the former return value more useful.

=cut

sub section_paths {
	my $S     = shift;
	my @lines = @_;	# the list of sections for which we need paths
	my @paths = ();	# Gotta have a place for the return values
	my $frags;	# If we're not returning an array, return this
	while ( my $line = shift (@lines) ) {
		my ($element) = split ( /\//, $line );
		$frags->{$element} = 1;	# For the hash of parents if needed
		my @temp;    # Defined here in case there are no parents
		if($S->{SECTION_DATA}->{$element}->{parents}){
			@temp = map {
				(
				  ( $S->{SECTION_DATA}->{$_}->{children}->{$element}->{invisible}
				  || $S->have_section_perm( 'hide_read_stories', $element )
				  || $S->have_section_perm( 'deny_read_stories', $element ) )
				  && !$S->have_perm('show_hidden_sections')
				) ? $_ :	# Add the current fragment OR
					$_. "/$line"; # Tac on an existing line
			  } keys %{ $S->{SECTION_DATA}->{$element}->{parents} };
		}
		if ( $#temp == -1 ) {	# We're at the top of the path
			my ($topsect) = split ( /\//, $line );
			if ( !$S->have_section_perm( 'hide_read_stories', $topsect )
				&& !$S->have_section_perm( 'deny_read_stories', $topsect ) )
			{
				push ( @paths, $line );
			}
		} else {
			push ( @lines, (@temp) );
		}
	}
	return ( (wantarray) ? @paths : $frags );
}

1;
