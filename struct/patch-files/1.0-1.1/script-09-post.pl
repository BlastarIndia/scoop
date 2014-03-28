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

my $sections = &grab_sec_perms($dbh,'Diary');

&mesg("Updating Diary section perms to autopost-section for:\n");

foreach my $grp (keys %$sections) {
  my $sec = $sections->{$grp};
  $sec->{sect_perms} =~ s/norm_post_stories/autosec_post_stories/ && &mesg("    ... $grp\n");
  &update_sec_perm($dbh,$grp,'Diary',$sec->{sect_perms});
}

# utility functions

sub grab_sec_perms {
  # gets them all
  my $dbh = shift;
  my $sec = shift;
  my $query = "SELECT * from section_perms WHERE section = " . $dbh->quote($sec);
  my $sth = $dbh->prepare($query);
  $sth->execute;
  my $sects = $sth->fetchall_hashref('group_id');
  $sth->finish;
  return $sects;
}

sub update_sec_perm {
  # updates one
  my ($dbh, $gid, $sec, $perm) = @_;
  my $query = "UPDATE section_perms SET sect_perms = ? WHERE section = ? AND group_id = ?";
  my $sth = $dbh->prepare($query);
  $sth->execute($perm,$sec,$gid);
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

