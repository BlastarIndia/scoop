package Scoop;
use strict;

my $DEBUG = 0;

=pod

=head1 Users/NewUser.pm

This file contains the user creation function and associated utilities.

=head1 FUNCTIONS

=over 4

=item new_user

Creates new accounts and new advertiser accounts. (Advertiser accounts have
never been used so they may not work.)

=cut

sub new_user {
	my $S = shift;

	$S->{UI}->{BLOCKS}->{subtitle} = 'New User';

	my $tool = $S->{CGI}->param('tool');
	my $email = $S->{CGI}->param('email');
	
	my $is_advertiser = 0;
	my $no_create = 0;
	
	# this controls whether or not they will see the extra advertising
	# account information fields.
	$is_advertiser = 1 if ($tool eq 'advertiser' || $S->{CGI}->param('advertiser') == 1 );
	
	$is_advertiser = 0 unless( $S->{UI}->{VARS}->{use_ads} && $S->{UI}->{VARS}->{req_extra_advertiser_info} );
	
	my $new_user_page = '';
	my $signup_prefs = '';
	
	my $really_new_user = ( $S->{GID} eq 'Anonymous' ? 1 : 0 );
	$really_new_user = 1 if ($S->have_perm('make_new_accounts'));
	#accounts with this perm set will never see the new advertiser page
	
	# if this is a person visiting this page not logged in, or a non-advertiser trying to 
	# set up an ad account, they get the page to create an account.  Otherwise give them 
	# an error message tailored to their situation, whether they are a normal user trying 
	# to create another account or an advertiser trying to create another advertising account
	if( $really_new_user ) {
		$new_user_page .= $S->{UI}->{BLOCKS}->{new_user_html};

		# get prefs shown on newuser form
		my $user = $S->user_data($S->{UID});
		my @prefs = $S->_required_pref_list($user);
		foreach my $pref (@prefs) {
			my $current = $S->{PREF_ITEMS}->{$pref};
			warn "(new_user) processing $pref (currently $user->{prefs}->{$pref})" if $DEBUG;
			my $prefvalue = $S->cgi->param($pref) || $current->{default_value};
			$prefvalue = $S->_filter_display($prefvalue);
			my $preftemplate = $S->{UI}->{BLOCKS}->{$current->{template}};
			my $allowed_html = $S->html_checker->allowed_html_as_string('pref') if $current->{html};
			my $keys = {	'control' => $current->{field},
					'title' => $current->{title},
					'description' => $current->{description},
					'required' => ($current->{signup} eq 'required') ? $S->{UI}->{BLOCKS}->{required_pref_marker} : '',
					'allowed_html' => $allowed_html };
			
			$preftemplate = $S->interpolate($preftemplate,$keys);
			$preftemplate =~ s/%%value%%/$prefvalue/;
			$signup_prefs .= $preftemplate;
		}
	} elsif( !$is_advertiser ) {
	
		$new_user_page .= $S->{UI}->{BLOCKS}->{new_user_has_account};
		$no_create = 1;
	
	} elsif( $is_advertiser && $S->{GID} eq $S->{UI}->{VARS}->{advertiser_group} ) {
	
		$new_user_page .= $S->{UI}->{BLOCKS}->{new_advertiser_has_account};
		$no_create = 1;
	
	} elsif( $is_advertiser ) {
		$new_user_page .= $S->{UI}->{BLOCK}->{new_advertiser_html};
	}
	
	my $formkey = $S->make_blowfish_formkey();
	
	
	my ($uname, $pass1, $error);
	
	# if they click the "Create User" button, create the account
	if ($tool eq 'writeuser') {
		$uname = $S->{CGI}->param('nickname');
		my $pass2;

		if( $really_new_user ) {
			if ($error .= $S->filter_new_username($uname)) {
				$uname = '';
			}
	
			if ($error .= $S->check_for_user($uname)) {
				$uname = '';
			}
	
			if ($error .= $S->check_email($email)) {
				$email = '';
			}

			if ($S->{UI}->{VARS}->{signup_with_password}) {
			    my $p_error .= $S->check_newuser_pass();
			    $pass2 = $S->cgi->param('pass1') unless ($p_error);
			    $error .= $p_error;
			}
				
		}
	
		if ($is_advertiser) {
			$error .= $S->check_address_fields();
		}
	
		$error .= '<BR> Invalid IP number, or old formkey. Please try again.' unless ($S->check_blowfish_formkey($S->cgi->param('formkey')));
	
		$error .= $S->check_creation_rate();
		
		$pass1 = $S->_random_pass();
		
		unless ($error) {
			my $rv;
			if ($really_new_user) {
				$rv = $S->create_user_step_1($uname, $pass1, $email, $pass2);
			} elsif ($is_advertiser) {
				$rv = $S->store_advertiser_info($S->{UID});
			}

			if ($rv == 1) {
				# Run the new user hook
				$S->run_hook('user_new', $uname, $is_advertiser);

				my $return_page = $S->{UI}->{BLOCKS}->{newuser_confirm_page};

				my $user_email = $email || $S->get_email_from_uid($S->{UID});
				$return_page =~ s/%%EMAIL%%/$user_email/g;
				$return_page =~ s/%%SITENAME%%/$S->{UI}->{VARS}->{sitename}/g;

				$S->{UI}->{BLOCKS}->{CONTENT} .= $return_page;
				return;
			} else {
				$error .= $rv;
			}
		}
	}

	$new_user_page =~ s/%%error%%/$error/g;
	$new_user_page =~ s/%%uname%%/$uname/g;
	$new_user_page =~ s/%%email%%/$email/g;
	$new_user_page =~ s/%%formkey%%/$formkey/g;
	$new_user_page =~ s/%%signup_prefs%%/$signup_prefs/g;


	$S->{UI}->{BLOCKS}->{CONTENT} = $new_user_page;

	return;
}

=item check_creation_rate

A utility to check the number of new accounts created by a particular IP
address in a day.

=cut

sub check_creation_rate {
        my $S = shift;
        
	my $dsub = $S->db_date_sub("NOW()", "24 HOUR");
	my $ip = $S->dbh->quote($S->{REMOTE_IP});
        my ($rv, $sth) = $S->db_select({
                WHAT => 'uid',
                FROM => 'users',
                WHERE => qq|creation_ip = $ip AND creation_time >= $dsub|
        });

        my $count = $sth->fetchall_arrayref();
        $sth->finish();
        
        if (scalar(@$count) >= $S->{UI}->{VARS}->{max_accounts_per_day} ) {
                return '<BR> Sorry, but account creation is restricted to '. $S->{UI}->{VARS}->{max_accounts_per_day} .' new accounts per IP per day. If you are behind a proxy or firewall that serves a large number of clients, others may have already created accounts today. Just wait till tomorrow, and try again.';
        }
        
        return '';
}

=item filter_new_username

A utility to make sure usernames are legal. Three of the four tests are for
things that will make people seem to have an identical username as another
user: leading and trailing spaces, multiple spaces in a row, and &nbsp;
characters, all of which collapse into a single space when rendered by a
browser.

=cut

sub filter_new_username {
        my $S = shift;
        my $name = shift;

        if ($name =~ /^\s/ || $name =~ /\s$/) {
                return "Username cannot begin or end with a space.";
        }
        if ($name =~ /\s\s/) {
                return "Username cannot contain multiple spaces in a row.";
        }

        if ($name =~ /[^a-zA-Z0-9\s]/) {
                return "Username contains an illegal character.";
        }

        if ($name =~ /&nbsp;/) {
                return "Username cannot contain &amp;nbsp; entity.";
        }

        return '';
}

=item create_user_step_1

Does the DB insert and sends the new user email; if email fails in a way that
the program can detect, it removes the newly created account information by
calling rollback_account.

=cut

sub create_user_step_1 {
	my $S = shift;
	my ($nick, $pass, $email, $real_pass) = @_;

	my $pass_to_crypt = ($S->{UI}->{VARS}->{signup_with_password}) ? $real_pass : $pass;

	my $c_pass = $S->dbh->quote($S->crypt_pass($pass_to_crypt));
	my $f_nick = $S->dbh->quote($nick);
	my $f_email = $S->dbh->quote($email);

    my $default_group = $S->dbh->quote($S->_get_default_group);
	my $ip = $S->dbh->quote($S->{REMOTE_IP});

 
	my $insert = {
                INTO => 'users',
                COLS => 'nickname, origemail, realemail, passwd, perm_group, creation_ip, creation_time, is_new_account',
                VALUES => qq|$f_nick, $f_email, $f_email, $c_pass, $default_group, $ip, NOW(),1|
	};

	if ($S->{UI}->{VARS}->{signup_with_password}) {
		my $q_pass = $S->dbh->quote($real_pass);
		my $i_pass = $S->dbh->quote($pass);
		$insert->{COLS} = 'nickname, origemail, realemail, passwd, newpasswd, creation_passwd, perm_group, creation_ip, creation_time, is_new_account';
		$insert->{VALUES} = qq|$f_nick, $f_email, $f_email, $i_pass, $c_pass, $q_pass, $default_group, $ip, NOW(),1|;
	}

        my ($rv, $sth) = $S->db_insert($insert);
        $sth->finish;

        return "Error creating new user! Database said: ".$DBI::errstr if !$rv;

        my $uid = $S->dbh->{'mysql_insertid'};

	# insert initial required prefs
	my $user = $S->user_data($uid);
	my @prefs = $S->_required_pref_list($user);
	foreach my $pref (@prefs) {
		my $value = $S->cgi->param($pref);
		$rv = $S->_save_pref($user,$pref,$value);
		warn "(create_user_step_1) rv is $rv" if $DEBUG;
		if ( $rv =~ /error/i ) {
			$S->rollback_account($uid);
			return $rv;
		}
	}
	

        my $path = $S->{UI}->{VARS}->{site_url} . $S->{UI}->{VARS}->{rootdir};
        my $subject = $S->{UI}->{BLOCKS}->{new_user_email_subject};
        my $from = $S->{UI}->{VARS}->{new_user_email_from} || $S->{UI}->{VARS}->{local_email};
        my $sitename = $S->{UI}->{VARS}->{sitename};

        my $showprefs;
        if($S->{UI}->{VARS}->{show_prefs_on_first_login}) {
                $showprefs = $S->{UI}->{BLOCKS}->{new_user_email_showprefs};
        }

        my $content = $S->{UI}->{BLOCKS}->{new_user_email};

        $content =~ s/%%nick%%/$nick/g;
        $content =~ s/%%pass%%/$pass/g;
        $content =~ s/%%url%%/$path/g;
        $content =~ s/%%showprefs%%/$showprefs/g;
        $content =~ s/%%from%%/$from/g;
        $content =~ s/%%sitename%%/$sitename/g;

        $subject =~ s/%%sitename%%/$sitename/g;

        $rv = $S->mail($email, $subject, $content, $from);
        warn 'Return from $S->mail is '.$rv."\n" if $DEBUG;

        unless ($rv == 1) {
                $S->rollback_account($uid);
        }

        return $rv;
}

=item rollback_account

Deletes the user account given to it as a parameter.

=cut

sub rollback_account {
        my $S = shift;
        my $uid = shift;

        my ($rv) = $S->db_delete({
                DEBUG => $DEBUG,
                FROM => 'users',
                WHERE => qq|uid = $uid|});

	($rv) = $S->db_delete({
		DEBUG => $DEBUG,
		FROM => 'userprefs',
		WHERE => qq|uid = $uid|});

        return;
}

=item check_for_user

=item check_email

Checks to see if the username and email address are already in use by another
user.

=cut

sub check_for_user {
        my $S = shift;
        my $nick = shift;
	my $q_nick = $S->dbh->quote($nick);

        return '<br />Username is already in use.<br />Please try a different one.'
                if $nick eq $S->{UI}->{VARS}->{anon_user_nick};

        unless ($nick) {
                return '<br />You must choose a user name';
        }

        my ($rv, $sth) = $S->db_select({
                WHAT => 'uid',
                FROM => 'users',
                WHERE => qq|nickname = $q_nick|});
        $sth->finish;

        if ($rv eq '0E0' or $rv == 0) {
                return '';
        } else {
                return '<br />Username is already in use.<br />Please try a different one.';
        }
}

sub check_email {
        my $S = shift;
        my $email = shift;
	my $q_email = $S->dbh->quote($email);

        unless ($email) {
                return '<BR>You must enter an email address, which must be working to activate your account.<BR><BR>';
        }
	# Check to make sure it's actually an email address that they put in
	# the email field.
	if($email !~ /$Mail::Sendmail::address_rx/){
            return "<BR>Sorry, $email is not a valid email address. Please enter a valid email address.<BR><BR>";
            }

        my ($rv, $sth) = $S->db_select({
                WHAT => 'uid',
                FROM => 'users',
                WHERE => qq|realemail = $q_email OR origemail = $q_email|});
        #$sth->finish;

        # Return an error if it fails since they can't use that address
        if ($rv eq '0E0'        ||
                $rv == 0                || # if it fails the address is already in use, so return
                $sth->fetchrow_hashref->{uid} == $S->{UID} ||   # unless its theirs
                $S->have_perm('edit_user') ) {                                  # or they are an admin

                $sth->finish;
        } else {
                $sth->finish;
                return '<BR>' . $email . ' belongs to a registered user already.<BR>All accounts must have a unique email address.<BR><BR>';
        }

        # Check that the domain is legal. 
        # Add domains to block in Var 'blocked_domains', separated by commas.

        my %blocked_dom = ();
        foreach(split /\s*,[\n\r\s]*/, $S->{UI}->{VARS}->{blocked_domains}) {
                #warn "Blocked $_\n";
                $blocked_dom{$_} = 1;
        }

        $email =~ /\@(.*)\s*$/;
        my $dom = $1;

        return '<BR>' . $email . " is from a blocked domain." if ($blocked_dom{$dom});
}


sub check_newuser_pass {
	my $S = shift;
	my $pass1 = $S->cgi->param('pass1');
	my $pass2 = $S->cgi->param('pass2');

	# Is there anything in them?
	return "<br> Please enter a password." unless $pass1;
	# Do they match?
	return qq|<br> The two password fields do not match. Please enter your password again.|
		unless ($pass1 eq $pass2);

	# Ok.
	return '';
}
	
1;
