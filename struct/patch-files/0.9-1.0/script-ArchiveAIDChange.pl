#!/usr/bin/perl

use strict;
use Getopt::Std;
use DBI;


my $args = &get_args();

my $db_user = $args->{u};
my $db_pass = $args->{p};
my $db_port = $args->{o};
my $db_name = $args->{d};
my $db_host = $args->{h};

my $QUIET = $args->{q} || 0;

my $dsn = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
my $dbh = DBI->connect($dsn, $db_user, $db_pass);

my ($query, $sth, $rv);
$|++;

convert_stories();


sub convert_stories {
	mesg("\nConverting stories' table to numeric aid\n");

	mesg("  Checking for previous patch run...");
	$query = "SELECT aid FROM stories WHERE aid REGEXP '[^-0-9]' LIMIT 1";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($aid_test) = $sth->fetchrow_array;
	$sth->finish;
	if (defined $aid_test) {
		mesg("not found. Continuing.\n");
	} else {
		mesg("found. Skipping.\n");
		return;
	}

	mesg("  Checking for users table...");
	$query = "SELECT uid from users LIMIT 1";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($uid_test) = $sth->fetchrow();
	$sth->finish;
	if (defined $uid_test) {
		mesg(" Users table Ok. Continuing.\n");
	} else {
		mesg(" ERROR: No users table found!
		
To make this patch work, you need to create a temporary users table 
in the archive database. Do the following:

* Shut down your site
* Dump the users table from the regular database with 'mysqldump -p --opt [dbname] users > users.sql'
* Load that table into the archive like this: 'mysql -p [archive_dbname] < users.sql
* Then come back and run this patch\n\n");
		return;
	}
	
	
	mesg("  Adding temporary column...");
	$query = "ALTER TABLE stories ADD COLUMN temp_aid INT(11) NOT NULL AFTER aid";
	$rv = $dbh->do($query);
	unless ($rv) {
		mesg("error!\nDB said: $DBI::errstr\nSkipping this part.\n");
		return;
	}
	mesg("done\n");

	mesg("  Gathering data...");
	$query = "SELECT stories.aid, users.uid FROM stories, users WHERE stories.aid = users.nickname GROUP BY stories.aid";
	$sth = $dbh->prepare($query);
	$rv = $sth->execute;
	unless ($rv) {
		mesg("error!\nDB said: $DBI::errstr\nSkipping this part.\n");
		return;
	}
	mesg("done\n");

	mesg("  Inserting numeric aid's");
	my $update_sth = $dbh->prepare("UPDATE stories SET temp_aid = ? WHERE aid = ?");
	while (my ($nick, $uid) = $sth->fetchrow_array) {
		mesg('.');
		$update_sth->execute($uid, $nick);
	}
	mesg("done\n");
	$update_sth->finish;
	$sth->finish;

	mesg("  Removing old aid column...");
	$query = "ALTER TABLE stories DROP COLUMN aid";
	$rv = $dbh->do($query);
	unless ($rv) {
		mesg("error!\nDB said: $DBI::errstr\nSkipping this part.\n");
		return;
	}
	mesg("done\n");

	mesg("  Renaming temporary column to aid column...");
	$query = "ALTER TABLE stories CHANGE temp_aid aid INT(11) NOT NULL";
	$dbh->do($query);
	mesg("done\n");
}


sub mesg {
	print @_ unless $QUIET;
}

sub get_args {
    my %info;
    my @neededargs;

    getopts("u:p:d:h:o:vqD", \%info);

    # now first generate an array of hashrefs that tell us what we
    # still need to get
    foreach my $arg ( qw( u p d h o ) ) {
        next if ( $info{$arg} and $info{$arg} ne '' );

        if( $arg eq 'u' ) {
            push( @neededargs, {arg     => 'u',
                                q       => 'archive db username? ',
                                default => 'nobody'} );
        } elsif( $arg eq 'p' ) {
            push( @neededargs, {arg     => 'p',
                                q       => 'archive db password? ',
                                default => 'password'} );
        } elsif( $arg eq 'd' ) {
            push( @neededargs, {arg     => 'd',
                                q       => 'archive db name? ',
                                default => 'scoop'} );
        } elsif( $arg eq 'h' ) {
            push( @neededargs, {arg     => 'h',
                                q       => 'archive db hostname? ',
                                default => 'localhost'} );
        } elsif( $arg eq 'o' ) {
            push( @neededargs, {arg     => 'o',
                                q       => 'archive db port? ',
                                default => '3306'} );
        }
    }

    foreach my $h ( @neededargs ) {
        my $answer = '';

        print "$h->{q}"."[$h->{default}] ";
        chomp( $answer = <STDIN> );

        $answer = $h->{default} unless( $answer && $answer ne '' );

        $info{ $h->{arg} } = $answer;
    }

    return \%info;
}
