#!/usr/bin/perl
use strict;
use DBI;
use File::Basename;
use Getopt::Std;

$|++;

my $args = {};
getopts("u:p:d:h:o:vqD", $args);

my $QUIET = $args->{q} || 0;

if ($ARGV[0] =~ /^--?h/) {
	print "usage: ./script-13-post.pl
   After asking for a cron.conf file for cron.pl, this script will go through
   each site listed within the file, update its cron table, and transfer config
   data from its script config file into its db. In order for this to work, all 
   of the sites listed must have a script conf file with correct info for db
   access.\n";
	exit 1;
}

my $conf_file = $args->{c};   # most likely will not exist
while( ! -e $conf_file ) {
	print "To update the cron setup for your scoop site, I'm going to need
the location of your cron.conf file. Just hit enter if the default is
correct.  If you want to skip running this script, type in 'SKIP' as the
name of the cron config file
[../cron/cron.conf] > ";
	chomp($conf_file = <STDIN> );
	$conf_file = '../cron/cron.conf' unless( $conf_file =~ /\w/ );
	last if (-e $conf_file || $conf_file =~ /SKIP/ );
	print "That file doesn't seem to exist, please try again\n\n";
}

exit 0 if $conf_file =~ /SKIP/;

my $cron_conf = do $conf_file || die "do($conf_file): $! ($@)\n";
my $template  = &conf_template;

# the format for cron.conf changed during 0.7 development. check to see if this
# is the old (0.6) format, and if so, poke it around so that it looks like a
# new one
unless ($cron_conf->{scripts} && $cron_conf->{sites}) {
	my %new_conf;
	my %temp_conf = %{$cron_conf};
	$new_conf{sites}->{'scoopsite'} = "scripts.conf";
	$new_conf{scripts} = \%temp_conf;
	$cron_conf = \%new_conf;
}

# we change to the dir that the cron conf is in because, most likely, the
# script conf files will be relative to this
my $dir = dirname($conf_file);
print "Changing current directory to $dir\n" unless $QUIET;
chdir($dir);

print "Starting to update cron...\n" unless $QUIET;

print "Gathering cron run times...\n" unless $QUIET;
my $cron_data;
while (my($script, $when) = each %{ $cron_conf->{scripts} }) {
	print "   Translating $script to " unless $QUIET;
	$script =~ s/\.pl$//;
	$script = lc($script);
	print "$script\n" unless $QUIET;
	$cron_data->{$script} = $when;
}
print "\n";

print "Updating sites...\n" unless $QUIET;
while (my($site, $script_conf) = each %{ $cron_conf->{sites} }) {
	print "Site $site has config $script_conf\n" unless $QUIET;
	my $cur_conf = do $script_conf || die "do($script_conf): $! ($@)\n";
	&do_scripts($cur_conf, $template, $cron_data);
	print "\n" unless $QUIET;
}

print "Finished updating!\n" unless $QUIET;
exit 0;

sub do_scripts {
	my ($cur_conf, $template, $cron) = @_;
	my $sth = &db_connect($cur_conf->{SHARED});

	print "      Updating cron table..." unless $QUIET;
	&update_cron_table($sth, $cron);
	print "done\n" unless $QUIET;

	while (my($script, $conf) = each %{$cur_conf}) {
		next if $script eq "SHARED";
		print "   Updating $script\n" unless $QUIET;

		if ($script eq 'sessionreap.pl') {   # special case
			print "      This is a special case!\n" unless $QUIET;
			print "      Updating..." unless $QUIET;
			my $info = $template->{expire_after};
			my $value = $conf->{expire_after} . ' ' . $conf->{expire_unit};
			$sth->{var}->execute($info->[1], $value, $info->[2], $info->[3], $info->[4]) || warn "error inserting row: $DBI::errstr\n";
			print "done\n" unless $QUIET;
			next;
		}

		while (my($k, $v) = each %{$conf}) {
			next unless $template->{$k};
			my $t = $template->{$k};
			print "      Updating $t->[0] $k..." unless $QUIET;
			if ($t->[0] eq 'var') {
				$sth->{var}->execute($t->[1], "$v", $t->[2], $t->[3], $t->[4])
					|| warn "error inserting row: $DBI::errstr\n";
			} else {
				$sth->{block}->execute($t->[1], $v)
					|| warn "error inserting row: $DBI::errstr\n";
			}
			print "done\n" unless $QUIET;
		}
	}

	&db_disconnect($sth);
}

sub update_cron_table {
	my $sth  = shift;
	my $cron = shift;

	while (my($name, $value) = each %{$cron}) {
		$sth->{cron}->execute($value, $name)
			|| warn "error inserting row: $DBI::errstr\n";
	}
}

sub db_connect {
	my $info = shift;

	my $sth = {};

	my $dsn = "DBI:mysql:database=$info->{dbname}:host=$info->{dbhost}";
	my $dbh = DBI->connect($dsn, $info->{dbuser}, $info->{dbpass});
	$sth->{dbh} = $dbh;

	my $q = &queries();
	$sth->{var} = $dbh->prepare($q->{var}) || die "couldn't prepare $q->{var}: $DBI::errstr\n";
	$sth->{block} = $dbh->prepare($q->{block}) || die "couldn't prepare $q->{block}: $DBI::errstr\n";
	$sth->{cron} = $dbh->prepare($q->{cron}) || die "couldn't prepare $q->{cron}: $DBI::errstr\n";

	return $sth;
}

sub queries {
	return {
		var   => 'INSERT INTO vars (name, value, description, type, category) VALUES (?, ?, ?, ?, ?)',
		block => 'INSERT INTO blocks (bid, block) VALUES (?, ?)',
		cron  => 'UPDATE cron SET run_every = ? WHERE name = ?'
	};
}

sub db_disconnect {
	my $sth = shift;

	$sth->{var}->finish;
	$sth->{block}->finish;
	$sth->{cron}->finish;

	$sth->{dbh}->disconnect;
}

sub conf_template {
	# format: key => [type, dbname] for type = block
	#                [type, dbname, description, type, category] for type = var
	my $template = {
		rdf_file => ['var', 'rdf_file', "The file to save the site's RDF file to. Must be writeable by web server.", 'text', 'RDF'],
		image => ['var', 'rdf_image', "The full URL of an image, to put with the RDF file", 'text', 'RDF'],
		days_to_show => ['var', 'rdf_days_to_show', 'How many days worth of stories to include in the RDF file', 'num', 'RDF'],
		max_stories_to_show => ['var', 'rdf_max_stories', 'The maximum number of stories to include in the RDF file', 'num', 'RDF'],
		copyright => ['var', 'rdf_copyright', 'A short copyright notice to include in the RDF file.', 'text', 'RDF'],
		expire_after => ['var', 'keep_sessions_for', 'How long to keep unused sessions around before getting rid of them (in format "time unit")', 'text', 'Cron'],
		subject => ['var', 'digest_subject', 'The subject of the digest e-mail that gets sent.', 'text', 'Stories,Cron'],
		storyformat => ['block', 'digest_storyformat'],
		headerfooter => ['block', 'digest_headerfooter']
	};

	return $template;
}		
