package Scoop;
use strict;

my $DEBUG = 0;

=pod

=head1 Users.pm

This file contains the base function for the user op. More user-related
functions can be found in the Users/ directory.

=over 4

=item edit_user

This is essentially a switch to pass control to the function needed for
displaying the user information, user prefs, or playing with their
ratings.


=cut

sub edit_user {
	my $S = shift;
	my $tool = $S->cgi->param('tool');
	my $uid = $S->cgi->param('uid');
	my $nick = $S->cgi->param('nick');

	$uid = $S->{UID} unless ($nick || $uid);
	$uid = $S->get_uid_from_nick($nick) unless $uid;
	$nick = $S->get_nick_from_uid($uid) unless $nick;

	warn "(edit_user) getting prefs for $nick (uid:$uid)" if $DEBUG;

	# user op EVAL gets uid and nick for us
	unless ( $nick && $uid ) { # if one or the other is missing, the user doesn't exist
		$S->{UI}->{VARS}->{subtitle} = 'Error';
		$S->apache->status(404);
		$S->{UI}->{BLOCKS}->{CONTENT} .= $S->{UI}->{BLOCKS}->{invalid_user_msg};
		return;
	}

	# now figure out what to do
	if ( $tool eq 'prefs' ) {
		$S->get_user_prefs($uid);
	} elsif ( $tool eq 'ratings' ) {
		if ( $S->cgi->param('action') eq 'undo' ) {
			$S->undo_user_ratings($uid);
		}
		$S->_get_user_ratings($uid);
	} elsif ( $tool eq 'files' ) {
		$S->_get_user_files($uid);
	} else {
		$S->user_info($uid);
	}

}

# maybe move these subs to this file?

#sub _get_user_files
#sub _build_file_list
#sub _get_recent_comments
#sub add_to_subscription
#sub pref

1;
