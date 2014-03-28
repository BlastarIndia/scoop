package Scoop;
use strict;

my $DEBUG = 0;
my $DB_EXPLAIN = 0;
my $CACHE_ONLY_DEBUG = 0;
$Scoop::COUNT_DEBUG = 0;
$Scoop::DB_QUERY_COUNT = 0;
$Scoop::DB_CACHE_HITS = 0;
$Scoop::DB_CACHE_MISSES = 0;
$Scoop::DB_NOCACHE = 0;

sub db_select {
	my $S = shift;
	my $args = shift;
	my $archive;
	
	$Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);
	
	my $query = "SELECT";
	my $dbh;

	if ($args->{DISTINCT}) {
		$query .= " DISTINCT";
	}

	my $table = $S->modify_for_shared_db($args->{FROM});

	if ($args->{ARCHIVE}) {
		$archive = 1;
		$dbh = $S->get_archive_dbh(1);
	} else {
		$archive = 0;
		$dbh = $S->get_dbh(1);
	}
	return('0E0',undef) unless ($dbh);

	
	$query .= " $args->{WHAT} FROM $table";
	$table =~ s/^\s*(.*)\s*$/$1/;
	
	my $resource = 'sql_'.$table;
	my $element = 'SQL_DATA_'.$table;
	
	if ($args->{WHERE}) {
		$query .= " WHERE $args->{WHERE}";
	}
	if ($args->{GROUP_BY}) {
		$query .= " GROUP BY $args->{GROUP_BY}";
	}
	if ($args->{ORDER_BY}) {
		$query .= " ORDER BY $args->{ORDER_BY}";
	}
	if ($args->{LIMIT}) {
		$query .= " LIMIT";
		if (lc($S->{CONFIG}->{DBType}) eq "mysql") {
			if ($args->{OFFSET}) {
				$query .= " $args->{OFFSET},";
			}
			$query .= " $args->{LIMIT}";
		} else {
			$query .= " $args->{LIMIT}";
			if($args->{OFFSET}) {
				$query .= " OFFSET $args->{OFFSET}";
			}
		}
	}
	if ($args->{DEBUG} || $DEBUG) {warn "in db_select: Query is $query\n";}
	
	# Don't cache if we're doing a join, for now.
	$args->{NOCACHE} = 1 if ($table =~ /,/);
	$args->{NOCACHE} = 1 unless $S->{UI}->{VARS}->{use_db_cache};
	
	my ($sth, $rv) = undef;
	my $cached = {};
	$cached->{data} = [];
	$cached->{name} = '';
	
	if($DB_EXPLAIN){
		my $explain;
		my $sthexp = $dbh->prepare("EXPLAIN ".$query);
		my $rvexp = $sthexp->execute();
		my @values=$sthexp->fetchrow_array;
		for('table','type','possible_keys','key','key_len','ref','rows','extra'){
			$explain.="$_: ".shift(@values)."\n";
		} warn "Query: $query\n$explain"; $sthexp->finish();
	}

	if (!$args->{NOCACHE} &&
		($cached = $S->cache->fetch_data({resource => $resource, 
	                                      element => $element,
		                                  item => $query}))) {
		$Scoop::DB_CACHE_HITS++;	
		$rv = ($#{$cached->{data}}+1);
		$rv = '0E0' if ($rv == 0);
	} else {	
		($args->{NOCACHE}) ? $Scoop::DB_NOCACHE++ : $Scoop::DB_CACHE_MISSES++;
		
		warn "in db_select: not found in cache. Running query\n" if ($DEBUG);
		warn "Cache miss! ($resource".'::'.$query.")\n" if ($CACHE_ONLY_DEBUG);
		$sth = $dbh->prepare($query);
		
		$rv = $sth->execute();
	
		if ($args->{NOCACHE}) {
			unless($rv)
			{
    				my ($package, $filename, $line) = caller;
				warn "<<ERROR>> <<$S->{REMOTE_IP}>> in db_select: $DBI::errstr (Query is $query) : Error in $filename line $line" 
			}
			return ($rv, $sth);
		}
		
		my $size = 0;
		my $line;
		while ($line = $sth->fetchrow_hashref()) {
			foreach my $key (keys %{$line}) {
				$size += length($line->{$key});
			}	
			push @{$cached->{data}}, $line;
		}
		$cached->{name} = $sth->{NAME};
		$sth->finish();

		warn "Size is $size\n" if $DEBUG;
		# Cache this stuff
		warn "Caching data for ".$element.'::'.$query."\n" if ($CACHE_ONLY_DEBUG);
		$S->cache->cache_data({resource => $resource,
	                           element => $element,
						       item => $query,
						       data => $cached,
							   size => $size});

	}
	
	my $scoop_sth = Scoop::Statement->new($cached->{data}, $cached->{name});
	#$scoop_sth->init($data, $name);
	$cached = {};
	
	warn "Made Scoop sth. Returning.\n" if $DEBUG;

    my ($package, $filename, $line) = caller;
	warn "<<ERROR>> <<$S->{REMOTE_IP}>> in db_select: $DBI::errstr (Query is $query) : Error in $filename line $line" unless ($rv);	
	return ($rv, $scoop_sth);
}


sub db_wipe_table_cache {
	my $S = shift;
	my $table = shift;
	$table =~ s/^\s*(.*)\s*$/$1/;
	my $resource = 'sql_'.$table;
	my $element = 'SQL_DATA_'.$table;

	# Clear the table's whole cache
	$S->cache->clear({resource => $resource, element => $element});
		
	return;
}


sub db_update {
	my $S = shift;
	my $args = shift;
	$Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);
	$args->{NOCACHE} = 1 unless $S->{UI}->{VARS}->{use_db_cache};

	$args->{WHAT}=$S->modify_for_shared_db($args->{WHAT});

	my $query = "UPDATE $args->{WHAT} SET $args->{SET}";
	if ($args->{WHERE}) {
		$query .= " WHERE $args->{WHERE}";
	}
	if ($args->{LIMIT}) {
		$query .= " LIMIT $args->{LIMIT}";
	}
	
	if ($args->{DEBUG} || $DEBUG) {warn "in db_update: Query is $query\n";}
	
	my $dbh;
	if ($args->{ARCHIVE}) {
		$dbh = $S->get_archive_dbh;
	} else {
		$dbh = $S->get_dbh;
	}
	return('0E0',undef) unless ($dbh);

	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();

    my ($package, $filename, $line) = caller;
	warn "<<ERROR>> in db_update: $DBI::errstr (Query is $query) : Error in $filename line $line" unless $rv;
	$S->db_wipe_table_cache($args->{WHAT}) if ($rv && !$args->{NOCACHE});
	
	return ($rv, $sth);
}

sub db_insert {
	my $S = shift;
	my $args = shift;
	my $dbh;
	$Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);
	$args->{NOCACHE} = 1 unless $S->{UI}->{VARS}->{use_db_cache};

	$args->{INTO}=$S->modify_for_shared_db($args->{INTO});
	
	my $query = "INSERT INTO $args->{INTO}";

	if ($args->{COLS}) {
		$query .= " ($args->{COLS})";
	}

	$query .= " VALUES ($args->{VALUES})";
	
	if ($args->{DEBUG} || $DEBUG) {warn "in db_insert: Query is $query\n";}

	if ($args->{ARCHIVE}) {
		$dbh = $S->get_archive_dbh;
	} else {
  		$dbh = $S->get_dbh;
	}
	return('0E0',undef) unless ($dbh);
	
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();

    my ($package, $filename, $line) = caller;
	warn "<<ERROR>> <<$S->{REMOTE_IP}>> in db_insert: $DBI::errstr (Query is $query) : Error in $filename line $line" unless $rv;
	$S->db_wipe_table_cache($args->{INTO}) if ($rv && !$args->{NOCACHE});

	return ($rv, $sth);
}

sub db_delete {
	my $S = shift;
	my $args = shift;
	$Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);
	$args->{NOCACHE} = 1 unless $S->{UI}->{VARS}->{use_db_cache};

	$args->{FROM}=$S->modify_for_shared_db($args->{FROM});
	
	my $query = "DELETE FROM $args->{FROM}";
	
	if ($args->{WHERE}) {
		$query .= " WHERE $args->{WHERE}";
	}
	
	if ($args->{LIMIT}) {
		$query .= " LIMIT $args->{LIMIT}";
	}

	if ($args->{DEBUG} || $DEBUG) {warn "in db_delete: Query is $query\n";}

	my $dbh;
	if ($args->{ARCHIVE}) {
		$dbh = $S->get_archive_dbh;
	} else {
  		$dbh = $S->get_dbh;
	}
	return('0E0',undef) unless ($dbh);

	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();

    my ($package, $filename, $line) = caller;
	warn "<<ERROR>> in db_delete: $DBI::errstr (Query is $query) : Error in $filename line $line" unless $rv;
	$S->db_wipe_table_cache($args->{FROM}) if ($rv && !$args->{NOCACHE});

	return ($rv, $sth);
}

sub db_lock_tables {
	my $S = shift;
	my $args = shift;

	$Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);

	my $query = "LOCK TABLES ";
	while (my($k, $v) = each %{ $args }) {
		$query .= "$k $v" unless $k eq "DEBUG";
	}

	if ($args->{DEBUG} || $DEBUG) {warn "in db_lock_tables: Query is $query\n";}

	my $dbh;
	if ($args->{ARCHIVE}) {
		$dbh = $S->get_archive_dbh;
	} else {
  		$dbh = $S->get_dbh;
	}
	return('0E0',undef) unless ($dbh);

	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();

	warn "<<ERROR>> in db_lock_tables: $DBI::errstr (Query is $query)\n" unless $rv;
	return ($rv, $sth);
}

sub modify_for_shared_db{
  my $S=shift;
  my $queryfrag=shift;
  warn("Determining Shared Database Usage Status for '$queryfrag'") if $DEBUG;
  return $queryfrag unless $S->var('use_shared_db');
  warn("We're using a Shared Database. Proceeding to Replacement") if $DEBUG;
  my $shared_db_name=$S->var('shared_db_name');
  for(split(/\s+/,$S->var('shared_db_tables'))){
    warn("Checking for Instances of '$_' for Replacement") if $DEBUG;
    $queryfrag=~s/(\b$_\b)/$shared_db_name\.$1/ig;
  }
  warn("Returning Updated Query Fragment for Shared DB: '$queryfrag'") if $DEBUG;
  return $queryfrag;
}

sub db_unlock_tables {
	my $S = shift;
	my $args = shift;

	$Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);

	my $query = "UNLOCK TABLES";
	
	if ($args->{DEBUG} || $DEBUG) {warn "in db_unlock_tables: Query is $query\n";}

	my $dbh;
	if ($args->{ARCHIVE}) {
		$dbh = $S->get_archive_dbh;
	} else {
  		$dbh = $S->get_dbh;
	}
	return('0E0',undef) unless ($dbh);

	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();

	warn "<<ERROR>> in db_unlock_tables: $DBI::errstr (Query is $query)\n" unless $rv;
	return ($rv, $sth);
}

# Add functions for transactions. Can only be used with versions of mysql
# that use transactions, of course.

sub db_start_transaction {
        my $S = shift;
        my $args = shift;

	unless ($S->{CONFIG}->{mysql_version} =~ /^4/) {
		return "Transactions not supported in this version of MySQL.\n";
		}
        $Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);
                                                                                
        my $query = "START TRANSACTION";
                                                                                
        if ($args->{DEBUG} || $DEBUG) {warn "in db_start_transaction: Query is $query\n";}
                                                                                
        my $dbh;
        if ($args->{ARCHIVE}) {
                $dbh = $S->get_archive_dbh;
        } else {
                $dbh = $S->get_dbh;
        }
        return('0E0',undef) unless ($dbh);
                                                                                
        my $sth = $dbh->prepare($query);
        my $rv = $sth->execute();
                                                                                
        warn "<<ERROR>> in db_start_transaction: $DBI::errstr (Query is $query)\n" unless $rv;
        return ($rv, $sth);
}

sub db_commit {
        my $S = shift;
        my $args = shift;
                                                                                
	unless ($S->{CONFIG}->{mysql_version} =~ /^4/) {
                return "Transactions not supported in this version of MySQL.\n";
                }
        $Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);
                                                                                
        my $query = "COMMIT";
                                                                                
        if ($args->{DEBUG} || $DEBUG) {warn "in db_commit: Query is $query\n";}
                                                                                
        my $dbh;
        if ($args->{ARCHIVE}) {
                $dbh = $S->get_archive_dbh;
        } else {
                $dbh = $S->get_dbh;
        }
        return('0E0',undef) unless ($dbh);
                                                                                
        my $sth = $dbh->prepare($query);
        my $rv = $sth->execute();
                                                                                
        warn "<<ERROR>> in db_commit: $DBI::errstr (Query is $query)\n" unless $rv;
        return ($rv, $sth);
}

sub db_rollback {
        my $S = shift;
        my $args = shift;
                                                                                
	unless ($S->{CONFIG}->{mysql_version} =~ /^4/) {
                return "Transactions not supported in this version of MySQL.\n";
                }
        $Scoop::DB_QUERY_COUNT++ if ($Scoop::COUNT_DEBUG);
                                                                                
        my $query = "ROLLBACK";
                                                                                
        if ($args->{DEBUG} || $DEBUG) {warn "in db_rollback: Query is $query\n";}
                                                                                
        my $dbh;
        if ($args->{ARCHIVE}) {
                $dbh = $S->get_archive_dbh;
        } else {
                $dbh = $S->get_dbh;
        }
        return('0E0',undef) unless ($dbh);
                                                                                
        my $sth = $dbh->prepare($query);
        my $rv = $sth->execute();
                                                                                
        warn "<<ERROR>> in db_rollback: $DBI::errstr (Query is $query)\n" unless $rv;
        return ($rv, $sth);
}

sub db_date_sub {
	my $S = shift;
	my $left = shift;
	my $right = shift;
	
	if (lc($S->{CONFIG}->{DBType}) eq "mysql") {
		return "DATE_SUB(($left), INTERVAL $right)";
	} else {
		return "$left + INTERVAL '$right'";
	}
}

sub db_date_add {
	my $S = shift;
	my $left = shift;
	my $right = shift;

	if(lc($S->{CONFIG}->{DBType}) eq "mysql") {
		return "DATE_ADD(($left), INTERVAL $right)";
	} else {
		 return "$left + INTERVAL '$right'";
	}
}

1;
