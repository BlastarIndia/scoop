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

print "Grabbing box template..." unless $QUIET;
$query = "SELECT block FROM blocks WHERE bid = 'box'";
$sth = $dbh->prepare($query);
$sth->execute;
my ($block) = $sth->fetchrow_array;
$sth->finish;
print "done\n" unless $QUIET;

print "Checking to see if patch has been applied..." unless $QUIET;
if ($block =~ /\%\%box_title_bg\%\%/i) {
	print "found\nSkipping this patch\n" unless $QUIET;
} else {
	print "not applied\n" unless $QUIET;

	print "Changing background color to call a block..." unless $QUIET;
	$block =~ s{td([^>]+)bgcolor="([^"]+)"}{td$1bgcolor="\%\%box_title_bg\%\%"}i;
	my $old_color = $2;
	print "done\n" unless $QUIET;

	if ($old_color) {
		print "Putting updated block back in..." unless $QUIET;
		$query = q|UPDATE blocks SET block = ? WHERE bid = 'box'|;
		$sth = $dbh->prepare($query);
		$sth->execute($block);
		$sth->finish;
		print "done\n" unless $QUIET;

		print "Changing box_title_bg to value that was in 'box'..." unless $QUIET;
		$query = q|UPDATE blocks SET block = ? WHERE bid = 'box_title_bg' AND theme = 'default'|;
		$sth = $dbh->prepare($query);
		$sth->execute($old_color);
		$sth->finish;
		print "done\n" unless $QUIET;
	} else {
		print "Failed to update block. You'll need to manually change the block 'box' so that\n";
		print "the background color calls the block 'box_title_bg'.\n";
		print "\nLeaving block unmodified for now.\n";
		sleep 5;
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
