#!/usr/bin/perl

use strict;
use DBI;
use Getopt::Std;

my $args = &get_args();

my $db_user = $args->{u};
my $db_pass = $args->{p};
my $db_port = $args->{o};
my $db_name = $args->{d};
my $db_host = $args->{h};

my $QUIET = $args->{q} || 0;


my $dsn = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
my $dbh = DBI->connect($dsn, $db_user, $db_pass);

print "Converting hotlist data. This will take a short while...\n" unless $QUIET;

my $get_hotlists = "SELECT uid, prefvalue FROM userprefs WHERE prefname = 'hotlist'";
my $sth = $dbh->prepare($get_hotlists);
my $rv = $sth->execute();
die "Couldn't run query [$get_hotlists]: $DBI::errstr\n" unless $rv;

my $insert_hotlist = "INSERT INTO viewed_stories (uid, sid, hotlisted) VALUES
(?, ?, 1)";
my $sth2 = $dbh->prepare($insert_hotlist);
while (my $row = $sth->fetchrow_arrayref) {
	foreach my $l ( split(/;/, $row->[1]) ) {
		my $rv = $sth2->execute($row->[0], $l);
		warn "Error running query [$insert_hotlist] with [$row->[0]] and [$l]: $DBI::errstr\n" unless $rv;
	}
}
$sth2->finish;
$sth->finish;

my $remove_hotlist = "DELETE FROM userprefs WHERE prefname = 'hotlist'";
my $rv = $dbh->do($remove_hotlist);
die "Error running query [$remove_hotlist]: $DBI::errstr\n" unless $rv;

$dbh->disconnect;
print "Finished converting hotlists over.\n" unless $QUIET;

exit 0;

sub get_args {
	my %info;
	my @neededargs;

	getopts("u:p:d:h:o:vqD", \%info);

	# now first generate an array of hashrefs that tell us what we
	# still need to get
	foreach my $arg ( qw( u p d h o ) ) {
		next if ( $info{$arg} and $info{$arg} ne '' );

		if( $arg eq 'u' ) {
			push( @neededargs, {arg		=> 'u',
								q		=> 'db username? ',
								default	=> 'nobody'} );
		} elsif( $arg eq 'p' ) {
			push( @neededargs, {arg		=> 'p',
								q		=> 'db password? ',
								default	=> 'password'} );
		} elsif( $arg eq 'd' ) {
			push( @neededargs, {arg		=> 'd',
								q		=> 'db name? ',
								default	=> 'scoop'} );
		} elsif( $arg eq 'h' ) {
			push( @neededargs, {arg		=> 'h',
								q		=> 'db hostname? ',
								default	=> 'localhost'} );
		} elsif( $arg eq 'o' ) {
			push( @neededargs, {arg		=> 'o',
								q		=> 'db port? ',
								default	=> '3306'} );
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


__END__

=head1 NAME

update_hotlist.pl - update hotlist from old style to new

=head1 SYNOPSIS

update_hotlist.pl [user [pass [db [dbhost]]]]

=head1 DESCRIPTION

During the addition of X new comments to scoop, the hotlist storage also got
changed, from using a row in the userprefs table to having it's own table. This
script should be run on old tables, still using the userprefs method, to update
user hotlist's. Make sure you've applied all other patches first, otherwise
this script will fail. Also, this script will remove the old hotlist's when
finished.

=head1 CONFIGURATION

At the top of the script, there are a few vars controlling the SQL server,
port, username, password, and database. The last three can also be passed on
the command line, in that order.

=head1 PREREQUISITES

Make sure you've updated to the appropriate code, and that you've applied the
SQL patch F<patch-04-NewHotlist.sql>, and any that it relies on.

=cut
