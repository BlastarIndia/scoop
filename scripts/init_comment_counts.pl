#!/usr/bin/perl
use strict;

my $DEBUG = 1;

##########################
# Configuration:
#	Adjust the vars below to work for your install
##########################
# DB connection params
my $db_user = $ARGV[2] || 'nobody';
my $db_host = 'localhost';
my $db_pass = $ARGV[1] || 'password';
my $db_port = '3306';
my $db_name = $ARGV[0] || 'scoop';

use DBI;
use DBD::mysql;
	
my $data_source = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
my $dbh = DBI->connect($data_source, $db_user, $db_pass);

print "Updating comment counts. This may take a moment...\n";

my $get_comments = "SELECT sid, cid from comments where points IS NOT NULL";
my $sth = $dbh->prepare($get_comments);
my $rv = $sth->execute();

unless ($rv) {
	die "Can't run $get_comments? ".$dbh->errstr()."\n";
}
my $total = 0;
while (my $comm = $sth->fetchrow_hashref()) {
	print "Updating $comm->{sid} #$comm->{cid}: " if ($DEBUG);
	my $count_ratings = qq|SELECT COUNT(*) from commentratings where sid = "$comm->{sid}" AND cid = "$comm->{cid}"|;
	my $sth2 = $dbh->prepare($count_ratings);
	my $rv = $sth2->execute();
	
	unless ($rv) {
		die "Can't run $count_ratings? ".$dbh->errstr()."\n";
	}

	my $count = $sth2->fetchrow();
	$sth2->finish();
	
	print "$count ratings found.\n" if $DEBUG;
	
	my $update_count = qq|UPDATE comments set lastmod = $count where sid = "$comm->{sid}" AND cid = "$comm->{cid}"|;
	$sth2 =  $dbh->prepare($update_count);
	$rv = $sth2->execute();

	unless ($rv) {
		die "Can't run $update_count? ".$dbh->errstr()."\n";
	}
	
	$sth2->finish();
	$total++;
}

$sth->finish();
$dbh->disconnect();

print "Done! $total comments updated.\n";
exit 1;
