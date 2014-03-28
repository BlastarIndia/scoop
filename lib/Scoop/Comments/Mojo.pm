package Scoop;
use strict;
my $DEBUG = 0;

sub update_mojo {
	my $S = shift;
	my $update_users = shift;
	
	my($mojo, $count);
	foreach my $uid (keys %{$update_users}) {
		warn "Calculating mojo for user $uid\n" if $DEBUG;
		next unless ($uid > 0);
		($mojo, $count) = $S->calculate_mojo($uid);
		$S->write_mojo($uid, $mojo, $count);
	}
	
	return;
}

sub calculate_mojo {
	my $S   = shift;
	my $uid = shift;

	my $max_days     = $S->{UI}->{VARS}->{mojo_max_days};
	my $max_comments = $S->{UI}->{VARS}->{mojo_max_comments};
	
	my $fetch = {
		WHAT => 'comments.points, comments.lastmod, comments.cid, comments.sid',
		FROM => 'comments, stories',
		WHERE => qq|comments.uid = $uid AND ((TO_DAYS(NOW()) - TO_DAYS(comments.date)) <= $max_days) AND comments.points IS NOT NULL AND comments.sid = stories.sid AND stories.displaystatus != -1|,
		ORDER_BY => 'comments.date desc',
		LIMIT => qq|$max_comments|,
		DEBUG => 0
	};
	
	if ($S->{UI}->{VARS}->{mojo_ignore_diaries}) {
		$fetch->{WHERE} .= qq| AND stories.section != 'Diary'|;
	}	
	
	my ($rv, $sth) = $S->db_select( $fetch );
	my ($sum, $count);
	my $weight = $max_comments;
	my $real_count = 0;
	while (my ($rating, $number, $cid, $sid) = $sth->fetchrow()) {
		$real_count++;
		# For auto set rating, number is -1, so set it here.
		$number = 1 if ($number <= 0);
		$count += ($weight * $number);
		$sum += (($rating * $weight) * $number);
		$weight--;
		warn "\tFrom cid $cid, Story $sid, rating is $rating: \n\tCount: $count, weight: $weight, Sum: $sum\n" if $DEBUG;
	}
	$sth->finish();
	
	my $new_mojo = ($sum / $count) unless ($count == 0);
	
	warn "New mojo for user $uid is $new_mojo\n" if $DEBUG;
	return($new_mojo, $real_count);
}

sub write_mojo {
	my $S = shift;
	my ($uid, $mojo, $count) = @_;
	my $set = $S->dbh->quote($mojo);
	unless ($mojo) {
		warn "Mojo is blank. Saving NULL\n" if $DEBUG;
		undef $mojo;
		$set = "NULL";
	}
	
	warn "Saving mojo $mojo for user $uid\n" if $DEBUG;
	my ($rv, $sth) = $S->db_update({
		WHAT => 'users',
		SET  => qq|mojo = $set|,
		WHERE=> qq|uid = $uid|});
	
	$sth->finish();
	
	# Check for trust lev, and set that
	$S->_set_trust_lev($uid, $mojo, $count);
	
	return;
}


sub _set_trust_lev {
	my $S = shift;
	my ($uid, $mojo, $count) = @_;
	
	my $trustlev = 1;
	my $hide_thresh = $S->{UI}->{VARS}->{hide_comment_threshold} || $S->{UI}->{VARS}->{rating_min};
	if (($mojo >= $S->{UI}->{VARS}->{mojo_rating_trusted}) &&
		($count >= $S->{UI}->{VARS}->{mojo_min_trusted})) {
		warn "User $uid is trusted!\n" if $DEBUG;
		$trustlev = 2;
	} elsif (($mojo <= $hide_thresh) &&
			 ($count >= $S->{UI}->{VARS}->{mojo_min_untrusted})) {
		warn "User $uid is untrusted!\n" if $DEBUG;
		$trustlev = 0;
	}

	my ($rv, $sth) = $S->db_update({
		WHAT => 'users',
		SET => qq|trustlev = $trustlev|,
		WHERE => qq|uid = $uid|,
		DEBUG => 0});
		
	$sth->finish();
	return;

}


1;
