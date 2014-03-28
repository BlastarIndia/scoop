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

$|++;
my ($query, $sth);

print "Getting perms var..." unless $QUIET;
$query = "SELECT value FROM vars WHERE name = 'perms'";
$sth = $dbh->prepare($query);
$sth->execute;
my ($perms) = $sth->fetchrow_array;
$sth->finish;
print "done\n" unless $QUIET;

print "Checking for patch..." unless $QUIET;
if ($perms =~ /edit_macros/) {
	print "found! Leaving perms alone.\n" unless $QUIET;
} else {
	print "not applied\nAdding macro support..." unless $QUIET;
	$perms =~ s/(view_log)/$1,\nedit_macros/i;
	print "done\n" unless $QUIET;

	print "Putting perms back in..." unless $QUIET;
	$query = "UPDATE vars SET value = ? WHERE name = 'perms'";
	$sth = $dbh->prepare($query);
	$sth->execute($perms);
	$sth->finish;
	print "done\n" unless $QUIET;
	print "Getting Superuser group perms..." unless $QUIET;
	$query = "SELECT group_perms FROM perm_groups WHERE perm_group_id = 'Superuser'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	$perms = $sth->fetchrow_array;
	$sth->finish;
	print "done\n" unless $QUIET;
	if ($perms =~ /edit_macros/) {
		print "found! Leaving Superuser alone.\n" unless $QUIET;
	} else {
		print "not applied\nAdding macro support..." unless $QUIET;
		$perms .= ',edit_macros';
		print "done\n" unless $QUIET;
	
		print "Putting perms back in..." unless $QUIET;
		$query = "UPDATE perm_groups SET group_perms = ? WHERE perm_group_id = 'Superuser'";
		$sth = $dbh->prepare($query);
		$sth->execute($perms);
		$sth->finish;
		print "done\n" unless $QUIET;
	}
	print "Getting Admins group perms..." unless $QUIET;
	$query = "SELECT group_perms FROM perm_groups WHERE perm_group_id = 'Admins'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	$perms = $sth->fetchrow_array;
	$sth->finish;
	print "done\n" unless $QUIET;
	if ($perms =~ /edit_macros/) {
		print "found! Leaving Admins alone.\n" unless $QUIET;
	} else {
		print "not applied\nAdding macro support..." unless $QUIET;
		$perms .= ',edit_macros';
		print "done\n" unless $QUIET;
	
		print "Putting perms back in..." unless $QUIET;
		$query = "UPDATE perm_groups SET group_perms = ? WHERE perm_group_id = 'Admins'";
		$sth = $dbh->prepare($query);
		$sth->execute($perms);
		$sth->finish;
		print "done\n" unless $QUIET;
	}
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
