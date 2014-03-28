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
my $default;
$|++;

&mesg("\nChecking box startpage_validation\n");
my $box = &grab_box($dbh,'startpage_validation');
if ( $box =~ /return ';/ ) {
  &mesg("Fixing...\n");
  $box =~ s/return ';/return '';/;
  &update_box($dbh,'startpage_validation',$box);
} else {
  &mesg("Already fixed, skipping\n");
}

# utility functions follow from here

sub grab_optemplate {
	my ($dbh, $id) = @_;
	my $query = "SELECT urltemplates FROM ops WHERE op=" . $dbh->quote($id);
	my $sth = $dbh->prepare($query);
	$sth->execute;
	my ($contents) = $sth->fetchrow_array;
	$sth->finish;
	return $contents;
}

sub update_optemplate {
	my ($dbh, $id, $contents) = @_;
	my $query = "UPDATE ops SET urltemplates = " . $dbh->quote($contents) . " WHERE op = " . $dbh->quote($id);
	my $sth = $dbh->prepare($query);
	$sth->execute();
	$sth->finish;

}

sub delete_var {
	my ($dbh, $id) = @_;
	my $query = "DELETE FROM vars WHERE name=" . $dbh->quote($id);
	my $sth = $dbh->prepare($query);
	$sth->execute;
	$sth->finish;
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
	$id = $dbh->quote($id);
	$contents = $dbh->quote($contents);
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
	$bid = $dbh->quote($bid);
	$contents = $dbh->quote($contents);
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
	$box = $dbh->quote($box);
	$contents = $dbh->quote($contents);
	my $query = "UPDATE box SET content = $contents WHERE boxid = $box";
	my $sth = $dbh->prepare($query);
	my $rv = $sth->execute();
	$sth->finish;
}

sub insert_box {
	my ($dbh, $box, $contents, $title, $template) = @_;
	map { $dbh->quote($_) } ($box,$contents,$title,$template);
	my $query = "INSERT INTO box (boxid,title,content,template) VALUES ($box, $title, $contents, $template)";
	my $sth = $dbh->prepare($query);
	$sth->execute();
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
