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

print "Getting related_links box..." unless $QUIET;
my $box = grab_box($dbh, 'related_links');
print "done\n" unless $QUIET;

print "Checking for patch..." unless $QUIET;
if ($box =~ /_check_archivestatus\(/) {
	print "found! Leaving box alone.\n" unless $QUIET;
} else {
	print "not applied\nAdding archive support..." unless $QUIET;
	$box =~ s/(param\('sid'\);)/$1\nmy \$archive = \$S->_check_archivestatus(\$sid);/i;
	$box =~ s/(db_select\(\{)/$1\n ARCHIVE => \$archive,/i;
	$box =~ s/(push \@link_arr, .+alttext.+\|;)/ if (\$S->{UI}->{VARS}->{use_topics}) {\n    $1\n  }/i;
	print "done\n" unless $QUIET;

	print "Putting related_links back in..." unless $QUIET;
	update_box($dbh, 'related_links', $box);
	print "done\n" unless $QUIET;
}


print "Getting show_comment_raters box..." unless $QUIET;
$box = grab_box($dbh, 'show_comment_raters');
print "done\n" unless $QUIET;

print "Checking for patch..." unless $QUIET;
if ($box =~ /_check_archivestatus\(/) {
	print "found! Leaving box alone.\n" unless $QUIET;
} else {
	print "not applied\nAdding archive support..." unless $QUIET;
	$box =~ s/(param\('sid'\);)/$1\nmy \$archive = \$S->_check_archivestatus(\$sid);/i;
	$box =~ s/(db_select\(\{)/$1\n\tARCHIVE => \$archive,/ig;
	print "done\n" unless $QUIET;

	print "Putting show_comment_raters back in..." unless $QUIET;
	update_box($dbh, 'show_comment_raters', $box);
	print "done\n" unless $QUIET;
}


print "Getting story_hit_box box..." unless $QUIET;
$box = grab_box($dbh, 'story_hit_box');
print "done\n" unless $QUIET;

if (!$box) {
	print "Box not found. Ignoring.\n" unless $QUIET;
} else {
	print "Checking for patch..." unless $QUIET;
	if ($box =~ /_check_archivestatus\(/) {
		print "found! Leaving box alone.\n" unless $QUIET;
	} else {
		print "not applied\nAdding archive support..." unless $QUIET;
		$box =~ s/(param\('sid'\);)/$1\n\nreturn if \$S->_check_archivestatus(\$sid);/i;
		print "done\n" unless $QUIET;

		print "Putting story_hit_box back in..." unless $QUIET;
		update_box($dbh, 'story_hit_box', $box);
		print "done\n" unless $QUIET;
	}
}

print "All done.\n" unless $QUIET;

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
