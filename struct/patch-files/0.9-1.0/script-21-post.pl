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

# lots of stuff in this one, so it's split into subs

user_urltemplate();
user_box();
story_info();
poll_block();
comment();
vars_urltemplate();
hooks();
paypal();

sub paypal {
	mesg("Updating boxes subpay_paypal and ad_pay_paypal\n");

	mesg("  Grabbing boxes...");
	my $ads = grab_box($dbh, 'ad_pay_paypal');
	my $sub = grab_box($dbh, 'subpay_paypal');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($sub =~ /business_id\s*=\s*['"]/) {
		mesg("not found. Continuing.\n");
	} else {
		mesg("found. Skipping.\n");
		return;
	}

	mesg("  Updating boxes\n");
	$sub =~ s/(business_id\s*=\s*)(['"])([^'"]+)\2/$1\$S->{UI}->{VARS}->{paypal_business_id}/;
	$ads =~ s/(business_id\s*=\s*)(['"])([^'"]+)\2/$1\$S->{UI}->{VARS}->{paypal_business_id}/;
	my $business_id = $3;

	mesg("  Updating var paypal_business_id...");
	update_var($dbh, 'paypal_business_id', $business_id) if $business_id;
	mesg("done\n");

	mesg("  Putting boxes back in...");
	update_box($dbh, 'ad_pay_paypal', $ads);
	update_box($dbh, 'subpay_paypal', $sub);
	mesg("done\n");
}

sub hooks {
	mesg("Updating hooks var\n");

	mesg("  Getting hooks var...");
	my $var = grab_var($dbh, 'hooks');
	mesg("done\n");

	mesg("  Changing user_new line\n");
	$var =~ s/user_new\(nick\)/user_new(nick, is_advertiser)/;

	mesg("  Putting hooks var back in...");
	update_var($dbh, 'hooks', $var);
	mesg("done\n");
}

sub vars_urltemplate {
	mesg("Updating /admin/vars urltemplate\n");

	mesg("  Getting urltemplate for op admin...");
	$query = "SELECT urltemplates FROM ops WHERE op = 'admin'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($tmpl) = $sth->fetchrow_array;
	$sth->finish;
	mesg("done\n");

	mesg("  Changing vars line\n");
	$tmpl =~ s/(element\.1=vars:)\/tool\/cat/$1\/tool\/mode\/item/i;

	mesg("  Putting template back in...");
	$query = "UPDATE ops SET urltemplates = " . $dbh->quote($tmpl) . " WHERE op = 'admin'";
	$dbh->do($query);
	mesg("done\n");
}

sub comment {
	mesg("Updating comment block\n");

	mesg("  Getting comment block...");
	my $block = grab_block($dbh, 'comment');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($block =~ /%%edit_user%%/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found. Continuing.\n");
	}

	mesg("  Adding edit_user key to comment\n");
	$block =~ s/(%%user_info%%)/$1%%edit_user%%/;

	mesg("  Putting comment back in...");
	update_block($dbh, 'comment', $block);
	mesg("done\n");
}

sub poll_block {
	mesg("Updating poll_block\n");

	mesg("  Getting poll_block...");
	my $block = grab_block($dbh, 'poll_block');
	mesg("done\n");

	mesg("  Removing hotlist and info from poll_block\n");
	$block =~ s/\s*<TR>\s*\r?\n\s*<TD[^>]*>\s*\r?\n\s*%%norm_font%%%%info%%%%norm_font_end%%\s*\r?\n\s*<\/TD>\s*\r?\n\s*<TD[^>]*>\s*\r?\n\s*%%norm_font%%%%hotlist%%%%norm_font_end%%\s*\r?\n\s*<\/TD>\s*\r?\n\s*<\/TR>\s*//i;

	mesg("  Putting poll_block back in...");
	update_block($dbh, 'poll_block', $block);
	mesg("done\n");
}

sub story_info {
	mesg("Updating story_info block\n");

	mesg("  Getting story_info block...");
	my $block = grab_block($dbh, 'story_info');
	mesg("done\n");

	mesg("  Removing comment_controls from story_info\n");
	$block =~ s/\s*<TR>\s*\r?\n\s*<TD[^>]*>\s*\r?\n\s*%%smallfont%%%%comment_controls%%%%smallfont_end%%\s*\r?\n\s*<\/TD>\s*\r?\n\s*<\/TR>\s*//i; 

	mesg("  Putting story_info back in...");
	update_block($dbh, 'story_info', $block);
	mesg("done\n");
}

sub user_box {
	mesg("Updating user_box\n");

	mesg("  Getting user_box...");
	my $box = grab_box($dbh, 'user_box');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /\$upload_link/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found. Continuing.\n");
	}

	mesg("  Adding Your Files link\n");
	$box =~ s/(\r?\n\tmy \$ad_link)/\tmy \$upload_link = (\$S->have_perm('upload_user') || \$S->have_perm('upload_admin')) ?\n\t\tqq{%%dot%% <a class="light" href="%%rootdir%%\/user\/\$urlnick\/files">Your Files<\/a><br \/>} : '';\n$1/;
	$box =~ s/(\$ad_link\r?\n)/$1      \$upload_link\n/;

	mesg("  Putting user_box back in...");
	update_box($dbh, 'user_box', $box);
	mesg("done\n");
}

sub user_urltemplate {
	mesg("\nUpdating user urltemplate\n");

	mesg("  Getting urltemplate for op user...");
	$query = "SELECT urltemplates FROM ops WHERE op = 'user'";
	$sth = $dbh->prepare($query);
	$sth->execute;
	my ($tmpl) = $sth->fetchrow_array;
	$sth->finish;
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($tmpl =~ /\$p->\{uid\}\s*=\s*\$uid/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found. Continuing.\n");
	}

	mesg("  Adding UID line\n");
	$tmpl =~ s/(\$p->\{nick\}\s*=\s*\$path\[0\];\r?\n)/$1    \$p->{uid}     = \$uid;\n/;

	mesg("  Putting template back in...");
	$query = "UPDATE ops SET urltemplates = " . $dbh->quote($tmpl) . " WHERE op = 'user'";
	$dbh->do($query);
	mesg("done\n");
}

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
