#!/usr/bin/perl

use strict;
use Getopt::Std;
use DBI;
use String::Random;

my $args = &get_args();

my $db_user = $args->{u};
my $db_pass = $args->{p};
my $db_port = $args->{o};
my $db_name = $args->{d};
my $db_host = $args->{h};

my $QUIET = $args->{q} || 0;

my $dsn = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
my $dbh = DBI->connect($dsn, $db_user, $db_pass,{ PrintError => 0 });

print "WARNING: Make sure you have no ads being judged while this script runs.  All
ads should be judged and paid for.  This script will create stories for
every ad that has been approved and paid for on your site.";

my ($section, $topic ) = &get_section_and_topic();
$section = $dbh->quote($section);
$topic = $dbh->quote($topic);
print "Section: $section\nTopic: $topic\n" if $args->{D};
my $format_box_exists = &check_format_box;

my $a_of_hashes = &get_ad_hashes;

for my $h ( @$a_of_hashes ) {
	print "Making story for ad_id $h->{ad_id}...\n" if $args->{D};
	&make_ad_story( $h );
}

$dbh->disconnect();
exit();

sub get_ad_hashes {
	my $q = "SELECT * from ad_info where active = 1 and example = 0 and judged = 1";
	my $sth = $dbh->prepare($q);
	my $rv = $sth->execute;
	my $aofh = [];

	while( my $t = $sth->fetchrow_hashref ) {
		push( @$aofh, $t );
	}

	return $aofh;
}

sub make_ad_story {
	my $ad_hash = shift;
	my $err = '';

	# make/get new story sid
	my $sid = &make_new_sid();
	my $q_sid = $dbh->quote($sid);

	# first story odds and ends
	my $time = $dbh->quote( &current_time() );
	my $aid = &get_nick_from_uid( $ad_hash->{sponsor} );
	my $title = $dbh->quote($ad_hash->{ad_title});

	# now the meat of the story
	my $body = '';
	my $intro = '';
	if( $format_box_exists ) {
		$intro = qq|%%BOX,ad_story_format,$ad_hash->{ad_id}%%|;
	}
	else {
		$intro = qq| %%BOX,show_ad,$ad_hash->{ad_id}%% |;
	}

	# quote stuff that could be bad
	$intro = $dbh->quote($intro);

	# set up the status values so that its never shown.  Later we'll set it to
	# show only in section if it gets approved/activated
	my $write_s = 0;
	my $display_s = 1;
	my $comment_s = 0;

	my $q = qq|INSERT INTO stories (sid,tid,aid,title,dept, time, introtext, bodytext, writestatus, section, displaystatus, commentstatus) VALUES ($q_sid, $topic, '$aid', $title, '', '$ad_hash->{submitted_on}', $intro, '$body', $write_s, $section, $display_s, $comment_s)|;
	print "Running [$q]\n" if $args->{D};
	my $sth = $dbh->prepare($q);
	my $rv = $sth->execute();

	unless( $rv ) {
		print "DB error! " . $dbh->errstr() . "\n";
		print "Wish to continue? [Y|n]";
		my $in = <STDIN>;
		exit 1 if( $in =~ /n/i );
	}

	$q = qq|UPDATE ad_info set ad_sid = $q_sid where ad_id = $ad_hash->{ad_id}|;
	warn "running [$q]\n" if $args->{D};
	$sth = $dbh->prepare($q);
	$sth->execute();

	return;
}

sub check_format_box {
	my $ret = 0;

	my $q = qq|SELECT boxid,content from box where boxid='ad_story_format'|;
	my $sth = $dbh->prepare($q);
	$sth->execute();
	my $block = $sth->fetchrow_array();

	unless( defined $block ) {
		$ret = 1;
	}

	return $block;
}

sub make_new_sid {
	my $sid = '';

	my $rand_stuff = &rand_stuff;
	$rand_stuff =~ /^(.....)/;
	$rand_stuff = $1;
	
	my @date = localtime(time);
	my $mon = $date[4]+1;
	my $day = $date[3];
	my $year = $date[5]+1900;

	$sid = "$year/$mon/$day/$date[2]$date[1]$date[0]/$rand_stuff";
	$sid =~ /(.{1,20})/;
	$sid = $1;

	return $sid;
}

sub rand_stuff {
	my $bytes = shift || 5;

	return String::Random->new->randpattern('n' x $bytes);
}

sub get_nick_from_uid {
	my $uid = shift;

	my $q = "SELECT nickname from users where uid = $uid";
	my $sth = $dbh->prepare($q);
	$sth->execute();

	my $h = $sth->fetchrow_hashref;

	return $h->{nickname};
}

sub current_time {
	my $S = shift;
	my @date = localtime(time);
	my $mon = $date[4]+1;
	my $day = $date[3];
	my $year = $date[5]+1900;
	my $currtime = qq|$year-$mon-$day $date[2]:$date[1]:$date[0]|;
	
	return $currtime;
}

sub get_section_and_topic {
	my $sec = undef;
	my $top = undef;

	while( 1 ) {
		print "Note: The following section and topic you choose MUST exist\n";
		print "What section do you want advertisements under? [advertisements] ";
		chomp( $sec = <STDIN> );
		$sec = 'advertisements' unless $sec =~ /\w/;

		print "What topic do you want advertisements under? [ads] ";
		chomp( $top = <STDIN> );
		$top = 'ads' unless $top =~ /\w/;

		print "You chose a section of '$sec' and topic of '$top'\n";
		print "Is this right? [Y|n] ";
		my $in = <STDIN>;
		last unless $in =~ /n/i;

	}

	return ($sec,$top);
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


