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

print "Updating section posting permissions...\n" unless $QUIET;

# get all the sections
my $get_sections = "SELECT section FROM sections";
my $sth = $dbh->prepare($get_sections);
my $rv = $sth->execute();
die "Couldn't run query [$get_sections]: $DBI::errstr\n" unless $rv;

# make a nice comma delimited list of them
my $sectionlist = '';
while( my $row = $sth->fetchrow_hashref() ) {
	$sectionlist .= $row->{section} . ',';
}
$sectionlist =~ s/,$//;

# now give everyone permission to post to every section
my $q = "update perm_groups set allowed_sections = '$sectionlist'";
$sth = $dbh->prepare($q);
$rv = $sth->execute();
die "Couldn't run query [$q]: $DBI::errstr\n" unless $rv;

print "Finished updating section permissions.  Edit who can post where now with the Group Admin tool.\n" unless $QUIET;

$dbh->disconnect();

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


=head1 USAGE

./update_section_perms.pl db_user db_pass db_name

=head1 INTENT

This script will give every group on your site permission to post to every section.
That way you don't have to give everyone permission by hand.  If you would rather
have nobody have permission to post anywhere at first, then don't run this script :)

=cut
