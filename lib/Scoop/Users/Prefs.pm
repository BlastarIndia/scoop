package Scoop;
use strict;

my $DEBUG = 0;

=pod

=head1 Users/Prefs.pm

This file contains user info and user preference management.

=head1 FUNCTIONS

=over 4

=item user_info

Displays the user info page, creating it from those prefs marked visible and
which the current user has permission to view.

=cut

sub user_info {
	my $S = shift;
	my $uid = shift;
	my $nick = $S->param->{nick};
	my $return = $S->{UI}->{BLOCKS}->{user_info_page};
	my $trusted_msg = '';
	warn "(user_info) user $S->{UID} requesting user info for $uid" if $DEBUG;

	#get user info and user prefs
	my $user = $S->user_data($uid);

	#get trusted/untrusted user message
	if ( $S->{TRUSTLEV} == 2 && $S->{UID} == $uid ) {
		$trusted_msg = $S->{UI}->{BLOCKS}->{trusted_info_message};
	}

	#get public prefs
	my @preflist = $S->_public_pref_list($user);
	my $item_list = '';

	foreach my $pref (@preflist) {
		warn "(user_info) processing $pref: user has $user->{prefs}->{$pref}" if $DEBUG;
		if ($user->{prefs}->{$pref}) {
			my $item = $S->{UI}->{BLOCKS}->{$S->{PREF_ITEMS}->{$pref}->{template}};
			my $fmt = $S->{PREF_ITEMS}->{$pref}->{display_fmt};
			if ( $fmt ) {
				$fmt =~ s/%%value%%/$user->{prefs}->{$pref}/g;
				$user->{prefs}->{$pref} = $fmt;
			}
			$item =~ s/%%title%%/$S->{PREF_ITEMS}->{$pref}->{title}/;
			$item =~ s/%%control%%/$user->{prefs}->{$pref}/;
			$item =~ s/%%description%%//;
			$item =~ s/%%allowed_html%%//;
			$item_list .= $item;
		}
	}
	$S->{UI}->{BLOCKS}->{subtitle} = "$nick: User Info";
	$return =~ s/%%trusted_msg%%/$trusted_msg/;
	$return =~ s/%%itemlist%%/$item_list/;
	$S->{UI}->{BLOCKS}->{CONTENT} = $return;
}

=item get_user_prefs

Builds the edit form for the user preference page specified. 

=cut

sub get_user_prefs {
	my $S = shift;
	my $page = $S->param->{action};
	my $uid = shift;
	my $nick = $S->param->{nick};
	my $write = $S->cgi->param('write');
	my $reset = $S->cgi->param('reset');
	my $message = '';
	my %params;
	my $firstlogin = $S->param->{firstlogin};
	my $nextpage = $S->cgi->param('nextpage');
	my $nextpage_form = '';

	# check for permission...
	unless ( $S->{UID} > -1 && ( $S->{UID} == $uid || $S->have_perm('edit_user') ) ) {
		return "%%error_font%%Permission Denied.%%error_font_end%%";
	}

	if ($reset) {
		$S->_reset_user_prefs($page, $uid);
		$message .= "$page preferences reset to defaults<BR>";
	}
	$message .= $S->_save_user_prefs($page, $uid, $nick) if ($write); 
	$nick = $S->cgi->param('nick'); # in case the nickname was changed
	warn "(get_user_prefs) first login? $firstlogin" if $DEBUG;
	if ($firstlogin) {
		$message .= $S->{UI}->{BLOCKS}->{firstlogin_message};
		$uid = $S->{UID};
		$nick = $S->{NICK};
		my @pages = split(/,\s*/, $S->var('first_login_page_order'));
		$page = $nextpage ? $nextpage : $pages[0];

		my $i = 0;
		while ( $pages[$i] ne $page ) {
			$i++;
		}
		$i++;
		$nextpage_form = qq{
			<INPUT type="hidden" name="firstlogin" value="1">
			<INPUT type="hidden" name="nextpage" value="$pages[$i]">} if $pages[$i];
	}

	$page = 'User Info' unless $page;

	my $formkey = $S->get_formkey_element();

	my $item_list = '';
	my $return = $S->{UI}->{BLOCKS}->{user_pref_page};
	$return =~ s/%%formkey%%/$formkey $nextpage_form/;
	$return =~ s/%%nick%%/$nick/g;
	$return =~ s/%%page%%/$page/g;

	#get user info and user prefs
	my $user = $S->user_data($uid);
	%{$user->{prefs}} = (%{$user->{prefs}},%params) if $reset;

	if ( $page eq 'Protected' ) {
		# Yes, this is a special case - password and real email are 
		# the only "preferences" stored in the user table now.
		my ($adminpreftemplate, $preftemplate);
		my $preflist = {'realemail' => $user->{realemail} };
		my $adminpreflist = {'origemail' => $user->{origemail}, 
				'nickname' => $user->{nickname},
				'uid' => $user->{uid},
				'perm_group' => $user->{perm_group}, 
				'mojo' => $user->{mojo}, 
				'creation_ip' => qq|<a href="%%rootdir%%/iplookup/$user->{creation_ip}">$user->{creation_ip}</a>|,
				'creation_time' => $user->{creation_time} };

		if ( $S->have_perm('edit_user') ) {
			$adminpreftemplate = $S->{UI}->{BLOCKS}->{user_admin};
			$adminpreftemplate =~ s/%%perm_group%%/$user->{perm_group}/;
			$adminpreftemplate = $S->interpolate($adminpreftemplate,$adminpreflist);
		}

		$preftemplate = $S->{UI}->{BLOCKS}->{user_pass};
		if ( $firstlogin ) {
			my $pass = $S->cgi->param('pass');
			$preflist->{passwd} = $S->{UI}->{BLOCKS}->{userpref_oldpass_hidden};
			$preflist->{passwd} =~ s/%%pass%%/$pass/;
		} else {
			$preflist->{passwd} = $S->{UI}->{BLOCKS}->{userpref_oldpass_field};
		}
		$preftemplate = $S->interpolate($preftemplate,$preflist);
		$return =~ s/%%itemlist%%/$adminpreftemplate\n$preftemplate/;
		$return =~ s/%%userpref_reset%%//g;
	} else {
		# Now for all the dynamically generated pages
		my @preflist = $S->_pref_list($page, $user);
		$S->{UI}->{BLOCKS}->{subtitle} = "$page";

		foreach my $pref (@preflist) {
			my $current = $S->{PREF_ITEMS}->{$pref};
			warn "(get_user_prefs) processing $pref (currently $user->{prefs}->{$pref})" if $DEBUG;
			my $prefvalue = (defined($user->{prefs}->{$pref})) ? $user->{prefs}->{$pref} : $current->{default_value};
			$prefvalue = $S->_filter_display($prefvalue);
			my $required = $current->{signup} eq 'required' ? $S->{UI}->{BLOCKS}->{required_pref_marker} : '';
			my $preftemplate = $S->{UI}->{BLOCKS}->{$current->{template}};
			my $allowed_html = $S->html_checker->allowed_html_as_string('pref') if $current->{html};
			my $keys = {'control' => $current->{field},
				'title' => $current->{title},
				'description' => $current->{description},
				'allowed_html' => $allowed_html,
				'required' => $required };

			$preftemplate = $S->interpolate($preftemplate,$keys);
			$preftemplate =~ s/%%value%%/$prefvalue/g;
	
			$item_list .= $preftemplate;
		}

		$return =~ s/%%itemlist%%/$item_list/;
	}

	$return =~ s/%%message%%/$message/;
	$S->{UI}->{BLOCKS}->{CONTENT} = $return;
}

=item _save_user_prefs

Saves the user prefs for the page specified. Does not attempt to save all cgi
parameters, only those which should appear on the preference page specified.

Any preference that should be on the page but is not defined is assumed to be
an unchecked checkbox and is treated accordingly.

=cut

sub _save_user_prefs {
	my $S = shift;
	my $page = shift;
	my $uid = shift;
	my $nick = shift;

	my %params = %{ $S->{CGI}->Vars_cloned() };
	my $user = $S->user_data($uid);

	my $return = '';
	my %save;

	unless ( $S->check_formkey() ) {
		return $S->{UI}->{BLOCKS}->{formkey_err};
	}

	if ( $page eq 'Protected' ) {
		# Yes, this is a special case - password and real email are 
		# the only "preferences" stored in the user table now.
		my $pass = $params{verify_me};
		if ( $S->have_perm('edit_user') || $S->check_password($nick,$pass) ) {
			# changing the password?
			if ( $params{pass1} ) {
				if  ( $params{pass1} eq $params{pass2} ) {
					$save{passwd} = $S->crypt_pass($params{pass1});
				} else {
					$return .= "New passwords do not match";
				}
			}
			# changing the nickname?
			if ( $S->have_perm('edit_user') && $params{nickname} ne $user->{nickname} ) {
				if ( !$S->get_uid_from_nick($params{nickname}) ) {
					$save{nickname} = $params{nickname};
				} else {
					$return .= "$params{nickname} is already in use";
				}
			}
			# changing the group?
			if ( $S->have_perm('edit_groups') ) {
				if ( $params{perm_group_id} ne $user->{perm_group} ) {
					$save{perm_group} = $params{perm_group_id};
				}
			}
			# and real email
			my $mail_err = $S->check_email($params{realemail});
			if ( !$mail_err ) {
				if ( $params{realemail} ne $user->{realemail} ) {
					$save{realemail} = $params{realemail};
				}
			} else {
				$return .= "%%error_font%%$mail_err%%error_font_end%%";
			}

			# now we save anything that's changed
			my $set = '';
			foreach my $item (keys %save) {
				$save{$item} = $S->dbh->quote($save{$item});
				$set .= qq{$item = $save{$item}, };
			}
			$set =~ s/, $//;
			my ($rv, $sth) = $S->db_update({
				WHAT => 'users',
				SET => $set,
				WHERE => "uid = $uid"
			}) if $set;

			# and tell the user what was saved
			$return .= $S->{DBH}->errstr unless ($rv);
			$return .= "<P>Updated fields: ";
			foreach my $key (keys %save) {
				$return .= "$key, ";
				$S->run_hook('pref_change', $uid, $key, $save{$key});
			}
			$return =~ s/, $//;

			if ( $save{nickname} ) {
				# nickname has changed in db - better change it 
				# wherever else it's needed...
				if ( $uid == $S->{UID} ) {
					$S->{NICK} = $params{nickname};
					# this is the current user...
				}
				$S->param->{nick} = $params{nickname};
				# and if not, everything else that checks the
				# cgi params should see the change too

				# and update the rdf_channels table if the
				# nickname was changed, because it uses nick,
				# not uid 
				# this will have to get fixed someday
				my ($rv2, $sth2) = $S->db_update({
					WHAT  => 'rdf_channels',
					SET   => "submittor = $save{nickname}",
					WHERE => "submittor = '$nick'"
				});
				$sth2->finish;
			}
			delete($S->{USER_DATA_CACHE}->{$uid});
		} else {
			$return .= "Password incorrect";
		}
	} else {
		# all the dynamically generated pages
		my @preflist = $S->_pref_list($page,$user);
		foreach my $pref (@preflist) {
			$return .= $S->_save_pref($user,$pref,$params{$pref});
		} 

	}

	return $return;
}

=item _save_pref

Filters and saves a single pref. Takes three arguments, the user hash, the pref
name and the value to set.

=cut

sub _save_pref {
	my $S = shift;
	my $user = shift;
	my $pref = shift;
	my $value = shift;

	my $pref_item = $S->{PREF_ITEMS}->{$pref};
	my $uid = $user->{uid};

	# if it's an array of checkboxes with the same name, it shows up as an
	# arrayref. Must convert to comma-separated list for storage.
	$value = join(',', @{$value}) if ref($value) =~ /ARRAY/;

	warn "(_save_user_prefs) filtering item $pref with old value $user->{prefs}->{$pref}; new value $value" if $DEBUG;

	# check if it's required
	warn "$pref is required? $pref_item->{required}" if $DEBUG;
	if ( $pref_item->{signup} eq 'required' && !$value ) {
		warn "$pref is required and blank - error" if $DEBUG;
		return "<P>%%error_font%%$pref_item->{title} is a required field%%error_font_end%%</P>";
	}

	# make NULL values (eg, unchecked checkboxes) into 'off'
	$value = 'off' unless defined($value);

	# skip unchanged params
	return if $user->{prefs}->{$pref} eq $value;
	return if ( !defined($user->{prefs}->{$pref}) && ($value eq $S->{PREF_ITEMS}->{$pref}->{default_value}) );
	# check length then regexp
	if ( $pref_item->{length} ) {
		if ( length($value) > $pref_item->{length} ) {
			return "<P>%%error_font%%$pref_item->{title} must be less than $pref_item->{length} characters%%error_font_end%%</P>";
		}
	}
	if ( $pref_item->{regex} && $value ) {
		warn "testing $value against regex $pref_item->{regex}" if $DEBUG;

                if ($pref_item->{regex} =~ /^BOX,(.*)$/) {
                        my @args = split /,/, $1;
                        my $box = shift @args;
                        if (my $err = $S->box_magic($box,$pref_item,$value,@args)) {
                                # If we get a return value at all, it's an error
                                return $err;
                        }
                } else {
                        unless ( $value =~ /$pref_item->{regex}/ ) {
                                return "<P>%%error_font%%$pref_item->{title} ($value) does not validate%%error_font_end%%</P>";
                        }
                }
	}

	# filter for html/plaintext
	if ( $pref_item->{html} ) {
		$value = $S->filter_comment($value, 'prefs');
		my $errors = $S->html_checker->errors_as_string;
		return "<P>%%error_font%%$pref_item->{title}: $errors%%error_font_end%%</P>" if $errors;
	} else {
		$value = $S->filter_subject($value);
	}

	# quote for db and save it
	my $q_value = $S->dbh->quote($value);
	my $q_key = $S->dbh->quote($pref);
	warn "(_save_user_prefs) saving item $pref" if $DEBUG;

	my ($rv, $sth);
	if ( defined $user->{prefs}->{$pref} ) {
		($rv, $sth) = $S->db_update({
			DEBUG => $DEBUG,
			WHAT  => 'userprefs',
			SET   => "prefvalue = $q_value",
			WHERE => "uid = $uid AND prefname = $q_key"
		});
		$sth->finish;
	} else {
		($rv, $sth) = $S->db_insert({
			DEBUG => $DEBUG,
			INTO  => 'userprefs',
			COLS  => 'uid, prefname, prefvalue',
			VALUES => "$uid, $q_key, $q_value"
		});
		$sth->finish;
	}
	if ($rv) {
		$S->run_hook('pref_change', $uid, $pref, $value);
		$sth->finish;
		# now force prefs to refresh from the db
		delete $S->{USER_DATA_CACHE}->{$uid};
		if ( $uid == $S->{UID} ) {
			delete $S->{prefs};
		}
		return "Saved $pref_item->{title}<BR>";
	} else {
		warn "(_save_user_prefs) database error: $S->dbh->errstr()" if $DEBUG;
		$value = 'ERROR';
		$sth->finish;
		return "Error saving $pref_item->{title}: " . $S->dbh->errstr() . "<BR>";
	}
}

=item _reset_user_prefs

Resets all the user prefs which should appear on the given page to the defaults
specified in the prefs admin tool by deleting them from the database and the
user data cache

=cut

sub _reset_user_prefs {
	my $S = shift;
	my $page = shift;
	my $uid = shift;
	my $user = $S->user_data($uid);
	my $q_uid = $S->dbh->quote($uid);

	my @preflist = $S->_pref_list($page,$user);
	my @sqlpreflist;

	foreach my $pref (@preflist) {
		delete $S->{USER_DATA_CACHE}->{$uid}->{prefs}->{$pref};
		push @sqlpreflist, $S->dbh->quote($pref);
		if ($uid == $S->{UID}) {
			delete $S->{prefs}->{$pref};
		}
	}

	my ($rv,$sth) = $S->db_delete({
		DEBUG => $DEBUG,
		FROM => 'userprefs',
		WHERE => qq|uid=$q_uid AND prefname IN (| . join(',', @sqlpreflist) . ')'
	});

	return;
}

####
# returns an array of preference names which are marked as "public"
# ordered by the display order field
####

sub _public_pref_list {
	my $S = shift;
	my $user = shift;
	my @preflist;

	my ($rv, $sth) = $S->db_select({
				WHAT => 'prefname',
				FROM => 'pref_items',
				WHERE => 'visible = 1 AND enabled = 1',
				ORDER_BY => 'display_order'
	});

	while ( my ($pref) = $sth->fetchrow_array() ) {
		next if $S->{PREF_ITEMS}->{$pref}->{perm_view} && !$S->have_perm($S->{PREF_ITEMS}->{$pref}->{perm_view});
		next if $S->{PREF_ITEMS}->{$pref}->{var} && !$S->{UI}->{VARS}->{$S->{PREF_ITEMS}->{$pref}->{var}};
		next if $S->{PREF_ITEMS}->{$pref}->{req_tu} && !( $user->{trustlev} == 2 || $S->have_perm('super_mojo',$user->{perm_group}) );
		push @preflist, $pref;
	}
	$sth->finish;
	return @preflist;
}

####
# returns an array of preference names which are marked as shown on the newuser
# page ordered by the page they're on, then the display order field Not sure
# why one would use this for anything other than the new user page but hey, it
# could happen. All perm/etc checks still done.
####

sub _required_pref_list {
	my $S = shift;
	my $user = shift;
	my @preflist;

	my ($rv, $sth) = $S->db_select({
				DEBUG => $DEBUG,
				WHAT => 'prefname',
				FROM => 'pref_items',
				WHERE => q{signup IN ('required', 'signup') AND enabled = 1},
				ORDER_BY => 'display_order'
	});

	while ( my ($pref) = $sth->fetchrow_array() ) {
		next if $S->{PREF_ITEMS}->{$pref}->{perm_view} && !$S->have_perm($S->{PREF_ITEMS}->{$pref}->{perm_view});
		next if $S->{PREF_ITEMS}->{$pref}->{var} && !$S->{UI}->{VARS}->{$S->{PREF_ITEMS}->{$pref}->{var}};
		next if $S->{PREF_ITEMS}->{$pref}->{req_tu} && !( $user->{trustlev} == 2 || $S->have_perm('super_mojo',$user->{perm_group}) );
		push @preflist, $pref;
		warn "(_required_pref_list) adding $pref to list" if $DEBUG;
	}
	$sth->finish;
	return @preflist;
}

####
# returns an array of preference names for the page it is given
# ordered by the display order field
####

sub _pref_list {
	my $S = shift;
	my $page = shift;
	my $user = shift;
	my @preflist;

	$page = $S->dbh->quote($page);

	my ($rv, $sth) = $S->db_select({
				WHAT => 'prefname',
				FROM => 'pref_items',
				WHERE => "page = $page AND enabled = 1",
				ORDER_BY => 'display_order'
	});

	while (my ($pref) = $sth->fetchrow_array() ) {
		next if $S->{PREF_ITEMS}->{$pref}->{perm_edit} && !$S->have_perm($S->{PREF_ITEMS}->{$pref}->{perm_edit});
		next if $S->{PREF_ITEMS}->{$pref}->{var} && !$S->{UI}->{VARS}->{$S->{PREF_ITEMS}->{$pref}->{var}};
		next if $S->{PREF_ITEMS}->{$pref}->{req_tu} && !( $user->{trustlev} == 2 || $S->have_perm('super_mojo',$user->{perm_group}) );
		push @preflist, $pref;
	}
	$sth->finish;
	return @preflist;
}

	

####
# filters html and entities for display on prefs page
####

sub _filter_display {
	my $S = shift;
	my $string = shift;

	$string =~ s/&/&amp;/g;
	$string =~ s/</&lt;/g;
	$string =~ s/>/&gt;/g;

	return $string;
}


1;
