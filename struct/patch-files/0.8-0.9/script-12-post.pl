#!/usr/bin/perl 

=head1 config_fulltext.pl

Tests your mySQL server to see if it supports FullText indexes and installs the indexes is supported
=cut

use strict;
use Getopt::Std;
use DBI;

my $required_maj="3.23";	# This is the major version required by scoop
my $required_min="23";		# This is the minor version required by scoop

my $args = &get_args();

my $db_user = $args->{u};
my $db_pass = $args->{p};
my $db_port = $args->{o};
my $db_name = $args->{d};
my $db_host = $args->{h};

my $QUIET = $args->{q} || 0;

my $enable_fulltext=1;	# Assume we can use FULLTEXT indexes

my $dsn = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
my $dbh = DBI->connect($dsn, $db_user, $db_pass,{ PrintError => 0 });

# first get the DB Server Version
my $get_version = "SELECT version()";
my $sth = $dbh->prepare($get_version);
my $rv = $sth->execute();
die "Couldn't run query [$get_version]: $DBI::errstr\n" unless $rv;

my $row = $sth->fetchrow_arrayref;
my($version)=$row->[0]=~m/^([\d\.]+)/;
$sth->finish;

$version=~s/^(\d+\.?\d*)\.?//;
my $major_ver=$1;
my $minor_ver=$version;
$version=$major_ver.'.'.$minor_ver;

print "MySQL Server Version.. $version\n";
my $good_version=1 if($major_ver > $required_maj || ($major_ver == $required_maj && $minor_ver >= $required_min));
unless($good_version) {
  print "Please Upgrade to version $required_maj.$required_min or above of MySQL in order to use FullText Indexes for searching.\n";
  print "This does not prevent your use of Scoop, but simply provides inferior search functionality.\n";
  $enable_fulltext=0;	# We Can't do it after all
} else {
  print "This version appears FullText capable......Good\n";
  print "Adding FullText Index: storysearch_idx.....";
  my $add_storysearch = "ALTER TABLE stories ADD FULLTEXT storysearch_idx (title,introtext,bodytext);";
  my $sth = $dbh->prepare($add_storysearch);
  my $rv = $sth->execute();
  if($rv){ print "OK\n";}
  elsif($DBI::err==1061){ print "Exists\n";}
  elsif($DBI::err==1044) { die("\n[DB: Access Denied]:Please run this script specifying a user that has privileges to add indexes and add records to the '$db_name' DB on '$db_host'.\n");}
  else{
    print "Failed\nCouldn't run query [$add_storysearch]: $DBI::errstr\n";
    $enable_fulltext=0;	# We Can't do it after all
  }
  $sth->finish;

  print "Adding FullText Index: commentsearch_idx...";
  my $add_commentsearch = "ALTER TABLE comments ADD FULLTEXT commentsearch_idx (subject,comment);";
  my $sth = $dbh->prepare($add_commentsearch);
  my $rv = $sth->execute();
  if($rv){ print "OK\n";}
  elsif($DBI::err==1061){ print "Exists\n";}
  elsif($DBI::err==1044) { die("\n[DB: Access Denied]:Please run this script specifying a user that has privileges to add indexes and add records to the '$db_name' DB on '$db_host'.\n");}
  else{
    print "Failed\nCouldn't run query [$add_commentsearch]: $DBI::errstr\n";
    $enable_fulltext=0;	# We Can't do it after all
  }
  $sth->finish;
}

print "Adding 'use_fullltext_indexes' Variable...";
my $add_variable = "INSERT INTO vars (name, value, description, type, category) VALUES ( 'use_fulltext_indexes', '$enable_fulltext', 'Set to true if your DB is capable of using FULLTEXT indexes and you have created the proper indexes', 'bool', 'General');";
my $sth = $dbh->prepare($add_variable);
my $rv = $sth->execute();
if($rv){ print "OK\n";}
elsif($DBI::err==1062){
  print "Exists";
  my $get_status = "SELECT value FROM vars WHERE name='use_fulltext_indexes';";
  my $sth = $dbh->prepare($get_status);
  my $rv = $sth->execute();
  die "\nCouldn't run query [$get_status]: $DBI::errstr\n" unless $rv;
  my $row = $sth->fetchrow_arrayref; my $current_status =$row->[0];
  $sth->finish;
  print (($current_status)?" (Enabled)\n":" (Disabled)\n");

  if($enable_fulltext==$current_status){
    print "FullText indexing status is unchanged.\n";
    print "Correct the issues above and run this script again to enable FullText Indexing.\n" unless $enable_fulltext;
  } else{
    print "Updating 'use_fullltext_indexes' Variable..";
    my $update_var = "UPDATE vars SET value=$enable_fulltext WHERE name='use_fulltext_indexes';";
    my $sth = $dbh->prepare($update_var);
    my $rv = $sth->execute();
    if($rv){ print (($enable_fulltext)?"Enabled\n":"Disabled\n");}
    else{ print "Failed\nCouldn't run query [$update_var]: $DBI::errstr\n";}
    $sth->finish;
  }
}
elsif($DBI::err==1044) { die("\n[DB: Access Denied]:Please run this script specifying a user that has privileges to add indexes and add records to the '$db_name' DB on '$db_host'.\n");}
else{ print "Failed\nCouldn't run query [$add_variable]: $DBI::errstr\n";}
$sth->finish;

exit();


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

