#!/usr/bin/perl

use strict;
use Getopt::Std;
use DBI;

my $args = &get_args;

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

print "Getting list of ops..." unless $QUIET;
$query = "SELECT block FROM blocks WHERE bid = 'opcodes'";
$sth = $dbh->prepare($query);
$sth->execute;
my ($block) = $sth->fetchrow_array;
$sth->finish;

# a bug in one of the patches somewhat corrupts the opcodes table, so we have
# to correct for that
$block =~ s/hotlist\r?\n/hotlist,/;
$block =~ s/\n|\r|\s//g;
# some dbs have duplicates, so we can't use an array
my %ops;
foreach my $op (split(/,/, $block)) {
	$ops{$op} = 1;
}
print "done\n" unless $QUIET;

print "Getting list of templates..." unless $QUIET;
$query = "SELECT template_id, opcode FROM templates";
$sth = $dbh->prepare($query);
$sth->execute;
my %templates;
while (my ($tmpl, $op) = $sth->fetchrow_array) {
	$templates{$op} = $tmpl;
}
$sth->finish;
print "done\n" unless $QUIET;

print "Combining into ops table..." unless $QUIET;
my $base_ops = base_ops();
my @unknown;
foreach my $op (keys %ops) {
	next unless $op;
	my %add = (
		op => $op, is_box => 0, enabled => 1
	);
	$add{template} = $templates{$op} if $templates{$op};

	if (my $b = $base_ops->{$op}) {
		# it's possible for func to be empty if this op is only in $base_ops as
		# a placeholder (such as main, confirmpass, hotlist, etc., which are
		# all handled differently)
		$add{func}        = $b->[0] if $b->[0];
		$add{description} = $b->[1] if $b->[1];
		$add{perm}        = $b->[2] if $b->[2];
	} else {
		push(@unknown, $op);
	}

	my $cols = join(", ", keys %add);
	my $vals = join(", ", (map { $dbh->quote($_) } values %add));

	$query = "INSERT INTO ops ($cols) VALUES ($vals)";
	$dbh->do($query);
}
print "done\n" unless $QUIET;

if (@unknown) {
	warn "NOTE:
  The following ops were found but didn't have defaults. They were added, along
  with their template, but you'll probably need to manually update them:
    ", join(', ', @unknown), "\n";
	sleep 2;
}

print "Removing opcodes block..." unless $QUIET;
$query = "DELETE FROM blocks WHERE bid = 'opcodes'";
$dbh->do($query);
print "done\n" unless $QUIET;

print "Dropping templates table..." unless $QUIET;
$query = 'DROP TABLE templates';
$dbh->do($query);
print "done\n" unless $QUIET;


print "Adding ops op template to op_templates..." unless $QUIET;
$query = "SELECT block FROM blocks WHERE bid = 'op_templates'";
$sth = $dbh->prepare($query);
$sth->execute;
($block) = $sth->fetchrow_array;
$sth->finish;
print "." unless $QUIET;

$block =~ s{admin=/tool/,}{admin.1=ops:/tool/opcode/,\nadmin=tool,};
print "." unless $QUIET;

$query = "UPDATE blocks SET block = ? WHERE bid = 'op_templates'";
$sth = $dbh->prepare($query);
$sth->execute($block);
$sth->finish;
print "done\n" unless $QUIET;


print "Removing edit_templates permission from perms block..." unless $QUIET;
$query = "SELECT block FROM blocks WHERE bid = 'perms'";
$sth = $dbh->prepare($query);
$sth->execute;
($block) = $sth->fetchrow_array;
$sth->finish;
print "." unless $QUIET;

$block =~ s/edit_templates,\r?\n//;
print "." unless $QUIET;

$query = "UPDATE blocks SET block = ? WHERE bid = 'perms'";
$sth = $dbh->prepare($query);
$sth->execute($block);
$sth->finish;
print "done\n" unless $QUIET;


print "Removing edit_templates perm from all groups..." unless $QUIET;
$query = q|SELECT perm_group_id, group_perms FROM perm_groups WHERE group_perms LIKE '%edit_templates%'|;
$sth = $dbh->prepare($query);
$sth->execute;
while (my ($group, $perms) = $sth->fetchrow_array) {
	$perms =~ s/edit_templates//;  # remove the perm
	$perms =~ s/,,/,/;             # make sure it's clean
	$perms =~ s/^,|,$//;           # same

	my $query2 = 'UPDATE perm_groups SET group_perms = ? WHERE perm_group_id = ?';
	my $sth2 = $dbh->prepare($query2);
	$sth2->execute($perms, $group);
	$sth2->finish;

	print '.' unless $QUIET;
}
$sth->finish;
print "done\n" unless $QUIET;

sub base_ops {
	# format is op: (function, [description, [permission]])
	return {
		poll_vote    => [
			'just_vote',
			'Registers a user vote in a poll.',
			'poll_vote'
		],
		modsub       => [
			'moderate_subs',
			'Display the moderation queue.',
			'moderate'
		],
		submitstory  => [
			'submit_story',
			'Submits a story to the moderation queue.',
			'story_post'
		],
		admin        => [
			'admin_main',
			'Entry point to the various admin tools.'
		],
		displaystory => [
			'focus_view',
			'Formats and shows a story according to the params.'
		],
		view_poll    => [
			'poll_focus_view',
			'Displays a poll or the results of one.'
		],
		poll_list    => [
			'poll_listing',
			'Gives a list of all the polls that have been created'
		],
		comments     => [
			'comment_dig',
			'Displays comments in various formats.'
		],
		dynamic      => [
			'comment_dig',
			'Same as comments, except is used for dynamic comment mode.'
		],
		newuser      => [
			'new_user',
			'Starts the process of creating a new user.'
		],
		special      => [
			'special',
			'Displays special pages.'
		],
		olderlist    => [
			'olderlist',
			'Gives a listing of older stories.'
		],
		search       => [
			'search',
			'Everything related to searching content on the site.'
		],
		interface    => [
			'interface_prefs',
			'Displays and edits preferences.'
		],
		main         => [
			'main_page',
			'Displays the front page.'
		],
		section      => [
			'main_page',
			'Lists the stories, with intros, that are in a specified section.'
		],
		user         => [
			'edit_user',
			'Display and edit registered users.'
		],
		cron         => [
			'cron',
			'Run waiting cron jobs.'
		],
		submitad     => [
			'choose_submit_ad_step',
			'Start the process of submitting an ad.'
		],
		adinfo       => [
			'ad_info_page',
			'Displays everything related to an ad.'
		],
		redirect     => [
			'redirect',
			'Does ad redirections to other sites, with logging.'
		],
		hotlist      => [undef,
			'Edits a user\'s story hotlist.'
		],
		blank        => [undef,
			'Uses a blank template to do nothing and show nothing.'
		],
		confirmpass => [undef,
			'Confirms a password change request.'
		],
		logout      => [undef,
			'Logs the user out and removes their session.'
		],
		default     => [undef,
			'The template used when no other is known. \'main\' is actually the default op'
		],
		fz          => [undef,
			'Interacts with ForumZilla to provide support for it.'
		],
		fzdisplay   => [undef,
			'Displays stories and comments for ForumZilla.'
		],
		submitrdf => [undef,
			'Walks the user through submitting an RDF feed.'
		],
		showad  => [undef,
			'Displays a single advertisment.'
		],
		ads => [undef,
			'Used for purchasing ad impressions.'
		],
		renew => [undef,
			'Used to renew ads that are already running.'
		]
	};
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
