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

print "Getting comment_controls box..." unless $QUIET;
$query = "SELECT content FROM box WHERE boxid = 'comment_controls'";
$sth = $dbh->prepare($query);
$sth->execute;
my ($box) = $sth->fetchrow_array;
$sth->finish;
print "done\n" unless $QUIET;

print "Checking for patch..." unless $QUIET;
if ($box =~ /if\s*\(\$comment_type_select\)\s*\{/) {
	print "found! Leaving box alone.\n" unless $QUIET;
} else {
	print "not applied\nAdding commentstatus support..." unless $QUIET;
	$box =~ s/(<TD VALIGN="middle">\r?\n\s*%%smallfont%%)/$1|;\nif (\$comment_type_select) {\n\t\$comment_sort .= qq|\n/i;
	$box =~ s/(\$comment_type_select\r?\n\s*<\/SMALL>)/$1|;\n}\n\$comment_sort .= qq|/i;
	print "done\n" unless $QUIET;

	print "Putting comment_controls back in..." unless $QUIET;
	$query = "UPDATE box SET content = ? WHERE boxid = 'comment_controls'";
	$sth = $dbh->prepare($query);
	$sth->execute($box);
	$sth->finish;
	print "done\n" unless $QUIET;
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
