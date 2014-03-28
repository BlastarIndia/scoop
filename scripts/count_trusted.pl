#!/usr/bin/perl
use strict;

##########################
# Configuration:
#	Adjust the vars below to work for your install
##########################
# DB connection params
my $db_user = 'nobody';
my $db_host = 'localhost';
my $db_pass = 'password';
my $db_port = '3306';
my $db_name = 'scoop';

# Mojo parameters 
# (note -- this should be automated, but isn't yet)
my $trusted_mojo        = '>= 3.5';
my $untrusted_mojo      = '< 1';
my $trusted_min_posts   = 10;
my $untrusted_min_posts = 5;

# Mail parameters, for mailing results
my $mailfrom = 'scoop@localhost';
my $smtp     = 'smtp.mydomain.org';
my $subject  = 'Trust stats from Scoop';
##########################

use DBI;
use DBD::mysql;
use Mail::Sendmail;

my $i = 0;
my %args;
while ($i <= $#ARGV) {
	if ($ARGV[$i] =~ /^-/) {
		if ($ARGV[$i+1] !~ /^-/) {
			$args{$ARGV[$i]} = $ARGV[$i+1];
			$i += 2;
		} else {
			$args{$ARGV[$i]} = 1;
			$i++;
		}
	}
}


if (exists $args{'-h'}) {
	print<<END;
count_trusted.pl
Counts trusted and untrusted users in a scoop weblog.
Options:
    -t Count trusted users (may be used with -u)
    -u Count untrusted users (may be used with -t)
    -c Count total users (created and confirmed)
    -m [you\@host.com] Email results to address. Good for cron!
    -h Print help (this page)

END
	exit 1;
}

my $mailto = $args{'-m'};
$args{'-t'} = 1 unless (exists($args{'-u'}) || exists($args{'-c'}));

my $out;
$out .= &count_users() if exists($args{'-c'});
$out .= &do_count($trusted_mojo, $trusted_min_posts, 'trusted') if exists($args{'-t'});
$out .= &do_count($untrusted_mojo, $untrusted_min_posts, 'untrusted') if exists($args{'-u'});

if ($args{'-m'}) {
	&mail_results($out, $args{'-m'});
} else {
	print $out;
}

sub count_users {
	my $data_source = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
    my $dbh = DBI->connect($data_source, $db_user, $db_pass);
	
	my $total_u = qq|select COUNT(*) from users|;
	my $conf_u = 'select COUNT(*) from users where passwd NOT REGEXP "^[0-9]+$"';

	my $sth = $dbh->prepare($total_u);
	$sth->execute();
	my $total = $sth->fetchrow();
	$sth->finish();

	$sth =  $dbh->prepare($conf_u);
	$sth->execute();
	my $confirmed = $sth->fetchrow();
	$sth->finish();
	$dbh->disconnect();

	return "    Total users: $total\nConfirmed users: $confirmed\n\n";
}

sub do_count {
	my $mojo = shift;
	my $num = shift;
	my $word = shift;

	my $data_source = "DBI:mysql:database=$db_name:host=$db_host:port=$db_port";
    my $dbh = DBI->connect($data_source, $db_user, $db_pass);

	my $first_q = qq|SELECT uid, nickname, mojo FROM users WHERE mojo $mojo|;

	my $sth = $dbh->prepare($first_q);
	$sth->execute();

	my @users;
	while (my $user = $sth->fetchrow_hashref) {	
		push @users, $user;
	}
	$sth->finish();

	my $total = 0;
	my $out;
	foreach my $user (@users) {
		my $second_q = qq|SELECT COUNT(*) FROM comments WHERE ((TO_DAYS(NOW()) - TO_DAYS(date)) <= 60) and uid = "$user->{uid}"|;
		$sth = $dbh->prepare($second_q);
		$sth->execute();
		my $c_num = $sth->fetchrow();	
		$total++ if ($c_num >= $num);
		$out .= sprintf("%-20s (%-4d) is %s. Mojo: %-1.2f, Comments: %-3d\n",$user->{nickname}, $user->{uid}, $word, $user->{mojo}, $c_num) if ($c_num >= $num);
	}

	$out .=  "Total $word users: $total\n\n";

	$sth->finish;
	$dbh->disconnect();
	return $out;
}


sub mail_results {
	my $out = shift;
	my $mailto = shift;

	my %mail = (
		To      => $mailto,
		From    => $mailfrom,
		SMTP    => $smtp,
		Subject => $subject,
		Message => $out
	);

	sendmail(%mail);
}
