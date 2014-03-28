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

print "Updating section permissions...\n" unless $QUIET;

# get all the old section perms
my $get_old = "SELECT perm_group_id,allowed_sections FROM perm_groups";
my $sth = $dbh->prepare($get_old);
my $rv = $sth->execute();
die "Couldn't run query [$get_old]: $DBI::errstr\n" unless $rv;

# make a nice hash of them
my %grouphash;
while( my $row = $sth->fetchrow_hashref() ) {
	$grouphash{$row->{perm_group_id}} = $row->{allowed_sections};
}

# get all the sections
my $get_sections = "SELECT section FROM sections";
$sth = $dbh->prepare($get_sections);
$rv = $sth->execute();
die "Couldn't run query [$get_sections]: $DBI::errstr\n" unless $rv;

# make a nice comma delimited list of them
my $sectionlist = [];
while( my $row = $sth->fetchrow_hashref() ) {
        push( @$sectionlist , $row->{section} )
}

# now give everyone permission to post to every section, if they need it, and
# give them the rest of the perms too
for my $sect ( @$sectionlist ) {
	for my $g ( keys %grouphash ) {
		my $newperms = 'norm_post_comments,norm_read_comments,norm_read_stories';
		if( $grouphash{$g} =~ /$sect/ ) {
			$newperms .= ',norm_post_stories';
		}

		my $q = qq|insert into section_perms(group_id,section,sect_perms) values ('$g','$sect','$newperms')|;
		$sth = $dbh->prepare($q);
		$rv = $sth->execute();
		die "Couldn't run query [$q]: $DBI::errstr\n" unless $rv;
	}
}


print "Finished updating section permissions.  Edit who can post where now with the Section Admin tool.\n" unless $QUIET;

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

./update_new_sect_perms.pl db_user db_pass db_name

=head1 INTENT

This script will take the section perms that were put in before, and map those
across to the new style section perms in section_perms table.  It will only map
over the post_story permissions, since thats all that the old style supported.
it will also give everyone permission to read comments and stories, and read
stories in every section.


=cut
