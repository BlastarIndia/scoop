#!/usr/bin/perl
use DBI;
use DBD::mysql;
use strict;
my $DEBUG = 0;
my ($query, $sth, $rv);

# Configure DB connection for live DB
my $dbname   = '';
my $username = '';
my $password = '';
my $dbhost   = '';

# Configure DB connection for archive DB
my $archive_dbname   = '';
my $archive_username = '';
my $archive_password = '';
my $archive_dbhost   = '';


# Set up the db handles
my $data_source = "DBI:mysql:database=$dbname:host=$dbhost";
my $dbh = DBI->connect($data_source, $username, $password) ||
	die "Can't connect to database '$dbname'! $@\n";

# Configure archiving params
$sth = $dbh->prepare('SELECT value FROM vars where name = "story_archive_age"');
$rv = $sth->execute();
my $story_age = $ARGV[0] || $sth->fetchrow(); # In days
$sth->finish();

exit unless ($story_age);

my $test = (exists $ARGV[1]) ? $ARGV[1] : 0;
warn "Test mode is on. No data will be changed.\n" if $test;
warn "Test mode is off.\n" if (!$test and $DEBUG);

my $check = (exists $ARGV[2]) ? $ARGV[2] : 1;
warn "Consistency checks enabled.\n" if ($check and $DEBUG);
warn "Consistency checks are off! You will be prompted before any data is removed from the live database.\n" if (!$check);

# Archive DBH
my $archive_data_source = "DBI:mysql:database=$archive_dbname:host=$archive_dbhost";
my $archive_dbh = DBI->connect($archive_data_source, $archive_username, $archive_password) ||
	die "Can't connect to database '$archive_dbname'! $@\n";

# Find out what time to use as baseline
my $query = 'SELECT NOW()';
$sth = $dbh->prepare($query);
$rv = $sth->execute();
my $now = $sth->fetchrow();
$sth->finish();
warn "Now is: $now\n\n" if $DEBUG;


# Look for leftovers in archive
warn "Checking for unclean shutdown of previous run...\n" if $DEBUG;
my $leftovers = &check_archive('stories');
$leftovers += &check_archive('comments');

if ($leftovers && $check) { die "Error: Found $leftovers stories and comments still tagged to_archive. Please figure out what happened and fix it before running archive again.\n"; }
if ($leftovers && !$check) {
	print "Found $leftovers stories and comments still tagged to_archive.\nContinue anyway? [y/N] > ";
	chomp(my $continue = <STDIN>);
	unless ($continue =~ /y/i) {
		print "You chose not to continue.\n";
		die;
	}
}	

warn "...looks good.\n" if (!$leftovers && $DEBUG);

# Find archivable stuff
$query = "SELECT sid FROM stories WHERE date_add(time, interval $story_age day) < '$now'";
$sth = $dbh->prepare($query);
$rv = $sth->execute();
my @sids;

my $count = 0;
while (my $sid = $sth->fetchrow()) {
	warn "Looking at $sid...\n" if $DEBUG;
	my $sth2 = $dbh->prepare(qq|SELECT ad_id from ad_info where ad_sid = "$sid"|);
	my $rv2 = $sth2->execute();
	my $is_ad = $sth2->fetchrow();
	$sth2->finish();
	next if $is_ad;
	warn " ...isn't an ad. Archiving.\n" if $DEBUG;
	push @sids, $sid;
	$count++;
}
$sth->finish();
	
# Mark stories and comments archivable
my $where = join(qq|' OR sid = '|, @sids);
$query = "UPDATE stories set to_archive=1 where sid = '$where'";
$sth = $dbh->prepare($query);
my $num_stories = $sth->execute();
warn "Set $num_stories stories to archive\n" if $DEBUG;
$sth->finish();

$query = "UPDATE comments set to_archive=1 where sid = '$where'";
$sth = $dbh->prepare($query);
my $num_comments = $sth->execute();
warn "Set $num_comments comments to archive\n" if $DEBUG;
$sth->finish();

# Move stories and comments into archive
my $archive_command = qq{mysqldump -c -t -h $dbhost -u $username --password=$password -w "to_archive = 1" $dbname stories comments |
			 perl -n -e 's/^INSERT INTO/INSERT IGNORE INTO/;print $_;' | 
			 mysql -f -u $archive_username --password=$archive_password -h $archive_dbhost $archive_dbname};

unless ($test) { system($archive_command) == 0 or die "system $archive_command failed: $?"; }

&consistency_check($num_stories, $num_comments);

if (!$check) {
	print "Archive command run. Look carefully at the output, and check that nothing went wrong.\nContinue? [y/N] > ";
	chomp(my $continue = <STDIN>);
	unless ($continue =~ /y/i) {
		print "You chose not to continue.\n";
		&rollback();
		die;
	}
}

if ($test) { &rollback(); print "Would have ";}

unless ($test) { &cleanup($where); }

warn "Archived $num_stories stories, $num_comments comments.\n\n" if $DEBUG;

sub cleanup {
	my $where = shift;

	# Clean up database
	warn "Deleting stories...\n" if $DEBUG;
	$query = qq|DELETE FROM stories where to_archive = 1|;
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	warn "Removed $rv stories\n" if $DEBUG;
	$sth->finish();

	warn "Deleting comments...\n" if $DEBUG;
	$query = qq|DELETE FROM comments where to_archive = 1|;
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
	warn "Removed $rv comments\n" if $DEBUG;
	$sth->finish();

	warn "Deleting votes...\n" if $DEBUG;
	$query = qq|DELETE FROM storymoderate where sid = '$where'|;
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
    	warn "Removed $rv votes\n" if $DEBUG;
	$sth->finish();
	
	warn "Deleting ratings...\n" if $DEBUG;
	$query = qq|DELETE FROM commentratings where sid = '$where'|;
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
    	warn "Removed $rv ratings\n" if $DEBUG;
	$sth->finish();
	
	
	warn "Deleting viewed_stories...\n" if $DEBUG;
	$query = qq|DELETE viewed_stories from viewed_stories 
	            LEFT JOIN stories ON viewed_stories.sid=stories.sid 
		    LEFT JOIN pollquestions ON viewed_stories.sid=pollquestions.qid 
		    WHERE stories.sid IS NULL AND pollquestions.qid IS NULL and viewed_stories.hotlisted = 0;|;
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();
    	warn "Removed $rv viewed_stories\n" if $DEBUG;
	$sth->finish();
	
	warn "Finalizing archive material...\n" if $DEBUG;
	$query = 'UPDATE stories SET to_archive = 0';
	$sth = $archive_dbh->prepare($query);
	$rv = $sth->execute();	
	$sth->finish();
    	warn "Untagged $rv archive stories\n" if $DEBUG;
	
	$query = 'UPDATE comments SET to_archive = 0';
	$sth = $archive_dbh->prepare($query);
	$rv = $sth->execute();	
	$sth->finish();
    	warn "Untagged $rv archive comments\n" if $DEBUG;
}

sub rollback {
	warn "Rolling back archive writes.\n" if $DEBUG;
	my $query = 'DELETE FROM stories WHERE to_archive = 1';	
	my $sth = $archive_dbh->prepare($query);
	my $rv = $sth->execute();
	$sth->finish();
	warn "Removed $rv stories from archive.\n" if $DEBUG;
	
	$query = 'DELETE FROM comments WHERE to_archive = 1';
	$sth = $archive_dbh->prepare($query);
	$rv = $sth->execute();	
	$sth->finish();
	warn "Removed $rv comments from archive.\n" if $DEBUG;
	
	warn "Rolling back to_archive flags.\n" if $DEBUG;
	$query = 'UPDATE stories SET to_archive = 0';
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();	
	$sth->finish();
	$query = 'UPDATE comments SET to_archive = 0';
	$sth = $dbh->prepare($query);
	$rv = $sth->execute();	
	$sth->finish();
}	

sub check_archive {
	my $table = shift;
	
	my $query = "SELECT count(*) from $table where to_archive = 1";
	my $sth = $archive_dbh->prepare($query);
	my $rv = $sth->execute();
	my $leftovers = $sth->fetchrow();
	$sth->finish();
	return $leftovers;
}

sub consistency_check {
	my $num_stories = shift;
	my $num_comments = shift;
	
	warn "Consistency checking archive\n" if $DEBUG;
	
	# Find out how many stories and comments are tagged to_archive
	my $archived_stories = &check_archive('stories');
	my $archived_comments = &check_archive('comments');
	
	if ($archived_stories != $num_stories) {
		warn "Error! Expected to archive $num_stories stories, only archived $archived_stories.\n";
		&rollback() unless (!$check);
		die unless (!$check);
	}
	
	if ($archived_comments != $num_comments) {
		warn "Error! Expected to archive $num_comments comments, only archived $archived_comments.\n";
		&rollback() unless (!$check);
		die unless (!$check);
	}
	
	warn "Expected $num_stories stories, archived $archived_stories.\nExpected $num_comments comments, archived $archived_comments\n" if $DEBUG;
}	
