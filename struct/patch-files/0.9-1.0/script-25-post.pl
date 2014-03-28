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

mesg("\nUpdating user urltemplate\n");

mesg("  Getting urltemplate for op user...");
$query = "SELECT urltemplates FROM ops WHERE op = 'user'";
$sth = $dbh->prepare($query);
$sth->execute;
my ($tmpl) = $sth->fetchrow_array;
$sth->finish;
mesg("done\n");

mesg("  Checking for diary patch...");

if ($tmpl =~ /user\s*\=\>\s*\"\$path\[0\]\"__COMMA__/) {
	mesg("found. Skipping.\n");
} else {
	mesg("not found. Continuing.\n");

	mesg("  Changing Diary handling line\n");
	$tmpl =~ s/(user\s*\=\>\s*)\"diary_\$uid\"/$1\"\$path[0]\"/;
}

mesg("  Checking for action patch...");

if ($tmpl =~ /\$p\-\>\{action\}/) {
	mesg("found. Skipping.\n");
} else {
	mesg("not found. Continuing.\n");

	mesg("  Adding action line\n");
	$tmpl =~ s/(\$p-\>\{op\}\s*=\s*\'user\';)/$1\n    \$p->\{action\}  \= \$path\[2\];/;
}

mesg("  Putting template back in...");
$query = "UPDATE ops SET urltemplates = " . $dbh->quote($tmpl) . " WHERE op = 'user'";
$dbh->do($query);
mesg("done\n");

# utility functions follow from here
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
