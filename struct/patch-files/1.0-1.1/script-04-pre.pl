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

mesg("\nStarting user info migration...\n");
# fields to rescue from users table: fakeemail, homepage, bio, publickey, admin_notes, sig
$query = "SELECT uid,fakeemail,homepage,bio,publickey,admin_notes,sig FROM users";
$sth = $dbh->prepare($query);
$sth->execute;
my $user_data = $sth->fetchall_hashref('uid');
$sth->finish;
mesg("\nGot info from users table...\n");

#now insert all that data into the userprefs table
mesg("\nPutting user info into userprefs table...\n");
foreach my $uid (sort keys %{$user_data}) {
	foreach my $key (keys %{$user_data->{$uid}}) {
		next unless $user_data->{$uid}->{$key};
		my $err = &insert_pref($dbh, $uid, $key, $user_data->{$uid}->{$key});
		mesg("\nError inserting $key ($user_data->{$uid}->{$key}) for UID $uid: $err\n") if $err;
	}
}

mesg("\nDone user info migration...\n");

# utility functions follow from here
sub insert_pref {
	my ($dbh, $uid, $pref, $value) = @_;
	my $q_uid = $dbh->quote($uid);
	my $q_pref = $dbh->quote($pref);
	my $q_value = $dbh->quote($value);
	my $query = "INSERT INTO userprefs VALUES ($q_uid, $q_pref, $q_value)";
	my $sth = $dbh->prepare($query);
	$sth->execute;
	return ($dbh->errstr) ? $dbh->errstr : '';
}

sub grab_var {
	my ($dbh, $id) = @_;
	my $query = "SELECT value FROM vars WHERE name = " . $dbh->quote($id);
	my $sth = $dbh->prepare($query);
	$sth->execute;
	my ($contents) = $sth->fetchrow_array;
	$sth->finish;
	return $contents;
}

sub update_var {
	my ($dbh, $id, $contents) = @_;
	my $query = "UPDATE vars SET value = ? WHERE name = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($contents, $id);
	$sth->finish;
}

sub grab_block {
	my ($dbh, $bid) = @_;
	my $query = "SELECT block FROM blocks WHERE bid = " . $dbh->quote($bid);
	my $sth = $dbh->prepare($query);
	$sth->execute;
	my ($contents) = $sth->fetchrow_array;
	$sth->finish;
	return $contents;
}

sub update_block {
	my ($dbh, $bid, $contents) = @_;
	my $query = "UPDATE blocks SET block = ? WHERE bid = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($contents, $bid);
	$sth->finish;
}

sub grab_box {
	my ($dbh, $box) = @_;
	my $query = "SELECT content FROM box WHERE boxid = " . $dbh->quote($box);
	my $sth = $dbh->prepare($query);
	$sth->execute;
	my ($contents) = $sth->fetchrow_array;
	$sth->finish;
	return $contents;
}

sub update_box {
	my ($dbh, $box, $contents) = @_;
	my $query = "UPDATE box SET content = ? WHERE boxid = ?";
	my $sth = $dbh->prepare($query);
	$sth->execute($contents, $box);
	$sth->finish;
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
                                q       => 'db username? ',
                                default => 'nobody'} );
        } elsif( $arg eq 'p' ) {
            push( @neededargs, {arg     => 'p',
                                q       => 'db password? ',
                                default => 'password'} );
        } elsif( $arg eq 'd' ) {
            push( @neededargs, {arg     => 'd',
                                q       => 'db name? ',
                                default => 'scoop'} );
        } elsif( $arg eq 'h' ) {
            push( @neededargs, {arg     => 'h',
                                q       => 'db hostname? ',
                                default => 'localhost'} );
        } elsif( $arg eq 'o' ) {
            push( @neededargs, {arg     => 'o',
                                q       => 'db port? ',
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
