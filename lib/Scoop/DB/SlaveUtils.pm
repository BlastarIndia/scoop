package Scoop;
use strict;
my $DEBUG = 1;

=head1 Scoop::DB::SlaveUtils.pm

Some db functions that are specific to a master/slave DB setup.

=over 4

=item *
get_dbh

Not specifically restricted to a master/slave db. However, if Scoop is not running on a master/slave setup, it just returns the standard $S->{DBH}. If it is, it will check to make sure the master is still up and running. If it is, it will return the master db handle. Otherwise, it write a message to the log and return nothing (raising a slave to master is important enough that it should not be entrusted to a machine). Also, if you pass a true value to the function, it will pick between the master and the pool of slaves and return one of their db handles. This is really only useful when coming from db_select, since the slaves cannot do inserts or updates.

=cut

sub get_dbh {
	my $S = shift;
	my $select = shift;
	my $dbh;

	# The *absolute* first thing to do is see if we're even using slaves.
	if(!$S->{HAVE_SLAVE}){
		$dbh = $S->{DBH};
		# and break out now - no need to go further
		return $dbh;
		}
	# next see if we're doing a select. If not, check and make sure the
	# main db's alive and we don't need to raise a slave
	elsif(!$select){
		$dbh = $S->{DBH};
		eval { $dbh->ping };
		if($@){ # oh hell, it's gone.
			# Jimmy crack corn, and I don't care...
			warn "The master's gone away! $@\n";
			# If the master's dead, return nothing. Raising a slave
			# is important enough to do by hand.
			return '';
			}
		warn "Using master db\n" if $DEBUG;
		}
	else { # we are doing a select
		# pick a dbh, any dbh
		my $j = int(rand($S->{NUMSLAVES} + 1));
		if($j){
			my $s = int(rand($S->{NUMSLAVES}));
			$dbh = $S->{SLAVEDB}->[$s];
			warn "Using slave db $s\n" if $DEBUG;
			eval { $dbh->ping };
			# hopefully this works
			if($@){
				warn "Slave went away hard, trying to use master: $@\n";
				$dbh = $S->get_dbh();
				}
			}
		else {
			$dbh = $S->get_dbh();
			}	
		}
	return $dbh;
	}

=pod

=item *
get_archive_dbh {

Very similar to get_dbh, but for the archive db, in case you have a slave set up for the archive database. The archive and main db slaves are set up seperately, so it isn't necessary to have replication set up for both.

=cut

sub get_archive_dbh {
	my $S = shift;
	my $select = shift;
	my $dbh;

	# not too surprisingly, this borrows heavily from get_dbh
	# The *absolute* first thing to do is see if we're even using slaves.
	if(!$S->{HAVE_SLAVE_ARCHIVE}){
		$dbh = $S->{DBHARCHIVE};
		# and break out now - no need to go further
		return $dbh;
		}
	# next see if we're doing a select. If not, check and make sure the
	# main db's alive and we don't need to raise a slave
	elsif(!$select){
		$dbh = $S->{DBHARCHIVE};
		eval { $dbh->ping };
                if($@){ # oh hell, it's gone.
                        # Jimmy crack corn, and I don't care...
                        warn "The master (archive)'s gone away! $@\n";
                        # If the master's dead, return nothing. Raising a slave
                        # is important enough to do by hand.
                        return '';
                        }
                warn "Using archive master db\n" if $DEBUG;
                }
	else { # we are doing a select
		# pick a dbh, any dbh
		my $j = int(rand($S->{NUMARCHSLAVES} + 1));
		if($j){
			my $s = int(rand($S->{NUMARCHSLAVES}));
			$dbh = $S->{SLAVEARCHDB}->[$s];
			warn "Using archive slave db $s\n" if $DEBUG;
			eval { $dbh->ping };
			# hopefully this works
			if($@){
				warn "Archive Slave went away hard, trying to use archive master: $@\n";
				$dbh = $S->get_archive_dbh();
				}
			}
		else {
			$dbh = $S->get_archive_dbh();
			}	
		}

	return $dbh;

	}


1;
