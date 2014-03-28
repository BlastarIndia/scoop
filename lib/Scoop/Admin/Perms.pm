=head1 Perms.pm

This module contains all of the permission verifying functions like
have_perm() and have_section_perm() all accessible through the $S object.

=head1 Functions

=cut

package Scoop;
use strict;

=over 4

=item *
get_perms()

Returns an array ref of all available permissions. If you add another permission,
don't forget to add it to this array!

=back

=cut

sub get_perms {
	my $S = shift;

	my $permstr = $S->{UI}->{VARS}->{perms};
	$permstr =~ s/\n|\r|\s//g;
	my @perms = sort split(/,/, $permstr);

    return \@perms;
}


# Takes a string consisting of a comma-delimited list of perm values,
# such as one might find in the user.perms field in the Scoop DB.
# Returns a hashref containing each perm from the string as a key, 
# and '1' as the value (just a placeholder).
# This is a hashref because it's easy to check for the existence of a perm
# just by looking for a key. See have_perm() for more on that.
sub _unpack_perms {
	my $S = shift;
	my $perms = shift;
	
	my %perm_hash;
	foreach my $perm_name ( split(/,/, $perms) ) {
		$perm_hash{$perm_name} = 1;
	}
	
	return \%perm_hash;
}

# Opposite of _unpack_perms: Takes a hashref and converts it into a string, 
# comma delimited, just right for sticking in user.perms.
sub _pack_perms {
	my $S = shift;
	my $perms = shift;
	
	my $perm_str = join( ',', sort keys %{$perms});
	return $perm_str;
}


=over 4

=item *
group_perms($gid)

Takes a group ID, gets the perms hash for that user, returns it.
If no $gid is given, it uses $S->{GID}

=back

=cut

sub group_perms {
    my $S = shift;
	my $gid = shift;
	
    my $group = $S->group_data( $gid );
	my $perms = {};
	return $perms unless $group;
	
	$perms = $S->_unpack_perms( $group->{group_perms} );
	
	return $perms;
}


=over 4

=item *
group_section_perms($gid)

Similar to group_perms, but returns a hash ref with the section name as
the key, and the value is a comma delimited list of the permissions that
group $gid has for that section.  if no $gid is given, it uses $S->{GID}

=back

=cut

sub group_section_perms {
	my $S = shift;
	my $gid = shift || $S->{GID};
	my $f_gid = $S->{DBH}->quote($gid);
	my $sect_data = {};

	my ($rv,$sth) = $S->db_select({
		DEBUG	=> 0,
		WHAT	=> 'section,sect_perms',
		FROM	=> 'section_perms',
		WHERE	=> qq| group_id = $f_gid |,
		});

	unless( $rv ) {
		return $sect_data;
	}

	while( my $t = $sth->fetchrow_hashref ) {
		$sect_data->{ $t->{section} } = $t->{sect_perms};
	}

	return $sect_data;
}


=over 4

=item *
have_perm($perm_to_check)

Takes a permission value to check for, and optionally a group id (defaults
to the current group), and returns true if the user has this perm, and false
if not.

=back

=cut

sub have_perm {
    my $S = shift;
    my $perm_to_check = shift;
	return 0 unless $perm_to_check;

    my $gid = shift || $S->{GID};

	my @all_check;
	# Check what kind of arg the perms is, and make it an array
	if (ref($perm_to_check) eq "ARRAY") {
		@all_check = @{$perm_to_check};
	} elsif (ref($perm_to_check) eq "HASH") {
		unshift(@all_check, keys %{$perm_to_check});
	} elsif (!ref($perm_to_check)) {
		unshift(@all_check, $perm_to_check);
	} else {
		warn "In have_perm: Bad argument type-- must be scalar, hashref, or arrayref.\n";
		return 0;
	}
	
	#warn "  Checking group <<$gid>> for capability <<$perm_to_check>>\n";
    my $userperm;
	
	# Only look up perms from the db if it's not the current user,
	# otherwise used the perm hash cached in $S->{PERMS}
	if ($gid eq $S->{GID}) {
		$userperm = $S->{PERMS};
	} else {
		$userperm = $S->group_perms( $gid );
	}

	# TU perm checks. If the user in question is a trusted user, then we
	# split a list of permissions trusted users have and add them to
	# the userperm hash.
	my @tuarr = split(/,/, $S->var('tu_perms'));
	# make it a handy hashref
	my $turef = {};
	foreach my $tu (@tuarr){
		$turef->{$tu} = 1;
		}
	# Only add the TU perm to the userperm hash if it's actually being
	# checked (and if the user's actually trusted, of course)
	# This avoids an endless loop that seems to happen if you put a check
	# for supermojo in otherwise.
	foreach my $chkperm (@all_check){
		next if !$turef->{$chkperm};
		if(($S->{TRUSTLEV} == 2 || $S->have_perm('super_mojo')) && ($gid eq $S->{GID})){	
			$userperm->{$chkperm} = $turef->{$chkperm};
			}
		}
    
	# If the hash key is not there for any arg, we don't have access
	foreach my $perm (@all_check) {
		return 0 unless ($userperm->{$perm});
	}
	
	# Otherwise, we don't.
	return 1;
}


=over 4

=item *
have_section_perm($perm_to_check,$section,$gid)

$gid optional, defaults to $S->{GID}  Takes a section permission like
'norm_read_comments' or 'hide_read_stories', and returns 1 if the optional
$gid has that permission in the given section, 0 otherwise.
Currently, the possible permissions are:
[hide|deny|norm]_[read|post]_[comments|stories] for a total of 12 different
permissions.

=back

=cut

sub have_section_perm {
	my $S = shift;
	my $perm = shift;
	my $section = shift;
	my $gid = shift || $S->{GID};
	my $perm_hash = {};

	# if section is undef, say they have perms
	unless( $section && $section ne '' ) {
		return 1;
	}

	if( $gid eq $S->{GID} ) {
		$perm_hash = $S->{SECTION_PERMS};
	} else {
		$perm_hash = $S->group_section_perms( $gid );
	}

	return 1 if ( $perm_hash->{$section} =~ /$perm/ );
	return 0;
}


# Creates the table to edit permissions. Pretty self-explanatory.
# Takes a user_id, or defaults to the current user.
sub perm_table {
    my $S = shift;
    my $gid = shift || $S->{GID};
    my $cols = shift || 4;

	my $perms;
	$perms = $S->get_perms();

    my $retval = qq|<table width="100%" border=0 cellpadding=2 cellspacing=0>\n<tr>|;
    
    my $i;

    #my $js_off = sprintf( 'check_off( this.form )' );

	foreach my $perm ( @{$perms} ) {
	
		if( $i++ >= $cols ) {
			$i = 1;
			$retval .= qq|</tr><tr>\n|;
		}

		my $checked = $S->have_perm( $perm, $gid ) ? "CHECKED" : "";

		$retval .= qq|
			<td>
				<INPUT TYPE=checkbox NAME="$perm" VALUE=1 $checked>
				%%norm_font%%$perm%%end_norm_font%%
			</td>|;
	
	}

    #$retval .= qq|</tr><tr><td colspan=$cols><a href=''>uncheck all</a></td></tr></table>|;
	$retval .= qq|</tr></table><P>|;
    return $retval;
}

1;
