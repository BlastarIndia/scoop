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

edit_one_block();
paypal_confirm();
subpay_paypal();
hotlist_box();
subpay_type_select();
admin_template();
submit_ad_pay_box();

sub submit_ad_pay_box {
	mesg("\nUpdating submit_ad_pay_box\n");

	mesg("  Grabbing submit_ad_pay_box...");
	my $box = grab_box($dbh, 'submit_ad_pay_box');
	mesg("done\n");

	mesg("  Applying patch\n");
	$box =~ s/ads_use_cc/payment_use_cc/g;
	$box =~ s/ads_use_paypal/payment_use_paypal/g;

	mesg("  Putting box back in...");
	update_box($dbh, 'submit_ad_pay_box', $box);
	mesg("done\n");
}

sub admin_template {
	mesg("\nChanging admin_template's look\n");

	mesg("  Making sure admin_template hasn't change...");
	my $query = "SELECT MD5(block) FROM blocks WHERE bid = 'admin_template'";
	my $sth = $dbh->prepare($query);
	$sth->execute;
	my ($db_md5) = $sth->fetchrow_array;
	$sth->finish;

	my $orig_md5 = 'c8bad631aeb25f0016bea6c9f096a1be';
	if ($db_md5 eq $orig_md5) {
		mesg("it hasn't. Continuing.\n");
	} else {
		mesg("it has. Skipping.\n");
		return;
	}

	mesg("  Copying default_template to admin_template...");
	update_block($dbh, 'admin_template', grab_block($dbh, 'default_template'));
	mesg("done\n");
}

sub subpay_type_select {
	mesg("\nChanging wording on subpay_type_select\n");

	mesg("  Grabbing subpay_type_select box...");
	my $box = grab_box($dbh, 'subpay_type_select');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /payment_use_cc/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found.\n");
	}

	mesg("  Applying patch\n");
	$box =~ s/K5 accepts/We accept/i;
	$box =~ s/You can pay.+debit card. //is;
	$box =~ s/(%%norm_font_end%%<\/td><\/tr>\r?\n?)\s*(<tr>)/$1\};\n\$content .= qq{$2/i;
	$box =~ s/(Paypal<\/a>%%norm_font_end%%<\/td>)\r?\n?/$1} if \$S->\{UI\}->\{VARS\}->\{payment_use_paypal\};\n\$content .= qq\{/i;
	$box =~ s/(Mastercard<\/a>%%norm_font_end%%<\/td>)\r?\n?/$1} if \$S->\{UI\}->\{VARS\}->\{payment_use_cc\};\n\$content .= qq{/i;

	mesg("  Putting box back in...");
	update_box($dbh, 'subpay_type_select', $box);
	mesg("done\n");
}

sub hotlist_box {
	mesg("\nFixing hotlist_box\n");

	mesg("  Fetching box hotlist_box...");
	my $box = grab_box($dbh, 'hotlist_box');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /next unless \(?\$story/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found.\n");
	}

	mesg("  Applying patch\n");
	$box =~ s/(my \$story = \$stories->\[0\];)/$1\nnext unless \(\$story\);\n/;
	$box =~ s/(my \$title =)/return unless \$box_content;\n$1/;

	mesg("  Putting box back in...");
	update_box($dbh, 'hotlist_box', $box);
	mesg("done\n");
}

sub subpay_paypal {
	mesg("\nFixing subpay_paypal box\n");

	mesg("  Fetching box subpay_paypal...");
	my $box = grab_box($dbh, 'subpay_paypal');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /value=".*?uid.*?:\$months"/i) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found.\n");
	}

	mesg("  Applying patch\n");
	$box =~ s/(name="custom"\s+value=)"\$months"/$1"\$S->{UID}:\$months"/i;
	$box =~ s/business_id\s*=\s*(['"]).+?\1/business_id = \$S->{UI}->{VARS}->{paypal_business_id}/;

	mesg("  Putting box back in...");
	update_box($dbh, 'subpay_paypal', $box);
	mesg("done\n");
}

sub paypal_confirm {
	mesg("\nFixing paypal_confirm box\n");

	mesg("  Fetching box paypal_confirm...");
	my $box = grab_box($dbh, 'paypal_confirm');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($box =~ /paypal_do_sub/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found.\n");
	}

	mesg("  Applying patches\n");
	$box =~ s/my \$state;\r?\n//;
	$box =~ s/paypal_invalid_mail\(/paypal_invalid_mail\(\$answer/;
	$box =~ s/(\$S->paypal_do_renewal\(\$vars\);\s*\r?\n?)/$1\n\} elsif (\$vars->{item_name} eq 'Subscription'\) \{\n\t\$S->paypal_do_sub\(\$vars\);\n\} elsif \(\$vars->\{item_name\} eq 'Donation'\) \{\n\t\$S->paypal_do_donate\(\$vars\);\n\} else \{\n\twarn "paypal_confirm called with unknown item_name: \$vars->\{item_name\}\\n";\n/;

	mesg("  Putting box back in...");
	update_box($dbh, 'paypal_confirm', $box);
	mesg("done\n");
}

sub edit_one_block {
	mesg("\nAdding description to edit_one_block\n");

	mesg("  Fetching edit_one_block...");
	my $block = grab_block($dbh, 'edit_one_block');
	mesg("done\n");

	mesg("  Checking for patch...");
	if ($block =~ /%%%%description%%%%/) {
		mesg("found. Skipping.\n");
		return;
	} else {
		mesg("not found.\n");
	}

	mesg("  Applying patch\n");
	$block =~ s/(%%value%%<\/textarea>\r?\n?\s*<\/td>\r?\n?\s*<\/tr>)/$1\n<tr>\n\t<td colspan="2">%%norm_font%%%%description%%%%norm_font_end%%<\/td>\n<\/tr>/;

	mesg("  Putting block back in...");
	update_block($dbh, 'edit_one_block', $block);
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
